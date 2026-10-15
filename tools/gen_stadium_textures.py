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


def crowd():
    """Torcida: 2 m x 1 m por repetição. Fileira de cabeças e camisetas coloridas."""
    rnd = random.Random(5)
    w, h = 32, 16
    img = Image.new("RGBA", (w, h))
    noisy(img, (52, 50, 62), 0.05, rnd)
    px = img.load()
    skins = [(241, 194, 150), (198, 134, 90), (141, 85, 54), (224, 172, 105), (92, 58, 40)]
    shirts = [(232, 87, 42), (42, 92, 232), (240, 210, 60), (240, 240, 240), (60, 180, 90),
              (200, 50, 60), (30, 30, 34), (150, 70, 200)]
    for row, top in enumerate((1, 9)):
        x = rnd.randrange(2)
        while x < w:
            skin = rnd.choice(skins)
            shirt = rnd.choice(shirts)
            jitter = rnd.randrange(2)
            # cabeça 2x2, corpo 3x4 (alguns de braços para cima)
            for dy in range(2):
                for dx in range(2):
                    px[(x + dx) % w, top + jitter + dy] = skin + (255,)
            for dy in range(4):
                for dx in range(-0, 3):
                    yy = top + jitter + 2 + dy
                    if yy < h:
                        px[(x - 0 + dx) % w, yy] = shade(shirt, 1.0 - dy * 0.06) + (255,)
            if rnd.random() < 0.3:
                px[(x - 1) % w, top + jitter] = skin + (255,)
                px[(x + 3) % w, top + jitter] = skin + (255,)
            x += 4 + rnd.randrange(2)
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
        "dirt_track": dirt((176, 120, 72), (128, 84, 48), (205, 160, 110), 1),
        "dirt_infield": dirt((118, 80, 50), (88, 58, 36), (150, 108, 72), 2),
        "tuff_block": tuff_block(),
        "concrete": concrete(),
        "crowd": crowd(),
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
