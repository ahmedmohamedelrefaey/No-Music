# Architecture

The Flutter client uploads selected media to FastAPI and polls a short-lived job record. The API writes each job to `/tmp/outputs/<job_id>`, uses FFmpeg to extract or remux media, and invokes `demucs --two-stems=vocals -n htdemucs`. Completed files are exposed only beneath the matching job directory via the `/outputs` static route.

`BackgroundTasks` is deliberately an MVP choice. It does not survive restarts and shares CPU with API requests. Production should retain the job-registry contract but replace its implementation with Redis plus Celery workers, move media into Supabase Storage, store job state in Postgres, use signed URLs, and enforce authenticated ownership.

Security boundaries: reject unsupported extensions, stream uploads while enforcing the 500MB limit, inspect video duration using ffprobe, avoid shell interpolation by calling subprocess with argument arrays, and keep service keys outside source control.
