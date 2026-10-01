#!/usr/bin/env python3
# tools/levelgen/arenas/make_jefe_nieve.py → jefe_nieve.json (arena de la Gran Bola de Nieve)
#   python3 tools/levelgen/arenas/make_jefe_nieve.py            # la arena de prueba
#   python3 tools/levelgen/arenas/make_jefe_nieve.py --lago     # + la pone en lago_helado
#                                                                 (solo sus columnas 72 en adelante,
#                                                                 ensanchándolo si hace falta: el
#                                                                 resto del nivel no se toca)
#
# LA PISTA DE HIELO (zona: columnas 12-35, filas 3-12; suelo de hielo en la 13). Cada pieza
# hace SIEMPRE lo mismo y se ve venir:
#
#   ║  v  [C]  v   v  v  [C]  v  ║       v   = CARÁMBANOS (salen en la fase 2), sobre las
#   ║          ====             ║             plataformas: un aterrizaje de la bola a < 2.5
#   ║       ====  ====          ║             casillas los hace caer
#   ║====                   ====║       =   = plataformas traspasables (a 3, 5 y 7 del suelo)
#   ║■                         ■║       [C] = CONGELADORES (fase 3): bajan del techo encima
#   ║iiiitttiAiiiiiiAitttiiii║                de cada bolsa y disparan hacia abajo
#                                         ■   = escalón (y pared): la bola rodando se estampa
#                                            ttt = hielo fino sobre agua (se rehace solo)
#                                            A   = Activadores del suelo (fase 3; antes, hielo):
#                                                  cada uno dispara el Congelador de su bolsa
#
#  Fase 1 (grande): rueda → se estampa contra la pared/escalón → MAREADA (pisotón 1 / GP 2).
#  Fase 2 (mediana): salta a las plataformas cerca del jugador; atráela bajo un carámbano.
#  Fase 3 (pequeña): gran golpe que rompe el hielo fino: si cae al agua, EMPAPADA; empapada
#  + su Congelador (golpea el Activador) = CONGELADA (GP 3).
# Entrada por la repisa izquierda (a la altura de las plataformas); salida por la derecha.
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))


def enc(i): return i % 16 + (i // 16) * 2 ** 17


EMPTY, SOLID, BORDER, WATER, DROP, FINISH = 0, 1, 4, 9, 10, 11
SW_OFF, SNOW, ICE, THIN = 14, 29, 30, 31
W, H = 50, 15
Z0, Z1 = 12, 35                     # columnas de la zona
FLOOR = 13
POCKETS = ((16, 17, 18), (29, 30, 31))   # hielo fino sobre agua (al descubierto: el gran golpe llega)
SWITCHES = ((20, FLOOR), (27, FLOOR))    # Activadores del suelo (fase 3), uno por bolsa
FREEZERS = ((17, 3), (30, 3))            # encima de cada bolsa, disparan hacia abajo
ICICLES = (14, 20, 24, 27, 33)           # columnas de los carámbanos (sobre las plataformas)


def build():
    t = [[EMPTY] * W for _ in range(H)]

    def put(c, r, v): t[r - 1][c - 1] = enc(v)

    for c in range(1, W + 1): put(c, 1, BORDER); put(c, H, BORDER)
    for r in range(1, H + 1): put(1, r, BORDER); put(W, r, BORDER)
    # repisas de entrada (izquierda) y salida (derecha), a la altura de las plataformas
    for c in list(range(2, Z0)) + list(range(Z1 + 1, W)):
        for r in range(10, H): put(c, r, SNOW)
    # pista: hielo (resbala) sobre nieve; las bolsas = hielo fino sobre agua
    for c in range(Z0, Z1 + 1):
        put(c, FLOOR, ICE); put(c, FLOOR + 1, SNOW)
    for pk in POCKETS:
        for c in pk:
            put(c, FLOOR, THIN); put(c, FLOOR + 1, WATER)
    # escalones junto a las paredes (subir a las plataformas; la bola se estampa en ellos)
    put(Z0, 12, SNOW); put(Z1, 12, SNOW)
    # plataformas traspasables: laterales (fila 10), medias (8) y la de arriba (6)
    for c in list(range(Z0, Z0 + 4)) + list(range(Z1 - 3, Z1 + 1)): put(c, 10, DROP)
    for c in list(range(19, 23)) + list(range(25, 29)): put(c, 8, DROP)
    for c in range(22, 26): put(c, 6, DROP)
    # Activadores del suelo (ocultos hasta la fase 3 por los bloques de fase)
    for sw in SWITCHES: put(*sw, SW_OFF)
    put(46, 9, FINISH)
    cryo = {'mode': 'switch', 'dir': 'down', 'range': 11, 'windup': 0.5, 'burst': 0.9, 'freezeTime': 3,
            'phase': 3}
    ents = [
        {'type': 'snowboss', 'col': 25, 'row': 12,
         'props': {'icicles': [{'col': c, 'row': 3} for c in ICICLES]}},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 3, 'props': {'corner': {'col': Z0 - 1, 'row': 9}, 'zone': 1, 'material': 'snow'}},
        {'type': 'bosswall', 'col': Z1 + 1, 'row': 3, 'props': {'corner': {'col': Z1 + 3, 'row': 9}, 'zone': 1, 'material': 'snow'}},
        {'type': 'bosswall', 'col': Z0 - 3, 'row': 2, 'props': {'corner': {'col': Z1 + 3, 'row': 2}, 'zone': 1, 'material': 'snow'}},
    ]
    for i, (c, r) in enumerate(FREEZERS):
        ents.append({'type': 'cryo', 'col': c, 'row': r, 'props': dict(cryo, id=11 + i)})
    for c, r in SWITCHES:
        ents.append({'type': 'phaseblock', 'col': c, 'row': r,
                     'props': {'corner': {'col': c, 'row': r}, 'phase': 3, 'hiddenAs': 'ice'}})
    return {
        'name': 'Jefe: Gran Bola de Nieve', 'name_en': 'Boss: Big Snowball',
        'width': W, 'height': H, 'playerStart': [4, 9],
        'tiles': t, 'entities': ents,
        'foliage': [],
        'vents': [],
        'links': [{'col': c, 'row': r, 'to': 11 + i} for i, (c, r) in enumerate(SWITCHES)],
        'blockLinks': [],
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


# ── Injerto en lago_helado: sus columnas 72.. = las 9.. de la arena ────────────────
def patch_lago(arena):
    path = os.path.join(ROOT, 'assets', 'levels', 'lago_helado.json')
    with open(path, encoding='utf-8') as f:
        d = json.load(f)
    c0, x0 = 9, 72                     # arena → nivel
    dx = x0 - c0
    assert d['height'] == arena['height']
    need = x0 + (arena['width'] - c0)
    if d['width'] < need:                  # (la arena creció: se ensancha el nivel por la derecha)
        for row in d['tiles']: row.extend([0] * (need - d['width']))
        d['width'] = need
    assert d['width'] == need
    for r in range(d['height']):
        for c in range(c0, arena['width'] + 1):
            d['tiles'][r][c + dx - 1] = arena['tiles'][r][c - 1]

    def shifted(e):
        e = json.loads(json.dumps(e))
        e['col'] += dx
        p = e.get('props', {})
        if 'corner' in p: p['corner']['col'] += dx
        for v in p.values():               # (listas de celdas: los carámbanos del jefe...)
            if isinstance(v, list):
                for q in v:
                    if isinstance(q, dict) and 'col' in q: q['col'] += dx
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
