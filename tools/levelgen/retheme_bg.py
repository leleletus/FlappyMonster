"""El PLANO DE FONDO por isla: `retheme.py --bg <niveles>` (la línea de órdenes y la seguridad, en retheme.py).

Pone ESTRUCTURAS en el plano de fondo (src/world/level/BackPlane.lua: `bgTiles` + decoraciones con `plane = 'bg'`) donde
hay hueco detrás de la capa jugable, según el tema de la isla (THEMES de retheme.py):
  pradera / bosque   colinas de tierra y césped + árboles grandes (roble, abedul, abeto)
  playa / trópico    dunas de arena, peñascos de arenisca (con césped en el trópico) + cocoteros y palmeras
  fortaleza          murallas de piedra con almenas y ventanas, torres; estandartes y hiedra en ellas; cipreses
  nieve              lomas de nieve, muros de hielo con nieve encima, ruinas de ladrillo helado + abetos nevados
  cueva / mina / submarino  montones de roca en el suelo, roca que cuelga del techo, columnas; cristales y setas gigantes
  volcán             agujas y muros de basalto, montones de ceniza + árboles muertos
  jungla             ruinas del templo (columnatas con dintel y arcos, pirámides escalonadas, muros rotos) + ceibas
Lo que NUNCA tiene plano detrás (para que el camino se lea): pinchos, lava, agua, plataformas y bloques sueltos (con 1
casilla de margen y 2 por encima, donde se pisa), trampas, objetos y puntos de control, la salida y la meta, las zonas
de jefe y sus muros. Cerca del inicio, la meta y los puntos de control solo va algo bajo (zonas ligeras), sin árboles.
Las estructuras nunca llegan a menos de 1 casilla de lo de arriba (se recortan enteras, sin muescas).

Lo GENERADO se apunta en un fichero aparte (`tools/levelgen/bg_gen/<nivel>.json`; con --out, `<dir>/<nivel>.bggen.json`):
cada bloque [col, fila, valor] y cada decoración tal cual. El editor no guarda claves desconocidas del nivel, por eso
no va dentro del JSON. Al rehacer (--force) solo se quita lo apuntado que siga IGUAL en el nivel (lo que el usuario
haya cambiado o puesto encima es suyo y se queda); un nivel con plano hecho a mano (sin ese fichero) no se toca nunca.
"""
import json, math, os

import retheme as R

GEN_DIR = 'tools/levelgen/bg_gen'

BG_TYPES = R.BG_TYPES           # (los tipos que van siempre al plano)
# Tamaño (ancho, alto) en casillas de lo que se pone (sprites / 64 px × 4): para ver si cabe
SIZE = {'big_oak': (5.8, 6.1), 'big_birch': (3.5, 6.6), 'big_fir': (3.3, 7.1), 'coconut_palm': (5.1, 7.1),
        'twin_palm': (5.9, 7.1), 'young_palm': (2.9, 2.8), 'snowy_fir': (3.6, 7.1), 'snowy_fir_small': (2.3, 3.8),
        'dead_tree': (5.1, 5.8), 'giant_mushroom': (4, 4.9), 'giant_mushroom_violet': (4, 4.9), 'old_tree': (4.9, 5.4),
        'cypress': (1.5, 6.1), 'ceiba': (3.6, 8.1), 'strangler_fig': (2.6, 6.1),
        'hazel_bush': (2.3, 1.3), 'boulder': (1.8, 1.1), 'stump': (1.4, 0.9), 'snow_rock': (1.6, 1), 'iceberg': (1.9, 1.7), 'basalt_rock': (1.1, 0.8),
        'charred_stump': (1.4, 1), 'obsidian_shards': (1.3, 1.1), 'beach_rocks': (1.5, 0.8), 'driftwood': (2, 0.7),
        'cave_crystals': (1.1, 1), 'cave_boulder': (1.6, 1.1), 'broken_pillar': (1, 2.6), 'stone_idol': (1, 1.6),
        'fallen_block': (1.4, 0.8), 'urn': (1.1, 1.2), 'broken_column': (1.8, 2.6), 'mushroom_cluster': (1.5, 1)}
HANG = {'banner', 'ivy_hang', 'liana_long', 'liana_mid', 'liana_short', 'hanging_moss', 'flower_vine', 'stalactite', 'hanging_roots'}

E, SOLID, BORDER, WATER = R.EMPTY, R.SOLID, R.BORDER, R.WATER
DIRT, GRASS, SNOW, ICE, SAND, DEEP = R.DIRT, R.GRASS, R.SNOW, R.ICE, R.SAND, R.DEEP
BASALT, ASH, MUD, JGRASS, TEMPLE = R.BASALT, R.ASH, R.MUD, R.JGRASS, R.TEMPLE
LAVA = 3
# Entidades que se tienen que LEER (trampas, mecanismos, objetos): sin plano a 1 casilla; las que caen, tampoco en su
# columna hasta el suelo. Los enemigos se mueven y se leen solos sobre el fondo oscuro: no cuentan.
READ_ENTS = {'rainspike', 'spikefall', 'mortar', 'gust', 'trampoline', 'trampoline_left', 'trampoline_right', 'trampoline_down',
             'phaseblock', 'cryo', 'bomb', 'bombobject', 'smallbox', 'box', 'scale', 'star', 'extralife', 'apple', 'mirror'}
FALLING = {'rainspike', 'spikefall'}
LIGHT_R = {'start': 8, 'finish': 7, 'checkpoint': 4}      # zonas ligeras (columnas a cada lado): solo cosas bajas
LIGHT_H = 2
TALL_FRONT = {'oak_tree', 'pine_tree', 'palmtree', 'snowy_pine', 'charred_tree', 'tree_fern', 'banana_plant', 'ceiba', 'strangler_fig'}


# ── Qué pone cada tema ──────────────────────────────────────────────────────────────────────────────────────────────
# kinds: (estructura, peso, ancho mín, máx, alto mín, máx); gap: casillas entre estructuras; trees: (tipo, peso, apoyos)
# (apoyos: bloques — de delante o del plano — sobre los que puede estar); small: decoraciones pequeñas encima del plano
SOIL = {GRASS, DIRT}
SPEC = {
    'meadow': dict(kinds=[('hill', 1, 6, 20, 2, 4)], gap=(0, 3), cap=4,
                   mat=dict(top=GRASS, body=DIRT),
                   trees=[('big_oak', 3, SOIL), ('big_birch', 2, SOIL), ('big_fir', 1, SOIL)], tree_gap=9, tree_p=0.45,
                   small=[('hazel_bush', 3), ('boulder', 2), ('stump', 1)], small_p=0.1),
    'forest': dict(kinds=[('hill', 1, 6, 18, 2, 5)], gap=(0, 2), cap=5,
                   mat=dict(top=GRASS, body=DIRT),
                   trees=[('big_fir', 3, SOIL), ('big_oak', 2, SOIL), ('big_birch', 2, SOIL)], tree_gap=7, tree_p=0.6,
                   small=[('hazel_bush', 3), ('stump', 2), ('boulder', 1)], small_p=0.12),
    'beach': dict(kinds=[('dune', 3, 8, 16, 2, 3), ('outcrop', 2, 4, 7, 3, 6)], gap=(2, 6), cap=6,
                  mat=dict(top=SAND, body=SAND, rock=SAND, rockcap=None),        # (peñascos de arenisca: la piedra al fondo sale negra)
                  trees=[('coconut_palm', 3, {SAND, GRASS, DIRT}), ('twin_palm', 2, {SAND, GRASS, DIRT}),
                         ('young_palm', 2, {SAND, GRASS, DIRT})], tree_gap=8, tree_p=0.5,
                  small=[('beach_rocks', 2), ('driftwood', 1)], small_p=0.1),
    'tropical': dict(kinds=[('hill', 2, 8, 14, 2, 3), ('outcrop', 2, 4, 7, 3, 6)], gap=(2, 5), cap=6,
                     mat=dict(top=GRASS, body=DIRT, rock=SAND, rockcap=GRASS),
                     trees=[('coconut_palm', 3, {SAND, GRASS, DIRT}), ('twin_palm', 2, {SAND, GRASS, DIRT}),
                            ('young_palm', 2, {SAND, GRASS, DIRT})], tree_gap=8, tree_p=0.5,
                     small=[('beach_rocks', 1)], small_p=0.05),
    'fortress': dict(kinds=[('wall', 3, 7, 14, 4, 6), ('tower', 1, 4, 4, 6, 8)], gap=(3, 8), cap=8,
                     mat=dict(body=SOLID),
                     trees=[('cypress', 3, {SOLID, BORDER, DIRT, GRASS}), ('old_tree', 1, {SOLID, BORDER, DIRT, GRASS})],
                     tree_gap=10, tree_p=0.3, small=[('urn', 1)], small_p=0.06),
    'snow': dict(kinds=[('hill', 3, 8, 14, 2, 3), ('icewall', 1, 5, 9, 3, 4), ('frostwall', 1, 5, 9, 3, 5)], gap=(1, 5), cap=6,
                 mat=dict(top=SNOW, body=SNOW, ice=ICE, brick=R.FBRICK, rock=R.IROCK, window=R.FWINDOW),
                 trees=[('snowy_fir', 3, {SNOW}), ('snowy_fir_small', 3, {SNOW})], tree_gap=6, tree_p=0.55,
                 small=[('snow_rock', 1)], small_p=0.03),
    # (costa helada: barreras de hielo y lomas bajas de nieve — a nivel del mar, sin bosque —, algún iceberg encima)
    'frozen_coast': dict(kinds=[('icewall', 3, 5, 10, 2, 4), ('hill', 1, 8, 14, 1, 2)], gap=(2, 6), cap=5,
                         mat=dict(top=SNOW, body=SNOW, ice=ICE),
                         trees=[('snowy_fir_small', 1, {SNOW})], tree_gap=16, tree_p=0.12,
                         small=[('iceberg', 2), ('snow_rock', 1)], small_p=0.06),
    'cave': dict(kinds=[('mound', 1, 6, 14, 2, 4)], gap=(1, 5), cap=4,
                 mat=dict(top=SOLID, body=SOLID, drape=SOLID),
                 trees=[('giant_mushroom', 2, {SOLID, BORDER, DEEP, DIRT}), ('giant_mushroom_violet', 2, {SOLID, BORDER, DEEP, DIRT})],
                 tree_gap=12, tree_p=0.35, small=[('cave_crystals', 3), ('cave_boulder', 1), ('mushroom_cluster', 1)], small_p=0.2),
    'mine': dict(kinds=[('mound', 1, 6, 14, 2, 4)], gap=(1, 5), cap=4,
                 mat=dict(top=DIRT, body=SOLID, drape=SOLID),
                 trees=[('giant_mushroom', 1, {SOLID, BORDER, DEEP, DIRT})], tree_gap=16, tree_p=0.25,
                 small=[('cave_crystals', 2), ('cave_boulder', 2)], small_p=0.15),
    'underwater': dict(kinds=[('mound', 1, 6, 14, 2, 4)], gap=(1, 5), cap=4,
                       mat=dict(top=DEEP, body=DEEP, drape=DEEP),
                       trees=[('giant_mushroom_violet', 1, {SOLID, BORDER, DEEP})], tree_gap=14, tree_p=0.3,
                       small=[('cave_crystals', 1)], small_p=0.15),
    'volcano': dict(kinds=[('spire', 3, 2, 4, 4, 8), ('mesa', 2, 4, 7, 3, 5), ('mound', 2, 6, 10, 2, 3)], gap=(2, 6), cap=8,
                    mat=dict(top=ASH, body=BASALT, rock=BASALT, rockcap=None),
                    trees=[('dead_tree', 1, {ASH, BASALT})], tree_gap=10, tree_p=0.4,
                    small=[('charred_stump', 2), ('basalt_rock', 2), ('obsidian_shards', 1)], small_p=0.12),
    'jungle': dict(kinds=[('colonnade', 3, 9, 13, 5, 7), ('ziggurat', 2, 7, 11, 3, 5), ('ruinwall', 2, 4, 8, 2, 5),
                          ('hill', 1, 8, 12, 2, 3)], gap=(2, 6), cap=8,
                   mat=dict(top=JGRASS, body=MUD, rock=TEMPLE),
                   trees=[('ceiba', 2, {JGRASS, MUD, GRASS, DIRT}), ('strangler_fig', 2, {JGRASS, MUD, GRASS, DIRT})],
                   tree_gap=9, tree_p=0.45, small=[('broken_pillar', 2), ('stone_idol', 1), ('fallen_block', 2)], small_p=0.12),
}
CAVE_LIKE = {'cave', 'mine', 'underwater'}
HILLS = {'hill', 'dune', 'mound'}


class Gen:
    def __init__(self, lv, name, theme, rnd, user_bg):
        self.lv, self.name, self.theme, self.rnd = lv, name, theme, rnd
        self.spec = SPEC[theme]
        self.T = lv['tiles']
        self.H, self.W = len(self.T), len(self.T[0])
        self.user = user_bg                                     # el plano que ya hay (del usuario): no se pisa
        self.P = [[0] * self.W for _ in range(self.H)]          # lo nuestro
        self.decos, self.boxes, self.trees = [], set(), []
        self.closed = theme in R.CLOSED or name in R.ROOFED
        self._terrain()
        self._avoid()

    # ── lo de delante ──
    def at(self, c, r):
        return self.T[r][c] if 0 <= r < self.H and 0 <= c < self.W else R.enc(BORDER)

    def empty(self, c, r):
        raw = self.at(c, r)
        return R.tid(raw) == E and not R.waterlogged(raw) and not R.spiky(raw)

    def _terrain(self):
        """Terreno = bloques de suelo unidos al marco o en masas grandes (≥ 12); lo demás son bloques sueltos."""
        H, W = self.H, self.W
        g = lambda c, r: R.tid(self.T[r][c]) in R.GROUND and not R.spiky(self.T[r][c])
        self.terr = set()
        seen = set()
        for r in range(H):
            for c in range(W):
                if (c, r) in seen or not g(c, r): continue
                comp, stack, frame = [], [(c, r)], False
                while stack:
                    x, y = stack.pop()
                    if (x, y) in seen or not (0 <= x < W and 0 <= y < H) or not g(x, y): continue
                    seen.add((x, y)); comp.append((x, y))
                    if x in (0, W - 1) or y in (0, H - 1): frame = True
                    stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                if frame or len(comp) >= 12: self.terr |= set(comp)

    def _avoid(self):
        H, W, lv = self.H, self.W, self.lv
        av = self.av = set()
        cap = self.capH = [99] * W

        def box(c0, r0, c1, r1):
            for x in range(c0, c1 + 1):
                for y in range(r0, r1 + 1): av.add((x, y))

        for r in range(H):
            for c in range(W):
                raw = self.T[r][c]
                i = R.tid(raw)
                if (c, r) in self.terr: continue
                if i == E and not R.waterlogged(raw) and not R.spiky(raw): continue
                if i == WATER or (i == E and R.waterlogged(raw)) and not R.spiky(raw):
                    av.add((c, r)); continue                    # (detrás del agua, nada)
                box(c - 1, r - 2, c + 1, r + 1)                 # pinchos, lava, plataformas, bloques sueltos, meta...
                if i == R.FINISH: box(c - 3, r - 3, c + 3, r + 1)
        for e in lv.get('entities', []):
            c, r, tp = e['col'] - 1, e['row'] - 1, e['type']
            props = e.get('props') or {}
            if tp in ('bosswall', 'bossglass') and props.get('corner'):
                k = props['corner']
                c1, r1 = (k.get('col', c + 1) - 1, k.get('row', r + 1) - 1) if isinstance(k, dict) else (k[0] - 1, k[1] - 1)
                box(min(c, c1) - 3, 0, max(c, c1) + 3, H - 1)
            elif tp == 'checkpoint':
                box(c - 2, r - 3, c + 2, r + 1)
                for x in range(c - LIGHT_R['checkpoint'], c + LIGHT_R['checkpoint'] + 1):
                    if 0 <= x < W: cap[x] = min(cap[x], LIGHT_H)
            elif tp == 'avalanche':                             # (el alud: su canal entero, hasta abajo, se tiene que leer)
                box(c - 1, r - 1, c + int(props.get('width', 2)), r + int(props.get('length', 10)))
            elif tp in READ_ENTS or tp.startswith('trampoline'):
                box(c - 1, r - 1, c + 1, r + 1)
                if tp in FALLING:
                    y = r
                    while y < H and self.empty(c, y): av.add((c, y)); y += 1
        for z in lv.get('bossZones', []) or []:
            box(z['col'] - 1 - 3, 0, z['col'] - 1 + z['w'] + 2, H - 1)
        ps = lv.get('playerStart', [2, 2])
        sc, sr = ps[0] - 1, ps[1] - 1
        box(sc - 3, sr - 3, sc + 3, sr + 1)
        fins = [c for r in range(H) for c in range(W) if R.tid(self.T[r][c]) == R.FINISH]
        for x in range(W):
            if abs(x - sc) <= LIGHT_R['start'] or any(abs(x - f) <= LIGHT_R['finish'] for f in fins):
                cap[x] = min(cap[x], LIGHT_H)
        # (las decoraciones altas de delante: los árboles grandes del plano, no encima)
        self.tall_front = [f['col'] - 1 for f in lv.get('foliage', []) if f.get('type') in TALL_FRONT and f.get('plane') != 'bg']
        # (el plano del usuario: ni encima ni pegado)
        for r in range(H):
            for c in range(W):
                if self.user[r][c]: box(c - 1, r - 1, c + 1, r + 1)
        for f in lv.get('foliage', []):
            if f.get('plane') == 'bg' or f.get('type') in BG_TYPES:
                box(f['col'] - 4, f['row'] - 8, f['col'] + 2, f['row'])

    # ── el plano ──
    def put(self, c, r, tile, hidden=False):
        if not (0 < c < self.W - 1 and 0 < r < self.H - 1): return False
        if self.user[r][c] or self.P[r][c]: return False
        if not hidden and (c, r) in self.av: return False
        self.P[r][c] = R.enc(tile)
        return True

    def get(self, c, r):
        if not (0 <= c < self.W and 0 <= r < self.H): return 0
        return R.tid(self.P[r][c] or self.user[r][c])

    def column(self, c, top, floor, cap_tile, body):
        """Rellena una columna del plano de la fila `top` hasta el suelo (`floor` = fila del bloque de delante), y dos
        filas más hacia dentro del terreno (tapadas: así no se ve el canto de abajo)."""
        for r in range(top, floor):
            self.put(c, r, cap_tile if (r == top and cap_tile) else body)
        for r in (floor, floor + 1):
            if (c, r) in self.terr: self.put(c, r, body, hidden=True)

    # ── dónde hay hueco: los suelos ──
    def sites(self):
        """Por columna, cada tramo de aire con suelo de terreno debajo: (col, fila del suelo, fila del techo, sitio)"""
        out = {}
        for c in range(1, self.W - 1):
            r = self.H - 2
            while r >= 1:
                if self.empty(c, r) and (c, r + 1) in self.terr:
                    b = r
                    while r >= 1 and self.empty(c, r): r -= 1
                    a = r + 1
                    room = 0
                    y = b
                    while y >= a and (c, y) not in self.av: room += 1; y -= 1
                    roof = a > 1 or self.closed
                    out.setdefault(c, []).append(dict(c=c, f=b + 1, a=a, room=room, roof=roof,
                                                      ceil=a - 1 if roof else None))
                r -= 1
        return out

    def segments(self, sites):
        """Tramos de columnas seguidas con suelo parecido (± 2 filas) y aire que se solapa"""
        segs, prev = [], []
        for c in range(1, self.W - 1):
            cur, used = [], set()
            for s in sites.get(c, []):
                best = None
                for j, (p, seg) in enumerate(prev):
                    if j in used or abs(p['f'] - s['f']) > 2 or not (s['a'] < p['f'] and p['a'] < s['f']): continue
                    if best is None or abs(p['f'] - s['f']) < abs(prev[best][0]['f'] - s['f']): best = j
                if best is None:
                    seg = [s]; segs.append(seg)
                else:
                    used.add(best); seg = prev[best][1]; seg.append(s)
                cur.append((s, seg))
            prev = cur
        return segs

    # ── estructuras ──
    def pick(self, opts):
        tot = sum(o[1] for o in opts)
        x = self.rnd.random() * tot
        for o in opts:
            x -= o[1]
            if x <= 0: return o
        return opts[-1]

    def tmin(self, cols):
        """La fila más alta a la que puede llegar una estructura de tope plano sobre esas columnas"""
        t = 1
        for s in cols:
            t = max(t, s['f'] - s['room'] + 1, s['f'] - min(self.capH[s['c']], self.spec['cap']))
        return t

    def lim(self, s):
        """Lo más alto que puede ir algo levantado desde el suelo en esa columna (casillas)"""
        return min(s['room'] - 1, self.capH[s['c']], self.spec['cap'], s['f'] - 2)

    def build_segment(self, seg):
        """Recorre el tramo poniendo estructuras del tema, cada una donde cabe entera, con huecos entre ellas"""
        sp, rnd = self.spec, self.rnd
        i = rnd.randint(0, 3)
        n = len(seg)
        while i < n:
            done = False
            for _ in range(3):                                   # (si no cabe, se prueba otra; si ninguna, se avanza)
                kind, _, w0, w1, h0, h1 = self.pick(sp['kinds'])
                fit = 0
                while i + fit < n and self.lim(seg[i + fit]) >= h0 and (kind in HILLS or abs(seg[i + fit]['f'] - seg[i]['f']) <= 1):
                    fit += 1                                     # (las lomas siguen el suelo; lo demás, de suelo llano)
                if fit < w0: continue
                w = rnd.randint(w0, min(w1, fit))
                cols = seg[i:i + w]
                base = min(s['f'] for s in cols)
                hmax = min(h1, base - self.tmin(cols))
                if kind in HILLS:
                    done = self.hill(cols, kind, h0, h1)
                elif hmax >= h0:
                    done = getattr(self, kind)(cols, base, rnd.randint(h0, hmax))
                if done:
                    i += w + rnd.randint(*sp['gap'])
                    break
            if not done: i += 1

    def hill(self, cols, kind, h0, h1):
        """Loma: sube y baja a rampas (un escalón cada 1-2 columnas), arriba casi llana; se recorta por lo que tenga
        encima sin escalones de más de 1, y sin trozos de menos de 3 columnas ni de 1 de alto"""
        m = self.spec['mat']
        w, amp = len(cols), self.rnd.randint(h0, h1)
        slope = self.rnd.choice((0.5, 0.6, 0.75))
        hs = []
        for k, s in enumerate(cols):
            e = min(k + 0.5, w - k - 0.5)
            h = min(amp, int(e * slope) + 1)
            if h == amp and amp > 2 and self.rnd.random() < 0.2: h -= 1
            hs.append(max(0, min(h, self.lim(s))))
        for _ in range(3):
            for k in range(w):
                for j in (k - 1, k + 1):
                    if 0 <= j < w: hs[k] = min(hs[k], hs[j] + 1)
        k = 0
        while k < w:                                             # (fuera los trozos sueltos)
            if hs[k] == 0: k += 1; continue
            j = k
            while j < w and hs[j] > 0: j += 1
            if j - k < 3 or max(hs[k:j]) < 2:
                for x in range(k, j): hs[x] = 0
            k = j
        if max(hs) < 2: return False
        top, body = (m['top'], m['body'])
        for s, h in zip(cols, hs):
            if h > 0: self.column(s['c'], s['f'] - h, s['f'], top, body)
        self.tops(cols, kind)
        return True

    def tops(self, cols, kind):
        """Apunta en cada columna la fila de arriba de lo que se acaba de levantar desde el suelo (`ptop`)"""
        for s in cols:
            r = s['f'] - 1
            while r >= 1 and self.P[r][s['c']]: r -= 1
            if r + 1 < s['f']: s['ptop'], s['pkind'] = r + 1, kind

    def outcrop(self, cols, base, h):
        """Peñasco: roca que se estrecha hacia arriba (los bordes más bajos), con algún diente de menos arriba"""
        m = self.spec['mat']
        w = len(cols)
        h = min(h, w + 1)                                           # (ni agujas: lo estrecho, bajo)
        mid = (w - 1) / 2
        for k, s in enumerate(cols):
            edge = abs(k - mid) / max(mid, 0.5)                     # 0 en medio, 1 en los bordes
            hh = h - int(round(edge ** 2 * (h - 1) * 0.5))
            if 0 < k < w - 1 and self.rnd.random() < 0.25: hh -= 1
            hh = max(1, hh - (s['f'] - base))
            self.column(s['c'], s['f'] - hh, s['f'], m.get('rockcap'), m['rock'])
        self.tops(cols, 'outcrop')
        return True

    def mesa(self, cols, base, h):
        """Muro de roca con la cresta irregular (basalto)"""
        m = self.spec['mat']
        t = base - h
        for k, s in enumerate(cols):
            jag = self.rnd.choice((0, 0, 1, 1, 2)) if 0 < k < len(cols) - 1 else self.rnd.choice((1, 2))
            self.column(s['c'], min(t + jag, s['f'] - 1), s['f'], None, m['rock'])
        self.tops(cols, 'mesa')
        return True

    def spire(self, cols, base, h):
        """Aguja de basalto: una columna entera y a su lado otras más bajas (el pie ancho, la punta fina)"""
        m = self.spec['mat']
        w = len(cols)
        mid = w // 2 if w != 2 else self.rnd.randint(0, 1)
        for k, s in enumerate(cols):
            hh = h if k == mid else max(1, int(round(h * self.rnd.uniform(0.4, 0.7))))
            self.column(s['c'], s['f'] - hh, s['f'], None, m['rock'])
        self.tops(cols, 'spire')
        return True

    def icewall(self, cols, base, h):
        """Muro de nieve con la cresta de HIELO en dientes (el hielo deja ver algo del cielo: brilla como un glaciar)"""
        m = self.spec['mat']
        t = base - h
        w = len(cols)
        for k, s in enumerate(cols):
            edge = k in (0, w - 1)
            top = min(t + 1 + edge + (self.rnd.random() < 0.25), s['f'] - 1)
            self.column(s['c'], top, s['f'], None, m['body'])
            if not edge and (k % 2 == 1 or self.rnd.random() < 0.3):
                self.put(s['c'], top - 1, m['ice'])
                if self.rnd.random() < 0.3 and top - 2 > t: self.put(s['c'], top - 2, m['ice'])
        self.tops(cols, 'icewall')
        return True

    def wall(self, cols, base, h, tower=False):
        """Muralla: almenas (una sí, una no) y ventanas de 1×2 cada 3 columnas; estandartes y hiedra colgando"""
        m = self.spec['mat']
        t = base - h                                        # (fila de las almenas)
        w = len(cols)
        wins = set()
        if h >= 5:
            wins = {k for k in range(2, w - 2) if (k - 2) % 3 == 0} if not tower else {self.rnd.randint(1, w - 2)}
        for k, s in enumerate(cols):
            c = s['c']
            merlon = (k % 2 == 0) if not tower else k in (0, w - 1)
            if merlon: self.put(c, t, m['body'])
            for r in range(t + 1, s['f']):
                if k in wins and t + 2 <= r <= t + 3: continue
                self.put(c, r, m['body'])
            for r in (s['f'], s['f'] + 1):
                if (c, r) in self.terr: self.put(c, r, m['body'], hidden=True)
        # (estandartes en el muro, entre ventanas; hiedra colgando de lo alto)
        free = [k for k in range(1, w - 1) if k not in wins and k - 1 not in wins and k + 1 not in wins]
        if free and h >= 4:
            k = self.rnd.choice(free)
            self.deco('banner', cols[k]['c'], t + 2, need_plane=True)
            rest = [x for x in free if abs(x - k) > 1]
            if rest and self.rnd.random() < 0.7:
                self.deco('ivy_hang', cols[self.rnd.choice(rest)]['c'], t + 1, need_plane=True)
        self.tops(cols, 'wall')
        return True

    def tower(self, cols, base, h):
        return self.wall(cols, base, h, tower=True)

    def frostwall(self, cols, base, h):
        """Ruina helada (2026-10-29): muro de ladrillo helado con almenas (una sí, una no), el pie de roca helada y
        ventanas heladas cada 3 columnas (bloques con su ventana dibujada: no hay huecos)"""
        m = self.spec['mat']
        t = base - h
        w = len(cols)
        for k, s in enumerate(cols):
            c = s['c']
            if k % 2 == 0: self.put(c, t, m['brick'])
            for r in range(t + 1, s['f']):
                win = h >= 4 and 1 <= k < w - 1 and (k - 1) % 3 == 0 and r == t + 2
                self.put(c, r, m['window'] if win else (m['rock'] if r == s['f'] - 1 else m['brick']))
            for r in (s['f'], s['f'] + 1):
                if (c, r) in self.terr: self.put(c, r, m['rock'], hidden=True)
        self.tops(cols, 'frostwall')
        return True

    def colonnade(self, cols, base, h):
        """Ruina del templo: columnas cada 4, dintel encima (roto a trozos) y arcos junto a las columnas"""
        m = self.spec['mat']
        t = base - h
        w = len(cols)
        pil = [k for k in range(0, w, 4)]
        if pil[-1] != w - 1 and w - 1 - pil[-1] >= 2: pil.append(w - 1)
        broken = self.rnd.choice(pil) if len(pil) > 2 and self.rnd.random() < 0.5 else None
        gaps = set()
        if self.rnd.random() < 0.6 and len(pil) > 2:                # (un trozo de dintel caído)
            a = self.rnd.randrange(len(pil) - 1)
            gaps = set(range(pil[a] + 1, pil[a + 1]))
        for k, s in enumerate(cols):
            c = s['c']
            if k in pil:
                top = t + (self.rnd.randint(2, max(2, h - 2)) if k == broken else 0)
                self.column(c, top, s['f'], None, m['rock'])
            elif k not in gaps and not (broken is not None and abs(k - broken) == 1):
                self.put(c, t, m['rock'])
                if (k - 1 in pil and k - 1 != broken) or (k + 1 in pil and k + 1 != broken):
                    self.put(c, t + 1, m['rock'])                    # (arranque del arco)
        # (lianas y musgo colgando del dintel)
        for k, s in enumerate(cols):
            c = s['c']
            if k not in pil and self.get(c, t) == TEMPLE and not self.get(c, t + 1) and self.rnd.random() < 0.35:
                tp = self.rnd.choice(('liana_long', 'liana_mid', 'hanging_moss'))
                self.deco(tp, c, t + 1, sub=None if tp == 'hanging_moss' else self.rnd.choice((1, 2)))
        self.tops(cols, 'colonnade')
        return True

    def ziggurat(self, cols, base, h):
        """Pirámide escalonada: cada escalón, una fila y una casilla menos a cada lado"""
        m = self.spec['mat']
        w = len(cols)
        for k, s in enumerate(cols):
            step = min(k, w - 1 - k)
            hh = min(h, step + 1)
            self.column(s['c'], base - hh, s['f'], None, m['rock'])
        self.tops(cols, 'ziggurat')
        return True

    def ruinwall(self, cols, base, h):
        """Muro derrumbado: la cresta baja a saltos"""
        m = self.spec['mat']
        hh = h
        for k, s in enumerate(cols):
            self.column(s['c'], base - hh, s['f'], None, m['rock'])
            hh = max(1, min(h, hh + self.rnd.choice((-1, -1, 0, 1))))
        self.tops(cols, 'ruinwall')
        return True

    # ── cuevas: roca que cuelga del techo y columnas ──
    def drapes(self, segs):
        """Cuevas: roca que cuelga del techo a trozos irregulares y, en los huecos anchos y despejados, alguna columna
        de suelo a techo (nunca pegada a una pared de delante)"""
        m = self.spec['mat']
        for seg in segs:
            roofed = [s for s in seg if s['roof'] and s['ceil'] is not None and (s['c'], s['ceil']) in self.terr]
            if not roofed: continue
            for s in roofed:
                s['span'] = s['f'] - s['a']
                s['free'] = 0
                while s['free'] < s['span'] and (s['c'], s['a'] + s['free']) not in self.av: s['free'] += 1
            k = self.rnd.randint(0, 4)
            while k < len(roofed):
                w = self.rnd.randint(5, 12)
                cols = roofed[k:k + w]
                amp = self.rnd.randint(2, 4)
                pil = None
                if len(cols) >= 6 and self.rnd.random() < 0.35:
                    j = len(cols) // 2 - 1
                    near = cols[j - 2:j + 4]
                    if len(near) == 6 and all(x['free'] == x['span'] <= 12 and self.capH[x['c']] > 50 and
                                              abs(x['f'] - cols[j]['f']) <= 1 and x['c'] - near[0]['c'] < 6 for x in near):
                        pil = (j, j + 1)
                prev = None
                for j, s in enumerate(cols):
                    c, a = s['c'], s['a']
                    if pil and j in pil:
                        for r in range(a, s['f']): self.put(c, r, m['body'])
                        for r in (a - 1, a - 2, s['f'], s['f'] + 1):
                            if (c, r) in self.terr: self.put(c, r, m['body'], hidden=True)
                        prev = None
                        continue
                    x = (j + 0.5) / len(cols)
                    d = int(round(amp * math.sin(math.pi * x) ** 0.6)) + self.rnd.choice((-1, 0, 0, 1))
                    if prev is not None: d = max(prev - 2, min(prev + 2, d))
                    d = max(0, min(d, s['free'] - 2, int(s['span'] * 0.45), self.capH[c] - 1))
                    prev = d
                    for r in range(a, a + d): self.put(c, r, m['drape'])
                    if d:
                        for r in (a - 1, a - 2):
                            if (c, r) in self.terr: self.put(c, r, m['drape'], hidden=True)
                        if self.rnd.random() < 0.15 and self.empty(c, a + d) and (c, a + d) not in self.av:
                            self.deco('stalactite', c, a + d)
                k += w + self.rnd.randint(2, 6)

    # ── decoraciones ──
    def deco(self, tp, c, r, sub=None, need_plane=False):
        if need_plane and not self.P[r][c]: return False
        if (c, r) in self.av or (c, r) in self.boxes: return False
        f = {'type': tp, 'col': c + 1, 'row': r + 1}
        if sub: f['sub'] = sub
        if tp not in BG_TYPES: f['plane'] = 'bg'
        if tp not in HANG and self.rnd.random() < 0.5: f['props'] = {'flip': True}
        self.decos.append(f)
        self.boxes.add((c, r))
        return True

    def fits(self, tp, c, r):
        """¿Cabe la decoración grande con el pie en (c, r)? Todo su recuadro, al aire delante y sin zonas prohibidas"""
        w, h = SIZE[tp]
        half = max(0, int(w * 0.8 / 2))
        for x in range(c - half, c + half + 1):
            for y in range(r - int(math.ceil(h)) + 1, r + 1):
                if not (0 < x < self.W - 1 and 0 < y < self.H - 1): return False
                if (x, y) in self.av or (x, y) in self.boxes: return False
                if not self.empty(x, y) and not (y == r and x != c and (x, y) in self.terr): return False
                if self.get(x, y) and (y < r or x == c): return False       # (no tapa estructuras del plano)
        return True

    def place_big(self, tp, c, r):
        w, h = SIZE[tp]
        half = max(0, int(w * 0.8 / 2))
        f = {'type': tp, 'col': c + 1, 'row': r + 1}
        if tp not in BG_TYPES: f['plane'] = 'bg'
        if self.rnd.random() < 0.5: f['props'] = {'flip': True}
        self.decos.append(f)
        for x in range(c - half, c + half + 1):
            for y in range(r - int(math.ceil(h)) + 1, r + 1): self.boxes.add((x, y))
        self.trees.append(c)

    def support(self, c, r):
        """El bloque que sostiene lo que se ponga en (c, r): el del plano o, si no hay, el de delante"""
        p = self.get(c, r + 1)
        if p: return p, 'plane'
        raw = self.at(c, r + 1)
        if (c, r + 1) in self.terr: return R.tid(raw), 'front'
        return None, None

    def decorate(self, segs):
        sp, rnd = self.spec, self.rnd
        cands = []
        for seg in segs:
            for s in seg:
                c = s['c']
                r = s.get('ptop', s['f']) - 1                    # (encima de lo nuestro, o en el suelo de delante)
                if r < 1 or not self.empty(c, r) or self.get(c, r): continue
                cands.append((c, r))
        rnd.shuffle(cands)
        # árboles (los grandes primero)
        for c, r in cands:
            if self.capH[c] < 6 or any(abs(c - t) < sp['tree_gap'] for t in self.trees): continue
            if any(abs(c - t) <= 2 for t in self.tall_front): continue
            if rnd.random() > sp['tree_p']: continue
            sup, _ = self.support(c, r)
            opts = [o for o in sp['trees'] if sup in o[2] and self.fits(o[0], c, r)]
            if opts: self.place_big(self.pick(opts)[0], c, r)
        # pequeñas, encima de lo del plano
        for c, r in cands:
            if not self.get(c, r + 1) or rnd.random() > sp['small_p']: continue
            tp = self.pick(sp['small'])[0]
            if self.fits(tp, c, r): self.place_big(tp, c, r); self.trees.pop()

    def run(self):
        sites = self.sites()
        segs = self.segments(sites)
        if self.theme in CAVE_LIKE: self.drapes(segs)
        for seg in segs: self.build_segment(seg)
        self.decorate(segs)
        return self.P, self.decos


# ── leer / escribir lo generado ──────────────────────────────────────────────────────────────────────────────────────
def sidecar_path(name, out):
    return os.path.join(out, name + '.bggen.json') if out else os.path.join(GEN_DIR, name + '.json')


def plane_decos(lv):
    return [f for f in lv.get('foliage', []) if f.get('plane') == 'bg' or f.get('type') in BG_TYPES]


def still_there(lv, rec):
    """¿Queda en el nivel algo de lo apuntado? (tras `build.py --only`, que lo reescribe, ya no)"""
    bg = lv.get('bgTiles')
    if bg and rec.get('w') == lv['width'] and rec.get('h') == lv['height']:
        if any(bg[r - 1][c - 1] == raw for c, r, raw in rec.get('tiles', [])): return True
    fol = lv.get('foliage', [])
    return any(d in fol for d in rec.get('decos', []))


def remove_generated(lv, rec):
    """Quita lo apuntado que siga igual en el nivel; devuelve (bloques, decoraciones) quitados"""
    nb = nd = 0
    bg = lv.get('bgTiles')
    if bg and rec.get('w') == lv['width'] and rec.get('h') == lv['height']:
        for c, r, raw in rec.get('tiles', []):
            if bg[r - 1][c - 1] == raw: bg[r - 1][c - 1] = 0; nb += 1
        if not any(v for row in bg for v in row): lv.pop('bgTiles')
    fol = lv.get('foliage', [])
    for d in rec.get('decos', []):
        if d in fol: fol.remove(d); nd += 1
    return nb, nd


def run(name, force=False, dry=False, out=None):
    theme = R.THEMES[name]
    src = os.path.join(R.LEVELS, name + '.json')
    dst = os.path.join(out, name + '.json') if out else src
    if out and os.path.exists(dst): src = dst                  # (la copia ya existe: se trabaja sobre ella)
    side = sidecar_path(name, out)
    lv = json.load(open(src))
    rec = json.load(open(side)) if os.path.exists(side) else None
    if rec and not still_there(lv, rec): rec = None           # (lo apuntado ya no está en el nivel: no cuenta)
    has_plane = bool(lv.get('bgTiles') and any(v for row in lv['bgTiles'] for v in row)) or bool(plane_decos(lv))
    if has_plane and not rec:
        print('  %-22s plano hecho a mano: no se toca' % name); return
    if rec and not force:
        print('  %-22s ya tiene plano generado (--force para rehacerlo)' % name); return
    nb = nd = 0
    if rec: nb, nd = remove_generated(lv, rec)
    H, W = len(lv['tiles']), len(lv['tiles'][0])
    user = lv.get('bgTiles') or [[0] * W for _ in range(H)]
    rnd = R.random.Random(int(R.hashlib.md5((name + 'bg').encode()).hexdigest()[:8], 16))
    P, decos = Gen(lv, name, theme, rnd, user).run()
    cells = [[c + 1, r + 1, P[r][c]] for r in range(H) for c in range(W) if P[r][c]]
    if cells:
        bg = [row[:] for row in user]
        for c, r, v in cells: bg[r - 1][c - 1] = v
        lv['bgTiles'] = bg
    lv.setdefault('foliage', []).extend(decos)
    print('  %-22s %-10s plano: bloques +%d · decoraciones +%d%s' % (name, theme, len(cells), len(decos),
          ' (quitado lo generado antes: %d bloques, %d decoraciones)' % (nb, nd) if rec else ''))
    if dry: return
    if out: os.makedirs(out, exist_ok=True)
    # (bgTiles justo detrás de tiles, como el editor)
    order = {}
    for k, v in lv.items():
        order[k] = v
        if k == 'tiles' and 'bgTiles' in lv: order['bgTiles'] = lv['bgTiles']
    R.save(dst, order)
    os.makedirs(os.path.dirname(side) or '.', exist_ok=True)
    json.dump({'level': name, 'w': W, 'h': H, 'tiles': cells, 'decos': decos}, open(side, 'w'), ensure_ascii=False,
              separators=(',', ':'))
