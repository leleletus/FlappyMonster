#!/usr/bin/env python3
# LA GRAN BOLA… ¿O VERITY? — la música del huevo de Pascua de la Gran Bola de Nieve (cuando sale con la cara de
# "Verity"). Composición NUEVA hecha con las ideas de dos canciones, no un popurrí: ningún compás está copiado de
# ninguna de las dos (se comprueba: ritmo + intervalos de cada compás contra los de las fuentes).
#
#   · de LA GRAN BOLA (snowball_boss, worlds_nes.py 'bola'; Fa menor): su riff — TRES NOTAS REPETIDAS Y UN SALTO —,
#     el salto de OCTAVA con que remata, el bajo que RUEDA en semicorcheas, los timbales rodando, los cascabeles.
#   · de "IT'S ME, IT'S VERITY" (Horror Skunx; Do menor armónico, 126; tools/music/ref/verity.mid, solo local):
#       a) la nota repetida con su BORDADURA INFERIOR en la sensible (Do-Do-Si-Do) y la bordadura 5ª–♭6ª–5ª (el trino
#          Sol-La♭-Sol);
#       b) el ritmo MECIDO del gancho (ataques en 0 · 6 · 8 · 14) y su caída por el acorde en corcheas;
#       c) las PAREJAS que bajan del piano (Do-Do Si♭-Si♭ La♭-La♭ Sol);
#       d) el acompañamiento "um-pa" (bajo fundamental–quinta a negras, acordes a contratiempo), el bombo a negras, y
#          la armonía i–i–♭VI–V con la DOMINANTE MAYOR (la sensible: lo que le da el aire de feria siniestra).
#   Y UNA MUESTRA literal (a petición del usuario, para que se reconozca la referencia): el gancho del piano eléctrico
#   de Verity, sus cuatro primeros compases, en la intro y abriendo cada estribillo (`HOOK`).
#   Cómo se juntan: el TEMA (A) es el riff de la Bola con la bordadura de Verity DENTRO (Fa-Fa-Mi-Fa y salto), sobre el
#   um-pa y la progresión de Verity; el PUENTE (B) pone el bajo rodante de la Bola bajo una frase nueva: tres notas
#   repetidas de anacrusa (la célula de la Bola en el sitio rítmico de la 2ª frase de Verity) que SALTAN a una nota
#   larga, en secuencia, y el trino; el ESTRIBILLO (C) lleva el ritmo mecido de Verity con el salto de octava de la
#   Bola sobre i–♭VI–♭VII (el giro de la Bola) que acaba en la dominante mayor (la de Verity), mientras una segunda
#   voz toca el riff de la Bola por debajo; el RESPIRO (K) es la caja de música sola, a medio gas, con un acorde
#   "equivocado" (Sol♭, el napolitano): el momento raro del huevo de Pascua; en la última vuelta del tema la caja de
#   música canta por encima una voz en notas largas.
#
# Fa menor (el tono de la Bola) con la sensible Mi (de Verity). 150 BPM (entre las dos). Forma: INTRO 4 (3 de caja de música + el compás de VUELTA; suena una vez) · … · CODA 3 + VUELTA. Antes: INTRO 4 (caja de
# música sola; suena una vez) · A 8 · A' 8 · B 8 · C 8 · K 8 · A'' 8 (+ contrapunto) · C' 8 · CODA 4 = bucle de 60
# compases (96 s).
#
#   ~/.venvs/fm-music/bin/python tools/music/verity_boss.py → assets/music/bosses/snowball_verity_{intro,loop}.ogg
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado). Después: tools/music/levels.py
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_tri, q_n163
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W

NAME = 'snowball_verity'
BPM = 150
S16 = 60.0 / BPM / 4
BAR = 16 * S16
INTRO = 4
N = {'C': 0, 'Db': 1, 'Eb': 3, 'E': 4, 'F': 5, 'Gb': 6, 'G': 7, 'Ab': 8, 'Bb': 10}
MAJ, MIN = (0, 4, 7), (0, 3, 7)
SCALE = {5, 7, 8, 10, 0, 1, 3, 4, 6}          # Fa menor + la sensible (Mi) + el Sol♭ del napolitano (solo en el respiro)


def ch(s):
    return (N[s[:-1]], MIN) if s.endswith('m') else (N[s], MAJ)


RIFF = "0:F5/3 4:F5/3 8:E5/2 10:F5/2 12:C6/4"                               # el riff de la Bola con la bordadura de Verity
T_A = [RIFF,
       "0:Ab5/6 6:G5/2 8:F5/6 14:C5/2",                                    # contesta bajando, en el ritmo mecido
       "0:Ab5/3 4:Ab5/3 8:G5/2 10:Ab5/2 12:Db6/4",
       "0:C6/4 4:Db6/2 6:C6/2 8:Bb5/2 10:Ab5/2 12:G5/4",                   # la bordadura 5ª–♭6ª–5ª y baja a la dominante
       "0:F5/3 4:F5/3 8:E5/2 10:F5/2 12:F6/4",                             # … y el salto, ahora de OCTAVA
       "0:Eb6/2 2:Db6/2 4:C6/2 6:Ab5/2 8:C6/4 12:Ab5/4",
       "0:F6/2 2:F6/2 4:Eb6/2 6:Eb6/2 8:Db6/2 10:Db6/2 12:C6/4"]           # las parejas que bajan
A_END = ["0:F5/4 4:Ab5/2 6:F5/2 8:C5/8"]
A_END2 = ["0:F5/4 4:C6/4 8:F6/8"]
CH_A = ['Fm', 'Fm', 'Db', 'C', 'Fm', 'Fm', ['Db', 'C'], 'Fm']
T_B = ["0:Db6/8 10:Bb5/2 12:Bb5/2 14:Bb5/2",                               # tres notas repetidas de anacrusa… y saltan
       "0:F6/8 10:Ab5/2 12:Ab5/2 14:Ab5/2",
       "0:Db6/8 10:G5/2 12:G5/2 14:G5/2",
       "0:C6/6 6:Db6/2 8:C6/2 10:Bb5/2 12:G5/4",
       "0:F5/2 2:Bb5/2 4:Db6/4 8:C6/2 10:Bb5/2 12:Db6/4",
       "0:C6/2 2:Ab5/2 4:F5/4 8:Ab5/2 10:C6/2 12:F6/4",
       "0:C6/2 2:Db6/2 4:C6/2 6:Db6/2 8:C6/2 10:Db6/2 12:Ab5/4",           # el trino
       "0:G5/3 4:G5/3 8:Ab5/2 10:G5/2 12:C6/4"]                                     # la célula de la Bola, en la dominante, con la bordadura ♭6ª–5ª
CH_B = ['Bbm', 'Fm', 'Db', 'C', 'Bbm', 'Fm', 'Db', 'C']
# LA MUESTRA: el gancho del piano eléctrico de Verity (sus compases 1-4), TAL CUAL, llevado a Fa menor — el usuario: "es
# el motivo reconocible; tiene que notarse que es una referencia". Suena tres veces: la caja de música sola en la
# intro y, con todo, abriendo los dos estribillos (donde el riff de la Bola le contesta por debajo, en sus huecos)
HOOK = ["0:F5/2 6:Ab5/2 8:F5/2 14:Ab5/2", "0:C6/2 2:Ab5/2 4:F5/2", "0:C6/2 4:Db6/2 8:C6/2 10:Ab5/2 14:G5/2", "14:Ab5/2"]
# … y su SEGUNDA MITAD (el usuario: "la muestra son dos"): la frase que le contesta en el piano eléctrico (sus compases
# 10-13: tres corcheas de anacrusa, la nota larga con su bordadura, y cae a la tónica), sobre su armonía i–♭VI–V–i
HOOK2 = ["0:F5/2 10:C6/2 12:Eb6/2 14:Eb6/2", "0:Db6/6 10:Db6/2 12:C6/2 14:Db6/2", "0:C6/8 12:G5/4", "0:F5/8"]
T_C = HOOK + HOOK2                                                         # el ESTRIBILLO es la muestra entera (8 compases)
CH_C = ['Fm', 'Fm', 'Db', 'C', 'Fm', 'Db', 'C', 'Fm']
T_K = ["0:F5/8 8:Ab5/8", "0:C6/8 8:Ab5/2 10:G5/2 12:F5/4", "0:Gb5/8 8:Bb5/8", "0:C6/8 8:Db6/2 10:C6/2 12:G5/4",
       RIFF, "0:Ab5/3 4:Ab5/3 8:G5/2 10:Ab5/2 12:Db6/4", "0:Bb5/4 4:Gb5/4 8:Db5/8", "0:G5/3 4:G5/3 8:Ab5/2 10:G5/2 12:C6/4"]
CH_K = ['Fm', 'Fm', 'Gb', 'C', 'Fm', 'Db', 'Gb', 'C']
# el CONTRAPUNTO de la última vuelta del tema: la caja de música, en notas largas
T_DESC = ["0:C5/8 8:Ab4/8", "0:F4/8 8:Ab4/8", "0:F4/8 8:Ab4/8", "0:G4/8 8:E4/8",
          "0:Ab4/8 8:C5/8", "0:C5/8 8:F5/8", "0:F5/8 8:E5/8", "0:F5/16"]
# LA VUELTA: el MISMO compás (toda la banda, sobre la dominante) cierra la intro y cierra la coda, así lo que queda
# sonando al empezar el bucle es igual venga de donde venga (antes la intro acababa con la caja de música sola y la
# coda con la banda: el bucle arrancaba con la cola de las dos, y la intro "no cortaba limpio ni enlazaba")
TURN = ["0:G5/3 4:G5/3 8:Ab5/2 10:G5/2 12:C6/2"]
T_CODA = ["0:F6/2 2:F6/2 4:Eb6/2 6:Eb6/2 8:Db6/2 10:Db6/2 12:C6/4", "0:Ab5/3 4:Ab5/3 8:G5/2 10:Ab5/2 12:Db6/4",
          "0:C6/2 2:Db6/2 4:C6/2 6:Db6/2 8:C6/2 10:Db6/2 12:C6/4"]
CH_CODA = ['Fm', 'Db', 'C']
T_IN = HOOK[:3]
CH_IN = ['Fm', 'Fm', 'Db']
TURNS = ('T1', 'T2')
ORDER = ['IN', 'T1', 'A', 'A2', 'B', 'C', 'K', 'A3', 'C2', 'CODA', 'T2']
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
            tag.append(kind)
    section('IN', T_IN, CH_IN)
    section('T1', TURN, ['C'])
    section('A', T_A + A_END, CH_A)
    section('A2', T_A + A_END2, CH_A)
    section('B', T_B, CH_B)
    section('C', T_C, CH_C)
    section('K', T_K, CH_K)
    section('A3', T_A + A_END2, CH_A, T_DESC)
    section('C2', T_C, CH_C)
    section('CODA', T_CODA, CH_CODA)
    section('T2', TURN, ['C'])
    return mel, chords, tag, starts, desc


def check(notes, chords):
    at = lambda b, st: chords[b - 1][0 if st < 8 else 1]
    bad = [(b, st) for b, st, n, d in notes if d >= 4 and (n - at(b, st)[0]) % 12 not in at(b, st)[1]]
    out = [(b, st) for b, st, n, d in notes if n % 12 not in SCALE]
    return bad, out


def copied(mel, tag):
    """¿Algún compás de la melodía es el de una de las fuentes (mismo ritmo Y mismos intervalos)?"""
    def sig(ns):
        ns = sorted(ns)
        return (tuple(st for st, n in ns), tuple(b[1] - a[1] for a, b in zip(ns, ns[1:])))
    src = set()
    for phrase in (W.O_A + W.O_END + W.O_END2, W.O_B, W.O_C):                # La Gran Bola
        bars = {}
        for b, st, n, d in phrase: bars.setdefault(b, []).append((st, n))
        src |= {sig(v) for v in bars.values() if len(v) >= 3}
    try:
        import mido
        m = mido.MidiFile(os.path.join(os.path.dirname(__file__), 'ref', 'verity.mid'))
        for tr in m.tracks:
            if tr.name not in ('Electric Piano', 'Grand Piano', 'Vibraphone'): continue
            t, bars = 0, {}
            for msg in tr:
                t += msg.time
                if msg.type == 'note_on' and msg.velocity > 0:
                    s = t / m.ticks_per_beat * 4
                    bars.setdefault(int(s // 16), []).append((int(round(s % 16)), msg.note))
            src |= {sig(v) for v in bars.values() if len(v) >= 3}
    except Exception as e:
        print('  (sin el MIDI de Verity: solo se compara con La Gran Bola)', e)
    mine = {}
    for b, st, n, d in mel: mine.setdefault(b, []).append((st, n))
    sample = ('IN', 'C', 'C2')                    # (los 4 primeros compases de estas secciones SON la muestra)
    first = {}
    for b, t in enumerate(tag, 1): first.setdefault(t, b)
    return sorted(b for b, v in mine.items() if len(v) >= 3 and sig(v) in src and not (tag[b - 1] in sample))


WAVES = [wavetable([1.0, 0.0, 0.5, 0.12, 0.25, 0.0, 0.12]),     # 0 voz HUECA (armónicos impares: rara, de feria)
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
THEME = ('A', 'A2', 'A3', 'CODA', 'T1', 'T2')
CHORUS = ('C', 'C2')
ROLL = (0, 0, 12, 0, 0, 0, 12, 7)                    # el bajo de la Bola: RUEDA en semicorcheas


def build(lufs=-10.5):
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
        t0, t1 = tv(b, st), tv(b, st) + d * S16 * 0.9
        if kind in ('IN', 'K'):                                # la caja de música canta sola (en el respiro, con una voz suave debajo)
            play(Cn['bell'], t0, t0 + max(d, 4) * S16 * 1.1, n, I_BELL, q=q_n163, release=8)
            if kind == 'K': play(Cn['lead'], t0, t1, n - 12, I_SOFTV, q=q_n163, release=5)
            continue
        play(Cn['lead'], t0, t1, n, I_VOICE, q=q_n163, release=3)
        if kind != 'A3' and (kind != 'B' or d >= 4):           # la caja de música la dobla (en B, solo las notas largas)
            play(Cn['bell'], t0, t0 + max(d, 4) * S16, n + 12, I_BELL, q=q_n163, release=6)
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
        lo = lambda r: 36 + (r - 36) % 12
        last = (b + 1) in starts or b == NB
        # ── BAJO ──
        if kind == 'IN':
            if k >= 2: bass(b, 0, 15.5, lo(r1), False)
        elif kind == 'K':
            if k <= 4: bass(b, 0, 15.5, lo(r1), False)
            else: bass(b, 0, 3.5, lo(r1)); bass(b, 8, 3.5, lo(r2) + 7 - (12 if lo(r2) + 7 > 47 else 0))      # um-pa, a medio gas
        elif kind == 'B' or kind in CHORUS:                    # RUEDA (la Bola)
            for st in range(16):
                r = r1 if st < 8 else r2
                bass(b, st, 0.9, lo(r) + ROLL[st % 8], st % 2 == 0)
        else:                                                  # um-pa (Verity): fundamental y quinta, a negras
            for st in (0, 4, 8, 12):
                r = r1 if st < 8 else r2
                fifth = lo(r) + 7 - (12 if lo(r) + 7 > 47 else 0)
                bass(b, st, 3.2, lo(r) if st in (0, 8) else fifth)
        for half, (r, q) in enumerate(((r1, q1), (r2, q2))):
            s0 = half * 8
            notes = [72 + (r - 72) % 12 + iv for iv in q]
            # acordes A CONTRATIEMPO (el "pa" del um-pa): tema y estribillo
            if kind in THEME or kind in CHORUS or (kind == 'K' and k >= 5):
                for st in (2, 6):
                    vs = 0.6 if kind == 'K' else 1.0
                    play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + 1.6 * S16, notes[1] - 12, I_STAB, vs=vs, release=1)
                    play(Cn['c2'], tv(b, s0 + st), tv(b, s0 + st) + 1.6 * S16, notes[2] - 12, I_STAB, vs=vs, release=1)
            # campanillas (estribillo y coda): el acorde, una nota cada tres semicorcheas
            if kind in CHORUS or kind == 'CODA':
                for i_, st in enumerate((0, 3, 6)):
                    play(Cn['ice'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 1.5, notes[(i_ + half) % 3] + 12, I_ICE, release=1)
            # arpegio brillante en semicorcheas (B y el último estribillo)
            if kind in ('B', 'C2'):
                for st in range(8):
                    play(Cn['shim'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 0.7, notes[(0, 1, 2, 1)[st % 4]] + (12 if st >= 4 else 0), I_SHIM, release=0)
            # coro (colchón): B, el respiro, la intro y el último estribillo
            if kind in ('B', 'K', 'C2', 'IN'):
                vs = {'C2': 1.3, 'K': 0.8, 'IN': 0.6}.get(kind, 1.0)
                play(Cn['p1'], tv(b, s0), tv(b, s0) + 7.6 * S16, notes[1] - 12, I_CHOIR, q=q_n163, vs=vs, release=5)
                play(Cn['p2'], tv(b, s0), tv(b, s0) + 7.6 * S16, notes[2] - 12, I_CHOIR, q=q_n163, vs=vs, release=5)
        # la SEGUNDA VOZ del estribillo: el riff de la Bola (tres notas y un salto) sobre cada acorde, por debajo
        if kind in CHORUS:
            for st in (0, 4, 8):
                r = r1 if st < 8 else r2
                play(Cn['dbl'], tv(b, st), tv(b, st) + 2.6 * S16, 60 + (r - 60) % 12, I_PUL, release=2)
            play(Cn['dbl'], tv(b, 12), tv(b, 12) + 3.6 * S16, 60 + (r2 - 60) % 12 + 7, I_PUL, release=2)
        # ── BATERÍA ──
        for st in range(16):
            t = tv(b, st)
            sleigh = lambda: NZ['hat'].hit(t, 0, [5, 3, 1] if st % 2 == 0 else [2, 1])
            if kind == 'IN':
                if st % 2 == 0: NZ['hat'].hit(t, 0, [5, 3, 1])
                if k >= 2 and st in (0, 8): hit(kick, TN.KICK_DEEP, t, 0.9)
                if k == 3 and st >= 8: snare(t, 0.3 + st * 0.04, [5 + st // 2, 4, 2])
            elif kind == 'K':                                  # respiro: cascabeles; del 5º compás, bombo y timbales que vuelven
                if st % 2 == 0: NZ['hat'].hit(t, 0, [5, 3, 1])
                if k >= 5 and st in (0, 8): hit(kick, TN.KICK_DEEP, t, 0.9)
                if k >= 7 and st in (2, 3, 10, 11, 14, 15): hit(tom, W.TOMS[(st // 2) % 3], t, 0.9)
                if k == 8 and st >= 4: snare(t, 0.3 + st * 0.04, [5 + st // 2, 4, 2])
            elif kind == 'B':                                  # la Bola rueda: timbales rodando, caja suave en 2 y 4
                if st in (0, 8, 10): hit(kick, TN.KICK, t, 0.9)
                if st in (4, 12): snare(t, 0.6, [9, 5, 2])
                elif st in (6, 7, 14, 15): hit(tom, W.TOMS[(st % 2) + (0 if st < 8 else 1)], t, 0.8)
                else: sleigh()
            else:                                              # tema y estribillo: bombo a negras, caja en 2 y 4 (Verity)
                if st % 4 == 0: hit(kick, TN.KICK, t, 1.0)
                if st in (4, 12): snare(t, 1.0)
                elif kind in CHORUS and st in (10, 11) and k % 2 == 0: hit(tom, W.TOMS[st - 10], t, 0.9)
                elif st in (7, 15) and (k % 2 == 0 or kind == 'C2'): snare(t, 0.35, [6, 3, 1])
                else: sleigh()
            if last and kind not in ('IN', 'K') and st >= 12:                      # entrada a la sección siguiente
                snare(t, 0.6 + (st - 12) * 0.1, [9 + (st - 12), 5, 2]); hit(tom, W.TOMS[min(2, st - 12)], t, 0.7)
            if st == 0 and (kind in TURNS or (b > INTRO and (k == 1 and kind not in ('B', 'K') or (kind in CHORUS and k % 2 == 1)
                                                      or (kind in THEME and (k - 1) % 4 == 0)))): NZ['crash'].hit(t, 3, CRASH)
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
    # (SIN doblar la cola sobre el principio del bucle: el compás de vuelta es el mismo en la intro y en la coda, así que
    # la cola que hace falta ya está ahí — la de la intro —; doblar la de la coda la pondría dos veces)
    S = {k_: v[:n].copy() for k_, v in S.items()}
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
    DYN = {'IN': (-4, -2.5), 'T1': (1.2, 1.2), 'T2': (1.2, 1.2), 'A': (0, 0), 'A2': (0.3, 0.3), 'B': (-1.5, -0.5), 'C': (1, 1), 'K': (-6, -2.5), 'A3': (0.8, 0.8),
           'C2': (1.8, 1.8), 'CODA': (1.5, 1.2)}
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
    GN.report(NAME, y, S, g, n)
    bad, out = check(mel + desc, chords)
    drums = sum(np.mean((S[k_][:n] * g[k_]) ** 2) for k_ in ('kick', 'toms', 'snare', 'hat', 'crash')) / sum(np.mean((S[k_][:n] * g[k_]) ** 2) for k_ in S)
    print(f'  {BPM} BPM, intro {INTRO} + bucle {NB - INTRO} compases ({(NB - INTRO) * BAR:.1f} s); melodía {len(mel)} notas; batería {100 * drums:.0f} % de la energía')
    print(f'  notas largas fuera del acorde: {bad or "ninguna"} · fuera de la escala: {out or "ninguna"}')
    print(f'  compases iguales a uno de las fuentes, fuera de la muestra (ritmo + intervalos): {copied(mel, tag) or "ninguno"}')
    # ── ¿enlaza? el compás de vuelta de la intro y el de la coda tienen que ser el mismo sonido, y secciones parejas ──
    nb = int(BAR * SR)
    a_, c_ = y[n_i - nb:n_i], y[n - nb:n]
    half = nb // 2
    # (se comparan los ESPECTROS por tramos, no las muestras: el ruido y la fase de los osciladores no se repiten)
    def spec(v):
        v = v.mean(1) if v.ndim == 2 else v
        fr = [np.abs(np.fft.rfft(v[i:i + 4096] * np.hanning(4096))) for i in range(0, len(v) - 4096, 2048)]
        m = np.array(fr)
        edges = np.geomspace(4, m.shape[1] - 1, 13).astype(int)
        return np.array([[np.sqrt(np.mean(r[e0:e1] ** 2)) for e0, e1 in zip(edges, edges[1:])] for r in m])
    sa, sc = spec(a_[half:]), spec(c_[half:])
    diff = np.mean(np.abs(20 * np.log10((sa + 1e-4) / (sc + 1e-4))))
    lvl = 10 * np.log10(np.mean(a_[half:] ** 2) / np.mean(c_[half:] ** 2))
    print(f'  vuelta: 2ª mitad del último compás, intro frente a coda: nivel {lvl:+.1f} dB, espectro por bandas a {diff:.1f} dB de media')
    ref = None
    line = []
    for i_, kind in enumerate(ORDER):
        b0 = starts[i_]; b1 = (starts[i_ + 1] if i_ + 1 < len(starts) else NB + 1)
        seg = y[int((b0 - 1) * BAR * SR):int((b1 - 1) * BAR * SR)]
        db = 10 * np.log10(np.mean(seg ** 2) + 1e-12)
        if kind == 'A': ref = db
        line.append((kind, db))
    print('  secciones (dB respecto a A): ' + ' · '.join(f'{k_} {d_ - ref:+.1f}' for k_, d_ in line))
    return y, mel, n_i


if __name__ == '__main__':
    y, mel, n_i = build()
    if not os.environ.get('REPORT'):
        GN.export(NAME, y, n_i)
        W.write_mid(F.out(NAME, 'mid'), mel, BPM)
