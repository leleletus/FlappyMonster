#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_tifon.py → los TEJADOS de Tifón, el Soplón Supremo (jefe secreto de la fortaleza;
# docs/bosses/tifon.md): la arena de prueba jefe_tifon.json y, con --lair, su guarida assets/levels/tejados_del_tifon.json
# (la misma sala con su tramo de entrada; se llega por la salida secreta de taller_trampas).
#   python3 tools/levelgen/arenas/make_jefe_tifon.py           → tools/levelgen/arenas/jefe_tifon.json
#   python3 tools/levelgen/arenas/make_jefe_tifon.py --lair    → assets/levels/tejados_del_tifon.json
#     (¡reescribe la guarida! Si el usuario la retoca en el editor, no volver a ejecutarlo con --lair)
#   love . --editor tools/levelgen/arenas/jefe_tifon.json      (probarla desde el editor)
#
# Los tejados al aire libre (openTop: sin techo, cielo de noche): el suelo es tejado de piedra en la fila 14; en medio
# un HUECO con pinchos (caer quita 1, no se muere: se sale de un salto); CHIMENEAS para cubrirse del soplo (dos de 2 de
# alto junto al hueco: el viento nunca te tira dentro si te pegas a ellas, y dos bajas a los lados); dos CORNISAS
# traspasables contra el granizo y para lanzar la bomba más alto; dos CAJAS (cobijo que se mueve) y dos BOMBAS que
# reaparecen. Zona: columnas 15-42 (28 de ancho), filas 2-13.
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

EMPTY, SOLID, DROP, FINISH = 0, 1, 10, 11
SPIKES_UP = 73728                        # (pinchos hacia arriba en las dos subceldas de abajo: TileCodec)
W, H = 60, 17
Z0, Z1 = 15, 42
ZTOP = 2
FLOOR = 14
GAP = (28, 29)
CHIMNEYS = ((25, 2), (32, 2), (19, 1), (38, 1))     # (columna, alto)
LEDGES = ((17, 19, 10), (36, 38, 10))


def build(lair):
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = v if v in (SPIKES_UP,) else enc(v)

    for c in range(1, W + 1):
        for r in range(FLOOR, H + 1): put(c, r, SOLID)
    for c in GAP:
        put(c, FLOOR, SPIKES_UP)
    for c, h in CHIMNEYS:
        for r in range(FLOOR - h, FLOOR): put(c, r, SOLID)
    for a, b, r in LEDGES:
        for c in range(a, b + 1): put(c, r, DROP)
    # la entrada (solo en la guarida: en la arena, llano para los bots de las pruebas): una chimenea y una cornisa;
    # la salida: la meta al final del tejado
    if lair: put(7, FLOOR - 1, SOLID); put(7, FLOOR - 2, SOLID)
    for c in range(9, 12): put(c, 11, DROP)
    for r in (11, 12, 13): put(57, r, FINISH)
    ents = [
        {'type': 'tifon', 'col': 28, 'row': 7},
        {'type': 'bombobject', 'col': 17, 'row': FLOOR - 1, 'props': {'respawn': 4, 'respawnLeft': 1, 'respawnRight': 9}},
        {'type': 'bombobject', 'col': 40, 'row': FLOOR - 1, 'props': {'respawn': 4, 'respawnLeft': 9, 'respawnRight': 1}},
        {'type': 'box', 'col': 22, 'row': FLOOR - 1},
        {'type': 'box', 'col': 35, 'row': FLOOR - 1},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': ZTOP, 'props': {'corner': {'col': Z0 - 1, 'row': FLOOR - 1}, 'zone': 1}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': ZTOP, 'props': {'corner': {'col': Z1 + 3, 'row': FLOOR - 1}, 'zone': 1}},
    ]
    if lair:
        # el tramo de entrada: una bomba para aprender a llevarla y un Soplón que sopla por el tejado
        ents += [
            {'type': 'bombobject', 'col': 5, 'row': FLOOR - 1, 'props': {'respawn': 4}},
            {'type': 'gust', 'col': 11, 'row': 8},
        ]                                        # (más allá de la zona, nada: project_check `jefes`)
    d = {
        'name': 'Tejados del Tifón' if lair else 'Jefe: Tifón',
        'name_en': "Typhoon's Rooftops" if lair else 'Boss: Typhoon',
        'width': W, 'height': H, 'playerStart': [3, FLOOR - 1],
        'tiles': t, 'entities': ents, 'vents': [], 'foliage': [],
        'bossZones': [{'id': 1, 'col': Z0, 'row': ZTOP, 'w': Z1 - Z0 + 1, 'h': FLOOR - ZTOP, 'music': 'tifon'}],
        'background': 'fortress', 'time': 'night', 'openTop': True,
    }
    if lair: d['music'] = 'fortaleza_2'
    return d


if __name__ == '__main__':
    lair = '--lair' in sys.argv
    out = os.path.join(ROOT, 'assets', 'levels', 'tejados_del_tifon.json') if lair else os.path.join(HERE, 'jefe_tifon.json')
    write(build(lair), out)
    print('escrito', out)
