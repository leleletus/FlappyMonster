"""Biblioteca mínima para escribir niveles de FlappyMonster desde código.

Coordenadas 1-based (col, fila) como en el juego / editor. tiles[fila-1][col-1].
Ids de tile: 0 vacío, 1 bloque, 2 plataforma (losa), 4 borde, 9 agua,
10 plataforma traspasable, 11 meta, 12 bloque rompible.
Pinchos: bits por subcelda (ver src/world/tiles/TileCodec.lua).
"""
import json

EMPTY, SOLID, SLAB, BORDER, WATER, DROP, FINISH, BREAK = 0, 1, 2, 4, 9, 10, 11, 12
UP, DOWN, LEFT, RIGHT = 0, 1, 2, 3
SUB_SHIFTS = (5, 8, 11, 14)  # TL, TR, BL, BR


def spike_bits(direction, subs):
    raw = 0
    for i in subs:
        sh = SUB_SHIFTS[i]
        raw += direction * 2 ** sh + 2 ** (sh + 2)
    return raw


# Subceldas cuya base pega con la pared en cada dirección
_BASE_SUBS = {UP: (2, 3), DOWN: (0, 1), LEFT: (1, 3), RIGHT: (0, 2)}


class Level:
    def __init__(self, name, w, h, start, music=None, modes=None, match_time=None):
        self.name, self.w, self.h, self.start = name, w, h, list(start)
        self.music, self.modes, self.match_time = music, modes, match_time
        self.g = [[EMPTY] * w for _ in range(h)]
        for c in range(1, w + 1):
            self.set(c, 1, BORDER)
            self.set(c, h, BORDER)
        for r in range(1, h + 1):
            self.set(1, r, BORDER)
            self.set(w, r, BORDER)
        self.entities, self.foliage, self.vents = [], [], []
        self.boss_zones, self.auto_scroll = [], None

    # ── tiles ────────────────────────────────────────────────────────────
    def inb(self, c, r):
        return 1 <= c <= self.w and 1 <= r <= self.h

    def set(self, c, r, v):
        if self.inb(c, r):
            self.g[r - 1][c - 1] = v

    def get(self, c, r):
        return self.g[r - 1][c - 1] if self.inb(c, r) else BORDER

    def rect(self, c0, r0, c1, r1, v=SOLID):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.set(c, r, v)

    def clear(self, c0, r0, c1, r1):
        self.rect(c0, r0, c1, r1, EMPTY)

    def ground(self, c0, c1, top, v=SOLID):
        """Suelo sólido desde la fila `top` hasta el borde inferior."""
        self.rect(c0, top, c1, self.h - 1, v)

    def terrain(self, c0, c1, top, v=SOLID):
        """Sustituye la columna: aire arriba y suelo sólido desde `top` hacia abajo."""
        self.clear(c0, 2, c1, self.h - 1)
        self.ground(c0, c1, top, v)

    def plat(self, c0, c1, r, kind=DROP):
        self.rect(c0, r, c1, r, kind)

    def water(self, c0, r0, c1, r1):
        self.rect(c0, r0, c1, r1, WATER)

    def spikes(self, c0, c1, r, direction=UP):
        """Pinchos de celda completa en las celdas (c0..c1, r)."""
        for c in range(c0, c1 + 1):
            self.set(c, r, spike_bits(direction, _BASE_SUBS[direction]))

    def half_spikes(self, c, r, direction, sub):
        """Un solo pincho (subcelda 0..3 = TL,TR,BL,BR)."""
        self.set(c, r, spike_bits(direction, (sub,)))

    def finish(self, c, r):
        """Bandera de meta 2x3 con la base en la fila r."""
        self.rect(c, r - 2, c + 1, r, FINISH)

    # ── entidades ────────────────────────────────────────────────────────
    def ent(self, typ, c, r, sub=None, **props):
        e = {'col': c, 'row': r, 'type': typ}
        if sub:
            e['sub'] = sub
        if props:
            e['props'] = props
        self.entities.append(e)
        return e

    def walker(self, typ, c, r, l, rr, **props):
        return self.ent(typ, c, r, patrol={'left': l, 'right': rr}, **props)

    def deco(self, typ, c, r, sub=None):
        d = {'col': c, 'row': r, 'type': typ}
        if sub:
            d['sub'] = sub
        self.foliage.append(d)

    def vent(self, c, r, sub=1, limit=None):
        v = {'col': c, 'row': r, 'sub': sub}
        if limit:
            v['limit'] = limit
        self.vents.append(v)

    # ── salida ───────────────────────────────────────────────────────────
    def ascii(self):
        ch = {0: '.', 1: '#', 2: '=', 4: 'B', 9: '~', 10: '-', 11: 'F', 12: 'x'}
        out = []
        ents = {(e['col'], e['row']): e['type'][0].upper() for e in self.entities}
        for r in range(1, self.h + 1):
            row = ''
            for c in range(1, self.w + 1):
                v = self.get(c, r)
                if (c, r) == tuple(self.start):
                    row += '@'
                elif (c, r) in ents:
                    row += ents[(c, r)]
                elif v > 15 and v % 16 == 0:
                    row += '^'
                else:
                    row += ch.get(v % 16 if v < 2 ** 17 and v < 32 else v, '^' if v > 32 else '?')
            out.append(row)
        return '\n'.join(out)

    def to_json(self):
        def j(x):
            return json.dumps(x, separators=(',', ':'), ensure_ascii=False, sort_keys=True)
        lines = ['{', '  "name": %s,' % j(self.name), '  "width": %d,' % self.w,
                 '  "height": %d,' % self.h, '  "playerStart": %s,' % j(self.start),
                 '  "tiles": [']
        lines += ['    %s%s' % (j(row), ',' if i < self.h - 1 else '') for i, row in enumerate(self.g)]
        lines.append('  ],')
        lines.append('  "entities": [')
        lines += ['    %s%s' % (j(e), ',' if i < len(self.entities) - 1 else '')
                  for i, e in enumerate(self.entities)]
        lines.append('  ],')
        lines.append('  "foliage": [%s],' % ','.join(j(d) for d in self.foliage))
        lines.append('  "vents": [%s]' % ','.join(j(v) for v in self.vents)
                     + (',' if (self.boss_zones or self.auto_scroll or self.modes or self.match_time or self.music) else ''))
        extra = []
        if self.boss_zones:
            extra.append('  "bossZones": %s' % j(self.boss_zones))
        if self.auto_scroll:
            extra.append('  "autoScroll": %s' % j(self.auto_scroll))
        if self.modes:
            extra.append('  "modes": %s' % j(self.modes))
        if self.match_time:
            extra.append('  "matchTime": %s' % j(self.match_time))
        if self.music:
            extra.append('  "music": %s' % j(self.music))
        lines.append(',\n'.join(extra))
        lines.append('}')
        return '\n'.join(lines) + '\n'

    def check(self):
        """Comprobaciones básicas (el juego también valida en el editor)."""
        warn = []
        s = self.start
        if self.get(*s) in (SOLID, BORDER, BREAK):
            warn.append('inicio dentro de un bloque')
        if self.get(s[0], s[1] + 1) not in (SOLID, BORDER, SLAB, DROP, BREAK):
            warn.append('inicio sin suelo debajo')
        for e in self.entities:
            v = self.get(e['col'], e['row']) % 16
            if v in (SOLID, BORDER, BREAK) and e['type'] not in ('flood', 'pointarea', 'bosswall'):
                warn.append('%s (%d,%d) dentro de un bloque' % (e['type'], e['col'], e['row']))
            p = e.get('props', {}).get('patrol')
            if p and not (p['left'] <= e['col'] <= p['right']):
                warn.append('%s (%d,%d): ruta no la contiene' % (e['type'], e['col'], e['row']))
        return warn
