#!/usr/bin/env python3
# tools/ui/make_gloomy_sprites.py — PROPUESTAS del CRABBY LÚGUBRE ("Gloomy Crabby") y de su jefe,
# el Mega Crabby lúgubre, basados en Cancrocaeca xenomorpha (cangrejo de cueva): cuerpo pequeño
# y redondo, SIN ojos, casi sin pigmento, patas larguísimas y pinzas pequeñas.
#
# Cada opción es una dirección distinta (proporciones, largo de patas, pinzas, silueta, puntos
# luminosos y forma de entender su palidez). El cuerpo está dibujado a mano (mapa de caracteres)
# y las PATAS se trazan por código, pixel a pixel, entre cadera – rodilla – pie: así el ciclo de
# andar y las demás poses salen de las mismas patas (y son finas, de 1 px, como las del Crabby).
#
# MISMA RESOLUCIÓN para el pequeño y el Mega: el Mega es EL MISMO sprite dibujado a escala 10
# (el pequeño, a 4, como los Crabbies), con retoques de 1 píxel (púas, otro par de puntos). Un
# cuerpo nuevo con más resolución no pega con el juego (ya se rechazó dos veces).
#
#   python3 tools/ui/make_gloomy_sprites.py          → vista previa en FlappyMonster_pruebas/gloomy/
#       opciones.png        las 4 opciones: cuadros ampliados (andar ×4, quieto, agachado, salto,
#                           susto, aplastado), a la luz y a oscuras (solo los puntos)
#       maqueta_<X>.png     cada opción en una cueva a oscuras con la linterna del jugador
#       maqueta_mega.png    el Mega de cada opción, a escala de juego, en su arena a oscuras
#       andar_<X>.gif       ciclo de andar
#   python3 tools/ui/make_gloomy_sprites.py --apply  → escribe los assets de la opción elegida por el
#       usuario: B "Fantasma" (ojos algo separados) y su Mega CON retoques (MEGA_B):
#       assets/images/gloomy/gloomy-Sheet.png (9 cuadros 26x15: andar 1-4, quieto, agachado, salto,
#       susto, aplastado) + glow-Sheet.png (sus puntos luminosos), bosses/megagloomy/body-Sheet.png
#       (9 cuadros 38x21, la MISMA rejilla de píxel) + glow-Sheet.png, ui/flashlight-Sheet.png
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

try:
    FONT = ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans.ttf', 13)
except Exception:
    FONT = None

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
IMG = os.path.join(ROOT, 'assets', 'images')
OUT = os.environ.get('FM_PREVIEWS', '/home/mtvemo/FlappyMonster_pruebas') + '/gloomy'

W, H = 26, 15                 # lienzo de cada cuadro (px de arte); los pies, en la fila de abajo
CX = W // 2
SMALL, MEGA = 4, 10           # escalas de juego (Crabby / Mega)


def rgb(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


# ── Las opciones ─────────────────────────────────────────────────────────────
# body: filas (o contorno, h brillo, w claro, s sombra, t tinte de dentro, c pinza, g punta luminosa)
# top: alto del cuerpo sobre el suelo (px de arte) = lo largas que se ven las patas
# legs: patas del lado IZQUIERDO (el derecho es su espejo): cadera (dx desde el borde del cuerpo,
#       dy desde arriba del cuerpo), rodilla (dx, dy desde el suelo hacia arriba), pie (dx)
# glow: puntos luminosos (dx desde el centro, dy desde arriba del cuerpo) y su color
OPTIONS = {
    'A': dict(
        name='Zancudo', note='araña de cueva: cuerpo mínimo, patas en arco muy altas, pinzas alzadas; puntos cian',
        pal=dict(o='#1e1e2a', h='#ffffff', w='#eef0f6', s='#c2c7d8', c='#eef0f6', l='#dfe3ee', j='#aab0c6'),
        body=['c.....c',
              'oc...co',
              '.ooooo.',
              'ohwwwso',
              'owwwwso',
              'owwssso',
              '.ooooo.'],
        top=5,
        legs=[(0, 3, -4, 10, -5), (0, 4, -7, 10, -8), (1, 5, -9, 7, -11)],
        glow=[(-1, 3), (1, 3)], glow_col='#7ff2ff',
        mega_extra=[(-2, 2, 'o'), (0, 1, 'o'), (2, 2, 'o')], mega_glow=[(-1, 3), (1, 3), (-2, 5), (2, 5)],
    ),
    'B': dict(
        name='Fantasma', note='translúcido azulado, se le ve lo de dentro; pinzas curvas hacia dentro; puntos ámbar',
        pal=dict(o='#46557a', h='#f6fbff', w='#d6e6f7', s='#9fb6d8', t='#f0b070', c='#e6f0fb', l='#b9cde6', j='#7f96bc'),
        body=['.cc...cc.',
              'c.......c',
              'c..ooo..c',
              '.oohwwoo.',
              'owwtttwso',
              'owwwtwsso',
              '.ooooooo.'],
        top=4,
        legs=[(0, 4, -4, 7, -6), (0, 5, -7, 7, -9), (1, 6, -9, 4, -12)],
        glow=[(-2, 4), (2, 4)], glow_col='#ffc45a',          # (algo separados, simétricos: los pidió el usuario)
        mega_extra=[], mega_glow=[(-2, 4), (2, 4)],
    ),
    'C': dict(
        name='Farolero', note='bola sobre zancos casi rectos (muy alto); las PUNTAS de las pinzas son la luz; crema',
        pal=dict(o='#1e1e2a', h='#fffaf0', w='#f3e9dc', s='#cbb9a6', c='#f3e9dc', g='#f3e9dc', l='#e4d8c8', j='#b3a08c'),
        body=['g.....g',
              'c.....c',
              'oc...co',
              '.ooooo.',
              'ohwwwso',
              'owwwwso',
              'owwwsso',
              '.ooooo.'],
        top=7,
        legs=[(0, 4, -3, 9, -4), (0, 5, -5, 10, -6), (1, 7, -7, 8, -9)],
        glow=[(-3, 0), (3, 0)], glow_col='#c8ff7a',
        mega_extra=[(-1, 3, 'o'), (1, 3, 'o')], mega_glow=[(-3, 0), (3, 0), (0, 5)],
    ),
    'D': dict(
        name='Rastrero', note='ancho y pegado al suelo, patas abiertas de lado como un opilión; puntos violeta',
        pal=dict(o='#1e1e2a', h='#ffffff', w='#e8e2f0', s='#bdb3cf', c='#e8e2f0', l='#d8d0e4', j='#a094b8'),
        body=['.c.......c.',
              '..ooooooo..',
              '.ohwwwwwso.',
              'cwwwwwwsssc',
              '.ooooooooo.'],
        top=1,
        legs=[(1, 2, -3, 5, -5), (0, 3, -6, 5, -8), (0, 4, -8, 3, -12)],
        glow=[(-2, 2), (2, 2)], glow_col='#d49bff',
        mega_extra=[(-3, 1, 'o'), (0, 0, 'o'), (3, 1, 'o')], mega_glow=[(-2, 2), (2, 2), (-4, 3), (4, 3)],
    ),
}

# MEGA de la opción B con retoques (misma rejilla de píxel, a escala 10): las patas son lo que lo
# hace imponente — 4 pares (a x10 caben sin enredarse), más altas y abiertas, el cuerpo más arriba
# —, pinzas algo mayores, tres púas en el caparazón y un tercer punto de luz dentro
MEGA_B = dict(OPTIONS['B'],
    canvas=(38, 21),
    body=['..cc.....cc..',
          '.c..c...c..c.',
          '.c.........c.',
          '.c...o.o...c.',
          '..c.ooooo.c..',
          '...oohwwoo...',
          '..owwtttwso..',
          '..owwwtwsso..',
          '...ooooooo...'],
    top=7,
    legs=[(2, 6, -5, 12, -6), (2, 7, -8, 13, -10), (2, 7, -11, 11, -14), (3, 8, -13, 7, -18)],
    glow=[(-2, 6), (2, 6), (0, 7)], mega_glow=[(-2, 6), (2, 6), (0, 7)], mega_extra=[],
)

POSES = ['andar1', 'andar2', 'andar3', 'andar4', 'quieto', 'agachado', 'salto', 'susto', 'aplastado']


def line(px, x0, y0, x1, y1, col):
    """Línea de 1 px (Bresenham) en el diccionario de píxeles"""
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        px[(x0, y0)] = col
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy; x0 += sx
        if e2 <= dx:
            err += dx; y0 += sy


def frame(o, pose, mega=False):
    """Un cuadro (W x H). Devuelve (imagen, puntos luminosos en px del cuadro)"""
    global W, H, CX
    W, H = o.get('canvas', (26, 15))
    CX = W // 2
    pal = {k: rgb(v) for k, v in o['pal'].items()}
    body = o['body']
    bw, bh = len(body[0]), len(body)
    ground = H - 1
    top = o['top']
    lift, spread, knee_up, foot_in, tuck = 0, 1.0, 0, 1.0, False
    phase = None
    if pose.startswith('andar'):
        phase = (int(pose[-1]) - 1) / 4.0
    elif pose == 'agachado':
        lift, knee_up, spread = -min(top, 2), 1, 1.05
    elif pose == 'salto':
        lift, tuck = 2, True
    elif pose == 'susto':
        lift, knee_up, spread = 1, 2, 1.12
    px = {}
    if pose == 'aplastado':
        # tortita: el cuerpo en 2 filas y las patas tiradas a los lados
        half = bw // 2 + 1
        for x in range(-half, half + 1):
            px[(CX + x, ground)] = pal['o']
            if abs(x) < half:
                px[(CX + x, ground - 1)] = pal['w'] if x < half - 2 else pal['s']
        for x in range(-half + 1, half):
            px[(CX + x, ground - 2)] = pal['o']
        for i, (_, _, _, _, fdx) in enumerate(o['legs']):
            for side in (-1, 1):
                x1 = CX + side * (half + 1 + i * 2)
                line(px, CX + side * half, ground - 1, x1, ground - (i % 2), pal['l'])
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        for (x, y), c in px.items():
            if 0 <= x < W and 0 <= y < H:
                im.putpixel((x, y), c)
        return im, []
    by0 = ground - top - bh + 1 - lift                   # fila de arriba del cuerpo
    bx0 = CX - bw // 2
    # Patas (detrás del cuerpo)
    for i, (hdx, hdy, kdx, kdy, fdx) in enumerate(o['legs']):
        for side in (-1, 1):
            hip = (CX + side * (bw // 2 - hdx), by0 + hdy)
            kx, ky, fx, fy = kdx * spread, kdy + knee_up, fdx * spread * foot_in, 0
            if phase is not None:
                a = 2 * math.pi * (phase + i / float(len(o['legs'])) + (0.5 if side > 0 else 0))
                fx += math.sin(a) * 1.4
                fy = max(0, math.cos(a)) * 1.2            # (el pie se alza al adelantarse)
                kx += math.sin(a) * 0.7
                ky += max(0, math.cos(a)) * 0.8
            if tuck:                                      # en el aire: recogidas hacia abajo y atrás
                kx, ky, fx, fy = kdx * 0.75, kdy * 0.55 + 2, fdx * 0.55, 1 + (i % 2)
            knee = (CX + side * (-kx), ground - ky - (lift if tuck else 0))
            foot = (CX + side * (-fx), ground - fy - (lift + 2 if tuck else 0))
            line(px, hip[0], hip[1], knee[0], knee[1], pal['j'])      # (fémur, más oscuro: el cuerpo se lee)
            line(px, knee[0], knee[1], foot[0], foot[1], pal['l'])
    # Cuerpo (con sus pinzas)
    for y, row in enumerate(body):
        for x, ch in enumerate(row):
            if ch != '.':
                px[(bx0 + x, by0 + y)] = pal[ch]
    if mega:
        for dx, dy, ch in o['mega_extra']:
            px[(CX + dx, by0 + dy)] = pal[ch]
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for (x, y), c in px.items():
        if 0 <= x < W and 0 <= y < H:
            im.putpixel((x, y), c)
    glow = [(CX + dx, by0 + dy) for dx, dy in (o['mega_glow'] if mega else o['glow'])]
    return im, glow


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def draw_glow(dst, x, y, k, col, strength=1.0, halo=True):
    """Punto luminoso (px de pantalla): el punto y un halo pequeño, pixelado"""
    c = rgb(col)
    lay = Image.new('RGBA', dst.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for r, a in (((k * 2.2, 26), (k * 1.4, 60)) if halo else ()):
        d.rectangle([x - r + k / 2, y - r + k / 2, x + r + k / 2 - 1, y + r + k / 2 - 1], fill=c[:3] + (int(a * strength),))
    d.rectangle([x, y, x + k - 1, y + k - 1], fill=c[:3] + (int(255 * min(1, strength)),))
    dst.alpha_composite(lay)


def put(dst, o, pose, x, y, k, lit=1.0, mega=False, rot=0, flip=False):
    """Dibuja un cuadro con los pies en (x, y) de pantalla; lit = cuánta luz le da (0 = solo los puntos)"""
    im, glow = frame(o, pose, mega)
    pts = []
    for gx, gy in glow:
        pts.append((gx, gy))
    big = up(im, k)
    if lit < 1:
        # a oscuras: casi invisible (una sombra muy tenue)
        r, g, b, a = big.split()
        dark = Image.merge('RGBA', (r.point(lambda v: int(v * (0.05 + 0.95 * lit))), g.point(lambda v: int(v * (0.06 + 0.94 * lit))),
                                    b.point(lambda v: int(v * (0.1 + 0.9 * lit))), a.point(lambda v: int(v * (0.35 + 0.65 * lit)))))
        big = dark
    # transformaciones: boca abajo (techo) o girado (pared)
    def tr(px, py):
        if flip:
            return px, (H * k) - py - k
        return px, py
    if flip:
        big = big.transpose(Image.FLIP_TOP_BOTTOM)
    ox, oy = x - big.width // 2, y - big.height
    if flip:
        oy = y
    if rot:
        big = big.rotate(rot, expand=True)
        ox, oy = (x, y - big.height // 2) if rot == 270 else (x - big.width, y - big.height // 2)
    dst.alpha_composite(big, (int(ox), int(oy)))
    for gx, gy in pts:
        sx, sy = gx * k, gy * k
        if flip:
            sy = (H - 1 - gy) * k
        if rot == 270:          # pared izquierda: los pies a la izquierda
            sx, sy = (H - 1 - gy) * k, gx * k
        elif rot == 90:         # pared derecha
            sx, sy = gy * k, (W - 1 - gx) * k
        draw_glow(dst, int(ox + sx), int(oy + sy), k, o['glow_col'], 1.0, halo=lit < 1)


# ── Cueva a oscuras ──────────────────────────────────────────────────────────
T = 64


def cave(wt, ht, blocks):
    """Sala de wt x ht casillas: bordes de roca + `blocks` [(col, fila)]; devuelve (imagen, sólidos)"""
    stone = Image.open(os.path.join(IMG, 'tiles', 'stone.png')).convert('RGBA')
    deep = Image.open(os.path.join(IMG, 'tiles', 'deep_stone.png')).convert('RGBA')
    im = Image.new('RGBA', (wt * T, ht * T), rgb('#20222e'))
    solid = set()
    for c in range(wt):
        for r in range(ht):
            if c == 0 or c == wt - 1 or r == 0 or r == ht - 1 or (c, r) in blocks:
                solid.add((c, r))
    for (c, r) in solid:
        tex = deep if (r == ht - 1 or r == 0) else stone
        im.paste(tex.crop(((c % 2) * T, (r % 2) * T, (c % 2) * T + T, (r % 2) * T + T)), (c * T, r * T))
    for name, c, r, hang in (('stalactite', 5, 1, True), ('stalagmite', 9, ht - 2, False), ('glow_mushroom', 12, ht - 2, False),
                             ('bones', 3, ht - 2, False), ('stalactite', 11, 1, True), ('crystals', 13, ht - 2, False)):
        p = os.path.join(IMG, 'decorations', 'cave', name + '.png')
        if os.path.exists(p) and c < wt - 1:
            d = Image.open(p).convert('RGBA')
            if d.width > d.height * 1.5:
                d = d.crop((0, 0, d.height, d.height))
            d = up(d, 4)
            im.alpha_composite(d, (c * T + (T - d.width) // 2, r * T if hang else (r + 1) * T - d.height))
    return im


def darkness(scene, lights, ambient=0.045, block=8):
    """Oscurece la escena: cada luz = (x, y, dirección en grados | None, alcance, medio ángulo);
    luz por bloques de `block` px y en 4 escalones (pixel art, sin degradados suaves)"""
    w, h = scene.size
    mask = Image.new('L', (w // block + 1, h // block + 1), 0)
    mp = mask.load()
    for by in range(mask.height):
        for bx in range(mask.width):
            x, y = bx * block + block / 2, by * block + block / 2
            best = 0.0
            for lx, ly, ang, rng, half in lights:
                d = math.hypot(x - lx, y - ly)
                v = 0.0
                if ang is None:
                    v = max(0.0, 1 - d / rng)
                else:
                    a = math.degrees(math.atan2(y - ly, x - lx))
                    da = abs((a - ang + 180) % 360 - 180)
                    if da < half and d < rng:
                        v = (1 - d / rng) ** 0.6 * min(1, (half - da) / 10 + 0.35)
                best = max(best, v)
            q = 0 if best < 0.06 else 0.28 if best < 0.3 else 0.6 if best < 0.62 else 1.0     # escalones
            mp[bx, by] = int(255 * q)
    mask = mask.resize((mask.width * block, mask.height * block), Image.NEAREST).crop((0, 0, w, h))
    dark = Image.new('RGBA', (w, h), (8, 9, 18, 255))
    amb = Image.blend(dark, scene, ambient)
    return Image.composite(scene, amb, mask), mask


def light_at(mask, x, y):
    x, y = max(0, min(mask.width - 1, int(x))), max(0, min(mask.height - 1, int(y)))
    return mask.getpixel((x, y)) / 255.0


def hud(im, charge):
    """Linterna: icono + barra de batería (maqueta del HUD)"""
    d = ImageDraw.Draw(im)
    x, y = 24, 22
    d.rectangle([x - 4, y - 4, x + 190, y + 28], fill=(0, 0, 0, 150))
    d.rectangle([x, y + 4, x + 22, y + 18], fill=(240, 220, 120, 255))
    d.polygon([(x + 22, y), (x + 34, y - 2), (x + 34, y + 24), (x + 22, y + 22)], fill=(255, 245, 190, 255))
    for i in range(8):
        on = i < int(charge * 8 + 0.5)
        col = (255, 226, 110, 255) if on else (70, 70, 84, 255)
        if on and charge < 0.3:
            col = (240, 90, 70, 255)
        d.rectangle([x + 46 + i * 17, y + 2, x + 46 + i * 17 + 12, y + 20], fill=col)


def mockup(key):
    o = OPTIONS[key]
    wt, ht = 15, 8
    blocks = {(6, 5), (7, 5), (8, 5), (11, 3), (12, 3), (3, 3)}
    scene = cave(wt, ht, blocks)
    floor = (ht - 1) * T
    # el jugador, con la linterna hacia la derecha
    pl = up(Image.open(os.path.join(IMG, 'player', 'monstrito1.png')).convert('RGBA'), 6)
    px, py = 4 * T + 10, floor
    scene.alpha_composite(pl, (px - pl.width // 2, py - pl.height))
    lights = [(px + 20, py - 56, -6, 330, 30), (px, py - 50, None, 86, 0)]
    # dónde está cada Crabby lúgubre: (x, y, pose, techo, pared)
    crabs = [(8 * T, floor, 'susto', False, 0),                 # alumbrado: huye
             (11 * T + 20, floor, 'andar2', False, 0),          # al borde de la luz
             (13 * T, 3 * T, 'andar3', False, 0),               # sobre un bloque, a oscuras
             (2 * T, T, 'andar1', True, 0),                     # en el techo, detrás del jugador
             (9 * T + 30, T, 'agachado', True, 0),              # en el techo, a punto de saltar
             (T, 5 * T, 'andar4', False, 270),                  # en la pared izquierda
             (7 * T, 5 * T, 'quieto', False, 0)]                # sobre la plataforma, a oscuras
    lit_scene = scene.copy()
    for x, y, pose, flip, rot in crabs:
        put(lit_scene, o, pose, x, y, SMALL, 1.0, flip=flip, rot=rot)
    out, mask = darkness(lit_scene, lights)
    # (los puntos luminosos se ven SIEMPRE: encima de la oscuridad)
    for x, y, pose, flip, rot in crabs:
        cy = y + (H * SMALL // 2 if flip else -H * SMALL // 2)
        cxx = x + (H * SMALL // 2 if rot == 270 else 0)
        lv = light_at(mask, cxx, cy)
        ghost = Image.new('RGBA', out.size, (0, 0, 0, 0))
        put(ghost, o, pose, x, y, SMALL, 0.0, flip=flip, rot=rot)
        if lv < 0.5:
            out.alpha_composite(ghost)
    hud(out, 0.55)
    d = ImageDraw.Draw(out)
    d.text((240, 26), 'Opción %s: %s  (a escala de juego x4)' % (key, o['name']), fill=(230, 230, 240, 255), font=FONT)
    out.save(os.path.join(OUT, 'maqueta_%s.png' % key))


def mockup_mega():
    wt, ht = 10, 7
    panels = []
    for key, o in OPTIONS.items():
        scene = cave(wt, ht, set())
        floor = (ht - 1) * T
        pl = up(Image.open(os.path.join(IMG, 'player', 'monstrito1.png')).convert('RGBA'), 6)
        px, py = 2 * T + 20, floor
        scene.alpha_composite(pl, (px - pl.width // 2, py - pl.height))
        lit = scene.copy()
        mx, my = 6 * T + 20, floor
        put(lit, o, 'andar2', mx, my, MEGA, 1.0, mega=True)
        put(lit, o, 'andar1', 8 * T + 30, T, SMALL, 1.0, flip=True)
        out, mask = darkness(lit, [(px + 20, py - 56, -8, 300, 28), (px, py - 50, None, 86, 0)])
        ghost = Image.new('RGBA', out.size, (0, 0, 0, 0))
        put(ghost, o, 'andar2', mx, my, MEGA, 0.0, mega=True)
        # (solo lo que queda a oscuras: recorta el fantasma donde hay luz)
        inv = mask.point(lambda v: 255 if v < 100 else 0)
        out.paste(Image.alpha_composite(out, ghost), (0, 0), inv)
        put(out, o, 'andar1', 8 * T + 30, T, SMALL, 0.0, flip=True)
        ImageDraw.Draw(out).text((16, 12), 'Mega %s: %s (el mismo sprite a x10)' % (key, o['name']), fill=(230, 230, 240, 255), font=FONT)
        panels.append(out)
    w, h = panels[0].size
    sheet = Image.new('RGBA', (w * 2 + 8, h * 2 + 8), (0, 0, 0, 255))
    for i, p in enumerate(panels):
        sheet.paste(p, ((i % 2) * (w + 8), (i // 2) * (h + 8)))
    sheet.save(os.path.join(OUT, 'maqueta_mega.png'))


def options_sheet():
    K = 6
    cw, ch = W * K + 10, H * K + 14
    rows = []
    for key, o in OPTIONS.items():
        row = Image.new('RGBA', (cw * len(POSES) + 20, ch * 2 + 34), rgb('#2a3044'))
        d = ImageDraw.Draw(row)
        d.text((8, 4), 'Opción %s: %s. %s' % (key, o['name'], o['note']), fill=(240, 240, 250, 255), font=FONT)
        d.rectangle([0, 22 + ch, row.width, row.height], fill=rgb('#07080f'))
        for i, pose in enumerate(POSES):
            x = 10 + i * cw + cw // 2
            put(row, o, pose, x, 22 + ch - 4, K, 1.0)
            put(row, o, pose, x, 22 + ch * 2 - 4, K, 0.0)
            d.text((10 + i * cw + 4, 22 + ch * 2), pose, fill=(150, 156, 180, 255), font=FONT)
        rows.append(row)
    sheet = Image.new('RGBA', (rows[0].width, sum(r.height for r in rows) + 8 * len(rows)), (0, 0, 0, 255))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y)); y += r.height + 8
    sheet.save(os.path.join(OUT, 'opciones.png'))


def walk_gif(key):
    o = OPTIONS[key]
    K = 8
    frames = []
    for i in range(4):
        im = Image.new('RGBA', (W * K * 2 + 24, H * K + 16), rgb('#2a3044'))
        ImageDraw.Draw(im).rectangle([W * K + 12, 0, im.width, im.height], fill=rgb('#07080f'))
        put(im, o, 'andar%d' % (i + 1), W * K // 2 + 4, H * K + 8, K, 1.0)
        put(im, o, 'andar%d' % (i + 1), W * K + 16 + W * K // 2, H * K + 8, K, 0.0)
        frames.append(im.convert('P', palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(OUT, 'andar_%s.gif' % key), save_all=True, append_images=frames[1:], duration=110, loop=0)


def mockup_mega_b():
    """El Mega de la opción elegida (B), de dos maneras: solo escalado / con retoques. Arriba, a la
    luz (con el pequeño y el jugador para comparar); abajo, en la arena a oscuras"""
    o = OPTIONS['B']
    wt, ht = 11, 7
    variants = (('1. Solo escalado: el sprite del pequeño a x10', o, True), ('2. Con retoques: 4 pares de patas más altas y abiertas, pinzas mayores, púas', MEGA_B, False))
    panels = []
    for title, ov, mg in variants:
        col = []
        for dark in (False, True):
            scene = cave(wt, ht, set())
            floor = (ht - 1) * T
            pl = up(Image.open(os.path.join(IMG, 'player', 'monstrito1.png')).convert('RGBA'), 6)
            px, py = 2 * T, floor
            scene.alpha_composite(pl, (px - pl.width // 2, py - pl.height))
            mx = 6 * T + 32
            lit = scene.copy()
            put(lit, ov, 'andar2', mx, floor, MEGA, 1.0, mega=mg)
            put(lit, o, 'andar1', 3 * T + 40, floor, SMALL, 1.0)
            if not dark:
                out = Image.blend(Image.new('RGBA', lit.size, (8, 9, 18, 255)), lit, 0.8)
            else:
                out, mask = darkness(lit, [(px + 20, py - 56, -10, 330, 30), (px, py - 50, None, 86, 0)])
                ghost = Image.new('RGBA', out.size, (0, 0, 0, 0))
                put(ghost, ov, 'andar2', mx, floor, MEGA, 0.0, mega=mg)
                inv = mask.point(lambda v: 255 if v < 100 else 0)
                out.paste(Image.alpha_composite(out, ghost), (0, 0), inv)
            ImageDraw.Draw(out).text((16, 12), title + (' (a oscuras)' if dark else ' (a la luz)'), fill=(230, 230, 240, 255), font=FONT)
            col.append(out)
        panels.append(col)
    w, h = panels[0][0].size
    sheet = Image.new('RGBA', (w * 2 + 8, h * 2 + 8), (0, 0, 0, 255))
    for i, col in enumerate(panels):
        for j, p in enumerate(col):
            sheet.paste(p, (i * (w + 8), j * (h + 8)))
    sheet.save(os.path.join(OUT, 'mega_B_comparacion.png'))
    # y sus cuadros, ampliados
    K = 5
    fr = [frame(MEGA_B, pz, False)[0] for pz in POSES]
    strip = Image.new('RGBA', (sum(f.width * K + 8 for f in fr), fr[0].height * K + 8), rgb('#2a3044'))
    x = 4
    for pz in POSES:
        put(strip, MEGA_B, pz, x + fr[0].width * K // 2, fr[0].height * K + 4, K, 1.0)
        x += fr[0].width * K + 8
    strip.save(os.path.join(OUT, 'mega_B_retoques_cuadros.png'))


def sheets(o, mega=False):
    """Tira con todos los cuadros (POSES) y, aparte, la de los PUNTOS LUMINOSOS (la misma rejilla,
    solo esos píxeles, en blanco: el juego los tiñe y los dibuja ENCIMA de la oscuridad)"""
    fr = [frame(o, pz, mega) for pz in POSES]
    w, h = fr[0][0].size
    body = Image.new('RGBA', (w * len(fr), h), (0, 0, 0, 0))
    glow = Image.new('RGBA', (w * len(fr), h), (0, 0, 0, 0))
    for i, (im, pts) in enumerate(fr):
        body.paste(im, (i * w, 0))
        for gx, gy in pts:
            glow.putpixel((i * w + gx, gy), (255, 255, 255, 255))
    return body, glow


def flashlight_icon():
    """Icono de la linterna del HUD, 3 cuadros 12x8: encendida, apagada, agotada (enfriándose)"""
    rows_on = ['....oooo....',
               'ooooyyyyoo..',
               'oggoyyyyowo.',
               'oggoyyyyowwo',
               'oggoyyyyowwo',
               'oggoyyyyowo.',
               'ooooyyyyoo..',
               '....oooo....']
    pals = [dict(o='#1e1e2a', g='#8a8fa6', y='#ffe27a', w='#fff8d0'),
            dict(o='#1e1e2a', g='#8a8fa6', y='#b9bccb', w='#5a5f78'),
            dict(o='#1e1e2a', g='#8a8fa6', y='#e2603c', w='#7a2e24')]
    out = Image.new('RGBA', (36, 8), (0, 0, 0, 0))
    for i, pal in enumerate(pals):
        for y, r in enumerate(rows_on):
            for x, ch in enumerate(r):
                if ch != '.':
                    out.putpixel((i * 12 + x, y), rgb(pal[ch]))
    return out


def touch_light():
    """Botón táctil de la linterna: 2 cuadros 24x24 (suelto / pulsado), como los de la cruceta y el salto"""
    out = Image.new('RGBA', (48, 24), (0, 0, 0, 0))
    ico = flashlight_icon().crop((0, 0, 12, 8))
    for i in range(2):
        d = ImageDraw.Draw(out)
        d.ellipse([i * 24 + 1, 1, i * 24 + 22, 22], fill=rgb('#1e1e2a'))
        d.ellipse([i * 24 + 2, 2, i * 24 + 21, 21], fill=rgb('#f2f2f6') if i == 0 else rgb('#ffe27a'))
        d.ellipse([i * 24 + 4, 5, i * 24 + 21, 21], fill=rgb('#c4c8d6') if i == 0 else rgb('#e6b84a'))
        d.ellipse([i * 24 + 3, 3, i * 24 + 19, 19], fill=rgb('#f2f2f6') if i == 0 else rgb('#ffe27a'))
        out.alpha_composite(ico, (i * 24 + 6, 8))
    return out


def icons():
    """Iconos que flotan sobre un lúgubre en vez de sonidos (el silencio es parte del nivel): 3 cuadros
    10x11 en blanco con contorno oscuro (el juego los tiñe): ! ha oído algo · ? busca · … ha perdido el
    rastro. Trazo de 2 px: con 1 px no se veían en la oscuridad"""
    glyphs = [['..xx....', '..xx....', '..xx....', '..xx....', '..xx....', '..xx....', '........', '..xx....', '..xx....'],
              ['.xxxx...', 'xx..xx..', '....xx..', '...xx...', '..xx....', '..xx....', '........', '..xx....', '..xx....'],
              ['........', '........', '........', '........', '........', '........', '........', 'xx.xx.xx', 'xx.xx.xx']]
    FWI, FHI = 10, 11
    out = Image.new('RGBA', (FWI * 3, FHI), (0, 0, 0, 0))
    for i, g in enumerate(glyphs):
        on = {(x + 1, y + 1) for y, r in enumerate(g) for x, ch in enumerate(r) if ch == 'x'}
        for (x, y) in on:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if (x + dx, y + dy) not in on and 0 <= x + dx < FWI and 0 <= y + dy < FHI:
                        out.putpixel((i * FWI + x + dx, y + dy), (20, 20, 30, 255))
        for (x, y) in on:
            out.putpixel((i * FWI + x, y), (255, 255, 255, 255))
    return out


def apply():
    o = OPTIONS['B']
    body, glow = sheets(o)
    mbody, mglow = sheets(MEGA_B)
    out = {
        'gloomy/gloomy-Sheet.png': body, 'gloomy/glow-Sheet.png': glow,
        'bosses/megagloomy/body-Sheet.png': mbody, 'bosses/megagloomy/glow-Sheet.png': mglow,
        'gloomy/icons-Sheet.png': icons(),
        'ui/flashlight-Sheet.png': flashlight_icon(), 'ui/touch/light-Sheet.png': touch_light(),
    }
    for name, im in out.items():
        p = os.path.join(IMG, name)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)
        print('escrito', os.path.relpath(p, ROOT), im.size)


if __name__ == '__main__':
    if '--apply' in sys.argv:
        apply()
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    options_sheet()
    for k in OPTIONS:
        mockup(k)
        walk_gif(k)
    mockup_mega()
    mockup_mega_b()
    print('vista previa en', OUT)
