#!/usr/bin/env python3
# tools/art/world/make_big_trees.py
# Árboles GRANDES (4-8 casillas de alto) y decoraciones nuevas para las islas, en el estilo de la casa
# (make_biome_art.py): cada parte = máscara + paleta de 4 tonos (contorno = el tono más oscuro de su propio
# color, nunca negro), luz de arriba a la izquierda, sombra abajo a la derecha, sin ruido, 1 px de margen.
# Arte a 1x; el juego lo dibuja a x4 (1 casilla = 16 px de arte).
#
# Por defecto SOLO hace la vista previa (no toca assets/):
#     /home/mtvemo/FlappyMonster_pruebas/arboles/vista_previa.png   catálogo x4 por isla, con el árbol actual y el monstruo
#     /home/mtvemo/FlappyMonster_pruebas/arboles/sprites/*.png      cada sprite a 1x
# --apply escribe en assets/images/world/decorations/<tema>/ (no pisa lo que existe salvo con --force).
# Las palmeras van en 3 capas del mismo tamaño (tronco, cocos, hojas) para que las hojas se mezan aparte,
# como foliage/palmtree.  Desde la raíz del repo:
#     ~/.venvs/fm-music/bin/python tools/art/world/make_big_trees.py [--apply [--force]] [nombre ...]
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont

APPLY = '--apply' in sys.argv
FORCE = '--force' in sys.argv
ONLY = {a for a in sys.argv[1:] if not a.startswith('--')}
PRUEBAS = os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas')
OUT = os.path.join(PRUEBAS, 'arboles')
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))


def rgb(h, a=255): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def pal(*hs): return tuple(rgb(h) for h in hs)


# ── Paletas (contorno, sombra, medio, luz) ──────────────────────────────────────────────────────────────────
LEAF = pal('0e3a1c', '1c6a34', '2e9a48', '62cc5a')         # = make_biome_art (arbusto tropical / roble)
LEAF_B = pal('0b2e17', '15502a', '1f7438', '2e9a48')       # el mismo verde, más hondo (bultos de detrás)
LEAF_D = pal('14281f', '1f4a37', '2f6b4f', '43896a')       # = pino nevado
LEAF_DB = pal('0f2018', '183a2c', '23553f', '2f6b4f')      # pino, piso de detrás
BIRCH_L = pal('24420e', '467a1c', '6eaa32', 'a6d65a')      # abedul: verde claro amarillento
BIRCH_LB = pal('1c360c', '355e16', '4f8a22', '6eaa32')
BARK = pal('2a1a10', '553620', '7a5030', 'a06e44')         # = make_biome_art
BIRCH = pal('4a4650', 'b4b0a6', 'dedad0', 'faf8f0')        # corteza blanca
BIRCH_MARK = rgb('2c2a30')
ROCK = pal('2e2826', '584e48', '7c7068', 'a09488')         # = estalagmita
MOSS = pal('1e3a12', '3a6a1e', '5aa040', '86c858')
PALM_T = pal('2e1c10', '6a4428', '93643c', 'bc8e5c')       # tronco de palmera (anillos)
PALM_L = pal('0c2800', '1f6a0a', '2f9a12', '6cc832')       # hojas (el verde vivo de la palmera actual)
PALM_LB = pal('0a2000', '1a560a', '237a0e', '2f9a12')
COCO = pal('1a1009', '54321d', '7a4a28', 'a0683a')
SAND = pal('6a4a24', 'b88c50', 'd8b070', 'f0d498')
DRIFT = pal('3e342c', '847462', 'ac9c88', 'd4cab8')        # madera de deriva, blanqueada
DUNE = pal('34400e', '647e24', '92aa40', 'c4d470')         # hierba de duna
SHELL = pal('7a4a3a', 'd89a80', 'f4c4a8', 'fff0e4')
SNOW = pal('5a6896', 'b0c0e4', 'dce6fa', 'ffffff')
ICE_ROCK = pal('283040', '4e5a70', '6e7c94', '94a2b8')
CHAR = pal('180f0d', '30201c', '463028', '604234')         # = make_biome_art
BASALT = pal('200d10', '3e1a1c', '5c2a26', '804238')
ASH = pal('4c1e18', '8c3e2c', 'b25c3c', 'd88856')
OBSID = pal('120a18', '281c34', '3e2e4e', '604e78')
EMBER, EMBER_D, EMBER_L = rgb('ff8a2a'), rgb('c8401c'), rgb('ffd060')
GLOW = pal('0e3a44', '229aa8', '4fe0e6', 'd8fcff')         # = seta luminosa de la cueva
GLOW_P = pal('2a1050', '6a32b0', 'a060e8', 'e4c8ff')       # seta luminosa morada
STEM = pal('5e5444', 'a89c80', 'e8e0cc', 'fffaf0')
GILL = pal('0a2a32', '125460', '1c7480', '2a94a0')
ROOTS = pal('22180e', '4a3420', '6a4c30', '8c6a44')
STONE = pal('2a2a3a', '4f4f66', '6e6e88', '9696ae')        # piedra de la fortaleza (= muralla del fondo)
GNARL = pal('221a18', '4a3c34', '6a584a', '8c7a68')        # corteza vieja, gris parda
OLIVE = pal('1a2a10', '35501e', '50722c', '76964a')        # copa del árbol viejo
IVY = pal('0e2a14', '1f5a2a', '3a8a3a', '6ab848')
CYPRESS = pal('0c2418', '17402a', '245c3a', '3a7a4c')
CYPRESS_B = pal('091c12', '113222', '1a4a2e', '245c3a')
RED = pal('5a0e10', 'a01e1e', 'd8322c', 'f05a48')          # = make_biome_art
GOLD = pal('7a4a08', 'd89a10', 'f8c820', 'ffe868')         # = SUN
TERRA = pal('4a1e12', '8a3e22', 'b45e34', 'd8844c')        # barro cocido
FLOWER_P = pal('4a1a50', '8a3aa0', 'c070d8', 'ecb0ff')
PETAL = pal('8a8070', 'd8d0c0', 'f0ead8', 'ffffff')
WHITE = rgb('ffffff')


# ── Geometría ────────────────────────────────────────────────────────────────────────────────────────────
def seg_t(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    L2 = vx * vx + vy * vy
    t = 0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / L2))
    qx, qy = ax + vx * t, ay + vy * t
    return t, math.hypot(px - qx, py - qy)


class Limb:
    """Rama / tronco: polilínea con radio que va de r0 a r1 a lo largo. inside(x,y); s(x,y) = longitud recorrida."""
    def __init__(self, pts, r0, r1=None):
        self.pts = pts
        self.r0, self.r1 = r0, (r0 if r1 is None else r1)
        self.cum = [0.0]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]): self.cum.append(self.cum[-1] + math.hypot(bx - ax, by - ay))
        self.L = max(1e-6, self.cum[-1])
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        r = max(self.r0, self.r1) + 1
        self.bb = (min(xs) - r, min(ys) - r, max(xs) + r, max(ys) + r)

    def near(self, x, y):
        best = None
        for i, ((ax, ay), (bx, by)) in enumerate(zip(self.pts, self.pts[1:])):
            t, d = seg_t(x, y, ax, ay, bx, by)
            s = self.cum[i] + t * (self.cum[i + 1] - self.cum[i])
            u = s / self.L
            rr = self.r0 + (self.r1 - self.r0) * u
            if best is None or d - rr < best[0]: best = (d - rr, s, u)
        return best

    def __call__(self, x, y):
        cx, cy = x + 0.5, y + 0.5
        b = self.bb
        if not (b[0] <= cx <= b[2] and b[1] <= cy <= b[3]): return False
        return self.near(cx, cy)[0] <= 0


def bez(p0, p1, p2, n=12, p3=None):
    """puntos de una curva de Bézier (cuadrática, o cúbica con p3)"""
    out = []
    for i in range(n + 1):
        t = i / n
        if p3 is None:
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        else:
            a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
            x = a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0]
            y = a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]
        out.append((x, y))
    return out


def ell(cx, cy, rx, ry):
    return lambda x, y: ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1


def blob(cx, cy, rx, ry, amp=0.1, ph=0.0, step=6.0):
    """bulto de hojas: elipse con el borde ondulado (lóbulos redondos de ~step px), no un círculo liso"""
    n = max(4, int(round(2 * math.pi * math.sqrt((rx * rx + ry * ry) / 2) / step)))
    def f(x, y):
        dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        a = math.atan2(dy, dx)
        r = 1 + amp * math.cos(a * n + ph) - amp * 0.3
        return dx * dx + dy * dy <= r * r
    return f


def union(*fs): return lambda x, y: any(f(x, y) for f in fs)


def minus(f, g): return lambda x, y: f(x, y) and not g(x, y)


# ── Lienzo por partes ────────────────────────────────────────────────────────────────────────────────────
class Canvas:
    """Como Canvas de make_biome_art, con más formas de sombrear (parte = máscara + paleta de 4 tonos):
       'box'  la de la casa (posición en su caja)        'ball' bulto redondo (luz arriba-izq., sombra abajo-der.)
       'cyl'  tronco vertical (luz a la izq. de la fila)  'rim'  ramas finas (filo de arriba-izq. claro, de abajo-der. oscuro)
       'leaf' hoja / fronda (filo de arriba claro, de abajo oscuro)                                    'flat' un tono
    edge = cómo se ve su borde contra OTRA parte que tiene detrás: 'out' contorno, 'dark' tono de sombra, 'none' nada.
    occl = recibe la sombra de las partes de delante que tiene justo encima (profundidad entre bultos).
    tex(x, y, tono) -> tono: dibujo propio (anillos, manchas)."""
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.pid = np.full((h, w), -1, dtype=np.int32)
        self.parts = []
        self.dots = []

    def part(self, inside, pal, mode='box', k=0.3, edge='out', occl=False, center=None, tex=None, light=True):
        pid = len(self.parts)
        m = np.zeros((self.h, self.w), dtype=bool)
        for y in range(self.h):
            for x in range(self.w):
                if inside(x, y): m[y, x] = True
        if not m.any(): return pid
        self.pid[m] = pid
        ys, xs = np.nonzero(m)
        self.parts.append(dict(pal=pal, mode=mode, k=k, edge=edge, occl=occl, center=center, tex=tex,
                               box=(xs.min(), ys.min(), xs.max(), ys.max()), light=light))
        return pid

    def dot(self, x, y, col, on=None):
        """un píxel encima (on = solo si cae sobre esa parte)"""
        self.dots.append((int(x), int(y), col, on))

    def mask_of(self, pids):
        return np.isin(self.pid, list(pids))

    def cap(self, pids, depth, pal, mode='flat', edge='out', extra=None, grow=0):
        """capa encima de lo que da al cielo (nieve, ceniza): los primeros `depth` px de las partes `pids`
        que tienen aire encima, y `grow` px más por encima de esa cara (la nieve se apila)"""
        P = self.pid
        src = np.isin(P, list(pids))
        m = np.zeros_like(src)
        for y in range(self.h):
            for x in range(self.w):
                if not src[y, x]: continue
                for d in range(1, depth + 1):
                    if y - d < 0 or P[y - d, x] == -1:
                        m[y, x] = True
                        if d == 1:
                            for g in range(1, grow + 1):
                                if y - g >= 0 and P[y - g, x] == -1: m[y - g, x] = True
                        break
                    if not src[y - d, x]: break
        if extra is not None:
            for y in range(self.h):
                for x in range(self.w):
                    if extra(x, y): m[y, x] = True
        return self.part(lambda x, y: m[y, x], pal, mode, edge=edge)

    def image(self):
        P, H, W = self.pid, self.h, self.w
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        get = lambda x, y: P[y, x] if 0 <= x < W and 0 <= y < H else -1
        # extensión por filas / columnas de cada parte (para 'cyl')
        for y in range(H):
            for x in range(W):
                p = P[y, x]
                if p < 0: continue
                d = self.parts[p]
                out, dark, mid, lig = d['pal']
                nb = [get(x + 1, y), get(x - 1, y), get(x, y + 1), get(x, y - 1)]
                c = None
                if any(q == -1 for q in nb):
                    c = out
                elif any(q != p and q < p for q in nb):          # borde contra una parte de detrás
                    if d['edge'] == 'out': c = out
                    elif d['edge'] == 'dark': c = dark
                if c is None:
                    c = self.shade(x, y, p, d, get)
                    if d['occl']:
                        for (dx, dy) in ((0, -1), (0, -2), (-1, -1), (1, -1)):
                            q = get(x + dx, y + dy)
                            if q > p and self.parts[q]['pal'] is not None:
                                c = dark; break
                    if d['tex']: c = d['tex'](x, y, c)
                im.putpixel((x, y), c)
        for x, y, col, on in self.dots:
            if 0 <= x < W and 0 <= y < H and P[y, x] >= 0 and (on is None or P[y, x] == on): im.putpixel((x, y), col)
        return im

    def shade(self, x, y, p, d, get):
        out, dark, mid, lig = d['pal']
        mode, k = d['mode'], d['k']
        x0, y0, x1, y1 = d['box']
        own = lambda dx, dy: get(x + dx, y + dy) == p
        if mode == 'flat':
            return lig if not own(0, -1) and d['light'] else mid
        if mode == 'box':
            u = ((x - x0) / max(1, x1 - x0) - 0.5) * 1.2 + ((y - y0) / max(1, y1 - y0) - 0.5) * 0.8
            c = dark if u > k else mid
            if not own(0, -1) or (not own(0, -2) and (x - x0) < (x1 - x0) * 0.6): c = lig
            elif not own(-1, 0) and u < 0.2: c = lig
            return c
        if mode == 'ball':
            if d['center']: cx, cy, rx, ry = d['center']
            else: cx, cy, rx, ry = (x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2, (x1 - x0 + 1) / 2, (y1 - y0 + 1) / 2
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            u = 0.62 * dx + 0.78 * dy
            r = math.hypot(dx, dy)
            if u > k and r > 0.35: return dark
            if (not own(0, -1) or not own(-1, 0)) and u < 0.1: return lig
            if u < -0.38 and r > 0.4: return lig
            return mid
        if mode == 'cyl':
            l = x
            while own(l - x - 1, 0): l -= 1
            r = x
            while own(r - x + 1, 0): r += 1
            t = (x - l + 0.5) / max(1, r - l + 1)
            if r - l <= 1: return mid
            if t < 0.3: return lig
            if t > 1 - k: return dark
            return mid
        if mode == 'rim':
            if not own(0, -1) or not own(-1, 0) or not own(-1, -1): return lig
            if not own(1, 1) or not own(0, 1) or not own(1, 0) or (k > 0.5 and (not own(0, 2) or not own(2, 0))): return dark
            return mid
        if mode == 'leaf':
            if not own(0, -1): return lig
            if not own(0, 1) or (k > 0.5 and not own(0, 2)): return dark
            return mid
        return mid


def finish(img, hang=False):
    """1 px de margen a los lados y arriba (abajo si cuelga)"""
    out = Image.new('RGBA', (img.width + 2, img.height + 1), (0, 0, 0, 0))
    out.paste(img, (1, 0 if hang else 1))
    return out


def layers_pad(imgs):
    return [finish(i) for i in imgs]


def compose(imgs):
    out = Image.new('RGBA', imgs[0].size, (0, 0, 0, 0))
    for i in imgs: out.alpha_composite(i)
    return out


# ── Ayudas de árboles ──────────────────────────────────────────────────────────────────────────────────
def crown(c, clumps, pals, k=0.35, edge='dark', step=6, amp=0.1):
    """copa hecha de bultos: clumps = [(cx, cy, rx, ry, capa)], pintados en orden (los de delante al final);
    capa 0 = de detrás (paleta más honda), 1 = de delante"""
    ids = []
    for i, (cx, cy, rx, ry, layer) in enumerate(clumps):
        ids.append(c.part(blob(cx, cy, rx, ry, amp, ph=i * 1.7, step=step), pals[layer], 'ball', k,
                          edge=edge, occl=True, center=(cx - rx * 0.1, cy - ry * 0.15, rx, ry)))
    return ids


def leaf_marks(c, clumps, col, seed=1, every=7):
    """unas pocas marcas de hoja (2 px) dentro de cada bulto, en la parte en sombra: textura sin ruido"""
    rnd = random.Random(seed)
    for (cx, cy, rx, ry, layer) in clumps:
        for _ in range(max(1, int(rx * ry / (every * every)))):
            a = rnd.uniform(-0.3, 1.9)
            r = rnd.uniform(0.35, 0.75)
            x, y = int(cx + math.cos(a) * rx * r), int(cy + math.sin(a) * ry * r)
            c.dot(x, y, col); c.dot(x + 1, y - 1, col)


def tree_branches(rnd, x, y, ang, length, r, depth, out, spread=0.55, shrink=0.72, curl=0.0):
    """ramas recursivas (árbol muerto): añade Limbs a out"""
    pts = [(x, y)]
    n = 4
    a = ang
    for i in range(n):
        a += rnd.uniform(-0.25, 0.25) + curl
        x += math.cos(a) * length / n
        y += math.sin(a) * length / n
        pts.append((x, y))
    out.append(Limb(pts, r, max(0.6, r * shrink)))
    if depth <= 0: return
    kids = 2 if depth > 1 or rnd.random() < 0.7 else 1
    for j in range(kids):
        s = (-1 if j == 0 else 1) * spread * rnd.uniform(0.7, 1.2)
        tree_branches(rnd, x, y, a + s, length * rnd.uniform(0.62, 0.8), max(0.6, r * shrink), depth - 1, out,
                      spread, shrink, curl)


# ══ PRADERA ═════════════════════════════════════════════════════════════════════════════════════════════
def big_oak():
    """roble grande (90x96): tronco con raíces, 3 ramas maestras que asoman entre los bultos de la copa"""
    W, H = 90, 96
    c = Canvas(W, H)
    cx = 45
    trunk = Limb([(cx, H + 1), (cx - 0.5, 80), (cx + 0.5, 66), (cx, 56)], 6.2, 4.2)
    roots = union(Limb([(cx - 2, 88), (cx - 9, 93), (cx - 13, H + 1)], 3.2, 1.6),
                  Limb([(cx + 2, 88), (cx + 9, 93), (cx + 14, H + 1)], 3.2, 1.6))
    t = c.part(union(trunk, roots), BARK, 'cyl', 0.38)
    br = union(Limb([(cx - 1, 66), (cx - 10, 56), (cx - 22, 48)], 3.4, 1.6),
               Limb([(cx + 1, 63), (cx + 11, 54), (cx + 23, 47)], 3.4, 1.6),
               Limb([(cx, 58), (cx - 2, 46), (cx + 1, 36)], 3.2, 1.8),
               Limb([(cx - 14, 53), (cx - 20, 58)], 1.6, 1.0),
               Limb([(cx + 15, 51), (cx + 22, 56)], 1.6, 1.0))
    c.part(br, BARK, 'rim', 0.6, edge='none')
    # copa en 3 pisos: un relleno hondo detrás, el piso de abajo (sombra), el del medio y el de arriba (luz);
    # cada piso tapa al de abajo, así cada bulto echa su sombra sobre el de debajo
    c.part(union(ell(cx, 26, 30, 16), ell(cx - 26, 38, 10, 7), ell(cx + 26, 37, 10, 7)), LEAF_B, 'box', 0.2)
    clumps = [
        (cx - 33, 49, 11, 8, 0), (cx - 15, 51, 9, 6, 0), (cx + 15, 50, 9, 6, 0), (cx + 33, 48, 11, 8, 0),
        (cx - 25, 37, 14, 11, 0), (cx, 39, 14, 10, 0), (cx + 25, 36, 14, 11, 0),
        (cx - 28, 30, 10, 8, 1), (cx - 14, 21, 14, 11, 1), (cx + 14, 20, 14, 11, 1), (cx + 29, 28, 10, 8, 0),
        (cx, 10, 13, 9, 1),
    ]
    crown(c, clumps, (LEAF_B, LEAF), k=0.38, step=7, amp=0.08)
    for (x, y) in ((cx + 2, 76), (cx - 2, 70), (cx + 1, 86)):
        c.dot(x, y, BARK[1], t); c.dot(x, y + 1, BARK[1], t)
    c.dot(cx - 2, 81, BARK[0], t); c.dot(cx - 2, 82, BARK[0], t)   # nudo
    return finish(c.image())


def big_birch():
    """abedul (54x104): tronco blanco con marcas negras, copa alta, clara y ligera (bultos sueltos que cuelgan,
    con huecos por los que se ven las ramas)"""
    W, H = 54, 104
    c = Canvas(W, H)
    pts = bez((26, H + 1), (24, 60), (29, 4), n=20)
    t = c.part(union(Limb(pts, 3.2, 1.4), Limb([(26, H - 3), (21, H + 1)], 2.0, 1.4),
                     Limb([(27, H - 3), (32, H + 1)], 2.0, 1.4)), BIRCH, 'cyl', 0.36)
    # marcas: rayas cortas horizontales (lenticelas) a lo largo del tronco, alternando lados
    for i, y in enumerate(range(H - 5, 6, -4)):
        xs = [p[0] for p in pts if abs(p[1] - y) < 3]
        x = round(sum(xs) / len(xs)) if xs else 27
        x0 = x - 2 if i % 2 else x
        for dx in range(2 if i % 3 else 3): c.dot(x0 + dx, y, BIRCH_MARK, t)
    br = union(Limb(bez((25, 66), (14, 56), (8, 60), n=8), 1.4, 0.7), Limb(bez((26, 58), (38, 46), (45, 52), n=8), 1.4, 0.7),
               Limb(bez((27, 44), (18, 34), (12, 38), n=8), 1.2, 0.7), Limb(bez((28, 36), (37, 26), (42, 30), n=8), 1.2, 0.7),
               Limb(bez((28, 24), (22, 16), (19, 18), n=6), 1.0, 0.6))
    c.part(br, BIRCH, 'rim', 0.4, edge='none')
    clumps = [
        (27, 12, 8, 9, 0), (17, 30, 8, 8, 0), (38, 28, 8, 8, 0), (12, 50, 8, 8, 0), (41, 46, 8, 9, 0), (27, 38, 6, 7, 0),
        (28, 6, 6, 5, 1), (21, 18, 6, 6, 1), (34, 16, 6, 6, 1), (11, 36, 6, 6, 1), (44, 34, 6, 6, 1),
        (21, 42, 6, 5, 1), (33, 40, 5, 5, 1), (7, 58, 5, 6, 1), (17, 56, 6, 6, 1), (38, 56, 6, 6, 1), (47, 56, 5, 6, 1),
        (27, 28, 6, 5, 1),
    ]
    crown(c, clumps, (BIRCH_LB, BIRCH_L), step=4.5, amp=0.12)
    return finish(c.image())


def fir(W, H, tiers, palf, palb, trunk_h=10, snow=False, seed=0):
    """abeto: pisos de ramas que caen en las puntas (cada piso de arriba tapa al de abajo: sombra debajo)"""
    c = Canvas(W, H)
    cx = W / 2
    c.part(union(Limb([(cx, H + 1), (cx, H - trunk_h - 6)], 2.6, 2.0),
                 Limb([(cx - 1, H - 2), (cx - 5, H + 1)], 1.6, 1.0), Limb([(cx + 1, H - 2), (cx + 5, H + 1)], 1.6, 1.0)),
           BARK, 'cyl', 0.4)
    top, bot = 1, H - trunk_h
    ids = []
    for i in range(tiers):
        f = i / (tiers - 1)
        yb = bot - (bot - top) * f * 0.86
        hh = (bot - top) * (0.30 - 0.12 * f)
        yt = yb - hh
        hw = (W / 2 - 1.5) * (1 - f * 0.82)
        def m(x, y, yt=yt, yb=yb, hw=hw, i=i):
            dx = x + 0.5 - cx
            if abs(dx) > hw: return False
            q = abs(dx) / hw
            ybot = yb - 2.5 * (1 - q) ** 2 + 1.5 * q * q
            if ((int(abs(dx)) + i) % 4) == 0 and abs(dx) > 2: ybot -= 1.4      # puntas de las ramas
            ytop = yt + (yb - yt) * (q ** (0.62 if snow else 0.85))
            return ytop <= y + 0.5 <= ybot
        tex = None
        if snow:
            # nieve DENTRO del piso (el contorno verde la rodea, como el pino nevado): los primeros px de su cara
            # de arriba, más gruesa hacia las puntas; en la sombra del piso de arriba, nieve en sombra
            def tex(x, y, t, yt=yt, yb=yb, hw=hw, palf=palf):
                if t == palf[0]: return t
                q = abs(x + 0.5 - cx) / hw
                if q < 0.1: return t
                ytop = yt + (yb - yt) * (min(1, q) ** 0.62)
                th = 2.6 + 3.0 * q
                if y + 0.5 > ytop + th: return t
                if t == palf[1]: return SNOW[1]
                return SNOW[3] if y + 0.5 <= ytop + 2.2 else SNOW[2]
        ids.append(c.part(m, palf, 'box', 0.25, edge='dark', occl=True, tex=tex))
    tip_tex = (lambda x, y, t: t if t == palf[0] or y > top + 3 else (SNOW[3] if x + 0.5 <= cx + 0.5 else SNOW[1])) if snow else None
    ids.append(c.part(lambda x, y: abs(x + 0.5 - cx) <= max(0.6, (y - top + 0.5) * 0.28) and top <= y <= top + 8,
                      palf, 'box', 0.3, edge='none', tex=tip_tex))
    return c, ids


def big_fir():
    """abeto alto (50x112): 7 pisos, verde oscuro de la casa"""
    c, _ = fir(50, 112, 7, LEAF_D, LEAF_DB, trunk_h=10)
    return finish(c.image())


def oak_bush():
    """seto / avellano (34x20): 4 bultos"""
    c = Canvas(34, 20)
    cl = [(9, 13, 8, 7, 0), (25, 12, 9, 8, 0), (17, 9, 9, 8, 1), (8, 14, 6, 5, 1), (27, 14, 6, 5, 1)]
    crown(c, cl, (LEAF_B, LEAF), step=4)
    for x, y in ((14, 6), (21, 9), (6, 12), (28, 11)): c.dot(x, y, RED[2])
    return finish(c.image())


def stump():
    """tocón (20x12) con anillos y setas"""
    c = Canvas(20, 13)
    c.part(union(lambda x, y: 4 <= x <= 14 and 3 <= y <= 12, Limb([(5, 10), (1, 12.9)], 1.8, 1.2),
                 Limb([(13, 10), (18, 12.9)], 1.8, 1.2)), BARK, 'cyl', 0.38)
    c.part(ell(9.5, 3.5, 5.5, 2.2), pal('5a3a1c', '9a6e40', 'c89a62', 'e0b67c'), 'flat', light=False)
    for x in (7, 8, 9, 10, 11, 12): c.dot(x, 3 if x in (7, 12) else 3, rgb('9a6e40'))
    c.dot(9, 3, rgb('5a3a1c')); c.dot(10, 3, rgb('5a3a1c'))
    c.part(ell(16.5, 9, 2.2, 1.6), RED, 'ball', 0.2)
    c.part(lambda x, y: x == 16 and 10 <= y <= 12, STEM, 'flat')
    c.dot(16, 8, WHITE)
    return finish(c.image())


def boulder():
    """roca grande con musgo (26x16)"""
    c = Canvas(26, 16)
    r = c.part(union(blob(11, 10, 10, 7, 0.06, 0.4, 7), blob(19, 11.5, 6.5, 4.8, 0.06, 1, 6)), ROCK, 'ball', 0.25,
               center=(12, 8, 13, 9))
    c.cap([r], 2, MOSS, 'flat', edge='dark')
    return finish(c.image())


def lupines():
    """altramuces (18x20): espigas cónicas de flores sobre una mata de hojas"""
    c = Canvas(18, 20)
    spikes = ((4, 15, FLOWER_P), (9, 19, PETAL), (14, 13, FLOWER_P))
    for (x0, h, p) in spikes:
        c.part(lambda x, y, a=x0, h=h: x == a and 20 - h + 6 <= y, LEAF, 'flat')
    c.part(union(blob(5, 18, 5, 3, 0.15, 0, 3), blob(13, 18, 5, 3, 0.15, 1, 3), blob(9, 17, 4, 3, 0.15, 2, 3)), LEAF, 'ball', 0.2)
    for (x0, h, p) in spikes:
        c.part(lambda x, y, a=x0, h=h: 20 - h <= y <= 20 - h + 8 and abs(x + 0.5 - a - 0.5) <= 0.6 + (y - (20 - h)) * 0.2,
               p, 'cyl', 0.4, tex=lambda x, y, t, p=p, h=h: p[1] if (y - (20 - h)) % 2 == 1 and t == p[2] else t)
    return finish(c.image())


# ══ COSTA ═══════════════════════════════════════════════════════════════════════════════════════════════
def frond(cx, cy, ang, length, droop, width):
    """fronda de cocotero: nervio que sube y cae + foliolos apretados que cuelgan hacia fuera y hacia la punta,
    con el filo de abajo en dientes de sierra (los foliolos)"""
    width *= 1.25
    ca, sa = math.cos(ang), math.sin(ang)
    ex, ey = cx + ca * length, cy + sa * length + droop
    mx, my = cx + ca * length * 0.5, cy + sa * length * 0.5 - droop * 0.5 - length * 0.12
    n = max(10, int(length * 1.6))
    rib = bez((cx, cy), (mx, my), (ex, ey), n=n)
    shapes = [Limb(rib, 1.2, 0.5)]
    s = 0.0
    for i in range(1, len(rib)):
        t = i / (len(rib) - 1)
        x, y = rib[i]
        px, py = rib[i - 1]
        tx, ty = x - px, y - py
        ln = math.hypot(tx, ty) or 1
        s += ln
        tx, ty = tx / ln, ty / ln
        nx, ny = -ty, tx
        if ny < 0 or (abs(ny) < 0.2 and nx * ca < 0): nx, ny = -nx, -ny     # la normal "de abajo"
        L = width * math.sin(math.pi * min(1.0, t * 1.1)) ** 0.55 * (0.4 + 0.6 * ((s % 4.0) / 4.0))
        dx, dy = nx * 0.72 + tx * 0.7, ny * 0.72 + tx * 0.0 + ty * 0.7 + 0.25
        dl = math.hypot(dx, dy) or 1
        shapes.append(Limb([(x, y), (x + dx / dl * L, y + dy / dl * L)], 0.8, 0.55))
        # foliolos de arriba, cortos
        ux, uy = -nx * 0.6 + tx * 0.8, -ny * 0.6 + ty * 0.8
        ul = math.hypot(ux, uy) or 1
        Lu = L * 0.22
        if Lu > 1.6: shapes.append(Limb([(x, y), (x + ux / ul * Lu, y + uy / ul * Lu)], 0.7, 0.5))
    return union(*shapes), rib


def palm(W, H, trunk_pts, crown_xy, fronds_spec, coconuts, r0=4.2, r1=2.8, extra_trunks=()):
    """palmera en 3 capas (tronco, cocos, hojas) del mismo tamaño. fronds_spec = [(ang_deg, largo, caída, ancho, detrás?)]"""
    ct = Canvas(W, H)
    for (tp, a, b) in [(trunk_pts, r0, r1)] + list(extra_trunks):
        lim = Limb(tp, a, b)
        x0 = tp[0][0]
        base = union(Limb([(x0 - 6, H + 1), (x0 - 1, H - 6)], 2.0, 1.4), Limb([(x0 + 6, H + 1), (x0 + 1, H - 6)], 2.0, 1.4),
                     Limb([(x0, H + 1), (x0, H - 7)], a + 1.6, a))
        def ring(x, y, t, lim=lim):
            s = lim.near(x + 0.5, y + 0.5)[1]
            if int(s) % 4 == 0 and t != PALM_T[0]: return PALM_T[1] if t != PALM_T[3] else PALM_T[2]
            return t
        ct.part(union(lim, base), PALM_T, 'cyl', 0.36, tex=ring)
    trunk = ct.image()
    cc = Canvas(W, H)
    for (x, y) in coconuts:
        cc.part(ell(x, y, 2.8, 2.8), COCO, 'ball', 0.15)
    coco = cc.image()
    cf = Canvas(W, H)
    crowns = crown_xy if isinstance(crown_xy, list) else [crown_xy]
    specs_all = fronds_spec if isinstance(crown_xy, list) else [fronds_spec]
    for back in (True, False):
        for (fx, fy), specs in zip(crowns, specs_all):
            for (a, L, d, w, b) in specs:
                if b != back: continue
                m, rib = frond(fx, fy, math.radians(a), L, d, w)
                cf.part(m, PALM_LB if back else PALM_L, 'leaf', 0.6, edge='out', occl=not back)
    for (fx, fy) in crowns:
        cf.part(ell(fx, fy + 0.5, 3.4, 2.6), PALM_L, 'ball', 0.2, edge='out')
    leaves = cf.image()
    return layers_pad([trunk, coco, leaves])


def coconut_palm():
    """cocotero alto y curvo (66x112): tronco con anillos que se inclina, frondas que cuelgan, cocos"""
    W, H = 80, 112
    cx, cy = 46, 26
    tp = bez((32, H + 1), (28, 62), (cx, cy), n=18)
    fr = [(-165, 28, 8, 5.5, True), (-120, 20, 6, 5, True), (-60, 20, 6, 5, True), (-15, 28, 8, 5.5, True),
          (-178, 32, 20, 6.5, False), (-142, 26, 12, 6, False), (-95, 15, 3, 4.5, False), (-42, 26, 12, 6, False),
          (-2, 32, 20, 6.5, False), (145, 18, 16, 5.5, False), (35, 18, 16, 5.5, False)]
    return palm(W, H, tp, (cx, cy), fr, [(cx - 3.5, cy + 4.5), (cx + 2.5, cy + 5), (cx - 0.5, cy + 7.5)])


def twin_palm():
    """dos cocoteros del mismo pie (88x112), uno más alto"""
    W, H = 92, 112
    t1 = bez((42, H + 1), (34, 70), (24, 26), n=18)
    t2 = bez((46, H + 1), (54, 78), (68, 46), n=18)
    fr1 = [(-160, 22, 8, 4.5, True), (-110, 16, 6, 4, True), (-55, 20, 6, 4.5, True),
           (-178, 24, 16, 5.5, False), (-135, 20, 10, 5, False), (-85, 12, 3, 4, False), (-30, 22, 12, 5.5, False),
           (5, 22, 18, 5, False), (135, 14, 16, 4.5, False)]
    fr2 = [(-150, 20, 8, 4.5, True), (-20, 22, 8, 4.5, True),
           (-175, 22, 16, 5, False), (-120, 16, 8, 4.5, False), (-70, 14, 6, 4.5, False), (-20, 22, 14, 5.5, False),
           (10, 22, 18, 5, False), (50, 14, 16, 4.5, False)]
    return palm(W, H, t2, [(24, 26), (68, 46)], [fr1, fr2],
                [(21, 30), (26, 30.5), (23.5, 33), (66, 50), (70.5, 50.5)], r0=3.8, r1=2.6,
                extra_trunks=[(t1, 4.0, 2.6)])


def young_palm():
    """palmera joven (40x44): tronco corto, frondas casi hasta el suelo"""
    W, H = 44, 44
    tp = bez((22, H + 1), (21, 32), (22, 20), n=10)
    fr = [(-160, 15, 6, 4, True), (-20, 15, 6, 4, True), (-100, 10, 3, 3.5, True),
          (-178, 18, 14, 4.5, False), (-130, 14, 8, 4.5, False), (-60, 14, 8, 4.5, False), (-2, 18, 14, 4.5, False),
          (135, 10, 10, 4, False), (45, 10, 10, 4, False)]
    return palm(W, H, tp, (22, 20), fr, [], r0=3.0, r1=2.4)


def beach_grass():
    """hierba de duna (18x14): briznas largas y finas que se doblan con el viento"""
    c = Canvas(18, 14)
    for (x0, h, lean) in ((2, 9, -0.5), (5, 13, -0.2), (8, 11, 0.35), (10, 14, 0.1), (13, 10, 0.6), (15, 8, 0.9)):
        pts = bez((x0, 14), (x0 + lean * h * 0.2, 14 - h * 0.6), (x0 + lean * h * 0.7, 14 - h), n=8)
        c.part(Limb(pts, 0.9, 0.5), DUNE, 'rim', 0.3, edge='out')
    return finish(c.image())


def driftwood():
    """tronco de deriva blanqueado (30x9) con una rama rota"""
    c = Canvas(30, 10)
    c.part(union(Limb([(2, 7.5), (14, 6.5), (27, 7.8)], 2.6, 1.8), Limb([(19, 6.5), (24, 2)], 1.3, 0.8),
                 Limb([(6, 7), (3, 3.5)], 1.1, 0.7)), DRIFT, 'rim', 0.6)
    c.part(ell(27.6, 7.8, 1.6, 2.0), pal('3e342c', '9a8a74', 'c4b49c', 'e2d8c4'), 'flat', light=False)
    for x in (9, 15, 21): c.dot(x, 7, DRIFT[1]); c.dot(x + 1, 7, DRIFT[1])
    return finish(c.image())


def beach_rocks():
    """piedras de playa con conchas (22x11)"""
    c = Canvas(22, 11)
    c.part(blob(8, 7, 7, 4.5, 0.05, 0, 7), ROCK, 'ball', 0.2)
    c.part(blob(16, 8.5, 5, 3, 0.05, 1, 6), ROCK, 'ball', 0.2)
    c.part(lambda x, y: 18 <= x <= 20 and 9 <= y <= 10 and not (x == 18 and y == 9), SHELL, 'flat')
    c.part(lambda x, y: 3 <= x <= 4 and 9 <= y <= 10, SHELL, 'flat')
    c.dot(19, 10, SHELL[1])
    c.cap([0], 1, MOSS, 'flat', edge='none') if False else None
    return finish(c.image())


# ══ NIEVE ═══════════════════════════════════════════════════════════════════════════════════════════════
def snowy_fir():
    """abeto nevado grande (56x112): nieve acumulada encima de cada piso (lo que da al cielo)"""
    c, ids = fir(56, 112, 7, LEAF_D, LEAF_DB, trunk_h=9, snow=True)
    return finish(c.image())


def snowy_fir_small():
    """abeto nevado joven (34x60): el mismo dibujo, 5 pisos"""
    c, ids = fir(34, 60, 5, LEAF_D, LEAF_DB, trunk_h=6, snow=True)
    return finish(c.image())


def snow_rock():
    c = Canvas(24, 14)
    r = c.part(union(blob(10, 9, 9, 6, 0.05, 0, 7), blob(18, 10.5, 5.5, 4, 0.05, 1, 6)), ICE_ROCK, 'ball', 0.25,
               center=(11, 7, 12, 8))
    c.cap([r], 3, SNOW, 'flat')
    return finish(c.image())


def snow_stump():
    c = Canvas(18, 14)
    t = c.part(union(lambda x, y: 4 <= x <= 13 and 4 <= y <= 13, Limb([(5, 11), (1, 13.9)], 1.8, 1.2),
                     Limb([(12, 11), (16.5, 13.9)], 1.8, 1.2)), BARK, 'cyl', 0.38)
    c.part(union(ell(9, 4, 6.5, 3), ell(4, 5.5, 2, 2)), SNOW, 'ball', 0.3)
    return finish(c.image())


def winter_grass():
    """hierba seca que asoma de la nieve (16x12)"""
    c = Canvas(16, 12)
    for (x0, h, lean) in ((3, 8, -0.4), (6, 11, 0.1), (9, 9, 0.5), (12, 7, 0.8)):
        pts = bez((x0, 12), (x0 + lean, 12 - h * 0.6), (x0 + lean * 3, 12 - h), n=6)
        c.part(Limb(pts, 0.9, 0.5), pal('4a3a1c', '8a7040', 'b8985a', 'dcc080'), 'rim', 0.3)
    c.part(blob(8, 12, 8, 3.2, 0.1, 0, 4), SNOW, 'flat')
    return finish(c.image())


# ══ VOLCÁN ══════════════════════════════════════════════════════════════════════════════════════════════
def dead_tree():
    """árbol muerto calcinado (80x92): tronco grueso y retorcido que se abre en Y, ramas que se afinan en punta y se
    tuercen, un muñón partido, una rama baja caída; brasas en las grietas y en un hueco"""
    W, H = 80, 92
    c = Canvas(W, H)
    L = lambda pts, a, b, n=10: Limb(bez(*pts, n=n) if len(pts) == 3 else pts, a, b)
    trunk = L([(40, H + 1), (35, 72), (42, 52)], 6.6, 4.4)
    roots = union(Limb([(37, H - 6), (29, H - 2), (22, H + 1)], 3.4, 1.2), Limb([(43, H - 6), (51, H - 3), (58, H + 1)], 3.2, 1.2),
                  Limb([(40, H - 3), (44, H + 1)], 3.0, 2.0))
    c.part(union(trunk, roots), CHAR, 'cyl', 0.4)
    limbs = union(
        L([(41, 55), (30, 46), (22, 30)], 4.2, 2.4), L([(27, 40), (14, 36), (6, 25)], 2.4, 0.7),
        L([(22, 31), (18, 18), (24, 7)], 2.2, 0.7), L([(14, 35), (9, 40), (8, 46)], 1.1, 0.6),
        L([(20, 22), (12, 16), (10, 10)], 1.2, 0.6),
        L([(43, 53), (55, 45), (60, 30)], 4.2, 2.4), L([(57, 41), (68, 38), (75, 28)], 2.2, 0.7),
        L([(60, 31), (57, 19), (63, 9)], 2.2, 0.7), L([(68, 38), (72, 44), (71, 49)], 1.1, 0.6),
        L([(58, 22), (66, 18), (69, 13)], 1.1, 0.6),
        Limb([(42, 54), (43, 41)], 3.2, 2.6),                                   # muñón partido
        L([(37, 70), (27, 64), (19, 67)], 2.4, 0.8),                            # rama baja que cae
    )
    c.part(limbs, CHAR, 'rim', 0.6, edge='none')
    c.part(ell(39.5, 77, 1.6, 2.6), pal('6e140c', 'c83c18', 'f07822', 'ffc848'), 'ball', 0.3, edge='out')   # hueco al rojo
    for (x, y, n) in ((41, 62, 4), (37, 84, 3), (43, 70, 3), (28, 42, 2), (55, 46, 2)):
        for i in range(n): c.dot(x + (i // 2), y + i, EMBER_D if i in (0, n - 1) else EMBER)
    c.dot(43, 41, EMBER); c.dot(42, 41, EMBER_D); c.dot(44, 41, EMBER_D)     # brasa en el muñón
    return finish(c.image())


def charred_stump():
    c = Canvas(20, 14)
    c.part(union(lambda x, y: 5 <= x <= 14 and (3 + (x % 3 == 0) * 1 + (x == 7) * -2) <= y <= 13,
                 Limb([(6, 11), (1.5, 13.9)], 1.8, 1.1), Limb([(13, 11), (18, 13.9)], 1.8, 1.1)), CHAR, 'cyl', 0.4)
    for (x, y) in ((9, 6), (9, 7), (10, 8)): c.dot(x, y, EMBER)
    c.dot(11, 10, EMBER_D)
    return finish(c.image())


def obsidian_shards():
    """agujas de obsidiana (18x16) con filo brillante"""
    c = Canvas(18, 16)
    for (x0, h, w, lean) in ((5, 11, 2.6, -0.25), (10, 15, 3.2, 0.1), (14, 8, 2.2, 0.35)):
        c.part(lambda x, y, a=x0, h=h, w=w, l=lean: 16 - h <= y and abs(x + 0.5 - a - l * (16 - y)) <= w * (y - (16 - h) + 0.5) / h,
               OBSID, 'cyl', 0.45)
    c.dot(9, 4, EMBER_D); c.dot(9, 6, EMBER)
    return finish(c.image())


def burnt_shrub():
    """matorral quemado grande (22x14), ramas finas"""
    c = Canvas(22, 14)
    rnd = random.Random(3)
    limbs = []
    for a in (-150, -120, -95, -70, -40):
        tree_branches(rnd, 11, 14, math.radians(a), 6, 1.2, 1, limbs, 0.6, 0.7)
    c.part(union(*limbs), CHAR, 'rim', 0.3)
    c.part(ell(11, 14.5, 5, 2.4), ASH, 'flat')
    c.dot(9, 13, EMBER)
    return finish(c.image())


# ══ CUEVA ═══════════════════════════════════════════════════════════════════════════════════════════════
def giant_mushroom(capc=GLOW, W=62, H=78):
    """seta gigante luminosa (62x78): pie grueso algo curvo con un anillo, sombrero ancho cuyo borde cae a los
    lados, láminas debajo y puntos que brillan"""
    c = Canvas(W, H)
    cx = W / 2
    gillp = GILL if capc is GLOW else pal('1e0a3a', '40206e', '583090', '7040b0')
    stem = Limb(bez((cx - 1, H + 1), (cx + 4, 52), (cx, 26), n=14), 4.6, 3.6)
    base = blob(cx - 1, H - 3.5, 8.5, 4.5, 0.1, 0.3, 5)
    c.part(union(stem, base), STEM, 'cyl', 0.4)
    # anillo: collar algo más ancho que el pie, con el filo de abajo ondulado
    c.part(lambda x, y: 38 <= y <= 41 + (1 if int(x) % 3 == 0 else 0) and abs(x + 0.5 - cx - 1.6) <= 5.8 + (y - 38) * 0.4,
           STEM, 'box', 0.4)
    rim = lambda x: 25 + 6 * (abs(x + 0.5 - cx) / 29) ** 2.2      # el borde baja hacia los lados
    c.part(lambda x, y: ell(cx, 25.5, 25, 6)(x, y) and y >= 24, gillp, 'flat', light=False,
           tex=lambda x, y, t: gillp[1] if (x % 3 == 0 and t != gillp[0]) else t)
    cap = lambda x, y: ell(cx, 27, 30, 25)(x, y) and y + 0.5 <= rim(x) + (1 if abs(x + 0.5 - cx) > 22 else 0)
    c.part(cap, capc, 'ball', 0.3, center=(cx - 3, 16, 30, 17))
    spot = pal('ffffff', 'e8ffff', 'f8ffff', 'ffffff') if capc is GLOW else pal('f8eaff', 'f0dcff', 'faf2ff', 'ffffff')
    for (x, y, r) in ((cx - 13, 11, 2.4), (cx + 6, 7, 2.8), (cx + 17, 15, 2.0), (cx - 3, 16, 1.6), (cx - 22, 20, 1.5),
                      (cx + 11, 21, 1.4), (cx + 23, 23, 1.2)):
        c.part(ell(x, y, r, r * 0.85), spot, 'flat', edge='none')
    for (x, y) in ((cx + 1, 50), (cx + 2, 60), (cx - 1, 66)):
        c.dot(x, y, capc[2]); c.dot(x, y + 1, capc[1])              # alguna espora luminosa pegada al pie
    return finish(c.image())


def mushroom_cluster():
    """corro de setas luminosas (22x14), tres alturas"""
    c = Canvas(22, 15)
    for (x0, h, r, p) in ((5, 8, 4, GLOW_P), (14, 13, 5.5, GLOW), (19, 6, 3, GLOW)):
        c.part(lambda x, y, a=x0, h=h: abs(x + 0.5 - a) <= 1.2 and 15 - h + 2 <= y, STEM, 'cyl', 0.4)
        c.part(lambda x, y, a=x0, h=h, r=r: ell(a, 15 - h + 2.2, r, r * 0.8)(x, y) and y <= 15 - h + 2, p, 'ball', 0.2)
        c.dot(x0 - 1, 15 - h, p[3])
    return finish(c.image())


def hanging_roots():
    """raíces que cuelgan del techo (26x32): se afinan y se abren en raicillas; gotas de luz en las puntas"""
    c = Canvas(26, 34)
    limbs = []
    for (x0, L, sw, fk) in ((4, 20, 1.2, 10), (9, 32, -1.0, 16), (14, 16, 1.4, 8), (18, 27, -1.2, 13), (22, 13, 0.8, 7)):
        pts = bez((x0, -1), (x0 + sw * 3, L * 0.5), (x0 - sw, L), n=12)
        limbs.append(Limb(pts, 1.6, 0.5))
        bx, by = pts[int(fk / L * 12)]
        limbs.append(Limb(bez((bx, by), (bx + sw * 2.5, by + 3), (bx + sw * 3, by + 7), n=5), 0.9, 0.5))
    c.part(union(*limbs), ROOTS, 'rim', 0.3)
    c.part(blob(13, 0, 13, 3.5, 0.15, 0, 5), pal('22180e', '4a3420', '584030', '6a4c30'), 'box', 0.3)
    c.part(blob(13, 0.5, 13, 2.5, 0.2, 1, 4), MOSS, 'flat', edge='none')
    for (x, y) in ((9.5, 31), (2.5, 19), (18.5, 26)):
        c.part(ell(x + 0.5, y + 0.5, 1.5, 1.7), GLOW, 'ball', 0.2, edge='out')
    return finish(c.image(), hang=True)


def cave_boulder():
    """roca de cueva con hongos de repisa luminosos (24x16)"""
    c = Canvas(24, 16)
    r = c.part(union(blob(11, 10, 10, 6.5, 0.06, 0.4, 7), blob(18, 11, 5.5, 5, 0.06, 1, 6)), ROCK, 'ball', 0.25,
               center=(12, 8, 13, 9))
    for (x, y, w) in ((3, 8, 3.2), (6, 5.5, 2.6), (20, 9, 2.8)):
        c.part(lambda xx, yy, x=x, y=y, w=w: ell(x, y, w, 1.6)(xx, yy) and yy <= y, GLOW, 'flat', edge='out')
    return finish(c.image())


# ══ FORTALEZA ═══════════════════════════════════════════════════════════════════════════════════════════
def old_tree():
    """árbol viejo y retorcido con hiedra (76x86): tronco grueso inclinado con un hueco, copa rala, hiedra que cuelga"""
    W, H = 76, 86
    c = Canvas(W, H)
    rnd = random.Random(11)
    trunk = Limb(bez((34, H + 1), (26, 64), (40, 44), n=14), 7.0, 4.2)
    roots = union(Limb([(31, H - 6), (22, H - 2), (16, H + 1)], 3.6, 1.4), Limb([(37, H - 6), (46, H - 3), (53, H + 1)], 3.4, 1.4),
                  Limb([(34, H - 3), (36, H + 1)], 3.0, 2.4))
    c.part(union(trunk, roots), GNARL, 'cyl', 0.4)
    limbs = []
    tree_branches(rnd, 39, 46, math.radians(-150), 18, 3.2, 2, limbs, 0.55, 0.65, 0.05)
    tree_branches(rnd, 41, 45, math.radians(-40), 15, 3.4, 2, limbs, 0.5, 0.65, -0.12)
    tree_branches(rnd, 40, 45, math.radians(-90), 14, 2.6, 1, limbs, 0.5, 0.65)
    c.part(union(*limbs), GNARL, 'rim', 0.6, edge='none')
    c.part(ell(32, 66, 2.6, 4), pal('140e0c', '140e0c', '221a18', '2a201c'), 'flat', edge='none', light=False)  # hueco
    clumps = [(16, 26, 11, 8, 0), (60, 24, 12, 8, 0), (38, 14, 14, 9, 0), (24, 18, 9, 7, 1), (52, 14, 10, 7, 1),
              (8, 32, 7, 5, 1), (64, 31, 8, 5, 1), (38, 7, 9, 6, 1)]
    crown(c, clumps, (pal('121e0a', '263c14', '35501e', '50722c'), OLIVE), step=4)
    # hiedra: tallos que bajan por el tronco y cuelgan de las ramas, con hojitas
    ivy = []
    for (pts) in (bez((40, 48), (30, 60), (36, 80), n=10), bez((10, 34), (11, 40), (9, 46), n=5),
                  bez((62, 33), (63, 40), (61, 44), n=5), bez((30, 52), (27, 60), (29, 70), n=6)):
        ivy.append(Limb(pts, 0.6, 0.6))
        for i, (x, y) in enumerate(pts[1:]):
            if i % 2 == 0: ivy.append(ell(x + (1.4 if i % 4 else -1.4), y, 1.6, 1.3))
    c.part(union(*ivy), IVY, 'box', 0.3)
    return finish(c.image())


def cypress():
    """ciprés (22x96): llama alta y estrecha, punta fina, de pequeños bultos verticales"""
    W, H = 22, 96
    c = Canvas(W, H)
    cx = W / 2
    c.part(lambda x, y: abs(x + 0.5 - cx) <= 1.6 and y >= H - 8, BARK, 'cyl', 0.4)
    def prof(y):          # semiancho a la altura y: punta arriba, más ancho hacia los 2/3, base algo recogida
        t = max(0.0, (y - 1) / (H - 9))
        return (W / 2 - 1.2) * min(1.0, (t / 0.62) ** 0.8) * (1 - max(0, t - 0.9) * 2.5)
    c.part(lambda x, y: abs(x + 0.5 - cx) <= prof(y) * 0.9 and 1 <= y <= H - 9, CYPRESS_B, 'box', 0.25)
    cl = []
    for i, y in enumerate(range(H - 13, 6, -6)):
        w = prof(y)
        offs = (-w * 0.42, w * 0.42) if w > 5 else (0,)
        for dx in offs:
            rx = max(2.0, (w * 0.62) if len(offs) > 1 else w * 0.95)
            cl.append((cx + dx + (0.6 if i % 2 else -0.6), y, rx, 5.5, 1))
    cl.sort(key=lambda k: -k[1])
    crown(c, cl, (CYPRESS_B, CYPRESS), k=0.2, edge='dark', step=5, amp=0.08)
    return finish(c.image())


def banner():
    """estandarte (14x34) que cuelga de un asta clavada en la muralla: rojo con borde dorado y cola en pico"""
    c = Canvas(14, 34)
    c.part(lambda x, y: 0 <= y <= 1 and 0 <= x <= 13, GNARL, 'flat')
    c.part(ell(0.5, 1, 1.6, 1.6), GOLD, 'flat'); c.part(ell(13.5, 1, 1.6, 1.6), GOLD, 'flat')
    def cloth(x, y):
        if not (2 <= x <= 11 and 2 <= y <= 33): return False
        return y <= 27 + abs(x + 0.5 - 7) * 1.2 if y > 27 else True
    c.part(cloth, RED, 'box', 0.4)
    c.part(lambda x, y: cloth(x, y) and (x in (3, 10)) and 3 <= y <= 27, GOLD, 'flat', edge='none')
    c.part(lambda x, y: ((x + 0.5 - 7) ** 2 / 6.5 + (y + 0.5 - 13) ** 2 / 9 <= 1) and not ((x + 0.5 - 7) ** 2 / 2 + (y + 0.5 - 13) ** 2 / 3.5 <= 1),
           GOLD, 'flat', edge='none')
    return finish(c.image(), hang=True)


def broken_column():
    """columna rota (22x40): basa, fuste estriado partido en diagonal, el trozo de arriba caído al lado"""
    c = Canvas(26, 40)
    c.part(lambda x, y: 1 <= x <= 16 and 36 <= y <= 39, STONE, 'box', 0.4)                 # basa
    c.part(lambda x, y: 2 <= x <= 15 and 33 <= y <= 35, STONE, 'box', 0.4)
    top = lambda x: 4 + (x - 4) * 0.9 + (3 if x in (8, 9) else 0) - (2 if x == 11 else 0)
    c.part(lambda x, y: 4 <= x <= 13 and top(x) <= y <= 32, STONE, 'cyl', 0.36,
           tex=lambda x, y, t: STONE[1] if x in (6, 9, 12) and t not in (STONE[0], STONE[3]) else t)
    c.part(union(lambda x, y: 17 <= x <= 25 and 33 <= y <= 39, lambda x, y: 16 <= x <= 25 and 31 <= y <= 32), STONE, 'box', 0.3)
    c.dot(19, 35, STONE[1]); c.dot(22, 35, STONE[1]); c.dot(19, 37, STONE[1]); c.dot(22, 37, STONE[1])
    ivy = []
    for (pts) in (bez((5, 14), (3, 22), (6, 34), n=8),):
        ivy.append(Limb(pts, 0.6, 0.6))
        for i, (x, y) in enumerate(pts[1:]):
            ivy.append(ell(x + (1.3 if i % 2 else -1.0), y, 1.6, 1.3))
    c.part(union(*ivy), IVY, 'box', 0.3)
    return finish(c.image())


def urn():
    """maceta de barro cocido con flores (16x18)"""
    c = Canvas(16, 18)
    for (x, y, p) in ((4, 4, RED), (8, 2, GOLD), (12, 5, RED), (6, 7, PETAL), (10, 6, FLOWER_P)):
        c.part(lambda xx, yy, x=x: abs(xx - x) == 0 and y + 2 <= yy <= 9, IVY, 'flat')
    c.part(lambda x, y: ell(8, 8.5, 6.5, 3)(x, y), IVY, 'ball', 0.2)
    for (x, y, p) in ((4, 4, RED), (8, 2, GOLD), (12, 5, RED), (6, 6, PETAL), (10, 6, FLOWER_P)):
        c.part(ell(x + 0.5, y + 0.5, 1.6, 1.6), p, 'ball', 0.3)
    c.part(lambda x, y: (9 <= y <= 10 and 1 <= x <= 14) or (11 <= y <= 17 and abs(x + 0.5 - 8) <= 5.5 - abs(y - 14) * 0.5),
           TERRA, 'cyl', 0.4)
    return finish(c.image())


def ivy_hang():
    """hiedra que cuelga de un muro (20x26)"""
    c = Canvas(20, 26)
    rnd = random.Random(4)
    parts = []
    for (x0, L) in ((3, 16), (8, 25), (13, 20), (17, 12)):
        pts = bez((x0, -1), (x0 + rnd.uniform(-2, 2), L * 0.5), (x0 + rnd.uniform(-1.5, 1.5), L), n=8)
        parts.append(Limb(pts, 0.6, 0.6))
        for i, (x, y) in enumerate(pts[1:]):
            parts.append(ell(x + (1.3 if i % 2 else -1.3), y, 1.7, 1.4))
    c.part(union(*parts), IVY, 'box', 0.3)
    return finish(c.image(), hang=True)


# ══ Catálogo ════════════════════════════════════════════════════════════════════════════════════════════
# (isla, suelo, [actuales], [(nombre, tema, función, capas?, cuelga?)])
D = 'assets/images/world/decorations/'
ISLANDS = [
    ('PRADERA', 'grass', ['meadow/oak_tree', 'meadow/pine_tree'], 'meadow', [
        ('big_oak', big_oak), ('big_birch', big_birch), ('big_fir', big_fir),
        ('hazel_bush', oak_bush), ('stump', stump), ('boulder', boulder), ('lupines', lupines)]),
    ('COSTA', 'sand', ['foliage/palmtree'], 'tropical', [
        ('coconut_palm', coconut_palm), ('twin_palm', twin_palm), ('young_palm', young_palm),
        ('beach_grass', beach_grass), ('driftwood', driftwood), ('beach_rocks', beach_rocks)]),
    ('NIEVE', 'snow', ['ice/snowy_pine'], 'ice', [
        ('snowy_fir', snowy_fir), ('snowy_fir_small', snowy_fir_small), ('snow_rock', snow_rock), ('snow_stump', snow_stump), ('winter_grass', winter_grass)]),
    ('VOLCAN', 'basalt', ['volcano/charred_tree'], 'volcano', [
        ('dead_tree', dead_tree), ('charred_stump', charred_stump), ('obsidian_shards', obsidian_shards),
        ('burnt_shrub', burnt_shrub)]),
    ('CUEVA', 'stone', ['cave/glow_mushroom'], 'cave', [
        ('giant_mushroom', giant_mushroom), ('giant_mushroom_violet', lambda: giant_mushroom(GLOW_P)),
        ('mushroom_cluster', mushroom_cluster), ('hanging_roots', hanging_roots), ('cave_boulder', cave_boulder)]),
    ('FORTALEZA', 'stone', [], 'fortress', [
        ('old_tree', old_tree), ('cypress', cypress), ('banner', banner), ('broken_column', broken_column),
        ('urn', urn), ('ivy_hang', ivy_hang)]),
]
HANGS = {'hanging_roots', 'banner', 'ivy_hang'}
LAYER_NAMES = ('trunk', 'coconuts', 'fronds')


def edge_check(name, img, hang):
    a = np.array(img)[:, :, 3]
    bad = a[:, 0].any() or a[:, -1].any() or (a[-1, :].any() if hang else a[0, :].any())
    if bad: print('  AVISO %s: toca el borde del lienzo' % name)


def write(path, img):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def load_current(rel):
    p = os.path.join(ROOT, D, rel)
    if os.path.isdir(p):
        return compose([Image.open(os.path.join(p, f)).convert('RGBA') for f in ('palmtree.png', 'coques.png', 'palmleaves.png')])
    return Image.open(p + '.png').convert('RGBA')


def preview(built):
    S, PS = 4, 6
    font = ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/PressStart2P.ttf'), 16)
    small = ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/PressStart2P.ttf'), 8)
    player = Image.open(os.path.join(ROOT, 'assets/images/player/monstrito1.png')).convert('RGBA')
    player = player.resize((player.width * PS, player.height * PS), Image.NEAREST)
    rows = []
    for (isl, ground, cur, theme, items) in ISLANDS:
        entries = [('(actual) ' + r.split('/')[-1], load_current(r), False) for r in cur]
        entries += [(n, built[n], n in HANGS) for n, _ in items]
        rows.append((isl, ground, entries))
    GAP, PADX = 28, 24
    widths = []
    for (_, _, entries) in rows:
        widths.append(PADX * 2 + sum(e[1].width * S + GAP for e in entries) + player.width + GAP)
    Wt = max(widths)
    blocks = []
    for (isl, ground, entries) in rows:
        hmax = max(e[1].height * S for e in entries)
        HROW = hmax + 70 + 64
        # (la cueva sobre fondo oscuro, si no, no se ve lo que brilla; el volcán, con su cielo rojizo)
        im = Image.new('RGBA', (Wt, HROW), {'CUEVA': rgb('2c2c40'), 'VOLCAN': rgb('c88a74')}.get(isl, rgb('aed8f2')))
        d = ImageDraw.Draw(im)
        gy = HROW - 64
        tile = Image.open(os.path.join(ROOT, 'assets/images/world/tiles', ground + '.png')).convert('RGBA')
        tile = tile.crop((0, 0, 64, 64))
        for x in range(0, Wt, 64): im.alpha_composite(tile, (x, gy))
        d.text((PADX, 10), isl, fill=WHITE if isl == 'CUEVA' else rgb('1a2a44'), font=font)
        x = PADX
        for (name, spr, hang) in entries:
            big = spr.resize((spr.width * S, spr.height * S), Image.NEAREST)
            if hang:
                d.rectangle([x - 4, 40, x + big.width + 4, 48], fill=STONE[1])
                im.alpha_composite(big, (x, 48))
            else:
                im.alpha_composite(big, (x, gy - big.height + S))   # la fila de abajo (margen) toca el suelo
            label = '%s %dx%d' % (name, spr.width, spr.height)
            d.text((x, gy + 8 + (12 if entries.index((name, spr, hang)) % 2 else 0)), label, fill=WHITE, font=small,
                   stroke_width=2, stroke_fill=rgb('1a2a44'))
            x += big.width + GAP
        im.alpha_composite(player, (x, gy - player.height))
        blocks.append(im)
    out = Image.new('RGBA', (Wt, sum(b.height for b in blocks)), rgb('aed8f2'))
    y = 0
    for b in blocks: out.alpha_composite(b, (0, y)); y += b.height
    write(os.path.join(OUT, 'vista_previa.png'), out)
    for (isl, _, _), b in zip(rows, blocks): write(os.path.join(OUT, 'isla_%s.png' % isl.lower()), b)
    print('  vista previa: %s (%dx%d)' % (os.path.join(OUT, 'vista_previa.png'), out.width, out.height))


def main():
    built = {}
    for (isl, ground, cur, theme, items) in ISLANDS:
        for name, fn in items:
            r = fn()
            if isinstance(r, list):
                for ln, li in zip(LAYER_NAMES, r):
                    edge_check(name + '/' + ln, li, False)
                    write(os.path.join(OUT, 'sprites', '%s_%s.png' % (name, ln)), li)
                    if APPLY and (not ONLY or name in ONLY):
                        p = os.path.join(ROOT, D, theme, name, ln + '.png')
                        if os.path.exists(p) and not FORCE: print('  %s ya existe (--force)' % p)
                        else: write(p, li); print('  ' + p)
                r = compose(r)
            else:
                edge_check(name, r, name in HANGS)
                if APPLY and (not ONLY or name in ONLY):
                    p = os.path.join(ROOT, D, theme, name + '.png')
                    if os.path.exists(p) and not FORCE: print('  %s ya existe (--force)' % p)
                    else: write(p, r); print('  ' + p)
            write(os.path.join(OUT, 'sprites', name + '.png'), r)
            built[name] = r
            print('  %-24s %-10s %dx%d' % (name, theme, r.width, r.height))
    preview(built)
    if APPLY: register_anims()


def register_anims():
    """cada sprite aplicado = una animación con su nombre en el conjunto de su carpeta (assets/anim/world/decorations/
    <tema>.json; las palmeras, uno propio por palmera con trunk / coconuts / fronds, como foliage/palmtree), que es
    como las piden los tipos (DecoFx.anim). Lo que ya está no se toca (puede estar retocado en el editor)."""
    sys.path.insert(0, os.path.join(ROOT, 'tools', 'anim'))
    from common import add_anims
    n = 0
    for (isl, ground, cur, theme, items) in ISLANDS:
        flat = []
        for name, fn in items:
            if ONLY and name not in ONLY: continue
            if os.path.isdir(os.path.join(ROOT, D, theme, name)):
                n += add_anims('world/decorations/%s/%s' % (theme, name),
                               [(ln, '%s%s/%s/%s.png' % (D, theme, name, ln), None, {}) for ln in LAYER_NAMES])
            elif os.path.exists(os.path.join(ROOT, D, theme, name + '.png')):
                flat.append((name, '%s%s/%s.png' % (D, theme, name), None, {}))
        n += add_anims('world/decorations/' + theme, flat)
    print('  animaciones nuevas: %d' % n)


if __name__ == '__main__':
    main()
