from __future__ import annotations

import asyncio
import os
import shutil
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

from fastapi import APIRouter, BackgroundTasks, File, Form, HTTPException, Request, UploadFile, status
from pydantic import BaseModel

from app.services.demucs_service import separate_audio
from app.services.ffmpeg_service import extract_audio, is_video, mux_audio, probe_duration

router = APIRouter(prefix="/api/v1", tags=["separation"])
OUTPUTS_DIR = Path(os.getenv("OUTPUTS_DIR", "/tmp/outputs"))
MAX_BYTES = int(os.getenv("MAX_UPLOAD_BYTES", str(500 * 1024 * 1024)))
MAX_DURATION = float(os.getenv("MAX_VIDEO_DURATION_SECONDS", "1800"))
ALLOWED_SUFFIXES = {".wav", ".mp3", ".m4a", ".aac", ".ogg", ".flac", ".mp4", ".mov", ".mkv", ".avi", ".webm"}


@dataclass
class Job:
    status: str = "queued"
    progress: int = 0
    error: str | None = None
    vocals: str | None = None
    instrumental: str | None = None
    video: str | None = None
    is_video: bool = False


JOBS: dict[str, Job] = {}


class QueuedResponse(BaseModel):
    job_id: str
    status: Literal["queued"]


class StatusResponse(BaseModel):
    progress: int
    status: Literal["queued", "processing", "done", "failed"]


class ResultResponse(BaseModel):
    vocals_url: str
    instrumental_url: str
    video_url_if_needed: str | None = None


def _url(request: Request, job_id: str, filename: str | None) -> str | None:
    return str(request.base_url).rstrip("/") + f"/outputs/{job_id}/{filename}" if filename else None


def _process(job_id: str, source: Path, mode: str) -> None:
    job = JOBS[job_id]
    job.status, job.progress = "processing", 5
    directory = source.parent
    try:
        audio_source = extract_audio(source, directory / "source.wav") if job.is_video else source
        job.progress = 20
        vocals, instrumental = separate_audio(audio_source, directory / "demucs")
        target_vocals, target_music = directory / "vocals.wav", directory / "instrumental.wav"
        shutil.copy2(vocals, target_vocals)
        shutil.copy2(instrumental, target_music)
        job.vocals, job.instrumental, job.progress = target_vocals.name, target_music.name, 85
        if job.is_video:
            selected = target_vocals if mode == "keep_vocals" else target_music
            video = mux_audio(source, selected, directory / "cleaned_video.mp4")
            job.video = video.name
        job.progress, job.status = 100, "done"
    except Exception as exc:  # preserve a readable job failure for polling clients
        job.status, job.error = "failed", str(exc)


@router.post("/separate", response_model=QueuedResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_separation(
    request: Request,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    mode: Literal["keep_vocals", "keep_music"] = Form(...),
) -> QueuedResponse:
    suffix = Path(file.filename or "upload").suffix.lower()
    if suffix not in ALLOWED_SUFFIXES:
        raise HTTPException(status_code=415, detail="Unsupported audio or video format")
    job_id = str(uuid.uuid4())
    directory = OUTPUTS_DIR / job_id
    directory.mkdir(parents=True, exist_ok=False)
    source = directory / f"original{suffix}"
    received = 0
    try:
        with source.open("wb") as destination:
            while chunk := await file.read(1024 * 1024):
                received += len(chunk)
                if received > MAX_BYTES:
                    destination.close()
                    source.unlink(missing_ok=True)
                    raise HTTPException(status_code=413, detail="File exceeds 500MB limit")
                destination.write(chunk)
        video = is_video(source)
        if video and probe_duration(source) > MAX_DURATION:
            source.unlink(missing_ok=True)
            raise HTTPException(status_code=413, detail="Video exceeds 30 minute duration limit")
    except HTTPException:
        raise
    except Exception as exc:
        source.unlink(missing_ok=True)
        raise HTTPException(status_code=422, detail=f"Unable to read media: {exc}") from exc
    JOBS[job_id] = Job(is_video=video)
    background_tasks.add_task(_process, job_id, source, mode)
    return QueuedResponse(job_id=job_id, status="queued")


@router.get("/status/{job_id}", response_model=StatusResponse)
async def job_status(job_id: str) -> StatusResponse:
    job = JOBS.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return StatusResponse(progress=job.progress, status=job.status)


@router.get("/result/{job_id}", response_model=ResultResponse)
async def job_result(request: Request, job_id: str) -> ResultResponse:
    job = JOBS.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if job.status == "failed":
        raise HTTPException(status_code=422, detail=job.error or "Separation failed")
    if job.status != "done":
        raise HTTPException(status_code=409, detail="Job is not complete")
    return ResultResponse(vocals_url=_url(request, job_id, job.vocals), instrumental_url=_url(request, job_id, job.instrumental), video_url_if_needed=_url(request, job_id, job.video))
