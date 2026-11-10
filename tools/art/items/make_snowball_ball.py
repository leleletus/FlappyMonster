#!/usr/bin/env python3
# tools/art/items/make_snowball_ball.py — la BOLA DE NIEVE QUE SE CARGA (`snowball_ball`, objeto: la deja al morir una
# de cada pocas Bolas de Nieve, assets/enemies/snowball.json `leaves`). Una bola lisa de 10x10 con la paleta de la
# Bola de Nieve (y de la Gran Bola de Nieve, diseño del usuario): contorno azul noche, blanco, dos azules de sombra
# abajo a la derecha y un brillo arriba a la izquierda. Sin cara: es nieve apretada, no el enemigo.
# Sin PIL (escribe el PNG a mano: zlib), para que funcione en cualquier máquina.
#   python3 tools/art/items/make_snowball_ball.py   → assets/images/items/snowball/ball.png
import os, struct, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'items', 'snowball', 'ball.png')

# (la paleta escrita a mano de tools/art/enemies/make_snowball.py, la del jefe)
O = (30, 30, 42, 255)
B = (255, 255, 255, 255)
C = (242, 244, 248, 255)
D = (226, 232, 242, 255)
E = (196, 204, 224, 255)
N = (0, 0, 0, 0)
W = H = 10

# El dibujo, a mano (10x10): # contorno · * brillo · . blanco · - sombra · = sombra honda
ART = [
    "   ####   ",
    "  #**..#  ",
    " #*....-# ",
    "#*......-#",
    "#.......-#",
    "#......--#",
    "#.....--=#",
    " #..--==# ",
    "  #-===#  ",
    "   ####   ",
]
KEY = {'#': O, '*': B, '.': C, '-': D, '=': E, ' ': N}

def pixel(x, y):
    return KEY[ART[y][x]]

def write_png(path, w, h, px):
    raw = b''.join(b'\x00' + b''.join(bytes(px(x, y)) for x in range(w)) for y in range(h))
    def chunk(t, data):
        return struct.pack('>I', len(data)) + t + data + struct.pack('>I', zlib.crc32(t + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(png)

if __name__ == '__main__':
    write_png(OUT, W, H, pixel)
    print('escrito', os.path.relpath(OUT, ROOT))
