#!/usr/bin/env python3
# tools/art/bosses/make_groove_crab.py — el arte de EL GROOVE (el Crabby trampolín gigante, jefe secreto).
#
# Diseño PROPIO (el usuario: "que no sea solo un reskin del Mega Crabby"), con el estilo de los cangrejos del juego:
# contorno oscuro, cuerpo en dos o tres tonos, patitas finas oscuras en 3 cuadros de andar y pinzas aparte en 2
# cuadros (abierta / cerrada). Cada cangrejo tiene su detalle (algas, cristal, manchas de lava, púas de hielo): el suyo
# es ser un CANGREJO VIOLINISTA — una pinza GRANDE y otra pequeña, como los de verdad, que agitan la grande al ritmo —
# con unas GAFAS DE SOL de visera metidas en el dibujo, una sonrisa, caparazón TURQUESA (la costa) y pinzas MAGENTA.
# En la espalda lleva el TRAMPOLÍN del juego. Rejilla 18x10 (el ancho del Crabby helado) a escala 10 en el juego.
#   · body-Sheet.png     3 cuadros 18x10: el cuerpo con las patas del Crabby de la costa (sus 3 cuadros de andar)
#   · bigclaw-Sheet.png  2 cuadros 12x9: la pinza grande (abierta, cerrada), dibujada mirando a la IZQUIERDA
#   · claw-Sheet.png     2 cuadros 7x6: la pinza pequeña (abierta, cerrada)
#   · tramp.png          el trampolín de la espalda (cojín y muelle de assets/images/mechanisms/trampoline/normal.png)
#   · note-Sheet.png     la NOTA (corchea) que dispara: 4 colores × 2 cuadros 9x10 (la banderita se mueve)
#   · gold-Sheet.png     la NOTA DORADA (2 cuadros 9x10, con destellos): devuélvesela y le explota el trampolín
#   · speaker-Sheet.png  bafle 18x26 (normal, membrana fuera en el bombo) · discoball-Sheet.png 4 cuadros 12x12
#   · glowstick-Sheet.png barras de luz 3x8 del público (4 colores) · panel-Sheet.png baldosas 32x3 de la pista de
#                        baile (apagada + 4 colores)
#   · wave-Sheet.png     la ONDA DE ARENA del suelo: 3 cuadros 12x9 (la forma de la onda del Saltarín Gigante,
#                        make_giant_hopper.py, con los colores de la playa)
#
#   python tools/art/bosses/make_groove_crab.py   → assets/images/bosses/groovecrab/ (+ vista previa)
#   … --gif                                       → FlappyMonster_pruebas/jefes/groove/maqueta.gif (sus animaciones)
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'bosses', 'groovecrab')
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/jefes/groove'
sys.path.insert(0, HERE)
from make_giant_hopper import FRAMES as WAVE_SHAPES   # noqa: E402


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


CLEAR = (0, 0, 0, 0)


def grid(rows, pal):
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), CLEAR)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c in pal: im.putpixel((x, y), pal[c])
    return im


def strip(frames):
    w, h = frames[0].width, frames[0].height
    im = Image.new('RGBA', (w * len(frames), h), CLEAR)
    for i, f in enumerate(frames): im.paste(f, (i * w, 0))
    return im


# ── Paleta (el contorno de todos los cangrejos; turquesa de la costa; magenta; gafas) ──
PAL = {
    'o': hx('#1b1a2a'),            # contorno (el de todos los cangrejos)
    'h': hx('#b8fff4'),            # brillo del caparazón
    'T': hx('#38d6c4'),            # turquesa
    't': hx('#1f9a9a'),            # turquesa oscuro (sombra)
    'k': hx('#14142a'),            # cristal de las gafas
    'g': hx('#8fe8ff'),            # brillo de las gafas
    'm': hx('#ff4fa3'),            # magenta (pinzas)
    'n': hx('#b0246e'),            # magenta oscuro
    'p': hx('#ffc2e0'),            # brillo de las pinzas
    'w': hx('#ffffff'),            # dientes de la sonrisa
}

# ── El cuerpo: caparazón en cúpula, gafas de visera, sonrisa; patas como las del Crabby (3 cuadros) ──
SHELL = ["......oooooo......",
         "...ooothhTTTooo...",
         "..otThhTTTTTTTto..",
         ".oTkgkkkkkkgkkkto.",
         ".oTkkkkkTTkkkkkto.",
         "..otTTowwwwoTTto..",
         "...oooooooooooo..."]


def crabby_legs():
    """Las PATAS del Crabby de la costa (filas 5-8 de crab1-3: sus 3 cuadros de andar), la mitad izquierda
    ensanchada un píxel y reflejada: anda igual que la familia"""
    out = []
    for f in ('crab1.png', 'crab2.png', 'crab3.png'):
        im = Image.open(os.path.join(ROOT, 'assets', 'images', 'enemies', 'crabby', f)).convert('RGBA')
        rows = []
        for y in range(6, 9):
            left = '.' + ''.join('o' if im.getpixel((x, y))[3] > 0 else '.' for x in range(8))
            rows.append(left + left[::-1])
        out.append(rows)
    return out


# ── Pinzas (mirando a la IZQUIERDA, como las del Mega Crabby; la derecha se dibuja volteada) ──
BIG = [["..oooooo....",
        ".ommmmmmoo..",
        "omppmmmmmmo.",
        "ommmoooooooo",
        "omo.........",
        "ommooooooo..",
        ".ommmmmmmmo.",
        "..onnnnnnno.",
        "...ooooooo.."],
       ["............",
        "..ooooooo...",
        ".omppmmmmoo.",
        "ommmmmmmmmmo",
        "ommmmmmmmmno",
        "ommnnnnnnnno",
        ".onnnnnnnno.",
        "..oooooooo..",
        "............"]]
SMALL = [["..oooo.",
          ".ompmmo",
          "omoooo.",
          "omo....",
          "ommmmo.",
          ".ooooo."],
         [".......",
          "..oooo.",
          ".ompmmo",
          "ommmmmo",
          "onnnnno",
          ".ooooo."]]

# ── La nota (corchea), en 4 colores (relleno, brillo) ──
NOTE = [["....oo...",
         "....oPoo.",
         "....oPPPo",
         "....oPooo",
         "....oPo..",
         "....oPo..",
         ".oooPPo..",
         "ohPPPPo..",
         "oPPPPo...",
         ".oooo...."],
        ["....oo...",
         "....oPo..",
         "....oPPo.",
         "....oPPPo",
         "....oPoPo",
         "....oPo..",
         ".oooPPo..",
         "ohPPPPo..",
         "oPPPPo...",
         ".oooo...."]]
NOTE_COLORS = [('#ff4fa3', '#ffc2e0'), ('#3fd8ff', '#c8f4ff'), ('#ffd23f', '#fff3b8'), ('#5cf07a', '#d0ffd8')]

# ── La onda de arena ──
WAVE_COL = {'o': hx('#5a3e1c'), 'd': hx('#b07c3a'), 'r': hx('#e2b45c'), 'l': hx('#f6dc98'), 'p': hx('#ffffff')}


def tramp():
    src = Image.open(os.path.join(ROOT, 'assets', 'images', 'mechanisms', 'trampoline', 'normal.png')).convert('RGBA')
    return src.crop((0, 4, 16, 13))                               # (el cojín y el muelle: sin la base)


# ── El ESCENARIO (0.5.47, el usuario: más epicidad; rave + concierto en la playa al atardecer) ──
GOLD = [["....oo...",
         "....oPoo.",
         "....oPPPo",
         "....oPooo",
         "....oPo..",
         "....oPo..",
         ".oooPPo..",
         "ohPPPPo..",
         "oPPPPo...",
         ".oooo...."],
        ["....oo..w",
         "....oPo..",
         "....oPPo.",
         "....oPPPo",
         "....oPoPo",
         "w...oPo..",
         ".oooPPo..",
         "ohPPPPo..",
         "oPPPPo...",
         ".oooo...."]]
P_GOLD = {'o': hx('#6a4a08'), 'P': hx('#ffd23f'), 'h': hx('#fff8c0'), 'w': hx('#ffffff')}


def speaker(pump):
    """Bafle 18x26: caja oscura, tweeter arriba y altavoz grande abajo (en el bombo, la membrana sale un píxel)"""
    w, h = 18, 26
    im = Image.new('RGBA', (w, h), CLEAR)
    px = im.load()
    for y in range(h):
        for x in range(w):
            edge = x in (0, w - 1) or y in (0, h - 1)
            px[x, y] = hx('#0c0b16') if edge else hx('#24223a')
    def disc(cx, cy, r, col):
        for y in range(h):
            for x in range(w):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r: px[x, y] = col
    disc(9, 5, 3.0, hx('#6a6890')); disc(9, 5, 2.0, hx('#3a3956')); disc(9, 5, 0.8, hx('#b0aed0'))
    big = 6.5 + (0.6 if pump else 0)
    disc(9, 17.5, big + 1, hx('#6a6890')); disc(9, 17.5, big, hx('#3a3956')); disc(9, 17.5, 2.2 + (0.5 if pump else 0), hx('#8a88b0'))
    return im


def discoball(f):
    """Bola de discoteca 12x12, 4 cuadros (los espejitos giran)"""
    im = Image.new('RGBA', (12, 12), CLEAR)
    px = im.load()
    for y in range(12):
        for x in range(12):
            d = (x + 0.5 - 6) ** 2 + (y + 0.5 - 6) ** 2
            if d <= 30:
                edge = d > 22
                lit = ((x + f) // 2 + y // 2) % 2 == 0
                px[x, y] = hx('#3a3a50') if edge else (hx('#e8ecff') if lit else hx('#8890b8'))
    px[3 + f % 3, 3] = hx('#ffffff')
    return im


def glowstick(col):
    """Barra de luz 3x8 (núcleo claro)"""
    c = hx(col)
    im = Image.new('RGBA', (3, 8), CLEAR)
    for y in range(8):
        im.putpixel((0, y), c); im.putpixel((2, y), c); im.putpixel((1, y), hx('#ffffff') if y < 6 else c)
    return im


def panel(col):
    """Baldosa de la pista de baile: 32x3 (2 casillas a ×4) encima del suelo; apagada o de un color"""
    im = Image.new('RGBA', (32, 3), CLEAR)
    for y in range(3):
        for x in range(32):
            edge = x in (0, 31) or y == 2
            im.putpixel((x, y), hx('#2a1a10') if edge else (hx(col) if col else hx('#5a4026')))
    return im


BEAT_COLS = ['#ff4fa3', '#3fd8ff', '#ffd23f', '#5cf07a']


def main():
    os.makedirs(OUT, exist_ok=True)
    notes = []
    for fill, hi in NOTE_COLORS:
        pal = {'o': PAL['o'], 'P': hx(fill), 'h': hx(hi)}
        notes += [grid(f, pal) for f in NOTE]
    out = {
        'body-Sheet.png': strip([grid(SHELL + l, PAL) for l in crabby_legs()]),
        'bigclaw-Sheet.png': strip([grid(c, PAL) for c in BIG]),
        'claw-Sheet.png': strip([grid(c, PAL) for c in SMALL]),
        'tramp.png': tramp(),
        'note-Sheet.png': strip(notes),
        'wave-Sheet.png': strip([grid(f, WAVE_COL) for f in WAVE_SHAPES]),
        'gold-Sheet.png': strip([grid(f, P_GOLD) for f in GOLD]),
        'speaker-Sheet.png': strip([speaker(False), speaker(True)]),
        'discoball-Sheet.png': strip([discoball(f) for f in range(4)]),
        'glowstick-Sheet.png': strip([glowstick(c) for c in BEAT_COLS]),
        'panel-Sheet.png': strip([panel(None)] + [panel(c) for c in BEAT_COLS]),
    }
    for name, im in out.items():
        im.save(os.path.join(OUT, name))
        print('  escrito', os.path.join(OUT, name), im.size)
    for old in ('shades.png',):                                    # (la primera prueba: gafas encima del Mega Crabby)
        p = os.path.join(OUT, old)
        if os.path.exists(p): os.remove(p)
    preview(out)


def preview(out):
    """El cangrejo montado (trampolín detrás, cuerpo, pinza grande a un lado y pequeña al otro), sus 3 cuadros,
    la pinza cerrada, las notas y la onda, a ×8, junto a los otros cangrejos del juego a la misma escala"""
    os.makedirs(PREVIEW, exist_ok=True)
    k = 8
    body = out['body-Sheet.png']
    big, small = out['bigclaw-Sheet.png'], out['claw-Sheet.png']
    tr = out['tramp.png']

    def crab(fr, bigf, smallf, raise_big=0):
        im = Image.new('RGBA', (40, 24), CLEAR)
        ox, oy = 11, 24 - 10                                       # (el cuerpo: 18x10 con los pies abajo)
        im.alpha_composite(tr, (ox + 1, oy - 9 + 1))
        im.alpha_composite(body.crop((fr * 18, 0, fr * 18 + 18, 10)), (ox, oy))
        b = big.crop((bigf * 12, 0, bigf * 12 + 12, 9))
        im.alpha_composite(b, (ox - 10, oy + 1 - raise_big))
        s = small.crop((smallf * 7, 0, smallf * 7 + 7, 6)).transpose(Image.FLIP_LEFT_RIGHT)
        im.alpha_composite(s, (ox + 17, oy + 3))
        return im

    W, H = 3 * 40 + 40 + 60, 60
    pv = Image.new('RGBA', (W * k, H * k), hx('#7ec8ff'))
    for i in range(3): pv.alpha_composite(crab(i, 0, 0).resize((40 * k, 24 * k), Image.NEAREST), (i * 40 * k, 0))
    pv.alpha_composite(crab(0, 1, 1, 4).resize((40 * k, 24 * k), Image.NEAREST), (3 * 40 * k, 0))
    n = out['note-Sheet.png']
    pv.alpha_composite(n.resize((n.width * k // 2, n.height * k // 2), Image.NEAREST), (0, 26 * k))
    wv = out['wave-Sheet.png']
    pv.alpha_composite(wv.resize((wv.width * k // 2, wv.height * k // 2), Image.NEAREST), (40 * k, 26 * k))
    # los otros cangrejos, para comparar
    x = 0
    for d in ('crabby', 'crabby_river', 'crabby_cave', 'crabby_fortress', 'crabby_ice', 'crabby_lava'):
        im = Image.open(os.path.join(ROOT, 'assets', 'images', 'enemies', d, 'crab1.png')).convert('RGBA')
        pv.alpha_composite(im.resize((im.width * k // 2, im.height * k // 2), Image.NEAREST), (x * k, 38 * k))
        x += im.width // 2 + 3
    pv.save(os.path.join(PREVIEW, 'vista_previa.png'))
    print('  vista previa', os.path.join(PREVIEW, 'vista_previa.png'))


# ── Maqueta animada (GIF) — el usuario: "un mockup para verlo completo y sus animaciones" ──
#   python tools/art/bosses/make_groove_crab.py --gif   → FlappyMonster_pruebas/jefes/groove/maqueta.gif
def mockup_gif():
    import math
    from PIL import ImageDraw
    P = 6                                         # píxeles de pantalla por píxel de arte (la maqueta, no el juego)
    W, H = 140, 74                                # (en píxeles de arte)
    FLOOR = 62
    FPS, BEAT = 25, 0.4                           # 150 BPM
    body = Image.open(os.path.join(OUT, 'body-Sheet.png')).convert('RGBA')
    big = Image.open(os.path.join(OUT, 'bigclaw-Sheet.png')).convert('RGBA')
    small = Image.open(os.path.join(OUT, 'claw-Sheet.png')).convert('RGBA')
    tr = Image.open(os.path.join(OUT, 'tramp.png')).convert('RGBA')
    notes = Image.open(os.path.join(OUT, 'note-Sheet.png')).convert('RGBA')
    wave = Image.open(os.path.join(OUT, 'wave-Sheet.png')).convert('RGBA')
    fr = lambda im, i, w: im.crop((i * w, 0, i * w + w, im.height))

    def crab(leg, tk, bigf, smallf, big_dy=0, big_dx=0, small_dy=0, glint=False):
        """El cangrejo montado en una capa 44x30 con los pies abajo en el centro: trampolín (tk = su altura, 0..1.2),
        cuerpo, pinza grande a la izquierda y pequeña a la derecha"""
        im = Image.new('RGBA', (44, 30), CLEAR)
        ox, oy = 13, 30 - 10
        th = max(1, round(9 * tk))
        im.alpha_composite(tr.resize((16, th), Image.NEAREST), (ox + 1, oy - th + 1))
        b = fr(body, leg, 18).copy()
        if glint:                                                  # (el brillo de las gafas barre el cristal)
            d = ImageDraw.Draw(b)
            for x in (5, 12): d.point((x, 3), fill=(255, 255, 255, 255))
        im.alpha_composite(b, (ox, oy))
        im.alpha_composite(fr(big, bigf, 12), (ox - 10 + big_dx, oy + 1 + big_dy))
        im.alpha_composite(fr(small, smallf, 7).transpose(Image.FLIP_LEFT_RIGHT), (ox + 17, oy + 3 + small_dy))
        return im

    # guion: (desde s, hasta s, qué)
    acts = [(0.0, 3.2, 'groove'), (3.2, 5.6, 'walk'), (5.6, 8.8, 'snap'), (8.8, 11.2, 'hop'), (11.2, 14.4, 'pose'),
            (14.4, 16.0, 'bounce')]
    labels = {'groove': 'baila al ritmo', 'walk': 'anda', 'snap': 'notas en los pops', 'hop': 'salta: cae en el bombo',
              'pose': 'POSE: vulnerable', 'bounce': 'trampolin: te lanza'}
    frames = []
    shots, waves = [], []
    x = 78.0
    hop_from = hop_to = 78.0
    for i in range(int(16.0 * FPS)):
        t = i / FPS
        act, t0 = next((a, s0) for s0, s1, a in acts if s0 <= t < s1)
        lt = t - t0
        beat = (t % BEAT) / BEAT
        on = beat < 0.25
        leg, tk, bigf, smallf, bdy, bdx, sdy = (int(t / BEAT) % 2) * 2, 1.0, 0, 0, 0, 0, 0
        sx, sy, lift, shake, glint = 1.0, 1.0, 0, 0, False
        mark = None
        if act == 'groove':
            sy = 0.9 if on else 1.0; sx = 1.06 if on else 1.0
            bigf = 1 if on else 0; bdy = -2 if int(t / BEAT) % 2 else 0
            sdy = 0 if int(t / BEAT) % 2 else -1
            tk = 0.85 if on else 1.0
        elif act == 'walk':
            x += (1 if lt < 1.2 else -1) * 20 / FPS
            leg = int(t * 8) % 3
            sy = 1 - 0.03 * abs(math.sin(t * 25))
        elif act == 'snap':
            bdy, bdx = -5, -2                                          # la pinza grande en alto
            step = int(lt / (BEAT / 4))
            snap = lt > BEAT and step % 4 in (0, 2) and (lt % (BEAT / 2)) < 0.08
            bigf = 1 if snap else 0
            if snap and (not shots or t - shots[-1]['t0'] > 0.15):
                shots.append({'t0': t, 'x': x - 26, 'y': FLOOR - 22, 'c': len(shots) % 4})
            tk = 1.0
        elif act == 'hop':
            if lt < 0.8:                                               # agachado: la diana en el suelo
                k = min(1, lt / 0.3)
                sy, sx, tk = 1 - 0.15 * k, 1 + 0.1 * k, 0.7
                hop_from, hop_to = x, 52.0
                mark = hop_to
            elif lt < 1.6:                                             # en el aire (aterriza en el tiempo fuerte)
                u = (lt - 0.8) / 0.8
                x = hop_from + (hop_to - hop_from) * u
                lift = 22 * 4 * u * (1 - u)
                sy, sx, tk, leg = 1.1, 0.92, 1.2, 1
                bdy, sdy = 2, 2
            else:
                if not waves or waves[-1]['t0'] < t0 + 1.5:
                    for d in (-1, 1): waves.append({'t0': t, 'x': x + d * 16, 'd': d})
                k = max(0, 1 - (lt - 1.6) / 0.25)
                sy, sx, shake = 1 - 0.2 * k, 1 + 0.15 * k, k * 2
        elif act == 'pose':
            k = min(1, lt / 0.15)
            tk = 1 - 0.85 * k                                          # el trampolín se esconde
            bigf, bdy, bdx = 0, -9 * k, 2 * k                          # ¡la pinza grande arriba, abierta!
            sdy = -3 * k
            sy, sx = 1 + 0.06 * k, 1 - 0.03 * k
            glint = int(t * 6) % 2 == 0
            if lt > 2.4:                                               # un pisotón: se encoge y vuelve a sacar el trampolín
                q = min(1, (lt - 2.4) / 0.3)
                tk, sy, sx, bdy = 0.15 + q, 1 - 0.18 * (1 - q), 1 + 0.12 * (1 - q), -9 * (1 - q)
        elif act == 'bounce':
            tk = 1 + 0.35 * max(0, math.sin(min(1, lt / 0.5) * math.pi * 3) * (1 - lt / 1.6))
        img = crab(leg, tk, bigf, smallf, round(bdy), round(bdx), round(sdy), glint)
        cw, ch = max(1, round(img.width * sx)), max(1, round(img.height * sy))
        img = img.resize((cw, ch), Image.NEAREST)
        canvas = Image.new('RGBA', (W, H), hx('#7ec8ff'))
        d = ImageDraw.Draw(canvas)
        d.rectangle((0, FLOOR, W, H), fill=hx('#e2b45c'))
        d.rectangle((0, FLOOR, W, FLOOR), fill=hx('#5a3e1c'))
        for sxx in range(0, W, 9): d.point((sxx + (sxx * 7) % 5, FLOOR + 4 + (sxx * 3) % 7), fill=hx('#b07c3a'))
        # los focos del escenario, que cambian de color en cada tiempo
        cols = [(255, 79, 163), (63, 216, 255), (255, 210, 63), (92, 240, 122)]
        c = cols[int(t / BEAT) % 4]
        ov = Image.new('RGBA', (W, H), CLEAR)
        od = ImageDraw.Draw(ov)
        od.polygon([(8, 0), (18, 0), (int(x) + 14, FLOOR), (int(x) - 14, FLOOR)], fill=c[:3] + (40,))
        od.polygon([(W - 18, 0), (W - 8, 0), (int(x) + 14, FLOOR), (int(x) - 14, FLOOR)], fill=cols[(int(t / BEAT) + 2) % 4][:3] + (40,))
        canvas.alpha_composite(ov)
        if mark is not None and int(t * 10) % 2 == 0:
            d.rectangle((int(mark) - 9, FLOOR - 2, int(mark) + 9, FLOOR - 1), fill=hx('#ff3a3a'))
        for w_ in waves:
            age = t - w_['t0']
            if age < 1.4:
                wx = int(w_['x'] + w_['d'] * 50 * age)
                f = fr(wave, int(age * 12) % 3, 12)
                if w_['d'] < 0: f = f.transpose(Image.FLIP_LEFT_RIGHT)
                canvas.alpha_composite(f, (wx - 6, FLOOR - 9))
        for s_ in shots:
            age = t - s_['t0']
            if age < 2.5:
                nx = int(s_['x'] - 40 * age)
                if nx > -10:
                    canvas.alpha_composite(fr(notes, s_['c'] * 2 + int(age * 6) % 2, 9), (nx, int(s_['y'] + math.sin(age * 8) * 2)))
        if act == 'bounce':                                            # el monstruo cae en el trampolín y sale lanzado
            u = (lt % 0.8) / 0.8
            my = int(FLOOR - 30 - 12 - 40 * 4 * u * (1 - u) * 1.6)
            d.rectangle((int(x) - 4, my, int(x) + 4, my + 7), fill=hx('#6a3fa8'))
            d.rectangle((int(x) - 2, my + 2, int(x) - 1, my + 3), fill=hx('#ffffff'))
            d.rectangle((int(x) + 1, my + 2, int(x) + 2, my + 3), fill=hx('#ffffff'))
        px = int(x - cw / 2 + (shake if int(t * 30) % 2 else -shake))
        canvas.alpha_composite(img, (px, int(FLOOR - ch - lift)))
        d.text((3, 2), labels[act], fill=(20, 20, 40, 255))
        frames.append(canvas.resize((W * P, H * P), Image.NEAREST).convert('P', palette=Image.ADAPTIVE, colors=128))
    path = os.path.join(PREVIEW, 'maqueta.gif')
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=int(1000 / FPS), loop=0, disposal=2)
    print('  maqueta', path, len(frames), 'cuadros')


if __name__ == '__main__':
    if '--gif' in sys.argv: mockup_gif()
    else: main()
