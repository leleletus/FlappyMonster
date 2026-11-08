#!/usr/bin/env python3
# tools/art/world/make_valley_sky.py
# El VALLE DE LOS PILARES (zona 1 de la campaña Flappy, docs/design/flappy-plan-5b-valley.md): fondo de SUPERFICIE
# `valley`. La tierra de los flappies: columnas altas y HUECAS de basalto, como tubos de órgano gigantes, con nidos en
# los agujeros (de ellas salen las tuberías del Flappy de siempre). Arte a 1x; el juego lo dibuja a x4.
#   valley_far    grupos de columnas lejanas (bruma) con flappies posados en lo alto y otros volando (3 clases)
#   valley_mid    columnas más grandes con agujeros de nido (alguno con un flappy asomado)
#   valley_near   las bases de columnas gruesas y rotas entre la hierba
#   + 3 degradados propios (día cálido / atardecer / noche), como la jungla (`grads` en Sky.BIOMES)
# Los flappies son de la MISMA raza que el monstruo (cabeza redonda, antenas, cuerpo oscuro), cada uno un poco
# distinto (color, antenas o cuernos, cola) y SIN ALAS: aletean por arte de magia (brazos arriba).
# Colores claros y apagados: los pilares del nivel (tile 59, casi negros) se leen siempre por delante.
# Por defecto solo hace la VISTA PREVIA (fuera del repo):
#   /home/mtvemo/FlappyMonster_pruebas/valle/   (vista_previa.png: las tres horas con pilares de verdad delante,
#                                                capas.png, capas/ con cada PNG a su tamaño)
# --apply escribe en assets/ (no pisa lo que exista; los degradados se AÑADEN a gradients.png como cuadros 18..20:
# tras make_sky.py, make_jungle_sky.py --apply y make_frozen_coast_sky.py --apply A, ejecutarlo otra vez).
# Desde la raíz del repo:
#     /usr/bin/python3 tools/art/world/make_valley_sky.py [--apply]
import os, sys, random
from PIL import Image, ImageDraw

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
os.chdir(REPO)                                    # (make_jungle_sky usa rutas relativas a la raíz)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]          # (make_jungle_sky lee sys.argv al importarse)
import make_jungle_sky as J                       # capa L, degradados, composición como Sky.lua, etiquetas
import make_frozen_coast_sky as FC                # sky_base con degradado propio
sys.argv = _argv

APPLY = '--apply' in sys.argv
FORCE = '--force' in sys.argv                     # con --apply, rehace SOLO valley_near.png (lo demás no se pisa)
PREV = '/home/mtvemo/FlappyMonster_pruebas/valle'
SKY = os.path.join(REPO, 'assets/images/world/sky')
W, S = J.W, J.S
rgb, L = J.rgb, J.L
ID = 'valley'

GRADS = {
    'day':   ['74b0da', '8ec0dc', 'aed0d8', 'd2dccc', 'f0dcb2'],     # azul arriba → crema cálida en el horizonte
    'dusk':  ['3c3a6c', '6a4a80', 'a65e7a', 'da8a68', 'f2b674'],
    'night': ['0a1024', '10182e', '162038', '1c2840', '24304a'],
}

# columnas: (luz, cuerpo, sombra, junta/boca) por capa; cuanto más lejos, más claro y más frío (bruma)
FAR = (rgb('cdc6cc'), rgb('b6b0c0'), rgb('a29eb4'))
MID = (rgb('aea0a2'), rgb('968c9c'), rgb('7c7690'))
NEAR = (rgb('8a7e86'), rgb('70687a'), rgb('5a5468'))
HOLE_M = rgb('5a5268')                     # agujero de nido (medio)
TWIG = (rgb('b89c74'), rgb('94785a'))      # ramitas del nido
HAZE = (rgb('9c94ac'), rgb('6e6684'), rgb('4a4460'))   # bruma / sombra del fondo del valle (violeta de los pilares)
# flappies lejanos: (cuerpo, cara) — apagados por la bruma, más oscuros que las columnas para leerse
KINDS = {
    'a': (rgb('5e5674'), rgb('f6f0e6')),   # como el monstruo: antenas en V
    'b': (rgb('46687a'), rgb('f2f4e6')),   # un cuerno rizado
    'c': (rgb('7e5248'), rgb('f8ecd6')),   # dos cuernos rectos
}


def put_rows(lay, x, y, rows, pal, flip=False):
    """dibuja un mapa de caracteres (pal: carácter → color; '.' = nada)"""
    w = max(len(r) for r in rows)
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch == '.' or ch not in pal: continue
            lay.put(x + (w - 1 - i if flip else i), y + j, pal[ch])


# ── Los flappies (a = cuerpo, F = cara: la franja clara de la cara del monstruo, en pequeño) ──────────────────────
HEADS = {                                   # antenas / cuernos de cada clase (encima de la cabeza, 7 de ancho)
    'a': ['.a...a.', '..a.a..'],            # antenas en V, como el monstruo
    'b': ['...aa..', '....a..'],            # un cuerno rizado
    'c': ['.a...a.', '.a...a.'],            # dos cuernos rectos en las esquinas
}
SIT = ['.aaaaa.', '.aFFFa.', '.aaaaa.', 'a.aaa.a', '..a.a..']                 # posado: brazos abajo
FLY = ['a.....a', '.aaaaa.', '.aFFFa.', '.aaaaa.', '..aaa..', '...a...']     # volando: brazos arriba (aletea sin alas)


def flappy(lay, x, y, kind, fly=False, flip=False):
    """x, y = esquina de arriba a la izquierda (7 de ancho, 7 de alto; volando, una fila de antena menos)"""
    body, face = KINDS[kind]
    rows = (HEADS[kind][1:] + FLY) if fly else (HEADS[kind] + SIT)
    put_rows(lay, x, y, rows, {'a': body, 'F': face}, flip)


def peek(lay, x, y, kind):
    """un flappy asomado a un agujero: antenas y la cara (3 de ancho bajo las antenas)"""
    body, face = KINDS[kind]
    put_rows(lay, x, y, HEADS[kind] + ['.aaaaa.', '.aFFFa.'], {'a': body, 'F': face})


# ── Columnas de basalto (prismas: cara de luz a la izquierda, cuerpo, sombra a la derecha; boca de tubería arriba) ──
def column(lay, x, w, top, base, pal, lip=True, joints=0, seed=0):
    l_, m_, d_ = pal
    r = random.Random(seed)
    kl = max(1, w // 4)
    kd = max(1, w // 4)
    for yy in range(top, base):
        for xx in range(x, x + w):
            c = m_
            if xx < x + kl: c = l_
            elif xx >= x + w - kd: c = d_
            lay.put(xx, yy, c)
    if lip:                                   # la boca: un reborde 1 px más ancho a cada lado y su sombra debajo
        for xx in range(x - 1, x + w + 1):
            lay.put(xx, top - 2, l_)
            lay.put(xx, top - 1, l_ if xx < x + kl else (d_ if xx >= x + w - kd else m_))
        for xx in range(x, x + w): lay.put(xx, top, d_)
    for _ in range(joints):                   # juntas del basalto: rayas cortas de sombra
        yy = r.randrange(top + 6, max(top + 7, base - 2))
        x0 = x + r.randrange(0, max(1, w - 3))
        for xx in range(x0, min(x + w, x0 + 2 + r.randrange(3))): lay.put(xx, yy, d_)


def organ(lay, cx, base, n, w, hmin, hmax, pal, seed, joints=1, lip=True):
    """grupo de columnas pegadas, altas en el centro como un órgano; devuelve [(x, w, top)]"""
    r = random.Random(seed)
    x = cx - n * w // 2
    out = []
    for i in range(n):
        k = 1 - abs((i + 0.5) / n - 0.5) * 2               # 1 en el centro, 0 en los bordes
        h = int(hmin + (hmax - hmin) * k) + r.randrange(-4, 5)
        ww = w + r.randrange(-1, 2)
        out.append((x, ww, base - h))
        x += ww + (1 if r.random() < 0.3 else 0)
    for (x, ww, top) in sorted(out, key=lambda c: -(base - c[2])):     # las bajas delante de las altas
        column(lay, x, ww, top, base, pal, lip, joints, seed + x)
    return out


def far():
    lay = L(140)
    B = 140
    groups = [(30, 5, 7, 40, 92, 1), (112, 4, 6, 30, 70, 2), (178, 6, 7, 50, 118, 3), (262, 4, 8, 34, 82, 4)]
    tops = []
    for (cx, n, w, hmin, hmax, sd) in groups:
        tops += organ(lay, cx, B, n, w, hmin, hmax, FAR, sd, joints=1)
    for (x, w, h) in ((70, 5, 26), (146, 6, 40), (226, 5, 22), (304, 6, 44)):   # columnas sueltas
        column(lay, x, w, B - h, B, FAR, joints=1, seed=x)
        tops.append((x, w, B - h))
    # flappies posados en lo alto de algunas columnas (de pie sobre el reborde)
    perch = [(0, 'a', False), (3, 'b', True), (6, 'c', False), (10, 'a', True), (13, 'c', True), (16, 'b', False),
             (19, 'a', False)]
    for (i, kind, flip) in perch:
        if i < len(tops):
            x, w, top = tops[i]
            flappy(lay, x + w // 2 - 3, top - 2 - 7, kind, False, flip)
    # flappies volando por encima
    for (x, y, kind, flip) in ((54, 18, 'b', False), (96, 34, 'a', True), (150, 8, 'c', False), (214, 26, 'a', False),
                               (244, 12, 'c', True), (292, 30, 'b', True)):
        flappy(lay, x, y, kind, True, flip)
    return lay.im


def nest_hole(lay, cx, cy, hole=HOLE_M, kind=None):
    """agujero de nido en la cara de una columna: óvalo oscuro con ramitas en el borde de abajo"""
    for (dy, half) in ((-2, 1), (-1, 2), (0, 2), (1, 2), (2, 1)):
        for dx in range(-half, half + 1): lay.put(cx + dx, cy + dy, hole)
    for dx in range(-3, 4): lay.put(cx + dx, cy + 3, TWIG[1] if dx % 2 else TWIG[0])
    lay.put(cx - 3, cy + 2, TWIG[0]); lay.put(cx + 3, cy + 2, TWIG[1])
    if kind: peek(lay, cx - 3, cy - 3, kind)


def mid():
    lay = L(112)
    B = 112
    groups = [(56, 4, 11, 46, 86, 11), (170, 5, 10, 54, 100, 12), (276, 3, 12, 36, 64, 13)]
    cols = []
    for (cx, n, w, hmin, hmax, sd) in groups:
        cols += organ(lay, cx, B, n, w, hmin, hmax, MID, sd, joints=3)
    for (x, w, h) in ((110, 9, 30), (226, 10, 42)):
        column(lay, x, w, B - h, B, MID, joints=2, seed=x)
        cols.append((x, w, B - h))
    r = random.Random(21)
    peeks = {1: 'a', 6: 'c', 10: 'b'}
    for i, (x, w, top) in enumerate(cols):
        if B - top < 34 or i % 2 == 1 and i not in peeks: continue
        cy = top + 8 + r.randrange(0, max(1, (B - top) // 3))
        nest_hole(lay, x + w // 2, cy, kind=peeks.get(i))
    return lay.im


def near():
    lay = L(64)
    B = 64
    G = 34                                     # donde empieza la bruma del fondo
    r = random.Random(31)
    for (x, w, h) in ((8, 22, 16), (32, 16, 26), (96, 28, 12), (140, 18, 30), (162, 24, 20), (228, 20, 14),
                      (252, 26, 24), (300, 14, 10)):
        column(lay, x, w, G - h, B, NEAR, lip=False, joints=2, seed=x)
        top = G - h                            # cara de arriba rota: dientes de luz
        for xx in range(x, x + w):
            if r.random() < 0.35: lay.put(xx, top - 1, NEAR[0])
    # el fondo del valle: sin hierba (el suelo de los niveles Flappy ya no es de pradera); las bases de las columnas
    # se hunden en bruma violeta que espesa hacia abajo (tramado ordenado, rectángulos duros) hasta una sombra sólida
    BAY = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))     # Bayer 4x4 (0..15)
    for x in range(W):
        for y in range(G - 8, B):
            t = (y - (G - 8)) / float(B - 1 - (G - 8))                        # 0 arriba → 1 abajo
            if t >= 0.92: lay.put(x, y, HAZE[2]); continue
            thr = (BAY[y % 4][x % 4] + 0.5) / 16.0
            if t * 1.15 > thr:
                lay.put(x, y, HAZE[0] if t < 0.4 else (HAZE[1] if t < 0.7 else HAZE[2]))
    return lay.im


PAR = (('far', 0.08), ('mid', 0.2), ('near', 0.38))


def build():
    grads = {t: J.grad_frame(c) for t, c in GRADS.items()}
    layers = {'far': far(), 'mid': mid(), 'near': near()}
    return grads, layers


def background(time, grads, layers, camX=900):
    cv = FC.sky_base(grads[time], time)
    for name, p in PAR:
        im = layers[name]
        J.draw_layer(cv, im, p, camX, J.WIN_H - im.height * S, J.TIMES[time])
    return cv


# ── La escena: pilares de verdad (tile pillar) desde arriba y abajo y el monstruo ────────────────
TIL = os.path.join(REPO, 'assets/images/world/tiles')


def tile(name): return Image.open(os.path.join(TIL, name + '.png')).convert('RGBA')


def scene(cv):
    body, cap = tile('pillar'), tile('pillar_cap')
    capd = cap.transpose(Image.FLIP_TOP_BOTTOM)
    k, oy, rows = 64, -48, 12                  # 12 filas (la 0 empieza 48 px por encima, como el nivel de 11)
    floor = rows - 1
    for (c, gap0, gap1) in ((3, 4, 7), (8, 2, 5), (13, 5, 8), (17, 3, 6)):
        for r in range(1, floor):
            if gap0 <= r <= gap1: continue
            im = capd if r == gap0 - 1 else (cap if r == gap1 + 1 else body)
            cv.alpha_composite(im, (c * k, oy + r * k))
    p = J.up(Image.open(os.path.join(REPO, 'assets/images/player/monstrito1.png')).convert('RGBA'), 6)
    cv.alpha_composite(p, (5 * 64 + 20, oy + 5 * 64))
    return cv


def layer_sheet(grads, layers):
    out = Image.new('RGBA', (1060, 820), rgb('20242a'))
    J.label(out, 'valley - capas a x2 (320 de ancho = se repite)', (20, 14), 12)
    y = 44
    for n in ('far', 'mid', 'near'):
        im = J.up(layers[n], 2)
        out.alpha_composite(grads['day'].resize((im.width, im.height), Image.NEAREST), (20, y))
        out.alpha_composite(im, (20, y))
        J.label(out, '%s_%s (%dx%d)' % (ID, n, layers[n].width, layers[n].height), (20, y + im.height + 4), 8)
        y += im.height + 20
    for i, t in enumerate(('day', 'dusk', 'night')):
        out.alpha_composite(grads[t].resize((40, 240), Image.NEAREST), (700 + i * 60, 60))
        J.label(out, t, (700 + i * 60, 310), 8)
    return out


def main():
    os.makedirs(os.path.join(PREV, 'capas'), exist_ok=True)
    grads, layers = build()
    for n, im in layers.items(): im.save(os.path.join(PREV, 'capas', '%s_%s.png' % (ID, n)))
    layer_sheet(grads, layers).convert('RGB').save(os.path.join(PREV, 'capas.png'))
    out = Image.new('RGB', (1280, 720 * 3), rgb('20242a'))
    for j, tm in enumerate(('day', 'dusk', 'night')):
        im = scene(background(tm, grads, layers))
        im.convert('RGB').save(os.path.join(PREV, 'escena_%s.png' % tm))
        out.paste(im.convert('RGB'), (0, j * 720))
        J.label(out, tm, (16, j * 720 + 16), 16)
    out.save(os.path.join(PREV, 'vista_previa.png'))
    print('vista previa:', os.path.join(PREV, 'vista_previa.png'))
    if APPLY: apply(grads, layers)


def apply(grads, layers):
    """escribe las capas en assets/ (no pisa nada que exista) y añade los 3 degradados (cuadros 18..20)"""
    def put(path, im):
        if os.path.exists(path) and not (FORCE and path.endswith('valley_near.png')): print('  %s ya existe: no se toca' % path); return
        im.save(path); print('  %-52s %dx%d' % (os.path.relpath(path, REPO), im.width, im.height))
    for n, im in layers.items(): put(os.path.join(SKY, '%s_%s.png' % (ID, n)), im)
    gp = os.path.join(SKY, 'gradients.png')
    g = Image.open(gp).convert('RGBA')
    if g.width == 17 * 8:                     # cuadros 18..20: valley_day, _dusk, _night
        ng = Image.new('RGBA', (g.width + 24, 180)); ng.paste(g, (0, 0))
        for i, t in enumerate(('day', 'dusk', 'night')): ng.paste(grads[t], (g.width + i * 8, 0))
        ng.save(gp); print('  %s: +3 cuadros (18..20)' % os.path.relpath(gp, REPO))
    else:
        print('  %s tiene %d cuadros (se esperaban 17): no se toca' % (gp, g.width // 8))


if __name__ == '__main__':
    main()
