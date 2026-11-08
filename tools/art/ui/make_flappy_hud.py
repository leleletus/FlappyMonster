#!/usr/bin/env python3
# tools/art/ui/make_flappy_hud.py
# La interfaz de los niveles FLAPPY (docs/design/flappy-plan-4-attack-and-cages.md), mapas de caracteres:
#   assets/images/ui/flappy/hud-Sheet.png     HUD (16x16 cada uno): corazón lleno · corazón vacío · celda de carga llena ·
#                                             celda de carga vacía (src/ui/FlappyHud.lua)
#   assets/images/ui/touch/special-Sheet.png  botón táctil del ATAQUE ESPECIAL (24x24: suelto · pulsado), como el de la
#                                             linterna (redondo, blanco / dorado) con el remolino de la carga dentro
#   /usr/bin/python3 tools/art/ui/make_flappy_hud.py      (nada de esto está retocado a mano: se puede volver a generar)
import os
from PIL import Image

PAL = {
    '.': (0, 0, 0, 0),
    'o': (20, 18, 34, 255),        # contorno
    'R': (255, 110, 110, 255),     # corazón: brillo
    'r': (220, 50, 60, 255),       # corazón
    'd': (140, 26, 40, 255),       # corazón: sombra
    'e': (70, 64, 90, 255),        # vacío
    'E': (110, 104, 130, 255),     # vacío: brillo
    'w': (240, 252, 255, 255),     # blanco
    'c': (110, 210, 255, 255),     # celeste (carga)
    'b': (60, 110, 210, 255),      # azul (carga)
    'W': (236, 236, 244, 255),     # botón suelto
    'g': (190, 192, 210, 255),     # botón suelto: sombra
    'Y': (255, 214, 96, 255),      # botón pulsado
    'y': (220, 170, 60, 255),      # botón pulsado: sombra
}

HEART = ['................', '................', '..oooo....oooo..', '.oRRrro..orrrdo.', '.oRrrrroorrrrdo.',
         '.orrrrrrrrrrrdo.', '.orrrrrrrrrrrdo.', '.orrrrrrrrrrrdo.', '..orrrrrrrrrdo..', '...orrrrrrrdo...',
         '....orrrrrdo....', '.....orrrdo.....', '......ordo......', '.......oo.......', '................', '................']
def recolor(rows, m): return [''.join(m.get(ch, ch) for ch in r) for r in rows]
HEART_EMPTY = recolor(HEART, {'R': 'E', 'r': 'e', 'd': 'e'})
CELL = ['................', '................', '...oooooooooo...', '..obbbbbbbbbbo..', '..obccccccccbo..', '..obcwwcccccbo..',
        '..obcwccccccbo..', '..obccccccccbo..', '..obccccccccbo..', '..obccccccccbo..',
        '..obccccccccbo..', '..obbbbbbbbbbo..', '...oooooooooo...', '................', '................', '................']
CELL_EMPTY = recolor(CELL, {'b': 'e', 'c': 'e', 'w': 'E'})

def button(face, shade):
    rows = []
    for y in range(24):
        r = ''
        for x in range(24):
            dx, dy = x - 11.5, y - 11.5
            d = (dx * dx + dy * dy) ** 0.5
            if d > 11.5: r += '.'
            elif d > 10.3: r += 'o'
            elif dx + dy > 9: r += shade
            else: r += face
        rows.append(r)
    # el remolino de la carga en el centro (8x8)
    swirl = ['..oooo..', '.obbbbo.', 'obccccbo', 'obcwwcbo', 'obcwocbo', 'obcccc.o', '.obbbbo.', '..oooo..']
    for j, sr in enumerate(swirl):
        row = list(rows[8 + j])
        for i, ch in enumerate(sr):
            if ch != '.': row[8 + i] = ch
        rows[8 + j] = ''.join(row)
    return rows

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

save([HEART[y] + HEART_EMPTY[y] + CELL[y] + CELL_EMPTY[y] for y in range(16)], 'assets/images/ui/flappy/hud-Sheet.png')
up, down = button('W', 'g'), button('Y', 'y')
save([up[y] + down[y] for y in range(24)], 'assets/images/ui/touch/special-Sheet.png')
