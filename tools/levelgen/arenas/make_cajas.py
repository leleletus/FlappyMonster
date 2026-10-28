#!/usr/bin/env python3
# tools/levelgen/arenas/make_cajas.py → cajas.json (arena de PRUEBA de lo nuevo de 0.5.68: Caja, Caja pequeña, Balanza,
# bomba objeto que se carga y reaparece, Soplón, Semilla). Seis tramos, uno por isla (prop `isle` fija), para ver el aspecto de cada una:
#   python3 tools/levelgen/arenas/make_cajas.py
#   tools/tests/run.sh level_shots -- tools/levelgen/arenas/cajas.json
#   love . --editor tools/levelgen/arenas/cajas.json   (y jugarlo desde el editor)
#
#  ║          (polea)                ║   cada tramo (12 columnas): una Balanza colgada del techo con la Caja grande cayendo
#  ║       ╔═════╗                   ║   en su platillo izquierdo, una caja pequeña y una bomba objeto en el suelo
#  ║    [=====] [=====]              ║
#  ║                    □  ●         ║
#  ║■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■║
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402  (mismo formato del editor)

EMPTY, SOLID, BORDER, FINISH = 0, 1, 4, 11
ISLES = ['pradera', 'costa', 'fortaleza', 'nieve', 'cueva', 'volcan']
SEG = 14
W, H = 2 + SEG * len(ISLES) + 4, 16
FLOOR = 14


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H): put(c, r, SOLID)
    for r in (11, 12, 13): put(W - 2, r, FINISH)
    ents = []
    for i, isle in enumerate(ISLES):
        c0 = 3 + i * SEG
        ents += [
            {'type': 'scale', 'col': c0 + 5, 'row': 2, 'props': {'span': 6, 'drop': 6, 'travel': 2, 'isle': isle}},
            {'type': 'box', 'col': c0 + 2, 'row': 4, 'props': {'isle': isle}},
            {'type': 'smallbox', 'col': c0 + 10, 'row': FLOOR - 1, 'props': {'isle': isle}},
            {'type': 'bombobject', 'col': c0 + 12, 'row': FLOOR - 1, 'props': {'respawn': 3}},
            {'type': 'gust', 'col': c0 + 11, 'row': 8, 'props': {'isle': isle}},
            {'type': 'seed', 'col': c0 + 8, 'row': FLOOR - 1, 'props': {'isle': isle}},
        ]
    return {
        'name': 'Prueba: cajas y balanza', 'name_en': 'Test: boxes and scale',
        'width': W, 'height': H, 'playerStart': [2, FLOOR - 1],
        'tiles': t, 'entities': ents, 'foliage': [],
        'background': 'meadow', 'time': 'day',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'cajas.json')
    write(build(), out)
    print('escrito', out)
