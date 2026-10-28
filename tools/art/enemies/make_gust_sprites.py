#!/usr/bin/env python3
# EL SOPLÓN (enemigo nuevo, aprobado por el usuario en 0.5.67 — diseño en curso): una bolita de aire con cara que flota,
# INSPIRA (se hincha) y SOPLA una ráfaga horizontal que empuja. Un aspecto por isla:
#   pradera: vilano de diente de león · costa: espuma de mar · fortaleza: hollín de chimenea · nieve: nubecilla de nieve
#   cueva: polvo pálido que brilla · volcán: ceniza con ascuas
# Hoja de 16x16 por cuadro (mira a la IZQUIERDA; el juego la voltea): 1-2 flotando · 3-4 inspirando (se hincha) ·
# 5-6 soplando (boca abierta, se deshincha) · 7-8 revienta. Y la RÁFAGA: partículas de 8x8 (3 cuadros) por isla.
# Estilo de la casa (docs/art/style-rules.md): contorno = el tono más oscuro de su color, brillo arriba a la izquierda,
# sombra abajo a la derecha, 3-4 tonos, 1 px de margen.
#   python3 tools/art/enemies/make_gust_sprites.py            → vistas previas en FlappyMonster_pruebas/nuevos/soplon/
#   python3 tools/art/enemies/make_gust_sprites.py --apply    → assets/images/enemies/gust/<isla>-Sheet.png + wind-Sheet.png
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'nuevos', 'soplon')
OUT = os.path.join(ROOT, 'assets', 'images', 'enemies', 'gust')
W = H = 16
NAVY = '1e1e2a'


def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# (contorno, sombra, cuerpo, brillo, ojos, acento 1, acento 2)
ISLES = {
    'pradera':   dict(o='5a6a3c', s='c9c2a0', b='f2eedc', h='ffffff', e=NAVY, x='7cc850', y='3e8c3c', bg='8cc8f0'),
    'costa':     dict(o='2c6a8a', s='9cd4e4', b='e4f8fc', h='ffffff', e=NAVY, x='3cb4b4', y='ffffff', bg='9cdcf0'),
    'fortaleza': dict(o='1c1c24', s='3a3a46', b='5c5c6c', h='8a8a9a', e='f0e6c8', x='2c2c34', y='a8a8b4', bg='8a8ea8'),
    'nieve':     dict(o='3c6a9c', s='a8cce8', b='e8f4ff', h='ffffff', e=NAVY, x='ffffff', y='bee4fa', bg='b8d4f0'),
    'cueva':     dict(o='4c3c6c', s='9c88c4', b='d8ccf0', h='f4eeff', e='2a6a8a', x='b4f4ff', y='e8fcff', bg='3a3450'),
    'volcan':    dict(o='1e1414', s='3a2a28', b='5a4440', h='7a625a', e='ffd23c', x='ff8a28', y='ffd23c', bg='6a2c2c'),
}


# ── EL CUERPO: una NUBE de bollitos (círculos) que se mueven de un cuadro a otro (0.5.67, el usuario: "más nube, que su
# cuerpo vaya cambiando, más transparente y redondeado"). Cada bollito: (dx, dy, radio) respecto al centro; el borde va
# SEMITRANSPARENTE y el relleno algo transparente, con brillos opacos arriba a la izquierda.
PUFFS = {   # cuadro → bollitos
    'idle1':   [(-3.6, 1.0, 2.9), (-0.8, -1.4, 3.4), (2.6, -0.6, 3.0), (4.4, 1.6, 2.3), (0.6, 2.0, 3.2)],
    'idle2':   [(-3.9, 1.4, 2.7), (-1.0, -1.0, 3.5), (2.3, -1.1, 3.1), (4.6, 1.2, 2.4), (0.3, 2.3, 3.0)],
    'inhale1': [(-4.1, 0.8, 3.2), (-1.0, -1.9, 3.7), (2.8, -1.1, 3.4), (4.8, 1.4, 2.7), (0.4, 1.8, 3.6)],
    'inhale2': [(-4.4, 0.6, 3.5), (-1.1, -2.3, 4.0), (3.0, -1.5, 3.7), (5.0, 1.3, 3.0), (0.4, 1.7, 4.0)],
    'blow1':   [(-3.2, 0.8, 3.3), (-0.6, -1.3, 3.4), (2.6, -0.7, 3.0), (4.3, 1.5, 2.4), (0.6, 2.0, 3.2)],
    'blow2':   [(-2.8, 1.0, 2.9), (-0.4, -0.9, 3.0), (2.4, -0.4, 2.7), (4.0, 1.6, 2.1), (0.8, 2.0, 2.9)],
}
A_EDGE, A_BODY, A_SHADE = 150, 215, 230        # alfa: borde, cuerpo, sombra (los brillos y la cara, opacos)


def cloud(puffs, cx=7.5, cy=8.5):
    """→ rejilla de papeles + alfa por píxel"""
    cover = lambda x, y: any((x - (cx + dx)) ** 2 + (y - (cy + dy)) ** 2 <= r * r for dx, dy, r in puffs)
    g = [['.'] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if not cover(x, y): continue
            edge = any(not cover(x + ax, y + ay) for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge: g[y][x] = 'o'; continue
            # brillo: el filo de ARRIBA y de la IZQUIERDA (a 2 px del borde); sombra: el filo de abajo (sin rayas)
            if not cover(x, y - 2) or (not cover(x - 2, y) and y < cy + 1): g[y][x] = 'h'
            elif not cover(x, y + 2): g[y][x] = 's'
            else: g[y][x] = 'b'
    return g


def put(g, x, y, c):
    if 0 <= x < W and 0 <= y < H: g[y][x] = c


def face(g, kind, cx=7, cy=8):
    """Ojos y boca (mira a la izquierda). kind: idle · inhale (ojos apretados, mofletes) · blow · pop"""
    if kind == 'pop': return
    if kind == 'inhale':
        for x in (cx - 3, cx - 2, cx + 1, cx + 2): put(g, x, cy - 1, 'e')    # ojos apretados (rayas)
        put(g, cx - 4, cy + 1, 'c'); put(g, cx + 3, cy + 1, 'c')            # mofletes (rosados)
        put(g, cx - 1, cy + 2, 'e'); put(g, cx, cy + 2, 'e')                # boca apretada
        return
    ex = cx - 1 if kind == 'blow' else cx - 2                               # (soplando: la cara se va hacia atrás)
    for x in (ex, ex + 3):
        put(g, x, cy - 2, 'e'); put(g, x, cy - 1, 'e')
    put(g, ex, cy - 2, 'w'); put(g, ex + 3, cy - 2, 'w')                    # el brillo del ojo
    if kind == 'blow':
        # LA BOCA SOPLANDO (rehecha, 0.5.67: "no se lee como una boca"): unos LABIOS en O fruncidos, bien redondos, con el
        # agujero oscuro dentro, los mofletes hinchados detrás y el aire que sale por delante
        mx, my = cx - 5, cy
        for dx, dy in ((1, 0), (2, 0), (0, 1), (3, 1), (0, 2), (3, 2), (1, 3), (2, 3)): put(g, mx + dx, my + dy, 'l')   # labios
        for dx, dy in ((1, 1), (2, 1), (1, 2), (2, 2)): put(g, mx + dx, my + dy, 'm')                                  # el agujero
        put(g, cx + 2, cy + 1, 'c'); put(g, cx + 3, cy + 1, 'c')                                                        # moflete
        for dx, dy in ((-1, 1), (-2, 2), (-1, 2)): put(g, mx + dx, my + dy, 'a')                                         # el aire
    else:
        put(g, ex + 1, cy + 1, 'e'); put(g, ex + 2, cy + 1, 'e')                                                         # boquita


def deco(g, isle, frame, big):
    """Lo de cada isla, encima del cuerpo (pocos píxeles: que la nube mande)"""
    top = next(y for y in range(H) if any(c != '.' for c in g[y]))
    if isle == 'pradera':                                                   # el vilano: un brote y semillitas
        put(g, 7, top - 1, 'y'); put(g, 8, top - 2, 'x'); put(g, 6, top - 2, 'x')
        put(g, 2, top + 3, 'x'); put(g, 14, top + 4, 'x')
    elif isle == 'costa':                                                   # burbujas de espuma
        put(g, 13, top, 'x'); put(g, 14, top - 1, 'y'); put(g, 2, top + 2, 'x')
    elif isle == 'fortaleza':                                               # volutas que suben
        put(g, 6, top - 1, 'x'); put(g, 9, top - 2, 'x'); put(g, 10, top - 3, 'y')
    elif isle == 'nieve':                                                   # un copo
        for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)): put(g, 8 + dx, top - 2 + dy, 'x')
        put(g, 8, top - 2, 'y')
    elif isle == 'cueva':                                                   # motas de luz
        for x, y in ((1, top + 3), (14, top + 1), (13, min(H - 1, top + 9))): put(g, x, y, 'x' if frame % 2 else 'y')
    elif isle == 'volcan':                                                  # ascuas
        for x, y in ((5, top + 2), (11, top + 3), (9, top + 7)): put(g, x, y, 'x')
        put(g, 8, top - 1, 'y' if frame % 2 else 'x')


FRAMES = [('idle1', 'idle'), ('idle2', 'idle'), ('inhale1', 'inhale'), ('inhale2', 'inhale'), ('blow1', 'blow'), ('blow2', 'blow')]
BOB = [0, 1, 0, -1, 0, 0]


def pop_frame(k):
    """Revienta: la nube se deshace en bollitos sueltos que se van (k = 0, 1)"""
    puffs = [(-5 - 2 * k, -2 - k, 1.6 - 0.4 * k), (4 + 2 * k, -3 - k, 1.5 - 0.4 * k), (-4 - k, 3 + k, 1.4 - 0.4 * k),
             (5 + 2 * k, 3 + k, 1.6 - 0.4 * k), (0, 0, 2.0 - 0.8 * k)]
    return cloud(puffs)


EXTRA = {'w': 'ffffff', 'm': '1e1e2a', 'a': 'ffffff'}           # brillo del ojo, el agujero de la boca, el aire
LIPS = {'pradera': 'b88a6a', 'costa': '7ab4c8', 'fortaleza': '2c2c34', 'nieve': '7aaee0', 'cueva': '8c78b4', 'volcan': '2a1c1c'}
CHEEK = {'pradera': 'f0a8a0', 'costa': 'f4b8c4', 'fortaleza': '9a7a84', 'nieve': 'f4c4d8', 'cueva': 'd8a8e0', 'volcan': 'c85a3c'}


def paint(g, pal, isle):
    alpha = {'o': A_EDGE, 'b': A_BODY, 's': A_SHADE}
    im = Image.new('RGBA', (W, H))
    for y in range(H):
        for x in range(W):
            c = g[y][x]
            if c == '.': continue
            col = EXTRA.get(c) or (LIPS[isle] if c == 'l' else (CHEEK[isle] if c == 'c' else pal[c]))
            im.putpixel((x, y), rgb(col)[:3] + (alpha.get(c, 255),))
    return im


def sheet(isle):
    pal = ISLES[isle]
    ims = []
    for i, (key, kind) in enumerate(FRAMES):
        g = cloud(PUFFS[key], cy=8.5 + BOB[i])
        face(g, kind, cy=8 + BOB[i])
        deco(g, isle, i, kind == 'inhale')
        ims.append(paint(g, pal, isle))
    for k in (0, 1):
        g = pop_frame(k)
        for x, y in ((3, 4 - k), (12, 5 - k), (2, 12), (13, 13)): put(g, x, y, 'x')
        ims.append(paint(g, pal, isle))
    out = Image.new('RGBA', (W * len(ims), H))
    for i, im in enumerate(ims): out.paste(im, (i * W, 0), im)
    return out


def wind(isle):
    """La RÁFAGA: 3 cuadros de 8x8 — una racha (líneas) con lo que arrastra en cada isla"""
    pal = ISLES[isle]
    out = Image.new('RGBA', (8 * 3, 8))
    carry = {'pradera': 'x', 'costa': 'y', 'fortaleza': 'x', 'nieve': 'x', 'cueva': 'x', 'volcan': 'x'}[isle]
    for f in range(3):
        g = [['.'] * 8 for _ in range(8)]
        for row, x0, ln in ((2, f, 5), (5, (f + 3) % 4, 4)):
            for dx in range(ln):
                x = (x0 + dx) % 8
                g[row][x] = 'h' if dx < ln - 1 else 'b'
        g[(f * 3 + 1) % 7][(f * 2 + 6) % 8] = carry
        g[(f * 3 + 4) % 7][(f * 5 + 1) % 8] = carry
        im = Image.new('RGBA', (8, 8))
        for y in range(8):
            for x in range(8):
                c = g[y][x]
                if c != '.':
                    col = rgb(pal[c])
                    if c in ('h', 'b'): col = col[:3] + (200,)
                    im.putpixel((x, y), col)
        out.paste(im, (f * 8, 0), im)
    return out


def preview(sheets, winds):
    S = 8
    labels_w = 0
    rows = len(sheets)
    big = Image.new('RGBA', (W * 8 * S + 8 * 3 * S + 40, H * S * rows), rgb('6e9a6e'))
    for k, isle in enumerate(sheets):
        bg = Image.new('RGBA', (W * 8 * S + 8 * 3 * S + 40, H * S), rgb(ISLES[isle]['bg']))
        a = sheets[isle].resize((W * 8 * S, H * S), Image.NEAREST)
        bg.paste(a, (0, 0), a)
        w = winds[isle].resize((8 * 3 * S, 8 * S), Image.NEAREST)
        bg.paste(w, (W * 8 * S + 40, 4 * S), w)
        big.paste(bg, (0, k * H * S))
    return big


def gif(isle, sh, path):
    """Animación: flota · inspira · sopla (con la ráfaga saliendo) · flota, a ×6 sobre su fondo"""
    S = 6
    order = [0, 1, 0, 1, 2, 3, 3, 4, 4, 5, 5, 0, 1, 0, 1, 6, 7]
    dur = [220, 220, 220, 220, 260, 260, 200, 120, 120, 120, 120, 220, 220, 220, 220, 90, 90]
    wd = wind(isle)
    frames = []
    for n, i in enumerate(order):
        cv = Image.new('RGBA', (W * 3, H), rgb(ISLES[isle]['bg']))
        fr = sh.crop((i * W, 0, (i + 1) * W, H))
        cv.paste(fr, (W * 2, 0), fr)
        if i in (4, 5):                                                    # la ráfaga sale por la izquierda
            for j in range(4):
                wf = wd.crop(((n + j) % 3 * 8, 0, ((n + j) % 3 + 1) * 8, 8))
                cv.paste(wf, (W * 2 - 8 - j * 8, 5), wf)
        frames.append(cv.resize((cv.width * S, cv.height * S), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=dur, loop=0, disposal=2)


if __name__ == '__main__':
    sheets = {isle: sheet(isle) for isle in ISLES}
    winds = {isle: wind(isle) for isle in ISLES}
    if '--apply' in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        for isle, im in sheets.items(): im.save(os.path.join(OUT, isle + '-Sheet.png'))
        w = Image.new('RGBA', (8 * 3, 8 * len(ISLES)))
        for k, isle in enumerate(ISLES): w.paste(winds[isle], (0, k * 8), winds[isle])
        w.save(os.path.join(OUT, 'wind-Sheet.png'))
        print('  ' + OUT)
    os.makedirs(PRUEBAS, exist_ok=True)
    preview(sheets, winds).save(os.path.join(PRUEBAS, 'vista_previa.png'))
    for isle in ISLES: gif(isle, sheets[isle], os.path.join(PRUEBAS, f'anim_{isle}.gif'))
    print('  ' + PRUEBAS)
