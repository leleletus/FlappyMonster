#!/usr/bin/env python3
# tools/ui/make_icecrabby_claws.py — PINZAS PEQUEÑAS del Crabby helado (propuestas).
# El Mega Crabby helado tiene las pinzas grandes (assets/images/bosses/megacrabby_ice/claw_left-Sheet.png,
# 10x7, dedos hacia dentro, 3 púas en el dorso). El Crabby helado normal lleva una versión
# MÁS PEQUEÑA y MÁS FINA, distinta de la del Mega pero de la misma familia: mismo contorno,
# mismos tonos naranja, dedos hacia dentro, dos cuadros (abierta / cerrada) como el Mega.
#
#   python3 tools/ui/make_icecrabby_claws.py            # vista previa de las opciones (fuera del repo)
#   python3 tools/ui/make_icecrabby_claws.py --apply X  # escribe la opción X en assets/images/enemies/crabby_ice/
#   (--out DIR: carpeta de la vista previa; por defecto $FM_PREVIEWS/crabby_ice_claws o
#    /home/mtvemo/FlappyMonster_pruebas/crabby_ice_claws)
#
# Vista previa: opciones.png (todas las opciones ampliadas: cuadros abierta/cerrada, junto a la
# pinza del Mega), maqueta.png (el Crabby helado en el juego con cada opción, junto al Crabby
# normal y al Mega helado, a escala de juego), anim_<X>.gif (andar con chasquidos, descanso,
# esconderse: la animación de las pinzas del Mega adaptada).
import argparse
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
ICE = os.path.join(ROOT, 'assets', 'images', 'enemies', 'crabby_ice')
MEGA = os.path.join(ROOT, 'assets', 'images', 'bosses', 'megacrabby_ice')
NORMAL = os.path.join(ROOT, 'assets', 'images', 'enemies', 'crabby')

PAL = {
    '.': None,
    'O': (30, 30, 42),        # contorno
    'H': (255, 216, 168),     # luz
    'L': (248, 158, 88),      # naranja claro
    'M': (226, 104, 50),      # naranja
    'S': (168, 62, 40),       # sombra
}

S = 4                       # escala del Crabby (GUMMY_SCALE)

# Pinza IZQUIERDA (la derecha es su espejo), dedos hacia dentro (a la derecha).
# Cada opción: cuadros [abierta, cerrada] + dónde va (px de arte del cuerpo, como el Mega:
# x desde el centro, y desde los pies, cuánto se mete hacia dentro).
OPTIONS = {
    'A': {
        'name': 'Mini Mega',
        'desc': 'la del Mega en pequeno y fina: 2 puas en el dorso, dedos de 1 px',
        'frames': [
            [".O.O...",
             "OOOOOO.",
             "OHLLLLO",
             "OLOOO.O",
             "OLO....",
             "OMMMO..",
             ".OOO..."],
            [".O.O...",
             "OOOOOO.",
             "OHLLLLO",
             "OLOOOOO",
             "OMMMMO.",
             ".OOOO..",
             "......."],
        ],
        'x': 5.6, 'y': -0.6, 'inset': 1.0,
    },
    'B': {
        'name': 'Tijera',
        'desc': 'sin puas, dedos largos y finos: la silueta mas limpia',
        'frames': [
            [".OOOOOO.",
             "OHLLLLLO",
             "OLOOOO.O",
             "OLO.....",
             "OMMMMO..",
             ".OOOO..."],
            [".OOOOOO.",
             "OHLLLLLO",
             "OLOOOOOO",
             "OMMMMMO.",
             ".OOOOO..",
             "........"],
        ],
        'x': 5.4, 'y': -0.4, 'inset': 1.5,
    },
    'C': {
        'name': 'Garfio',
        'desc': 'dedo de arriba curvado hacia abajo (gancho), una pua: afilada',
        'frames': [
            ["..O....",
             ".OHOOO.",
             "OHLLLLO",
             "OLOOOLO",
             "OLO..OO",
             "OMMO...",
             ".OO...."],
            ["..O....",
             ".OHOOO.",
             "OHLLLLO",
             "OLOOOLO",
             "OMMMMOO",
             ".OOOO..",
             "......."],
        ],
        'x': 5.6, 'y': -0.6, 'inset': 1.0,
    },
}


def grid(rows):
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r.ljust(w, '.')):
            c = PAL[ch]
            if c:
                im.putpixel((x, y), c + (255,))
    return im


def sheet(frames):
    ims = [grid(f) for f in frames]
    w, h = max(i.width for i in ims), max(i.height for i in ims)
    out = Image.new('RGBA', (w * len(ims), h), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        out.paste(im, (i * w, 0))
    return out


def up(im, k):
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.NEAREST)


def load(path):
    return Image.open(path).convert('RGBA')


def frame_of(sh, i, n=2):
    fw = sh.width // n
    return sh.crop((i * fw, 0, (i + 1) * fw, sh.height))


# ── Animación (la del Mega, adaptada): poses de las pinzas ────────────────────
# Desplazamientos en px de arte (dx hacia fuera, dy hacia abajo) y cuadro (0 abierta, 1 cerrada)
def claw_pose(kind, t, side):
    """kind: 'walk' (balanceo con el paso + chasquidos al azar), 'rest' (caídas, respiran),
    'snap' (chasquido doble, como el emote del Mega), 'hide' (se recogen y bajan con el caparazón)"""
    if kind == 'walk':
        dy = round(math.sin(t * 2 * math.pi * 2 + (0 if side < 0 else math.pi)) * 0.6)
        snap = 1 if ((int(t * 6) + (0 if side < 0 else 3)) % 7) < 2 else 0
        return 0, dy, snap
    if kind == 'rest':
        return 0, 1, 1
    if kind == 'snap':
        ph = (t * 4) % 1
        return (1 if ph < 0.5 else 0) * side * 0, -1 if ph < 0.5 else 0, 0 if ph < 0.5 else 1
    return 0, 0, 1


# ── Dibujo (como Mega:drawLocal: cuerpo, pinzas delante junto a las patas) ───
def draw_crab(canvas, body, claws, spike, cx, floor, s, opt=None, frames=(0, 1), offs=((0, 0), (0, 0)),
              spike_dy=2, claw_k=1.0, cfg=None, spike_k=1.0):
    ih = body.height
    if spike is not None and spike_k > 0:
        sk = up(spike, s / 4 * 1.0)
        sk = sk.resize((sk.width, max(1, round(sk.height * spike_k))), Image.NEAREST)
        canvas.alpha_composite(sk, (int(cx - sk.width / 2), int(floor - (ih - spike_dy) * s - sk.height + s / 4)))
    b = up(body, s)
    canvas.alpha_composite(b, (int(cx - b.width / 2), floor - b.height))
    if claws is None:
        return
    cs = s * claw_k
    fw = claws.width // 2
    for i, side in enumerate((-1, 1)):
        fr = frame_of(claws, frames[i])
        if side > 0:
            fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
        c = up(fr, cs)
        dx, dy = offs[i]
        x = cx + side * (cfg['x'] * s + fw * cs / 2 - cfg['inset'] * cs) + side * dx * cs - c.width / 2
        y = floor + cfg['y'] * s - claws.height * cs / 2 + dy * cs - c.height / 2
        canvas.alpha_composite(c, (int(x), int(y)))


def background(w, h, floor):
    bg = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    px = bg.load()
    for y in range(h):
        k = (y // 16) * 16 / max(1, floor)
        c = (int(86 + 50 * k), int(118 + 50 * k), int(176 - 10 * k)) if y < floor else \
            ((236, 244, 255) if y < floor + 6 else (200, 218, 240))
        for x in range(w):
            px[x, y] = c + (255,)
    return bg


def text(d, xy, s, fill=(255, 255, 255)):
    d.text(xy, s, fill=fill, font=ImageFont.load_default())


def preview(out):
    os.makedirs(out, exist_ok=True)
    mega = load(os.path.join(MEGA, 'claw_left-Sheet.png'))
    # 1) opciones ampliadas
    Z = 16
    W = 400 + len(OPTIONS) * 300
    im = Image.new('RGBA', (W, 330), (52, 58, 80, 255))
    d = ImageDraw.Draw(im)
    text(d, (20, 12), 'Mega helado (actual, 10x7): abierta / cerrada')
    for i in range(2):
        im.alpha_composite(up(frame_of(mega, i), Z), (20 + i * (10 * Z + 10), 40))
    x0 = 400
    for k, o in sorted(OPTIONS.items()):
        sh = sheet(o['frames'])
        fw = sh.width // 2
        text(d, (x0, 12), 'OPCION %s: %s (%dx%d)' % (k, o['name'], fw, sh.height))
        text(d, (x0, 26), o['desc'])
        for i in range(2):
            im.alpha_composite(up(frame_of(sh, i), Z), (x0 + i * (fw * Z + 10), 60))
        x0 += 300
    im = im.crop((0, 0, x0, im.height))
    im.convert('RGB').save(os.path.join(out, 'opciones.png'))

    # 2) maqueta en el juego (escala real ×2 para verla mejor)
    body = load(os.path.join(ICE, 'crab1.png'))
    spike = load(os.path.join(ICE, 'spike.png'))
    nbody = load(os.path.join(NORMAL, 'crab1.png'))
    nspike = load(os.path.join(NORMAL, 'spike.png'))
    mbody = load(os.path.join(MEGA, 'crab1.png'))
    mspike = load(os.path.join(MEGA, 'spike.png'))
    Wm, Hm, floor = 1300, 420, 330
    base = background(Wm, Hm, floor)
    d = ImageDraw.Draw(base)
    pl = os.path.join(ROOT, 'assets', 'images', 'player', 'monstrito1.png')
    if os.path.exists(pl):
        p = up(load(pl), 6)
        base.alpha_composite(p, (30, floor - p.height))
    draw_crab(base, nbody, None, nspike, 170, floor, S, spike_dy=0)
    text(d, (130, floor + 20), 'Crabby normal', (40, 40, 60))
    draw_crab(base, body, None, spike, 300, floor, S)
    text(d, (250, floor + 20), 'helado (ahora)', (40, 40, 60))
    x = 450
    for k, o in sorted(OPTIONS.items()):
        sh = sheet(o['frames'])
        draw_crab(base, body, sh, spike, x, floor, S, frames=(0, 1), cfg=o)
        text(d, (x - 40, floor + 20), 'helado %s: %s' % (k, o['name']), (40, 40, 60))
        x += 150
    draw_crab(base, mbody, mega, mspike, x + 160, floor, 10, frames=(0, 1),
              cfg={'x': 5.4, 'y': -1.2, 'inset': 1.5})
    text(d, (x + 90, floor + 20), 'Mega helado (x10)', (40, 40, 60))
    big = up(base.crop((0, 120, min(Wm, x + 330), Hm)), 2)
    big.convert('RGB').save(os.path.join(out, 'maqueta.png'))

    # 3) animaciones por opción (las del Mega, adaptadas). Secuencia de 40 cuadros a 12 fps:
    #    andar 1-2-1-3 con balanceo y chasquidos al azar (16) · chasquido doble del descanso,
    #    pinzas arriba (8) · esconderse: se hunden con el caparazón fila a fila y desaparecen
    #    bajo la superficie (9) · escondido (3) · salir (4, al revés)
    walk = [load(os.path.join(ICE, 'crab%d.png' % n)) for n in (1, 2, 1, 3)]
    sinks = [load(os.path.join(ICE, 'sink%d.png' % n)) for n in range(1, 9)]
    hid = Image.new('RGBA', (18, 13), (0, 0, 0, 0))

    def sunk(i):                     # cuerpo 18x13 con el cuadro de hundirse i apoyado en los pies
        full = Image.new('RGBA', (18, 13), (0, 0, 0, 0))
        full.paste(sinks[i], (0, 5))
        return full

    seq = []
    for f in range(16):
        t = f / 12
        po = [claw_pose('walk', t, sd) for sd in (-1, 1)]
        seq.append(('andar', walk[(f // 2) % 4], [(p[0], p[1]) for p in po], [p[2] for p in po], 0))
    for f in range(8):
        ph = f % 4
        up_ = -2 if ph < 2 else -1
        seq.append(('chasquido', walk[1], [(0, up_), (0, up_)], [0 if ph < 2 else 1] * 2, 0))
    for i in range(8):
        seq.append(('esconderse', sunk(i), [(0, i + 1), (0, i + 1)], [1, 1], i + 5))
    for f in range(4):
        seq.append(('escondido', hid, [(0, 13), (0, 13)], [1, 1], 13))
    for i in range(7, -1, -2):
        seq.append(('salir', sunk(i), [(0, i + 1), (0, i + 1)], [1, 1], i + 5))
    FLOOR = 70
    for k, o in sorted(OPTIONS.items()):
        sh = sheet(o['frames'])
        frames = []
        for name, b, offs, fs, drop in seq:
            fr = background(120, 96, FLOOR)
            layer = Image.new('RGBA', fr.size, (0, 0, 0, 0))
            draw_crab(layer, b, sh, spike, 60, FLOOR, S, frames=fs, offs=offs, cfg=o, spike_dy=2 + drop)
            layer = layer.crop((0, 0, layer.width, FLOOR))         # (lo hundido no se ve)
            fr.alpha_composite(layer, (0, 0))
            frames.append((name, fr))
        big = [up(f, 2).convert('RGB') for _, f in frames]
        big[0].save(os.path.join(out, 'anim_%s.gif' % k), save_all=True, append_images=big[1:],
                     duration=83, loop=0)
        # hoja con TODOS los cuadros
        cols = 10
        cw, ch = 120 * 2, 96 * 2 + 14
        rows = (len(frames) + cols - 1) // cols
        sheet_im = Image.new('RGBA', (cols * cw, rows * ch + 20), (40, 44, 60, 255))
        d2 = ImageDraw.Draw(sheet_im)
        text(d2, (6, 4), 'OPCION %s: %s - %d cuadros a 12 fps' % (k, o['name'], len(frames)))
        for n, (name, f) in enumerate(frames):
            x, y = (n % cols) * cw, 20 + (n // cols) * ch
            sheet_im.alpha_composite(up(f, 2), (x, y))
            text(d2, (x + 4, y + 96 * 2), '%d %s' % (n + 1, name))
        sheet_im.convert('RGB').save(os.path.join(out, 'cuadros_%s.png' % k))
    print('vista previa:', out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', default=None)
    ap.add_argument('--out', default=os.path.join(os.environ.get('FM_PREVIEWS', '/home/mtvemo/FlappyMonster_pruebas'),
                                                  'crabby_ice_claws'))
    a = ap.parse_args()
    preview(a.out)
    if a.apply:
        o = OPTIONS[a.apply]
        sheet(o['frames']).save(os.path.join(ICE, 'claw_left-Sheet.png'))
        print('escrito', os.path.join(ICE, 'claw_left-Sheet.png'))


if __name__ == '__main__':
    sys.exit(main())
