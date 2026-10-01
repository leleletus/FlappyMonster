#!/usr/bin/env python3
# tools/ui/make_puffer_redesign.py
# Rediseño del pez globo (assets/images/puffer_fish/puffer_fish-Sheet.png, 4 cuadros
# de 16x16: nadar 1-2, medio hinchado, hinchado), como el de los Crabbies: la MISMA
# forma (cada píxel) con el estilo nuevo, cuadro a cuadro:
#   negro → contorno azul muy oscuro; grises oscuros (cola) → azules marinos
#   blanco (cuerpo) → brillo arriba-izquierda y sombra a la derecha / abajo
#   gris medio (tripa) → gris azulado, más oscuro en su borde de abajo
#   PINCHOS (nuevo: antes no se veían): una corona de púas APARTE,
#   assets/images/puffer_fish/spikes-Sheet.png (2 cuadros de 24x24: medio hinchado /
#   hinchado), centrada en el cuerpo y dibujada DETRÁS de él (pufferfish.lua): púas
#   triangulares de verdad alrededor (menos en la cola), que no caben en el cuadro de
#   16x16. Solo dibujo: la caja que pincha no cambia
#   python3 tools/ui/make_puffer_redesign.py <carpeta>   vista previa
#   python3 tools/ui/make_puffer_redesign.py --apply     al juego (original fuera del repo)
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import originals   # noqa: E402

SRC = 'assets/images/puffer_fish/puffer_fish-Sheet.png'
SPIKES_PNG = 'assets/images/puffer_fish/spikes-Sheet.png'
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


SP, SPD = (232, 236, 246, 255), (170, 178, 200, 255)
RW = 24                                    # cuadro de la corona de púas


def spikes(full):
    """Corona de púas: triángulos que salen del cuerpo (radio r0) hasta r1; la cola
    (a la izquierda, 180°) sin púas. Contorno oscuro, cara clara con sombra."""
    import math
    im = Image.new('RGBA', (RW, RW), (0, 0, 0, 0))
    c = (RW - 1) / 2
    r0, r1 = (4.5, 9.5) if full else (4.0, 7.0)
    n = 11 if full else 8
    angs = [math.radians(-150 + i * 300 / (n - 1)) for i in range(n)]
    base = 0.2 if full else 0.24                  # media anchura angular en la base (púas finas)
    fill = [[0] * RW for _ in range(RW)]
    for y in range(RW):
        for x in range(RW):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            if r < r0 - 1 or r > r1: continue
            a = math.atan2(dy, dx)
            for ang in angs:
                d = abs((a - ang + math.pi) % (2 * math.pi) - math.pi)
                k = max(0.0, (r1 - r) / (r1 - r0))
                if d <= base * k:
                    fill[y][x] = 2 if (a - ang + math.pi) % (2 * math.pi) - math.pi > 0 else 1
                    break
    for y in range(RW):
        for x in range(RW):
            if fill[y][x]: im.putpixel((x, y), SP if fill[y][x] == 1 else SPD)
    out = im.copy()
    for y in range(RW):                           # contorno
        for x in range(RW):
            if im.getpixel((x, y))[3]: continue
            if any(0 <= x + dx < RW and 0 <= y + dy < RW and im.getpixel((x + dx, y + dy))[3]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), O)
    return out


def spike_sheet():
    out = Image.new('RGBA', (RW * 2, RW), (0, 0, 0, 0))
    out.paste(spikes(False), (0, 0)); out.paste(spikes(True), (RW, 0))
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
        spike_sheet().save(SPIKES_PNG)
        print('  ' + SRC + ' (original fuera del repo)')
        print('  ' + SPIKES_PNG)
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    sheet().save(os.path.join(OUT, 'puffer_fish-Sheet.png'))
    spike_sheet().save(os.path.join(OUT, 'spikes-Sheet.png'))
    print('PRUEBA en', OUT)
