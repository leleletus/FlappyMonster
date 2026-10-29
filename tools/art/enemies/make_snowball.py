#!/usr/bin/env python3
# tools/art/enemies/make_snowball.py — la BOLA DE NIEVE (`snowball`, enemigo de datos: assets/enemies/snowball.json), la
# hermana pequeña de la Gran Bola de Nieve (jefe `snowboss`). Patrulla rodando; si ve a un jugador se agacha, se LANZA
# rodando hacia él y lo EMPUJA con fuerza de lado (comportamiento `ram`, src/world/entities/behaviors/ram.lua).
#
# El jefe es un diseño del USUARIO (assets/images/bosses/snowboss/, 16x16): este script SOLO LO LEE, nunca lo escribe.
# De él sale el lenguaje de la pequeña: su paleta exacta (contorno azul noche, blanco, dos azules de sombra abajo a la
# derecha, un brillo arriba a la izquierda), ojos de bloque oscuro, la boca en raya, la cara que GIRA con la bola al
# rodar (como roll_happy / roll_angry) y los mismos gestos: contenta rodando, enfadada al lanzarse.
#
# Dos diseños con los MISMOS cuadros (el conjunto de animación vale para los dos):
#   A «Hermanita» — la bola del jefe en pequeño (12 px): rueda con la cara girando; al cargar se aplasta, al lanzarse
#     pone cara de enfado, tras el empujón se ríe. Es la que crece hasta ser el jefe en la intro de la historia.
#   B «Carnero» — más atrevida: un huevo de nieve más estrecho y alto con dos cuernos de hielo enroscados (el guiño a
#     la cabra que embiste); no rueda: va a saltitos y embiste con los cuernos por delante.
# Simple y plano (memoria del usuario: pocos colores, sin motas): 4 tonos de la bola + 2 del hielo de B.
#
#   python3 tools/art/enemies/make_snowball.py              → SOLO vistas previas en
#                                                            FlappyMonster_pruebas/bola_de_nieve/ (vista_previa.png:
#                                                            las dos hojas; maqueta.png: junto al jugador y al jefe a
#                                                            escala de juego; maqueta.gif: animada)
#   python3 tools/art/enemies/make_snowball.py --apply A|B [--force]  → escribe ese diseño (si ya hay hoja, solo con
#                                                            --force: puede estar retocada a mano) en
#                                                            assets/images/enemies/snowball/snowball-Sheet.png y el
#                                                            conjunto assets/anim/enemies/snowball.json (este solo si
#                                                            no existe: luego se retoca en el editor de animaciones)
# Aplicado (2026-10-29, sin el usuario delante): A. Cambiar a B = `--apply B --force` (mismos cuadros, nada más).
import os, sys, math, json
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
IMG = os.path.join(ROOT, 'assets', 'images')
BOSS = os.path.join(IMG, 'bosses', 'snowboss')                      # (del usuario: solo se lee)
SHEET_REL = 'assets/images/enemies/snowball/snowball-Sheet.png'
ANIM_REL = 'assets/anim/enemies/snowball.json'
OUT = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'bola_de_nieve')

FW, FH = 14, 12                                                    # cuadro (los pies abajo del todo)

# ── Paleta: la del jefe, medida en su body-Sheet.png (si no está, la misma escrita a mano) ──
def boss_palette():
    pal = {'o': (30, 30, 42, 255), 'b': (255, 255, 255, 255), 'c': (242, 244, 248, 255),
           'd': (226, 232, 242, 255), 'e': (196, 204, 224, 255)}
    try:
        im = Image.open(os.path.join(BOSS, 'body-Sheet.png')).convert('RGBA')
        seen = {}
        for y in range(16):
            for x in range(16):
                p = im.getpixel((x, y))
                if p[3]:
                    seen[p] = seen.get(p, 0) + 1
        cols = sorted(seen, key=lambda p: sum(p[:3]))
        if len(cols) == 5:                                         # oscuro → claro: contorno, e, d, c, b
            pal = {'o': cols[0], 'e': cols[1], 'd': cols[2], 'c': cols[3], 'b': cols[4]}
    except Exception:
        pass
    return pal

PAL = boss_palette()
ICE = {'i': (120, 196, 236, 255), 'j': (196, 236, 252, 255), 'k': (40, 84, 140, 255)}   # cuernos de B: medio, luz, contorno


# ── Dibujo por píxeles ──────────────────────────────────────────────────────────────────────────────────────────────
def blank():
    return [['.'] * FW for _ in range(FH)]


def ball(g, cx, cy, rx, ry):
    """Elipse rellena con contorno y sombra (abajo a la derecha) y brillo (arriba a la izquierda), como el jefe"""
    inside = set()
    for y in range(FH):
        for x in range(FW):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if u * u + v * v <= 1.0:
                inside.add((x, y))
    for (x, y) in inside:
        edge = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            g[y][x] = 'o'
            continue
        u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        rim = any((x + dx, y + dy) not in inside for dx in (-2, -1, 0, 1, 2) for dy in (-1, 0, 1))   # (junto al borde)
        s = 0.45 * u + 0.9 * v
        if s > 0.62 and rim:
            g[y][x] = 'e'
        elif s > 0.38 and rim and u > -0.2:
            g[y][x] = 'd'
        elif -0.7 * u - 0.7 * v > 0.5 and rim:
            g[y][x] = 'b'
        else:
            g[y][x] = 'c'
    return inside


def rot(cx, cy, feats, ang, inside):
    """Rasgos de la cara (desplazamientos continuos desde el centro) girados `ang` rad, en píxeles dentro de la bola"""
    out = []
    ca, sa = math.cos(ang), math.sin(ang)
    for (dx, dy) in feats:
        x, y = dx * ca - dy * sa, dx * sa + dy * ca
        px, py = int(math.floor(cx + x)), int(math.floor(cy + y))
        if (px, py) in inside:
            out.append((px, py))
    return out


# Caras (desplazamientos desde el centro de la cara, en píxeles; el centro de un píxel es +0.5)
def eyes_dot(sp=3):                       # ojos de bloque 1x2 (los del jefe, en pequeño)
    return [(-sp, -2.0), (-sp, -1.0), (sp - 1, -2.0), (sp - 1, -1.0)]


def eyes_angry(sp=3):                     # ◣ ◢ : el ceño baja hacia el centro (roll_angry del jefe)
    return [(-sp, -2.0), (-sp, -1.0), (-sp + 1, -1.0), (sp - 1, -2.0), (sp - 1, -1.0), (sp - 2, -1.0)]


def eyes_closed(sp=3):                    # parpadeo: rayita
    return [(-sp, -1.0), (-sp + 1, -1.0), (sp - 1, -1.0), (sp - 2, -1.0)]


def eyes_laugh(sp=3):                     # ^ ^
    return [(-sp - 1, -1.0), (-sp, -2.0), (-sp + 1, -1.0), (sp - 2, -1.0), (sp - 1, -2.0), (sp, -1.0)]


def eyes_dizzy(sp=3):                     # > <
    return [(-sp - 1, -3.0), (-sp, -2.0), (-sp - 1, -1.0), (sp, -3.0), (sp - 1, -2.0), (sp, -1.0)]


def mouth_line(w=4, y=2.0):
    return [(-w / 2 + i, y) for i in range(w)]


def mouth_smile(y=2.0):
    return [(-2.0, y - 1), (-1.0, y), (0.0, y), (1.0, y - 1)]


def mouth_wide(y=2.0):                    # sonrisa ancha (la raya del jefe, curvada)
    return [(-3.0, y - 1), (-2.0, y), (-1.0, y), (0.0, y), (1.0, y), (2.0, y - 1)]


def mouth_open(y=2.0):                    # D: risa
    return [(-2.0, y), (-1.0, y), (0.0, y), (1.0, y), (-1.0, y + 1), (0.0, y + 1)]


def mouth_grit(y=2.0):                    # dientes apretados (enfado)
    return [(-2.0, y), (-1.0, y), (0.0, y), (1.0, y)]


def mouth_wavy(y=2.0):
    return [(-2.0, y), (-1.0, y - 1), (0.0, y), (1.0, y - 1)]



# ── Diseño A «Hermanita»: la bola del jefe en pequeño ──────────────────────────────────────────────────────────────
def frame_A(kind, k=0):
    g = blank()
    cx = FW / 2
    if kind in ('roll', 'angry', 'idle', 'blink', 'laugh', 'dizzy'):
        rx, ry = 6.0, 6.0
        if kind == 'laugh' and k == 1:
            rx, ry = 6.5, 5.5
        cy = FH - ry
        ins = ball(g, cx, cy, rx, ry)
        fy = cy + 0.0
        ang = (k * math.pi / 4) if kind in ('roll', 'angry') else 0.0
        if kind == 'roll':
            feats = eyes_dot() + mouth_smile()
        elif kind == 'angry':
            feats = eyes_angry() + mouth_grit()
        elif kind == 'idle':
            feats = eyes_dot() + mouth_smile()
        elif kind == 'blink':
            feats = eyes_closed() + mouth_smile()
        elif kind == 'laugh':
            feats = eyes_laugh() + mouth_open(1.5)
        else:
            feats = eyes_dizzy() + mouth_wavy()
        for p in rot(cx, fy, feats, ang, ins):
            g[p[1]][p[0]] = 'o'
    elif kind == 'windup':                                   # aplastada y temblando: va a salir disparada
        rx, ry = (7.0, 5.0) if k == 0 else (6.8, 4.6)
        cy = FH - ry
        ins = ball(g, cx + (0.0 if k == 0 else 0.0), cy, rx, ry)
        for p in rot(cx, cy + 0.6, eyes_angry() + mouth_grit(1.4), 0.0, ins):
            g[p[1]][p[0]] = 'o'
    elif kind == 'dead':
        if k == 0:                                           # chafada
            ins = ball(g, cx, FH - 3.2, 7.0, 3.2)
            for p in [(4, 9), (5, 9), (8, 9), (9, 9)]:
                if p in ins:
                    g[p[1]][p[0]] = 'o'
        else:                                                # montón de nieve (sin cara) que se deshace
            pile(g, k)
    return g


def pile(g, k):
    """Montón de nieve: unas bolas bajas que se juntan; k=1 entero, k=2 más bajo y con terrones sueltos"""
    if k == 1:
        lumps = [(4.0, FH - 2.0, 3.2, 2.2), (9.5, FH - 2.0, 3.6, 2.6), (7.0, FH - 2.6, 3.4, 2.8)]
    else:
        lumps = [(5.0, FH - 1.4, 3.0, 1.6), (9.0, FH - 1.4, 3.0, 1.8)]
    inside = set()
    for (cx, cy, rx, ry) in lumps:
        for y in range(FH):
            for x in range(FW):
                u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if u * u + v * v <= 1.0 and y < FH:
                    inside.add((x, y))
    for (x, y) in inside:
        edge = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, -1)))
        g[y][x] = 'o' if (edge or y == FH - 1) else ('d' if y >= FH - 2 else 'c')
    if k == 2:                                               # terrones que saltan
        for (x, y) in [(1, FH - 6), (12, FH - 7), (3, FH - 9)]:
            g[y][x] = 'c'
            if x + 1 < FW:
                g[y][x + 1] = 'd'


# ── Diseño B «Carnero»: huevo de nieve estrecho con cuernos de hielo, a saltitos ────────────────────────────────────
def horns(g, top, lean=0):
    """Dos cuernos de hielo enroscados hacia fuera a los lados de la cabeza (lean = adelantados al embestir)"""
    left = [(4, top - 1, 'k'), (3, top - 1, 'k'), (2, top, 'k'), (1, top + 1, 'k'), (1, top + 2, 'k'), (2, top + 3, 'k'),
            (3, top, 'i'), (2, top + 1, 'i'), (2, top + 2, 'j')]
    for (x, y, ch) in left:
        for xx in (x, FW - 1 - x):
            xx += lean
            if 0 <= xx < FW and 0 <= y < FH and g[y][xx] == '.':
                g[y][xx] = ch


def frame_B(kind, k=0):
    g = blank()
    cx = FW / 2
    lean = 0
    rx, ry, lift = 4.6, 5.6, 0.0
    feats = eyes_dot(2) + mouth_line(2, 2.0)
    fdx = 0.0
    if kind == 'roll':                                       # saltitos: aplasta, estira, arriba, cae
        rx, ry, lift = [(4.6, 5.6, 0), (5.2, 5.0, 0), (4.3, 5.9, 0), (4.4, 5.7, 1), (4.4, 5.7, 2),
                        (4.4, 5.7, 1), (4.5, 5.6, 0), (5.0, 5.2, 0)][k]
    elif kind == 'angry':                                    # embiste: inclinado, cuernos delante
        rx, ry, lift = 4.8, 5.4, (1 if k % 4 in (1, 2) else 0)
        feats = eyes_angry(3) + mouth_grit(2.0)
    elif kind == 'idle':
        pass
    elif kind == 'blink':
        feats = eyes_closed(2) + mouth_line(2, 2.0)
    elif kind == 'laugh':
        rx, ry = (4.8, 5.4) if k == 0 else (5.1, 5.0)
        feats = eyes_laugh(3) + mouth_open(1.6)
    elif kind == 'dizzy':
        feats = eyes_dizzy(3) + mouth_wavy(2.0)
    elif kind == 'windup':                                   # se encoge y agacha los cuernos
        rx, ry = (5.4, 4.8) if k == 0 else (5.6, 4.5)
        feats = eyes_angry(3) + mouth_grit(1.6)
    elif kind == 'dead':
        if k == 0:
            ins = ball(g, cx, FH - 3.0, 6.4, 3.0)
            for p in [(5, 9), (8, 9)]:
                g[p[1]][p[0]] = 'o'
            for (x, y, ch) in [(1, 9, 'k'), (2, 9, 'i'), (12, 9, 'k'), (11, 9, 'i')]:   # cuernos caídos a los lados
                if g[y][x] == '.':
                    g[y][x] = ch
        else:
            pile(g, k)
            if k == 1:
                for (x, y, ch) in [(0, FH - 1, 'k'), (1, FH - 1, 'i'), (13, FH - 1, 'k')]:
                    if g[y][x] == '.':
                        g[y][x] = ch
        return g
    cy = FH - ry - lift
    ins = ball(g, cx, cy, rx, ry)
    horns(g, int(math.floor(cy - ry + 1.5)), lean)
    for p in rot(cx + fdx, cy + 0.2, feats, 0.0, ins):
        g[p[1]][p[0]] = 'o'
    return g


# ── Hoja y conjunto de animación (mismo orden en A y B) ────────────────────────────────────────────────────────────
FRAMES = ([('roll', k) for k in range(8)] + [('angry', k) for k in range(8)] +
          [('idle', 0), ('blink', 0), ('windup', 0), ('windup', 1), ('laugh', 0), ('laugh', 1), ('dizzy', 0),
           ('dead', 0), ('dead', 1), ('dead', 2)])
ANIMS = {
    'walk':   {'frames': list(range(1, 9)), 'fps': 10, 'loop': True},
    'charge': {'frames': list(range(9, 17)), 'fps': 20, 'loop': True},
    'idle':   {'frames': [17, 18], 'fps': 2, 'loop': True, 'durations': [1.8, 0.14]},
    'windup': {'frames': [19, 20], 'fps': 14, 'loop': True},
    'recoil': {'frames': [21, 22], 'fps': 8, 'loop': True},
    'dazed':  {'frames': [23], 'fps': 4, 'loop': True},
    'hurt':   {'frames': [23], 'fps': 4, 'loop': True},
    'dead':   {'frames': [24, 25, 26], 'fps': 4, 'loop': False, 'durations': [0.18, 0.8, 0.42]},
}


def to_img(g, pal):
    im = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    for y in range(FH):
        for x in range(FW):
            ch = g[y][x]
            if ch != '.':
                im.putpixel((x, y), pal.get(ch) or ICE.get(ch))
    return im


def sheet(design):
    fn = frame_A if design == 'A' else frame_B
    im = Image.new('RGBA', (FW * len(FRAMES), FH), (0, 0, 0, 0))
    for i, (kind, k) in enumerate(FRAMES):
        im.alpha_composite(to_img(fn(kind, k), PAL), (i * FW, 0))
    return im


def anim_json():
    frames = [{'image': SHEET_REL, 'x': i * FW, 'y': 0, 'w': FW, 'h': FH} for i in range(len(FRAMES))]
    return {'id': 'enemies/snowball', 'scale': 4, 'origin': [0.5, 1], 'fallback': 'idle',
            'frames': frames, 'anims': ANIMS}


# ── Vistas previas ─────────────────────────────────────────────────────────────────────────────────────────────────
def frame_of(sh, n):
    return sh.crop(((n - 1) * FW, 0, n * FW, FH))


def bg_scene(w, h, floor_y):
    im = Image.new('RGBA', (w, h), (150, 186, 222, 255))
    try:
        t = Image.open(os.path.join(IMG, 'world', 'tiles', 'snow.png')).convert('RGBA')
        for x in range(0, w, 64):
            for y in range(floor_y, h, 64):
                im.alpha_composite(t, (x, y))
    except Exception:
        ImageDraw.Draw(im).rectangle((0, floor_y, w, h), fill=(236, 242, 250, 255))
    return im


def paste_scaled(dst, src, s, x, y_bottom, flip=False):
    b = src.resize((src.width * s, src.height * s), Image.NEAREST)
    if flip:
        b = b.transpose(Image.FLIP_LEFT_RIGHT)
    dst.alpha_composite(b, (int(x - b.width / 2), int(y_bottom - b.height)))


def previews():
    os.makedirs(OUT, exist_ok=True)
    sheets = {d: sheet(d) for d in 'AB'}
    for d, sh in sheets.items():
        sh.save(os.path.join(OUT, 'hoja_%s.png' % d))
    # 1) las dos hojas grandes, con nombre de cada animación
    S = 8
    names = {1: 'walk', 9: 'charge', 17: 'idle', 19: 'windup', 21: 'recoil', 23: 'dazed', 24: 'dead'}
    W = FW * S * len(FRAMES) + 20
    vp = Image.new('RGBA', (W, 2 * (FH * S + 40) + 10), (52, 70, 104, 255))
    dr = ImageDraw.Draw(vp)
    for row, d in enumerate('AB'):
        y0 = 10 + row * (FH * S + 40)
        dr.text((10, y0), {'A': 'A  Hermanita (aplicada)', 'B': 'B  Carnero'}[d], fill=(255, 255, 255, 255))
        big = sheets[d].resize((sheets[d].width * S, FH * S), Image.NEAREST)
        vp.alpha_composite(big, (10, y0 + 14))
        for n, nm in names.items():
            dr.text((10 + (n - 1) * FW * S, y0 + 16 + FH * S), nm, fill=(255, 230, 140, 255))
    vp.save(os.path.join(OUT, 'vista_previa.png'))
    # 2) maqueta a escala de juego: jugador (×6), Bola de Nieve A y B (×4) y el jefe (fase 1, ×10)
    boss = Image.open(os.path.join(BOSS, 'body-Sheet.png')).convert('RGBA').crop((0, 0, 16, 16))
    player = Image.open(os.path.join(IMG, 'player', 'monstrito1.png')).convert('RGBA')
    w, h, fy = 1100, 300, 236
    m = bg_scene(w, h, fy)
    paste_scaled(m, player, 6, 90, fy)
    for i, (d, n) in enumerate([('A', 1), ('A', 9), ('A', 19), ('A', 21), ('B', 1), ('B', 9), ('B', 19), ('B', 21)]):
        paste_scaled(m, frame_of(sheets[d], n), 4, 190 + i * 70, fy, flip=(n == 9 and False))
    paste_scaled(m, boss, 10, 900, fy + 10)          # (el cuadro del jefe deja 1 px vacío abajo)
    ImageDraw.Draw(m).text((10, 10), 'jugador · A: rodar, lanzarse, cargar, reirse · B: igual · el jefe (fase 1)',
                           fill=(20, 30, 60, 255))
    m.save(os.path.join(OUT, 'maqueta.png'))
    # 3) GIF: rueda, ve, carga, se lanza, empuja y se ríe; y muere aplastada (A arriba, B abajo)
    seq = [1, 2, 3, 4, 5, 6, 7, 8] * 2 + [19, 20] * 4 + list(range(9, 17)) * 2 + [21, 22] * 4 + [17] * 6 + [24, 25, 25, 25, 26, 26]
    frames = []
    for i, n in enumerate(seq):
        im = bg_scene(360, 230, 100)
        dd = Image.new('RGBA', (360, 230), (0, 0, 0, 0))
        im.alpha_composite(bg_scene(360, 230, 214).crop((0, 115, 360, 230)), (0, 115))
        x = 60 + (i * 6 if n <= 8 or 9 <= n <= 16 else 0)
        for row, d in enumerate('AB'):
            paste_scaled(im, frame_of(sheets[d], n), 4, (60 + (i % 40) * 6) % 340 + 10, 100 + row * 114)
        frames.append(im.convert('P', palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(OUT, 'maqueta.gif'), save_all=True, append_images=frames[1:], duration=70, loop=0)
    print('vistas previas en', OUT)


def apply(design, force=False):
    sh = sheet(design)
    p = os.path.join(ROOT, SHEET_REL)
    if os.path.exists(p) and not force:
        print(SHEET_REL, 'ya existe: no se pisa (puede estar retocada a mano); --force para reescribirla')
        return
    os.makedirs(os.path.dirname(p), exist_ok=True)
    sh.save(p)
    print('escrito', SHEET_REL, '(diseño %s)' % design)
    a = os.path.join(ROOT, ANIM_REL)
    if not os.path.exists(a):
        with open(a, 'w') as f:
            json.dump(anim_json(), f, indent=2, sort_keys=True)
            f.write('\n')
        print('escrito', ANIM_REL)
    else:
        print(ANIM_REL, 'ya existe: no se pisa (se retoca en el editor de animaciones)')


if __name__ == '__main__':
    previews()
    if '--apply' in sys.argv:
        i = sys.argv.index('--apply')
        d = sys.argv[i + 1].upper() if i + 1 < len(sys.argv) else 'A'
        if d not in ('A', 'B'):
            sys.exit('--apply A|B')
        apply(d, '--force' in sys.argv)
