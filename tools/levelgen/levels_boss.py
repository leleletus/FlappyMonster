"""Niveles de carrera con jefe: un tramo largo de plataformas + una arena de jefe ya probada
(copiada de los niveles originales) + la meta. Los niveles con jefe son solo de Carrera."""
import json
import os
from lib import *

LEVELS_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels')


def load_src(name):
    with open(os.path.join(LEVELS_DIR, name), encoding='utf-8') as f:
        return json.load(f)


def _shift_props(props, dx):
    out = json.loads(json.dumps(props))
    if 'corner' in out:
        out['corner']['col'] += dx
    if isinstance(out.get('patrol'), dict):
        out['patrol']['left'] += dx
        out['patrol']['right'] += dx
    for wp in out.get('waypoints', []) or []:
        wp['col'] += dx
    for key in ('points',):
        for wp in out.get(key, []) or []:
            wp['col'] += dx
    return out


def graft(L, src, c0, x0):
    """Copia las columnas c0..ancho del nivel `src` (misma altura) a partir de la columna x0 de L.
    Devuelve dx (desplazamiento de columnas)."""
    assert src['height'] == L.h, 'la altura debe coincidir'
    dx = x0 - c0
    for c in range(c0, src['width'] + 1):
        for r in range(1, L.h + 1):
            L.set(c + dx, r, src['tiles'][r - 1][c - 1])
    for e in src['entities']:
        if e['col'] < c0:
            continue
        ne = json.loads(json.dumps(e))
        ne['col'] += dx
        if 'props' in ne:
            ne['props'] = _shift_props(ne['props'], dx)
        L.entities.append(ne)
    for z in src.get('bossZones', []):
        nz = dict(z)
        nz['col'] += dx
        L.boss_zones.append(nz)
    for d in src.get('foliage', []):
        if d['col'] >= c0:
            nd = dict(d)
            nd['col'] += dx
            L.foliage.append(nd)
    return dx


def resize_width(L, new_w):
    """Ajusta el ancho del nivel (rellena con aire y coloca el borde derecho)."""
    for row in L.g:
        row.extend([EMPTY] * (new_w - len(row)))
    L.w = new_w
    for r in range(1, L.h + 1):
        L.set(new_w, r, BORDER)


def _floor(L, c0, c1, top=14):
    L.rect(c0, top, c1, L.h - 1, SOLID)


def ruta_del_espejo():
    """Tramo de entrenamiento (túnel de gateo, morteros, techo con pinchos) y el Duelo del Espejo."""
    src = load_src('jefe_espejo.json')
    L = Level('Ruta del Espejo', 134, 15, (4, 13), music='classic')
    G = 14
    _floor(L, 2, 133, G)
    # tramo 1: llano con enemigos
    L.walker('gummy', 9, G - 1, 6, 12)
    L.ent('mortar', 15, G - 1, range=9, delayMin=3, delayMax=5)
    L.walker('crabby', 20, G - 1, 17, 24)
    # foso corto de pinchos con plataforma
    L.rect(26, G, 29, G, EMPTY)
    L.spikes(26, 29, G, UP)
    L.plat(26, 29, 11, DROP)
    L.ent('star', 27, 9)
    L.ent('checkpoint', 32, G - 1)
    # muro con túnel de gateo (salto agachado) y estrella premio
    L.rect(37, 2, 38, G - 2, SOLID)
    L.ent('star', 37, G - 1)
    L.walker('gummy', 42, G - 1, 40, 46)
    # pasillo de techo con pinchos que caen
    L.rect(48, 2, 62, 9, SOLID)
    for c in (50, 53, 56, 59, 61):
        L.ent('spikefall', c, 10, sub=1 + c % 2, detectRange=5)
    L.ent('mortar', 55, G - 1, range=9, sides='left')
    L.walker('crabby', 52, G - 1, 49, 58)
    # escaleras arriba y abajo
    L.rect(66, G - 1, 70, G - 1, SOLID)
    L.rect(68, G - 2, 70, G - 2, SOLID)
    L.walker('gummy', 74, G - 1, 71, 77)
    L.ent('checkpoint', 77, G - 1)
    L.ent('extralife', 69, G - 4)
    # arena del espejo (copiada del nivel original): la zona empieza en la columna 86
    graft(L, src, 12, 82)
    return L


def fortaleza_malvada():
    """Fortaleza flotante: trampolines, plataformas sobre pinchos y la Nave Malvada al final."""
    src = load_src('MiniBossArena.json')
    L = Level('Fortaleza Malvada', 121, 15, (4, 13), music='flying_machine')
    G = 14
    _floor(L, 2, 120, G)
    L.walker('gummy', 10, G - 1, 6, 14)
    L.ent('trampoline', 18, G - 1)
    L.plat(20, 26, 6, SLAB)
    L.ent('star', 23, 4)
    L.walker('crabby', 23, 5, 20, 26)
    # foso ancho de pinchos con plataformas de rebote
    for c in range(30, 52):
        L.set(c, G, EMPTY)
    L.spikes(30, 51, G, UP)
    for i, c in enumerate((31, 37, 43, 49)):
        L.plat(c, c + 2, 11 - (i % 2) * 2, SLAB)
    L.ent('trampoline', 38, 10)
    L.walker('gummy', 44, 8, 43, 45)
    L.ent('checkpoint', 54, G - 1)
    # piso rompible con almacén secreto (ground pound)
    L.rect(58, G - 3, 66, G - 3, SOLID)
    L.rect(58, G - 2, 66, G - 2, EMPTY)
    L.rect(60, G - 3, 64, G - 3, BREAK)
    L.walker('crabby', 62, G - 1, 58, 66)
    L.rect(58, G - 2, 58, G - 1, SOLID)
    L.rect(66, G - 2, 66, G - 1, SOLID)
    L.ent('extralife', 62, G - 2) if False else None
    L.plat(60, 64, G - 6, DROP)
    L.ent('star', 62, G - 7)
    # subida y bajada
    L.rect(70, G - 1, 72, G - 1, SOLID)
    L.rect(72, G - 2, 74, G - 2, SOLID)
    L.walker('crabby', 78, G - 1, 75, 82)
    L.ent('mortar', 84, G - 1, range=10, delayMin=3, delayMax=5)
    L.ent('checkpoint', 88, G - 1)
    # arena de la nave (la zona empieza en la columna 93)
    graft(L, src, 8, 89)
    return L


def guarida_cangrejo_rey():
    """Guarida de cangrejos: paredes que trepan, bloques rompibles y el Mega Crabby al final."""
    src = load_src('jefe_cangrejo.json')
    L = Level('Guarida del Cangrejo Rey', 122, 15, (4, 13), music='hidro_city')
    G = 14
    _floor(L, 2, 121, G)
    L.walker('crabby', 12, G - 1, 8, 16)
    L.ent('crabby', 22, G - 1, wallWalk=True, patrol=False, speed=60)
    # columnas con cangrejos trepadores
    L.rect(26, G - 2, 27, G - 1, SOLID)
    L.ent('crabby', 28, G - 1, wallWalk=True, patrol=False, speed=60)
    L.plat(30, 34, 10, DROP)
    L.walker('gummy', 32, 9, 30, 34)
    L.ent('star', 32, 7)
    L.ent('checkpoint', 38, G - 1)
    # foso de pinchos con plataformas
    for c in range(42, 56):
        L.set(c, G, EMPTY)
    L.spikes(42, 55, G, UP)
    for i, c in enumerate((43, 47, 51)):
        L.plat(c, c + 2, 11, SLAB)
    L.walker('crabby', 48, 10, 47, 49)
    # sala de bloques rompibles: se baja pisando (ground pound)
    L.terrain(56, 72, G - 2)
    L.rect(62, G - 2, 66, G - 2, BREAK)
    L.walker('gummy', 59, G - 3, 57, 61)
    L.walker('crabby', 69, G - 3, 67, 72, wallWalk=True) if False else None
    L.ent('extralife', 64, G - 4)
    L.ent('checkpoint', 72, G - 3)
    L.terrain(73, 83, G)
    L.walker('gummy', 77, G - 1, 74, 81)
    # arena del Mega Crabby (la zona empieza en la columna 92)
    graft(L, src, 6, 84)
    return L


BUILDERS = [ruta_del_espejo, fortaleza_malvada, guarida_cangrejo_rey]
