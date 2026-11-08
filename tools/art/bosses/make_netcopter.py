#!/usr/bin/env python3
# tools/art/bosses/make_netcopter.py — el Redcóptero (jefe del Valle, campaña Flappy; docs/design/flappy-plan-5-netcopter.md).
# El Monstruo Malvado pedalea una máquina de chatarra: globo remendado, góndola de madera y una hélice de pedal.
# El piloto es el cuerpo del jugador (monstrito1, 9x16) con la cabeza y las antenas de miniboss1/monster/Idle1.png.
# Sin alas en nada. Arte a x6 (el píxel del jugador): formas planas, 2-3 tonos por pieza, sin detalle fino.
#
#   python3 tools/art/bosses/make_netcopter.py           → vista_previa.png (fondo = cielo claro; el Valle aún no existe)
#   python3 tools/art/bosses/make_netcopter.py --apply   → assets/images/bosses/netcopter/
#
# Anclas (arte, en cuadro de máquina 44x54): el globo en y 0..25; la góndola en x 12..32, y 43..52; el piloto (9x16,
# el cuerpo del jugador) se dibuja con su esquina en (18, 27): de pie con los pies en y 42, sobre el borde de la góndola,
# las manos en el manillar (y 39); el cañón en y 42, con la esquina en x -12 (desplegado), sujeto por su brazo
# (cannon_arm-Sheet: abrazadera a 12 px de la esquina del cañón, barra, placa en x 9..11); la hélice (propeller-Sheet,
# 12x18, 4 cuadros) con la esquina en (32, 37) y el buje en (37, 45). Plan 5c (docs/design/flappy-plan-5c-netcopter-
# polish.md): el globo se mece (machine-Sheet: 3 cuadros, 0 / +1 / -1 px), la red se despliega y gira (net-Sheet), la
# risa como la del Espejo (pilot_laugh-Sheet + joy_face), enfadado (pilot_angry), humo, hebras y chispas (puff-Sheet,
# spark-Sheet) y la marca de la bomba (mark-Sheet). Todo lo monta netcopter.lua / netshot.lua igual que la vista previa.
import os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'redcoptero')
DEST = os.path.join(ROOT, 'assets', 'images', 'bosses', 'netcopter')
K = 6
SKY = (150, 205, 240, 255)


def hx(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# contorno, sombra, medio, luz
RED = [hx(c) for c in ('5a1418', '9a2428', 'cf3d34', 'ec7a5a')]
PATCH = [hx(c) for c in ('5a4a1c', 'b89a38', 'e8d070')]
WOOD = [hx(c) for c in ('2e1c0c', '6a4020', '9a6234', 'c08c52')]
IRON = [hx(c) for c in ('1c1c24', '4a4a58', '7c7c8c', 'b4b4c4')]
ROPE = hx('c8b078')
BLACK, WHITE = hx('000000'), hx('ffffff')
FIRE = [hx('ff8a28'), hx('ffd23c'), hx('fff6c0')]
NETC = [hx('7a6a40'), hx('e8dcb0')]


def new(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def rect(im, x0, y0, x1, y1, c):
    ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=c)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def ellipse(im, cx, cy, rx, ry, pal):
    """Elipse con contorno (pal[0]), luz arriba-izquierda, sombra abajo-derecha."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d > 1:
                continue
            e = ((x - cx) / (rx - 1.4)) ** 2 + ((y - cy) / (ry - 1.4)) ** 2
            if e > 1:
                c = pal[0]
            else:
                t = ((x - cx) / rx) * 0.6 + ((y - cy) / ry) * 0.8
                c = pal[3] if t < -0.55 else pal[1] if t > 0.45 else pal[2]
            px(im, x, y, c)


def sheet(frames):
    w = sum(f.width for f in frames)
    s = new(w, max(f.height for f in frames))
    x = 0
    for f in frames:
        s.paste(f, (x, 0)); x += f.width
    return s


# ══ LA MÁQUINA (cuadro 44x54) ═════════════════════════════════════════════════════════════════════════════════════
# El globo arriba (y 0..25); cuerdas largas; la góndola baja D filas para que el Monstruo Malvado quepa de pie
# (cuerpo entero, 16 filas) entre el globo y la góndola, con los pies sobre el borde.
MW, MH = 44, 54
D = 14                                               # lo que baja la parte de abajo (góndola, hélice, manillar)
PILOT_AT = (18, 27)                                  # esquina del piloto 9x16: pies en y 42, la góndola empieza en 43


def gondola(im):
    rect(im, 12, 29, 32, 38, WOOD[0])
    rect(im, 13, 30, 31, 37, WOOD[2])
    rect(im, 13, 35, 31, 37, WOOD[1])
    rect(im, 13, 30, 31, 30, WOOD[3])
    for x in (18, 25):                               # tablas
        rect(im, x, 31, x, 37, WOOD[1])
    px(im, 15, 33, WOOD[0]); px(im, 29, 33, WOOD[0])  # clavos


def handlebar(im):
    """Manillar de hierro a la altura de las manos del piloto (fila 12 del piloto), con dos postes hasta la góndola."""
    rect(im, 17, 25, 27, 25, IRON[0])
    rect(im, 17, 26, 17, 28, IRON[1]); rect(im, 27, 26, 27, 28, IRON[1])


def ropes(im, y0, y1, dx=0):
    for (xa, xb) in ((9 + dx, 13), (35 + dx, 31)):
        n = y1 - y0
        for i in range(n + 1):
            px(im, xa + (xb - xa) * i // n, y0 + i, ROPE)


def shaft(im):
    """El eje de la hélice que sale de la góndola (la hélice que gira es hoja aparte: propeller-Sheet)."""
    rect(im, 33, 32, 36, 33, IRON[1]); rect(im, 33, 32, 36, 32, IRON[2])


# ══ LA HÉLICE (cuadro 12x18; se pega en PROP_AT del cuadro de la máquina; buje en (5, 8)) ═══════════════════════════
# Gira de cara: 4 cuadros (vertical, /, horizontal, \). Las palas, en una elipse de radios 5 x 8 (perspectiva).
PROP_W, PROP_H = 12, 18
PROP_AT = (32, 37)                                   # (el buje en (37, 45))


def propeller(frame):
    import math
    im = new(PROP_W, PROP_H)
    cx, cy = 5, 8                                                             # el buje (píxel)
    ang = math.radians([90, 45, 0, 135][frame])
    ex, ey = 5.0 * math.cos(ang), 8.0 * math.sin(ang)                         # punta de la pala (elipse 5 x 8)
    L = math.hypot(ex, ey)
    ux, uy = ex / L, ey / L
    for y in range(PROP_H):
        for x in range(PROP_W):
            dx, dy = x - cx, y - cy
            along, across = dx * ux + dy * uy, -dx * uy + dy * ux             # (en píxeles: el mismo grosor girada)
            if 1.5 <= abs(along) <= L + 0.3 and abs(across) <= 1.0:
                px(im, x, y, IRON[3] if abs(across) < 0.3 else IRON[2])
    edge = []
    for y in range(PROP_H):
        for x in range(PROP_W):
            if im.getpixel((x, y))[3] == 0 and any(0 <= x + a < PROP_W and 0 <= y + b < PROP_H and im.getpixel((x + a, y + b))[3]
                                                   for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge.append((x, y))
    for (x, y) in edge:
        px(im, x, y, IRON[0])                                                 # contorno de las palas
    rect(im, cx - 1, cy - 1, cx + 1, cy + 1, IRON[0]); px(im, cx, cy, IRON[3])  # buje
    return im


def lower():
    """La parte de abajo en sus coordenadas de siempre (góndola en y 29..38); se pega D filas más abajo."""
    lo = new(MW, MH - D)
    handlebar(lo)
    gondola(lo)
    shaft(lo)
    return lo


# Telas de los remiendos: cada uno de una tela distinta del globo (contorno, tela, luz)
DENIM = [hx('1e2a48'), hx('3c5c94'), hx('6c8cc4')]
BURLAP = [hx('3a2a10'), hx('a07c3c'), hx('cca868')]
THREAD = hx('f4ecd0')


def patch(im, rows, cloth):
    """Remiendo cosido: rows = [(y, x0, x1)] (forma un poco torcida). Borde oscuro con puntadas de hilo claro
    alternas (punto sí, punto no), tela de otro color dentro y una fila de luz arriba."""
    cells = {(x, y) for (y, x0, x1) in rows for x in range(x0, x1 + 1)}
    top = min(y for (y, _, _) in rows)
    for (x, y) in cells:
        edge = any((x + dx, y + dy) not in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            c = THREAD if (x + y) % 2 == 0 else cloth[0]
        else:
            c = cloth[2] if y == top + 1 else cloth[1]
        px(im, x, y, c)


def patches(im, dy=0):
    # remiendo vaquero, grande y algo torcido (la fila de arriba corrida un píxel)
    patch(im, [(7 + dy, 11, 16), (8 + dy, 10, 16), (9 + dy, 10, 16), (10 + dy, 10, 16), (11 + dy, 10, 16),
               (12 + dy, 10, 17), (13 + dy, 11, 17)], DENIM)
    # remiendo de saco, pequeño
    patch(im, [(15, 27, 32), (16, 27, 32), (17, 27, 32), (18, 28, 32), (19, 28, 31)], BURLAP)


def machine(sway):
    """sway: el globo corrido -1 / 0 / +1 px sobre la góndola (vaivén; las cuerdas lo siguen)."""
    im = new(MW, MH)
    ropes(im, 24, 29 + D, sway)
    top = new(MW, 26)
    ellipse(top, 22, 13, 18, 12.5, RED)
    patches(top)
    for x in range(8, 38, 6):                        # costuras
        px(top, x, 23 if x < 30 else 22, RED[0])
    im.alpha_composite(top, (sway, 0)) if sway >= 0 else im.alpha_composite(top.crop((-sway, 0, MW, 26)), (0, 0))
    im.alpha_composite(lower(), (0, D))
    return im


def machine_popped(frame):
    """Fase 2: el globo reventado cuelga como un trapo (más bajo) sobre las cuerdas."""
    im = new(MW, MH)
    ropes(im, 20, 29 + D)
    d = frame
    pts = [(6, 18), (12, 12 + d), (22, 9), (32, 12 + d), (38, 18), (36, 24 + d), (28, 21), (22, 26 - d), (15, 21), (8, 25 + d)]
    ImageDraw.Draw(im).polygon(pts, fill=RED[0])
    inner = [(8, 18), (13, 14 + d), (22, 11), (31, 14 + d), (36, 18), (34, 22 + d), (28, 19), (22, 24 - d), (16, 19), (10, 22 + d)]
    ImageDraw.Draw(im).polygon(inner, fill=RED[2])
    rect(im, 18, 13, 26, 14, RED[3])
    for x in range(10, 36, 5):
        px(im, x, 20, RED[1]); px(im, x + 1, 21, RED[1])
    patch(im, [(14 + d, 12, 17), (15 + d, 11, 17), (16 + d, 11, 17), (17 + d, 11, 16), (18 + d, 12, 16)], DENIM)  # aguanta
    im.alpha_composite(lower(), (0, D))
    return im


# ══ EL CAÑÓN (16x12; boca a la izquierda) ═════════════════════════════════════════════════════════════════════════
def cannon(glow):
    im = new(18, 12)
    rect(im, 3, 2, 16, 9, IRON[0]); rect(im, 4, 3, 15, 8, IRON[2]); rect(im, 4, 3, 15, 4, IRON[3]); rect(im, 4, 7, 15, 8, IRON[1])
    rect(im, 0, 1, 3, 10, IRON[0]); rect(im, 1, 2, 3, 9, IRON[1])                  # boca
    inner = FIRE[2] if glow else IRON[0]
    rect(im, 1, 4, 2, 7, inner)
    if glow:
        rect(im, 0, 4, 0, 7, FIRE[1]); px(im, 3, 5, FIRE[0]); px(im, 3, 6, FIRE[0])
    rect(im, 9, 2, 9, 9, IRON[0]); rect(im, 13, 2, 13, 9, IRON[0])                  # aros
    rect(im, 17, 4, 17, 7, IRON[0])                                                # culata
    return im


# ══ EL BRAZO DEL CAÑÓN (piezas de 3x12, a la altura del cañón) ═════════════════════════════════════════════════════
# Abrazadera (alrededor del cañón, se mueve con él y con su retroceso) · barra (se repite hasta la placa) · placa
# atornillada al costado de la góndola. Hierro, bloques planos.
def cannon_arm():
    collar = new(3, 12)
    rect(collar, 0, 1, 2, 10, IRON[0]); rect(collar, 1, 2, 1, 9, IRON[1]); px(collar, 1, 3, IRON[3]); px(collar, 1, 8, IRON[3])
    bar = new(3, 12)
    rect(bar, 0, 5, 2, 8, IRON[0]); rect(bar, 0, 6, 2, 6, IRON[3]); rect(bar, 0, 7, 2, 7, IRON[2])
    plate = new(3, 12)
    rect(plate, 0, 2, 2, 11, IRON[0]); rect(plate, 1, 3, 2, 10, IRON[1]); px(plate, 1, 4, IRON[3]); px(plate, 1, 9, IRON[3])
    return sheet([collar, bar, plate])


# ══ LA GARRA (brazo de 54x14; la garra a la izquierda) ═════════════════════════════════════════════════════════════
def claw():
    im = new(54, 14)
    rect(im, 14, 5, 53, 8, IRON[0]); rect(im, 14, 6, 53, 7, IRON[2]); rect(im, 14, 6, 53, 6, IRON[3])
    for x in range(20, 52, 8):
        rect(im, x, 4, x + 1, 9, IRON[0]); px(im, x, 6, IRON[1])                   # articulaciones
    rect(im, 8, 3, 15, 10, IRON[0]); rect(im, 9, 4, 14, 9, IRON[1])                # palma
    for (y0, y1) in ((0, 4), (9, 13)):                                             # dos dedos
        rect(im, 1, y0, 9, y1, IRON[0]); rect(im, 2, y0 + 1, 8, y1 - 1, IRON[2])
    rect(im, 0, 3, 2, 4, IRON[0]); rect(im, 0, 9, 2, 10, IRON[0])                 # puntas que se cierran
    rect(im, 3, 4, 6, 4, IRON[3])
    return im


# ══ EL PILOTO (9x16, el cuerpo del jugador) ═══════════════════════════════════════════════════════════════════════
# El Monstruo Malvado es el monstruo (player/monstrito1.png: cuello, brazos, torso oscuro con su sombra, piernas) con
# la cabeza y las antenas de miniboss1/monster (Idle1.png; hurt.png para el daño). Mismo píxel que el jugador (×6).
# Negro puro de contorno, como su cabeza. Sin alas.
SHADE = hx('32344a')                                 # la sombra del torso del monstruo (50,52,74)
BODY = {                                             # filas 8..15 del cuerpo: A negro, E sombra
    'pedal': ['....A....', '...EAA...', '..AAAAA..', '.A.AAA.A.', 'A...A...A'],          # brazos al manillar
    'laugh': ['A.......A', '.A..A..A.', '..AEAAA..', '..AAAAA..', '...AAA...', '....A....'],  # filas 7..12, manos arriba
    'hurt':  ['A...A...A', '.A.EAA.A.', '..AAAAA..', '...AAA...', '....A....'],          # brazos de monstrito1
}
LEGS = {                                             # filas 13..15
    0: ['...A.A...', '..AA.A...', '.....AA..'],      # pedal 1: el pie izquierdo arriba
    1: ['...A.A...', '...A.AA..', '..AA.....'],      # pedal 2: el derecho arriba
    'stand': ['...A.A...', '...A.A...', '..AA.AA..'],
}


def head(name):
    """Antenas + cabeza de miniboss1/monster/<name>.png (columnas 9..17, filas 2..9) → filas 0..7 del cuerpo."""
    src = Image.open(os.path.join(ROOT, 'assets', 'images', 'bosses', 'miniboss1', 'monster', name + '.png')).convert('RGBA')
    return src.crop((9, 2, 18, 10))


def draw_rows(im, y0, rows):
    for j, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == 'A':
                px(im, x, y0 + j, BLACK)
            elif ch == 'E':
                px(im, x, y0 + j, SHADE)


def pilot(kind):
    im = new(9, 16)
    im.alpha_composite(head('hurt' if kind == 'hurt' else 'Idle1'), (0, 0))
    if kind in ('pedal1', 'pedal2'):
        draw_rows(im, 8, BODY['pedal']); draw_rows(im, 13, LEGS[0 if kind == 'pedal1' else 1])
    elif kind == 'laugh':
        draw_rows(im, 7, BODY['laugh']); draw_rows(im, 13, LEGS['stand'])
        for x in (3, 4, 5):
            px(im, x, 6, BLACK)                      # boca abierta, de risa
    else:
        draw_rows(im, 8, BODY['hurt']); draw_rows(im, 13, LEGS['stand'])
    return im


def pilot_flee(frame):
    """Huye de pie en un trozo de góndola (36x30), con el manillar y la hélice rota; el cuerpo entero encima."""
    im = new(36, 30)
    rect(im, 13, 14, 23, 14, IRON[0]); rect(im, 13, 15, 13, 17, IRON[1]); rect(im, 23, 15, 23, 17, IRON[1])  # manillar
    im.alpha_composite(pilot('pedal1' if frame == 0 else 'pedal2'), (14, 2))
    rect(im, 9, 18, 29, 25, WOOD[0]); rect(im, 10, 19, 28, 24, WOOD[2]); rect(im, 10, 23, 28, 24, WOOD[1])
    px(im, 14, 21, WOOD[0]); px(im, 24, 21, WOOD[0])
    # hélice rota: un solo palo torcido que gira, humo
    rect(im, 29, 20, 32, 21, IRON[1])
    if frame == 0:
        rect(im, 32, 14, 33, 20, IRON[2]); px(im, 32, 14, IRON[0])
    else:
        rect(im, 33, 22, 34, 28, IRON[2]); px(im, 34, 28, IRON[0])
    for (x, y) in ((4, 14 + frame), (2, 18 - frame), (5, 22)):
        rect(im, x, y, x + 1, y + 1, hx('545462'))   # humo
    return im


# ══ RED, BOMBA, PIEZAS ═════════════════════════════════════════════════════════════════════════════════════════════
def net():
    im = new(16, 16)
    for i in range(0, 16, 4):
        rect(im, i, 0, i, 15, NETC[1]); rect(im, 0, i, 15, i, NETC[1])
    for i in range(0, 16, 4):
        for j in range(0, 16, 4):
            px(im, i, j, NETC[0])
    rect(im, 15, 0, 15, 15, NETC[0]); rect(im, 0, 15, 15, 15, NETC[0])
    for i in range(0, 16, 4):
        px(im, 15, i, NETC[1]); px(im, i, 15, NETC[1])
    return im


# La red: 24x24. Cuadros 1-3 se despliega (ovillo, a medias, abierta); 4-5 abierta girada 30° y 60° (gira: la malla
# cuadrada se repite cada 90°). Malla de 16 px con nudos oscuros y plomos en las esquinas.
NW_ = 24


def line(im, x0, y0, x1, y1, c):
    """Línea de 1 px (Bresenham) entre puntos enteros."""
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        px(im, x0, y0, c)
        if x0 == x1 and y0 == y1:
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy; x0 += sx
        if e2 <= dx:
            err += dx; y0 += sy


def net_open(deg):
    """La red abierta (malla de 16 con cuerdas cada 4) girada `deg` grados alrededor del centro: líneas de 1 px."""
    import math
    im = new(NW_, NW_)
    c = NW_ // 2
    ca, sa = math.cos(math.radians(deg)), math.sin(math.radians(deg))

    def at(u, v):
        return round(c + (u - 8) * ca - (v - 8) * sa), round(c + (u - 8) * sa + (v - 8) * ca)
    for i in range(0, 17, 4):
        line(im, *at(i, 0), *at(i, 16), NETC[1])
        line(im, *at(0, i), *at(16, i), NETC[1])
    for i in range(0, 17, 4):
        for j in range(0, 17, 4):
            px(im, *at(i, j), NETC[0])                                         # nudos
    for (u, v) in ((0, 0), (16, 0), (0, 16), (16, 16)):                       # plomos
        x, y = at(u, v)
        rect(im, x - 1, y - 1, x, y, IRON[0])
    return im


def net_frame(k):
    if k >= 2:
        return net_open([0, 30, 60][k - 2])
    im = new(NW_, NW_)
    c = NW_ // 2
    if k == 0:                                     # ovillo: la red plegada, un nudo apretado con los plomos asomando
        rect(im, c - 3, c - 3, c + 2, c + 2, NETC[0]); rect(im, c - 2, c - 2, c + 1, c + 1, NETC[1])
        px(im, c - 1, c - 1, NETC[0]); px(im, c, c, NETC[0])
        for (x, y) in ((c - 4, c - 4), (c + 2, c - 4), (c - 4, c + 2), (c + 2, c + 2)):
            rect(im, x, y, x + 1, y + 1, IRON[0])
    else:                                          # a medias: malla de 10 con los bordes aún recogidos
        for i in range(-4, 6, 3):
            rect(im, c + i, c - 5, c + i, c + 4, NETC[1]); rect(im, c - 5, c + i, c + 4, c + i, NETC[1])
        for i in range(-4, 6, 3):
            for j in range(-4, 6, 3):
                px(im, c + i, c + j, NETC[0])
        rect(im, c - 6, c - 6, c - 5, c - 5, IRON[0]); rect(im, c + 4, c - 6, c + 5, c - 5, IRON[0])
        rect(im, c - 6, c + 4, c - 5, c + 5, IRON[0]); rect(im, c + 4, c + 4, c + 5, c + 5, IRON[0])
    return im


# ══ LA RISA (como la del Espejo: cabeza en blanco + cara de carcajada encima, la cabeza sube y baja) ══════════════════
# pilot_laugh-Sheet (9x16 ×2): A = cabeza arriba (antenas tiesas) + brazos arriba; B = cabeza 1 px abajo (antenas
# abiertas) + brazos abajo. La cabeza, sin ojos. joy_face.png (5x3): la cara de la carcajada, se pinta encima
# (en la columna 2, fila 4 del piloto; + 1 fila en el cuadro B).
LAUGH_BODY = {
    'up':   ['A...A...A', '.A.EAA.A.', '..AAAAA..', '...AAA...', '....A....'],              # filas 8..12
    'down': ['....A....', '...EAA...', '..AAAAA..', '.A.AAA.A.', 'A...A...A'],
}
JOY_AT = (2, 4)


def blank_head(down):
    h = head('Idle1')
    px(h, 3, 5, WHITE); px(h, 5, 5, WHITE)          # sin ojos
    im = new(9, 9)
    if down:
        im.alpha_composite(h, (0, 1))
    else:
        rect(h, 0, 0, 8, 1, (0, 0, 0, 0))            # antenas tiesas, hacia arriba
        for (x, y) in ((2, 0), (6, 0), (3, 1), (5, 1)):
            px(h, x, y, BLACK)
        im.alpha_composite(h, (0, 0))
    return im


def pilot_laugh(down):
    im = new(9, 16)
    draw_rows(im, 8, LAUGH_BODY['down' if down else 'up']); draw_rows(im, 13, LEGS['stand'])
    im.alpha_composite(blank_head(down), (0, 0))
    return im


def joy_face():
    """La cara de la carcajada (5x3, sobre la cabeza en blanco): los ojos subidos por la risa y la boca abierta de lado
    a lado. Con 5 px de cara no caben dos «^» ni «> <» (se pegan al contorno y se leen como ojos normales o «X X»)."""
    im = new(5, 3)
    for (x, y) in ((1, 0), (3, 0), (1, 2), (2, 2), (3, 2)):
        px(im, x, y, BLACK)
    return im


# ══ ENFADADO (11x16: el piloto con 2 columnas de más a la izquierda; el puño de delante en alto) ═════════════════════
ANGRY_DX = 2


def pilot_angry():
    im = new(9 + ANGRY_DX, 16)
    h = head('Idle1')
    px(h, 3, 5, WHITE); px(h, 5, 5, WHITE)
    for (x, y) in ((2, 4), (3, 5), (6, 4), (5, 5), (4, 6)):                  # ojos de enfado «\ /» y la boca apretada
        px(h, x, y, BLACK)
    rect(h, 0, 0, 8, 1, (0, 0, 0, 0))                                        # antenas tiesas
    for (x, y) in ((2, 0), (6, 0), (3, 1), (5, 1)):
        px(h, x, y, BLACK)
    im.alpha_composite(h, (ANGRY_DX, 0))
    # cuerpo: el brazo de detrás al manillar, el de delante sube con el puño cerrado junto a la cabeza
    body = ['....A....', '...EAA...', '..AAAAA..', '...AAA.A.', '....A...A']
    for j, r in enumerate(body):
        for x, ch in enumerate(r):
            if ch == 'A':
                px(im, x + ANGRY_DX, 8 + j, BLACK)
            elif ch == 'E':
                px(im, x + ANGRY_DX, 8 + j, SHADE)
    for (x, y) in ((3, 9), (2, 8), (1, 7), (1, 6)):                          # el brazo que sube
        px(im, x, y, BLACK)
    rect(im, 0, 4, 1, 5, BLACK)                                               # el puño
    draw_rows_off(im, 13, LEGS['stand'], ANGRY_DX)
    return im


def draw_rows_off(im, y0, rows, dx):
    for j, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == 'A':
                px(im, x + dx, y0 + j, BLACK)


# ══ HUMO Y CHISPAS ═════════════════════════════════════════════════════════════════════════════════════════════════
SMOKE = [hx('545462'), hx('8a8a98'), hx('c4c4cc')]


def puff(k, pal):
    """Bocanada de 8x8: k 0 pequeña y densa, 1 grande, 2 deshaciéndose. pal = (oscuro, medio, claro)."""
    im = new(8, 8)
    if k == 0:
        rect(im, 2, 3, 5, 5, pal[0]); rect(im, 3, 2, 4, 6, pal[0]); rect(im, 3, 3, 4, 4, pal[1])
    elif k == 1:
        rect(im, 1, 2, 6, 6, pal[0]); rect(im, 2, 1, 5, 7, pal[0])
        rect(im, 2, 2, 5, 5, pal[1]); rect(im, 2, 2, 3, 3, pal[2])
    else:
        for (x, y) in ((0, 1), (5, 0), (6, 5), (1, 6)):
            rect(im, x, y, x + 1, y + 1, pal[1])
        rect(im, 3, 3, 4, 4, pal[2])
    return im


def spark(k):
    im = new(7, 7)
    if k == 0:
        rect(im, 3, 1, 3, 5, FIRE[1]); rect(im, 1, 3, 5, 3, FIRE[1]); px(im, 3, 3, FIRE[2])
    elif k == 1:
        for (x, y) in ((0, 0), (6, 0), (0, 6), (6, 6), (3, 0), (3, 6), (0, 3), (6, 3)):
            px(im, x, y, FIRE[0])
        rect(im, 2, 2, 4, 4, FIRE[1]); px(im, 3, 3, FIRE[2])
    else:
        for (x, y) in ((0, 0), (6, 0), (0, 6), (6, 6)):
            px(im, x, y, FIRE[0])
        px(im, 3, 3, FIRE[0])
    return im


def bomb(frame):
    im = new(14, 18)
    ellipse(im, 7, 11, 6, 6, [hx('0c0c12'), hx('16161e'), hx('34343f'), hx('6a6a7c')])
    rect(im, 5, 3, 8, 5, IRON[0]); rect(im, 6, 3, 7, 4, IRON[2])                   # cuello
    px(im, 8, 2, ROPE); px(im, 9, 1, ROPE)                                        # mecha
    sp = (9, 0) if frame == 0 else (10, 1)
    rect(im, sp[0] - 1, sp[1], sp[0] + 1, sp[1] + 1, FIRE[0]); px(im, sp[0], sp[1], FIRE[2])
    if frame:
        px(im, 8, 0, FIRE[1])
    rect(im, 6, 10, 8, 12, FIRE[0]); px(im, 7, 11, FIRE[1])                       # brillo de dentro («bomba brillante»)
    return im


def mark(frame):
    """La marca de la bomba lanzada (12x12): cuatro esquinas de mira (bloques, como el resto del arte) y un punto en
    el centro, que laten — abiertas y oscuras / cerradas y claras."""
    im = new(12, 12)
    o = 0 if frame == 0 else 1
    edge, core = (RED[0], FIRE[0]) if frame == 0 else (FIRE[0], FIRE[1])
    for (sx, sy) in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        x0 = o if sx > 0 else 11 - o
        y0 = o if sy > 0 else 11 - o
        for i in range(4):                                                     # la L de la esquina (2 px de grosor)
            px(im, x0 + sx * i, y0, edge); px(im, x0, y0 + sy * i, edge)
        for i in range(1, 3):
            px(im, x0 + sx * i, y0 + sy, core); px(im, x0 + sx, y0 + sy * i, core)
    rect(im, 5, 5, 6, 6, FIRE[1] if frame == 0 else FIRE[2])                      # el centro
    return im


def parts():
    """Cuatro piezas de 14x14 que salen volando: trapo de globo, tabla, pala de hélice y trozo de cañón."""
    ps = []
    a = new(14, 14); ImageDraw.Draw(a).polygon([(1, 3), (8, 0), (13, 5), (9, 12), (3, 10)], fill=RED[0])
    ImageDraw.Draw(a).polygon([(3, 4), (8, 2), (11, 5), (8, 10), (4, 9)], fill=RED[2]); rect(a, 5, 4, 7, 4, RED[3]); ps.append(a)
    b = new(14, 14); rect(b, 0, 4, 13, 9, WOOD[0]); rect(b, 1, 5, 12, 8, WOOD[2]); rect(b, 1, 8, 12, 8, WOOD[1]); px(b, 3, 6, WOOD[0]); ps.append(b)
    c = new(14, 14); rect(c, 5, 0, 8, 13, IRON[0]); rect(c, 6, 1, 7, 12, IRON[2]); rect(c, 6, 1, 6, 12, IRON[3]); ps.append(c)
    d = new(14, 14); rect(d, 1, 3, 12, 10, IRON[0]); rect(d, 2, 4, 11, 9, IRON[1]); rect(d, 2, 4, 11, 5, IRON[2]); rect(d, 4, 5, 6, 8, IRON[0]); ps.append(d)
    return sheet(ps)


def build():
    return {
        'machine-Sheet.png': sheet([machine(0), machine(1), machine(-1)]),
        'machine_popped-Sheet.png': sheet([machine_popped(0), machine_popped(1)]),
        'cannon-Sheet.png': sheet([cannon(False), cannon(True)]),
        'cannon_arm-Sheet.png': cannon_arm(),
        'propeller-Sheet.png': sheet([propeller(i) for i in range(4)]),
        'claw.png': claw(),
        'pilot-Sheet.png': sheet([pilot('pedal1'), pilot('pedal2'), pilot('laugh'), pilot('hurt')]),
        'pilot_laugh-Sheet.png': sheet([pilot_laugh(False), pilot_laugh(True)]),
        'joy_face.png': joy_face(),
        'pilot_angry.png': pilot_angry(),
        'pilot_flee-Sheet.png': sheet([pilot_flee(0), pilot_flee(1)]),
        'net.png': net(),
        'net-Sheet.png': sheet([net_frame(k) for k in range(5)]),
        'puff-Sheet.png': sheet([puff(k, SMOKE) for k in range(3)] + [puff(k, (NETC[0], NETC[1], WHITE)) for k in range(3)]),
        'spark-Sheet.png': sheet([spark(k) for k in range(3)]),
        'bomb-Sheet.png': sheet([bomb(0), bomb(1)]),
        'mark-Sheet.png': sheet([mark(0), mark(1)]),
        'parts.png': parts(),
    }


def up(im, k=K):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


# Montaje como en el juego (netcopter.lua): cañón en CANNON_OUT con su brazo hasta la placa, hélice en PROP_AT
CANNON_OUT, CANNON_Y = -12, 42
COLLAR_DX, PLATE_X = 12, 9


def crop(sh, i, w, h):
    return sh.crop((i * w, 0, (i + 1) * w, h))


def assemble(files, look='machine', mf=0, pilot=None, pdx=0, prop=0, glow=False, recoil=0, eyes=None):
    """La máquina montada (mirando a la izquierda) en un lienzo con 14 px de margen a la izquierda."""
    L = 14
    im = new(MW + L, MH)
    cx = CANNON_OUT + recoil
    im.alpha_composite(crop(files['cannon-Sheet.png'], 1 if glow else 0, 18, 12), (L + cx, CANNON_Y))
    arm = files['cannon_arm-Sheet.png']
    c0 = cx + COLLAR_DX
    for x in range(c0 + 3, PLATE_X):
        im.alpha_composite(crop(arm, 1, 3, 12).crop((0, 0, 1, 12)), (L + x, CANNON_Y))
    im.alpha_composite(crop(arm, 0, 3, 12), (L + c0, CANNON_Y))
    im.alpha_composite(crop(arm, 2, 3, 12), (L + PLATE_X, CANNON_Y))
    im.alpha_composite(crop(files[look + '-Sheet.png'], mf, MW, MH), (L, 0))
    im.alpha_composite(crop(files['propeller-Sheet.png'], prop, PROP_W, PROP_H), (L + PROP_AT[0], PROP_AT[1]))
    if pilot is not None:
        im.alpha_composite(pilot, (L + PILOT_AT[0] - pdx, PILOT_AT[1]))
    if eyes is not None:
        im.alpha_composite(files['joy_face.png'], (L + PILOT_AT[0] + JOY_AT[0], PILOT_AT[1] + JOY_AT[1] + eyes))
    return im


def preview(files):
    W, H = 1700, 1400
    pv = Image.new('RGBA', (W, H), SKY)

    def put(im, x, y, k=K):
        pv.alpha_composite(im.resize((im.width * k, im.height * k), Image.NEAREST), (x, y))
    ps = files['pilot-Sheet.png']
    pl = files['pilot_laugh-Sheet.png']
    # fila 1: pedalea (mirando a la izquierda), dispara con retroceso, y en espejo (mirando a la derecha)
    a = assemble(files, pilot=crop(ps, 0, 9, 16), prop=0)
    put(a, 10, 10)
    b = assemble(files, pilot=crop(ps, 1, 9, 16), prop=1, glow=True, recoil=1)
    put(b, 380, 10)
    put(a.transpose(Image.FLIP_LEFT_RIGHT), 750, 10)
    # fila 2: se ríe (dos cuadros con la cara de la carcajada), enfadado, fase 2
    put(assemble(files, pilot=crop(pl, 0, 9, 16), eyes=0, prop=2, mf=1), 10, 360)
    put(assemble(files, pilot=crop(pl, 1, 9, 16), eyes=1, prop=3, mf=2), 380, 360)
    put(assemble(files, pilot=files['pilot_angry.png'], pdx=ANGRY_DX, prop=0), 750, 360)
    put(assemble(files, look='machine_popped', mf=1, pilot=crop(ps, 3, 9, 16), prop=1), 1120, 360)
    # el piloto: monstrito1 junto a sus cuadros, al doble (para ver los píxeles)
    mon = Image.open(os.path.join(ROOT, 'assets', 'images', 'player', 'monstrito1.png')).convert('RGBA')
    put(mon, 1130, 20, 8); put(ps, 1220, 20, 8)
    put(pl, 1130, 170, 8); put(files['pilot_angry.png'], 1290, 170, 8)
    lj = new(9, 16); lj.alpha_composite(crop(pl, 0, 9, 16)); lj.alpha_composite(files['joy_face.png'], JOY_AT)
    put(lj, 1400, 170, 8)
    # fila 3: piezas
    put(files['propeller-Sheet.png'], 10, 720); put(files['cannon-Sheet.png'], 340, 720)
    put(files['cannon_arm-Sheet.png'], 580, 720); put(files['claw.png'], 700, 720)
    put(files['pilot_flee-Sheet.png'], 1080, 720)
    put(files['net-Sheet.png'], 10, 900)
    put(files['bomb-Sheet.png'], 700, 900); put(files['mark-Sheet.png'], 900, 900); put(files['parts.png'], 1080, 900)
    put(files['puff-Sheet.png'], 10, 1060); put(files['spark-Sheet.png'], 340, 1060)
    put(files['machine-Sheet.png'], 520, 1060, 3); put(files['machine_popped-Sheet.png'], 950, 1060, 3)
    return pv


def main():
    files = build()
    os.makedirs(OUT, exist_ok=True)
    preview(files).convert('RGB').save(os.path.join(OUT, 'vista_previa.png'))
    print('vista previa:', os.path.join(OUT, 'vista_previa.png'))
    if '--apply' in sys.argv:
        os.makedirs(DEST, exist_ok=True)
        for n, im in files.items():
            im.save(os.path.join(DEST, n))
            print('escrito', n, im.size)


if __name__ == '__main__':
    main()
