#!/usr/bin/env python3
# tools/art/enemies/make_scorpion.py — el ESCORPIÓN del volcán (una cola) y el ESCORPIÓN DE TRES COLAS, jefe secreto
# (docs/bosses/future-secret-bosses.md). El usuario eligió el C «Obsidiana» (2026-10-31), con el cuerpo más corto y las colas
# dibujadas por encima de él.
#
# El cuerpo es una hoja de cuadros; las COLAS y los BRAZOS son PIEZAS sueltas (idea del usuario, 2026-10-31: "segmentos
# que el juego anime al momento"): discos que se colocan por una cadena con muelle y la punta en 16 direcciones. Los
# segmentos son redondos para que no haga falta girarlos (rotar píxeles los ensucia) y la luz siga arriba a la izquierda.
# El jefe es la misma hoja a más escala (regla de los "Mega") con 3 colas y el broche con la astilla.
# Estilo del usuario para los enemigos nuevos: colores planos (3 tonos por parte), siluetas finas y originales.
#
#   python tools/art/enemies/make_scorpion.py          → FlappyMonster_pruebas/escorpion/final/ (el elegido, con sonido)
#   python tools/art/enemies/make_scorpion.py --all    → los 4 diseños, para comparar
#   python tools/art/enemies/make_scorpion.py --apply  → assets/ (hojas y animaciones)
import json, math, os, shutil, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = '/home/mtvemo/FlappyMonster_pruebas/escorpion'
SMALL_K, BOSS_K = 4, 10
W, H = 40, 24
GROUND = 22
TAU = math.tau
RATTLE_F = (0, 3, 6)                 # (cuadros del movimiento en que suena cada clic; a 0,03 s: 0,09 s entre clics)
COIL_F, COIL_K = 12, 0.34            # (enrollarse: cuadros rápidos y su muelle)


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# Diseños: cuerpo (luz, medio, sombra, contorno), patas, ojo y los 3 brillos de los aguijones (claro, medio)
# plates = (x centro, radio x, radio y, alto) de atrás adelante; seg = estilo de segmento; claw = (largo, grosor, curva)
DESIGNS = {
    # A: el del medio; ascuas bajo cada segmento
    'A': dict(name='Basalto', light='#8a8280', mid='#524a50', shade='#2f2a32', line='#141118', leg='#4a4348', legF='#28242c',
              eye='#ffcf4a', core='#ff7a2a', seg='ember', spikes=False, ss=1.0, claw=(4.0, 1.3), legs=(-5, -2, 2, 5),
              plates=[(6, 4.2, 2.8, 11), (11, 4.5, 3.3, 11), (16, 4.6, 3.7, 11), (21, 4.6, 3.9, 11)], head=(27, 5.0, 3.9, 11),
              glow=[('#ffd0a0', '#ff4a2a'), ('#ffe6a0', '#ff8a1e'), ('#fff6b8', '#ffd02a')]),
    # B: rechoncho y de pinzas enormes
    'B': dict(name='Ascua', light='#ff9a4a', mid='#d8482a', shade='#8e2a26', line='#3e1018', leg='#8e2a26', legF='#561a20',
              eye='#fff0a0', core='#ffd86a', seg='round', spikes=False, ss=1.25, claw=(5.6, 1.9), legs=(-4, -1, 2, 4),
              plates=[(7, 4.5, 3.4, 11), (12, 5.0, 4.4, 10), (18, 5.4, 5.0, 10)], head=(26, 6.2, 5.0, 10),
              glow=[('#ffffff', '#ff3a4a'), ('#fff4c0', '#ffa01e'), ('#ffffd8', '#ffe23a')]),
    # C: fino y largo, con púas en el lomo y las pinzas como ganchos
    'C': dict(name='Obsidiana', light='#8a78c8', mid='#3e2f6e', shade='#231a44', line='#0e0a22', leg='#3a2d68', legF='#1f183e',
              eye='#6affe0', core='#c060ff', seg='facet', spikes=True, ss=0.95, claw=(4.6, 0.9), legs=(-5, -2, 2, 5),
              plates=[(6, 3.6, 2.2, 12), (11, 4.1, 2.8, 12), (16, 4.4, 3.2, 12)], head=(22, 4.8, 3.2, 12),
              glow=[('#ffc0f0', '#ff3ac0'), ('#e0c8ff', '#a050ff'), ('#c8fff0', '#2ae0d0')]),
    # D: esqueleto de ceniza: placas estrechas, patas largas, cola de vértebras
    'D': dict(name='Ceniza', light='#e4d8c4', mid='#b0a08c', shade='#786a60', line='#352c2c', leg='#b0a08c', legF='#6a5c54',
              eye='#ff4a2a', core='#d8552a', seg='vertebra', spikes=False, ss=0.95, claw=(4.4, 1.0), legs=(-7, -3, 3, 7),
              plates=[(6, 3.0, 2.2, 10), (10.5, 3.0, 2.5, 10), (15, 3.0, 2.7, 10), (19.5, 3.0, 2.9, 10), (24, 3.0, 2.9, 10)], head=(29.5, 4.4, 3.1, 10),
              glow=[('#ffd0a0', '#e0342a'), ('#ffe0a0', '#ee7a1e'), ('#fff0b0', '#e8b82a')]),
}
SEG_N, ST_N, PIN_N = 13, 21, 31     # (lado del cuadro de cada pieza en sus hojas)
TAIL_XY = (4, 9)                     # (donde nace la cola, en la hoja)
SIZES = (3.0, 2.7, 2.4, 2.0, 1.6)    # (radios de los segmentos, de la base a la punta; cada diseño los multiplica por ss)


# ── dibujo por píxel ──────────────────────────────────────────────────────────────────────────────────────────
def outlined(im, color):
    px, out = im.load(), im.copy()
    op = out.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3]: continue
            if any(0 <= x + a < im.width and 0 <= y + b < im.height and px[x + a, y + b][3] for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                op[x, y] = color
    return out


def raster(w, h, fn, line=None):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    p = im.load()
    for y in range(h):
        for x in range(w):
            c = fn(x + 0.5, y + 0.5)
            if c: p[x, y] = c
    return outlined(im, line) if line else im


def tone(D, lit):
    return hx(D['light']) if lit > 0.42 else (hx(D['mid']) if lit > -0.32 else hx(D['shade']))


def segment(D, r):
    """un segmento de cola (o de brazo): redondo, se coloca sin girar"""
    r *= D['ss']
    n = SEG_N; c = n / 2
    style = D['seg']
    def fn(x, y):
        dx, dy = (x - c) / r, (y - c) / r
        d = max(abs(dx), abs(dy), (abs(dx) + abs(dy)) * 0.72) if style == 'facet' else math.hypot(dx, dy)
        if d > 1: return None
        if style == 'vertebra' and d < 0.36: return hx(D['shade'])
        if style == 'ember' and dx * 0.7 + dy * 0.7 > 0.62 and d > 0.6: return hx(D['core'])
        return tone(D, -(dx + dy) * 0.75)
    return raster(n, n, fn, hx(D['line']))


def stinger(D, ang, glow, flash=False):
    """la punta en la dirección ang (0 = derecha): bulbo con el veneno que brilla y el pincho curvado"""
    n = ST_N; c = n / 2
    ca, sa = math.cos(ang), math.sin(ang)
    hi, mid = (hx('#ffffff'), hx('#ffffff')) if flash else (hx(glow[0]), hx(glow[1]))
    def fn(x, y):
        dx, dy = x - c, y - c
        u, v = dx * ca + dy * sa, -dx * sa + dy * ca
        if (u / 2.8) ** 2 + (v / 2.1) ** 2 <= 1:
            return hi if -(dx + dy) > 1.1 else mid
        if 1.5 <= u <= 8.5:
            cv = 0.07 * (u - 1.5) ** 2
            if abs(v - cv) <= 1.2 * (1 - (u - 1.5) / 7) + 0.15:
                return hx(D['line']) if flash is False and u > 6 else (hx(D['light']) if flash is False else hi)
        return None
    return raster(n, n, fn, hx(D['line']))


def pincer(D, ang, opened):
    """la pinza en la dirección ang: palma y dos dedos en forma de C (se lee como pinza desde cualquier lado)"""
    R_, th = D['claw']
    n = PIN_N; c = n / 2
    ca, sa = math.cos(ang), math.sin(ang)
    gap = 0.22 + 0.62 * opened
    cx = 1.2 + R_
    def fn(x, y):
        dx, dy = x - c, y - c
        u, v = dx * ca + dy * sa, -dx * sa + dy * ca
        lit = -(dx + dy) * 0.2
        if ((u - 0.8) / 3.4) ** 2 + (v / (th + 1.6)) ** 2 <= 1: return tone(D, lit)
        r, a = math.hypot(u - cx, v), abs(math.atan2(v, u - cx))
        g = gap + (0.28 if v > 0 else 0.0)                                   # (el dedo de abajo, más corto)
        if a >= g and u > 0.5:
            t = (a - g) / (math.pi - g)
            if abs(r - R_) <= th * (0.3 + 0.7 * t) + 0.2: return tone(D, lit)
        return None
    return raster(n, n, fn, hx(D['line']))


def ell_fn(D, cx, cy, rx, ry):
    def f(x, y):
        dx, dy = (x - cx) / rx, (y - cy) / ry
        d = dx * dx + dy * dy
        if d > 1: return None
        if d > 0.72 and dy > -0.3 and dx > -0.6: return hx(D['shade'])          # (el borde de la placa la separa)
        return tone(D, -(dx * 0.5 + dy) * 0.95)
    return f


def line_px(p, a, b, c):
    n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) + 1
    for i in range(n + 1):
        x, y = a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n
        if 0 <= int(x) < W and 0 <= int(y) < H: p[int(x), int(y)] = c


def body(D, frame=0, f4=4, low=0):
    """el cuerpo sin cola ni pinzas, mirando a la DERECHA; frame = el paso de las patas; low = agachado"""
    if low:
        D = dict(D, plates=[(c, a, b, y + low) for c, a, b, y in D['plates']], head=D['head'][:3] + (D['head'][3] + low,))
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    p = im.load()
    x0, x1 = D['plates'][0][0] + 3, D['head'][0] - 2
    hips = [x0 + (x1 - x0) * i / 3 for i in range(4)]
    by = max(c[3] + c[2] for c in D['plates']) - 1
    for side, col in ((0, hx(D['legF'])), (1, hx(D['leg']))):
        for i, hx_ in enumerate(hips):
            ph = (frame + i * 2 + side) % f4
            step = (-1.5, -0.5, 0.5, 1.5)[ph]
            lift = 1 if ph == 3 else 0
            out = D['legs'][i] + (0 if side else 1)
            hip = (hx_, by)
            knee = (hx_ + out * 0.55 + step * 0.4, by + 1)
            foot = (hx_ + out * 1.05 + step, GROUND - 1 - lift)
            line_px(p, hip, knee, col); line_px(p, knee, foot, col)
    for (cx, rx, ry, cy) in D['plates']:
        f = ell_fn(D, cx, cy, rx, ry)
        for y in range(H):
            for x in range(W):
                c = f(x + 0.5, y + 0.5)
                if c: p[x, y] = c
        if D['spikes']:
            for k in range(3):
                x_, y_ = int(cx), int(cy - ry - k)
                if y_ >= 0 and k < 2: p[x_, y_] = hx(D['mid'] if k == 0 else D['light'])
    hxc, hrx, hry, hcy = D['head']
    f = ell_fn(D, hxc, hcy, hrx, hry)
    for y in range(H):
        for x in range(W):
            c = f(x + 0.5, y + 0.5)
            if c: p[x, y] = c
    # ojos: 2x2 con su brillo (el usuario: que se vean)
    ex, ey = int(hxc + hrx * 0.28), int(hcy - hry * 0.42)
    for a, b in ((0, 0), (1, 0), (0, 1), (1, 1)):
        p[ex + a, ey + b] = hx(D['eye'])
    p[ex - 3, ey + 1] = hx(D['eye'])
    # quelíceros
    mx, my = int(hxc + hrx), int(hcy + 1)
    if mx + 1 < W:
        p[mx, my] = hx(D['shade']); p[mx + 1, my] = hx(D['line'])
    return outlined(im, hx(D['line']))


def clasp(D):
    """el broche que une las colas: anillo de metal con la astilla del espejo engastada (la pieza que suelta)"""
    gold, goldS, line = hx('#ffd84a'), hx('#b8801c'), hx('#4a2c10')
    glass, glassL = hx('#a8e8ff'), hx('#ffffff')
    def fn(x, y):
        dx, dy = x - 4.5, y - 4.5
        if abs(dx) + abs(dy) <= 1.6: return glassL if dx + dy < 0 else glass
        if math.hypot(dx, dy) <= 3.2: return gold if dx + dy < 0.6 else goldS
        return None
    return raster(9, 9, fn, line)


def rune_overlay(D):
    """las marcas doradas de la Furia del Espejo sobre las placas (solo el jefe)"""
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    p = im.load(); g = hx('#ffd84a')
    for (cx, rx, ry, cy) in D['plates'][1:]:
        p[int(cx), int(cy - ry * 0.55)] = g
        p[int(cx), int(cy - ry * 0.55) + 1] = g
    return im


# ── la cadena: lo que hará el juego (posiciones con muelle y largo fijo entre segmentos) ──────────────────────────
class Chain:
    def __init__(self, base, n, gap):
        self.n, self.gap = n, gap
        self.P = [[base[0], base[1] - i * gap] for i in range(n)]
        self.V = [[0.0, 0.0] for _ in range(n)]

    def step(self, base, target, k=0.16, damp=0.72):
        self.P[0] = list(base)
        for i in range(1, self.n):
            t = target[i]
            kk = k * (1 - 0.45 * i / self.n)                                # (la punta va un poco por detrás: látigo)
            self.V[i][0] = (self.V[i][0] + (t[0] - self.P[i][0]) * kk) * damp
            self.V[i][1] = (self.V[i][1] + (t[1] - self.P[i][1]) * kk) * damp
            self.P[i][0] += self.V[i][0]; self.P[i][1] += self.V[i][1]
        for i in range(1, self.n):
            a, b = self.P[i - 1], self.P[i]
            dx, dy = b[0] - a[0], b[1] - a[1]
            d = math.hypot(dx, dy) or 1
            b[0] = a[0] + dx / d * self.gap; b[1] = a[1] + dy / d * self.gap

    def tip_angle(self):
        a, b = self.P[-2], self.P[-1]
        return math.atan2(b[1] - a[1], b[0] - a[0])


def anchors(D, x, top, k):
    """hombro y mano de la pinza (en reposo), en pantalla"""
    hc, hr, _, hy = D['head']
    return (x + (hc + hr * 0.5) * k, top + (hy + 3) * k), (x + (hc + hr + 7) * k, top + (hy + 1) * k)


def bez(p0, p1, p2, p3, n):
    """n puntos a distancia casi igual por una curva"""
    pts = []
    for i in range(201):
        t = i / 200
        u = 1 - t
        pts.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    ds = [0]
    for a, b in zip(pts, pts[1:]): ds.append(ds[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    out, j = [], 0
    for i in range(n):
        s = ds[-1] * i / (n - 1)
        while j < 200 and ds[j + 1] < s: j += 1
        out.append(pts[j])
    return out


class Kit:
    """todas las piezas de un diseño, a la escala de pantalla k (con las hojas ya hechas: como las cargará el juego)"""
    def __init__(self, D, k):
        self.D, self.k = D, k
        up = lambda im: im.resize((im.width * k, im.height * k), Image.NEAREST)
        self.body = [up(body(D, f)) for f in range(4)]
        self.segs = [up(segment(D, r)) for r in SIZES]
        self.rune = up(rune_overlay(D))
        self.clasp = up(clasp(D))
        self.st = [[up(stinger(D, i * TAU / 16, g)) for i in range(16)] for g in D['glow']]
        self.st_f = [up(stinger(D, i * TAU / 16, D['glow'][0], True)) for i in range(16)]
        self.pin = {o: [up(pincer(D, i * TAU / 16, o)) for i in range(16)] for o in (0, 1)}

    def put(self, c, im, x, y, shade=None):
        if shade is not None:
            r, g, b, a = im.split()
            f = lambda v: int(v * shade)
            im = Image.merge('RGBA', (r.point(f), g.point(f), b.point(f), a))
        c.alpha_composite(im, (int(x - im.width / 2), int(y - im.height / 2)))


def seg_for(i, n):
    return min(len(SIZES) - 1, i * len(SIZES) // n)


def draw_tail(K, c, ch, tail, flash=False, shade=None):
    for i in range(ch.n - 1):
        K.put(c, K.segs[seg_for(i, ch.n)], ch.P[i][0], ch.P[i][1], shade)
    d = round(ch.tip_angle() / TAU * 16) % 16
    K.put(c, K.st_f[d] if flash else K.st[tail][d], ch.P[-1][0], ch.P[-1][1])


def draw_arm(K, c, sh, hand, ang, opened, shade=None):
    n = 3
    for i in range(n):
        t = i / n
        K.put(c, K.segs[3], sh[0] + (hand[0] - sh[0]) * t, sh[1] + (hand[1] - sh[1]) * t + math.sin(t * math.pi) * K.k, shade)
    K.put(c, K.pin[opened][round(ang / TAU * 16) % 16], hand[0], hand[1], shade)


# ── el fondo: el volcán de verdad ─────────────────────────────────────────────────────────────────────────────────
def load(rel):
    return Image.open(os.path.join(ROOT, rel)).convert('RGBA')


def volcano_bg(w, h):
    gi = 8
    g = load('assets/images/world/sky/gradients.png').crop((gi * 8, 0, gi * 8 + 8, 180))
    bg = g.resize((w, h), Image.NEAREST)
    for name in ('far', 'mid', 'near'):
        lay = load(f'assets/images/world/sky/volcano_{name}.png')
        lay = lay.resize((lay.width * 4, lay.height * 4), Image.NEAREST)
        for x in range(0, w, lay.width): bg.alpha_composite(lay, (x, max(0, h - 64 - lay.height)))
    gy = h - 64
    tile = load('assets/images/world/tiles/basalt.png').crop((0, 0, 64, 64))
    for x in range(0, w, 64): bg.alpha_composite(tile, (x, gy))
    return bg, gy


def player():
    im = load('assets/images/player/monstrito1.png')
    return im.resize((im.width * 6, im.height * 6), Image.NEAREST)


try:
    FONT = ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans.ttf', 15)
    FONT_B = ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans-Bold.ttf', 20)
except Exception:
    FONT = FONT_B = None


def text(d, xy, s, fill=(255, 255, 255, 255), font=None):
    f = font or FONT
    d.text((xy[0] + 1, xy[1] + 1), s, fill=(0, 0, 0, 255), font=f); d.text(xy, s, fill=fill, font=f)


# ── las poses (todas en píxeles de pantalla, relativas al cuerpo) ─────────────────────────────────────────────────
def boss_poses(K, x, gy, t):
    """base de las colas, hombros y nudos del jefe con su cuerpo en x"""
    k = K.k
    top = gy - GROUND * k
    return (x + TAIL_XY[0] * k, top + TAIL_XY[1] * k), top


def fan_target(base, k, i, t, n, up=1.0):
    """en reposo: tres colas bien abiertas, como un tridente sobre el lomo, cada punta hacia delante"""
    sway = math.sin(t * 2.2 + i * 2.1) * 1.2 * k
    tx, ty = ((-14, -29), (6, -41), (27, -29))[i]
    tip = (base[0] + tx * k + sway, base[1] + ty * k * up)
    return bez(base, (base[0] + (-11 + i * 7) * k, base[1] - 11 * k), (tip[0] - 11 * k, tip[1] - 9 * k), tip, n)


def braid_target(base, k, i, t, n, tip, up=1.0, amp=1.5):
    """entrelazadas: una sola curva gruesa, cada cola da vueltas alrededor de ella. Devuelve también la z de cada punto"""
    ctr = bez(base, (base[0] - 9 * k, base[1] - 16 * k), (tip[0] - 12 * k, tip[1] - 26 * k * up), tip, n)
    pts, zs = [], []
    for j, p in enumerate(ctr):
        ph = j / n * TAU * 2.2 + i * TAU / 3 + t * 0.9
        a = amp * k * min(1, j / 2) * (1 - 0.5 * j / n)
        a0, a1 = ctr[max(0, j - 1)], ctr[min(n - 1, j + 1)]
        nx, ny = -(a1[1] - a0[1]), a1[0] - a0[0]
        d = math.hypot(nx, ny) or 1
        pts.append((p[0] + nx / d * math.sin(ph) * a, p[1] + ny / d * math.sin(ph) * a))
        zs.append(math.cos(ph))
    return pts, zs


def strike_target(base, k, n, tip, windup=0.0):
    return bez(base, (base[0] + 10 * k, base[1] - 18 * k), (tip[0] - 12 * k, tip[1] - (12 + windup) * k), tip, n)


def boss_scene(K, name):
    """toda la coreografía: abanico · 3 clics y se entrelazan · golpe clavado · 3 clics y se separan · una a una · pinza"""
    k = K.k
    w, h = 1200, 700
    bg, gy = volcano_bg(w, h)
    pl = player()
    x = 190
    N = 19; gap = 3.4 * k
    base, top = boss_poses(K, x, gy, 0)
    tails = [Chain((base[0] + (i - 1) * k, base[1]), N, gap) for i in range(3)]
    for i, ch in enumerate(tails):
        ch.P = [list(p) for p in fan_target(ch.P[0], k, i, 0, N)]
    frames, zbr = [], 0.0
    px = 960
    # línea de tiempo (cuadros a 30 por segundo)
    seq = [('fan', 30), ('join', 45), ('wind', 14), ('hit', 8), ('stuck', 30), ('split', 45), ('s0', 18), ('s1', 18), ('s2', 18), ('stuck3', 22), ('fan2', 24), ('claw', 40)]
    tl = []
    for s, d in seq: tl += [(s, i, d) for i in range(d)]
    marks = [640, 700, 760]
    hit_x = 700
    # los 3 clics van SEGUIDOS y DURANTE el movimiento de enrollarse / desenrollarse (el usuario, 2026-10-31): RATTLE_F
    clicks = {'join': RATTLE_F, 'split': RATTLE_F}
    spread_log = []
    armN = 0
    for f, (st, i, d) in enumerate(tl):
        t = f / 30
        walk = int(t * 6) % 4 if st in ('fan', 'fan2') else 0
        c = bg.copy()
        # objetivos
        br = 0.0
        flash = [False] * 3
        tg = [None] * 3; zs = [None] * 3
        tip_j = (base[0] + 19 * k, base[1] - 37 * k)
        if st in ('fan', 'fan2', 'stuck3') and st != 'stuck3':
            tg = [fan_target(tails[a].P[0], k, a, t, N) for a in range(3)]
        elif st == 'join':
            for a in range(3):
                tg[a], zs[a] = braid_target(tails[a].P[0], k, a, t, N, tip_j)
            for a, cf in enumerate(clicks['join']):
                if cf <= i < cf + 2: flash[a] = True
        elif st == 'wind':
            for a in range(3):
                tg[a], zs[a] = braid_target(tails[a].P[0], k, a, t, N, (base[0] - 4 * k, base[1] - 30 * k), 1.2)
        elif st in ('hit', 'stuck'):
            for a in range(3):
                tg[a], zs[a] = braid_target(tails[a].P[0], k, a, t * 0.1, N, (hit_x, gy + 2), 0.45, amp=1.0)
        elif st == 'split':
            tg = [fan_target(tails[a].P[0], k, a, t, N, 1.1) for a in range(3)]
            for a, cf in enumerate(clicks['split']):
                if cf <= i < cf + 2: flash[a] = True
        elif st in ('s0', 's1', 's2', 'stuck3'):
            who = {'s0': 0, 's1': 1, 's2': 2, 'stuck3': 3}[st]
            tg = []
            for a in range(3):
                if a <= who:
                    tg.append(strike_target(tails[a].P[0], k, N, (marks[a], gy + 1)))
                else:
                    tg.append(fan_target(tails[a].P[0], k, a, t, N, 1.1))
            if who < 3 and i < 5: flash[who] = True
        elif st == 'claw':
            tg = [fan_target(tails[a].P[0], k, a, t, N) for a in range(3)]
        for a in range(3):
            fast = st in ('hit', 's0', 's1', 's2') or (st in ('join', 'split') and i < COIL_F)
            tails[a].step(tails[a].P[0], tg[a], k=COIL_K if st in ('join', 'split') and fast else (0.42 if fast else 0.16), damp=0.62 if fast else 0.72)
        spread_log.append((st, i, max(math.hypot(tails[a].P[-1][0] - tails[b].P[-1][0], tails[a].P[-1][1] - tails[b].P[-1][1]) for a in range(3) for b in range(a))))
        # marcas del suelo: donde va a caer
        d_ = ImageDraw.Draw(c)
        if st in ('wind',) or (st == 'join' and i > 30):
            d_.rectangle((hit_x - 42, gy - 5, hit_x + 42, gy), fill=(255, 90, 40, 255))
        if st == 'split' and i > 24 or st in ('s0', 's1', 's2'):
            for a in range(3):
                if st != 'split' and {'s0': 0, 's1': 1, 's2': 2}[st] > a: continue
                col = hx(K.D['glow'][a][1])
                d_.rectangle((marks[a] - 22, gy - 5, marks[a] + 22, gy), fill=col)
        # el jugador
        pxx = px + (0 if st not in ('claw',) else -160 * min(1, i / 16))
        c.alpha_composite(pl, (int(pxx), gy - pl.height))
        # pinza de atrás, cuerpo, pinza de delante y, ENCIMA de todo (el usuario, 2026-10-31), las colas y el broche
        sh, rest = anchors(K.D, x, top, k)
        reach = 0
        opened = 0
        if st == 'claw':
            reach = (0 if i < 10 else min(1, (i - 10) / 6)) * 36 * k if i < 28 else 36 * k * (1 - (i - 28) / 12)
            opened = 1 if i < 16 else 0
        hand = (rest[0] + reach, rest[1])
        draw_arm(K, c, (sh[0] - 3 * k, sh[1] - k), (hand[0] - 3 * k, hand[1] - 6 * k), -0.35, opened, 0.65)
        K.put(c, K.body[walk], x + W * k / 2, top + H * k / 2)
        K.put(c, K.rune, x + W * k / 2, top + H * k / 2)
        draw_arm(K, c, sh, hand, 0.0, opened)
        # entrelazadas se ordenan por z; separadas, la de atrás más oscura
        if zs[0] is not None and st in ('join', 'wind', 'hit', 'stuck'):
            items = []
            for a, ch in enumerate(tails):
                for j in range(N - 1):
                    items.append((zs[a][j], j, a))
            for z, j, a in sorted(items):
                K.put(c, K.segs[seg_for(j, N)], tails[a].P[j][0], tails[a].P[j][1], 0.72 + 0.28 * (z + 1) / 2)
            for a in range(3):
                d = round(tails[a].tip_angle() / TAU * 16) % 16
                K.put(c, K.st_f[d] if flash[a] else K.st[a][d], tails[a].P[-1][0], tails[a].P[-1][1])
        else:
            for a, sh_ in ((0, 0.62), (2, 0.8), (1, None)):
                draw_tail(K, c, tails[a], a, flash[a], sh_)
        K.put(c, K.clasp, base[0], base[1])
        # el clic, escrito (la previa no tiene sonido)
        for a in range(3):
            if flash[a]:
                dd = ImageDraw.Draw(c)
                text(dd, (500 + a * 80, 40), 'TAK', (255, 240, 170, 255), FONT_B)
        dd = ImageDraw.Draw(c)
        label = {'fan': 'reposo: las 3 colas', 'fan2': 'reposo', 'join': '3 clics: se entrelazan', 'wind': 'carga',
                 'hit': 'GOLPE', 'stuck': 'clavada: la ventana', 'split': '3 clics: se separan', 's0': 'una', 's1': 'dos',
                 's2': 'tres', 'stuck3': '', 'claw': 'pinza: atrapa'}[st]
        text(dd, (20, 16), f'{name} — {label}')
        frames.append(c.convert('RGB').convert('P', palette=Image.ADAPTIVE, colors=128))
    frames[0].save(os.path.join(OUT, f'jefe_{name}.gif'), save_all=True, append_images=frames[1:], duration=33, loop=0)
    if os.environ.get('SPREAD'):
        for g in ('join', 'split'):
            print(g, ' '.join(f'{d:.0f}' for st_, i_, d in spread_log if st_ == g)[:220])
    return frames


def still_boss(K, w=860, h=640, pose='fan'):
    """un cuadro fijo del jefe, sobre el volcán"""
    k = K.k
    bg, gy = volcano_bg(w, h)
    x = 190
    N = 19; gap = 3.4 * k
    base, top = boss_poses(K, x, gy, 0)
    tails = [Chain((base[0] + (i - 1) * k, base[1]), N, gap) for i in range(3)]
    zs = [None] * 3
    for a, ch in enumerate(tails):
        if pose == 'braid':
            tg, zs[a] = braid_target(ch.P[0], k, a, 0.3, N, (base[0] + 19 * k, base[1] - 37 * k))
        else:
            tg = fan_target(ch.P[0], k, a, 0.6, N)
        ch.P = [list(p) for p in tg]
        for _ in range(4): ch.step(ch.P[0], tg, k=0.5, damp=0.3)
    sh, hand = anchors(K.D, x, top, k)
    draw_arm(K, bg, (sh[0] - 3 * k, sh[1] - k), (hand[0] - 3 * k, hand[1] - 6 * k), -0.35, 1, 0.65)
    K.put(bg, K.body[0], x + W * k / 2, top + H * k / 2)
    K.put(bg, K.rune, x + W * k / 2, top + H * k / 2)
    draw_arm(K, bg, sh, hand, 0.0, 1)
    if pose == 'braid':
        items = sorted((zs[a][j], j, a) for a in range(3) for j in range(N - 1))
        for z, j, a in items: K.put(bg, K.segs[seg_for(j, N)], tails[a].P[j][0], tails[a].P[j][1], 0.72 + 0.28 * (z + 1) / 2)
        for a in range(3):
            d = round(tails[a].tip_angle() / TAU * 16) % 16
            K.put(bg, K.st[a][d], tails[a].P[-1][0], tails[a].P[-1][1])
    else:
        draw_tail(K, bg, tails[0], 0, False, 0.62); draw_tail(K, bg, tails[2], 2, False, 0.8); draw_tail(K, bg, tails[1], 1)
    K.put(bg, K.clasp, base[0], base[1])
    p = player()
    bg.alpha_composite(p, (w - p.width - 8, gy - p.height))
    return bg


def small_frame(K, c, x, gy, t, walk, ch, tg, flash=False):
    k = K.k
    top = gy - GROUND * k
    ch.step((x + TAIL_XY[0] * k, top + TAIL_XY[1] * k), tg)
    K.put(c, K.body[walk], x + W * k / 2, top + H * k / 2)
    sh, hand = anchors(K.D, x, top, k)
    draw_arm(K, c, sh, hand, 0.0, 1)
    draw_tail(K, c, ch, 1, flash)


def small_gif(K, name):
    w, h = 560, 300
    bg, gy = volcano_bg(w, h)
    k = K.k
    N = 8; gap = 3.2 * k
    x0 = 60
    top = gy - GROUND * k
    ch = Chain((x0 + TAIL_XY[0] * k, top + TAIL_XY[1] * k), N, gap)
    pl = player()
    frames = []
    for f in range(120):
        t = f / 30
        x = x0 + min(f, 70) * 1.6
        base = (x + TAIL_XY[0] * k, top + TAIL_XY[1] * k)
        c = bg.copy()
        c.alpha_composite(pl, (w - pl.width - 20, gy - pl.height))
        if f < 75:
            tg = bez(base, (base[0] - 8 * k, base[1] - 10 * k), (base[0] + 2 * k, base[1] - 26 * k + math.sin(t * 3) * k), (base[0] + 13 * k, base[1] - 20 * k), N)
            walk = int(t * 8) % 4
        elif f < 88:
            tg = bez(base, (base[0] - 8 * k, base[1] - 8 * k), (base[0] - 8 * k, base[1] - 24 * k), (base[0] + 2 * k, base[1] - 20 * k), N); walk = 0
        else:
            tg = strike_target(base, k, N, (x + 60 * k, gy), 0); walk = 0
        small_frame(K, c, x, gy, t, walk, ch, tg, 76 <= f < 80)
        frames.append(c.convert('RGB').convert('P', palette=Image.ADAPTIVE, colors=96))
    frames[0].save(os.path.join(OUT, f'chico_{name}.gif'), save_all=True, append_images=frames[1:], duration=33, loop=0)


def pieces_sheet(id_, D):
    """las piezas sueltas de un diseño, ×6"""
    k = 6
    K = Kit(D, 1)
    c = Image.new('RGBA', (1100, 420), (40, 30, 34, 255))
    d = ImageDraw.Draw(c)
    text(d, (10, 6), f'{id_} {D["name"]}: las piezas (cuerpo en 4 pasos · segmentos · puntas en 16 direcciones · pinza abierta y cerrada)')
    up = lambda im: im.resize((im.width * k, im.height * k), Image.NEAREST)
    for i in range(4):
        c.alpha_composite(up(K.body[i]).resize((W * 4, H * 4), Image.NEAREST), (10 + i * 150, 34))
    for i, s in enumerate(K.segs):
        c.alpha_composite(up(s), (640 + i * 86, 30))
    for i in range(8):
        c.alpha_composite(up(K.st[i % 3][i * 2]).resize((84, 84), Image.NEAREST), (10 + i * 90, 130))
    for i in range(4):
        c.alpha_composite(up(K.pin[1][i * 4]).resize((116, 116), Image.NEAREST), (10 + i * 120, 230))
        c.alpha_composite(up(K.pin[0][i * 4]).resize((116, 116), Image.NEAREST), (500 + i * 120, 230))
    c.alpha_composite(up(K.clasp), (760, 120))
    c.convert('RGB').save(os.path.join(OUT, f'piezas_{id_}.png'))


def preview():
    kits = {i: (Kit(D, BOSS_K), Kit(D, SMALL_K)) for i, D in DESIGNS.items()}
    cols = 2
    tw, th = 860, 640
    sh = Image.new('RGB', (cols * tw + 20, 2 * (th + 240)), (24, 18, 22))
    for n, (i, (KB, KS)) in enumerate(kits.items()):
        ox, oy = (n % cols) * tw + 10, (n // cols) * (th + 240)
        sh.paste(still_boss(KB).convert('RGB'), (ox, oy))
        # el pequeño, a su escala real, delante de su trozo de volcán
        bg, gy = volcano_bg(tw, 240)
        k = KS.k; N = 8; gap = 3.2 * k
        x = 90; top = gy - GROUND * k
        base = (x + TAIL_XY[0] * k, top + TAIL_XY[1] * k)
        ch = Chain(base, N, gap)
        tg = bez(base, (base[0] - 8 * k, base[1] - 10 * k), (base[0] + 2 * k, base[1] - 26 * k), (base[0] + 13 * k, base[1] - 20 * k), N)
        ch.P = [list(p) for p in tg]
        small_frame(KS, bg, x, gy, 0, 0, ch, tg)
        pl = player(); bg.alpha_composite(pl, (tw - pl.width - 120, gy - pl.height))
        sh.paste(bg.convert('RGB'), (ox, oy + th))
        d = ImageDraw.Draw(sh)
        text(d, (ox + 12, oy + 10), f'{i} "{DESIGNS[i]["name"]}"', (255, 240, 170, 255), FONT_B)
    sh.save(os.path.join(OUT, 'vista_previa.png'))
    # abanico y entrelazadas, lado a lado
    sh = Image.new('RGB', (2 * tw + 10, 4 * th), (24, 18, 22))
    for n, (i, (KB, _)) in enumerate(kits.items()):
        sh.paste(still_boss(KB, pose='fan').convert('RGB'), (0, n * th))
        sh.paste(still_boss(KB, pose='braid').convert('RGB'), (tw + 10, n * th))
    sh.save(os.path.join(OUT, 'colas_separadas_y_entrelazadas.png'))
    return kits


# ══ EL PAQUETE: hojas y animaciones del diseño elegido ═══════════════════════════════════════════════════════════
CHOSEN = 'C'
E_DIR, B_DIR = 'assets/images/enemies/scorpion/', 'assets/images/bosses/giantscorpion/'
BODY_W = 30                          # (el cuerpo corto cabe en menos ancho: la hoja se recorta por la derecha)


def strip(ims, w, h):
    sh = Image.new('RGBA', (w * len(ims), h), (0, 0, 0, 0))
    for i, im in enumerate(ims): sh.alpha_composite(im, (i * w, 0))
    return sh


def body_frames(D, rune=False):
    fr = [body(D, f) for f in range(4)] + [body(D, 0, low=2), body(D, 2, low=1)]
    if rune:
        for f, l in zip(fr, (0, 0, 0, 0, 2, 1)):
            f.alpha_composite(rune_overlay(D), (0, l))
    dead = body(D, 0).transpose(Image.FLIP_TOP_BOTTOM)                   # (panza arriba, sobre el lomo)
    bbox = dead.getbbox()
    fr.append(Image.new('RGBA', (W, H), (0, 0, 0, 0)))
    fr[-1].alpha_composite(dead, (0, GROUND - bbox[3]))
    return [f.crop((0, 0, BODY_W, H)) for f in fr]


def mark_sheet(D):
    """la marca del suelo donde va a caer un aguijón: una por cola y la del golpe entrelazado (blanca)"""
    out = []
    for hi, mid in list(D['glow']) + [('#ffffff', '#ff5a4a')]:
        im = Image.new('RGBA', (24, 4), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rectangle((1, 1, 22, 3), fill=hx(mid)); d.rectangle((4, 1, 19, 1), fill=hx(hi))
        out.append(im)
    return out


def crack_img(D):
    """la grieta que deja una cola clavada"""
    im = Image.new('RGBA', (24, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    dk, gl = hx(D['line']), hx(D['core'])
    for a, b in (((12, 0), (12, 3)), ((12, 3), (7, 5)), ((7, 5), (3, 5)), ((12, 3), (17, 6)), ((17, 6), (21, 6)), ((12, 3), (12, 7))):
        d.line((a, b), fill=dk)
    im.putpixel((12, 2), gl); im.putpixel((9, 4), gl); im.putpixel((15, 5), gl)
    return im


def impact_frames(D):
    """polvo y esquirlas al clavarse: 4 cuadros"""
    out = []
    for f in range(4):
        im = Image.new('RGBA', (24, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        r = 2 + f * 2
        for sx in (-1, 1):
            cx = 12 + sx * (2 + f * 3)
            d.ellipse((cx - r / 2, 13 - r, cx + r / 2, 14), fill=hx('#8a7a78' if f < 2 else '#5a4e50'))
            if f < 3:
                sy = 9 - f * 3
                d.rectangle((12 + sx * (3 + f * 3), sy, 12 + sx * (3 + f * 3) + 1, sy + 1), fill=hx(D['mid']))
                d.point((12 + sx * (5 + f * 4), sy + 2), fill=hx(D['core']))
        out.append(outlined(im, hx('#2a2226')) if f < 3 else im)
    return out


def icon(D, empty=False):
    """el coleccionable (17x13): el broche con su astilla; sin ella al robarla el Groove"""
    gold, goldS, line = hx('#ffd84a'), hx('#b8801c'), hx('#4a2c10')
    glass, glassL, hole = hx('#a8e8ff'), hx('#ffffff'), hx('#3a2410')
    def fn(x, y):
        dx, dy = x - 8.5, y - 6.5
        if abs(dx) * 0.9 + abs(dy) <= 2.4: return hole if empty else (glassL if dx + dy < -0.3 else glass)
        if (dx / 5.5) ** 2 + (dy / 4.8) ** 2 <= 1: return gold if dx + dy < 0.8 else goldS
        if abs(dy) <= 1.1 and abs(dx) <= 7.2: return goldS
        return None
    return raster(17, 13, fn, line)


def anim_set(aid, scale, origin, sheets, anims):
    frames = []
    for rel, w, h, n in sheets:
        frames += [{"h": h, "image": rel, "w": w, "x": i * w, "y": 0} for i in range(n)]
    data = {"id": aid, "scale": scale, "origin": origin, "fallback": next(iter(anims)), "frames": frames, "anims": anims}
    path = os.path.join(ROOT, 'assets', 'anim', aid + '.json')
    with open(path, 'w') as f: f.write(json.dumps(data, indent=2) + '\n')
    print('  ', os.path.relpath(path, ROOT))


def apply():
    D = DESIGNS[CHOSEN]
    a = lambda fr, fps, loop=True: {"fps": fps, "frames": fr, "loop": loop}
    fan = [i * TAU / 16 for i in range(16)]
    out = {E_DIR + 'body-Sheet.png': strip(body_frames(D), BODY_W, H),
           E_DIR + 'segments-Sheet.png': strip([segment(D, r) for r in SIZES], SEG_N, SEG_N),
           E_DIR + 'stinger-Sheet.png': strip([stinger(D, g, D['glow'][1]) for g in fan], ST_N, ST_N),
           E_DIR + 'stinger_flash-Sheet.png': strip([stinger(D, g, D['glow'][1], True) for g in fan], ST_N, ST_N),
           E_DIR + 'pincer_open-Sheet.png': strip([pincer(D, g, 1) for g in fan], PIN_N, PIN_N),
           E_DIR + 'pincer_closed-Sheet.png': strip([pincer(D, g, 0) for g in fan], PIN_N, PIN_N),
           B_DIR + 'body-Sheet.png': strip(body_frames(D, True), BODY_W, H),
           B_DIR + 'mark-Sheet.png': strip(mark_sheet(D), 24, 4), B_DIR + 'crack.png': crack_img(D),
           B_DIR + 'impact-Sheet.png': strip(impact_frames(D), 24, 16), B_DIR + 'wear_clasp.png': clasp(D),
           'assets/images/story/collectibles/astilla_escorpion.png': icon(D),
           'assets/images/story/collectibles/astilla_escorpion_empty.png': icon(D, True)}
    for t in range(3):
        out[B_DIR + f'stinger{t + 1}-Sheet.png'] = strip([stinger(D, g, D['glow'][t]) for g in fan], ST_N, ST_N)
    for rel, im in out.items():
        os.makedirs(os.path.dirname(os.path.join(ROOT, rel)), exist_ok=True)
        im.save(os.path.join(ROOT, rel)); print('  ', rel)
    # Cuerpo: origen en los pies. Piezas: origen en el centro; la punta y la pinza, cuadro = 1 + round(ángulo / 22,5°)
    body_anims = {"idle": a([1], 4), "walk": a([1, 2, 3, 4], 10), "windup": a([5], 8, False), "hurt": a([6], 8), "dead": a([7], 8, False)}
    d16 = list(range(1, 17))
    anim_set('enemies/scorpion', SMALL_K, [0.5, 1], [(E_DIR + 'body-Sheet.png', BODY_W, H, 7)], body_anims)
    anim_set('bosses/giantscorpion', BOSS_K, [0.5, 1], [(B_DIR + 'body-Sheet.png', BODY_W, H, 7)], body_anims)
    def part_set(aid, k, stingers):
        sheets = [(E_DIR + 'segments-Sheet.png', SEG_N, SEG_N, 5), (E_DIR + 'pincer_open-Sheet.png', PIN_N, PIN_N, 16),
                  (E_DIR + 'pincer_closed-Sheet.png', PIN_N, PIN_N, 16), (E_DIR + 'stinger_flash-Sheet.png', ST_N, ST_N, 16)]
        an = {"segment": a([1, 2, 3, 4, 5], 1, False), "pincer_open": a([5 + i for i in d16], 8), "pincer_closed": a([21 + i for i in d16], 8),
              "stinger_flash": a([37 + i for i in d16], 8)}
        n = 53
        for name, rel in stingers:
            sheets.append((rel, ST_N, ST_N, 16))
            an[name] = a([n + i for i in d16], 8)
            n += 16
        anim_set(aid, k, [0.5, 0.5], sheets, an)
    part_set('enemies/scorpion_parts', SMALL_K, [('stinger', E_DIR + 'stinger-Sheet.png')])
    part_set('bosses/giantscorpion_parts', BOSS_K, [(f'stinger{t + 1}', B_DIR + f'stinger{t + 1}-Sheet.png') for t in range(3)])
    anim_set('bosses/giantscorpion_fx', BOSS_K, [0.5, 1], [(B_DIR + 'mark-Sheet.png', 24, 4, 4), (B_DIR + 'crack.png', 24, 8, 1), (B_DIR + 'impact-Sheet.png', 24, 16, 4)],
             {"mark1": a([1], 1), "mark2": a([2], 1), "mark3": a([3], 1), "mark_heavy": a([4], 1), "crack": a([5], 1, False), "impact": a([6, 7, 8, 9], 14, False)})


def wav(rel):
    import wave
    with wave.open(os.path.join(ROOT, 'assets/sounds', rel)) as w:
        import numpy as np
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16) / 32768.0


def video(name, frames_s=312 * 0.03):
    """la coreografía CON los sonidos del juego, cada uno en su cuadro"""
    import numpy as np
    S = 'enemies/scorpion/'; G = 'bosses/giantscorpion/'
    f = 0.03                                                             # (un GIF va de 10 en 10 ms: 33 → 30)
    ev = [((30 + RATTLE_F[0]) * f, G + 'rattle_join.wav'), (92 * f, G + 'strike.wav'), (120 * f, G + 'pull.wav'),
          ((127 + RATTLE_F[0]) * f, G + 'rattle_split.wav'), (176 * f, S + 'sting.wav'), (194 * f, S + 'sting.wav'),
          (212 * f, S + 'sting.wav'), (288 * f, S + 'snap.wav'), (0.1, S + 'skitter.wav'), (248 * f, S + 'skitter.wav')]
    y = np.zeros(int(44100 * frames_s) + 44100)
    for t, rel in ev:
        x = wav(rel); i = int(t * 44100); y[i:i + len(x)] += x[:len(y) - i]
    import wave
    wp = os.path.join(OUT, 'pista.wav')
    with wave.open(wp, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100)
        w.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', os.path.join(OUT, f'jefe_{name}.gif'), '-i', wp, '-shortest', '-pix_fmt', 'yuv420p',
                    '-c:a', 'aac', os.path.join(OUT, f'jefe_{name}_con_sonido.mp4')], check=True)
    os.remove(wp)


if __name__ == '__main__':
    if '--apply' in sys.argv:
        apply()
        sys.exit(0)
    if '--all' in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        kits = preview()
        for i, D in DESIGNS.items():
            pieces_sheet(i, D)
            boss_scene(kits[i][0], i)
            small_gif(kits[i][1], i)
        print('previas en', OUT)
        sys.exit(0)
    OUT = os.path.join(OUT, 'final')
    os.makedirs(OUT, exist_ok=True)
    D = DESIGNS[CHOSEN]
    KB, KS = Kit(D, BOSS_K), Kit(D, SMALL_K)
    still_boss(KB).convert('RGB').save(os.path.join(OUT, 'jefe_colas_separadas.png'))
    still_boss(KB, pose='braid').convert('RGB').save(os.path.join(OUT, 'jefe_colas_entrelazadas.png'))
    pieces_sheet(CHOSEN, D)
    boss_scene(KB, CHOSEN)
    small_gif(KS, CHOSEN)
    video(CHOSEN)
    print('previas en', OUT)
