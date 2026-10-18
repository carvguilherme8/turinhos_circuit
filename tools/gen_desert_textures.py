"""Gera as texturas pixel art do Parque do Deserto (andar livre).

Saída: assets/textures/desert/*.png (16 px = 1 m, como as outras pistas)
  sand.png        areia com ondulações de vento
  sandstone.png   arenito em camadas (paredões e mesas)
  packed_dirt.png terra batida das áreas de manobra e das rampas

Uso: python tools/gen_desert_textures.py
"""
import os
import random

from PIL import Image

from gen_stadium_textures import dirt_detail, noisy, shade

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures", "desert")


def sand(seed=41, size=64):
    rnd = random.Random(seed)
    base = (222, 172, 112)
    img = Image.new("RGBA", (size, size))
    noisy(img, base, 0.05, rnd)
    px = img.load()
    # Ondulações: linhas onduladas mais escuras e um brilho logo acima.
    for row in range(0, size, 7):
        phase = rnd.uniform(0, 6.28)
        for x in range(size):
            import math
            y = (row + int(round(math.sin(x * 0.2 + phase) * 1.5))) % size
            px[x, y] = shade((190, 140, 86), rnd.uniform(0.95, 1.05)) + (255,)
            px[x, (y - 1) % size] = shade((236, 192, 136), rnd.uniform(0.97, 1.03)) + (255,)
    # Grãos e pedrinhas.
    for _ in range(90):
        px[rnd.randrange(size), rnd.randrange(size)] = shade(rnd.choice([(176, 128, 80), (240, 206, 150), (150, 120, 96)]), rnd.uniform(0.9, 1.1)) + (255,)
    return img


def sandstone(seed=42, size=64):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (size, size))
    px = img.load()
    bands = [(196, 104, 62), (214, 132, 80), (178, 88, 54), (226, 152, 96), (168, 80, 52), (204, 120, 72)]
    y = 0
    while y < size:
        color = rnd.choice(bands)
        h = rnd.randint(3, 8)
        for yy in range(y, min(size, y + h)):
            for x in range(size):
                px[x, yy] = shade(color, rnd.uniform(0.93, 1.06)) + (255,)
        # risca escura entre camadas
        if y + h < size:
            for x in range(size):
                if rnd.random() < 0.7:
                    px[x, y + h - 1] = shade(color, 0.8) + (255,)
        y += h
    # rachaduras verticais
    for _ in range(8):
        x, y0 = rnd.randrange(size), rnd.randrange(size)
        for k in range(rnd.randint(3, 9)):
            px[(x + (k // 3)) % size, (y0 + k) % size] = (120, 60, 40, 255)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    textures = {
        "sand": sand(),
        "sandstone": sandstone(),
        "packed_dirt": dirt_detail((176, 112, 70), (128, 78, 46), (206, 150, 104), (190, 104, 60), 43),
    }
    for name, img in textures.items():
        img.save(os.path.join(OUT, name + ".png"))
    print(f"{len(textures)} texturas -> {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
