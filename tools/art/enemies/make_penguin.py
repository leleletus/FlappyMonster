#!/usr/bin/env python3
# tools/art/enemies/make_penguin.py — el PINGÜINO (`penguin`), enemigo de la Costa Helada. Dos diseños, A y B, con
# todos los cuadros que usa el juego (mira a la DERECHA; el juego lo voltea; cuadro 24x20 con los pies en la fila de
# abajo; escala 4 en el juego):
#   walk1-4  anda como un pato (se balancea de un pie a otro)
#   idle1-2  quieto (parpadea)
#   dive1-2  se tira de barriga (se inclina y se lanza)
#   slide1-2 se desliza de barriga (aletas atrás)
#   dazed1-2 pisado: aturdido de barriga (ojos en espiral; las estrellas las pone el juego, BossFx)
#   ridden1-2 montado como un trineo (aplastado por el peso, aletas abiertas, ojos apretados)
#   getup1   se levanta
#   dead     aplastado
#
# Reglas del usuario para sprites nuevos (memoria "sprite-design-simple-original"): POCOS colores, zonas planas, una
# silueta clara, formas finas y originales (no redondo y gordito como todo lo demás): "si todo es igual, nada nunca
# será nuevo". Cada parte: 3 tonos (contorno, sombra, medio), sin brillos ni motas.
#   A «Torpedo»  un huso largo y fino, negro azulado con la pechera blanca, pico fino y largo naranja. El pingüino de
#                siempre pero estirado: la opción más cercana a la casa.
#   B «Zancos»   la opción ATREVIDA: cuerpo anguloso de facetas rectas inclinado hacia delante, cresta amarilla de
#                pingüino saltarrocas que sale disparada hacia atrás, ojo rojo, pico corto y afilado, y patas
#                LARGAS de 1 px con el pie ancho (la regla de las patas de la casa) — un pingüino zancudo.
#
#   python3 tools/art/enemies/make_penguin.py            → SOLO vistas previas en FlappyMonster_pruebas/pinguino/
#                                                          (vista_previa.png con las dos hojas y la maqueta en el hielo
#                                                          junto al jugador a escala del juego; archivos/ con cada hoja)
#   python3 tools/art/enemies/make_penguin.py --apply A|B [--force]
#          → escribe ese diseño en assets/images/enemies/penguin/penguin-Sheet.png (no pisa la hoja si existe, salvo
#            con --force: así se cambia de diseño) y crea assets/anim/enemies/penguin.json si no existe (los mismos
#            cuadros sirven para los dos diseños; nunca se pisa: se retoca en el editor de animaciones).
# Elegido sin el usuario (2026-10-29, no estaba): B «Zancos» — ver docs/entities/enemies.md § Pingüino. Para cambiar:
#     python3 tools/art/enemies/make_penguin.py --apply A --force
import os, sys, json
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_jungle_enemies import (E, R, Pg, Xf, P, D, render, sheet, r3, tube, Above, Below, LeftOf, margin_ok,  # noqa
                                 hx, ground, big, put, text, FONT, FONTM, FONTB, PLAYER, ID, IMG, ROOT)

OUT = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'pinguino')
FW, FH = 24, 20
S = 4
FRAMES = ['walk1', 'walk2', 'walk3', 'walk4', 'idle1', 'idle2', 'dive1', 'dive2', 'slide1', 'slide2',
          'dazed1', 'dazed2', 'ridden1', 'ridden2', 'getup1', 'dead']
FEET = (11.5, 19.6)                     # pivote de los pies (de pie): se balancea y se tumba alrededor de él

# ══ Paletas (3 tonos: contorno, sombra, medio) ══════════════════════════════════════════════════════════════════
A_BACK = r3('0a0f1e', '1b2440', '2c3a62')
A_BELLY = r3('5a6a84', 'c4d0de', 'f2f6fb')
A_BEAK = r3('6a2806', 'cc5a12', 'f39a2a')
B_BACK = r3('120e22', '2a2448', '3e3668')
B_BELLY = r3('7a6a56', 'e2d4b4', 'fbf1d8')
B_BEAK = r3('6a140c', 'c8381e', 'f0643a')
B_CREST = r3('7a5a06', 'dca81a', 'ffde4a')
EYE_W, EYE_D, EYE_R = 'ffffff', '0a0f1e', 'e8283a'


# ══ A «Torpedo» ═══════════════════════════════════════════════════════════════════════════════════════════════
# (coordenadas propias: DE PIE, mirando a la derecha, pies en la fila 19. `lying` = de barriga: el cuadro gira el
# cuerpo 90°, así que el pico apunta "arriba" en estas coordenadas — delante al tumbarse — y lo de atrás, "abajo")
def A_items(eye='open', flip_up=0, step=0, beak_open=False, lying=False):
    it = []
    if lying:
        it += [P(E(13.0, 18.6, 0.8, 1.6), A_BEAK, shade='none'), P(E(10.6, 18.8, 0.8, 1.6), A_BEAK, shade='none')]
    else:
        lf, rf = (0.6 if step < 0 else 0), (0.6 if step > 0 else 0)
        it += [P(E(9.6, 19.3 - lf, 1.9, 0.75), A_BEAK, shade='none'), P(E(13.6, 19.3 - rf, 1.9, 0.75), A_BEAK, shade='none')]
    body = E(11.5, 10.6, 4.0, 8.4)
    it.append(P(body, A_BACK, shade='none'))
    it.append(P(body & E(13.4, 12.2, 2.6, 6.6), A_BELLY, line=False, shade='none'))
    # pico fino y largo (cerrado: una cuña; abierto: dos)
    if lying:
        it.append(P(Pg([(11.0, 3.4), (11.9, -1.6), (13.0, 3.4)]), A_BEAK, shade='none'))
    elif beak_open:
        it.append(P(Pg([(14.6, 5.0), (19.6, 5.4), (14.6, 6.2)]), A_BEAK, shade='none'))
        it.append(P(Pg([(14.6, 6.6), (18.8, 7.6), (14.6, 7.6)]), A_BEAK, shade='none'))
    else:
        it.append(P(Pg([(14.6, 5.4), (20.0, 6.6), (14.6, 7.4)]), A_BEAK, shade='none'))
    # aleta: una hoja fina, oscura
    it.append(P(E(10.2, 11.6, 1.0, 4.2, 14 - flip_up), r3(A_BACK[0], A_BACK[0], A_BACK[1]), shade='none'))
    it += eye_items(eye, *((10, 5) if lying else (13, 5)), design='A', lying=lying)
    return it


# ══ B «Zancos» ════════════════════════════════════════════════════════════════════════════════════════════════
def B_items(eye='open', flip_up=0, step=0, beak_open=False, lying=False):
    it = []
    if lying:                                              # de barriga: las patas recogidas, solo asoman los pies
        it += [P(E(13.4, 14.6, 0.8, 1.8), B_BEAK, shade='none'), P(E(11.0, 14.8, 0.8, 1.8), B_BEAK, shade='none')]
    else:                                                  # patas de 1 px, largas, y el pie ancho
        lf, rf = (1 if step < 0 else 0), (1 if step > 0 else 0)
        for x, up in ((10, lf), (13, rf)):
            it.append(D([(x, y, B_BEAK[1]) for y in range(13, 18 - up + 1)]))
            it.append(D([(x - 1, 19 - up, B_BEAK[0]), (x, 19 - up, B_BEAK[1]), (x + 1, 19 - up, B_BEAK[1]),
                         (x + 2, 19 - up, B_BEAK[0])]))
    # cuerpo de facetas rectas, inclinado hacia delante; la cola, una punta atrás
    body = Pg([(13.0, 1.9), (15.0, 3.2), (15.9, 7.0), (15.1, 10.6), (12.6, 12.8), (9.6, 12.6), (5.8, 13.6),
               (7.6, 10.0), (8.2, 6.0), (10.6, 2.6)])
    it.append(P(body, B_BACK, shade='none'))
    it.append(P(body & Pg([(13.4, 5.4), (16.2, 7.0), (15.4, 10.8), (12.6, 13.2), (10.8, 12.8), (12.2, 9.4)]),
                B_BELLY, line=False, shade='none'))
    if lying:
        it.append(P(Pg([(12.0, 2.6), (13.4, -1.4), (14.4, 3.2)]), B_BEAK, shade='none'))
    elif beak_open:
        it.append(P(Pg([(15.0, 3.6), (18.6, 4.0), (15.2, 4.8)]), B_BEAK, shade='none'))
        it.append(P(Pg([(15.2, 5.4), (18.0, 6.4), (15.2, 6.4)]), B_BEAK, shade='none'))
    else:
        it.append(P(Pg([(15.0, 3.6), (19.0, 5.0), (15.2, 6.0)]), B_BEAK, shade='none'))
    # aleta: un triángulo largo y fino
    it.append(P(Pg([(9.8, 6.4), (11.4, 7.0), (8.4, 11.6 - flip_up * 0.6)]), r3(B_BACK[0], B_BACK[0], B_BACK[1]), shade='none'))
    # cresta amarilla: dos rayas finas (sin contorno) que salen disparadas hacia atrás desde el ojo
    # (de barriga: hacia "abajo" en estas coordenadas = atrás)
    c1, c2 = B_CREST[1], B_CREST[2]
    if lying:
        it.append(D([(10, 5, c1), (10, 6, c2), (9, 7, c2), (9, 8, c2), (8, 9, c2),
                     (12, 5, c1), (12, 6, c2), (13, 7, c2), (13, 8, c2)]))
    else:
        it.append(D([(14, 3, c1), (13, 3, c2), (12, 3, c2), (11, 2, c2), (10, 2, c2), (9, 1, c2),
                     (12, 5, c1), (11, 5, c2), (10, 5, c2), (9, 6, c2), (8, 6, c2)]))
    it += eye_items(eye, *((11, 4) if lying else (13, 4)), design='B', lying=lying)
    return it


def eye_items(eye, x, y, design, lying=False):
    """El ojo (coordenadas propias: gira con el cuerpo): abierto (blanco + pupila delante; el de B, rojo), cerrado,
    espiral (aturdido), apretado (montado), X (muerto)"""
    pup = EYE_R if design == 'B' else EYE_D
    if eye == 'open':
        return [D([(x, y, EYE_W), (x, y - 1, pup)])] if lying else [D([(x, y, EYE_W), (x + 1, y, pup)])]
    if eye == 'closed': return [D([(x, y, EYE_W), (x + 1, y, EYE_W)])]
    if eye == 'swirl': return [D([(x, y, EYE_W), (x + 1, y, EYE_W), (x + 1, y - 1, EYE_W), (x, y - 1, pup)])]
    if eye == 'squint': return [D([(x, y, EYE_W), (x + 1, y - 1, EYE_W)])]
    if eye == 'x': return [D([(x, y, EYE_W), (x + 1, y - 1, EYE_W), (x + 1, y, EYE_W), (x, y - 1, EYE_W)])]
    return []


# ══ Los cuadros ═══════════════════════════════════════════════════════════════════════════════════════════════
def grounded(im):
    """Baja (o sube) el dibujo hasta que su último píxel esté en la fila de abajo (cada pose pisa el suelo) y, si toca
    un lado del cuadro, lo centra (1 px de margen a los lados)"""
    bb = im.getbbox()
    if not bb: return im
    dx = 0
    if bb[0] < 1 or bb[2] > FW - 1: dx = (FW - (bb[2] - bb[0])) // 2 - bb[0]
    if bb[3] == FH and dx == 0: return im
    out = Image.new('RGBA', im.size)
    out.paste(im, (dx, FH - bb[3]))
    return out


LIE = Xf(rot=90, pivot=(11.5, 10.0), dx=-1.2, dy=4.0)      # de barriga (la cabeza delante, a la derecha)


def frame(design, name):
    items = A_items if design == 'A' else B_items
    L = lambda xf, its: grounded(render(FW, FH, [(xf, its, None)]))
    if name.startswith('walk'):
        k = int(name[-1]) - 1
        rot, step = [(-7, -1), (0, 0), (7, 1), (0, 0)][k]
        return L(Xf(rot=rot, pivot=FEET, dx=0.5), items(step=step, flip_up=abs(rot) // 3))
    if name == 'idle1': return L(Xf(dx=0.5), items())
    if name == 'idle2': return L(Xf(dx=0.5), items(eye='closed'))
    if name == 'dive1': return L(Xf(rot=32, pivot=FEET, dx=0.5), items(beak_open=True, flip_up=2))
    if name == 'dive2': return L(Xf(rot=70, pivot=(11.5, 10.0), dx=-0.2), items(eye='open', flip_up=6, lying=True))
    if name == 'slide1': return L(LIE, items(flip_up=6, lying=True))
    if name == 'slide2': return L(LIE, items(flip_up=3, lying=True))
    if name == 'dazed1': return L(LIE, items(eye='swirl', lying=True))
    if name == 'dazed2': return L(Xf(rot=86, pivot=LIE.p, dx=LIE.dx, dy=LIE.dy), items(eye='swirl', lying=True))
    if name in ('ridden1', 'ridden2'):
        sq = 0.84 if name == 'ridden1' else 0.78
        return L(Xf(rot=90, pivot=LIE.p, dx=LIE.dx, dy=LIE.dy, sx=sq), items(eye='squint', flip_up=-4, lying=True))
    if name == 'getup1': return L(Xf(rot=45, pivot=FEET, dx=0.5), items(flip_up=3))
    if name == 'dead': return L(Xf(rot=90, pivot=LIE.p, dx=LIE.dx, dy=LIE.dy, sx=0.6), items(eye='x', lying=True))
    raise KeyError(name)


def sheets(): return {d: [frame(d, n) for n in FRAMES] for d in 'AB'}


def check(sh):
    bad = []
    for d, fr in sh.items():
        for n, im in zip(FRAMES, fr):
            if not margin_ok(im): bad.append('%s %s' % (d, n))
            bb = im.getbbox()
            if bb and bb[3] != FH: bad.append('%s %s: no toca el suelo (abajo %d)' % (d, n, bb[3]))
    return bad


# ══ Vistas previas ════════════════════════════════════════════════════════════════════════════════════════════
BG = 'b8d0e8'
NAMES = {'A': 'A «Torpedo» (cercano a la casa)', 'B': 'B «Zancos» (el atrevido)'}


def player_on(cv, x, feet, k=0, flip=False):
    im = PLAYER[k]
    put(cv, im, x - im.width * 6 // 2, feet - im.height * 6, 6, flip)


def scene(design, fr):
    """La maqueta a escala del juego (un bloque = 64 px): hielo, el jugador, el pingüino andando, deslizándose y
    montado como un trineo cruzando un hueco"""
    W, H = 1100, 300
    cv = Image.new('RGBA', (W, H), hx(BG))
    floor = 236
    ground(cv, 0, floor, 384, 64, 'snow.png')
    ground(cv, 384, floor, 448, 64, 'ice.png')
    ground(cv, 960, floor, 140, 64, 'ice.png')            # (el hueco de 2 bloques: 832..960)
    g = lambda n: fr[FRAMES.index(n)]
    player_on(cv, 70, floor)
    put(cv, g('walk1'), 150, floor - FH * S)
    put(cv, g('idle1'), 240, floor - FH * S, flip=True)
    put(cv, g('dive1'), 330, floor - FH * S)
    put(cv, g('slide1'), 440, floor - FH * S)
    put(cv, g('dazed1'), 560, floor - FH * S)
    # montado: el jugador de pie sobre la barriga (la cara de arriba del trineo: ver penguin.lua RIDE_TOP)
    put(cv, g('ridden1'), 700, floor - FH * S)
    player_on(cv, 700 + FW * S // 2, floor - 26)
    # cruzando el hueco
    put(cv, g('ridden2'), 850, floor - FH * S - 4)
    player_on(cv, 850 + FW * S // 2, floor - 30)
    text(cv, (10, 8), 'Pingüino ' + NAMES[design] + ' — maqueta a escala del juego (×4; el jugador ×6)', FONT)
    text(cv, (10, 24), 'jugador · anda · quieto · se tira · se desliza · aturdido · montado · cruza un hueco', FONT, 'e8f0ff')
    return cv


def preview(sh):
    fw = FW * S + 10
    W = max(170 + len(FRAMES) * fw, 1100)
    rows = []
    for d in 'AB':
        row = Image.new('RGBA', (W, FH * S + 40), hx('3a4a62'))
        text(row, (8, 6), NAMES[d], FONT)
        for i, (n, im) in enumerate(zip(FRAMES, sh[d])):
            x = 170 + i * fw
            ImageDraw.Draw(row).rectangle((x, 26, x + FW * S - 1, 26 + FH * S - 1), fill=hx(BG))
            row.alpha_composite(big(im), (x, 26))
            text(row, (x, 26 + FH * S + 2), n, FONT)
        rows.append(row)
        rows.append(scene(d, sh[d]))
    H = sum(r.height for r in rows) + 10 * len(rows)
    cv = Image.new('RGBA', (W, H), hx('202838'))
    y = 0
    for r in rows:
        cv.alpha_composite(r, (0, y)); y += r.height + 10
    return cv


ANIM = {
    'id': 'enemies/penguin', 'scale': S, 'origin': [0.5, 1], 'fallback': 'idle',
    'anims': {
        'walk': {'frames': [1, 2, 3, 4], 'fps': 8, 'loop': True},
        'idle': {'frames': [5, 5, 5, 5, 6], 'fps': 4, 'loop': True},
        'dive': {'frames': [7, 8], 'fps': 7, 'loop': False},
        'slide': {'frames': [9, 10], 'fps': 6, 'loop': True},
        'dazed': {'frames': [11, 12], 'fps': 4, 'loop': True},
        'ridden': {'frames': [13, 14], 'fps': 8, 'loop': True},
        'getup': {'frames': [15], 'fps': 6, 'loop': False},
        'dead': {'frames': [16], 'fps': 4, 'loop': False},
    },
}


def apply(sh, design, force):
    d = os.path.join(IMG, 'enemies', 'penguin')
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, 'penguin-Sheet.png')
    if os.path.exists(p) and not force:
        print('  ya existe (usa --force para cambiar de diseño): ' + p)
    else:
        sheet(sh[design]).save(p)
        print('  ' + p + '  (diseño ' + design + ')')
    a = os.path.join(ROOT, 'assets', 'anim', 'enemies', 'penguin.json')
    if os.path.exists(a):
        print('  ya existe (no se pisa): ' + a)
        return
    data = dict(ANIM)
    rel = 'assets/images/enemies/penguin/penguin-Sheet.png'
    data['frames'] = [{'image': rel, 'x': i * FW, 'y': 0, 'w': FW, 'h': FH} for i in range(len(FRAMES))]
    with open(a, 'w') as f: json.dump(data, f, indent=2, sort_keys=True); f.write('\n')
    print('  ' + a)


def main():
    sh = sheets()
    bad = check(sh)
    if bad: print('AVISO márgenes / suelo: ' + ', '.join(bad))
    if '--apply' in sys.argv:
        k = sys.argv.index('--apply')
        design = sys.argv[k + 1] if k + 1 < len(sys.argv) and sys.argv[k + 1] in ('A', 'B') else None
        if not design: sys.exit('--apply A|B')
        apply(sh, design, '--force' in sys.argv)
        return
    os.makedirs(os.path.join(OUT, 'archivos'), exist_ok=True)
    for d in 'AB':
        sheet(sh[d]).save(os.path.join(OUT, 'archivos', 'penguin-%s-Sheet.png' % d))
    preview(sh).save(os.path.join(OUT, 'vista_previa.png'))
    print('  ' + os.path.join(OUT, 'vista_previa.png'))


if __name__ == '__main__':
    main()
