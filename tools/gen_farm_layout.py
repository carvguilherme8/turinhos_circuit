"""Traçado da Pista da Fazenda (motocross ao ar livre, em morro).

O traçado é descrito como uma sequência de seções (retas e curvas com altura no fim), cada
reta com os seus obstáculos. O script monta a linha como uma "tartaruga" (anda reto, faz curva
de raio R) e:
  1. sorteia pequenas variações nos ângulos das curvas, mantendo o giro total em 360°;
  2. com os ângulos fixos, o ponto final depende linearmente dos comprimentos das retas, então
     o fechamento da volta sai direto de um mínimos quadrados (menor mudança nas retas);
  3. descarta traçados em que trechos distantes na volta ficam perto demais;
e grava o melhor no script da pista (entre as marcas "# <layout>" e "# </layout>"):
pontos de controle (x, altura, z), saltos e costelas.

Uso: python tools/gen_farm_layout.py [--preview mapa.png] [--tries 12000] [--apply]
"""
import argparse
import math
import os
import re

import numpy as np

# Tipos de salto (iguais aos do OutdoorTrack): lombada, mesa, double.
ROLLER, TABLE, DOUBLE = 0, 1, 2

# Seções em ordem de corrida, começando na reta da largada (ângulos: + = esquerda).
# ("S", comprimento m, altura no fim m, [obstáculos], nota)
#    obstáculo: ("roller"|"table"|"double", posição 0..1 na reta, comprimento m, altura m)
#               ("whoops", posição 0..1, quantidade, altura m)
# ("T", ângulo graus, raio m, altura no fim m, nota)
SECTIONS = [
    ("S", 85.0, 10.0, [("table", 0.62, 22.0, 2.0)], "reta da largada, mesa depois da chegada"),
    ("T", 100.0, 22.0, 10.5, "primeira curva (holeshot), berm larga"),
    ("S", 60.0, 12.0, [("roller", 0.06, 8.0, 1.0), ("double", 0.32, 20.0, 1.7)],
     "ritmo: lombada e double (espaço para frear antes da curva)"),
    ("T", -120.0, 15.0, 12.5, "direita com berm"),
    ("S", 55.0, 16.0, [("table", 0.45, 24.0, 2.8)], "subida para a mesa grande no alto do morro"),
    ("T", 180.0, 10.0, 16.0, "grampo à esquerda no topo"),
    ("S", 75.0, 7.0, [("double", 0.25, 30.0, 2.4)], "descida longa com double em descida"),
    ("T", -70.0, 30.0, 5.5, "S rápido (direita)"),
    ("T", 80.0, 30.0, 4.5, "S rápido (esquerda)"),
    ("S", 50.0, 4.5, [("whoops", 0.15, 11, 0.75)], "costelas no vale"),
    ("T", -170.0, 11.0, 5.0, "grampo à direita"),
    ("S", 65.0, 8.0, [("double", 0.06, 26.0, 2.0), ("double", 0.55, 26.0, 2.0)], "dois doubles subindo"),
    ("T", 120.0, 20.0, 10.0, "esquerda com berm, subindo"),
    ("S", 45.0, 12.0, [("table", 0.4, 22.0, 2.2)], "mesa"),
    ("T", 150.0, 14.0, 12.0, "esquerda fechada"),
    ("S", 40.0, 10.0, [("table", 0.15, 22.0, 2.0)], "step-down: mesa descendo"),
    ("T", -60.0, 25.0, 10.0, "direita rápida"),
    ("T", 150.0, 20.0, 10.0, "última curva, entra na reta da largada"),
]
TRACK_WIDTH = 9.0
MIN_GAP = TRACK_WIDTH + 10.0  # distância mínima entre trechos que não são vizinhos na volta
STEP = 2.0
ANGLE_JITTER = 35.0
HAIRPIN_JITTER = 20.0
MIN_STRAIGHT_FACTOR = 0.75
MAX_STRAIGHT_FACTOR = 1.6
SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "tracks", "outdoor_track.gd")


def headings(angles):
    h, out = 0.0, []
    for k, s in enumerate(SECTIONS):
        out.append(h)
        if s[0] == "T":
            h += math.radians(angles[k])
    return out, h


def solve_lengths(angles):
    """Comprimentos das retas que fecham a volta mudando o mínimo (mínimos quadrados)."""
    s_idx = [k for k, s in enumerate(SECTIONS) if s[0] == "S"]
    hs, _ = headings(angles)
    fixed = np.zeros(2)
    for k, s in enumerate(SECTIONS):
        if s[0] == "T":
            a = math.radians(angles[k])
            chord = 2 * s[2] * abs(math.sin(a / 2))
            mid = hs[k] + a / 2
            fixed += chord * np.array([math.cos(mid), math.sin(mid)])
    A = np.array([[math.cos(hs[k]) for k in s_idx], [math.sin(hs[k]) for k in s_idx]])
    nom = np.array([SECTIONS[k][1] for k in s_idx])
    w_inv = np.diag(nom ** 2)
    lam = np.linalg.solve(A @ w_inv @ A.T, -fixed - A @ nom)
    lengths = nom + w_inv @ A.T @ lam
    return dict(zip(s_idx, lengths)), np.sum(((lengths - nom) / nom) ** 2)


def trace(angles, lengths):
    """Pontos (x, z), alturas, seção de cada ponto e distância de início de cada seção."""
    x = np.zeros(2)
    heading = 0.0
    h0 = SECTIONS[-1][3]
    pts, hs, sec, starts = [x.copy()], [h0], [len(SECTIONS) - 1], []
    travelled = 0.0
    for k, s in enumerate(SECTIONS):
        starts.append(travelled)
        if s[0] == "S":
            length, h1 = lengths[k], s[2]
            n = max(1, int(length / STEP))
            for i in range(1, n + 1):
                x = x + np.array([math.cos(heading), math.sin(heading)]) * (length / n)
                pts.append(x.copy()); hs.append(h0 + (h1 - h0) * i / n); sec.append(k)
            travelled += length
        else:
            a = math.radians(angles[k])
            arc, h1 = abs(a) * s[2], s[3]
            n = max(2, int(arc / STEP))
            for i in range(1, n + 1):
                prev = heading
                heading += a / n
                x = x + np.array([math.cos((prev + heading) / 2), math.sin((prev + heading) / 2)]) * (arc / n)
                pts.append(x.copy()); hs.append(h0 + (h1 - h0) * i / n); sec.append(k)
            travelled += arc
        h0 = h1
    return np.array(pts), np.array(hs), np.array(sec), starts


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
    diff = 360.0 - sum(angles.values())
    for k in free:
        angles[k] += diff / len(free)
    return angles


def features(lengths, starts):
    """Saltos (distância, comprimento, altura, tipo) e costelas (distância, quantidade, altura)."""
    jumps, whoops = [], []
    kinds = {"roller": ROLLER, "table": TABLE, "double": DOUBLE}
    for k, s in enumerate(SECTIONS):
        if s[0] != "S":
            continue
        for f in s[3]:
            at = starts[k] + f[1] * lengths[k]
            if f[0] == "whoops":
                whoops.append((round(at, 1), f[2], f[3]))
            else:
                jumps.append((round(at, 1), f[2], f[3], kinds[f[0]]))
    return jumps, whoops


def apply(ctrl, jumps, whoops):
    """Grava pontos, saltos e costelas no script da pista (entre as marcas de layout)."""
    rows = []
    for i in range(0, len(ctrl), 6):
        rows.append("\t" + ", ".join(f"Vector3({x:g}, {h:g}, {z:g})" for x, h, z in ctrl[i:i + 6]) + ",")
    block = ["# <layout> (gerado por tools/gen_farm_layout.py --apply)",
             "## Pontos de controle da linha central, em ordem de corrida (laço fechado): x, altura, z.",
             "@export var control_points: PackedVector3Array = PackedVector3Array([",
             *rows,
             "]):",
             "\tset(value):",
             "\t\tcontrol_points = value",
             "\t\t_queue_rebuild()",
             "## Saltos moldados na pista: (distância desde o primeiro ponto, comprimento m, altura m,",
             "## tipo: 0 = lombada, 1 = mesa, 2 = double).",
             "@export var jumps: Array[Vector4] = [",
             *["\tVector4(%g, %g, %g, %d)," % j for j in jumps],
             "]:",
             "\tset(value):",
             "\t\tjumps = value",
             "\t\t_queue_rebuild()",
             "## Costelas: (distância do início, quantidade, altura m), uma a cada `whoop_spacing` m.",
             "@export var whoops: Array[Vector3] = [",
             *["\tVector3(%g, %g, %g)," % w for w in whoops],
             "]:",
             "\tset(value):",
             "\t\twhoops = value",
             "\t\t_queue_rebuild()",
             "# </layout>"]
    src = open(SCRIPT, encoding="utf-8").read()
    if "# <layout>" not in src:
        raise SystemExit("marcas de layout não encontradas em " + SCRIPT)
    new = re.sub(r"# <layout>.*?# </layout>", lambda m: "\n".join(block), src, flags=re.S)
    open(SCRIPT, "w", encoding="utf-8", newline="\n").write(new)
    print("gravado em", os.path.normpath(SCRIPT))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default="")
    ap.add_argument("--tries", type=int, default=12000)
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    rng = np.random.default_rng(5)
    best = None
    for _ in range(args.tries):
        angles = random_angles(rng)
        lengths, change = solve_lengths(angles)
        factors = [lengths[k] / SECTIONS[k][1] for k in lengths]
        if min(factors) < MIN_STRAIGHT_FACTOR or max(factors) > MAX_STRAIGHT_FACTOR:
            continue
        pts = trace(angles, lengths)[0]
        bad = proximity(pts[::2])
        angle_change = sum(((angles[k] - SECTIONS[k][1]) / 45.0) ** 2 for k in angles)
        score = bad * 10.0 + change * 20.0 + angle_change
        if best is None or score < best[0]:
            best = (score, angles, lengths, bad)
    if best is None:
        raise SystemExit("nenhum traçado válido; afrouxe os limites")
    score, angles, lengths, bad = best
    pts, hs, sec, starts = trace(angles, lengths)
    total = np.linalg.norm(np.diff(pts, axis=0), axis=1).sum()
    print(f"melhor: encosta {bad:.1f}  fecha {np.linalg.norm(pts[-1] - pts[0]):.2f} m  comprimento {total:.0f} m")
    for k, s in enumerate(SECTIONS):
        new = lengths[k] if s[0] == "S" else angles[k]
        print(f"  {k + 1:2d} {s[0]} {s[1]:7.1f} -> {new:7.1f}  em {starts[k]:6.1f} m  {s[-1]}")
    jumps, whoops = features(lengths, starts)
    # Pontos de controle a cada ~8 m; z espelhado: no Godot, de +X para +Z é virar à direita.
    keep = list(range(0, len(pts) - 1, 4))
    ctrl = [(round(float(pts[i][0]), 1), round(float(hs[i]), 2), round(float(-pts[i][1]), 1)) for i in keep]
    print(f"{len(ctrl)} pontos, {len(jumps)} saltos, {len(whoops)} trechos de costelas")
    if args.apply:
        apply(ctrl, jumps, whoops)
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
        seg = np.r_[0.0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
        for j in jumps:
            i = min(int(np.searchsorted(seg, j[0])), len(q) - 1)
            d.ellipse([q[i][0] - 6, q[i][1] - 6, q[i][0] + 6, q[i][1] + 6], fill=("yellow", "white", "red")[j[3]])
        for w in whoops:
            i = min(int(np.searchsorted(seg, w[0])), len(q) - 1)
            d.rectangle([q[i][0] - 5, q[i][1] - 5, q[i][0] + 5, q[i][1] + 5], fill="cyan")
        d.ellipse([q[0][0] - 10, q[0][1] - 10, q[0][0] + 10, q[0][1] + 10], outline="white", width=3)
        last = -1
        for i, k in enumerate(sec):
            if k != last:
                d.text((q[i][0] + 14, q[i][1] - 4), str(k + 1), fill="white")
                last = k
        img.save(args.preview)


if __name__ == "__main__":
    main()
