#!/usr/bin/env python3
# tools/art/world/make_frozen_coast_sky.py
# Isla de la COSTA HELADA (la del Mega Crabby de hielo): fondo de SUPERFICIE `frozen_coast`. Arte a 1x; el juego lo
# dibuja a x4. A diferencia de `snow` (las Montañas Heladas: picos), aquí todo es a NIVEL DEL MAR y horizontal:
#   frozen_coast_far     el horizonte del mar polar con témpanos e icebergs lejanos
#   frozen_coast_mid     acantilados de hielo / el puerto helado (A) · olas rompientes CONGELADAS (B)
#   frozen_coast_near    banquisa con crestas de presión y postes (A) · placa de hielo agrietada, esquirlas y un
#                        pecio atrapado en el hielo (B)
#   frozen_coast_aurora  aurora polar (capa aditiva, SOLO de noche: pide una línea nueva en Sky.lua, ver README)
#   + 3 degradados propios (día / atardecer / noche), como la jungla (`grads` en Sky.BIOMES)
# DOS OPCIONES: A (estilo de la casa: puerto, faro, banquisa) y B (más atrevida: mar turquesa, olas heladas, pecio).
# El usuario (2026-10-29) eligió la A, pero con los icebergs, la barrera y el frente del glaciar al estilo de la B
# (facetas planas con su reflejo en franjas: crystal / ice_wall) y la aurora (verde con un toque de magenta). Aplicada
# la A; la B se queda aquí y en la vista previa.
# Por defecto solo hace la VISTA PREVIA (fuera del repo):
#   /home/mtvemo/FlappyMonster_pruebas/fondo_costa_helada/   (vista_previa.png, escenas A/B por hora, capas/, README)
# --apply A escribe la opción en assets/ (no pisa lo que exista; los degradados se AÑADEN a gradients.png como
# cuadros 15..17). Desde la raíz del repo:
#     ~/.venvs/fm-music/bin/python tools/art/world/make_frozen_coast_sky.py [--apply A|B]
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]          # (make_jungle_sky lee sys.argv al importarse)
import make_jungle_sky as J                       # capa L, perfil, composición como Sky.lua, etiquetas
sys.argv = _argv

APPLY = '--apply' in sys.argv
PREV = '/home/mtvemo/FlappyMonster_pruebas/fondo_costa_helada'
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
SKY = os.path.join(REPO, 'assets/images/world/sky')
W, S = J.W, J.S
rgb, L, profile = J.rgb, J.L, J.profile
ID = 'frozen_coast'


def poly(lay, pts, col):
    """polígono relleno (repetible a lo ancho: se dibuja también desplazado ±W)"""
    d = ImageDraw.Draw(lay.im)
    for off in (-lay.w, 0, lay.w):
        d.polygon([(x + off, y) for x, y in pts], fill=col)


def hline(lay, x0, x1, y, col):
    for x in range(int(x0), int(x1)): lay.put(x, y, col)


def vline(lay, x, y0, y1, col):
    for y in range(int(y0), int(y1)): lay.put(x, y, col)


def recolor_in(lay, box, src, dst):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            if lay.get(x, y)[:3] == src[:3] and lay.get(x, y)[3]: lay.put(x, y, dst)


# ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
# OPCIÓN A — "Costa de témpanos" (estilo de la casa)
# ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
GRADS_A = {
    'day':   ['74acd6', '88badc', '9cc8e2', 'b0d4e8', 'c4e0ec'],     # azul polar, casi blanco en el horizonte
    'dusk':  ['3a3a6c', '62508a', '9a6c9e', 'd09498', 'eec4a6'],     # lila → melocotón
    'night': ['060c1e', '0a1428', '0e1c34', '12243e', '182c48'],
}
A = dict(
    sea_f=rgb('7ea8c8'), sea_fl=rgb('a6c6de'), sea_fd=rgb('6e98bc'),
    berg_f=rgb('a8c6de'), berg_fl=rgb('eef6fa'), berg_fd=rgb('88aac8'),
    sea_m=rgb('5e90b8'), sea_ml=rgb('88b2d2'), sea_md=rgb('4e80aa'),
    ice_m=rgb('98c0dc'), ice_ml=rgb('c4dcec'), ice_md=rgb('6e9cc2'), snow_m=rgb('e8f2f8'),
    wood=rgb('5e5058'), wood_l=rgb('7a6a70'), red=rgb('a85656'), red_d=rgb('843e44'),
    lamp=rgb('f09a2c'), refl_f=rgb('98bad4'), refl_m=rgb('7aa6ca'),                                     # ámbar: Sky.lua lo ve "incandescente" → brilla de noche
    tower=rgb('d6e2ea'), tower_d=rgb('a8bccc'),
    snow=rgb('dce8f2'), snow_l=rgb('f4f9fc'), snow_d=rgb('b4cade'),
    ice=rgb('86bad6'), ice_l=rgb('b8daec'), ice_d=rgb('5c92ba'), gap=rgb('3a6a96'),
    post=rgb('4e4048'), post_l=rgb('6e5e66'),
)


def tab_berg(lay, x, base, w, h, body, light, dark, snow, grooves=True):
    """iceberg tabular: cara frontal casi recta, techo plano nevado, el tercio derecho en sombra, grietas verticales"""
    pts = [(x, base), (x + 1, base - h + 2), (x + 3, base - h), (x + w - 4, base - h), (x + w - 1, base - h + 3), (x + w, base)]
    poly(lay, pts, body)
    split = x + int(w * 0.68)
    for yy in range(base - h, base + 1):
        for xx in range(split + (yy - (base - h)) // 3, x + w + 1):
            if lay.get(xx, yy) == body: lay.put(xx, yy, dark)
    for xx in range(x + 2, x + w - 1):
        lay.put(xx, base - h, snow)
        if (xx * 7) % 5: lay.put(xx, base - h + 1, snow)
    vline(lay, x + 1, base - h + 2, base, light)
    if grooves and h > 6:
        for gx in range(x + 5, split - 1, 6):
            vline(lay, gx, base - h + 3, base - 1 - (gx % 3), dark)


def ice_wall(lay, x0, x1, base, env, var, pal, refl, seed=1, step=(8, 14), bevel=(0, 6)):
    """muro de hielo (barrera, frente de glaciar): columnas de alto distinto, cada una con su techo en bisel y tres
    caras planas (clara a la izquierda, media, oscura a la derecha), un filo blanquísimo arriba y su reflejo.
    env(x) = alto medio en esa x; var = cuánto cambia de una columna a la siguiente; bevel = caída del techo"""
    l_, m_, d_ = pal
    r = random.Random(seed)
    x = x0
    tops = []
    while x < x1:
        w = r.randrange(*step)
        w = min(w, x1 - x)
        if w < 3: break
        h = int(env(x + w / 2)) + r.randrange(-var, var + 1)
        fall = r.randrange(*bevel) if bevel[1] > bevel[0] else bevel[0]
        dl, dr = (0, fall) if r.random() < 0.6 else (fall, 0)            # techo en bisel
        tl, tr = base - h + dl, base - h + dr
        poly(lay, [(x, base), (x, tl), (x + w, tr), (x + w, base)], m_)
        ka = x + max(2, int(w * 0.3))
        poly(lay, [(x, base), (x, tl), (ka, tl + (tr - tl) * (ka - x) / w), (ka, base)], l_)
        kb = x + w - max(2, int(w * 0.22))
        poly(lay, [(kb, base), (kb, tl + (tr - tl) * (kb - x) / w), (x + w, tr), (x + w, base)], d_)
        for xx in range(x, x + w):                                       # filo de arriba
            lay.put(xx, int(round(tl + (tr - tl) * (xx - x) / w)), rgb('f4fafc'))
        tops.append((x, w, h))
        x += w
    for (x, w, h) in tops:                                               # reflejo: franjas que se estrechan
        for yy in range(1, int(h * 0.7)):
            if yy % 3 == 2: continue
            k = yy / (h * 0.7)
            hline(lay, x + 1 + int(k * w * 0.2) + (yy % 2), x + w - 1 - int(k * w * 0.2), base + 1 + yy, refl)


def a_far():
    lay = L(120)
    HZ = 40
    for y in range(HZ, 120):
        for x in range(W): lay.put(x, y, A['sea_f'])
    hline(lay, 0, W, HZ, A['sea_fl'])
    # (2026-10-29, el usuario eligió A pero con el hielo de B: barrera e icebergs de FACETAS planas, con su reflejo)
    pal = (A['berg_fl'], A['berg_f'], A['berg_fd'])
    ice_wall(lay, 150, 300, HZ, lambda x: 9, 1, pal, A['refl_f'], seed=2, step=(16, 30), bevel=(1, 3))
    for (x, w, h, rd) in ((10, 30, 14, 0.4), (56, 12, 7, 0.6), (90, 22, 17, 0.35), (124, 10, 6, 0.5), (304, 12, 8, 0.45)):
        crystal(lay, x, HZ, w, h, rd, pal, A['refl_f'])
    hline(lay, 0, W, HZ, A['sea_fl'])
    r = random.Random(3)
    for i, y in enumerate((44, 48, 53, 60, 69, 80, 94, 110)):  # destellos del mar (más largos y separados hacia abajo)
        x = r.randrange(W)
        while x < W + 40:
            hline(lay, x, x + 3 + i + r.randrange(6 + i), y, A['sea_fl'])
            x += 14 + i * 4 + r.randrange(22)
    return lay.im


def lighthouse(lay, cx, base, h):
    top = base - h
    for y in range(top, base):
        t = (y - top) / h
        hw = 3 + t * 2
        for x in range(int(cx - hw), int(cx + hw) + 1):
            band = ((y - top) // 7) % 2 == 1 and y < base - 4
            c = A['red'] if band else A['tower']
            if x >= cx + hw - 1: c = A['red_d'] if band else A['tower_d']
            lay.put(x, y, c)
    for x in range(cx - 4, cx + 5): lay.put(x, top, A['wood'])           # balcón
    for y in range(top - 5, top):                                          # linterna
        for x in range(cx - 2, cx + 3): lay.put(x, y, A['lamp'] if 1 <= y - (top - 5) <= 3 and abs(x - cx) < 2 else A['wood'])
    for i, x in enumerate(range(cx - 3, cx + 4)): lay.put(x, top - 6, A['red_d'])
    for x in range(cx - 1, cx + 2): lay.put(x, top - 7, A['red_d'])
    lay.put(cx, top - 8, A['red_d'])


def hut(lay, x, base, w, h):
    for y in range(base - h, base):
        for xx in range(x, x + w): lay.put(xx, y, A['wood'] if xx > x else A['wood_l'])
    for i in range(w // 2 + 3):                                            # tejado nevado a dos aguas
        y = base - h - i // 1
        if y < base - h - (w // 2): break
    roof = [(x - 2, base - h), (x + w // 2, base - h - w // 2 - 1), (x + w + 1, base - h)]
    poly(lay, roof, A['snow_m'])
    hline(lay, x - 2, x + w + 2, base - h, A['ice_ml'])
    for k in range(2):                                                     # ventanas encendidas
        wx = x + 3 + k * (w - 8)
        for yy in range(base - h + 3, base - h + 6):
            for xx in range(wx, wx + 3): lay.put(xx, yy, A['lamp'])


def a_mid():
    lay = L(112)
    SEA = 50
    for y in range(SEA, 112):
        for x in range(W): lay.put(x, y, A['sea_m'])
    hline(lay, 0, W, SEA, A['sea_ml'])
    # el frente del glaciar: columnas de hielo de FACETAS planas (como los icebergs de B), con su reflejo en franjas
    pal = (A['ice_ml'], A['ice_m'], A['ice_md'])
    ice_wall(lay, -4, 112, SEA, lambda x: 40 - max(0, x - 60) * 0.35, 3, pal, A['refl_m'], seed=5, step=(14, 24),
             bevel=(3, 9))
    crystal(lay, 122, SEA, 20, 15, 0.4, pal, A['refl_m'])              # un témpano suelto delante del glaciar
    crystal(lay, 146, SEA, 8, 5, 0.6, pal, A['refl_m'])
    # el puerto: muelle sobre pilotes, orilla nevada, dos casetas y el faro
    for x in range(196, 320):
        b = SEA - 6 - (2 if x > 240 else 0) - (1 if x > 274 else 0)
        for y in range(b, SEA + 1): lay.put(x, y, A['snow_m'] if y < b + 2 else A['ice_m'])
        if x > 316: pass
    hline(lay, 158, 200, SEA - 5, A['wood_l']); hline(lay, 158, 200, SEA - 4, A['wood'])
    for px in range(160, 200, 8):
        vline(lay, px, SEA - 4, SEA + 5, A['wood'])
        lay.put(px, SEA - 6, A['snow_m'])
    hut(lay, 212, SEA - 6, 14, 9)
    hut(lay, 234, SEA - 8, 12, 8)
    lighthouse(lay, 292, SEA - 9, 38)
    for (fx, fw, dy) in ((150, 10, 3), (186, 6, 4), (250, 12, 3), (20, 14, 10), (120, 9, 14), (230, 18, 20),
                         (70, 22, 30), (290, 16, 38), (170, 26, 50)):      # témpanos flotando (más grandes hacia abajo)
        th = 1 + dy // 14
        for k in range(th): hline(lay, fx + (1 if k == 0 else 0), fx + fw - (1 if k == 0 else 0), SEA + dy - th + k, A['snow_m'])
        hline(lay, fx, fx + fw, SEA + dy, A['ice_m'])
        hline(lay, fx + 1, fx + fw - 1, SEA + dy + 1, A['sea_md'])
        if dy > 12: hline(lay, fx + 2, fx + fw - 2, SEA + dy + 2, A['sea_md'])
    r = random.Random(5)
    for y in (SEA + 6, SEA + 17, SEA + 33, SEA + 52):                       # destellos
        x = r.randrange(W)
        while x < W + 30:
            hline(lay, x, x + 4 + r.randrange(8), y, A['sea_ml'])
            x += 26 + r.randrange(30)
    return lay.im


def a_near():
    lay = L(64)
    gp = profile([(2, 3, 0.7), (1.5, 8, 2.2)], 26)
    g = lambda x: int(round(64 - gp[int(x) % W]))
    r = random.Random(7)
    # crestas de presión: losas de hielo inclinadas, en grupos
    for gx in (18, 96, 170, 252):
        n = 3 + r.randrange(3)
        for k in range(n):
            x0 = gx + k * 7 + r.randrange(3)
            h = 12 + r.randrange(20)
            lean = r.choice((-5, -3, 3, 5))
            w = 8 + r.randrange(5)
            b = g(x0) + 2
            pts = [(x0, b), (x0 + lean, b - h), (x0 + lean + w, b - h + r.randrange(-2, 3)), (x0 + w, b)]
            poly(lay, pts, A['ice'])
            poly(lay, [(x0 + w * 0.6, b), (x0 + lean + w * 0.6, b - h + 1), (x0 + lean + w, b - h + 1), (x0 + w, b)], A['ice_d'])
            for i in range(int(w) + 1):                                    # nieve encima
                lay.put(x0 + lean + i, b - h - 1 + (i * (pts[2][1] - pts[1][1])) // max(1, w), A['snow_l'])
                lay.put(x0 + lean + i, b - h + (i * (pts[2][1] - pts[1][1])) // max(1, w), A['snow'])
            for y in range(b - h + 2, b):                                  # filo de luz a la izquierda
                lay.put(x0 + lean * (b - y) / h, y, A['ice_l'])
    # postes del viejo muelle con una maroma
    posts = (60, 74, 214, 228)
    for px in posts:
        b = g(px)
        for y in range(b - 14, b + 1):
            lay.put(px, y, A['post_l']); lay.put(px + 1, y, A['post']); lay.put(px + 2, y, A['post'])
        for x in range(px - 1, px + 4): lay.put(x, b - 15, A['snow_l'])
        lay.put(px, b - 16, A['snow_l']); lay.put(px + 1, b - 16, A['snow_l'])
    for (a, b_) in ((60, 74), (214, 228)):
        for i in range(b_ - a):
            t = i / (b_ - a)
            lay.put(a + 2 + i, g(a) - 11 + 3 * 4 * t * (1 - t), A['post'])
    # suelo de nieve con ventisqueros (y alguna grieta de mar oscuro)
    for x in range(W):
        top = g(x)
        for y in range(top, 64):
            c = A['snow']
            if y == top: c = A['snow_l']
            elif y > top + 6 and (x // 3 + y) % 9 == 0: c = A['snow_d']
            lay.put(x, y, c)
    for (cx, cw) in ((132, 9), (296, 6)):
        for x in range(cx, cx + cw):
            for y in range(g(x) + 3, g(x) + 5): lay.put(x, y, A['gap'])
            lay.put(x, g(x) + 2, A['snow_d'])
    for y in range(58, 64):
        for x in range(W): lay.put(x, y, A['snow'])
    return lay.im


def aurora(cols, seed, bands):
    """aurora para una capa ADITIVA (colores oscuros: se suman al cielo). Cortinas: rayas verticales bajo una cinta
    ondulada; la fila de abajo de cada raya, más viva."""
    lay = L(150)
    r = random.Random(seed)
    for (y0, amp, k, ph, ln, col) in bands:
        base, edge = cols[col]
        for x in range(W):
            yc = y0 + amp * math.sin(2 * math.pi * k * x / W + ph) + 3 * math.sin(2 * math.pi * 5 * x / W)
            n = ln + int(6 * math.sin(2 * math.pi * 7 * x / W + ph)) + r.randrange(3)
            for i in range(n):
                y = int(yc) - i
                c = edge if i < 2 else base
                if i > n * 0.6 and (x + y) % 2: continue                 # se deshace arriba (tramado)
                lay.put(x, y, c)
    return lay.im


def a_aurora():
    return aurora({'g': (rgb('165a34'), rgb('30a862')), 'm': (rgb('3a1446'), rgb('762a7c'))}, 5,
                  [(46, 10, 2, 0.4, 20, 'g'), (60, 7, 3, 2.6, 9, 'm'), (72, 6, 3, 2.0, 12, 'g')])


# ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
# OPCIÓN B — "Mar congelado" (más atrevida: facetas planas, turquesa, reflejos, olas heladas)
# ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
GRADS_B = {
    'day':   ['3c98c0', '54aac6', '72bccb', '94cecf', 'b8e0d6'],     # azul → turquesa claro
    'dusk':  ['221e48', '44266a', '7a387a', 'be5878', 'ec9876'],     # violeta → coral
    'night': ['030e16', '051620', '071e2a', '092634', '0c2e3e'],     # negro verdoso
}
B = dict(
    sea_f=rgb('5c9cb4'), sea_fl=rgb('86bccc'), sea_fd=rgb('4a889e'),
    cr_l=rgb('e6f6f6'), cr_m=rgb('a8dce0'), cr_d=rgb('6eb2c4'),         # cristal lejano (3 facetas)
    refl=rgb('78b6c6'),
    wv=rgb('2e8ea6'), wv_l=rgb('6cc4d0'), wv_d=rgb('1f6e8a'), foam=rgb('e4f6f4'), tube=rgb('17546c'),
    fsea=rgb('28809a'), fsea_l=rgb('4aa2b6'),
    sheet=rgb('bfe4ec'), sheet_l=rgb('e8f8fa'), sheet_d=rgb('8cc4d6'), crack=rgb('5a9ab4'),
    sh_l=rgb('d8f2f6'), sh_m=rgb('7ac6d6'), sh_d=rgb('3e94b0'),
    hull=rgb('2c3444'), hull_l=rgb('48506a'), rust=rgb('8a4a3a'), rust_l=rgb('b0644a'),
)


def crystal(lay, x, base, w, h, ridge, pal, refl=None):
    """iceberg de facetas: techo en bisel (dos alturas), faceta izquierda clara, frente medio, derecha oscura;
    y su reflejo en el agua cortado en franjas"""
    l_, m_, d_ = pal
    a = x + int(w * ridge)
    pts = [(x, base), (x + 2, base - h + 4), (a, base - h), (x + w - 3, base - h + 6), (x + w, base)]
    poly(lay, pts, m_)
    poly(lay, [(x, base), (x + 2, base - h + 4), (a, base - h), (a - 2, base)], l_)
    poly(lay, [(a + (w - a + x) // 2, base), (a + 1, base - h + 1), (x + w - 3, base - h + 6), (x + w, base)], d_)
    if refl is not None:
        for yy in range(1, int(h * 0.8)):
            if yy % 3 == 2: continue
            k = yy / (h * 0.8)
            x0 = x + 2 + int(k * w * 0.25) + (yy % 2)
            x1 = x + w - 2 - int(k * w * 0.25)
            hline(lay, x0, x1, base + 1 + yy, refl)


def b_far():
    lay = L(120)
    HZ = 40
    for y in range(HZ, 120):
        for x in range(W): lay.put(x, y, B['sea_f'])
    hline(lay, 0, W, HZ, B['sea_fl'])
    pal = (B['cr_l'], B['cr_m'], B['cr_d'])
    for (x, w, h, rd) in ((8, 46, 20, 0.35), (78, 16, 8, 0.6), (120, 30, 13, 0.3), (196, 60, 26, 0.45), (280, 14, 7, 0.5)):
        crystal(lay, x, HZ, w, h, rd, pal, B['refl'])
    # franjas de luz del mar: largas, en filas que se van separando hacia abajo (perspectiva)
    r = random.Random(4)
    y, gap = HZ + 3, 2
    while y < 120:
        x = r.randrange(W)
        while x < W + 60:
            hline(lay, x, x + 8 + r.randrange(26), y, B['sea_fl'])
            x += 30 + r.randrange(40)
        y += gap; gap += 1
    return lay.im


def frozen_wave(lay, xc, base, H, Wd):
    """ola rompiente CONGELADA: lomo que sube desde la izquierda, cresta que se enrosca hacia la derecha; bajo el
    labio la cara cóncava (en sombra, abierta: se ve el cielo detrás), espuma helada arriba y carámbanos del labio"""
    xa = xc - int(Wd * 0.7)
    r = H * 0.4
    tcx, tcy = xc + r * 0.45, base - H + 4 + r              # el hueco del rizo
    lip_end = int(tcx + r * 0.9)
    def top(x):
        if x <= xc:
            t = (x - xa) / (xc - xa)
            return base - H * t * t * (3 - 2 * t)
        return base - H + (x - xc) * 0.35
    def lipbot(x): return top(x) + max(2, 4 - (x - xc) * 0.15)
    def front(y):
        if y < tcy - r: return 1e9
        if y <= tcy + r: return tcx - math.sqrt(max(0.0, r * r - (y - tcy) ** 2))
        return tcx + (y - (tcy + r)) * 1.3
    for x in range(xa, lip_end + 1):
        ty = top(x)
        for y in range(int(ty), base + 1):
            if x > xc and y >= lipbot(x) and x > front(y): continue           # dentro del rizo: aire
            if x > lip_end - 2 and y > lipbot(x) + 1: continue
            f = front(y) - x
            c = B['wv']
            if y >= lipbot(x) and f < 3: c = B['tube']
            elif y >= lipbot(x) and f < 7 and x > xc - r: c = B['wv_d']
            elif y <= ty + 1: c = B['wv_l']
            elif x < xc and (x - xa) < (xc - xa) * 0.55 and (x + y) % 7 == 0: c = B['wv_l']
            lay.put(x, y, c)
    for x in range(int(xc - Wd * 0.3), lip_end + 1):            # espuma helada, festoneada
        ty = int(top(x))
        th = 2 + (1 if (x // 3) % 2 else 0)
        for y in range(ty - 1, ty + th): lay.put(x, y, B['foam'])
    for k in range(3):                                            # carámbanos del labio
        x = lip_end - k * 3
        ty = int(lipbot(x)) + 1
        for i in range(4 - k): lay.put(x, ty + i, B['foam'])
    for x in range(int(tcx - 2), int(tcx + r * 1.1)):             # espuma al pie del rizo
        for y in range(base - 1 - ((x // 2) % 2), base + 1):
            lay.put(x, y, B['foam'])
    for k in range(3):                                            # rayas de "movimiento" en el lomo
        for i in range(6):
            x = xa + 8 + k * 7 + i
            if x < xc - 6: lay.put(x, int(top(x)) + 4 + k * 3, B['wv_l'])


def b_mid():
    lay = L(110)
    SEA = 56
    for y in range(SEA, 110):
        for x in range(W): lay.put(x, y, B['fsea'])
    hline(lay, 0, W, SEA, B['fsea_l'])
    for (xc, H, Wd) in ((70, 44, 70), (196, 30, 46), (290, 52, 74)):
        frozen_wave(lay, xc, SEA, H, Wd)
    r = random.Random(9)
    for (fx, fw, dy) in ((20, 18, 10), (130, 12, 8), (236, 24, 16), (100, 30, 28), (300, 20, 40)):   # placas facetadas
        th = 2 + dy // 12
        poly(lay, [(fx, SEA + dy), (fx + 3, SEA + dy - th), (fx + fw - 2, SEA + dy - th), (fx + fw, SEA + dy)], B['fsea_l'])
        poly(lay, [(fx + fw * 0.6, SEA + dy), (fx + fw * 0.6 + 2, SEA + dy - th), (fx + fw - 2, SEA + dy - th), (fx + fw, SEA + dy)], B['wv_l'])
        hline(lay, fx + 1, fx + fw, SEA + dy + 1, B['wv_d'])
    for y in (SEA + 3, SEA + 7, SEA + 13, SEA + 22, SEA + 34, SEA + 49):   # grietas del mar helado
        x = r.randrange(W)
        while x < W + 30:
            hline(lay, x, x + 6 + r.randrange(14), y, B['fsea_l'])
            x += 20 + r.randrange(30)
    return lay.im


def b_near():
    lay = L(72)
    TOP = 34
    # placa de hielo: cortes de los témpanos (facetas planas) y grietas
    for y in range(TOP, 72):
        for x in range(W): lay.put(x, y, B['sheet'])
    hline(lay, 0, W, TOP, B['sheet_l'])
    r = random.Random(12)
    x = 0
    while x < W:
        x += 16 + r.randrange(26)
        y = TOP + 1
        cx = x
        while y < 72:
            lay.put(cx, y, B['crack']); y += 1
            if r.random() < 0.4: cx += r.choice((-1, 1)); lay.put(cx, y - 1, B['crack'])
    for y in (42, 50, 60):
        for x in range(W):
            if (x * 7 + y * 3) % 47 < 18: lay.put(x, y, B['sheet_d'])
    # el pecio: proa de un barco atrapada en el hielo, mástil roto
    bx = 40
    hull = [(bx, TOP + 1), (bx + 6, TOP - 16), (bx + 10, TOP - 22), (bx + 34, TOP - 12), (bx + 40, TOP + 1)]
    poly(lay, hull, B['hull'])
    poly(lay, [(bx + 6, TOP - 16), (bx + 10, TOP - 22), (bx + 34, TOP - 12), (bx + 32, TOP - 9), (bx + 9, TOP - 18)], B['hull_l'])
    for i in range(30):                                            # franja de óxido
        xx = bx + 6 + i
        yy = TOP - 14 + (i * 10) // 34 + 2
        lay.put(xx, yy, B['rust']); lay.put(xx, yy + 1, B['rust'])
    for i in range(30):                                            # mástil roto, inclinado
        lay.put(bx + 22 + i // 3, TOP - 18 - i, B['hull']); lay.put(bx + 23 + i // 3, TOP - 18 - i, B['hull_l'])
    for i in range(7): lay.put(bx + 28 + i, TOP - 42 + i // 2, B['hull'])           # la verga
    for (ix, ln) in ((bx + 12, 4), (bx + 18, 3), (bx + 26, 5), (bx + 31, 2)):        # carámbanos de la borda
        base = TOP - 20 + (ix - bx - 10) * 10 // 24 + 2
        for i in range(ln): lay.put(ix, base + i, B['sh_l'])
    for i in range(40):                                            # nieve contra el casco
        lay.put(bx - 2 + i, TOP - (2 if 6 < i < 34 else 1), B['sheet_l']); lay.put(bx - 2 + i, TOP, B['sheet_l'])
    # esquirlas: losas angulosas clavadas en la placa, dos facetas planas
    for (x0, h, w, lean) in ((110, 22, 9, 6), (122, 14, 7, -3), (131, 9, 6, 4), (196, 26, 10, -7), (208, 12, 6, 3),
                             (262, 18, 8, 5), (274, 10, 6, -2), (300, 8, 5, 3)):
        b = TOP + 2
        tip = (x0 + lean + w // 2, b - h)
        poly(lay, [(x0, b), tip, (x0 + w, b)], B['sh_m'])
        poly(lay, [(x0, b), tip, (x0 + w // 2, b)], B['sh_l'] if lean <= 0 else B['sh_m'])
        poly(lay, [(x0 + w // 2, b), tip, (x0 + w, b)], B['sh_d'] if lean <= 0 else B['sh_m'])
        if lean > 0: poly(lay, [(x0, b), tip, (x0 + w // 3, b)], B['sh_l'])
    return lay.im


def b_aurora():
    return aurora({'g': (rgb('0c3a2e'), rgb('1c7a5a')), 'm': (rgb('2a0e30'), rgb('5a1e5a'))}, 8,
                  [(40, 12, 2, 1.2, 16, 'g'), (58, 8, 3, 3.1, 10, 'm'), (74, 5, 1, 0.3, 8, 'g')])


OPTIONS = {
    'A': dict(grads=GRADS_A, far=a_far, mid=a_mid, near=a_near, aurora=a_aurora, par=(0.08, 0.2, 0.38),
              title='A - costa de tempanos (estilo de la casa)'),
    'B': dict(grads=GRADS_B, far=b_far, mid=b_mid, near=b_near, aurora=b_aurora, par=(0.08, 0.2, 0.38),
              title='B - mar congelado (mas atrevida)'),
}


# ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
# Vista previa: el fondo como lo compone Sky.lua (capas apoyadas en el fondo del nivel) + bloques reales delante
# ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
WIN_W, WIN_H = J.WIN_W, J.WIN_H
TIMES = J.TIMES
up, tint, alpha_mul, tile_x, draw_layer, label = J.up, J.tint, J.alpha_mul, J.tile_x, J.draw_layer, J.label
TIL = os.path.join(REPO, 'assets/images/world/tiles')


def build(opt):
    o = OPTIONS[opt]
    grads = {t: J.grad_frame(c) for t, c in o['grads'].items()}
    layers = {'far': o['far'](), 'mid': o['mid'](), 'near': o['near'](), 'aurora': o['aurora']()}
    return grads, layers


def sky_base(grad, time):
    """degradado + sol / luna y estrellas + nubes, como Sky.render (copiado de make_jungle_sky.sky_base)"""
    g = grad.resize((WIN_W, WIN_H), Image.NEAREST)
    cv = Image.new('RGBA', (WIN_W, WIN_H)); cv.alpha_composite(g)
    t = TIMES[time]
    gs = J.GAME_SKY
    if time == 'night':
        st = Image.open(os.path.join(gs, 'stars.png')).convert('RGBA')
        for i in range(1, 71):
            v = math.sin(i * 12.9898) * 43758.5453; u = math.sin(i * 78.233) * 12345.678
            sx, sy, f = v - math.floor(v), (u - math.floor(u)) * 0.62, i % 3 + 1
            fr = alpha_mul(st.crop(((f - 1) * 3, 0, f * 3, 3)), 0.85).resize((9, 9), Image.NEAREST)
            cv.alpha_composite(fr, (int(sx * WIN_W) % WIN_W, int(sy * WIN_H)))
        cv.alpha_composite(up(Image.open(os.path.join(gs, 'moon.png')).convert('RGBA')), (int(WIN_W * 0.78), 70))
    else:
        sun = up(Image.open(os.path.join(gs, 'sun.png')).convert('RGBA'))
        if time == 'dusk': cv.alpha_composite(tint(sun, (1, 0.75, 0.55)), (int(WIN_W * 0.8), 330))
        else: cv.alpha_composite(sun, (int(WIN_W * 0.76), 60))
    cl = Image.open(os.path.join(gs, 'clouds.png')).convert('RGBA')
    for (cx, cy, v) in ((0.05, 70, 1), (0.32, 140, 2), (0.58, 95, 3), (0.81, 180, 1)):
        c = alpha_mul(tint(up(cl.crop(((v - 1) * 48, 0, v * 48, 16))), t), 0.7 if time == 'night' else 0.95)
        cv.alpha_composite(c, (int(cx * WIN_W), cy))
    return cv


def add_layer(cv, im1x, p, camX, y, a=0.4):
    """capa aditiva (como `add = true` en Sky.lua: alfa 0.35..0.45)"""
    lay = up(im1x)
    tmp = Image.new('RGBA', (WIN_W, WIN_H)); tile_x(tmp, lay, camX, p, y)
    base = np.array(cv).astype(np.float32); add = np.array(tmp).astype(np.float32)
    k = add[..., 3:4] / 255.0 * a
    base[..., :3] = np.clip(base[..., :3] + add[..., :3] * k, 0, 255)
    return Image.fromarray(base.astype(np.uint8))


def background(opt, time, grads, layers, camX=900):
    t = TIMES[time]
    cv = sky_base(grads[time], time)
    if time == 'night':
        cv = add_layer(cv, layers['aurora'], 0.03, camX, WIN_H - layers['aurora'].height * S)
    for name, p in zip(('far', 'mid', 'near'), OPTIONS[opt]['par']):
        im = layers[name]
        draw_layer(cv, im, p, camX, WIN_H - im.height * S, t)
        if time != 'day':                         # lo "incandescente" (ámbar) no se tiñe: Sky.lua lo repinta (glow)
            a = np.array(im); r_, g_, b_ = (a[..., k].astype(int) for k in range(3))
            hot = (a[..., 3] > 0) & (r_ >= 153) & (g_ <= r_ * 0.72) & (b_ <= 76)
            a[~hot] = 0
            tile_x(cv, up(Image.fromarray(a)), camX, p, WIN_H - im.height * S)
    return cv


def snow_background(camX=900):
    """el fondo de hoy (`snow`, las Montañas Heladas) con la misma escena, para comparar"""
    g = Image.open(os.path.join(SKY, 'gradients.png')).convert('RGBA').crop((0, 0, 8, 180))
    cv = sky_base(g, 'day')
    for name, p in (('far', 0.08), ('mid', 0.2), ('near', 0.38)):
        im = Image.open(os.path.join(SKY, 'snow_%s.png' % name)).convert('RGBA')
        draw_layer(cv, im, p, camX, WIN_H - im.height * S, TIMES['day'])
    return cv


# ── La escena: bloques reales del juego (nieve, hielo, plataforma), agua, el monstruo y un cangrejo de hielo ──────
# s = nieve · i = hielo · p = plataforma · w = agua · . = aire     (20 x 12; la fila 0 empieza 48 px por encima)
SCENE = [
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "...ppp...........ii.",
    ".................ii.",
    ".................ii.",
    ".............sssssss",
    "sssssss..ii..sssssss",
    "sssssssswwwwwsssssss",
    "sssssssswwwwwsssssss",
]


def tex(name, alpha=1.0):
    im = Image.open(os.path.join(TIL, name + '.png')).convert('RGBA')
    return alpha_mul(im, alpha) if alpha < 1 else im


def draw_tiles(cv, oy=-48):
    k = 64
    T = {'s': tex('snow'), 'i': tex('ice', 0.78), 'p': tex('platform')}
    at = lambda r, c: SCENE[r][c] if 0 <= r < 12 and 0 <= c < 20 else '#'
    group = {'s': 'g', 'i': 'i', '#': '#'}
    d = ImageDraw.Draw(cv)
    for r in range(12):
        for c in range(20):
            n = SCENE[r][c]
            if n not in T: continue
            x, y = c * k, oy + r * k
            cv.alpha_composite(T[n], (x, y))
            if n == 'p': continue
            col = (255, 255, 255, 255) if n == 's' else (224, 240, 255, 230)
            for (dr, dc, box) in ((-1, 0, (x, y, x + k - 1, y + 1)), (1, 0, (x, y + k - 2, x + k - 1, y + k - 1)),
                                  (0, -1, (x, y, x + 1, y + k - 1)), (0, 1, (x + k - 2, y, x + k - 1, y + k - 1))):
                nb = at(r + dr, c + dc)
                if group.get(nb) != group[n] and nb != '#': d.rectangle(box, fill=col)
    return cv


def draw_water(cv, oy=-48):
    """tinte del agua (material water: 0.05, 0.30, 0.90, 0.35) y una franja clara en la superficie (aprox. de
    WaterSurface: en el juego ondula)"""
    ov = Image.new('RGBA', cv.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    cells = {(r, c) for r in range(12) for c in range(20) if SCENE[r][c] == 'w'} | {(9, 7), (9, 8), (9, 11), (9, 12)}
    for (r, c) in cells:
        x, y = c * 64, oy + r * 64
        top = (r, c) in {(9, 7), (9, 8), (9, 11), (9, 12)}
        d.rectangle((x, y + (8 if top else 0), x + 63, y + 63), fill=(13, 77, 230, 89))
        if top: d.rectangle((x, y + 8, x + 63, y + 11), fill=(200, 230, 255, 120))
    cv.alpha_composite(ov)
    return cv


def player(cv, x, y_feet):
    p = up(Image.open(os.path.join(REPO, 'assets/images/player/monstrito1.png')).convert('RGBA'), 6)
    cv.alpha_composite(p, (x, y_feet - p.height))


def crab(cv, x, y_feet):
    c = up(Image.open(os.path.join(REPO, 'assets/images/enemies/crabby_ice/crab1.png')).convert('RGBA'), 4)
    cv.alpha_composite(c, (x, y_feet - c.height))


def scene(cv, opt=None):
    """bloques, decoraciones de la misma opción (make_frozen_coast_decor.py, si está), el monstruo, un cangrejo de
    hielo y el agua encima (como en el juego, el tinte del agua va después de todo)"""
    draw_tiles(cv)
    if opt:
        try:
            import make_frozen_coast_decor as D
            D.place_in_scene(cv, opt, -48)
        except ImportError as e:
            print('  (sin decoraciones: %s)' % e)
    player(cv, 2 * 64 + 5, 9 * 64 - 48)
    crab(cv, 15 * 64 - 4, 8 * 64 - 48)
    draw_water(cv)
    return cv


def layer_sheet(opt, grads, layers):
    """las capas a x2 sobre su degradado de día (y la aurora sobre el de noche)"""
    out = Image.new('RGBA', (1320, 960), rgb('20242a'))
    label(out, 'opcion %s - capas a x2 (320 de ancho = se repite)' % opt, (20, 14), 12)
    y = 44
    for n in ('far', 'mid', 'near', 'aurora'):
        im = up(layers[n], 2)
        gname = 'night' if n == 'aurora' else 'day'
        bg = grads[gname].resize((im.width, im.height + 20), Image.NEAREST)
        out.alpha_composite(bg, (20, y))
        if n == 'aurora':
            a = np.array(im).astype(np.float32); a[..., :3] = np.clip(a[..., :3] * 2.2, 0, 255)
            out.alpha_composite(Image.fromarray(a.astype(np.uint8)), (20, y + 20))
        else:
            out.alpha_composite(im, (20, y + 20))
        label(out, '%s_%s  (%dx%d)' % (ID, n, layers[n].width, layers[n].height), (20 + im.width + 16, y + 20), 8)
        y += im.height + 34
    x = 1060
    for i, t in enumerate(('day', 'dusk', 'night')):
        out.alpha_composite(grads[t].resize((60, 360), Image.NEAREST), (x + i * 80, 44 + 0))
        label(out, t, (x + i * 80, 410), 8)
    return out


def main():
    os.makedirs(os.path.join(PREV, 'capas'), exist_ok=True)
    built = {}
    for opt in ('A', 'B'):
        grads, layers = build(opt)
        built[opt] = (grads, layers)
        for n, im in layers.items(): im.save(os.path.join(PREV, 'capas', '%s_%s_%s.png' % (opt, ID, n)))
        gs = Image.new('RGBA', (24, 180))
        for i, t in enumerate(('day', 'dusk', 'night')): gs.paste(grads[t], (i * 8, 0))
        gs.save(os.path.join(PREV, 'capas', '%s_%s_gradients.png' % (opt, ID)))
        layer_sheet(opt, grads, layers).convert('RGB').save(os.path.join(PREV, 'capas_%s.png' % opt))
    shots = {}
    for opt in ('A', 'B'):
        grads, layers = built[opt]
        for tm in ('day', 'dusk', 'night'):
            im = scene(background(opt, tm, grads, layers), opt)
            im.convert('RGB').save(os.path.join(PREV, 'escena_%s_%s.png' % (opt, tm)))
            shots[(opt, tm)] = im
    ref = scene(snow_background())
    ref.convert('RGB').save(os.path.join(PREV, 'comparar_snow_montanas.png'))
    out = Image.new('RGB', (2560, 2160 + 120), rgb('20242a'))
    names = {'day': 'dia', 'dusk': 'atardecer', 'night': 'noche'}
    for i, opt in enumerate(('A', 'B')):
        label(out, OPTIONS[opt]['title'], (i * 1280 + 16, 30), 16)
        for j, tm in enumerate(('day', 'dusk', 'night')):
            out.paste(shots[(opt, tm)].convert('RGB'), (i * 1280, 120 + j * 720))
            label(out, '%s - %s' % (opt, names[tm]), (i * 1280 + 16, 120 + j * 720 + 16), 16)
    out.save(os.path.join(PREV, 'vista_previa.png'))
    print('vista previa:', os.path.join(PREV, 'vista_previa.png'))
    if APPLY: apply(built)


def apply(built):
    """escribe la opción elegida (--apply A|B) en assets/ (no pisa nada que exista)"""
    args = sys.argv[sys.argv.index('--apply') + 1:]
    opt = args[0].upper() if args and args[0].upper() in OPTIONS else None
    if not opt: print('--apply necesita la opción: --apply A  o  --apply B'); return
    grads, layers = built[opt]
    def put(path, im):
        if os.path.exists(path): print('  %s ya existe: no se toca' % path); return
        im.save(path); print('  %-52s %dx%d' % (os.path.relpath(path, REPO), im.width, im.height))
    for n, im in layers.items(): put(os.path.join(SKY, '%s_%s.png' % (ID, n)), im)
    gp = os.path.join(SKY, 'gradients.png')
    g = Image.open(gp).convert('RGBA')
    if g.width == 112:                                    # cuadros 15..17: frozen_coast_day, _dusk, _night
        ng = Image.new('RGBA', (112 + 24, 180)); ng.paste(g, (0, 0))
        for i, t in enumerate(('day', 'dusk', 'night')): ng.paste(grads[t], (112 + i * 8, 0))
        ng.save(gp); print('  %s: +3 cuadros (15..17)' % os.path.relpath(gp, REPO))
    else:
        print('  %s tiene %d cuadros (se esperaban 14): no se toca' % (gp, g.width // 8))


if __name__ == '__main__':
    main()
