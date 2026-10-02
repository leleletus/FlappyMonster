"""Niveles de carrera con jefe: un tramo largo de plataformas + una arena de jefe ya probada
(copiada de los niveles originales) + la meta. Los niveles con jefe son solo de Carrera."""
import json
import os
from lib import *

# Arenas de los niveles de prueba originales (ya no son niveles del juego)
ARENAS_DIR = os.path.join(os.path.dirname(__file__), 'arenas')


def load_src(name):
    with open(os.path.join(ARENAS_DIR, name), encoding='utf-8') as f:
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
    for l in src.get('links', []):            # (Activadores → objetos conectados: congeladores...)
        nl = dict(l)
        nl['col'] += dx
        L.extra.setdefault('links', []).append(nl)
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


def _enc(i): return i % 16 + (i // 16) * 2 ** 17      # id de tile → valor de celda (TileCodec)


SNOW, ICE = _enc(29), _enc(30)


def lago_helado():
    """Lago helado: suelo de hielo que resbala, congeladores (para aprender a esquivar el
    chorro) y la Gran Bola de Nieve al final (arena jefe_nieve: compuertas + congeladores
    de los Activadores)."""
    src = load_src('jefe_nieve.json')
    L = Level('Lago Helado', 103, 15, (4, 9), music='classic')
    L.extra.update({'name_en': 'Frozen Lake', 'snow': True, 'background': 'snow', 'time': 'dusk'})
    G = 10
    L.rect(2, G, 71, 14, SNOW)
    # foso con pinchos
    L.rect(15, G, 17, 13, EMPTY)
    L.spikes(15, 17, 13, UP)
    # pista de hielo (resbala) y el primer congelador, de frente: hay que saltar el chorro
    L.rect(18, G, 30, G, ICE)
    L.walker('gummy', 23, G - 1, 19, 27)
    L.rect(31, G - 2, 34, G - 1, SNOW)
    L.set(31, G - 1, EMPTY)
    L.ent('cryo', 31, G - 1, dir='left', interval=3.5, firstDelay=1.5, range=9, freezeTime=2.5)
    L.ent('star', 33, G - 4)
    # llano con plataformas
    L.walker('crabby', 41, G - 1, 36, 46)
    L.plat(38, 42, G - 4, DROP)
    L.ent('star', 40, G - 5)
    L.ent('checkpoint', 47, G - 1)
    # foso de agua helada con islas de hielo
    L.rect(49, G, 56, 13, EMPTY)
    L.water(49, 12, 56, 13)
    for c in (50, 53, 56):
        L.set(c, G, ICE)
    L.walker('gummy', 53, G - 3, 51, 55, movement='fly')
    # lluvia: congelador colgado que dispara hacia abajo
    L.ent('cryo', 62, 4, dir='down', interval=3, firstDelay=0.5, range=6, freezeTime=2)
    L.walker('crabby', 65, G - 1, 58, 69)
    L.ent('extralife', 66, G - 4)
    L.plat(64, 68, G - 3, DROP)
    L.ent('checkpoint', 70, G - 1)
    # arena de la Gran Bola de Nieve (la zona empieza en la columna 75)
    graft(L, src, 9, 72)
    return L


THIN = _enc(31)


def glaciar_cangrejo():
    """Glaciar del Cangrejo: un glaciar con Crabbies helados de todas las tapas (montón de nieve,
    carámbano, púa de hielo, trampolín; en suelo, paredes y techo), hielo fino sobre agua y el
    Mega Crabby helado al final (arena jefe_cangrejo_helado: la del Mega con suelo de nieve)."""
    src = load_src('jefe_cangrejo_helado.json')
    L = Level('Glaciar del Cangrejo', 120, 15, (4, 12), music='labyrinth')
    L.extra.update({'name_en': 'Crab Glacier', 'snow': True, 'spikeSkin': 'ice'})
    G = 13
    L.rect(2, G, 81, 14, SNOW)
    # salida: un Crabby helado normal (púa de hielo) para empezar
    L.walker('crabby_ice', 10, G - 1, 7, 13)
    # hielo fino sobre agua: hay que cruzarlo sin pararse (se agrieta al estar encima)
    L.rect(15, G, 20, G, THIN)
    L.water(15, 14, 20, 14)
    L.ent('star', 18, G - 3)
    # pista de hielo con un montón de nieve en medio (¡no es una decoración!)
    L.rect(22, G, 31, G, ICE)
    L.walker('crabby_ice_snow', 27, G - 1, 24, 30, hideChance=0.9)
    L.plat(25, 29, G - 4, DROP)
    L.ent('star', 27, G - 5)
    L.ent('checkpoint', 33, G - 1)
    # foso de pinchos de hielo con losas; en la del medio, un Crabby con carámbano
    L.rect(36, G, 48, 14, EMPTY)
    L.spikes(36, 48, 14, UP)
    for c in (37, 41, 45):
        L.plat(c, c + 2, 10, SLAB)
    L.walker('crabby_ice_icicle', 42, 9, 41, 43, hideChance=0.6)
    # techo bajo con Crabbies que caen (carámbano / nieve) sobre quien pasa por debajo
    L.rect(50, 2, 61, 7, SNOW)
    L.ent('crabby_ice_icicle', 53, 8, attach='ceiling', dropOnSight=True, patrol={'left': 51, 'right': 55})
    L.ent('crabby_ice_snow', 58, 8, attach='ceiling', dropOnSight=True, patrol={'left': 56, 'right': 60})
    L.ent('extralife', 55, G - 4)
    L.plat(54, 56, G - 3, DROP)
    # columna de hielo con un trepador (tapa de púa) dándole la vuelta
    L.rect(65, G - 2, 67, G - 1, SNOW)
    L.ent('crabby_ice', 64, G - 1, wallWalk=True, patrol=False, speed=60)
    L.ent('star', 66, G - 5)
    # Crabby trampolín helado: su trampolín sube a la repisa del checkpoint
    L.walker('crabbytramp_ice', 71, G - 1, 69, 74)
    L.rect(76, G - 2, 80, G - 1, SNOW)
    L.ent('checkpoint', 78, G - 3)
    L.walker('gummy_ice', 73, G - 5, 70, 75, movement='fly')
    # arena del Mega Crabby helado (la zona empieza en la columna 89)
    graft(L, src, 6, 82)
    return L


def reino_gummy():
    """Reino Gummy: un prado lleno de Gummies de todas las clases (normales, con casco, voladores)
    — la guardia del rey — y el REY GUMMY al final (arena jefe_gummy: el salón del trono)."""
    src = load_src('jefe_gummy.json')
    L = Level('Reino Gummy', 122, 15, (4, 12), music='flying_machine')
    L.extra.update({'name_en': 'Gummy Kingdom'})
    G = 13
    L.rect(2, G, 80, 14, SOLID)
    # entrada: un Gummy normal para empezar
    L.walker('gummy', 10, G - 1, 7, 14)
    # escalón con un Gummy con casco encima (rebota: ground pound para romperle el casco)
    L.rect(18, G - 2, 22, G - 1, SOLID)
    L.walker('gummy', 20, G - 3, 18, 22, helmet=True)
    L.ent('star', 20, G - 6)
    # foso de pinchos con dos losas y un Gummy volador por encima
    L.rect(24, G, 31, G, EMPTY)
    L.spikes(24, 31, G, UP)
    L.plat(25, 26, G - 3, SLAB)
    L.plat(29, 30, G - 3, SLAB)
    L.walker('gummy', 27, G - 5, 24, 31, movement='fly')
    L.ent('checkpoint', 34, G - 1)
    # el pasillo de la guardia: normal, con casco y un volador sobre la plataforma
    L.walker('gummy', 38, G - 1, 36, 42)
    L.walker('gummy', 45, G - 1, 43, 48, helmet=True)
    L.plat(39, 46, G - 4, DROP)
    L.ent('star', 42, G - 5)
    L.walker('gummy', 42, G - 7, 38, 47, movement='fly')
    # escalera de plataformas hasta una vida extra (con un volador con casco)
    L.plat(51, 53, G - 3, DROP)
    L.plat(55, 57, G - 6, DROP)
    L.ent('extralife', 56, G - 7)
    L.walker('gummy', 54, G - 5, 50, 58, movement='fly', helmet=True)
    # dos más antes del castillo
    L.walker('gummy', 62, G - 1, 60, 66, helmet=True)
    L.walker('gummy', 66, G - 1, 63, 69)
    L.ent('checkpoint', 72, G - 1)
    # arena del Rey Gummy (la zona empieza en la columna 87)
    graft(L, src, 6, 81)
    return L


BUILDERS = [ruta_del_espejo, fortaleza_malvada, guarida_cangrejo_rey, lago_helado, glaciar_cangrejo, reino_gummy]
