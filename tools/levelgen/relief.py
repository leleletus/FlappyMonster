#!/usr/bin/env python3
"""RELIEVE sobre un nivel YA HECHO y retocado a mano (2026-11-15; el usuario: «que no se vea tan plano ni cuadrado, como
los niveles nuevos», y «ten cuidado con los mini bloques»). A diferencia de geo.py (que construye niveles nuevos), esto
lee el JSON del nivel y SOLO AÑADE, y solo donde no se juega:

  1. Plano principal: cúpulas de roca y estalactitas DEBAJO de las islas de terreno del paquete (cristal / roca). Una
     casilla nueva solo si:
       - está vacía (ni agua ni pinchos) y cuelga de la isla (se crece hacia abajo desde su cara de abajo, sin huecos);
       - en su columna y en las 3 de cada lado no hay NADA hasta el fondo del nivel salvo la propia isla (debajo no se
         juega: caer ahí ya es el vacío) ni ninguna entidad (ni la ruta de una patrulla);
       - no es una de las 2 columnas del borde de la isla (los saltos que salen de su canto no rozan nada).
     Al crecer hacia abajo desde la isla, ninguna casilla nueva deja una cara de arriba al aire: no da apoyos nuevos.
  2. Plano de fondo (sin colisión): mar de nubes abajo, agujas lejanas y alguna isla lejana, SOLO donde el plano de
     fondo está vacío (lo que hay — las ruinas, el templo — no se pisa).
  NADA de mini bloques.

    python3 tools/levelgen/relief.py via_estelar [--seed 3] [--dry]
Escribe solo las filas de "tiles" y "bgTiles" (el resto del archivo, tal cual: lo escribe el editor).
"""
import json, math, os, random, re, sys

ID_HIGH = 2 ** 17
def enc(i): return i % 16 + (i // 16) * ID_HIGH
def tid(v): return (v % 16) + ((v // ID_HIGH) % 64) * 16 if v else 0

# paquetes de bloques: el terreno que recibe relieve y lo que se pone
PACKS = {
    'starway': {'terrain': {61, 62}, 'rock': 62, 'top': 61, 'cloud': 63},
}
SAFE_SIDE = 3          # columnas a cada lado que tienen que estar vacías hasta el fondo
EDGE = 2               # columnas del borde de la isla sin relieve


def components(g, W, H, terr):
    seen, comps = set(), []
    for r in range(H):
        for c in range(W):
            if (c, r) in seen or tid(g[r][c]) not in terr: continue
            comp, st = [], [(c, r)]
            seen.add((c, r))
            while st:
                x, y = st.pop()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen and tid(g[ny][nx]) in terr:
                        seen.add((nx, ny)); st.append((nx, ny))
            comps.append(comp)
    return comps


def entity_cols(data):
    """columnas ocupadas por entidades (con su patrulla) y la fila más alta de cada una (0-based)"""
    out = []
    for e in data.get('entities', []):
        c0 = c1 = e['col'] - 1
        p = (e.get('props') or {}).get('patrol')
        if p: c0, c1 = min(c0, p['left'] - 1), max(c1, p['right'] - 1)
        corner = (e.get('props') or {}).get('corner')
        r = e['row'] - 1
        if corner: c1 = max(c1, corner['col'] - 1)
        out.append((c0, c1, r))
    return out


def underside(data, pack, rng, log):
    g, W, H = data['tiles'], data['width'], data['height']
    terr = pack['terrain']
    rock = enc(pack['rock'])
    ents = entity_cols(data)
    added = 0
    for comp in components(g, W, H, terr):
        own = set(comp)
        cols = sorted({c for c, _ in comp})
        if len(cols) < 4: continue
        bottom = {c: max(r for cc, r in comp if cc == c) for c in cols}
        # columnas seguidas: una isla puede tener huecos; se trabaja por tramos contiguos
        runs, cur = [], [cols[0]]
        for c in cols[1:]:
            if c == cur[-1] + 1: cur.append(c)
            else: runs.append(cur); cur = [c]
        runs.append(cur)
        for run in runs:
            n = len(run)
            if n < 2 * EDGE + 2: continue
            maxd = max(2, min(9, n // 3))
            want = []
            for i in range(n):
                if i < EDGE or i >= n - EDGE: want.append(0); continue
                x = (i + 0.5) / n
                d = maxd * math.sin(math.pi * x) ** 0.8
                if 0.25 < x < 0.75: d += rng.choice((-1, 0, 0, 1))
                want.append(max(0, int(round(d))))
            for i in range(1, n):
                want[i] = min(want[i], want[i - 1] + 2)
            for i in range(n - 2, -1, -1):
                want[i] = min(want[i], want[i + 1] + 2)
            # estalactitas
            for _ in range(1 if n < 10 else 2):
                i = rng.randrange(EDGE + 1, max(EDGE + 2, n - EDGE - 1))
                want[i] += rng.randrange(2, 4)
            for i, c in enumerate(run):
                for k in range(1, want[i] + 1):
                    r = bottom[c] + k
                    if r >= H - 1 or g[r][c] != 0: break
                    if not safe(g, W, H, c, r, own, ents): break
                    g[r][c] = rock
                    own.add((c, r))
                    added += 1
    log.append('relieve bajo las islas: %d casillas de roca' % added)


def safe(g, W, H, c, r, own, ents):
    for cc in range(c - SAFE_SIDE, c + SAFE_SIDE + 1):
        if cc < 1 or cc >= W - 1: return False
        for rr in range(r, H - 1):
            if (cc, rr) in own: continue
            if tid(g[rr][cc]) != 0: return False
    for c0, c1, er in ents:
        if c0 - SAFE_SIDE <= c <= c1 + SAFE_SIDE and er >= r - 2: return False
    return True


def backdrop(data, pack, rng, log):
    W, H = data['width'], data['height']
    bg = data.get('bgTiles') or [[0] * W for _ in range(H)]
    data['bgTiles'] = bg
    g = data['tiles']
    rock, top, cloud = enc(pack['rock']), enc(pack['top']), enc(pack['cloud'])
    n = 0

    def put(c, r, v):
        nonlocal n
        if 1 <= c < W - 1 and 1 <= r < H - 1 and bg[r][c] == 0:
            bg[r][c] = v; n += 1

    def free(c0, r0, c1, r1):
        return all(bg[r][c] == 0 for r in range(max(0, r0), min(H, r1 + 1)) for c in range(max(0, c0), min(W, c1 + 1)))

    # agujas lejanas (de abajo arriba, afiladas), solo donde todo su sitio está libre en el fondo
    c = 6
    while c < W - 6:
        w = rng.choice((5, 7, 9))
        topr = rng.randrange(int(H * 0.38), int(H * 0.62))
        if free(c - w // 2 - 1, topr - 1, c + w // 2 + 1, H - 2):
            h = H - 2 - topr
            for k, r in enumerate(range(topr, H - 1)):
                ww = 1 + int((w - 1) * (k / max(1, h)) ** 1.1 + 0.5)
                for cc in range(c - (ww - 1) // 2, c - (ww - 1) // 2 + ww):
                    put(cc, r, top if k < 2 else rock)
        c += rng.randrange(10, 17)
    # islas lejanas en el cielo (donde no hay nada en ningún plano)
    for _ in range(W // 40):
        c0 = rng.randrange(4, W - 14)
        w = rng.randrange(6, 11)
        r0 = rng.randrange(3, int(H * 0.3))
        if free(c0 - 1, r0 - 1, c0 + w, r0 + 5) and all(g[r][cc] == 0 for r in range(r0 - 1, r0 + 5) for cc in range(c0 - 1, c0 + w + 1)):
            for i, cc in enumerate(range(c0, c0 + w)):
                x = (i + 0.5) / w
                d = 1 + int(round(3 * math.sin(math.pi * x) ** 0.8))
                for r in range(r0, r0 + d): put(cc, r, top if r == r0 else rock)
    # mar de nubes abajo (el último: las agujas salen de él)
    for c in range(1, W - 1):
        crest = H - 7 + int(round(math.sin(c * 0.37) * 0.8 + math.sin(c * 0.11 + 1.3) * 1.2))
        for r in range(crest, H - 1):
            if bg[r][c] == 0 or tid(bg[r][c]) in (pack['rock'], pack['top']):
                if bg[r][c] == 0: n += 1
                bg[r][c] = cloud
    log.append('plano de fondo: %d casillas nuevas' % n)


def write_rows(text, key, rows):
    """sustituye las filas de la clave `key` (una por línea, como el editor) sin tocar el resto del archivo"""
    lines = [json.dumps(r, separators=(',', ':')) for r in rows]
    body = ',\n'.join('    ' + l for l in lines)
    m = re.search(r'(\n  "%s": \[\n)(.*?)(\n  \])' % re.escape(key), text, re.S)
    if m:
        return text[:m.start(2)] + body + text[m.end(2):]
    # (sin plano de fondo todavía: va detrás de "tiles")
    m = re.search(r'(\n  "tiles": \[\n.*?\n  \],)', text, re.S)
    return text[:m.end(1)] + '\n  "%s": [\n%s\n  ],' % (key, body) + text[m.end(1):]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not args: sys.exit('relief.py: nombra el nivel (p. ej. via_estelar)')
    seed = int(sys.argv[sys.argv.index('--seed') + 1]) if '--seed' in sys.argv else 3
    pack = PACKS['starway']
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'levels')
    for name in args:
        p = os.path.join(root, name + '.json')
        text = open(p, encoding='utf-8').read()
        data = json.loads(text)
        rng, log = random.Random(seed), []
        underside(data, pack, rng, log)
        backdrop(data, pack, rng, log)
        print(name + ':', '; '.join(log))
        if '--dry' in sys.argv: continue
        text = write_rows(text, 'tiles', data['tiles'])
        text = write_rows(text, 'bgTiles', data['bgTiles'])
        json.loads(text)
        open(p, 'w', encoding='utf-8').write(text)
        print('escrito', p)


if __name__ == '__main__':
    main()
