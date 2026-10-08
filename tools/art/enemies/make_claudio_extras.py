#!/usr/bin/env python3
# tools/art/enemies/make_claudio_extras.py — el PARPADEO de Claudio (assets/images/enemies/claudio/claudio_blink.png).
# Claudio lo dibujó el usuario (sus imágenes NO se tocan); este cuadro sale de claudio_idle.png cerrándole los ojos:
# de cada ojo (2 px negros en vertical) queda solo el de abajo; el de arriba toma el color del cuerpo de su lado.
# Desde la raíz del repo:  python3 tools/art/enemies/make_claudio_extras.py
from PIL import Image

D = 'assets/images/enemies/claudio/'
im = Image.open(D + 'claudio_idle.png').convert('RGBA')
px, n = im.load(), 0
for y in range(im.height - 1):
    for x in range(im.width):
        black = lambda p: p[3] > 0 and p[:3] == (0, 0, 0)
        if black(px[x, y]) and black(px[x, y + 1]) and not (y > 0 and black(px[x, y - 1])):
            px[x, y] = px[x - 1, y]; n += 1
im.save(D + 'claudio_blink.png')
print('  %sclaudio_blink.png  (%d ojos cerrados)' % (D, n))
