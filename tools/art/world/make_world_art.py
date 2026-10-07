#!/usr/bin/env python3
# tools/art/world/make_world_art.py
# Arte de bloques y objetos del mundo (pixel art sencillo, x4 en el juego):
#   tiles/stone.png        Piedra: grietas en relieve que CONTINÚAN de un bloque al de al lado
#                          (dibujo de 2x2 casillas que se repite sin costura: la textura
#                          lleva `span = 2` y cada casilla usa su cuarto)
#   tiles/deep_stone.png   Roca abisal (roja oscura, fondos marinos hondos), igual
#   tiles/border.png       Borde: roca durísima y compacta (piezas pequeñas biseladas)
#   tiles/lava.png         Lava: 4 cuadros de 16x16 (interior) que fluyen
#   tiles/lava_top.png     Lava con la cara de arriba al aire: 4 cuadros (cresta brillante)
#   tiles/platform.png     Plataforma NO traspasable: viga de acero remachada (¾ de alto)
#   tiles/sand_blend.png   transiciones de la arena (tierra, piedra, roca abisal, borde)
#   fx/lava_fx.png         partículas de la lava: burbuja, burbuja grande, estallido, gota
#   mortar/normal.png, shooting.png   Mortero
#   items/checkpoint_off.png, checkpoint_on.png   Punto de control
# Las imágenes que ya existían se guardan antes FUERA del repo (tools/art/lib/originals.py).
# No pisa lo ya generado salvo con --force. Desde la raíz del repo:
#     python3 tools/art/world/make_world_art.py [--force] [nombre ...]
import os, sys, math, random
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib'))   # (originals.py)
import originals   # noqa: E402

FORCE = '--force' in sys.argv
ONLY = {a for a in sys.argv[1:] if not a.startswith('--')}
IMG = 'assets/images'


def rgb(h, a=255): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def grid(rows, pal):
    w = len(rows[0])
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        assert len(r) == w, (r, w)
        for x, ch in enumerate(r):
            if pal.get(ch): im.putpixel((x, y), pal[ch])
    return im


def strip(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames): out.paste(f, (i * w, 0))
    return out


DONE = set()


def save(rel, img, scale=4, name=None):
    """Guarda assets/images/<rel>. La primera vez que se pisa una imagen que no es
    de este script, su original se guarda fuera del repo."""
    name = name or os.path.basename(rel)[:-4]
    if ONLY and name not in ONLY: return
    path = os.path.join(IMG, rel)
    mark = os.path.join(originals.ROOT, '.world_art', rel)          # (ya es nuestra)
    if os.path.exists(path) and not os.path.exists(mark):
        originals.keep(path)
    elif os.path.exists(path) and not FORCE:
        print('  ' + path + ' ya existe: no se toca (--force)')
        return
    if scale != 1: img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    os.makedirs(os.path.dirname(mark), exist_ok=True)
    open(mark, 'w').close()
    print('  %-44s %dx%d' % (path, img.width, img.height))


# ── Roca con grietas que se repite sin costura (Voronoi en un toro) ────────────
def rock(size, seeds, pal, seed, bevel=False, bevel_dark=False, specks=0):
    rnd = random.Random(seed)
    pts = [(rnd.uniform(0, size), rnd.uniform(0, size)) for _ in range(seeds)]
    tone = [rnd.choice(('base', 'base', 'alt')) for _ in pts]

    def owner(x, y):
        x %= size; y %= size
        best, bi = 1e9, 0
        for i, (px, py) in enumerate(pts):
            dx = min(abs(x + 0.5 - px), size - abs(x + 0.5 - px))
            dy = min(abs(y + 0.5 - py), size - abs(y + 0.5 - py))
            d = dx * dx + dy * dy
            if d < best: best, bi = d, i
        return bi
    own = [[owner(x, y) for x in range(size)] for y in range(size)]
    O = lambda x, y: own[y % size][x % size]
    im = Image.new('RGBA', (size, size))
    for y in range(size):
        for x in range(size):
            o = O(x, y)
            crack = O(x + 1, y) != o or O(x, y + 1) != o
            if crack:
                c = pal['crack']
            elif bevel and (O(x, y - 1) != o or O(x - 1, y) != o):
                c = pal['light']                       # bisel: arriba-izquierda de cada pieza
            elif bevel_dark and (O(x, y + 2) != o or O(x + 2, y) != o):
                c = pal['shade']                       # y sombra abajo-derecha
            else:
                c = pal[tone[o]]
            im.putpixel((x, y), c)
    for _ in range(specks):
        x, y = rnd.randrange(size), rnd.randrange(size)
        if im.getpixel((x, y)) in (pal['base'], pal['alt']): im.putpixel((x, y), pal['speck'])
    return im


STONE = dict(base=rgb('4a4a56'), alt=rgb('47474f'), light=rgb('5c5c6a'), crack=rgb('393942'),
             shade=rgb('3e3e48'), speck=rgb('56566a'))
DEEP = dict(base=rgb('5a2a33'), alt=rgb('52262f'), light=rgb('713a42'), crack=rgb('3a1820'),
            shade=rgb('4a2029'), speck=rgb('6a3540'))
BORDER = dict(base=rgb('2e2d36'), alt=rgb('2e2d36'), light=rgb('4a4958'), crack=rgb('1a1a20'),
              shade=rgb('222129'), speck=rgb('46455a'))


# ── Roca sencilla (lo que se usa) ──────────────────────────────────────────────
# Dibujo de 32x32 = 2x2 casillas: color plano + unas pocas grietas cortas ('c' oscuro)
# y motas ('l' claro / 'd' oscuro), siempre lejos de los bordes de cada casilla.
STONE_MARKS = [
    "................................",
    "................................",
    "..........l.....................",
    ".....cc.................l.......",
    "......cc..........cc............",
    ".......c...........cc...........",
    "....................c...........",
    "................................",
    "................................",
    "..d...........d.................",
    "..........................l.....",
    "........l...............ccc.....",
    "..........................cc....",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    ".....l...................d......",
    "...........cc...................",
    "............ccc.................",
    "..............c.........l.......",
    "................................",
    "...d............................",
    "........................cc......",
    ".................l.......c......",
    "........c................cc.....",
    ".......cc.......................",
    "........................d.......",
    "............d...................",
    "................................",
    "................................",
]
DEEP_MARKS = STONE_MARKS[16:] + STONE_MARKS[:16]
BORDER_MARKS = [
    "................................",
    "................................",
    "....ll.........dd.......ll......",
    "....ld.........dd.......ld......",
    "................................",
    "..........cccc..................",
    "........................cccc....",
    "..dd............ll..............",
    "..dd............ld..............",
    "..........ll...............dd...",
    "..........ld...............dd...",
    "................................",
    "....cccc..............cccc......",
    "................................",
    ".....................ll.........",
    "...ll................ld.........",
    "...ld...........................",
    "...............cccc.............",
    "..........dd.................ll.",
    "..........dd.................ld.",
    "..ll............................",
    "..ld..............ll...cccc.....",
    "..................ld............",
    "......cccc......................",
    "................................",
    ".........................dd.....",
    "...ll.........ll.........dd.....",
    "...ld.........ld................",
    "......................cccc......",
    "...........dd...................",
    "...........dd...................",
    "................................",
]


def simple_rock(pal, marks):
    m = {'.': pal['base'], 'c': pal['crack'], 'l': pal['light'], 'd': pal['shade']}
    im = Image.new('RGBA', (32, 32))
    for y, row in enumerate(marks):
        for x, ch in enumerate(row): im.putpixel((x, y), m[ch])
    return im


# ── Lava ──────────────────────────────────────────────────────────────────────
LAVA = [rgb('8c1c12'), rgb('c83c18'), rgb('f07822'), rgb('ffc848'), rgb('fff0a0')]


# Dibujo a mano (16x16, se repite): r = rojo oscuro, R = rojo, o = naranja, y = amarillo.
# Los cuadros lo desplazan 4 px cada uno → fluye (y sigue repitiéndose sin costura).
LAVA_ROWS = [
    "oooRRRoooooooRRo",
    "ooRRrRRoooyyooRR",
    "oRRrrrRoooyyyoRR",
    "oRRrrRRooooyoooR",
    "ooRRRRooooooooRR",
    "ooooooooRRRooooo",
    "yooooooRRrRRoooo",
    "yyoooooRrrrRoooy",
    "yooooooRRrRRooyy",
    "oooRRooooRRooooy",
    "ooRRRRooooooooRo",
    "ooRrrRRoooyoooRR",
    "oooRrrRooyyyoooR",
    "oooRRRRoooyoooRR",
    "ooooRRooooooooRR",
    "RRoooooooooooooR",
]
LAVA_PAL = {'r': LAVA[0], 'R': LAVA[1], 'o': LAVA[2], 'y': LAVA[3]}


def lava_frame(f, top):
    im = Image.new('RGBA', (16, 16))
    for y in range(16):
        for x in range(16):
            im.putpixel((x, y), LAVA_PAL[LAVA_ROWS[y][(x + f * 4) % 16]])
    if top:
        ph = 2 * math.pi * f / 4
        for x in range(16):
            h = 1 + round(math.sin(2 * math.pi * (x / 16 * 2) + ph))          # 0..2
            for y in range(0, h + 1):
                im.putpixel((x, y), LAVA[4] if y == h else LAVA[3])
            im.putpixel((x, h + 1), LAVA[3])
    return im


def lava_fx():
    Y, O, R = LAVA[4], LAVA[2], LAVA[1]
    return strip([
        grid([".....", ".....", "..O..", ".OYO.", "....."], {'O': O, 'Y': Y}),
        grid([".....", ".OOO.", "OYYYO", "OYYYO", ".OOO."], {'O': O, 'Y': Y}),
        grid(["O...O", ".R.R.", ".....", ".R.R.", "O...O"], {'O': O, 'R': R}),
        grid([".....", "..Y..", ".YOY.", "..O..", "....."], {'O': O, 'Y': Y}),
    ])


# ── Plataforma no traspasable: viga de acero ──────────────────────────────────
def platform():
    """Viga de acero sencilla: filo claro, cuerpo plano, filo oscuro y unos pocos remaches."""
    pal = {'O': rgb('22252e'), 'L': rgb('aab2c4'), 'M': rgb('7c849a'), 'D': rgb('545b70'), 'r': rgb('c8cede')}
    return grid([
        "OOOOOOOOOOOOOOOO",
        "LLLLLLLLLLLLLLLL",
        "MMMMMMMMMMMMMMMM",
        "MMrMMMMMMMMMrMMM",
        "MMMMMMMMMMMMMMMM",
        "MMMMMMMMMMMMMMMM",
        "MMMMMMMMMMMMMMMM",
        "MMMMMMMMMMMMMMMM",
        "MMrMMMMMMMMMrMMM",
        "DDDDDDDDDDDDDDDD",
        "DDDDDDDDDDDDDDDD",
        "OOOOOOOOOOOOOOOO",
        "................", "................", "................", "................",
    ], pal)


# ── Mortero ───────────────────────────────────────────────────────────────────
MORTAR = [
    "................",
    "................",
    "....OOOOOOOO....",
    "...OkkkkkkkkO...",
    "...OMMMMMMMMO...",
    "....OMMMMMMO....",
    "...OLMMMMMMMO...",
    "..OLMMMMMMMMMO..",
    "..OLMMMMMMMMMO..",
    "..OMMMMMMMMMMO..",
    "...OMMMMMMMMO...",
    "..OOOOOOOOOOOO..",
    ".OWWWWWWWWWWWWO.",
    ".OWWWWWWWWWWWWO.",
    ".OOOOOOOOOOOOOO.",
    "..OO........OO..",
]


def mortar(shoot):
    """Mortero sencillo: olla de hierro (2 tonos + brillo) sobre una base de madera."""
    pal = {'O': rgb('1a1a22'), 'k': rgb('0c0c10'), 'L': rgb('7a8092'), 'M': rgb('4c5160'), 'W': rgb('8c5c34')}
    rows = list(MORTAR)
    if shoot:   # boca al rojo
        rows[3] = "...OffffffffO..."
        pal['f'] = rgb('f07822')
    return grid(rows, pal)


# ── Punto de control (8x16, mismo tamaño que antes) ───────────────────────────
def checkpoint(on):
    pal = {'O': rgb('1e1e26'), 'P': rgb('c8ccd8'), 'p': rgb('8a8ea0'), 'S': rgb('7a7a88'), 's': rgb('55555f')}
    if on:
        pal.update({'G': rgb('7af0a0'), 'g': rgb('3aa860'), 'F': rgb('ffd040'), 'f': rgb('e08a20')})
        rows = [
            "..OO....",
            ".OGgO...",
            "..OO....",
            "..PpFFFO",
            "..PpFFfO",
            "..PpFfFO",
            "..PpFFO.",
            "..PpO...",
            "..Pp....",
            "..Pp....",
            "..Pp....",
            "..Pp....",
            "..Pp....",
            ".OSSsO..",
            "OSSSSsO.",
            "OOOOOOO.",
        ]
    else:
        pal.update({'G': rgb('5a5e6c'), 'g': rgb('3c3f4a'), 'F': rgb('9aa0b4'), 'f': rgb('6e7488')})
        rows = [
            "..OO....",
            ".OGgO...",
            "..OO....",
            "..PpO...",
            "..PpFO..",
            "..PpFfO.",
            "..PpFFO.",
            "..PpFfO.",
            "..PpFO..",
            "..PpO...",
            "..Pp....",
            "..Pp....",
            "..Pp....",
            ".OSSsO..",
            "OSSSSsO.",
            "OOOOOOO.",
        ]
    return grid(rows, pal)


# ── Transiciones de la arena (franja a la izquierda, se gira en el juego) ─────
BLEND = ["XXXXXXXXXXXXXXXX", "XXX.XXXXX.XXXX.X", "X.X..X.X..X.X..X", "..X....X....X...", "......X........."]


def blend(dk, bs):
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for x, col in enumerate(BLEND):
        for y, ch in enumerate(col):
            if ch == 'X': im.putpixel((x, y), dk if (x + y) % 3 == 0 else bs)
    return im


if __name__ == '__main__':
    print('Arte del mundo:')
    # (muy sencillas: color plano y pocas marcas cortas que no tocan los bordes)
    save('world/tiles/stone.png', simple_rock(STONE, STONE_MARKS))
    save('world/tiles/deep_stone.png', simple_rock(DEEP, DEEP_MARKS))
    save('world/tiles/border.png', simple_rock(BORDER, BORDER_MARKS))
    save('world/tiles/lava.png', strip([lava_frame(f, False) for f in range(4)]))
    save('world/tiles/lava_top.png', strip([lava_frame(f, True) for f in range(4)]))
    save('world/tiles/platform.png', platform())
    save('world/tiles/sand_blend.png', strip([blend(rgb('5a3c22'), rgb('76502e')), blend(STONE['crack'], STONE['base']),
                                        blend(DEEP['crack'], DEEP['base']), blend(BORDER['crack'], BORDER['base'])]))
    save('fx/lava_fx.png', lava_fx())
    save('enemies/mortar/normal.png', mortar(False), 1)
    save('enemies/mortar/shooting.png', mortar(True), 1)
    save('items/checkpoint_off.png', checkpoint(False), 1)
    save('items/checkpoint_on.png', checkpoint(True), 1)
