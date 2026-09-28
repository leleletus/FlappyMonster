"""Niveles de caza (sin meta): solo Cazamonstruos. Hay que pisar a todos los enemigos."""
from lib import *
from levels_run import pit


def ciudadela_cangrejos():
    """Fortaleza de cinco pisos: cangrejos en paredes y techos, azoteas, suelos rompibles y nichos."""
    L = Level('Ciudadela de Cangrejos', 96, 26, (6, 23), music='hidro_city', modes=['hunt'])
    G = 24
    L.terrain(2, 95, G)
    # ── planta baja ──
    L.walker('gummy', 16, G - 1, 10, 22)
    L.walker('gummy', 70, G - 1, 62, 80)
    L.walker('crabby', 44, G - 1, 36, 52)
    L.ent('crabby', 88, G - 1, wallWalk=True, patrol=False, speed=60)
    L.ent('checkpoint', 48, G - 1)
    # ── pisos 1..4: losas escalonadas (3 filas de separación) ──
    tiers = [(21, [(10, 16), (26, 32), (44, 50), (62, 68), (80, 86)]),
             (18, [(18, 24), (34, 40), (52, 58), (70, 76), (88, 93)]),
             (15, [(10, 16), (26, 32), (44, 50), (62, 68), (80, 86)]),
             (12, [(18, 24), (34, 40), (52, 58), (70, 76), (88, 93)])]
    for ti, (row, segs) in enumerate(tiers):
        for si, (a, b) in enumerate(segs):
            L.plat(a, b, row, DROP if (ti + si) % 2 else SLAB)
            if (ti + si) % 3 == 0:
                L.walker('gummy', (a + b) // 2, row - 1, a, b)
            elif (ti + si) % 3 == 1:
                L.walker('crabby', (a + b) // 2, row - 1, a, b)
    # pilares con cangrejos trepadores
    for c in (30, 60):
        L.rect(c, 13, c + 1, G - 1, SOLID)
        L.ent('crabby', c - 1, G - 1, wallWalk=True, patrol=False, speed=55)
    # ── azotea (fila 10) con huecos sobre el piso 4 y cangrejos colgantes ──
    L.rect(6, 10, 90, 10, SOLID)
    for c in (20, 36, 54, 72, 90):
        L.clear(c, 10, c + 1, 10)                       # huecos para subir
    L.walker('gummy', 28, 9, 22, 34)
    L.walker('gummy', 62, 9, 56, 70)
    L.walker('crabby', 84, 9, 78, 88)
    L.ent('star', 40, 8)
    L.ent('extralife', 78, 8)
    L.ent('crabby', 26, 11, attach='ceiling', dropOnSight=True, detectRange=8, patrol=False)
    L.ent('crabby', 66, 11, attach='ceiling', dropOnSight=True, detectRange=8, patrol=False)
    # ── nicho de gateo con premio (salto agachado) ──
    L.rect(2, G - 2, 5, G - 2, SOLID)
    L.rect(2, G - 1, 2, G - 1, SOLID)
    L.ent('star', 3, G - 1)
    # ── cámara sobre la azotea: el suelo es rompible, se entra de un cabezazo desde abajo ──
    L.rect(44, 3, 53, 7, SOLID)
    L.clear(45, 4, 52, 6)
    L.rect(45, 7, 52, 7, BREAK)
    L.walker('crabby', 47, 6, 45, 52)
    L.walker('gummy', 51, 6, 45, 52)
    L.ent('extralife', 49, 5)
    # trampolines para subir rápido
    L.ent('trampoline', 12, G - 1)
    L.ent('trampoline', 76, G - 1)
    return L


def jardin_gummies():
    """Jardín abierto y amplio: colinas, fosos y muchos gummies (algunos vuelan)."""
    L = Level('Jardín de Gummies', 120, 16, (5, 13), music='classic', modes=['hunt'])
    G = 14
    L.terrain(2, 119, G)
    hills = [(2, 14, G), (15, 24, G - 1), (25, 34, G - 2), (35, 44, G - 1), (45, 54, G),
             (59, 72, G - 1), (73, 84, G - 2), (85, 96, G - 1), (97, 104, G), (109, 119, G - 1)]
    for a, b, top in hills:
        L.terrain(a, b, top)
    pit(L, 55, 58, 15)
    pit(L, 105, 108, 15)
    for c in (8, 30, 50, 64, 90, 114):
        L.deco('palmtree', c, [h for h in hills if h[0] <= c <= h[1]][0][2] - 1)
    for c in (12, 38, 76, 100):
        L.deco('tulip', c, [h for h in hills if h[0] <= c <= h[1]][0][2] - 1, sub=4)
    for a, b, top in hills:
        mid = (a + b) // 2
        L.walker('gummy', mid, top - 1, a, b)
        if b - a > 8:
            L.walker('gummy', a + 2, top - 1, a, mid)
    # cangrejos y voladores
    L.walker('crabby', 29, G - 3, 26, 33)
    L.walker('crabby', 78, G - 3, 74, 83)
    L.ent('gummy', 20, 9, movement='fly', patrol={'left': 15, 'right': 26}, speed=70)
    L.ent('gummy', 56, 9, movement='fly', patrol={'left': 50, 'right': 62}, speed=70)
    L.ent('gummy', 92, 9, movement='fly', patrol={'left': 85, 'right': 100}, speed=70)
    # plataformas altas con premios
    for c, r in ((18, 10), (40, 9), (66, 10), (88, 9), (112, 10)):
        L.plat(c, c + 5, r, DROP)
        L.walker('gummy', c + 2, r - 1, c, c + 5)
        L.ent('star', c + 2, r - 2)
    L.ent('extralife', 56, 12)
    L.ent('checkpoint', 46, G - 1)
    L.ent('checkpoint', 98, G - 1)
    L.ent('spikefall', 70, 2, sub=1) if False else None
    return L


def mina_inundada():
    """Mina en dos niveles: galerías secas arriba, aguas con respiraderos abajo, muros rompibles."""
    L = Level('Mina Inundada', 100, 26, (12, 11), music='labyrinth', modes=['hunt'])
    L.rect(2, 2, 99, 25, SOLID)

    def carve(c0, c1, r0, r1):
        L.clear(c0, r0, c1, r1)

    # galería superior (filas 8..11), suelo fila 12
    carve(2, 97, 8, 11)
    for c in (20, 44, 68):
        L.rect(c, 8, c + 1, 10, SOLID)              # columnas: pasar por debajo (gateo)
        L.ent('checkpoint', c - 3, 11) if c == 44 else None
    L.walker('gummy', 16, 11, 12, 18)
    L.walker('crabby', 30, 11, 24, 40)
    L.walker('gummy', 55, 11, 47, 65)
    L.walker('crabby', 80, 11, 72, 92)
    L.ent('star', 32, 9)
    # pozos de acceso a la parte baja (romper con ground pound)
    for c in (16, 38, 60, 84):
        L.rect(c, 12, c + 2, 12, BREAK)
        carve(c, c + 2, 13, 14)
    # nivel medio (filas 15..17): túneles de un solo alto = salto agachado
    carve(2, 97, 15, 17)
    L.rect(2, 18, 97, 18, SOLID)
    for c in (28, 52, 76):
        L.rect(c, 15, c + 5, 16, SOLID)              # túnel de 1 de alto
    L.walker('gummy', 10, 17, 4, 24)
    L.walker('crabby', 42, 17, 33, 50)
    L.walker('gummy', 66, 17, 58, 72)
    L.walker('crabby', 90, 17, 80, 95)
    L.ent('extralife', 30, 17)
    L.ent('star', 54, 17)
    # nivel bajo: agua profunda con respiraderos y cangrejos en islas
    carve(2, 97, 19, 24)
    L.water(2, 21, 97, 24)
    for i, c in enumerate((14, 34, 54, 74, 92)):
        L.rect(c, 21, c + 4, 24, SOLID)
        L.rect(c - 2, 23, c - 1, 24, SOLID)                # peldaños para salir del agua
        L.rect(c + 5, 23, c + 6, 24, SOLID)
        L.walker('crabby' if i % 2 else 'gummy', c + 2, 20, c, c + 4)
        L.vent(c + 8 if c < 90 else c - 6, 24, 3)
    L.ent('checkpoint', 6, 20)
    # acceso desde el nivel medio al agua (aberturas)
    for c in (22, 46, 70):
        L.clear(c, 18, c + 2, 18)
    L.ent('star', 31, 21)
    # piedras entre islas (la cabeza asoma sobre el agua): evitan largos tramos a nado
    for c in (28, 41, 62, 65):
        L.rect(c, 22, c + 1, 24, SOLID)
    # islas bajo las aberturas + peldaños para volver a subir
    for c in (21, 45, 69):
        L.rect(c, 21, c + 3, 24, SOLID)
    # pozos de escalera (izquierda y derecha) que unen los tres niveles
    for c0 in (3, 89):
        c1 = c0 + 6
        carve(c0, c1, 8, 20)
        for i, r in enumerate(range(20, 9, -2)):
            a = c0 if i % 2 == 0 else c1 - 3
            L.plat(a, a + 3, r, DROP)
    # más habitantes
    L.walker('gummy', 24, 11, 22, 28)
    L.walker('crabby', 50, 17, 44, 56)
    L.walker('gummy', 74, 11, 70, 78)
    L.walker('gummy', 40, 17, 36, 44)
    return L


BUILDERS = [ciudadela_cangrejos, jardin_gummies, mina_inundada]
