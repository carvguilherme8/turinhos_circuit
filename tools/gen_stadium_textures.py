"""Gera as texturas pixel art do estádio (mesma estética voxel da moto).

Saída: assets/textures/stadium/*.png
Escala: 16 px = 1 m nas texturas de superfície (como um bloco do Minecraft).

Uso: python tools/gen_stadium_textures.py
"""
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures", "stadium")

# Fonte 3x5 (pixel) para faixas e telão.
FONT = {
    "A": ["###", "#.#", "###", "#.#", "#.#"],
    "C": ["###", "#..", "#..", "#..", "###"],
    "E": ["###", "#..", "##.", "#..", "###"],
    "G": ["###", "#..", "#.#", "#.#", "###"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": ["###", "#.#", "#.#", "#.#", "###"],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": ["###", "#..", "###", "..#", "###"],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "!": [".#.", ".#.", ".#.", "...", ".#."],
    "*": ["...", ".#.", "###", ".#.", "..."],
    " ": ["...", "...", "...", "...", "..."],
}


def shade(c, f):
    return tuple(max(0, min(255, round(v * f))) for v in c)


def noisy(img, base, amount, rnd):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            px[x, y] = shade(base, 1.0 + rnd.uniform(-amount, amount)) + (255,)


def text_width(text, scale):
    return len(text) * 4 * scale - scale


def draw_text(img, text, x0, y0, color, scale=1):
    px = img.load()
    for i, ch in enumerate(text):
        glyph = FONT[ch]
        for gy, row in enumerate(glyph):
            for gx, cell in enumerate(row):
                if cell != "#":
                    continue
                for sy in range(scale):
                    for sx in range(scale):
                        x = x0 + (i * 4 + gx) * scale + sx
                        y = y0 + gy * scale + sy
                        if 0 <= x < img.width and 0 <= y < img.height:
                            px[x, y] = color + (255,)


def dirt(base, speck_dark, speck_light, seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (16, 16))
    noisy(img, base, 0.07, rnd)
    px = img.load()
    for _ in range(14):
        x, y = rnd.randrange(16), rnd.randrange(16)
        px[x, y] = shade(speck_dark, rnd.uniform(0.9, 1.1)) + (255,)
    for _ in range(8):
        x, y = rnd.randrange(16), rnd.randrange(16)
        px[x, y] = shade(speck_light, rnd.uniform(0.95, 1.05)) + (255,)
    return img


def dirt_detail(base, dark, light, warm, seed, size=64):
    """Terra com variedade (64 px = 4 m, repetível): torrões com sombra e brilho,
    pedrinhas, rachaduras e manchas de outra tonalidade."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (size, size))
    noisy(img, base, 0.06, rnd)
    px = img.load()

    def put(x, y, c):
        px[x % size, y % size] = c + (255,)

    # Manchas de outra tonalidade (mais avermelhada ou amarelada).
    for _ in range(7):
        cx, cy, r = rnd.randrange(size), rnd.randrange(size), rnd.randint(3, 6)
        tint = rnd.choice([warm, shade(base, 0.92), shade(base, 1.07)])
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if x * x + y * y <= r * r and rnd.random() < 0.8:
                    put(cx + x, cy + y, shade(tint, rnd.uniform(0.95, 1.05)))
    # Torrões: bloco escuro com um pixel claro em cima (parece relevo).
    for _ in range(26):
        x, y = rnd.randrange(size), rnd.randrange(size)
        w, h = rnd.choice([(2, 2), (3, 2), (2, 1)])
        for yy in range(h):
            for xx in range(w):
                put(x + xx, y + yy, shade(dark, rnd.uniform(0.9, 1.1)))
        put(x, y - 1, shade(light, rnd.uniform(0.95, 1.05)))
    # Pedrinhas acinzentadas.
    for _ in range(18):
        x, y = rnd.randrange(size), rnd.randrange(size)
        put(x, y, (150 + rnd.randrange(30), 140 + rnd.randrange(25), 125 + rnd.randrange(20)))
    # Rachaduras curtas.
    for _ in range(6):
        x, y = rnd.randrange(size), rnd.randrange(size)
        dx, dy = rnd.choice([(1, 0), (1, 1), (0, 1), (1, -1)])
        for k in range(rnd.randint(3, 6)):
            put(x + dx * k + (k % 2), y + dy * k, shade(dark, 0.8))
    # Grãos soltos.
    for _ in range(120):
        x, y = rnd.randrange(size), rnd.randrange(size)
        put(x, y, shade(rnd.choice([dark, light]), rnd.uniform(0.95, 1.05)))
    return img


def macro_noise(size=32, seed=9):
    """Ruído suave em tons de cinza (repetível) para manchas grandes no chão."""
    rnd = random.Random(seed)
    grid = 8
    vals = [[rnd.random() for _ in range(grid)] for _ in range(grid)]

    def sample(u, v):
        x, y = u * grid, v * grid
        x0, y0 = int(x) % grid, int(y) % grid
        x1, y1 = (x0 + 1) % grid, (y0 + 1) % grid
        fx, fy = x - int(x), y - int(y)
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        top = vals[y0][x0] * (1 - fx) + vals[y0][x1] * fx
        bottom = vals[y1][x0] * (1 - fx) + vals[y1][x1] * fx
        return top * (1 - fy) + bottom * fy

    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            v = round(255 * sample(x / size, y / size))
            px[x, y] = (v, v, v, 255)
    return img


def tuff_block():
    """Bloco de espuma claro (as cores vêm de cada instância, multiplicando a textura)."""
    rnd = random.Random(3)
    img = Image.new("RGBA", (16, 16))
    noisy(img, (235, 235, 235), 0.03, rnd)
    px = img.load()
    for i in range(16):
        for edge in (0, 15):
            px[i, edge] = (170, 170, 170, 255)
            px[edge, i] = (170, 170, 170, 255)
    for x in range(1, 15):
        px[x, 7] = (210, 210, 210, 255)
        px[x, 8] = (250, 250, 250, 255)
    return img


def concrete():
    rnd = random.Random(4)
    img = Image.new("RGBA", (16, 16))
    noisy(img, (150, 148, 144), 0.05, rnd)
    px = img.load()
    for i in range(16):
        px[i, 15] = (118, 116, 112, 255)
        px[15, i] = (118, 116, 112, 255)
    return img


CROWD_VARIANTS = 4


def crowd_tile(rnd, shirts, density, arms_up, seat):
    """Uma faixa de torcida de 2 m x 1 m (32 x 16 px): duas fileiras de pessoas."""
    w, h = 32, 16
    img = Image.new("RGBA", (w, h))
    noisy(img, (52, 50, 62), 0.05, rnd)
    px = img.load()
    skins = [(241, 194, 150), (198, 134, 90), (141, 85, 54), (224, 172, 105), (92, 58, 40)]
    for top in (1, 9):
        x = rnd.randrange(2)
        while x < w:
            if rnd.random() > density:
                # Cadeira vazia (encosto colorido).
                for dy in range(3, 6):
                    for dx in range(3):
                        px[(x + dx) % w, top + dy] = shade(seat, rnd.uniform(0.9, 1.05)) + (255,)
                x += 4
                continue
            skin = rnd.choice(skins)
            shirt = rnd.choice(shirts)
            jitter = rnd.randrange(2)
            for dy in range(2):
                for dx in range(2):
                    px[(x + dx) % w, top + jitter + dy] = skin + (255,)
            for dy in range(4):
                for dx in range(3):
                    yy = top + jitter + 2 + dy
                    if yy < h:
                        px[(x + dx) % w, yy] = shade(shirt, 1.0 - dy * 0.06) + (255,)
            if rnd.random() < arms_up:
                for side in (-1, 3):
                    px[(x + side) % w, top + jitter] = skin + (255,)
                    px[(x + side) % w, max(0, top + jitter - 1)] = skin + (255,)
            x += 4 + rnd.randrange(2)
    return img


def crowd():
    """Atlas com CROWD_VARIANTS faixas de torcida empilhadas (cada uma 32 x 16 px)."""
    rnd = random.Random(5)
    mixed = [(232, 87, 42), (42, 92, 232), (240, 210, 60), (240, 240, 240), (60, 180, 90),
             (200, 50, 60), (30, 30, 34), (150, 70, 200)]
    blue = [(42, 92, 232), (42, 92, 232), (30, 60, 170), (240, 240, 240)]
    orange = [(232, 87, 42), (232, 87, 42), (250, 140, 50), (30, 30, 34)]
    variants = [
        crowd_tile(rnd, mixed, 0.95, 0.25, (90, 90, 100)),     # torcida misturada, cheia
        crowd_tile(rnd, blue, 0.97, 0.55, (42, 92, 232)),      # fã-clube azul, braços para cima
        crowd_tile(rnd, orange, 0.97, 0.45, (232, 87, 42)),    # fã-clube laranja
        crowd_tile(rnd, mixed, 0.35, 0.1, (150, 150, 160)),    # setor vazio
    ]
    atlas = Image.new("RGBA", (32, 16 * CROWD_VARIANTS))
    for i, img in enumerate(variants):
        atlas.paste(img, (0, i * 16))
    return atlas


def stairs():
    """Escada da arquibancada: dois degraus por fileira e faixa amarela de segurança."""
    rnd = random.Random(12)
    img = Image.new("RGBA", (16, 16))
    noisy(img, (170, 168, 162), 0.04, rnd)
    px = img.load()
    for x in range(16):
        px[x, 0] = (230, 190, 40, 255)
        px[x, 8] = (230, 190, 40, 255)
        px[x, 7] = (120, 118, 114, 255)
        px[x, 15] = (120, 118, 114, 255)
    return img


def seats():
    """Cadeiras vistas de cima, em tons de cinza (a cor de cada setor vem do vértice)."""
    rnd = random.Random(13)
    img = Image.new("RGBA", (16, 16))
    noisy(img, (95, 95, 100), 0.04, rnd)
    px = img.load()
    for row in (2, 10):
        for x in range(16):
            if x % 4 == 3:
                continue
            for dy in range(4):
                v = 235 if dy == 0 else 205
                px[x, row + dy] = (v, v, v, 255)
    return img


def banner():
    """Faixa do muro: 8 m x 1 m (128 x 16 px), segmentos de propaganda fictícia."""
    img = Image.new("RGBA", (128, 16))
    segments = [
        ("TURINHOS", (232, 87, 42), (255, 255, 255)),
        ("MX", (24, 24, 30), (240, 210, 60)),
        ("CIRCUIT", (42, 92, 232), (255, 255, 255)),
    ]
    widths = [text_width(t, 1) + 8 for t, _, _ in segments]
    scale_total = sum(widths)
    x = 0
    px = img.load()
    for (text, bg, fg), seg_w in zip(segments, widths):
        seg_w = round(seg_w * 128 / scale_total)
        for xx in range(x, min(128, x + seg_w)):
            for yy in range(16):
                border = yy in (0, 15)
                px[xx, yy] = (shade(bg, 0.75) if border else bg) + (255,)
        draw_text(img, text, x + (seg_w - text_width(text, 1)) // 2, 3, fg, 1)
        # sublinhado
        for xx in range(x + 3, x + seg_w - 3):
            px[xx, 11] = shade(fg, 0.85) + (255,)
        x += seg_w
    return img


def jumbotron():
    img = Image.new("RGBA", (96, 36))
    rnd = random.Random(6)
    noisy(img, (16, 18, 30), 0.15, rnd)
    px = img.load()
    for x in range(96):
        for y in (0, 1, 34, 35):
            px[x, y] = (60, 60, 70, 255)
    for y in range(36):
        for x in (0, 1, 94, 95):
            px[x, y] = (60, 60, 70, 255)
    title = "TURINHOS"
    draw_text(img, title, (96 - text_width(title, 2)) // 2, 5, (255, 140, 60), 2)
    sub = "* MX *"
    draw_text(img, sub, (96 - text_width(sub, 2)) // 2, 20, (255, 225, 90), 2)
    return img


def checker():
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            black = ((x // 4) + (y // 4)) % 2 == 0
            px[x, y] = ((25, 25, 28) if black else (240, 240, 240)) + (255,)
    return img


def metal():
    rnd = random.Random(8)
    img = Image.new("RGBA", (16, 16))
    noisy(img, (120, 126, 134), 0.05, rnd)
    px = img.load()
    for i in range(16):
        px[i, 0] = (90, 94, 100, 255)
        px[0, i] = (90, 94, 100, 255)
    for x, y in ((3, 3), (12, 3), (3, 12), (12, 12)):
        px[x, y] = (175, 180, 186, 255)
    return img


def light_panel():
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            cell = x % 4 in (0,) or y % 4 in (0,)
            px[x, y] = ((70, 70, 78) if cell else (255, 246, 214)) + (255,)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    textures = {
        "dirt_track": dirt_detail((176, 120, 72), (124, 82, 46), (212, 166, 116), (186, 112, 66), 1),
        "dirt_infield": dirt_detail((118, 80, 50), (84, 56, 34), (152, 110, 74), (128, 78, 46), 2),
        "dirt_macro": macro_noise(),
        "tuff_block": tuff_block(),
        "concrete": concrete(),
        "crowd": crowd(),
        "stairs": stairs(),
        "seats": seats(),
        "banner": banner(),
        "jumbotron": jumbotron(),
        "checker": checker(),
        "metal": metal(),
        "light_panel": light_panel(),
    }
    for name, img in textures.items():
        img.save(os.path.join(OUT, name + ".png"))
    print(f"{len(textures)} texturas -> {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
