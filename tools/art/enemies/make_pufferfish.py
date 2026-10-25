#!/usr/bin/env python3
# tools/art/enemies/make_pufferfish.py — rediseño del PEZ GLOBO (el enemigo del agua de la costa), base del Pez Globo
# Gigante (el nuevo jefe de la costa: docs/bosses/new-bosses-plan.md).
#
# Misma hoja que la de ahora (assets/images/enemies/pufferfish/puffer_fish-Sheet.png: 4 cuadros de 16x16 mirando a la
# DERECHA — nadar 1, nadar 2, medio inflado, inflado), así que entra sin tocar el código. Estilo de la casa
# (docs/art/style-rules.md): contorno = el tono más oscuro del PROPIO color, luz arriba a la izquierda, sombra abajo a
# la derecha, 3-4 tonos, 1 px de margen. Las púas salen al inflarse (cortas a medias, largas inflado) y la cola se
# mueve entre los dos cuadros de nadar.
#
#   python tools/art/enemies/make_pufferfish.py            → FlappyMonster_pruebas/enemigos/pez_globo/vista_previa.png
#   python tools/art/enemies/make_pufferfish.py --apply A  → escribe la hoja con el diseño A (guarda el original fuera)
#
# El usuario eligió el diseño A "Arena" (2026-10-25); B y C se guardan (en el generador y como hojas sueltas junto a
# la vista previa) por si sirven luego. Sustituye a make_puffer_redesign.py (el reestilo píxel a píxel del sprite
# original: retirado a FlappyMonster_originals/herramientas_retiradas/).
import os, sys, math
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
SHEET = os.path.join(ROOT, 'assets', 'images', 'enemies', 'pufferfish', 'puffer_fish-Sheet.png')
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/enemigos/pez_globo'


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# Diseños: tonos del cuerpo (luz, medio, sombra, contorno), vientre (claro, sombra), manchas, aletas, púas, y dibujo
DESIGNS = {
    'A': dict(name='Arena', light='#f8e08e', mid='#e3b84e', shade='#b5842c', outline='#5e3b12',
              belly='#fff4d4', bellyS='#e9d3a0', spot='#8f5b20', fin='#e58b3a', finS='#a9561c', spike='#fff4d4',
              pattern='spots'),
    'B': dict(name='Arrecife', light='#9ce8f0', mid='#4fb6cc', shade='#2c7c9b', outline='#163a55',
              belly='#eefaf6', bellyS='#bfe0de', spot='#ffffff', fin='#2c7c9b', finS='#1d5674', spike='#eefaf6',
              pattern='dots'),
    'C': dict(name='Coral', light='#ffbf8f', mid='#f2875a', shade='#c5583a', outline='#5f2216',
              belly='#ffe9d6', bellyS='#f0c6a8', spot='#c5583a', fin='#ffd24a', finS='#c99a1c', spike='#ffe9d6',
              pattern='stripes'),
}

# manchas del lomo (posición relativa al cuerpo: -1..1)
SPOTS = {'spots': [(-0.5, -0.3), (-0.1, -0.65), (0.15, -0.2), (-0.75, 0.0), (0.4, -0.75)],
         'dots': [(-0.55, -0.45), (-0.2, -0.1), (0.05, -0.6), (-0.8, 0.05), (0.3, -0.3)]}

# Cuadros: radios del cuerpo (x, y), centro, cola (desplazamiento vertical de la punta), largo de las púas
FRAMES = [dict(rx=5.2, ry=3.6, cx=8.6, cy=8.0, tail=-1, spikes=0),     # nadar 1 (cola arriba)
          dict(rx=5.2, ry=3.6, cx=8.6, cy=8.0, tail=1, spikes=0),      # nadar 2 (cola abajo)
          dict(rx=5.2, ry=4.4, cx=8.6, cy=8.0, tail=0, spikes=1),      # medio inflado
          dict(rx=4.9, ry=4.9, cx=8.6, cy=8.0, tail=0, spikes=2)]      # inflado (más pequeño: sitio para las púas)


def frame(D, F):
    W = 16
    px = [[None] * W for _ in range(W)]
    C = {k: hx(D[k]) for k in ('light', 'mid', 'shade', 'outline', 'belly', 'bellyS', 'spot', 'fin', 'finS', 'spike')}
    cx, cy, rx, ry = F['cx'], F['cy'], F['rx'], F['ry']
    body = set()
    for y in range(W):
        for x in range(W):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if nx * nx + ny * ny <= 1.0: body.add((x, y))
    # cola: un abanico ahorquillado a la izquierda del cuerpo, que sube o baja al nadar
    left = min(x for x, y in body)
    tail = set()
    t = F['tail']
    FAN = {1: (0,), 2: (-1, 0, 1), 3: (-2, -1, 1, 2)}           # (la horquilla: el centro de atrás, vacío)
    for dx, rows in FAN.items():
        x = left - dx + 1
        for dy in rows:
            y = int(round(cy - 0.5)) + dy + (t if dx >= 2 else 0)
            if 0 <= x < W and 0 <= y < W and (x, y) not in body: tail.add((x, y))
    # cuerpo con luces: arriba-izquierda claro, abajo-derecha sombra; vientre más claro abajo
    for (x, y) in body:
        nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        v = -(0.55 * nx + 0.85 * ny)
        belly = ny > 0.3
        if belly:
            px[y][x] = C['bellyS'] if (nx > 0.35 or ny > 0.8) else C['belly']
        else:
            px[y][x] = C['light'] if v > 0.55 else (C['shade'] if v < -0.25 else C['mid'])
    # dibujo del lomo (manchas / puntos / rayas), solo arriba del vientre
    for (x, y) in body:
        nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        if ny > 0.25: continue
        p = D['pattern']
        if p in ('spots', 'dots'):
            for sx_, sy_ in SPOTS[p]:                          # (manchas sueltas, en sitios fijos del lomo)
                if (x, y) == (int(round(cx + sx_ * rx - 0.5)), int(round(cy + sy_ * ry - 0.5))): px[y][x] = C['spot']
        if p == 'stripes' and int(round(x - cx)) in (-3, 0) and ny < 0.15 and ny > -0.95: px[y][x] = C['spot']
    for (x, y) in tail:
        if (x, y) not in body: px[y][x] = C['fin'] if y <= cy else C['finS']
    # aleta lateral (pectoral), en el centro, un poco hacia atrás
    fx, fy = int(round(cx - 1.5)), int(round(cy + 0.5))
    for (x, y) in ((fx, fy), (fx - 1, fy), (fx - 1, fy + 1)):
        if (x, y) in body: px[y][x] = C['finS']
    # ojo (blanco 2x2 con pupila delante) y boca
    ex, ey = int(round(cx + rx * 0.45)), int(round(cy - ry * 0.35))
    for (x, y) in ((ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)):
        if (x, y) in body: px[y][x] = (255, 255, 255, 255)
    if (ex + 1, ey + 1) in body: px[ey + 1][ex + 1] = C['outline']
    if (ex + 1, ey) in body: px[ey][ex + 1] = C['outline']
    mx, my = max(x for x, y in body if y == int(round(cy + 0.5))), int(round(cy + 0.5))
    px[my][mx] = C['outline']
    # contorno: todo lo vacío que toca el cuerpo o la cola (sin diagonales)
    filled = {(x, y) for y in range(W) for x in range(W) if px[y][x] is not None}
    for (x, y) in list(filled):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if 0 <= q[0] < W and 0 <= q[1] < W and q not in filled and px[q[1]][q[0]] is None:
                px[q[1]][q[0]] = 'O'
    for y in range(W):
        for x in range(W):
            if px[y][x] == 'O': px[y][x] = C['outline']
    # púas: rayos desde el contorno hacia fuera (las de atrás no: la cola)
    L = F['spikes']
    if L:
        for k in range(12):
            a = -math.pi / 2 + k * (2 * math.pi / 12)
            if math.cos(a) < -0.6: continue                    # (por la cola no)
            # una línea continua desde el contorno hacia fuera (a medios píxeles: sin huecos en diagonal); la punta,
            # del color de la púa
            pts = []
            d = 0.0
            while d <= L + 0.6:
                x = int(math.floor(cx + math.cos(a) * (rx + 0.5 + d)))
                y = int(math.floor(cy + math.sin(a) * (ry + 0.5 + d)))
                if (x, y) not in pts: pts.append((x, y))
                d += 0.5
            pts = [q for q in pts if q not in body]
            for j, (x, y) in enumerate(pts):
                if 1 <= x < W - 1 and 1 <= y < W - 1 and (px[y][x] is None or px[y][x] == C['outline']):
                    px[y][x] = C['spike'] if j == len(pts) - 1 else C['outline']
    im = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    for y in range(W):
        for x in range(W):
            if px[y][x] is not None and x in range(1, W - 1) and y in range(1, W - 1):
                im.putpixel((x, y), px[y][x])
    return im


def sheet(key):
    D = DESIGNS[key]
    out = Image.new('RGBA', (64, 16), (0, 0, 0, 0))
    for i, F in enumerate(FRAMES): out.paste(frame(D, F), (16 * i, 0))
    return out


def preview():
    os.makedirs(PREVIEW, exist_ok=True)
    big, small = 10, 5                                         # (de cerca, y a la escala del juego)
    keys = ['ACTUAL'] + list(DESIGNS)
    row_h = 16 * big + 40
    im = Image.new('RGBA', (16 * big * 4 + 60 * 4 + 16 * small * 4 + 140, row_h * len(keys) + 10), hx('#1f4e6e'))
    dr = ImageDraw.Draw(im)
    cur = Image.open(SHEET).convert('RGBA')
    for r, k in enumerate(keys):
        sh = cur if k == 'ACTUAL' else sheet(k)
        y0 = 10 + r * row_h
        dr.text((10, y0), k if k == 'ACTUAL' else f'{k} - {DESIGNS[k]["name"]}', fill=(255, 255, 255, 255))
        for i in range(4):
            f = sh.crop((16 * i, 0, 16 * i + 16, 16)).resize((16 * big, 16 * big), Image.NEAREST)
            im.alpha_composite(f, (10 + i * (16 * big + 60), y0 + 20))
        x1 = 10 + 4 * (16 * big + 60) + 20
        for i in range(4):
            f = sh.crop((16 * i, 0, 16 * i + 16, 16)).resize((16 * small, 16 * small), Image.NEAREST)
            im.alpha_composite(f, (x1 + i * (16 * small + 8), y0 + 20 + (16 * big - 16 * small) // 2))
    p = os.path.join(PREVIEW, 'vista_previa.png')
    im.save(p)
    print(p)


def apply(key):
    sys.path.insert(0, os.path.join(HERE, '..', 'lib'))
    import originals
    o, new = originals.keep(SHEET)                             # (el original, fuera del repo, una sola vez)
    print('original:', o, '(guardado ahora)' if new else '(ya estaba)')
    sheet(key).save(SHEET)
    print('escrito', SHEET, 'con el diseño', key)
    os.makedirs(PREVIEW, exist_ok=True)                        # (los demás diseños, listos por si sirven luego)
    for k in DESIGNS:
        if k != key:
            sheet(k).save(os.path.join(PREVIEW, f'puffer_fish-Sheet_{k}_{DESIGNS[k]["name"]}.png'))


if __name__ == '__main__':
    if '--apply' in sys.argv:
        apply(sys.argv[sys.argv.index('--apply') + 1])
    else:
        preview()
