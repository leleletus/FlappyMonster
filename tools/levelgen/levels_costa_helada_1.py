"""La Costa Helada, nivel 2: «Témpanos a la Deriva» (Drifting Floes) — cruzar un mar polar sobre ICEBERGS.

Diseño aprobado por el usuario (FlappyMonster_pruebas/islas_heladas/diseno.md § B, Costa 2, con su corrección: los
icebergs NO se agrietan y NO derivan solos; solo se mueven EMPUJADOS o SOPLADOS). Va después de fabrica_criogenica.
El mar es AGUA HELADA (`coldWater`): caer congela a los pocos segundos (se sale machacando botones) y los peces globo
suben del fondo de las fosas; en cada orilla de llegada hay ESCALONES bajo el agua para salir (caer no atasca nunca).

Medidas: el hielo de las orillas tiene la cara de arriba en la fila SH = 16 (de pie en la 15); el agua empieza en la
fila WS = 17 (superficie = 1 casilla por debajo de las orillas). Un iceberg de 1 de alto asoma 0,3: queda 0,7 por
debajo de la orilla (se baja a él y se vuelve a subir de un salto; desde la orilla no se empuja, está más abajo).

Tramos (columnas):
  1  2-19    el MUELLE (ladrillo helado) y el primer témpano, quieto en un canal de 8: bajar, subir, aprender que el
             agua congela (los escalones de la otra orilla)
  2  20-43   el TÉMPANO VARADO: un iceberg en seco sobre la plataforma; se EMPUJA andando hasta que cae al canal (7 de
             ancho: sin él no se salta) y queda de piedra de paso (cae justo en el borde: siempre igual). Pez globo en la fosa
  3  44-61   el SOPLÓN: del acantilado (fila 12) se baja al iceberg del canal (11 de ancho); un Soplón metido en un
             nicho del acantilado, a la altura del iceberg (no ve a quien va por arriba), sopla en cuanto te subes y os
             lleva hacia la otra orilla (aguanta hacia atrás o te tira al agua). Sin soplo, el hueco es de 6: no se salta
  4  62-81   punto de control 1, la caja pequeña y la CASA DE HIELO con el POZO: un iceberg de 2 tapa el pozo justo a la
             altura de un túnel inundado de 1 de alto. Con la caja en brazos (jugador + caja = 2 > 1,5) se HUNDE A
             PROPÓSITO, baja a la altura del túnel y se pasa (salto agachado) a la gruta de la ESTRELLA ESCONDIDA (+ una
             vida). Se sale por arriba, por un bloque invisible (de dentro afuera; desde arriba no se baja). Sin la caja,
             del pozo se sale por una repisa
  5  82-99   los TÉMPANOS FINOS: cuatro icebergs pequeños que aguantan menos que un jugador (`capacity` 0,8): se hunden a
             los 0,7 s de pisarlos y vuelven a flotar: saltar sin pararse. Dos peces globo suben de la fosa. Estrella 1 en
             lo alto, sobre el tercero (saltar ahí es mojarse)
  6  100-127 el GLACIAR de los PINGÜINOS: un banco de nieve, un pingüino en la nieve (andando; al verte se tira de
             barriga hacia ti, rebota en el banco), una GRIETA de 2 con agua helada: pisado, el pingüino es un TRINEO que
             la cruza (estrella 2 encima de la grieta); al otro lado, hielo resbaladizo bajo un arco con dos carámbanos que
             caen y un Crabby helado. Punto de control 2
  7  128-165 el MAR ABIERTO: dos canales (13 y 12 de ancho) con un islote en medio y un iceberg grande en cada uno; una
             VENTISCA sobre cada canal sopla a rachas SOLO hacia la derecha (aviso de 1 s): el iceberg avanza ~3 casillas
             por racha (el jugador, más: hay que aguantar hacia atrás). En el islote, un PINGÜINO: si se tira de barriga a
             tu iceberg, lo SOBRECARGA (2 > 1,5) y se hunde — un ground pound lo quita —. La meta en el muelle del final

Cómo se hace (el plano generado ANTES que las decoraciones, como en la jungla):
    python3 tools/levelgen/build.py --only tempanos_a_la_deriva
    python3 tools/levelgen/retheme.py --tiles tempanos_a_la_deriva        # el terreno de la costa helada
    python3 tools/levelgen/retheme.py --bg --force tempanos_a_la_deriva   # el plano de fondo (ventisqueros, muros de hielo)
    python3 tools/levelgen/retheme.py tempanos_a_la_deriva                # las decoraciones
    python3 tools/levelgen/levels_costa_helada_1.py --plane               # lo del plano que va a mano (HAND_PLANE)
La comida (dos manzanas, junto a los puntos de control) la pone este constructor: add_apples.py no conoce el paquete
helado.

Comprobación (level_solve no mueve icebergs, no sopla ni carga cajas): SOLVE=<variante> + --out a una carpeta BAJO
assets/levels/ (level_solve lee por love.filesystem; borrarla después):
    SOLVE=fixed  python3 tools/levelgen/build.py --only tempanos_a_la_deriva --out assets/levels/_tempanos
        cada iceberg, una losa fija donde acaba (el varado, caído en el borde; los soplados, 3 casillas más allá —
        una racha—; el del pozo tapándolo; los finos en su sitio): ¿se llega a la meta? (la losa queda 0,3 más baja que
        el iceberg de verdad: más difícil, nunca más fácil)
    SOLVE=home   los icebergs donde EMPIEZAN (el varado, fuera del canal; sin soplar): pasa, pero a nado (ver abajo)
    SOLVE=swim   sin icebergs y el agua sin congelar: ¿todo el mar se cruza y se sale a nado? (caer no atasca)
    SOLVE=coldswim  sin icebergs, con el agua helada (el buscador ya cuenta el frío y el bloque de hielo)
    SOLVE=star   el iceberg del pozo, HUNDIDO (una losa a la altura del túnel), la salida encima, la meta en la gruta
    SOLVE=nostar el pozo tapado: la meta en la gruta debe FALLAR (ni por el túnel ni por el bloque invisible)
    SOLVE=star_out  salida en la gruta, la meta de verdad (se sale por el bloque invisible)
    SOLVE=well   salida en el iceberg del pozo, sin caja: se sale por la repisa
Resultados (2026-10-29, MAXN=400000): fixed OK (613 acciones), swim OK, coldswim OK (todo el mar se puede cruzar a
nado aun helado: es el castigo — congelarse, los peces globo —, no un atasco), star OK, nostar FALLA (lo más cerca, de
pie en el bloque invisible), star_out OK, well OK. Sin soplo / sin empujar, los huecos son de 6-7 casillas (a saltos no
se cruzan; se cruzarían a nado). Lo que el buscador NO prueba: que el Soplón y las ventiscas lleven de verdad los icebergs
esas ~3 casillas, que el varado caiga limpio al canal y el hundimiento con la caja — necesita jugarlo una persona.
Aprendido al comprobar: escalones de 2 en 2 bajo el agua no se suben (el salto que saca la cabeza se queda corto) → de
1 en 1; una fosa pegada a los escalones tampoco (del fondo de la fosa al escalón, 2) → separadas.
"""
import os
from lib import *

SOLVE = os.environ.get('SOLVE', '')
ID_HIGH = 2 ** 17


def enc(i): return i % 16 + (i // 16) * ID_HIGH


FBRICK, IROCK, IBRICK, GLACIER, SBRICK = enc(50), enc(51), enc(52), enc(53), enc(54)
FPLAT = enc(57)
HIDDEN = 15                     # bloque invisible: se atraviesa subiendo, de pie encima, no se baja

W, H = 166, 24
SH = 16          # cara de arriba de las orillas (de pie en la 15)
WS = 17          # primera fila de agua: la superficie está 1 casilla por debajo de las orillas
BED = 20         # fondo del mar (3 de agua)
DEEP = 21        # fondo de las fosas (4 de agua): de ahí suben los peces globo
COLD = 2.5       # s en el agua helada hasta congelarse (× el aire de la dificultad)

SWIM = SOLVE in ('swim', 'coldswim')                                     # (sin icebergs)
SLABS = SOLVE in ('fixed', 'home', 'nostar', 'star_out', 'well', 'star')   # (icebergs → losas fijas)
HOME = SOLVE == 'home'


def tempanos_a_la_deriva():
    L = Level('Témpanos a la Deriva', W, H, (4, SH - 1), music='nieve_1', modes=['race', 'hide'])
    L.extra.update(name_en='Drifting Floes', background='frozen_coast', time='day')
    if SOLVE != 'swim':
        L.extra['coldWater'] = COLD
    L.ground(2, W - 1, SH)

    # ── piezas ───────────────────────────────────────────────────────────────
    def sea(c0, c1, bed=BED):
        """Un canal: aire arriba, agua de la fila WS al fondo"""
        L.clear(c0, 2, c1, H - 1)
        L.rect(c0, WS, c1, bed - 1, WATER)
        L.rect(c0, bed, c1, H - 1, SOLID)

    def trench(c0, c1):
        """Una fosa 1 más honda en el fondo de un canal (los peces globo suben de ahí); nunca junto a los escalones de
        una orilla (del fondo de la fosa al escalón serían 2)"""
        L.rect(c0, BED, c1, DEEP - 1, WATER)

    def stairs(s, d):
        """Escalones para salir del agua junto a la orilla `s` (su primera columna; el agua hacia `d`): tres de 1 casilla
        desde el fondo, el último a ras de la superficie (de pie, seco; de ahí, 1 a la orilla). Bajo el agua se salta
        poco y el salto que saca la cabeza se queda corto: de 2 en 2 no se salía (SOLVE=swim)"""
        for k in range(3):
            L.rect(s + (k + 1) * d, WS + k, s + (k + 1) * d, H - 1, SOLID)

    def floe(c, w, cap=1.5, slab=None, row=WS - 1):
        """Un iceberg (casilla de arriba a la izquierda en la fila de encima del agua: cae y flota). Variantes del
        solucionador: una losa fija en la fila WS (`slab` = su columna donde acaba; HOME: donde empieza)"""
        if SWIM:
            return
        if SLABS:
            cc = c if (HOME or slab is None) else slab
            if cc is None: return
            for k in range(w): L.set(cc + k, WS, SOLID)
            return
        L.ent('iceberg', c, row, width=w, capacity=cap)

    def puffer(c0, c1):
        """Pez globo en la fosa: su área va del fondo hasta la superficie"""
        L.ent('pufferfish', (c0 + c1) // 2, DEEP - 1,
              area=[{'col': c0, 'row': DEEP - 1}, {'col': c1, 'row': DEEP - 1}, {'col': c1, 'row': WS}, {'col': c0, 'row': WS}])

    # ── 1. EL MUELLE (2-11) y el primer témpano (canal 12-19) ────────────────────
    L.rect(2, SH, 11, SH + 2, FBRICK)
    sea(12, 19)
    stairs(20, -1)
    floe(14, 3)

    # ── 2. EL TÉMPANO VARADO (plataforma 20-32, canal 33-39) ─────────────────────
    if SWIM:
        pass
    elif SLABS:
        if not HOME: floe(33, 3)                                  # (empujado: cae justo en el borde)
    else:
        L.ent('iceberg', 27, SH - 1, width=3, capacity=1.5)       # (en seco: varado sobre la plataforma)
    sea(33, 39)
    trench(33, 35)
    puffer(33, 35)
    stairs(40, -1)

    # ── 3. EL SOPLÓN (acantilado 45-50, canal 51-61) ────────────────────────────
    L.rect(44, SH - 2, 44, SH - 1)                                 # escalón al acantilado
    L.rect(45, 12, 50, H - 1, IROCK)
    L.set(50, 15, EMPTY)                                           # el NICHO del Soplón, a la altura del iceberg
    L.ent('gust', 50, 15, flyMode='route', speed=0, patrol={'left': 50, 'right': 50}, power=0.7, reach=5.5)   # (quieto en el nicho)
    L.walker('gummy_ice', 47, 11, 45, 49)
    sea(51, 61)
    trench(53, 57)
    puffer(53, 57)
    stairs(62, -1)
    floe(51, 4, slab=54)                                           # (una racha lo lleva ~3-4 casillas)

    # ── 4. PUNTO DE CONTROL 1, la caja y la CASA DE HIELO con el POZO (62-81) ────
    L.ent('checkpoint', 63, SH - 1)
    L.ent('apple', 65, SH - 1)
    if not SLABS:
        L.ent('smallbox', 67, SH - 1, respawn=4)
    L.rect(69, 14, 80, H - 1, FBRICK)                              # (la casa de hielo: ladrillo helado)
    L.rect(70, 13, 80, 13, FBRICK)
    # el pozo (72-73): aire hasta la superficie, agua hasta el fondo; una repisa para salir sin hundirlo
    L.clear(72, 13, 73, WS - 1)
    L.rect(72, WS, 73, BED - 1, WATER)
    L.set(72, 14, FPLAT)
    # el túnel inundado de 1 de alto (fila 17, 74-76) y la gruta (76-79, filas 14-16; suelo seco en la 17 desde la 77)
    L.rect(74, WS, 76, WS, WATER)
    L.clear(76, 14, 79, 16)
    L.set(79, 15, FPLAT)                                           # (para subir al bloque invisible)
    L.set(79, 13, HIDDEN)                                          # la salida: de dentro afuera
    if SWIM:
        pass
    elif SOLVE == 'star':
        L.rect(72, WS + 1, 73, WS + 1, SOLID)                      # (el iceberg HUNDIDO: su cara al ras del túnel)
    elif SLABS:
        L.rect(72, WS, 73, WS, SOLID)                              # (el iceberg tapando el pozo)
    else:
        L.ent('iceberg', 72, SH, width=2, capacity=1.5)
    if SOLVE not in ('star', 'nostar'):
        L.ent('star', 77, 15)                                      # ESTRELLA 3, la escondida
        L.ent('extralife', 78, 16)

    # ── 5. LOS TÉMPANOS FINOS (orilla 81, canal 82-99) ───────────────────────
    sea(82, 99)
    trench(86, 95)
    stairs(81, 1)
    stairs(100, -1)
    for c in (84, 88, 92, 96):
        floe(c, 2, cap=0.8)
    puffer(86, 90)
    puffer(91, 95)
    L.ent('star', 90, 13)                                          # ESTRELLA 1

    # ── 6. EL GLACIAR DE LOS PINGÜINOS (100-127) ────────────────────────────────
    L.rect(103, SH - 2, 105, SH - 1, SBRICK)                       # el banco de nieve (pared para que rebote)
    L.walker('penguin', 109, SH - 1, 106, 111)
    L.clear(112, SH, 113, SH)                                      # la GRIETA: 1 de agua helada
    L.rect(112, WS, 113, WS, WATER)
    L.ent('star', 113, 14)                                         # ESTRELLA 2 (saltando o en trineo)
    L.rect(114, SH, 121, SH, GLACIER)                              # hielo resbaladizo
    L.rect(115, 12, 121, 12, IBRICK)                               # el arco de hielo
    L.ent('spikefall', 117, 13, sub=1)
    L.ent('spikefall', 120, 13, sub=2)
    L.walker('crabby_ice', 118, SH - 1, 115, 121)
    L.ent('checkpoint', 124, SH - 1)
    L.ent('apple', 126, SH - 1)

    # ── 7. EL MAR ABIERTO (128-156) y el muelle de la meta (157-165) ─────────────
    sea(128, 140)
    trench(132, 136)
    puffer(132, 136)
    stairs(127, 1)
    stairs(141, -1)
    floe(129, 5, slab=132)
    L.walker('penguin', 142, SH - 1, 141, 144)
    sea(145, 156)
    trench(148, 152)
    puffer(148, 152)
    stairs(157, -1)
    floe(145, 5, slab=148)
    for c0, c1 in ((128, 140), (145, 156)):
        L.ent('blizzard', c0, 12, corner={'col': c1, 'row': SH}, dir_right=True, dir_left=False, dir_up=False,
              dir_down=False, power=0.6, warn=1, blowMin=2, blowMax=3, gapMin=3, gapMax=5, firstDelay=2)
    L.rect(157, SH, W - 1, SH + 2, FBRICK)

    materials(L)

    # ── la meta (o la de cada variante) ──────────────────────────────────────────
    if SOLVE in ('star', 'nostar'):
        L.finish(77, 16)                                           # (la gruta)
    else:
        L.finish(161, SH - 1)
    if SOLVE == 'star':
        L.start = [73, WS]
    elif SOLVE == 'star_out':
        L.start = [78, 16]
    elif SOLVE == 'well':
        L.start = [73, SH]
    return L


# Lo que va a mano DESPUÉS de retheme: en el PLANO DE FONDO (`--bg` no lo toca) las columnas de hielo que sostienen el
# arco de los carámbanos (sin ellas el arco parecía flotar), y la fila de abajo del marco otra vez de borde. `python3 tools/levelgen/levels_costa_helada_1.py --plane`
HAND_PLANE = [(115, 13, 15, enc(55)), (121, 13, 15, enc(55))]          # (columna, fila de arriba, fila de abajo, tile)


def plane():
    import json
    path = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels', 'tempanos_a_la_deriva.json')
    lv = json.load(open(path))
    bg = lv.get('bgTiles') or [[0] * lv['width'] for _ in range(lv['height'])]
    for c, r0, r1, v in HAND_PLANE:
        for r in range(r0, r1 + 1):
            bg[r - 1][c - 1] = v
    lv['bgTiles'] = bg
    # (retheme pasa a TIERRA la fila de abajo del marco bajo las fosas: bajo la roca helada se veía un cuadro marrón)
    lv['tiles'][-1] = [4 if (v % 16 + 16 * ((v >> 17) % 16)) == 16 else v for v in lv['tiles'][-1]]
    import retheme
    retheme.save(path, lv)
    print('plano a mano: %d columnas' % len(HAND_PLANE))


def materials(L):
    """El hielo de la costa: solo la fila de arriba de cada orilla queda «sólida» (retheme la hace nieve); lo de
    debajo, el fondo del mar y los escalones son roca helada (sin la tierra marrón del tema bajo el agua); lo construido
    (los muelles, la casa de hielo) es ladrillo helado hasta el agua y roca helada por debajo"""
    for r in range(2, H):
        for c in range(2, W):
            v = L.get(c, r)
            if v == SOLID and not (r <= SH and L.get(c, r - 1) in (EMPTY, HIDDEN)):
                L.set(c, r, IROCK)
            elif v == FBRICK and r >= WS:
                L.set(c, r, IROCK)


BUILDERS = [tempanos_a_la_deriva]

if __name__ == '__main__' and '--plane' in os.sys.argv:
    plane()
