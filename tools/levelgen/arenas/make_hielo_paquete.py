#!/usr/bin/env python3
# tools/levelgen/arenas/make_hielo_paquete.py → hielo_paquete.json: escaparate de los TILES HELADOS (2026-10-29):
#   - la nieve y el hielo por capas (TileTypes.drawSkin): una pared de nieve y una de hielo que se ven como UNA masa,
#     nieve sobre tierra y piedra (franja tramada), una veta de hielo dentro de la nieve, mini bloques de nieve y hielo;
#   - el paquete helado (tiles 50-58): muralla de ladrillo helado con ventanas, columnata de columnas de hielo con dintel,
#     sillares de hielo, acantilado de hielo glaciar, iglú de bloques de nieve, roca helada, plataforma helada y repisa
#     de hielo;
#   - DETRÁS (plano de fondo): un castillo de ladrillo helado con ventanas, un glaciar y roca helada.
#   python3 tools/levelgen/arenas/make_hielo_paquete.py
#   tools/tests/run.sh level_shots SCALE=1 -- tools/levelgen/arenas/hielo_paquete.json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

EMPTY, SOLID, BORDER, WATER, FINISH = 0, 1, 4, 9, 11
DIRT, SNOW, ICE = 16, 29, 30
FBRICK, IROCK, IBRICK, GLACIER, SBRICK, PILLAR, WINDOW, FPLAT, LEDGE = 50, 51, 52, 53, 54, 55, 56, 57, 58
W, H = 64, 18
FLOOR = 15                                     # fila del suelo de delante


def build():
    t = [[EMPTY] * W for _ in range(H)]
    bg = [[EMPTY] * W for _ in range(H)]

    def put(g, c, r, v): g[r - 1][c - 1] = enc(v)

    def box(g, c0, r0, c1, r1, v):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1): put(g, c, r, v)

    for c in range(1, W + 1): put(t, c, 1, BORDER); put(t, c, H, BORDER)
    for r in range(1, H + 1): put(t, 1, r, BORDER); put(t, W, r, BORDER)
    # suelo: nieve sobre tierra sobre piedra (con un tramo de roca helada)
    for c in range(2, W):
        put(t, c, FLOOR, SNOW)
        put(t, c, FLOOR + 1, DIRT if not 40 <= c <= 50 else IROCK)
        put(t, c, FLOOR + 2, SOLID if not 40 <= c <= 50 else IROCK)
    # 1) una pared de NIEVE (7x6) con una veta de hielo, sobre un pie de tierra y piedra
    box(t, 3, 7, 9, 12, SNOW)
    for c, r in ((5, 9), (6, 9), (6, 10), (7, 10), (7, 11)): put(t, c, r, ICE)
    box(t, 3, 13, 9, 13, DIRT); box(t, 3, 14, 9, 14, SOLID)
    # 2) una masa de HIELO (5x4) con nieve encima
    box(t, 12, 9, 16, 13, ICE)
    box(t, 12, 8, 16, 8, SNOW)
    put(t, 17, 13, ICE); put(t, 11, 13, ICE)
    # 3) muralla de ladrillo helado con ventana, sobre ella una columnata de hielo con dintel
    box(t, 20, 9, 26, 14, FBRICK)
    put(t, 22, 11, WINDOW); put(t, 24, 11, WINDOW)
    for c in (20, 23, 26): box(t, c, 5, c, 8, PILLAR)
    box(t, 19, 4, 27, 4, FBRICK)
    # 4) sillares de hielo y un acantilado de hielo glaciar
    box(t, 29, 10, 32, 14, IBRICK)
    box(t, 34, 7, 38, 14, GLACIER)
    box(t, 34, 6, 37, 6, SNOW)
    # 5) iglú de bloques de nieve (con la puerta)
    box(t, 41, 12, 46, 14, SBRICK); box(t, 42, 11, 45, 11, SBRICK); box(t, 43, 10, 44, 10, SBRICK)
    put(t, 43, 14, EMPTY); put(t, 44, 14, EMPTY); put(t, 43, 13, EMPTY); put(t, 44, 13, EMPTY)
    # 6) roca helada con nieve y plataformas
    box(t, 49, 8, 53, 14, IROCK); box(t, 49, 7, 52, 7, SNOW)
    for c in range(55, 59): put(t, c, 10, FPLAT)
    for c in range(40, 45): put(t, c, 7, LEDGE)
    for c in range(28, 33): put(t, c, 6, FPLAT)
    for c in (12, 13, 14, 15): put(t, c, 4, LEDGE)
    put(t, 61, FLOOR - 1, FINISH); put(t, 61, FLOOR - 2, FINISH)
    # DETRÁS: un castillo de ladrillo helado con almenas y ventanas, un glaciar y roca helada
    box(bg, 18, 6, 30, FLOOR - 1, FBRICK)
    for c in range(18, 31, 2): put(bg, c, 5, FBRICK)
    for c in (20, 24, 28):
        put(bg, c, 8, WINDOW)
    box(bg, 31, 3, 34, FLOOR - 1, FBRICK)                               # torre
    for c in (31, 34): put(bg, c, 2, FBRICK)
    put(bg, 32, 6, WINDOW); put(bg, 33, 6, WINDOW)
    box(bg, 37, 4, 47, FLOOR - 1, GLACIER); box(bg, 38, 3, 45, 3, GLACIER); box(bg, 37, 3, 37, 3, SNOW)
    box(bg, 38, 2, 44, 2, SNOW)
    box(bg, 52, 5, 60, FLOOR - 1, IROCK); box(bg, 53, 4, 59, 4, SNOW)
    box(bg, 3, 3, 10, 6, ICE); box(bg, 3, 2, 10, 2, SNOW)              # hielo transparente en el fondo, para comparar
    # mini bloques de nieve y hielo (un montoncito y un carámbano grueso)
    subs = [
        {'col': 18, 'row': 14, 'sub': 3, 'kind': 'snow'}, {'col': 18, 'row': 14, 'sub': 4, 'kind': 'snow'},
        {'col': 18, 'row': 14, 'sub': 2, 'kind': 'snow'},
        {'col': 27, 'row': 14, 'sub': 3, 'kind': 'ice'}, {'col': 27, 'row': 14, 'sub': 4, 'kind': 'ice'},
        {'col': 27, 'row': 14, 'sub': 1, 'kind': 'ice'},
        {'col': 10, 'row': 12, 'sub': 1, 'kind': 'snow'}, {'col': 10, 'row': 12, 'sub': 3, 'kind': 'snow'},
        {'col': 10, 'row': 13, 'sub': 1, 'kind': 'frost_brick'}, {'col': 10, 'row': 13, 'sub': 3, 'kind': 'frost_brick'},
    ]
    fol = [
        {'type': 'snowy_fir', 'col': 50, 'row': 2},
        {'type': 'snowy_pine', 'col': 37, 'row': 5},
        {'type': 'icicle', 'col': 13, 'row': 14},
    ]
    return {
        'name': 'Prueba: tiles helados', 'name_en': 'Test: frozen tiles',
        'width': W, 'height': H, 'playerStart': [2, FLOOR - 1],
        'tiles': t, 'bgTiles': bg, 'subtiles': subs, 'entities': [], 'foliage': fol, 'vents': [],
        'background': 'snow', 'time': 'day', 'snow': True, 'spikeSkin': 'ice',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'hielo_paquete.json')
    write(build(), out)
    print('escrito', out)
