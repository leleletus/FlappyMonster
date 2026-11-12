#!/usr/bin/env python3
# tools/art/ui/make_cb_symbols.py — los SÍMBOLOS para daltónicos de los bloques y activadores ON / OFF (0.5.208,
# ACCESIBILIDAD: Opciones → SÍMBOLOS PARA DALTÓNICOS; docs/design/accessibility.md): hasta ahora solo los distinguía el
# color (azul / rojo). Escribe en assets/images/world/tiles/: cb_on.png (un AROS blanco) y cb_off.png (una X blanca),
# 16×16 con borde negro de 1 px; se dibujan encima del tile (TileTypes.drawTile, campo `cbSymbol`). No se retocan a mano.
#   python3 tools/art/ui/make_cb_symbols.py
import os, struct, zlib

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'world', 'tiles')
N = 16
CLEAR, WHITE, BLACK = (0, 0, 0, 0), (255, 255, 255, 255), (12, 12, 20, 255)


def write(name, on):
    rows = [[CLEAR] * N for _ in range(N)]
    for y in range(N):
        for x in range(N):
            if on(x, y): rows[y][x] = WHITE
    # borde negro alrededor de lo blanco
    out = [r[:] for r in rows]
    for y in range(N):
        for x in range(N):
            if rows[y][x] == CLEAR:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < N and 0 <= yy < N and rows[yy][xx] == WHITE:
                        out[y][x] = BLACK
                        break
    raw = b''.join(b'\x00' + b''.join(bytes(p) for p in r) for r in out)
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', N, N, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    open(os.path.join(OUT, name), 'wb').write(png)
    print('escrito', name)


c = (N - 1) / 2
# ON: un aro (radio 4,5 a 6,5)
write('cb_on.png', lambda x, y: 4.2 <= ((x - c) ** 2 + (y - c) ** 2) ** 0.5 <= 6.2)
# OFF: una X de 2 px de grueso
write('cb_off.png', lambda x, y: 2 <= x <= 13 and 2 <= y <= 13 and (abs(x - y) <= 1 or abs(x + y - (N - 1)) <= 1))
