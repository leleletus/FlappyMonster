#!/usr/bin/env python3
# tools/art/ui/make_menu_ui.py — el arte de los MENÚS (src/ui/menu/, docs/architecture/menus.md), en pixel art a 1x:
#   assets/images/ui/menus/title_logo.png + .json   el logo del título REMASTERIZADO: el recuadro blanco y cada
#        letra por separado. Sale del logo de siempre (assets/images/ui/menus/logo.png, que NO se toca: lo usa
#        también el final de la historia): se guardan todos sus píxeles y solo se añade el estilo de la casa. El
#        .json dice dónde está el recuadro y cada letra en la hoja y dónde va cada letra (para que salgan una a una).
#   assets/images/ui/menus/button.png + .json       los BOTONES (9-slice): una columna por color, fila 1 normal y
#        fila 2 seleccionado (más claro y con borde blanco), en tonos
#        apagados (MUTE). El .json: tamaño de celda, cortes y nombres de color.
#   assets/images/ui/menus/cartridge.png + .json, cart_labels.png   los CARTUCHOS de las partidas (ver abajo).
#   assets/images/ui/menus/panel.png                el PANEL (9-slice) de las pantallas con contenido (partidas,
#        juego libre, online): azul noche translúcido con borde claro.
# Desde la raíz del repo:  python3 tools/art/ui/make_menu_ui.py
import json, os
from PIL import Image

DIR = 'assets/images/ui/menus'

# Paleta: por color, 5 tonos de oscuro a claro: contorno, labio (cara de abajo), sombra, medio, luz
PAL = {
    'green':  [(24, 70, 38), (36, 104, 52), (52, 140, 62), (88, 190, 78), (168, 236, 128)],
    'orange': [(96, 40, 20), (150, 62, 26), (200, 96, 36), (244, 146, 52), (255, 212, 120)],
    'blue':   [(24, 40, 96), (34, 64, 142), (48, 98, 190), (80, 148, 236), (160, 212, 255)],
    'pink':   [(96, 24, 66), (146, 40, 98), (196, 62, 128), (240, 108, 170), (255, 186, 218)],
    'purple': [(52, 26, 96), (82, 40, 142), (112, 62, 188), (156, 104, 232), (214, 180, 255)],
    'yellow': [(100, 70, 10), (156, 110, 20), (206, 156, 30), (246, 206, 58), (255, 240, 150)],
    'red':    [(96, 22, 22), (146, 34, 34), (196, 52, 46), (238, 90, 72), (255, 168, 150)],
    'teal':   [(16, 70, 72), (24, 106, 106), (34, 146, 140), (60, 196, 180), (150, 240, 224)],
    'grey':   [(40, 42, 52), (64, 66, 80), (92, 96, 110), (128, 132, 146), (186, 190, 202)],
}
# (los BOTONES usan la paleta APAGADA: cada tono se acerca MUTE a su gris; el usuario, 3.103: demasiado coloridos)
MUTE = 0.38


def muted(c):
    g = 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]
    return tuple(int(round(v + (g - v) * MUTE)) for v in c)


ORDER = ['green', 'orange', 'blue', 'pink', 'purple', 'yellow', 'red', 'teal', 'grey']


def lighter(c, k):
    return tuple(int(round(v + (255 - v) * k)) for v in c)


# ── Logo ────────────────────────────────────────────────────────────────────
# El logo de SIEMPRE (recuadro blanco y letras oscuras), remasterizado a 2x: se guardan TODOS los píxeles de las
# letras y del recuadro y se les añade el estilo de la casa. Recuadro: contorno azul noche, luz arriba / izquierda,
# sombra abajo / derecha, un filete interior (eco del marco del original) y un labio de relieve debajo. Letras: azul
# noche casi negro con un brillo arriba y una sombra suave en relieve sobre el blanco. Sin colores chillones.
K, LIP = 2, 2
INK = (28, 30, 48)          # letras
INK_HI = (74, 80, 116)      # brillo de arriba de cada trazo
INK_SH = (192, 196, 212)    # sombra de las letras sobre el blanco (relieve)
BOX = {'outline': (30, 34, 56), 'hi': (255, 255, 255), 'body': (244, 242, 234), 'shade': (214, 214, 222),
       'line': (206, 210, 222), 'lip': (176, 180, 198)}


def logo():
    src = Image.open(os.path.join(DIR, 'logo.png')).convert('RGBA')
    W, H = src.size
    ink = [[src.getpixel((x, y))[3] > 0 and src.getpixel((x, y))[:3] == (0, 0, 0) for x in range(W)] for y in range(H)]
    # el recuadro: la tinta del borde es el marco (lo redibuja el estilo); dentro, las letras
    for y in range(H):
        for x in range(W):
            if x in (0, W - 1) or y in (0, H - 1):
                ink[y][x] = False
    # filas de texto: bandas de filas con tinta; dentro, letras = columnas con tinta separadas por columnas vacías
    rows = [y for y in range(H) if any(ink[y])]
    bands, cur = [], [rows[0]]
    for y in rows[1:]:
        if y == cur[-1] + 1: cur.append(y)
        else: bands.append(cur); cur = [y]
    bands.append(cur)
    letters = []
    for band in bands:
        y0, y1 = band[0], band[-1]
        cols = [x for x in range(W) if any(ink[y][x] for y in band)]
        runs, cur = [], [cols[0]]
        for x in cols[1:]:
            if x == cur[-1] + 1: cur.append(x)
            else: runs.append(cur); cur = [x]
        runs.append(cur)
        for r in runs: letters.append((r[0], y0, r[-1], y1))
    assert len(letters) == 13, 'el logo tiene %d letras' % len(letters)
    # ── el recuadro (W*K x H*K + labio) ──
    bw, bh = W * K, H * K
    box = Image.new('RGBA', (bw, bh + LIP), (0, 0, 0, 0))
    for y in range(bh + LIP):
        for x in range(bw):
            if x in (0, bw - 1) or y in (0, bh + LIP - 1): c = BOX['outline']
            elif y >= bh - 1: c = BOX['lip']                                  # labio de relieve
            elif y == 1 or x == 1: c = BOX['hi']                              # luz
            elif y == bh - 2 or x == bw - 2: c = BOX['shade']                 # sombra
            elif (x in (4, bw - 5) and 4 <= y <= bh - 5) or (y in (4, bh - 5) and 4 <= x <= bw - 5): c = BOX['line']
            else: c = BOX['body']
            box.putpixel((x, y), c + (255,))
    # ── las letras: cada una en su celda (trazo a K x, su sombra 1 px abajo a la derecha, 1 px de margen) ──
    cells, sx = [], bw
    for (x0, y0, x1, y1) in letters:
        w, h = (x1 - x0 + 1) * K + 2, (y1 - y0 + 1) * K + 2
        cells.append((sx, w, h))
        sx += w
    sheet = Image.new('RGBA', (sx, max(bh + LIP, max(c[2] for c in cells))), (0, 0, 0, 0))
    sheet.paste(box, (0, 0))
    meta = []
    for (x0, y0, x1, y1), (cx, w, h) in zip(letters, cells):
        def on(xx, yy):
            if xx < 0 or yy < 0: return False
            x, y = x0 + xx // K, y0 + yy // K
            return x0 <= x <= x1 and y0 <= y <= y1 and ink[y][x]
        for yy in range(h):
            for xx in range(w):
                ax, ay = xx - 1, yy - 1
                if on(ax, ay):
                    c = INK_HI if not on(ax, ay - 1) else INK
                    sheet.putpixel((cx + xx, yy), c + (255,))
                elif on(ax - 1, ay - 1):
                    sheet.putpixel((cx + xx, yy), INK_SH + (255,))
        # x, y = dónde va la esquina de la celda en el logo (px del logo a K x; el recuadro empieza en 0, 0)
        meta.append({'sx': cx, 'sy': 0, 'w': w, 'h': h, 'x': x0 * K - 1, 'y': y0 * K - 1, 'line': 1 if y0 < bands[1][0] else 2})
    sheet.save(os.path.join(DIR, 'title_logo.png'))
    with open(os.path.join(DIR, 'title_logo.json'), 'w') as f:
        json.dump({'w': bw, 'h': bh + LIP, 'k': K, 'box': {'sx': 0, 'sy': 0, 'w': bw, 'h': bh + LIP}, 'letters': meta}, f, indent=1)
    print('title_logo.png: recuadro + %d letras, hoja %dx%d' % (len(meta), sheet.size[0], sheet.size[1]))


# ── Botones (9-slice) ───────────────────────────────────────────────────────
# Celda 8x8 a 1x. Cortes: 2 izquierda, 2 derecha, 2 arriba, 3 abajo (el labio de abajo da el relieve).
CELL, CUT = 8, {'l': 2, 'r': 2, 't': 2, 'b': 3}


def button_cell(p, sel):
    t = [lighter(c, 0.12) for c in p] if sel else p
    outline = (255, 255, 255) if sel else t[0]
    im = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
    for y in range(CELL):
        for x in range(CELL):
            if x in (0, CELL - 1) or y in (0, CELL - 1): c = outline
            elif y == CELL - 2: c = t[1]                    # labio
            elif y == CELL - 3 or x == CELL - 2: c = t[2]   # sombra abajo / derecha
            elif y == 1 or x == 1: c = t[4]                 # luz arriba / izquierda
            else: c = t[3]
            im.putpixel((x, y), c + (255,))
    return im


def buttons():
    sheet = Image.new('RGBA', (CELL * len(ORDER), CELL * 2), (0, 0, 0, 0))
    for i, name in enumerate(ORDER):
        p = [muted(c) for c in PAL[name]]
        sheet.paste(button_cell(p, False), (i * CELL, 0))
        sheet.paste(button_cell(p, True), (i * CELL, CELL))
    sheet.save(os.path.join(DIR, 'button.png'))
    with open(os.path.join(DIR, 'button.json'), 'w') as f:
        json.dump({'cell': CELL, 'cut': CUT, 'colors': ORDER,
                   'text': {n: {'shadow': muted(PAL[n][0]), 'shadow_sel': muted(PAL[n][1])} for n in ORDER}}, f, indent=1)
    print('button.png: %d colores' % len(ORDER))


# ── Panel (9-slice) ─────────────────────────────────────────────────────────
def panel():
    im = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
    edge, light, fill = (14, 18, 40, 255), (120, 170, 255, 255), (22, 30, 64, 214)
    for y in range(CELL):
        for x in range(CELL):
            if x in (0, CELL - 1) or y in (0, CELL - 1): c = edge
            elif x in (1, CELL - 2) or y in (1, CELL - 2): c = light
            else: c = fill
            im.putpixel((x, y), c)
    im.save(os.path.join(DIR, 'panel.png'))
    print('panel.png')


# ── Cartuchos de las PARTIDAS (src/states/story/StorySlotState.lua) ───────────
# cartridge.png: una columna por color de carcasa (rojo, azul, verde, gris = vacía), fila 1 normal y fila 2
# elegido (más claro). 60 x 72 a 1x: estrías de agarre arriba, la ETIQUETA (crema, con la ventanita de la isla
# arriba: ahí van los cart_labels) y los contactos dorados abajo.
# cart_labels.png: las ventanitas, 46 x 26 a 1x, una por mundo (en el orden de src/story/Worlds.lua) + la de la
# partida nueva. El .json dice las medidas y dónde va cada cosa (en px del cartucho a 1x).
CW, CH = 60, 72
LABEL = (5, 13, 50, 50)       # x, y, w, h de la etiqueta
WIN = (7, 15, 46, 26)          # la ventanita de la isla
SHELLS = {'red': (176, 58, 58), 'blue': (58, 92, 176), 'green': (58, 140, 82), 'grey': (96, 98, 110)}
SHELL_ORDER = ['red', 'blue', 'green', 'grey']


def shade(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c)


def cartridge_cell(base, sel):
    base = muted(base)
    if sel: base = lighter(base, 0.12)
    out, dark, mid, hi = shade(base, 0.35), shade(base, 0.7), base, lighter(base, 0.35)
    im = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    px = im.putpixel
    for y in range(CH):
        for x in range(CW):
            # (las esquinas de arriba, cortadas en diagonal: la forma del cartucho)
            if (x + y < 3) or ((CW - 1 - x) + y < 3): continue
            edge = x in (0, CW - 1) or y in (0, CH - 1) or x + y == 3 or (CW - 1 - x) + y == 3
            if edge: c = out
            elif y == 1 or x == 1: c = hi
            elif x == CW - 2 or y == CH - 2: c = dark
            else: c = mid
            px((x, y), c + (255,))
    # estrías de agarre (arriba)
    for y in (4, 6, 8, 10):
        for x in range(8, CW - 8):
            px((x, y), dark + (255,))
            px((x, y + 1 if y + 1 < 12 else y), hi + (255,)) if False else None
    # la etiqueta: crema con borde oscuro y sombra
    lx, ly, lw, lh = LABEL
    cream, cream_sh, ink = (240, 234, 216), (214, 206, 186), (40, 36, 48)
    for y in range(ly, ly + lh):
        for x in range(lx, lx + lw):
            if x in (lx, lx + lw - 1) or y in (ly, ly + lh - 1): c = shade(base, 0.45)
            elif x == lx + lw - 2 or y == ly + lh - 2: c = cream_sh
            else: c = cream
            px((x, y), c + (255,))
    # el hueco de la ventanita (se tapa con la isla)
    wx, wy, ww, wh = WIN
    for y in range(wy - 1, wy + wh + 1):
        for x in range(wx - 1, wx + ww + 1):
            if x in (wx - 1, wx + ww) or y in (wy - 1, wy + wh): px((x, y), ink + (255,))
    # los contactos dorados (abajo)
    for i in range(7):
        x0 = 9 + i * 6
        for y in range(CH - 6, CH - 2):
            for x in range(x0, x0 + 3):
                px((x, y), ((236, 190, 70) if y < CH - 4 else (176, 132, 40)) + (255,))
    return im


def mini_scene(kind):
    w, h = WIN[2], WIN[3]
    im = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    P = im.putpixel
    def sky(top, bot):
        for y in range(h):
            k = y / (h - 1)
            c = tuple(int(top[i] + (bot[i] - top[i]) * k) for i in range(3))
            # (a franjas de 3 px, como los cielos del juego)
            c = tuple(int(top[i] + (bot[i] - top[i]) * (3 * (y // 3)) / (h - 1)) for i in range(3))
            for x in range(w): P((x, y), c + (255,))
    def ground(fn, col, col2=None):
        for x in range(w):
            top = fn(x)
            for y in range(max(0, top), h):
                P((x, y), ((col2 if (col2 and y == top) else col)) + (255,))
    def disc(cx, cy, r, col):
        for y in range(h):
            for x in range(w):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r: P((x, y), col + (255,))
    import math
    if kind == 'pradera':
        sky((92, 164, 236), (176, 222, 255)); disc(37, 6, 3, (255, 236, 120))
        ground(lambda x: 15 + int(3 * math.sin(x / 6)), (72, 150, 70), (120, 200, 90))
        ground(lambda x: 20 + int(2 * math.sin(x / 4 + 1)), (52, 120, 56), (88, 170, 72))
    elif kind == 'costa':
        sky((96, 176, 240), (190, 230, 255)); disc(9, 6, 3, (255, 240, 140))
        ground(lambda x: 16, (44, 112, 184), (150, 210, 250))
        ground(lambda x: 21 - (1 if 14 < x < 32 else 0), (226, 200, 130), (246, 226, 160))
        for y in range(9, 17): P((30, y), (110, 72, 40, 255))
        for x in range(26, 35): P((x, 9 - abs(x - 30) // 3), (60, 150, 70, 255))
    elif kind == 'fortaleza':
        sky((70, 50, 96), (238, 140, 96)); disc(36, 14, 4, (255, 190, 110))
        ground(lambda x: 18 if (x // 5) % 2 else 16, (70, 66, 82), (110, 104, 122))
        for y in range(6, 18):
            for x in range(17, 27): P((x, y), ((90, 84, 104) if x not in (17, 26) else (60, 56, 72)) + (255,))
        for x in range(17, 27, 3): P((x, 5), (90, 84, 104, 255))
    elif kind == 'nieve':
        sky((120, 170, 230), (210, 230, 250))
        ground(lambda x: 4 + abs(x - 14) // 1 if x < 28 else 6 + abs(x - 36), (150, 160, 190), (255, 255, 255))
        ground(lambda x: 21, (230, 238, 250), (255, 255, 255))
    elif kind == 'cuevas':
        sky((20, 22, 40), (40, 40, 70))
        ground(lambda x: 20 + (x % 7 == 0), (60, 56, 80), (90, 84, 116))
        for x in range(w):
            for y in range(0, 3 + (x * 7 % 5)): P((x, y), (50, 46, 70, 255))
        for (cx, cy) in ((10, 16), (24, 15), (36, 17)):
            for d in range(4): P((cx, cy - d), (140, 220, 255, 255)); P((cx + 1, cy - d + 1), (90, 160, 230, 255))
    elif kind == 'final':
        sky((60, 20, 30), (200, 70, 40))
        ground(lambda x: 7 + abs(x - 23) if abs(x - 23) < 14 else 21, (70, 40, 40), (110, 60, 50))
        for y in range(4, 9): P((23, y), (255, 140, 40, 255)); P((22, y + 1), (255, 200, 80, 255))
        ground(lambda x: 23, (240, 110, 40), (255, 200, 90))
    else:   # nueva partida: oscuro, con un + que se dibuja en el juego
        sky((34, 38, 60), (56, 62, 92))
    return im


def cartridges():
    sheet = Image.new('RGBA', (CW * len(SHELL_ORDER), CH * 2), (0, 0, 0, 0))
    for i, n in enumerate(SHELL_ORDER):
        sheet.paste(cartridge_cell(SHELLS[n], False), (i * CW, 0))
        sheet.paste(cartridge_cell(SHELLS[n], True), (i * CW, CH))
    sheet.save(os.path.join(DIR, 'cartridge.png'))
    kinds = ['pradera', 'costa', 'fortaleza', 'nieve', 'cuevas', 'final', 'new']
    labels = Image.new('RGBA', (WIN[2] * len(kinds), WIN[3]), (0, 0, 0, 0))
    for i, k in enumerate(kinds): labels.paste(mini_scene(k), (i * WIN[2], 0))
    labels.save(os.path.join(DIR, 'cart_labels.png'))
    with open(os.path.join(DIR, 'cartridge.json'), 'w') as f:
        json.dump({'w': CW, 'h': CH, 'shells': SHELL_ORDER, 'label': LABEL, 'window': WIN, 'scenes': kinds}, f, indent=1)
    print('cartridge.png: %d carcasas; cart_labels.png: %d ventanitas' % (len(SHELL_ORDER), len(kinds)))


if __name__ == '__main__':
    logo()
    buttons()
    panel()
    cartridges()
