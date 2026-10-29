"""El BONUS de las Montañas Heladas: "La Cima" (Rey de la Colina contra el bot; diseño aprobado por el usuario,
FlappyMonster_pruebas/islas_heladas/diseno.md, «La Cima»).

La ZONA DE PUNTOS está en la cima, justo debajo del labio del glaciar: un ALUD (`avalanche`) cae sobre ella cada
pocos segundos. Cuando retumba hay que salir (a las dos casillas a cada lado de la cima, o al teleférico) y volver
cuando pasa; o empujar al rival debajo. Bolas de Nieve que reaparecen patrullan las laderas y se lanzan a empujar;
un TELEFÉRICO (`cablecar`) sube del valle de la izquierda al hombro de la cima. A la derecha, la ladera helada baja
a un valle con una repisa de hielo alta.

    python3 tools/levelgen/build.py --only la_cima && python3 tools/levelgen/retheme.py la_cima
    python3 tools/levelgen/retheme.py --bg la_cima
    tools/tests/run.sh bot_nav BUILD=1 -- assets/levels/la_cima.json   (el grafo del bot)
"""
from lib import *

ID_HIGH = 2 ** 17
def enc(i): return i % 16 + (i // 16) * ID_HIGH
ICE = enc(30)                                        # hielo (resbala)
ICE_ROCK, GLACIER, ICE_LEDGE = enc(51), enc(53), enc(58)

W, H = 48, 18
G = 16                       # fila del suelo de los valles
TOP = 10                     # fila de la cima (su cara de arriba)


def la_cima():
    L = Level('La Cima', W, H, (7, G - 1), music='montana_bonus', modes=['koth'], match_time=100)
    L.extra.update({'name_en': 'The Summit', 'background': 'snow', 'time': 'day', 'snow': True, 'spikeSkin': 'ice'})
    L.terrain(2, W - 1, G)
    # ── la montaña (de izquierda a derecha): valle, dos escalones, el hombro, la CIMA, la ladera helada, valle ──
    # (los escalones de la izquierda quedan por debajo del cable del teleférico: la cabina y quien va en ella pasan
    # por encima con holgura)
    L.rect(9, 14, 13, G, SOLID)
    L.rect(14, 12, 19, G, SOLID)                 # el hombro
    L.rect(20, TOP, 29, G, SOLID)                # la cima
    L.rect(30, 12, 32, G, SOLID)
    L.rect(33, 14, 35, G, SOLID)
    # la ladera de la derecha es de roca helada (la cara al viento) y el valle tiene un lago helado que resbala
    L.rect(30, 13, 32, G, ICE_ROCK)
    L.rect(33, 15, 35, G, ICE_ROCK)
    L.rect(39, G, 45, G, ICE)
    # ── el LABIO DEL GLACIAR, colgado del marco sobre la cima: de él se suelta el alud ──
    L.rect(19, 2, 30, 2, GLACIER)
    L.rect(20, 3, 29, 3, GLACIER)
    L.rect(22, 4, 27, 4, GLACIER)
    # el ALUD: 6 columnas (22-27) de la fila 5 a la cima (5 filas). Primer aviso a los 8 s, uno cada 15 s:
    # aviso 1,6 s (retumba: hay que salir) → 3 s de torrente
    L.ent('avalanche', 22, 5, width=6, length=5, delay=8, period=15, warn=1.6, pour=3)
    # la ZONA DE PUNTOS, justo debajo del alud (las dos casillas de cada lado de la cima quedan fuera: ahí se espera)
    L.ent('pointarea', 22, TOP - 2, corner={'col': 27, 'row': TOP - 1}, points=1, interval=1, contested=True)
    # ── el TELEFÉRICO: del valle de la izquierda (estación en la columna 4) al hombro de la cima (columna 18);
    # dos cabinas: cuando una está abajo, la otra está arriba. Las cubiertas quedan 60 px por encima del suelo y de
    # la cima: se sube de un saltito
    L.ent('cablecar', 4, G - 3, path=[{'col': 18, 'row': TOP - 3}], cabins=2, speed=4, stops=1)
    # ── la repisa de hielo alta sobre el valle de la derecha (una estrella) y una tabla para llegar ──
    L.plat(37, 39, 13, ICE_LEDGE)
    L.plat(41, 44, 10, ICE_LEDGE)
    # ── enemigos que reaparecen (regla de las arenas, bot_nav `datos`: el 40 % de sus puntos — Bola de Nieve
    # 20 → 8, Gummy 10 → 4) ──
    L.walker('snowball', 16, 11, 14, 19, points=8, respawn=8)        # en el hombro: se lanza a la cima
    L.walker('snowball', 31, 11, 30, 32, points=8, respawn=8)        # en el escalón de la derecha
    L.walker('gummy_ice', 42, G - 1, 37, 46, points=4, respawn=8)    # en el valle helado
    # ── cosas que coger (sin vidas extra: las da el premio del bonus) ──
    L.ent('star', 42, 9)
    L.ent('star', 10, 13)
    L.ent('apple', 46, G - 1)
    return L


BUILDERS = [la_cima]
