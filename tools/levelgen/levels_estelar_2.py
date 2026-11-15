"""Los niveles estelares nuevos (2026-11-15; docs/design/estelar-levels-2.md): el usuario pidió, después de la Vía
Estelar (larga y algo tediosa), un nivel MÁS RÁPIDO que exprima los Bloques Beep con parkour y plataformeo puro, un
BONUS y el nivel del JEFE, todos con relieve de verdad (nada de rectángulos lisos: tools/levelgen/geo.py), el plano de
fondo a fondo y bien decorados.

    python3 tools/levelgen/build.py --only pulsar escenario_estelar santuario_del_compas
    tools/tests/run.sh level_shots -- assets/levels/pulsar.json          (la foto)

  pulsar                 PÚLSAR: 240 x 40, a 140 BPM (frase de 3,43 s: los bloques cambian más deprisa), seis tramos
  escenario_estelar      EL ESCENARIO ESTELAR: bonus (Rey de la Colina contra el bot), 72 x 26, a 126 BPM
  santuario_del_compas   EL SANTUARIO DEL COMPÁS: el nivel del jefe estelar (aún sin jefe: la arena y el camino), 150 BPM
"""
import random
from lib import *
from geo import Geo
from levels_via_estelar import (FR, IR, CLOUD, BRICK, PILLAR, WINDOW, CPF, PF, PINK, CYAN, met, spring, hint, bridge,
                                DECO_TOP)


def period(bpm):
    """s de una frase de 8 pulsos (lo que tarda en cambiar un Bloque Beep)"""
    return round(8 * 60.0 / bpm, 7)


def geo(L, seed):
    return Geo(L, seed, top=FR, body=IR, brick=BRICK, pillar=PILLAR, window=WINDOW, cloud=CLOUD)


def clap(L, c, r, offset=0, d='up'):
    """placa de pinchos de palmas en (c, r) — una casilla sólida; `d` = hacia dónde salen —"""
    L.set(c, r, EMPTY)
    p = {}
    if offset: p['offset'] = offset
    if d != 'up': p['dir'] = d
    return L.ent('clapspikes', c, r, **p)


def orbit(L, c, r, count=2, radius=2, per=8, d='cw', phase=0, motion=None):
    p = {}
    if count != 2: p['count'] = count
    if radius != 2: p['radius'] = radius
    if per != 8: p['beatsPerTurn'] = per
    if d != 'cw': p['dir'] = d
    if phase: p['phase'] = phase
    if motion: p['motion'] = motion
    return L.ent('orbitstars', c, r, **p)


def beeps(L, steps):
    """escalones de Bloques Beep: (c0, c1, fila, 'P' | 'C')"""
    for c0, c1, r, k in steps:
        bridge(L, c0, c1, r, PINK if k == 'P' else CYAN)


# ══ Decoración común ═════════════════════════════════════════════════════════════════════════════════════════════
def decorate(L, seed, density=0.24, sky=(4, 30), skip=()):
    """lo de encima de cada superficie de cristal o nube, y estrellas flotando en el cielo abierto"""
    rng = random.Random(seed)
    busy = {(e['col'], e['row']) for e in L.entities} | {(e['col'], e['row'] + 1) for e in L.entities}
    busy |= {(e['col'] + dx, e['row']) for e in L.entities if e['type'] in ('clapspikes', 'orbitstars') for dx in (-1, 1)}
    tot = sum(w for _, w, _ in DECO_TOP)
    for c in range(3, L.w - 2):
        if any(a <= c <= b for a, b in skip): continue
        for r in range(3, L.h - 2):
            if L.get(c, r) != EMPTY or L.get(c, r + 1) not in (FR, CLOUD) or (c, r) in busy: continue
            if rng.random() > density: continue
            if L.get(c, r + 1) == CLOUD:
                if rng.random() < 0.4: L.deco('cloud_puff', c, r)
                continue
            x = rng.random() * tot
            for name, w, sub in DECO_TOP:
                x -= w
                if x <= 0:
                    L.deco(name, c, r, sub); break
    for c in range(6, L.w - 6, 7):
        r = rng.randrange(*sky)
        if all(L.get(cc, rr) == EMPTY for cc in range(c - 2, c + 3) for rr in range(r - 2, r + 3)) \
           and not any(a <= c <= b for a, b in skip):
            L.deco('floating_star', c, r)


# ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════
# PÚLSAR
# ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════
PW, PH = 240, 40


def p_launch_and_stair(L, g):
    # 0 · DESPEGUE: una isla grande con su cúpula de roca debajo
    g.island(2, 17, 26, depth=9, tips=2)
    hint(L, 12, 25, 'pulsar.intro')
    # 1 · LA ESCALERA DE AGUJAS: escalones de dos en dos del mismo color (se suben dos por frase) y el salto al otro
    #     color justo en el cambio; debajo, el vacío
    beeps(L, [(20, 21, 25, 'P'), (23, 24, 24, 'P'), (26, 27, 22, 'C'), (29, 30, 21, 'C'),
              (32, 33, 19, 'P'), (35, 36, 18, 'P'), (38, 39, 16, 'C'), (41, 42, 15, 'C')])
    L.ent('apple', 30, 20)
    # el rellano: una isla colgada delante del monte
    g.island(44, 52, 14, depth=6, tips=1)
    L.ent('checkpoint', 46, 13)
    L.walker('gummy_star', 50, 13, 48, 52)


def p_canyon(L, g):
    """2 · LA GRIETA DE PALMAS: un MACIZO flotante atravesado por un túnel (detrás, la pared de la cueva en el plano de
    fondo); palmas en el suelo, el TECHO y las paredes; un foso de Bloques Beep; y la CHIMENEA, que se sube por repisas
    de colores alternos con palmas en las paredes"""
    rng = g.rng
    g.massif(53, 97, 5, 27, amp=1.5, shoulder=3, taper=9, tips=3)
    # el túnel (suelo de la 14) — la entrada, desde el rellano
    g.carve(53, 10, 84, 13)
    for c in range(53, 85):
        if L.get(c, 14) == EMPTY: L.set(c, 14, FR)
    # el techo del túnel, irregular, con puntas
    for c in range(57, 84):
        if rng.random() < 0.3: L.set(c, 10, IR)
    for c in (57, 60, 68):
        if L.get(c, 10) != EMPTY: g.sub(c, 11, 1); g.sub(c, 11, 2)
    # palmas: suelo (salen arriba), techo (abajo) y las dos a la vez
    for c in (58, 59): clap(L, c, 14, 0)
    for c in (64, 65): clap(L, c, 14, 0)
    for c in (61, 62): clap(L, c, 10, 0, 'down')
    hint(L, 55, 13, 'pulsar.claps')
    # el FOSO: dos PISTAS seguidas sobre pinchos, cian (71-77) y rosa (78-84): con un solo color el hueco es de 7
    # (más que un doble salto, unas 5): hay que entrar en la cian con el cian y pasar a la rosa JUSTO en el cambio
    g.carve(71, 7, 84, 19)
    L.spikes(71, 84, 19)
    beeps(L, [(71, 77, 14, 'C'), (78, 84, 14, 'P')])
    g.sub(71, 7, 1); g.sub(84, 7, 2)
    L.ent('checkpoint', 67, 13)
    # la CHIMENEA (85-88, de la 13 hasta arriba): repisas alternas rosa / cian y palmas en las paredes
    g.carve(85, 2, 88, 13)
    g.carve(89, 2, 92, 5)
    for c in range(89, 93): L.set(c, 6, FR)
    beeps(L, [(85, 86, 12, 'P'), (87, 88, 10, 'C'), (85, 86, 8, 'P'), (87, 88, 6, 'C')])
    clap(L, 89, 9, 0, 'left')
    clap(L, 84, 7, 1, 'right')
    clap(L, 89, 12, 1, 'left')
    # la estrella 1: un nicho en la pared izquierda, a la altura de la última repisa rosa
    g.carve(82, 6, 83, 7)
    L.ent('star', 82, 7)
    L.ent('checkpoint', 91, 5)
    L.ent('apple', 87, 13)
    # (lo de encima del macizo, por encima de la chimenea, ya no tapa la salida)
    for c in range(85, 93):
        for r in range(2, 6): L.set(c, r, EMPTY)


def p_orbits(L, g):
    """3 · LAS ÓRBITAS: el cielo abierto; estrellas en órbita sobre los huecos, parejas de metrónomos que se juntan
    entre estrellas y un puente de colores con una órbita encima (la estrella 2, en su eje)"""
    orbit(L, 98, 6, count=1)
    hint(L, 89, 5, 'pulsar.orbit')
    g.island(100, 105, 10, depth=4)
    L.walker('gummy_star', 103, 9, 101, 105)
    met(L, 106, 10, 4, 'right')
    met(L, 118, 10, 4, 'left')
    orbit(L, 113, 6, count=2)
    g.island(120, 127, 11, depth=5, tips=2)
    L.ent('checkpoint', 122, 10)
    L.walker('crabby_star', 125, 10, 123, 127)
    L.ent('gust', 126, 4, points=6)
    # una PISTA rosa de 12 (con el cian, un hueco de 12): se corre entera en una frase (~2,9 s de 3,43), y por ella
    # pasa la órbita de abajo
    beeps(L, [(128, 139, 12, 'P')])
    orbit(L, 134, 9, count=2, d='ccw', phase=1)
    L.ent('star', 134, 9)                                 # (en el eje: se coge entre las dos estrellas)
    g.island(139, 143, 15, depth=4)
    L.ent('checkpoint', 140, 14)
    L.ent('apple', 142, 14)


def p_shaft(L, g):
    """4 · EL POZO: un macizo hueco (geoda) que se baja de suelo en suelo — medio pozo rosa, medio cian, alternos —;
    hay que DEJARSE CAER del borde justo antes del cambio para aterrizar en el otro color (el mismo color queda 8 filas
    más abajo). Palmas en las paredes. Abajo, pinchos; la salida es un túnel desde el último suelo"""
    g.massif(144, 165, 11, 37, amp=1.5, shoulder=3, taper=9, tips=2)
    for c in range(144, 149):                               # (la boca: a ras de la isla de antes)
        for r in range(2, 16): L.set(c, r, EMPTY)
        L.set(c, 16, FR)
    g.carve(149, 2, 156, 33)
    for c in range(149, 157):
        for r in range(2, 12): L.set_bg(c, r, EMPTY)        # (arriba, cielo: la cueva empieza dentro)
    g.sub(148, 16, 4)
    L.spikes(149, 156, 33)
    hint(L, 145, 15, 'pulsar.drop')
    beeps(L, [(149, 152, 17, 'P'), (153, 156, 21, 'C'), (149, 152, 25, 'P'), (153, 156, 29, 'C')])
    clap(L, 148, 19, 0, 'right'); clap(L, 157, 23, 1, 'left'); clap(L, 148, 27, 0, 'right')
    # la salida: un túnel a la derecha a ras del último suelo cian, hasta el borde del macizo
    g.carve(157, 27, 166, 28)
    for c in range(157, 167): L.set(c, 29, FR)


def p_finale(L, g):
    """5 · EL SPRINT FINAL: trampolín de compás a la repisa, un puente de colores bajo un techo de roca con palmas que
    caen, metrónomo entre tres estrellas en órbita y la escalera de colores a la meta (la estrella 3, arriba)"""
    g.island(166, 171, 29, depth=6, tips=1)
    L.ent('checkpoint', 166, 28)
    spring(L, 170, 28)
    g.island(173, 181, 22, depth=5)
    L.ent('apple', 179, 21)
    L.walker('hopper', 177, 21, 174, 181)
    # un TECHO de roca flotante sobre el puente (de él caen las palmas: no se pasa por arriba de un doble salto)
    g.massif(181, 199, 12, 18, amp=1, shoulder=2, taper=3, tips=0, veins=0.04)
    # rosa (3) · PISTA cian (8) · rosa (3) · cian (3): con el rosa el hueco es de 8, y la pista entera más lo que sigue
    # no se corre en una frase: se espera al final de la pista y se salta al rosa en el cambio
    beeps(L, [(182, 184, 22, 'P'), (185, 192, 22, 'C'), (193, 195, 22, 'P'), (196, 198, 22, 'C')])
    for c, off in ((184, 0), (187, 1), (190, 0), (194, 1), (197, 0)):
        b = g.bottom(c, 2)
        if b and b < 20: clap(L, c, b + 1, off, 'down')
    g.island(199, 206, 22, depth=5, tips=1)
    L.ent('checkpoint', 202, 21)
    met(L, 207, 22, 4, 'right')
    orbit(L, 212, 19, count=3, radius=2.5)
    g.island(213, 220, 22, depth=5)
    L.walker('gummy_star', 218, 21, 216, 220)
    spring(L, 214, 21)
    L.plat(215, 218, 14, PF)
    L.ent('star', 217, 13)
    # la escalera de la meta: 2 filas por escalón (el mismo color queda a 4: no llega un doble salto)
    beeps(L, [(222, 223, 21, 'P'), (225, 226, 19, 'C'), (228, 229, 17, 'P')])
    g.island(231, 238, 15, depth=9, tips=2)
    L.finish(235, 14)


def p_backdrop(L, g):
    """el PLANO DE FONDO: agujas de cristal lejanas que salen de un mar de nubes, islas que flotan y ruinas encima de
    las islas grandes (las cuevas de los macizos ya tienen su pared detrás)"""
    rng = g.rng
    for c in range(6, PW - 4, 11):
        base, top = 36, rng.randrange(14, 26)
        g.bg_spire(c + rng.randrange(-2, 3), base, top, w=rng.choice((5, 7, 9)))
    for c0 in (22, 108, 186, 224):
        g.bg_island(c0, c0 + rng.randrange(6, 10), rng.randrange(5, 9), depth=4)
    g.bg_tower(5, 25, 5); g.bg_portico(10, 25, 4)
    g.bg_arch(45, 51, 13, 5)
    g.bg_tower(101, 9, 4); g.bg_portico(121, 10, 4)
    g.bg_tower(232, 14, 5)
    g.bg_cloud_sea(33)


def pulsar():
    L = Level('Púlsar', PW, PH, (5, 25), music='estelar_pulsar', modes=['race'])
    L.extra.update(name_en='Pulsar', background='starway', time='night', light='none', timeLimit=480,
                   beat={'period': period(140), 'start': 'pink'})
    L.spikes(2, PW - 1, PH - 1)
    g = geo(L, 21)
    p_launch_and_stair(L, g)
    p_canyon(L, g)
    p_orbits(L, g)
    p_shaft(L, g)
    p_finale(L, g)
    p_backdrop(L, g)
    decorate(L, 31, skip=((144, 165),))
    return L


# ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════
# EL ESCENARIO ESTELAR (bonus: Rey de la Colina contra el bot)
# ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════
EW, EH = 72, 28


def escenario_estelar():
    """Un ESCENARIO flotante en medio de dos islas. Las dos zonas: el escenario y la cima (una repisa sobre él a la que
    se llega con el trampolín del centro o por los escalones de colores de los lados). Las islas se unen al
    escenario por PISTAS de un color (rosa a la izquierda, cian a la derecha: con el otro color, un hueco de 6 que no
    salva un doble salto: se cruza a su tiempo). Debajo, un mar de nubes macizas con trampolines en los bordes que te devuelven arriba
    (nadie muere al caer: en un bonus se pierde tiempo, no vidas)."""
    L = Level('El Escenario Estelar', EW, EH, (6, 19), music='estelar_bonus', modes=['koth'], match_time=100)
    L.extra.update(name_en='The Star Stage', background='starway', time='night', light='none',
                   beat={'period': period(126), 'start': 'pink'})
    g = geo(L, 7)
    # las dos islas y el escenario
    g.island(3, 21, 20, depth=5, tips=1)
    g.island(51, 69, 20, depth=5, tips=1)
    g.massif(28, 44, 21, 25, amp=0.6, shoulder=0, taper=2, tips=0, veins=0.03)
    for c in range(28, 45): L.set(c, 21, FR)               # (el suelo del escenario, plano)
    # las pistas (rosa a la izquierda, cian a la derecha)
    beeps(L, [(22, 27, 20, 'P'), (45, 50, 20, 'C')])
    # el mar de nubes (macizo) y sus trampolines de compás
    for c in range(2, EW):
        top = 26 if (c // 7) % 2 else 25
        for r in range(top, EH): L.set(c, r, CLOUD)
    for c in (2, EW - 1):                                  # (en los bordes: lo único con cielo encima)
        L.ent('trampoline', c, 24, power=2.0)
    # la CIMA: repisa traspasable sobre el escenario (zona 2) y los escalones de colores a los lados
    # (de 2 en 2 filas: repisas → escalones de colores → la cima; y un trampolín en medio del escenario)
    L.plat(32, 40, 14, PF)
    L.ent('trampoline', 36, 20, power=2.0)
    L.plat(26, 29, 18, PF); L.plat(43, 46, 18, PF)
    beeps(L, [(29, 31, 16, 'P'), (41, 43, 16, 'C')])
    # las zonas (una activa a la vez, que va de una a otra)
    L.ent('pointarea', 31, 18, corner={'col': 41, 'row': 20}, points=4)
    L.ent('pointarea', 33, 11, corner={'col': 39, 'row': 13}, points=3)
    # peligros al compás en los bordes (lejos de las zonas): palmas en las islas y una órbita sobre cada pista
    for c, off in ((9, 0), (10, 0), (62, 1), (63, 1)): clap(L, c, 20, off)
    orbit(L, 24, 16, count=1, radius=2)
    orbit(L, 48, 16, count=1, radius=2, d='ccw')
    # enemigos que reaparecen (regla de las arenas: el 40 % de sus puntos) y estrellas
    L.walker('gummy_star', 17, 19, 14, 20, respawn=1, points=4)
    L.walker('gummy_star', 55, 19, 52, 58, respawn=1, points=4)
    L.walker('hopper', 50, 24, 45, 55, respawn=1, points=6)
    L.ent('star', 4, 15)
    L.ent('star', 68, 15)
    L.plat(3, 6, 16, PF); L.plat(66, 69, 16, PF)
    # fondo: arcos y columnas detrás del escenario, torres en las islas
    g.bg_arch(29, 43, 20, 12)
    g.bg_portico(31, 12, 3, w=11)
    g.bg_tower(6, 19, 6); g.bg_tower(64, 19, 6)
    g.bg_spire(18, 24, 6, w=5); g.bg_spire(54, 24, 6, w=5)
    for c0 in (8, 56):
        g.bg_island(c0, c0 + 7, 4, depth=3)
    decorate(L, 9, density=0.3, sky=(3, 10))
    return L


# ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════
# EL SANTUARIO DEL COMPÁS (el nivel del jefe estelar; el jefe aún no existe: docs/design/estelar-boss-ideas.md)
# ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════
SW_, SH = 130, 32
AX0, AX1 = 84, 125                  # la arena (columnas de dentro)
AF = 26                             # su suelo


def santuario_del_compas():
    L = Level('El Santuario del Compás', SW_, SH, (4, 21), music='estelar_boss', modes=['race'])
    L.extra.update(name_en='Sanctuary of the Beat', background='starway', time='night', light='none',
                   beat={'period': period(150), 'start': 'pink'})
    L.spikes(2, SW_ - 1, SH - 1)
    g = geo(L, 13)
    # ── el CAMINO (2-80): corto, todo lo aprendido, a 150 BPM ─────────────────────────────────────────────────────
    g.island(2, 12, 22, depth=7, tips=2)
    # escalera de colores: 2 filas por escalón (el mismo color, a 4)
    beeps(L, [(14, 15, 21, 'C'), (17, 18, 19, 'P'), (20, 21, 17, 'C'), (23, 24, 15, 'P')])
    g.island(26, 34, 14, depth=5, tips=1)
    L.ent('checkpoint', 28, 13)
    # pista cian de 8 bajo un techo flotante con palmas, y un rosa al final
    g.massif(36, 50, 4, 9, amp=1, shoulder=1, taper=2, tips=0)
    beeps(L, [(35, 42, 14, 'C'), (43, 45, 14, 'P')])
    for c, off in ((37, 0), (40, 1), (44, 0)):
        b = g.bottom(c, 2)
        if b and b < 12: clap(L, c, b + 1, off, 'down')
    g.island(47, 54, 15, depth=5)
    L.walker('crabby_star', 51, 14, 49, 54)
    # metrónomos entre órbitas
    met(L, 55, 15, 4, 'right')
    orbit(L, 61, 12, count=2, radius=2)
    met(L, 67, 15, 4, 'left')
    g.island(69, 76, 16, depth=6, tips=2)
    L.ent('checkpoint', 71, 15)
    L.ent('apple', 74, 15)
    # ── la ARENA (84-125 x 8-26): un templo de ladrillo estelar con columnas; el suelo es MITAD rosa MITAD cian por
    #    tramos (con cada cambio desaparece la mitad), repisas de los dos colores a dos alturas, palmas en el techo y
    #    trampolines de compás en las esquinas. El JEFE irá aquí (zona de jefe cuando exista). ──────────────────────────
    # las paredes y el techo del templo (con relieve: el techo cuelga irregular)
    g.massif(AX0 - 3, AX1 + 3, 3, AF + 3, amp=2, shoulder=2, taper=4, tips=3, veins=0.0)
    for c in range(AX0 - 3, AX1 + 4):                          # (el suelo del templo, también en los extremos)
        for r in (AF, AF + 1, AF + 2):
            if L.get(c, r) == EMPTY: L.set(c, r, IR)
    g.carve(AX0, 8, AX1, AF - 1)
    for c in range(AX0, AX1 + 1):
        for r in range(4, 8):
            if L.get(c, r) != EMPTY: L.set(c, r, BRICK)
    g.hang(AX0 + 6, AX1 - 6, 8, depth=3, tips=3)
    # la entrada (a la izquierda, a la altura del suelo) y la salida (a la derecha)
    g.carve(AX0 - 3, AF - 3, AX0 - 1, AF - 1)
    g.carve(AX1 + 1, AF - 3, AX1 + 3, AF - 1)
    # el suelo: bordes fijos de ladrillo y en medio tramos de 4 alternos (rosa / cian) sobre un foso de pinchos
    for c in range(AX0, AX1 + 1): L.set(c, AF, BRICK)
    g.carve(AX0 + 3, AF + 1, AX1 - 4, AF + 1)
    L.spikes(AX0 + 3, AX1 - 4, AF + 1)
    for i, c in enumerate(range(AX0 + 3, AX1 - 3, 4)):
        bridge(L, c, min(c + 3, AX1 - 4), AF, PINK if i % 2 == 0 else CYAN)
    # repisas: abajo de cristal (traspasables), arriba de colores
    for c0 in (AX0 + 2, AX1 - 6):
        L.plat(c0, c0 + 4, 21, PF)
    beeps(L, [(AX0 + 10, AX0 + 14, 17, 'P'), (AX1 - 14, AX1 - 10, 17, 'C'), (AX0 + 18, AX1 - 18, 14, 'P')])
    # trampolines de compás en las esquinas, palmas en el techo y columnas de adorno (plano de fondo)
    spring(L, AX0 + 1, AF - 1); spring(L, AX1 - 1, AF - 1)
    for c, off in ((AX0 + 12, 0), (AX1 - 12, 1)):
        b = g.bottom(c, 8)
        if b: clap(L, c, b + 1, off, 'down')
    # detrás: la pared del templo con ventanas y columnas cada 6
    for c in range(AX0, AX1 + 1):
        for r in range(8, AF):
            L.set_bg(c, r, WINDOW if (c % 5 == 3 and r % 4 == 1) else BRICK)
        if (c - AX0) % 6 == 1:
            for r in range(9, AF): L.set_bg(c, r, PILLAR)
    L.ent('checkpoint', AX0 - 2, AF - 1)
    # la bajada a la puerta: un saliente a ras del suelo del templo y dos peldaños de colores por el camino
    g.island(77, AX0 - 4, AF, depth=4, tips=1)
    beeps(L, [(78, 79, 20, 'P'), (77, 78, 23, 'C')])
    # la meta (mientras no haya jefe: detrás de la arena)
    g.island(AX1 + 1, SW_ - 2, AF, depth=4)
    L.finish(SW_ - 4, AF - 1)
    # fondo del camino
    for c in range(8, 80, 9):
        g.bg_spire(c, 30, g.rng.randrange(10, 20), w=g.rng.choice((5, 7)))
    g.bg_tower(5, 21, 5); g.bg_portico(28, 13, 4); g.bg_tower(72, 15, 5)
    g.bg_cloud_sea(27, 2, AX0 - 4)
    decorate(L, 17, skip=((AX0 - 3, AX1 + 3),))
    return L


BUILDERS = [pulsar, escenario_estelar, santuario_del_compas]
