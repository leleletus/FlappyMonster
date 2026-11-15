"""RELIEVE para los niveles generados: formas de roca con aspecto natural en vez de rectángulos (el usuario, 2026-11-15:
«nada de paredes y muros cuadrados sin relieve ni decoración»). Lo usan los niveles estelares nuevos
(levels_estelar_2.py); sirve para cualquier paquete de bloques: se le pasan los tiles.

  Geo(L, seed, top=…, body=…, sub_top=…, sub_body=…)
    island(c0, c1, top, depth)       isla flotante: arriba plana (se juega encima), por debajo una cúpula invertida
                                     irregular con alguna estalactita; los escalones de abajo se suavizan con MINI
                                     BLOQUES (cuartos de casilla) para que el borde sea diagonal y no de escalera
    mass(c0, c1, r0, r1)             roca maciza con los bordes de los lados irregulares (paredes de cañón, montes)
    hang(c0, c1, r_top, depth)       roca que cuelga del techo (o de una masa): por debajo, irregular y con puntas
    spire(c, base, top, w)           aguja de roca que sube desde abajo (más ancha abajo)
    round_under(c0, c1)              suaviza con mini bloques los escalones de la cara de abajo en esas columnas
  Plano de fondo (sin colisión, más oscuro: docs/art/background-plane.md):
    bg_cloud_sea(row)                mar de nubes desde esa fila hasta abajo, con la cresta ondulada
    bg_spire(c, base, top, w)        agujas de cristal / roca lejanas
    bg_island(c0, c1, top, depth)    islas lejanas que flotan
    bg_tower(c, base, h) · bg_portico(c, base, h) · bg_arch(c0, c1, base, h)   ruinas
"""
import math
import random
from lib import EMPTY


class Geo:
    def __init__(self, L, seed=1, top=None, body=None, sub_top='star_crystal', sub_body='nebula_rock',
                 brick=None, pillar=None, window=None, cloud=None):
        self.L, self.rng = L, random.Random(seed)
        self.top, self.body = top, body
        self.sub_top, self.sub_body = sub_top, sub_body
        self.brick, self.pillar, self.window, self.cloud = brick, pillar, window, cloud
        self.subs = L.extra.setdefault('subtiles', [])
        self._subset = set()

    # ── mini bloques ────────────────────────────────────────────────────────────────────────────────────────────
    def sub(self, c, r, q, kind=None, solid=False):
        """un cuarto de casilla (q: 1 arriba-izq, 2 arriba-der, 3 abajo-izq, 4 abajo-der) en una casilla VACÍA.
        DECORATIVO por defecto (`solid: false`): el relieve no cambia el camino — ni lo corta, ni abre atajos, ni da un
        apoyo de más — (el usuario, 2026-11-15: «lo decorativo no debe de ayudar»; la primera tanda los ponía sólidos y
        tuvo que arreglar Púlsar y el Santuario a mano)"""
        if self.L.get(c, r) != EMPTY or (c, r, q) in self._subset: return
        self._subset.add((c, r, q))
        d = {'col': c, 'row': r, 'sub': q, 'kind': kind or self.sub_body}
        if not solid: d['solid'] = False
        self.subs.append(d)

    def solid(self, c, r):
        return self.L.get(c, r) != EMPTY

    # ── formas ──────────────────────────────────────────────────────────────────────────────────────────────────
    def column(self, c, r0, r1, top_tile=True):
        """columna de roca de r0 a r1; la casilla de arriba, del tile de superficie si `top_tile`"""
        for r in range(r0, r1 + 1):
            self.L.set(c, r, self.top if (top_tile and r == r0) else self.body)

    def island(self, c0, c1, top, depth=5, tips=1, jag=1, top_tile=None):
        """isla flotante: cara de arriba plana en `top`; por debajo, más honda en medio (cúpula invertida)"""
        rng, n = self.rng, c1 - c0 + 1
        bottoms = []
        for i in range(n):
            x = (i + 0.5) / n
            prof = math.sin(math.pi * x) ** 0.8
            d = 1 + (depth - 1) * prof
            if prof > 0.35 and jag: d += rng.choice((-1, 0, 0, 1)) * jag
            bottoms.append(top + max(0, int(round(d)) - 1))
        for i in range(1, n):                   # (sin saltos de más de 2 entre columnas vecinas)
            bottoms[i] = max(bottoms[i - 1] - 2, min(bottoms[i - 1] + 2, bottoms[i]))
        for i, c in enumerate(range(c0, c1 + 1)):
            for r in range(top, bottoms[i] + 1):
                self.L.set(c, r, (top_tile or self.top) if r == top else self.body)
        # estalactitas: una columna que baja 1-3 más (en el tercio de en medio)
        for _ in range(tips):
            if n < 5: break
            i = rng.randrange(n // 3, max(n // 3 + 1, 2 * n // 3))
            c, b = c0 + i, bottoms[i]
            ln = rng.randrange(1, 4)
            for r in range(b + 1, b + 1 + ln): self.L.set(c, r, self.body)
            self.sub(c - 1, b + 1, 2); self.sub(c + 1, b + 1, 1)
            self.sub(c, b + ln + 1, 1); self.sub(c, b + ln + 1, 2)      # (la punta: media casilla más)
        self.round_under(c0, c1)
        # las esquinas de arriba: un cuarto de casilla de bisel bajo el canto (no toca la cara que se pisa)
        self.sub(c0 - 1, top, 4); self.sub(c1 + 1, top, 3)
        return bottoms

    def round_under(self, c0, c1):
        """suaviza los escalones de la cara de ABAJO entre c0 y c1: un cuarto en cada rincón"""
        L = self.L
        for c in range(c0 - 1, c1 + 1):
            ba, bb = self.bottom(c), self.bottom(c + 1)
            if ba is None or bb is None or ba == bb: continue
            if ba > bb:                       # la de la izquierda baja más: rincón bajo la de la derecha
                self.sub(c + 1, bb + 1, 1)
                if ba - bb >= 2: self.sub(c + 1, bb + 2, 1)
            else:
                self.sub(c, ba + 1, 2)
                if bb - ba >= 2: self.sub(c, ba + 2, 2)

    def bottom(self, c, r_from=None):
        """la última fila sólida de la columna c contando desde arriba de la primera masa (o desde r_from)"""
        L = self.L
        r = r_from or 2
        while r < L.h and L.get(c, r) == EMPTY: r += 1
        if r >= L.h: return None
        while r < L.h - 1 and L.get(c, r + 1) != EMPTY: r += 1
        return r

    def mass(self, c0, c1, r0, r1, jag=1, tile=None):
        """roca maciza de c0..c1 x r0..r1 con los LADOS irregulares (cada fila entra o sale `jag` casillas)"""
        rng = self.rng
        dl = dr = 0
        for r in range(r0, r1 + 1):
            if r > r0:
                dl = max(-jag, min(jag, dl + rng.choice((-1, 0, 0, 1))))
                dr = max(-jag, min(jag, dr + rng.choice((-1, 0, 0, 1))))
            for c in range(c0 + dl, c1 - dr + 1):
                self.L.set(c, r, tile or ((self.top if (r == r0 or self.L.get(c, r - 1) == EMPTY) else self.body)))

    def massif(self, c0, c1, top, bottom, amp=1.5, shoulder=3, taper=8, tips=3, veins=0.02):
        """MACIZO flotante (un monte que no llega al suelo): cara de arriba con picos (`amp`) que baja `shoulder`
        filas en los extremos; cara de abajo en `bottom` en medio, que sube `taper` filas hacia los extremos, con
        estalactitas; vetas de cristal sueltas dentro. Devuelve (tops, bottoms) por columna"""
        rng, n = self.rng, c1 - c0 + 1
        ph = [rng.random() * 6.28 for _ in range(3)]
        tops, bots = {}, {}
        for i, c in enumerate(range(c0, c1 + 1)):
            x = (i + 0.5) / n
            edge = 1 - math.sin(math.pi * x) ** 0.5
            t = top - amp * (math.sin(i * 0.31 + ph[0]) * 0.6 + math.sin(i * 0.13 + ph[1]) * 0.8) + shoulder * edge
            b = bottom - taper * (1 - math.sin(math.pi * x) ** 0.7) + rng.choice((-1, 0, 0, 1)) * (0.2 < x < 0.8)
            tops[c], bots[c] = int(round(t)), max(int(round(t)) + 2, int(round(b)))
        for c in range(c0 + 1, c1 + 1):               # (escalones de 2 como mucho)
            tops[c] = max(tops[c - 1] - 2, min(tops[c - 1] + 2, tops[c]))
            bots[c] = max(bots[c - 1] - 2, min(bots[c - 1] + 2, bots[c]))
        for c in range(c0, c1 + 1):
            for r in range(tops[c], bots[c] + 1):
                self.L.set(c, r, self.top if r == tops[c] else self.body)
        for _ in range(tips):
            c = rng.randrange(c0 + n // 5, c1 - n // 5 + 1)
            ln = rng.randrange(2, 5)
            for r in range(bots[c] + 1, bots[c] + 1 + ln): self.L.set(c, r, self.body)
            for r in range(bots[c] + 1, bots[c] + ln - 1):
                self.L.set(c - 1, r, self.body); self.L.set(c + 1, r, self.body)
            self.sub(c, bots[c] + ln + 1, 1); self.sub(c, bots[c] + ln + 1, 2)
        # vetas de cristal (el tile de superficie, suelto dentro de la roca)
        for c in range(c0 + 2, c1 - 1):
            for r in range(tops[c] + 2, bots[c] - 1):
                if rng.random() < veins:
                    for dc, dr in ((0, 0), (1, 0), (0, 1), (1, 1))[:rng.randrange(1, 5)]:
                        if self.L.get(c + dc, r + dr) == self.body: self.L.set(c + dc, r + dr, self.top)
        self.round_under(c0, c1)
        self.round_top(c0, c1)
        self.sub(c0 - 1, tops[c0], 4); self.sub(c1 + 1, tops[c1], 3)
        return tops, bots

    def round_top(self, c0, c1):
        """suaviza los escalones de la cara de ARRIBA: un cuarto en el rincón de cada escalón (abajo, junto a la pared)"""
        L = self.L
        for c in range(c0 - 1, c1 + 1):
            ta, tb = self.surface(c), self.surface(c + 1)
            if ta is None or tb is None or ta == tb: continue
            if ta < tb: self.sub(c + 1, tb - 1, 3)        # la izquierda más alta
            else: self.sub(c, ta - 1, 4)

    def surface(self, c, r_from=2):
        r = r_from
        while r < self.L.h and self.L.get(c, r) == EMPTY: r += 1
        return r if r < self.L.h else None

    def carve(self, c0, r0, c1, r1, back=True):
        """vacía un hueco (túnel, cueva, pozo); `back` = la pared de roca del PLANO DE FONDO detrás (se lee como una
        cueva, no como un agujero al cielo)"""
        for c in range(c0, c1 + 1):
            for r in range(r0, r1 + 1):
                was = self.L.get(c, r)
                self.L.set(c, r, EMPTY)
                if back and was != EMPTY: self.bg(c, r, self.body, over=True)

    def arch(self, c0, c1, base, low, high, thick=3, leg=3):
        """ARCO de roca natural: dos patas de `leg` de ancho que suben desde `base` (fila de su suelo) y un techo cuya
        cara de abajo va de `low` (junto a las patas) a `high` (en medio); `thick` filas de grueso, irregular"""
        rng, n = self.rng, c1 - c0
        for i, c in enumerate(range(c0, c1 + 1)):
            x = i / max(1, n)
            under = int(round(low - (low - high) * math.sin(math.pi * x) ** 0.8))
            top = under - thick - rng.choice((0, 0, 1)) - int(round(math.sin(math.pi * x) * 1.5))
            if i < leg or i > n - leg: under = base - 1
            for r in range(top, under + 1):
                self.L.set(c, r, self.top if r == top else self.body)
        self.round_under(c0, c1)
        self.round_top(c0, c1)

    def hang(self, c0, c1, r_top, depth=3, tips=2):
        """roca que cuelga (de r_top hacia abajo): honda en medio, irregular, con alguna punta"""
        rng, n = self.rng, c1 - c0 + 1
        for i, c in enumerate(range(c0, c1 + 1)):
            x = (i + 0.5) / n
            d = 1 + (depth - 1) * math.sin(math.pi * x) ** 0.6 + rng.choice((-1, 0, 0, 0, 1))
            for r in range(r_top, r_top + max(1, int(round(d)))):
                self.L.set(c, r, self.body)
        for _ in range(tips):
            c = rng.randrange(c0 + 1, c1)
            b = self.bottom(c, r_top)
            if b is None: continue
            self.sub(c, b + 1, 1); self.sub(c, b + 1, 2)
        self.round_under(c0, c1)

    def spire(self, c, base, top, w=3):
        """aguja que sube de `base` (abajo) a `top`: w de ancho abajo, se estrecha hacia arriba; la punta, plana (se
        pisa) con el tile de superficie"""
        h = base - top + 1
        for k, r in enumerate(range(top, base + 1)):
            ww = 1 + int((w - 1) * (k / max(1, h - 1)) ** 0.7 + 0.5)
            a = c - (ww - 1) // 2
            for cc in range(a, a + ww):
                self.L.set(cc, r, self.top if r == top else self.body)
        self._bevel_sides(c - w - 1, c + w + 1, top, base)    # (el escalón entre anchuras, en diagonal)

    def _bevel_sides(self, c0, c1, r0, r1):
        """rincones de los LADOS que se ensanchan hacia abajo: un cuarto encima de cada escalón"""
        L = self.L
        for r in range(r0 + 1, r1 + 1):
            for c in range(c0, c1 + 1):
                if L.get(c, r) == EMPTY: continue
                if L.get(c, r - 1) == EMPTY:
                    if L.get(c + 1, r - 1) != EMPTY: self.sub(c, r - 1, 4)
                    elif L.get(c - 1, r - 1) != EMPTY: self.sub(c, r - 1, 3)

    # ── plano de fondo ──────────────────────────────────────────────────────────────────────────────────────────
    def bg(self, c, r, v, over=False):
        """un bloque del plano de fondo; sin `over`, no pisa lo que ya hay (las cuevas, lo puesto antes)"""
        if not over and self.L.bg is not None and self.L.inb(c, r) and self.L.bg[r - 1][c - 1]: return
        self.L.set_bg(c, r, v)

    def bg_cloud_sea(self, row, c0=2, c1=None):
        c1 = c1 or self.L.w - 1
        for c in range(c0, c1 + 1):
            crest = row + int(round(math.sin(c * 0.37) * 0.8 + math.sin(c * 0.11 + 1.3) * 1.2))
            for r in range(crest, self.L.h):
                self.bg(c, r, self.cloud, over=True)

    def bg_spire(self, c, base, top, w=5, tile=None):
        h = base - top + 1
        for k, r in enumerate(range(top, base + 1)):
            ww = 1 + int((w - 1) * (k / max(1, h - 1)) ** 1.1 + 0.5)
            a = c - (ww - 1) // 2
            for cc in range(a, a + ww):
                self.bg(cc, r, tile or (self.top if r - top < 2 else self.body))

    def bg_island(self, c0, c1, top, depth=4):
        rng, n = self.rng, c1 - c0 + 1
        for i, c in enumerate(range(c0, c1 + 1)):
            x = (i + 0.5) / n
            d = 1 + (depth - 1) * math.sin(math.pi * x) ** 0.8 + rng.choice((-1, 0, 1)) * (0.3 < x < 0.7)
            for r in range(top, top + max(1, int(round(d)))):
                self.bg(c, r, self.top if r == top else self.body)

    def bg_tower(self, c, base, h, w=3):
        for cc in range(c, c + w):
            for r in range(base - h + 1, base + 1):
                self.bg(cc, r, self.window if (cc == c + w // 2 and (base - r) % 3 == 1 and r > base - h + 1) else self.brick)
        # almenas
        for cc in range(c, c + w, 2): self.bg(cc, base - h, self.brick)

    def bg_portico(self, c, base, h, w=5):
        for r in range(base - h + 1, base + 1):
            self.bg(c, r, self.pillar); self.bg(c + w - 1, r, self.pillar)
        for cc in range(c, c + w): self.bg(cc, base - h, self.brick)

    def bg_arch(self, c0, c1, base, h):
        """arco de ladrillo: dos pilares y una curva por arriba"""
        n, top = c1 - c0, base - h
        for i, c in enumerate(range(c0, c1 + 1)):
            if i in (0, n):                        # los pilares
                for r in range(top, base + 1): self.bg(c, r, self.pillar or self.brick)
                continue
            x = i / n                              # la curva: el hueco llega más arriba en medio
            hole_top = top + 1 + int(round((1 - math.sin(math.pi * x) ** 0.5) * (h - 2)))
            for r in range(top, hole_top): self.bg(c, r, self.brick)
