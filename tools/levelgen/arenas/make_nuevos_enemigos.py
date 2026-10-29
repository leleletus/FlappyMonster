#!/usr/bin/env python3
# tools/levelgen/arenas/make_nuevos_enemigos.py → nuevos_enemigos.json (arena de PRUEBA de los tres enemigos de 0.5.96,
# docs/entities/enemies.md): un prado con un TOPO de cada isla (prop `isle` fija) y uno de piedra para ver que se para,
# un río de la jungla con PIRAÑAS y un tronco por encima (para que salten a por ti), y un claro con PLANTAS CARNÍVORAS
# y un Escarabajo Rinoceronte para darles de comer. Fondo de la jungla.
# 0.5.97: las pirañas con su ÁREA DE NADO (el río entero: nadan como el pez globo); en el claro, una planta COLGADA de
# un saliente (techo) y otra en la PARED de un pilar, un Gummy que pasea entre ellas (se aparta) y una BOMBA objeto
# para lanzársela a una planta (se la traga y revienta).
#   python3 tools/levelgen/arenas/make_nuevos_enemigos.py
#   tools/tests/run.sh level_shots SCALE=1 -- tools/levelgen/arenas/nuevos_enemigos.json
#   tools/tests/run.sh editor_open PLAY=tools/levelgen/arenas/nuevos_enemigos.json   (jugarlo)
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402  (mismo formato del editor)

EMPTY, SOLID, BORDER, WATER, FINISH = 0, 1, 4, 9, 11
DIRT, GRASS, MUD, JGRASS, JPLAT = 16, 17, 40, 41, 43
ISLES = ['pradera', 'costa', 'fortaleza', 'nieve', 'cueva', 'volcan', 'jungla']   # (el orden de Isles.IDS)
W, H = 66, 12
FLOOR = 8                        # fila de la cara de arriba del suelo
RIVER = (28, 45)                 # columnas del río (filas FLOOR..H-1 de agua)
MEADOW = (2, 25)                 # el prado de los topos (césped); 26-27, piedra (el topo se para ahí)


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    for c in range(2, W):
        for r in range(FLOOR, H):
            if MEADOW[0] <= c <= MEADOW[1]: put(c, r, GRASS if r == FLOOR else DIRT)
            elif RIVER[0] <= c <= RIVER[1]: put(c, r, WATER)
            elif c < RIVER[0]: put(c, r, SOLID)
            else: put(c, r, JGRASS if r == FLOOR else MUD)
    for c in range(34, 39): put(c, 5, JPLAT)                     # un tronco sobre el río
    for c in range(52, 56): put(c, 4, MUD)                       # un saliente (la planta colgada, debajo)
    for r in range(4, FLOOR): put(58, r, MUD)                    # un pilar (la planta de pared, a su izquierda)
    for r in (5, 6, 7): put(W - 2, r, FINISH)
    ents = []
    for i, isle in enumerate(ISLES):
        ents.append({'type': 'mole', 'col': 4 + i * 3, 'row': FLOOR - 1,
                     'props': {'isle': isle, 'patrol': {'left': 3 + i * 3, 'right': 5 + i * 3}}})
    river = [{'col': RIVER[0], 'row': FLOOR}, {'col': RIVER[1], 'row': FLOOR},
             {'col': RIVER[1], 'row': H - 1}, {'col': RIVER[0], 'row': H - 1}]
    for c in (31, 36, 42):
        ents.append({'type': 'piranha', 'col': c, 'row': FLOOR + 2, 'props': {'area': river}})
    for c in (50, 61):
        ents.append({'type': 'carnivoreplant', 'col': c, 'row': FLOOR - 1, 'props': {}})
    ents.append({'type': 'carnivoreplant', 'col': 54, 'row': 5, 'props': {'mount': 'ceiling'}})
    ents.append({'type': 'carnivoreplant', 'col': 57, 'row': 6, 'props': {'mount': 'wall_right'}})
    ents.append({'type': 'gummy_jungle', 'col': 53, 'row': FLOOR - 1, 'props': {'patrol': False, 'pauses': False}})
    ents.append({'type': 'bombobject', 'col': 48, 'row': FLOOR - 1, 'props': {'respawn': 3}})
    ents.append({'type': 'beetle', 'col': 63, 'row': FLOOR - 1, 'props': {'patrol': {'left': 62, 'right': 64}}})
    ents.append({'type': 'mole', 'col': 47, 'row': FLOOR - 1, 'props': {'isle': 'auto', 'patrol': {'left': 46, 'right': 48}}})
    return {
        'name': 'Prueba: topo, piraña y planta', 'name_en': 'Test: mole, piranha and plant',
        'width': W, 'height': H, 'playerStart': [2, FLOOR - 1],
        'tiles': t, 'entities': ents, 'foliage': [],
        'background': 'jungle', 'time': 'day',
    }


if __name__ == '__main__':
    out = os.path.join(HERE, 'nuevos_enemigos.json')
    write(build(), out)
    print('escrito', out)
