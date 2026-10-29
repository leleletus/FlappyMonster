#!/usr/bin/env python3
# tools/levelgen/arenas/make_decoraciones.py → decoraciones.json: el ESCAPARATE de todas las decoraciones, una franja
# por categoría (cada una con el suelo de su isla), para verlas de una vez:
#   python3 tools/levelgen/arenas/make_decoraciones.py
#   tools/tests/run.sh level_shots SCALE=0.35 -- tools/levelgen/arenas/decoraciones.json
#   tools/tests/run.sh editor_open PLAY=tools/levelgen/arenas/decoraciones.json
#
# La lista sale de docs/reference/decorations-and-modes.md (la escribe el JUEGO: `run.sh docs_reference`), así que
# una decoración nueva entra sola al volver a generar. Lo que cuelga va al final de su franja, del techo; lo demás
# sobre el suelo, separado según su ancho (de los conjuntos de animación).
#
#  ║■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■║   techo (= suelo de la franja de arriba)
#  ║                                 ¦  ¦ ¦  ¦  ║   colgantes
#  ║   ♣        ♠     ¥   ∆  ·  ·               ║   10 casillas de aire: caben los árboles grandes (8)
#  ║■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■║   suelo de la isla
import glob
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402  (mismo formato del editor)

EMPTY, SOLID, BORDER, WATER = 0, 1, 4, 9
GRASS, SNOW, SAND, BASALT = 17, 29, 35, 38
AIR = 10                                   # filas de aire por franja
# Franjas: (categoría o categorías, tile del suelo, agua)
STRIPS = [
    (('Plantas', 'Grandes', 'Pequeñas (subcelda)', 'Pradera'), GRASS, False),
    (('Tropical',), SAND, False),
    (('Acuático',), SAND, True),
    (('Hielo y nieve',), SNOW, False),
    (('Volcán',), BASALT, False),
    (('Cueva',), SOLID, False),
    (('Fortaleza',), SOLID, False),
    (('Jungla',), GRASS, False),
    (('Costa helada',), SNOW, False),
]
# Las que cuelgan del techo de su casilla / subcelda (DecoFx.sheet / wave con hang)
HANG = {'stalactite', 'cobweb', 'icicle', 'icicle_small', 'lava_fall', 'hanging_roots', 'banner', 'ivy_hang',
        'liana_long', 'liana_mid', 'liana_short', 'hanging_moss', 'flower_vine', 'hanging_orchid', 'net_hang'}
WIDE = {'butterflies': 32, 'fireflies': 40, 'dragonfly': 32}      # (las que vuelan: su zona)


def catalog():
    """[(nombre, categoría, colocación)] en el orden de la tabla generada"""
    out = []
    for line in open(os.path.join(ROOT, 'docs/reference/decorations-and-modes.md'), encoding='utf-8'):
        m = re.match(r'^\| `([a-z0-9_]+)` \| [^|]* \| ([^|]+) \| (sub|cell) \|', line)
        if m: out.append((m.group(1), m.group(2).strip(), m.group(3)))
    return out


def widths():
    """ancho en px de arte de cada animación de los conjuntos de decoraciones (el primer cuadro)"""
    w = {}
    for p in glob.glob(os.path.join(ROOT, 'assets/anim/world/decorations/**/*.json'), recursive=True):
        d = json.load(open(p, encoding='utf-8'))
        sub = os.path.relpath(p, os.path.join(ROOT, 'assets/anim/world/decorations'))[:-5].replace(os.sep, '/')
        for name, a in d.get('anims', {}).items():
            f = d['frames'][a['frames'][0] - 1]
            fw = f.get('w')
            if fw is None and f.get('image'):
                from PIL import Image
                fw = Image.open(os.path.join(ROOT, f['image'])).width
            w[name] = max(w.get(name, 0), fw or 16)
            w[sub.split('/')[-1]] = max(w.get(sub.split('/')[-1], 0), fw or 16)     # (palmeras: su conjunto)
    return w


def art_w(name, W):
    for k in (name, name + '_trunk', {'tropical_bush': 'bush', 'cave_crystals': 'crystals'}.get(name, '')):
        if k in W: return W[k]
    return WIDE.get(name, 16)


def build():
    cat, W = catalog(), widths()
    rows = []                     # una lista de decoraciones por franja
    for cats, ground, water in STRIPS:
        rows.append([c for c in cat if c[1] in cats])
    # Columnas de cada franja
    plans, width = [], 0
    for items in rows:
        col, plan = 3, []
        ground = [it for it in items if it[0] not in HANG]
        hang = [it for it in items if it[0] in HANG]
        for name, _, place in ground:
            n = max(1, math.ceil((art_w(name, W) - 2) / 16))
            plan.append((name, place, col + n // 2, False))      # (centrada: no se sale por la izquierda)
            col += n + 1
        col += 1
        for name, _, place in hang:
            n = max(1, math.ceil((art_w(name, W) - 2) / 16))
            plan.append((name, place, col + n // 2, True))
            col += n + 1
        plans.append(plan)
        width = max(width, col + 1)
    W_ = width + 1
    H = 1 + len(STRIPS) * (AIR + 1) + 1
    t = [[EMPTY] * W_ for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W_ + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W_, r, BORDER)
    foliage = []
    for i, ((cats, ground, water), plan) in enumerate(zip(STRIPS, plans)):
        top = 1 + i * (AIR + 1)               # techo (fila del suelo de la franja de arriba, o el borde)
        floor = top + AIR + 1
        for c in range(2, W_):
            if floor < H: put(c, floor, ground)
            if water:
                for r in range(top + 1, floor): put(c, r, WATER)
        for name, place, c, hang in plan:
            row = top + 1 if hang else floor - 1
            f = {'type': name, 'col': c, 'row': row}
            if place == 'sub': f['sub'] = 1 if hang else 3
            foliage.append(f)
    return {
        'name': 'Prueba: decoraciones', 'name_en': 'Test: decorations',
        'width': W_, 'height': H, 'playerStart': [2, AIR + 1],
        'tiles': t, 'entities': [], 'foliage': foliage, 'vents': [],
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'decoraciones.json')
    d = build()
    write(d, out)
    print('escrito %s: %dx%d, %d decoraciones' % (out, d['width'], d['height'], len(d['foliage'])))
