#!/usr/bin/env python3
# tools/levelgen/add_apples.py — pone MANZANAS (curan 1 de vida) en niveles ya hechos SIN tocar nada más del JSON
# (se añaden líneas al final de "entities", en el formato del editor; lo retocado a mano se conserva).
#   · niveles de CÁMARA AUTOMÁTICA: cuatro repartidas por el recorrido
#   · niveles con JEFE: una a medio camino y otra justo antes de la arena (para llegar entero a la pelea)
# Siempre de pie en suelo firme (no pinchos, no lava, no agua), lejos de otras entidades, de la salida y de la zona
# del jefe. No hace nada en un nivel que ya tenga manzanas.   python3 tools/levelgen/add_apples.py nivel [nivel ...]
import json, os, sys

LEVELS = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels')
GROUND = {1, 4, 16, 17, 29, 30, 35, 36, 38, 39, 2, 10}


def tid(raw): return raw % 16 + 16 * ((raw >> 17) % 16)
def plain(raw): return raw == tid(raw) % 16 + ((tid(raw) // 16) << 17)       # (sin agua ni pinchos encima)


def spots(d):
    T, W, H = d['tiles'], d['width'], d['height']
    ents = [(e['col'], e['row']) for e in d.get('entities', [])]
    zones = d.get('bossZones', [])
    out = []
    for r in range(2, H - 1):                    # (índices 0: la fila r es la casilla del objeto)
        for c in range(1, W - 1):
            if T[r][c] != 0 or T[r - 1][c] != 0: continue
            g = T[r + 1][c]
            if tid(g) not in GROUND or not plain(g): continue
            col, row = c + 1, r + 1
            if any(abs(col - ec) <= 2 and abs(row - er) <= 2 for ec, er in ents): continue
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


def add(name):
    path = os.path.join(LEVELS, name + '.json')
    text = open(path, encoding='utf-8').read()
    d = json.loads(text)
    if any(e['type'] == 'apple' for e in d.get('entities', [])):
        print('  %s: ya tiene manzanas' % name); return
    cands = spots(d)
    if d.get('autoScroll'):
        wanted = [int(d['width'] * f) for f in (0.2, 0.4, 0.6, 0.82)]
    elif d.get('bossZones'):
        z = min(d['bossZones'], key=lambda z: z['col'])
        wanted = [z['col'] // 2, z['col'] - 5]
        cands = [s for s in cands if s[0] < z['col'] - 1]
    else:
        wanted = [int(d['width'] * f) for f in (0.35, 0.7)]
    got, used = [], []
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
    for n in sys.argv[1:]: add(n)
