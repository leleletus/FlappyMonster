#!/usr/bin/env python3
# tools/art/bosses/make_carnivorous_queen.py — la REINA CARNÍVORA, jefa secreta de la jungla (docs/design/carnivorous-queen.md).
# SOLO DISEÑOS PARA ELEGIR: no escribe nada en assets/, solo previas en FlappyMonster_pruebas/reina_carnivora/.
#
# Es la Planta Carnívora B «Cepo» crecida al tocar una astilla: mismas valvas (fuera verde, dentro magenta, pestañas
# claras), mismas hojas de la base y la misma flor de cebo, que ahora es su punto débil y lleva la astilla como una
# gota de rocío. El cuerpo es una hoja de cuadros; la FLOR y la GOTA son capas sueltas; las BOCAS que brotan son piezas
# (cabeza en 16 direcciones + discos que no hay que girar) para que el juego las mueva con SegmentChain.lua.
# Estilo del usuario: colores planos (3 tonos por parte), sin motas, siluetas finas, ojos que se lean.
#
#   python3 tools/art/bosses/make_carnivorous_queen.py            → todo (vista_previa, hojas de piezas, GIF por diseño)
#   python3 tools/art/bosses/make_carnivorous_queen.py --still    → sin los GIF (para iterar)
#   python3 tools/art/bosses/make_carnivorous_queen.py --look A   → solo ese diseño en los GIF
import math, os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(HERE, '..', 'enemies'))
# (el motor de la planta y la cadena del escorpión: los mismos, sin copiarlos)
from make_jungle_enemies import E, Sh, Pg, P, D, Xf, render, tube, r3, hx, LEAF, _lobe, margin_ok
from make_scorpion import Chain, bez as bez3, text, FONT_B

OUT = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'reina_carnivora')
TAU = math.tau
PLAYER_K, SMALL_K = 6, 4

# ── paletas: las de la planta pequeña (3 tonos: contorno, sombra, medio) ──────────────────────────────────────────
LEAFL = r3(LEAF[0], LEAF[2], LEAF[3])                    # (hoja clara: la valva)
LEAFD = r3(LEAF[0], LEAF[1], LEAF[2])                    # (hoja oscura: tallo y base)
INNER = r3('4a0c26', '9a1c4a', 'd0407a')                 # (el magenta de dentro)
CILIA = 'e4f4a8'
PINK = r3('7a2440', 'd0507a', 'f08aa8')
YEL = 'f4d03a'
EYE, PUPIL = 'ffe14a', '1a0a10'
HOLE = r3('1c0410', '2a060e', '2a060e')
GLASS, GLASS_L, GLASS_D = 'a8e8ff', 'ffffff', '2a6a9a'


def flash_white(im):
    r, g, b, a = im.split()
    w = Image.new('L', im.size, 255)
    return Image.merge('RGBA', (w, w, w, a))


# ── piezas comunes ────────────────────────────────────────────────────────────────────────────────────────────────
def trap(H, ha, theta, L, W, out=LEAFL, inn=INNER, closed=False, bulge=0.0, xf=None, teeth=2, tall=True):
    """las dos valvas: como las de la planta pequeña, pero con dientes de 2 píxeles (a esta escala 1 no se lee)"""
    it = []
    if closed:
        for s, a in ((1, ha - 5), (-1, ha + 5)):
            _, _, outer, _ = _lobe(H, a, L, W + bulge, s)
            it.append(P(outer, out))
        ar = math.radians(ha)
        tx, ty = H[0] + math.sin(ar) * (L + 0.6), H[1] - math.cos(ar) * (L + 0.6)
        it.append(D([(int(tx) - 1, int(ty), CILIA), (int(tx) + 1, int(ty), CILIA), (int(tx), int(ty) - 1, CILIA)]))
    else:
        for s, a in ((1, ha - theta), (-1, ha + theta)):
            whole, inner, _, rim = _lobe(H, a, L, W, s)
            it.append(P(whole, out))
            it.append(P(inner, inn, line=False))
            ar = math.radians(a)
            nx, ny = math.cos(ar) * s, math.sin(ar) * s
            pts = []
            for i, (x, y) in enumerate(rim[1::teeth]):
                pts.append((int(math.floor(x)), int(math.floor(y)), CILIA))
                if tall: pts.append((int(math.floor(x + nx)), int(math.floor(y + ny)), CILIA))
            it.append(D(pts))
    for x in it: x.xf = xf
    return it


def base_leaves(cx, y, r=9.0, thick=1.3, extra=0.0):
    """las hojas de la base, fijas en la fila de abajo: la anclan al suelo"""
    return [P(E(cx - r * 0.75 - extra, y, r, thick, -8), LEAFD), P(E(cx + r * 0.75 + extra, y, r, thick, 8), LEAFD)]


def eyes(cx, y, gap, stun=False, xf=None, big=False):
    """2 ojos oblicuos de 3x3 (el usuario: que se lean); aturdida, dos aspas"""
    pts = []
    for s in (-1, 1):
        x0 = cx + s * gap - (1 if s < 0 else 1)
        if stun:
            for a, b in ((0, 0), (2, 0), (1, 1), (0, 2), (2, 2)): pts.append((x0 + a, y + b, PUPIL))
        else:
            for b in range(3):
                for a in range(3):
                    if b == 0 and ((s < 0 and a == 0) or (s > 0 and a == 2)): continue     # (ceño)
                    pts.append((x0 + a, y + b, EYE))
            pts.append((x0 + (1 if s > 0 else 1), y + 1, PUPIL)); pts.append((x0 + 1, y + 2, PUPIL))
    d = D(pts); d.xf = xf
    return d


def stem(pts, r=1.2, ramp=LEAFD, xf=None):
    p = P(tube(pts, r), ramp); p.xf = xf
    return p


# ── la FLOR de rocío: capas sueltas (flor abierta / capullo / gota) ───────────────────────────────────────────────
FLW, FLH = 19, 17
FLC = (9.5, 8.5)
DROP_AT = (13, 3)                     # (donde cae la gota, sobre el pétalo de arriba a la derecha)


def flower_open():
    cx, cy = FLC
    it = []
    for i in range(5):
        a = math.radians(-90 + i * 72)
        it.append(P(E(cx + math.cos(a) * 4.6, cy + math.sin(a) * 4.2, 3.3, 3.0), PINK))
    it.append(P(E(cx, cy, 2.6, 2.4), r3('8a5a10', 'd8a020', YEL)))
    return render(FLW, FLH, [(Xf(), it, None)])


def flower_bud():
    cx, cy = FLC
    it = [P(E(cx, cy + 0.5, 2.5, 3.8), PINK), P(E(cx, cy + 3.8, 2.6, 1.3), LEAFL)]
    return render(FLW, FLH, [(Xf(), it, None)])


def dew(on_bud=False):
    """la gota de rocío (la astilla): capa aparte para poder quitarla al robarla el Groove o al derrotarla"""
    im = Image.new('RGBA', (FLW, FLH), (0, 0, 0, 0))
    x, y = (10, 4) if on_bud else DROP_AT
    p = im.load()
    g, w, l = hx(GLASS), hx(GLASS_L), hx(GLASS_D)
    # (lágrima de 3x4 con su contorno: punta arriba, brillo arriba a la izquierda)
    p[x + 1, y - 1] = l
    for a, b in ((0, 0), (2, 0), (-1, 1), (3, 1), (-1, 2), (3, 2), (0, 3), (1, 3), (2, 3)): p[x + a, y + b] = l
    p[x + 1, y] = w
    p[x, y + 1] = w; p[x + 1, y + 1] = g; p[x + 2, y + 1] = g
    p[x, y + 2] = g; p[x + 1, y + 2] = g; p[x + 2, y + 2] = g
    return im


def icon(with_drop=True):
    """el coleccionable (17x13): flor de rocío con hoja; sin la astilla queda el hueco en el pétalo"""
    it = [P(E(3.8, 9.8, 3.2, 1.5, 20), LEAFL), P(E(13.2, 9.8, 3.2, 1.5, -20), LEAFL)]
    cx, cy = 8.5, 6.8
    shape = None                                             # (los pétalos, una sola forma: con un contorno por pétalo, a 17x13 son motas)
    for i in range(5):
        a = math.radians(-90 + i * 72)
        e = E(cx + math.cos(a) * 2.9, cy + math.sin(a) * 2.6, 2.3, 2.1)
        shape = e if shape is None else shape | e
    it.append(P(shape, PINK))
    it.append(P(E(cx, cy, 1.6, 1.5), r3('8a5a10', 'd8a020', YEL)))
    im = render(17, 13, [(Xf(), it, None)])
    p = im.load()
    x, y = 10, 2
    if with_drop:
        for a, b in ((1, -1), (0, 0), (2, 0), (-1, 1), (3, 1), (-1, 2), (3, 2), (0, 3), (1, 3), (2, 3)):
            if y + b >= 0: p[x + a, y + b] = hx(GLASS_D)
        p[x + 1, y] = hx(GLASS_L); p[x, y + 1] = hx(GLASS_L)
        for a, b in ((1, 1), (2, 1), (0, 2), (1, 2), (2, 2)): p[x + a, y + b] = hx(GLASS)
    else:
        for a, b in ((1, 1), (0, 2), (1, 2), (2, 2)): p[x + a, y + b] = hx('7a2440')
    return im


# ══ LOS CUATRO DISEÑOS ═══════════════════════════════════════════════════════════════════════════════════════════
# Cada uno: tamaño de la hoja, escala, y frame(nombre) → (items, ancla de la flor o None, 'bud'|'open', ancla de la boca)
FRAMES = ['idle1', 'idle2', 'tell', 'spit1', 'spit2', 'closed', 'gulp', 'blast', 'stun1', 'stun2']


# A «Cepo Real»: la planta tal cual, tumbada y enorme. Lo más fiel y lo más bajo: deja libre todo el aire.
def look_A(name):
    W, H = 56, 34
    cx, hy = 28, 31.0
    L, Wd = 25.0, 4.6
    lift = {'idle1': 6, 'idle2': 8, 'tell': 22, 'spit1': 16, 'spit2': 58, 'closed': 90, 'gulp': 90, 'blast': 40, 'stun1': -4, 'stun2': -4}[name]
    closed = name in ('closed', 'gulp')
    it = base_leaves(cx, H - 1.2, 12.0)
    if closed:
        it.append(stem([(cx, H - 1), (cx, hy - 3)], 1.5))
        it += trap((cx, hy - 3), 0, 0, 25.0, 6.0, closed=True, bulge=1.4 if name == 'gulp' else 0)
        return it, None, None, (cx, 3)
    fl, stage = None, None
    sway = {'idle2': 1, 'tell': -1}.get(name, 0)
    stun = name.startswith('stun')
    top = 9 if stun else 13
    if stun:
        fl, stage = (cx + (1 if name == 'stun2' else 0), top - 1), 'open'
        it.append(stem([(cx, hy), (cx + (1 if name == 'stun2' else 0), top)], 1.2))
    else:
        fl, stage = (cx + sway, top - 1), 'bud'
        it.append(stem([(cx, hy), (cx + sway, top)], 1.2))
    it += trap((cx, hy), 0, 90 - lift, L, Wd)
    it.append(P(E(cx, hy - 2.5, 5.5, 4.2), LEAFL))
    it.append(eyes(cx, int(hy - 5), 3, stun=stun))
    return it, fl, stage, (cx, hy - 8)


# B «Dama»: la más fina. Vestido de hojas, cintura estrecha y la trampa de corona en V. La flor al pecho, tras dos solapas.
def look_B(name):
    W, H = 48, 72
    cx = 24
    sway = {'idle1': 0, 'idle2': 2.0, 'tell': -3, 'spit1': -8, 'spit2': 10, 'closed': 0, 'gulp': 4, 'blast': -6, 'stun1': 0, 'stun2': 0}[name]
    up = Xf(rot=sway, pivot=(cx, 41))
    theta = {'idle1': 36, 'idle2': 33, 'tell': 58, 'spit1': 18, 'spit2': 50, 'blast': 66, 'stun1': 30, 'stun2': 34}.get(name, 0)
    stun = name.startswith('stun')
    closed = name in ('closed', 'gulp')
    it = base_leaves(cx, H - 1.2, 10.0, extra=1.0)
    # el vestido: 2 hojas largas de lado (oscuras) y una delante
    it.append(P(Pg([(cx - 3, 41), (cx + 3, 41), (cx + 12, H - 2), (cx + 3, H - 2)]), LEAFD))
    it.append(P(Pg([(cx - 3, 41), (cx + 3, 41), (cx - 3, H - 2), (cx - 12, H - 2)]), LEAFD))
    it.append(P(Pg([(cx - 2.6, 38), (cx + 2.6, 38), (cx + 6, H - 3), (cx, H - 1), (cx - 6, H - 3)]), LEAFL))
    it.append(D([(cx - 11 + i * 2, H - 2, CILIA) for i in range(12)]))
    # lo de arriba gira desde la cintura
    def U(p):
        p.xf = up
        return p
    if stun:                                                     # (el cuello se vence: la corona cuelga a un lado, boca abajo)
        drop = 1 if name == 'stun2' else 0
        it.append(stem(bez3((cx, 40), (cx + 3, 25), (cx + 14, 24), (cx + 15, 33 + drop), 8), 1.8, LEAFD))
        h2 = (cx + 15, 35 + drop)
        it.append(P(E(cx - 7, 38, 2.4, 7.0, -62), LEAFL))
        it.append(P(E(cx + 7, 38, 2.4, 7.0, 62), LEAFL))
        it += trap(h2, 180, theta * 0.5, 15.0, 3.0)
        it.append(P(E(h2[0], h2[1], 4.6, 3.6), LEAFL))
        it.append(eyes(h2[0], int(h2[1]) - 1, 2, stun=True))
        return it, (cx, 35), 'open', (cx, 30)
    it.append(U(stem([(cx, 41), (cx, 22)], 1.8, LEAFD)))
    if not stun:
        it.append(U(P(E(cx - 3.0, 33, 2.6, 7.0, -14), LEAFL)))
        it.append(U(P(E(cx + 3.0, 33, 2.6, 7.0, 14), LEAFL)))
    hinge = (cx, 19)
    it += trap(hinge, 0, theta, 17.0, 3.4, closed=closed, bulge=1.0 if name == 'gulp' else 0, xf=up)
    it.append(U(P(E(cx, 21, 4.6, 3.6), LEAFL)))
    it.append(eyes(cx, 19, 2, stun=stun, xf=up))
    mouth = up.fwd(cx, 8)
    # (el capullo con la gota, siempre a la vista: entre las solapas, como un broche)
    return it, up.fwd(cx, 29), 'bud', mouth


# C «Jarra»: atrevida. Una nepente alta y estrecha: la tapa es una valva y dentro de la boca negra brillan los ojos.
# La bomba se ve adónde va: al agujero. Aturdida, se vence a un lado y la flor asoma por la boca como una lengua.
def look_C(name):
    W, H = 84, 70
    cx = 30
    tilt = {'idle1': 0, 'idle2': 1.5, 'tell': -2, 'spit1': -5, 'spit2': 7, 'closed': 0, 'gulp': 0, 'blast': -3, 'stun1': 44, 'stun2': 47}[name]
    x = Xf(rot=tilt, pivot=(cx, 62))
    stun = name.startswith('stun')
    def bw(y):                                                   # (medio ancho de la jarra a la altura y)
        if y < 24: return 5.6 + (24 - y) * 0.45
        return 5.6 + 3.8 * math.sin(min(1, (y - 24) / 34) * math.pi) ** 0.8
    flask = Sh(lambda a, b: 17 <= b <= 59 and abs(a - cx) <= bw(b))
    it = base_leaves(cx, H - 1.2, 11.0)
    it.append(stem([(cx, H - 1), (cx - 1, 63), (cx, 58)], 1.6, LEAFD, xf=None))
    bump = Sh(lambda a, b: False)
    if name == 'gulp': bump = E(cx, 44, 12.0, 6.0)
    def X(p):
        p.xf = x
        return p
    it.append(X(P(flask | bump, LEAFL)))
    # franja magenta del vientre, para que no se funda con el fondo verde
    it.append(X(P(flask & Sh(lambda a, b: 28 <= b <= 34), INNER, line=False)))
    it.append(X(P(flask & Sh(lambda a, b: 37 <= b <= 40), INNER, line=False)))
    rimy = 16
    lid = {'idle1': 34, 'idle2': 28, 'tell': 74, 'spit1': 14, 'spit2': 92, 'blast': 110, 'stun1': 70, 'stun2': 74}.get(name)
    if lid is not None:                                          # (tapa abierta: una sola valva, bisagra atrás a la izquierda)
        h = (cx - 8, rimy - 2)
        a = 88 - lid
        whole, inner, _, rim = _lobe(h, a, 23.0, 5.0, 1)
        it.append(X(P(whole, LEAFL)))
        it.append(X(P(inner, INNER, line=False)))
        ar = math.radians(a)
        d = D([(int(px_), int(py_), CILIA) for px_, py_ in rim[1::2]] + [(int(px_ + math.cos(ar)), int(py_ + math.sin(ar)), CILIA) for px_, py_ in rim[1::2]])
        d.xf = x
        it.append(d)
    it.append(X(P(E(cx, rimy, 10.6, 5.2), INNER)))
    it.append(X(P(E(cx, rimy + 0.6, 7.4, 3.4), HOLE, line=False, shade='none')))
    if lid is not None:
        it.append(eyes(cx, rimy - 1, 3, stun=False, xf=x) if not stun else D([]))
    if lid is not None:                                          # (pestañas colgando del labio: la misma planta)
        d = D([(cx - 9 + i * 2, rimy + 5, CILIA) for i in range(10)] + [(cx - 9 + i * 2, rimy + 6, CILIA) for i in range(10)]); d.xf = x
        it.append(d)
    if lid is None:                                              # (tapa cerrada sobre la boca)
        it.append(X(P(E(cx - 0.5, rimy - 2.2, 12.5, 4.2, -3), LEAFL)))
        d = D([(cx - 11 + i * 2, rimy + 2, CILIA) for i in range(12)]); d.xf = x
        it.append(d)
    mouth = x.fwd(cx, rimy)
    if stun:
        tip = (mouth[0] + 7, mouth[1] - 7 + (1 if name == 'stun2' else 0))
        it.append(stem([mouth, tip], 1.2))
        return it, tip, 'open', mouth
    # (el capullo con la gota, prendido en el labio como una flor en el pelo)
    return it, x.fwd(cx + 10, rimy - 2), 'bud', mouth


# D «Abanico»: la más rara. Un tallo muy fino y una rueda de valvas estrechas, con cara en el centro.
# Se cierra entera como un tulipán al tragar; aturdida, las valvas cuelgan como un girasol mustio.
def look_D(name):
    W, H = 60, 66
    cx = 30
    c = (cx, 25)
    spread = {'idle1': 76, 'idle2': 72, 'tell': 96, 'spit1': 50, 'spit2': 92, 'closed': 14, 'gulp': 16, 'blast': 104, 'stun1': 152, 'stun2': 156}[name]
    n = 7
    L, Wd = 24.0, 2.7
    stun = name.startswith('stun')
    it = base_leaves(cx, H - 1.2, 11.0)
    it.append(stem([(cx, H - 1), (cx + 1, 48), (cx, 28)], 1.5, LEAFD))
    it.append(P(E(cx - 4, 50, 5, 1.6, 30), LEAFD))
    it.append(P(E(cx + 5, 42, 5, 1.6, -30), LEAFD))
    order = [0, 6, 1, 5, 2, 4, 3]
    for i in order:
        a = -spread + i * 2 * spread / (n - 1)
        whole, inner, _, rim = _lobe(c, a, L, Wd, 1 if a <= 0 else -1)
        ar = math.radians(a)
        d_ = (math.sin(ar), -math.cos(ar))
        it.append(P(whole, LEAFL))
        it.append(P(E(c[0] + d_[0] * (L * 0.56), c[1] + d_[1] * (L * 0.56), L * 0.34, Wd * 0.5, a - 90), INNER, line=False, shade='none'))
        tp = (c[0] + d_[0] * (L + 1), c[1] + d_[1] * (L + 1))
        it.append(D([(int(tp[0]), int(tp[1]), CILIA), (int(tp[0] + d_[0]), int(tp[1] + d_[1]), CILIA)]))
    closed = name in ('closed', 'gulp')
    if closed:
        it.append(P(E(cx, 25, 5.4 + (1.2 if name == 'gulp' else 0), 6.5), LEAFL))
        it.append(eyes(cx, 22, 2))
        return it, (cx, 12), 'bud', (cx, 10)
    it.append(P(E(cx, 25, 7.6, 7.6), LEAFL))
    it.append(P(E(cx, 26, 5.6, 5.4), INNER, line=False))
    open_h = {'tell': 3.4, 'spit1': 1.4, 'spit2': 3.4, 'blast': 4.0}.get(name, 2.2)
    it.append(P(E(cx, 28, 3.0, open_h), HOLE, line=False, shade='none'))
    it.append(eyes(cx, 21, 3, stun=stun))
    if stun:
        it.append(stem([(cx, 19), (cx + (1 if name == 'stun2' else 0), 10)], 1.2))
        return it, (cx + (1 if name == 'stun2' else 0), 8), 'open', c
    # (el capullo con la gota, de tiara sobre la cara)
    return it, (cx, 13), 'bud', c


LOOKS = {
    'A': dict(name='Cepo Real', fn=look_A, W=56, H=34, k=5, pad=4, cx=28, seg=(3.2, 2.9, 2.6, 2.2, 1.8), head=dict(L=18, W=4.8, three=False, lid=False), seed='pip',
              desc='la planta tal cual, tumbada y enorme'),
    'B': dict(name='Dama', fn=look_B, W=48, H=72, k=5, pad=3, cx=24, seg=(2.4, 2.2, 2.0, 1.8, 1.5), head=dict(L=20, W=3.4, three=False, lid=False), seed='spindle',
              desc='vestido de hojas, cintura fina, corona de cepo'),
    'C': dict(name='Jarra', fn=look_C, W=84, H=70, k=5, pad=13, cx=30, seg=(2.8, 2.6, 2.3, 2.0, 1.7), head=dict(L=17, W=4.2, three=False, lid=True), seed='drop',
              desc='nepente alta: los ojos en la boca negra'),
    'D': dict(name='Abanico', fn=look_D, W=60, H=66, k=5, pad=3, cx=30, seg=(2.6, 2.3, 2.1, 1.8, 1.5), head=dict(L=18, W=3.2, three=True, lid=False), seed='star',
              desc='tallo fino y rueda de valvas con cara'),
}
SEG_N = 11


class Kit:
    """todas las piezas de un diseño (a 1x en .art, a la escala k en lo demás), como las cargaría el juego"""
    def __init__(self, lid):
        self.id, self.L = lid, LOOKS[lid]
        self.k = k = self.L['k']
        self.up = lambda im, m=None: im.resize((im.width * (m or k), im.height * (m or k)), Image.NEAREST)
        W, H = self.L['W'], self.L['H']
        self.art, self.anchor = {}, {}
        pad = self.pad = self.L['pad']                           # (filas de más arriba: que nada toque el borde)
        H = self.L['HH'] = H + pad
        for f in FRAMES:
            items, fl, stage, mouth = self.L['fn'](f)
            self.art[f] = render(W, H, [(Xf(dy=pad), items, None)])
            self.anchor[f] = ((fl[0], fl[1] + pad) if fl else None, stage, (mouth[0], mouth[1] + pad))
        self.body = {f: self.up(a) for f, a in self.art.items()}
        self.fl_art = {'open': flower_open(), 'bud': flower_bud()}
        self.fl = {s: self.up(a) for s, a in self.fl_art.items()}
        self.fl_hit = {s: flash_white(a) for s, a in self.fl.items()}
        self.drop_art = {'open': dew(False), 'bud': dew(True)}
        self.drop = {s: self.up(a) for s, a in self.drop_art.items()}
        self.seg_art = [self.segment(r) for r in self.L['seg']]
        self.segs = [[self.up(p) for p in a] for a in self.seg_art]
        self.head_art = {}
        self.seed_art = [self.seed(i) for i in range(4)]
        self.seeds = [self.up(a, SMALL_K) for a in self.seed_art]
        self.socket_art = [self.socket(i) for i in range(3)]

    # ── la flor sobre un cuadro del cuerpo ──
    def draw_body(self, c, frame, x, floor, hit=False, tint=None):
        k = self.k
        W, H = self.L['W'], self.L['HH']
        ox, oy = int(x - self.L['cx'] * k), int(floor - H * k + k)      # (1 píxel de arte dentro del suelo, como Kit.SINK)
        b = self.body[frame]
        c.alpha_composite(b, (ox, oy))
        fl, stage, mouth = self.anchor[frame]
        if fl:
            im = self.fl_hit[stage] if hit else self.fl[stage]
            px_, py_ = ox + int(fl[0]) * k - int(FLC[0] * k), oy + int(fl[1]) * k - int(FLC[1] * k)
            c.alpha_composite(im, (px_, py_))
            if not hit: c.alpha_composite(self.drop[stage], (px_, py_))
        return (ox + mouth[0] * k, oy + mouth[1] * k), ((ox + fl[0] * k, oy + fl[1] * k) if fl else None)

    def segment(self, r):
        """un disco del tallo, en 3 capas: contorno, sombra y luz. El juego pinta TODOS los contornos de la cadena, luego
        todas las sombras y luego las luces: sale un tubo liso de 3 tonos, sin las rayas de discos apilados"""
        n = SEG_N; cc = n / 2
        o = render(n, n, [(Xf(), [P(E(cc, cc, r + 1, r + 1), r3(LEAF[0], LEAF[0], LEAF[0]), line=False, shade='none')], None)])
        s_ = render(n, n, [(Xf(), [P(E(cc, cc, r, r), r3(LEAF[2], LEAF[2], LEAF[2]), line=False, shade='none')], None)])
        l = render(n, n, [(Xf(), [P(E(cc - 0.5, cc - 0.5, max(0.8, r - 0.9), max(0.8, r - 0.9)), r3(LEAF[3], LEAF[3], LEAF[3]), line=False, shade='none')], None)])
        return o, s_, l

    def head(self, d16, op):
        """la cabeza que brota, en una de 16 direcciones (0 = derecha) y abierta op (0 cerrada, 1 media, 2 del todo, 3 con presa)"""
        key = (d16, op)
        if key in self.head_art: return self.head_art[key]
        h = self.L['head']
        n = 2 * (h['L'] + 13)
        c = (n / 2, n / 2)
        ha = d16 * 360 / 16 + 90
        th = {0: 0, 1: 22, 2: 50, 3: 0}[op]
        it = []
        if h['lid']:                                               # (C: una copa con su tapa)
            ar = math.radians(ha)
            dx, dy = math.sin(ar), -math.cos(ar)
            nx_, ny_ = -dy, dx
            bl = 1.2 if op == 3 else 0
            q = h['L'] / 13                                        # (la copa crece con el largo de la cabeza)
            it.append(P(E(c[0] + dx * 5.5 * q, c[1] + dy * 5.5 * q, 6.5 * q, 4.4 * q + bl, ha - 90), LEAFL))
            rc = (c[0] + dx * 11 * q, c[1] + dy * 11 * q)
            it.append(P(E(rc[0], rc[1], 2.4 * q, 6.2 * q, ha - 90), INNER))
            if op in (1, 2):
                it.append(P(E(rc[0] + dx * 0.4, rc[1] + dy * 0.4, 1.2 * q, 4.2 * q, ha - 90), HOLE, line=False, shade='none'))
                hg = (rc[0] - nx_ * 6 * q, rc[1] - ny_ * 6 * q)
                whole, inner, _, _r = _lobe(hg, ha + th * 0.9 + 6, 12.0 * q, 3.2 * q, 1)
                it.append(P(whole, LEAFL)); it.append(P(inner, INNER, line=False))
            else:
                it.append(P(E(rc[0] + dx * 1.2 * q, rc[1] + dy * 1.2 * q, 2.2 * q, 6.6 * q, ha - 90), LEAFL))
        elif h['three']:                                           # (D: tres valvas estrechas)
            if op in (0, 3):
                it += trap(c, ha, 0, h['L'], h['W'] + 0.8, closed=True, bulge=1.2 if op == 3 else 0)
            else:
                for a in (ha - th * 1.2, ha + th * 1.2, ha):
                    whole, inner, _, rim = _lobe(c, a, h['L'], h['W'], 1)
                    it.append(P(whole, LEAFL)); it.append(P(inner, INNER, line=False))
                    ar = math.radians(a)
                    tip = (c[0] + math.sin(ar) * (h['L'] + 1), c[1] - math.cos(ar) * (h['L'] + 1))
                    it.append(D([(int(tip[0]), int(tip[1]), CILIA)]))
        else:
            it += trap(c, ha, th, h['L'], h['W'], closed=op in (0, 3), bulge=1.2 if op == 3 else 0)
        it.append(P(E(c[0], c[1], 2.8, 2.8), LEAFD))
        im = self.up(render(n, n, [(Xf(), it, None)]))
        self.head_art[key] = im
        return im

    def seed(self, i):
        """la semilla que escupe, en 4 giros (a la escala de la planta pequeña)"""
        n = 11; cc = 5.5
        rot = i * 45
        kind = self.L['seed']
        SEED = r3('2a1408', '6a3a1a', 'a8703a')
        it = []
        if kind == 'pip':
            it = [P(E(cc, cc, 3.8, 2.6, rot), SEED), P(E(cc, cc, 1.8, 1.0, rot), INNER, line=False, shade='none')]
        elif kind == 'spindle':
            it = [P(E(cc, cc, 4.6, 1.7, rot), r3('4a0c26', '9a1c4a', 'd0407a')), P(E(cc, cc, 1.5, 1.0, rot), r3('2a1408', 'e4f4a8', 'e4f4a8'), line=False, shade='none')]
        elif kind == 'drop':
            ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
            it = [P(E(cc, cc, 3.0, 3.0) | Pg([(cc + ca * 5, cc + sa * 5), (cc - sa * 2.6, cc + ca * 2.6), (cc + sa * 2.6, cc - ca * 2.6)]), SEED)]
        else:
            it = []
            for a in range(4):
                ang = rot + a * 90
                it.append(P(E(cc + math.cos(math.radians(ang)) * 2.5, cc + math.sin(math.radians(ang)) * 2.5, 2.6, 1.2, ang), INNER))
            it.append(P(E(cc, cc, 1.5, 1.5), SEED, line=False, shade='none'))
        return render(n, n, [(Xf(), it, None)])

    def socket(self, i):
        """el agujero por donde brota (visto en el suelo; la pared y el techo lo giran): grieta → boca de hojas"""
        w, h = 30, 10
        it = []
        rx = (5, 9, 12)[i]
        it.append(P(E(15, 8.2, rx, 1.3 + i * 0.3), HOLE, shade='none'))
        if i:
            it.append(P(E(15 - rx, 7.4, 4 + i, 1.1, 24), LEAFD))
            it.append(P(E(15 + rx, 7.4, 4 + i, 1.1, -24), LEAFD))
        return render(w, h, [(Xf(), it, None)])


# ── el fondo: el templo de verdad ─────────────────────────────────────────────────────────────────────────────────
def load(rel):
    return Image.open(os.path.join(ROOT, rel)).convert('RGBA')


GRAD_TEMPLE = 14


def temple_room(w, h, walls=True):
    """la sala: degradado + pared lejana + arcadas + raíces del fondo `temple`, con suelo, techo y paredes de sillar + musgo"""
    S = 4
    g = load('assets/images/world/sky/gradients.png').crop((GRAD_TEMPLE * 8, 0, GRAD_TEMPLE * 8 + 8, 180))
    bg = g.resize((w, h), Image.NEAREST)
    wall = load('assets/images/world/sky/temple_wall.png'); wall = wall.resize((wall.width * S, wall.height * S), Image.NEAREST)
    wall.putalpha(wall.getchannel('A').point(lambda v: int(v * 0.9)))
    for y in range(0, h, wall.height):
        for x in range(0, w, wall.width): bg.alpha_composite(wall, (x, y))
    gy = h - 64
    for name, top in (('far', False), ('mid', False), ('top', True)):
        lay = load(f'assets/images/world/sky/temple_{name}.png'); lay = lay.resize((lay.width * S, lay.height * S), Image.NEAREST)
        y = (64 if walls else 0) if top else gy - lay.height
        for x in range(0, w, lay.width): bg.alpha_composite(lay, (x, y))
    tex = load('assets/images/world/tiles/temple_brick.png')
    moss = load('assets/images/world/tiles/temple_moss.png')
    def brick(x, y): bg.alpha_composite(tex.crop((x % 256 // 64 * 64, y % 256 // 64 * 64, x % 256 // 64 * 64 + 64, y % 256 // 64 * 64 + 64)), (x, y))
    for x in range(0, w, 64):
        brick(x, gy)
        if walls: brick(x, 0)
    if walls:
        for y in range(0, h, 64):
            brick(0, y); brick(w - 64 if w % 64 == 0 else w // 64 * 64, y)
    for x in range(64 if walls else 0, w - (64 if walls else 0), 64): bg.alpha_composite(moss, (x, gy))
    return bg, gy


def player():
    im = load('assets/images/player/monstrito1.png')
    return im.resize((im.width * PLAYER_K, im.height * PLAYER_K), Image.NEAREST)


def bomb():
    im = load('assets/images/enemies/bomb/bombObject-Sheet.png').crop((1, 0, 14, 16))
    return im.resize((im.width * SMALL_K, im.height * SMALL_K), Image.NEAREST)


PLANT_ART = load('assets/images/enemies/carnivoreplant/plant-Sheet.png')
def small_plant(i=0):
    im = PLANT_ART.crop((i * 26, 0, (i + 1) * 26, 24))
    return im.resize((26 * SMALL_K, 24 * SMALL_K), Image.NEAREST)


def sprout(i):
    """de semilla a planta: 2 cuadros de brote; luego ya es la Planta Carnívora normal (la hoja del juego, sin tocar)"""
    it = [P(E(8.5, 15, 4.5, 1.2), LEAFD)]
    if i == 0:
        it += [stem([(8.5, 15), (8.5, 12)], 0.7), P(E(7, 11, 2, 1, 20), LEAFL), P(E(10, 11, 2, 1, -20), LEAFL)]
    else:
        it += [stem([(8.5, 15), (8.5, 9)], 0.8), P(E(5.5, 8.5, 3.5, 1.2, 15), LEAFL), P(E(11.5, 8.5, 3.5, 1.2, -15), LEAFL),
               P(E(8.5, 6.5, 1.3, 1.2), PINK)]
    return render(17, 16, [(Xf(), it, None)])


STARS = load('assets/images/bosses/common/stars-Sheet.png')


def stars(i):
    h = STARS.height
    n = STARS.width // h
    im = STARS.crop((i % n * h, 0, i % n * h + h, h))
    return im.resize((h * 5, h * 5), Image.NEAREST)


BOOM = load('assets/images/enemies/bomb/explosion-Sheet.png')


def boom(i):
    im = BOOM.crop((i * 48, 0, i * 48 + 48, 48))
    return im.resize((48 * 3, 48 * 3), Image.NEAREST)


# ══ SOLO LA CADENA: las poses de las bocas (lo que haría el juego con SegmentChain.lua) ═══════════════════════════
class Mouth:
    """una boca que brota: base fija en el suelo / la pared / el techo; discos con muelle y la cabeza en la punta"""
    def __init__(self, K, base, normal, reach):
        # (los discos siempre se solapan: a más distancia, más discos, nunca más separados)
        self.K, self.base, self.nrm = K, base, normal
        self.gap = 2.0 * K.k
        n = self.n = max(6, int(math.hypot(reach[0] - base[0], reach[1] - base[1]) * 1.2 / self.gap) + 1)
        self.ch = Chain(base, n, 0.1)
        self.ch.P = [list(base) for _ in range(n)]
        self.ext = 0.0

    def step(self, target, ext, wob=0.0):
        """target: adonde va la cabeza; ext (0..1): cuánto ha salido"""
        self.ext = ext
        self.ch.gap = max(0.1, self.gap * ext)
        b, nx, ny = self.base, self.nrm[0], self.nrm[1]
        tx, ty = b[0] + (target[0] - b[0]) * ext, b[1] + (target[1] - b[1]) * ext
        px_, py_ = -ny, nx                                              # (ladeada: la S del tallo)
        p1 = (b[0] + nx * 70 * ext + px_ * 46 * ext, b[1] + ny * 70 * ext + py_ * 46 * ext)
        p2 = (tx - nx * 40 * ext - px_ * 40 * ext + wob, ty - ny * 40 * ext - py_ * 40 * ext)
        tg = bez3(b, p1, p2, (tx, ty), self.n)
        self.ch.step(b, tg, k=0.5, damp=0.45)

    def draw(self, c, op):
        K = self.K
        ch = self.ch
        for layer in range(3):                                          # (contornos, sombras, luces: ver Kit.segment)
            for i in range(ch.n - 1):
                s = K.segs[min(len(K.segs) - 1, i * len(K.segs) // ch.n)][layer]
                c.alpha_composite(s, (int(ch.P[i][0] - s.width / 2), int(ch.P[i][1] - s.height / 2)))
        d = round(ch.tip_angle() / TAU * 16) % 16
        h = K.head(d, op)
        c.alpha_composite(h, (int(ch.P[-1][0] - h.width / 2), int(ch.P[-1][1] - h.height / 2)))


def put_socket(K, c, x, y, side, i):
    s = K.up(K.socket_art[i])
    if side == 'ceil': s = s.transpose(Image.FLIP_TOP_BOTTOM)
    elif side == 'wallL': s = s.transpose(Image.ROTATE_270)
    elif side == 'wallR': s = s.transpose(Image.ROTATE_90)
    c.alpha_composite(s, (int(x - s.width / 2), int(y - s.height / 2)) if side.startswith('wall') else (int(x - s.width / 2), int(y - s.height + K.k * 1) if side == 'floor' else int(y - K.k)))


# ── cuadros fijos para comparar ───────────────────────────────────────────────────────────────────────────────────
def still(K, w, h, frame='idle1', mouth=True):
    """el diseño sobre el templo, a escala real, junto al jugador y la planta pequeña; una boca fuera, una semilla en el aire"""
    c, gy = temple_room(w, h, walls=False)
    x = w // 2 - 40
    K.draw_body(c, frame, x, gy)
    pl = player()
    c.alpha_composite(pl, (w - pl.width - 60, gy - pl.height))
    sp = small_plant(0)
    c.alpha_composite(sp, (30, gy - sp.height + 4))
    if mouth:
        m = Mouth(K, (w - 190, gy), (0, -1), (w - 150, gy - 170))
        for _ in range(24): m.step((w - 150, gy - 170), 1.0)
        put_socket(K, c, w - 190, gy, 'floor', 2)
        m.draw(c, 2)
    s = K.seeds[1]
    c.alpha_composite(s, (150, gy - 190))
    return c


def parts_sheet(K):
    """la hoja de piezas de un diseño: el cuerpo en todos sus cuadros, flor y gota por capas, discos, cabezas, semillas…"""
    L = K.L
    m = 4 if L['H'] < 50 else 3
    bw, bh = L['W'] * m + 8, L['HH'] * m + 26
    cols = len(FRAMES)
    cw = max(1300, bw * 5 + 20)
    rows = 2
    c = Image.new('RGBA', (cw, bh * rows + 620), (58, 62, 54, 255))
    d = ImageDraw.Draw(c)
    text(d, (10, 6), f'{K.id} «{L["name"]}»  - cuerpo {L["W"]}x{L["HH"]} ×{K.k} = {L["W"] * K.k}x{L["HH"] * K.k} px  (aquí ×{m})', (255, 240, 170, 255), FONT_B)
    y0 = 36
    for i, f in enumerate(FRAMES):
        x, y = 10 + (i % 5) * bw, y0 + (i // 5) * bh
        im = K.art[f].copy()
        fl, st, _ = K.anchor[f]
        if fl:
            layer = Image.new('RGBA', im.size, (0, 0, 0, 0))
            layer.alpha_composite(K.fl_art[st], (max(0, int(fl[0] - FLC[0])), max(0, int(fl[1] - FLC[1])))) if fl[1] - FLC[1] >= 0 else None
            layer.alpha_composite(K.drop_art[st], (max(0, int(fl[0] - FLC[0])), max(0, int(fl[1] - FLC[1])))) if fl[1] - FLC[1] >= 0 else None
            im.alpha_composite(layer)
        c.alpha_composite(K.up(im, m), (x, y + 18))
        text(d, (x + 2, y), f)
    y = y0 + 2 * bh + 4
    text(d, (10, y), 'capas (×6): flor abierta · capullo · gota (astilla) · flor con gota · sin gota al derrotarla'); y += 22
    x = 10
    for a in (K.fl_art['open'], K.fl_art['bud'], K.drop_art['open']):
        c.alpha_composite(K.up(a, 6), (x, y)); x += FLW * 6 + 10
    tog = K.fl_art['open'].copy(); tog.alpha_composite(K.drop_art['open'])
    c.alpha_composite(K.up(tog, 6), (x, y)); x += FLW * 6 + 10
    c.alpha_composite(K.up(K.fl_art['open'], 6), (x, y)); x += FLW * 6 + 30
    text(d, (x, y), 'icono 17x13 (×6): con y sin astilla')
    c.alpha_composite(K.up(icon(True), 6), (x, y + 20)); c.alpha_composite(K.up(icon(False), 6), (x + 112, y + 20))
    c.alpha_composite(icon(True), (x + 224, y + 20)); c.alpha_composite(icon(False), (x + 244, y + 20))
    y += FLH * 6 + 10
    text(d, (10, y), 'boca que brota: 16 direcciones (se muestran 8) ·  cerrada · media · abierta · con presa ·  discos del tallo ·  semilla ·  agujero'); y += 22
    x = 10
    for op, dirs in ((2, range(0, 16, 4)), (0, (12,)), (1, (12,)), (3, (12,))):
        for di in dirs:
            h = K.head(di, op).resize((K.head(di, op).width // K.k * 3, K.head(di, op).height // K.k * 3), Image.NEAREST)
            c.alpha_composite(h, (x, y)); x += h.width + 2
    x = 10; y += 2 * (L['head']['L'] + 13) * 3 + 6
    for a in K.seg_art:
        t_ = a[0].copy(); t_.alpha_composite(a[1]); t_.alpha_composite(a[2])
        c.alpha_composite(K.up(t_, 5), (x, y)); x += SEG_N * 5
    x += 20
    for a in K.seed_art:
        c.alpha_composite(K.up(a, 5), (x, y)); x += 58
    x += 20
    for a in K.socket_art:
        c.alpha_composite(K.up(a, 4), (x, y)); x += 126
    for i in range(2):
        s = sprout(i); c.alpha_composite(K.up(s, 4), (x, y)); x += 72
    c.convert('RGB').save(os.path.join(OUT, f'piezas_{K.id}.png'))


def overview(kits):
    tw, th = 820, 520
    rows = len(kits)
    sil_h = 260
    sh = Image.new('RGB', (tw * 2 + 10, th * rows + sil_h), (24, 18, 22))
    for n, (i, K) in enumerate(kits.items()):
        a = still(K, tw, th, 'idle1')
        b = still(K, tw, th, 'stun1', mouth=False)
        sh.paste(a.convert('RGB'), (0, n * th)); sh.paste(b.convert('RGB'), (tw + 10, n * th))
        d = ImageDraw.Draw(sh)
        text(d, (12, n * th + 8), f'{i} «{K.L["name"]}»: {K.L["desc"]}', (255, 240, 170, 255), FONT_B)
        text(d, (tw + 22, n * th + 8), f'aturdida, con la flor al aire · ×{K.k}, {K.L["W"] * K.k}x{K.L["HH"] * K.k} px', (255, 240, 170, 255))
    # las siluetas en negro: si no se distinguen aquí, no son diseños distintos
    y = th * rows
    d = ImageDraw.Draw(sh)
    d.rectangle((0, y, tw * 2 + 10, y + sil_h), fill=(200, 200, 190))
    x = 16
    for i, K in kits.items():
        for f in ('idle1', 'closed'):
            im = K.up(K.art[f], K.k // 2 if K.k > 3 else 1)
            r, g, b, a = im.split()
            blk = Image.merge('RGBA', (r.point(lambda v: 20), g.point(lambda v: 20), b.point(lambda v: 20), a))
            sh.paste(blk, (x, y + sil_h - im.height - 8), blk)
            x += im.width + 12
        x += 14
    pl = player(); r, g, b, a = pl.split()
    blk = Image.merge('RGBA', (r.point(lambda v: 90), g.point(lambda v: 20), b.point(lambda v: 20), a))
    blk = blk.resize((pl.width // 2, pl.height // 2), Image.NEAREST)
    sh.paste(blk, (x, y + sil_h - blk.height - 8), blk)
    sh.save(os.path.join(OUT, 'vista_previa.png'))


# ══ LA PELEA EN GIF: reposo · boca del suelo · de la pared · del techo (atrapa) · semilla · bomba · aturdida · golpe ═══
FPS = 20
SEQ = [('reposo', 24), ('suelo_aviso', 10), ('suelo_sale', 8), ('suelo_muerde', 6), ('suelo_vuelve', 8),
       ('pared_aviso', 10), ('pared_sale', 8), ('pared_muerde', 6), ('pared_vuelve', 8),
       ('techo_aviso', 10), ('techo_sale', 6), ('techo_traga', 22), ('techo_suelta', 8),
       ('escupe_carga', 8), ('escupe', 18), ('brota', 14), ('reposo2', 10),
       ('bomba', 16), ('traga', 10), ('explota', 10), ('aturdida', 28), ('salto', 12), ('golpe', 8), ('recupera', 10)]
LABELS = {'reposo': 'reposo', 'suelo_aviso': 'aviso: se abre el suelo', 'suelo_sale': 'brota una boca', 'suelo_muerde': 'muerde', 'suelo_vuelve': '',
          'pared_aviso': 'aviso: la pared', 'pared_sale': 'brota de la pared', 'pared_muerde': 'muerde', 'pared_vuelve': '',
          'techo_aviso': 'aviso: el techo', 'techo_sale': 'baja del techo', 'techo_traga': 'te traga: machaca botones', 'techo_suelta': 'te suelta',
          'escupe_carga': 'coge aire', 'escupe': 'escupe una semilla', 'brota': 'la semilla brota: planta pequeña', 'reposo2': '',
          'bomba': 'le lanzas una bomba', 'traga': 'se la traga', 'explota': 'le explota dentro', 'aturdida': 'aturdida: la flor al aire',
          'salto': 'a por la flor', 'golpe': 'GOLPE', 'recupera': ''}


def fight_gif(K):
    w, h = 1280, 704
    room, gy = temple_room(w, h)
    pl = player()
    bm = bomb()
    x0 = w // 2
    tl = []
    for s, d in SEQ: tl += [(s, i, d) for i in range(d)]
    floor_b, wall_b, ceil_b = (930, gy), (64, 430), (900, 64)
    T_FLOOR, T_WALL, T_CEIL = (1070, gy - 150), (290, gy - 130), (925, gy - 100)
    m_floor = Mouth(K, floor_b, (0, -1), T_FLOOR)
    m_wall = Mouth(K, wall_b, (1, 0), T_WALL)
    m_ceil = Mouth(K, ceil_b, (0, 1), T_CEIL)
    plant_x = 250
    frames = []
    for f, (st, i, d) in enumerate(tl):
        c = room.copy()
        t = i / max(1, d - 1)
        tick = f // 8
        # cuadro del cuerpo
        body = 'idle1' if tick % 2 == 0 else 'idle2'
        if st == 'escupe_carga': body = 'spit1'
        elif st == 'escupe': body = 'spit2' if i < 8 else body
        elif st == 'traga': body = 'closed' if i < 3 else 'gulp'
        elif st == 'explota': body = 'blast'
        elif st == 'bomba' and i > 8: body = 'tell'
        elif st in ('aturdida', 'salto'): body = 'stun1' if tick % 2 == 0 else 'stun2'
        elif st == 'golpe': body = 'stun1'
        hit = st == 'golpe' and i % 2 == 0
        # jugador
        p = 1040
        if st.startswith('suelo'): p = 1040 if st != 'suelo_muerde' else 1090
        elif st.startswith('pared'): p = 200 + (120 if st == 'pared_muerde' else 0)
        elif st == 'techo_aviso': p = 200 + t * 700
        elif st.startswith('techo'): p = 900
        elif st in ('escupe_carga', 'escupe', 'brota', 'reposo2'): p = 950 + 50 * min(1, f / 400)
        elif st in ('bomba', 'traga', 'explota'): p = 1000
        elif st == 'aturdida': p = 1000 - t * 240
        elif st in ('salto', 'golpe', 'recupera'): p = 760
        py = gy - pl.height
        # la ranura de cada boca y la boca
        def mouth_phase(prefix, m, base, side, target, grabbed=False):
            ph = None
            for sfx in ('aviso', 'sale', 'muerde', 'vuelve', 'traga', 'suelta'):
                if st == f'{prefix}_{sfx}': ph = sfx
            if ph is None: return
            if ph == 'aviso':
                put_socket(K, c, base[0], base[1], side, 0 if i < 5 else 1)
                m.step(target, 0.02)
                return
            put_socket(K, c, base[0], base[1], side, 2)
            if ph == 'sale':
                m.step(target, min(1.0, 0.25 + t)); m.draw(c, 2 if t > 0.3 else 1)
            elif ph in ('muerde',):
                m.step(target, 1.0); m.draw(c, 1 if i < 1 else 0)
            elif ph == 'traga':
                m.step(target, 1.0); m.draw(c, 3 if i % 6 < 3 else 0)
            elif ph in ('vuelve', 'suelta'):
                m.step(target, max(0.02, 1 - t)); m.draw(c, 0 if ph == 'vuelve' else 2)
        # orden: planta y fondo, cuerpo, luego las bocas y por encima el jugador
        if st in ('brota',):
            s = sprout(0 if i < 5 else 1) if i < 10 else None
            if s is not None:
                s = K.up(s, SMALL_K); c.alpha_composite(s, (plant_x - s.width // 2, gy - s.height + 4))
            else:
                sp = small_plant(0); c.alpha_composite(sp, (plant_x - sp.width // 2, gy - sp.height + 4))
        elif tl.index((st, i, d)) > idx_of(tl, 'brota'):
            sp = small_plant(tick % 2); c.alpha_composite(sp, (plant_x - sp.width // 2, gy - sp.height + 4))
        mouth_at, fl_at = K.draw_body(c, body, x0, gy, hit=hit)
        if st in ('aturdida', 'salto', 'golpe'):
            ax = fl_at or (x0, gy - 200)
            for a in range(4):                                   # (la corona de estrellas del juego, girando sobre la flor)
                ang = f * 0.35 + a * TAU / 4
                s = stars(f // 3 + a)
                c.alpha_composite(s, (int(ax[0] + math.cos(ang) * 70 - s.width / 2), int(ax[1] - 11 * K.k - 12 + math.sin(ang) * 14)))
        if st == 'explota':
            s = boom(i)
            c.alpha_composite(s, (int(mouth_at[0] - s.width / 2), int(mouth_at[1] - s.height / 2)))
        # jugador (no se dibuja cuando está tragado)
        if not st == 'techo_traga':
            if st == 'salto':
                ax = fl_at or (x0, gy - 200)
                sx, sy = 760, gy - pl.height
                tx, ty = ax[0] - pl.width / 2, ax[1] - 7 * K.k - pl.height
                u = t
                xx = sx + (tx - sx) * u
                yy = sy + (ty - sy) * u - math.sin(u * math.pi) * 110
                c.alpha_composite(pl, (int(xx), int(yy)))
            elif st == 'golpe':
                ax = fl_at or (x0, gy - 200)
                c.alpha_composite(pl, (int(ax[0] - pl.width / 2), int(ax[1] - 7 * K.k - pl.height)))
            elif st == 'recupera':
                c.alpha_composite(pl, (int(x0 + 200 + t * 200), int(gy - pl.height - math.sin(t * math.pi) * 120)))
            else:
                c.alpha_composite(pl, (int(p), py))
        mouth_phase('suelo', m_floor, floor_b, 'floor', T_FLOOR)
        mouth_phase('pared', m_wall, wall_b, 'wallL', T_WALL)
        mouth_phase('techo', m_ceil, ceil_b, 'ceil', T_CEIL)
        # semilla
        if st == 'escupe' and i >= 2:
            u = (i - 2) / (d - 3)
            sx, sy = mouth_at
            xx = sx + (plant_x - sx) * u
            yy = sy + (gy - 14 - sy) * u - math.sin(u * math.pi) * 150
            s = K.seeds[i % 4]
            c.alpha_composite(s, (int(xx - s.width / 2), int(yy - s.height / 2)))
        # bomba
        if st == 'bomba':
            u = t
            sx, sy = 1010, gy - 90
            tx, ty = mouth_at
            xx = sx + (tx - sx) * u
            yy = sy + (ty - sy) * u - math.sin(u * math.pi) * 170
            c.alpha_composite(bm, (int(xx - bm.width / 2), int(yy - bm.height / 2)))
        dd = ImageDraw.Draw(c)
        text(dd, (84, 76), f'{K.id} «{K.L["name"]}» — {LABELS[st]}', (255, 240, 170, 255), FONT_B)
        if st == 'techo_traga': text(dd, (830, gy - 200), '¡machaca!', (255, 255, 255, 255), FONT_B)
        frames.append(c.convert('RGB').convert('P', palette=Image.ADAPTIVE, colors=96))
    frames[0].save(os.path.join(OUT, f'pelea_{K.id}.gif'), save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0, optimize=True)


def idx_of(tl, name):
    for n, a in enumerate(tl):
        if a[0] == name: return n
    return 0


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[sys.argv.index('--look') + 1] if '--look' in sys.argv else None
    kits = {i: Kit(i) for i in LOOKS}
    # (comprobación: 1 píxel de margen en todos los cuadros)
    for i, K in kits.items():
        for f, a in K.art.items():
            if not margin_ok(a): print('  sin margen:', i, f, a.getbbox(), a.size)
        parts_sheet(K)
    overview(kits)
    if '--still' not in sys.argv:
        for i, K in kits.items():
            if only and i != only: continue
            fight_gif(K)
    print('previas en', OUT)


if __name__ == '__main__':
    main()
