"""Genera los niveles nuevos en assets/levels/. Uso: python3 tools/levelgen/build.py [--show]"""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
import levels_run
mods = [levels_run]
for name in ('levels_koth', 'levels_boss'):
    try:
        mods.append(__import__(name))
    except ImportError:
        pass
out = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels')
for m in mods:
    for b in m.BUILDERS:
        L = b()
        fn = re.sub(r'\W+', '_', b.__name__)
        w = L.check()
        if w: print(b.__name__, 'AVISOS:', *w, sep='\n  ')
        if '--show' in sys.argv and (len(sys.argv) < 3 or sys.argv[-1] == b.__name__ or sys.argv[-1] == '--show'):
            print(L.name); print(L.ascii())
        open(os.path.join(out, fn + '.json'), 'w', encoding='utf-8').write(L.to_json())
        print('escrito', fn + '.json')
