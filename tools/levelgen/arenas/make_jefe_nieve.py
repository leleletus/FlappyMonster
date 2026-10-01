#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_nieve.py → jefe_nieve.json (arena de la Gran Bola de Nieve)
#   python3 tools/levelgen/arenas/make_jefe_nieve.py            # la arena de prueba
#   python3 tools/levelgen/arenas/make_jefe_nieve.py --lago     # + la pone en lago_helado
#                                                                 (solo sus columnas 72-103:
#                                                                 el resto del nivel no se toca)
#
# LA PISTA DE HIELO (zona: columnas 12-28, filas 3-12; suelo en la 13). Todo se lee a la vista
# y cada pieza hace SIEMPRE lo mismo:
#
#   ║▓                ╳(A)                ▓║    A   = Activador de la COMPUERTA (flotando)
#   ║▓▓▓▓[a]        ┄┄┄┄┄┄┄        [a]▓▓▓▓║    [a] = Activador de un CONGELADOR, encima de
#   ║=====          (aire)          =====║          cada plataforma (= plataformas traspasables)
#   C>                  ▌                  <C   C   = CONGELADORES en las paredes: su chorro
#   ║■            ▌▌  ▌▌ ▌                ■║          barre la pista a media altura (la bola
#   ║iiiii tt i | i tt iiiii║                     sí, un jugador de pie no; saltando, sí)
#                                                ▌   = COMPUERTA (Bloques ON, 2 de alto)
#                                                ■   = escalón para subir a las plataformas
#                                                tt  = LAGO: hielo fino sobre agua helada
#
#  1. COMPUERTA: el Activador A la sube. Si la bola rueda contra ella → se marea (pisotón 1 /
#     ground pound 2) y la compuerta se abre con el golpe (hay que volver a subirla). Subida
#     también corta la pista: escudo contra los rodamientos y corta el chorro de los Congeladores.
#  2. CONGELADORES: cada [a] dispara el de su pared por la mitad de la pista: si la bola está
#     ahí → congelada (pisotón 1 / ground pound 3). Al jugador en el suelo no le da si está de
#     pie; desde la plataforma se dispara sin riesgo.
#  3. LAGO: los saltos de la bola agrietan el hielo fino (2 estados por aterrizaje; el gran
#     golpe lo rompe de una); un jugador encima también lo gasta. Si la bola cae al agua, se
#     congela (como con un Congelador) y al salir vuelve a helar el lago.
#  4. FASES: 2 = se hincha, rebota en las paredes, bolas-bomba (se le devuelven de una patada)
#     y gran golpe (olas + carámbanos; puede caer sobre una plataforma: la sombra avisa);
#     3 = avalancha (rueda 6 s rebotando: la compuerta la para) y ENTIERRA los Activadores en
#     nieve prensada (un ground pound encima atraviesa la nieve y pulsa el Activador). Al
#     cambiar de fase vuelve a helar el lago.
# Entrada por la repisa izquierda, que sigue en la plataforma (fila 10); salida por la derecha.
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))


def enc(i): return i % 16 + (i // 16) * 2 ** 17


EMPTY, SOLID, BORDER, WATER, DROP, FINISH = 0, 1, 4, 9, 10, 11
SW_OFF, SB_ON_X, SNOW, ICE, THIN = 14, 19, 29, 30, 31
W, H = 40, 15
Z0, Z1 = 12, 28                     # columnas de la zona
FLOOR = 13
GATE = 20                           # columna de la compuerta (centro)
LAKES = (17, 18, 22, 23)            # hielo fino sobre agua
ACT = (GATE, 8)                     # Activador de la compuerta (flotando)
ACT_L, ACT_R = (16, 9), (24, 9)     # Activadores de los congeladores (sobre las plataformas)


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    # repisas de entrada (izquierda) y salida (derecha), a la altura de las plataformas
    for c in list(range(2, Z0)) + list(range(Z1 + 1, W)):
        for r in range(10, H): put(c, r, SNOW)
    # pista: hielo (resbala); el lago = hielo fino sobre agua
    for c in range(Z0, Z1 + 1):
        put(c, FLOOR, ICE); put(c, FLOOR + 1, SNOW)
    for c in LAKES:
        put(c, FLOOR, THIN); put(c, FLOOR + 1, WATER)
    # escalones junto a las paredes (para subir a las plataformas)
    put(Z0, 12, SNOW); put(Z1, 12, SNOW)
    # plataformas traspasables a 3 casillas del suelo (la bola pasa por debajo, también hinchada)
    for c in list(range(Z0, Z0 + 5)) + list(range(Z1 - 4, Z1 + 1)): put(c, 10, DROP)
    # Activadores (todos APAGADOS: compuerta bajada al empezar)
    put(*ACT_L, SW_OFF); put(*ACT_R, SW_OFF); put(*ACT, SW_OFF)
    # compuerta: Bloques ON de 2 de alto en el centro (inactivos al empezar)
    put(GATE, 11, SB_ON_X); put(GATE, 12, SB_ON_X)
    put(37, 9, FINISH)
    # los Congeladores van en la pared, a media altura de la pista
    put(Z0 - 1, 11, EMPTY); put(Z1 + 1, 11, EMPTY)
    cryo = {'mode': 'switch', 'range': 8, 'windup': 0.6, 'burst': 0.8, 'freezeTime': 3}
    ents = [
        {'type': 'snowboss', 'col': 25, 'row': 12},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 3, 'props': {'corner': {'col': Z0 - 1, 'row': 9}, 'zone': 1, 'material': 'snow'}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': 3, 'props': {'corner': {'col': Z1 + 3, 'row': 9}, 'zone': 1, 'material': 'snow'}},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 2, 'props': {'corner': {'col': Z1 + 3, 'row': 2}, 'zone': 1, 'material': 'snow'}},
        {'type': 'cryo', 'col': Z0 - 1, 'row': 11, 'props': dict(cryo, id=1, dir='right')},
        {'type': 'cryo', 'col': Z1 + 1, 'row': 11, 'props': dict(cryo, id=2, dir='left')},
    ]
    return {
        'name': 'Jefe: Gran Bola de Nieve', 'name_en': 'Boss: Big Snowball',
        'width': W, 'height': H, 'playerStart': [4, 9],
        'tiles': t, 'entities': ents,
        'foliage': [{'type': 'icicle', 'col': c, 'row': 3} for c in (14, 18, 22, 26)],
        'vents': [],
        'links': [{'col': ACT_L[0], 'row': ACT_L[1], 'to': 1}, {'col': ACT_R[0], 'row': ACT_R[1], 'to': 2}],
        'blockLinks': [{'col': GATE, 'row': r, 'from': [ACT[0], ACT[1]]} for r in (11, 12)],
        'bossZones': [{'id': 1, 'col': Z0, 'row': 3, 'w': Z1 - Z0 + 1, 'h': 10, 'music': 'winter_nes'}],
        'background': 'snow', 'time': 'dusk', 'snow': True,
    }


# ── Escritura con el formato del editor (una fila de tiles por línea) ──────────────
def j(x): return json.dumps(x, separators=(',', ':'), ensure_ascii=False, sort_keys=True)


def write(d, path):
    out = ['{']
    keys = list(d.keys())
    for i, k in enumerate(keys):
        v = d[k]
        end = ',' if i < len(keys) - 1 else ''
        if k == 'tiles' or (isinstance(v, list) and v and isinstance(v[0], (dict, list))):
            out.append('  "%s": [' % k)
            out += ['    %s%s' % (j(x), ',' if n < len(v) - 1 else '') for n, x in enumerate(v)]
            out.append('  ]' + end)
        else:
            out.append('  "%s": %s%s' % (k, j(v), end))
    out.append('}')
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')


# ── Injerto en lago_helado: sus columnas 72..103 = las 9..40 de la arena ───────────
def patch_lago(arena):
    path = os.path.join(ROOT, 'assets', 'levels', 'lago_helado.json')
    with open(path, encoding='utf-8') as f:
        d = json.load(f)
    c0, x0 = 9, 72                     # arena → nivel
    dx = x0 - c0
    assert d['height'] == arena['height'] and d['width'] == x0 + (arena['width'] - c0)
    for r in range(d['height']):
        for c in range(c0, arena['width'] + 1):
            d['tiles'][r][c + dx - 1] = arena['tiles'][r][c - 1]

    def shifted(e):
        e = json.loads(json.dumps(e))
        e['col'] += dx
        p = e.get('props', {})
        if 'corner' in p: p['corner']['col'] += dx
        if 'from' in e: e['from'][0] += dx
        return e

    keep = lambda lst: [e for e in lst if e['col'] < x0]
    d['entities'] = keep(d['entities']) + [shifted(e) for e in arena['entities'] if e['col'] >= c0]
    d['foliage'] = keep(d.get('foliage', [])) + [shifted(e) for e in arena['foliage'] if e['col'] >= c0]
    d['links'] = keep(d.get('links', [])) + [shifted(e) for e in arena['links']]
    d['blockLinks'] = keep(d.get('blockLinks', [])) + [shifted(e) for e in arena['blockLinks']]
    d['bossZones'] = [dict(z, col=z['col'] + dx) for z in arena['bossZones']]
    if 'subtiles' in d: d['subtiles'] = keep(d['subtiles'])
    write(d, path)
    print(path)


if __name__ == '__main__':
    arena = build()
    out = os.path.join(HERE, 'jefe_nieve.json')
    write(arena, out)
    print(out)
    if '--lago' in sys.argv:
        patch_lago(arena)
