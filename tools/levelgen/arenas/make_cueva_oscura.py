#!/usr/bin/env python3
# tools/levelgen/arenas/make_cueva_oscura.py → cueva_oscura.json (arena de pruebas: nivel A OSCURAS
# con Crabbies lúgubres: suelo, repisas, columnas y techo bajo por donde trepan)
#   python3 tools/levelgen/arenas/make_cueva_oscura.py
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

EMPTY, SOLID, BORDER, DROP, FINISH, DEEP = 0, 1, 4, 10, 11, 36
W, H = 44, 13


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W): put(c, 12, SOLID)
    for c in range(9, 12): put(c, 9, SOLID)                 # repisa
    for r in (10, 11): put(16, r, SOLID)                    # columna baja
    for c in range(19, 24): put(c, 8, DROP)                 # plataforma
    for r in range(2, 6): put(27, r, SOLID)                 # estalactita gorda
    for c in range(30, 34): put(c, 9, SOLID)
    for r in (9, 10, 11): put(41, r, FINISH)
    ents = [
        {'type': 'gloomy', 'col': 12, 'row': 11},
        {'type': 'gloomy', 'col': 21, 'row': 2, 'props': {'attach': 'ceiling'}},
        {'type': 'gloomy', 'col': 31, 'row': 8},
        {'type': 'gloomy', 'col': 37, 'row': 11},
        {'type': 'gummy', 'col': 25, 'row': 11, 'props': {'patrol': {'left': 18, 'right': 29}}},
    ]
    return {
        'name': 'Prueba: cueva a oscuras', 'name_en': 'Test: dark cave',
        'width': W, 'height': H, 'playerStart': [3, 11],
        'tiles': t, 'entities': ents, 'foliage': [], 'vents': [],
        'background': 'cave', 'time': 'night', 'dark': True, 'modes': ['race'], 'music': 'dark_cave',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'cueva_oscura.json')
    write(build(), out)
    print('escrito', out)
