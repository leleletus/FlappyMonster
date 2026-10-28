#!/usr/bin/env python3
# tools/art/world/make_jungle_sky.py
# Isla de la SELVA (el templo del Escarabajo Rinoceronte): fondos y bloques. Arte a 1x; el juego lo dibuja a x4.
#   Fondo de SUPERFICIE `jungle` (sky/): jungle_far (colinas con niebla y zigurat), jungle_mid (dosel con árboles
#       emergentes), jungle_near (troncos con contrafuertes, hojas gigantes, lianas), jungle_top (dosel que cuelga
#       de arriba del nivel) + 3 degradados propios (día / atardecer / noche: húmedo, verdoso)
#   Fondo de PROFUNDIDAD `temple` (sky/): temple_far (arcada de pilares), temple_mid (escombros, pilares rotos,
#       estatua del escarabajo), temple_top (techo de sillares con raíces), temple_wall (160x160) + su degradado
#   Bloques (tiles/, 16x16 x4): jungle_grass (musgo y hierba sobre barro, si su cara de arriba da al aire),
#       mud (barro), jungle_blades (matas que asoman, 3 variantes de 16x4), temple_brick (sillares con tallas,
#       dibujo de 4x4 casillas: span = 4), temple_moss (capa de musgo que se pinta ENCIMA del sillar si su cara de
#       arriba da al aire), jungle_platform (A: tablones atados con liana) y jungle_platform_b (B: bambú con cuerda)
# Por defecto solo hace la VISTA PREVIA (fuera del repo):
#   /home/mtvemo/FlappyMonster_pruebas/selva/fondo/vista_previa.png  (+ capas/ con cada PNG a su tamaño real)
# --apply escribe los archivos de verdad en assets/ (no pisa lo que exista; los degradados se AÑADEN a
# gradients.png como cuadros 11..15). Desde la raíz del repo:
#     ~/.venvs/fm-music/bin/python tools/art/world/make_jungle_sky.py [--apply]
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont

APPLY = '--apply' in sys.argv
PREV = '/home/mtvemo/FlappyMonster_pruebas/selva/fondo'
SKY = 'assets/images/world/sky'
TIL = 'assets/images/world/tiles'
W = 320
S = 4


def rgb(h, a=255): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def profile(terms, base):
    """Altura por columna, repetible a lo ancho (ciclos enteros)."""
    return [base + sum(a * math.sin(2 * math.pi * k * x / W + p) for a, k, p in terms) for x in range(W)]


class L:
    """Capa de 1x que se repite a lo ancho (x en módulo W)."""
    def __init__(self, h, w=W):
        self.w, self.h = w, h
        self.im = Image.new('RGBA', (w, h), (0, 0, 0, 0))

    def put(self, x, y, c):
        if 0 <= y < self.h: self.im.putpixel((int(x) % self.w, int(y)), c)

    def get(self, x, y):
        if 0 <= y < self.h: return self.im.getpixel((int(x) % self.w, int(y)))
        return (0, 0, 0, 0)

    def has(self, x, y): return self.get(x, y)[3] > 0

    def blob(self, cx, cy, r, body, light=None, dark=None, ry=None):
        """Círculo (o elipse) con luz arriba-izquierda y sombra abajo."""
        ry = ry or r
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1:
                    c = body
                    if light and dx + dy * 1.3 < -0.75: c = light
                    elif dark and dy > 0.62: c = dark
                    self.put(x, y, c)


rnd = random.Random(11)


# ══ Degradados (8x180, franjas planas con una fila tramada en cada cambio, como make_sky.py) ═════════════════
GRADS = {
    'jungle_day':   ['6aa4c0', '80b4c4', '98c6c4', 'b0d6c0', 'c8e4bc'],    # neblina verde-turquesa abajo
    'jungle_dusk':  ['3a3a68', '664a78', 'a26276', 'd08c6a', 'dcb47a'],
    'jungle_night': ['081420', '0c1c28', '102432', '162e3a', '1c3842'],
    'temple':       ['28342a', '222e24', '1c271e', '162018', '101812'],
}


def grad_frame(cols):
    out = Image.new('RGBA', (8, 180))
    n = len(cols)
    band = 180 / n
    for y in range(180):
        b = min(n - 1, int(y / band))
        nxt = int((b + 1) * band)
        for x in range(8):
            c = cols[b]
            if b < n - 1 and y == nxt - 1 and (x + y) % 2 == 0: c = cols[b + 1]
            out.putpixel((x, y), rgb(c))
    return out


# ══ SELVA: superficie ═════════════════════════════════════════════════════════════════════════════════════════
FB, FL, FD, FM = rgb('7aa696'), rgb('8eb8a6'), rgb('6e9888'), rgb('9cc4b0')       # lejos (bruma)
MB, ML, MD = rgb('3c705a'), rgb('4a8068'), rgb('31604c')                          # dosel (medio)
NB, NL, ND = rgb('1c4630'), rgb('255638'), rgb('143826')                          # cerca: hojas
TB, TL, TD = rgb('30261a'), rgb('403222'), rgb('221a12')                          # cerca: troncos
LI = rgb('2a4c2c')                                                                # lianas


def zigurat(lay, cx, base, tiers, th, shrine, body, light, dark):
    """Pirámide escalonada: cada piso con su filo claro arriba y a la izquierda, escalera central."""
    y = base
    for hw in tiers:
        for yy in range(y - th, y):
            for x in range(cx - hw, cx + hw + 1):
                c = body
                if yy == y - th or x == cx - hw: c = light
                lay.put(x, yy, c)
        y -= th
    sw = shrine
    for yy in range(y - 9, y):                       # templete de la cima
        for x in range(cx - sw, cx + sw + 1):
            lay.put(x, yy, light if (yy == y - 9 or x == cx - sw) else body)
    for x in range(cx - sw - 2, cx + sw + 3): lay.put(x, y - 10, light)     # cornisa
    for x in range(cx - sw - 1, cx + sw + 2): lay.put(x, y - 11, body)
    for yy in range(y - 6, y):                       # puerta
        for x in range(cx - 1, cx + 2): lay.put(x, yy, dark)
    for yy in range(y, base):                        # escalera central
        for x in range(cx - 3, cx + 4):
            lay.put(x, yy, dark if (yy % 2 == 0) else body)


def umbrella_tree(lay, x0, base, h, rx, body, light, dark, trunk=None):
    """Árbol emergente: tronco fino y copa plana ancha (ceiba)."""
    trunk = trunk or dark
    top = base - h
    for y in range(top + 2, base + 1):
        lay.put(x0, y, trunk); lay.put(x0 + 1, y, trunk)
    for k, (dx, dy) in enumerate(((-5, -3), (5, -2), (-10, 1), (10, 1))):      # ramas
        for i in range(5):
            lay.put(x0 + (dx * i) // 5, top + 4 + (dy * i) // 5 + i // 2, trunk)
    lay.blob(x0 + 0.5, top, rx, body, light, dark, ry=rx * 0.34)
    lay.blob(x0 - rx * 0.4, top - 2, rx * 0.5, body, light, None, ry=rx * 0.25)
    lay.blob(x0 + rx * 0.45, top - 1.5, rx * 0.45, body, light, None, ry=rx * 0.22)


def jungle_far():
    lay = L(130)
    hp = profile([(7, 2, 0.6), (4, 5, 2.0), (2, 11, 0.4)], 46)
    for x in range(W):
        y0 = int(round(130 - hp[x]))
        for y in range(y0, 130): lay.put(x, y, FL if y == y0 else FB)
    zigurat(lay, 205, 130 - 40, [44, 37, 30, 23, 16, 11], 8, 6, FB, FL, FD)
    zigurat(lay, 58, 130 - 44, [20, 15, 10], 7, 4, FB, FL, FD)
    for x0 in range(14, W, 33):                       # ceibas lejanas sobre las colinas
        if abs(x0 - 205) < 50 or abs(x0 - 58) < 24: continue
        b = int(round(130 - hp[x0]))
        umbrella_tree(lay, x0, b + 2, 14 + rnd.randrange(8), 7 + rnd.randrange(3), FB, FL, None, FD)
    # bruma: la falda de las colinas, más clara (tramado en el filo)
    for y in range(96, 130):
        for x in range(W):
            if not lay.has(x, y): continue
            if y > 100 or (y >= 97 and (x + y) % 2 == 0): lay.put(x, y, FM)
    return lay.im


def jungle_mid():
    lay = L(110)
    cp = profile([(4, 3, 1.1), (3, 7, 0.2)], 52)
    for x in range(W):
        y0 = int(round(110 - cp[x]))
        for y in range(y0, 110): lay.put(x, y, MD if y > 96 else MB)
    for x0 in range(0, W, 9):                          # copas redondas del dosel
        r = 6 + rnd.randrange(4)
        lay.blob(x0 + rnd.randrange(3), 110 - cp[x0] + 2, r, MB, ML, None)
    for x0 in (36, 148, 262):                          # árboles emergentes por encima del dosel
        base = int(110 - cp[x0]) + 4
        umbrella_tree(lay, x0, base, 34 + rnd.randrange(12), 15, MB, ML, MD)
    for x0 in range(5, W, 23):                         # algún tronco que asoma en la sombra de abajo
        if x0 % 3: continue
        for y in range(97, 104 + x0 % 5):
            lay.put(x0, y, MB); lay.put(x0 + 1, y, MB)
    return lay.im


def leaf(lay, bx, by, ang, ln, wd, body=NB, light=NL, dark=ND):
    """Hoja gigante (oreja de elefante): elipse girada con nervio central, tallo hasta (bx, by)."""
    ca, sa = math.cos(ang), math.sin(ang)
    cx, cy = bx + ca * ln * 0.9, by + sa * ln * 0.9
    R = int(ln) + 2
    for y in range(int(cy) - R, int(cy) + R + 1):
        for x in range(int(cx) - R, int(cx) + R + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u = (dx * ca + dy * sa) / ln                # a lo largo de la hoja
            v = (-dx * sa + dy * ca) / wd               # a lo ancho
            if u * u + v * v <= 1:
                edge = u * u + v * v > 0.72
                c = dark if edge else (light if v < -0.15 else body)
                if abs(v) < 0.14 and u > -0.85: c = dark       # nervio
                lay.put(x, y, c)
    for i in range(int(ln * 0.9)):                     # tallo
        lay.put(bx + ca * i * 0.4, by + sa * i * 0.4 + i * 0.6, dark)


def fern(lay, bx, by, n=5, ln=9, col=ND):
    for k in range(n):
        a = -math.pi / 2 + (k - (n - 1) / 2) * 0.45
        for i in range(ln):
            t = i / ln
            x = bx + math.cos(a) * i
            y = by + math.sin(a) * i + t * t * 6
            lay.put(x, y, col)
            if i % 2 == 0 and i > 1: lay.put(x + (1 if math.cos(a) >= 0 else -1), y + 1, col)


def liana(lay, x0, y0, x1, y1, sag, col=LI, leafc=NB):
    n = int(abs(x1 - x0) * 1.2) + 1
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t + sag * 4 * t * (1 - t)
        lay.put(x, y, col)
        if i % 7 == 3:
            lay.put(x, y + 1, leafc); lay.put(x + 1, y + 1, leafc); lay.put(x, y + 2, leafc)


def hang(lay, x0, y0, ln, col=LI, leafc=NB, curl=True):
    x = float(x0)
    for i in range(ln):
        x0f = x0 + math.sin(i * 0.18 + x0) * 1.2
        lay.put(x0f, y0 + i, col)
        if i % 6 == 4:
            lay.put(x0f + 1, y0 + i, leafc); lay.put(x0f + 2, y0 + i + 1, leafc)
        if i % 6 == 1 and i > 3:
            lay.put(x0f - 1, y0 + i, leafc)
    if curl:
        y = y0 + ln
        for dx, dy in ((0, 0), (1, 1), (2, 1), (2, 0), (1, -1)): lay.put(x0 + math.sin(ln * 0.18 + x0) * 1.2 + dx, y + dy, col)


def big_tree(lay, x0, h, ground):
    """Tronco grande con contrafuertes y copa arriba; ramas con lianas colgando."""
    top = ground - h
    w = 5
    for y in range(top + 6, ground):
        flare = max(0, y - (ground - 16)) * 0.75        # contrafuertes
        for x in range(int(x0 - w - flare), int(x0 + w + flare) + 1):
            dx = x - x0
            c = TB
            if dx <= -w + 1 - flare * 0.6: c = TL
            if dx >= w - 1: c = TD
            if flare and abs(dx) > w + 1 and (x + y) % 5 == 0: c = TD     # surcos de las raíces
            lay.put(x, y, c)
        if y % 9 == 0: lay.put(x0 - 1, y, TD); lay.put(x0, y, TD)
    for side in (-1, 1):                               # ramas
        by = top + 18 + (6 if side > 0 else 0)
        for i in range(16):
            lay.put(x0 + side * (w + i), by - i // 2, TB)
            lay.put(x0 + side * (w + i), by - i // 2 + 1, TD)
        lay.blob(x0 + side * (w + 16), by - 10, 7, NB, NL, ND, ry=5)
        hang(lay, x0 + side * (w + 10), by - 3, 26 + rnd.randrange(16))
    for (dx, dy, r) in ((0, 6, 15), (-14, 10, 11), (14, 9, 12), (-6, 2, 9), (8, 1, 9)):    # copa
        lay.blob(x0 + dx, top + dy, r, NB, NL, ND, ry=r * 0.7)
    hang(lay, x0 - 9, top + 14, 40)
    hang(lay, x0 + 11, top + 14, 30)


def jungle_near():
    lay = L(120)
    gp = profile([(3, 4, 0.5), (2, 9, 1.7)], 14)
    g = lambda x: int(round(120 - gp[int(x) % W]))
    big_tree(lay, 74, 104, 112)
    big_tree(lay, 238, 96, 114)
    liana(lay, 88, 34, 224, 40, 26)                     # lianas de árbol a árbol
    liana(lay, 252, 40, 380, 30, 30)
    for x in range(W):                                  # sotobosque
        for y in range(g(x), 120): lay.put(x, y, NL if y == g(x) else NB)
    for x0 in range(4, W, 22):                          # hojas gigantes y helechos
        b = g(x0)
        a = -math.pi / 2 + rnd.choice((-0.8, -0.5, 0.5, 0.8))
        leaf(lay, x0, b + 2, a, 9 + rnd.randrange(5), 4.5)
        if rnd.random() < 0.6: leaf(lay, x0 + 3, b + 2, -math.pi / 2 + rnd.choice((-0.3, 0.3)), 7 + rnd.randrange(4), 3.5)
        fern(lay, x0 + 11, b + 1)
    return lay.im


def jungle_top():
    lay = L(60)
    tp = profile([(2, 3, 0.4), (2, 8, 1.2)], 6)
    for x in range(W):
        for y in range(0, int(tp[x])): lay.put(x, y, NB)
    for x0 in range(0, W, 8):                           # matas de hojas que cuelgan
        r = 4 + rnd.randrange(4)
        cy = tp[x0] + rnd.randrange(3)
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(x0 - r - 1, x0 + r + 2):
                dx, dy = (x + 0.5 - x0) / r, (y + 0.5 - cy) / (r * 0.8)
                if dx * dx + dy * dy <= 1:
                    lay.put(x, y, ND if dy > 0.55 else NB)
    for x0 in range(5, W, 13):                          # lianas y hojas colgando
        y0 = int(tp[x0 % W]) + 3
        if rnd.random() < 0.65: hang(lay, x0, y0, 10 + rnd.randrange(38))
        else: leaf(lay, x0, y0 - 2, math.pi / 2 + rnd.choice((-0.5, 0.5)), 6 + rnd.randrange(3), 3)
    return lay.im


# ══ TEMPLO: profundidad ═══════════════════════════════════════════════════════════════════════════════════════
SB, SL, SD = rgb('2c3a30'), rgb('3a4a3c'), rgb('222e26')       # piedra lejana
RB, RL, RD = rgb('1e2820'), rgb('2a362c'), rgb('161e18')       # escombros (más cerca, más oscuro)
VG, VL = rgb('2a4228'), rgb('36522e')                          # enredaderas
RT, RTL = rgb('33261a'), rgb('44331f')                         # raíces


def temple_far():
    lay = L(100)
    P = 80                                               # pilar cada 80 (4 por vuelta)
    for x in range(W):
        k = x % P
        pillar = k < 16
        for y in range(8, 100):
            if y < 20:                                   # dintel corrido
                lay.put(x, y, SL if y == 8 else (SD if (x % 12 == 0 and y > 9) else SB))
                continue
            if pillar:
                c = SL if k == 0 else (SD if k == 15 else SB)
                if 20 <= y < 24 and k in (0, 15): c = SB
                if y in (40, 60, 80) and 4 <= k <= 11: c = SD          # tallas del fuste
                if y in (41, 61, 81) and 4 <= k <= 11: c = SL
                lay.put(x, y, c)
            else:
                # arco: del borde de un pilar al siguiente, clave en la fila 26, arranque en la 44
                u = (k - 16 - 31.5) / 32.0
                ytop = 26 + 18 * (1 - math.sqrt(max(0.0, 1 - u * u)))
                if y < ytop:
                    lay.put(x, y, SD if y >= ytop - 1 else SB)
        for y in range(20, 24):                           # capitel
            if k in (P - 2, P - 1, 16, 17): lay.put(x, y, SB)
    for y in range(92, 100):                              # gradas del suelo
        for x in range(W):
            lay.put(x, y, SL if y in (92, 96) else SB)
    for x0 in range(22, W, 11):                           # enredaderas del dintel
        if x0 % P < 18: continue
        hang(lay, x0, 20, 6 + rnd.randrange(22), VG, VL, curl=False)
    return lay.im


def beetle_statue(lay, cx, base):
    """Estatua del escarabajo rinoceronte: peana, caparazón y el cuerno hacia arriba (silueta)."""
    for y in range(base - 8, base):
        for x in range(cx - 18, cx + 19): lay.put(x, y, RL if y == base - 8 else RB)
    lay.blob(cx + 4, base - 17, 15, RB, RL, RD, ry=10)                    # caparazón
    for y in range(base - 24, base - 8):                                  # cabeza
        for x in range(cx - 18, cx - 8):
            if (x - (cx - 13)) ** 2 / 30 + (y - (base - 15)) ** 2 / 50 <= 1: lay.put(x, y, RB)
    for i in range(18):                                                   # cuerno
        t = i / 18
        x = cx - 16 - t * 6
        y = base - 22 - i
        w = 2.5 * (1 - t) + 0.5
        for xx in range(int(x - w), int(x + w) + 1): lay.put(xx, y, RL if xx < x else RB)
    for i in range(7):                                                    # cuerno pequeño
        lay.put(cx - 7 + i // 2, base - 25 - i, RB); lay.put(cx - 6 + i // 2, base - 25 - i, RB)
    for dx in (-2, 6, 14):                                                # patas
        for y in range(base - 9, base - 7): lay.put(cx + dx, y, RD)


def temple_mid():
    lay = L(70)
    rp = profile([(3, 5, 0.3), (2, 11, 1.4)], 9)
    for x in range(W):
        y0 = int(round(70 - rp[x]))
        for y in range(y0, 70): lay.put(x, y, RL if y == y0 else RB)
    for (x0, h, w) in ((30, 34, 6), (118, 22, 5), (290, 40, 7)):           # pilares rotos
        b = int(70 - rp[x0])
        for y in range(b - h, b + 1):
            jag = (y - (b - h)) < 3 and ((y + 1) % 3) > abs(x0 % 3)
            for x in range(x0 - w, x0 + w + 1):
                if y == b - h and (x % 3 == 0): continue
                lay.put(x, y, RL if x == x0 - w else (RD if x == x0 + w else RB))
        for y in range(b - h + 8, b, 9):
            for x in range(x0 - w + 1, x0 + w): lay.put(x, y, RD)
    for (x0, w, h) in ((60, 14, 7), (165, 10, 6), (318, 12, 5)):           # sillares caídos
        b = int(70 - rp[x0 % W])
        for y in range(b - h, b + 1):
            for x in range(x0, x0 + w):
                lay.put(x, y, RL if (y == b - h or x == x0) else RB)
    # (la estatua del escarabajo, fuera: el usuario, 2026-10-28 — beetle_statue se queda por si acaso)
    for x0 in (8, 140, 250):                               # raíces que trepan
        x = float(x0)
        for y in range(69, 30, -1):
            x += math.sin(y * 0.3 + x0) * 0.6
            if lay.has(x, y) or y > 60: lay.put(x, y, RT)
    return lay.im


def temple_top():
    lay = L(70)
    tp = profile([(2, 4, 0.9), (1.5, 9, 0.2)], 12)
    for x in range(W):
        for y in range(0, int(tp[x])):
            c = RB
            if y % 6 == 5 or (x + (y // 6) * 8) % 16 == 0: c = RD        # juntas de los sillares
            if y == int(tp[x]) - 1: c = RD
            lay.put(x, y, c)
    for x0 in range(10, W, 37):                            # sillares que asoman
        b = int(tp[x0])
        for y in range(b - 1, b + 5):
            for x in range(x0, x0 + 9): lay.put(x, y, RD if y == b + 4 or x == x0 + 8 else RB)
    for x0 in range(4, W, 9):                              # raíces y enredaderas colgando
        y0 = int(tp[x0 % W])
        if rnd.random() < 0.5:
            x = float(x0)
            for i in range(10 + rnd.randrange(40)):
                x += rnd.choice((-1, 0, 0, 0, 1)) * 0.5
                lay.put(x, y0 + i, RT)
                if i < 6: lay.put(x + 1, y0 + i, RT)
        else:
            hang(lay, x0, y0, 8 + rnd.randrange(26), VG, VL)
    return lay.im


WS = 160


def temple_wall():
    """Pared lejana (160x160, se repite en las dos direcciones): sillares grandes tallados, raíces, musgo."""
    M, Bd, Lt, Sh = rgb('141c16'), rgb('1f2a22'), rgb('28342a'), rgb('1a231c')
    Mo = rgb('243820')
    im = Image.new('RGBA', (WS, WS), Bd)
    r = random.Random(21)
    glyphs = [
        ["111111", "1....1", "1.11.1", "1.1..1", "1.1111", "1....."],         # espiral
        ["..11..", ".1111.", "111111", ".1111.", "1.11.1", ".1..1."],         # escarabajo
        ["1....1", ".1..1.", "..11..", "..11..", ".1..1.", "1....1"],
        ["111111", "1....1", "1.11.1", "1.11.1", "1....1", "111111"],         # ojo
    ]
    for cy in range(WS // 16):
        off = 16 if cy % 2 else 0
        for bx in range(WS // 32):
            x0, y0 = (bx * 32 + off) % WS, cy * 16
            for y in range(16):
                for x in range(32):
                    c = Bd
                    if y == 15 or x == 31: c = M
                    elif y == 0 or x == 0: c = Lt
                    elif y == 14 or x == 30: c = Sh
                    im.putpixel(((x0 + x) % WS, (y0 + y) % WS), c)
            if r.random() < 0.4:
                gl = r.choice(glyphs)
                gx, gy = x0 + 13, y0 + 5
                for yy, row in enumerate(gl):
                    for xx, ch in enumerate(row):
                        if ch == '1':
                            im.putpixel(((gx + xx) % WS, (gy + yy) % WS), M)
                            if xx + 1 < 6 and row[xx + 1] != '1' and (yy + 1 >= 6 or gl[yy + 1][xx] != '1'):
                                im.putpixel(((gx + xx + 1) % WS, (gy + yy + 1) % WS), Lt)
            if r.random() < 0.35:                          # musgo en la cara de arriba
                for x in range(2 + r.randrange(8), 10 + r.randrange(18)):
                    im.putpixel(((x0 + x) % WS, y0 % WS), Mo)
                    if x % 3: im.putpixel(((x0 + x) % WS, (y0 + 1) % WS), Mo)
    for cx, ph in ((44, 0.0), (118, 2.1)):                 # raíces de arriba abajo (senos enteros: sin costura)
        for y in range(WS):
            x = cx + 5 * math.sin(2 * math.pi * y / WS + ph) + 2 * math.sin(2 * math.pi * 3 * y / WS)
            for dx in range(-1, 2):
                im.putpixel((int(round(x + dx)) % WS, y), rgb('3a2c1c') if dx < 0 else rgb('2a2014'))
    return im


# ══ Bloques (16x16 de arte) ═══════════════════════════════════════════════════════════════════════════════════
def grid(rows, pal):
    im = Image.new('RGBA', (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == im.width, row
        for x, ch in enumerate(row):
            if pal.get(ch): im.putpixel((x, y), pal[ch])
    return im


MUD = {'.': rgb('5a3a22'), 'd': rgb('3a2416'), 'l': rgb('7e5634')}
MUD_ROWS = [
    "................",
    "...l........ll..",
    "..dd............",
    "...........dd...",
    "......d.........",
    ".......d........",
    "........dd......",
    "..l.............",
    ".dd..........l..",
    ".............dd.",
    "..........l.....",
    ".........dd.....",
    "...ll...........",
    "...dd......d....",
    "............d...",
    "................",
]
JG = dict(MUD, L=rgb('a6d860'), g=rgb('5fb04a'), G=rgb('2f7a3a'), D=rgb('1d4a2a'))
JG_TOP = [
    "LLLLLLLLLLLLLLLL",
    "gggLggggggggLggg",
    "ggggggGgggggggGg",
    "gGgggGGggggGgggg",
    "GGgGGGGGGgGGGGgG",
    "DGDDGDDDDGDDDGDD",
    "D..D....D..D...D",
    "...D....D......D",
    "...D...........D",
]
BLADES = [
    ["..L.......L.....", ".LgL.....Lg...L.", ".gGg..L..gG..Lg.", "GgGG.gGg.GG.gGG."],
    ["......L.......L.", "..L..LgL.....gL.", ".Lg..gGg..L..gG.", ".gG.GGGG.gGg.GG."],
    ["...L........L...", "..Lg...L...LgL..", "..gG..Lg...gGg.L", ".gGG.gGG..GGGG.g"],
]
BL_PAL = {'L': rgb('a6d860'), 'g': rgb('5fb04a'), 'G': rgb('2f7a3a')}

TBK = {'M': rgb('1e2620'), 'S': rgb('3e4a3c'), 'B': rgb('5f6e58'), 'L': rgb('8a9a7c'),
       'm': rgb('4f7a26'), 'n': rgb('86b03c')}


def temple_brick():
    """64x64 (4x4 casillas: span = 4, así las tallas no se repiten cada dos bloques): hiladas de 8 de alto,
    sillares de 16, a matajuntas; 3 tallas, algo de musgo en las juntas y una grieta."""
    N = 64
    im = Image.new('RGBA', (N, N), TBK['B'])
    for row in range(N // 8):
        off = 8 if row % 2 else 0
        for b in range(N // 16 + 1):
            x0 = b * 16 - off
            for y in range(8):
                for x in range(16):
                    X = (x0 + x) % N
                    c = TBK['B']
                    if y == 7 or x == 15: c = TBK['M']
                    elif y == 0 or x == 0: c = TBK['L']
                    elif y == 6 or x == 14: c = TBK['S']
                    im.putpixel((X, row * 8 + y), c)
    # tallas (hundidas: trazo en el tono de sombra)
    spiral = ["11111", "1...1", "1.1.1", "1.111", "1...."]
    beetle = ["1...1", ".111.", "11111", ".111.", "1.1.1"]
    eye = [".111.", "1...1", "1.1.1", "1...1", ".111."]
    for (gx, gy, g) in ((5, 1, spiral), (37, 25, beetle), (13, 49, eye)):
        for yy, row in enumerate(g):
            for xx, ch in enumerate(row):
                if ch == '1': im.putpixel((gx + xx, gy + yy), TBK['S'])
    for (x, y) in ((15, 8), (16, 8), (7, 16), (8, 15), (47, 32), (48, 32), (31, 40), (56, 8), (55, 8), (23, 56)):
        im.putpixel((x, y), TBK['m'])                                                 # musgo en las juntas
    for (x, y) in ((16, 7), (8, 16), (48, 31)): im.putpixel((x, y), TBK['n'])
    for (x, y) in ((27, 10), (28, 11), (28, 12), (58, 42), (59, 43)): im.putpixel((x, y), TBK['S'])   # grietas
    return im


MOSS = {'n': rgb('86b03c'), 'm': rgb('4f7a26'), 'o': rgb('2e4a16')}
MOSS_ROWS = [
    "nnnnnnnnnnnnnnnn",
    "nmnnnnmnnnnnmnnn",
    "mmmmnmmmmmnmmmmm",
    "omommmoommmmomoo",
    ".o.om...om..o.m.",
    "...o.....o....o.",
    "...o..........o.",
] + ["................"] * 9

PLAT_A = {'L': rgb('966236'), 'B': rgb('6e4426'), 'S': rgb('4a2e1a'), 'O': rgb('2a1a10'),
          'g': rgb('5fb04a'), 'G': rgb('2f7a3a'), 'v': rgb('1d4a2a')}
PLAT_A_ROWS = [
    "LLLLLLLLLLLgLLLL",
    "BBBBBBSLBBGgGBBB",
    "BBBBBBSLBBgGgBBB",
    "BBSBBBSLBBGgGBBB",
    "SSSSSSSSSSgGgSSS",
    "OOOOOOOOOOvGvOOO",
    "...........G....",
    "..........GGv...",
    "...........v....",
] + ["................"] * 7
PLAT_B = {'L': rgb('dccc78'), 'B': rgb('b4a248'), 'S': rgb('7e7028'), 'O': rgb('4a4216'),
          'r': rgb('c8a868'), 'R': rgb('8a6a3a')}
PLAT_B_ROWS = [
    "LLLLLOLLLLLrRLLL",
    "BBBBBOBBBBBRrBBB",
    "SSSSSOSSSSSrRSSS",
    "LLLLLLLLOLLRrLLL",
    "BBBBBBBBOBBrRBBB",
    "OOOOOOOOOOORrOOO",
    "...........R....",
] + ["................"] * 9


def tiles():
    mud = grid(MUD_ROWS, MUD)
    jg = mud.copy()
    top = grid(JG_TOP, JG)
    for y in range(len(JG_TOP)):
        for x in range(16):
            p = top.getpixel((x, y))
            if p[3] and not (y >= 6 and JG_TOP[y][x] == '.'): jg.putpixel((x, y), p)
    blades = Image.new('RGBA', (48, 4), (0, 0, 0, 0))
    for i, rows in enumerate(BLADES): blades.paste(grid(rows, BL_PAL), (i * 16, 0))
    return {'mud': mud, 'jungle_grass': jg, 'jungle_blades': blades, 'temple_brick': temple_brick(),
            'temple_moss': grid(MOSS_ROWS, MOSS), 'jungle_platform': grid(PLAT_A_ROWS, PLAT_A),
            'jungle_platform_b': grid(PLAT_B_ROWS, PLAT_B)}


# ══ Vista previa: el fondo como lo compone Sky.lua + bloques delante ════════════════════════════════════════════
WIN_W, WIN_H = 1280, 720
TIMES = {'day': (1, 1, 1), 'dusk': (1, 0.8, 0.72), 'night': (0.42, 0.48, 0.72)}
GAME_SKY = 'assets/images/world/sky'


def up(im, k=S): return im.resize((im.width * k, im.height * k), Image.NEAREST)


def tint(im, t):
    a = np.array(im).astype(np.float32)
    a[..., 0] *= t[0]; a[..., 1] *= t[1]; a[..., 2] *= t[2]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def alpha_mul(im, k):
    a = np.array(im).astype(np.float32); a[..., 3] *= k
    return Image.fromarray(a.astype(np.uint8))


def tile_x(canvas, im, camX, p, y):
    """Repite la capa a lo ancho con su paralaje (como drawLayers)."""
    w = im.width
    x = -int((camX * p) % w)
    while x < canvas.width:
        canvas.alpha_composite(im, (x, y)) if y >= 0 else canvas.alpha_composite(im.crop((0, -y, w, im.height)), (x, 0))
        x += w


def fill_rect(canvas, box, col):
    d = ImageDraw.Draw(canvas)
    d.rectangle(box, fill=col)


def edge_col(im, top):
    """Color de la fila del borde (centro), como Sky.lua."""
    return im.getpixel((im.width // 2, 0 if top else im.height - 1))


def draw_layer(canvas, im1x, p, camX, y, t, top=False):
    lay = tint(up(im1x), t)
    tile_x(canvas, lay, camX, p, y)
    c = edge_col(lay, top)
    if c[3] > 0:
        if top and y > 0: fill_rect(canvas, (0, 0, WIN_W, y - 1), c)
        if not top and y + lay.height < WIN_H: fill_rect(canvas, (0, y + lay.height, WIN_W, WIN_H), c)


def sky_base(time, grads):
    g = up(grads['jungle_' + time], 1).resize((WIN_W, WIN_H), Image.NEAREST)
    canvas = Image.new('RGBA', (WIN_W, WIN_H)); canvas.alpha_composite(g)
    t = TIMES[time]
    if time == 'night':
        st = Image.open(os.path.join(GAME_SKY, 'stars.png')).convert('RGBA')
        for i in range(1, 71):
            v = math.sin(i * 12.9898) * 43758.5453; u = math.sin(i * 78.233) * 12345.678
            sx, sy, f = v - math.floor(v), (u - math.floor(u)) * 0.62, i % 3 + 1
            fr = alpha_mul(st.crop(((f - 1) * 3, 0, f * 3, 3)), 0.85).resize((9, 9), Image.NEAREST)
            canvas.alpha_composite(fr, (int(sx * WIN_W) % WIN_W, int(sy * WIN_H)))
        canvas.alpha_composite(up(Image.open(os.path.join(GAME_SKY, 'moon.png')).convert('RGBA')), (int(WIN_W * 0.78), 70))
    else:
        sun = up(Image.open(os.path.join(GAME_SKY, 'sun.png')).convert('RGBA'))
        if time == 'dusk': canvas.alpha_composite(tint(sun, (1, 0.75, 0.55)), (int(WIN_W * 0.8), 330))
        else: canvas.alpha_composite(sun, (int(WIN_W * 0.76), 60))
    cl = Image.open(os.path.join(GAME_SKY, 'clouds.png')).convert('RGBA')
    for (cx, cy, v) in ((0.05, 70, 1), (0.32, 140, 2), (0.58, 95, 3), (0.81, 180, 1)):
        c = alpha_mul(tint(up(cl.crop(((v - 1) * 48, 0, v * 48, 16))), t), 0.7 if time == 'night' else 0.95)
        canvas.alpha_composite(c, (int(cx * WIN_W), cy))
    return canvas


# ── Bloques dibujados como en el juego (bordes de 2 px solo en las caras al aire) ─────────────────────────────────
EDGE = {'jg': (158, 115, 72), 'mud': (158, 115, 72), 'tb': (138, 154, 124)}
CAPE = {'jg': (166, 216, 96), 'tb': (134, 176, 60)}
GROUND = {'jg', 'mud', 'tb'}


def draw_scene(canvas, grid_, T, oy=0, tint_=(1, 1, 1)):
    """grid_: filas de nombres ('jg', 'mud', 'tb', 'pa', 'pb', None). oy = y de pantalla de la fila 0."""
    R, C = len(grid_), len(grid_[0])
    k = 64
    tex = {n: up(T[n]) for n in T}
    at = lambda r, c: grid_[r][c] if 0 <= r < R and 0 <= c < C else ('edge' if r >= R or c < 0 or c >= C else None)
    for r in range(R):
        for c in range(C):
            n = grid_[r][c]
            if not n: continue
            x, y = c * k, oy + r * k
            if n in ('pa', 'pb'):
                canvas.alpha_composite(tex['jungle_platform' if n == 'pa' else 'jungle_platform_b'], (x, y))
                continue
            nb = {d: at(r + dr, c + dc) for d, (dr, dc) in
                  {'top': (-1, 0), 'bottom': (1, 0), 'left': (0, -1), 'right': (0, 1)}.items()}
            e = {d: not (v in GROUND or v == 'edge') for d, v in nb.items()}
            if n == 'tb':
                big = tex['temple_brick']
                q = big.crop(((c % 4) * 64, (r % 4) * 64, (c % 4) * 64 + 64, (r % 4) * 64 + 64))
                canvas.alpha_composite(q, (x, y))
                if e['top']: canvas.alpha_composite(tex['temple_moss'], (x, y))
            else:
                canvas.alpha_composite(tex['jungle_grass' if (n == 'jg' and e['top']) else 'mud'], (x, y))
            d = ImageDraw.Draw(canvas)
            col = EDGE[n]
            noTop = n in ('jg', 'tb') and e['top']
            if e['top'] and not noTop: d.rectangle((x, y, x + k - 1, y + 1), fill=col)
            if e['bottom']: d.rectangle((x, y + k - 2, x + k - 1, y + k - 1), fill=col)
            if e['left']: d.rectangle((x, y, x + 1, y + k - 1), fill=col)
            if e['right']: d.rectangle((x + k - 2, y, x + k - 1, y + k - 1), fill=col)
            if noTop:
                cap = 24 if n == 'jg' else 12
                if e['left']: d.rectangle((x, y, x + 1, y + cap - 1), fill=CAPE[n])
                if e['right']: d.rectangle((x + k - 2, y, x + k - 1, y + cap - 1), fill=CAPE[n])
            if n == 'jg' and e['top']:
                v = (c * 5 + r * 3) % 3
                bl = tex['jungle_blades'].crop((v * 64, 0, v * 64 + 64, 16))
                canvas.alpha_composite(bl, (x, y - 16))


def player(canvas, x, y_feet):
    p = Image.open('assets/images/player/monstrito1.png').convert('RGBA')
    p = up(p, 6)
    canvas.alpha_composite(p, (x, y_feet - p.height))


SURF_SCENE = [  # 20 x 12 casillas (la fila 0 empieza 48 px por encima de la pantalla: 12 * 64 = 768)
    [None] * 20,
    [None] * 20,
    [None] * 20,
    [None] * 20,
    [None] * 12 + ['pa'] * 3 + [None] * 5,
    [None] * 15 + ['tb'] * 4 + [None],
    [None] * 2 + ['pa'] * 4 + [None] * 9 + ['tb'] * 4 + [None],
    [None] * 15 + ['tb'] * 4 + [None],
    [None] * 9 + ['jg'] * 2 + [None] * 4 + ['tb'] * 4 + [None],
    [None] * 6 + ['jg'] * 3 + ['mud'] * 2 + [None] * 2 + ['jg'] * 2 + ['tb'] * 4 + ['jg'],
    ['jg'] * 6 + ['mud'] * 5 + [None] * 2 + ['mud'] * 7,
    ['mud'] * 11 + [None] * 2 + ['mud'] * 7,
]

TEMPLE_SCENE = [
    [None] * 20,
    [None] * 20,
    [None] * 20,
    [None] * 20,
    [None] * 20,
    [None] * 20,
    ['tb'] * 3 + [None] * 4 + ['pb'] * 3 + [None] * 6 + ['tb'] * 4,
    ['tb'] * 3 + [None] * 13 + ['tb'] * 4,
    ['tb'] * 3 + [None] * 13 + ['tb'] * 4,
    ['tb'] * 4 + [None] * 3 + ['tb'] * 2 + [None] * 4 + ['tb'] * 7,
    ['tb'] * 4 + ['mud'] * 3 + ['tb'] * 2 + [None] * 4 + ['tb'] * 7,
    ['tb'] * 20,
]


def render_surface(time, layers, grads, T, camX=900, scene=True):
    t = TIMES[time]
    cv = sky_base(time, grads)
    for name, p in (('far', 0.08), ('mid', 0.2), ('near', 0.38)):
        im = layers['jungle_' + name]
        draw_layer(cv, im, p, camX, WIN_H - im.height * S, t)
    draw_layer(cv, layers['jungle_top'], 0.42, camX, int(-48 * 0.42), t, top=True)
    if scene:
        draw_scene(cv, SURF_SCENE, T, oy=-48)
        player(cv, 2 * 64 + 5, 10 * 64 - 48)
    return cv


def render_temple(layers, grads, T, camX=900):
    """Corte superficie → templo como en Sky.render con profundidad: el paisaje se apoya en la línea B, franja
    de suelo + tramado, degradado del templo, pared, techo colgando de la franja y escombros en el fondo."""
    t = TIMES['day']
    cv = sky_base('day', grads)
    restY, B = int(WIN_H * 0.78), 170
    pv = lambda p: 0.7 + 0.4 * p
    D = (B - restY) / pv(0.38)
    for name, p in (('far', 0.08), ('mid', 0.2), ('near', 0.38)):
        im = layers['jungle_' + name]
        y = int(restY + D * pv(p)) - im.height * S
        lay = tint(up(im), t); tile_x(cv, lay, camX, p, y)
    soil = edge_col(layers['jungle_near'], False)
    d0 = B + 24
    under = Image.new('RGBA', (WIN_W, WIN_H - B))
    g = up(grads['temple'], 1).resize((WIN_W, int(WIN_H * 1.4)), Image.NEAREST)
    under.alpha_composite(g.crop((0, 0, WIN_W, WIN_H - B - 24)), (0, 24))
    wall = alpha_mul(up(layers['temple_wall']), 0.9)
    oy = 24 + 32 - (int(300 * 0.18) % wall.height) - wall.height
    ox = -int((camX * 0.18) % wall.width)
    yy = oy
    while yy < under.height:
        xx = ox
        while xx < WIN_W: under.alpha_composite(wall, (xx, yy)) if yy >= 0 else under.alpha_composite(wall.crop((0, -yy, wall.width, wall.height)), (xx, 0)); xx += wall.width
        yy += wall.height
    for name, p in (('far', 0.12), ('mid', 0.28)):
        im = up(layers['temple_' + name])
        y = max(24 + 40, under.height - im.height)
        tile_x(under, im, camX, p, y)
    tile_x(under, up(layers['temple_top']), camX, 0.2, 24 + 16)
    fill_rect(under, (0, 0, WIN_W, 23), soil)
    bl = Image.open(os.path.join(GAME_SKY, 'blend.png')).convert('RGBA')
    a = np.array(bl); a[..., 0], a[..., 1], a[..., 2] = soil[0], soil[1], soil[2]
    tile_x(under, up(Image.fromarray(a)), camX, 0.38, 24)
    cv.alpha_composite(under, (0, B))
    draw_scene(cv, TEMPLE_SCENE, T, oy=-48)
    player(cv, 5 * 64 + 5, 10 * 64 - 48)
    return cv


def label(im, text, xy, size=16, col=(255, 255, 255, 255)):
    d = ImageDraw.Draw(im)
    try: f = ImageFont.truetype('assets/fonts/PressStart2P.ttf', size)
    except OSError: f = ImageFont.load_default()
    x, y = xy
    d.text((x + 2, y + 2), text, font=f, fill=(0, 0, 0, 255))
    d.text((x, y), text, font=f, fill=col)


def tile_sheet(T, layers, grads):
    """Cada bloque en un grupo de 4x3 (con los bordes del juego), las texturas sueltas a x4 y las capas del
    fondo a x2 sobre su degradado."""
    out = Image.new('RGBA', (2560, 1000), rgb('20242a'))
    groups = [('jungle_grass', [['jg'] * 4] * 3), ('mud', [['mud'] * 4] * 3),
              ('temple_brick+moss', [['tb'] * 4] * 3)]
    x = 40
    for name, g in groups:
        sub = Image.new('RGBA', (4 * 64, 3 * 64 + 16), (0, 0, 0, 0))
        draw_scene(sub, g, T, oy=16)
        out.alpha_composite(sub, (x, 60))
        label(out, name, (x, 24), 12)
        x += 4 * 64 + 50
    for i, (name, n) in enumerate((('plataforma A', 'pa'), ('plataforma B', 'pb'))):
        sub = Image.new('RGBA', (4 * 64, 64), (0, 0, 0, 0))
        draw_scene(sub, [[n] * 4], T)
        out.alpha_composite(sub, (x, 76 + i * 110))
        label(out, name, (x, 40 + i * 110), 12)
    x += 4 * 64 + 50
    label(out, 'texturas a x4 (1 casilla = 64 px):', (x, 24), 12)
    y = 60
    for n in ('jungle_grass', 'mud', 'temple_moss', 'jungle_platform', 'jungle_platform_b', 'temple_brick'):
        im = up(T[n])
        out.alpha_composite(im, (x, y))
        label(out, n.replace('jungle_', 'j_'), (x, y + im.height + 8), 8)
        x += im.width + 40
    out.alpha_composite(up(T['jungle_blades']), (1280 - 26, 170))
    label(out, 'jungle_blades (3 variantes)', (1280 - 26, 196), 8)
    # capas a x2 sobre el degradado de su bioma
    y = 320
    label(out, 'capas a x2: jungle (far, mid, near, top) y temple (far, mid, top, wall)', (40, y - 30), 12)
    for row, (gname, names) in enumerate((('jungle_day', ('jungle_far', 'jungle_mid', 'jungle_near', 'jungle_top')),
                                          ('temple', ('temple_far', 'temple_mid', 'temple_top', 'temple_wall')))):
        x = 40
        yy = y + row * 340
        for n in names:
            im = up(layers[n], 2)
            bg = grads[gname].resize((im.width, 300), Image.NEAREST)
            out.alpha_composite(bg, (x, yy))
            out.alpha_composite(im, (x, yy + (0 if n.endswith('_top') or n.endswith('_wall') else 300 - im.height)))
            x += im.width + 20
    return out


def main():
    os.makedirs(os.path.join(PREV, 'capas'), exist_ok=True)
    grads = {k: grad_frame(v) for k, v in GRADS.items()}
    layers = {'jungle_far': jungle_far(), 'jungle_mid': jungle_mid(), 'jungle_near': jungle_near(),
              'jungle_top': jungle_top(), 'temple_far': temple_far(), 'temple_mid': temple_mid(),
              'temple_top': temple_top(), 'temple_wall': temple_wall()}
    T = tiles()
    gstrip = Image.new('RGBA', (8 * len(grads), 180))
    for i, k in enumerate(grads): gstrip.paste(grads[k], (i * 8, 0))
    for n, im in list(layers.items()) + [('jungle_gradients', gstrip)]:
        im.save(os.path.join(PREV, 'capas', n + '.png'))
    for n, im in T.items():
        im.save(os.path.join(PREV, 'capas', 'tile_' + n + '.png'))
    shots = {}
    for tm in ('day', 'dusk', 'night'):
        shots[tm] = render_surface(tm, layers, grads, T)
        shots[tm].save(os.path.join(PREV, 'superficie_%s.png' % tm))
    shots['temple'] = render_temple(layers, grads, T)
    shots['temple'].save(os.path.join(PREV, 'templo.png'))
    sheet = tile_sheet(T, layers, grads)
    sheet.save(os.path.join(PREV, 'bloques.png'))
    out = Image.new('RGBA', (2560, 1440 + 1000 + 60), rgb('20242a'))
    out.paste(shots['day'], (0, 0)); out.paste(shots['dusk'], (1280, 0))
    out.paste(shots['night'], (0, 720)); out.paste(shots['temple'], (1280, 720))
    for (tx, ty, s) in ((0, 0, 'jungle - dia'), (1280, 0, 'jungle - atardecer'), (0, 720, 'jungle - noche'),
                        (1280, 720, 'superficie -> profundidad temple')):
        label(out, s, (tx + 16, ty + 16), 16)
    out.alpha_composite(sheet, (0, 1440 + 60))
    out.convert('RGB').save(os.path.join(PREV, 'vista_previa.png'))
    print('vista previa:', os.path.join(PREV, 'vista_previa.png'))
    if APPLY: apply(layers, grads, T)


def apply(layers, grads, T):
    """Escribe los archivos del juego (no pisa nada que exista)."""
    def put(path, im):
        if os.path.exists(path): print('  %s ya existe: no se toca' % path); return
        im.save(path); print('  %-48s %dx%d' % (path, im.width, im.height))
    for n, im in layers.items(): put(os.path.join(SKY, n + '.png'), im)
    gp = os.path.join(SKY, 'gradients.png')
    g = Image.open(gp).convert('RGBA')
    if g.width == 80:                                     # cuadros 11..14: jungle_day, jungle_dusk, jungle_night, temple
        ng = Image.new('RGBA', (80 + 8 * len(grads), 180)); ng.paste(g, (0, 0))
        for i, k in enumerate(grads): ng.paste(grads[k], (80 + i * 8, 0))
        ng.save(gp); print('  %s: +%d cuadros' % (gp, len(grads)))
    else:
        print('  %s ya tiene %d cuadros: no se toca' % (gp, g.width // 8))
    # (plataforma: la A — tablones atados con liana — elegida por el usuario; la B, bambú, solo en la vista previa)
    for n, im in T.items():
        if n != 'jungle_platform_b': put(os.path.join(TIL, n + '.png'), up(im))


if __name__ == '__main__':
    main()
