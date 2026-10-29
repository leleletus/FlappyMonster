#!/usr/bin/env python3
# tools/art/ui/make_prompts.py
# La AYUDA de "coger" (systems/Carry): el botón de ARRIBA según el aparato, encima de lo que se puede cargar.
#   assets/images/ui/prompts/grab-Sheet.png   3 cuadros de 16x16: 1 teclado (tecla con flecha), 2 mando (cruceta con
#                                             el brazo de arriba en amarillo), 3 táctil (la cruceta táctil, arriba)
# La AYUDA de MACHACAR (0.5.97: tragado por una Planta carnívora o congelado; PlayerAdventure.drawMashPrompt): un
# botón cualquiera que se pulsa y se suelta, según el aparato.
#   assets/images/ui/prompts/mash-Sheet.png   6 cuadros de 16x16: 1-2 teclado (tecla suelta / pulsada, amarilla),
#                                             3-4 mando (botón redondo), 5-6 táctil (el botón táctil)
# Misma paleta que los botones táctiles (make_sprites.py). NO pisa el PNG si ya existe (--force para rehacerlo):
# se puede retocar a mano.
#     python3 tools/art/ui/make_prompts.py [--force]
import os, sys
from PIL import Image

K = (12, 12, 16, 255)          # contorno
W = (232, 232, 240, 255)       # cuerpo
L = (255, 255, 255, 255)       # brillo
D = (150, 150, 168, 255)       # sombra
A = (70, 70, 86, 255)          # flecha
Y = (255, 214, 64, 255)        # lo que hay que pulsar
YD = (196, 150, 20, 255)

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'ui', 'prompts', 'grab-Sheet.png')
OUT_MASH = os.path.join(ROOT, 'assets', 'images', 'ui', 'prompts', 'mash-Sheet.png')


def grid(rows, pal):
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal: img.putpixel((x, y), pal[ch])
    return img


PAL = {'k': K, 'w': W, 'l': L, 'd': D, 'a': A, 'y': Y, 'Y': YD}

# 1 · teclado: una tecla con su borde de abajo más oscuro y la flecha hacia arriba
KEY = [
    '................',
    '..kkkkkkkkkkkk..',
    '.kllllllllllllk.',
    '.klwwwwaawwwwwk.',
    '.klwwwaaaawwwwk.',
    '.klwwaaaaaawwwk.',
    '.klwaaaaaaaawwk.',
    '.klwwwwaawwwwwk.',
    '.klwwwwaawwwwwk.',
    '.klwwwwaawwwwwk.',
    '.klwwwwwwwwwwwk.',
    '.kddddddddddddk.',
    '.kddddddddddddk.',
    '..kkkkkkkkkkkk..',
    '................',
    '................',
]
# 2 · mando: la cruceta con el brazo de ARRIBA pulsado (amarillo y la flecha)
PAD = [
    '................',
    '.....kkkkkk.....',
    '.....kyaayk.....',
    '.....kaaaak.....',
    '.....kyaayk.....',
    '.....kYaaYk.....',
    '.kkkkkwwwwkkkkk.',
    '.kwwwwwwwwwwwwk.',
    '.kwdwwwwwwwwdwk.',
    '.kddddwwwwddddk.',
    '.kkkkkwwwwkkkkk.',
    '.....kwddwk.....',
    '.....kddddk.....',
    '.....kkkkkk.....',
    '................',
    '................',
]
# 3 · táctil: un círculo (la cruceta del táctil) con la flecha de arriba encendida
TOUCH = [
    '................',
    '.....kkkkkk.....',
    '...kkwwyywwkk...',
    '..kwwwyyyywwwk..',
    '..kwwyyyyyywwk..',
    '.kwwwwwyywwwwwk.',
    '.kwwwwwyywwwwwk.',
    '.kwdwwwwwwwwdwk.',
    '.kddwwwwwwwwddk.',
    '.kwdwwwwwwwwdwk.',
    '.kwwwwwwwwwwwwk.',
    '..kwwwwddwwwwk..',
    '..kddwddddwddk..',
    '...kkddddddkk...',
    '.....kkkkkk.....',
    '................',
]


# ── MACHACAR: suelto / pulsado ──
# teclado: la tecla vista de frente; pulsada baja 2 px (el borde de abajo casi desaparece) y se pone amarilla
KEY_UP = [
    '................',
    '................',
    '..kkkkkkkkkkkk..',
    '.kllllllllllllk.',
    '.klwwwwwwwwwwwk.',
    '.klwwwwwwwwwwwk.',
    '.klwwwwwwwwwwwk.',
    '.klwwwwwwwwwwwk.',
    '.klwwwwwwwwwwwk.',
    '.klwwwwwwwwwwwk.',
    '.kddddddddddddk.',
    '.kddddddddddddk.',
    '.kddddddddddddk.',
    '..kkkkkkkkkkkk..',
    '................',
    '................',
]
KEY_DOWN = [
    '................',
    '................',
    '................',
    '................',
    '..kkkkkkkkkkkk..',
    '.kyyyyyyyyyyyyk.',
    '.kyYyyyyyyyyyyk.',
    '.kyyyyyyyyyyyyk.',
    '.kyyyyyyyyyyyyk.',
    '.kyyyyyyyyyyyyk.',
    '.kyyyyyyyyyyyyk.',
    '.kYYYYYYYYYYYYk.',
    '.kddddddddddddk.',
    '..kkkkkkkkkkkk..',
    '................',
    '................',
]
# mando: un botón redondo (de los de la derecha) con su sombra; pulsado, amarillo y hundido
PAD_UP = [
    '................',
    '................',
    '.....kkkkkk.....',
    '...kkllllllkk...',
    '..kllwwwwwwllk..',
    '..klwwwwwwwwlk..',
    '.klwwwwwwwwwwwk.',
    '.kwwwwwwwwwwwwk.',
    '.kwwwwwwwwwwwwk.',
    '.kwwwwwwwwwwwwk.',
    '..kwwwwwwwwwwk..',
    '..kddwwwwwwddk..',
    '...kkddddddkk...',
    '.....kkkkkk.....',
    '................',
    '................',
]
PAD_DOWN = [
    '................',
    '................',
    '................',
    '................',
    '.....kkkkkk.....',
    '...kkyyyyyykk...',
    '..kyyyyyyyyyyk..',
    '.kyyyyyyyyyyyyk.',
    '.kyyyyyyyyyyyyk.',
    '.kyyyyyyyyyyyyk.',
    '.kyyyyyyyyyyyyk.',
    '..kYYyyyyyyYYk..',
    '...kkYYYYYYkk...',
    '.....kkkkkk.....',
    '................',
    '................',
]
# táctil: el botón de saltar del táctil (un círculo con un aro); pulsado se ilumina en amarillo
TOUCH_UP = [
    '................',
    '.....kkkkkk.....',
    '...kkwwwwwwkk...',
    '..kwwddddddwwk..',
    '..kwddwwwwddwk..',
    '.kwddwwwwwwddwk.',
    '.kwdwwwwwwwwdwk.',
    '.kwdwwwwwwwwdwk.',
    '.kwdwwwwwwwwdwk.',
    '.kwdwwwwwwwwdwk.',
    '.kwddwwwwwwddwk.',
    '..kwddwwwwddwk..',
    '..kwwddddddwwk..',
    '...kkwwwwwwkk...',
    '.....kkkkkk.....',
    '................',
]
TOUCH_DOWN = [
    '................',
    '.....kkkkkk.....',
    '...kkyyyyyykk...',
    '..kyyYYYYYYyyk..',
    '..kyYYyyyyYYyk..',
    '.kyYYyyyyyyYYyk.',
    '.kyYyyyyyyyyYyk.',
    '.kyYyyyyyyyyYyk.',
    '.kyYyyyyyyyyYyk.',
    '.kyYyyyyyyyyYyk.',
    '.kyYYyyyyyyYYyk.',
    '..kyYYyyyyYYyk..',
    '..kyyYYYYYYyyk..',
    '...kkyyyyyykk...',
    '.....kkkkkk.....',
    '................',
]


def save(out, frames):
    if os.path.exists(out) and '--force' not in sys.argv:
        print('  ya existe (--force para rehacerlo):', out)
        return
    sheet = Image.new('RGBA', (16 * len(frames), 16), (0, 0, 0, 0))
    for i, rows in enumerate(frames):
        sheet.paste(grid(rows, PAL), (i * 16, 0))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print('  ', out)


def main():
    save(OUT, (KEY, PAD, TOUCH))
    save(OUT_MASH, (KEY_UP, KEY_DOWN, PAD_UP, PAD_DOWN, TOUCH_UP, TOUCH_DOWN))


if __name__ == '__main__':
    main()
