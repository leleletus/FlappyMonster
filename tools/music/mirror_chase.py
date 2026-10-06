#!/usr/bin/env python3
# ¡CORRE! — la música de la PERSECUCIÓN del Espejo (el nivel de antes del jefe final: `huida_del_espejo`).
#
# El encargo: una pista de persecución intensa, DRUM & BASS llevado a chiptune rápido y agresivo (referencia solo de
# género y energía: "Losing Control (Sophon Remix)" de Stonebank; no se copia nada): percusión muy fuerte y rápida,
# bajo que empuja, frases melódicas CORTAS y rítmicas, sensación de movimiento y urgencia, con variación y subidas. Y
# que sea el tema del jefe final convertido en huida: sus motivos, de forma natural y rítmica.
#
# De EL ESPEJO (tools/music/mirror_boss.py, 12/8) vienen las NOTAS; aquí cambian de compás y de carácter (4/4 en
# semicorcheas a 174 BPM, a golpes cortos y sincopados):
#   · la CABEZA DEL TEMA (Fa#-Do#-Fa#-La-Sol#-Fa# · La-Fa#-La-Re · Si-Sol#-Si-Mi…) → el gancho del "drop" (A), troceado;
#   · el MOTIVO DEL ESPEJO (Do#-Sol#-Mi#-Do#, la llamada del revés) → cierra cada media frase sobre la dominante, lo
#     canta despacio la campana en el respiro (K) y trepa en las subidas (U);
#   · "EL TEMA DEL HÉROE" (la muestra de la antigua música de nivel, level.ogg 0:41-1:02; en el jefe, ~1:06-1:19) →
#     la sección B: sus notas con su 3+3+2 de vuelta (el jefe lo había pasado a negras), en golpes repetidos, sobre
#     sus acordes Sim · Do# · Fa#m | Sim · Do# · Re · Mi; la 2ª vez, una octava arriba y con todo;
#   · el RIFF DE LA FURIA (nota repetida y salto) → la sección G, en semicorcheas corridas.
# Fa# menor armónico, como el jefe. Batería de DnB "two-step": bombo en 1 y en el "y" del 3, caja en 2 y 4, cajas
# fantasma, charles a semicorcheas; bajo = sub (triángulo) + un diente de sierra que tiembla una octava arriba.
#
# Forma: INTRO 4 (charles, el bajo, el motivo a golpes) + SUBIDA 4 | A 8 · A' 8 (drop: el tema) · B 8 · B' 8 (el héroe)
# · K 8 (respiro a medio tiempo: campana y colchón; vuelve el bombo) · G 8 (furia) · A'' 8 (el tema con todo) ·
# SUBIDA 4 = bucle de 60 compases (82,8 s). La SUBIDA es el MISMO compás al final de la intro y al final del bucle
# (regla de las pistas con intro: mismo último compás y sin doblar colas), y acaba en un silencio de un tiempo antes
# del drop.
#
#   ~/.venvs/fm-music/bin/python tools/music/mirror_chase.py → assets/music/bosses/mirror_chase_{intro,loop}.ogg
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado). Después: tools/music/levels.py
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_tri, q_saw, q_n163
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W

NAME = 'mirror_chase'
BPM = 174
S16 = 60.0 / BPM / 4
BAR = 16 * S16
N = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
MAJ, MIN = (0, 4, 7), (0, 3, 7)
SCALE = {6, 8, 9, 11, 1, 2, 4, 5, 7}          # Fa# menor + la sensible (Mi# = Fa) + la napolitana (Sol)


def ch(s):
    return (N[s[:-1]], MIN) if s.endswith('m') else (N[s], MAJ)


def PH(*bars):
    out = []
    for i, txt in enumerate(bars):
        for tok in txt.split():
            st, rest = tok.split(':'); nm, d = rest.split('/')
            out.append((i + 1, int(st), 12 * (int(nm[-1]) + 1) + N[nm[:-1]], int(d)))
    return out


def run(notes):                                # un compás de semicorcheas corridas
    return ' '.join('%d:%s/1' % (i, n) for i, n in enumerate(notes.split()))


MIRROR = "0:C#6/2 3:G#5/2 6:F5/2 8:C#5/2 11:F5/2 14:G#5/2"                 # el motivo del espejo, a golpes (3+3+2…)
T_A = ["0:F#5/2 3:C#5/1 4:F#5/2 6:A5/2 10:G#5/2 12:F#5/2",                  # la cabeza del tema del jefe, troceada
       "0:A5/2 3:F#5/1 4:A5/2 6:D6/4 12:A5/2 14:F#5/2",
       "0:B5/2 3:G#5/1 4:B5/2 6:E6/2 10:D6/2 12:B5/2",
       MIRROR,
       "0:F#5/2 3:C#5/1 4:F#5/2 6:A5/2 10:B5/2 12:C#6/2",
       "0:D6/2 3:B5/1 4:D6/2 6:F#6/4 12:D6/2 14:B5/2",
       "0:D6/2 2:B5/2 4:G5/2 8:F5/2 10:G#5/2 12:C#6/4"]                    # napolitana y dominante: el espejo, hacia arriba
A_END = ["0:F#5/3 4:F#5/2 8:A5/2 12:C#6/2"]
A_END2 = ["0:F#5/6 8:F#6/4"]
CH_A = ['F#m', 'D', 'E', 'C#', 'F#m', 'Bm', ['G', 'C#'], 'F#m']
T_B = ["0:A5/3 3:A5/3 6:A5/2 8:F#5/3 11:F#5/3 14:F#5/2",                    # el tema del héroe, con su 3+3+2
       "0:C#6/3 3:B5/3 6:A5/2 8:G#5/3 11:A5/3 14:B5/2",
       "0:C#5/3 3:E5/3 6:A5/2 8:G#5/3 11:E5/3 14:F#5/2",
       "0:C#5/3 3:C#5/3 6:C#5/2 8:C#6/2 10:A5/2 12:F#5/4",
       "0:D5/3 3:D5/1 4:E5/2 6:F#5/2 8:E5/3 11:D5/3 14:D5/2",
       "0:E5/3 3:E5/1 4:F#5/2 6:G#5/2 8:F#5/3 11:E5/3 14:E5/2",
       "0:F#5/3 3:F#5/3 6:F#5/2 8:D5/3 11:D5/3 14:D5/2",
       "0:A5/3 3:G#5/3 6:A5/2 8:B5/4 12:B5/2 14:C#6/2"]
CH_B = ['Bm', 'C#', 'F#m', 'F#m', 'Bm', 'C#', 'D', 'E']
T_K = ["0:C#6/8 8:A5/8", "0:F#5/8 8:A5/8", "0:B5/8 8:D6/8", "0:C#6/4 4:G#5/4 8:F5/4 12:C#5/4",          # el espejo, despacio
       "0:F#5/6 6:C#5/2 8:F#5/4 12:A5/4", "0:A5/6 6:F#5/2 8:A5/4 12:D6/4", "0:D6/4 4:B5/4 8:G5/8",
       "0:C#5/2 2:F5/2 4:G#5/2 6:C#6/2 " + ' '.join('%d:C#6/1' % i for i in range(8, 16))]
CH_K = ['F#m', 'D', 'Bm', 'C#', 'F#m', 'D', 'G', 'C#']
T_G = [run("F#5 F#5 A5 F#5 F#5 C#6 F#5 F#5 A5 G#5 F#5 E5 F#5 A5 C#6 A5"),                                # la furia, corrida
       run("F#5 F#5 A5 F#5 F#5 C#6 F#5 F#5") + " 8:B5/2 10:A5/2 12:G#5/2 14:F#5/2",
       run("G5 G5 B5 G5 G5 D6 G5 G5 B5 A5 G5 F#5 G5 B5 D6 B5"),
       run("C#6 C#6 C#6 G#5 G#5 G#5 F5 F5 F5 C#5 C#5 C#5 F5 G#5 C#6 G#5"),                               # el espejo, martilleado
       run("C#6 C#6 E6 C#6 C#6 F#6 C#6 C#6 E6 D6 C#6 B5 C#6 E6 F#6 E6"),
       run("B5 B5 D6 B5 B5 F#6 B5 B5") + " 8:D6/2 10:C#6/2 12:B5/2 14:A5/2",
       run("D6 D6 B5 B5 G5 G5 D6 D6 C#6 C#6 G#5 G#5 F5 F5 C#6 C#6"),
       "0:C#5/1 1:F5/1 2:G#5/1 3:C#6/1 4:G#5/1 5:F5/1 6:C#6/2 8:C#6/2 10:C#6/2 12:F6/4"]
CH_G = ['F#m', 'F#m', 'G', 'C#', 'F#m', 'Bm', ['G', 'C#'], 'C#']
T_IN = [MIRROR, "0:C#6/2 3:G#5/2 6:F5/2 8:C#5/6", MIRROR, "0:C#5/2 3:F5/2 6:G#5/2 8:C#6/6"]
CH_IN = ['C#'] * 4
# LA SUBIDA (igual al final de la intro y del bucle): el espejo trepando, redoble, y un tiempo de SILENCIO antes del drop
T_U = ["0:C#5/3 3:F5/3 6:G#5/2 8:C#6/8", "0:F5/3 3:G#5/3 6:C#6/2 8:F6/8",
       "0:C#6/2 2:C#6/2 4:C#6/2 6:C#6/2 " + ' '.join('%d:C#6/1' % i for i in range(8, 16)),
       ' '.join('%d:F6/1' % i for i in range(0, 12))]
CH_U = ['C#'] * 4
ORDER = ['IN', 'U1', 'A', 'A2', 'B', 'B2', 'K', 'G', 'A3', 'U2']
INTRO = 8
BUILD = ('U1', 'U2')
THEME = ('A', 'A2', 'A3')
HERO = ('B', 'B2')
FAST = ('G',)                                  # (notas de paso corridas: no cuentan en la comprobación del acorde)


def song():
    mel, chords, tag, starts = [], [], [], []

    def section(kind, bars, cs, up=0):
        base = len(chords)
        starts.append(base + 1)
        for b, st, n, d in PH(*bars): mel.append((base + b, st, n + up, d))
        for c in cs:
            chords.append((ch(c[0]), ch(c[1])) if isinstance(c, list) else (ch(c), ch(c)))
            tag.append(kind)
    section('IN', T_IN, CH_IN)
    section('U1', T_U, CH_U)
    section('A', T_A + A_END, CH_A)
    section('A2', T_A + A_END2, CH_A)
    section('B', T_B, CH_B)
    section('B2', T_B, CH_B, 12)
    section('K', T_K, CH_K)
    section('G', T_G, CH_G)
    section('A3', T_A + A_END2, CH_A)
    section('U2', T_U, CH_U)
    return mel, chords, tag, starts


def check(mel, chords, tag):
    at = lambda b, st: chords[b - 1][0 if st < 8 else 1]
    bad = [(b, st) for b, st, n, d in mel if d >= 4 and tag[b - 1] not in FAST and tag[b - 1] not in HERO
           and (n - at(b, st)[0]) % 12 not in at(b, st)[1]]
    out = [(b, st) for b, st, n, d in mel if n % 12 not in SCALE and tag[b - 1] not in HERO]
    return bad, out


WAVES = [wavetable([1.0, 0.5, 0.33, 0.2, 0.12]), GN.CWAVES[0], wavetable([1.0, 0.25, 0.4, 0.1, 0.2])]
I_SAW = {'vol': [15, 15, 14, 13, 12, 11], 'sus': 11}                         # la voz: picada, sin vibrato
I_PUL = {'vol': [12, 11, 9, 8, 7, 6], 'sus': 6, 'duty': [0.125, 0.25]}
I_REESE = {'vol': [13, 14, 14, 13], 'sus': 13, 'vib': (0, 0.35, 8.5)}          # el bajo que TIEMBLA (diente de sierra)
I_TRI = {'vol': [15], 'sus': 15}
I_BELL = dict(GN.I_BELL, duty=1.0)
I_CHOIR = {'vol': [3, 5, 7, 8, 9, 9, 10], 'sus': 10, 'vib': (20, 0.12, 4.5), 'duty': 2.0}
I_STAB = {'vol': [13, 10, 6, 3, 2, 1], 'sus': 0, 'duty': 0.25}
I_ARP = {'vol': [7, 5, 3, 2], 'sus': 1, 'duty': 0.125}
SNARE_N, CRASH = [15, 12, 8, 5, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
GHOST = [6, 3, 1]


def build(lufs=-9.5):
    mel, chords, tag, starts = song()
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'dbl', 'bell', 'p1', 'p2', 'c1', 'c2', 'arp', 'bass', 'reese')}
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
        t0 = tv(b, st)
        if kind == 'K':                                        # respiro: la campana, con eco
            play(Cn['bell'], t0, t0 + max(d, 4) * S16 * 1.1, n, I_BELL, q=q_n163, release=8)
            continue
        gate = 0.8 if d <= 2 else 0.9                          # picado
        play(Cn['lead'], t0, t0 + d * S16 * gate, n, I_SAW, q=q_saw, release=1)
        if kind in ('A2', 'A3', 'B2', 'G') or kind in BUILD:   # la octava (pulso) en las vueltas con todo
            play(Cn['dbl'], t0, t0 + d * S16 * gate, n + (12 if kind != 'B2' else -12), I_PUL, release=1)
        if kind in ('IN',): play(Cn['bell'], t0, t0 + 3 * S16, n, I_BELL, q=q_n163, release=4)

    for b in range(1, NB + 1):
        kind = tag[b - 1]
        k = b - starts[ORDER.index(kind)] + 1                  # compás dentro de la sección
        (r1, q1), (r2, q2) = chords[b - 1]
        lo = lambda r: 30 + (r - 30) % 12                      # (Fa#1 … Fa2)
        last = (b + 1) in starts or b == NB
        gap = kind in BUILD and k == 4                         # el último compás de la subida: se corta en el 4º tiempo

        def bass(st, ln, r, up=0):
            if gap and st >= 12: return
            t = tv(b, st)
            play(Cn['bass'], t, t + ln * S16, lo(r) + 12 + up, I_TRI, q=q_tri, release=0)
            if kind not in ('IN', 'K') or (kind == 'K' and k >= 5):
                play(Cn['reese'], t, t + ln * S16 * 0.92, lo(r) + 24 + up, I_REESE, q=q_saw, release=1)
        # ── BAJO: empuja con el bombo (0 y el "y" del 3) y contesta ──
        if kind == 'K' and k <= 4:
            bass(0, 15.5, r1)
        elif kind in BUILD:
            for st in range(0, 16, 2 if k <= 2 else 1): bass(st, 1.6 if k <= 2 else 0.8, r1, 12 if (st // 2) % 2 and k > 2 else 0)
        elif kind == 'IN':
            if k >= 3: bass(0, 5.5, r1); bass(10, 5.5, r1)
        elif kind in FAST:                                     # la furia: corcheas al unísono, sin parar
            for st in range(0, 16, 2): bass(st, 1.7, r1 if st < 8 else r2, 12 if st % 8 == 6 else 0)
        else:
            bass(0, 5.5, r1); bass(6, 3.5, r1, 12); bass(10, 3.5, r2); bass(14, 1.8, r2, 7 if q2 == MAJ or True else 0)
        for half, (r, q) in enumerate(((r1, q1), (r2, q2))):
            s0 = half * 8
            notes = [66 + (r - 66) % 12 + iv for iv in q]
            # golpes de acorde sincopados (drops y héroe)
            if kind in THEME or kind in HERO or kind in FAST:
                for st in ((3, 6) if kind not in FAST else (2, 6)):
                    if gap: break
                    play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + 1.4 * S16, notes[0], I_STAB, release=1)
                    play(Cn['c2'], tv(b, s0 + st), tv(b, s0 + st) + 1.4 * S16, notes[2], I_STAB, release=1)
            # arpegio en semicorcheas (2ª vuelta del héroe, tema final y respiro tardío)
            if kind in ('B2', 'A3') or (kind == 'K' and k >= 5):
                for st in range(8):
                    play(Cn['arp'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 0.7, notes[(0, 1, 2, 1)[st % 4]] + (12 if st >= 4 else 0) + 12, I_ARP, release=0)
            # colchón: el respiro y la intro
            if kind in ('K', 'IN'):
                vs = 1.0 if kind == 'K' else 0.6
                play(Cn['p1'], tv(b, s0), tv(b, s0) + 7.6 * S16, notes[1], I_CHOIR, q=q_n163, vs=vs, release=5)
                play(Cn['p2'], tv(b, s0), tv(b, s0) + 7.6 * S16, notes[2], I_CHOIR, q=q_n163, vs=vs, release=5)
        # ── BATERÍA (DnB two-step) ──
        for st in range(16):
            t = tv(b, st)
            if gap and st >= 12: break
            hat = lambda v=None: NZ['hat'].hit(t, 0, v or ([6, 3, 1] if st % 4 == 2 else [4, 2] if st % 2 == 0 else [2, 1]))
            if kind == 'IN':
                hat()
                if k >= 3 and st in (0, 10): hit(kick, TN.KICK, t, 0.9)
            elif kind in BUILD:                                # redoble que se acelera: negras, corcheas, semicorcheas
                if st % 4 == 0: hit(kick, TN.KICK, t, 1.0)
                step = (4, 2, 1, 1)[k - 1]
                if st % step == 0:
                    u = ((k - 1) * 16 + st) / 60.0
                    snare(t, 0.35 + 0.65 * u, [int(6 + 9 * u), int(4 + 6 * u), 3, 1])
                if k >= 3 and st % 4 == 0: hit(tom, W.TOMS[2 - (st // 4) % 3], t, 0.8)
            elif kind == 'K':                                  # medio tiempo; del 5º compás vuelve el bombo de dos pasos
                if st % 2 == 0: hat()
                if st == 0 or (k >= 5 and st == 10): hit(kick, TN.KICK_DEEP if k <= 4 else TN.KICK, t, 0.95)
                if st == 8: snare(t, 0.8)
                if k == 8 and st >= 8: snare(t, 0.4 + (st - 8) * 0.07, [7 + (st - 8), 5, 2])
            else:
                var = k % 4 == 0                               # cada 4 compases, una variación de "break"
                kicks = (0, 6, 10) if var else (0, 10)
                if kind in FAST: kicks = (0, 3, 6, 10, 13)
                if st in kicks: hit(kick, TN.KICK, t, 1.0)
                if st in (4, 12): snare(t, 1.0)
                elif st in ((7, 9, 14, 15) if var else (7, 15) if k % 2 else (9, 15)): snare(t, 0.3, GHOST)
                hat()
                if last and st >= 12 and kind not in FAST: hit(tom, W.TOMS[min(2, st - 12)], t, 0.8)
            if st == 0 and (k == 1 and kind not in ('IN', 'K') or (kind in THEME + HERO + FAST and k == 5)): NZ['crash'].hit(t, 3, CRASH)
        if kind in BUILD:                                      # ruido que sube durante toda la subida
            n_ = int(BAR * 60 * (0.75 if k == 4 else 1))
            for i_ in range(n_):
                x_ = ((k - 1) + i_ / (BAR * 60)) / 4
                NZ['fx'].hit(tv(b, 0) + i_ / 60.0, int(round(10 - 8 * x_)), [max(1, int(round(11 * x_ ** 1.6)))])

    n = int(NB * BAR * SR)
    n_i = int(INTRO * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k_: cut(F.pulse_dac(F.render_pulse(Cn[k_])))
    wave = lambda k_: cut(F.render_wave(Cn[k_], WAVES) * 0.0075)
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    S = {
        'lead': cut(F.pulse_dac(F.render_saw(Cn['lead']))), 'dbl': pulse('dbl'), 'bell': wave('bell'), 'choir': wave('p1') + wave('p2'),
        'stabs': pulse('c1') + pulse('c2'), 'arp': pulse('arp'),
        'bass': cut(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)), 'reese': cut(F.pulse_dac(F.render_saw(Cn['reese']))),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + cut(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
        'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12)),
        'crash': cut(F.tnd_dac(NZ['crash'].render() / 22638.0 * 12)) + cut(F.tnd_dac(NZ['fx'].render() / 22638.0 * 12)),
    }
    # (SIN doblar la cola: la subida es el mismo compás al final de la intro y del bucle, y acaba en silencio)
    S = {k_: v[:n].copy() for k_, v in S.items()}
    S['bell'] = GN.delay(S['bell'], 3 * S16, 0.3, 2, 3000)[:len(S['bell'])]
    # niveles respecto a la voz: aquí mandan la batería y el bajo (DnB)
    LV = {'lead': 0, 'dbl': -8, 'bell': -3, 'choir': -6, 'stabs': -6, 'arp': -9, 'bass': 4, 'reese': -3,
          'kick': 4, 'toms': 0, 'snare': 3, 'hat': -5, 'crash': -5}
    g = GN.level(S, LV, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k_] * g[k_] for k_ in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    side = S['arp'] * g['arp'] * 0.6 + S['choir'] * g['choir'] * 0.4 + S['hat'] * g['hat'] * 0.35 - S['stabs'] * g['stabs'] * 0.3 + S['bell'] * g['bell'] * 0.3
    DYN = {'IN': (-5.0, -3.5), 'U1': (-3.0, 1.0), 'U2': (-3.0, 1.0), 'A': (0, 0), 'A2': (0.5, 0.5), 'B': (0.3, 0.8), 'B2': (1.2, 1.5),
           'K': (-6.0, -2.5), 'G': (1.5, 2.2), 'A3': (2.0, 2.2)}
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
    mono = y.mean(1)
    def rms(i0, i1): return 20 * np.log10(np.sqrt(np.mean(mono[int((i0 - 1) * BAR * SR):int((i1 - 1) * BAR * SR)] ** 2)) + 1e-9)
    ends = starts[1:] + [NB + 1]
    ref = rms(starts[2], ends[2])
    print('  secciones (dB respecto a A): ' + ' · '.join('%s %+.1f' % (nm, rms(a, e) - ref) for nm, a, e in zip(ORDER, starts, ends)))
    drums = sum(np.mean((S[k_] * g[k_]) ** 2) for k_ in ('kick', 'toms', 'snare', 'hat', 'crash')) / sum(np.mean((S[k_] * g[k_]) ** 2) for k_ in S)
    low = sum(np.mean((S[k_] * g[k_]) ** 2) for k_ in ('bass', 'reese')) / sum(np.mean((S[k_] * g[k_]) ** 2) for k_ in S)
    nb = int(BAR * SR)
    a_, c_ = mono[n_i - nb:n_i], mono[n - nb:n]
    lvl = 10 * np.log10(np.mean(a_ ** 2) / np.mean(c_ ** 2))
    quiet = 10 * np.log10(np.mean(c_[int(nb * 0.8):] ** 2) / np.mean(c_[:nb // 2] ** 2) + 1e-12)
    per_s = len([1 for b, st, nn, d in mel if tag[b - 1] in THEME]) / (24 * BAR)
    print(f'  {BPM} BPM, intro {INTRO} + bucle {NB - INTRO} compases ({(NB - INTRO) * BAR:.1f} s); batería {100 * drums:.0f} % de la energía, bajo {100 * low:.0f} %; '
          f'{per_s:.1f} notas de melodía por segundo en el tema')
    print(f'  subida de la intro frente a la del bucle: nivel {lvl:+.1f} dB · silencio antes del drop: {quiet:.0f} dB respecto al compás')
    bad, out = check(mel, chords, tag)
    print(f'  notas largas fuera del acorde: {bad or "ninguna"} · fuera de la escala: {out or "ninguna"}')
    return y, mel, n_i


if __name__ == '__main__':
    y, mel, n_i = build()
    if not os.environ.get('REPORT'):
        GN.export(NAME, y, n_i)
        W.write_mid(F.out(NAME, 'mid'), mel, BPM)
