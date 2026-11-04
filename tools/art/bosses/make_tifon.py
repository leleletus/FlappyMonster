#!/usr/bin/env python3
# tools/art/bosses/make_tifon.py — TIFÓN, el Soplón Supremo: jefe secreto de la fortaleza (docs/design/tifon.md).
# Es el Soplón (gust) de la fortaleza crecido al tocar una astilla: una nube de tormenta gigante que SOPLA todo el
# tejado, lo ASPIRA hacia su boca, suelta RAYOS y GRANIZO. La astilla es la punta de la flecha de su VELETA, que lleva
# encima como un sombrero y que gira con el viento (avisa hacia dónde va a soplar).
#
# Ronda 2 (2026-11-04, el usuario): "el A pero con la colita del C": la forma de Remolino (cabeza de nube sobre una
# cola de tornado) con los colores de Nubarrón y la cabeza más ancha, como la del A. Y MENOS DENSIDAD DE PÍXELES: la
# ronda 1 era x5 y quedaba fuera de lugar (el jugador es x6, los Mega x9-10). Ahora el arte va a MITAD de resolución
# (un píxel nuevo = 2x2 de antes) y se enseña a x10 (opción 1: el mismo tamaño en pantalla) y a x6 / x8 (opción 2:
# más pequeño, el píxel del jugador). La ronda 1 (cuatro aspectos a x5) está en la historia de git.
#
#   python3 tools/art/bosses/make_tifon.py             → vista_previa.png, piezas.png, comunes.png, pelea_x<k>.gif + .mp4
#   python3 tools/art/bosses/make_tifon.py --still     → sin los GIF
#
# Estilo (docs/art/style-rules.md): contorno = el tono más oscuro de su propio color, luz arriba a la izquierda, sombra
# abajo a la derecha, 3-4 tonos planos, sin ruido. El cuerpo es un montón de BOLLITOS (como el Soplón pequeño); cada
# bollito de delante deja un pliegue oscuro sobre el de detrás: así se lee como nube y no como mancha.
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'tifon')
PLAYER_K, SMALL_K = 6, 4
SCALES = (10, 8, 6)                 # (las escalas que se enseñan: 10 = opción 1, 6 / 8 = opción 2)
Q = 0.5                             # (la geometría de la ronda 1, a mitad de resolución)


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def load(rel):
    return Image.open(os.path.join(ROOT, rel)).convert('RGBA')


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


try:
    FONT = ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans.ttf', 15)
    FONT_B = ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans-Bold.ttf', 20)
except Exception:
    FONT = FONT_B = None


def text(d, xy, s, fill=(255, 255, 255, 255), font=None):
    f = font or FONT
    d.text((xy[0] + 1, xy[1] + 1), s, fill=(0, 0, 0, 255), font=f); d.text(xy, s, fill=fill, font=f)


# ── colores ───────────────────────────────────────────────────────────────────────────────────────────────────────
GLOW = ('ffe14a', 'fff6c0')                     # el rayo dentro de la nube (medio, núcleo)
BOMBGLOW = ('ff8a28', 'ffd23c')
BRASS = ('4a2c0c', '9a6418', 'd09a2c', 'f4d870')                    # la veleta: latón (contorno, sombra, medio, luz)
GLASS = ('2a6a9a', 'a8e8ff', 'ffffff')                              # la astilla (como las otras del juego)
GLASS_O = '1c4a6e'
# el hollín del A (Nubarrón) en la cabeza; la cola, del mismo gris, un tono más clara para que se separe
L = dict(name='Tifón', pal=('16161e', '34343f', '545462', '84849a'), eye='f0e6c8', mouth='0c0c12',
         funnel=('16161e', '3e3e4a', '62626f', '8e8ea2'))

FRAMES = ['idle1', 'idle2', 'warn', 'blow1', 'blow2', 'inhale1', 'inhale2', 'gulp', 'boom', 'cough', 'charge',
          'spin1', 'spin2', 'spin3', 'spin4', 'stun1', 'stun2']
FW, FH = 46, 44                                  # cuadro (arte); el centro del cuerpo en (CX, CY)
CX, CY = 23, 21


# ══ EL CUERPO: bollitos (en las unidades de la ronda 1; se multiplican por Q) ═══════════════════════════════════════
HEAD = [(-25, -2, 8, 6.5), (-15, -9, 11, 9.5), (1, -13, 13, 11), (16, -8, 10, 9), (26, -1, 7.5, 6),
        (-3, -1, 17, 8.5), (14, 1, 10, 6.5)]
FACE = (-5, -5)
VANE = (2, -23)


def puffs_for(f):
    """→ (bollitos [(x, y, rx, ry, capa)] en arte relativo a (CX, CY), cara, ancla de la veleta). capa: 'b' cabeza ·
    'f' cola · 'k' moflete"""
    inf = {'warn': 1.05, 'blow1': 0.97, 'blow2': 0.93, 'inhale1': 1.04, 'inhale2': 1.08, 'gulp': 1.12, 'boom': 1.16,
           'cough': 0.96, 'charge': 1.02}.get(f, 1.0)
    bob = 1 if f in ('idle2', 'stun2') else 0
    sag = f.startswith('stun')
    spinning = f.startswith('spin')
    spin = {'spin1': 0, 'spin2': 1, 'spin3': 2, 'spin4': 3}.get(f, 0)
    blowpush = {'blow1': 1.0, 'blow2': 2.0}.get(f, 0.0)
    out, depth = [], []
    for i, (x, y, rx, ry) in enumerate(HEAD):
        x, y, rx, ry = x * inf, y * inf, rx * inf, ry * inf
        if spinning:                                                   # gira sobre un eje vertical: cada bollito tiene
            z = 0 if rx >= 15 else ((i * 37) % 11 - 5) * 3.5           # una profundidad inventada y orbita con el resto
            a = math.radians(spin * 90)
            x, z = x * math.cos(a) - z * math.sin(a), x * math.sin(a) + z * math.cos(a)
            depth.append(z)
        if blowpush and x < -6: x += blowpush * 2                      # (al soplar, la cara se echa atrás)
        if sag: y = y * 0.7 + 13; ry *= 0.8; rx *= 1.06
        y += bob * (i % 2) * 2
        out.append((x, y, rx, ry, 'b'))
    if spinning: out = [p for _, p in sorted(zip(depth, out), key=lambda q: q[0])]
    # la cola de tornado: elipses que se estrechan y se mecen (en el giro, la fase corre)
    ph = {'idle1': 0, 'idle2': 0.6, 'spin1': 0, 'spin2': 1.6, 'spin3': 3.2, 'spin4': 4.8, 'blow1': 0.3,
          'blow2': 0.9}.get(f, 0.2)
    n = 7 if not sag else 3
    tail = []
    for i in range(n):
        fy = 5 + i * 4.6 * (0.6 if sag else 1)
        fx = math.sin(ph + i * 0.9) * (1 + i * 0.9) + 3
        if sag: fy += 10
        tail.append((fx, fy, 11 - i * 1.3, 3.2, 'f'))
    out = tail[::-1] + out
    fx, fy = FACE
    if sag: fy = fy * 0.7 + 13
    else: fx, fy = fx * inf, fy * inf + (bob * 2 if False else 0)
    vx, vy = VANE
    vy = vy * 0.7 + 13 if sag else vy * inf
    sc = lambda p: (p[0] * Q, p[1] * Q, p[2] * Q, p[3] * Q, p[4])
    return [sc(p) for p in out], (fx * Q, fy * Q), (vx * Q, vy * Q)


def body_art(f):
    """→ imagen del cuerpo (sin veleta), y anclas: cara, veleta"""
    puffs, face, vane_ = puffs_for(f)
    tone = [[None] * FW for _ in range(FH)]           # (rampa, índice de tono)
    own = [[-1] * FW for _ in range(FH)]
    for i, (x, y, rx, ry, part) in enumerate(puffs):
        rp = L['funnel'] if part == 'f' else L['pal']
        cx, cy = CX + x, CY + y
        for Y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for X in range(int(cx - rx - 1), int(cx + rx + 2)):
                if not (0 <= X < FW and 0 <= Y < FH): continue
                nx, ny = (X + .5 - cx) / rx, (Y + .5 - cy) / ry
                if nx * nx + ny * ny > 1: continue
                nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
                Lt = -0.45 * nx - 0.65 * ny + 0.62 * nz
                t = 3 if Lt > 0.8 else (1 if Lt < 0.2 else 2)
                if part == 'f' and t == 3: t = 2                              # (la cola: sin brillo, sólo su raya)
                tone[Y][X] = (rp, t)
                own[Y][X] = i
        # pliegue: el borde de arriba / delante de este bollito sobre los de detrás (un trazo, no un marco)
        for Y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for X in range(int(cx - rx - 1), int(cx + rx + 2)):
                if not (0 <= X < FW and 0 <= Y < FH) or own[Y][X] != i: continue
                for ax, ay in ((-1, 0), (0, -1)) if part != 'k' else ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nX, nY = X + ax, Y + ay
                    if 0 <= nX < FW and 0 <= nY < FH and own[nY][nX] not in (-1, i):
                        tone[Y][X] = (rp, 1 if part != 'k' else 0)
                        break
    im = Image.new('RGBA', (FW, FH))
    for Y in range(FH):
        for X in range(FW):
            if tone[Y][X]:
                rp, t = tone[Y][X]
                im.putpixel((X, Y), hx(rp[t]))
    a = im.getchannel('A')                                             # contorno exterior: el tono más oscuro
    for Y in range(FH):
        for X in range(FW):
            if a.getpixel((X, Y)): continue
            for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nX, nY = X + ax, Y + ay
                if 0 <= nX < FW and 0 <= nY < FH and a.getpixel((nX, nY)):
                    im.putpixel((X, Y), hx(L['pal'][0])); break
    d = Dots(im)
    fx, fy = int(round(CX + face[0])), int(round(CY + face[1]))
    if f == 'charge': crackle(d, im, seed=3)
    if f == 'boom': crackle(d, im, seed=5, col=BOMBGLOW)
    if f == 'gulp':
        for X, Y in disc(CX + 3, CY + 1, 2.4, 1.8): d.put(X, Y, BOMBGLOW[0])
        d.put(CX + 3, CY + 1, BOMBGLOW[1])
    if f not in ('spin2', 'spin3', 'spin4'): draw_face(d, f, fx, fy)    # (de lado o de espaldas: sin cara)
    return im, (fx, fy), (CX + vane_[0], CY + vane_[1])


class Dots:
    def __init__(self, im): self.im = im
    def put(self, x, y, c, a=255):
        x, y = int(x), int(y)
        if 0 <= x < self.im.width and 0 <= y < self.im.height: self.im.putpixel((x, y), hx(c)[:3] + (a,))


def disc(cx, cy, rx, ry):
    for Y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for X in range(int(cx - rx - 1), int(cx + rx + 2)):
            if ((X + .5 - cx) / rx) ** 2 + ((Y + .5 - cy) / ry) ** 2 <= 1: yield X, Y


def ring(cx, cy, rx, ry, w=1.0):
    inner = set(disc(cx, cy, max(0.5, rx - w), max(0.5, ry - w)))
    for p in disc(cx, cy, rx, ry):
        if p not in inner: yield p


def crackle(d, im, seed, col=GLOW):
    """grietas de luz dentro de la nube (rayo que se carga, o la bomba que revienta dentro): 3 zigzags cortos"""
    rnd = random.Random(seed)
    for k in range(2 if col == BOMBGLOW else 3):
        x, y = CX + rnd.randint(-10, 10), CY + rnd.randint(-7, 2)
        for s in range(5):
            if not (0 <= x < FW and 0 <= y < FH) or im.getpixel((int(x), int(y)))[3] == 0: break
            d.put(x, y, col[1] if s == 0 else col[0])
            x += rnd.choice((-1, 1)); y += 1


# ── la cara a esta resolución: píxel a píxel (las formas geométricas no se leen tan pequeñas) ─────────────────────
def draw_face(d, f, fx, fy):
    """ojos de 3x2 con ceja y la boca, mirando a la IZQUIERDA (el juego voltea)"""
    o, s, b, h = L['pal']
    e, m = L['eye'], L['mouth']
    stun = f.startswith('stun') or f == 'boom'
    for side in (-1, 1):
        cx, cy = fx + side * 4 - (1 if side < 0 else 0), fy          # (esquina izquierda de un ojo de 4x3)
        if stun:                                                       # aspas 3x3
            for a, c in ((0, 0), (2, 0), (1, 1), (0, 2), (2, 2)): d.put(cx + a, cy + c, e)
            continue
        # ceja de enfado (4 px): baja hacia el centro de la cara
        brow = ((-1, -2), (0, -2), (1, -1), (2, -1), (3, -1)) if side < 0 else ((0, -1), (1, -1), (2, -1), (3, -2), (4, -2))
        for a, c in brow: d.put(cx + a, cy + c, m)
        if f in ('warn', 'cough'):                                     # apretados
            for a in range(4): d.put(cx + a, cy + 1, m)
            continue
        wide = f in ('gulp', 'inhale2')
        glow = f == 'charge'
        pts = [(a, 0) for a in range(4)] + [(a, 1) for a in range(4)] + [(1, 2), (2, 2)]
        if wide: pts += [(0, 2), (3, 2)]
        for a, c in pts: d.put(cx + a, cy + c, GLOW[0] if glow else e)
        if glow: d.put(cx + 1, cy + 1, 'ffffff'); d.put(cx + 2, cy + 1, 'ffffff')
        elif wide: d.put(cx + 1, cy + 1, m)                            # (asombrado: pupila de 1)
        else:
            for a, c in ((0, 1), (1, 1), (1, 2)): d.put(cx + a, cy + c, m)      # pupila en L: delante y abajo
    mx, my = fx - 1, fy + 5                                            # la boca: delante y abajo
    if f.startswith('stun'): my -= 1
    if f in ('idle1', 'idle2', 'spin1'):
        for a, c in ((-2, 1), (-1, 0), (0, 0), (1, 0), (2, 1)): d.put(mx + a, my + c, m)
    elif f == 'warn':
        for X, Y in ring(mx + .5, my + .5, 1.6, 1.6): d.put(X, Y, o)
        d.put(mx, my, m)
    elif f in ('blow1', 'blow2'):
        r = 2.2 if f == 'blow1' else 2.7
        for X, Y in disc(mx + .5, my + .5, r + 1, r + 1): d.put(X, Y, o)
        for X, Y in disc(mx + .5, my + .5, r, r): d.put(X, Y, m)
        d.put(mx - 1, my - 2, h) if f == 'blow2' else None
    elif f in ('inhale1', 'inhale2', 'boom'):
        rx, ry = (3.2, 2.8) if f == 'inhale1' else (4.6, 4.0)
        for X, Y in disc(mx + 1, my + 1.5, rx + 1, ry + 1): d.put(X, Y, o)
        for X, Y in disc(mx + 1, my + 1.5, rx, ry): d.put(X, Y, m)
        if f == 'inhale2':                                             # el remolino de dentro: una espiral de 5 píxeles
            for a, c in ((0, 0), (1, 0), (2, 1), (1, 2), (-1, 1)): d.put(mx + a, my + 1 + c, s)
        elif f == 'boom':
            for X, Y in disc(mx + 1, my + 1.5, rx - 1.5, ry - 1.5): d.put(X, Y, BOMBGLOW[0])
            d.put(mx + 1, my + 1, BOMBGLOW[1]); d.put(mx, my + 2, BOMBGLOW[1])
    elif f == 'gulp':
        for a in range(-2, 3): d.put(mx + a, my, m)
    elif f == 'cough':
        for X, Y in disc(mx + .5, my + .5, 2.6, 1.8): d.put(X, Y, o)
        d.put(mx, my, m); d.put(mx + 1, my, m)
    elif f == 'charge':                                                # dientes que chisporrotean
        for a in range(-2, 4): d.put(mx + a, my - 1, o); d.put(mx + a, my + 1, o); d.put(mx + a, my, GLOW[1] if a % 2 else o)
    elif f.startswith('stun'):                                         # boca ondulada
        for a in range(-2, 4): d.put(mx + a, my + (a % 2), m)


# ══ LA VELETA (capa suelta: el juego la gira), píxel a píxel ════════════════════════════════════════════════════════
# o b h s = latón (contorno, medio, luz, sombra) · O W L D = la astilla (contorno, blanco, claro, oscuro)
MAST = [".......obs.......", ".......obs.......", ".......obs.......",
        "....oooobsooo....", "...obbbbbbbbbo...", "....oooobsooo....",
        ".......obs.......", ".......obs.......", "......obbbso....."]
VANE_L = [
    "............o....",
    "...........oho...",
    "..........ohbo...",
    "..OO.....ohbbo...",
    ".OWLooooohbbso...",
    "OWLLhhhhhhhhhho..",
    ".ODDoooobsoooo...",
    "..OO...obs.......",
] + MAST
VANE_F = [
    "........o........",
    ".......oho.......",
    "......ohso.......",
    "......ohso.......",
    "......OWLDO......",
    "......OLDDO......",
    ".......OOO.......",
    ".......obs.......",
] + MAST
VW, VH = 17, len(VANE_L)                         # (17 de ancho con el mástil en el centro: volteada no se mueve)
VBASE = (8, VH - 1)                              # el pie de la veleta (se clava en la nube)


def vane(state='L', flash=False, empty=False):
    """state: L (la flecha apunta a la izquierda) · R · F (de canto, girando). La astilla es la punta de la flecha."""
    rows = VANE_F if state == 'F' else VANE_L
    col = {'o': BRASS[0], 's': BRASS[1], 'b': BRASS[2], 'h': BRASS[3],
           'O': GLASS_O, 'W': GLASS[2], 'L': GLASS[1], 'D': GLASS[0]}
    if empty: col.update({'O': '16161c', 'W': '34343e', 'L': '24242c', 'D': '24242c'})
    im = Image.new('RGBA', (VW, VH))
    for y, r in enumerate(rows):
        for x, c in enumerate(r[:VW]):
            if c != '.': im.putpixel((x, y), hx(col[c]))
    if state == 'R': im = im.transpose(Image.FLIP_LEFT_RIGHT)          # (el mástil, en el centro, no se mueve)
    if flash:
        r, g_, bb, a = im.split(); w = Image.new('L', im.size, 255); im = Image.merge('RGBA', (w, w, w, a))
    return im


def icon(with_tip=True):
    """icono de la Colección (17x13): la flecha de la veleta con su aleta y la astilla de punta (la veleta en pequeño)"""
    im = Image.new('RGBA', (17, 13))
    d = Dots(im)
    o, s_, b, h = BRASS
    ay = 8
    for x in range(5, 16): d.put(x, ay - 1, o); d.put(x, ay, b); d.put(x, ay + 1, o)          # el astil
    for a in range(9, 15):                                                                    # la aleta
        top = ay - 2 - (a - 9) if a < 13 else ay - 6
        for y in range(top, ay): d.put(a, y, h if y == top else (s_ if a == 14 else b))
        d.put(a, top - 1, o)
    for y in range(ay - 7, ay + 2): d.put(15, y, o)
    for y in range(ay + 2, 13): d.put(9, y, o); d.put(10, y, b); d.put(11, y, o)              # el pie del mástil
    tipc = (GLASS_O, GLASS[0], GLASS[1], GLASS[2]) if with_tip else ('16161c', '24242c', '24242c', '34343e')
    for k, x in enumerate(range(0, 5)):                                                       # la astilla
        hw = (k + 1) // 2
        for c in range(-hw, hw + 1):
            col = tipc[3] if c < 0 and k > 1 else (tipc[1] if c > 0 else tipc[2])
            if k == 0: col = tipc[3]
            d.put(x + 1, ay + c, col)
        d.put(x + 1, ay - hw - 1, tipc[0]); d.put(x + 1, ay + hw + 1, tipc[0])
    d.put(0, ay, tipc[0])
    return im


# ══ EFECTOS comunes ═══════════════════════════════════════════════════════════════════════════════════════════════
def streak(i, warn=False):
    """la racha de viento (24x8, a x4): 3 cuadros; warn = el aviso (rayitas finas y discontinuas)"""
    im = Image.new('RGBA', (24, 8)); d = Dots(im)
    rows = ((2, i * 3, 14), (5, (i * 7 + 5) % 24, 10))
    for row, x0, ln in rows:
        for a in range(ln):
            if warn and a % 3 == 2: continue
            x = (x0 + a) % 24
            d.put(x, row, 'ffffff', 230 if a > 2 else 140) if not warn else d.put(x, row, 'd8e2f0', 170)
        if not warn:
            d.put((x0 + ln) % 24, row - 1, 'ffffff', 160)                       # la colita que se riza
    return im


def mark(i):
    """la marca del rayo en el tejado (16x6, x4): chispitas → cruz que brilla"""
    im = Image.new('RGBA', (16, 6)); d = Dots(im)
    pts = [(7, 3), (8, 3), (6, 2), (9, 2), (5, 4), (10, 4), (4, 1), (11, 1), (3, 5), (12, 5), (7, 1), (8, 5)]
    n = (4, 8, 12)[i]
    for k, (x, y) in enumerate(pts[:n]): d.put(x, y, GLOW[1] if k < 2 else GLOW[0], 255 if i == 2 or k < 4 else 180)
    return im


def bolt(i):
    """el rayo (16x40, x4, se repite en vertical): 2 cuadros de zigzag con núcleo blanco y halo amarillo"""
    im = Image.new('RGBA', (16, 40)); d = Dots(im)
    rnd = random.Random(10 + i)
    x = 8
    path = []
    for y in range(40):
        if y % 5 == 0: x = max(4, min(11, x + rnd.choice((-2, -1, 1, 2))))
        path.append((x, y))
    for x, y in path:
        for a in (-2, 2): d.put(x + a, y, GLOW[0], 150)
        d.put(x - 1, y, GLOW[0]); d.put(x + 1, y, GLOW[0]); d.put(x, y, 'ffffff')
    return im


def arc(i):
    """el rayo encadenado entre chimeneas (32x12, x4)"""
    im = Image.new('RGBA', (32, 12)); d = Dots(im)
    rnd = random.Random(20 + i)
    y = 6
    for x in range(32):
        if x % 4 == 0: y = max(2, min(9, y + rnd.choice((-2, -1, 1, 2))))
        d.put(x, y - 1, GLOW[0]); d.put(x, y + 1, GLOW[0]); d.put(x, y, 'ffffff')
    return im


def hail(i):
    """granizo (8x8, x4): 2 cuadros cayendo, 2 haciéndose añicos"""
    im = Image.new('RGBA', (8, 8)); d = Dots(im)
    ice = ('3c6a9c', 'a8cce8', 'e8f4ff', 'ffffff')
    if i < 2:
        for X, Y in disc(4, 4.5, 2.6, 2.6): d.put(X, Y, ice[2])
        for X, Y in ring(4, 4.5, 2.6, 2.6): d.put(X, Y, ice[0])
        d.put(3, 3, ice[3]); d.put(5, 5, ice[1])
        if i == 1: d.put(4, 0, ice[2], 120); d.put(4, 1, ice[2], 160)
    else:
        k = i - 2
        for x, y in ((2 - k, 5 - k), (6 + k, 4 - k), (4, 6 - k), (1 - k, 7), (7 + k, 7)):
            d.put(x, y, ice[2]); d.put(x + 1, y, ice[0])
    return im


def scorch():
    """la teja chamuscada donde cayó el rayo (16x4, x4)"""
    im = Image.new('RGBA', (16, 4)); d = Dots(im)
    for x in range(2, 14):
        d.put(x, 1 + (x % 3 == 0), '1a1418', 200)
        if 4 <= x <= 11: d.put(x, 2, '2a2024', 220)
    return im


# ══ LA ESCENA: los tejados de la fortaleza bajo la tormenta (sólo para previas) ════════════════════════════════════
STORM = ['262c3c', '2e3446', '363e52', '40485e', '4a546c']


def roofs(w, h):
    """cielo de tormenta + murallas lejanas + tejado de piedra con chimeneas"""
    bg = Image.new('RGBA', (w, h), hx(STORM[0]))
    d = ImageDraw.Draw(bg)
    band = h // len(STORM)
    for i, c in enumerate(STORM): d.rectangle((0, i * band, w, (i + 1) * band + 4), fill=hx(c))
    for name, y, dark in (('fortress_far', h - 64 - 130 * 4 + 120, 0.45), ('fortress_mid', h - 64 - 400, 0.55)):
        lay = load(f'assets/images/world/sky/{name}.png')
        lay = Image.eval(lay, lambda v: v)
        r, g, b, a = lay.split()
        r = r.point(lambda v: int(v * dark)); g = g.point(lambda v: int(v * dark)); b = b.point(lambda v: int(v * dark + 14))
        lay = up(Image.merge('RGBA', (r, g, b, a)), 4)
        for x in range(0, w, lay.width): bg.alpha_composite(lay, (x, y))
    gy = h - 64
    stone = load('assets/images/world/tiles/stone.png')
    for x in range(0, w, 64):
        bg.alpha_composite(stone.crop((x % 128 // 64 * 64, 0, x % 128 // 64 * 64 + 64, 64)), (x, gy))
    chim = []
    for cx in (96, w - 160):
        for k in range(2):
            bg.alpha_composite(stone.crop((64, 64, 128, 128)), (cx, gy - 64 * (k + 1)))
        d.rectangle((cx - 6, gy - 128 - 12, cx + 70, gy - 128), fill=hx('3a3a46'))
        d.rectangle((cx - 6, gy - 128 - 12, cx + 70, gy - 128 - 10), fill=hx('5c5c6c'))
        chim.append(cx)
    return bg, gy, chim


def player():
    return up(load('assets/images/player/monstrito1.png'), PLAYER_K)


def bomb(i=0):
    im = load('assets/images/enemies/bomb/bombObject-Sheet.png').crop((1, 0, 14, 16))
    return up(im, SMALL_K)


BOOM = load('assets/images/enemies/bomb/explosion-Sheet.png')
STARS = load('assets/images/bosses/common/stars-Sheet.png')


def boom(i):
    return up(BOOM.crop((i * 48, 0, i * 48 + 48, 48)), 3)


def stars(i):
    hh = STARS.height; n = STARS.width // hh
    return up(STARS.crop((i % n * hh, 0, i % n * hh + hh, hh)), 5)


# ══ KIT: todas las piezas a una escala ═════════════════════════════════════════════════════════════════════════════
class Kit:
    def __init__(self, k):
        self.k = k
        self.art, self.face, self.vane_at = {}, {}, {}
        for f in FRAMES:
            self.art[f], self.face[f], self.vane_at[f] = body_art(f)
        self.body = {f: up(a, k) for f, a in self.art.items()}
        self.vanes = {s: up(vane(s), k) for s in 'LRF'}

    def draw(self, c, f, x, y, vstate='L', flip=False, hit=False):
        """x, y = el centro del cuerpo en pantalla → la boca en pantalla"""
        K = self.k
        b = self.body[f]
        v = self.vanes[vstate]
        if flip: b = b.transpose(Image.FLIP_LEFT_RIGHT)
        if hit:
            r, g, bb, a = b.split(); wv = Image.new('L', b.size, 255); b = Image.merge('RGBA', (wv, wv, wv, a))
        ox, oy = int(x - CX * K), int(y - CY * K)
        vx, vy = self.vane_at[f]
        if flip: vx = FW - 1 - vx
        c.alpha_composite(v, (int(ox + round(vx) * K - VBASE[0] * K), int(oy + round(vy) * K - VBASE[1] * K + 2 * K)))
        c.alpha_composite(b, (ox, oy))
        fx, fy = self.face[f]
        if flip: fx = FW - 1 - fx
        return (ox + fx * K, oy + (fy + 6) * K)

    def bbox(self, f):
        return self.art[f].getbbox()

    def floor_y(self, f, gy):
        """el centro del cuerpo para que el cuadro f se apoye en el suelo gy"""
        return gy - (self.bbox(f)[3] - CY) * self.k + self.k


def overview(kits):
    show = ['idle1', 'warn', 'blow2', 'inhale2', 'gulp', 'charge', 'spin2', 'stun1']
    cw, ch = 420, 640
    W = 220 + cw * len(show)
    H = 60 + ch * len(kits)
    cv = Image.new('RGBA', (W, H), hx('1a1c24'))
    d = ImageDraw.Draw(cv)
    text(d, (16, 14), 'TIFÓN — ronda 2: Remolino con los colores de Nubarrón, a MITAD de resolución; '
                      'el mismo arte a x10 / x8 / x6 (jugador x6, sobre los tejados)', font=FONT_B)
    for r, K_ in enumerate(kits):
        bg, gy, _ = roofs(cw, ch - 20)
        y0 = 60 + r * ch
        text(d, (16, y0 + 10), f'x{K_.k}', font=FONT_B)
        note = {10: 'opción 1: el mismo tamaño que la ronda 1, píxeles el doble de grandes',
                8: 'opción 2 (media): más pequeño',
                6: 'opción 2: el píxel del jugador'}[K_.k]
        yy = y0 + 40
        for line in wrap(note, 22):
            text(d, (16, yy), line); yy += 20
        bb = K_.bbox('idle1')
        text(d, (16, yy + 10), f'idle: {(bb[2] - bb[0]) * K_.k}x{(bb[3] - bb[1]) * K_.k} px')
        text(d, (16, yy + 30), f'arte: {bb[2] - bb[0]}x{bb[3] - bb[1]}')
        for i, f in enumerate(show):
            cell = bg.copy()
            cell.alpha_composite(player(), (30, gy - 96))
            yc = K_.floor_y(f, gy) if f.startswith('stun') else gy - 40 - 18 * K_.k
            K_.draw(cell, f, cw // 2 + 40, yc, vstate='F' if f.startswith(('spin', 'stun')) else 'L')
            if f.startswith('stun'):
                cell.alpha_composite(stars(0), (cw // 2 + 40 - 25, yc - 12 * K_.k - 40))
            cv.alpha_composite(cell, (220 + i * cw, y0))
            text(d, (220 + i * cw + 8, y0 + 4), f)
    return cv


def wrap(s, n):
    out, cur = [], ''
    for w in s.split():
        if len(cur) + len(w) + 1 > n: out.append(cur); cur = w
        else: cur = (cur + ' ' + w).strip()
    return out + [cur]


def parts_sheet():
    """todos los cuadros a x8 con su nombre (el arte de verdad, píxel a píxel)"""
    s = 8
    cols = 6
    cw, ch = FW * s + 10, (FH + 10) * s + 30
    cv = Image.new('RGBA', (cw * cols, ch * ((len(FRAMES) + cols - 1) // cols) + 40), hx('4a546c'))
    d = ImageDraw.Draw(cv)
    text(d, (8, 8), f'Tifón — los {len(FRAMES)} cuadros del cuerpo ({FW}x{FH}, x{s}; la veleta es una capa aparte)', font=FONT_B)
    for i, f in enumerate(FRAMES):
        x, y = (i % cols) * cw, 40 + (i // cols) * ch
        v = up(vane('F' if f.startswith(('spin', 'stun')) else 'L'), s)
        vx, vy = body_art(f)[2]
        y += 10 * s
        cv.alpha_composite(v, (int(x + round(vx) * s - VBASE[0] * s), int(y + round(vy) * s - VBASE[1] * s + 2 * s)))
        cv.alpha_composite(up(body_art(f)[0], s), (x, y))
        text(d, (x + 4, y + FH * s + 4), f)
    return cv


def common_sheet():
    s = 6
    cv = Image.new('RGBA', (1300, 640), hx('363e52'))
    d = ImageDraw.Draw(cv)
    text(d, (10, 8), 'TIFÓN — piezas comunes: veleta (x10) L / R / de frente / sin astilla · icono de la Colección · efectos (x6)', font=FONT_B)
    x = 10
    for st, em in (('L', False), ('R', False), ('F', False), ('L', True)):
        cv.alpha_composite(up(vane(st, empty=em), 10), (x, 40)); x += VW * 10 + 16
    cv.alpha_composite(up(icon(True), s), (x, 60)); cv.alpha_composite(up(icon(False), s), (x, 60 + 13 * s + 10))
    y = 250
    x = 10
    for i in range(3): cv.alpha_composite(up(streak(i), s), (x, y)); x += 24 * s + 10
    for i in range(3): cv.alpha_composite(up(streak(i, warn=True), s), (x, y)); x += 24 * s + 10
    y = 320; x = 10
    for i in range(3): cv.alpha_composite(up(mark(i), s), (x, y)); x += 16 * s + 10
    cv.alpha_composite(up(scorch(), s), (x, y)); x += 16 * s + 20
    for i in range(4): cv.alpha_composite(up(hail(i), s), (x, y - 10)); x += 8 * s + 10
    y = 380; x = 10
    for i in range(2): cv.alpha_composite(up(bolt(i), s), (x, y)); x += 16 * s + 10
    for i in range(2): cv.alpha_composite(up(arc(i), s), (x, y + 60)); x += 32 * s + 10
    text(d, (10, 220), 'racha (3) · aviso (3)')
    text(d, (10, 300 - 0), '')
    return cv


# ══ GIF: un trozo de pelea (soplo → aspira la bomba encendida → revienta dentro → aturdido → rayos) ═══════════════
def fight_gif(K_, path):
    W, H = 1100, 680
    bg, gy, chim = roofs(W, H)
    rnd = random.Random(1)
    frames, durs, ev = [], [], []
    cue = lambda n: ev.append((sum(durs) / 1000, n))
    hx_, hy = 760, gy - 40 - 18 * K_.k
    bm_at = K_.draw(bg.copy(), 'boom', hx_, hy)
    pl = player()
    bm = bomb()
    parts = [(rnd.randint(0, W), rnd.randint(60, gy - 20), rnd.randint(0, 2)) for _ in range(26)]

    def shot(f, px, py, vst='L', extra=None, wind=0, warn=False, boss=None, dur=110, hit=False):
        c = bg.copy()
        if warn:
            for k in range(8):
                im = up(streak(k % 3, warn=True), 4)
                c.alpha_composite(im, ((k * 137) % (W - 100), 80 + (k * 61) % (gy - 140)))
        if wind:
            for (x, y, i) in parts:
                im = up(streak((i + len(frames)) % 3), 4)
                xx = (x - len(frames) * 38 * wind) % W if wind > 0 else (x + len(frames) * 30) % W
                c.alpha_composite(im, (int(xx), y))
        bx, by = boss or (hx_, hy)
        K_.draw(c, f, bx, by, vstate=vst, hit=hit)
        c.alpha_composite(pl, (int(px), int(py)))
        if extra: extra(c)
        frames.append(c.convert('RGB').convert('P', palette=Image.ADAPTIVE)); durs.append(dur)

    px = 300
    cue('roar')
    for i in range(6): shot('idle1' if i % 4 < 2 else 'idle2', px, gy - 96)
    cue('vane'); cue('warn')
    for i in range(9): shot('warn', px, gy - 96, warn=True)
    cue('blow')
    for i in range(28):
        px = max(chim[0] + 64, px - 9) if True else px
        shot('blow1' if i % 2 else 'blow2', px, gy - 96, wind=1, dur=90)
    for i in range(3): shot('idle1', px, gy - 96)
    # aspira: la bomba encendida vuela hacia la boca
    mouth = None
    c0 = bg.copy()
    mouth = K_.draw(c0, 'inhale2', hx_, hy)
    cue('inhale')
    for i in range(20):
        t = min(1, i / 17)
        bx0, by0 = px + 40, gy - 140
        bx = bx0 + (mouth[0] - bx0) * t
        by = by0 + (mouth[1] - by0) * t - math.sin(t * math.pi) * 120
        def ex(c, bx=bx, by=by):
            if t < 1 and True: c.alpha_composite(bm, (int(bx - 26), int(by - 32)))
            c.alpha_composite(up(Image.new('RGBA', (2, 2), hx('ffd23c')), 4), (int(bx + (i % 2) * 4), int(by - 36)))
        shot('inhale1' if i < 6 else 'inhale2', px, gy - 96, wind=-1, extra=ex, dur=100)
    cue('gulp')
    for i in range(4): shot('gulp', px, gy - 96, dur=120)
    cue('boom')
    for i in range(5):
        shot('boom', px, gy - 96, extra=lambda c, i=i: c.alpha_composite(boom(min(9, i * 2)), (bm_at[0] - 72, bm_at[1] - 72)), dur=90)
    # se desploma sobre el tejado, aturdido
    bbs = K_.bbox('stun1')
    sy = K_.floor_y('stun1', gy)
    top = sy + (bbs[1] - CY) * K_.k
    cue('dizzy')
    for i in range(6):
        y = hy + (sy - hy) * (i + 1) / 6
        shot('stun1', px, gy - 96, vst='F', boss=(hx_, y), dur=80)
    for i in range(12):
        jx = px + (hx_ - px) * min(1, i / 7)
        jy = gy - 96 - math.sin(min(1, i / 7) * math.pi) * 260 if i < 7 else top - 92
        hit = i in (8, 9)
        if i == 8: cue('hit')
        shot('stun1' if i % 2 else 'stun2', jx - 20, jy, vst='F', boss=(hx_, sy), hit=hit,
             extra=lambda c, i=i: c.alpha_composite(stars(i), (hx_ - 25, top - 60)), dur=100)
    # vuelve a subir, gira, carga el rayo
    cue('spin'); cue('vane')
    for i in range(6):
        y = sy + (hy - sy) * (i + 1) / 6
        shot('spin%d' % (i % 4 + 1), 300, gy - 96, vst='LFRF'[i % 4], boss=(hx_, y), dur=90)
    targets = [200, 420, 600]
    cue('charge')
    for i in range(10):
        def ex(c, i=i):
            for tx in targets: c.alpha_composite(up(mark(min(2, i // 4)), 4), (tx, gy - 18))
        shot('charge', 300, gy - 96, extra=ex, dur=100)
    cue('thunder')
    for i in range(4):
        def ex(c, i=i):
            for tx in targets:
                b = up(bolt(i % 2), 4)
                for yy in range(hy + 40, gy - 20, b.height): c.alpha_composite(b, (tx, yy))
                c.alpha_composite(up(scorch(), 4), (tx, gy - 6))
        shot('charge', 300, gy - 96, extra=ex, dur=80)
    for i in range(10):
        if i in (1, 3, 4, 7): cue('hail')
        shot('idle1' if i % 4 < 2 else 'idle2', 300, gy - 96)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=durs, loop=0)
    return ev, sum(durs) / 1000


def video(gif, ev, total, path):
    """el GIF con los sonidos en su sitio (tools/sounds/tifon.py, previas): para juzgar el momento de cada uno"""
    import subprocess, wave
    import numpy as np
    sys.path.insert(0, os.path.join(ROOT, 'tools', 'sounds'))
    import tifon as TS
    snd = TS.sounds()
    snd['hit'] = TS.thud(300, 120, 0.2, 0.05)
    sr = TS.SR
    mix = np.zeros(int(sr * (total + 3)))
    for at, n in ev:
        x = snd[n] / (np.abs(snd[n]).max() + 1e-9) * (0.5 if n in ('hail', 'vane') else 0.8)
        i = int(at * sr); mix[i:i + len(x)] += x[:len(mix) - i]
    mix = mix[:int(sr * total)] / max(1.0, np.abs(mix).max())
    wav = path[:-4] + '.wav'
    with wave.open(wav, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes((mix * 32000).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', gif, '-i', wav, '-movflags', 'faststart', '-pix_fmt', 'yuv420p',
                    '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2', '-c:v', 'libx264', '-c:a', 'aac', '-shortest', path], check=True)
    os.remove(wav)


def main():
    os.makedirs(OUT, exist_ok=True)
    kits = [Kit(k) for k in SCALES]
    overview(kits).save(os.path.join(OUT, 'vista_previa.png'))
    parts_sheet().save(os.path.join(OUT, 'piezas.png'))
    common_sheet().save(os.path.join(OUT, 'comunes.png'))
    if '--still' not in sys.argv:
        for K_ in kits:
            if K_.k == 8: continue
            g = os.path.join(OUT, f'pelea_x{K_.k}.gif')
            ev, total = fight_gif(K_, g)
            video(g, ev, total, os.path.join(OUT, f'pelea_x{K_.k}_con_sonido.mp4'))
    print('  ' + OUT)


if __name__ == '__main__':
    main()
