#!/usr/bin/env python3
# tools/levelgen/levels_flappy_valle_boss.py
# La etapa del JEFE del Valle de los Pilares (zona 1 de la campaña Flappy, src/flappy/Zones.lua `boss`; Plan 5,
# docs/design/flappy-plan-5-netcopter.md): ~40 columnas de pilares al ritmo del Valle (unas cargas y una comida), la
# ARENA del Redcóptero (flappy_lib.boss_arena: una pantalla, la cámara se para en ella, dos pilares cortos para
# cubrirse) y ~8 columnas hasta la meta. Escribe SOLO assets/levels/valle_redcoptero.json (el id va en las partidas:
# nunca se renombra). El SUELO va en la última fila (solo césped: floor=H), una fila más abajo que en el resto del
# Valle, para que quepan el jugador y la máquina (el usuario, 2026-11-08: "bajar el suelo, está muy arriba y estorba").
#   python3 tools/levelgen/levels_flappy_valle_boss.py
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flappy_lib

# Pilares: huecos de 4 cada 7 columnas, alturas suaves (el Valle)
gaps, col = [], 18
for t in [4, 5, 3, 6, 4, 5, 4]:
    gaps.append((col, t, 4)); col += 7
ents = []
for i in [0, 2, 4]:                      # cargas en el centro del hueco
    c, top, h = gaps[i]
    ents.append(flappy_lib.ent('flapcharge', c, top + (h - 1) // 2))
c, top, h = gaps[3]                      # la comida (el aspecto de la zona: 'auto')
ents.append(flappy_lib.ent('apple', c, top + (h - 1) // 2))

# La arena: empieza 6 columnas después del último pilar; un pilar corto colgando del techo (filas 1-2) y otro de 3
# desde el suelo (filas 8-10)
a0 = col - 7 + 6
arena = flappy_lib.boss_arena(a0, 'netcopter', stubs=[(4, 3, 8), (9, 1, 7)])
width = a0 + 20 + 9                      # 8 columnas después de la zona hasta la meta (columna width - 2)
flappy_lib.write('assets/levels/valle_redcoptero.json', "El Redcóptero", "The Net-Copter", width, gaps,
                 entities=ents, arena=arena, floor=flappy_lib.H)
