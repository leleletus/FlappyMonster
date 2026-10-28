#!/usr/bin/env python3
# tools/art/world/make_jungle_decor.py
# Decoraciones de la ISLA DE LA SELVA (conjunto `jungle_set`, aprobado 2026-10-28 sin la rana, el tucán ni el mono): selva tropical densa y ruinas de
# un templo de piedra cubierto de musgo. Mismo estilo que make_biome_art.py (Canvas por partes: máscara + paleta de
# 4 tonos, contorno = el tono más oscuro de SU color, nunca negro; luz arriba-izquierda, sin ruido, 1 px de margen
# con el contorno cerrado). Arte a 1x; el juego lo dibuja a x4 (1 casilla = 16 px de arte).
#
# Por defecto SOLO hace la vista previa (fuera del repo):
#     /home/mtvemo/FlappyMonster_pruebas/selva/decoraciones/vista_previa.png   catálogo a x4 con su nombre
#     /home/mtvemo/FlappyMonster_pruebas/selva/decoraciones/maqueta.gif        escena con lo que se anima
#     /home/mtvemo/FlappyMonster_pruebas/selva/decoraciones/sprites/           cada sprite a 1x
# --apply escribe los sprites en assets/images/world/decorations/jungle/ (y las partículas en .../fx/); no pisa
# lo que ya exista (--force para rehacerlo). Desde la raíz del repo:
#     ~/.venvs/fm-music/bin/python tools/art/world/make_jungle_decor.py [--apply [--force]]
import os, sys, math, random
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]          # (make_biome_art lee sys.argv al importarse)
from make_biome_art import Canvas as _Canvas, pad, strip, ell, wobbly, rgb
sys.argv = _argv


class Canvas(_Canvas):
    """el Canvas de make_biome_art con UNA diferencia: el contorno solo va donde la parte da al vacío o a una parte
    que tiene DETRÁS; donde la tapa otra de delante, su borde es su tono de sombra (la de delante lleva su contorno).
    Así las piezas pequeñas no se quedan en puro contorno y se lee qué va delante."""
    def image(self):
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        P = self.px
        same = lambda x, y, p: 0 <= x < self.w and 0 <= y < self.h and P[y][x] == p
        at = lambda x, y: P[y][x] if 0 <= x < self.w and 0 <= y < self.h else None
        box = {}
        for y in range(self.h):
            for x in range(self.w):
                p = P[y][x]
                if p is None: continue
                b = box.setdefault(p, [x, y, x, y])
                b[0], b[1], b[2], b[3] = min(b[0], x), min(b[1], y), max(b[2], x), max(b[3], y)
        for y in range(self.h):
            for x in range(self.w):
                p = P[y][x]
                if p is None: continue
                (out, dark, mid, light), k = self.pals[p]
                x0, y0, x1, y1 = box[p]
                nb = [at(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                if any(q is None or (q != p and q < p) for q in nb):
                    c = out
                elif any(q != p for q in nb):
                    c = dark
                else:
                    u = ((x - x0) / max(1, x1 - x0) - 0.5) * 1.2 + ((y - y0) / max(1, y1 - y0) - 0.5) * 0.8
                    c = mid
                    if u > k: c = dark
                    if not same(x, y - 1, p) or not same(x, y - 2, p) and (x - x0) < (x1 - x0) * 0.6: c = light
                    elif not same(x - 1, y, p) and u < 0.2: c = light
                im.putpixel((x, y), c)
        for x, y, col in self.dots:
            if 0 <= x < self.w and 0 <= y < self.h and P[y][x] is not None: im.putpixel((x, y), col)
        return im

APPLY = '--apply' in sys.argv
FORCE = '--force' in sys.argv
PREV = '/home/mtvemo/FlappyMonster_pruebas/selva/decoraciones'
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
DEST = os.path.join(REPO, 'assets/images/world/decorations/jungle')
DEST_FX = os.path.join(REPO, 'assets/images/world/decorations/fx')

# ── Paletas (contorno, sombra, medio, luz) ────────────────────────────────────
LEAF = (rgb('0f2a1a'), rgb('1d4a2a'), rgb('2f7a3a'), rgb('5fb04a'))
LEAF_BK = (rgb('0b2016'), rgb('143a22'), rgb('1d4a2a'), rgb('2f6a36'))       # hojas de atrás (profundidad)
LEAF_LT = (rgb('1a3a14'), rgb('3e7a2a'), rgb('5fb04a'), rgb('a6d860'))       # platanera, brotes
HI = rgb('a6d860')
TRUNK = (rgb('2a1a10'), rgb('4a2e1a'), rgb('6e4426'), rgb('966236'))
KAPOK = (rgb('2a2420'), rgb('4e463a'), rgb('72684f'), rgb('9a8f70'))         # corteza clara de la ceiba
KAPOK_BK = (rgb('211c18'), rgb('3a342c'), rgb('544c3e'), rgb('6e6450'))
HOLLOW = (rgb('120c08'), rgb('1e140c'), rgb('2a1c10'), rgb('3a2816'))
STONE = (rgb('1e2620'), rgb('3e4a3c'), rgb('5f6e58'), rgb('8a9a7c'))
STONE_BK = (rgb('181e1a'), rgb('2e382e'), rgb('465242'), rgb('5f6e58'))
MOSS = (rgb('23401a'), rgb('4f7a26'), rgb('6a9630'), rgb('86b03c'))
MOSS_HI = rgb('b0d060')
MUD = (rgb('2a180e'), rgb('3a2416'), rgb('5a3a22'), rgb('7e5634'))
VINE = (rgb('1e2a10'), rgb('3a4a1c'), rgb('566a28'), rgb('7a8e36'))
STEM = (rgb('2a3a14'), rgb('4f6a26'), rgb('7a9a3a'), rgb('a6c860'))
GREYMOSS = (rgb('243426'), rgb('46624a'), rgb('6a8a62'), rgb('94b484'))
MAGENTA = (rgb('5a1030'), rgb('8a1e50'), rgb('d0407a'), rgb('f07aa8'))
ORANGE = (rgb('6a2a08'), rgb('b05010'), rgb('f08a24'), rgb('f8b860'))
YELLOW = (rgb('6a4a08'), rgb('b08a10'), rgb('f4d03a'), rgb('fff07a'))
TEAL = (rgb('0e3a38'), rgb('1a706a'), rgb('2fb0a0'), rgb('7ee0cc'))
RED = (rgb('5a0e10'), rgb('a01e1e'), rgb('d8322c'), rgb('f05a48'))
PURPLE = (rgb('2e1040'), rgb('5a2a80'), rgb('8a4ab8'), rgb('c08ae0'))
WHITE = (rgb('7a7a8a'), rgb('c8c8d4'), rgb('ececf4'), rgb('ffffff'))
BLACKF = (rgb('0c0c14'), rgb('1a1a26'), rgb('282838'), rgb('44445c'))      # plumas negras (tucán)
BLUEF = (rgb('0a1e4a'), rgb('1a46a0'), rgb('2f78e0'), rgb('7ab8ff'))        # rana flecha azul
FUR = (rgb('24140a'), rgb('42281a'), rgb('624028'), rgb('86603c'))
SKIN = (rgb('5a3a26'), rgb('9a6a48'), rgb('c49470'), rgb('e6bc94'))
FIRE_OUT = (rgb('7a160a'), rgb('d03a12'), rgb('ec5a18'), rgb('f87a22'))
FIRE_MID = (rgb('f07a1e'), rgb('f8902a'), rgb('ffa632'), rgb('ffc04a'))
FIRE_IN = (rgb('ffc040'), rgb('ffd858'), rgb('ffea80'), rgb('fff8c8'))
GLOW_T = rgb('7ef0e0')
GLOW_T2 = rgb('d8fff8')


# ── Formas ────────────────────────────────────────────────────────────────────
def rell(cx, cy, rx, ry, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    def f(x, y):
        dx, dy = x + 0.5 - cx, y + 0.5 - cy
        u, v = dx * ca + dy * sa, -dx * sa + dy * ca
        return (u / rx) ** 2 + (v / ry) ** 2 <= 1
    return f


def stroke(path, width, n=None):
    """píxeles a menos de width(t) del punto path(t), t en [0,1] (hojas, ramas, lianas)"""
    pts = set()
    n = n or 160
    for i in range(n + 1):
        t = i / n
        cx, cy = path(t)
        r = width(t)
        pts.add((int(math.floor(cx)), int(math.floor(cy))))
        ri = int(math.ceil(r)) + 1
        for yy in range(int(cy) - ri, int(cy) + ri + 1):
            for xx in range(int(cx) - ri, int(cx) + ri + 1):
                if (xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 <= r * r: pts.add((xx, yy))
    return pts


def arc(x0, y0, ang_deg, length, droop=0.0, bend=0.0):
    """camino: sale de (x0,y0) con ese ángulo (0 = derecha, -90 = arriba), cae `droop` (gravedad) y se curva `bend`"""
    a = math.radians(ang_deg)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    def p(t):
        return (x0 + dx * length * t + nx * bend * length * t * t,
                y0 + dy * length * t + nx * 0 + ny * bend * length * t * t + droop * length * t * t)
    return p


def line(x0, y0, x1, y1):
    return lambda t: (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)


def m(pts): return lambda x, y: (x, y) in pts


def U(*fs): return lambda x, y: any(f(x, y) for f in fs)


def minus(f, g): return lambda x, y: f(x, y) and not g(x, y)


def poly(pts):
    def f(x, y):
        px, py = x + 0.5, y + 0.5
        inside = False
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]; xj, yj = pts[j]
            if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi: inside = not inside
            j = i
        return inside
    return f


def leaf_pts(x0, y0, ang, L, W, droop=0.0, bend=0.0, blunt=False, slits=()):
    """hoja: ancho que crece desde el tallo y acaba en punta (o roma); slits = cortes desde el borde (platanera)"""
    p = arc(x0, y0, ang, L, droop, bend)
    if blunt: w = lambda t: W * min(1, t * 3.2) * (1 - t ** 5) ** 0.5 + 0.3
    else: w = lambda t: W * math.sin(math.pi * min(1, t * 0.95 + 0.04)) ** 0.75 + 0.2
    pts = stroke(p, w)
    for (ts, side) in slits:                     # corte fino perpendicular al nervio, del borde hacia dentro
        cx, cy = p(ts); cx2, cy2 = p(min(1, ts + 0.02))
        dx, dy = cx2 - cx, cy2 - cy
        d = math.hypot(dx, dy) or 1
        nx, ny = -dy / d * side, dx / d * side
        for k in range(int(W * 0.45 * 4), int(W * 1.6 * 4)):
            q = (int(math.floor(cx + nx * k / 4)), int(math.floor(cy + ny * k / 4)))
            pts.discard(q)
    return pts, p


def midrib(c, p, col, t0=0.15, t1=0.85, n=12):
    for i in range(n + 1):
        x, y = p(t0 + (t1 - t0) * i / n)
        c.dot(int(x), int(y), col)


def hl(c, pts, col=HI):
    for x, y in pts: c.dot(x, y, col)


# ══ GRANDES ═══════════════════════════════════════════════════════════════════
def ceiba():
    """Ceiba gigante (56x128, 8 casillas): tronco claro con contrafuertes, ramas y copa en pisos. Dos capas del
    mismo tamaño: 'trunk' y 'canopy' (la copa se mece, el tronco no)."""
    W, H = 56, 128
    t = Canvas(W, H)
    cx = 28
    # contrafuertes de atrás (más oscuros)
    def fin(xe, yj, side, ground=H):
        def f(x, y):
            if side < 0 and not (xe <= x <= cx): return False
            if side > 0 and not (cx <= x <= xe): return False
            k = abs(x + 0.5 - xe) / abs(cx - xe)
            top = ground - (ground - yj) * k ** 1.9
            return y >= top
        return f
    t.part(fin(4, 92, -1), KAPOK_BK, 0.1)
    t.part(fin(52, 90, 1), KAPOK_BK, 0.1)
    # tronco
    t.part(lambda x, y: 34 <= y and abs(x + 0.5 - cx) <= 4.4 + max(0, y - 70) * 0.04 + max(0, y - 104) * 0.25, KAPOK, 0.1)
    # contrafuertes de delante
    t.part(fin(11, 100, -1), KAPOK, 0.25)
    t.part(fin(46, 98, 1), KAPOK, 0.25)
    t.part(fin(21, 110, -1), KAPOK, 0.4)
    # ramas
    for (pth, w0, w1) in ((arc(cx - 1, 50, -150, 22, 0, 0.35), 2.2, 1.0), (arc(cx + 1, 44, -30, 22, 0, -0.3), 2.2, 1.0),
                          (arc(cx, 40, -92, 26, 0, 0.0), 2.6, 1.2), (arc(cx - 1, 40, -120, 16, 0, 0.2), 1.6, 0.8),
                          (arc(cx + 1, 38, -62, 16, 0, -0.1), 1.6, 0.8)):
        t.part(m(stroke(pth, lambda s, a=w0, b=w1: a + (b - a) * s)), KAPOK, 0.2)
    # corteza: vetas verticales y musgo
    for (x, y0, n) in ((26, 52, 9), (30, 66, 8), (27, 80, 7), (30, 92, 6), (25, 104, 5)):
        for y in range(y0, y0 + n): t.dot(x, y, KAPOK[1])
    for (x, y) in ((25, 60), (26, 61), (25, 62), (31, 75), (30, 76), (15, 117), (16, 116), (40, 112), (41, 113)):
        t.dot(x, y, MOSS[2])
    trunk = t.image()

    c = Canvas(W, H)
    # copa: pisos planos (atrás oscuros, delante claros); cada bulto su parte
    back = ((8, 33, 8, 5), (48, 29, 8, 5), (12, 18, 10, 7), (44, 16, 10, 7), (20, 9, 11, 7), (37, 8, 11, 7),
            (28, 22, 14, 6))
    for (x, y, rx, ry) in back:
        c.part(wobbly(x, y, rx, ry, 0.1, x * 0.7), LEAF_BK, 0.2)
    front = ((10, 36, 7.5, 4), (46, 32, 7.5, 4), (8, 22, 7.5, 5), (48, 21, 7.5, 5), (17, 13, 8.5, 6),
             (39, 12, 8.5, 6), (28, 6, 9, 5.5), (21, 22, 9, 5), (35, 21, 9, 5), (28, 15, 8, 5))
    for (x, y, rx, ry) in front:
        c.part(wobbly(x, y, rx, ry, 0.12, x * 1.3 + y), LEAF, 0.2)
    for (x, y) in ((13, 9), (14, 9), (12, 10), (24, 3), (25, 3), (26, 4), (35, 8), (36, 8), (17, 18), (18, 18), (4, 19),
                   (5, 19), (44, 18), (45, 18), (6, 33), (7, 33), (42, 29), (43, 29), (25, 12), (26, 12), (31, 18), (32, 18)):
        c.dot(x, y, HI)
    for (x, y) in ((24, 25), (30, 24), (40, 24), (12, 26), (51, 24), (13, 39), (48, 35), (20, 16), (42, 15)):
        c.dot(x, y, LEAF[0])
    # lianas que cuelgan de la copa
    for (x0, y0, L, ph) in ((5, 38, 30, 0.0), (51, 34, 26, 1.0), (17, 23, 18, 2.0)):
        pts = stroke(lambda s, x0=x0, y0=y0, L=L, ph=ph: (x0 + 1.0 * math.sin(s * 5 + ph), y0 + L * s), lambda s: 0.6)
        c.part(m(pts), VINE, 0.5)
        for k in range(3, L, 7): c.dot(int(x0 + 1.0 * math.sin(k / L * 5 + ph)) + 1, y0 + k, LEAF[3])
    # bromelias rojas en las ramas
    for (x, y) in ((14, 40), (44, 35)):
        c.part(lambda xx, yy, x=x, y=y: abs(xx - x) + max(0, y - yy) <= 2 and yy <= y and yy >= y - 2, RED, 0.5)
    canopy = c.image()
    return {'trunk': trunk, 'canopy': canopy}


def strangler_fig():
    """Higuera estranguladora (40x96, 6 casillas): tronco hecho de raíces trenzadas alrededor de un hueco oscuro,
    raíces aéreas y copa redonda y densa. Capas 'trunk' y 'canopy'."""
    W, H = 40, 96
    t = Canvas(W, H)
    cx = 20
    t.part(lambda x, y: 30 <= y and abs(x + 0.5 - cx) <= 4.5 + max(0, y - 80) * 0.5, HOLLOW, 0.6)
    strands = ((-5, 0.0, 1.2), (-2, 1.7, 1.1), (2, 3.1, 1.1), (5, 4.6, 1.2), (0, 2.4, 1.0))
    for i, (off, ph, wd) in enumerate(strands):
        def path(s, off=off, ph=ph):
            y = 30 + (H - 30) * s
            spread = 1 + max(0, s - 0.75) * 7
            return (cx + off * spread * 0.9 + 2.6 * math.sin(s * 9 + ph), y)
        t.part(m(stroke(path, lambda s, wd=wd: wd + s * 0.6)), TRUNK, 0.3)
    # raíces del pie
    for (ang, L) in ((-170, 9), (-10, 9), (-160, 6), (-20, 6)):
        t.part(m(stroke(arc(cx + (-3 if ang < -90 else 3), H - 4, ang, L, 0.5), lambda s: 1.6 - s)), TRUNK, 0.3)
    for (x, y) in ((17, 50), (23, 62), (16, 74), (22, 40)): t.dot(x, y, MOSS[2])
    trunk = t.image()

    c = Canvas(W, H)
    for (x, y, rx, ry) in ((8, 22, 8, 7), (32, 20, 8, 7.5), (20, 10, 12, 9)):
        c.part(wobbly(x, y, rx, ry, 0.12, x), LEAF_BK, 0.2)
    for (x, y, rx, ry) in ((10, 26, 7, 5.5), (30, 26, 7.5, 5.5), (14, 15, 8, 6.5), (27, 13, 8.5, 7), (20, 24, 7, 5)):
        c.part(wobbly(x, y, rx, ry, 0.14, x * 0.9 + y), LEAF, 0.2)
    for (x, y) in ((9, 21), (10, 21), (12, 10), (13, 10), (22, 7), (23, 7), (24, 8), (17, 19), (18, 19), (5, 24)):
        c.dot(x, y, HI)
    # raíces aéreas
    for (x0, y0, L) in ((5, 30, 34), (35, 30, 30), (8, 31, 22), (32, 31, 40)):
        c.part(m(stroke(lambda s, x0=x0, y0=y0, L=L: (x0 + 0.6 * math.sin(s * 4 + x0), y0 + L * s), lambda s: 0.6)), TRUNK, 0.5)
    # higos
    for (x, y) in ((12, 28), (28, 29), (24, 18)):
        c.part(ell(x + 0.5, y + 0.5, 1.2, 1.2), ORANGE, 0.5)
    return {'trunk': t.image(), 'canopy': c.image()}


def banana_plant():
    """Platanera (32x40): hojas grandes rasgadas, racimo y flor morada"""
    c = Canvas(32, 40)
    bx, by = 16, 21
    # hojas de atrás
    for (ang, L, W, dr, sl) in ((-125, 17, 3.3, 0.35, ((0.45, 1), (0.7, -1))), (-55, 17, 3.3, 0.4, ((0.5, -1),))):
        pts, p = leaf_pts(bx, by, ang, L, W, dr, blunt=True, slits=sl)
        c.part(m(pts), LEAF, 0.15); midrib(c, p, LEAF[1])
    # pseudotallo
    c.part(lambda x, y: y >= by - 2 and abs(x + 0.5 - bx) <= 1.7 + max(0, y - 34) * 0.3, STEM, 0.3)
    for y in (26, 31, 36): c.dot(bx - 1, y, STEM[1])
    # racimo + flor
    st = stroke(lambda s: (bx + 1 + 6 * s, by + 1 + 5 * s * s), lambda s: 0.6)
    c.part(m(st), STEM, 0.5)
    for (x, y) in ((20, 24), (22, 24), (19, 26), (21, 26), (23, 26), (20, 28), (22, 28)):
        c.part(rell(x + 0.5, y + 0.3, 1.5, 0.9, -0.5), LEAF_LT, 0.5)
    c.part(lambda x, y: ell(22.5, 32.5, 1.7, 2.3)(x, y) and y <= 34, PURPLE, 0.3)
    # hojas de delante
    for (ang, L, W, dr, sl) in ((-92, 18, 3.4, 0.1, ((0.4, 1), (0.62, -1))), (-160, 15, 3.0, 0.7, ((0.55, 1),)),
                                (-18, 15, 3.0, 0.75, ((0.4, -1), (0.66, 1)))):
        pts, p = leaf_pts(bx, by, ang, L, W, dr, blunt=True, slits=sl)
        c.part(m(pts), LEAF_LT, 0.2); midrib(c, p, LEAF_LT[1])
    return c.image()


def elephant_ear():
    """Oreja de elefante (34x24): hojas enormes en forma de corazón, con la punta hacia abajo, en tallos largos"""
    c = Canvas(34, 24)
    def heart(nx, ny, ang, L):
        ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        def loc(x, y):
            dx, dy = x + 0.5 - nx, y + 0.5 - ny
            return dx * ca + dy * sa, -dx * sa + dy * ca
        tri = poly([(0.1 * L, -0.5 * L), (L, 0), (0.1 * L, 0.5 * L)])
        def f(x, y):
            u, v = loc(x, y)
            if (u - 0.28 * L) ** 2 + (abs(v) - 0.27 * L) ** 2 <= (0.3 * L) ** 2 and u > -0.05 * L: return True
            return tri(u - 0.5, v - 0.5)
        return f, loc
    leaves = ((12, 9, 140, 11, LEAF, 16, 23), (22, 9, 40, 11, LEAF, 18, 23), (17, 2, 92, 11, LEAF_LT, 17, 23))
    for (nx, ny, ang, L, pal, sx, sy) in leaves:
        c.part(m(stroke(line(sx, sy, nx, ny), lambda s: 0.6)), STEM, 0.5)
        f, loc = heart(nx, ny, ang, L)
        c.part(f, pal, 0.3)
        a = math.radians(ang)
        for k in range(1, int(L * 0.9)):                        # nervio claro
            c.dot(int(nx + math.cos(a) * k), int(ny + math.sin(a) * k), pal[3] if pal is not LEAF_BK else pal[3])
        for k in (0.35, 0.6):                                   # nervios laterales
            bx, by = nx + math.cos(a) * L * k, ny + math.sin(a) * L * k
            for side in (1, -1):
                b2 = a + side * 0.9
                for j in (1, 2):
                    c.dot(int(bx + math.cos(b2) * j), int(by + math.sin(b2) * j), pal[1])
    return c.image()


def tree_fern():
    """Helecho arborescente (28x44): tronco fino y peludo, corona de frondas que se arquean"""
    c = Canvas(28, 44)
    cx, top = 14, 13
    c.part(lambda x, y: y >= top and abs(x + 0.5 - cx) <= 1.6 + max(0, y - 40) * 0.6, TRUNK, 0.3)
    for y in range(top + 2, 44, 3): c.dot(cx - 1 + (y % 2), y, TRUNK[3])
    def frond(ang, L, droop, pal):
        p = arc(cx, top, ang, L, droop)
        pts = stroke(p, lambda s: 0.6)
        for i in range(2, 13):
            s = i / 13
            x, y = p(s); x2, y2 = p(min(1, s + 0.02))
            dx, dy = x2 - x, y2 - y; d = math.hypot(dx, dy) or 1
            nx, ny = -dy / d, dx / d
            ll = 3.2 * (1 - s) + 0.8
            for side in (1, -1):
                pts |= stroke(lambda q: (x + nx * side * ll * q + dx / d * 0.8 * q, y + ny * side * ll * q + dy / d * 0.8 * q),
                              lambda q: 0.5, 8)
        c.part(m(pts), pal, 0.3)
    for (ang, L, dr) in ((-150, 14, 0.55), (-30, 14, 0.55), (-110, 12, 0.3)):
        frond(ang, L, dr, LEAF_BK)
    for (ang, L, dr) in ((-170, 13, 0.8), (-10, 13, 0.8), (-70, 12, 0.3), (-130, 11, 0.45), (-50, 11, 0.45)):
        frond(ang, L, dr, LEAF)
    c.part(ell(cx + 0.5, top + 0.5, 2, 1.6), TRUNK, 0.3)
    return c.image()


def heliconia():
    """Heliconia (16x28): hojas de remo y un tallo con brácteas rojas en zigzag ("pinza de langosta")"""
    c = Canvas(16, 28)
    for (x0, ang, L, W, dr) in ((6, -105, 20, 2.6, 0.05), (10, -75, 17, 2.4, 0.15)):
        pts, p = leaf_pts(x0, 27, ang, L, W, dr)
        c.part(m(pts), LEAF, 0.2); midrib(c, p, LEAF[1], 0.1, 0.8)
    c.part(m(stroke(line(8, 27, 8.5, 6), lambda s: 0.7)), STEM, 0.4)
    for i, (y, side) in enumerate(((20, 1), (16, -1), (12, 1), (8, -1))):
        x = 8.5 + side * 0.5
        bract = stroke(lambda s, x=x, y=y, side=side: (x + side * 4.0 * s, y - 1.5 * s - 2.2 * s * s), lambda s: 1.5 * (1 - s) + 0.35)
        c.part(m(bract), RED, 0.4)
        tip = stroke(lambda s, x=x, y=y, side=side: (x + side * (3.0 + 1.2 * s), y - 2.8 - 1.0 * s), lambda s: 0.6)
        c.part(m(tip), YELLOW, 0.5)
    pts, p = leaf_pts(9, 27, -40, 12, 2.2, 0.6)
    c.part(m(pts), LEAF_LT, 0.2)
    return c.image()


def ruined_arch():
    """Arco en ruinas (44x40): dos pilares, dintel partido, musgo y lianas"""
    c = Canvas(44, 40)
    c.part(lambda x, y: 12 <= x <= 38 and 4 <= y <= 9 and not (x >= 33 and y - 4 > (38 - x) * 1.1 + 1), STONE_BK, 0.2)
    for (x0, x1, y0) in ((3, 11, 8), (30, 38, 13)):
        c.part(lambda x, y, x0=x0, x1=x1, y0=y0: x0 <= x <= x1 and y >= y0, STONE, 0.15)
        for y in range(y0 + 5, 40, 6):
            for x in range(x0 + 1, x1): c.dot(x, y, STONE[1])
        c.part(lambda x, y, x0=x0, x1=x1: x0 - 1 <= x <= x1 + 1 and y >= 37, STONE, 0.2)
    # dintel (lado izquierdo entero, roto a la derecha)
    c.part(poly([(1, 2), (29, 2), (31, 5), (27, 9), (1, 9)]), STONE, 0.25)
    for x in range(4, 26, 5): c.dot(x, 5, STONE[1]); c.dot(x + 1, 6, STONE[1])
    # piedra caída del dintel
    c.part(poly([(32, 40), (33, 35), (41, 34), (43, 40)]), STONE, 0.3)
    # musgo
    c.part(lambda x, y: (y <= 3 and 0 <= x <= 22 and y >= 1 + (x % 5 == 0)) or (2 <= x <= 7 and 3 <= y <= 4 + (x % 3)), MOSS, 0.5)
    c.part(lambda x, y: 29 <= x <= 39 and 11 <= y <= 13 + (x % 3 == 0) * 2, MOSS, 0.5)
    c.part(lambda x, y: 2 <= x <= 12 and 36 <= y, MOSS, 0.5)
    # lianas del dintel
    for (x0, L) in ((9, 18), (15, 12), (22, 22)):
        c.part(m(stroke(lambda s, x0=x0, L=L: (x0 + 0.7 * math.sin(s * 6 + x0), 9 + L * s), lambda s: 0.6)), VINE, 0.5)
        for k in range(3, L, 5): c.dot(int(x0 + 0.7 * math.sin(k / L * 6 + x0)) + 1, 9 + k, LEAF[3])
    for (x, y) in ((5, 16), (6, 16), (6, 17), (34, 22), (34, 23), (35, 23)): c.dot(x, y, MOSS[2])
    return c.image()


def broken_pillar():
    """Columna rota (14x40): estrías, banda tallada, cima partida con musgo, enredadera"""
    c = Canvas(14, 40)
    c.part(lambda x, y: 0 <= x <= 13 and y >= 35, STONE, 0.2)
    c.part(lambda x, y: 1 <= x <= 12 and 33 <= y <= 35, STONE, 0.2)
    top = [6, 4, 5, 2, 3, 6, 7, 5, 8, 9]
    c.part(lambda x, y: 2 <= x <= 11 and y >= top[x - 2] and y <= 33, STONE, 0.15)
    for x in (4, 7, 10):
        for y in range(top[x - 2] + 2, 33):
            if not (14 <= y <= 17): c.dot(x, y, STONE[1])
    for x in range(3, 11): c.dot(x, 14, STONE[3] if x < 7 else STONE[2]); c.dot(x, 17, STONE[1])
    for x in (4, 7, 10): c.dot(x, 15, STONE[1]); c.dot(x - 1, 16, STONE[1])
    c.part(lambda x, y: 2 <= x <= 9 and top[x - 2] - 1 <= y <= top[x - 2] + 1 + (x % 3 == 0) * 3, MOSS, 0.5)
    # enredadera en espiral
    vine = stroke(lambda s: (6.5 + 5 * math.sin(s * 10), 10 + 24 * s), lambda s: 0.55)
    vine = {(x, y) for (x, y) in vine if math.cos(((y - 10) / 24) * 10) > -0.3}
    c.part(m(vine), VINE, 0.5)
    for (x, y) in ((11, 13), (2, 21), (11, 27)): c.part(ell(x + 0.5, y + 0.5, 1.3, 1), LEAF_LT, 0.5)
    return c.image()


# ══ COLGANTES ═════════════════════════════════════════════════════════════════
def liana(L, seed):
    """Liana (10xL, cuelga): dos hebras trenzadas, hojitas y un rizo abajo"""
    c = Canvas(10, L)
    for ph in (0, math.pi):
        c.part(m(stroke(lambda s, ph=ph: (4.5 + 1.3 * math.sin(s * L / 3.0 + ph), -1 + (L - 4) * s), lambda s: 0.6)), VINE, 0.4)
    c.part(m(stroke(lambda s: (4.5 + 2.2 * math.sin(s * 5.5) * s, L - 5 + 3.2 * math.sin(s * 2.6)), lambda s: 0.55)), VINE, 0.4)
    rnd = random.Random(seed)
    side = 1
    for y in range(4, L - 6, 5):
        x = 4.5 + side * 2.6
        c.part(rell(x + 0.2 * side, y + 0.7, 1.9, 1.1, side * 0.6), LEAF if rnd.random() < 0.6 else LEAF_LT, 0.4)
        side = -side
    return c.image()


def hanging_moss():
    """Musgo colgante (16x20, cuelga): cortina de hebras de distinto largo"""
    c = Canvas(16, 20)
    lens = [9, 14, 12, 18, 15, 11, 17, 13, 10, 16, 12, 8]
    c.part(lambda x, y: 1 <= x <= 14 and y <= 2 + (x % 3 == 1), GREYMOSS, 0.4)
    for i, L in enumerate(lens):
        x0 = 1.5 + i * 1.15
        pts = stroke(lambda s, x0=x0, L=L, i=i: (x0 + 0.6 * math.sin(s * 4 + i), 1 + L * s), lambda s: 1.1 - 0.5 * s)
        c.part(m(pts), GREYMOSS if i % 2 else MOSS, 0.4)
    return c.image()


def flower_vine():
    """Enredadera con flores (14x36, cuelga): tallo con hojas y flores de trompeta magenta y naranja"""
    c = Canvas(14, 36)
    p = lambda s: (7 + 2.4 * math.sin(s * 7), -1 + 33 * s)
    c.part(m(stroke(p, lambda s: 0.6)), VINE, 0.4)
    side = 1
    for i, s in enumerate((0.12, 0.25, 0.38, 0.52, 0.65, 0.8, 0.93)):
        x, y = p(s)
        if i % 2 == 0:
            c.part(rell(x + side * 2.2, y + 0.5, 2.0, 1.2, side * 0.5), LEAF, 0.4)
        else:
            pal = MAGENTA if i != 3 else ORANGE
            fl = stroke(lambda q, x=x, y=y, side=side: (x + side * 2.5 * q, y + 3.5 * q), lambda q: 0.5 + 1.3 * q * q)
            c.part(m(fl), pal, 0.4)
            c.dot(int(x + side * 2.5), int(y + 3.5), YELLOW[2])
        side = -side
    return c.image()




# ══ SUELO ═════════════════════════════════════════════════════════════════════


def jungle_fern():
    """Helecho gigante (22x16): frondas dentadas abiertas a los dos lados"""
    c = Canvas(22, 16)
    def frond(x0, ang, L, droop, pal, n=10):
        p = arc(x0, 15, ang, L, droop)
        pts = stroke(p, lambda s: 0.6)
        for i in range(1, n):
            s = i / n
            x, y = p(s); x2, y2 = p(min(1, s + 0.02))
            dx, dy = x2 - x, y2 - y; d = math.hypot(dx, dy) or 1
            nx, ny = -dy / d, dx / d
            ll = 2.6 * (1 - s) + 0.7
            for side in (1, -1):
                pts |= stroke(lambda q: (x + nx * side * ll * q + dx / d * 0.9 * q, y + ny * side * ll * q + dy / d * 0.9 * q),
                              lambda q: 0.5, 8)
        c.part(m(pts), pal, 0.3)
    for (ang, L, dr) in ((-130, 13, 0.4), (-50, 13, 0.4), (-95, 13, 0.15)):
        frond(11, ang, L, dr, LEAF_BK)
    for (ang, L, dr) in ((-165, 11, 0.6), (-15, 11, 0.6), (-115, 12, 0.3), (-65, 12, 0.3)):
        frond(11, ang, L, dr, LEAF)
    return c.image()


def mossy_log():
    """Tronco con setas (32x12): tronco caído con manta de musgo, anillos, hongos repisa y un brote"""
    c = Canvas(32, 12)
    c.part(lambda x, y: 0 <= x <= 28 and 3 <= y <= 11 and not (x <= 1 and y in (3, 11)), TRUNK, 0.3)
    c.part(ell(28.5, 7.2, 2.6, 4.6), (TRUNK[0], rgb('8a6038'), rgb('b48450'), rgb('d4a46a')), 0.5)
    c.dot(28, 6, TRUNK[2]); c.dot(28, 7, TRUNK[1]); c.dot(29, 8, TRUNK[2])
    for (x, y, n) in ((4, 7, 5), (12, 8, 6), (20, 6, 4)):
        for k in range(n): c.dot(x + k, y, TRUNK[1])
    c.part(lambda x, y: 1 <= x <= 25 and y <= 4 + (x % 4 == 1) + (x % 7 == 3) and y >= 2 - (8 <= x <= 16), MOSS, 0.5)
    for (x, y) in ((4, 2), (5, 2), (11, 1), (12, 1), (19, 2)): c.dot(x, y, MOSS_HI)
    SHELF = (rgb('6a2a08'), rgb('c06418'), rgb('f09a3a'), rgb('fcd08a'))
    for (x, y, rx) in ((22, 6, 2.8), (24.5, 8.5, 2.4), (21.5, 10, 2.0), (6, 9, 1.8)):
        c.part(lambda xx, yy, x=x, y=y, rx=rx: ell(x, y, rx, 1.5)(xx, yy) and yy <= y, SHELF, 0.5)
    pts, _ = leaf_pts(17, 2, -70, 5, 1.0, 0.2)
    c.part(m(pts), LEAF_LT, 0.3)
    pts, _ = leaf_pts(17, 2, -125, 4, 0.9, 0.3)
    c.part(m(pts), LEAF_LT, 0.3)
    return c.image()


def roots():
    """Raíces (18x8): raíces nudosas que salen y entran en la tierra"""
    c = Canvas(18, 8)
    for (x0, x1, h, w) in ((0.5, 10, 6.0, 1.15), (6, 17, 7.0, 1.3), (12, 17, 3.2, 0.9)):
        c.part(m(stroke(lambda s, x0=x0, x1=x1, h=h: (x0 + (x1 - x0) * s, 7.6 - h * math.sin(math.pi * s)),
                        lambda s, w=w: w * (1.25 - 0.5 * abs(s - 0.5)))), TRUNK, 0.3)
    for (x, y) in ((4, 2), (5, 2), (11, 1), (12, 1)): c.dot(x, y, MOSS[3])
    return c.image()



# ══ TEMPLO ════════════════════════════════════════════════════════════════════
def stone_idol(lit):
    """Ídolo de piedra (22x24): cabeza tallada con tocado, cejas pesadas y boca cuadrada; ojos turquesa (2º cuadro: brillan)"""
    c = Canvas(22, 24)
    c.part(lambda x, y: 1 <= x <= 20 and y >= 21, STONE_BK, 0.2)                          # peana
    c.part(lambda x, y: 2 <= x <= 19 and 5 <= y <= 21, STONE, 0.2)                         # cara
    c.part(lambda x, y: 0 <= x <= 21 and 1 <= y <= 6 and not (y == 1 and x in (0, 21)), STONE, 0.25)   # tocado
    for x in range(2, 20, 3): c.dot(x, 3, STONE[1]); c.dot(x + 1, 4, STONE[1])
    c.part(lambda x, y: 0 <= x <= 3 and 7 <= y <= 15, STONE, 0.3)                         # orejeras
    c.part(lambda x, y: 18 <= x <= 21 and 7 <= y <= 15, STONE, 0.3)
    for (x0, x1) in ((4, 8), (13, 17)):                                                   # cejas
        c.part(lambda x, y, x0=x0, x1=x1: x0 <= x <= x1 and 7 <= y <= 8, STONE, 0.4)
    eye = (rgb('0a1c1a'), rgb('124440'), rgb('1a706a'), rgb('2fb0a0')) if not lit else (rgb('1a706a'), GLOW_T, GLOW_T, GLOW_T2)
    for x0 in (5, 14):
        c.part(lambda x, y, x0=x0: x0 <= x <= x0 + 2 and 10 <= y <= 11, eye, 0.6)
        if lit: c.dot(x0, 10, GLOW_T2); c.dot(x0 + 1, 10, rgb('ffffff'))
    c.part(lambda x, y: 9 <= x <= 12 and 10 <= y <= 15 and abs(x + 0.5 - 11) <= 1 + (y - 10) * 0.3, STONE, 0.4)   # nariz
    c.part(lambda x, y: 6 <= x <= 15 and 16 <= y <= 19, (rgb('101410'), rgb('1e2620'), rgb('2a342a'), rgb('3e4a3c')), 0.5)  # boca
    for x in (7, 9, 11, 13): c.dot(x, 17, STONE[2]); c.dot(x + 1, 17, STONE[2])
    # musgo y grieta
    c.part(lambda x, y: (y <= 2 + (x % 4 == 0) and 3 <= x <= 13 and y >= 0) or (14 <= x <= 16 and y <= 2), MOSS, 0.5)
    c.part(lambda x, y: 0 <= x <= 2 and 13 <= y <= 15 + (x == 1), MOSS, 0.5)
    for (x, y) in ((16, 5), (17, 6), (17, 7), (18, 8)): c.dot(x, y, STONE[0])
    for (x, y) in ((4, 0), (8, 0), (15, 0)): c.dot(x, y, MOSS_HI)
    return c.image()


def fallen_block():
    """Bloque caído (20x12): bloque tallado con una espiral, volcado, con musgo y un helecho"""
    c = Canvas(20, 12)
    c.part(poly([(1, 12), (2, 3), (15, 1), (17, 12)]), STONE, 0.2)
    c.part(poly([(15, 1), (19, 3), (19, 12), (17, 12)]), STONE_BK, 0.2)
    spiral = [(6, 5), (7, 5), (8, 5), (9, 5), (10, 6), (10, 7), (10, 8), (9, 9), (8, 9), (7, 9), (6, 8), (6, 7), (7, 7), (8, 7)]
    for (x, y) in spiral: c.dot(x, y, STONE[1])
    for (x, y) in ((11, 9), (11, 8), (5, 6)): c.dot(x, y, STONE[3])
    c.part(lambda x, y: 2 <= x <= 13 and y <= 3 + (x % 3 == 0) and y >= 2 - (x > 8), MOSS, 0.5)
    pts, _ = leaf_pts(17, 3, -80, 4, 1.0, 0.3)
    c.part(m(pts), LEAF_LT, 0.3)
    pts, _ = leaf_pts(17, 3, -30, 4, 1.0, 0.5)
    c.part(m(pts), LEAF_LT, 0.3)
    return c.image()


def stone_brazier():
    """Brasero de piedra (12x24): pie tallado y cuenco; fuego de 4 cuadros arriba"""
    frames = []
    for f in range(4):
        c = Canvas(12, 24)
        a = f / 4 * 2 * math.pi
        h1, h2, h3 = 2 + 1.5 * math.sin(a), 0.5 + 1.2 * math.sin(a + 2.1), 2.5 + 1.4 * math.sin(a + 4.2)
        def tongue(cx, base, tip, w, lean):
            def g(x, y):
                if not (tip <= y <= base): return False
                k = (y - tip) / max(1, base - tip)
                return abs(x + 0.5 - (cx + lean * (1 - k))) <= w * k
            return g
        c.part(U(ell(6, 9.5, 4.5, 2.6), tongue(3.5, 9, h1, 2.2, -0.8), tongue(6.5, 9, h2, 2.6, 0.4), tongue(9, 9, h3, 2, 0.8)), FIRE_OUT, 0.5)
        c.part(U(ell(6, 9.5, 3.2, 1.8), tongue(5, 9, h1 + 2.5, 1.8, -0.3), tongue(7.4, 9, h2 + 3, 1.7, 0.5)), FIRE_MID, 0.5)
        c.part(U(ell(6 + 0.4 * math.sin(a), 9.6, 2, 1.2), tongue(6, 9, h2 + 5.5, 1.1, 0.2)), FIRE_IN, 0.7)
        # cuenco y pie
        c.part(lambda x, y: 9 <= y <= 12 and abs(x + 0.5 - 6) <= 6 - (y - 9) * 0.6, STONE, 0.25)
        c.part(lambda x, y: 4 <= x <= 7 and 12 <= y <= 21, STONE, 0.2)
        c.part(lambda x, y: 2 <= x <= 9 and 21 <= y <= 23, STONE, 0.2)
        for x in range(1, 11, 2): c.dot(x, 10, STONE[1])
        c.part(lambda x, y: 2 <= x <= 6 and 22 <= y, MOSS, 0.5)
        c.dot(5, 15, STONE[1]); c.dot(6, 16, STONE[1]); c.dot(5, 17, STONE[1])
        frames.append(c.image())
    return strip(frames)


# ══ PARTÍCULAS (fx/) ══════════════════════════════════════════════════════════
def fx_leaf():
    """hoja verde que cae dando vueltas (4 cuadros de 5x4, en color)"""
    shapes = (((0, 2), (1, 1), (2, 1), (3, 1), (1, 2), (2, 2), (3, 0), (4, 0)),
              ((1, 0), (1, 1), (2, 1), (2, 2), (3, 2), (2, 3), (1, 2)),
              ((0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (1, 1), (2, 1)),
              ((3, 0), (3, 1), (2, 1), (2, 2), (1, 2), (2, 3), (3, 2)))
    frames = []
    for i, s in enumerate(shapes):
        im = Image.new('RGBA', (5, 4), (0, 0, 0, 0))
        for k, (x, y) in enumerate(s): im.putpixel((x, y), LEAF[3] if k in (1, 2) and i != 2 else (LEAF[2] if k % 3 else LEAF[1]))
        frames.append(im)
    return strip(frames)


def fx_firefly():
    """luciérnaga: 3 cuadros de 5x5 que laten (núcleo blanco-amarillo, halo verde lima)"""
    frames = []
    for r in (0, 1, 2):
        im = Image.new('RGBA', (5, 5), (0, 0, 0, 0))
        for y in range(5):
            for x in range(5):
                d = abs(x - 2) + abs(y - 2)
                if d == 0: im.putpixel((x, y), rgb('fffbd0'))
                elif d == 1 and r >= 0: im.putpixel((x, y), rgb('e8f060') if r else rgb('a6d860', 200))
                elif d == 2 and r == 2: im.putpixel((x, y), rgb('86b03c', 150))
        frames.append(im)
    return strip(frames)


def fx_pollen():
    """polen / esporas: 3 variantes de 3x3 (blancas: se tiñen)"""
    frames = []
    for s in (((1, 1),), ((1, 1), (2, 1)), ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2))):
        im = Image.new('RGBA', (3, 3), (0, 0, 0, 0))
        for k, (x, y) in enumerate(s): im.putpixel((x, y), (255, 255, 255, 255) if (x, y) == (1, 1) else (220, 220, 220, 255))
        frames.append(im)
    return strip(frames)


def fx_mist():
    """bruma: 3 cuadros de 14x6 (blancos, el juego los tiñe y los hace casi transparentes)"""
    frames = []
    for k in range(3):
        im = Image.new('RGBA', (14, 6), (0, 0, 0, 0))
        rx, ry = 4.5 + k * 1.1, 1.6 + k * 0.4
        for y in range(6):
            for x in range(14):
                d = ((x + 0.5 - 7) / rx) ** 2 + ((y + 0.5 - 3.4) / ry) ** 2
                d2 = ((x + 0.5 - 5 - k) / (rx * 0.6)) ** 2 + ((y + 0.5 - 2.4) / (ry * 0.9)) ** 2
                if min(d, d2) <= 1:
                    v = 255 if d2 <= 1 else 215
                    im.putpixel((x, y), (v, v, v, 255))
        frames.append(im)
    return strip(frames)


def fx_drip():
    """gota de agua (3 cuadros de 5x5): se forma, cae, salpica"""
    W1, W2, W3 = rgb('3a7a9a'), rgb('7ac0e0'), rgb('d8f4ff')
    data = (((2, 0, W1), (2, 1, W2), (1, 1, W1), (3, 1, W1), (2, 2, W1)),
            ((2, 0, W2), (2, 1, W2), (1, 2, W1), (2, 2, W3), (3, 2, W1), (2, 3, W1)),
            ((0, 3, W2), (4, 3, W2), (1, 2, W1), (3, 2, W1), (2, 4, W1), (1, 4, W2), (3, 4, W2)))
    frames = []
    for d in data:
        im = Image.new('RGBA', (5, 5), (0, 0, 0, 0))
        for x, y, col in d: im.putpixel((x, y), col)
        frames.append(im)
    return strip(frames)


# ── Píxel a píxel (lo pequeño: bichos y flores; a mano se lee mejor que con máscaras) ──
def pix(rows, legend):
    rows = [r for r in rows]
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.' and ch != ' ': im.putpixel((x, y), legend[ch])
    return im


def edit(rows, changes):
    """copia de un dibujo con filas cambiadas: {y: 'fila'}"""
    out = list(rows)
    for y, r in changes.items(): out[y] = r
    return out


L_TOUCAN = {'K': rgb('0c0c14'), 'k': rgb('1e1e2c'), 'b': rgb('30304a'), 'g': rgb('50506e'),
            'W': rgb('ffffff'), 'w': rgb('d8d8c8'), 'y': rgb('f4d03a'),
            'E': rgb('2f78e0'), 'e': rgb('7ab8ff'), 'p': rgb('0c0c14'),
            'q': rgb('7a3008'), 'o': rgb('c85a10'), 'O': rgb('f08a24'), 'L': rgb('f8c050'), 't': rgb('241410'),
            'r': rgb('d8322c'), 'f': rgb('6a6a7a'),
            'T': rgb('2a1a10'), 's': rgb('4a2e1a'), 'S': rgb('6e4426'), 'h': rgb('966236'), 'm': rgb('5fb04a')}
TOUCAN = [
    '................',
    '...KKKK.........',
    '..KggbbKqqqqqq..',
    '.KgbEEbqLLLLLLq.',
    '.KbEpEbqOOLLLLLq',
    '.KbbEEbqoOOOOOtq',
    '.KbWWWbqqooootq.',
    '.KWWWWwKKqqqqq..',
    '.KyWWWwbbK......',
    '.KbyyykbbbK.....',
    '.KgbbkkkbbK.....',
    '.KgbbkkkkK......',
    '..KbkkkkK.......',
    '.KbKKKKK........',
    'KbK.f.f.........',
    'KK.TmhhST.......',
    '...TShSsT.......',
    '...TSSssT.......',
]


def toucan():
    """Tucán (16x18) posado en un tocón: 4 cuadros (quieto, parpadea, llama con el pico abierto, salta un pelo)"""
    blink = edit(TOUCAN, {4: '.KbEkEbqOOLLLLLq'})
    call = edit(TOUCAN, {4: '.KbEpEbqOOLLLLLq', 5: '.KbbEEbqooooqqtq', 6: '.KbWWWbKqqq..qq.',
                         7: '.KWWWWwqOOOOqq..', 8: '.KyWWWwbqooootq.', 9: '.KbyyykbbKqqqq..'})
    hop = TOUCAN[1:15] + ['KK..............', '...TmhhST.......', TOUCAN[16], TOUCAN[17]]
    return strip([pix(TOUCAN, L_TOUCAN), pix(blink, L_TOUCAN), pix(call, L_TOUCAN), pix(hop, L_TOUCAN)])


L_FROG = {'K': rgb('0a1e4a'), 'd': rgb('1a46a0'), 'm': rgb('2f78e0'), 'l': rgb('7ab8ff'), 'x': rgb('0c1028'),
          'w': rgb('ffffff'), 's': rgb('d0e8ff')}
FROG = [
    '............',
    '........KKK.',
    '.......KwxlK',
    '...KKKKlxxmK',
    '..KllmmmmmmK',
    '.KlmxxmmxmmK',
    'KlmKKKmmmdK.',
    'KmKdxdKmKdK.',
    'KKKKKKKKKKK.',
]


def dart_frog():
    """Rana venenosa (12x9): 4 cuadros (sentada, croa, se agacha, salta)"""
    croak = edit(FROG, {5: '.KlmxxmmxmmK', 6: 'KlmKKKmmmKsK', 7: 'KmKdxdKmKssK', 8: 'KKKKKKKKKKK.'})
    crouch = ['............'] + FROG[:3] + ['...KKKKlxxmK', '.KllmxxmmxmK', 'KlmKKKmmmdK.', 'KmKdxdKmKdK.', 'KKKKKKKKKKK.'][0:5]
    crouch = ['............', '............', '........KKK.', '.......KwxlK', '..KKKKKlxxmK', '.KllmxxmmxmK',
              'KlmKKKmmmdK.', 'KmKdxdKmKdK.', 'KKKKKKKKKKK.']
    jump = ['........KKK.', '.......KwxlK', '...KKKKlxxmK', '..KllmmmmmmK', '.KlmxxmmxmmK', 'KlmxmmmmmdK.',
            'KdKKdKKKdK..', 'Kd.Kd..Kd...', 'K..K...K....']
    return strip([pix(r, L_FROG) for r in (FROG, croak, crouch, jump)])


L_DF = {'d': rgb('1a706a'), 'm': rgb('2fb0a0'), 'E': rgb('7ee0cc'), 'K': rgb('0e3a38'),
        'w': rgb('8ab8c8'), 'W': rgb('dcf4fc')}


def dragonfly():
    """Libélula (13x5): 2 cuadros (alas arriba / abajo)"""
    up_ = ['.....wW..wW..', '....wWw.wWw..', 'dmdmdmdmmKEE.', '.........KE..', '.............']
    dn_ = ['.............', '.........KE..', 'dmdmdmdmmKEE.', '....wWw.wWw..', '.....wW..wW..']
    return strip([pix(up_, L_DF), pix(dn_, L_DF)])


L_MUSH = {'K': rgb('0e3a38'), 'd': rgb('1a706a'), 'T': rgb('2fb0a0'), 'l': rgb('7ee0cc'), 'G': rgb('e8fff8'),
          'o': rgb('6a6a7a'), 's': rgb('b8b8c4'), 'S': rgb('ececf4'), 'g': rgb('23401a'), 'M': rgb('6a9630')}


def jungle_mushrooms():
    """Setas de la selva (10x9): dos setas de sombrero turquesa con motas que brillan, en una mata de musgo"""
    return pix(['..KKKK....',
                '.KlGTTK...',
                'KlTTTGdK..',
                'KddddddK..',
                '..KSsK.KKK',
                '..KSsKKlGdK'[:10],
                '..KSsKKddK',
                '..KSsK.KsK',
                'gMgSsMgMsg'], L_MUSH)


L_BROM = {'G': rgb('0f2a1a'), 'g': rgb('1d4a2a'), 'M': rgb('2f7a3a'), 'L': rgb('5fb04a'), 'H': rgb('a6d860'),
          'R': rgb('5a0e10'), 'r': rgb('a01e1e'), 'Q': rgb('d8322c'), 'q': rgb('f05a48'),
          'p': rgb('8a1e50'), 'P': rgb('d0407a'), 'Y': rgb('f4d03a')}


def bromeliad():
    """Bromelia (12x10): roseta de hojas en punta, rojas por dentro, con espiga rosa"""
    return pix(['.....Y......',
                '....YPY.....',
                '.....Pp.....',
                'G...RqPR...G',
                'LG.RqQpQR.GL',
                'GLGRqQQrRGLg',
                '.GLRqQrRrGMG',
                'GHLGRQrRGLMg',
                'GLHLGRRGLMgG',
                '.GGGGGGGGGG.'], L_BROM)


L_ORCH = {'G': rgb('0f2a1a'), 'g': rgb('1d4a2a'), 'M': rgb('2f7a3a'), 'L': rgb('5fb04a'), 's': rgb('4f6a26'),
          'W': rgb('fbe8f4'), 'w': rgb('d8a8cc'), 'v': rgb('a06aa0'), 'm': rgb('d0407a'), 'p': rgb('8a1e50'),
          'Y': rgb('f4d03a')}


def orchid():
    """Orquídea (10x12): dos hojas anchas, tallo arqueado y dos flores"""
    return pix(['......vWv.',
                '.....vWWWv',
                '......mYm.',
                '..vWv.vpv.',
                '.vWWWvs...',
                '..mYm.s...',
                '..vpv.s...',
                '.....s....',
                '.GG..s..G.',
                'GLMG.s.GMG',
                'GLLMGsGMLG',
                '.GGGGGGGG.'], L_ORCH)


def hanging_orchid():
    """Orquídea colgante (10x17, cuelga): hilo, bola de musgo y raíces, y un racimo de tres flores"""
    L = dict(L_ORCH, **{'n': rgb('3a4a1c'), 'k': rgb('23401a'), 'D': rgb('4f7a26'), 'N': rgb('6a9630'), 'h': rgb('86b03c')})
    return pix(['....n.....',
                '....n.....',
                '....n.....',
                '..kkkkk...',
                '.khhNNDk..',
                '.kNNNNDk..',
                '..kDDDk...',
                '...n.ss...',
                '..n...s...',
                '.vWv...s..',
                'vWWWv...s.',
                '.mYm..vWv.',
                '.vpv.vWWWv',
                '......mYm.',
                '...vWvvpv.',
                '..vWWWv...',
                '...mYm....',
                '...vpv....'], L)


L_MUD = {'R': rgb('2a180e'), 'r': rgb('5a3a22'), 'h': rgb('7e5634'), 'H': rgb('9a7048'),
         'w': rgb('22160c'), 'W': rgb('3a2a1c'), 's': rgb('6a7a72'), 'S': rgb('a8bcb0'), 'b': rgb('8a6a4a')}
PUDDLE = ['................',
          '....HhhhhhhhH...',
          '.HhhWWsSSsWWhhH.',
          'hrWWwwwwwwwwWWrh',
          'RrrrWWWwwWWWrrrR',
          '.RRRrrrrrrrrRRR.']


def mud_puddle():
    """Charco de barro (16x6): 3 cuadros, una burbuja de barro crece y revienta"""
    b1 = edit(PUDDLE, {1: '....HhhhhhhhH...', 2: '.HhhWWsSSsRbhhH.', 3: 'hrWWwwwwwwRWrWrh'})
    b1 = edit(PUDDLE, {1: '....HhhhhhRRH...', 2: '.HhhWWsSSRbSRhH.', 3: 'hrWWwwwwwRWWRWrh'})
    b2 = edit(PUDDLE, {1: '....HhhhhSh.S...', 2: '.HhhWWsSSsWsWhH.'})
    return strip([pix(r, L_MUD) for r in (PUDDLE, b1, b2)])


L_MONK = {'K': rgb('24140a'), 'd': rgb('42281a'), 'F': rgb('624028'), 'f': rgb('86603c'),
          's': rgb('c49470'), 'S': rgb('e6bc94'), 'n': rgb('9a6a48'), 'x': rgb('1a0e06'), 'w': rgb('ffffff')}
MONKEY = ['.....KK.....',
          '.....KfK....',
          '.....KFK....',
          '..KKKKFK....',
          '.KFffFFdK...',
          'KFfFFFFFdK..',
          'KFSSnSSSdK..',
          'KSxSSSxSK...',
          'KSSSnSSSK...',
          '.KSnnnSK....',
          '..KKKKFdK...',
          '..KFfFFFdK..',
          '.KFfFFFFFdK.',
          '.KdFFFFFFdK.',
          'KdKFFFFFdKdK',
          'Kd.KFFFFdK.K',
          '.K.KdKKdK.Kd',
          '...KdK.KdK.K',
          '...KK..KK.Kd',
          '..........K.']


def monkey():
    """Mono (12x20, cuelga de un brazo): 3 cuadros (quieto, parpadea, rasca la cabeza)"""
    blink = edit(MONKEY, {7: 'KSnSSSnSK...'})
    scratch = edit(MONKEY, {3: '..KKKKFK.KK.', 4: '.KFffFFdKKdK', 5: 'KFfFFFFFdKdK', 6: 'KFSSnSSSdKdK', 7: 'KSxSSSxSKdK.',
                            8: 'KSSSnSSSKdK.', 9: '.KSnnnSKdK..', 10: '..KKKKFdK...'})
    return strip([pix(r, L_MONK) for r in (MONKEY, blink, scratch)])


# ══ Catálogo ══════════════════════════════════════════════════════════════════
# name, etiqueta (editor), función, colocación, capa, cuelga, ancho de cuadro (None = 1 cuadro), qué hace en el juego
ITEMS = [
    ('ceiba', 'Ceiba gigante', ceiba, 'cell', 'back', False, None, 'copa se mece (capa canopy); suelta hojas'),
    ('strangler_fig', 'Higuera estranguladora', strangler_fig, 'cell', 'back', False, None, 'copa se mece; hojas'),
    ('banana_plant', 'Platanera', banana_plant, 'cell', 'back', False, None, 'wave 0.7'),
    ('tree_fern', 'Helecho arborescente', tree_fern, 'cell', 'back', False, None, 'wave 0.8'),
    ('heliconia', 'Heliconia', heliconia, 'cell', 'back', False, None, 'wave 0.6; polen'),
    ('elephant_ear', 'Oreja de elefante', elephant_ear, 'cell', 'back', False, None, 'wave 0.5'),
    ('jungle_fern', 'Helecho gigante', jungle_fern, 'cell', 'back', False, None, 'wave 0.9'),
    ('ruined_arch', 'Arco en ruinas', ruined_arch, 'cell', 'back', False, None, 'estático; gotas'),
    ('broken_pillar', 'Columna rota', broken_pillar, 'cell', 'back', False, None, 'estático'),
    ('stone_idol', 'Ídolo de piedra', None, 'cell', 'back', False, 22, 'ojos laten (2 cuadros) + luz turquesa'),
    ('fallen_block', 'Bloque caído', fallen_block, 'cell', 'back', False, None, 'estático'),
    ('stone_brazier', 'Brasero de piedra', stone_brazier, 'cell', 'back', False, 12, 'fuego 4 cuadros, luz, brasas'),
    ('mossy_log', 'Tronco con setas', mossy_log, 'cell', 'back', False, None, 'estático; esporas'),
    ('roots', 'Raíces', roots, 'cell', 'front', False, None, 'estático'),
    ('mud_puddle', 'Charco de barro', mud_puddle, 'cell', 'front', False, 16, 'burbuja 3 cuadros'),
    ('liana_long', 'Liana (larga)', lambda: liana(48, 3), 'sub', 'back', True, None, 'cuelga; wave 1.2'),
    ('liana_mid', 'Liana (media)', lambda: liana(32, 5), 'sub', 'back', True, None, 'cuelga; wave 1.0'),
    ('liana_short', 'Liana (corta)', lambda: liana(16, 7), 'sub', 'back', True, None, 'cuelga; wave 0.8'),
    ('hanging_moss', 'Musgo colgante', hanging_moss, 'cell', 'back', True, None, 'cuelga; wave 0.6; gotas'),
    ('flower_vine', 'Enredadera con flores', flower_vine, 'cell', 'back', True, None, 'cuelga; wave 1.0'),
    ('hanging_orchid', 'Orquídea colgante', hanging_orchid, 'sub', 'back', True, None, 'cuelga; se balancea (rot)'),
    ('monkey', 'Mono', monkey, 'cell', 'back', True, 12, 'cuelga de la cola, se balancea; 3 cuadros'),
    ('bromeliad', 'Bromelia', bromeliad, 'sub', 'front', False, None, 'estático'),
    ('orchid', 'Orquídea', orchid, 'sub', 'front', False, None, 'se balancea (rot)'),
    ('jungle_mushrooms', 'Setas de la selva', jungle_mushrooms, 'sub', 'front', False, None, 'brillo suave; esporas'),
    ('toucan', 'Tucán', toucan, 'sub', 'front', False, 16, 'parpadea, mira atrás, llama (4 cuadros)'),
    ('dart_frog', 'Rana venenosa', dart_frog, 'sub', 'front', False, 12, 'croa y salta en su sitio (4 cuadros)'),
    ('dragonfly', 'Libélula', dragonfly, 'cell', 'front', False, 13, 'vuela por su casilla (2 cuadros)'),
    ('fireflies', 'Luciérnagas', None, 'cell', 'front', False, None, 'solo partículas (fx/firefly), aditivas'),
]
# (aprobado sin ellos, 2026-10-28: la rana, el tucán y el mono no se aplican ni se registran — quizá sean enemigos
# más adelante —; su dibujo se queda aquí y siguen en la vista previa)
NOT_APPLIED = {'dart_frog', 'toucan', 'monkey'}
FX = [('jungle_leaf', fx_leaf, 5), ('firefly', fx_firefly, 5), ('pollen', fx_pollen, 3), ('mist', fx_mist, 14),
      ('drip', fx_drip, 5)]


def build():
    """→ {nombre: (imagen con margen, ancho de cuadro con margen, cuelga, capas{} o None)}"""
    out = {}
    for (name, label, fn, place, layer, hang, fw, anim) in ITEMS:
        if name == 'fireflies': continue
        if name == 'stone_idol':
            img = pad(strip([stone_idol(False), stone_idol(True)]), False, 22)
            out[name] = (img, 24, hang, None); continue
        r = fn()
        if isinstance(r, dict):
            layers = {k: pad(v, hang) for k, v in r.items()}
            out[name] = (None, None, hang, layers)
        else:
            img = pad(r, hang, fw)
            out[name] = (img, (fw + 2) if fw else img.width, hang, None)
    fx = {n: (fn(), fw) for (n, fn, fw) in FX}
    return out, fx


def file_names(name, entry):
    img, fw, hang, layers = entry
    if layers: return {name + '_' + k + '.png': v for k, v in layers.items()}
    return {(name + '-Sheet.png' if fw != img.width else name + '.png'): img}


# ══ Vista previa ══════════════════════════════════════════════════════════════
S = 4
BG_TOP, BG_BOT = (52, 84, 82), (34, 58, 56)
FONT = ImageFont.truetype(os.path.join(REPO, 'assets/fonts/PressStart2P.ttf'), 8)


def frames_of(entry):
    img, fw, hang, layers = entry
    if layers:
        base = None
        for k in ('trunk', 'canopy'):
            base = layers[k].copy() if base is None else (base.alpha_composite(layers[k]) or base)
        return [base]
    n = img.width // fw
    return [img.crop((i * fw, 0, (i + 1) * fw, img.height)) for i in range(n)]


def up(im, k=S): return im.resize((im.width * k, im.height * k), Image.NEAREST)


def ground_tile(x_art):
    """casilla de suelo de selva (16x16): hierba oscura arriba, barro debajo (solo para la vista previa)"""
    t = Image.new('RGBA', (16, 16), MUD[2])
    for x in range(16):
        h = 3 + ((x * 7 + x_art) % 5 == 0) + ((x * 3 + x_art) % 7 == 0)
        for y in range(h): t.putpixel((x, y), LEAF[1] if y < h - 1 else LEAF[0])
        t.putpixel((x, 0), LEAF[2] if (x + x_art) % 3 else LEAF[3])
    for (x, y, col) in ((3, 8, MUD[1]), (4, 8, MUD[1]), (11, 11, MUD[1]), (7, 13, MUD[3]), (13, 6, MUD[3]), (1, 14, MUD[1])):
        t.putpixel((x, y), col)
    return t


def ceiling_tile(x_art):
    t = Image.new('RGBA', (16, 16), STONE[1])
    for x in range(16):
        t.putpixel((x, 15), STONE[0])
        if (x + x_art) % 4 == 0: t.putpixel((x, 14), MOSS[1])
    for (x, y) in ((4, 5), (11, 9), (8, 2)): t.putpixel((x, y), STONE[2])
    return t


def bg(w, h):
    im = Image.new('RGBA', (w, h))
    d = ImageDraw.Draw(im)
    for y in range(0, h, 8):
        k = y / max(1, h - 1)
        col = tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * k) for i in range(3))
        d.rectangle((0, y, w, y + 8), fill=col + (255,))
    return im


def text(d, x, y, s, col=(230, 240, 220)):
    d.text((x + 1, y + 1), s, font=FONT, fill=(10, 20, 16))
    d.text((x, y), s, font=FONT, fill=col)


def player_img():
    return up(Image.open(os.path.join(REPO, 'assets/images/player/monstrito1.png')).convert('RGBA'), 6)


def beetle_img():
    sh = Image.open(os.path.join(REPO, 'assets/images/enemies/beetle/beetle-Sheet.png')).convert('RGBA')
    return up(sh.crop((0, 0, 22, 20)), 4)


def row_ground(canvas, y_ground, w):
    for gx in range(0, w, 64):
        canvas.alpha_composite(up(ground_tile(gx // 64 * 5)), (gx, y_ground))


def row_ceiling(canvas, y_ceil, w):
    for gx in range(0, w, 64):
        canvas.alpha_composite(up(ceiling_tile(gx // 64 * 3)), (gx, y_ceil - 64))


def preview(items, fx):
    W = 1840
    sections = [
        ('GRANDES / RUINAS (celda, crecen hacia arriba)', ['ceiba', 'strangler_fig', 'banana_plant', 'tree_fern', 'heliconia',
                                                         'elephant_ear', 'ruined_arch', 'broken_pillar', '@player', '@beetle'], False),
        ('SUELO Y TEMPLO', ['jungle_fern', 'stone_idol', 'fallen_block', 'stone_brazier', 'mossy_log', 'roots', 'mud_puddle',
                            'bromeliad', 'orchid', 'jungle_mushrooms', 'toucan', 'dart_frog', 'dragonfly', '@player'], False),
        ('COLGANTES (del techo de su casilla)', ['liana_long', 'liana_mid', 'liana_short', 'hanging_moss', 'flower_vine',
                                                 'hanging_orchid', 'monkey', '@player'], True),
    ]
    label_of = {it[0]: it for it in ITEMS}
    blocks = []
    for title, names, hang in sections:
        cells = []
        for n in names:
            if n == '@player': im, lab, sub = player_img(), 'Monstruo x6', ''
            elif n == '@beetle': im, lab, sub = beetle_img(), 'Escarabajo x4', ''
            else:
                fr = frames_of(items[n])[0]
                im = up(fr)
                it = label_of[n]
                lab = it[1]
                w0, h0 = fr.width - 2, fr.height - 1
                sub = '%dx%d %s' % (w0, h0, it[3])
            cells.append((n, im, lab, sub))
        hmax = max(c[1].height for c in cells)
        blocks.append((title, cells, hang, hmax))
    # animaciones cuadro a cuadro
    anim_names = [n for (n, *_r) in ITEMS if n in items and frames_of(items[n]) and len(frames_of(items[n])) > 1]
    H = 30
    for (_, _, _, hmax) in blocks: H += 40 + hmax + 64 + 40
    H += 40 + len(anim_names) * 0 + 380 + 200
    canvas = bg(W, H)
    d = ImageDraw.Draw(canvas)
    text(d, 16, 10, 'SELVA - conjunto jungle_set (PROPUESTA, sin aplicar)   decoraciones x4 · 1 casilla = 64 px', (255, 240, 160))
    y = 36
    for (title, cells, hang, hmax) in blocks:
        text(d, 16, y, title, (255, 220, 140))
        y += 22
        if hang:
            yc = y + 64
            row_ceiling(canvas, yc, W)
            x = 24
            for (n, im, lab, sub) in cells:
                if n == '@player':
                    canvas.alpha_composite(im, (x, yc + hmax + 30 - im.height)); x += im.width + 40; continue
                canvas.alpha_composite(im, (x, yc))
                text(d, x, yc + im.height + 6, lab)
                text(d, x, yc + im.height + 18, sub, (170, 200, 170))
                x += max(im.width, 8 * max(len(lab), len(sub))) + 28
            y = yc + hmax + 60
        else:
            yg = y + hmax
            row_ground(canvas, yg, W)
            x = 24
            for (n, im, lab, sub) in cells:
                canvas.alpha_composite(im, (x, yg - im.height + (0 if n[0] == '@' else 4)))
                text(d, x, yg + 22, lab)
                if sub: text(d, x, yg + 34, sub, (170, 200, 170))
                x += max(im.width, 8 * max(len(lab), len(sub))) + 28
            y = yg + 64 + 8
    # cuadro a cuadro
    text(d, 16, y, 'ANIMACIONES (cuadro a cuadro, x4)', (255, 220, 140))
    y += 22
    x, rowh = 24, 0
    for n in anim_names:
        frs = frames_of(items[n])
        w = sum(f.width * S + 6 for f in frs) + 20
        if x + max(w, 160) > W - 20: x, y = 24, y + rowh + 30; rowh = 0
        xx = x
        for f in frs:
            canvas.alpha_composite(up(f), (xx, y)); xx += f.width * S + 6
        text(d, x, y + frs[0].height * S + 4, label_of[n][1])
        rowh = max(rowh, frs[0].height * S + 16)
        x += max(w, 8 * len(label_of[n][1]) + 20)
    y += rowh + 34
    text(d, 16, y, 'PARTICULAS fx/ (x8)', (255, 220, 140))
    y += 22
    x = 24
    for (n, (im, fw)) in fx.items():
        k = im.width // fw
        xx = x
        dark = Image.new('RGBA', (im.width * 8 + k * 6 + 8, im.height * 8 + 8), (20, 34, 30, 255))
        canvas.alpha_composite(dark, (x - 4, y - 4))
        for i in range(k):
            canvas.alpha_composite(up(im.crop((i * fw, 0, (i + 1) * fw, im.height)), 8), (xx, y)); xx += fw * 8 + 6
        text(d, x, y + im.height * 8 + 8, n + '-Sheet')
        x = max(xx, x + 8 * len(n + '-Sheet')) + 40
    y += 100
    return canvas.crop((0, 0, W, y))


# ══ Maqueta animada ═══════════════════════════════════════════════════════════
def wave_img(fr, t, amp, speed, phase, hang=False, k_scale=S):
    """como DecoFx.wave: filas desplazadas en seno (raíz quieta)"""
    big = up(fr, k_scale)
    out = Image.new('RGBA', (big.width + 2 * int(amp * k_scale + 4), big.height), (0, 0, 0, 0))
    pad_x = (out.width - big.width) // 2
    h = fr.height
    tt = t * speed + phase * 6.28
    for row in range(h):
        k = (row / (h - 1)) if hang else (1 - row / (h - 1))
        off = int(math.floor(amp * k_scale * k ** 1.4 * math.sin(tt - k * 1.3) + 0.5))
        out.alpha_composite(big.crop((0, row * k_scale, big.width, (row + 1) * k_scale)), (pad_x + off, row * k_scale))
    return out, pad_x


def add_glow(base, cx, cy, r, col, a):
    g = Image.new('RGBA', base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    for i in range(6, 0, -1):
        rr = r * i / 6
        al = int(255 * a * (1 - i / 6.5) / 2)
        gd.rectangle((cx - rr, cy - rr * 0.8, cx + rr, cy + rr * 0.8), fill=None)
    # halo en escalones (aditivo aproximado: mezcla clara)
    for i in range(5, 0, -1):
        rr = r * i / 5
        lay = Image.new('RGBA', base.size, (0, 0, 0, 0))
        ImageDraw.Draw(lay).ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=col + (int(255 * a / 5),))
        base.alpha_composite(lay)


def maqueta(items, fx):
    SW, SH = 1600, 720
    random.seed(4)
    ground_y = SH - 128
    nfr = 48
    fr = lambda n, i=0: frames_of(items[n])[i]
    layers = {k: v for k, v in items['ceiba'][3].items()}
    fig = items['strangler_fig'][3]
    parts = []           # partículas: x, y, vx, vy, life, kind
    out = []
    back = bg(SW, SH)
    # silueta de selva lejana
    sil = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sil)
    for i in range(0, SW, 40):
        hh = 120 + int(40 * math.sin(i * 0.013) + 25 * math.sin(i * 0.051))
        sd.ellipse((i - 50, ground_y - hh, i + 70, ground_y - hh + 120), fill=(40, 70, 60, 255))
    sd.rectangle((0, ground_y - 80, SW, ground_y), fill=(40, 70, 60, 255))
    back.alpha_composite(sil)
    for gx in range(0, SW, 64):
        for gy in (ground_y, ground_y + 64):
            t = up(ground_tile(gx // 64 * 5))
            if gy > ground_y:
                t = up(Image.new('RGBA', (16, 16), MUD[2]))
            back.alpha_composite(t, (gx, gy))
    # techo de piedra a la derecha (para lo que cuelga)
    ceil_y = 128
    for gx in range(1024, SW, 64):
        back.alpha_composite(up(ceiling_tile(gx // 64)), (gx, ceil_y - 64))
        back.alpha_composite(up(Image.new('RGBA', (16, 16), STONE[1])), (gx, ceil_y - 128))
    for i in range(nfr):
        t = i / nfr * 2 * math.pi / 1.0          # un ciclo exacto por bucle
        tt = i / nfr * 4.0                       # segundos de la escena
        im = back.copy()
        # ceiba
        cb_x = 160
        tr = up(layers['trunk'])
        im.alpha_composite(tr, (cb_x - tr.width // 2, ground_y + 4 - tr.height))
        cw, px = wave_img(layers['canopy'], t, 0.6, 1, 0)
        im.alpha_composite(cw, (cb_x - tr.width // 2 - px, ground_y + 4 - tr.height))
        # higuera atrás
        fx_ = 470
        ft = up(fig['trunk'])
        im.alpha_composite(ft, (fx_ - ft.width // 2, ground_y + 4 - ft.height))
        cw, px = wave_img(fig['canopy'], t + 1, 0.5, 1, 0)
        im.alpha_composite(cw, (fx_ - ft.width // 2 - px, ground_y + 4 - ft.height))
        # arco + ídolo + brasero
        arc_im = up(fr('ruined_arch'))
        im.alpha_composite(arc_im, (1290, ground_y + 4 - arc_im.height))
        idol = up(fr('stone_idol', 1 if math.sin(t * 2) > 0.2 else 0))
        im.alpha_composite(idol, (1330, ground_y + 4 - idol.height))
        if math.sin(t * 2) > 0.2: add_glow(im, 1330 + 11 * 4 + 4, ground_y - 13 * 4 * 1 - 20, 46, (90, 240, 220), 0.18)
        br = up(fr('stone_brazier', int(tt * 8) % 4))
        for bx in (1230, 1490):
            add_glow(im, bx + br.width // 2, ground_y - 80, 70, (255, 140, 50), 0.14)
            im.alpha_composite(br, (bx, ground_y + 4 - br.height))
        # plantas que se mecen
        for (n, x, amp, ph) in (('banana_plant', 280, 0.7, 0.2), ('tree_fern', 760, 0.8, 0.5), ('heliconia', 880, 0.6, 0.8),
                                ('elephant_ear', 345, 0.5, 0.3), ('jungle_fern', 990, 0.9, 0.1)):
            w_im, px = wave_img(fr(n), t, amp, 1, ph)
            im.alpha_composite(w_im, (x - px, ground_y + 4 - w_im.height))
        for (n, x) in (('bromeliad', 10), ('mossy_log', 540), ('orchid', 730), ('jungle_mushrooms', 1060), ('roots', 1550),
                       ('mud_puddle', 1090), ('broken_pillar', 1540)):
            if n == 'mud_puddle': f = up(fr(n, int(tt * 3) % 3))
            else: f = up(fr(n))
            im.alpha_composite(f, (x, ground_y + 4 - f.height))
        # colgantes del techo
        for (n, x, amp, ph) in (('liana_long', 1060, 1.2, 0.0), ('hanging_moss', 1130, 0.6, 0.4), ('liana_mid', 1230, 1.0, 0.6),
                                ('flower_vine', 1300, 1.0, 0.2), ('liana_short', 1380, 0.8, 0.9), ('hanging_orchid', 1440, 0.6, 0.5)):
            w_im, px = wave_img(fr(n), t, amp, 1, ph, hang=True)
            im.alpha_composite(w_im, (x - px, ceil_y - 4))
        mk = up(fr('monkey', (0, 0, 1, 1, 0, 2)[int(tt * 1.5) % 6]))
        rot = mk.rotate(math.degrees(0.15 * math.sin(t)), resample=Image.NEAREST, center=(mk.width // 2, 0), expand=False)
        im.alpha_composite(rot, (1520, ceil_y - 4))
        # criaturas
        tu = up(fr('toucan', (0, 0, 1, 0, 2, 2, 0, 3)[int(tt * 2) % 8]))
        im.alpha_composite(tu, (1440, ground_y + 4 - tu.height))
        fseq = (0, 0, 1, 0, 2, 3, 0, 0)
        fi = fseq[int(tt * 2) % 8]
        fg = up(fr('dart_frog', fi))
        im.alpha_composite(fg, (940, ground_y + 4 - fg.height - (12 if fi == 3 else 0)))
        df = up(fr('dragonfly', i % 2))
        dx_ = 900 + int(60 * math.sin(t) + 10 * math.sin(t * 3))
        dy_ = ground_y - 150 + int(20 * math.sin(t * 2))
        if math.cos(t) < 0: df = df.transpose(Image.FLIP_LEFT_RIGHT)
        im.alpha_composite(df, (dx_, dy_))
        # el monstruo y el escarabajo, para la escala
        im.alpha_composite(player_img(), (680, ground_y - 96))
        bt = beetle_img()
        im.alpha_composite(bt, (1150, ground_y - bt.height + 4))
        # partículas: hojas que caen de las copas, luciérnagas, brasas, polen
        if i % 6 == 0:
            parts.append([cb_x + random.randint(-90, 90), ground_y - 470, random.choice((-20, 20)), 30, 0, 'leaf'])
        if i % 9 == 4:
            parts.append([fx_ + random.randint(-60, 60), ground_y - 300, random.choice((-20, 20)), 30, 0, 'leaf'])
        if i % 3 == 0:
            for bx in (1230, 1490):
                parts.append([bx + 24 + random.randint(-8, 8), ground_y - 88, random.randint(-10, 10), -70, 0, 'ember'])
        if i % 8 == 0:
            parts.append([900 + random.randint(-20, 20), ground_y - 80, random.randint(-6, 6), -14, 0, 'pollen'])
        np_ = []
        for p in parts:
            p[4] += 1 / 12
            p[0] += p[2] / 12 + (math.sin(p[4] * 3 + p[0]) * 1.5 if p[5] == 'leaf' else 0)
            p[1] += p[3] / 12
            if p[5] == 'leaf': p[3] = min(60, p[3] + 2)
            life = {'leaf': 7, 'ember': 1.1, 'pollen': 3}[p[5]]
            if p[4] < life and p[1] < ground_y: np_.append(p)
        parts = np_
        for p in parts:
            if p[5] == 'leaf':
                sh, fw = fx['jungle_leaf']
                k = int(p[4] * 4) % 4
                im.alpha_composite(up(sh.crop((k * fw, 0, (k + 1) * fw, sh.height)), 3), (int(p[0]), int(p[1])))
            elif p[5] == 'ember':
                im.alpha_composite(Image.new('RGBA', (6, 3), (255, 160, 60, 255)), (int(p[0]), int(p[1])))
            else:
                sh, fw = fx['pollen']
                im.alpha_composite(up(sh.crop((0, 0, fw, sh.height)), 3).point(lambda v: v) , (int(p[0]), int(p[1])))
        # luciérnagas (en el ciclo)
        sh, fw = fx['firefly']
        for k in range(7):
            fxx = 300 + k * 160 + int(30 * math.sin(t + k * 1.7) + 12 * math.sin(t * 3 + k))
            fyy = ground_y - 60 - (k * 37) % 150 + int(18 * math.sin(t * 2 + k))
            fi = (int(tt * 3) + k) % 3
            add_glow(im, fxx + 7, fyy + 7, 14 + fi * 3, (200, 240, 90), 0.10 + 0.05 * fi)
            im.alpha_composite(up(sh.crop((fi * fw, 0, (fi + 1) * fw, sh.height)), 3), (fxx, fyy))
        # bruma rasante
        sh, fw = fx['mist']
        for k in range(3):
            mx = (int(tt * 25) + k * 430) % (SW + 200) - 100
            m_ = up(sh.crop((k * fw, 0, (k + 1) * fw, sh.height)), 6)
            m_.putalpha(m_.getchannel('A').point(lambda a: int(a * 0.22)))
            im.alpha_composite(m_, (mx, ground_y - 30))
        out.append(im.convert('RGB').convert('P', palette=Image.ADAPTIVE, colors=255))
    return out


def main():
    items, fx = build()
    os.makedirs(os.path.join(PREV, 'sprites', 'fx'), exist_ok=True)
    for name, e in items.items():
        for fn, im in file_names(name, e).items(): im.save(os.path.join(PREV, 'sprites', fn))
    for n, (im, fw) in fx.items(): im.save(os.path.join(PREV, 'sprites', 'fx', n + '-Sheet.png'))
    pv = preview(items, fx)
    pv.save(os.path.join(PREV, 'vista_previa.png'))
    print('  %s  %dx%d' % (os.path.join(PREV, 'vista_previa.png'), pv.width, pv.height))
    if '--no-gif' not in sys.argv:
        frs = maqueta(items, fx)
        frs[0].save(os.path.join(PREV, 'maqueta.gif'), save_all=True, append_images=frs[1:], duration=83, loop=0)
        print('  %s  %d cuadros' % (os.path.join(PREV, 'maqueta.gif'), len(frs)))
    if APPLY:
        os.makedirs(DEST, exist_ok=True)
        todo = [(os.path.join(DEST, fn), im) for name, e in items.items() if name not in NOT_APPLIED
                for fn, im in file_names(name, e).items()]
        todo += [(os.path.join(DEST_FX, n + '-Sheet.png'), im) for n, (im, fw) in fx.items()]
        for path, im in todo:
            if os.path.exists(path) and not FORCE:
                print('  %s ya existe: no se toca (--force)' % path); continue
            im.save(path)
            print('  %-60s %dx%d' % (path, im.width, im.height))
        register_anims(items, fx)


# Ritmo de lo que se anima (el resto: un cuadro); lo que ya esté en el conjunto no se toca (editor de animaciones)
ANIM_OPTS = {
    'stone_idol': {'durations': [1.6, 1.0]},                 # ojos apagados / brillan
    'stone_brazier': {'fps': 9},
    'mud_puddle': {'durations': [1.4, 0.5, 0.3]},            # la burbuja crece y revienta
    'dragonfly': {'fps': 16},
    'jungle_leaf': {'fps': 6}, 'firefly': {'fps': 4},
}


def register_anims(items, fx):
    """cada sprite aplicado = una animación con su nombre en assets/anim/world/decorations/jungle.json (y las
    partículas en .../fx.json), que es como las piden los tipos (DecoFx.anim)"""
    sys.path.insert(0, os.path.join(REPO, 'tools', 'anim'))
    from common import add_anims
    rel = lambda path: os.path.relpath(path, REPO).replace(os.sep, '/')
    ent = []
    for name, e in items.items():
        if name in NOT_APPLIED: continue
        img, fw, hang, layers = e
        for fn, im in file_names(name, e).items():
            n = fn[:-4].replace('-Sheet', '')
            ent.append((n, rel(os.path.join(DEST, fn)), None if layers or fw == im.width else fw, ANIM_OPTS.get(name)))
    n1 = add_anims('world/decorations/jungle', ent)
    fxe = []
    for n, (im, fw) in fx.items():
        p = rel(os.path.join(DEST_FX, n + '-Sheet.png'))
        if n == 'drip':                                       # (se forma y cae · salpica: DecoFx.drip)
            fxe += [('drip', p, fw, {'frames_of': [1, 2], 'durations': [0.5, 10], 'loop': False}),
                    ('drip_splash', p, fw, {'frames_of': [3]})]
        else:
            fxe.append((n, p, fw, ANIM_OPTS.get(n)))
    n2 = add_anims('world/decorations/fx', fxe)
    print('  animaciones nuevas: %d (jungle) + %d (fx)' % (n1, n2))


if __name__ == '__main__':
    main()
