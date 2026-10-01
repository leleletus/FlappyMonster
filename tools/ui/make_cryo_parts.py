#!/usr/bin/env python3
# tools/ui/make_cryo_parts.py
# El CONGELADOR por piezas (el juego las monta según dónde está apoyado, ver
# src/world/entities/types/cryo.lua). Todas en un lienzo de 16x16 = la casilla, con el
# cuerpo centrado y 3 px libres a cada lado, para poder girar las piezas sobre el centro:
#   cryo_body-Sheet.png    4 cuadros: el depósito SIEMPRE derecho (reposo, carga 1, carga 2,
#                          disparo: el indicador se llena y brilla)
#   cryo_feet.png          la base (franja de aviso) y las patas, dibujadas mirando ABAJO;
#                          se giran hacia la superficie que lo sostiene (sin ella: no se dibujan)
#   cryo_cannon-Sheet.png  4 cuadros: el cañón dibujado hacia la DERECHA (reposo, escarcha,
#                          más escarcha, disparo con la boca abierta); se gira hacia donde dispara
#   cryo-Sheet.png         el montaje de siempre (patas abajo, cañón a la derecha): el icono
#                          del editor
# Mismos colores que tools/ui/make_cryo_sprites.py. Desde la raíz del repo:
#     python3 tools/ui/make_cryo_parts.py
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_cryo_sprites import PAL, grid, sheet  # noqa: E402

D = 'assets/images/cryo/'
CLEAR = (0, 0, 0, 0)

# Depósito 10x10 (columnas 3-12, filas 3-12 de la casilla)
BODY = [
    "OOOOOOOOOO",
    "OFFfFFfFFO",
    "OLMMMMMMDO",
    "OLMOOOOMDO",
    "OLMOggOMDO",
    "OLMOggOMDO",
    "OLMOccOMDO",
    "OLMOOOOMDO",
    "OLMMMMMMDO",
    "OOOOOOOOOO",
]


def place(rows, x, y):
    im = Image.new('RGBA', (16, 16), CLEAR)
    im.paste(grid(rows), (x, y))
    return im


def body(kind):
    rows = [list(r) for r in BODY]
    if kind in ('w1', 'w2', 'fire'):                     # el indicador se llena
        for y in (4, 5): rows[y][4] = rows[y][5] = 'c'
        for y in (6,): rows[y][4] = rows[y][5] = 'C'
    if kind in ('w2', 'fire'):                           # y brilla
        rows[4][4] = rows[4][5] = 'C'
        rows[5][4] = rows[5][5] = 'W'
    return place([''.join(r) for r in rows], 3, 3)


def feet():
    # base con franja de aviso pegada al depósito (fila 13), y patas (fila 15)
    im = Image.new('RGBA', (16, 16), CLEAR)
    im.paste(grid([
        "OykykykykO",
        "OOOOOOOOOO",
    ]), (3, 13))
    im.paste(grid(["OOO"]), (2, 15))
    im.paste(grid(["OOO"]), (11, 15))
    return im


# Cañón hacia la derecha: columnas 12-15 (la 12 pisa el borde del depósito = la junta),
# filas 6-9 (centrado en la casilla)
CANNON = {
    'idle': ["OOO.", "MnnO", "MnnO", "OOO."],
    'w1':   ["OOf.", "MnnO", "MnnO", "OOf."],
    'w2':   ["OOF.", "MnnO", "MnnO", "OOF."],
    'fire': ["OOOO", "MWWW", "MWWW", "OOOO"],
}


def cannon(kind):
    im = place(CANNON[kind], 12, 6)
    if kind == 'w2':                                     # más escarcha alrededor de la boca
        im.putpixel((13, 5), PAL['f'])
        im.putpixel((13, 10), PAL['f'])
    return im


def assembled(kind):
    im = body(kind)
    for part in (feet(), cannon(kind)):
        im.alpha_composite(part)
    return im


if __name__ == '__main__':
    kinds = ['idle', 'w1', 'w2', 'fire']
    out = {
        'cryo_body-Sheet.png': sheet([body(k) for k in kinds]),
        'cryo_feet.png': feet(),
        'cryo_cannon-Sheet.png': sheet([cannon(k) for k in kinds]),
        'cryo-Sheet.png': sheet([assembled(k) for k in kinds]),
    }
    for name, im in out.items():
        im.save(D + name)
        print('  %-40s %dx%d' % (D + name, im.width, im.height))
