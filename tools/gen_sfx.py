"""Gera efeitos sonoros simples (sintetizados aqui, livres de direitos).

Saída: assets/audio/sfx/
  countdown_beep.wav  bipe curto e grave (3, 2, 1)
  countdown_go.wav    bipe longo e agudo (VAI!)
  ui_move.wav         tique curto ao navegar pelo menu
  ui_select.wav       dois bipes subindo (confirmar)
  ui_back.wav         dois bipes descendo (voltar / fechar)
  rain_loop.wav       chuva constante (ruído filtrado + gotas), loop sem emenda
  fire_whoosh.wav     "fuuum" de fogo (passar pela argola)
  wind_loop.wav       vento do deserto, loop sem emenda

Uso: python tools/gen_sfx.py
"""
import math
import os
import random
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


def rain(seconds=8.0, fade=0.6, seed=7):
    """Chuva: chiado (ruído passado por filtros simples) + milhares de gotinhas curtas."""
    rnd = random.Random(seed)
    n = int(RATE * (seconds + fade))
    # chiado: ruído branco suavizado (passa-baixa) menos uma versão mais suave (passa-alta)
    out = [0.0] * n
    low = slow = 0.0
    for i in range(n):
        w = rnd.uniform(-1.0, 1.0)
        low += (w - low) * 0.35
        slow += (low - slow) * 0.02
        out[i] = (low - slow) * 0.55
    # gotas: estalinho que some rápido, em alturas variadas
    for _ in range(int(seconds * 420)):
        start = rnd.randrange(n - 600)
        amp = rnd.uniform(0.04, 0.22)
        freq = rnd.uniform(1800.0, 5200.0)
        for k in range(rnd.randint(120, 500)):
            out[start + k] += amp * math.exp(-k / 70.0) * math.sin(2 * math.pi * freq * k / RATE)
    # loop: o trecho depois do fim entra por baixo do começo
    m = int(RATE * seconds)
    f = int(RATE * fade)
    for i in range(f):
        t = i / f
        out[i] = out[i] * math.sin(t * math.pi / 2) + out[m + i] * math.cos(t * math.pi / 2)
    out = out[:m]
    peak = max(abs(v) for v in out)
    return [v / peak * 0.8 for v in out]


def whoosh(seconds=0.9, seed=11):
    """Ruído que cresce e some, com o "brilho" subindo (chama passando perto)."""
    rnd = random.Random(seed)
    n = int(RATE * seconds)
    out = []
    low = 0.0
    for i in range(n):
        t = i / n
        cutoff = 0.05 + 0.5 * t  # o som fica mais aberto com o tempo
        low += (rnd.uniform(-1.0, 1.0) - low) * cutoff
        env = math.sin(math.pi * min(1.0, t * 1.4)) ** 2 if t < 0.72 else (1.0 - t) / 0.28 * 0.8
        crackle = rnd.uniform(-1.0, 1.0) * 0.4 if rnd.random() < 0.004 else 0.0
        out.append((low * 1.6 + crackle) * env * 0.7)
    return out


def wind(seconds=10.0, fade=1.0, seed=13):
    """Vento: ruído grave que sobe e desce devagar (rajadas)."""
    rnd = random.Random(seed)
    n = int(RATE * (seconds + fade))
    out = [0.0] * n
    low = slow = 0.0
    for i in range(n):
        low += (rnd.uniform(-1.0, 1.0) - low) * 0.04
        slow += (low - slow) * 0.004
        gust = 0.55 + 0.45 * math.sin(i / RATE * 0.9) * math.sin(i / RATE * 0.37 + 1.0)
        out[i] = (low - slow) * gust
    m = int(RATE * seconds)
    f = int(RATE * fade)
    for i in range(f):
        t = i / f
        out[i] = out[i] * math.sin(t * math.pi / 2) + out[m + i] * math.cos(t * math.pi / 2)
    out = out[:m]
    peak = max(abs(v) for v in out)
    return [v / peak * 0.7 for v in out]


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
    save("rain_loop.wav", rain())
    save("fire_whoosh.wav", whoosh())
    save("wind_loop.wav", wind())


if __name__ == "__main__":
    main()
