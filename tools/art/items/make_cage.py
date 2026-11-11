#!/usr/bin/env python3
# tools/art/items/make_cage.py — el FLAPPY ENJAULADO rehecho (0.5.196; el usuario: «la jaula más grande, y el flappy de
# dentro distinto cada vez y mucho más parecido a los flappies del juego»). Pixel art en mapas de caracteres, sin PIL
# (escribe los PNG a mano). Se dibuja ×4 (GUMMY_SCALE). Nada de alas (golden rule 6: vuelan por magia).
#   assets/images/items/cage/cage-Sheet.png     23x24 ×2: la jaula CERRADA (barrotes por delante, candado) · ABIERTA
#                                               (la puerta del medio abierta hacia la derecha, sin candado)
#   assets/images/items/cage/flappies-Sheet.png 9x16, una FILA por variante (VARIANTS, abajo) y 2 columnas: brazos
#                                               abajo (triste, encerrado) · brazos arriba (pide ayuda / sale volando).
#                                               El cuerpo es el del monstruo (assets/images/player/monstrito1 / 3: cabeza
#                                               de caja con contorno, palitos, antenas): cambian colores y detalles.
#   assets/images/items/cage/lamp.png           2x2: una luz de carga (la jaula pide tantas como su `minCharge`)
# src/world/entities/types/items/cage.lua dibuja el flappy DENTRO (entre la pared del fondo y los barrotes) con el
# cuadro de la jaula encima. El flappy de cada jaula sale de su casilla (Cage.variantAt): igual en cada partida y en
# cada cliente.
# Sin flags: solo la vista previa (FlappyMonster_pruebas/jaulas/vista_previa.png si existe /home/mtvemo, si no la
# carpeta que diga --preview). --apply escribe los tres PNG (no están retocados a mano: se puede volver a generar).
#   python3 tools/art/items/make_cage.py [--apply] [--preview DIR]
import os, sys, struct, zlib

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'items', 'cage')

# ── La jaula ──────────────────────────────────────────────────────────────────
# Hierro de las máquinas del Monstruo Malvado (contorno = su tono más oscuro) y candado dorado
CAGE_PAL = {
    '.': (0, 0, 0, 0),
    'o': (40, 40, 58, 255),        # contorno del hierro
    'd': (88, 88, 108, 255),       # sombra
    'g': (146, 146, 166, 255),     # hierro
    'G': (208, 208, 224, 255),     # brillo
    'Y': (255, 214, 96, 255),      # candado
    'y': (204, 150, 48, 255),      # su sombra
    'u': (104, 64, 22, 255),       # su contorno
    'k': (40, 40, 58, 255),        # (el ojo de la cerradura: el contorno)
}
CW, CH = 23, 24                    # el cuadro; la jaula ocupa las columnas 3..19 (centro: la 11)
FX, FY = 7, 4                      # dónde va el flappy (9x16) dentro del cuadro: pies sobre la base (fila 20)

def blank(w, h): return [['.'] * w for _ in range(h)]

def cage(open_):
    g = blank(CW, CH)
    def put(x, y, c):
        if 0 <= x < CW and 0 <= y < CH: g[y][x] = c
    # anilla de colgar (filas 1-2)
    for x in (10, 11, 12): put(x, 1, 'o')
    put(10, 2, 'o'); put(12, 2, 'o')
    # cúpula: un arco (hueco por dentro: las antenas del flappy se ven a través) que baja hasta los barrotes de fuera.
    # El arco y los barrotes de fuera van en la sombra del hierro ('d'), no en el contorno: colgada de un pilar oscuro
    # la jaula se seguiría viendo (in-game, valle_pilares_3)
    for x in range(8, 15): put(x, 3, 'o')
    for x in range(9, 14): put(x, 3, 'G' if x < 12 else 'g')
    put(6, 4, 'd'); put(7, 4, 'd'); put(15, 4, 'd'); put(16, 4, 'd')
    put(5, 5, 'd'); put(17, 5, 'd')
    put(4, 6, 'd'); put(18, 6, 'd')
    put(8, 4, 'G'); put(14, 4, 'g')
    # barrotes: los de fuera (3, 19); los de la PUERTA (7, 15) suben hasta el arco
    for y in range(7, 20):
        put(3, y, 'g' if y < 12 else 'd'); put(19, y, 'd')
    if not open_:
        for y in range(5, 20):
            put(7, y, 'G' if y < 12 else 'g'); put(15, y, 'g' if y < 12 else 'd')
        put(7, 4, 'g'); put(15, 4, 'd')
        # el travesaño de la puerta (a la altura de las caderas del flappy) y el CANDADO en el cierre, en el barrote de
        # la derecha (así no tapa al flappy)
        for x in range(8, 15): put(x, 16, 'g')
        lock = ['.u.',
                'u.u',
                'YYY',
                'yky']
        for j, r in enumerate(lock):
            for i, c in enumerate(r):
                if c != '.': put(14 + i, 11 + j, c)
    else:
        # la puerta abierta: girada hacia fuera, de canto, a la derecha (su marco y sus dos barrotes juntos)
        for y in range(8, 20):
            put(20, y, 'o'); put(21, y, 'g' if y < 14 else 'd'); put(22, y, 'o')
        put(21, 7, 'o'); put(21, 20, '.')
        put(21, 13, 'G')
    # base (fila 20: el borde de arriba, 21-22 la placa con las luces de carga, 23 el canto de abajo)
    for x in range(2, 21): put(x, 20, 'o')
    for x in range(3, 20): put(x, 20, 'G' if x < 12 else 'g')
    for y in (21, 22):
        put(2, y, 'o'); put(20, y, 'o')
        for x in range(3, 20): put(x, y, 'd' if y == 22 else 'g')
    for x in range(3, 20): put(x, 23, 'o')
    put(3, 21, 'G'); put(19, 21, 'G')                          # remaches (fuera de donde van las luces)
    return [''.join(r) for r in g]

# ── Los flappies ─────────────────────────────────────────────────────────────
# El cuerpo del monstruo (monstrito1 = brazos arriba, monstrito3 = brazos abajo), filas 8..15. 'O' = el contorno (el
# color oscuro de la variante: cuerpo, contorno de la cabeza, antenas), 'E' = su brillo en el pecho.
BODY_UP = ['O...O...O', '.O.EOO.O.', '..OOOOO..', '...OOO...', '....O....', '...O.O...', '...O.O...', '..OO.OO..']
BODY_DOWN = ['....O....', '...EOO...', '..OOOOO..', '.O.OOO.O.', 'O...O...O', '...O.O...', '...O.O...', '..OO.OO..']

# Cabezas (filas 2..7 / 3..7). 'B' brillo, 'C' color, 'D' sombra; 'e' = donde van los ojos (los pone EYES)
HEADS = {
    'box':   {3: '..OOOOO..', 4: '.OBBCCDO.', 5: '.OCCCCDO.', 6: '.OCCDDDO.', 7: '..OOOOO..'},
    'round': {2: '...OOO...', 3: '..OBBCO..', 4: '.OBBCCCO.', 5: '.OCCCCDO.', 6: '.OCCDDDO.', 7: '..OOOOO..'},
    'wide':  {3: '.OOOOOOO.', 4: 'OBBCCCCDO', 5: 'OCCCCCCDO', 6: 'OCCCDDDDO', 7: '.OOOOOOO.'},
}
# Ojos: lista de (col, fila) en 'k' (y 'r' = mofletes). La fila 5 es la de los ojos del monstruo.
EYES = {
    'dots':   [(3, 5), (5, 5)],
    'left':   [(2, 5), (4, 5)],                 # los del monstruo (mira a un lado)
    'wide':   [(2, 5), (6, 5)],
    'sleepy': [(2, 5), (3, 5), (5, 5), (6, 5)],
    'tall':   [(3, 4), (3, 5), (5, 4), (5, 5)],
}
# Antenas / cuernos / pelo (filas 0..2; con la cabeza 'round', solo 0..1). 'h' = cuerno, 'Q' = bombilla
TOPS = {
    'v':      {0: '..O...O..', 1: '...O.O...', 2: '...O.O...'},
    'horns':  {0: '.h.....h.', 1: '.hh...hh.', 2: '..hO.Oh..'},
    'bulb':   {0: '....Q....', 1: '....O....', 2: '....O....'},
    'tuft':   {0: '...O.O...', 1: '..O.O.O..', 2: '...OOO...'},
    'bunny':  {0: '..O...O..', 1: '..O...O..', 2: '..OO.OO..'},
    'curl':   {0: '...OO....', 1: '.....O...', 2: '....O....'},
    'tri':    {0: '..O.O.O..', 1: '..O.O.O..', 2: '...OOO...'},
    'long':   {0: '.O.....O.', 1: '..O...O..', 2: '...O.O...'},
    'short':  {1: '...O.O...'},
}

def rgb(h): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)

# Las variantes (el orden es su número: no se reordenan, solo se añaden al final — lo usa Cage.variantAt)
VARIANTS = [
    # nombre,  cabeza,  ojos,     arriba,  mofletes, colores: B brillo, C color, D sombra, O contorno, E pecho, extra
    ('rosa',   'box',   'dots',   'v',     True,  dict(B='ffd2e4', C='f59ac0', D='d46a98', O='4a1634', E='7a3460')),
    ('menta',  'box',   'left',   'horns', False, dict(B='d0fadc', C='8edcaa', D='5aaa7c', O='143e2c', E='2e6a50', h='fff0c8')),
    ('limon',  'round', 'dots',   'bulb',  False, dict(B='fff6b8', C='fadc64', D='d2aa3c', O='4e340e', E='7e5a24', Q='ff8a3c')),
    ('lila',   'wide',  'sleepy', 'bunny', True,  dict(B='e4d8ff', C='b496eb', D='8668c3', O='2c1c54', E='4c3a82')),
    ('cielo',  'box',   'wide',   'tuft',  False, dict(B='cceeff', C='82c3fa', D='5591d7', O='14285a', E='2c4a8a')),
    ('melocoton', 'round', 'tall', 'curl', True,  dict(B='ffdcb4', C='faa56e', D='d77346', O='542210', E='86422a')),
    ('agua',   'wide',  'dots',   'tri',   False, dict(B='c0faf4', C='6ed7d7', D='3ca5aa', O='0e3840', E='24606a')),
    ('crema',  'box',   'tall',   'long',  True,  dict(B='fffcf0', C='ece4d2', D='c4b8a0', O='3c2c22', E='6a5444')),
]

def flappy(v, pose):
    name, head, eyes, top, blush, cols = v
    g = blank(9, 16)
    def put(x, y, c): g[y][x] = c
    rows = HEADS[head]
    t = TOPS[top]
    hi = min(rows)                              # fila de arriba de la cabeza
    for dy, r in t.items():
        y = dy - (3 - hi)                       # (cabeza redonda: las antenas suben una fila y pierden la de arriba)
        if 0 <= y < hi:
            for x, c in enumerate(r):
                if c != '.': put(x, y, c)
    for y, r in rows.items():
        for x, c in enumerate(r):
            if c != '.': put(x, y, c)
    for (x, y) in EYES[eyes]: put(x, y, 'k')
    if blush:
        put(2 if head != 'wide' else 1, 6, 'r'); put(6 if head != 'wide' else 7, 6, 'r')
    body = BODY_UP if pose == 'up' else BODY_DOWN
    for j, r in enumerate(body):
        for x, c in enumerate(r):
            if c != '.': put(x, 8 + j, c)
    pal = {'.': (0, 0, 0, 0), 'k': rgb(cols['O']), 'r': rgb('ff7a9a')}
    for k in ('B', 'C', 'D', 'O', 'E', 'h', 'Q'):
        if k in cols: pal[k] = rgb(cols[k])
    if 'h' in cols: pal['h'] = rgb(cols['h'])
    return [[pal[c] for c in r] for r in g]

LAMP = [[rgb('dcf6ff'), rgb('6ed2ff')], [rgb('6ed2ff'), rgb('3c8cd2')]]

# ── PNG a mano ──────────────────────────────────────────────────────────────
def to_px(rows, pal): return [[pal[c] for c in r] for r in rows]

def write_png(px, path):
    h, w = len(px), len(px[0])
    raw = b''.join(b'\x00' + b''.join(bytes(c) for c in r) for r in px)
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f: f.write(png)
    print('escrito', os.path.relpath(path, ROOT), '%dx%d' % (w, h))

def read_png(path):
    # (solo lo justo para la vista previa: RGBA/RGB/paleta de 8 bits sin entrelazar)
    d = open(path, 'rb').read(); p = 8; idat = b''; plte = trns = None
    while p < len(d):
        n, = struct.unpack('>I', d[p:p + 4]); t = d[p + 4:p + 8]; c = d[p + 8:p + 8 + n]; p += 12 + n
        if t == b'IHDR': w, h, bd, ct = struct.unpack('>IIBB', c[:10])
        elif t == b'PLTE': plte = [tuple(c[i:i + 3]) for i in range(0, len(c), 3)]
        elif t == b'tRNS': trns = c
        elif t == b'IDAT': idat += c
    ch = {6: 4, 2: 3, 3: 1}[ct]; raw = zlib.decompress(idat); st = w * ch; prev = bytearray(st); i = 0; out = []
    for y in range(h):
        f = raw[i]; line = bytearray(raw[i + 1:i + 1 + st]); i += 1 + st
        for x in range(st):
            a = line[x - ch] if x >= ch else 0; b = prev[x]; cc = prev[x - ch] if x >= ch else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pp = a + b - cc; pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - cc)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else cc)) & 255
        prev = line; r = []
        for x in range(w):
            v = line[x * ch:(x + 1) * ch]
            if ct == 6: r.append(tuple(v))
            elif ct == 2: r.append(tuple(v) + (255,))
            else: r.append(plte[v[0]] + ((trns[v[0]] if trns and v[0] < len(trns) else 255),))
        out.append(r)
    return out

def hstack(*ims):
    h = max(len(i) for i in ims)
    return [sum((i[y] if y < len(i) else [(0, 0, 0, 0)] * len(i[0]) for i in ims), []) for y in range(h)]

def sheets():
    closed, open_ = to_px(cage(False), CAGE_PAL), to_px(cage(True), CAGE_PAL)
    fl = []
    for v in VARIANTS:
        fl += [a + b for a, b in zip(flappy(v, 'down'), flappy(v, 'up'))]
    return hstack(closed, open_), fl

# ── Vista previa ─────────────────────────────────────────────────────────────
def preview(dirpath):
    W, H = 1400, 980
    bg_top, bg_bot = (150, 206, 236), (214, 238, 246)
    img = [[tuple(int(bg_top[k] + (bg_bot[k] - bg_top[k]) * y / H) for k in range(3)) + (255,) for _ in range(W)]
           for y in range(H)]
    def blit(px, x0, y0, s, sub=None):
        sx, sy, sw, sh = sub or (0, 0, len(px[0]), len(px))
        for y in range(sh):
            for x in range(sw):
                c = px[sy + y][sx + x]
                if c[3] == 0: continue
                for j in range(s):
                    row = img[y0 + y * s + j]
                    for i in range(s): row[x0 + x * s + i] = c
    def rect(x0, y0, w, h, c):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w): img[y][x] = c
    cage_sheet, fl_sheet = sheets()
    def draw_cage(x0, y0, s, vi, open_=False, pose=0):
        # (como en el juego: el flappy dentro y la jaula por encima)
        if not open_: blit(fl_sheet, x0 + FX * s, y0 + FY * s, s, (pose * 9, vi * 16, 9, 16))
        blit(cage_sheet, x0, y0, s, (CW if open_ else 0, 0, CW, CH))
    # fila 1: a escala de juego (×4) la jaula vieja, el monstruo (×6) y las 8 nuevas
    old = os.path.join(ROOT, 'assets', 'images', 'items', 'cage-Sheet.png')
    x = 20
    if os.path.exists(old):
        blit(read_png(old), x, 40, 4, (0, 0, 16, 16)); x += 90
    mon = read_png(os.path.join(ROOT, 'assets', 'images', 'player', 'monstrito1.png'))
    blit(mon, x, 10, 6); x += 80
    for vi in range(len(VARIANTS)):
        draw_cage(x, 10, 4, vi); x += 100
    # fila 2: ×4 abiertas con el flappy que sale (brazos arriba) y las luces de carga 1..5
    x = 20
    for vi in range(len(VARIANTS)):
        draw_cage(x, 150, 4, vi, open_=True)
        n = vi % 5 + 1
        lamp = LAMP
        for i in range(n):
            lx = x + 46 - n * 6 + i * 12 + 2
            blit(lamp, lx, 150 + 21 * 4, 4)
        x += 100
    # fila 3: los flappies sueltos ×6 (como el monstruo), brazos abajo y arriba
    x = 20
    for vi in range(len(VARIANTS)):
        blit(fl_sheet, x, 300, 6, (0, vi * 16, 9, 16)); blit(fl_sheet, x + 62, 300, 6, (9, vi * 16, 9, 16))
        x += 140
    blit(mon, x, 300, 6)
    # fila 4: dos jaulas a ×8 para ver el detalle
    draw_cage(20, 440, 8, 0); draw_cage(220, 440, 8, 3, pose=1); draw_cage(420, 440, 8, 5, open_=True)
    draw_cage(620, 440, 8, 1); draw_cage(820, 440, 8, 2, pose=1); draw_cage(1020, 440, 8, 6)
    os.makedirs(dirpath, exist_ok=True)
    path = os.path.join(dirpath, 'vista_previa.png')
    write_png(img, path)

if __name__ == '__main__':
    args = sys.argv[1:]
    pdir = '/home/mtvemo/FlappyMonster_pruebas/jaulas'
    if '--preview' in args: pdir = args[args.index('--preview') + 1]
    preview(pdir)
    if '--apply' in args:
        cs, fs = sheets()
        write_png(cs, os.path.join(OUT, 'cage-Sheet.png'))
        write_png(fs, os.path.join(OUT, 'flappies-Sheet.png'))
        write_png(LAMP, os.path.join(OUT, 'lamp.png'))
