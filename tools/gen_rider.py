"""Gera o piloto voxel do Turinhos Circuit (mesma estética e escala da moto).

Saídas (em assets/models/riders/rider/):
  rider.bbmodel  projeto Blockbench (Bedrock entity, UV por face, textura embutida)
  rider.png      textura pixel art
  rider.glb      modelo para o Godot (usa o rider.png ao lado)

Mesmo espaço da moto: frente em -Z, chão em y = 0, 16 px = 1 m. Posição de ataque:
pés nas pedaleiras, mãos nas manoplas, sentado na frente do banco.
Grupos: legs (fixo), upper (tronco/braços/cabeça, gira no quadril para o peso do piloto)
e head (gira no pescoço).

Uso: python tools/gen_rider.py [--primary 2a5ce8] [--out pasta]
"""
import argparse
import math
import os
import random

import gen_motocross as gm
from gen_motocross import Cube, mirror_x, shade, noise, edge_factor, face_light, hex_color

HIP = (0.0, 20.0, 4.5)
NECK = (0.0, 28.0, 1.5)

GROUPS = [
    ("rider", (0, 0, 0), None),
    ("legs", (0, 0, 0), "rider"),
    ("upper", HIP, "rider"),
    ("head", NECK, "upper"),
]


class RiderPalette:
    def __init__(self, primary):
        self.primary = primary
        self.primary_dark = shade(primary, 0.72)
        self.white = (236, 236, 230)
        self.pants = (44, 48, 74)
        self.boot = (214, 214, 210)
        self.boot_dark = (120, 122, 126)
        self.glove = (34, 34, 40)
        self.lens = (36, 44, 70)
        self.lens_shine = (110, 170, 230)
        self.strap = (60, 60, 68)


def flat(color_name, edges=True):
    def paint(pal, cube, face, p, uv, w, h):
        f = noise(p, 0.05) * face_light(face)
        if edges:
            f *= edge_factor(uv, w, h)
        return shade(getattr(pal, color_name), f)
    return paint


DIGIT_8 = ["###", "#.#", "###", "#.#", "###"]


def jersey(pal, cube, face, p, uv, w, h):
    c = pal.primary
    if face == "south" and w >= 5 and h >= 6:
        # Número nas costas.
        i = math.floor(uv[0] * w - (w - 3) / 2)
        j = math.floor(uv[1] * h - (h - 5) / 2 + 1)
        if 0 <= j < 5 and 0 <= i < 3 and DIGIT_8[j][i] == "#":
            c = pal.white
    elif face in ("east", "west") and 0.4 < uv[0] < 0.6:
        c = pal.white  # faixa lateral
    elif face == "north" and uv[1] < 0.25:
        c = pal.primary_dark  # gola
    return shade(c, noise(p, 0.05) * face_light(face) * edge_factor(uv, w, h))


def sleeve(pal, cube, face, p, uv, w, h):
    c = pal.white if face in ("east", "west") and 0.4 < uv[1] < 0.55 else pal.primary
    return shade(c, noise(p, 0.05) * face_light(face) * edge_factor(uv, w, h))


def helmet(pal, cube, face, p, uv, w, h):
    c = pal.white
    if abs(p[0]) < 0.8 and face in ("up", "north", "south"):
        c = pal.primary  # faixa no meio do capacete
    if 30.1 <= p[1] <= 31.1:
        if face == "north":
            c = pal.lens_shine if (p[0] > 0.6 and p[1] > 30.7) else pal.lens  # óculos
        elif face in ("east", "west", "south"):
            c = pal.strap  # elástico do óculos
    return shade(c, noise(p, 0.04) * face_light(face) * edge_factor(uv, w, h))


def boot(pal, cube, face, p, uv, w, h):
    c = pal.boot
    if face in ("east", "west", "north") and int(p[1] * 1.0) % 3 == 0:
        c = pal.boot_dark  # fivelas
    return shade(c, noise(p, 0.04) * face_light(face) * edge_factor(uv, w, h))


def glove(pal, cube, face, p, uv, w, h):
    c = pal.primary if face == "up" else pal.glove
    return shade(c, noise(p, 0.05) * face_light(face))


def build_cubes():
    C = []
    # ---- pernas (fixas na moto)
    C += mirror_x("boot", "legs", (2.8, 6.8, 0.0), (5.0, 10.0, 3.6), boot)
    C += mirror_x("boot_toe", "legs", (3.0, 6.8, -1.4), (4.8, 8.4, 0.0), boot)
    C += mirror_x("shin", "legs", (3.4, 9.5, 0.8), (5.2, 16.5, 2.8), boot, ("x", -22.5), (4.3, 9.5, 1.8))
    # Coxa quase deitada, subindo do joelho até o quadril (rotação até 45°, limite do Minecraft Java).
    C += mirror_x("thigh", "legs", (2.6, 15.6, -2.0), (4.8, 18.0, 5.0), flat("pants"), ("x", -22.5), (3.7, 16.8, -1.0))
    C.append(Cube("pelvis", "legs", (-2.6, 17.8, 2.4), (2.6, 21.0, 6.6), flat("pants")))

    # ---- tronco e braços (giram juntos no quadril)
    C.append(Cube("torso", "upper", (-3.0, 20.0, 2.0), (3.0, 28.5, 6.0), jersey, ("x", -22.5), HIP))
    C += mirror_x("upper_arm", "upper", (3.6, 21.8, 0.2), (5.4, 27.8, 2.2), sleeve, ("x", 45.0), (4.5, 27.3, 1.2))
    C += mirror_x("forearm", "upper", (4.8, 21.4, -6.4), (6.6, 23.2, -2.2), sleeve, ("x", -22.5), (5.7, 23.3, -2.4))
    C += mirror_x("glove", "upper", (6.4, 19.6, -7.6), (8.6, 21.6, -5.6), glove)

    # ---- cabeça
    C.append(Cube("helmet", "head", (-2.3, 28.0, -2.5), (2.3, 32.8, 2.2), helmet))
    C.append(Cube("chin_bar", "head", (-1.7, 28.0, -3.6), (1.7, 29.8, -2.5), flat("primary")))
    C.append(Cube("peak", "head", (-2.0, 32.0, -4.8), (2.0, 32.6, -2.0), flat("primary")))
    return C


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--primary", default="2a5ce8", help="cor principal da roupa e do capacete (hex)")
    ap.add_argument("--name", default="rider")
    ap.add_argument("--out", default=os.path.join(here, "..", "assets", "models", "riders", "rider"))
    args = ap.parse_args()

    random.seed(11)
    pal = RiderPalette(hex_color(args.primary))
    cubes = build_cubes()
    img = gm.pack_and_paint(cubes, pal)
    os.makedirs(args.out, exist_ok=True)
    img.save(os.path.join(args.out, args.name + ".png"))
    gm.write_bbmodel(cubes, img, os.path.join(args.out, args.name + ".bbmodel"), args.name, GROUPS)
    gm.write_glb(cubes, img, os.path.join(args.out, args.name + ".glb"), args.name, GROUPS)
    print(f"{len(cubes)} cubos, textura {img.width}x{img.height} -> {os.path.normpath(args.out)}")


if __name__ == "__main__":
    main()
