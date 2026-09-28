"""Niveles de Rey de la Colina: solo Modo Puntos (koth). Zona de puntos = entidad `pointarea`."""
from lib import *
from levels_run import pit


def isla_flotante():
    """Isla central sobre un foso de pinchos: escaleras, trampolines y pinchos que caen sobre la zona."""
    L = Level('Isla Flotante', 60, 22, (4, 19), music='flying_machine', modes=['koth'], match_time=150)
    G = 20
    L.terrain(2, 59, G)
    pit(L, 15, 46, 21)
    # escaleras a la isla (2 filas por escalón)
    for c, r in ((16, 18), (19, 16), (22, 14)):
        L.plat(c, c + 3, r, DROP)
    for c, r in ((41, 18), (38, 16), (35, 14)):
        L.plat(c, c + 3, r, DROP)
    # isla central y zona
    L.rect(26, 12, 34, 13, SOLID)
    L.rect(29, 14, 31, 15, SOLID)
    L.ent('pointarea', 26, 7, corner={'col': 34, 'row': 11})
    # techo con pinchos sobre la zona
    L.rect(24, 3, 36, 3, SOLID)
    for c in (26, 29, 32, 34):
        L.ent('spikefall', c, 4, sub=1 + (c % 2), detectRange=6, stuckTime=1.5)
    # trampolines de las orillas hacia plataformas altas
    L.ent('trampoline', 13, G - 1)
    L.plat(16, 20, 9, DROP)
    L.ent('trampoline', 46 + 1, G - 1)
    L.plat(40, 44, 9, DROP)
    L.ent('star', 18, 7)
    L.ent('star', 42, 7)
    # cangrejos trampolín por las paredes de la isla
    L.ent('crabbytramp', 25, 13, wallWalk=True, patrol=False, respawn=1, speed=60)
    L.ent('crabby', 36, 13, wallWalk=True, patrol=False, respawn=1, speed=70)
    L.walker('gummy', 8, G - 1, 4, 13, respawn=1)
    L.walker('gummy', 52, G - 1, 48, 57, respawn=1)
    L.ent('extralife', 30, 17) if False else None
    return L


def coliseo_pinchos():
    """Arena de gladiadores: gradas, pinchos que llueven del techo y zona elevada en el centro."""
    L = Level('Coliseo de Pinchos', 64, 20, (9, 17), music='flying_machine', modes=['koth'], match_time=180)
    G = 18
    L.terrain(2, 63, G)
    # gradas laterales (peldaños de 1)
    for i in range(6):
        L.terrain(2 + i * 2, 3 + i * 2, G - 1 - i) if False else None
    for i, c in enumerate((2, 4, 6)):
        L.rect(c, G - 1 - i, c + 1, G - 1, SOLID)
    for i, c in enumerate((62, 60, 58)):
        L.rect(c - 1, G - 1 - i, c, G - 1, SOLID)
    # fosos con pinchos entre las gradas y el centro
    pit(L, 12, 17, 19)
    pit(L, 46, 51, 19)
    L.ent('trampoline', 11, G - 1)
    L.ent('trampoline', 52, G - 1)
    # centro elevado
    L.rect(24, G - 3, 40, G - 1, SOLID)
    L.ent('pointarea', 27, G - 8, corner={'col': 37, 'row': G - 4})
    L.plat(20, 23, G - 2, DROP)
    L.plat(41, 44, G - 2, DROP)
    L.plat(18, 21, G - 5, DROP)
    L.plat(43, 46, G - 5, DROP)
    # techo y lluvia de pinchos
    L.rect(14, 2, 50, 2, SOLID)
    L.ent('spikerain', 32, 4, range=9, activeEasy=1, activeHard=4)
    for c in range(16, 49):
        L.ent('rainspike', c, 3, sub=1)
        L.ent('rainspike', c, 3, sub=2)
    # público hostil
    L.walker('crabby', 20, G - 1, 18, 23, respawn=1)
    L.walker('crabby', 44, G - 1, 41, 46, respawn=1)
    L.walker('gummy', 30, G - 4, 25, 39, respawn=1)
    L.ent('star', 32, G - 6)
    return L


def cascada_dorada():
    """Pozo vertical que se inunda y drena por ciclos; la zona queda sumergida a ratos."""
    L = Level('Cascada Dorada', 48, 28, (5, 25), music='hidro_city', modes=['koth'], match_time=180)
    G = 26
    L.terrain(2, 47, G)
    # zigzag de plataformas (2 filas por escalón) hacia la base de la zona
    plats = [(4, 10, 23), (13, 19, 21), (22, 28, 19), (31, 37, 17), (35, 41, 15), (27, 33, 13),
             (5, 11, 19), (8, 14, 15), (10, 15, 13), (39, 45, 11), (41, 46, 19)]
    for a, b, r in plats:
        L.plat(a, b, r, DROP)
    # base de la zona: en lo alto, la marea la cubre a ratos
    L.rect(16, 11, 24, 12, SOLID)
    L.ent('pointarea', 16, 7, corner={'col': 24, 'row': 10})
    # marea: sube y baja en todo el pozo
    L.ent('flood', 2, 2, corner={'col': 47, 'row': 26}, startLevel=2, maxLevel=18, startDelay=6,
          riseSpeed=0.6, holdTime=6, fallSpeed=0.9, lowTime=6)
    L.vent(6, 26, 3)
    L.vent(44, 26, 3)
    L.vent(25, 26, 3)
    # habitantes
    L.walker('crabby', 25, 18, 22, 28, respawn=1)
    L.walker('gummy', 16, 20, 13, 19, respawn=1)
    L.walker('gummy', 37, 14, 35, 41, respawn=1)
    L.walker('crabby', 20, 12, 15, 20) if False else None
    L.ent('trampoline', 9, G - 1)
    L.ent('trampoline', 39, G - 1)
    L.ent('star', 8, 9)
    L.ent('star', 40, 9)
    return L


BUILDERS = [isla_flotante, coliseo_pinchos, cascada_dorada]
