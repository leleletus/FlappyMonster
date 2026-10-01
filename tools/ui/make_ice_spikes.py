#!/usr/bin/env python3
# tools/ui/make_ice_spikes.py — pinchos de HIELO: la púa de los pinchos (assets/images/spikes/spike.png,
# acero) recoloreada a hielo con la misma paleta que la púa del Mega Crabby helado. La usan los
# pinchos de casilla y los pinchos que caen en los niveles con "spikeSkin": "ice"
# (src/world/SpikeSkins.lua; editor: Nivel → Fondo y clima → Pinchos).
#   python3 tools/ui/make_ice_spikes.py      → assets/images/spikes/spike_ice.png
import os
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SRC = os.path.join(ROOT, 'assets', 'images', 'spikes', 'spike.png')
DST = os.path.join(ROOT, 'assets', 'images', 'spikes', 'spike_ice.png')
ICE = {(255, 255, 255): (226, 246, 255), (242, 242, 246): (186, 226, 250),
       (196, 200, 214): (118, 172, 222), (30, 30, 42): (30, 30, 42)}

im = Image.open(SRC).convert('RGBA')
px = im.load()
for y in range(im.height):
    for x in range(im.width):
        p = px[x, y]
        if p[3]:
            assert p[:3] in ICE, p
            px[x, y] = ICE[p[:3]] + (p[3],)
im.save(DST)
print('escrito', DST)
