"""Genera niveles en assets/levels/ desde código.

    python3 tools/levelgen/build.py --only nombre [nombre...]   # SOLO esos niveles
    python3 tools/levelgen/build.py [--show [nombre]]           # TODOS (ver aviso)

AVISO: sin --only se reescriben TODOS los niveles generados, y se pierde lo que
se haya retocado a mano en el editor (el usuario los retoca). Úsalo con --only.
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
import levels_run
mods = [levels_run]
for name in ('levels_hunt', 'levels_koth', 'levels_boss', 'levels_water', 'levels_batch2'):
    try:
        mods.append(__import__(name))
    except ImportError:
        pass
only = None
if '--only' in sys.argv:
    only = set()
    for a in sys.argv[sys.argv.index('--only') + 1:]:
        if a.startswith('--'): break
        only.add(a)
out = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels')
if '--out' in sys.argv:                 # (otra carpeta: p. ej. la variante resuelta, OPEN=1, para level_solve)
    out = sys.argv[sys.argv.index('--out') + 1]
    os.makedirs(out, exist_ok=True)
for m in mods:
    for b in m.BUILDERS:
        fn = re.sub(r'\W+', '_', b.__name__)
        if only is not None and fn not in only:
            continue
        L = b()
        w = L.check()
        if w: print(b.__name__, 'AVISOS:', *w, sep='\n  ')
        if '--show' in sys.argv and (len(sys.argv) < 3 or sys.argv[-1] == b.__name__ or sys.argv[-1] == '--show'):
            print(L.name); print(L.ascii())
        open(os.path.join(out, fn + '.json'), 'w', encoding='utf-8').write(L.to_json())
        print('escrito', fn + '.json')
