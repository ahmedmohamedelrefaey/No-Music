# MuteMusic AI contributor guide

## Commands

- Backend: `cd backend && python -m venv .venv && .venv/bin/pip install -r requirements.txt && uvicorn app.main:app --reload`
- Mobile: `cd mobile_app && flutter pub get && flutter analyze`
- Container: `docker build -t mutemusic-backend ./backend`

## Rules

- Never commit secrets, Firebase config files, or Supabase service keys.
- Keep API responses compatible with `docs/api_spec.md`.
- Put expensive audio work behind the job registry; retain the registry interface when replacing BackgroundTasks with Celery.
- Run static checks before committing.
