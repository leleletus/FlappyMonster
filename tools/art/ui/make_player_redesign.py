#!/usr/bin/env python3
# tools/art/ui/make_player_redesign.py
# Rediseño del monstruito (el jugador) y por tanto del Espejo (mismos sprites con
# los colores invertidos + sus piezas de risa), como el de los Crabbies/Gummies:
# la MISMA forma (cada píxel), estilo nuevo:
#   negro  → azul marino muy oscuro; donde el cuerpo es grueso (tronco), un filo
#            un poco más claro arriba-izquierda (volumen sin perder la silueta)
#   blanco → la cara: brillo arriba-izquierda y sombra a la derecha / abajo
#   --rim  → variante B: además un borde fino azul claro SOLO por fuera de la silueta
#            (los huecos de 1-2 px entre brazos y piernas no se rellenan)
#   --mix  → la ELEGIDA: mezcla de A y D (cuerpo casi negro con el filo de volumen de A)
#   --black→ variante D: cuerpo NEGRO puro como el original; solo la cara cambia
#   --light→ variante C: cuerpo gris azulado algo más claro, sin borde (se distingue
#            un poco de los fondos oscuros sin cambiar la silueta)
#   python3 tools/art/ui/make_player_redesign.py <carpeta> [--rim]   vista previa
#   python3 tools/art/ui/make_player_redesign.py --apply [--rim]     al juego (originales fuera del repo)
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib'))   # (originals.py)
import originals   # noqa: E402

APPLY = '--apply' in sys.argv
RIM = '--rim' in sys.argv
LIGHT = '--light' in sys.argv
BLACK = '--black' in sys.argv          # variante D: el cuerpo sigue NEGRO puro; solo la cara cambia
MIX = '--mix' in sys.argv              # la ELEGIDA (mezcla de A y D): casi negro + el filo de volumen de A
OUT = next((a for a in sys.argv[1:] if not a.startswith('--')), '/tmp/player_redesign')
SRC = 'assets/images/'

NAVY, NAVY_L = (30, 30, 42, 255), (58, 60, 84, 255)
W, H, S = (242, 242, 246, 255), (255, 255, 255, 255), (196, 200, 214, 255)
RIMC = (92, 100, 140, 255)

FILES = ['player/monstrito1.png', 'player/monstrito2.png', 'player/monstrito3.png', 'player/monstrito4.png',
         'player/monstrito5.png', 'player/icon.png', 'player/dedais.png',
         'bosses/mirror/Body_ArmsDown.png', 'bosses/mirror/Body_ArmsUp.png', 'bosses/mirror/Head_Down.png',
         'bosses/mirror/Head_Up.png', 'bosses/mirror/JoyEyes.png']
NO_RIM = {'player/icon.png', 'player/dedais.png', 'bosses/mirror/JoyEyes.png'}   # (HUD / dibujados encima)


def src(rel):
    o = originals.path(SRC + rel)
    return o if os.path.exists(o) else SRC + rel


def outer_rim(out, w, h):
    """Borde por fuera de la silueta: se cierra la máscara (huecos pequeños) y el
    borde solo va donde el exterior (alcanzable desde fuera) toca la figura."""
    op = [[out.getpixel((x, y))[3] > 0 for x in range(w)] for y in range(h)]
    def dil(m):
        return [[any(0 <= x + dx < w and 0 <= y + dy < h and m[y + dy][x + dx] for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                 for x in range(w)] for y in range(h)]
    def ero(m):
        return [[all((0 <= x + dx < w and 0 <= y + dy < h and m[y + dy][x + dx]) or not (0 <= x + dx < w and 0 <= y + dy < h)
                     for dx in (-1, 0, 1) for dy in (-1, 0, 1)) for x in range(w)] for y in range(h)]
    closed = ero(dil(op))
    closed = [[closed[y][x] or op[y][x] for x in range(w)] for y in range(h)]
    res = out.copy()
    for y in range(h):
        for x in range(w):
            if closed[y][x]: continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and closed[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                res.putpixel((x, y), (RIMC[0], RIMC[1], RIMC[2], 200))
    return res


def restyle(rel, rim=False, light=False, black_body=False, mix=False):
    im = Image.open(src(rel)).convert('RGBA')
    w, h = im.size
    at = lambda x, y: im.getpixel((x, y)) if 0 <= x < w and 0 <= y < h else (0, 0, 0, 0)
    black = lambda x, y: at(x, y)[3] > 0 and at(x, y)[:3] != (255, 255, 255)
    white = lambda x, y: at(x, y)[3] > 0 and at(x, y)[:3] == (255, 255, 255)
    rows = {}
    for y in range(h):
        wx = [x for x in range(w) if white(x, y)]
        if wx: rows[y] = (min(wx), max(wx))
    ys = sorted(rows)
    xs = [x for y in rows for x in rows[y]]
    cx = (min(xs) + max(xs)) / 2 if xs else w / 2
    body, bodyL = ((52, 56, 78, 255), (78, 84, 112, 255)) if light else (NAVY, NAVY_L)
    if black_body: body = bodyL = (0, 0, 0, 255)
    if mix: body, bodyL = (12, 12, 20, 255), (50, 52, 74, 255)
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            if black(x, y):
                c = body
                # filo claro en lo grueso: arriba-izquierda de una zona de 2x2 negra
                if black(x + 1, y) and black(x, y + 1) and black(x + 1, y + 1) and \
                        (not black(x, y - 1) or not black(x - 1, y)):
                    c = bodyL
                out.putpixel((x, y), c)
            elif white(x, y):
                x0, x1 = rows[y]
                c = W
                if x == x1 or (y == ys[-1] and x >= cx): c = S
                elif y == ys[0] and x <= x0 + 1: c = H
                out.putpixel((x, y), c)
    if rim: out = outer_rim(out, w, h)
    return out


if __name__ == '__main__':
    if APPLY:
        print('Rediseño del monstruito y del Espejo (originales fuera del repo):')
        for rel in FILES:
            originals.keep(SRC + rel)
            im = restyle(rel, RIM and rel not in NO_RIM, LIGHT, BLACK, MIX)
            im.save(SRC + rel)
            print('  %-42s %dx%d' % (SRC + rel, im.width, im.height))
        sys.exit(0)
    for variant, rim, light, blk in (('A', False, False, False), ('C', False, True, False), ('D', False, False, True)):
        d = os.path.join(OUT, variant)
        os.makedirs(d, exist_ok=True)
        for rel in FILES:
            restyle(rel, rim and rel not in NO_RIM, light, blk).save(os.path.join(d, os.path.basename(rel)))
    print('PRUEBA en', OUT)
