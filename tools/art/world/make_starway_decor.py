#!/usr/bin/env python3
# tools/art/world/make_starway_decor.py
# Las DECORACIONES de la Vía Estelar (docs/design/via-estelar-level.md; el conjunto `starway_set`, categoría «Estelar»
# del editor). Arte a 1x (se dibuja x4, base abajo en el centro), estilo de la casa: contorno = el tono más oscuro del
# propio color, luz arriba-izquierda, 3-4 tonos; colores fríos y apagados (no distraen: el usuario) salvo la luz de los
# farolillos y las estrellas.
#   crystal_cluster  racimo de cristales lavanda (celda)          star_lantern   farolillo con una estrella (luz, titila)
#   telescope        telescopio en su trípode (celda)             floating_star  estrella que flota (sube y baja, brilla)
#   const_sign       letrero con una constelación (celda)         moon_flower    flor de luna (subcelda, brilla poco)
#   crystal_shard    esquirla de cristal (subcelda)               cloud_puff     nubecilla (celda, delante)
#   star_banner      banderín con una estrella (ondea, 3 cuadros)
# Escribe assets/images/world/decorations/starway/*.png y assets/anim/world/decorations/starway.json (--apply); sin él,
# la hoja en ~/FlappyMonster_pruebas/via_estelar/decoraciones/vista_previa.png.
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib'))
import animjson  # noqa: E402
import os, sys, json, math
from PIL import Image, ImageDraw

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
os.chdir(REPO)
OUT = 'assets/images/world/decorations/starway'
ANIM = 'assets/anim/world/decorations/starway.json'
PREV = os.path.expanduser('~/FlappyMonster_pruebas/via_estelar/decoraciones')


def rgb(h, a=255): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


CRY = [rgb(c) for c in ('3c3466', '5a5090', '7a70b4', '9c94d2', 'c4bee8', 'ece8fc')]
MET = [rgb(c) for c in ('2a2840', '4a4a68', '76769a', 'a8a8c8')]          # metal plateado
GLD = [rgb(c) for c in ('6a4a1a', 'b08a3a', 'e8c860', 'fff0b0')]
WOOD = [rgb(c) for c in ('2e2236', '4c3a52', '6c5874', '8c7894')]
CLD = [rgb(c) for c in ('8a86b8', 'b0acd6', 'd6d4ee', 'f4f3fc')]
FLW = [rgb(c) for c in ('3a5a6a', '5a8a94', 'bfe6ee', 'f2fdff')]


def blank(w, h): return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def shard(d, x, base, h, w, pal):
    """una esquirla: rombo alargado con la punta arriba; luz a la izquierda"""
    for yy in range(h):
        k = yy / max(1, h - 1)
        half = max(0, round(w / 2 * min(1, (k * 1.6))))
        y = base - h + yy
        for xx in range(x - half, x + half + 1):
            c = pal[3] if xx < x else (pal[2] if xx == x else pal[1])
            if xx in (x - half, x + half) or yy == 0: c = pal[0]
            d.point((xx, y), fill=c)
        if yy > 1 and half > 0: d.point((x - half + 1, y), fill=pal[4] if yy % 3 else pal[3])


def crystal_cluster():
    im = blank(22, 20); d = ImageDraw.Draw(im)
    for x, h, w in ((6, 12, 4), (15, 10, 4), (10, 18, 6), (18, 7, 3), (3, 7, 3)):
        shard(d, x, 19, h, w, CRY)
    d.line((1, 19, 20, 19), fill=CRY[0])
    return im


def crystal_shard():
    im = blank(9, 9); d = ImageDraw.Draw(im)
    shard(d, 4, 8, 8, 4, CRY); shard(d, 7, 8, 4, 2, CRY)
    return im


def star_lantern(on):
    im = blank(12, 30); d = ImageDraw.Draw(im)
    d.rectangle((5, 10, 6, 29), fill=MET[1]); d.line((5, 10, 5, 29), fill=MET[2])
    d.rectangle((3, 27, 8, 29), fill=MET[0]); d.line((3, 27, 8, 27), fill=MET[2])
    d.rectangle((2, 1, 9, 10), fill=MET[0])                  # la jaula
    d.rectangle((3, 2, 8, 9), fill=GLD[2] if on else GLD[1])
    pts = [(5, 3), (6, 3), (4, 5), (7, 5), (5, 5), (6, 5), (5, 4), (6, 4), (5, 6), (6, 6), (4, 7), (7, 7)]
    for p in pts: d.point(p, fill=GLD[3] if on else GLD[2])
    d.line((2, 0, 9, 0), fill=MET[2])
    return im


def telescope():
    im = blank(22, 22); d = ImageDraw.Draw(im)
    d.line((11, 12, 5, 21), fill=WOOD[1]); d.line((11, 12, 17, 21), fill=WOOD[1]); d.line((11, 12, 11, 21), fill=WOOD[2])
    # el tubo, inclinado hacia arriba a la derecha
    for i in range(14):
        x, y = 4 + i, 14 - i * 0.6
        for t in range(-1, 2):
            c = MET[3] if t < 0 else (MET[2] if t == 0 else MET[1])
            d.point((x, round(y + t)), fill=c)
    d.rectangle((16, 3, 19, 7), fill=MET[0]); d.rectangle((17, 4, 18, 6), fill=GLD[2])   # el objetivo
    d.point((11, 11), fill=GLD[2])
    return im


def floating_star(f):
    im = blank(11, 11); d = ImageDraw.Draw(im)
    c = 5
    arm = 4 if f == 0 else 3
    for k in range(-arm, arm + 1):
        d.point((c + k, c), fill=GLD[2]); d.point((c, c + k), fill=GLD[2])
    d.rectangle((c - 1, c - 1, c + 1, c + 1), fill=GLD[3])
    for p in ((c - arm, c), (c + arm, c), (c, c - arm), (c, c + arm)): d.point(p, fill=GLD[1])
    if f == 0:
        for p in ((c - 2, c - 2), (c + 2, c + 2), (c - 2, c + 2), (c + 2, c - 2)): d.point(p, fill=GLD[2])
    return im


def const_sign():
    im = blank(20, 24); d = ImageDraw.Draw(im)
    d.rectangle((9, 12, 10, 23), fill=WOOD[1]); d.line((9, 12, 9, 23), fill=WOOD[2])
    d.rectangle((1, 1, 18, 13), fill=WOOD[0])
    d.rectangle((2, 2, 17, 12), fill=rgb('1a1838'))
    stars = [(4, 9), (7, 5), (11, 7), (14, 3), (15, 10)]
    for a, b in zip(stars, stars[1:]): d.line((a, b), fill=rgb('5a5490'))
    for p in stars: d.point(p, fill=rgb('f0eeff'))
    d.line((1, 1, 18, 1), fill=WOOD[3])
    return im


def moon_flower():
    im = blank(9, 10); d = ImageDraw.Draw(im)
    d.line((4, 4, 4, 9), fill=FLW[1]); d.point((3, 7), fill=FLW[1]); d.point((5, 6), fill=FLW[1])
    for p in ((4, 1), (3, 2), (5, 2), (4, 3), (2, 2), (6, 2)): d.point(p, fill=FLW[2])
    d.point((4, 2), fill=FLW[3])
    return im


def cloud_puff():
    im = blank(24, 10); d = ImageDraw.Draw(im)
    for cx, cy, r in ((7, 6, 4), (13, 4, 5), (19, 6, 4)):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=CLD[2])
    for cx, cy, r in ((12, 3, 3), (7, 5, 2)):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=CLD[3])
    d.line((3, 9, 21, 9), fill=CLD[1])
    return im


def star_banner(f):
    im = blank(16, 26); d = ImageDraw.Draw(im)
    d.rectangle((1, 0, 2, 25), fill=MET[1]); d.point((1, 0), fill=GLD[2]); d.point((2, 0), fill=GLD[2])
    for y in range(2, 14):
        w = 11 + round(math.sin(y * 0.5 + f * 2.1) * 1.4)
        for x in range(3, 3 + w):
            dy = round(math.sin(x * 0.6 + f * 2.1))
            c = rgb('4a3a7a') if (x + y) % 9 else rgb('5a4a8c')
            if y + dy in (2, 13): c = rgb('2e2452')
            d.point((x, y + dy), fill=c)
    cx, cy = 9, 7 + round(math.sin(9 * 0.6 + f * 2.1))
    for k in range(-2, 3):
        d.point((cx + k, cy), fill=GLD[2]); d.point((cx, cy + k), fill=GLD[2])
    d.point((cx, cy), fill=GLD[3])
    return im


def build():
    return {
        'crystal_cluster': [crystal_cluster()], 'crystal_shard': [crystal_shard()],
        'star_lantern': [star_lantern(True), star_lantern(False)], 'telescope': [telescope()],
        'floating_star': [floating_star(0), floating_star(1)], 'const_sign': [const_sign()],
        'moon_flower': [moon_flower()], 'cloud_puff': [cloud_puff()],
        'star_banner': [star_banner(0), star_banner(1), star_banner(2)],
    }


def save(sprites):
    os.makedirs(OUT, exist_ok=True)
    frames, anims = [], {}
    durs = {'star_lantern': [0.9, 0.25], 'floating_star': [0.5, 0.5]}
    for name, ims in sprites.items():
        w, h = ims[0].size
        if len(ims) > 1:
            sheet = blank(w * len(ims), h)
            for i, im in enumerate(ims): sheet.alpha_composite(im, (i * w, 0))
            path = '%s/%s-Sheet.png' % (OUT, name)
        else:
            sheet, path = ims[0], '%s/%s.png' % (OUT, name)
        sheet.save(path)
        idx = []
        for i in range(len(ims)):
            frames.append({'image': path, 'x': i * w, 'y': 0, 'w': w, 'h': h}); idx.append(len(frames))
        a = {'fps': 6 if name == 'star_banner' else 8, 'frames': idx, 'loop': True}
        if name in durs: a['durations'] = durs[name]
        anims[name] = a
        print('  escrito', path)
    d = {'id': 'world/decorations/starway', 'scale': 4, 'origin': [0.5, 1], 'fallback': 'crystal_cluster',
         'frames': frames, 'anims': anims}
    animjson.write(ANIM, d)
    print('  escrito', ANIM)


def preview(sprites):
    os.makedirs(PREV, exist_ok=True)
    cv = Image.new('RGBA', (1240, 200), rgb('1c1a34'))
    x = 20
    for name, ims in sprites.items():
        for im in ims:
            b = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
            cv.alpha_composite(b, (x, 180 - b.height)); x += b.width + 12
    cv.save(os.path.join(PREV, 'vista_previa.png'))
    print('vista previa:', os.path.join(PREV, 'vista_previa.png'))


if __name__ == '__main__':
    sp = build()
    preview(sp)
    if '--apply' in sys.argv: save(sp)
