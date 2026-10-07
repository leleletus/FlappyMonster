#!/usr/bin/env python3
# tools/levelgen/add_apples.py — pone MANZANAS (curan 1 de vida) en niveles ya hechos SIN tocar nada más del JSON
# (se añaden líneas al final de "entities", en el formato del editor; lo retocado a mano se conserva).
#   · niveles de CÁMARA AUTOMÁTICA: cuatro repartidas por el recorrido
#   · niveles con JEFE: una a medio camino y otra justo antes de la arena (para llegar entero a la pelea)
#   · --checkpoints N nivel: una junto a cada N-ésimo checkpoint (niveles largos y duros: el laberinto submarino)
#   · --at 0.25,0.5,0.75 nivel: en esas fracciones del ancho (niveles a oscuras…)
# Vale también BAJO EL AGUA (casilla con agua, suelo debajo). Siempre de pie en suelo firme (no pinchos, no lava, no agua), lejos de otras entidades, de la salida y de la zona
# del jefe. No hace nada en un nivel que ya tenga manzanas.   python3 tools/levelgen/add_apples.py nivel [nivel ...]
import json, os, sys

LEVELS = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels')
GROUND = {1, 4, 16, 17, 29, 30, 35, 36, 38, 39, 2, 10}


def tid(raw): return raw % 16 + 16 * ((raw >> 17) % 16)
WATER = 16
def plain(raw):                                   # (sin pinchos ni nada encima; con agua vale)
    raw &= ~WATER
    return raw == tid(raw) % 16 + ((tid(raw) // 16) << 17)
def free(raw): return raw in (0, 9, 16, 25)          # (aire, agua — casilla de agua o encharcada —; sin pinchos)


def spots(d, gap=2):
    T, W, H = d['tiles'], d['width'], d['height']
    ents = [(e['col'], e['row']) for e in d.get('entities', [])]
    zones = d.get('bossZones', [])
    out = []
    for r in range(2, H - 1):                    # (índices 0: la fila r es la casilla del objeto)
        for c in range(1, W - 1):
            if not free(T[r][c]) or not free(T[r - 1][c]): continue
            g = T[r + 1][c]
            if tid(g) not in GROUND or not plain(g): continue
            col, row = c + 1, r + 1
            if any(abs(col - ec) <= gap and abs(row - er) <= gap for ec, er in ents): continue
            if abs(col - d['playerStart'][0]) < 6: continue
            if any(z['col'] - 1 <= col <= z['col'] + z['w'] and z['row'] - 1 <= row <= z['row'] + z['h'] for z in zones): continue
            # (suelo de al menos 3 de ancho: no en un pilar suelto)
            if not all(tid(T[r + 1][c + k]) in GROUND for k in (-1, 1)): continue
            out.append((col, row))
    return out


def pick(cands, col, used):
    best = None
    for c, r in cands:
        if any(abs(c - u) < 8 for u in used): continue
        k = (abs(c - col), -r)                   # el más cercano a esa columna; a igualdad, el más bajo
        if best is None or k < best[0]: best = (k, (c, r))
    return best and best[1]


def add(name, every=None, fracs=None):
    path = os.path.join(LEVELS, name + '.json')
    text = open(path, encoding='utf-8').read()
    d = json.loads(text)
    if any(e['type'] == 'apple' for e in d.get('entities', [])):
        print('  %s: ya tiene manzanas' % name); return
    cands = spots(d, 1 if every else 2)
    near = None
    if every:
        cps = sorted((e['col'], e['row']) for e in d['entities'] if e['type'] == 'checkpoint')
        near = cps[every - 1::every]
        wanted = []
    elif fracs:
        wanted = [int(d['width'] * f) for f in fracs]
    elif d.get('autoScroll'):
        wanted = [int(d['width'] * f) for f in (0.2, 0.4, 0.6, 0.82)]
    elif d.get('bossZones'):
        z = min(d['bossZones'], key=lambda z: z['col'])
        wanted = [z['col'] // 2, z['col'] - 5]
        cands = [s for s in cands if s[0] < z['col'] - 1]
    else:
        wanted = [int(d['width'] * f) for f in (0.35, 0.7)]
    got, used = [], []
    for cc, cr in near or []:                    # junto a ese checkpoint: la casilla libre más cercana (≤ 5)
        best = None
        for c, r in cands:
            k = abs(c - cc) + 2 * abs(r - cr)
            if k <= 9 and abs(c - cc) >= 2 and (c, r) not in got and (best is None or k < best[0]): best = (k, (c, r))
        if best: got.append(best[1])
    for col in wanted:
        s = pick(cands, col, used)
        if s: got.append(s); used.append(s[0])
    if not got:
        print('  %s: sin sitio' % name); return
    i = text.index('"entities": [')
    j = text.index('\n  ]', i)
    lines = ',\n'.join('    {"col":%d,"row":%d,"type":"apple"}' % s for s in got)
    sep = ',\n' if text[i:j].rstrip().endswith('}') else '\n'
    text = text[:j] + sep + lines + text[j:]
    json.loads(text)
    open(path, 'w', encoding='utf-8').write(text)
    print('  %s: manzanas en %s' % (name, got))


if __name__ == '__main__':
    if len(sys.argv) < 2: sys.exit('uso: add_apples.py nivel [nivel ...]')
    args, every, fracs = sys.argv[1:], None, None
    if args[0] == '--checkpoints': every, args = int(args[1]), args[2:]
    elif args[0] == '--at': fracs, args = [float(x) for x in args[1].split(',')], args[2:]
    for n in args: add(n, every, fracs)
