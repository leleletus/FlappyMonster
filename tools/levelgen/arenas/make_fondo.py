#!/usr/bin/env python3
# tools/levelgen/arenas/make_fondo.py → fondo.json: escaparate del PLANO DE FONDO (src/world/level/BackPlane.lua): delante
# el terreno de la jungla de siempre; DETRÁS, muros y columnas del templo, una arcada, un árbol grande (los árboles grandes
# van siempre al fondo) y decoraciones de fondo — más oscuros y con la sombra de los bloques de delante.
#   python3 tools/levelgen/arenas/make_fondo.py
#   tools/tests/run.sh level_shots SCALE=1 -- tools/levelgen/arenas/fondo.json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

EMPTY, BORDER, DROP, FINISH = 0, 4, 10, 11
MUD, JGRASS, TEMPLE, JPLAT = 40, 41, 42, 43
W, H = 40, 14
FLOOR = 11                                     # fila del suelo de delante


def build():
    t = [[EMPTY] * W for _ in range(H)]
    bg = [[EMPTY] * W for _ in range(H)]

    def put(g, c, r, v): g[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(t, c, 1, BORDER); put(t, c, H, BORDER)
    for r in range(1, H + 1): put(t, 1, r, BORDER); put(t, W, r, BORDER)
    # delante: suelo con un escalón, un bloque suelto y plataformas
    for c in range(2, W):
        top = FLOOR - (1 if 14 <= c <= 19 else 0)
        put(t, c, top, JGRASS)
        for r in range(top + 1, H): put(t, c, r, MUD)
    for c in (24, 25): put(t, c, 8, TEMPLE)
    for c in range(29, 33): put(t, c, 7, JPLAT)
    for c in range(6, 10): put(t, c, 7, JPLAT)
    # DETRÁS: un muro del templo con almenas, una arcada y columnas
    for c in range(4, 13):
        for r in range(5, FLOOR):
            if not (7 <= c <= 9 and r >= 8): put(bg, c, r, TEMPLE)     # (el hueco del arco)
    for c in (4, 6, 8, 10, 12): put(bg, c, 4, TEMPLE)
    for c in (21, 27, 34):
        for r in range(6 if c != 27 else 4, FLOOR): put(bg, c, r, TEMPLE)
    for c in range(20, 36): put(bg, c, 5, TEMPLE)
    for c in range(14, 20):
        for r in range(8, FLOOR - 1): put(bg, c, r, MUD)
        put(bg, c, 7, JGRASS)
    put(t, 38, FLOOR - 1, FINISH); put(t, 38, FLOOR - 2, FINISH)
    fol = [
        {'type': 'ceiba', 'col': 17, 'row': 6},                                   # (árbol grande: siempre al fondo)
        {'type': 'broken_pillar', 'col': 30, 'row': 10, 'plane': 'bg'},
        {'type': 'stone_idol', 'col': 23, 'row': 10, 'plane': 'bg'},
        {'type': 'liana_long', 'col': 26, 'row': 6, 'sub': 1, 'plane': 'bg'},
        {'type': 'hanging_moss', 'col': 10, 'row': 6, 'plane': 'bg'},
        {'type': 'jungle_fern', 'col': 33, 'row': 10, 'plane': 'bg'},
        # delante, para comparar
        {'type': 'heliconia', 'col': 3, 'row': 10},
        {'type': 'stone_brazier', 'col': 12, 'row': 10},
        {'type': 'jungle_fern', 'col': 36, 'row': 10},
    ]
    return {
        'name': 'Prueba: plano de fondo', 'name_en': 'Test: background plane',
        'width': W, 'height': H, 'playerStart': [3, FLOOR - 1],
        'tiles': t, 'bgTiles': bg, 'entities': [], 'foliage': fol, 'vents': [],
        'background': 'jungle', 'time': 'day',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'fondo.json')
    write(build(), out)
    print('escrito', out)
