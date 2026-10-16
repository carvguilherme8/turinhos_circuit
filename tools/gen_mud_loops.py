"""Recorta os loops de pneu na lama a partir da gravação de um carro andando na lama.

Entrada: assets/audio/source/mud_driving.mp3
Saída:   assets/audio/sfx/
  mud_roll.wav   pneu rodando na lama (trecho calmo, fica de fundo enquanto anda)
  mud_slide.wav  lama espirrando forte (trecho agressivo, entra na derrapagem)

Os graves mais fundos (motor do carro) são cortados para não brigar com o som da moto, e os
agudos são abafados: lama soa grave e "molhada"; agudo demais lembra cascalho.
Precisa do ffmpeg (no PATH ou via `pip install imageio-ffmpeg`) para ler o mp3.

Uso: python tools/gen_mud_loops.py
"""
import os

import numpy as np

from gen_engine_loops import RATE, ROOT, decode, make_loop, save

SOURCE = os.path.join(ROOT, "assets", "audio", "source", "mud_driving.mp3")

# Nome, início (s), duração do loop (s), duração do crossfade (s).
LOOPS = [
    ("mud_roll.wav", 40.0, 8.0, 0.6),
    ("mud_slide.wav", 12.8, 3.6, 0.4),
]
# Abaixo disto é quase só o motor do carro (Hz).
HIGHPASS_HZ = 160.0
# Acima disto os agudos vão sendo abafados (Hz; 12 dB por oitava).
LOWPASS_HZ = 1100.0


def shape(samples):
    """Corta os graves (rampa de uma oitava) e abafa os agudos (filtro na frequência)."""
    spectrum = np.fft.rfft(samples)
    freqs = np.maximum(np.fft.rfftfreq(len(samples), 1.0 / RATE), 1.0)
    high = np.clip(np.log2(freqs / (HIGHPASS_HZ / 2.0)), 0.0, 1.0)
    low = 1.0 / (1.0 + (freqs / LOWPASS_HZ) ** 2)
    return np.fft.irfft(spectrum * high * low, len(samples))


def main():
    samples = shape(decode(SOURCE))
    for name, start, length, fade in LOOPS:
        save(name, make_loop(samples, start, length, fade))


if __name__ == "__main__":
    main()
