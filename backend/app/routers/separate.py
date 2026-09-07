from __future__ import annotations

import asyncio
import logging
import os
import shutil
import threading
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

from fastapi import APIRouter, BackgroundTasks, File, Form, HTTPException, Request, UploadFile, status
from pydantic import BaseModel

from app.services.demucs_service import separate_audio
from app.services.ffmpeg_service import extract_audio, is_video, mux_audio, probe_duration

router = APIRouter(prefix="/api/v1", tags=["separation"])
logger = logging.getLogger(__name__)
OUTPUTS_DIR = Path(os.getenv("OUTPUTS_DIR", "/tmp/outputs"))
MAX_BYTES = int(os.getenv("MAX_UPLOAD_BYTES", str(500 * 1024 * 1024)))
MAX_DURATION = float(os.getenv("MAX_VIDEO_DURATION_SECONDS", "1800"))
ALLOWED_SUFFIXES = {".wav", ".mp3", ".m4a", ".aac", ".ogg", ".flac", ".mp4", ".mov", ".mkv", ".avi", ".webm"}
DEFAULT_RETENTION_HOURS = 24.0
RETENTION_SWEEP_SECONDS = 15 * 60
Quality = Literal["fast", "deep"]


def parse_retention_hours(raw: str | None, default: float = DEFAULT_RETENTION_HOURS) -> float:
    """FILE_RETENTION_HOURS must remain configuration; fall back to 24h when absent or invalid."""
    if raw is None:
        return default
    text = raw.strip()
    if not text:
        return default
    try:
        value = float(text)
    except ValueError:
        return default
    return value if value > 0 else default


def _env_positive_int(name: str, default: int) -> int:
    raw = (os.getenv(name) or "").strip()
    if not raw:
        return default
    try:
        value = int(raw)
    except ValueError:
        return default
    return value if value > 0 else default


FILE_RETENTION_HOURS = parse_retention_hours(os.getenv("FILE_RETENTION_HOURS"))
# Deep-clean uses the heavy Demucs configuration; serialize those jobs per server.
_DEEP_JOB_SLOTS = threading.BoundedSemaphore(_env_positive_int("MAX_CONCURRENT_DEEP_JOBS", 1))


@dataclass
class Job:
    status: str = "queued"
    progress: int = 0
    error: str | None = None
    stage: str | None = None
    quality: str = "fast"
    vocals: str | None = None
    instrumental: str | None = None
    video: str | None = None
    is_video: bool = False
    created_at: float = field(default_factory=time.time)


JOBS: dict[str, Job] = {}


class QueuedResponse(BaseModel):
    job_id: str
    status: Literal["queued"]


class StatusResponse(BaseModel):
    progress: int
    status: Literal["queued", "processing", "done", "failed"]
    stage: Literal["analyzing", "separating", "finalizing"] | None = None
    error: str | None = None


class ResultResponse(BaseModel):
    vocals_url: str
    instrumental_url: str
    video_url_if_needed: str | None = None


class JobDeletedResponse(BaseModel):
    job_id: str
    status: Literal["deleted"]


def _url(request: Request, job_id: str, filename: str | None) -> str | None:
    return str(request.base_url).rstrip("/") + f"/outputs/{job_id}/{filename}" if filename else None


def delete_job_files(job_id: str) -> None:
    """Remove exactly one job directory; missing files count as already deleted."""
    directory = OUTPUTS_DIR / job_id
    try:
        shutil.rmtree(directory)
    except FileNotFoundError:
        pass
    except OSError as exc:
        logger.warning("Job %s cleanup failed", job_id)
        raise HTTPException(status_code=500, detail="Files could not be deleted right now") from exc


def sweep_expired_jobs() -> int:
    """Delete job directories older than the retention window and their job records."""
    now = time.time()
    removed = 0
    try:
        entries = list(OUTPUTS_DIR.iterdir())
    except OSError:
        return 0
    for entry in entries:
        if not entry.is_dir():
            continue
        # A long-running separation must not lose its working directory while
        # Demucs or FFmpeg is still writing into it.
        active_job = JOBS.get(entry.name)
        if active_job and active_job.status in {"queued", "processing"}:
            continue
        try:
            age_seconds = now - entry.stat().st_mtime
        except OSError:
            continue
        if age_seconds < FILE_RETENTION_HOURS * 3600:
            continue
        try:
            shutil.rmtree(entry)
        except FileNotFoundError:
            pass
        except OSError:
            logger.warning("Retention cleanup failed for job %s", entry.name)
            continue
        JOBS.pop(entry.name, None)
        removed += 1
    return removed


async def retention_loop() -> None:
    while True:
        try:
            await asyncio.to_thread(sweep_expired_jobs)
        except asyncio.CancelledError:
            raise
        except Exception:  # the sweeper must never take the API down
            logger.exception("Retention sweep failed")
        await asyncio.sleep(RETENTION_SWEEP_SECONDS)


def _process(job_id: str, source: Path, mode: str, quality: str) -> None:
    job = JOBS.get(job_id)
    if job is None:
        return  # deleted before the worker started
    job.status, job.progress, job.stage = "processing", 5, "analyzing"
    directory = source.parent
    try:
        audio_source = extract_audio(source, directory / "source.wav") if job.is_video else source
        job.progress, job.stage = 20, "separating"
        if quality == "deep":
            with _DEEP_JOB_SLOTS:
                if JOBS.get(job_id) is not job:
                    return  # deleted while waiting for a deep-clean slot
                vocals, instrumental = separate_audio(audio_source, directory / "demucs", quality)
        else:
            vocals, instrumental = separate_audio(audio_source, directory / "demucs", quality)
        target_vocals, target_music = directory / "vocals.wav", directory / "instrumental.wav"
        shutil.copy2(vocals, target_vocals)
        shutil.copy2(instrumental, target_music)
        job.vocals, job.instrumental, job.progress = target_vocals.name, target_music.name, 85
        job.stage = "finalizing"
        if job.is_video:
            selected = target_vocals if mode == "keep_vocals" else target_music
            video = mux_audio(source, selected, directory / "cleaned_video.mp4")
            job.video = video.name
        job.progress, job.stage, job.status = 100, None, "done"
    except Exception as exc:  # preserve a readable job failure for polling clients
        logger.exception("Audio separation job %s failed", job_id)
        job.status, job.stage, job.error = "failed", None, str(exc)


@router.post("/separate", response_model=QueuedResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_separation(
    request: Request,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    mode: Literal["keep_vocals", "keep_music"] = Form(...),
    quality: Quality = Form("fast"),
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
        shutil.rmtree(directory, ignore_errors=True)
        raise
    except Exception as exc:
        shutil.rmtree(directory, ignore_errors=True)
        raise HTTPException(status_code=422, detail=f"Unable to read media: {exc}") from exc
    JOBS[job_id] = Job(is_video=video, quality=quality)
    background_tasks.add_task(_process, job_id, source, mode, quality)
    return QueuedResponse(job_id=job_id, status="queued")


@router.get("/status/{job_id}", response_model=StatusResponse)
async def job_status(job_id: str) -> StatusResponse:
    job = JOBS.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return StatusResponse(progress=job.progress, status=job.status, stage=job.stage, error=job.error)


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


@router.delete("/jobs/{job_id}", response_model=JobDeletedResponse)
async def delete_job(job_id: str) -> JobDeletedResponse:
    try:
        uuid.UUID(job_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail="Job not found") from exc
    job = JOBS.get(job_id)
    if job and job.status in {"queued", "processing"}:
        # Deleting the directory while Demucs is writing can recreate files
        # after a successful-looking deletion. Keep the delete promise honest.
        raise HTTPException(status_code=409, detail="Job is still processing")
    delete_job_files(job_id)
    JOBS.pop(job_id, None)
    return JobDeletedResponse(job_id=job_id, status="deleted")
