#!/usr/bin/env python3
# tools/art/player/make_monster_actions.py → PROPUESTA (v4) de poses nuevas del monstrito y de sus OJOS aparte
#   python3 tools/art/player/make_monster_actions.py           solo vistas previas en
#                                                              FlappyMonster_pruebas/monstrito_animaciones/
#                                                              (vista_previa_v4.png, escala_juego_v4.png, ojos/*.png)
#   python3 tools/art/player/make_monster_actions.py --apply   además escribe assets/images/player/actions/<pose>.png
#                                                              y assets/images/player/actions/eyes/<ojo>.png
#                                                              (solo archivos nuevos; nunca toca monstrito*.png ni duel/)
#
# Poses de acción: derrape, aterrizaje fuerte, preparación del ground pound, daño, lanzar, empujar, mirar arriba,
# agachado mirando abajo, espera larga, borde y victoria. SIN ciclos de andar ni correr (el monstruo se mueve
# alternando idle y salto a propósito: es parte de su esencia). SIN ALAS: aletea por arte de magia.
# Misma cabeza, antenas y paleta que monstrito1-5.png y las del duelo. Lienzo 9x16 o 13x16 (la cabeza en x=2 como
# en el duelo). Origen abajo en el centro. Miran a la DERECHA (el juego las voltea).
#
# LOS OJOS VAN APARTE (v3, el usuario: los ojos cerrados, ^ ^ y > < pintados en la cara de 5 px no se leían): las
# poses llevan la cara LISA (como monstrito4) y los ojos son sprites encima, a MEDIO píxel del sprite como las X de
# src/player/DeadEyes.lua (dedais.png) y los ojos de risa del Espejo (JoyEyes.png). Cada pose dice qué ojo usa y
# dónde: EYE_USE[pose] = (ojo, cx, cy, sep) en píxeles del sprite: cx, cy el punto medio entre los dos ojos, sep la
# distancia de cada ojo a ese punto. El ojo derecho de los asimétricos (> <) es el izquierdo volteado.
# Python puro (zlib + struct): no necesita PIL.
import math
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
BASE = os.path.join(ROOT, 'assets', 'images', 'player')
OUT = os.path.join(BASE, 'actions')
_PRUEBAS = os.environ.get('FM_PRUEBAS') or (
    '/home/mtvemo/FlappyMonster_pruebas' if os.path.isdir('/home/mtvemo') else os.path.expanduser('~/FlappyMonster_pruebas'))
PREVIEW = os.path.join(_PRUEBAS, 'monstrito_animaciones')

# Paleta de monstrito1-5 (# contorno · o cara · s sombra · w brillo · v brillo de la barriga)
PAL = {'#': (12, 12, 20, 255), 'o': (242, 242, 246, 255), 's': (196, 200, 214, 255), 'w': (255, 255, 255, 255),
       'v': (50, 52, 74, 255)}

# ---------------------------------------------------------------------------------------------------- PNG mínimo


def png_load(p):
    d = open(p, 'rb').read()
    i, idat, pal, trns = 8, b'', None, None
    while i < len(d):
        n, t = struct.unpack('>I4s', d[i:i + 8])
        c = d[i + 8:i + 8 + n]
        if t == b'IHDR': w, h, bd, ct = struct.unpack('>IIBB', c[:10])
        if t == b'PLTE': pal = [tuple(c[j:j + 3]) for j in range(0, len(c), 3)]
        if t == b'tRNS': trns = list(c)
        if t == b'IDAT': idat += c
        i += 12 + n
    raw = zlib.decompress(idat)
    bpp = {6: 4, 2: 3, 3: 1, 4: 2, 0: 1}[ct]
    st, rows, prev, k = w * bpp, [], bytearray(w * bpp), 0
    for _ in range(h):
        f = raw[k]; line = bytearray(raw[k + 1:k + 1 + st]); k += 1 + st
        for x in range(st):
            a = line[x - bpp] if x >= bpp else 0; b = prev[x]; c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        rows.append(bytes(line)); prev = line
    px = []
    for y in range(h):
        r = []
        for x in range(w):
            if ct == 6: r.append(tuple(rows[y][x * 4:x * 4 + 4]))
            elif ct == 2: r.append(tuple(rows[y][x * 3:x * 3 + 3]) + (255,))
            elif ct == 3:
                idx = rows[y][x]; r.append(pal[idx] + ((trns[idx] if trns and idx < len(trns) else 255),))
            elif ct == 4: v = rows[y][x * 2]; r.append((v, v, v, rows[y][x * 2 + 1]))
            else: v = rows[y][x]; r.append((v, v, v, 255))
        px.append(r)
    return px


def png_save(p, px):
    h, w = len(px), len(px[0])
    raw = b''.join(b'\x00' + b''.join(bytes(c) for c in row) for row in px)
    ch = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(p, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                        + ch(b'IDAT', zlib.compress(raw, 9)) + ch(b'IEND', b''))


def blank(w, h, col=(0, 0, 0, 0)): return [[col] * w for _ in range(h)]


def blit(dst, src, x0, y0, k, dim=None):
    for y, row in enumerate(src):
        for x, c in enumerate(row):
            if c[3] == 0: continue
            if dim: c = tuple(int(c[i] * dim + 90 * (1 - dim)) for i in range(3)) + (255,)
            for dy in range(k):
                for dx in range(k):
                    yy, xx = y0 + y * k + dy, x0 + x * k + dx
                    if 0 <= yy < len(dst) and 0 <= xx < len(dst[0]): dst[yy][xx] = c[:3] + (255,)


def rect(dst, x, y, w, h, col):
    for yy in range(max(0, y), min(len(dst), y + h)):
        for xx in range(max(0, x), min(len(dst[0]), x + w)): dst[yy][xx] = col

# ---------------------------------------------------------------------------------------------------- ojos
# A medio píxel del sprite (se dibujan a escala s/2, como DeadEyes). Mapas del ojo IZQUIERDO.
EYES = {
    'normal':    ["##",
                  "##"],                  # (el ojo de siempre: 1 px del sprite)
    'blink':     ["###"],                 # (cerrado: una raya fina; parpadeo, impacto)
    'happy':     [".##.",
                  "#..#"],                # (^ ^: los de risa del Espejo, JoyEyes.png sin su margen, igual de grandes)
    'hurt':      ["#..",
                  ".#.",
                  "..#",
                  ".#.",
                  "#.."],                 # (> <, v4: más alto para que se lea a ×6; el derecho es este volteado)
    'surprised': ["###",
                  "###",
                  "###"],                 # (abiertos como platos: un ojo más grande; el anillo se leía como ^)
    'sparkle':   [".#.",
                  "###",
                  ".#."],                 # (destello de alegría)
}
MIRRORED = {'hurt'}
EYE_COL = PAL['#']

# Cara lisa (sin ojos) de la cabeza: las filas 4-6 de la tele
FACE = [".#wwoos#.", ".#oooos#.", ".#oosss#."]

# ---------------------------------------------------------------------------------------------------- poses
# Mapas a mano (9 o 13 de ancho, 16 de alto). La cara se pinta lisa luego (HEAD_AT dice dónde está cada cabeza).

POSES = {
    # 1. DERRAPE (dar la vuelta corriendo): frena echado HACIA ATRÁS, el pie de delante clavado, brazos agitándose
    'skid1': [".....#.#.....",
              "....#.#......",
              "....#.#......",
              "...#####.....",
              "..#.....#....",
              "..#.....#....",
              "..#.....#....",
              ".#.#####.....",
              "..#..#.......",
              "...#.v##.....",
              "....#####....",
              ".....###.#...",
              "......#...#..",
              ".....#.#.....",
              ".....#..#....",
              "....##...##.."],
    'skid2': [".....#.#.....",
              "....#.#......",
              "....#.#......",
              "...#####.....",
              "..#.....#....",
              "..#.....#....",
              "..#.....#....",
              "...#####...#.",
              ".....#....#..",
              ".....v##.#...",
              "....#####....",
              "...#.###.....",
              "..#...#......",
              ".....#.#.....",
              ".....#..#....",
              "....##...##.."],
    # 3. ATERRIZAJE FUERTE: impacto (cabeza hundida, brazos afuera, rodillas dobladas) y recuperación
    'land_hard1': [".............",
                   ".............",
                   ".............",
                   "...##...##...",
                   ".....#.#.....",
                   "....#####....",
                   "...#.....#...",
                   "...#.....#...",
                   "...#.....#...",
                   "....#####....",
                   "..##.v##.##..",
                   "....#####....",
                   ".....###.....",
                   "....#...#....",
                   "...#.....#...",
                   "..##.....##.."],
    'land_hard2': [".............",
                   "....#...#....",
                   ".....#.#.....",
                   ".....#.#.....",
                   "....#####....",
                   "...#.....#...",
                   "...#.....#...",
                   "...#.....#...",
                   "....#####....",
                   "......#......",
                   ".....v##.....",
                   "...#######...",
                   "..#..###..#..",
                   ".....#.#.....",
                   "....#...#....",
                   "...##...##..."],
    # 4. GROUND POUND, preparación: hecho una bola (manos con los pies), mira abajo. (El picado es el salto de siempre.)
    'gpound_curl': [".........",
                    ".##...##.",
                    "...#.#...",
                    "..#####..",
                    ".#.....#.",
                    ".#.....#.",
                    ".#.....#.",
                    "..#####..",
                    "...v##...",
                    ".#.###.#.",
                    ".#.#.#.#.",
                    "..##.##..",
                    ".........",
                    ".........",
                    ".........",
                    "........."],
    # 5. DAÑO: el golpe (en estrella) y el retroceso (echado atrás, brazos al frente). Brazos y piernas del largo de
    #    las bases: brazo 2 px en diagonal desde el cuerpo, pierna 2 px + pie.
    'hurt1': ["...#.....#...",
              "....#...#....",
              ".....#.#.....",
              "....#####....",
              "...#.....#...",
              "...#.....#...",
              "...#.....#...",
              "....#####....",
              "..#...#...#..",
              "...#.v##.#...",
              "....#####....",
              ".....###.....",
              "......#......",
              ".....#.#.....",
              "....#...#....",
              "...#.....#..."],
    'hurt2': [".....#.#.....",
              "....#.#......",
              "....#.#......",
              "...#####.....",
              "..#.....#....",
              "..#.....#....",
              "..#.....#....",
              "...#####.....",
              ".....#....#..",
              ".....v##.#...",
              "....#####....",
              ".....###.##..",
              "......#......",
              ".....#.#.....",
              "....#...##...",
              "...##........"],
    # 8. LANZAR: ERGUIDO, el brazo que lanza alto y al frente, el otro atrás, un paso adelante (no se inclina:
    #    así no se confunde con empujar)
    'throw': ["....#.#......",
              ".....#.#.....",
              ".....#.#.....",
              "....#####....",
              "...#.....#...",
              "...#.....#...",
              "...#.....#...",
              "....#####..#.",
              "......#...#..",
              ".....v##.#...",
              "....#####....",
              "...#.###.....",
              "..#...#......",
              ".....#.#.....",
              "....#...#....",
              "...#....##..."],
    # 9. EMPUJAR: inclinado hacia el objeto, las manos planas contra él; las piernas se alternan
    'push1': [".............",
              ".....#.#.....",
              "......#.#....",
              "......#.#....",
              ".....#####...",
              "....#.....#..",
              "....#.....#..",
              "....#.....#..",
              ".....#####...",
              ".......#.....",
              "......v######",
              ".....#####..#",
              ".....###.....",
              "....#.#......",
              "...#..#......",
              ".##...##....."],
    'push2': [".............",
              ".....#.#.....",
              "......#.#....",
              "......#.#....",
              ".....#####...",
              "....#.....#..",
              "....#.....#..",
              "....#.....#..",
              ".....#####...",
              ".......#.....",
              "......v######",
              ".....#####..#",
              ".....###.....",
              ".....#.#.....",
              "....#..#.....",
              "..##...##...."],
    # 13. EN EL BORDE (el vacío a la derecha): DE PUNTILLAS (sin pies planos), el cuerpo se va hacia delante en
    #     diagonal, los brazos dan vueltas: arriba (1) y abajo con la cabeza un poco atrás (2) = se tambalea
    'ledge1': ["........#.#..",
               ".......#.#...",
               ".......#.#...",
               "......#####..",
               ".....#.....#.",
               ".....#.....#.",
               ".....#.....#.",
               "......#####..",
               "...#...#...#.",
               "....#.v##.#..",
               ".....#####...",
               "......###....",
               "......#......",
               ".....#.#.....",
               ".....#.#.....",
               ".....#.#....."],
    'ledge2': [".......#.#...",
               "......#.#....",
               "......#.#....",
               ".....#####...",
               "....#.....#..",
               "....#.....#..",
               "....#.....#..",
               ".....#####...",
               ".......#.....",
               "......v##....",
               ".....#####...",
               "....#.###.#..",
               "...#..#...#..",
               ".....#.#.....",
               ".....#.#.....",
               ".....#.#....."],
    # 14. VICTORIA (nueva): se agacha para coger impulso (1), salta con el puño arriba (2) y cae en «¡tachán!»
    #     con los brazos abiertos (3)
    'victory1': [".............",
                 ".............",
                 "....#...#....",
                 ".....#.#.....",
                 ".....#.#.....",
                 "....#####....",
                 "...#.....#...",
                 "...#.....#...",
                 "...#.....#...",
                 "....#####....",
                 "......#......",
                 ".....v##.....",
                 "....#####....",
                 "...#.###.#...",
                 "..#.#...#.#..",
                 "...##...##..."],
    'victory2': ["...#.....#...",
                 "....#...#....",
                 ".....#.#.....",
                 "....#####....",
                 "...#.....#.#.",
                 "...#.....#.#.",
                 "...#.....#.#.",
                 "....#####..#.",
                 "......#...#..",
                 ".....v####...",
                 "....#####....",
                 "...#.###.....",
                 "..#...#......",
                 ".....#.##....",
                 "....##..#....",
                 "............."],
    'victory3': ["....#...#....",
                 ".....#.#.....",
                 ".....#.#.....",
                 "....#####....",
                 "...#.....#...",
                 "...#.....#...",
                 "...#.....#...",
                 "....#####....",
                 "......#......",
                 ".###.v##.###.",
                 "....#####....",
                 ".....###.....",
                 "......#......",
                 ".....#.#.....",
                 "....#...#....",
                 "...##...##..."],
}

# Dónde está la cabeza de cada pose (x0, y0 de su lienzo de 9 de ancho: la cara en x0+1.., filas y0+4..y0+6)
HEAD_AT = {
    'skid1': (1, 0), 'skid2': (1, 0), 'land_hard1': (2, 2), 'land_hard2': (2, 1), 'gpound_curl': (0, 0),
    'hurt1': (2, 0), 'hurt2': (1, 0), 'throw': (2, 0), 'push1': (3, 1), 'push2': (3, 1),
    'ledge1': (4, 0), 'ledge2': (3, 0), 'victory1': (2, 2), 'victory2': (2, 0), 'victory3': (2, 0),
    'look_up': (0, 0), 'crouch_look_down': (0, 6), 'idle_blink': (0, 0), 'idle_wiggle1': (0, 0),
    'idle_wiggle2': (0, 0),
}

# Qué ojos lleva cada pose: (ojo, mirada dx, mirada dy) — la mirada mueve el par en píxeles del sprite
LOOK = {
    'skid1': ('normal', 0.5, 0), 'skid2': ('normal', 0.5, 0),
    'land_hard1': ('blink', 0, 0), 'land_hard2': ('normal', 0, 0),
    'gpound_curl': ('normal', 0, 0.5),
    'hurt1': ('hurt', 0, 0), 'hurt2': ('hurt', 0, 0),
    'throw': ('normal', 0.5, -0.5),
    'push1': ('normal', 0.5, 0), 'push2': ('normal', 0.5, 0),
    'look_up': ('normal', 0, -0.5),
    'crouch_look_down': ('normal', 0, 0.5),
    'idle_blink': ('blink', 0, 0), 'idle_wiggle1': ('normal', 0, 0), 'idle_wiggle2': ('normal', 0, 0),
    'ledge1': ('surprised', 0.25, 0.25), 'ledge2': ('surprised', 0.25, 0.25),
    'victory1': ('happy', 0, 0), 'victory2': ('happy', 0, -0.25), 'victory3': ('sparkle', 0, 0),
}
SEP = 1.0                     # (cada ojo a 1 px del centro: donde están los ojos pintados de monstrito3)
EYE_SEP = {'happy': 1.25,     # (el Espejo los pone a ±1.2 en píxeles de pantalla; aquí van a medios píxeles del
                              # sprite: con 1,2 el redondeo los juntaba — el usuario: «el Espejo los tiene separados
                              # un poquito» —; con 1,25 queda medio píxel entre los dos, como él)
           'hurt': 1.25}      # (los > < más anchos: un hueco de 1 px entre los dos)


def eye_use(name):
    """(ojo, cx, cy, sep) en píxeles del sprite, para el juego (como DeadEyes.drawPair)."""
    eye, dx, dy = LOOK[name]
    x0, y0 = HEAD_AT[name]
    return eye, x0 + 4.5 + dx, y0 + 5.5 + dy, EYE_SEP.get(eye, SEP)


ANT = {'spread': [".#.....#.", "..#...#..", "...#.#..."],     # (abiertas hacia atrás: mirar arriba)
       'wigL':   [".#....#..", "..#..#...", "...#.#..."],     # (meneo: la izquierda se abre)
       'wigR':   ["..#....#.", "...#..#..", "...#.#..."]}     # (meneo: la derecha se abre)


def cv_from(rows): return [list(r) for r in rows]


def pose(name):
    if name in POSES:
        cv = cv_from(POSES[name])
    elif name == 'crouch_look_down':  # 11. agachado: monstrito5 tal cual (los ojos, abajo, los pone la capa)
        cv = cv_from(MAP['crouch'])
    else:                             # 10 / 12. el idle de monstrito3 con las antenas cambiadas
        cv = cv_from(MAP['idle'])
        if name == 'look_up':
            for y in range(3): cv[y] = list(ANT['spread'][y])
        elif name in ('idle_wiggle1', 'idle_wiggle2'):
            for y in range(3): cv[y] = list(ANT['wigL' if name == 'idle_wiggle1' else 'wigR'][y])
    x0, y0 = HEAD_AT[name]           # la cara, lisa: los ojos los pone la capa de ojos
    for i, r in enumerate(FACE):
        for x, c in enumerate(r):
            if c != '.' and 0 <= x0 + x < len(cv[0]): cv[y0 + 4 + i][x0 + x] = c
    return cv


# (animación, base con la que se compara, [poses]) en el orden de la propuesta (los números de v2)
ANIMS = [
    # (1, derrapar: quitado por el usuario en el juego, 2026-11-10 — «no termina de quedar bien» —)
    ('3 land',      'crouch', ['land_hard1', 'land_hard2']),
    ('4 gpound',    'jump',   ['gpound_curl']),
    # (5, dolor: quitado por el usuario en el juego, 2026-11-10 — «no termina de quedar bien» —)
    ('8 throw',     'jump',   ['throw']),
    ('9 push',      'idle',   ['push1', 'push2']),
    ('10 lookup',   'idle',   ['look_up']),
    ('11 lookdown', 'crouch', ['crouch_look_down']),
    ('12 longidle', 'idle',   ['idle_blink', 'idle_wiggle1', 'idle_wiggle2']),
    # (13, al borde: descartado por el usuario, 2026-11-10)
    ('14 victory',  'glide',  ['victory1', 'victory2', 'victory3']),
]

# Las 5 bases (leídas de los PNG del usuario, para comparar y para las poses que parten de ellas)
MAP = {}


def load_bases():
    key = {v[:3]: k for k, v in PAL.items()}
    imgs = {}
    for n, i in {'glide': 1, 'jump': 2, 'idle': 3, 'dead': 4, 'crouch': 5}.items():
        px = png_load(os.path.join(BASE, 'monstrito%d.png' % i))
        imgs[n] = px
        MAP[n] = [''.join('.' if c[3] == 0 else key.get(c[:3], '#') for c in r) for r in px]
    return imgs


def catalog():
    out = []
    for anim, base, names in ANIMS:
        frames = [(n, pose(n)) for n in names]
        for n, cv in frames:
            assert len(cv) == 16 and all(len(r) == len(cv[0]) for r in cv) and len(cv[0]) in (9, 13), n
        out.append((anim, base, frames))
    return out


def to_px(cv): return [[PAL[c] if c in PAL else (0, 0, 0, 0) for c in r] for r in cv]


def eye_px(name, mirror=False):
    rows = [r[::-1] for r in EYES[name]] if mirror else EYES[name]
    return [[EYE_COL if c == '#' else (0, 0, 0, 0) for c in r] for r in rows]


def eye_rects(name, k, pad_x=0):
    """Dónde van los dos ojos de la pose a escala k, en píxeles de pantalla desde la esquina del sprite:
    [(x, y, imagen)] — el ojo a k/2 por píxel, como DeadEyes y el Espejo. SIMÉTRICOS por construcción: el derecho es el
    reflejo exacto del izquierdo alrededor del centro del par (antes cada uno se redondeaba por su cuenta y con algunas
    separaciones el par quedaba corrido un cuarto de píxel: el usuario lo vio en los ^ ^ de la victoria)."""
    eye, cx, cy, sep = eye_use(name)
    cx += pad_x
    h = k // 2
    c = round(cx * k)                      # centro del par (px de pantalla)
    off = round(sep * k)                   # de cada ojo al centro
    out = []
    left = eye_px(eye)
    w, hh = len(left[0]) * h, len(left) * h
    y = round(cy * k) - hh // 2
    lx = c - off - w // 2
    out.append((lx, y, left))
    right = eye_px(eye, mirror=(eye in MIRRORED))
    out.append((2 * c - lx - w, y, right))   # (el reflejo del izquierdo: mismo hueco a cada lado del centro)
    return out, h


def draw_eyes(dst, name, ox, oy, k, pad_x=0):
    """Pinta los ojos de la pose sobre el sprite ya dibujado en (ox, oy) a escala k."""
    rects, h = eye_rects(name, k, pad_x)
    for x, y, px in rects: blit(dst, px, ox + x, oy + y, h)

# ---------------------------------------------------------------------------------------------------- vistas previas

BG = (70, 86, 104, 255)
FONT = {'0': "111101101101111", '1': "010110010010111", '2': "111001111100111", '3': "111001111001111",
        '4': "101101111001001", '5': "111100111001111", '6': "111100111101111", '7': "111001001001001",
        '8': "111101111101111", '9': "111101111001111"}


def text(dst, s, x, y, k, col=(220, 226, 236, 255)):
    for ch in s:
        g = FONT.get(ch)
        if g:
            for i, b in enumerate(g):
                if b == '1': rect(dst, x + (i % 3) * k, y + (i // 3) * k, k, k, col)
        x += 4 * k


def main():
    imgs = load_bases()
    cat = catalog()
    K, GAP = 8, 8
    cw, ch = 13 * K, 16 * K
    ncols = max(5, 1 + max(len(fr) for _, _, fr in cat))
    left = 48
    W = left + GAP + ncols * (cw + GAP) + GAP
    eyes_h = 6 * K + 2 * GAP
    H = GAP + eyes_h + (1 + len(cat)) * (ch + GAP)
    sheet = blank(W, H, BG)
    # fila de los OJOS, sueltos, a la escala del juego relativa (medio píxel del sprite = K/2) y en grande
    x = left + GAP
    for name in EYES:
        for side in (-1, 1):
            px = eye_px(name, mirror=(side == 1 and name in MIRRORED))
            rect(sheet, x - 2, GAP - 2, len(px[0]) * K + 4, len(px) * K + 4, (242, 242, 246, 255))
            blit(sheet, px, x, GAP, K)
            x += len(px[0]) * K + 12
        x += 20
    # fila 0: las 5 bases
    y = GAP + eyes_h
    for i, n in enumerate(['glide', 'jump', 'idle', 'dead', 'crouch']):
        blit(sheet, imgs[n], left + GAP + i * (cw + GAP) + 2 * K, y, K)
    text(sheet, '0', 8, y + ch // 2, 4)
    for r, (anim, base, frames) in enumerate(cat, start=1):
        y = GAP + eyes_h + r * (ch + GAP)
        num = anim.split()[0]
        text(sheet, num, 4, y + ch // 2, 4)
        x = left + GAP
        blit(sheet, imgs[base], x + 2 * K, y, K, dim=0.45)                   # (la base más cercana, apagada)
        rect(sheet, x + cw + GAP // 2 - 1, y, 2, ch, (30, 36, 46, 255))      # (separador)
        for i, (name, cv) in enumerate(frames):
            px = to_px(cv)
            pad = (13 - len(px[0])) // 2
            fx = x + (i + 1) * (cw + GAP)
            blit(sheet, px, fx + pad * K, y, K)
            draw_eyes(sheet, name, fx + pad * K, y, K)
    os.makedirs(PREVIEW, exist_ok=True)
    png_save(os.path.join(PREVIEW, 'vista_previa_v4.png'), sheet)
    print('  vista previa', os.path.join(PREVIEW, 'vista_previa_v4.png'))

    # Escala de juego (×6, los ojos a ×3) sobre un fondo de tono medio, todos apoyados en el mismo suelo
    S = 6
    pick = ['idle', 'jump', 'crouch'] + [n for _, _, fr in cat for n, _ in fr]
    byname = {n: cv for _, _, fr in cat for n, cv in fr}
    EW = 14 * S
    img = blank(len(pick) * EW + 2 * S, 24 * S, (104, 124, 116, 255))
    rect(img, 0, 20 * S, len(img[0]), 4 * S, (62, 74, 68, 255))
    for i, n in enumerate(pick):
        px = imgs[n] if n in imgs else to_px(byname[n])
        w = len(px[0])
        x = S + i * EW + (EW - w * S) // 2
        blit(img, px, x, 4 * S, S)
        if n not in imgs: draw_eyes(img, n, x, 4 * S, S)
    png_save(os.path.join(PREVIEW, 'escala_juego_v4.png'), img)
    print('  escala de juego', os.path.join(PREVIEW, 'escala_juego_v4.png'))

    # Los ojos como archivos sueltos (de momento, solo en la carpeta de pruebas)
    eyes_dir = os.path.join(PREVIEW, 'ojos')
    os.makedirs(eyes_dir, exist_ok=True)
    for name in EYES: png_save(os.path.join(eyes_dir, name + '.png'), eye_px(name))
    print('  ojos', eyes_dir)
    # La tabla de ojos por pose (lo que el juego necesitaría)
    for _, _, fr in cat:
        for n, _ in fr:
            e, cx, cy, sep = eye_use(n)
            print('    %-18s ojo %-9s centro (%.2f, %.2f) sep %.2f' % (n, e, cx, cy, sep))

    if '--apply' in sys.argv:
        for d in (OUT, os.path.join(OUT, 'eyes')): os.makedirs(d, exist_ok=True)
        files = [(os.path.join(OUT, n + '.png'), to_px(cv)) for _, _, fr in cat for n, cv in fr]
        used = sorted({eye_use(n)[0] for _, _, fr in cat for n, _ in fr})   # (solo los ojos que usa alguna pose)
        files += [(os.path.join(OUT, 'eyes', e + '.png'), eye_px(e)) for e in used]
        for p, px in files:
            if os.path.exists(p) and '--force' not in sys.argv:
                print('  ya existe (no se toca)', p); continue
            png_save(p, px)
            print('  escrito', p)


if __name__ == '__main__':
    main()
