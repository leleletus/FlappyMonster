#!/usr/bin/env python3
# LA PUERTA ACTIVABLE (types/mechanisms/door.lua): una hoja por isla, en una tira de 4 cuadros de 16x16
#   1 = sola (puerta de 1 casilla de alto), 2 = arriba, 3 = en medio (se repite), 4 = abajo.
# La hoja ocupa las columnas 2..13 del cuadro (12 px): entre dos puertas en casillas seguidas queda un hueco de 4 px
# (se leen como puertas distintas, una detrás de otra) y una puerta de 2 de ancho son dos hojas. Pocos colores y zonas
# planas (el usuario: sencillo y original), contorno del tono más oscuro de su propio color, luz arriba a la izquierda.
#   jungla    losa de piedra del templo (los colores del sillar) con un ojo verde tallado arriba
#   pradera   tablones verticales con dos flejes de hierro
#   costa     tablones pintados de verde mar con una cuerda atada
#   fortaleza rastrillo de hierro (barrotes con huecos que dejan ver detrás y púas abajo)
#   nieve     losa de hielo con una veta clara
#   cueva     losa de piedra oscura con un cristal cian
#   volcan    losa de basalto con una runa que brilla
#   python3 tools/art/world/make_doors.py           → vista previa en FlappyMonster_pruebas/puertas/vista_previa.png
#   python3 tools/art/world/make_doors.py --apply   → assets/images/mechanisms/door/<isla>-Sheet.png
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'puertas')
OUT = os.path.join(ROOT, 'assets', 'images', 'mechanisms', 'door')
ISLES = ['pradera', 'costa', 'fortaleza', 'nieve', 'cueva', 'volcan', 'jungla']      # (Isles.IDS)
X0, X1 = 2, 13                                                                      # la hoja: columnas 2..13


def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def new(): return Image.new('RGBA', (16, 16), (0, 0, 0, 0))


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): im.putpixel((x, y), c)


def slab(kind, pal, top, bottom, joint=False):
    """Losa lisa (piedra, hielo): contorno, luz a la izquierda y arriba, sombra a la derecha y abajo"""
    O, D, M, L = pal['O'], pal['D'], pal['M'], pal['L']
    im = new()
    rect(im, X0, 0, X1, 15, M)
    rect(im, X0 + 1, 0, X0 + 1, 15, L)
    rect(im, X1 - 1, 0, X1 - 1, 15, D)
    rect(im, X0, 0, X0, 15, O); rect(im, X1, 0, X1, 15, O)
    if top:
        rect(im, X0, 0, X1, 0, O); rect(im, X0 + 1, 1, X1 - 1, 1, L)
    elif joint:
        rect(im, X0 + 1, 0, X1 - 1, 0, D)          # (junta con el sillar de encima)
    if bottom:
        rect(im, X0, 15, X1, 15, O); rect(im, X0 + 1, 14, X1 - 1, 14, D)
    return im


def stone(pal, glyph):
    """Losa de sillares (una junta por casilla) con su glifo en la de arriba"""
    def frame(top, bottom):
        im = slab('stone', pal, top, bottom, joint=not top)
        if top: glyph(im)
        return im
    return [frame(True, True), frame(True, False), frame(False, False), frame(False, True)]


def eye(pal):
    G, B, O = pal['G'], pal['B'], pal['O']
    def g(im):
        y = 6                                       # (un ojo tallado: borde oscuro, iris verde, pupila clara)
        rect(im, 6, y, 9, y, O); rect(im, 4, y + 1, 11, y + 1, O)
        rect(im, 5, y + 2, 10, y + 2, G); rect(im, 4, y + 2, 4, y + 2, O); rect(im, 11, y + 2, 11, y + 2, O)
        rect(im, 7, y + 2, 8, y + 2, B)
        rect(im, 4, y + 3, 11, y + 3, O); rect(im, 6, y + 4, 9, y + 4, O)
        rect(im, 5, y + 3, 10, y + 3, G); rect(im, 7, y + 3, 8, y + 3, B)
    return g


def crystal(pal):
    G, B = pal['G'], pal['B']
    def g(im):
        rect(im, 7, 5, 8, 11, G); rect(im, 6, 7, 9, 9, G)
        rect(im, 7, 6, 7, 9, B)
    return g


def rune(pal):
    G, B = pal['G'], pal['B']
    def g(im):
        rect(im, 7, 4, 8, 11, G); rect(im, 5, 6, 6, 6, G); rect(im, 9, 9, 10, 9, G)
        rect(im, 7, 6, 7, 9, B)
    return g


def ice(pal):
    """Losa de hielo: sin juntas, una veta clara en diagonal en cada casilla"""
    def frame(top, bottom):
        im = slab('ice', pal, top, bottom)
        for i in range(5):
            x, y = 9 - i, 4 + i * 2
            if X0 + 2 <= x <= X1 - 2:
                rect(im, x, y, x, min(15, y + 1), pal['L'])
        return im
    return [frame(True, True), frame(True, False), frame(False, False), frame(False, True)]


def planks(pal, band):
    """Tablones verticales (madera) con sus juntas y una banda por casilla (`band`: fleje o cuerda)"""
    O, D, M, L = pal['O'], pal['D'], pal['M'], pal['L']
    def frame(top, bottom):
        im = new()
        rect(im, X0, 0, X1, 15, M)
        for x in (X0 + 1, 7):
            rect(im, x, 0, x, 15, L)                # (la luz de cada tablón)
        for x in (6, 10):
            rect(im, x, 0, x, 15, D)                # (juntas)
        rect(im, X1 - 1, 0, X1 - 1, 15, D)
        rect(im, X0, 0, X0, 15, O); rect(im, X1, 0, X1, 15, O)
        if top: rect(im, X0, 0, X1, 0, O)
        if bottom: rect(im, X0, 15, X1, 15, O); rect(im, X0 + 1, 14, X1 - 1, 14, D)
        band(im, 4 if top else (9 if bottom else 7))
        return im
    return [frame(True, True), frame(True, False), frame(False, False), frame(False, True)]


def iron_band(pal):
    def b(im, y):
        rect(im, X0, y, X1, y + 1, pal['I']); rect(im, X0 + 1, y, X1 - 1, y, pal['J'])
        for x in (X0 + 2, X1 - 2): im.putpixel((x, y + 1), pal['J'])
    return b


def rope_band(pal):
    def b(im, y):
        for x in range(X0, X1 + 1):
            im.putpixel((x, y), pal['R'] if (x % 2 == 0) else pal['S'])
            im.putpixel((x, y + 1), pal['S'] if (x % 2 == 0) else pal['R'])
    return b


def portcullis(pal):
    """Rastrillo: 3 barrotes de 2 px (huecos transparentes entre ellos), dos travesaños por casilla, púas abajo"""
    O, D, M, L = pal['O'], pal['D'], pal['M'], pal['L']
    bars = ((X0, X0 + 1), (7, 8), (X1 - 1, X1))
    def frame(top, bottom):
        im = new()
        last = 13 if bottom else 15
        for a, b in bars:
            rect(im, a, 0, a, last, L); rect(im, b, 0, b, last, D)
        for y in ((3, 11) if not bottom else (3,)):
            rect(im, X0, y, X1, y, M); rect(im, X0, y + 1, X1, y + 1, O)
        if top: rect(im, X0, 0, X1, 0, O); rect(im, X0, 1, X1, 1, M)
        if bottom:
            for a, b in bars:                       # (púas: se estrechan)
                im.putpixel((a, 14), L); im.putpixel((b, 14), D)
                im.putpixel((a if a % 2 else b, 15), O)
        return im
    return [frame(True, True), frame(True, False), frame(False, False), frame(False, True)]


PAL = {
    # (los del sillar del templo: assets/images/world/tiles/temple_brick.png)
    'jungla': dict(O=rgb('1e2620'), D=rgb('3e4a3c'), M=rgb('5f6e58'), L=rgb('8a9a7c'), G=rgb('4f7a26'), B=rgb('86b03c')),
    'pradera': dict(O=rgb('3e2412'), D=rgb('5c3a1e'), M=rgb('8a5a30'), L=rgb('b07a44'), I=rgb('3a3a46'), J=rgb('767684')),
    'costa': dict(O=rgb('1c3c44'), D=rgb('2a5f66'), M=rgb('3f8f98'), L=rgb('68b8bc'), R=rgb('e8dcb0'), S=rgb('b8a87c')),
    'fortaleza': dict(O=rgb('1e2028'), D=rgb('3a3e4a'), M=rgb('5a5f6e'), L=rgb('8c92a2')),
    # (los del iceberg: tools/art/world/make_iceberg.py)
    'nieve': dict(O=rgb('2c5a86'), D=rgb('5c92ba'), M=rgb('9cc6e0'), L=rgb('e6f4fa')),
    'cueva': dict(O=rgb('1a1a24'), D=rgb('2e2e3c'), M=rgb('4a4a5e'), L=rgb('6c6c84'), G=rgb('3fb4c8'), B=rgb('b8f4f8')),
    # (los del basalto: assets/images/world/tiles/basalt.png)
    'volcan': dict(O=rgb('241010'), D=rgb('3e1a1c'), M=rgb('5c2a26'), L=rgb('804238'), G=rgb('ff8a20'), B=rgb('ffd060')),
}


def frames(isle):
    p = PAL[isle]
    if isle == 'jungla': return stone(p, eye(p))
    if isle == 'cueva': return stone(p, crystal(p))
    if isle == 'volcan': return stone(p, rune(p))
    if isle == 'nieve': return ice(p)
    if isle == 'pradera': return planks(p, iron_band(p))
    if isle == 'costa': return planks(p, rope_band(p))
    if isle == 'fortaleza': return portcullis(p)
    raise KeyError(isle)


def sheet(isle):
    fs = frames(isle)
    im = Image.new('RGBA', (16 * len(fs), 16), (0, 0, 0, 0))
    for i, f in enumerate(fs): im.paste(f, (16 * i, 0))
    return im


def door(isle, h, k=0.0):
    """La puerta de `h` casillas abierta `k` (sube al techo: se recorta arriba), en una imagen de 16 x 16·h"""
    fs = frames(isle)
    col = Image.new('RGBA', (16, 16 * h), (0, 0, 0, 0))
    for i in range(h):
        f = fs[0] if h == 1 else (fs[1] if i == 0 else (fs[3] if i == h - 1 else fs[2]))
        col.paste(f, (0, 16 * i))
    off = int(round(k * 16 * h))
    out = Image.new('RGBA', col.size, (0, 0, 0, 0))
    out.paste(col.crop((0, off, 16, 16 * h)), (0, 0))
    return out


def preview():
    """Cada isla: cerrada, a medio abrir y abierta (3 de alto, bajo un dintel); abajo, tres puertas seguidas del templo"""
    S, H = 4, 3
    bg, wall = (40, 46, 40, 255), (70, 80, 66, 255)
    cw = 16 * 3 + 8
    W, Ht = 8 + cw * len(ISLES), 8 + (16 * H + 8) + 8 + (16 * H + 8) + 8
    im = Image.new('RGBA', (W, Ht), bg)
    for i, isle in enumerate(ISLES):
        x = 8 + i * cw
        rect(im, x - 2, 8, x + 16 * 3 + 1, 11, wall)                 # (el dintel)
        for j, k in enumerate((0.0, 0.5, 1.0)):
            d = door(isle, H, k)
            im.alpha_composite(d, (x + 16 * j, 12))
        rect(im, x - 2, 12 + 16 * H, x + 16 * 3 + 1, 12 + 16 * H + 3, wall)   # (el suelo)
    y = 12 + 16 * H + 12
    x = 8
    rect(im, x - 2, y - 4, x + 16 * 3 + 1, y - 1, wall)
    for j in range(3): im.alpha_composite(door('jungla', H), (x + 16 * j, y))
    rect(im, x - 2, y + 16 * H, x + 16 * 3 + 1, y + 16 * H + 3, wall)
    x = 8 + cw
    rect(im, x - 2, y - 4, x + 16 * 3 + 1, y - 1, wall)
    for j, k in enumerate((1.0, 0.3, 0.0)): im.alpha_composite(door('jungla', H, k), (x + 16 * j, y))
    rect(im, x - 2, y + 16 * H, x + 16 * 3 + 1, y + 16 * H + 3, wall)
    return im.resize((W * S, Ht * S), Image.NEAREST)


if __name__ == '__main__':
    os.makedirs(PRUEBAS, exist_ok=True)
    p = os.path.join(PRUEBAS, 'vista_previa.png')
    preview().save(p)
    print('vista previa:', p)
    if '--apply' in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        for isle in ISLES:
            path = os.path.join(OUT, isle + '-Sheet.png')
            sheet(isle).save(path)
            print('  ', os.path.relpath(path, ROOT))
