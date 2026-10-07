#!/usr/bin/env python3
# PROPUESTAS de diseño (no son todavía sprites del juego: el usuario elige y entonces se aplican):
#   · Gummy de CUEVA y de MAGMA, Crabby de RÍO (pradera) y de LAVA, y los de la FORTALEZA: 3 opciones cada uno — el
#     MISMO dibujo de siempre (cada píxel del Gummy / del Crabby) con otra paleta y, como mucho, un detalle de 1-3 px.
#   · el SALTARÍN (enemigo nuevo: salta en arco hacia el jugador): 3 diseños x 3 cuadros (quieto, agachado, en el
#     aire) x 6 islas (misma forma; cambia la paleta, las motas y lo que lleva en la cabeza).
# Estilo del juego: contorno azul marino muy oscuro (1e1e2a, nunca negro), luz arriba-izquierda, sombra abajo-derecha,
# caras de dos rayitas y una boca.
#   python3 tools/art/enemies/make_enemy_designs.py  →  /home/mtvemo/FlappyMonster_pruebas/enemigos/*.png
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'assets', 'images')
OUT = '/home/mtvemo/FlappyMonster_pruebas/enemigos'
NAVY = '1e1e2a'
BG = {'pradera': '8cc8f0', 'costa': '9cdcf0', 'fortaleza': '8a8ea8', 'nieve': 'b8d4f0', 'cueva': '3a3450', 'volcan': '6a2c2c',
      'neutro': '6e9a6e', 'ceniza': 'c08868'}


def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def base(path):
    """Un sprite del juego como mapa de PAPELES: o contorno, h brillo, b cuerpo, s sombra (por su luminosidad)"""
    im = Image.open(os.path.join(ROOT, path)).convert('RGBA')
    cols = sorted({p for p in im.getdata() if p[3]}, key=lambda p: sum(p[:3]))
    role = dict(zip(cols, 'osbh')) if len(cols) == 4 else None
    assert role, path
    return [[role.get(im.getpixel((x, y)), '.') if im.getpixel((x, y))[3] else '.' for x in range(im.width)] for y in range(im.height)]


def paint(grid, pal, edits=(), pad_top=0):
    """pal: papel → color hex. edits: (x, y, color hex | papel | '.') — y puede ser negativo si pad_top > 0"""
    g = [['.'] * len(grid[0]) for _ in range(pad_top)] + [r[:] for r in grid]
    for x, y, c in edits: g[y + pad_top][x] = c
    im = Image.new('RGBA', (len(g[0]), len(g)))
    for y, r in enumerate(g):
        for x, c in enumerate(r):
            if c == '.': continue
            im.putpixel((x, y), rgb(pal.get(c, c) if len(c) == 1 else c))
    return im


def sheet(name, title, rows, bg, scale=8, colw=None):
    """rows: [(etiqueta, [imágenes], color de fondo opcional)]"""
    cw = colw or max(i.width for _, ims, *_ in rows for i in ims) + 4
    chh = max(i.height for _, ims, *_ in rows for i in ims) + 4
    ncol = max(len(ims) for _, ims, *_ in rows)
    W, H = 150 + ncol * cw * scale, 26 + len(rows) * chh * scale
    out = Image.new('RGBA', (W, H), rgb('20202c'))
    d = ImageDraw.Draw(out)
    d.text((8, 6), title, fill=(255, 255, 255, 255))
    for r, (label, ims, *rest) in enumerate(rows):
        y0 = 26 + r * chh * scale
        d.rectangle((146, y0, W - 4, y0 + chh * scale - 4), fill=rgb(BG[rest[0] if rest else bg]))
        d.rectangle((146, y0 + (chh - 2) * scale, W - 4, y0 + chh * scale - 4), fill=(0, 0, 0, 60))
        for k, line in enumerate(label.split('\n')): d.text((8, y0 + 8 + k * 13), line, fill=(255, 255, 255, 255))
        for c, im in enumerate(ims):
            big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            out.paste(big, (150 + c * cw * scale + (cw - im.width) * scale // 2, y0 + (chh - 2 - im.height) * scale), big)
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, name + '.png'))
    print('  ' + os.path.join(OUT, name + '.png'))


def P(h, b, s, o=NAVY, **k): return dict({'o': o, 'h': h, 'b': b, 's': s}, **k)


GLOW, GLOW2 = '7ff0ff', 'd8ffff'
FIRE, FIRE2, FIRE3 = 'ffb030', 'ffe060', 'ff7818'

# ── GUMMY (16x16; ojos en x=5 y x=9, filas 5-7; boca fila 10) ────────────────
G = [base('enemies/gummy/gummy.png'), base('enemies/gummy/gummy1.png'), base('enemies/gummy/gummy2.png')]
EYES = [(5, 5), (5, 6), (5, 7), (9, 5), (9, 6), (9, 7)]
MOUTH = [(4, 9), (5, 10), (6, 10), (7, 10), (8, 10), (9, 10), (10, 9)]
CAP = [(x, 2, 'k') for x in range(3, 11)] + [(x, 3, 'K') for x in (3, 4, 8, 9)] + [(x, 1, 'o') for x in range(4, 10)]   # (la capa del Gummy helado)


def gummy(pal, edits=()):
    return [paint(g, pal, edits, pad_top=2) for g in G]


GUMMY_SETS = {
    'gummy_cueva': ('GUMMY DE CUEVA', 'cueva', [
        ('A  Cristal\nverde agua, con\ncristalitos que\nbrillan', P('e8fff8', 'a8e6d8', '5cb4b0'),
         [(5, 1, GLOW), (5, 0, GLOW2), (9, 1, GLOW), (7, 1, GLOW2)]),
        ('B  Hongo\nlila, con sombrero\nde seta luminosa', P('efe6ff', 'c9b8e0', '8c78b4'),
         [(x, -1, 'o') for x in range(5, 10)] + [(4, 0, 'o'), (10, 0, 'o')] + [(x, 0, '58e0c8') for x in range(5, 10)]
         + [(2, 1, 'o'), (12, 1, 'o'), (3, 0, 'o'), (11, 0, 'o')] + [(x, 1, '58e0c8') for x in range(3, 12)] + [(x, 1, '2ea898') for x in (10, 11)]
         + [(6, 0, GLOW2), (4, 1, GLOW2), (8, 1, GLOW2), (2, 2, 'o'), (12, 2, 'o')]),
        ('C  Palido\nsin color y con los\nojos cerrados; dos\nmotas de luz', P('ffffff', 'f4e8f0', 'd0b4cc'),
         [(x, y, 'b') for x, y in EYES] + [(4, 6, 'o'), (5, 6, 'o'), (9, 6, 'o'), (10, 6, 'o'), (3, 8, GLOW), (11, 8, GLOW)]),
    ]),
    'gummy_magma': ('GUMMY DE MAGMA', 'volcan', [
        ('A  Brasa\nroca oscura con\ngrietas, ojos y\nboca encendidos', P('804238', '5c2a26', '3e1a1c'),
         [(x, y, FIRE2) for x, y in EYES] + [(x, y, FIRE3) for x, y in MOUTH]
         + [(7, 3, FIRE), (7, 4, FIRE3), (11, 6, FIRE), (11, 7, FIRE3), (2, 8, FIRE), (3, 11, FIRE3)]),
        ('B  Lava\nlava viva con una\ncostra de roca\nen la cabeza', P('ffd860', 'ff8a28', 'd8481c', k='8a4a3c', K='5c2a26'), CAP),
        ('C  Ceniza\ncolor ceniza, con\nuna llamita en\nla cabeza', P('d88856', 'b25c3c', '8c3e2c'),
         [(7, 1, FIRE), (7, 0, FIRE2), (8, 1, FIRE3), (6, 1, FIRE3), (8, 0, FIRE)]),
    ]),
}

# ── CRABBY (16x9; ojos en (6,2) y (9,2); patas = contorno, filas 5-8) ────────
C = [base('enemies/crabby/crab1.png'), base('enemies/crabby/crab2.png'), base('enemies/crabby/crab3.png')]
LEGS = lambda g: [(x, y) for y in range(5, 9) for x in range(16) if g[y][x] == 'o']
CEYES = [(6, 2), (9, 2)]


def crab(pal, edits=(), legs=None, tips=None):
    out = []
    for g in C:
        e = list(edits)
        if legs: e += [(x, y, legs) for x, y in LEGS(g) if not (y == 5 and 2 <= x <= 13)]
        if tips: e += [(x, 8, tips) for x in range(16) if g[8][x] == 'o']
        out.append(paint(g, pal, e, pad_top=2))
    return out


CRAB_SETS = {
    'crabby_rio': ('CRABBY DE RIO (pradera, agua dulce)', 'pradera', [
        ('A  Musgo\nverde oliva, con\nmusgo en el lomo', P('d2e08c', '9cb45a', '5c7a3a'),
         [(5, 0, '3e7a2e'), (6, 0, '5aa040'), (10, 0, '3e7a2e'), (6, -1, '5aa040')]),
        ('B  Rio\nverde azulado,\npatas del color\ndel agua', P('b4ece0', '5ab4a8', '2e7c84'), [], '1e4a54'),
        ('C  Barro\nmarron, con un\nbrote en el lomo', P('e0c090', 'b08458', '7a5236'),
         [(8, -1, '5aa040'), (9, -2, '5aa040'), (7, -2, '8cd060'), (8, 0, '3e7a2e')]),
    ]),
    'crabby_lava': ('CRABBY DE LAVA', 'volcan', [
        ('A  Basalto\nroca con grietas\ny ojos encendidos', P('804238', '5c2a26', '3e1a1c'),
         [(x, y, FIRE2) for x, y in CEYES] + [(5, 1, FIRE), (8, 3, FIRE3), (10, 3, FIRE), (11, 2, FIRE3)]),
        ('B  Fundido\nlava viva, patas\nde roca', P('ffd860', 'ff8a28', 'd8481c'), [], '3a1414'),
        ('C  Obsidiana\nvidrio negro\nmorado, puntas\nal rojo', P('6a5a8a', '3a2a4a', '241a30'),
         [(x, y, FIRE3) for x, y in CEYES], None, FIRE3),
    ]),
}

# ── FORTALEZA (los dos) ──────────────────────────────────────────────────────
RIV = '4a5264'
FORT = [
    ('A  Acero\nchapa gris con\nremaches', P('eef2f6', 'b8c0cc', '7c8698'),
     [(3, 4, RIV), (11, 4, RIV), (3, 11, RIV), (10, 11, RIV)], [(4, 1, RIV), (11, 3, RIV)]),
    ('B  Oxido\nhierro oxidado\ncon remaches', P('e8a070', 'b86a3c', '7c3e28'),
     [(3, 4, '4a2418'), (11, 4, '4a2418'), (3, 11, '4a2418'), (10, 11, '4a2418')], [(4, 1, '4a2418'), (11, 3, '4a2418')]),
    ('C  Guardia\npiedra gris con\npenacho rojo', P('d0cedc', '9a98a4', '64627a'),
     [(7, 1, 'c83232'), (7, 0, 'e85050'), (8, 1, 'a02020'), (8, 0, 'c83232'), (6, 1, 'c83232')],
     [(6, 0, 'c83232'), (7, 0, 'e85050'), (8, 0, 'c83232'), (9, 0, 'a02020'), (7, -1, 'c83232'), (8, -1, 'a02020')]),
]

# ── EL SALTARÍN (16x16). Papeles: o h b s + w barriga, e ojos/boca, x motas, y lo de la cabeza (según la isla) ───────
HOP = {
    'A  Rana': dict(
        idle=["...oo.....oo....",
              "..ohbo...ohbo...",
              "..obeboooobeso..",
              ".oohbbxbbbxbbso.",
              ".obbbbbbbbbbbso.",
              ".obbeeeeeeebbso.",
              ".osbwwwwwwwwsso.",
              "oooosswwwwssoooo",
              "obbso.oooo.obbso",
              "ooooo......ooooo"],
        air=["...oo.....oo....",
             "..ohbo...ohbo...",
             "..obeboooobeso..",
             ".oohbbxbbbxbbso.",
             ".obbbbbbbbbbbso.",
             ".obbeeeeeeebbso.",
             ".osbwwwwwwwwsso.",
             "..oosswwwwssoo..",
             "..obo.oooo.obo..",
             "..obo......obo..",
             ".oobo......oboo.",
             ".oso........oso.",
             ".oo..........oo."],
        anchor=(7, 1), air_anchor=(7, 1), squash=4),
    'B  Muelle': dict(
        idle=["....oooooo......",
              "...ohhbbbso.....",
              "..obbxbbbbso....",
              "..obebbbebso....",
              "..obebbbebso....",
              "..obbbbbbbso....",
              "..obbeeebsso....",
              "...osssssso.....",
              "....oooooo......",
              ".....oso........",
              "......oso.......",
              ".....oso........",
              "....ooooo......."],
        air=["....oooooo......",
             "...ohhbbbso.....",
             "..obbxbbbbso....",
             "..obebbbebso....",
             "..obebbbebso....",
             "..obbbbbbbso....",
             "..obbeeebsso....",
             "...osssssso.....",
             "....oooooo......",
             ".....oso........",
             "......oso.......",
             "......oso.......",
             ".....oso........",
             ".....oso........",
             "......oso.......",
             "....ooooo......."],
        anchor=(6, -1), air_anchor=(6, -1), squash=5),
    'C  Liebre': dict(
        idle=["...oo...oo......",
              "..oho..oho......",
              "..obo..obo......",
              "..obo..obo......",
              "..oboooobo......",
              ".ohbbbbbbbo.....",
              ".obebbbebso.....",
              ".obebbbebso.....",
              ".obbbeebbso.....",
              ".obxwwwwsso.....",
              "..oowwwwsoo.....",
              ".obbooooobbo....",
              ".oooo...oooo...."],
        air=[".oo...oo........",
             ".oho..oho.......",
             "..obo..obo......",
             "..oboooobo......",
             ".ohbbbbbbbo.....",
             ".obebbbebso.....",
             ".obebbbebso.....",
             ".obbbeebbso.....",
             ".obxwwwwsso.....",
             "..oowwwwsoo.....",
             "..obo...obo.....",
             "..obo...obo.....",
             ".oobo..oobo.....",
             ".ooo...ooo......"],
        anchor=(5, 3), air_anchor=(5, 2), squash=7),
}
# Lo que lleva en la CABEZA en cada isla (dx, dy, color) desde el ancla de cada diseño: es lo que más los distingue
G1, G2 = '5aa040', '8cd060'
HEAD = {
    'brote':   [(0, 0, G1), (0, -1, G1), (1, -2, G2), (-1, -2, G2)],
    'concha':  [(0, 0, 'ff9ab0'), (1, 0, 'e86a90'), (0, -1, 'ffc8d4'), (1, -1, 'ff9ab0')],
    'penacho': [(0, 0, 'c83232'), (0, -1, 'e85050'), (1, -1, 'c83232'), (0, -2, 'c83232'), (1, -2, 'a02020')],
    'nieve':   [(-1, 0, 'fafcff'), (0, 0, 'fafcff'), (1, 0, 'fafcff'), (2, 0, 'cee2f6'), (0, -1, 'fafcff'), (1, -1, 'ecfaff')],
    'farol':   [(0, 0, '8c78b4'), (0, -1, '8c78b4'), (1, -2, '8c78b4'), (1, -3, GLOW), (2, -3, GLOW2)],     # como el del rape
    'llama':   [(0, 0, FIRE3), (1, 0, FIRE3), (0, -1, FIRE), (1, -1, FIRE3), (0, -2, FIRE2)],
}
ISLES = [
    ('pradera', 'PRADERA\nverde, motas\noscuras, un brote', P('c8f090', '7cc850', '3e8c3c', w='e8f4b4', e=NAVY, x='3e8c3c'), 'brote'),
    ('costa', 'COSTA\narena, motas\nturquesa, una\nconcha', P('fff4c0', 'f0d088', 'c89a50', w='fff8dc', e=NAVY, x='3cb4b4'), 'concha'),
    ('fortaleza', 'FORTALEZA\nacero, remaches,\npenacho rojo', P('eef2f6', 'b8c0cc', '7c8698', w='dfe4ec', e=NAVY, x=RIV), 'penacho'),
    ('nieve', 'CUMBRES\nhielo, escarcha,\ngorro de nieve', P('ecfaff', 'bee4fa', '78acde', w='e4f4ff', e=NAVY, x='ffffff'), 'nieve'),
    ('cueva', 'CUEVAS\npalido, ojos y\nmotas de luz,\nun farolillo', P('efe6ff', 'c9b8e0', '8c78b4', w='e4d8f4', e='2a6a8a', x=GLOW), 'farol'),
    ('volcan', 'VOLCAN\nroca, grietas y\nojos encendidos,\nuna llama', P('804238', '5c2a26', '3e1a1c', w='70342c', e=FIRE2, x=FIRE), 'llama'),
]


def norm(rows):
    w = 16
    return [list((r + '.' * w)[:w]) for r in rows]


def hopper(design, pal, cap):
    d = HOP[design]
    idle = norm(d['idle'])
    crouch = [r[:] for r in idle]
    del crouch[d['squash']]                                   # agachado: una fila menos de cuerpo
    air = norm(d['air'])
    out = []
    for g in (idle, crouch, air):
        ax, ay = d['air_anchor'] if g is air else d['anchor']
        e = [(ax + dx, ay + dy, c) for dx, dy, c in HEAD[cap]] if cap else []
        out.append(paint(g, pal, e, pad_top=5))
    return out


# ══ SEGUNDA RONDA (elegidos por el usuario; "que sean otra ESPECIE, como el Crabby helado respecto al Crabby: otra
# forma de cuerpo, otras proporciones, otra silueta — no el de siempre con otra paleta") ═══════════════════════════
V2 = {
    # Gummy de cueva: colores de la opción B (lila) + los cristales de la A, estilizados. Cuerpo de PERA (ancho abajo),
    # patas cortas y gruesas, y un racimo de cristales tallados que le sale de la cabeza, hacia un lado
    'gummy_cueva': (16, P('efe6ff', 'c9b8e0', '8c78b4', e=NAVY, g=GLOW, G=GLOW2, t='2ea8b8'), [
        ".....o..........",
        "....oGo....o....",
        "....oGgo..oGo...",
        "....oGgtooGgto..",
        "...ohGgtbbGgtso.",
        "..ohbbbbbbbbbso.",
        "..obbebbbebbbso.",
        ".obbbebbbebbbbso",
        ".obbbebbbebbbbso",
        ".obbbbbbbbbbbbso",
        ".obbebbbbbebbsso",
        ".oobbeeeeebbssoo",
        "..oosssssssssoo.",
        "....oo....oo....",
        "....oo....oo....",
        "...ooo...ooo...."]),
    # Gummy de magma: la opción A (roca, grietas, ojos y boca encendidos) con forma de VOLCANCITO: ancho abajo,
    # estrecho arriba y con el cráter encendido en la coronilla (plano: no es un pincho, se le puede pisar)
    'gummy_magma': (16, P('804238', '5c2a26', '3e1a1c', e=FIRE2, f=FIRE, F=FIRE2, c=FIRE3), [
        "................",
        "................",
        ".....offffo.....",
        "....ohFFFFso....",
        "....obbbbbso....",
        "...ohbbbbbbso...",
        "...obebbbebso...",
        "..ohbebbbebbso..",
        "..obbebbbebbso..",
        ".ohbbbbbbbbbbso.",
        ".obbcbbbbbcbbso.",
        ".obbbffffffbbso.",
        ".oosbbcbbbbssoo.",
        "..oooooooooooo..",
        "....oo....oo....",
        "...ooo...ooo...."]),
    # Crabby de río: color entre la A y la C (oliva pardo) con el musgo de la A. Cangrejo de agua dulce: caparazón
    # ALTO y redondo como un canto rodado, pinzas pequeñas por delante, patas cortas
    'crabby_rio': (18, P('d8cc8c', 'a89c5a', '6e6638', e=NAVY, m='5aa040', M='8cd060'), [
        "......mMm.........",
        ".....ommmoooo.....",
        "...oohmmbbbbboo...",
        "..ohhbbbbbbbbbbso.",
        "..obbbbbbbbbbbbso.",
        "..obbebbbbbbebbso.",
        "..obbbbeeeebbbsso.",
        ".oooosssssssssooo.",
        "ohho.o..oo..o.ohso",
        ".oo.o...oo...o.oo."]),
    # Crabby de lava: la opción A (basalto, grietas, ojos encendidos) como cangrejo de roca ANCHO y bajo, con dos
    # pinzas gruesas levantadas y tres pares de patas
    'crabby_lava': (18, P('804238', '5c2a26', '3e1a1c', e=FIRE3, E=FIRE2, f=FIRE), [
        "o..o.oooooooo.o..o",
        "obbo.ohbfbbso.obbo",
        "obboohbbfbbbsoobbo",
        ".ooobEbbfbbEbsooo.",
        "..oobbbeeeebbsoo..",
        "...oossssssssoo...",
        "...o.o.o..o.o.o...",
        "..o..o.o..o.o..o..",
        ".o...o.o..o.o...o."]),
    # Fortaleza, Gummy: la opción A (acero con remaches) como MUÑECO DE CUERDA: cuerpo cuadrado y una llave de latón
    # en el costado
    'gummy_fortaleza': (16, P('eef2f6', 'b8c0cc', '7c8698', e=NAVY, r=RIV, k='d8a838'), [
        "................",
        "................",
        "..oooooooooooo..",
        "..ohhbbbbbbbso..",
        "..obrbbbbbbrso..",
        "..obbebbbebbso.o",
        "..obbebbbebbsooo",
        "..obbebbbebbsokk",
        "..obbbbbbbbbsooo",
        "..obbebbbbebso.o",
        "..obbbeeeebbso..",
        "..obrbbbbbbrso..",
        "..oossssssssoo..",
        "....oo....oo....",
        "....oo....oo....",
        "...ooo...ooo...."]),
    # Fortaleza, Crabby: acero con remaches como una TORRETA: cúpula chata con faldón, rejilla por boca y cuatro patas
    # de pistón con pie
    'crabby_fortaleza': (16, P('eef2f6', 'b8c0cc', '7c8698', e=NAVY, r=RIV), [
        "....oooooooo....",
        "...ohhbbbbbso...",
        "..ohbrbbbbrbso..",
        "..obbebbbbebso..",
        ".oobbbbbbbbbbsoo",
        ".osseeeeeeeesso.",
        ".oooooooooooooo.",
        "..oo.oo..oo.oo..",
        "..o...o..o...o..",
        ".ooo.ooo.ooo.ooo"]),
}
V2_ROWS = [('GUMMY DE CUEVA\npera lila con\ncristales tallados', 'gummy_cueva', 'cueva', 'g'),
           ('GUMMY DE MAGMA\nvolcancito con el\ncrater encendido', 'gummy_magma', 'volcan', 'g'),
           ('GUMMY DE LA\nFORTALEZA\nmuneco de cuerda', 'gummy_fortaleza', 'fortaleza', 'g'),
           ('CRABBY DE RIO\ncanto rodado con\nmusgo y pincitas', 'crabby_rio', 'pradera', 'c'),
           ('CRABBY DE LAVA\nroca ancha, pinzas\nlevantadas', 'crabby_lava', 'volcan', 'c'),
           ('CRABBY DE LA\nFORTALEZA\ntorreta con patas', 'crabby_fortaleza', 'fortaleza', 'c')]


def v2(key):
    w, pal, rows = V2[key]
    for r in rows: assert len(r) == w, (key, r, len(r))
    return paint([list(r) for r in rows], pal)


def sheet_v2():
    white = P('ffffff', 'f2f2f6', 'c4c8d6')
    rows = []
    for lab, key, isle, kind in V2_ROWS:
        orig = gummy(white)[0] if kind == 'g' else crab(white)[0]
        rows.append((lab, [orig, v2(key)], isle))
    sheet('variantes_v2', 'VARIANTES, 2a ronda  -  a la izquierda el de siempre, a la derecha la especie nueva', rows, 'neutro', scale=9)


# ══ TERCERA RONDA (varias versiones de cada una, para comparar). Reglas del usuario: PATAS FINAS (1 px, solo el pie
# más ancho, como el Gummy), caras SIMÉTRICAS, pinzas que parezcan pinzas y miren hacia dentro ═════════════════════
LEGS_G = [".....o...o......", ".....o...o......", "....ooo.ooo....."]            # las del Gummy (cuerpo centrado en x = 7)
CAVE = P('efe6ff', 'c9b8e0', '8c78b4', e=NAVY, g=GLOW, G=GLOW2, t='2ea8b8')
V3_CAVE = [
    ('A  Pera\ncuerpo de pera,\ncristales tallados\na un lado', [
        "................", ".....o..........", "....oGo...o.....", "....oGgo.oGo....", "....oGgtooGto...",
        "...ohbbbbbso....", "..ohbebbbebso...", "..obbebbbebso...", ".obbbebbbebbso..", ".obbbbbbbbbbso..",
        ".obbebbbbbebso..", ".oobbeeeeebsoo..", "..oosssssssoo..."] + LEGS_G),
    ('B  Gema\ncuerpo tallado que\nse estrecha abajo,\ncristales de orejas', [
        "................", "................", "...o.......o....", "..oGo.....oGo...", "..oGgoooooGgo...",
        "..otbhhbbbsto...", "..obbebbbebso...", "..obbebbbebso...", "..obbebbbebso...", "..obbbbbbbbso...",
        "..obebbbbbeso...", "...obeeeeeso....", "....ooooooo....."] + LEGS_G),
    ('C  Bajo\nancho y bajito,\nojos separados,\nun solo cristal', [
        "................", "................", "................", "................", "................",
        ".......o........", "......oGo.......", "...oooGgtooo....", "..ohhbbbbbbso...", ".obbebbbbbebso..",
        ".obbebbbbbebso..", ".obbbbeeebbbso..", "..oosssssssoo..."] + LEGS_G),
]
STEEL = P('eef2f6', 'b8c0cc', '7c8698', e=NAVY, r=RIV, k='d8a838', K='f4d878')
FORT_BODY = ["................", "................", "..ooooooooooo...", "..ohhbbbbbbso...", "..obrbbbbbrso...",
             "..obbebbbebso...", "..obbebbbebso...", "..obbebbbebso...", "..obbbbbbbbso...", "..obebbbbbeso...",
             "..obbeeeeebso...", "..obrbbbbbrso...", "..oosssssssoo..."]
FORT_FEET = {
    'A': [".....o...o......", ".....o...o......", "....ooo.ooo....."],            # las del Gummy
    'A1': [".....o...o......", "....ooo..o......", ".........ooo...."],           # paso
    'B': [".....o...o......", ".....o...o......", "...ooo...ooo...."],            # botas: la punta hacia fuera
    'B1': [".....o...o......", "...ooo...o......", ".........ooo...."],
    'C': ["....ooo.ooo.....", ".....o...o......", "....ooo.ooo....."],            # pistones: casquillo arriba y pie abajo
    'C1': ["....ooo.ooo.....", "....ooo..o......", ".........ooo...."],
}
# la LLAVE de cuerda (en el costado): gira con el paso — de canto (fina) / de frente (alta)
KEY = {'alta': [(13, 7, 'o'), (14, 5, 'o'), (14, 6, 'K'), (14, 7, 'k'), (14, 8, 'k'), (14, 9, 'o'), (15, 6, 'o'), (15, 7, 'o'), (15, 8, 'o')],
       'media': [(13, 7, 'o'), (14, 6, 'o'), (14, 7, 'K'), (14, 8, 'o'), (15, 6, 'o'), (15, 7, 'k'), (15, 8, 'o')],
       'fina': [(13, 7, 'o'), (14, 6, 'o'), (14, 7, 'k'), (14, 8, 'o'), (15, 7, 'o')]}
RIVER = P('d8cc8c', 'a89c5a', '6e6638', e=NAVY, m='5aa040', M='8cd060', c='e4d8a0')
V3_RIVER = [
    ('A  Robusto\ncaparazon alto,\npatas largas,\npinzas a los lados', [
        "......mMm.........", ".....ommmoooo.....", "...oohmmbbbbboo...", "...ohbbbbbbbbbso..".replace('so..', 'so...')[:18],
        "...obebbbbbbeso...", "occobbbeeeebbsocco", "oc.oossssssssoo.co", "occ.o..o..o..o.cco",
        "...o...o..o...o...", "..oo..oo..oo..oo.."]),
    ('B  Pinzas arriba\nlas pinzas\nlevantadas, como\nsaludando', [
        "......mMm.........", "o.o..ommmoooo..o.o", "occoohmmbbbbboocco", ".ooohbbbbbbbbbsoo.",
        "...obebbbbbbeso...", "...obbbeeeebbso...", "...oossssssssoo...", "....o..o..o..o....",
        "...o...o..o...o...", "..oo..oo..oo..oo.."]),
    ('C  Esbelto\ncaparazon mas\nestrecho, patas\naun mas largas', [
        ".......mMm........", ".....ommmoooo.....", "....oohmmbbboo....", "....ohbbbbbbso....", "....obebbbbeso....",
        "occ.obbeeeebso.cco", "ocoooossssssooooco", "occ..o.o..o.o..cco", "....o..o..o..o....",
        "....o..o..o..o....", "...oo.oo..oo.oo..."]),
]
LAVA = P('804238', '5c2a26', '3e1a1c', e=FIRE3, E=FIRE2, f=FIRE)
LAVA_BODY = [".....oooooooo.....", "....ohbbffbbso....", "...ohbbbffbbbso...", "...obEbbffbbEso...", "...obbbeeeebbso...",
             "...oossssssssoo...", "...o.o.o..o.o.o...", "..o..o.o..o.o..o..", ".o...o.o..o.o...o."]
# pinza IZQUIERDA (filas desde y0, columnas desde x = 0); la derecha es su espejo
LAVA_CLAWS = [
    ('1  A los lados,\nhacia dentro\n(como los demas\nCrabbies)', 2, ["oo.", "obo", "ob.", "obo", ".o."]),
    ('2  Levantadas,\nabiertas hacia\ndentro', 0, [".oo", "ob.", "obo", "obo", ".oo"]),
    ('3  Mazas\ngordas, cerradas,\ncon la grieta\nencendida', 1, ["ooo", "obbo", "obfo", "obbo", ".oo."]),
    ('4  Tenazas\nlargas hacia\ndelante y abajo', 3, ["oo.", "obo", "obo", "ob.", "oo."]),
]


def maps(rows, pal, edits=()):
    w = len(rows[0])
    for r in rows: assert len(r) == w, (r, len(r), w)
    return paint([list(r) for r in rows], pal, edits)


def lava(y0, claw):
    g = [list(r) for r in LAVA_BODY]
    for dy, row in enumerate(claw):
        for dx, c in enumerate(row):
            if c == '.': continue
            for x in (dx, 17 - dx):
                if g[y0 + dy][x] == '.' or c != 'o': g[y0 + dy][x] = c
    return paint(g, LAVA)


def sheet_v3():
    white = P('ffffff', 'f2f2f6', 'c4c8d6')
    og, oc = gummy(white)[0], crab(white)[0]
    rows = [('GUMMY DE CUEVA\n' + lab, [og, maps(m, CAVE)], 'cueva') for lab, m in V3_CAVE]
    rows.append(('GUMMY FORTALEZA\nA  pies de Gummy\n(quieto, 2 pasos:\nla llave gira)',
                 [og, maps(FORT_BODY + FORT_FEET['A'], STEEL, KEY['alta']), maps(FORT_BODY + FORT_FEET['A1'], STEEL, KEY['media']),
                  maps(FORT_BODY + FORT_FEET['A'], STEEL, KEY['fina']), maps(FORT_BODY + FORT_FEET['A1'], STEEL, KEY['media'])], 'fortaleza'))
    rows.append(('GUMMY FORTALEZA\nB  botas con la\npunta hacia fuera',
                 [og, maps(FORT_BODY + FORT_FEET['B'], STEEL, KEY['alta']), maps(FORT_BODY + FORT_FEET['B1'], STEEL, KEY['media']),
                  maps(FORT_BODY + FORT_FEET['B'], STEEL, KEY['fina'])], 'fortaleza'))
    rows.append(('GUMMY FORTALEZA\nC  patas de piston\n(casquillo y pie)',
                 [og, maps(FORT_BODY + FORT_FEET['C'], STEEL, KEY['alta']), maps(FORT_BODY + FORT_FEET['C1'], STEEL, KEY['media']),
                  maps(FORT_BODY + FORT_FEET['C'], STEEL, KEY['fina'])], 'fortaleza'))
    rows += [('CRABBY DE RIO\n' + lab, [oc, maps(m, RIVER)], 'pradera') for lab, m in V3_RIVER]
    rows += [('CRABBY DE LAVA\n' + lab, [oc, lava(y0, claw)], 'ceniza') for lab, y0, claw in LAVA_CLAWS]      # (fondo claro: sobre el rojo oscuro no se veían las pinzas)
    sheet('variantes_v3', 'VARIANTES, 3a ronda  -  a la izquierda el de siempre; elige una version de cada', rows, 'neutro', scale=8)


# ══ CUARTA RONDA: los dos Crabbies que faltan. Del usuario: NINGÚN Crabby tiene boca; el de río = el cuerpo de la C
# con patas como las del Crabby helado y PELITOS (cangrejo de río grande), y las pinzas con otro enfoque; el de lava =
# pinzas a los lados hacia dentro pero CON EL DIBUJO de las de los demás Crabbies / Megas, y otra "cara" ════════════
CLAW_ROLE = {'1e1e2a': 'o', 'ffd8a8': 'h', 'f89e58': 'b', 'e26832': 's', 'a83e28': 's', 'ffffff': 'h', 'f2f2f6': 'b', 'c4c8d6': 's'}


def claw_frames(path, fw, skip_top=0):
    """Las pinzas del juego (tira de 2 cuadros: abierta / cerrada, pinza IZQUIERDA) como mapas de papeles"""
    im = Image.open(os.path.join(ROOT, path)).convert('RGBA')
    out = []
    for f in range(im.width // fw):
        g = []
        for y in range(skip_top, im.height):
            g.append([CLAW_ROLE['%02x%02x%02x' % im.getpixel((f * fw + x, y))[:3]] if im.getpixel((f * fw + x, y))[3] else '.' for x in range(fw)])
        out.append(g)
    return out


SMALL_CLAW = lambda: claw_frames('enemies/crabby_ice/claw_left-Sheet.png', 7, 1)        # la del Crabby helado (sin sus cerdas)
MEGA_CLAW = lambda: claw_frames('bosses/megacrabby/claw_left-Sheet.png', 10, 1)  # la del Mega Crabby (del usuario)
MITTEN = [[list(r) for r in ("..qq...", ".qqqqcc", "qqqqq..", ".qqqqcc", "..qq...")],       # "manopla" peluda, abierta
          [list(r) for r in ("..qq...", ".qqqqc.", "qqqqqcc", ".qqqqc.", "..qq...")]]       # cerrada

RIVER4 = P('d8cc8c', 'a89c5a', '6e6638', e=NAVY, m='5aa040', M='8cd060', l='8a7c44', q='4a4020', c='efe6c0')
RIVER_BODY = [".......mMm........", ".....ommmoooo.....", "....oohmmbbboo....", "....ohbbbbbbso....", "....obebbbbeso....",
              "....obbbbbbbso....", "....oossssssoo....",
              "..ol.ol....lo.lo..", ".ol..ol....lo..lo.", "ol...ol....lo...lo", "ol....ol..lo....lo", "o.....o....o.....o"]
RIVER_HAIR = [(4, 8), (3, 9), (2, 11), (4, 10), (5, 11), (7, 8), (8, 10)]            # pelitos (lado izquierdo; el derecho, espejo)

LAVA4 = P('804238', '5c2a26', '3e1a1c', e=FIRE3, E=FIRE2, f=FIRE)
LAVA_SHELL = [".....oooooooo.....", "....ohbbbbbbso....", "...ohbbbbbbbbso...", "...obbbbbbbbbso...", "...obbbbbbbbbso...",
              "...oossssssssoo...", "...o.o.o..o.o.o...", "..o..o.o..o.o..o..", ".o...o.o..o.o...o."]
LAVA_FACES = [
    ('ojos de brasa\ny grietas sueltas', [(5, 3, 'E'), (12, 3, 'E'), (8, 1, 'f'), (8, 2, 'f'), (9, 2, 'e'), (4, 4, 'e'), (5, 4, 'f'), (13, 2, 'f'), (11, 4, 'e')]),
    # (sin la "costura" de lava que llevaba debajo: parecía una boca, y ningún Crabby la tiene)
    ('mirada rasgada\n(ojos de rendija,\ncejas de roca)', [(5, 3, 'E'), (6, 3, 'E'), (11, 3, 'E'), (12, 3, 'E'), (4, 2, 'o'), (5, 2, 'o'), (12, 2, 'o'), (13, 2, 'o'),
                                                         (8, 1, 'f'), (9, 1, 'e')]),
    ('ojos oscuros como\nlos demas Crabbies\ny placas al rojo', [(6, 2, 'o'), (11, 2, 'o'), (8, 1, 'f'), (9, 1, 'e'), (8, 2, 'e'), (9, 3, 'f'), (8, 4, 'f'),
                                                           (4, 3, 'f'), (5, 3, 'e'), (12, 3, 'e'), (13, 3, 'f')]),
]


def with_claws(body, pal, claw, at, edits=(), hair=(), pad=5, claw_pal=None):
    """El cuerpo con sus dos pinzas (la izquierda en `at` = (x, y) de su esquina; la derecha, espejo), por delante"""
    w = len(body[0]) + 2 * pad
    g = [['.'] * w for _ in body]
    for y, r in enumerate(body):
        for x, c in enumerate(r): g[y][x + pad] = c
    for x, y, c in edits: g[y][x + pad] = c
    for x, y in hair:
        for xx in (x, len(body[0]) - 1 - x): g[y][xx + pad] = 'q'
    im = paint(g, pal)
    cw = len(claw[0])
    ci = paint(claw, claw_pal or pal)
    im.alpha_composite(ci, (at[0] + pad, at[1]))
    im.alpha_composite(ci.transpose(Image.FLIP_LEFT_RIGHT), (w - (at[0] + pad) - cw, at[1]))
    return im


def sheet_v4():
    white = P('ffffff', 'f2f2f6', 'c4c8d6')
    oc = crab(white)[0]
    small, mega = SMALL_CLAW(), MEGA_CLAW()
    body = [list(r) for r in RIVER_BODY]
    rows = [
        ('CRABBY DE RIO\n1  pinzas del juego\n(la del Crabby\nhelado), abierta\ny cerrada',
         [oc, with_claws(body, RIVER4, small[0], (-3, 4), hair=RIVER_HAIR), with_claws(body, RIVER4, small[1], (-3, 4), hair=RIVER_HAIR)], 'pradera'),
        ('CRABBY DE RIO\n2  manoplas peludas\n(cangrejo de rio),\nabierta y cerrada',
         [oc, with_claws(body, RIVER4, MITTEN[0], (-3, 4), hair=RIVER_HAIR), with_claws(body, RIVER4, MITTEN[1], (-3, 4), hair=RIVER_HAIR)], 'pradera'),
        ('CRABBY DE RIO\n3  pinzas grandes\n(la del Mega, a su\ntamano)',
         [oc, with_claws(body, RIVER4, mega[0], (-5, 4), hair=RIVER_HAIR), with_claws(body, RIVER4, mega[1], (-5, 4), hair=RIVER_HAIR)], 'pradera'),
    ]
    shell = [list(r) for r in LAVA_SHELL]
    hot = dict(LAVA4, h=FIRE3)                                # pinzas con el filo al rojo
    for i, (lab, face) in enumerate(LAVA_FACES):
        rows.append(('CRABBY DE LAVA\ncara %d: %s' % (i + 1, lab),
                     [oc, with_claws(shell, LAVA4, small[0], (-4, 2), face), with_claws(shell, LAVA4, small[1], (-4, 2), face)], 'ceniza'))
    rows.append(('CRABBY DE LAVA\npinzas B: grandes\n(la del Mega),\ncara 1',
                 [oc, with_claws(shell, LAVA4, mega[0], (-6, 2), LAVA_FACES[0][1]), with_claws(shell, LAVA4, mega[1], (-6, 2), LAVA_FACES[0][1])], 'ceniza'))
    rows.append(('CRABBY DE LAVA\npinzas C: como la A\ncon el filo al rojo,\ncara 1',
                 [oc, with_claws(shell, LAVA4, small[0], (-4, 2), LAVA_FACES[0][1], claw_pal=hot),
                  with_claws(shell, LAVA4, small[1], (-4, 2), LAVA_FACES[0][1], claw_pal=hot)], 'ceniza'))
    sheet('variantes_v4', 'CRABBIES, 4a ronda  -  el de siempre, y cada version con la pinza abierta y cerrada (sin boca)', rows, 'neutro', scale=8)


# ══ CRABBY DE CUEVA (propuestas). Del usuario: SIN pinzas sueltas como las del helado / lava / río — o ninguna, o
# dibujadas DENTRO del sprite, como las del Crabby lúgubre —; y lo de siempre: sin boca, simétrico, patas finas, no
# más alto que el Crabby. Familia del Gummy de cueva (lila + cristal), no del lúgubre (pálido y zancudo) ═══════════
CAVE_CRAB = P('efe6ff', 'c9b8e0', '8c78b4', e=NAVY, E=GLOW, g=GLOW, G=GLOW2, t='2ea8b8')
V5 = [
    ('A  Geoda\nsin pinzas: caparazon\nredondo con un racimo\nde cristales',
     ["........oo........", ".....o.oGGo.o.....", "....oGooGgooGo....", "...oohbbggbbsoo...", "...obebbbbbbeso...", "...oossssssssoo...",
      "...o..o....o..o...", "..o...o....o...o..", "..o..o......o..o.."]),
    ('B  Pinzas de cristal\nsus "pinzas" son dos\ncristales que lleva\nen alto (como los\nbrazos del lugubre)',
     ["..o............o..", ".oGo..........oGo.", ".ogo..oooooo..ogo.", "..oooohbbbbsoooo..", "....obebbbbeso....", "....oossssssoo....",
      "....o..o..o..o....", "...o...o..o...o...", "...o..o....o..o..."]),
    ('C  Cresta\nsin pinzas: ancho y\nchato, cresta de tres\ncristales y ojos\nque brillan',
     ["......o.oo.o......", ".....oGoGgoGo.....", "...ooogogtogooo...", "..ohbbbbbbbbbbso..", "..obEbbbbbbbbEso..", "...oossssssssoo...",
      "...o.o......o.o...", "..o..o......o..o..", "..o...o....o...o.."]),
    ('D  Pinzas pegadas\npinzas pequenas que\nson parte del cuerpo,\na los lados, y un\ncristal en el lomo',
     ["........oo........", ".......oGgo.......", ".oo..oooGgooo..oo.", "ob.oohbbbbbbsoo.bo", "obooobebbbbebooobo", ".oo.oossssssoo.oo.",
      ".....o.o..o.o.....", "....o..o..o..o....", "....o.o....o.o...."]),
]


def sheet_v5():
    white = P('ffffff', 'f2f2f6', 'c4c8d6')
    oc = crab(white)[0]
    gum = Image.open(os.path.join(ROOT, 'enemies', 'gummy_cave', 'gummy.png')).convert('RGBA')
    gl = Image.open(os.path.join(ROOT, 'enemies', 'gloomy', 'gloomy-Sheet.png')).convert('RGBA').crop((0, 0, 26, 15))
    rows = []
    for lab, m in V5:
        for r in m:
            assert len(r) == 18 and [c != '.' for c in r] == [c != '.' for c in reversed(r)], (lab, r)     # simétrico
        rows.append(('CRABBY DE CUEVA\n' + lab, [oc, maps(m, CAVE_CRAB), gum, gl], 'cueva'))
    sheet('crabby_cueva', 'CRABBY DE CUEVA  -  el Crabby de siempre · la propuesta · (para comparar) el Gummy de cueva y el Crabby lugubre',
          rows, 'cueva', scale=8, colw=30)


if __name__ == '__main__':
    for key, (title, bg, opts) in GUMMY_SETS.items():
        sheet(key, title + '  -  quieto, paso 1, paso 2   (arriba: el Gummy de siempre)',
              [('El de siempre', gummy(P('ffffff', 'f2f2f6', 'c4c8d6')))] + [(lab, gummy(pal, ed)) for lab, pal, ed in opts], bg)
    for key, (title, bg, opts) in CRAB_SETS.items():
        sheet(key, title + '  -  tres pasos   (arriba: el Crabby de siempre)',
              [('El de siempre', crab(P('ffffff', 'f2f2f6', 'c4c8d6')))] + [(o[0], crab(*o[1:])) for o in opts], bg)
    sheet('fortaleza', 'FORTALEZA  -  el Gummy y el Crabby de la isla (3 ideas)',
          [(lab, gummy(pal, ge)[:2] + crab(pal, ce)[:2]) for lab, pal, ge, ce in FORT], 'fortaleza')
    for design in HOP:
        tag = design.split()[0].lower()
        sheet('saltarin_' + tag, 'SALTARIN  ' + design + '  -  quieto, agachado (va a saltar), en el aire  -  una fila por isla',
              [(lab, hopper(design, pal, cap), isle) for isle, lab, pal, cap in ISLES], 'neutro', scale=7)
    # los tres diseños juntos, en la pradera
    isle, lab, pal, cap = ISLES[0]
    sheet('saltarin_los_tres', 'SALTARIN  -  los tres disenos, lado a lado (pradera)',
          [(d, hopper(d, pal, cap)) for d in HOP], 'pradera')
    sheet_v2()
    sheet_v3()
    sheet_v4()
    sheet_v5()
