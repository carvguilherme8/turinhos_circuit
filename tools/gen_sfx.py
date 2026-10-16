"""Gera efeitos sonoros simples (sintetizados aqui, livres de direitos).

Saída: assets/audio/sfx/
  countdown_beep.wav  bipe curto e grave (3, 2, 1)
  countdown_go.wav    bipe longo e agudo (VAI!)
  ui_move.wav         tique curto ao navegar pelo menu
  ui_select.wav       dois bipes subindo (confirmar)
  ui_back.wav         dois bipes descendo (voltar / fechar)

Uso: python tools/gen_sfx.py
"""
import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")


def tone(freq, seconds, volume=0.5, attack=0.005, release=0.06):
    """Onda quadrada suavizada (som de placar/semáforo retrô) com ataque e soltura curtos."""
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        # Quadrada "arredondada": fundamental + harmônicos ímpares decrescentes.
        s = sum(math.sin(2 * math.pi * freq * k * t) / k for k in (1, 3, 5, 7)) * 0.8
        env = min(1.0, t / attack) * min(1.0, (seconds - t) / release)
        out.append(s * env * volume)
    return out


def blips(freqs, step, volume=0.3):
    """Sequência de bipes curtos e emendados, com o fim de cada um amortecido."""
    out = []
    for f in freqs:
        out += tone(f, step, volume=volume, attack=0.003, release=step * 0.6)
    return out


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    print("gerado", os.path.normpath(path))


def main():
    save("countdown_beep.wav", tone(660.0, 0.22))
    # "VAI!": uma oitava acima e mais longo.
    go = tone(1320.0, 0.75, volume=0.55, release=0.25)
    save("countdown_go.wav", go)
    save("ui_move.wav", tone(1046.5, 0.045, volume=0.22, attack=0.002, release=0.035))
    save("ui_select.wav", blips([784.0, 1174.7], 0.07))
    save("ui_back.wav", blips([880.0, 587.3], 0.07))


if __name__ == "__main__":
    main()
