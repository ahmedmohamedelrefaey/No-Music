from __future__ import annotations

import subprocess
from pathlib import Path


class DemucsError(RuntimeError):
    pass


def separate_audio(input_path: Path, output_root: Path) -> tuple[Path, Path]:
    """Run htdemucs two-stem separation and return vocals and no-vocals WAV paths."""
    output_root.mkdir(parents=True, exist_ok=True)
    command = (
        "demucs", "--two-stems=vocals", "-n", "htdemucs", "--out", str(output_root), str(input_path),
    )
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        # Combine both outputs for debugging on Windows
        detail = (result.stderr.strip() + "\n" + result.stdout.strip()).strip()
        print(f"Demucs failed (code {result.returncode}): {detail[:2000]}")
        raise DemucsError(detail or "Demucs failed")
    stem_dir = output_root / "htdemucs" / input_path.stem
    vocals = stem_dir / "vocals.wav"
    music = stem_dir / "no_vocals.wav"
    if not vocals.is_file() or not music.is_file():
        raise DemucsError("Demucs completed without expected output stems")
    return vocals, music
