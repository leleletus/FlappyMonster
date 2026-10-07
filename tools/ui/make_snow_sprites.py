#!/usr/bin/env python3
# tools/ui/make_snow_sprites.py
# Sprites del hielo y la nieve (arte de 16x16 escalado x4, como el resto de
# texturas de tiles):
#   assets/images/world/tiles/snow.png        Nieve (a partir del color del usuario;
#                                       su original, fuera del repo: tools/ui/originals.py)
#   assets/images/world/tiles/ice.png         Hielo (sus burbujas, con brillos y grietas;
#                                       original fuera del repo). Se dibuja semitransparente
#   assets/images/world/tiles/thin_ice_0..3.png  Hielo fino (losa de media casilla):
#                                       normal, dañado, muy dañado, a punto de romperse
#   assets/images/fx/snowflakes.png     copos de nieve, 4 cuadros de 7x7
#   assets/images/fx/ice_drop.png       gota que cae del hielo, 2 cuadros de 3x5
#                                       (gota, salpicadura)
# No pisa lo que ya existe (--force para rehacerlo). Desde la raíz del repo:
#     python3 tools/ui/make_snow_sprites.py [--force]
import os, sys, shutil, random
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import originals   # noqa: E402

FORCE = '--force' in sys.argv
T = 'assets/images/world/tiles'
FX = 'assets/images/fx'


def save(img, path, scale=1):
    if os.path.exists(path) and not FORCE:
        print('  ' + path + ' ya existe: no se toca (--force)')
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(path)
    print('  ' + path, img.size)


def backup(name):
    """El original del usuario se guarda una vez FUERA del repo (originals.py) y el nuevo lo sustituye."""
    _, fresh = originals.keep(os.path.join(T, name + '.png'))
    return fresh or FORCE


def grid(rows, pal):
    h, w = len(rows), len(rows[0])
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal and pal[ch]:
                im.putpixel((x, y), pal[ch])
    return im


# ── Nieve ─────────────────────────────────────────────────────────────────────
def snow():
    rnd = random.Random(3)
    base = (203, 219, 252, 255)        # (color del usuario)
    light = (226, 236, 255, 255)
    shade = (178, 196, 238, 255)
    white = (255, 255, 255, 255)
    im = Image.new('RGBA', (16, 16), base)
    for y in range(16):
        for x in range(16):
            if y < 5: im.putpixel((x, y), light)                  # arriba, más clara
            if y >= 13: im.putpixel((x, y), shade)               # abajo, a la sombra
    # montoncitos suaves (ondas) entre la parte clara y la base
    for x in range(16):
        if (x // 3) % 2 == 0: im.putpixel((x, 5), light)
    # copos compactados: motas de sombra y brillos
    for _ in range(9):
        im.putpixel((rnd.randrange(16), rnd.randrange(6, 13)), shade)
    for x, y in ((3, 1), (11, 2), (7, 8), (14, 10), (1, 11)):
        im.putpixel((x, y), white)
    return im


# ── Hielo ─────────────────────────────────────────────────────────────────────
def ice():
    base = (167, 196, 255, 255)        # (colores del usuario)
    bub = (213, 227, 255, 255)
    deep = (132, 166, 240, 255)
    shine = (240, 247, 255, 255)
    im = Image.new('RGBA', (16, 16), base)
    for y in range(16):
        for x in range(16):
            if y >= 12: im.putpixel((x, y), deep)            # fondo más denso
    # brillos en diagonal (dos franjas)
    for k in range(6):
        for (x0, y0) in ((2, 8), (8, 11)):
            x, y = x0 + k, y0 - k
            if 0 <= x < 16 and 0 <= y < 16: im.putpixel((x, y), shine)
    # burbujas (las del usuario, en píxel grande)
    for x, y in ((12, 3), (3, 12), (13, 12), (6, 4)):
        im.putpixel((x, y), bub)
    # grieta fina
    for x, y in ((10, 6), (11, 7), (11, 8), (12, 9)):
        im.putpixel((x, y), deep)
    return im


# ── Hielo fino (losa de media casilla: filas 0-7 del arte) ───────────────────
def thin_ice(stage):
    base = (178, 208, 255, 255)
    top = (228, 240, 255, 255)
    edge = (120, 156, 230, 255)
    crack = (48, 76, 160, 255)
    white = (250, 253, 255, 255)
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y in range(8):
        for x in range(16):
            c = base
            if y == 0: c = top
            if y == 7: c = edge
            im.putpixel((x, y), c)
    for x in (2, 3, 9, 10):                      # brillo
        im.putpixel((x, 1), white)
    im.putpixel((4, 2), white)
    cracks = []
    if stage >= 1:   # una grieta pequeña
        cracks += [(6, 2), (7, 3), (7, 4), (8, 5)]
    if stage >= 2:   # más grietas, ramificadas
        cracks += [(8, 6), (5, 1), (4, 1), (12, 1), (12, 2), (13, 3), (12, 4), (11, 5), (11, 6), (7, 5), (6, 6)]
    if stage >= 3:   # a punto de romperse: grietas por todas partes y trozos que faltan
        cracks += [(1, 3), (2, 4), (2, 5), (3, 6), (14, 5), (15, 6), (9, 2), (10, 3), (3, 2), (2, 2)]
    for x, y in cracks:
        im.putpixel((x, y), crack)
    for x, y in cracks:                          # canto claro al lado: la grieta se lee sobre cualquier fondo
        if x + 1 < 16 and (x + 1, y) not in cracks and y < 7:
            im.putpixel((x + 1, y), white)
    if stage >= 3:
        for x, y in ((0, 7), (1, 7), (15, 7), (14, 7), (8, 7), (0, 6)):
            im.putpixel((x, y), (0, 0, 0, 0))
        for x in range(16):                      # se oscurece un poco
            for y in range(8):
                p = im.getpixel((x, y))
                if p[3] and p not in (crack,):
                    im.putpixel((x, y), (max(0, p[0] - 18), max(0, p[1] - 14), p[2], 255))
    return im


# ── Copos y gota ──────────────────────────────────────────────────────────────
def flakes():
    W = (255, 255, 255, 255)
    L = (214, 228, 255, 255)
    pal = {'W': W, 'L': L}
    frames = [
        ["       ", "       ", "   W   ", "  WWW  ", "   W   ", "       ", "       "],   # cruz pequeña
        ["       ", "  W W  ", "   L   ", "  W W  ", "       ", "       ", "       "],   # aspa
        ["   W   ", " W L W ", "  LWL  ", "WLWWWLW", "  LWL  ", " W L W ", "   W   "],   # copo grande
        ["       ", "       ", "  WW   ", "  WW   ", "       ", "       ", "       "],   # bolita
    ]
    out = Image.new('RGBA', (7 * 4, 7), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(grid(f, pal), (i * 7, 0))
    return out


def drop():
    D = (200, 225, 255, 255)
    L = (245, 250, 255, 255)
    E = (120, 160, 230, 255)
    pal = {'D': D, 'L': L, 'E': E}
    f1 = [" E ", "EDE", "ELE", "EDE", " E "]
    f2 = ["   ", "   ", "   ", "D D", "EDE"]
    out = Image.new('RGBA', (6, 5), (0, 0, 0, 0))
    out.paste(grid(f1, pal), (0, 0))
    out.paste(grid(f2, pal), (3, 0))
    return out


if __name__ == '__main__':
    print('Sprites de hielo y nieve:')
    if backup('snow'):
        FORCE_SAVE = True
        snow().resize((64, 64), Image.NEAREST).save(os.path.join(T, 'snow.png')); print('  ' + T + '/snow.png (original: ' + originals.path(os.path.join(T, 'snow.png')) + ')')
    if backup('ice'):
        ice().resize((64, 64), Image.NEAREST).save(os.path.join(T, 'ice.png')); print('  ' + T + '/ice.png (original: ' + originals.path(os.path.join(T, 'ice.png')) + ')')
    for st in range(4):
        save(thin_ice(st), os.path.join(T, 'thin_ice_%d.png' % st), 4)
    save(flakes(), os.path.join(FX, 'snowflakes.png'))
    save(drop(), os.path.join(FX, 'ice_drop.png'))
