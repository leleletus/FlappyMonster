#!/usr/bin/env python3
# tools/ui/make_terrain.py
# Texturas de los bloques de terreno (arte 16x16 escalado x4 = 64x64, se repiten
# sin costura; los bordes claros los dibuja el juego solo en las caras al aire):
#   assets/images/world/tiles/dirt.png          Tierra
#   assets/images/world/tiles/grass.png         Césped con la cara de arriba al aire
#                                         (capa verde sobre tierra; tapado = dirt.png)
#   assets/images/world/tiles/grass_blades.png  tallitos que asoman encima (3 variantes 16x4)
#   assets/images/world/tiles/sand.png          Arena
#   (piedra, borde y transiciones de la arena: tools/ui/make_world_art.py)
# Antes estos bloques se dibujaban con código. No pisa lo que ya existe
# (--force para rehacerlo). Desde la raíz del repo:
#     python3 tools/ui/make_terrain.py [--force]
import os, sys
from PIL import Image

FORCE = '--force' in sys.argv
T = 'assets/images/world/tiles'


def rgb(h): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def grid(rows, pal):
    im = Image.new('RGBA', (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        assert len(r) == im.width, r
        for x, ch in enumerate(r):
            if pal.get(ch): im.putpixel((x, y), pal[ch])
    return im


def save(img, name, scale=4):
    path = os.path.join(T, name + '.png')
    if os.path.exists(path) and not FORCE:
        print('  ' + path + ' ya existe: no se toca (--force)')
        return
    img.resize((img.width * scale, img.height * scale), Image.NEAREST).save(path)
    print('  ' + path)


DIRT = {'.': rgb('76502e'), 'd': rgb('5a3c22'), 'l': rgb('8c6240')}
DIRT_ROWS = [
    "................",
    "..........l.....",
    "..l.......dd....",
    "..dd............",
    "................",
    "................",
    "......l.........",
    "......dd........",
    "................",
    "..............l.",
    ".............dd.",
    "...l............",
    "...dd...........",
    "...........l....",
    "...........dd...",
    "................",
]

STONE = {'.': rgb('4a4a56'), 'd': rgb('3a3a44'), 'l': rgb('5c5c6a')}
STONE_ROWS = [
    "......d.........",
    ".l....d..l......",
    "......d.........",
    "......d.........",
    "dddd..dd........",
    "...dddd.dd......",
    ".l.......ddddddd",
    ".........d......",
    ".........d.l....",
    ".........d......",
    "dd.......d......",
    ".dddd...dd......",
    "....dddd.dddd...",
    "..l.........dd..",
    ".............d..",
    "......d......d..",
]

GRASS_TOP = [       # (el resto de filas son de tierra)
    "llllllllllllllll",
    "gggggggggggggggg",
    "gggggggggggggggg",
    "ggggggggGggggggg",
    "GggGggGGGgggGGgg",
    "G.dG..G.G...G.Gd",
    "..........l..G..",
]
GRASS = dict(DIRT, g=rgb('4c9e3e'), G=rgb('38782e'))
GRASS['l'] = rgb('78c454')

BLADES = [
    ["................", ".g.......g......", ".g..g....g....g.", ".G..G..g.G..g.G."],
    ["................", "....g........g..", "..g.g...g....g..", "..G.G...G..g.G.g"],
    ["................", "......g.........", ".g....g....g..g.", ".G.g..G.g..G..G."],
]
BL = {'g': rgb('78c454'), 'G': rgb('4c9e3e')}

SAND = {'.': rgb('dcbc7c'), 'd': rgb('c4a05e'), 'l': rgb('eed49c')}
SAND_ROWS = [
    "................",
    "...d.........l..",
    "................",
    "........ll......",
    ".......d..d.....",
    "..l.............",
    "............d...",
    "................",
    ".....d..........",
    "..............l.",
    "..ll............",
    ".d..d......d....",
    "................",
    "........l.......",
    "...........ll...",
    "..l.......d..d..",
]

# Franja de transición (izquierda): cuánto del vecino hay en cada columna, tramado
BLEND = [
    "XXXXXXXXXXXXXXXX",   # columna 0
    "XXX.XXXXX.XXXX.X",   # columna 1
    "X.X..X.X..X.X..X",   # columna 2
    "..X....X....X...",   # columna 3
    "......X.........",   # columna 4
]


def blend(pal_dark, pal_base):
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for x, col in enumerate(BLEND):
        for y, ch in enumerate(col):
            if ch == 'X':
                im.putpixel((x, y), pal_dark if (x + y) % 3 == 0 else pal_base)
    return im


if __name__ == '__main__':
    print('Texturas de terreno:')
    save(grid(DIRT_ROWS, DIRT), 'dirt')
    g = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    g.paste(grid(GRASS_TOP[:6], GRASS), (0, 0))
    g.paste(grid(DIRT_ROWS[6:], DIRT), (0, 6))
    for x, ch in enumerate(GRASS_TOP[6]):          # (alguna gota de verde más abajo)
        if ch == 'G': g.putpixel((x, 6), GRASS['G'])
    save(g, 'grass')
    strip = Image.new('RGBA', (48, 4), (0, 0, 0, 0))
    for i, rows in enumerate(BLADES):
        strip.paste(grid(rows, BL), (i * 16, 0))
    save(strip, 'grass_blades')
    save(grid(SAND_ROWS, SAND), 'sand')
