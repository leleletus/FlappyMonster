#!/usr/bin/env python3
# tools/art/ui/make_intro_card.py — el ARTE de la TARJETA DE PRESENTACIÓN del nivel (0.5.202,
# docs/design/level-intro-card.md; src/ui/IntroCard.lua). Escribe en assets/images/ui/intro/:
#   monster-Sheet.png  el monstruo con un BORDE BLANCO de 1 px (el usuario: que se vea sobre el negro), cuadros de 11×18
#                      en fila: 1-3 corriendo (monstrito3-5, su aleteo), 4-5 quieto (monstrito1-2). Sin alas (regla 6).
#   band.png           un trozo de banda de 16×16 en grises (se tiñe con el color de la isla al dibujar): fila de brillo
#                      arriba, cuerpo, dos filas más oscuras abajo; se repite en horizontal
#   band_cap.png       la PUNTA de la banda (4×16, escalonada) para el borde que entra
#   plate.png          la placa del número, 12×12 en blanco con un borde gris de 1 px y esquinas recortadas (9 trozos
#                      de 4 px)
# Lee los PNG sin PIL. No se retoca a mano.
#   python3 tools/art/ui/make_intro_card.py
import os, struct, zlib

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'ui', 'intro')
RUN = ['monstrito3.png', 'monstrito4.png', 'monstrito5.png']
IDLE = ['monstrito1.png', 'monstrito2.png']


def read(path):
    """→ w, h, px(x, y) = (r, g, b, a)"""
    d = open(path, 'rb').read(); i = 8; idat = b''; plte = None; trns = None
    while i < len(d):
        n = struct.unpack('>I', d[i:i + 4])[0]; t = d[i + 4:i + 8]; c = d[i + 8:i + 8 + n]
        if t == b'IHDR': w, h, bd, ct = struct.unpack('>IIBB', c[:10])
        elif t == b'PLTE': plte = c
        elif t == b'tRNS': trns = c
        elif t == b'IDAT': idat += c
        i += 12 + n
    assert bd == 8, 'solo 8 bits'
    bpp = {6: 4, 2: 3, 3: 1, 4: 2, 0: 1}[ct]
    raw = zlib.decompress(idat); st = w * bpp; rows = []; prev = bytearray(st); k = 0
    for _ in range(h):
        f = raw[k]; line = bytearray(raw[k + 1:k + 1 + st]); k += 1 + st
        for x in range(st):
            a = line[x - bpp] if x >= bpp else 0; b = prev[x]; c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line)); prev = line

    def px(x, y):
        r = rows[y]
        if ct == 6: return tuple(r[x * 4:x * 4 + 4])
        if ct == 2: return tuple(r[x * 3:x * 3 + 3]) + (255,)
        if ct == 4: return (r[x * 2], r[x * 2], r[x * 2], r[x * 2 + 1])
        if ct == 0: return (r[x], r[x], r[x], 255)
        ix = r[x]; a = trns[ix] if trns and ix < len(trns) else 255
        return (plte[ix * 3], plte[ix * 3 + 1], plte[ix * 3 + 2], a)
    return w, h, px


def write(name, w, h, pix):
    """pix(x, y) → (r, g, b, a)"""
    raw = b''.join(b'\x00' + b''.join(bytes(pix(x, y)) for x in range(w)) for y in range(h))
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    open(os.path.join(OUT, name), 'wb').write(png)
    print('escrito', name, w, 'x', h)


os.makedirs(OUT, exist_ok=True)
CLEAR = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)

# ── el monstruo con borde blanco ──
frames = [read(os.path.join(ROOT, 'assets', 'images', 'player', n)) for n in RUN + IDLE]
FW = max(f[0] for f in frames) + 2; FH = max(f[1] for f in frames) + 2


def framePix(f, x, y):
    w, h, px = f
    sx, sy = x - 1, y - 1                     # (1 px de margen para el borde)
    inside = lambda a, b: 0 <= a < w and 0 <= b < h and px(a, b)[3] > 0
    if inside(sx, sy): return px(sx, sy)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        if inside(sx + dx, sy + dy): return WHITE
    return CLEAR


write('monster-Sheet.png', FW * len(frames), FH, lambda x, y: framePix(frames[x // FW], x % FW, y))

# ── la banda (grises: se tiñe) ──
def bandPix(x, y):
    if y == 0: return WHITE                          # brillo
    if y >= 14: return (176, 176, 176, 255)          # sombra de dentro
    return (222, 222, 222, 255)


write('band.png', 16, 16, bandPix)


# ── la punta escalonada (4 px: cada 4 filas, un paso menos) ──
def capPix(x, y):
    if x >= 4 - (y // 4): return CLEAR
    return bandPix(x, y)


write('band_cap.png', 4, 16, capPix)


# ── la placa ──
def platePix(x, y):
    corner = (x in (0, 11)) and (y in (0, 11))
    if corner: return CLEAR
    if x in (0, 11) or y in (0, 11): return (150, 150, 156, 255)
    if y == 10: return (214, 214, 222, 255)          # (sombra de abajo dentro)
    return WHITE


write('plate.png', 12, 12, platePix)
