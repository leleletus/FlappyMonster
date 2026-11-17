#!/usr/bin/env python3
# tools/art/bosses/make_metrogolem.py
# EL GÓLEM METRÓNOMO (jefe de El Santuario del Compás: docs/bosses/metrogolem.md). Pocos píxeles de arte a escala 8
# (la regla de la densidad: jefes grandes = pocos píxeles gordos): un cuerpo de piedra estelar con forma de metrónomo
# (pirámide truncada), dos ojos, una ranura con marcas por delante, dos puños de piedra y la LÁMPARA dorada encima que
# se enciende en el pulso. El PÉNDULO (varilla + pesa) cuelga por debajo y se dibuja aparte (gira).
#   body_idle / body_lit / body_wind / body_dazed    el cuerpo (24x28)
#   rod.png (2x56) · bob.png (12x12) · wave.png (8x6: la onda del golpe) · note.png (8x11: la nota de las campanadas)
#   Desde la raíz:  /usr/bin/python3 tools/art/bosses/make_metrogolem.py [--apply]
# Sin --apply: vista previa en ~/FlappyMonster_pruebas/metrogolem/vista_previa.png
import os, sys
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
OUT = os.path.join(REPO, 'assets/images/bosses/metrogolem')
PREV = os.path.expanduser('~/FlappyMonster_pruebas/metrogolem')
S = 8


def rgb(h, a=255): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


O, D, M, L, W = rgb('1e1a2e'), rgb('4a4470'), rgb('6e66a0'), rgb('9c94cc'), rgb('c8c2ea')
EYE, EYE_A = rgb('e0fcff'), rgb('ff6a8a')
LAMP = {'off': (rgb('5a4420'), rgb('8a6a2a')), 'on': (rgb('e8c050'), rgb('fff4b0')), 'red': (rgb('a02838'), rgb('ff6a7a'))}
GOLD = (rgb('5a4420'), rgb('b08a3a'), rgb('e8c050'), rgb('fff4b0'))
CRY = (rgb('7a70b4'), rgb('c4bee8'), rgb('ece8fc'))

BW, BH = 24, 28
TOP = 5                                  # fila donde empieza la piedra (encima, la lámpara)


def half_w(y):
    """media anchura de la piedra en la fila y (pirámide truncada: 4 arriba, 9 abajo)"""
    return 4 + (y - TOP) * 5 // (BH - 1 - TOP)


def body(pose):
    im = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
    px = im.putpixel
    cx = 12
    # la piedra
    for y in range(TOP, BH):
        hw = half_w(y)
        for x in range(cx - hw, cx + hw):
            edge = x in (cx - hw, cx + hw - 1) or y in (TOP, BH - 1)
            if edge: c = O
            elif x == cx - hw + 1 or y == TOP + 1: c = W
            elif x <= cx - hw + 3: c = L
            elif x >= cx + hw - 3: c = D
            else: c = M
            px((x, y), c)
    # la ranura del metrónomo con sus marcas
    for y in range(14, BH - 3):
        px((cx - 1, y), O); px((cx, y), D)
        if y % 3 == 0: px((cx + 1, y), L); px((cx - 2, y), L)
    # base: una franja más oscura
    for x in range(cx - half_w(BH - 3) + 1, cx + half_w(BH - 3) - 1): px((x, BH - 3), D)
    # los ojos
    if pose == 'dazed':
        for ex in (cx - 4, cx + 2):                        # (x de mareo)
            for dx, dy in ((0, 0), (2, 0), (1, 1), (0, 2), (2, 2)): px((ex + dx, 9 + dy), O)
    else:
        col = EYE_A if pose == 'wind' else EYE
        for ex in (cx - 4, cx + 2):
            for dx in range(2):
                px((ex + dx, 10), col); px((ex + dx, 11), col if pose != 'wind' else O)
            if pose == 'wind':                             # (cejas de enfado)
                px((ex + (0 if ex < cx else 1), 9), O)
    # los puños
    hw = half_w(17)
    for side in (-1, 1):
        x0 = cx - hw - 4 if side < 0 else cx + hw            # (pegados al costado)
        for y in range(15, 20):
            for x in range(x0, x0 + 4):
                edge = x in (x0, x0 + 3) or y in (15, 19)
                px((x, y), O if edge else (L if y == 16 else M))
    # la lámpara (encima)
    lk = {'idle': 'off', 'lit': 'on', 'wind': 'red', 'dazed': 'off'}[pose]
    dk, lt = LAMP[lk]
    for y in range(1, TOP):
        for x in range(cx - 2, cx + 2):
            edge = x in (cx - 2, cx + 1) or y == 1
            px((x, y), O if edge else (lt if (y == 2 and lk != 'off') else dk))
    if pose == 'dazed': px((cx, 2), O); px((cx - 1, 3), O)     # (la lámpara rajada)
    if lk != 'off': px((cx - 1, 0), lt); px((cx, 0), lt)
    return im


def rod():
    im = Image.new('RGBA', (2, 56), (0, 0, 0, 0))
    for y in range(56):
        im.putpixel((0, y), GOLD[2] if y % 6 else GOLD[3]); im.putpixel((1, y), GOLD[1])
    return im


def bob():
    """la pesa: un rombo de oro con una estrella de cristal"""
    n, c = 12, 5.5
    im = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    for y in range(n):
        for x in range(n):
            d = abs(x - c) + abs(y - c)
            if d > 6: continue
            if d > 5: col = O
            elif x - c + y - c < -2: col = GOLD[3]
            elif x - c + y - c < 2: col = GOLD[2]
            else: col = GOLD[1]
            im.putpixel((x, y), col)
    for dx, dy, k in ((0, 0, 2), (1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1)):
        im.putpixel((5 + dx, 6 + dy), CRY[k])
    return im


def wave():
    im = Image.new('RGBA', (8, 6), (0, 0, 0, 0))
    rows = ['...ww...', '..wllw..', '.wlmmlw.', 'wlm..mlw', 'lm....ml', 'm......m']
    pal = {'w': CRY[2], 'l': CRY[1], 'm': CRY[0]}
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.': im.putpixel((x, y), pal[ch])
    return im


def note():
    """la NOTA de cristal que deja caer en las campanadas (8x11): una corchea"""
    rows = ['....oo..', '....owo.', '....olwo', '....ol.o', '....ol..', '....ol..', '.ooool..', 'owwlll..', 'owllld..',
            'olllddo.', '.ooooo..']
    pal = {'o': O, 'w': CRY[2], 'l': CRY[1], 'd': CRY[0]}
    im = Image.new('RGBA', (8, 11), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.': im.putpixel((x, y), pal[ch])
    return im


def up(im, k=S): return im.resize((im.width * k, im.height * k), Image.NEAREST)


def build():
    return {'body_idle': body('idle'), 'body_lit': body('lit'), 'body_wind': body('wind'), 'body_dazed': body('dazed'),
            'rod': rod(), 'bob': bob(), 'wave': wave(), 'note': note()}


def preview(ims):
    os.makedirs(PREV, exist_ok=True)
    out = Image.new('RGBA', (1180, 760), rgb('15132a'))
    x = 20
    for n in ('body_idle', 'body_lit', 'body_wind', 'body_dazed'):
        out.alpha_composite(up(ims[n]), (x, 20)); x += 220
    # una pose completa: cuerpo + péndulo inclinado
    b = up(ims['body_lit'])
    bx, by = 80, 300
    out.alpha_composite(b, (bx, by))
    r = up(ims['rod']).rotate(25, expand=True, resample=Image.NEAREST)
    out.alpha_composite(r, (bx + 96 - r.width // 2 - 90, by + BH * S - 20))
    out.alpha_composite(up(ims['bob']), (bx + 96 - 48, by + BH * S + 60))
    out.alpha_composite(up(ims['wave']), (700, 600)); out.alpha_composite(up(ims['wave']), (800, 600))
    mon = Image.open(os.path.join(REPO, 'assets/images/player/monstrito1.png')).convert('RGBA')
    out.alpha_composite(mon.resize((mon.width * 6, mon.height * 6), Image.NEAREST), (950, 560))
    out.convert('RGB').save(os.path.join(PREV, 'vista_previa.png'))
    print('vista previa:', os.path.join(PREV, 'vista_previa.png'))


def apply(ims):
    os.makedirs(OUT, exist_ok=True)
    for n, im in ims.items():
        im.save(os.path.join(OUT, n + '.png')); print('  escrito', n)


if __name__ == '__main__':
    ims = build()
    preview(ims)
    if '--apply' in sys.argv: apply(ims)
