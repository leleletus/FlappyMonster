#!/usr/bin/env python3
# tools/levelgen/arenas/make_costa_helada.py → costa_helada.json: escaparate de la COSTA HELADA (fondo `frozen_coast` de
# src/fx/Sky.lua y las decoraciones de `frozen_coast_set`): una pantalla con orilla de nieve, el mar con un témpano de
# hielo, un pilar de hielo, una plataforma con la red colgando y un Crabby helado.
#   python3 tools/levelgen/arenas/make_costa_helada.py
#   tools/tests/run.sh level_shots SCALE=1 TIME=night -- tools/levelgen/arenas/costa_helada.json   (TIME: day|dusk|night)
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

EMPTY, WATER, DROP, SNOW, ICE = 0, 9, 10, 29, 30
W, H = 20, 12


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, 8):                                  # orilla de la izquierda
        for r in range(10, H + 1): put(c, r, SNOW)
    for c in range(14, W + 1):                             # orilla de la derecha, un escalón más alta
        for r in range(9, H + 1): put(c, r, SNOW)
    for c in range(8, 14):                                 # el mar, con un témpano de hielo
        for r in range(10, H + 1): put(c, r, WATER)
    put(10, 10, ICE); put(11, 10, ICE)
    for r in range(6, 9): put(18, r, ICE); put(19, r, ICE)
    for c in range(4, 7): put(c, 6, DROP)
    fol = [
        {'type': 'rowboat', 'col': 1, 'row': 9}, {'type': 'anchor', 'col': 5, 'row': 9},
        {'type': 'kelp_rock', 'col': 6, 'row': 9}, {'type': 'starfish_ice', 'col': 7, 'row': 9, 'sub': 3},
        {'type': 'bollard', 'col': 7, 'row': 9, 'sub': 4}, {'type': 'net_hang', 'col': 5, 'row': 7},
        {'type': 'floe', 'col': 13, 'row': 9}, {'type': 'buoy', 'col': 14, 'row': 8},
        {'type': 'ice_chunks', 'col': 15, 'row': 8, 'sub': 4}, {'type': 'crab_pot', 'col': 17, 'row': 8},
        {'type': 'iceberg', 'col': 20, 'row': 8},
    ]
    for f in fol: f['props'] = {'layer': 'back'}
    return {
        'name': 'Prueba: costa helada', 'name_en': 'Test: frozen coast',
        'width': W, 'height': H, 'playerStart': [3, 9],
        'tiles': t, 'entities': [{'type': 'crabby_ice', 'col': 16, 'row': 8, 'props': {}}], 'foliage': fol, 'vents': [],
        'background': 'frozen_coast', 'time': 'day', 'snow': True, 'spikeSkin': 'ice',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'costa_helada.json')
    write(build(), out)
    print('escrito', out)
