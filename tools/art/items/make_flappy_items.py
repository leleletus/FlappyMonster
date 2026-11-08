#!/usr/bin/env python3
# tools/art/items/make_flappy_items.py
# Los OBJETOS de los niveles Flappy (docs/design/flappy-plan-4-attack-and-cages.md), dibujados como mapas de caracteres
# a tamaño de arte (16 px de lado, se dibujan ×4). Sin alas en nada (golden rule 6).
#   assets/images/items/flapcharge.png       la CARGA DE ALETEO: un remolino de magia de aleteo
#   assets/images/fx/flapburst-Sheet.png     la RÁFAGA del ataque especial: una media luna de magia que avanza (4 cuadros)
#   /usr/bin/python3 tools/art/items/make_flappy_items.py
#   (nada de esto está retocado a mano: se puede volver a generar)
import os
from PIL import Image

PAL = {
    '.': (0, 0, 0, 0),
    'o': (20, 26, 60, 255),        # contorno
    'b': (60, 110, 210, 255),      # azul
    'c': (110, 210, 255, 255),     # celeste
    'w': (240, 252, 255, 255),     # brillo
    'y': (255, 220, 90, 255),      # chispa dorada
}

CHARGE = [
    '................',
    '.....oooooo.....',
    '...oobbbbbboo...',
    '..obbccccccbbo..',
    '..obcccwwcccbo..',
    '.obccwwccccccbo.',
    '.obcwcc.ooccccbo',
    '.obcwc.ob..ccbo.',
    '.obcwc.oy..cwbo.',
    '.obccc..oowwcbo.',
    '.obbccc....ccbo.',
    '..obbcccwwccbo..',
    '..oobbccccbboo..',
    '....oobbbboo....',
    '......oooo......',
    '................',
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

# La ráfaga: una media luna que mira a la derecha, con su estela; los 4 cuadros cambian el brillo y la estela
BURST = [
    [
        '................',
        '.......oooo.....',
        '........occo....',
        '.........ocwo...',
        '..........ocwo..',
        '..b...b...ocwwo.',
        '...........cwwo.',
        '.b.c..c....cwwo.',
        '.b.c..c....cwwo.',
        '...........cwwo.',
        '..b...b...ocwwo.',
        '..........ocwo..',
        '.........ocwo...',
        '........occo....',
        '.......oooo.....',
        '................',
    ],
]
def shift_trail(rows, k):
    # (la estela son las 7 primeras columnas: se desplazan k a la derecha, dando la vuelta; la media luna no se mueve)
    return [(r[:7][-k:] + r[:7][:-k] if k else r[:7]) + r[7:] for r in rows]
frames = [BURST[0], shift_trail(BURST[0], 1), shift_trail(BURST[0], 2), shift_trail(BURST[0], 3)]
sheet = [''.join(f[y] for f in frames) for y in range(16)]
save(sheet, 'assets/images/fx/flapburst-Sheet.png')
