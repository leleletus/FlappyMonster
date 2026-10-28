#!/usr/bin/env python3
# LA SEMILLA (objeto nuevo, aprobado por el usuario en 0.5.67 — diseño en curso): se coge, se planta con un ground pound
# en un bloque que lo admita y CRECE hacia arriba una planta que se trepa y en cuyas hojas se puede estar; se marchita.
# Un aspecto por isla — la semilla y lo que crece:
#   pradera: judía → tallo de habichuela con hojas anchas · costa: vaina → columna de KELP (también bajo el agua)
#   fortaleza: perno → CADENA de eslabones · nieve: esquirla → PILAR de hielo
#   cueva: espora que brilla → SETA luminosa de tallo largo (da luz) · volcán: guijarro de obsidiana → columna de BASALTO
# Piezas (1 casilla = 16 px de arte, ×4 en el juego):
#   semilla 12x12 · brote (3 cuadros de 16x16: la punta que sale) · base 16x16 · tallo 16x16 (se repite) ·
#   COPA 48x8 (3 casillas, ARRIBA: donde se está de pie — la planta es una T)
#   python3 tools/art/world/make_seed_plants.py            → vistas previas en FlappyMonster_pruebas/nuevos/semilla/
#   python3 tools/art/world/make_seed_plants.py --apply    → assets/images/items/seed/<isla>-*.png
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'nuevos', 'semilla')
OUT = os.path.join(ROOT, 'assets', 'images', 'items', 'seed')


def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# o contorno · s sombra · b cuerpo · h brillo · x/y acentos · l hoja (oscura) · L hoja (clara)
ISLES = {
    'pradera':   dict(o='22461e', s='3e7c32', b='5cac44', h='9cd86c', x='7a4a24', y='c8a060', l='3e8c3c', L='7cc850', bg='8cc8f0'),
    'costa':     dict(o='2a3a1c', s='4c6230', b='6c8a40', h='9cb860', x='3cb4b4', y='e4f8fc', l='4c6230', L='8aa850', bg='9cdcf0'),
    'fortaleza': dict(o='242830', s='4c5260', b='747c8c', h='a8b0be', x='343842', y='c8ccd6', l='4c5260', L='8a92a2', bg='8a8ea8'),
    'nieve':     dict(o='3c6a9c', s='78acde', b='bee4fa', h='ecfaff', x='a8d0f0', y='ffffff', l='78acde', L='d8f0ff', bg='b8d4f0'),
    'cueva':     dict(o='3c3050', s='6c5c88', b='9c8cb8', h='d0c4e8', x='2a8aa0', y='b4f4ff', l='2a8aa0', L='b4f4ff', bg='3a3450'),
    'volcan':    dict(o='140e10', s='2c2224', b='443438', h='60504e', x='ff8a28', y='ffd23c', l='2c2224', L='443438', bg='6a2c2c'),
}


class G:
    def __init__(self, w, h): self.w, self.h, self.g = w, h, [['.'] * w for _ in range(h)]
    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h: self.g[y][x] = c
    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w): self.put(xx, yy, c)
    def disc(self, cx, cy, r, shade=True):
        for y in range(self.h):
            for x in range(self.w):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= r:
                    edge = d > r - 1
                    c = 'o' if edge else ('h' if shade and (x - cx) + (y - cy) < -r * 0.6 else ('s' if shade and (x - cx) + (y - cy) > r * 0.5 else 'b'))
                    self.put(x, y, c)
    def img(self, pal):
        im = Image.new('RGBA', (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                c = self.g[y][x]
                if c != '.': im.putpixel((x, y), rgb(pal[c]))
        return im


# ── La SEMILLA (12x12) ──
def seed(isle):
    g = G(12, 12)
    if isle == 'pradera':                                       # judía: alubia con su brote
        g.disc(6, 7, 3.6); g.rect(5, 1, 2, 3, 'L'); g.put(7, 1, 'l')
    elif isle == 'costa':                                       # vaina de kelp: ovalada, con su mancha turquesa
        for y in range(2, 11):
            w = 2 + (min(y - 2, 10 - y) // 2)
            g.rect(6 - w, y, 2 * w, 1, 'b')
        g.disc(6, 6.5, 4.2); g.put(5, 6, 'x'); g.put(6, 6, 'x'); g.put(6, 7, 'y')
    elif isle == 'fortaleza':                                   # perno: cabeza hexagonal y rosca
        g.rect(2, 2, 8, 4, 'b'); g.rect(3, 1, 6, 1, 'o'); g.rect(2, 2, 1, 4, 'o'); g.rect(9, 2, 1, 4, 'o'); g.rect(3, 6, 6, 1, 'o')
        g.rect(3, 2, 2, 2, 'h'); g.rect(5, 7, 2, 4, 'b'); g.rect(4, 7, 1, 4, 'o'); g.rect(7, 7, 1, 4, 'o')
        for y in (8, 10): g.put(5, y, 's'); g.put(6, y, 's')
    elif isle == 'nieve':                                       # esquirla de hielo: rombo con brillo
        for y in range(1, 11):
            w = 5 - abs(y - 5.5) * 0.8
            g.rect(int(6 - w), y, int(2 * w), 1, 'b')
        for y in range(1, 11): g.put(int(6 - (5 - abs(y - 5.5) * 0.8)), y, 'o')
        g.put(5, 3, 'y'); g.put(5, 4, 'h'); g.put(6, 5, 'h')
    elif isle == 'cueva':                                       # espora que brilla
        g.disc(6, 6, 4.0, shade=False)
        g.disc(6, 6, 2.6, shade=False)
        for x, y in ((6, 6), (5, 5), (6, 5), (5, 6)): g.put(x, y, 'y')
        g.rect(4, 4, 4, 4, 'x'); g.rect(5, 5, 2, 2, 'y')
    elif isle == 'volcan':                                      # guijarro de obsidiana con una ascua
        g.disc(6, 6.5, 4.0); g.put(6, 6, 'x'); g.put(7, 7, 'x'); g.put(6, 7, 'y')
    return g.img(ISLES[isle])


# ── El TALLO (16x16, se repite), la BASE, la COPA, el BROTE y la PLATAFORMA de hojas ──
def stem(isle, kind):
    """kind: 'stem' (tramo), 'base' (raíz / arranque) o 'top' (copa)"""
    g = G(16, 16)
    if isle == 'pradera':
        g.rect(5, 0, 6, 16, 'b'); g.rect(5, 0, 1, 16, 'o'); g.rect(10, 0, 1, 16, 'o'); g.rect(6, 0, 1, 16, 'h'); g.rect(9, 0, 1, 16, 's')
        g.put(10, 4, 'l'); g.put(11, 3, 'l'); g.put(12, 3, 'L'); g.put(5, 11, 'l'); g.put(4, 10, 'L')   # zarcillos
        if kind == 'base':
            for x in (4, 5, 10, 11): g.put(x, 15, 'x')
            g.put(3, 14, 'x'); g.put(12, 14, 'x')
        if kind == 'top':
            g.g = [['.'] * 16 for _ in range(16)]
            g.rect(7, 8, 2, 8, 'b'); g.rect(7, 8, 1, 8, 'h')
            for x, y in ((5, 6), (4, 5), (3, 5), (10, 6), (11, 5), (12, 5), (7, 5), (8, 4), (8, 3)): g.put(x, y, 'L')
            g.put(8, 2, 'l')
    elif isle == 'costa':                                       # kelp: cinta ondulada con vejigas
        for y in range(16):
            x = 5 + (1 if (y // 4) % 2 else 0)
            g.put(x - 1, y, 'o'); g.rect(x, y, 5, 1, 'b'); g.put(x, y, 'h'); g.put(x + 4, y, 's'); g.put(x + 5, y, 'o')
        g.disc(11, 5, 1.6, shade=False); g.put(11, 5, 'h')
        g.disc(4, 12, 1.6, shade=False); g.put(4, 12, 'h')
        if kind == 'top':
            g.g = [['.'] * 16 for _ in range(16)]
            for y in range(6, 16): g.rect(7, y, 2, 1, 'b')
            for x, y in ((6, 5), (5, 4), (9, 5), (10, 4), (8, 3), (8, 2)): g.put(x, y, 'L')
        if kind == 'base':
            g.rect(4, 14, 8, 2, 'o'); g.rect(5, 14, 6, 1, 's')
    elif isle == 'fortaleza':                                   # cadena: eslabones gordos que se trepan
        for y0 in (0, 8):
            g.rect(5, y0, 6, 1, 'o'); g.rect(5, y0 + 5, 6, 1, 'o'); g.rect(4, y0 + 1, 1, 4, 'o'); g.rect(11, y0 + 1, 1, 4, 'o')
            g.rect(5, y0 + 1, 6, 1, 'h'); g.rect(5, y0 + 4, 6, 1, 's')
            g.rect(7, y0 + 5, 2, 3, 'b'); g.put(7, y0 + 6, 'h')
        if kind == 'top':
            g.g = [['.'] * 16 for _ in range(16)]
            g.rect(6, 6, 4, 10, 'b'); g.rect(6, 6, 1, 10, 'h')
            g.rect(4, 3, 8, 3, 'b'); g.rect(4, 3, 8, 1, 'h'); g.rect(4, 5, 8, 1, 'o'); g.put(11, 2, 'o'); g.put(12, 1, 'o')
        if kind == 'base':
            g.rect(3, 13, 10, 3, 's'); g.rect(3, 13, 10, 1, 'o')
    elif isle == 'nieve':                                       # pilar de hielo
        g.rect(4, 0, 8, 16, 'b'); g.rect(4, 0, 1, 16, 'o'); g.rect(11, 0, 1, 16, 'o')
        g.rect(5, 0, 2, 16, 'h'); g.rect(10, 0, 1, 16, 's')
        for y in (3, 4, 10, 11): g.put(7 + (y % 2), y, 'y')
        if kind == 'top':
            g.g = [['.'] * 16 for _ in range(16)]
            for y in range(2, 16):
                w = min(4, (y - 2) // 2 + 1)
                g.rect(8 - w, y, 2 * w, 1, 'b'); g.put(8 - w, y, 'o'); g.put(8 + w - 1, y, 'o')
            g.put(7, 4, 'y'); g.put(7, 5, 'h')
    elif isle == 'cueva':                                       # tallo pálido de seta
        g.rect(5, 0, 6, 16, 'b'); g.rect(5, 0, 1, 16, 'o'); g.rect(10, 0, 1, 16, 'o'); g.rect(6, 0, 1, 16, 'h'); g.rect(9, 0, 1, 16, 's')
        g.put(8, 5, 'x'); g.put(8, 12, 'x')
        if kind == 'top':                                       # el sombrero que BRILLA
            g.g = [['.'] * 16 for _ in range(16)]
            g.rect(7, 9, 2, 7, 'b'); g.rect(7, 9, 1, 7, 'h')
            for y in range(3, 10):
                w = min(7, 2 + (y - 3))
                g.rect(8 - w, y, 2 * w, 1, 'x')
                g.put(8 - w, y, 'o'); g.put(8 + w - 1, y, 'o')
            g.rect(4, 4, 3, 2, 'y'); g.rect(9, 6, 2, 1, 'y'); g.rect(2, 9, 12, 1, 'o')
    elif isle == 'volcan':                                      # columna de basalto (prismas) con ascuas
        g.rect(3, 0, 10, 16, 'b'); g.rect(3, 0, 1, 16, 'o'); g.rect(12, 0, 1, 16, 'o'); g.rect(8, 0, 1, 16, 's')
        g.rect(4, 0, 1, 16, 'h')
        for y in (7, 15): g.rect(3, y, 10, 1, 'o')
        g.put(6, 4, 'x'); g.put(10, 11, 'x'); g.put(10, 12, 'y')
        if kind == 'top':
            g.rect(3, 0, 10, 2, 'h'); g.rect(3, 0, 10, 1, 'o')
    if kind == 'base' and isle in ('nieve', 'cueva', 'volcan'):
        g.rect(2, 14, 12, 2, 's'); g.rect(2, 14, 12, 1, 'o')
    return g.img(ISLES[isle])


def leaves(isle):
    """La COPA donde se está de pie (48x8, arriba del todo: la planta es una T — con las hojas a media altura parecía
    una cruz, y la de hielo, una espada): copa de hojas · flotadores de kelp · barra con ganchos · meseta de cristal ·
    el SOMBRERO de la seta (brilla) · la cara plana del basalto"""
    g = G(48, 8)
    if isle == 'pradera':                                       # copa de hojas anchas
        for x in range(1, 47):
            top = 1 + (abs(x - 24) // 9)
            g.rect(x, top, 1, 7 - top, 'L'); g.put(x, top, 'o'); g.put(x, 7, 'o')
            if x % 6 == 3: g.put(x, 4, 'l'); g.put(x, 5, 'l')
        g.put(0, 4, 'o'); g.put(47, 4, 'o')
    elif isle == 'costa':                                       # flotadores de kelp en fila
        for cx in range(4, 48, 8):
            for y in range(1, 8):
                for x in range(cx - 4, cx + 4):
                    d = ((x - cx + 0.5) / 4) ** 2 + ((y - 4) / 3.2) ** 2
                    if d <= 1: g.put(x, y, 'o' if d > 0.6 else ('h' if y < 4 and x < cx else 'b'))
            g.put(cx - 1, 3, 'y')
    elif isle == 'fortaleza':                                   # barra con ganchos a los lados
        g.rect(1, 2, 46, 4, 'b'); g.rect(1, 2, 46, 1, 'h'); g.rect(1, 5, 46, 1, 's'); g.rect(1, 1, 46, 1, 'o'); g.rect(1, 6, 46, 1, 'o')
        g.rect(0, 1, 1, 6, 'o'); g.rect(47, 1, 1, 6, 'o')
        for x in (5, 16, 31, 42): g.put(x, 3, 'y')
    elif isle == 'nieve':                                       # meseta de cristal, plana, con picos pequeños
        g.rect(1, 2, 46, 5, 'b'); g.rect(1, 2, 46, 1, 'y'); g.rect(1, 6, 46, 1, 'o'); g.rect(0, 2, 1, 5, 'o'); g.rect(47, 2, 1, 5, 'o')
        for x in range(3, 46, 7): g.put(x, 1, 'y'); g.put(x, 0, 'h')
        for x in range(5, 45, 9): g.put(x, 4, 'h')
    elif isle == 'cueva':                                       # el sombrero de la seta, ancho y que brilla
        for x in range(0, 48):
            top = 1 + int(((x - 23.5) / 24) ** 2 * 5)
            g.rect(x, top, 1, 7 - top, 'x'); g.put(x, top, 'o'); g.put(x, 7, 'o')
        for x, y in ((10, 3), (11, 3), (30, 3), (31, 2), (20, 2), (38, 4), (5, 5)): g.put(x, y, 'y')
    elif isle == 'volcan':                                      # la cara plana de la columna de basalto
        g.rect(2, 1, 44, 6, 'b'); g.rect(2, 1, 44, 1, 'h'); g.rect(2, 6, 44, 1, 'o'); g.rect(2, 1, 1, 6, 'o'); g.rect(45, 1, 1, 6, 'o')
        for x in (14, 34): g.rect(x, 1, 1, 6, 'o')
        g.put(8, 3, 'x'); g.put(26, 4, 'x'); g.put(26, 3, 'y'); g.put(40, 4, 'x')
    return g.img(ISLES[isle])


def sprout(isle):
    """El BROTE: 3 cuadros de 16x16 (asoma, crece, ya es base)"""
    base = stem(isle, 'base')
    top = stem(isle, 'top')
    out = Image.new('RGBA', (48, 16))
    for f, h in enumerate((5, 10, 16)):
        cv = Image.new('RGBA', (16, 16))
        t = top.crop((0, 16 - h, 16, 16))
        cv.paste(t, (0, 16 - h), t)
        if f == 2: cv = base
        out.paste(cv, (f * 16, 0), cv)
    return out


def assemble(isle, h=5):
    """Una planta montada de `h` casillas: la base, los tallos y, arriba, la COPA (donde se está de pie)"""
    cv = Image.new('RGBA', (48, 16 * h))
    b, s, l = stem(isle, 'base'), stem(isle, 'stem'), leaves(isle)
    cv.paste(b, (16, 16 * (h - 1)), b)
    for k in range(1, h): cv.paste(s, (16, 16 * (h - 1 - k)), s)
    cv.paste(l, (0, 0), l)
    return cv


def preview():
    S = 5
    cols = []
    for isle in ISLES:
        bg = Image.new('RGBA', (60, 120), rgb(ISLES[isle]['bg']))
        sd = seed(isle); bg.paste(sd, (2, 2), sd)
        sp = sprout(isle); bg.paste(sp, (6, 16), sp)
        pl = assemble(isle); bg.paste(pl, (6, 120 - pl.height), pl)
        cols.append(bg.resize((bg.width * S, bg.height * S), Image.NEAREST))
    out = Image.new('RGBA', (sum(c.width for c in cols), cols[0].height))
    x = 0
    for c in cols: out.paste(c, (x, 0)); x += c.width
    return out


def gif(isle, path):
    """Crece: la semilla cae, se planta y sube tramo a tramo hasta la copa; luego se marchita"""
    S = 5
    pal = ISLES[isle]
    frames, dur = [], []
    total = 5
    full = assemble(isle, total)
    for n in range(28):
        cv = Image.new('RGBA', (48, 100), rgb(pal['bg']))
        if n < 4:
            sd = seed(isle); cv.paste(sd, (18, 70 + n * 4 - 12), sd)
        else:
            k = min(1.0, (n - 4) / 12)
            hgt = int(full.height * k)
            alpha = 1.0 if n < 22 else max(0, 1 - (n - 22) / 5)
            if hgt > 0:
                part = full.crop((0, full.height - hgt, 48, full.height))
                if alpha < 1:
                    a = part.split()[3].point(lambda v: int(v * alpha))
                    part.putalpha(a)
                cv.paste(part, (0, 100 - hgt), part)
        frames.append(cv.resize((cv.width * S, cv.height * S), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
        dur.append(90 if n < 16 else 140)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=dur, loop=0, disposal=2)


if __name__ == '__main__':
    if '--apply' in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        for isle in ISLES:
            seed(isle).save(os.path.join(OUT, f'{isle}-seed.png'))
            sprout(isle).save(os.path.join(OUT, f'{isle}-sprout-Sheet.png'))
            for k in ('base', 'stem', 'top'): stem(isle, k).save(os.path.join(OUT, f'{isle}-{k}.png'))
            leaves(isle).save(os.path.join(OUT, f'{isle}-leaves.png'))
        print('  ' + OUT)
    os.makedirs(PRUEBAS, exist_ok=True)
    preview().save(os.path.join(PRUEBAS, 'vista_previa.png'))
    for isle in ISLES: gif(isle, os.path.join(PRUEBAS, f'anim_{isle}.gif'))
    print('  ' + PRUEBAS)
