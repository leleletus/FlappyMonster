#!/usr/bin/env python3
# tools/art/ui/make_menu_ui.py — el arte de los MENÚS (src/ui/menu/, docs/architecture/menus.md), en pixel art a 1x:
#   assets/images/ui/menus/title_logo.png + .json   el logo del título EN COLOR, letra a letra. Sale del logo de
#        siempre (assets/images/ui/menus/logo.png, que NO se toca: lo usa también el final de la historia): se
#        guardan TODOS los píxeles de cada letra y solo se añade el estilo de la casa (cada letra de un color, luz
#        arriba, sombra abajo, contorno oscuro de su propio color). Sin el recuadro: las letras flotan sobre el
#        fondo vivo. El .json dice dónde está cada letra en la hoja y dónde va en el logo (para que salgan una a una).
#   assets/images/ui/menus/button.png + .json       los BOTONES (9-slice): una columna por color, fila 1 normal y
#        fila 2 seleccionado (más claro y con borde blanco). El .json: tamaño de celda, cortes y nombres de color.
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
ORDER = ['green', 'orange', 'blue', 'pink', 'purple', 'yellow', 'red', 'teal', 'grey']


def lighter(c, k):
    return tuple(int(round(v + (255 - v) * k)) for v in c)


# ── Logo ────────────────────────────────────────────────────────────────────
LOGO_COLORS = ['red', 'orange', 'yellow', 'green', 'teal', 'blue',               # FLAPPY
               'purple', 'pink', 'red', 'orange', 'yellow', 'green', 'teal']    # MONSTER


def logo():
    src = Image.open(os.path.join(DIR, 'logo.png')).convert('RGBA')
    W, H = src.size
    ink = [[src.getpixel((x, y))[3] > 0 and src.getpixel((x, y))[:3] == (0, 0, 0) for x in range(W)] for y in range(H)]
    # sin el recuadro: la tinta que toca el borde (y la que está unida a él) es el marco
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
    assert len(letters) == len(LOGO_COLORS), 'el logo tiene %d letras' % len(letters)
    # Cada píxel del logo pasa a K x K (el trazo de 1 px no deja sitio para luz, sombra y contorno: a 2x sí; el
    # juego lo dibuja a la MITAD de LOGO_SCALE, así que ocupa lo mismo que el de siempre). Debajo de cada letra,
    # EXTRUDE px de relieve (el labio, como los botones), y alrededor de todo 1 px de contorno; 1 px de margen.
    K, EXTRUDE = 2, 2
    cells, sx = [], 0
    for (x0, y0, x1, y1) in letters:
        w, h = (x1 - x0 + 1) * K + 4, (y1 - y0 + 1) * K + EXTRUDE + 4
        cells.append((sx, w, h))
        sx += w
    sheet = Image.new('RGBA', (sx, max(c[2] for c in cells)), (0, 0, 0, 0))
    meta = []
    for i, ((x0, y0, x1, y1), (cx, w, h)) in enumerate(zip(letters, cells)):
        p = PAL[LOGO_COLORS[i]]
        # la letra a K x
        def on(xx, yy):
            if xx < 0 or yy < 0: return False
            x, y = x0 + xx // K, y0 + yy // K
            return x0 <= x <= x1 and y0 <= y <= y1 and ink[y][x]
        def body(xx, yy): return any(on(xx, yy - e) for e in range(EXTRUDE + 1))
        for yy in range(h):
            for xx in range(w):
                ax, ay = xx - 2, yy - 2                          # (coordenadas dentro de la letra a K x)
                if on(ax, ay):
                    up, down = on(ax, ay - 1), on(ax, ay + 1)
                    left, right = on(ax - 1, ay), on(ax + 1, ay)
                    if not up or not left: c = p[4]                  # luz arriba / izquierda
                    elif not down or not right: c = p[2]             # sombra abajo / derecha
                    else: c = p[3]
                    sheet.putpixel((cx + xx, yy), c + (255,))
                elif body(ax, ay):
                    sheet.putpixel((cx + xx, yy), p[1] + (255,))                                    # relieve
                elif any(body(ax + dx, ay + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    sheet.putpixel((cx + xx, yy), p[0] + (255,))                                    # contorno
        # x, y = dónde va la esquina de la celda en el logo (en px del logo A K x; el logo empieza en 0, 0)
        meta.append({'sx': cx, 'sy': 0, 'w': w, 'h': h, 'x': x0 * K - 2, 'y': y0 * K - 2, 'line': 1 if y0 < bands[1][0] else 2})
    sheet.save(os.path.join(DIR, 'title_logo.png'))
    with open(os.path.join(DIR, 'title_logo.json'), 'w') as f:
        json.dump({'w': W * K, 'h': H * K, 'k': K, 'letters': meta}, f, indent=1)
    print('title_logo.png: %d letras, hoja %dx%d' % (len(meta), sheet.size[0], sheet.size[1]))


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
        sheet.paste(button_cell(PAL[name], False), (i * CELL, 0))
        sheet.paste(button_cell(PAL[name], True), (i * CELL, CELL))
    sheet.save(os.path.join(DIR, 'button.png'))
    with open(os.path.join(DIR, 'button.json'), 'w') as f:
        json.dump({'cell': CELL, 'cut': CUT, 'colors': ORDER,
                   'text': {n: {'shadow': PAL[n][0], 'shadow_sel': PAL[n][1]} for n in ORDER}}, f, indent=1)
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
