from __future__ import annotations

import asyncio
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.routers.separate import OUTPUTS_DIR, restore_jobs, retention_loop, router
from app.services.demucs_service import warmup_model

OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)
origins = [value.strip() for value in os.getenv("ALLOWED_ORIGINS", "http://localhost:8000").split(",") if value.strip()]
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI):
    restore_jobs()
    await asyncio.to_thread(warmup_model)
    sweeper = asyncio.create_task(retention_loop())
    yield
    sweeper.cancel()


app = FastAPI(title="MuteMusic AI API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=origins, allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(router)
app.mount("/outputs", StaticFiles(directory=str(OUTPUTS_DIR)), name="outputs")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
