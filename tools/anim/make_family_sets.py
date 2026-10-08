#!/usr/bin/env python3
# tools/anim/make_family_sets.py — conjuntos de animación de las familias que usan UNA IMAGEN POR CUADRO:
#   · los CRABBIES (enemies/crabby, crabby_ice, crabby_fortress, crabby_river, crabby_cave, crabby_lava):
#     walk, hide, unhide, hidden, peek, meat, dead — los lee src/world/entities/types/enemies/crabby.lua
#   · el GUMMY y el SALTARÍN ya tienen los suyos (enemies/gummy, enemies/hopper)
# Nunca pisa uno que ya existe (--force). Desde la raíz del repo: python3 tools/anim/make_family_sets.py
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import write, REPO

force = '--force' in sys.argv
E = 'assets/images/enemies/'
# skin → (carpeta, archivo de "meat", cuadros de hundirse)
CRABS = {'crabby': ('crabby', 'MeatCrabby.png', 0), 'crabby_fortress': ('crabby_fortress', 'meat.png', 0),
         'crabby_ice': ('crabby_ice', 'meat.png', 8), 'crabby_river': ('crabby_river', 'meat.png', 5),
         'crabby_cave': ('crabby_cave', 'meat.png', 6), 'crabby_lava': ('crabby_lava', 'meat.png', 6)}
n = 0
for sid, (folder, meat, sink) in CRABS.items():
    d = E + folder + '/'
    names = ['crab1.png', 'crab2.png', 'crab3.png', 'dead.png', 'hid.png', 'lookin.png', meat] + ['sink%d.png' % i for i in range(1, sink + 1)]
    for f in names: assert os.path.exists(os.path.join(REPO, d + f)), d + f
    frames = [{'image': d + f} for f in names]
    frames[4]['inset'] = 1                                   # (escondido: la tapa apoya en la superficie)
    for i in range(sink): frames[7 + i]['inset'] = i         # (al hundirse, filas vacías arriba del cuadro)
    CRAB2, DEAD, HID, LOOK, MEAT = 2, 4, 5, 6, 7
    sinks = list(range(8, 8 + sink))
    hide = (sinks + [HID]) if sink else [MEAT, LOOK, HID]
    unhide = (sinks[::-1] + [CRAB2]) if sink else [LOOK, MEAT, CRAB2]
    doc = {
        'id': 'enemies/' + sid, 'scale': 4, 'origin': [0.5, 1], 'fallback': 'walk',
        'meta': {'wholeImages': True, 'usedBy': 'src/world/entities/types/enemies/crabby.lua'},
        'frames': frames,
        'anims': {
            'walk': {'frames': [1, 2, 3], 'fps': 5, 'loop': True},
            'hide': {'frames': hide, 'fps': round(len(hide) / 0.75, 9), 'loop': False},
            'unhide': {'frames': unhide, 'fps': round(len(hide) / 0.75, 9), 'loop': False},
            'hidden': {'frames': [HID], 'fps': 5, 'loop': True},
            'peek': {'frames': [LOOK], 'fps': 5, 'loop': True},
            'meat': {'frames': [MEAT], 'fps': 5, 'loop': True},
            'dead': {'frames': [DEAD], 'fps': 5, 'loop': False},
        },
    }
    n += write(doc, force)
print('conjuntos de familia nuevos:', n)
