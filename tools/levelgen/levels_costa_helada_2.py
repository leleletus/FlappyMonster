"""La Costa Helada, nivel 3: «La Bahía de las Mareas» (bahia_de_las_mareas) — un puerto helado con MAREA.

Diseño aprobado (FlappyMonster_pruebas/islas_heladas/diseno.md, Costa 3): un puerto pesquero helado con una MAREA
(inundación `control = 'tide'`, agua helada `cold`): en MAREA ALTA los ICEBERGS (`iceberg`, siguen el agua) suben a
los muelles, al tejado del mercado y al barco; en MAREA BAJA se cruza el FONDO entre Crabbies helados, por lo que solo
se alcanza entonces. Medir la marea es el puzle. Fondo `frozen_coast` al atardecer, música nieve_2.

LA MAREA: una inundación por cuenca, todas con la misma marea (filas 12-27), periodo TIDE_P s, de LO (2 filas bajo el fondo: el
fondo seco ≈ 31 % del ciclo) a HI (la superficie en lo alto de la fila 19: los muelles quedan a una fila por encima);
empieza bajando, a 2 s de la bajamar. Se lee en: los PILOTES del plano de fondo (columna de hielo de las filas 19-25:
su capitel es la marca de la pleamar), los muros del puerto (ladrillo helado arriba, roca helada oscura con algas
debajo de la marca) y las algas y estrellas de mar del fondo.

  filas    fondo (arena) 26 · pleamar en lo alto de 19 · muelles 18 · tejados y barco más arriba
  1 (2-26)    MUELLE DEL PUEBLO (salida) → DÁRSENA 1: el iceberg I1 reposa en el fondo junto al muelle 2: bájate en
              bajamar, súbete y la marea te sube (el ASCENSOR de la marea; desde el muelle no se llega a saltos)
  2 (27-50)   MUELLE 2 → la RAMPA (35-36) → bajo el ALMACÉN, el VARADERO (37-50, filas 21-25): solo en bajamar.
              Estrella escondida: en el DESVÁN del almacén, tras un bloque rompible del techo del varadero (cabezazo
              desde la repisa de hielo)
  3 (51-80)   DÁRSENA 3: el iceberg I3 (ancho 3) está lejos del MERCADO (muelle 3, tejado en la fila 18): EMPÚJALO en
              bajamar hasta el muro y súbete; la pleamar te deja en el tejado. Punto de control 1
  4 (81-115)  EL PECIO: el barco helado varado (casco de hielo glaciar, cubierta de tablones en la fila 18 — a ras de
              la pleamar —). Toldilla con el palo de mesana: las vergas suben a la COFA (estrella 2). La BODEGA, bajo la
              cubierta: en bajamar está seca (estrella 1, bajo una viga: con el agua no se llega) y una brecha del casco
              sale al fondo; en pleamar está inundada
  5 (116-147) LOS PANTALANES: el pantalán 1 y el 2 con un canal de 7 en medio; en PLEAMAR el iceberg I6 es el paso;
              en BAJAMAR se baja al fondo y se sube por la ESCALA del pantalán 2. A media marea, ninguno. Punto de
              control 2
  6 (148-165) EL FARO: la puerta está en el fondo (bajamar); dentro, el POZO DE MAREA con el iceberg I7 sube con la
              pleamar a las repisas de hielo que trepan a la galería → el ESPIGÓN y la META

Comprobación (level_solve no modela los icebergs ni la marea, no empuja ni rompe bloques): variantes con el agua FIJA
y cada iceberg como bloques en su sitio de bajamar (en el fondo) o de pleamar (fila 19):
    TIDE=low|high  START=c,r  GOAL=c,r  [PUSHED=1: I3 ya empujado al muro] [NOICE=1: sin icebergs] [OPEN=1: sin
    el rompible]   python3 tools/levelgen/build.py --only bahia_de_las_mareas --out assets/levels/_bahia
    (el --out bajo assets/levels/: level_solve lee por love.filesystem; borrarlo después). Tramos en SOLVES (abajo).
Orden:
    python3 tools/levelgen/build.py --only bahia_de_las_mareas
    python3 tools/levelgen/retheme.py bahia_de_las_mareas
    python3 tools/levelgen/levels_costa_helada_2.py --tidy      (quita las decoraciones «iceberg» — se confunden con
                                                                 los de verdad — y las que caen dentro de un iceberg)
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from lib import *

ID_HIGH = 2 ** 17


def enc(i): return i % 16 + (i // 16) * ID_HIGH


SAND = enc(35)
FBRICK, IROCK, IBRICK, GLACIER, SBRICK, IPILLAR, FWINDOW, FPLAT, ILEDGE = (enc(i) for i in range(50, 59))

TIDE = os.environ.get('TIDE', '')                # variante de comprobación: 'low' / 'high' (agua fija)
PUSHED = bool(os.environ.get('PUSHED'))
NOICE = bool(os.environ.get('NOICE'))
OPEN = bool(os.environ.get('OPEN'))
SHOT = bool(os.environ.get('SHOT'))              # (con TIDE: para level_shots, icebergs de verdad)

W, H = 166, 30
SEA = 26            # fondo (arena): de pie en la 25
DOCK = 18           # cara de arriba de los muelles (de pie en la 17)
HIGHW = 19          # pleamar: la superficie en lo alto de esta fila
TIDE_P = 26         # s por marea
FLOOD_R0, FLOOD_R1 = 12, SEA + 1   # la inundación: filas 12-27 (nivel = casillas sobre el fondo de la 27)
# bajamar: el agua 2 filas bajo la cara del fondo (el fondo seco ≈ 31 % del ciclo; el agua tiñe también los bloques que
# cubre: más honda se veía una franja de agua bajo todo el nivel); pleamar: en lo alto de la fila 19
LO, HI = 0, FLOOD_R1 - HIGHW + 1
COLD = 4            # s en el agua helada hasta congelarse
BASINS = ((15, 26), (35, 69), (81, 153))     # columnas de agua: dársena 1 · rampa, varadero y dársena 3 · pecio, pantalanes y faro

# icebergs: (col, ancho) — se colocan en el fondo (casilla de arriba a la izquierda en la fila 25)
I1 = (23, 3)
I3 = (60, 3); I3_PUSHED = (67, 3)
I6 = (126, 2)
I7 = (151, 2)


class Bay(Level):
    def __init__(self):
        Level.__init__(self, 'La Bahía de las Mareas', W, H, (6, DOCK - 1), music='nieve_2', modes=['race'])
        self.extra.update(name_en='Tide Bay', background='frozen_coast', time='dusk', coldWater=COLD)

    def bgr(self, c0, r0, c1, r1, v):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.set_bg(c, r, v)

    def seabed(self, c0, c1):
        """El fondo de la bahía: arena encima, piedra debajo"""
        self.rect(c0, SEA, c1, H - 1, SOLID)
        self.rect(c0, SEA, c1, SEA, SAND)

    def quay(self, c0, c1, top=DOCK, faces=('l', 'r')):
        """Un muelle macizo; su cara al mar: ladrillo helado sobre la marca de la pleamar, roca helada debajo"""
        self.rect(c0, top, c1, H - 1, SOLID)
        for side in faces:
            c = c0 if side == 'l' else c1
            self.rect(c, top, c, HIGHW - 1, FBRICK)
            self.rect(c, HIGHW, c, SEA - 1, IROCK)

    def post(self, c, top=HIGHW):
        """Un pilote (plano de fondo): su capitel marca la pleamar"""
        self.bgr(c, top, c, SEA - 1, IPILLAR)

    def iceberg(self, spot):
        c, w = spot
        if TIDE:
            if NOICE: return
        if SHOT:                                 # (foto con el agua fija: los icebergs de verdad)
            self.ent('iceberg', c, SEA - 1, width=w); return
            r = HIGHW if TIDE == 'high' else SEA - 1
            self.rect(c, r, c + w - 1, r, IBRICK)
        else:
            self.ent('iceberg', c, SEA - 1, width=w)

    def food(self, c, r):
        self.ent('apple', c, r)


def bahia_de_las_mareas():
    L = Bay()
    rect, clear, ent, deco = L.rect, L.clear, L.ent, L.deco

    # ══ 1 · MUELLE DEL PUEBLO y DÁRSENA 1 (2-26) ═══════════════════════════════════════════════════════════════
    L.quay(2, 14, faces=('r',))
    L.seabed(15, 26)
    L.post(16); L.post(21)
    L.iceberg(I1)                               # el ascensor de la marea: junto al muelle 2
    ent('crabby_ice', 18, SEA - 1, patrol={'left': 15, 'right': 21})
    L.vent(19, SEA - 1)

    # ══ 2 · MUELLE 2, RAMPA, ALMACÉN y VARADERO (27-50) ═════════════════════════════════════════════════════════
    L.quay(27, 34)
    L.seabed(35, 50)
    ent('penguin', 30, DOCK - 1, patrol={'left': 28, 'right': 33})
    L.food(29, DOCK - 1)
    # el almacén: muros de 2, tejado a dos aguas; abajo, el varadero abierto (filas 21-25) de lado a lado
    rect(37, 7, 38, 20, FBRICK); rect(49, 7, 50, 20, FBRICK)
    rect(37, 7, 50, 8, FBRICK); rect(39, 6, 48, 6, IBRICK); rect(41, 5, 46, 5, IBRICK)
    rect(37, 19, 50, 20, FBRICK)                 # suelo del desván = techo del varadero
    for r in (11, 15):
        L.set(37, r, FWINDOW); L.set(50, r, FWINDOW)
    L.bgr(39, 9, 48, 18, FBRICK)                 # (el interior del desván)
    L.bgr(39, 11, 39, 11, FWINDOW); L.bgr(48, 11, 48, 11, FWINDOW)
    L.bgr(37, 21, 50, 25, FBRICK)                # (el fondo del varadero)
    # varadero: una zanja helada (agua de casillas, 2 de ancho: un iceberg de 3 no cabe) y un Crabby
    L.water(40, SEA, 41, SEA + 1)
    ent('crabby_ice', 46, SEA - 1, patrol={'left': 43, 'right': 50})
    # ESTRELLA ESCONDIDA: repisa de hielo (fila 23) bajo dos bloques rompibles del techo; encima, el desván
    rect(43, 23, 44, 23, ILEDGE)
    rect(44, 21, 45, 21, FPLAT)                  # (tabla bajo el hueco: para subir al desván)
    rect(44, 19, 45, 19, EMPTY)
    rect(44, 20, 45, 20, EMPTY if OPEN else BREAK)
    ent('star', 41, DOCK)                        # (en el suelo del desván, fila 18)

    # ══ 3 · DÁRSENA 3 y el MERCADO (51-80) ═════════════════════════════════════════════════════════════════════
    L.seabed(51, 69)
    L.post(54); L.post(63)
    L.iceberg(I3_PUSHED if PUSHED else I3)       # hay que empujarlo hasta el muro del mercado
    L.vent(56, SEA - 1)
    L.quay(70, 80)
    ent('checkpoint', 77, DOCK - 1)
    L.food(73, DOCK - 1)
    L.bgr(72, 11, 79, 17, FBRICK)                # (la lonja detrás del punto de control)
    L.bgr(71, 10, 80, 10, IBRICK); L.bgr(73, 9, 78, 9, IBRICK)
    for c in (74, 77): L.set_bg(c, 13, FWINDOW)

    # ══ 4 · EL PECIO (81-115) ═══════════════════════════════════════════════════════════════════════════════════
    L.seabed(81, 115)
    for r in (24, 22, 20):                       # (quien cae entre el mercado y la popa sube en bajamar por esta escala)
        rect(82, r, 83, r, FPLAT)
    # El barco es HUECO: una cáscara de hielo glaciar (el casco helado) con el forro de tablas en el plano de fondo;
    # toldilla (popa, cubierta en la 16), cubierta de tablones (18) sobre la BODEGA y castillo de proa (15)
    L.bgr(85, 16, 111, 24, FPLAT)                # (el forro de tablas, de popa a proa)
    rect(84, 16, 90, 16, GLACIER)                # toldilla
    rect(84, 17, 84, 23, GLACIER); rect(85, 23, 85, 24, GLACIER)   # espejo de popa, curvado abajo
    rect(85, 25, 110, 25, GLACIER)               # quilla / fondo del casco
    # palo de mesana (plano de fondo) con sus vergas y la COFA (estrella 2)
    L.bgr(87, 3, 87, 15, IPILLAR)
    for r in (13, 10, 7):
        rect(85, r, 89, r, FPLAT)
    ent('star', 87, 5)
    # cubierta (tablones, fila 18) sobre la BODEGA (filas 17-24 bajo la toldilla, 19-24 bajo la cubierta)
    rect(91, DOCK, 106, DOCK, FPLAT)
    L.bgr(99, 8, 99, 17, IPILLAR)                # (palo mayor, partido)
    ent('penguin', 96, DOCK - 1, patrol={'left': 92, 'right': 104})
    # bodega: escala de tablas hasta la cubierta; la ESTRELLA 1 bajo una viga (seca: salto doble; con agua, no)
    rect(95, 23, 96, 23, FPLAT); rect(97, 21, 98, 21, FPLAT)
    rect(102, 20, 104, 20, GLACIER)
    ent('star', 103, 21)
    ent('crabby_ice', 104, 24, patrol={'left': 100, 'right': 109})
    # castillo de proa (cubierta en la 15); la roda en escalera; debajo, la BRECHA del casco (filas 21-25) al fondo
    rect(107, 15, 112, 15, GLACIER)
    rect(112, 16, 112, 18, GLACIER); rect(111, 19, 111, 20, GLACIER); rect(110, 21, 110, 22, GLACIER)
    rect(105, 16, 106, 16, FPLAT)                # (escalón de la cubierta al castillo)
    rect(113, 15, 115, 15, FPLAT)                # bauprés

    # ══ 5 · LOS PANTALANES (116-147) ════════════════════════════════════════════════════════════════════════════
    L.seabed(116, 147)
    rect(117, DOCK, 123, DOCK, FPLAT)            # pantalán 1
    L.iceberg(I6)                                # canal 124-130: el paso en pleamar
    rect(131, DOCK, 142, DOCK, FPLAT)            # pantalán 2
    for r in (24, 22, 20):                       # la escala (bajamar)
        rect(132, r, 133, r, FPLAT)
    for c in (118, 122, 135, 139, 142):
        L.post(c)
    L.post(145)
    L.water(127, SEA, 129, SEA)                  # (un charco helado bajo el canal)
    ent('crabby_ice', 120, SEA - 1, patrol={'left': 116, 'right': 125})
    ent('crabby_ice', 140, SEA - 1, patrol={'left': 135, 'right': 147})
    ent('penguin', 137, DOCK - 1, patrol={'left': 134, 'right': 142})
    ent('checkpoint', 141, DOCK - 1)
    L.food(131, DOCK - 1)
    L.vent(124, SEA - 1)

    # ══ 6 · EL FARO y el ESPIGÓN (148-165) ═════════════════════════════════════════════════════════════════════
    L.seabed(148, 155)
    rect(148, 4, 149, 25, FBRICK)                # muro izquierdo, con la puerta abajo
    clear(148, 23, 149, 25)
    rect(154, 4, 155, 25, FBRICK)                # muro derecho, con la salida a la galería (filas 9-10)
    clear(154, 9, 155, 10)
    rect(148, 3, 155, 3, IBRICK); rect(150, 2, 153, 2, IBRICK)     # la cúpula de la linterna
    for r in (6, 7):
        L.set(148, r, FWINDOW); L.set(155, r, FWINDOW)
    L.bgr(150, 4, 153, 25, FBRICK)               # (el interior del pozo)
    L.bgr(151, 6, 152, 6, FWINDOW)
    L.iceberg(I7)
    rect(152, 17, 153, 17, ILEDGE)
    rect(150, 15, 151, 15, ILEDGE)
    rect(152, 13, 153, 13, ILEDGE)
    rect(150, 11, 153, 11, ILEDGE)               # la galería
    L.quay(156, W - 1, top=11, faces=())         # el espigón
    rect(154, 11, 155, 11, FBRICK)
    ent('penguin', 158, 10, patrol={'left': 156, 'right': 164})
    L.finish(161, 10)

    # ── LA MAREA ──────────────────────────────────────────────────────────────────────────────────────────────────
    # (tres inundaciones IGUALES — mismo periodo y fase: una sola marea —, una por cuenca: el agua tiñe todo lo que
    # cubre su rectángulo, y con una sola los muelles y el espigón se veían bajo el agua)
    for k, (c0, c1) in enumerate(BASINS):
        flood = dict(id=k + 1, corner={'col': c1, 'row': FLOOD_R1}, cold=COLD)
        if TIDE:
            lv = HI if TIDE == 'high' else LO
            flood.update(startLevel=lv, maxLevel=lv)
        else:
            flood.update(control='tide', startLevel=LO, maxLevel=HI, tidePeriod=TIDE_P, tidePhase=0.92)
        ent('flood', c0, FLOOD_R0, **flood)

    decorate(L)
    if TIDE: variant(L)
    return L


def decorate(L):
    """Lo que retheme no pone: lo del puerto en su sitio (bolardos en los bordes, el bote, la boya, nasas, redes)"""
    d = L.deco
    d('buoy', 3, DOCK - 1); d('rowboat', 9, DOCK - 1); d('bollard', 14, DOCK - 1, sub=4)
    d('bollard', 27, DOCK - 1, sub=3); d('bollard', 34, DOCK - 1, sub=4); d('crab_pot', 32, DOCK - 1)
    d('kelp_rock', 17, SEA - 1); d('starfish_ice', 20, SEA - 1, sub=4)
    d('rowboat', 38, SEA - 1); d('crab_pot', 48, SEA - 1)
    d('net_hang', 39, 21); d('net_hang', 47, 21)
    d('bollard', 70, DOCK - 1, sub=3); d('crab_pot', 79, DOCK - 1)
    d('kelp_rock', 52, SEA - 1); d('starfish_ice', 58, SEA - 1, sub=3)
    d('anchor', 116, SEA - 1)                    # (el ancla del pecio)
    d('crab_pot', 93, 24); d('crab_pot', 106, 24)
    d('kelp_rock', 136, SEA - 1); d('starfish_ice', 144, SEA - 1, sub=4)
    d('buoy', 164, 10); d('bollard', 157, 10, sub=3)


def variant(L):
    """Comprobación por tramos: salida y meta en otro sitio (START / GOAL)"""
    fin = [(c, r) for r in range(1, H + 1) for c in range(1, W + 1) if L.get(c, r) == FINISH]
    if os.environ.get('GOAL'):
        for c, r in fin: L.set(c, r, EMPTY)
        c, r = (int(x) for x in os.environ['GOAL'].split(','))
        L.set(c, r, FINISH)                      # (una sola casilla: la meta exacta)
    if os.environ.get('START'):
        L.start = [int(x) for x in os.environ['START'].split(',')]


BUILDERS = [bahia_de_las_mareas]

# Tramos comprobados con level_solve (TIDE, START, GOAL, extras, se espera): la marea alterna como al jugarlo
SOLVES = [
    ('low', '6,17', '24,24', '', 'OK'),            # 1: del muelle al iceberg I1 en el fondo
    ('low', '6,17', '31,17', 'NOICE=1', 'FALLA'),  #    en bajamar no se sube al muelle 2
    ('high', '6,17', '31,17', 'NOICE=1', 'FALLA'),  #    ni en pleamar sin iceberg (el muelle 1 está lejos)
    ('high', '24,18', '31,17', '', 'OK'),          # 1: el iceberg en pleamar → muelle 2
    ('low', '31,17', '59,25', '', 'OK'),           # 2: rampa, varadero, dársena 3 hasta el iceberg I3
    ('low', '45,25', '40,18', 'OPEN=1', 'OK'),     # 2: el desván (estrella escondida) sin el rompible
    ('high', '61,18', '77,17', '', 'FALLA'),       # 3: sin empujar I3 no se llega al mercado
    ('high', '68,18', '77,17', 'PUSHED=1', 'OK'),  # 3: empujado, sí
    ('high', '77,17', '87,4', '', 'OK'),           # 4: la cofa (estrella 2)
    ('low', '82,25', '79,17', '', 'OK'),           # 4: caído entre el mercado y la popa: la escala
    ('high', '77,17', '141,17', '', 'OK'),         # 4-5: pecio, pantalán 1, I6, pantalán 2
    ('low', '96,17', '103,21', '', 'OK'),          # 4: la bodega (estrella 1) en bajamar
    # (en pleamar la bodega está inundada: quien cae dentro se queda hasta la bajamar — de la escala a la cubierta hay 3
    # filas, que bajo el agua no se saltan —; level_solve no distingue el salto seco del mojado junto a la estrella)
    ('low', '103,24', '141,17', '', 'OK'),         # 5: brecha → fondo → escala del pantalán 2
    ('low', '141,17', '152,24', '', 'OK'),         # 6: a la puerta del faro, al iceberg I7
    ('low', '141,17', '161,10', '', 'FALLA'),      #    en bajamar no se sube el pozo
    ('high', '152,18', '161,10', '', 'OK'),        # 6: pleamar: repisas, galería, espigón, meta
]


def tidy(name='bahia_de_las_mareas'):
    """Tras retheme: fuera las decoraciones «iceberg» (parecen los de verdad) y las que caen dentro de un iceberg"""
    path = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'levels', name + '.json')
    lv = json.load(open(path))
    cells = set()
    for e in lv['entities']:
        if e['type'] == 'iceberg':
            w = (e.get('props') or {}).get('width', 1)
            cells |= {(e['col'] + k, e['row']) for k in range(w)}
    before = len(lv['foliage'])
    lv['foliage'] = [f for f in lv['foliage'] if f['type'] != 'iceberg' and (f['col'], f['row']) not in cells]
    import retheme
    retheme.save(path, lv)
    print('decoraciones quitadas: %d' % (before - len(lv['foliage'])))


if __name__ == '__main__' and '--tidy' in sys.argv:
    sys.argv = sys.argv[:1]
    tidy()
