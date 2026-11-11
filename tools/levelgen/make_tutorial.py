#!/usr/bin/env python3
# tools/levelgen/make_tutorial.py — el NIVEL TUTORIAL (docs/design/tutorial-level.md): assets/levels/tutorial.json.
# Cada SECCIÓN es un mapa de caracteres de 18 filas (la leyenda, abajo) + los textos de sus carteles, en orden; se pegan
# de izquierda a derecha. Regla del diseño: el camino NUNCA depende de un objeto (caja, trampolín, semilla, puerta):
# esos llevan a un PREMIO opcional — así nadie se queda atascado y level_solve (que solo mira el terreno) lo comprueba.
#   python3 tools/levelgen/make_tutorial.py            → escribe el nivel SOLO si no existe (el usuario puede haberlo
#                                                       retocado en el editor)
#   python3 tools/levelgen/make_tutorial.py --force    → lo reescribe
#   python3 tools/levelgen/make_tutorial.py --print    → solo muestra el mapa entero en texto
import json, os, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'levels', 'tutorial.json')
H = 18

# ── Leyenda ──────────────────────────────────────────────────────────────────────────────────────────────────────
# Tiles: '.' aire · '#' tierra (césped arriba, solo) · '=' plataforma traspasable · '-' plataforma · 'B' rompible ·
#        'S' Activador ON · 'O' Bloque ON (sólido ahora) · 'p' Bloque OFF inactivo (sólido tras cambiar) · '~' agua ·
#        '@' agua con respiradero · 'I' hielo · 'i' hielo fino · '^' pinchos en el suelo · 'F' meta
# Entidades (la casilla queda de aire; en el agua, de agua): 'P' salida · '?' cartel · 'k' checkpoint · '*' estrella ·
#        'a' comida · '+' vida extra · 'g' Gummy · 'h' Gummy con casco · 'c' Crabby · 'x' caja pequeña · 'X' caja ·
#        't' trampolín · 'y' géiser · 'D' puerta (de su Activador 'S' de la misma sección) · 'e' semilla
TILE = {'.': 0, '=': 10, '-': 2, 'B': 12, 'S': 13, 'O': 18, 'p': 28, '~': 9, '@': 9, 'I': 30, 'i': 31, 'F': 11}
ENT = {'?': 'hint', 'k': 'checkpoint', '*': 'star', 'a': 'apple', '+': 'extralife', 'g': 'gummy', 'h': 'gummy',
       'c': 'crabby', 'x': 'smallbox', 'X': 'box', 't': 'trampoline', 'y': 'geyser', 'D': 'door', 'e': 'seed'}

def encode(tid, water=False, spikes_up=False):
    raw = tid % 16 + (tid // 16) * 2 ** 17
    if water: raw += 16
    if spikes_up:                                   # (subceldas de abajo, BL y BR, hacia arriba: dir 0)
        for sh in (11, 14): raw += 2 ** (sh + 2)
    return raw

# ── Las secciones ────────────────────────────────────────────────────────────────────────────────────────────────
# (filas 1..18; el suelo empieza en la 14: se está de pie en la 13)
SECTIONS = []
def section(name, rows, texts=(), dark=False, extra=None):
    assert len(rows) == H, (name, len(rows))
    w = len(rows[0])
    for r in rows: assert len(r) == w, (name, r)
    SECTIONS.append({'name': name, 'rows': rows, 'texts': list(texts), 'dark': dark, 'extra': extra or {}})

G = '#'
def ground(w): return [G * w] * 5

section('andar', [
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '.P..?.........',
] + ground(14), ['tut.walk'])

section('correr', [
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '..............*.*...',
    '....................',
    '....................',
    '....................',
    '..?.................',
    '####......##########',
    '####......##########',
    '####################',
    '####################',
    '####################',
], ['tut.run'])  # (el foso: 2 de hondo, se sale saltando)

section('saltar', [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '.............*..',
    '................',
    '.........###....',
    '..?..##..###....',
] + ground(16), ['tut.jump'])

section('doble_salto', [
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..........*...',
    '..............',
    '..............',
    '.......#######',
    '.k?....#######',
] + ground(14), ['tut.double'])  # (2 casillas: el salto solo sube 1,6)

section('agacharse', [
    '##################',
    '##################',
    '##################',
    '##################',
    '##################',
    '##################',
    '##################',
    '##################',
    '.......###........',
    '.......###........',
    '.......###........',
    '.......###........',
    '..?.......*.......',
] + ground(18), ['tut.crouch'])  # (el túnel: 1 casilla de alto y 3 de largo — agachado no se anda: se pasa con saltos agachados —)

section('plataformas', [
    '..........####',
    '..........####',
    '..........####',
    '..........####',
    '..........####',
    '..........####',
    '..........####',
    '..........####',
    '..........####',
    '..........####',
    '...###====####',
    '..####........',
    '?#####....*...',
] + ground(14), ['tut.drop'])  # (escalones arriba; la única bajada es la plataforma traspasable)

section('pisar', [
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '.k?.....g.........',
] + ground(18), ['tut.stomp'])

section('pinchos', [
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '..?...^^^..a..?..c..',
] + ground(20), ['tut.health', 'tut.spikes_enemy'])

section('ground_pound', [
    '................',
    '................',
    '................',
    '..........###...',
    '..........###...',
    '..........###...',
    '..........###...',
    '..........###...',
    '..........###...',
    '..........###...',
    '..........###...',
    '..........###...',
    '.k?.......###...',
    '######BBBB###...',
    '######.........#',
    '######........##',
    '################',
    '################',
], ['tut.pound'])  # (la tapa rompible; debajo, el pasillo y los escalones de salida — fuera de debajo del pilar: el usuario lo encontró
# imposible, el primer escalón tenía 1 casilla de techo —)

section('cabezazo', [
    '..............O...',
    '..............O...',
    '..............O...',
    '..............O...',
    '..............O...',
    '..............O...',
    '..........*...O...',
    '..............O...',
    '..............O...',
    '....BB...S....O...',
    '..............O...',
    '..............O...',
    '..?...........O...',
] + ground(18), ['tut.bump'])

section('objetos', [
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '......*.*.*...',
    '..............',
    '..........+...',
    '..............',
    '.k?...........',
] + ground(14), ['tut.pickups'])

section('cargar', [
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..............*...',
    '..................',
    '.............####.',
    '.k?...x......####.',
] + ground(18), ['tut.carry'])

section('empujar', [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '...........*....',
    '................',
    '..........###...',
    '..?...X...###...',
] + ground(16), ['tut.push'])

section('trampolin', [
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '..............',
    '......+.......',
    '.....----.....',
    '..............',
    '..............',
    '..............',
    '..............',
    '..?...t.......',
] + ground(14), ['tut.trampoline'])

section('agua', [
    '......................',
    '......................',
    '......................',
    '......................',
    '......................',
    '......................',
    '......................',
    '......................',
    '......................',
    '......................',
    '......................',
    '......................',
    '.k?...................',
    '####~~~~~~~~~~~~~~####',
    '####~~~~~~~~~~~~~#####',
    '####~~~~~~~*~~~~######',
    '####~~~~@~~~~~@#######',
    '######################',
], ['tut.water'])  # (escalones bajo el agua a la salida: nadando los saltos son flojos y solo se recargan en el suelo)

section('hielo', [
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '....................',
    '..?.........?.......',
    '##IIIIIIII##iiii####',
    '##########....######',
    '####################',
    '####################',
    '####################',
], ['tut.ice', 'tut.thin_ice'])  # (bajo el hielo fino, un hoyo de 1: se sale saltando)

section('geiser', [
    '................',
    '................',
    '................',
    '................',
    '................',
    '...........*....',
    '..........#####.',
    '................',
    '................',
    '................',
    '................',
    '................',
    '.k?.....y.......',
] + ground(16), ['tut.geyser'])  # (la plataforma, al lado del chorro: sube y se mueve a ella)

section('puerta', [
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '..........########',
    '..........#.....##',
    '....S.....#..+..##',
    '..................',
    '..................',
    '..?.......D.......',
] + ground(18), ['tut.door'])  # (la puerta cierra el paso: su Activador, arriba a la izquierda, con un cabezazo)

section('oscuro', [
    '##########################',
    '##########################',
    '##########################',
    '##########################',
    '##########################',
    '##########################',
    '..........................',
    '..........................',
    '..........................',
    '..............----........',
    '..........................',
    '........###.........###...',
    '.k?.....###....*....###...',
] + ground(26), ['tut.light'], dark=True)

section('semilla', [
    '..................',
    '..................',
    '..................',
    '..................',
    '..............*...',
    '.............####.',
    '.............####.',
    '.............####.',
    '.............####.',
    '.............####.',
    '.............####.',
    '.............####.',
    '.k?...e...........',
] + ground(18), ['tut.seed'])  # (el pilar del premio; por debajo se pasa agachado)

section('meta', [
    '............',
    '............',
    '............',
    '............',
    '............',
    '............',
    '............',
    '............',
    '............',
    '.......F....',
    '.......F....',
    '.......F....',
    '..?....F....',
] + ground(12), ['tut.goal'])

# ── Construcción ─────────────────────────────────────────────────────────────────────────────────────────────────
def build():
    W = sum(len(s['rows'][0]) for s in SECTIONS)
    grid = [['.'] * W for _ in range(H)]
    entities, vents, links, scenes = [], [], [], []
    start = None
    x0 = 0
    door_id = 0
    for s in SECTIONS:
        w = len(s['rows'][0])
        texts = list(s['texts'])
        door_id_here = None
        switch_here = None
        for r, row in enumerate(s['rows']):
            for c, ch in enumerate(row):
                col, rr = x0 + c + 1, r + 1
                if ch in ENT or ch == 'P':
                    # (en el agua — agua a un lado —, la casilla sigue siendo de agua)
                    side = [row[k] for k in (c - 1, c + 1) if 0 <= k < len(row)]
                    grid[r][x0 + c] = '~' if any(k in '~@' for k in side) else '.'
                    if ch == 'P':
                        start = [col, rr]; continue
                    e = {'type': ENT[ch], 'col': col, 'row': rr}
                    if ch == '?':
                        assert texts, ('sin texto para un cartel', s['name'])
                        e['props'] = {'text': texts.pop(0)}
                    elif ch in 'gh':
                        e['props'] = {'patrol': {'left': col - 3, 'right': col + 3}}
                        if ch == 'h': e['props']['helmet'] = True
                    elif ch == 'c':
                        e['props'] = {'patrol': {'left': col - 2, 'right': col + 2}}
                    elif ch == 'y':
                        e['props'] = {'height': 8}
                    elif ch == 'e':
                        e['props'] = {'life': 30}
                    elif ch == 'D':
                        door_id += 1; door_id_here = door_id
                        e['props'] = {'id': door_id}
                    entities.append(e)
                else:
                    grid[r][x0 + c] = ch
                    if ch == 'S': switch_here = (col, rr)
                    if ch == '@': vents.append({'col': col, 'row': rr, 'sub': 3})
        assert not texts, ('textos de más', s['name'], texts)
        if door_id_here:
            assert switch_here, ('puerta sin Activador', s['name'])
            links.append({'col': switch_here[0], 'row': switch_here[1], 'to': door_id_here})
        if s['dark']:
            scenes.append({'col': x0 + 1, 'w': w, 'dark': True, 'background': 'cave', 'time': 'night'})
        x0 += w
    tiles = []
    for r in range(H):
        out = []
        for c in range(W):
            ch = grid[r][c]
            if ch == '#':
                above = grid[r - 1][c] if r > 0 else '#'
                out.append(encode(16 if above == '#' else 17))
            elif ch == '^':
                out.append(encode(0, False, True))
            else:
                out.append(encode(TILE[ch], ch in '~@'))
        tiles.append(out)
    assert start, 'sin salida (P)'
    level = {
        'name': 'Tutorial', 'name_en': 'Tutorial',
        'width': W, 'height': H, 'playerStart': start,
        'tiles': tiles, 'entities': entities, 'foliage': [], 'vents': vents,
        'music': 'tutorial', 'parTime': 0,
        'modes': [],                                 # (ningún modo online: el tutorial es de un jugador)
    }
    if links: level['links'] = links
    if scenes: level['scenes'] = scenes
    return level, grid

def dump(level):
    # una fila de casillas por línea (como el editor)
    lines = ['{']
    keys = [k for k in level if k != 'tiles']
    for k in ['name', 'name_en', 'width', 'height', 'playerStart']:
        lines.append('  %s: %s,' % (json.dumps(k), json.dumps(level[k], ensure_ascii=False)))
    lines.append('  "tiles": [')
    for i, row in enumerate(level['tiles']):
        lines.append('    ' + json.dumps(row, separators=(',', ':')) + (',' if i < len(level['tiles']) - 1 else ''))
    lines.append('  ],')
    rest = [k for k in keys if k not in ('name', 'name_en', 'width', 'height', 'playerStart')]
    for i, k in enumerate(rest):
        lines.append('  %s: %s%s' % (json.dumps(k), json.dumps(level[k], ensure_ascii=False), ',' if i < len(rest) - 1 else ''))
    lines.append('}')
    return '\n'.join(lines) + '\n'

if __name__ == '__main__':
    level, grid = build()
    if '--print' in sys.argv:
        for r in grid: print(''.join(r))
        print('ancho', level['width'], '· secciones', len(SECTIONS), '· entidades', len(level['entities']))
        sys.exit(0)
    if os.path.exists(OUT) and '--force' not in sys.argv:
        print('ya existe', os.path.relpath(OUT, ROOT), '(puede estar retocado a mano): --force para reescribirlo')
        sys.exit(1)
    with open(OUT, 'w') as f: f.write(dump(level))
    print('escrito', os.path.relpath(OUT, ROOT), '·', level['width'], 'x', level['height'], '·', len(level['entities']), 'entidades')
