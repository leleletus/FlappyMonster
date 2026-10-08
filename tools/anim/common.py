"""Escritura de conjuntos de animación (assets/anim/<id>.json) con el mismo formato legible que el editor."""
import json, os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ORDER = ['id', 'label', 'strip', 'timing', 'scale', 'origin', 'fallback', 'meta', 'frames', 'anims', 'variants']


def inline(v):
    return json.dumps(v, ensure_ascii=False, sort_keys=True, separators=(', ', ': '))


def dump(doc):
    keys = [k for k in ORDER if k in doc] + sorted(k for k in doc if k not in ORDER)
    out = ['{']
    for i, k in enumerate(keys):
        v, comma = doc[k], ',' if i < len(keys) - 1 else ''
        if isinstance(v, list) and v and isinstance(v[0], dict):
            out.append('  %s: [' % json.dumps(k))
            out += ['    ' + inline(x) + (',' if j < len(v) - 1 else '') for j, x in enumerate(v)]
            out.append('  ]' + comma)
        elif isinstance(v, dict) and v:
            out.append('  %s: {' % json.dumps(k))
            ks = sorted(v)
            out += ['    %s: %s%s' % (json.dumps(n), inline(v[n]), ',' if j < len(ks) - 1 else '') for j, n in enumerate(ks)]
            out.append('  }' + comma)
        else:
            out.append('  %s: %s%s' % (json.dumps(k), inline(v), comma))
    out.append('}')
    return '\n'.join(out) + '\n'


def path_of(set_id):
    return os.path.join(REPO, 'assets', 'anim', set_id + '.json')


def write(doc, force=False):
    """Escribe el conjunto. NUNCA pisa uno que ya existe (puede estar retocado en el editor) salvo force."""
    p = path_of(doc['id'])
    if os.path.exists(p) and not force:
        return False
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w', encoding='utf-8').write(dump(doc))
    return True


def read(set_id):
    p = path_of(set_id)
    return json.load(open(p, encoding='utf-8')) if os.path.exists(p) else None
