# API Specification

## POST /api/v1/separate

Multipart fields: `file`, `mode` (`keep_vocals` or `keep_music`), and optional `quality` (`fast` or `deep`, default `fast`). Existing clients that omit `quality` keep working unchanged. The mobile app always sends `keep_vocals`. Returns HTTP 202:

```json
{"job_id":"uuid","status":"queued"}
```

Returns 413 for files over 500MB or video duration over 30 minutes, 415 for unsupported types, and 422 for unreadable media or an unknown quality value.

Quality mapping: `fast` uses default htdemucs settings; `deep` runs Demucs with `--shifts 5 --overlap 0.5` (multiple averaged shifted runs) for lower residual instruments at a higher processing cost. Deep jobs are serialized per server; tune with `MAX_CONCURRENT_DEEP_JOBS`.

## GET /api/v1/status/{job_id}

```json
{"progress":42,"status":"processing","stage":"separating"}
```

Statuses are `queued`, `processing`, `done`, or `failed`. `stage` is optional (`analyzing`, `separating`, `finalizing`) and lets clients show honest processing phases instead of inventing percentages; it is `null` when done. Unknown jobs return 404.

## GET /api/v1/result/{job_id}

Available only once status is `done`:

```json
{"vocals_url":"http://host/outputs/id/vocals.wav","instrumental_url":"http://host/outputs/id/instrumental.wav","video_url_if_needed":"http://host/outputs/id/cleaned_video.mp4"}
```

Returns 409 while processing, 422 after a failed job, and 404 for unknown jobs (including jobs deleted by the user or by retention cleanup).

## DELETE /api/v1/jobs/{job_id}

Deletes the job's uploaded input and all generated outputs, and drops the job record. The id is validated as a UUID before any filesystem access, and only `OUTPUTS_DIR/<job_id>` is ever removed, so no other job's files can be touched. Idempotent: unknown-but-valid UUIDs return 200; malformed ids return 404.

```json
{"job_id":"uuid","status":"deleted"}
```

## File retention

`FILE_RETENTION_HOURS` (default 24) controls automatic deletion. A background sweeper removes job directories older than the retention window every 15 minutes; missing files are treated as already deleted, and cleanup failures are logged with the job id only.
