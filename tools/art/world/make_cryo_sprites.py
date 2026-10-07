#!/usr/bin/env python3
# tools/art/world/make_cryo_sprites.py
# Arte del CONGELADOR (lanzador de nitrógeno líquido) y del bloque de hielo que
# encierra a lo que congela (jugador, enemigos, jefes). Pixel art sencillo, x4:
#   assets/images/traps/cryo/cryo-Sheet.png     (ahora lo genera make_cryo_parts.py, por piezas) 4 cuadros 16x16 mirando a la DERECHA:
#                                         reposo, carga 1, carga 2 (el indicador brilla,
#                                         escarcha en la boquilla), disparo (boquilla abierta,
#                                         retroceso)
#   assets/images/traps/cryo/stream-Sheet.png   chorro: 3 cuadros 16x10 que se repiten a lo
#                                         largo (el dibujo avanza 4 px por cuadro)
#   assets/images/traps/cryo/stream_head-Sheet.png  la punta del chorro: 2 cuadros 12x14 (nube)
#   assets/images/fx/ice_block.png        bloque de hielo 16x16 de 9 trozos (esquinas de
#                                         4 px): se estira al tamaño de lo congelado
# No pisa lo que ya existe (--force). Desde la raíz del repo:
#     python3 tools/art/world/make_cryo_sprites.py [--force]
import os, sys
from PIL import Image

FORCE = '--force' in sys.argv
A = 'assets/images/'


def rgb(h, a=255): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


PAL = {
    'O': rgb('1e1e2a'), 'M': rgb('5a6a88'), 'L': rgb('8fa0bc'), 'D': rgb('3c4860'),
    'F': rgb('e8f4ff'), 'f': rgb('b8d8f4'),                  # escarcha
    'g': rgb('1a2a3a'), 'c': rgb('4fc8e8'), 'C': rgb('9cf0ff'), 'W': rgb('ffffff'),   # indicador
    'n': rgb('2a3448'),                                       # boca de la boquilla
    'y': rgb('f0c040'), 'k': rgb('262630'),                   # franja de aviso
}


def grid(rows, pal=PAL):
    w = len(rows[0])
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        assert len(r) == w, r
        for x, ch in enumerate(r):
            if ch in pal: im.putpixel((x, y), pal[ch])
    return im


BODY = [
    "................",
    "................",
    "...OOOOOOOO.....",
    "..OFFfFFfFFO....",
    "..OLMMMMMMDO....",
    "..OLMOOOOMDO....",
    "..OLMOggOMDOOO..",
    "..OLMOggOMDOnnO.",
    "..OLMOccOMDMnnO.",
    "..OLMOccOMDOOO..",
    "..OLMOOOOMDO....",
    "..OLMMMMMMDO....",
    "..OLMMMMMMDO....",
    "..OykykykykO....",
    "..OOOOOOOOOO....",
    ".OOO......OOO...",
]


def frame(kind):
    rows = [list(r) for r in BODY]
    if kind in ('w1', 'w2', 'fire'):
        # el indicador se llena y brilla
        for y, x in ((6, 6), (6, 7), (7, 6), (7, 7)): rows[y][x] = 'c'
        for y, x in ((8, 6), (8, 7), (9, 6), (9, 7)): rows[y][x] = 'C'
    if kind in ('w2', 'fire'):
        for y, x in ((6, 6), (6, 7)): rows[y][x] = 'C'
        for y, x in ((7, 6), (7, 7)): rows[y][x] = 'W'
    if kind == 'w1':
        rows[6][14] = 'f'; rows[9][14] = 'f'                    # escarcha en la boquilla
    if kind == 'w2':
        rows[6][14] = 'F'; rows[9][14] = 'F'; rows[5][13] = 'f'; rows[10][13] = 'f'
    if kind == 'fire':
        # boquilla abierta: boca clara y más grande
        rows[6] = list("..OLMOCCOMDOOOO.")
        rows[7] = list("..OLMOWWOMDOWWWO")
        rows[8] = list("..OLMOCCOMDMWWWO")
        rows[9] = list("..OLMOCCOMDOOOO.")
    im = grid([''.join(r) for r in rows])
    if kind == 'fire':                                        # retroceso: 1 px hacia atrás
        out = Image.new('RGBA', im.size, (0, 0, 0, 0)); out.paste(im, (-1, 0)); im = out
    if kind == 'w2':                                          # carga: se agacha un píxel
        out = Image.new('RGBA', im.size, (0, 0, 0, 0)); out.paste(im.crop((0, 0, 16, 15)), (0, 1)); im = out
    return im


def sheet(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames): out.paste(f, (i * w, 0))
    return out


def stream(i):
    """Chorro de 16x10: centro blanco, azul claro alrededor y bruma tramada en los
    bordes. El dibujo se repite cada 16 px y avanza 4 px por cuadro."""
    im = Image.new('RGBA', (16, 10), (0, 0, 0, 0))
    for x in range(16):
        xx = (x - i * 4) % 16
        wob = (1 if xx in (3, 4, 11, 12) else 0)
        for y in range(10):
            d = abs(y - 4.5)
            if d < 1 + wob * 0.5: c = rgb('ffffff')
            elif d < 2.5: c = rgb('c8f0ff')
            elif d < 3.5: c = rgb('7ad0f0', 200) if (x + y + i) % 2 == 0 else rgb('c8f0ff', 140)
            elif d < 4.6 and (xx * 3 + y) % 5 == 0: c = rgb('e8f8ff', 150)
            else: continue
            im.putpixel((x, y), c)
    return im


def head(i):
    im = Image.new('RGBA', (12, 14), (0, 0, 0, 0))
    blobs = [((4, 7), 4.0), ((8, 5), 3.0 + i * 0.5), ((8, 9), 3.0 - i * 0.3), ((10, 7), 2.0)]
    for y in range(14):
        for x in range(12):
            inside = [r for (bx, by), r in blobs if (x - bx) ** 2 + (y - by) ** 2 <= r * r]
            if inside:
                edge = all((x - bx) ** 2 + (y - by) ** 2 > (r - 1.2) ** 2 for (bx, by), r in blobs
                           if (x - bx) ** 2 + (y - by) ** 2 <= r * r)
                im.putpixel((x, y), rgb('9cdcf4', 210) if edge else rgb('f0faff', 235))
    return im


def ice_block():
    """Bloque de hielo de 9 trozos (16x16, esquinas de 4 px): contorno azul oscuro,
    relleno azul claro semitransparente, brillo en diagonal arriba a la izquierda."""
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            edge = x in (0, 15) or y in (0, 15)
            if edge: c = rgb('3c6cb4', 255)
            elif x in (1, 14) or y in (1, 14): c = rgb('b4dcff', 210)
            else: c = rgb('a0d0ff', 120)
            im.putpixel((x, y), c)
    for k in range(3):                                    # brillos (en las esquinas: no se estiran)
        im.putpixel((2 + k, 3 - k + 1), rgb('ffffff', 230))
    im.putpixel((2, 2), rgb('ffffff', 230)); im.putpixel((13, 12), rgb('ffffff', 180)); im.putpixel((12, 13), rgb('ffffff', 180))
    return im


def save(rel, img, scale=1):
    path = A + rel
    if os.path.exists(path) and not FORCE:
        print('  ' + path + ' ya existe: no se toca (--force)')
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if scale != 1: img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(path)
    print('  %-42s %dx%d' % (path, img.width, img.height))


if __name__ == '__main__':
    print('Congelador:')
    # (cryo-Sheet.png y las piezas del Congelador: tools/art/world/make_cryo_parts.py)
    save('traps/cryo/stream-Sheet.png', sheet([stream(i) for i in range(3)]))
    save('traps/cryo/stream_head-Sheet.png', sheet([head(i) for i in range(2)]))
    save('fx/ice_block.png', ice_block())
