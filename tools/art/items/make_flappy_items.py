#!/usr/bin/env python3
# tools/art/items/make_flappy_items.py
# Los OBJETOS de los niveles Flappy (docs/design/flappy-plan-4-attack-and-cages.md), dibujados como mapas de caracteres
# a tamaño de arte (16 px de lado, se dibujan ×4). Sin alas en nada (golden rule 6).
#   assets/images/items/flapcharge.png       la CARGA DE ALETEO: un remolino de magia de aleteo
#   assets/images/fx/flapburst-Sheet.png     la RÁFAGA del ataque especial: una media luna de magia que avanza (4 cuadros)
#   assets/images/items/cage-Sheet.png       el FLAPPY ENJAULADO: jaula cerrada con un flappy dentro · jaula abierta · el
#                                            flappy libre (de otro color que el monstruo: rosa, con cuernitos; SIN alas)
#   assets/images/world/flappy/crackwall.png el MURO AGRIETADO: un bloque de piedra del Valle con grietas (se repite)
#   /usr/bin/python3 tools/art/items/make_flappy_items.py
#   (nada de esto está retocado a mano: se puede volver a generar)
import os
from PIL import Image

PAL = {
    '.': (0, 0, 0, 0),
    'o': (28, 46, 110, 255),       # contorno (el azul más oscuro del propio objeto)
    'b': (60, 110, 210, 255),      # azul
    'c': (110, 210, 255, 255),     # celeste
    'w': (240, 252, 255, 255),     # brillo
    'y': (255, 220, 90, 255),      # chispa dorada
    'g': (150, 150, 165, 255),     # barrotes
    'G': (200, 200, 215, 255),     # brillo de los barrotes
    'd': (70, 70, 85, 255),        # sombra de los barrotes
    'p': (240, 120, 170, 255),     # flappy enjaulado (rosa)
    'P': (255, 190, 215, 255),     # su brillo
    'k': (30, 16, 26, 255),        # sus ojos
    's': (150, 135, 120, 255),     # piedra
    'S': (185, 170, 150, 255),     # su brillo
    'r': (100, 88, 78, 255),       # su sombra
    'x': (40, 32, 30, 255),        # grieta
}

# (DENSIDAD: la de la manzana del usuario — unos 8 píxeles de arte de ancho en un lienzo de 16, dibujada ×4 —;
#  docs/art/style-rules.md "One pixel density"; el usuario, 2026-11-08: los primeros tenían demasiada resolución)
CHARGE = [
    '................', '................', '................', '................',
    '......oooo......',
    '.....owccbo.....',
    '....owccccbo....',
    '....occbycbo....',
    '....ocbccbbo....',
    '....obccccbo....',
    '.....obbbbo.....',
    '......oooo......',
    '................', '................', '................', '................',
]

def save(rows, path):
    h, w = len(rows), len(rows[0])
    assert all(len(r) == w for r in rows), path
    im = Image.new('RGBA', (w, h))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            im.putpixel((x, y), PAL[ch])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print('escrito', path)


save(CHARGE, 'assets/images/items/flapcharge.png')

# La ráfaga: una media luna que mira a la derecha con su estela (12x12, se dibuja ×4); los 4 cuadros mueven la estela
BURST = [
    [
        '............',
        '......oo....',
        '.......oco..',
        '........owo.',
        '..b.....owo.',
        '.c.c....owo.',
        '..b.....owo.',
        '........owo.',
        '.......oco..',
        '......oo....',
        '............',
        '............',
    ],
]
def shift_trail(rows, k):
    # (la estela son las 5 primeras columnas: se desplazan k a la derecha, dando la vuelta; la media luna no se mueve)
    return [(r[:5][-k:] + r[:5][:-k] if k else r[:5]) + r[5:] for r in rows]
frames = [BURST[0], shift_trail(BURST[0], 1), shift_trail(BURST[0], 2), shift_trail(BURST[0], 3)]
sheet = [''.join(f[y] for f in frames) for y in range(12)]
save(sheet, 'assets/images/fx/flapburst-Sheet.png')

# El flappy enjaulado: jaula de barrotes con cúpula y un flappy rosa dentro · la misma abierta (puerta a un lado) · el
# flappy suelto (sale volando por magia hacia arriba)
CAGE_CLOSED = [
    '................', '................', '................',
    '......dddd......',
    '.....dGGGGd.....',
    '....dg.gg.gd....',
    '....dgpppp.d....',
    '....dgpkpkgd....',
    '....dgppppgd....',
    '....dg.gg.gd....',
    '...dGGGGGGGGd...',
    '...dddddddddd...',
    '................', '................', '................', '................',
]
CAGE_OPEN = [
    '................', '................', '................',
    '......dddd......',
    '.....dGGGGd.....',
    '....dg.gg..d....',
    '....dg.gg.......',
    '....dg.gg...d...',
    '....dg.gg...g...',
    '....dg.gg...g...',
    '...dGGGGGGGGd...',
    '...dddddddddd...',
    '................', '................', '................', '................',
]
FREED = [
    '................', '................', '................', '................',
    '.....p..p.......',
    '.....pppp.......',
    '....pPkPkp......',
    '....pPPPPp......',
    '.....pppp.......',
    '.....p..p.......',
    '................', '................', '................', '................', '................', '................',
]
save([CAGE_CLOSED[y] + CAGE_OPEN[y] + FREED[y] for y in range(16)], 'assets/images/items/cage-Sheet.png')

CRACKWALL = [
    'rrrrrrrrrrrrrrrr',
    'rSSSSSSSrSSSSSSr',
    'rSsssssxrsssssrr',
    'rSssssxsrssxsssr',
    'rSsssxssrsxsssrr',
    'rrrrxrrrrrxrrrrr',
    'rSSSxSSSSSxSSSSr',
    'rSssxxsssxssssrr',
    'rSssssxsxsssssrr',
    'rSsssssxssssssrr',
    'rrrrrrrxrrrrrrrr',
    'rSSSSSSxSrSSSSSr',
    'rSssssxssrssssrr',
    'rSsssxsssrssssrr',
    'rSssssssrrssssrr',
    'rrrrrrrrrrrrrrrr',
]
save(CRACKWALL, 'assets/images/world/flappy/crackwall.png')
