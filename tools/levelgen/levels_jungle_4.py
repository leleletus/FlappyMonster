"""LA ESTAMPIDA — el 4.º nivel de la jungla (diseño aprobado por el usuario, FlappyMonster_pruebas/niveles_jungla/diseno.md):
CÁMARA AUTOMÁTICA hacia la puerta del templo del Escarabajo Gigante (el nivel siguiente es el jefe, templo_escarabajo)
mientras una ESTAMPIDA de Escarabajos Rinoceronte embiste: te ven delante y cargan (380 px/s, más que tú).
Embistiendo arrollan lo que pillan — las cajas pequeñas salen despedidas, contra las grandes se aturden — y las
Plantas carnívoras del camino se comen a los que te adelantan (un respiro: dormida se pisa). Topos en el barro,
un vado de pirañas y la puerta del templo al final.

    python3 tools/levelgen/build.py --only la_estampida
    python3 tools/levelgen/add_apples.py la_estampida        (ANTES de retheme: busca suelo de piedra)
    python3 tools/levelgen/retheme.py la_estampida           (terreno y decoraciones de la jungla)
    python3 tools/levelgen/retheme.py --bg la_estampida      (ruinas y árboles en el plano de fondo)

Tramos (columnas):
  1. La estampida (2-46): tres escarabajos detrás de la salida embisten nada más empezar; tablones para dejarlos
     pasar por debajo (estrella 1); una planta que se come al que viene de frente; foso.
  2. Árboles caídos (47-100): filas de cajas — las pequeñas las arrollan, contra las grandes se aturden —; una meseta
     con un muro de cajas grandes; estrella 2 sobre la última pila.
  3. Topos y plantas (101-151): barro con topos; plantas que se comen a los escarabajos; ESTRELLA ESCONDIDA en un dosel
     de lianas muy alto: solo se llega rebotando en el escarabajo VOLADOR que ronda debajo.
  4. El vado (152-173): piedras del templo entre pozas con pirañas, con la cámara empujando.
  5. La puerta (174-199): un escarabajo y una planta, la escalinata y la puerta del templo con la meta dentro.
Por qué 11 filas y no 15 (el diseño): los niveles de cámara automática enseñan toda su altura (docs/gameplay/autoscroll.md).
"""
from lib import *

ID_HIGH = 2 ** 17
def enc(i): return i % 16 + (i // 16) * ID_HIGH
TEMPLE = enc(42)            # sillares del templo (retheme no los convierte; el Topo no los cava)

W, H = 200, 11
G = 9                       # fila del suelo (dos de grosor: césped y barro para los topos; las pozas, 2 de hondo)


def spike_pit(L, c0, c1):
    """Foso de 2 de hondo con pinchos en el fondo (el borde de abajo del nivel)"""
    L.clear(c0, 2, c1, H - 1)
    L.spikes(c0, c1, H - 1, UP)


def boxes(L, typ, cols, high=2, g=G):
    """Un "árbol caído": fila de cajas apiladas `high` de alto sobre el suelo `g` (caen y se apilan solas)"""
    for c in cols:
        for k in range(high):
            L.ent(typ, c, g - 1 - k, respawn=6)


def beetle(L, c, l, r, left=False, g=G, **p):
    if left: p['startDir'] = 'left'
    return L.walker('beetle', c, g - 1, l, r, **p)


def la_estampida():
    L = Level('La Estampida', W, H, (12, G - 1), music='jungla_2', modes=['race'])
    L.extra.update(name_en='The Stampede', background='jungle', time='dusk')
    L.auto_scroll = {'countdown': 3, 'endCol': W, 'margin': 0.6, 'speed': 110, 'startCol': 1, 'width': 20}
    L.terrain(2, W - 1, G)

    # ── 1. La estampida (2-46) ─────────────────────────────────────────────────────────────────────────────
    # (tres escarabajos detrás de la salida: dos te ven ya — 5 y 6 casillas —, el tercero cuando se acerca)
    for c in (5, 6, 7):
        beetle(L, c, 2, 9)
    L.plat(17, 21, G - 2)                       # tablones a 2 de alto: arriba no te ven (no estás a su altura)
    L.ent('star', 19, G - 3)
    L.ent('carnivoreplant', 27, G - 1)          # la planta del camino: hay que saltarla (doble salto)...
    beetle(L, 36, 34, 40, left=True)            # ...o dejar que se coma al que viene de frente embistiendo
    spike_pit(L, 44, 46)                        # (en un borde frenan: el foso corta la estampida)

    # ── 2. Árboles caídos (47-100) ─────────────────────────────────────────────────────────────────────────
    beetle(L, 52, 48, 56)
    boxes(L, 'smallbox', (59, 60, 61))          # árbol 1: cajas pequeñas (embistiendo las despide)
    L.ent('checkpoint', 64, G - 1)
    L.terrain(66, 78, G - 1)                    # la meseta
    boxes(L, 'box', (71,), g=G - 1)             # árbol 2: muro de cajas grandes (2 de alto en la 71, 1 en la 72)
    boxes(L, 'box', (72,), high=1, g=G - 1)
    beetle(L, 75, 73, 77, left=True, g=G - 1)   # embiste contra el muro y se aturde
    spike_pit(L, 79, 81)
    boxes(L, 'box', (87, 88, 89, 90), high=1)   # árbol 3: tronco de cajas grandes...
    boxes(L, 'smallbox', (88, 89), high=1)      # ...con ramas de cajas pequeñas encima
    L.plat(87, 90, G - 3)                       # tablones encima: la estrella 2
    L.ent('star', 89, G - 4)
    beetle(L, 96, 93, 99, left=True)

    # ── 3. Topos y plantas (101-151) ───────────────────────────────────────────────────────────────────────
    L.walker('mole', 104, G - 1, 101, 110)
    beetle(L, 107, 105, 109)                    # lo adelantas: embiste por detrás... y se lo come la planta
    L.ent('carnivoreplant', 112, G - 1)
    # el DOSEL: lianas a 5 de alto (el doble salto llega a 3); debajo ronda el escarabajo VOLADOR: pisarlo en el aire
    # recarga los dos saltos y desde ahí se llega. Nada más alto de 1 casilla cerca (ni plataformas, ni pilas de cajas).
    L.plat(118, 123, G - 5)
    L.ent('star', 121, G - 6)
    L.ent('beetle', 116, G - 3, wings=True, flyRange=1)
    for c in (118, 120, 123):
        L.deco('liana_mid', c, G - 4, sub=1)    # (el dosel cuelga lianas: se lee como copa, no como tabla suelta)
    L.walker('mole', 128, G - 1, 124, 134)
    L.ent('checkpoint', 131, G - 1)
    L.ent('carnivoreplant', 138, G - 1)
    beetle(L, 143, 141, 147, left=True)         # viene de frente: embistiendo cae en la planta
    L.walker('mole', 147, G - 1, 145, 151)

    # ── 4. El vado (152-173) ───────────────────────────────────────────────────────────────────────────────
    L.clear(152, 2, 173, H - 1)
    L.water(152, G, 173, H - 1)
    for c0, c1 in ((155, 156), (160, 161), (165, 165), (169, 170)):
        L.rect(c0, G, c1, H - 1, TEMPLE)        # piedras del templo a ras del agua
    for c in (158, 163, 167, 172):
        L.ent('piranha', c, H - 1)

    # ── 5. La puerta del templo (174-199) ──────────────────────────────────────────────────────────────────
    L.ent('carnivoreplant', 178, G - 1)
    beetle(L, 182, 180, 184, left=True)         # el último: embiste hacia la planta
    L.rect(185, G - 1, 186, H - 1, TEMPLE)      # escalinata
    L.rect(187, G - 2, W - 1, H - 1, TEMPLE)    # la plataforma de la puerta
    L.rect(189, 2, W - 1, 3, TEMPLE)            # el dintel de la puerta (dentro, 3 de alto)
    L.finish(195, G - 3)
    for c in (189, 199):
        L.deco('broken_pillar', c, G - 3)       # las columnas del pórtico
    for c in (188, 192):
        L.deco('stone_brazier', c, G - 3)
    L.deco('stone_idol', 197, G - 3)
    for c in (190, 193, 197):
        L.deco('hanging_moss', c, 4)
    return L


BUILDERS = [la_estampida]
