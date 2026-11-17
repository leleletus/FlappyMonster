#!/usr/bin/env python3
# tools/art/world/make_starway_orbit.py
# ESTRELLAS EN ÓRBITA (Vía Estelar, docs/design/starway-rhythm-objects.md #9): estrellas de pinchos que giran
# alrededor de un eje de cristal, un paso por pulso (src/world/entities/types/traps/orbitstars.lua).
#   star / star_b   la estrella (13x13 de arte, x4): plata con borde oscuro; la b, el brillo del pulso
#   hub / hub_lit   el eje (8x8): cristal lavanda con la lámpara dorada (encendida en el pulso), como el metrónomo
#   dot             un punto del camino de la órbita (2x2)
#   Desde la raíz del repo:  /usr/bin/python3 tools/art/world/make_starway_orbit.py [--apply]
# Sin --apply: solo la vista previa en ~/FlappyMonster_pruebas/via_estelar/orbita/vista_previa.png
import os, sys, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib'))
import animjson  # noqa: E402
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
PREV = os.path.expanduser('~/FlappyMonster_pruebas/via_estelar/orbita')
K = 4


def rgb(h): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def star(lit):
    """estrella de pinchos (15x15): 4 puntas largas y 4 cortas en diagonal, claras; el núcleo con borde oscuro"""
    n, c = 15, 7
    pal = {'o': rgb('1e1a2e'), 'd': rgb('5a5c7a'), 'm': rgb('9294b0'), 'l': rgb('c4c8da'),
           'w': rgb('eef0f8'), 'y': rgb('ff8aa8')}
    im = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    def put(x, y, col): im.putpixel((x, y), pal[col])
    core = {(x, y) for y in range(n) for x in range(n) if abs(x - c) + abs(y - c) <= 2}
    # astroide (4 puntas largas, cóncavas) + 4 puntas cortas en diagonal
    shape = {(x, y) for y in range(n) for x in range(n)
             if math.sqrt(abs(x - c)) + math.sqrt(abs(y - c)) <= 3.05
             or (abs(x - c) == abs(y - c) and abs(x - c) <= 3)}
    for (x, y) in sorted(shape):
        if not (0 <= x < n and 0 <= y < n): continue
        dx, dy = x - c, y - c
        edge = any((x + ax, y + ay) not in shape for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if (x, y) in core and edge: col = 'o'
        elif dx == 0 and dy == 0: col = 'y' if lit else 'w'
        elif dx + dy < 0: col = 'w' if lit else 'l'
        elif dx + dy == 0: col = 'l' if lit else 'm'
        else: col = 'm' if lit else 'd'
        put(x, y, col)
    # borde oscuro alrededor de TODA la figura (se lee sobre el cielo claro y el oscuro)
    out = Image.new('RGBA', (n + 2, n + 2), (0, 0, 0, 0))
    for (x, y) in shape:
        for ax in (-1, 0, 1):
            for ay in (-1, 0, 1):
                if abs(ax) + abs(ay) == 1 and (x + ax, y + ay) not in shape:
                    out.putpixel((x + ax + 1, y + ay + 1), pal['o'])
    out.alpha_composite(im, (1, 1))
    return out


def art(rows, pal):
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.': im.putpixel((x, y), pal[ch])
    return im


HUB_PAL = {'o': rgb('3a2a6a'), 'd': rgb('6a58a8'), 'm': rgb('9484cc'), 'l': rgb('c4b8ee'),
           'g': rgb('8a6a2a'), 'y': rgb('e8c050'), 'Y': rgb('fff4b0')}
HUB = [
    '..oooo..',
    '.ollmmo.',
    'olm{}mdo',
    'olm}}mdo',
    'omm}}mdo',
    'omd{}ddo',
    '.oddddo.',
    '..oooo..',
]


def hub(lit):
    return art([r.replace('{', 'Y' if lit else 'g').replace('}', 'y' if lit else 'g') for r in HUB], HUB_PAL)


def dot():
    return art(['ll', 'ld'], {'l': (196, 184, 238, 150), 'd': (106, 88, 168, 150)})


def up(im, k=K): return im.resize((im.width * k, im.height * k), Image.NEAREST)


def preview():
    os.makedirs(PREV, exist_ok=True)
    W, H = 940, 480
    out = Image.new('RGBA', (W, H), rgb('1c1a34'))
    x = 20
    for im in (star(False), star(True), hub(False), hub(True), dot()):
        out.alpha_composite(up(im), (x, 20)); out.alpha_composite(up(im, 8), (x, 100)); x += 130
    # cuatro pulsos de un compás, 2 estrellas a 2 casillas (64 px por casilla)
    for b in range(4):
        cx, cy = 120 + b * 230, 330
        for i in range(24):
            a = 2 * math.pi * i / 24
            out.alpha_composite(up(dot()), (int(cx + 128 * math.sin(a)) - 4, int(cy - 128 * math.cos(a)) - 4))
        h = up(hub(b == 0))
        out.alpha_composite(h, (cx - 16, cy - 16))
        for s in range(2):
            a = 2 * math.pi * (b / 4 + s / 2)
            st = up(star(False))
            px, py = int(cx + 128 * math.sin(a)) - 34, int(cy - 128 * math.cos(a)) - 34
            if 0 <= py < H - 52: out.alpha_composite(st, (px, py))
    out.convert('RGB').save(os.path.join(PREV, 'vista_previa.png'))
    print('vista previa:', PREV)


def apply():
    d = 'assets/images/traps/orbitstars'
    os.makedirs(os.path.join(REPO, d), exist_ok=True)
    ims = {'star': star(False), 'star_b': star(True), 'hub': hub(False), 'hub_lit': hub(True), 'dot': dot()}
    names = sorted(ims)
    for nm in names:
        ims[nm].save(os.path.join(REPO, d, nm + '.png')); print('  escrito', d + '/' + nm + '.png')
    anims = {'star': 'star', 'star_lit': 'star_b', 'idle': 'hub', 'lit': 'hub_lit', 'dot': 'dot'}
    js = {'id': 'traps/orbitstars', 'scale': 4, 'origin': [0.5, 0.5], 'fallback': 'idle',
          'frames': [{'image': d + '/' + nm + '.png', 'key': nm + '.png'} for nm in names],
          'anims': {a: {'fps': 4, 'frames': [names.index(f) + 1], 'loop': True} for a, f in anims.items()}}
    p = os.path.join(REPO, 'assets/anim/traps/orbitstars.json')
    animjson.write(p, js)
    print('  escrito', os.path.relpath(p, REPO))


if __name__ == '__main__':
    preview()
    if '--apply' in sys.argv: apply()
