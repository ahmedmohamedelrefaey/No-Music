from __future__ import annotations

import subprocess
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

# "fast" keeps the default htdemucs settings; "deep" averages multiple shifted
# runs (and blends overlapping segments more) for lower residual instruments at
# a genuinely higher processing cost.
DEEP_SHIFTS = "5"
DEEP_OVERLAP = "0.5"

_SEPARATOR = None


def _get_separator():
    """Lazy-load and cache the Demucs Separator instance."""
    global _SEPARATOR
    if _SEPARATOR is None:
        try:
            from demucs.api import Separator
            logger.info("Loading htdemucs model (first call)...")
            _SEPARATOR = Separator("htdemucs")
            logger.info("htdemucs model loaded and cached")
        except Exception:
            logger.exception("Failed to pre-load Demucs model")
            raise
    return _SEPARATOR


class DemucsError(RuntimeError):
    pass


def warmup_model() -> bool:
    """Pre-load the Demucs model at server startup to avoid first-job delay."""
    try:
        _get_separator()
        return True
    except Exception:
        logger.exception("Model warmup failed")
        return False


def separate_audio(input_path: Path, output_root: Path, quality: str = "fast") -> tuple[Path, Path]:
    """Run htdemucs two-stem separation and return vocals and no-vocals WAV paths."""
    output_root.mkdir(parents=True, exist_ok=True)
    command = ["demucs", "--two-stems=vocals", "-n", "htdemucs", "--out", str(output_root)]
    if quality == "deep":
        command += ["--shifts", DEEP_SHIFTS, "--overlap", DEEP_OVERLAP]
    else:
        command += ["--segment", "7", "--overlap", "0.25"]
    command.append(str(input_path))
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        detail = (result.stderr.strip() + "\n" + result.stdout.strip()).strip()
        logger.error("Demucs failed (code %d): %s", result.returncode, detail[:2000])
        raise DemucsError(detail or "Demucs failed")
    stem_dir = output_root / "htdemucs" / input_path.stem
    vocals = stem_dir / "vocals.wav"
    music = stem_dir / "no_vocals.wav"
    if not vocals.is_file() or not music.is_file():
        raise DemucsError("Demucs completed without expected output stems")
    return vocals, music
