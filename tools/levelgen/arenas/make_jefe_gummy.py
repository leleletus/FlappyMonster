#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_gummy.py → jefe_gummy.json (arena del REY GUMMY: el salón del trono)
#   python3 tools/levelgen/arenas/make_jefe_gummy.py
#
# EL SALÓN DEL TRONO (zona: columnas 12-33, filas 3-12; suelo en la 13):
#
#   ║                              ║
#   ║            ====              ║     ==  = plataformas traspasables (3 y 6 casillas sobre el
#   ║                              ║           suelo): refugio de las olas y del panzazo (si te
#   ║====                      ====║           subes, el rey cae en la plataforma: se ve en la marca)
#   ║                              ║
#   ║■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■║     suelo liso: las olas de gelatina corren de punta a punta
#
#  Fase 1: saltitos + PANZAZO (la marca te sigue, se fija al final): salta la ola, pisotón/GP
#          mientras está mareado.  Fase 2: dos panzazos seguidos y la GUARDIA REAL (Gummies por
#          los lados).  Fase 3: se DIVIDE en 3 Gummies medianos: acaba con todos.
# Entrada a la izquierda; salida (meta) a la derecha.
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402  (mismo formato del editor)

EMPTY, SOLID, BORDER, DROP, FINISH = 0, 1, 4, 10, 11
W, H = 46, 15
Z0, Z1 = 12, 33                     # columnas de la zona
FLOOR = 13


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H): put(c, r, SOLID)
    # plataformas: laterales (fila 10) y la del medio (7)
    for c in list(range(Z0, Z0 + 4)) + list(range(Z1 - 3, Z1 + 1)): put(c, 10, DROP)
    for c in range(21, 25): put(c, 7, DROP)
    for r in (10, 11, 12): put(42, r, FINISH)
    ents = [
        {'type': 'megagummy', 'col': 23, 'row': 12},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 3, 'props': {'corner': {'col': Z0 - 1, 'row': 12}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': 3, 'props': {'corner': {'col': Z1 + 3, 'row': 12}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 2, 'props': {'corner': {'col': Z1 + 3, 'row': 2}, 'zone': 1}},
    ]
    return {
        'name': 'Jefe: Rey Gummy', 'name_en': 'Boss: Gummy King',
        'width': W, 'height': H, 'playerStart': [4, 12],
        'tiles': t, 'entities': ents,
        'foliage': [],
        'vents': [],
        'bossZones': [{'id': 1, 'col': Z0, 'row': 3, 'w': Z1 - Z0 + 1, 'h': 10, 'music': 'boss_nes'}],
        'background': 'meadow', 'time': 'day',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'jefe_gummy.json')
    write(build(), out)
    print('escrito', out)
