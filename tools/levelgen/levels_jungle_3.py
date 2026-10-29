"""La jungla, nivel 3: «El Templo de los Pesos» (templo_de_los_pesos) — un templo NO LINEAL.

Diseño aprobado por el usuario (FlappyMonster_pruebas/niveles_jungla/diseno.md, §3): un SALÓN central con una
puerta de 3 bloques ON/OFF y TRES ALAS en cualquier orden; cada ala acaba en un Activador que quita un bloque de la
puerta. Dentro del templo (fondo `jungle` + profundidad `temple`), música jungla_1.

    fila  2 ┌───────────── ala de la BALANZA ─────┐┌ ala de las BOCAS ┐
            │  galería del Activador ←·catapulta  ││ C: bomba → planta │→ tolva de vuelta
            │  (S2: caja que cae en un platillo)  ││ B: topo + bocas   │
            │                                     ││ A: Gummy → planta │
         16 ├══════════════════════╗              └──═══ (escalera) ═══┘
         19 │ R1: la PESA (ascensor) │ R0: catapulta │      SALÓN       ║D║ antesala → META   ├ desván del Activador ←┐
            │ caja → platillo        │ de la ESTRELLA│  inicio · CP · comida  ║        (M) topos en el barro ← ┤
         30 └────────────────────────┴───────────────┴── (trampilla) ───────┴──────────────────────────────┐   │
         32                                            L: aterrizaje → topos → escarabajo + cajas → subida ─┘
         39

Medidas (doble salto): 1 salto ≈ 1,6 casillas, doble ≈ 3; escalones de 2 filas; pasillos de 3 de alto.
Platillo de la Balanza: con `drop = n + 0.375` la tabla queda justo en la cara de arriba de una fila (`scale()`).
La catapulta (S2 y R0): de pie en el platillo de la derecha, un cabezazo al Activador de encima suelta la Caja grande
de su repisa (bloque OFF) sobre el platillo de la izquierda: cae 3 casillas (784 px/s ≥ IMPACT_VY 750 → fuerza
2·784/2200 ≈ 0,71) y dispara al jugador con `power` 1,6 (≈ 1230 px/s: unas 7,4 casillas + el salto en el aire).
Si cae con el platillo nivelado (nadie en el otro), cae 5 casillas y se rompe; reaparece (3 s) y vuelve a caer:
basta con subirse al platillo de la derecha y esperar.

Comprobación (level_solve no rompe bloques, no usa Activadores ni balanzas): `OPEN=1` = la variante RESUELTA (puerta
abierta, rompibles fuera, el ascensor como una tabla fija arriba, cada catapulta como un trampolín de su fuerza más
floja); `SOLVE=<ala>` / `SOLVE=<ala>_vuelta` (balanza, bocas, tuneles) mueve la salida y la meta para comprobar CADA ala
de ida (del salón a su Activador) y de vuelta (del Activador al salón) con la puerta cerrada:
    OPEN=1 [SOLVE=bocas] python3 tools/levelgen/build.py --only templo_de_los_pesos --out <carpeta>
"""
import os
from lib import *

ID_HIGH = 2 ** 17
OPEN = bool(os.environ.get('OPEN'))
SOLVE = os.environ.get('SOLVE', '')


def enc(i): return i % 16 + (i // 16) * ID_HIGH


MUD, JGRASS, TEMPLE, JPLAT = enc(40), enc(41), enc(42), enc(43)
SW_ON, SW_OFF = 13, 14
OFFB, OFFB_X = enc(27), enc(28)          # bloque OFF: sólido mientras su Activador está en OFF

W, H = 150, 40
FLOOR = 30                               # suelo del salón (y de las salas bajas de la balanza)


class Temple(Level):
    def __init__(self):
        Level.__init__(self, 'El Templo de los Pesos', W, H, (57, FLOOR - 1), music='jungla_1', modes=['race'])
        self.extra.update(name_en='The Temple of Weights', background='jungle', time='day', depth='temple', surfaceRow=2)
        self.blinks = []
        # todo el templo es piedra; las salas se excavan
        self.rect(2, 2, W - 1, H - 1, TEMPLE)

    def to_json(self):
        if self.blinks: self.extra['blockLinks'] = self.blinks
        return Level.to_json(self)

    def sw(self, c, r):
        """Activador ON/OFF (empieza en OFF; resuelto: ON)"""
        self.set(c, r, SW_ON if OPEN else SW_OFF)
        return (c, r)

    def off_block(self, c, r, src, solved=None):
        """Bloque OFF enlazado a su Activador (sólido al empezar; se abre con el Activador en ON)"""
        self.set(c, r, OFFB_X if (OPEN if solved is None else solved) else OFFB)
        self.blinks.append({'col': c, 'row': r, 'from': list(src)})

    def jplat(self, c0, c1, r):
        self.rect(c0, r, c1, r, JPLAT)

    def mud_floor(self, c0, c1, r, deep=0):
        """Suelo blando (el topo cava): césped de la jungla arriba y `deep` filas de barro debajo"""
        self.rect(c0, r, c1, r, JGRASS)
        if deep: self.rect(c0, r + 1, c1, r + deep, MUD)

    def scale(self, c, r, level_row, span, travel=2, power=1.0):
        """Balanza con la polea en (c, r) y los platillos NIVELADOS con la tabla en la cara de arriba de `level_row`"""
        drop = level_row - r - 1 + 0.375
        return self.ent('scale', c, r, span=span, drop=drop, travel=travel, power=power)


TRAMP_CATAPULT = 1.9 * 1.6 * 0.71        # (la variante resuelta: el disparo más flojo de la catapulta, como trampolín)


def templo_de_los_pesos():
    L = Temple()
    clear, rect, ent = L.clear, L.rect, L.ent

    # ══ SALÓN (columnas 55-92, filas 19-29) ═══════════════════════════════════════════════════════════════════
    clear(55, 19, 92, 29)
    clear(53, 27, 54, 29)                      # puerta a la sala R0 (ala de la balanza)
    clear(53, 19, 54, 26)                      # (R0 y el salón, una sola sala: la catapulta de la estrella entra por arriba)
    # escalera de tablones hasta el ala de las bocas (hueco del techo en las columnas 71-74)
    for r, a in ((28, 68), (26, 72), (24, 68), (22, 71)):
        L.jplat(a, a + 2, r)
    clear(71, 16, 74, 18)
    L.jplat(71, 74, 20); L.jplat(71, 74, 18); L.jplat(71, 74, 16)
    # trampilla al ala de los túneles (tablones: agachado se baja)
    clear(86, 31, 87, 31); L.jplat(86, 87, FLOOR)
    # puerta: 3 bloques OFF en la columna 93, uno por ala; columna 94 libre
    door = [(93, 27), (93, 28), (93, 29)]
    clear(94, 27, 94, 29)
    clear(93, 19, 94, 22)                      # el desván (ala de los túneles) se asoma al salón por arriba
    ent('checkpoint', 80, FLOOR - 1)
    # LA ESTRELLA ESCONDIDA: en lo alto, entre el musgo colgante (solo con la catapulta de R0)
    ent('star', 56, 20)

    # ══ ALA DE LA BALANZA (izquierda) ════════════════════════════════════════════════════════════════════════
    # R0 (columnas 40-52): la catapulta de la estrella, a la entrada (se entiende después de S2)
    clear(40, 19, 52, 29)
    clear(38, 27, 39, 29)                      # puerta a R1
    sw0 = L.sw(49, 26)                         # (sobre la celda izquierda del platillo derecho)
    L.off_block(43, 22, sw0)                   # repisa de la caja
    ent('box', 43, 21, respawn=3)
    if not OPEN:
        L.scale(47, 19, 27, 6, power=1.6)
    else:
        ent('trampoline', 50, 29, power=round(TRAMP_CATAPULT, 2))
    # R1 (columnas 18-37): la PESA — se empuja la caja grande de la repisa al platillo derecho y el izquierdo sube
    clear(18, 19, 37, 29)
    rect(28, 25, 33, 29, TEMPLE)               # repisa de la caja
    rect(34, 27, 35, 29, TEMPLE); rect(36, 29, 37, 29, TEMPLE)       # escalones desde la puerta
    ent('box', 28, 24, respawn=5)
    rect(18, 23, 20, 23, TEMPLE)               # el saliente al que solo se llega desde el platillo izquierdo arriba
    clear(18, 16, 20, 18)
    L.jplat(18, 20, 21); L.jplat(18, 20, 19); L.jplat(18, 20, 17)
    if not OPEN:
        L.scale(24, 19, 27, 4)
    else:
        L.jplat(21, 23, 25)                    # (resuelto: el platillo izquierdo arriba)
    ent('beetle', 23, FLOOR - 1, patrol={'left': 18, 'right': 27})
    # ZONA ALTA (filas 3-15, columnas 14-49): S2, la CATAPULTA hasta la galería del Activador
    clear(14, 3, 49, 15)
    sw2 = L.sw(32, 12)
    L.off_block(26, 8, sw2)
    ent('box', 26, 7, respawn=3)
    if not OPEN:
        L.scale(30, 3, 13, 6, power=1.6)
    else:
        ent('trampoline', 33, 15, power=round(TRAMP_CATAPULT, 2))
    rect(36, 9, 46, 9, TEMPLE)                 # la galería
    rect(47, 3, 49, 9, TEMPLE)
    sw_scale = L.sw(45, 6)                     # ACTIVADOR del ala: quita el bloque de abajo de la puerta
    rect(44, 3, 46, 5, TEMPLE)
    ent('beetle', 42, 15, patrol={'left': 36, 'right': 48})

    # ══ ALA DE LAS BOCAS (arriba: columnas 64-81, filas 3-15) ═════════════════════════════════════════════════
    # tres pisos de 3 de alto: A (filas 13-15) → derecha, B (9-11) → izquierda, C (5-7) → derecha al Activador
    clear(64, 13, 81, 15); clear(64, 9, 81, 11); clear(64, 5, 81, 7)
    # A: un tramo de 2 de alto con una planta en el suelo; un Gummy de la jungla ronda delante (ground pound → a la boca)
    rect(75, 13, 77, 13, TEMPLE)
    ent('carnivoreplant', 76, 15)
    ent('gummy_jungle', 70, 15, patrol={'left': 65, 'right': 74})
    # A → B a la derecha (planta en la pared derecha: sube pegado a la izquierda)
    clear(79, 12, 81, 12); L.jplat(79, 81, 14); L.jplat(79, 81, 12)
    ent('carnivoreplant', 81, 13, mount='wall_right')
    # B: suelo de barro con un TOPO y dos plantas colgadas del techo (no saltes debajo)
    L.rect(67, 12, 78, 12, JGRASS)
    ent('mole', 72, 11, patrol={'left': 67, 'right': 78})
    ent('carnivoreplant', 69, 9, mount='ceiling')
    ent('carnivoreplant', 75, 9, mount='ceiling')
    ent('star', 72, 10)
    # B → C a la izquierda (planta en la pared izquierda)
    clear(64, 8, 67, 8); L.jplat(64, 67, 10); L.jplat(64, 67, 8)
    ent('carnivoreplant', 64, 9, mount='wall_left')
    # C: una planta en un tramo de 2 de alto y una BOMBA que reaparece para dársela de comer
    rect(73, 5, 75, 5, TEMPLE)
    ent('carnivoreplant', 74, 7)
    ent('bombobject', 69, 7, respawn=4)
    sw_mouths = L.sw(80, 4)                    # ACTIVADOR del ala: el bloque del medio
    # la tolva de vuelta al salón (columnas 83-84)
    clear(82, 5, 82, 7); clear(83, 5, 84, 18)

    # ══ ALA DE LOS TÚNELES (abajo y a la derecha) ═════════════════════════════════════════════════════════════
    # L: aterrizaje (80-95), topos en el barro (96-112), escarabajo + cajas (113-127), escalón (128-140), subida (141-149)
    clear(80, 32, 95, 38)
    clear(96, 35, 112, 38)
    L.mud_floor(96, 103, 39); L.mud_floor(106, 112, 39)
    rect(104, 38, 105, 38, TEMPLE)             # isla de sillares (los topos no la cruzan)
    ent('mole', 99, 38, patrol={'left': 96, 'right': 103})
    ent('mole', 109, 38, patrol={'left': 106, 'right': 112})
    # la estrella del techo: un bloque rompible de cabezazo encima de la isla
    L.set(104, 34, EMPTY if OPEN else BREAK); clear(104, 32, 104, 33)
    ent('star', 104, 33)
    clear(113, 36, 127, 38)
    ent('beetle', 119, 38, patrol={'left': 114, 'right': 125})
    for r in (36, 37, 38):                     # columna de 3 cajas grandes contra el escalón: el escarabajo LANZADO las rompe
        ent('box', 127, r, respawn=30)
    ent('bombobject', 92, 38, respawn=4)       # (o una bomba)
    clear(128, 35, 140, 37)
    clear(141, 32, 149, 37)
    # subida a M
    clear(143, 30, 146, 31)
    for r, a in ((36, 143), (34, 146), (32, 143)):
        L.jplat(a, a + 2, r)
    L.jplat(143, 146, 30)
    # M (columnas 115-149, filas 25-29): topos entre sillares; checkpoint al llegar
    clear(119, 25, 149, 29)
    L.mud_floor(119, 125, FLOOR, 1); L.mud_floor(128, 140, FLOOR, 1)
    ent('mole', 122, 29, patrol={'left': 119, 'right': 125})
    ent('mole', 134, 29, patrol={'left': 128, 'right': 140})
    ent('checkpoint', 148, 29)
    # subida al desván (columnas 115-118)
    clear(115, 19, 118, 29)
    for r, a in ((28, 115), (26, 116), (24, 115)):
        L.jplat(a, a + 2, r)
    # el DESVÁN sobre la antesala (columnas 95-114, filas 19-22) con el Activador colgado
    clear(95, 19, 114, 22)
    rect(97, 19, 99, 19, TEMPLE)
    sw_tunnels = L.sw(98, 20)                  # ACTIVADOR del ala: el bloque de arriba
    ent('gummy_jungle', 106, 22, patrol={'left': 101, 'right': 112})

    # ══ LA PUERTA y la META ═══════════════════════════════════════════════════════════════════════════════════
    for (c, r), src in zip(door, (sw_tunnels, sw_mouths, sw_scale)):
        L.off_block(c, r, src, solved=OPEN and not SOLVE)
    clear(95, 24, 112, 29)                     # antesala
    L.finish(108, 29)

    decorate(L)
    plane(L)
    if SOLVE: variant(L)
    return L


def decorate(L):
    """Lo que retheme no pone: el musgo de la «lámpara» del salón (la estrella), braseros e ídolos del templo"""
    for c, t in ((55, 'hanging_moss'), (56, 'liana_long'), (57, 'hanging_moss'), (58, 'flower_vine')):
        L.deco(t, c, 19)
    for c in (59, 89):
        L.deco('stone_brazier', c, FLOOR - 1)
    L.deco('stone_brazier', 97, 29); L.deco('stone_brazier', 111, 29)
    L.deco('stone_brazier', 96, 22)


def plane(L):
    """El PLANO DE FONDO hecho a mano (retheme --bg ponía colinas de barro detrás de los túneles — parecían terreno
    de topos — y columnas justo debajo de los platillos: se leía como si el platillo descansara en ellas). Ruinas del
    templo lejos de platillos, plataformas, meta y checkpoints."""
    bg = lambda c0, r0, c1, r1: [L.set_bg(c, r, TEMPLE) for r in range(r0, r1 + 1) for c in range(c0, c1 + 1)]

    def arch(a, b, top, floor):
        """Dos columnas (a, a+1) y (b-1, b) con su dintel colgado del techo y el arranque del arco"""
        bg(a, top, a + 1, floor); bg(b - 1, top, b, floor)
        bg(a, top, b, top + 1)
        bg(a + 2, top + 2, a + 2, top + 2); bg(b - 2, top + 2, b - 2, top + 2)
        for c in range(a + 1, b, 3): L.deco('hanging_moss', c, top + 2, sub=None); L.foliage[-1]['plane'] = 'bg'
    # salón: dos arcos (entre ellos, la escalera de tablones; el checkpoint queda dentro del de la derecha)
    arch(58, 65, 19, 29)
    arch(76, 84, 19, 29)
    bg(89, 24, 90, 29); bg(89, 23, 89, 23)                # columna rota junto a la puerta
    # zona alta de la balanza: la galería «apoyada» en dos pilares, y un muro bajo derrumbado a la izquierda
    bg(38, 10, 39, 15); bg(43, 10, 44, 15)
    for c, h in ((14, 3), (15, 2), (16, 3), (17, 1), (22, 2), (23, 1)):
        bg(c, 16 - h, c, 15)
    # antesala: pirámide escalonada con su ídolo
    for k, (a, b) in enumerate(((98, 106), (99, 105), (100, 104))):
        bg(a, 29 - k, b, 29 - k)
    L.deco('stone_idol', 102, 26); L.foliage[-1]['plane'] = 'bg'
    # túneles: arco en la sala de aterrizaje y columnas en la subida a M
    arch(81, 93, 32, 38)
    bg(126, 25, 127, 29)
    # desván: muro bajo
    for c, h in ((104, 2), (105, 1), (106, 2), (107, 1)):
        bg(c, 23 - h, c, 22)


def variant(L):
    """Comprobación por alas con level_solve: salida y meta en otro sitio, la puerta cerrada"""
    fin = [(c, r) for r in range(1, H + 1) for c in range(1, W + 1) if L.get(c, r) == FINISH]
    for c, r in fin: L.set(c, r, EMPTY)
    hall = (61, FLOOR - 1)
    spots = {   # ala: (salida de la ida, meta junto al Activador)
        'balanza': ((40, 8), (42, 8)),
        'bocas': ((79, 7), (77, 7)),
        'tuneles': ((101, 22), (100, 22)),
    }
    name, back = SOLVE.replace('_vuelta', ''), SOLVE.endswith('_vuelta')
    goal_start, goal = spots[name]
    if back:
        L.start = list(goal_start); L.finish(hall[0], hall[1])
    else:
        L.finish(*goal)


BUILDERS = [templo_de_los_pesos]
