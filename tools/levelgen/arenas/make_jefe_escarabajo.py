#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_escarabajo.py → jefe_escarabajo.json (arena del ESCARABAJO RINOCERONTE GIGANTE: el
# templo de la balanza; isla de la jungla, aún sin integrar en la historia)
#   python3 tools/levelgen/arenas/make_jefe_escarabajo.py
#
# EL TEMPLO DE LA BALANZA (zona: columnas 12-35, filas 3-12; suelo en la 13; techo bajo, fila 2):
#
#   ║▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒║     techo del templo: ahí se estrella el escarabajo disparado
#   ║            o           ║     o  la polea de la BALANZA (span 12)
#   ║                        ║
#   ║                        ║
#   ║          =====         ║     =  plataformas traspasables: para esquivar la embestida y las ondas (0.5.81: una
#   ║     ___          ___   ║        casilla más bajas)
#   ║===                  ===║     ___ los PLATILLOS: nivelada, colgados 3 casillas sobre el suelo (0.5.79, el usuario:
#   ║                        ║         antes a ras del suelo sobre un foso; sin fosos, cuerda más corta)
#   ║■■■■■■■■■■■■■■■■■■■■■■■■║
#
# Cómo se gana: con él en un platillo, ground pound en el otro → sale disparado, choca con el techo y cae patas arriba.
# Entrada a la izquierda; salida (meta) a la derecha.
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

EMPTY, SOLID, BORDER, DROP, FINISH = 0, 1, 4, 10, 11
TEMPLE = 42                                # sillar del templo (las ruinas del plano de fondo)
W, H = 48, 15
Z0, Z1 = 12, 35
FLOOR = 13
PULLEY = (24, 3)
SPAN = 12                                  # casillas entre los centros de los platillos
DROP_ROPE = 6.375                          # nivelada, el platillo queda 3 casillas sobre el suelo (giantbeetle_rules)
SIDE_ROW, MID_ROW = 11, 9                  # plataformas traspasables: a los lados (a la altura de los platillos) y en medio


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H): put(c, r, SOLID)
        if Z0 - 2 <= c <= Z1 + 2: put(c, 2, SOLID)           # (el techo del templo)
    # RUINAS DEL TEMPLO en el PLANO DE FONDO (0.5.87, el usuario; sin colisión, más oscuras y con la sombra de lo de
    # delante): columnas con su dintel bajo el techo, dos arcos entre ellas y un muro bajo derrumbado
    bg = [[EMPTY] * W for _ in range(H)]

    def put_bg(c, r, v): bg[r - 1][c - 1] = enc(v)

    COLS = (15, 20, 28, 33)
    for c in COLS:
        for r in range(3, FLOOR): put_bg(c, r, TEMPLE)
    for c in range(Z0, Z1 + 1): put_bg(c, 3, TEMPLE)                       # (el dintel, pegado al techo)
    for a, b in ((15, 20), (28, 33)):                                       # (arcos: bajan desde el dintel)
        for c in range(a + 1, b): put_bg(c, 4, TEMPLE)
        put_bg(a + 1, 5, TEMPLE); put_bg(b - 1, 5, TEMPLE)
    for c, h in ((22, 2), (23, 3), (24, 1), (25, 2), (26, 1)):              # (muro bajo derrumbado, detrás del centro)
        for r in range(FLOOR - h, FLOOR): put_bg(c, r, TEMPLE)
    for c in list(range(Z0, Z0 + 3)) + list(range(Z1 - 2, Z1 + 1)): put(c, SIDE_ROW, DROP)
    for c in range(22, 27): put(c, MID_ROW, DROP)
    for r in (10, 11, 12): put(44, r, FINISH)
    ents = [
        {'type': 'giantbeetle', 'col': 24, 'row': 12},
        {'type': 'scale', 'col': PULLEY[0], 'row': PULLEY[1], 'props': {'span': SPAN, 'drop': DROP_ROPE, 'travel': 2, 'power': 1}},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 3, 'props': {'corner': {'col': Z0 - 1, 'row': 12}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': 3, 'props': {'corner': {'col': Z1 + 3, 'row': 12}, 'zone': 1}},
    ]
    return {
        'name': 'Jefe: Escarabajo Rinoceronte Gigante', 'name_en': 'Boss: Giant Rhino Beetle',
        'width': W, 'height': H, 'playerStart': [4, 12],
        'tiles': t, 'bgTiles': bg, 'entities': ents, 'vents': [],
        # ruinas DELANTE (sin estorbar: junto a las paredes y bajo las plataformas de los lados) y DETRÁS (plane 'bg')
        'foliage': [
            {'type': 'stone_brazier', 'col': Z0 + 1, 'row': FLOOR - 1}, {'type': 'stone_brazier', 'col': Z1 - 1, 'row': FLOOR - 1},
            {'type': 'fallen_block', 'col': 21, 'row': FLOOR - 1}, {'type': 'broken_pillar', 'col': 27, 'row': FLOOR - 1},
            {'type': 'stone_idol', 'col': 25, 'row': FLOOR - 3, 'plane': 'bg'},          # (sobre el muro derrumbado)
            {'type': 'liana_long', 'col': 17, 'row': 4, 'sub': 1, 'plane': 'bg'}, {'type': 'liana_mid', 'col': 31, 'row': 4, 'sub': 2, 'plane': 'bg'},
            {'type': 'hanging_moss', 'col': 22, 'row': 4, 'plane': 'bg'}, {'type': 'flower_vine', 'col': 26, 'row': 4, 'plane': 'bg'},
            {'type': 'jungle_fern', 'col': 18, 'row': FLOOR - 1, 'plane': 'bg'}, {'type': 'roots', 'col': 30, 'row': FLOOR - 1, 'plane': 'bg'},
        ],
        'bossZones': [{'id': 1, 'col': Z0, 'row': 3, 'w': Z1 - Z0 + 1, 'h': 10, 'music': 'templo'}],
        'background': 'jungle', 'time': 'day',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'jefe_escarabajo.json')
    write(build(), out)
    print('escrito', out)
