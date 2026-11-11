#!/usr/bin/env python3
"""Añade Saltarines (`hopper`) a los niveles nombrados (el usuario, 2026-11-10: «más hoppers en TODOS los niveles»).

Solo añade filas al final de `entities`, sin tocar nada más del archivo (ni el formato). Busca suelo llano con aire
encima para sus saltos, lejos de la salida, la meta, las zonas de jefe, los pinchos, otros enemigos y lo que haya colocado.
Uno cada ~30 columnas, repartidos, con su ruta acotada a ese suelo. Aspecto: `auto` (el de la isla).

  python3 tools/levelgen/add_hoppers.py valle_soleado playa_rebotes     (exige nombres; --dry solo cuenta)

Pasarlo una sola vez por nivel: añadiría otros. Después: `run.sh bot_nav BUILD=1 -- <niveles con grafo>`, las semillas de
MenuScene.SCENES (`run.sh menu_flow FINDSEED=30`) y `run.sh docs_reference`.
"""
import json, os, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
GROUND = {1, 4, 16, 17, 29, 30, 35, 36, 38, 39, 40, 41, 42, 50, 51, 52, 53, 54, 60}
EVERY = 30
PICKUPS_OK = {'star', 'hint', 'life', 'food'}          # (no estorban: se puede estar cerca)


def tile_id(raw): return raw % 16 + (raw >> 17) * 16
def spiky(raw): return (raw // 32) % 4096 != 0


def spots(d, tall=3, longest=4):
    W, H, T = d['width'], d['height'], d['tiles']
    def at(c, r): return T[r - 1][c - 1] if 1 <= c <= W and 1 <= r <= H else 1
    def air(c, r): return at(c, r) == 0
    def ground(c, r):
        raw = at(c, r)
        return raw != 0 and not spiky(raw) and not (raw >> 4) & 1 and tile_id(raw) in GROUND
    sx, sy = d['playerStart']
    goals = [(c, r) for r in range(1, H + 1) for c in range(1, W + 1) if tile_id(at(c, r)) in (11, 44)]
    zones = d.get('bossZones') or []
    ents = d['entities']
    out = []
    for r in range(3, H):
        c = 2
        while c < W:
            ok = air(c, r) and ground(c, r + 1) and all(air(c, r - k) for k in range(1, tall + 1))
            if not ok:
                c += 1; continue
            c0 = c
            while c < W and air(c, r) and ground(c, r + 1) and all(air(c, r - k) for k in range(1, tall + 1)): c += 1
            c1 = c - 1
            if c1 - c0 + 1 >= longest:
                for x in range(c0 + 1, c1):
                    if abs(x - sx) < 14 and abs(r - sy) < 8: continue
                    if any(abs(x - g[0]) < 4 and abs(r - g[1]) < 8 for g in goals): continue
                    if any(z['col'] - 3 <= x <= z['col'] + z['w'] + 2 for z in zones): continue
                    if zones and x > max(z['col'] + z['w'] - 1 for z in zones): continue   # (nada más allá del jefe)
                    near = False
                    for e in ents:
                        if e.get('type') in PICKUPS_OK or abs(e.get('row', 0) - r) > 4: continue
                        if abs(e['col'] - x) < 3: near = True; break
                    if near: continue
                    out.append((x, r, max(c0, x - 4), min(c1, x + 4)))
    return out


def add(name, dry):
    path = os.path.join(ROOT, 'assets', 'levels', name + '.json')
    raw = open(path, encoding='utf8', newline='').read()
    d = json.loads(raw)
    cand = spots(d) or spots(d, 2, 3)          # (arenas muy justas: a falta de algo mejor)
    want = max(1, round(d['width'] / EVERY))
    chosen = []
    for k in range(want):
        centre = (k + 0.5) * d['width'] / want
        pool = [s for s in cand if all(abs(s[0] - q[0]) >= 10 or abs(s[1] - q[1]) > 4 for q in chosen)]
        if not pool: break
        chosen.append(min(pool, key=lambda s: (abs(s[0] - centre), -s[1])))
    print('  %-24s ancho %3d: %d de %d (sitios %d)' % (name, d['width'], len(chosen), want, len(cand)))
    if dry or not chosen: return
    # (en las arenas de puntos — bonus, online — los enemigos pisables dan el 40 % y reaparecen: arnés bot_nav)
    arena = any(e['type'] == 'pointarea' for e in d['entities'])
    extra = {'points': 6, 'respawn': 8} if arena else {}
    lines = ['    ' + json.dumps({'col': c, 'props': dict({'patrol': {'left': l, 'right': rr}}, **extra), 'row': r, 'type': 'hopper'},
                                 separators=(',', ':'), sort_keys=True) for c, r, l, rr in chosen]
    i = raw.index('"entities": [')
    if raw[i:i + 16].startswith('"entities": []'):
        new = raw[:i] + '"entities": [\n' + ',\n'.join(lines) + '\n  ]' + raw[i + len('"entities": []'):]
    else:
        j = raw.index('\n  ]', i)
        new = raw[:j] + ',\n' + ',\n'.join(lines) + raw[j:]
    b = json.loads(new)
    assert b['entities'][:len(d['entities'])] == d['entities'] and {k: v for k, v in b.items() if k != 'entities'} == {k: v for k, v in d.items() if k != 'entities'}
    open(path, 'w', encoding='utf8', newline='').write(new)


if __name__ == '__main__':
    names = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not names: sys.exit('Hay que nombrar los niveles (no toca ninguno sin nombre).')
    for n in names: add(n, '--dry' in sys.argv)
