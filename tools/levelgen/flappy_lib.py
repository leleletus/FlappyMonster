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


def write(out, name, name_en, width, gaps, speed=200, music='flappy', entities=None):
    lvl = {
        "name": name,
        "name_en": name_en,
        "width": width, "height": H,
        "playerStart": [4, 5],
        "tiles": build(width, gaps),
        "entities": entities or [],
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
            if k == 'entities' and v:
                f.write('  "entities": [\n')
                for j, e in enumerate(v):
                    f.write('    ' + json.dumps(e, ensure_ascii=False, separators=(',', ':')) + (',' if j < len(v) - 1 else '') + '\n')
                f.write('  ]' + ('' if last else ',') + '\n')
            elif k == 'tiles':
                f.write('  "tiles": [\n')
                for j, row in enumerate(v):
                    f.write('    [' + ','.join(map(str, row)) + ']' + (',' if j < len(v) - 1 else '') + '\n')
                f.write('  ]' + ('' if last else ',') + '\n')
            else:
                f.write('  ' + json.dumps(k) + ': ' + json.dumps(v, ensure_ascii=False, separators=(',', ':')) + ('' if last else ',') + '\n')
        f.write('}\n')
    print('escrito', out, len(gaps), 'pilares', len(entities or []), 'entidades')


def ent(kind, col, row, **props):
    return {"type": kind, "col": col, "row": row, "props": props}


def populate(gaps, charges, food, cage, wall):
    """Objetos de una etapa (Plan 4): CARGAS en el centro del hueco de los pilares `charges` (índices de gaps), COMIDA
    en el de `food`, la JAULA (índice, carga mínima) arriba entre dos pilares y el MURO (índice) arriba entre dos pilares
    tapando una carga. La ruta principal (los huecos) nunca queda tapada."""
    out = []
    for i in charges:
        c, top, h = gaps[i]
        out.append(ent('flapcharge', c, top + (h - 1) // 2))
    for i in food:
        c, top, h = gaps[i]
        out.append(ent('apple', c, top + (h - 1) // 2))
    ci, cmin = cage
    out.append(ent('cage', gaps[ci][0] + 3, 2, minCharge=cmin))
    wc = gaps[wall][0] + 3
    out.append(ent('crackwall', wc, 2, minCharge=2, rows=2))
    out.append(ent('flapcharge', wc + 1, 1))
    return out
