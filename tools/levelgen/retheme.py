#!/usr/bin/env python3
"""Re-viste los niveles: materiales del terreno y decoraciones por TEMA.

Cuando se hicieron los niveles solo existía la piedra. Esto cambia SOLO el
aspecto (piedra, tierra, césped y nieve son idénticos para la física) y añade
decoraciones (no chocan). Nada de la jugabilidad cambia: ni colisiones, ni
pinchos, ni agua, ni entidades.

Terreno (bloques 'solid' y la fila de ABAJO del marco de 'border'):
  - arriba al aire  → superficie del tema (césped / nieve / tierra / piedra)
  - arriba agua     → arena (fondo del agua, 2 de hondo; nieve: tierra; fortaleza: piedra)
  - playa (césped/trópico): superficie con agua a ≤ 3 columnas → arena (2 de hondo)
  - hondo: terreno a ≥ DEEP_ROWS filas bajo una superficie de agua → roca abisal
    (en cualquier tema salvo nieve; sin arena honda); tema 'underwater': también
    todo lo que esté por debajo del 45 % del alto del nivel
  - 1-3 por debajo  → tierra (la profundidad varía por columna)
  - más hondo       → piedra
  Nieve: islas sueltas pequeñas (≤ 4 bloques de una fila) → hielo.
Decoraciones (capa 'back', nunca tapan el juego): en el suelo, en el techo y
bajo el agua, según el tema; nunca en pinchos, entidades, la salida, la meta,
vents, bloques rompibles/especiales ni dentro de bloques de jefe.

Uso (desde la raíz del repo):
  python3 tools/levelgen/retheme.py                 todos los niveles de THEMES
  python3 tools/levelgen/retheme.py valle_soleado   solo esos
  --force   aunque el nivel ya esté re-vestido (vuelve a poner decoraciones)
  --terrain vuelve a decidir también los bloques de tierra/césped/nieve/arena
            (¡pisa los que se pusieran a mano!); sin él solo cambia la piedra
  --dry     no escribe, solo cuenta
  --tiles   solo el terreno: no toca las decoraciones (las del usuario se quedan)
  --sky     solo escribe el fondo y la hora (tabla SKY) en los niveles que no los tengan
  --deep    solo pasa a roca abisal el terreno hondo bajo el agua (nada más cambia)
Tras `build.py --only x` (que reescribe el nivel) hay que volver a pasarlo.
"""
import json, os, random, sys, hashlib

LEVELS = 'assets/levels'
ID_HIGH = 2 ** 17
EMPTY, SOLID, SLAB, BORDER, WATER, DROP, FINISH, BREAK = 0, 1, 2, 4, 9, 10, 11, 12
DIRT, GRASS, SNOW, ICE, SAND, DEEP = 16, 17, 29, 30, 35, 36
GROUND = {SOLID, BORDER, DIRT, GRASS, SNOW, ICE, SAND, DEEP}
DEEP_ROWS = 4                     # bajo ≥ 4 filas de agua: roca abisal

THEMES = {
    'valle_soleado': 'meadow', 'jardin_gummies': 'meadow', 'carrera01': 'meadow', 'nivel01': 'meadow',
    'lluvia_pinchos': 'meadow', 'tren_fugaz': 'meadow', 'ruta_del_espejo': 'meadow', 'ciudadela_cangrejos': 'meadow',
    'marea_alta': 'tropical', 'cascada_dorada': 'tropical', 'isla_flotante': 'tropical', 'canon_trampolines': 'tropical',
    'rebote_real': 'tropical', 'guarida_cangrejo_rey': 'tropical',
    'cumbre_cangrejo': 'snow', 'torre_viento': 'snow', 'lago_helado': 'snow', 'glaciar_cangrejo': 'snow',
    'cavernas_cristal': 'cave', 'mina_inundada': 'mine', 'laberinto_submarino': 'underwater',
    'fabrica_morteros': 'fortress', 'fortaleza_malvada': 'fortress', 'taller_trampas': 'fortress',
    'coliseo_pinchos': 'fortress',
}

# Fondo de superficie (src/fx/Sky.lua), hora y fondo de profundidad (opcional) de cada nivel: `--sky` los escribe SOLO si el nivel
# aún no los tiene (lo elegido en el editor no se toca)
SKY = {
    'valle_soleado': ('meadow', 'day'), 'jardin_gummies': ('forest', 'day'), 'carrera01': ('meadow', 'day', 'underwater'),
    'nivel01': ('coast', 'day', 'abyss'), 'lluvia_pinchos': ('mountain', 'day'), 'tren_fugaz': ('mountain', 'dusk'),
    'ruta_del_espejo': ('meadow', 'night'), 'ciudadela_cangrejos': ('coast', 'day'), 'marea_alta': ('coast', 'dusk'),
    'cascada_dorada': ('forest', 'day'), 'isla_flotante': ('meadow', 'day'), 'canon_trampolines': ('coast', 'day'),
    'rebote_real': ('forest', 'day'), 'guarida_cangrejo_rey': ('coast', 'day'), 'cumbre_cangrejo': ('coast', 'dusk'),
    'torre_viento': ('snow', 'night'), 'lago_helado': ('snow', 'dusk'), 'glaciar_cangrejo': ('snow', 'day'), 'cavernas_cristal': ('cave', 'day'), 'mina_inundada': ('mountain', 'day', 'cave'),
    'laberinto_submarino': ('coast', 'day', 'underwater'), 'fabrica_morteros': ('fortress', 'dusk'),
    'fortaleza_malvada': ('fortress', 'night'), 'taller_trampas': ('fortress', 'day', 'cave'), 'coliseo_pinchos': ('fortress', 'dusk'),
}


def set_sky(name):
    path = os.path.join(LEVELS, name + '.json')
    lv = json.load(open(path))
    bg, tm, *dp = SKY.get(name, ('meadow', 'day'))
    changed = []
    if dp and 'depth' not in lv: lv['depth'] = dp[0]; changed.append('profundidad ' + dp[0])
    if 'background' not in lv and bg != 'meadow': lv['background'] = bg; changed.append(bg)
    if 'time' not in lv and tm != 'day': lv['time'] = tm; changed.append(tm)
    if changed: save(path, lv)
    print('  %-22s %s' % (name, ', '.join(changed) or '(sin cambios)'))


# Superficie al aire / cerca de la superficie / hondo, por tema
TERRAIN = {
    'meadow':     (GRASS, DIRT, SOLID),
    'tropical':   (GRASS, DIRT, SOLID),
    'snow':       (SNOW, DIRT, SOLID),
    'cave':       (SOLID, SOLID, SOLID),
    'mine':       (DIRT, DIRT, SOLID),
    'underwater': (SOLID, SOLID, SOLID),
    'fortress':   (SOLID, SOLID, SOLID),
}

# Decoraciones: (tipo, peso, 'cell'|'sub', casillas libres que necesita hacia arriba)
FLOOR = {
    'meadow':   [('tulip', 5, 'sub', 1), ('fern', 4, 'cell', 1), ('tropical_bush', 3, 'cell', 1), ('butterflies', 1, 'cell', 1),
                 ('hibiscus', 2, 'sub', 1), ('stretch', 1, 'sub', 2), ('palmtree', 1, 'cell', 3)],
    'tropical': [('palmtree', 3, 'cell', 3), ('fern', 3, 'cell', 1), ('tropical_bush', 3, 'cell', 1), ('hibiscus', 4, 'sub', 1),
                 ('pineapple', 2, 'sub', 1), ('tiki_torch', 1, 'cell', 2), ('butterflies', 1, 'cell', 1)],
    'snow':     [('snowy_pine', 4, 'cell', 2), ('frozen_bush', 3, 'cell', 1), ('snow_pile', 5, 'sub', 1), ('ice_crystal', 3, 'sub', 1),
                 ('snowman', 1, 'cell', 1)],
    'cave':     [('stalagmite', 3, 'cell', 1), ('stalagmite_small', 4, 'sub', 1), ('cave_crystals', 4, 'cell', 1),
                 ('glow_mushroom', 4, 'sub', 1), ('bones', 1, 'sub', 1)],
    'mine':     [('torch', 4, 'sub', 1), ('stalagmite_small', 3, 'sub', 1), ('glow_mushroom', 3, 'sub', 1), ('bones', 1, 'sub', 1),
                 ('cave_crystals', 1, 'cell', 1), ('stalagmite', 1, 'cell', 1)],
    'underwater': [('stalagmite_small', 3, 'sub', 1), ('glow_mushroom', 3, 'sub', 1), ('cave_crystals', 1, 'cell', 1)],
    'fortress': [('torch', 4, 'sub', 1), ('bones', 2, 'sub', 1), ('stalagmite_small', 1, 'sub', 1)],
}
BEACH = [('shell', 3, 'sub', 1), ('starfish', 2, 'sub', 1), ('palmtree', 2, 'cell', 3), ('pineapple', 1, 'sub', 1)]
WATER_FLOOR = [('seaweed', 4, 'cell', 2), ('seaweed_small', 5, 'sub', 1), ('coral', 3, 'cell', 1), ('coral_fan', 2, 'cell', 1),
               ('anemone', 3, 'sub', 1), ('starfish', 2, 'sub', 1), ('shell', 2, 'sub', 1), ('clam', 2, 'sub', 1)]
CEIL = {
    'snow':     [('icicle', 3, 'cell'), ('icicle_small', 4, 'sub')],
    'cave':     [('stalactite', 5, 'cell'), ('cobweb', 1, 'corner')],
    'mine':     [('stalactite', 3, 'cell'), ('cobweb', 2, 'corner')],
    'underwater': [('stalactite', 2, 'cell')],
    'fortress': [('cobweb', 3, 'corner')],
}
DENSITY = {'floor': 0.2, 'water': 0.24, 'ceil': 0.15}
PLANKS = {SLAB, DROP}            # plataformas: solo decoraciones pequeñas encima
NEW_TYPES = {t for L in list(FLOOR.values()) + [WATER_FLOOR] for t, *_ in L if t not in ('tulip', 'stretch', 'palmtree')} | \
            {t for L in CEIL.values() for t, *_ in L}
AUTO_TYPES = NEW_TYPES | {'tulip', 'stretch', 'palmtree'}


def tid(raw): return raw % 16 + 16 * ((raw // ID_HIGH) % 16)
def enc(i): return i % 16 + (i // 16) * ID_HIGH
def with_id(raw, i): return raw - enc(tid(raw)) + enc(i)
def waterlogged(raw): return (raw // 16) % 2 == 1
def spiky(raw): return (raw // 32) % 4096 != 0


def retheme(name, force=False, dry=False, terrain=False, tiles_only=False):
    path = os.path.join(LEVELS, name + '.json')
    lv = json.load(open(path))
    theme = THEMES[name]
    T = lv['tiles']
    H, W = len(T), len(T[0])
    auto = lambda f: (f.get('props') or {}).get('layer') == 'back' and f.get('type') in AUTO_TYPES
    already = any(auto(f) for f in lv.get('foliage', []))
    if already and not force and not tiles_only:
        print('  %-22s ya re-vestido (--force)' % name)
        return
    rnd = random.Random(int(hashlib.md5(name.encode()).hexdigest()[:8], 16))
    surf, near, deep = TERRAIN[theme]

    def at(c, r):                    # 0-based; fuera = borde
        return T[r][c] if 0 <= r < H and 0 <= c < W else enc(BORDER)

    def frame(c, r): return c == 0 or c == W - 1 or r == 0

    def wet(c, r):
        raw = at(c, r)
        return tid(raw) == WATER or (tid(raw) not in GROUND and waterlogged(raw))

    def beach(c, r):
        if theme not in ('meadow', 'tropical'): return False
        return any(wet(c + dx, r + dy) for dx in range(-3, 4) for dy in (-1, 0, 1))

    CONVERT = {SOLID, BORDER} | ({DIRT, GRASS, SNOW, SAND, DEEP} if terrain else set())

    # Profundidad bajo el agua por casilla: filas desde la superficie del agua de su
    # columna (atravesando agua y terreno; el aire la reinicia)
    deepAt = {}
    for c in range(W):
        surfRow = None
        for r in range(H):
            raw = at(c, r)
            if tid(raw) in GROUND or tid(raw) == BREAK:
                if surfRow is not None: deepAt[(c, r)] = r - surfRow
            elif wet(c, r):
                if surfRow is None: surfRow = r
            else:
                surfRow = None

    # ── Terreno ───────────────────────────────────────────────────────────────
    changed = 0
    colDepth = [2 + (rnd.random() < 0.45) for _ in range(W)]
    new = [row[:] for row in T]
    for c in range(W):
        depth = None
        for r in range(H):
            i = tid(T[r][c])
            if i not in GROUND and i != BREAK:
                depth = None
                continue
            if depth is None:
                above = tid(at(c, r - 1))
                if r == 0 or frame(c, r - 1) and r - 1 == 0:
                    depth, top = 99, 'rock'          # cuelga del techo del marco
                else:
                    w_ = above == WATER or waterlogged(at(c, r - 1))
                    depth, top = 0, ('water' if w_ else 'air')
                    sandy = (w_ and theme not in ('snow', 'fortress')) or (not w_ and beach(c, r))
            else:
                depth += 1
            if frame(c, r) or i not in CONVERT or (i == BORDER and r != H - 1):
                continue
            if theme != 'snow' and (deepAt.get((c, r), 0) >= DEEP_ROWS or (theme == 'underwater' and r >= H * 0.45)):
                want = DEEP
            elif depth <= 1 and top != 'rock' and sandy:
                want = SAND
            elif depth == 0:
                want = surf if top == 'air' else (DIRT if near == DIRT else SOLID)
            elif depth <= colDepth[c]:
                want = near
            else:
                want = deep
            if DEEP_ONLY and want != DEEP: continue
            if want != i:
                new[r][c] = with_id(T[r][c], want)
                changed += 1
    # Nieve: islas pequeñas de una fila → hielo
    if theme == 'snow':
        seen = set()
        for r in range(1, H - 1):
            for c in range(1, W - 1):
                if (c, r) in seen or tid(new[r][c]) not in (SNOW,): continue
                comp, stack = [], [(c, r)]
                while stack:
                    x, y = stack.pop()
                    if (x, y) in seen or not (0 < x < W - 1 and 0 < y < H - 1): continue
                    if tid(new[y][x]) not in GROUND - {BORDER}: continue
                    seen.add((x, y)); comp.append((x, y))
                    stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                if len(comp) <= 4 and len({y for _, y in comp}) == 1 and all(tid(at(x, y + 1)) not in GROUND for x, y in comp):
                    for x, y in comp:
                        new[y][x] = with_id(new[y][x], ICE); changed += 1
    lv['tiles'] = new
    T = new
    if tiles_only:
        print('  %-22s %-10s bloques cambiados %4d (solo terreno)' % (name, theme, changed))
        if not dry: save(path, lv)
        return

    # ── Decoraciones ──────────────────────────────────────────────────────────
    busy = set()
    for e in lv.get('entities', []):
        c, r = e['col'] - 1, e['row'] - 1
        busy |= {(c, r), (c, r - 1)}
        if e['type'] in ('bosswall', 'bossglass', 'flood', 'pointarea') and (e.get('props') or {}).get('corner'):
            k = e['props']['corner']
            c1, r1 = (k.get('col', c + 1) - 1, k.get('row', r + 1) - 1) if isinstance(k, dict) else (k[0] - 1, k[1] - 1)
            if e['type'] in ('bosswall', 'bossglass'):
                for x in range(c, c1 + 1):
                    for y in range(r - 1, r1 + 1): busy.add((x, y))
    for z in lv.get('bossZones', []) or []:      # (las peleas de jefe, limpias)
        for x in range(z['col'] - 1, z['col'] - 1 + z['w']):
            for y in range(z['row'] - 1, z['row'] - 1 + z['h']): busy.add((x, y))
    ps = lv.get('playerStart', [1, 1])
    busy |= {(ps[0] - 1, ps[1] - 1), (ps[0] - 1, ps[1] - 2)}
    for v in lv.get('vents', []):
        busy.add((v.get('col', 0) - 1, v.get('row', 0) - 1))
    for r in range(H):
        for c in range(W):
            if tid(T[r][c]) == FINISH:
                for dx in range(-1, 2):
                    for dy in range(-2, 2): busy.add((c + dx, r + dy))
    if force:       # (quita solo las que puso este script: las del usuario no llevan layer='back')
        lv['foliage'] = [f for f in lv.get('foliage', []) if not auto(f)]
    for f in lv.get('foliage', []):
        busy.add((f['col'] - 1, f['row'] - 1))

    def free(c, r, wet):
        if not (0 < c < W - 1 and 0 < r < H - 1) or (c, r) in busy: return False
        raw = T[r][c]
        if spiky(raw): return False
        i = tid(raw)
        is_wet = i == WATER or (i == EMPTY and waterlogged(raw))
        return (i == EMPTY and not waterlogged(raw) and not wet) or (wet and is_wet)

    def pick(options):
        tot = sum(o[1] for o in options)
        x = rnd.random() * tot
        for o in options:
            x -= o[1]
            if x <= 0: return o
        return options[-1]

    added = []
    lastCol = {}

    def place(tp, c, r, sub=None):
        f = {'type': tp, 'col': c + 1, 'row': r + 1}
        if sub: f['sub'] = sub
        props = {'layer': 'back'}
        if rnd.random() < 0.5 and tp not in ('butterflies',): props['flip'] = True
        f['props'] = props
        added.append(f)
        busy.add((c, r))

    for r in range(1, H - 1):
        for c in range(1, W - 1):
            below = at(c, r + 1)
            # Suelo: un bloque de terreno debajo con la cara de arriba libre
            plank = tid(below) in PLANKS
            if (tid(below) in GROUND or plank) and not spiky(below):
                wet = tid(T[r][c]) == WATER or waterlogged(T[r][c])
                opts = WATER_FLOOR if wet else (BEACH if tid(below) == SAND else FLOOR[theme])
                if plank: opts = [o for o in opts if o[2] == 'sub' and o[3] == 1]
                dens = DENSITY['water' if wet else 'floor']
                if free(c, r, wet) and rnd.random() < dens and abs(lastCol.get(r, -9) - c) > 1:
                    tp, _, kind, need = pick(opts)
                    if all(free(c, r - k, wet) for k in range(need)):
                        if kind == 'sub':
                            subs = [3, 4]; rnd.shuffle(subs)
                            place(tp, c, r, subs[0])
                            if rnd.random() < 0.3:
                                tp2, _, k2, n2 = pick([o for o in opts if o[2] == 'sub'])
                                added.append({'type': tp2, 'col': c + 1, 'row': r + 1, 'sub': subs[1], 'props': {'layer': 'back'}})
                        else:
                            place(tp, c, r)
                        lastCol[r] = c
                        continue
            # Techo: terreno encima con la cara de abajo libre
            above = at(c, r - 1)
            if theme in CEIL and tid(above) in GROUND and r - 1 >= 0 and free(c, r, False) and rnd.random() < DENSITY['ceil']:
                if tid(at(c, r + 1)) in GROUND: continue          # (hueco de una casilla: nada)
                tp, _, kind = pick(CEIL[theme])
                if kind == 'corner':
                    wl, wr = tid(at(c - 1, r)) in GROUND, tid(at(c + 1, r)) in GROUND
                    if not (wl or wr): continue
                    f = {'type': tp, 'col': c + 1, 'row': r + 1, 'props': {'layer': 'back', **({'flip': True} if wr and not wl else {})}}
                    added.append(f); busy.add((c, r))
                elif kind == 'sub':
                    place(tp, c, r, rnd.choice([1, 2]))
                else:
                    place(tp, c, r)
    lv.setdefault('foliage', []).extend(added)
    if theme == 'snow':
        lv['snow'], lv['spikeSkin'] = True, 'ice'      # (nieve cayendo, pinchos de hielo)
        for e in lv.get('entities', []):               # Crabbies → Crabbies helados (mismas propiedades)
            e['type'] = ICY_CRABS.get(e['type'], e['type'])
    print('  %-22s %-10s bloques cambiados %4d · decoraciones +%d' % (name, theme, changed, len(added)))
    if not dry:
        save(path, lv)


ICY_CRABS = {'crabby': 'crabby_ice', 'crabbytramp': 'crabbytramp_ice'}


def save(path, lv):
    """Mismo formato que el editor: una fila de tiles / un objeto por línea."""
    cj = lambda v: json.dumps(v, ensure_ascii=False, separators=(',', ':'), sort_keys=True)
    out = []
    for k, v in lv.items():
        if k == 'tiles' or (isinstance(v, list) and v and isinstance(v[0], (list, dict))):
            body = ',\n'.join('    ' + cj(x) for x in v)
            out.append('  "%s": [\n%s\n  ]' % (k, body))
        else:
            out.append('  "%s": %s' % (k, cj(v)))
    open(path, 'w').write('{\n' + ',\n'.join(out) + '\n}\n')


DEEP_ONLY = '--deep' in sys.argv
if DEEP_ONLY: sys.argv += ['--tiles', '--terrain']

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if '--sky' in sys.argv:
        print('Fondo y hora:')
        for n in (args or sorted(SKY)): set_sky(n)
        sys.exit(0)
    print('Re-vestir niveles:')
    for n in (args or sorted(THEMES)):
        retheme(n, '--force' in sys.argv, '--dry' in sys.argv, '--terrain' in sys.argv, '--tiles' in sys.argv)
