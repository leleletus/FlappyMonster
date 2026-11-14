#!/usr/bin/env python3
# tools/art/world/make_beep_blocks.py
# Los BLOQUES BEEP de cristal (docs/design/beep-blocks.md): un par ROSA y CIAN que se cambian solos cada 4 s con el
# reloj de compás del nivel (Vía Estelar). Cada color tiene dos imágenes: SÓLIDO (cristal lleno, tallado) e INACTIVO
# (contorno de cristal punteado, se atraviesa). 16x16 dibujado como mapa de caracteres, escalado ×4 (64x64, como los
# Bloques ON/OFF). Dos diseños para elegir:
#   A  «gema»     : cristal tallado, una faceta en rombo en medio y triángulos de luz/sombra alrededor
#   B  «estrella» : cristal liso con una estrella de cuatro puntas grabada en medio (la Vía Estelar)
#   python3 tools/art/world/make_beep_blocks.py            → vista previa en FlappyMonster_pruebas/beep_blocks/
#   python3 tools/art/world/make_beep_blocks.py --apply A  → assets/images/world/tiles/beep_{pink,cyan}{,_x}.png
#   (nada de esto está retocado a mano: se puede volver a generar)
import os, sys
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'world', 'tiles')
PREV = '/home/mtvemo/FlappyMonster_pruebas/beep_blocks'
K = 4

# Paletas: o contorno (el tono más oscuro del propio color), d sombra, m medio, b base, l luz, w brillo
PALS = {
    'pink': {'o': (110, 22, 74), 'd': (178, 44, 118), 'm': (222, 82, 156), 'b': (246, 128, 190),
             'l': (255, 184, 222), 'w': (255, 240, 248)},
    'cyan': {'o': (14, 76, 104), 'd': (24, 136, 170), 'm': (44, 186, 214), 'b': (96, 222, 240),
             'l': (170, 244, 252), 'w': (240, 255, 255)},
}

# ── A: gema tallada ──────────────────────────────────────────────────────────────────────────────────────
GEM = [
    'oooooooooooooooo',
    'owwlllllllllllmo',
    'owlllllllllllmdo',
    'ollwlllllllllmdo',
    'olllwllwllllbbdo',
    'olllllwwwlllbbdo',
    'olllllwlwwlbbbdo',
    'olllllwllwbbbbdo',
    'ommmmmwbbbbmmmdo',
    'ommmmmbbbbmmmmdo',
    'ommmmmmbbmmmmmdo',
    'ommmmmmmmmmmmmdo',
    'ommmmmmmmmmmdmdo',
    'ommmmmmmmmmmmddo',
    'oddddddddddddddo',
    'oooooooooooooooo',
]
# rombo central (la faceta) sobre la base: se dibuja aparte para que quede simétrico
def gem_solid():
    g = [list('o' * 16)] + [list('o' + 'b' * 14 + 'o') for _ in range(14)] + [list('o' * 16)]
    for y in range(1, 15):
        for x in range(1, 15):
            # triángulos: arriba luz, izquierda luz media, derecha base, abajo sombra (partidos por las diagonales)
            u, v = x - 7.5, y - 7.5
            if abs(u) + abs(v) <= 4.5:
                c = 'w' if (u + v) < -1.5 else 'l'            # la faceta del medio, con su brillo arriba-izquierda
            elif v < 0 and abs(u) <= -v:
                c = 'l'
            elif u < 0 and abs(v) < -u:
                c = 'b'
            elif u > 0 and abs(v) < u:
                c = 'm'
            else:
                c = 'd'
            g[y][x] = c
    # bisel: fila/columna de luz arriba-izquierda, de sombra abajo-derecha
    for i in range(1, 15):
        if g[1][i] != 'w': g[1][i] = 'w' if i < 8 else 'l'
        if g[i][1] != 'w': g[i][1] = 'w' if i < 8 else 'l'
        g[14][i] = 'd'; g[i][14] = 'd'
    g[14][1] = 'm'; g[1][14] = 'm'
    # destello en la esquina
    g[2][2] = 'w'; g[3][3] = 'w'
    return [''.join(r) for r in g]

# ── B: cristal con estrella ──────────────────────────────────────────────────────────────────────────────
def star_solid():
    g = [list('o' * 16)] + [list('o' + 'b' * 14 + 'o') for _ in range(14)] + [list('o' * 16)]
    for i in range(1, 15):                                    # bisel: luz arriba-izquierda, sombra abajo-derecha
        g[1][i] = 'l'; g[i][1] = 'l'; g[14][i] = 'd'; g[i][14] = 'd'
        g[13][i] = 'm' if 1 < i < 14 else g[13][i]; g[i][13] = 'm' if 1 < i < 14 else g[i][13]
    g[1][14] = 'm'; g[14][1] = 'm'; g[2][2] = 'w'; g[2][3] = 'w'; g[3][2] = 'w'
    for y in range(2, 13):
        for x in range(2, 13):
            u, v = abs(x - 7.5), abs(y - 7.5)
            if u < 1 and v < 1:
                g[y][x] = 'w'                                 # el corazón de la estrella
            elif (u < 1 and v < 5) or (v < 1 and u < 5):
                g[y][x] = 'w' if (u < 1 and v < 3) or (v < 1 and u < 3) else 'l'   # las cuatro puntas
            elif u < 2 and v < 2:
                g[y][x] = 'l'                                 # el halo pegado al centro
    return [''.join(r) for r in g]


def inactive(solid):
    # contorno punteado: las cuatro esquinas en escuadra (como el Bloque ON inactivo) + un brillo en el medio
    g = [['.'] * 16 for _ in range(16)]
    for i in range(16):
        for (x, y) in ((i, 0), (i, 15), (0, i), (15, i)):
            corner = i <= 4 or i >= 11
            mid = 7 <= i <= 8
            if corner or mid:
                g[y][x] = 'l' if (x == 0 or y == 0) else 'm'
    for i in range(1, 15):          # contorno oscuro por dentro del trazo, para que se lea sobre el cielo
        for (x, y) in ((i, 1), (i, 14), (1, i), (14, i)):
            nb = ((x, 0) if y == 1 else (x, 15) if y == 14 else (0, y) if x == 1 else (15, y))
            if g[nb[1]][nb[0]] != '.':
                g[y][x] = 'o'
    g[7][7] = 'l'; g[8][8] = 'l'; g[7][8] = 'w'; g[8][7] = 'l'      # una chispa en el centro
    return [''.join(r) for r in g]


def render(art, pal):
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(art):
        for x, ch in enumerate(row[:16]):
            if ch != '.':
                im.putpixel((x, y), pal[ch] + (255,))
    return im.resize((16 * K, 16 * K), Image.NEAREST)


DESIGNS = {'A': gem_solid, 'B': star_solid}


def images(design):
    solid = DESIGNS[design]()
    out = {}
    for col, pal in PALS.items():
        out['beep_' + col] = render(solid, pal)
        out['beep_' + col + '_x'] = render(inactive(solid), pal)
    return out


def preview():
    os.makedirs(PREV, exist_ok=True)
    T = 64
    sky_top, sky_bot = (24, 30, 74), (88, 110, 190)
    W, H = T * 22, T * 8
    im = Image.new('RGBA', (W, H))
    for y in range(H):
        k = y / H
        c = tuple(int(a + (b - a) * k) for a, b in zip(sky_top, sky_bot)) + (255,)
        for x in range(W): im.putpixel((x, y), c)
    for d_i, d in enumerate('AB'):
        ims = images(d)
        y0 = T * (1 + d_i * 4)
        x = T // 2
        # los cuatro sueltos
        for n in ('beep_pink', 'beep_pink_x', 'beep_cyan', 'beep_cyan_x'):
            im.alpha_composite(ims[n], (x, y0)); x += T + T // 2
        # un tramo de camino: rosa sólido / cian inactivo, y abajo el cambio
        x += T // 2
        for row, (a, b) in enumerate((('beep_pink', 'beep_cyan_x'), ('beep_pink_x', 'beep_cyan'))):
            for i in range(10):
                n = a if (i // 3) % 2 == 0 else b
                im.alpha_composite(ims[n], (x + i * T, y0 + row * T + (T if row else 0) // 2))
    big = im                                                 # tamaño real del juego (64 px por casilla)
    path = os.path.join(PREV, 'vista_previa.png')
    big.save(path)
    print(path)


if __name__ == '__main__':
    if '--apply' in sys.argv:
        d = sys.argv[sys.argv.index('--apply') + 1]
        for n, img in images(d).items():
            img.save(os.path.join(OUT, n + '.png'))
            print('escrito', n)
    else:
        preview()
