"""Benchmark: original CLI fast path vs experimental quantized path.

Usage inside the container:
    python /tmp/bench_q.py /data/outputs/<job_id>/source.wav
"""
import sys
import time
from pathlib import Path

sys.path.insert(0, "/app")

import torch
import torchaudio

from app.services.demucs_service import separate_audio, separate_audio_quantized

src = Path(sys.argv[1])
print("engine:", torch.backends.quantized.engine, "| threads:", torch.get_num_threads())

t0 = time.time()
v1, _ = separate_audio(src, Path("/tmp/bench_orig"), "fast")
t_fast = time.time() - t0
print(f"ORIG fast: {t_fast:.1f}s -> {v1}")

t0 = time.time()
v2, _ = separate_audio_quantized(src, Path("/tmp/bench_quant"))
t_q = time.time() - t0
print(f"QUANT: {t_q:.1f}s -> {v2}")
print(f"SPEEDUP: {t_fast / t_q:.2f}x")

w1, _ = torchaudio.load(str(v1))
w2, _ = torchaudio.load(str(v2))
n = min(w1.shape[-1], w2.shape[-1])
rel = (w1[..., :n] - w2[..., :n]).pow(2).sum() / w1[..., :n].pow(2).sum()
print(f"REL DIFF vocals: {rel.item() * 100:.4f}%")
