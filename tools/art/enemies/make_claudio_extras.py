#!/usr/bin/env python3
# tools/art/enemies/make_claudio_extras.py — el PARPADEO de Claudio (assets/images/enemies/claudio/claudio_blink.png) y su
# BAILE de los créditos (claudio_dance-Sheet.png, abajo).
# Claudio lo dibujó el usuario (sus imágenes NO se tocan); este cuadro sale de claudio_idle.png cerrándole los ojos:
# de cada ojo (2 px negros en vertical) queda solo el de abajo; el de arriba toma el color del cuerpo de su lado.
# Desde la raíz del repo:  python3 tools/art/enemies/make_claudio_extras.py
# Desde la raíz del repo:  python3 tools/art/enemies/make_claudio_extras.py [parpadeo] [baile]   (sin nada: los dos)
import sys
from PIL import Image

D = 'assets/images/enemies/claudio/'
WHAT = sys.argv[1:] or ['parpadeo', 'baile']
im = Image.open(D + 'claudio_idle.png').convert('RGBA')
px, n = im.load(), 0
for y in range(im.height - 1):
    for x in range(im.width):
        black = lambda p: p[3] > 0 and p[:3] == (0, 0, 0)
        if black(px[x, y]) and black(px[x, y + 1]) and not (y > 0 and black(px[x, y - 1])):
            px[x, y] = px[x - 1, y]; n += 1
if 'parpadeo' in WHAT:
    im.save(D + 'claudio_blink.png')
    print('  %sclaudio_blink.png  (%d ojos cerrados)' % (D, n))

# ── EL BAILE de Claudio (los créditos: src/story/films/credits.lua) ──────────────────────────────────────────────
# claudio_dance-Sheet.png, 3 cuadros de 16x16 sacados de claudio_idle.png SIN tocar su cuerpo: solo se mueven los
# brazos (los 2 px de cada lado, en su fila): 1 los dos brazos ARRIBA · 2 saluda con el derecho · 3 el derecho más
# alto (2 y 3 alternados = el saludo de despedida). Los pasos son los de andar (claudio1 / claudio2, del usuario).
base = Image.open(D + 'claudio_idle.png').convert('RGBA')
bp = base.load()
# (cada brazo: 2x2 px a cada lado, filas 8-9)
LEFT = [(x, y) for x in (1, 2) for y in (8, 9)]
RIGHT = [(x, y) for x in (13, 14) for y in (8, 9)]
col = bp[1, 8]
UP_L = [(2, 7), (2, 6), (1, 6), (1, 5)]                # (en diagonal hacia arriba, pegado al cuerpo)
UP_R = [(13, 7), (13, 6), (14, 6), (14, 5)]
HIGH_R = [(13, 7), (14, 6), (14, 5), (14, 4)]
def frame(left_up, right_pose):
    f = base.copy(); p = f.load()
    for (x, y) in (LEFT if left_up else []) + (RIGHT if right_pose else []): p[x, y] = (0, 0, 0, 0)
    for (x, y) in (UP_L if left_up else []) + {'up': UP_R, 'high': HIGH_R}.get(right_pose, []): p[x, y] = col
    return f
frames = [frame(True, 'up'), frame(False, 'up'), frame(False, 'high')]
sheet = Image.new('RGBA', (16 * len(frames), 16), (0, 0, 0, 0))
for i, f in enumerate(frames): sheet.paste(f, (16 * i, 0))
if 'baile' in WHAT:
    sheet.save(D + 'claudio_dance-Sheet.png')
    print('  %sclaudio_dance-Sheet.png  (%d cuadros: brazos arriba, saludo, saludo alto)' % (D, len(frames)))
