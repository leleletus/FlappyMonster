#!/usr/bin/env python3
# LA SEMILLA (objeto nuevo, aprobado por el usuario en 0.5.67 — diseño en curso): se coge, se planta con un ground pound
# en un bloque que lo admita y CRECE hacia arriba una planta que se trepa y en cuyas hojas se puede estar; se marchita.
# Un aspecto por isla — la semilla y lo que crece:
#   pradera: judía → tallo de habichuela con hojas anchas · costa: vaina → columna de KELP (también bajo el agua)
#   fortaleza: perno → CADENA de eslabones · nieve: esquirla → PILAR de hielo
#   cueva: espora que brilla → SETA luminosa de tallo largo (da luz) · volcán: guijarro de obsidiana → columna de BASALTO
# Piezas (1 casilla = 16 px de arte, ×4 en el juego):
#   semilla 12x12 · brote (3 cuadros de 16x16) · base 16x16 · tallo 2 × 16x16 (alternos, con hojitas) ·
#   HOJA GRANDE 32x10 (para trepar, a un lado y al otro) · COPA 48x16 (arriba: hojas o la flor)
#   python3 tools/art/world/make_seed_plants.py            → vistas previas en FlappyMonster_pruebas/nuevos/semilla/
#   python3 tools/art/world/make_seed_plants.py --apply    → assets/images/items/seed/<isla>-*.png
import os, sys, math, json
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'nuevos', 'semilla')
OUT = os.path.join(ROOT, 'assets', 'images', 'items', 'seed')


def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# PLANTAS DE VERDAD (0.5.67, el usuario: las de fortaleza, hielo y lava "parecían estructuras, no plantas", y todas
# necesitaban más hojas y HOJAS GRANDES intermedias para trepar): cada isla, una planta viva —
#   pradera: habichuela · costa: kelp con frondas · fortaleza: hiedra de castillo (zarza con espinas y bayas) ·
#   nieve: helecho escarchado con una flor de nieve · cueva: seta luminosa con setas de repisa · volcán: lirio de fuego
# papeles: o contorno · b/h/s tallo (cuerpo, brillo, sombra) · L hoja clara · l hoja oscura · v nervio · x/y acentos
# (espinas, bayas, brillo, ascuas) · p/q pétalos (la flor de arriba)
ISLES = {
    'pradera':   dict(o='1e3a1a', b='4c9a38', h='86cc5a', s='2e6a28', L='7cc850', l='3e8c3c', v='2e6a28', x='7a4a24', y='c8a060', p='9cd86c', q='5cac44', bg='8cc8f0'),
    'costa':     dict(o='2a2614', b='7a6a2c', h='a8964a', s='54481c', L='b4a04c', l='7c6a28', v='54481c', x='c89a50', y='f4ecb0', p='c8b45c', q='8a7a30', bg='9cdcf0'),
    'fortaleza': dict(o='1a2016', b='4a3a2a', h='6c5a40', s='2e241a', L='3e7a44', l='2a5630', v='1e3e22', x='a82c2c', y='7a3ca8', p='4c8a50', q='2a5630', bg='8a8ea8'),
    # (nieve, v6: helecho más sencillo · v5: HELECHO ESCARCHADO de un verde azulado con puntas blancas — el blanco pálido se perdía contra la nieve)
    'nieve':     dict(o='1e4a58', b='5aa8a0', h='9cdcd0', s='3c7c78', L='8cd4c4', l='4c9a94', v='2e6a70', x='ffffff', y='78acde', p='ffffff', q='bee4fa', bg='b8d4f0'),
    'cueva':     dict(o='2e2440', b='a898c8', h='dcd0f0', s='7c6ca0', L='4ac4d4', l='2a8aa0', v='1e6a80', x='b4f4ff', y='ffffff', p='4ac4d4', q='2a8aa0', bg='3a3450'),
    # (cactus de lava: OBSIDIANA negra con venas que brillan — el rojo oscuro se perdía contra el cielo del volcán)
    # (volcán, v5: ENREDADERA DE ASCUAS — tallos carbonizados, hojas negras con el borde y el nervio encendidos)
    'volcan':    dict(o='0a080c', b='2e2a32', h='4e4856', s='18141c', L='3a3238', l='241e24', v='ff8a28', x='ff8a28', y='ffd23c', p='ff8a28', q='ffd23c', bg='6a2c2c'),
}


class G:
    def __init__(self, w, h): self.w, self.h, self.g = w, h, [['.'] * w for _ in range(h)]
    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h: self.g[y][x] = c
    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w): self.put(xx, yy, c)
    def disc(self, cx, cy, r, fill='b', edge='o'):
        for y in range(self.h):
            for x in range(self.w):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= r: self.put(x, y, edge if d > r - 1 else fill)
    def flip(self):
        self.g = [r[::-1] for r in self.g]; return self
    def img(self, pal):
        im = Image.new('RGBA', (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                c = self.g[y][x]
                if c != '.': im.putpixel((x, y), rgb(pal[c]))
        return im


def leaf(g, x0, y0, ln, hgt, isle, side=1, vein=True):
    """Una hoja que sale de (x0, y0) hacia `side` (1 derecha, -1 izquierda): `ln` de largo, `hgt` de ancho máximo, arriba
    plana (se puede pisar) y abombada por debajo, con su nervio"""
    for i in range(ln):
        x = x0 + side * i
        w = max(1, int(round(hgt * (1 - ((i - ln * 0.45) / (ln * 0.6)) ** 2))))
        if isle == 'fortaleza': w = max(1, w - (1 if i % 4 == 3 else 0))     # (hiedra: borde lobulado)
        for k in range(w):
            g.put(x, y0 + k, 'L' if k < w // 2 + 1 else 'l')
        g.put(x, y0 - 1, 'o'); g.put(x, y0 + w, 'o')
        if vein and 1 < i < ln - 2 and w > 2: g.put(x, y0 + 1, 'v')
    g.put(x0 + side * ln, y0, 'o')


def stem_tile(isle, variant):
    """Un tramo de tallo (16x16) con hojas pequeñas, alternando el lado (variant 0 / 1)"""
    g = G(16, 16)
    w = 4 if isle in ('nieve', 'fortaleza') else 6
    x0 = 8 - w // 2
    for y in range(16):
        dx = (1 if (y // 5) % 2 else 0) if isle == 'costa' else 0          # (el kelp ondula)
        g.put(x0 - 1 + dx, y, 'o'); g.rect(x0 + dx, y, w, 1, 'b'); g.put(x0 + dx, y, 'h'); g.put(x0 + w - 1 + dx, y, 's')
        g.put(x0 + w + dx, y, 'o')
    side = 1 if variant == 0 else -1
    bx = x0 + w if side > 0 else x0 - 1
    leaf(g, bx, 4, 5, 3, isle, side, vein=False)                             # hojita
    leaf(g, x0 - 1 if side > 0 else x0 + w, 11, 3, 2, isle, -side, vein=False)
    if isle == 'fortaleza':                                                  # espinas y una baya
        g.put(x0 - 2, 8, 'x'); g.put(x0 + w + 1, 14, 'x'); g.put(bx + side * 2, 2, 'y')
    elif isle == 'nieve':                                                    # escarcha en las puntas
        g.put(bx + side * 5, 4, 'x'); g.put(x0 + 1, 7, 'x')
    elif isle == 'volcan':                                                   # ascuas en el tallo
        g.put(x0 + 2, 6, 'x'); g.put(x0 + 3, 13, 'y')
    elif isle == 'cueva':
        g.put(x0 + 2, 9, 'x')
    elif isle == 'costa':                                                    # vejiga
        g.disc(bx + side * 4 + 0.5, 6.5, 1.6, fill='y' if False else 'L'); g.put(int(bx + side * 4), 6, 'y')
    return g.img(ISLES[isle])


def big_leaf(isle):
    """HOJA GRANDE para trepar (32x10, sale del tallo hacia la derecha; el juego la voltea para la izquierda)"""
    g = G(32, 10)
    if isle == 'cueva':                                                      # seta de repisa que brilla
        for x in range(1, 31):
            top = 2 + int(((x - 16) / 16) ** 2 * 3)
            g.rect(x, top, 1, 7 - top, 'L'); g.put(x, top, 'o'); g.put(x, 7, 'o')
            if x % 5 == 2: g.put(x, top + 1, 'x')
        g.rect(1, 7, 30, 1, 'l')
    else:
        leaf(g, 0, 2, 31, 6, isle, 1)
        if isle == 'costa':
            for x in (8, 18, 26): g.put(x, 3, 'y')
        if isle == 'fortaleza':
            for x in (6, 15, 24): g.put(x, 7, 'x')
            g.put(20, 1, 'y'); g.put(21, 1, 'y')
        if isle == 'nieve':
            for x in range(3, 30, 4): g.put(x, 1, 'x')
        if isle == 'volcan':
            for x in range(4, 28): g.put(x, 3, 'v')
    return g.img(ISLES[isle])


def crown(isle):
    """La COPA de arriba (48x16): donde se está de pie — hojas en abanico o la FLOR"""
    g = G(48, 16)
    if isle in ('pradera', 'costa', 'fortaleza'):
        leaf(g, 24, 8, 23, 5, isle, -1); leaf(g, 23, 8, 23, 5, isle, 1)      # dos hojas grandes a los lados
        leaf(g, 22, 4, 10, 3, isle, -1, False); leaf(g, 25, 4, 10, 3, isle, 1, False)
        g.rect(21, 6, 6, 10, 'b')
        if isle == 'fortaleza':
            for x, y in ((10, 6), (12, 7), (35, 6), (37, 7)): g.put(x, y, 'y')
        if isle == 'costa':
            for x in (6, 16, 31, 41): g.put(x, 9, 'y')
    elif isle in ('nieve', 'volcan'):                                        # una FLOR: pétalos abiertos, plana arriba
        g.rect(22, 8, 4, 8, 'b')
        for k, (dx, ln) in enumerate(((-1, 20), (1, 20))):
            leaf(g, 24 + (0 if dx < 0 else -1), 9, ln, 4, isle, dx, False)
        for x in range(10, 38):
            top = 3 + int(abs(x - 24) / 6)
            for y in range(top, 8): g.put(x, y, 'p' if (x + y) % 3 else 'q')
            g.put(x, top - 1, 'o')
        g.disc(24, 6, 2.5, fill='y' if isle == 'volcan' else 'q')
        if isle == 'volcan':
            for x, y in ((14, 2), (33, 1), (24, 0)): g.put(x, y, 'x')
    elif isle == 'cueva':                                                    # el sombrero que brilla
        g.rect(21, 8, 6, 8, 'b')
        for x in range(2, 46):
            top = 2 + int(((x - 23.5) / 22) ** 2 * 6)
            g.rect(x, top, 1, 10 - top, 'L'); g.put(x, top, 'o'); g.put(x, 10, 'o')
        for x, y in ((10, 5), (11, 4), (30, 4), (31, 3), (20, 3), (38, 6)): g.put(x, y, 'x')
        g.rect(4, 9, 40, 1, 'l')
    return g.img(ISLES[isle])


def base(isle):
    g = G(16, 16)
    im = stem_tile(isle, 0)
    out = im.copy()
    rt = G(16, 16)
    for x, y in ((3, 15), (4, 14), (5, 15), (10, 15), (11, 14), (12, 15), (2, 15), (13, 15)): rt.put(x, y, 'o')
    r = rt.img(ISLES[isle]); out.paste(r, (0, 0), r)
    return out


def seed(isle):
    g = G(12, 12)
    if isle == 'pradera':
        g.disc(6, 7, 3.6, 'b'); g.put(4, 5, 'h'); g.rect(5, 1, 2, 3, 'L'); g.put(7, 1, 'l')
    elif isle == 'costa':
        g.disc(6, 6.5, 4.2, 'b'); g.put(4, 4, 'h'); g.put(6, 6, 'x'); g.put(7, 7, 'y')
    elif isle == 'fortaleza':                                                # semilla con espinas
        g.disc(6, 6.5, 3.4, 'b'); g.put(5, 5, 'h')
        for x, y in ((6, 1), (1, 6), (11, 6), (6, 11), (2, 2), (10, 2)): g.put(x, y, 'x')
    elif isle == 'nieve':                                                    # vaina blanca con escarcha
        g.disc(6, 6.5, 3.8, 'L'); g.put(4, 4, 'x'); g.put(7, 7, 'y'); g.put(5, 8, 'v')
    elif isle == 'cueva':                                                    # espora que brilla
        g.disc(6, 6, 4.0, 'L'); g.rect(5, 5, 2, 2, 'x'); g.put(5, 5, 'y')
    elif isle == 'volcan':                                                   # semilla de ascua
        g.disc(6, 6.5, 3.8, 'b'); g.put(6, 6, 'x'); g.put(7, 7, 'x'); g.put(6, 7, 'y')
    return g.img(ISLES[isle])


def sprout(isle):
    """El BROTE (3 cuadros de 16x16): asoma con dos hojitas y se hace tallo"""
    out = Image.new('RGBA', (48, 16))
    for f, h in enumerate((4, 9, 16)):
        g = G(16, 16)
        g.rect(7, 16 - h, 2, h, 'b'); g.put(7, 16 - h, 'h')
        leaf(g, 9, 16 - h, 2 + f, 1 + (f > 0), isle, 1, False); leaf(g, 6, 16 - h + 1, 2 + f, 1 + (f > 0), isle, -1, False)
        out.paste(g.img(ISLES[isle]), (f * 16, 0))
    return out


def assemble(isle, h=6):
    """Una planta de `h` casillas: base, tramos alternos con hojitas, HOJAS GRANDES a la 2 (derecha) y a la 4
    (izquierda) para ir trepando, y la COPA arriba"""
    cv = Image.new('RGBA', (80, 16 * h + 16))
    oy = 16
    b = base(isle); cv.paste(b, (32, oy + 16 * (h - 1)), b)
    for k in range(1, h):
        t = stem_tile(isle, k % 2); cv.paste(t, (32, oy + 16 * (h - 1 - k)), t)
    bl = big_leaf(isle)
    cv.paste(bl, (43, oy + 16 * (h - 3) + 2), bl)
    fl = bl.transpose(Image.FLIP_LEFT_RIGHT); cv.paste(fl, (5, oy + 16 * (h - 5) + 2), fl)
    cr = crown(isle); cv.paste(cr, (16, 0), cr)
    return cv


# ── PLANTAS DIBUJADAS ENTERAS (v4, 0.5.67, el usuario: "muy repetitivas y algo extrañas, no la típica planta que
# esperarías" — sobre todo pradera, costa y lava): ya no se apila un tramo de 16 px; cada planta se dibuja ENTERA, con el
# tallo que se curva, hojas de tamaños distintos a alturas irregulares (azar con semilla: siempre la misma imagen) y una
# imagen por altura (4, 5 y 6 casillas: el juego la descubre de abajo arriba al crecer). Las HOJAS GRANDES / brazos
# quedan a 2 y 4 casillas del suelo (lado derecho, lado izquierdo) y la COPA arriba: donde el juego pone las plataformas.
#   pradera: HABICHUELA de manual (dos hebras trenzadas, hojas de corazón, zarcillos rizados, una vaina arriba)
#   costa: KELP (tallo ondulado, frondas largas en cinta, vejigas de aire; frondas grandes con flotador; abanico arriba)
#   volcán: CACTUS DE LAVA (sus BRAZOS son las plataformas; espinas que brillan; flor de fuego arriba)
import random

ORG = {'pradera', 'costa', 'volcan', 'nieve', 'cueva'}
WP = 64                                          # (ancho de la imagen: 4 casillas, la planta en el centro)


# PLATAFORMAS de cada planta (lo que el juego pisa: las hojas grandes y la copa), medidas SOBRE EL DIBUJO: cada dibujo
# apunta sus zonas (REGIONS) y plats() busca en cada una la cara de arriba de verdad. Se guardan junto a la imagen:
# <isla>-plant<h>.json = {"w", "h", "plats": [[x, y, ancho], ...]} en píxeles de arte, origen arriba a la izquierda (la
# base de la imagen es el suelo).
REGIONS = {}


def plats(img, regions):
    a = img.split()[3].load()
    out = []
    for xa, xb, ya, yb in regions:
        tops = []
        for x in range(max(0, xa), min(img.width, xb + 1)):
            for y in range(max(0, ya), min(img.height, yb + 1)):
                if a[x, y] > 0: tops.append((x, y)); break
        if not tops: continue
        ys = sorted(y for _, y in tops)
        y = ys[len(ys) // 2]                                   # (la mediana: la cara plana, sin la punta rizada)
        xs = [x for x, yy in tops if abs(yy - y) <= 2]
        out.append([min(xs), y, max(xs) - min(xs) + 1])
    return out


def plant_data(isle, h):
    """(imagen, plataformas) de la planta de `h` casillas de la isla (dibujada entera, o la de la fortaleza montada)"""
    REGIONS.pop((isle, h), None)
    if isle in ORG:
        img = full_plant(isle, h)
    else:
        img = assemble(isle, h)
        oy = 16
        REGIONS[(isle, h)] = [(43, 74, oy + 16 * (h - 3) - 2, oy + 16 * (h - 3) + 6),
                              (5, 36, oy + 16 * (h - 5) - 2, oy + 16 * (h - 5) + 6), (24, 56, 0, 10)]
    return img, plats(img, REGIONS[(isle, h)])


def full_plant(isle, h):
    # (semilla FIJA: hash() de Python cambia en cada ejecución y cada --apply dibujaba otra planta)
    rnd = random.Random(sum(ord(ch) * (i + 1) for i, ch in enumerate(isle)) * 10 + h)
    H = 16 * h + 18                                  # (+ la copa que asoma por arriba)
    g = G(WP, H)
    cx = WP // 2
    floor = H - 1
    top = 18
    def stem_x(y):
        if isle in ('pradera', 'volcan'): return cx + 2.2 * math.sin((floor - y) / 9.0 + (0.8 if isle == 'volcan' else 0))
        if isle == 'costa': return cx + 2.6 * math.sin((floor - y) / 7.0 + 1)
        if isle == 'nieve': return cx + 1.6 * math.sin((floor - y) / 11.0 + 2)
        return cx + 1.2 * math.sin((floor - y) / 14.0)            # (la seta: casi recta, una curva suave)
    # ── el TALLO ──
    for y in range(top, H):
        x = stem_x(y)
        if isle in ('pradera', 'volcan'):             # dos hebras que se trenzan
            for k, ph in enumerate((0, math.pi)):
                sx = int(round(x + 1.6 * math.sin((floor - y) / 4.0 + ph)))
                g.put(sx - 2, y, 'o'); g.rect(sx - 1, y, 3, 1, 'b'); g.put(sx - 1, y, 'h'); g.put(sx + 1, y, 's'); g.put(sx + 2, y, 'o')
        elif isle in ('costa', 'nieve'):              # estípite / tallo fino y ondulado
            sx = int(round(x))
            g.put(sx - 2, y, 'o'); g.rect(sx - 1, y, 3, 1, 'b'); g.put(sx - 1, y, 'h'); g.put(sx + 2, y, 'o')
        elif isle == 'cueva':                         # el pie de la seta: grueso, se ensancha abajo
            sx = int(round(x))
            hw = 3 + (2 if y > floor - 10 else (1 if y > floor - 22 else 0))
            g.put(sx - hw - 1, y, 'o'); g.rect(sx - hw, y, 2 * hw + 1, 1, 'b'); g.rect(sx - hw, y, 2, 1, 'h')
            g.put(sx + hw, y, 's'); g.put(sx + hw + 1, y, 'o')
            if (y * 3) % 17 == 0: g.put(sx - 1, y, 'x')                                     # (motas que brillan)
        else:                                         # el cactus: columna gruesa con costillas
            sx = cx
            g.put(sx - 5, y, 'o'); g.rect(sx - 4, y, 9, 1, 'b'); g.rect(sx - 4, y, 2, 1, 'h'); g.rect(sx + 3, y, 2, 1, 's')
            g.put(sx + 5, y, 'o')
            for rx in (sx - 1, sx + 2): g.put(rx, y, 'x' if (y // 3) % 3 else 'y')         # (venas de lava)
            if (y * 7 + 3) % 11 == 0: g.put(sx - 6, y, 'x'); g.put(sx - 7, y - 1, 'y')       # espinas que brillan
            if (y * 5 + 1) % 13 == 0: g.put(sx + 6, y, 'x'); g.put(sx + 7, y - 1, 'y')
    # ── hojas PEQUEÑAS a alturas irregulares, a un lado y al otro ──
    y = floor - 8
    side = 1
    while y > top + 10:
        x = int(round(stem_x(y)))
        size = rnd.choice((3, 4, 4, 5, 6))
        if isle in ('pradera', 'volcan'):
            heart(g, x + side * 3, y, size, side)
            if isle == 'volcan':                      # el borde y el nervio, encendidos
                g.put(x + side * (3 + size), y, 'x'); g.put(x + side * (3 + size // 2), y - 1, 'x')
                if rnd.random() < 0.4: flame(g, x - side * 4, y + 2)
            elif rnd.random() < 0.45: tendril(g, x - side * 3, y + 4, -side)
        elif isle == 'nieve':
            fern(g, x + side * 2, y, size + 4, side)
        elif isle == 'cueva':
            if rnd.random() < 0.6: bracket(g, x + side * 4, y, 4 + size // 2, side)
        else:
            ribbon(g, x + side * 2, y, size + 4, side)
            if rnd.random() < 0.5: g.disc(x + side * 3 + 0.5, y + 1.5, 1.4, 'p', 'o')       # vejiga
        side = -side
        y -= rnd.randint(7, 13)
    # ── las HOJAS GRANDES / brazos: a 2 casillas (derecha) y a 4 (izquierda) del suelo ──
    for k, (cells, sd) in enumerate(((2, 1), (4, -1))):
        if cells >= h: continue
        py = floor - 16 * cells + 1                   # (su parte de arriba, donde se pisa)
        x = int(round(stem_x(py + 4)))
        x0, ln = (x + sd * 5, 22) if isle == 'cueva' else (x + sd * 2, 26)
        REGIONS.setdefault((isle, h), []).append((min(x0, x0 + sd * ln), max(x0, x0 + sd * ln), py - 4, py + 3))
        if isle in ('pradera', 'volcan'):
            bigleaf_bean(g, x + sd * 2, py, sd)
            if isle == 'volcan':                       # la hoja grande de ascuas: borde encendido
                for i in range(2, 26, 3): g.put(x + sd * (2 + i), py - 1, 'x')
        elif isle == 'costa': bigfrond(g, x + sd * 2, py, sd)
        elif isle == 'nieve': fern(g, x + sd * 2, py, 26, sd, big=True)
        else: bracket(g, x + sd * 5, py, 22, sd, big=True)
    # ── la COPA ──
    REGIONS.setdefault((isle, h), []).append((cx - 14, cx + 14, 0, top + 10))
    if isle == 'pradera':
        heart(g, cx - 3, top + 3, 11, -1); heart(g, cx + 3, top + 3, 11, 1)
        for yy in range(top + 6, top + 14): g.put(cx + 9, yy, 'v' if yy % 3 else 'o')       # la vaina colgando
        g.rect(cx + 8, top + 8, 3, 6, 'L'); g.put(cx + 9, top + 14, 'o')
        tendril(g, cx, top - 2, 1)
    elif isle == 'costa':
        for k, (dx, ln) in enumerate(((-1, 16), (1, 16), (-1, 9), (1, 9))):
            ribbon(g, cx + dx * (1 + k // 2), top + 2 + 3 * (k // 2), ln, dx, flat=True)
        g.disc(cx, top + 2, 2.2, 'p', 'o')
    elif isle == 'volcan':                            # dos hojas grandes y la FLOR DE FUEGO en medio
        heart(g, cx - 3, top + 4, 12, -1); heart(g, cx + 3, top + 4, 12, 1)
        for d in (-12, -6, 6, 12): g.put(cx + d, top + 3, 'x')
        flower(g, cx, top + 1, 6, fire=True)
    elif isle == 'nieve':                             # frondas abiertas y la FLOR DE NIEVE
        fern(g, cx - 2, top + 5, 18, -1, flat=True); fern(g, cx + 2, top + 5, 18, 1, flat=True)
        flower(g, cx, top + 1, 6)
    else:                                             # el SOMBRERO: una cúpula que brilla, con motas
        for yy in range(top - 6, top + 6):
            for xx in range(cx - 22, cx + 23):
                d = ((xx - cx) / 22) ** 2 + ((yy - (top + 6)) / 12) ** 2
                if d <= 1 and yy <= top + 5:
                    edge = ((xx - cx) / 21) ** 2 + ((yy - (top + 6)) / 11) ** 2 > 1
                    g.put(xx, yy, 'o' if edge else ('x' if yy < top - 2 and xx < cx else 'L'))
        g.rect(cx - 20, top + 5, 41, 1, 'l'); g.rect(cx - 21, top + 6, 43, 1, 'o')
        for xx, yy in ((cx - 12, top - 1), (cx - 4, top - 4), (cx + 7, top - 2), (cx + 15, top + 2), (cx - 17, top + 3), (cx + 2, top + 1)):
            g.disc(xx + 0.5, yy + 0.5, 1.3, 'y', 'y')
        for bx in (cx - 9, cx + 8):                   # setitas al pie
            for yy in range(floor - 4, floor + 1): g.put(bx, yy, 'b')
            g.rect(bx - 2, floor - 5, 5, 2, 'L'); g.put(bx - 1, floor - 5, 'x')
    return g.img(ISLES[isle])


def heart(g, x0, y0, size, side):
    """Hoja de CORAZÓN (habichuela): sale hacia `side`, más ancha cerca del tallo, punta al final"""
    for i in range(size):
        x = x0 + side * i
        w = max(1, int(round(size * 0.55 * math.sin(math.pi * (i + 1) / (size + 1)) + (1 if i < size * 0.4 else 0))))
        for k in range(-w // 2, w - w // 2):
            g.put(x, y0 + k, 'L' if k < 0 else 'l')
        g.put(x, y0 - w // 2 - 1, 'o'); g.put(x, y0 + w - w // 2, 'o')
        if 0 < i < size - 1: g.put(x, y0, 'v')
    g.put(x0 + side * size, y0, 'o')


def tendril(g, x, y, side):
    """Zarcillo rizado (3-4 px de espiral)"""
    for dx, dy in ((0, 0), (side, -1), (2 * side, -1), (3 * side, 0), (3 * side, 1), (2 * side, 1)): g.put(x + dx, y + dy, 'v')


def ribbon(g, x0, y0, ln, side, flat=False):
    """Fronda de KELP: una HOJA ancha y ondulada (3-4 px, se estrecha en la punta) que sube en diagonal; arriba, casi
    plana (antes era una cinta de 2 px: parecían ramitas)"""
    for i in range(ln):
        x = x0 + side * i
        y = y0 - (0 if flat else i // 3) + int(round(math.sin(i / 2.2)))
        w = 4 if i < ln * 0.6 else (3 if i < ln * 0.85 else 2)
        g.put(x, y - 1, 'o')
        for k in range(w): g.put(x, y + k, 'L' if k < w - 1 else 'l')
        if w > 2 and i % 4 == 1: g.put(x, y + 1, 'v')
        g.put(x, y + w, 'o')
    g.put(x0 + side * ln, y0 - (0 if flat else ln // 3) + 1, 'o')


def bigleaf_bean(g, x0, py, side):
    """HOJA GRANDE de habichuela para pisar (≈ 26 px): arriba plana, la punta rizada hacia arriba"""
    ln = 26
    for i in range(ln):
        x = x0 + side * i
        w = max(2, int(round(6 * math.sin(math.pi * (i + 2) / (ln + 3)))))
        g.rect(x, py, 1, w, 'L'); g.put(x, py + w - 1, 'l'); g.put(x, py - 1, 'o'); g.put(x, py + w, 'o')
        if 1 < i < ln - 3: g.put(x, py + 2, 'v')
    g.put(x0 + side * ln, py - 1, 'o'); g.put(x0 + side * (ln + 1), py - 2, 'o'); g.put(x0 + side * (ln - 1), py - 2, 'L')


def bigfrond(g, x0, py, side):
    """FRONDA GRANDE de kelp para pisar: una hoja ancha (arriba plana, abajo ondulada) con su vejiga de aire grande
    donde nace — el flotador que la sostiene"""
    ln = 26
    g.disc(x0 + side * 2 + 0.5, py + 3.5, 3.4, 'p', 'o'); g.put(x0 + side * 1, py + 2, 'y')
    for i in range(4, ln):
        x = x0 + side * i
        w = 4 + int(round(1.5 * math.sin(i / 2.0))) - (1 if i > ln - 4 else 0)
        g.put(x, py - 1, 'o')
        for k in range(w): g.put(x, py + k, 'L' if k < w - 1 else 'l')
        g.put(x, py + w, 'o')
        if i % 4 == 2: g.put(x, py + 1, 'v')
    g.put(x0 + side * ln, py, 'o'); g.put(x0 + side * ln, py + 1, 'o')


def fern(g, x0, y0, ln, side, big=False, flat=False):
    """FRONDA DE HELECHO escarchada, SENCILLA (la v5, con hojuelas de 1 px y escarcha en cada una, se veía sobrecargada):
    un nervio y hojuelas MACIZAS (hojitas de dos tonos con su borde) inclinadas hacia la punta; solo la punta de la
    fronda lleva escarcha. La grande, arriba lisa (se pisa), con las hojuelas colgando por debajo"""
    def pt(i): return x0 + side * i, y0 - (0 if (big or flat) else i // 3)
    leaf = set()
    step = 4 if big else 3
    for n, i in enumerate(range(2, ln - 1, step)):
        x, y = pt(i)
        L = max(2, int(round((5 if big else 4) * math.sin(math.pi * (i + 1) / (ln + 1)))))
        sy = 1 if (big or n % 2) else -1                        # (la grande: solo por debajo; las otras alternan)
        for k in range(1, L + 1):
            px, py = x + side * (k // 2), y + sy * k
            leaf |= {(px, py, 'L' if k < L else 'l'), (px + side, py, 'l')}
    for px, py, _ in leaf:                                      # (el borde de las hojuelas)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)): g.put(px + dx, py + dy, 'o')
    for px, py, c in sorted(leaf, key=lambda t: t[2] == 'L'): g.put(px, py, c)
    for i in range(ln):
        x, y = pt(i); g.put(x, y, 'v'); g.put(x, y + 1, 'o'); g.put(x, y - 1, 'o')
        if big: g.put(x, y - 1, 'L'); g.put(x, y - 2, 'o')
    x, y = pt(ln - 1); g.put(x + side, y, 'x'); g.put(x + side, y - 1, 'o')   # (la escarcha, solo en la punta)


def bracket(g, x0, y0, ln, side, big=False):
    """SETA DE REPISA (media seta que sale del pie, brilla): arriba plana, abajo curva, con sus láminas"""
    hgt = 5 if big else 3
    for i in range(ln):
        x = x0 + side * i
        d = hgt - int(round(hgt * (i / ln) ** 2))
        g.put(x, y0 - 1, 'o')
        for k in range(d): g.put(x, y0 + k, 'L' if k < d - 1 else 'l')
        g.put(x, y0 + d, 'o')
        if i % 4 == 1 and d > 2: g.put(x, y0 + 1, 'x')
    g.put(x0 + side * ln, y0, 'o')


def flame(g, x, y):
    """Florecilla de FUEGO (una llama de 3-4 px)"""
    for dx, dy, c in ((0, 0, 'x'), (0, -1, 'y'), (-1, 0, 'x'), (1, 0, 'x'), (0, -2, 'x')): g.put(x + dx, y + dy, c)


def flower(g, cx, cy, r, fire=False):
    """Una FLOR grande arriba: pétalos alrededor y el centro (de fuego en el volcán: pétalos como llamas)"""
    for k in range(8):
        a = k * math.pi / 4
        for t in range(1, r + 1):
            x, y = int(round(cx + math.cos(a) * t)), int(round(cy + math.sin(a) * t * 0.7))
            g.put(x, y, ('p' if t < r - 1 else 'q') if fire else ('p' if t < r - 1 else 'q'))
            if fire and k in (5, 6, 7) and t == r: g.put(x, y - 1, 'y')
    g.disc(cx + 0.5, cy + 0.5, 1.8, 'y' if fire else 'x', 'o' if not fire else 'x')


def preview():
    S = 4
    cols = []
    for isle in ISLES:
        pl = full_plant(isle, 6) if isle in ORG else assemble(isle)
        bg = Image.new('RGBA', (84, 16 * 6 + 46), rgb(ISLES[isle]['bg']))
        sd = seed(isle); bg.paste(sd, (2, 2), sd)
        sp = sprout(isle); bg.paste(sp, (20, 0), sp)
        bg.paste(pl, ((84 - pl.width) // 2, bg.height - pl.height), pl)
        cols.append(bg.resize((bg.width * S, bg.height * S), Image.NEAREST))
    out = Image.new('RGBA', (sum(c.width for c in cols), max(c.height for c in cols)))
    x = 0
    for c in cols: out.paste(c, (x, 0)); x += c.width
    return out


def gif(isle, path):
    """Crece: la semilla cae, brota y sube tramo a tramo hasta la copa; luego se marchita"""
    S = 4
    pal = ISLES[isle]
    full = full_plant(isle, 6) if isle in ORG else assemble(isle)
    frames, dur = [], []
    for n in range(30):
        cv = Image.new('RGBA', (84, full.height + 4), rgb(pal['bg']))
        if n < 4:
            sd = seed(isle); cv.paste(sd, (36, cv.height - 30 + n * 4), sd)
        else:
            k = min(1.0, (n - 4) / 14)
            hgt = int(full.height * k)
            alpha = 1.0 if n < 24 else max(0, 1 - (n - 24) / 5)
            if hgt > 0:
                part = full.crop((0, full.height - hgt, full.width, full.height))
                if alpha < 1: part.putalpha(part.split()[3].point(lambda v: int(v * alpha)))
                cv.paste(part, ((84 - full.width) // 2, cv.height - hgt), part)
        frames.append(cv.resize((cv.width * S, cv.height * S), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
        dur.append(90 if n < 18 else 140)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=dur, loop=0, disposal=2)


if __name__ == '__main__':
    if '--apply' in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        for isle in ISLES:
            seed(isle).save(os.path.join(OUT, f'{isle}-seed.png'))
            sprout(isle).save(os.path.join(OUT, f'{isle}-sprout-Sheet.png'))
            base(isle).save(os.path.join(OUT, f'{isle}-base.png'))
            st = Image.new('RGBA', (32, 16)); st.paste(stem_tile(isle, 0), (0, 0)); st.paste(stem_tile(isle, 1), (16, 0))
            st.save(os.path.join(OUT, f'{isle}-stem-Sheet.png'))
            big_leaf(isle).save(os.path.join(OUT, f'{isle}-bigleaf.png'))
            crown(isle).save(os.path.join(OUT, f'{isle}-crown.png'))
            for hh in (4, 5, 6):                               # (la planta entera de cada altura + sus plataformas)
                img, pl = plant_data(isle, hh)
                img.save(os.path.join(OUT, f'{isle}-plant{hh}.png'))
                with open(os.path.join(OUT, f'{isle}-plant{hh}.json'), 'w') as f:
                    json.dump({'w': img.width, 'h': img.height, 'plats': pl}, f)
        print('  ' + OUT)
    os.makedirs(PRUEBAS, exist_ok=True)
    preview().save(os.path.join(PRUEBAS, 'vista_previa.png'))
    for isle in ISLES: gif(isle, os.path.join(PRUEBAS, f'anim_{isle}.gif'))
    print('  ' + PRUEBAS)
