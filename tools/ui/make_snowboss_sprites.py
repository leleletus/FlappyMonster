#!/usr/bin/env python3
# tools/ui/make_snowboss_sprites.py
# Arte del jefe GRAN BOLA DE NIEVE (assets/images/bosses/snowboss/) a partir del
# dibujo del usuario (assets/images/snowball/ball.png: 4x2 caras de 16x16 + la bola
# pequeña; el original se guarda FUERA del repo, tools/ui/originals.py, y se parte
# siempre de él). Misma forma (cada píxel), estilo nuevo como el resto de
# personajes: contorno azul muy oscuro, blanco con brillo arriba-izquierda y sombra
# azulada abajo-derecha.
#   body-Sheet.png     16x16 x12: contento (quieto, aplastado 1, aplastado 2, escupe),
#                      enfadado (igual), golpe contento, golpe enfadado, mareado 1, 2
#   roll_happy-Sheet.png / roll_angry-Sheet.png  16x16 x8: rodando (la cara gira de
#                      45 en 45 grados, rotación por píxel, sin difuminar)
#   cracks-Sheet.png   16x16 x3: grietas (fase 3 y muerte), de menos a más (base: el juego
#                      usa las adaptadas a cada cuadro de tools/ui/make_snowboss_cracks.py)
#   sweat-Sheet.png    5x7 x2: gota de sudor
#   ball.png           8x8: bola de nieve (proyectil)
#   bomb_ball-Sheet.png 10x12 x2: bola con mecha encendida (chispa en 2 cuadros)
#   flee-Sheet.png     12x12 x2: la bolita que huye (avergonzada), rodando
#   icicle.png         8x16: carámbano que cae
#   shock-Sheet.png    16x8 x2: ola de nieve por el suelo
#   splat-Sheet.png    64x36 x3: bola estampada en la pantalla (golpe, chorrea, cae)
#   ../../tiles/packed_snow.png  64x64: nieve prensada rompible (tile 37)
# Desde la raíz del repo:  python3 tools/ui/make_snowboss_sprites.py [carpeta_vista_previa]
import math, os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import originals   # noqa: E402

A = 'assets/images/'
OUTD = A + 'bosses/snowboss/'
PREVIEW = next((x for x in sys.argv[1:] if not x.startswith('--')), None)
SRC = A + 'snowball/ball.png'


def rgb(h, a=255): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


O = rgb('1e1e2a')     # contorno y rasgos
W = rgb('f2f4f8')     # nieve
H = rgb('ffffff')     # brillo
S = rgb('c4cce0')     # sombra azulada
S2 = rgb('a8b4d0')    # sombra más honda (borde de abajo)
I = rgb('e2e8f2')     # media sombra
CLEAR = (0, 0, 0, 0)


def src():
    o, _ = originals.keep(SRC)
    return Image.open(o if os.path.exists(o) else SRC).convert('RGBA')


def frame(im, fx, fy, w=16, h=16):
    return im.crop((fx * 16, fy * 16, fx * 16 + w, fy * 16 + h))


def kind(p):
    """'.' vacío, 'O' oscuro, 'W' blanco, 's' sombra (gris del original)."""
    if p[3] == 0: return '.'
    if p[0] < 60: return 'O'
    if p[0] > 245: return 'W'
    return 's'


def classify(im):
    w, h = im.size
    return [[kind(im.getpixel((x, y))) for x in range(w)] for y in range(h)]


def outside_mask(k):
    """Píxeles oscuros conectados con el exterior (contorno) frente a los de dentro
    (rasgos de la cara)."""
    h, w = len(k), len(k[0])
    out = [[False] * w for _ in range(h)]
    stack = [(x, y) for y in range(h) for x in range(w) if (x in (0, w - 1) or y in (0, h - 1)) and k[y][x] == '.']
    seen = set(stack)
    while stack:                                   # el aire de fuera
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and k[ny][nx] == '.':
                seen.add((nx, ny)); stack.append((nx, ny))
    for y in range(h):                             # oscuro tocando ese aire = contorno
        for x in range(w):
            if k[y][x] == 'O':
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or (nx, ny) in seen:
                        out[y][x] = True
    # el contorno puede tener 2 píxeles de grueso en las esquinas
    changed = True
    while changed:
        changed = False
        for y in range(h):
            for x in range(w):
                if k[y][x] == 'O' and not out[y][x]:
                    n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                            if 0 <= x + dx < w and 0 <= y + dy < h and out[y + dy][x + dx])
                    inner = any(0 <= x + dx < w and 0 <= y + dy < h and k[y + dy][x + dx] in 'Ws'
                                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                    if n >= 2 and not inner:
                        out[y][x] = True; changed = True
    return out


def restyle(im, face=None):
    """Estilo nuevo. `face`: capa de rasgos (lista de (x, y, color)) que se pinta en vez
    de los del original (cuerpo en blanco)."""
    k = classify(im)
    h, w = len(k), len(k[0])
    edge = outside_mask(k)
    body = [[k[y][x] in 'Ws' or (k[y][x] == 'O' and not edge[y][x]) for x in range(w)] for y in range(h)]
    ys = [y for y in range(h) if any(body[y])]
    out = Image.new('RGBA', (w, h), CLEAR)
    if not ys: return out
    top, bot = ys[0], ys[-1]
    for y in range(h):
        xs = [x for x in range(w) if body[y][x]]
        for x in range(w):
            if k[y][x] == '.': continue
            if k[y][x] == 'O' and edge[y][x]:
                out.putpixel((x, y), O); continue
            if not body[y][x]: continue
            x0, x1 = xs[0], xs[-1]
            c = W
            if k[y][x] == 's' or y == bot: c = S
            elif x == x1 or (y == bot - 1 and x > (x0 + x1) / 2): c = I
            if (y == top and x <= x0 + 1) or (y == top + 1 and x == x0) or (y == top + 1 and x == x0 + 1):
                c = H
            if face is None and k[y][x] == 'O':
                c = O
            if face is None and k[y][x] == 's' and 0 < y < h - 1 and (k[y - 1][x] == 'O' or k[y][x - 1] == 'O') \
               and y < bot - 1 and not (x == x1 or x == x1 - 1):
                c = rgb('8f9ab4')                      # gris de dentro de los ojos enfadados
            out.putpixel((x, y), c)
    if face:
        for x, y, c in face:
            if 0 <= x < w and 0 <= y < h and out.getpixel((x, y))[3]:
                out.putpixel((x, y), c)
    return out


def face_of(im):
    """Los rasgos (píxeles de dentro) del original: lista (x, y, color)."""
    k = classify(im)
    edge = outside_mask(k)
    out = []
    for y in range(len(k)):
        for x in range(len(k[0])):
            if k[y][x] == 'O' and not edge[y][x]:
                out.append((x, y, O))
    return out


def draw_face(spec):
    """Rasgos desde filas de texto (16 de ancho; 'O' = trazo)."""
    out = []
    for y, row in enumerate(spec):
        for x, ch in enumerate(row):
            if ch == 'O': out.append((x, y, O))
            elif ch == 'b': out.append((x, y, rgb('4fa0e8')))
            elif ch == 'p': out.append((x, y, rgb('f0a0b0')))
    return out


HURT = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "...O........O...",
    "....OO....OO....",
    "...O........O...",
    "................",
    "......OOOO......",
    ".....O....O.....",
]
DIZZY1 = [
    "................",
    "................",
    "................",
    "................",
    "..OOOOO.OOOOO...",
    "......O.O.......",
    "..OOO.O.O.OOO...",
    "..O...O.O...O...",
    "..OOOOO.OOOOO...",
    "................",
    ".......OO.......",
    "......O..O......",
    ".......OO.......",
]
DIZZY2 = [
    "................",
    "................",
    "................",
    "................",
    "..OOOOO.OOOOO...",
    "..O.....O.......",
    "..O.OOO.O.OOO...",
    "..O...O.O...O...",
    "..OOOOO.OOOOO...",
    "................",
    "......OOO.......",
    ".....O...O......",
    "......OOO.......",
]


def sheet(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h), CLEAR)
    for i, f in enumerate(frames): out.paste(f, (i * w, 0))
    return out


def rotated_face(face, ang, cx=8, cy=8):
    """Gira los rasgos `ang` grados alrededor del centro sin difuminar: se amplían x8,
    se giran con vecino más cercano y cada píxel de 16x16 queda pintado si su bloque
    de 8x8 está cubierto al menos un 40 %."""
    K = 8
    m = Image.new('L', (16, 16), 0)
    for x, y, _ in face: m.putpixel((x, y), 255)
    big = m.resize((16 * K, 16 * K), Image.NEAREST).rotate(ang, resample=Image.NEAREST, center=(cx * K, cy * K))
    out = []
    for y in range(16):
        for x in range(16):
            blk = big.crop((x * K, y * K, x * K + K, y * K + K))
            if sum(1 for v in blk.getdata() if v) >= 0.4 * K * K: out.append((x, y, O))
    return out


def cracks(n):
    im = Image.new('RGBA', (16, 16), CLEAR)
    lines = [
        [(9, 2), (9, 3), (8, 4), (8, 5), (9, 6)],
        [(3, 9), (4, 9), (5, 10), (5, 11), (6, 12)],
        [(12, 7), (13, 8), (12, 9), (12, 10), (13, 11), (11, 8)],
        [(6, 3), (5, 4), (5, 5), (4, 6)],
        [(10, 12), (10, 11), (11, 13)],
    ]
    use = lines[:[2, 4, 5][n]]
    for ln in use:
        for x, y in ln: im.putpixel((x, y), rgb('5a6a90'))
    return im


def sweat(i):
    rows = [".bb..", "bbbb.", "bWbb.", "bbbb.", ".bb..", ".....", "....."] if i == 0 else \
           [".....", ".bb..", "bbbb.", "bWbb.", "bbbb.", ".bb..", "....."]
    pal = {'b': rgb('6ab8f0'), 'W': rgb('ffffff')}
    im = Image.new('RGBA', (5, 7), CLEAR)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal: im.putpixel((x, y), pal[ch])
    return im


def small_ball(base):
    return restyle(base.crop((4, 4, 12, 12)))


def bomb_ball(base, i):
    im = Image.new('RGBA', (10, 12), CLEAR)
    im.paste(small_ball(base), (0, 4))
    for x, y in ((6, 3), (7, 2), (8, 1)): im.putpixel((x, y), rgb('8a6a40'))     # mecha
    spark = [((9, 0), rgb('fff07a')), ((8, 0), rgb('ffb040'))] if i == 0 else [((9, 1), rgb('ffb040')), ((9, 0), rgb('ffffff'))]
    for (x, y), c in spark: im.putpixel((x, y), c)
    return im


def flee(i):
    rows = [
        "............",
        "....OOOO....",
        "..OOWWWWOO..",
        ".OWWWWWWWWO.",
        ".OWWOWWOWWO.",
        "OWWWOWWOWWWO",
        "OWWWWWWWWWSO",
        "OWWWWOOWWWSO",
        ".OWWWWWWWSO.",
        ".OSWWWWWSSO.",
        "..OOSSSSOO..",
        "....OOOO....",
    ]
    if i == 1:
        rows = ["............"] + rows[:3] + rows[4:]           # rueda: un píxel aplastado
    pal = {'O': O, 'W': W, 'S': S}
    im = Image.new('RGBA', (12, 12), CLEAR)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal: im.putpixel((x, y), pal[ch])
    im.putpixel((10, 1), rgb('6ab8f0')); im.putpixel((10, 2), rgb('6ab8f0'))      # gota
    return im


def icicle():
    rows = [
        "OOOOOOOO",
        "OHWWWWSO",
        "OHWWWSSO",
        ".OHWWSO.",
        ".OHWWSO.",
        ".OHWWSO.",
        ".OHWSSO.",
        "..OHSO..",
        "..OHSO..",
        "..OHSO..",
        "..OWSO..",
        "...OO...",
        "...OO...",
        "...OO...",
        "........",
        "........",
    ]
    pal = {'O': rgb('3c6cb4'), 'H': rgb('ffffff'), 'W': rgb('c8e6ff'), 'S': rgb('8cc0ee')}
    im = Image.new('RGBA', (8, 16), CLEAR)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal: im.putpixel((x, y), pal[ch])
    return im


def shock(i):
    im = Image.new('RGBA', (16, 8), CLEAR)
    for x in range(16):
        hgt = int(3 + 4 * math.sin((x + i * 4) / 16 * math.pi) ** 2) if 2 <= x <= 13 else 0
        for y in range(8 - hgt, 8):
            c = W if y > 8 - hgt else H
            if x >= 11: c = S if y > 8 - hgt else W
            im.putpixel((x, y), c)
        if hgt: im.putpixel((x, 8 - hgt), O if hgt > 3 else S)
    return im


def splat(i):
    """Bola estampada en la pantalla: mancha con contorno, chorretones."""
    w, h = 64, 36
    im = Image.new('RGBA', (w, h), CLEAR)
    cx, cy = 32, 12 + i * 4
    blobs = [(cx, cy, 11), (cx - 12, cy - 3, 6), (cx + 13, cy + 1, 7), (cx - 6, cy + 9, 5), (cx + 7, cy - 9, 5),
             (cx - 20, cy + 4, 3), (cx + 22, cy - 6, 3)]
    drips = [(cx - 8, cy + 6, 6 + i * 6), (cx + 4, cy + 8, 4 + i * 7), (cx + 12, cy + 5, 3 + i * 5)]
    def inside(x, y):
        if any((x - bx) ** 2 + (y - by) ** 2 <= r * r for bx, by, r in blobs): return True
        return any(abs(x - dx) <= 2 and dy <= y <= dy + L for dx, dy, L in drips) or \
               any((x - dx) ** 2 + (y - dy - L) ** 2 <= 9 for dx, dy, L in drips)
    a = 255 if i < 2 else 170
    for y in range(h):
        for x in range(w):
            if inside(x, y):
                edge = not all(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if edge: c = rgb('8f9ab4', a)
                elif not inside(x + 1, y + 1) or not inside(x, y + 2): c = rgb('c4cce0', a)
                else: c = rgb('f6f8fc', a)
                im.putpixel((x, y), c)
    for x, y in ((cx - 4, cy - 5), (cx - 3, cy - 5), (cx - 5, cy - 4)):
        if 0 <= y < h: im.putpixel((x, y), rgb('ffffff', a))
    return im


def packed_snow():
    """Nieve prensada rompible: la textura de nieve con juntas de bloques y grietas."""
    base = Image.open(A + 'tiles/snow.png').convert('RGBA').resize((16, 16), Image.NEAREST)
    im = base.copy()
    line = rgb('9aacd0'); dark = rgb('7088b8'); hi = rgb('ffffff')
    for x in range(16):
        im.putpixel((x, 7), line)
        im.putpixel((x, 15), dark)
    for y in range(16):
        im.putpixel((0, y), hi if y < 7 else line)
        im.putpixel((15, y), dark)
    for y in range(0, 7): im.putpixel((8, y), line)
    for y in range(8, 15): im.putpixel((4, y), line); im.putpixel((12, y), line)
    for x, y in ((10, 2), (11, 3), (11, 4), (6, 10), (7, 11), (14, 12)):
        im.putpixel((x, y), dark)
    return im.resize((64, 64), Image.NEAREST)


def build():
    base = src()
    fr = {n: frame(base, i % 4, i // 4) for i, n in enumerate(
        ['h_idle', 'h_sq1', 'h_sq2', 'h_shoot', 'a_idle', 'a_sq1', 'a_sq2', 'a_shoot'])}
    body = [restyle(fr[n]) for n in ['h_idle', 'h_sq1', 'h_sq2', 'h_shoot', 'a_idle', 'a_sq1', 'a_sq2', 'a_shoot']]
    body += [restyle(fr['h_sq1'], draw_face(HURT)), restyle(fr['a_sq1'], draw_face(HURT)),
             restyle(fr['h_idle'], draw_face(DIZZY1)), restyle(fr['h_idle'], draw_face(DIZZY2))]
    out = {
        'body-Sheet.png': sheet(body),
        'roll_happy-Sheet.png': sheet([restyle(fr['h_idle'], rotated_face(face_of(fr['h_idle']), k * 45)) for k in range(8)]),
        'roll_angry-Sheet.png': sheet([restyle(fr['a_idle'], rotated_face(face_of(fr['a_idle']), k * 45)) for k in range(8)]),
        'cracks-Sheet.png': sheet([cracks(i) for i in range(3)]),
        'sweat-Sheet.png': sheet([sweat(i) for i in range(2)]),
        'ball.png': small_ball(frame(base, 0, 2)),
        'bomb_ball-Sheet.png': sheet([bomb_ball(frame(base, 0, 2), i) for i in range(2)]),
        'flee-Sheet.png': sheet([flee(i) for i in range(2)]),
        'icicle.png': icicle(),
        'shock-Sheet.png': sheet([shock(i) for i in range(2)]),
        'splat-Sheet.png': sheet([splat(i) for i in range(3)]),
    }
    return out


if __name__ == '__main__':
    out = build()
    os.makedirs(OUTD, exist_ok=True)
    for name, im in out.items():
        im.save(OUTD + name)
        print('  %-44s %dx%d' % (OUTD + name, im.width, im.height))
    ps = packed_snow()
    ps.save(A + 'tiles/packed_snow.png'); print('  ' + A + 'tiles/packed_snow.png')
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        rows = [(n, im) for n, im in out.items()] + [('packed_snow', ps.resize((16, 16), Image.NEAREST))]
        k = 6
        W_ = max(im.width for _, im in rows) * k + 20
        H_ = sum(im.height * k + 10 for _, im in rows) + 10
        canvas = Image.new('RGBA', (W_, H_), rgb('6f9fd8'))
        y = 10
        for _, im in rows:
            canvas.alpha_composite(im.resize((im.width * k, im.height * k), Image.NEAREST), (10, y))
            y += im.height * k + 10
        canvas.save(os.path.join(PREVIEW, 'sprites.png'))
        print('  vista previa: ' + os.path.join(PREVIEW, 'sprites.png'))
