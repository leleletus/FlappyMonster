#!/usr/bin/env python3
# tools/levelgen/arenas/make_islas.py → islas.json (arena de PRUEBA de lo que cambia por ISLA en los enemigos y objetos:
# src/world/level/Isles.lua). Un tramo por isla: el Gummy, el Crabby (pincho) y el Crabby con trampolín de su FAMILIA
# (prop `isle` fija: al cargar cambian al tipo de esa isla), el Saltarín y la comida con su aspecto, y un Géiser.
# Quietos (movement static) para la foto; en el juego, con `love . --editor`, se ven andar.
#   python3 tools/levelgen/arenas/make_islas.py
#   tools/tests/run.sh level_shots SCALE=0.5 -- tools/levelgen/arenas/islas.json
#   love . --editor tools/levelgen/arenas/islas.json   (y jugarlo desde el editor)
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402  (mismo formato del editor)

EMPTY, SOLID, BORDER, FINISH = 0, 1, 4, 11
ISLES = ['pradera', 'costa', 'fortaleza', 'nieve', 'cueva', 'volcan', 'jungla']   # (el orden de Isles.IDS)
SEG = 12
W, H = 2 + SEG * len(ISLES) + 4, 10
FLOOR = 8


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H): put(c, r, SOLID)
    for r in (5, 6, 7): put(W - 2, r, FINISH)
    still = {'movement': 'static', 'pauses': False}
    ents = []
    for i, isle in enumerate(ISLES):
        c0 = 3 + i * SEG
        ents += [
            {'type': 'gummy', 'col': c0, 'row': FLOOR - 1, 'props': dict(still, isle=isle)},
            {'type': 'crabby', 'col': c0 + 2, 'row': FLOOR - 1, 'props': dict(still, isle=isle)},
            {'type': 'crabbytramp', 'col': c0 + 4, 'row': FLOOR - 1, 'props': dict(still, isle=isle)},
            {'type': 'hopper', 'col': c0 + 6, 'row': FLOOR - 1, 'props': {'skin': isle, 'range': 1}},
            {'type': 'apple', 'col': c0 + 8, 'row': FLOOR - 2, 'props': {'skin': isle}},
            {'type': 'geyser', 'col': c0 + 9, 'row': FLOOR - 1, 'props': {'isle': isle, 'firstDelay': 0, 'warn': 0.2,
                                                                          'erupt': 9, 'interval': 9, 'height': 3}},
        ]
    return {
        'name': 'Prueba: cada isla', 'name_en': 'Test: every island',
        'width': W, 'height': H, 'playerStart': [2, FLOOR - 1],
        'tiles': t, 'entities': ents, 'foliage': [],
        'background': 'meadow', 'time': 'day',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'islas.json')
    write(build(), out)
    print('escrito', out)
