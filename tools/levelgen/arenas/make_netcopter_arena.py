#!/usr/bin/env python3
# tools/levelgen/arenas/make_netcopter_arena.py
# La ARENA DE PRUEBA del Redcóptero (tools/levelgen/arenas/NetcopterArena.json: la usan boss_intro, boss_frames y
# online_boss; docs/bosses/netcopter.md). Hasta el Plan 5d se editaba a mano; ahora sale de aquí: una sala Flappy de 40 x
# 11 SIN SUELO (como las etapas: los pilares de abajo llegan al borde de abajo; caer por él quita 1 y bota), con el fondo
# del Valle (`valley`), un pilar colgando del techo (columna 9, filas 1-3), otro que sube desde abajo (columna 13, filas
# 8-11), la zona del jefe (columnas 17-36, toda la altura, música tuffi) y el Redcóptero en (32, 5). Escribe SOLO ese
# archivo.
#   python3 tools/levelgen/arenas/make_netcopter_arena.py
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import flappy_lib
from flappy_lib import H, AIR, PILLAR

W = 40
tiles = [[AIR] * W for _ in range(H)]
for r in (1, 2, 3):
    tiles[r - 1][9 - 1] = PILLAR
for r in range(8, H + 1):
    tiles[r - 1][13 - 1] = PILLAR

lvl = [
    ('name', "NetcopterArena"),
    ('name_en', "Net-Copter arena"),
    ('width', W), ('height', H),
    ('playerStart', [3, 5]),
    ('tiles', tiles),
    ('entities', [flappy_lib.ent('netcopter', 32, 5)]),
    ('bossZones', [{"id": 1, "col": 17, "row": 1, "w": 20, "h": H, "music": "tuffi"}]),
    ('music', 'flappy'),
    ('flappy', True),
    ('background', 'valley'),
]
out = os.path.join(HERE, 'NetcopterArena.json')
with open(out, 'w') as f:
    f.write('{\n')
    for i, (k, v) in enumerate(lvl):
        end = '' if i == len(lvl) - 1 else ','
        if k == 'tiles':
            f.write('  "tiles": [\n')
            for j, row in enumerate(v):
                f.write('    [' + ','.join(map(str, row)) + ']' + (',' if j < len(v) - 1 else '') + '\n')
            f.write('  ]' + end + '\n')
        elif k == 'entities':
            f.write('  "entities": [' + ','.join(json.dumps({kk: vv for kk, vv in e.items() if vv != {}}, separators=(',', ':'))
                                                 for e in v) + ']' + end + '\n')
        else:
            f.write('  ' + json.dumps(k) + ': ' + json.dumps(v, ensure_ascii=False, separators=(',', ':')) + end + '\n')
    f.write('}\n')
print('escrito', out)
