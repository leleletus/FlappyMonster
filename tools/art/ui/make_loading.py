#!/usr/bin/env python3
# tools/art/ui/make_loading.py — la PANTALLA DE CARGA (0.5.201, docs/design/ux-round-2026-11.md): el monstruo corriendo
# COMPLETAMENTE BLANCO (el usuario), sacado de sus cuadros de siempre (monstrito3-5: el aleteo con el que «corre»):
# assets/images/ui/loading/run-Sheet.png (los cuadros en fila). Lee los PNG sin PIL. No se retoca a mano.
#   python3 tools/art/ui/make_loading.py
import os, struct, zlib

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
SRC = ['monstrito3.png', 'monstrito4.png', 'monstrito5.png']

def read(path):
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
    def alpha(x, y):
        r = rows[y]
        if ct == 6: return r[x * 4 + 3]
        if ct == 4: return r[x * 2 + 1]
        if ct == 3:
            ix = r[x]; return trns[ix] if trns and ix < len(trns) else 255
        return 255
    return w, h, alpha

frames = [read(os.path.join(ROOT, 'assets', 'images', 'player', n)) for n in SRC]
W = max(f[0] for f in frames); H = max(f[1] for f in frames)
out = []
for y in range(H):
    row = bytearray()
    for w, h, alpha in frames:
        for x in range(W):
            on = x < w and y < h and alpha(x, y) > 0
            row += bytes((255, 255, 255, 255) if on else (0, 0, 0, 0))
    out.append(bytes(row))
raw = b''.join(b'\x00' + r for r in out)
chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W * len(frames), H, 8, 6, 0, 0, 0)) \
    + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
open(os.path.join(ROOT, 'assets', 'images', 'ui', 'loading', 'run-Sheet.png'), 'wb').write(png)
print('escrito run-Sheet.png', W, 'x', H, '×', len(frames))
