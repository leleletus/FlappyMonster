#!/usr/bin/env python3
# tools/art/bosses/make_tifon.py — TIFÓN, el Soplón Supremo: jefe secreto de la fortaleza (docs/design/tifon.md).
# Es el Soplón (gust) de la fortaleza crecido al tocar una astilla: una nube de tormenta gigante que SOPLA todo el
# tejado, lo ASPIRA hacia su boca, suelta RAYOS y GRANIZO. La astilla es la punta de la flecha de su VELETA, que lleva
# encima como un sombrero y que gira con el viento (avisa hacia dónde va a soplar).
# Ronda 1: cuatro aspectos para elegir (previas, nada se escribe en assets/).
#
#   python3 tools/art/bosses/make_tifon.py             → vista_previa.png, piezas_<A-D>.png, comunes.png, pelea_<A-D>.gif
#   python3 tools/art/bosses/make_tifon.py --still     → sin los GIF
#   python3 tools/art/bosses/make_tifon.py --look A    → solo ese aspecto en los GIF
#
# Estilo (docs/art/style-rules.md): contorno = el tono más oscuro de su propio color, luz arriba a la izquierda, sombra
# abajo a la derecha, 3-4 tonos planos, sin ruido. El cuerpo es un montón de BOLLITOS (como el Soplón pequeño); cada
# bollito de delante deja un pliegue oscuro sobre el de detrás: así se lee como nube y no como mancha.
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'tifon')
PLAYER_K, SMALL_K, K = 6, 4, 5


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


# ── colores comunes ───────────────────────────────────────────────────────────────────────────────────────────────
GLOW = ('ffe14a', 'fff6c0')                     # el rayo dentro de la nube (medio, núcleo)
BOMBGLOW = ('ff8a28', 'ffd23c')
BRASS = ('4a2c0c', '9a6418', 'd09a2c', 'f4d870')                    # la veleta: latón (contorno, sombra, medio, luz)
GLASS = ('2a6a9a', 'a8e8ff', 'ffffff')                              # la astilla (como las otras del juego)

# (contorno, sombra, cuerpo, luz, ojos, pupila/boca, mejillas, embudo opcional)
LOOKS = {
    'A': dict(name='Nubarrón', pal=('16161e', '34343f', '545462', '84849a'), eye='f0e6c8', mouth='0c0c12',
              cheek='7a5a66', note='el Soplón de hollín crecido: un cúmulo ancho y bajo, base plana'),
    'B': dict(name='Yunque', pal=('141a28', '2e3a54', '4a5878', '7e8eb0'), eye='fff0a0', mouth='0a0e18',
              cheek='6a5a80', top=('2e3a54', '7e8eb0', 'a8b8d4', 'd8e2f0'),
              note='un cumulonimbo: tronco oscuro y un yunque claro y plano arriba; cara en el vientre'),
    'C': dict(name='Remolino', pal=('18201e', '36443f', '56665f', '8a9c92'), eye='e8f4c8', mouth='0a100e',
              cheek='6a6a5a', funnel=('18201e', '3e4c46', '6a7a72', '9aaca2'),
              note='cabeza de nube sobre una cola de tornado que barre el tejado'),
    'D': dict(name='Fuelle', pal=('1e1428', '3e2e52', '5e4a7a', '8e7aaa'), eye='f6e8ff', mouth='100818',
              cheek='9a5a8a', note='una bola de tormenta con dos mofletes enormes: el «dios del viento»'),
}

FRAMES = ['idle1', 'idle2', 'warn', 'blow1', 'blow2', 'inhale1', 'inhale2', 'gulp', 'boom', 'cough', 'charge',
          'spin1', 'spin2', 'spin3', 'spin4', 'stun1', 'stun2']
FW, FH = 84, 84                                  # cuadro (arte); el centro del cuerpo en (42, 46)
CX, CY = 42, 46


# ══ EL CUERPO: bollitos ═══════════════════════════════════════════════════════════════════════════════════════════
def puffs_for(lid, f):
    """→ (bollitos [(x, y, rx, ry, capa)], cosas de la cara {eyes, mouth, face}, ancla de la veleta, base plana o None)
    capa: 'b' cuerpo · 't' yunque (B) · 'f' embudo (C). Todo en arte relativo a (CX, CY)."""
    inf = {'warn': 1.06, 'blow1': 0.97, 'blow2': 0.93, 'inhale1': 1.05, 'inhale2': 1.1, 'gulp': 1.14, 'boom': 1.2,
           'cough': 0.96, 'charge': 1.02}.get(f, 1.0)
    bob = {'idle2': 1, 'blow2': 0, 'stun1': 0, 'stun2': 1}.get(f, 0)
    sag = f.startswith('stun')
    spin = {'spin1': 4, 'spin2': 1, 'spin3': 2, 'spin4': 3}.get(f, 0) % 4
    spinning = f.startswith('spin')
    blowpush = {'blow1': 1.0, 'blow2': 2.0}.get(f, 0.0)
    if lid == 'A':
        base = [(-21, 7, 9, 7), (-27, 10, 6, 5), (-11, -1, 12, 11), (5, -6, 13, 12), (19, 1, 10, 9), (27, 8, 7, 6),
                (-4, 7, 15, 8), (12, 8, 11, 7)]
        face = (-6, 3); vane = (5, -18); flat = 14
    elif lid == 'B':
        base = [(-1, 13, 13, 9), (-7, 3, 11, 10), (6, -1, 11, 10), (0, -10, 12, 8)]
        top = [(-14, -20, 12, 5), (14, -21, 13, 5), (0, -22, 18, 6), (-24, -19, 7, 3), (25, -20, 7, 3)]
        face = (-4, 6); vane = (2, -27); flat = 20
    elif lid == 'C':
        base = [(-12, -8, 10, 9), (2, -13, 12, 10), (14, -6, 9, 8), (-2, -2, 14, 8), (-20, -2, 6, 5), (20, 0, 6, 5)]
        face = (-5, -6); vane = (2, -24); flat = None
    else:
        base = [(-12, -10, 9, 8), (8, -12, 10, 9), (-1, 1, 20, 17), (17, 2, 7, 7)]
        face = (-4, -1); vane = (-1, -24); flat = None
    cheeks = f in ('warn', 'gulp') or (lid == 'D' and f in ('inhale1', 'inhale2', 'idle1', 'idle2', 'charge'))
    out, depth = [], []
    for i, (x, y, rx, ry) in enumerate(base):
        x, y, rx, ry = x * inf, y * inf, rx * inf, ry * inf
        if spinning:                                                   # gira sobre un eje vertical: cada bollito tiene
            z = 0 if rx >= 15 else ((i * 37) % 11 - 5) * {'A': 4.6, 'B': 1.4, 'C': 3.5, 'D': 3.0}[lid]                              # una profundidad inventada y orbita con el resto
            a = math.radians(spin * 90)
            x, z = x * math.cos(a) - z * math.sin(a), x * math.sin(a) + z * math.cos(a)
            depth.append(z)
        if blowpush and x < -6: x += blowpush                          # (al soplar, la cara se echa atrás)
        if sag:
            y = y * 0.7 + 8; ry *= 0.78; rx *= 1.06
        y += bob * (1 if i % 2 else -0) + (1 if f == 'idle2' and i % 3 == 0 else 0)
        out.append((x, y, rx, ry, 'b'))
    if spinning:                                                       # los de detrás se pintan antes
        out = [p for _, p in sorted(zip(depth, out), key=lambda q: q[0])]
    if lid == 'B':
        for i, (x, y, rx, ry) in enumerate(top):
            if spin:
                x = x * (1, 0.82, 1, 0.82)[spin]
            if sag: y = y * 0.7 + 8; ry *= 0.8
            out.append((x * inf, y * inf + bob, rx * inf, ry * inf, 't'))
    if lid == 'C':
        ph = {'idle1': 0, 'idle2': 0.6, 'spin1': 0, 'spin2': 1.6, 'spin3': 3.2, 'spin4': 4.8, 'blow1': 0.3, 'blow2': 0.9}.get(f, 0.2)
        n = 7 if not sag else 4
        for i in range(n):
            t = i / 6
            fy = 4 + i * 4.6 * (0.7 if sag else 1)
            fx = math.sin(ph + i * 0.9) * (1 + i * 0.9) + 3
            out.insert(0, (fx, fy, 10.5 - i * 1.25, 3.0, 'f'))
    if cheeks:
        fx, fy = face
        s = 1.25 if f == 'warn' or lid == 'D' and f in ('inhale1', 'inhale2') else (1.4 if f == 'gulp' else 1.0)
        out.append((fx - 13, fy + 8, 5.5 * s, 4.5 * s, 'k'))
        out.append((fx + 12, fy + 8, 5.5 * s, 4.5 * s, 'k'))
    fx, fy = face
    if sag: fy = fy * 0.7 + 8
    vx, vy = vane
    if sag: vy = vy * 0.7 + 8
    vy = vy * (inf if not sag else 1) + bob
    if flat is not None and sag: flat = flat * 0.7 + 8
    return out, (fx * (inf if not sag else 1), fy * (inf if not sag else 1) + bob), (vx, vy), (flat * inf if flat else None)


def ramp(L, part):
    o, s, b, h = L['pal']
    if part == 't': return L['top']
    if part == 'f': return L['funnel']
    return L['pal']


def body_art(lid, f):
    """→ imagen del cuerpo (sin veleta), y anclas: cara, veleta"""
    L = LOOKS[lid]
    puffs, face, vane, flat = puffs_for(lid, f)
    tone = [[None] * FW for _ in range(FH)]           # (rampa, índice de tono)
    own = [[-1] * FW for _ in range(FH)]
    for i, (x, y, rx, ry, part) in enumerate(puffs):
        rp = ramp(L, part if part != 'k' else 'b')
        cx, cy = CX + x, CY + y
        for Y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for X in range(int(cx - rx - 1), int(cx + rx + 2)):
                if not (0 <= X < FW and 0 <= Y < FH): continue
                if flat is not None and part != 'f' and Y >= CY + flat: continue
                nx, ny = (X + .5 - cx) / rx, (Y + .5 - cy) / ry
                if nx * nx + ny * ny > 1: continue
                nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
                Lt = -0.45 * nx - 0.65 * ny + 0.62 * nz
                t = 3 if Lt > 0.78 else (1 if Lt < 0.18 else 2)
                if part == 'f':                                           # (el embudo: rayas en espiral)
                    if (X + Y * 2 + i) % 7 < 2: t = 1
                tone[Y][X] = (rp, t)
                own[Y][X] = i
        # pliegue: el borde de este bollito sobre los de detrás
        for Y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for X in range(int(cx - rx - 1), int(cx + rx + 2)):
                if not (0 <= X < FW and 0 <= Y < FH) or own[Y][X] != i: continue
                for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nX, nY = X + ax, Y + ay
                    if 0 <= nX < FW and 0 <= nY < FH and own[nY][nX] not in (-1, i):
                        if ay < 0 or ax < 0 or part == 'k':                # (solo arriba / delante: un trazo, no un marco)
                            tone[Y][X] = (rp, 1 if part != 'k' else 0)
                        break
    im = Image.new('RGBA', (FW, FH))
    pal0 = L['pal'][0]
    for Y in range(FH):
        for X in range(FW):
            if tone[Y][X]:
                rp, t = tone[Y][X]
                im.putpixel((X, Y), hx(rp[t]))
    # contorno exterior: el tono más oscuro
    a = im.getchannel('A')
    for Y in range(FH):
        for X in range(FW):
            if a.getpixel((X, Y)): continue
            for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nX, nY = X + ax, Y + ay
                if 0 <= nX < FW and 0 <= nY < FH and a.getpixel((nX, nY)):
                    im.putpixel((X, Y), hx(pal0)); break
    d = Dots(im)
    fx, fy = CX + face[0], CY + face[1]
    if f == 'charge': crackle(d, im, L, seed=3)
    if f == 'boom': crackle(d, im, L, seed=5, col=BOMBGLOW)
    if f == 'gulp':
        for X, Y in disc(CX + 4, CY + 2, 4.5, 3.5): d.put(X, Y, BOMBGLOW[0]) if im.getpixel((X, Y))[3] else None
        for X, Y in disc(CX + 4, CY + 2, 2.2, 1.6): d.put(X, Y, BOMBGLOW[1])
    if f in ('spin2', 'spin3', 'spin4'): pass                        # (de lado o de espaldas: sin cara)
    else: draw_face(d, L, f, int(fx), int(fy), lid)
    return im, (fx, fy), (CX + vane[0], CY + vane[1])


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


def crackle(d, im, L, seed, col=GLOW):
    """grietas de luz dentro de la nube (rayo que se carga, o la bomba que revienta dentro)"""
    rnd = random.Random(seed)
    for k in range(4):
        x, y = CX + rnd.randint(-18, 18), CY + rnd.randint(-10, 8)
        for s in range(9):
            if not (0 <= x < FW and 0 <= y < FH) or im.getpixel((int(x), int(y)))[3] == 0: break
            d.put(x, y, col[1] if s % 3 == 0 else col[0])
            x += rnd.choice((-1, 1)); y += rnd.choice((0, 1, 1))


def line(d, x0, y0, x1, y1, c, w=1):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n):
        t = i / max(1, n - 1)
        x, y = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
        for k in range(w): d.put(x, y + k, c)


def draw_face(d, L, f, fx, fy, lid):
    """ojos y boca, mirando a la IZQUIERDA (el juego voltea). Ojos de 7x5 con ceja gruesa; la boca según el gesto"""
    o, s, b, h = L['pal']
    e, m = L['eye'], L['mouth']
    gap = 8
    for side in (-1, 1):
        ex, ey = fx + side * gap, fy
        # ceja: baja hacia el centro de la cara (enfado); aturdido, arriba y lisa
        if f.startswith('stun') or f == 'boom':
            line(d, ex - 3, ey - 5, ex + 3, ey - 5, o, 2)
            for k in range(-2, 3):                                     # aspas de 5x5, 2 px de grueso
                d.put(ex + k, ey + k, e); d.put(ex + k + 1, ey + k, e)
                d.put(ex + k, ey - k, e); d.put(ex + k + 1, ey - k, e)
            continue
        if side < 0: line(d, ex - 4, ey - 5, ex + 3, ey - 3, o, 2)
        else: line(d, ex - 3, ey - 3, ex + 4, ey - 5, o, 2)
        if f in ('cough', 'warn'):                                     # apretados
            line(d, ex - 3, ey, ex + 3, ey, o, 2)
            continue
        glow = f == 'charge'
        wide = f in ('gulp', 'inhale2')
        rx, ry = (3.8, 3.2) if wide else (3.6, 2.4)
        for X, Y in disc(ex + .5, ey + .5, rx, ry): d.put(X, Y, GLOW[1] if glow else e)
        if glow:
            for X, Y in disc(ex + .5, ey + .5, rx - 1.2, ry - 1): d.put(X, Y, 'ffffff')
        elif wide: d.put(ex - 1, ey, m); d.put(ex - 1, ey + 1, m)
        else:
            for X, Y in disc(ex - 0.6, ey + 1.0, 1.7, 1.5): d.put(X, Y, m)   # pupila delante y abajo
    mx, my = fx - 3, fy + (6 if f.startswith('stun') else 9)          # la boca: delante y abajo
    if f in ('idle1', 'idle2', 'spin1', 'spin2', 'spin3'):
        line(d, mx - 4, my + 1, mx - 2, my - 1, o, 2); line(d, mx - 2, my - 1, mx + 3, my - 1, o, 2); line(d, mx + 3, my - 1, mx + 5, my + 1, o, 2)
    elif f == 'warn':
        for X, Y in disc(mx, my, 3.2, 3.2): d.put(X, Y, o)
        for X, Y in disc(mx, my, 1.4, 1.4): d.put(X, Y, m)
    elif f in ('blow1', 'blow2'):
        r = 4.4 if f == 'blow1' else 5.0
        for X, Y in disc(mx, my, r + 1.2, r + 1.2): d.put(X, Y, o)
        for X, Y in disc(mx, my, r, r): d.put(X, Y, m)
        for X, Y in ring(mx - 0.4, my - 0.4, r + 0.6, r + 0.6):
            if X < mx and Y < my: d.put(X, Y, h)                        # el labio, con luz arriba
    elif f in ('inhale1', 'inhale2', 'boom'):
        rx, ry = (7, 6) if f == 'inhale1' else (9.5, 8)
        for X, Y in disc(mx + 1, my + 2, rx + 1.2, ry + 1.2): d.put(X, Y, o)
        for X, Y in disc(mx + 1, my + 2, rx, ry): d.put(X, Y, m)
        if f != 'boom':                                                # el remolino de dentro
            for k in range(3):
                for X, Y in ring(mx + 1, my + 2, rx - 1.5 - k * 2.4, ry - 1.5 - k * 2.0):
                    if (math.atan2(Y - my - 2, X - mx - 1) * 3 + k) % 2.2 < 0.8: d.put(X, Y, s)
        else:
            for X, Y in disc(mx + 1, my + 2, rx - 3, ry - 3): d.put(X, Y, BOMBGLOW[0])
            for X, Y in disc(mx + 1, my + 2, rx - 6, ry - 5.5): d.put(X, Y, BOMBGLOW[1])
    elif f == 'gulp':
        line(d, mx - 4, my, mx + 5, my, o, 2)
        d.put(mx - 5, my - 1, o); d.put(mx + 6, my - 1, o)
    elif f == 'cough':
        for X, Y in disc(mx + 1, my + 1, 5.2, 3.8): d.put(X, Y, o)
        for X, Y in disc(mx + 1, my + 1, 4, 2.6): d.put(X, Y, m)
    elif f == 'charge':                                                # dientes apretados que chisporrotean
        for X, Y in disc(mx + 1, my + 1, 6.5, 3.2): d.put(X, Y, o)
        for a in range(-4, 6):
            for c in (0, 1): d.put(mx + 1 + a, my + c, GLOW[1] if a % 2 else GLOW[0])
    elif f.startswith('stun'):                                         # boca ondulada
        for a in range(-5, 7): d.put(mx + a, my + (a % 4 in (1, 2)), o); d.put(mx + a, my + 1 + (a % 4 in (1, 2)), o)


# ══ LA VELETA (capa suelta: el juego la gira) ═════════════════════════════════════════════════════════════════════
VW, VH = 27, 22
VBASE = (13, 21)                                  # el pie de la veleta (se clava en la nube)
GLASS_O = '1c4a6e'


def vane(state='L', flash=False, empty=False):
    """state: L (la flecha apunta a la izquierda) · R · F (de frente, girando). La astilla es la punta de la flecha;
    la cola es una aleta de latón que sube (la que coge el viento)."""
    im = Image.new('RGBA', (VW, VH))
    d = Dots(im)
    o, s, b, h = BRASS
    bx, by = VBASE
    for y in range(by - 11, by + 1):                                     # el mástil (2 px + contorno)
        d.put(bx - 1, y, o); d.put(bx, y, h if y % 4 == 0 else b); d.put(bx + 1, y, s); d.put(bx + 2, y, o)
    cy = by - 5                                                           # la cruz, corta, con bolitas
    for x in range(bx - 5, bx + 7):
        if bx - 1 <= x <= bx + 2: continue
        d.put(x, cy - 1, o); d.put(x, cy, b); d.put(x, cy + 1, o)
    for x in (bx - 6, bx + 7):
        for X, Y in disc(x + .5, cy + .5, 1.6, 1.6): d.put(X, Y, o)
        d.put(x, cy, b); d.put(x, cy - 1 + 0, b)
    for X, Y in disc(bx + 1, by - 11.5, 2.2, 2.2): d.put(X, Y, o)         # la bola de arriba
    for X, Y in disc(bx + 1, by - 11.5, 1.3, 1.3): d.put(X, Y, b)
    d.put(bx, by - 12, h)
    ay = by - 14
    tipc = (GLASS_O, GLASS[0], GLASS[1], GLASS[2]) if not empty else ('16161c', '24242c', '24242c', '34343e')
    if state == 'F':
        for y in range(ay - 6, ay + 1): d.put(bx, y, b); d.put(bx + 1, y, s)     # la aleta de canto
        d.put(bx - 1, ay - 6, o); d.put(bx + 2, ay - 6, o)
        for y in range(ay - 6, ay + 1): d.put(bx - 1, y, o); d.put(bx + 2, y, o)
        for X, Y, c in ((bx - 1, ay + 1, 0), (bx, ay + 1, 2), (bx + 1, ay + 1, 1), (bx + 2, ay + 1, 0),
                        (bx - 1, ay + 2, 0), (bx, ay + 2, 3), (bx + 1, ay + 2, 2), (bx + 2, ay + 2, 0)): d.put(X, Y, tipc[c])
    else:
        g = -1 if state == 'L' else 1                                     # hacia donde apunta
        X = lambda a: bx + (a if g < 0 else 1 - a)                        # (a: coordenada con la punta a la izquierda)
        for a in range(-6, 8):                                            # el astil
            d.put(X(a), ay - 1, o); d.put(X(a), ay, b); d.put(X(a), ay + 1, o)
        # la aleta: un trapecio que sube detrás (de a=2 a a=9)
        for a in range(2, 10):
            top = ay - 2 - (a - 2) if a < 7 else ay - 7
            for y in range(top, ay):
                d.put(X(a), y, h if y == top else (s if a == 9 else b))
            d.put(X(a), top - 1, o)
        for y in range(ay - 8, ay + 2): d.put(X(10), y, o)
        # la punta: la astilla, un triángulo de cristal de 6 px
        for k, a in enumerate(range(-12, -6)):
            hw = (k + 1) // 2
            for c in range(-hw, hw + 1):
                col = tipc[3] if c < 0 and k > 1 else (tipc[1] if c > 0 else tipc[2])
                if k == 0: col = tipc[3]
                d.put(X(a), ay + c, col)
            d.put(X(a), ay - hw - 1, tipc[0]); d.put(X(a), ay + hw + 1, tipc[0])
        d.put(X(-13), ay, tipc[0])
        for c in range(-3, 4): d.put(X(-6), ay + c, tipc[0])
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


# ══ KIT: todas las piezas de un aspecto, a escala ═════════════════════════════════════════════════════════════════
class Kit:
    def __init__(self, lid):
        self.id, self.L = lid, LOOKS[lid]
        self.art, self.face, self.vane_at = {}, {}, {}
        for f in FRAMES:
            im, fc, va = body_art(lid, f)
            self.art[f], self.face[f], self.vane_at[f] = im, fc, va
        self.body = {f: up(a, K) for f, a in self.art.items()}
        self.vanes = {s: up(vane(s), K) for s in 'LRF'}

    def draw(self, c, f, x, y, vstate='L', flip=False, hit=False):
        """x, y = el centro del cuerpo en pantalla"""
        b = self.body[f]
        v = self.vanes[vstate]
        if flip: b = b.transpose(Image.FLIP_LEFT_RIGHT)
        if hit:
            r, g, bb, a = b.split(); wv = Image.new('L', b.size, 255); b = Image.merge('RGBA', (wv, wv, wv, a))
        ox, oy = int(x - CX * K), int(y - CY * K)
        vx, vy = self.vane_at[f]
        if flip: vx = FW - 1 - vx
        c.alpha_composite(v, (int(ox + vx * K - VBASE[0] * K), int(oy + vy * K - VBASE[1] * K + 3 * K)))
        c.alpha_composite(b, (ox, oy))
        fx, fy = self.face[f]
        if flip: fx = FW - 1 - fx
        return (ox + (fx - 3) * K, oy + (fy + 7) * K)                 # (la boca, en pantalla)

    def bbox(self, f):
        return self.art[f].getbbox()


def overview(kits):
    show = ['idle1', 'warn', 'blow2', 'inhale2', 'gulp', 'charge', 'spin2', 'stun1']
    cw, ch = 420, 540
    W = 220 + cw * len(show)
    H = 60 + ch * len(kits)
    cv = Image.new('RGBA', (W, H), hx('1a1c24'))
    d = ImageDraw.Draw(cv)
    text(d, (16, 14), 'TIFÓN — ronda 1: cuatro aspectos (×5, a escala real con el jugador ×6, sobre los tejados)', font=FONT_B)
    for r, K_ in enumerate(kits):
        bg, gy, _ = roofs(cw, ch - 20)
        y0 = 60 + r * ch
        text(d, (16, y0 + 10), f"{K_.id} «{K_.L['name']}»", font=FONT_B)
        yy = y0 + 40
        for line in wrap(K_.L['note'], 22):
            text(d, (16, yy), line); yy += 20
        bb = K_.bbox('idle1')
        text(d, (16, yy + 10), f'idle: {(bb[2] - bb[0]) * K}x{(bb[3] - bb[1]) * K} px')
        for i, f in enumerate(show):
            cell = bg.copy()
            cell.alpha_composite(player(), (30, gy - 96))
            yc = gy - 215 if not f.startswith('stun') else gy - CY * K + (FH - 18) * K - 150
            if f.startswith('stun'):
                bbs = K_.bbox(f); yc = gy - (bbs[3] - CY) * K + K
            K_.draw(cell, f, cw // 2 + 30, yc, vstate='F' if f.startswith(('spin', 'stun')) else 'L')
            if f.startswith('stun'):
                cell.alpha_composite(stars(0), (cw // 2 + 30 - 25, yc - 140))
            cv.alpha_composite(cell, (220 + i * cw, y0))
            text(d, (220 + i * cw + 8, y0 + 4), f)
    return cv


def wrap(s, n):
    out, cur = [], ''
    for w in s.split():
        if len(cur) + len(w) + 1 > n: out.append(cur); cur = w
        else: cur = (cur + ' ' + w).strip()
    return out + [cur]


def silhouettes(kits):
    cw = 380
    cv = Image.new('RGBA', (cw * len(kits), 380), hx('4a546c'))
    d = ImageDraw.Draw(cv)
    for i, K_ in enumerate(kits):
        b = K_.body['idle1']
        a = b.getchannel('A')
        sil = Image.new('RGBA', b.size, (16, 16, 22, 255)); sil.putalpha(a)
        cv.alpha_composite(sil, (i * cw + (cw - b.width) // 2, 0))
        text(d, (i * cw + 10, 350), f"{K_.id} {K_.L['name']}")
    return cv


def parts_sheet(K_):
    """todos los cuadros a x3 con su nombre"""
    s = 3
    cols = 8
    cw, ch = FW * s + 10, FH * s + 30
    cv = Image.new('RGBA', (cw * cols, ch * ((len(FRAMES) + cols - 1) // cols) + 40), hx('4a546c'))
    d = ImageDraw.Draw(cv)
    text(d, (8, 8), f"{K_.id} «{K_.L['name']}» — cuadros del cuerpo (x3; la veleta es una capa aparte)", font=FONT_B)
    for i, f in enumerate(FRAMES):
        x, y = (i % cols) * cw, 40 + (i // cols) * ch
        v = up(vane('F' if f.startswith(('spin', 'stun')) else 'L'), s)
        vx, vy = K_.vane_at[f]
        cv.alpha_composite(v, (int(x + vx * s - VBASE[0] * s), int(y + vy * s - VBASE[1] * s + 3 * s)))
        cv.alpha_composite(up(K_.art[f], s), (x, y))
        text(d, (x + 4, y + FH * s + 4), f)
    return cv


def common_sheet():
    s = 6
    cv = Image.new('RGBA', (1200, 640), hx('363e52'))
    d = ImageDraw.Draw(cv)
    text(d, (10, 8), 'TIFÓN — piezas comunes (x6): veleta L / R / de frente / sin astilla · icono de la Colección · efectos', font=FONT_B)
    x = 10
    for st, em in (('L', False), ('R', False), ('F', False), ('L', True)):
        cv.alpha_composite(up(vane(st, empty=em), s), (x, 50)); x += VW * s + 16
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
    W, H = 1100, 620
    bg, gy, chim = roofs(W, H)
    rnd = random.Random(1)
    frames, durs, ev = [], [], []
    cue = lambda n: ev.append((sum(durs) / 1000, n))
    hx_, hy = 760, gy - 260
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
        shot('boom', px, gy - 96, extra=lambda c, i=i: c.alpha_composite(boom(min(9, i * 2)), (hx_ - 72, hy - 60)), dur=90)
    # se desploma sobre el tejado, aturdido
    bbs = K_.bbox('stun1')
    sy = gy - (bbs[3] - CY) * K + K
    cue('dizzy')
    for i in range(6):
        y = hy + (sy - hy) * (i + 1) / 6
        shot('stun1', px, gy - 96, vst='F', boss=(hx_, y), dur=80)
    for i in range(12):
        jx = px + (hx_ - px) * min(1, i / 7)
        jy = gy - 96 - math.sin(min(1, i / 7) * math.pi) * 260 if i < 7 else sy - 160
        hit = i in (8, 9)
        if i == 8: cue('hit')
        shot('stun1' if i % 2 else 'stun2', jx - 20, jy, vst='F', boss=(hx_, sy), hit=hit,
             extra=lambda c, i=i: c.alpha_composite(stars(i), (hx_ - 25, sy - 150)), dur=100)
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
    only = sys.argv[sys.argv.index('--look') + 1] if '--look' in sys.argv else None
    kits = [Kit(l) for l in LOOKS]
    overview(kits).save(os.path.join(OUT, 'vista_previa.png'))
    silhouettes(kits).save(os.path.join(OUT, 'siluetas.png'))
    for K_ in kits: parts_sheet(K_).save(os.path.join(OUT, f'piezas_{K_.id}.png'))
    common_sheet().save(os.path.join(OUT, 'comunes.png'))
    if '--still' not in sys.argv:
        for K_ in kits:
            if only and K_.id != only: continue
            g = os.path.join(OUT, f'pelea_{K_.id}.gif')
            ev, total = fight_gif(K_, g)
            video(g, ev, total, os.path.join(OUT, f'pelea_{K_.id}_con_sonido.mp4'))
    print('  ' + OUT)


if __name__ == '__main__':
    main()
