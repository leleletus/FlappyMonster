#!/usr/bin/env python3
# tools/art/enemies/make_netlauncher.py — el lanzarredes (campaña Flappy, Valle; docs/design/flappy-plan-5b-valley.md,
# tarea 2): una torreta de chatarra del Monstruo Malvado, posada en el suelo, con un tubo corto apuntando arriba.
# Base oxidada con dos tornillos, una franja roja (sus colores) y el tubo de hierro. Sin alas. Arte a x4 (la densidad de los
# objetos pequeños: cabe en una casilla): formas planas, 2-3 tonos por pieza.
#
#   python3 tools/art/enemies/make_netlauncher.py           → vista previa en FlappyMonster_pruebas/valle/
#   python3 tools/art/enemies/make_netlauncher.py --apply [--force]   → los archivos de abajo (sin --force no pisa los que
#                                                                      ya existen)
#
# netlauncher-Sheet.png: 3 cuadros de 14x14 — 1 reposo, 2 apunta (la boca brilla), 3 retroceso (el tubo se hunde y sale humo).
# Y su SOPORTE (Plan 5d: las etapas Flappy no tienen suelo; el lanzarredes se posa en un poste de hierro que sube desde el
# borde de abajo), el tile `mount` (src/world/tiles/types/mount.lua), 16x16 a x4 como los pilares:
#   assets/images/world/tiles/mount_top.png  la placa de arriba (oxidada, dos tornillos) sobre el poste
#   assets/images/world/tiles/mount.png      el poste (se repite en vertical: remaches y una junta)
import os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'valle')
DEST = os.path.join(ROOT, 'assets', 'images', 'enemies', 'netlauncher')
TILES = os.path.join(ROOT, 'assets', 'images', 'world', 'tiles')
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


# El SOPORTE: mapa de caracteres de 16x16 (o contorno, d hierro oscuro, m hierro, h luz/remache, R/u/U óxido)
MOUNT_PAL = {'.': (0, 0, 0, 0), 'o': IRON[0], 'd': IRON[1], 'm': IRON[2], 'h': IRON[3],
             'R': RUST[0], 'u': RUST[1], 'U': RUST[2]}
POST = '..ohmmmmmmmmdo..'
RIVET = '..ohmhmmmmhmdo..'
SEAM = '..oddddddddddo..'
MOUNT_BODY = [POST, POST, POST, RIVET, POST, POST, POST, SEAM,
              POST, POST, POST, RIVET, POST, POST, POST, SEAM]
MOUNT_TOP = ['oooooooooooooooo',
             'oUUUUUUUUUUUUUUo',
             'ouhuuuuuuuuuuhuo',
             'oRRRRRRRRRRRRRRo',
             'oooooooooooooooo'] + MOUNT_BODY[5:]


def tile(rows):
    assert len(rows) == 16 and all(len(r) == 16 for r in rows)
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            im.putpixel((x, y), MOUNT_PAL[ch])
    return im.resize((64, 64), Image.NEAREST)


def save(im, dest):
    if os.path.exists(dest) and '--force' not in sys.argv:
        print('%s ya existe: no se toca (--force para pisarlo)' % dest)
        return
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    im.save(dest)
    print('escrito', dest)


def main():
    files = Image.new('RGBA', (FW * 3, FW), (0, 0, 0, 0))
    for i, k in enumerate(('idle', 'aim', 'recoil')):
        files.alpha_composite(frame(k), (i * FW, 0))
    top, body = tile(MOUNT_TOP), tile(MOUNT_BODY)
    if '--apply' in sys.argv:
        save(files, os.path.join(DEST, 'netlauncher-Sheet.png'))
        save(top, os.path.join(TILES, 'mount_top.png'))
        save(body, os.path.join(TILES, 'mount.png'))
        return
    os.makedirs(OUT, exist_ok=True)
    # (la tira de cuadros y, al lado, el lanzarredes de pie en su soporte de dos casillas, a la escala del juego)
    pv = Image.new('RGBA', (FW * 3 * K + 40 + 64 + 20, 64 * 3 + 20), (150, 205, 240, 255))
    pv.alpha_composite(files.resize((files.width * K, files.height * K), Image.NEAREST), (20, 10))
    x0 = FW * 3 * K + 40
    pv.alpha_composite(top, (x0, 10 + 64))
    pv.alpha_composite(body, (x0, 10 + 128))
    pv.alpha_composite(frame('idle').resize((FW * K, FW * K), Image.NEAREST), (x0 + 32 - FW * K // 2, 10 + 64 - FW * K))
    pv.save(os.path.join(OUT, 'netlauncher_vista_previa.png'))
    print('vista previa en', OUT)


if __name__ == '__main__':
    main()
