from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.routers.separate import OUTPUTS_DIR, router

OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)
origins = [value.strip() for value in os.getenv("ALLOWED_ORIGINS", "http://localhost:8000").split(",") if value.strip()]
app = FastAPI(title="MuteMusic AI API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=origins, allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(router)
app.mount("/outputs", StaticFiles(directory=str(OUTPUTS_DIR)), name="outputs")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
