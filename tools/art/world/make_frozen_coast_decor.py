#!/usr/bin/env python3
# tools/art/world/make_frozen_coast_decor.py
# Decoraciones de la isla de la COSTA HELADA (la del Mega Crabby de hielo): la orilla de un mar polar, un viejo puerto
# pesquero helado. DOS OPCIONES para elegir (como el fondo, make_frozen_coast_sky.py):
#   A  estilo de la casa (Canvas por partes de make_jungle_decor: paleta de 4 tonos, contorno = el tono más oscuro de
#      SU color, luz arriba-izquierda): iceberg, trozos de hielo, ancla, boya con luz, bolardo, nasa, roca con algas,
#      bote volcado, red colgante, estrella de mar en hielo, témpano flotante
#   B  más atrevida (facetas PLANAS, sin degradado dentro de cada cara, formas finas y angulosas, un acento coral):
#      iceberg de cristal, ola helada, aguja de hielo, baliza con luz, cadena colgante, nasas apiladas, algas heladas,
#      mástil de un pecio, arco de hielo, medusa en hielo, témpano facetado
# Arte a 1x; el juego lo dibuja a x4 (1 casilla = 16 px de arte). 1 px de margen (pad) como todas las decoraciones.
# Por defecto SOLO hace la vista previa (fuera del repo):
#     /home/mtvemo/FlappyMonster_pruebas/fondo_costa_helada/decoraciones.png    catálogo A y B a x4 con su nombre
#     /home/mtvemo/FlappyMonster_pruebas/fondo_costa_helada/sprites_A|B/       cada sprite a 1x
# Elegida y aplicada la A (2026-10-29; su iceberg y su témpano, en facetas planas como el hielo del fondo). --apply A
# escribe en assets/images/world/decorations/frozen_coast/ y registra sus animaciones (no pisa lo que exista; --force
# para rehacerlo; tipo: src/world/decorations/types/frozen_coast_set.lua). Desde la raíz del repo:
#     ~/.venvs/fm-music/bin/python tools/art/world/make_frozen_coast_decor.py [--apply A|B [--force]]
import os, sys, math
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]          # (los módulos importados leen sys.argv al importarse)
from make_jungle_decor import Canvas, poly, stroke, line, m, U, minus, rell
from make_biome_art import pad, strip, ell, rgb
import make_jungle_sky as J
sys.argv = _argv

APPLY = '--apply' in sys.argv
FORCE = '--force' in sys.argv
PREV = '/home/mtvemo/FlappyMonster_pruebas/fondo_costa_helada'
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
DEST = os.path.join(REPO, 'assets/images/world/decorations/frozen_coast')


def R(x0, y0, x1, y1): return lambda x, y: x0 <= x <= x1 and y0 <= y <= y1


def AND(f, g): return lambda x, y: f(x, y) and g(x, y)


# ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
# A — estilo de la casa
# ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
ICE = (rgb('2c5a86'), rgb('5c92ba'), rgb('86bad6'), rgb('c4e2f0'))
ICE_L = (rgb('4a7aa6'), rgb('86b8d6'), rgb('b4daec'), rgb('e6f4fa'))
SNOW = (rgb('6a86a6'), rgb('b4cade'), rgb('dce8f2'), rgb('f8fcff'))
WOOD = (rgb('2e2026'), rgb('4e3a3a'), rgb('6e5250'), rgb('8e6e66'))
WOOD_D = (rgb('22181c'), rgb('3a2a2c'), rgb('4e3a3a'), rgb('6e5250'))
IRON = (rgb('1e2430'), rgb('3a4252'), rgb('566072'), rgb('7a8698'))
RUST = rgb('9a4e32')
RED = (rgb('4a1418'), rgb('8a2a2e'), rgb('c0443e'), rgb('e8746a'))
WHITE = (rgb('6a7a8e'), rgb('c0ccd8'), rgb('e8eef4'), rgb('ffffff'))
KELP = (rgb('1e2a14'), rgb('3e5a24'), rgb('5e7e30'), rgb('8aa848'))
ROCK = (rgb('262c38'), rgb('444e60'), rgb('626e82'), rgb('8894a8'))
ROPE = (rgb('3a2a1a'), rgb('6a5034'), rgb('9a7a50'), rgb('c4a470'))
NETBG = (rgb('14222c'), rgb('1e3240'), rgb('284454'), rgb('345a6c'))
LAMP_ON = (rgb('7a3a08'), rgb('c06a10'), rgb('f09a2c'), rgb('ffd27a'))
LAMP_OFF = (rgb('2a2a30'), rgb('4a4a54'), rgb('6a6a78'), rgb('8a8a98'))
STAR = (rgb('d86a3e'), rgb('f4a070'))


def a_iceberg():
    """(2026-10-29: el usuario eligió A, pero el hielo al estilo de B: facetas planas, sin nieve encima)"""
    c = Flat(28, 26)
    l_, m_, d_, t_ = rgb('e6f4fa'), rgb('9cc6e0'), rgb('5c92ba'), rgb('f8fcff')
    c.fill(poly([(0, 26), (2, 12), (7, 6), (13, 3), (19, 8), (24, 7), (28, 14), (28, 26)]), m_, ICE[0])
    c.fill(poly([(0, 26), (2, 12), (7, 6), (13, 3), (11, 14), (9, 26)]), l_, ICE[0])
    c.fill(poly([(18, 26), (19, 8), (24, 7), (28, 14), (28, 26)]), d_, ICE[0])
    c.fill(poly([(7, 6), (13, 3), (11, 10)]), t_, ICE[0])
    for y in range(16, 24): c.px(14 + (y > 20), y, d_)                       # grieta
    return c.image()


def a_ice_chunks():
    c = Canvas(11, 9)
    c.part(R(0, 4, 4, 8), ICE, 0.4)
    c.part(R(6, 5, 10, 8), ICE, 0.4)
    c.part(poly([(2, 4.5), (3, 0.5), (8, 1), (7.5, 5)]), ICE_L, 0.4)
    return c.image()


def a_anchor():
    c = Canvas(17, 25)
    c.part(minus(ell(8.5, 3, 2.6, 2.6), ell(8.5, 3, 1.2, 1.2)), IRON, 0.5)
    c.part(U(R(7, 5, 9, 20), R(3, 6, 13, 8),
             m(stroke(lambda t: (2.5 + 12 * t, 20.5 - 6 * (2 * t - 1) ** 2), lambda t: 1.1)),
             poly([(0, 14), (3.5, 11), (4.5, 17)]), poly([(17, 14), (13.5, 11), (12.5, 17)])), IRON, 0.35)
    c.part(AND(ell(8.5, 25.5, 9, 4.5), lambda x, y: y <= 24), SNOW, 0.5)
    for x in range(4, 13): c.dot(x, 6, SNOW[3])                                   # nieve en el cepo
    for (x, y) in ((8, 12), (7, 15), (9, 17), (11, 19), (4, 14)): c.dot(x, y, RUST)
    return c.image()


def a_buoy(on):
    c = Canvas(14, 23)
    c.part(poly([(2, 21), (3, 11), (11, 11), (12, 21)]), RED, 0.35)
    c.part(R(3, 14, 11, 16), WHITE, 0.6)
    c.part(R(5, 5, 8, 10), IRON, 0.5)
    c.part(R(5, 1, 8, 4), LAMP_ON if on else LAMP_OFF, 0.6)
    c.part(poly([(1.5, 12.5), (3, 10), (11, 10), (12.5, 12.5)]), SNOW, 0.6)
    c.part(AND(ell(7, 23.5, 7.5, 3.5), lambda x, y: y <= 22), SNOW, 0.6)
    for (x, y) in ((3, 13), (3, 14), (11, 13), (7, 13)): c.dot(x, y, ICE[3])       # carámbanos
    return c.image()


def a_bollard():
    c = Canvas(8, 13)
    c.part(U(R(2, 4, 5, 12), R(1, 2, 6, 4)), IRON, 0.4)
    c.part(U(R(1, 7, 6, 8), m(stroke(line(6, 8, 7.2, 12), lambda t: 0.6))), ROPE, 0.5)
    c.part(R(1, 1, 6, 2), SNOW, 0.6)
    return c.image()


def a_crab_pot():
    c = Canvas(16, 12)
    c.part(R(0, 2, 15, 11), WOOD, 0.4)
    c.part(R(2, 4, 13, 9), NETBG, 0.5)
    for y in range(4, 10):
        for x in range(2, 14):
            if (x + y) % 3 == 0 or (x - y) % 3 == 0: c.dot(x, y, ROPE[2])
    c.part(poly([(0, 2.5), (1, 0.5), (15, 0.5), (16, 2.5)]), SNOW, 0.6)
    return c.image()


def a_kelp_rock():
    c = Canvas(21, 14)
    c.part(ell(10.5, 9.5, 10, 5), ROCK, 0.25)
    c.part(U(m(stroke(lambda t: (9.5 - 8 * t, 5 + 7 * t * t), lambda t: 1.6)),
             m(stroke(lambda t: (11.5 + 7 * t, 5 + 6 * t * t), lambda t: 1.5))), KELP, 0.4)
    c.part(ell(10.5, 4.6, 5, 1.8), SNOW, 0.6)
    for (x, y) in ((4, 9), (16, 8), (14, 11)): c.dot(x, y, ROCK[3])              # escarcha
    return c.image()


def a_rowboat():
    c = Canvas(30, 15)
    hull = AND(ell(15, 12, 14.5, 10), lambda x, y: 3 <= y <= 11)
    c.part(hull, WOOD, 0.3)
    c.part(R(0, 10, 29, 11), WOOD_D, 0.5)
    for k, yy in enumerate((6, 8)):
        for x in range(4, 26):
            if hull(x, yy) and hull(x, yy - 1): c.dot(x, yy, WOOD[1])
    c.part(AND(ell(15, 12, 14.5, 10), lambda x, y: y <= 5), SNOW, 0.6)
    for x0 in (4, 11, 19, 24):                                                    # carámbanos bajo la borda
        c.part(poly([(x0, 12), (x0 + 2, 12), (x0 + 1, 14.5)]), ICE_L, 0.6)
    return c.image()


def a_net_hang():
    """red de pesca colgada de la casilla de arriba, con dos flotadores y carámbanos (la malla, a píxel)"""
    w, h = 16, 23
    c = Canvas(w, h)
    c.part(R(0, 0, 15, 1), ROPE, 0.5)
    c.part(ell(3.5, 3, 2, 1.6), RED, 0.5)
    c.part(ell(12.5, 3, 2, 1.6), RED, 0.5)
    im = c.image()
    for y in range(2, 20):
        x0, x1 = 1 + (y - 2) // 6, 14 - (y - 2) // 5
        for x in range(x0, x1 + 1):
            if im.getpixel((x, y))[3]: continue
            a, b = (x + y) % 4 == 0, (x - y) % 4 == 0
            if a and b: im.putpixel((x, y), ROPE[0])
            elif a or b: im.putpixel((x, y), ROPE[1] if y > 14 else ROPE[2])
    for x in (5, 8, 11):                                                          # carámbanos
        for i, col in enumerate((ICE_L[2], ICE_L[3], ICE_L[2])):
            if 19 + i < h: im.putpixel((x, 19 + i), col)
    return im


def a_starfish_ice():
    c = Canvas(8, 8)
    c.part(R(0, 1, 7, 7), ICE_L, 0.45)
    for y, row in enumerate(("..x...", "xxxxx.", ".xxx..", ".x.x..")):
        for x, ch in enumerate(row):
            if ch == 'x': c.dot(1 + x, 2 + y, STAR[0])
    c.dot(3, 3, STAR[1])
    return c.image()


def a_floe():
    c = Flat(18, 6)
    c.fill(poly([(0, 3), (3, 0), (15, 0.5), (18, 3.5), (15, 6), (2, 6)]), rgb('9cc6e0'), ICE[0])
    c.fill(poly([(0, 3), (3, 0), (15, 0.5), (18, 3.5)]), rgb('e6f4fa'), ICE[0])
    return c.image()


# ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
# B — facetas planas (cada cara un solo color), formas finas y angulosas, acento coral
# ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
BL, BM, BD, BLL = rgb('d8f2f6'), rgb('7ac6d6'), rgb('3e94b0'), rgb('f2fbfc')
OUT = rgb('1f5a72')
NAVY, NAVY_L, NAVY_O = rgb('2c3444'), rgb('48506a'), rgb('161c28')
CORAL, CORAL_D = rgb('e8704a'), rgb('a8442c')
AMBER, AMBER_OFF = rgb('f09a2c'), rgb('5a5a66')
SAIL, SAIL_D = rgb('e8eef0'), rgb('a8bcc6')
JELLY, JELLY_L = rgb('b060c0'), rgb('e8a8ee')


class Flat:
    """lienzo de caras planas: cada fill() pinta su máscara de UN color; el contorno (1 px, de un color) solo en el
    filo con el vacío de las partes que lo piden (lo fino va sin contorno)"""
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.c = [[None] * w for _ in range(h)]
        self.edge = [[None] * w for _ in range(h)]

    def fill(self, f, col, edge=OUT):
        for y in range(self.h):
            for x in range(self.w):
                if f(x, y): self.c[y][x] = col; self.edge[y][x] = edge

    def px(self, x, y, col):
        if 0 <= x < self.w and 0 <= y < self.h: self.c[y][x] = col; self.edge[y][x] = None

    def image(self):
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        at = lambda x, y: self.c[y][x] if 0 <= x < self.w and 0 <= y < self.h else None
        for y in range(self.h):
            for x in range(self.w):
                col = self.c[y][x]
                if col is None: continue
                if self.edge[y][x] and any(at(x + dx, y + dy) is None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    col = self.edge[y][x]
                im.putpixel((x, y), col)
        return im


def b_crystal_berg():
    c = Flat(26, 30)
    c.fill(poly([(1, 30), (3, 14), (8, 5), (13, 1), (18, 6), (24, 12), (25, 30)]), BM)
    c.fill(poly([(1, 30), (3, 14), (8, 5), (13, 1), (11, 15), (9, 30)]), BL)
    c.fill(poly([(17, 30), (18, 6), (24, 12), (25, 30)]), BD)
    c.fill(poly([(8, 5), (13, 1), (11.5, 9)]), BLL)
    for y in range(18, 27): c.px(13 + (y > 22), y, BD)
    return c.image()


def b_frozen_wave():
    lay = J.L(27, 33)
    import make_frozen_coast_sky as SK
    SK.frozen_wave(lay, 19, 26, 24, 24)
    src = lay.im
    c = Flat(33, 27)
    for y in range(27):
        for x in range(33):
            p = src.getpixel((x, y))
            if p[3]: c.fill(lambda xx, yy, X=x, Y=y: xx == X and yy == Y, p, OUT if p[:3] != SK.B['foam'][:3] else rgb('8cc8d4'))
    return c.image()


def b_ice_spire():
    c = Flat(11, 40)
    c.fill(poly([(0, 40), (7, 0), (10, 40)]), BM)
    c.fill(poly([(0, 40), (7, 0), (4.5, 40)]), BL)
    c.fill(poly([(7.5, 40), (7, 0), (10, 40)]), BD)
    c.fill(poly([(5, 40), (9, 30), (11, 40)]), BD)
    return c.image()


def b_beacon(on):
    c = Flat(9, 40)
    c.fill(R(4, 10, 5, 39), NAVY, None)
    c.fill(R(1, 11, 8, 12), NAVY, None)
    c.fill(poly([(1, 10), (4.5, 3), (8, 10)]), CORAL, CORAL_D)
    c.fill(poly([(4.5, 3), (8, 10), (4.5, 10)]), CORAL_D, CORAL_D)
    c.fill(R(3, 0, 6, 2), AMBER if on else AMBER_OFF, None)
    c.fill(R(3, 18, 6, 21), CORAL, None)
    for (x, y) in ((1, 13), (1, 14), (8, 13), (4, 22)): c.px(x, y, BL)            # carámbanos
    c.fill(poly([(0, 40), (2, 36), (7, 35), (9, 40)]), BL)
    c.fill(poly([(5, 40), (7, 35), (9, 40)]), BM)
    return c.image()


def b_chain_hang():
    c = Flat(8, 30)
    for k in range(6):
        y0 = k * 4
        if k % 2 == 0:
            c.fill(minus(ell(4, y0 + 2.5, 2.6, 2.8), ell(4, y0 + 2.5, 1.0, 1.4)), rgb('8a96aa'), NAVY)
        else:
            c.fill(R(3, y0 + 1, 4, y0 + 4), rgb('aab6c8'), NAVY)
        c.px(2, y0 + 1, BLL)
    c.fill(U(R(3, 24, 4, 26), m(stroke(lambda t: (4 + 2.5 * math.sin(t * 3.2), 26 + 2.5 * (1 - math.cos(t * 3.2))), lambda t: 0.6))),
           rgb('8a96aa'), NAVY)
    for x, ln in ((2, 3), (5, 2)):
        for i in range(ln): c.px(x, 9 + i, BL)
    return c.image()


def b_crab_pot_stack():
    c = Flat(17, 23)
    for (x0, y0, x1, y1) in ((0, 12, 15, 22), (2, 2, 16, 11)):
        c.fill(R(x0, y0, x1, y1), CORAL, CORAL_D)
        c.fill(R(x0 + 2, y0 + 2, x1 - 2, y1 - 2), rgb('1f4a5e'), None)
        for y in range(y0 + 2, y1 - 1):
            for x in range(x0 + 2, x1 - 1):
                if (x + y) % 3 == 0: c.px(x, y, BD)
    c.fill(poly([(2, 2.5), (3, 0), (15, 0), (16.5, 2.5)]), BL)
    c.fill(poly([(0, 12.5), (1, 11), (2, 11), (2, 12.5)]), BL)
    return c.image()


def b_frozen_kelp():
    """tres tallos finos de alga forrados de hielo (2 px: cara clara y cara oscura), con su vejiga arriba"""
    c = Flat(9, 27)
    for (x0, top, ph) in ((1, 3, 0.0), (4, 10, 1.4), (6, 6, 2.6)):
        for y in range(top + 2, 27):
            x = int(round(x0 + 0.8 * math.sin((27 - y) * 0.35 + ph)))
            c.px(x, y, BL); c.px(x + 1, y, BD)
            if (y + int(ph * 3)) % 6 == 0: c.px(x + 2, y, BM); c.px(x + 2, y - 1, BM)      # hojitas
        x = int(round(x0 + 0.8 * math.sin((27 - top - 2) * 0.35 + ph)))
        c.fill(R(x, top, x + 1, top + 1), BLL, None)
    return c.image()


def b_mast_wreck():
    c = Flat(21, 41)
    c.fill(m(stroke(line(6, 40, 12.5, 2), lambda t: 1.1)), NAVY, NAVY_O)
    c.fill(m(stroke(line(3, 11, 19, 7), lambda t: 0.7)), NAVY, None)
    c.fill(poly([(12, 9.5), (18.5, 8), (17.5, 22), (15, 19), (13, 25), (10.5, 18)]), SAIL, SAIL_D)
    c.fill(poly([(15.5, 9), (18.5, 8), (17.5, 22), (15, 19)]), SAIL_D, SAIL_D)
    for (x, ln) in ((4, 2), (7, 3), (18, 2)):                                        # carámbanos de la verga
        y = int(11 - (x - 3) * 4 / 16) + 1
        for i in range(ln): c.px(x, y + i, BL)
    c.fill(poly([(0, 41), (3, 35), (9, 34), (14, 37), (19, 41)]), BL)
    c.fill(poly([(9, 34), (14, 37), (19, 41), (9, 41)]), BM)
    return c.image()


def b_ice_arch():
    c = Flat(32, 22)
    c.fill(poly([(0, 22), (2, 8), (8, 2), (20, 1), (28, 5), (32, 22), (25, 22), (24, 12), (18, 9), (11, 10), (7, 14), (6.5, 22)]), BM)
    c.fill(poly([(0, 22), (2, 8), (8, 2), (11, 10), (7, 14), (6.5, 22)]), BL)
    c.fill(poly([(20, 1), (28, 5), (32, 22), (25, 22), (24, 12), (18, 9)]), BD)
    c.fill(poly([(8, 2), (20, 1), (15, 4)]), BLL)
    return c.image()


def b_jelly_ice():
    c = Flat(8, 10)
    c.fill(R(0, 1, 7, 9), BM)
    c.fill(poly([(0, 1), (8, 1), (0, 9)]), BL)
    for (x, y, col) in ((3, 3, JELLY_L), (4, 3, JELLY), (2, 4, JELLY), (3, 4, JELLY), (4, 4, JELLY), (5, 4, JELLY),
                        (2, 5, JELLY), (4, 5, JELLY), (5, 6, JELLY), (3, 6, JELLY), (2, 7, JELLY), (5, 7, JELLY)):
        c.px(x, y, col)
    return c.image()


def b_floe():
    c = Flat(18, 6)
    c.fill(poly([(0, 3), (3, 0), (15, 0.5), (18, 3.5), (15, 6), (2, 6)]), BM)
    c.fill(poly([(0, 3), (3, 0), (15, 0.5), (18, 3.5)]), BL)
    return c.image()


# ══ Catálogo ════════════════════════════════════════════════════════════════════════════════════════════════════
# nombre, etiqueta (editor), función, colocación, capa, cuelga, ancho de cuadro (None = 1), qué haría en el juego
ITEMS = {
    'A': [
        ('iceberg', 'Iceberg', a_iceberg, 'cell', 'back', False, None, 'estático'),
        ('ice_chunks', 'Trozos de hielo', a_ice_chunks, 'sub', 'front', False, None, 'estático'),
        ('anchor', 'Ancla', a_anchor, 'cell', 'back', False, None, 'estático'),
        ('buoy', 'Boya con luz', lambda: strip([a_buoy(True), a_buoy(False)]), 'cell', 'back', False, 14,
         'luz parpadea (2 cuadros) + brillo ámbar'),
        ('bollard', 'Bolardo', a_bollard, 'sub', 'front', False, None, 'estático'),
        ('crab_pot', 'Nasa', a_crab_pot, 'cell', 'back', False, None, 'estático'),
        ('kelp_rock', 'Roca con algas', a_kelp_rock, 'cell', 'back', False, None, 'estático'),
        ('rowboat', 'Bote volcado', a_rowboat, 'cell', 'back', False, None, 'estático; gotas de los carámbanos'),
        ('net_hang', 'Red colgante', a_net_hang, 'cell', 'back', True, None, 'cuelga; wave suave'),
        ('starfish_ice', 'Estrella de mar en hielo', a_starfish_ice, 'sub', 'front', False, None, 'estático'),
        ('floe', 'Témpano flotante', a_floe, 'cell', 'back', False, None, 'se mece en el agua (sube y baja)'),
    ],
    'B': [
        ('crystal_berg', 'Iceberg de cristal', b_crystal_berg, 'cell', 'back', False, None, 'estático; destello'),
        ('frozen_wave', 'Ola helada', b_frozen_wave, 'cell', 'back', False, None, 'estático'),
        ('ice_spire', 'Aguja de hielo', b_ice_spire, 'cell', 'back', False, None, 'estático'),
        ('beacon', 'Baliza', lambda: strip([b_beacon(True), b_beacon(False)]), 'cell', 'back', False, 9,
         'luz parpadea (2 cuadros) + brillo ámbar'),
        ('chain_hang', 'Cadena colgante', b_chain_hang, 'sub', 'back', True, None, 'cuelga; se balancea (rot)'),
        ('crab_pot_stack', 'Nasas apiladas', b_crab_pot_stack, 'cell', 'back', False, None, 'estático'),
        ('frozen_kelp', 'Algas heladas', b_frozen_kelp, 'sub', 'front', False, None, 'estático'),
        ('mast_wreck', 'Mástil de un pecio', b_mast_wreck, 'cell', 'back', False, None, 'la vela se mece un poco'),
        ('ice_arch', 'Arco de hielo', b_ice_arch, 'cell', 'back', False, None, 'estático; gotas'),
        ('jelly_ice', 'Medusa en hielo', b_jelly_ice, 'sub', 'front', False, None, 'estático'),
        ('floe_b', 'Témpano facetado', b_floe, 'cell', 'back', False, None, 'se mece en el agua (sube y baja)'),
    ],
}


def build(opt):
    """→ {nombre: (imagen con margen, ancho de cuadro con margen, cuelga, colocación)}"""
    out = {}
    for (name, label, fn, place, layer, hang, fw, anim) in ITEMS[opt]:
        img = pad(fn(), hang, fw)
        out[name] = (img, (fw + 2) if fw else img.width, hang, place)
    return out


def first(e):
    img, fw, hang, place = e
    return img.crop((0, 0, fw, img.height))


# ══ Vista previa ═══════════════════════════════════════════════════════════════════════════════════════════════════
S = 4
FONT = ImageFont.truetype(os.path.join(REPO, 'assets/fonts/PressStart2P.ttf'), 8)
TIL = os.path.join(REPO, 'assets/images/world/tiles')


def up(im, k=S): return im.resize((im.width * k, im.height * k), Image.NEAREST)


def text(d, x, y, s, col=(230, 240, 250)):
    d.text((x + 1, y + 1), s, font=FONT, fill=(10, 16, 24))
    d.text((x, y), s, font=FONT, fill=col)


def sheet():
    W = 2400
    snow = Image.open(os.path.join(TIL, 'snow.png')).convert('RGBA')
    ice = Image.open(os.path.join(TIL, 'ice.png')).convert('RGBA')
    out = Image.new('RGBA', (W, 1300), rgb('1c2834'))
    d = ImageDraw.Draw(out)
    y_base = 0
    for opt, title in (('A', 'A - estilo de la casa (4 tonos, contorno de su color)'),
                       ('B', 'B - facetas planas, formas finas, acento coral')):
        items = build(opt)
        text(d, 20, y_base + 16, title, (255, 255, 255))
        ground = y_base + 470
        for gx in range(0, W, 64): out.alpha_composite(snow, (gx, ground))
        ceil = y_base + 110
        x = 30
        hanging = []
        for (name, label, fn, place, layer, hang, fw, anim) in ITEMS[opt]:
            img, fwp, h_, pl = items[name]
            if hang: hanging.append(name); continue
            n = img.width // fwp
            for k in range(n):
                fr = up(img.crop((k * fwp, 0, (k + 1) * fwp, img.height)))
                out.alpha_composite(fr, (x + k * (fr.width + 8), ground - fr.height + (8 if name.startswith('floe') else 0)))
            wtot = n * (fwp * S + 8)
            text(d, x, ground + 76, name)
            text(d, x, ground + 92, '%s %dx%d' % (pl, fwp - 2, img.height - 1), (150, 180, 200))
            x += max(wtot, 120) + 26
        x += 30
        for gx in range(x - 20, x + 64 * 3, 64): out.alpha_composite(ice, (gx, ceil - 64))
        for name in hanging:
            img, fwp, h_, pl = items[name]
            fr = up(first(items[name]))
            out.alpha_composite(fr, (x, ceil))
            text(d, x, ceil + fr.height + 10, name)
            x += fr.width + 60
        pl = up(Image.open(os.path.join(REPO, 'assets/images/player/monstrito1.png')).convert('RGBA'), 6)
        out.alpha_composite(pl, (W - 120, ground - pl.height))
        y_base += 650
    return out


# ── En la escena de make_frozen_coast_sky.py (filas de 64 px; la fila 0 empieza en oy) ─────────────────────────────
SCENE_PLACES = {
    # (nombre, columna, fila de la casilla, dx en px)  — se apoya en el fondo de su casilla (cuelga: arriba)
    'A': [('rowboat', 0, 8, 10), ('kelp_rock', 5, 8, 0), ('starfish_ice', 6, 8, -12), ('anchor', 4, 8, 0),
          ('bollard', 6, 8, 18), ('net_hang', 4, 6, 0), ('floe', 12, 8, 0), ('buoy', 13, 7, 0), ('crab_pot', 16, 7, 0),
          ('iceberg', 19, 7, 12), ('ice_chunks', 14, 7, 20)],
    'B': [('crystal_berg', 0, 8, 0), ('frozen_kelp', 3, 8, 0), ('ice_spire', 5, 8, 0), ('jelly_ice', 6, 8, -6),
          ('chain_hang', 4, 6, 0), ('floe_b', 12, 8, 0), ('beacon', 13, 7, -8), ('crab_pot_stack', 16, 7, 0),
          ('mast_wreck', 19, 7, 0), ('frozen_wave', 14, 7, 0)],
}


def place_in_scene(cv, opt, oy):
    items = build(opt)
    for (name, col, row, dx) in SCENE_PLACES[opt]:
        fr = up(first(items[name]))
        img, fw, hang, place = items[name]
        cx = col * 64 + (32 if place == 'cell' else 16) + dx
        if hang:
            cv.alpha_composite(fr, (cx - fr.width // 2, oy + row * 64))
        else:
            bottom = oy + (row + 1) * 64 + (8 if name.startswith('floe') else 0)
            cv.alpha_composite(fr, (cx - fr.width // 2, bottom - fr.height))


def main():
    for opt in ('A', 'B'):
        os.makedirs(os.path.join(PREV, 'sprites_' + opt), exist_ok=True)
        for name, (img, fw, hang, place) in build(opt).items():
            img.save(os.path.join(PREV, 'sprites_' + opt, (name + '-Sheet.png') if fw != img.width else name + '.png'))
    pv = sheet()
    pv.convert('RGB').save(os.path.join(PREV, 'decoraciones.png'))
    print('  %s  %dx%d' % (os.path.join(PREV, 'decoraciones.png'), pv.width, pv.height))
    if APPLY: apply()


ANIM_OPTS = {'buoy': {'durations': [0.5, 0.9]}, 'beacon': {'durations': [0.4, 1.2]}}


def apply():
    """escribe la opción elegida (--apply A|B) y registra sus animaciones (assets/anim/world/decorations/frozen_coast)"""
    args = [a for a in sys.argv[sys.argv.index('--apply') + 1:] if not a.startswith('--')]
    opt = args[0].upper() if args and args[0].upper() in ITEMS else None
    if not opt: print('--apply necesita la opción: --apply A  o  --apply B'); return
    os.makedirs(DEST, exist_ok=True)
    ent = []
    for name, (img, fw, hang, place) in build(opt).items():
        fn = (name + '-Sheet.png') if fw != img.width else name + '.png'
        path = os.path.join(DEST, fn)
        if os.path.exists(path) and not FORCE: print('  %s ya existe: no se toca (--force)' % path)
        else: img.save(path); print('  %-60s %dx%d' % (os.path.relpath(path, REPO), img.width, img.height))
        ent.append((name, os.path.relpath(path, REPO).replace(os.sep, '/'), None if fw == img.width else fw, ANIM_OPTS.get(name)))
    sys.path.insert(0, os.path.join(REPO, 'tools', 'anim'))
    from common import add_anims
    print('  animaciones nuevas: %d' % add_anims('world/decorations/frozen_coast', ent))


if __name__ == '__main__':
    main()
