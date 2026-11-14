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

# el PAQUETE ESTELAR (src/world/tiles/types/starway_pack.lua)
FR = enc(61)            # cristal estelar (el camino)
IR = enc(62)            # roca nebular (lo de debajo)
CLOUD = enc(63)         # nube maciza
BRICK = enc(64)         # ladrillo estelar (el laberinto, construcciones)
PILLAR = enc(65)        # columna de cristal
WINDOW = enc(66)        # ventana estelar (plano de fondo)
CPF = enc(67)           # nube traspasable
PF = enc(68)            # repisa de cristal traspasable
ICE = enc(30)           # hielo (resbala: un tramo a propósito)
PINK, CYAN = enc(45), enc(47)
SW_ON = 13              # Activador ON/OFF

W, H = 520, 48
DX = 100                # (las zonas 3-6 van 100 columnas más a la derecha: la Pista de baile va delante)
VOID = H - 1            # la fila de pinchos del fondo


class Shift:
    """el mismo nivel con las columnas corridas `dx` (las zonas que van detrás de la Pista de baile)"""
    def __init__(self, L, dx): self.L, self.dx, self.extra = L, dx, L.extra
    def set(self, c, r, v): self.L.set(c + self.dx, r, v)
    def get(self, c, r): return self.L.get(c + self.dx, r)
    def set_bg(self, c, r, v): self.L.set_bg(c + self.dx, r, v)
    def rect(self, c0, r0, c1, r1, v=SOLID): self.L.rect(c0 + self.dx, r0, c1 + self.dx, r1, v)
    def clear(self, c0, r0, c1, r1): self.L.clear(c0 + self.dx, r0, c1 + self.dx, r1)
    def plat(self, c0, c1, r, kind=DROP): self.L.plat(c0 + self.dx, c1 + self.dx, r, kind)
    def spikes(self, c0, c1, r, direction=UP): self.L.spikes(c0 + self.dx, c1 + self.dx, r, direction)
    def finish(self, c, r): self.L.finish(c + self.dx, r)
    def deco(self, typ, c, r, sub=None): self.L.deco(typ, c + self.dx, r, sub)
    def link(self, c, r, to): link(self.L, c + self.dx, r, to)
    def ent(self, typ, c, r, sub=None, **p):
        if 'patrol' in p: p['patrol'] = {'left': p['patrol']['left'] + self.dx, 'right': p['patrol']['right'] + self.dx}
        return self.L.ent(typ, c + self.dx, r, sub, **p)
    def walker(self, typ, c, r, l, rr, **p): return self.L.walker(typ, c + self.dx, r, l + self.dx, rr + self.dx, **p)


def link(L, c, r, to):
    if isinstance(L, Shift): return L.link(c, r, to)
    L.extra.setdefault('links', []).append({'col': c, 'row': r, 'to': to})


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
    L.walker('gummy_star', 72, 23, 72, 73)
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
    L.walker('crabby_star', 155, 13, 150, 162)
    L.plat(160, 164, 11, PF)
    L.ent('extralife', 162, 10)
    # CAMINO BAJO: el que cae desde la isla (o entre las piedras) llega a la nube de abajo: placas y Gummies
    isle(L, 128, 165, 32, thick=3)
    for c, off in ((140, 0), (141, 0), (150, 1), (151, 1), (158, 0), (159, 0)):
        clap(L, c, 32, off)
    L.walker('gummy_star', 145, 31, 143, 148)
    L.walker('gummy_star', 154, 31, 153, 156)
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
    L.rect(MX0, MY0, x1, y1, BRICK)                     # todo macizo (ladrillo estelar), luego se vacían las cámaras
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
        link(L, a + 3, d - 2, k + 1)
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
                L.walker('gummy_star', a + 3, d, a + 1, c - 1)
            elif roll < 0.4:
                for cc in (a + 3, a + 4):
                    if L.get(cc, d + 1) == BRICK: clap(L, cc, d + 1, (i + j) % 2)
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


# ══ 2b · La pista de baile (97-196): parkour TODO de Bloques Beep ══════════════════════════════════════════════════
def zone_dance(L):
    hint(L, 93, 16, 'via.dance')
    # a) SUELO ALTERNO (97-128): el suelo son parejas rosa / cian (con un color, huecos de 2) y MUROS de cristal de 3 de
    #    alto bajo un techo (no se saltan): con el rosa, los muros rosas cierran; con el cian, los cianes
    for i, c in enumerate(range(97, 129, 2)):
        bridge(L, c, c + 1, 17, PINK if i % 2 == 0 else CYAN)
    L.rect(97, 10, 128, 12, BRICK)
    for c, v in ((104, PINK), (112, CYAN), (120, PINK), (126, CYAN)):
        L.rect(c, 14, c, 16, v)
        L.rect(c, 13, c, 13, BRICK)                    # (el techo baja hasta el muro: no hay rendija encima)
    # b) LA TORRE DE DOS COLORES (129-137): escalones en zigzag, rosa y cian alternos; caer = volver al suelo de abajo
    isle(L, 129, 137, 18, thick=2, v=BRICK)
    for k, (c0, r) in enumerate(((130, 15), (134, 13), (130, 11), (134, 9))):
        bridge(L, c0, c0 + 2, r, CYAN if k % 2 == 0 else PINK)
    L.plat(129, 129, 13, PF)                           # (repisas de descanso en las paredes)
    L.plat(137, 137, 11, PF)
    # c) EL PASILLO DE MUROS (138-186), arriba: muros de cristal de techo a suelo; colores seguidos iguales = se pasan
    #    dos en la misma frase; placas de palmas entre medias
    L.rect(138, 7, 186, 8, BRICK)                      # suelo (de pie en la 6)
    L.rect(138, 2, 186, 3, BRICK)                      # techo
    for k, (c, v) in enumerate(((142, PINK), (146, CYAN), (149, CYAN), (153, PINK), (156, PINK), (160, CYAN),
                                (164, PINK), (167, PINK), (171, CYAN), (174, CYAN), (178, PINK), (182, CYAN))):
        L.rect(c, 4, c, 6, v)
    for c, off in ((144, 0), (151, 1), (158, 0), (169, 1), (176, 0)):
        clap(L, c, 7, off)
    hint(L, 139, 6, 'via.walls')
    L.ent('star', 185, 6)                              # (la estrella del pasillo: al final, antes de bajar)
    # d) la bajada a la isla del metrónomo
    L.plat(187, 189, 10, PF)
    L.plat(190, 192, 13, PF)
    isle(L, 186, 196, 17)
    L.ent('checkpoint', 191, 16)
    L.ent('apple', 194, 16)


# ══ Decoración: lo de encima de cada isla, el cielo y el PLANO DE FONDO (bloques de verdad) ═══════════════════════
# (subcelda: 3 = abajo a la izquierda, 4 = abajo a la derecha — las de arriba, 1 y 2, flotaban media casilla: el usuario)
DECO_TOP = (('crystal_cluster', 3, None), ('moon_flower', 3, 4), ('crystal_shard', 2, 3), ('crystal_shard', 1, 4),
            ('star_lantern', 0.6, None), ('telescope', 0.25, None), ('const_sign', 0.25, None), ('star_banner', 0.4, None))


def decorate(L, seed=11):
    rng = random.Random(seed)
    busy = {(e['col'], e['row']) for e in L.entities}
    busy |= {(e['col'], e['row'] + 1) for e in L.entities}
    tot = sum(w for _, w, _ in DECO_TOP)
    for c in range(3, W - 2):
        for r in range(3, H - 2):
            if L.get(c, r) != EMPTY or L.get(c, r + 1) not in (FR, CLOUD) or (c, r) in busy: continue
            if rng.random() > 0.2: continue
            if L.get(c, r + 1) == CLOUD:
                if rng.random() < 0.3: L.deco('cloud_puff', c, r)
                continue
            x = rng.random() * tot
            for name, w, sub in DECO_TOP:
                x -= w
                if x <= 0:
                    L.deco(name, c, r, sub); break
    # estrellas que flotan en el cielo abierto (fuera del laberinto y de la torre)
    for c in range(8, W - 8, 9):
        r = rng.randrange(4, 26)
        if all(L.get(cc, rr) == EMPTY for cc in range(c - 1, c + 2) for rr in range(r - 1, r + 2)) \
           and not (MX0 + DX - 2 <= c <= MX0 + DX + NX * CW + 2) and not (263 + DX <= c <= 300 + DX):
            L.deco('floating_star', c, r)


def backplane(L, seed=5):
    """el PLANO DE FONDO: ruinas de ladrillo estelar con ventanas y columnas de cristal detrás de las islas grandes, y
    la pared del templo detrás de todo el laberinto"""
    rng = random.Random(seed)
    # detrás del laberinto: ladrillo con ventanas cada 4 x 3 (dentro de las cámaras se ve la pared del templo)
    x0, y0 = MX0 + DX, MY0
    for c in range(x0, x0 + NX * CW + 1):
        for r in range(y0, y0 + NY * CH + 1):
            L.set_bg(c, r, WINDOW if (c % 4 == 2 and r % 3 == 1) else BRICK)
    # ruinas: detrás de cada tramo de suelo de 8 o más casillas, una torre o un pórtico
    c = 3
    while c < W - 10:
        top = next((r for r in range(4, H - 2) if L.get(c, r) == FR and L.get(c, r - 1) == EMPTY), None)
        if top is None or (x0 - 4 <= c <= x0 + NX * CW + 4):
            c += 1; continue
        run = 0
        while c + run < W - 1 and L.get(c + run, top) == FR and L.get(c + run, top - 1) == EMPTY: run += 1
        if run >= 8:
            kind = rng.random()
            a = c + 1 + rng.randrange(max(1, run - 6))
            if kind < 0.5:                             # torre con ventanas
                h = rng.randrange(4, 8)
                for cc in range(a, a + 3):
                    for rr in range(top - h, top):
                        L.set_bg(cc, rr, WINDOW if (cc == a + 1 and (top - rr) % 3 == 2) else BRICK)
            else:                                      # pórtico: dos columnas y un dintel
                h = rng.randrange(3, 6)
                for rr in range(top - h, top):
                    L.set_bg(a, rr, PILLAR); L.set_bg(a + 4, rr, PILLAR)
                for cc in range(a, a + 5): L.set_bg(cc, top - h - 1, BRICK)
        c += max(run, 1)


def via_estelar():
    L = Level('Vía Estelar', W, H, (4, 29), music='via_estelar', modes=['race'])
    L.extra.update(name_en='Starway', background='starway', time='night', light='none', timeLimit=900,
                   beat={'period': 4, 'start': 'pink'})
    L.spikes(2, W - 1, VOID)
    zone_bridge(L)
    zone_claps(L)
    zone_dance(L)
    S = Shift(L, DX)
    zone_metronome(S)
    zone_maze(S)
    zone_tower(S)
    zone_finale(S)
    backplane(L)
    decorate(L)
    return L


BUILDERS = [via_estelar]
