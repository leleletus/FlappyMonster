"""El BONUS de la jungla: "El Claro de la Balanza" (Rey de la Colina contra el bot; diseño aprobado por el usuario,
FlappyMonster_pruebas/niveles_jungla/diseno.md).

La ZONA DE PUNTOS va MONTADA en un platillo de una balanza gigante (`ride`: sube y baja con él): quien se sube la
hunde y levanta el otro platillo. Plantas carnívoras en las orillas y colgando del techo: empuja al rival dentro y se
lo come (tiene que machacar para salir mientras tú sumas). Géiseres en las esquinas te devuelven a la balanza; bombas
que reaparecen para reventar plantas (o al rival).

    python3 tools/levelgen/build.py --only claro_de_la_balanza && python3 tools/levelgen/retheme.py claro_de_la_balanza
    tools/tests/run.sh bot_nav BUILD=1   (el grafo del bot)
"""
from lib import *

W, H = 48, 18
G = 16                       # fila del suelo


def claro_de_la_balanza():
    L = Level('El Claro de la Balanza', W, H, (5, G - 1), music='jungla_bonus', modes=['koth'], match_time=150)
    L.extra.update({'name_en': 'The Scale Clearing', 'background': 'jungle', 'time': 'day'})
    L.terrain(2, W - 1, G)
    # el techo del claro: un dintel de piedra del que cuelga la polea (y las plantas del techo)
    L.rect(14, 2, 34, 2, SOLID)
    # cornisas para subir a los platillos (los platillos nivelados quedan en la fila 11; hundidos, en la 13; subidos,
    # en la 8). Las bajas llegan a UNA casilla del platillo: desde ellas se sube al nivelado (con 4 de hueco no se
    # llegaba: ni el bot ni casi nadie, la zona empieza ahí) y se baja al hundido; las altas de dentro, al subido
    L.plat(9, 15, 13, DROP)
    L.plat(33, 39, 13, DROP)
    L.plat(3, 6, 10, DROP)
    L.plat(42, 45, 10, DROP)
    L.plat(11, 14, 10, DROP)
    L.plat(34, 37, 10, DROP)
    # la BALANZA: polea en (24, 3), platillos a 6 casillas a cada lado
    L.ent('scale', 24, 3, span=12, drop=7.5, travel=2.5, power=1.1)
    # la ZONA DE PUNTOS, montada en el platillo izquierdo (centro en la columna 18; 3 de ancho, 2 de alto)
    L.ent('pointarea', 17, 9, corner={'col': 19, 'row': 10}, points=1, interval=1, contested=True, ride=True)
    # plantas: en el suelo junto a las paredes, y colgando del dintel sobre los platillos
    # (regla de las arenas, bot_nav `datos`: reaparecen y dan el 40 % de sus puntos — planta 20 → 8, Gummy 10 → 4)
    P = dict(points=8, respawn=8)
    L.ent('carnivoreplant', 3, G - 1, **P)
    L.ent('carnivoreplant', W - 2, G - 1, **P)
    L.ent('carnivoreplant', 15, 3, mount='ceiling', **P)
    L.ent('carnivoreplant', 33, 3, mount='ceiling', **P)
    # géiseres en las esquinas (te devuelven arriba)
    L.ent('geyser', 7, G - 1, height=8)
    L.ent('geyser', W - 6, G - 1, height=8)
    # bombas que reaparecen (para las plantas, o para el rival)
    L.ent('bombobject', 22, G - 1)
    L.ent('bombobject', 27, G - 1)
    # enemigos que reaparecen (regla del bonus: los hay y dan una parte de sus puntos)
    L.walker('gummy_jungle', 12, G - 1, 9, 16, respawn=1, points=4)
    L.walker('gummy_jungle', 36, G - 1, 33, 40, respawn=1, points=4)
    L.ent('star', 4, 9)
    L.ent('star', 44, 9)
    return L


BUILDERS = [claro_de_la_balanza]
