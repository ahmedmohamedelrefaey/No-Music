from __future__ import annotations

import subprocess
import logging
import time
from pathlib import Path

logger = logging.getLogger(__name__)

# "fast" keeps the default htdemucs settings; "deep" averages multiple shifted
# runs (and blends overlapping segments more) for lower residual instruments at
# a genuinely higher processing cost.
DEEP_SHIFTS = "5"
DEEP_OVERLAP = "0.5"

# Experimental quantized path mirrors the CLI "fast" settings exactly:
# htdemucs, two stems (vocals + no_vocals), segment within the transformer's
# 10s training length, 0.25 overlap, 16-bit WAV output.
EXPERIMENT_SEGMENT = 10.0
EXPERIMENT_OVERLAP = 0.25

_Q_MODEL = None


def _warmup_demucs():
    """Pre-download htdemucs weights so first separation is faster."""
    try:
        from demucs.pretrained import get_model
        logger.info("Pre-downloading htdemucs model weights...")
        get_model("htdemucs")
        logger.info("htdemucs model weights cached")
    except Exception:
        logger.exception("Model warmup failed (non-fatal)")


class DemucsError(RuntimeError):
    pass


def warmup_model() -> bool:
    """Pre-download Demucs model weights at server startup."""
    try:
        _warmup_demucs()
        return True
    except Exception:
        logger.exception("Model warmup failed (non-fatal)")
        return False


def separate_audio(input_path: Path, output_root: Path, quality: str = "fast") -> tuple[Path, Path]:
    """Run htdemucs two-stem separation and return vocals and no-vocals WAV paths."""
    output_root.mkdir(parents=True, exist_ok=True)
    command = ["demucs", "--two-stems=vocals", "-n", "htdemucs", "--out", str(output_root)]
    if quality == "deep":
        command += ["--shifts", DEEP_SHIFTS, "--overlap", DEEP_OVERLAP]
    else:
        command += ["--segment", "10", "--overlap", "0.25"]
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


def _get_quantized_model():
    """Load htdemucs once and convert Linear layers to int8 (experimental).

    The cached instance is reused across jobs, so later jobs skip both the
    weight load and the quantization conversion.
    """
    global _Q_MODEL
    if _Q_MODEL is None:
        import torch
        from demucs.pretrained import get_model
        logger.info("Loading htdemucs for quantized path...")
        model = get_model("htdemucs")
        model.cpu()
        model.eval()
        try:
            torch.backends.quantized.engine = "qnnpack"
        except Exception:
            logger.warning("Could not select qnnpack engine", exc_info=True)
        _Q_MODEL = torch.quantization.quantize_dynamic(
            model, {torch.nn.Linear}, dtype=torch.qint8
        )
        logger.info("Quantized model ready (engine=%s)", torch.backends.quantized.engine)
    return _Q_MODEL


def separate_audio_quantized(input_path: Path, output_root: Path) -> tuple[Path, Path]:
    """Experimental int8 separation: same model, stems, rate and layout as fast.

    Mirrors demucs/separate.py (normalize -> apply_model -> denormalize ->
    vocals + sum-of-rest) but runs in-process on a dynamically quantized
    model instead of spawning the CLI.
    """
    import torch
    from demucs.apply import apply_model
    from demucs.audio import save_audio
    from demucs.separate import load_track

    output_root.mkdir(parents=True, exist_ok=True)
    started = time.time()
    model = _get_quantized_model()
    try:
        wav = load_track(input_path, model.audio_channels, model.samplerate)
    except SystemExit as exc:
        raise DemucsError(f"Could not read audio: {exc}") from exc
    ref = wav.mean(0)
    wav = (wav - ref.mean()) / ref.std()
    with torch.no_grad():
        sources = apply_model(
            model,
            wav[None],
            device="cpu",
            shifts=1,
            split=True,
            overlap=EXPERIMENT_OVERLAP,
            progress=False,
            num_workers=0,
            segment=EXPERIMENT_SEGMENT,
        )[0]
    sources = sources * ref.std() + ref.mean()
    stem_dir = output_root / "htdemucs" / input_path.stem
    stem_dir.mkdir(parents=True, exist_ok=True)
    vocals = stem_dir / "vocals.wav"
    music = stem_dir / "no_vocals.wav"
    save_kwargs = {
        "samplerate": model.samplerate,
        "bitrate": 320,
        "preset": 2,
        "clip": "rescale",
        "as_float": False,
        "bits_per_sample": 16,
    }
    index = model.sources.index("vocals")
    save_audio(sources[index], str(vocals), **save_kwargs)
    others = torch.zeros_like(sources[0])
    for position, stem in enumerate(sources):
        if position != index:
            others += stem
    save_audio(others, str(music), **save_kwargs)
    logger.info("Quantized separation took %.1fs", time.time() - started)
    if not vocals.is_file() or not music.is_file():
        raise DemucsError("Quantized run completed without expected output stems")
    return vocals, music
