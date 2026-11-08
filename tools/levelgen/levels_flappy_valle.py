#!/usr/bin/env python3
# tools/levelgen/levels_flappy_valle.py
# Las dos etapas PROVISIONALES del Valle de los Pilares (zona 1 de la campaña Flappy, src/flappy/Zones.lua; Plan 3 de
# docs/design/flappy-plan-3-campaign-frame.md): sirven para jugar el marco de la campaña (partidas, mapa, vidas,
# resultados) y, desde el Plan 4, cargas, una jaula, un muro y comida (flappy_lib.populate). El Plan 5 las rehace con el arte y el diseño de verdad MANTENIENDO los ids (los nombres de archivo van
# en las partidas: nunca se renombran). Escribe SOLO esos dos archivos (lo común: flappy_lib.py).
#   python3 tools/levelgen/levels_flappy_valle.py
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flappy_lib

# 1: huecos de 4, pilares cada 7 columnas, alturas suaves
g1, col = [], 20
for t in [4, 5, 4, 3, 5, 6, 4, 5, 3, 4, 5, 4]:
    g1.append((col, t, 4)); col += 7
flappy_lib.write('assets/levels/valle_pilares_1.json', "Valle de los Pilares 1", "Valley of the Pillars 1", col + 10, g1,
                 entities=flappy_lib.populate(g1, charges=[0, 2, 4, 6, 8], food=[5, 10], cage=(3, 2), wall=7))

# 2: empieza con huecos de 4 y pasa a 3, pilares más juntos y saltos de altura más grandes
g2, col = [], 20
for t in [4, 6, 3, 5, 2]:
    g2.append((col, t, 4)); col += 6
for t in [6, 3, 5, 2, 6, 4, 2, 5, 3, 6]:
    g2.append((col, t, 3)); col += 6
flappy_lib.write('assets/levels/valle_pilares_2.json', "Valle de los Pilares 2", "Valley of the Pillars 2", col + 10, g2,
                 entities=flappy_lib.populate(g2, charges=[0, 1, 3, 5, 7, 9], food=[6, 12], cage=(4, 3), wall=10))
