#!/usr/bin/env python3
# LA JUNGLA (isla nueva: jungla tropical espesa con templos de piedra comidos por la vegetación; la del Escarabajo
# Rinoceronte). PROPUESTA de las variantes de isla 'jungla' de lo que ya cambia por isla (src/world/level/Isles.lua):
#   FAMILIAS:  gummy_jungle (rana de árbol: verde, ojos saltones, motas, pies naranjas) ·
#              crabby_jungle + crabbytramp_jungle (cangrejo de Halloween: caparazón morado con manchas amarillas, patas
#              naranjas y pinzas magenta; el trampolín usa el arte del mismo cangrejo, como los demás)
#   isleArt:   el Saltarín 'jungla' (rana flecha turquesa con una flor) · la Caja (madera oscura atada con lianas) · la
#              Balanza (losa de templo con musgo, cuerda de liana y polea de piedra tallada) · el Soplón (bruma húmeda con
#              una hoja y pétalos; + su fila en wind-Sheet.png) · la Ventisca (rachas con hojas y pétalos) · el Géiser
#              (manantial turquesa con hojitas, en un brocal de piedra con musgo) · la Semilla (vaina de cacao → liana con hojas de
#              costilla de Adán y una flor magenta arriba) · la comida (racimo de plátanos)
# MISMOS tamaños, cuadros y orden que las variantes de las otras islas (el juego las carga por nombre). Estilo
# (docs/art/style-rules.md): contorno = el tono más oscuro del color de cada parte, luz arriba a la izquierda, se
# conserva cada píxel de la forma del Gummy / del Saltarín de siempre.
#   python3 tools/art/enemies/make_jungle_skins.py          → SOLO vistas previas en FlappyMonster_pruebas/jungla/variantes/
#                                                             (vista_previa.png, maqueta.gif y archivos/ con cada PNG)
#   python3 tools/art/enemies/make_jungle_skins.py --apply  → escribe en assets/images/ (NO lo uses sin el visto bueno del
#                                                             usuario; no pisa nada que ya exista salvo con --force, y
#                                                             enemies/gust/wind-Sheet.png se AMPLÍA con la fila de la jungla)
import os, sys, json, math, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'world'))
sys.path.insert(0, os.path.join(HERE, '..', 'lib'))
from PIL import Image, ImageDraw, ImageFont
import make_enemy_designs as D
import make_crab_species as CS
import make_hopper_sprites as HS
import make_gust_sprites as GS
import make_scale_box as SB
import make_seed_plants as SP
import make_wind_geyser as WG
import make_food_sprites as FS

ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
IMG = os.path.join(ROOT, 'assets', 'images')
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'jungla', 'variantes')
ISLE = 'jungla'
ISLES6 = ['pradera', 'costa', 'fortaleza', 'nieve', 'cueva', 'volcan']
rgb = D.rgb

# ── PALETA DE LA JUNGLA ──────────────────────────────────────────────────────────────────────────────────────────
LEAF = ['0f2a1a', '1d4a2a', '2f7a3a', '5fb04a', 'a6d860']
TRUNK = ['2a1a10', '4a2e1a', '6e4426', '966236']
STONE = ['1e2620', '3e4a3c', '5f6e58', '8a9a7c']
MOSS = ['4f7a26', '86b03c']
MUD = ['3a2416', '5a3a22', '7e5634']
MAG, ORA, YEL, TEAL = 'd0407a', 'f08a24', 'f4d03a', '2fb0a0'
BG_JUNGLE = '3c5a40'


def overlay(grid, rows, x0=0, y0=0):
    """Pinta `rows` (mapas de papeles; ' ' = no toca) encima de una rejilla"""
    g = [r[:] for r in grid]
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ' ': g[y0 + y][x0 + x] = c
    return g


# ══ GUMMY DE LA JUNGLA: rana de árbol ═════════════════════════════════════════════════════════════════════════════
# El MISMO Gummy (cada píxel: cuerpo, cara, piernas) en verde hoja, con dos OJOS SALTONES de rana encima de la cabeza
# (filas 0-1, vacías en el Gummy), motas oscuras en el lomo y en los costados (nunca en la cara) y las patitas naranjas.
GUMMY_PAL = dict(o=LEAF[0], h=LEAF[4], b=LEAF[3], s=LEAF[2], m=LEAF[1], F='b05a14', f=ORA)
FROG_BUMPS = ["   ooo   ooo    ",
              "  ohhbo ohbso   "]
GUMMY_SPOTS = [(6, 3), (8, 3), (2, 8), (12, 7), (12, 10)]


def frog_feet(g):
    """Las piernas del Gummy (filas 13-15, contorno) en naranja: la pierna en tono oscuro, el pie en claro"""
    g = [r[:] for r in g]
    for y in range(13, 16):
        for x in range(16):
            if g[y][x] == 'o': g[y][x] = 'f' if y == 15 or g[y + 1][x] == '.' and y == 14 else 'F'
    return g


def gummy_jungle():
    out = {}
    for f in ('gummy.png', 'gummy1.png', 'gummy2.png'):
        g = overlay(frog_feet(D.base('enemies/gummy/' + f)), FROG_BUMPS)
        for x, y in GUMMY_SPOTS:
            if g[y][x] in 'bhs': g[y][x] = 'm'
        out['enemies/gummy_jungle/' + f] = D.paint(g, GUMMY_PAL)
    # aplastado: el de siempre en verde, con los dos ojos saltones aplastados encima
    g = D.base('enemies/gummy/dead.png')
    g = overlay(g, ["   oo     oo    "], 0, 11)
    g[12][4] = 'm'; g[12][11] = 'm'
    out['enemies/gummy_jungle/dead.png'] = D.paint(g, GUMMY_PAL)
    return out


# ══ CRABBY DE LA JUNGLA: cangrejo de Halloween (cangrejo de tierra de la jungla) ════════════════════════════════════
# Otra especie como los de río / lava / cueva (make_crab_species.py: 18 px de ancho, se hunde fila a fila): caparazón
# morado con dos manchas amarillas detrás de los ojos, patas NARANJAS y pinzas MAGENTA (las del juego, 5x5).
JUNGLE_CRAB_PAL = dict(o='2a0c26', h='a85090', b='6e2a66', s='4a1a46', e='12060f', Y=YEL, y='c89a1e', l=ORA, L='b05a14')
JUNGLE_CLAW_PAL = dict(o='4a1030', h='f07aa8', b=MAG, s='8e2456')
# patas: dos a cada lado, LARGAS y muy abiertas (el cangrejo de Halloween es zancudo; la silueta y los tres gestos de
# andar son los del Crabby de río), naranjas: la parte de arriba con su sombra al lado (más gruesa) y el pie oscuro.
# (1ª prueba: tres patas rectas hacia abajo por lado, muy juntas: parecían un fleco de medusa)
_RIVER_LEGS = CS.SPECIES['crabby_river']['legs']


def _legs(rows):
    out = []
    for y, r in enumerate(rows):
        out.append(''.join('.' if c == '.' else ('L' if (c in 'mn' or (c == 'o' and y == 3)) else 'l') for c in r))
    return out


JUNGLE_CRAB = dict(
    pal=JUNGLE_CRAB_PAL, claw_pal=JUNGLE_CLAW_PAL,
    shell=[".....oooooooo.....",
           "....ohYbbbbYso....",
           "...ohbebbbbebso...",
           "...obbbbbbbbbso...",
           "...oossssssssoo..."],
    legs=[_legs(r) for r in _RIVER_LEGS],
    look=2,
    dead=["......oooooooooo......",
          "....oohYbbbbbbYsoo....",
          "l.oobebbbbbbbbbbesoo.l",
          ".loossssssssssssssool.",
          "L..oooooooooooooooo..L"])


def crabby_jungle():
    files = CS.build('crabby_jungle', JUNGLE_CRAB)
    out = {'enemies/crabby_jungle/' + k: v for k, v in files.items()}
    out['enemies/crabby_jungle/spike.png'] = Image.open(os.path.join(IMG, 'enemies', 'crabby', 'spike.png')).convert('RGBA')
    return out


# ══ EL SALTARÍN 'jungla': rana flecha turquesa con una flor en la cabeza ════════════════════════════════════════
HOP_PAL = D.P('9ff0e0', TEAL, '1f7a70', o='0e3a36', w='d8fff4', e='0e3a36', x=LEAF[0])
D.HEAD['flor'] = [(0, 0, LEAF[1]), (0, -1, LEAF[2]), (-1, -2, MAG), (1, -2, MAG), (0, -2, YEL), (0, -3, MAG),
                  (-1, -3, '8e2456'), (1, -1, LEAF[3])]


def hopper_jungle():
    return {'enemies/hopper/jungla-Sheet.png': HS.frames(HOP_PAL, 'flor')}


# ══ EL SOPLÓN 'jungla': bruma húmeda de la jungla (verde muy pálido) con una hoja y pétalos ═══════════════════════
GS.ISLES[ISLE] = dict(o='3e6a4c', s='96c49c', b='d2ecc8', h='ffffff', e=LEAF[0], x=LEAF[3], y=MAG, bg=BG_JUNGLE)
GS.LIPS[ISLE] = '6a9a78'
GS.CHEEK[ISLE] = 'f0a0b8'
_deco = GS.deco


def _deco_jungle(g, isle, frame, big):
    if isle != ISLE: return _deco(g, isle, frame, big)
    top = next(y for y in range(GS.H) if any(c != '.' for c in g[y]))
    # una hojita que le brota de la coronilla (dos tonos) y dos pétalos sueltos que flotan alrededor
    GS.put(g, 8, top - 1, 'x'); GS.put(g, 9, top - 2, 'x'); GS.put(g, 10, top - 2, 'x'); GS.put(g, 9, top - 1, 'o')
    GS.put(g, 2, top + 3 + frame % 2, 'y'); GS.put(g, 14, top + 6 - frame % 2, 'y')


GS.deco = _deco_jungle


def gust_wind_row():
    """La fila de la jungla de enemies/gust/wind-Sheet.png (3 cuadros 8x8): la racha con una hoja y un pétalo"""
    pal = GS.ISLES[ISLE]
    out = Image.new('RGBA', (24, 8))
    for f in range(3):
        im = Image.new('RGBA', (8, 8))
        for row, x0, ln in ((2, f, 5), (5, (f + 3) % 4, 4)):
            for dx in range(ln):
                c = rgb(pal['h'] if dx < ln - 1 else pal['b'])
                im.putpixel(((x0 + dx) % 8, row), c[:3] + (200,))
        im.putpixel(((f * 2 + 6) % 8, (f * 3 + 1) % 7), rgb(pal['x']))
        im.putpixel(((f * 5 + 1) % 8, (f * 3 + 4) % 7), rgb(pal['y']))
        out.paste(im, (f * 8, 0), im)
    return out


def gust_jungle():
    sheet = GS.sheet(ISLE)
    old = Image.open(os.path.join(IMG, 'enemies', 'gust', 'wind-Sheet.png')).convert('RGBA')
    assert old.size in ((24, 48), (24, 56)), old.size      # (6 islas: la de la jungla es la 7ª fila, Isles.IDS)
    old = old.crop((0, 0, 24, 48))                         # (si ya tenía la 7ª fila, se rehace)
    wind = Image.new('RGBA', (24, 56))
    wind.paste(old, (0, 0)); wind.paste(gust_wind_row(), (0, 48))
    return {'enemies/gust/jungla-Sheet.png': sheet, 'enemies/gust/wind-Sheet.png': wind}


# ══ LA CAJA 'jungla': madera oscura de la jungla atada con lianas (cruz de liana con un nudo y una hoja) ══════════
BOX_PAL = dict(o=TRUNK[0], s=TRUNK[1], b=TRUNK[2], h=TRUNK[3], x=TRUNK[1], r=LEAF[3], R=LEAF[2], q=LEAF[1],
               L=LEAF[4], y=MOSS[1], Y=MOSS[0])


def _bits(whole, n, cut):
    """Los 4 cuartos (la caja se rompe), un poco desmigados, como en make_scale_box.py"""
    w = whole.width // 2
    bits = Image.new('RGBA', (w * 4, w))
    for i, (sx, sy) in enumerate(((0, 0), (w, 0), (0, w), (w, w))):
        q = whole.crop((sx, sy, sx + w, sy + w))
        px = q.load()
        for a, b in cut(i): px[a, b] = (0, 0, 0, 0)
        bits.paste(q, (i * w, 0))
    return bits


def box_jungle():
    g = SB.G(16, 16)
    g.block(0, 0, 16, 16)
    for x in (5, 10): g.rect(x, 1, 1, 14, 'x')                             # tablas verticales
    for x, y in ((3, 4), (8, 11), (12, 6)): g.put(x, y, 'x')               # vetas
    for y in range(1, 15):                                                   # la liana: cruza en diagonal, dos tonos
        x = 1 + (y * 13) // 14
        g.put(x, y, 'r'); g.put(x + 1, y, 'R')
    for x in range(1, 15): g.put(x, 9, 'r' if x % 3 else 'R'); g.put(x, 10, 'R')     # y una vuelta horizontal
    g.rect(9, 8, 3, 3, 'q'); g.put(9, 8, 'r')                              # el nudo
    g.put(12, 7, 'L'); g.put(13, 7, 'r'); g.put(13, 6, 'L'); g.put(14, 6, 'R')      # una hoja que le sale del nudo
    for x in (1, 2, 3, 13, 14): g.put(x, 14, 'y')                          # musgo al pie
    g.put(2, 13, 'y'); g.put(14, 13, 'Y')
    whole = g.img(BOX_PAL)
    bits = _bits(whole, 8, lambda i: ((7, 0), (0, 7), (7, 7), (6, 7))[i:i + 2])
    s = SB.G(10, 10)
    s.block(0, 0, 10, 10)
    s.rect(4, 1, 1, 8, 'x')
    for y in range(1, 9): s.put(1 + (y * 7) // 8, y, 'r')
    s.rect(1, 5, 8, 1, 'R'); s.put(5, 4, 'q'); s.put(6, 4, 'L')
    s.put(1, 8, 'y'); s.put(8, 8, 'Y')
    small = s.img(BOX_PAL)
    sbits = _bits(small, 5, lambda i: [(4, 0) if i % 2 else (0, 4)])
    return {'mechanisms/box/jungla.png': whole, 'mechanisms/box/jungla-bits-Sheet.png': bits,
            'mechanisms/box/jungla-small.png': small, 'mechanisms/box/jungla-small-bits-Sheet.png': sbits}


# ══ LA BALANZA 'jungla': losa de templo con musgo · cuerda de LIANA · polea de piedra tallada ═══════════════════
STONE_PAL = dict(o=STONE[0], s=STONE[1], b=STONE[2], h=STONE[3], x=STONE[1], y=MOSS[1], Y=MOSS[0], r=TRUNK[2],
                 R=TRUNK[1], g=YEL, L=LEAF[3], l=LEAF[2])


def scale_jungle():
    # platillo (48x8): losa de piedra con glifos tallados, musgo por encima y la argolla de madera
    p = SB.G(48, 8)
    p.block(0, 2, 48, 6)
    for x in (16, 32): p.rect(x, 3, 1, 4, 'o')                              # juntas entre losas
    for gx in (6, 24, 40):                                                   # glifos: una espiral de templo
        for dx, dy in ((0, 0), (1, 0), (2, 0), (2, 1), (0, 2), (1, 2), (2, 2), (0, 1)): p.put(gx + dx, 3 + dy, 'x')
        p.put(gx + 1, 4, 'h')
    for x in list(range(1, 9)) + list(range(29, 35)) + [44, 45, 46]: p.put(x, 2, 'y')    # musgo encima
    for x in (2, 3, 5, 31, 45): p.put(x, 1, 'y')
    for x in (4, 6, 30, 33): p.put(x, 3, 'Y')
    p.put(3, 0, 'L'); p.put(32, 1, 'Y')
    p.rect(22, 0, 4, 1, 'R'); p.put(22, 1, 'R'); p.put(25, 1, 'R')
    pan = p.img(STONE_PAL)
    # cuerda (4x8, se repite): una LIANA verde que se retuerce, con una hojita
    r = SB.G(4, 8)
    for y in range(8):
        r.put(1, y, 'L' if y % 4 < 2 else 'l'); r.put(2, y, 'l' if y % 4 < 2 else 'L')
    r.put(3, 2, 'L'); r.put(0, 6, 'l')
    rope = r.img(dict(STONE_PAL, L=LEAF[3], l=LEAF[2]))
    # polea (2 cuadros 16x16): rueda de piedra con radios tallados, eje de madera, horquilla de madera; musgo
    out = Image.new('RGBA', (32, 16))
    for f in range(2):
        g = SB.G(16, 16)
        cx = cy = 7.5
        for y in range(16):
            for x in range(16):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= 7.2:
                    g.put(x, y, 'o' if d > 6.2 else ('h' if (x - cx) + (y - cy) < -4 else ('s' if (x - cx) + (y - cy) > 4 else 'b')))
                if 2.2 < d < 3.2: g.put(x, y, 'x')
        if f == 0:
            g.rect(7, 2, 2, 12, 'x'); g.rect(2, 7, 12, 2, 'x')
        else:
            for k in range(-4, 5): g.put(int(cx + k), int(cy + k), 'x'); g.put(int(cx + k), int(cy - k), 'x')
        for x, y in ((3, 12), (4, 13), (2, 11), (12, 13)): g.put(x, y, 'y')   # musgo abajo (no gira: queda igual)
        g.rect(6, 6, 4, 4, 'R'); g.rect(7, 7, 2, 2, 'g')
        g.rect(6, 0, 4, 1, 'R'); g.rect(7, 1, 2, 5, 'r'); g.put(7, 1, 'R')
        out.paste(g.img(STONE_PAL), (f * 16, 0))
    return {'mechanisms/scale/jungla-pan.png': pan, 'mechanisms/scale/jungla-rope.png': rope,
            'mechanisms/scale/jungla-pulley-Sheet.png': out}


# ══ LA VENTISCA 'jungla' (rachas con hojas y pétalos) y EL GÉISER 'jungla' (manantial turquesa con hojitas) ═══════
WG.WIND_CARRY[ISLE] = (LEAF[3], MAG)
WG.BG[ISLE] = BG_JUNGLE
WG.GEY[ISLE] = dict(o=STONE[0], r=STONE[1], R=STONE[3], j='ffffff', J=TEAL, k='145a50', x=MOSS[1], a=235, kind='agua')


def geyser_jungle():
    v = WG.vent(ISLE)
    px = v.load()
    for x, y, c in ((1, 4, MOSS[1]), (2, 4, MOSS[0]), (2, 3, MOSS[1]), (13, 4, MOSS[1]), (14, 4, MOSS[0]),
                    (3, 2, LEAF[3]), (4, 2, LEAF[2]), (12, 2, LEAF[3]), (4, 6, STONE[0]), (11, 6, STONE[0])):
        px[x, y] = rgb(c)
    col = Image.new('RGBA', (48, 16)); cr = Image.new('RGBA', (48, 16))
    for f in range(3):
        cf = WG.column(ISLE, f)
        for x, y in ((6, (f * 5 + 4) % 16), (9, (f * 5 + 12) % 16)):          # hojitas que suben con el agua
            cf.putpixel((x, y), rgb(LEAF[3])); cf.putpixel((x + 1, y), rgb(LEAF[2]))
        col.paste(cf, (f * 16, 0))
        c = WG.crest(ISLE, f)
        c.putpixel((3 + f, 6 - f), rgb(LEAF[3])); c.putpixel((4 + f, 6 - f), rgb(LEAF[2]))   # una hoja que salta
        cr.paste(c, (f * 16, 0))
    return {'mechanisms/geyser/jungla-vent.png': v, 'mechanisms/geyser/jungla-warn-Sheet.png': WG.warning(ISLE),
            'mechanisms/geyser/jungla-column-Sheet.png': col, 'mechanisms/geyser/jungla-crest-Sheet.png': cr,
            'mechanisms/wind/jungla-gust-Sheet.png': WG.gusts(ISLE)}


# ══ LA SEMILLA 'jungla': vaina de cacao → LIANA leñosa con hojas de costilla de Adán y una flor magenta arriba ════
SP.ISLES[ISLE] = dict(o=LEAF[0], O=TRUNK[0], b=TRUNK[2], h=TRUNK[3], s=TRUNK[1], L=LEAF[3], l=LEAF[2], v=LEAF[1],
                      x=YEL, y=ORA, p=MAG, q='8e2456', k=LEAF[4], bg=BG_JUNGLE)


def holes(g, x0, y0, side, ln, w, every=5):
    """Las ranuras de la costilla de Adán: cortes transparentes desde el borde de abajo hacia el nervio"""
    for i in range(3, ln - 2, every):
        x = x0 + side * i
        for k in range(w - 1, w // 2, -1):
            if g.g[y0 + k][x] in 'Ll': g.put(x, y0 + k, '.')
        g.put(x, y0 + w // 2, 'o') if g.g[y0 + w // 2][x] in 'Ll' else None


def monstera(g, x0, y0, size, side):
    """Hoja de CORAZÓN (la de la habichuela) con sus ranuras si es grande"""
    SP.heart(g, x0, y0, size, side)
    if size >= 5:
        for i in range(2, size - 1, 3):
            x = x0 + side * i
            w = max(1, int(round(size * 0.55 * math.sin(math.pi * (i + 1) / (size + 1)) + (1 if i < size * 0.4 else 0))))
            if w >= 3: g.put(x, y0 + w - w // 2 - 1, '.')


def jungle_plant(h):
    rnd = SP.random.Random(sum(ord(ch) * (i + 1) for i, ch in enumerate(ISLE)) * 10 + h)
    WPX = SP.WP
    H = 16 * h + 18
    g = SP.G(WPX, H)
    cx, floor, top = WPX // 2, H - 1, 18
    key = (ISLE, h)
    SP.REGIONS[key] = []

    def stem_x(y): return cx + 2.0 * math.sin((floor - y) / 10.0 + 0.4)
    # el TALLO: dos lianas leñosas que se trenzan (marrón, contorno marrón oscuro)
    for y in range(top, H):
        x = stem_x(y)
        for ph in (0, math.pi):
            sx = int(round(x + 1.6 * math.sin((floor - y) / 4.5 + ph)))
            g.put(sx - 2, y, 'O'); g.rect(sx - 1, y, 3, 1, 'b'); g.put(sx - 1, y, 'h'); g.put(sx + 1, y, 's'); g.put(sx + 2, y, 'O')
    # raíces al pie
    for dx, dy in ((-4, 0), (-5, 0), (-3, -1), (4, 0), (5, 0), (3, -1), (-6, 0), (6, 0)): g.put(cx + dx, floor + dy, 'O')
    # hojas pequeñas a alturas irregulares y algún zarcillo / flor de liana
    y, side = floor - 9, 1
    while y > top + 10:
        x = int(round(stem_x(y)))
        size = rnd.choice((4, 5, 5, 6, 7))
        monstera(g, x + side * 3, y, size, side)
        r = rnd.random()
        if r < 0.3: SP.tendril(g, x - side * 3, y + 4, -side)
        elif r < 0.5: g.put(x - side * 3, y + 3, 'p'); g.put(x - side * 3, y + 4, 'q')       # (florecilla de liana)
        side = -side
        y -= rnd.randint(7, 12)
    # HOJAS GRANDES (las plataformas): a 2 casillas (derecha) y a 4 (izquierda)
    for cells, sd in ((2, 1), (4, -1)):
        if cells >= h: continue
        py = floor - 16 * cells + 1
        x = int(round(stem_x(py + 4)))
        x0, ln = x + sd * 2, 26
        SP.REGIONS[key].append((min(x0, x0 + sd * ln), max(x0, x0 + sd * ln), py - 4, py + 3))
        SP.bigleaf_bean(g, x0, py, sd)
        for i in (6, 11, 16, 21):                                            # ranuras de costilla de Adán, desde abajo
            xx = x0 + sd * i
            for yy in range(py + 3, py + 7):
                if g.g[yy][xx] in 'Ll': g.put(xx, yy, '.')
            if g.g[py + 2][xx] in 'Llv': g.put(xx, py + 3, 'o') if g.g[py + 3][xx] == '.' else None
    # la COPA: dos hojas grandes de corazón y una flor de heliconia/hibisco magenta en medio
    SP.REGIONS[key].append((cx - 14, cx + 14, 0, top + 10))
    monstera(g, cx - 3, top + 4, 12, -1); monstera(g, cx + 3, top + 4, 12, 1)
    SP.flower(g, cx, top + 1, 6)
    for xx, yy in ((cx - 10, top + 9), (cx + 11, top + 10)):                # lianas que cuelgan
        for k in range(5): g.put(xx, yy + k, 'v' if k % 2 else 'l')
    return g.img(SP.ISLES[ISLE])


def jungle_seed():
    g = SP.G(12, 12)                                                         # vaina de cacao: naranja, con costillas
    for y in range(12):
        for x in range(12):
            d = ((x - 6) / 3.6) ** 2 + ((y - 6.5) / 4.6) ** 2
            if d <= 1: g.put(x, y, 'o' if d > 0.62 else ('y'))
    for y in (4, 5, 6, 7, 8): g.put(6, y, 'Q')
    for y in (5, 6, 7): g.put(4, y, 'Q'); g.put(8, y, 'Q')
    g.put(4, 3, 'X'); g.put(5, 3, 'X'); g.put(3, 4, 'X')
    g.put(9, 8, 'Q'); g.put(8, 9, 'Q')
    g.put(6, 1, 'v'); g.put(7, 0, 'l'); g.put(8, 0, 'L')                    # el rabito con una hojita
    return g.img(dict(SP.ISLES[ISLE], o='5a2a0a', y=ORA, Q='b05a14', X=YEL))


def jungle_crown():
    g = SP.G(48, 16)
    SP.leaf(g, 24, 8, 23, 5, ISLE, -1); SP.leaf(g, 23, 8, 23, 5, ISLE, 1)
    SP.leaf(g, 22, 4, 10, 3, ISLE, -1, False); SP.leaf(g, 25, 4, 10, 3, ISLE, 1, False)
    for x in (8, 14, 33, 39): g.put(x, 11, '.'); g.put(x, 12, '.')
    g.rect(21, 6, 6, 10, 'b')
    SP.flower(g, 24, 4, 4)
    return g.img(SP.ISLES[ISLE])


def seed_jungle():
    out = {'items/seed/jungla-seed.png': jungle_seed(), 'items/seed/jungla-sprout-Sheet.png': SP.sprout(ISLE),
           'items/seed/jungla-base.png': SP.base(ISLE), 'items/seed/jungla-crown.png': jungle_crown()}
    st = Image.new('RGBA', (32, 16)); st.paste(SP.stem_tile(ISLE, 0), (0, 0)); st.paste(SP.stem_tile(ISLE, 1), (16, 0))
    out['items/seed/jungla-stem-Sheet.png'] = st
    bl = SP.big_leaf(ISLE)
    px = bl.load()
    for x in (8, 15, 22):                                                    # (ranuras también en la pieza suelta)
        for y in (6, 7): px[x, y] = (0, 0, 0, 0)
    out['items/seed/jungla-bigleaf.png'] = bl
    for hh in (4, 5, 6):
        img = jungle_plant(hh)
        out['items/seed/jungla-plant%d.png' % hh] = img
        out['items/seed/jungla-plant%d.json' % hh] = {'w': img.width, 'h': img.height, 'plats': SP.plats(img, SP.REGIONS[(ISLE, hh)])}
    return out


# ══ LA COMIDA 'jungla': un racimo de plátanos (16x16, contorno de la manzana, luz arriba a la izquierda) ═════════
# (una "mano" de tres plátanos que crecen hacia arriba desde el tallo, con las puntas abiertas; la 1ª prueba, un racimo
# colgando, parecía una calabaza)
BANANA = (dict(o=FS.O, Y='fff0a0', y=YEL, d='c89a1e', G='86b03c', g='4f7a26', b='6e4426'), [
    "................",
    "..oo.........oo.",
    ".oYo...oo...oyo.",
    ".oYyo.oYyo.oYyo.",
    "..oYyooYyooYyo..",
    "..oYyyoYyoYyyo..",
    "..oYyyoYyoYydo..",
    "...oYyoYyoYydo..",
    "...oYydYydYdo...",
    "....oyddyddo....",
    ".....oyyddo.....",
    "......oggo......",
    "......oGgo......",
    "......obbo......",
    ".......oo.......",
    "................"])


def food_jungle():
    return {'items/food_jungla.png': FS.img(*BANANA)}


# ══ TODO JUNTO, y lo que ya existe para compararlo ══════════════════════════════════════════════════════════════
def build_all():
    out = {}
    for fn in (gummy_jungle, crabby_jungle, hopper_jungle, gust_jungle, box_jungle, scale_jungle, geyser_jungle,
               seed_jungle, food_jungle):
        out.update(fn())
    return out


def load(rel):
    return Image.open(os.path.join(IMG, rel)).convert('RGBA')


def verify(new):
    """Mismos tamaños que la variante de cada isla (o, para lo de una carpeta por tipo, que la del Crabby de río)"""
    problems = []
    for rel, im in new.items():
        if not isinstance(im, Image.Image): continue
        d, f = os.path.split(rel)
        if f.startswith('jungla'):
            refs = [os.path.join(d, isle + f[5:]) for isle in ISLES6]
        elif rel == 'items/food_jungla.png':
            refs = ['items/food_%s.png' % i for i in ISLES6 if i != 'pradera'] + ['items/apple.png']
        elif rel == 'enemies/gust/wind-Sheet.png':
            continue
        elif d.endswith('gummy_jungle'):
            refs = [os.path.join(x, f) for x in ('enemies/gummy', 'enemies/gummy_ice', 'enemies/gummy_magma', 'enemies/gummy_fortress')]
        else:                                               # crabby_jungle: 18 px de ancho, como río / lava / cueva
            refs = [os.path.join('enemies', x, f) for x in ('crabby_lava', 'crabby_river', 'crabby_cave')
                    if os.path.exists(os.path.join(IMG, 'enemies', x, f))]
        sizes = {load(r).size for r in refs if os.path.exists(os.path.join(IMG, r))}
        if f.startswith('jungla-plant'):                     # (las plantas: 64 de ancho en todas menos la fortaleza)
            sizes = {s for s in sizes if s[0] == 64}
        ok = im.size in sizes if sizes else None
        if ok is False: problems.append('%s %s ≠ %s' % (rel, im.size, sorted(sizes)))
        yield rel, im.size, sorted(sizes), ok


# ── vista previa ──────────────────────────────────────────────────────────────────────────────────────────────
FONT = ImageFont.load_default(size=13)
FONTB = ImageFont.load_default(size=20)


def big(im, s): return im.resize((im.width * s, im.height * s), Image.NEAREST)


def group(label, ims, s, new=False, gap=6):
    ims = [big(i, s) for i in ims]
    w = max(sum(i.width for i in ims) + gap * (len(ims) - 1), 90)
    h = max(i.height for i in ims)
    cv = Image.new('RGBA', (w + 16, h + 34), rgb('5a7c5a' if new else '46664a'))
    x = 8
    for i in ims:
        cv.paste(i, (x, 8 + h - i.height), i); x += i.width + gap
    d = ImageDraw.Draw(cv)
    if new:
        d.rectangle((0, 0, cv.width - 1, cv.height - 1), outline=rgb(YEL), width=3)
    d.text((8, h + 14), label, fill=rgb('fff4a0' if new else 'e8f0e0'), font=FONT)
    return cv


def section(title, groups, maxw=2200):
    rows, row, w = [], [], 0
    for gimg in groups:
        if row and w + gimg.width + 10 > maxw: rows.append(row); row, w = [], 0
        row.append(gimg); w += gimg.width + 10
    rows.append(row)
    W = max(sum(g.width + 10 for g in r) for r in rows) + 10
    H = 34 + sum(max(g.height for g in r) + 10 for r in rows)
    cv = Image.new('RGBA', (W, H), rgb(BG_JUNGLE))
    ImageDraw.Draw(cv).text((10, 6), title, fill=rgb('ffffff'), font=FONTB)
    y = 34
    for r in rows:
        x = 10
        for gimg in r: cv.paste(gimg, (x, y)); x += gimg.width + 10
        y += max(g.height for g in r) + 10
    return cv


def frames_of(sheet, fw):
    return [sheet.crop((k * fw, 0, (k + 1) * fw, sheet.height)) for k in range(sheet.width // fw)]


def with_claws(body, claw_sheet, cw, k=0, cx=5.4, cy=-1.6):
    """Un Crabby con sus pinzas sueltas (aprox. como el juego: x desde el centro, y desde los pies)"""
    if claw_sheet is None: return body
    c = claw_sheet.crop((k * cw, 0, (k + 1) * cw, claw_sheet.height))
    pad = cw + 2
    cv = Image.new('RGBA', (body.width + 2 * pad, body.height + 2))
    cv.paste(body, (pad, 2), body)
    mid = pad + body.width / 2
    y = int(2 + body.height + cy - c.height + 1)
    cv.paste(c, (int(mid - cx - c.width + 1.5), y), c)
    m = c.transpose(Image.FLIP_LEFT_RIGHT)
    cv.paste(m, (int(mid + cx - 1.5), y), m)
    return cv


CRAB_CLAW = {'crabby_river': (5, 4.4, -1.6), 'crabby_lava': (5, 5.4, -1.6), 'crabby_ice': (7, 5.6, -0.6), 'crabby_jungle': (5, 5.4, -1.6)}


def preview(new):
    S = 4
    nw = lambda rel: new[rel]
    secs = []
    # GUMMY
    gs = []
    for d in ('gummy', 'gummy_cave', 'gummy_fortress', 'gummy_ice', 'gummy_magma'):
        gs.append(group(d, [load('enemies/%s/%s' % (d, f)) for f in ('gummy.png', 'gummy1.png', 'gummy2.png', 'dead.png')], S))
    gs.append(group('gummy_jungle (NUEVO)', [nw('enemies/gummy_jungle/' + f) for f in ('gummy.png', 'gummy1.png', 'gummy2.png', 'dead.png')], S, True))
    secs.append(section('GUMMY  (x4)  - rana de arbol: ojos saltones, motas, pies naranjas', gs))
    # CRABBY
    cs = []
    for d in ('crabby', 'crabby_river', 'crabby_fortress', 'crabby_ice', 'crabby_cave', 'crabby_lava'):
        cl = CRAB_CLAW.get(d)
        sheet = load('enemies/%s/claw_left-Sheet.png' % d) if cl else None
        cs.append(group(d, [with_claws(load('enemies/%s/crab1.png' % d), sheet, *(cl or (5,)))] + [load('enemies/%s/dead.png' % d)], S))
    j = 'enemies/crabby_jungle/'
    jc = nw(j + 'claw_left-Sheet.png')
    cs.append(group('crabby_jungle (NUEVO)', [with_claws(nw(j + 'crab1.png'), jc, 5, 0, 5.4, -1.6), nw(j + 'dead.png')], S, True))
    cs.append(group('crabby_jungle: crab1-3, pinza abierta/cerrada, lookin, meat, sink1-5, hid', [nw(j + 'crab%d.png' % i) for i in (1, 2, 3)]
                    + frames_of(jc, 5) + [nw(j + 'lookin.png'), nw(j + 'meat.png')] + [nw(j + 'sink%d.png' % i) for i in range(1, 6)], S, True))
    cs.append(group('crabbytramp_jungle (trampolin: mismo arte)', [with_claws(nw(j + 'crab1.png'), jc, 5, 1, 5.4, -1.6),
                                                                     load('mechanisms/trampoline/extended.png')], S, True))
    secs.append(section('CRABBY + CRABBY TRAMPOLIN  (x4)  - cangrejo de Halloween: morado, manchas amarillas, patas naranjas, pinzas magenta', cs))
    # SALTARÍN
    hs = [group(i, [load('enemies/hopper/%s-Sheet.png' % i)], S) for i in ISLES6]
    hs.append(group('jungla (NUEVO)', [nw('enemies/hopper/jungla-Sheet.png')], S, True))
    secs.append(section('SALTARIN  (x4)  - rana flecha turquesa con una flor', hs, 2000))
    # SOPLÓN
    us = [group(i, [load('enemies/gust/%s-Sheet.png' % i)], S) for i in ISLES6]
    us.append(group('jungla (NUEVO)', [nw('enemies/gust/jungla-Sheet.png')], S, True))
    us.append(group('wind-Sheet (7 filas: + jungla)', [nw('enemies/gust/wind-Sheet.png')], S, True))
    secs.append(section('SOPLON  (x4)  - bruma humeda con una hoja y petalos', us, 2200))
    # CAJA
    bs = [group(i, [load('mechanisms/box/%s.png' % i), load('mechanisms/box/%s-small.png' % i), load('mechanisms/box/%s-bits-Sheet.png' % i)], S) for i in ISLES6]
    bs.append(group('jungla (NUEVO)', [nw('mechanisms/box/jungla.png'), nw('mechanisms/box/jungla-small.png'), nw('mechanisms/box/jungla-bits-Sheet.png'),
                                      nw('mechanisms/box/jungla-small-bits-Sheet.png')], S, True))
    secs.append(section('CAJA + CAJA PEQUENA  (x4)  - madera oscura atada con lianas', bs))
    # BALANZA
    def mount(pan, rope, pul):
        cv = Image.new('RGBA', (52, 40))
        p0 = pul.crop((0, 0, 16, 16)); cv.paste(p0, (18, 0), p0)
        for y in range(12, 32, 8): cv.paste(rope, (24, y), rope)
        cv.paste(pan, (2, 32), pan)
        return cv
    ss = [group(i, [mount(load('mechanisms/scale/%s-pan.png' % i), load('mechanisms/scale/%s-rope.png' % i),
                          load('mechanisms/scale/%s-pulley-Sheet.png' % i))], S) for i in ISLES6]
    ss.append(group('jungla (NUEVO)', [mount(nw('mechanisms/scale/jungla-pan.png'), nw('mechanisms/scale/jungla-rope.png'),
                                            nw('mechanisms/scale/jungla-pulley-Sheet.png')), nw('mechanisms/scale/jungla-pulley-Sheet.png')], S, True))
    secs.append(section('BALANZA  (x4)  - losa de templo con musgo, cuerda de liana, polea de piedra', ss))
    # GÉISER + VENTISCA
    def gmount(get, isle):
        cv = Image.new('RGBA', (16, 8 + 16 * 2 + 14))
        v = get('mechanisms/geyser/%s-vent.png' % isle); cv.paste(v, (0, cv.height - 8), v)
        col = frames_of(get('mechanisms/geyser/%s-column-Sheet.png' % isle), 16)
        for k in range(2): cv.paste(col[k], (0, cv.height - 8 - 16 * (k + 1)), col[k])
        cr = frames_of(get('mechanisms/geyser/%s-crest-Sheet.png' % isle), 16)[1]; cv.paste(cr, (0, 0), cr)
        return cv
    ys = [group(i, [gmount(load, i), load('mechanisms/geyser/%s-warn-Sheet.png' % i), load('mechanisms/wind/%s-gust-Sheet.png' % i)], S) for i in ISLES6]
    ys.append(group('jungla (NUEVO)', [gmount(nw, ISLE), nw('mechanisms/geyser/jungla-warn-Sheet.png'), nw('mechanisms/wind/jungla-gust-Sheet.png')], S, True))
    secs.append(section('GEISER (respiradero, columna, penacho, aviso) + VENTISCA (rachas)  (x4)', ys, 2200))
    # SEMILLA
    ps = [group(i, [load('items/seed/%s-seed.png' % i), load('items/seed/%s-plant6.png' % i)], 3) for i in ISLES6]
    ps.append(group('jungla (NUEVO)', [nw('items/seed/jungla-seed.png'), nw('items/seed/jungla-sprout-Sheet.png'), nw('items/seed/jungla-plant4.png'),
                                      nw('items/seed/jungla-plant5.png'), nw('items/seed/jungla-plant6.png')], 3, True))
    secs.append(section('SEMILLA  (x3)  - vaina de cacao; liana con hojas de costilla de Adan y flor magenta', ps, 2300))
    # COMIDA
    fs = [group('pradera', [load('items/apple.png')], S)] + [group(i, [load('items/food_%s.png' % i)], S) for i in ISLES6[1:]]
    fs.append(group('jungla (NUEVO)', [nw('items/food_jungla.png')], S, True))
    secs.append(section('COMIDA  (x4)  - racimo de platanos', fs))
    W = max(s.width for s in secs)
    out = Image.new('RGBA', (W, sum(s.height for s in secs) + 8 * len(secs)), rgb('22301f'))
    y = 0
    for s in secs: out.paste(s, (0, y)); y += s.height + 8
    return out, secs


def maqueta(new):
    """GIF: lo animado de la jungla a x4 (andar, saltar, soplar, la polea, el géiser, las rachas)"""
    S = 4
    nw = lambda rel: new[rel]
    gum = [nw('enemies/gummy_jungle/%s' % f) for f in ('gummy.png', 'gummy1.png', 'gummy.png', 'gummy2.png')]
    wings = frames_of(load('enemies/wings/wings-Sheet.png'), 9)
    crab = [nw('enemies/crabby_jungle/crab%d.png' % i) for i in (1, 2, 1, 3)]
    claw = nw('enemies/crabby_jungle/claw_left-Sheet.png')
    hop = frames_of(nw('enemies/hopper/jungla-Sheet.png'), 16)
    gust = frames_of(nw('enemies/gust/jungla-Sheet.png'), 16)
    gwind = frames_of(nw('enemies/gust/wind-Sheet.png').crop((0, 48, 24, 56)), 8)
    pul = frames_of(nw('mechanisms/scale/jungla-pulley-Sheet.png'), 16)
    col = frames_of(nw('mechanisms/geyser/jungla-column-Sheet.png'), 16)
    crest = frames_of(nw('mechanisms/geyser/jungla-crest-Sheet.png'), 16)
    vent = nw('mechanisms/geyser/jungla-vent.png')
    gusts = frames_of(nw('mechanisms/wind/jungla-gust-Sheet.png'), 32)
    sprout = frames_of(nw('items/seed/jungla-sprout-Sheet.png'), 16)
    hop_seq = [0, 0, 0, 1, 1, 2, 2, 2, 2, 1, 0, 0]
    hop_dy = [0, 0, 0, 0, 0, -6, -10, -10, -6, 0, 0, 0]
    gust_seq = [0, 1, 0, 1, 2, 3, 3, 4, 5, 5, 0, 1]
    frames = []
    W, H = 260, 64
    for n in range(24):
        cv = Image.new('RGBA', (W, H), rgb(BG_JUNGLE))
        d = ImageDraw.Draw(cv)
        d.rectangle((0, 52, W, H), fill=rgb('2a3e2c'))
        x = 4 + (n % 12)
        g = gum[n % 4]; cv.paste(g, (x, 36), g)
        g2 = gum[(n + 2) % 4]; cv.paste(g2, (30, 14), g2)                 # el volador, con alas
        wf = wings[(n // 2) % len(wings)]; cv.paste(wf, (30 - 6, 14 + 1), wf)
        c = with_claws(crab[n % 4], claw, 5, (n // 3) % 2, 5.4, -1.6); cv.paste(c, (54 + (n % 12), 52 - c.height), c)
        k = n % 12
        hf = hop[hop_seq[k]]; cv.paste(hf, (92, 31 + hop_dy[k]), hf)
        uf = gust[gust_seq[k]]; cv.paste(uf, (116, 22), uf)
        if gust_seq[k] in (4, 5):
            for jj in range(3):
                wq = gwind[(n + jj) % 3]; cv.paste(wq, (108 - jj * 8, 26), wq)
        pf = pul[n % 2]; cv.paste(pf, (140, 4), pf)
        cv.paste(vent, (164, 44), vent)
        for jj in range(2):
            cf = col[(n + jj) % 3]; cv.paste(cf, (164, 28 - jj * 16), cf)
        cf = crest[n % 3]; cv.paste(cf, (164, 0), cf)
        gf = gusts[n % 3]; cv.paste(gf, (186 + (n * 3) % 20, 10), gf); cv.paste(gf, (190 + (n * 5) % 24, 30), gf)
        sf = sprout[min(2, (n % 12) // 3)]; cv.paste(sf, (238, 36), sf)
        frames.append(big(cv, S).convert('P', palette=Image.ADAPTIVE))
    return frames


if __name__ == '__main__':
    apply, force = '--apply' in sys.argv, '--force' in sys.argv
    new = build_all()
    print('Tamaños (nuevo · los de las demás islas):')
    bad = 0
    for rel, size, refs, ok in verify(new):
        print('  %-48s %-10s %s %s' % (rel, '%dx%d' % size, refs, '' if ok is not False else '  <-- DISTINTO'))
        bad += ok is False
    print('  %d archivos, %d con tamaño distinto' % (len(new), bad))
    # vistas previas + cada archivo, fuera del repositorio
    files = os.path.join(PRUEBAS, 'archivos')
    for rel, im in new.items():
        p = os.path.join(files, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        if isinstance(im, Image.Image): im.save(p)
        else:
            with open(p, 'w') as f: json.dump(im, f)
    pv, secs = preview(new)
    os.makedirs(PRUEBAS, exist_ok=True)
    pv.save(os.path.join(PRUEBAS, 'vista_previa.png'))
    for k, s in enumerate(secs): s.save(os.path.join(PRUEBAS, 'seccion_%d.png' % (k + 1)))
    fr = maqueta(new)
    fr[0].save(os.path.join(PRUEBAS, 'maqueta.gif'), save_all=True, append_images=fr[1:], duration=140, loop=0, disposal=2)
    print('  ' + os.path.join(PRUEBAS, 'vista_previa.png') + '  ·  maqueta.gif  ·  archivos/')
    if apply:
        for rel, im in new.items():
            p = os.path.join(IMG, rel)
            grow = rel == 'enemies/gust/wind-Sheet.png'           # (se amplía: sus 6 filas, tal cual, + la de la jungla)
            if os.path.exists(p) and not (force or grow):
                print('  (ya existe, no se toca: %s)' % rel); continue
            os.makedirs(os.path.dirname(p), exist_ok=True)
            if isinstance(im, Image.Image): im.save(p)
            else:
                with open(p, 'w') as f: json.dump(im, f)
            print('  ' + p)
