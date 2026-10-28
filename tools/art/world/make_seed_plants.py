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
import os, sys
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
    'costa':     dict(o='22301a', b='6c8a40', h='9cb860', s='4c6230', L='8aa850', l='5c7634', v='3c5024', x='c89a50', y='e4f8fc', p='9cb860', q='6c8a40', bg='9cdcf0'),
    'fortaleza': dict(o='1a2016', b='4a3a2a', h='6c5a40', s='2e241a', L='3e7a44', l='2a5630', v='1e3e22', x='a82c2c', y='7a3ca8', p='4c8a50', q='2a5630', bg='8a8ea8'),
    'nieve':     dict(o='2c5470', b='8cc8c0', h='c8f0ec', s='5c9c98', L='d8f4f8', l='a0d4e4', v='78acc8', x='ffffff', y='78acde', p='ffffff', q='bee4fa', bg='b8d4f0'),
    'cueva':     dict(o='2e2440', b='a898c8', h='dcd0f0', s='7c6ca0', L='4ac4d4', l='2a8aa0', v='1e6a80', x='b4f4ff', y='ffffff', p='4ac4d4', q='2a8aa0', bg='3a3450'),
    'volcan':    dict(o='120a0a', b='4a2226', h='6e3434', s='2e1416', L='5a2a28', l='3a1a1a', v='ff8a28', x='ff8a28', y='ffd23c', p='ff8a28', q='ffd23c', bg='6a2c2c'),
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


def preview():
    S = 4
    cols = []
    for isle in ISLES:
        pl = assemble(isle)
        bg = Image.new('RGBA', (84, pl.height + 30), rgb(ISLES[isle]['bg']))
        sd = seed(isle); bg.paste(sd, (2, 2), sd)
        sp = sprout(isle); bg.paste(sp, (20, 0), sp)
        bg.paste(pl, (2, 28), pl)
        cols.append(bg.resize((bg.width * S, bg.height * S), Image.NEAREST))
    out = Image.new('RGBA', (sum(c.width for c in cols), max(c.height for c in cols)))
    x = 0
    for c in cols: out.paste(c, (x, 0)); x += c.width
    return out


def gif(isle, path):
    """Crece: la semilla cae, brota y sube tramo a tramo hasta la copa; luego se marchita"""
    S = 4
    pal = ISLES[isle]
    full = assemble(isle)
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
                cv.paste(part, (2, cv.height - hgt), part)
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
        print('  ' + OUT)
    os.makedirs(PRUEBAS, exist_ok=True)
    preview().save(os.path.join(PRUEBAS, 'vista_previa.png'))
    for isle in ISLES: gif(isle, os.path.join(PRUEBAS, f'anim_{isle}.gif'))
    print('  ' + PRUEBAS)
