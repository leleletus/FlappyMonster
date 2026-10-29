"""Isla de la JUNGLA, nivel 2: «RÍO REVUELTO» (The Churning River) — el valle que se cruza DOS VECES.

IDA (de izquierda a derecha, por el CAUCE SECO, fila del suelo G = 23): charcas hondas con PIRAÑAS que saltan al pasar,
TOPOS en los montículos de barro de las orillas y una poza honda con una CAJA en el fondo que hay que empujar hasta la
pared para poder salir. Punto de control 1 en lo más hondo del valle. Al final, la PRESA: un templo con el Activador
(cabezazo desde abajo) que INUNDA el valle (inundación `control = 'switch'`) y abre la puerta (Bloques OFF) de la
escalera de la torre; el agua sube detrás mientras se trepa.
VUELTA (de derecha a izquierda, por ARRIBA, fila 14, la superficie del agua en lo alto de la fila 15): islas, puentes de
liana y ruinas a ras de agua sobre el valle inundado. Las pirañas de las charcas suben con el agua (su área de nado va
de la charca a la superficie); las PLANTAS carnívoras de las caras de las islas, a ras de agua, se comen a las que
saltan detrás de ti (aliadas); un GÉISER sobre una losa hundida te sube a una peña alta; una BALANZA con una caja en
un platillo deja el otro ARRIBA, de escalón hacia una peña. La meta está ENCIMA de la salida.

Reglas que hacen que el orden se cumpla (y nada se salte en seco):
  · Lo de arriba queda a ≥ 7 casillas del cauce: en seco solo se sube por la torre de la presa, cerrada por Bloques
    OFF hasta que se pulsa el Activador (que inunda).
  · Caer al agua en la vuelta no atasca: ESCALERAS de Bloques ON (inactivos — solo el contorno — en la ida) suben del
    cauce a la isla de antes del hueco; las enciende el mismo Activador. Una junto al punto de control 1 (reaparecer
    tras la inundación es bajo el agua: se sube por ella).
  · El jugador NO flota (se hunde; bajo el agua salta 1,1 y 2,27 con el doble): la vuelta va por encima del agua.

Comprobación (level_solve no sabe usar Activadores, cajas, géiseres ni balanzas):
    SOLVE=go  python3 tools/levelgen/build.py --only rio_revuelto --out <dir>   → la IDA: meta provisional en la sala del
              Activador; la caja, un bloque fijo donde acaba empujada
    SOLVE=go_nobox  (igual, sin la caja: debe FALLAR — la poza no se sale sin ella)
    SOLVE=dry  (la meta de verdad, sin poder pulsar el Activador: debe FALLAR — no hay atajo en seco)
    SOLVE=ret python3 ... → la VUELTA: agua a tope fija, Activador en ON (escaleras sólidas, puerta abierta), salida en la
              sala del Activador; el platillo alto de la balanza, una tabla fija (se llega por las escaleras: el géiser
              no lo modela)
    SOLVE=ret_top  (la vuelta SOLO por arriba: escaleras apagadas y el chorro del géiser como tablas)
    RSTART=c,r / RGOAL=c,r (con ret / ret_top): otra salida (81,22 = el punto de control 1 ya inundado) u otra meta
              (28,16 = dentro de la ruina de la estrella escondida)
    El --out ha de quedar bajo assets/levels/ (p. ej. assets/levels/_rio_go; level_solve lee por love.filesystem):
    borrarlo después. Resultados (2026-10-29): go OK, go_nobox FALLA, dry FALLA (EXPLORE: nada por encima de la fila 17),
    ret OK, ret_top OK, ret+RSTART=81,22 OK, ret_top+RSTART=36,13+RGOAL=28,16 OK.
    python3 tools/levelgen/build.py --only rio_revuelto && python3 tools/levelgen/retheme.py rio_revuelto
    python3 tools/levelgen/add_apples.py --checkpoints 1 rio_revuelto
"""
import os
from lib import *

SOLVE = os.environ.get('SOLVE', '')
ID_HIGH = 2 ** 17


def enc(i): return i % 16 + (i // 16) * ID_HIGH


SW_ON, SW_OFF = 13, 14
ONB, ONB_X, OFFB, OFFB_X = enc(18), enc(19), enc(27), enc(28)
TEMPLE = enc(42)
ON = SOLVE in ('ret', 'ret_top')       # (variante resuelta de la vuelta: Activador en ON)
TOP = SOLVE == 'ret_top'               # (…y solo POR ARRIBA: escaleras apagadas; el géiser, tablas)

W, H = 160, 28
G = 23          # fila del suelo del cauce (de pie en la 22)
U = 14          # fila de las islas de la vuelta (de pie en la 13)
SURF = 15       # el agua de la inundación llega a lo alto de esta fila
SW = (150, 20)  # el Activador de la presa


def rio_revuelto():
    L = Level('Río Revuelto', W, H, (5, G - 1), music='jungla_2', modes=['race', 'hide'])
    L.extra.update(name_en='The Churning River', background='jungle', time='dusk')
    L.ground(2, W - 1, G)
    blinks = []

    # ── piezas ───────────────────────────────────────────────────────────────
    def island(c0, c1, top=U, thick=2, v=SOLID):
        L.rect(c0, top, c1, top + thick - 1, v)

    def puddle(c0, c1, depth=2):
        L.rect(c0, G, c1, G + depth - 1, WATER)

    def mound(c0, c1):
        """Montículo de barro de la orilla (1 y 2 de alto): el Topo vive arriba"""
        L.rect(c0, G - 1, c1, G - 1)
        L.rect(c0 + 2, G - 2, c1 - 2, G - 2)
        L.ent('mole', (c0 + c1) // 2, G - 3, isle='auto', patrol={'left': c0 + 2, 'right': c1 - 2})

    def stair(c, right):
        """Escalera de Bloques ON del cauce a la superficie (8 peldaños sueltos en diagonal, de 1 en 1): sale de (c, 22)
        y acaba en la fila 15, junto a la isla"""
        d = 1 if right else -1
        for k in range(8):
            cc, rr = c + d * k, G - 1 - k
            assert L.get(cc, rr) == EMPTY, 'escalera: (%d,%d) ocupado' % (cc, rr)
            L.set(cc, rr, ONB if ON and not TOP else ONB_X)
            blinks.append({'col': cc, 'row': rr, 'from': list(SW)})

    def piranha(c, r, pts):
        L.ent('piranha', c, r, area=[{'col': a, 'row': b} for a, b in pts])

    def plant(c, r, mount=None):
        if mount: L.ent('carnivoreplant', c, r, mount=mount)
        else: L.ent('carnivoreplant', c, r)

    # ── IDA: el cauce ────────────────────────────────────────────────────────
    # 1. Salida (2-19): bajo la losa de la meta. Primer Topo en la orilla.
    mound(10, 17)
    # 2. Charca 1 (20-23), piraña (sube al hueco G con el agua)
    puddle(20, 23)
    piranha(21, G + 1, [(20, 24), (23, 24), (26, 19), (26, 15), (24, 15), (21, 22)])
    # (bajo la ruina de la estrella escondida, 27-31: cauce llano)
    # 3. Escalera S4 (32-39) → isla U8 (vuelta: huecos 38-39, G y la cámara)
    stair(32, True)
    # 4. La POZA de la caja (45-53): el cauce baja un escalón (la orilla de enfrente, 54-55, en la fila 24) y la poza
    #    tiene 2 de agua por debajo de esa orilla; la caja en el fondo — se empuja hasta la pared de la derecha y desde
    #    ella se sale (bajo el agua no se suben 2 hasta la superficie: comprobado con SOLVE=go_nobox). A la izquierda,
    #    escalones de 1 para volver a salir por donde se entró.
    L.clear(45, G, 55, G)
    L.clear(45, G + 1, 53, G + 2)
    L.rect(45, G + 1, 53, G + 2, WATER)
    L.set(45, G + 1, SOLID); L.set(45, G + 2, SOLID)              # escalón (a ras del agua)
    L.set(46, G + 2, SOLID)                                        # escalón
    if SOLVE in ('go', 'dry'):
        L.set(53, G + 2, SOLID)                                    # (la caja, ya empujada contra la pared)
    elif not ON and SOLVE != 'go_nobox':
        L.ent('box', 48, G + 2, respawn=4)
    # 5. Escalera S3 (55-62) → isla U6 (vuelta: huecos E y F)
    stair(55, True)
    # 6. Charca 3 (64-68), piraña (huecos E y F)
    puddle(64, 68)
    piranha(66, G + 1, [(64, 24), (68, 24), (68, 20), (62, 16), (62, 15), (49, 15), (49, 16), (58, 20), (64, 22)])
    # 7. Topo 2 (71-78) y lo más hondo del valle: punto de control 1 y la escalera S2 (84-91) → U4 (la balanza)
    mound(71, 78)
    L.ent('checkpoint', 81, G - 1)
    stair(84, True)
    # 8. Charca 4 (93-98), ancha: una tabla de liana encima; piraña (hueco D, el de la balanza)
    puddle(93, 98)
    L.plat(94, 97, G - 2)
    piranha(95, G + 1, [(93, 24), (98, 24), (98, 21), (91, 16), (91, 15), (83, 15), (83, 16), (90, 21), (93, 22)])
    L.ent('star', 95, G - 5)                                       # (estrella 1: salto desde la tabla)
    # 9. Topo 3 (100-106); charca 5 (108-111, hueco C del géiser) y la escalera S1 (114-107) → peña H1
    mound(100, 106)
    puddle(108, 111)
    piranha(109, G + 1, [(108, 24), (111, 24), (112, 21), (112, 15), (107, 15), (107, 17), (108, 21)])
    stair(114, False)
    # 10. Topo 4 (116-123); escalera S0 (130-137) → U1 (huecos A y B); charca 6 (134-138), piraña (huecos A y B)
    mound(116, 123)
    stair(130, True)
    puddle(134, 138)
    piranha(136, G + 1, [(134, 24), (138, 24), (137, 19), (137, 15), (124, 15), (124, 16), (130, 19), (134, 22)])

    # ── LA PRESA (146-159): templo con el Activador; la torre con la escalera, cerrada por Bloques OFF ──────────────
    L.rect(146, 12, 159, G - 1, TEMPLE)
    L.clear(147, 18, 152, G - 1)                                   # la sala del Activador
    L.clear(146, 20, 146, G - 1)                                   # la puerta de la presa
    L.clear(154, 2, 158, G - 1)                                    # el hueco de la escalera (abierto arriba)
    L.set(*SW, SW_ON if ON else (TEMPLE if SOLVE == 'dry' else SW_OFF))   # cuelga del techo de la sala
    # (SOLVE=dry: sin Activador — el solver lo pulsaría y cambiaría el nivel para toda la búsqueda —: la meta NO se
    # puede alcanzar en seco; EXPLORE=1 no llega a nada de arriba)
    L.rect(SW[0], 18, SW[0], 19, TEMPLE)
    L.extra['links'] = [{'col': SW[0], 'row': SW[1], 'to': 1}]
    for r in range(18, G):                                         # la puerta de la escalera
        L.set(153, r, OFFB_X if ON else OFFB)
        blinks.append({'col': 153, 'row': r, 'from': list(SW)})
    for k, r in enumerate(range(G - 2, 12, -2)):                   # tablas en zigzag hasta arriba
        a = 154 if k % 2 == 0 else 156
        L.plat(a, a + 2, r)
    # (la torre: de la última tabla, fila 13, a la azotea, fila 12)

    # ── VUELTA: lo de arriba (de derecha a izquierda) ───────────────────────────────────────────────────────────
    island(138, 144)                                               # U1 (hueco 145 con la azotea)
    # hueco A (134-137): piraña de la charca 6
    L.plat(127, 133, U)                                            # U2: puente de liana a ras de agua
    # hueco B (124-126): planta en la cara de U3, a ras de agua
    island(116, 123)                                               # U3
    plant(124, U, 'wall_left')
    # hueco C (107-115): losa hundida con el GÉISER → la peña H1; si no, al agua y escalera S1
    L.rect(113, 17, 115, 17, TEMPLE)
    L.ent('geyser', 114, 16, height=7, interval=2.5, warn=0.8, erupt=2.6, firstDelay=1)
    if TOP:
        for r in (15, 13, 11): L.plat(114, 114, r)                 # (para el solver: lo que sube el chorro)
    L.ent('star', 114, 11)                                         # (estrella 2: en lo alto del chorro)
    island(101, 106, 13, 3)                                        # H1 (peña, de pie en la 12)
    island(92, 100)                                                # U4
    plant(96, U - 1)                                               # (una planta en el suelo de U4: se salta)
    # hueco D (83-91): la BALANZA. Polea en (86, 9), platillos 83-85 y 87-89 a ras de U4; una caja grande en el de la
    # izquierda lo hunde y deja el derecho ARRIBA (~fila 11,6): el escalón a la peña U5. Quien se sube al alto pesa 1
    # y la caja 2: no baja.
    if ON:
        L.plat(87, 89, 12)                                         # (para el solver: el platillo alto, fijo)
    else:
        L.ent('scale', 86, 9, span=4, drop=4.5, travel=2.5)
        L.ent('box', 84, 13, respawn=6)
    island(77, 82, 11)                                             # U5: peña alta
    island(63, 76)                                                 # U6
    plant(69, U - 1)
    # hueco E (60-62): la escalera S3 acaba aquí (sin planta: no se pisan)
    island(52, 59)                                                 # U7
    # hueco F (49-51): planta en la cara de U8
    island(40, 48)                                                 # U8
    plant(49, U, 'wall_left')
    L.ent('checkpoint', 43, U - 1)
    # huecos 38-39
    L.plat(32, 37, U)                                              # U9: puente de liana
    # La RUINA de la estrella escondida (27-31, filas 12-18): hueca, con una entrada BAJO EL AGUA en su cara izquierda
    # (filas 15-16); dentro queda AIRE por encima de la superficie (filas 13-14). En seco la entrada está a 6 del cauce.
    L.rect(27, 12, 31, 18, TEMPLE)
    L.clear(28, 13, 30, 16)
    L.clear(27, 15, 27, 16)
    L.set(30, 16, TEMPLE)                                          # escalón dentro (de pie, la cabeza fuera del agua)
    L.ent('star', 30, 14)                                          # (estrella 3, escondida)
    plant(29, 11)                                                  # (planta encima de la ruina: se salta)
    # hueco G (24-26)
    island(16, 23)                                                 # U10
    island(12, 15, 12)                                             # escalón
    L.rect(2, 10, 11, 11, TEMPLE)                                  # la losa de la META, encima de la salida
    if SOLVE in ('go', 'go_nobox'):
        L.finish(148, G - 1)                                       # (la ida acaba en la sala del Activador)
    elif os.environ.get('RGOAL'):                                  # (para el solver: otra meta — p. ej. dentro de la ruina)
        L.finish(*[int(x) for x in os.environ['RGOAL'].split(',')])
    else:
        L.finish(4, 9)
    if ON:
        L.start = [149, G - 1]
        if os.environ.get('RSTART'):                               # (otra salida: p. ej. el punto de control 1 ya inundado)
            L.start = [int(x) for x in os.environ['RSTART'].split(',')]

    # ── la INUNDACIÓN ────────────────────────────────────────────────────────────────────────────────────────────
    flood = dict(corner={'col': W - 1, 'row': H - 1}, id=1, maxLevel=H - SURF)
    if ON:
        flood.update(startLevel=H - SURF)                          # (la vuelta: el agua ya arriba, fija)
    else:
        flood.update(control='switch', startLevel=0, riseSpeed=1.0, riseStep=3, risePause=0.7, fallSpeed=1.0)
    L.ent('flood', 2, 10, **flood)
    L.extra['blockLinks'] = blinks
    backplane(L, blinks)
    return L


# Pilares del PLANO DE FONDO bajo las islas de la vuelta (que no parezcan flotar: son los restos de un acueducto del
# templo), (col0, col1, fila de debajo de la isla). Se ponen a mano; lo demás del plano lo genera `retheme.py --bg`
# (tools/levelgen/bg_gen/rio_revuelto.json) y este constructor lo VUELVE A PONER al reconstruir (build.py lo borraría).
#   Primera vez:  NOBG=1 build.py --only rio_revuelto → retheme.py --bg rio_revuelto → build.py --only … → retheme.py …
PIERS = [(140, 141, 16), (119, 120, 16), (103, 104, 16), (98, 99, 16), (79, 80, 13), (66, 67, 16), (72, 73, 16),
         (55, 56, 16), (43, 44, 16), (19, 20, 16), (13, 14, 14), (2, 3, 12)]


def backplane(L, blinks):
    if os.environ.get('NOBG'):
        return
    stairs = {(b['col'], b['row']) for b in blinks}
    for a, b, r0 in PIERS:
        for c in range(a, b + 1):
            for r in range(r0, H):
                if L.get(c, r) not in (EMPTY,) or (c, r) in stairs:
                    if r > r0 and L.get(c, r) != EMPTY and (c, r) not in stairs: break      # (hasta el suelo)
                    continue
                L.set_bg(c, r, TEMPLE)
    # (por dentro, los templos tienen pared al fondo: la sala del Activador, la escalera de la torre y la ruina de la
    # estrella escondida — así se leen como salas y la estrella no se ve tanto desde fuera)
    for c0, r0, c1, r1 in ((147, 18, 152, G - 1), (154, 12, 158, G - 1), (27, 13, 30, 16)):
        for c in range(c0, c1 + 1):
            for r in range(r0, r1 + 1):
                if L.get(c, r) != TEMPLE: L.set_bg(c, r, TEMPLE)
    side = os.path.join(os.path.dirname(__file__), 'bg_gen', 'rio_revuelto.json')
    if os.path.exists(side):
        import json
        rec = json.load(open(side))
        for c, r, v in rec.get('tiles', []):
            if L.bg is None or L.bg[r - 1][c - 1] == EMPTY: L.set_bg(c, r, v)
        L.foliage += rec.get('decos', [])


BUILDERS = [rio_revuelto]
