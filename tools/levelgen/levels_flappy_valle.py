#!/usr/bin/env python3
# tools/levelgen/levels_flappy_valle.py
# Las TRES etapas del Valle de los Pilares (zona 1 de la campaña Flappy, src/flappy/Zones.lua; Plan 5b de
# docs/design/flappy-plan-5b-valley.md), con el fondo `valley` (src/fx/Sky.lua). Los ids se guardan en las partidas:
# nunca se renombran. Escribe SOLO valle_pilares_1/2/3.json (lo común: flappy_lib.py; el jefe, levels_flappy_valle_boss.py).
#   1 la entrada suave: huecos anchos (4-5), alturas tranquilas, 5 cargas, 2 comidas, una jaula fácil, sin muros
#   2 jaulas y muros: huecos de 3-4, una jaula a la vista y otra detrás de un muro agrietado (carga 2), 2 comidas
#   3 la primera máquina del Malvado: huecos de 3-4, tres LANZARREDES en el suelo bajo la ruta (siempre con sitio a los
#     lados para esperar la red), una jaula muy arriba, 2 comidas y un ATAJO: un túnel arriba tras un muro agrietado que
#     pasa por encima del segundo lanzarredes (su suelo para las redes)
# La ruta principal (los huecos) nunca necesita romper un muro: el piloto sin carga de flappy_flight `etapa` las pasa.
#   python3 tools/levelgen/levels_flappy_valle.py
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flappy_lib
from flappy_lib import ent, at_gaps

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
BG = 'valley'


def out(name):
    return os.path.join(ROOT, 'assets', 'levels', name + '.json')


def pillars(first, step, spec):
    """spec = [(fila de arriba del hueco, alto), ...] → gaps de build() cada `step` columnas desde `first`"""
    return [(first + i * step, top, h) for i, (top, h) in enumerate(spec)]


# 1: huecos de 4-5 cada 8 columnas, alturas que cambian como mucho 1-2 filas
g1 = pillars(20, 8, [(4, 5), (3, 5), (4, 4), (5, 5), (4, 5), (3, 4), (4, 5), (5, 4), (4, 5), (3, 5), (4, 4), (5, 5),
                     (4, 5)])
e1 = (at_gaps('flapcharge', g1, [1, 3, 5, 7, 9]) + at_gaps('apple', g1, [4, 10])
      # la jaula fácil: carga 1, justo por encima de la ruta, poco después de la primera carga
      + [ent('cage', g1[2][0] + 4, 3, minCharge=1, gift='shield')])
flappy_lib.write(out('valle_pilares_1'), "Valle de los Pilares 1", "Valley of the Pillars 1", g1[-1][0] + 14, g1,
                 entities=e1, background=BG)

# 2: huecos de 4 que pasan a 3 cada 7 columnas, saltos de altura más grandes; una jaula a la vista (carga 2) y un
#    escondite arriba (muro de carga 2) con otra jaula (carga 1) detrás: hacen falta 3 cargas, hay 4 antes
g2 = pillars(20, 7, [(4, 4), (2, 4), (5, 4), (3, 4), (6, 3), (3, 3), (5, 3), (2, 3), (5, 3), (3, 4), (6, 3), (4, 3),
                     (2, 3), (5, 3), (3, 3), (5, 4)])
e2c, s2 = flappy_lib.cubby(g2[7][0] + 3, 'cage', min_charge=2, minCharge=1, gift='magnet_points')
e2 = (at_gaps('flapcharge', g2, [0, 2, 3, 5, 8, 10]) + at_gaps('apple', g2, [4, 12]) + e2c
      + [ent('cage', g2[11][0] + 3, 2, minCharge=2, gift='heart')])
flappy_lib.write(out('valle_pilares_2'), "Valle de los Pilares 2", "Valley of the Pillars 2", g2[-1][0] + 14, g2,
                 entities=e2, solids=s2, background=BG)

# 3: huecos de 3-4 cada 7 columnas. Lanzarredes en el suelo (fila 9) entre dos pilares, a 3 columnas de cada uno, con
#    la ruta pasando por ENCIMA (huecos que acaban en la fila 7 o antes). El túnel va de la columna 58 a la 80 (filas
#    1-2, muro en la 58): por debajo, los huecos empiezan en la fila 5 y el 2º lanzarredes dispara contra su suelo.
g3 = pillars(20, 7, [(4, 4), (3, 4), (2, 4), (4, 3), (3, 4), (4, 4), (5, 3), (6, 3), (5, 4), (2, 4), (5, 3), (4, 4),
                     (5, 3), (3, 4), (5, 3), (3, 4)])
T0, T1 = g3[5][0] + 3, g3[8][0] + 4                     # el túnel: 58 → 80
e3t, s3, a3 = flappy_lib.tunnel(T0, T1, g3, min_charge=2)
e3 = (at_gaps('flapcharge', g3, [0, 2, 4, 9, 11, 13]) + at_gaps('apple', g3, [3, 12]) + e3t
      + [ent('flapcharge', T0 + 6, 2), ent('flapcharge', T0 + 15, 1)]          # el premio del atajo
      + [ent('netlauncher', g3[1][0] + 3, 9),            # entre huecos altos: la ruta pasa 3-5 filas por encima
         ent('netlauncher', g3[7][0] + 3, 9),            # bajo el túnel: su red se queda en el suelo del túnel
         ent('netlauncher', g3[11][0] + 3, 9)]
      # la jaula muy arriba (carga 3), en la fila 1 entre dos pilares
      + [ent('cage', g3[10][0] + 3, 1, minCharge=3, gift='strength')])
flappy_lib.write(out('valle_pilares_3'), "Valle de los Pilares 3", "Valley of the Pillars 3", g3[-1][0] + 14, g3,
                 entities=e3, solids=s3, air=a3, background=BG)
