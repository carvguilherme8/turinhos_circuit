"""Gera a moto motocross low poly/voxel do Turinhos Circuit.

Saídas (em assets/models/bikes/motocross/):
  motocross.bbmodel  projeto Blockbench (formato Bedrock entity, UV por face, textura embutida)
  motocross.png      textura pixel art (atlas)
  motocross.glb      modelo pronto para o Godot (1 bloco = 16 px = 1 m; usa o motocross.png ao lado)

Regras de compatibilidade com Minecraft:
  - só cubos; rotação em um único eixo, em múltiplos de 22,5°; nenhuma rotação em grupo
  - frente da moto em -Z (norte no Blockbench), chão em y = 0

Uso: python tools/gen_motocross.py [--primary e8572a] [--out pasta]
Depois de editar o modelo no Blockbench, o .bbmodel passa a ser a fonte; este script serve
para gerar a base e variações de cor.
"""
import argparse
import base64
import io
import json
import math
import os
import random
import struct
import uuid

from PIL import Image

TEX_W = 128
WHEEL_R = 6.0
FRONT_AXLE = (0.0, 6.0, -12.0)
REAR_AXLE = (0.0, 6.0, 12.0)
RAKE = 22.5  # inclinação do garfo (graus em torno de X)


def hex_color(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, f):
    return tuple(max(0, min(255, round(v * f))) for v in c)


# ---------------------------------------------------------------- paleta

class Palette:
    def __init__(self, primary):
        self.primary = primary
        self.primary_dark = shade(primary, 0.72)
        self.white = (236, 236, 228)
        self.tire = (38, 36, 44)
        self.tire_light = (64, 62, 72)
        self.metal = (178, 184, 190)
        self.metal_dark = (110, 116, 124)
        self.engine = (70, 72, 80)
        self.engine_light = (104, 106, 114)
        self.seat = (34, 34, 40)
        self.gold = (222, 170, 60)
        self.exhaust = (196, 200, 204)
        self.pipe = (128, 118, 112)


# ---------------------------------------------------------------- pintores de textura
# Cada pintor recebe (palette, cube, face, p, uv) e devolve uma cor RGB.
# p = posição 3D (px, sem rotação) do centro do texel; uv = posição 0..1 dentro da face.

def noise(p, amount=0.06, seed=0):
    rnd = random.Random(hash((round(p[0] * 4), round(p[1] * 4), round(p[2] * 4), seed)))
    return 1.0 + rnd.uniform(-amount, amount)


def edge_factor(uv, w, h):
    """Escurece 1 texel da borda da face (contorno estilo voxel)."""
    i = uv[0] * w
    j = uv[1] * h
    if w >= 3 and h >= 3 and (i < 1 or j < 1 or i > w - 1 or j > h - 1):
        return 0.82
    return 1.0


def face_light(face):
    return {"up": 1.08, "down": 0.8}.get(face, 1.0)


def flat(color_name, edges=True, grain=0.05):
    def paint(pal, cube, face, p, uv, w, h):
        c = getattr(pal, color_name)
        f = noise(p, grain) * face_light(face)
        if edges:
            f *= edge_factor(uv, w, h)
        return shade(c, f)
    return paint


def plastic_with_stripe(pal, cube, face, p, uv, w, h):
    """Plástico na cor principal, com faixa branca nas laterais (gráfico de motocross)."""
    c = pal.primary
    if face in ("east", "west") and 0.35 < uv[1] < 0.55:
        c = pal.white
    elif face in ("east", "west") and uv[1] >= 0.55:
        c = pal.primary_dark
    return shade(c, noise(p, 0.05) * face_light(face) * edge_factor(uv, w, h))


# Dígito "8" em 3x5 (simétrico: lê certo mesmo espelhado no Blockbench/Minecraft).
DIGIT_8 = ["###", "#.#", "###", "#.#", "###"]


def number_plate(pal, cube, face, p, uv, w, h):
    if face in ("north", "east", "west") and w >= 5 and h >= 6:
        i = math.floor(uv[0] * w - (w - 3) / 2)
        j = math.floor(uv[1] * h - (h - 5) / 2)
        if 0 <= j < 5 and 0 <= i < 3 and DIGIT_8[j][i] == "#":
            return shade(pal.seat, 1.0)
    c = pal.white if face in ("north", "east", "west") else pal.primary
    return shade(c, noise(p, 0.03) * edge_factor(uv, w, h))


def wheel_painter(axle):
    def paint(pal, cube, face, p, uv, w, h):
        dy = p[1] - axle[1]
        dz = p[2] - axle[2]
        r = math.hypot(dy, dz)
        if face in ("east", "west"):
            if r > WHEEL_R - 1.5:
                c = pal.tire  # pneu
            elif r > WHEEL_R - 2.5:
                c = pal.metal  # aro
            elif r < 1.5:
                c = pal.gold  # cubo da roda
            elif abs(dy) < 0.6 or abs(dz) < 0.6:
                c = pal.metal_dark  # raios
            else:
                c = shade(pal.tire, 1.25)
            return shade(c, noise(p, 0.04))
        # Banda de rodagem: cravos alternados.
        ang = math.degrees(math.atan2(dy, dz))
        lug = int((ang + 360) / 22.5) % 2
        across = int(abs(p[0]) * 2) % 2
        c = pal.tire_light if (lug ^ across) else pal.tire
        return shade(c, noise(p, 0.05))
    return paint


def engine_painter(pal, cube, face, p, uv, w, h):
    c = pal.engine
    if face in ("east", "west", "north") and int(p[1]) % 2 == 0:
        c = pal.engine_light  # aletas de refrigeração
    return shade(c, noise(p, 0.05) * face_light(face) * edge_factor(uv, w, h))


def side_cover_painter(pal, cube, face, p, uv, w, h):
    if face in ("east", "west"):
        dy = uv[1] - 0.5
        dz = uv[0] - 0.5
        if math.hypot(dy, dz) < 0.32:
            return shade(pal.engine_light, noise(p, 0.05) * 1.15)
    return shade(pal.engine, noise(p, 0.05) * edge_factor(uv, w, h))


def spring_painter(pal, cube, face, p, uv, w, h):
    c = pal.gold if int(p[1] * 2) % 2 == 0 else pal.metal_dark
    return shade(c, noise(p, 0.04))


def seat_painter(pal, cube, face, p, uv, w, h):
    c = pal.seat
    if face == "up" and int(p[2]) % 3 == 0:
        c = shade(pal.seat, 1.25)  # costura / textura do banco
    return shade(c, noise(p, 0.05) * face_light(face) * edge_factor(uv, w, h))


def grip_painter(pal, cube, face, p, uv, w, h):
    c = pal.seat if int(abs(p[0]) * 2) % 2 == 0 else pal.tire_light
    return shade(c, noise(p, 0.04))


def exhaust_painter(pal, cube, face, p, uv, w, h):
    c = pal.exhaust
    if face in ("east", "west") and 0.25 < uv[1] < 0.45:
        c = pal.primary  # logo na ponteira
    return shade(c, noise(p, 0.04) * face_light(face) * edge_factor(uv, w, h))


def tank_painter(pal, cube, face, p, uv, w, h):
    c = pal.primary
    if face == "up" and abs(p[0]) < 0.6:
        c = pal.white  # faixa central
    return shade(c, noise(p, 0.05) * face_light(face) * edge_factor(uv, w, h))


# ---------------------------------------------------------------- geometria

class Cube:
    def __init__(self, name, group, frm, to, painter, rot=None, origin=None):
        self.name = name
        self.group = group
        self.frm = tuple(float(v) for v in frm)
        self.to = tuple(float(v) for v in to)
        self.painter = painter
        # rot = (eixo, graus); um único eixo, múltiplo de 22,5 (compatível com Minecraft Java)
        self.rot = rot
        if rot:
            assert rot[0] in "xyz" and abs(rot[1]) % 22.5 == 0 and abs(rot[1]) <= 45
        self.origin = tuple(float(v) for v in (origin or self.center()))
        self.uv = {}

    def center(self):
        return tuple((a + b) / 2 for a, b in zip(self.frm, self.to))


def mirror_x(name, group, frm, to, painter, rot=None, origin=None):
    """Cria o par esquerda/direita de um cubo descrito no lado +X."""
    out = [Cube(name + "_r", group, frm, to, painter, rot, origin)]
    f2 = (-to[0], frm[1], frm[2])
    t2 = (-frm[0], to[1], to[2])
    o2 = None if origin is None else (-origin[0], origin[1], origin[2])
    out.append(Cube(name + "_l", group, f2, t2, painter, rot, o2))
    return out


def wheel(name, axle, group):
    """Roda em degraus (círculo de pixel extrudado), sem cubos sobrepostos."""
    # (largura, altura) das colunas ao longo de Z, da frente para trás
    profile = [(1, 6), (2, 10), (6, 12), (2, 10), (1, 6)]
    cubes = []
    z = axle[2] - WHEEL_R
    paint = wheel_painter(axle)
    for i, (w, h) in enumerate(profile):
        cubes.append(Cube(f"{name}_{i}", group,
                          (-2, axle[1] - h / 2, z), (2, axle[1] + h / 2, z + w), paint))
        z += w
    # Eixo saliente dos dois lados
    cubes.append(Cube(f"{name}_axle", group,
                      (-2.6, axle[1] - 0.5, axle[2] - 0.5), (2.6, axle[1] + 0.5, axle[2] + 0.5),
                      flat("metal", edges=False)))
    return cubes


def build_cubes(pal):
    C = []
    fa = FRONT_AXLE
    rake = ("x", RAKE)

    # ---- rodas
    C += wheel("front_wheel", fa, "front_wheel")
    C += wheel("rear_wheel", REAR_AXLE, "rear_wheel")
    # Disco e coroa em cruz (dois cubos com espessuras diferentes, sem faces coplanares)
    C.append(Cube("brake_disc_a", "front_wheel", (2.0, 4.0, -14.0), (2.5, 8.0, -10.0), flat("metal_dark")))
    C.append(Cube("brake_disc_b", "front_wheel", (2.0, 3.5, -13.5), (2.4, 8.5, -10.5), flat("metal_dark")))
    C.append(Cube("sprocket_a", "rear_wheel", (-2.5, 4.0, 10.0), (-2.0, 8.0, 14.0), flat("gold")))
    C.append(Cube("sprocket_b", "rear_wheel", (-2.4, 3.5, 10.5), (-2.0, 8.5, 13.5), flat("gold")))

    # ---- garfo (tudo inclinado 22,5° em torno do eixo da roda dianteira)
    C += mirror_x("fork_lower", "fork", (2.1, 5.0, -13.0), (3.4, 11.5, -11.0), flat("primary_dark"), rake, fa)
    C += mirror_x("fork_upper", "fork", (2.2, 11.5, -12.6), (3.2, 18.5, -11.4), flat("metal", grain=0.03), rake, fa)
    C.append(Cube("clamp_bottom", "fork", (-3.6, 14.5, -13.0), (3.6, 15.5, -9.5), flat("metal_dark"), rake, fa))
    C.append(Cube("clamp_top", "fork", (-3.6, 18.0, -13.0), (3.6, 19.0, -9.5), flat("metal_dark"), rake, fa))
    C.append(Cube("head_tube", "frame", (-1.0, 13.0, -10.5), (1.0, 18.5, -9.0), flat("metal_dark"), rake, fa))
    C.append(Cube("number_plate_front", "fork", (-3.0, 13.0, -14.2), (3.0, 19.5, -13.2), number_plate, rake, fa))

    # ---- guidão (no topo do garfo, sem rotação)
    C.append(Cube("bar_riser", "fork", (-1.0, 18.0, -7.5), (1.0, 20.0, -5.5), flat("metal_dark")))
    C.append(Cube("handlebar", "fork", (-7.0, 20.0, -7.0), (7.0, 20.8, -6.2), flat("metal_dark", edges=False)))
    C += mirror_x("grip", "fork", (6.5, 19.8, -7.2), (8.8, 21.0, -6.0), grip_painter)
    C += mirror_x("lever", "fork", (4.0, 20.2, -8.6), (6.5, 20.6, -7.0), flat("metal", edges=False))

    # ---- para-lama dianteiro
    C.append(Cube("front_fender", "fork", (-2.0, 13.0, -18.0), (2.0, 14.0, -8.0), flat("primary")))
    C.append(Cube("front_fender_tip", "fork", (-1.8, 12.4, -20.0), (1.8, 13.4, -17.0), flat("primary"),
                  ("x", -22.5), (0, 13.0, -18.0)))

    # ---- quadro
    C.append(Cube("frame_spine", "frame", (-1.0, 13.0, -9.0), (1.0, 15.0, 2.0), flat("metal_dark")))
    C.append(Cube("down_tube", "frame", (-1.0, 4.0, -5.0), (1.0, 13.5, -3.0), flat("metal_dark"),
                  ("x", -22.5), (0, 4.0, -4.0)))
    C.append(Cube("frame_upright", "frame", (-1.2, 5.0, 3.0), (1.2, 14.0, 5.0), flat("metal_dark")))
    C += mirror_x("subframe", "frame", (1.2, 12.0, 4.0), (2.2, 13.0, 15.0), flat("metal_dark"))

    # ---- motor
    C.append(Cube("engine_case", "frame", (-2.5, 4.0, -4.0), (2.5, 10.0, 3.5), engine_painter))
    C.append(Cube("cylinder", "frame", (-2.0, 10.0, -4.5), (2.0, 13.0, -0.5), engine_painter))
    C.append(Cube("clutch_cover", "frame", (2.5, 5.0, -2.0), (3.1, 9.0, 2.0), side_cover_painter))
    C.append(Cube("ignition_cover", "frame", (-3.1, 5.0, -2.5), (-2.5, 8.5, 1.0), side_cover_painter))
    C.append(Cube("skid_plate", "frame", (-2.6, 3.4, -5.5), (2.6, 4.0, 3.5), flat("metal")))
    C.append(Cube("radiator", "frame", (-3.0, 9.5, -6.5), (3.0, 14.0, -5.0), flat("tire")))

    # ---- suspensão traseira
    C += mirror_x("swingarm", "frame", (2.2, 5.3, 3.5), (3.3, 6.9, 12.8), flat("metal"))
    C.append(Cube("shock_spring", "frame", (-0.9, 7.0, 4.2), (0.9, 13.0, 5.8), spring_painter,
                  ("x", -22.5), (0, 7.0, 5.0)))

    # ---- plásticos
    C.append(Cube("tank", "body", (-3.0, 13.0, -8.0), (3.0, 17.0, -0.5), tank_painter))
    C.append(Cube("tank_cap", "body", (-0.8, 17.0, -5.5), (0.8, 17.5, -3.9), flat("metal_dark", edges=False)))
    C += mirror_x("shroud", "body", (3.0, 10.0, -9.5), (4.0, 16.0, -1.5), plastic_with_stripe)
    C.append(Cube("seat", "body", (-2.2, 16.0, -3.5), (2.2, 18.0, 11.0), seat_painter))
    C += mirror_x("side_panel", "body", (2.2, 10.0, 0.5), (3.0, 16.0, 10.5), number_plate)
    C.append(Cube("rear_fender", "body", (-2.6, 15.5, 10.0), (2.6, 17.0, 18.5), flat("primary"),
                  ("x", -22.5), (0, 16.5, 10.0)))
    C.append(Cube("rear_fender_side", "body", (-2.2, 13.0, 9.5), (2.2, 16.5, 14.5), flat("primary_dark")))

    # ---- escapamento (lado direito, +X)
    C.append(Cube("header_pipe", "frame", (2.0, 7.0, -6.0), (3.0, 8.0, -1.5), flat("pipe")))
    C.append(Cube("header_mid", "frame", (3.1, 7.0, -1.5), (4.0, 8.0, 4.0), flat("pipe")))
    C.append(Cube("header_rise", "frame", (3.0, 7.0, 4.0), (4.0, 12.5, 5.0), flat("pipe")))
    C.append(Cube("muffler", "frame", (3.0, 11.5, 5.0), (4.8, 14.0, 13.0), exhaust_painter))
    C.append(Cube("muffler_tip", "frame", (3.4, 12.2, 13.0), (4.4, 13.3, 14.0), flat("tire", edges=False)))

    # ---- pedaleiras
    C += mirror_x("footpeg", "frame", (2.6, 6.0, 1.0), (5.2, 6.8, 2.6), flat("metal_dark"))
    return C


# ---------------------------------------------------------------- faces e UV

FACES = ("north", "east", "south", "west", "up", "down")


def face_corners(c, face):
    """Cantos TL, TR, BR, BL vistos de fora (convenção de UV do Blockbench)."""
    (x0, y0, z0), (x1, y1, z1) = c.frm, c.to
    return {
        "north": [(x1, y1, z0), (x0, y1, z0), (x0, y0, z0), (x1, y0, z0)],
        "south": [(x0, y1, z1), (x1, y1, z1), (x1, y0, z1), (x0, y0, z1)],
        "east": [(x1, y1, z1), (x1, y1, z0), (x1, y0, z0), (x1, y0, z1)],
        "west": [(x0, y1, z0), (x0, y1, z1), (x0, y0, z1), (x0, y0, z0)],
        "up": [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
        "down": [(x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0)],
    }[face]


def face_size(c, face):
    sx, sy, sz = (b - a for a, b in zip(c.frm, c.to))
    return {"north": (sx, sy), "south": (sx, sy), "east": (sz, sy), "west": (sz, sy),
            "up": (sx, sz), "down": (sx, sz)}[face]


def pack_and_paint(cubes, pal):
    """Empacota uma região de textura por face (prateleiras) e pinta cada texel."""
    regions = []
    for c in cubes:
        for f in FACES:
            w, h = face_size(c, f)
            regions.append((c, f, max(1, math.ceil(w - 0.01)), max(1, math.ceil(h - 0.01))))
    regions.sort(key=lambda r: -r[3])

    x = y = shelf_h = 0
    placed = []
    for c, f, w, h in regions:
        if x + w > TEX_W:
            x, y, shelf_h = 0, y + shelf_h, 0
        placed.append((c, f, x, y, w, h))
        x += w
        shelf_h = max(shelf_h, h)
    tex_h = 16
    while tex_h < y + shelf_h:
        tex_h *= 2

    img = Image.new("RGBA", (TEX_W, tex_h), (0, 0, 0, 0))
    px = img.load()
    for c, f, x0, y0, w, h in placed:
        c.uv[f] = (x0, y0, x0 + w, y0 + h)
        tl, tr, br, bl = face_corners(c, f)
        for j in range(h):
            for i in range(w):
                u = (i + 0.5) / w
                v = (j + 0.5) / h
                p = tuple(tl[k] + (tr[k] - tl[k]) * u + (bl[k] - tl[k]) * v for k in range(3))
                col = c.painter(pal, c, f, p, (u, v), w, h)
                px[x0 + i, y0 + j] = col + (255,)
    return img


# ---------------------------------------------------------------- Blockbench

GROUPS = [
    # (nome, pivô, pai)
    ("motocross", (0, 0, 0), None),
    ("frame", (0, 0, 0), "motocross"),
    ("body", (0, 0, 0), "motocross"),
    ("rear_wheel", REAR_AXLE, "motocross"),
    ("fork", (0, 16.0, -9.0), "motocross"),
    ("front_wheel", FRONT_AXLE, "fork"),
]


def new_uuid():
    return str(uuid.uuid4())


def write_bbmodel(cubes, img, path, name):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    tex_data = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

    elements = []
    by_group = {g[0]: [] for g in GROUPS}
    for c in cubes:
        uid = new_uuid()
        el = {
            "name": c.name, "box_uv": False, "rescale": False, "locked": False,
            "render_order": "default", "allow_mirror_modeling": True,
            "from": list(c.frm), "to": list(c.to), "autouv": 0, "color": 0,
            "origin": list(c.origin),
            "faces": {f: {"uv": list(c.uv[f]), "texture": 0} for f in FACES},
            "type": "cube", "uuid": uid,
        }
        if c.rot:
            r = [0, 0, 0]
            r["xyz".index(c.rot[0])] = c.rot[1]
            el["rotation"] = r
        elements.append(el)
        by_group[c.group].append(uid)

    def group_node(gname):
        g = next(g for g in GROUPS if g[0] == gname)
        children = [group_node(o[0]) for o in GROUPS if o[2] == gname] + by_group[gname]
        return {"name": gname, "origin": list(g[1]), "color": 0, "uuid": new_uuid(),
                "export": True, "mirror_uv": False, "isOpen": True, "locked": False,
                "visibility": True, "autouv": 0, "children": children}

    model = {
        "meta": {"format_version": "4.10", "model_format": "bedrock", "box_uv": False},
        "name": name,
        "model_identifier": "turinhos_" + name,
        "visible_box": [3, 2.5, 1],
        "variable_placeholders": "",
        "variable_placeholder_buttons": [],
        "timeline_setups": [],
        "unhandled_root_fields": {},
        "resolution": {"width": img.width, "height": img.height},
        "elements": elements,
        "outliner": [group_node("motocross")],
        "textures": [{
            "path": "", "name": name + ".png", "folder": "", "namespace": "", "id": "0",
            "width": img.width, "height": img.height, "uv_width": img.width, "uv_height": img.height,
            "particle": False, "render_mode": "default", "render_sides": "auto",
            "frame_time": 1, "frame_order_type": "loop", "frame_order": "", "frame_interpolate": False,
            "visible": True, "internal": True, "saved": True, "uuid": new_uuid(), "source": tex_data,
        }],
    }
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(model, fh, indent="\t")


# ---------------------------------------------------------------- glTF (.glb)

def rotate(p, origin, rot):
    if not rot:
        return p
    a = math.radians(rot[1])
    ca, sa = math.cos(a), math.sin(a)
    x, y, z = (p[i] - origin[i] for i in range(3))
    if rot[0] == "x":
        y, z = y * ca - z * sa, y * sa + z * ca
    elif rot[0] == "y":
        x, z = x * ca + z * sa, -x * sa + z * ca
    else:
        x, y = x * ca - y * sa, x * sa + y * ca
    return (x + origin[0], y + origin[1], z + origin[2])


NORMALS = {"north": (0, 0, -1), "south": (0, 0, 1), "east": (1, 0, 0),
           "west": (-1, 0, 0), "up": (0, 1, 0), "down": (0, -1, 0)}


def write_glb(cubes, img, path, name):
    """Exporta o .glb referenciando <name>.png na mesma pasta."""
    scale = 1.0 / 16.0
    group_pivot = {g[0]: g[1] for g in GROUPS}
    group_parent = {g[0]: g[2] for g in GROUPS}

    def world_pivot(g):
        return group_pivot[g]

    bin_data = bytearray()
    buffer_views, accessors, meshes = [], [], []

    def add_view(data, target):
        while len(bin_data) % 4:
            bin_data.append(0)
        buffer_views.append({"buffer": 0, "byteOffset": len(bin_data), "byteLength": len(data), "target": target})
        bin_data.extend(data)
        return len(buffer_views) - 1

    mesh_index = {}
    for gname, _, _ in GROUPS:
        gcubes = [c for c in cubes if c.group == gname]
        if not gcubes:
            continue
        pivot = world_pivot(gname)
        pos, nrm, uvs, idx = [], [], [], []
        for c in gcubes:
            for f in FACES:
                corners = [rotate(p, c.origin, c.rot) for p in face_corners(c, f)]
                n = rotate(NORMALS[f], (0, 0, 0), c.rot)
                u0, v0, u1, v1 = c.uv[f]
                face_uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
                base = len(pos)
                for p, uv in zip(corners, face_uv):
                    pos.append(tuple((p[k] - pivot[k]) * scale for k in range(3)))
                    nrm.append(n)
                    uvs.append((uv[0] / img.width, uv[1] / img.height))
                # TL,TR,BR,BL é horário visto de fora; glTF quer anti-horário.
                idx += [base, base + 3, base + 2, base, base + 2, base + 1]

        pv = add_view(b"".join(struct.pack("<3f", *p) for p in pos), 34962)
        mins = [min(p[k] for p in pos) for k in range(3)]
        maxs = [max(p[k] for p in pos) for k in range(3)]
        accessors.append({"bufferView": pv, "componentType": 5126, "count": len(pos), "type": "VEC3", "min": mins, "max": maxs})
        a_pos = len(accessors) - 1
        nv = add_view(b"".join(struct.pack("<3f", *n) for n in nrm), 34962)
        accessors.append({"bufferView": nv, "componentType": 5126, "count": len(nrm), "type": "VEC3"})
        a_nrm = len(accessors) - 1
        uv_view = add_view(b"".join(struct.pack("<2f", *t) for t in uvs), 34962)
        accessors.append({"bufferView": uv_view, "componentType": 5126, "count": len(uvs), "type": "VEC2"})
        a_uv = len(accessors) - 1
        iv = add_view(b"".join(struct.pack("<I", i) for i in idx), 34963)
        accessors.append({"bufferView": iv, "componentType": 5125, "count": len(idx), "type": "SCALAR"})
        a_idx = len(accessors) - 1
        meshes.append({"name": gname, "primitives": [{
            "attributes": {"POSITION": a_pos, "NORMAL": a_nrm, "TEXCOORD_0": a_uv},
            "indices": a_idx, "material": 0}]})
        mesh_index[gname] = len(meshes) - 1

    nodes = []
    node_index = {}
    for gname, pivot, parent in GROUPS:
        local = pivot if parent is None else tuple(pivot[k] - group_pivot[parent][k] for k in range(3))
        node = {"name": gname, "translation": [v * scale for v in local]}
        if gname in mesh_index:
            node["mesh"] = mesh_index[gname]
        nodes.append(node)
        node_index[gname] = len(nodes) - 1
    for gname, _, parent in GROUPS:
        if parent:
            nodes[node_index[parent]].setdefault("children", []).append(node_index[gname])

    gltf = {
        "asset": {"version": "2.0", "generator": "turinhos gen_motocross.py"},
        "scene": 0,
        "scenes": [{"name": name, "nodes": [node_index["motocross"]]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": [{"name": name, "pbrMetallicRoughness": {
            "baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.9}}],
        "textures": [{"sampler": 0, "source": 0}],
        "samplers": [{"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071}],
        # Textura externa (o mesmo .png usado pelo Blockbench), sem cópia embutida.
        "images": [{"uri": name + ".png"}],
        "buffers": [{"byteLength": len(bin_data)}],
        "bufferViews": buffer_views,
        "accessors": accessors,
    }
    while len(bin_data) % 4:
        bin_data.append(0)
    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(bin_data)
    with open(path, "wb") as fh:
        fh.write(struct.pack("<III", 0x46546C67, 2, total))
        fh.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        fh.write(struct.pack("<II", len(bin_data), 0x004E4942) + bytes(bin_data))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--primary", default="e8572a", help="cor principal dos plásticos (hex)")
    ap.add_argument("--name", default="motocross")
    ap.add_argument("--out", default=os.path.join(here, "..", "assets", "models", "bikes", "motocross"))
    args = ap.parse_args()

    random.seed(7)
    pal = Palette(hex_color(args.primary))
    cubes = build_cubes(pal)
    img = pack_and_paint(cubes, pal)
    os.makedirs(args.out, exist_ok=True)
    img.save(os.path.join(args.out, args.name + ".png"))
    write_bbmodel(cubes, img, os.path.join(args.out, args.name + ".bbmodel"), args.name)
    write_glb(cubes, img, os.path.join(args.out, args.name + ".glb"), args.name)
    print(f"{len(cubes)} cubos, textura {img.width}x{img.height} -> {os.path.normpath(args.out)}")


if __name__ == "__main__":
    main()
