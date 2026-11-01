#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_escorpion.py → jefe_escorpion.json (arena de prueba del ESCORPIÓN TRIPLE AGUIJÓN, jefe
# secreto del volcán; aún sin nivel ni música propia). Antes de la zona, un Escorpión pequeño para probarlo también.
#   python3 tools/levelgen/arenas/make_jefe_escorpion.py
#   love . --editor tools/levelgen/arenas/jefe_escorpion.json    (probarlo desde el editor)
#
# Zona: columnas 16-55 (40 de ancho), filas 3-14; suelo en la 15 (las colas abiertas miden unas 8 casillas: techo alto).
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

EMPTY, SOLID, BORDER, DROP, FINISH = 0, 1, 4, 10, 11
W, H = 68, 17
Z0, Z1 = 16, 55
FLOOR = 15
SIDE_ROW = 12                              # plataformas traspasables a los lados: para esquivar y caerle encima


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H): put(c, r, SOLID)
        if Z0 - 2 <= c <= Z1 + 2: put(c, 2, SOLID)
    for c in list(range(Z0, Z0 + 4)) + list(range(Z1 - 3, Z1 + 1)): put(c, SIDE_ROW, DROP)
    for c in range(33, 39): put(c, 11, DROP)
    for r in (12, 13, 14): put(64, r, FINISH)
    ents = [
        {'type': 'scorpion', 'col': 8, 'row': FLOOR - 1},
        {'type': 'giantscorpion', 'col': 38, 'row': FLOOR - 1},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 3, 'props': {'corner': {'col': Z0 - 1, 'row': FLOOR - 1}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': 3, 'props': {'corner': {'col': Z1 + 3, 'row': FLOOR - 1}, 'zone': 1}},
    ]
    return {
        'name': 'Jefe: Escorpión Triple Aguijón', 'name_en': 'Boss: Triple Strike Scorpion',
        'width': W, 'height': H, 'playerStart': [3, FLOOR - 1],
        'tiles': t, 'entities': ents, 'vents': [], 'foliage': [],
        'bossZones': [{'id': 1, 'col': Z0, 'row': 3, 'w': Z1 - Z0 + 1, 'h': FLOOR - 3}],
        'background': 'volcano', 'time': 'day',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'jefe_escorpion.json')
    write(build(), out)
    print('escrito', out)
