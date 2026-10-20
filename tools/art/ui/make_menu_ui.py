#!/usr/bin/env python3
# tools/art/ui/make_menu_ui.py — el arte de los MENÚS (src/ui/menu/, docs/architecture/menus.md), en pixel art a 1x:
#   assets/images/ui/menus/title_logo.png + .json   el logo del título REMASTERIZADO: el recuadro blanco y cada
#        letra por separado. Sale del logo de siempre (assets/images/ui/menus/logo.png, que NO se toca: lo usa
#        también el final de la historia): se guardan todos sus píxeles y solo se añade el estilo de la casa. El
#        .json dice dónde está el recuadro y cada letra en la hoja y dónde va cada letra (para que salgan una a una).
#   assets/images/ui/menus/button.png + .json       los BOTONES (9-slice): una columna por color, fila 1 normal y
#        fila 2 seleccionado (más claro y con borde blanco), en tonos
#        apagados (MUTE). El .json: tamaño de celda, cortes y nombres de color.
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


if __name__ == '__main__':
    logo()
    buttons()
    panel()
