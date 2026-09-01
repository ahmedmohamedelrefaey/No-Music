from __future__ import annotations

import subprocess
from pathlib import Path


class FFmpegError(RuntimeError):
    pass


def _run(*args: str) -> None:
    result = subprocess.run(args, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise FFmpegError(result.stderr.strip() or "FFmpeg failed")


def is_video(path: Path) -> bool:
    return path.suffix.lower() in {".mp4", ".mov", ".mkv", ".avi", ".webm"}


def probe_duration(path: Path) -> float:
    result = subprocess.run(
        ("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(path)),
        capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        raise FFmpegError(result.stderr.strip() or "Unable to inspect media")
    try:
        return float(result.stdout.strip())
    except ValueError as exc:
        raise FFmpegError("Media duration was unavailable") from exc


def extract_audio(video_path: Path, output_path: Path) -> Path:
    _run("ffmpeg", "-y", "-i", str(video_path), "-vn", "-ac", "2", "-ar", "44100", str(output_path))
    return output_path


def mux_audio(video_path: Path, audio_path: Path, output_path: Path) -> Path:
    _run("ffmpeg", "-y", "-i", str(video_path), "-i", str(audio_path), "-c:v", "copy", "-map", "0:v:0", "-map", "1:a:0", "-shortest", str(output_path))
    return output_path
