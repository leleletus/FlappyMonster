#!/usr/bin/env python3
# LA VENTISCA y EL GÉISER (peligros nuevos pedidos por el usuario en 0.5.67 — diseño en curso).
#   VENTISCA: viento al azar que, AVISANDO antes, empuja a jugadores, enemigos y todo lo que tenga física hacia un lado,
#   el otro, arriba o abajo (primero en torre_viento; reutilizable en otros niveles). Arte: las RACHAS (líneas que cruzan
#   la pantalla, 32x8, 3 cuadros, con lo que arrastra cada isla) y el AVISO (flecha 16x16, 2 cuadros, que parpadea en el
#   borde de la pantalla por donde va a entrar el viento). El juego las gira para arriba / abajo.
#   GÉISER: un respiradero en el suelo que borbotea (aviso) y lanza una COLUMNA que empuja hacia arriba todo lo que tenga
#   física (jugadores, enemigos, cajas, bombas). Por isla: pradera y costa AGUA · nieve agua que SE CONGELA en un pilar de
#   hielo que sirve de plataforma un rato y luego se rompe · fortaleza VAPOR · cueva vapor que BRILLA (da algo de luz) ·
#   volcán HUMO volcánico con ascuas. Arte: respiradero 16x8 · aviso 3 cuadros de 16x8 · columna 16x16 (3 cuadros, se
#   repite en vertical) · penacho de arriba 16x16 (3 cuadros) · nieve: pilar de hielo 16x16 + su remate 16x8 + 2 grietas.
#   python3 tools/art/world/make_wind_geyser.py            → vistas previas en FlappyMonster_pruebas/nuevos/ventisca_geiser/
#   python3 tools/art/world/make_wind_geyser.py --apply    → assets/images/mechanisms/wind/ y …/geyser/<isla>-*.png
import os, sys, math
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'nuevos', 'ventisca_geiser')
OUT_W = os.path.join(ROOT, 'assets', 'images', 'mechanisms', 'wind')
OUT_G = os.path.join(ROOT, 'assets', 'images', 'mechanisms', 'geyser')


def rgb(h, a=255): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


# ── LA VENTISCA ──────────────────────────────────────────────────────────────────────────────────────────────────
WIND_CARRY = {   # lo que arrastra cada isla (copos en la torre de nieve)
    'pradera': ('7cc850', '3e8c3c'), 'costa': ('f0d088', 'fff4c0'), 'fortaleza': ('5c5c6c', '8a8a9a'),
    'nieve': ('ffffff', 'd8f0ff'), 'cueva': ('b4f4ff', 'e8fcff'), 'volcan': ('ff8a28', '5a4440'),
}
BG = {'pradera': '8cc8f0', 'costa': '9cdcf0', 'fortaleza': '8a8ea8', 'nieve': '3a4a6a', 'cueva': '3a3450', 'volcan': '6a2c2c'}


def gusts(isle):
    """3 cuadros de 32x8: rachas blancas semitransparentes que avanzan a la derecha, con lo que arrastran"""
    a, b = WIND_CARRY[isle]
    out = Image.new('RGBA', (96, 8))
    for f in range(3):
        im = Image.new('RGBA', (32, 8))
        for row, x0, ln in ((1, 4 * f, 14), (4, 4 * f + 13, 10), (6, 4 * f + 22, 7)):
            for d in range(ln):
                x = (x0 + d) % 32
                im.putpixel((x, row), rgb('ffffff', 90 + int(140 * d / ln)))           # (la punta, más opaca)
        for k, (x, y) in enumerate(((7 + 6 * f, 3), (19 + 6 * f, 5), (27 + 6 * f, 2))):
            im.putpixel((x % 32, y), rgb(a if k % 2 == 0 else b))
            if isle == 'nieve': im.putpixel(((x + 1) % 32, y), rgb(b, 180))
        out.paste(im, (f * 32, 0))
    return out


def warn_arrow():
    """El AVISO: flecha gruesa hacia la derecha con contorno oscuro (2 cuadros: encendida / apagada para parpadear)"""
    shape = ["................",
             ".........o......",
             ".........oo.....",
             ".........oyo....",
             "..oooooooowyo...",
             "..owwwwwwwwwyo..",
             "..owyyyyyyyyyyo.",
             "..owyyyyyyyyyyyo",
             "..owyyyyyyyyyyo.",
             "..owwwwwwwwwyo..",
             "..oooooooowyo...",
             ".........oyo....",
             ".........oo.....",
             ".........o......",
             "................",
             "................"]
    out = Image.new('RGBA', (32, 16))
    for f, pal in enumerate(({'o': '2a2a3a', 'w': 'ffffff', 'y': '7ad4ff'}, {'o': '2a2a3a', 'w': 'c8e8ff', 'y': '3c8ccc'})):
        for y, r in enumerate(shape):
            for x, c in enumerate(r):
                if c != '.': out.putpixel((f * 16 + x, y), rgb(pal[c], 255 if f == 0 else 170))
    return out


# ── EL GÉISER ────────────────────────────────────────────────────────────────────────────────────────────────────
# (borde, roca 1, roca 2, chorro claro, chorro, chorro oscuro, acento, alfa del chorro)
GEY = {
    # (agua de un azul fuerte y con su borde oscuro opaco: sobre el cielo claro de la pradera y la costa no se veía)
    'pradera':   dict(o='3a2a1c', r='7a6a58', R='a8987c', j='ffffff', J='3c98e0', k='1c5aa8', x='7cc850', a=235, kind='agua'),
    'costa':     dict(o='4c3a2a', r='c8a070', R='f0d088', j='ffffff', J='2cb0c8', k='14708a', x='e85c5c', a=235, kind='agua'),
    'nieve':     dict(o='3c6a9c', r='9cbcdc', R='e4f0ff', j='ffffff', J='a8dcf4', k='5c9ccc', x='ffffff', a=225, kind='hielo'),
    'fortaleza': dict(o='242830', r='5c626e', R='8a909c', j='ffffff', J='dcdce4', k='a8a8b4', x='c84a2a', a=160, kind='vapor'),
    'cueva':     dict(o='2a2438', r='4a4060', R='6c6088', j='e8fcff', J='9ef0ff', k='4ac4d4', x='b4f4ff', a=170, kind='luz'),
    'volcan':    dict(o='140e10', r='3a2a28', R='5a4440', j='9a8a86', J='6a5c5a', k='3e3434', x='ff8a28', a=210, kind='humo'),
}


def vent(isle):
    """El RESPIRADERO (16x8): una boca en el suelo, de lo que sea cada isla"""
    p = GEY[isle]
    im = Image.new('RGBA', (16, 8))
    px = im.load()
    for x in range(16):
        top = 3 if 3 <= x <= 12 else 5
        for y in range(top, 8): px[x, y] = rgb(p['R'] if y == top else p['r'])
        px[x, top] = rgb(p['o'])
    for x in range(5, 11): px[x, 4] = rgb(p['o']); px[x, 5] = rgb('101018')               # el agujero
    if isle == 'fortaleza':                                                                  # rejilla de hierro
        for x in (5, 7, 9): px[x, 4] = rgb(p['R'])
    if isle == 'pradera': px[2, 4] = rgb(p['x']); px[13, 4] = rgb(p['x']); px[2, 3] = rgb(p['x'])
    if isle == 'costa': px[13, 4] = rgb(p['x']); px[3, 4] = rgb('ffffff')                  # (un cangrejito / una concha)
    if isle in ('cueva', 'volcan'): px[4, 4] = rgb(p['x']); px[11, 4] = rgb(p['x'])
    return im


def warning(isle):
    """El AVISO (3 cuadros de 16x8): burbujas / bocanadas que salen del agujero, cada vez más"""
    p = GEY[isle]
    out = Image.new('RGBA', (48, 8))
    for f in range(3):
        im = Image.new('RGBA', (16, 8))
        for k in range(f + 2):
            x = 6 + (k * 3 + f) % 5
            y = 4 - (k + f) % 4
            im.putpixel((x, y), rgb(p['j'], 255))
            if k % 2: im.putpixel((x + 1, y + 1), rgb(p['J'], 220))
        out.paste(im, (f * 16, 0))
    return out


def column(isle, f):
    """Un tramo de la COLUMNA (16x16, se repite): chorro con franjas que suben (cuadro f) — semitransparente"""
    p = GEY[isle]
    im = Image.new('RGBA', (16, 16))
    for y in range(16):
        wob = int(round(math.sin((y + f * 5) * 0.7) * 1))
        for x in range(3 + wob, 13 + wob):
            u = (x - 3 - wob) / 10
            c = p['J']
            if u < 0.2 or u > 0.85: c = p['k']
            if ((y + f * 5) % 6 < 2 and 0.3 < u < 0.7): c = p['j']
            a = p['a'] if 0.1 < u < 0.9 else int(p['a'] * 0.6)
            if p['kind'] == 'agua' and (x == 3 + wob or x == 12 + wob): c, a = p['k'], 255     # (el borde, opaco)
            im.putpixel((x, y), rgb(c, a))
    if p['kind'] == 'humo':                                                                  # ascuas en el humo
        for x, y in ((5, (f * 5 + 3) % 16), (10, (f * 5 + 11) % 16)): im.putpixel((x, y), rgb(p['x']))
    if p['kind'] == 'luz':
        for x, y in ((7, (f * 5 + 2) % 16), (9, (f * 5 + 9) % 16)): im.putpixel((x, y), rgb('ffffff'))
    return im


def crest(isle, f):
    """El PENACHO de arriba (16x16): salpicaduras / volutas que se abren"""
    p = GEY[isle]
    im = Image.new('RGBA', (16, 16))
    for k in range(9):
        ang = math.pi * (0.1 + 0.8 * k / 8)
        r = 3 + f * 2 + (k % 3)
        x = int(8 - math.cos(ang) * r * 1.1)
        y = int(14 - math.sin(ang) * r)
        for dx, dy in ((0, 0), (1, 0), (0, 1)):
            if 0 <= x + dx < 16 and 0 <= y + dy < 16:
                im.putpixel((x + dx, y + dy), rgb(p['j'] if k % 2 else p['J'], p['a'] if p['kind'] != 'agua' else 255))
    for y in range(10, 16):
        for x in range(5, 11): im.putpixel((x, y), rgb(p['J'], p['a']))
    if p['kind'] == 'humo': im.putpixel((5 + f * 2, 3 + f), rgb(p['x']))
    return im


def ice(isle='nieve'):
    """NIEVE: el chorro se CONGELA — pilar de hielo 16x16 (tramo), remate 16x8 (donde se está de pie), 2 grietas 16x16"""
    p = GEY[isle]
    col = Image.new('RGBA', (16, 16))
    for y in range(16):
        for x in range(3, 13):
            c = p['J'] if 4 < x < 11 else p['k']
            if x in (5, 6) and y % 5 != 4: c = 'ffffff'
            col.putpixel((x, y), rgb(c))
        col.putpixel((3, y), rgb(p['o'])); col.putpixel((12, y), rgb(p['o']))
    top = Image.new('RGBA', (16, 8))
    for x in range(1, 15):
        for y in range(2, 8): top.putpixel((x, y), rgb(p['J'] if y > 2 else 'ffffff'))
        top.putpixel((x, 1), rgb(p['o']))
    for x in (2, 6, 10, 13): top.putpixel((x, 0), rgb('ffffff'))
    cracks = Image.new('RGBA', (32, 16))
    for f, pts in enumerate((((6, 3), (7, 4), (7, 5), (8, 6), (8, 7)), ((6, 3), (7, 4), (7, 5), (8, 6), (8, 7), (9, 8), (8, 9), (6, 10), (5, 11), (9, 12), (10, 13)))):
        for x, y in pts: cracks.putpixel((f * 16 + x, y), rgb(p['o']))
    return col, top, cracks


# ── VISTAS PREVIAS ─────────────────────────────────────────────────────────────────────────────────────────────
def preview():
    S = 5
    rows = []
    for isle in GEY:
        cv = Image.new('RGBA', (150, 72), rgb(BG[isle]))
        # el géiser montado: respiradero, 3 tramos y penacho
        v = vent(isle); cv.paste(v, (8, 64), v)
        for k in range(3):
            c = column(isle, k); cv.paste(c, (8, 48 - k * 16), c)
        cr = crest(isle, 1); cv.paste(cr, (8, 0), cr)
        w = warning(isle); cv.paste(w, (30, 64), w)
        for f in range(3):
            c = column(isle, f); cv.paste(c, (84 + f * 18, 40), c)
            c2 = crest(isle, f); cv.paste(c2, (84 + f * 18, 20), c2)
        if isle == 'nieve':
            col, top, cracks = ice()
            for k in range(2): cv.paste(col, (40, 48 - k * 16), col)
            cv.paste(top, (40, 24), top)
            for f in range(2):
                cv.paste(col, (60 + f * 0, 48), col)
            cv.paste(cracks.crop((16, 0, 32, 16)), (60, 48), cracks.crop((16, 0, 32, 16)))
        g = gusts(isle); cv.paste(g, (30, 4), g)
        rows.append(cv.resize((cv.width * S, cv.height * S), Image.NEAREST))
    ar = warn_arrow()
    head = Image.new('RGBA', (150, 20), rgb('2a2a3a'))
    head.paste(ar, (4, 2), ar)
    rows.insert(0, head.resize((head.width * S, head.height * S), Image.NEAREST))
    out = Image.new('RGBA', (rows[0].width, sum(r.height for r in rows)))
    y = 0
    for r in rows: out.paste(r, (0, y)); y += r.height
    return out


def gif_geyser(isle, path):
    """Un ciclo: quieto · borbotea (aviso) · ERUPCIÓN (la columna sube) · se mantiene · baja. Nieve: se congela y se rompe"""
    S = 5
    frames, dur = [], []
    H = 6 * 16 + 8
    seq = [('idle', 0)] * 3 + [('warn', i) for i in range(6)] + [('up', i) for i in range(5)] + [('hold', i) for i in range(8)]
    seq += ([('freeze', i) for i in range(10)] + [('break', i) for i in range(3)]) if isle == 'nieve' else [('down', i) for i in range(5)]
    for n, (ph, i) in enumerate(seq):
        cv = Image.new('RGBA', (40, H), rgb(BG[isle]))
        v = vent(isle); cv.paste(v, (12, H - 8), v)
        hgt = {'idle': 0, 'warn': 0, 'up': (i + 1), 'hold': 5, 'down': 5 - (i + 1), 'freeze': 5, 'break': 5}[ph]
        if ph == 'warn':
            w = warning(isle).crop(((i % 3) * 16, 0, (i % 3 + 1) * 16, 8)); cv.paste(w, (12, H - 12), w)
        if ph in ('freeze', 'break'):
            col, top, cracks = ice()
            for k in range(hgt): cv.paste(col, (12, H - 8 - (k + 1) * 16), col)
            cv.paste(top, (12, H - 8 - hgt * 16 - 6), top)
            if ph == 'break':
                cr = cracks.crop(((min(i, 1)) * 16, 0, (min(i, 1) + 1) * 16, 16))
                for k in range(hgt): cv.paste(cr, (12, H - 8 - (k + 1) * 16), cr)
        else:
            for k in range(hgt):
                c = column(isle, (n + k) % 3); cv.paste(c, (12, H - 8 - (k + 1) * 16), c)
            if hgt:
                c = crest(isle, n % 3); cv.paste(c, (12, H - 8 - hgt * 16 - 14), c)
        frames.append(cv.resize((cv.width * S, cv.height * S), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
        dur.append(120)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=dur, loop=0, disposal=2)


def gif_wind(path):
    """La ventisca en la torre: aviso (flecha que parpadea a la izquierda) y luego las rachas cruzan hacia la derecha"""
    S = 4
    frames, dur = [], []
    g = gusts('nieve'); ar = warn_arrow()
    for n in range(28):
        cv = Image.new('RGBA', (120, 64), rgb(BG['nieve']))
        if n < 10:
            a = ar.crop(((n % 2) * 16, 0, (n % 2 + 1) * 16, 16)); cv.paste(a, (2, 24), a)
        else:
            for row in range(6):
                fr = g.crop((((n + row) % 3) * 32, 0, ((n + row) % 3 + 1) * 32, 8))
                x = ((n - 10) * 12 + row * 37) % 150 - 30
                cv.paste(fr, (x, 4 + row * 10), fr)
        frames.append(cv.resize((cv.width * S, cv.height * S), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
        dur.append(100)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=dur, loop=0, disposal=2)


if __name__ == '__main__':
    if '--apply' in sys.argv:
        os.makedirs(OUT_W, exist_ok=True); os.makedirs(OUT_G, exist_ok=True)
        warn_arrow().save(os.path.join(OUT_W, 'warn-Sheet.png'))
        for isle in GEY:
            gusts(isle).save(os.path.join(OUT_W, f'{isle}-gust-Sheet.png'))
            vent(isle).save(os.path.join(OUT_G, f'{isle}-vent.png'))
            warning(isle).save(os.path.join(OUT_G, f'{isle}-warn-Sheet.png'))
            col = Image.new('RGBA', (48, 16)); cr = Image.new('RGBA', (48, 16))
            for f in range(3): col.paste(column(isle, f), (f * 16, 0)); cr.paste(crest(isle, f), (f * 16, 0))
            col.save(os.path.join(OUT_G, f'{isle}-column-Sheet.png')); cr.save(os.path.join(OUT_G, f'{isle}-crest-Sheet.png'))
        c, t, k = ice()
        c.save(os.path.join(OUT_G, 'nieve-ice.png')); t.save(os.path.join(OUT_G, 'nieve-icetop.png')); k.save(os.path.join(OUT_G, 'nieve-cracks-Sheet.png'))
        print('  ' + OUT_W + '  ·  ' + OUT_G)
    os.makedirs(PRUEBAS, exist_ok=True)
    preview().save(os.path.join(PRUEBAS, 'vista_previa.png'))
    for isle in GEY: gif_geyser(isle, os.path.join(PRUEBAS, f'geiser_{isle}.gif'))
    gif_wind(os.path.join(PRUEBAS, 'ventisca_torre.gif'))
    print('  ' + PRUEBAS)
