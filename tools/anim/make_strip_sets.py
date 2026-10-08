#!/usr/bin/env python3
# tools/anim/make_strip_sets.py — mete cada TIRA que carga el juego con SpriteStrip (decoraciones, bombas, jefes,
# efectos, interfaz…) en el CONJUNTO DE ANIMACIÓN DE SU CARPETA (assets/anim/<carpeta>.json), como una animación con
# nombre: la tira bomb-fuse-Sheet.png → animación «bomb-fuse» del conjunto enemies/bomb, marcada con "sheet" (el
# archivo) y "frameW" (el ancho de cuadro que pide el código). Así cada cosa del juego tiene UN conjunto con todas
# sus animaciones, que se ven y se editan en `love . --anim`, y SpriteStrip.load las lee de ahí.
#
# Las tiras salen de una CAPTURA: el juego apunta las que carga sin animación, y a qué velocidad las reproduce el
# código, cuando se ejecuta con
#   FM_ANIM_CAPTURE=/tmp/tiras.tsv tools/tests/run.sh all        (y level_shots de los niveles, para las decoraciones)
# y luego:   python3 tools/anim/make_strip_sets.py /tmp/tiras.tsv
# No toca una animación que ya existe (puede estar retocada en el editor); solo le apunta "codeFps" (la velocidad
# del código) la primera vez que se captura, y entonces la animación empieza a esa velocidad.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import write, read, REPO

strips, speeds = {}, {}
for f in [a for a in sys.argv[1:] if not a.startswith('--')]:
    for line in open(f, encoding='utf-8'):
        p = line.rstrip('\n').split('\t')
        if p[0] == '@fps' and len(p) == 4: speeds[p[1]] = (float(p[2]), p[3] != '0')
        elif len(p) == 4: strips[p[0]] = (int(float(p[1])), int(float(p[2])), int(float(p[3])))
added = timed = 0
for path in sorted(set(strips) | set(speeds)):
    if not path.startswith('assets/images/') or not os.path.exists(os.path.join(REPO, path)): continue
    rel = path[len('assets/images/'):]
    sid, file = os.path.dirname(rel), os.path.basename(rel)
    if not sid: continue
    doc = read(sid) or {'id': sid, 'scale': 4, 'origin': [0.5, 1], 'frames': [], 'anims': {}}
    anims = doc.setdefault('anims', {})
    name = next((n for n, a in anims.items() if a.get('sheet') == file), None)
    changed = False
    if name is None and path in strips:
        fw, w, h = strips[path]
        n = max(1, w // fw)
        base = file[:-4]
        name = base[:-6] if base.endswith('-Sheet') and len(base) > 6 else base
        while name in anims: name += '_tira'
        first = len(doc['frames'])
        doc['frames'] += [{'image': path, 'x': i * fw, 'y': 0, 'w': fw, 'h': h} for i in range(n)]
        anims[name] = {'frames': list(range(first + 1, first + n + 1)), 'fps': 8, 'loop': True, 'sheet': file, 'frameW': fw}
        doc.setdefault('fallback', name)
        added += 1; changed = True
    if name is not None and path in speeds and 'codeFps' not in anims[name]:
        fps, loop = speeds[path]
        fps = int(fps) if fps == int(fps) else fps
        anims[name].update({'codeFps': fps, 'fps': fps, 'loop': loop})
        timed += 1; changed = True
    if changed: write(doc, True)
print('tiras nuevas: %d · con la velocidad del código apuntada: %d' % (added, timed))
