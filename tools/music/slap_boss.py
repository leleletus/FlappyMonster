#!/usr/bin/env python3
# EL GROOVE — un tema de jefe cuyo instrumento PRINCIPAL es el slap bass de Resaca (tools/music/slap.py), con
# acompañamiento de Famicom. Nació como maqueta ("quiero oír el tema para inspirarme", 2026-10-26); el usuario: "el mejor
# tema del juego por mucho" → es el tema de EL GROOVE, el Crabby trampolín gigante, jefe secreto (catálogo `groove`).
# OJO: el jefe (types/bosses/groovecrab.lua) SIGUE ESTA PARTITURA por compases (sus SECCIONES, los POPS del bajo y los
# golpes de banda): si cambia la forma, el tempo o dónde caen los golpes, hay que cambiar también su tabla SONG.
#
# Mi menor (el Mi grave es la cuerda al aire del bajo), 150 BPM, funk de jefe:
#   · EL BAJO canta: pulgar (slap) en los graves, POPS a la octava (la nota fuerte), notas fantasma (x) que llenan
#     las semicorcheas. Riff de 4 compases i–i–VI–VII (Mim · Mim · Do · Re) que acaba subiendo en cromático a Mi.
#   · B: el bajo sube de registro y canta en pops por la progresión iv–i–VI–V (Lam · Mim · Do · Si).
#   · SOLO: paradas — la banda da un golpe y calla; el bajo hace licks solo (con la blue note Si♭).
#   · Acompañamiento: batería funk (bombo 1 y "3 y", caja en 2 y 4 con fantasmas), golpes de acorde a contratiempo
#     (VRC6), "rasgueo" en semicorcheas (pulso al 12,5 %), colchón N163, golpes de banda al cerrar frase y un brillo
#     que dobla los pops dos octavas arriba en el clímax.
# Forma: INTRO 8 (el bajo solo 4, luego la banda; suena una vez) · A 16 · B 16 · SOLO 8 · SUBIDA 8 · CLÍMAX 16 ·
# VUELTA 4 = 8 + 68 compases.
#
#   python tools/music/slap_boss.py   → FlappyMonster_pruebas/musica/slap_boss/ (intro + dos vueltas, y la costura)
#   INSTALL=1 …                       → assets/music/bosses/groove_intro.ogg + groove_loop.ogg
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_saw, q_n163
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W
import slap as SL

BPM = 150
S16 = 60.0 / BPM / 4
BAR = 16 * S16
NAME = 'slap_boss'
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/musica/slap_boss'
NN = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'Bb': 10, 'B': 11}
MAJ, MIN = (0, 4, 7), (0, 3, 7)


def ch(s):
    return (NN[s[:-1]], MIN) if s.endswith('m') else (NN[s], MAJ)


def note(s):
    return 12 * (int(s[-1]) + 1) + NN[s[:-1]]


def BL(t):
    """Un compás de bajo: 'st:NOTA/dur' + '!' = pop (fuerte) · 'x' = fantasma (flojo)"""
    out = []
    for tok in t.split():
        st, rest = tok.split(':')
        vel = 122 if rest.endswith('!') else (48 if rest.endswith('x') else 98)
        n, d = rest.rstrip('!x').split('/')
        out.append((int(st), note(n), int(d), vel))
    return out


# ══ EL BAJO ══════════════════════════════════════════════════════════════════════════════════════════════════════
R1 = "0:E2/2 2:E3/1! 3:E2/1x 4:G2/2 6:A2/1 7:E2/1x 8:B2/2 10:D3/1 11:E3/1! 12:D3/2 14:B2/1 15:A2/1"
R2 = "0:G2/2 2:G3/1! 3:E2/1x 4:A2/2 6:B2/2 8:E2/3 11:E3/1! 12:D3/1 13:B2/1 14:G2/2"
R3 = "0:C2/2 2:C3/1! 3:C2/1x 4:E2/2 6:G2/1 7:C2/1x 8:G2/2 10:B2/1 11:C3/1! 12:B2/2 14:G2/1 15:E2/1"
R4 = "0:D2/2 2:D3/1! 3:D2/1x 4:F#2/2 6:A2/2 8:D3/2 10:C3/1 11:D3/1! 12:F#3/1! 13:E3/1 14:D3/1 15:D#3/1"
R1V = "0:E2/2 2:E3/1! 3:E2/1x 4:E2/1x 5:G2/1 6:A2/1 7:Bb2/1 8:B2/2 10:D3/1! 11:E3/1! 12:G3/2! 14:E3/1 15:D3/1"
R7 = "0:C3/2 2:C4/1! 3:C3/1x 4:G3/2 6:E3/2 8:G3/2 10:A3/1 11:B3/1 12:C4/2! 14:B3/1 15:A3/1"
R8 = "0:B2/2 2:B3/1! 3:B2/1x 4:D#3/2 6:F#3/2 8:A3/2 10:F#3/1 11:D#3/1 12:B2/2 14:D#3/1 15:F#3/1"
FILL = "0:D2/2 2:D3/1! 3:D2/1x 4:F#2/2 6:A2/2 8:A2/1 9:B2/1 10:C3/1 11:C#3/1 12:D3/1 13:D#3/1 14:E3/2!"
B1 = "0:A2/2 2:A3/2! 4:C4/3! 7:B3/1 8:A3/2! 10:E3/2 12:G3/2 14:A3/2!"
B2 = "0:A2/1 1:A2/1x 2:E3/2 4:A3/2! 6:B3/2 8:C4/4! 12:B3/2 14:A3/2"
B3 = "0:E2/2 2:E3/2! 4:G3/3! 7:F#3/1 8:E3/2! 10:B2/2 12:D3/2 14:E3/2!"
B4 = "0:E2/1 1:E2/1x 2:B2/2 4:E3/2! 6:F#3/2 8:G3/4! 12:A3/2 14:B3/2"
B5 = "0:C3/2 2:C4/2! 4:E4/3! 7:D4/1 8:C4/2! 10:G3/2 12:A3/2 14:B3/2"
B6 = "0:C2/1 1:C2/1x 2:G2/2 4:C3/2! 6:E3/2 8:G3/2 10:C4/2! 12:B3/2 14:G3/2"
B7 = "0:B2/2 2:B3/2! 4:D#4/3! 7:C#4/1 8:B3/2! 10:F#3/2 12:A3/2 14:B3/2!"
B8 = "0:B1/2 2:B2/1! 3:B1/1x 4:D#2/2 6:F#2/2 8:A2/2 10:B2/2 12:D#3/2 14:F#3/2"
B9 = "0:A2/2 2:A3/2! 4:E4/3! 7:D4/1 8:C4/2! 10:A3/2 12:B3/2 14:C4/2!"
B11 = "0:E2/2 2:E3/2! 4:B3/3! 7:A3/1 8:G3/2! 10:E3/2 12:F#3/2 14:G3/2!"
B16 = "0:B1/2 2:B2/1! 3:B1/1x 4:B2/1 5:B1/1x 6:B2/1! 7:B1/1x 8:B2/1 9:A2/1 10:G2/1 11:F#2/1 12:F#2/1 13:F2/1 14:E2/2"
K1 = R1V
K2 = "0:E2/1 1:E2/1x 2:E3/1! 3:E2/1x 4:E2/1 5:E2/1x 6:E3/1! 7:D3/1 8:B2/1 9:A2/1 10:G2/1 11:E2/1 12:G2/1 13:A2/1 14:B2/2"
K3 = "0:E2/2 2:E3/1! 3:E2/1x 4:E2/1x 5:G2/1 6:A2/1 7:Bb2/1 8:B2/2 10:D3/1! 11:E3/1! 12:A3/2! 14:G3/1 15:E3/1"
K4 = "0:B2/2 2:B3/1! 3:B2/1x 4:A2/2 6:A3/1! 7:A2/1x 8:G2/2 10:G3/1! 11:G2/1x 12:F#2/2 14:F#3/1! 15:F#2/1x"
K8 = "0:E2/1 1:E3/1! 2:E2/1 3:E3/1! 4:E2/1 5:E3/1! 6:E2/1 7:E3/1! 8:G2/1 9:G3/1! 10:A2/1 11:A3/1! 12:B2/1 13:B3/1! 14:D3/1 15:D#3/1"

H4 = ['Em', 'Em', 'C', 'D']
SECTIONS = [   # (nombre, compases de bajo, armonía, papel)
    ('I', [R1, R2, R3, R4, R1, R2, R7, R8], H4 + ['Em', 'Em', 'C', 'B'], 'intro'),
    ('A', [R1, R2, R3, R4, R1, R2, R7, R8, R1, R2, R3, R4, R1V, R2, R3, FILL],
     H4 + ['Em', 'Em', 'C', 'B'] + H4 + H4, 'A'),
    ('B', [B1, B2, B3, B4, B5, B6, B7, B8, B9, B2, B11, B4, B5, B6, B7, B16],
     ['Am', 'Am', 'Em', 'Em', 'C', 'C', 'B', 'B'] * 2, 'B'),
    ('K', [K1, K2, K3, K4, K1, K2, K3, K8], ['Em'] * 3 + ['Em'] + ['Em'] * 4, 'solo'),
    ('S', [R1, R2, R3, R4, R1, R2, R3, R8], H4 + ['Em', 'Em', 'C', 'B'], 'build'),
    ('C', [R1, R2, R7, R8, R1V, R2, R7, R8, B9, B2, B11, B4, B5, B6, B7, B16],
     ['Em', 'Em', 'C', 'B'] * 2 + ['Am', 'Am', 'Em', 'Em', 'C', 'C', 'B', 'B'], 'climax'),
    ('O', [R1, R2, R3, R4], H4, 'out'),
]
INTRO = 8


def song():
    bass, chords, role, sec, starts = [], [], [], [], {}
    for name, bars, harm, rl in SECTIONS:
        base = len(chords)
        starts[name] = base + 1
        for i, t in enumerate(bars):
            bass += [(base + i + 1, st, n, d, v) for st, n, d, v in BL(t)]
        chords += [ch(c) for c in harm]
        role += [rl] * len(harm); sec += [name] * len(harm)
    return bass, chords, role, sec, starts


# ── INSTRUMENTOS ─────────────────────────────────────────────────────────────────────────────────────────────────
WAVES = [wavetable([1.0, 0.3, 0.1])]
I_STAB = {'vol': [12, 9, 5, 2, 1], 'sus': 0, 'duty': 0.25}
I_SCR = {'vol': [5, 2, 1], 'sus': 0, 'duty': 0.125}
I_PAD = {'vol': [2, 3, 4, 5, 5, 5], 'sus': 5, 'vib': (24, 0.12, 4.5), 'duty': 0.0}
I_HIT = {'vol': [15, 13, 11, 9, 7, 5, 3, 1], 'sus': 0, 'vib': (0, 0, 0)}
I_SPARK = {'vol': [8, 5, 3, 1], 'sus': 0, 'duty': 0.125}
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
LV = {'bass': 0, 'kick': -2, 'snare': -3, 'hat': -14, 'ohat': -15, 'crash': -9, 'toms': -4, 'stabs': -9, 'scr': -16,
      'pad': -13, 'hits': -7, 'spark': -15, 'nrise': -13}
LUFS = -9.5                                         # (más fuerte: en su pelea la música manda)


def build():
    bass, chords, role, sec, starts = song()
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('c1', 'c2', 'scr', 'pad1', 'pad2', 'h1', 'h2', 'spark')}
    NZ = {k: Noise(NF) for k in ('hat', 'ohat', 'snare', 'crash', 'nrise')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16
    rl = lambda b: role[b - 1]
    pos = lambda b: b - starts[sec[b - 1]] + 1
    LEN = {name: len(h) for name, _, h, _ in SECTIONS}

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # ── EL BAJO (el slap) ──
    slap = SL.Rec()
    for b, st, n, d, v in bass:
        r_, k = rl(b), pos(b)
        if r_ == 'intro' and k <= 4: v = int(v * 0.9)
        slap.add(tv(b, st), tv(b, st) + d * S16 * 0.95, n, v)
        if r_ == 'climax' and v >= 120:                                       # el brillo: los pops, dos octavas arriba
            play(Cn['spark'], tv(b, st), tv(b, st) + S16 * 0.9, n + 24, I_SPARK, release=1)

    # ── ACOMPAÑAMIENTO ──
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        r, q = chords[b - 1]
        last = k == LEN[sec[b - 1]]
        band = not (r_ == 'intro' and k <= 4)
        if band and r_ != 'solo':                                             # golpes de acorde a contratiempo
            base = 64 + (r - 64) % 12
            for st in (2, 6, 10, 14) if r_ in ('B', 'climax') else (6, 14):
                play(Cn['c1'], tv(b, st), tv(b, st) + 1.2 * S16, base + q[1], I_STAB, release=1)
                play(Cn['c2'], tv(b, st), tv(b, st) + 1.2 * S16, base + q[2], I_STAB, release=1)
        if r_ in ('A', 'climax', 'build'):                                    # el rasgueo en semicorcheas
            hi = 76 + (r - 76) % 12
            for st in range(16):
                play(Cn['scr'], tv(b, st), tv(b, st) + S16 * 0.4, hi + (q[1] if st % 2 else q[2]), I_SCR,
                     vs=1.0 if st % 4 == 2 else 0.5, release=0)
        if r_ in ('B', 'climax'):                                             # colchón
            base = 57 + (r - 57) % 12
            for j, iv in enumerate(q[1:]):
                play(Cn[('pad1', 'pad2')[j]], tv(b, 0), tv(b, 0) + BAR * 0.97, base + iv, I_PAD, q=q_n163, release=6)
        if r_ == 'solo' and k % 2 == 1:                                       # el solo: un golpe de banda y silencio
            base = 64 + (r - 64) % 12
            play(Cn['h1'], tv(b, 0), tv(b, 0) + 3 * S16, base + q[1], I_HIT, q=q_saw, release=3)
            play(Cn['h2'], tv(b, 0), tv(b, 0) + 3 * S16, base + q[2], I_HIT, q=q_saw, release=3)
        if band and r_ in ('A', 'B', 'climax', 'build') and k % 4 == 0:      # golpes de banda al cerrar cada frase
            for st in (12, 14) if k % 8 == 0 else (14,):
                base = 64 + (r - 64) % 12
                play(Cn['h1'], tv(b, st), tv(b, st) + 1.5 * S16, base + q[1], I_HIT, q=q_saw, release=2)
                play(Cn['h2'], tv(b, st), tv(b, st) + 1.5 * S16, base + q[2], I_HIT, q=q_saw, release=2)

    # ── BATERÍA (funk) ──
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        last = k == LEN[sec[b - 1]]
        for st in range(16):
            t = tv(b, st)
            if r_ == 'intro' and k <= 4:                                      # el bajo solo (y los charles al final)
                if k >= 3 and st % 2 == 0: NZ['hat'].hit(t, 1, [4, 2, 1] if st % 4 else [6, 3, 1])
                if k == 4 and st >= 12: snare(t, 0.3 + 0.12 * (st - 12), [7 + (st - 12), 4, 2])
                continue
            if r_ == 'solo':                                                  # paradas: golpe y charles
                if k % 2 == 1 and st == 0: hit(kick, TN.KICK_DEEP, t, 1.0); snare(t, 0.9); NZ['crash'].hit(t, 3, CRASH)
                if st % 2 == 0: NZ['hat'].hit(t, 1, [4, 2, 1])
                if k == 8 and st >= 8: hit(tom, W.TOMS[(st - 8) // 3 % 3], t, 0.6)
                continue
            if r_ == 'build':
                if st % 4 == 0: hit(kick, TN.KICK_DEEP, t, 1.0)
                step = 4 if k <= 3 else (2 if k <= 6 else 1)
                if st % step == 0: snare(t, 0.3 + 0.06 * k + 0.015 * st, [6 + k // 2 + st // 5, 4, 2])
                if st % 2 == 1: NZ['hat'].hit(t, 1, [3, 1])
                continue
            big = r_ == 'climax'
            if st in (0, 10) or (st == 7 and k % 2 == 0) or (big and st == 3 and k % 2 == 1): hit(kick, TN.KICK_DEEP, t, 1.0)
            if st in (4, 12): snare(t, 1.0)
            elif st in (7, 15) or (st == 9 and r_ == 'B'): snare(t, 0.22, [5, 2, 1])               # fantasmas
            if st % 4 == 2: NZ['ohat'].hit(t, 1, [6, 5, 4, 3, 2, 1])
            else: NZ['hat'].hit(t, 1, [5, 2, 1] if st % 2 == 0 else [3, 1])
            if st == 0 and (k == 1 or (big and k % 4 == 1)): NZ['crash'].hit(t, 3, CRASH)
            if last and st >= 12:
                hit(tom, W.TOMS[min(2, st - 12)], t, 0.7)
                if st >= 14: snare(t, 0.5 + (st - 14) * 0.15, [8 + (st - 14), 5, 2])
        if r_ == 'build' and k == 7:
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
    S = {
        'bass': slap.render(n + tail),
        'stabs': pulse('c1') + pulse('c2'), 'scr': pulse('scr'), 'pad': wave('pad1') + wave('pad2'),
        'hits': cut(F.pulse_dac(F.render_saw(Cn['h1']))) + cut(F.pulse_dac(F.render_saw(Cn['h2']))),
        'spark': GN.delay(pulse('spark'), 3 * S16, 0.35, 2, 4000),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + noise('snare'),
        'hat': noise('hat'), 'ohat': noise('ohat'), 'crash': noise('crash'), 'nrise': noise('nrise'),
    }
    S = {k: GN.fold(x, n, at) for k, x in S.items() if np.abs(x).max() > 0}
    g = GN.level(S, {k: LV.get(k, -10) for k in S}, 'bass')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('stabs', 0.35) - sd('scr', 0.5) + sd('pad', 0.3) + sd('ohat', 0.3) - sd('hat', 0.2) + sd('spark', 0.5) - sd('hits', 0.15)
    y = F.master(np.stack([x + side, x - side], 1), lufs=LUFS)
    GN.report(NAME, y, S, g, n)
    bh = sum((nn - chords[b - 1][0]) % 12 in (1, 6) for b, st, nn, d, v in bass if d >= 2)
    print(f'  {BPM} BPM, {NB} compases ({NB * BAR:.1f} s: intro {INTRO * BAR:.1f} + bucle {(NB - INTRO) * BAR:.1f}); '
          f'bajo {len(bass)} notas ({sum(v >= 120 for *_, v in bass)} pops, {sum(v < 60 for *_, v in bass)} fantasma); notas de corchea o más a 2ª menor o tritono del acorde: {bh}')
    print('  secciones: ' + ' · '.join(f'{nm} {(starts[nm] - 1) * BAR // 60:.0f}:{(starts[nm] - 1) * BAR % 60:04.1f}' for nm, *_ in SECTIONS))
    return y, at


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
    y, at = build()
    if not os.environ.get('REPORT'):
        preview(y, at)
        if os.environ.get('INSTALL'):                 # (el tema de EL GROOVE, el jefe secreto: catálogo `groove`)
            GN.export('groove', y, at)
