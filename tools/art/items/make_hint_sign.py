#!/usr/bin/env python3
# tools/art/items/make_hint_sign.py — el CARTEL de ayuda (`hint`, 0.5.190: el nivel tutorial): un poste de madera con
# un tablón y un «?» (12x16, a ×4 en el juego), y su versión «leído» (el «?» más apagado) para cuando ya se acercó.
# Paleta de madera de los cajones (assets/images/mechanisms/box: marrones) con el contorno azul noche de todo el juego.
# Sin PIL (escribe el PNG a mano). No está retocado a mano: se puede volver a generar.
#   python3 tools/art/items/make_hint_sign.py  → assets/images/items/hint/sign-Sheet.png (2 cuadros de 12x16)
import os, struct, zlib

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
PAL = {
    '.': (0, 0, 0, 0),
    'o': (34, 32, 52, 255),       # contorno
    'W': (196, 140, 84, 255),     # madera clara
    'w': (156, 104, 58, 255),     # madera
    'd': (110, 72, 40, 255),      # madera: sombra
    'Y': (255, 224, 110, 255),    # el «?»
    'y': (190, 160, 90, 255),     # el «?» ya leído
}
SIGN = [
    'oooooooooooo',
    'oWWWWWWWWWwo',
    'oWWWWQQWWWwo',
    'oWWWQWWQWWwo',
    'oWWWWWWQWWwo',
    'oWWWWWQWWWwo',
    'oWWWWQWWWWwo',
    'owwwwwwwwwdo',
    'owwwwQwwwwdo',
    'oddddddddddo',
    'oooooooooooo',
    '....owdo....',
    '....owdo....',
    '....owdo....',
    '....owdo....',
    '...oooooo...',
]
def frame(q):
    return [r.replace('Q', q) for r in SIGN]

def save(rows, rel):
    h, w = len(rows), len(rows[0])
    raw = b''.join(b'\x00' + b''.join(bytes(PAL[ch]) for ch in r) for r in rows)
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f: f.write(png)
    print('escrito', rel)

a, b = frame('Y'), frame('y')
save([a[i] + b[i] for i in range(16)], 'assets/images/items/hint/sign-Sheet.png')
