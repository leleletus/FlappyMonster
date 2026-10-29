#!/usr/bin/env python3
# tools/art/enemies/make_jungle_enemies.py — PROPUESTA de tres enemigos nuevos (el usuario los eligió; el comportamiento
# viene después, aquí se dibujan TODOS los cuadros que va a necesitar):
#   1. el TOPO (general: cada isla tiene el suyo, hojas `<isla>-Sheet.png` como el Saltarín): va bajo tierra dejando un
#      MONTÍCULO de la tierra de su isla que se mueve (el aviso), asoma debajo del jugador para MORDER y se vuelve a
#      hundir; un culetazo sobre el montículo lo saca (mareado, se le puede pisar); pisado = aplastado.
#   2. la PIRAÑA (solo jungla): vive en los ríos, salta del agua en arco para morder; se le puede pisar en el aire.
#   3. la PLANTA CARNÍVORA (solo jungla): fija en el suelo, se cierra de golpe si el jugador pasa por encima o al lado;
#      solo se le puede pisar justo después de cerrarse; si se le da de comer un escarabajo, se duerme un rato.
# De cada uno, DOS diseños (A y B); del topo, los dos en las 7 islas (misma hoja, mismos cuadros, otra piel).
#
# El usuario, viendo la 1ª prueba (2026-10-29): "no tan detallados — muchos píxeles de colores distintos a tan poca
# resolución no se leen — ni tan gorditos: formas más finas y originales aunque se salgan un poco del resto; si todo
# es igual, nunca habrá nada nuevo". Por eso: 3 tonos por parte (contorno, sombra, medio; sin brillos ni motas), UN
# adorno por isla, siluetas finas y largas; la B de cada uno es la más atrevida.
#
# Cómo se dibuja: cada sprite es una pila de PIEZAS (formas: elipses, rectángulos, polígonos, tubos) en coordenadas
# propias que se rasterizan con una transformación por cuadro (giro, escala, desplazamiento: así la piraña se inclina
# en el salto sin redibujar cada pose a mano). El contorno de cada pieza es el tono más oscuro de SU color (nunca
# negro), la sombra abajo a la derecha (docs/art/style-rules.md). Detalles de 1 px (ojos, dientes) encima.
#
#   python tools/art/enemies/make_jungle_enemies.py          → SOLO vistas previas en
#                                                              FlappyMonster_pruebas/enemigos_nuevos/ (vista_previa.png,
#                                                              maqueta.gif y archivos/ con cada hoja); --no-gif sin GIF
#   python tools/art/enemies/make_jungle_enemies.py --apply [--mole A|B] [--piranha A|B] [--plant A|B] [--force]
#          → escribe el diseño elegido (A por defecto) en assets/images/enemies/mole/<isla>-Sheet.png,
#            piranha/piranha-Sheet.png y carnivoreplant/plant-Sheet.png (NO lo uses sin el visto bueno del usuario;
#            no pisa nada que ya exista salvo con --force), sus conjuntos de animación assets/anim/enemies/{mole,
#            piranha,carnivoreplant}.json y la "z" de dormido (assets/images/bosses/common/sleep_z.png + `sleep_z` en
#            bosses/common.json); esos nunca se pisan (se retocan en el editor de animaciones).
#   El usuario eligió (2026-10-29): topo A «Periscopio», piraña B «Aguja», planta B «Cepo»:
#     python tools/art/enemies/make_jungle_enemies.py --apply --mole A --piranha B --plant B
import os, sys, math
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
IMG = os.path.join(ROOT, 'assets', 'images')
OUT = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'enemigos_nuevos')
ISLES = ['pradera', 'costa', 'fortaleza', 'nieve', 'cueva', 'volcan', 'jungla']      # (el orden de Isles.IDS)


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# ══ MOTOR: formas, transformaciones y piezas ═══════════════════════════════════════════════════════════════════════
class Sh:
    """Una forma = una función (x, y) → dentro/fuera, en coordenadas continuas (el centro del píxel x es x + 0.5)"""
    def __init__(self, f): self.f = f
    def __call__(self, x, y): return self.f(x, y)
    def __or__(a, b): return Sh(lambda x, y: a.f(x, y) or b.f(x, y))
    def __and__(a, b): return Sh(lambda x, y: a.f(x, y) and b.f(x, y))
    def __sub__(a, b): return Sh(lambda x, y: a.f(x, y) and not b.f(x, y))


def E(cx, cy, rx, ry, rot=0.0):
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    def f(x, y):
        dx, dy = x - cx, y - cy
        u, v = dx * c + dy * s, -dx * s + dy * c
        return (u / rx) ** 2 + (v / ry) ** 2 <= 1.0
    return Sh(f)


def R(x0, y0, x1, y1): return Sh(lambda x, y: x0 <= x < x1 and y0 <= y < y1)


def Pg(pts):
    def f(x, y):
        ins, n = False, len(pts)
        for i in range(n):
            (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
            if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1): ins = not ins
        return ins
    return Sh(f)


def Above(y0): return Sh(lambda x, y: y < y0)
def Below(y0): return Sh(lambda x, y: y >= y0)
def LeftOf(x0): return Sh(lambda x, y: x < x0)


class Xf:
    """Transformación: escala (sx, sy) y giro (grados, horario en pantalla) alrededor de `pivot`, y luego desplazamiento"""
    def __init__(self, rot=0.0, pivot=(10, 10), dx=0.0, dy=0.0, sx=1.0, sy=1.0, flip=False):
        self.rot, self.p, self.dx, self.dy, self.sx, self.sy, self.flip = rot, pivot, dx, dy, sx, sy, flip
        self.c, self.s = math.cos(math.radians(rot)), math.sin(math.radians(rot))

    def fwd(self, x, y):
        px, py = self.p
        u, v = (x - px) * self.sx, (y - py) * self.sy
        if self.flip: v = -v
        return px + u * self.c - v * self.s + self.dx, py + u * self.s + v * self.c + self.dy

    def inv(self, X, Y):
        px, py = self.p
        a, b = X - px - self.dx, Y - py - self.dy
        u, v = a * self.c + b * self.s, -a * self.s + b * self.c
        if self.flip: v = -v
        return px + u / self.sx, py + v / self.sy


ID = Xf()


class P:
    """Una pieza: forma + rampa (contorno, sombra, medio, luz). shade: 'sphere' (volumen), 'flat' (medio + luz arriba),
    'none' (todo el medio). line: contorno exterior de 1 px. hi/lo: umbrales de luz y sombra."""
    def __init__(self, shape, ramp, line=True, shade='sphere', hi=9.0, lo=0.25, xf=None, clip=None, light=None):
        self.shape, self.ramp, self.line, self.shade = shape, [hx(c) for c in ramp], line, shade
        self.hi, self.lo, self.xf, self.clip, self.light = hi, lo, xf, clip, light


class D:
    """Detalles: [(x, y, color)] en coordenadas propias (se transforman con la pieza)"""
    def __init__(self, pts, xf=None, clip=None): self.pts, self.xf, self.clip = pts, xf, clip


def render(W, H, layers):
    """layers: [(Xf del cuadro, [P | D], recorte de pantalla (forma) o None)] → Image RGBA"""
    cv = [[None] * W for _ in range(H)]
    for xf, items, clip in layers:
        for it in items:
            if isinstance(it, D):
                for x, y, col in it.pts:
                    lx, ly = (it.xf.fwd(x + .5, y + .5) if it.xf else (x + .5, y + .5))
                    X, Y = xf.fwd(lx, ly)
                    X, Y = int(math.floor(X)), int(math.floor(Y))
                    if 0 <= X < W and 0 <= Y < H and (clip is None or clip(X + .5, Y + .5)) \
                            and (it.clip is None or it.clip(X + .5, Y + .5)):
                        cv[Y][X] = hx(col) if isinstance(col, str) else col
                continue
            mask = set()
            for Y in range(H):
                for X in range(W):
                    if clip is not None and not clip(X + .5, Y + .5): continue
                    if it.clip is not None and not it.clip(X + .5, Y + .5): continue
                    lx, ly = xf.inv(X + .5, Y + .5)
                    if it.xf: lx, ly = it.xf.inv(lx, ly)
                    if it.shape(lx, ly): mask.add((X, Y))
            if not mask: continue
            o, s, b, h = it.ramp
            if it.line:
                for X, Y in mask:
                    for nx, ny in ((X + 1, Y), (X - 1, Y), (X, Y + 1), (X, Y - 1)):
                        if (nx, ny) not in mask and 0 <= nx < W and 0 <= ny < H \
                                and (clip is None or clip(nx + .5, ny + .5)):
                            cv[ny][nx] = o
            xs, ys = [p[0] for p in mask], [p[1] for p in mask]
            if it.light: cx, cy, rx, ry = it.light
            else:
                cx, cy = (min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2
                rx, ry = max(1.0, (max(xs) - min(xs) + 1) / 2), max(1.0, (max(ys) - min(ys) + 1) / 2)
            for X, Y in mask:
                if it.shade == 'none': cv[Y][X] = b; continue
                if it.shade == 'flat':
                    cv[Y][X] = h if (X, Y - 1) not in mask else b; continue
                if it.shade == 'dark':
                    cv[Y][X] = s; continue
                nx, ny = (X + .5 - cx) / rx, (Y + .5 - cy) / ry
                nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
                L = -0.45 * nx - 0.65 * ny + 0.62 * nz
                cv[Y][X] = h if L > it.hi else (s if L < it.lo else b)
    im = Image.new('RGBA', (W, H))
    for Y in range(H):
        for X in range(W):
            if cv[Y][X]: im.putpixel((X, Y), cv[Y][X])
    return im


def sheet(frames):
    W, H = frames[0].size
    out = Image.new('RGBA', (W * len(frames), H))
    for i, f in enumerate(frames): out.paste(f, (i * W, 0))
    return out


def margin_ok(im, bottom=True):
    """1 px de margen transparente (arriba y a los lados; abajo el suelo puede tocar el borde si bottom)"""
    W, H = im.size
    px = im.load()
    for x in range(W):
        if px[x, 0][3]: return False
        if not bottom and px[x, H - 1][3]: return False
    for y in range(H):
        if px[0, y][3] or px[W - 1, y][3]: return False
    return True


# ══ PALETAS (3 tonos por parte: contorno, sombra, medio — sin brillos ni motas: el usuario, tras la 1ª prueba,
# "demasiados píxeles de colores distintos a tan poca resolución no se leen; y no tan gorditos") ══════════════════
LEAF = ['0f2a1a', '1d4a2a', '2f7a3a', '5fb04a', 'a6d860']
MAG, ORA, YEL, TEAL = 'd0407a', 'f08a24', 'f4d03a', '2fb0a0'
BG_JUNGLE = '3c5a40'
MOUTH = ('2a060e', '2a060e', '2a060e', '2a060e')
TOOTH = ('6a6458', 'e8e0cc', 'ffffff', 'ffffff')
PINK = ('7a2440', 'd0507a', 'f08aa8', 'f08aa8')


def r3(o, s, b): return (o, s, b, b)                         # rampa de 3 tonos (sin luz)


def tube(pts, r, step=0.4):
    """Un tubo (cuello, tallo, cuerpo de gusano): círculos de radio r a lo largo de la polilínea pts"""
    sh = None
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(x2 - x1, y2 - y1) / step))
        for k in range(n + 1):
            c = E(x1 + (x2 - x1) * k / n, y1 + (y2 - y1) * k / n, r, r)
            sh = c if sh is None else sh | c
    return sh


def bez(p0, p1, p2, n=10):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / n for i in range(n + 1))]


# ══ 1. EL TOPO ══════════════════════════════════════════════════════════════════════════════════════════════════
# Cuadro 22x20 con los pies (y el suelo) en la fila de abajo: el juego lo dibuja con el borde de abajo en la cara de
# arriba del bloque; lo que queda bajo tierra se recorta en el propio dibujo. Mira a la DERECHA (el juego lo voltea).
MW, MH = 22, 20
MOLE_FRAMES = ['mound1', 'mound2', 'mound3', 'emerge1', 'emerge2', 'idle1', 'idle2', 'bite1', 'bite2',
               'dive1', 'dive2', 'dizzy1', 'dizzy2', 'dead']

# Pieles por isla: pelo, nariz, uñas (3 tonos cada una) + UN adorno
MOLE_ISLES = {
    'pradera': dict(fur=r3('3a2216', '6a4428', '94643a'), nose=PINK, claw=r3('6a5a48', 'c8b898', 'f0e6cc')),
    'costa': dict(fur=r3('5a3e1c', 'a8803e', 'd8b06a'), nose=PINK, claw=r3('6a2a0c', 'd0602a', 'f09050'),
                  hat=r3('7a2a10', 'd0602a', 'f09050')),
    'fortaleza': dict(fur=r3('22222e', '464a5c', '6a7084'), nose=PINK, claw=r3('6a5a48', 'c8b898', 'f0e6cc'),
                      hat=r3('3a2a0e', '8a6420', 'c89a3a')),
    'nieve': dict(fur=r3('5a6a8a', 'b4c4dc', 'eef2fa'), nose=PINK, claw=r3('2a5a7a', '7ac0e0', 'c8f0ff'),
                  hat=r3('5a1020', 'b02838', 'e04858')),
    'cueva': dict(fur=r3('3a2448', '765690', 'a888b8'), nose=r3('7a1a44', 'e0508a', 'ff90c0'),
                  claw=r3('6a5a48', 'c8b898', 'f0e6cc'), hat=r3('5a3a10', 'c0901c', 'f0c030')),
    'volcan': dict(fur=r3('140a0c', '2e1c1e', '4a3030'), nose=r3('7a2008', 'e06018', 'ffa030'),
                   claw=r3('7a2008', 'e06018', 'ffa030'), hat=r3('7a2008', 'e06018', 'ffa030')),
    'jungla': dict(fur=r3('22280e', '4a5420', '6e7a30'), nose=PINK, claw=r3('3a2412', '7e5634', 'a87c50'),
                   hat=r3('0f2a1a', '2f7a3a', '5fb04a')),
}
# Montículo: la tierra de la isla (+ la capa de arriba: hierba, musgo, ceniza)
MOUND = {
    'pradera': dict(ramp=r3('2a1a10', '4a2e1a', '6e4426'), top=r3('1d4a2a', '3a8a3a', '5fb04a')),
    'costa': dict(ramp=r3('7a5a2a', 'c8a060', 'e8cc94'), top=None),
    'fortaleza': dict(ramp=r3('22222c', '44485a', '6a6e80'), top=None),
    'nieve': dict(ramp=r3('5a7090', 'b4c8e0', 'f0f6ff'), top=None),
    'cueva': dict(ramp=r3('1e1418', '3e2a30', '5c3e42'), top=None),
    'volcan': dict(ramp=r3('2a1210', '4a2018', '6a2c20'), top=r3('5a1a0c', 'a0482a', 'd06a30')),
    'jungla': dict(ramp=r3('2a1a10', '3a2416', '5a3a22'), top=r3('1e3a14', '4f7a26', '86b03c')),
}
GROUND_TILE = {'pradera': 'grass.png', 'costa': 'sand.png', 'fortaleza': 'stone.png', 'nieve': 'snow.png',
               'cueva': 'deep_stone.png', 'volcan': 'ash.png', 'jungla': 'jungle_grass.png'}
ISLE_BG = {'pradera': '8cc8f0', 'costa': '9cdcf0', 'fortaleza': '8a8ea8', 'nieve': 'b8d4f0', 'cueva': '3a3450',
           'volcan': '6a2c2c', 'jungla': '3c5a40'}


def mound_items(isle, k):
    """El montículo que avanza (k = 0, 1, 2: el bulto rueda hacia delante y salta un terrón atrás)"""
    m = MOUND[isle]
    body = E(11, 20.4, 6.0, 3.6) | E(9 + k, 17.6, 2.8, 2.0) | E(13.5 + k * 0.5, 17.2, 2.4, 2.0)
    it = [P(body, m['ramp'])]
    if m['top']: it.append(P(body & Above(18.0 + (k == 1)), m['top'], line=False))
    cx, cy = [(4.5, 14.5), (3.5, 13.0), (4.0, 15.5)][k]           # un terrón que salta hacia atrás
    it.append(P(E(cx, cy, 1.0, 0.9), m['ramp']))
    return it


def hole_items(isle):
    """El borde del agujero: tierra amontonada a los dos lados, delante del topo"""
    m = MOUND[isle]
    rim = E(5.0, 20.6, 3.8, 2.4) | E(17.0, 20.6, 3.8, 2.4)
    it = [P(rim, m['ramp'])]
    if m['top']: it.append(P(rim & Above(19.2), m['top'], line=False))
    return it


# ── TOPO A «Periscopio»: de perfil, de pie y FLACO, hocico largo y fino como un pico (mandíbulas que se abren de
# arriba abajo), brazo fino con dos uñas largas; sale del suelo recto como un periscopio ─────────────────────────
JAW_H = (12.0, 8.6)


def moleA_items(isle, mouth='closed', eyes='open', arm='down', sniff=0, feet=True):
    p = MOLE_ISLES[isle]
    fur, nose, claw = p['fur'], p['nose'], p['claw']
    it = []
    if feet:
        it += [P(E(4.6, 18.8, 1.8, 0.7, 20), nose), P(E(7.0, 19.5, 1.6, 0.7), nose), P(E(10.6, 19.5, 1.9, 0.7), nose)]
    if isle == 'volcan':                                      # (el del volcán: la tripa encendida)
        it.append(P(E(8.5, 13.8, 3.4, 6.2) | E(9.5, 8.0, 3.4, 3.0), fur))
        it.append(P((E(8.5, 13.8, 3.4, 6.2) & LeftOf(99)) - E(7.4, 13.0, 3.4, 6.6), p['hat'], line=False))
    else:
        it.append(P(E(8.5, 13.8, 3.4, 6.2) | E(9.5, 8.0, 3.4, 3.0), fur))
    jx_up = Xf(rot=-26 - sniff, pivot=JAW_H)
    jx_lo = Xf(rot=30, pivot=JAW_H)
    if mouth == 'open':
        tipu, tipl = jx_up.fwd(18.4, 8.6), jx_lo.fwd(18.0, 9.0)
        it.append(P(Pg([JAW_H, tipu, tipl]), MOUTH, line=False, shade='none'))
        it.append(P(Pg([(11.5, 6.4), (18.4, 8.0), (18.4, 8.6), (11.5, 8.6)]), fur, xf=jx_up))
        it.append(P(Pg([(11.5, 8.6), (18.0, 8.8), (18.0, 9.4), (11.5, 10.6)]), fur, xf=jx_lo))
        it.append(D([(15, 9, 'ffffff'), (17, 9, 'ffffff')], xf=jx_up))
        it.append(D([(14, 8, 'ffffff'), (16, 8, 'ffffff')], xf=jx_lo))
        it.append(P(E(18.6, 8.2, 1.0, 1.0), nose, xf=jx_up))
    else:
        jx = Xf(rot=-sniff, pivot=JAW_H)
        it.append(P(Pg([(11.5, 6.4), (18.4, 8.0), (18.4, 9.2), (11.5, 10.6)]), fur, xf=jx))
        it.append(P(E(18.6, 8.6, 1.0, 1.0), nose, xf=jx))
        if mouth == 'snap':
            it.append(D([(13, 9, fur[0]), (14, 9, 'ffffff'), (15, 9, fur[0]), (16, 9, 'ffffff'), (17, 9, fur[0])], xf=jx))
        elif mouth == 'tongue':
            it.append(D([(14, 9, fur[0]), (15, 9, fur[0]), (16, 9, fur[0]), (17, 10, nose[1]), (17, 11, nose[1])], xf=jx))
        else:
            it.append(D([(14, 9, fur[0]), (15, 9, fur[0]), (16, 9, fur[0])], xf=jx))
    # brazo fino (un tono más oscuro) y dos uñas largas
    arm_pts = {'down': [(10.0, 11.4), (12.6, 13.6)], 'up': [(10.0, 11.4), (12.8, 9.6)],
               'out': [(10.0, 11.6), (13.6, 12.0)]}[arm]
    it.append(P(tube(arm_pts, 0.9), r3(fur[0], fur[1], fur[1])))
    hx_, hy_ = arm_pts[-1]
    if arm == 'down': cl = R(hx_ - 0.4, hy_ + 0.6, hx_ + 0.6, hy_ + 3.6) | R(hx_ + 1.6, hy_ + 0.4, hx_ + 2.6, hy_ + 3.0)
    elif arm == 'up': cl = R(hx_ - 0.4, hy_ - 3.4, hx_ + 0.6, hy_ - 0.6) | R(hx_ + 1.6, hy_ - 2.8, hx_ + 2.6, hy_ - 0.2)
    else: cl = R(hx_ + 0.6, hy_ - 1.0, hx_ + 3.6, hy_) | R(hx_ + 0.6, hy_ + 1.0, hx_ + 3.2, hy_ + 2.0)
    it.append(P(cl, claw, shade='none'))
    # ojo (la cueva: ciega, sin ojo)
    e = fur[0]
    if isle != 'cueva' or eyes != 'open':
        it.append(D({'open': [(11, 6, e), (11, 7, e)], 'shut': [(10, 7, e), (11, 7, e)],
                     'dizzy': [(10, 6, e), (11, 6, e), (12, 6, e), (12, 7, e), (10, 7, e), (10, 8, e), (11, 8, e), (12, 8, e)],
                     'x': [(10, 6, e), (12, 6, e), (11, 7, e), (10, 8, e), (12, 8, e)]}[eyes]))
    it += mole_hat(isle, (9.5, 5.2), (8.5, 10.6), 'A')
    return it


# ── TOPO B «Gusano»: el atrevido — un topo LARGO como una serpiente (cuerpo-tubo), cabeza pequeña con hocico afilado;
# asoma de punta y muerde hacia arriba, y se zambulle en ARCO como un delfín en la tierra ───────────────────────────
def moleB_items(isle, path, head, ang, mouth='closed', eyes='open', r=2.3, sq=1.0):
    p = MOLE_ISLES[isle]
    fur, nose, claw = p['fur'], p['nose'], p['claw']
    it = []
    if path: it.append(P(tube(path, r), fur))
    if head is None: return it
    hx_, hy_ = head
    hxf = Xf(rot=ang, pivot=head, sy=sq)
    if isle == 'volcan' and path:                             # (tripa encendida: el lado de abajo del tubo)
        it.append(P(tube(path, r) - tube([(x, y - 1.2) for x, y in path], r), p['hat'], line=False))
    it.append(P(E(hx_ - 1.6, hy_ + 2.4, 1.2, 0.9), claw, xf=hxf))          # la manita
    up = Pg([(hx_ + 1.0, hy_ - 1.9), (hx_ + 6.2, hy_ - 0.5), (hx_ + 6.2, hy_), (hx_ + 1.0, hy_)])
    lo = Pg([(hx_ + 1.0, hy_), (hx_ + 5.8, hy_), (hx_ + 5.8, hy_ + 0.7), (hx_ + 1.0, hy_ + 1.7)])
    if mouth == 'open':                                       # las dos mandíbulas muy abiertas
        piv = (hx_ + 1.2, hy_)
        ju, jl = _compose(hxf, Xf(rot=-34, pivot=piv)), _compose(hxf, Xf(rot=34, pivot=piv))
        it.append(P(Pg([piv, ju.fwd(hx_ + 6.2, hy_), jl.fwd(hx_ + 5.8, hy_)]), MOUTH, line=False, shade='none'))
        it.append(P(E(hx_, hy_, 3.0, 2.6), fur, xf=hxf))
        it.append(P(up, fur, xf=ju))
        it.append(P(lo, fur, xf=jl))
        it.append(P(E(hx_ + 6.4, hy_ - 0.2, 0.9, 0.9), nose, xf=ju))
        X, Y = int(math.floor(hx_)), int(math.floor(hy_))
        it.append(D([(X + 3, Y, 'ffffff'), (X + 5, Y, 'ffffff')], xf=ju))
        it.append(D([(X + 3, Y - 1, 'ffffff'), (X + 5, Y - 1, 'ffffff')], xf=jl))
    else:
        it.append(P(E(hx_, hy_, 3.0, 2.6) | up | lo, fur, xf=hxf))
        it.append(P(E(hx_ + 6.4, hy_ + 0.1, 0.9, 0.9), nose, xf=hxf))
        X, Y = int(math.floor(hx_)), int(math.floor(hy_))
        if mouth == 'snap': it.append(D([(X + 2, Y, fur[0]), (X + 3, Y, 'ffffff'), (X + 4, Y, fur[0]), (X + 5, Y, 'ffffff')], xf=hxf))
        elif mouth == 'tongue': it.append(D([(X + 2, Y, fur[0]), (X + 3, Y, fur[0]), (X + 4, Y, fur[0]), (X + 6, Y + 1, nose[1]),
                                              (X + 6, Y + 2, nose[1])], xf=hxf))
        else: it.append(D([(X + 2, Y, fur[0]), (X + 3, Y, fur[0]), (X + 4, Y, fur[0])], xf=hxf))
    e = fur[0]
    X, Y = int(math.floor(hx_)), int(math.floor(hy_))
    if isle != 'cueva' or eyes != 'open':
        it.append(D({'open': [(X, Y - 1, e), (X, Y - 2, e)], 'shut': [(X - 1, Y - 1, e), (X, Y - 1, e)],
                     'dizzy': [(X, Y - 2, e), (X + 1, Y - 2, e), (X + 2, Y - 2, e), (X + 2, Y - 1, e), (X, Y - 1, e),
                               (X, Y, e), (X + 1, Y, e), (X + 2, Y, e)],
                     'x': [(X, Y - 2, e), (X + 2, Y - 2, e), (X + 1, Y - 1, e), (X, Y, e), (X + 2, Y, e)]}[eyes], xf=hxf))
    for x in mole_hat(isle, (hx_ - 0.4, hy_ - 2.4), (hx_ - 3.0, hy_ + 0.4), 'B'):
        x.xf = hxf if x.xf is None else _compose(hxf, x.xf)
        it.append(x)
    return it


class _compose(Xf):
    """a(b(p)): primero b, luego a"""
    def __init__(self, a, b): self.a, self.b = a, b
    def fwd(self, x, y): return self.a.fwd(*self.b.fwd(x, y))
    def inv(self, X, Y): return self.b.inv(*self.a.inv(X, Y))


def mole_hat(isle, top, neck, design):
    """El adorno de cada isla, UNO, de formas planas: top = lo alto de la cabeza, neck = el cuello"""
    p = MOLE_ISLES[isle]
    if 'hat' not in p or isle == 'volcan': return []
    tx, ty = top
    hat = p['hat']
    if isle == 'costa':                                       # una caracola en la cabeza
        return [P(E(tx, ty + 0.2, 1.7, 1.3) | Pg([(tx - 0.4, ty - 0.8), (tx + 0.4, ty - 2.6), (tx + 1.2, ty - 0.6)]), hat)]
    if isle == 'fortaleza':                                   # casco de bronce de zapador
        return [P((E(tx, ty + 1.0, 3.4, 2.6) & Above(ty + 1.0)) | R(tx - 3.8, ty + 0.4, tx + 4.4, ty + 1.4), hat)]
    if isle == 'cueva':                                       # casco de minero con su lámpara
        return [P((E(tx, ty + 1.0, 3.2, 2.4) & Above(ty + 1.0)) | R(tx - 3.6, ty + 0.4, tx + 3.6, ty + 1.4), hat),
                P(E(tx + 1.4, ty - 0.4, 0.9, 0.9), r3('6a6450', 'fff4c0', 'fffbe8'))]
    if isle == 'nieve':                                       # bufanda roja con la punta al viento
        nx, ny = neck
        return [P(E(nx, ny, 3.4, 1.0) | Pg([(nx - 2.6, ny), (nx - 5.4, ny + 2.4), (nx - 3.6, ny + 2.8), (nx - 1.4, ny + 0.6)]), hat)]
    if isle == 'jungla':                                      # una hoja de sombrero
        return [P(E(tx + 0.6, ty - 0.2, 3.8, 1.3, -16), hat)]
    return []


def mole_frame(design, isle, name):
    """Un cuadro de 22x20 (los pies en la fila de abajo)"""
    clip = Above(18.6)
    hole = (Xf(), hole_items(isle), None)
    L = []
    if name.startswith('mound'):
        return render(MW, MH, [(Xf(), mound_items(isle, int(name[-1]) - 1), None)])
    if design == 'A':
        T = lambda **k: Xf(pivot=(8.5, 20), **k)
        M = lambda **k: moleA_items(isle, **k)
        L = {'emerge1': [(T(dy=9.0), M(eyes='shut', feet=False), clip), hole],
             'emerge2': [(T(dy=4.5), M(feet=False), clip), hole],
             'idle1': [(T(), M(), None)],
             'idle2': [(T(), M(sniff=8), None)],
             'bite1': [(T(dy=1.5), M(mouth='open', eyes='shut', arm='out', feet=False), clip), hole],
             'bite2': [(T(dy=2.5), M(mouth='snap', eyes='shut', feet=False), clip), hole],
             'dive1': [(T(dy=7.0, rot=12, dx=-3.0), M(eyes='shut', feet=False), clip), hole],
             'dive2': [(T(dy=10.5, rot=26, dx=-1.5), M(eyes='shut', feet=False), clip), hole],
             'dizzy1': [(T(rot=-6), M(mouth='tongue', eyes='dizzy', arm='out', sniff=-10), None)],
             'dizzy2': [(T(rot=6), M(mouth='tongue', eyes='dizzy', arm='out', sniff=-14), None)],
             'dead': [(T(sy=0.42, sx=1.06), M(mouth='tongue', eyes='x', arm='out'), None)]}[name]
    else:
        B = lambda *a, **k: moleB_items(isle, *a, **k)
        lie = [(4.6, 17.4), (7.0, 16.4), (9.4, 17.6), (11.0, 17.2)]
        lie2 = [(4.6, 16.8), (7.0, 17.6), (9.4, 16.6), (11.0, 17.4)]
        L = {'emerge1': [(Xf(), B([(11, 23), (11, 21)], (11, 18.4), -90, eyes='shut'), clip), hole],
             'emerge2': [(Xf(), B([(11, 23), (11, 15)], (11, 13.0), -84), clip), hole],
             'idle1': [(Xf(), B(lie, (12.6, 16.4), 0), None)],
             'idle2': [(Xf(), B(lie2, (12.6, 16.8), -6), None)],
             'bite1': [(Xf(), B(bez((5.4, 23), (5.4, 9.0), (11.0, 8.4)), (12.6, 8.8), -14, mouth='open', eyes='shut'),
                       clip), hole],
             'bite2': [(Xf(), B(bez((5.4, 23), (5.6, 10.0), (11.0, 9.8)), (12.4, 10.6), 14, mouth='snap', eyes='shut'),
                       clip), hole],
             'dive1': [(Xf(), B(bez((5.0, 23), (7.0, 6.0), (14.4, 12.4)), (15.2, 13.8), 66, eyes='shut'), clip), hole],
             'dive2': [(Xf(), B(bez((5.0, 23), (10.0, 6.0), (16.4, 23)), None, 0), clip), hole],
             'dizzy1': [(Xf(), B([(4.6, 17.2), (7.4, 17.8), (9.6, 16.6), (11.0, 17.4)], (12.6, 16.2), -14, mouth='tongue',
                                eyes='dizzy'), None)],
             'dizzy2': [(Xf(), B([(4.6, 17.8), (7.4, 16.8), (9.6, 17.6), (11.0, 16.8)], (12.6, 15.8), -20, mouth='tongue',
                                eyes='dizzy'), None)],
             'dead': [(Xf(pivot=(10, 20), sy=0.45, sx=1.04), B(lie, (12.6, 16.4), 0, mouth='tongue', eyes='x'), None)]}[name]
    return render(MW, MH, L)


# ══ 2. LA PIRAÑA (solo jungla) ══════════════════════════════════════════════════════════════════════════════════
# Cuadro 22x20 mirando a la DERECHA, el pez centrado en (11, 10) (el giro del salto es sobre ese centro).
FW, FH = 22, 20
FISH_FRAMES = ['swim1', 'swim2', 'swim3', 'leap1', 'leap2', 'bite1', 'bite2', 'fall', 'dead']
FISH = {
    # A «Mandíbula»: casi todo CABEZA — una cuña alta y chata que adelgaza hasta una cola fina; mandíbula de abajo roja
    # muy salida con dos dientes grandes que se ven siempre
    'A': dict(back=r3('16202c', '34485e', '587890'), belly=r3('4a0c10', 'a8202a', 'e04a3a'), fin=r3('16202c', '34485e', '587890'),
              eye='ffc83a', hinge=(11.0, 10.8)),
    # B «Aguja» (el atrevido): larguísima y fina como una lanza, con un PICO de dientes; verde agua, aletas magenta
    'B': dict(back=r3('0c2a2a', '1c6058', '2c9484'), belly=r3('4a5a44', 'a8b490', 'd4dcbc'), fin=r3('4a1030', '8e2456', MAG),
              eye='f4d03a', hinge=(13.2, 10.2)),
}


def fishA_items(jaw=0, tail=0, eye='open', fins=0):
    f = FISH['A']
    back, belly, fin = f['back'], f['belly'], f['fin']
    jx = Xf(rot=jaw, pivot=f['hinge'])
    it = [P(Pg([(5.6, 10.0), (1.4, 6.0), (2.8, 10.0), (1.4, 14.0)]), fin, xf=Xf(rot=tail, pivot=(5.2, 10))),
          P(Pg([(9.0, 6.0), (10.6, 2.8 - fins), (12.6, 4.8)]), fin)]
    body = Pg([(4.4, 8.6), (9.0, 5.6), (14.0, 4.0), (17.0, 5.6), (17.6, 9.0), (16.6, 10.6), (11.0, 13.6), (6.0, 12.4), (4.4, 11.4)])
    if jaw:
        tip, bot = jx.fwd(18.8, 9.2), jx.fwd(12.0, 15.2)
        it.append(P(Pg([(11.0, 10.4), (17.6, 9.4), tip, bot]), MOUTH, line=False, shade='none'))
    it.append(P(body, back))
    it.append(P(body & Below(10.6), belly, line=False))
    jaw_sh = Pg([(10.4, 10.6), (18.8, 9.2), (18.6, 11.8), (12.4, 15.2), (10.4, 13.6)])
    it.append(P(jaw_sh, belly, xf=jx))
    it.append(P(Pg([(13.4, 10.4), (14.8, 10.2), (14.2, 8.0)]) | Pg([(16.2, 10.0), (17.6, 9.8), (17.0, 7.8)]), TOOTH,
                line=False, shade='none', xf=jx))
    e = back[0]
    it.append(D({'open': [(14, 6, f['eye']), (15, 6, e)], 'shut': [(14, 6, e), (15, 6, e)],
                 'x': [(13, 5, e), (15, 5, e), (14, 6, e), (13, 7, e), (15, 7, e)]}[eye]))
    return it


def fishB_items(jaw=0, tail=0, eye='open', fins=0):
    f = FISH['B']
    back, belly, fin = f['back'], f['belly'], f['fin']
    jx = Xf(rot=jaw, pivot=f['hinge'])
    it = [P(Pg([(4.6, 10.0), (1.4, 7.0), (2.6, 10.0), (1.4, 13.0)]), fin, xf=Xf(rot=tail, pivot=(4.4, 10))),
          P(Pg([(5.4, 8.6), (7.0, 6.2 - fins), (8.8, 8.4)]), fin),
          P(Pg([(5.4, 11.4), (7.0, 13.8 + fins), (8.8, 11.6)]), fin)]
    body = E(8.8, 10.0, 5.0, 2.0) | E(12.2, 9.8, 2.2, 1.9) | Pg([(13.0, 8.4), (19.0, 9.6), (19.0, 10.2), (13.0, 10.2)])
    if jaw:
        tip = jx.fwd(18.6, 10.6)
        it.append(P(Pg([(13.2, 10.2), (19.0, 10.2), tip]), MOUTH, line=False, shade='none'))
    it.append(P(body, back))
    it.append(P((E(8.8, 10.0, 5.0, 2.0) | E(12.2, 9.8, 2.2, 1.9)) & Below(10.4), belly, line=False))
    it.append(P(Pg([(12.6, 10.2), (18.6, 10.4), (18.4, 10.9), (12.6, 11.8)]), belly, xf=jx))
    it.append(D([(15, 10, 'ffffff'), (17, 10, 'ffffff')], xf=jx))
    e = back[0]
    it.append(D({'open': [(12, 9, f['eye'])], 'shut': [(11, 9, e), (12, 9, e)],
                 'x': [(11, 8, e), (13, 8, e), (12, 9, e), (11, 10, e), (13, 10, e)]}[eye]))
    return it


def fish_frame(design, name):
    F = fishA_items if design == 'A' else fishB_items
    C = (10, 10)
    xf, k = {
        'swim1': (Xf(pivot=C), dict(tail=0)),
        'swim2': (Xf(pivot=C), dict(tail=-13)),
        'swim3': (Xf(pivot=C), dict(tail=16, jaw=6)),
        'leap1': (Xf(rot=-30, pivot=C), dict(jaw=22, tail=10, fins=1)),
        'leap2': (Xf(rot=-40, pivot=C), dict(jaw=38, tail=-12, fins=1)),
        'bite1': (Xf(rot=-12, pivot=C), dict(jaw=0, tail=8, eye='shut')),
        'bite2': (Xf(rot=-6, pivot=C), dict(jaw=10, tail=-8)),
        'fall': (Xf(rot=38, pivot=C), dict(jaw=6, tail=-14, fins=1)),
        'dead': (Xf(pivot=C, flip=True), dict(jaw=12, eye='x')),
    }[name]
    return render(FW, FH, [(_compose(Xf(dx=1), xf), F(**k), None)])


# ══ 3. LA PLANTA CARNÍVORA (solo jungla) ════════════════════════════════════════════════════════════════════════
# Cuadro 26x24 con la base en la fila de abajo (de pie sobre el bloque).
PW, PH = 26, 24
PLANT_FRAMES = ['idle1', 'idle2', 'tell1', 'tell2', 'snap1', 'snap2', 'chew1', 'chew2', 'sleep1', 'sleep2', 'dead']
LEAFD = r3(LEAF[0], LEAF[1], LEAF[2])
LEAFL = r3(LEAF[0], LEAF[2], LEAF[3])
INNER = r3('4a0c26', '9a1c4a', MAG)
CILIA = 'e4f4a8'
DRY = r3('2a1a10', '5a3a1e', '8a6a3a')
DRYI = r3('3a2412', '6e3a2a', '8a4a3a')


def _lobe(h, a, L, W, inner_sign):
    """Una valva: elipse a lo largo de la dirección a (grados desde la vertical) que sale de la bisagra h →
    (entera, mitad de dentro, mitad de fuera, borde de la de dentro)"""
    ar = math.radians(a)
    d = (math.sin(ar), -math.cos(ar))
    n = (math.cos(ar) * inner_sign, math.sin(ar) * inner_sign)
    cx, cy = h[0] + d[0] * L / 2, h[1] + d[1] * L / 2
    whole = E(cx, cy, L / 2, W, a - 90)
    half = Sh(lambda x, y: (x - h[0]) * n[0] + (y - h[1]) * n[1] > 0)
    rim = []
    for k in range(2, int(L)):
        u = k
        t = (u - L / 2) / (L / 2)
        w = W * math.sqrt(max(0, 1 - t * t))
        rim.append((h[0] + d[0] * u + n[0] * (w + 1.0), h[1] + d[1] * u + n[1] * (w + 1.0)))
    return whole, whole & half, whole - half, rim


def _trap(H, ha, theta, L, W, closed, dead, teeth_every=2, bulge=0.0):
    """La trampa de dos valvas con bisagra en H, mirando hacia ha (grados desde la vertical), abierta theta"""
    out_r, in_r = (DRY, DRYI) if dead else (LEAFL, INNER)
    it = []
    if closed:
        for s, a in ((1, ha - 5), (-1, ha + 5)):
            _, _, outer, _ = _lobe(H, a, L, W + bulge, s)
            it.append(P(outer, out_r))
        ar = math.radians(ha)
        if not dead:                                          # pestañas trabadas en la punta
            tx, ty = H[0] + math.sin(ar) * (L + 0.4), H[1] - math.cos(ar) * (L + 0.4)
            it.append(D([(int(tx) - 1, int(ty), CILIA), (int(tx) + 1, int(ty), CILIA), (int(tx), int(ty) - 1, CILIA)]))
    else:
        for s, a in ((1, ha - theta), (-1, ha + theta)):
            whole, inner, outer, rim = _lobe(H, a, L, W, s)
            it.append(P(whole, out_r))
            it.append(P(inner, in_r, line=False))
            if not dead:
                it.append(D([(int(math.floor(x)), int(math.floor(y)), CILIA) for x, y in rim[1::teeth_every]]))
    return it


def plantA_items(H, ctrl, ha, theta=50, closed=False, bulge=0.0, dead=False):
    """A «Cuello»: una atrapamoscas pequeña en un cuello largo y fino que se arquea; se echa atrás (aviso) y se
    lanza hacia delante al morder"""
    lv = DRY if dead else LEAFD
    it = [P(E(7.4, 22.8, 4.6, 0.9, -14), lv), P(E(16.4, 22.8, 4.0, 0.9, 16), lv)]
    it.append(P(tube(bez((12, 24.2), ctrl, H), 0.9), lv))
    it += _trap(H, ha, theta, 8.4, 2.3, closed, dead, bulge=bulge)
    return it


def plantB_items(lift=4, sway=0.0, bulge=0.0, droop=0.0, dead=False, bait=True):
    """B «Cepo» (el atrevido): dos hojas largas TUMBADAS en el suelo con dientes en el borde (un cepo de hojas) y una
    florecita de cebo en medio; al pisar al lado, las hojas saltan y se cierran de pie"""
    H = (12, 21.8)
    out = Xf(rot=droop, pivot=(12, 24))
    it = []
    if bait and lift < 40:
        it.append(P(tube([(12, 22), (12 + sway, 17.6)], 0.5), LEAFD if not dead else DRY))
        it.append(P(E(12 + sway, 16.8, 1.4, 1.1), PINK if not dead else DRY))
        it.append(D([(int(12 + sway), 16, YEL)] if not dead else []))
    closed = lift > 80
    it += _trap(H, 0, 90 - lift, 10.0, 2.4, closed, dead, teeth_every=2, bulge=bulge)
    for x in it:
        x.xf = out
    return it


def plant_frame(design, name):
    if design == 'A':
        k = {'idle1': dict(H=(13.0, 10.6), ctrl=(9.0, 17.0), ha=18, theta=46),
             'idle2': dict(H=(13.8, 10.8), ctrl=(9.6, 17.0), ha=22, theta=48),
             'tell1': dict(H=(9.6, 10.0), ctrl=(15.0, 17.0), ha=-12, theta=70),
             'tell2': dict(H=(9.0, 10.4), ctrl=(14.6, 17.4), ha=-16, theta=74),
             'snap1': dict(H=(13.8, 12.6), ctrl=(9.0, 18.0), ha=56, theta=22),
             'snap2': dict(H=(14.2, 13.4), ctrl=(9.0, 18.0), ha=62, closed=True),
             'chew1': dict(H=(13.0, 11.0), ctrl=(9.0, 17.0), ha=14, closed=True, bulge=0.6),
             'chew2': dict(H=(13.2, 11.4), ctrl=(9.0, 17.4), ha=18, closed=True),
             'sleep1': dict(H=(15.0, 17.0), ctrl=(11.0, 10.0), ha=118, closed=True),
             'sleep2': dict(H=(15.2, 17.4), ctrl=(11.2, 10.4), ha=122, closed=True, bulge=0.3),
             'dead': dict(H=(15.4, 20.6), ctrl=(13.0, 16.0), ha=96, theta=34, dead=True)}[name]
        return render(PW, PH, [(Xf(dx=1), plantA_items(**k), None)])
    k = {'idle1': dict(lift=4), 'idle2': dict(lift=6, sway=0.6),
         'tell1': dict(lift=16, sway=-0.6), 'tell2': dict(lift=11, sway=0.6),
         'snap1': dict(lift=52), 'snap2': dict(lift=86),
         'chew1': dict(lift=86, bulge=0.5), 'chew2': dict(lift=86),
         'sleep1': dict(lift=86, droop=16), 'sleep2': dict(lift=86, droop=19, bulge=0.3),
         'dead': dict(lift=-6, dead=True)}[name]
    return render(PW, PH, [(Xf(dx=1), plantB_items(**k), None)])


# ══ HOJAS, VISTA PREVIA Y MAQUETA ══════════════════════════════════════════════════════════════════════════════════
MOLE_NAMES = {'A': 'Periscopio', 'B': 'Gusano'}
FISH_NAMES = {'A': 'Mandibula', 'B': 'Aguja'}
PLANT_NAMES = {'A': 'Cuello', 'B': 'Cepo'}
DESC = {
    ('mole', 'A'): ['de perfil, de pie y flaco', 'hocico largo como un pico', 'sale recto del suelo'],
    ('mole', 'B'): ['(el atrevido) largo como', 'una serpiente; muerde de', 'punta y se hunde en arco'],
    ('fish', 'A'): ['casi todo cabeza: cuna', 'chata, cola fina, mandibula', 'roja salida con 2 dientes'],
    ('fish', 'B'): ['(el atrevido) larga y fina', 'como una lanza, pico de', 'dientes, aletas magenta'],
    ('plant', 'A'): ['atrapamoscas pequena en un', 'cuello largo: se echa atras', 'y se lanza a morder'],
    ('plant', 'B'): ['(el atrevido) un cepo de', 'hojas tumbadas en el suelo', 'con una flor de cebo'],
}


def mole_sheets():
    return {(d, i): [mole_frame(d, i, n) for n in MOLE_FRAMES] for d in 'AB' for i in ISLES}


def fish_sheets(): return {d: [fish_frame(d, n) for n in FISH_FRAMES] for d in 'AB'}


def plant_sheets(): return {d: [plant_frame(d, n) for n in PLANT_FRAMES] for d in 'AB'}


def check_margins(moles, fish, plants):
    bad = []
    for (d, i), fr in moles.items():
        for n, im in zip(MOLE_FRAMES, fr):
            if not margin_ok(im): bad.append('topo %s %s %s' % (d, i, n))
    for d, fr in fish.items():
        for n, im in zip(FISH_FRAMES, fr):
            if not margin_ok(im, bottom=False): bad.append('piraña %s %s' % (d, n))
    for d, fr in plants.items():
        for n, im in zip(PLANT_FRAMES, fr):
            if not margin_ok(im): bad.append('planta %s %s' % (d, n))
    return bad


try:
    FONT = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'PressStart2P.ttf'), 8)
    FONTM = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'PressStart2P.ttf'), 12)
    FONTB = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'PressStart2P.ttf'), 16)
except OSError:
    FONT = FONTM = FONTB = ImageFont.load_default()
S = 4
_tiles = {}


def tile(name):
    if name not in _tiles: _tiles[name] = Image.open(os.path.join(IMG, 'world', 'tiles', name)).convert('RGBA')
    return _tiles[name]


FILL = {'grass.png': 'dirt.png', 'jungle_grass.png': 'mud.png', 'ash.png': 'basalt.png'}


def ground(cv, x0, y0, w, h, name):
    """Una franja de suelo (la textura del bloque a escala del juego, 64 px el bloque) en x0..x0+w, y0..y0+h; debajo
    de la primera fila, el bloque cubierto (tierra bajo la hierba, basalto bajo la ceniza)"""
    for y in range(y0, y0 + h, 64):
        t = tile(name if y == y0 else FILL.get(name, name))
        for x in range(x0, x0 + w, t.width):
            part = t.crop((0, 0, min(t.width, x0 + w - x), min(t.height, y0 + h - y, 64)))
            cv.paste(part, (x, y), part)


def big(im, s=S): return im.resize((im.width * s, im.height * s), Image.NEAREST)


def put(cv, im, x, y, s=S, flip=False):
    b = big(im, s)
    if flip: b = b.transpose(Image.FLIP_LEFT_RIGHT)
    cv.alpha_composite(b, (int(x), int(y)))


WATER = (13, 77, 230, 89)                                    # (el tinte del agua del juego: 0.05, 0.30, 0.90, 0.35)


def water(cv, x0, y0, x1, y1):
    ov = Image.new('RGBA', (x1 - x0, y1 - y0), WATER)
    ImageDraw.Draw(ov).rectangle((0, 0, x1 - x0 - 1, 3), fill=(150, 200, 255, 110))
    cv.alpha_composite(ov, (x0, y0))


def text(cv, xy, s, font=FONT, fill='ffffff', shadow=True):
    d = ImageDraw.Draw(cv)
    if shadow: d.text((xy[0] + 1, xy[1] + 1), s, font=font, fill=(0, 0, 0, 200))
    d.text(xy, s, font=font, fill=hx(fill))


LABW, GAP = 230, 10


def preview(moles, fish, plants):
    fw = MW * S + GAP
    W = LABW + len(MOLE_FRAMES) * fw + 20
    parts = []
    # ── la fila de comparación: el jugador ×6, el Escarabajo azul ×4 y los nuevos ×4 (todos de pie en el suelo) ──
    lh = 190
    cv = Image.new('RGBA', (W, lh), hx(BG_JUNGLE))
    gy = lh - 48
    ground(cv, 0, gy, W, 48, 'jungle_grass.png')
    text(cv, (12, 10), 'ENEMIGOS NUEVOS  - propuesta (x4 como en el juego; el jugador x6)', FONTB)
    lineup = [('jugador x6', Image.open(os.path.join(IMG, 'player', 'monstrito1.png')).convert('RGBA'), 6),
              ('Escarabajo', Image.open(os.path.join(IMG, 'enemies', 'beetle', 'beetle-Sheet.png')).convert('RGBA').crop((0, 0, 22, 20)), 4),
              ('Gummy jungla', Image.open(os.path.join(IMG, 'enemies', 'gummy_jungle', 'gummy.png')).convert('RGBA'), 4),
              ('Topo A', moles[('A', 'jungla')][MOLE_FRAMES.index('idle1')], 4),
              ('Topo B', moles[('B', 'jungla')][MOLE_FRAMES.index('idle1')], 4),
              ('Monticulo', moles[('A', 'jungla')][0], 4),
              ('Pirana A', fish['A'][0], 4), ('Pirana B', fish['B'][0], 4),
              ('Planta A', plants['A'][0], 4), ('Planta B', plants['B'][0], 4)]
    x = 20
    for lab, im, s in lineup:
        bb = im.getbbox()
        y = gy - bb[3] * s if not lab.startswith('Pir') else gy - 30 - im.height * s
        put(cv, im, x, y, s)
        text(cv, (x, gy + 8), lab)
        x += max(im.width * s, len(lab) * 8 + 4) + 22
    parts.append(cv)
    # ── TOPOS: cada isla en su suelo, A arriba y B abajo ──
    for k, isle in enumerate(ISLES):
        rh = MH * S + 30
        cv = Image.new('RGBA', (W, 30 + 2 * rh), hx(ISLE_BG[isle]))
        ImageDraw.Draw(cv).rectangle((0, 0, W, 26), fill=hx('20202c'))
        text(cv, (12, 8), 'TOPO - %s' % isle.upper(), FONTM)
        if k == 0:
            for c, n in enumerate(MOLE_FRAMES): text(cv, (LABW + c * fw + 4, 9), n)
        for r, d in enumerate('AB'):
            y0 = 30 + r * rh
            gy = y0 + MH * S
            ground(cv, LABW - 10, gy, W - LABW + 10, 26, GROUND_TILE[isle])
            ImageDraw.Draw(cv).rectangle((0, y0, LABW - 14, y0 + rh - 4), fill=hx('2a3a2e'))
            text(cv, (10, y0 + 10), '%s  %s' % (d, MOLE_NAMES[d]), FONTM)
            for j, line in enumerate(DESC[('mole', d)]): text(cv, (10, y0 + 34 + j * 14), line)
            for c, im in enumerate(moles[(d, isle)]): put(cv, im, LABW + c * fw, y0)
        parts.append(cv)
    # ── PIRAÑAS: en el agua (nadar, muerta) y en el aire (salto, mordisco, cae) ──
    rh = 2 * FH * S + 20
    cv = Image.new('RGBA', (W, 30 + 2 * rh), hx(BG_JUNGLE))
    ImageDraw.Draw(cv).rectangle((0, 0, W, 26), fill=hx('20202c'))
    text(cv, (12, 8), 'PIRANA (solo jungla)  - 22x20, mira a la derecha', FONTM)
    for c, n in enumerate(FISH_FRAMES): text(cv, (LABW + c * fw + 4, 30 + 4), n)
    for r, d in enumerate('AB'):
        y0 = 30 + r * rh + 14
        surf = y0 + FH * S + 6
        ground(cv, LABW - 10, cv.height if False else y0 + rh - 34, W - LABW + 10, 30, 'mud.png')
        ImageDraw.Draw(cv).rectangle((0, y0, LABW - 14, y0 + rh - 20), fill=hx('2a3a2e'))
        text(cv, (10, y0 + 10), '%s  %s' % (d, FISH_NAMES[d]), FONTM)
        for j, line in enumerate(DESC[('fish', d)]): text(cv, (10, y0 + 34 + j * 14), line)
        for c, (n, im) in enumerate(zip(FISH_FRAMES, fish[d])):
            if n.startswith('swim'): yy = surf + 10
            elif n == 'dead': yy = surf - 8 * S
            else: yy = y0
            put(cv, im, LABW + c * fw, yy)
        water(cv, LABW - 10, surf, W, y0 + rh - 34)
    parts.append(cv)
    # ── PLANTAS ──
    rh = PH * S + 30
    fw2 = PW * S + GAP
    cv = Image.new('RGBA', (W, 30 + 2 * rh), hx(BG_JUNGLE))
    ImageDraw.Draw(cv).rectangle((0, 0, W, 26), fill=hx('20202c'))
    text(cv, (12, 8), 'PLANTA CARNIVORA (solo jungla)  - 26x24, de pie en el bloque', FONTM)
    for r, d in enumerate('AB'):
        y0 = 30 + r * rh
        gy = y0 + PH * S
        ground(cv, LABW - 10, gy, W - LABW + 10, 26, 'jungle_grass.png')
        ImageDraw.Draw(cv).rectangle((0, y0, LABW - 14, y0 + rh - 4), fill=hx('2a3a2e'))
        text(cv, (10, y0 + 10), '%s  %s' % (d, PLANT_NAMES[d]), FONTM)
        for j, line in enumerate(DESC[('plant', d)]): text(cv, (10, y0 + 34 + j * 14), line)
        for c, (n, im) in enumerate(zip(PLANT_FRAMES, plants[d])):
            put(cv, im, LABW + c * fw2, y0)
            if r == 0: text(cv, (LABW + c * fw2 + 4, y0 + 2), n)
    parts.append(cv)
    H = sum(p.height + 6 for p in parts)
    out = Image.new('RGBA', (W, H), hx('20202c'))
    y = 0
    for p in parts: out.paste(p, (0, y)); y += p.height + 6
    return out


# ── maqueta animada ──────────────────────────────────────────────────────────────────────────────────────────────
PLAYER = [Image.open(os.path.join(IMG, 'player', 'monstrito%d.png' % i)).convert('RGBA') for i in (1, 2, 3)]
BEETLE = Image.open(os.path.join(IMG, 'enemies', 'beetle', 'beetle-Sheet.png')).convert('RGBA').crop((0, 0, 22, 20))
HW = 384


def draw_player(cv, x, feet_y, frame=0, flip=False):
    im = PLAYER[frame]
    put(cv, im, x - im.width * 6 // 2, feet_y - im.height * 6, 6, flip)


def stars(cv, cx, cy, t):
    for k in range(3):
        a = t * 0.9 + k * 2.1
        x, y = cx + math.cos(a) * 30, cy + math.sin(a) * 9
        d = ImageDraw.Draw(cv)
        for dx, dy in ((0, -4), (-4, 0), (0, 0), (4, 0), (0, 4)):
            d.rectangle((int(x) + dx, int(y) + dy, int(x) + dx + 3, int(y) + dy + 3), fill=hx('ffe060'))


def zz(cv, x, y, t):
    for k in range(2):
        p = ((t + k * 6) % 12) / 12
        text(cv, (int(x + p * 20 + k * 8), int(y - p * 36)), 'z', FONTM if k else FONTB, 'ffffff')


def mole_scene(design, isle, t, sheets):
    cv = Image.new('RGBA', (HW, 200), hx(ISLE_BG[isle]))
    gy = 150
    ground(cv, 0, gy, HW, 50, GROUND_TILE[isle])
    text(cv, (8, 6), 'Topo %s %s - %s' % (design, MOLE_NAMES[design], isle))
    F = dict(zip(MOLE_FRAMES, sheets[(design, isle)]))
    px, pfoot, pfr = 260, gy, 0
    mole, mx = None, 0
    if t < 22:
        mx = 40 + (260 - 40) * t / 21
        mole = 'mound%d' % (1 + (t // 2) % 3)
    elif t < 41:
        mx = 260
        seq = ['emerge1'] * 2 + ['emerge2'] * 2 + ['bite1'] * 3 + ['bite2'] * 2 + ['bite1'] * 2 + ['bite2'] * 2 + \
              ['dive1'] * 2 + ['dive2'] * 2 + [None] * 2
        mole = seq[t - 22]
        if 24 <= t <= 34:                                     # el jugador salta para esquivar el mordisco
            u = (t - 24) / 10
            pfoot = gy - int(170 * u * (1 - u)); pfr = 1
    elif t < 48:
        mx = 260 - (t - 41) * 6
        mole = 'mound%d' % (1 + (t // 2) % 3)
        u = min(1, (t - 41) / 6)                              # salta… y culetazo
        pfoot = gy - int(90 * math.sin(math.pi * u)) if t < 47 else gy
        px = 260 - (t - 41) * 5; pfr = 1
    else:
        mx = 218
        px = 300
        if t < 50: mole = 'emerge2'
        elif t < 57: mole = 'dizzy1' if (t // 2) % 2 else 'dizzy2'
        else: mole = 'dead'
        if 54 <= t <= 57:                                     # lo pisa
            u = (t - 54) / 3
            px = 300 - int(82 * u); pfoot = gy - 30 - int(70 * math.sin(math.pi * min(u, 1) * 0.8))
            pfr = 1
        elif t > 57:
            px, pfoot = 218, gy - (8 if t < 60 else 0)
    if mole:
        put(cv, F[mole], mx - MW * S // 2, gy - MH * S, S, flip=mx > 250 and False)
        if mole.startswith('dizzy'): stars(cv, mx, gy - 74, t)
    draw_player(cv, px, pfoot, pfr)
    return cv


def fish_scene(design, t, sheets):
    cv = Image.new('RGBA', (HW, 240), hx(BG_JUNGLE))
    bank, surf = 128, 140
    ground(cv, 0, bank, 128, 112, 'jungle_grass.png')
    ground(cv, 256, bank, 128, 112, 'jungle_grass.png')
    ground(cv, 128, 208, 128, 32, 'mud.png')
    text(cv, (8, 6), 'Pirana %s %s' % (design, FISH_NAMES[design]))
    F = dict(zip(FISH_FRAMES, sheets[design]))
    fx, fy, fr, flip = 192, 176, 'swim1', False
    px, pfoot, pfr, pflip = 60, bank, 0, False
    T = t % 64
    if T < 16:                                                # nada de un lado a otro
        fx = 160 + 40 * math.sin(T / 16 * math.pi * 2)
        flip = math.cos(T / 16 * math.pi * 2) < 0
        fr = ['swim1', 'swim2', 'swim3'][T % 3]
        px = 40 + T * 4
    elif T < 34:                                              # el jugador cruza de un salto y la piraña salta
        u = (T - 16) / 17
        px = 104 + 190 * u; pfoot = bank - int(200 * u * (1 - u)); pfr = 1
        v = (T - 17) / 14
        if v < 0: fr = 'swim1'
        else:
            fx = 176 + 30 * v
            fy = surf + 10 - int(330 * v * (1 - v)) - 40
            fr = 'leap1' if v < 0.25 else 'leap2' if v < 0.4 else 'bite1' if v < 0.5 else 'bite2' if v < 0.6 else 'fall'
        if T >= 33: pfoot, pfr = bank, 0
    elif T < 48:
        px, pfoot, pflip = 300 - (T - 34) * 2, bank, True
        fx, fy = 200 - (T - 34) * 2, 176
        flip = True
        fr = ['swim1', 'swim2', 'swim3'][T % 3]
    else:                                                     # salta otra vez: el jugador la pisa en el aire
        v = (T - 48) / 8
        pflip = True
        if v <= 1:
            fx = 196 - 10 * v
            fy = surf + 10 - int(190 * v * (1 - v * 0.5)) - 30
            fr, flip = ('leap1' if v < 0.4 else 'leap2'), True
            px = 272 - 60 * v; pfoot = bank - int(150 * math.sin(math.pi * min(1, v * 0.9)))
            pfr = 1
        else:
            w = (T - 56) / 7
            fx, fy, fr = 186, min(surf - 30, surf - 150 + int(300 * w)), 'dead'
            px = 212 - 100 * w; pfoot = bank - int(120 * math.sin(math.pi * w)); pfr = 1
            if T == 63: pfoot, pfr = bank, 0
    put(cv, F[fr], fx - FW * S // 2, fy - FH * S // 2, S, flip)
    water(cv, 128, surf, 256, 208)
    draw_player(cv, px, pfoot, pfr, pflip)
    return cv


def plant_scene(design, t, sheets):
    cv = Image.new('RGBA', (HW, 200), hx(BG_JUNGLE))
    gy = 150
    ground(cv, 0, gy, HW, 50, 'jungle_grass.png')
    text(cv, (8, 6), 'Planta %s %s' % (design, PLANT_NAMES[design]))
    F = dict(zip(PLANT_FRAMES, sheets[design]))
    T = t % 112
    fr, px, pfoot, pfr, pflip = 'idle1', 30, gy, 0, False
    bx = by = None
    z = False
    if T < 16: fr = 'idle1' if (T // 4) % 2 == 0 else 'idle2'; px = 30 + T * 7; pfr = (T // 2) % 2 * 2
    elif T < 22: fr = 'tell1' if T % 2 else 'tell2'; px = 142 + (T - 16) * 2; pfr = (T // 2) % 2 * 2
    elif T < 30:                                              # pasa por encima de un salto: se cierra tarde
        u = (T - 22) / 7
        px = 154 + 130 * u; pfoot = gy - int(190 * u * (1 - u)); pfr = 1
        fr = 'tell1' if T < 24 else 'snap1' if T == 24 else 'snap2'
        if T == 29: pfoot, pfr = gy, 0
    elif T < 36: fr = 'snap2'; px = 284; pflip = True
    elif T < 38: fr = 'snap1'; px = 284; pflip = True
    elif T < 48:                                              # le tira un escarabajo
        px, pflip = 284, True
        fr = 'idle1' if (T // 4) % 2 == 0 else 'idle2'
        if T >= 41:
            u = (T - 41) / 6
            bx, by = 270 - 76 * u, gy - 80 - int(120 * u * (1 - u)) + int(40 * u)
        if T == 47: fr, bx = 'snap1', None
    elif T < 58: fr = 'chew1' if (T // 2) % 2 else 'chew2'; px, pflip = 284, True
    elif T < 82:                                              # duerme: el jugador pasa por encima sin peligro
        fr = 'sleep1' if (T // 4) % 2 == 0 else 'sleep2'; z = True
        px, pflip = 284 - max(0, T - 62) * 9, True
        pfr = (T // 2) % 2 * 2 if T > 62 else 0
    elif T < 86: fr = 'snap1' if T < 84 else 'idle1'; px = 100 + (T - 82) * 6; pfr = (T // 2) % 2 * 2
    elif T < 92:                                              # se cierra… y justo después lo pisa
        fr = 'tell1' if T % 2 else 'tell2'
        u = (T - 86) / 8
        px = 124 + 70 * u; pfoot = gy - int(170 * u * (1 - u * 0.4)); pfr = 1
        if T >= 89: fr = 'snap2'
    else:
        fr = 'snap2' if T < 94 else 'dead'
        px, pfoot = 192, gy - (78 if T < 94 else 10 if T < 96 else 0)
        pfr = 1 if T < 96 else 0
    put(cv, F[fr], 192 - PW * S // 2, gy - PH * S, S)
    if z: zz(cv, 210, gy - 100, T)
    if bx is not None: put(cv, BEETLE, bx - 44, by - 40, S, True)
    draw_player(cv, px, pfoot, pfr, pflip)
    return cv


def maqueta(moles, fish, plants, ticks_per_isle=64):
    frames = []
    n = ticks_per_isle * len(ISLES)
    for t in range(n):
        isle = ISLES[t // ticks_per_isle]
        tm = t % ticks_per_isle
        rows = [(mole_scene('A', isle, tm, moles), mole_scene('B', isle, tm, moles)),
                (fish_scene('A', t, fish), fish_scene('B', t, fish)),
                (plant_scene('A', t, plants), plant_scene('B', t, plants))]
        H = sum(a.height + 4 for a, _ in rows)
        cv = Image.new('RGBA', (HW * 2 + 4, H), hx('20202c'))
        y = 0
        for a, b in rows:
            cv.paste(a, (0, y)); cv.paste(b, (HW + 4, y)); y += a.height + 4
        frames.append(cv.convert('RGB'))
    return frames


def apply(moles, fish, plants, choice, force):
    """Escribe en assets/ el diseño elegido de cada uno (no pisa nada que exista salvo con --force)"""
    out = {}
    for isle in ISLES: out['enemies/mole/%s-Sheet.png' % isle] = sheet(moles[(choice['mole'], isle)])
    out['enemies/piranha/piranha-Sheet.png'] = sheet(fish[choice['piranha']])
    out['enemies/carnivoreplant/plant-Sheet.png'] = sheet(plants[choice['plant']])
    for rel, im in out.items():
        path = os.path.join(IMG, rel)
        if os.path.exists(path) and not force:
            print('  (existe, no se toca) ' + path); continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im.save(path)
        print('  ' + path)


# ── Lo que el juego necesita además de las hojas (al aplicar; nada de esto pisa lo que ya existe) ─────────────────
# Conjuntos de animación (assets/anim/enemies/<id>.json): una animación por estado, con los cuadros de la hoja por
# nombre (el código las pide así: docs/art/animation.md). El topo: la hoja de la pradera y una VARIANTE por isla.
ANIMS = {
    'enemies/mole': ('enemies/mole/pradera-Sheet.png', MW, MOLE_FRAMES, {
        'mound': (['mound1', 'mound2', 'mound3'], 9, True), 'emerge': (['emerge1', 'emerge2'], 14, False),
        'idle': (['idle1', 'idle2'], 3, True), 'bite': (['bite1', 'bite2'], 10, True),
        'dive': (['dive1', 'dive2'], 10, False), 'dizzy': (['dizzy1', 'dizzy2'], 4, True), 'dead': (['dead'], 8, False)}),
    'enemies/piranha': ('enemies/piranha/piranha-Sheet.png', FW, FISH_FRAMES, {
        'swim': (['swim1', 'swim2', 'swim3', 'swim2'], 8, True), 'leap': (['leap1', 'leap2'], 10, False),
        'bite': (['bite1', 'bite2'], 12, True), 'fall': (['fall'], 8, False), 'dead': (['dead'], 8, False)}),
    'enemies/carnivoreplant': ('enemies/carnivoreplant/plant-Sheet.png', PW, PLANT_FRAMES, {
        'idle': (['idle1', 'idle2'], 2, True), 'tell': (['tell1', 'tell2'], 14, True),
        'snap': (['snap1', 'snap2'], 14, False), 'chew': (['chew1', 'chew2'], 5, True),
        'sleep': (['sleep1', 'sleep2'], 1.5, True), 'dead': (['dead'], 8, False)}),
}
# La "z" de DORMIDO (la Planta carnívora dormida tras comer; compartida: assets/images/bosses/common/, animación
# `sleep_z` de bosses/common, la dibuja src/fx/BossFx.lua sleepZ). 6x7, blanca azulada con contorno oscuro.
ZZ = ['######', '#oooo#', '###o##', '##o###', '#o####', '#oooo#', '######']


def zz_image():
    im = Image.new('RGBA', (6, 7))
    for y, row in enumerate(ZZ):
        for x, ch in enumerate(row):
            im.putpixel((x, y), hx('e8f0ff') if ch == 'o' else hx('26304a'))
    # (el contorno solo alrededor de la letra: lo de fuera, transparente)
    px = im.load()
    for y in range(7):
        for x in range(6):
            if ZZ[y][x] == '#' and not any(0 <= x + dx < 6 and 0 <= y + dy < 7 and ZZ[y + dy][x + dx] == 'o'
                                           for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                px[x, y] = (0, 0, 0, 0)
    return im


def apply_extras():
    sys.path.insert(0, os.path.join(ROOT, 'tools', 'anim'))
    import common
    for sid, (img, fw, names, anims) in ANIMS.items():
        path = 'assets/images/' + img
        h = Image.open(os.path.join(ROOT, path)).height
        doc = {'id': sid, 'scale': 4, 'origin': [0.5, 1], 'fallback': list(anims)[0],
               'frames': [{'image': path, 'x': i * fw, 'y': 0, 'w': fw, 'h': h} for i in range(len(names))], 'anims': {}}
        for a, (fr, fps, loop) in anims.items():
            doc['anims'][a] = {'frames': [names.index(n) + 1 for n in fr], 'fps': fps, 'loop': loop}
        if sid == 'enemies/mole':
            doc['variants'] = {i: {'from': path, 'to': path.replace('pradera', i)} for i in ISLES if i != 'pradera'}
        print(('  ' if common.write(doc) else '  (existe, no se toca) ') + common.path_of(sid))
    zp = os.path.join(IMG, 'bosses', 'common', 'sleep_z.png')
    if not os.path.exists(zp):
        zz_image().save(zp)
        print('  ' + zp)
    print('  conjunto bosses/common: %d animación(es) añadida(s)' % common.add_anims(
        'bosses/common', [('sleep_z', 'assets/images/bosses/common/sleep_z.png', None, {'fps': 1})]))


def main():
    args = sys.argv[1:]
    moles, fish, plants = mole_sheets(), fish_sheets(), plant_sheets()
    bad = check_margins(moles, fish, plants)
    for b in bad: print('  AVISO margen de 1 px: ' + b)
    if '--apply' in args:
        choice = {'mole': 'A', 'piranha': 'A', 'plant': 'A'}
        for k in choice:
            if '--' + k in args: choice[k] = args[args.index('--' + k) + 1]
        apply(moles, fish, plants, choice, '--force' in args)
        apply_extras()
        return
    os.makedirs(os.path.join(OUT, 'archivos'), exist_ok=True)
    for (d, isle), fr in moles.items(): sheet(fr).save(os.path.join(OUT, 'archivos', 'topo%s_%s-Sheet.png' % (d, isle)))
    for d, fr in fish.items(): sheet(fr).save(os.path.join(OUT, 'archivos', 'pirana%s-Sheet.png' % d))
    for d, fr in plants.items(): sheet(fr).save(os.path.join(OUT, 'archivos', 'planta%s-Sheet.png' % d))
    preview(moles, fish, plants).save(os.path.join(OUT, 'vista_previa.png'))
    print('  ' + os.path.join(OUT, 'vista_previa.png'))
    if '--no-gif' not in args:
        fr = maqueta(moles, fish, plants)
        fr[0].save(os.path.join(OUT, 'maqueta.gif'), save_all=True, append_images=fr[1:], duration=90, loop=0)
        print('  ' + os.path.join(OUT, 'maqueta.gif'))


if __name__ == '__main__':
    main()
