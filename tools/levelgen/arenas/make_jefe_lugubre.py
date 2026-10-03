#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_lugubre.py → jefe_lugubre.json (arena del MEGA CRABBY LÚGUBRE)
#   python3 tools/levelgen/arenas/make_jefe_lugubre.py
#
# LA SIMA (zona: columnas 12-35, filas 3-12; suelo en la 13), A OSCURAS:
#
#   ║▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒║     el jefe recorre las dos paredes y el techo
#   ║                        ║
#   ║====                ====║     ==  plataformas traspasables: desde ahí se alumbra de lejos
#   ║                        ║
#   ║■■■■■■■■■■■■■■■■■■■■■■■■║     suelo liso y ANCHO (24 casillas): hay que poder alejarse 4
#                                   casillas de donde va a caer para que no apague la linterna
# Entrada a la izquierda; salida (meta) a la derecha.
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

EMPTY, SOLID, BORDER, DROP, FINISH, DEEP = 0, 1, 4, 10, 11, 36
W, H = 48, 15
Z0, Z1 = 12, 35
FLOOR = 13


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H): put(c, r, SOLID)
        put(c, 2, SOLID)
    for c in list(range(Z0, Z0 + 4)) + list(range(Z1 - 3, Z1 + 1)): put(c, 10, DROP)
    for r in (10, 11, 12): put(44, r, FINISH)
    ents = [
        {'type': 'megagloomy', 'col': 24, 'row': 5},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 3, 'props': {'corner': {'col': Z0 - 1, 'row': 12}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': 3, 'props': {'corner': {'col': Z1 + 3, 'row': 12}, 'zone': 1}},
    ]
    return {
        'name': 'Jefe: Mega Crabby lúgubre', 'name_en': 'Boss: Mega Gloomy Crabby',
        'width': W, 'height': H, 'playerStart': [4, 12],
        'tiles': t, 'entities': ents, 'foliage': [], 'vents': [],
        'bossZones': [{'id': 1, 'col': Z0, 'row': 3, 'w': Z1 - Z0 + 1, 'h': 10, 'music': 'crab_tantrum_gloomy'}],
        'background': 'cave', 'time': 'night', 'dark': True,
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'jefe_lugubre.json')
    write(build(), out)
    print('escrito', out)
