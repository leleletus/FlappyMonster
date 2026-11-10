#!/usr/bin/env python3
# tools/art/ui/make_run_button.py — el botón táctil de CORRER (0.5.190): assets/images/ui/touch/run-Sheet.png, 24x24 ×2
# (suelto · pulsado), redondo como el de la linterna y el del ataque especial (tools/art/ui/make_flappy_hud.py: misma
# forma y colores), con una doble flecha » dentro. Sin PIL (escribe el PNG a mano). No está retocado a mano: se puede
# volver a generar.
#   python3 tools/art/ui/make_run_button.py
import os, struct, zlib

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
PAL = {
    '.': (0, 0, 0, 0),
    'o': (34, 32, 52, 255),        # contorno (el de los otros botones)
    'W': (236, 236, 244, 255),     # botón suelto
    'g': (190, 192, 210, 255),     # botón suelto: sombra
    'Y': (255, 214, 96, 255),      # botón pulsado
    'y': (220, 170, 60, 255),      # botón pulsado: sombra
}

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
    # la doble flecha » (12x8), centrada
    arrows = ['oo....oo....',
              '.oo....oo...',
              '..oo....oo..',
              '...oo....oo.',
              '...oo....oo.',
              '..oo....oo..',
              '.oo....oo...',
              'oo....oo....']
    for j, ar in enumerate(arrows):
        row = list(rows[8 + j])
        for i, ch in enumerate(ar):
            if ch != '.': row[7 + i] = ch
        rows[8 + j] = ''.join(row)
    return rows

def save(rows, rel):
    h, w = len(rows), len(rows[0])
    raw = b''.join(b'\x00' + b''.join(bytes(PAL[ch]) for ch in r) for r in rows)
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    path = os.path.join(ROOT, rel)
    with open(path, 'wb') as f: f.write(png)
    print('escrito', rel)

up, down = button('W', 'g'), button('Y', 'y')
save([up[y] + down[y] for y in range(24)], 'assets/images/ui/touch/run-Sheet.png')
