#!/usr/bin/env python3
# tools/ui/make_icecrab_sprites.py — sprites del MEGA CRABBY HELADO (variante de hielo del jefe
# Mega Crabby), inspirado en el cangrejo antártico Paralomis birsteini: naranja, caparazón
# redondeado y lleno de espinas, patas y pinzas más LARGAS y espinosas (sin escarcha).
# Mismo estilo y mismas piezas que el Mega Crabby (assets/images/MegaCrabby/): contorno azul
# marino oscuro, luz arriba a la izquierda, sombra abajo a la derecha, ojos de 1 px y boca
# ancha; así se reconoce como "su versión helada" y no como otro enemigo.
#
#   python3 tools/ui/make_icecrab_sprites.py                 # sprites + maqueta en --out
#   python3 tools/ui/make_icecrab_sprites.py --apply         # escribe assets/images/megacrabby_ice/
#   (--out DIR: carpeta de la vista previa; por defecto $FM_PREVIEWS/megacrabby_ice o
#    /home/mtvemo/FlappyMonster_pruebas/megacrabby_ice — fuera del repo)
#
# Piezas (como las del Mega Crabby):
#   crab1/2/3.png         cuerpo + patas, 3 cuadros de andar (18x13 a escala 10, como el Mega)
#   claw_left-Sheet.png   pinza izquierda, 2 cuadros (abierta / cerrada), 10x7, dedos hacia dentro
#   spike.png             la púa de la cabeza, de HIELO (la del Mega recoloreada a azul hielo)
# Vista previa: vista_previa.png (Mega Crabby original vs helado, a escala de juego, sobre la
# pista de hielo, + las tiras ampliadas) y andar.gif (ciclo de andar con chasquidos de pinza).
import argparse
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'assets', 'images', 'MegaCrabby')
DST = os.path.join(ROOT, 'assets', 'images', 'megacrabby_ice')

PAL = {
    '.': None,
    'O': (30, 30, 42),        # contorno (el mismo de todo el juego)
    'H': (255, 216, 168),     # luz
    'L': (248, 158, 88),      # naranja claro
    'M': (226, 104, 50),      # naranja
    'S': (168, 62, 40),       # sombra
    'F': (236, 246, 255),     # escarcha
    'f': (176, 214, 242),     # escarcha en sombra
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--out', default=os.path.join(os.environ.get('FM_PREVIEWS', '/home/mtvemo/FlappyMonster_pruebas'),
                                                  'megacrabby_ice'))
    a = ap.parse_args()
    sp = build()
    os.makedirs(a.out, exist_ok=True)
    for n, im in sp.items(): im.save(os.path.join(a.out, n))
    mockup(sp, a.out)
    print('vista previa:', a.out)
    if a.apply:
        os.makedirs(DST, exist_ok=True)
        for n, im in sp.items(): im.save(os.path.join(DST, n))
        print('escrito', DST)


if __name__ == '__main__':
    sys.exit(main())
