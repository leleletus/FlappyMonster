#!/usr/bin/env python3
# tools/ui/make_decorations.py
# Sprites de las decoraciones temáticas (arte a 1x; el juego las dibuja a x4):
#   assets/images/world/decorations/ice/      Hielo y nieve
#   assets/images/world/decorations/cave/     Cueva
#   assets/images/world/decorations/water/    Acuático
#   assets/images/world/decorations/tropical/ Tropical
#   assets/images/world/decorations/fx/       partículas y brillos que comparten
# Tamaños: las de SUBCELDA son de 8 px de ancho (32 px en juego = un cuarto de
# casilla); las de CELDA, de 16 (64 px = una casilla). Las tiras de animación
# llevan los cuadros uno al lado del otro (SpriteStrip).
# No pisa lo que ya existe (--force para rehacerlo). Desde la raíz del repo:
#     python3 tools/ui/make_decorations.py [--force] [nombre ...]
import os, sys, math, random
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import originals   # noqa: E402

FORCE = '--force' in sys.argv
ONLY = {a for a in sys.argv[1:] if not a.startswith('--')}
OUT = 'assets/images/world/decorations'
N = None                                  # transparente


def rgb(h, a=255):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def grid(rows, pal, w=None):
    w = w or max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        assert len(r) <= w, (r, w)
        for x, ch in enumerate(r):
            c = pal.get(ch)
            if c: im.putpixel((x, y), c)
    return im


def strip(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def outline_color(fr):
    """Color de contorno: el más frecuente entre los píxeles que tocan transparencia."""
    w, h = fr.size
    op = lambda x, y: 0 <= x < w and 0 <= y < h and fr.getpixel((x, y))[3] > 0
    count = {}
    for y in range(h):
        for x in range(w):
            if op(x, y) and not all(op(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                c = fr.getpixel((x, y)); count[c] = count.get(c, 0) + 1
    return max(count, key=count.get) if count else None


def edge_check(name, img):
    """Avisa si RELLENO (no contorno) toca el borde del lienzo por los lados o por arriba
    (por abajo si cuelga): se vería cortado en el juego."""
    if name in NO_PAD: return
    fw = FRAME_W.get(name, img.width) + 2
    hang = name in HANGING
    for k in range(img.width // fw):
        fr = img.crop((k * fw, 0, (k + 1) * fw, img.height))
        w, h = fr.size
        oc = outline_color(fr)
        pts = [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)] + \
              [(x, h - 1 if hang else 0) for x in range(w)]
        bad = [q for q in pts if fr.getpixel(q)[3] and fr.getpixel(q) != oc]
        if bad: print('  AVISO: %s (cuadro %d) toca el borde del lienzo: %s' % (name, k + 1, bad[:4]))


# Ancho de cuadro de las tiras (sin el margen) y lo que no lleva margen
FRAME_W = {'snowman-Sheet': 16, 'torch-Sheet': 8, 'anemone-Sheet': 8, 'clam-Sheet': 8, 'tiki_torch-Sheet': 8}
NO_PAD = {'cobweb', 'spider-Sheet', 'butterfly-Sheet'}
HANGING = {'icicle', 'icicle_small', 'stalactite'}


def complete_outline(fr, hang):
    """Cierra el contorno SOLO en el margen nuevo (donde el borde lo cortaba): pone el
    color de contorno junto al relleno que tocaba el borde del lienzo."""
    w, h = fr.size
    op = lambda x, y: 0 <= x < w and 0 <= y < h and fr.getpixel((x, y))[3] > 0
    oc = outline_color(fr)
    if not oc: return fr
    out = fr.copy()
    margin = [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)] + \
             [(x, h - 1 if hang else 0) for x in range(w)]
    for x, y in margin:
        if op(x, y): continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if op(x + dx, y + dy) and fr.getpixel((x + dx, y + dy)) != oc:
                out.putpixel((x, y), oc)
                break
    return out


def pad(name, img):
    """1 px de margen a los lados y arriba (o abajo si cuelga) + contorno cerrado, para
    que nada se vea cortado por el borde del lienzo. Se centra igual (ancla abajo-centro)."""
    if name in NO_PAD: return img
    fw = FRAME_W.get(name, img.width)
    hang = name in HANGING
    n = img.width // fw
    out = Image.new('RGBA', ((fw + 2) * n, img.height + 1), (0, 0, 0, 0))
    for k in range(n):
        fr = img.crop((k * fw, 0, (k + 1) * fw, img.height))
        big = Image.new('RGBA', (fw + 2, img.height + 1), (0, 0, 0, 0))
        big.paste(fr, (1, 0 if hang else 1))
        out.paste(complete_outline(big, hang), (k * (fw + 2), 0))
    return out


def save(theme, name, img):
    if ONLY and name not in ONLY: return
    path = os.path.join(OUT, theme, name + '.png')
    if os.path.exists(path) and not FORCE:
        print('  ' + path + ' ya existe: no se toca (--force)')
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if theme != 'fx':
        img = pad(name, img)
        edge_check(name, img)
    img.save(path)
    print('  %-52s %dx%d' % (path, img.width, img.height))


def outline(im, col):
    """Contorno de 1 px (4 vecinos) alrededor de lo opaco."""
    w, h = im.size
    src = im.copy()
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and src.getpixel((xx, yy))[3]:
                    im.putpixel((x, y), col)
                    break
    return im


def shade_cols(im, light, mid, dark, cut=(0.34, 0.7)):
    """Sombreado por columnas dentro de cada fila opaca: luz a la izquierda."""
    w, h = im.size
    for y in range(h):
        xs = [x for x in range(w) if im.getpixel((x, y))[3]]
        if not xs: continue
        x0, x1 = min(xs), max(xs)
        for x in xs:
            k = (x - x0) / max(1, x1 - x0)
            im.putpixel((x, y), light if k < cut[0] else (mid if k < cut[1] else dark))
    return im


# ═════════════════════════════ HIELO Y NIEVE ═════════════════════════════════
IO, ID, IL, IW = rgb('3c5aa8'), rgb('7aa0e6'), rgb('b4d2ff'), rgb('f0f8ff')
SW, SS, SO = rgb('f4f8ff'), rgb('c4d2f0'), rgb('8ea4d4')


def icicle_small():
    # tres puntas de hielo colgando del borde de arriba (8x8)
    im = Image.new('RGBA', (8, 8), (0, 0, 0, 0))
    for cx, base, ht in ((1.5, 3, 7), (4.5, 3, 5), (7.0, 2, 3)):
        for i in range(ht):
            hw = base / 2 * (1 - i / ht) ** 0.8
            for x in range(8):
                if abs(x + 0.5 - cx) <= hw + 0.01: im.putpixel((x, i), ID)
    shade_cols(im, IW, IL, ID, (0.34, 0.67))
    for x in range(8):
        if im.getpixel((x, 0))[3]: im.putpixel((x, 0), IL)
    return outline(im, IO)


def icicle():
    # carámbano de una casilla (16x16) colgando del borde de arriba
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for cx, base, ht in ((7.5, 7, 15), (3.0, 4, 8), (12.5, 4, 10)):
        for i in range(ht):
            hw = base / 2 * (1 - i / ht) ** 0.8
            for x in range(16):
                if abs(x + 0.5 - cx) <= hw + 0.01: im.putpixel((x, i), ID)
    shade_cols(im, IW, IL, ID, (0.34, 0.67))
    for x in range(16):
        if im.getpixel((x, 0))[3]: im.putpixel((x, 0), IL)
    return outline(im, IO)


def snow_pile():
    return grid([
        "........",
        "........",
        "........",
        "...ooo..",
        "..oWHWo.",
        ".oWWWWSo",
        "oWHWWSSo",
        "oSSSSSSo",
    ], {'o': SO, 'W': SW, 'H': rgb('ffffff'), 'S': SS})


def ice_crystal():
    return grid([
        "...o....",
        "..oWo...",
        "..oWLo.o",
        "o.oWLooL",
        "LooWLoLD",
        "LDoWLoLD",
        "oLDWLDDo",
        "oooooooo",
    ], {'o': IO, 'D': ID, 'L': IL, 'W': IW})


def frozen_bush():
    rnd = random.Random(5)
    w, h = 16, 12
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    leaf, leafL, leafD = rgb('3f7f78'), rgb('5ea393'), rgb('2c5a5a')
    cx, cy, rx, ry = 7.5, 7.5, 6.3, 5.0
    for y in range(h):
        for x in range(w):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            bump = 0.18 * math.sin(x * 1.7)
            if dx * dx + dy * dy < 1 + bump or (y >= 10 and 2 <= x <= 13):
                c = leafL if dx < -0.2 else (leafD if dx > 0.45 else leaf)
                im.putpixel((x, y), c)
    # nieve encima: las 2 primeras filas opacas de cada columna
    for x in range(w):
        ys = [y for y in range(h) if im.getpixel((x, y))[3]]
        if not ys: continue
        top = min(ys)
        depth = 2 if 2 <= x <= 12 else 1
        for y in range(top, min(h, top + depth)):
            im.putpixel((x, y), SW if y == top else SS)
    return outline(im, rgb('1e3a44'))


def snowy_pine():
    w, h = 16, 32
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    trunk, trunkD = rgb('7a5234'), rgb('553823')
    g, gL, gD = rgb('2f6b4f'), rgb('43896a'), rgb('1f4a37')
    for y in range(27, 32):
        for x in (7, 8): im.putpixel((x, y), trunk if x == 7 else trunkD)
    tiers = [(1, 11, 3.5), (8, 19, 5.5), (15, 27, 7.5)]    # (arriba, abajo, medio ancho abajo)
    for top, bot, half in tiers:
        for y in range(top, bot):
            k = (y - top + 1) / (bot - top)
            hw = max(0.5, half * k)
            for x in range(w):
                d = x - 7.5
                if abs(d) <= hw:
                    im.putpixel((x, y), gL if d < -hw * 0.35 else (gD if d > hw * 0.35 else g))
        # nieve: borde superior izquierdo de cada piso y una franja en la base
        for y in range(top, bot):
            k = (y - top + 1) / (bot - top)
            hw = max(0.5, half * k)
            xl = int(math.floor(7.5 - hw + 0.5))
            for x in range(xl, xl + 2):
                if 0 <= x < w and im.getpixel((x, y))[3]: im.putpixel((x, y), SW)
        for x in range(w):
            if im.getpixel((x, bot - 1))[3] and (x % 3 != 1): im.putpixel((x, bot - 1), SS if x > 8 else SW)
    im.putpixel((7, 0), SW); im.putpixel((8, 0), SS)
    return outline(im, rgb('14281f'))


def snowman():
    pal = {'k': rgb('2a2a36'), 'K': rgb('45455a'), 'o': SO, 'W': SW, 'S': SS, 'e': rgb('20202a'),
           'n': rgb('f08a24'), 'r': rgb('d8343c'), 'R': rgb('9c1f2c'), 'b': rgb('6b4a2e'), 'B': rgb('20202a')}
    base = [
        "................",
        "......kKkk......",
        "......kKkk......",
        "....kkkkkkkk....",
        ".....oWWWWo.....",
        ".....WeWWeS.....",
        ".....WWWnnn.....",
        ".....oWWWSo.....",
        "....rrrrrrrr....",
        "..b.oWWWWRrWo.b.",
        "...bWWWWWRrWSb..",
        "...oWWWBWWSSSo..",
        "...WWWWWWWWSSS..",
        "...WWWWBWWWSSS..",
        "...oWWWWWWSSSo..",
        "....ooWWWWSSo...",
    ]
    blink = list(base); blink[5] = ".....WkWWkS....."
    flap = list(base); flap[9] = "..b.oWWWWWRrWob."; flap[10] = "...bWWWWWWRrWb.."
    return strip([grid(base, pal), grid(blink, pal), grid(flap, pal)])


# ═════════════════════════════════ CUEVA ═════════════════════════════════════
RL, RM, RD, RO = rgb('a09488'), rgb('7c7068'), rgb('584e48'), rgb('2e2826')


def cone(w, h, tips, up):
    """Conos de roca: tips = [(x centro, ancho arriba/abajo, alto)]."""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for cx, base, ht in tips:
        for i in range(ht):
            k = 1 - i / ht
            hw = base / 2 * (k ** 0.9)
            y = i if not up else h - 1 - i
            for x in range(w):
                if abs(x + 0.5 - cx) <= hw + 0.01:
                    im.putpixel((x, y), RM)
    shade_cols(im, RL, RM, RD)
    return outline(im, RO)


def stalactite():
    return cone(16, 16, [(6.5, 10, 15), (12.5, 5, 9), (2.5, 4, 6)], up=False)


def stalagmite():
    return cone(16, 16, [(8.5, 11, 15), (3.5, 5, 8), (13, 4, 5)], up=True)


def stalagmite_small():
    return cone(8, 8, [(3.5, 5, 7), (6.5, 3, 4)], up=True)


def cave_crystals():
    w, h = 16, 14
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    P, PL, PD = rgb('9a5ce6'), rgb('d6b4ff'), rgb('5e2fa8')
    shards = [  # (base x, alto, inclinación, medio ancho)
        (7.5, 13, 0.0, 2.2), (4.2, 8, -1.3, 1.5), (11.2, 9, 1.4, 1.5), (9.8, 5, 0.8, 1.1), (5.6, 5, -0.6, 1.1)]
    for bx, ht, lean, hw in shards:
        tipx, tipy = bx + lean, h - 1 - ht
        poly = [(bx - hw, h - 1), (bx - hw + lean * 0.7, tipy + 2), (tipx, tipy), (bx + hw + lean * 0.7, tipy + 2), (bx + hw, h - 1)]
        d.polygon(poly, fill=P)
        d.line([(bx - hw * 0.35 + lean * 0.4, h - 2), (tipx - 0.3, tipy + 1)], fill=PL)
        d.line([(bx + hw * 0.7, h - 1), (bx + hw * 0.7 + lean * 0.7, tipy + 2)], fill=PD)
    for x in range(w):              # base de roca
        for y in (h - 1,):
            if 3 <= x <= 12: im.putpixel((x, y), RM)
    return outline(im, rgb('2a1250'))


def glow_mushroom():
    C, CH, CD, S, SD, O = rgb('4fe0e6'), rgb('d8fcff'), rgb('229aa8'), rgb('e8e0cc'), rgb('a89c80'), rgb('0e3a44')
    return grid([
        "........",
        "..OOOO..",
        ".OCHCCO.",
        "OCHCCCDO",
        "ODDDDDDO",
        ".OOSTOO.",
        "..OSTO..",
        ".OOOOOO.",
    ], {'O': O, 'C': C, 'H': CH, 'D': CD, 'S': S, 'T': SD})


def flame_frames(w, h, n, seed, pal):
    """Llama de pixel art: n cuadros w x h, base abajo al centro."""
    rnd = random.Random(seed)
    frames = []
    for f in range(n):
        im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        cx = (w - 1) / 2
        sway = math.sin(f / n * 2 * math.pi) * 0.9
        for y in range(h):
            k = (h - 1 - y) / (h - 1)                # 0 abajo → 1 arriba
            hw = (w / 2 - 0.4) * (1 - k) ** 0.8 * (0.85 + 0.25 * math.sin(f * 1.9 + y))
            c0 = cx + sway * k * 1.4
            for x in range(w):
                dd = abs(x - c0)
                if dd <= hw:
                    r = dd / max(0.5, hw)
                    col = pal[0] if (r < 0.45 and k < 0.55) else (pal[1] if r < 0.8 and k < 0.8 else pal[2])
                    im.putpixel((x, y), col)
        if rnd.random() < 0.8:                        # chispa suelta arriba
            x = int(cx + rnd.choice((-1, 0, 1)))
            im.putpixel((max(0, min(w - 1, x)), rnd.randrange(0, 2)), pal[2])
        frames.append(im)
    return frames


FIRE = (rgb('fff4b0'), rgb('ffb02e'), rgb('e0461e'))


def torch():
    # palo con abrazadera (abajo) + llama (arriba): 4 cuadros de 8x12
    wood, woodD, metal, metalD = rgb('8a5a32'), rgb('5c3a20'), rgb('9a9aa8'), rgb('55556a')
    frames = []
    for fl in flame_frames(6, 6, 4, 11, FIRE):
        im = Image.new('RGBA', (8, 12), (0, 0, 0, 0))
        base = grid([
            ".mMMMm..",
            ".mwwWm..",
            "..wWW...",
            "..wW....",
            ".MwWM...",
            "..wW....",
        ], {'m': metal, 'M': metalD, 'w': wood, 'W': woodD})
        im.paste(base, (0, 6), base)
        im.paste(fl, (1, 1), fl)
        frames.append(im)
    return strip(frames)


def cobweb():
    w = 16
    im = Image.new('RGBA', (w, w), (0, 0, 0, 0))
    col, colF = rgb('e6e6f0', 210), rgb('c8c8d8', 140)
    rays = [0, 22, 45, 68, 90]
    for a in rays:                     # hilos desde la esquina de arriba a la izquierda
        r = math.radians(a)
        for i in range(0, 17):
            x, y = int(round(math.cos(r) * i)), int(round(math.sin(r) * i))
            if 0 <= x < w and 0 <= y < w: im.putpixel((x, y), col)
    for R in (4, 8, 12):               # arcos (colgando un poco entre hilos)
        for ai in range(len(rays) - 1):
            a0, a1 = math.radians(rays[ai]), math.radians(rays[ai + 1])
            for s in range(12):
                t = s / 11
                a = a0 + (a1 - a0) * t
                rr = R - 1.0 * math.sin(t * math.pi)
                x, y = int(round(math.cos(a) * rr)), int(round(math.sin(a) * rr))
                if 0 <= x < w and 0 <= y < w and not im.getpixel((x, y))[3]:
                    im.putpixel((x, y), colF)
    return im


def spider():
    # 3 cuadros 7x5: patas A, patas B, hilo (1 px en el centro, se estira)
    k, e = rgb('2a2030'), rgb('e04040')
    a = grid([".k...k.", "k.kkk.k", ".kkekk.", "k.kkk.k", ".k...k."], {'k': k, 'e': e})
    b = grid(["k.....k", ".kkkkk.", "k.kekk.k"[:7], ".kkkkk.", "k.....k"], {'k': k, 'e': e})
    t = Image.new('RGBA', (7, 5), (0, 0, 0, 0))
    for y in range(5): t.putpixel((3, y), rgb('e6e6f0', 200))
    return strip([a, b, t])


def bones():
    B, BD, O, k = rgb('efe6cf'), rgb('bfb294'), rgb('5a4e3a'), rgb('2a2420')
    return grid([
        "..OOOO..",
        ".OBBBBO.",
        "OBkBBkDO",
        "OBkBBkDO",
        ".OBBBDO.",
        "O.OBDO.O",
        "BOOOOOOB",
        "OBBBBBBO",
    ], {'B': B, 'D': BD, 'O': O, 'k': k})


def seaweed(w=16, h=32, strands=((4, 30, 0.0), (8, 24, 1.6), (11, 16, 3.1)), seed=2):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    g, gL, gD = rgb('3aa25a'), rgb('7ad07a'), rgb('24703e')
    for bx, ht, ph in strands:
        for i in range(ht):
            y = h - 1 - i
            x = bx + math.sin(i * 0.33 + ph) * 1.6 * (i / ht)
            xi = int(round(x))
            for dx in (0, 1):
                if 0 <= xi + dx < w: im.putpixel((xi + dx, y), gL if dx == 0 else g)
            if i % 5 == 3 and i < ht - 2:         # hojitas
                side = 1 if (i // 5) % 2 else -1
                for j in (1, 2):
                    xx = xi + (2 if side > 0 else -1) + (j - 1) * side
                    if 0 <= xx < w: im.putpixel((xx, y - j + 1), g if j == 1 else gD)
    return outline(im, rgb('123a22'))


def seaweed_small():
    return seaweed(8, 8, ((2, 7, 0.4), (4, 6, 2.0)), 3)


def coral():
    C, CL, CD, O = rgb('f06a7a'), rgb('ffb0a8'), rgb('b83a5a'), rgb('5a1430')
    return grid([
        "..L.......L.....",
        ".OCO..L..OCO.L..",
        ".OCO.OCO.OCO.CO.",
        ".OCCOOCO.OCOOCO.",
        "..OCCOCO.OCCCO..",
        "L..OCCCO.OCCO...",
        "CO..OCCOOCCO..L.",
        "OCO..OCCCCO..OCO",
        ".OCO..OCCO..OCO.",
        "..OCOOCCDO.OCDO.",
        "...OCCCCDOOCDO..",
        "....OOCCDCCDO...",
        "......OCCDO.....",
        "......OCCDO.....",
        ".....OCCCDDO....",
        "....OOOOOOOOO...",
    ], {'O': O, 'C': C, 'L': CL, 'D': CD})


def coral_fan():
    P, PL, PD, O = rgb('9a5ad8'), rgb('d0a8ff'), rgb('6a32a8'), rgb('2e1250')
    return grid([
        "....OOOOOOO.....",
        "..OOLPLPLPPOO...",
        ".OLP.P.P.P.PDO..",
        "OLPPPPPPPPPPPDO.",
        "OP.P.P.P.P.P.PO.",
        "OPPPPPPPPPPPPPDO",
        ".OP.P.P.P.P.PDO.",
        ".OPPPPPPPPPPPDO.",
        "..OP.P.P.P.PDO..",
        "..OPPPPPPPPPDO..",
        "...OP.P.P.PDO...",
        "....OPPPPPDO....",
        ".....OOPDOO.....",
        "......OPDO......",
        "......OPDO......",
        ".....OOOOOO.....",
    ], {'O': O, 'P': P, 'L': PL, 'D': PD})


def anemone():
    O, B, BD, T, TL, W = rgb('4a1440'), rgb('b83a8a'), rgb('7a2060'), rgb('e86ab8'), rgb('ff9ad8'), rgb('fff0fa')
    pal = {'O': O, 'B': B, 'D': BD, 'T': T, 'L': TL, 'W': W}
    base = ["OBBBBBBO", "ODDDDDDO"]
    tops = [
        ["W..W..W.", "T..T.WT.", ".T.T.T.W", ".T.TT.T.", "..TLLT.T", ".LTTTTL."],
        [".W..W..W", ".T..T.T.", "T..T.T.T", ".T.TT.T.", ".TTLLTT.", ".LTTTTL."],
        ["..W..W..", "W.T..T.W", "T..TT..T", ".TT.T.T.", ".TTLLTT.", ".LTTTTL."],
    ]
    return strip([grid(t + base, pal) for t in tops])


def starfish():
    O, S, SL, SD = rgb('7a2a10'), rgb('f08030'), rgb('ffc070'), rgb('c05818')
    return grid([
        "........",
        "...OO...",
        "...OSO..",
        "OOOSLOOO",
        "OSSLSSDO",
        ".OSSSDO.",
        ".OSOOSO.",
        "OSO..OSO",
    ], {'O': O, 'S': S, 'L': SL, 'D': SD})


def shell():
    O, S, SL, SD = rgb('7a4a5a'), rgb('f4c8d0'), rgb('fff0f0'), rgb('d08898')
    return grid([
        "........",
        "........",
        "...OO...",
        "..OLSO..",
        ".OLSDSO.",
        "OLSDSDSO",
        "OSDSDSDO",
        ".OOOOOO.",
    ], {'O': O, 'S': S, 'L': SL, 'D': SD})


def clam():
    O, C, CL, CD, P, M = rgb('2a3050'), rgb('7a8ac0'), rgb('b0c0f0'), rgb('4a5a90'), rgb('fffaf0'), rgb('e05a7a')
    pal = {'O': O, 'C': C, 'L': CL, 'D': CD, 'P': P, 'M': M}
    closed = ["........", "........", "........", "..OOOO..", ".OLCCCO.", "OLCDCDCO", "OCDCDCDO", ".OOOOOO."]
    half = ["........", "........", "..OOOO..", ".OLCCCO.", "OODDDDOO", "OMMPMMMO", "OCDCDCDO", ".OOOOOO."]
    opn = ["..OOOO..", ".OLCCCO.", "OLCDCDCO", "OODDDDOO", "OM.PP.MO", "OMMPPMMO", "OCDCDCDO", ".OOOOOO."]
    return strip([grid(closed, pal), grid(half, pal), grid(opn, pal)])


# ═════════════════════════════════ TROPICAL ══════════════════════════════════
def hibiscus():
    R, RL, RD, Y, G, GD, O = rgb('e8283c'), rgb('ff7a7a'), rgb('a01024'), rgb('ffe050'), rgb('3cb44a'), rgb('237a30'), rgb('4a0a14')
    return grid([
        ".ORRO...",
        "ORLRRO..",
        "RLRYRRO.",
        "ORRRDRO.",
        ".ORDRO..",
        "..OGO.GG",
        "GGOGOGGD",
        ".GDGGDG.",
    ], {'R': R, 'L': RL, 'D': RD, 'Y': Y, 'G': G, 'H': GD, 'O': O})


def fern():
    w, h = 16, 12
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    g, gL, gD = rgb('44b04a'), rgb('8ae06a'), rgb('2a7a34')
    # hojas que salen del centro de la base y se arquean hacia fuera y abajo
    for ang, ln in ((-1.05, 7), (-0.55, 9), (-0.1, 10), (0.35, 9), (0.8, 8), (1.15, 6)):
        pts = []
        for i in range(ln * 3):
            t = i / (ln * 3)
            a = ang * (0.6 + 1.2 * t)
            x = 7.5 + math.sin(a) * t * ln * 1.0
            y = h - 1 - math.cos(a) * t * ln + (t ** 2) * 2.5
            pts.append((int(round(x)), int(round(y)), t))
        for x, y, t in pts:
            if 0 <= x < w and 0 <= y < h: im.putpixel((x, y), g)
        for j, (x, y, t) in enumerate(pts):
            if j % 3 == 0 and 0.15 < t < 0.9:
                for dx, dy, c in ((0, -1, gL), (1, 0, gD), (-1, 0, gL)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and not im.getpixel((xx, yy))[3]: im.putpixel((xx, yy), c)
    return outline(im, rgb('123a18'))


def tropical_bush():
    rnd = random.Random(9)
    w, h = 16, 14
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    g, gL, gD = rgb('2e9a48'), rgb('62cc5a'), rgb('1c6a34')
    blobs = [(4.6, 8.5, 3.3), (10.6, 8.5, 3.3), (7.5, 5.5, 4.2), (7.5, 10, 4.6)]
    for y in range(h):
        for x in range(w):
            for bx, by, r in blobs:
                if (x - bx) ** 2 + (y - by) ** 2 < r * r:
                    c = gL if (x - bx) < -r * 0.3 and (y - by) < 0 else (gD if (y - by) > r * 0.4 else g)
                    im.putpixel((x, y), c)
                    break
    for x in range(3, 13):
        im.putpixel((x, h - 1), gD)
    flowers = [(3, 6, rgb('ff5a8a')), (10, 4, rgb('ffd83a')), (12, 9, rgb('ff5a8a')), (6, 10, rgb('ffd83a'))]
    for fx, fy, fc in flowers:
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            im.putpixel((fx + dx, fy + dy), fc)
        im.putpixel((fx, fy), rgb('fff4d0'))
    return outline(im, rgb('0e3a1c'))


def tiki_torch():
    # poste de bambú (8x22 con cuenco) + llama; 4 cuadros de 8x28
    b, bL, bD, bowl, bowlD = rgb('d8b060'), rgb('f0d890'), rgb('9a7438'), rgb('7a4a28'), rgb('4e2e18')
    frames = []
    for fl in flame_frames(6, 8, 4, 21, FIRE):
        im = Image.new('RGBA', (8, 28), (0, 0, 0, 0))
        for y in range(10, 28):
            ring = (y - 10) % 6 == 5
            im.putpixel((3, y), bD if ring else bL)
            im.putpixel((4, y), bD if ring else b)
        for y, row in enumerate(["OBBBBBBO", ".OBbbBO.", "..OBBO.."]):
            for x, ch in enumerate(row):
                c = {'O': bowlD, 'B': bowl, 'b': bD}.get(ch)
                if c: im.putpixel((x, 7 + y), c)
        im.paste(fl, (1, 0), fl)
        frames.append(im)
    return strip(frames)


def pineapple():
    Y, YL, YD, G, GD, O = rgb('f0b830'), rgb('ffe070'), rgb('b87818'), rgb('4ab44a'), rgb('2a7a30'), rgb('5a3a10')
    return grid([
        "..G.G.G.",
        "...GGG..",
        "..GGHGG.",
        "..OOOOO.",
        ".OYLYDYO",
        ".OLYDYDO",
        ".OYDYDYO",
        "..OOOOO.",
    ], {'Y': Y, 'L': YL, 'D': YD, 'G': G, 'H': GD, 'O': O})


def butterfly():
    # 3 colores x 2 cuadros (alas abiertas / cerradas), 5x4 cada uno
    frames = []
    for c, cd in ((rgb('ffd83a'), rgb('d08a10')), (rgb('ff6ab0'), rgb('b02a70')), (rgb('5ad8ff'), rgb('2a78c0'))):
        k = rgb('2a2020')
        pal = {'c': c, 'd': cd, 'k': k}
        frames.append(grid(["cc.cc", "cdkdc", ".dkd.", "..k.."], pal))
        frames.append(grid(["..k..", ".ckc.", ".dkd.", "..k.."], pal))
    return strip(frames)


# ═════════════════════════════════ PARTÍCULAS ════════════════════════════════
def sparkle():
    W, L = rgb('ffffff'), rgb('d8ecff')
    return strip([
        grid([".....", ".....", "..W..", ".....", "....."], {'W': W}),
        grid([".....", "..L..", ".LWL.", "..L..", "....."], {'W': W, 'L': L}),
        grid(["..L..", "..W..", "LWWWL", "..W..", "..L.."], {'W': W, 'L': L}),
    ])


def ember():
    return strip([grid(["YO", "OR"], {'Y': rgb('fff0a0'), 'O': rgb('ffa030'), 'R': rgb('e04a1e')}),
                  grid(["O.", ".."], {'O': rgb('ff8a2a')})])


def spore():
    return strip([grid([".C.", "CWC", ".C."], {'C': rgb('7af0e8', 220), 'W': rgb('e8fffc')}),
                  grid(["...", ".C.", "..."], {'C': rgb('7af0e8', 200)})])


def bubble():
    E, W = rgb('c8ecff', 230), rgb('ffffff')
    return strip([grid([".EEE.", "EW..E", "E...E", "E...E", ".EEE."], {'E': E, 'W': W}),
                  grid(["E...E", ".....", "..E..", ".....", "E...E"], {'E': E})])


def clump():
    return strip([grid([".W.", "WWS", ".S."], {'W': rgb('ffffff'), 'S': rgb('c8d8f4')}),
                  grid(["W.", ".W"], {'W': rgb('ffffff')}).crop((0, 0, 3, 3))])


def glow():
    """Halo suave en escalones (blanco; se tiñe y se dibuja en modo aditivo)."""
    s = 32
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    steps = [200, 140, 95, 60, 34, 16]
    for y in range(s):
        for x in range(s):
            r = math.hypot(x - 15.5, y - 15.5) / 16
            if r < 1:
                im.putpixel((x, y), (255, 255, 255, steps[min(5, int(r * 6))]))
    return im


def leaf():
    return strip([grid([".G", "GD"], {'G': rgb('62cc5a'), 'D': rgb('2e9a48')}),
                  grid(["GD", ".."], {'G': rgb('62cc5a'), 'D': rgb('2e9a48')})])


# ═══════════════════ REDISEÑO de las decoraciones antiguas ════════════════════
# Mismo dibujo y tamaño que el original del usuario, con el estilo de las nuevas:
# contorno oscuro de 1 px (su propio color oscurecido) y luz arriba-izquierda /
# sombra abajo-derecha en los trazos planos. El original se guarda UNA vez FUERA
# del repo (tools/ui/originals.py) y siempre se parte de él (se puede rehacer).
OLD = [
    'assets/images/world/decorations/foliage/tulip.png',
    'assets/images/world/decorations/foliage/palmtree/palmtree.png',
    'assets/images/world/decorations/foliage/palmtree/coques.png',
    'assets/images/world/decorations/foliage/palmtree/palmleaves.png',
] + ['assets/images/world/decorations/foliage/stretch/stretch%d.png' % i for i in range(1, 6)]


def restyle(im, flat_shade):
    w, h = im.size
    src = im.copy()
    op = lambda x, y: 0 <= x < w and 0 <= y < h and src.getpixel((x, y))[3] > 0
    out = src.copy()
    if flat_shade:
        for y in range(h):
            for x in range(w):
                if not op(x, y): continue
                r, g, b, a = src.getpixel((x, y))
                if not op(x, y - 1) or not op(x - 1, y):
                    k = 1.28
                elif not op(x, y + 1) or not op(x + 1, y):
                    k = 0.78
                else:
                    continue
                out.putpixel((x, y), (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a))
    for y in range(h):
        for x in range(w):
            if op(x, y): continue
            for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                if op(x + dx, y + dy):
                    r, g, b, _ = src.getpixel((x + dx, y + dy))
                    out.putpixel((x, y), (int(r * 0.32), int(g * 0.32), int(b * 0.32), 255))
                    break
    return out


def redesign_old():
    for path in OLD:
        if ONLY and os.path.basename(path)[:-4] not in ONLY: continue
        orig, fresh = originals.keep(path)
        if not os.path.exists(orig): continue
        if not fresh and not FORCE:
            print('  ' + path + ' ya rediseñado (original en ' + os.path.basename(orig) + '; --force)')
            continue
        src = Image.open(orig).convert('RGBA')
        big = Image.new('RGBA', (src.width + 2, src.height + 1), (0, 0, 0, 0))
        big.paste(src, (1, 1))
        im = restyle(big, 'stretch' in path)
        im.save(path)
        print('  %-52s rediseño (original: %s)' % (path, os.path.basename(orig)))


SPRITES = [
    ('ice', 'icicle', icicle),
    ('ice', 'icicle_small', icicle_small), ('ice', 'snow_pile', snow_pile), ('ice', 'ice_crystal', ice_crystal),
    ('ice', 'frozen_bush', frozen_bush), ('ice', 'snowy_pine', snowy_pine), ('ice', 'snowman-Sheet', snowman),
    ('cave', 'stalactite', stalactite), ('cave', 'stalagmite', stalagmite), ('cave', 'stalagmite_small', stalagmite_small),
    ('cave', 'crystals', cave_crystals), ('cave', 'glow_mushroom', glow_mushroom), ('cave', 'torch-Sheet', torch),
    ('cave', 'cobweb', cobweb), ('cave', 'spider-Sheet', spider), ('cave', 'bones', bones),
    ('water', 'seaweed', seaweed), ('water', 'seaweed_small', seaweed_small), ('water', 'coral', coral),
    ('water', 'coral_fan', coral_fan), ('water', 'anemone-Sheet', anemone), ('water', 'starfish', starfish),
    ('water', 'shell', shell), ('water', 'clam-Sheet', clam),
    ('tropical', 'hibiscus', hibiscus), ('tropical', 'fern', fern), ('tropical', 'bush', tropical_bush),
    ('tropical', 'tiki_torch-Sheet', tiki_torch), ('tropical', 'pineapple', pineapple), ('tropical', 'butterfly-Sheet', butterfly),
    ('fx', 'sparkle-Sheet', sparkle), ('fx', 'ember-Sheet', ember), ('fx', 'spore-Sheet', spore),
    ('fx', 'bubble-Sheet', bubble), ('fx', 'clump-Sheet', clump), ('fx', 'glow', glow), ('fx', 'leaf-Sheet', leaf),
]

if __name__ == '__main__':
    print('Decoraciones:')
    for theme, name, fn in SPRITES:
        save(theme, name, fn())
    redesign_old()
