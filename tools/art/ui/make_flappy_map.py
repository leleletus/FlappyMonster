#!/usr/bin/env python3
# tools/art/ui/make_flappy_map.py
# El MAPA DE ZONA de la campaña Flappy (src/states/flappy/FlappyMapState.lua; Plan 5b, docs/design/flappy-plan-5b-valley.md):
# el arte del VALLE DE LOS PILARES. Arte a 1x; el juego lo dibuja a x4 (la densidad del cielo y del mapa de la historia).
#   valle_bg.png           el cuadro de fondo (320x180 = 1280x720): degradado de día, sol, nubes y las tres capas del
#                          cielo `valley` (make_valley_sky.py). Se repite a lo ancho (las capas son de 320 y dan la vuelta)
#   valle_pillar.png       el pilar de basalto de delante, que lleva un nido arriba (18x160: boca arriba, cuerpo, y las
#                          10 filas de abajo son su base en la hierba: el juego dibuja lo de arriba que haga falta + la base)
#   valle_nest-Sheet.png   el NIDO de una etapa (24x22, 3 cuadros): abierta (banderín rojo, huevo), superada (banderín
#                          dorado, huevo dorado), cerrada (gris; el candado lo pone el juego con PixelIcons 'lock')
#   valle_boss-Sheet.png   el icono del jefe: el REDCÓPTERO (globo remendado, cuerdas, góndola y hélice; los colores de
#                          make_netcopter.py), 24x26, 3 cuadros: abierto, vencido (el globo pinchado), cerrado (gris)
#   valle_shop-Sheet.png   la TIENDA: el nido del MERCADER, un flappy de la misma raza (cabeza redonda, antenas, SIN ALAS)
#                          con gorro y delantal y su saco de monedas; 30x24, 2 cuadros (quieto, saludando)
# Los sitios de los nodos son DATOS (src/flappy/Zones.lua `map`); la vista previa usa unos de ejemplo.
# Por defecto solo la VISTA PREVIA (fuera del repo):
#   /home/mtvemo/FlappyMonster_pruebas/valle/mapa_vista_previa.png   (el mapa a 1280 y a 960)
#   /home/mtvemo/FlappyMonster_pruebas/valle/mapa_sprites.png        (cada sprite a x8)
# --apply escribe en assets/images/flappy/map/ (no pisa lo que exista; --force sí: estos archivos son de este generador
# y nadie los ha retocado a mano — si eso cambia, quitar --force de la lista en docs/art/generators.md).
# Desde la raíz del repo:
#     /usr/bin/python3 tools/art/ui/make_flappy_map.py [--apply [--force]]
import os, sys, random
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
os.chdir(REPO)
sys.path.insert(0, os.path.join(REPO, 'tools/art/world'))
_argv, sys.argv = sys.argv, sys.argv[:1]          # (los generadores del cielo leen sys.argv al importarse)
import make_valley_sky as V                       # capas, paleta y flappies del Valle
J = V.J                                           # make_jungle_sky: degradado, up(), etiquetas
sys.argv = _argv

APPLY = '--apply' in sys.argv
FORCE = '--force' in sys.argv
PREV = '/home/mtvemo/FlappyMonster_pruebas/valle'
OUT = os.path.join(REPO, 'assets/images/flappy/map')
S = 4                                             # la escala del juego
rgb = V.rgb


def hx(s): return rgb(s)


# ── Paleta ──────────────────────────────────────────────────────────────────────────────────────────────────────
# pilar de delante: el basalto de las capas, más oscuro y con contorno (se lee delante del fondo)
PL = (hx('8a7e8c'), hx('6a6278'), hx('504a62'))   # luz, cuerpo, sombra
PO = hx('2c2838')                                 # contorno
PJ = hx('403a50')                                 # juntas
GR = getattr(V, 'GRASS', (hx('7fae4a'), hx('5a8a3a'), hx('3c6a30')))    # (el Valle ya no tiene franja de hierba: solo la usa el pilar)
TW = (hx('c8ac80'), hx('9c7e5c'), hx('6e5440'), hx('4a3828'))     # ramitas: luz, medio, oscuro, contorno
GREY_TW = (hx('a8a4ac'), hx('84808c'), hx('64606c'), hx('3e3a46'))
EGG = (hx('fff6e4'), hx('e6d8c0'))
GOLD = (hx('fff0a0'), hx('f4c43c'), hx('b8862a'))
FLAG_R = (hx('ec5a48'), hx('b8342c'))
POLE = hx('5a4030')
# el Redcóptero (los mismos que make_netcopter.py)
RED = [hx(c) for c in ('5a1418', '9a2428', 'cf3d34', 'ec7a5a')]
DENIM = [hx('1e2a48'), hx('3c5c94'), hx('6c8cc4')]
BURLAP = [hx('3a2a10'), hx('a07c3c'), hx('cca868')]
THREAD = hx('f4ecd0')
WOOD = [hx(c) for c in ('2e1c0c', '6a4020', '9a6234', 'c08c52')]
IRON = [hx(c) for c in ('1c1c24', '4a4a58', '7c7c8c', 'b4b4c4')]
ROPE = hx('c8b078')
# el mercader: cuerpo ciruela, cara clara del monstruo, gorro rojo, delantal crema, saco de arpillera
MB, MF, MS, ME = hx('5c4070'), hx('f4f2ee'), hx('c4c8d6'), hx('0c0c14')
HAT = (hx('d0503c'), hx('8e2c24'))
APRON = (hx('f0e2c0'), hx('cbb894'))


def new(w, h): return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height: im.putpixel((x, y), c)


def rows(im, x, y, rs, pal):
    for j, r in enumerate(rs):
        for i, ch in enumerate(r):
            if ch in pal: px(im, x + i, y + j, pal[ch])


def grey(im, k=0.9):
    """el cuadro CERRADO: en grises y más oscuro"""
    out = im.copy()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = out.getpixel((x, y))
            if a == 0: continue
            l = int((0.3 * r + 0.55 * g + 0.15 * b) * k)
            out.putpixel((x, y), (l, l, min(255, l + 8), a))
    return out


def sheet(frames):
    w, h = frames[0].size
    out = new(w * len(frames), h)
    for i, f in enumerate(frames): out.alpha_composite(f, (i * w, 0))
    return out


# ── El fondo ────────────────────────────────────────────────────────────────────────────────────────────────────
def background():
    W, H = 320, 180
    cv = J.grad_frame(V.GRADS['day']).resize((W, H), Image.NEAREST)
    sky = J.GAME_SKY
    cv.alpha_composite(Image.open(os.path.join(sky, 'sun.png')).convert('RGBA'), (250, 12))
    cl = Image.open(os.path.join(sky, 'clouds.png')).convert('RGBA')
    for (x, y, v) in ((10, 20, 1), (96, 38, 2), (178, 14, 3), (282, 50, 1)):
        cv.alpha_composite(cl.crop(((v - 1) * 48, 0, v * 48, 16)), (x, y))
    _, layers = V.build()
    for name in ('far', 'mid', 'near'):
        im = layers[name]
        cv.alpha_composite(im, (0, H - im.height))
    return cv


GROUND = 150                      # fila de la hierba del fondo (la capa near: 180 - 64 + 34); el juego: WINDOW_H - 30*4


# ── El pilar de delante (18 de ancho: la boca 18, el cuerpo 16 con contorno) ────────────────────────────────────
PILLAR_H, BASE_H = 160, 10


def pillar():
    im = new(18, PILLAR_H)
    r = random.Random(7)

    def body_row(y, x0=1, x1=16):
        px(im, x0, y, PO); px(im, x1, y, PO)
        for x in range(x0 + 1, x1):
            c = PL[1]
            if x < x0 + 5: c = PL[0]
            elif x >= x1 - 3: c = PL[2]
            px(im, x, y, c)
    # la boca: contorno, dos filas de reborde y la sombra debajo
    for x in range(18): px(im, x, 0, PO)
    for y in (1, 2):
        px(im, 0, y, PO); px(im, 17, y, PO)
        for x in range(1, 17): px(im, x, y, PL[0] if (x < 6 or y == 1) else (PL[2] if x >= 13 else PL[1]))
    for x in range(18): px(im, x, 3, PO)
    for y in range(4, PILLAR_H - BASE_H): body_row(y)
    for x in range(2, 16): px(im, x, 4, PL[2])               # sombra bajo la boca
    for _ in range(26):                                       # juntas del basalto
        y = r.randrange(8, PILLAR_H - BASE_H - 2)
        x0 = 3 + r.randrange(0, 10)
        for x in range(x0, min(15, x0 + 2 + r.randrange(3))): px(im, x, y, PJ)
    # la base: se ensancha un poco y la hierba la tapa abajo
    b = PILLAR_H - BASE_H
    for y in range(b, PILLAR_H):
        k = 1 if y >= b + 3 else 0
        body_row(y, 1 - k, 16 + k)
    for x in range(18):
        for y in range(PILLAR_H - 4, PILLAR_H): px(im, x, y, GR[1] if y < PILLAR_H - 2 else GR[2])
        px(im, x, PILLAR_H - 4, GR[0])
        if x % 3 == 0: px(im, x, PILLAR_H - 5, GR[1])
        if x % 5 == 1: px(im, x, PILLAR_H - 6, GR[0]); px(im, x, PILLAR_H - 5, GR[0])
    return im


# ── El nido (24x22): la taza de ramitas abajo (filas 15..21), lo que lleva encima ───────────────────────────────
NEST = ['...t..t...t..t...t..t...',
        '..oTToTToTToTToTToTToo..',
        '.oTtTtTtTtTtTtTtTtTtTtTo',
        '.otdtdtdtdtdtdtdtdtdtdto',
        '..odddddddddddddddddddo.',
        '...odddddddddddddddddo..',
        '.....oooooooooooooo.....']


def nest_cup(im, y0, pal):
    l, m, d, o = pal
    rows(im, 0, y0, NEST, {'t': m, 'T': l, 'o': o, 'd': d})


def egg(im, x, y, pal):
    rows(im, x, y, ['.aa.', 'abaa', 'aaab'], {'a': pal[0], 'b': pal[1]})


def flag(im, x, y, pal):
    """banderín en un palito: el palo en x, la tela a su derecha"""
    for yy in range(y, y + 13): px(im, x, yy, POLE)
    rows(im, x + 1, y, ['aaaaab', 'aaaab.', 'aab...', 'ab....'], {'a': pal[0], 'b': pal[1]})


def nests():
    out = []
    for kind in ('open', 'done', 'locked'):
        im = new(24, 22)
        if kind == 'open':
            flag(im, 16, 2, FLAG_R); egg(im, 7, 13, EGG)
        elif kind == 'done':
            flag(im, 16, 2, (GOLD[1], GOLD[2])); egg(im, 7, 13, (GOLD[0], GOLD[1]))
        nest_cup(im, 15, GREY_TW if kind == 'locked' else TW)
        out.append(im)
    return out


# ── El Redcóptero en pequeño (24x26) ─────────────────────────────────────────────────────────────────────────────
def balloon(im, cx, cy, rx, ry):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            u, v = (x - cx) / (rx + 0.5), (y - cy) / (ry + 0.5)
            q = u * u + v * v
            if q > 1: continue
            edge = q > 0.72
            c = RED[2]
            if u + v < -0.7: c = RED[3]
            elif u + v > 0.55: c = RED[1]
            px(im, x, y, RED[0] if edge and (u * u + v * v) > 0.86 else c)


def gondola(im, y0=19):
    rows(im, 6, y0, ['ooooooooooooo',
                     'owwwwwwwwwwwo',
                     'ommmmmmdmmmmo',
                     'ommmmmmdmmmmo',
                     'ooooooooooooo'], {'o': WOOD[0], 'w': WOOD[3], 'm': WOOD[2], 'd': WOOD[1]})
    # la hélice de atrás (a la derecha)
    rows(im, 19, y0 + 1, ['..b', 'sbc', '..c'], {'s': IRON[2], 'b': IRON[3], 'c': IRON[1]})


def boss_open():
    im = new(24, 26)
    # cuerdas del globo a la góndola
    for (x0, x1) in ((5, 7), (18, 16)):
        for y in range(13, 19):
            px(im, x0 + round((x1 - x0) * (y - 13) / 5), y, ROPE)
    balloon(im, 12, 7, 10, 7)
    rows(im, 5, 4, ['ooo', 'oto', 'ooo'], {'o': DENIM[1], 't': THREAD})          # remiendo vaquero
    rows(im, 15, 8, ['bbb', 'btb'], {'b': BURLAP[2], 't': BURLAP[0]})           # remiendo de arpillera
    gondola(im)
    return im


def boss_popped():
    """vencido: el globo pinchado, un trapo rojo caído sobre la góndola"""
    im = new(24, 26)
    for (x0, x1) in ((7, 8), (17, 16)):
        for y in range(15, 19): px(im, x0 + (x1 - x0) * (y - 15) // 3, y, ROPE)
    rows(im, 3, 11, ['.....oooooooooo.....',
                     '...oommmmmmmmmmmoo..',
                     '.oommmmmmlmmmmmmmmoo',
                     'ommdd.mmmmmmm.ddmmmo',
                     'od..o.dmm.mmd.o..ddo',
                     '.o....o.o..o.o....o.'],
         {'o': RED[0], 'm': RED[2], 'l': RED[3], 'd': RED[1]})
    rows(im, 7, 12, ['oto'], {'o': DENIM[1], 't': THREAD})
    gondola(im)
    return im


def bosses():
    a = boss_open()
    return [a, boss_popped(), grey(a)]


# ── El mercader en su nido (30x24: el nido como el de las etapas, en x 0..23; el saco a la derecha) ──────────────
MERCHANT = ['..a...a..',
            '...a.a...',
            '..hhhhh..',
            '.HHHHHHH.',
            '.aFFFFsa.',
            '.aFeFesa.',
            '.aFFsssa.',
            '..aaaaa..',
            'a.PPPPP.a',
            '.aPPpPPa.',
            '..PPpPP..',
            '..aaaaa..']
MERCHANT_WAVE = ['..a...a.a',
                 '...a.a..a',
                 '..hhhhh.a',
                 '.HHHHHHHa',
                 '.aFFFFsa.',
                 '.aFeFesa.',
                 '.aFFsssa.',
                 '..aaaaa..',
                 'a.PPPPP..',
                 '.aPPpPPa.',
                 '..PPpPP..',
                 '..aaaaa..']
SACK = ['..ss...',
        '.sSSs..',
        '..rr...',
        '.sSSSs.',
        'sSSSSSs',
        'sSScSSs',
        'sSccSSs',
        'sSScSSs',
        '.sssss.']


def shop(wave=False):
    im = new(30, 24)
    rows(im, 8, 6, MERCHANT_WAVE if wave else MERCHANT,
         {'a': MB, 'F': MF, 's': MS, 'e': ME, 'h': HAT[0], 'H': HAT[1], 'P': APRON[0], 'p': APRON[1]})
    nest_cup(im, 17, TW)
    rows(im, 21, 11, SACK, {'s': BURLAP[0], 'S': BURLAP[2], 'r': ROPE, 'c': GOLD[1]})
    rows(im, 18, 17, ['.g', 'gG'], {'g': GOLD[1], 'G': GOLD[0]})                # monedas en el borde
    return im


def shops(): return [shop(False), shop(True)]


# ── El cartel de la tienda: poste con brazo (se queda quieto), tablón colgado de dos cuerdas (se mece) y un destello ─
# Hoja valle_sign.png 34x49: poste+brazo en (0,0) 34x31 · tablón en (0,32) 30x12 · destello 2 cuadros 5x5 en (0,44)/(5,44).
# Respecto al cuadro de la tienda (30x24): el poste nace en la columna 2 (en el borde del nido) y el tablón queda sobre el
# mercader sin tocarle el gorro (el gorro empieza en la fila 6; el tablón acaba en la fila 2).
SIGN_POST_AT, SIGN_PLANK_AT = (0, -12), (3, -9)          # esquina de cada pieza respecto al cuadro de la tienda (filas)


def sign_post():
    im = new(34, 31)
    for y in range(31):                                    # poste de dos columnas, hasta el nido (fila 18)
        px(im, 2, y, WOOD[0]); px(im, 3, y, WOOD[2]); px(im, 4, y, WOOD[1])
    for x in range(2, 32):                                 # brazo (fila 0) con refuerzo
        px(im, x, 0, WOOD[0]); px(im, x, 1, WOOD[2]); px(im, x, 2, WOOD[1] if x > 5 else WOOD[2])
    for i in range(1, 4): px(im, 4 + i, 2 + i, WOOD[1]); px(im, 4 + i, 3 + i, WOOD[0])      # puntal
    return im


def sign_plank():
    im = new(30, 12)
    for x in (4, 25):                                      # las cuerdas
        px(im, x, 0, ROPE); px(im, x, 1, ROPE)
    for y in range(2, 12):                                 # tablón: contorno, cara, luz arriba, sombra abajo
        for x in range(30):
            edge = y in (2, 11) or x in (0, 29)
            c = WOOD[0] if edge else (WOOD[3] if y == 3 else (WOOD[1] if y == 10 else WOOD[2]))
            px(im, x, y, c)
    for (x, y) in ((3, 3), (26, 3), (3, 10), (26, 10)): px(im, x, y, IRON[2])               # clavos
    return im


def sign_spark(f):
    im = new(5, 5)
    on = [(2, 0), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (2, 1), (2, 3), (2, 4)] if f == 0 else [(2, 2), (1, 1), (3, 1), (1, 3), (3, 3)]
    for (x, y) in on: px(im, x, y, GOLD[0] if (x, y) == (2, 2) else GOLD[1])
    return im


def sign_sheet():
    out = new(34, 49)
    out.alpha_composite(sign_post(), (0, 0)); out.alpha_composite(sign_plank(), (0, 32))
    out.alpha_composite(sign_spark(0), (0, 44)); out.alpha_composite(sign_spark(1), (5, 44))
    return out


# ── Vista previa: el mapa como lo dibuja FlappyMapState (sitios de ejemplo, como los de Zones.lua) ─────────────────
EXAMPLE = [('shop', 0.08, 0.60), ('open', 0.27, 0.52), ('locked', 0.46, 0.38), ('locked', 0.66, 0.50),
           ('boss', 0.88, 0.44)]


def mock(win_w, art):
    bg, pil, nst, bos, shp = art
    cv = Image.new('RGBA', (win_w, 720))
    big = J.up(bg, S)
    x = (win_w - big.width) // 2
    while x > 0: x -= big.width
    while x < win_w:
        cv.paste(big, (x, 0)); x += big.width             # (el fondo es opaco)
    mw = min(win_w, 1280)
    x0 = (win_w - mw) // 2
    gy = 720 - (180 - GROUND) * S
    for (kind, nx, ny) in EXAMPLE:
        cx, cy = x0 + int(nx * mw), int(ny * 720)
        need = (gy - cy) // S + 4                           # filas del pilar hasta un poco bajo la hierba
        top = pil.crop((0, 0, 18, max(1, need - BASE_H)))
        cv.alpha_composite(J.up(top, S), (cx - 36, cy))
        cv.alpha_composite(J.up(pil.crop((0, PILLAR_H - BASE_H, 18, PILLAR_H)), S), (cx - 36, cy + (need - BASE_H) * S))
        if kind == 'shop': cv.alpha_composite(J.up(shp[0], S), (cx - 48, cy - 21 * S))
        elif kind == 'boss': cv.alpha_composite(J.up(bos[0], S), (cx - 48, cy - 27 * S))
        else: cv.alpha_composite(J.up(nst[('open', 'done', 'locked').index(kind)], S), (cx - 48, cy - 19 * S))
    return cv


def sprite_sheet(art):
    bg, pil, nst, bos, shp = art
    out = Image.new('RGBA', (1100, 760), hx('8ec0dc'))
    J.label(out, 'mapa del Valle - sprites a x8 (nidos: abierta / superada / cerrada; jefe: abierto / vencido / cerrado; tienda)', (12, 10), 8)
    x = 12
    for im in nst:
        out.alpha_composite(J.up(im, 8), (x, 40)); x += 24 * 8 + 12
    x = 12
    for im in bos:
        out.alpha_composite(J.up(im, 8), (x, 240)); x += 24 * 8 + 12
    x = 12
    for im in shp:
        out.alpha_composite(J.up(im, 8), (x, 470)); x += 30 * 8 + 12
    out.alpha_composite(J.up(pil.crop((0, 0, 18, 40)), 4), (980, 40))
    out.alpha_composite(J.up(pil.crop((0, PILLAR_H - BASE_H, 18, PILLAR_H)), 4), (980, 220))
    return out


def build():
    return background(), pillar(), nests(), bosses(), shops()


def main():
    os.makedirs(PREV, exist_ok=True)
    art = build()
    a, b = mock(1280, art), mock(960, art)
    out = Image.new('RGB', (1280, 720 * 2 + 20), hx('20242a'))
    out.paste(a.convert('RGB'), (0, 0)); out.paste(b.convert('RGB'), (0, 740))
    J.label(out, '1280', (12, 12), 12); J.label(out, '960', (12, 752), 12)
    out.save(os.path.join(PREV, 'mapa_vista_previa.png'))
    sprite_sheet(art).convert('RGB').save(os.path.join(PREV, 'mapa_sprites.png'))
    print('vista previa:', os.path.join(PREV, 'mapa_vista_previa.png'), '+ mapa_sprites.png')
    if APPLY: apply(art)


def apply(art):
    bg, pil, nst, bos, shp = art
    os.makedirs(OUT, exist_ok=True)
    for name, im in (('valle_bg', bg), ('valle_pillar', pil), ('valle_nest-Sheet', sheet(nst)),
                     ('valle_boss-Sheet', sheet(bos)), ('valle_shop-Sheet', sheet(shp))):
        path = os.path.join(OUT, name + '.png')
        if os.path.exists(path) and not FORCE: print('  %s ya existe: no se toca (--force)' % os.path.relpath(path, REPO)); continue
        im.save(path); print('  %-46s %dx%d' % (os.path.relpath(path, REPO), im.width, im.height))
    path = os.path.join(OUT, 'valle_sign.png')          # el cartel es nuevo: se escribe solo si no existe (--force no hace falta)
    if os.path.exists(path) and not FORCE: print('  valle_sign.png ya existe: no se toca (--force)')
    else: sign_sheet().save(path); print('  valle_sign.png 34x49')


if __name__ == '__main__':
    main()
