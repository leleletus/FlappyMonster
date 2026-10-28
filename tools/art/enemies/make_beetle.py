#!/usr/bin/env python3
# tools/art/enemies/make_beetle.py — el ESCARABAJO RINOCERONTE (enemigo exclusivo de la jungla, isla futura) y el
# ESCARABAJO RINOCERONTE GIGANTE, su jefe (docs/bosses/new-bosses-plan.md § 5). El usuario eligió el diseño D (mezcla
# del A y el C) el 2026-10-28; --apply lo escribe en assets/ (las entidades aún no existen).
#
# Hoja: cuadros de 22x20 mirando a la DERECHA (el cuerno pide sitio delante y las alas detrás). Estilo de la casa
# (docs/art/style-rules.md): contorno = el tono más oscuro del PROPIO color, luz arriba a la izquierda, sombra abajo a
# la derecha, 3-4 tonos, 1 px de margen; el brillo de caparazón (los escarabajos relucen) es una raya clara curva.
# El gigante es LA MISMA hoja a escala 12 (regla de los "Mega"), con las marcas doradas de la Furia del Espejo (el
# fragmento que lo hizo crecer) y el ojo encendido; cuadros suyos además de los del pequeño: lanzar con el cuerno,
# élitros abiertos y alas zumbando (salto), aterrizaje aplastado.
#
#   python tools/art/enemies/make_beetle.py           → FlappyMonster_pruebas/escarabajo/ (vista_previa.png, mockups, GIFs)
#   python tools/art/enemies/make_beetle.py --apply   → assets/: el diseño elegido (D) + assets/anim/enemies/beetle.json y
#                                                       bosses/giantbeetle.json
import os, math
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = '/home/mtvemo/FlappyMonster_pruebas/escarabajo'
W, H = 22, 20
OY = 4                                              # (4 px de aire arriba: el cuerno alto y las alas del gigante)


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# Diseños: caparazón (brillo, luz, medio, sombra, contorno), patas/cuerno (medio, sombra), ojo
DESIGNS = {
    'A': dict(name='Bronce', shine='#e9f7a8', light='#8fcf4e', mid='#4f9a3a', shade='#2f6a32', outline='#173a22',
              horn='#c88a3c', hornS='#8a5422', hornO='#4a2a12', leg='#3a2a1e', eye='#120c08'),
    'B': dict(name='Zafiro', shine='#d8f4ff', light='#5ec2f0', mid='#2f74c8', shade='#22489a', outline='#121f4e',
              horn='#3f4a7a', hornS='#262d55', hornO='#11142e', leg='#1c2040', eye='#ffffff'),
    'C': dict(name='Castaña', shine='#ffe0b0', light='#d68a4a', mid='#9c5228', shade='#6a3218', outline='#34160a',
              horn='#5a2c14', hornS='#3c1c0c', hornO='#1e0c04', leg='#2a1408', eye='#ffe9a0'),
    # (el usuario, 2026-10-28: "una mezcla entre el A y el C") — dos mezclas:
    # D: élitros castaños con reflejo verde metálico (el brillo del A sobre el cuerpo del C); protórax y cabeza verdes
    'D': dict(name='Bronce castaño', shine='#e9f7a8', light='#9cb24a', mid='#8a5228', shade='#5e3018', outline='#2e1608',
              pron=('#8fcf4e', '#4f9a3a', '#2f6a32'), horn='#7a4220', hornS='#4e2810', hornO='#24100a', leg='#6e3e1c', eye='#120c08'),
    # E: élitros verdes del A; protórax, cabeza, cuerno y patas castaños del C
    'E': dict(name='Verde y castaña', shine='#e9f7a8', light='#8fcf4e', mid='#4f9a3a', shade='#2f6a32', outline='#173a22',
              pron=('#d68a4a', '#9c5228', '#6a3218'), pronO='#34160a', horn='#5a2c14', hornS='#3c1c0c', hornO='#1e0c04',
              leg='#6e3e1c', eye='#120c08'),
}
MIX = 'D'                                                   # (la mezcla A+C de los GIFs y las maquetas del jefe)
GOLD, GOLD_S, GLOW, GLOW_C = hx('#ffd84a'), hx('#c4901c'), hx('#ff6a2a'), hx('#ffe08a')
EYE_SHINE = hx('#f4f0e0')

# ── las piezas de cada cuadro (de pie, mirando a la derecha; las poses las mueven) ─────────────────────────────────
# élitros: una cúpula alta; protórax: un bloque redondo delante, con un espolón; cabeza baja con el ojo; el CUERNO
# grande sale de la cabeza, sube hacia delante y se curva hacia atrás (2 px de grueso en la base)
ELYTRA = (7.0, 8.2 + OY, 6.2, 5.4)
PRONOTUM = (12.8, 8.0 + OY, 2.9, 2.9)
HEAD = (15.6, 9.4 + OY, 2.2, 1.9)
HORNS = {
    'up': [(16, 12), (17, 12), (17, 11), (18, 11), (17, 10), (18, 10), (18, 9), (18, 8), (17, 7), (18, 7), (17, 6), (16, 5)],
    'fwd': [(16, 13), (17, 13), (17, 12), (18, 12), (19, 12), (19, 11), (20, 11), (20, 10)],
    'toss': [(16, 12), (16, 11), (17, 11), (16, 10), (17, 10), (17, 9), (17, 8), (17, 7), (16, 6), (16, 5), (15, 4)],
}
SPUR = [(14, 9), (15, 8)]
# PATAS (v2; el usuario: "no parece que camine"): tres patas de este lado y, detrás y más oscuras, las tres del otro;
# cada una con fémur y tibia (rodilla) y uña. Andar = trípode: delantera y trasera de un lado con la del medio del
# otro; en el APOYO el pie se queda en el suelo y va hacia atrás, en el VUELO se levanta y vuelve adelante.
# (cadera en x, pie en reposo respecto a la cadera, hacia dónde dobla la rodilla): trasera, media, delantera
LEGS = ((4, -3, -1), (8, 0, 0), (12, 3, 1))
GROUND = 14 + OY
# gait: ('walk', fase 0..1, zancada) · ('flip', fase) · ('plant', 1|2) · ('dangle', vaivén) · ('splay',)
FRAMES = {
    'walk1': dict(dy=0, shear=0.0, horn='up', gait=('walk', 0.0, 1.5)),
    'walk2': dict(dy=0, shear=0.0, horn='up', gait=('walk', 0.25, 1.5)),
    'walk3': dict(dy=0, shear=0.0, horn='up', gait=('walk', 0.5, 1.5)),
    'walk4': dict(dy=0, shear=0.0, horn='up', gait=('walk', 0.75, 1.5)),
    'charge1': dict(dy=0, shear=0.16, horn='fwd', gait=('walk', 0.0, 2.6)),
    'charge2': dict(dy=-1, shear=0.16, horn='fwd', gait=('walk', 0.25, 2.6)),
    'charge3': dict(dy=0, shear=0.16, horn='fwd', gait=('walk', 0.5, 2.6)),
    'charge4': dict(dy=-1, shear=0.16, horn='fwd', gait=('walk', 0.75, 2.6)),
    'flip1': dict(flip=True, horn='fwd', gait=('flip', 0.0)),
    'flip2': dict(flip=True, horn='fwd', gait=('flip', 0.33)),
    'flip3': dict(flip=True, horn='fwd', gait=('flip', 0.66)),
    'toss1': dict(dy=0, shear=0.2, horn='fwd', gait=('plant', 1)),
    'toss2': dict(dy=-1, shear=-0.18, horn='toss', gait=('plant', 2)),
    'fly1': dict(dy=-3, shear=0.0, horn='up', gait=('dangle', 0), wings=1),
    'fly2': dict(dy=-3, shear=0.0, horn='up', gait=('dangle', 1), wings=2),
    'slam': dict(dy=1, shear=0.0, horn='up', gait=('splay',), squash=True),
}
SMALL = ['walk1', 'walk2', 'walk3', 'walk4', 'charge1', 'charge2', 'charge3', 'charge4', 'flip1', 'flip2', 'flip3']
BOSS = SMALL + ['toss1', 'toss2', 'fly1', 'fly2', 'slam']


def line(a, b):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    return [(int(round(x0 + (x1 - x0) * i / n)), int(round(y0 + (y1 - y0) * i / n))) for i in range(n + 1)]


def leg_points(gait, hip, rest, kd, phase_off, flip):
    """Una pata: [cadera → rodilla → pie] + la uña, según el paso"""
    hx_, hy_ = hip
    g = gait[0]
    if g == 'walk':
        p = (gait[1] + phase_off) % 1.0
        st = gait[2]
        if p < 0.5: fx, fy = hx_ + rest + st * (1 - 4 * p), GROUND                # (apoyo: el pie va hacia atrás)
        else:
            t = (p - 0.5) / 0.5
            fx, fy = hx_ + rest - st + 2 * st * t, GROUND - round(2 * math.sin(math.pi * t))   # (vuelo: sube y vuelve)
        knee = (hx_ + kd + (fx - hx_) * 0.45, min(hy_ + 1, fy - 2))
    elif g == 'flip':
        w = math.sin(2 * math.pi * (gait[1] + phase_off))
        fx, fy = hx_ + rest * 0.6 + round(1.5 * w), hy_ - 4 + round(abs(w))
        knee = (hx_ + kd * 2 + round(w * 0.5), hy_ - 2)
    elif g == 'plant':
        push = {1: (-4, 0, 3), 2: (-5, -1, 4)}[gait[1]]
        fx = hx_ + {-1: push[0], 0: push[1], 1: push[2]}[kd]
        fy = GROUND - (2 if gait[1] == 2 and kd == 1 else 0)                   # (al lanzar, la delantera se levanta)
        knee = (hx_ + kd * 2 + (fx - hx_) * 0.3, hy_ + 1)
    elif g == 'dangle':
        sway = (-1, 1)[gait[1]] * (1 if phase_off < 0.5 else -1)
        fx, fy = hx_ - 1 + sway + kd, hy_ + 4
        knee = (hx_ + kd + 1, hy_ + 2)
    else:                                                                      # splay: aplastado, patas abiertas
        fx, fy = hx_ + rest * 1.5 + kd, GROUND
        knee = (hx_ + kd * 2 + rest * 0.6, hy_)
    foot = (int(round(fx)), int(round(fy)))
    knee = (int(round(knee[0])), int(round(knee[1])))
    pts = line(hip, knee) + line(knee, foot)[1:]
    claw = (foot[0] + (kd if kd else (1 if fx >= hx_ else -1)), foot[1] if not flip else foot[1])
    return pts + [claw]


def ell(cx, cy, rx, ry, rot=0.0):
    out = {}
    c, s_ = math.cos(rot), math.sin(rot)
    for y in range(-4, H + 4):
        for x in range(-4, W + 4):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u, v = dx * c + dy * s_, -dx * s_ + dy * c
            nx, ny = u / rx, v / ry
            if nx * nx + ny * ny <= 1.0: out[(x, y)] = (nx * c - ny * s_, nx * s_ + ny * c)
    return out


def frame(D, name, boss=False):
    F = FRAMES[name]
    C = {k: hx(v) for k, v in D.items() if isinstance(v, str) and k != 'name'}
    flip, sq, wings = F.get('flip'), F.get('squash'), F.get('wings', 0)
    part = {}                                       # (x, y) -> (pieza, color)
    ex, ey, erx, ery = ELYTRA
    if sq: ery, erx, ey = ery * 0.8, erx * 1.08, ey + 1.0
    floor = 10.5 + OY + (0.6 if sq else 0)

    def put(pts, kind, pal):
        for (x, y), (nx, ny) in pts.items():
            lt = -(0.55 * nx + 0.85 * ny)
            part[(x, y)] = (kind, pal[0] if lt > 0.5 else (pal[1] if lt > -0.05 else pal[2]))

    shell = (C['light'], C['mid'], C['shade'])
    if wings:                                       # el abdomen (lo que queda debajo del élitro levantado)
        put({p: n for p, n in ell(ex + 0.5, ey + 1.6, erx - 0.8, ery - 1.8).items() if p[1] + 0.5 <= floor}, 'body', (C['mid'], C['shade'], C['shade']))
    else:
        put({p: n for p, n in ell(ex, ey, erx, ery).items() if p[1] + 0.5 <= floor}, 'elytra', shell)
    pron = tuple(hx(c) for c in D['pron']) if 'pron' in D else shell
    put({p: n for p, n in ell(*PRONOTUM).items() if p[1] + 0.5 <= floor + 0.4}, 'pron', pron)
    put(ell(*HEAD), 'head', (pron[1], pron[2], hx(D.get('pronO', D['outline']))))
    for p in SPUR: part[p] = ('horn', C['horn'])
    for i, p in enumerate(HORNS[F['horn']]): part[p] = ('horn', C['horn'] if i % 3 != 2 else C['hornS'])
    # pose: inclinar (el frente baja o sube) y subir/bajar
    sh, dy = F.get('shear', 0.0), F.get('dy', 0)
    moved = {}
    for (x, y), v in part.items():
        moved[(x, y + dy + int(round(sh * (x - 9))))] = v
    part = moved
    if wings:                                       # élitro levantado hacia atrás-arriba (giro sobre el protórax) y alas
        ang = 0.75                                  # (el élitro: girado sobre su borde delantero, la punta arriba-atrás)
        el = ell(ex + 0.5, ey - 3.6 + dy, erx * 0.85, ery * 0.5, ang)
        wing_ang = (0.6, 0.12)[wings - 1]           # (las alas: largas y finas, hacia atrás: arriba o casi horizontales)
        wcx = ex - 4.0
        wg = ell(wcx, ey - 2.6 + dy + (0 if wings == 1 else 2.0), 7.6, 1.8, wing_ang)
        for p in wg:
            vein = (p[0] - p[1]) % 4 == 0
            part[p] = ('wing', (176, 156, 110, 255) if vein else (238, 230, 200, 255))
        for p, n in el.items():
            lt = -(0.55 * n[0] + 0.85 * n[1])
            part[p] = ('elytra', C['light'] if lt > 0.5 else (C['mid'] if lt > -0.05 else C['shade']))
    if flip:                                        # patas arriba: el cuerpo, dado la vuelta, apoyado en el suelo
        ys = [y for (x, y) in part]
        top, bot = min(ys), max(ys)
        part = {(x, top + bot - y): v for (x, y), v in part.items()}
        shift = GROUND - max(y for (x, y) in part)
        part = {(x, y + shift): v for (x, y), v in part.items()}
    # patas: las de este lado y, detrás y más oscuras, las del otro (desfasadas medio paso, 1 px atrás)
    body_pts = [p for p, v in part.items() if v[0] in ('elytra', 'pron', 'body', 'head')]
    def hip_at(x):
        col = [y for (xx, y) in body_pts if xx == x]
        if not col: col = [y for (xx, y) in body_pts if abs(xx - x) <= 1]
        return (x, (min(col) - 0) if flip else (max(col) + 0))
    legs, far = [], []
    for (lx, rest, kd) in LEGS:
        tripod = 0.0 if kd != 0 else 0.5                                    # (trasera y delantera juntas; la media, al revés)
        legs += leg_points(F['gait'], hip_at(lx), rest, kd, tripod, flip)
        far += leg_points(F['gait'], hip_at(lx - 1), rest, kd, (tripod + 0.5) % 1.0, flip)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0)); px = img.load()
    inside = lambda p: 0 < p[0] < W - 1 and 0 < p[1] < H - 1
    for p in far:
        if inside(p) and p not in part: px[p] = C['outline'] if 'pronO' not in D else hx(D['pronO'])
    for p in legs:
        if inside(p) and p not in part: px[p] = C['leg']
    for p, (k, col) in part.items():
        if inside(p): px[p] = col
    # contorno: el tono más oscuro de cada pieza; las uniones entre piezas, también
    solid = {p for p in part if inside(p)}
    out = {}
    for p in solid:
        k = part[p][0]
        nb = [(p[0] + a, p[1] + b) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        if any(q not in solid for q in nb):
            out[p] = C['hornO'] if k == 'horn' else ((150, 128, 84, 255) if k == 'wing' else C['outline'])
        elif k == 'elytra' and any(q in solid and part[q][0] == 'pron' for q in nb):
            out[p] = C['outline']                   # (la unión élitros-protórax)
    for p, col in out.items(): px[p] = col
    # brillo del caparazón: una raya curva arriba a la izquierda de los élitros
    if not flip and not wings:
        cx_, cy_ = ex, ey + dy + (1 if sq else 0)
        for t in range(5):
            a = 2.55 - t * 0.2
            p = (int(round(cx_ + erx * 0.66 * math.cos(a))), int(round(cy_ - ery * 0.66 * math.sin(a) + sh * 0)))
            if p in solid and p not in out and part[p][0] == 'elytra': px[p] = C['shine']
    # el ojo (v2; el usuario: "un poco más notable"): 2x2, oscuro con un punto de brillo arriba-delante
    eye = [p for p in solid if part[p][0] == 'head' and p not in out]
    if eye:
        cy_e = sum(q[1] for q in eye) / len(eye)
        e = max(eye, key=lambda p: (p[0] * 2 - abs(p[1] + 0.5 - cy_e) * 1.5))
        ex0, ey0 = e[0] - 1, int(round(cy_e - 1))
        for q in ((ex0, ey0), (ex0 + 1, ey0), (ex0, ey0 + 1), (ex0 + 1, ey0 + 1)):
            if q in solid: px[q] = GLOW if boss else C['eye']
        if (ex0 + 1, ey0) in solid: px[ex0 + 1, ey0] = GLOW_C if boss else EYE_SHINE
    # la Furia del Espejo (gigante): una RUNA dorada en el centro de los élitros (rombo con el corazón encendido) y
    # una franja dorada a lo largo del borde de abajo del caparazón
    if boss and not flip:
        ely = [p for p in solid if part[p][0] == 'elytra' and p not in out]
        if ely:
            mx = int(round(sum(p[0] for p in ely) / len(ely))); my = int(round(sum(p[1] for p in ely) / len(ely)))
            for q, col in (((mx, my - 1), GOLD), ((mx - 1, my), GOLD), ((mx + 1, my), GOLD_S), ((mx, my + 1), GOLD_S), ((mx, my), GLOW)):
                if q in solid and q not in out: px[q] = col
            low = max(p[1] for p in ely)
            for p in ely:
                if p[1] == low and p[0] % 2 == 0: px[p] = GOLD_S
    return img


def sheet(D, names, boss=False):
    img = Image.new('RGBA', (W * len(names), H), (0, 0, 0, 0))
    for i, n in enumerate(names): img.alpha_composite(frame(D, n, boss), (i * W, 0))
    return img


# ── los ataques ────────────────────────────────────────────────────────────────────────────────────────────────────
def stone_block():
    """Bloque del templo (16x16): piedra con un glifo de escarabajo tallado"""
    S, L, M, D_, O = hx('#e8dcb8'), hx('#c9b98c'), hx('#a28f62'), hx('#76653f'), hx('#45391f')
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); p = img.load()
    for y in range(1, 15):
        for x in range(1, 15):
            p[x, y] = O if x in (1, 14) or y in (1, 14) else (L if x + y < 12 else (M if x + y < 22 else D_))
    for x in range(2, 14): p[x, 2] = S
    for y in range(2, 14): p[2, y] = S if y < 8 else L
    glyph = [(7, 5), (8, 5), (6, 6), (9, 6), (6, 7), (7, 7), (8, 7), (9, 7), (6, 8), (9, 8), (7, 9), (8, 9), (5, 7), (10, 7),
             (5, 9), (10, 9), (7, 4), (8, 3)]
    for g in glyph: p[g] = D_
    for x, y in ((11, 11), (12, 12), (4, 12)): p[x, y] = D_
    return img


def debris():
    """Tres cascotes (8x8 cada uno) que caen del techo al chocar el cuerno"""
    img = Image.new('RGBA', (24, 8), (0, 0, 0, 0)); p = img.load()
    L, M, O = hx('#c9b98c'), hx('#8c7a50'), hx('#45391f')
    shapes = [[(2, 2), (3, 2), (4, 2), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (2, 4), (3, 4), (4, 4), (5, 4), (3, 5), (4, 5)],
              [(3, 1), (4, 1), (2, 2), (3, 2), (4, 2), (5, 2), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (3, 4), (4, 4), (5, 4), (4, 5)],
              [(2, 3), (3, 3), (4, 3), (2, 4), (3, 4), (4, 4), (3, 5)]]
    for i, sh in enumerate(shapes):
        ss = set(sh)
        for x, y in sh:
            edge = any((x + dx, y + dy) not in ss for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            p[i * 8 + x, y] = O if edge else (L if x + y < 6 else M)
    return img


def shockwave():
    """Onda del suelo al aterrizar (4 cuadros de 24x12): polvo y piedra que se levanta y se deshace"""
    img = Image.new('RGBA', (96, 12), (0, 0, 0, 0)); p = img.load()
    L, M, D_, O = hx('#f2e4b8'), hx('#d1b97c'), hx('#9c8451'), hx('#5c4a28')
    for f in range(4):
        h_ = [5, 8, 9, 6][f]; w_ = [10, 16, 20, 22][f]
        for x in range(w_):
            col = int(h_ * math.sin(math.pi * (x + 0.5) / w_) ** 0.7) - (f == 3 and x % 3 == 0)
            for y in range(col):
                X, Y = f * 24 + 1 + x, 11 - y
                if 0 <= Y < 12:
                    top = y == col - 1
                    p[X, Y] = O if (top and f < 3) or x in (0, w_ - 1) else (L if y > col * 0.6 else (M if y > col * 0.3 else D_))
        if f == 3:
            for x in range(0, w_, 2): p[f * 24 + 1 + x, 11 - (x % 5)] = (0, 0, 0, 0)
    return img


def dust():
    """Nube de polvo (4 cuadros de 16x16): al cargar, al chocar y al voltearse"""
    img = Image.new('RGBA', (64, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    L, M, O = hx('#f4ead0'), hx('#d8c79e'), hx('#9c8a62')
    for f in range(4):
        r = [3, 5, 6, 6][f]
        puffs = [(5, 10), (10, 10), (8, 7)] if f < 3 else [(4, 11), (11, 11), (8, 8)]
        for (x, y) in puffs:
            rr = r - (f == 3) * 2
            d.ellipse([f * 16 + x - rr // 2 - 1, y - rr // 2 - 1, f * 16 + x + rr // 2 + 1, y + rr // 2 + 1], fill=O)
        for (x, y) in puffs:
            rr = r - (f == 3) * 2
            d.ellipse([f * 16 + x - rr // 2, y - rr // 2, f * 16 + x + rr // 2, y + rr // 2], fill=M if f > 1 else L)
    return img


# ── vistas previas, maquetas y GIFs ────────────────────────────────────────────────────────────────────────────────
def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def load(rel):
    return Image.open(os.path.join(ROOT, rel)).convert('RGBA')


try:
    from PIL import ImageFont
    FONT = ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans.ttf', 15)
except Exception:
    FONT = None


def text(d, xy, s, fill=(255, 255, 255, 255)):
    d.text((xy[0] + 1, xy[1] + 1), s, fill=(0, 0, 0, 255), font=FONT); d.text(xy, s, fill=fill, font=FONT)


def preview():
    rows = []
    for k in ('D', 'E'):
        D = DESIGNS[k]
        rows.append((f'Pequeño {k} "{D["name"]}" (x6): andar 1-4 · cargar 1-4 · patas arriba 1-3', up(sheet(D, SMALL), 6)))
    for k in ('D', 'E'):
        rows.append((f'Gigante {k} (x6; en el juego x12): lo mismo + lanzar 1-2 · alas 1-2 · aterrizaje', up(sheet(DESIGNS[k], BOSS, True), 6)))
    atk = Image.new('RGBA', (16 + 24 + 96 + 64 + 30, 16), (0, 0, 0, 0))
    x = 0
    for im in (stone_block(), debris(), shockwave(), dust()):
        atk.alpha_composite(im, (x, 16 - im.height)); x += im.width + 10
    rows.append(('Ataques (x6): bloque del templo · cascotes · onda del suelo (4) · polvo (4)', up(atk, 6)))
    Wt = max(im.width for _, im in rows) + 40
    Ht = sum(im.height + 34 for _, im in rows) + 20
    out = Image.new('RGBA', (Wt, Ht), (52, 78, 58, 255)); d = ImageDraw.Draw(out)
    y = 10
    for title, im in rows:
        text(d, (20, y), title); y += 18
        out.alpha_composite(im, (20, y)); y += im.height + 16
    out.save(os.path.join(OUT, 'vista_previa.png'))


def jungle_bg(Wp, Hp, temple=False):
    """Fondo de maqueta con los cielos y adornos del juego (bosque + tropical) y suelo de hierba o de piedra"""
    bg = Image.new('RGBA', (Wp, Hp), (120, 190, 210, 255))
    for rel in ('assets/images/world/sky/forest_far.png', 'assets/images/world/sky/forest_mid.png', 'assets/images/world/sky/forest_near.png'):
        try:
            im = load(rel); k = max(1, Hp // im.height)
            im = up(im, k)
            for x in range(0, Wp, im.width): bg.alpha_composite(im, (x, Hp - im.height))
        except Exception: pass
    tile = load('assets/images/world/tiles/stone.png' if temple else 'assets/images/world/tiles/grass.png').crop((0, 0, 64, 64))
    gy = Hp - 64
    for x in range(0, Wp, 64): bg.alpha_composite(tile, (x, gy))
    return bg, gy


def deco(bg, gy, temple=False):
    try:
        palm = up(load('assets/images/world/decorations/foliage/palmtree/palmtree.png'), 4)
        leaves = up(load('assets/images/world/decorations/foliage/palmtree/palmleaves.png'), 4)
        for x in (40, bg.width - 220):
            bg.alpha_composite(palm, (x, gy - palm.height)); bg.alpha_composite(leaves, (x + palm.width // 2 - leaves.width // 2 - 8, gy - palm.height - int(leaves.height * 0.7)))
        fern = up(load('assets/images/world/decorations/tropical/fern.png'), 4)
        for x in (300, 620, bg.width - 380): bg.alpha_composite(fern, (x, gy - fern.height))
        tiki = load('assets/images/world/decorations/tropical/tiki_torch-Sheet.png')
        th = tiki.height; tiki = up(tiki.crop((0, 0, th if tiki.width > th else tiki.width, th)), 4)
        if temple:
            for x in (180, bg.width - 280): bg.alpha_composite(tiki, (x, gy - tiki.height))
    except Exception as e:
        print('  (adornos:', e, ')')


def player():
    return up(load('assets/images/player/monstrito1.png'), 6)


def mockups():
    # 1) nivel de la jungla: los tres diseños del pequeño, el jugador, un bloque
    bg, gy = jungle_bg(1280, 720); deco(bg, gy)
    d = ImageDraw.Draw(bg)
    pl = player(); bg.alpha_composite(pl, (160, gy - pl.height))
    for i, k in enumerate(('A', 'C', 'D', 'E')):
        D = DESIGNS[k]
        im = up(frame(D, ('walk1', 'walk3', 'charge1', 'walk2')[i]), 4)
        x = 400 + i * 170
        bg.alpha_composite(im, (x, gy - im.height + 4))
        text(d, (x, gy - im.height - 16), f'{k} {D["name"]}')
    blk = up(stone_block(), 4); bg.alpha_composite(blk, (1100, gy - 64))
    text(d, (16, 16), 'Maqueta: nivel de la jungla — Escarabajo Rinoceronte (x4), jugador (x6), bloque del templo (x4)')
    bg.save(os.path.join(OUT, 'maqueta_nivel.png'))
    # 2) el templo: el gigante (x12), el jugador, la onda del suelo y bloques
    bg, gy = jungle_bg(1600, 900, temple=True); deco(bg, gy, temple=True)
    d = ImageDraw.Draw(bg)
    boss = up(frame(DESIGNS[MIX], 'walk1', True), 12)
    bg.alpha_composite(boss, (820, gy - boss.height + 12))
    pl = player(); bg.alpha_composite(pl, (300, gy - pl.height))
    sw = up(shockwave().crop((48, 0, 72, 12)), 6); bg.alpha_composite(sw, (620, gy - sw.height))
    for x, yy in ((520, 300), (700, 180)):
        bg.alpha_composite(up(stone_block(), 4), (x, yy))
    text(d, (16, 16), 'Maqueta: arena del templo — Escarabajo Rinoceronte Gigante (x12) con la Furia del Espejo, jugador (x6), onda y bloques')
    bg.save(os.path.join(OUT, 'maqueta_jefe.png'))


def gif(name, frames, ms, k, bgc=(52, 78, 58, 255), pad=8):
    w = max(f.width for f in frames) * k + pad * 2; h = max(f.height for f in frames) * k + pad * 2
    out = []
    for f in frames:
        c = Image.new('RGBA', (w, h), bgc); c.alpha_composite(up(f, k), (pad, h - pad - f.height * k))
        out.append(c.convert('P', palette=Image.ADAPTIVE))
    out[0].save(os.path.join(OUT, name), save_all=True, append_images=out[1:], duration=ms, loop=0, disposal=2)


def gifs():
    A = DESIGNS[MIX]
    WALK, CHARGE, FLIP = ['walk1', 'walk2', 'walk3', 'walk4'], ['charge1', 'charge2', 'charge3', 'charge4'], ['flip1', 'flip2', 'flip3']
    for k in ('D', 'E'):
        D = DESIGNS[k]
        gif(f'pequeno_{k}_andar.gif', [frame(D, n) for n in WALK], 120, 8)
        gif(f'pequeno_{k}_cargar.gif', [frame(D, n) for n in CHARGE], 70, 8)
        gif(f'pequeno_{k}_patas_arriba.gif', [frame(D, n) for n in FLIP], 100, 8)
    B = lambda n: frame(A, n, True)
    gif('jefe_andar.gif', [B(n) for n in WALK], 160, 10)
    gif('jefe_cargar.gif', [B(n) for n in CHARGE], 80, 10)
    gif('jefe_lanzar.gif', [B('walk1'), B('toss1'), B('toss1'), B('toss2'), B('toss2'), B('walk1')], [300, 150, 150, 120, 300, 300], 10)
    gif('jefe_salto_y_golpe.gif', [B('walk1'), B('fly1'), B('fly2'), B('fly1'), B('fly2'), B('slam'), B('slam'), B('walk1')],
        [300, 70, 70, 70, 70, 140, 260, 300], 10)
    gif('jefe_patas_arriba.gif', [B(n) for n in FLIP], 110, 10)
    st = [shockwave().crop((i * 24, 0, i * 24 + 24, 12)) for i in range(4)]
    gif('ataque_onda.gif', st, 90, 10)
    gif('ataque_polvo.gif', [dust().crop((i * 16, 0, i * 16 + 16, 16)) for i in range(4)], 90, 10)
    # escena animada: el gigante carga contra la pared, caen cascotes, salta y aterriza con la onda
    scene_gif()


def scene_gif():
    A = DESIGNS[MIX]
    bg0, gy = jungle_bg(960, 540, temple=True); deco(bg0, gy, temple=True)
    wall = up(stone_block(), 4)
    for yy in range(gy - 64 * 6, gy, 64): bg0.alpha_composite(wall, (900, yy))
    pl = player()
    frames, durs = [], []
    k = 9
    def shot(bx, by, fname, extra=(), d=80, flip=False):
        c = bg0.copy()
        c.alpha_composite(pl, (110, gy - pl.height))
        im = up(frame(A, fname, True), k)
        if flip: im = im.transpose(Image.FLIP_LEFT_RIGHT)
        c.alpha_composite(im, (int(bx), int(by - im.height + 9)))
        for im2, xy in extra: c.alpha_composite(im2, (int(xy[0]), int(xy[1])))
        frames.append(c.convert('RGB').convert('P', palette=Image.ADAPTIVE)); durs.append(d)
    x = 330                                                        # (se para con el cuerno contra la pared, en x≈700)
    for i in range(10):                                            # carga hacia la pared
        x += 37; shot(x, gy, ('charge1', 'charge2', 'charge3', 'charge4')[i % 4], (( up(dust().crop((16, 0, 32, 16)), 4), (x - 30, gy - 60)),) if i % 3 == 0 else ())
    deb = up(debris(), 4)
    for i in range(8):                                             # choque: caen cascotes
        ex = [(deb.crop((j * 32, 0, j * 32 + 32, 32)), (640 + j * 70, 40 + i * 50 + j * 24)) for j in range(3)]
        shot(x, gy, ('walk1', 'walk2', 'walk3', 'walk4')[i % 4] if i >= 4 else 'walk1', ex, 90)
    for i in range(6):                                             # se da la vuelta y salta (alas)
        shot(x - i * 30, gy - i * 40, ('fly1', 'fly2')[i % 2], (), 70, flip=True)
    for i in range(5):
        shot(x - 180 - i * 30, gy - 240 + i * 48, ('fly1', 'fly2')[i % 2], (), 70, flip=True)
    sw = shockwave()
    for i in range(4):                                             # aterriza: la onda sale hacia el jugador
        w_ = up(sw.crop((i * 24, 0, i * 24 + 24, 12)), 6)
        shot(x - 330, gy, 'slam', ((w_, (x - 330 - 60 - i * 70, gy - w_.height)),), 110, flip=True)
    shot(x - 330, gy, 'walk1', (), 500, flip=True)
    frames[0].save(os.path.join(OUT, 'escena_jefe.gif'), save_all=True, append_images=frames[1:], duration=durs, loop=0)


# Retocadas A MANO por el usuario (las patas, 2026-10-28; docs/art/generators.md): --apply NUNCA las reescribe. Para
# cambiarlas, pasar antes sus retoques al generador (la salida del generador está en FlappyMonster_originals/…-orig.png)
KEEP = {'assets/images/enemies/beetle/beetle-Sheet.png', 'assets/images/bosses/giantbeetle/body-Sheet.png'}
CHOSEN = 'D'                                                # (el usuario eligió el D "Bronce castaño", 2026-10-28)


def anim_set(aid, scale, sheets, anims):
    """Conjunto de animación (assets/anim/<aid>.json) con los cuadros de cada hoja: [(ruta, ancho, alto, n)]"""
    import json
    frames = []
    for rel, w, h, n in sheets:
        frames += [{"h": h, "image": rel, "w": w, "x": i * w, "y": 0} for i in range(n)]
    data = {"id": aid, "scale": scale, "origin": [0.5, 1], "fallback": "idle", "frames": frames, "anims": anims}
    path = os.path.join(ROOT, 'assets', 'anim', aid + '.json')
    with open(path, 'w') as f:
        f.write(json.dumps(data, indent=2) + '\n')
    print('  ', os.path.relpath(path, ROOT))


def squashed():
    """APLASTADO (pisado y muerto; 0.5.79, el usuario: "solo desaparecen"): sale del cuadro de andar de la hoja
    RETOCADA por el usuario (se lee, no se toca): el caparazón aplastado — sus filas, una sí y otra no — pegado al suelo y
    las patas abiertas a los lados"""
    src = Image.open(os.path.join(ROOT, 'assets/images/enemies/beetle/beetle-Sheet.png')).convert('RGBA').crop((0, 0, W, H))
    sp = src.load()
    rows = [y for y in range(H) if any(sp[x, y][3] > 0 for x in range(W))]
    body = [y for y in rows if y <= 14]                       # (las patas: de la 15 a la 18)
    keep = body[::2][-5:] if len(body) > 5 else body
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0)); p = img.load()
    base = 18 - len(keep) + 1
    for i, y in enumerate(keep):
        for x in range(W):
            if sp[x, y][3] > 0: p[x, base + i] = sp[x, y]
    leg = sp[3, 16] if sp[3, 16][3] > 0 else (46, 26, 12, 255)
    for x in (0, 1, 2): p[x, 18] = leg                         # (las patas, abiertas a los dos lados)
    for x in (17, 18, 19): p[x, 18] = leg
    return img


def apply():
    """Escribe en assets/ el diseño elegido: hojas del pequeño y del gigante, los ataques y sus animaciones"""
    D = DESIGNS[CHOSEN]
    E = 'assets/images/enemies/beetle/'; G = 'assets/images/bosses/giantbeetle/'
    for d in (E, G): os.makedirs(os.path.join(ROOT, d), exist_ok=True)
    # (el pequeño, en AZUL METÁLICO — RECOLORS[SMALL_PAL] —: su hoja retocada por el usuario se recolorea tono a tono, una
    # vez; el original se guarda fuera del repo, en FlappyMonster_originals)
    sp = os.path.join(ROOT, E + 'beetle-Sheet.png')
    if os.path.exists(sp):
        src = Image.open(sp).convert('RGBA')
        if any('%02x%02x%02x' % p[:3] in SRC_TONES for p in src.getdata() if p[3]):
            sys.path.insert(0, os.path.join(ROOT, 'tools/art/lib'))
            import originals
            print('   original guardado en', originals.keep(sp)[0])
            recolor(src, RECOLORS[SMALL_PAL]).save(sp); print('  ', E + 'beetle-Sheet.png (recoloreada: azul metálico)')
    out = {E + 'beetle-Sheet.png': sheet(D, SMALL), G + 'body-Sheet.png': sheet(D, BOSS, True), G + 'block.png': stone_block(),
           E + 'dead.png': squashed(), E + 'fly-Sheet.png': recolor(sheet(D, ['fly1', 'fly2']), RECOLORS[SMALL_PAL]),
           G + 'debris-Sheet.png': debris(), G + 'wave-Sheet.png': shockwave(), G + 'dust-Sheet.png': dust()}
    for rel, im in out.items():
        if rel in KEEP and os.path.exists(os.path.join(ROOT, rel)):
            print('  ', rel, '(RETOCADA POR EL USUARIO: no se toca)'); continue
        im.save(os.path.join(ROOT, rel)); print('  ', rel)
    a = lambda fr, fps, loop=True: {"fps": fps, "frames": fr, "loop": loop}
    small = {"idle": a([1], 8), "walk": a([1, 2, 3, 4], 8), "charge": a([5, 6, 7, 8], 14), "flip": a([9, 10, 11], 10),
             "dead": a([9], 8, False)}
    # (el pequeño: + aplastado y las alas de la variante voladora — los súbditos del jefe —; 0.5.79)
    anim_set('enemies/beetle', 4, [(E + 'beetle-Sheet.png', W, H, len(SMALL)), (E + 'dead.png', W, H, 1),
                                   (E + 'fly-Sheet.png', W, H, 2)],
             dict(small, dead=a([12], 8, False), fly=a([13, 14], 14)))
    boss = dict(small, toss=a([12, 13], 6, False), fly=a([14, 15], 16), slam=a([16], 8, False), hurt=a([10], 8),
                block=a([17], 8), debris=a([18, 19, 20], 8), wave=a([21, 22, 23, 24], 12, False), dust=a([25, 26, 27, 28], 12, False))
    anim_set('bosses/giantbeetle', 12, [(G + 'body-Sheet.png', W, H, len(BOSS)), (G + 'block.png', 16, 16, 1),
                                        (G + 'debris-Sheet.png', 8, 8, 3), (G + 'wave-Sheet.png', 24, 12, 4),
                                        (G + 'dust-Sheet.png', 16, 16, 4)], boss)


# ══ PALETAS NUEVAS DEL PEQUEÑO (0.5.86, el usuario: "se camufla bastante bien en la jungla") ════════════════════════
# Misma forma y patas (las de la hoja RETOCADA por el usuario: se leen y se cambian de color tono a tono), colores que
# destacan sobre el verde y el marrón de la jungla. El jefe se queda como está.
#   python3 tools/art/enemies/make_beetle.py --recolor          → vista previa (FlappyMonster_pruebas/escarabajo/recolor/)
SRC_TONES = {   # tono del diseño D → papel
    'e9f7a8': 'shine', '9cb24a': 'light', '8a5228': 'mid', '5e3018': 'shade', '2e1608': 'outline',
    '8fcf4e': 'pron1', '4f9a3a': 'pron2', '2f6a32': 'pron3', '7a4220': 'horn', '24100a': 'hornO', '6e3e1c': 'leg',
    '120c08': 'eye',
}
SMALL_PAL = '1'                                             # (el elegido por el usuario, 2026-10-28: azul metálico)
RECOLORS = {
    '1': dict(name='Azul metálico', shine='d8f4ff', light='5ec2f0', mid='2f74c8', shade='22489a', outline='121f4e',
              pron1='9fe4ff', pron2='3a8fd8', pron3='24569e', horn='3f4a7a', hornO='11142e', leg='262d55', eye='ffffff'),
    '2': dict(name='Rojo y negro', shine='ffd8c8', light='ff6a4a', mid='d42a2a', shade='8a1420', outline='3a0812',
              pron1='6a6a7a', pron2='3e3e4c', pron3='24242e', horn='34343e', hornO='121218', leg='24242e', eye='ffe9a0'),
    '3': dict(name='Dorado', shine='fff6c0', light='ffd84a', mid='d49a20', shade='8e5a10', outline='3e2406',
              pron1='ffe680', pron2='e0a830', pron3='9a6614', horn='5a3410', hornO='24120a', leg='4a2c10', eye='120c08'),
    '4': dict(name='Violeta iridiscente', shine='f0d8ff', light='c27af0', mid='8a3ec8', shade='5a2290', outline='2a0e48',
              pron1='8af0dc', pron2='2fb0a0', pron3='1e6e6a', horn='3a2050', hornO='160a22', leg='2a1a3a', eye='ffffff'),
}


def recolor(img, pal):
    out = img.copy(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            role = SRC_TONES.get('%02x%02x%02x' % (r, g, b))
            if a and role and role in pal: px[x, y] = hx('#' + pal[role])
    return out


def recolor_preview():
    from PIL import ImageDraw
    E = os.path.join(ROOT, 'assets/images/enemies/beetle/')
    srcs = [Image.open(E + f).convert('RGBA') for f in ('beetle-Sheet.png', 'dead.png', 'fly-Sheet.png')]
    bg = Image.open('/home/mtvemo/FlappyMonster_pruebas/selva/fondo/superficie_day.png').convert('RGBA').crop((0, 300, 1280, 720))
    rows = [('Actual (castaño y verde)', None)] + [(p['name'], p) for p in RECOLORS.values()]
    out = Image.new('RGBA', (1280, len(rows) * 140 + 20), (30, 34, 40, 255)); d = ImageDraw.Draw(out)
    for i, (name, pal) in enumerate(rows):
        y0 = 20 + i * 140
        out.alpha_composite(bg.crop((0, 140, 1280, 260)), (0, y0))
        imgs = [s if pal is None else recolor(s, pal) for s in srcs]
        x = 20
        for k in (0, 4, 8):                                         # andar, embestir, patas arriba
            f = imgs[0].crop((k * W, 0, k * W + W, H)).resize((W * 4, H * 4), Image.NEAREST)
            out.alpha_composite(f, (x, y0 + 120 - H * 4)); x += W * 4 + 20
        out.alpha_composite(imgs[1].resize((W * 4, H * 4), Image.NEAREST), (x, y0 + 120 - H * 4)); x += W * 4 + 20
        out.alpha_composite(imgs[2].crop((0, 0, W, H)).resize((W * 4, H * 4), Image.NEAREST), (x, y0 + 60 - H * 4)); x += W * 4 + 40
        d.rectangle((x - 6, y0 + 4, x + 230, y0 + 24), fill=(0, 0, 0, 160)); d.text((x, y0 + 8), name, fill=(255, 255, 255))
    os.makedirs(os.path.join(OUT, 'recolor'), exist_ok=True)
    out.save(os.path.join(OUT, 'recolor', 'vista_previa.png'))
    print('  ', os.path.join(OUT, 'recolor', 'vista_previa.png'))


if __name__ == '__main__':
    import sys
    os.makedirs(OUT, exist_ok=True)
    if '--recolor' in sys.argv:
        recolor_preview(); sys.exit(0)
    if '--apply' in sys.argv:
        apply(); sys.exit(0)
    for k, D in DESIGNS.items():
        up(sheet(D, SMALL), 1).save(os.path.join(OUT, f'hoja_pequeno_{k}.png'))
    for k in ('D', 'E'): sheet(DESIGNS[k], BOSS, True).save(os.path.join(OUT, f'hoja_gigante_{k}.png'))
    preview(); mockups(); gifs()
    print('  vistas previas en', OUT)
