#!/usr/bin/env python3
# tools/anim/make_strip_sets.py — un CONJUNTO DE ANIMACIÓN por cada TIRA que carga el juego con SpriteStrip
# (decoraciones, bombas, jefes, efectos, interfaz…), para que se vean y se editen en `love . --anim`.
#
# Las tiras salen de una CAPTURA: el juego apunta cada tira que carga sin conjunto cuando se ejecuta con
#   FM_ANIM_CAPTURE=/tmp/tiras.tsv tools/tests/run.sh all
# y luego:   python3 tools/anim/make_strip_sets.py /tmp/tiras.tsv
# Nunca pisa un conjunto que ya existe (--force para rehacerlos). Id = la ruta de la imagen sin assets/images/ ni
# .png; cuadros = la rejilla con el ancho que pide el código; una secuencia `all` con todos (8 fps).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import write, REPO

force = '--force' in sys.argv
files = [a for a in sys.argv[1:] if not a.startswith('--')]
seen, made, kept = {}, 0, 0
for f in files:
    for line in open(f, encoding='utf-8'):
        p = line.rstrip('\n').split('\t')
        if len(p) == 4:
            seen[p[0]] = (int(float(p[1])), int(float(p[2])), int(float(p[3])))
for path in sorted(seen):
    fw, w, h = seen[path]
    if not path.startswith('assets/images/') or not os.path.exists(os.path.join(REPO, path)) or w <= 16 and h <= 16 and w == fw and False:
        continue
    n = max(1, w // fw)
    sid = path[len('assets/images/'):-len('.png')]
    doc = {
        'id': sid, 'strip': {'frameW': fw}, 'scale': 4, 'origin': [0.5, 0.5], 'fallback': 'all',
        'meta': {'code': True},
        'frames': [{'image': path, 'x': i * fw, 'y': 0, 'w': fw, 'h': h} for i in range(n)],
        'anims': {'all': {'frames': list(range(1, n + 1)), 'fps': 8, 'loop': True}},
    }
    if write(doc, force): made += 1
    else: kept += 1
print('tiras en la captura: %d · conjuntos nuevos: %d · ya existían: %d' % (len(seen), made, kept))
