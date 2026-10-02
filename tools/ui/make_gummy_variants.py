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
def icy_A(im, dead=False, icicles=False):
    """Escarcha: cuerpo de hielo + gorro de nieve en lo alto (+ carámbanos colgando: descartados
    por el usuario; la versión del juego va SIN ellos)"""
    im = recolor(im, ICE)
    if dead:
        put(im, [(4, 11), (5, 11), (6, 11), (7, 11)], FROST)
        return im
    # gorro de nieve (bultitos encima del contorno y nieve en la fila de arriba)
    put(im, [(4, 1), (5, 1), (7, 1), (8, 1), (9, 1)], OUT_C)
    put(im, [(3, 2), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2), (9, 2), (10, 2)], FROST)
    put(im, [(6, 1)], FROST)
    put(im, [(3, 3), (4, 3), (8, 3), (9, 3)], FROST_S)
    if icicles:                       # carámbanos bajo la barriga (a los lados)
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


ICY = {'A': ('Escarcha', 'nieve en la cabeza (elegida, sin carambanos)', icy_A),
       'B': ('Cubito', 'hielo translucido, brillo y mejillas frias', icy_B),
       'C': ('Cristal', 'dos cristales de hielo en la cabeza', icy_C)}


def icy_frames(opt):
    f = ICY[opt][2]
    return [f(load(n)) for n in ('gummy.png', 'gummy1.png', 'gummy2.png')] + [f(load('dead.png'), dead=True)]


# ── Mega Gummy: el MISMO sprite del Gummy (16x16) dibujado a escala 10, como el Mega Crabby es
# el Crabby a escala 10: misma resolución (un píxel del Gummy = un píxel del Mega) y solo
# retoques de 1 px sobre su rejilla (el usuario rechazó un cuerpo nuevo con más detalle).
MW, MH = 16, 16
WHITE, BODY, SHADE = (255, 255, 255), (242, 242, 246), (196, 200, 214)
PINK = {WHITE: (255, 214, 232), BODY: (248, 160, 200), SHADE: (214, 104, 158)}
MOUTH = (110, 34, 52)
GOLD, GOLD_S = (255, 210, 70), (220, 160, 40)


def brows(im):
    """cejas enfadadas: 1 px encima de cada ojo, inclinado hacia dentro (ojos en x5 y x9)"""
    put(im, [(4, 4), (10, 4)], OUT_C)
    put(im, [(5, 4), (9, 4)], BODY)


def fangs(im):
    """boca abierta: la sonrisa del Gummy (fila 10, x5-9) se abre una fila con dos colmillos"""
    put(im, [(5, 10), (6, 10), (7, 10), (8, 10), (9, 10)], MOUTH)
    put(im, [(5, 10), (9, 10)], WHITE)
    put(im, [(4, 10), (10, 10)], OUT_C)
    put(im, [(5, 11), (6, 11), (7, 11), (8, 11), (9, 11)], OUT_C)


def crown(im):
    put(im, [(5, 0), (7, 0), (9, 0)], OUT_C)
    put(im, [(4, 1), (10, 1)], OUT_C)
    put(im, [(5, 1), (7, 1), (9, 1)], GOLD)
    put(im, [(6, 1), (8, 1)], GOLD_S)


def drips(im, pal):
    for x in (3, 8, 11):
        put(im, [(x, 12)], pal[BODY])
        put(im, [(x, 13)], OUT_C)


def mega_frame(opt, i, dead=False):
    src = load(('gummy.png', 'gummy1.png', 'gummy2.png')[i] if not dead else 'dead.png')
    pal = PINK if opt == 'C' else None
    im = recolor(src, pal) if pal else src.copy()
    if dead:
        return im
    if opt == 'A':
        brows(im); fangs(im)
    elif opt == 'B':
        brows(im); crown(im)
    else:
        brows(im); fangs(im); drips(im, pal)
    return im


MEGA = {'A': ('Grandullon', 'cejas enfadadas y boca abierta con colmillos'),
        'B': ('Rey Gummy', 'cejas enfadadas y coronita de oro (elegida)'),
        'C': ('Gelatina', 'rosa, cejas, colmillos y goterones')}


def mega_frames(opt):
    return [mega_frame(opt, i) for i in range(3)] + [mega_frame(opt, 0, dead=True)]


# ── Jefe REY GUMMY (types/megagummy.lua): todo en la rejilla del Gummy (16x16, 1 px del Gummy =
# 1 px del jefe) con retoques de 1 px. La corona va APARTE (crown.png, misma rejilla): se dibuja
# encima y sale volando al dividirse. Cuadros de body-Sheet.png (16x16 cada uno):
#   1 quieto · 2-3 andar · 4 saltando (patas recogidas) · 5 mareado (ojos cruzados, boca en zigzag)
#   6 dolor (ojos > <, boca abierta) · 7 risa (ojos ^ ^, boca abierta) · 8 grito (fanfarria, boca abierta)
# Más: crown.png, wave-Sheet.png (ola de gelatina 12x8, 2 cuadros), stars-Sheet.png (estrellita de
# mareo 5x5, 2 cuadros), target-Sheet.png (marca de caída 16x4, 2 cuadros), shadow.png (16x3).
EYES = [(5, 5), (5, 6), (5, 7), (9, 5), (9, 6), (9, 7)]
SMILE = [(4, 9), (10, 9), (5, 10), (6, 10), (7, 10), (8, 10), (9, 10)]


def clear(im, pts):
    put(im, pts, BODY)


def open_mouth(im):
    put(im, [(5, 10), (6, 10), (7, 10), (8, 10), (9, 10)], MOUTH)
    put(im, [(4, 10), (10, 10)], OUT_C)
    put(im, [(5, 11), (6, 11), (7, 11), (8, 11), (9, 11)], OUT_C)


def boss_frames():
    base = [load(n) for n in ('gummy.png', 'gummy1.png', 'gummy2.png')]
    out = []
    for im in base:
        im = im.copy(); brows(im); out.append(im)
    idle = out[0]
    # 4 saltando: patas recogidas (solo los pies pegados a la barriga)
    j = idle.copy()
    for y in (13, 14, 15):
        for x in range(16):
            j.putpixel((x, y), (0, 0, 0, 0))
    put(j, [(4, 13), (5, 13), (6, 13), (8, 13), (9, 13), (10, 13)], OUT_C)
    out.append(j)
    # 5 mareado: ojos cruzados (uno arriba, otro abajo), sin cejas, boca en zigzag
    d = load('gummy.png')
    clear(d, EYES + SMILE)
    put(d, [(5, 5), (9, 7)], OUT_C)
    put(d, [(5, 10), (6, 9), (7, 10), (8, 9), (9, 10)], OUT_C)
    out.append(d)
    # 6 dolor: ojos apretados > <, boca abierta
    h = idle.copy()
    clear(h, EYES + SMILE)
    put(h, [(4, 5), (5, 6), (4, 7), (10, 5), (9, 6), (10, 7)], OUT_C)
    open_mouth(h)
    out.append(h)
    # 7 risa: ojos cerrados ^ ^, boca abierta
    r = load('gummy.png')
    clear(r, EYES + SMILE)
    put(r, [(4, 6), (5, 5), (6, 6), (8, 6), (9, 5), (10, 6)], OUT_C)
    open_mouth(r)
    out.append(r)
    # 8 grito (fanfarria): ojos normales y cejas, boca abierta
    g = idle.copy()
    clear(g, SMILE)
    open_mouth(g)
    out.append(g)
    return out


def sheet(frames):
    w, h = frames[0].size
    s = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    return s


def grid(rows, pal):
    h, w = len(rows), len(rows[0])
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                im.putpixel((x, y), pal[ch] + (255,))
    return im


def boss_art(dst):
    os.makedirs(dst, exist_ok=True)
    sheet(boss_frames()).save(os.path.join(dst, 'body-Sheet.png'))
    c = Image.new('RGBA', (MW, MH), (0, 0, 0, 0))     # la corona sola (misma rejilla 16x16)
    crown(c)
    c.save(os.path.join(dst, 'crown.png'))
    P = {'o': OUT_C, 'w': WHITE, 'b': BODY, 's': SHADE, 'y': GOLD, 'Y': GOLD_S,
         'r': (230, 60, 70), 'R': (150, 30, 40), 'k': (0, 0, 0)}
    # ola de gelatina (sale del aterrizaje y corre por el suelo; se salta)
    wave = [grid(["....oooo....",
                  "..oowwbboo..",
                  ".owbbbbbbso.",
                  ".obbbbbbbso.",
                  "obbbbbbbbsso",
                  "obbbbbbbbsso",
                  "obbbbbbssssO".replace('O', 'o'),
                  "oooooooooooo"], P),
            grid(["............",
                  "...ooooo....",
                  ".oowwbbboo..",
                  "obbbbbbbbso.",
                  "obbbbbbbbsso",
                  "obbbbbbbbsso",
                  "obbbbbbsssso",
                  "oooooooooooo"], P)]
    sheet(wave).save(os.path.join(dst, 'wave-Sheet.png'))
    stars = [grid(["..o..", ".oyo.", "oyyYo", ".oYo.", "..o.."], P),
             grid([".....", ".oyo.", ".yYy.", ".oyo.", "....."], P)]
    sheet(stars).save(os.path.join(dst, '..', 'common', 'stars-Sheet.png'))       # (compartidas por los jefes)
    target = [grid(["rr..r..rr..r..rr", "rR.rRr.rR.rRr.Rr", "r..............r", "rrrrrrrrrrrrrrrr"], P),
              grid(["ww..w..ww..w..ww", "wb.wbw.wb.wbw.bw", "w..............w", "wwwwwwwwwwwwwwww"], P)]
    sheet(target).save(os.path.join(dst, '..', 'common', 'target-Sheet.png'))
    sh = Image.new('RGBA', (16, 3), (0, 0, 0, 0))
    for x in range(16):
        for y in range(3):
            edge = x in (0, 15) or (y != 1 and x in (1, 14))
            if not edge:
                sh.putpixel((x, y), (0, 0, 0, 255))
    sh.save(os.path.join(dst, 'shadow.png'))
    print('escrito', dst)


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
    text(d, (x0, 10), 'MEGA GUMMY (el sprite del Gummy 16x16 a escala 10, como el Mega Crabby)')
    y = 30
    for k, (nm, desc) in sorted(MEGA.items()):
        text(d, (x0, y), 'OPCION %s: %s' % (k, nm))
        text(d, (x0, y + 14), desc)
        for i, f in enumerate(mega_frames(k)):
            im.alpha_composite(up(f, Z), (x0 + i * 140, y + 30))
        y += 200
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
            bg.alpha_composite(f, (x, floor - f.height))
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
                bg.alpha_composite(s, (130 - s.width // 2, 200 - s.height))
                frames.append(bg.convert('RGB'))
            frames[0].save(os.path.join(out, 'anim_%s_%s.gif' % (kind, k)), save_all=True,
                           append_images=frames[1:], duration=110, loop=0)
    print('vista previa:', out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply-helado', action='store_true',
                    help='escribe el Gummy helado elegido (A "Escarcha" sin carámbanos) en assets/images/gummy_ice/')
    ap.add_argument('--apply-mega', action='store_true',
                    help='escribe el jefe Rey Gummy (opción B) en assets/images/bosses/megagummy/ (boss_art)')
    ap.add_argument('--out', default=os.path.join(os.environ.get('FM_PREVIEWS', '/home/mtvemo/FlappyMonster_pruebas'),
                                                  'gummy_variantes'))
    a = ap.parse_args()
    preview(a.out)
    if a.apply_helado:
        dst = os.path.join(ROOT, 'assets', 'images', 'gummy_ice')
        os.makedirs(dst, exist_ok=True)
        for n, f in zip(('gummy.png', 'gummy1.png', 'gummy2.png', 'dead.png'), icy_frames('A')):
            f.save(os.path.join(dst, n))
        print('escrito', dst)
    if a.apply_mega:
        boss_art(os.path.join(ROOT, 'assets', 'images', 'bosses', 'megagummy'))


if __name__ == '__main__':
    sys.exit(main())
