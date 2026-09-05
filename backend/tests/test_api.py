from __future__ import annotations

import os
import time
import uuid

import app.routers.separate as separate


def upload(client, name="song.wav", mode="keep_vocals", quality=None):
    files = {"file": (name, b"fake-media-bytes", "application/octet-stream")}
    form = {"mode": mode}
    if quality is not None:
        form["quality"] = quality
    return client.post("/api/v1/separate", files=files, data=form)


def test_separate_roundtrip_is_compatible_with_spec(client, fake_separation):
    response = upload(client)
    assert response.status_code == 202
    body = response.json()
    assert body["status"] == "queued"
    job_id = body["job_id"]

    status = client.get(f"/api/v1/status/{job_id}")
    assert status.status_code == 200
    assert status.json()["status"] == "done"
    assert status.json()["progress"] == 100

    result = client.get(f"/api/v1/result/{job_id}")
    assert result.status_code == 200
    payload = result.json()
    assert set(payload) == {"vocals_url", "instrumental_url", "video_url_if_needed"}
    assert payload["video_url_if_needed"] is None
    assert f"/outputs/{job_id}/vocals.wav" in payload["vocals_url"]
    assert f"/outputs/{job_id}/instrumental.wav" in payload["instrumental_url"]


def test_quality_defaults_to_fast_for_existing_clients(client, fake_separation):
    response = upload(client)
    assert response.status_code == 202
    job_id = response.json()["job_id"]
    assert client.get(f"/api/v1/status/{job_id}").status_code == 200
    assert fake_separation["quality"] == "fast"
    assert separate.JOBS[job_id].quality == "fast"


def test_deep_quality_is_kept_and_not_downgraded(client, fake_separation):
    response = upload(client, quality="deep")
    assert response.status_code == 202
    job_id = response.json()["job_id"]
    assert client.get(f"/api/v1/status/{job_id}").json()["status"] == "done"
    assert fake_separation["quality"] == "deep"
    assert separate.JOBS[job_id].quality == "deep"


def test_quality_rejects_unknown_values(client):
    assert upload(client, quality="ultra").status_code == 422


def test_processing_reports_honest_stages(client, fake_separation):
    response = upload(client, quality="deep")
    job_id = response.json()["job_id"]
    client.get(f"/api/v1/status/{job_id}")
    # While Demucs (stubbed) was running, the job advertised the separating stage.
    assert fake_separation["stages_seen"] == ["separating"]
    final = client.get(f"/api/v1/status/{job_id}").json()
    assert final["stage"] is None
    assert final["status"] == "done"


def test_unsupported_extension_returns_415(client):
    assert upload(client, name="archive.exe").status_code == 415


def test_oversize_upload_returns_413(client, monkeypatch):
    monkeypatch.setattr(separate, "MAX_BYTES", 4)
    response = upload(client)
    assert response.status_code == 413
    assert response.json()["detail"] == "File exceeds 500MB limit"


def test_status_and_result_404_for_unknown_jobs(client):
    unknown = str(uuid.uuid4())
    assert client.get(f"/api/v1/status/{unknown}").status_code == 404
    assert client.get(f"/api/v1/result/{unknown}").status_code == 404


def test_result_409_while_job_is_incomplete(client):
    job_id = str(uuid.uuid4())
    separate.JOBS[job_id] = separate.Job(status="processing", progress=42, stage="separating")
    assert client.get(f"/api/v1/result/{job_id}").status_code == 409
    status = client.get(f"/api/v1/status/{job_id}").json()
    assert status["stage"] == "separating"


def test_video_input_produces_video_url(client, fake_separation):
    response = upload(client, name="clip.mp4")
    assert response.status_code == 202
    job_id = response.json()["job_id"]
    result = client.get(f"/api/v1/result/{job_id}").json()
    assert result["video_url_if_needed"].endswith(f"/outputs/{job_id}/cleaned_video.mp4")


def test_delete_job_removes_only_its_files(client, fake_separation, outputs_dir):
    first = upload(client).json()["job_id"]
    second = upload(client).json()["job_id"]
    first_dir = outputs_dir / first
    assert (first_dir / "vocals.wav").is_file()

    response = client.delete(f"/api/v1/jobs/{first}")
    assert response.status_code == 200
    assert response.json() == {"job_id": first, "status": "deleted"}
    assert not first_dir.exists()
    assert (outputs_dir / second / "vocals.wav").is_file()  # untouched sibling job
    assert first not in separate.JOBS

    assert client.get(f"/api/v1/status/{first}").status_code == 404
    assert client.get(f"/api/v1/result/{first}").status_code == 404


def test_delete_job_is_idempotent_and_safe(client, fake_separation, outputs_dir):
    job_id = upload(client).json()["job_id"]
    assert client.delete(f"/api/v1/jobs/{job_id}").status_code == 200
    # Second call: files already gone, job record already dropped.
    assert client.delete(f"/api/v1/jobs/{job_id}").status_code == 200
    # Never-existed-but-valid uuid is safe to "delete".
    assert client.delete(f"/api/v1/jobs/{uuid.uuid4()}").status_code == 200
    # Malformed ids are rejected before any filesystem access.
    assert client.delete("/api/v1/jobs/not-a-uuid").status_code == 404
    assert client.delete("/api/v1/jobs/..%2F..%2Fetc").status_code == 404


def test_retention_parsing_falls_back_to_24h():
    assert separate.parse_retention_hours(None) == 24.0
    assert separate.parse_retention_hours("") == 24.0
    assert separate.parse_retention_hours("   ") == 24.0
    assert separate.parse_retention_hours("invalid") == 24.0
    assert separate.parse_retention_hours("0") == 24.0
    assert separate.parse_retention_hours("-5") == 24.0
    assert separate.parse_retention_hours("48") == 48.0
    assert separate.parse_retention_hours("0.5") == 0.5


def test_retention_sweep_deletes_only_expired_jobs(monkeypatch, outputs_dir):
    old_id = "99999999-9999-9999-9999-999999999999"
    fresh_id = "88888888-8888-8888-8888-888888888888"
    old_dir = outputs_dir / old_id
    fresh_dir = outputs_dir / fresh_id
    old_dir.mkdir(parents=True)
    fresh_dir.mkdir(parents=True)
    (old_dir / "vocals.wav").write_bytes(b"a")
    (fresh_dir / "vocals.wav").write_bytes(b"b")
    expired = time.time() - (25 * 3600)
    os.utime(old_dir, (expired, expired))
    separate.JOBS[old_id] = separate.Job()
    separate.JOBS[fresh_id] = separate.Job()

    monkeypatch.setattr(separate, "FILE_RETENTION_HOURS", 24.0)
    removed = separate.sweep_expired_jobs()

    assert removed == 1
    assert not old_dir.exists()
    assert fresh_dir.exists()
    assert old_id not in separate.JOBS
    assert fresh_id in separate.JOBS


def test_retention_sweep_handles_missing_files(monkeypatch, outputs_dir):
    gone_id = "77777777-7777-7777-7777-777777777777"
    gone_dir = outputs_dir / gone_id
    gone_dir.mkdir()
    expired = time.time() - (30 * 3600)
    os.utime(gone_dir, (expired, expired))
    separate.JOBS[gone_id] = separate.Job()
    monkeypatch.setattr(separate, "FILE_RETENTION_HOURS", 24.0)

    # Directory vanishes between stat() and rmtree(); cleanup must not raise.
    def raise_missing(path, **_):
        raise FileNotFoundError(path)

    monkeypatch.setattr(separate.shutil, "rmtree", raise_missing)
    assert separate.sweep_expired_jobs() >= 1
    assert gone_id not in separate.JOBS
