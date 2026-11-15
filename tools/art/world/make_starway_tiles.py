#!/usr/bin/env python3
# tools/art/world/make_starway_tiles.py
# EL PAQUETE ESTELAR (Vía Estelar, docs/design/via-estelar-level.md): los bloques temáticos del nivel especial, con piel
# por capas como el paquete helado (TileTypes.drawSkin: cuerpo sin costuras de 2x2 casillas y lo de arriba / abajo solo
# en las caras al aire). Colores claros y fríos (lavanda / plata) para leerse delante del cielo nocturno; NADA rosa ni
# cian (son los Bloques Beep) ni dorado vivo (los objetos rítmicos). Arte a 1x (16 o 32 px), escalado x4.
#   star_crystal.png  Cristal estelar (2x2): facetas de cristal lavanda con estrellitas dentro      (tile 61)
#   nebula_rock.png   Roca nebular (2x2): la roca oscura de debajo, con polvo de estrellas           (tile 62)
#   cloud_block.png   Nube maciza (2x2) + cloud_top.png (el borde de algodón) + cloud_under.png      (tile 63)
#   star_brick.png    Ladrillo estelar (2x2): sillares con una estrella incrustada de vez en cuando (tile 64)
#   crystal_pillar.png + _top + _bottom   Columna de cristal: fuste, capitel y basa                (tile 65)
#   star_window.png   Ventana estelar: un ojo de buey con estrellas (capa sobre el ladrillo; fondo)  (tile 66)
#   cloud_platform.png  Nube traspasable                                                             (tile 67)
#   crystal_ledge.png   Repisa de cristal traspasable                                                (tile 68)
#   star_top.png        el filo de luz estelar encima del cristal, la roca y el ladrillo
# Sin --apply: la hoja en /home/mtvemo/FlappyMonster_pruebas/via_estelar/bloques/vista_previa.png. --apply escribe los
# PNG (ninguno está retocado a mano: se pueden regenerar).   Desde la raíz:  python3 tools/art/world/make_starway_tiles.py
import os, sys, random
from PIL import Image

OUT = 'assets/images/world/tiles'
PREV = '/home/mtvemo/FlappyMonster_pruebas/via_estelar/bloques'
X = 4


def rgb(h, a=255): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


CLEAR = (0, 0, 0, 0)
CRY = [rgb(c) for c in ('3c3466', '5a5090', '7a70b4', '9c94d2', 'c4bee8', 'ece8fc')]
NEB = [rgb(c) for c in ('1c1834', '262046', '322a5a', '40366c', '7a6ea8', 'b8b0e0')]
BRK = [rgb(c) for c in ('2e2852', '4c447e', '6a62a2', '8a82bc', 'b0aad6')]
GOLD = [rgb(c) for c in ('8a6a2a', 'd8b456', 'fff0b0')]
CLD = [rgb(c) for c in ('7a76aa', '9c98c8', 'c0bce0', 'e2e0f4', 'fbfaff')]


def canvas(w, h, fill=CLEAR): return Image.new('RGBA', (w, h), fill)


def up(im): return im.resize((im.width * X, im.height * X), Image.NEAREST)


def star_crystal():
    """facetas: rombos que se repiten (32 = 2 casillas), luz arriba-izquierda; estrellitas dentro"""
    im = canvas(32, 32, CRY[2])
    for y in range(32):
        for x in range(32):
            # dos rejillas diagonales → rombos de 16
            u, v = (x + y) % 16, (x - y) % 16
            if u == 0 or v == 0: c = CRY[1]
            elif u < 4 and v > 12: c = CRY[4]              # la arista de luz de cada rombo
            elif u < 7: c = CRY[3]
            elif u > 12: c = CRY[1] if v < 3 else CRY[2]
            else: c = CRY[2]
            im.putpixel((x, y), c)
    r = random.Random(4)
    for _ in range(7):
        x, y = r.randrange(1, 31), r.randrange(1, 31)
        im.putpixel((x, y), CRY[5])
    for (x, y) in ((6, 9), (22, 25)):                      # dos estrellitas en cruz
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            im.putpixel(((x + dx) % 32, (y + dy) % 32), CRY[5] if (dx, dy) == (0, 0) else CRY[4])
    return im


def nebula_rock():
    """0.5.231 (el usuario: «muy ruidosa y muy detallada para el estilo del juego; algo más simple pero efectivo»): un
    color plano con dos ESTRATOS ondulados (la línea de sombra con su filo de luz encima), dos guijarros y tres motas de
    polvo de estrellas. Sin ruido por píxel. Sin costuras (32 = 2 casillas: las ondas tienen periodo 32).
    El original (ruido por píxel, vetas, 10 motas) está en FlappyMonster_originals/world/tiles/nebula_rock.png"""
    import math
    im = canvas(32, 32, NEB[2])
    for base, amp, ph in ((9, 1.5, 0.0), (25, 1.5, 2.2)):
        for x in range(32):
            y = base + int(round(amp * math.sin(2 * math.pi * x / 32 + ph)))
            im.putpixel((x, y % 32), NEB[1])
            im.putpixel((x, (y + 1) % 32), NEB[1] if x % 9 else NEB[2])   # (la sombra, de 2 a ratos)
            im.putpixel((x, (y - 1) % 32), NEB[3])                       # el filo de luz
    for (x, y) in ((5, 16), (21, 15)):                                     # guijarros
        for dx, dy, c in ((0, 0, 3), (1, 0, 3), (2, 0, 2), (0, 1, 2), (1, 1, 1), (2, 1, 1)):
            if not (dx == 2 and dy == 0): im.putpixel((x + dx, y + dy), NEB[c])
    for (x, y, k) in ((12, 4, 4), (28, 19, 5), (17, 30, 4)): im.putpixel((x, y), NEB[k])
    return im


def star_brick():
    """sillares de 16x8 a tresbolillo; juntas oscuras; una estrella dorada incrustada en uno de cada cuatro"""
    im = canvas(32, 32, BRK[2])
    for y in range(32):
        for x in range(32):
            row = y // 8
            off = 8 if row % 2 else 0
            bx = (x + off) % 16
            by = y % 8
            if by == 7 or bx == 15: c = BRK[0]
            elif by == 0 or bx == 0: c = BRK[3]
            elif by == 6 or bx == 14: c = BRK[1]
            else: c = BRK[2]
            im.putpixel((x, y), c)
    for (x, y) in ((20, 19),):
        for dx, dy, k in ((0, 0, 2), (1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1), (2, 0, 0), (-2, 0, 0), (0, 2, 0), (0, -2, 0)):
            if k or (dx * dx + dy * dy == 4): im.putpixel((x + dx, y + dy), GOLD[k])
    return im


def star_top():
    """el filo de arriba: 2 px de luz con chispas, 1 de sombra (64x64 a x4: solo arriba)"""
    im = canvas(16, 16)
    for x in range(16):
        im.putpixel((x, 0), CRY[5] if x % 5 else CRY[4])
        im.putpixel((x, 1), CRY[4])
        im.putpixel((x, 2), CRY[3] if (x % 3) else CRY[4])
        if x % 7 == 3: im.putpixel((x, 3), CRY[3])
    return im


def cloud_block():
    """algodón: bolas de tamaños distintos que se solapan (repetible a lo ancho y a lo alto: 32x32)"""
    im = canvas(32, 32, CLD[1])
    r = random.Random(21)
    balls = [(r.randrange(32), r.randrange(32), r.choice((4, 5, 6, 7))) for _ in range(14)]
    for y in range(32):
        for x in range(32):
            best = None
            for (cx, cy, rad) in balls:
                dx = min(abs(x - cx), 32 - abs(x - cx)); dy = min(abs(y - cy), 32 - abs(y - cy))
                ddx, ddy = dx, dy
                # luz arriba-izquierda dentro de cada bola
                sx, sy = ((x - cx + 16) % 32) - 16, ((y - cy + 16) % 32) - 16
                d = (ddx * ddx + ddy * ddy) ** 0.5
                if d <= rad:
                    k = (sx + sy) / (rad * 1.4)
                    c = CLD[3] if k < -0.35 else (CLD[2] if k < 0.45 else CLD[1])
                    if best is None or d / rad < best[0]: best = (d / rad, c)
            if best: im.putpixel((x, y), best[1])
    return im


def cloud_top():
    """el borde ondulado de algodón (sobresale un poco: 6 px)"""
    im = canvas(16, 16)
    for x in range(16):
        h = 3 + (1 if x % 8 in (2, 3, 4, 5) else 0) + (1 if x % 8 in (3, 4) else 0)
        for y in range(h):
            yy = 6 - h + y
            im.putpixel((x, yy), CLD[4] if y < 2 else CLD[3])
    return im


def cloud_under():
    im = canvas(16, 16)
    for x in range(16):
        for y in (14, 15):
            if (x + y) % 2 == 0 or y == 15: im.putpixel((x, y), CLD[0])
    return im


def crystal_pillar():
    body = canvas(16, 16)
    for y in range(16):
        for x in range(2, 14):
            c = CRY[1] if x in (2, 13) else (CRY[4] if x in (4, 5) else (CRY[2] if x > 9 else CRY[3]))
            if (y + x) % 8 == 0 and 5 < x < 10: c = CRY[4]
            body.putpixel((x, y), c)
    top = canvas(16, 16)
    for y in range(5):
        for x in range(0, 16):
            c = CRY[1] if y == 4 or x in (0, 15) else (CRY[5] if y == 0 else CRY[3])
            top.putpixel((x, y), c)
    bot = canvas(16, 16)
    for y in range(11, 16):
        for x in range(0, 16):
            c = CRY[1] if y == 11 or x in (0, 15) or y == 15 else CRY[2]
            bot.putpixel((x, y), c)
    return body, top, bot


def star_window():
    """ojo de buey: aro de cristal y dentro el cielo con dos estrellas (capa sobre el ladrillo estelar)"""
    im = canvas(16, 16)
    c = 7.5
    for y in range(16):
        for x in range(16):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if 5.2 < d <= 6.5: im.putpixel((x, y), CRY[3] if x + y < 15 else CRY[1])
            elif d <= 5.2: im.putpixel((x, y), rgb('141236'))
    for (x, y, k) in ((5, 5, 5), (10, 8, 4), (7, 10, 4)):
        im.putpixel((x, y), CRY[k])
    return im


def cloud_platform():
    im = canvas(16, 16)
    for x in range(16):
        h = 7 + (1 if x % 6 in (2, 3) else 0)
        for y in range(h):
            c = CLD[4] if y < 2 else (CLD[3] if y < 4 else (CLD[2] if y < h - 1 else CLD[1]))
            im.putpixel((x, y), c)
    return im


def crystal_ledge():
    im = canvas(16, 16)
    for x in range(16):
        for y in range(5):
            c = CRY[5] if y == 0 else (CRY[3] if y < 3 else CRY[1])
            im.putpixel((x, y), c)
        if x % 5 == 2:                                     # cristalitos colgando
            im.putpixel((x, 5), CRY[2]); im.putpixel((x, 6), CRY[1])
    return im


def build():
    pb, pt, pbo = crystal_pillar()
    return {
        'star_crystal': star_crystal(), 'nebula_rock': nebula_rock(), 'star_brick': star_brick(),
        'star_top': star_top(), 'cloud_block': cloud_block(), 'cloud_top': cloud_top(), 'cloud_under': cloud_under(),
        'crystal_pillar': pb, 'crystal_pillar_top': pt, 'crystal_pillar_bottom': pbo,
        'star_window': star_window(), 'cloud_platform': cloud_platform(), 'crystal_ledge': crystal_ledge(),
    }


def preview(ims):
    """una maqueta: un trozo de camino con cada bloque delante del cielo starway"""
    os.makedirs(PREV, exist_ok=True)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    _a, sys.argv = sys.argv, sys.argv[:1]
    import make_starway_sky as SW
    sys.argv = _a
    g, l = SW.build()
    cv = SW.background('night', g, l).convert('RGBA')
    T = 64

    def tile(name, c, r, top=None):
        im = up(ims[name])
        if im.width > T: im = im.crop(((c % 2) * T, (r % 2) * T, (c % 2) * T + T, (r % 2) * T + T))
        cv.alpha_composite(im, (c * T, r * T))
        if top: cv.alpha_composite(up(ims[top]), (c * T, r * T))

    for c in range(1, 7):
        for r in range(7, 11): tile('star_crystal' if r < 9 else 'nebula_rock', c, r, 'star_top' if r == 7 else None)
    for c in range(8, 12):
        for r in range(8, 11): tile('cloud_block', c, r, 'cloud_top' if r == 8 else None)
    for c in range(13, 19):
        for r in range(5, 11): tile('star_brick', c, r, 'star_top' if r == 5 else None)
    for (c, r) in ((14, 7), (17, 7)): cv.alpha_composite(up(ims['star_window']), (c * T, r * T))
    for r in range(3, 7):
        cv.alpha_composite(up(ims['crystal_pillar' + ('_top' if r == 3 else '')]), (8 * T, r * T))
        if r == 3: cv.alpha_composite(up(ims['crystal_pillar']), (8 * T, r * T))
    for c in (9, 10, 11): cv.alpha_composite(up(ims['cloud_platform']), (c * T, 5 * T))
    for c in (2, 3, 4): cv.alpha_composite(up(ims['crystal_ledge']), (c * T, 4 * T))
    beep = Image.open(os.path.join(OUT, 'beep_pink.png')).convert('RGBA')
    for c in (19,): cv.alpha_composite(beep, (c * T, 6 * T))
    mon = Image.open('assets/images/player/monstrito1.png').convert('RGBA')
    mon = mon.resize((mon.width * 6, mon.height * 6), Image.NEAREST)
    cv.alpha_composite(mon, (3 * T, 7 * T - mon.height))
    cv.convert('RGB').save(os.path.join(PREV, 'vista_previa.png'))
    print('vista previa:', os.path.join(PREV, 'vista_previa.png'))


if __name__ == '__main__':
    ims = build()
    preview(ims)
    if '--apply' in sys.argv:
        only = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else None   # (--only a,b)
        for n, im in ims.items():
            if only and n not in only: continue
            up(im).save(os.path.join(OUT, n + '.png')); print('  escrito', n)
