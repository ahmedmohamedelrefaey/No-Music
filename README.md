# MuteMusic AI

MuteMusic AI separates vocals and instrumental music from uploaded audio or video. It is an MVP: results depend on recording quality, speech/music overlap, noise, and Demucs model limits.

## Architecture

```text
Flutter (Riverpod + Dio)
        | multipart / polling
FastAPI API ── BackgroundTasks ── FFmpeg ── Demucs htdemucs
        |                              |
   /tmp/outputs static files <───────────┘
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
docker run -p 8000:8000 --env-file backend/.env mutemusic-backend
```

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
curl -F "file=@sample.mp4" -F "mode=keep_vocals" http://localhost:8000/api/v1/separate
```

Poll `/api/v1/status/{job_id}`, then read `/api/v1/result/{job_id}` once status is `done`.

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
