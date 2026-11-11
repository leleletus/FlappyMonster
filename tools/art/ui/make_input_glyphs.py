#!/usr/bin/env python3
# tools/art/ui/make_input_glyphs.py — los ICONOS DE BOTONES de los carteles de ayuda (0.5.195; el usuario: «sprites para
# los botones que indica, para cada aparato»): assets/images/ui/glyphs/<nombre>.png, 11 px de alto, pixel art.
#   teclado: key_space, key_shift, key_f, key_up, key_down, key_left, key_right (una tecla con su letra o flecha)
#   teclado (0.5.196): key_x (el ataque especial) · mando: pad_l, pad_r (los gatillos)
#   mando:   pad_a, pad_b, pad_x, pad_y (botón redondo con la letra) · pad_up, pad_down, pad_left, pad_right (cruceta con
#            ese brazo en amarillo)
# Los elige src/ui/InputGlyphs.lua por el nombre del botón (Input.label). Sin PIL. No está retocado a mano.
#   python3 tools/art/ui/make_input_glyphs.py
import os, struct, zlib

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'ui', 'glyphs')
PAL = {'.': (0, 0, 0, 0), 'o': (34, 32, 52, 255), 'W': (236, 236, 244, 255), 'g': (170, 172, 192, 255),
       'k': (34, 32, 52, 255), 'Y': (255, 214, 96, 255), 'y': (200, 150, 50, 255)}
H = 11
FONT = {   # 3x5
    'A': ['.k.', 'k.k', 'kkk', 'k.k', 'k.k'], 'B': ['kk.', 'k.k', 'kk.', 'k.k', 'kk.'], 'C': ['.kk', 'k..', 'k..', 'k..', '.kk'],
    'E': ['kkk', 'k..', 'kk.', 'k..', 'kkk'], 'F': ['kkk', 'k..', 'kk.', 'k..', 'k..'], 'H': ['k.k', 'k.k', 'kkk', 'k.k', 'k.k'],
    'I': ['kkk', '.k.', '.k.', '.k.', 'kkk'], 'L': ['k..', 'k..', 'k..', 'k..', 'kkk'], 'R': ['kk.', 'k.k', 'kk.', 'k.k', 'k.k'], 'P': ['kk.', 'k.k', 'kk.', 'k..', 'k..'], 'S': ['.kk', 'k..', '.k.', '..k', 'kk.'],
    'T': ['kkk', '.k.', '.k.', '.k.', '.k.'], 'X': ['k.k', 'k.k', '.k.', 'k.k', 'k.k'], 'Y': ['k.k', 'k.k', '.k.', '.k.', '.k.'],
}
ARROW = {'up': ['..k..', '.kkk.', 'kkkkk', '..k..', '..k..'], 'down': ['..k..', '..k..', 'kkkkk', '.kkk.', '..k..'],
         'left': ['..k..', '.kk..', 'kkkkk', '.kk..', '..k..'], 'right': ['..k..', '..kk.', 'kkkkk', '..kk.', '..k..']}

def grid(w): return [['.'] * w for _ in range(H)]
def stamp(g, pic, x, y):
    for j, r in enumerate(pic):
        for i, ch in enumerate(r):
            if ch != '.': g[y + j][x + i] = ch

def keycap(w):
    g = grid(w)
    for y in range(H):
        for x in range(w):
            edge = x in (0, w - 1) or y in (0, H - 1)
            corner = (x in (0, w - 1)) and (y in (0, H - 1))
            if corner: continue
            g[y][x] = 'o' if edge else ('g' if y >= H - 3 else 'W')
    return g

def text_key(txt):
    w = len(txt) * 4 - 1 + 6
    g = keycap(w)
    for i, ch in enumerate(txt): stamp(g, FONT[ch], 3 + i * 4, 2)
    return g

def arrow_key(d):
    g = keycap(11); stamp(g, ARROW[d], 3, 2); return g

def round_btn(ch):
    g = grid(11)
    for y in range(H):
        for x in range(11):
            dx, dy = x - 5, y - 5
            d = (dx * dx + dy * dy) ** 0.5
            if d <= 5.4: g[y][x] = 'o' if d > 4.4 else ('g' if dx + dy > 3 else 'W')
    stamp(g, FONT[ch], 4, 3)
    return g

def shoulder(ch):
    # (gatillo del mando, L / R: una tecla de 13 de ancho con la esquina de arriba de su lado cortada en diagonal)
    w = 13
    g = grid(w)
    for y in range(H):
        for x in range(w):
            cx = x if ch == 'L' else w - 1 - x
            if cx + y < 3 or (x in (0, w - 1) and y == H - 1) or (cx == w - 1 and y == 0): continue
            edge = x in (0, w - 1) or y in (0, H - 1) or cx + y == 3
            g[y][x] = 'o' if edge else ('g' if y >= H - 3 else 'W')
    stamp(g, FONT[ch], 5, 3)
    return g

def dpad(d):
    g = grid(11)
    for y in range(H):
        for x in range(11):
            if (3 <= x <= 7) or (3 <= y <= 7): g[y][x] = 'o' if (x in (3, 7) and not 3 < y < 7 and (y < 3 or y > 7)) or \
                (y in (3, 7) and not 3 < x < 7 and (x < 3 or x > 7)) or x in (0, 10) or y in (0, 10) else 'W'
    arm = {'up': [(x, y) for x in range(4, 7) for y in range(1, 4)], 'down': [(x, y) for x in range(4, 7) for y in range(7, 10)],
           'left': [(x, y) for x in range(1, 4) for y in range(4, 7)], 'right': [(x, y) for x in range(7, 10) for y in range(4, 7)]}[d]
    for x, y in arm: g[y][x] = 'Y'
    g[5][5] = 'g'
    return g

def save(g, name):
    rows = [''.join(r) for r in g]
    h, w = len(rows), len(rows[0])
    raw = b''.join(b'\x00' + b''.join(bytes(PAL[ch]) for ch in r) for r in rows)
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    with open(os.path.join(OUT, name + '.png'), 'wb') as f: f.write(png)
    print('escrito', name, '%dx%d' % (w, h))

os.makedirs(OUT, exist_ok=True)
save(text_key('SPACE'), 'key_space'); save(text_key('SHIFT'), 'key_shift'); save(text_key('F'), 'key_f')
for d in ('up', 'down', 'left', 'right'):
    save(arrow_key(d), 'key_' + d); save(dpad(d), 'pad_' + d)
for c in 'ABXY': save(round_btn(c), 'pad_' + c.lower())
save(text_key('X'), 'key_x')                                   # (0.5.196: el ataque especial, para las jaulas)
for c in 'LR': save(shoulder(c), 'pad_' + c.lower())
