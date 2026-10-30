#!/usr/bin/env python3
# tools/art/world/make_secret_exit.py
# La SALIDA SECRETA (tile `secret_exit`, src/world/tiles/types/secret_exit.lua): una placa roja con marco dorado y una
# CERRADURA negra en medio — la misma idea que el nodo rojo con cerradura del mapa (docs/story/world-map.md). 16x16
# dibujado a mano como mapa de caracteres, escalado ×4 (64x64, como la meta). Pocos colores, áreas lisas.
#   python3 tools/art/world/make_secret_exit.py      → assets/images/world/tiles/secret_exit.png
#   (nada de esto está retocado a mano: se puede volver a generar)
import os
from PIL import Image

OUT = 'assets/images/world/tiles/secret_exit.png'
PAL = {
    '.': (0, 0, 0, 0),
    'o': (40, 20, 24, 255),        # contorno
    'g': (236, 184, 64, 255),      # marco dorado
    'G': (255, 230, 140, 255),     # brillo del marco
    'd': (170, 112, 36, 255),      # sombra del marco
    'r': (176, 36, 44, 255),       # placa roja
    'R': (220, 70, 70, 255),       # brillo de la placa
    'k': (24, 10, 14, 255),        # la cerradura
}
ART = [
    'oooooooooooooooo',
    'oGGGGGGGGGGGGGgo',
    'oGRRRRRRRRRRRrdo',
    'oGRrrrrrrrrrrrdo',
    'oGRrrrrkkrrrrrdo',
    'oGRrrrkkkkrrrrdo',
    'oGRrrrkkkkrrrrdo',
    'oGRrrrrkkrrrrrdo',
    'oGRrrrrkkrrrrrdo',
    'oGRrrrkkkkrrrrdo',
    'oGRrrrkkkkrrrrdo',
    'oGRrrrrrrrrrrrdo',
    'oGRrrrrrrrrrrrdo',
    'ogrrrrrrrrrrrrdo',
    'oddddddddddddddo',
    'oooooooooooooooo',
]


def main():
    im = Image.new('RGBA', (16, 16))
    for y, row in enumerate(ART):
        assert len(row) == 16, (y, row)
        for x, ch in enumerate(row):
            im.putpixel((x, y), PAL[ch])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.resize((64, 64), Image.NEAREST).save(OUT)
    print('  ' + OUT)


if __name__ == '__main__':
    main()
