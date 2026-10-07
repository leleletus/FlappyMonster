#!/usr/bin/env python3
# tools/ui/make_cryo_chain.py
# Soporte del Congelador cuando no está apoyado en nada (cuelga del techo):
#   assets/images/traps/cryo/chain.png    5x8: un eslabón de frente (anillo) + uno de canto;
#                                   se repite en vertical (el anillo encaja con el canto)
#   assets/images/traps/cryo/anchor.png   9x4: placa atornillada al techo de la que sale la cadena
#   assets/images/traps/cryo/clamp.png    7x3: abrazadera en el Congelador donde engancha la cadena
# Mismos colores que el aparato (tools/ui/make_cryo_sprites.py): contorno azul muy
# oscuro, metal claro con brillo y sombra.
# Desde la raíz del repo:  python3 tools/ui/make_cryo_chain.py
from PIL import Image

D = 'assets/images/traps/cryo/'


def rgb(h): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


PAL = {
    'o': rgb('1e1e2a'),   # contorno
    'h': rgb('e8f4ff'),   # brillo
    'm': rgb('8fa0bc'),   # metal
    's': rgb('5a6a88'),   # sombra
    'd': rgb('3c4860'),   # sombra honda
}


def grid(rows):
    im = Image.new('RGBA', (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in PAL: im.putpixel((x, y), PAL[ch])
    return im


CHAIN = [
    '.ooo.',
    'ohmso',
    'om.so',
    'om.so',
    'omsdo',
    '.ooo.',
    '.ohd.',     # eslabón de canto (barra), entra en el anillo de abajo
    '.omd.',
]

ANCHOR = [
    'ooooooooo',
    'ohmmmmmso',
    'omhmmmhdo',
    'ooooooooo',
]

CLAMP = [
    '.ooooo.',
    'ohmmmso',
    'ooooooo',
]

if __name__ == '__main__':
    for name, rows in (('chain.png', CHAIN), ('anchor.png', ANCHOR), ('clamp.png', CLAMP)):
        im = grid(rows)
        im.save(D + name)
        print('  %-36s %dx%d' % (D + name, im.width, im.height))
