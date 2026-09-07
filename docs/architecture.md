# Architecture

The Flutter client uploads selected media to FastAPI and polls a job record. The API writes each job to `/tmp/outputs/<job_id>`, stores its state in SQLite outside the public outputs directory, uses FFmpeg to extract or remux media, and invokes `demucs --two-stems=vocals -n htdemucs`. Completed files are exposed only beneath the matching job directory via the `/outputs` static route.

`BackgroundTasks` is deliberately an MVP choice. It does not survive restarts and shares CPU with API requests. SQLite restores completed result records after restart, while interrupted queued/processing work becomes failed honestly because it cannot resume. Production should retain the job-registry contract but replace its implementation with Redis plus Celery workers, move media into Supabase Storage, store job state in Postgres, use signed URLs, and enforce authenticated ownership.

Security boundaries: reject unsupported extensions, stream uploads while enforcing the 500MB limit, inspect video duration using ffprobe, avoid shell interpolation by calling subprocess with argument arrays, and keep service keys outside source control.

## Phase 2: quality, privacy, and video workflow

- **Quality**: `keep_vocals` is the product's only mode; `quality` (`fast`/`deep`) is an additive form field. `deep` genuinely maps to heavier Demucs settings (`--shifts 5 --overlap 0.5`); deep requests are never downgraded and are serialized per server via a semaphore (`MAX_CONCURRENT_DEEP_JOBS`).
- **Honest progress**: the job registry reports a coarse `stage` (`analyzing`/`separating`/`finalizing`) alongside `progress`; the client shows a stepper and only uses the real upload percentage for bytes actually sent — no fabricated percentages.
- **Privacy and retention**: `DELETE /api/v1/jobs/{job_id}` deletes exactly one job directory (UUID-validated, idempotent). A background sweeper removes directories older than `FILE_RETENTION_HOURS` (default 24, forgiving parsing) every 15 minutes. Cleanup treats missing files as success and logs failures with the job id only — never paths or stack traces.
- **Result quality card**: rule-based and explicitly labeled as an indicative estimate (quality chosen + file type), never presented as an AI score.
