#!/usr/bin/env python3
# tools/art/ui/make_flappy_redesign.py
# Rediseño del modo Flappy, sin perder su diseño (misma forma, mismos tamaños):
#   pipes/pipe.png         tubería (6x84, x13 en el juego): casi negra como el monstruito,
#                          con un filo más claro a la izquierda (volumen) y el borde del
#                          labio iluminado
#   level/Background.png   fondo (84x48, x15): los mismos paneles grises; cada panel con
#                          bisel (claro arriba-izquierda, oscuro abajo-derecha)
# Los originales se guardan antes FUERA del repo (tools/art/lib/originals.py) y se parte
# siempre de ellos:   python3 tools/art/ui/make_flappy_redesign.py [--apply | <carpeta>]
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib'))   # (originals.py)
import originals   # noqa: E402

SRC = 'assets/images/'
APPLY = '--apply' in sys.argv
OUT = next((a for a in sys.argv[1:] if not a.startswith('--')), '/tmp/flappy_redesign')


def src(rel):
    o = originals.path(SRC + rel)
    return o if os.path.exists(o) else SRC + rel


def pipe():
    im = Image.open(src('flappy/pipe.png')).convert('RGBA')
    w, h = im.size
    body, light, dark, lip = (12, 12, 20, 255), (50, 52, 74, 255), (6, 6, 10, 255), (74, 78, 104, 255)
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    op = lambda x, y: 0 <= x < w and 0 <= y < h and im.getpixel((x, y))[3] > 0
    for y in range(h):
        xs = [x for x in range(w) if op(x, y)]
        if not xs: continue
        x0, x1 = min(xs), max(xs)
        for x in xs:
            c = body
            if y == 0: c = lip                                   # borde del labio
            elif x == x0 + (1 if x1 - x0 >= 3 else 0): c = light  # filo de volumen
            elif x == x1: c = dark
            out.putpixel((x, y), c)
    return out


def background():
    im = Image.open(src('flappy/Background.png')).convert('RGBA')
    w, h = im.size
    mortar = im.getpixel((0, 0))
    block = lambda x, y: im.getpixel((x % w, y % h))[:3] != mortar[:3]
    base = im.getpixel((2, 1))
    lightc = tuple(min(255, int(v * 1.1)) for v in base[:3]) + (255,)
    darkc = tuple(int(v * 0.88) for v in base[:3]) + (255,)
    out = im.copy()
    for y in range(h):
        for x in range(w):
            if not block(x, y): continue
            # (el fondo se repite: los vecinos se miran dando la vuelta)
            if not block(x, y - 1) or not block(x - 1, y): out.putpixel((x, y), lightc)
            elif not block(x, y + 1) or not block(x + 1, y): out.putpixel((x, y), darkc)
    return out


if __name__ == '__main__':
    files = {'flappy/pipe.png': pipe(), 'flappy/Background.png': background()}
    if APPLY:
        print('Rediseño del modo Flappy (originales fuera del repo):')
        for rel, im in files.items():
            originals.keep(SRC + rel)
            im.save(SRC + rel)
            print('  %-36s %dx%d' % (SRC + rel, im.width, im.height))
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    for rel, im in files.items(): im.save(os.path.join(OUT, os.path.basename(rel)))
    print('PRUEBA en', OUT)
