# MuteMusic AI

MuteMusic AI separates vocals and instrumental music from uploaded audio or video. It is an MVP: results depend on recording quality, speech/music overlap, noise, and Demucs model limits.

## Architecture

```text
Flutter (Riverpod + Dio)
        | multipart / polling
FastAPI API ── BackgroundTasks ── FFmpeg ── Demucs htdemucs
        |                              |
 /data volume: outputs + SQLite <─────────┘
```

## Setup

Backend prerequisites: Python 3.11 and FFmpeg.

```bash
cd backend
python -m venv .venv
.venv/bin/pip install -r requirements.txt
uvicorn app.main:app --reload
```

Windows PowerShell activation is `.venv\Scripts\Activate.ps1`.

```bash
docker build -t mutemusic-backend ./backend
docker volume create mutemusic-data
docker run -p 8000:8000 --env-file backend/.env -v mutemusic-data:/data mutemusic-backend
```

Oracle Linux / Podman uses the same persistent data layout. The `:Z` suffix
sets the correct SELinux label for the mounted volume:

```bash
podman build --format docker -t mutemusic-backend ./backend
podman volume create mutemusic-data
podman run -d --name no-music --restart=always --health-on-failure=restart -p 8000:8000 --env-file /home/opc/backend/.env -v mutemusic-data:/data:Z mutemusic-backend
```

The named volume keeps processed outputs and `jobs.sqlite3` when the container
is restarted or replaced. The image also includes a `/health` container health
check. Do not mount or publish `/data` directly through a web server.
Podman must build with `--format docker`; its default OCI image format ignores
Dockerfile health checks.

For mobile, install Flutter 3.22+, then:

```bash
cd mobile_app
flutter pub get
flutter gen-l10n
flutter analyze
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For an iOS simulator use `http://localhost:8000`; physical devices require the host machine LAN address.

## API example

```bash
curl -F "file=@sample.mp4" -F "mode=keep_vocals" -F "quality=deep" http://localhost:8000/api/v1/separate
```

Poll `/api/v1/status/{job_id}`, then read `/api/v1/result/{job_id}` once status is `done`. Clients may delete their job files at any time with `DELETE /api/v1/jobs/{job_id}`; everything is also deleted automatically after `FILE_RETENTION_HOURS` (default 24).

## Integrations Status

| Integration | Status | Configuration |
| --- | --- | --- |
| Figma | Requires Credentials | Connected account did not have edit access to the supplied file. |
| GitHub `No Music` | Requires Access | Repository was not visible to the connected GitHub account. |
| Supabase | Requires Credentials | Add URL and anon key before enabling. |
| Firebase | Disabled | Add Firebase platform config before initialization. |
| RevenueCat | Requires Credentials | `REVENUECAT_API_KEY` dart define. |
| Sentry | Disabled | Configure DSN to enable reporting. |

## Screenshots

Screenshots to be added after emulator run.
