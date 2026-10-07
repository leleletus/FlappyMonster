#!/usr/bin/env python3
# tools/art/story/make_story_fx.py
# Efectos de las cinemáticas de la historia (assets/images/story/fx/):
#   magic-Sheet.png     el ALETEO hecho magia: un orbe que late, 4 cuadros 11x11 (lo que el Reflejo le roba)
#   sparkle-Sheet.png   chispa, 4 cuadros 7x7 (nace, cruz, cruz grande, se apaga)
#   python3 tools/art/story/make_story_fx.py
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'assets', 'images', 'story', 'fx')
PAL = {'.': (0, 0, 0, 0), 'o': (72, 150, 230, 255), 'b': (130, 210, 255, 255), 'c': (200, 240, 255, 255),
       'w': (255, 255, 255, 255), 'y': (255, 240, 150, 255)}
ORB = [
    ['...........', '...ooooo...', '..obbbbbo..', '.obbcccbbo.', '.obccwccbo.', '.obcwwwcbo.', '.obccwccbo.', '.obbcccbbo.', '..obbbbbo..', '...ooooo...', '...........'],
    ['...ooooo...', '..obbbbbo..', '.obcccccbo.', 'obccwwwccbo', 'obcwwwwwcbo', 'obcwwwwwcbo', 'obcwwwwwcbo', 'obccwwwccbo', '.obcccccbo.', '..obbbbbo..', '...ooooo...'],
    ['...........', '...ooooo...', '..obcccbo..', '.obcwwwcbo.', '.ocwwwwwco.', '.ocwwwwwco.', '.ocwwwwwco.', '.obcwwwcbo.', '..obcccbo..', '...ooooo...', '...........'],
    ['...........', '...........', '...ooooo...', '..obbcbbo..', '..obcwcbo..', '..ocwwwco..', '..obcwcbo..', '..obbcbbo..', '...ooooo...', '...........', '...........'],
]
SPK = [
    ['.......', '.......', '.......', '...w...', '.......', '.......', '.......'],
    ['.......', '...y...', '...w...', '.ywwwy.', '...w...', '...y...', '.......'],
    ['...y...', '...w...', '...w...', 'ywwwwwy', '...w...', '...w...', '...y...'],
    ['.......', '.......', '...y...', '..ywy..', '...y...', '.......', '.......'],
]


def strip(frames, name):
    w, h = len(frames[0][0]), len(frames[0])
    im = Image.new('RGBA', (w * len(frames), h))
    for i, f in enumerate(frames):
        for y, row in enumerate(f):
            for x, ch in enumerate(row):
                im.putpixel((i * w + x, y), PAL[ch])
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name))
    print('  story/fx/%s %dx%d (%d cuadros)' % (name, im.width, im.height, len(frames)))


strip(ORB, 'magic-Sheet.png')
strip(SPK, 'sparkle-Sheet.png')
