#!/usr/bin/env python3
# tools/art/world/make_biome_art.py
# Arte de los biomas que faltaban (etapa de "retematizar" las islas del modo historia), en el estilo del juego:
# contorno oscuro de 1 px + 3 tonos (luz arriba-izquierda, sombra abajo-derecha), sin ruido. Arte a 1x; el
# juego lo dibuja a x4. Formas hechas con funciones (máscaras), así se pueden retocar a mano después.
#   assets/images/world/tiles/basalt.png       Basalto: roca volcánica oscura, dibujo de 2x2 casillas (juntas de columna)
#   assets/images/world/tiles/ash.png          Ceniza: capa gris (con alguna brasa) sobre basalto, si su cara de arriba da al aire
#   assets/images/world/decorations/volcano/   charred_tree, dead_bush, basalt_rock, basalt_pebbles, ash_pile,
#                                        lava_vent, glow_rock, lava_fall-Sheet (cae del techo), steam_stones (aguas termales)
#   assets/images/world/decorations/meadow/    oak_tree, pine_tree, round_bush, flower_patch, tall_grass, red_mushroom,
#                                        mossy_rock, fallen_log, sunflower
#   assets/images/world/decorations/fx/smoke-Sheet.png   bocanadas de humo / vapor (3 cuadros, blancas: se tiñen)
#   assets/images/enemies/mortar/flame.png       bola de fuego del mortero (6 cuadros de 16x16; rediseño, ver mortar_flame)
# Las decoraciones llevan 1 px de margen (a los lados y arriba; abajo si cuelgan) con el contorno cerrado.
# No pisa lo que ya existe (--force [nombres] para rehacerlo). Desde la raíz del repo:
#     python3 tools/art/world/make_biome_art.py [--force] [nombre ...]
import os, sys, math, random
from PIL import Image

FORCE = '--force' in sys.argv
ONLY = {a for a in sys.argv[1:] if not a.startswith('--')}
OUTLINE = (24, 22, 32, 255)


def rgb(h, a=255): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def save(rel, img, scale=1):
    name = os.path.splitext(os.path.basename(rel))[0]
    if ONLY and name not in ONLY: return
    path = os.path.join('assets/images', rel)
    if os.path.exists(path) and not FORCE:
        print('  %s ya existe: no se toca (--force)' % path)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if scale != 1: img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(path)
    print('  %-52s %dx%d' % (path, img.width, img.height))


class Canvas:
    """Lienzo por PARTES (como el resto del arte del juego): cada parte = máscara + paleta de 4 tonos
    (contorno, sombra, medio, luz). El CONTORNO es el tono más oscuro de su propio color (nunca negro);
    la luz viene de arriba a la izquierda: brillo en el filo de arriba-izquierda, sombra hacia abajo-derecha.
    Una parte de delante (pintada después) tapa a la de detrás y lleva su propio contorno."""
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]
        self.pals = []
        self.dots = []

    def part(self, inside, pal, shade=0.3):
        pid = len(self.pals)
        self.pals.append((pal, shade))
        for y in range(self.h):
            for x in range(self.w):
                if inside(x, y): self.px[y][x] = pid
        return pid

    def dot(self, x, y, col): self.dots.append((x, y, col))

    def image(self):
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        P = self.px
        same = lambda x, y, p: 0 <= x < self.w and 0 <= y < self.h and P[y][x] == p
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
                if not all(same(x + dx, y + dy, p) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    c = out
                else:
                    # posición en su caja: -1 (arriba-izquierda) .. 1 (abajo-derecha)
                    u = ((x - x0) / max(1, x1 - x0) - 0.5) * 1.2 + ((y - y0) / max(1, y1 - y0) - 0.5) * 0.8
                    c = mid
                    if u > k: c = dark
                    if not same(x, y - 1, p) or not same(x, y - 2, p) and (x - x0) < (x1 - x0) * 0.6: c = light
                    elif not same(x - 1, y, p) and u < 0.2: c = light
                im.putpixel((x, y), c)
        for x, y, col in self.dots:
            if 0 <= x < self.w and 0 <= y < self.h and P[y][x] is not None: im.putpixel((x, y), col)
        return im


def pad(img, hang=False, fw=None):
    """1 px de margen a los lados y arriba (abajo si cuelga), por cuadro."""
    fw = fw or img.width
    n = img.width // fw
    out = Image.new('RGBA', ((fw + 2) * n, img.height + 1), (0, 0, 0, 0))
    for k in range(n):
        out.paste(img.crop((k * fw, 0, (k + 1) * fw, img.height)), (k * (fw + 2) + 1, 0 if hang else 1))
    return out


def strip(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames): out.paste(f, (i * w, 0))
    return out


def ell(cx, cy, rx, ry):
    return lambda x, y: ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1


def wobbly(cx, cy, rx, ry, k, ph):
    def f(x, y):
        dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        a = math.atan2(dy, dx)
        r = 1 + k * math.sin(a * 5 + ph) + k * 0.6 * math.sin(a * 9 + ph * 2)
        return dx * dx + dy * dy <= r * r
    return f


# ── Paletas (contorno, sombra, medio, luz): las del arte del juego (arbusto, pino nevado, estalagmita...) ──
LEAF = (rgb('0e3a1c'), rgb('1c6a34'), rgb('2e9a48'), rgb('62cc5a'))       # = arbusto tropical
LEAF_D = (rgb('14281f'), rgb('1f4a37'), rgb('2f6b4f'), rgb('43896a'))     # = pino nevado
BARK = (rgb('2a1a10'), rgb('553620'), rgb('7a5030'), rgb('a06e44'))
ROCK = (rgb('2e2826'), rgb('584e48'), rgb('7c7068'), rgb('a09488'))       # = estalagmita
# (2ª paleta del volcán: en el mapa la isla es ROJIZA y en los niveles el fondo también, pero el suelo era gris
# carbón; ahora la roca es basalto ROJIZO —lava vieja, escoria— y la ceniza, ceniza volcánica rojiza: siguen
# pareciendo roca, pero del color de la isla. Antes: BASALT 16121a·2c2630·403a46·5c5464, ASH 3c3840·6e6a72·928e96·bab6be)
BASALT = (rgb('200d10'), rgb('3e1a1c'), rgb('5c2a26'), rgb('804238'))
CHAR = (rgb('180f0d'), rgb('30201c'), rgb('463028'), rgb('604234'))
ASH = (rgb('4c1e18'), rgb('8c3e2c'), rgb('b25c3c'), rgb('d88856'))
LAVA = (rgb('6e140c'), rgb('c83c18'), rgb('f07822'), rgb('ffc848'))
OBSID = (rgb('120a18'), rgb('281c34'), rgb('3e2e4e'), rgb('604e78'))
PETAL = (rgb('8a8070'), rgb('d8d0c0'), rgb('f0ead8'), rgb('ffffff'))
SUN = (rgb('7a4a08'), rgb('d89a10'), rgb('f8c820'), rgb('ffe868'))
RED = (rgb('5a0e10'), rgb('a01e1e'), rgb('d8322c'), rgb('f05a48'))
STEM = (rgb('7a7060'), rgb('c8bca8'), rgb('f0e6d8'), rgb('ffffff'))
EMBER = rgb('ff8a2a')
EMBER_D = rgb('c8401c')
MOSS_G = rgb('5aa040')


# ── TILES ─────────────────────────────────────────────────────────────────────
def basalt_tile():
    """32x32 (2x2 casillas): color plano + unas pocas juntas cortas de columna (MUY sencillo: el usuario
    rechazó las grietas recargadas en la piedra)"""
    d, b, l = BASALT[1], BASALT[2], BASALT[3]
    im = Image.new('RGBA', (32, 32), b)
    for (x, y0, n) in ((6, 4, 6), (21, 9, 5), (13, 19, 6), (27, 22, 4), (4, 24, 4)):
        for y in range(y0, y0 + n): im.putpixel((x, y), d)
        im.putpixel((x + 1, y0), l)
    for (x, y) in ((10, 7), (25, 3), (17, 13), (8, 15), (24, 17), (19, 27), (29, 29)):
        im.putpixel((x, y), l)
    return im


def ash_tile():
    """16x16: capa de ceniza arriba (6 filas) sobre basalto; alguna brasa"""
    d, b, l = BASALT[1], BASALT[2], BASALT[3]
    im = Image.new('RGBA', (16, 16), b)
    a2, a0, a1 = ASH[1], ASH[2], ASH[3]
    prof = [5, 5, 6, 6, 5, 4, 5, 6, 6, 6, 5, 5, 4, 5, 6, 5]
    for x in range(16):
        for y in range(prof[x]):
            im.putpixel((x, y), a1 if y == 0 else (a0 if (x + y) % 5 else a2))
        im.putpixel((x, prof[x]), a2 if x % 3 else d)
    for x, y in ((3, 2), (11, 3)): im.putpixel((x, y), EMBER)
    for x, y in ((5, 10), (12, 13), (2, 14)): im.putpixel((x, y), d)
    im.putpixel((8, 11), l)
    return im


# ── VOLCÁN ────────────────────────────────────────────────────────────────────
def charred_tree():
    """árbol calcinado (20x32): tronco que se estrecha, ramas secas, brasas en las grietas"""
    c = Canvas(20, 32)
    c.part(lambda x, y: y >= 8 and abs(x + 0.5 - 10) <= 1.4 + max(0, y - 24) * 0.45, CHAR, 0.1)
    for (x0, y0, dx, n, w) in ((10, 17, -1, 7, 1), (10, 13, 1, 7, 1), (10, 9, -1, 5, 1), (10, 21, 1, 5, 1), (10, 6, 1, 3, 1)):
        pts = {(int(round(x0 + dx * (i + 1))), int(round(y0 - i * 0.6))) for i in range(n)}
        pts |= {(px, py + 1) for px, py in pts}
        c.part(lambda x, y, pts=pts: (x, y) in pts, CHAR, 0.1)
    for (x, y, col) in ((10, 19, EMBER_D), (9, 24, EMBER_D), (10, 25, EMBER), (11, 14, EMBER_D)):
        c.dot(x, y, col)
    return c.image()


def dead_bush():
    """matorral seco (8x8): ramitas gruesas con su contorno"""
    c = Canvas(8, 8)
    pts = set()
    for (x0, dx) in ((3.5, -0.55), (3.6, 0.0), (3.6, 0.55)):
        for i in range(6):
            pts |= {(int(round(x0 + dx * i)), 7 - i), (int(round(x0 + dx * i)) + 1, 7 - i)}
    c.part(lambda x, y: (x, y) in pts, CHAR, 0.2)
    return c.image()


def basalt_rock():
    """columnas de basalto de distintas alturas, cada una con su cara de arriba (16x12)"""
    c = Canvas(16, 12)
    for (x0, h) in ((1, 7), (4, 11), (7, 9), (10, 12), (13, 6)):
        c.part(lambda x, y, a=x0, hh=h: a <= x <= a + 3 and y >= 12 - hh, BASALT, 0.0)
    for (x0, h) in ((1, 7), (4, 11), (7, 9), (10, 12), (13, 6)):
        c.dot(x0 + 1, 12 - h + 1, BASALT[3]); c.dot(x0 + 2, 12 - h + 1, BASALT[3])
    return c.image()


def basalt_pebbles():
    c = Canvas(8, 5)
    c.part(ell(2.5, 4.5, 2.6, 2.6), BASALT)
    c.part(ell(6, 5, 2.2, 2), BASALT)
    return c.image()


def ash_pile():
    c = Canvas(10, 5)
    c.part(ell(5, 5.5, 5, 4.4), ASH, 0.2)
    c.dot(4, 2, EMBER_D); c.dot(6, 3, EMBER_D)
    return c.image()


def lava_vent():
    """montículo de basalto con la boca al rojo (8x6)"""
    c = Canvas(8, 6)
    c.part(ell(4, 6.5, 4, 5.2), BASALT, 0.2)
    c.part(lambda x, y: 3 <= x <= 4 and 2 <= y <= 3, LAVA, 0.5)
    c.dot(3, 2, LAVA[3])
    return c.image()


def glow_rock():
    """obsidiana con grietas que brillan (8x7)"""
    c = Canvas(8, 7)
    c.part(wobbly(4, 4.5, 3.9, 3.3, 0.12, 1.0), OBSID, 0.2)
    for x, y in ((3, 3), (4, 4), (5, 4), (4, 5)): c.dot(x, y, EMBER if (x + y) % 2 else EMBER_D)
    c.dot(2, 2, OBSID[3])
    return c.image()


def lava_fall():
    """chorro de lava que cae del techo (8x16, cuelga; 3 cuadros que bajan)"""
    frames = []
    for f in range(3):
        c = Canvas(8, 16)
        c.part(lambda x, y: y >= 2 and abs(x + 0.5 - 4 - 0.5 * math.sin((y + f * 2) * 0.6)) <= (1.6 if y < 14 else 2.6), LAVA, 0.35)
        c.part(lambda x, y: y <= 2 and 0 <= x <= 7 and not (y == 2 and x in (0, 7)), BASALT, 0.1)
        for y in range(3, 16):
            if (y + f * 3) % 6 == 0: c.dot(4, y, rgb('fff0a0'))
        frames.append(c.image())
    return strip(frames)


def steam_stones():
    """corro de piedras de unas aguas termales (el vapor lo pone el juego) (10x4)"""
    c = Canvas(10, 4)
    for x0 in (1.6, 5, 8.4):
        c.part(ell(x0, 3.6, 1.8, 2), ROCK, 0.2)
    return c.image()


def smoke():
    """3 bocanadas (se tiñen en el juego): borde algo más oscuro y un brillo arriba-izquierda (6x6)"""
    frames = []
    for r in (1.7, 2.3, 2.9):
        im = Image.new('RGBA', (6, 6), (0, 0, 0, 0))
        for y in range(6):
            for x in range(6):
                d = math.hypot(x + 0.5 - 3, y + 0.5 - 3)
                if d <= r:
                    v = 255 if (x + y) < 5 else 225
                    if d > r - 0.8: v = 190
                    im.putpixel((x, y), (v, v, v, 255))
        frames.append(im)
    return strip(frames)


# ── PRADERA ───────────────────────────────────────────────────────────────────
def oak_tree():
    """roble (30x34): copa de varios bultos con sombra hacia abajo-derecha, tronco con raíces y una rama"""
    c = Canvas(30, 34)
    c.part(lambda x, y: y >= 16 and abs(x + 0.5 - 15) <= 2 + max(0, y - 29) * 0.9, BARK, 0.15)
    c.part(lambda x, y: 17 <= x <= 21 and 18 <= y <= 20 and (x - 17) >= (20 - y) - 1, BARK, 0.2)
    c.part(lambda x, y: ell(8, 15, 7.5, 6.5)(x, y) or ell(22, 14, 7.5, 7)(x, y), LEAF, 0.15)        # bultos de atrás
    c.part(lambda x, y: ell(15, 9, 10, 8)(x, y) or ell(11, 13, 6, 5)(x, y), LEAF, 0.25)               # copa de delante
    for x, y in ((9, 6), (14, 4), (20, 7), (6, 12), (24, 11)): c.dot(x, y, LEAF[3])
    for x, y in ((18, 14), (22, 17), (12, 17)): c.dot(x, y, LEAF[1])
    c.dot(15, 22, BARK[1]); c.dot(14, 26, BARK[1])
    return c.image()


def pine_tree():
    """pino (18x32): 3 pisos dentados, como el pino nevado sin nieve"""
    c = Canvas(18, 32)
    c.part(lambda x, y: 8 <= x <= 9 and y >= 24, BARK, 0.2)
    for t0, t1, w in ((16, 26, 8.5), (9, 19, 7.0), (1, 12, 5.5)):
        c.part(lambda x, y, t0=t0, t1=t1, w=w: t0 <= y <= t1 and abs(x + 0.5 - 9) <= (y - t0 + 1) * w / (t1 - t0 + 1)
               - (0.8 if (y - t0) % 3 == 0 and y > t0 + 1 else 0), LEAF_D, 0.2)
    return c.image()


def round_bush():
    """arbusto redondo de pradera con bayas (16x10)"""
    c = Canvas(16, 10)
    c.part(lambda x, y: ell(5, 6.5, 5, 4.5)(x, y) or ell(11, 6, 5, 5)(x, y) or ell(8, 4.5, 4, 4)(x, y), LEAF, 0.2)
    for x, y in ((5, 3), (9, 2), (3, 5)): c.dot(x, y, LEAF[3])
    for x, y in ((6, 6), (11, 4), (12, 7)): c.dot(x, y, RED[2])
    return c.image()


def flower_patch():
    """margaritas sobre una mata de hojas (8x7)"""
    c = Canvas(8, 7)
    c.part(lambda x, y: y >= 5 and 0 <= x <= 7 and not (y == 5 and x in (0, 7)), LEAF, 0.3)
    for (fx_, fy) in ((1, 2), (4, 1), (6, 3)):
        c.part(lambda x, y, a=fx_, b=fy: a <= x <= a + 1 and b <= y <= b + 1, PETAL, 0.6)
        c.dot(fx_, fy, SUN[2])
    return c.image()


def tall_grass():
    """hierba alta (8x10): briznas de 2 px con su tono oscuro, como el helecho"""
    c = Canvas(8, 10)
    for (x0, h, lean) in ((1, 8, 0.35), (3, 10, -0.15), (5, 9, 0.25), (6, 7, -0.4)):
        pts = set()
        for i in range(h):
            x = int(round(x0 + lean * i * 0.5))
            pts |= {(x, 9 - i), (x + 1, 9 - i)} if i < h - 2 else {(x, 9 - i)}
        c.part(lambda x, y, pts=pts: (x, y) in pts, LEAF, 0.4)
    return c.image()


def red_mushroom():
    c = Canvas(8, 8)
    c.part(lambda x, y: 3 <= x <= 4 and y >= 4, STEM, 0.5)
    c.part(lambda x, y: y <= 4 and ell(4, 4.6, 4, 4.2)(x, y), RED, 0.25)
    for x, y in ((2, 2), (5, 1), (4, 3)): c.dot(x, y, rgb('ffffff'))
    return c.image()


def mossy_rock():
    c = Canvas(10, 7)
    c.part(wobbly(5, 4.5, 4.8, 3.7, 0.1, 0.4), ROCK, 0.2)
    for x in range(3, 8):
        c.dot(x, 1 if 4 <= x <= 6 else 2, MOSS_G if x % 2 else LEAF[3])
    return c.image()


def fallen_log():
    c = Canvas(16, 7)
    c.part(lambda x, y: 1 <= y <= 6 and 0 <= x <= 13, BARK, 0.3)
    c.part(ell(14, 3.8, 2, 3.2), (BARK[0], rgb('9a6e40'), rgb('c89a62'), rgb('e0b67c')), 0.5)
    for x in (4, 8, 11): c.dot(x, 3, BARK[1])
    c.dot(14, 3, BARK[1]); c.dot(6, 1, MOSS_G); c.dot(7, 1, MOSS_G)
    return c.image()


def sunflower():
    c = Canvas(8, 16)
    c.part(lambda x, y: 3 <= x <= 4 and y >= 6, LEAF_D, 0.5)
    c.part(lambda x, y: (y in (10, 11) and 0 <= x <= 3) or (y in (8, 9) and 4 <= x <= 7), LEAF, 0.4)
    c.part(ell(4, 3.5, 3.8, 3.5), SUN, 0.3)
    for x, y in ((3, 3), (4, 3), (3, 4), (4, 4)): c.dot(x, y, rgb('7a4a1c'))
    c.dot(4, 4, rgb('4a2a10'))
    return c.image()


# ── FUEGO DEL MORTERO (rediseño; el original del usuario está fuera del repo:
#    FlappyMonster_originals/assets/images/enemies/mortar/flame-orig.png) ──────────────
FIRE_OUT = (rgb('7a160a'), rgb('d03a12'), rgb('ec5a18'), rgb('f87a22'))     # capa de fuera: rojo (contorno rojo oscuro)
FIRE_MID = (rgb('f07a1e'), rgb('f8902a'), rgb('ffa632'), rgb('ffc04a'))     # medio: naranja (su borde, naranja)
FIRE_IN = (rgb('ffc040'), rgb('ffd858'), rgb('ffea80'), rgb('fff8c8'))      # núcleo: amarillo claro


def tongue(cx, base, tip, w, lean):
    """llama: de ancha en la base a punta arriba, algo inclinada"""
    def f(x, y):
        if not (tip <= y <= base): return False
        k = (y - tip) / max(1, base - tip)
        return abs(x + 0.5 - (cx + lean * (1 - k))) <= w * k
    return f


def mortar_flame():
    """bola de fuego (6 cuadros de 16x16): núcleo amarillo claro, capa naranja grande y llamas que suben
    y tiemblan; contorno rojo oscuro solo por fuera (no negro)"""
    frames = []
    for f in range(6):
        a = f / 6 * 2 * math.pi
        h1, h2, h3 = 1.5 + 1.5 * math.sin(a), 0.5 + 1.2 * math.sin(a + 2.1), 2.5 + 1.5 * math.sin(a + 4.2)
        c = Canvas(16, 16)
        c.part(lambda x, y: ell(8, 10.5, 6.3, 5.4)(x, y) or tongue(4.5, 9, h1, 2.8, -1)(x, y)
               or tongue(8.5, 8, h2, 3.0, 0.5)(x, y) or tongue(12, 10, h3, 2.4, 1)(x, y), FIRE_OUT, 0.5)
        c.part(lambda x, y: ell(8, 10.6, 5, 4.4)(x, y) or tongue(6, 9, h1 + 2, 2.2, -0.5)(x, y)
               or tongue(10, 9, h2 + 2.5, 2.2, 0.6)(x, y), FIRE_MID, 0.5)
        c.part(lambda x, y: ell(7.8 + 0.4 * math.sin(a), 10.8, 3.2, 2.9)(x, y)
               or tongue(8, 10, h2 + 5, 1.4, 0.3)(x, y), FIRE_IN, 0.7)
        c.dot(7, 10, rgb('ffffff')); c.dot(8, 10, rgb('ffffff'))
        frames.append(c.image())
    return strip(frames)


if __name__ == '__main__':
    print('Arte de los biomas:')
    save('world/tiles/basalt.png', basalt_tile(), 4)
    save('world/tiles/ash.png', ash_tile(), 4)
    V = 'world/decorations/volcano/'
    for name, fn, hang in (('charred_tree', charred_tree, False), ('dead_bush', dead_bush, False),
                           ('basalt_rock', basalt_rock, False), ('basalt_pebbles', basalt_pebbles, False),
                           ('ash_pile', ash_pile, False), ('lava_vent', lava_vent, False), ('glow_rock', glow_rock, False),
                           ('steam_stones', steam_stones, False)):
        save(V + name + '.png', pad(fn(), hang))
    save(V + 'lava_fall-Sheet.png', pad(lava_fall(), True, 8))
    M = 'world/decorations/meadow/'
    for name, fn in (('oak_tree', oak_tree), ('pine_tree', pine_tree), ('round_bush', round_bush),
                     ('flower_patch', flower_patch), ('tall_grass', tall_grass), ('red_mushroom', red_mushroom),
                     ('mossy_rock', mossy_rock), ('fallen_log', fallen_log), ('sunflower', sunflower)):
        save(M + name + '.png', pad(fn()))
    save('world/decorations/fx/smoke-Sheet.png', smoke())
    save('enemies/mortar/flame.png', mortar_flame())
