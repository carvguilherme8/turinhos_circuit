"""Gera os mapas que deixam o jogo repintar a moto e o piloto (cores e número) em tempo real.

Cada pixel da textura é "cor fixa × sombra" ou "cor variável × sombra". Pintando o modelo com
cores de teste, separamos as partes:
  <nome>_skin_base.png    cores fixas (pneus, motor, pele...); preto onde a cor é variável
  <nome>_skin_map.png     R = quanto da cor principal, G = quanto da cor de detalhe,
                          B = sombra dos pixels de número (tudo dividido por SCALE)
  <nome>_skin_digits.png  R = dígitos 0..7, G = dígitos 8..9: bit ligado = o pixel faz parte
                          daquele dígito (pinta com a cor do número em vez da cor de fundo)
No jogo: cor = base + principal × R + detalhe × G; nos pixels do dígito escolhido,
cor = cor do número × B (scripts/bike/skin_painter.gd).

Uso: python tools/gen_skin_maps.py
"""
import os
import random

from PIL import Image

import gen_motocross as gm
import gen_rider as gr

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
# Fatores de sombra vão até ~1,3; guardados divididos por SCALE para caber em 0..255.
SCALE = 1.5
# Cor de teste: alta o bastante para precisão, baixa o bastante para não estourar em 255.
TEST = 190
BLANK = " "


def render_rider(primary, accent, number):
    gr.BACK_NUMBER = number
    random.seed(11)
    pal = gr.Palette(primary, accent)
    return gm.pack_and_paint(gr.build_cubes(), pal)


def render_bike(primary, number):
    gm.PLATE_NUMBER = number
    random.seed(7)
    pal = gm.Palette(primary)
    return gm.pack_and_paint(gm.build_cubes(pal), pal)


def build(name, out, render, has_accent, number_color, digits):
    black, test = (0, 0, 0), (TEST, TEST, TEST)
    blank = render(black, black, BLANK) if has_accent else render(black, BLANK)
    with_primary = render(test, black, BLANK) if has_accent else render(test, BLANK)
    with_accent = render(black, test, BLANK) if has_accent else None
    per_digit = [render(black, black, d) if has_accent else render(black, d) for d in digits]

    w, h = blank.size
    base = Image.new("RGB", (w, h))
    skin_map = Image.new("RGB", (w, h))
    digit_bits = Image.new("RGB", (w, h))
    b, p = blank.load(), with_primary.load()
    a = with_accent.load() if with_accent else None
    dpx = [img.load() for img in per_digit]
    for y in range(h):
        for x in range(w):
            base_c = b[x, y][:3]
            base.putpixel((x, y), base_c)
            primary_f = (p[x, y][0] - base_c[0]) / TEST
            accent_f = (a[x, y][0] - base_c[0]) / TEST if a else 0.0
            bits = 0
            shade_f = 0.0
            for i, px in enumerate(dpx):
                c = px[x, y][:3]
                if c != base_c:
                    bits |= 1 << i
                    shade_f = c[0] / number_color[0]
            skin_map.putpixel((x, y), tuple(round(min(1.0, max(0.0, f / SCALE)) * 255)
                                            for f in (primary_f, accent_f, shade_f)))
            digit_bits.putpixel((x, y), (bits & 0xFF, bits >> 8, 0))
    base.save(os.path.join(out, name + "_skin_base.png"))
    skin_map.save(os.path.join(out, name + "_skin_map.png"))
    digit_bits.save(os.path.join(out, name + "_skin_digits.png"))
    print("gerado", os.path.normpath(os.path.join(out, name + "_skin_*.png")))


def check(name, out, reference, primary, accent, number, number_color):
    """Reconstrói uma textura já existente a partir dos mapas e mede a diferença."""
    base = Image.open(os.path.join(out, name + "_skin_base.png")).load()
    skin_map = Image.open(os.path.join(out, name + "_skin_map.png")).load()
    digit_bits = Image.open(os.path.join(out, name + "_skin_digits.png")).load()
    ref = Image.open(reference)
    worst = 0
    bit = 1 << int(number)
    for y in range(ref.height):
        for x in range(ref.width):
            m = skin_map[x, y]
            bits = digit_bits[x, y][0] | (digit_bits[x, y][1] << 8)
            if bits & bit:
                c = [number_color[k] * m[2] / 255 * SCALE for k in range(3)]
            else:
                c = [base[x, y][k] + primary[k] * m[0] / 255 * SCALE + accent[k] * m[1] / 255 * SCALE
                     for k in range(3)]
            r = ref.getpixel((x, y))[:3]
            worst = max(worst, max(abs(round(c[k]) - r[k]) for k in range(3)))
    print(f"  conferência {os.path.basename(reference)}: maior diferença {worst}/255")


def main():
    gr.DIGITS_BIG[BLANK] = ["...."] * 7
    gm.DIGITS[BLANK] = ["..."] * 5
    digits = [str(d) for d in range(10)]

    rider_out = os.path.join(ROOT, "assets", "models", "riders", "rider")
    white = gr.Palette((0, 0, 0), (0, 0, 0)).white
    build("rider", rider_out, render_rider, True, white, digits)
    check("rider", rider_out, os.path.join(rider_out, "rider.png"),
          gm.hex_color("2a5ce8"), gm.hex_color("f0d23c"), "8", white)

    bike_out = os.path.join(ROOT, "assets", "models", "bikes", "motocross")
    seat = gm.Palette((0, 0, 0)).seat
    build("motocross", bike_out, render_bike, False, seat, digits)
    check("motocross", bike_out, os.path.join(bike_out, "motocross.png"),
          gm.hex_color("e8572a"), (0, 0, 0), "8", seat)


if __name__ == "__main__":
    main()
