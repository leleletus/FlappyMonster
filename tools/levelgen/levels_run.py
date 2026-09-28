"""Niveles de carrera/caza (con meta): se juegan en Carrera y en Cazamonstruos.

Física de referencia (con doble salto): un salto sube ~1,6 casillas, dos ~3;
huecos de hasta 4 casillas son cómodos, 5 justos.
"""
from lib import *


def pit(L, c0, c1, floor_row):
    """Foso: sin suelo entre c0..c1; el fondo es `floor_row` con pinchos encima."""
    L.clear(c0, 2, c1, L.h - 1)
    L.rect(c0, floor_row, c1, L.h - 1, SOLID)
    L.spikes(c0, c1, floor_row - 1, UP)


def valle_soleado():
    L = Level('Valle Soleado', 130, 18, (4, 14), music='classic', modes=['race'])
    G = 15
    L.terrain(2, 23, G)
    for c in (4, 11, 19):
        L.deco('palmtree', c, G - 1)
    L.deco('tulip', 8, G - 1, sub=4)
    L.walker('gummy', 16, G - 1, 12, 21)
    L.ent('star', 9, 11)
    # escalones suaves hacia arriba
    L.terrain(24, 35, G - 1)
    L.terrain(36, 47, G - 2)
    L.walker('crabby', 30, G - 2, 26, 34)
    L.plat(38, 42, 10)
    L.ent('star', 40, 8)
    L.walker('gummy', 40, 9, 38, 42)
    L.deco('palmtree', 34, G - 3)
    # foso de 3 con pinchos
    pit(L, 48, 50, 17)
    L.terrain(51, 66, G - 2)
    L.ent('checkpoint', 56, G - 3)
    L.walker('crabby', 61, G - 3, 53, 65)
    # bajada
    L.terrain(67, 87, G)
    L.deco('palmtree', 70, G - 1)
    L.walker('gummy', 70, G - 1, 68, 73)
    # techo con pinchos que caen
    L.rect(74, 2, 86, 9, SOLID)
    L.ent('spikefall', 76, 10, sub=1, detectRange=6)
    L.ent('spikefall', 79, 10, sub=2, detectRange=6)
    L.ent('spikefall', 83, 10, sub=1, detectRange=6)
    L.walker('crabby', 80, G - 1, 75, 86)
    L.ent('extralife', 78, 13)
    # cadena de plataformas sobre foso largo (huecos de 2)
    pit(L, 88, 107, 17)
    for c, r in ((89, 13), (94, 12), (99, 13), (104, 12)):
        L.plat(c, c + 2, r, SLAB if r == 13 else DROP)
    L.walker('gummy', 95, 11, 94, 96)
    L.walker('gummy', 105, 11, 104, 106)
    L.ent('star', 99, 9)
    L.ent('star', 106, 9)
    # colinas finales con cangrejos que trepan
    L.terrain(108, 129, G)
    L.ent('checkpoint', 111, G - 1)
    L.ent('crabby', 116, G - 1, wallWalk=True, patrol=False, speed=60)
    L.terrain(118, 121, G - 2)
    L.terrain(122, 129, G - 3)
    L.finish(126, G - 3)
    L.deco('palmtree', 123, G - 4)
    return L


def cavernas_cristal():
    """Cuevas con lagos, respiraderos de oxígeno, túneles para agacharse y bloques rompibles."""
    L = Level('Cavernas Cristalinas', 140, 22, (4, 20), music='labyrinth', modes=['race'])
    L.rect(2, 2, 139, 21, SOLID)

    def carve(c0, c1, r0, r1):
        L.clear(c0, r0, c1, r1)

    # A: sala de inicio
    carve(2, 30, 13, 20)
    L.plat(10, 14, 17, DROP)
    L.walker('gummy', 12, 16, 10, 14)
    L.ent('star', 12, 15)
    L.walker('crabby', 24, 20, 18, 28)
    L.deco('tulip', 7, 20, sub=4)
    # pasillo con un escalón hacia B
    carve(31, 36, 18, 19)
    L.ent('checkpoint', 35, 19)
    # B: lago con islas (para cruzar se nada entre ellas; los respiraderos dan aire)
    carve(37, 62, 9, 19)
    L.water(37, 18, 62, 19)
    for c in (39, 46, 53, 60):
        L.rect(c, 18, c + 2, 19, SOLID)
    L.vent(43, 19, 3)
    L.vent(50, 19, 3)
    L.vent(57, 19, 3)
    L.walker('crabby', 47, 17, 46, 48)
    L.walker('gummy', 54, 17, 53, 55)
    L.ent('star', 44, 14)
    L.ent('star', 51, 14)
    L.plat(48, 51, 13, DROP)
    L.ent('extralife', 50, 12)                            # premio en lo alto
    L.spikes(41, 41, 17, UP) if False else None
    # salida elevada: peldaños hasta el pasillo
    carve(63, 66, 12, 20)
    L.rect(63, 17, 64, 20, SOLID)                         # pared con hueco arriba
    L.rect(63, 17, 64, 17, SOLID)
    L.rect(65, 19, 66, 20, SOLID)
    # C: cámara con bloques rompibles y pinchos
    carve(67, 84, 12, 20)
    L.rect(67, 19, 68, 20, SOLID)
    L.spikes(72, 78, 20, UP)
    L.plat(70, 72, 17, DROP)
    L.plat(76, 79, 16, DROP)
    L.plat(81, 84, 18, SLAB)
    L.walker('gummy', 82, 17, 81, 84)
    L.ent('star', 77, 14)
    L.rect(80, 12, 84, 13, BREAK)
    # túnel bajo: hay que agacharse
    carve(85, 96, 20, 20)
    L.ent('checkpoint', 84, 17)
    L.walker('crabby', 90, 20, 86, 95)
    # D: pozo vertical
    carve(97, 106, 5, 20)
    for c, r in ((98, 18), (102, 15), (98, 12), (102, 9)):
        L.plat(c, c + 3, r, SLAB)
    L.walker('gummy', 103, 14, 102, 105)
    L.walker('gummy', 99, 11, 98, 101)
    L.ent('star', 100, 16)
    # E: galería alta con pinchos cayendo
    carve(107, 122, 5, 8)
    L.terrain(107, 122, 9)
    L.rect(107, 2, 122, 4, SOLID)
    L.ent('spikefall', 110, 5, sub=1, detectRange=7)
    L.ent('spikefall', 114, 5, sub=2, detectRange=7)
    L.ent('spikefall', 118, 5, sub=1, detectRange=7)
    L.walker('crabby', 112, 8, 108, 116)
    L.ent('checkpoint', 108, 8)
    # F: descenso por lago profundo
    carve(123, 132, 5, 20)
    L.water(123, 11, 132, 20)
    L.rect(123, 5, 123, 10, SOLID)
    L.clear(123, 5, 123, 8)
    L.plat(123, 125, 9, SLAB)
    L.vent(126, 20, 3)
    L.vent(130, 20, 3)
    L.spikes(127, 128, 20, UP)
    L.ent('star', 128, 15)
    # G: final con peldaños
    carve(133, 138, 12, 20)
    L.rect(133, 19, 134, 20, SOLID)
    L.rect(135, 17, 136, 20, SOLID)
    L.rect(137, 15, 138, 20, SOLID)
    L.finish(137, 14)
    L.walker('crabby', 134, 18, 133, 134, pauses=False)
    return L


def torre_viento():
    """Torre vertical en zig-zag: 25 plataformas hacia el cielo, con descansos y checkpoints."""
    L = Level('Torre del Viento', 44, 56, (5, 54), music='flying_machine', modes=['race'])
    L.terrain(2, 43, 55)
    xs = [4, 13, 22, 31, 22, 13]        # columnas izquierdas de cada plataforma (ancho 6)
    row = 52
    i = 0
    while row > 10:
        c = xs[i % len(xs)]
        L.plat(c, c + 5, row, DROP)
        if i % 3 == 1:
            L.walker('gummy', c + 2, row - 1, c, c + 5)
        if i % 5 == 2:
            L.walker('crabby', c + 3, row - 1, c, c + 5)
        if i % 4 == 0 and i > 0 and row > 14:
            L.ent('star', c + 2, row - 3)
        if i in (8, 16):
            L.ent('checkpoint', c + 3, row - 1)
        row -= 2
        i += 1
    # cima
    L.plat(28, 40, 10, DROP)
    L.rect(14, 8, 30, 8, SOLID)
    L.finish(21, 7)
    # paredes de pinchos decorativas (peligro lateral)
    for r in range(10, 50, 8):
        L.half_spikes(2, r, RIGHT, 0)
        L.half_spikes(43, r, LEFT, 1)
    return L


def fabrica_morteros():
    """Fábrica con morteros, túneles de gateo (salto agachado), muros y trampas de techo."""
    L = Level('Fábrica de Morteros', 124, 17, (4, 14), music='flying_machine', modes=['race'])
    G = 15
    L.terrain(2, 123, G)
    # 1: entrada
    L.ent('mortar', 12, G - 1, range=9, delayMin=3, delayMax=5)
    L.walker('gummy', 8, G - 1, 5, 10)
    L.walker('crabby', 17, G - 1, 14, 20)
    L.ent('checkpoint', 21, G - 1)
    # 2: muro con túnel bajo (agachado) y ruta alta por plataformas
    L.rect(30, 6, 31, G - 2, SOLID)
    L.rect(29, 6, 32, 6, SOLID)
    L.plat(24, 27, 12, DROP)
    L.plat(24, 27, 9, DROP)
    L.ent('star', 25, 8)
    L.plat(33, 36, 11, DROP)
    L.plat(28, 33, 4, SOLID) if False else None
    L.walker('crabby', 26, 8, 24, 27)
    L.ent('star', 30, G - 1)               # premio dentro del túnel
    # techo del túnel a 1 de alto: hay que gatear
    L.rect(30, G - 1, 31, G - 1, EMPTY)
    # 3: pasillo con techo bajo y pinchos que caen
    L.rect(37, 2, 62, 10, SOLID)
    for c in (40, 44, 48, 52, 57):
        L.ent('spikefall', c, 11, sub=1 + (c % 2), detectRange=5)
    L.ent('mortar', 46, G - 1, range=10, sides='both')
    L.ent('mortar', 58, G - 1, range=10, sides='left')
    L.walker('gummy', 42, G - 1, 38, 45)
    L.ent('checkpoint', 62, G - 1)
    # 4: cadena de cintas sobre foso
    pit(L, 64, 84, 16)
    for i, c in enumerate(range(65, 83, 5)):
        L.plat(c, c + 3, 13 - (i % 2), SLAB)
    L.walker('crabby', 70, 12, 69, 72)
    L.walker('gummy', 80, 12, 79, 82)
    L.ent('star', 75, 9)
    # 5: cámara con suelo rompible: pisotón para bajar al almacén
    L.terrain(85, 110, G - 3)
    L.rect(92, G - 3, 96, G - 3, BREAK)
    L.clear(92, G - 2, 96, G - 1)
    L.ent('extralife', 94, G - 1)          # almacén secreto bajo los bloques
    L.ent('mortar', 100, G - 4, range=9, sides='left')
    L.walker('crabby', 88, G - 4, 86, 91)
    L.walker('gummy', 106, G - 4, 102, 109)
    L.ent('checkpoint', 98, G - 4)
    # 6: final
    L.terrain(111, 123, G - 1)
    L.terrain(116, 123, G - 3)
    L.finish(120, G - 3)
    L.walker('crabby', 113, G - 2, 111, 115)
    return L


def tren_fugaz():
    """Cámara automática horizontal: no pares. Enemigos, morteros y fosos a ritmo constante."""
    L = Level('Tren Fugaz', 170, 11, (5, 9), music='flying_machine', modes=['race'])
    L.auto_scroll = {'countdown': 3, 'endCol': 170, 'margin': 0.6, 'speed': 105, 'startCol': 1, 'width': 20}
    G = 10
    L.terrain(2, 169, G)
    c = 24
    motif = 0
    while c < 150:
        m = motif % 5
        if m == 0:            # foso de 3 con pinchos
            pit(L, c, c + 2, 10)
            L.walker('gummy', c + 6, G - 1, c + 4, c + 9)
            c += 12
        elif m == 1:          # escalera con cangrejo
            L.terrain(c, c + 3, G - 1)
            L.terrain(c + 4, c + 7, G - 2)
            L.walker('crabby', c + 5, G - 3, c + 4, c + 7)
            L.terrain(c + 8, c + 12, G)
            c += 13
        elif m == 2:          # mortero + plataformas altas
            L.ent('mortar', c + 4, G - 1, range=9, delayMin=2, delayMax=3.5)
            L.plat(c + 1, c + 4, 6, DROP)
            L.ent('star', c + 2, 5)
            c += 12
        elif m == 3:          # hueco de 4 con plataforma intermedia
            pit(L, c, c + 4, 10)
            L.plat(c + 1, c + 3, 8, SLAB)
            L.walker('gummy', c + 8, G - 1, c + 6, c + 10)
            c += 12
        else:                 # techo con pinchos
            L.rect(c, 2, c + 6, 5, SOLID)
            L.ent('spikefall', c + 2, 6, sub=1, detectRange=4)
            L.ent('spikefall', c + 5, 6, sub=2, detectRange=4)
            L.ent('extralife', c + 3, 8) if c > 100 else None
            c += 12
        motif += 1
    L.finish(163, G - 1)
    return L


def canon_trampolines():
    """Cañones de trampolines: muros y fosos imposibles sin rebotar; estantes altos con premios."""
    L = Level('Cañón de Trampolines', 120, 20, (4, 17), music='hidro_city', modes=['race'])
    G = 18
    L.terrain(2, 119, G)
    L.deco('palmtree', 5, G - 1)
    L.ent('trampoline', 9, G - 1)
    L.plat(6, 13, 12, SLAB)                # estante alto: premio
    L.ent('star', 9, 10)
    L.ent('extralife', 12, 11)
    L.walker('gummy', 17, G - 1, 14, 22)
    # muro de 6 de alto: se pasa rebotando (o por el estante)
    L.rect(26, 12, 28, G - 1, SOLID)
    L.ent('trampoline', 24, G - 1)
    L.ent('star', 27, 10)
    L.terrain(29, 44, G)
    L.walker('crabby', 34, G - 1, 30, 40)
    L.ent('checkpoint', 32, G - 1)
    # foso ancho (5) con trampolín de despegue
    L.ent('trampoline', 43, G - 1)
    pit(L, 45, 49, 19)
    L.terrain(50, 70, G - 1)
    L.walker('gummy', 60, G - 2, 56, 66)
    L.ent('checkpoint', 56, G - 2)
    # cañón de piedras: plataformas con trampolín a 7 de distancia
    pit(L, 71, 96, 19)
    for i, c in enumerate((72, 79, 86)):
        L.plat(c, c + 3, 15 - i, SLAB)
        L.ent('trampoline', c + 1, 14 - i)
    L.walker('crabby', 88, 12, 87, 89) if False else None
    L.plat(93, 96, 13, SLAB)
    L.ent('star', 76, 7)
    L.ent('star', 83, 7)
    L.terrain(97, 119, G - 2)
    L.walker('gummy', 101, G - 3, 98, 106)
    L.ent('checkpoint', 99, G - 3)
    L.walker('crabby', 108, G - 3, 104, 112)
    L.terrain(110, 119, G - 4)
    L.finish(115, G - 4)
    return L


BUILDERS = [valle_soleado, cavernas_cristal, torre_viento, fabrica_morteros, tren_fugaz, canon_trampolines]
