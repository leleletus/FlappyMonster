#!/usr/bin/env python3
# tools/ui/make_icecrab_sprites.py — sprites del MEGA CRABBY HELADO (variante de hielo del jefe
# Mega Crabby), inspirado en el cangrejo antártico Paralomis birsteini: naranja, caparazón
# redondeado y lleno de espinas, patas y pinzas más LARGAS y espinosas (sin escarcha).
# Mismo estilo y mismas piezas que el Mega Crabby (assets/images/bosses/megacrabby/): contorno azul
# marino oscuro, luz arriba a la izquierda, sombra abajo a la derecha, ojos de 1 px y boca
# ancha; así se reconoce como "su versión helada" y no como otro enemigo.
#
#   python3 tools/ui/make_icecrab_sprites.py                 # sprites + maqueta en --out
#   python3 tools/ui/make_icecrab_sprites.py --apply         # escribe assets/images/bosses/megacrabby_ice/
#   (--out DIR: carpeta de la vista previa; por defecto $FM_PREVIEWS/megacrabby_ice o
#    /home/mtvemo/FlappyMonster_pruebas/megacrabby_ice — fuera del repo)
#
# Piezas (como las del Mega Crabby):
#   crab1/2/3.png         cuerpo + patas, 3 cuadros de andar (18x13 a escala 10, como el Mega)
#   claw_left-Sheet.png   pinza izquierda, 2 cuadros (abierta / cerrada), 10x7, dedos hacia dentro
#   spike.png             la púa de la cabeza, de HIELO (la del Mega recoloreada a azul hielo)
#   rage_body-Sheet.png   enfadado: esquirlas de hielo sobre el caparazón (26x21, 2 cuadros: normal / brillo)
#   rage_claw-Sheet.png   enfadado: esquirlas sobre la pinza (18x15, centrada como la pinza, 2 cuadros)
#                         (--rabia A|B|C|D elige la opción; la del juego: cuerpo A "Esquirlas" + pinzas B "Corona"
#                         = --rabia A --rabia-pinza B; vista previa: rabia_opciones.png, pua.png)
# Vista previa: vista_previa.png (Mega Crabby original vs helado, a escala de juego, sobre la
# pista de hielo, + las tiras ampliadas) y andar.gif (ciclo de andar con chasquidos de pinza).
import argparse
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'assets', 'images', 'bosses', 'megacrabby')
DST = os.path.join(ROOT, 'assets', 'images', 'bosses', 'megacrabby_ice')

PAL = {
    '.': None,
    'O': (30, 30, 42),        # contorno (el mismo de todo el juego)
    'H': (255, 216, 168),     # luz
    'L': (248, 158, 88),      # naranja claro
    'M': (226, 104, 50),      # naranja
    'S': (168, 62, 40),       # sombra
    'F': (236, 246, 255),     # escarcha
    'f': (176, 214, 242),     # escarcha en sombra
    'B': (110, 160, 214),     # hielo en sombra
}
# MISMA RESOLUCIÓN QUE EL MEGA: el pixel del helado mide lo mismo que el del Mega Crabby
# (escala 10), así encaja con el resto del juego. El diseño es el de la 3.ª propuesta
# (caparazón redondo con bultos y púas, sin escarcha ni boca, patas largas, pinzas grandes)
# dibujado a mano a esa resolución. Las pinzas apuntan HACIA DENTRO (hacia el cuerpo).
SCALE = 10                  # escala de juego (la del Mega Crabby)
CLAW_K = 1.0                # pinzas a la escala del cuerpo (el Mega: 0.85): más grandes
CLAW_X, CLAW_Y = 5.4, -1.2  # dónde van las pinzas (px de arte desde el centro-abajo del cuerpo)

SHELL = [
    ".....O.O..O.O.....",
    "....OOOOOOOOOO....",
    "...OHHHLLLLLLMO...",
    "..OHLHLLLLHLLMSO..",
    "OOLLLOLLLLLLOLMSOO",
    ".OMLSLLLLLLSLMMSO.",
    "..OMMMMMMMMMMSSO..",
    "...OOOOOOOOOOOO...",
]
# Patas: 2 por lado, naranjas con su borde oscuro por fuera; mitad izquierda (9 px), el
# lado derecho es el espejo de otro cuadro (paso alterno)
LEG_HALVES = [          # filas 8-12
    [".OM..OM..",
     "OM...OM..",
     "OM....OM.",
     "OS....OS.",
     "O.....O.."],
    [".OM..OM..",
     ".OM...OM.",
     "OM....OM.",
     "OS...OS..",
     "O....O..."],
    [".OM..OM..",
     "OM..OM...",
     "OM..OM...",
     ".OS.OS...",
     ".O..O...."],
]
PHASE = [0, 2, 1]


def body(frame):
    rows = list(SHELL)
    for l, r in zip(LEG_HALVES[frame], LEG_HALVES[PHASE[frame]]):
        rows.append(l + r[::-1])
    return rows


# Pinza izquierda con los dedos HACIA DENTRO (a la derecha; la derecha es su espejo):
# grande, con 3 púas en el dorso. Cuadro 1 abierta, 2 cerrada.
CLAWS = [
    ["...O.O.O..",
     ".OOOOOOOO.",
     "OHHLLLLLLO",
     "OHLLMOOO.O",
     "OLLMO.....",
     "OLLMMMMMO.",
     ".OOOOOOO.."],
    ["...O.O.O..",
     ".OOOOOOOO.",
     "OHHLLLLLLO",
     "OHLLMOOOOO",
     "OLLLMMMMO.",
     "OLMMSSSO..",
     ".OOOOOO..."],
]


def claw(opened): return CLAWS[0 if opened else 1]


ICE = {(255, 255, 255): (226, 246, 255), (242, 242, 246): (186, 226, 250),
       (196, 200, 214): (118, 172, 222), (30, 30, 42): (30, 30, 42)}


def grid(rows):
    w = len(rows[0])
    for r in rows:
        assert len(r) == w, (len(r), r)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            c = PAL[ch]
            if c: im.putpixel((x, y), c + (255,))
    return im


def build():
    out = {}
    for i in range(3):
        out['crab%d.png' % (i + 1)] = grid(body(i))
    a, b = grid(claw(True)), grid(claw(False))
    sheet = Image.new('RGBA', (a.width * 2, a.height), (0, 0, 0, 0))
    sheet.paste(a, (0, 0)); sheet.paste(b, (a.width, 0))
    out['claw_left-Sheet.png'] = sheet
    sp = Image.open(os.path.join(SRC, 'spike.png')).convert('RGBA')
    px = sp.load()
    for y in range(sp.height):
        for x in range(sp.width):
            p = px[x, y]
            if p[3] and p[:3] in ICE: px[x, y] = ICE[p[:3]] + (p[3],)
    out['spike.png'] = sp
    return out


# ── Maqueta ──────────────────────────────────────────────────────────────────
def up(im, s): return im.resize((round(im.width * s), round(im.height * s)), Image.NEAREST)


def crab(canvas, body, claws, spike, cx, floor, s, claw_k=0.85, claw_x=4.6, claw_y=-1.6, frames=(0, 0),
         spike_s=None):
    """Monta el cangrejo como Mega:drawLocal (púa detrás, cuerpo, pinzas delante).
    claw_x / claw_y en px de arte del cuerpo desde su centro-abajo."""
    cs = max(1, round(s * claw_k))
    ss = spike_s or s / 4
    sk = spike.resize((round(spike.width * ss), round(spike.height * ss)), Image.NEAREST)
    canvas.alpha_composite(sk, (int(cx - sk.width / 2), int(floor - body.height * s - sk.height + 6 * ss)))
    b = up(body, s)
    canvas.alpha_composite(b, (cx - b.width // 2, floor - b.height))
    fw = claws.width // 2
    for i, side in enumerate((-1, 1)):
        fr = claws.crop((frames[i] * fw, 0, (frames[i] + 1) * fw, claws.height))
        if side > 0: fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
        c = up(fr, cs)
        x = cx + side * (claw_x * s + fw * cs / 2 - 1.5 * cs) - c.width / 2
        y = floor + claw_y * s - claws.height * cs / 2 - c.height / 2
        canvas.alpha_composite(c, (int(x), int(y)))


def background(w, h, floor):
    bg = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    px = bg.load()
    for y in range(h):                                         # cielo del atardecer en bandas
        k = (y // 24) * 24 / max(1, floor)
        c = (int(70 + 60 * k), int(80 + 50 * k), int(140 - 10 * k))
        for x in range(w): px[x, y] = c + (255,)
    for y in range(floor, h):
        c = (236, 244, 255) if y < floor + 8 else (200, 218, 240)
        for x in range(w): px[x, y] = c + (255,)
    return bg


def mockup(sprites, out):
    orig = {n: Image.open(os.path.join(SRC, n)).convert('RGBA')
            for n in ('crab1.png', 'claw_left-Sheet.png', 'spike.png')}
    W, H, floor = 1280, 1040, 470
    im = background(W, H, floor)
    try:
        from PIL import ImageDraw, ImageFont
        d = ImageDraw.Draw(im)
        font = ImageFont.load_default()
    except Exception:
        d = None
    crab(im, orig['crab1.png'], orig['claw_left-Sheet.png'], orig['spike.png'], 330, floor, 10)
    crab(im, sprites['crab1.png'], sprites['claw_left-Sheet.png'], sprites['spike.png'], 930, floor, SCALE,
         claw_k=CLAW_K, claw_x=CLAW_X, claw_y=CLAW_Y, frames=(0, 1))
    # jugador de referencia (tamaño)
    pl = os.path.join(ROOT, 'assets', 'images', 'player', 'monstrito1.png')
    if os.path.exists(pl):
        p = up(Image.open(pl).convert('RGBA'), 6)
        im.alpha_composite(p, (620, floor - p.height))
    if d:
        d.text((250, 40), 'MEGA CRABBY (actual) x10', fill=(255, 255, 255), font=font)
        d.text((830, 40), 'MEGA CRABBY HELADO x10 (propuesta)', fill=(255, 255, 255), font=font)
    # tiras ampliadas: 3 cuadros de andar, 2 de pinza, púa
    y0 = floor + 140
    x = 40
    for n in ('crab1.png', 'crab2.png', 'crab3.png'):
        a = up(sprites[n], 10)
        im.alpha_composite(a, (x, y0)); x += a.width + 24
    c = up(sprites['claw_left-Sheet.png'], 10)
    im.alpha_composite(c, (x, y0)); x += c.width + 24
    s = up(sprites['spike.png'], 3)
    im.alpha_composite(s, (x, y0 - 10))
    if d:
        d.text((40, y0 - 22), 'andar 1-3 (x10)                                                                pinza abierta / cerrada (x10)', fill=(255, 255, 255), font=font)
    os.makedirs(out, exist_ok=True)
    im.convert('RGB').save(os.path.join(out, 'vista_previa.png'))
    # GIF: ciclo de andar (1-2-1-3) con chasquidos de pinza, junto al original
    frames = []
    seq = [1, 2, 1, 3]
    for i in range(16):
        f = background(760, 300, 250)
        n = seq[i % 4]
        o = Image.open(os.path.join(SRC, 'crab%d.png' % n)).convert('RGBA')
        crab(f, o, orig['claw_left-Sheet.png'], orig['spike.png'], 190, 250, 7, frames=((i // 3) % 2, (i // 5) % 2))
        crab(f, sprites['crab%d.png' % n], sprites['claw_left-Sheet.png'], sprites['spike.png'], 560, 250, 7,
             claw_k=CLAW_K, claw_x=CLAW_X, claw_y=CLAW_Y, frames=((i // 3) % 2, (i // 5) % 2))
        frames.append(f.convert('RGB'))
    frames[0].save(os.path.join(out, 'andar.gif'), save_all=True, append_images=frames[1:], duration=140, loop=0)


# ── Enfadado: coraza de esquirlas de hielo ───────────────────────────────────
# Al enfadarse le salen esquirlas de hielo afiladas en el caparazón y en las pinzas. Son dos
# capas que el juego dibuja ENCIMA del cuerpo y de cada pinza con la misma transformación
# (rage_body-Sheet.png, rage_claw-Sheet.png), así siguen el andar, los chasquidos y el squash.
# Cada esquirla es un triángulo afilado rasterizado a mano: base sobre el borde, punta hacia
# fuera, contorno oscuro (menos en la base, que nace del caparazón), luz en un lado.
# Opciones (para elegir): --rabia A|B|C|D
RP_X, RP_TOP = 4, 8        # margen de la capa del cuerpo: a los lados y arriba (px de arte)
RC_P = 4                   # margen de la capa de la pinza (a todos los lados: se dibuja centrada)
ICEP = {'O': (30, 30, 42), 'W': (255, 255, 255), 'F': (226, 246, 255), 'f': (176, 214, 242),
        'B': (110, 160, 214), 'D': (70, 112, 184)}

# (x, y de la base en px de arte del cuerpo o de la pinza izquierda; ángulo: 0 = arriba,
#  -90 = izquierda; largo; ancho de la base). Las del lado derecho del cuerpo son el espejo.
RAGE = {
    'A': {  # Esquirlas: dos esquirlas medianas por hombro, abiertas en abanico; tres en el dorso de la pinza
        'name': 'Esquirlas',
        'body': [(4.6, 1.2, -24, 5, 3.2), (2.8, 2.6, -52, 5, 3.2)],
        'claw': [(2.4, 0.8, -24, 4, 3.0), (5.0, 0.6, -2, 3.5, 2.6), (7.4, 0.8, 18, 3, 2.4)],
    },
    'B': {  # Corona: una gran esquirla en cada hombro con otras dos menores + puñal en la pinza
        'name': 'Corona',
        'body': [(4.0, 1.6, -36, 8, 4.0), (6.2, 0.8, -10, 5, 3.0), (2.4, 3.0, -62, 4, 3.0)],
        'claw': [(2.2, 1.0, -34, 6, 3.6), (5.0, 0.6, -6, 3.5, 2.6)],
    },
    'C': {  # Sierra: dientes cortos y anchos, muy juntos, por el borde y el dorso de la pinza
        'name': 'Sierra',
        'body': [(5.8, 0.8, -12, 3, 2.8), (4.0, 1.4, -36, 3, 2.8), (2.4, 3.0, -60, 3, 2.8)],
        'claw': [(1.6, 1.0, -30, 3, 2.6), (3.6, 0.6, -10, 3, 2.6), (5.6, 0.6, 8, 3, 2.6), (7.6, 0.8, 24, 2.5, 2.4)],
    },
    'D': {  # Agujas: dos agujas muy largas por lado (como las espinas del Paralomis) + dos en la pinza
        'name': 'Agujas',
        'body': [(4.0, 1.6, -38, 9, 2.8), (2.2, 3.0, -64, 7, 2.6)],
        'claw': [(2.4, 0.8, -26, 6, 2.6), (5.4, 0.6, 4, 4, 2.2)],
    },
}


def shard_layer(w, h, shards, ox, oy, mirror_w=None):
    """Rasteriza las esquirlas en una capa w x h; (ox, oy) = dónde cae el (0, 0) del arte.
    mirror_w: ancho del arte para añadir el espejo de cada esquirla (lado derecho).
    Cobertura con 4x4 submuestras (un píxel cuenta si la esquirla cubre >= 40 %) y la línea
    central siempre pintada, para que una esquirla fina no se rompa en píxeles sueltos."""
    import math
    full = list(shards)
    if mirror_w:
        full += [(mirror_w - x, y, -a, L, bw) for (x, y, a, L, bw) in shards]
    kind = {}
    for (bx, by, a, L, bw) in full:
        r = math.radians(a)
        ax, ay = math.sin(r), -math.cos(r)              # eje (de la base a la punta)
        nx, ny = -ay, ax                                 # perpendicular
        light = -1 if a >= 0 else 1                      # la luz, del lado de arriba-izquierda

        def inside(x, y):
            dx, dy = x - bx, y - by
            u, v = dx * ax + dy * ay, dx * nx + dy * ny
            return u, v, (-0.4 <= u <= L and abs(v) <= bw / 2 * (1 - max(0.0, u) / L))
        cells = {}
        for py in range(h):
            for px in range(w):
                n, uu, vv = 0, 0.0, 0.0
                for sy in range(4):
                    for sx in range(4):
                        u, v, ok = inside(px - ox + (sx + 0.5) / 4, py - oy + (sy + 0.5) / 4)
                        if ok: n += 1; uu += u; vv += v
                if n >= 7: cells[(px, py)] = (uu / n, vv / n)
        for k in range(int(L * 3)):                       # línea central (sin huecos)
            t = k / 3
            px, py = int(math.floor(bx + ax * t + ox)), int(math.floor(by + ay * t + oy))
            if 0 <= px < w and 0 <= py < h and (px, py) not in cells: cells[(px, py)] = (t, 0.0)
        for (px, py), (u, v) in cells.items():
            if u > L - 1.3: c = 'W'
            elif v * light > 0.3: c = 'F'
            elif v * light < -0.3: c = 'B' if u > 1.2 else 'D'
            else: c = 'f'
            if (px, py) not in kind or u < kind[(px, py)][1]: kind[(px, py)] = (c, u)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for (px, py), (c, u) in kind.items():
        im.putpixel((px, py), ICEP[c] + (255,))
    # contorno: huecos junto a la esquirla que no queden en su base (nace del caparazón)
    for (px, py), (c, u) in list(kind.items()):
        if u < 1.2: continue
        for qx, qy in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
            if 0 <= qx < w and 0 <= qy < h and (qx, qy) not in kind and im.getpixel((qx, qy))[3] == 0:
                im.putpixel((qx, qy), ICEP['O'] + (255,))
    return im


def glint(im, seed):
    """2.º cuadro: un brillo que recorre algunas puntas"""
    import random
    rnd = random.Random(seed)
    g = im.copy()
    pts = [(x, y) for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[:3] == ICEP['F']]
    for p in rnd.sample(pts, min(len(pts), max(1, len(pts) // 5))):
        g.putpixel(p, ICEP['W'] + (255,))
    return g


def rage_layers(opt, claw_opt=None):
    o = RAGE[opt]
    oc = RAGE[claw_opt or opt]
    bw, bh = 18 + 2 * RP_X, 13 + RP_TOP
    b = shard_layer(bw, bh, o['body'], RP_X, RP_TOP, mirror_w=18)
    cw, ch = 10 + 2 * RC_P, 7 + 2 * RC_P
    c = shard_layer(cw, ch, oc['claw'], RC_P, RC_P)
    body = Image.new('RGBA', (bw * 2, bh), (0, 0, 0, 0))
    body.paste(b, (0, 0)); body.paste(glint(b, 1), (bw, 0))
    claw = Image.new('RGBA', (cw * 2, ch), (0, 0, 0, 0))
    claw.paste(c, (0, 0)); claw.paste(glint(c, 2), (cw, 0))
    return body, claw


SPIKE_DY = 2               # la púa de la cabeza va 2 px de arte más abajo (encajada en el caparazón)


def crab_game(canvas, sp, cx, floor, s, rage=None, frames=(0, 1), spike_dy=SPIKE_DY, anger=True):
    """Como Mega:drawLocal + renderAnger (en el juego): púa detrás (origen abajo-centro, escala
    s/4, sobre la cabeza), cuerpo (origen abajo-centro), pinzas centradas delante, capas de rabia."""
    body = sp['crab1.png']
    ih = body.height
    spike = sp['spike.png']
    sk = up(spike, s / 4)
    canvas.alpha_composite(sk, (int(cx - sk.width / 2), int(floor - (ih - spike_dy) * s - (spike.height - 1) * s / 4)))
    b = up(body, s)
    canvas.alpha_composite(b, (int(cx - b.width / 2), floor - b.height))
    if rage:
        rb = rage[0].crop((0, 0, rage[0].width // 2, rage[0].height))
        r = up(rb, s)
        canvas.alpha_composite(r, (int(cx - r.width / 2), floor - r.height))
    cs = s * CLAW_K
    claws = sp['claw_left-Sheet.png']
    fw = claws.width // 2
    for i, side in enumerate((-1, 1)):
        fr = claws.crop((frames[i] * fw, 0, (frames[i] + 1) * fw, claws.height))
        ccx = cx + side * (CLAW_X * s + fw * cs / 2 - 1.5 * cs)
        ccy = floor + CLAW_Y * s - claws.height * cs / 2
        layers = [fr]
        if rage:
            rc = rage[1].crop((0, 0, rage[1].width // 2, rage[1].height))
            layers.append(rc)
        for L in layers:
            if side > 0: L = L.transpose(Image.FLIP_LEFT_RIGHT)
            c = up(L, cs)
            canvas.alpha_composite(c, (int(ccx - c.width / 2), int(ccy - c.height / 2)))
    if rage and anger:                                    # vena y vapor (los del Mega)
        vein = Image.open(os.path.join(SRC, '..', 'common', 'anger_vein.png')).convert('RGBA').crop((0, 0, 11, 11))
        steam = Image.open(os.path.join(SRC, '..', 'common', 'anger_steam.png')).convert('RGBA')
        steam = steam.crop((9, 0, 18, steam.height))
        hy = floor - ih * s
        for im, x, y in ((vein, cx - 0.4 * body.width * s, hy + 0.1 * ih * s),
                         (steam, cx + 0.38 * body.width * s, hy - 0.05 * ih * s)):
            k = up(im, 3)
            sh = Image.new('RGBA', k.size, (0, 0, 0, 128)); sh.putalpha(k.getchannel('A').point(lambda a: a // 2))
            canvas.alpha_composite(sh, (int(x - k.width / 2 + 3), int(y - k.height / 2 + 3)))
            canvas.alpha_composite(k, (int(x - k.width / 2), int(y - k.height / 2)))


def rage_preview(sp, out):
    from PIL import ImageDraw, ImageFont
    font = ImageFont.load_default()
    # 1) púa: antes / después
    W, H, floor = 900, 330, 290
    im = background(W, H, floor)
    crab_game(im, sp, 230, floor, SCALE, spike_dy=0)
    crab_game(im, sp, 670, floor, SCALE)
    d = ImageDraw.Draw(im)
    d.text((150, 14), 'PUA: ahora', fill=(255, 255, 255), font=font)
    d.text((570, 14), 'PUA: 2 px mas abajo', fill=(255, 255, 255), font=font)
    im.convert('RGB').save(os.path.join(out, 'pua.png'))
    # 2) opciones de la rabia, a escala de juego, con la vena y el vapor
    opts = sorted(RAGE)
    W, H, floor = 460 * len(opts), 560, 300
    im = background(W, H, floor)
    d = ImageDraw.Draw(im)
    for i, k in enumerate(opts):
        lay = rage_layers(k)
        cx = 230 + i * 460
        crab_game(im, sp, cx, floor, SCALE, rage=lay)
        d.text((cx - 120, 14), 'OPCION %s: %s' % (k, RAGE[k]['name']), fill=(255, 255, 255), font=font)
        # capas ampliadas (cuerpo + pinza) debajo
        b = up(lay[0].crop((0, 0, lay[0].width // 2, lay[0].height)), 7)
        c = up(lay[1].crop((0, 0, lay[1].width // 2, lay[1].height)), 7)
        im.alpha_composite(b, (cx - 200, floor + 60))
        im.alpha_composite(c, (cx + 200 - c.width, floor + 60))
    im.convert('RGB').save(os.path.join(out, 'rabia_opciones.png'))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--rabia', default=None, help='opción de la coraza de rabia que se escribe (A/B/C/D): el cuerpo')
    ap.add_argument('--rabia-pinza', default=None, help='opción para las pinzas (por defecto la de --rabia)')
    ap.add_argument('--out', default=os.path.join(os.environ.get('FM_PREVIEWS', '/home/mtvemo/FlappyMonster_pruebas'),
                                                  'megacrabby_ice'))
    a = ap.parse_args()
    sp = build()
    os.makedirs(a.out, exist_ok=True)
    for n, im in sp.items(): im.save(os.path.join(a.out, n))
    if a.rabia:
        body, claw = rage_layers(a.rabia, a.rabia_pinza)
        sp['rage_body-Sheet.png'], sp['rage_claw-Sheet.png'] = body, claw
    mockup(sp, a.out)
    rage_preview(sp, a.out)
    print('vista previa:', a.out)
    if a.apply:
        os.makedirs(DST, exist_ok=True)
        for n, im in sp.items(): im.save(os.path.join(DST, n))
        print('escrito', DST)


if __name__ == '__main__':
    sys.exit(main())
