#!/usr/bin/env python3
# tools/levelgen/levels_flappy_test.py
# La ETAPA DE PRUEBA del vuelo (paso 2 de docs/design/flappy-prequel.md): assets/levels/_flappy_vuelo.json, un nivel
# Flappy ("flappy": true) con cámara automática y PILARES (tile 59) cada pocas columnas: primero huecos de 4 casillas,
# luego de 3. Sirve para que el usuario juzgue cómo se siente volar; no es un nivel de la campaña. Oculto (empieza por
# '_'): se entra desde el menú de depuración. Escribe SOLO ese archivo.
#   python3 tools/levelgen/levels_flappy_test.py
import json

W, H = 150, 11


def raw(tile_id):
    # el número que guarda la celda (src/world/tiles/TileCodec.lua): bits 0-3 = id % 16, bits 17-20 = id // 16
    return tile_id % 16 + (tile_id // 16) * 2 ** 17


AIR, DIRT, GRASS, FINISH, PILLAR = raw(0), raw(16), raw(17), raw(11), raw(59)
FLOOR = 10                       # fila del césped (la 11, tierra)
tiles = [[AIR] * W for _ in range(H)]
for c in range(W):
    tiles[FLOOR - 1][c] = GRASS
    tiles[H - 1][c] = DIRT

# (columna, fila de arriba del hueco, alto del hueco): de fácil a difícil
GAPS = []
col = 20
tops4 = [4, 5, 3, 6, 4, 2, 5, 6]
tops3 = [5, 3, 6, 4, 2, 6, 3, 5, 4, 6]
for t in tops4:
    GAPS.append((col, t, 4)); col += 7
for t in tops3:
    GAPS.append((col, t, 3)); col += 6
for c, top, h in GAPS:
    for r in range(1, FLOOR):            # filas 1..9 (la 10 es el suelo)
        if not (top <= r < top + h):
            tiles[r - 1][c - 1] = PILLAR
assert col < W - 6, col
for r in range(1, FLOOR):
    tiles[r - 1][W - 3] = FINISH

lvl = {
    "name": "Vuelo de prueba",
    "name_en": "Test flight",
    "width": W, "height": H,
    "playerStart": [4, 5],
    "tiles": tiles,
    "entities": [],
    "autoScroll": {"startCol": 1, "endCol": 0, "speed": 200, "width": 20, "margin": 0.6, "countdown": 0},
    "music": "flappy",
    "flappy": True,
}
out = 'assets/levels/_flappy_vuelo.json'
with open(out, 'w') as f:
    f.write('{\n')
    keys = list(lvl.keys())
    for i, k in enumerate(keys):
        v = lvl[k]
        last = i == len(keys) - 1
        if k == 'tiles':
            f.write('  "tiles": [\n')
            for j, row in enumerate(v):
                f.write('    [' + ','.join(map(str, row)) + ']' + (',' if j < len(v) - 1 else '') + '\n')
            f.write('  ]' + ('' if last else ',') + '\n')
        else:
            f.write('  ' + json.dumps(k) + ': ' + json.dumps(v, ensure_ascii=False, separators=(',', ':')) + ('' if last else ',') + '\n')
    f.write('}\n')
print('escrito', out, len(GAPS), 'pilares')
