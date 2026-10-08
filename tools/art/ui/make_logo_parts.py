#!/usr/bin/env python3
# tools/art/ui/make_logo_parts.py — corta el logo de mtvemo (assets/startup/mtvemo_logo.png, dibujado por el usuario:
# NO se toca) en sus seis letras, para que la pantalla de inicio (src/states/menu/StartupState.lua) las saque una a
# una con la melodía, EN PIXEL ART (el original es un dibujo liso; el juego es de píxeles). Escribe
# assets/startup/parts/<n>_<letra>.png (recortadas) y assets/startup/logo.json (dónde va cada una, en píxeles del logo). Cada trazo suelto del logo se asigna a su letra por dónde cae.
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
# PIXEL ART: el logo se reduce a 1/PX (cada píxel nuevo = un bloque de PX x PX del original; negro si la tinta cubre
# al menos COVER del bloque), sin bordes suavizados, como el resto del juego. Cada letra por separado, en la misma
# rejilla, para que juntas casen.
PX, COVER = 16, 0.34
os.makedirs(OUT, exist_ok=True)
for old in os.listdir(OUT): os.remove(os.path.join(OUT, old))
gh, gw = H // PX, W // PX
# SIMÉTRICAS: las seis letras del logo son simétricas (izquierda / derecha; la «e» y la «o» también arriba / abajo).
# Cada una se reduce en una rejilla CENTRADA en su propio eje, y lo que cubre cada píxel se promedia con su reflejo
# antes de decidir si es negro: así las dos mitades salen idénticas (las dos patas de la M, los dos lados de la O).
BOTH = {'e', 'o'}
# (en el original la M y la V están a medio píxel de este tamaño: sin esto se tocan; la M se aparta un píxel)
NUDGE = {'m': (-1, 0)}
parts, whole = [], np.zeros((gh, gw), dtype=bool)
for k, (name, _) in enumerate(LETTERS, 1):
    a = np.where(who == k, im[..., 3] / 255.0, 0.0)
    ys, xs = np.where(a > 0.5)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    nw, nh = int(round((x1 - x0) / PX)), int(round((y1 - y0) / PX))
    cx = (x0 + x1) / 2.0
    sx0 = int(round(cx - nw * PX / 2.0))                              # (la rejilla, centrada en el eje de la letra)
    sy0 = int(round((y0 + y1) / 2.0 - nh * PX / 2.0)) if name in BOTH else y0
    pad = np.zeros((H + 2 * PX, W + 2 * PX)); pad[PX:PX + H, PX:PX + W] = a
    cov = pad[sy0 + PX:sy0 + PX + nh * PX, sx0 + PX:sx0 + PX + nw * PX].reshape(nh, PX, nw, PX).mean(axis=(1, 3))
    cov = (cov + cov[:, ::-1]) / 2
    if name in BOTH: cov = (cov + cov[::-1]) / 2
    m = cov >= COVER
    rows, cols = np.where(m.any(axis=1))[0], np.where(m.any(axis=0))[0]
    m = m[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
    px, py = int(round(sx0 / PX)) + int(cols[0]) + NUDGE.get(name, (0, 0))[0], int(round(sy0 / PX)) + int(rows[0]) + NUDGE.get(name, (0, 0))[1]
    whole[py:py + m.shape[0], px:px + m.shape[1]] |= m
    piece = np.zeros(m.shape + (4,), dtype=np.uint8)
    piece[m] = (0, 0, 0, 255)
    f = '%d_%s.png' % (k, name)
    Image.fromarray(piece).save(os.path.join(OUT, f), optimize=True)
    parts.append({'file': f, 'x': px, 'y': py, 'w': int(m.shape[1]), 'h': int(m.shape[0])})
    sym = bool((m == m[:, ::-1]).all()) and (name not in BOTH or bool((m == m[::-1]).all()))
    print('  %s  %dx%d en (%d, %d)  simétrica: %s' % (f, m.shape[1], m.shape[0], px, py, 'sí' if sym else 'NO'))
json.dump({'w': gw, 'h': gh, 'pixel': PX, 'parts': parts}, open('assets/startup/logo.json', 'w'), indent=1)
# vista previa para el usuario (x8, sobre blanco)
prev = '/home/mtvemo/FlappyMonster_pruebas/logo'
os.makedirs(prev, exist_ok=True)
img = Image.fromarray(np.where(whole, 0, 255).astype(np.uint8)).resize((gw * 8, gh * 8), Image.NEAREST)
img.save(os.path.join(prev, 'vista_previa.png'))
print('  logo en pixel art: %dx%d px (tinta %d px de ancho); vista previa en %s/vista_previa.png' % (gw, gh, max(p['x'] + p['w'] for p in parts) - min(p['x'] for p in parts), prev))
