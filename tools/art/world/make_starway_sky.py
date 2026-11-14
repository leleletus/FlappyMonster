#!/usr/bin/env python3
# tools/art/world/make_starway_sky.py
# El cielo de la VÍA ESTELAR (nivel especial de los Bloques Beep, docs/design/beep-blocks.md): fondo de SUPERFICIE
# `starway`. Una noche clara por encima de las nubes: la VÍA LÁCTEA cruzando el cielo en diagonal, CONSTELACIONES con
# sus líneas (figuras del juego: un Crabby, un Gummy, la cabeza del monstruo con sus antenas — SIN alas —, un bloque de
# cristal y una flecha de camino) y, muy abajo, un MAR DE NUBES iluminado por la luna con agujas de cristal rosa y cian
# asomando. Arte a 1x; el juego lo dibuja a x4.
#   starway_milky   (aditiva) la Vía Láctea: banda tramada de polvo violeta / azul / rosa con estrellas finas
#   starway_const   (aditiva) las constelaciones: estrellas gordas unidas por líneas tenues
#   starway_far     el mar de nubes lejano (lavanda claro) con islas flotantes en silueta
#   starway_near    las crestas de nubes cercanas y las agujas de cristal (rosa / cian, como los Bloques Beep)
#   + 3 degradados propios (`grads`; los tres son de noche: el nivel es siempre de noche, la hora solo lo matiza)
# Por defecto solo hace la VISTA PREVIA (fuera del repo):
#   /home/mtvemo/FlappyMonster_pruebas/via_estelar/fondo/ (vista_previa.png, capas/)
# --apply escribe en assets/ (no pisa lo que exista; los degradados se AÑADEN a gradients.png como cuadros 21..23:
# tras make_sky.py, make_jungle_sky.py --apply, make_frozen_coast_sky.py --apply A y make_valley_sky.py --apply,
# ejecutarlo otra vez).  Desde la raíz del repo:  /usr/bin/python3 tools/art/world/make_starway_sky.py [--apply]
import os, sys, math, random
import numpy as np
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
os.chdir(REPO)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]
import make_jungle_sky as J
import make_frozen_coast_sky as FC
sys.argv = _argv

APPLY = '--apply' in sys.argv
FORCE = '--force' in sys.argv                     # con --apply, REHACE los starway_* y sus 3 degradados (21..23)
PREV = '/home/mtvemo/FlappyMonster_pruebas/via_estelar/fondo'
SKY = os.path.join(REPO, 'assets/images/world/sky')
W, S = J.W, J.S
rgb, L = J.rgb, J.L
ID = 'starway'
BAY = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

# Noche profunda: índigo arriba → violeta → un brillo azul-verdoso sobre el mar de nubes
GRADS = {
    'day':   ['10143a', '1a1c4c', '2a2460', '3c3074', '4a4486'],
    'dusk':  ['0c0e2c', '181a42', '2a1e52', '42285e', '5a3a6c'],
    'night': ['05061a', '0a0c26', '141236', '201a48', '2a2c5c'],
}


def dither(t, x, y): return t * 16 > BAY[y % 4][x % 4] + 0.5


# ── La Vía Láctea (aditiva: en el juego, alfa 0,35..0,45 y sin teñir) ─────────────────────────────────────────
def milky():
    H = 180
    lay = L(H)
    r = random.Random(3)
    # banda diagonal (sube hacia la derecha) que se repite a lo ancho: el centro va de y=150 (x=0) a y=30 (x=320) …
    # y vuelve a empezar: para que empalme, la banda es periódica (dos tramos que se cruzan en el borde)
    def center(x): return 160 - (x % W) * 0.42
    cols = [rgb('2a2250'), rgb('3c3270'), rgb('544690'), rgb('6e5ea8')]   # (apagada: no debe distraer, el usuario)
    pink = rgb('5a3456')
    for x in range(W):
        for y in range(H):
            best = 0
            for k in (-1, 0, 1):
                c = center(x) + k * W * 0.42
                d = abs(y - c) / 34.0
                # polvo: una nube irregular, con un canal oscuro en medio (el polvo que tapa)
                n = 0.5 + 0.25 * math.sin(x * 0.11 + y * 0.07) + 0.25 * math.sin(x * 0.043 - y * 0.12 + 1.7)
                v = max(0.0, 1 - d * d) * (0.55 + 0.45 * n)
                lane = abs(y - c - 3 * math.sin(x * 0.05)) < 2.2 + 1.5 * math.sin(x * 0.09)
                if lane: v *= 0.35
                best = max(best, v)
            if best > 0.08 and dither(best, x, y):
                i = 0 if best < 0.35 else (1 if best < 0.6 else (2 if best < 0.85 else 3))
                c = cols[i]
                if i >= 1 and math.sin(x * 0.031 + y * 0.05) > 0.82: c = pink        # nebulosas rosas sueltas
                lay.put(x, y, c)
    # estrellas finas dentro de la banda (más densas que en el resto del cielo)
    for _ in range(200):
        x = r.randrange(W)
        y = int(center(x) + r.gauss(0, 16))
        if 0 <= y < H: lay.put(x, y, rgb('a8a4d0') if r.random() < 0.7 else rgb('b89cc0'))
    for _ in range(90):
        x, y = r.randrange(W), r.randrange(H)
        lay.put(x, y, rgb('6a70a0'))
    return lay.im


# ── Constelaciones (aditiva) ───────────────────────────────────────────────────────────────────────────────────
# cada una: estrellas (x, y, gorda) y las líneas que las unen (índices); figuras del juego, contadas con pocas
CONST = [
    # el MONSTRUO (cabeza redonda con sus dos antenas en V; sin alas)
    ((40, 40), [(0, 10, 1), (6, 3, 0), (14, 0, 1), (22, 3, 0), (28, 10, 1), (22, 18, 0), (14, 21, 1), (6, 18, 0),
                (8, -8, 1), (20, -8, 1)],
     [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 0), (1, 8), (3, 9)]),
    # un CRABBY (cuerpo ancho, dos pinzas arriba)
    ((128, 22), [(0, 14, 1), (8, 10, 0), (20, 10, 0), (28, 14, 1), (20, 18, 0), (8, 18, 0), (-6, 2, 1), (-2, -4, 0),
                 (34, 2, 1), (30, -4, 0)],
     [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0), (0, 6), (6, 7), (3, 8), (8, 9)]),
    # un BLOQUE de cristal (un rombo dentro de un cuadrado)
    ((214, 60), [(0, 0, 1), (20, 0, 1), (20, 20, 1), (0, 20, 1), (10, 4, 0), (16, 10, 0), (10, 16, 0), (4, 10, 0)],
     [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4)]),
    # la FLECHA del camino (la Vía Estelar: apunta a la derecha)
    ((262, 18), [(0, 12, 0), (14, 12, 0), (28, 12, 1), (20, 4, 1), (20, 20, 1)],
     [(0, 1), (1, 2), (2, 3), (2, 4)]),
    # un GUMMY (gota redonda con dos ojitos)
    ((84, 96), [(8, 0, 1), (16, 6, 0), (18, 16, 1), (12, 22, 0), (4, 22, 0), (-2, 16, 1), (0, 6, 0), (5, 11, 0), (11, 11, 0)],
     [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 0)]),
]


def constellations():
    lay = L(150)
    line = rgb('7a74b4')
    for (ox, oy), stars, links in CONST:
        pts = [(ox + x, oy + y) for x, y, _ in stars]
        for a, b in links:
            (x0, y0), (x1, y1) = pts[a], pts[b]
            n = int(max(abs(x1 - x0), abs(y1 - y0)))
            for i in range(1, n):
                if i % 2: lay.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), line)   # punteada
        for (x, y), (_, _, big) in zip(pts, stars):
            lay.put(x, y, rgb('d8d8f0'))
            for dx, dy in (((1, 0), (-1, 0), (0, 1), (0, -1)) if big else ((1, 0), (0, 1))):
                lay.put(x + dx, y + dy, rgb('9a9ed0') if big else rgb('6e74a8'))
    return lay.im


# ── El mar de nubes ────────────────────────────────────────────────────────────────────────────────────────────
def cloud_band(H, base, amp, terms, pal, seed, puff=9):
    """crestas de nubes redondeadas: perfil periódico + bultos; luz arriba (luna), sombra abajo, tramado"""
    lay = L(H)
    prof = J.profile(terms, base)
    r = random.Random(seed)
    for x in range(W):
        top = int(prof[x] - amp * abs(math.sin(math.pi * (x % puff) / puff)))
        for y in range(max(0, top), H):
            d = y - top
            c = pal[0] if d < 2 else (pal[1] if d < 6 else (pal[2] if d < 14 else pal[3]))
            if 6 <= d < 8 and dither(0.5, x, y): c = pal[2]
            if 2 <= d < 3 and dither(0.5, x, y): c = pal[1]
            lay.put(x, y, c)
    return lay


def island(lay, cx, top, w, col, dark):
    """isla flotante en silueta: un trozo de roca con la punta hacia abajo"""
    for y in range(0, w // 2 + 3):
        half = int(w / 2 * (1 - y / (w / 2 + 3)))
        for x in range(cx - half, cx + half + 1):
            lay.put(x, top + y, dark if y > 1 else col)


def far():
    """el mar de nubes lejano, más arriba que las crestas cercanas, con agujas de cristal pequeñas (lejanas, apagadas)"""
    pal = (rgb('6e6ca4'), rgb('585890'), rgb('46467a'), rgb('383a6a'))
    lay = L(100)
    for cx, h, c in ((50, 22, (rgb('c890c0'), rgb('a86aa6'), rgb('7a4c84'), rgb('5a3a6e'))),
                     (172, 28, (rgb('8cc4d8'), rgb('6aa0c0'), rgb('4a78a0'), rgb('3a5884'))),
                     (262, 18, (rgb('c890c0'), rgb('a86aa6'), rgb('7a4c84'), rgb('5a3a6e')))):
        spire(lay, cx, 34, h, c)
    band = cloud_band(100, 30, 3, [(3, 2, 0.3), (2, 5, 1.1)], pal, 5, puff=11)
    lay.im.alpha_composite(band.im)
    return lay.im


def spire(lay, cx, base, h, pal):
    """aguja de cristal facetada (luz a la izquierda, sombra a la derecha), punta arriba"""
    for y in range(h):
        half = max(0, int((y / h) * 4))
        for x in range(cx - half, cx + half + 1):
            c = pal[0] if x < cx else (pal[1] if x == cx else pal[2])
            if x == cx - half or x == cx + half: c = pal[3]
            lay.put(x, base - h + y, c)
    lay.put(cx - 1, base - h + 3, rgb('ffffff'))


def near():
    pal = (rgb('a4a0cc'), rgb('8682b4'), rgb('68669a'), rgb('504e82'))
    lay = L(60)
    PINK = (rgb('d49cc0'), rgb('b0709c'), rgb('844c78'), rgb('5a3254'))
    CYAN = (rgb('9cd0dc'), rgb('6aa8bc'), rgb('467e98'), rgb('2e5670'))
    for cx, h, p in ((30, 26, PINK), (38, 16, CYAN), (130, 30, CYAN), (139, 18, PINK), (226, 24, PINK), (300, 20, CYAN)):
        spire(lay, cx, 40, h, p)
    band = cloud_band(60, 34, 6, [(3, 3, 0.7), (2, 7, 2.1)], pal, 9, puff=13)
    lay.im.alpha_composite(band.im)
    return lay.im


PAR = (('milky', 0.02, True), ('const', 0.04, True), ('far', 0.08, False), ('near', 0.3, False))


def build():
    grads = {t: J.grad_frame(c) for t, c in GRADS.items()}
    layers = {'milky': milky(), 'const': constellations(), 'far': far(), 'near': near()}
    return grads, layers


def background(time, grads, layers, camX=900):
    cv = FC.sky_base(grads[time], time)
    for name, p, add in PAR:
        im = layers[name]
        y = J.WIN_H - im.height * S
        if add: cv = FC.add_layer(cv, im, p, camX, y, a=0.4)
        else: J.draw_layer(cv, im, p, camX, y, J.TIMES[time])
    return cv


def scene(cv):
    """un tramo de camino de Bloques Beep y el monstruo delante, para juzgar el contraste"""
    T = os.path.join(REPO, 'assets/images/world/tiles')
    pink, cyx = (Image.open(os.path.join(T, n + '.png')).convert('RGBA') for n in ('beep_pink', 'beep_cyan_x'))
    for i in range(14):
        cv.alpha_composite(pink if (i // 3) % 2 == 0 else cyx, (64 + i * 64, 520 - (i // 6) * 128))
    p = J.up(Image.open(os.path.join(REPO, 'assets/images/player/monstrito1.png')).convert('RGBA'), 6)
    cv.alpha_composite(p, (64 + 64 + 8, 520 - p.height))
    return cv


def main():
    os.makedirs(os.path.join(PREV, 'capas'), exist_ok=True)
    grads, layers = build()
    for n, im in layers.items(): im.save(os.path.join(PREV, 'capas', '%s_%s.png' % (ID, n)))
    out = Image.new('RGB', (1280, 720 * 2), J.rgb('20242a'))
    for j, tm in enumerate(('night', 'day')):
        im = scene(background(tm, grads, layers))
        out.paste(im.convert('RGB'), (0, j * 720))
        J.label(out, tm, (16, j * 720 + 16), 16)
    out.save(os.path.join(PREV, 'vista_previa.png'))
    print('vista previa:', os.path.join(PREV, 'vista_previa.png'))
    if APPLY: apply(grads, layers)


def apply(grads, layers):
    def put(path, im):
        if os.path.exists(path) and not FORCE: print('  %s ya existe: no se toca' % path); return
        im.save(path); print('  %-52s %dx%d' % (os.path.relpath(path, REPO), im.width, im.height))
    for n, im in layers.items(): put(os.path.join(SKY, '%s_%s.png' % (ID, n)), im)
    gp = os.path.join(SKY, 'gradients.png')
    g = Image.open(gp).convert('RGBA')
    if g.width == 20 * 8:                     # cuadros 21..23: starway_day, _dusk, _night
        ng = Image.new('RGBA', (g.width + 24, 180)); ng.paste(g, (0, 0))
        for i, t in enumerate(('day', 'dusk', 'night')): ng.paste(grads[t], (g.width + i * 8, 0))
        ng.save(gp); print('  %s: +3 cuadros (21..23)' % os.path.relpath(gp, REPO))
    elif g.width == 23 * 8 and FORCE:         # (rehacer: los 3 últimos cuadros son los suyos)
        for i, t in enumerate(('day', 'dusk', 'night')): g.paste(grads[t], (20 * 8 + i * 8, 0))
        g.save(gp); print('  %s: cuadros 21..23 rehechos' % os.path.relpath(gp, REPO))
    else:
        print('  %s tiene %d cuadros (se esperaban 20): no se toca' % (gp, g.width // 8))


if __name__ == '__main__':
    main()
