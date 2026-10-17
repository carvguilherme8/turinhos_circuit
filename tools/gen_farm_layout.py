"""Traçado da Pista da Fazenda (motocross ao ar livre), recriado de um vídeo onboard de uma volta.

O vídeo dá a sequência de seções (retas, curvas com direção e ângulo aproximado, subidas e
descidas). Este script monta o traçado como uma "tartaruga" (anda reto, faz curva de raio R):
  1. sorteia pequenas variações nos ângulos das curvas, mantendo o giro total em 360°;
  2. com os ângulos fixos, o ponto final depende linearmente dos comprimentos das retas, então
     o fechamento da volta sai direto de um mínimos quadrados (menor mudança nas retas);
  3. descarta traçados em que trechos distantes na volta ficam perto demais (cruzam/encostam)
e guarda o melhor. Grava os pontos de controle (x, altura, z) para a cena.

Uso: python tools/gen_farm_layout.py [--preview mapa.png] [--tries 4000]
"""
import argparse
import math

import numpy as np

# Seções em ordem de corrida, começando na reta da largada.
# ("S", comprimento m, altura no fim m, nota) | ("T", ângulo graus (+ esquerda), raio m, altura no fim, nota)
SECTIONS = [
    ("S", 60.0, 10.0, "reta da largada (torre do bandeirinha), barranco à direita"),
    ("T", -30.0, 40.0, 11.0, "curva longa à direita subindo"),
    ("S", 22.0, 13.0, "crista"),
    ("T", -180.0, 9.0, 11.0, "grampo à direita (pneus)"),
    ("S", 45.0, 6.0, "descida com público"),
    ("T", 90.0, 16.0, 3.0, "esquerda descendo junto ao barranco"),
    ("S", 22.0, 2.0, "lombada no vale"),
    ("T", 140.0, 22.0, 2.0, "esquerda longa nas barracas"),
    ("S", 45.0, 5.0, "reta na sombra, subindo"),
    ("T", 120.0, 18.0, 7.0, "esquerda na encosta"),
    ("S", 18.0, 7.5, ""),
    ("T", -40.0, 20.0, 8.0, "S (direita)"),
    ("T", 55.0, 20.0, 8.0, "S (esquerda) até a crista"),
    ("S", 75.0, 1.0, "descida longa com ondulações"),
    ("T", -180.0, 9.0, 1.0, "grampo à direita no fundo"),
    ("S", 50.0, 4.0, "subida para o salto grande"),
    ("T", 105.0, 20.0, 6.0, "esquerda subindo"),
    ("S", 15.0, 7.0, ""),
    ("T", 80.0, 25.0, 9.0, "esquerda longa"),
    ("S", 35.0, 10.0, "costelas"),
    ("T", 180.0, 9.0, 11.0, "grampo à esquerda sob as árvores"),
    ("S", 30.0, 8.0, "descida na sombra"),
    ("T", -160.0, 16.0, 7.0, "direita"),
    ("S", 70.0, 10.0, "reta com step-up / mesa"),
    ("T", 180.0, 20.0, 10.0, "esquerda junto ao público"),
]
TRACK_WIDTH = 8.0
MIN_GAP = TRACK_WIDTH + 8.0  # distância mínima entre trechos que não são vizinhos na volta
STEP = 2.0
# Variação sorteada nos ângulos (graus): curvas comuns e grampos (|ângulo| >= 170°).
ANGLE_JITTER = 35.0
HAIRPIN_JITTER = 20.0
MIN_STRAIGHT_FACTOR = 0.6


def straights_and_turns():
    s_idx = [k for k, s in enumerate(SECTIONS) if s[0] == "S"]
    t_idx = [k for k, s in enumerate(SECTIONS) if s[0] == "T"]
    return s_idx, t_idx


def headings(angles):
    """Rumo (radianos) no início de cada seção, para os ângulos dados das curvas."""
    h, out = 0.0, []
    for k, s in enumerate(SECTIONS):
        out.append(h)
        if s[0] == "T":
            h += math.radians(angles[k])
    return out, h


def solve_lengths(angles):
    """Comprimentos das retas que fecham a volta mudando o mínimo (mínimos quadrados)."""
    s_idx, t_idx = straights_and_turns()
    hs, _ = headings(angles)
    fixed = np.zeros(2)
    for k in t_idx:
        a = math.radians(angles[k])
        r = SECTIONS[k][2]
        chord = 2 * r * abs(math.sin(a / 2))
        mid = hs[k] + a / 2
        fixed += chord * np.array([math.cos(mid), math.sin(mid)])
    A = np.array([[math.cos(hs[k]) for k in s_idx], [math.sin(hs[k]) for k in s_idx]])
    nom = np.array([SECTIONS[k][1] for k in s_idx])
    w_inv = np.diag(nom ** 2)  # retas longas aceitam mudar mais
    lam = np.linalg.solve(A @ w_inv @ A.T, -fixed - A @ nom)
    lengths = nom + w_inv @ A.T @ lam
    return dict(zip(s_idx, lengths)), np.sum(((lengths - nom) / nom) ** 2)


def trace(angles, lengths):
    x = np.zeros(2)
    heading = 0.0
    h0 = SECTIONS[-1][-2]
    pts, hs, sec = [x.copy()], [h0], [len(SECTIONS) - 1]
    for k, s in enumerate(SECTIONS):
        if s[0] == "S":
            length = lengths[k]
            n = max(1, int(length / STEP))
            for i in range(1, n + 1):
                x = x + np.array([math.cos(heading), math.sin(heading)]) * (length / n)
                pts.append(x.copy()); hs.append(h0 + (s[2] - h0) * i / n); sec.append(k)
            h0 = s[2]
        else:
            a = math.radians(angles[k])
            arc = abs(a) * s[2]
            n = max(2, int(arc / STEP))
            for i in range(1, n + 1):
                prev = heading
                heading += a / n
                x = x + np.array([math.cos((prev + heading) / 2), math.sin((prev + heading) / 2)]) * (arc / n)
                pts.append(x.copy()); hs.append(h0 + (s[3] - h0) * i / n); sec.append(k)
            h0 = s[3]
    return np.array(pts), np.array(hs), np.array(sec)


def proximity(pts):
    d = np.linalg.norm(pts[:, None, :] - pts[None, :, :], axis=2)
    n = len(pts)
    idx = np.arange(n)
    along = np.abs(idx[:, None] - idx[None, :])
    along = np.minimum(along, n - along) * STEP
    near = (along > MIN_GAP * 4.0) & (d < MIN_GAP)
    return float(np.sum((MIN_GAP - d[near]) ** 2))


def random_angles(rng):
    angles = {k: s[1] for k, s in enumerate(SECTIONS) if s[0] == "T"}
    free = [k for k in angles if abs(angles[k]) < 170.0]
    for k in angles:
        angles[k] += rng.normal(0.0, (ANGLE_JITTER if k in free else HAIRPIN_JITTER) * 0.5)
    # mantém o giro total em +360° espalhando a diferença nas curvas livres
    diff = 360.0 - sum(angles.values())
    for k in free:
        angles[k] += diff / len(free)
    return angles


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default="")
    ap.add_argument("--tries", type=int, default=4000)
    args = ap.parse_args()
    rng = np.random.default_rng(5)
    best = None
    for attempt in range(args.tries):
        angles = random_angles(rng)
        lengths, change = solve_lengths(angles)
        if min(lengths[k] / SECTIONS[k][1] for k in lengths) < MIN_STRAIGHT_FACTOR:
            continue
        pts = trace(angles, lengths)[0]
        bad = proximity(pts[::2])
        angle_change = sum(((angles[k] - SECTIONS[k][1]) / 45.0) ** 2 for k in angles)
        score = bad * 10.0 + change * 20.0 + angle_change
        if best is None or score < best[0]:
            best = (score, angles, lengths, bad)
    score, angles, lengths, bad = best
    pts, hs, sec = trace(angles, lengths)
    total = np.linalg.norm(np.diff(pts, axis=0), axis=1).sum()
    print(f"melhor: encosta {bad:.1f}  fecha {np.linalg.norm(pts[-1] - pts[0]):.2f} m  comprimento {total:.0f} m")
    for k, s in enumerate(SECTIONS):
        new = lengths[k] if s[0] == "S" else angles[k]
        print(f"  {s[0]} {s[1]:7.1f} -> {new:7.1f}   {s[-1]}")
    seg = np.r_[0.0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    print("início de cada seção (m ao longo da volta):")
    for k in range(len(SECTIONS)):
        first = int(np.argmax(sec == k))
        print(f"  {k + 1:2d} {seg[first]:6.1f}  {SECTIONS[k][-1]}")
    keep = list(range(0, len(pts) - 1, 4))
    ctrl = [(round(float(pts[i][0]), 1), round(float(hs[i]), 2), round(float(pts[i][1]), 1)) for i in keep]
    print(f"PONTOS {len(ctrl)}")
    print("PackedVector3Array(" + ", ".join(f"{x}, {h}, {z}" for x, h, z in ctrl) + ")")
    if args.preview:
        from PIL import Image, ImageDraw
        p = pts - pts.min(0)
        sc = 3.0
        img = Image.new("RGB", (int(p[:, 0].max() * sc) + 80, int(p[:, 1].max() * sc) + 80), (70, 120, 60))
        d = ImageDraw.Draw(img)
        q = [(a * sc + 40, b * sc + 40) for a, b in p]
        hmin, hmax = hs.min(), hs.max()
        for i in range(len(q) - 1):
            t = (hs[i] - hmin) / (hmax - hmin + 1e-6)
            d.line([q[i], q[i + 1]], fill=(int(120 + 130 * t), int(60 + 90 * t), 30), width=int(TRACK_WIDTH * sc))
        d.ellipse([q[0][0] - 10, q[0][1] - 10, q[0][0] + 10, q[0][1] + 10], outline="white", width=3)
        last = -1
        for i, k in enumerate(sec):
            if k != last:
                d.text((q[i][0] + 14, q[i][1] - 4), str(k + 1), fill="white")
                last = k
        img.save(args.preview)


if __name__ == "__main__":
    main()
