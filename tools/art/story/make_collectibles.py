#!/usr/bin/env python3
# tools/art/story/make_collectibles.py
# Los COLECCIONABLES de la historia (assets/story/collectibles.json) y las PIEZAS que llevan puestas los cangrejos
# secretos. Cada cangrejo lleva su ASTILLA del espejo montada y adornada, y el coleccionable es esa pieza (el usuario,
# 2026-10-29):
#   assets/images/story/collectibles/astilla_crabby.png   la CORONA DE CONCHAS: conchas de arena y coral rojo con la
#                                                         astilla (tono arena-rojizo) engastada como joya
#   assets/images/story/collectibles/astilla_gloomy.png   el AMULETO: la astilla (tono morado lúgubre) colgando de un
#                                                         cordón con su engarce
#   assets/images/story/collectibles/bola_disco.png       la BOLA DE DISCO del Groove, hecha de astillas (teselas del
#                                                         cristal azul del espejo y alguna de cada astilla)
#   assets/images/story/collectibles/astilla_crabby_empty.png / astilla_gloomy_empty.png   la corona y el amuleto VACÍOS
#                                                         (estado 'stolen' de la partida: el Groove les robó la astilla;
#                                                         collectibles.json `states.stolen.icon`)
#   assets/images/story/collectibles/locked.png           la silueta "???" de lo que aún no se tiene (una astilla
#                                                         oscura cualquiera: no desvela la forma de nada)
# Las tres primeras son a la vez el ICONO de las fichas de la Colección y el objeto que suelta el jefe en el nivel
# (mismo tamaño que los fragmentos del espejo: ~16 px de arte, a escala 4).
# Lo que llevan PUESTO los jefes (capas aparte: nunca se tocan sus sprites, retocados a mano por el usuario), a la
# escala de píxel del jefe:
#   assets/images/bosses/megacrabby/wear_crown.png        la corona en la cabeza del Mega Crabby (abraza la base de su púa)
#   assets/images/bosses/megagloomy/wear_amulet.png       el amuleto al cuello del Mega Crabby Lúgubre (bajo el caparazón)
# Dónde van y con qué cuadros: el `WEAR` de cada jefe (src/world/entities/base/Boss.lua, Boss:drawWear).
# Estilo (memoria sprite-design-simple-original): pocos colores, zonas planas, silueta clara, contorno = el tono
# oscuro del propio material (nunca negro). Las astillas se distinguen de los 8 fragmentos grandes del espejo por su
# TONO (cada una el de su jefe) y su forma de esquirla fina.
#   python3 tools/art/story/make_collectibles.py           → solo la vista previa
#   python3 tools/art/story/make_collectibles.py --apply   → escribe los assets (solo archivos NUEVOS o suyos)
import os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'story', 'collectibles')
PREV_DIR = '/home/mtvemo/FlappyMonster_pruebas/coleccion'


def rgb(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


# ── Paletas (pocos colores por pieza) ──────────────────────────────────────────
# astilla del Mega Crabby: cristal arena-rojizo
CRAB_GLASS = {'W': rgb('#fff6ec'), 'G': rgb('#ffc6a8'), 'H': rgb('#e47e62')}
CRAB_EDGE = rgb('#8a3428')
SAND = {'S': rgb('#f2d18c'), 's': rgb('#c98f4c')}
SAND_EDGE = rgb('#6a3c22')
CORAL = {'R': rgb('#e6503c')}
CORAL_EDGE = rgb('#7c2226')
# astilla del Lúgubre: cristal morado
GLOOM_GLASS = {'W': rgb('#fbf7ff'), 'G': rgb('#d6c2ff'), 'H': rgb('#9878dc')}
GLOOM_EDGE = rgb('#3c2a74')
CORD = {'C': rgb('#7a5ab4'), 'M': rgb('#bca4ec'), 'm': rgb('#6c4caa')}
CORD_EDGE = rgb('#2c1e52')
# la bola: teselas del cristal del espejo (los fragmentos grandes: make_mirror_shards.py) y alguna de cada astilla
MIRROR = [rgb('#ffffff'), rgb('#d6eeff'), rgb('#a2ccf2'), rgb('#709edc')]
MIRROR_EDGE = rgb('#34508c')
METAL = {'K': rgb('#c4c8d4'), 'k': rgb('#7a7e96')}
METAL_EDGE = rgb('#3a3c52')
# silueta "???"
LOCK = {'L': rgb('#2a2f48')}
LOCK_EDGE = rgb('#6a7299')


def from_map(rows, pal):
    """Mapa de caracteres → (imagen, materiales). '.' = vacío."""
    h, w = len(rows), max(len(r) for r in rows)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    mat = [[None] * w for _ in range(h)]
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.':
                im.putpixel((x, y), pal[ch][0])
                mat[y][x] = pal[ch][1]
    return im, mat


def outline(im, mat, pad=1):
    """Contorno de 1 px (4 vecinos) alrededor de todo, del tono oscuro del material vecino."""
    w, h = im.size
    out = Image.new('RGBA', (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    out.paste(im, (pad, pad))
    for y in range(h + 2 * pad):
        for x in range(w + 2 * pad):
            sx, sy = x - pad, y - pad
            if 0 <= sx < w and 0 <= sy < h and mat[sy][sx]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = sx + dx, sy + dy
                if 0 <= nx < w and 0 <= ny < h and mat[ny][nx]:
                    out.putpixel((x, y), mat[ny][nx])
                    break
    return out


def palette(*groups):
    """groups: (dict de colores, color del contorno) → {char: (color, contorno)}"""
    p = {}
    for cols, edge in groups:
        for k, c in cols.items():
            p[k] = (c, edge)
    return p


# ── LA CORONA DE CONCHAS (astilla_crabby) ──────────────────────────────────────
# Dos ramas de coral a los lados, dos conchas en punta y, en medio, la astilla de pie como joya; abajo, la banda.
CROWN = [
    ".......W.......",
    "......WG.......",
    ".R....WGH....R.",
    "R.R...WGH...R.R",
    "R.R.S.WGH.S.R.R",
    ".RR.SsWGHsS.RR.",
    "..RSSsWGHsSSR..",
    "..RSSsWGHsSSR..",
    "SSSSSSSWSSSSSSS",
    "SsSSsSSSSSsSSsS",
    "sssssssssssssss",
]
CROWN_PAL = palette((CRAB_GLASS, CRAB_EDGE), (SAND, SAND_EDGE), (CORAL, CORAL_EDGE))

# La corona VACÍA (estado 'stolen': el Groove le sacó la astilla para su bola): el engaste abierto, con sus dos garras
# y el hueco oscuro donde iba la joya. Mismo lienzo que la llena (se cambia una por otra sin moverse)
CROWN_EMPTY = [
    "...............",
    "...............",
    ".R...........R.",
    "R.R.........R.R",
    "R.R.S.....S.R.R",
    ".RR.Ss...sS.RR.",
    "..RSSss.ssSSR..",
    "..RSSsskssSSR..",
    "SSSSSSSkSSSSSSS",
    "SsSSsSSSSSsSSsS",
    "sssssssssssssss",
]
CROWN_EMPTY_PAL = dict(CROWN_PAL, k=(SAND_EDGE, SAND_EDGE))

# La corona PUESTA (cabeza del Mega Crabby, a su escala de píxel): más pequeña y simple, abraza la base de la púa
CROWN_WORN = [
    "R...W...R",
    "R.SWGHS.R",
    "RSSWGHSSR",
    "sssssssss",
]

# ── EL AMULETO (astilla_gloomy) ────────────────────────────────────────────────
AMULET = [
    "...CCCCCCCCC...",
    "..C.........C..",
    ".C...........C.",
    ".C...........C.",
    "..C.........C..",
    "...C.......C...",
    "....C.....C....",
    ".....CMMMC.....",
    "......MmM......",
    ".....WWGGH.....",
    ".....WWGGH.....",
    "......WGGH.....",
    "......WGH......",
    "......WGH......",
    ".......GH......",
    ".......H.......",
]
AMULET_PAL = palette((GLOOM_GLASS, GLOOM_EDGE), (CORD, CORD_EDGE))

# El amuleto VACÍO (estado 'stolen'): el cordón y el engarce, abierto y sin la astilla. Mismo lienzo que el lleno
AMULET_EMPTY = [
    "...CCCCCCCCC...",
    "..C.........C..",
    ".C...........C.",
    ".C...........C.",
    "..C.........C..",
    "...C.......C...",
    "....C.....C....",
    ".....CMMMC.....",
    "......MmM......",
    ".....MkkkM.....",
    ".....MkkkM.....",
    "......MMM......",
    "...............",
    "...............",
    "...............",
    "...............",
]
AMULET_EMPTY_PAL = dict(AMULET_PAL, k=(CORD_EDGE, CORD_EDGE))

# El amuleto PUESTO (al cuello del Lúgubre, bajo el caparazón): el cordón sale de los lados del caparazón
AMULET_WORN = [
    "C.....C",
    ".C...C.",
    "..MMM..",
    "..WGH..",
    "..WGH..",
    "...H...",
]

# ── LA SILUETA "???" ───────────────────────────────────────────────────────────
LOCKED = [
    "........L.....",
    ".......LL.....",
    "......LLL.....",
    ".....LLLLL....",
    "....LLLLLL....",
    "....LLLLLLL...",
    "...LLLLLLLL...",
    "...LLLLLLLLL..",
    "..LLLLLLLLLL..",
    "..LLLLLLLLL...",
    ".LLLLLLLLLL...",
    ".LLLLLLLLL....",
    "LLLLLLLLL.....",
    "..LLLLLL......",
    "....LLL.......",
]


def disco_ball():
    """La bola de disco: esfera de teselas de 3x3 (cristal del espejo; luz arriba a la izquierda) con su tapa y anilla."""
    w, h = 15, 18
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    mat = [[None] * w for _ in range(h)]

    def put(x, y, c, e):
        im.putpixel((x, y), c)
        mat[y][x] = e

    # anilla y tapa
    for x, y in ((6, 0), (8, 0), (6, 1), (8, 1)):
        put(x, y, METAL['k'], METAL_EDGE)
    put(7, 0, (0, 0, 0, 0), None)
    for x in range(5, 10):
        put(x, 2, METAL['K'] if x < 8 else METAL['k'], METAL_EDGE)
    # esfera: centro (7, 10), radio 7
    cx, cy, r = 7, 10, 7.2
    warm, purple = CRAB_GLASS['G'], GLOOM_GLASS['G']
    special = {(1, 2): warm, (3, 1): purple, (2, 3): warm, (0, 1): purple}     # (tesela col, fila) de cada astilla
    for y in range(3, h):
        for x in range(w):
            if (x - cx) ** 2 + (y - cy) ** 2 > r * r:
                continue
            tx, ty = (x - 1) // 3, (y - 4) // 3
            light = (x - cx) * 0.7 + (y - cy) * 0.9                # (negativo = hacia la luz)
            band = 0 if light < -4 else (1 if light < 1 else (2 if light < 5 else 3))
            tone = band + ((tx + ty) % 2)                           # (tablero: dos tonos vecinos)
            c = special.get((tx, ty)) or MIRROR[min(3, tone)]
            put(x, y, c, MIRROR_EDGE)
    # brillo
    for x, y in ((4, 6), (5, 6), (4, 7)):
        put(x, y, MIRROR[0], MIRROR_EDGE)
    return im, mat


def build():
    out = {}
    out['astilla_crabby'] = outline(*from_map(CROWN, CROWN_PAL))
    out['astilla_gloomy'] = outline(*from_map(AMULET, AMULET_PAL))
    out['astilla_crabby_empty'] = outline(*from_map(CROWN_EMPTY, CROWN_EMPTY_PAL))
    out['astilla_gloomy_empty'] = outline(*from_map(AMULET_EMPTY, AMULET_EMPTY_PAL))
    out['bola_disco'] = outline(*disco_ball())
    out['locked'] = outline(*from_map(LOCKED, palette((LOCK, LOCK_EDGE))))
    worn = {
        'megacrabby/wear_crown': outline(*from_map(CROWN_WORN, CROWN_PAL)),
        'megagloomy/wear_amulet': outline(*from_map(AMULET_WORN, AMULET_PAL)),
    }
    return out, worn


# ── Vista previa ───────────────────────────────────────────────────────────────
def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def boss_preview(worn):
    """Los dos jefes con su pieza puesta, con las mismas anclas que el juego (Boss WEAR)."""
    crab = Image.open(os.path.join(ROOT, 'assets/images/bosses/megacrabby/crab2.png')).convert('RGBA')
    spike = Image.open(os.path.join(ROOT, 'assets/images/bosses/megacrabby/spike.png')).convert('RGBA')
    claw = Image.open(os.path.join(ROOT, 'assets/images/bosses/megacrabby/claw_left-Sheet.png')).convert('RGBA').crop((0, 0, 10, 7))
    sheet = Image.open(os.path.join(ROOT, 'assets/images/bosses/megagloomy/body-Sheet.png')).convert('RGBA')
    K = 10                                     # la escala de píxel de los dos jefes (MS)
    W, H = 900, 330
    pv = Image.new('RGBA', (W, H), (52, 70, 96, 255))
    d = ImageDraw.Draw(pv)
    d.rectangle((0, 290, W, H), fill=(40, 46, 60, 255))
    # Mega Crabby: pies en (170, 290); púa detrás, cuerpo, corona (ancla: base de la púa, centro), pinzas
    fx, fy = 170, 290
    body = up(crab, K)
    sp = spike.resize((round(spike.width * K / 4), round(spike.height * K / 4)), Image.NEAREST)
    pv.alpha_composite(sp, (fx - sp.width // 2, fy - body.height - sp.height + K))
    pv.alpha_composite(body, (fx - body.width // 2, fy - body.height))
    cr = up(worn['megacrabby/wear_crown'], K)
    pv.alpha_composite(cr, (fx - cr.width // 2, fy - body.height - cr.height + K))
    cl = up(claw, 7)
    pv.alpha_composite(cl, (fx - 48 - cl.width - 30, fy - 40 - cl.height))
    pv.alpha_composite(cl.transpose(Image.FLIP_LEFT_RIGHT), (fx + 48 + 30, fy - 40 - cl.height))
    # Lúgubre: cuadros 5 (quieto), 6 (agachado), 7 (salto), 8 (asustado) con el amuleto colgando del caparazón
    shell = {5: 13, 6: 15, 7: 11, 8: 12}
    am = up(worn['megagloomy/wear_amulet'], K)
    for i, f in enumerate((5, 6, 7, 8)):
        fr = up(sheet.crop(((f - 1) * 38, 0, f * 38, 21)), K // 2)
        ox = 330 + i * 140 - fr.width // 2 + 40
        oy = 290 - fr.height
        pv.alpha_composite(fr, (ox, oy))
        ax, ay = ox + 19.5 * K // 2, oy + shell[f] * K // 2
        a2 = up(worn['megagloomy/wear_amulet'], K // 2)
        pv.alpha_composite(a2, (int(ax - a2.width / 2), int(ay - K // 2)))
    return pv


def preview(items, worn):
    os.makedirs(PREV_DIR, exist_ok=True)
    pv = Image.new('RGBA', (1340, 640), (30, 34, 52, 255))
    d = ImageDraw.Draw(pv)
    x = 30
    for name in ('astilla_crabby', 'astilla_gloomy', 'bola_disco', 'locked', 'astilla_crabby_empty', 'astilla_gloomy_empty'):
        im = up(items[name], 10)
        d.rectangle((x - 10, 20, x + 190, 220), fill=(46, 52, 78, 255))
        pv.alpha_composite(im, (x + 90 - im.width // 2, 120 - im.height // 2))
        x += 220
    # a la escala del nivel (4) sobre un fondo de nivel, junto a un fragmento grande del espejo
    d.rectangle((0, 240, 900, 330), fill=(96, 150, 196, 255))
    x = 40
    shard = Image.open(os.path.join(ROOT, 'assets/images/story/mirror/shard_1.png')).convert('RGBA')
    shard = shard.crop(shard.getbbox())
    for im in (shard, items['astilla_crabby'], items['astilla_gloomy'], items['bola_disco']):
        u = up(im, 4)
        pv.alpha_composite(u, (x, 285 - u.height // 2))
        x += 120
    pv.alpha_composite(boss_preview(worn), (0, 310))
    pv.save(os.path.join(PREV_DIR, 'vista_previa.png'))
    boss_preview(worn).save(os.path.join(PREV_DIR, 'jefes_con_pieza.png'))
    print('vista previa:', os.path.join(PREV_DIR, 'vista_previa.png'))


def main():
    items, worn = build()
    preview(items, worn)
    if '--apply' not in sys.argv:
        return
    os.makedirs(OUT, exist_ok=True)
    for name, im in items.items():
        im.save(os.path.join(OUT, name + '.png'))
        print('escrito', os.path.join(OUT, name + '.png'))
    for name, im in worn.items():
        im.save(os.path.join(ROOT, 'assets', 'images', 'bosses', name + '.png'))
        print('escrito', os.path.join('assets/images/bosses', name + '.png'))


if __name__ == '__main__':
    main()
