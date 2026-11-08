#!/usr/bin/env python3
# tools/art/bosses/make_netcopter.py — el Redcóptero (jefe del Valle, campaña Flappy; docs/design/flappy-plan-5-netcopter.md).
# El Monstruo Malvado pedalea una máquina de chatarra: globo remendado, góndola de madera y una hélice de pedal.
# El piloto va en la MISMA rejilla 26x21 que miniboss1/monster/Idle1.png (blanco y negro, se amplía, no se rediseña).
# Sin alas en nada. Arte a x6 (el píxel del jugador): formas planas, 2-3 tonos por pieza, sin detalle fino.
#
#   python3 tools/art/bosses/make_netcopter.py           → vista_previa.png (fondo = cielo claro; el Valle aún no existe)
#   python3 tools/art/bosses/make_netcopter.py --apply   → assets/images/bosses/netcopter/
#
# Anclas (arte, en cuadro de máquina 44x40): la góndola abierta va en x 12..32, y 29..38; el piloto (26x21) se dibuja
# con su esquina arriba-izquierda en (9, 16) del cuadro (el cuerpo queda sentado sobre la góndola, y=29); el cañón se pega en (2, 28); la hélice gira en (38, 32).
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


# ══ LA MÁQUINA (cuadro 44x40) ═════════════════════════════════════════════════════════════════════════════════════
MW, MH = 44, 40


def gondola(im):
    rect(im, 12, 29, 32, 38, WOOD[0])
    rect(im, 13, 30, 31, 37, WOOD[2])
    rect(im, 13, 35, 31, 37, WOOD[1])
    rect(im, 13, 30, 31, 30, WOOD[3])
    for x in (18, 25):                               # tablas
        rect(im, x, 31, x, 37, WOOD[1])
    px(im, 15, 33, WOOD[0]); px(im, 29, 33, WOOD[0])  # clavos
    rect(im, 12, 29, 14, 29, WOOD[0]); rect(im, 30, 29, 32, 29, WOOD[0])


def ropes(im, y0=24, y1=29):
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


def machine(frame):
    im = new(MW, MH)
    ropes(im)
    ellipse(im, 22, 13, 18, 12.5, RED)
    # remiendos (amarillos, esquinas «cosidas»)
    rect(im, 11, 8, 17, 14, PATCH[0]); rect(im, 12, 9, 16, 13, PATCH[1]); rect(im, 12, 9, 16, 9, PATCH[2])
    px(im, 14, 11, PATCH[0])
    rect(im, 27, 15, 32, 19, PATCH[0]); rect(im, 28, 16, 31, 18, PATCH[1]); rect(im, 28, 16, 31, 16, PATCH[2])
    for x in range(8, 38, 6):                        # costuras
        px(im, x, 23 if x < 30 else 22, RED[0])
    gondola(im)
    propeller(im, frame)
    rect(im, 14, 28, 30, 28, WOOD[0])                # borde de la góndola, por delante del piloto
    return im


def machine_popped(frame):
    """Fase 2: el globo reventado cuelga como un trapo (más bajo) sobre las cuerdas."""
    im = new(MW, MH)
    ropes(im, 20, 29)
    d = frame
    pts = [(6, 18), (12, 12 + d), (22, 9), (32, 12 + d), (38, 18), (36, 24 + d), (28, 21), (22, 26 - d), (15, 21), (8, 25 + d)]
    ImageDraw.Draw(im).polygon(pts, fill=RED[0])
    inner = [(8, 18), (13, 14 + d), (22, 11), (31, 14 + d), (36, 18), (34, 22 + d), (28, 19), (22, 24 - d), (16, 19), (10, 22 + d)]
    ImageDraw.Draw(im).polygon(inner, fill=RED[2])
    rect(im, 18, 13, 26, 14, RED[3])
    for x in range(10, 36, 5):
        px(im, x, 20, RED[1]); px(im, x + 1, 21, RED[1])
    rect(im, 12, 15 + d, 16, 17 + d, PATCH[1])      # un remiendo que aguanta
    gondola(im)
    propeller(im, 1 - frame)
    rect(im, 14, 28, 30, 28, WOOD[0])
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


# ══ EL PILOTO (26x21, la rejilla de Idle1) ════════════════════════════════════════════════════════════════════════
def base_pilot(name='Idle1'):
    return Image.open(os.path.join(ROOT, 'assets', 'images', 'bosses', 'miniboss1', 'monster', name + '.png')).convert('RGBA')


def legs(im, f):
    """Piernas que pedalean bajo el cuerpo (fila 10 en adelante): f=0 izquierda abajo, f=1 derecha abajo."""
    for y in (10, 11, 12):                           # borra los pies de Idle1
        for x in range(8, 19):
            if y >= 10:
                px(im, x, y, (0, 0, 0, 0))
    px(im, 12, 10, BLACK); px(im, 14, 10, BLACK)
    if f == 0:
        for (x, y) in ((11, 11), (10, 12), (10, 13), (11, 13), (15, 11), (16, 11), (17, 11)):
            px(im, x, y, BLACK)
    else:
        for (x, y) in ((15, 11), (16, 12), (16, 13), (17, 13), (11, 11), (10, 11), (9, 11)):
            px(im, x, y, BLACK)


def pilot(kind):
    if kind == 'hurt':
        im = base_pilot('hurt'); legs(im, 0)
        return im
    im = base_pilot('Idle1')
    if kind in ('pedal1', 'pedal2'):
        legs(im, 0 if kind == 'pedal1' else 1)
        if kind == 'pedal2':                         # el cuerpo sube un píxel al pedalear fuerte
            im = im.transform(im.size, Image.AFFINE, (1, 0, 0, 0, 1, 1), resample=Image.NEAREST)
            legs(im, 1) if False else None
    elif kind == 'laugh':
        legs(im, 0)
        for x in (12, 13, 14):
            px(im, x, 8, BLACK)                      # boca abierta
        px(im, 11, 8, WHITE); px(im, 15, 8, WHITE)
        for (x, y) in ((8, 7), (18, 7), (7, 6), (19, 6)):
            px(im, x, y, BLACK)                      # brazos arriba, de risa
        for (x, y) in ((8, 8), (8, 9), (18, 8), (18, 9)):
            px(im, x, y, (0, 0, 0, 0))
    return im


def pilot_flee(frame):
    """Huye en un trozo de góndola con la hélice rota: 36x30, el piloto de Idle1 recortado encima."""
    im = new(36, 30)
    p = pilot('pedal1' if frame == 0 else 'pedal2')
    im.alpha_composite(p.crop((3, 0, 26, 17)), (10, 2))
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
    W, H = 1500, 1000
    pv = Image.new('RGBA', (W, H), SKY)
    d = ImageDraw.Draw(pv)

    def put(im, x, y):
        pv.alpha_composite(up(im), (x, y))
    # la máquina montada, fase 1 y fase 2 (piloto de risa), con el cañón
    for i, (nm, pil) in enumerate((('machine', 'pedal1'), ('machine_popped', 'laugh'))):
        sh = files[nm + ('' if nm == 'machine' else '') + '-Sheet.png']
        fr = sh.crop((0, 0, MW, MH))
        base = new(MW + 18, MH)
        base.alpha_composite(fr, (18, 0))
        base.alpha_composite(files['cannon-Sheet.png'].crop((0 if i == 0 else 18, 0, 18 if i == 0 else 36, 12)), (0, 28))
        base.alpha_composite(files['pilot-Sheet.png'].crop((26 * (2 if pil == 'laugh' else 0), 0, 26 * (3 if pil == 'laugh' else 1), 21)), (18 + 22 - 13, 16))
        fg = fr.crop((14, 28, 31, 29)); base.alpha_composite(fg, (18 + 14, 28))
        put(base, 20 + i * 400, 20)
    x = 20
    for nm in ('machine-Sheet.png', 'machine_popped-Sheet.png'):
        put(files[nm], x, 300); x += files[nm].width * K + 30
    put(files['cannon-Sheet.png'], 20, 560); put(files['claw.png'], 300, 560)
    put(files['bomb-Sheet.png'], 700, 560); put(files['net.png'], 900, 560); put(files['parts.png'], 1000, 560)
    put(files['pilot-Sheet.png'], 20, 760); put(files['pilot_flee-Sheet.png'], 700, 760)
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
