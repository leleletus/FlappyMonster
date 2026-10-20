#!/usr/bin/env python3
# tools/art/fx/make_lights.py — las LUCES del lienzo de luz (src/fx/Darkness.lua), como imágenes: así cada luz es UN
# dibujo (y las seguidas van en un solo lote) en vez de varios círculos. Blanco, en escalones; el color y la fuerza
# los pone el código con setColor (mezcla aditiva).
#   assets/images/fx/light_disc.png    un disco lleno (las luces a oscuras: dos discos de distinto radio)
#   assets/images/fx/light_rings.png   5 anillos que suman (luces de decoraciones y tiles de noche / en cueva):
#                                      valor = anillos que cubren el píxel / 5, radios 1 - i/5 · 0,85
#   assets/images/fx/light_halo.png    lo mismo con radios 1 - i/5 · 0,8 (el halo de los jugadores)
# Radio 32 px (64 x 64); el código los escala al radio de cada luz.
#   python3 tools/art/fx/make_lights.py
import os
from PIL import Image

DIR = 'assets/images/fx'
R = 32
RINGS = 5


def make(name, fracs):
    im = Image.new('RGBA', (2 * R, 2 * R), (0, 0, 0, 0))
    for y in range(2 * R):
        for x in range(2 * R):
            d = (((x + 0.5 - R) ** 2 + (y + 0.5 - R) ** 2) ** 0.5) / R
            n = sum(1 for f in fracs if d <= f)
            if n:
                v = round(255 * n / len(fracs))
                im.putpixel((x, y), (v, v, v, 255))
    im.save(os.path.join(DIR, name))
    print(name)


if __name__ == '__main__':
    make('light_disc.png', [1.0])
    make('light_rings.png', [1 - i / RINGS * 0.85 for i in range(RINGS)])
    make('light_halo.png', [1 - i / RINGS * 0.8 for i in range(RINGS)])
