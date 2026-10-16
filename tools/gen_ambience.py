"""Recorta o som ambiente do estádio (torcida) num loop longo.

Entrada: assets/audio/source/stadium_crowd.mp3
Saída:   assets/audio/sfx/stadium_crowd.ogg (estéreo, Ogg Vorbis, loop sem emenda)

Precisa do ffmpeg (no PATH ou via `pip install imageio-ffmpeg`).

Uso: python tools/gen_ambience.py
"""
import os
import subprocess

import numpy as np

from gen_engine_loops import OUT, RATE, ROOT, ffmpeg_exe

SOURCE = os.path.join(ROOT, "assets", "audio", "source", "stadium_crowd.mp3")
NAME = "stadium_crowd.ogg"
# Início (s), duração do loop (s) e do crossfade (s). Trecho sem apitos nem gritos isolados.
START, LENGTH, FADE = 270.0, 60.0, 3.0
TARGET_RMS = 0.2


def decode_stereo(path):
    raw = subprocess.run(
        [ffmpeg_exe(), "-v", "error", "-i", path, "-ac", "2", "-ar", str(RATE), "-f", "s16le", "-"],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64).reshape(-1, 2) / 32768.0


def main():
    samples = decode_stereo(SOURCE)
    a, n, f = int(START * RATE), int(LENGTH * RATE), int(FADE * RATE)
    seg = samples[a:a + n + f]
    out = seg[:n].copy()
    # Crossfade de potência igual: o trecho depois do fim entra por baixo do começo.
    t = np.linspace(0.0, 1.0, f)[:, None]
    out[:f] = seg[:f] * np.sin(t * np.pi / 2) + seg[n:n + f] * np.cos(t * np.pi / 2)
    out *= TARGET_RMS / np.sqrt(np.mean(out ** 2))
    pcm = (np.clip(out, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    path = os.path.join(OUT, NAME)
    subprocess.run(
        [ffmpeg_exe(), "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "4", path],
        input=pcm, check=True)
    print("gerado", os.path.normpath(path))


if __name__ == "__main__":
    main()
