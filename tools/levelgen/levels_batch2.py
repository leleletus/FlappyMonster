"""Tanda 2: 15 niveles GRANDES que usan las mecánicas que ya hay (bombas, Activadores y Bloques
ON/OFF, hielo y hielo fino, congeladores, bloques rompibles, trampolines, peces globo, morteros,
pinchos que caen, lava, niveles a oscuras...) y están pensados también para el futuro modo del
ESCONDITE: varias alturas (sótanos, suelo, tramos altos sueltos — NO una pasarela seguida: arriba
se sube a por algo y se vuelve a bajar) y escondrijos (cabañas, túneles de una casilla, salas tras
bloques rompibles).

  10 de carrera + caza (`modes`: race, hunt, hide)   ·   5 arenas de Rey de la Colina (koth, hide)

Cómo están hechos: cada nivel es una fila de PIEZAS (métodos de `B`) sobre el suelo `G`, más
pasarelas (`deck`), escaleras (`ladder`) y sótanos (`basement`). El camino obligado nunca depende
de algo que se pueda perder: lo que hay que abrir se abre con un Activador (siempre se puede volver
a golpear), con la cabeza o con un ground pound; las bombas guardan atajos y tesoros y reaparecen.

Comprobación: `OPEN=1` escribe la variante RESUELTA (paredes rompibles abiertas, bloques ON/OFF como
quedan tras golpear el Activador) para `tools/tests/run.sh level_solve`, que no sabe romper bloques
ni usar Activadores:
    OPEN=1 python3 tools/levelgen/build.py --only <nivel> --out /tmp/x   → level_solve
    python3 tools/levelgen/build.py --only <nivel> && python3 tools/levelgen/retheme.py <nivel>

Medidas (doble salto): un escalón de 2 casillas se sube cómodo, 3 es el límite; huecos ≤ 4; un
trampolín hacia arriba sube 5. Alto 28: azotea en la fila 6, pasarela en la 14, suelo en la 22,
sótano en las filas 23-24, pozas hasta la 26.
"""
import os
from lib import *

ID_HIGH = 2 ** 17
OPEN = bool(os.environ.get('OPEN'))


def enc(i): return i % 16 + (i // 16) * ID_HIGH


LAVA, SW_ON, SW_OFF, HID = 3, 13, 14, 15
ONB, ONB_X, OFFB, OFFB_X = enc(18), enc(19), enc(27), enc(28)
ICE, THIN = enc(30), enc(31)
STRUCT = BORDER         # lo CONSTRUIDO (cabañas, casetas, techos, pilares, muros): roca compacta, que retheme no convierte en césped
H, G, U, TOP = 28, 22, 14, 6


class B(Level):
    def __init__(self, name, name_en, w, start_col=4, music='classic', modes=('race', 'hunt', 'hide'), **extra):
        Level.__init__(self, name, w, H, (start_col, G - 1), music=music, modes=list(modes))
        self.extra.update(name_en=name_en, **extra)
        self.ground(2, w - 1, G)
        self.blinks, self.pits, self.cellars = [], [], []
        self.isles, self.spits = [], []

    # ── utilidades ───────────────────────────────────────────────────────
    def to_json(self):
        if self.blinks:
            self.extra['blockLinks'] = self.blinks
        return Level.to_json(self)

    def check(self):
        """Además de lo básico: fosos que caen en un sótano, enemigos que patrullan sin suelo."""
        warn = Level.check(self)
        for a, b in self.pits:
            for x, y in self.cellars:
                if a <= y and b >= x:
                    warn.append('foso %d-%d dentro del sótano %d-%d' % (a, b, x, y))
        solidish = lambda v: v != EMPTY and v != WATER and v != LAVA and not (v > 31 and v < ID_HIGH)        # (ni pinchos)
        for e in self.entities:
            p = e.get('props', {})
            pt = p.get('patrol')
            if isinstance(pt, dict) and p.get('movement') != 'fly' and p.get('attach') != 'ceiling' and e['type'] != 'pufferfish':
                for c in range(pt['left'], pt['right'] + 1):
                    if not solidish(self.get(c, e['row'] + 1)):
                        warn.append('%s (%d,%d): sin suelo en la columna %d de su ruta' % (e['type'], e['col'], e['row'], c)); break
                    if self.get(c, e['row']) not in (EMPTY,):
                        warn.append('%s (%d,%d): su ruta choca en la columna %d' % (e['type'], e['col'], e['row'], c)); break
        return warn

    def walk(self, typ, c0, c1, r=None, **props):
        """Enemigo que patrulla entre c0 y c1 (sobre el suelo, o de pie en la fila r)"""
        props.setdefault('patrol', {'left': c0, 'right': c1})
        return self.ent(typ, (c0 + c1) // 2, r or (G - 1), **props)

    def fly(self, typ, c0, c1, r, **props):
        return self.ent(typ, (c0 + c1) // 2, r, movement='fly', patrol={'left': c0, 'right': c1}, **props)

    def stars(self, *cells):
        for c, r in cells:
            self.ent('star', c, r)

    def put(self, c, r, v):
        """Como set, pero avisa si pisa algo (piezas que se solapan)"""
        assert self.get(c, r) == EMPTY, '%s: (%d,%d) ya ocupado' % (self.name, c, r)
        self.set(c, r, v)

    def sw(self, c, r):
        """Activador ON/OFF (empieza en OFF; resuelto: ON)"""
        self.put(c, r, SW_ON if OPEN else SW_OFF)
        return (c, r)

    def on_blocks(self, c0, r0, c1, r1, src):
        """Bloques ON: sólidos cuando su Activador está en ON (al empezar, solo el contorno)"""
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.set(c, r, ONB if OPEN else ONB_X)
                self.blinks.append({'col': c, 'row': r, 'from': list(src)})

    def off_blocks(self, c0, r0, c1, r1, src):
        """Bloques OFF: sólidos al empezar; se abren al poner su Activador en ON"""
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.set(c, r, OFFB_X if OPEN else OFFB)
                self.blinks.append({'col': c, 'row': r, 'from': list(src)})

    def breakable(self, c0, r0, c1, r1):
        self.rect(c0, r0, c1, r1, EMPTY if OPEN else BREAK)

    # ── alturas: pasarelas, islas, escaleras ─────────────────────────────
    def deck(self, c0, c1, r=U, kind=DROP):
        for c in range(c0, min(c1, self.w - 2) + 1):
            self.put(c, r, kind)

    def island(self, c0, c1, r=U, thick=2):
        """Isla flotante de terreno (la re-viste retheme: césped, nieve...)"""
        for rr in range(r, r + thick):
            for c in range(c0, min(c1, self.w - 2) + 1):
                self.put(c, rr, SOLID)

    def ladder(self, c, base=G, top=U, right=True):
        """Tablas en zigzag de 2 en 2 casillas desde `base` hasta `top`, con su rellano arriba
        (ocupa las columnas c..c+5)"""
        r, k = base - 2, 0
        while r >= top:
            a = c if (k % 2 == 0) == right else c + 3
            for x in range(a, a + 3):
                self.put(x, r, DROP)
            r, k = r - 2, k + 1

    def sky(self, c, spec, r=U):
        """Fila de islas (I), pasarelas (D) y huecos (_): 'I12 _3 D10'. Devuelve los tramos [(tipo, c0, c1)]"""
        out = []
        for tok in spec.split():
            kind, w = tok[0], int(tok[1:])
            if kind == 'I':
                self.island(c, c + w - 1, r)
                if r == U: self.isles.append((c, min(c + w - 1, self.w - 2)))
            elif kind == 'D':
                self.deck(c, c + w - 1, r)
            out.append((kind, c, min(c + w - 1, self.w - 2)))
            c += w
        return [t for t in out if t[0] != '_']

    UPPER = ('I12 _4 D8 _4 I10', 'D8 _4 I14 _4 D8', 'I10 _4 I10 _4 I10')

    def upper(self, stairs, foes=('gummy', 'crabby'), ice=False, mortar=False, roof=False, life=1):
        """Lo de ARRIBA no es un camino: son TRAMOS cortos y sueltos, uno por escalera, con huecos
        de 4 entre sus islas y un vacío que no se salta (≥ 9) hasta el siguiente — hay que volver
        a bajar. (La primera versión era una pasarela seguida: el usuario vio que el nivel se
        pasaba entero por arriba en línea recta.) Cada tramo trae su premio y sus enemigos."""
        ends = list(stairs[1:]) + [self.w - 12]
        out = []
        for i, s0 in enumerate(stairs):
            room, c, toks = ends[i] - (s0 + 6) - 9, s0 + 6, []
            for tok in self.UPPER[i % len(self.UPPER)].split():
                w = int(tok[1:])
                if w > room:
                    break
                toks.append(tok); room -= w
            while toks and toks[-1][0] == '_':
                toks.pop()
            sec = self.sky(c, ' '.join(toks)) if toks else []
            if not toks:                                    # (sin sitio para un tramo: un mirador con su premio)
                self.stars((s0 + 1, U - 2), (s0 + 4, U - 2))
            out.append(sec)
            for j, (kind, a, b) in enumerate(sec):
                foe = foes[(i + j) % len(foes)]
                if kind == 'I':
                    if ice:
                        self.rect(a, U, b, U, ICE)
                    if foe == 'gloomy':
                        self.ent('gloomy', (a + b) // 2, U - 1)
                    elif mortar and j == len(sec) - 1:
                        self.ent('mortar', b - 2, U - 1, range=8)
                    else:
                        self.walk(foe, a + 2, b - 2, U - 1, **({'helmet': True} if foe == 'gummy' and (i + j) % 3 == 2 else {}))
                    if j == len(sec) - 1:
                        if i == life:
                            self.ent('extralife', (a + b) // 2, U - 4)
                        else:
                            self.stars(((a + b) // 2 - 1, U - 3), ((a + b) // 2 + 1, U - 3))
                    if roof and b - a >= 11 and j == 0:           # azotea: una escalera más y un premio arriba del todo
                        self.ladder(a + 3, base=U, top=TOP)
                        self.deck(a + 9, a + 14, TOP)
                        self.stars((a + 11, TOP - 2), (a + 13, TOP - 2))
                else:
                    self.stars((a + 2, U - 2), (b - 2, U - 2))
                    if foe != 'gloomy':
                        self.fly('gummy', a, b, U - 4)
        return out

    # ── PIEZAS de suelo (c = primera columna; devuelven la siguiente libre) ──
    def flat(self, c, w):
        return c + w

    def stairs(self, c, right=True):
        """Tramo llano con la escalera a la pasarela (7 columnas)"""
        self.ladder(c, right=right)
        return c + 7

    def cellar(self, c, w, stairs=(0,), breaks=(), holes=()):
        """Tramo llano con un SÓTANO debajo (filas 23-24). Entradas (columnas desde c): `stairs`
        (hueco de 2 con escalón para volver a salir), `breaks` (suelo rompible: ground pound),
        `holes` (hueco sin escalón). Devuelve la siguiente columna."""
        a, b = c + 1, c + w - 2
        self.clear(a, G + 1, b, G + 2)
        self.cellars.append((a, b))
        for o in stairs:
            self.clear(c + o, G, c + o + 1, G)
            self.set(c + o - 1 if o > 2 else c + o + 2, G + 2, SOLID)
        for o in holes:
            self.clear(c + o, G, c + o + 1, G)
        for o in breaks:
            self.rect(c + o, G, c + o + 1, G, BREAK)
        return c + w

    def pit(self, c, w=3):
        """Foso con pinchos"""
        self.clear(c, G, c + w - 1, G + 2)
        self.spikes(c, c + w - 1, G + 2, UP)
        self.pits.append((c, c + w - 1))
        self.spits.append((c, c + w - 1))
        return c + w

    def populate(self, droppers='crabby', flyers='gummy'):
        """Más vida sin tocar el camino: un Crabby colgado BAJO una isla sí y otra no (se deja caer al
        verte pasar por debajo) y un Gummy volando sobre uno de cada dos fosos."""
        if droppers:
            for i, (a, b) in enumerate(self.isles):
                if i % 2 == 0 and b - a >= 8:
                    self.ent(droppers, (a + b) // 2, U + 2, attach='ceiling', dropOnSight=True, patrol={'left': a + 2, 'right': b - 2})
        if flyers:
            for i, (a, b) in enumerate(self.spits):
                if i % 2 == 1:
                    self.fly(flyers, a - 2, b + 2, G - 4)

    def hill(self, c, w, h=2):
        """Loma: sube h (de 2 en 2) y vuelve a bajar"""
        for k in range(1, h // 2 + 1):
            self.rect(c + (k - 1) * 2, G - 2 * k, c + w - 1 - (k - 1) * 2, G - 1, SOLID)
        return c + w

    def bomb_vault(self, c, loot=('star', 'star', 'extralife'), respawn=6):
        """Cabaña cerrada con una pared ROMPIBLE: la bomba que ronda fuera la abre (patéala hacia la
        pared). Se pasa por el tejado; dentro, el botín (y un buen escondite). Ancho 13."""
        self.rect(c + 5, G - 4, c + 11, G - 4, STRUCT)         # tejado
        self.rect(c + 11, G - 3, c + 11, G - 1, STRUCT)        # pared del fondo
        self.breakable(c + 5, G - 3, c + 5, G - 1)             # la puerta
        self.plat(c + 2, c + 3, G - 2, DROP)                   # escalón al tejado
        for i, t in enumerate(loot):
            self.ent(t, c + 7 + i, G - 2)
        self.ent('bomb', c + 1, G - 1, patrol={'left': c, 'right': c + 4}, respawn=respawn, speed=40)
        return c + 13

    def bomb_wall(self, c):
        """Muro rompible que cierra el paso: lo abre la bomba parada a su lado (o se salta por la
        tabla y el dintel). Ancho 8."""
        self.breakable(c + 4, G - 3, c + 5, G - 1)
        self.rect(c + 4, G - 4, c + 5, G - 4, STRUCT)
        self.ent('bomb', c + 2, G - 1, respawn=5, speed=0)
        self.plat(c + 1, c + 2, G - 2, DROP)
        return c + 8

    def switch_bridge(self, c, w=7):
        """Foso demasiado ancho para saltarlo: el Activador (cabezazo desde abajo) hace sólido el
        puente de Bloques ON. Ancho w + 6."""
        s = self.sw(c + 1, G - 4)
        a, b = c + 4, c + 3 + w
        self.clear(a, G, b, G + 2)
        self.spikes(a, b, G + 2, UP)
        self.pits.append((a, b))
        self.on_blocks(a, G, b, G, s)
        return b + 3

    def switch_door(self, c):
        """Caseta con un pasillo cerrado por Bloques OFF: el Activador de fuera lo abre. Ancho 12."""
        s = self.sw(c + 1, G - 4)
        self.rect(c + 5, U + 3, c + 10, G - 3, STRUCT)
        self.off_blocks(c + 5, G - 2, c + 5, G - 1, s)
        self.ent('star', c + 8, G - 1)
        return c + 12

    def puffer(self, c0, r0, c1, r1, **props):
        area = [{'col': c0, 'row': r0}, {'col': c1, 'row': r0}, {'col': c1, 'row': r1}, {'col': c0, 'row': r1}]
        self.ent('pufferfish', (c0 + c1) // 2, r1, area=area, **props)

    def lake(self, c, w=14, depth=3, ice=True, puffer=False):
        """Lago (el agua, una casilla por debajo del suelo). A los lados, ESCALONES de una casilla
        hasta el fondo: bajo el agua no se nada hacia arriba (se salta 1), así que se sale andando.
        Con HIELO FINO encima: se cruza corriendo (estar encima lo va rompiendo; un ground pound
        lo rompe de golpe) o se cae al agua. Sin hielo: por el fondo o por lo que haya encima."""
        a, b = c + 1, c + w - 2
        assert w >= 2 * depth + 6, 'lago demasiado estrecho para sus escalones'
        self.clear(a, G, b, G)
        self.rect(a, G + 1, b, G + depth, WATER)
        for i in range(depth):
            self.rect(a + i, G + 1 + i, a + i, G + depth, SOLID)
            self.rect(b - i, G + 1 + i, b - i, G + depth, SOLID)
        if ice:
            self.rect(a + 1, G, b - 1, G, THIN)
        if puffer:
            self.puffer(a + depth + 1, G + 2, b - depth - 1, G + depth)
        self.pits.append((a, b))
        return c + w

    def dive_pool(self, c, w=20, puffers=1):
        """Poza honda partida por un muro: hay que BUCEAR por debajo (peces globo, un respiradero).
        Escalones a los dos lados para bajar y volver a salir."""
        a, b = c + 1, c + w - 2
        self.clear(a, G, b, G)
        self.rect(a, G + 1, b, G + 4, WATER)
        m = (a + b) // 2
        self.rect(m, G - 5, m, G + 2, STRUCT)                  # el muro: no se salta; por debajo quedan 2 casillas
        for i in range(4):
            self.rect(a + i, G + 1 + i, a + i, G + 4, SOLID)
            self.rect(b - i, G + 1 + i, b - i, G + 4, SOLID)
        self.vent(m, G + 4, 3)
        if puffers >= 1:
            self.puffer(a + 4, G + 2, m - 1, G + 4)
        if puffers >= 2:
            self.puffer(m + 1, G + 2, b - 4, G + 4)
        self.pits.append((a, b))
        return c + w

    def freezer_hall(self, c, w=10, n=2, interval=3.2, ice=False):
        """Pasillo bajo un techo con CONGELADORES que disparan hacia abajo por turnos"""
        self.rect(c, G - 5, c + w - 1, G - 4, STRUCT)
        for i in range(n):
            x = c + 2 + i * ((w - 5) // max(1, n - 1)) if n > 1 else c + w // 2
            self.ent('cryo', x, G - 3, dir='down', interval=interval, firstDelay=0.4 + i * interval / n, range=3, freezeTime=2.2)
        if ice:
            self.rect(c, G, c + w - 1, G, ICE)
        return c + w

    def crouch_tunnel(self, c, w=8):
        """Losa baja: por debajo, agachado (premio dentro); por encima, saltando"""
        self.rect(c + 1, G - 2, c + w - 2, G - 2, STRUCT)
        self.ent('star', c + w // 2, G - 1)
        return c + w

    def spikefall_hall(self, c, w=11, n=3):
        self.rect(c, G - 6, c + w - 1, G - 5, STRUCT)
        for i in range(n):
            self.ent('spikefall', c + 2 + i * ((w - 4) // max(1, n - 1)), G - 4, sub=1 + i % 2, detectRange=6)
        return c + w

    def mortar_nest(self, c, w=10):
        """Mortero en un pilar, con un tejadillo para cubrirse"""
        self.rect(c + w - 4, G - 2, c + w - 3, G - 1, STRUCT)
        self.ent('mortar', c + w - 4, G - 3, range=9, delayMin=2.2, delayMax=3.5)
        self.plat(c + 1, c + 3, G - 3, SLAB)
        return c + w

    def lava_hops(self, c, w=13):
        """Foso de LAVA con plataformas"""
        self.clear(c, G, c + w - 1, G + 2)
        self.rect(c, G + 1, c + w - 1, G + 2, LAVA)
        k = c + 2
        while k + 1 < c + w - 1:
            self.plat(k, k + 1, G, SLAB)
            k += 4
        self.pits.append((c, c + w - 1))
        return c + w

    def ice_run(self, c, w=12, gap=3):
        """Pista de HIELO (resbala) con un foso en medio"""
        self.rect(c, G, c + w - 1, G, ICE)
        m = c + w // 2 - gap // 2
        self.clear(m, G, m + gap - 1, G + 2)
        self.spikes(m, m + gap - 1, G + 2, UP)
        self.pits.append((m, m + gap - 1))
        return c + w

    def tramp_cliff(self, c, w=7):
        """Acantilado de 4: solo se sube con el trampolín (o por la pasarela)"""
        self.ent('trampoline', c, G - 1)
        self.rect(c + 2, G - 4, c + 1 + w, G - 1, SOLID)
        return c + 2 + w

    def tramp_gap(self, c, w=10):
        """Foso ancho con pinchos: trampolín a una tabla alta y de ahí a otra más baja"""
        self.ent('trampoline', c, G - 1)
        a, b = c + 2, c + 1 + w
        self.clear(a, G, b, G + 2)
        self.spikes(a, b, G + 2, UP)
        self.pits.append((a, b))
        self.plat(a + 1, a + 4, G - 4, DROP)
        self.plat(b - 3, b - 1, G - 2, DROP)
        self.stars((a + 2, G - 6), (a + 3, G - 6))
        return b + 1

    def koth_zone(self, c0, r0, c1, r1, points=4):
        self.ent('pointarea', c0, r0, corner={'col': c1, 'row': r1}, points=points)

    def end(self, c):
        """Los últimos 12: punto de control y la meta. `c` = primera columna"""
        assert c + 13 <= self.w, '%s: no cabe el final (c=%d, ancho %d)' % (self.name, c, self.w)
        W = c + 13                                          # el nivel acaba aquí: se recorta a su ancho
        self.g = [row[:W] for row in self.g]
        self.w = W
        for r in range(1, self.h + 1):
            self.set(W, r, BORDER)
        self.ent('checkpoint', c + 2, G - 1)
        self.finish(self.w - 7, G - 1)


K = dict(points=6, respawn=8)          # enemigos de las arenas: reaparecen y dan menos puntos


# ═════════════════════════════════════════════════════════════════════════════
# CARRERA + CAZA
# ═════════════════════════════════════════════════════════════════════════════
def pradera_explosiva():
    """Pradera de día: BOMBAS vivas y bloques rompibles. Cabañas que solo abre una bomba, suelos
    que ceden a un ground pound y sótanos con el botín."""
    L = B('Pradera Explosiva', 'Boom Meadow', 190, music='classic', background='meadow')
    c = L.flat(2, 12)
    L.walk('gummy', 7, 12); L.stars((9, G - 3), (10, G - 3))
    s1 = c; c = L.stairs(c)                                # 14
    c = L.hill(c, 8, 2); L.walk('crabby', c - 7, c - 2, G - 3)
    c = L.bomb_vault(c)
    c = L.flat(c, 7); L.walk('gummy', c - 6, c - 1, helmet=True)
    c = L.pit(c, 3)
    c = L.flat(c, 4); L.ent('checkpoint', c - 3, G - 1)
    k = c; c = L.cellar(c, 28, stairs=(24,), breaks=(3,))  # sótano con una tapia que abre la bomba
    L.walk('crabby', k + 6, k + 12, G + 2)
    L.walk('bomb', k + 14, k + 18, G + 2, respawn=6, speed=40)
    L.breakable(k + 20, G + 1, k + 20, G + 2)
    L.stars((k + 9, G + 1), (k + 22, G + 1), (k + 23, G + 1)); L.ent('extralife', k + 21, G + 2)
    L.walk('gummy', k + 8, k + 16)
    L.crouch_tunnel(k + 18, 6)
    s2 = c; c = L.stairs(c, right=False)
    c = L.hill(c, 10, 4); L.ent('crabby', c - 5, G - 5, wallWalk=True, patrol=False, speed=60)
    c = L.pit(c, 4)
    c = L.flat(c, 4); L.ent('checkpoint', c - 3, G - 1)
    c = L.bomb_vault(c, loot=('star', 'star', 'star'))
    c = L.flat(c, 7); L.walk('gummy', c - 6, c - 1)
    c = L.pit(c, 3)
    s3 = c; c = L.stairs(c)
    c = L.bomb_wall(c)
    c = L.flat(c, 6); L.walk('crabby', c - 5, c - 1)
    L.end(c)
    L.upper([s1, s2, s3])
    L.populate()
    return L


def bosque_interruptores():
    """Bosque al atardecer: Activadores y Bloques ON/OFF. Puentes que hay que encender, casetas
    que se abren y un sótano con su propia puerta."""
    L = B('Bosque de los Interruptores', 'Switch Woods', 190, music='labyrinth', background='forest', time='dusk')
    c = L.flat(2, 10); L.walk('gummy', 6, 10)
    s1 = c; c = L.stairs(c)
    c = L.switch_bridge(c, 7)
    c = L.flat(c, 8); L.walk('crabby', c - 7, c - 2); L.stars((c - 5, G - 3), (c - 3, G - 3))
    c = L.hill(c, 8, 2)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    c = L.switch_door(c)
    c = L.flat(c, 7); L.walk('gummy', c - 6, c - 1, helmet=True)
    c = L.pit(c, 3)
    s2 = c; c = L.stairs(c, right=False)
    k = c; c = L.cellar(c, 26, stairs=(2, 22))
    d = L.sw(k + 8, G - 4)                                 # la puerta del sótano se abre desde arriba
    L.off_blocks(k + 12, G + 1, k + 12, G + 2, d)
    L.walk('crabby', k + 5, k + 10, G + 2)
    L.stars((k + 15, G + 1), (k + 17, G + 1), (k + 19, G + 1)); L.ent('extralife', k + 14, G + 2)
    L.walk('gummy', k + 12, k + 18)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    c = L.switch_bridge(c, 8)
    c = L.flat(c, 6); L.walk('crabby', c - 5, c - 1)
    s3 = c; c = L.stairs(c)
    c = L.crouch_tunnel(c, 8)
    c = L.flat(c, 4)
    L.end(c)
    L.upper([s1, s2, s3], foes=('crabby', 'gummy'))
    L.populate()
    return L


def playa_rebotes():
    """Playa de día: TRAMPOLINES y Crabbies trampolín sobre fosos anchos, pozas con peces globo."""
    L = B('Playa de los Rebotes', 'Bounce Beach', 190, music='hidro_city', background='coast')
    c = L.flat(2, 10); L.walk('gummy', 6, 10)
    s1 = c; c = L.stairs(c)
    c = L.tramp_gap(c + 1, 10)
    c = L.flat(c, 8); L.walk('crabby', c - 7, c - 2)
    k = c; c = L.lake(c, 18, depth=4, ice=False, puffer=True)
    L.plat(k + 5, k + 6, G - 1, DROP); L.plat(k + 11, k + 12, G - 1, DROP)      # se cruza por las tablas (o nadando)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    c = L.flat(c, 8); L.walk('crabbytramp', c - 7, c - 2)
    k = c; c = L.tramp_cliff(c + 1, 7); L.walk('gummy', k + 4, k + 8, G - 5)
    c = L.tramp_gap(c + 1, 10)
    c = L.flat(c, 8); L.walk('crabby', c - 7, c - 2)
    s2 = c; c = L.stairs(c, right=False)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    c = L.dive_pool(c, 20, puffers=2)
    c = L.flat(c, 7); L.walk('gummy', c - 6, c - 1, helmet=True)
    c = L.tramp_gap(c + 1, 9)
    c = L.flat(c, 8); L.walk('crabbytramp', c - 7, c - 2)
    L.end(c)
    L.upper([s1, s2], foes=('crabby', 'gummy'))
    L.populate()
    return L


def arrecife_globo():
    """Arrecife: se anda por el FONDO del mar (bajo el agua se salta poco: 1 casilla, 2 con el doble
    salto). Peces globo que patrullan, muros de coral, respiraderos y escaleras de tablas hasta los
    islotes para tomar aire."""
    L = B('Arrecife Globo', 'Puffer Reef', 142, music='hidro_city', background='coast', depth='underwater')
    S = 13                                                 # fila de la superficie del agua
    L.rect(2, S, 141, G - 1, WATER)
    L.rect(2, S - 1, 14, G - 1, SOLID)                     # orilla de salida (una casilla sobre el agua)
    L.rect(15, S, 15, G - 1, SOLID)
    L.start = [4, S - 2]
    L.rect(128, S - 1, 141, G - 1, SOLID)                  # orilla de llegada
    L.rect(127, S, 127, G - 1, SOLID)
    L.walk('gummy', 6, 12, S - 2)

    def rungs(a, top):                                     # escalera de tablas sumergidas, una por fila
        for i, r in enumerate(range(G - 1, top - 1, -1)):
            x = a + (i % 2) * 2
            L.set(x, r, DROP + 16); L.set(x + 1, r, DROP + 16)

    for a in (30, 52, 74, 96, 113):                        # islotes a ras de agua (aire), con su escalera desde el fondo
        L.rect(a, S, a + 5, S + 1, SOLID)
        rungs(a - 4, S + 1)
        L.ent('star', a + 2, S - 2)
    L.walk('crabby', 52, 57, S - 1); L.walk('gummy', 96, 101, S - 1, helmet=True)
    rungs(123, S + 1)                                      # … y la de la orilla de llegada
    # coral: muros que cuelgan (se pasa por debajo) y lomas del fondo (2 de alto, con un escalón)
    for a in (22, 66, 104):
        L.rect(a, S, a + 1, G - 4, SOLID)
    for a in (42, 86):
        L.rect(a, G - 2, a + 2, G - 1, SOLID)
        L.set(a - 1, G - 1, SOLID); L.set(a + 3, G - 1, SOLID)
    for a in (20, 38, 60, 82, 101, 120):
        L.vent(a, G - 1, 3)
    L.stars((18, G - 2), (36, G - 2), (43, G - 4), (58, G - 2), (64, G - 2), (80, G - 2), (87, G - 4), (102, G - 2), (112, G - 2))
    L.puffer(17, S + 3, 21, G - 3)
    L.puffer(32, S + 4, 40, G - 2)
    L.puffer(46, S + 3, 64, S + 5)
    L.puffer(58, S + 7, 65, G - 2)
    L.puffer(68, S + 4, 84, G - 3)
    L.puffer(90, S + 3, 102, S + 5)
    L.puffer(107, S + 4, 121, G - 3)
    L.ent('extralife', 62, G - 2); L.ent('extralife', 114, G - 2)
    L.ent('checkpoint', 54, S - 1); L.ent('checkpoint', 98, S - 1)
    # arriba no hay ruta seca (la hubo: se pasaba el nivel por encima del agua): solo Gummies que
    # vuelan sobre los islotes y un premio alto en cada uno, al que se llega con el doble salto
    for i, a_ in enumerate((30, 52, 74, 96, 113)):
        if i % 2 == 0:
            L.fly('gummy', a_ - 3, a_ + 8, S - 5)
    L.ent('checkpoint', 130, S - 2)
    L.finish(136, S - 2)
    return L


def cantera_dinamita():
    """Cantera de montaña: bombas, paredes rompibles, morteros y pinchos que caen."""
    L = B('Cantera Dinamita', 'Dynamite Quarry', 190, music='flying_machine', background='mountain', depth='underground')
    c = L.flat(2, 10); L.walk('crabby', 6, 10)
    s1 = c; c = L.stairs(c)
    c = L.mortar_nest(c, 10)
    c = L.pit(c, 3)
    c = L.bomb_vault(c)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    k = c; c = L.spikefall_hall(c, 11); L.walk('gummy', k + 2, k + 8)
    k = c; c = L.cellar(c, 30, stairs=(2, 26), breaks=(14,))
    L.walk('bomb', k + 5, k + 9, G + 2, respawn=6, speed=40)
    L.breakable(k + 11, G + 1, k + 11, G + 2)
    L.stars((k + 17, G + 1), (k + 19, G + 1), (k + 21, G + 1)); L.ent('extralife', k + 23, G + 2)
    L.hill(k + 5, 8, 2); L.ent('mortar', k + 8, G - 3, range=9)
    L.walk('crabby', k + 18, k + 24)
    s2 = c; c = L.stairs(c, right=False)
    c = L.pit(c, 4)
    c = L.crouch_tunnel(c, 8)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    c = L.mortar_nest(c, 10)
    c = L.pit(c, 3)
    c = L.bomb_wall(c)
    c = L.flat(c, 7); L.walk('crabby', c - 6, c - 1)
    L.end(c)
    L.upper([s1, s2], mortar=True)
    L.populate()
    return L


def cumbres_escarcha():
    """Cumbres nevadas de día: pistas de HIELO que resbalan y lagos de hielo fino con peces globo."""
    L = B('Cumbres de Escarcha', 'Frost Peaks', 190, music='classic', background='snow', snow=True, spikeSkin='ice')
    c = L.flat(2, 10); L.walk('gummy', 6, 10)
    s1 = c; c = L.stairs(c)
    k = c; c = L.ice_run(c, 12, 3)
    c = L.flat(c, 7); L.walk('crabby', c - 6, c - 1)
    c = L.hill(c, 8, 2)
    c = L.lake(c, 16, depth=3)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    k = c; c = L.cellar(c, 22, stairs=(18,), breaks=(4,))
    L.stars((k + 8, G + 1), (k + 10, G + 1), (k + 12, G + 1)); L.ent('extralife', k + 3, G + 2)
    L.rect(k + 8, G, k + 14, G, ICE); L.walk('gummy', k + 8, k + 14, helmet=True)
    c = L.ice_run(c, 14, 4)
    s2 = c; c = L.stairs(c, right=False)
    c = L.hill(c, 10, 4); L.ent('crabby', c - 5, G - 5, wallWalk=True, patrol=False, speed=60)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    c = L.lake(c, 18, depth=4, puffer=True)
    k = c; c = L.flat(c, 10); L.rect(k, G, k + 9, G, ICE); L.walk('crabby', k + 1, k + 8)
    c = L.pit(c, 3)
    c = L.flat(c, 3)
    L.end(c)
    L.upper([s1, s2], ice=True)
    L.populate()
    return L


def fabrica_criogenica():
    """Fábrica de noche: pasillos con CONGELADORES por turnos, puertas ON/OFF, hielo y pinchos."""
    L = B('Fábrica Criogénica', 'Cryo Works', 190, music='flying_machine', background='fortress', time='night', depth='icecave')
    c = L.flat(2, 10); L.walk('gummy', 6, 10)
    s1 = c; c = L.stairs(c)
    c = L.freezer_hall(c, 10, 2)
    c = L.flat(c, 7); L.walk('crabby', c - 6, c - 1)
    c = L.pit(c, 3)
    c = L.switch_door(c)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    c = L.freezer_hall(c, 14, 3, 3.6, ice=True)
    c = L.pit(c, 4)
    k = c; c = L.cellar(c, 24, stairs=(20,), holes=(2,))
    L.stars((k + 7, G + 1), (k + 9, G + 1), (k + 15, G + 1)); L.ent('extralife', k + 12, G + 2)
    L.walk('gummy', k + 6, k + 14, helmet=True)
    s2 = c; c = L.stairs(c, right=False)
    c = L.switch_bridge(c, 7)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    # congelador horizontal: barre el suelo; se esquiva subido a las tablas mientras dispara
    k = c; c = L.flat(c, 15)
    L.ent('cryo', k + 13, G - 1, dir='left', interval=3.4, firstDelay=1, range=12, freezeTime=2.2)
    L.plat(k + 3, k + 4, G - 2, DROP); L.plat(k + 8, k + 9, G - 2, DROP)
    L.stars((k + 3, G - 4), (k + 8, G - 4))
    k = c; c = L.spikefall_hall(c, 10); L.walk('crabby', k + 2, k + 7)
    c = L.flat(c, 2)
    L.end(c)
    L.upper([s1, s2], foes=('crabby', 'gummy'))
    L.populate()
    return L


def templo_del_eco():
    """Cueva A OSCURAS: Crabbies lúgubres. Lo que hace ruido los distrae (bloques rompibles,
    trampolines, bombas, estrellas): úsalo para alejarlos de tu camino."""
    L = B('Templo del Eco', 'Echo Temple', 190, music='dark_cave', background='cave', time='night', dark=True)
    c = L.flat(2, 10); L.stars((8, G - 3),)
    s1 = c; c = L.stairs(c)
    c = L.flat(c, 6); L.ent('gloomy', c - 3, G - 1)
    c = L.hill(c, 8, 2)
    k = c; c = L.flat(c, 8); L.rect(k + 2, G - 4, k + 4, G - 4, BREAK)   # bloques a mano: romperlos hace ruido
    L.ent('gloomy', k + 6, G - 1)
    c = L.pit(c, 3)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    k = c; c = L.cellar(c, 30, stairs=(2, 26), breaks=(14,))
    L.ent('gloomy', k + 10, G + 2); L.stars((k + 7, G + 1), (k + 18, G + 1), (k + 20, G + 1)); L.ent('extralife', k + 22, G + 2)
    L.ent('trampoline', k + 6, G - 1)                      # ruido… y atajo a la pasarela
    L.crouch_tunnel(k + 17, 7)
    L.ent('gloomy', k + 12, 4)                             # en el techo
    c = L.bomb_vault(c, loot=('star', 'star', 'extralife'), respawn=8)   # la bomba: el ruido más fuerte
    c = L.flat(c, 6); L.ent('gloomy', c - 3, G - 1)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    s2 = c; c = L.stairs(c, right=False)
    c = L.switch_bridge(c, 7)
    c = L.flat(c, 6); L.ent('gloomy', c - 3, G - 1)
    c = L.hill(c, 10, 4); L.ent('gloomy', c - 5, 4)
    c = L.pit(c, 3)
    c = L.flat(c, 3)
    L.end(c)
    L.rect(2, 2, L.w - 1, 3, SOLID)                        # techo de la cueva
    L.upper([s1, s2], foes=('gloomy',))
    return L


def jungla_colgante():
    """Jungla de día: tres alturas de islas colgantes, trampolines para subir y Gummies que vuelan."""
    L = B('Jungla Colgante', 'Hanging Jungle', 190, music='hidro_city', background='forest')
    c = L.flat(2, 10); L.walk('gummy', 6, 10)
    s1 = c; c = L.stairs(c)
    c = L.pit(c, 4)
    c = L.flat(c, 8); L.walk('crabby', c - 7, c - 2)
    k = c; c = L.tramp_cliff(c + 1, 8); L.walk('gummy', k + 4, k + 9, G - 5)
    c = L.flat(c, 4)
    c = L.dive_pool(c, 20, puffers=1)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    s2 = c; c = L.stairs(c, right=False)
    c = L.crouch_tunnel(c, 8)
    c = L.pit(c, 3)
    c = L.flat(c, 8); L.walk('crabbytramp', c - 7, c - 2)
    c = L.switch_bridge(c, 7)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    s3 = c; c = L.stairs(c)
    c = L.hill(c, 12, 4); L.ent('crabby', c - 6, G - 5, wallWalk=True, patrol=False, speed=60)
    c = L.pit(c, 4)
    c = L.flat(c, 8); L.walk('gummy', c - 7, c - 2, helmet=True)
    L.end(c)
    L.upper([s1, s2, s3], roof=True)
    L.populate()
    return L


def caldera_roja():
    """Volcán al atardecer: fosos de LAVA con plataformas, morteros y paredes rompibles."""
    L = B('Caldera Roja', 'Red Caldera', 190, music='flying_machine', background='mountain', time='dusk', depth='underground')
    c = L.flat(2, 10); L.walk('crabby', 6, 10)
    s1 = c; c = L.stairs(c)
    c = L.lava_hops(c, 13)
    c = L.flat(c, 7); L.walk('gummy', c - 6, c - 1)
    c = L.mortar_nest(c, 10)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    k = c; c = L.lava_hops(c, 17); L.fly('gummy', k + 4, k + 12, G - 4)
    c = L.hill(c, 10, 4); L.ent('mortar', c - 6, G - 5, range=9)
    k = c; c = L.spikefall_hall(c, 11)
    s2 = c; c = L.stairs(c, right=False)
    c = L.flat(c, 3); L.ent('checkpoint', c - 2, G - 1)
    c = L.bomb_vault(c)
    c = L.lava_hops(c, 13)
    c = L.flat(c, 7); L.walk('crabby', c - 6, c - 1)
    c = L.bomb_wall(c)
    c = L.flat(c, 4)
    L.end(c)
    L.upper([s1, s2], mortar=True)
    L.populate()
    return L


# ═════════════════════════════════════════════════════════════════════════════
# REY DE LA COLINA (arenas grandes de varias alturas)
# ═════════════════════════════════════════════════════════════════════════════
def arena(name, name_en, w=92, **extra):
    L = B(name, name_en, w, start_col=6, modes=('koth', 'hide'), **extra)
    L.match_time = 180
    return L


def cantera_real():
    """Arena de BOMBAS: la colina central está sobre suelo rompible — una explosión te la quita."""
    L = arena('Cantera Real', 'Royal Quarry', music='flying_machine', background='mountain')
    m = 46
    L.rect(m - 8, G - 3, m + 8, G - 1, SOLID)              # la colina
    L.rect(m - 6, G - 3, m + 6, G - 3, BREAK)              # … con el suelo rompible
    L.plat(m - 11, m - 9, G - 2, DROP); L.plat(m + 9, m + 11, G - 2, DROP)
    L.koth_zone(m - 6, G - 8, m + 6, G - 4)
    for c in (m - 16, m + 16):
        L.ent('bomb', c, G - 1, patrol={'left': c - 3, 'right': c + 3}, respawn=7, speed=40)
    L.walk('crabby', 14, 20, **K); L.walk('crabby', 72, 78, **K)
    L.pit(22, 3); L.pit(67, 3)
    L.ladder(7); L.ladder(80, right=False)
    L.island(13, 30); L.island(62, 79)
    L.deck(34, 58)
    L.koth_zone(40, U - 5, 52, U - 1, points=3)
    L.fly('gummy', 38, 54, U - 4, **K)
    L.ent('mortar', 22, U - 1, range=8); L.ent('mortar', 70, U - 1, range=8)
    L.ladder(43, base=U, top=TOP + 2)
    L.deck(49, 55, TOP + 2); L.ent('extralife', 52, TOP)
    L.stars((18, U - 2), (74, U - 2))
    return L


def lago_de_cristal():
    """Arena helada: la colina es una placa de HIELO FINO sobre un lago con peces globo; arriba, otra bajo dos congeladores."""
    L = arena('Lago de Cristal', 'Glass Lake', music='classic', background='snow', time='dusk', snow=True, spikeSkin='ice')
    m = 46
    L.lake(m - 13, 27, depth=4, puffer=True)
    L.koth_zone(m - 7, G - 5, m + 7, G - 1)
    L.rect(14, G, 30, G, ICE); L.rect(62, G, 78, G, ICE)
    L.walk('crabby', 16, 28, **K); L.walk('crabby', 64, 76, **K)
    L.ladder(7); L.ladder(80, right=False)
    L.island(13, 32); L.island(60, 79)
    L.deck(36, 56)
    L.rect(40, U - 6, 52, U - 6, SOLID)
    L.ent('cryo', 43, U - 5, dir='down', interval=4, firstDelay=1, range=4, freezeTime=2)
    L.ent('cryo', 49, U - 5, dir='down', interval=4, firstDelay=3, range=4, freezeTime=2)
    L.koth_zone(40, U - 4, 52, U - 1, points=3)
    L.walk('gummy', 16, 30, U - 1, **K); L.walk('gummy', 62, 76, U - 1, helmet=True, **K)
    L.stars((23, U - 3), (69, U - 3))
    L.ent('extralife', 46, U - 8)
    L.ladder(33, base=U, top=U - 6); L.ladder(54, base=U, top=U - 6, right=False)
    return L


def ciudadela_alterna():
    """Arena de Activadores: el suelo de cada colina son Bloques ON/OFF — quien golpea el Activador
    le quita el suelo a una y se lo da a la otra."""
    L = arena('Ciudadela Alterna', 'Flip Citadel', music='labyrinth', background='fortress', time='dusk')
    L.clear(26, G, 40, G + 2); L.spikes(26, 40, G + 2, UP)
    L.clear(52, G, 66, G + 2); L.spikes(52, 66, G + 2, UP)
    s = L.sw(46, G - 4)
    L.on_blocks(26, G, 40, G, s)
    L.off_blocks(52, G, 66, G, s)
    L.koth_zone(28, G - 5, 38, G - 1)
    L.koth_zone(54, G - 5, 64, G - 1)
    L.walk('crabby', 14, 22, **K); L.walk('crabby', 70, 78, **K)
    L.ladder(7); L.ladder(80, right=False)
    L.island(13, 24); L.island(68, 79)
    L.deck(28, 40); L.deck(52, 64)
    L.island(43, 49)
    L.walk('gummy', 28, 40, U - 1, **K); L.walk('gummy', 52, 64, U - 1, **K)
    L.ent('spikefall', 34, 2, sub=1, detectRange=14); L.ent('spikefall', 58, 2, sub=2, detectRange=14)
    L.stars((19, U - 2), (73, U - 2))
    L.ent('extralife', 46, U - 3)
    return L


def cala_de_los_muelles():
    """Arena de playa: la colina está en lo alto y se llega REBOTANDO (trampolines y Crabbies
    trampolín) o por las escaleras; abajo, una poza con peces globo."""
    L = arena('Cala de los Muelles', 'Spring Cove', music='hidro_city', background='coast')
    m = 46
    L.lake(m - 13, 27, depth=4, ice=False, puffer=True)
    L.plat(m - 3, m + 3, G - 1, SLAB)                      # islote de tablas en medio de la poza
    L.ent('trampoline', m, G - 2)
    L.island(m - 8, m - 2, G - 7); L.island(m + 2, m + 8, G - 7)      # la colina, con un hueco para entrar rebotando
    L.koth_zone(m - 8, G - 12, m + 8, G - 8)
    L.ent('trampoline', m - 15, G - 1); L.ent('trampoline', m + 15, G - 1)
    L.plat(m - 14, m - 12, G - 5, DROP); L.plat(m + 12, m + 14, G - 5, DROP)      # del trampolín a la tabla, y de ahí a la colina
    L.plat(m - 9, m - 8, G - 1, DROP); L.plat(m + 8, m + 9, G - 1, DROP)          # tablas para llegar al islote del centro
    L.walk('crabbytramp', 14, 26, **K); L.walk('crabbytramp', 66, 78, **K)
    L.ladder(7); L.ladder(80, right=False)
    L.island(13, 30); L.island(62, 79)
    L.walk('gummy', 16, 28, U - 1, **K); L.walk('gummy', 64, 76, U - 1, **K)
    L.ladder(24, base=U, top=TOP + 2); L.ladder(63, base=U, top=TOP + 2, right=False)
    L.deck(30, 62, TOP + 2)
    L.koth_zone(40, TOP - 3, 52, TOP + 1, points=3)
    L.fly('gummy', 38, 54, TOP - 1, **K)
    L.stars((22, U - 3), (70, U - 3))
    L.ent('extralife', 46, G + 4)
    return L


def cripta_del_silencio():
    """Arena A OSCURAS: dos colinas y Crabbies lúgubres que acuden al ruido. Quedarse quieto en la
    colina es fácil… hasta que alguien hace sonar algo."""
    L = arena('Cripta del Silencio', 'Silent Crypt', music='dark_cave', background='cave', time='night', dark=True)
    L.rect(2, 2, 91, 3, SOLID)
    L.rect(38, G - 2, 54, G - 1, SOLID)
    L.koth_zone(40, G - 7, 52, G - 3)
    for c in (18, 30, 62, 74):
        L.ent('gloomy', c, G - 1, respawn=10, points=6)
    L.ent('gloomy', 46, 4, respawn=10, points=6)
    L.ent('trampoline', 34, G - 1); L.ent('trampoline', 58, G - 1)
    L.rect(22, G - 4, 24, G - 4, BREAK); L.rect(68, G - 4, 70, G - 4, BREAK)
    L.ladder(7); L.ladder(80, right=False)
    L.island(13, 34); L.island(58, 79)
    L.deck(38, 54)
    L.koth_zone(40, U - 5, 52, U - 1, points=3)
    L.stars((24, U - 2), (68, U - 2), (46, U - 3))
    k = L.cellar(12, 68, stairs=(4, 62), breaks=(32, 36))
    L.ent('gloomy', 46, G + 2, respawn=10, points=6)
    L.stars((30, G + 1), (60, G + 1)); L.ent('extralife', 40, G + 1)
    return L


BUILDERS = [pradera_explosiva, bosque_interruptores, playa_rebotes, arrecife_globo, cantera_dinamita, cumbres_escarcha,
            fabrica_criogenica, templo_del_eco, jungla_colgante, caldera_roja,
            cantera_real, lago_de_cristal, ciudadela_alterna, cala_de_los_muelles, cripta_del_silencio]
