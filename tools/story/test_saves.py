#!/usr/bin/env python3
# tools/story/test_saves.py
# PARTIDAS DE PRUEBA del modo historia: escribe huecos de partida (storyN.sav, src/story/Save.lua) ya avanzados, para
# probar algo sin jugar todo el juego. Lee el orden de los mundos de src/story/Worlds.lua.
#   python3 tools/story/test_saves.py <hueco>=<nivel> [<hueco>=<nivel> ...] [--dir CARPETA] [--diff normal]
# El monstruo queda EN ese nivel, ya superado, con todo lo anterior superado (y los fragmentos de los jefes vencidos);
# el nodo siguiente, abierto. Las cinemáticas de antes de un nivel (Worlds films) quedan SIN ver. Qué fragmento da
# cada nivel: Shards.LEVEL (src/story/Shards.lua).
#   p. ej. 2=lluvia_pinchos  → anda al nodo siguiente: la película de la persecución y "La Huida del Espejo"
#          3=huida_del_espejo → al siguiente: la película de la guarida y el jefe Espejo
# Por defecto en la carpeta de guardado del juego (~/.local/share/love/FlappyMonster). OJO: SOBRESCRIBE esos huecos.
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORLDS = os.path.join(HERE, '..', '..', 'src', 'story', 'Worlds.lua')
SHARDS = os.path.join(HERE, '..', '..', 'src', 'story', 'Shards.lua')


def shard_levels():
    src = open(SHARDS, encoding='utf-8').read()
    body = re.search(r'Shards\.LEVEL = \{([^}]*)\}', src).group(1)
    return {k: int(v) for k, v in re.findall(r'(\w+) = (\d+)', body)}


def worlds():
    src = open(WORLDS, encoding='utf-8').read()
    out = []
    for m in re.finditer(r"\{\s*id = '(\w+)',\s*levels = \{([^}]*)\},\s*boss = '(\w+)'", src):
        out.append({'id': m.group(1), 'levels': re.findall(r"'(\w+)'", m.group(2)), 'boss': m.group(3)})
    return out


def lua(v, ind=''):
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, str): return '"%s"' % v.replace('\\', '\\\\').replace('"', '\\"')
    pad = ind + '  '
    keys = sorted(v, key=str)
    body = ',\n'.join('%s[%s] = %s' % (pad, k if isinstance(k, int) else '"%s"' % k, lua(v[k], pad)) for k in keys)
    return '{\n' + body + ('\n' if body else '') + ind + '}'


def make(level, diff):
    W = worlds()
    done, best, shards, reward = {}, {}, {}, {}
    xtra = diff == 'xtra'
    SL = shard_levels()

    def clear(n):
        done[n] = True
        best[n] = {'grade': 'B', 'rating': 75, 'score': 300}
        if n in SL:
            for s in ([f'{SL[n]}a', f'{SL[n]}b'] if xtra else [str(SL[n])]): shards[s] = True

    for w, wd in enumerate(W, 1):
        nodes = wd['levels'] + [wd['boss']]
        if level not in nodes:
            for n in nodes: clear(n)
            reward[w] = 'B'
            continue
        k = nodes.index(level)
        for n in nodes[:k + 1]: clear(n)
        return {'version': 1, 'difficulty': diff, 'world': w, 'node': k + 1, 'lives': 5, 'done': done, 'best': best,
                'playTime': 0, 'gameOvers': 0, 'points': 0, 'worldReward': reward, 'bonus': {}, 'shards': shards,
                'films': {}}
    sys.exit('nivel desconocido: ' + level)


if __name__ == '__main__':
    args, out, diff = [], os.path.expanduser('~/.local/share/love/FlappyMonster'), 'normal'
    it = iter(sys.argv[1:])
    for a in it:
        if a == '--dir': out = next(it)
        elif a == '--diff': diff = next(it)
        elif '=' in a: args.append(a.split('=', 1))
        else: sys.exit(__doc__ or 'uso: test_saves.py <hueco>=<nivel> ...')
    if not args: sys.exit('uso: python3 tools/story/test_saves.py 2=lluvia_pinchos 3=huida_del_espejo')
    for slot, level in args:
        if slot not in ('1', '2', '3'): sys.exit('hueco 1, 2 o 3')
        path = os.path.join(out, f'story{slot}.sav')
        open(path, 'w').write('return ' + lua(make(level, diff)) + '\n')
        print(f'  {path}: en {level}')
