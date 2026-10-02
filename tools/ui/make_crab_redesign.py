#!/usr/bin/env python3
# tools/ui/make_crab_redesign.py
# Rediseño de los Crabbies, sus pinchos, los trampolines y TODOS los pinchos: la
# MISMA forma de los originales (cada píxel), mismos tamaños, al estilo nuevo:
# contorno azul muy oscuro, brillo arriba-izquierda y sombra abajo-derecha.
# Los pinchos: uno de acero en pixel art (cara clara a la izquierda, sombra a la
# derecha), ampliado al tamaño exacto de cada imagen original (crabby/Mega 38x38,
# tiles y pinchos que caen 32x32, Nave Malvada 26x27 hacia abajo, icono 8x8).
#   python3 tools/ui/make_crab_redesign.py <carpeta>   vista previa (no toca assets/)
#   python3 tools/ui/make_crab_redesign.py --apply     al juego: los originales se
#        guardan antes FUERA del repo (tools/ui/originals.py) y se parte siempre de
#        ellos (se puede repetir sin estropear nada)
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import originals   # noqa: E402
APPLY = '--apply' in sys.argv

OUT = next((a for a in sys.argv[1:] if not a.startswith('--')), '/tmp/crab_redesign')


def rgb(h): return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


PAL = {'O': rgb('1e1e2a'), 'W': rgb('f2f2f6'), 'H': rgb('ffffff'), 'S': rgb('c4c8d6'),
       'k': rgb('1e1e2a'), 'g': rgb('ffffff'), 'L': rgb('3a3a4a'),
       'Y': rgb('ffe14a'), 'y': rgb('e8a020'), 'M': rgb('b4bccc'), 'm': rgb('6e7688'), 'D': rgb('5a6178')}


def grid(rows):
    w = len(rows[0])
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        assert len(r) == w, r
        for x, ch in enumerate(r):
            if ch in PAL: im.putpixel((x, y), PAL[ch])
    return im


SRC = 'assets/images/'


def restyle(path):
    """La MISMA forma del original (cada píxel), modernizada: contorno azul muy oscuro,
    brillo arriba a la izquierda del caparazón y sombra suave a la derecha y abajo."""
    o = originals.path(path)
    src = Image.open(o if os.path.exists(o) else path).convert('RGBA')
    w, h = src.size
    white = lambda x, y: 0 <= x < w and 0 <= y < h and src.getpixel((x, y))[:3] == (255, 255, 255) and src.getpixel((x, y))[3]
    xs = [x for y in range(h) for x in range(w) if white(x, y)]
    cx = (min(xs) + max(xs)) / 2 if xs else w / 2
    # extremos de cada fila de blanco (los ojos, huecos de dentro, no cuentan)
    rows = {}
    for y in range(h):
        wx = [x for x in range(w) if white(x, y)]
        if wx: rows[y] = (min(wx), max(wx))
    ys = sorted(rows)
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            p = src.getpixel((x, y))
            if not p[3]: continue
            if not white(x, y):
                out.putpixel((x, y), PAL['O'])
                continue
            x0, x1 = rows[y]
            c = PAL['W']
            if x == x1 or (y == ys[-1] and x >= cx):
                c = PAL['S']                                  # sombra: derecha y abajo
            elif x == x0 and y == ys[0] or (y == ys[0] and x == x0 + 1):
                c = PAL['H']                                  # brillo arriba a la izquierda
            out.putpixel((x, y), c)
    return out


def crab(i): return restyle(SRC + 'crabby/crab%d.png' % (i + 1))


def hid(): return restyle(SRC + 'crabby/hid.png')


def lookin(): return restyle(SRC + 'crabby/lookin.png')


def spike_art(w, h, down=False):
    """Pincho de acero: triángulo con contorno, cara izquierda clara, centro blanco,
    derecha en sombra. w x h de arte; down = la punta hacia abajo."""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    c = w / 2
    for y in range(h):
        hw = (y + 1) / h * c
        for x in range(w):
            d = x + 0.5 - c
            if abs(d) <= hw:
                edge = abs(d) > hw - 1 or y == h - 1
                col = PAL['O'] if edge else (PAL['H'] if d < -0.5 else (PAL['W'] if d < 0.8 else PAL['S']))
                im.putpixel((x, y), col)
    return im.transpose(Image.FLIP_TOP_BOTTOM) if down else im


def spike(): return spike_art(9, 9)


def fit(art, cw, ch, k, down=False):
    """Arte ampliado x k, centrado a lo ancho y apoyado en la base (arriba si apunta
    hacia abajo), en un lienzo del tamaño del original."""
    big = art.resize((art.width * k, art.height * k), Image.NEAREST)
    out = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
    x = (cw - big.width) // 2
    y = 1 if down else ch - big.height - (1 if ch - big.height >= 2 else 0)
    out.paste(big, (x, y))
    return out


def claws():
    """Las pinzas: cada uno de los 2 cuadros (7x6) por separado."""
    o = originals.path(SRC + 'MegaCrabby/claw_left-Sheet.png')
    src = Image.open(o if os.path.exists(o) else SRC + 'MegaCrabby/claw_left-Sheet.png').convert('RGBA')
    out = Image.new('RGBA', src.size, (0, 0, 0, 0))
    tmp = '/tmp/_claw_frame.png'
    for i in range(src.width // 7):
        src.crop((i * 7, 0, i * 7 + 7, 6)).save(tmp)
        out.paste(restyle(tmp), (i * 7, 0))
    return out


def trampoline(ext):
    pad = ["..OOOOOOOOOOOO..", ".OYYYYYYYYYYYYO.", ".OyyyyyyyyyyyyO.", "..OOOOOOOOOOOO.."]
    coil = ["......OMmO......", ".....OMmmMO....."]
    base = ["...OOOOOOOOOO...", "...ODDDDDDDDO...", "...OOOOOOOOOO..."]
    if ext:
        rows = pad + [coil[i % 2] for i in range(9)] + base
    else:
        rows = ["." * 16] * 4 + pad + [coil[i % 2] for i in range(5)] + base
    return grid(rows)


def apply():
    """Al juego: cada imagen, con su original guardado fuera del repo."""
    out = {
        'crabby/crab1.png': crab(0), 'crabby/crab2.png': crab(1), 'crabby/crab3.png': crab(2),
        'crabby/hid.png': hid(), 'crabby/lookin.png': lookin(),
        'crabby/MeatCrabby.png': restyle(SRC + 'crabby/MeatCrabby.png'),
        'MegaCrabby/crab1.png': restyle(SRC + 'MegaCrabby/crab1.png'),
        'MegaCrabby/crab2.png': restyle(SRC + 'MegaCrabby/crab2.png'),
        'MegaCrabby/crab3.png': restyle(SRC + 'MegaCrabby/crab3.png'),
        # (las pinzas del Mega ya no salen de aquí: son un diseño nuevo, tools/ui/make_enemy_extras.py)
        'trampoline/normal.png': trampoline(False), 'trampoline/extended.png': trampoline(True),
        'crabby/spike.png': fit(spike_art(9, 9), 38, 38, 4),
        'MegaCrabby/spike.png': fit(spike_art(9, 9), 38, 38, 4),
        'spikes/spike.png': fit(spike_art(8, 8), 32, 32, 4),
        'bosses/miniboss1/spike.png': fit(spike_art(13, 13, True), 26, 27, 2, True),
        'items/spikefall.png': fit(spike_art(8, 4, True), 8, 8, 1, True),
    }
    for rel, im in out.items():
        path = SRC + rel
        originals.keep(path)
        im.save(path)
        print('  %-40s %dx%d' % (path, im.width, im.height))


if __name__ == '__main__':
    if APPLY:
        print('Rediseño de Crabbies, pinchos y trampolines (originales fuera del repo):')
        apply()
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    for i in range(3): crab(i).save(os.path.join(OUT, 'crab%d.png' % (i + 1)))
    hid().save(os.path.join(OUT, 'hid.png'))
    lookin().save(os.path.join(OUT, 'lookin.png'))
    spike().save(os.path.join(OUT, 'spike.png'))
    claws().save(os.path.join(OUT, 'claw_left-Sheet.png'))
    trampoline(False).save(os.path.join(OUT, 'trampoline_normal.png'))
    trampoline(True).save(os.path.join(OUT, 'trampoline_extended.png'))
    print('PRUEBA en', OUT)
