"""Las Montañas Heladas, nivel 4: «La Ladera del Alud» (ladera_del_alud) — un DESCENSO, lo contrario de torre_viento.

Diseño aprobado por el usuario (FlappyMonster_pruebas/islas_heladas/diseno.md, §B Montañas 4): se BAJA por la cara de un
acantilado mientras los CANALES DE ALUD (`avalanche`) barren las columnas; a cubierto bajo las repisas; CORNISAS de
nieve que se hunden con tu peso (hielo fino, ya agrietado); Bolas de Nieve (`snowball`) que te echan de las repisas.
Acaba en la orilla del lago helado (el nivel siguiente es el jefe, lago_helado). Fondo `snow`, atardecer, `montana_2`.

    python3 tools/levelgen/build.py --only ladera_del_alud
    python3 tools/levelgen/retheme.py ladera_del_alud           (decoraciones de la nieve)
    python3 tools/levelgen/retheme.py --bg ladera_del_alud      (estructuras en el plano de fondo)

48 x 64, cinco PISOS en zig-zag hacia abajo (como la torre, pero bajando). Toda la roca es `ice_rock` (paquete helado)
con una capa de nieve encima de lo que queda al aire; las repisas de hielo fino son las cornisas.

  fila  2 ┌ techo de la montaña ─────────────────────┐   cielo   ┌ cima: SALIDA (estrella escondida bajo el hielo) ┐
  1.  5-9 │ ← la CRESTA: dos canales, una grieta, Bola │                                                          │
       10 └─ cornisa sobre el pozo (se hunde: bajas) ──┴─────────────────────────────────────────────────────────┘
  2. 14-20  → el CORREDOR DE LOS ALUDES: cuatro canales en LÍNEA ESCALONADA (la ola va a tu paso), fosos con pinchos
            bajo dos de ellos, estrella en una tabla dentro de un canal, Bola al final; PUNTO DE CONTROL 1; pozo abajo.
  3. 25-36  ← LAS CORNISAS: un barranco con pinchos al fondo; agujas de roca con cornisas que se hunden; un canal sobre
            una cornisa; una Bola que embiste desde la repisa de la izquierda; pozo abajo.
  4. 39-50  → LOS CORREDORES DE ALUD: tres mesetas separadas por dos canales enteros (couloirs) con pinchos al fondo;
            se cruzan entre aluvión y aluvión; PUNTO DE CONTROL 2; una Bola que te devuelve al canal.
  5. 53-59  ← EL PIE DE LA LADERA: la última línea de canales (la ola hacia la izquierda), Gummies y un Crabby helados,
            y la META en la orilla del lago helado.

Comprobación (level_solve no rompe el hielo fino ni ve los aludes ni a las Bolas): `OPEN=1` = la cornisa del pozo
del piso 1 ya hundida (es la única que hay que romper para seguir) y la trampilla de la estrella escondida rota. El resto de cornisas son suelo para el solver
(en el juego aguantan 2,4 s de pie: hay que cruzarlas sin pararse).
    OPEN=1 python3 tools/levelgen/build.py --only ladera_del_alud --out <carpeta>
`RSTART=c,f` mueve la salida (p. ej. `RSTART=44,10`: ¿se sale del hueco de la estrella escondida?).
"""
import os
from lib import *

ID_HIGH = 2 ** 17
OPEN = bool(os.environ.get('OPEN'))


def enc(i): return i % 16 + (i // 16) * ID_HIGH


SNOW, ICE = enc(29), enc(30)
ROCK = enc(51)                      # roca helada (paquete helado): la montaña entera
CORNICE = enc(32)                   # hielo fino YA AGRIETADO (estado 1): 3 × 0,8 s de pie y se hunde
CORNICE_NEW = enc(31)               # hielo fino entero (4 × 0,8 s): la trampilla de la estrella escondida
FPLAT = enc(57)                     # tablones helados (traspasables)

W, H = 48, 64


def aval(L, c, r, width, length, delay, period=6.0, warn=1.2, pour=2.2):
    """Un canal de alud colgado de la roca de encima (casilla de arriba a la izquierda del canal)"""
    return L.ent('avalanche', c, r, width=width, length=length, delay=delay, period=period, warn=warn, pour=pour)


def ladera_del_alud():
    L = Level('La Ladera del Alud', W, H, (43, 8), music='montana_2', modes=['race'])
    if os.environ.get('RSTART'):                             # (para el solver: otra salida, p. ej. el hueco de la estrella)
        L.start = [int(x) for x in os.environ['RSTART'].split(',')]
    L.extra.update(name_en='Avalanche Slope', background='snow', time='dusk', snow=True, spikeSkin='ice')
    L.rect(2, 2, W - 1, H - 1, ROCK)                         # la montaña: se excava

    # ── 1. La cresta (filas 2-13, hacia la izquierda) ────────────────────────────────────────────────────────────
    L.clear(30, 2, W - 1, 8)                                 # cielo sobre la cima
    L.clear(30, 9, 35, 9)                                    # (escalón de la cima a la cresta)
    L.clear(3, 5, 35, 9)                                     # la cresta, bajo el techo de la montaña (filas 2-4)
    # estrella ESCONDIDA: detrás de la salida, una trampilla de hielo entero sobre un hueco de dos filas (con un escalón
    # bajo la trampilla para volver a salir: el jugador mide más de una casilla)
    L.clear(42, 10, W - 1, 11)
    L.set(46, 11, ROCK)
    L.rect(45, 9, 46, 9, EMPTY if OPEN else CORNICE_NEW)
    L.ent('star', 43, 11)
    # canal 1 sobre una grieta con pinchos (cruzar mientras cae = la nieve te mete en la grieta)
    aval(L, 25, 5, 3, 9, delay=0.5, period=5.0, pour=2.0)
    L.clear(26, 10, 27, 11)
    L.spikes(26, 27, 12, UP)
    # la Bola de la cresta: te ve llegar sobre la grieta y embiste hacia ella
    L.walker('snowball', 19, 9, 16, 22)
    aval(L, 12, 5, 3, 5, delay=2.5, period=5.0, pour=2.0)    # canal 2 (a contratiempo del 1)
    # la cornisa sobre el pozo: única bajada; se hunde bajo tu peso
    L.clear(3, 10, 6, 13)
    if not OPEN:
        L.rect(3, 10, 6, 10, CORNICE)

    # ── 2. El corredor de los aludes (filas 14-24, hacia la derecha) ────────────────────────────────────────────
    L.clear(3, 14, 46, 20)                                   # suelo en la fila 21
    # cuatro canales de 4 en LÍNEA ESCALONADA: 7 casillas y 1,9 s entre uno y otro = la ola va a tu paso
    for i, c in enumerate((9, 16, 23, 30)):
        aval(L, c, 14, 4, 10, delay=1.0 + 1.9 * i, period=7.6, pour=2.2)
    for c in (17, 31):                                       # fosos con pinchos bajo dos canales
        L.clear(c, 21, c + 1, 22)
        L.spikes(c, c + 1, 22, UP)
    L.plat(24, 25, 17, FPLAT)                                # una tabla DENTRO del canal 3: arriba la estrella (en
    L.ent('star', 24, 16)                                    # el chorro); debajo, un refugio en mitad del canal
    L.walker('gummy_ice', 21, 20, 20, 22)                    # (en el refugio entre los canales 2 y 3)
    L.walker('snowball', 28, 20, 27, 29)                     # en el refugio entre los canales 3 y 4: te devuelve al 3
    L.walker('gummy_ice', 37, 20, 35, 39)
    L.ent('checkpoint', 42, 20)
    L.ent('apple', 40, 20)
    L.clear(44, 21, 46, 24)                                  # el pozo al piso 3

    # ── 3. Las cornisas (filas 25-36, hacia la izquierda) ────────────────────────────────────────────────────────
    L.clear(3, 25, 46, 35)
    L.spikes(15, 46, 36, UP)                                 # el fondo del barranco
    L.rect(41, 27, 46, 28, ROCK)                             # repisa de llegada (pegada a la pared)
    L.rect(33, 29, 34, 36, ROCK)                             # aguja 1
    L.rect(35, 29, 37, 29, CORNICE)                          #   y su cornisa
    L.rect(24, 31, 25, 36, ROCK)                             # aguja 2 (encima, a cubierto)
    L.rect(26, 31, 28, 31, CORNICE)                          #   cornisa en el canal
    L.rect(21, 31, 23, 31, CORNICE)                          #   cornisa del otro lado
    aval(L, 26, 25, 4, 12, delay=0.5, period=5.5, pour=2.0)
    L.ent('star', 28, 28)                                    # en el chorro, sobre la cornisa
    L.rect(2, 33, 14, 35, ROCK)                              # la repisa de la izquierda (pegada a la pared)
    L.rect(15, 33, 18, 33, CORNICE)                          #   con su cornisa
    L.walker('snowball', 12, 32, 9, 14)                      # embiste cuando aterrizas en la cornisa
    aval(L, 8, 25, 3, 8, delay=3.0, period=5.5, pour=2.0)    # canal sobre la repisa
    L.ent('apple', 6, 32)
    L.clear(3, 33, 4, 38)                                    # el pozo al piso 4

    # ── 4. Los corredores de alud (filas 39-52, hacia la derecha) ───────────────────────────────────────────────
    L.clear(3, 39, 46, 41)
    L.clear(12, 42, 46, 44)
    L.clear(30, 45, 46, 47)
    for c0 in (12, 30):                                      # dos couloirs de 4 con pinchos al fondo
        L.clear(c0, 39, c0 + 3, 50)
        L.spikes(c0, c0 + 3, 50, UP)
        aval(L, c0, 39, 4, 12, delay=0.5 if c0 == 12 else 3.0, period=6.0, pour=2.4)
    L.ent('checkpoint', 19, 44)
    L.walker('snowball', 27, 44, 26, 29)                     # te ve en el montículo y te echa al couloir (desde el
                                                             # punto de control, a 7 casillas, aún no te ve)
    L.walker('gummy_ice', 40, 47, 36, 44)
    L.ent('apple', 37, 47)
    L.clear(44, 48, 46, 52)                                  # el pozo al pie de la ladera

    # ── 5. El pie de la ladera y el lago helado (filas 53-63, hacia la izquierda) ──────────────────────────────
    L.clear(3, 53, 46, 59)                                   # suelo en la fila 60
    for i, c in enumerate((37, 30, 23)):                     # la última línea: la ola va hacia la izquierda
        aval(L, c, 53, 3, 7, delay=1.0 + 1.9 * i, period=7.0, pour=2.2)
    L.walker('crabby_ice', 34, 59, 33, 35)
    L.walker('gummy_ice', 27, 59, 26, 29)
    L.walker('snowball', 21, 59, 18, 22)
    # el lago helado: hielo sobre agua, a la izquierda; la meta en la orilla
    L.clear(3, 60, 14, 62)
    L.rect(3, 60, 14, 60, ICE)
    L.water(3, 61, 14, 62)
    L.finish(16, 59)

    # ── Dientes de roca bajo cada techo (que no parezcan pasillos; nunca encima de un canal ni de un pozo) ─────────
    for c0, c1, r, h in ((7, 9, 5, 1), (17, 20, 5, 1), (29, 29, 5, 2),                       # techo del piso 1
                         (7, 7, 14, 1), (14, 14, 14, 2), (21, 22, 14, 1), (27, 28, 14, 2), (35, 38, 14, 1), (41, 41, 14, 2),
                         (3, 5, 25, 2), (12, 14, 25, 1), (19, 21, 25, 2), (31, 33, 25, 1), (37, 40, 25, 2),
                         (6, 8, 39, 1), (18, 21, 39, 2), (25, 27, 39, 1), (36, 40, 39, 1),
                         (4, 7, 53, 1), (27, 28, 53, 2), (33, 35, 53, 1), (41, 43, 53, 2)):
        L.rect(c0, r, c1, r, ROCK)
        if h > 1: L.rect(c0 + (c1 > c0), r + 1, c1 - (c1 > c0 + 1), r + 1, ROCK)
    for c0, c1, r in ((13, 15, 20), (40, 43, 59), (20, 23, 44)):                              # montículos en el suelo
        L.rect(c0, r, c1, r, ROCK)

    # ── Nieve: dos filas encima de la roca al aire ──────────────────────────────────────────────────────────────
    for c in range(2, W):
        for r in range(3, H):
            if L.get(c, r) == ROCK and L.get(c, r - 1) in (EMPTY, FINISH):          # (bajo pinchos o agua, roca)
                L.set(c, r, SNOW)
                if L.get(c, r + 1) == ROCK: L.set(c, r + 1, SNOW)
    return L


BUILDERS = [ladera_del_alud]
