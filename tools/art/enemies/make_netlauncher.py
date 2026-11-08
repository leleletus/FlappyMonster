#!/usr/bin/env python3
# tools/art/enemies/make_netlauncher.py — el lanzarredes (campaña Flappy, Valle; docs/design/flappy-plan-5b-valley.md,
# tarea 2): una torreta de chatarra del Monstruo Malvado, posada en el suelo, con un tubo corto apuntando arriba.
# Base oxidada con dos tornillos, una franja roja (sus colores) y el tubo de hierro. Sin alas. Arte a x4 (la densidad de los
# objetos pequeños: cabe en una casilla): formas planas, 2-3 tonos por pieza.
#
#   python3 tools/art/enemies/make_netlauncher.py           → vista previa en FlappyMonster_pruebas/valle/
#   python3 tools/art/enemies/make_netlauncher.py --apply   → assets/images/enemies/netlauncher/netlauncher-Sheet.png
#
# netlauncher-Sheet.png: 3 cuadros de 14x14 — 1 reposo, 2 apunta (la boca brilla), 3 retroceso (el tubo se hunde y sale humo).
import os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'valle')
DEST = os.path.join(ROOT, 'assets', 'images', 'enemies', 'netlauncher')
K = 4
FW = 14


def hx(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


IRON = [hx(c) for c in ('1c1c24', '4a4a58', '7c7c8c', 'b4b4c4')]
RUST = [hx(c) for c in ('3a1c10', '7a3a1c', 'a85a2c')]
RED = [hx(c) for c in ('5a1418', '9a2428', 'cf3d34')]
FIRE = [hx(c) for c in ('ff8a28', 'ffd23c', 'fff6c0')]
SMOKE = [hx('8a8a96'), hx('c4c4d0')]


def rect(im, x0, y0, x1, y1, c):
    ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=c)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def frame(kind):
    im = Image.new('RGBA', (FW, FW), (0, 0, 0, 0))
    # base: trapecio oxidado (contorno, óxido, luz) y su franja roja
    rect(im, 1, 9, 12, 13, RUST[0])
    rect(im, 2, 10, 11, 12, RUST[1])
    rect(im, 2, 10, 11, 10, RUST[2])
    rect(im, 2, 12, 11, 12, RED[1])
    rect(im, 2, 11, 11, 11, RED[2])
    px(im, 3, 10, IRON[3]); px(im, 10, 10, IRON[3])           # tornillos
    px(im, 3, 11, IRON[1]); px(im, 10, 11, IRON[1])
    # tubo: sube desde la base; en el retroceso se hunde 2 px
    top = 3 if kind == 'recoil' else 1
    rect(im, 4, top, 9, 8, IRON[0])
    rect(im, 5, top + 1, 8, 8, IRON[1])
    rect(im, 5, top + 1, 5, 8, IRON[2])
    rect(im, 4, top, 9, top, IRON[0])
    rect(im, 5, top + 1, 8, top + 1, IRON[0])                 # la boca, hueca
    rect(im, 4, 7, 9, 8, RUST[0])                              # abrazadera al pie del tubo
    px(im, 5, 7, RUST[2]); px(im, 8, 7, RUST[2])
    if kind == 'aim':                                          # la boca brilla
        rect(im, 5, top + 1, 8, top + 1, FIRE[1])
        rect(im, 6, top + 1, 7, top + 1, FIRE[2])
        px(im, 4, top - 1, FIRE[0]); px(im, 9, top - 1, FIRE[0])
        rect(im, 5, top, 8, top, FIRE[0])
    if kind == 'recoil':                                       # humo sobre la boca
        for (x, y, c) in ((4, 1, 0), (5, 0, 1), (8, 1, 1), (9, 0, 0), (6, 1, 1), (7, 0, 0)):
            px(im, x, y, SMOKE[c])
    return im


def main():
    files = Image.new('RGBA', (FW * 3, FW), (0, 0, 0, 0))
    for i, k in enumerate(('idle', 'aim', 'recoil')):
        files.alpha_composite(frame(k), (i * FW, 0))
    if '--apply' in sys.argv:
        os.makedirs(DEST, exist_ok=True)
        files.save(os.path.join(DEST, 'netlauncher-Sheet.png'))
        print('escrito', DEST)
        return
    os.makedirs(OUT, exist_ok=True)
    pv = Image.new('RGBA', (FW * 3 * K + 40, FW * K + 20), (150, 205, 240, 255))
    pv.alpha_composite(files.resize((files.width * K, files.height * K), Image.NEAREST), (20, 10))
    pv.save(os.path.join(OUT, 'netlauncher_vista_previa.png'))
    print('vista previa en', OUT)


if __name__ == '__main__':
    main()
