#!/usr/bin/env python3
# tools/art/ui/make_story_icons.py
# Iconos del MAPA del modo historia (assets/images/ui/icons/, se dibujan con src/ui/PixelIcons.lua):
#   lock.png   candado (nivel cerrado)      check.png  marca (nivel superado)
# Mismo estilo que los demás iconos: blanco con contorno oscuro; el color lo pone quien dibuja.
#   python3 tools/art/ui/make_story_icons.py
import os
from PIL import Image

OUT = 'assets/images/ui/icons'
PAL = {'.': (0, 0, 0, 0), 'o': (24, 24, 34, 255), 'w': (255, 255, 255, 255), 'g': (190, 196, 210, 255)}
ICONS = {
    'lock': ['..ooooo..',
             '.owwwwwo.',
             '.owooowo.',
             '.owo.owo.',
             'ooooooooo',
             'owwwwwwwo',
             'owwwowwwo',
             'owwwowwwo',
             'owwwwwwwo',
             'ooooooooo'],
    'check': ['.......oo',
              '......owo',
              '.....owwo',
              'oo..owwo.',
              'owoowwo..',
              'owwwwo...',
              '.owwo....',
              '..oo.....'],
}
for name, rows in ICONS.items():
    im = Image.new('RGBA', (len(rows[0]), len(rows)))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            im.putpixel((x, y), PAL[ch])
    im.save(os.path.join(OUT, name + '.png'))
    print('  %s/%s.png %dx%d' % (OUT, name, im.width, im.height))
