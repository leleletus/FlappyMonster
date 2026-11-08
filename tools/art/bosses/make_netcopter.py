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
# las manos en el manillar (y 39); el cañón en y 42; la hélice gira en (38, 46).
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


def ropes(im, y0, y1):
    for (xa, xb) in ((9, 13), (35, 31)):
        n = y1 - y0
        for i in range(n + 1):
            px(im, xa + (xb - xa) * i // n, y0 + i, ROPE)


def propeller(im, frame):
    """Hélice de pedal a la derecha: eje con manivela y dos palas (frame 0 vertical, 1 diagonal)."""
    rect(im, 33, 32, 37, 33, IRON[1]); rect(im, 33, 32, 37, 32, IRON[2])      # eje
    rect(im, 37, 30, 38, 35, IRON[0]); rect(im, 38, 31, 38, 34, IRON[1])      # buje
    if frame == 0:
        rect(im, 36, 24, 40, 29, IRON[0]); rect(im, 37, 25, 39, 28, IRON[2]); rect(im, 37, 25, 37, 28, IRON[3])
        rect(im, 36, 36, 40, 41 - 1, IRON[0]); rect(im, 37, 37, 39, 39, IRON[1])
    else:
        for i in range(5):
            rect(im, 39 + i - 1, 28 - i, 41 + i - 1, 29 - i, IRON[2]); px(im, 38 + i, 28 - i, IRON[0])
        for i in range(4):
            rect(im, 36 - i + 1, 36 + i, 38 - i + 1, 37 + i, IRON[1]); px(im, 39 - i, 36 + i, IRON[0])


def lower(frame):
    """La parte de abajo en sus coordenadas de siempre (góndola en y 29..38); se pega D filas más abajo."""
    lo = new(MW, MH - D)
    handlebar(lo)
    gondola(lo)
    propeller(lo, frame)
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


def machine(frame):
    im = new(MW, MH)
    ropes(im, 24, 29 + D)
    ellipse(im, 22, 13, 18, 12.5, RED)
    patches(im)
    for x in range(8, 38, 6):                        # costuras
        px(im, x, 23 if x < 30 else 22, RED[0])
    im.alpha_composite(lower(frame), (0, D))
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
    im.alpha_composite(lower(1 - frame), (0, D))
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
    rect(im, 12, 9, 16, 11, WOOD[0]); rect(im, 13, 10, 15, 11, WOOD[2])            # soporte
    return im


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
        'machine-Sheet.png': sheet([machine(0), machine(1)]),
        'machine_popped-Sheet.png': sheet([machine_popped(0), machine_popped(1)]),
        'cannon-Sheet.png': sheet([cannon(False), cannon(True)]),
        'claw.png': claw(),
        'pilot-Sheet.png': sheet([pilot('pedal1'), pilot('pedal2'), pilot('laugh'), pilot('hurt')]),
        'pilot_flee-Sheet.png': sheet([pilot_flee(0), pilot_flee(1)]),
        'net.png': net(),
        'bomb-Sheet.png': sheet([bomb(0), bomb(1)]),
        'parts.png': parts(),
    }


def up(im, k=K):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def preview(files):
    W, H = 1500, 1300
    pv = Image.new('RGBA', (W, H), SKY)

    def put(im, x, y):
        pv.alpha_composite(up(im), (x, y))
    # la máquina montada, fase 1 (pedalea) y fase 2 (se ríe), con el cañón desplegado
    for i, (nm, fr) in enumerate((('machine', 0), ('machine_popped', 2))):
        m = files[nm + '-Sheet.png'].crop((0, 0, MW, MH))
        base = new(MW + 18, MH)
        base.alpha_composite(files['cannon-Sheet.png'].crop((18 * i, 0, 18 * (i + 1), 12)), (0, 28 + D))
        base.alpha_composite(m, (18, 0))
        base.alpha_composite(files['pilot-Sheet.png'].crop((9 * fr, 0, 9 * (fr + 1), 16)), (18 + PILOT_AT[0], PILOT_AT[1]))
        put(base, 20 + i * 420, 20)
    # comparación: el jugador (monstrito1) junto a los cuadros del piloto, al mismo tamaño
    mon = Image.open(os.path.join(ROOT, 'assets', 'images', 'player', 'monstrito1.png')).convert('RGBA')
    put(mon, 900, 60); put(files['pilot-Sheet.png'], 980, 60)
    put(files['pilot_flee-Sheet.png'], 900, 200)
    x = 20
    for nm in ('machine-Sheet.png', 'machine_popped-Sheet.png'):
        put(files[nm], x, 380); x += files[nm].width * K + 30
    put(files['cannon-Sheet.png'], 20, 1100); put(files['claw.png'], 300, 1100)
    put(files['bomb-Sheet.png'], 700, 1100); put(files['net.png'], 900, 1100); put(files['parts.png'], 1000, 1100)
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
