#!/usr/bin/env python3
# tools/art/story/make_overworld.py
# El MAPA DEL MUNDO del modo historia (estilo Super Mario World), como DATOS + unos pocos sprites:
#   assets/story/overworld.json   el terreno (una letra por casilla de 32 px), su ALTURA (0 hoyo, 1 llano,
#                                 2 meseta, 3 cumbre: el juego dibuja acantilados donde baja), el CAMINO de cada
#                                 mundo (curva suave: el juego reparte por ella los niveles del mundo, sean
#                                 cuantos sean, con el jefe al final, en su castillo), los puentes entre mundos,
#                                 las decoraciones / formaciones del terreno y los bichos que pasean
#   assets/images/story/          node-Sheet, castle-Sheet, water-Sheet, path.png, bridge.png, ground-Sheet,
#                                 edge-Sheet, foam.png y features/*.png (colinas, dunas, picos, agujas de roca,
#                                 rocas, bocas de cueva: el relieve de cada isla)
#   + la JUNGLA (próximamente): una isla más al SUR, entre la Costa y la Fortaleza, aún SIN niveles (no está en
#     Worlds.LIST): terreno, relieve, ruinas, bichos, castillo con su jefe y puentes CERRADOS; no es una parada.
#     Se genera al final con su propio azar: las 6 islas de la historia salen igual que antes (filas 0..H0-1)
# El terreno se pinta en el juego con las texturas de los BLOQUES del juego (césped, arena, nieve, piedra,
# roca, lava…) y las decoraciones / enemigos / jefes son sus sprites de siempre en pequeño.
# Reglas del relieve: los caminos van por el LLANO (valles entre mesetas; nada se levanta a menos de ~2
# casillas de un camino); las mesetas y cumbres tienen al menos 2x2 casillas; las cuevas tienen hoyos.
#   python3 tools/art/story/make_overworld.py        (determinista: misma semilla, mismo mapa)
import json, math, os, random
from PIL import Image

OUT_JSON = 'assets/story/overworld.json'
IMG = 'assets/images/story/'
FEAT = IMG + 'features/'
os.makedirs(FEAT, exist_ok=True)
W, H = 112, 63
W0 = 90                    # (el ancho de antes de la Costa Helada: los bucles con azar de las otras islas no pasan de
                           #  aquí, así crecer el mapa hacia el este no mueve ni una decoración de lo de antes)
H0 = 50                    # alto del mapa de las 6 islas de la historia (las cinemáticas encuadran esto: 'view');
                           # debajo, la jungla (próximamente). Los bucles con azar de las 6 islas van hasta H0, así
                           # crecer el mapa no mueve ni una decoración de lo de arriba
rng = random.Random(1987)

# ── Terreno ──────────────────────────────────────────────────────────────────
# '~' mar · g césped · s arena · w nieve · c roca de cueva · f piedra (fortaleza) · l roca volcánica · L lava
# · j suelo de la jungla (césped oscuro) · t piedra del templo (ruinas de la jungla)
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


# SEPARACIÓN de las islas (el usuario, 0.5.99: "parecen muy pegadas"): cada isla se desplaza entera — su tierra, su
# camino, su bonus, su relieve y sus bichos — con OFF[isla] (casillas); los puentes se estiran entre las dos
OFF = {'pradera': (0, 2), 'costa': (0, 0), 'fortaleza': (5, 0), 'nieve': (0, 0), 'cuevas': (0, -1), 'final': (0, 0)}


def off(k, pts):
    ox, oy = OFF.get(k, (0, 0))
    return [(x + ox, y + oy) for x, y in pts]


def stretch(a, b, pts):
    """un puente de la isla a a la b: cada punto se desplaza de OFF[a] a OFF[b] a lo largo del puente"""
    (ax, ay), (bx, by) = OFF.get(a, (0, 0)), OFF.get(b, (0, 0))
    n = max(1, len(pts) - 1)
    return [(x + ax + (bx - ax) * i / n, y + ay + (by - ay) * i / n) for i, (x, y) in enumerate(pts)]


def iblob(k, cx, cy, rx, ry, ch, jag=0.18):
    ox, oy = OFF.get(k, (0, 0))
    blob(cx + ox, cy + oy, rx, ry, ch, jag)


# Mundo 1, la Pradera (abajo a la izquierda) · 2, la Costa (abajo en medio) · 3, la Fortaleza (abajo a la derecha)
# 4, las Cumbres (arriba a la derecha) · 5, las Cuevas (arriba a la izquierda) · 6, el Final (el volcán, en medio)
iblob('pradera', 14, 35, 12, 9, 'g'); iblob('pradera', 8, 30, 6, 5, 'g')
blob(40, 39, 12, 7, 's'); blob(41, 38, 8, 5, 'g'); blob(48, 36, 5, 4, 'g')
iblob('fortaleza', 68, 36, 13, 9, 'f'); iblob('fortaleza', 76, 30, 5, 5, 'f')
blob(67, 12, 14, 9, 'w'); blob(58, 18, 6, 4, 'w')
iblob('cuevas', 18, 12, 12.5, 9, 'c'); iblob('cuevas', 10, 17, 6, 4, 'c')          # (algo más estrecha: lejos del volcán)
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
PATHS = {k: off(k, v) for k, v in PATHS.items()}
# Puentes entre mundos: del castillo de uno al primer nivel del siguiente (con puntos intermedios para que curven)
CONNECT = [
    stretch('pradera', 'costa', [(24, 31), (26, 34), (28.5, 36.5), (31, 38)]),
    stretch('costa', 'fortaleza', [(50, 38), (53, 39.5), (56, 39.5), (58, 38)]),
    stretch('fortaleza', 'nieve', [(77, 27), (79, 23.5), (78.5, 20), (76, 17)]),
    stretch('nieve', 'cuevas', [(73, 9), (68, 3.5), (58, 2.5), (45, 3), (35, 5), (29, 11)]),
    stretch('cuevas', 'final', [(23, 17), (27, 19.5), (32, 19.5), (36, 18)]),
]


# BONUS de cada mundo (arena contra el bot): un ramal corto desde el castillo hasta su nodo
BONUS = {'pradera': [(24, 31), (24, 27.5), (22, 24.5)], 'costa': [(50, 38), (52.5, 40), (52, 43)],
         'fortaleza': [(77, 27), (74.5, 25.5), (71.5, 26.5)], 'nieve': [(73, 9), (69.5, 6.5), (66, 5.5)],
         'cuevas': [(23, 17), (26, 18.5), (26.5, 21)], 'final': [(42, 14), (45, 13), (47.5, 14)]}
BONUS = {k: off(k, v) for k, v in BONUS.items()}


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


def open2x2(level, y0=0):
    """Quita lo que no forme al menos un bloque de 2x2 de esa altura (sin crestas de una casilla); solo desde la fila y0"""
    keep = [[False] * W for _ in range(H)]
    for y in range(H - 1):
        for x in range(W - 1):
            if all(hgt[y + dy][x + dx] >= level and land(x + dx, y + dy) for dx in (0, 1) for dy in (0, 1)):
                for dx in (0, 1):
                    for dy in (0, 1):
                        keep[y + dy][x + dx] = True
    for y in range(y0, H):
        for x in range(W):
            if hgt[y][x] >= level and not keep[y][x]:
                hgt[y][x] = level - 1


def lower_pits(cx, cy, rx, ry, chars, clear):
    for y in range(H):
        for x in range(W):
            if wobbly(x, y, cx, cy, rx, ry, 0.2) and grid[y][x] in chars and interior(x, y) \
                    and dist[y][x] >= clear and hgt[y][x] == 1:
                hgt[y][x] = 0


# (x, y, rx, ry, altura, terrenos, distancia mínima al camino); cada grupo, con el desplazamiento de su isla
RELIEF = [
    'pradera',
    # Pradera: lomas y una colina alta; el camino va por los valles
    (10, 34, 3, 2.6, 2, 'g', 2), (13, 44, 4.5, 2.2, 2, 'g', 2), (5, 40, 3, 2.4, 2, 'g', 2), (17, 32, 2.6, 2.4, 2, 'g', 1.8),
    (11, 26, 3.5, 2.2, 2, 'g', 2), (4, 33, 2.5, 2.5, 2, 'g', 2), (21, 42, 3, 1.8, 2, 'g', 2), (13, 34, 1.8, 1.6, 3, 'g', 2.6),
    (5, 27, 3, 2, 2, 'g', 2),
    'costa',
    # Costa: mesetas de hierba con acantilados de tierra; dunas en la arena
    (38, 39, 3, 2.6, 2, 'gs', 2), (45, 43, 3.5, 1.8, 2, 'gs', 2), (37, 33, 2.8, 1.8, 2, 'gs', 1.8), (44, 37, 2, 1.5, 2, 'g', 1.8),
    (38, 39, 1.6, 1.4, 3, 'g', 2.6),
    'fortaleza',
    # Fortaleza: terrazas de piedra a varias alturas
    (66, 38, 4, 4, 2, 'f', 2), (66, 38, 2.4, 2.4, 3, 'f', 2.6), (76, 35, 3.5, 4.5, 2, 'f', 2), (76, 35, 2, 2.6, 3, 'f', 2.6),
    (63, 31, 3.5, 2.4, 2, 'f', 2), (71, 44, 3.5, 1.8, 2, 'f', 2), (58, 43, 3, 2, 2, 'f', 1.8), (79, 41, 2, 2.5, 2, 'f', 2),
    'nieve',
    # Cumbres: una cordillera (mesetas grandes con cumbres)
    (68, 11, 6, 4, 2, 'w', 1.8), (68, 11, 4, 2.6, 3, 'w', 2.4), (59, 14, 3.5, 3.5, 2, 'w', 1.8), (59, 14, 2.2, 2.2, 3, 'w', 2.4),
    (74, 14, 3.5, 2.6, 2, 'w', 1.8), (64, 19, 4.5, 1.8, 2, 'w', 1.8), (77, 8, 3.5, 3, 2, 'w', 1.8), (77, 8, 2, 1.8, 3, 'w', 2.4),
    (62, 5, 3, 2, 2, 'w', 1.8), (79, 15, 2, 2.4, 2, 'w', 1.8),
    'cuevas',
    # Cuevas: terreno muy quebrado (terrazas a tres alturas, pegadas unas a otras)
    (19, 11, 4.5, 3.4, 2, 'c', 1.8), (19, 11, 3, 2.2, 3, 'c', 2.4), (10, 11, 3.5, 2.4, 2, 'c', 1.8), (27, 14, 3.2, 2.4, 2, 'c', 1.8),
    (14, 19, 4, 2.4, 2, 'c', 1.8), (23, 4, 4.5, 1.8, 2, 'c', 1.8), (31, 8, 2.4, 3.4, 2, 'c', 1.8), (6, 20, 3.4, 2.4, 2, 'c', 1.8),
    (6, 13, 2.4, 2.4, 2, 'c', 1.8), (14, 4, 3, 1.6, 2, 'c', 1.8), (27, 14, 1.8, 1.4, 3, 'c', 2.4), (10, 11, 1.8, 1.4, 3, 'c', 2.4),
    'final',
    # Volcán: el cono alrededor del cráter y coladas
    (41, 18, 3.6, 3.4, 2, 'l', 1.8), (41, 18, 2.6, 2.4, 3, 'l', 2.2), (38, 23, 2.4, 1.8, 2, 'l', 1.8), (48, 21, 2, 2.4, 2, 'l', 1.8),
    (44, 25, 2.5, 1.5, 2, 'l', 1.8),
]
isle = None
for e in RELIEF:
    if isinstance(e, str):
        isle = e
        continue
    cx, cy, rx, ry, lv, ch, clear = e
    raise_blob(cx + OFF[isle][0], cy + OFF[isle][1], rx, ry, lv, ch, clear)
open2x2(3)
open2x2(2)
# hoyos de las cuevas (simas): bajo el llano, con su pared
for cx, cy, rx, ry in [(13, 13, 1.6, 1.2), (24, 11, 1.5, 1.4), (9, 7, 1.5, 1.2), (19, 18, 1.4, 1.1), (27, 4, 1.4, 1)]:
    lower_pits(cx + OFF['cuevas'][0], cy + OFF['cuevas'][1], rx, ry, 'c', 2.2)
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
for y in range(2, H0 - 2):
    for x in range(2, W0 - 2):
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
for y in range(3, H0 - 2):
    for x in range(3, W0 - 3):
        if grid[y][x] == 'c' and h(x, y - 1) > h(x, y) >= 1 and h(x - 1, y - 1) > h(x, y) and h(x + 1, y - 1) > h(x, y) \
                and dist[y][x] >= 1.4 and (x, y) not in taken and rng.random() < 0.5 and mouths < 9:
            diff = min(2, h(x, y - 1) - h(x, y))
            decos.append({'t': 'cave_mouth', 'x': x, 'y': y, 'oy': round(0.75 * diff, 2)})
            taken.add((x, y))
            mouths += 1

# ── Bichos que pasean (de un lado a otro por el MISMO llano; peces en el agua) ─
# (el TIPO sale de la ISLA donde caen — `critter_type` —: cada isla enseña SUS Gummies, Crabbies y Saltarines, como
# en los niveles; en las cuevas, además del Crabby de cueva, el lúgubre)
CRITTERS = [
    'pradera',
    ('gummy', 6, 11, 41), ('crabby', 17, 22, 36), ('gummy', 9, 14, 28), ('crabby', 3, 7, 35), ('hopper', 12, 17, 32), ('hopper', 5, 10, 38),
    'costa',
    ('crabby', 33, 38, 36), ('gummy', 43, 47, 41), ('hopper', 36, 41, 43), ('crabby', 30, 34, 39),
    ('puffer', 28, 33, 44), ('puffer', 50, 55, 44),
    'fortaleza',
    ('bomb', 60, 65, 35), ('crabby', 70, 75, 41), ('bomb', 64, 69, 30), ('gummy', 62, 67, 38), ('hopper', 72, 77, 33),
    'nieve',
    ('crabby', 62, 67, 14), ('gummy', 69, 74, 15), ('crabby', 56, 60, 19), ('hopper', 60, 65, 9),
    'cuevas',
    ('gloomy', 12, 17, 12), ('gloomy', 21, 26, 9), ('gloomy', 8, 11, 18), ('crabby', 14, 19, 7), ('gummy', 22, 27, 14), ('hopper', 10, 15, 15),
    'final',
    ('gummy', 39, 44, 14), ('crabby', 40, 45, 21), ('hopper', 37, 42, 23),
    ('puffer', 36, 41, 8), ('puffer', 52, 57, 26),
]
ISLE_OF = {'w': 'nieve', 'c': 'cueva', 'f': 'fortaleza', 'l': 'volcan', 'j': 'jungla', 't': 'jungla', 'i': 'costa_helada'}
ISLE_TYPES = {
    'pradera':   {'crabby': 'crabby_river', 'hopper': 'hopper_pradera'},
    'costa':     {'hopper': 'hopper_costa'},
    'fortaleza': {'gummy': 'gummy_fortress', 'crabby': 'crabby_fortress', 'hopper': 'hopper_fortaleza'},
    'nieve':     {'gummy': 'gummy_ice', 'crabby': 'crabby_ice', 'hopper': 'hopper_nieve'},
    'cueva':     {'gummy': 'gummy_cave', 'crabby': 'crabby_cave', 'hopper': 'hopper_cueva'},
    'volcan':    {'gummy': 'gummy_magma', 'crabby': 'crabby_lava', 'hopper': 'hopper_volcan'},
    'jungla':    {'gummy': 'gummy_jungle', 'crabby': 'crabby_jungle', 'hopper': 'hopper_jungla'},   # (+ 'beetle': el suyo)
    'costa_helada': {'gummy': 'gummy_ice', 'crabby': 'crabby_ice', 'hopper': 'hopper_nieve'},
}


def critter_type(t, x, y):
    isle = ISLE_OF.get(grid[y][x]) or ('pradera' if x <= 26 else 'costa')      # (hierba y arena: pradera al oeste, costa al este)
    return ISLE_TYPES[isle].get(t, t)


def place_critter(t, x0, x1, y):
    if t == 'puffer':      # (coordenadas a mano: el juego los lleva al mar abierto más cercano — StoryMapState loadMap)
        return {'t': t, 'x0': x0, 'x1': x1, 'y': y}
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
        return {'t': critter_type(t, best[0], y), 'x0': best[0], 'x1': best[-1], 'y': y}
    print('  (bicho sin sitio: %s %d-%d fila %d)' % (t, x0, x1, y))
    return None


critters = []
for a in CRITTERS:
    if isinstance(a, str):
        isle = a
        continue
    t, x0, x1, y = a
    ox, oy = OFF[isle]
    c = place_critter(t, x0 + ox, x1 + ox, y + oy)
    if c:
        critters.append(c)

# El jefe de cada mundo, en pequeño junto a su castillo (sus sprites del juego; fw = ancho de cuadro)
BOSS_ART = {
    'pradera':   {'img': 'assets/images/bosses/megagummy/body-Sheet.png', 'fw': 16, 'over': 'assets/images/bosses/megagummy/crown.png', 'overBig': True},
    'costa':     {'img': 'assets/images/bosses/megacrabby/crab1.png'},
    'fortaleza': {'img': 'assets/images/bosses/miniboss1/ship.png', 'fly': True, 'under': 'assets/images/bosses/miniboss1/monster/Idle1.png'},
    'nieve':     {'img': 'assets/images/bosses/snowboss/body-Sheet.png', 'fw': 16},          # (la Gran Bola de Nieve)
    'cuevas':    {'img': 'assets/images/bosses/megagloomy/body-Sheet.png', 'fw': 38, 'glow': 'assets/images/bosses/megagloomy/glow-Sheet.png'},
    'final':     {'img': 'assets/images/bosses/mirror/Body_ArmsDown.png', 'over': 'assets/images/bosses/mirror/Head_Down.png', 'invert': True},
}

# Jefes de MITAD de isla (un nivel normal con jefe: no tiene castillo): se dibujan junto a SU nodo
NODE_BOSS = {                # (hoy ninguno: la Bola de Nieve tiene castillo desde que las Montañas Heladas son su isla)
}

# ── La ISLA DEL GROOVE (el nivel secreto de después del juego: Worlds `secret`): un islote de arena al noreste del
# volcán, siempre a la vista (un misterio); su camino desde el bonus del Final y su nodo solo aparecen al vencer al
# Espejo (StoryMapState). Se añade AL FINAL, después de decoraciones y bichos, para no mover nada de lo demás (rng).
# El camino cruza el agua: se dibuja como puente.
# (su camino: SECRETS, al final del todo, con los demás secretos)
blob(48.8, 8.1, 3.0, 2.4, 's', 0.1)
decos.append({'t': 'palm', 'x': 49, 'y': 6})

# ── LA JUNGLA (PRÓXIMAMENTE): la isla de después de la Costa, aún SIN niveles ─────────────────────────────────
# Al SUR, entre la Costa y la Fortaleza (el mapa creció hacia abajo: H0 → H). NO está en Worlds.LIST (el progreso y
# las partidas cuentan los mundos por su posición): en el mapa es solo DATOS + ARTE (`soon` en overworld.json): su
# terreno, relieve, ruinas, árboles, bichos, el castillo con el Escarabajo Gigante, un camino con paradas de
# muestra (cerradas, no son paradas: no se puede ir) y dos puentes CERRADOS: desde el castillo de la Costa (por el
# canal entre la Costa y su bonus) y hasta el primer nivel de la Fortaleza (por el canal de la Fortaleza). El
# puente de siempre Costa → Fortaleza sigue igual. Con su azar propio y al final: lo de arriba no se mueve.
jrng = random.Random(2027)
old_land = [(x, y) for y in range(H) for x in range(W) if grid[y][x] != '~']


def blob_sea(cx, cy, rx, ry, ch, jag=0.18, gap=2.6):
    """Como blob(), pero solo sobre el MAR y sin acercarse a menos de `gap` casillas de la tierra de antes"""
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            ang = math.atan2(dy, dx)
            wob = 1 + jag * (math.sin(ang * 5 + cx) * 0.6 + math.sin(ang * 9 + cy) * 0.4)
            if grid[y][x] == '~' and dx * dx + dy * dy <= wob * wob \
                    and all(math.hypot(x - ox, y - oy) >= gap for ox, oy in old_land if abs(ox - x) < 4 and abs(oy - y) < 4):
                grid[y][x] = ch


blob_sea(55, 54.6, 12.5, 5.2, 'j'); blob_sea(44.5, 53.8, 4.6, 3.6, 'j'); blob_sea(66, 54.2, 4.8, 4.2, 'j')
JPATH = [(49, 50.5), (44.5, 53.5), (47.5, 57.6), (54, 57.8), (58.5, 54.6), (62.5, 57.2), (65, 52)]
# (0.5.99: ya es el MUNDO 3 de Worlds.LIST; sus paradas son las de Worlds.lua: 4 niveles + el castillo)
# Puentes: castillo de la Costa → primer nivel de la jungla · castillo de la jungla → primer nivel de la Fortaleza
JBRIDGES = [
    [(50, 38), (50.2, 41.5), (50.4, 45), (49.6, 48.2), (49, 50.5)],
    stretch('jungla', 'fortaleza', [(65, 52), (62.2, 48.6), (58.2, 45.6), (56.4, 42.4), (57, 40), (58, 38)]),
]
# su BONUS (El Claro de la Balanza): un ramal corto desde el castillo hacia el este, sobre el islote del templo
JBONUS = [(65, 52), (67.4, 53.2), (69.2, 55.4)]
SJPATH = catmull(JPATH)
SJBRIDGES = [catmull(b) for b in JBRIDGES]
SJBONUS = catmull(JBONUS)
JLINES = [SJPATH] + SJBRIDGES + [SJBONUS]
# bajo el camino, tierra; alrededor del castillo, la plaza de piedra del templo
for y in range(H0, H):
    for x in range(W):
        dd = min(seg_dist(x + 0.5, y + 0.5, l[i], l[i + 1]) for l in (SJPATH, SJBONUS) for i in range(len(l) - 1))
        if grid[y][x] == '~' and dd < 1.3:
            grid[y][x] = 'j'
        if grid[y][x] == 'j' and wobbly(x, y, 65, 52, 2.4, 1.9, 0.2):
            grid[y][x] = 't'
# la distancia a los caminos ya cuenta también los de la jungla (lo de arriba ya está hecho: no cambia nada)
for y in range(H):
    for x in range(W):
        dist[y][x] = min(dist[y][x], min(seg_dist(x + 0.5, y + 0.5, l[i], l[i + 1]) for l in JLINES for i in range(len(l) - 1)))
# relieve: la meseta del templo (dentro de la vuelta del camino), lomas de selva al oeste y al sur
for cx, cy, rx, ry, lv, ch, clear in [
        (54, 52.2, 4.2, 2.2, 2, 'j', 1.8), (54.5, 52, 2.2, 1.4, 3, 'j', 2.2), (43.4, 55.6, 2.4, 2.4, 2, 'j', 1.8),
        (68.4, 54.6, 2.6, 2.6, 2, 'j', 1.8), (59.6, 50.6, 2.4, 1.6, 2, 'j', 1.8), (50.6, 59.6, 3.2, 1.4, 2, 'j', 1.8)]:
    raise_blob(cx, cy, rx, ry, lv, ch, clear)
open2x2(3, H0)             # (solo la jungla: arriba, el cráter del volcán ya rompió bloques a propósito)
open2x2(2, H0)
# landmarks a mano: el ZIGURAT en lo alto de la meseta y ruinas sueltas
jdecos = [{'t': 'ziggurat', 'x': 54, 'y': 52}]
# (el sitio del cartel de cuando era PRÓXIMAMENTE: sin nada encima)
jtaken = {(x, y) for x in range(52, 57) for y in range(50, 54)} | {(x, y) for x in range(51, 59) for y in range(55, 57)}
JDECOS = {'j': ['jungle_fern', 'heliconia', 'banana_plant', 'elephant_ear', 'tree_fern', 'bromeliad', 'jungle_fern'],
          't': ['stone_brazier', 'broken_pillar', 'stone_idol']}
JFEATURES = {('j', 1): ['jungle_tree'] * 6 + ['ruin'], ('j', 2): ['jungle_tree', 'jungle_tree', 'ruin'],
             ('j', 3): ['jungle_tree'], ('t', 1): ['ruin']}
for y in range(H0, H - 1):
    for x in range(2, W - 2):
        ch = grid[y][x]
        if ch not in JDECOS or dist[y][x] < 1.6 or (x, y) in jtaken:
            continue
        if h(x, y - 1) > h(x, y) or h(x, y + 1) != h(x, y):
            continue
        if any((x + dx, y + dy) in jtaken for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            continue
        feats = JFEATURES.get((ch, hgt[y][x]))
        roll = jrng.random()
        if feats and roll < 0.55:                      # (selva densa: muchos árboles)
            jtaken.add((x, y))
            jdecos.append({'t': jrng.choice(feats), 'x': x, 'y': y})
        elif roll < 0.7:
            jtaken.add((x, y))
            jdecos.append({'t': jrng.choice(JDECOS[ch]), 'x': x, 'y': y})
decos += jdecos
# bichos de la jungla: la rana (Gummy de la selva), el Crabby de la selva, el Escarabajo Rinoceronte azul, su Saltarín
JCRITTERS = [('gummy', 45, 50, 55), ('beetle', 58, 63, 52), ('crabby', 60, 65, 55), ('hopper', 46, 52, 59),
             ('beetle', 41, 46, 52), ('gummy', 64, 69, 57), ('puffer', 37, 42, 52), ('puffer', 68, 73, 50)]
for t, x0, x1, y in JCRITTERS:
    c = place_critter(t, x0, x1, y)
    if c:
        critters.append(c)
# La jungla entra en el mapa como el MUNDO 3 (tras la Costa): sus datos, y los puentes Costa → jungla → Fortaleza en
# vez del de siempre Costa → Fortaleza (que sigue contando arriba para la distancia a los caminos: no mueve nada)
SPATHS['jungla'], SBONUS['jungla'] = SJPATH, SJBONUS
BOSS_ART['jungla'] = {'img': 'assets/images/bosses/giantbeetle/body-Sheet.png', 'fw': 22}

# ── LA COSTA HELADA (el usuario, 0.5.100: la isla helada se parte en dos — las Montañas Heladas, la de siempre, con la
# Gran Bola de Nieve, y esta, la del Mega Crabby helado): al ESTE de las Montañas (el mapa creció hacia el este:
# W0 → W), llana, de hielo (`i`), con su camino, su castillo al noroeste y su bonus. Puentes: castillo de las Montañas
# → primer nivel de aquí · castillo de aquí → primer nivel de las Cuevas (por el norte, sobre el mar, como el de
# antes). Con su azar propio y al final: lo de antes no se mueve.
crng = random.Random(2031)
old_land = [(x, y) for y in range(H) for x in range(W) if grid[y][x] != '~']
blob_sea(97.5, 13.5, 9.5, 8, 'i'); blob_sea(90.5, 18.5, 4, 3.2, 'i'); blob_sea(104, 18, 4, 3.6, 'i')
CPATH = [(89, 13), (91.5, 18.5), (97.5, 20.5), (103, 17), (102.5, 10.5), (97, 7.5), (93, 6.5)]
CBONUS = [(93, 6.5), (97, 4.6), (100.5, 5.2)]
CBRIDGES = [
    [(73, 9), (77.5, 6.5), (82, 7), (86, 10), (89, 13)],                                                 # Montañas → aquí
    [(93, 6.5), (91, 2.6), (84, 0.9), (70, 0.8), (56, 1), (44, 1.6), (35, 4.4), (29, 10)],              # aquí → Cuevas
]
SCPATH, SCBONUS = catmull(CPATH), catmull(CBONUS)
SCBRIDGES = [catmull(b) for b in CBRIDGES]
for y in range(H):
    for x in range(W0 - 4, W):
        dd = min(seg_dist(x + 0.5, y + 0.5, l[i], l[i + 1]) for l in (SCPATH, SCBONUS) for i in range(len(l) - 1))
        if grid[y][x] == '~' and dd < 1.3:
            grid[y][x] = 'i'
for y in range(H):
    for x in range(W):
        dist[y][x] = min(dist[y][x], min(seg_dist(x + 0.5, y + 0.5, l[i], l[i + 1]) for l in [SCPATH, SCBONUS] + SCBRIDGES
                                         for i in range(len(l) - 1)))
# relieve: dos bancos de hielo (la costa es llana)
for cx, cy, rx, ry, lv in [(98, 14.5, 3.4, 2.2, 2), (104.5, 18.5, 2, 1.6, 2), (95, 18, 2.2, 1.4, 2)]:
    raise_blob(cx, cy, rx, ry, lv, 'i', 1.8)
open2x2(2)
CDECOS = ['snow_pile', 'snow_pile', 'frozen_bush', 'snowman']
ctaken = set()
cdecos = []
for y in range(2, H0 - 2):
    for x in range(W0 - 4, W - 2):
        if grid[y][x] != 'i' or dist[y][x] < 1.6 or (x, y) in ctaken:
            continue
        if h(x, y - 1) > h(x, y) or h(x, y + 1) != h(x, y):
            continue
        if any((x + dx, y + dy) in ctaken for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            continue
        roll = crng.random()
        if hgt[y][x] > 1 and roll < 0.3:
            ctaken.add((x, y))
            cdecos.append({'t': 'rock_grey', 'x': x, 'y': y})
        elif roll < 0.22:
            ctaken.add((x, y))
            cdecos.append({'t': crng.choice(CDECOS), 'x': x, 'y': y})
decos += cdecos
for t, x0, x1, y in [('crabby', 92, 97, 16), ('crabby', 99, 104, 13), ('gummy', 96, 101, 18), ('hopper', 100, 105, 9),
                     ('puffer', 107, 111, 10), ('puffer', 86, 90, 23)]:
    c = place_critter(t, x0, x1, y)
    if c:
        critters.append(c)
SPATHS['costa_helada'], SBONUS['costa_helada'] = SCPATH, SCBONUS
BOSS_ART['costa_helada'] = {'img': 'assets/images/bosses/megacrabby_ice/crab1.png'}

# ── LOS SECRETOS (Worlds `secrets`, docs/story/world-map.md#the-secret-nodes): un camino corto desde su nodo `from` hasta un
# nodo ROJO con cerradura, que no existe en el mapa hasta que se abre (StoryMapState). El juego reparte los niveles de cada
# mundo por su camino por longitud de arco: aquí se calcula igual dónde cae el nodo `from` (`(k, n)` = su nodo k de n,
# = Worlds.lua: si allí cambia, cambia esto). Va AL FINAL, después de todas las decoraciones y bichos y sin azar: bajo el
# camino y en su islote se pone tierra donde había mar y se quitan las pocas decoraciones que pisa; nada más se mueve.
#   (level, mundo, desde: (k, n) de su camino | 'bonus' | otro secreto, puntos intermedios, fin, islote (cx, cy, rx, ry) | None, tierra)
def node_at(path, k, n):
    acc = [0.0]
    for i in range(1, len(path)):
        acc.append(acc[-1] + math.dist(path[i - 1], path[i]))
    sv = acc[-1] * (k - 1) / max(1, n - 1)
    for i in range(1, len(path)):
        if sv <= acc[i] or i == len(path) - 1:
            q = max(0.0, min(1.0, (sv - acc[i - 1]) / max(1e-9, acc[i] - acc[i - 1])))
            return (round(path[i - 1][0] + (path[i][0] - path[i - 1][0]) * q, 2), round(path[i - 1][1] + (path[i][1] - path[i - 1][1]) * q, 2))


SECRETS = [
    # la GUARIDA del Mega Crabby: una lengua de arena al norte del Arrecife Globo (nodo 4 de 5 de la Costa) hasta su islote
    ('guarida_cangrejo_rey', 'costa', (4, 5), [(44.5, 32.0)], (45.3, 29.9), (45.5, 29.6, 1.9, 1.5), 's'),
    # la GRUTA del Mega Crabby lúgubre: al oeste del Templo del Eco (nodo 4 de 5 de las Cuevas), por el llano
    ('gruta_lugubre', 'cuevas', (4, 5), [(10.4, 15.1)], (7.3, 15.6), None, 'c'),
    # el GROOVE: del bonus del Final a su islote de arena al noreste del volcán (el de siempre)
    ('isla_del_groove', 'final', 'bonus', [(48.3, 11.4)], (48.6, 8.9), (48.8, 8.1, 3.0, 2.4), 's'),
    # el MEGA MASHUP (el final de verdad): del Groove, por su islote, un poco más al este
    ('mashup_cangrejos', 'final', 'isla_del_groove', [(49.9, 8.7)], (50.8, 7.6), (50.7, 7.7, 1.7, 1.5), 's'),
]
SSECRET, SECRET_END = {}, {}
for lvl, wk, frm, mid, end, isle, ch in SECRETS:
    if frm == 'bonus':
        start = SBONUS[wk][-1]
    elif isinstance(frm, str):
        start = SECRET_END[frm]
    else:
        start = node_at(SPATHS[wk], frm[0], frm[1])
    SSECRET[lvl] = catmull([start] + mid + [end])
    SECRET_END[lvl] = end
    if isle:
        blob(isle[0], isle[1], isle[2], isle[3], ch, 0.1)
    # (tierra bajo el camino: que no cruce el mar)
    for y in range(H):
        for x in range(W):
            if grid[y][x] == '~' and min(seg_dist(x, y, a, b) for a, b in zip(SSECRET[lvl], SSECRET[lvl][1:])) < 0.95:
                grid[y][x] = ch
                hgt[y][x] = 1
            if grid[y][x] != '~' and min(seg_dist(x, y, a, b) for a, b in zip(SSECRET[lvl], SSECRET[lvl][1:])) < 1.6:
                hgt[y][x] = min(hgt[y][x], 1)          # (por el llano)
decos = [d for d in decos if all(min(seg_dist(d['x'], d['y'], a, b) for a, b in zip(l, l[1:])) >= 1.0 for l in SSECRET.values())
         and all(math.dist((d['x'], d['y']), e) >= 1.4 for e in SECRET_END.values())]
SECRET_OF = {lvl: wk for lvl, wk, *_ in SECRETS}

STORY = ['pradera', 'costa', 'jungla', 'fortaleza', 'nieve', 'costa_helada', 'cuevas', 'final']        # (= Worlds.LIST)
SCONNECT_OUT = [SCONNECT[0], SJBRIDGES[0], SJBRIDGES[1], SCONNECT[2], SCBRIDGES[0], SCBRIDGES[1], SCONNECT[4]]


# ── CAÑONES entre islas (el usuario, 2026-10-29: "para cambiar de isla se usa un puente; estaba pensando en usar un
# cañón… se vería mejor y quedaría más cómico"): en vez de los puentes, un cañón en CADA punta de cada cruce (el de
# ida y el de vuelta). Sale de los mismos cruces (SCONNECT_OUT, que siguen contando para la distancia a los caminos:
# nada se mueve): cada cañón, en tierra junto a la orilla por la que el cruce salía al mar, sin pisar caminos,
# decoraciones ni el castillo con su jefe; `la` / `lb` = dónde aterriza el monstruo al llegar a esa punta (entre el
# cañón y el nodo). Va DESPUÉS de todo lo demás y sin azar: no cambia nada del mapa. Una isla nueva = un cruce más.
# (coordenadas como las de los caminos: el punto q cae en la casilla floor(q + 0.5), como lo dibuja el juego)
def cell_at(x, y):
    cx, cy = math.floor(x + 0.5), math.floor(y + 0.5)
    if 0 <= cx < W and 0 <= cy < H:
        return grid[cy][cx], hgt[cy][cx]
    return '~', 0


def boss_spot(n):
    """dónde pone el juego al jefe junto a su castillo (StoryMapState bossSide), en casillas"""
    for ox, oy in ((58, 0), (-58, 0), (40, 40), (-40, 40), (0, 52)):
        bx, by = n[0] + ox / 32, n[1] + (12 + oy) / 32
        if all(cell_at(bx + d / 32, by)[0] not in '~L' for d in (-14, 0, 14)):
            return bx, by
    return n[0] + 58 / 32, n[1] + 12 / 32


def cannon_end(line, castle, avoid):
    """el cañón de la punta de `line` que empieza en su nodo (line[0]): junto a la orilla por la que sale al mar"""
    node = line[0]
    acc = [0.0]
    for i in range(1, len(line)):
        acc.append(acc[-1] + math.dist(line[i - 1], line[i]))

    def at(s):
        for i in range(1, len(line)):
            if s <= acc[i] or i == len(line) - 1:
                q = max(0.0, min(1.0, (s - acc[i - 1]) / max(1e-9, acc[i] - acc[i - 1])))
                return (line[i - 1][0] + (line[i][0] - line[i - 1][0]) * q, line[i - 1][1] + (line[i][1] - line[i - 1][1]) * q)
    shore, s = node, 0.0
    while s < acc[-1]:
        p = at(s)
        if cell_at(*p)[0] == '~':
            break
        shore, s = p, s + 0.05
    far = at(min(acc[-1], s + 3.0))                    # (hacia dónde sigue el cruce, ya en el mar)
    keep = 1.7 if castle else 1.25                     # (lejos del castillo / del nodo)
    boss = boss_spot(node) if castle else None
    best = None
    for iy in range(-10, 11):
        for ix in range(-10, 11):
            x, y = node[0] + ix * 0.5, node[1] + iy * 0.5
            if math.dist((x, y), node) < keep or math.dist((x, y), node) > 5:
                continue
            ch, hh = cell_at(x, y)
            if ch in '~L' or any(cell_at(x + dx, y)[0] in '~L' or cell_at(x + dx, y)[1] != hh for dx in (-0.7, 0.7)):
                continue
            if cell_at(x, y - 0.8)[0] in '~L' or cell_at(x, y - 0.8)[1] > hh:   # (nada más alto detrás)
                continue
            if boss and abs(x - boss[0]) < 1.6 and -1.6 < y - boss[1] < 0.8:
                continue
            if any(math.dist((x, y), (d['x'], d['y'])) < 1.3 for d in decos):
                continue
            if any(min(seg_dist(x, y, l[i], l[i + 1]) for i in range(len(l) - 1)) < 0.9 for l in avoid):
                continue
            # el camino del nodo al cañón, todo por tierra
            if any(cell_at(node[0] + (x - node[0]) * k / 8, node[1] + (y - node[1]) * k / 8)[0] in '~L' for k in range(9)):
                continue
            score = math.dist((x, y), shore) + 0.25 * math.dist((x, y), node) + 0.15 * math.dist((x, y), far)
            if not best or score < best[0]:
                best = (score, x, y)
    if not best:
        raise SystemExit('cañón: no hay sitio junto al nodo %s' % (node,))
    x, y = best[1], best[2]
    k = min(1.0, 0.5 * math.dist((x, y), node)) / max(1e-9, math.dist((x, y), node))
    land_ = (x + (node[0] - x) * k, y + (node[1] - y) * k)      # (aterriza a una casilla del cañón, hacia el nodo)
    return [round(x, 2), round(y, 2)], [round(land_[0], 2), round(land_[1], 2)]


AVOID = [SPATHS[k] for k in STORY] + [SBONUS[k] for k in STORY] + list(SSECRET.values())
CANNONS = []
for c in SCONNECT_OUT:
    a, la = cannon_end(c, True, AVOID)
    b, lb = cannon_end(c[::-1], False, AVOID)
    CANNONS.append({'a': a, 'la': la, 'b': b, 'lb': lb})
print('  cañones: %d cruces' % len(CANNONS))

data = {
    'cell': 32, 'w': W, 'h': H,
    'rows': [''.join(r) for r in grid],
    'heights': [''.join(str(v) for v in r) for r in hgt],
    'worlds': [{'id': k, 'path': [list(p) for p in SPATHS[k]], 'boss': BOSS_ART[k], 'nodeBoss': NODE_BOSS.get(k, {}), 'bonus': [list(p) for p in SBONUS[k]],
                'secrets': {lvl: [list(p) for p in SSECRET[lvl]] for lvl in SSECRET if SECRET_OF[lvl] == k}} for k in STORY],
    'connect': [[list(p) for p in c] for c in SCONNECT_OUT],
    'cannons': CANNONS,           # (un cañón en cada punta de cada cruce; el juego ya no dibuja los puentes)
    'decos': decos, 'critters': critters,
    'view': [W, H],               # (lo que encuadran las cinemáticas: las 7 islas, la jungla abajo)
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
# el nodo SECRETO (Worlds `secrets`): más grande, con una CERRADURA (la de la salida secreta de los niveles):
# 1 abierto (rojo) · 2 superado (dorado)
NODE_SECRET = ['...oooo...', '..oaaaao..', '.oabbbbao.', 'oabbkkbbao', 'oabkkkkbao', 'oabbkkbbao', 'oacbkkbcao',
               '.oaccccao.', '..oaaaao..', '...oooo...']
sheet([grid_img(NODE_SECRET, dict(p, k=(24, 10, 14, 255))) for p in (node_pals[1], node_pals[2])], IMG + 'node_secret-Sheet.png')

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


T = 'assets/images/world/tiles/'
g0 = tone(T + 'grass.png', 30, 2)
# (base, oscuro, claro) de cada terreno, de los colores de su bloque del juego
TERR = [
    (g0, (g0[0] - 30, g0[1] - 40, g0[2] - 20, 255), (min(255, g0[0] + 40), min(255, g0[1] + 30), g0[2] + 20, 255)),   # g
    (tone(T + 'sand.png', 30, 30), (196, 160, 104, 255), (240, 222, 170, 255)),                                       # s
    (tone(T + 'snow.png', 30, 20), (196, 214, 240, 255), (255, 255, 255, 255)),                                       # w
    (tone(T + 'border.png', 60, 60), (26, 26, 34, 255), (80, 78, 100, 255)),                                          # c
    (tone(T + 'stone.png', 60, 60), (52, 52, 62, 255), (110, 110, 124, 255)),                                         # f
    (tone(T + 'deep_stone.png', 60, 60), (60, 30, 34, 255), (140, 66, 50, 255)),                                      # l
    ((47, 122, 58, 255), (29, 74, 42, 255), (95, 176, 74, 255)),                                                       # j (jungle_grass)
    ((95, 110, 88, 255), (62, 74, 60, 255), (138, 154, 124, 255)),                                                     # t (temple_brick)
    (tone(T + 'ice.png', 30, 30), (120, 176, 214, 255), (226, 246, 255, 255)),                                        # i (ice: la Costa Helada)
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

# ── La JUNGLA: árbol de la selva (copa redonda sobre su tronco), el ZIGURAT del templo y ruinas ─────────────
JGREEN = ((47, 122, 58, 255), (95, 176, 74, 255), (29, 74, 42, 255))
TEMPLE = ((95, 110, 88, 255), (138, 154, 124, 255), (62, 74, 60, 255))
MOSS = ((79, 122, 38, 255), (134, 176, 60, 255))
TRUNK = ((110, 76, 46, 255), (146, 104, 64, 255), (74, 50, 30, 255))


def over(a, b):
    """b encima de a (mismo tamaño)"""
    out = a.copy()
    out.alpha_composite(b)
    return out


# árbol: tronco corto y copa grande de tres bultos (con brillos arriba a la izquierda)
def canopy_in(x, y):
    return any(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1
               for cx, cy, rx, ry in ((7.5, 6.5, 7.5, 5.5), (4, 8, 4, 3.5), (11, 8, 4, 3.5), (7.5, 3, 4.5, 3)))
def canopy_extra(im):
    for x, y in ((5, 4), (6, 4), (10, 6), (3, 8), (12, 9)):
        im.putpixel((x, y), JGREEN[1])
    for x, y in ((7, 10), (8, 10), (4, 11), (11, 11)):
        im.putpixel((x, y), JGREEN[2])
tree_trunk = shape_img(16, 17, lambda x, y: 6 <= x <= 8 + (y > 14) and y >= 9, TRUNK)
tree_top = shape_img(16, 17, lambda x, y: y <= 12 and canopy_in(x, y), JGREEN, canopy_extra)
save_feat('jungle_tree', over(tree_trunk, tree_top))


# zigurat: tres gradas de piedra del templo, escalera en medio, musgo en lo alto y la puerta oscura
def zig_in(x, y):
    steps = ((0, 3, 21), (4, 6, 17), (8, 9, 13))       # (y desde arriba de la grada, mitad del ancho visible)
    if y >= 11:
        return True
    if y >= 7:
        return 3 <= x <= 20
    if y >= 3:
        return 6 <= x <= 17
    return 9 <= x <= 14
def zig_extra(im):
    for y in range(4, 16):                              # la escalera (franja más clara en el centro)
        for x in (11, 12):
            if im.getpixel((x + 1, y + 1)) not in ((0, 0, 0, 0), OUT):
                im.putpixel((x + 1, y + 1), TEMPLE[1] if y % 2 else TEMPLE[0])
    for y in (4, 8, 12):                                # juntas de las gradas
        for x in range(1, 23):
            p = im.getpixel((x + 1, y + 1))
            if p not in ((0, 0, 0, 0), OUT) and x not in (11, 12):
                im.putpixel((x + 1, y + 1), TEMPLE[2])
    for x, y in ((10, 0), (11, 0), (14, 0), (7, 3), (8, 3), (16, 3), (4, 7), (19, 7), (20, 7), (1, 11), (2, 11), (22, 11)):
        if im.getpixel((x + 1, y + 1)) not in ((0, 0, 0, 0), OUT):
            im.putpixel((x + 1, y + 1), MOSS[x % 2])
    for y in range(13, 16):                             # la puerta, abajo en el centro
        for x in (11, 12):
            im.putpixel((x + 1, y + 1), (20, 24, 22, 255))
    im.putpixel((12, 13), (20, 24, 22, 255)); im.putpixel((13, 13), (20, 24, 22, 255))
save_feat('ziggurat', shape_img(24, 16, zig_in, TEMPLE, zig_extra))


# ruina: un muro de piedra del templo roto por arriba, con una columna en pie a un lado y musgo
RUIN_TOP = [0, 0, 0, 5, 4, 4, 6, 7, 5, 5, 6, 8, 8, 9]          # (fila de arriba de cada columna)
def ruin_in(x, y):
    return y >= RUIN_TOP[x] and not (x == 2 and y < 4 and y % 3 == 2)
def ruin_extra(im):
    for y in range(1, 13):                              # juntas: hiladas y llagas alternas
        for x in range(1, 15):
            p = im.getpixel((x, y))
            if p in ((0, 0, 0, 0), OUT) or x <= 3:
                continue
            if (y - 1) % 3 == 2 or ((x + (3 if ((y - 1) // 3) % 2 else 0)) % 6 == 0):
                im.putpixel((x, y), TEMPLE[2])
    for x in range(14):                                 # musgo por lo alto
        y = RUIN_TOP[x] + 1
        if im.getpixel((x + 1, y)) not in ((0, 0, 0, 0), OUT) and x % 3 != 1:
            im.putpixel((x + 1, y), MOSS[x % 2])
save_feat('ruin', shape_img(14, 12, ruin_in, TEMPLE, ruin_extra))
print('  %s*.png' % FEAT)
