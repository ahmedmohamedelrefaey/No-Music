from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path


class FFmpegError(RuntimeError):
    pass


def _executable(environment_variable: str, command: str) -> str:
    """Resolve FFmpeg executables, supporting explicit Windows paths."""
    configured = os.getenv(environment_variable)
    if configured:
        candidate = Path(configured).expanduser()
        if candidate.is_file():
            return str(candidate)
        raise FFmpegError(f"{environment_variable} points to a missing file: {candidate}")

    resolved = shutil.which(command)
    if resolved:
        return resolved
    raise FFmpegError(
        f"{command} was not found. Add its folder to PATH or set "
        f"{environment_variable} to the full executable path."
    )


def _run(*args: str) -> None:
    try:
        result = subprocess.run(args, capture_output=True, text=True, check=False)
    except FileNotFoundError as exc:
        raise FFmpegError(f"Executable was not found: {args[0]}") from exc
    if result.returncode != 0:
        raise FFmpegError(result.stderr.strip() or "FFmpeg failed")


def is_video(path: Path) -> bool:
    return path.suffix.lower() in {".mp4", ".mov", ".mkv", ".avi", ".webm"}


def probe_duration(path: Path) -> float:
    result = subprocess.run(
        (_executable("FFPROBE_PATH", "ffprobe"), "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(path)),
        capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        raise FFmpegError(result.stderr.strip() or "Unable to inspect media")
    try:
        return float(result.stdout.strip())
    except ValueError as exc:
        raise FFmpegError("Media duration was unavailable") from exc


def extract_audio(video_path: Path, output_path: Path) -> Path:
    _run(_executable("FFMPEG_PATH", "ffmpeg"), "-y", "-i", str(video_path), "-vn", "-ac", "2", "-ar", "44100", str(output_path))
    return output_path


def mux_audio(video_path: Path, audio_path: Path, output_path: Path) -> Path:
    _run(_executable("FFMPEG_PATH", "ffmpeg"), "-y", "-i", str(video_path), "-i", str(audio_path), "-c:v", "copy", "-map", "0:v:0", "-map", "1:a:0", "-shortest", str(output_path))
    return output_path
