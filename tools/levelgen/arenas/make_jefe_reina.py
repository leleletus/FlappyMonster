#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_reina.py → jefe_reina.json (arena de prueba de la REINA CARNÍVORA, jefa secreta de la jungla: una
# sala del templo; aún sin nivel). Bombas que reaparecen a los dos lados y plataformas para llegar a la flor.
#   python3 tools/levelgen/arenas/make_jefe_reina.py    (¡reescribe la arena! si la retocas en el editor, no lo ejecutes)
#   love . --editor tools/levelgen/arenas/jefe_reina.json    (probarla desde el editor)
#
# Zona: columnas 12-43 (32 de ancho), filas 3-13; suelo en la 14.
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

EMPTY, BORDER, DROP, FINISH, TEMPLE = 0, 4, 10, 11, 42
W, H = 56, 16
Z0, Z1 = 12, 43
FLOOR = 14
MID = (Z0 + Z1) // 2


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H): put(c, r, TEMPLE)
        if Z0 - 2 <= c <= Z1 + 2: put(c, 2, TEMPLE)
    for a, b, r in ((Z0, Z0 + 3, 11), (Z1 - 3, Z1, 11), (MID - 7, MID - 4, 11), (MID + 5, MID + 8, 11), (MID - 1, MID + 2, 8)):
        for c in range(a, b + 1): put(c, r, DROP)
    for r in (11, 12, 13): put(52, r, FINISH)
    ents = [
        {'type': 'carnqueen', 'col': MID, 'row': FLOOR - 1},
        {'type': 'bombobject', 'col': Z0 + 2, 'row': FLOOR - 1, 'props': {'respawn': 4}},
        {'type': 'bombobject', 'col': Z1 - 2, 'row': FLOOR - 1, 'props': {'respawn': 4}},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 3, 'props': {'corner': {'col': Z0 - 1, 'row': FLOOR - 1}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': 3, 'props': {'corner': {'col': Z1 + 3, 'row': FLOOR - 1}, 'zone': 1}},
    ]
    return {
        'name': 'Jefa: Reina Carnívora', 'name_en': 'Boss: Carnivorous Queen',
        'width': W, 'height': H, 'playerStart': [4, FLOOR - 1],
        'tiles': t, 'entities': ents, 'vents': [], 'foliage': [],
        'bossZones': [{'id': 1, 'col': Z0, 'row': 3, 'w': Z1 - Z0 + 1, 'h': FLOOR - 3}],
        'background': 'jungle', 'time': 'day', 'depth': 'temple',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'jefe_reina.json')
    write(build(), out)
    print('escrito', out)
