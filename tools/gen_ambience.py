"""Recorta os sons da torcida do estádio.

Entradas: assets/audio/source/stadium_crowd.mp3, assets/audio/source/crowd_cheer.mp3
Saída:    assets/audio/sfx/
  stadium_crowd.ogg  ambiente de fundo (estéreo, loop sem emenda)
  crowd_cheer_1.ogg, crowd_cheer_2.ogg  torcida vibrando (toca quando sai uma manobra)

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

CHEER_SOURCE = os.path.join(ROOT, "assets", "audio", "source", "crowd_cheer.mp3")
# Nome, início (s), duração (s), entrada e saída suaves (s). Cada um é uma onda de gritos.
CHEERS = [
    ("crowd_cheer_1.ogg", 4.8, 9.5, 0.3, 2.0),
    ("crowd_cheer_2.ogg", 35.8, 9.2, 0.3, 1.5),
]
CHEER_PEAK = 0.9


def decode_stereo(path):
    raw = subprocess.run(
        [ffmpeg_exe(), "-v", "error", "-i", path, "-ac", "2", "-ar", str(RATE), "-f", "s16le", "-"],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64).reshape(-1, 2) / 32768.0


def encode_ogg(name, samples):
    pcm = (np.clip(samples, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    path = os.path.join(OUT, name)
    subprocess.run(
        [ffmpeg_exe(), "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "4", path],
        input=pcm, check=True)
    print("gerado", os.path.normpath(path))


def make_cheers():
    samples = decode_stereo(CHEER_SOURCE)
    for name, start, length, fade_in, fade_out in CHEERS:
        a, n = int(start * RATE), int(length * RATE)
        out = samples[a:a + n].copy()
        env = np.ones(n)
        i, o = int(fade_in * RATE), int(fade_out * RATE)
        env[:i] = np.linspace(0.0, 1.0, i)
        env[n - o:] = np.linspace(1.0, 0.0, o) ** 2
        out *= env[:, None]
        encode_ogg(name, out * (CHEER_PEAK / np.abs(out).max()))


def main():
    make_cheers()
    samples = decode_stereo(SOURCE)
    a, n, f = int(START * RATE), int(LENGTH * RATE), int(FADE * RATE)
    seg = samples[a:a + n + f]
    out = seg[:n].copy()
    # Crossfade de potência igual: o trecho depois do fim entra por baixo do começo.
    t = np.linspace(0.0, 1.0, f)[:, None]
    out[:f] = seg[:f] * np.sin(t * np.pi / 2) + seg[n:n + f] * np.cos(t * np.pi / 2)
    encode_ogg(NAME, out * (TARGET_RMS / np.sqrt(np.mean(out ** 2))))


if __name__ == "__main__":
    main()
