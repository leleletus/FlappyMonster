#!/usr/bin/env python3
# tools/ui/make_overworld.py
# El MAPA DEL MUNDO del modo historia (estilo Super Mario World), como DATOS + unos pocos sprites:
#   assets/story/overworld.json   el terreno (una letra por casilla de 32 px), el CAMINO de cada mundo (una
#                                 polilínea: el juego reparte por ella los niveles del mundo, sean cuantos
#                                 sean, con el jefe al final, en su castillo), los puentes entre mundos, las
#                                 decoraciones y los bichos que pasean
#   assets/images/story/          node-Sheet (punto de nivel: cerrado, abierto, superado, actual), castle-Sheet
#                                 (castillo del jefe: con bandera roja / dorada al vencerlo), water-Sheet (el mar,
#                                 2 cuadros), path.png (baldosa del camino), bridge.png (tablones)
# El terreno se pinta en el juego con las texturas de los BLOQUES del juego (césped, arena, nieve, piedra,
# roca, lava…) y las decoraciones / enemigos / jefes son sus sprites de siempre en pequeño.
#   python3 tools/ui/make_overworld.py        (determinista: misma semilla, mismo mapa)
import json, math, os, random
from PIL import Image

OUT_JSON = 'assets/story/overworld.json'
IMG = 'assets/images/story/'
W, H = 84, 48
rng = random.Random(1987)

# ── Terreno ──────────────────────────────────────────────────────────────────
# '~' mar · g césped · s arena · w nieve · c roca de cueva · f piedra (fortaleza) · l roca volcánica
grid = [['~'] * W for _ in range(H)]


def blob(cx, cy, rx, ry, ch, jag=0.18):
    """Isla redondeada con borde irregular"""
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            ang = math.atan2(dy, dx)
            wob = 1 + jag * (math.sin(ang * 5 + cx) * 0.6 + math.sin(ang * 9 + cy) * 0.4)
            if dx * dx + dy * dy <= wob * wob:
                grid[y][x] = ch


def rect(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            grid[y][x] = ch


# Mundo 1, la Pradera (abajo a la izquierda) · 2, la Costa (abajo en medio) · 3, la Fortaleza (abajo a la derecha)
# 4, las Cumbres (arriba a la derecha) · 5, las Cuevas (arriba a la izquierda) · 6, el Final (en el centro)
blob(14, 35, 12, 9, 'g'); blob(8, 30, 6, 5, 'g')
blob(40, 39, 12, 7, 's'); blob(41, 38, 8, 5, 'g'); blob(48, 36, 5, 4, 'g')
blob(68, 36, 13, 9, 'f'); blob(76, 30, 5, 5, 'f')
blob(67, 12, 14, 9, 'w'); blob(58, 18, 6, 4, 'w')
blob(19, 12, 14, 9, 'c'); blob(10, 17, 6, 4, 'c')
blob(42, 19, 8, 7, 'l', 0.25)
blob(43, 18, 2.2, 1.6, 'L', 0.1); blob(38, 15, 1.6, 1.2, 'L', 0.1)      # charcos de lava en el volcán
# playas: arena en el borde de la Pradera y la Costa
for y in range(1, H - 1):
    for x in range(1, W - 1):
        if grid[y][x] == 'g' and any(grid[y + dy][x + dx] == '~' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) and rng.random() < 0.35 and x > 26:
            grid[y][x] = 's'

# ── Caminos (polilíneas en casillas; el juego reparte por ellas los nodos) ────
PATHS = {
    'pradera':   [(5, 31), (8, 36), (12, 40), (17, 38), (20, 33), (16, 29), (21, 27), (24, 31)],
    'costa':     [(31, 38), (35, 42), (40, 43), (44, 39), (41, 35), (47, 34), (50, 38)],
    'fortaleza': [(58, 38), (62, 42), (68, 43), (72, 38), (67, 33), (73, 30), (77, 27)],
    'nieve':     [(76, 17), (72, 14), (66, 17), (60, 18), (62, 10), (68, 7), (73, 9)],
    'cuevas':    [(29, 11), (25, 7), (19, 6), (13, 9), (9, 15), (17, 15), (23, 17)],
    'final':     [(36, 18), (40, 23), (45, 22), (47, 17), (42, 14)],
}
ORDER = ['pradera', 'costa', 'fortaleza', 'nieve', 'cuevas', 'final']
# Puentes entre mundos: del castillo de uno al primer nivel del siguiente
CONNECT = [
    [(24, 31), (27, 35), (31, 38)],
    [(50, 38), (54, 38), (58, 38)],
    [(77, 27), (78, 22), (76, 17)],
    [(73, 9), (60, 3), (38, 4), (29, 11)],
    [(23, 17), (30, 18), (36, 18)],
]

# Bajo cada camino de mundo siempre hay tierra (su terreno); los puentes entre mundos cruzan el agua
LAND = {'pradera': 'g', 'costa': 'g', 'fortaleza': 'f', 'nieve': 'w', 'cuevas': 'c', 'final': 'l'}


def carve(path, ch):
    for i in range(len(path) - 1):
        (ax, ay), (bx, by) = path[i], path[i + 1]
        n = int(max(abs(bx - ax), abs(by - ay)) * 3) + 1
        for j in range(n + 1):
            x, y = ax + (bx - ax) * j / n, ay + (by - ay) * j / n
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    cx, cy = int(x + dx), int(y + dy)
                    if grid[cy][cx] in '~L':
                        grid[cy][cx] = ch


for k in ORDER:
    carve(PATHS[k], LAND[k])

# ── Decoraciones (sus sprites del juego, en pequeño), lejos de los caminos ────
DECOS = {
    'g': ['tulip', 'bush', 'fern', 'hibiscus', 'bush'],
    's': ['palm', 'pineapple', 'palm', 'hibiscus'],
    'f': ['torch', 'bones', 'stalagmite_small', 'torch'],
    'w': ['snowy_pine', 'snowy_pine', 'snowman', 'frozen_bush', 'snow_pile'],
    'c': ['crystals', 'stalagmite', 'glow_mushroom', 'crystals'],
    'l': ['stalagmite', 'bones', 'stalagmite_small'],
}


def seg_dist(px, py, a, b):
    (ax, ay), (bx, by) = a, b
    vx, vy = bx - ax, by - ay
    t = max(0, min(1, ((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy + 1e-9)))
    return math.hypot(px - ax - vx * t, py - ay - vy * t)


lines = list(PATHS.values()) + CONNECT


def near_path(x, y, d):
    return any(seg_dist(x, y, l[i], l[i + 1]) < d for l in lines for i in range(len(l) - 1))


decos = []
taken = set()
for y in range(2, H - 2):
    for x in range(2, W - 2):
        ch = grid[y][x]
        if ch in DECOS and grid[y + 1][x] != '~' and rng.random() < 0.16 and not near_path(x + 0.5, y + 0.5, 1.6):
            if any((x + dx, y + dy) in taken for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                continue
            taken.add((x, y))
            decos.append({'t': rng.choice(DECOS[ch]), 'x': x, 'y': y})

# ── Bichos que pasean (de un lado a otro, por tierra; peces en el agua) ──────
CRITTERS = [
    ('gummy', 6, 11, 41), ('crabby', 17, 22, 36), ('gummy', 9, 14, 28), ('crabby', 3, 7, 35),
    ('crabby', 33, 38, 36), ('gummy', 43, 47, 41), ('puffer', 28, 33, 44), ('puffer', 50, 55, 44),
    ('bomb', 60, 65, 35), ('crabby', 70, 75, 41), ('bomb', 64, 69, 30),
    ('crabby_ice', 62, 67, 14), ('gummy_ice', 69, 74, 15), ('crabby_ice', 56, 60, 19),
    ('gloomy', 12, 17, 12), ('gloomy', 21, 26, 9), ('gloomy', 8, 11, 18),
    ('puffer', 36, 41, 8), ('puffer', 52, 57, 26),
]
critters = []
for t, x0, x1, y in CRITTERS:
    critters.append({'t': t, 'x0': x0, 'x1': x1, 'y': y})

# El jefe de cada mundo, en pequeño junto a su castillo (sus sprites del juego; fw = ancho de cuadro)
BOSS_ART = {
    'pradera':   {'img': 'assets/images/bosses/megagummy/body-Sheet.png', 'fw': 16, 'over': 'assets/images/bosses/megagummy/crown.png'},
    'costa':     {'img': 'assets/images/bosses/megacrabby/crab1.png'},
    'fortaleza': {'img': 'assets/images/bosses/miniboss1/ship.png', 'fly': True},
    'nieve':     {'img': 'assets/images/bosses/megacrabby_ice/crab1.png'},
    'cuevas':    {'img': 'assets/images/bosses/megagloomy/body-Sheet.png', 'fw': 38, 'glow': 'assets/images/bosses/megagloomy/glow-Sheet.png'},
    'final':     {'img': 'assets/images/bosses/mirror/Body_ArmsDown.png', 'over': 'assets/images/bosses/mirror/Head_Down.png', 'invert': True},
}

data = {
    'cell': 32, 'w': W, 'h': H,
    'rows': [''.join(r) for r in grid],
    'worlds': [{'id': k, 'path': [list(p) for p in PATHS[k]], 'boss': BOSS_ART[k]} for k in ORDER],
    'connect': [[list(p) for p in c] for c in CONNECT],
    'decos': decos, 'critters': critters,
}
with open(OUT_JSON, 'w') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
print('  %s  %dx%d, %d decoraciones, %d bichos' % (OUT_JSON, W, H, len(decos), len(critters)))

# ── Sprites (estilo del juego: contorno oscuro, 3 tonos) ─────────────────────
OUT = (24, 22, 32, 255)


def grid_img(rows, pal):
    im = Image.new('RGBA', (len(rows[0]), len(rows)))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            im.putpixel((x, y), pal.get(ch, (0, 0, 0, 0)))
    return im


def sheet(frames, path):
    w, h = frames[0].size
    s = Image.new('RGBA', (w * len(frames), h))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    s.save(path)
    print('  %s %dx%d' % (path, s.width, s.height))


NODE = ['..oooo..', '.oaaaao.', 'oabbbbao', 'oabbbbao', 'oabbbbao', 'oaccccao', '.oaaaao.', '..oooo..']
node_pals = [
    {'o': OUT, 'a': (70, 70, 84, 255), 'b': (110, 110, 124, 255), 'c': (88, 88, 100, 255)},      # cerrado
    {'o': OUT, 'a': (150, 30, 30, 255), 'b': (232, 64, 56, 255), 'c': (186, 44, 40, 255)},       # abierto
    {'o': OUT, 'a': (170, 120, 20, 255), 'b': (255, 214, 70, 255), 'c': (220, 170, 40, 255)},    # superado
    {'o': OUT, 'a': (40, 90, 170, 255), 'b': (90, 170, 255, 255), 'c': (60, 130, 220, 255)},     # (resaltado)
]
sheet([grid_img(NODE, p) for p in node_pals], IMG + 'node-Sheet.png')

CASTLE = ['....f...........',
          '....fFF.........',
          '....fFFF........',
          '....f...........',
          '.o.o.o..o.o.o...',
          '.ommmo..ommmo...',
          '.oLmmo..oLmmo...',
          '.oLmmooooLmmo...',
          '.oLmmmmmmLmmo...',
          '.oLmmmddmLmmo...',
          '.oLmmdDDdLmmo...',
          '.oLmmdDDdLmmo...',
          '.oLmmdDDdLmmo...',
          '.ooooooooooo....',
          '................',
          '................']
CASTLE = [r[:14] + r[14:] for r in CASTLE]
base = {'o': OUT, 'm': (150, 150, 164, 255), 'L': (196, 196, 210, 255), 'd': (70, 60, 70, 255), 'D': (30, 24, 34, 255), 'f': (90, 70, 50, 255)}
red = dict(base, F=(220, 50, 50, 255))
gold = dict(base, F=(255, 210, 60, 255))
sheet([grid_img(CASTLE, red), grid_img(CASTLE, gold)], IMG + 'castle-Sheet.png')

# Mar: azul con crestas que se mueven (2 cuadros de 16x16)
def water(phase):
    im = Image.new('RGBA', (16, 16), (52, 110, 200, 255))
    for y in range(16):
        for x in range(16):
            if (x + y * 3 + phase * 4) % 16 in (0, 1) and y % 8 == (3 if phase == 0 else 4):
                im.putpixel((x, y), (120, 180, 240, 255))
            if (x * 7 + y * 5 + phase * 3) % 31 == 0:
                im.putpixel((x, y), (200, 230, 255, 255))
    return im
sheet([water(0), water(1)], IMG + 'water-Sheet.png')

path = grid_img(['.oo.', 'oaao', 'oaao', '.oo.'], {'o': (150, 110, 60, 255), 'a': (236, 210, 150, 255)})
path.save(IMG + 'path.png')
bridge = grid_img(['oooooooo', 'abababab', 'abababab', 'oooooooo'], {'o': (70, 44, 24, 255), 'a': (170, 116, 60, 255), 'b': (140, 92, 46, 255)})
bridge.save(IMG + 'bridge.png')
print('  %spath.png, bridge.png' % IMG)

# Suelo visto desde ARRIBA (una baldosa 16x16 por terreno, con los colores de su bloque del juego) y la
# espuma de la orilla. Los acantilados usan las texturas de los bloques tal cual (vistas de lado).
def tone(path, x, y):
    return Image.open(path).convert('RGBA').getpixel((x, y))


def ground(base, dots, seed):
    r = random.Random(seed)
    im = Image.new('RGBA', (16, 16), base)
    for col, n in dots:
        for _ in range(n):
            x, y = r.randrange(16), r.randrange(16)
            im.putpixel((x, y), col)
            if r.random() < 0.4 and x < 15:
                im.putpixel((x + 1, y), col)
    return im


T = 'assets/images/tiles/'
g0 = tone(T + 'grass.png', 30, 2)
# (base, oscuro, claro) de cada terreno, de los colores de su bloque del juego
TERR = [
    (g0, (g0[0] - 30, g0[1] - 40, g0[2] - 20, 255), (min(255, g0[0] + 40), min(255, g0[1] + 30), g0[2] + 20, 255)),   # g
    (tone(T + 'sand.png', 30, 30), (196, 160, 104, 255), (240, 222, 170, 255)),                                       # s
    (tone(T + 'snow.png', 30, 20), (196, 214, 240, 255), (255, 255, 255, 255)),                                       # w
    (tone(T + 'border.png', 60, 60), (26, 26, 34, 255), (80, 78, 100, 255)),                                          # c
    (tone(T + 'stone.png', 60, 60), (52, 52, 62, 255), (110, 110, 124, 255)),                                         # f
    (tone(T + 'deep_stone.png', 60, 60), (60, 30, 34, 255), (140, 66, 50, 255)),                                      # l
]
# 3 variantes por terreno (el juego elige una por casilla): lisa, con motas y con una mancha más oscura
tops = []
for i, (base, dark, light) in enumerate(TERR):
    tops.append(ground(base, [(dark, 6), (light, 3)], 10 + i))
    tops.append(ground(base, [(dark, 12), (light, 7)], 20 + i))
    im = ground(base, [(dark, 4), (light, 3)], 30 + i)
    r = random.Random(40 + i)
    cx, cy = r.randrange(4, 12), r.randrange(4, 12)
    for y in range(16):
        for x in range(16):
            if ((x - cx) / 4.5) ** 2 + ((y - cy) / 3) ** 2 < 1 and (x + y) % 2 == 0:
                im.putpixel((x, y), dark)
    tops.append(im)
sheet(tops, IMG + 'ground-Sheet.png')
# Borde de la tierra que da al mar (arriba y a los lados): contorno oscuro + brillo, uno por terreno (16x4)
edges = []
for base, dark, light in TERR:
    e = Image.new('RGBA', (16, 4))
    for x in range(16):
        e.putpixel((x, 0), OUT)
        e.putpixel((x, 1), light)
        if x % 3 != 1:
            e.putpixel((x, 2), light)
    edges.append(e)
sheet(edges, IMG + 'edge-Sheet.png')
foam = Image.new('RGBA', (16, 4))
for x in range(16):
    foam.putpixel((x, 0), (230, 245, 255, 255))
    if x % 5 in (1, 2):
        foam.putpixel((x, 1), (170, 215, 250, 255))
foam.save(IMG + 'foam.png')
print('  %sfoam.png' % IMG)
