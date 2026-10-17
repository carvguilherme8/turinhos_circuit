"""Gera as texturas pixel art da Pista da Fazenda (motocross ao ar livre).

Saída: assets/textures/farm/*.png (16 px = 1 m, como as do estádio)
  dirt_red.png   terra da pista (alaranjada, como a terra vermelha do vídeo)
  clay_bank.png  barranco de terra vermelha (taludes e cortes no morro)
  grass.png      grama de pasto com tufos e flores
  fence.png      madeira pintada de branco (cercas)
  bark.png, leaves.png  tronco e copa das árvores (voxel)

Uso: python tools/gen_farm_textures.py
"""
import os
import random

from PIL import Image

from gen_stadium_textures import dirt_detail, noisy, shade

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures", "farm")


def grass(seed=21, size=64):
    rnd = random.Random(seed)
    base = (92, 138, 58)
    img = Image.new("RGBA", (size, size))
    noisy(img, base, 0.08, rnd)
    px = img.load()

    def put(x, y, c):
        px[x % size, y % size] = c + (255,)

    # Manchas de grama seca e mais escura.
    for _ in range(8):
        cx, cy, r = rnd.randrange(size), rnd.randrange(size), rnd.randint(3, 7)
        tint = rnd.choice([(124, 146, 64), (74, 116, 48), (108, 150, 66)])
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if x * x + y * y <= r * r and rnd.random() < 0.75:
                    put(cx + x, cy + y, shade(tint, rnd.uniform(0.94, 1.06)))
    # Tufos: risquinho escuro com ponta clara.
    for _ in range(140):
        x, y = rnd.randrange(size), rnd.randrange(size)
        put(x, y, shade((58, 96, 38), rnd.uniform(0.9, 1.1)))
        put(x, y - 1, shade((132, 176, 78), rnd.uniform(0.95, 1.05)))
    # Florzinhas e terra aparecendo.
    for _ in range(10):
        put(rnd.randrange(size), rnd.randrange(size), rnd.choice([(236, 226, 120), (240, 240, 232)]))
    for _ in range(12):
        put(rnd.randrange(size), rnd.randrange(size), shade((150, 96, 58), rnd.uniform(0.9, 1.1)))
    return img


def clay_bank(seed=22, size=64):
    """Barranco: terra vermelha com camadas horizontais (o corte no morro)."""
    img = dirt_detail((168, 84, 48), (122, 56, 32), (196, 116, 72), (180, 70, 40), seed, size)
    rnd = random.Random(seed + 1)
    px = img.load()
    for _ in range(9):
        y = rnd.randrange(size)
        x0, length = rnd.randrange(size), rnd.randint(10, 30)
        for k in range(length):
            px[(x0 + k) % size, y] = shade((134, 64, 36), rnd.uniform(0.9, 1.05)) + (255,)
    return img


def fence(seed=23):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (16, 16))
    noisy(img, (232, 230, 220), 0.04, rnd)
    px = img.load()
    for y in range(16):
        if y % 8 == 0:
            for x in range(16):
                px[x, y] = shade((200, 196, 186), rnd.uniform(0.95, 1.05)) + (255,)
    for _ in range(6):
        px[rnd.randrange(16), rnd.randrange(16)] = (180, 120, 80, 255)  # respingo de terra
    return img


def bark(seed=24):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (16, 16))
    noisy(img, (104, 76, 52), 0.08, rnd)
    px = img.load()
    for x in range(0, 16, 3):
        for y in range(16):
            if rnd.random() < 0.7:
                px[x, y] = shade((76, 54, 36), rnd.uniform(0.9, 1.1)) + (255,)
    return img


def leaves(seed=25):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (16, 16))
    noisy(img, (62, 112, 48), 0.12, rnd)
    px = img.load()
    for _ in range(40):
        px[rnd.randrange(16), rnd.randrange(16)] = shade(rnd.choice([(44, 84, 36), (96, 148, 64)]), rnd.uniform(0.9, 1.1)) + (255,)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    textures = {
        "dirt_red": dirt_detail((190, 108, 60), (138, 72, 38), (222, 150, 98), (200, 92, 50), 31),
        "clay_bank": clay_bank(),
        "grass": grass(),
        "fence": fence(),
        "bark": bark(),
        "leaves": leaves(),
    }
    for name, img in textures.items():
        img.save(os.path.join(OUT, name + ".png"))
    print(f"{len(textures)} texturas -> {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
