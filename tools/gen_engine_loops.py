"""Recorta os loops do motor a partir da gravação da moto.

Entrada: assets/audio/source/motocross_engine.mp3 (moto passando: acelera trocando marchas
         e depois solta o acelerador).
Saída:   assets/audio/sfx/
  engine_on.wav   acelerando (trecho de 14,25 s, giro estável)
  engine_off.wav  acelerador solto (trecho de 15,65 s, motor desacelerando)

Cada trecho vira um loop sem emenda: o fim é misturado no começo (crossfade).
Precisa do ffmpeg (no PATH ou via `pip install imageio-ffmpeg`) para ler o mp3.

Uso: python tools/gen_engine_loops.py
"""
import os
import shutil
import subprocess
import wave

import numpy as np

RATE = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SOURCE = os.path.join(ROOT, "assets", "audio", "source", "motocross_engine.mp3")
OUT = os.path.join(ROOT, "assets", "audio", "sfx")

# Nome, início (s), duração do loop (s), duração do crossfade (s).
LOOPS = [
    ("engine_on.wav", 14.25, 0.95, 0.10),
    ("engine_off.wav", 15.65, 1.30, 0.12),
]
# Volume RMS de saída (o jogo controla o volume de cada estado).
TARGET_RMS = 0.22


def ffmpeg_exe():
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def decode(path):
    """Lê o mp3 como mono 44,1 kHz em float."""
    raw = subprocess.run(
        [ffmpeg_exe(), "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0


def make_loop(samples, start, length, fade):
    a = int(start * RATE)
    n = int(length * RATE)
    f = int(fade * RATE)
    seg = samples[a:a + n + f].copy()
    seg -= seg.mean()
    out = seg[:n].copy()
    # Crossfade de potência igual: o rabo depois do fim entra por baixo do começo.
    t = np.linspace(0.0, 1.0, f)
    out[:f] = seg[:f] * np.sin(t * np.pi / 2) + seg[n:n + f] * np.cos(t * np.pi / 2)
    return out * (TARGET_RMS / np.sqrt(np.mean(out ** 2)))


def save(name, samples):
    path = os.path.join(OUT, name)
    data = (np.clip(samples, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("gerado", os.path.normpath(path))


def main():
    samples = decode(SOURCE)
    for name, start, length, fade in LOOPS:
        save(name, make_loop(samples, start, length, fade))


if __name__ == "__main__":
    main()
