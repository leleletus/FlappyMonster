#!/usr/bin/env python3
# tools/art/ui/make_settings_ui.py — el arte de la pantalla de CONFIGURACIÓN rehecha (0.5.197,
# docs/design/settings-menu-rework.md): assets/images/ui/settings/
#   checker.png       32x32: el fondo a cuadros (dos azules apagados, cuadros de 16), se repite y se desliza
#   gear-Sheet.png    20x20 ×2: el engranaje del menú principal (normal · elegido, dorado)
#   switch-Sheet.png  22x11 ×2: el interruptor (apagado: gris, bolita a la izquierda · encendido: verde, a la derecha);
#                     la bolita CENTRADA en vertical (el usuario: en la maqueta quedaba baja)
#   bar-Sheet.png     4x7 ×2: un bloque de la barra de volumen (vacío · lleno)
# Sin PIL. No está retocado a mano: se puede volver a generar.
#   python3 tools/art/ui/make_settings_ui.py
import os, struct, zlib, math

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'ui', 'settings')
MUTE = 0.52
def mute(c):
    g = sum(c) / 3
    return tuple(int(round(v + (g - v) * MUTE * 0.5)) for v in c)
PAL = {'.': (0, 0, 0, 0), 'o': (34, 32, 52, 255), 'W': (236, 236, 244, 255), 'w': (190, 192, 210, 255),
       'k': (74, 74, 106, 255), 'K': (52, 52, 80, 255), 'G': (106, 190, 48, 255), 'g': (70, 140, 40, 255),
       'Y': (255, 214, 96, 255), 'y': (200, 150, 50, 255), 'S': (120, 124, 150, 255), 's': (88, 90, 116, 255)}
PAL['A'] = mute((48, 98, 190)) + (255,)
PAL['B'] = mute((34, 64, 142)) + (255,)

def save(rows, name):
    h, w = len(rows), len(rows[0])
    raw = b''.join(b'\x00' + b''.join(bytes(PAL[ch]) for ch in r) for r in rows)
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    with open(os.path.join(OUT, name), 'wb') as f: f.write(png)
    print('escrito', name, '%dx%d' % (w, h))

def checker():
    return [''.join('A' if ((x // 16) + (y // 16)) % 2 == 0 else 'B' for x in range(32)) for y in range(32)]

def gear(face, shade):
    rows = []
    for y in range(20):
        r = ''
        for x in range(20):
            dx, dy = x - 9.5, y - 9.5
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            tooth = (math.cos(a * 8) > 0.35)
            outer = 9.4 if tooth else 7.4
            if d > outer: r += '.'
            elif d > outer - 1.2: r += 'o'
            elif d < 2.6: r += '.'                     # el agujero
            elif d < 3.8: r += 'o'
            else: r += shade if dx + dy > 4 else face
        rows.append(r)
    return rows

def switch(on):
    W, H = 22, 11
    rows = []
    track, tshade = ('G', 'g') if on else ('k', 'K')
    for y in range(H):
        r = ''
        for x in range(W):
            edge = x in (0, W - 1) or y in (0, H - 1)
            corner = x in (0, W - 1) and y in (0, H - 1)
            if corner: r += '.'
            elif edge: r += 'o'
            else: r += tshade if y >= H - 3 else track
        rows.append(list(r))
    # bolita 9x9, centrada en vertical: filas 1..9 (una fila de borde arriba y otra abajo)
    kx = W - 11 if on else 2
    for j in range(9):
        for i in range(9):
            cx, cy = i - 4, j - 4
            if cx * cx + cy * cy > 18: continue
            rows[1 + j][kx + i] = 'o' if cx * cx + cy * cy > 11 else ('w' if cx + cy > 2 else 'W')
    return [''.join(r) for r in rows]

def bar(full):
    f, s = ('G', 'g') if full else ('S', 's')
    return ['oooo'] + ['o' + f + f + 'o' if y < 4 else 'o' + s + s + 'o' for y in range(5)] + ['oooo']

os.makedirs(OUT, exist_ok=True)
save(checker(), 'checker.png')
g1, g2 = gear('W', 'w'), gear('Y', 'y')
save([g1[y] + g2[y] for y in range(20)], 'gear-Sheet.png')
s1, s2 = switch(False), switch(True)
save([s1[y] + s2[y] for y in range(11)], 'switch-Sheet.png')
b1, b2 = bar(False), bar(True)
save([b1[y] + b2[y] for y in range(7)], 'bar-Sheet.png')
