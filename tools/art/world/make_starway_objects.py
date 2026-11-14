#!/usr/bin/env python3
# tools/art/world/make_starway_objects.py
# BOCETOS de los objetos rítmicos de la Vía Estelar que eligió el usuario (docs/design/starway-rhythm-objects.md):
#   1  Plataforma metrónomo  una losa de cristal de 2 casillas que avanza UNA casilla por pulso, a golpes (4 → y 4 ←
#                            = una frase de 8 pulsos); su lámpara se enciende en cada pulso
#   2  Pinchos de palmas     una placa con pinchos de cristal que SALEN en los pulsos 2 y 4 de cada compás (la caja) y
#                            se esconden en el 1 y el 3; medio pulso antes, un destello avisa
#   4  Trampolín de compás   una estrella sobre un muelle: caer en ella EN el pulso (±0,1 s) lanza muy alto; fuera del
#                            pulso, un saltito; un aro que se cierra marca el pulso
# Solo VISTA PREVIA (nada va a assets/ hasta que el usuario lo apruebe):
#   /home/mtvemo/FlappyMonster_pruebas/via_estelar/objetos/  sprites.png · funcionamiento.png · escena.gif
#   Desde la raíz del repo:  /usr/bin/python3 tools/art/world/make_starway_objects.py
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib'))
import animjson  # noqa: E402
import os, sys
from PIL import Image, ImageDraw

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
os.chdir(REPO)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]
import make_jungle_sky as J
import make_starway_sky as SW
sys.argv = _argv

PREV = '/home/mtvemo/FlappyMonster_pruebas/via_estelar/objetos'
K = 4                                   # escala del arte (como los tiles: 16 px de arte = una casilla de 64)
rgb = J.rgb


def art(rows, pal):
    """mapa de caracteres → imagen de 1x ('.' = nada)"""
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.': im.putpixel((x, y), pal[ch])
    return im


def up(im, k=K): return im.resize((im.width * k, im.height * k), Image.NEAREST)


# ── 1 · Plataforma metrónomo (32x8: dos casillas de ancho, media de alto) ───────────────────────────────────────
# cristal lavanda (ni rosa ni cian: no se confunde con los Bloques Beep) y una lámpara dorada en medio
PLAT_PAL = {'o': rgb('3a2a6a'), 'd': rgb('6a58a8'), 'm': rgb('9484cc'), 'l': rgb('c4b8ee'), 'w': rgb('f0ecff'),
            'g': rgb('8a6a2a'), 'y': rgb('e8c050'), 'Y': rgb('fff4b0')}
PLAT = [
    'oooooooooooooooooooooooooooooooo',
    'owwllllllllllllllllllllllllllmmo',
    'owlmmmmmmmmmmmmggmmmmmmmmmmmmmdo',
    'olmmmmmmmmmmmmg{}gmmmmmmmmmmmmdo',
    'olmmmmmmmmmmmmg{}gmmmmmmmmmmmmdo',
    'ommmmmmmmmmmmmmggmmmmmmmmmmmmddo',
    'odddddddddddddddddddddddddddddddo'[:32],
    'oooooooooooooooooooooooooooooooo',
]


def platform(lit):
    rows = [r.replace('{', 'Y' if lit else 'g').replace('}', 'y' if lit else 'g') for r in PLAT]
    return art(rows, PLAT_PAL)


# ── 2 · Pinchos de palmas: LOS PINCHOS DEL JUEGO (assets/images/traps/spikes/spike.png, media casilla cada uno) que
# salen de una PLACA de una casilla (el usuario: «más parecidas a los pinchos del resto del juego»). La placa es un
# bloque sólido con dos ranuras; escondidos, asoma la punta; el aviso enciende su franja y echa chispas.
PLATE_PAL = {'o': (30, 30, 42, 255), 'k': (14, 14, 22, 255), 'd': (64, 66, 88, 255), 'm': (98, 100, 128, 255),
             'l': (146, 148, 176, 255), 'w': (196, 200, 214, 255), 'p': (96, 58, 92, 255), 'P': (255, 150, 196, 255),
             'Q': (255, 220, 236, 255)}
PLATE = [
    'oooooooooooooooo',
    'owkkkkkwwkkkkkwo',
    'olkkkkklwkkkkkdo',
    'owwwwwwwwwwwwwlo',
    'owllllllllllllmo',
    'olmmmmmmmmmmmmdo',
    'olmm{{{{{{{{mmdo',
    'olmm[[[[[[[[mmdo',
    'olmmmmmmmmmmmmdo',
    'olmmmmmmmmmmmmdo',
    'olmdmmmmmmmmdmdo',
    'olmmmmmmmmmmmmdo',
    'olmmmmmmmmmmmmdo',
    'olddddddddddddo.'[:15] + 'o',
    'oddddddddddddddo',
    'oooooooooooooooo',
]


def plate(glint):
    rows = [r.replace('{', 'Q' if glint else 'p').replace('[', 'P' if glint else 'p') for r in PLATE]
    return art(rows, PLATE_PAL)


SPIKE = Image.open(os.path.join(REPO, 'assets/images/traps/spikes/spike.png')).convert('RGBA')   # 32x32 = 8x8 de arte x4


def clap_frame(state):
    """la casilla de la placa (64x64, abajo) + lo que sale por encima (64 px): 64x128 a x4. state: down | glint | up"""
    out = Image.new('RGBA', (64, 128), (0, 0, 0, 0))
    rise = {'down': 8, 'glint': 10, 'up': 32}[state]          # px de pincho por encima de la placa
    for i in range(2):
        out.alpha_composite(SPIKE, (i * 32, 64 - rise))
    out.alpha_composite(up(plate(state == 'glint')), (0, 64))
    if state == 'glint':
        d = ImageDraw.Draw(out)
        for (x, y) in ((6, 44), (44, 40), (26, 50)):
            d.rectangle((x, y, x + 3, y + 3), fill=(255, 244, 176, 255))
            d.rectangle((x - 4, y, x - 1, y + 3), fill=(255, 200, 220, 200)); d.rectangle((x + 4, y, x + 7, y + 3), fill=(255, 200, 220, 200))
    return out


# ── 4 · Trampolín de compás (16x16: estrella dorada sobre un muelle) ────────────────────────────────────────────
STAR_PAL = {'o': rgb('6a4410'), 'd': rgb('b07a1c'), 'y': rgb('f0c040'), 'l': rgb('ffe890'), 'w': rgb('fffbe0'),
            'c': rgb('8a86b8'), 'C': rgb('c4c0e8'), 'b': rgb('3a3466'), 'B': rgb('5a5490')}
STAR_IDLE = [
    '.......oo.......',
    '......olyo......',
    '......olyo......',
    '.oooooolyyoooooo'[:16],
    'olwwllllyyyyyydo',
    '.oyllllyyyyyddo.',
    '..oyyyyyyyyddo..',
    '...oyyyyyyddo...',
    '...oyyydyyddo...',
    '..oyyddoodyddo..',
    '..oyddo..oddo...',
    '..ooo......ooo..',
    '.....cCCCCc.....',
    '......cccc......',
    '.....cCCCCc.....',
    '...BBBBBBBBBB...',
]
STAR_SQUASH = ['................'] * 3 + [
    '.......oo.......',
    '......olyo......',
    '.ooooolyyooooo..',
    'olwwlllyyyyyddo.',
    '.oyyyyyyyyyddo..',
    '..oyyydyydddo...',
    '..oyddoodyddo...',
    '..ooo.....ooo...',
    '.....cCCCCc.....',
    '.....cCCCCc.....',
    '...BBBBBBBBBB...',
] + ['................'] * 2
STAR_SQUASH = STAR_SQUASH[:16]


def ring(size, r, col, w=2):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = size // 2
    d.ellipse((c - r, c - r, c + r, c + r), outline=col, width=w)
    return im


def ring_art(r):
    """el aro que se cierra hacia el pulso (24x24 de arte, se dibuja x4 centrado en la estrella): 1 px, dorado claro"""
    im = Image.new('RGBA', (24, 24), (0, 0, 0, 0))
    c = 11.5
    for y in range(24):
        for x in range(24):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if abs(d - r) < 0.5: im.putpixel((x, y), rgb('fff0a0') if r <= 4 else rgb('e8c870'))
    return im


# ── Hojas ───────────────────────────────────────────────────────────────────────────────────────────────────────
BG = rgb('1c1a34')


def font(): return None


def label(im, text, xy, size=12, col=(255, 255, 255, 255)): J.label(im, text, xy, size, col)


def sprites_sheet():
    out = Image.new('RGBA', (1100, 600), BG)
    label(out, 'Objetos ritmicos de la Via Estelar - sprites a x4 (como en el juego) y x8', (20, 14), 12)
    y = 50
    label(out, '1  Plataforma metronomo (2 casillas)   apagada / lampara en el pulso', (20, y), 10)
    out.alpha_composite(up(platform(False)), (20, y + 24)); out.alpha_composite(up(platform(True)), (180, y + 24))
    out.alpha_composite(up(platform(True), 8), (360, y + 20))
    y = 170
    label(out, '2  Pinchos de palmas   escondidos / aviso (medio pulso antes) / fuera (pulsos 2 y 4)', (20, y), 10)
    for i, st_ in enumerate(('down', 'glint', 'up')):
        im = clap_frame(st_)
        out.alpha_composite(im, (20 + i * 90, y + 10))
        out.alpha_composite(im.resize((128, 256), Image.NEAREST).crop((0, 64, 128, 256)), (320 + i * 150, y + 6))
    y = 380
    label(out, '4  Trampolin de compas   quieto / aplastado / el aro que se cierra hacia el pulso / lanzado EN el pulso', (20, y), 10)
    st, sq = art(STAR_IDLE, STAR_PAL), art(STAR_SQUASH, STAR_PAL)
    out.alpha_composite(up(st), (20, y + 30)); out.alpha_composite(up(sq), (110, y + 30))
    for i, r in enumerate((30, 22, 14)):
        f = Image.new('RGBA', (64, 64)); f.alpha_composite(up(st))
        rg = ring(64, r, (255, 240, 160, 255 if i == 2 else 150)); f.alpha_composite(rg)
        out.alpha_composite(f, (200 + i * 80, y + 30))
    f = up(st).copy()
    for (sx, sy) in ((4, 4), (52, 8), (10, 50), (56, 46), (30, 0)):
        ImageDraw.Draw(f).rectangle((sx, sy, sx + 3, sy + 3), fill=rgb('fff4b0'))
    out.alpha_composite(f, (450, y + 30))
    out.alpha_composite(up(st, 8), (560, y + 10)); out.alpha_composite(up(sq, 8), (720, y + 10))
    return out


def timeline_sheet():
    """cómo funcionan: una frase de 8 pulsos (4 s) a lo ancho; cada fila un objeto, con los Bloques Beep de referencia"""
    cw, x0 = 110, 230
    out = Image.new('RGBA', (x0 + cw * 8 + 30, 640), BG)
    label(out, 'Como funcionan: una frase = 8 pulsos = 4 s (120 BPM).  Los Bloques Beep, arriba, de referencia.', (20, 14), 11)
    for b in range(8):
        x = x0 + b * cw
        ImageDraw.Draw(out).rectangle((x, 44, x + cw - 4, 620), outline=rgb('3a3866'))
        label(out, 'pulso %d' % (b + 1), (x + 18, 50), 10, rgb('c8c4f0') if b not in (1, 3, 5, 7) else rgb('ffffff'))
    # fila 0: Bloques Beep
    pk, cx = (Image.open('assets/images/world/tiles/%s.png' % n).convert('RGBA') for n in ('beep_pink', 'beep_cyan_x'))
    label(out, 'Bloques Beep', (20, 92), 10)
    for b in range(8):
        x = x0 + b * cw + 22
        out.alpha_composite(pk.resize((48, 48), Image.NEAREST), (x, 80))
        if b >= 5: label(out, 'BEEP', (x + 2, 132), 9, rgb('fff0a0'))
    label(out, '(cambian en el pulso 1 de la frase siguiente)', (x0, 150), 8, rgb('a8a4d0'))
    # fila 1: plataforma
    label(out, '1 Plataforma', (20, 200), 10); label(out, 'metronomo', (20, 216), 10)
    for b in range(8):
        x = x0 + b * cw
        pos = b + 1 if b < 4 else 7 - b
        im = up(platform(True), 1).resize((64, 16), Image.NEAREST)
        px = x + 6 + int(pos * 10)
        out.alpha_composite(im, (px, 206))
        label(out, '->' if b < 3 else ('<-' if 3 < b < 7 else '..'), (x + 40, 230), 9, rgb('c8c4f0'))
    label(out, 'avanza 1 casilla de golpe en cada pulso: 4 a la derecha, 4 de vuelta (una frase); la lampara brilla en el pulso',
          (x0, 250), 8, rgb('a8a4d0'))
    # fila 2: pinchos
    label(out, '2 Pinchos', (20, 320), 10); label(out, 'de palmas', (20, 336), 10)
    for b in range(8):
        x = x0 + b * cw
        up_ = b % 2 == 1
        im = clap_frame('up' if up_ else 'down').resize((32, 64), Image.NEAREST)
        out.alpha_composite(im, (x + 8, 286))
        if not up_: out.alpha_composite(clap_frame('glint').resize((32, 64), Image.NEAREST), (x + 60, 286))
        label(out, 'FUERA' if up_ else 'abajo  aviso', (x + 4, 352), 8, rgb('ffb0c4') if up_ else rgb('c8c4f0'))
    label(out, 'salen con la caja (pulsos 2 y 4 de cada compas), se esconden en 1 y 3; medio pulso antes, destello',
          (x0, 372), 8, rgb('a8a4d0'))
    # fila 3: trampolín
    label(out, '4 Trampolin', (20, 440), 10); label(out, 'de compas', (20, 456), 10)
    st = art(STAR_IDLE, STAR_PAL)
    for b in range(8):
        x = x0 + b * cw
        f = Image.new('RGBA', (64, 64)); f.alpha_composite(up(st))
        f.alpha_composite(ring(64, 14, (255, 240, 160, 255)))
        out.alpha_composite(f, (x + 22, 420))
        label(out, 'EN EL PULSO', (x + 14, 490), 8, rgb('fff0a0'))
    label(out, 'el aro se cierra hacia cada pulso. Caer en la estrella EN el pulso (+-0,1 s) = salto altisimo (unas 7 casillas);',
          (x0, 510), 8, rgb('a8a4d0'))
    label(out, 'entre pulsos = un saltito (unas 2 casillas). El camino sigue arriba: hay que botar a tiempo.', (x0, 526), 8, rgb('a8a4d0'))
    return out


# ── La escena animada (corcheas: 4 cuadros por pulso, 2 frases = 64 cuadros) ─────────────────────────────────────
def scene_gif():
    grads, layers = SW.build()
    bg = SW.background('night', grads, layers).convert('RGBA')
    T = 64
    pk, pkx, cy, cyx = (Image.open('assets/images/world/tiles/%s.png' % n).convert('RGBA')
                        for n in ('beep_pink', 'beep_pink_x', 'beep_cyan', 'beep_cyan_x'))
    mon = J.up(Image.open('assets/images/player/monstrito1.png').convert('RGBA'), 6)
    st, sq = art(STAR_IDLE, STAR_PAL), art(STAR_SQUASH, STAR_PAL)
    frames = []
    FPB = 4                                      # cuadros por pulso
    for f in range(16 * FPB):
        beat = f / FPB                           # pulsos desde el principio
        b8 = int(beat) % 8                       # pulso de la frase (0 = el 1)
        phrase = int(beat) // 8
        sub = (f % FPB) / FPB                    # dentro del pulso
        cv = bg.copy()
        d = ImageDraw.Draw(cv)
        floor = 560
        # Bloques Beep (rosa en las frases pares) — parpadeo en los beeps
        pinkOn = phrase % 2 == 0
        blink = b8 >= 5 and sub < 0.36
        if blink: pinkOn = not pinkOn
        for i in range(3): cv.alpha_composite(pk if pinkOn else pkx, (40 + i * T, floor))
        for i in range(3): cv.alpha_composite(cyx if pinkOn else cy, (40 + (3 + i) * T, floor - T))
        # 1 · plataforma metrónomo: 1 casilla por pulso, de golpe (los primeros 0,08 s del pulso)
        k = int(beat) % 8
        pos = (k if k < 4 else 8 - k) + (min(1, sub / 0.16) * (1 if k < 4 else -1) if sub < 0.16 else 0)
        pos = (k + min(1, sub / 0.16)) if k < 4 else (8 - k - min(1, sub / 0.16))
        lit = sub < 0.3
        cv.alpha_composite(up(platform(lit)), (int(460 + pos * T), floor - 2 * T + 32))
        # 2 · pinchos de palmas: fuera en los pulsos 2, 4, 6, 8 (índices impares)
        for i in range(3):
            st_ = 'up' if b8 % 2 == 1 else ('glint' if sub >= 0.5 else 'down')
            cv.alpha_composite(clap_frame(st_), (820 + i * T, floor - T + T))
        # 4 · trampolín: el monstruo bota EN el pulso cada 2 pulsos (alto) — a la derecha
        sx = 1080
        ph = (beat % 2) / 2                       # un bote cada 2 pulsos
        h = int(4 * 230 * ph * (1 - ph))
        on = ph < 0.08 or ph > 0.94
        cv.alpha_composite(up(sq if on else st), (sx, floor))
        r = int(30 - 26 * ((beat % 1)))
        cv.alpha_composite(ring(80, max(6, r), (255, 240, 160, 230)), (sx - 8, floor - 8))
        cv.alpha_composite(mon, (sx + 2, floor - mon.height - h + (8 if on else 0)))
        # suelo de referencia bajo los pinchos y el trampolín
        for x in range(800, 1280, T):
            d.rectangle((x, floor + T, x + T - 1, floor + T + 8), fill=rgb('3a3866'))
        # rótulo: pulso y beeps
        d.rectangle((0, 0, 1280, 40), fill=(10, 10, 30, 200))
        label(cv, 'frase %d  pulso %d %s' % (phrase + 1, b8 + 1, ' BEEP' if b8 >= 5 and sub < 0.4 else ''), (16, 10), 12,
              rgb('fff0a0') if b8 >= 5 else rgb('ffffff'))
        label(cv, '1 plataforma metronomo', (460, 50), 9); label(cv, '2 pinchos de palmas', (820, 50), 9)
        label(cv, '4 trampolin de compas', (1060, 70), 9)
        frames.append(cv.convert('RGB').resize((960, 540), Image.NEAREST))
    frames[0].save(os.path.join(PREV, 'escena.gif'), save_all=True, append_images=frames[1:], duration=125, loop=0)
    frames[0].save(os.path.join(PREV, 'escena_cuadro.png'))


def main():
    os.makedirs(PREV, exist_ok=True)
    sprites_sheet().convert('RGB').save(os.path.join(PREV, 'sprites.png'))
    timeline_sheet().convert('RGB').save(os.path.join(PREV, 'funcionamiento.png'))
    scene_gif()
    print('vista previa:', PREV)


if __name__ == '__main__':
    main()


# ── --apply: los sprites de verdad (los pinchos NO: son los del juego, assets/images/traps/spikes/) ──────────────
def apply():
    import json
    sets = {
        'mechanisms/metronome': ('assets/images/mechanisms/metronome', {'platform': platform(False), 'platform_lit': platform(True)},
                                 {'idle': 'platform', 'lit': 'platform_lit'}),
        'traps/clapspikes': ('assets/images/traps/clapspikes', {'plate': plate(False), 'plate_glint': plate(True)},
                             {'idle': 'plate', 'glint': 'plate_glint'}),
        'mechanisms/beatspring': ('assets/images/mechanisms/beatspring',
                                  dict({'idle': art(STAR_IDLE, STAR_PAL), 'squash': art(STAR_SQUASH, STAR_PAL)},
                                       **{'ring%d' % i: ring_art(r) for i, r in ((1, 11), (2, 8), (3, 6), (4, 4))}),
                                  dict({'idle': 'idle', 'bounce': 'squash'}, **{'ring%d' % i: 'ring%d' % i for i in range(1, 5)})),
    }
    for aid, (d, ims, anims) in sets.items():
        os.makedirs(os.path.join(REPO, d), exist_ok=True)
        names = sorted(ims)
        for n in names:
            ims[n].save(os.path.join(REPO, d, n + '.png')); print('  escrito', d + '/' + n + '.png')
        js = {'id': aid, 'scale': 4, 'origin': [0.5, 0.5], 'fallback': 'idle',
              'frames': [{'image': d + '/' + n + '.png', 'key': n + '.png'} for n in names],
              'anims': {a: {'fps': 4, 'frames': [names.index(f) + 1], 'loop': True} for a, f in anims.items()}}
        p = os.path.join(REPO, 'assets/anim', aid + '.json')
        os.makedirs(os.path.dirname(p), exist_ok=True)
        animjson.write(p, js)
        print('  escrito', os.path.relpath(p, REPO))


if '--apply' in sys.argv:
    apply()
