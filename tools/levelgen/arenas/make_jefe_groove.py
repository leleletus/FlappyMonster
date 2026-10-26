#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_groove.py → jefe_groove.json (arena de EL GROOVE, el jefe secreto: el escenario)
#   python3 tools/levelgen/arenas/make_jefe_groove.py
#
# EL ESCENARIO (zona: columnas 12-35, filas 3-12; suelo en la 13), a cielo abierto:
#
#   ║                        ║     sin techo: su trampolín te lanza ~8 casillas (cabe en la zona)
#   ║                        ║
#   ║                        ║
#   ║====                ====║     ==  plataformas traspasables a los lados: de las ONDAS se sube aquí, pero ahí
#   ║                        ║         te alcanzan sus NOTAS
#   ║                        ║
#   ║■■■■■■■■■■■■■■■■■■■■■■■■║     suelo LLANO: él no tiene física, sus saltos son pura función del tiempo
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


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H): put(c, r, SOLID)
    for c in list(range(Z0 + 1, Z0 + 5)) + list(range(Z1 - 4, Z1)): put(c, 8, DROP)
    for r in (10, 11, 12): put(44, r, FINISH)
    ents = [
        {'type': 'groovecrab', 'col': 24, 'row': 12},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 3, 'props': {'corner': {'col': Z0 - 1, 'row': 12}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': 3, 'props': {'corner': {'col': Z1 + 3, 'row': 12}, 'zone': 1}},
    ]
    return {
        'name': 'Jefe: El Groove', 'name_en': 'Boss: The Groove',
        'width': W, 'height': H, 'playerStart': [4, 12],
        'tiles': t, 'entities': ents, 'foliage': [], 'vents': [],
        'bossZones': [{'id': 1, 'col': Z0, 'row': 3, 'w': Z1 - Z0 + 1, 'h': 10, 'music': 'groove'}],
        'background': 'coast',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'jefe_groove.json')
    write(build(), out)
    print('escrito', out)
