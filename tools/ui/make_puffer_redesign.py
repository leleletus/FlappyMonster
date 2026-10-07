#!/usr/bin/env python3
# tools/ui/make_puffer_redesign.py
# Rediseño del pez globo (assets/images/enemies/pufferfish/puffer_fish-Sheet.png, 4 cuadros
# de 16x16: nadar 1-2, medio hinchado, hinchado), como el de los Crabbies: la MISMA
# forma (cada píxel) con el estilo nuevo, cuadro a cuadro:
#   negro → contorno azul muy oscuro; grises oscuros (cola) → azules marinos
#   blanco (cuerpo) → brillo arriba-izquierda y sombra a la derecha / abajo
#   gris medio (tripa) → gris azulado, más oscuro en su borde de abajo
#   python3 tools/ui/make_puffer_redesign.py <carpeta>   vista previa
#   python3 tools/ui/make_puffer_redesign.py --apply     al juego (original fuera del repo)
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import originals   # noqa: E402

SRC = 'assets/images/enemies/pufferfish/puffer_fish-Sheet.png'
APPLY = '--apply' in sys.argv
OUT = next((a for a in sys.argv[1:] if not a.startswith('--')), '/tmp/puffer_redesign')
FW = 16

O = (30, 30, 42, 255)
W, H, S = (242, 242, 246, 255), (255, 255, 255, 255), (196, 200, 214, 255)
TAIL = {21: (34, 36, 52, 255), 32: (48, 50, 70, 255), 47: (66, 70, 96, 255)}
BELLY, BELLY_D = (150, 158, 182, 255), (118, 126, 152, 255)


def frame(im):
    w, h = im.size
    px = lambda x, y: im.getpixel((x, y)) if 0 <= x < w and 0 <= y < h else (0, 0, 0, 0)
    white = lambda x, y: px(x, y)[3] and px(x, y)[:3] == (255, 255, 255)
    belly = lambda x, y: px(x, y)[3] and px(x, y)[:3] == (113, 113, 113)
    rows = {}
    for y in range(h):
        xs = [x for x in range(w) if white(x, y)]
        if xs: rows[y] = (min(xs), max(xs))
    ys = sorted(rows)
    allx = [x for y in rows for x in rows[y]]
    cx = (min(allx) + max(allx)) / 2 if allx else w / 2
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            p = px(x, y)
            if not p[3]: continue
            v = p[0]
            if white(x, y):
                x0, x1 = rows[y]
                c = W
                if x == x1: c = S
                elif y == ys[0] and x <= x0 + 1: c = H
            elif belly(x, y):
                c = BELLY_D if (not belly(x, y + 1) and x >= cx) or not belly(x + 1, y) else BELLY
            elif v == 0:
                c = O
            else:
                c = TAIL.get(v, O)
            out.putpixel((x, y), c)
    return out


def sheet():
    o = originals.path(SRC)
    im = Image.open(o if os.path.exists(o) else SRC).convert('RGBA')
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    for i in range(im.width // FW):
        out.paste(frame(im.crop((i * FW, 0, i * FW + FW, im.height))), (i * FW, 0))
    return out


if __name__ == '__main__':
    if APPLY:
        originals.keep(SRC)
        sheet().save(SRC)
        print('  ' + SRC + ' (original fuera del repo)')
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    sheet().save(os.path.join(OUT, 'puffer_fish-Sheet.png'))
    print('PRUEBA en', OUT)
