#!/usr/bin/env python3
# tools/levelgen/make_credits_sets.py
# Los ESCENARIOS DE LOS CRÉDITOS (docs/story/credits.md): una franja pequeña de cada isla (20 x 6 casillas) que la
# película de los créditos JUEGA de verdad debajo de su bloque de texto (src/story/LiveStage.lua: el motor del juego,
# sus enemigos, sus bombas y sus sonidos; el monstruo lo lleva un bot sencillo). Son niveles normales: se abren en el
# editor (love . --editor assets/story/sets/credits_pradera.json). No salen en ninguna lista ni se juegan.
#   Filas: 1-4 aire, 5 el suelo, 6 lo de debajo. El monstruo empieza a la izquierda (col 2) y cruza hacia la derecha.
#   python3 tools/levelgen/make_credits_sets.py
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'assets', 'story', 'sets')
W, H = 20, 6


def raw(tid):
    """El valor de una casilla con ese id (src/world/tiles/TileCodec.lua: los ids de 16 en adelante, en los bits 17+)"""
    return (tid // 16) * 2 ** 17 + tid % 16


EMPTY, SOLID, PLATFORM, LAVA, BORDER, WATER = 0, 1, 2, 3, 4, 9
BREAK, DIRT, GRASS, SNOW, ICE, THIN_ICE, SAND, DEEP, PSNOW, BASALT, ASH = 12, 16, 17, 29, 30, 31, 35, 36, 37, 38, 39


# decoraciones de colocación 'sub' (docs/reference/decorations-and-modes.md)
SUB = {'tall_grass', 'flower_patch', 'tulip', 'shell', 'starfish', 'clam', 'torch', 'bones', 'snow_pile', 'ice_crystal',
       'glow_mushroom', 'stalagmite_small', 'basalt_pebbles', 'glow_rock', 'lava_vent', 'dead_bush'}


class Strip:
    def __init__(self, top, under):
        self.g = [[EMPTY] * W for _ in range(H)]
        self.rect(1, 5, W, 5, top)
        self.rect(1, 6, W, 6, under)
        self.ents, self.fol = [], []

    def rect(self, c0, r0, c1, r1, tid):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.g[r - 1][c - 1] = raw(tid)

    def ent(self, t, col, row=4, **props):
        e = {'type': t, 'col': col, 'row': row}
        if props: e['props'] = props
        self.ents.append(e)

    def deco(self, t, col, row=4, sub=None, back=True, **props):
        d = {'col': col, 'row': row, 'type': t}
        # (las de subcelda van en una de abajo: sin `sub`, a la de arriba, y flotarían medio bloque)
        if sub is None and t in SUB: sub = 3 + col % 2
        if sub: d['sub'] = sub
        p = dict(props)
        if back: p['layer'] = 'back'
        if p: d['props'] = p
        self.fol.append(d)

    def level(self, name, background, time='day', music=None, boss=False):
        extra = {'bossZones': [{'id': 1, 'col': 1, 'row': 1, 'w': W, 'h': H}]} if boss else {}
        return {**extra, 'name': name + ' (créditos)', 'name_en': name + ' (credits)', 'width': W, 'height': H,
                'playerStart': [2, 4], 'background': background, 'time': time, 'light': 'day', 'echo': False,
                'modes': [], 'tiles': self.g, 'entities': self.ents, 'foliage': self.fol, 'vents': []}


def pradera():
    s = Strip(GRASS, DIRT)
    s.rect(8, 2, 10, 2, GRASS)                  # una repisa: el Gummy de arriba se cae
    s.ent('gummy', 9, 1, pauses=False)
    s.ent('gummy', 6)
    s.ent('star', 4, 3); s.ent('star', 5, 3)
    s.ent('bomb', 13, 4, speed=0, fuseTime=1.2)   # se enciende al pasar: la explosión se lleva a los dos Gummies
    s.ent('gummy', 15); s.ent('gummy', 16, pauses=False)
    s.rect(18, 4, 18, 4, BREAK)                 # y rompe el bloque
    for c, t in ((3, 'tall_grass'), (7, 'flower_patch'), (11, 'tulip'), (17, 'round_bush'), (19, 'tall_grass')):
        s.deco(t, c)
    return s.level('Pradera', 'meadow')


def costa():
    s = Strip(SAND, SAND)
    s.rect(9, 5, 13, 6, WATER)                  # una charca con un pez globo (la salta; si cae, nada)
    s.ent('pufferfish', 11, 6, area=[{'col': 9, 'row': 5}, {'col': 13, 'row': 5}, {'col': 13, 'row': 6}, {'col': 9, 'row': 6}])
    s.ent('crabby_river', 6)
    s.ent('trampoline', 15)                     # un trampolín que lo lanza alto
    s.ent('crabby_river', 18)
    s.ent('star', 15, 1)
    for c, t in ((3, 'palmtree'), (7, 'shell'), (14, 'starfish'), (17, 'tiki_torch'), (19, 'clam')):
        s.deco(t, c)
    return s.level('Costa', 'coast')


def fortaleza():
    s = Strip(SOLID, BORDER)
    s.ent('gummy_fortress', 5)
    s.ent('mortar', 17)                         # dispara al monstruo según se acerca
    s.rect(9, 4, 10, 4, BREAK)                  # dos bloques rompibles: un ground pound los rompe
    s.ent('crabby_fortress', 13)
    s.ent('bombobject', 12, 4, fuseTime=1.6)
    for c, t in ((3, 'torch'), (8, 'bones'), (15, 'torch'), (19, 'bones')):
        s.deco(t, c)
    return s.level('Fortaleza', 'fortress', 'dusk')


def nieve():
    s = Strip(SNOW, ICE)
    s.rect(9, 5, 11, 5, THIN_ICE)               # hielo fino sobre un hueco: se rompe y cae
    s.rect(9, 6, 11, 6, EMPTY)
    s.ent('gummy_ice', 6)
    s.ent('crabby_ice', 14)
    s.ent('gummy_ice', 17, pauses=False)
    s.ent('star', 10, 3)
    for c, t in ((3, 'snowy_pine'), (7, 'snow_pile'), (13, 'ice_crystal'), (16, 'snowman'), (19, 'frozen_bush')):
        s.deco(t, c)
    return s.level('Nieve', 'snow')


def cuevas():
    s = Strip(DEEP, DEEP)
    s.ent('gloomy', 7)
    s.ent('gummy_cave', 11)
    s.ent('bomb', 14, 4, speed=0, fuseTime=1.0)
    s.rect(15, 4, 16, 4, BREAK)                 # la bomba rompe los bloques... y al Crabby de detrás
    s.ent('crabby_cave', 18)
    for c, t in ((3, 'glow_mushroom'), (9, 'cave_crystals'), (12, 'stalagmite_small'), (19, 'glow_mushroom')):
        s.deco(t, c)
    return s.level('Cuevas', 'cave')


def volcan():
    s = Strip(ASH, BASALT)
    s.rect(9, 5, 10, 6, LAVA)                   # un charco de lava: lo salta (el Gummy de magma, no)
    s.ent('gummy_magma', 6)
    s.ent('crabby_lava', 13)
    s.ent('mortar', 18)
    s.ent('gummy_magma', 15, pauses=False)
    for c, t in ((3, 'charred_tree'), (7, 'basalt_pebbles'), (12, 'glow_rock'), (16, 'lava_vent'), (19, 'dead_bush')):
        s.deco(t, c)
    return s.level('Volcán', 'volcano', 'dusk')


def crab():
    s = Strip(SAND, SAND)
    s.ent('megacrabby', 14)                     # el Mega Crabby de verdad (pinzas y púa), sin pelea: pasea
    s.ent('crabby', 7); s.ent('crabbytramp', 10)
    for c, t in ((3, 'palmtree'), (18, 'palmtree'), (8, 'shell')):
        s.deco(t, c)
    return s.level('Mega Crabby', 'coast', boss=True)


def bola():
    s = Strip(SNOW, ICE)
    s.ent('megacrabby_ice', 14)                 # el Mega Crabby helado (pinzas y su tapa)
    s.ent('gummy_ice', 6); s.ent('crabby_ice_snow', 9)
    for c, t in ((3, 'snowy_pine'), (18, 'snowy_pine'), (11, 'snow_pile')):
        s.deco(t, c)
    return s.level('Mega Crabby helado', 'snow', boss=True)


SETS = {'pradera': pradera, 'costa': costa, 'fortaleza': fortaleza, 'nieve': nieve, 'cuevas': cuevas,
        'volcan': volcan, 'crab': crab, 'bola': bola}

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for k, fn in SETS.items():
        path = os.path.join(OUT, 'credits_%s.json' % k)
        with open(path, 'w') as f:
            json.dump(fn(), f, ensure_ascii=False, indent=1)
        print(os.path.relpath(path, os.path.join(HERE, '..', '..')))
