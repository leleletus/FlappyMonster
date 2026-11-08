#!/usr/bin/env python3
# tools/levelgen/levels_flappy_test.py
# La ETAPA DE PRUEBA del vuelo (paso 2 de docs/design/flappy-prequel.md): assets/levels/_flappy_vuelo.json, un nivel
# Flappy con cámara automática y PILARES cada pocas columnas: primero huecos de 4 casillas, luego de 3. Sirve para que
# el usuario juzgue cómo se siente volar; no es un nivel de la campaña. Oculto (empieza por '_'): se entra desde el
# menú de depuración. Escribe SOLO ese archivo (lo común: flappy_lib.py).
#   python3 tools/levelgen/levels_flappy_test.py
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flappy_lib

GAPS = []
col = 20
for t in [4, 5, 3, 6, 4, 2, 5, 6]:
    GAPS.append((col, t, 4)); col += 7
for t in [5, 3, 6, 4, 2, 6, 3, 5, 4, 6]:
    GAPS.append((col, t, 3)); col += 6
flappy_lib.write('assets/levels/_flappy_vuelo.json', "Vuelo de prueba", "Test flight", 150, GAPS)
