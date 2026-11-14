"""Escribe un conjunto de animación (assets/anim/*.json) con el MISMO formato que el editor de animaciones: una clave
por línea, un cuadro / animación / variante por línea (así un cambio pequeño da un diff pequeño)."""
import json


def dumps(d):
    j = lambda x: json.dumps(x, ensure_ascii=False)
    out = ['{']
    keys = list(d.keys())
    for i, k in enumerate(keys):
        v = d[k]
        comma = ',' if i < len(keys) - 1 else ''
        if k == 'frames':
            out.append('  "frames": [')
            out += ['    %s%s' % (j(f), ',' if n < len(v) - 1 else '') for n, f in enumerate(v)]
            out.append('  ]' + comma)
        elif k in ('anims', 'variants') and isinstance(v, dict):
            out.append('  %s: {' % j(k))
            ks = sorted(v)
            out += ['    %s: %s%s' % (j(a), j(v[a]), ',' if n < len(ks) - 1 else '') for n, a in enumerate(ks)]
            out.append('  }' + comma)
        else:
            out.append('  %s: %s%s' % (j(k), j(v), comma))
    out.append('}')
    return '\n'.join(out) + '\n'


def write(path, d):
    with open(path, 'w', encoding='utf-8') as f: f.write(dumps(d))
