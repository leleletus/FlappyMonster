#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_pez.py → jefe_pez.json (arena del PEZ GLOBO GIGANTE: la cala de la resaca)
#   python3 tools/levelgen/arenas/make_jefe_pez.py
#
# LA CALA (zona: columnas 12-33, filas 3-12; suelo en la 13):
#
#   ║                              ║
#   ║          ======              ║     ==  = plataformas traspasables: las de los lados (fila 9) quedan bajo el
#   ║                              ║           agua con la marea alta; la del centro (fila 6), siempre seca: aire
#   ║====~~~~~~~~~~~~~~~~~~~~~~====║     ~~  = la marea: una inundación de la pelea (control 'boss') que empieza
#   ║   ~~~~~~~~~~~~~~~~~~~~~~~~   ║           BAJA (el pez varado: se aprende primero cuándo se le golpea),
#   ║ o                        o   ║           sube 6 casillas y vuelve a bajar; al bajar, la RESACA arrastra
#   ║■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■║           hacia la derecha (prop `undertow`). o = respiraderos (aire).
#
# Entrada a la izquierda; salida (meta) a la derecha. Música: "Resaca".
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402  (mismo formato del editor)

EMPTY, SOLID, BORDER, DROP, FINISH = 0, 1, 4, 10, 11
W, H = 46, 15
Z0, Z1 = 12, 33                     # columnas de la zona
FLOOR = 13
TIDE = dict(startLevel=0.25, maxLevel=6, startDelay=7, riseSpeed=1.2, fallSpeed=1.0, holdTime=9, lowTime=9,
            undertow=130)


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H): put(c, r, SOLID)
    for c in list(range(Z0, Z0 + 4)) + list(range(Z1 - 3, Z1 + 1)): put(c, 9, DROP)     # plataformas de los lados
    for c in range(20, 26): put(c, 6, DROP)                                               # el refugio seco del centro
    for r in (10, 11, 12): put(42, r, FINISH)
    ents = [
        {'type': 'giantpuffer', 'col': 23, 'row': 12},
        {'type': 'flood', 'col': Z0, 'row': 4, 'props': dict(TIDE, control='boss', id=1,
                                                             corner={'col': Z1, 'row': 12})},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 3, 'props': {'corner': {'col': Z0 - 1, 'row': 12}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': 3, 'props': {'corner': {'col': Z1 + 3, 'row': 12}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 2, 'props': {'corner': {'col': Z1 + 3, 'row': 2}, 'zone': 1}},
    ]
    return {
        'name': 'Jefe: Pez Globo Gigante', 'name_en': 'Boss: Giant Pufferfish',
        'width': W, 'height': H, 'playerStart': [4, 12],
        'tiles': t, 'entities': ents,
        'foliage': [],
        'vents': [{'col': 16, 'row': 12, 'sub': 3}, {'col': 29, 'row': 12, 'sub': 3}],
        'bossZones': [{'id': 1, 'col': Z0, 'row': 3, 'w': Z1 - Z0 + 1, 'h': 10, 'music': 'resaca'}],
        'background': 'coast', 'time': 'day',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'jefe_pez.json')
    write(build(), out)
    print('escrito', out)
