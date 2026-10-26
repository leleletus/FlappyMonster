#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_saltarin.py → jefe_saltarin.json (arena del SALTARÍN GIGANTE: la sima del farol)
#   python3 tools/levelgen/arenas/make_jefe_saltarin.py
#
# LA SIMA DEL FAROL (zona: columnas 12-35, filas 3-12; suelo en la 13), A OSCURAS:
#
#   ║▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒║     techo de roca
#   ║                        ║
#   ║          =====         ║     ==  plataformas traspasables: desde arriba se cae con un ground pound
#   ║====                ====║         (el ruido que lo asusta)
#   ║                        ║
#   ║     █            █     ║     █  ROCAS de 2 de alto: detrás de ellas no te alumbra su fogonazo ni su farol
#   ║■■■■■■■■■■■■■■■■■■■■■■■■║        (Lights.clear) y él las salta
#
# Entrada a la izquierda; salida (meta) a la derecha.
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

EMPTY, SOLID, BORDER, DROP, FINISH = 0, 1, 4, 10, 11
W, H = 48, 15
Z0, Z1 = 12, 35
FLOOR = 13
ROCKS = (17, 30)


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H): put(c, r, SOLID)
        put(c, 2, SOLID)
    for c in list(range(Z0, Z0 + 4)) + list(range(Z1 - 3, Z1 + 1)): put(c, 8, DROP)
    for c in range(22, 27): put(c, 6, DROP)
    for c in ROCKS:
        for r in (11, 12): put(c, r, SOLID)
    for r in (10, 11, 12): put(44, r, FINISH)
    ents = [
        {'type': 'gianthopper', 'col': 24, 'row': 12},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 3, 'props': {'corner': {'col': Z0 - 1, 'row': 12}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': 3, 'props': {'corner': {'col': Z1 + 3, 'row': 12}, 'zone': 1}},
    ]
    return {
        'name': 'Jefe: Saltarín Gigante', 'name_en': 'Boss: Giant Hopper',
        'width': W, 'height': H, 'playerStart': [4, 12],
        'tiles': t, 'entities': ents, 'foliage': [], 'vents': [],
        'bossZones': [{'id': 1, 'col': Z0, 'row': 3, 'w': Z1 - Z0 + 1, 'h': 10, 'music': 'polilla'}],
        'background': 'cave', 'time': 'night', 'dark': True,
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'jefe_saltarin.json')
    write(build(), out)
    print('escrito', out)
