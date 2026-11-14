"""VÍA ESTELAR (Starway) — el nivel especial de los Bloques Beep (docs/design/via-estelar-level.md; mecánicas en
docs/design/beep-blocks.md y docs/design/starway-rhythm-objects.md). El más largo y laberíntico del juego: 420 x 48,
todo al compás de la música (`via_estelar`, 120 BPM: pulso 0,5 s, frase 4 s = un cambio de bloques).

    python3 tools/levelgen/build.py --only via_estelar
    tools/tests/run.sh level_solve -- assets/levels/via_estelar.json            (entero; tramos: START / GOALCOL)

Zonas (columnas):
  0. Despegue (2-19)              isla de salida, carteles
  1. Puente de cristal (20-58)    puente rosa / cian sobre el vacío; escalera de dos colores que se cambia bajo los pies
                                  (red de seguridad debajo con un trampolín de compás que te devuelve)
  2. Corredor de palmas (59-96)   pasillo de techo bajo con placas de pinchos alternas; pared de 7 que solo se sube
                                  botando EN el pulso
  3. El metrónomo (97-165)        vacío cruzado en parejas de plataformas metrónomo que se juntan en el pulso 5;
                                  ascensores metrónomo hacia el CAMINO ALTO, o bajada al CAMINO BAJO
  4. Constelación laberinto (166-262)  laberinto de 12 x 6 cámaras con PUERTAS DE CRISTAL (columnas rosas o cianes que
                                  se abren y cierran con la música), escaleras, trampolines de compás, placas y enemigos;
                                  dos Activadores escondidos abren las dos puertas de la salida
  5. Escalera estelar (263-300)   torre de 38 filas: trampolines, repisas de dos colores, ascensores, Soplones
  6. La gran sinfonía (301-418)   todo a la vez bajando hacia la meta
"""
import random
from lib import *

ID_HIGH = 2 ** 17
def enc(i): return i % 16 + (i // 16) * ID_HIGH

FR = enc(50)            # ladrillo helado (el «cristal» del camino; no resbala)
IR = enc(51)            # roca helada (lo de abajo)
ICE = enc(30)           # hielo (resbala: un tramo a propósito)
PF = enc(57)            # plataforma helada traspasable
PINK, CYAN = enc(45), enc(47)
SW_ON = 13              # Activador ON/OFF

W, H = 420, 48
VOID = H - 1            # la fila de pinchos del fondo


def isle(L, c0, c1, top, thick=3, v=FR):
    L.rect(c0, top, c1, top + thick - 1, v)
    if thick > 1: L.rect(c0, top + 1, c1, top + thick - 1, IR)


def bridge(L, c0, c1, r, v):
    L.rect(c0, r, c1, r, v)


def met(L, c, r, steps=4, d='right', oneway=True):
    p = {'steps': steps, 'dir': d}
    if not oneway: p['oneway'] = False
    return L.ent('metronome', c, r, **p)


def clap(L, c, r, offset=0):
    """placa de pinchos de palmas (sustituye al suelo de esa casilla)"""
    L.set(c, r, EMPTY)
    return L.ent('clapspikes', c, r, **({'offset': offset} if offset else {}))


def spring(L, c, r):
    """trampolín de compás apoyado en el suelo de la fila r+1"""
    return L.ent('beatspring', c, r)


def hint(L, c, r, key):
    return L.ent('hint', c, r, text=key)


# ══ 0-1 · Despegue y puente de cristal ══════════════════════════════════════════════════════════════════════════
def zone_bridge(L):
    isle(L, 2, 19, 30, thick=4)
    L.ent('checkpoint', 6, 29)
    hint(L, 9, 29, 'via.beep')
    hint(L, 16, 29, 'via.switch')
    # puente A: tramos de 3, alternos (con un color sólido, los huecos son de 3: se salta o se espera al cambio)
    for i, c in enumerate(range(20, 38, 3)):
        bridge(L, c, c + 2, 30, PINK if i % 2 == 0 else CYAN)
    isle(L, 38, 44, 30)
    L.ent('apple', 41, 29)
    # la estrella 1, colgada bajo el puente: se baja a la isleta y se vuelve con el trampolín EN el pulso
    isle(L, 26, 31, 38, thick=2)
    L.ent('star', 29, 37)
    spring(L, 27, 37)
    # puente B: escalera de dos colores (rosa abajo, cian más arriba...): al cambiar, el escalón de debajo desaparece
    bridge(L, 45, 47, 30, PINK)
    bridge(L, 49, 51, 28, CYAN)
    bridge(L, 53, 55, 26, PINK)
    bridge(L, 57, 58, 24, CYAN)
    # la red de seguridad (debajo): te devuelve arriba con el trampolín de compás
    isle(L, 44, 58, 37, thick=2)
    spring(L, 45, 36)
    hint(L, 48, 36, 'via.spring')


# ══ 2 · Corredor de palmas y pared del trampolín ════════════════════════════════════════════════════════════════
def zone_claps(L):
    isle(L, 59, 96, 24, thick=4)
    L.ent('checkpoint', 61, 23)
    # el pasillo: techo a 3 de alto (no se saltan las placas por arriba) y placas alternas
    L.rect(64, 19, 82, 20, FR)
    hint(L, 62, 23, 'via.clap')
    for c0, off in ((66, 0), (70, 1), (74, 0), (78, 1)):
        for c in (c0, c0 + 1):
            clap(L, c, 24, off)
    L.walker('gummy', 72, 23, 72, 73)
    # la pared: 7 de alto; solo se sube botando EN el pulso
    L.rect(87, 17, 96, 23, FR)
    spring(L, 85, 23)
    L.ent('apple', 92, 16)
    L.ent('checkpoint', 94, 16)


# ══ 3 · El metrónomo ════════════════════════════════════════════════════════════════════════════════════════════
def zone_metronome(L):
    # parejas que se juntan en el pulso 5 (todas van con el mismo reloj): la de la derecha va hacia la izquierda
    met(L, 97, 17, 4, 'right')
    met(L, 109, 17, 4, 'left')
    met(L, 112, 17, 4, 'right')
    met(L, 124, 17, 4, 'left')
    L.ent('gust', 117, 12, points=6)
    isle(L, 127, 134, 17)
    L.ent('checkpoint', 129, 16)
    hint(L, 131, 16, 'via.fork')
    # CAMINO ALTO: piedras de dos colores hasta la isla alta (entra arriba en el laberinto)
    bridge(L, 135, 137, 16, PINK)
    bridge(L, 139, 141, 15, CYAN)
    isle(L, 142, 165, 14, thick=2)
    L.ent('checkpoint', 145, 13)
    L.walker('crabby', 155, 13, 150, 162)
    L.plat(160, 164, 11, PF)
    L.ent('extralife', 162, 10)
    # CAMINO BAJO: el que cae desde la isla (o entre las piedras) llega a la nube de abajo: placas y Gummies
    isle(L, 128, 165, 32, thick=3)
    for c, off in ((140, 0), (141, 0), (150, 1), (151, 1), (158, 0), (159, 0)):
        clap(L, c, 32, off)
    L.walker('gummy', 145, 31, 143, 148)
    L.walker('gummy', 154, 31, 153, 156)
    L.ent('checkpoint', 162, 31)


# ══ 4 · Constelación laberinto ══════════════════════════════════════════════════════════════════════════════════
MX0, MY0, CW, CH, NX, NY = 166, 8, 8, 6, 12, 6       # cámaras de 8 x 6 (paredes de 1 compartidas)


def cell_box(i, j):
    """interior de la cámara (i, j): columnas y filas"""
    x0, y0 = MX0 + i * CW, MY0 + j * CH
    return x0 + 1, y0 + 1, x0 + CW - 1, y0 + CH - 1


def zone_maze(L, seed=7):
    rng = random.Random(seed)
    x1, y1 = MX0 + NX * CW, MY0 + NY * CH
    L.rect(MX0, MY0, x1, y1, FR)                        # todo macizo, luego se vacían las cámaras
    for i in range(NX):
        for j in range(NY):
            a, b, c, d = cell_box(i, j)
            L.clear(a, b, c, d)
    # laberinto perfecto (DFS) + algunos lazos
    links = set()
    seen, stack = {(0, 0)}, [(0, 0)]
    while stack:
        i, j = stack[-1]
        nb = [(i + di, j + dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))
              if 0 <= i + di < NX and 0 <= j + dj < NY and (i + di, j + dj) not in seen]
        if not nb:
            stack.pop(); continue
        n = rng.choice(nb)
        links.add(frozenset(((i, j), n))); seen.add(n); stack.append(n)
    extra = 0
    while extra < 14:
        i, j = rng.randrange(NX), rng.randrange(NY)
        di, dj = rng.choice(((1, 0), (0, 1)))
        n = (i + di, j + dj)
        if n[0] < NX and n[1] < NY and frozenset(((i, j), n)) not in links:
            links.add(frozenset(((i, j), n))); extra += 1
    # los pasos
    beepdoors = 0
    for lk in links:
        (ia, ja), (ib, jb) = sorted(lk)
        if ja == jb:                                   # de lado: un hueco de 3 en la pared, a ras del suelo
            wc = MX0 + ib * CW
            fl = MY0 + (ja + 1) * CH                   # fila del suelo
            if rng.random() < 0.4:                     # PUERTA DE CRISTAL: columna de un color
                L.rect(wc, fl - 3, wc, fl - 1, PINK if beepdoors % 2 == 0 else CYAN); beepdoors += 1
            else:
                L.clear(wc, fl - 3, wc, fl - 1)
        else:                                          # vertical: hueco de 2 en el suelo de la de arriba
            a, _, c, _ = cell_box(ia, ja)
            fr = MY0 + (ja + 1) * CH
            hc = a + 2 + rng.randrange(3)
            L.clear(hc, fr, hc + 1, fr)
            L.plat(hc, hc + 1, fr, PF)                 # se baja agachado, se sube por encima
            # para SUBIR: un trampolín de compás debajo del hueco, o una escalera de repisas
            _, b2, _, d2 = cell_box(ib, jb)
            if rng.random() < 0.5:
                L.ent('beatspring', hc, d2)
            else:
                L.plat(hc - 2, hc - 1, d2 - 2, PF)
                L.plat(hc + 2, hc + 3 if hc + 3 <= c else hc + 2, d2 - 4, PF)
    # entradas: arriba a la izquierda (camino alto) y en medio (camino bajo); salida abajo a la derecha
    L.clear(MX0, MY0 + CH - 3, MX0, MY0 + CH - 1)             # (0,0): suelo en la 14
    L.clear(MX0, MY0 + 4 * CH - 3, MX0, MY0 + 4 * CH - 1)     # (0,3): suelo en la 32
    L.clear(x1, y1 - 3, x1, y1 - 1)                           # (11,5): salida
    # contenido de las cámaras: según la distancia desde la entrada (BFS)
    adj = {}
    for lk in links:
        a, b = tuple(lk)
        adj.setdefault(a, []).append(b); adj.setdefault(b, []).append(a)
    dist, q = {(0, 0): 0}, [(0, 0)]
    for cur in q:
        for n in adj.get(cur, []):
            if n not in dist: dist[n] = dist[cur] + 1; q.append(n)
    deads = sorted([c for c in adj if len(adj[c]) == 1 and c not in ((0, 0), (0, 3), (NX - 1, NY - 1))],
                   key=lambda c: -dist.get(c, 0))
    # los dos Activadores: en los callejones sin salida más lejanos (uno en la mitad de arriba, otro abajo)
    up = [c for c in deads if c[1] < NY // 2]
    dn = [c for c in deads if c[1] >= NY // 2]
    acts = [up[0] if up else deads[0], dn[0] if dn else deads[1]]
    for k, (i, j) in enumerate(acts):
        a, b, c, d = cell_box(i, j)
        L.set(a + 3, d - 2, SW_ON)                 # se golpea de un cabezazo
        L.extra.setdefault('links', []).append({'col': a + 3, 'row': d - 2, 'to': k + 1})
        L.ent('apple', a + 1, d)
    used = set(acts)
    rest = [c for c in deads if c not in used]
    loot = [('star', None), ('extralife', None), ('apple', None), ('apple', None)]
    for (typ, _), (i, j) in zip(loot, rest):
        a, b, c, d = cell_box(i, j)
        L.ent(typ, a + 3, d); used.add((i, j))
    # algo en las demás: placas, enemigos
    for i in range(NX):
        for j in range(NY):
            if (i, j) in used or (i, j) in ((0, 0), (0, 3)): continue
            a, b, c, d = cell_box(i, j)
            roll = rng.random()
            if roll < 0.22:
                L.walker('gummy', a + 3, d, a + 1, c - 1)
            elif roll < 0.4:
                for cc in (a + 3, a + 4):
                    if L.get(cc, d + 1) == FR: clap(L, cc, d + 1, (i + j) % 2)
            elif roll < 0.5:
                L.walker('hopper', a + 4, d, a + 1, c - 1)
    for (i, j) in ((3, 1), (7, 4), (9, 2)):
        a, b, c, d = cell_box(i, j)
        L.ent('checkpoint', a + 1, d)
    # las dos puertas de la salida (una por Activador), fuera del laberinto
    isle(L, x1, x1 + 6, y1, thick=2)
    for k, c in enumerate((x1 + 2, x1 + 4)):
        L.ent('door', c, y1 - 1, id=k + 1, height=3)
    L.rect(x1 + 1, y1 - 6, x1 + 6, y1 - 4, FR)              # el dintel (no se saltan por arriba)
    return acts


# ══ 5 · Escalera estelar ════════════════════════════════════════════════════════════════════════════════════════
def zone_tower(L):
    """de la fila 44 a la 9: trampolín → repisa → escalera de dos colores → ascensor → repisa → trampolín → escalera
    de vuelta → repisa → la cima. Caer = volver abajo (no hay vacío dentro de la torre)."""
    isle(L, 263, 300, 44, thick=3)
    L.ent('checkpoint', 270, 43)
    hint(L, 268, 43, 'via.tower')
    spring(L, 273, 43)
    L.plat(271, 277, 37, PF)                    # P1 (de pie en la 36)
    bridge(L, 279, 282, 35, PINK)
    bridge(L, 284, 287, 33, CYAN)
    bridge(L, 289, 292, 31, PINK)
    L.plat(293, 297, 31, PF)                    # P2
    met(L, 298, 31, 4, 'up')                    # ascensor: sube a la 27
    L.plat(289, 295, 27, PF)                    # P3
    L.ent('gust', 283, 22, points=6)
    spring(L, 291, 26)
    L.plat(288, 294, 20, PF)                    # P4 (de pie en la 19)
    bridge(L, 283, 286, 18, CYAN)
    bridge(L, 278, 281, 16, PINK)
    bridge(L, 273, 276, 14, CYAN)
    L.plat(269, 272, 12, PF)                    # P5
    L.ent('apple', 270, 11)
    isle(L, 275, 300, 9, thick=2)               # la cima (el hueco 269-274 sube a ella)
    L.ent('checkpoint', 296, 8)


# ══ 6 · La gran sinfonía ════════════════════════════════════════════════════════════════════════════════════════
def zone_finale(L):
    # puente con placas: los bloques cambian Y los pinchos dan palmas
    for i, c in enumerate(range(301, 325, 3)):
        bridge(L, c, c + 2, 9, PINK if i % 2 == 0 else CYAN)
    isle(L, 325, 332, 9, thick=2)
    clap(L, 328, 9, 0); clap(L, 329, 9, 1)
    # bajada en metrónomos (la pareja que se junta) con un Soplón
    met(L, 333, 12, 4, 'right')
    met(L, 345, 12, 4, 'left')
    L.ent('gust', 340, 7, points=6)
    isle(L, 348, 356, 14)
    L.ent('checkpoint', 351, 13)
    # la escalera final: escalones de dos colores bajando, con trampolines para los que caen
    r = 16
    for i, c in enumerate(range(358, 394, 4)):
        bridge(L, c, c + 2, r, PINK if i % 2 == 0 else CYAN)
        r += 2
    isle(L, 360, 395, 40, thick=2)
    for c in (366, 378, 390):
        spring(L, c, 39)
    # la isla de la meta
    isle(L, 396, 418, 33, thick=6)
    L.finish(412, 32)
    L.ent('star', 404, 26)
    L.plat(402, 406, 28, PF)
    spring(L, 400, 32)


def via_estelar():
    L = Level('Vía Estelar', W, H, (4, 29), music='via_estelar', modes=['race'])
    L.extra.update(name_en='Starway', background='starway', time='night', light='none', timeLimit=900,
                   beat={'period': 4, 'start': 'pink'})
    L.spikes(2, W - 1, VOID)
    zone_bridge(L)
    zone_claps(L)
    zone_metronome(L)
    zone_maze(L)
    zone_tower(L)
    zone_finale(L)
    return L


BUILDERS = [via_estelar]
