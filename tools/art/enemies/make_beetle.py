#!/usr/bin/env python3
# tools/art/enemies/make_beetle.py — el ESCARABAJO RINOCERONTE (enemigo exclusivo de la jungla, isla futura) y el
# ESCARABAJO RINOCERONTE GIGANTE, su jefe (docs/bosses/new-bosses-plan.md § 5). PROTOTIPO: solo vistas previas; nada
# entra en assets/ hasta que el usuario elija (--apply).
#
# Hoja: cuadros de 22x20 mirando a la DERECHA (el cuerno pide sitio delante y las alas detrás). Estilo de la casa
# (docs/art/style-rules.md): contorno = el tono más oscuro del PROPIO color, luz arriba a la izquierda, sombra abajo a
# la derecha, 3-4 tonos, 1 px de margen; el brillo de caparazón (los escarabajos relucen) es una raya clara curva.
# El gigante es LA MISMA hoja a escala 12 (regla de los "Mega"), con las marcas doradas de la Furia del Espejo (el
# fragmento que lo hizo crecer) y el ojo encendido; cuadros suyos además de los del pequeño: lanzar con el cuerno,
# élitros abiertos y alas zumbando (salto), aterrizaje aplastado.
#
#   python tools/art/enemies/make_beetle.py   → FlappyMonster_pruebas/escarabajo/ (vista_previa.png, mockups, GIFs)
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
}
GOLD, GOLD_S, GLOW = hx('#ffd84a'), hx('#c4901c'), hx('#ff6a2a')

# ── las piezas de cada cuadro (de pie, mirando a la derecha; las poses las mueven) ─────────────────────────────────
# élitros: una cúpula alta; protórax: un bloque redondo delante, con un espolón; cabeza baja con el ojo; el CUERNO
# grande sale de la cabeza, sube hacia delante y se curva hacia atrás (2 px de grueso en la base)
ELYTRA = (7.0, 9.2 + OY, 6.2, 5.4)
PRONOTUM = (12.8, 9.0 + OY, 2.9, 2.9)
HEAD = (15.7, 10.6 + OY, 1.9, 1.6)
HORNS = {
    'up': [(16, 13), (17, 13), (17, 12), (18, 12), (17, 11), (18, 11), (18, 10), (18, 9), (17, 8), (18, 8), (17, 7), (16, 6)],
    'fwd': [(16, 14), (17, 14), (17, 13), (18, 13), (19, 13), (19, 12), (20, 12), (20, 11)],
    'toss': [(16, 13), (16, 12), (17, 12), (16, 11), (17, 11), (17, 10), (17, 9), (17, 8), (16, 7), (16, 6), (15, 5)],
}
SPUR = [(14, 10), (15, 9)]
LEG_X = (4, 8, 11)
# poses: dy (sube/baja), shear (inclina: el frente baja si > 0), cuerno, patas (desplazamiento del pie de cada pata),
# y extras: 'flip' (patas arriba), 'wings' (1/2: élitro levantado y alas arriba/abajo), 'squash'
FRAMES = {
    'walk1': dict(dy=0, shear=0.0, horn='up', legs=(-1, 1, -1)),
    'walk2': dict(dy=-1, shear=0.0, horn='up', legs=(1, -1, 1)),
    'charge1': dict(dy=0, shear=0.16, horn='fwd', legs=(-2, -2, -1)),
    'charge2': dict(dy=-1, shear=0.16, horn='fwd', legs=(-1, -1, -2)),
    'flip1': dict(flip=True, horn='fwd', legs=(-1, 1, -1)),
    'flip2': dict(flip=True, horn='fwd', legs=(1, -1, 1)),
    'toss1': dict(dy=0, shear=0.2, horn='fwd', legs=(-1, -1, -1)),
    'toss2': dict(dy=-1, shear=-0.18, horn='toss', legs=(1, 1, 0)),
    'fly1': dict(dy=-3, shear=0.0, horn='up', legs=(0, 0, 0), wings=1, dangle=True),
    'fly2': dict(dy=-3, shear=0.0, horn='up', legs=(0, 0, 0), wings=2, dangle=True),
    'slam': dict(dy=1, shear=0.0, horn='up', legs=(-2, 0, 2), squash=True),
}
W = 22
SMALL = ['walk1', 'walk2', 'charge1', 'charge2', 'flip1', 'flip2']
BOSS = SMALL + ['toss1', 'toss2', 'fly1', 'fly2', 'slam']


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
    C = {k: hx(v) for k, v in D.items() if k != 'name'}
    flip, sq, wings = F.get('flip'), F.get('squash'), F.get('wings', 0)
    part = {}                                       # (x, y) -> (pieza, color)
    ex, ey, erx, ery = ELYTRA
    if sq: ery, erx, ey = ery * 0.8, erx * 1.08, ey + 1.0
    floor = 11.5 + OY + (0.6 if sq else 0)

    def put(pts, kind, pal):
        for (x, y), (nx, ny) in pts.items():
            lt = -(0.55 * nx + 0.85 * ny)
            part[(x, y)] = (kind, pal[0] if lt > 0.5 else (pal[1] if lt > -0.05 else pal[2]))

    shell = (C['light'], C['mid'], C['shade'])
    if wings:                                       # el abdomen (lo que queda debajo del élitro levantado)
        put({p: n for p, n in ell(ex + 0.5, ey + 1.6, erx - 0.8, ery - 1.8).items() if p[1] + 0.5 <= floor}, 'body', (C['mid'], C['shade'], C['shade']))
    else:
        put({p: n for p, n in ell(ex, ey, erx, ery).items() if p[1] + 0.5 <= floor}, 'elytra', shell)
    put({p: n for p, n in ell(*PRONOTUM).items() if p[1] + 0.5 <= floor + 0.4}, 'pron', shell)
    put(ell(*HEAD), 'head', (C['mid'], C['shade'], C['outline']))
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
        shift = 14 + OY - max(y for (x, y) in part)
        part = {(x, y + shift): v for (x, y), v in part.items()}
    # patas (detrás de todo): de pie, del vientre al suelo; patas arriba, hacia el cielo y moviéndose
    legs = []
    for lx, d in zip(LEG_X, F['legs']):
        if flip:
            base = min(y for (x, y) in part if abs(x - lx) <= 1) - 1
            pts = [(lx, base), (lx + (1 if d > 0 else -1), base - 1), (lx + d, base - 2), (lx + d, base - 3)]
        elif F.get('dangle'):
            base = int(floor) + dy + 1
            pts = [(lx, base), (lx - 1, base + 1), (lx - 1, base + 2)]
        else:
            base = int(floor) + dy + int(round(sh * (lx - 9))) + 1
            foot = 14 + OY
            pts = [(lx, base)] + [(lx + (d if y >= foot - 1 else (d > 0) - (d < 0) if y > base else 0), y) for y in range(base + 1, foot + 1)]
            pts.append((lx + d + (1 if d >= 0 else -1), foot))
        legs += pts
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0)); px = img.load()
    inside = lambda p: 0 < p[0] < W - 1 and 0 < p[1] < H - 1
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
    # el ojo
    eye = [p for p in solid if part[p][0] == 'head' and p not in out]
    if eye:
        e = max(eye, key=lambda p: (p[0] * 2 - abs(p[1] - (sum(q[1] for q in eye) / len(eye)))))
        px[e] = GLOW if boss else C['eye']
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
    for k, D in DESIGNS.items():
        rows.append((f'Pequeño {k} "{D["name"]}" (x8): andar 1-2 · cargar 1-2 · patas arriba 1-2', up(sheet(D, SMALL), 8)))
    rows.append(('Gigante A (x8; en el juego x12): + lanzar 1-2 · alas 1-2 · aterrizaje', up(sheet(DESIGNS['A'], BOSS, True), 8)))
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
    for i, (k, D) in enumerate(DESIGNS.items()):
        im = up(frame(D, ('walk1', 'charge1', 'walk2')[i]), 4)
        x = 440 + i * 240
        bg.alpha_composite(im, (x, gy - im.height + 4))
        text(d, (x, gy - im.height - 16), f'{k} {D["name"]}')
    blk = up(stone_block(), 4); bg.alpha_composite(blk, (1100, gy - 64))
    text(d, (16, 16), 'Maqueta: nivel de la jungla — Escarabajo Rinoceronte (x4), jugador (x6), bloque del templo (x4)')
    bg.save(os.path.join(OUT, 'maqueta_nivel.png'))
    # 2) el templo: el gigante (x12), el jugador, la onda del suelo y bloques
    bg, gy = jungle_bg(1600, 900, temple=True); deco(bg, gy, temple=True)
    d = ImageDraw.Draw(bg)
    boss = up(frame(DESIGNS['A'], 'walk1', True), 12)
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
    A = DESIGNS['A']
    for k, D in DESIGNS.items():
        gif(f'pequeno_{k}_andar.gif', [frame(D, 'walk1'), frame(D, 'walk2')], 180, 8)
    gif('pequeno_A_cargar.gif', [frame(A, 'charge1'), frame(A, 'charge2')], 90, 8)
    gif('pequeno_A_patas_arriba.gif', [frame(A, 'flip1'), frame(A, 'flip2')], 130, 8)
    B = lambda n: frame(A, n, True)
    gif('jefe_andar.gif', [B('walk1'), B('walk2')], 220, 10)
    gif('jefe_cargar.gif', [B('charge1'), B('charge2')], 90, 10)
    gif('jefe_lanzar.gif', [B('walk1'), B('toss1'), B('toss1'), B('toss2'), B('toss2'), B('walk1')], [300, 150, 150, 120, 300, 300], 10)
    gif('jefe_salto_y_golpe.gif', [B('walk1'), B('fly1'), B('fly2'), B('fly1'), B('fly2'), B('slam'), B('slam'), B('walk1')],
        [300, 70, 70, 70, 70, 140, 260, 300], 10)
    gif('jefe_patas_arriba.gif', [B('flip1'), B('flip2')], 130, 10)
    st = [shockwave().crop((i * 24, 0, i * 24 + 24, 12)) for i in range(4)]
    gif('ataque_onda.gif', st, 90, 10)
    gif('ataque_polvo.gif', [dust().crop((i * 16, 0, i * 16 + 16, 16)) for i in range(4)], 90, 10)
    # escena animada: el gigante carga contra la pared, caen cascotes, salta y aterriza con la onda
    scene_gif()


def scene_gif():
    A = DESIGNS['A']
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
        x += 37; shot(x, gy, ('charge1', 'charge2')[i % 2], (( up(dust().crop((16, 0, 32, 16)), 4), (x - 30, gy - 60)),) if i % 3 == 0 else ())
    deb = up(debris(), 4)
    for i in range(8):                                             # choque: caen cascotes
        ex = [(deb.crop((j * 32, 0, j * 32 + 32, 32)), (640 + j * 70, 40 + i * 50 + j * 24)) for j in range(3)]
        shot(x, gy, 'walk1' if i < 6 else 'walk2', ex, 90)
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


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for k, D in DESIGNS.items():
        up(sheet(D, SMALL), 1).save(os.path.join(OUT, f'hoja_pequeno_{k}.png'))
    sheet(DESIGNS['A'], BOSS, True).save(os.path.join(OUT, 'hoja_gigante_A.png'))
    preview(); mockups(); gifs()
    print('  vistas previas en', OUT)
