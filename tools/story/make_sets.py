#!/usr/bin/env python3
# tools/story/make_sets.py
# DECORADOS de las cinemáticas de la historia: son NIVELES de verdad (mismos bloques, decoraciones, fondo y luz
# que cualquier nivel; se abren en el editor: love . --editor assets/story/sets/crater.json), que la película
# dibuja con el motor del juego (src/story/Stage.lua). No se juegan ni salen en ninguna lista.
#   crater.json   el interior del volcán, donde está el ESPEJO: suelo de ceniza sobre basalto, dos charcas de
#                 lava, un pedestal para el espejo y una chimenea arriba a la izquierda (por donde entra y sale)
#   python3 tools/story/make_sets.py
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'assets', 'story', 'sets')
EMPTY, LAVA, BORDER = 0, 3, 4
BASALT, ASH = 262150, 262151          # (ids 38 y 39: la parte alta va en los bits 17+, src/world/tiles/TileCodec.lua)


def crater():
    W, H = 22, 13
    g = [[EMPTY] * W for _ in range(H)]

    def rect(c0, r0, c1, r1, v):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                g[r - 1][c - 1] = v

    rect(1, 1, W, 2, BASALT)                       # techo
    rect(4, 1, 8, 2, EMPTY)                        # la chimenea del cráter
    rect(1, 1, 1, H, BASALT); rect(W, 1, W, H, BASALT)
    rect(2, 3, 2, 5, BASALT); rect(W - 1, 3, W - 1, 6, BASALT); rect(W - 2, 3, W - 2, 4, BASALT)   # paredes irregulares
    rect(1, 11, W, H, BASALT)                      # suelo
    rect(5, 11, 18, 11, ASH)                       # ceniza arriba
    rect(2, 11, 4, 11, LAVA); rect(19, 11, W - 1, 11, LAVA)        # charcas de lava a los lados
    rect(14, 10, 16, 10, ASH)                      # pedestal del espejo (centro: columna 15)
    fol = [
        {'col': 3, 'row': 3, 'type': 'lava_fall'},
        {'col': 20, 'row': 5, 'type': 'lava_fall'},
        {'col': 10, 'row': 3, 'type': 'stalactite', 'props': {'layer': 'back'}},
        {'col': 12, 'row': 3, 'type': 'stalactite', 'props': {'layer': 'back', 'flip': True}},
        {'col': 18, 'row': 3, 'type': 'stalactite', 'props': {'layer': 'back'}},
        {'col': 6, 'row': 10, 'sub': 3, 'type': 'basalt_pebbles', 'props': {'layer': 'back'}},
        {'col': 11, 'row': 10, 'sub': 4, 'type': 'ash_pile', 'props': {'layer': 'back'}},
        {'col': 12, 'row': 10, 'sub': 3, 'type': 'glow_rock', 'props': {'layer': 'back'}},
        {'col': 18, 'row': 10, 'sub': 3, 'type': 'glow_rock', 'props': {'layer': 'back', 'flip': True}},
        {'col': 17, 'row': 10, 'sub': 4, 'type': 'basalt_pebbles', 'props': {'layer': 'back'}},
        {'col': 5, 'row': 10, 'type': 'basalt_rock', 'props': {'layer': 'back'}},
    ]
    return {'name': 'Cráter del Espejo (decorado)', 'name_en': 'Mirror Crater (set)', 'width': W, 'height': H,
            'playerStart': [8, 10], 'background': 'volcano', 'time': 'dusk', 'depth': 'magma', 'surfaceRow': 1,
            'light': 'cave', 'echo': False, 'modes': [], 'tiles': g, 'entities': [], 'foliage': fol, 'vents': []}


def write(name, d):
    os.makedirs(OUT, exist_ok=True)
    rows = ',\n'.join('    ' + json.dumps(r) for r in d['tiles'])
    head = {k: v for k, v in d.items() if k != 'tiles'}
    txt = json.dumps(head, ensure_ascii=False, indent=2)
    txt = txt[:-2] + ',\n  "tiles": [\n' + rows + '\n  ]\n}\n'
    open(os.path.join(OUT, name), 'w').write(txt)
    print('  assets/story/sets/' + name)


if __name__ == '__main__':
    write('crater.json', crater())
