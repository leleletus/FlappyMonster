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
#   OJO: el usuario RETOCÓ A MANO la hoja (2026-10-26, docs/art/generators.md): --apply pisaría sus cambios.
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
# (0.5.31: más GORDITO — el usuario — y la aleta pectoral se mueve con la cola: `fin` -1 arriba, 1 abajo, 0 quieta)
# (0.5.33: desinflado es un pez NORMAL — el usuario —: cuerpo alargado y bajo que se estrecha hacia la cola (`taper`);
# solo al inflarse se pone redondo. Más abajo (cy 9.4): la barriga, donde estaba — el jefe varado sigue en el suelo)
FRAMES = [dict(rx=5.6, ry=3.1, cx=8.6, cy=9.4, tail=-1, spikes=0, fin=-1, taper=0.3),   # nadar 1 (cola y aleta arriba)
          dict(rx=5.6, ry=3.1, cx=8.6, cy=9.4, tail=1, spikes=0, fin=1, taper=0.3),     # nadar 2 (cola y aleta abajo)
          dict(rx=5.2, ry=4.6, cx=8.6, cy=8.0, tail=0, spikes=1, fin=0),                # medio inflado
          dict(rx=4.7, ry=4.7, cx=8.6, cy=8.0, tail=0, spikes=2, fin=0)]                # inflado (sitio para las púas)
EYE = '#140c06'                                                                # el ojo: un solo color, negro


def frame(D, F):
    W = 16
    px = [[None] * W for _ in range(W)]
    C = {k: hx(D[k]) for k in ('light', 'mid', 'shade', 'outline', 'belly', 'bellyS', 'spot', 'fin', 'finS', 'spike')}
    cx, cy, rx, ry = F['cx'], F['cy'], F['rx'], F['ry']
    tp = F.get('taper', 0.0)
    body = set()
    for y in range(W):
        for x in range(W):
            nx = (x + 0.5 - cx) / rx
            ny = (y + 0.5 - cy) / (ry * (1 - tp * max(0.0, -nx)))       # (más estrecho hacia la cola)
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
    # aleta lateral (pectoral), en el centro, un poco hacia atrás: la base pegada al cuerpo y la punta, que sube o
    # baja al nadar (con la cola)
    fx, fy = int(round(cx - 1.0)), int(round(cy + 0.6))
    fn = F['fin']
    pts = [((fx, fy), 'fin'), ((fx - 1, fy), 'fin')]
    pts += [((fx - 2, fy), 'fin'), ((fx - 3, fy), 'finS')] if fn == 0 else \
           [((fx - 2, fy + fn), 'fin'), ((fx - 3, fy + fn), 'finS'), ((fx - 3, fy + 2 * fn), 'finS')]
    for (x, y), c in pts:
        if (x, y) in body: px[y][x] = C[c]
    # ojo: 2x2 de un solo color (negro, sin blanco) y boca
    ex, ey = int(round(cx + rx * 0.45)), int(round(cy - ry * 0.35))
    for (x, y) in ((ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)):
        if (x, y) in body: px[y][x] = hx(EYE)
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
    # púas (0.5.33: rehechas, las de antes se veían sucias): rectas en las 8 direcciones (horizontal, vertical y
    # diagonal a 45°, sin escalones raros), menos las de atrás (la cola). Salen del contorno: la base del color de la
    # púa en sombra y la punta clara; medio inflado, solo la punta (1 px), inflado, 2 px
    L = F['spikes']
    if L:
        for dx, dy in ((0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, -1), (-1, 1)):
            # el último píxel del contorno en esa dirección, desde el centro del cuerpo
            x, y = int(math.floor(cx)), int(math.floor(cy))
            while 0 <= x + dx < W and 0 <= y + dy < W and px[y + dy][x + dx] is not None:
                x, y = x + dx, y + dy
            if dx and dy and px[y + dy][x] is None and px[y][x + dx] is None:
                px[y + dy][x] = C['outline']                   # (en diagonal, que no quede suelta: un píxel de unión)
            n = L                                              # (si no cabe entera en el cuadro, más corta: con punta)
            while n and not (1 <= x + dx * n < W - 1 and 1 <= y + dy * n < W - 1): n -= 1
            for k in range(1, n + 1):
                qx, qy = x + dx * k, y + dy * k
                if px[qy][qx] is None: px[qy][qx] = C['spike'] if k == n else C['outline']
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
