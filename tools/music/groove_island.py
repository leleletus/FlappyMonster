#!/usr/bin/env python3
# ISLA DEL GROOVE — el tema de NIVEL del islote del Cangrejo Groove (assets/levels/isla_del_groove.json): un REMIX de
# costa_1 "Calipso" (la MISMA melodía y los mismos acordes de worlds_nes.py: K_A, K_B, la vuelta en Re menor y el solo
# del steel drum) arreglado como FUNK, con el SLAP BASS del tema del jefe de protagonista (tools/music/slap.py, como
# slap_boss.py). El usuario (0.5.54): "un remix completamente más animado, con diferentes instrumentos y sobre todo el
# hermoso y rico slap bass que usa el tema del Groove". Catálogo `costa_groove`.
#
# Fa mayor (la de Calipso), 132 BPM (Calipso, 122):
#   · EL BAJO: patrones de funk sobre los acordes — pulgar en el grave, POPS a la octava, notas fantasma (x) y una
#     nota de paso cromática hacia el acorde siguiente al final del compás; en el puente sube y canta en pops; en el
#     SOLO de bajo la banda da un golpe y calla.
#   · La melodía de Calipso en su steel drum (N163); en la vuelta grande, doblada una octava arriba por un pulso.
#   · Acompañamiento: rasgueo de acordes a contratiempo (pulso 25 %), golpes de metales (VRC6) al cerrar frase,
#     colchón N163 en el puente, maraca en semicorcheas (la de la costa) y batería funk.
# Forma: INTRO 4 (el bajo solo 2, luego la banda; suena una vez) · A 8 · A' 8 · B 8 · D 8 (la vuelta de Calipso en Re
# menor) · SOLO DE BAJO 8 · S 8 (el solo del steel drum) · A' grande 8 = 4 + 56 compases.
#
#   python tools/music/groove_island.py   → FlappyMonster_pruebas/musica/groove_island/ (intro + dos vueltas, la costura)
#   INSTALL=1 …                           → assets/music/worlds/costa/costa_groove_intro.ogg + _loop.ogg
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

BPM = 132
S16 = 60.0 / BPM / 4
BAR = 16 * S16
NAME = 'groove_island'
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/musica/groove_island'
MAJ, MIN = (0, 4, 7), (0, 3, 7)

# ══ LA PARTITURA: la de Calipso ══════════════════════════════════════════════════════════════════════════════════
DM, DC = W.DEV['calipso'][0], W.DEV['calipso'][1]           # (la vuelta en Re menor)
SM, SC = W.EXTRA['calipso']['S']                             # (el solo del steel drum)
SOLO_CH = W.CH("Dm Dm Bb C Dm Gm Bb|C C")                     # (el solo de bajo, sobre la vuelta en Re menor)
INTRO = 4
SECTIONS = [   # (nombre, melodía [(compás, st, nota, dur)], acordes por compás, papel)
    ('I', [], [(W.Fr, MAJ)] * INTRO, 'intro'),
    ('A', W.K_A + W.K_END, W.KCH_A, 'A'),
    ('A2', W.K_A + W.K_END2, W.KCH_A, 'A'),
    ('B', W.K_B, W.KCH_B, 'B'),
    ('D', DM, DC, 'D'),
    ('K', [], SOLO_CH, 'solo'),
    ('S', SM, SC, 'S'),
    ('Z', W.K_A + W.K_END2, W.KCH_A, 'big'),
]


def song():
    mel, chords, role, sec, starts = [], [], [], [], {}
    for name, m, ch, rl in SECTIONS:
        base = len(chords)
        starts[name] = base + 1
        mel += [(base + b, st, n, d) for b, st, n, d in m]
        for c in ch:
            chords.append(c if isinstance(c[0], tuple) else (c, c))
        role += [rl] * len(ch); sec += [name] * len(ch)
    return sorted(mel), chords, role, sec, starts


# ══ EL BAJO: patrones de funk por grados ═════════════════════════════════════════════════════════════════════════
# 'R' raíz grave · '3' '5' tercera y quinta · '8' octava · '83' '85' octava + tercera / quinta · 'x' fantasma (la raíz,
# floja) · 'n' nota de paso: un semitono por debajo de la raíz del compás siguiente. '!' = pop (fuerte)
PAT = {
    'groove': "0:R/2 2:8/1! 3:x/1 4:5/2 6:8/1! 7:x/1 8:R/2 10:3/1 11:5/1 12:8/2! 14:5/1 15:n/1",
    'push':   "0:R/1 1:x/1 2:8/1! 3:x/1 4:R/1 5:5/1 6:8/1! 7:x/1 8:3/2 10:5/1 11:8/1! 12:R/2 14:5/1 15:n/1",
    'space':  "0:R/3 3:8/1! 4:x/1 6:5/2 8:R/2 10:8/1! 11:x/1 12:5/2 14:3/1 15:n/1",
    'sing':   "0:R/2 2:8/2! 4:83/3! 7:8/1 8:85/2! 10:83/2 12:8/2 14:5/2",
    'sing2':  "0:R/1 1:x/1 2:5/2 4:8/2! 6:83/2 8:85/4! 12:83/2 14:8/2",
    'hammer': "0:R/1 1:8/1! 2:R/1 3:8/1! 4:R/1 5:8/1! 6:R/1 7:8/1! 8:3/1 9:83/1! 10:5/1 11:85/1! 12:8/1 13:x/1 14:5/1 15:n/1",
    'lick':   "0:R/2 2:8/1! 3:x/1 4:x/1 5:3/1 6:5/1 7:8/1 8:85/2! 10:83/1! 11:8/1 12:5/2 14:3/1 15:n/1",
    'stop':   "0:R/2 2:8/1! 3:x/1 4:5/1 5:8/1 6:83/1! 7:85/1 8:8/1! 9:5/1 10:3/1 11:R/1 12:x/1 13:3/1 14:5/1 15:n/1",
}
HALF = "0:R/2 2:8/1! 3:x/1 4:5/2 6:8/1! 7:n/1"                # (media barra, para los compases de dos acordes)


def root_of(r):
    return 41 + (r - 5) % 12                                   # (Fa1 = 41 … Mi2: el registro del pulgar)


def bass_bar(r, q, pat, next_r):
    out = []
    lo = root_of(r)
    for tok in pat.split():
        st, rest = tok.split(':')
        pop, gh = rest.endswith('!'), False
        g, d = rest.rstrip('!').split('/')
        if g == 'R': n = lo
        elif g == 'x': n, gh = lo, True
        elif g == '3': n = lo + q[1]
        elif g == '5': n = lo + q[2]
        elif g == '8': n = lo + 12
        elif g == '83': n = lo + 12 + q[1]
        elif g == '85': n = lo + 12 + q[2]
        else: n = root_of(next_r) - 1                           # (de paso, cromática)
        out.append((int(st), n, int(d), 122 if pop else (48 if gh else 98)))
    return out


def bassline(chords, role, sec, starts):
    notes = []
    NB = len(chords)
    for b in range(1, NB + 1):
        r_ = role[b - 1]
        k = b - starts[sec[b - 1]] + 1
        (r1, q1), (r2, q2) = chords[b - 1]
        nr = chords[b % NB][0][0]
        if r_ == 'intro': pat = 'space' if k <= 2 else 'groove'
        elif r_ == 'A': pat = ('space', 'groove', 'space', 'push')[(k - 1) % 4]
        elif r_ == 'B': pat = ('sing', 'sing2')[(k - 1) % 2]
        elif r_ == 'D': pat = ('push', 'groove')[(k - 1) % 2]
        elif r_ == 'solo': pat = ('lick', 'hammer', 'lick', 'stop', 'lick', 'hammer', 'stop', 'hammer')[k - 1]
        elif r_ == 'S': pat = 'space'
        else: pat = ('push', 'groove', 'push', 'hammer')[(k - 1) % 4]
        if (r1, q1) != (r2, q2):                               # (dos acordes: media barra cada uno)
            first = bass_bar(r1, q1, HALF, r2)
            second = [(st + 8, n, d, v) for st, n, d, v in bass_bar(r2, q2, HALF, nr)]
            notes += [(b,) + x for x in first + second]
        else:
            notes += [(b,) + x for x in bass_bar(r1, q1, PAT[pat], nr)]
    return notes


# ── INSTRUMENTOS ─────────────────────────────────────────────────────────────────────────────────────────────────
WAVES = [wavetable([1.0, 0.3, 0.1]), wavetable([1.0, 0.7, 0.35, 0.45, 0.1, 0.2])]      # 0 colchón · 1 steel drum
I_STEEL = dict(W.I_STEEL, duty=1.0)                                                 # (duty = la onda N163)
I_DBL = {'vol': [8, 7, 6, 6, 5, 5], 'sus': 5, 'duty': 0.25}                          # dobla la melodía arriba
I_STAB = {'vol': [12, 9, 5, 2, 1], 'sus': 0, 'duty': 0.25}
I_PAD = {'vol': [2, 3, 4, 5, 5, 5], 'sus': 5, 'vib': (24, 0.12, 4.5), 'duty': 0.0}
I_HIT = {'vol': [15, 13, 11, 9, 7, 5, 3, 1], 'sus': 0, 'vib': (0, 0, 0)}
I_SPARK = {'vol': [8, 5, 3, 1], 'sus': 0, 'duty': 0.125}
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
LV = {'bass': 0, 'lead': -3.5, 'dbl': -10, 'kick': -3, 'snare': -4, 'hat': -15, 'ohat': -16, 'shaker': -17, 'crash': -10,
      'toms': -5, 'stabs': -10, 'pad': -14, 'hits': -8, 'spark': -16}
LUFS = -11.5


def build():
    mel, chords, role, sec, starts = song()
    bass = bassline(chords, role, sec, starts)
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'dbl', 'c1', 'c2', 'pad1', 'pad2', 'h1', 'h2', 'spark')}
    NZ = {k: Noise(NF) for k in ('hat', 'ohat', 'snare', 'crash', 'shaker')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16
    rl = lambda b: role[b - 1]
    pos = lambda b: b - starts[sec[b - 1]] + 1
    LEN = {name: len(ch) for name, _, ch, _ in SECTIONS}
    chord_at = lambda b, st: chords[b - 1][0 if st < 8 else 1]

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # ── EL BAJO (el slap) ──
    slap = SL.Rec()
    for b, st, n, d, v in bass:
        if rl(b) == 'intro' and pos(b) <= 2: v = int(v * 0.9)
        slap.add(tv(b, st), tv(b, st) + d * S16 * 0.95, n, v)
        if rl(b) == 'big' and v >= 120:                                       # el brillo: los pops, dos octavas arriba
            play(Cn['spark'], tv(b, st), tv(b, st) + S16 * 0.9, n + 24, I_SPARK, release=1)

    # ── LA MELODÍA (steel drum; en la vuelta grande, doblada arriba) ──
    for b, st, n, d in mel:
        t0, t1 = tv(b, st), tv(b, st) + d * S16 * 0.92
        play(Cn['lead'], t0, t1, n, I_STEEL, q=q_n163, release=4)
        if rl(b) == 'big':
            play(Cn['dbl'], t0, t1, n + 12, I_DBL, release=2)

    # ── ACOMPAÑAMIENTO ──
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        band = not (r_ == 'intro' and k <= 2)
        if band and r_ != 'solo':                                             # el rasgueo a contratiempo
            for st in (2, 6, 10, 14) if r_ in ('B', 'big', 'D') else (6, 10, 14):
                r, q = chord_at(b, st)
                base = 64 + (r - 64) % 12
                play(Cn['c1'], tv(b, st), tv(b, st) + 1.2 * S16, base + q[1], I_STAB, release=1)
                play(Cn['c2'], tv(b, st), tv(b, st) + 1.2 * S16, base + q[2], I_STAB, release=1)
        if r_ in ('B', 'D'):                                                  # colchón
            r, q = chord_at(b, 0)
            base = 57 + (r - 57) % 12
            for j, iv in enumerate(q[1:]):
                play(Cn[('pad1', 'pad2')[j]], tv(b, 0), tv(b, 0) + BAR * 0.97, base + iv, I_PAD, q=q_n163, release=6)
        if r_ == 'solo' and k % 2 == 1:                                       # el solo de bajo: golpe de banda y silencio
            r, q = chord_at(b, 0)
            base = 64 + (r - 64) % 12
            play(Cn['h1'], tv(b, 0), tv(b, 0) + 3 * S16, base + q[1], I_HIT, q=q_saw, release=3)
            play(Cn['h2'], tv(b, 0), tv(b, 0) + 3 * S16, base + q[2], I_HIT, q=q_saw, release=3)
        if band and r_ not in ('intro', 'solo') and k % 4 == 0:              # metales al cerrar cada frase
            for st in (12, 14) if k % 8 == 0 else (14,):
                r, q = chord_at(b, st)
                base = 64 + (r - 64) % 12
                play(Cn['h1'], tv(b, st), tv(b, st) + 1.5 * S16, base + q[1], I_HIT, q=q_saw, release=2)
                play(Cn['h2'], tv(b, st), tv(b, st) + 1.5 * S16, base + q[2], I_HIT, q=q_saw, release=2)

    # ── BATERÍA (funk) y la maraca de la costa ──
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        last = k == LEN[sec[b - 1]]
        for st in range(16):
            t = tv(b, st)
            if r_ == 'intro' and k <= 2:                                      # el bajo solo (y los charles al final)
                if k == 2 and st % 2 == 0: NZ['hat'].hit(t, 1, [4, 2, 1] if st % 4 else [6, 3, 1])
                if k == 2 and st >= 12: snare(t, 0.3 + 0.12 * (st - 12), [7 + (st - 12), 4, 2])
                continue
            NZ['shaker'].hit(t, 1, [3, 1] if st % 2 else [4, 2, 1])
            if r_ == 'solo':                                                  # paradas: golpe y charles
                if k % 2 == 1 and st == 0: hit(kick, TN.KICK_DEEP, t, 1.0); snare(t, 0.9); NZ['crash'].hit(t, 3, CRASH)
                if st % 2 == 0: NZ['hat'].hit(t, 1, [4, 2, 1])
                if k == 8 and st >= 8: hit(tom, W.TOMS[(st - 8) // 3 % 3], t, 0.6)
                continue
            big = r_ == 'big'
            if st in (0, 10) or (st == 7 and k % 2 == 0) or (big and st == 3 and k % 2 == 1): hit(kick, TN.KICK_DEEP, t, 1.0)
            if st in (4, 12): snare(t, 1.0)
            elif st in (7, 15) or (st == 9 and r_ == 'B'): snare(t, 0.22, [5, 2, 1])               # fantasmas
            if st % 4 == 2: NZ['ohat'].hit(t, 1, [6, 5, 4, 3, 2, 1])
            else: NZ['hat'].hit(t, 1, [5, 2, 1] if st % 2 == 0 else [3, 1])
            if st == 0 and (k == 1 or (big and k % 4 == 1)): NZ['crash'].hit(t, 3, CRASH)
            if last and st >= 12:
                hit(tom, W.TOMS[min(2, st - 12)], t, 0.7)
                if st >= 14: snare(t, 0.5 + (st - 14) * 0.15, [8 + (st - 14), 5, 2])

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
        'bass': slap.render(n + tail), 'lead': wave('lead'), 'dbl': pulse('dbl'),
        'stabs': pulse('c1') + pulse('c2'), 'pad': wave('pad1') + wave('pad2'),
        'hits': cut(F.pulse_dac(F.render_saw(Cn['h1']))) + cut(F.pulse_dac(F.render_saw(Cn['h2']))),
        'spark': GN.delay(pulse('spark'), 3 * S16, 0.35, 2, 4000),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + noise('snare'),
        'hat': noise('hat'), 'ohat': noise('ohat'), 'crash': noise('crash'), 'shaker': noise('shaker'),
    }
    S = {k: GN.fold(x, n, at) for k, x in S.items() if np.abs(x).max() > 0}
    g = GN.level(S, {k: LV.get(k, -10) for k in S}, 'bass')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('stabs', 0.35) + sd('pad', 0.3) + sd('ohat', 0.3) - sd('hat', 0.2) + sd('shaker', 0.3) + sd('spark', 0.5) \
        - sd('hits', 0.15) + sd('dbl', 0.25)
    y = F.master(np.stack([x + side, x - side], 1), lufs=LUFS)
    GN.report(NAME, y, S, g, n)
    # (comprobaciones: el bajo en notas de corchea o más que chocan con su acorde; la melodía, la de Calipso)
    bad = sum((nn - chord_at(b, st)[0]) % 12 in (1, 6) for b, st, nn, d, v in bass if d >= 2)
    print(f'  {BPM} BPM, {NB} compases ({NB * BAR:.1f} s: intro {INTRO * BAR:.1f} + bucle {(NB - INTRO) * BAR:.1f}); '
          f'bajo {len(bass)} notas ({sum(v >= 120 for *_, v in bass)} pops, {sum(v < 60 for *_, v in bass)} fantasma); '
          f'notas de bajo de corchea o más a 2ª menor o tritono del acorde: {bad}; melodía {len(mel)} notas')
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
        if os.environ.get('INSTALL'):                 # (el nivel del islote del Cangrejo Groove: catálogo `costa_groove`)
            GN.export('costa_groove', y, at)
