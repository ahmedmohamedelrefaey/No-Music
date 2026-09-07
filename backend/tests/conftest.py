from __future__ import annotations

import os
import tempfile
from pathlib import Path

# OUTPUTS_DIR is bound at import time, so it must be configured before app modules load.
_OUTPUTS = Path(tempfile.mkdtemp(prefix="mutemusic-tests-"))
os.environ["OUTPUTS_DIR"] = str(_OUTPUTS)
os.environ["JOB_STORE_PATH"] = str(_OUTPUTS.parent / f"{_OUTPUTS.name}-jobs.sqlite3")
os.environ.pop("FILE_RETENTION_HOURS", None)

import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
from fastapi.testclient import TestClient

import app.routers.separate as separate


@pytest.fixture()
def outputs_dir() -> Path:
    return _OUTPUTS


@pytest.fixture()
def client():
    separate.JOBS.clear()
    for entry in _OUTPUTS.iterdir():
        shutil.rmtree(entry, ignore_errors=True)
    from app.main import app

    with TestClient(app) as test_client:
        yield test_client
    separate.JOBS.clear()


@pytest.fixture()
def fake_separation(monkeypatch):
    """Replace FFmpeg/Demucs with filesystem stubs; record Demucs settings."""
    recorded: dict[str, object] = {}

    def fake_separate_audio(input_path, output_root, quality="fast"):
        recorded["quality"] = quality
        recorded["stages_seen"] = [job.stage for job in separate.JOBS.values()]
        stem_dir = Path(output_root) / "htdemucs" / Path(input_path).stem
        stem_dir.mkdir(parents=True, exist_ok=True)
        vocals = stem_dir / "vocals.wav"
        music = stem_dir / "no_vocals.wav"
        vocals.write_bytes(b"vocals-bytes")
        music.write_bytes(b"music-bytes")
        return vocals, music

    monkeypatch.setattr(separate, "separate_audio", fake_separate_audio)
    monkeypatch.setattr(separate, "extract_audio", lambda video, output: output.touch() or output)
    monkeypatch.setattr(separate, "mux_audio", lambda video, audio, output: output.touch() or output)
    monkeypatch.setattr(separate, "is_video", lambda path: path.suffix.lower() == ".mp4")
    monkeypatch.setattr(separate, "probe_duration", lambda path: 10.0)
    return recorded


def upload(client, name="song.wav", mode="keep_vocals", quality=None):
    files = {"file": (name, b"fake-media-bytes", "application/octet-stream")}
    form = {"mode": mode}
    if quality is not None:
        form["quality"] = quality
    return client.post("/api/v1/separate", files=files, data=form)
