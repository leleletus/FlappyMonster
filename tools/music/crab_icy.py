#!/usr/bin/env python3
# CRAB TANTRUM (ICY) — el tema del Mega Crabby helado, TERCERA versión: composición nueva.
#
# Historia: v1 = el tema del Mega Crabby con el motivo navideño de "Winter Fallympics" metido en cuatro sitios; v2 =
# además, su frase de 1:48 entera como puente. El usuario: "básicamente has copiado y pegado las melodías originales";
# quiere lo que se hizo en el jefe final: los motivos como MATERIAL que se reinterpreta y desarrolla, no trozos
# insertados; puede ser más larga, con más secciones, melodías nuevas, y sonar bastante distinta de las otras dos del
# Mega Crabby mientras conserve algo reconocible del motivo de Tentacle Tantrum. "Creativa, coherente, que suene bien".
#
# Así que aquí NO hay ningún compás copiado de winter. Lo que se toma de cada canción y qué se hace con ello:
#   · de TENTACLE TANTRUM, la CÉLULA del riff (tónica larga, tónica, sube una cuarta, baja a la tercera; ritmo 6-2-2-4):
#     es el compás 3 y 7 del tema, el final del estribillo, y la toca el bajo en el respiro. Y su tresillo 3+3+2.
#   · de WINTER, tres IDEAS:
#       a) el salto de OCTAVA y la bajada por grados del motivo navideño → el tema A empieza con el ritmo de la célula
#          pero con ESE contorno (tónica, tónica, octava arriba, baja); el ESTRIBILLO es ese contorno en menor, sobre
#          el 5º grado, y con el ritmo del cangrejo (3+3+2) en vez de negras iguales, en secuencia; el RESPIRO lo
#          canta la caja de música en valores largos (aumentación) y sigue por su cuenta.
#       b) el gesto de la frase de 1:48 (tres corcheas y una nota larga a contratiempo) → la sección B lo INVIERTE
#          (las corcheas bajan en vez de subir) y lo lleva por una progresión nueva; en el tema A aparece una vez del
#          derecho (compás 4).
#       c) su cierre (tres notas repetidas y un salto) → cierra B y el respiro, en otros grados.
#   · y al final se JUNTAN: en la tercera vuelta del tema, la caja de música canta por encima una voz nueva en notas
#     largas hecha con el salto y la bajada (contrapunto), mientras la voz lleva el tema del cangrejo.
#
# Re menor natural (el giro ♭VI–♭VII del riff); el estribillo, i–♭VI–III–♭VII (Fa mayor, la tonalidad de winter, asoma
# como III). Timbres de hielo: voz suave del N163 + caja de música, campanillas, cascabeles, arpegio brillante, coro.
# 186 BPM a tiempo entero. Forma: INTRO 4 (caja de música sola; suena una vez) · A 8 · A' 8 · B 8 (deshielo, más
# ligera) · C 8 (estribillo) · K 8 (RESPIRO: caja de música, el bajo trae la célula, vuelven los tambores) · A'' 8
# (tema + contrapunto) · B 8 · C' 8 (estribillo con todo) · CODA 4 = bucle de 60 compases (77,4 s).
#
#   python tools/music/crab_icy.py   → assets/music/bosses/crab_tantrum_icy_{intro,loop}.ogg + .mid
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_tri, q_n163
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W

BPM = 186
S16 = 60.0 / BPM / 4
BAR = 16 * S16
INTRO = 4
N = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'Bb': 10}
MAJ, MIN = (0, 4, 7), (0, 3, 7)
SCALE = {2, 4, 5, 7, 9, 10, 0}


def ch(s):
    return (N[s[:-1]], MIN) if s.endswith('m') else (N[s], MAJ)


CELL = "0:D5/6 6:D5/2 8:G5/2 10:F5/4 14:D5/4"                              # la célula de Tentacle Tantrum
T_A = ["0:D5/6 6:D5/2 8:D6/2 10:C6/2 12:A5/2 14:F5/4",                             # su ritmo, con el salto de octava y la bajada
       "2:A5/2 4:G5/2 6:F5/2 8:F5/4 12:D5/4",
       CELL,
       "2:D5/2 4:F5/2 6:A5/2 8:G5/4 12:E5/4",                              # (el gesto de 1:48, del derecho, una vez)
       "0:D5/6 6:D5/2 8:Bb5/2 10:A5/2 12:F5/2 14:D5/4",
       "2:F5/2 4:E5/2 6:D5/2 8:E5/4 12:G5/4",
       CELL]
A_END = ["2:D5/4 6:D5/2 8:Bb4/4 12:C5/4"]                                   # la cola del riff: ♭VI–♭VII
A_END2 = ["2:D5/4 6:D5/2 8:F5/4 12:G5/4"]
CH_A = ['Dm', ['Dm', 'Bb'], 'Dm', ['Dm', 'C'], 'Bb', ['Bb', 'C'], 'Dm', ['Dm', 'Bb', 'C']]
# LAS DOS REFERENCIAS DE WINTER, a medio camino (3.72.1). Historia: v3 las disfrazaba tanto (el gesto de 1:48 INVERTIDO,
# el motivo a mitad de velocidad) que no se reconocían; 3.72.0 las puso literales y al usuario le sonó a "copiar y
# pegar: antes la transición y la inclusión eran más naturales; el punto era hacerlas un poco más reconocibles, no
# literalmente iguales". Ahora cada una conserva su HUELLA y lo demás es propio, sobre la armonía de la v3:
#   · frase de 1:48: su RITMO (tres corcheas y una nota larga a contratiempo; 2-2-2-4 · 2-2-4→) y el contorno de su
#     cabeza (sube por el acorde hasta la octava), del DERECHO, pero en Sol menor y siguiendo en secuencia por la
#     progresión de la v3 — no sus notas ni su continuación; el cierre (tres notas y un salto) como estaba.
#   · motivo navideño: su primer compás como es (negras: salto de octava y bajada) y a partir de ahí sigue por su cuenta.
T_B_OLD = ["0:D6/2 2:Bb5/2 4:G5/2 6:D5/4 10:G5/2 12:Bb5/2 14:A5/4", "2:F5/2 4:D5/2 6:A5/4 12:F5/4",
           "0:D6/2 2:Bb5/2 4:F5/2 6:D5/4 10:F5/2 12:Bb5/2 14:C6/4", "2:A5/2 4:F5/2 6:C6/4 12:A5/4",
           "0:Bb5/2 2:G5/2 4:D5/2 6:G5/4 10:Bb5/2 12:D6/2 14:D6/4", "2:A5/2 4:F5/2 6:D5/4 12:F5/4",
           "0:F5/3 4:F5/3 8:F5/3 12:Bb5/4", "0:G5/3 4:G5/3 8:G5/3 12:C6/4"]             # (la v3: el gesto invertido)
T_B = ["0:G4/2 2:Bb4/2 4:D5/2 6:G5/4 10:D5/2 12:G5/2 14:A5/4",             # la cabeza de 1:48, del derecho, en Sol menor
       "2:F5/2 4:A5/2 6:D6/4 12:A5/4",
       "0:D6/2 2:C6/2 4:Bb5/2 6:F5/4 10:D5/2 12:F5/2 14:A5/4",             # baja (el ritmo de su 3er compás) por Si♭
       "2:G5/2 4:F5/2 6:C5/4 10:A4/2 12:C5/4",
       "0:Bb4/2 2:D5/2 4:G5/2 6:Bb5/4 10:G5/2 12:Bb5/2 14:D6/4",           # la cabeza otra vez, una tercera más arriba
       "2:A5/2 4:F5/2 6:D5/4 12:F5/4",
       "0:F5/3 4:F5/3 8:F5/3 12:Bb5/4",                                    # su cierre (tres notas y un salto), en otros grados
       "0:G5/3 4:G5/3 8:G5/3 12:C6/4"]
CH_B = ['Gm', 'Dm', 'Bb', 'F', 'Gm', 'Dm', 'Bb', 'C']
MOTIF = ["0:F5/4 4:F6/4 8:E6/4 12:D6/4", "0:C6/4 4:Bb5/4 8:G5/8"]            # el primer compás del motivo, como es, y gira por su cuenta
T_C = ["0:A4/3 3:A5/3 6:G5/2 8:F5/3 11:E5/3 14:D5/2",                      # el contorno del motivo navideño, en menor y en 3+3+2
       "0:D5/3 3:F5/3 6:A5/2 8:Bb5/4 12:F5/4",
       "0:C5/3 3:C6/3 6:Bb5/2 8:A5/3 11:G5/3 14:F5/2",                     # … una tercera más arriba
       "0:E5/3 3:G5/3 6:Bb5/2 8:C6/4 12:G5/4",
       "0:A5/3 3:D6/3 6:C6/2 8:A5/3 11:G5/3 14:F5/2",
       "0:F5/3 3:Bb5/3 6:A5/2 8:F5/4 12:D5/4",
       "0:E5/2 2:G5/2 4:C6/4 8:Bb5/2 10:G5/2 12:E5/4",
       "0:D5/6 6:D5/2 8:G5/2 10:F5/4 14:D5/2"]                             # … y cierra con la célula del cangrejo
CH_C = ['Dm', 'Bb', 'F', 'C', 'Dm', 'Bb', 'C', 'Dm']
T_K = MOTIF + ["0:A5/4 4:D6/4 8:F6/8", "0:D6/8 8:A5/8",
                "0:Bb5/8 8:G5/8", "0:F5/8 8:D5/8", "0:E5/4 4:G5/4 8:C6/8", "0:G5/3 4:G5/3 8:G5/3 12:C6/4"]     # … y sigue por su cuenta (como en la v3)
CH_K = ['Bb', 'C', 'Dm', 'Dm', 'Gm', 'Bb', 'C', 'C']
# el CONTRAPUNTO de la tercera vuelta del tema: la caja de música, en notas largas (medio compás cada una)
T_DESC = ["0:F5/8 8:A5/8", "0:D6/8 8:Bb5/8", "0:A5/8 8:F5/8", "0:D5/8 8:E5/8",
          "0:F5/8 8:Bb5/8", "0:D6/8 8:C6/8", "0:A5/8 8:D6/8", "0:D6/8 8:Bb5/4 12:C6/4"]
T_CODA = ["0:F5/6 6:F5/4 10:F5/4 14:G5/4", "2:G5/6 8:G5/4 12:G5/4", "0:A5/6 6:A5/4 10:A5/4 14:D6/2",
          "0:A4/4 4:D5/2 6:F5/2 8:A5/6"]                                   # la llamada del juego
CH_CODA = ['Bb', 'C', 'Dm', 'Dm']
T_IN = MOTIF + ["0:A5/4 4:D6/4 8:F6/8", "0:D6/8"]
CH_IN = ['Bb', 'C', 'Dm', 'Dm']
ORDER = ['IN', 'A', 'A2', 'B', 'C', 'K', 'A3', 'B2', 'C2', 'CODA']
Q4 = {}


def song():
    mel, chords, tag, starts, desc = [], [], [], [], []

    def section(kind, bars, cs, extra=None):
        base = len(chords)
        starts.append(base + 1)
        for b, st, n, d in W.PH(*bars): mel.append((base + b, st, n, d))
        for b, st, n, d in W.PH(*(extra or [])): desc.append((base + b, st, n, d))
        for c in cs:
            chords.append((ch(c[0]), ch(c[1])) if isinstance(c, list) else (ch(c), ch(c)))
            if isinstance(c, list) and len(c) == 3: Q4[len(chords)] = ch(c[2])
            tag.append(kind)
    Q4.clear()
    section('IN', T_IN, CH_IN)
    section('A', T_A + A_END, CH_A)
    section('A2', T_A + A_END2, CH_A)
    section('B', T_B, CH_B)
    section('C', T_C, CH_C)
    section('K', T_K, CH_K)
    section('A3', T_A + A_END2, CH_A, T_DESC)
    section('B2', T_B, CH_B)
    section('C2', T_C, CH_C)
    section('CODA', T_CODA, CH_CODA)
    return mel, chords, tag, starts, desc


def check(notes, chords):
    def at(b, st):
        if st >= 14: return chords[b % len(chords)][0]
        if st >= 12 and b in Q4: return Q4[b]
        return chords[b - 1][0 if st < 8 else 1]
    bad = [(b, st) for b, st, n, d in notes if d >= 4 and (n - at(b, st)[0]) % 12 not in at(b, st)[1]]
    out = [(b, st) for b, st, n, d in notes if n % 12 not in SCALE]
    return bad, out


WAVES = [wavetable([1.0, 0.45, 0.2, 0.1]),                     # 0 voz suave
         GN.CWAVES[0],                                         # 1 caja de música
         wavetable([1.0, 0.25, 0.4, 0.1, 0.2])]                # 2 coro
I_VOICE = {'vol': [12, 14, 15, 14, 13, 13], 'sus': 13, 'vib': (12, 0.2, 5.5), 'duty': 0.0}
I_SOFTV = {'vol': [6, 8, 9, 9, 8, 8], 'sus': 8, 'vib': (16, 0.15, 5.0), 'duty': 0.0}
I_BELL = dict(GN.I_BELL, duty=1.0)
I_CHOIR = {'vol': [3, 5, 7, 8, 9, 9, 10], 'sus': 10, 'vib': (20, 0.12, 4.5), 'duty': 2.0}
I_PUL = {'vol': [11, 10, 9, 8, 8, 7], 'sus': 7, 'duty': [0.125, 0.25]}
I_TRI = {'vol': [15], 'sus': 15}
I_BDEF = {'vol': [12, 9, 6, 4, 3, 2], 'sus': 2, 'duty': 0.5}
I_ICE = {'vol': [9, 6, 4, 3, 2, 1], 'sus': 0, 'duty': 0.125}
I_SHIM = {'vol': [6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_STAB = {'vol': [13, 11, 8, 5, 3, 2], 'sus': 1, 'duty': 0.25}
I_ECHO = {'vol': [5, 5, 4, 3], 'sus': 2, 'duty': 0.5}
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
TRES = (0, 6, 12)
THEME = ('A', 'A2', 'A3', 'CODA')
CHORUS = ('C', 'C2')
CALM = ('B', 'B2')


def build(lufs=-10.0):
    mel, chords, tag, starts, desc = song()
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'dbl', 'echo', 'bell', 'p1', 'p2', 'c1', 'c2', 'ice', 'shim', 'bass', 'bdef')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash', 'fx')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # ── MELODÍA ──
    for b, st, n, d in mel:
        kind = tag[b - 1]
        t0, t1 = tv(b, st), tv(b, st) + d * S16 * 0.93
        if kind in ('IN', 'K'):                                # la caja de música canta sola (en el respiro, con una voz suave debajo)
            play(Cn['bell'], t0, t0 + max(d, 4) * S16 * 1.1, n, I_BELL, q=q_n163, release=8)
            if kind == 'K': play(Cn['lead'], t0, t1, n - 12, I_SOFTV, q=q_n163, release=5)
            continue
        play(Cn['lead'], t0, t1, n, I_VOICE, q=q_n163, release=3)
        if kind != 'A3' and (kind not in CALM or d >= 4):      # la caja de música la dobla (en B, solo las notas largas)
            play(Cn['bell'], t0, t0 + max(d, 4) * S16, n + 12, I_BELL, q=q_n163, release=6)
        if kind == 'C2': play(Cn['dbl'], t0, t1, n + 12, I_PUL, release=2)          # el último estribillo, con su octava
        if d >= 3: play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 3) * S16 * 0.8, n, I_ECHO, release=1)
    for b, st, n, d in desc:                                   # el contrapunto: la caja de música por encima del tema
        play(Cn['bell'], tv(b, st), tv(b, st) + d * S16 * 1.05, n + 12, I_BELL, q=q_n163, release=8)

    def bass(b, st, ln, note, define=True):
        t = tv(b, st)
        play(Cn['bass'], t, t + ln * S16, note, I_TRI, q=q_tri, release=0)
        if define: play(Cn['bdef'], t, t + min(ln, 2.5) * S16, note + 12, I_BDEF, release=1)

    for b in range(1, NB + 1):
        kind = tag[b - 1]
        k = b - starts[ORDER.index(kind)] + 1                  # compás dentro de la sección
        (r1, q1), (r2, q2) = chords[b - 1]
        lo = lambda r: 38 + (r - 38) % 12
        last = (b + 1) in starts or b == NB
        # ── BAJO ──
        if kind == 'IN':
            if k >= 3: bass(b, 0, 15.5, lo(r1), False)
        elif kind == 'K':
            if k <= 4: bass(b, 0, 15.5, lo(r1), False)
            else:                                              # la célula del cangrejo, en el bajo, sobre cada acorde
                for st, ln, iv in ((0, 5.5, 0), (6, 1.8, 0), (8, 1.8, 5), (10, 3.6, 3 if q1 == MIN else 4), (14, 1.8, 0)): bass(b, st, ln, lo(r1) + iv)
        elif kind in CALM:
            bass(b, 0, 7.5, lo(r1), False); bass(b, 8, 5.5, lo(r2), False); bass(b, 14, 1.8, lo(r2) + 7, False)
        elif kind in CHORUS:
            for st in range(0, 16, 2):
                r = r1 if st < 8 else r2
                bass(b, st, 1.7, lo(r) + (12 if st in (6, 14) else 0))
        else:                                                  # el tresillo 6-6-4 del tema
            bass(b, 0, 5.5, lo(r1)); bass(b, 6, 1.8 if r2 != r1 else 5.5, lo(r1))
            if r2 != r1: bass(b, 8, 3.6, lo(r2))
            r3 = Q4[b][0] if b in Q4 else r2
            bass(b, 12, 1.8, lo(r3)); bass(b, 14, 1.8, lo(r3) + 12)
        for half, (r, q) in enumerate(((r1, q1), (r2, q2))):
            s0 = half * 8
            notes = [72 + (r - 72) % 12 + iv for iv in q]
            # campanillas en el tresillo (tema y estribillo)
            if kind in THEME or kind in CHORUS:
                for i_, st in enumerate((0, 3, 6)):
                    play(Cn['ice'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 1.5, notes[(i_ + half) % 3] + 12, I_ICE, release=1)
            # arpegio brillante en semicorcheas (B, estribillo, coda)
            if kind in CALM or kind in CHORUS or kind == 'CODA':
                for st in range(8):
                    play(Cn['shim'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 0.7, notes[(0, 1, 2, 1)[st % 4]] + (12 if st >= 4 else 0), I_SHIM, release=0)
            # coro (colchón): B, el respiro y el último estribillo
            if kind in CALM or kind in ('K', 'C2', 'IN'):
                vs = {'C2': 1.3, 'K': 0.8, 'IN': 0.6}.get(kind, 1.0)
                play(Cn['p1'], tv(b, s0), tv(b, s0) + 7.6 * S16, notes[1] - 12, I_CHOIR, q=q_n163, vs=vs, release=5)
                play(Cn['p2'], tv(b, s0), tv(b, s0) + 7.6 * S16, notes[2] - 12, I_CHOIR, q=q_n163, vs=vs, release=5)
        # golpes de quinta: tema (tresillo) y estribillo (a tiempo)
        if kind in THEME or kind in CHORUS:
            for st in (TRES if kind in THEME else (0, 4, 8, 12)):
                r = r1 if st < 8 else (Q4[b][0] if st >= 12 and b in Q4 else r2)
                root = 50 + (r - 50) % 12
                play(Cn['c1'], tv(b, st), tv(b, st) + 2.5 * S16, root, I_STAB, release=2)
                play(Cn['c2'], tv(b, st), tv(b, st) + 2.5 * S16, root + 7, I_STAB, release=2)
        # ── BATERÍA ──
        for st in range(16):
            t = tv(b, st)
            sleigh = lambda: NZ['hat'].hit(t, 0, [5, 3, 1] if st % 2 == 0 else [2, 1])
            if kind == 'IN':
                if st % 2 == 0: NZ['hat'].hit(t, 0, [5, 3, 1])
                if k >= 3 and st in TRES: hit(kick, TN.KICK_DEEP, t, 0.9)
                if k == 4 and st >= 4: snare(t, 0.3 + st * 0.04, [5 + st // 2, 4, 2])
            elif kind == 'K':                                  # respiro: cascabeles; del 5º compás, bombo y timbales que vuelven
                if st % 2 == 0: NZ['hat'].hit(t, 0, [5, 3, 1])
                if k >= 5 and st in TRES: hit(kick, TN.KICK_DEEP, t, 0.9)
                if k >= 7 and st in (2, 3, 10, 11, 14, 15): hit(tom, W.TOMS[(st // 2) % 3], t, 0.9)
                if k == 8 and st >= 4: snare(t, 0.3 + st * 0.04, [5 + st // 2, 4, 2])
            elif kind in CALM:                                 # ligera: bombo en el tresillo, caja suave en 2 y 4
                if st in TRES: hit(kick, TN.KICK, t, 0.9)
                if st in (4, 12): snare(t, 0.55, [9, 5, 2])
                else: sleigh()
            elif kind in CHORUS:                               # estribillo: bombo a negras + 4y, caja en 2 y 4, timbales
                if st % 4 == 0 or st == 14: hit(kick, TN.KICK, t, 1.0)
                if st in (4, 12): snare(t, 1.0)
                elif st in (10, 11) and k % 2 == 0: hit(tom, W.TOMS[st - 10], t, 0.9)
                elif st in (7, 15) and kind == 'C2': snare(t, 0.35, [6, 3, 1])
                else: sleigh()
            else:                                              # el tema: tresillo en el bombo, caja en 2 y 4, timbales
                if st in TRES or st == 10: hit(kick, TN.KICK, t, 1.0 if st in TRES else 0.85)
                if st in (4, 12): snare(t, 1.0)
                elif st in (7, 15) and k % 2 == 0: snare(t, 0.35, [6, 3, 1])
                elif st in (3, 14): hit(tom, W.TOMS[2 if st == 3 else 1], t, 0.9)
                else: sleigh()
            if last and kind not in ('IN', 'K') and st >= 12:                      # entrada a la sección siguiente
                snare(t, 0.6 + (st - 12) * 0.1, [9 + (st - 12), 5, 2]); hit(tom, W.TOMS[min(2, st - 12)], t, 0.7)
            if st == 0 and b > INTRO and (k == 1 and kind not in CALM and kind != 'K' or (kind in CHORUS and k % 2 == 1)
                                          or (kind in THEME and (k - 1) % 4 == 0)): NZ['crash'].hit(t, 3, CRASH)
        if kind in ('IN', 'K') and last:                       # subida de ruido hacia el tema
            n_ = int(BAR * 60)
            for i_ in range(n_):
                x_ = i_ / (n_ - 1)
                NZ['fx'].hit(tv(b, 0) + i_ / 60.0, int(round(9 - 7 * x_)), [max(1, int(round(9 * x_ ** 1.5)))])

    n = int(NB * BAR * SR)
    n_i = int(INTRO * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k_: cut(F.pulse_dac(F.render_pulse(Cn[k_])))
    wave = lambda k_: cut(F.render_wave(Cn[k_], WAVES) * 0.0075)
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    S = {
        'lead': wave('lead'), 'bell': wave('bell'), 'dbl': pulse('dbl'), 'echo': pulse('echo'), 'choir': wave('p1') + wave('p2'),
        'stabs': pulse('c1') + pulse('c2'), 'ice': pulse('ice'), 'shim': pulse('shim'),
        'bass': cut(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)), 'bdef': pulse('bdef'),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + cut(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
        'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12)),
        'crash': cut(F.tnd_dac(NZ['crash'].render() / 22638.0 * 12)) + cut(F.tnd_dac(NZ['fx'].render() / 22638.0 * 12)),
    }
    S = {k_: GN.fold(v, n, n_i) for k_, v in S.items()}
    S['bell'] = GN.delay(S['bell'], 3 * S16, 0.25, 2, 3200)[:len(S['bell'])]
    # (niveles respecto a la voz; el acompañamiento ya va alto para que en el juego no se quede sola la melodía)
    LV = {'lead': 0, 'bell': -2, 'dbl': -8, 'echo': -12, 'choir': -7, 'stabs': -7, 'ice': -7, 'shim': -10,
          'bass': 3, 'bdef': -5, 'kick': 3, 'toms': 0, 'snare': 0, 'hat': -8, 'crash': -7}
    g = GN.level(S, LV, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k_] * g[k_] for k_ in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    side = S['ice'] * g['ice'] * 0.5 + S['shim'] * g['shim'] * 0.5 + S['choir'] * g['choir'] * 0.4 - S['echo'] * g['echo'] * 0.6 + S['hat'] * g['hat'] * 0.3
    # dinámica por secciones (dB): B más ligera, el respiro abajo y creciendo, el último estribillo arriba
    DYN = {'IN': (-4, -2), 'A': (0, 0), 'A2': (0.3, 0.3), 'B': (-1.5, -1), 'C': (1, 1), 'K': (-6, -2.5), 'A3': (0.8, 0.8),
           'B2': (-1, -0.5), 'C2': (1.8, 1.8), 'CODA': (1.5, 1.5)}
    env = np.ones(len(x))
    for b in range(1, NB + 1):
        a_, e_ = DYN[tag[b - 1]]
        first = max(i for i in starts if i <= b); nxt = min([i for i in starts if i > b] + [NB + 1])
        i0, i1 = int((b - 1) * BAR * SR), min(len(x), int(b * BAR * SR))
        u = (np.arange(i1 - i0) / (i1 - i0) + (b - first)) / (nxt - first)
        env[i0:i1] = 10 ** ((a_ + (e_ - a_) * u) / 20)
    k_ = int(0.03 * SR); env = np.convolve(np.pad(env, k_, mode='edge'), np.ones(2 * k_ + 1) / (2 * k_ + 1), mode='valid')[:len(x)]
    x, side = x * env, side * env
    y = F.master(np.stack([x + side, x - side], 1), lufs=lufs)
    GN.report('crab_tantrum_icy', y, S, g, n)
    # (los dos compases del motivo navideño — intro y respiro — llevan sus notas de paso: no cuentan)
    own = [x for x in mel + desc if not ((tag[x[0] - 1] == 'IN' and x[0] <= 2) or (tag[x[0] - 1] == 'K' and x[0] - starts[ORDER.index('K')] < 2))]
    bad, out = check(own, chords)
    drums = sum(np.mean((S[k_][:n] * g[k_]) ** 2) for k_ in ('kick', 'toms', 'snare', 'hat', 'crash')) / sum(np.mean((S[k_][:n] * g[k_]) ** 2) for k_ in S)
    print(f'  {BPM} BPM, intro {INTRO} + bucle {NB - INTRO} compases ({(NB - INTRO) * BAR:.1f} s); melodía {len(mel)} notas; batería {100 * drums:.0f} % de la energía')
    print(f'  notas largas fuera del acorde: {bad or "ninguna"} · fuera de la escala: {out or "ninguna"}')
    return y, mel, n_i


if __name__ == '__main__':
    y, mel, n_i = build()
    if not os.environ.get('REPORT'):
        GN.export('crab_tantrum_icy', y, n_i)
        W.write_mid(F.out('crab_tantrum_icy', 'mid'), mel, BPM)
