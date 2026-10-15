"""Gera o piloto do Turinhos Circuit no estilo boneco do Minecraft.

Saídas (em assets/models/riders/rider/):
  rider.bbmodel  projeto Blockbench (Bedrock entity, UV por face, textura embutida)
  rider.png      textura pixel art (1 texel por unidade, como as skins do Minecraft)
  rider.glb      modelo para o Godot (usa o rider.png ao lado)

Proporções do jogador do Minecraft (em unidades = pixels de skin): cabeça 8x8x8,
tronco 8x12x4, braços e pernas 4x12x4. Pés em y = 0 (em pé), frente em -Z, direita em +X.
A pose de pilotagem vem da rotação dos "ossos" (grupos), como nos modelos do Minecraft:
pernas até as pedaleiras, tronco inclinado para frente, braços até as manoplas.
No Godot o piloto entra com escala RIDER_SCALE e deslocamento RIDER_OFFSET (cena da moto).

Uso: python tools/gen_rider.py [--primary 2a5ce8] [--accent f0d23c] [--out pasta]
"""
import argparse
import math
import os
import random

import gen_motocross as gm
from gen_motocross import Cube, shade, hex_color

# Encaixe na moto (unidades da moto = 1/16 m): moto = RIDER_SCALE * piloto + RIDER_OFFSET
RIDER_SCALE = 0.9
RIDER_OFFSET = (0.0, 6.8, 3.8)

LEAN = -30.0      # tronco inclinado para frente
HEAD_UP = 24.0    # cabeça compensa a inclinação para olhar a pista
ARM_X, ARM_Y = 80.0, 15.0
LEG_X, LEG_Z = 10.0, 11.0

GROUPS = [
    # (nome, pivô, pai, rotação (x, y, z) em graus)
    ("rider", (0, 0, 0), None, (0, 0, 0)),
    ("leg_r", (2, 12, 0), "rider", (LEG_X, 0, LEG_Z)),
    ("leg_l", (-2, 12, 0), "rider", (LEG_X, 0, -LEG_Z)),
    ("upper", (0, 12, 0), "rider", (LEAN, 0, 0)),
    ("head", (0, 24, 0), "upper", (HEAD_UP, 0, 0)),
    ("arm_r", (5, 22, 0), "upper", (ARM_X, -ARM_Y, 0)),
    ("arm_l", (-5, 22, 0), "upper", (ARM_X, ARM_Y, 0)),
]


class Palette:
    def __init__(self, primary, accent):
        self.primary = primary
        self.primary_dark = shade(primary, 0.7)
        self.accent = accent
        self.white = (242, 242, 236)
        self.trim = (40, 40, 46)
        self.pants = (40, 44, 70)
        self.boot = (226, 226, 222)
        self.buckle = (70, 72, 80)
        self.glove = (32, 32, 38)
        self.skin = (232, 176, 128)
        self.skin_dark = (196, 136, 96)
        self.mouth = (120, 70, 50)
        self.lens_dark = (24, 36, 74)
        self.lens_light = (80, 190, 235)
        self.vent = (30, 30, 34)


# ---------------------------------------------------------------- utilidades de pintura

def grain(p, amount=0.05):
    return gm.noise(p, amount)


def mc_shade(face):
    """Sombreado leve por face, como nas texturas do Minecraft."""
    return {"up": 1.06, "down": 0.78, "east": 0.95, "west": 0.95}.get(face, 1.0)


def finish(c, p, face, amount=0.05):
    return shade(c, grain(p, amount) * mc_shade(face))


# Dígitos 4x7 das costas (largura par para centralizar exato no tronco de 8).
DIGITS_BIG = {
    "0": [".##.", "#..#", "#..#", "#..#", "#..#", "#..#", ".##."],
    "1": ["..#.", ".##.", "..#.", "..#.", "..#.", "..#.", ".###"],
    "2": [".##.", "#..#", "...#", "..#.", ".#..", "#...", "####"],
    "3": [".##.", "#..#", "...#", "..#.", "...#", "#..#", ".##."],
    "4": ["#..#", "#..#", "#..#", "####", "...#", "...#", "...#"],
    "5": ["####", "#...", "###.", "...#", "...#", "#..#", ".##."],
    "6": [".##.", "#...", "###.", "#..#", "#..#", "#..#", ".##."],
    "7": ["####", "...#", "..#.", "..#.", ".#..", ".#..", ".#.."],
    "8": [".##.", "#..#", "#..#", ".##.", "#..#", "#..#", ".##."],
    "9": [".##.", "#..#", "#..#", ".###", "...#", "...#", ".##."],
}
BACK_NUMBER = "8"


def glyph_hit(glyph, i, j):
    return 0 <= j < len(glyph) and 0 <= i < len(glyph[0]) and glyph[j][i] == "#"


def texel(uv, w, h):
    return math.floor(uv[0] * w), math.floor(uv[1] * h)


# ---------------------------------------------------------------- pintores

# Casco do capacete desenhado pixel a pixel (9x9 por face), visto de fora.
# W branco, P cor principal, D principal escura, A destaque, T borracha/sombra,
# K elástico, S pele, N nariz, M boca.
HELMET_FACES = {
    "north": [
        "WWWPPPWWW",
        "WWAPPPAWW",
        "TTTTTTTTT",
        "TTTTTTTTT",
        "TTTTTTTTT",
        "TSSSNSSST",
        "TSSMMMSST",
        "TTTTTTTTT",
        "TTTTTTTTT",
    ],
    # Lateral direita: a esquerda da imagem é a traseira, a direita é a frente.
    "east": [
        "WWWWWWWWW",
        "PPPPPPPWW",
        "PAAAAAPPW",
        "PPPPPPPWW",
        "KAKKAKKAK",
        "WWWWWWWWW",
        "WWWWWWAAW",
        "WWWWWWWWW",
        "TTTTTTTTT",
    ],
    "south": [
        "WWWPPPWWW",
        "WWAPPPAWW",
        "WWWPPPWWW",
        "WWWPPPWWW",
        "KAKKAKKAK",
        "WWWPPPWWW",
        "WWWPPPWWW",
        "WWWPPPWWW",
        "TTTTTTTTT",
    ],
    # Topo: a primeira linha é a frente.
    "up": [
        "WWAPPPAWW",
        "WTAPPPATW",
        "WWAPPPAWW",
        "WTAPPPATW",
        "WWAPPPAWW",
        "WWAPPPAWW",
        "WWAPPPAWW",
        "WWAPPPAWW",
        "WWAPPPAWW",
    ],
}
HELMET_FACES["west"] = [row[::-1] for row in HELMET_FACES["east"]]


def helmet_shell(pal, cube, face, p, uv, w, h):
    if face == "down":
        return finish(pal.trim, p, face)
    i, j = texel(uv, w, h)
    rows = HELMET_FACES[face]
    key = rows[min(j, len(rows) - 1)][min(i, len(rows[0]) - 1)]
    colors = {"W": pal.white, "P": pal.primary, "D": pal.primary_dark, "A": pal.accent,
              "T": pal.trim, "K": pal.trim, "S": pal.skin, "N": pal.skin_dark, "M": pal.mouth}
    return finish(colors[key], p, face, 0.035)


def goggles(pal, cube, face, p, uv, w, h):
    i, j = texel(uv, w, h)
    if face == "north":
        border = i == 0 or i == w - 1 or j == 0 or j == h - 1
        if border:
            corner = (i in (0, w - 1)) and (j in (0, h - 1))
            return finish(pal.primary if corner else pal.trim, p, face)
        t = (i + j * 0.5) / max(1, w)
        c = gm.mix(pal.lens_dark, pal.lens_light, 0.15 + 0.75 * t)
        if (i, j) in ((w - 3, 1), (w - 2, 1), (w - 2, 2)):
            c = (255, 255, 255)  # reflexo
        return c
    return finish(pal.trim, p, face)


def chin_bar(pal, cube, face, p, uv, w, h):
    i, j = texel(uv, w, h)
    c = pal.primary
    if face == "north":
        if j == 0:
            c = pal.white
        elif j >= 1 and i % 2 == 1 and 1 <= i <= w - 2:
            c = pal.vent  # respiros
    elif face == "up":
        c = pal.white
    elif face == "down":
        c = pal.trim
    return finish(c, p, face)


def peak(pal, cube, face, p, uv, w, h):
    c = pal.primary
    if face == "up":
        c = pal.white if abs(p[0]) < 1.0 else (pal.accent if abs(p[0]) < 1.5 else pal.primary)
    elif face == "down":
        c = pal.trim
    elif face == "north":
        c = pal.accent
    return finish(c, p, face)


def jersey(pal, cube, face, p, uv, w, h):
    x, y, z = p
    i, j = texel(uv, w, h)
    c = pal.primary
    if y > 23.0:
        c = pal.trim  # gola
    elif face in ("east", "west"):
        c = pal.white if 1 <= i <= 2 else pal.primary_dark
    elif face == "south":
        glyph = DIGITS_BIG[BACK_NUMBER]
        gi, gj = i - (w - len(glyph[0])) // 2, j - 2
        if glyph_hit(glyph, gi, gj):
            c = pal.white
    elif face == "north":
        if 17.0 < y < 19.0:
            c = pal.white  # faixa no peito
        elif 19.0 <= y < 20.0 and abs(x) < 2.5:
            c = pal.accent
    return finish(c, p, face)


def arm(pal, cube, face, p, uv, w, h):
    y = p[1]
    if y < 15.0:
        c = pal.glove if not (face == "up" or (14.0 <= y and face != "down")) else pal.primary_dark
        if y < 13.0 and face in ("east", "west"):
            c = pal.accent if int(y) == 12 else pal.glove  # detalhe na luva
        return finish(c, p, face)
    c = pal.primary
    if 18.0 <= y < 19.5:
        c = pal.white  # faixa da manga
    if face in ("east", "west") and y >= 19.5:
        c = pal.primary_dark
    return finish(c, p, face)


def leg(pal, cube, face, p, uv, w, h):
    y = p[1]
    if face == "down":
        return finish(pal.trim, p, face)  # sola
    if y < 7.0:
        c = pal.boot
        if face != "up" and int(y) in (2, 4, 6):
            c = pal.buckle  # fivelas
        if y < 1.0:
            c = pal.trim
        return finish(c, p, face)
    c = pal.pants
    if face in ("east", "west") and abs(p[2]) < 0.8:
        c = pal.primary  # faixa lateral da calça
    if 8.0 <= y < 10.0 and face == "north":
        c = shade(pal.pants, 1.35)  # joelheira
    return finish(c, p, face)


def build_cubes():
    C = []
    # Pernas (pés em y=0)
    C.append(Cube("leg_r", "leg_r", (0, 0, -2), (4, 12, 2), leg))
    C.append(Cube("leg_l", "leg_l", (-4, 0, -2), (0, 12, 2), leg))
    C.append(Cube("boot_toe_r", "leg_r", (0.3, 0, -3.2), (3.7, 2, -2), leg))
    C.append(Cube("boot_toe_l", "leg_l", (-3.7, 0, -3.2), (-0.3, 2, -2), leg))
    # Tronco e braços
    C.append(Cube("body", "upper", (-4, 12, -2), (4, 24, 2), jersey))
    C.append(Cube("arm_r", "arm_r", (4, 12, -2), (8, 24, 2), arm))
    C.append(Cube("arm_l", "arm_l", (-8, 12, -2), (-4, 24, 2), arm))
    # Capacete (no lugar da cabeça; um pouco maior que ela, como a "camada" do Minecraft)
    C.append(Cube("helmet", "head", (-4.5, 24, -4.5), (4.5, 33, 4.5), helmet_shell))
    C.append(Cube("goggles", "head", (-3.5, 27.6, -5.4), (3.5, 31.0, -4.5), goggles))
    C.append(Cube("chin_bar", "head", (-3.5, 24.0, -6.2), (3.5, 26.2, -4.5), chin_bar))
    C.append(Cube("peak", "head", (-4.0, 32.0, -8.0), (4.0, 33.0, -4.0), peak, ("x", 22.5), (0, 32.5, -4.0)))
    return C


# ---------------------------------------------------------------- verificação do encaixe

def _rot_point(p, pivot, degrees):
    q = gm.euler_to_quat(degrees)
    v = tuple(p[k] - pivot[k] for k in range(3))
    # v' = q v q*
    x, y, z, w = q
    vx, vy, vz = v
    tx = 2 * (y * vz - z * vy)
    ty = 2 * (z * vx - x * vz)
    tz = 2 * (x * vy - y * vx)
    r = (vx + w * tx + (y * tz - z * ty), vy + w * ty + (z * tx - x * tz), vz + w * tz + (x * ty - y * tx))
    return tuple(r[k] + pivot[k] for k in range(3))


def to_bike(p, chain):
    """Aplica as rotações dos grupos (do mais interno para o de fora) e leva para a moto."""
    for name in chain:
        g = next(g for g in GROUPS if g[0] == name)
        p = _rot_point(p, g[1], g[3])
    return tuple(RIDER_SCALE * p[k] + RIDER_OFFSET[k] for k in range(3))


def report_fit():
    hand = to_bike((6, 12, 0), ["arm_r", "upper"])
    foot = to_bike((2, 0, 0), ["leg_r"])
    hip = to_bike((0, 12, 0), ["upper"])
    top = to_bike((0, 33, 0), ["head", "upper"])
    fmt = lambda v: "(%.1f, %.1f, %.1f)" % v
    print("  mão direita", fmt(hand), "| manopla (7.6, 20.4, -6.6)")
    print("  pé direito ", fmt(foot), "| pedaleira (3.9, 6.8, 1.8)")
    print("  quadril    ", fmt(hip), "| banco y=18")
    print("  topo do capacete", fmt(top))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--primary", default="2a5ce8", help="cor principal da roupa e do capacete (hex)")
    ap.add_argument("--accent", default="f0d23c", help="cor de detalhe (hex)")
    ap.add_argument("--name", default="rider")
    ap.add_argument("--number", default="8", choices=list(DIGITS_BIG), help="número nas costas")
    ap.add_argument("--texture-only", action="store_true",
                    help="gera só o .png (variação de cor do mesmo modelo, mesma UV)")
    ap.add_argument("--out", default=os.path.join(here, "..", "assets", "models", "riders", "rider"))
    args = ap.parse_args()
    global BACK_NUMBER
    BACK_NUMBER = args.number

    random.seed(11)
    pal = Palette(hex_color(args.primary), hex_color(args.accent))
    cubes = build_cubes()
    img = gm.pack_and_paint(cubes, pal)
    os.makedirs(args.out, exist_ok=True)
    img.save(os.path.join(args.out, args.name + ".png"))
    if not args.texture_only:
        gm.write_bbmodel(cubes, img, os.path.join(args.out, args.name + ".bbmodel"), args.name, GROUPS)
        gm.write_glb(cubes, img, os.path.join(args.out, args.name + ".glb"), args.name, GROUPS)
    print(f"{len(cubes)} cubos, textura {img.width}x{img.height} -> {os.path.normpath(args.out)}")
    report_fit()


if __name__ == "__main__":
    main()
