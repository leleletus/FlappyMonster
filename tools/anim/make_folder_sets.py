#!/usr/bin/env python3
# tools/anim/make_folder_sets.py — un conjunto de animación por CARPETA de imágenes sueltas (el jugador, el mortero,
# los objetos, los tiles, las piezas de los jefes…): un cuadro por imagen con "key" = su archivo. El juego carga
# esas imágenes con Anim.image(ruta), que pasa por este conjunto: cambiarle la imagen a un cuadro en el editor
# (`love . --anim`) cambia lo que se ve en el juego. Las secuencias son solo para VERLAS juntas (`all`, y una por
# cada grupo numerado: monstrito1..5 → `monstrito`): qué cuadro se usa y cuándo lo decide el código.
# No toca las carpetas que ya tienen un conjunto propio (crabbies, gummy…) ni las tiras (tienen el suyo).
# Nunca pisa uno que ya existe (--force). Desde la raíz del repo: python3 tools/anim/make_folder_sets.py
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import write, REPO, path_of
import subprocess

# Solo imágenes que están en git (los dibujos a medio hacer del usuario no se tocan), y fuera las carpetas cuyas
# imágenes ya salen por las VARIANTES de otro conjunto (los Gummies de cada isla: enemies/gummy)
TRACKED = set(subprocess.check_output(['git', '-C', REPO, 'ls-files', 'assets/images']).decode().split('\n'))
SKIP = re.compile(r'^enemies/gummy_')

force = '--force' in sys.argv
ROOT = os.path.join(REPO, 'assets', 'images')
made = 0
for d, _, files in sorted(os.walk(ROOT)):
    rel = os.path.relpath(d, ROOT).replace(os.sep, '/')
    pngs = sorted(f for f in files if f.endswith('.png') and 'assets/images/%s/%s' % (rel, f) in TRACKED)
    if SKIP.match(rel): continue
    # (fuera las tiras: ya tienen su conjunto, con el nombre de la imagen)
    pngs = [f for f in pngs if not os.path.exists(path_of(rel + '/' + f[:-4]))]
    if not pngs or rel == '.':
        continue
    frames = [{'image': 'assets/images/%s/%s' % (rel, f), 'key': f} for f in pngs]
    anims = {'all': {'frames': list(range(1, len(pngs) + 1)), 'fps': 3, 'loop': True}}
    groups = {}
    for i, f in enumerate(pngs):
        m = re.match(r'^(.*?)[_-]?(\d+)\.png$', f)
        if m and m.group(1): groups.setdefault(m.group(1), []).append(i + 1)
    for name, idx in groups.items():
        if len(idx) >= 2 and name not in anims: anims[name] = {'frames': idx, 'fps': 6, 'loop': True}
    doc = {'id': rel, 'scale': 4, 'origin': [0.5, 1], 'fallback': 'all', 'meta': {'code': True, 'folder': True},
           'frames': frames, 'anims': anims}
    made += write(doc, force)
print('conjuntos de carpeta nuevos:', made)
