#!/usr/bin/env python3
# LA POLILLA — tema de jefe ORIGINAL del SALTARÍN GIGANTE (el jefe de las cuevas, Gruta del Farol;
# docs/bosses/gianthopper.md). Pedido del usuario (2026-10-26): "completamente original pero siguiendo el estilo de la
# música de las cavernas oscuras" (cuevas_oscuras, gloomy_nes.py cueva), "a la altura de un jefe", con el BAJO de
# Resaca (el Slap Bass GM de final_fall.render_bass, que le gusta mucho): su sonido, con un riff PROPIO.
#
# De las cavernas oscuras: Re menor (armónica: Do# en La mayor) y la napolitana Mi♭ como giro oscuro, la CAJA DE MÚSICA
# con eco de cueva, las GOTAS, el colchón N163 que se hincha, el LATIDO de bombo grave (dos golpes) y nada de platos.
# De jefe: 144 BPM (el doble del latido de 72 de la cueva), el bajo slap empujando en semicorcheas, la voz hueca
# (N163 de armónicos impares, como el Crabby lúgubre) con la sierra del VRC6 una octava abajo en el clímax.
# Motivos:
#   · EL GANCHO (2 compases): Re–Fa–La en 3+3+2 hacia la luz, revoloteo (Sol–Fa) y se posa en La; luego baja.
#     Se repite en secuencia por i–VI–iv–V.
#   · EL PARPADEO (su acento, donde la melodía se queda quieta): el farol que tiembla — semicorcheas alternando 5ª y
#     octava del acorde, una fuerte y una floja, en un pulso del 12,5 % arriba.
#   · EL SUSTO (la sección de paradas): golpes de toda la banda y silencio, como el ruido que lo asusta; entre golpe
#     y golpe la caja de música sube por el acorde: ahí está LA LLAMADA (La–Re–Fa–La, 5ª–1ª–3ª–5ª, sobre Rem).
#
# Forma: INTRO 8 (suena una vez) · A 16 (la caja de música) · B 16 (la voz) · SUSTO 8 · SUBIDA 8 · CLÍMAX 16 ·
# VUELTA 8 = 8 + 72 compases (133,3 s; bucle de 120 s, de la VUELTA vuelve a la A).
#
#   python tools/music/polilla.py        → previas en FlappyMonster_pruebas/musica/polilla/
#   INSTALL=1 …                          → assets/music/bosses/polilla_intro.ogg + _loop.ogg + tools/music/mid/polilla.mid
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_saw, q_n163, q_tri
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W
import final_fall as FF

BPM = 144
S16 = 60.0 / BPM / 4
BAR = 16 * S16
NAME = 'polilla'
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/musica/polilla'
N = {'C': 0, 'C#': 1, 'D': 2, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'A': 9, 'Bb': 10, 'B': 11}
MAJ, MIN = (0, 4, 7), (0, 3, 7)
SCALE = {2, 4, 5, 7, 9, 10, 1}                      # Re menor armónica (el Mi♭ solo dentro de su acorde)


def ch(s):
    return (N[s[:-1]], MIN) if s.endswith('m') else (N[s], MAJ)


ROOT = {'D': 38, 'Bb': 34, 'G': 31, 'A': 33, 'Eb': 39}    # raíces del bajo (Re2, Si♭1, Sol1, La1, Mi♭2)

# ══ ARMONÍA ══════════════════════════════════════════════════════════════════════════════════════════════════════
H_A = ['Dm', 'Dm', 'Bb', 'Bb', 'Gm', 'Gm', 'A', 'A']
H_A2 = ['Dm', 'Dm', 'Bb', 'Bb', 'Eb', 'Eb', 'A', 'A']                  # (Mi♭: la napolitana, el giro oscuro)
H_B = ['Gm', 'Gm', 'Dm', 'Dm', 'Eb', 'Eb', 'A', 'A']
H_B2 = ['Gm', 'Gm', 'Dm', 'Dm', 'Bb', 'Eb', 'A', 'A']
H_S = ['Dm', 'Bb', 'Gm', 'A', 'Dm', 'Bb', 'Eb', 'A']

# ══ LA MELODÍA ═══════════════════════════════════════════════════════════════════════════════════════════════════
M_A = ["0:D5/3 3:F5/3 6:A5/2 8:G5/2 10:F5/2 12:A5/4",                    # el gancho: hacia la luz y se posa
       "0:D6/2 2:C#6/2 4:A5/4 8:F5/2 10:E5/2 12:D5/4",                    # … y baja
       "0:D5/3 3:F5/3 6:Bb5/2 8:A5/2 10:G5/2 12:Bb5/4",                   # (en secuencia: Si♭)
       "0:F6/2 2:D6/2 4:Bb5/4 8:G5/2 10:F5/2 12:D5/4",
       "0:D5/3 3:G5/3 6:Bb5/2 8:A5/2 10:G5/2 12:D6/4",                    # (Solm)
       "0:Bb5/2 2:A5/2 4:G5/4 8:F5/2 10:E5/2 12:D5/4",
       "0:C#5/3 3:E5/3 6:A5/2 8:G5/2 10:E5/2 12:C#6/4",                   # (La: la dominante)
       "0:E6/4 4:C#6/4 8:A5/8"]                                           # (nota tenida: parpadea el farol)
M_A2 = ["0:D5/3 3:F5/3 6:A5/2 8:G5/2 10:F5/2 12:A5/4",
        "0:D6/2 2:E6/2 4:F6/4 8:E6/2 10:D6/2 12:A5/4",                    # (la respuesta sube)
        "0:F5/3 3:Bb5/3 6:D6/2 8:Bb5/2 10:A5/2 12:F5/4",
        "0:G5/2 2:F5/2 4:D5/4 8:F5/2 10:G5/2 12:Bb5/4",
        "0:Eb5/3 3:G5/3 6:Bb5/2 8:G5/2 10:F5/2 12:Eb5/4",                 # (la napolitana)
        "0:Bb5/2 2:G5/2 4:Eb6/4 8:D6/2 10:Bb5/2 12:G5/4",
        "0:E5/3 3:A5/3 6:C#6/2 8:E6/2 10:D6/2 12:C#6/4",
        "0:A5/4 4:E5/4 8:C#5/8"]                                          # (se queda en la sensible)
# B: la VOZ. El gancho al revés (baja en 3+3+2 y vuelve a subir), un registro más arriba en la 2ª mitad
M_B = ["0:D6/3 3:Bb5/3 6:G5/2 8:A5/2 10:Bb5/2 12:D6/4",
       "0:G6/4 4:F6/2 6:D6/2 8:Bb5/4 12:G5/4",
       "0:A5/3 3:F5/3 6:D5/2 8:E5/2 10:F5/2 12:A5/4",
       "0:D6/4 4:C#6/2 6:A5/2 8:F5/4 12:D5/4",
       "0:G5/3 3:Eb5/3 6:Bb4/2 8:Eb5/2 10:G5/2 12:Bb5/4",
       "0:Eb6/4 4:D6/2 6:Bb5/2 8:G5/4 12:Eb5/4",
       "0:E5/3 3:C#5/3 6:A4/2 8:C#5/2 10:E5/2 12:A5/4",
       "0:C#6/4 4:D6/2 6:E6/2 8:E6/8"]
M_B2 = ["0:G5/3 3:Bb5/3 6:D6/2 8:F6/2 10:D6/2 12:G6/4",
        "0:Bb6/4 4:A6/2 6:G6/2 8:D6/4 12:Bb5/4",
        "0:A5/3 3:D6/3 6:F6/2 8:E6/2 10:D6/2 12:A6/4",
        "0:F6/4 4:E6/2 6:D6/2 8:A5/8",
        "0:Bb5/3 3:D6/3 6:F6/2 8:D6/2 10:Bb5/2 12:F5/4",
        "0:G5/3 3:Bb5/3 6:Eb6/2 8:D6/2 10:Bb5/2 12:G5/4",
        "0:A5/2 2:C#6/2 4:E6/2 6:A6/2 8:G6/2 10:E6/2 12:C#6/4",
        "0:E6/4 4:C#6/4 8:A5/4 12:E5/4"]
# SUSTO: golpes y silencio; entre golpes, la caja de música sube por el acorde (la LLAMADA en el primero)
M_R = ["4:A4/2 6:D5/2 8:F5/2 10:A5/6", "8:F5/2 10:E5/2 12:D5/4",
       "4:F4/2 6:Bb4/2 8:D5/2 10:F5/6", "8:F5/2 10:D5/2 12:Bb4/4",
       "4:Bb4/2 6:Eb5/2 8:G5/2 10:Bb5/6", "8:Bb5/2 10:G5/2 12:Eb5/4",
       "4:A4/2 6:C#5/2 8:E5/2 10:A5/6", "0:C#6/8"]                         # (medio compás vacío antes de la subida)
# SUBIDA: el grito en notas repetidas, cada vez más arriba
M_S = ["0:D5/2 3:D5/2 6:D5/2 8:F5/2 11:F5/2 14:A5/2",
       "0:D5/2 3:D5/2 6:D5/2 8:F5/2 11:F5/2 14:Bb5/2",
       "0:D5/2 3:D5/2 6:G5/2 8:Bb5/2 11:Bb5/2 14:D6/2",
       "0:C#6/2 3:C#6/2 6:E6/2 8:C#6/4 12:A5/4",
       "0:F5/2 3:F5/2 6:A5/2 8:D6/2 11:D6/2 14:F6/2",
       "0:F6/4 4:D6/2 6:Bb5/2 8:F5/2 10:Bb5/2 12:D6/4",
       "0:Eb6/3 3:Bb5/3 6:G5/2 8:Bb5/2 10:Eb6/2 12:G6/4",
       "0:E6/2 2:C#6/2 4:A5/2 6:C#6/2 8:E6/2 10:G6/2 12:A6/4"]
# CLÍMAX: el gancho una octava arriba por toda la progresión, con su propia línea (no es la A)
M_C = ["0:A5/3 3:D6/3 6:F6/2 8:E6/2 10:D6/2 12:F6/4",
       "0:A6/2 2:G6/2 4:F6/4 8:D6/2 10:C#6/2 12:D6/4",
       "0:Bb5/3 3:D6/3 6:F6/2 8:G6/2 10:F6/2 12:D6/4",
       "0:F6/2 2:G6/2 4:F6/4 8:D6/2 10:Bb5/2 12:F6/4",
       "0:G6/3 3:D6/3 6:Bb5/2 8:A5/2 10:Bb5/2 12:D6/4",
       "0:G6/2 2:A6/2 4:Bb6/4 8:A6/2 10:G6/2 12:D6/4",
       "0:C#6/3 3:E6/3 6:A6/2 8:G6/2 10:E6/2 12:C#6/4",
       "0:E6/4 4:A6/4 8:E6/8",
       "0:D6/3 3:F6/3 6:A6/2 8:G6/2 10:F6/2 12:A6/4",
       "0:A6/2 2:F6/2 4:D6/4 8:E6/2 10:F6/2 12:A6/4",
       "0:Bb6/3 3:F6/3 6:D6/2 8:F6/2 10:Bb6/2 12:F6/4",
       "0:D6/4 4:F6/4 8:Bb6/4 12:F6/4",
       "0:G6/3 3:Eb6/3 6:Bb5/2 8:Eb6/2 10:G6/2 12:Bb6/4",
       "0:G6/4 4:Eb6/4 8:Bb5/4 12:G5/4",
       "0:A5/3 3:C#6/3 6:E6/2 8:A6/2 10:G6/2 12:E6/4",
       "0:C#6/4 4:A5/4 8:E5/4 12:C#5/4"]
# VUELTA: la caja de música adelanta la cabeza del gancho; el bajo sigue (la costura vuelve a la A)
M_O = ["0:D5/3 3:F5/3 6:A5/2", "", "0:D5/3 3:F5/3 6:Bb5/2", "",
       "0:D5/3 3:G5/3 6:Bb5/2", "", "0:C#5/3 3:E5/3 6:A5/2 8:C#6/8", ""]
M_I = ["", "", "", "", "", "", "0:C#5/3 3:E5/3 6:A5/2 8:C#6/8", ""]

# (sección, melodía, armonía, bajo, papel)
SECTIONS = [
    ('I', M_I, H_A, 'intro', 'intro'),
    ('A', M_A + M_A2, H_A + H_A2, 'riff', 'A'),
    ('B', M_B + M_B2, H_B + H_B2, 'gallop', 'B'),
    ('R', M_R, H_A2, 'stop', 'scare'),
    ('S', M_S, H_S, 'eighths', 'build'),
    ('C', M_C, H_A + H_A2, 'riff+', 'climax'),
    ('O', M_O, H_A, 'riff', 'out'),
]
INTRO = 8
VOICE = {'B', 'build', 'climax'}                    # papeles en los que canta la voz (si no, la caja de música)

# ══ EL BAJO (el slap de Resaca, con un riff propio: solo raíz, 5ª y octava) ═════════════════════════════════════
RIFF1 = [(0, 0, 3), (3, 0, 1), (4, 12, 2), (6, 0, 2), (8, 0, 1), (9, 7, 2), (11, 12, 1), (12, 0, 2), (14, 7, 1), (15, 12, 1)]
RIFF2 = [(0, 0, 3), (3, 0, 1), (4, 12, 2), (6, 0, 2), (8, 7, 2), (10, 12, 2), (12, 7, 1), (13, 0, 1), (14, 12, 1), (15, 0, 1)]
RIFF2P = [(0, 0, 2), (2, 12, 1), (3, 0, 1), (4, 12, 2), (6, 0, 2), (8, 7, 2), (10, 12, 1), (11, 0, 1), (12, 12, 1), (13, 0, 1), (14, 12, 1), (15, 7, 1)]
GALLOP = [(0, 0, 2), (3, 0, 1), (4, 0, 2), (6, 12, 1), (7, 0, 1), (8, 0, 2), (11, 0, 1), (12, 12, 2), (14, 7, 2)]


def bass_for(base, harm, kind):
    out = []
    for i, c in enumerate(harm):
        b, r = base + i + 1, ROOT[c.rstrip('m')]
        if kind == 'intro':
            if i >= 4: out += [(b, st, r + iv, d, 70 + 6 * (i - 4)) for st, iv, d in (RIFF1 if i % 2 == 0 else RIFF2)]
        elif kind in ('riff', 'riff+'):
            pat = RIFF1 if i % 2 == 0 else (RIFF2P if kind == 'riff+' else RIFF2)
            out += [(b, st, r + iv, d) for st, iv, d in pat]
        elif kind == 'gallop':
            out += [(b, st, r + iv, d) for st, iv, d in GALLOP]
        elif kind == 'stop':                                               # el susto: un golpe y silencio
            if i % 2 == 0: out += [(b, 0, r, 5, 115), (b, 6, r + 12, 1, 90)]
            elif i == 7: out += [(b, 8, r, 2), (b, 10, r + 7, 2), (b, 12, r + 12, 2), (b, 14, r + 7, 2)]
        elif kind == 'eighths':                                            # la subida: corcheas con octavas
            out += [(b, st, r + (12 if st % 4 == 2 else 0), 2, 90 + 3 * i) for st in range(0, 16, 2)]
    return out


def song():
    mel, chords, role, sec, bass, starts = [], [], [], [], [], {}
    for name, bars, harm, bk, rl in SECTIONS:
        base = len(chords)
        starts[name] = base + 1
        mel.extend((base + b, st, n, d) for b, st, n, d in W.PH(*bars))
        chords += [ch(c) for c in harm]
        role += [rl] * len(harm); sec += [name] * len(harm)
        bass += bass_for(base, harm, bk)
    return sorted(mel), chords, role, sec, bass, starts


def check(mel, chords):
    tones = lambda b: {(chords[b - 1][0] + i) % 12 for i in chords[b - 1][1]}
    bad = [(b, st) for b, st, n, d in mel if d >= 4 and n % 12 not in tones(b)]
    out = [(b, st) for b, st, n, d in mel if n % 12 not in SCALE and n % 12 not in tones(b)]
    return bad, out


def bass_vs_harmony(bass, chords):
    return sum((x[2] - chords[x[0] - 1][0]) % 12 not in (0, 7) for x in bass), len(bass)


# ── INSTRUMENTOS ─────────────────────────────────────────────────────────────────────────────────────────────────
WAVES = [GN.CWAVES[0], GN.WAVES[0], GN.CWAVES[1]]                   # 0 caja de música · 1 voz hueca · 2 colchón
I_BOX = dict(GN.I_BELL, duty=0.0)
I_VOICE = dict(GN.I_SING, duty=1.0)
I_SAWL = {'vol': [13, 12, 12, 11, 11, 10], 'sus': 10, 'vib': (14, 0.2, 6)}
I_DBL = {'vol': [8, 7, 6, 6, 5, 5], 'sus': 5, 'duty': [0.125, 0.25]}
I_ECHO = GN.I_ECHO
I_PAD = dict(GN.I_PADC, duty=2.0)
I_FLICK = {'vol': [9, 6, 3, 1], 'sus': 0, 'duty': 0.125}
I_STAB = {'vol': [12, 9, 6, 3, 1], 'sus': 0, 'duty': 0.25}
I_SHIM = {'vol': [6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_DRIP = GN.I_DRIP
I_TRI = GN.I_TRI
METAL = [5, 2, 1]
SNARE_N = [14, 10, 6, 3, 1]
LV = {'box': 0, 'voice': 0, 'saw': -7, 'dbl': -9, 'echo': -12, 'boxecho': -10, 'flick': -13, 'pad': -11, 'stabs': -9,
      'shim': -15, 'drip': -13, 'tri': -6, 'bass': 1, 'kick': -1, 'snare': -3, 'metal': -15, 'toms': -3, 'nrise': -13}
BACKING_UP = 6.0                   # (el acompañamiento, +6 dB respecto a la melodía: regla BACKING de la casa)
LUFS = -11.0


def build():
    rng = np.random.default_rng(11)
    mel, chords, role, sec, bass, starts = song()
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    keys = ('box', 'boxup', 'voice', 'saw', 'dbl', 'echo', 'flick', 'pad1', 'pad2', 'c1', 'c2', 'shim', 'drip', 'tri')
    Cn = {k: Chan(NF) for k in keys}
    NZ = {k: Noise(NF) for k in ('metal', 'snare', 'nrise')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16
    rl = lambda b: role[b - 1]
    pos = lambda b: b - starts[sec[b - 1]] + 1
    LEN = {name: len(h) for name, _, h, _, _ in SECTIONS}

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # ── MELODÍA ──
    busy = set()
    for b, st, n, d in mel:
        r_, t0 = rl(b), tv(b, st)
        for k in range(st, min(16, st + d)): busy.add((b, k))
        if r_ in VOICE:
            play(Cn['voice'], t0, t0 + d * S16 * 0.94, n, I_VOICE, q=q_n163, release=3)
            if d >= 3: play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 3) * S16 * 0.8, n, I_ECHO, release=1)
            if r_ == 'climax':
                play(Cn['saw'], t0, t0 + d * S16 * 0.93, n - 12, I_SAWL, q=q_saw, release=3)
                play(Cn['boxup'], t0, t0 + S16 * 5, n + 12, I_BOX, q=q_n163, vs=0.6, release=6)
            elif r_ == 'B' and pos(b) > 8:
                play(Cn['dbl'], t0, t0 + d * S16 * 0.9, n + 12, I_DBL, vs=0.8, release=2)
        else:
            play(Cn['box'], t0, t0 + max(d, 4) * S16 * 1.2, n, I_BOX, q=q_n163, release=6)
            if r_ == 'A' and pos(b) > 8: play(Cn['dbl'], t0, t0 + d * S16 * 0.9, n, I_DBL, release=2)

    # ── EL PARPADEO (acento): donde la melodía calla o se queda tenida, el farol tiembla ──
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        if r_ == 'scare': continue
        r, q = chords[b - 1]
        hi = 81 + (r - 81) % 12
        spans = [(st0, d) for bb, st0, n, d in mel if bb == b and d >= 8]
        if not any(x for x in mel if x[0] == b) and r_ in ('intro', 'out') and k % 2 == 0:
            spans = [(0, 16)]
        for st0, d in spans:
            for st in range(st0 + 2, min(16, st0 + d)):
                note = hi + (q[2] if st % 2 == 0 else 12)
                play(Cn['flick'], tv(b, st), tv(b, st) + S16 * 0.6, note, I_FLICK, vs=1.0 if st % 2 == 0 else 0.45, release=0)

    # ── ACOMPAÑAMIENTO ──
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        r, q = chords[b - 1]
        t0 = tv(b, 0)
        if r_ in ('intro', 'A', 'scare', 'out', 'B'):                       # colchón que se hincha (el de la cueva)
            base = 57 + (r - 57) % 12
            vs = 0.6 if r_ == 'B' else 1.0
            for j, iv in enumerate(q[1:]):
                play(Cn[('pad1', 'pad2')[j]], t0, t0 + BAR * 0.97, base + iv, I_PAD, q=q_n163, vs=vs, release=8)
        if r_ in ('intro', 'scare'):                                         # el bordón de triángulo
            play(Cn['tri'], t0, t0 + BAR * 0.97, 38 + (r - 38) % 12, I_TRI, q=q_tri, release=0)
        if r_ in ('B', 'build', 'climax'):                                   # golpes del acorde a contratiempo
            for st in (2, 6, 10, 14):
                if r_ == 'build' and k <= 2 and st in (2, 10): continue
                base = 62 + (r - 62) % 12
                play(Cn['c1'], tv(b, st), tv(b, st) + 1.5 * S16, base + q[1], I_STAB, release=1)
                play(Cn['c2'], tv(b, st), tv(b, st) + 1.5 * S16, base + q[2], I_STAB, release=1)
        if r_ == 'scare' and k % 2 == 1:                                     # el golpe del susto
            base = 62 + (r - 62) % 12
            play(Cn['c1'], t0, t0 + 3 * S16, base + q[1], I_STAB, release=3)
            play(Cn['c2'], t0, t0 + 3 * S16, base + q[2], I_STAB, release=3)
        if r_ == 'climax' and k > 8:                                         # arpegio de brillo, por encima
            for st in range(16):
                play(Cn['shim'], tv(b, st), tv(b, st) + S16 * 0.7, 86 + (r - 86) % 12 + (q + (12,))[st % 4], I_SHIM, release=0)
        if r_ in ('intro', 'A', 'scare', 'out'):                             # gotas: del acorde, donde no toca nadie
            for _ in range(int(rng.integers(0, 3 if r_ != 'A' else 2))):
                st = int(rng.integers(0, 16))
                if (b, st) in busy: continue
                note = 84 + (r - 84) % 12 + [0, q[1], q[2], 12][int(rng.integers(0, 4))]
                play(Cn['drip'], tv(b, st), tv(b, st) + 0.07, note, I_DRIP, release=0)

    # ── BATERÍA (de cueva: bombo hondo, sin platos; "metal" = ruido en modo corto) ──
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        last = k == LEN[sec[b - 1]]
        nxt = role[b] if b < NB else 'A'
        for st in range(16):
            t = tv(b, st)
            if r_ == 'intro':
                if st in (0, 3) and (k > 4 or k % 2 == 1): hit(kick, TN.KICK_DEEP, t, 0.8 if st == 0 else 0.55)   # el latido
                if k > 4 and st == 8: snare(t, 0.5, [8, 4, 2])
                if k > 4 and st % 2 == 1: NZ['metal'].hit(t, 1, [3, 1])
                if k == 8 and st >= 8: snare(t, 0.3 + (st - 8) * 0.08, [6 + (st - 8), 4, 2])
                continue
            if r_ == 'scare':
                if k % 2 == 1 and st == 0: hit(kick, TN.KICK_DEEP, t, 1.0); snare(t, 0.9); hit(tom, W.TOM_LOW, t, 0.8)
                if k % 2 == 1 and st == 6: hit(kick, TN.KICK_DEEP, t, 0.5)
                if k == 8 and st >= 8: hit(tom, W.TOMS[2 - (st - 8) // 3 % 3], t, 0.4 + 0.06 * (st - 8))
                continue
            if r_ == 'build':
                if st % 4 == 0: hit(kick, TN.KICK_DEEP, t, 1.0)
                step = 4 if k <= 3 else (2 if k <= 6 else 1)
                if st % step == 0: snare(t, 0.3 + 0.06 * k + 0.015 * st, [6 + k // 2 + st // 5, 4, 2])
                if k == 8 and st >= 8: hit(tom, W.TOMS[(st - 8) // 3 % 3], t, 0.7)
                if st % 2 == 1: NZ['metal'].hit(t, 1, METAL)
                continue
            if r_ in ('A', 'out'):                                           # medio tiempo: latido + caja en el 3
                if st in (0, 3) or (st == 10 and r_ == 'A'): hit(kick, TN.KICK_DEEP, t, 1.0 if st == 0 else 0.7)
                if st == 8: snare(t, 0.9 if r_ == 'A' else 0.6)
                if st == 15 and r_ == 'A' and k % 2 == 0: snare(t, 0.25, [6, 3, 1])
                if st % 2 == 1: NZ['metal'].hit(t, 1, METAL if r_ == 'A' else [3, 1])
            elif r_ == 'B':                                                  # la voz: el tresillo en el bombo
                if st in (0, 3, 6, 10): hit(kick, TN.KICK_DEEP, t, 1.0 if st in (0, 6) else 0.75)
                if st in (8,): snare(t, 1.0)
                if st == 4 and k > 8: snare(t, 0.7)
                if st == 15: snare(t, 0.3, [6, 3, 1])
                if st % 2 == 1 or (k > 8): NZ['metal'].hit(t, 1, METAL)
                if st == 14 and k % 2 == 0: hit(tom, W.TOMS[1], t, 0.6)
            elif r_ == 'climax':                                             # a tiempo entero: caja en 2 y 4
                if st in (0, 3, 6, 10) or (st == 14 and k % 2 == 0): hit(kick, TN.KICK_DEEP, t, 1.0)
                if st in (4, 12): snare(t, 1.0)
                elif st in (7, 15): snare(t, 0.3, [6, 3, 1])
                NZ['metal'].hit(t, 1, METAL if st % 2 == 1 else [4, 2, 1])
                if st == 0 and k % 2 == 1: hit(tom, W.TOM_LOW, t, 0.9)          # (en lugar de plato: el tambor hondo)
                if st in (3, 13) and b % 2 == 0: hit(tom, W.TOMS[{3: 2, 13: 0}[st]], t, 0.7)
            if last and st >= 12 and nxt not in ('scare',):                      # redoble hacia la siguiente
                hit(tom, W.TOMS[min(2, st - 12)], t, 0.6)
                if st >= 14: snare(t, 0.45 + (st - 14) * 0.15, [8 + (st - 14), 5, 2])
            if st == 0 and k == 1 and r_ in ('A', 'B', 'climax'): hit(tom, W.TOM_LOW, t, 1.0)
        if r_ == 'build' and k == 7:                                         # soplido de ruido hacia el clímax
            nf = int(2 * BAR * F.FPS)
            NZ['nrise'].hit(tv(b, 0), [int(12 - 9 * i / nf) for i in range(nf)], [int(1 + 9 * i / nf) for i in range(nf)])

    # ── STEMS ──
    n = int(NB * BAR * SR)
    at = int(INTRO * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k: cut(F.pulse_dac(F.render_pulse(Cn[k])))
    wave = lambda k: cut(F.render_wave(Cn[k], WAVES) * 0.0075)
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    noise = lambda k: cut(F.tnd_dac(NZ[k].render() / 22638.0 * 12))
    box = wave('box')
    S = {
        'box': box, 'boxecho': GN.delay(box + wave('boxup'), 3 * S16, 0.5, 4, 2600) - box - wave('boxup'),
        'voice': wave('voice') + wave('boxup'), 'saw': cut(F.pulse_dac(F.render_saw(Cn['saw']))),
        'dbl': pulse('dbl'), 'echo': pulse('echo'), 'flick': GN.delay(pulse('flick'), 2 * S16, 0.35, 2, 2500),
        'pad': wave('pad1') + wave('pad2'), 'stabs': pulse('c1') + pulse('c2'), 'shim': pulse('shim'),
        'drip': GN.delay(pulse('drip'), 0.31, 0.4, 3, 3000), 'tri': cut(F.tnd_dac(F.render_tri(Cn['tri']) / 8227.0)),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + noise('snare'),
        'metal': noise('metal'), 'nrise': noise('nrise'),
    }
    FF.BPM = BPM                                                              # (render_bass toma el tempo de ahí)
    yb = FF.render_bass(bass)
    S['bass'] = np.zeros(n + tail); S['bass'][:min(len(yb), n + tail)] = yb[:n + tail]
    S = {k: GN.fold(x, n, at) for k, x in S.items() if np.abs(x).max() > 0}
    LEADS = ('box', 'voice', 'saw', 'dbl', 'echo', 'boxecho')
    g = GN.level(S, {k: LV.get(k, -10) + (BACKING_UP if k not in LEADS else 0) for k in S}, 'box')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('boxecho', 0.5) - sd('echo', 0.6) + sd('stabs', 0.25) + sd('shim', 0.4) - sd('pad', 0.3) + sd('metal', 0.3) \
        - sd('flick', 0.4) + sd('drip', 0.5) - sd('dbl', 0.3)
    y = F.master(np.stack([x + side, x - side], 1), lufs=LUFS)
    GN.report(NAME, y, S, g, n)
    bad, out = check(mel, chords)
    bh, nbh = bass_vs_harmony(bass, chords)
    iv = np.abs(np.diff([m[2] for m in mel]))
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    bars = [t for _, bs, *_ in SECTIONS for t in bs if t]
    print(f'  {BPM} BPM, {NB} compases ({NB * BAR:.1f} s: intro {INTRO * BAR:.1f} + bucle {(NB - INTRO) * BAR:.1f}); '
          f'melodía {len(mel)} notas, {len(bars)} compases, {len(bars) - len(set(bars))} repetidos tal cual')
    print(f'  batería {grp(("kick", "snare", "metal", "toms", "nrise")):.0f} %, bajo {grp(("bass",)):.0f} %, '
          f'melodía {grp(LEADS):.0f} %')
    print('  secciones: ' + ' · '.join(f'{nm} {(starts[nm] - 1) * BAR // 60:.0f}:{(starts[nm] - 1) * BAR % 60:04.1f}' for nm, *_ in SECTIONS))
    print(f'  notas largas fuera del acorde: {bad or "ninguna"} · fuera de escala y acorde: {out or "ninguna"}')
    print(f'  bajo contra la armonía (ni raíz ni 5ª): {bh} de {nbh} · intervalo medio {iv.mean():.2f} st, '
          f'grados {np.mean(iv <= 2) * 100:.0f} %, saltos de octava {np.mean(iv >= 12) * 100:.0f} %, '
          f'a contratiempo {np.mean([m[1] % 4 != 0 for m in mel]) * 100:.0f} %')
    return y, mel, at


def preview(y, at):
    os.makedirs(PREVIEW, exist_ok=True)
    def enc(x, name):
        wav = os.path.join(PREVIEW, name + '.wav'); ogg = wav[:-4] + '.ogg'
        F.write_wav(wav, x)
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"'); os.remove(wav)
    loop = y[at:]
    enc(np.concatenate([y, loop]), NAME + '_intro_y_dos_vueltas')
    k = int(8 * BAR * SR)
    enc(np.concatenate([loop[-k:], loop[:k]]), NAME + '_costura')
    print(f'  previas en {PREVIEW}')


if __name__ == '__main__':
    y, mel, at = build()
    if not os.environ.get('REPORT'):
        preview(y, at)
        if os.environ.get('INSTALL'):
            GN.export(NAME, y, at)
            W.write_mid(F.out(NAME, 'mid'), mel, BPM)
