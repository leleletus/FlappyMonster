#!/usr/bin/env python3
# tools/art/enemies/make_bomb_fuses.py — la CUERDA de las bombas, aparte del cuerpo. Las hojas del cuerpo
# (bomb-Sheet.png, bombObject-Sheet.png) las dibuja el USUARIO y aquí solo se LEEN (2026-10-08: sus bombas ya no
# llevan la cuerda dentro). Este script mide cada bomba de esas hojas y escribe, casadas con cada cuadro:
#   bomb-rope-Sheet.png / bombObject-rope-Sheet.png   la cuerda APAGADA de cada cuadro del cuerpo
#   bomb-fuse-Sheet.png / bombObject-fuse-Sheet.png   la cuerda ENCENDIDA (más corta, con la chispa: 4 cuadros de
#                                                     parpadeo) de cada cuadro que puede arder (quieta y a punto)
# y rehace las animaciones del conjunto assets/anim/enemies/bomb.json: los recortes del cuerpo (cada bomba en SU
# sitio de la hoja: no van en una rejilla fija, así ninguna sale cortada), las cuerdas y la explosión.
# Las cuerdas van en celdas más grandes que el cuerpo (PX a cada lado, PY arriba) con su ancla en el mismo punto.
# Si el usuario cambia otra vez las hojas del cuerpo: volver a ejecutarlo.
#   python3 tools/art/enemies/make_bomb_fuses.py            (vista previa en FlappyMonster_pruebas/bombas/)
#   python3 tools/art/enemies/make_bomb_fuses.py --apply    (escribe las cuerdas y el conjunto)
import os, sys
import numpy as np
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
DIR = os.path.join(REPO, 'assets/images/enemies/bomb')
P = 'assets/images/enemies/bomb/'
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/bombas'
BW, BH = 13, 16            # recorte del cuerpo (todas las bombas caben; la más ancha mide 13)
PX, PY = 5, 8              # margen de la celda de la cuerda: a cada lado y arriba
CW, CH = BW + 2 * PX, BH + PY
F, f = (176, 130, 78, 255), (124, 88, 50, 255)                    # cuerda (clara / oscura; la oscura = el cabo del usuario)
W, HOT1, HOT2 = (236, 241, 255, 255), (255, 122, 44, 255), (255, 206, 92, 255)
ROPE = {   # recorrido de la cuerda desde el cabo (dx, dy), hacia arriba
    'idle': [(0, 0), (0, -1), (0, -2), (1, -3), (2, -3), (3, -4)],
    'left': [(0, 0), (0, -1), (-1, -2), (-1, -3), (-2, -4)],
    'right': [(0, 0), (0, -1), (1, -2), (2, -2), (3, -3), (4, -4)],
    'short': [(0, 0), (0, -1), (1, -2), (1, -3)],
}
SPARK = [
    {(0, 0): W, (0, 1): HOT2, (1, 0): HOT2, (-1, 0): HOT1},
    {(0, 0): HOT2, (0, -1): W, (1, 1): HOT1, (-1, 1): HOT1, (0, 1): HOT1},
    {(0, 0): W, (1, -1): HOT2, (-1, -1): HOT2, (0, 1): HOT1, (2, 0): HOT1},
    {(0, 0): HOT2, (-1, 0): W, (1, 0): HOT1, (0, -1): HOT2, (-2, -1): HOT1},
]


def sprites(file):
    """Las bombas de una hoja del usuario: [{x, y (recorte BW x BH), ax, ay (el cabo, en píxeles del recorte)}]."""
    im = Image.open(os.path.join(DIR, file)).convert('RGBA')
    a = np.array(im)
    ink = a[..., 3] > 0
    cols = ink.any(axis=0)
    runs, x = [], 0
    while x < im.width:
        if cols[x]:
            x1 = x
            while x1 < im.width and cols[x1]: x1 += 1
            # (dos bombas pegadas: se parten por la anchura máxima)
            n = max(1, round((x1 - x) / BW)) if (x1 - x) > BW else 1
            for i in range(n): runs.append((x + i * (x1 - x) // n, x + (i + 1) * (x1 - x) // n))
            x = x1
        else: x += 1
    out = []
    for x0, x1 in runs:
        sub = ink[:, x0:x1]
        ys = np.where(sub.any(axis=1))[0]
        top, bottom = int(ys[0]), int(ys[-1]) + 1
        cx0 = x0 - (BW - (x1 - x0)) // 2
        cy0 = bottom - BH
        assert cy0 >= 0 and cx0 >= 0 and cx0 + BW <= im.width, (file, x0, x1, top, bottom)
        # el cabo: el píxel marrón de la fila de arriba si el usuario lo dibujó; si no, el centro del casquillo
        xs = [x for x in range(x0, x1) if ink[top, x]]
        brown = [x for x in xs if tuple(a[top, x][:3]) != (0, 0, 0)]
        ax = brown[0] if brown else xs[len(xs) // 2]
        out.append({'x': cx0, 'y': cy0, 'ax': ax - cx0, 'ay': top - cy0, 'stub': bool(brown)})
    return im, out


def rope(sp, kind, spark=None):
    """Una celda de cuerda para la bomba `sp`. → imagen CW x CH, punta (x, y) en la celda."""
    img = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    px = img.load()
    tip = None
    for i, (dx, dy) in enumerate(ROPE[kind]):
        x, y = PX + sp['ax'] + dx, PY + sp['ay'] + dy
        px[x, y] = f if i % 2 == 0 else F
        tip = (x, y)
    if spark is not None:
        for (dx, dy), col in SPARK[spark].items():
            x, y = tip[0] + dx, tip[1] + dy
            if 0 <= x < CW and 0 <= y < CH: px[x, y] = col
    return img, tip


def strip(cells):
    out = Image.new('RGBA', (CW * len(cells), CH), (0, 0, 0, 0))
    for i, c in enumerate(cells): out.paste(c, (i * CW, 0))
    return out


def build():
    """→ {archivo: imagen}, y el plan de animaciones."""
    files, plan = {}, {}
    for pre, body, n_walk in (('', 'bomb', 2), ('object_', 'bombObject', 0)):
        im, sp = sprites(body + '-Sheet.png')
        want = 4 + n_walk
        assert len(sp) == want, '%s-Sheet.png: se esperaban %d bombas (quieta, parpadeo%s, a punto 1, a punto 2) y hay %d' % (
            body, want, ', andar 1, andar 2' if n_walk else '', len(sp))
        idle, lit = sp[0:2], sp[-2:]
        walk = sp[2:4] if n_walk else []
        ropes = [rope(s, 'idle')[0] for s in idle] + [rope(walk[0], 'left')[0], rope(walk[1], 'right')[0]] if walk else [rope(s, 'idle')[0] for s in idle]
        files[body + '-rope-Sheet.png'] = strip(ropes)
        fuses, tips = [], []
        for s in idle + lit:
            for k in range(4):
                c, tip = rope(s, 'short', k)
                fuses.append(c); tips.append(tip)
        files[body + '-fuse-Sheet.png'] = strip(fuses)
        plan[pre] = {'body': body, 'sp': sp, 'walk': bool(walk), 'tips': tips}
    return files, plan


def anims(plan):
    sys.path.insert(0, os.path.join(REPO, 'tools', 'anim'))
    from common import write, read
    old = read('enemies/bomb') or {}
    # (el ANCLA del conjunto se conserva: el usuario la ajusta en el editor para subir o bajar las bombas en el juego)
    doc = {'id': 'enemies/bomb', 'scale': old.get('scale', 4), 'origin': old.get('origin', [0.5, 1]), 'fallback': 'idle', 'frames': [], 'anims': {}}
    A = doc['anims']
    def add(fr): doc['frames'].append(fr); return len(doc['frames'])
    oy = round((PY + BH / 2) / CH, 4)                       # (el centro del cuerpo dentro de la celda de la cuerda)
    for pre, pl in plan.items():
        body, sp = pl['body'], pl['sp']
        b = [add({'image': P + body + '-Sheet.png', 'x': s['x'], 'y': s['y'], 'w': BW, 'h': BH}) for s in sp]
        nr = 4 if pl['walk'] else 2
        r = [add({'image': P + body + '-rope-Sheet.png', 'x': i * CW, 'y': 0, 'w': CW, 'h': CH, 'ox': 0.5, 'oy': oy}) for i in range(nr)]
        z = []
        for i in range(16):
            tx, ty = pl['tips'][i]
            # "tip": la punta de la mecha respecto al centro del cuerpo, en píxeles de arte (de ahí salen las chispas)
            z.append(add({'image': P + body + '-fuse-Sheet.png', 'x': i * CW, 'y': 0, 'w': CW, 'h': CH, 'ox': 0.5, 'oy': oy,
                          'tip': [tx + 0.5 - CW / 2, ty + 0.5 - (PY + BH / 2)]}))
        A[pre + 'idle'] = {'frames': [b[0], b[1]], 'durations': [2.6, 0.12], 'fps': 4, 'loop': True}        # (parpadea)
        A[pre + 'rope_idle'] = {'frames': [r[0], r[1]], 'fps': 4, 'loop': True}
        if pl['walk']:
            A[pre + 'walk'] = {'frames': [b[2], b[0], b[3], b[0]], 'fps': 9, 'loop': True}
            A[pre + 'rope_walk'] = {'frames': [r[2], r[0], r[3], r[0]], 'fps': 9, 'loop': True}
        A[pre + 'lit'] = {'frames': [b[-2], b[-1]], 'fps': 7, 'loop': True}                                 # (mira a los lados)
        for name, base in (('idle', 0), ('lit', 8)):
            for k in (1, 2):
                A['%sfuse_%s_%d' % (pre, name, k)] = {'frames': z[base + (k - 1) * 4: base + k * 4], 'fps': 14, 'loop': True}
    # la explosión: la que hubiera (tools/art/enemies/make_bomb_redesign.py)
    ex = Image.open(os.path.join(DIR, 'explosion-Sheet.png'))
    n = ex.width // 48
    e = [add({'image': P + 'explosion-Sheet.png', 'x': i * 48, 'y': 0, 'w': 48, 'h': 48}) for i in range(n)]
    A['explosion'] = {'frames': e, 'fps': n / 0.6, 'loop': False}                                           # (los 0,6 s que dura)
    write(doc, True)
    print('  assets/anim/enemies/bomb.json  (%d cuadros, %d animaciones)' % (len(doc['frames']), len(A)))


def preview(files, plan):
    """Cada bomba con su cuerda apagada y con la encendida, ×8, como se verá."""
    os.makedirs(PREVIEW, exist_ok=True)
    rows = []
    for pre, pl in plan.items():
        im = Image.open(os.path.join(DIR, pl['body'] + '-Sheet.png')).convert('RGBA')
        rp, fz = files[pl['body'] + '-rope-Sheet.png'], files[pl['body'] + '-fuse-Sheet.png']
        sp = pl['sp']
        order = [0, 1, 2, 3] if pl['walk'] else [0, 1]
        cells = []
        for i in order:                                       # apagadas
            c = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
            c.alpha_composite(im.crop((sp[i]['x'], sp[i]['y'], sp[i]['x'] + BW, sp[i]['y'] + BH)), (PX, PY))
            c.alpha_composite(rp.crop((i * CW, 0, (i + 1) * CW, CH)))
            cells.append(c)
        for j, i in enumerate([0, 1, len(sp) - 2, len(sp) - 1]):   # encendidas (un cuadro de chispa de cada)
            c = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
            c.alpha_composite(im.crop((sp[i]['x'], sp[i]['y'], sp[i]['x'] + BW, sp[i]['y'] + BH)), (PX, PY))
            c.alpha_composite(fz.crop(((j * 4 + j % 4) * CW, 0, (j * 4 + j % 4 + 1) * CW, CH)))
            cells.append(c)
        rows.append(strip(cells))
    k = 8
    out = Image.new('RGBA', (max(r.width for r in rows) * k, sum(r.height for r in rows) * k + 8), (120, 150, 200, 255))
    y = 0
    for r in rows:
        b = r.resize((r.width * k, r.height * k), Image.NEAREST)
        out.paste(b, (0, y), b); y += b.height + 8
    out.save(os.path.join(PREVIEW, 'vista_previa_cuerdas.png'))
    print('  vista previa:', os.path.join(PREVIEW, 'vista_previa_cuerdas.png'))


if __name__ == '__main__':
    files, plan = build()
    for pre, pl in plan.items():
        print('  %s-Sheet.png: %d bombas; recortes x = %s; cabo %s' % (pl['body'], len(pl['sp']), [s['x'] for s in pl['sp']],
              ['%d,%d%s' % (s['ax'], s['ay'], '' if s['stub'] else ' (sin cabo dibujado)') for s in pl['sp']]))
    preview(files, plan)
    if '--apply' in sys.argv:
        for name, img in files.items():
            img.save(os.path.join(DIR, name)); print('  ' + name, img.size)
        anims(plan)
