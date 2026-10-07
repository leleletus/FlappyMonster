#!/usr/bin/env python3
# tools/art/story/make_mirror_shards.py
# EL ESPEJO de la historia y sus FRAGMENTOS (assets/images/story/mirror/). Todas las imágenes comparten
# el MISMO lienzo (48x64): dibujadas en el mismo punto, encajan solas y el espejo se va completando.
#   frame.png            el marco dorado con su pie y el fondo oscuro (sin cristal)
#   glass.png            el cristal ENTERO, sin grietas (el espejo restaurado)
#   shard_1..7.png       los 7 fragmentos, uno por jefe y en el orden de la historia:
#                        1 Rey Gummy · 2 Mega Crabby · 3 Nave Malvada · 4 Gran Bola de Nieve ·
#                        5 Mega Crabby helado · 6 Mega Crabby lúgubre · 7 el Espejo (el del CENTRO: donde
#                        chocó el monstruo, el último que se recupera)
#   shard_<n>a/b.png     Xtra Extremo: cada fragmento partido en dos (uno por cada jefe de la pareja)
# Cada fragmento refleja un poco el color de su isla. Estilo del juego: contorno = el tono más oscuro
# del propio cristal (nunca negro), luz arriba-izquierda.
#   python3 tools/art/story/make_mirror_shards.py            → solo la vista previa
#   python3 tools/art/story/make_mirror_shards.py --apply    → escribe los assets
import math, os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', '..', 'assets', 'images', 'story', 'mirror')
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/espejo/vista_previa.png'

W, H = 48, 64
CX, CY, RX, RY = 23.5, 27.5, 16.5, 22.5           # el cristal: un óvalo


def rgb(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


GLASS = [rgb(c) for c in ('#ffffff', '#d6eeff', '#a2ccf2', '#709edc')]     # brillo → sombra
EDGE = rgb('#34508c')
GOLD = [rgb(c) for c in ('#fff2a8', '#f0c040', '#b87c20', '#6c4418')]
BACK = rgb('#161a2a')

# Semillas de los fragmentos (Voronoi): la 7 es el punto del golpe, algo descentrado; las otras seis lo
# rodean, irregulares. (dx, dy) en fracción de los radios del óvalo.
SEEDS = [
    (-0.50, -0.62),      # 1 arriba-izquierda
    (0.42, -0.70),       # 2 arriba-derecha
    (0.74, -0.02),       # 3 derecha
    (0.36, 0.66),        # 4 abajo-derecha
    (-0.40, 0.72),       # 5 abajo-izquierda
    (-0.76, 0.06),       # 6 izquierda
    (-0.06, -0.04),      # 7 centro
]
WEIGHT = [0, 2, -1, 1, -2, 1, 18]                 # (px²: el del centro, algo más pequeño... o grande)
TINT = [rgb(c) for c in ('#a0f098', '#ffe498', '#c4c4dc', '#ffffff', '#98f0ff', '#d0a4ff', '#ffa48c')]
SPLIT = [18, -14, 12, -20, 16, -10, 22]           # Xtra: giro (grados) del corte respecto al ancho del fragmento
TINT_K = 0.36


def in_glass(x, y):
    return ((x - CX) / RX) ** 2 + ((y - CY) / RY) ** 2 <= 1.0


def shard_of(x, y):
    best, bi = None, 0
    for i, (dx, dy) in enumerate(SEEDS):
        sx, sy = CX + dx * RX, CY + dy * RY
        d = (x - sx) ** 2 + (y - sy) ** 2 - WEIGHT[i]
        if best is None or d < best:
            best, bi = d, i
    return bi


def base_colour(x, y):
    """El cristal sin grietas: bandas diagonales + dos destellos."""
    t = (x - CX) / RX * 0.55 + (y - CY) / RY * 0.75          # -1.3 (arriba-izq) .. 1.3
    k = 1 if t < -0.35 else (2 if t < 0.45 else 3)
    d = x + y * 0.5                                           # destellos: dos franjas diagonales
    if 24 <= d <= 26 or 29 <= d <= 29.5:
        k = 0
    if 49 <= d <= 50:
        k = max(k - 1, 1)
    return GLASS[k]


def mix(a, b, k):
    return tuple(int(round(a[i] * (1 - k) + b[i] * k)) for i in range(3))


def build():
    ids = {}                                                  # (x, y) → fragmento 0..6
    for y in range(H):
        for x in range(W):
            if in_glass(x, y):
                ids[(x, y)] = shard_of(x, y)
    cen = []
    for i in range(7):
        pts = [p for p, s in ids.items() if s == i]
        cen.append((sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)))
    # Xtra: cada fragmento se corta por su centro A LO ANCHO (perpendicular a su eje largo, con un pequeño
    # giro), para que las dos mitades sean trozos y no astillas
    ang = []
    for i in range(7):
        pts = [p for p, s in ids.items() if s == i]
        sxx = sum((p[0] - cen[i][0]) ** 2 for p in pts)
        syy = sum((p[1] - cen[i][1]) ** 2 for p in pts)
        sxy = sum((p[0] - cen[i][0]) * (p[1] - cen[i][1]) for p in pts)
        ang.append(0.5 * math.atan2(2 * sxy, sxx - syy) + math.pi / 2 + math.radians(SPLIT[i]))
    halves = {}                                               # (x, y) → 0 | 1 (mitad a / b)
    for (x, y), s in ids.items():
        a = ang[s]
        side = (x - cen[s][0]) * math.sin(a) - (y - cen[s][1]) * math.cos(a)
        halves[(x, y)] = 0 if side < 0 else 1
    return ids, halves, ang


def piece(pixels, tint):
    """Un trozo suelto (conjunto de píxeles): cristal teñido, contorno del propio cristal, canto de luz."""
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    edge = set()
    for (x, y) in pixels:
        if any(n not in pixels for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
            edge.add((x, y))
    for (x, y) in pixels:
        if (x, y) in edge:
            c = mix(EDGE, tint, 0.18)
        else:
            c = mix(base_colour(x, y), tint, TINT_K)
            if (x - 1, y) in edge and (x - 1, y - 1) in edge or (x, y - 1) in edge and (x - 1, y) in edge:
                c = GLASS[0]                                  # el canto de arriba-izquierda brilla
            elif (x, y - 1) in edge or (x - 1, y) in edge:
                c = mix(c, GLASS[0], 0.55)
        im.putpixel((x, y), c + (255,))
    return im


def glass_whole(ids):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for (x, y) in ids:
        im.putpixel((x, y), base_colour(x, y) + (255,))
    return im


def frame():
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def ring(x, y):
        return ((x - CX) / (RX + 4)) ** 2 + ((y - CY) / (RY + 4)) ** 2

    # pie: tallo y base, bajo el óvalo
    for y in range(50, 60):
        wdt = 3 if y < 57 else (7 if y < 59 else 11)
        for x in range(int(CX - wdt + 0.5), int(CX + wdt + 1.5)):
            im.putpixel((x, y), GOLD[2] + (255,))
    for y in range(60, 63):
        for x in range(int(CX - 13 + 0.5), int(CX + 13 + 1.5)):
            im.putpixel((x, y), GOLD[2] + (255,))
    # marco: anillo del óvalo + remate arriba
    for y in range(H):
        for x in range(W):
            r = ring(x, y)
            if r <= 1.0:
                im.putpixel((x, y), (GOLD[2] if not in_glass(x, y) else BACK) + (255,))
    for (x, y) in ((23, 0), (24, 0), (22, 1), (23, 1), (24, 1), (25, 1)):
        im.putpixel((x, y), GOLD[2] + (255,))
    # volumen: luz arriba-izquierda, sombra abajo-derecha, contorno con el tono oscuro del oro
    src = im.copy()

    def gold(x, y):
        if not (0 <= x < W and 0 <= y < H):
            return False
        p = src.getpixel((x, y))
        return p[3] > 0 and p[:3] != BACK

    for y in range(H):
        for x in range(W):
            if not gold(x, y):
                continue
            out = not (gold(x - 1, y) and gold(x + 1, y) and gold(x, y - 1) and gold(x, y + 1))
            if out:
                c = GOLD[3]
            else:
                lit = (x - CX) / RX * 0.6 + (y - CY) / RY * 0.8
                c = GOLD[0] if lit < -0.75 else (GOLD[1] if lit < 0.35 else GOLD[2])
                if not gold(x - 2, y) or not gold(x, y - 2):
                    c = GOLD[0] if lit < 0.35 else GOLD[1]
            im.putpixel((x, y), c + (255,))
    # remaches: cuatro gemas en el marco
    for (x, y) in ((23, 2), (24, 2), (4, 27), (4, 28), (43, 27), (43, 28), (23, 52), (24, 52)):
        im.putpixel((x, y), rgb('#e8485c') + (255,))
    del d
    return im


def main():
    apply = '--apply' in sys.argv
    ids, halves, ang = build()
    files = {'frame.png': frame(), 'glass.png': glass_whole(ids)}
    sizes = []
    for i in range(7):
        px = {p for p, s in ids.items() if s == i}
        files['shard_%d.png' % (i + 1)] = piece(px, TINT[i])
        ha = {p for p in px if halves[p] == 0}
        hb = px - ha
        files['shard_%da.png' % (i + 1)] = piece(ha, TINT[i])
        files['shard_%db.png' % (i + 1)] = piece(hb, TINT[i])
        sizes.append((len(px), len(ha), len(hb)))
    for i, s in enumerate(sizes):
        print('  fragmento %d: %d px (mitades %d + %d)' % ((i + 1,) + s))

    # vista previa: el espejo llenándose (0..7), el entero, cada fragmento suelto y sus mitades
    S, PAD = 5, 8
    cols = 9
    cw, ch = W * S + PAD, H * S + PAD
    pv = Image.new('RGBA', (cols * cw + PAD, 4 * ch + PAD), rgb('#2c3048') + (255,))

    def put(im, col, row):
        pv.alpha_composite(im.resize((W * S, H * S), Image.NEAREST), (PAD + col * cw, PAD + row * ch))

    for n in range(8):                                        # fila 0: 0..7 fragmentos
        m = files['frame.png'].copy()
        for i in range(n):
            m.alpha_composite(files['shard_%d.png' % (i + 1)])
        put(m, n, 0)
    whole = files['frame.png'].copy(); whole.alpha_composite(files['glass.png'])
    put(whole, 8, 0)
    for i in range(7):                                        # fila 1: sueltos; fila 2: mitades (separadas)
        put(files['shard_%d.png' % (i + 1)], i, 1)
        a = ang[i]
        ox, oy = int(round(-math.sin(a) * 2)), int(round(math.cos(a) * 2))
        ta = Image.new('RGBA', (W + 8, H + 8), (0, 0, 0, 0))
        ta.alpha_composite(files['shard_%da.png' % (i + 1)], (4 + ox, 4 + oy))
        ta.alpha_composite(files['shard_%db.png' % (i + 1)], (4 - ox, 4 - oy))
        put(ta.crop((4, 4, 4 + W, 4 + H)), i, 2)
    for n in (0, 5, 9, 14):                                   # fila 3: Xtra, el espejo con n mitades
        m = files['frame.png'].copy()
        k = 0
        for i in range(7):
            for h in 'ab':
                if k < n:
                    m.alpha_composite(files['shard_%d%s.png' % (i + 1, h)])
                k += 1
        put(m, (0, 1, 2, 3)[(0, 5, 9, 14).index(n)], 3)
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    pv.save(PREVIEW)
    print('  vista previa → ' + PREVIEW)

    if apply:
        os.makedirs(OUT, exist_ok=True)
        for name, im in files.items():
            im.save(os.path.join(OUT, name))
        print('  %d imágenes → assets/images/story/mirror/' % len(files))


if __name__ == '__main__':
    main()
