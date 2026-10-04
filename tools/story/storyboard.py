#!/usr/bin/env python3
# tools/story/storyboard.py
# GUION GRÁFICO de la historia ("El Espejo Roto"): la INTRO y el FINAL, viñeta a viñeta, montadas con
# los sprites reales del juego (bocetos de concepto: posiciones y encuadres, no la animación final).
# Cada viñeta = una escena a 320x180 (la pantalla del juego a 1/4) con su número, duración y lo que pasa.
# El guion escrito (tiempos, transiciones, sonido) está en docs/historia/HISTORIA.md: los dos salen de
# la misma tabla SCENES de aquí (`--md` la imprime).
#   python3 tools/story/storyboard.py        → FlappyMonster_pruebas/historia/storyboard_{intro,final}.png
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
IMG = os.path.join(REPO, 'assets', 'images')
OUT = '/home/mtvemo/FlappyMonster_pruebas/historia'
MAP = '/home/mtvemo/FlappyMonster_pruebas/mapa/mapa_completo.png'
W, H = 320, 180
FONT = ImageFont.truetype(os.path.join(REPO, 'assets', 'fonts', 'PressStart2P.ttf'), 8)

_cache = {}


def img(path):
    if path not in _cache:
        _cache[path] = Image.open(os.path.join(IMG, path)).convert('RGBA')
    return _cache[path]


def spr(path, scale=1, frame=None, fw=None, flip=False, invert=False, alpha=1.0, tint=None):
    im = img(path)
    if fw:
        im = im.crop(((frame or 0) * fw, 0, (frame or 0) * fw + fw, im.height))
    if flip:
        im = ImageOps.mirror(im)
    if invert:
        r, g, b, a = im.split()
        im = Image.merge('RGBA', (ImageOps.invert(r), ImageOps.invert(g), ImageOps.invert(b), a))
    if tint:
        r, g, b, a = im.split()
        im = Image.merge('RGBA', tuple(c.point(lambda v, k=k: int(v * k)) for c, k in zip((r, g, b), tint)) + (a,))
    if alpha < 1:
        im.putalpha(im.getchannel('A').point(lambda v: int(v * alpha)))
    if scale != 1:
        im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.NEAREST)
    return im


def put(c, im, cx, by):
    """Pega `im` centrada en cx y con los pies en by."""
    c.alpha_composite(im, (int(cx - im.width / 2), int(by - im.height)))


def sky(grad, layers=()):
    """Degradado nº `grad` de sky/gradients.png + capas (archivo, y de su base)."""
    g = img('sky/gradients.png').crop((grad * 8, 0, grad * 8 + 1, 180)).resize((W, H), Image.NEAREST)
    c = g.copy()
    for name, base in layers:
        l = img('sky/%s.png' % name)
        c.alpha_composite(l, (0, base - l.height))
    return c


def flash(c, k):
    c.alpha_composite(Image.new('RGBA', (W, H), (255, 255, 255, int(255 * k))))


def dark(c, k):
    c.alpha_composite(Image.new('RGBA', (W, H), (0, 0, 0, int(255 * k))))


def monster(c, x, y, s=2, frame=1, wings=False, flip=False, invert=False):
    if wings:
        w = spr('wings/wings-Sheet.png', s, 0, 9)
        c.alpha_composite(w, (int(x - 4.5 * s - w.width + s), int(y - 13 * s)))
        c.alpha_composite(ImageOps.mirror(w), (int(x + 4.5 * s - s), int(y - 13 * s)))
    put(c, spr('player/monstrito%d.png' % frame, s, flip=flip, invert=invert), x, y)


def mirror(c, x, y, s=1, shards=0, whole=False, glow=False):
    m = img('story/mirror/frame.png').copy()
    if whole:
        m.alpha_composite(img('story/mirror/glass.png'))
    for i in range(shards):
        m.alpha_composite(img('story/mirror/shard_%d.png' % (i + 1)))
    if glow:
        d = ImageDraw.Draw(c, 'RGBA')
        for r, a in ((70, 26), (52, 40), (38, 60)):
            d.ellipse((x - r * s, y - 36 * s - r * s, x + r * s, y - 36 * s + r * s), fill=(255, 255, 220, a))
    put(c, m.resize((int(48 * s), int(64 * s)), Image.NEAREST), x, y)


def shard(c, n, x, y, s=2):
    im = img('story/mirror/shard_%d.png' % n)
    im = im.crop(im.getbbox())
    put(c, im.resize((int(im.width * s), int(im.height * s)), Image.NEAREST), x, y)


def ground(c, y, col):
    ImageDraw.Draw(c).rectangle((0, y, W, H), fill=col)


def ray(c, x0, y0, x1, y1, col=(255, 255, 220, 190), wdt=3):
    ImageDraw.Draw(c, 'RGBA').line((x0, y0, x1, y1), fill=col, width=wdt)


def world_map(zoom=None):
    m = Image.open(MAP).convert('RGBA') if os.path.exists(MAP) else Image.new('RGBA', (2688, 1536), (40, 90, 160, 255))
    if zoom:
        m = m.crop(zoom)
    return m.resize((W, H), Image.BILINEAR)


CAVE = [('magma_wall', 160), ('magma_top', 70), ('magma_mid', 180)]
ISLES = [(62, 142), (192, 146), (70, 62), (258, 62), (272, 140), (166, 88)]   # pradera, costa, fortaleza, nieve, cuevas, volcán       # (en la viñeta del mapa)


# ----------------------------------------------------------------------------------------------------
# LAS ESCENAS: (id, segundos, título, qué pasa, sonido / música, función que la dibuja)
# ----------------------------------------------------------------------------------------------------
def i1():
    c = sky(0, [('meadow_far', 180), ('meadow_mid', 180)])
    put(c, spr('sky/sun.png', 1), 270, 46)
    for x, top in ((90, 60), (190, 96)):
        p = spr('pipes/pipe.png', 2)
        c.alpha_composite(p, (x, top + 46)); c.alpha_composite(ImageOps.flip(p), (x, top - 168))
    monster(c, 140, 96, 2, 2, wings=True)
    return c


def i2():
    c = sky(1, [('volcano_far', 180), ('volcano_mid', 180)])
    dark(c, 0.18)
    monster(c, 120, 70, 2, 3, wings=True)
    ray(c, 150, 60, 235, 78, (255, 240, 200, 120), 1)
    put(c, spr('story/mirror/shard_7.png', 1), 240, 110)
    return c


def i3():
    c = sky(9, CAVE)
    mirror(c, 215, 150, 1.5, whole=True, glow=True)
    monster(c, 95, 150, 2, 1)
    monster(c, 215, 118, 1, 1, flip=True)                                   # su reflejo, dentro
    return c


def i4():
    c = sky(9, CAVE)
    mirror(c, 215, 150, 1.5, shards=7)
    monster(c, 178, 118, 2, 4, wings=True)
    for a, b in ((-60, -50), (-78, 8), (-50, 46), (54, -56), (70, 0), (40, 52)):
        ray(c, 215, 96, 215 + a, 96 + b, (255, 255, 255, 230), 2)
    flash(c, 0.45)
    return c


def i5():
    c = sky(9, CAVE)
    mirror(c, 215, 150, 1.5, shards=0)
    monster(c, 215, 118, 1.5, 1, flip=True, invert=True)                      # el REFLEJO sale del marco
    monster(c, 110, 152, 2, 5)
    for n, (x, y) in enumerate(((120, 50), (160, 30), (250, 28), (290, 60), (70, 80), (185, 60))):
        shard(c, n + 1, x, y, 1.5)
    return c


def i6():
    c = sky(9, CAVE)
    mirror(c, 250, 150, 1.5, shards=0)
    monster(c, 160, 84, 2, 2, wings=True, invert=True)                        # se lleva las alas y se ríe
    c.alpha_composite(spr('bosses/mirror/JoyEyes.png', 2, invert=True), (155, 60))
    monster(c, 80, 152, 2, 3)                                                 # el monstruo, sin alas, salta y cae
    shard(c, 7, 160, 112, 2)
    return c


def i7():
    c = world_map()
    vx, vy = ISLES[5]
    for n, (x, y) in enumerate(ISLES[:5]):
        ray(c, vx, vy - 8, x, y - 8, (255, 255, 255, 170), 1)
        shard(c, n + 1, x, y, 1)
    shard(c, 6, vx - 14, vy + 4, 1); shard(c, 7, vx + 12, vy - 4, 1)
    return c


def i8():
    c = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    cells = [
        (sky(0, [('meadow_far', 90), ('meadow_mid', 90)]), lambda p: (put(p, spr('bosses/megagummy/body-Sheet.png', 3, 0, 16), 53, 82), put(p, spr('bosses/megagummy/crown.png', 3), 53, 82))),
        (sky(0, [('coast_far', 90), ('coast_near', 100)]), lambda p: put(p, spr('bosses/megacrabby/crab1.png', 4), 53, 82)),
        (sky(1, [('fortress_far', 100)]), lambda p: put(p, spr('bosses/miniboss1/ship.png', 2), 53, 60)),
        (sky(0, [('snow_far', 100), ('snow_mid', 100)]), lambda p: put(p, spr('bosses/snowboss/body-Sheet.png', 3, 0, 16), 53, 82)),
        (sky(0, [('snow_far', 100)]), lambda p: put(p, spr('bosses/megacrabby_ice/crab1.png', 4), 53, 82)),
        (sky(3, [('cave_far', 90)]), lambda p: put(p, spr('bosses/megagloomy/body-Sheet.png', 2, 0, 38), 53, 78)),
    ]
    for k, (bg, draw) in enumerate(cells):
        p = bg.crop((100, 60, 206, 148))
        draw(p)
        c.alpha_composite(p, (1 + (k % 3) * 107, 1 + (k // 3) * 90))
    return c


def i9():
    c = sky(0, [('meadow_far', 180), ('meadow_mid', 180), ('meadow_near', 180)])
    put(c, spr('sky/volcano_far.png', 0.35), 262, 118)
    monster(c, 70, 158, 2, 1)
    return c


def e1():
    c = sky(8, [('volcano_far', 180), ('volcano_near', 190)])
    ground(c, 150, (62, 26, 28))
    monster(c, 200, 140, 2, 4, invert=True, flip=True)
    c.alpha_composite(spr('bosses/common/stars-Sheet.png', 2, 0, 5), (192, 96))
    monster(c, 100, 150, 2, 1)
    shard(c, 7, 205, 96, 2)
    return c


def e2():
    c = sky(8, [('volcano_far', 180), ('volcano_near', 190)])
    ground(c, 150, (62, 26, 28))
    monster(c, 160, 150, 2, 2)
    import math
    for n in range(7):
        a = n / 7 * math.tau - 1.2
        shard(c, n + 1, 160 + math.cos(a) * 62, 98 + math.sin(a) * 40, 1.5)
    return c


def e3():
    c = sky(9, CAVE)
    mirror(c, 215, 150, 1.5, shards=5)
    monster(c, 100, 150, 2, 1)
    shard(c, 6, 160, 80, 1.5); shard(c, 7, 130, 62, 1.5)
    ray(c, 168, 74, 198, 96, (255, 255, 255, 160), 1)
    return c


def e4():
    c = sky(9, CAVE)
    mirror(c, 215, 150, 1.5, whole=True, glow=True)
    monster(c, 100, 150, 2, 1)
    flash(c, 0.5)
    return c


def e5():
    c = sky(9, CAVE)
    mirror(c, 215, 150, 1.5, whole=True, glow=True)
    put(c, spr('player/monstrito4.png', 1.5, invert=True, alpha=0.55), 196, 120)   # el Reflejo, absorbido
    for k in range(5):
        ray(c, 150 + k * 9, 132 - k * 4, 204, 104, (255, 255, 255, 110), 1)
    monster(c, 100, 150, 2, 1)
    return c


def e6():
    c = world_map()
    d = ImageDraw.Draw(c, 'RGBA')
    vx, vy = ISLES[5]
    for r, a in ((150, 40), (110, 60), (70, 90)):
        d.ellipse((vx - r, vy - r, vx + r, vy + r), outline=(255, 255, 230, a + 80), width=3)
    d.ellipse((vx - 12, vy - 12, vx + 12, vy + 12), fill=(255, 255, 230, 220))
    return c


def e7():
    c = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    cells = [
        (sky(0, [('meadow_far', 90), ('meadow_mid', 90)]), lambda p: (put(p, spr('gummy/gummy.png', 2), 53, 82), put(p, spr('bosses/megagummy/crown.png', 3), 53, 86))),
        (sky(0, [('coast_far', 90), ('coast_near', 100)]), lambda p: put(p, spr('crabby/crab1.png', 2), 53, 82)),
        (sky(0, [('fortress_far', 100)]), lambda p: put(p, spr('bosses/miniboss1/ship.png', 1), 53, 82)),
        (sky(0, [('snow_far', 100), ('snow_mid', 100)]), lambda p: put(p, spr('bosses/snowboss/ball.png', 2), 53, 82)),
        (sky(0, [('snow_far', 100)]), lambda p: put(p, spr('crabby_ice/crab1.png', 2), 53, 82)),
        (sky(3, [('cave_far', 90)]), lambda p: put(p, spr('gloomy/gloomy-Sheet.png', 1, 0, 26), 53, 80)),
    ]
    for k, (bg, draw) in enumerate(cells):
        p = bg.crop((100, 60, 206, 148))
        draw(p)
        c.alpha_composite(p, (1 + (k % 3) * 107, 1 + (k // 3) * 90))
    return c


def e8():
    c = sky(9, CAVE)
    mirror(c, 215, 150, 1.5, whole=True)
    monster(c, 215, 118, 1, 1, flip=True)                                   # el reflejo, normal: copia al monstruo
    monster(c, 100, 138, 2, 2, wings=True)                                    # ¡vuelven las alas!
    for x, y in ((70, 96), (132, 92), (100, 80)):
        ray(c, x, y, x, y + 6, (255, 255, 200, 230), 2)
    return c


def e9():
    c = sky(1, [('meadow_far', 180), ('meadow_mid', 180)])
    put(c, spr('sky/sun.png', 1), 60, 150)
    for x, top in ((210, 70),):
        p = spr('pipes/pipe.png', 2)
        c.alpha_composite(p, (x, top + 46)); c.alpha_composite(ImageOps.flip(p), (x, top - 168))
    monster(c, 150, 92, 2, 2, wings=True)
    put(c, spr('menus/logo.png', 3), 160, 60)
    return c


INTRO = [
    ('I1', 6.0, 'Un día cualquiera', 'El monstruo ALETEA entre las tuberías (el modo Flappy), feliz. Cielo azul.',
     'Música: tema del juego, ligero ("la llamada"). Aleteos.', i1),
    ('I2', 5.0, 'El destello', 'Atardecer: algo brilla dentro del volcán. Curioso, vuela hacia allí.',
     'La música se queda en una nota; un brillo (campanita).', i2),
    ('I3', 6.0, 'El espejo antiguo', 'Dentro del cráter: un espejo dorado. Se acerca; su reflejo lo imita.',
     'Caja de música: "la llamada" y su eco INVERTIDO (el reflejo).', i3),
    ('I4', 2.5, '¡CRAC!', 'Aletea demasiado cerca y choca. Destello blanco: el cristal se parte en 7.',
     'Silencio de medio segundo → golpe + cristal roto. Corte seco.', i4),
    ('I5', 6.0, 'El Reflejo sale', 'Del marco vacío sale su reflejo (colores invertidos). Los fragmentos flotan.',
     'Entra el motivo del Espejo (grave, 12/8). Tintineo de cristales.', i5),
    ('I6', 6.0, 'Le roba las alas', 'El Reflejo le quita el ALETEO, se ríe y se guarda el fragmento del centro. El monstruo salta... y cae.',
     'Risa del Espejo. Golpe sordo al caer (sin alas).', i6),
    ('I7', 6.0, 'Seis fragmentos, seis islas', 'El Reflejo lanza los otros seis: cruzan el cielo y caen uno en cada isla (el mapa).',
     'Seis notas descendentes, una por fragmento.', i7),
    ('I8', 7.0, 'La furia del espejo', 'Quien encuentra un fragmento crece y se enfurece: Rey Gummy, Mega Crabby, la Nave, la Bola, el helado, el lúgubre.',
     'Seis golpes de timbal, uno por jefe; crece.', i8),
    ('I9', 5.5, 'A pie', 'El monstruo, en la orilla de la Pradera, mira el volcán a lo lejos... y echa a andar. → MAPA.',
     'La llamada, decidida, en trompeta: enlaza con la música del mapa.', i9),
]
FINAL = [
    ('F1', 4.0, 'El Espejo cae', 'En el juego: el jefe Espejo, vencido, cae y suelta el ÚLTIMO fragmento (no hay meta que tocar).',
     'Se corta la música del jefe. Cristal.', e1),
    ('F2', 5.0, 'Los siete', 'El monstruo lo recoge: los siete fragmentos salen y giran a su alrededor.',
     'Caja de música: la llamada, despacio. Un tintineo por fragmento.', e2),
    ('F3', 8.0, 'Pieza a pieza', 'Vuelan al marco y encajan uno a uno, en el orden en que se ganaron (el del centro, el último).',
     'Siete notas ASCENDENTES (la escala de la llamada), una por pieza.', e3),
    ('F4', 3.0, 'El espejo, entero', 'La última pieza: destello. Las grietas se borran.',
     'Acorde mayor lleno + platillo.', e4),
    ('F5', 5.0, 'El Reflejo vuelve', 'El espejo tira del Reflejo: vuelve dentro, rabiando, y suelta lo que robó.',
     'El motivo del Espejo, al revés (= la llamada). Succión.', e5),
    ('F6', 7.0, 'La luz recorre las islas', 'Del cráter sale una onda de luz que barre el mapa, isla a isla: LA FURIA DEL ESPEJO se apaga.',
     'Tema del mapa, a pleno. Seis campanas.', e6),
    ('F7', 7.0, 'Todos, pequeños otra vez', 'Los jefes encogen: un Gummy con una corona enorme, un Crabby, la nave diminuta, una bolita...',
     'Seis "pop" cómicos sobre la música.', e7),
    ('F8', 7.0, 'Las alas', 'Ante el espejo, su reflejo ya es solo eso. Prueba: un aleteo... dos... ¡se eleva!',
     'Pausa. Aleteo, aleteo → la llamada completa, por fin resuelta.', e8),
    ('F9', 9.0, 'Volando a casa', 'Sale del cráter y vuela sobre las islas al amanecer; vuelven las tuberías. Logo. FIN → créditos.',
     'Tema del juego a pleno; termina con el aleteo.', e9),
]


def sheet(scenes, name, title):
    S, PAD, CAP = 2, 16, 58
    cols = 3
    rows = (len(scenes) + cols - 1) // cols
    cw, ch = W * S + PAD, H * S + CAP + PAD
    out = Image.new('RGBA', (cols * cw + PAD, rows * ch + PAD + 28), (28, 30, 44, 255))
    d = ImageDraw.Draw(out)
    total = sum(s[1] for s in scenes)
    d.text((PAD, 12), '%s  -  %d escenas, %.1f s' % (title, len(scenes), total), font=FONT, fill=(255, 226, 120))
    t = 0
    for k, (sid, dur, ttl, what, snd, fn) in enumerate(scenes):
        x, y = PAD + (k % cols) * cw, 36 + (k // cols) * ch
        out.alpha_composite(fn().resize((W * S, H * S), Image.NEAREST), (x, y))
        d.rectangle((x - 1, y - 1, x + W * S, y + H * S), outline=(255, 255, 255))
        d.text((x, y + H * S + 6), '%s  %04.1f-%04.1f s  %s' % (sid, t, t + dur, ttl.upper()), font=FONT, fill=(255, 255, 255))
        words, line, ly = what.split(), '', y + H * S + 20
        for w in words + ['']:
            if w == '' or d.textlength(line + ' ' + w, font=FONT) > W * S:
                d.text((x, ly), line.strip(), font=FONT, fill=(170, 180, 205)); ly += 11; line = w
            else:
                line += ' ' + w
        t += dur
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, name))
    print('  %s: %d escenas, %.1f s → %s/%s' % (title, len(scenes), total, OUT, name))


def markdown():
    for title, scenes in (('Intro', INTRO), ('Final', FINAL)):
        print('\n### %s (%.1f s)\n' % (title, sum(s[1] for s in scenes)))
        print('| Escena | Tiempo | Qué se ve | Sonido y música |\n|---|---|---|---|')
        t = 0
        for sid, dur, ttl, what, snd, fn in scenes:
            print('| **%s** %s | %.1f–%.1f s | %s | %s |' % (sid, ttl, t, t + dur, what, snd))
            t += dur


if __name__ == '__main__':
    if '--md' in sys.argv:
        markdown()
    else:
        sheet(INTRO, 'storyboard_intro.png', 'INTRO')
        sheet(FINAL, 'storyboard_final.png', 'FINAL')
