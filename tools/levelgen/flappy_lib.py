# tools/levelgen/flappy_lib.py
# Lo común de los generadores de etapas FLAPPY (levels_flappy_test.py, levels_flappy_valle.py): un nivel "flappy": true
# de 11 filas con suelo (césped sobre tierra), PILARES (tile 59) con su hueco, la meta al final y la cámara automática.
# Solo escribe el archivo que se le pide.
import json

H = 11
FLOOR = 10                       # fila del césped (la 11, tierra)


def raw(tile_id):
    # el número que guarda la celda (src/world/tiles/TileCodec.lua): bits 0-3 = id % 16, bits 17-20 = id // 16
    return tile_id % 16 + (tile_id // 16) * 2 ** 17


AIR, DIRT, GRASS, FINISH, PILLAR = raw(0), raw(16), raw(17), raw(11), raw(59)


def build(width, gaps):
    """gaps = [(columna, fila de arriba del hueco, alto del hueco), ...] → filas de tiles"""
    tiles = [[AIR] * width for _ in range(H)]
    for c in range(width):
        tiles[FLOOR - 1][c] = GRASS
        tiles[H - 1][c] = DIRT
    for c, top, h in gaps:
        assert 1 <= c <= width - 6, c
        for r in range(1, FLOOR):        # filas 1..9 (la 10 es el suelo)
            if not (top <= r < top + h):
                tiles[r - 1][c - 1] = PILLAR
    for r in range(1, FLOOR):
        tiles[r - 1][width - 3] = FINISH
    return tiles


def write(out, name, name_en, width, gaps, speed=200, music='flappy'):
    lvl = {
        "name": name,
        "name_en": name_en,
        "width": width, "height": H,
        "playerStart": [4, 5],
        "tiles": build(width, gaps),
        "entities": [],
        "autoScroll": {"startCol": 1, "endCol": 0, "speed": speed, "width": 20, "margin": 0.6, "countdown": 0},
        "music": music,
        "flappy": True,
    }
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
    print('escrito', out, len(gaps), 'pilares')
