# API Specification

## POST /api/v1/separate

Multipart fields: `file` and `mode` (`keep_vocals` or `keep_music`). Returns HTTP 202:

```json
{"job_id":"uuid","status":"queued"}
```

Returns 413 for files over 500MB or video duration over 30 minutes, 415 for unsupported types, and 422 for unreadable media.

## GET /api/v1/status/{job_id}

```json
{"progress":42,"status":"processing"}
```

Statuses are `queued`, `processing`, `done`, or `failed`. Unknown jobs return 404.

## GET /api/v1/result/{job_id}

Available only once status is `done`:

```json
{"vocals_url":"http://host/outputs/id/vocals.wav","instrumental_url":"http://host/outputs/id/instrumental.wav","video_url_if_needed":"http://host/outputs/id/cleaned_video.mp4"}
```

Returns 409 while processing, 422 after a failed job, and 404 for unknown jobs.
