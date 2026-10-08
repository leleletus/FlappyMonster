#!/usr/bin/env python3
# tools/art/enemies/make_bomb_redesign.py — las BOMBAS rehechas (2026-10-08: "no parecen bombas"): bola OSCURA con
# brillo, casquillo de metal, mecha de cuerda, ojos blancos y, la que anda, botas. Escribe en
# assets/images/enemies/bomb/ (los originales, a FlappyMonster_originals la primera vez):
#   bomb-Sheet.png            15x16 x9: quieta, parpadeo, andar 1-4, a punto de estallar 1-3 (hinchada, temblando)
#   bombObject-Sheet.png      15x16 x5: el objeto (sin botas): quieta, parpadeo, a punto de estallar 1-3
#   bomb-fuse-Sheet.png / bombObject-fuse-Sheet.png   15x16 x8: la chispa de la mecha (4 cuadros) en la punta de la
#                             bomba quieta y en la de la hinchada; solo los píxeles de la chispa (va ENCIMA)
#   explosion-Sheet.png       48x48 x10: destello, bola de fuego con onda, se rompe en llamas, humo que se deshace
# y, con --anims, rehace las animaciones del conjunto assets/anim/enemies/bomb.json (cuadros, ritmo y la punta de la
# mecha "tip" de cada cuadro). Sin argumentos solo escribe la vista previa en FlappyMonster_pruebas/bombas/.
#   python3 tools/art/enemies/make_bomb_redesign.py [--apply] [--anims]
import json, math, os, random, shutil, sys
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
DIR = os.path.join(REPO, 'assets/images/enemies/bomb')
ORIG = '/home/mtvemo/FlappyMonster_originals/assets/images/enemies/bomb'
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/bombas'
FW, FH = 15, 16
K, B, D, H, W = (0, 0, 0, 255), (46, 50, 68, 255), (28, 31, 44, 255), (96, 106, 138, 255), (236, 241, 255, 255)
C, c = (178, 184, 198, 255), (112, 118, 136, 255)                 # casquillo
F, f = (176, 130, 78, 255), (124, 88, 50, 255)                    # mecha
O, o = (236, 142, 44, 255), (176, 92, 24, 255)                    # botas
E = (255, 255, 255, 255)
HOT1, HOT2 = (255, 122, 44, 255), (255, 206, 92, 255)
ROWS = {4: [5, 7, 9, 9, 9, 9, 9, 7, 5], 5: [5, 7, 9, 11, 11, 11, 11, 11, 9, 7, 5]}


def outline(img):
    """Borde negro alrededor de todo lo dibujado (como el resto de los personajes)."""
    px, w, h = img.load(), img.width, img.height
    add = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] == 0 and any(
        0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] > 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for p in add: px[p] = K


def bomb(r=4, cy=10, eyes='open', feet=None, fuse='idle', hot=0, dx=0):
    """Un cuadro. feet: None o (izq, der) = desplazamiento x de cada bota; hot 0..2 = cuánto arde por dentro."""
    img = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    px = img.load()
    cx = 7 + dx
    rows = ROWS[r]
    for i, wd in enumerate(rows):
        y = cy - r + i
        for x in range(cx - wd // 2, cx + wd // 2 + 1):
            ddx, ddy = x - cx, y - cy
            px[x, y] = D if ddx + ddy >= r else B
    # brillo arriba a la izquierda
    for p in ((cx - r + 1, cy - r + 2), (cx - r + 2, cy - r + 1)): px[p] = H
    px[cx - r + 2, cy - r + 2] = W
    if r == 5: px[cx - 4, cy - 1] = H
    # arde por dentro (a punto de estallar): la panza se enciende
    if hot:
        for x in range(cx - 2, cx + 3): px[x, cy + r - 1] = HOT1
        if hot > 1:
            for x in range(cx - 3, cx + 4): px[x, cy + r - 2] = HOT1
            for x in range(cx - 1, cx + 2): px[x, cy + r - 1] = HOT2
    # casquillo
    top = cy - r
    for x in range(cx - 1, cx + 2):
        px[x, top - 1] = C if x < cx + 1 else c
        px[x, top - 2] = C if x < cx else c
    # botas
    if feet:
        for side, off in zip((-1, 1), feet):
            x0 = cx + side * 2 + off - (1 if side < 0 else 0)
            px[x0, cy + r + 1], px[x0 + 1, cy + r + 1] = O, o
    outline(img)
    # ojos
    ey = cy - 1
    if eyes == 'open':
        for x in (cx - 2, cx + 2): px[x, ey], px[x, ey + 1] = E, E
    if eyes == 'blink':
        for x in (cx - 2, cx + 2): px[x, ey + 1] = E
    if eyes == 'panic':                       # ojos como platos, pupila pequeña
        for x0 in (cx - 3, cx + 2):
            for x in (x0, x0 + 1):
                for y in (ey - 1, ey): px[x, y] = E
        px[cx - 2, ey], px[cx + 2, ey] = K, K
    if eyes == 'panic2':
        for x0 in (cx - 3, cx + 2):
            for x in (x0, x0 + 1):
                for y in (ey - 1, ey): px[x, y] = E
        px[cx - 3, ey - 1], px[cx + 3, ey - 1] = K, K
    # mecha (cuerda de 1 px, sin borde): desde el casquillo
    path = {'idle': [(0, -3), (0, -4), (1, -5), (2, -5), (3, -6)], 'left': [(0, -3), (-1, -4), (-1, -5), (-2, -6)],
            'right': [(0, -3), (1, -4), (2, -4), (3, -5), (4, -6)], 'up': [(0, -3), (0, -4), (1, -5), (1, -6)],
            'short': [(0, -3), (1, -4), (1, -5)]}[fuse]
    tip = None
    for i, (fx, fy) in enumerate(path):
        x, y = cx + fx, top + fy + 1
        if 0 <= x < FW and 0 <= y < FH:
            px[x, y] = F if i % 2 == 0 else f
            tip = (x, y)
    return img, tip


def spark(tip, k):
    """La chispa de la mecha (4 formas): solo sus píxeles."""
    img = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    px = img.load()
    x, y = tip
    shapes = [
        {(0, 0): W, (0, 1): HOT2, (1, 0): HOT2, (-1, 0): HOT1},
        {(0, 0): HOT2, (0, -1): W, (1, 1): HOT1, (-1, 1): HOT1, (0, 1): HOT1},
        {(0, 0): W, (1, -1): HOT2, (-1, -1): HOT2, (0, 1): HOT1, (2, 0): HOT1},
        {(0, 0): HOT2, (-1, 0): W, (1, 0): HOT1, (0, -1): HOT2, (-2, -1): HOT1},
    ]
    for (dx, dy), col in shapes[k].items():
        if 0 <= x + dx < FW and 0 <= y + dy < FH: px[x + dx, y + dy] = col
    return img


def strip(frames):
    out = Image.new('RGBA', (frames[0].width * len(frames), frames[0].height), (0, 0, 0, 0))
    for i, fr in enumerate(frames): out.paste(fr, (i * frames[0].width, 0))
    return out


# ── Explosión (48x48) ──
def blobs(items, size=48):
    """items: [(x, y, r, color)] de fuera hacia dentro; con borde negro."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    px = img.load()
    for x0, y0, r, col in items:
        for y in range(size):
            for x in range(size):
                if (x - x0 + 0.5) ** 2 + (y - y0 + 0.5) ** 2 <= r * r: px[x, y] = col
    return img


def explosion():
    rnd = random.Random(11)
    RED, ORG, YEL, WHT = (196, 44, 20, 255), (244, 120, 30, 255), (255, 208, 72, 255), (255, 250, 224, 255)
    S1, S2, S3 = (120, 120, 132, 255), (86, 86, 98, 255), (58, 58, 68, 255)
    fr = []
    # 1 destello: núcleo blanco y rayos
    a = blobs([(24, 24, 7, YEL), (24, 24, 5, WHT)])
    px = a.load()
    for ang in range(0, 360, 45):
        for d in range(9, 15):
            x, y = int(24 + math.cos(math.radians(ang)) * d), int(24 + math.sin(math.radians(ang)) * d)
            px[x, y] = YEL if d < 13 else WHT
    fr.append(a)
    # 2-4 bola de fuego que crece, con lóbulos
    for R, n in ((9, 5), (14, 7), (18, 9)):
        lobes = [(24 + math.cos(i * 6.283 / n + 0.4) * R * 0.55, 24 + math.sin(i * 6.283 / n + 0.4) * R * 0.55, R * 0.62) for i in range(n)]
        items = [(x, y, r, RED) for x, y, r in lobes] + [(24, 24, R * 0.86, RED)]
        items += [(x, y, r - 2, ORG) for x, y, r in lobes] + [(24, 24, R * 0.86 - 2, ORG), (24, 24, R * 0.6, YEL), (24, 24, R * 0.32, WHT)]
        b = blobs(items); outline(b); fr.append(b)
    # 5 la bola se rompe: llamas sueltas y el primer humo dentro
    lobes = [(24 + math.cos(i * 6.283 / 8) * 13, 24 + math.sin(i * 6.283 / 8) * 13, 6.5) for i in range(8)]
    b = blobs([(x, y, r, RED) for x, y, r in lobes] + [(x, y, r - 2, ORG) for x, y, r in lobes] + [(x, y, r - 4, YEL) for x, y, r in lobes]
              + [(24, 24, 9, S2), (24, 24, 7, S1)])
    outline(b); fr.append(b)
    # 6 anillo de humo con brasas
    ring = [(24 + math.cos(i * 6.283 / 7 + 0.2) * 14, 24 + math.sin(i * 6.283 / 7 + 0.2) * 14, 6) for i in range(7)]
    b = blobs([(x, y, r, S2) for x, y, r in ring] + [(x - 1, y - 1, r - 2, S1) for x, y, r in ring]
              + [(24 + math.cos(i * 2.1) * 8, 24 + math.sin(i * 2.1) * 8, 1.6, ORG) for i in range(3)])
    outline(b); fr.append(b)
    # 7-10 el humo se abre y se deshace
    for R, r0, n, col in ((16, 5, 7, (S2, S1)), (18, 4, 6, (S3, S2)), (20, 3, 5, (S3, S2)), (21, 2, 4, (S3, S3))):
        puffs = [(24 + math.cos(i * 6.283 / n + R) * (R + rnd.uniform(-2, 2)), 24 + math.sin(i * 6.283 / n + R) * (R + rnd.uniform(-2, 2)), r0 + rnd.uniform(-0.6, 0.6)) for i in range(n)]
        b = blobs([(x, y, r, col[0]) for x, y, r in puffs] + [(x - 0.5, y - 0.5, max(0.8, r - 1.6), col[1]) for x, y, r in puffs])
        outline(b); fr.append(b)
    return fr


def build():
    sheets, tips = {}, {}
    # la bomba que anda
    walk = [bomb(feet=(-1, 1), fuse='idle'), bomb(cy=9, feet=(0, 0), fuse='left'), bomb(feet=(1, -1), fuse='idle'), bomb(cy=9, feet=(0, 0), fuse='right')]
    lit = [bomb(r=5, eyes='panic', fuse='short', hot=1), bomb(r=5, eyes='panic2', fuse='short', hot=2, dx=1), bomb(r=5, eyes='panic', fuse='short', hot=2, dx=-1)]
    body = [bomb(feet=(0, 0)), bomb(feet=(0, 0), eyes='blink')] + walk + lit
    sheets['bomb-Sheet.png'] = strip([b[0] for b in body]); tips['bomb'] = [b[1] for b in body]
    # el objeto: sin botas, un píxel más abajo
    olit = [bomb(r=5, eyes='panic', fuse='short', hot=1), bomb(r=5, eyes='panic2', fuse='short', hot=2, dx=1), bomb(r=5, eyes='panic', fuse='short', hot=2, dx=-1)]
    obj = [bomb(cy=11), bomb(cy=11, eyes='blink')] + olit
    sheets['bombObject-Sheet.png'] = strip([b[0] for b in obj]); tips['object'] = [b[1] for b in obj]
    sheets['bomb-fuse-Sheet.png'] = strip([spark(body[0][1], k) for k in range(4)] + [spark(lit[0][1], k) for k in range(4)])
    sheets['bombObject-fuse-Sheet.png'] = strip([spark(obj[0][1], k) for k in range(4)] + [spark(olit[0][1], k) for k in range(4)])
    sheets['explosion-Sheet.png'] = strip(explosion())
    return sheets, tips


def anims(tips):
    """Rehace el conjunto enemies/bomb (cuadros y animaciones) para estas hojas."""
    sys.path.insert(0, os.path.join(REPO, 'tools', 'anim'))
    from common import write
    P = 'assets/images/enemies/bomb/'
    doc = {'id': 'enemies/bomb', 'scale': 4, 'origin': [0.5, 1], 'fallback': 'idle', 'frames': [], 'anims': {}}
    def cut(file, n, w, h, tp=None):
        first = len(doc['frames'])
        for i in range(n):
            fr = {'image': P + file, 'x': i * w, 'y': 0, 'w': w, 'h': h}
            if tp: fr['tip'] = list(tp[i])
            doc['frames'].append(fr)
        return [first + i + 1 for i in range(n)]
    A = doc['anims']
    b = cut('bomb-Sheet.png', 9, FW, FH, tips['bomb'])
    A['idle'] = {'frames': [b[0], b[1]], 'durations': [2.6, 0.12], 'fps': 4, 'loop': True}          # (parpadea)
    A['walk'] = {'frames': b[2:6], 'fps': 9, 'loop': True}
    A['lit'] = {'frames': [b[6], b[7], b[6], b[8]], 'fps': 16, 'loop': True}                          # (tiembla)
    ob = cut('bombObject-Sheet.png', 5, FW, FH, tips['object'])
    A['object_idle'] = {'frames': [ob[0], ob[1]], 'durations': [3.1, 0.12], 'fps': 4, 'loop': True}
    A['object_lit'] = {'frames': [ob[2], ob[3], ob[2], ob[4]], 'fps': 16, 'loop': True}
    fz = cut('bomb-fuse-Sheet.png', 8, FW, FH)
    A['fuse_idle'] = {'frames': fz[0:4], 'fps': 14, 'loop': True}; A['fuse_lit'] = {'frames': fz[4:8], 'fps': 14, 'loop': True}
    oz = cut('bombObject-fuse-Sheet.png', 8, FW, FH)
    A['object_fuse_idle'] = {'frames': oz[0:4], 'fps': 14, 'loop': True}; A['object_fuse_lit'] = {'frames': oz[4:8], 'fps': 14, 'loop': True}
    ex = cut('explosion-Sheet.png', 10, 48, 48)
    A['explosion'] = {'frames': ex, 'fps': 10 / 0.6, 'loop': False}                                   # (los 0,6 s que dura)
    write(doc, True)
    print('  assets/anim/enemies/bomb.json  (%d cuadros, %d animaciones)' % (len(doc['frames']), len(A)))


if __name__ == '__main__':
    sheets, tips = build()
    os.makedirs(PREVIEW, exist_ok=True)
    k = 8
    h = sum(s.height * (k if s.height < 40 else 3) + 8 for s in sheets.values())
    prev = Image.new('RGBA', (max(s.width * (k if s.height < 40 else 3) for s in sheets.values()), h), (120, 150, 200, 255))
    y = 0
    for s in sheets.values():
        z = k if s.height < 40 else 3
        b = s.resize((s.width * z, s.height * z), Image.NEAREST)
        prev.paste(b, (0, y), b); y += b.height + 8
    prev.save(os.path.join(PREVIEW, 'vista_previa.png'))
    print('  vista previa:', os.path.join(PREVIEW, 'vista_previa.png'))
    if '--apply' in sys.argv:
        os.makedirs(ORIG, exist_ok=True)
        for name, s in sheets.items():
            dst = os.path.join(ORIG, name[:-4] + '-orig.png')
            if not os.path.exists(dst): shutil.copy(os.path.join(DIR, name), dst)
            s.save(os.path.join(DIR, name)); print('  ' + name, s.size)
    if '--anims' in sys.argv: anims(tips)
