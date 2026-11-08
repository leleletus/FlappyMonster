#!/usr/bin/env python3
# tools/art/world/make_flappy_pillars.py
# Los PILARES de los niveles Flappy (tile `pillar`, src/world/tiles/types/pillar.lua; docs/design/flappy-prequel.md):
# las columnas huecas del Valle de los Pilares, de donde salen las tuberías del Flappy de siempre. Mismos colores que
# assets/images/flappy/pipe.png (azul noche casi negro, brillo a la izquierda), a la densidad de los tiles: 16x16
# dibujado como mapa de caracteres, escalado x4 (64x64).
#   pillar.png      el cuerpo (se repite en vertical)
#   pillar_cap.png  la boca, con la cara al aire ARRIBA (para la cara de abajo se dibuja volteada)
#   /usr/bin/python3 tools/art/world/make_flappy_pillars.py
#   (nada de esto está retocado a mano: se puede volver a generar)
import os
from PIL import Image

PAL = {
    '.': (0, 0, 0, 0),
    'o': (6, 6, 10, 255),          # contorno
    'L': (74, 78, 104, 255),       # luz de la boca
    'H': (50, 52, 74, 255),        # brillo (izquierda)
    'b': (24, 26, 40, 255),        # cuerpo
    's': (12, 12, 20, 255),        # sombra (derecha, debajo de la boca)
}
BODY = '..oHbbbbbbbbso..'
CAP = [
    'oooooooooooooooo',
    'oLLLLLLLLLLLLLLo',
    'oLHHbbbbbbbbbbso',
    'oHbbbbbbbbbbbbso',
    'osssssssssssssso',
    'oooooooooooooooo',
] + ['..oHssssssssso..'] + [BODY] * 9


def save(rows, path):
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), path
    im = Image.new('RGBA', (16, 16))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            im.putpixel((x, y), PAL[ch])
    im = im.resize((64, 64), Image.NEAREST)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print('escrito', path)


save([BODY] * 16, 'assets/images/world/tiles/pillar.png')
save(CAP, 'assets/images/world/tiles/pillar_cap.png')
