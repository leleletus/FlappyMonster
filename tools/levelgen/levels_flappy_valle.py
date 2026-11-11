#!/usr/bin/env python3
# tools/levelgen/levels_flappy_valle.py
# Las TRES etapas del Valle de los Pilares (zona 1 de la campaña Flappy, src/flappy/Zones.lua), con el fondo `valley`
# (src/fx/Sky.lua). Los ids se guardan en las partidas: nunca se renombran. Escribe SOLO valle_pilares_1/2/3.json (lo
# común: flappy_lib.py; el jefe, levels_flappy_valle_boss.py).
#
# REDISEÑO (el usuario, 2026-11-11: "bastante cortas, repetitivas y muy fáciles"): cada etapa unas 2-2,5 veces más larga,
# hecha de TRAMOS que no se repiten (cada etapa con su idea, y los tramos la van apretando), con una curva de dificultad:
#   1 «Los pilares» (200 px/s): huecos de 4 que pasan a 3; escalera, el primer pasillo, una jaula colgada de un pilar
#     (la ráfaga atraviesa los pilares) y otra abajo del todo, junto al borde; acaba en un zigzag
#   2 «Grietas y cornisas» (210 px/s): huecos de 3; jaula a la vista, una galería tras un muro con la carga para la
#     jaula dentro, un cañón (pasillo sinuoso), pilares dobles, una CORNISA (arriba, ruta estrecha con premio; abajo, la segura), ritmo
#     de 5 columnas, una bajada de pilares pegados (cada 4) y un segundo cañón
#   3 «La máquina del Malvado» (225 px/s): huecos de 3 y AGUJAS de 2; lanzarredes solos, en BATERÍA (tres seguidos) y
#     debajo de una cornisa (arriba, sin redes pero con estalactitas; abajo, con redes), el atajo del túnel sobre dos
#     lanzarredes, un pasillo vigilado, la jaula de la fila 1 y un final con lanzarredes entre agujas
# Reglas que se mantienen: sin suelo (Plan 5d: los pilares de abajo llegan al borde; los lanzarredes, en su soporte); la
# ruta principal (los huecos) nunca necesita romper un muro ni coger la ruta de arriba de una cornisa (el piloto sin carga
# de flappy_flight `etapa` las pasa); un lanzarredes, a 3 columnas o más de los pilares de los lados (sitio para esperar
# la red); las jaulas de antes siguen en el MISMO índice de la lista de entidades (`rescued` de las partidas guarda el
# índice: legacy=), con su regalo; toda ruta de arriba (cornisa, túnel, galería) tiene 4 filas libres sobre la piedra
# (tocarla quita 1: con menos no se vuela) y flappy_flight `etapa_arriba` la vuela; cada jaula y muro se puede abrir con las
# cargas que hay antes de él aunque se haya disparado a todo lo anterior (flappy_flight `cargas`).
#   python3 tools/levelgen/levels_flappy_valle.py
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flappy_lib
from flappy_lib import ent, launcher, corridor, ledge, tunnel

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
BG = 'valley'


def out(name):
    return os.path.join(ROOT, 'assets', 'levels', name + '.json')


class Course:
    """Una etapa por TRAMOS: un cursor de columna que avanza; cada tramo añade sus huecos, entidades y bloques"""

    def __init__(self, start=22):
        self.c = start
        self.gaps, self.ents, self.solids, self.air, self.mounts = [], [], [], [], []
        self.cages = []                       # (entidad, índice heredado o None)

    def skip(self, n):
        self.c += n

    def pillars(self, step, spec):
        """spec = [(fila de arriba del hueco, alto), ...]: un pilar cada `step` columnas desde el cursor → los huecos"""
        g = []
        for top, h in spec:
            g.append((self.c, top, h))
            self.c += step
        self.gaps += g
        return g

    def at(self, cols_spec):
        """pilares sueltos en columnas dadas: [(columna, fila de arriba, alto), ...] (el cursor queda en la última)"""
        self.gaps += cols_spec
        self.c = max(self.c, cols_spec[-1][0])
        return cols_spec

    def corridor(self, tops, h, after=6):
        g = corridor(self.c, tops, h)
        self.gaps += g
        self.c += len(tops) - 1 + after
        return g

    def put(self, kind, col, row, **props):
        self.ents.append(ent(kind, col, row, **props))

    def mid(self, kind, gap, dy=0, **props):
        """una entidad en el centro del hueco `gap` (dy filas más abajo)"""
        c, top, h = gap
        self.put(kind, c, top + (h - 1) // 2 + dy, **props)

    def cage(self, col, row, min_charge, gift, legacy=None):
        self.cages.append((ent('cage', col, row, minCharge=min_charge, gift=gift), legacy))

    def launcher(self, col, row=9):
        e, m = launcher(col, row)
        self.ents.append(e)
        self.mounts.append(m)

    def entities(self):
        """la lista final: las jaulas heredadas en su índice de siempre (1 = el primero), lo demás en orden"""
        rest = list(self.ents)
        fixed = {idx: e for e, idx in self.cages if idx}
        new = [e for e, idx in self.cages if not idx]
        out = []
        n = len(rest) + len(fixed)
        for i in range(1, n + 1):
            if i in fixed:
                out.append(fixed[i])
            else:
                assert rest, ('no hay entidades bastantes para poner la jaula heredada en su índice', i)
                out.append(rest.pop(0))
        return out + new

    def write(self, name, title, title_en, speed):
        cols = [g[0] for g in self.gaps]
        assert len(cols) == len(set(cols)), ('dos huecos en la misma columna', sorted(c for c in cols if cols.count(c) > 1))
        width = max(cols) + 14
        ents = self.entities()
        flappy_lib.write(out(name), title, title_en, width, self.gaps, speed=speed, entities=ents,
                         solids=self.solids, air=self.air, mounts=self.mounts, background=BG)
        kinds = {}
        for e in ents:
            kinds[e['type']] = kinds.get(e['type'], 0) + 1
        hs = [h for _, top, h in self.gaps if top != 2 or h < 10]
        print('  %s: %d columnas, ~%.0f s a %d px/s, huecos de %d-%d, %s' % (
            name, width, (width - 20) * 64 / speed, speed, min(hs), max(hs),
            ', '.join('%s %d' % kv for kv in sorted(kinds.items()))))


# ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# 1 «LOS PILARES»: la entrada de la campaña. Huecos de 4 que pasan a 3, a 200 px/s.
s = Course()
# A bienvenida: 5 pilares cada 8, alturas tranquilas; dos cargas y la jaula fácil de siempre (fila 3, justo encima)
a = s.pillars(8, [(4, 4), (5, 4), (4, 4), (3, 4), (4, 4)])
s.mid('flapcharge', a[1]); s.mid('flapcharge', a[3])
s.cage(a[2][0] + 4, 3, 1, 'shield', legacy=8)
# B escalera: cada 6, el hueco sube de 2 en 2 hasta arriba del todo, baja hasta abajo y vuelve a subir
b = s.pillars(6, [(6, 4), (4, 4), (2, 4), (2, 4), (4, 4), (6, 4), (7, 4), (5, 4), (3, 4)])
s.mid('flapcharge', b[2]); s.mid('apple', b[4]); s.mid('flapcharge', b[6])
# C el primer pasillo: 12 columnas de pilar seguidas, hueco de 4 que ondula (una carga dentro)
s.skip(2)
c = s.corridor([5, 5, 4, 4, 3, 3, 3, 4, 5, 6, 6, 6], 4, after=7)
s.mid('flapcharge', c[6])
# D el nido: una jaula COLGADA del pilar, en la fila 2 encima de un hueco bajo; se abre disparando desde la parte de
#   arriba del hueco anterior (la ráfaga atraviesa los pilares) y luego hay que bajar
d = s.pillars(6, [(3, 4), (3, 4), (6, 4)])
s.mid('flapcharge', d[0])
s.cage(d[2][0], 2, 1, 'small')
# E huecos de 3: cada 7, saltos de 2-3 filas
s.skip(2)
e = s.pillars(7, [(5, 3), (3, 3), (6, 3), (4, 3), (2, 3), (5, 3), (7, 3), (4, 3)])
s.mid('flapcharge', e[1]); s.mid('apple', e[3]); s.mid('flapcharge', e[4]); s.mid('flapcharge', e[6])
# F la zambullida: dos pilares con el hueco abajo y, entre ellos, una jaula en la fila 10, junto al borde de abajo
#   (caerse quita 1); pide 2 de carga
f = s.pillars(6, [(7, 3), (7, 3)])
s.cage(f[0][0] + 3, 10, 2, 'heart')
# G el zigzag final: cada 5, arriba / abajo con huecos de 4; comida al salir
s.skip(2)
g = s.pillars(5, [(2, 4), (6, 4), (2, 4), (6, 4), (3, 4)])
s.put('apple', g[-1][0] + 4, 5)
s.write('valle_pilares_1', "Valle de los Pilares 1", "Valley of the Pillars 1", 200)


# ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# 2 «GRIETAS Y CORNISAS»: huecos de 3, a 210 px/s; muros, jaulas y la primera ruta partida.
s = Course()
# A calentamiento: cada 7; dos cargas
a = s.pillars(7, [(4, 4), (2, 3), (5, 3), (3, 3), (6, 3)])
s.mid('flapcharge', a[0]); s.mid('flapcharge', a[3])
# B grietas: la jaula a la vista (fila 2, carga 2) y la GALERÍA: un túnel de 4 filas (suelo de piedra en la 5) tras un
#   muro de carga 2; DENTRO, primero una carga y luego la jaula (carga 1): la ráfaga que rompe el muro lo gasta todo, y
#   la carga para la jaula solo se coge después (antes, un escondite de una casilla con la carga delante: el usuario
#   rompió el muro y se quedó sin carga para la jaula). Debajo, la ruta de los huecos
b = s.pillars(7, [(3, 3), (5, 3), (3, 3)])          # (el 3º, alto: desde su hueco se entra en la galería)
s.mid('flapcharge', b[0])
s.cage(b[0][0] + 4, 2, 2, 'heart', legacy=11)
s.mid('flapcharge', b[1]); s.mid('flapcharge', b[2])
G0 = b[2][0] + 4
G1 = G0 + 12
under = s.at([(G0 + 4, 7, 3), (G0 + 10, 8, 3)])
ge, gs, ga = tunnel(G0, G1, under, min_charge=2, floor=5)
s.ents += ge; s.solids += gs; s.air += ga
s.put('flapcharge', G0 + 2, 3)
s.cage(G0 + 8, 2, 1, 'magnet_points', legacy=10)
s.put('flapcharge', G1 - 1, 3)
s.c = G1 + 5
# C el cañón: 20 columnas de pasillo de 3 que serpentea (cuestas de una fila cada dos o tres columnas)
s.skip(2)
c = s.corridor([5, 5, 4, 4, 3, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 6, 5, 5, 4, 4], 3)
s.mid('flapcharge', c[5])
s.put('apple', s.c - 2, 5)
# D pilares DOBLES: dos pilares con dos columnas entre ellos y el segundo hueco movido 1 fila (corregir rápido)
s.skip(2)
d = s.at([(s.c, 3, 3), (s.c + 3, 4, 3), (s.c + 10, 6, 3), (s.c + 13, 5, 3),
          (s.c + 20, 2, 3), (s.c + 23, 3, 3), (s.c + 30, 6, 3), (s.c + 33, 7, 3)])
s.mid('flapcharge', d[5])
s.skip(7)
# E la cornisa: un suelo de piedra en la fila 5 parte la pantalla. Abajo, la ruta segura (huecos de 3); arriba, una ruta
#   de 4 filas libres (sin estalactitas: tocar la piedra quita 1) que lleva dos cargas y una jaula
L0 = s.c + 2
low = [(L0 + 2, 7, 3), (L0 + 8, 8, 3), (L0 + 14, 7, 3), (L0 + 20, 8, 3), (L0 + 26, 7, 3)]
s.at(low)
L1 = L0 + 26
ls, la = ledge(L0, L1, low, 5)
s.solids += ls; s.air += la
s.put('flapcharge', L0 + 7, 2); s.put('flapcharge', L0 + 19, 2)
s.cage(L0 + 25, 2, 2, 'ghost')
s.mid('flapcharge', low[2])
s.c = L1 + 6
# F ritmo: cada 5, de arriba abajo (saltos de 3-4 filas en 4 columnas)
f = s.pillars(5, [(3, 3), (6, 3), (3, 3), (7, 3), (4, 3), (7, 3), (3, 3), (6, 3)])
s.mid('flapcharge', f[3]); s.mid('apple', f[6])
# G la bajada pegada: un pilar cada 4, el hueco baja fila a fila y vuelve a subir
s.skip(1)
g = s.pillars(4, [(2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (6, 3), (4, 3), (2, 3)])
# H el segundo cañón: 21 columnas, baja despacio desde el techo y vuelve a subir
s.skip(2)
h = s.corridor([2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 5, 5, 5, 4, 4, 4], 3)
s.mid('flapcharge', h[13])
# I final: cada 6, saltos grandes
i = s.pillars(6, [(4, 3), (7, 3), (3, 3), (6, 3), (4, 3)])
s.put('apple', i[-1][0] + 4, 5)
s.write('valle_pilares_2', "Valle de los Pilares 2", "Valley of the Pillars 2", 210)


# ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# 3 «LA MÁQUINA DEL MALVADO»: huecos de 3 y agujas de 2, a 225 px/s; lanzarredes de todas las maneras.
s = Course()
# A calentamiento: cada 6
a = s.pillars(6, [(4, 3), (3, 3), (5, 3), (2, 3), (4, 3)])
s.mid('flapcharge', a[1]); s.mid('flapcharge', a[3])
# B el primer lanzarredes, con la ruta por encima
b = s.pillars(6, [(3, 3), (2, 3), (4, 3)])
s.launcher(b[0][0] + 3)
s.mid('flapcharge', b[1])
s.put('apple', b[2][0] + 3, 5)
# C el atajo: un túnel arriba tras un muro (carga 2) por encima de DOS lanzarredes (sus redes se quedan en su suelo);
#   por debajo, la ruta de los huecos
s.skip(2)
c = s.pillars(7, [(3, 3), (7, 3), (8, 3), (7, 3), (5, 3)])     # (el 1º, alto: desde su hueco se entra en el túnel)
T0, T1 = c[0][0] + 3, c[4][0] - 3
te, ts, ta = tunnel(T0, T1, c, min_charge=2, floor=5)       # (4 filas libres: se vuela; con 2, imposible)
s.ents += te; s.solids += ts; s.air += ta
s.launcher(c[1][0] + 3, 10); s.launcher(c[3][0] + 3, 10)
s.put('flapcharge', T0 + 6, 2); s.put('flapcharge', T0 + 15, 3)
s.mid('flapcharge', c[2])
# D agujas: huecos de 2 (de una columna) entre huecos de 3
d = s.pillars(6, [(4, 3), (5, 2), (3, 3), (4, 2), (6, 3), (5, 2)])
s.mid('flapcharge', d[2])
s.put('apple', d[-1][0] + 3, 5)
# E la batería: tres lanzarredes seguidos bajo la ruta; con carga se puede bajar a la fila 9 y reventar uno. Al final,
#   una jaula colgada del último pilar en la fila 10, junto al soporte del 3er lanzarredes: bajar entre él y el pilar
e = s.pillars(6, [(5, 3), (4, 3), (5, 3), (4, 3)])
for k in range(3):
    s.launcher(e[k][0] + 3)
s.mid('flapcharge', e[0]); s.mid('flapcharge', e[1])
s.cage(e[3][0], 10, 1, 'shield')
# F la cornisa del Malvado: piedra en la fila 5. Abajo, huecos de 3 con dos lanzarredes (fila 10; las redes paran en
#   la piedra); arriba, sin redes pero con estalactitas de una fila (filas 2-4 libres: 130 px para el centro del
#   monstruo, un aleteo sube 75) y una carga
s.skip(2)
L0 = s.c
low = [(L0 + 2, 7, 3), (L0 + 8, 7, 3), (L0 + 14, 8, 3), (L0 + 20, 7, 3), (L0 + 26, 7, 3)]
stal = [(L0 + 5, 2, 10), (L0 + 11, 2, 10), (L0 + 17, 2, 10), (L0 + 23, 2, 10)]
s.at(low + stal)
ls, la = ledge(L0, L0 + 26, low + stal, 5)
s.solids += ls; s.air += la
s.launcher(L0 + 5, 10); s.launcher(L0 + 17, 10)
s.put('flapcharge', L0 + 14, 2)
s.mid('apple', low[3])
s.c = L0 + 34
# G el pasillo vigilado: un pasillo de 3 que baja y sube despacio y un lanzarredes a la salida
p = s.corridor([3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 5, 5, 5, 4, 4, 4], 3)
s.mid('flapcharge', p[7])
s.launcher(p[-1][0] + 3)
s.put('flapcharge', p[-1][0] + 4, 4)
# H la jaula alta de siempre (fila 1, carga 3, fuerza) entre dos pilares; cargas antes
s.skip(0)
hh = s.pillars(7, [(2, 3), (5, 3), (3, 3)])
s.mid('flapcharge', hh[0])
s.cage(hh[0][0] + 3, 1, 3, 'strength', legacy=15)
# I la serpiente: pasillo de 4 con cuestas de una fila por columna (dos seguidas como mucho)
s.skip(1)
q = s.corridor([3, 4, 5, 5, 6, 7, 7, 6, 5, 5, 4, 3, 3, 4, 5], 4)
s.mid('flapcharge', q[6])
# K la escalera de agujas: cada 5, huecos de 2 y de 3 alternos que bajan y suben; una jaula colgada del pilar más
#   bajo, en la fila 3 (subir, disparar y bajar a la fila 8 en 4 columnas)
k = s.pillars(5, [(2, 3), (4, 2), (6, 3), (8, 2), (6, 3), (4, 2), (2, 3)])
s.mid('flapcharge', k[1]); s.mid('flapcharge', k[2])
s.cage(k[3][0], 3, 2, 'magnet_all')
s.skip(1)
# J el final: agujas y lanzarredes entre ellas
j = s.at([(s.c, 4, 3), (s.c + 5, 7, 3), (s.c + 11, 3, 3), (s.c + 16, 6, 2), (s.c + 22, 3, 3), (s.c + 27, 5, 2),
          (s.c + 32, 3, 2), (s.c + 37, 5, 3)])
s.launcher(j[1][0] + 3); s.launcher(j[3][0] + 3)
s.mid('apple', j[2])
s.write('valle_pilares_3', "Valle de los Pilares 3", "Valley of the Pillars 3", 225)
