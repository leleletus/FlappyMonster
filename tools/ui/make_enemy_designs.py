#!/usr/bin/env python3
# PROPUESTAS de diseño (no son todavía sprites del juego: el usuario elige y entonces se aplican):
#   · Gummy de CUEVA y de MAGMA, Crabby de RÍO (pradera) y de LAVA, y los de la FORTALEZA: 3 opciones cada uno — el
#     MISMO dibujo de siempre (cada píxel del Gummy / del Crabby) con otra paleta y, como mucho, un detalle de 1-3 px.
#   · el SALTARÍN (enemigo nuevo: salta en arco hacia el jugador): 3 diseños x 3 cuadros (quieto, agachado, en el
#     aire) x 6 islas (misma forma; cambia la paleta, las motas y lo que lleva en la cabeza).
# Estilo del juego: contorno azul marino muy oscuro (1e1e2a, nunca negro), luz arriba-izquierda, sombra abajo-derecha,
# caras de dos rayitas y una boca.
#   python3 tools/ui/make_enemy_designs.py  →  /home/mtvemo/FlappyMonster_pruebas/enemigos/*.png
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'images')
OUT = '/home/mtvemo/FlappyMonster_pruebas/enemigos'
NAVY = '1e1e2a'
BG = {'pradera': '8cc8f0', 'costa': '9cdcf0', 'fortaleza': '8a8ea8', 'nieve': 'b8d4f0', 'cueva': '3a3450', 'volcan': '6a2c2c',
      'neutro': '6e9a6e'}


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
G = [base('gummy/gummy.png'), base('gummy/gummy1.png'), base('gummy/gummy2.png')]
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
C = [base('crabby/crab1.png'), base('crabby/crab2.png'), base('crabby/crab3.png')]
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
