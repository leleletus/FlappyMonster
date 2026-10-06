"""LA HUIDA DEL ESPEJO — el nivel de antes del jefe final: el Espejo te PERSIGUE (entidad `mirrorchase`, pegada al
borde izquierdo de la cámara automática) por un nivel horizontal del volcán. No se le puede hacer nada: hay que
llegar a la meta. La cámara va a 160 px/s (el jugador corre a 240): deja margen para saltar, no para pararse.
Dura lo que una vuelta de su música (mirror_chase, 82,8 s): 214 casillas.

    python3 tools/levelgen/build.py --only huida_del_espejo
    python3 tools/levelgen/retheme.py huida_del_espejo        (terreno y decoraciones del volcán)
"""
from lib import *

LAVA = 3
G = 10          # fila del suelo (11 filas: la cámara automática enseña toda la altura)


def lava_pit(L, c0, c1):
    """Foso de LAVA a ras de suelo (se salta)"""
    L.clear(c0, 2, c1, G)
    L.rect(c0, G, c1, G, LAVA)


def huida_del_espejo():
    W = 214
    L = Level('La Huida del Espejo', W, 11, (9, G - 1), music='mirror_chase', modes=['race'])
    L.extra.update(name_en='Mirror Escape', background='volcano', time='dusk')
    L.auto_scroll = {'countdown': 3, 'endCol': W, 'margin': 0.6, 'speed': 160, 'startCol': 1, 'width': 20}
    L.terrain(2, W - 1, G)
    L.ent('mirrorchase', 3, G - 2)
    c, m = 24, 0
    while c < W - 30:
        k = m % 9
        if k == 0:                      # calentamiento: un Gummy de frente y un foso corto
            L.walker('gummy', c + 4, G - 1, c + 2, c + 7)
            lava_pit(L, c + 9, c + 10)
            c += 13
        elif k == 1:                    # escalones arriba y abajo
            L.terrain(c, c + 3, G - 1)
            L.terrain(c + 4, c + 7, G - 2)
            L.ent('star', c + 5, G - 5)
            L.terrain(c + 8, c + 10, G - 1)
            c += 13
        elif k == 2:                    # lago de lava con dos plataformas
            lava_pit(L, c, c + 9)
            L.plat(c + 2, c + 3, G - 1, SLAB)
            L.plat(c + 6, c + 7, G - 2, SLAB)
            c += 13
        elif k == 3:                    # techo bajo con pinchos que caen
            L.rect(c, 2, c + 8, 5, SOLID)
            L.ent('spikefall', c + 2, 6, sub=1, detectRange=4)
            L.ent('spikefall', c + 5, 6, sub=2, detectRange=4)
            L.ent('spikefall', c + 7, 6, sub=1, detectRange=4)
            c += 12
        elif k == 4:                    # un Saltarín en mitad del camino
            L.ent('hopper', c + 5, G - 1, patrol={'left': c + 2, 'right': c + 9}, jumpEvery=1.1)
            lava_pit(L, c + 11, c + 12)
            c += 15
        elif k == 5:                    # muro de 3: se pasa con el trampolín
            L.ent('trampoline', c + 3, G - 1)
            L.rect(c + 5, G - 3, c + 6, G - 1, SOLID)
            L.ent('star', c + 5, G - 6)
            c += 12
        elif k == 6:                    # tres fosos seguidos, a ritmo
            for i in range(3):
                lava_pit(L, c + i * 4, c + i * 4 + 1)
            L.walker('crabby', c + 14, G - 1, c + 12, c + 16, canHide=False)
            c += 18
        elif k == 7:                    # mortero: bolas de fuego mientras corres
            L.ent('mortar', c + 6, G - 1, range=9, delayMin=1.6, delayMax=2.6)
            L.plat(c + 2, c + 4, G - 3, DROP)
            L.ent('extralife', c + 3, G - 4) if m > 9 else L.ent('star', c + 3, G - 4)
            c += 12
        else:                           # escalera hacia arriba sobre lava
            lava_pit(L, c + 1, c + 10)
            L.plat(c + 1, c + 2, G - 1, SLAB)
            L.plat(c + 4, c + 5, G - 2, SLAB)
            L.plat(c + 7, c + 8, G - 3, SLAB)
            L.ent('star', c + 8, G - 5)
            c += 13
        m += 1
    L.finish(W - 6, G - 1)
    return L


BUILDERS = [huida_del_espejo]
