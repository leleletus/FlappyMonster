#!/usr/bin/env python3
# tools/ui/make_sky.py
# Cielo y fondos con paralaje (assets/images/sky/, arte a 1x; el juego lo dibuja a x4):
#   gradients.png   degradados del cielo en franjas de píxel: 5 cuadros de 8x180
#                   (día, atardecer, noche, cueva, submarino)
#   sun.png, moon.png, stars.png (3 cuadros de 3x3: centelleo), clouds.png (3 nubes de 48x16)
#   <bioma>_far.png / _mid.png / _near.png   capas de siluetas de 320 de ancho que se
#                   repiten a lo ancho sin costura (abajo = el suelo del nivel)
#   cave_top.png    techo de la cueva con estalactitas (cuelga de arriba del nivel)
#   rays.png        rayos de luz bajo el agua (se dibujan aditivos)
#   abyss_*, icecave_*, underground_*   fondos de PROFUNDIDAD (bajo la superficie)
#   (gradients.png: + abismo, cueva helada, subsuelo)
#   blend.png       tramado que une el suelo de la superficie con la profundidad (se tiñe)
# Sencillo a propósito: siluetas legibles de 2-3 tonos, sin detalle fino.
# No pisa lo que ya existe (--force [nombres]). Desde la raíz del repo:
#     python3 tools/ui/make_sky.py [--force]
import os, sys, math, random
from PIL import Image

FORCE = '--force' in sys.argv
ONLY = {a for a in sys.argv[1:] if not a.startswith('--')}
OUT = 'assets/images/sky'
W = 320


def rgb(h, a=255): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def save(name, img):
    if ONLY and name not in ONLY: return
    path = os.path.join(OUT, name + '.png')
    if os.path.exists(path) and not FORCE:
        print('  ' + path + ' ya existe: no se toca (--force)')
        return
    os.makedirs(OUT, exist_ok=True)
    img.save(path)
    print('  %-40s %dx%d' % (path, img.width, img.height))


def profile(terms, base):
    """Altura por columna, repetible a lo ancho: términos (amplitud, ciclos enteros, fase)."""
    return [base + sum(a * math.sin(2 * math.pi * k * x / W + p) for a, k, p in terms) for x in range(W)]


def fill_profile(h, prof, body, top=None, shade=None, dither=None):
    """Silueta: de la altura del perfil hacia abajo. `top` = filo claro de 1 px;
    `dither` = (color, filas) tramado en la parte de arriba del cuerpo."""
    im = Image.new('RGBA', (W, h), (0, 0, 0, 0))
    for x in range(W):
        y0 = max(0, int(round(h - prof[x])))
        for y in range(y0, h):
            c = body
            if shade and y > h - 6: c = shade
            if dither and y - y0 < dither[1] and (x + y) % 2 == 0: c = dither[0]
            if top and y == y0: c = top
            im.putpixel((x, y), c)
    return im


def over(a, b):
    out = a.copy(); out.alpha_composite(b); return out


# ── Cielo ─────────────────────────────────────────────────────────────────────
GRADS = {
    'day':   ['5aa0e6', '6cb0ee', '80c0f4', '98d0f8', 'b4e0fa'],
    'dusk':  ['3a3a78', '6a4a8a', 'b05a78', 'e88060', 'f8b070'],
    'night': ['0c1030', '121a40', '1a2450', '223060', '2c3c6c'],
    'cave':  ['141016', '1a151c', '211a24', '28202c', '302634'],
    'water': ['0e3a64', '134a78', '1a5c8c', '2470a0', '2c84b4'],
    'abyss': ['3a1424', '2e1020', '240c1a', '1a0814', '12060e'],
    'icecave': ['3c5a84', '344e74', '2c4264', '243656', '1c2a48'],
    'underground': ['3a2a1e', '33251a', '2c2016', '251b12', '1e160e'],
}


def gradients():
    """Franjas de color planas; en el cambio de franja, una sola fila tramada."""
    out = Image.new('RGBA', (8 * len(GRADS), 180))
    for i, cols in enumerate(GRADS.values()):
        n = len(cols)
        band = 180 / n
        for y in range(180):
            b = min(n - 1, int(y / band))
            nxt = int((b + 1) * band)
            for x in range(8):
                c = cols[b]
                if b < n - 1 and y == nxt - 1 and (x + y) % 2 == 0: c = cols[b + 1]
                out.putpixel((i * 8 + x, y), rgb(c))
    return out


def disc(size, r, col, rim=None, cut=None):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if d <= r:
                if cut and math.hypot(x - c - cut[0], y - c - cut[1]) <= cut[2]: continue
                im.putpixel((x, y), rim if (rim and d > r - 1.2) else col)
    return im


def sun():
    im = disc(24, 7.5, rgb('fff2a0'), rgb('ffd040'))
    for a in range(8):          # rayos cortos
        ang = a * math.pi / 4
        for d in (9.5, 10.5):
            x, y = int(round(11.5 + math.cos(ang) * d)), int(round(11.5 + math.sin(ang) * d))
            im.putpixel((x, y), rgb('ffd040'))
    return im


def moon():
    im = disc(20, 8, rgb('eef0f8'), rgb('c8cce0'), cut=(4, -3, 6.5))
    for x, y in ((6, 9), (8, 13), (5, 12)):
        if im.getpixel((x, y))[3]: im.putpixel((x, y), rgb('c8cce0'))
    return im


def stars():
    W_, Y = rgb('ffffff'), rgb('c8d8ff')
    out = Image.new('RGBA', (9, 3), (0, 0, 0, 0))
    out.putpixel((1, 1), W_)
    for x, y in ((4, 0), (3, 1), (4, 1), (5, 1), (4, 2)): out.putpixel((x, y), Y if (x, y) != (4, 1) else W_)
    out.putpixel((7, 1), Y)
    return out


def clouds():
    out = Image.new('RGBA', (48 * 3, 16), (0, 0, 0, 0))
    shapes = [[(10, 10, 6), (18, 7, 7), (27, 8, 6), (35, 11, 5)], [(12, 11, 5), (21, 8, 6), (30, 11, 5)],
              [(8, 11, 4), (15, 9, 5), (24, 7, 6), (33, 9, 5), (40, 11, 4)]]
    for i, blobs in enumerate(shapes):
        for y in range(16):
            for x in range(48):
                inside = any((x - bx) ** 2 + ((y - by) * 1.3) ** 2 < r * r for bx, by, r in blobs) and y <= 13
                if inside:
                    below = not any((x - bx) ** 2 + ((y + 2 - by) * 1.3) ** 2 < r * r for bx, by, r in blobs) or y >= 12
                    out.putpixel((i * 48 + x, y), rgb('dde6f4') if below else rgb('ffffff'))
    return out


# ── Capas por bioma ───────────────────────────────────────────────────────────
rnd = random.Random(5)


def trees_on(im, prof, h, every, size, col, kind='round', top=None):
    """Árboles sobre un perfil (separación entera: se repite sin costura)."""
    for x0 in range(0, W, every):
        x0 += rnd.randrange(0, max(1, every // 3))
        base = int(round(h - prof[x0 % W]))
        s = size + rnd.randrange(-1, 2)
        for y in range(base - s * 2, base + 1):
            for x in range(x0 - s, x0 + s + 1):
                xx = x % W
                if not (0 <= y < h): continue
                if kind == 'round':
                    ok = (x - x0) ** 2 + (y - (base - s)) ** 2 <= s * s
                else:   # pino: triángulo
                    ok = abs(x - x0) <= (y - (base - s * 2)) * 0.5
                if ok: im.putpixel((xx, y), top if (top and y < base - s * 1.4 and x < x0) else col)
    return im


def layer_meadow():
    far = fill_profile(90, profile([(10, 2, 0.3), (5, 5, 1.0)], 40), rgb('a8ccc0'), rgb('bcdcd0'))
    midp = profile([(8, 3, 1.2), (4, 7, 0.4)], 30)
    mid = fill_profile(70, midp, rgb('78b468'), rgb('94c87c'))
    nearp = profile([(4, 4, 2.0), (2, 9, 0.1)], 14)
    near = fill_profile(50, nearp, rgb('4f8f4c'), rgb('62a058'))
    near = trees_on(near, nearp, 50, 40, 6, rgb('3f7a44'), top=rgb('4f8f4c'))
    return far, mid, near


def layer_coast():
    far = Image.new('RGBA', (W, 60), (0, 0, 0, 0))
    for x in range(W):
        k = x % 160
        hgt = int(round(9 * math.sin(math.pi * k / 70))) if k < 70 else 0       # islas lejanas
        for y in range(40 - hgt, 60):
            c = rgb('8fb2c6') if y < 40 else (rgb('5a9ad0') if (y - 40) % 6 else rgb('8cc0e8'))
            far.putpixel((x, y), c)
    midp = profile([(5, 2, 0.7), (3, 5, 2.2)], 16)
    mid = fill_profile(50, midp, rgb('e2c888'), rgb('f0dca8'), rgb('d2b474'))
    near = Image.new('RGBA', (W, 90), (0, 0, 0, 0))
    trunk, leaf, leafL = rgb('6a4a34'), rgb('3f7a50'), rgb('55945e')
    for x0 in (30, 140, 230):            # palmeras
        for y in range(36, 90):
            bend = int((90 - y) * 0.12)
            for dx in (0, 1, 2): near.putpixel(((x0 + bend + dx) % W, y), trunk)
        tx, ty = x0 + 1 + int(54 * 0.12), 36
        for ang in (-3.0, -2.3, -1.6, -0.9, -0.2):        # hojas que cuelgan
            for d in range(0, 20):
                x = tx + math.cos(ang) * d
                y = ty + math.sin(ang) * d * 0.55 + d * d * 0.035
                for t in (-1, 0, 1):
                    yy = int(round(y + t))
                    if 0 <= yy < 90 and d < 19 - abs(t) * 4:
                        near.putpixel((int(round(x)) % W, yy), leafL if t < 0 else leaf)
    return far, mid, near


def layer_mountain(snowy=False):
    farp = profile([(30, 3, 0.2), (14, 7, 1.3), (6, 13, 0.7)], 70)
    far = fill_profile(130, farp, rgb('b4c0d8') if not snowy else rgb('d0dcf0'), rgb('ffffff'))
    for x in range(W):              # nieve en las cumbres
        y0 = int(round(130 - farp[x]))
        for y in range(y0, min(130, y0 + (6 if farp[x] > 80 else 0))):
            far.putpixel((x, y), rgb('ffffff'))
    midp = profile([(18, 4, 1.7), (8, 9, 0.2)], 45)
    mid = fill_profile(90, midp, rgb('7888a6') if not snowy else rgb('e8eef8'), rgb('94a2bc') if not snowy else rgb('ffffff'))
    nearp = profile([(5, 5, 0.9), (3, 11, 2.3)], 16)
    near = fill_profile(60, nearp, rgb('46645a') if not snowy else rgb('f4f8ff'), None, None)
    near = trees_on(near, nearp, 60, 26, 7, rgb('34503f') if not snowy else rgb('5c7a8c'), 'pine',
                    rgb('ffffff') if snowy else None)
    return far, mid, near


def layer_forest():
    farp = profile([(4, 3, 0.4), (2, 8, 1.0)], 40)
    far = fill_profile(80, farp, rgb('5c9c78'))
    far = trees_on(far, farp, 80, 14, 7, rgb('5c9c78'))
    midp = profile([(3, 2, 1.5)], 30)
    mid = fill_profile(110, midp, rgb('2f6b48'))
    mid = trees_on(mid, midp, 110, 30, 14, rgb('2f6b48'), top=rgb('3c7c56'))
    nearp = profile([(3, 5, 0.2)], 10)
    near = fill_profile(50, nearp, rgb('1f4f33'))
    near = trees_on(near, nearp, 50, 34, 9, rgb('1f4f33'))          # matorrales redondos
    return far, mid, near


def layer_cave():
    farp = profile([(10, 3, 0.9), (6, 8, 2.0)], 40)
    far = fill_profile(80, farp, rgb('3a3242'), rgb('463c50'))
    midp = profile([(6, 5, 0.1), (4, 11, 1.4)], 22)
    mid = fill_profile(60, midp, rgb('2a2430'), rgb('362e3e'))
    for x0 in range(15, W, 37):        # estalagmitas
        hgt = 10 + rnd.randrange(14)
        for i in range(hgt):
            hw = 3 * (1 - i / hgt)
            for x in range(int(x0 - hw), int(x0 + hw) + 1):
                y = int(60 - midp[x0 % W] - i)
                if 0 <= y < 60: mid.putpixel((x % W, y), rgb('2a2430'))
    top = Image.new('RGBA', (W, 70), (0, 0, 0, 0))
    topp = profile([(5, 4, 0.6), (3, 9, 1.1)], 14)
    for x in range(W):
        for y in range(0, int(topp[x])): top.putpixel((x, y), rgb('342c3c'))
    for x0 in range(8, W, 23):         # estalactitas
        hgt = 12 + rnd.randrange(30)
        for i in range(hgt):
            hw = 3.5 * (1 - i / hgt)
            for x in range(int(x0 - hw), int(x0 + hw) + 1):
                y = int(topp[x0 % W]) + i
                if y < 70: top.putpixel((x % W, y), rgb('342c3c'))
    return far, mid, top


def layer_underwater():
    farp = profile([(12, 2, 0.4), (6, 6, 1.9)], 40)
    far = fill_profile(90, farp, rgb('245a84'), rgb('2c6a94'))
    midp = profile([(5, 3, 2.1), (3, 8, 0.5)], 18)
    mid = fill_profile(110, midp, rgb('1a4466'))
    for x0 in range(6, W, 19):         # algas
        hgt = 30 + rnd.randrange(50)
        for i in range(hgt):
            x = x0 + int(round(math.sin(i * 0.2 + x0) * 2))
            y = int(110 - midp[x0 % W] - i)
            for dx in (0, 1, 2):
                if 0 <= y < 110: mid.putpixel(((x + dx) % W, y), rgb('1d5a52'))
    rays = Image.new('RGBA', (W, 160), (0, 0, 0, 0))
    for x0 in (20, 90, 150, 240, 290):
        for y in range(160):
            w = 6 + y // 14
            a = int(70 * (1 - y / 160))
            for x in range(x0 + y // 4, x0 + y // 4 + w):
                if (x + y) % 2 == 0 or a > 40: rays.putpixel((x % W, y), (255, 255, 255, a))
    return far, mid, rays


def layer_fortress():
    far, _, _ = layer_mountain()
    far = Image.eval(far, lambda v: v)                      # mismas montañas
    mid = Image.new('RGBA', (W, 100), (0, 0, 0, 0))
    col, top = rgb('4f4f66'), rgb('62627c')
    for x in range(W):               # muralla con almenas y torres
        h = 40
        tower = (x % 110) < 26
        if tower: h = 78
        if (x % 110) in range(4, 22) and tower and (x % 6) < 3: h = 84
        if not tower and (x % 8) < 4: h = 44
        for y in range(100 - h, 100):
            mid.putpixel((x, y), top if y == 100 - h else col)
        if tower and (x % 110) in (11, 12, 13, 14) and True:
            for y in range(100 - 64, 100 - 56): mid.putpixel((x, y), rgb('ffd060'))     # ventana
    return far, mid


def hanging(h, prof_terms, base, col, every, lo, hi, width=3.5):
    """Techo colgante: franja + puntas (estalactitas, carámbanos, raíces)."""
    im = Image.new('RGBA', (W, h), (0, 0, 0, 0))
    topp = profile(prof_terms, base)
    for x in range(W):
        for y in range(0, int(topp[x])): im.putpixel((x, y), col)
    for x0 in range(8, W, every):
        hgt = lo + rnd.randrange(hi - lo)
        for i in range(hgt):
            hw = width * (1 - i / hgt)
            for x in range(int(x0 - hw), int(x0 + hw) + 1):
                y = int(topp[x0 % W]) + i
                if y < h: im.putpixel((x % W, y), col)
    return im


def layer_abyss():
    far = fill_profile(90, profile([(12, 2, 1.1), (6, 7, 0.3)], 36), rgb('4a1c2c'), rgb('5a2636'))
    midp = profile([(6, 3, 0.4), (4, 9, 2.0)], 20)
    mid = fill_profile(80, midp, rgb('2e0e1a'), rgb('3e1624'))
    for x0 in range(12, W, 41):          # chimeneas / columnas de roca
        hgt = 20 + rnd.randrange(30)
        for i in range(hgt):
            for x in range(x0 - 3, x0 + 4):
                y = int(80 - midp[x0 % W] - i)
                if 0 <= y < 80: mid.putpixel((x % W, y), rgb('2e0e1a'))
    top = hanging(60, [(4, 3, 0.2), (3, 8, 1.4)], 10, rgb('2a0c18'), 31, 8, 26)
    return far, mid, top


def layer_icecave():
    far = fill_profile(80, profile([(10, 3, 0.6), (5, 8, 1.9)], 34), rgb('5a7eaa'), rgb('86a8d0'))
    mid = fill_profile(60, profile([(6, 4, 1.4), (3, 10, 0.2)], 20), rgb('3e5c88'), rgb('6e90bc'))
    top = hanging(60, [(4, 4, 1.0), (2, 9, 0.5)], 10, rgb('6e90bc'), 17, 8, 28, 2.5)
    return far, mid, top


def layer_underground():
    far = fill_profile(80, profile([(8, 3, 0.2), (4, 8, 1.6)], 30), rgb('4a3626'), rgb('58422e'))
    mid = fill_profile(60, profile([(6, 5, 1.1), (3, 11, 0.6)], 18), rgb('34261a'), rgb('42301f'))
    top = Image.new('RGBA', (W, 60), (0, 0, 0, 0))     # tierra con raíces colgando
    topp = profile([(3, 4, 0.8), (2, 9, 2.0)], 8)
    for x in range(W):
        for y in range(0, int(topp[x])): top.putpixel((x, y), rgb('2c2016'))
    for x0 in range(10, W, 21):
        x, y = float(x0), topp[x0 % W]
        for i in range(14 + rnd.randrange(24)):
            x += rnd.choice((-1, 0, 0, 1)) * 0.6
            if int(y) + i < 60: top.putpixel((int(x) % W, int(y) + i), rgb('5a4430'))
    return far, mid, top


def blend():
    """Tramado (blanco, se tiñe): de lleno arriba a casi nada abajo; une el suelo de la
    superficie con el fondo de profundidad."""
    im = Image.new('RGBA', (8, 8), (0, 0, 0, 0))
    dens = [8, 7, 6, 4, 3, 2, 1, 1]
    order = [0, 4, 2, 6, 1, 5, 3, 7]               # (reparto ordenado tipo Bayer en 8)
    for y, d in enumerate(dens):
        for x in range(8):
            if order.index((x + y * 3) % 8) < d: im.putpixel((x, y), (255, 255, 255, 255))
    return im


if __name__ == '__main__':
    print('Cielo y fondos:')
    save('gradients', gradients())
    save('sun', sun()); save('moon', moon()); save('stars', stars()); save('clouds', clouds())
    sets = {'meadow': layer_meadow(), 'coast': layer_coast(), 'mountain': layer_mountain(),
            'snow': layer_mountain(True), 'forest': layer_forest(), 'cave': layer_cave(),
            'underwater': layer_underwater(), 'fortress': layer_fortress(),
            'abyss': layer_abyss(), 'icecave': layer_icecave(), 'underground': layer_underground()}
    for b, layers in sets.items():
        names = {'cave': ('far', 'mid', 'top'), 'underwater': ('far', 'mid', 'rays')}.get(b, ('far', 'mid', 'near'))
        if b in ('abyss', 'icecave', 'underground'): names = ('far', 'mid', 'top')
        for n, im in zip(names, layers):
            if b == 'cave' and n == 'top': save('cave_top', im)
            elif n == 'rays': save('rays', im)
            else: save('%s_%s' % (b, n), im)
    save('blend', blend())
