#!/usr/bin/env python3
# tools/levelgen/arenas/make_mashup_cangrejos.py → assets/levels/mashup_cangrejos.json, el nivel del EVENTO Mega Mashup
# de los Cangrejos (docs/bosses/crab-mashup.md; solo en Juego Libre: no está en ningún mundo de la historia).
#   python3 tools/levelgen/arenas/make_mashup_cangrejos.py
#
# Cose en UN nivel las arenas de los cuatro cangrejos gigantes TAL COMO ESTÁN en sus niveles de la historia (casillas,
# decoraciones, paredes de jefe, bloques de fase, lo que haya dentro), una al lado de otra separadas por roca, y un
# ESCENARIO nuevo para el final:
#
#   [Tantrum: guarida_cangrejo_rey] ▓ [Icy: glaciar_cangrejo] ▓ [Gloomy: gruta_lugubre] ▓ [Groove: isla_del_groove] ▓
#   [ESCENARIO GRANDE: los cuatro por relevos] → salida (meta)
#
# Cada arena es una ESCENA (su fondo, hora, oscuridad, nieve, pinchos: src/world/level/Scenes.lua) y una zona de jefe
# de EVENTO (la lleva el director `crabmashup`, no empieza sola). Los cangrejos, con las props del evento: 2 de vida por
# turno (+1 por jugador extra) que no escala la dificultad, sin enfado en su turno (rageMode 'never') y enfadados
# en el final ('always'); el Groove de su arena, con los platos desde el principio; el del final pone el escenario grande.
# OJO: si se regenera, se pierde lo que se haya cambiado a mano en el editor (este nivel se hace aquí).
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_jefe_nieve import write, enc   # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
LEVELS = os.path.join(ROOT, 'assets', 'levels')
EMPTY, SOLID, BORDER, FINISH = 0, 1, 4, 11
H = 15
SEP = 3                                         # columnas de roca entre arenas

# (rol, nivel de la historia, props del cangrejo en el evento)
EVENT = {'hp': 4, 'hpPerPlayer': 2, 'fixedHp': True, 'event': True}   # (0.5.63, el usuario: con 2 era muy fácil)
SOURCES = [
    ('tantrum', 'guarida_cangrejo_rey', {'rageMode': 'never'}),
    ('icy', 'glaciar_cangrejo', {'rageMode': 'never'}),
    ('gloomy', 'gruta_lugubre', {'rageMode': 'never'}),
    ('groove', 'isla_del_groove', {'rageMode': 'never', 'decksFromStart': True}),
]
BOSS_TYPE = {'tantrum': 'megacrabby', 'icy': 'megacrabby_ice', 'gloomy': 'megagloomy', 'groove': 'groovecrab'}
SCENE_KEYS = ('background', 'time', 'clouds', 'light', 'dark', 'snow', 'echo', 'spikeSkin', 'depth', 'surfaceRow')


def shift_props(p, dc, zone_new):
    p = json.loads(json.dumps(p or {}))
    if 'zone' in p: p['zone'] = zone_new
    for k in ('corner',):
        if isinstance(p.get(k), dict) and 'col' in p[k]: p[k]['col'] += dc
    for k in ('area', 'points', 'route'):
        if isinstance(p.get(k), list):
            for q in p[k]:
                if isinstance(q, dict) and 'col' in q: q['col'] += dc
    if isinstance(p.get('point'), dict) and 'col' in p['point']: p['point']['col'] += dc
    return p


def build():
    cols = []                                   # columnas del nivel nuevo: lista de 15 valores cada una
    ents, fol, subs, zones, scenes = [], [], [], [], []
    start = None

    def rock(n):
        for _ in range(n): cols.append([enc(BORDER)] * H)

    rock(2)
    for zi, (role, name, extra) in enumerate(SOURCES, start=1):
        d = json.load(open(os.path.join(LEVELS, name + '.json'), encoding='utf-8'))
        assert d['height'] == H, name
        z = d['bossZones'][0]
        walls = [e for e in d['entities'] if e['type'] == 'bosswall' and (e.get('props') or {}).get('zone')]
        c0 = min([e['col'] for e in walls] + [z['col'] - 1])
        c1 = max([(e.get('props') or {}).get('corner', {}).get('col', e['col']) for e in walls] + [z['col'] + z['w']])
        base = len(cols) + 1                   # columna nueva de c0
        dc = base - c0
        for c in range(c0, c1 + 1):
            cols.append([d['tiles'][r][c - 1] for r in range(H)])
        for e in d['entities']:
            corner = (e.get('props') or {}).get('corner', {}).get('col')
            if not (c0 <= e['col'] <= c1) or (corner is not None and not (c0 <= corner <= c1)): continue
            ne = dict(e, col=e['col'] + dc, props=shift_props(e.get('props'), dc, zi))
            if e['type'] == BOSS_TYPE[role]:
                ne['props'].update(EVENT, mashupRole=role, **extra)
            elif e['type'] in ('megacrabby', 'megacrabby_ice', 'megagloomy', 'groovecrab'):
                continue
            ents.append(ne)
        for f in d.get('foliage', []):
            if c0 <= f['col'] <= c1: fol.append(dict(f, col=f['col'] + dc))
        for s in d.get('subtiles', []):
            if c0 <= s['col'] <= c1: subs.append(dict(s, col=s['col'] + dc))
        zones.append({'id': zi, 'col': z['col'] + dc, 'row': z['row'], 'w': z['w'], 'h': z['h'],
                      'music': z.get('music', 'boss'), 'event': True})
        sc = {'col': base, 'w': c1 - c0 + 1}
        for k in SCENE_KEYS:
            if k in d: sc[k] = d[k]
        scenes.append(sc)
        if zi == 1:
            ents.append({'type': 'crabmashup', 'col': z['col'] + dc + 3, 'row': z['row']})
        rock(SEP)

    # ── EL ESCENARIO DEL FINAL: zona de 28 columnas a cielo abierto, suelo de arena en la 13; a los lados, paredes de
    # jefe; a la derecha, la salida (la meta) que se abre al acabar
    sand = 262147                               # (la arena del escenario de la isla del Groove)
    zw, floor = 26, 13                          # (26: como la arena de la Gloomy; era 28 — el usuario, 0.5.64)
    base = len(cols) + 1
    stage = [[EMPTY] * H for _ in range(3 + zw + 3 + 8)]
    for c, colv in enumerate(stage):
        for r in range(floor, H + 1): colv[r - 1] = sand
    zc = base + 3
    for r in (10, 11, 12): stage[3 + zw + 3 + 5][r - 1] = enc(FINISH)
    for r in range(1, H + 1): stage[-1][r - 1] = enc(BORDER)
    cols += stage
    zones.append({'id': 5, 'col': zc, 'row': 3, 'w': zw, 'h': 10, 'music': 'groove', 'event': True})
    ents += [
        {'type': 'bosswall', 'col': zc - 3, 'row': 3, 'props': {'corner': {'col': zc - 1, 'row': 12}, 'zone': 5}},
        {'type': 'bosswall', 'col': zc + zw, 'row': 3, 'props': {'corner': {'col': zc + zw + 2, 'row': 12}, 'zone': 5}},
    ]
    fin = {'tantrum': (zc + 6, 12, {'summonPool': 4, 'summonCount': 2, 'summonMax': 4}),
           'icy': (zc + 11, 12, {}), 'gloomy': (zc + 16, 12, {}),
           'groove': (zc + 21, 12, {'bigStage': True})}
    for role, (c, r, extra) in fin.items():
        p = dict(EVENT, mashupRole=role, rageMode='always', **extra)
        ents.append({'type': BOSS_TYPE[role], 'col': c, 'row': r, 'props': p})
    scenes.append({'col': base, 'w': len(stage), 'background': 'coast', 'time': 'night'})
    start = [zc + zw // 2 - 3, floor - 1]      # (se empieza en el ESCENARIO, a la vista: la intro es allí — el usuario, 0.5.62)

    W = len(cols)
    tiles = [[cols[c][r] for c in range(W)] for r in range(H)]
    return {
        'name': 'Mega Mashup de los Cangrejos', 'name_en': 'Crab Mega Mashup',
        'width': W, 'height': H, 'playerStart': start,
        'tiles': tiles, 'entities': ents, 'foliage': fol, 'vents': [], 'subtiles': subs,
        'bossZones': zones, 'scenes': scenes,
        'event': True, 'modes': ['race'], 'music': 'costa_groove',
        # (se empieza en el ESCENARIO: el cielo del nivel es el suyo — antes era el de la costa de día y se hacía de
        #  noche de golpe al empezar la intro; el usuario, 0.5.63)
        'background': 'coast', 'time': 'night',
    }


if __name__ == '__main__':
    out = os.path.join(LEVELS, 'mashup_cangrejos.json')
    d = build()
    write(d, out)
    print('escrito', out, d['width'], 'columnas', len(d['entities']), 'entidades')
