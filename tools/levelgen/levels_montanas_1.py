"""Montañas Heladas, nivel 2: «EL TELEFÉRICO» (The Cable Car Pass) — de pico en pico colgado de un cable, con viento.

Diseño aprobado por el usuario: FlappyMonster_pruebas/islas_heladas/diseno.md § B (Frozen Mountains 2). Va después de
cumbres_escarcha y antes de torre_viento. Las cumbres son picos sueltos sobre simas con pinchos de hielo; entre ellos
solo se pasa en TELEFÉRICO (`cablecar`). Lo que hace cada tramo:

  1  2-17    la salida: un escalón de nieve y el primer muelle de ladrillo helado. Una Bola de Nieve en el muelle
             (se aprende su empujón donde no hay caída: a lo sumo te tira escalón abajo)
  2  18-34   el primer teleférico, LLANO y «solo con peso» (`onWeight`): espera a que subas y vuelve solo si te bajas.
             Estrella 1 encima del cable, a mitad de camino (doble salto desde la cabina)
  3  35-42   el pico P2 (8 de ancho) con una Bola de Nieve en el borde de la siguiente estación
  4  43-59   el segundo teleférico SUBE 8 filas hasta la cumbre, de ida y vuelta con esperas (hay que cogerlo a tiempo);
             un Soplón a su derecha sopla a quien pasa (fuerza 0,7: andando en contra se aguanta en la cabina)
  5  60-72   la CUMBRE (punto de control 1, un Gummy helado). En su cara de abajo, una cueva con una vida extra
  6  73-99   el CRUCE: dos cables en X. La cabina A baja de la cumbre (74,6) hacia la derecha hasta (94,14), sobre la
             sima; la B baja del pico P4 (98,8) hacia la izquierda hasta (78,16). Van a la par (mismo largo, velocidad y
             esperas: salen a la vez de las estaciones altas) y se cruzan a media bajada, la B siempre 2 filas por DEBAJO
             de la A: hay que saltar de la A a la B, que luego vuelve a subir hasta P4. Quien se queda en la A acaba
             abajo junto a la cara de P4, donde una cueva guarda la ESTRELLA ESCONDIDA (salto de 4 desde la cabina);
             la A vuelve a subir a la cumbre (se reintenta sin morir)
  7  100-128 las AGUJAS: P4 y tres agujas estrechas sobre la sima (3-5 de ancho, huecos de 2-3); Bolas de Nieve en la
             primera y la tercera, la del medio de HIELO (resbala) y un Soplón sobre el hueco entre las dos últimas
  8  129-144 el ALUD (el único del nivel): un risco de roca helada con una cornisa; el canal cae justo delante del
             túnel que lo atraviesa. Punto de control 2 al salir del túnel
  9  145-163 el último teleférico: un CIRCUITO de tres puntos con tres cabinas, «solo con peso», hasta la cumbre de la
             meta. Una VENTISCA (izquierda / derecha, fuerza 0,5: se aguanta andando en contra) sopla sobre la sima.
             Quien da la vuelta entera pasa por el punto bajo del circuito: estrella 2
 10  164-171 la cumbre de la meta

Medidas del teleférico (src/world/entities/types/mechanisms/cablecar.lua): la plataforma de la cabina queda 100 px bajo
el cable y mide 3 casillas: con el punto del cable en (c, r) se está de pie como en un suelo de la fila r + 2 (4 px más
abajo), en las casillas c-1..c+1. Por eso cada muelle acaba en la columna c-2 y su suelo es la fila r+2. Cada punto
lleva una torre hasta el suelo si lo hay a ≤ 14 casillas debajo (si no, colgaría del borde de arriba del nivel): el
fondo de cada sima está a ≤ r+14 de todos sus puntos. La cabina más baja deja 1 fila sobre los pinchos.

Cómo se hace (en este orden, como la jungla: el plano generado ANTES que las decoraciones):
    python3 tools/levelgen/build.py --only el_teleferico
    python3 tools/levelgen/retheme.py --tiles el_teleferico            # nieve / tierra / piedra
    python3 tools/levelgen/retheme.py --bg --force el_teleferico       # montes y muros helados en el plano de fondo
    python3 tools/levelgen/retheme.py el_teleferico                    # las decoraciones
    python3 tools/levelgen/levels_montanas_1.py --plane                # las casetas de las estaciones (HAND_PLANE)
(La comida — dos manzanas: antes del cruce y antes del alud — la pone el constructor: add_apples.py elegía el canal del
alud, el único sitio libre junto al punto de control 2.)

Comprobación: `level_solve` no sabe montar en teleférico. Variantes (al --out, bajo assets/levels/, y borrarlo después):
    SOLVE=bridge   cada cable, un PUENTE de plataformas traspasables por donde pasa la plataforma de sus cabinas
                   (sin las entidades del teleférico): ¿se llega a la meta? (+ EXPLORE=1: estrellas, vida, controles)
    SOLVE=gap1..4  puentes en todos MENOS en el teleférico 1 (llano), 2 (sube), 3 (el cruce: A y B) o 4 (circuito):
                   debe FALLAR — ningún tramo se salta a pie
    SOLVE=xa       en el cruce solo el puente de la A: debe FALLAR (sin la B no se llega a P4)
    python3 tools/levelgen/build.py --only el_teleferico --out assets/levels/_tele_bridge   (con SOLVE=…)
"""
import os
from lib import *

SOLVE = os.environ.get('SOLVE', '')
ID_HIGH = 2 ** 17


def enc(i): return i % 16 + (i // 16) * ID_HIGH


ICE = enc(30)
FBRICK, IROCK, IBRICK, FWINDOW, IPILLAR = enc(50), enc(51), enc(52), enc(56), enc(55)

W, H = 172, 26


class M(Level):
    def __init__(self):
        Level.__init__(self, 'El Teleférico', W, H, (4, 17), music='montana_1', modes=['race', 'hide'])
        self.extra.update(name_en='The Cable Car Pass', background='snow', time='day', snow=True, spikeSkin='ice')
        self.cables = []

    # ── piezas ───────────────────────────────────────────────────────────────
    def peak(self, c0, c1, top):
        """Pico: roca helada desde la fila `top` hasta abajo; la fila de arriba, piedra (retheme la cubre de nieve)"""
        self.rect(c0, top, c1, H - 1, IROCK)
        self.rect(c0, top, c1, top, SOLID)

    def chasm(self, c0, c1, floor):
        """Sima: vacía hasta el fondo `floor`, con pinchos de hielo encima"""
        self.clear(c0, 2, c1, H - 1)
        self.rect(c0, floor, c1, H - 1, IROCK)
        self.rect(c0, floor, c1, floor, SOLID)
        self.spikes(c0, c1, floor - 1, UP)

    def pier(self, c0, c1, top):
        """Muelle de estación: la fila de arriba del pico, de ladrillo helado"""
        self.rect(c0, top, c1, top, FBRICK)

    def cave(self, c0, c1, r0, r1):
        """Cueva en la cara de un pico (abierta hacia la sima)"""
        self.clear(c0, r0, c1, r1)

    def cable(self, k, pts, **props):
        """Teleférico `k` (1..4; el cruce son 3a y 3b) por los puntos `pts`; en las variantes del buscador, un PUENTE"""
        self.cables.append((k, pts, props.get('mode') == 'loop'))
        if SOLVE:
            return
        (c, r), rest = pts[0], pts[1:]
        self.ent('cablecar', c, r, path=[{'col': a, 'row': b} for a, b in rest], **props)

    def bridges(self):
        """(variantes del buscador) tablas traspasables donde pasa la plataforma de las cabinas de cada cable"""
        skip = set()
        if SOLVE.startswith('gap'):
            n = SOLVE[3:]
            skip = {n, n + 'a', n + 'b'}
        if SOLVE == 'xa':
            skip = {'3b'}
        for k, pts, loop in self.cables:
            if str(k) in skip:
                continue
            segs = list(zip(pts, pts[1:])) + ([(pts[-1], pts[0])] if loop else [])
            for (c0, r0), (c1, r1) in segs:
                n = max(abs(c1 - c0), abs(r1 - r0)) * 8
                for i in range(n + 1):
                    t = i / n
                    pc, pr = c0 + (c1 - c0) * t, r0 + (r1 - r0) * t
                    row = int(round(pr + 1.0625)) + 1            # (la cara de arriba de la plataforma: 100 px bajo el cable)
                    for col in range(int(pc - 1.5 + 0.999), int(pc + 1.5) + 1):
                        if self.get(col, row) == EMPTY:
                            self.set(col, row, DROP)


def el_teleferico():
    L = M()

    # 1. La salida (2-17): escalón de nieve y el primer muelle; una Bola de Nieve en él
    L.peak(2, 9, 18)
    L.peak(10, 12, 17)
    L.peak(13, 17, 16)
    L.pier(15, 17, 16)
    L.walker('snowball', 16, 15, 13, 17)

    # 2. Teleférico 1 (18-34): llano, solo con peso. Estrella 1 sobre el cable
    L.chasm(18, 34, 22)
    L.cable(1, [(19, 14), (33, 14)], speed=2.5, onWeight=True, stops=0.5)
    L.ent('star', 26, 12)

    # 3. El pico P2 (35-42), Bola de Nieve junto a la estación de salida
    L.peak(35, 42, 16)
    L.pier(35, 37, 16)
    L.pier(40, 42, 16)
    L.walker('snowball', 41, 15, 38, 42)

    # 4. Teleférico 2 (43-59): sube a la cumbre, ida y vuelta con esperas; un Soplón a su derecha
    L.chasm(43, 59, 20)
    L.cable(2, [(44, 14), (58, 6)], speed=2, stops=1.5)
    L.ent('gust', 56, 12, power=0.7)

    # 5. La cumbre (60-72): punto de control 1, Gummy helado; la cueva de la vida en su cara este
    L.peak(60, 72, 8)
    L.pier(60, 62, 8)
    L.pier(70, 72, 8)
    L.ent('checkpoint', 63, 7)
    L.walker('gummy_ice', 67, 7, 64, 69)
    L.ent('apple', 71, 7)                                          # (comida antes del cruce)
    L.cave(70, 72, 16, 17)
    L.ent('extralife', 71, 17)

    # 6. El CRUCE (73-99): A baja de la cumbre a la derecha; B baja de P4 a la izquierda, 2 filas por debajo
    L.chasm(73, 99, 20)
    L.cable('3a', [(74, 6), (94, 14)], speed=2.5, stops=1.5)
    L.cable('3b', [(98, 8), (78, 16)], speed=2.5, stops=1.5)

    # 7. Las agujas (100-128): P4 (con la cueva de la estrella escondida al pie de la A) y tres agujas
    L.peak(100, 105, 10)
    L.pier(100, 102, 10)
    L.cave(100, 102, 14, 15)
    L.ent('star', 101, 15)                                          # (estrella 3, la escondida)
    L.chasm(106, 128, 20)
    L.peak(109, 112, 12)
    L.walker('snowball', 111, 11, 109, 112)
    L.peak(116, 118, 11)
    L.rect(116, 11, 118, 11, ICE)                                  # (la aguja de hielo: resbala)
    L.peak(122, 126, 13)
    L.walker('snowball', 124, 12, 122, 126)
    L.ent('gust', 120, 9, power=0.8)

    # 8. El alud (129-144): risco de roca helada con cornisa; el canal cae delante del túnel. Punto de control 2
    L.peak(129, 144, 14)
    L.rect(136, 5, 140, 11, IROCK)                                 # el risco (el túnel por debajo: filas 12-13)
    L.rect(131, 5, 135, 6, IROCK)                                  # la cornisa
    L.rect(136, 14, 140, 14, FBRICK)                               # el suelo empedrado del túnel
    L.ent('avalanche', 132, 7, width=3, length=7, delay=1, period=5, warn=1.2, pour=1.6)
    L.ent('apple', 130, 13)                                        # (comida antes del alud, fuera del canal)
    L.ent('checkpoint', 142, 13)
    L.pier(142, 144, 14)

    # 9. El circuito final (145-163): tres cabinas, solo con peso; ventisca de lado sobre la sima. Estrella 2 abajo
    L.chasm(145, 163, 20)
    L.cable(4, [(146, 12), (162, 6), (154, 16)], mode='loop', cabins=3, speed=2.5, stops=1.5, onWeight=True)
    L.ent('star', 154, 17)
    L.ent('blizzard', 145, 2, corner={'col': 163, 'row': 18}, dir_up=False, dir_down=False, power=0.5, warn=1.2,
          blowMin=2, blowMax=3, gapMin=4, gapMax=8, firstDelay=3)

    # 10. La cumbre de la meta (164-171)
    L.peak(164, W - 1, 8)
    L.pier(164, 166, 8)
    L.finish(169, 7)

    if SOLVE:
        L.bridges()
    return L


# Las CASETAS de las estaciones en el plano de fondo (ladrillo helado con ventana): así los muelles se leen como
# estaciones. Solo rellena casillas vacías del plano (lo generado por `retheme.py --bg` y lo del usuario se queda).
#     python3 tools/levelgen/levels_montanas_1.py --plane
HAND_ROCK = [(136, 12, 140, 13)]       # el fondo del túnel del risco (si no, el risco parece flotar)
HAND_PLANE = [
    # (col0, fila0, col1, fila1, columnas con ventana en la fila del medio)
    (13, 12, 16, 15, (14, 15)),        # la salida
    (64, 4, 68, 7, (65, 67)),          # la cumbre (detrás del Gummy, no del punto de control)
    (101, 7, 104, 9, (102, 103)),      # P4, la llegada del cruce
    (164, 4, 167, 7, (165, 166)),      # la cumbre de la meta
]


def plane(path=None):
    import json
    import retheme as R
    path = path or os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels', 'el_teleferico.json')
    lv = json.load(open(path))
    H_, W_ = len(lv['tiles']), len(lv['tiles'][0])
    bg = lv.get('bgTiles') or [[0] * W_ for _ in range(H_)]
    n = 0
    for c0, r0, c1, r1, wins in HAND_PLANE:
        mid = (r0 + r1 + 1) // 2
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                if bg[r - 1][c - 1]:
                    continue
                v = FBRICK
                if r == r0: v = IBRICK                             # (el alero: sillares de hielo)
                elif r == mid and c in wins: v = FWINDOW
                bg[r - 1][c - 1] = v; n += 1
    for c0, r0, c1, r1 in HAND_ROCK:
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                if not bg[r - 1][c - 1]:
                    bg[r - 1][c - 1] = IROCK; n += 1
    order = {}
    for k, v in lv.items():
        order[k] = v
        if k == 'tiles': order['bgTiles'] = bg
    R.save(path, order)
    print('plano a mano: +%d bloques' % n)


BUILDERS = [el_teleferico]

if __name__ == '__main__':
    import sys
    if '--plane' in sys.argv: plane()
    else: print(__doc__)
