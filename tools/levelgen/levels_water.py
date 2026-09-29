"""Niveles acuáticos. Genera:

- laberinto_submarino: enorme laberinto bajo el agua (solo la orilla de salida
  y la de llegada están secas), repleto de peces globo y pinchos. Aire: bolsas
  de aire (la fila de arriba de algunas cámaras) repartidas por el camino +
  respiraderos (vents). Checkpoints en las bolsas del camino, estrellas y
  vidas extra en los callejones sin salida.

Todo sale de una semilla fija: el mismo laberinto cada vez.

OJO: assets/levels/laberinto_submarino.json es ya la "versión 2" retocada a mano
por el usuario en el editor (escaleras, aire, vents, vidas, peces, decoración).
Regenerarlo (build.py --only laberinto_submarino) BORRA esos retoques.
"""
import random
from lib import Level, SOLID, WATER, EMPTY, FINISH, DROP, UP, DOWN, LEFT, RIGHT, spike_bits, _BASE_SUBS

FLAG_WATER = 16          # tile inundado (TileCodec.FLAG_WATER): p. ej. una plataforma bajo el agua

# ── Rejilla del laberinto ──────────────────────────────────────────────────────
# Celda (i, j) = cámara de 4x4 casillas; entre cámaras, muros de 1 casilla.
# Pasos horizontales: 3 de alto (filas 2..4 de la cámara: la fila de arriba
# queda cerrada, así una bolsa de aire nunca toca agua de lado). Pasos
# verticales: 4 de ancho.
PITCH, IN = 5, 4


def maze_cells(mw, mh, rng):
    """Laberinto perfecto (backtracker): un único camino entre dos cámaras.
    Devuelve el conjunto de pasos abiertos {((i,j),(i2,j2))} con (i,j) < (i2,j2)."""
    seen, stack, opened = {(0, 0)}, [(0, 0)], set()
    while stack:
        i, j = stack[-1]
        nb = [(i + di, j + dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))
              if 0 <= i + di < mw and 0 <= j + dj < mh and (i + di, j + dj) not in seen]
        if not nb:
            stack.pop()
            continue
        # (preferencia por los pasos horizontales: menos pozos verticales
        # largos, que no pueden llevar bolsas de aire)
        n = rng.choice([x for x in nb for _ in range(3 if x[1] == j else 1)])
        seen.add(n)
        opened.add(tuple(sorted(((i, j), n))))
        stack.append(n)
    return opened


def closed_walls(mw, mh, opened):
    out = []
    for i in range(mw):
        for j in range(mh):
            for n in ((i + 1, j), (i, j + 1)):
                if n[0] < mw and n[1] < mh and tuple(sorted(((i, j), n))) not in opened:
                    out.append(tuple(sorted(((i, j), n))))
    return out


def anchors(path, opened, mw, mh):
    """Para cada cámara, la cámara del camino de la que cuelga su rama."""
    on = set(path)
    anc = {c: c for c in path}
    q = list(path)
    while q:
        c = q.pop(0)
        for n in neighbors(c, opened, mw, mh):
            if n not in anc:
                anc[n] = anc[c]
                q.append(n)
    return anc


def count_routes(a, b, opened, mw, mh, cap=10):
    """Caminos simples distintos de a a b (hasta `cap`)."""
    n = 0
    seen = {a}

    def dfs(c):
        nonlocal n
        if n >= cap:
            return
        if c == b:
            n += 1
            return
        for x in neighbors(c, opened, mw, mh):
            if x not in seen:
                seen.add(x); dfs(x); seen.discard(x)
    dfs(a)
    return n


def neighbors(c, opened, mw, mh):
    i, j = c
    out = []
    for n in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
        if 0 <= n[0] < mw and 0 <= n[1] < mh and tuple(sorted((c, n))) in opened:
            out.append(n)
    return out


def bfs_path(a, b, opened, mw, mh):
    prev, q = {a: None}, [a]
    while q:
        c = q.pop(0)
        if c == b:
            break
        for n in neighbors(c, opened, mw, mh):
            if n not in prev:
                prev[n] = c
                q.append(n)
    path, c = [], b
    while c is not None:
        path.append(c)
        c = prev[c]
    return path[::-1]


# ── Polígono del área de un pez (contorno de un conjunto de casillas) ──────────
def area_polygon(tiles):
    """Contorno (centros de casilla) de un conjunto de casillas conexo y de al
    menos 2 de grueso: el borde de la unión de cuadrados, metido media casilla
    hacia dentro. Devuelve [{col,row}, ...]."""
    S = set(tiles)
    edges = {}
    for (c, r) in S:
        x0, y0, x1, y1 = c - 1, r - 1, c, r
        if (c, r - 1) not in S: edges[(x1, y0)] = (x0, y0)      # arriba (interior a la izquierda)
        if (c + 1, r) not in S: edges[(x1, y1)] = (x1, y0)      # derecha
        if (c, r + 1) not in S: edges[(x0, y1)] = (x1, y1)      # abajo
        if (c - 1, r) not in S: edges[(x0, y0)] = (x0, y1)      # izquierda
    start = min(edges)
    pts, p = [start], edges[start]
    while p != start:
        pts.append(p)
        p = edges[p]
    # solo las esquinas (quitar puntos en línea recta)
    corners = []
    n = len(pts)
    for k in range(n):
        a, b, c = pts[k - 1], pts[k], pts[(k + 1) % n]
        if (b[0] - a[0], b[1] - a[1]) != (c[0] - b[0], c[1] - b[1]):
            corners.append(b)
    out = []
    n = len(corners)
    for k in range(n):
        a, b, c = corners[k - 1], corners[k], corners[(k + 1) % n]
        din = (sgn(b[0] - a[0]), sgn(b[1] - a[1]))
        dout = (sgn(c[0] - b[0]), sgn(c[1] - b[1]))
        nin, nout = (din[1], -din[0]), (dout[1], -dout[0])          # normales hacia dentro (izquierda)
        x = b[0] + 0.5 * (nin[0] + nout[0])
        y = b[1] + 0.5 * (nin[1] + nout[1])
        out.append({'col': int(round(x + 0.5)), 'row': int(round(y + 0.5))})
    return out


def sgn(v):
    return (v > 0) - (v < 0)


def laberinto_submarino():
    """Enorme laberinto bajo el agua repleto de peces globo y pinchos. Prueba
    semillas (a partir de una fija) hasta que el laberinto cumple las reglas:
    1 o 2 caminos a la meta y como mucho 3 cámaras seguidas sin aire."""
    for seed in range(20260928, 20260928 + 200):
        try:
            L = _laberinto(seed)
            print('  semilla', seed)
            return L
        except AssertionError as e:
            print('  semilla %d descartada: %s' % (seed, e))
    raise AssertionError('ninguna semilla cumple las reglas')


def _laberinto(seed):
    rng = random.Random(seed)
    MW, MH = 20, 9
    X0 = 16                              # columna del muro izquierdo del laberinto
    Y0 = 8                               # fila del muro de arriba
    W = X0 + PITCH * MW + 18
    H = Y0 + PITCH * MH + 2
    L = Level('Laberinto Submarino', W, H, (5, Y0), music='hidro_city', modes=['race'])
    L.rect(2, 2, W - 1, H - 1, SOLID)

    def cell_box(i, j):
        c0, r0 = X0 + PITCH * i + 1, Y0 + PITCH * j + 1
        return c0, r0, c0 + IN - 1, r0 + IN - 1

    start_cell = (0, 0)
    opened = maze_cells(MW, MH, rng)
    # Salida: la cámara de la columna derecha MÁS LEJANA (por el laberinto)
    # de la entrada: el camino cruza casi todo y no queda media mazmorra
    # "detrás" de la meta sin necesidad de recorrerla
    end_cell = max(((MW - 1, j) for j in range(MH)), key=lambda c: len(bfs_path(start_cell, c, opened, MW, MH)))
    path = bfs_path(start_cell, end_cell, opened, MW, MH)
    # Solo 1 o 2 caminos llevan a la meta: los bucles extra van DENTRO de una
    # misma rama muerta (misma cámara de anclaje: no abren otro camino); y
    # UN solo paso entre ramas distintas da la segunda ruta.
    anc = anchors(path, opened, MW, MH)
    from collections import Counter
    branch = Counter(anc[c] for c in anc if c not in path)
    assert branch.get(end_cell, 0) <= 8, 'hay %d cámaras detrás de la meta' % branch.get(end_cell, 0)
    assert max(branch.values()) <= MW * MH // 5, 'una rama muerta de %d cámaras' % max(branch.values())
    walls = closed_walls(MW, MH, opened)
    rng.shuffle(walls)
    pi = {c: k for k, c in enumerate(path)}
    # Segunda ruta: un paso entre dos zonas que cuelgan de puntos del camino
    # alejados (≥ 8 cámaras): mejor entre dos ramas, si no rama ↔ camino
    cands = [w for w in walls if anc[w[0]] != anc[w[1]] and abs(pi[anc[w[0]]] - pi[anc[w[1]]]) >= 8]
    cands.sort(key=lambda w: (w[0] in path) + (w[1] in path))
    busy = set()
    if cands:
        opened.add(cands[0])
        busy = {anc[cands[0][0]], anc[cands[0][1]]}     # (sus ramas no llevan bucles)
    # Bucles extra solo DENTRO de una misma rama muerta que no use la 2ª ruta:
    # confunden más pero no abren otro camino a la meta
    extra = 0
    for (a, b) in walls:
        if anc[a] == anc[b] and anc[a] not in busy and a not in path and b not in path and extra < 30:
            opened.add((a, b)); extra += 1
    routes = count_routes(start_cell, end_cell, opened, MW, MH)
    assert 1 <= routes <= 2, 'rutas a la meta: %d' % routes
    print('laberinto_submarino: %d rutas a la meta, camino más corto de %d cámaras, %d bucles en ramas muertas'
          % (routes, len(path), extra))
    # (la línea de bolsas de aire se imprime más abajo)
    path = bfs_path(start_cell, end_cell, opened, MW, MH)
    on_path = set(path)

    # ── Cámaras y pasos (todo agua) ────────────────────────────────────────────
    for i in range(MW):
        for j in range(MH):
            c0, r0, c1, r1 = cell_box(i, j)
            L.rect(c0, r0, c1, r1, WATER)
    for (a, b) in opened:
        (i, j), (i2, j2) = a, b
        c0, r0, c1, r1 = cell_box(i, j)
        if i2 == i + 1:                                   # paso horizontal: 3 de alto
            L.rect(c1 + 1, r0 + 1, c1 + 1, r1, WATER)
        else:                                             # paso vertical: 4 de ancho
            L.rect(c0, r1 + 1, c1, r1 + 1, WATER)

    def has_open(c, d):
        i, j = c
        n = (i + d[0], j + d[1])
        return tuple(sorted((c, n))) in opened

    # ── Orillas: salida (izquierda) y llegada (derecha), en rampa hasta el agua
    sc0, sr0, sc1, sr1 = cell_box(*start_cell)
    ec0, er0, ec1, er1 = cell_box(*end_cell)
    surf = sr0 + 1                                        # primera fila de agua (la de arriba es aire)
    # Izquierda: tierra seca y una rampa que baja al agua de la cámara (0,0)
    L.clear(2, 2, X0 - 1, surf - 1)
    L.rect(2, surf, X0 - 1, H - 1, SOLID)
    for k, c in enumerate(range(X0 - 5, X0)):             # rampa: baja 1 por casilla
        L.rect(c, surf, c, surf + k, WATER if k else EMPTY)
    L.rect(X0, sr0, X0, sr1, WATER)                       # abre el muro izquierdo de la cámara
    L.rect(X0, sr0, X0, sr0, EMPTY)
    L.rect(X0 - 5, surf, X0, surf, WATER)                 # superficie continua
    L.start = [5, surf - 1]
    # Derecha: de la cámara final sale un pozo de agua (4 de ancho) que sube
    # hasta la superficie, con escalera de plataformas pegada a la orilla; la
    # orilla seca (suelo a la altura del agua) lleva a la meta
    XE = X0 + PITCH * MW
    L.clear(XE + 1, 2, W - 1, surf - 1)
    L.rect(XE + 1, surf, XE + 4, er1, WATER)              # el pozo
    L.rect(XE, er0 + 1, XE, er1, WATER)                   # abre el muro derecho de la cámara
    for r in range(surf, er1 + 1):                        # escalera (una plataforma por fila)
        L.set(XE + 4, r, DROP + FLAG_WATER)
    L.rect(XE + 5, surf, W - 1, H - 1, SOLID)             # orilla
    L.finish(W - 5, surf - 1)
    L.ent('star', W - 9, surf - 2)

    # ── Bolsas de aire (fila de arriba de la cámara sin agua) ──────────────────
    # En el camino: una cada 4 cámaras como mucho (≈ 9-12 s a nado); también
    # en algunos callejones. Solo en cámaras con el techo cerrado.
    pockets = {start_cell} | ({end_cell} if not has_open(end_cell, (0, -1)) else set())
    MAX_GAP = 2                                           # cámaras seguidas sin aire en el camino
    last = 0                                              # índice de la última bolsa
    for k in range(1, len(path)):
        if path[k] in pockets:
            last = k
        elif k - last >= MAX_GAP + 1 or k == len(path) - 1:
            # la más tardía posible del tramo que pueda llevar bolsa (techo cerrado)
            for kk in range(k, last, -1):
                if not has_open(path[kk], (0, -1)):
                    pockets.add(path[kk]); last = kk
                    break
    gaps, g = [], 0
    for c in path:
        if c in pockets: gaps.append(g); g = 0
        else: g += 1
    assert max(gaps) <= MAX_GAP, 'tramo sin aire de %d cámaras' % max(gaps)
    for c in rng.sample(sorted(set((i, j) for i in range(MW) for j in range(MH)) - on_path), 22):
        if not has_open(c, (0, -1)):
            pockets.add(c)
    for c in pockets:
        c0, r0, c1, r1 = cell_box(*c)
        L.rect(c0, r0, c1, r0, EMPTY)
    print('  aire: %d bolsas; en el camino, como mucho %d cámaras seguidas sin aire' % (len(pockets), max(gaps)))

    # ── Callejones (una sola salida, fuera del camino) ────────────────────────
    dead_ends = [(i, j) for i in range(MW) for j in range(MH)
                 if len(neighbors((i, j), opened, MW, MH)) == 1 and (i, j) not in on_path]

    # ── Pinchos: en las caras cerradas de las cámaras, a trozos ────────────────
    def spike_tile(c, r, d):
        L.set(c, r, WATER + spike_bits(d, _BASE_SUBS[d]))

    for i in range(MW):
        for j in range(MH):
            cell = (i, j)
            # (margen: en el camino menos pinchos que en los callejones)
            if cell in (start_cell, end_cell) or rng.random() < (0.45 if cell in on_path else 0.2):
                continue
            c0, r0, c1, r1 = cell_box(i, j)
            pocket = cell in pockets
            faces = []
            if not has_open(cell, (0, 1)): faces.append('floor')
            if not has_open(cell, (0, -1)) and not pocket: faces.append('ceil')
            if not has_open(cell, (-1, 0)): faces.append('left')
            if not has_open(cell, (1, 0)): faces.append('right')
            rng.shuffle(faces)
            for f in faces[:rng.choice((1, 1, 2) if cell in on_path else (1, 2, 2, 3))]:
                if f == 'floor':
                    a = rng.randint(c0, c1 - 1)
                    for c in range(a, a + 2): spike_tile(c, r1, UP)
                elif f == 'ceil':
                    a = rng.randint(c0, c1 - 1)
                    for c in range(a, a + 2): spike_tile(c, r0, DOWN)
                elif f == 'left':
                    a = rng.randint(r0 + (1 if pocket else 0), r1 - 1)
                    for r in range(a, a + 2): spike_tile(c0, r, RIGHT)
                else:
                    a = rng.randint(r0 + (1 if pocket else 0), r1 - 1)
                    for r in range(a, a + 2): spike_tile(c1, r, LEFT)

    # ── Escaleras de plataformas en los pasos verticales ──────────────────────
    # Bajo el agua un salto sube ≈ 1,1 casillas y el doble ≈ 2,1 (y los saltos
    # solo vuelven al tocar suelo): sin apoyos no se sube de una cámara a la de
    # arriba (5 casillas). Una columna de plataformas traspasables inundadas,
    # una por fila: se sube de salto en salto (se atraviesan desde abajo) y se
    # baja al lado (o agachado a través de ellas).
    for (a, b) in sorted(opened):
        (i, j), (i2, j2) = a, b
        if i2 != i:
            continue
        c0, r0, c1, r1 = cell_box(i, j2)                  # cámara de abajo
        lc = c0 + 1
        for r in range(r0 - 1, r1 + 1):                   # del paso (muro) al fondo
            L.set(lc, r, DROP + FLAG_WATER)

    # ── Repisa para respirar en cada bolsa de aire ────────────────────────────
    # Desde el fondo, con doble salto, la cabeza apenas entra en la fila de aire
    # (en lo alto del salto). Dos plataformas inundadas contra la pared de la
    # derecha (alturas 1 y 2): de pie en la de arriba la cabeza queda en el
    # aire y se respira tranquilo.
    for c in pockets:
        if c == start_cell:
            continue
        c0, r0, c1, r1 = cell_box(*c)
        L.set(c1, r1, DROP + FLAG_WATER)
        L.set(c1, r0 + 2, DROP + FLAG_WATER)

    # ── Peces globo: áreas de 1 a 3 cámaras unidas (rectas o en L) ─────────────
    def water_tiles(cell):
        c0, r0, c1, r1 = cell_box(*cell)
        top = r0 + 1 if cell in pockets else r0          # (el pez no sale al aire)
        return [(c, r) for c in range(c0, c1 + 1) for r in range(top, r1 + 1)]

    def link_tiles(a, b):
        (i, j), (i2, j2) = sorted((a, b))
        c0, r0, c1, r1 = cell_box(i, j)
        if i2 == i + 1:
            return [(c1 + 1, r) for r in range(r0 + 1, r1 + 1)]
        return [(c, r1 + 1) for c in range(c0, c1 + 1)]

    fish_cells = [c for c in sorted(set((i, j) for i in range(MW) for j in range(MH)))
                  if c not in (start_cell, end_cell) and c[0] > 0]
    rng.shuffle(fish_cells)
    used = set()
    nfish = 0
    for cell in fish_cells:
        if cell in used or nfish >= 80:
            continue
        # Densidad: casi todas las cámaras del camino; algo menos fuera
        if rng.random() > (0.75 if cell in on_path else 0.45):
            continue
        group = [cell]
        for _ in range(rng.choice((0, 1, 1, 2))):         # crece por pasos abiertos
            opts = [n for n in neighbors(group[-1], opened, MW, MH) if n not in group and n not in (start_cell, end_cell)]
            if not opts:
                break
            group.append(rng.choice(opts))
        tiles = []
        for k, g in enumerate(group):
            tiles += water_tiles(g)
            if k: tiles += link_tiles(group[k - 1], g)
        area = area_polygon(tiles)
        if len(area) > 24:
            continue
        c0, r0, c1, r1 = cell_box(*cell)
        # (margen: en el camino alcance menor, hinchado más corto y más descanso)
        path_fish = any(g in on_path for g in group)
        L.ent('pufferfish', c0 + 2, r0 + 2, area=area,
              speed=rng.choice((35, 45, 55)),
              range=rng.choice((1.5, 2.0)) if path_fish else rng.choice((2.0, 2.5, 3.0)),
              inflateTime=rng.choice((1.5, 2.0)) if path_fish else rng.choice((2.0, 2.5, 3.0)),
              cooldown=rng.choice((2.5, 3.0)) if path_fish else rng.choice((1.0, 1.5, 2.0)))
        used.update(group)
        nfish += 1

    # ── Checkpoints (en las bolsas del camino), vents, estrellas, vidas ────────
    cps = 0
    for k, c in enumerate(path):
        if c in pockets and c not in (start_cell, end_cell) and k > 5 and cps < 12 and k - 9 * cps > 5:
            c0, r0, c1, r1 = cell_box(*c)
            L.ent('checkpoint', c0 + 2, r1)
            cps += 1
    for k, c in enumerate(path):
        if k % 3 == 1 and c not in pockets:
            c0, r0, c1, r1 = cell_box(*c)
            if L.get(c1 - 1, r1) == WATER:
                L.vent(c1 - 1, r1, 3)
    rng.shuffle(dead_ends)
    for n, c in enumerate(dead_ends[:14]):
        c0, r0, c1, r1 = cell_box(*c)
        if n < 5:
            L.ent('extralife', c0 + 2, r0 + 2)
        else:
            L.ent('star', c0 + 2, r0 + 2)
        if c not in pockets:
            L.vent(c0 + 1, r1, 3)
    return L


BUILDERS = [laberinto_submarino]
