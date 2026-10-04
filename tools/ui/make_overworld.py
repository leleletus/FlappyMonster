#!/usr/bin/env python3
# tools/ui/make_overworld.py
# El MAPA DEL MUNDO del modo historia (estilo Super Mario World), como DATOS + unos pocos sprites:
#   assets/story/overworld.json   el terreno (una letra por casilla de 32 px), su ALTURA (0 hoyo, 1 llano,
#                                 2 meseta, 3 cumbre: el juego dibuja acantilados donde baja), el CAMINO de cada
#                                 mundo (curva suave: el juego reparte por ella los niveles del mundo, sean
#                                 cuantos sean, con el jefe al final, en su castillo), los puentes entre mundos,
#                                 las decoraciones / formaciones del terreno y los bichos que pasean
#   assets/images/story/          node-Sheet, castle-Sheet, water-Sheet, path.png, bridge.png, ground-Sheet,
#                                 edge-Sheet, foam.png y features/*.png (colinas, dunas, picos, agujas de roca,
#                                 rocas, bocas de cueva: el relieve de cada isla)
# El terreno se pinta en el juego con las texturas de los BLOQUES del juego (césped, arena, nieve, piedra,
# roca, lava…) y las decoraciones / enemigos / jefes son sus sprites de siempre en pequeño.
# Reglas del relieve: los caminos van por el LLANO (valles entre mesetas; nada se levanta a menos de ~2
# casillas de un camino); las mesetas y cumbres tienen al menos 2x2 casillas; las cuevas tienen hoyos.
#   python3 tools/ui/make_overworld.py        (determinista: misma semilla, mismo mapa)
import json, math, os, random
from PIL import Image

OUT_JSON = 'assets/story/overworld.json'
IMG = 'assets/images/story/'
FEAT = IMG + 'features/'
os.makedirs(FEAT, exist_ok=True)
W, H = 84, 48
rng = random.Random(1987)

# ── Terreno ──────────────────────────────────────────────────────────────────
# '~' mar · g césped · s arena · w nieve · c roca de cueva · f piedra (fortaleza) · l roca volcánica · L lava
grid = [['~'] * W for _ in range(H)]
hgt = [[1] * W for _ in range(H)]          # altura de cada casilla de tierra (el mar no cuenta)


def blob(cx, cy, rx, ry, ch, jag=0.18):
    """Isla redondeada con borde irregular"""
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            ang = math.atan2(dy, dx)
            wob = 1 + jag * (math.sin(ang * 5 + cx) * 0.6 + math.sin(ang * 9 + cy) * 0.4)
            if dx * dx + dy * dy <= wob * wob:
                grid[y][x] = ch


# Mundo 1, la Pradera (abajo a la izquierda) · 2, la Costa (abajo en medio) · 3, la Fortaleza (abajo a la derecha)
# 4, las Cumbres (arriba a la derecha) · 5, las Cuevas (arriba a la izquierda) · 6, el Final (el volcán, en medio)
blob(14, 35, 12, 9, 'g'); blob(8, 30, 6, 5, 'g')
blob(40, 39, 12, 7, 's'); blob(41, 38, 8, 5, 'g'); blob(48, 36, 5, 4, 'g')
blob(68, 36, 13, 9, 'f'); blob(76, 30, 5, 5, 'f')
blob(67, 12, 14, 9, 'w'); blob(58, 18, 6, 4, 'w')
blob(19, 12, 14, 9, 'c'); blob(10, 17, 6, 4, 'c')
blob(42, 19, 8, 7, 'l', 0.25)
for y in range(1, H - 1):
    for x in range(1, W - 1):
        if grid[y][x] == 'g' and any(grid[y + dy][x + dx] == '~' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) and rng.random() < 0.35 and x > 26:
            grid[y][x] = 's'

# ── Caminos: puntos de control → curva suave (Catmull-Rom) ───────────────────
PATHS = {
    'pradera':   [(5, 31), (8, 36), (12, 40), (17, 38), (20, 33), (16, 29), (21, 27), (24, 31)],
    'costa':     [(31, 38), (35, 42), (40, 43), (44, 39), (41, 35), (47, 34), (50, 38)],
    'fortaleza': [(58, 38), (62, 42), (68, 43), (72, 38), (67, 33), (73, 30), (77, 27)],
    'nieve':     [(76, 17), (72, 14), (66, 17), (60, 18), (62, 10), (68, 7), (73, 9)],
    'cuevas':    [(29, 11), (25, 7), (19, 6), (13, 9), (9, 15), (17, 15), (23, 17)],
    'final':     [(36, 18), (40, 23), (45, 22), (47, 17), (42, 14)],
}
ORDER = ['pradera', 'costa', 'fortaleza', 'nieve', 'cuevas', 'final']
# Puentes entre mundos: del castillo de uno al primer nivel del siguiente (con puntos intermedios para que curven)
CONNECT = [
    [(24, 31), (26, 34), (28.5, 36.5), (31, 38)],
    [(50, 38), (53, 39.5), (56, 39.5), (58, 38)],
    [(77, 27), (79, 23.5), (78.5, 20), (76, 17)],
    [(73, 9), (68, 3.5), (58, 2.5), (45, 3), (35, 5), (29, 11)],
    [(23, 17), (27, 19.5), (32, 19.5), (36, 18)],
]


# BONUS de cada mundo (arena contra el bot): un ramal corto desde el castillo hasta su nodo
BONUS = {'pradera': [(24, 31), (24, 27.5), (22, 24.5)], 'costa': [(50, 38), (52.5, 40), (52, 43)],
         'fortaleza': [(77, 27), (74.5, 25.5), (71.5, 26.5)], 'nieve': [(73, 9), (76.5, 8), (78.5, 5.5)],
         'cuevas': [(23, 17), (26, 18.5), (26.5, 21)], 'final': [(42, 14), (45, 13), (47.5, 14)]}


def catmull(pts, n=8):
    """Curva que pasa por todos los puntos de control (sin esquinas)"""
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for j in range(n):
            t = j / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    out.append(tuple(pts[-1]))
    return [(round(x, 2), round(y, 2)) for x, y in out]


SPATHS = {k: catmull(v) for k, v in PATHS.items()}
SCONNECT = [catmull(c) for c in CONNECT]
SBONUS = {k: catmull(v) for k, v in BONUS.items()}
LINES = list(SPATHS.values()) + SCONNECT + list(SBONUS.values())


def seg_dist(px, py, a, b):
    (ax, ay), (bx, by) = a, b
    vx, vy = bx - ax, by - ay
    t = max(0, min(1, ((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy + 1e-9)))
    return math.hypot(px - ax - vx * t, py - ay - vy * t)


# distancia de cada casilla (su centro) al camino o puente más cercano
dist = [[min(seg_dist(x + 0.5, y + 0.5, l[i], l[i + 1]) for l in LINES for i in range(len(l) - 1))
         for x in range(W)] for y in range(H)]

LAND = {'pradera': 'g', 'costa': 'g', 'fortaleza': 'f', 'nieve': 'w', 'cuevas': 'c', 'final': 'l'}
# bajo cada camino de mundo siempre hay tierra (su terreno); los puentes cruzan el agua
for k in ORDER:
    for y in range(H):
        for x in range(W):
            if grid[y][x] == '~' and min(seg_dist(x + 0.5, y + 0.5, l[i], l[i + 1]) for l in (SPATHS[k], SBONUS[k]) for i in range(len(l) - 1)) < 1.3:
                grid[y][x] = LAND[k]

# ── Relieve: mesetas (2), cumbres (3), hoyos (0) y el cráter del volcán ──────
def land(x, y):
    return 0 <= x < W and 0 <= y < H and grid[y][x] != '~'


def interior(x, y, r=1):
    return all(land(x + dx, y + dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1))


def wobbly(x, y, cx, cy, rx, ry, jag=0.3):
    """dentro de una elipse de borde irregular (para que nada sea un rectángulo)"""
    dx, dy = (x - cx) / rx, (y - cy) / ry
    ang = math.atan2(dy, dx)
    wob = 1 + jag * (math.sin(ang * 3 + cx * 1.7) * 0.6 + math.sin(ang * 5 + cy * 2.3) * 0.4)
    return dx * dx + dy * dy <= wob * wob


def raise_blob(cx, cy, rx, ry, level, chars, clear):
    for y in range(H):
        for x in range(W):
            if wobbly(x, y, cx, cy, rx, ry) and grid[y][x] in chars and interior(x, y) \
                    and dist[y][x] >= clear and hgt[y][x] == level - 1:
                hgt[y][x] = level


def open2x2(level):
    """Quita lo que no forme al menos un bloque de 2x2 de esa altura (sin crestas de una casilla)"""
    keep = [[False] * W for _ in range(H)]
    for y in range(H - 1):
        for x in range(W - 1):
            if all(hgt[y + dy][x + dx] >= level and land(x + dx, y + dy) for dx in (0, 1) for dy in (0, 1)):
                for dx in (0, 1):
                    for dy in (0, 1):
                        keep[y + dy][x + dx] = True
    for y in range(H):
        for x in range(W):
            if hgt[y][x] >= level and not keep[y][x]:
                hgt[y][x] = level - 1


def lower_pits(cx, cy, rx, ry, chars, clear):
    for y in range(H):
        for x in range(W):
            if wobbly(x, y, cx, cy, rx, ry, 0.2) and grid[y][x] in chars and interior(x, y) \
                    and dist[y][x] >= clear and hgt[y][x] == 1:
                hgt[y][x] = 0


# (x, y, rx, ry, altura, terrenos, distancia mínima al camino)
RELIEF = [
    # Pradera: lomas y una colina alta; el camino va por los valles
    (10, 34, 3, 2.6, 2, 'g', 2), (13, 44, 4.5, 2.2, 2, 'g', 2), (5, 40, 3, 2.4, 2, 'g', 2), (17, 32, 2.6, 2.4, 2, 'g', 1.8),
    (11, 26, 3.5, 2.2, 2, 'g', 2), (4, 33, 2.5, 2.5, 2, 'g', 2), (21, 42, 3, 1.8, 2, 'g', 2), (13, 34, 1.8, 1.6, 3, 'g', 2.6),
    (5, 27, 3, 2, 2, 'g', 2),
    # Costa: mesetas de hierba con acantilados de tierra; dunas en la arena
    (38, 39, 3, 2.6, 2, 'gs', 2), (45, 43, 3.5, 1.8, 2, 'gs', 2), (37, 33, 2.8, 1.8, 2, 'gs', 1.8), (44, 37, 2, 1.5, 2, 'g', 1.8),
    (38, 39, 1.6, 1.4, 3, 'g', 2.6),
    # Fortaleza: terrazas de piedra a varias alturas
    (66, 38, 4, 4, 2, 'f', 2), (66, 38, 2.4, 2.4, 3, 'f', 2.6), (76, 35, 3.5, 4.5, 2, 'f', 2), (76, 35, 2, 2.6, 3, 'f', 2.6),
    (63, 31, 3.5, 2.4, 2, 'f', 2), (71, 44, 3.5, 1.8, 2, 'f', 2), (58, 43, 3, 2, 2, 'f', 1.8), (79, 41, 2, 2.5, 2, 'f', 2),
    # Cumbres: una cordillera (mesetas grandes con cumbres)
    (68, 11, 6, 4, 2, 'w', 1.8), (68, 11, 4, 2.6, 3, 'w', 2.4), (59, 14, 3.5, 3.5, 2, 'w', 1.8), (59, 14, 2.2, 2.2, 3, 'w', 2.4),
    (74, 14, 3.5, 2.6, 2, 'w', 1.8), (64, 19, 4.5, 1.8, 2, 'w', 1.8), (77, 8, 3.5, 3, 2, 'w', 1.8), (77, 8, 2, 1.8, 3, 'w', 2.4),
    (62, 5, 3, 2, 2, 'w', 1.8), (79, 15, 2, 2.4, 2, 'w', 1.8),
    # Cuevas: terreno muy quebrado (terrazas a tres alturas, pegadas unas a otras)
    (19, 11, 4.5, 3.4, 2, 'c', 1.8), (19, 11, 3, 2.2, 3, 'c', 2.4), (10, 11, 3.5, 2.4, 2, 'c', 1.8), (27, 14, 3.2, 2.4, 2, 'c', 1.8),
    (14, 19, 4, 2.4, 2, 'c', 1.8), (23, 4, 4.5, 1.8, 2, 'c', 1.8), (31, 8, 2.4, 3.4, 2, 'c', 1.8), (6, 20, 3.4, 2.4, 2, 'c', 1.8),
    (6, 13, 2.4, 2.4, 2, 'c', 1.8), (14, 4, 3, 1.6, 2, 'c', 1.8), (27, 14, 1.8, 1.4, 3, 'c', 2.4), (10, 11, 1.8, 1.4, 3, 'c', 2.4),
    # Volcán: el cono alrededor del cráter y coladas
    (41, 18, 3.6, 3.4, 2, 'l', 1.8), (41, 18, 2.6, 2.4, 3, 'l', 2.2), (38, 23, 2.4, 1.8, 2, 'l', 1.8), (48, 21, 2, 2.4, 2, 'l', 1.8),
    (44, 25, 2.5, 1.5, 2, 'l', 1.8),
]
for cx, cy, rx, ry, lv, ch, clear in RELIEF:
    raise_blob(cx, cy, rx, ry, lv, ch, clear)
open2x2(3)
open2x2(2)
# hoyos de las cuevas (simas): bajo el llano, con su pared
for cx, cy, rx, ry in [(13, 13, 1.6, 1.2), (24, 11, 1.5, 1.4), (9, 7, 1.5, 1.2), (19, 18, 1.4, 1.1), (27, 4, 1.4, 1)]:
    lower_pits(cx, cy, rx, ry, 'c', 2.2)
# el cráter: lava en lo alto del cono
for y in range(H):
    for x in range(W):
        if wobbly(x, y, 41, 18, 1.7, 1.4, 0.25) and hgt[y][x] >= 2:
            grid[y][x] = 'L'
            hgt[y][x] = 2

# ── Decoraciones y formaciones (lejos de los caminos, nunca sobre una pared) ──
DECOS = {
    'g': ['tulip', 'bush', 'fern', 'hibiscus', 'bush'],
    's': ['palm', 'pineapple', 'palm', 'hibiscus'],
    'f': ['torch', 'bones', 'rock_grey', 'torch'],
    'w': ['snowy_pine', 'snowy_pine', 'snowman', 'frozen_bush', 'snow_pile'],
    'c': ['crystals', 'stalagmite', 'glow_mushroom', 'crystals', 'rock_dark'],
    'l': ['stalagmite', 'bones', 'rock_red'],
}
# formaciones grandes por terreno y altura (features/*.png)
FEATURES = {
    ('g', 1): ['hill'], ('g', 2): ['hill', 'hill', 'rock_brown'],
    ('s', 1): ['dune', 'dune', 'rock_brown'], ('s', 2): ['rock_brown'],
    ('f', 2): ['rock_grey'], ('f', 3): ['rock_grey', 'spire_grey'],
    ('w', 2): ['peak', 'snowy_pine'], ('w', 3): ['peak', 'peak'],
    ('c', 1): ['spire', 'rock_dark'], ('c', 2): ['spire', 'rock_dark', 'stalagmite'], ('c', 3): ['spire', 'spire'],
    ('l', 2): ['rock_red', 'spire_red'],
}


def h(x, y):
    return hgt[y][x] if land(x, y) else -1


decos = []
taken = set()
for y in range(2, H - 2):
    for x in range(2, W - 2):
        ch = grid[y][x]
        if ch not in DECOS or ch == 'L' or dist[y][x] < 1.6 or hgt[y][x] == 0:
            continue
        if h(x, y - 1) > h(x, y) or h(x, y + 1) != h(x, y):      # (ni pegado bajo una pared ni encima de un borde)
            continue
        if any((x + dx, y + dy) in taken for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            continue
        feats = FEATURES.get((ch, hgt[y][x]))
        roll = rng.random()
        if feats and roll < (0.4 if hgt[y][x] > 1 else 0.08):
            taken.add((x, y))
            decos.append({'t': rng.choice(feats), 'x': x, 'y': y})
        elif roll < 0.2:
            taken.add((x, y))
            decos.append({'t': rng.choice(DECOS[ch]), 'x': x, 'y': y})
# bocas de cueva en las paredes de las cuevas (en la casilla de abajo, sobre la cara del acantilado)
mouths = 0
for y in range(3, H - 2):
    for x in range(3, W - 3):
        if grid[y][x] == 'c' and h(x, y - 1) > h(x, y) >= 1 and h(x - 1, y - 1) > h(x, y) and h(x + 1, y - 1) > h(x, y) \
                and dist[y][x] >= 1.4 and (x, y) not in taken and rng.random() < 0.5 and mouths < 9:
            diff = min(2, h(x, y - 1) - h(x, y))
            decos.append({'t': 'cave_mouth', 'x': x, 'y': y, 'oy': round(0.75 * diff, 2)})
            taken.add((x, y))
            mouths += 1

# ── Bichos que pasean (de un lado a otro por el MISMO llano; peces en el agua) ─
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
    if t == 'puffer':      # (coordenadas a mano: el juego los lleva al mar abierto más cercano — StoryMapState loadMap)
        critters.append({'t': t, 'x0': x0, 'x1': x1, 'y': y})
        continue
    # el tramo más largo de casillas de tierra seguidas a la misma altura (sin cruzar paredes)
    best, run = None, []
    for x in range(x0 - 2, x1 + 3):
        ok = land(x, y) and grid[y][x] != 'L' and h(x, y + 1) == h(x, y) and (not run or h(x, y) == h(run[0], y))
        if ok:
            run.append(x)
        if not ok or x == x1 + 2:
            if run and (best is None or len(run) > len(best)):
                best = run
            run = [x] if ok and run and h(x, y) != h(run[0], y) else ([] if not ok else run)
    if best and len(best) >= 3:
        critters.append({'t': t, 'x0': best[0], 'x1': best[-1], 'y': y})

# El jefe de cada mundo, en pequeño junto a su castillo (sus sprites del juego; fw = ancho de cuadro)
BOSS_ART = {
    'pradera':   {'img': 'assets/images/bosses/megagummy/body-Sheet.png', 'fw': 16, 'over': 'assets/images/bosses/megagummy/crown.png', 'overBig': True},
    'costa':     {'img': 'assets/images/bosses/megacrabby/crab1.png'},
    'fortaleza': {'img': 'assets/images/bosses/miniboss1/ship.png', 'fly': True, 'under': 'assets/images/bosses/miniboss1/monster/Idle1.png'},
    'nieve':     {'img': 'assets/images/bosses/megacrabby_ice/crab1.png'},
    'cuevas':    {'img': 'assets/images/bosses/megagloomy/body-Sheet.png', 'fw': 38, 'glow': 'assets/images/bosses/megagloomy/glow-Sheet.png'},
    'final':     {'img': 'assets/images/bosses/mirror/Body_ArmsDown.png', 'over': 'assets/images/bosses/mirror/Head_Down.png', 'invert': True},
}

data = {
    'cell': 32, 'w': W, 'h': H,
    'rows': [''.join(r) for r in grid],
    'heights': [''.join(str(v) for v in r) for r in hgt],
    'worlds': [{'id': k, 'path': [list(p) for p in SPATHS[k]], 'boss': BOSS_ART[k], 'bonus': [list(p) for p in SBONUS[k]]} for k in ORDER],
    'connect': [[list(p) for p in c] for c in SCONNECT],
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
    {'o': OUT, 'a': (40, 90, 170, 255), 'b': (90, 170, 255, 255), 'c': (60, 130, 220, 255)},     # bonus abierto (azul)
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

# ── Formaciones del relieve (features/*.png): forma + contorno + 3 tonos ─────
def shape_img(w, h, inside, pal, extra=None):
    """inside(x, y) → True si el píxel es de la forma; luz arriba-izquierda, sombra abajo-derecha"""
    base, light, dark = pal
    m = [[inside(x, y) for x in range(w)] for y in range(h)]
    im = Image.new('RGBA', (w + 2, h + 2))
    ins = lambda x, y: 0 <= x < w and 0 <= y < h and m[y][x]
    for y in range(h):
        for x in range(w):
            if m[y][x]:
                col = base
                if not ins(x, y - 1) or not ins(x - 1, y) or (not ins(x, y - 2) and x % 2 == 0):
                    col = light
                elif not ins(x, y + 1) or not ins(x + 1, y) or not ins(x + 2, y):
                    col = dark
                im.putpixel((x + 1, y + 1), col)
    for y in range(-1, h + 1):
        for x in range(-1, w + 1):
            if not ins(x, y) and any(ins(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                im.putpixel((x + 1, y + 1), OUT)
    if extra:
        extra(im)
    return im


def save_feat(name, im):
    im.save(FEAT + name + '.png')


GREEN = ((86, 170, 70, 255), (140, 214, 104, 255), (52, 120, 52, 255))
SAND = ((222, 190, 128, 255), (244, 224, 170, 255), (184, 146, 92, 255))
ROCK = {'grey': ((120, 120, 134, 255), (170, 170, 184, 255), (78, 78, 92, 255)),
        'dark': ((70, 70, 92, 255), (112, 110, 140, 255), (40, 40, 56, 255)),
        'red': ((128, 60, 52, 255), (176, 92, 70, 255), (84, 36, 36, 255)),
        'brown': ((140, 104, 70, 255), (184, 146, 100, 255), (96, 68, 46, 255))}

# colina redonda (pradera) con dos matas
def hill_extra(im):
    for x, y in ((5, 6), (6, 6), (11, 8), (12, 8)):
        im.putpixel((x, y), GREEN[2])
save_feat('hill', shape_img(18, 12, lambda x, y: ((x - 8.5) / 9) ** 2 + ((y - 12) / 12) ** 2 <= 1, GREEN, hill_extra))
# duna baja con su cresta
def dune_extra(im):
    for x in range(4, 16):
        y = 4 + int(abs(x - 9) * 0.35)
        im.putpixel((x, y), SAND[2])
save_feat('dune', shape_img(20, 7, lambda x, y: ((x - 9.5) / 10) ** 2 + ((y - 7) / 7) ** 2 <= 1, SAND, dune_extra))
# pico nevado: roca con capa de nieve de borde irregular
def peak_in(x, y):
    return abs(x - 9) <= (y + 1) * 0.55
def peak_extra(im):
    snow, snowl = (236, 242, 255, 255), (255, 255, 255, 255)
    for y in range(1, 19):
        for x in range(1, 19):
            p = im.getpixel((x, y))
            if p[3] and p != OUT and y <= 6 + ((x * 7) % 3):
                im.putpixel((x, y), snowl if x < 10 else snow)
save_feat('peak', shape_img(19, 18, peak_in, ROCK['grey'], peak_extra))
# aguja de roca (cuevas, fortaleza, volcán)
for nm, pal in (('spire', ROCK['dark']), ('spire_grey', ROCK['grey']), ('spire_red', ROCK['red'])):
    save_feat(nm, shape_img(9, 16, lambda x, y: abs(x - 4) <= 1 + y * 0.2 and not (y < 2 and x != 4), pal))
# rocas sueltas
for k, pal in ROCK.items():
    save_feat('rock_' + k, shape_img(10, 7, lambda x, y: ((x - 4.5) / 5) ** 2 + ((y - 6.5) / 6.5) ** 2 <= 1
                                     and not (x > 6 and y < 3), pal))
# boca de cueva: arco de roca con la entrada negra
def mouth_extra(im):
    for y in range(4, 13):
        for x in range(1, 16):
            if ((x - 8) / 3.6) ** 2 + ((y - 12.5) / 7.5) ** 2 <= 1:
                im.putpixel((x, y), (10, 8, 16, 255))
    for x in range(5, 12):
        if im.getpixel((x, 5))[3] and im.getpixel((x, 5)) == (10, 8, 16, 255):
            pass
save_feat('cave_mouth', shape_img(15, 12, lambda x, y: ((x - 7) / 7.5) ** 2 + ((y - 12) / 12) ** 2 <= 1, ROCK['dark'], mouth_extra))
print('  %s*.png' % FEAT)
