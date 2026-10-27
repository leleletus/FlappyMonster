#!/usr/bin/env python3
# MEGA MASHUP DE LOS CANGREJOS — los cuatro temas de los cangrejos gigantes en una sola pista, más rápida y más de
# jefe, para un EVENTO: una batalla sincronizada con la música (cuando suena el tema de un cangrejo, se pelea contra
# ese cangrejo). Aprobada por el usuario (0.5.57) e instalada como `crab_mashup`; la batalla aún no existe: cuando
# se haga, deberá SEGUIR el mapa de secciones (SECTIONS, SEC_BPM, RAMP — los tiempos salen en secciones_180bpm.json).
#
# Las cuatro fuentes y lo que se toma de cada una (sus propias notas, de sus generadores):
#   · CRAB TANTRUM (crab_tantrum.py, el Mega Crabby): el tema A (la célula del riff y su cola ♭VI–♭VII), el GRITO DE
#     GUERRA del estribillo, el puente tribal y la coda con la llamada. Sierra + pulso, golpes de quinta, marimba.
#   · GLOOMY (crab_tantrum.py gloomy): el mismo tema en la cueva — voz hueca con eco, batería seca a medio tiempo, las
#     PATAS de la araña (semicorcheas en grupos de 8, la bajada cromática y la PAUSA al cerrar la frase).
#   · ICY (crab_icy.py): su B (el gesto de 1:48 invertido) y su ESTRIBILLO (el contorno del motivo en 3+3+2). Voz
#     suave del N163, caja de música, coro, campanillas, cascabeles.
#   · CANGREJO GROOVE (slap_boss.py): su CLÍMAX (la sección C del tema, tal cual: el riff con su R7/R8 y el B alto), en
#     su propia tonalidad, Mi menor: el cambio de tono de Re a Mi es la subida del evento. El slap canta; golpes en
#     todos los contratiempos, rasgueo, colchón, el brillo de los pops, golpes de banda.
#   · FINAL, LOS CUATRO A LA VEZ (el mashup de verdad): el riff del Groove es i–i–♭VI–♭VII (Mim Mim Do Re) = la
#     armonía del grito de guerra del Tantrum (Rem Rem Si♭ Do) un tono arriba → el grito de guerra en la sierra SOBRE
#     el riff de slap, con las patas de la Gloomy debajo y, la segunda vez, la caja de música de la Icy cantando una
#     voz larga por encima. Luego la CODA, TODOS todavía: el Re mayor con que acaba el final se vuelve Re menor y la
#     banda sigue en Re (el riff de slap un tono abajo, el grito, las patas, la caja de música), la cadencia ♭VI–♭VII–i
#     de la coda del Tantrum con todos, y un último compás de parada: golpe de banda, tambores tribales (como la intro)
#     y la llamada, que cierra el bucle hacia el principio.
#
# Forma (compases de 16 semicorcheas; 180 BPM a tiempo entero, la Gloomy a 144 y el Groove a 150 — SEC_BPM —; TEMPO=…
# cambia el de 180):
#   intro 4 (tambores tribales, el slap trae la célula; suena una vez) ·
#   TANTRUM: A 8 · grito 8 · GLOOMY: puente de patas 8 · A 8 · ICY: B 8 · estribillo 8 ·
#   GROOVE (Mi menor, su clímax): A 8 · B 8 · FINAL (los cuatro, Mi menor) 16 · CODA (los cuatro, Re menor) 8
#   = bucle de 88 compases.
#
#   python tools/music/crab_mashup.py   → FlappyMonster_pruebas/musica/crab_mashup/ (previas + mapa de secciones)
#   INSTALL=1 …                         → assets/music/bosses/crab_mashup_intro.ogg + crab_mashup_loop.ogg
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys, json
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_saw, q_n163, q_vrc6
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W
import slap as SL
import crab_tantrum as CT
import crab_icy as CI
import slap_boss as SB

BPM = float(os.environ.get('TEMPO', 180))                     # (el usuario eligió 180 entre 190 y 180)
S16 = 60.0 / BPM / 4
BAR = 16 * S16
NAME = 'crab_mashup'
PREVIEW = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'musica', 'crab_mashup')
MAJ, MIN = (0, 4, 7), (0, 3, 7)
D_MIN = {2, 4, 5, 7, 9, 10, 0}
TRES = (0, 6, 12)

# la voz larga de la caja de música en la segunda vuelta del final (escrita en Re menor; suena +2 y una octava arriba)
DESC = W.PH("0:D5/8 8:A5/8", "0:F5/8 8:D6/8", "0:D6/8 8:Bb5/8", "0:C6/8 8:G5/8",
            "0:A5/8 8:F5/8", "0:D5/8 8:A5/8", "0:Bb5/8 8:D6/8", "0:E6/8 8:C6/8")
# el último compás del final: Re mayor, y el Do# sube al Re de la coda (el mismo Re, ahora menor). v1 bajaba hacia un
# Si♭ y la coda cambiaba de golpe a otra banda (el usuario: "abrupto… el final muy soso y no combina")
FIN = "0:D2/2 2:D3/1! 3:D2/1x 4:F#2/2 6:A2/2 8:D3/2 10:C3/1 11:D3/1! 12:F#3/1! 13:E3/1 14:D3/1 15:C#3/1"
R = SB
# el Groove: su CLÍMAX (la C de slap_boss.py). v1 tomaba su A con 4 compases de paradas y su primer B (el usuario: "no
# saca la mejor parte de su tema y queda algo raro")
GROOVE_A = [R.R1, R.R2, R.R7, R.R8, R.R1V, R.R2, R.R7, R.R8]
GROOVE_B = [R.B9, R.B2, R.B11, R.B4, R.B5, R.B6, R.B7, R.B16]
FINAL_R = [R.R1, R.R2, R.R3, R.R4, R.R1V, R.R2, R.R3, R.R4, R.R1, R.R2, R.R3, R.R4, R.K3, R.R2, R.R3, FIN]
# la coda: el riff un tono abajo (RIFF_TR) — Rem Rem Si♭ Do · Si♭ Do (sube en cromático al Re) · Rem con la blue note —
# y el último compás sin riff (la parada de la llamada)
CODA_R = [R.R1, R.R2, R.R3, R.R4, R.R3, R.R4, R.R1V, None]
RIFF_TR = {'coda': -2}
# su melodía: el grito de guerra en Re (4 compases) y la subida de la coda del Tantrum con la llamada (4)
CODA = [e for e in CT.PH_B if e[0] <= 4] + [e for e in CT.PH_CODA if e[0] >= 5]

# (id, jefe, estilo, melodía (Re menor escrita), acordes, transposición de melodía y acordes, riff de slap)
SECTIONS = [
    ('intro', '-', 'intro', [], ['Dm'] * 4, 0, None),
    ('tantrum_A', 'tantrum', 'tantrum', CT.PH_A + CT.A_END, CT.CH_A, 0, None),
    ('tantrum_B', 'tantrum', 'chant', CT.PH_B + CT.B_END, CT.CH_B, 0, None),
    ('gloomy_puente', 'gloomy', 'gloomy_br', CT.PH_BR, ['Dm'] * 8, 0, None),
    ('gloomy_A', 'gloomy', 'gloomy', CT.PH_A + CT.A_END2, CT.CH_A, 0, None),
    ('icy_B', 'icy', 'icy_calm', W.PH(*CI.T_B), CI.CH_B, 0, None),
    ('icy_C', 'icy', 'icy_chorus', W.PH(*CI.T_C), CI.CH_C, 0, None),
    ('groove_A', 'groove', 'groove_a', [], ['Em', 'Em', 'C', 'B'] * 2, 0, GROOVE_A),
    ('groove_B', 'groove', 'groove_b', [], ['Am', 'Am', 'Em', 'Em', 'C', 'C', 'B', 'B'], 0, GROOVE_B),
    ('final', 'todos', 'final', CT.PH_B + CT.B_END + [(b + 8, s, n, d) for b, s, n, d in CT.PH_B + CT.B_END2],
     CT.CH_B * 2, 2, FINAL_R),
    ('coda', 'todos', 'coda', CODA, ['Dm', 'Dm', 'Bb', 'C', 'Bb', 'C', 'Dm', 'Dm'], 0, CODA_R),
]
INTRO = 4
# cada cangrejo, a SU tempo (el usuario, con todo a 180: las patas de la Gloomy "tan rápido y raro" y el slap del Groove
# "rapidísimo"): la Gloomy a 144 y el Groove a 150, como sus temas; el Groove acelera en sus dos últimos compases hacia el final
SEC_BPM = {'gloomy_puente': 144, 'gloomy_A': 144, 'groove_A': 150, 'groove_B': 150}
RAMP = {('groove_B', 7): 160, ('groove_B', 8): 170}
# dinámica por sección (dB al entrar → al salir): crece por bloques; la cueva y el deshielo respiran
DYN = {'intro': (-5, -2), 'tantrum_A': (0, 0), 'tantrum_B': (0.3, 0.8), 'gloomy_puente': (-2.5, -1.5), 'gloomy_A': (-1.5, -1),
       'icy_B': (-1.5, -1), 'icy_C': (0.5, 1.2), 'groove_A': (0.3, 0.9), 'groove_B': (1, 1.5), 'final': (2, 2.8),
       'coda': (2.8, 2.2)}


def song():
    mel, chords, sec, starts, q4, desc, riffs = [], [], [], {}, {}, [], []
    for sid, boss, style, ph, cs, tr, rf in SECTIONS:
        base = len(chords)
        starts[sid] = base + 1
        mel += [(base + b, st, n + tr, d) for b, st, n, d in ph]
        for c in cs:
            if isinstance(c, list):
                (r1, q1), (r2, q2) = SB.ch(c[0]), SB.ch(c[1])
                if len(c) == 3: r3, q3 = SB.ch(c[2]); q4[len(chords) + 1] = ((r3 + tr) % 12, q3)
            else:
                (r1, q1) = (r2, q2) = SB.ch(c)
            chords.append((((r1 + tr) % 12, q1), ((r2 + tr) % 12, q2)))
            sec.append(sid)
        if sid == 'final':
            desc += [(base + 8 + b, st, n + tr, d) for b, st, n, d in DESC]
        if sid == 'coda':                                      # (la caja de música sigue en la coda: su primera mitad)
            desc += [(base + b, st, n, d) for b, st, n, d in DESC if b <= 4]
        if rf:
            for i, t in enumerate(rf):
                if t: riffs += [(base + i + 1, st, n + RIFF_TR.get(sid, 0), d, v) for st, n, d, v in SB.BL(t)]
    return mel, chords, sec, starts, q4, desc, riffs


def check(notes, chords, sec, q4):
    """notas largas (≥ 4) del acorde que suena; todo en la escala de su sección (Re menor, o Mi menor = +2)"""
    tr = {s[0]: s[5] for s in SECTIONS}
    def at(b, st):
        if st >= 14: return chords[b % len(chords)][0]
        if st >= 12 and b in q4: return q4[b]
        return chords[b - 1][0 if st < 8 else 1]
    bad = [(b, st) for b, st, n, d in notes if d >= 4 and (n - at(b, st)[0]) % 12 not in at(b, st)[1]]
    out = [(b, st) for b, st, n, d in notes if (n - tr[sec[b - 1]]) % 12 not in D_MIN]
    return bad, out


WAVES = [wavetable([1.0, 0.45, 0.2, 0.1]),                       # 0 voz suave (Icy)
         GN.CWAVES[0],                                           # 1 caja de música
         wavetable([1.0, 0.0, 0.5, 0.0, 0.28, 0.0, 0.12]),       # 2 voz hueca (Gloomy)
         wavetable([1.0, 0.25, 0.4, 0.1, 0.2]),                  # 3 coro (Icy)
         wavetable([1.0, 0.3, 0.1])]                             # 4 colchón (Groove)
I_HOLLOW = dict(CT.I_HOLLOW)
I_BELL = dict(GN.I_BELL, duty=1.0)
I_CHOIR = dict(CI.I_CHOIR, duty=3.0)
I_PAD = dict(SB.I_PAD, duty=4.0)
LV = {'lead': 0, 'dbl': -8, 'echo': -12, 'voice': -5.5, 'hollow': 1.5, 'bell': -4, 'choir': -7, 'legs': -5, 'legs2': -12,
      'stabs': -6, 'mar': -6, 'ice': -7, 'shim': -10, 'gstabs': -6, 'scr': -13, 'pad': -10, 'hits': -4, 'spark': -12,
      'bass': 3, 'gbass': 5, 'kick': 3, 'toms': 0, 'snare': 0, 'hat': -9, 'ohat': -11, 'crash': -7}
LUFS = -9.5                                         # (como el Groove: en un evento sincronizado la música manda)
G_V2 = {'lead': 1.0, 'dbl': 1.30215, 'echo': 1.9579, 'voice': 1.54446, 'hollow': 1.74201, 'bell': 3.03672, 'choir': 1.43437,
        'legs': 5.32725, 'legs2': 6.24919, 'stabs': 1.70101, 'mar': 2.5838, 'ice': 1.72782, 'shim': 3.31731, 'gstabs': 2.75546,
        'scr': 6.73067, 'pad': 1.99632, 'hits': 0.499219, 'spark': 0.737165, 'bass': 1.68005, 'gbass': 1.41344, 'kick': 1.00699,
        'toms': 0.986997, 'snare': 0.772622, 'hat': 0.443507, 'ohat': 0.400165, 'crash': 0.432239}


def build():
    mel, chords, sec, starts, q4, desc, riffs = song()
    NB = len(chords)
    style_of = {s[0]: s[2] for s in SECTIONS}
    LEN = {s[0]: len(s[4]) for s in SECTIONS}
    sty = lambda b: style_of[sec[b - 1]]
    pos = lambda b: b - starts[sec[b - 1]] + 1
    last = lambda b: pos(b) == LEN[sec[b - 1]]
    bpm_of = [RAMP.get((sec[b - 1], pos(b)), SEC_BPM.get(sec[b - 1], BPM)) for b in range(1, NB + 1)]
    s16 = lambda b: 60.0 / bpm_of[b - 1] / 4
    bar = lambda b: 16 * s16(b)
    T0 = np.concatenate([[0.0], np.cumsum([bar(b) for b in range(1, NB + 1)])])     # inicio de cada compás (s)
    NF = F.frames_for(T0[NB] + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'dbl', 'echo', 'voice', 'hollow', 'bell', 'p1', 'p2', 'legs', 'legs2', 'c1', 'c2',
                                'mar', 'ice', 'shim', 'g1', 'g2', 'scr', 'pad1', 'pad2', 'h1', 'h2', 'spark')}
    NZ = {k: Noise(NF) for k in ('hat', 'ohat', 'snare', 'crash', 'fx')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: T0[b - 1] + st * s16(b)
    GLOOMY = ('gloomy', 'gloomy_br')
    pause = lambda b, st: sty(b) in GLOOMY and st >= 12 and last(b)            # la PAUSA de la araña
    breath = lambda b, st: sec[b - 1] == 'tantrum_B' and st >= 12 and last(b)   # (el respiro antes de bajar a la cueva)
    ALL = ('final', 'coda')                                                    # los cuatro a la vez
    llam = lambda b: sty(b) == 'coda' and last(b)                              # la parada de la llamada

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=CT.SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # ── MELODÍA: el instrumento de cada cangrejo ──
    for b, st, n, d in mel:
        s, k = sty(b), pos(b)
        t0, t1 = tv(b, st), tv(b, st) + d * s16(b) * 0.93
        if s in GLOOMY:
            play(Cn['hollow'], t0, t1, n, I_HOLLOW, q=q_n163, release=4)
        elif s in ('icy_calm', 'icy_chorus'):
            play(Cn['voice'], t0, t1, n, CI.I_VOICE, q=q_n163, release=3)
            if s == 'icy_chorus' or d >= 4: play(Cn['bell'], t0, t0 + max(d, 4) * s16(b), n + 12, I_BELL, q=q_n163, release=6)
            if s == 'icy_chorus' and k >= 5: play(Cn['dbl'], t0, t1, n + 12, CT.I_PUL, release=2)
        else:                                                 # Tantrum: sierra una octava abajo + pulso (la octava en el grito y el final)
            play(Cn['lead'], t0, t1, n - 12, CT.I_SAW, q=q_saw, release=3)
            play(Cn['dbl'], t0, t1, n + (12 if s in ('chant', 'final', 'coda') else 0), CT.I_PUL, release=2)
            if s == 'coda' and k >= 5: play(Cn['bell'], t0, t0 + max(d, 4) * s16(b), n + 12, I_BELL, q=q_n163, release=6)
        if d >= 3 and s not in GLOOMY:
            play(Cn['echo'], t0 + 3 * s16(b), t0 + 3 * s16(b) + min(d, 3) * s16(b) * 0.8, n, CT.I_ECHO, release=1)
    for b, st, n, d in desc:                                  # la caja de música de la Icy, por encima del final
        play(Cn['bell'], tv(b, st), tv(b, st) + d * s16(b) * 1.05, n + 12, I_BELL, q=q_n163, release=8)
    sung = {(b, st + j) for b, st, n, d in mel for j in range(d)}

    # ── BAJO: el slap de siempre (tresillo del Tantrum) y el slap que CANTA (el riff del Groove) ──
    slap, gslap = SL.Rec(), SL.Rec()

    def bass(b, st, ln, note):
        if pause(b, st) or breath(b, st): return
        slap.add(tv(b, st), tv(b, st) + ln * s16(b), note)

    for b, st, n, d, v in riffs:
        s, k = sty(b), pos(b)
        if s in ALL and v < 60: continue                                       # (en el final, sin fantasmas: menos atropellado)
        gslap.add(tv(b, st), tv(b, st) + d * s16(b) * 0.95, n, v)
        if v >= 120 and (s != 'final' or k > 8):                              # el brillo: los pops, dos octavas arriba
            play(Cn['spark'], tv(b, st), tv(b, st) + s16(b) * 0.9, n + 24, SB.I_SPARK, release=1)

    i6 = 0
    for b in range(1, NB + 1):
        s, k, sid = sty(b), pos(b), sec[b - 1]
        (r1, q1), (r2, q2) = chords[b - 1]
        lo = lambda r: 38 + (r - 38) % 12
        nxt = chords[b % NB][0][0]
        lb = last(b)
        if s == 'intro' or llam(b):                                            # (la llamada: el slap trae la célula, como en la intro)
            if k >= 3:
                for st, ln, iv in ((0, 5.5, 0), (6, 1.8, 0), (8, 1.8, 5), (10, 3.6, 3), (14, 1.8, 0)): bass(b, st, ln, lo(r1) + iv)
        elif s == 'gloomy_br':                                                 # el riff, en el bajo
            for st, ln, iv in ((0, 5.5, 0), (6, 1.8, 0), (8, 1.8, 5), (10, 3.6, 3), (14, 1.8, -2 if b % 2 == 0 else 0)): bass(b, st, ln, lo(r1) + iv)
        elif s == 'icy_calm':
            bass(b, 0, 7.5, lo(r1)); bass(b, 8, 5.5, lo(r2)); bass(b, 14, 1.8, lo(r2) + 7)
        elif s == 'icy_chorus':
            for st in range(0, 16, 2):
                bass(b, st, 1.7, lo(r1 if st < 8 else r2) + (12 if st in (6, 14) else 0))
        elif s in ('tantrum', 'chant', 'gloomy'):                              # tresillo 6-6-4 y una nota de paso
            bass(b, 0, 5.5, lo(r1)); bass(b, 6, 1.8 if r2 != r1 else 5.5, lo(r1))
            if r2 != r1: bass(b, 8, 3.6, lo(r2))
            r3 = q4[b][0] if b in q4 else r2
            step = lo(r3) + (7 if (lo(r3) + 7 - nxt) % 12 in (0, 5, 7) else 12)
            bass(b, 12, 1.8, lo(r3)); bass(b, 14, 1.8, step)

        # ── ACOMPAÑAMIENTO ──
        if s in GLOOMY or (s in ALL and not llam(b)):                          # LAS PATAS de la Gloomy
            for st in range(16):
                if pause(b, st): continue
                r, q = (r1, q1) if st < 8 else (q4[b] if st >= 12 and b in q4 else (r2, q2))
                alone = s == 'gloomy_br' and k <= 4
                base_ = 62 + (r - 62) % 12 + (12 if alone or (s in GLOOMY and k % 4 == 0) else 0)
                note = base_ + GN.LEG8[q][st % 8]
                if s in GLOOMY and lb and st >= 8: note = base_ + 12 - (st - 8)            # bajada cromática hacia la pausa
                quiet = (b, st) in sung or s in ALL
                vs = (0.3 if (b, st) in sung else 0.55) if s in ALL else (0.4 if quiet else 1.0)
                play(Cn['legs'], tv(b, st), tv(b, st) + s16(b) * 0.5, note, GN.I_LEG, vs=vs, release=0)
                if s == 'gloomy' and k >= 5:                                   # el segundo patrón, 6 contra 8
                    play(Cn['legs2'], tv(b, st), tv(b, st) + s16(b) * 0.5, base_ + GN.LEG6[q][i6 % 6], GN.I_LEG2, q=q_vrc6, release=0)
                    i6 += 1
        if s in ('tantrum', 'chant') or (s == 'coda' and k >= 5):             # la marimba de la costa en el tresillo
            for half, (r, q) in enumerate(((r1, q1), (r2, q2))):
                notes = [72 + (r - 72) % 12 + iv for iv in q]
                for j, st in enumerate((0, 3, 6)):
                    if breath(b, half * 8 + st): continue
                    if half == 1 and st == 6 and b in q4: notes = [72 + (q4[b][0] - 72) % 12 + iv for iv in q4[b][1]]
                    play(Cn['mar'], tv(b, half * 8 + st), tv(b, half * 8 + st) + s16(b) * 1.5, notes[(j + half) % 3], CT.I_MAR, release=1)
        if s in ('tantrum', 'chant') + ALL and not llam(b):                   # golpes de quinta en el tresillo
            for st in TRES:
                if breath(b, st): continue
                r = r1 if st < 8 else (q4[b][0] if st >= 12 and b in q4 else r2)
                root = 50 + (r - 50) % 12
                play(Cn['c1'], tv(b, st), tv(b, st) + 2.5 * s16(b), root, CT.I_STAB, release=2)
                play(Cn['c2'], tv(b, st), tv(b, st) + 2.5 * s16(b), root + 7, CT.I_STAB, release=2)
        if s in ('icy_calm', 'icy_chorus'):
            for half, (r, q) in enumerate(((r1, q1), (r2, q2))):
                s0 = half * 8
                notes = [72 + (r - 72) % 12 + iv for iv in q]
                if s == 'icy_chorus':                                          # campanillas en el tresillo
                    for j, st in enumerate((0, 3, 6)):
                        play(Cn['ice'], tv(b, s0 + st), tv(b, s0 + st) + s16(b) * 1.5, notes[(j + half) % 3] + 12, CI.I_ICE, release=1)
                for st in range(8):                                            # arpegio brillante
                    play(Cn['shim'], tv(b, s0 + st), tv(b, s0 + st) + s16(b) * 0.7, notes[(0, 1, 2, 1)[st % 4]] + (12 if st >= 4 else 0), CI.I_SHIM, release=0)
                vs = 1.3 if s == 'icy_chorus' and k >= 5 else (0.0 if s == 'icy_chorus' else 1.0)
                if vs:                                                         # coro
                    play(Cn['p1'], tv(b, s0), tv(b, s0) + 7.6 * s16(b), notes[1] - 12, I_CHOIR, q=q_n163, vs=vs, release=5)
                    play(Cn['p2'], tv(b, s0), tv(b, s0) + 7.6 * s16(b), notes[2] - 12, I_CHOIR, q=q_n163, vs=vs, release=5)
            if s == 'icy_chorus':                                              # golpes de quinta a negras
                for st in (0, 4, 8, 12):
                    root = 50 + ((r1 if st < 8 else r2) - 50) % 12
                    play(Cn['c1'], tv(b, st), tv(b, st) + 2.5 * s16(b), root, CT.I_STAB, release=2)
                    play(Cn['c2'], tv(b, st), tv(b, st) + 2.5 * s16(b), root + 7, CT.I_STAB, release=2)
        if s in ('groove_a', 'groove_b') + ALL:                                # el Groove: golpes de acorde a contratiempo
            stop = llam(b)
            gb = 64 + (r1 - 64) % 12
            if not stop:
                for st in (6, 14) if s == 'final' and k <= 8 else (2, 6, 10, 14):
                    play(Cn['g1'], tv(b, st), tv(b, st) + 1.2 * s16(b), gb + q1[1], SB.I_STAB, release=1)
                    play(Cn['g2'], tv(b, st), tv(b, st) + 1.2 * s16(b), gb + q1[2], SB.I_STAB, release=1)
            if not stop:                                                       # el rasgueo en semicorcheas
                hi = 76 + (r1 - 76) % 12
                for st in range(16):
                    play(Cn['scr'], tv(b, st), tv(b, st) + s16(b) * 0.4, hi + (q1[1] if st % 2 else q1[2]), SB.I_SCR,
                         vs=1.0 if st % 4 == 2 else 0.5, release=0)
            if s in ('groove_a', 'groove_b'):                                  # colchón
                pb = 57 + (r1 - 57) % 12
                for j, iv in enumerate(q1[1:]):
                    play(Cn[('pad1', 'pad2')[j]], tv(b, 0), tv(b, 0) + bar(b) * 0.97, pb + iv, I_PAD, q=q_n163, release=6)
            if stop:                                                           # la parada: un golpe de banda y la llamada
                play(Cn['h1'], tv(b, 0), tv(b, 0) + 3 * s16(b), gb + q1[1], SB.I_HIT, q=q_saw, release=3)
                play(Cn['h2'], tv(b, 0), tv(b, 0) + 3 * s16(b), gb + q1[2], SB.I_HIT, q=q_saw, release=3)
            if not stop and k % 4 == 0 and s not in ALL:                       # golpes de banda al cerrar frase
                for st in (12, 14) if k % 8 == 0 else (14,):
                    play(Cn['h1'], tv(b, st), tv(b, st) + 1.5 * s16(b), gb + q1[1], SB.I_HIT, q=q_saw, release=2)
                    play(Cn['h2'], tv(b, st), tv(b, st) + 1.5 * s16(b), gb + q1[2], SB.I_HIT, q=q_saw, release=2)

        # ── BATERÍA ──
        for st in range(16):
            t = tv(b, st)
            if pause(b, st) or breath(b, st): continue
            if s == 'intro' or llam(b):                                        # tribal: bombo en el tresillo, timbales
                if st in TRES: hit(kick, TN.KICK_DEEP, t, 1.0)
                pat = {2: 0, 3: 1, 8: 2, 10: 0, 11: 1, 14: 2, 15: 2} if k % 2 else {2: 0, 3: 0, 4: 1, 8: 2, 9: 2, 10: 1, 11: 0, 14: 2, 15: 1}
                if st in pat: hit(tom, W.TOMS[pat[st]], t, 1.0)
                if (k >= 3 or s == 'coda') and st % 2 == 1 and st not in pat: NZ['hat'].hit(t, 1, [3, 1])
                if (k == 4 or s == 'coda') and st >= 8: snare(t, 0.4 + (st - 8) * 0.07, [7 + (st - 8), 5, 2])
                if s == 'coda' and st == 0: snare(t, 0.9); NZ['crash'].hit(t, 3, CT.CRASH)
                continue
            if s == 'gloomy_br':                                               # tribal y seco, lejos
                if st in TRES: hit(kick, TN.KICK_DEEP, t, 1.0)
                pat = {2: 0, 3: 1, 8: 2, 10: 0, 11: 1, 14: 2, 15: 2} if k % 2 else {2: 0, 3: 0, 4: 1, 8: 2, 9: 2, 10: 1, 11: 0, 14: 2, 15: 1}
                if st in pat and k >= 3: hit(tom, W.TOMS[pat[st]], t, 0.6)
                if st == 8 and k >= 5: NZ['snare'].hit(t, 3, [10, 5, 2], short=1)
            elif s == 'gloomy':                                                # medio tiempo: bombo hondo, chasquido de pinza en el 3
                if st in TRES: hit(kick, TN.KICK_DEEP, t, 1.0)
                if st == 8: NZ['snare'].hit(t, 3, [10, 5, 2], short=1)
                elif st in (3, 14): hit(tom, W.TOMS[2], t, 0.6)
                elif st % 4 == 2: NZ['hat'].hit(t, 1, [3, 1])
            elif s == 'icy_calm':                                              # ligera: tresillo, caja suave, cascabeles
                if st in TRES: hit(kick, TN.KICK, t, 0.9)
                if st in (4, 12): snare(t, 0.55, [9, 5, 2])
                else: NZ['hat'].hit(t, 0, [5, 3, 1] if st % 2 == 0 else [2, 1])
            elif s == 'icy_chorus':                                            # bombo a negras + 4y, caja 2 y 4, timbales
                if st % 4 == 0 or st == 14: hit(kick, TN.KICK, t, 1.0)
                if st in (4, 12): snare(t, 1.0)
                elif st in (10, 11) and k % 2 == 0: hit(tom, W.TOMS[st - 10], t, 0.9)
                elif st in (7, 15) and k >= 5: snare(t, 0.35, [6, 3, 1])
                else: NZ['hat'].hit(t, 0, [5, 3, 1] if st % 2 == 0 else [2, 1])
            elif s in ('groove_a', 'groove_b'):                                # funk, el del clímax (bombo también en el "1 y")
                if st in (0, 10) or (st == 7 and k % 2 == 0) or (st == 3 and k % 2 == 1): hit(kick, TN.KICK_DEEP, t, 1.0)
                if st in (4, 12): snare(t, 1.0)
                elif st in (7, 15) or (st == 9 and s == 'groove_b'): snare(t, 0.22, [5, 2, 1])
                if st % 4 == 2: NZ['ohat'].hit(t, 1, [6, 5, 4, 3, 2, 1])
                else: NZ['hat'].hit(t, 1, [5, 2, 1] if st % 2 == 0 else [3, 1])
            elif s in ALL:                                                     # los cuatro: tresillo + funk + timbales tribales
                if st in TRES or st == 10 or (st == 3 and k % 2 == 1): hit(kick, TN.KICK_DEEP if st in TRES else TN.KICK, t, 1.0 if st in TRES else 0.85)
                if st in (4, 12): snare(t, 1.0)
                elif st in (7, 15): snare(t, 0.3, [6, 3, 1])
                elif k % 2 == 0 and st in (2, 11, 14): hit(tom, W.TOMS[{2: 0, 11: 1, 14: 2}[st]], t, 0.9)
                if st % 4 == 2: NZ['ohat'].hit(t, 1, [6, 5, 4, 3, 2, 1])
                elif st not in (4, 12): NZ['hat'].hit(t, 1, [4, 2, 1] if st % 2 == 0 else [3, 1])
            else:                                                              # Tantrum (tema, grito, coda): tiempo entero
                if st in TRES or st == 10 or (st == 3 and b % 2 == 0 and s != 'tantrum'): hit(kick, TN.KICK, t, 1.0 if st in TRES else 0.85)
                if st in (4, 12): snare(t, 1.0)
                elif st in (7, 15) and (s != 'tantrum' or b % 2 == 0): snare(t, 0.35, [6, 3, 1])
                elif st in (3, 14) or (s == 'chant' and st in (2, 10, 11)):
                    hit(tom, W.TOMS[{2: 0, 3: 2, 10: 0, 11: 1, 14: 1}[st]], t, 0.9)
                else: NZ['hat'].hit(t, 1, [4, 2, 1] if st % 2 == 0 else [3, 1])
            if lb and st >= 12 and s not in GLOOMY:                            # entrada a la sección siguiente
                snare(t, 0.6 + (st - 12) * 0.1, [9 + (st - 12), 5, 2]); hit(tom, W.TOMS[min(2, st - 12)], t, 0.7)
            if st == 0 and b > 1 and (k == 1 or (s in ('chant', 'coda', 'final', 'icy_chorus') and k % 2 == 1)
                                      or (s in ('tantrum', 'groove_a', 'groove_b') and k % 4 == 1)):
                NZ['crash'].hit(t, 3, CT.CRASH)
        if s in ('icy_chorus', 'groove_b') and lb:                             # subida de ruido hacia el Groove / el final
            n_ = int(bar(b) * 60)
            for j in range(n_):
                x_ = j / (n_ - 1)
                NZ['fx'].hit(tv(b, 0) + j / 60.0, int(round(9 - 7 * x_)), [max(1, int(round(7 * x_ ** 1.5)))])

    # ── STEMS Y MEZCLA ──
    n = int(T0[NB] * SR)
    at = int(T0[INTRO] * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k_: cut(F.pulse_dac(F.render_pulse(Cn[k_])))
    wave = lambda k_: cut(F.render_wave(Cn[k_], WAVES) * 0.0075)
    saw = lambda k_: cut(F.pulse_dac(F.render_saw(Cn[k_])))
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    noise = lambda k_: cut(F.tnd_dac(NZ[k_].render() / 22638.0 * 12))
    S = {
        'lead': saw('lead'), 'dbl': pulse('dbl'), 'echo': pulse('echo'),
        'voice': wave('voice'), 'hollow': wave('hollow'), 'bell': wave('bell'), 'choir': wave('p1') + wave('p2'),
        'legs': pulse('legs'), 'legs2': cut(F.render_pulse(Cn['legs2']) * 0.0075),
        'stabs': pulse('c1') + pulse('c2'), 'mar': pulse('mar'), 'ice': pulse('ice'), 'shim': pulse('shim'),
        'gstabs': pulse('g1') + pulse('g2'), 'scr': pulse('scr'), 'pad': wave('pad1') + wave('pad2'),
        'hits': saw('h1') + saw('h2'), 'spark': GN.delay(pulse('spark'), 3 * S16, 0.35, 2, 4000),
        'bass': slap.render(n + tail), 'gbass': gslap.render(n + tail),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + noise('snare'),
        'hat': noise('hat'), 'ohat': noise('ohat'), 'crash': noise('crash') + noise('fx'),
    }
    S = {k_: GN.fold(v, n, at) for k_, v in S.items() if np.abs(v).max() > 0}
    S['hollow'] = GN.delay(S['hollow'], 3 * 15.0 / SEC_BPM['gloomy_A'], 0.22, 2)[:len(S['hollow'])]     # (un poco de cueva en la voz)
    S['bell'] = GN.delay(S['bell'], 3 * S16, 0.25, 2, 3200)[:len(S['bell'])]
    # ganancias CONGELADAS en las de la v2 aprobada (GN.level sobre su pista entera): GN.level mide "mientras suena"
    # respecto al pico de cada grupo, así que cambiar el Groove o la coda movía la mezcla de los otros tres cangrejos
    # (el bajo del Tantrum pasaba del 28 al 19 %). Un grupo nuevo se mide como siempre
    g = GN.level(S, {k_: LV[k_] for k_ in S}, 'lead')
    g.update({k_: v for k_, v in G_V2.items() if k_ in S})
    from scipy.signal import butter, sosfilt
    x = sum(S[k_] * g[k_] for k_ in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd = lambda k_, w: S[k_] * g[k_] * w if k_ in S else 0.0
    side = (sd('mar', 0.5) - sd('echo', 0.6) + sd('stabs', 0.3) + sd('hat', 0.3) + sd('legs', 0.35) - sd('legs2', 0.5)
            + sd('ice', 0.5) + sd('shim', 0.5) + sd('choir', 0.4) + sd('gstabs', 0.35) - sd('scr', 0.5) + sd('pad', 0.3)
            + sd('ohat', 0.3) + sd('spark', 0.5) - sd('hits', 0.15))
    # cada sección, a SU nivel respecto al tema A del Tantrum (DYN): se mide cada una y se corrige (los cuatro temas
    # tienen densidades muy distintas; sin esto el estribillo de la Icy salía 5 dB por encima y la cueva 2,5 por debajo)
    lu = {}
    for sid, *_ in SECTIONS:
        i0 = int(T0[starts[sid] - 1] * SR); i1 = int(T0[starts[sid] - 1 + LEN[sid]] * SR)
        lu[sid] = F.loudness(np.stack([x[i0:i1], x[i0:i1]], 1))
    corr = {sid: -(lu[sid] - lu['tantrum_A']) for sid in lu}
    env = np.ones(len(x))
    for b in range(1, NB + 1):
        a_, e_ = DYN[sec[b - 1]]
        a_, e_ = a_ + corr[sec[b - 1]], e_ + corr[sec[b - 1]]
        first, ln = starts[sec[b - 1]], LEN[sec[b - 1]]
        i0, i1 = int(T0[b - 1] * SR), min(len(x), int(T0[b] * SR))
        u = (np.arange(i1 - i0) / (i1 - i0) + (b - first)) / ln
        env[i0:i1] = 10 ** ((a_ + (e_ - a_) * u) / 20)
    env[n:] = env[n - 1]
    k_ = int(0.03 * SR); env = np.convolve(np.pad(env, k_, mode='edge'), np.ones(2 * k_ + 1) / (2 * k_ + 1), mode='valid')[:len(x)]
    x, side = x * env, side * env
    y = F.master(np.stack([x + side, x - side], 1), lufs=LUFS)

    GN.report(NAME, y, S, g, n)
    if os.environ.get('STEMS'):                                   # (reparto de energía por sección)
        for sid, *_ in SECTIONS:
            i0 = int(T0[starts[sid] - 1] * SR); i1 = int(T0[starts[sid] - 1 + LEN[sid]] * SR)
            e = {k_: np.mean((S[k_][i0:i1] * g[k_]) ** 2) for k_ in S}; tot = sum(e.values())
            print(f'    {sid:14s} ' + ' '.join(f'{k_} {100 * v / tot:.0f}%' for k_, v in sorted(e.items(), key=lambda kv: -kv[1]) if v / tot > 0.02))
    bad, out = check(mel + desc, chords, sec, q4)
    print(f'  {BPM:g} BPM (Gloomy 144, Groove 150), intro {INTRO} + bucle {NB - INTRO} compases ({T0[INTRO]:.1f} + {T0[NB] - T0[INTRO]:.1f} s); melodía {len(mel)} notas, riff {len(riffs)}')
    print(f'  notas largas fuera del acorde: {bad or "ninguna"} · fuera de la escala: {out or "ninguna"}')
    secs = []
    for sid, boss, *_ in SECTIONS:
        i0 = int(T0[starts[sid] - 1] * SR); i1 = int(T0[starts[sid] - 1 + LEN[sid]] * SR)
        lu = F.loudness(y[i0:i1]) if i1 - i0 > SR * 0.5 else float('nan')
        secs.append(dict(seccion=sid, jefe=boss, compas=starts[sid], compases=LEN[sid], bpm=bpm_of[starts[sid] - 1],
                         inicio_s=round(T0[starts[sid] - 1], 3), fin_s=round(T0[starts[sid] - 1 + LEN[sid]], 3),
                         lufs=round(lu, 1)))
        print(f'    {sid:14s} {boss:8s} compás {starts[sid]:3d}  {secs[-1]["inicio_s"]:6.1f}-{secs[-1]["fin_s"]:6.1f} s  {lu:6.1f} LUFS')
    return y, at, mel, secs, T0


def preview(y, at, mel, secs, T0):
    os.makedirs(PREVIEW, exist_ok=True)
    tag = f'{BPM:g}bpm'
    def enc(x, name):
        wav = os.path.join(PREVIEW, name + '.wav'); ogg = wav[:-4] + '.ogg'
        F.write_wav(wav, x)
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"'); os.remove(wav)
    loop = y[at:]
    enc(np.concatenate([y, loop]), f'{NAME}_{tag}_intro_y_dos_vueltas')
    k = int((T0[-1] - T0[-9]) * SR)
    enc(np.concatenate([loop[-k:], loop[:k]]), f'{NAME}_{tag}_costura')
    enc(y[:at], f'{NAME}_{tag}_intro'); enc(loop, f'{NAME}_{tag}_loop')
    sc = {d['seccion']: d for d in secs}                       # el Groove con lo que tiene alrededor (2 compases)
    enc(y[int(T0[sc['groove_A']['compas'] - 3] * SR):int(T0[sc['final']['compas'] + 1] * SR)], f'{NAME}_{tag}_groove')
    W.write_mid(os.path.join(PREVIEW, f'{NAME}_{tag}.mid'), mel, BPM)
    with open(os.path.join(PREVIEW, f'secciones_{tag}.json'), 'w') as f:
        json.dump(dict(bpm=BPM, intro_compases=INTRO, secciones=secs), f, indent=1, ensure_ascii=False)
    print(f'  previas en {PREVIEW}')


if __name__ == '__main__':
    y, at, mel, secs, T0 = build()
    if not os.environ.get('REPORT'):
        preview(y, at, mel, secs, T0)
        if os.environ.get('INSTALL'):                 # (el evento de los cangrejos: catálogo `crab_mashup`)
            GN.export('crab_mashup', y, at)
            W.write_mid(F.out('crab_mashup', 'mid'), mel, BPM)     # (a un solo tempo: la Gloomy y el Groove van más lentos)
