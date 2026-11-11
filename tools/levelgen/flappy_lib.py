# tools/levelgen/flappy_lib.py
# Lo común de los generadores de etapas FLAPPY (levels_flappy_test.py, levels_flappy_valle.py,
# levels_flappy_valle_boss.py): un nivel "flappy": true de 11 filas SIN SUELO (Plan 5d, el usuario tras jugar 0.5.179:
# mejor sin suelo, que los pilares salgan también desde abajo de la pantalla, como salen de arriba), PILARES (tile 59) de
# arriba abajo con su hueco (los de abajo llegan al borde de abajo del nivel), la meta al final y la cámara automática. Caer por
# el borde de abajo quita 1 y bota (src/player/PlayerFlight.lua). Lo que antes se apoyaba en el suelo va en un SOPORTE
# (tile 60 `mount`, hasta el borde: launcher()). Solo escribe el archivo que se le pide.
import json

H = 11


def raw(tile_id):
    # el número que guarda la celda (src/world/tiles/TileCodec.lua): bits 0-3 = id % 16, bits 17-20 = id // 16
    return tile_id % 16 + (tile_id // 16) * 2 ** 17


AIR, FINISH, PILLAR, MOUNT = raw(0), raw(11), raw(59), raw(60)


SOLID = raw(1)


def build(width, gaps, solids=None, air=None, mounts=None):
    """gaps = [(columna, fila de arriba del hueco, alto del hueco), ...] (el pilar ocupa el resto de la columna, de la
    fila 1 a la H); solids = [(columna, fila), ...] bloques sólidos sueltos (el escondite de detrás de un muro agrietado,
    el suelo de un túnel); air = [(columna, fila), ...] casillas que quedan VACÍAS aunque sean de un pilar (un túnel);
    mounts = [(columna, fila de arriba), ...] SOPORTES (de esa fila al borde de abajo) → filas de tiles"""
    tiles = [[AIR] * width for _ in range(H)]
    for c, top, h in gaps:
        assert 1 <= c <= width - 6, c
        for r in range(1, H + 1):
            if not (top <= r < top + h):
                tiles[r - 1][c - 1] = PILLAR
    for c, r in air or []:
        tiles[r - 1][c - 1] = AIR
    for r in range(1, H + 1):
        tiles[r - 1][width - 3] = FINISH
    for c, r in solids or []:
        tiles[r - 1][c - 1] = SOLID
    for c, top in mounts or []:
        for r in range(top, H + 1):
            assert tiles[r - 1][c - 1] == AIR, ('soporte encima de algo', c, r)
            tiles[r - 1][c - 1] = MOUNT
    return tiles


def write(out, name, name_en, width, gaps, speed=200, music='flappy', entities=None, solids=None, arena=None,
          air=None, mounts=None, background=None):
    """arena = lo que devuelve boss_arena(): la cámara automática se para en ella y el nivel lleva su zona de jefe;
    solids, air, mounts = los de build(); background = el fondo del nivel (un bioma de src/fx/Sky.lua, p. ej. 'valley')"""
    lvl = {
        "name": name,
        "name_en": name_en,
        "width": width, "height": H,
        "playerStart": [4, 5],
        "tiles": build(width, gaps, solids, air, mounts),
        "entities": entities or [],
        "autoScroll": {"startCol": 1, "endCol": 0, "speed": speed, "width": 20, "margin": 0.6, "countdown": 0},
        "music": music,
        "flappy": True,
    }
    if arena:
        lvl["autoScroll"]["endCol"] = arena["endCol"]
        lvl["bossZones"] = [arena["zone"]]
        lvl["entities"] = lvl["entities"] + arena["entities"]
        gaps = gaps + arena["gaps"]
        lvl["tiles"] = build(width, gaps, solids, air, mounts)
    if background:
        lvl["background"] = background
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
    print('escrito', out, len(gaps), 'pilares', len(lvl["entities"]), 'entidades')


def ent(kind, col, row, **props):
    return {"type": kind, "col": col, "row": row, "props": props}


def at_gaps(kind, gaps, idx, **props):
    """Una entidad `kind` en el CENTRO del hueco de cada pilar de `idx` (índices de gaps): cargas y comida en la ruta"""
    out = []
    for i in idx:
        c, top, h = gaps[i]
        out.append(ent(kind, c, top + (h - 1) // 2, **props))
    return out


def launcher(col, row, **props):
    """Un LANZARREDES en (col, row) sobre su SOPORTE (de la fila row + 1 al borde de abajo: las etapas no tienen suelo)
    → entidad, soporte para build(mounts=...)"""
    return ent('netlauncher', col, row, **props), (col, row + 1)


def cubby(wc, inside, min_charge=2, **props):
    """Un ESCONDITE arriba del todo: un muro agrietado en (wc, filas 1-2) que pide `min_charge` y, detrás, la casilla
    (wc + 1, 1) con `inside` (una entidad: 'flapcharge', 'cage'... con sus props) encerrada por bloques sólidos debajo y a
    su derecha (solo se llega rompiendo el muro; flappy_campaign `zonas` lo comprueba) → entidades, bloques sólidos"""
    ents = [ent('crackwall', wc, 2, minCharge=min_charge, rows=2), ent(inside, wc + 1, 1, **props)]
    return ents, [(wc + 1, 2), (wc + 2, 1), (wc + 2, 2)]


def corridor(c0, tops, h):
    """Un PASILLO: columnas de pilar SEGUIDAS desde c0, una por cada fila de arriba de `tops`, todas con un hueco de `h`
    filas (la ruta tiene que seguir la curva sin salirse; cambiar como mucho 1 fila por columna) → gaps de build()"""
    for a, b in zip(tops, tops[1:]):
        assert abs(a - b) <= 1, ('pasillo con un escalón de más de 1 fila', c0, tops)
    return [(c0 + i, top, h) for i, top in enumerate(tops)]


def ledge(c0, c1, gaps, row):
    """Una CORNISA: un suelo de bloques sólidos en la fila `row` de c0 a c1 que parte la pantalla en dos rutas. La de
    ABAJO es la de los huecos (han de empezar en row + 2 o más abajo: el pilar que queda debajo de la cornisa cuelga de
    ella); la de ARRIBA, filas 1 a row - 1, es una ruta opcional. VOLABLE solo con row >= 5 (4 filas libres, 256 px): el
    monstruo (caja de fuera 75 px, de su centro 27 arriba y 48 abajo) no puede tocar la piedra (posarse quita 1) y un
    aleteo sube 75 px (FLY_FLAP 450, FLY_GRAVITY 1350) → su centro tiene 181 px (con estalactitas de una fila, 130); con
    row = 4 y estalactitas quedaban 66 px, menos que un aleteo: imposible (el usuario, 2026-11-11) (sin muro: se entra por arriba antes de c0; los pilares
    de dentro pierden esas filas, salvo los huecos que empiecen en la fila 2 —una estalactita de una fila—). El piloto de
    flappy_flight no toma la de arriba (sus huecos tocan un bloque). → bloques sólidos, casillas vacías"""
    for c, top, h in gaps:
        assert not (c0 <= c <= c1) or top >= row + 2 or top == 2, ('hueco bajo la cornisa demasiado alto', c, top)
    solids = [(c, row) for c in range(c0, c1 + 1)]
    air = [(c, r) for c, top, _ in gaps if c0 <= c <= c1 and top != 2 for r in range(1, row)]
    return solids, air


def tunnel(c0, c1, gaps, min_charge=2, floor=3):
    """Un ATAJO arriba: un túnel de las filas 1 a floor - 1 de la columna c0 + 1 a la c1, con un muro agrietado en c0 (pide
    `min_charge`, tan alto como el túnel) y un suelo de bloques sólidos en la fila `floor` de c0 a c1; los pilares de
    dentro pierden esas filas. Por debajo sigue la ruta de los huecos (que han de empezar en la fila floor + 2 o más
    abajo: el pilar de debajo cuelga del suelo); el suelo para las redes de los lanzarredes de debajo. Para que se pueda
    VOLAR dentro hacen falta 4 filas (floor = 5): ver `ledge`. → entidades, bloques sólidos, casillas vacías"""
    for c, top, h in gaps:
        assert not (c0 <= c <= c1) or top >= floor + 2, ('hueco bajo el túnel demasiado alto', c, top)
    ents = [ent('crackwall', c0, floor - 1, minCharge=min_charge, rows=floor - 1)]
    solids = [(c, floor) for c in range(c0, c1 + 1)]
    air = [(c, r) for c, _, _ in gaps if c0 < c <= c1 for r in range(1, floor)]
    return ents, solids, air


def boss_arena(col, boss, w=20, music='tuffi', boss_at=(15, 5), stubs=()):
    """La ARENA del jefe de una etapa Flappy: una zona de jefe de `w` columnas (una pantalla, toda la altura) que empieza en
    la columna `col`, con el jefe `boss` en (col + boss_at[0], boss_at[1]); la cámara automática se PARA justo en ella
    (endCol = su última columna: la ventana queda encima de la zona, AutoScroll 'stop' y la zona se queda la cámara).
    `stubs` = pilares cortos de dentro (paran la red y la bomba del Redcóptero, enemySolid: sirven para cubrirse), como huecos de build() [(columna relativa, fila de arriba, alto)].
    Vencido el jefe, la zona se abre y se sigue volando a la meta (la de build(), al final del nivel). → dict para write()"""
    return {
        "zone": {"id": 1, "col": col, "row": 1, "w": w, "h": H, "music": music},
        "endCol": col + w - 1,
        "entities": [ent(boss, col + boss_at[0], boss_at[1])],
        "gaps": [(col + c, top, h) for c, top, h in stubs],
    }
