#!/usr/bin/env python3
# tools/ui/make_gummy_variants.py — variantes del GUMMY (propuestas para elegir):
#   · Gummy HELADO (niveles helados): la MISMA forma del Gummy (cada píxel del original:
#     assets/images/gummy/gummy*.png, 16x16) con su estilo de hielo + detalles por opción.
#   · MEGA GUMMY (jefe o enemigo grande): el Gummy en grande, al mismo tamaño de píxel que el
#     Mega Crabby (escala 10), con su misma cara y detalles propios por opción.
#
#   python3 tools/ui/make_gummy_variants.py      # vista previa (fuera del repo)
#   (--out DIR; por defecto $FM_PREVIEWS/gummy_variantes o /home/mtvemo/FlappyMonster_pruebas/...)
#
# Vista previa: opciones.png (todas las opciones ampliadas, cuadros quieto / andar 1 / andar 2 /
# muerto), maqueta.png (a escala de juego en un nivel helado y en uno normal, junto al Gummy,
# al Gummy con casco y con alas, al jugador y al Mega Crabby), anim_<X>.gif (andar y respirar).
import argparse
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'assets', 'images', 'gummy')

OUT_C = (30, 30, 42)
# Paleta del Gummy original → hielo
ICE = {(255, 255, 255): (236, 250, 255), (242, 242, 246): (190, 228, 250), (196, 200, 214): (120, 172, 222)}
FROST = (250, 252, 255)
FROST_S = (206, 226, 246)
DEEP = (86, 136, 200)


def load(n):
    return Image.open(os.path.join(SRC, n)).convert('RGBA')


def recolor(im, table):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p[:3] in table:
                px[x, y] = table[p[:3]] + (p[3],)
    return out


def put(im, pts, col):
    for x, y in pts:
        if 0 <= x < im.width and 0 <= y < im.height:
            im.putpixel((x, y), col + (255,))


# ── Gummy helado: opciones (sobre cada cuadro del original) ───────────────────
# Filas del Gummy: cuerpo 2..12 (contorno arriba en la fila 2), patas 13..15.
def icy_A(im, dead=False):
    """Escarcha: cuerpo de hielo + gorro de nieve en lo alto + carámbanos colgando de la barriga"""
    im = recolor(im, ICE)
    if dead:
        put(im, [(4, 11), (5, 11), (6, 11), (7, 11)], FROST)
        return im
    # gorro de nieve (bultitos encima del contorno y nieve en la fila de arriba)
    put(im, [(4, 1), (5, 1), (7, 1), (8, 1), (9, 1)], OUT_C)
    put(im, [(3, 2), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2), (9, 2), (10, 2)], FROST)
    put(im, [(6, 1)], FROST)
    put(im, [(3, 3), (4, 3), (8, 3), (9, 3)], FROST_S)
    # carámbanos bajo la barriga (entre las patas no: a los lados)
    put(im, [(3, 13), (11, 13)], DEEP)
    put(im, [(3, 14), (11, 14)], OUT_C)
    return im


def icy_B(im, dead=False):
    """Cubito: hielo translúcido con un brillo en diagonal y escarcha en las mejillas"""
    im = recolor(im, ICE)
    if dead:
        return im
    put(im, [(3, 4), (4, 4), (3, 5), (12, 8), (12, 9)], FROST)        # brillo + reflejo
    put(im, [(3, 8), (11, 8)], (255, 205, 220))                       # mejillas rosadas (frío)
    put(im, [(6, 3), (7, 3)], FROST)
    return im


def icy_C(im, dead=False):
    """Cristal: cuerpo de hielo con dos cristales de hielo en la cabeza (como orejas)"""
    im = recolor(im, ICE)
    if dead:
        return im
    for x0 in (4, 9):
        put(im, [(x0, 0), (x0, 1)], OUT_C)
        put(im, [(x0 - 1, 1), (x0 + 1, 1)], OUT_C)
        put(im, [(x0, 2)], FROST)
        put(im, [(x0, 1)], FROST_S)
    put(im, [(3, 8), (11, 8)], DEEP)
    return im


ICY = {'A': ('Escarcha', 'nieve en la cabeza y carambanos', icy_A),
       'B': ('Cubito', 'hielo translucido, brillo y mejillas frias', icy_B),
       'C': ('Cristal', 'dos cristales de hielo en la cabeza', icy_C)}


def icy_frames(opt):
    f = ICY[opt][2]
    return [f(load(n)) for n in ('gummy.png', 'gummy1.png', 'gummy2.png')] + [f(load('dead.png'), dead=True)]


# ── Mega Gummy: cuerpo grande (elipse con el estilo del Gummy) + cara + extras ─
MW, MH = 20, 20                       # lienzo del Mega Gummy (px de arte; escala 10 en el juego)
WHITE, BODY, SHADE = (255, 255, 255), (242, 242, 246), (196, 200, 214)
PINK = {WHITE: (255, 214, 232), BODY: (248, 160, 200), SHADE: (214, 104, 158)}
MOUTH = (110, 34, 52)


def mega_body(pal=None):
    im = Image.new('RGBA', (MW, MH), (0, 0, 0, 0))
    cx, cy, rx, ry = 9.5, 8.5, 9.4, 8.4
    inside = set()
    for y in range(MH):
        for x in range(MW):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                inside.add((x, y))
    for (x, y) in inside:
        edge = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            c = OUT_C
        else:
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = nx * 0.6 + ny * 0.8
            c = WHITE if d < -0.55 else (SHADE if d > 0.45 else BODY)
            if pal: c = pal[c]
        im.putpixel((x, y), c + (255,))
    return im


def mega_face(im, brows=False, mouth='smile', cheeks=None):
    for x in (6, 13):                                      # ojos: rayas de 3, como el Gummy
        put(im, [(x, 5), (x, 6), (x, 7)], OUT_C)
    if brows:                                              # cejas enfadadas
        put(im, [(4, 3), (5, 4), (15, 3), (14, 4)], OUT_C)
    if cheeks:
        put(im, [(4, 9), (15, 9)], cheeks)
    if mouth == 'smile':                                   # la sonrisa del Gummy, más ancha
        put(im, [(6, 10), (13, 10)], OUT_C)
        put(im, [(x, 11) for x in range(6, 14)], OUT_C)
    else:                                                  # boca abierta con dos colmillos
        put(im, [(x, 10) for x in range(6, 14)], OUT_C)
        put(im, [(6, 11), (13, 11)], OUT_C)
        put(im, [(x, 11) for x in range(7, 13)], MOUTH)
        put(im, [(8, 11), (11, 11)], WHITE)
        put(im, [(x, 12) for x in range(7, 13)], OUT_C)
    return im


LEGS = [  # (quieto, andar 1, andar 2): patas de 2 px y pies de 4
    ((6, 0), (12, 0)), ((5, -1), (12, 0)), ((6, 0), (13, 1)),
]


def mega_legs(im, i):
    for lx, foot in LEGS[i]:
        put(im, [(lx, 17), (lx + 1, 17), (lx, 18), (lx + 1, 18)], OUT_C)
        put(im, [(lx - 1 + foot + k, 19) for k in range(4)], OUT_C)


def mega_crown(im):
    put(im, [(7, 0), (9, 0), (11, 0)], OUT_C)
    put(im, [(x, 1) for x in range(6, 14)], OUT_C)
    put(im, [(7, 1), (9, 1), (11, 1)], (255, 210, 70))
    put(im, [(8, 1), (10, 1), (12, 1)], (230, 170, 40))
    return im


def mega_drips(im, pal):
    """Gelatina: goterones colgando del borde de abajo y burbujas dentro"""
    for x, h in ((3, 1), (9, 2), (16, 1)):
        for k in range(h):
            put(im, [(x, 16 + k)], pal[BODY])
        put(im, [(x - 1, 16), (x + 1, 16)], OUT_C)
        put(im, [(x, 16 + h)], OUT_C)
    put(im, [(4, 6), (16, 12), (15, 5)], pal[WHITE])
    return im


def mega_frame(opt, i, dead=False):
    pal = PINK if opt == 'C' else None
    if dead:                                    # aplastado (como dead.png), ojos en X
        im = Image.new('RGBA', (MW, MH), (0, 0, 0, 0))
        b = mega_body(pal).resize((MW, 7), Image.NEAREST)
        im.alpha_composite(b, (0, MH - 7))
        for x in (6, 13):
            put(im, [(x - 1, MH - 5), (x, MH - 4), (x + 1, MH - 5), (x - 1, MH - 3), (x + 1, MH - 3)], OUT_C)
        return im
    im = mega_body(pal)
    mega_legs(im, i)
    if opt == 'A':
        mega_face(im, brows=True, mouth='fangs')
    elif opt == 'B':
        mega_face(im, brows=True, cheeks=(255, 190, 200))
        mega_crown(im)
    else:
        mega_face(im, mouth='fangs')
        mega_drips(im, pal)
    return im


MEGA = {'A': ('Grandullon', 'cejas enfadadas, boca abierta con colmillos'),
        'B': ('Rey Gummy', 'cejas, mofletes y coronita de oro'),
        'C': ('Gelatina', 'rosa, goterones colgando, burbujas y colmillos')}


def mega_frames(opt):
    return [mega_frame(opt, i) for i in range(3)] + [mega_frame(opt, 0, dead=True)]


# ── Vista previa ──────────────────────────────────────────────────────────────
def up(im, k):
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.NEAREST)


def text(d, xy, s, fill=(255, 255, 255)):
    d.text(xy, s, fill=fill, font=ImageFont.load_default())


def background(w, h, floor, icy):
    bg = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    px = bg.load()
    for y in range(h):
        k = (y // 16) * 16 / max(1, floor)
        if y < floor:
            c = (int(86 + 50 * k), int(118 + 50 * k), int(176 - 10 * k)) if icy else (int(96 + 60 * k), int(160 + 40 * k), int(220 - 20 * k))
        else:
            c = ((236, 244, 255) if y < floor + 6 else (200, 218, 240)) if icy else ((110, 180, 70) if y < floor + 6 else (130, 90, 60))
        for x in range(w):
            px[x, y] = c + (255,)
    return bg


def preview(out):
    os.makedirs(out, exist_ok=True)
    names = ['quieto', 'andar 1', 'andar 2', 'muerto']
    # 1) opciones
    Z, Zm = 8, 6
    im = Image.new('RGBA', (1500, 940), (52, 58, 80, 255))
    d = ImageDraw.Draw(im)
    text(d, (20, 10), 'GUMMY HELADO (16x16, escala 4 en el juego) - cuadros: ' + ' / '.join(names))
    orig = [load(n) for n in ('gummy.png', 'gummy1.png', 'gummy2.png', 'dead.png')]
    y = 30
    text(d, (20, y), 'original')
    for i, f in enumerate(orig):
        im.alpha_composite(up(f, Z), (150 + i * 140, y))
    y += 140
    for k, (nm, desc, _) in sorted(ICY.items()):
        text(d, (20, y), 'OPCION %s: %s' % (k, nm))
        text(d, (20, y + 14), desc)
        for i, f in enumerate(icy_frames(k)):
            im.alpha_composite(up(f, Z), (150 + i * 140, y))
        y += 140
    x0 = 760
    text(d, (x0, 10), 'MEGA GUMMY (20x19, escala 10 como el Mega Crabby)')
    y = 30
    for k, (nm, desc) in sorted(MEGA.items()):
        text(d, (x0, y), 'OPCION %s: %s' % (k, nm))
        text(d, (x0, y + 14), desc)
        for i, f in enumerate(mega_frames(k)):
            im.alpha_composite(up(f, Zm), (x0 + 130 + i * 125 - 60, y + 30))
        y += 160 + 120
    im.convert('RGB').save(os.path.join(out, 'opciones.png'))

    # 2) maqueta a escala de juego
    W, H, floor = 1600, 520, 420
    for icy in (True, False):
        bg = background(W, H, floor, icy)
        d = ImageDraw.Draw(bg)
        pl = os.path.join(ROOT, 'assets', 'images', 'player', 'monstrito1.png')
        x = 40
        if os.path.exists(pl):
            p = up(load(pl), 6)
            bg.alpha_composite(p, (x, floor - p.height)); x += 110
        g = up(load('gummy.png'), 4)
        bg.alpha_composite(g, (x, floor - g.height)); text(d, (x, floor + 20), 'Gummy', (40, 40, 60)); x += 90
        hel = up(load('casco.png'), 4)
        bg.alpha_composite(g, (x, floor - g.height)); bg.alpha_composite(hel, (x, floor - g.height))
        text(d, (x, floor + 20), 'con casco', (40, 40, 60)); x += 100
        if icy:
            for k in sorted(ICY):
                f = up(icy_frames(k)[0], 4)
                bg.alpha_composite(f, (x, floor - f.height))
                text(d, (x - 10, floor + 20), 'helado %s' % k, (40, 40, 60))
                hx = x + 100                                       # con casco también
                bg.alpha_composite(f, (hx, floor - f.height)); bg.alpha_composite(hel, (hx, floor - f.height))
                text(d, (hx - 4, floor + 34), '+ casco', (40, 40, 60))
                x += 200
        for k in sorted(MEGA):
            f = up(mega_frames(k)[0], 10)
            bg.alpha_composite(f, (x, floor - f.height + 10))
            text(d, (x + 40, floor + 20), 'Mega %s' % k, (40, 40, 60))
            x += 230
        mc = os.path.join(ROOT, 'assets', 'images', 'MegaCrabby', 'crab1.png')
        if os.path.exists(mc) and x < W - 170:
            m = up(load(mc), 10)
            bg.alpha_composite(m, (x, floor - m.height)); text(d, (x + 30, floor + 20), 'Mega Crabby', (40, 40, 60))
            x += m.width + 20
        bg = bg.crop((0, 140, min(W, x + 20), H))
        bg.convert('RGB').save(os.path.join(out, 'maqueta_%s.png' % ('helada' if icy else 'normal')))

    # 3) animaciones: andar (quieto-1-quieto-2) y respirar (estirarse un poco al estar quieto)
    for kind, opts in (('helado', ICY), ('mega', MEGA)):
        for k in sorted(opts):
            fr = icy_frames(k) if kind == 'helado' else mega_frames(k)
            sc = 4 if kind == 'helado' else 10
            frames = []
            for f in range(24):
                bg = background(260, 240, 200, kind == 'helado')
                if f < 16:
                    img = fr[[0, 1, 0, 2][(f // 2) % 4]]
                else:
                    img = fr[0]
                    k2 = 1 + 0.06 * math.sin((f - 16) / 8 * math.pi * 2)
                    img = img.resize((img.width, max(1, round(img.height * k2))), Image.NEAREST)
                s = up(img, sc)
                bg.alpha_composite(s, (130 - s.width // 2, 200 - s.height + (10 if kind == 'mega' else 0)))
                frames.append(bg.convert('RGB'))
            frames[0].save(os.path.join(out, 'anim_%s_%s.gif' % (kind, k)), save_all=True,
                           append_images=frames[1:], duration=110, loop=0)
    print('vista previa:', out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(os.environ.get('FM_PREVIEWS', '/home/mtvemo/FlappyMonster_pruebas'),
                                                  'gummy_variantes'))
    a = ap.parse_args()
    preview(a.out)


if __name__ == '__main__':
    sys.exit(main())
