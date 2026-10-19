"""Monta os ícones do app a partir da moto renderizada (tools/render_icon_bike.gd).

Uso: python tools/gen_icon.py <moto.png>
Gera em assets/icons/: icon.png (1024, cantos arredondados: PC e editor), android_192.png e o
ícone adaptativo do Android (android_background.png + android_foreground.png, 432 px, moto dentro
da zona segura do centro). Fundo: pôr do sol do estádio com um morro de terra.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join("assets", "icons")
TOP, MID, BOTTOM = (74, 44, 110), (232, 87, 42), (255, 196, 92)


def background(size):
    bg = Image.new("RGBA", (size, size))
    px = bg.load()
    for y in range(size):
        t = y / (size - 1)
        a, b, k = (TOP, MID, t / 0.6) if t < 0.6 else (MID, BOTTOM, (t - 0.6) / 0.4)
        color = tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)) + (255,)
        for x in range(size):
            px[x, y] = color
    d = ImageDraw.Draw(bg)
    d.polygon([(0, size * 0.86), (size * 0.55, size * 0.70), (size, size * 0.80), (size, size), (0, size)],
              fill=(122, 64, 38, 255))
    d.polygon([(0, size * 0.92), (size * 0.6, size * 0.80), (size, size * 0.88), (size, size), (0, size)],
              fill=(92, 46, 30, 255))
    return bg


def compose(bike, size, scale, center, with_background=True):
    canvas = background(size) if with_background else Image.new("RGBA", (size, size), (0, 0, 0, 0))
    w = int(size * scale)
    h = int(bike.height * w / bike.width)
    b = bike.resize((w, h), Image.LANCZOS)
    shadow = Image.new("RGBA", b.size, (0, 0, 0, 0))
    shadow.putalpha(b.getchannel("A").point(lambda a: a * 0.45))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.012))
    x = int(size * center[0] - w / 2)
    y = int(size * center[1] - h / 2)
    canvas.alpha_composite(shadow, (x + int(size * 0.015), y + int(size * 0.02)))
    canvas.alpha_composite(b, (x, y))
    return canvas


def main():
    bike = Image.open(sys.argv[1]).convert("RGBA")
    bike = bike.crop(bike.getbbox())
    os.makedirs(OUT, exist_ok=True)
    icon = compose(bike, 1024, 0.78, (0.5, 0.52))
    mask = Image.new("L", (1024, 1024), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1023, 1023), radius=200, fill=255)
    rounded = icon.copy()
    rounded.putalpha(mask)
    rounded.save(os.path.join(OUT, "icon.png"))
    icon.convert("RGB").resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "android_192.png"))
    background(432).save(os.path.join(OUT, "android_background.png"))
    compose(bike, 432, 0.56, (0.5, 0.52), False).save(os.path.join(OUT, "android_foreground.png"))


if __name__ == "__main__":
    main()
