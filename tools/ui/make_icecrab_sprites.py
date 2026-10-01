#!/usr/bin/env python3
# tools/ui/make_icecrab_sprites.py — sprites del MEGA CRABBY HELADO (variante de hielo del jefe
# Mega Crabby), inspirado en el cangrejo antártico Paralomis birsteini: naranja, caparazón
# redondeado y lleno de espinas, patas y pinzas más LARGAS y espinosas, con escarcha encima.
# Mismo estilo y mismas piezas que el Mega Crabby (assets/images/MegaCrabby/): contorno azul
# marino oscuro, luz arriba a la izquierda, sombra abajo a la derecha, ojos de 1 px y boca
# ancha; así se reconoce como "su versión helada" y no como otro enemigo.
#
#   python3 tools/ui/make_icecrab_sprites.py                 # sprites + maqueta en --out
#   python3 tools/ui/make_icecrab_sprites.py --apply         # escribe assets/images/megacrabby_ice/
#   (--out DIR: carpeta de la vista previa; por defecto $FM_PREVIEWS/megacrabby_ice o
#    /home/mtvemo/FlappyMonster_pruebas/megacrabby_ice — fuera del repo)
#
# Piezas (como las del Mega Crabby):
#   crab1/2/3.png         cuerpo + patas, 3 cuadros de andar (36x20, a escala 5 = el tamaño del Mega)
#   claw_left-Sheet.png   pinza izquierda, 2 cuadros (abierta / cerrada), 18x10 (grande y larga, con púas)
#   spike.png             la púa de la cabeza, de HIELO (la del Mega recoloreada a azul hielo)
# Vista previa: vista_previa.png (Mega Crabby original vs helado, a escala de juego, sobre la
# pista de hielo, + las tiras ampliadas) y andar.gif (ciclo de andar con chasquidos de pinza).
import argparse
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'assets', 'images', 'MegaCrabby')
DST = os.path.join(ROOT, 'assets', 'images', 'megacrabby_ice')

PAL = {
    '.': None,
    'O': (30, 30, 42),        # contorno (el mismo de todo el juego)
    'H': (255, 216, 168),     # luz
    'L': (248, 158, 88),      # naranja claro
    'M': (226, 104, 50),      # naranja
    'S': (168, 62, 40),       # sombra
    'F': (236, 246, 255),     # escarcha
    'f': (176, 214, 242),     # escarcha en sombra
}

# ENFOQUE: más resolución, mismo tamaño en pantalla. El Mega Crabby es arte de 16x9 a
# escala 10 (160 px de ancho); el helado se dibuja a 32 px de ancho y escala 5, así que
# ocupa prácticamente lo mismo pero con detalle: tubérculos/espinas por todo el caparazón,
# patas articuladas largas y pinzas grandes. Se genera por geometría (elipses y segmentos
# rasterizados a mano, sin antialias) y luego se sombrea con la paleta de arriba: luz
# arriba a la izquierda, sombra abajo a la derecha, contorno oscuro de 1 px. Sin "boca":
# por delante el caparazón acaba en su borde, como el cangrejo real.
SCALE = 5                   # escala de juego propuesta (Mega Crabby: 10)
CLAW_X, CLAW_Y = 13.0, -9.0  # dónde van las pinzas (px de arte desde el centro-abajo del cuerpo)
BW, BH = 36, 20             # cuerpo + patas
CX, CY, RX, RY = 17.5, 7.0, 11.4, 5.6      # caparazón (elipse)
EYES = ((13, 6), (21, 6))        # 2x2, con brillo
# Patas (lado izquierdo; el derecho es su espejo con el paso contrario): raíz → rodilla
# (arriba y hacia fuera, como las patas largas del Paralomis) → punta en el suelo
LEGS = [
    [((9, 9), (3, 7), (0, 19)), ((12, 11), (7, 10), (5, 19))],
    [((9, 9), (3, 6), (1, 19)), ((12, 11), (8, 9), (8, 19))],
    [((9, 9), (4, 7), (3, 19)), ((12, 11), (6, 10), (3, 19))],
]
PHASE = [0, 2, 1]


def blank(w, h): return [['.'] * w for _ in range(h)]


def outline(g):
    """Contorno oscuro de 1 px alrededor de todo lo que no es transparente."""
    h, w = len(g), len(g[0])
    out = [r[:] for r in g]
    for y in range(h):
        for x in range(w):
            if g[y][x] == '.':
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and g[yy][xx] not in '.O':
                        out[y][x] = 'O'; break
    return out


def seg(a, b):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    return [(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)) for i in range(n + 1)]


def shell(g):
    for y in range(BH):
        for x in range(BW):
            dx, dy = (x + 0.5 - CX - 0.5) / RX, (y + 0.5 - CY) / RY
            if dx * dx + dy * dy <= 1:
                # luz por la normal: arriba-izquierda clara, abajo-derecha sombra
                l = -dx * 0.55 - dy * 0.85
                g[y][x] = 'H' if l > 0.62 else 'L' if l > 0.05 else 'M' if l > -0.55 else 'S'
    # tubérculos: bultitos (brillo + sombra debajo) repartidos sin cuadrícula, lejos de los ojos
    for x, y in ((9, 4), (16, 3), (24, 4), (27, 7), (7, 8), (11, 10), (17, 9), (24, 10), (20, 3), (13, 3)):
        if g[y][x] in 'LMS' and g[y + 1][x] != '.':
            g[y][x] = 'H'; g[y + 1][x] = 'S'
    # escarcha en lo alto del caparazón
    for x, y in ((10, 3), (11, 2), (12, 2), (13, 2), (14, 2), (15, 2), (21, 2), (22, 2), (23, 2), (9, 3), (16, 2)):
        if g[y][x] != '.': g[y][x] = 'F' if x < 18 else 'f'


def spines(g):
    """Púas: 1 px oscuro asomando por fuera del contorno, repartidas por el borde de arriba
    y los lados (se ponen DESPUÉS del contorno)."""
    for x, y in ((10, 1), (14, 0), (18, 0), (22, 0), (26, 1), (7, 3), (29, 3), (5, 6), (30, 6), (6, 10), (29, 10)):
        if g[y][x] == '.': g[y][x] = 'O'


def legs(g, frame):
    for side, fr in ((0, frame), (1, PHASE[frame])):
        for path in LEGS[fr]:
            pts = []
            for a, b in zip(path, path[1:]): pts += seg(a, b)
            if side: pts = [(BW - 1 - x, y) for x, y in pts]
            for k, (x, y) in enumerate(pts):
                if 0 <= y < BH and g[y][x] == '.':
                    g[y][x] = 'M' if k % 4 else 'S'           # (articulaciones más oscuras)


def body(frame):
    g = blank(BW, BH)
    legs(g, frame)
    shell(g)
    g = outline(g)
    spines(g)
    for x, y in EYES:                                         # ojos: 2x2 oscuros con brillo
        for dx in (0, 1):
            for dy in (0, 1): g[y + dy][x + dx] = 'O'
        g[y][x] = 'F'
    return [''.join(r) for r in g]


# Pinza izquierda (el dedo largo hacia la izquierda, la palma a la derecha, donde se une
# al cuerpo): GRANDE y LARGA, 18x10, con púas en el dorso. Cuadro 1 abierta, 2 cerrada.
CW, CH = 18, 10


def claw(opened):
    g = blank(CW, CH)
    for y in range(CH):                                       # palma (elipse)
        for x in range(CW):
            dx, dy = (x - 12.5) / 5.2, (y - 5.0) / 3.6
            if dx * dx + dy * dy <= 1:
                l = -dx * 0.4 - dy * 0.9
                g[y][x] = 'H' if l > 0.55 else 'L' if l > 0 else 'M' if l > -0.5 else 'S'
    # dedo de arriba (fijo): largo, se afila hacia la punta curvada
    for x in range(1, 9):
        g[3][x] = 'L' if x > 2 else 'M'
        if x > 3: g[2][x] = 'H' if x < 8 else 'L'
        if x > 5: g[4][x] = 'M'
    g[4][1] = 'M'                                              # punta hacia abajo
    # dedo de abajo (el que se mueve)
    y0 = 7 if opened else 5
    for x in range(3, 9):
        g[y0][x] = 'M' if x > 3 else 'S'
        if x > 5: g[y0 + 1][x] = 'S'
    if opened: g[y0 - 1][3] = 'S'                              # punta hacia arriba
    g = outline(g)
    for x in (9, 11, 13, 15):                                  # púas del dorso
        top = next(y for y in range(CH) if g[y][x] != '.')
        if top > 0: g[top - 1][x] = 'O'
    return [''.join(r) for r in g]


ICE = {(255, 255, 255): (226, 246, 255), (242, 242, 246): (186, 226, 250),
       (196, 200, 214): (118, 172, 222), (30, 30, 42): (30, 30, 42)}


def grid(rows):
    w = len(rows[0])
    for r in rows:
        assert len(r) == w, (len(r), r)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            c = PAL[ch]
            if c: im.putpixel((x, y), c + (255,))
    return im


def build():
    out = {}
    for i in range(3):
        out['crab%d.png' % (i + 1)] = grid(body(i))
    a, b = grid(claw(True)), grid(claw(False))
    sheet = Image.new('RGBA', (a.width * 2, a.height), (0, 0, 0, 0))
    sheet.paste(a, (0, 0)); sheet.paste(b, (a.width, 0))
    out['claw_left-Sheet.png'] = sheet
    sp = Image.open(os.path.join(SRC, 'spike.png')).convert('RGBA')
    px = sp.load()
    for y in range(sp.height):
        for x in range(sp.width):
            p = px[x, y]
            if p[3] and p[:3] in ICE: px[x, y] = ICE[p[:3]] + (p[3],)
    out['spike.png'] = sp
    return out


# ── Maqueta ──────────────────────────────────────────────────────────────────
def up(im, s): return im.resize((round(im.width * s), round(im.height * s)), Image.NEAREST)


def crab(canvas, body, claws, spike, cx, floor, s, claw_k=0.85, claw_x=4.6, claw_y=-1.6, frames=(0, 0),
         spike_s=None):
    """Monta el cangrejo como Mega:drawLocal (púa detrás, cuerpo, pinzas delante).
    claw_x / claw_y en px de arte del cuerpo desde su centro-abajo."""
    cs = max(1, round(s * claw_k))
    ss = spike_s or s / 4
    sk = spike.resize((round(spike.width * ss), round(spike.height * ss)), Image.NEAREST)
    canvas.alpha_composite(sk, (int(cx - sk.width / 2), int(floor - body.height * s - sk.height + 6 * ss)))
    b = up(body, s)
    canvas.alpha_composite(b, (cx - b.width // 2, floor - b.height))
    fw = claws.width // 2
    for i, side in enumerate((-1, 1)):
        fr = claws.crop((frames[i] * fw, 0, (frames[i] + 1) * fw, claws.height))
        if side > 0: fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
        c = up(fr, cs)
        x = cx + side * (claw_x * s + fw * cs / 2 - 1.5 * cs) - c.width / 2
        y = floor + claw_y * s - claws.height * cs / 2 - c.height / 2
        canvas.alpha_composite(c, (int(x), int(y)))


def background(w, h, floor):
    bg = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    px = bg.load()
    for y in range(h):                                         # cielo del atardecer en bandas
        k = (y // 24) * 24 / max(1, floor)
        c = (int(70 + 60 * k), int(80 + 50 * k), int(140 - 10 * k))
        for x in range(w): px[x, y] = c + (255,)
    for y in range(floor, h):
        c = (236, 244, 255) if y < floor + 8 else (200, 218, 240)
        for x in range(w): px[x, y] = c + (255,)
    return bg


def mockup(sprites, out):
    orig = {n: Image.open(os.path.join(SRC, n)).convert('RGBA')
            for n in ('crab1.png', 'claw_left-Sheet.png', 'spike.png')}
    W, H, floor = 1280, 1040, 470
    im = background(W, H, floor)
    try:
        from PIL import ImageDraw, ImageFont
        d = ImageDraw.Draw(im)
        font = ImageFont.load_default()
    except Exception:
        d = None
    crab(im, orig['crab1.png'], orig['claw_left-Sheet.png'], orig['spike.png'], 330, floor, 10)
    crab(im, sprites['crab1.png'], sprites['claw_left-Sheet.png'], sprites['spike.png'], 930, floor, SCALE,
         claw_k=1, claw_x=CLAW_X, claw_y=CLAW_Y, frames=(0, 1), spike_s=2.5)
    # jugador de referencia (tamaño)
    pl = os.path.join(ROOT, 'assets', 'images', 'player', 'monstrito1.png')
    if os.path.exists(pl):
        p = up(Image.open(pl).convert('RGBA'), 6)
        im.alpha_composite(p, (620, floor - p.height))
    if d:
        d.text((250, 40), 'MEGA CRABBY (actual) x10', fill=(255, 255, 255), font=font)
        d.text((830, 40), 'MEGA CRABBY HELADO x5 (propuesta: arte 32 px)', fill=(255, 255, 255), font=font)
    # tiras ampliadas: 3 cuadros de andar, 2 de pinza, púa
    y0 = floor + 140
    x = 40
    for n in ('crab1.png', 'crab2.png', 'crab3.png'):
        a = up(sprites[n], 6)
        im.alpha_composite(a, (x, y0)); x += a.width + 24
    c = up(sprites['claw_left-Sheet.png'], 7)
    im.alpha_composite(c, (x, y0)); x += c.width + 24
    s = up(sprites['spike.png'], 3)
    im.alpha_composite(s, (x, y0 - 10))
    if d:
        d.text((40, y0 - 22), 'andar 1-3 (x6)                                                              pinza abierta / cerrada (x7)', fill=(255, 255, 255), font=font)
    os.makedirs(out, exist_ok=True)
    im.convert('RGB').save(os.path.join(out, 'vista_previa.png'))
    # GIF: ciclo de andar (1-2-1-3) con chasquidos de pinza, junto al original
    frames = []
    seq = [1, 2, 1, 3]
    for i in range(16):
        f = background(760, 300, 250)
        n = seq[i % 4]
        o = Image.open(os.path.join(SRC, 'crab%d.png' % n)).convert('RGBA')
        crab(f, o, orig['claw_left-Sheet.png'], orig['spike.png'], 190, 250, 7, frames=((i // 3) % 2, (i // 5) % 2))
        crab(f, sprites['crab%d.png' % n], sprites['claw_left-Sheet.png'], sprites['spike.png'], 560, 250, 3.5,
             claw_k=1, claw_x=CLAW_X, claw_y=CLAW_Y, frames=((i // 3) % 2, (i // 5) % 2), spike_s=1.75)
        frames.append(f.convert('RGB'))
    frames[0].save(os.path.join(out, 'andar.gif'), save_all=True, append_images=frames[1:], duration=140, loop=0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--out', default=os.path.join(os.environ.get('FM_PREVIEWS', '/home/mtvemo/FlappyMonster_pruebas'),
                                                  'megacrabby_ice'))
    a = ap.parse_args()
    sp = build()
    os.makedirs(a.out, exist_ok=True)
    for n, im in sp.items(): im.save(os.path.join(a.out, n))
    mockup(sp, a.out)
    print('vista previa:', a.out)
    if a.apply:
        os.makedirs(DST, exist_ok=True)
        for n, im in sp.items(): im.save(os.path.join(DST, n))
        print('escrito', DST)


if __name__ == '__main__':
    sys.exit(main())
