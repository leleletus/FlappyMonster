#!/usr/bin/env python3
# tools/art/ui/make_logo_parts.py — corta el logo de mtvemo (assets/startup/mtvemo_logo.png, dibujado por el usuario:
# NO se toca) en sus seis letras, para que la pantalla de inicio (src/states/menu/StartupState.lua) las saque una a
# una con la melodía. Escribe assets/startup/parts/<n>_<letra>.png (recortadas) y assets/startup/logo.json (dónde va
# cada una dentro del logo entero). Cada trazo suelto del logo se asigna a su letra por dónde cae.
# Desde la raíz del repo:  python3 tools/art/ui/make_logo_parts.py
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage

SRC, OUT = 'assets/startup/mtvemo_logo.png', 'assets/startup/parts'
# letra → rectángulo (x0, y0, x1, y1) que contiene sus trazos (la T y la V se cruzan en x: se separan por arriba/abajo)
LETTERS = [('m', (130, 230, 340, 600)), ('t', (350, 230, 625, 600)), ('v', (340, 440, 635, 720)),
           ('e', (645, 320, 945, 580)), ('m2', (970, 310, 1250, 580)), ('o', (1280, 320, 1555, 585))]

im = np.array(Image.open(SRC).convert('RGBA'))
H, W = im.shape[:2]
lab, n = ndimage.label(im[..., 3] > 40)
owner = np.zeros(n + 1, dtype=int)                       # trazo → letra (1..6)
for i, sl in enumerate(ndimage.find_objects(lab), 1):
    x0, x1, y0, y1 = sl[1].start, sl[1].stop, sl[0].start, sl[0].stop
    fits = [k for k, (_, (a, b, c, d)) in enumerate(LETTERS, 1) if x0 >= a and x1 <= c and y0 >= b and y1 <= d]
    # (la T cabe también en… nada más; la V empieza más abajo que la T: gana la que tenga el borde de arriba más cerca)
    assert fits, 'trazo sin letra: %s' % ((x0, y0, x1, y1),)
    owner[i] = min(fits, key=lambda k: abs(LETTERS[k - 1][1][1] - y0))
# los píxeles del borde suavizado (alfa bajo) van con el trazo más cercano
# (hasta 4 px: el logo trae motas casi invisibles sueltas lejos de las letras, que se dejan fuera)
dist, (iy, ix) = ndimage.distance_transform_edt(lab == 0, return_indices=True)
who = np.where(dist <= 4, owner[lab[iy, ix]], 0)
os.makedirs(OUT, exist_ok=True)
parts = []
for k, (name, _) in enumerate(LETTERS, 1):
    m = (who == k) & (im[..., 3] > 0)
    ys, xs = np.where(m)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    piece = im[y0:y1, x0:x1].copy()
    piece[~m[y0:y1, x0:x1]] = 0
    f = '%d_%s.png' % (k, name)
    Image.fromarray(piece).save(os.path.join(OUT, f), optimize=True)
    parts.append({'file': f, 'x': int(x0), 'y': int(y0), 'w': int(x1 - x0), 'h': int(y1 - y0)})
    print('  %s  %dx%d en (%d, %d)' % (f, x1 - x0, y1 - y0, x0, y0))
allx = [p['x'] for p in parts] + [p['x'] + p['w'] for p in parts]
ally = [p['y'] for p in parts] + [p['y'] + p['h'] for p in parts]
json.dump({'w': W, 'h': H, 'ink': [min(allx), min(ally), max(allx), max(ally)], 'parts': parts},
          open('assets/startup/logo.json', 'w'), indent=1)
# comprobación: las piezas juntas rehacen el logo
back = np.zeros_like(im)
for p in parts:
    pc = np.array(Image.open(os.path.join(OUT, p['file'])))
    reg = back[p['y']:p['y'] + p['h'], p['x']:p['x'] + p['w']]
    reg[pc[..., 3] > 0] = pc[pc[..., 3] > 0]
diff = back[..., 3] != im[..., 3]
print('  píxeles del logo que quedan fuera (motas): %d, alfa máximo %d de 255' % (int(diff.sum()), int(im[..., 3][diff].max()) if diff.any() else 0))
