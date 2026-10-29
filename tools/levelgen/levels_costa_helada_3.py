"""La Costa Helada, nivel 4: «BAJO EL HIELO» (Under the Ice) — el último antes del jefe (glaciar_cangrejo).

Diseño aprobado por el usuario: FlappyMonster_pruebas/islas_heladas/diseno.md § B (Costa Helada 4). Se nada BAJO una
capa de hielo (la fila S) en AGUA HELADA (`coldWater`: a los COLD s con el cuerpo dentro te congelas — el bloque de hielo
de siempre: machacar botones —; fuera del agua se pone a cero). Lo distinto de los otros niveles de agua
(arrecife_globo: se anda por el fondo y se respira en islotes; laberinto_submarino: cámaras con bolsas de aire):
  · DOS medidores: el AIRE se recupera sacando la cabeza (agujeros de HIELO FINO que se rompen de un cabezazo desde
    abajo — 4 golpes —, y la CAMPANA de aire bajo la quilla de un iceberg), pero el FRÍO solo se quita sacando el
    CUERPO del agua: en las BOLSAS de aire (cúpulas de hielo con repisa), en las orillas y encima de los TÉMPANOS.
  · El hielo fino que tiene una REPISA debajo es una salida (el atajo, la estrella escondida); sin repisa, solo se
    respira (de un pasillo de 2 de alto no se sale: el doble salto bajo el agua sube 2,27; para salir hacen falta 3).
  · Carámbanos (pinchos hacia abajo) en el techo de un tramo: ahí no se salta. Crabbies helados en el fondo y colgados
    del techo (caen al verte), peces globo en las fosas.
  · TÉMPANOS: en la grieta abierta (el tramo 4) flotan témpanos pequeños que se HUNDEN si te quedas encima (aguantan
    0,5: un jugador los hunde en 0,7 s) y vuelven a SUBIR al quitarte; al pie del glaciar, un témpano grande que hay
    que EMPUJAR nadando (por el bajío) hasta cerca de la pared para subir al glaciar.

Tramos (columnas; S = 12 la capa de hielo, de pie encima en la fila 11; el pasillo de abajo tiene el fondo en la 15):
  1  2-18    la orilla nevada (salida) y el agujero de pesca; un iceberg encallado en el hielo (no se anda por encima)
  2  19-44   el primer pasillo: dos agujeros de hielo fino para respirar, un Crabby en el fondo, el primer IGLÚ (bolsa de aire)
  3  45-70   la FOSA: el fondo baja a la fila 20; una quilla de hielo, el gran iceberg encallado con la CAMPANA de aire
             bajo su quilla (estrella 1 dentro), peces globo; la escalera sube a la grieta: la orilla con el punto de
             control 1
  4  71-92   la GRIETA abierta (bajo la aurora): cuatro témpanos que se hunden; estrella 2 en lo alto; debajo, agua
             honda con peces globo y una escalera de rescate. Una pared de hielo bajo la orilla de la derecha: a nado no
             se pasa
  5  93-135  el agujero, el iceberg de la ESTRELLA ESCONDIDA (hielo fino con repisa bajo su base: dentro hay una
             cueva); el techo de CARÁMBANOS con Crabbies colgados y un respiradero entre medias; el segundo IGLÚ con el punto
             de control 2; el ATAJO (hielo fino con repisa: sale arriba y se va por encima del canal); el CANAL hondo
             con peces globo y la escalera a la poza
  6  136-165 el BAJÍO al pie del glaciar: el témpano grande se empuja; del témpano al primer escalón del glaciar;
             arriba, hielo resbaladizo con un Pingüino (pisado, trineo) y la meta

Cómo se hace:
    python3 tools/levelgen/build.py --only bajo_el_hielo
    python3 tools/levelgen/retheme.py bajo_el_hielo          (terreno y decoraciones de la Costa Helada)
    (la comida la pone el constructor, una junto a cada punto de control: add_apples ponía la del iglú FUERA de él)

Comprobación (level_solve no sabe de témpanos — son entidades —, ni rompe el hielo fino de forma fiable):
    SOLVE=route   los témpanos como bloques de hielo fijos (los de la grieta en su sitio; el grande, YA EMPUJADO)
    SOLVE=home    igual, pero el témpano grande donde empieza: debe FALLAR (hay que empujarlo)
    SOLVE=nolead  sin los témpanos de la grieta: debe FALLAR (a nado no se pasa la grieta)
    SOLVE=nobig   sin el témpano grande: debe FALLAR (del bajío al glaciar no se sube)
    SOLVE=short   el hielo fino del atajo ya roto y el canal tapado; sale del punto de control 2: debe llegar (por arriba)
    SOLVE=secret  el hielo fino de la estrella escondida ya roto; la meta, en su cueva: debe llegar
    SOLVE=skip1   los respiraderos del tramo 2 ya rotos; la meta, encima de la capa: debe FALLAR (por un respiradero
                  no se sale: no tiene repisa)
    SOLVE=skip2   los del tramo 5 rotos, el atajo macizo y el canal tapado; sale de la orilla 92; la meta encima de la
                  capa (125): debe FALLAR
    SOLVE=x python3 tools/levelgen/build.py --only bajo_el_hielo --out assets/levels/_bajo  → run.sh level_solve -- …
    (borrar assets/levels/_bajo después)
"""
import os
from lib import *

SOLVE = os.environ.get('SOLVE', '')
ID_HIGH = 2 ** 17
WBIT = 16                      # (la casilla, además, encharcada: TileCodec.FLAG_WATER)


def enc(i): return i % 16 + (i // 16) * ID_HIGH


ICE, THIN, SNOW = enc(30), enc(31) + WBIT, enc(29)       # hielo (resbala), hielo fino ENCHARCADO (roto → agua)
GLACIER, IROCK, LEDGE = enc(53), enc(51), enc(58) + WBIT  # hielo glaciar, roca helada, repisa de hielo encharcada
SBRICK = enc(54)                                          # bloque de nieve: los IGLÚS de los pescadores (las bolsas)

W, H = 166, 24
S = 12          # la CAPA DE HIELO (de pie encima en la 11)
F = 15          # el fondo del pasillo de debajo (de pie en la 14: dos de agua hasta el hielo)
COLD = 7        # s en el agua helada hasta congelarse (× el aire de la dificultad)
# variantes del buscador: el hielo fino que ya está ROTO (agua) o que es MACIZO
OPENED = {'short': {'short'}, 'secret': {'secret'}, 'skip1': {'b1'}, 'skip2': {'b2'}}
SHUT = {'skip2': {'short'}}


def bajo_el_hielo():
    L = Level('Bajo el Hielo', W, H, (5, S - 1), music='nieve_1', modes=['race', 'hide'])
    L.extra.update(name_en='Under the Ice', background='frozen_coast', time='night', depth='underwater',
                   surfaceRow=S, coldWater=COLD, spikeSkin='ice', snow=True)
    solid = SOLVE != ''                                     # (variantes del buscador: témpanos como bloques)

    # ── el mar bajo el hielo ─────────────────────────────────────────────────────────────────────────────────────
    L.rect(2, S + 1, W - 1, H - 1, WATER)                   # agua de la fila 13 abajo
    L.rect(2, S, W - 1, S, ICE)                             # la capa de hielo
    L.ground(2, W - 1, F, IROCK)                            # el fondo del pasillo, de roca helada (se cava en las fosas)

    def sea(c0, c1, floor):
        """El fondo de c0..c1 en la fila `floor` (agua hasta ella)"""
        L.rect(c0, S + 1, c1, floor - 1, WATER)
        L.rect(c0, floor, c1, H - 1, IROCK)

    def opening(c0, c1, top=S):
        """Agua abierta al cielo en la capa de hielo (c0..c1)"""
        L.rect(c0, top, c1, S, WATER)

    def rung(c, r):
        L.set(c, r, LEDGE)

    def ladder(c, r0, r1, step=1):
        """Escalera de repisas de una en una fila (r0 abajo → r1 arriba), alternando c y c+step"""
        for k, r in enumerate(range(r0, r1 - 1, -1)):
            rung(c + (k % 2) * step, r)

    def thin(c, tag):
        """Hielo fino en la capa (respiradero / salida); en las variantes del buscador, ya roto (agua) o macizo"""
        L.set(c, S, WATER if tag in OPENED.get(SOLVE, ()) else (ICE if tag in SHUT.get(SOLVE, ()) else THIN))

    def tower(c0, tops, keel=None):
        """Iceberg ENCALLADO en el hielo: una columna por cada fila de `tops` (su cima), hasta la capa. Ninguna cima
        por debajo de la fila 8: desde la capa (de pie en la 11) el doble salto sube 3 y no se sube encima. `keel` =
        hasta qué fila baja su quilla bajo el agua"""
        for k, top in enumerate(tops):
            assert top <= 8
            L.rect(c0 + k, top, c0 + k, S - 1, GLACIER)
        if keel:
            L.rect(c0, S + 1, c0 + len(tops) - 1, keel, GLACIER)

    def pocket(o, left=2, right=3):
        """BOLSA de aire: el IGLÚ de un pescador sobre su agujero (aire en las filas S-2..S-1) con la boca en o, o+1 y
        dos repisas debajo (fila S+2 en o, S+1 en o+1): se sube y se sale del agua (se quita el frío)"""
        c0, c1 = o - left, o + 1 + right
        L.rect(c0 - 1, S - 2, c1 + 1, S - 1, SBRICK)
        L.rect(c0, S - 3, c1, S - 3, SBRICK)                # (el techo, sin las esquinas: redondo)
        L.clear(c0, S - 2, c1, S - 1)
        for c in range(c0, c1 + 1):                         # (por dentro, pared de nieve en el plano de fondo)
            for r in (S - 2, S - 1): L.set_bg(c, r, SBRICK)
        opening(o, o + 1)
        rung(o, S + 2); rung(o + 1, S + 1)

    def puffer(pts, **kw):
        c = sum(p[0] for p in pts) // len(pts)
        r = sum(p[1] for p in pts) // len(pts)
        L.ent('pufferfish', c, r, area=[{'col': a, 'row': b} for a, b in pts], **kw)

    def floe(c, w, **kw):
        if solid:
            L.rect(c, S, c + w - 1, S, ICE)                 # (para el buscador: un bloque fijo a ras de agua)
        else:
            L.ent('iceberg', c, S, width=w, **kw)

    # ── 1. la orilla (2-18) ──────────────────────────────────────────────────────────────────────────────────────
    L.rect(2, S, 12, H - 1, IROCK)
    L.rect(2, S, 12, S + 1, SOLID)                          # tierra nevada (retheme: nieve)
    opening(13, 14)                                         # el agujero de pesca
    tower(15, [7, 4, 3, 5, 8])                              # iceberg encallado: por encima no se sigue
    L.rect(16, S + 1, 18, S + 1, GLACIER)                   # (su quilla, corta)

    # ── 2. el primer pasillo (19-44) ─────────────────────────────────────────────────────────────────────────────
    thin(22, 'b1')                                          # respiradero 1
    L.walker('crabby_ice', 27, F - 1, 25, 30)
    thin(29, 'b1'); thin(30, 'b1')                          # respiradero 2 (doble)
    pocket(35)                                              # IGLÚ 1 (32-40)
    L.ent('crabby_ice_snow', 43, S + 1, attach='ceiling', dropOnSight=True, patrol={'left': 42, 'right': 44})

    # ── 3. la fosa (45-70) ───────────────────────────────────────────────────────────────────────────────────────
    sea(45, 90, 20)
    L.rect(50, S + 1, 51, 16, GLACIER)                      # quilla 1
    tower(56, [8, 5, 3, 4, 6], keel=17)                     # el gran iceberg encallado (quilla hasta la 17)
    L.rect(56, 16, 56, 17, WATER)                           # (la quilla, más estrecha abajo)
    L.clear(58, 16, 59, 17)                                 # la CAMPANA: aire atrapado bajo la quilla (abierta abajo)
    for c, r in ((58, 16), (59, 16), (58, 17), (59, 17)): L.set_bg(c, r, GLACIER)
    L.ent('star', 58, 16)                                   # (estrella 1, dentro)
    puffer([(46, 14), (55, 14), (55, 19), (46, 19)])
    puffer([(53, 18), (64, 18), (66, 15), (68, 19), (53, 19)], range=2)
    ladder(71, 19, 13)                                      # la escalera a la grieta (71/72)
    L.ent('checkpoint', 67, S - 1)                          # punto de control 1, en la orilla de la grieta
    L.ent('apple', 64, S - 1)                               # (comida)

    # ── 4. la grieta abierta (71-92) ─────────────────────────────────────────────────────────────────────────────
    opening(71, 90)
    if SOLVE != 'nolead':
        for c in (74, 78, 82, 86):
            floe(c, 2, capacity=0.5)
    L.ent('star', 80, 8)                                    # (estrella 2: doble salto desde un témpano)
    ladder(84, 19, 13)                                      # escalera de rescate (84/85)
    puffer([(73, 15), (83, 15), (83, 19), (73, 19)])
    puffer([(76, 17), (90, 17), (90, 19), (76, 19)], range=2)
    L.rect(91, S + 1, 92, 19, GLACIER)                      # pared bajo la orilla de la derecha (a nado no se pasa)

    # ── 5. el techo de carámbanos, la bolsa 3, el atajo y el canal (93-135) ─────────────────────────────────────
    opening(94, 95)                                         # el agujero
    tower(96, [6, 3, 4, 7])                                 # iceberg de la ESTRELLA ESCONDIDA
    L.clear(97, S - 2, 98, S - 1)                           # su cueva (de pie en la capa)
    for c, r in ((97, S - 2), (98, S - 2), (97, S - 1), (98, S - 1)): L.set_bg(c, r, GLACIER)
    L.ent('star', 98, S - 2)                                # (estrella 3, escondida)
    thin(97, 'secret')
    rung(97, S + 2); rung(97, S + 1)
    L.ent('crabby_ice_snow', 100, S + 1, attach='ceiling', dropOnSight=True, patrol={'left': 100, 'right': 100})
    for c in list(range(101, 104)) + list(range(106, 109)):
        L.set(c, S + 1, spike_bits(DOWN, (0, 1)) + WBIT)    # carámbanos del techo (no saltar)
    thin(104, 'b2'); thin(105, 'b2')                        # respiradero entre los carámbanos
    L.walker('crabby_ice', 105, F - 1, 104, 106)
    pocket(113)                                             # IGLÚ 2 (110-118)
    L.ent('checkpoint', 116, S - 1)                         # punto de control 2
    L.ent('apple', 111, S - 1)                              # (comida, dentro del iglú)
    L.ent('crabby_ice_icicle', 120, S + 1, attach='ceiling', dropOnSight=True, patrol={'left': 119, 'right': 120})
    # el ATAJO: hielo fino con su repisa; arriba, la capa de hielo hasta la poza (vida extra por el camino)
    thin(121, 'short')
    rung(121, S + 2); rung(121, S + 1)
    L.ent('extralife', 128, S - 1)
    # el canal hondo (123-138) y la escalera a la poza (134/135)
    sea(123, 138, 20)
    if SOLVE in ('short', 'skip2'):
        L.rect(123, S + 1, 123, 19, SOLID)                  # (para el buscador: el canal, tapado)
    L.rect(127, S + 1, 128, 16, GLACIER)                    # quilla
    puffer([(124, 14), (132, 14), (132, 19), (124, 19)])
    puffer([(129, 17), (137, 17), (137, 19), (129, 19)], range=2)
    opening(134, 135)                                       # la poza
    ladder(134, 19, 13)

    # ── 6. el bajío y el glaciar (136-165) ───────────────────────────────────────────────────────────────────────
    # la orilla 136-138 (la capa); el bajío 139-149: una fila de agua sobre roca (se anda empujando el témpano)
    L.rect(139, S + 1, 149, H - 1, IROCK)
    opening(139, 149)
    if SOLVE not in ('nobig',):
        if solid:
            c = 141 if SOLVE == 'home' else 145
            L.rect(c, S, c + 2, S, ICE)
        else:
            L.ent('iceberg', 141, S, width=3)
    # el GLACIAR: escalones de 2 (nieve encima), arriba hielo (el Pingüino resbala)
    L.rect(150, 10, W - 1, S + 1, GLACIER)
    L.rect(150, S + 2, W - 1, H - 1, IROCK)                 # (la roca de debajo del glaciar)
    L.rect(153, 8, W - 1, 9, GLACIER)
    L.rect(156, 6, W - 1, 7, GLACIER)
    L.rect(150, 10, 152, 10, SNOW); L.rect(153, 8, 155, 8, SNOW); L.rect(156, 6, W - 1, 6, ICE)
    L.ent('penguin', 159, 5)

    # ── la meta ──────────────────────────────────────────────────────────────────────────────────────────────────
    goal = os.environ.get('RGOAL')
    if SOLVE == 'secret':
        L.set(98, S - 2, FINISH)                            # (para el buscador: la cueva de la estrella escondida)
    elif SOLVE == 'skip1':
        L.set(25, S - 1, FINISH)                            # (encima de la capa, sobre el primer pasillo)
    elif SOLVE == 'skip2':
        L.set(125, S - 1, FINISH)                           # (encima de la capa, pasado el techo de carámbanos)
    elif goal:
        L.finish(*[int(x) for x in goal.split(',')])
    else:
        L.finish(163, 5)
    if SOLVE == 'short':
        L.start = [116, S - 1]
    if SOLVE == 'skip2':
        L.start = [92, S - 1]                               # (la orilla de la derecha de la grieta)
    if os.environ.get('RSTART'):
        L.start = [int(x) for x in os.environ['RSTART'].split(',')]
    return L


BUILDERS = [bajo_el_hielo]
