#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_nieve.py → jefe_nieve.json (arena de prueba de la Gran
# Bola de Nieve; levels_boss.lago_helado() la injerta en el nivel del juego).
#   python3 tools/levelgen/arenas/make_jefe_nieve.py
# Arena (zona: columnas 12-29, filas 3-12; suelo de hielo en la 13):
#   - suelo de HIELO (resbala) entero
#   - dos plataformas de nieve (fila 9, 3 casillas sobre el suelo) con un Activador
#     ON/OFF en medio de cada una
#   - COMPUERTAS: Bloques ON (cols 13 y 28, filas 11-12), del Activador más cercano;
#     los Activadores empiezan APAGADOS (compuertas bajadas)
#   - CONGELADORES (modo Activador; cada Activador dispara los 2 de su lado): en la
#     pared de las repisas (cols 11 y 30, fila 12) por el suelo (la compuerta subida
#     corta el chorro) y colgados del techo (cols 19 y 22, fila 4) hacia abajo, sobre el centro
#   - entrada / salida por REPISAS en la fila 10: se entra andando y dejándose caer
import json, os

def enc(i): return i % 16 + (i // 16) * 2 ** 17

EMPTY, SOLID, BORDER, WATER, FINISH = 0, 1, 4, 9, 11
SW_OFF, SB_ON_X, SNOW, ICE, THIN = 14, 19, 29, 30, 31
W, H = 40, 15
t = [[EMPTY] * W for _ in range(H)]
def put(c, r, v): t[r - 1][c - 1] = enc(v)
for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
# repisas de entrada y salida (se entra andando y dejándose caer: sin saltos)
for c in list(range(2, 12)) + list(range(30, 40)):
    for r in range(10, 15): put(c, r, SNOW)
for c in range(12, 30):
    put(c, 13, ICE); put(c, 14, SNOW)
# plataformas a 3 casillas del suelo (el jefe cabe debajo, también hinchado)
for c in list(range(13, 18)) + list(range(24, 29)): put(c, 9, SNOW)
# Activadores APAGADOS al empezar: compuertas bajadas (se entra libre)
put(15, 9, SW_OFF); put(26, 9, SW_OFF)
for r in (11, 12): put(13, r, SB_ON_X); put(28, r, SB_ON_X)
put(37, 9, FINISH)
# los congeladores van en la pared de las repisas (celdas 11 y 30 de la fila 12)
put(11, 12, EMPTY); put(30, 12, EMPTY)
ents = [
    {'type': 'snowboss', 'col': 21, 'row': 12},
    {'type': 'bosswall', 'col': 9, 'row': 3, 'props': {'corner': {'col': 11, 'row': 9}, 'zone': 1, 'material': 'snow'}},
    {'type': 'bosswall', 'col': 30, 'row': 3, 'props': {'corner': {'col': 32, 'row': 9}, 'zone': 1, 'material': 'snow'}},
    {'type': 'bosswall', 'col': 9, 'row': 2, 'props': {'corner': {'col': 32, 'row': 2}, 'zone': 1, 'material': 'snow'}},
    {'type': 'cryo', 'col': 11, 'row': 12, 'props': {'mode': 'switch', 'id': 1, 'dir': 'right', 'range': 7, 'windup': 0.5, 'freezeTime': 3.5}},
    {'type': 'cryo', 'col': 30, 'row': 12, 'props': {'mode': 'switch', 'id': 2, 'dir': 'left', 'range': 7, 'windup': 0.5, 'freezeTime': 3.5}},
    # congeladores del techo, sobre el centro: cada uno con el Activador de su lado
    {'type': 'cryo', 'col': 19, 'row': 4, 'props': {'mode': 'switch', 'id': 1, 'dir': 'down', 'range': 9, 'windup': 0.5, 'freezeTime': 3.5}},
    {'type': 'cryo', 'col': 22, 'row': 4, 'props': {'mode': 'switch', 'id': 2, 'dir': 'down', 'range': 9, 'windup': 0.5, 'freezeTime': 3.5}},
]
level = {
    'name': 'Jefe: Gran Bola de Nieve', 'name_en': 'Boss: Big Snowball',
    'width': W, 'height': H, 'playerStart': [4, 9],
    'background': 'snow', 'time': 'dusk', 'snow': True,
    'tiles': t, 'entities': ents,
    'links': [{'col': 15, 'row': 9, 'to': 1}, {'col': 26, 'row': 9, 'to': 2}],
    'foliage': [{'type': 'icicle', 'col': c, 'row': 3} for c in (14, 16, 25, 27)],
    'bossZones': [{'id': 1, 'col': 12, 'row': 3, 'w': 18, 'h': 10, 'music': 'winter_nes'}],
}
out = os.path.join(os.path.dirname(__file__), 'jefe_nieve.json')
with open(out, 'w', encoding='utf-8') as f:
    json.dump(level, f, ensure_ascii=False, indent=1)
print(out)
