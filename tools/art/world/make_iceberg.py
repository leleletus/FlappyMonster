#!/usr/bin/env python3
# EL ICEBERG (types/mechanisms/iceberg.lua) y el icono del medidor de ESCARCHA (agua helada, PlayerAir).
#   ICEBERG: un témpano que flota, de `width` × `height` casillas (16 px de arte por casilla, ×4 en el juego). Facetas
#   PLANAS como el hielo del fondo de la Costa Helada (tools/art/world/make_frozen_coast_decor.py): cara clara a la
#   izquierda, media en medio, oscura a la derecha, la parte de abajo un tono más oscura, cara de arriba LISA (se pisa)
#   con una fila de brillo, esquinas de abajo cortadas. Pocos colores, sin motas (docs/art/style-rules.md, el usuario:
#   sencillo y original). Dos variantes por tamaño (el juego alterna según la casilla).
#   ICONO: un copo 8x8 (se dibuja ×2 a la izquierda del medidor).
#   python3 tools/art/world/make_iceberg.py           → vista previa en FlappyMonster_pruebas/mecanicas_heladas/iceberg/vista_previa.png
#   python3 tools/art/world/make_iceberg.py --apply   → assets/images/mechanisms/iceberg/h<alto>-w<ancho>-<1|2>.png
#                                                       + assets/images/ui/icons/frost.png
import os, sys, random
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'mecanicas_heladas', 'iceberg')
OUT = os.path.join(ROOT, 'assets', 'images', 'mechanisms', 'iceberg')
OUT_ICON = os.path.join(ROOT, 'assets', 'images', 'ui', 'icons', 'frost.png')
MAX_W, MAX_H = 8, 3          # (Iceberg.MAX_W / MAX_H)


def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# (los del iceberg del fondo: make_frozen_coast_decor.py, A)
O, D, M, L, TOP = rgb('2c5a86'), rgb('5c92ba'), rgb('9cc6e0'), rgb('e6f4fa'), rgb('f8fcff')
DARKER = {L: M, M: D, D: D}


def side(x0, y0, x1, y1, x, y):
    """>0 a la derecha de la recta (x0,y0)→(x1,y1) (con y hacia abajo)"""
    return (x1 - x0) * (y - y0) - (y1 - y0) * (x - x0)


def berg(w, h, v):
    W, H = 16 * w, 16 * h
    rnd = random.Random(w * 101 + h * 13 + v * 7)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    # silueta: el rectángulo con las esquinas de abajo cortadas y el canto de abajo un poco irregular
    cut = min(5, max(3, H // 4))
    bottom = [H - 1] * W
    x = cut + rnd.randint(1, 4)
    while x < W - cut - 2:
        n = rnd.randint(3, 7)
        lift = rnd.choice((0, 1, 1, 2))
        for i in range(x, min(W - cut, x + n)): bottom[i] = H - 1 - lift
        x += n + rnd.randint(2, 6)

    def inside(x, y):
        if y > bottom[x]: return False
        if y > H - 1 - cut + x: return False                 # (esquina de abajo a la izquierda)
        if y > H - 1 - cut + (W - 1 - x): return False       # (… y a la derecha)
        return True

    # facetas: rectas inclinadas de arriba abajo; clara a la izquierda, oscura a la derecha, en medio media / clara
    n = 2 + w // 2 + (1 if (v == 2 and w > 1) else 0)
    cuts = []
    for i in range(1, n):
        xt = W * i / n + rnd.uniform(-3, 3)
        xb = xt + rnd.choice((-1, 1)) * rnd.uniform(5, 9) * min(1.5, 0.6 + 0.4 * h)
        cuts.append((xt, xb))
    cols = [L] + [(M if i % 2 == 1 else L) for i in range(1, n - 1)] + [D]
    if n == 2: cols = [L, D] if w == 1 else [L, M]
    # la parte de abajo, un tono más oscura: una recta un poco inclinada a media altura (más abajo cuanto más alto)
    ya, yb = H * 0.58 + rnd.uniform(-2, 2), H * 0.58 + rnd.uniform(-2, 3) + (2 if v == 2 else -2)
    for y in range(H):
        for x in range(W):
            if not inside(x, y): continue
            k = 0
            for (xt, xb) in cuts:
                if side(xt, 0, xb, H, x + 0.5, y + 0.5) < 0: k += 1
            c = cols[min(k, len(cols) - 1)]
            if side(0, ya, W, yb, x + 0.5, y + 0.5) < 0: c = DARKER[c]
            im.putpixel((x, y), c)
    # contorno: el tono más oscuro de su color en todo lo que toca el exterior
    px = im.load()
    edge = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0: continue
            for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < W and 0 <= ny < H) or px[nx, ny][3] == 0:
                    edge.append((x, y)); break
    for (x, y) in edge: px[x, y] = O
    # la cara de arriba (lisa: se pisa), vista un poco desde arriba: una fila de brillo y dos claras bajo el contorno
    for x in range(1, W - 1):
        for y, c in ((1, TOP), (2, L), (3, L)):
            if px[x, y][3] and px[x, y] != O: px[x, y] = c
        if px[x, 4][3] and px[x, 4] != O: px[x, 4] = O if x % 7 != 3 else px[x, 4]    # (el canto: casi seguido)
    return im


def frost_icon():
    im = Image.new('RGBA', (8, 8), (0, 0, 0, 0))
    W, B = TOP, rgb('9cc6e0')
    for i in range(1, 7):
        im.putpixel((3, i), W); im.putpixel((i, 3), W) if i != 3 else None
    for (x, y) in ((1, 1), (2, 2), (4, 4), (5, 5), (5, 1), (4, 2), (2, 4), (1, 5)): im.putpixel((x, y), B)
    im.putpixel((3, 3), B)
    # contorno oscuro alrededor (se lee sobre cualquier fondo)
    px = im.load()
    out = []
    for y in range(8):
        for x in range(8):
            if px[x, y][3]: continue
            for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 8 and 0 <= ny < 8 and px[nx, ny][3] and px[nx, ny] != O:
                    out.append((x, y)); break
    for (x, y) in out: px[x, y] = O
    return im


def preview(imgs, icon):
    """Mar con témpanos de varios tamaños flotando (la línea del agua donde quedan en el juego, ×4)"""
    S = 4
    Wp, Hp = 1240, 560
    out = Image.new('RGBA', (Wp, Hp), rgb('b8d4f0'))
    water_y = 300
    tint = (107, 189, 245, 107)
    sea = Image.new('RGBA', (Wp, Hp - water_y), tint)
    x = 24
    for (w, h, v) in ((1, 1, 1), (2, 1, 2), (3, 1, 1), (4, 1, 2), (3, 2, 1), (5, 2, 2), (2, 3, 1)):
        im = imgs[(h, w, v)].resize((16 * w * S, 16 * h * S), Image.NEAREST)
        out.alpha_composite(im, (x, water_y - int(0.3 * 64)))
        x += 16 * w * S + 24
        if x > Wp - 200: break
    out.alpha_composite(sea, (0, water_y))
    # la fila de abajo: todos los anchos de una casilla de alto, variante 1 y 2
    y = 400
    x = 24
    for w in range(1, MAX_W + 1):
        for v in (1, 2):
            im = imgs[(1, w, v)].resize((16 * w * 2, 32), Image.NEAREST)
            if x + im.width > Wp - 24: x, y = 24, y + 44
            out.alpha_composite(im, (x, y)); x += im.width + 10
    ic = icon.resize((32, 32), Image.NEAREST)
    out.alpha_composite(ic, (Wp - 60, 20))
    return out


def main():
    apply = '--apply' in sys.argv
    imgs = {}
    for h in range(1, MAX_H + 1):
        for w in range(1, MAX_W + 1):
            for v in (1, 2):
                imgs[(h, w, v)] = berg(w, h, v)
    icon = frost_icon()
    if apply:
        os.makedirs(OUT, exist_ok=True)
        for (h, w, v), im in imgs.items(): im.save(os.path.join(OUT, f'h{h}-w{w}-{v}.png'))
        icon.save(OUT_ICON)
        print(f'{len(imgs)} icebergs → {OUT}\nicono → {OUT_ICON}')
    os.makedirs(PRUEBAS, exist_ok=True)
    p = os.path.join(PRUEBAS, 'vista_previa.png')
    preview(imgs, icon).save(p)
    print('vista previa →', p)


if __name__ == '__main__':
    main()
