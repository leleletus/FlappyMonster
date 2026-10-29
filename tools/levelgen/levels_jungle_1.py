"""La jungla, nivel 1: "Senda del Dosel" (The Canopy Trail) — la INTRODUCCIÓN de la isla, DOS RUTAS A LA VEZ.

Diseño aprobado por el usuario: FlappyMonster_pruebas/niveles_jungla/diseno.md § 1. Dos pisos paralelos que se cruzan:
el SUELO (barro, topos, escarabajos, plantas) y el DOSEL (tablones de liana a 7 casillas del suelo: no se sube de un
salto; se sube con las SEMILLAS, que crecen hasta él, o por las ruinas del templo donde los pisos se cruzan). Cada piso
resuelve los problemas del otro: desde el dosel se tiran escarabajos a las plantas de abajo; desde el suelo se planta la
semilla que cruza el hueco del dosel (en el terreno de un topo: un ground pound lo saca antes).

Cómo se hace (en este orden: el plano generado ANTES que las decoraciones, porque retheme pone ceibas — que van al
plano — y entonces `--bg` lo tomaría por un plano hecho a mano y no lo tocaría):
    python3 tools/levelgen/build.py --only senda_del_dosel
    python3 tools/levelgen/retheme.py --tiles senda_del_dosel            # el terreno de la jungla
    python3 tools/levelgen/retheme.py --bg --force senda_del_dosel       # ruinas y árboles en el plano de fondo
    python3 tools/levelgen/retheme.py senda_del_dosel                    # las decoraciones
    python3 tools/levelgen/levels_jungle_1.py --plane                    # lo del plano que va a mano (ver HAND_PLANE)
    python3 tools/levelgen/add_apples.py senda_del_dosel                 # la comida

Comprobación: `level_solve` no sabe plantar semillas: `OPEN=1` escribe la variante RESUELTA (cada semilla, ya plantada:
sus hojas y su copa como tablones en las casillas que ocupan) para `level_solve EXPLORE=1` (¿se llega a las estrellas?):
    OPEN=1 python3 tools/levelgen/build.py --only senda_del_dosel --out <carpeta>
El camino del SUELO llega a la meta sin semillas (las plantas carnívoras y los enemigos no cuentan para el buscador: con
ellas, lo peor es que te traguen y salgas machacando botones).

Tramos (columnas):
  1  2-30    el escarabajo: uno en el llano y la puerta del templo (túnel de 2 de alto) con una planta en la boca;
             se pisa, se coge, se lanza a la planta → se duerme y se pasa. Encima del templo, la estrella 1 (desde el dosel)
  2  31-55   el primer dosel: la semilla en el montículo de barro crece hasta los tablones; arriba, dos escarabajos y dos
             agujeros sobre las dos plantas del suelo (se dejan caer los escarabajos en ellas)
  3  56-89   los topos: barro con dos topos; el dosel tiene un hueco de 13 (64-76) que solo cruza la planta de la
             semilla, plantada en el banco de barro del segundo topo (estrella 2 sobre el hueco: solo desde la copa; a 6
             de los bordes, desde el dosel no se llega). La pirámide donde se cruzan los pisos: punto de control 1
  4  90-133  la galería del templo: dos pisos de plantas (suelo + techo) que solo se pasan dándoles de comer, por orden,
             con los escarabajos de cada tramo. Al final, la torre: su puerta tapiada por cascotes es FALSA (estrella 3,
             la escondida)
  5  134-156 el río: una poza con UNA piraña (anticipo del nivel 2) bajo un puente de tablones; punto de control 2
  6  157-169 la meta, bajo un arco en ruinas (en el plano de fondo)
"""
import os
from lib import *

ID_HIGH = 2 ** 17
OPEN = bool(os.environ.get('OPEN'))


def enc(i): return i % 16 + (i // 16) * ID_HIGH


MUD, JGRASS, TEMPLE, JPLAT = enc(40), enc(41), enc(42), enc(43)
FAKE_ROCK = enc(24)              # borde falso: se ve como la roca de los cascotes, sin colisión
W, H, G, C = 170, 28, 22, 15     # ancho, alto, fila del suelo, fila del dosel (7 por encima: no se sube de un salto)


class J(Level):
    def __init__(self):
        Level.__init__(self, 'Senda del Dosel', W, H, (4, G - 1), music='jungla_1', modes=['race'])
        self.extra.update(name_en='The Canopy Trail', background='jungle', time='day')
        self.ground(2, W - 1, G)

    def canopy(self, c0, c1, r=C):
        self.plat(c0, c1, r, JPLAT)

    def walk(self, typ, c0, c1, r=G - 1, **props):
        return self.ent(typ, (c0 + c1) // 2, r, patrol={'left': c0, 'right': c1}, **props)

    def seed(self, c, r, spot, h):
        """Semilla en (c, r); `spot` = (columna, fila del suelo) donde se planta para el buscador: OPEN=1 pone ahí la
        planta ya crecida (hoja derecha a 2, hoja izquierda a 4, copa a h casillas del suelo; medidas de
        assets/images/items/seed/jungla-plant<h>.json)"""
        self.ent('seed', c, r, life=25)
        if OPEN:
            sc, gr = spot
            self.set(sc + 1, gr - 2, JPLAT)
            self.set(sc - 1, gr - 4, JPLAT)
            for x in (sc - 1, sc, sc + 1):
                self.set(x, gr - h, JPLAT)

    def pair(self, c, floor_r, ceil_r, sleep=8):
        """Puerta de plantas: una en el suelo y otra colgada del techo encima (3 de alto: no se salta)"""
        self.ent('carnivoreplant', c, floor_r, sleepTime=sleep)
        self.ent('carnivoreplant', c, ceil_r, mount='ceiling', sleepTime=sleep)


def senda_del_dosel():
    L = J()

    # ── 1 · el escarabajo (2-30) ────────────────────────────────────────────────────────────────────────────────────
    L.walk('beetle', 11, 17)
    # la puerta del templo: un túnel de 2 de alto (no se salta la planta) bajo un templo escalonado
    L.rect(21, 17, 29, 19, TEMPLE)
    L.rect(23, 16, 27, 16, TEMPLE)
    L.ent('carnivoreplant', 22, G - 1, sleepTime=8)
    L.ent('star', 25, 15)                                     # estrella 1: encima del templo, desde el dosel

    # ── 2 · el primer dosel (31-55) ─────────────────────────────────────────────────────────────────────────────────
    L.seed(33, G - 1, (37, G - 1), 5)
    L.rect(36, G - 1, 38, G - 1, MUD)                         # el montículo donde se planta (la copa: bajo los tablones)
    L.canopy(31, 43); L.canopy(47, 49); L.canopy(53, 63)      # agujeros 44-46 y 50-52 sobre las plantas del suelo
    L.walk('beetle', 33, 42, C - 1)
    L.walk('beetle', 47, 49, C - 1)
    L.ent('carnivoreplant', 45, G - 1)
    L.ent('carnivoreplant', 51, G - 1)

    # ── 3 · los topos (56-89) ───────────────────────────────────────────────────────────────────────────────────────
    L.rect(56, G, 78, G, MUD)
    L.canopy(77, 82)                                          # (el hueco del dosel: 64-76, 13: no se salta)
    # el banco de barro bajo el hueco (1 de alto: la planta crecida llega justo a la altura del dosel), territorio del
    # segundo topo
    L.rect(65, G - 1, 75, G - 1, MUD)
    L.walk('mole', 57, 63, isle='auto')
    L.walk('mole', 65, 75, G - 2, isle='auto')
    L.ent('carnivoreplant', 60, C + 1, mount='ceiling')       # colgada del dosel: cuidado al bajar por ahí
    L.seed(62, G - 1, (70, G - 1), 6)
    L.ent('star', 70, 11)                                     # estrella 2: sobre el hueco, solo desde la copa (a 6 de
                                                              # los bordes del dosel: desde ellos no se llega)
    # la pirámide donde se cruzan los pisos
    L.rect(79, 20, 89, 21, TEMPLE)
    L.rect(81, 18, 89, 19, TEMPLE)
    L.rect(83, 16, 89, 17, TEMPLE)
    L.ent('checkpoint', 86, 15)

    # ── 4 · la galería del templo (90-133) ──────────────────────────────────────────────────────────────────────────
    # (90-91: el pozo para bajar a la galería de abajo; 126-127: el otro pozo, junto a la torre)
    L.rect(92, 17, 125, 18, TEMPLE)                           # el piso de arriba / el techo de abajo
    # abajo: tres puertas de plantas, un escarabajo antes de cada una
    L.walk('beetle', 92, 96)
    L.pair(99, G - 1, 19)
    L.walk('beetle', 102, 108)
    L.pair(111, G - 1, 19)
    L.walk('beetle', 114, 117)
    L.pair(120, G - 1, 19)
    # arriba: dos puertas (la de arriba cuelga de una rama de tablones), un escarabajo antes de cada una
    L.walk('beetle', 93, 100, 16)
    L.canopy(102, 106, 13)
    L.pair(104, 16, 14)
    L.walk('beetle', 108, 112, 16)
    L.canopy(114, 118, 13)
    L.pair(116, 16, 14)
    # la torre: se pasa por debajo; arriba, su puerta tapiada por cascotes es falsa
    L.rect(128, 9, 133, 18, TEMPLE)
    for c in (128, 130, 131, 133):
        L.set(c, 8, TEMPLE)                                   # (almenas)
    L.rect(128, 15, 128, 16, FAKE_ROCK)
    L.clear(129, 15, 131, 16)
    L.ent('star', 130, 16)                                    # estrella 3, la escondida

    # ── 5 · el río (134-156) ────────────────────────────────────────────────────────────────────────────────────────
    L.ent('checkpoint', 136, G - 1)
    L.rect(138, 20, 139, 21, TEMPLE)                          # escalón al puente
    L.canopy(140, 146, 18); L.canopy(150, 156, 18)            # el puente (a 4 del agua: la piraña llega)
    L.water(141, G, 155, G + 2)                               # (3 de hondo: se sale por las orillas, a ras del agua)
    L.rect(145, 21, 146, G + 2, SOLID); L.rect(150, 21, 151, G + 2, SOLID)    # piedras para cruzar
    pool = [{'col': 141, 'row': G}, {'col': 155, 'row': G}, {'col': 155, 'row': G + 2}, {'col': 141, 'row': G + 2}]
    L.ent('piranha', 148, G + 1, area=pool)

    # ── 6 · la meta (157-169) ───────────────────────────────────────────────────────────────────────────────────────
    L.finish(163, G - 1)
    L.deco('stone_brazier', 158, G - 1); L.deco('stone_brazier', 169, G - 1)
    return L


BUILDERS = [senda_del_dosel]


# ── El plano de fondo HECHO A MANO (después de `retheme.py --bg`) ───────────────────────────────────────────────────
# Lo de la isla lo pone `retheme.py --bg` (ruinas, ceibas: lo generado, apuntado en bg_gen/); esto añade lo que el
# diseño necesita y el generador no pone (no pone nada tras la meta ni en huecos de 2-3 de alto): el fondo de las
# PUERTAS del templo (así se leen como pasos a través de un edificio, no como bloques flotando), el interior de la
# cámara de la torre y el ARCO en ruinas de la meta. Solo rellena casillas vacías del plano (lo generado y lo que el
# usuario haya cambiado se queda); `--bg --force` después lo respeta (no está en el apunte: cuenta como del usuario).
#     python3 tools/levelgen/levels_jungle_1.py --plane
HAND_PLANE = [
    (21, 20, 29, 21),             # tras el túnel de la puerta del templo (tramo 1)
    (129, 15, 131, 16),           # el interior de la cámara de la torre
    (128, 19, 133, 21),           # tras el paso bajo la torre
    (160, 17, 160, 21), (167, 17, 167, 21),     # el arco de la meta: pilares,
    (159, 15, 168, 16), (161, 14, 166, 14),     # dintel y remate
]


def plane(path=None):
    import json
    import retheme as R
    path = path or os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels', 'senda_del_dosel.json')
    lv = json.load(open(path))
    H_, W_ = len(lv['tiles']), len(lv['tiles'][0])
    bg = lv.get('bgTiles') or [[0] * W_ for _ in range(H_)]
    n = 0
    for c0, r0, c1, r1 in HAND_PLANE:
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                if not bg[r - 1][c - 1]:
                    bg[r - 1][c - 1] = TEMPLE; n += 1
    order = {}
    for k, v in lv.items():
        order[k] = v
        if k == 'tiles': order['bgTiles'] = bg
    R.save(path, order)
    print('plano a mano: +%d bloques' % n)


if __name__ == '__main__':
    import sys
    if '--plane' in sys.argv: plane()
    else: print(__doc__)
