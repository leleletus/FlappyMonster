#!/usr/bin/env python3
# tools/art/enemies/retouch_bomb.py
# Retoque de las hojas de la bomba del usuario (assets/images/enemies/bomb/bomb-Sheet.png
# y bombObject-Sheet.png), a partir de su dibujo:
#   * ojos: de un punto a 1x2 (más expresivos); los ojos en raya del cuadro 4
#     (a punto de explotar) se quedan
#   * boquilla: tapón metálico de 3 px encima del cuerpo, con brillo
#   * mecha: la misma forma que la suya, subida 1 px para salir del tapón y en
#     color cuerda (antes, gris casi negro: se perdía contra el contorno)
# Guarda una copia del original FUERA del repo la primera vez (tools/art/lib/originals.py).
# Después hay que regenerar las mechas encendidas:
#     python3 tools/art/enemies/make_bomb_sprites.py --force
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib'))   # (originals.py)
import originals   # noqa: E402
from PIL import Image

DIR = 'assets/images/enemies/bomb'
FW, FH = 15, 16
OLD_FUSE = (37, 37, 37, 255)
ROPE = (164, 120, 72, 255)          # mecha (cuerda)
CAP, CAP_HI = (74, 74, 88, 255), (140, 140, 156, 255)
BLACK, WHITE = (0, 0, 0, 255), (255, 255, 255, 255)


def retouch(name):
    path = os.path.join(DIR, name)
    orig, _ = originals.keep(path)
    src = Image.open(orig).convert('RGBA')
    out = src.copy()
    for f in range(src.width // FW):
        ox = f * FW
        px = lambda x, y: src.getpixel((ox + x, y))
        fuse = [(x, y) for x in range(FW) for y in range(FH) if px(x, y) == OLD_FUSE]
        # fila de arriba del cuerpo (primera fila con contorno negro)
        top = min(y for y in range(FH) for x in range(FW) if px(x, y) == BLACK)
        xs = [x for x in range(FW) if px(x, top) == BLACK]
        cx = (min(xs) + max(xs)) // 2
        # quitar la mecha vieja
        for x, y in fuse:
            out.putpixel((ox + x, y), (0, 0, 0, 0))
        # tapón (encima del cuerpo): 3 px con brillo a la izquierda
        cy = top - 1
        for dx in (-1, 0, 1):
            out.putpixel((ox + cx + dx, cy), CAP_HI if dx == -1 else CAP)
        # mecha: la misma forma, 1 px más arriba (sale del tapón)
        for x, y in fuse:
            if y - 1 >= 0 and (y - 1) < cy:
                out.putpixel((ox + x, y - 1), ROPE)
        # ojos de punto → 1x2 (un píxel negro con blanco a los lados y encima blanco)
        for y in range(top + 2, FH - 3):
            for x in range(1, FW - 1):
                if px(x, y) == BLACK and px(x - 1, y) == WHITE and px(x + 1, y) == WHITE \
                        and px(x, y - 1) == WHITE:
                    out.putpixel((ox + x, y - 1), BLACK)
    out.save(path)
    print('  ' + path + '  (original: ' + orig + ')')


if __name__ == '__main__':
    print('Retoque de la bomba:')
    retouch('bomb-Sheet.png')
    retouch('bombObject-Sheet.png')
