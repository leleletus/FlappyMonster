#!/usr/bin/env python3
# CRAB TANTRUM — el tema del Mega Crabby, composición propia (ya no es el arreglo nota a nota de "Tentacle Tantrum").
#
# Es la BASE de los tres Mega Crabbies: de aquí saldrán la versión lúgubre y la helada (mismo tema, otra atmósfera).
#
# De "Tentacle Tantrum" solo se toman MUESTRAS, como quien samplea (lo demás es nuevo: respuestas, estribillo, puente,
# armonía, bajo y batería):
#   1. la CÉLULA del riff: tónica larga, tónica, sube una cuarta, baja a la tercera, tónica — con su ritmo 6-2-2-4-4.
#      Abre las frases de A (compases 1, 3 y, variada, 5) y la toca el BAJO en el puente tribal
#   2. el TRESILLO 3+3+2 (6-6-4 semicorcheas) del bajo y el bombo
#   3. el giro del estribillo: nota larga y bordadura inferior (una vez por frase de B)
#   4. la idea rítmica del final: notas repetidas sincopadas (6-4-4-4) sobre acordes que suben
# Y es de la COSTA, la isla del Mega Crabby: Re menor = el relativo de Fa mayor (costa_1); el estribillo se abre a Fa
# mayor; la marimba de la costa toca el tresillo; la maraca en semicorcheas; cierra con "la llamada" (La-Re-Fa-La).
# Carácter (el usuario): potente, TRIBAL y agresivo — timbales en ostinato, bombo marcado, bajo bien definido
# (triángulo + un pulso que lo dibuja una octava arriba), sierra del VRC6 + pulso en la melodía.
#
# Forma (compases de 16 semicorcheas a 180; se siente a 90): intro 4 (tambores; suena una vez, archivo aparte) ·
# A 8 · A' 8 · B 8 · B' 8 · PUENTE tribal 8 · A'' 8 · CODA 8 = bucle de 56 compases (74,7 s).
#
#   python tools/music/crab_tantrum.py        → assets/music/bosses/crab_tantrum_normal_{intro,loop}.ogg + .mid
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, q_tri, q_saw
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W

BPM = 180
S16 = 60.0 / BPM / 4
BAR = 16 * S16
INTRO = 4

N = {'C': 0, 'C#': 1, 'D': 2, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'Ab': 8, 'A': 9, 'Bb': 10, 'B': 11}
MAJ, MIN = (0, 4, 7), (0, 3, 7)
SCALE = {2, 4, 5, 7, 9, 10, 0, 1}                 # Re menor (+ Do#, la sensible, en la dominante)


def ch(s):
    return (N[s[:-1]], MIN) if s.endswith('m') else (N[s], MAJ)


A4, Bb4, C5, Cs5, D5, E5, F5, G5, A5, Bb5, C6, D6 = 69, 70, 72, 73, 74, 76, 77, 79, 81, 82, 84, 86

# ── Melodía: (compás de la frase, semicorchea, nota, duración). Una nota puede cruzar la barra (como en el riff) ──
CELL = [(1, 0, D5, 6), (1, 6, D5, 2), (1, 8, G5, 2), (1, 10, F5, 4)]                    # la muestra del riff
PH_A = CELL + [
    (1, 14, D5, 4),
    (2, 2, A4, 2), (2, 4, C5, 2), (2, 6, D5, 2), (2, 8, F5, 4), (2, 12, D5, 4),         # respuesta (nueva)
    (3, 0, D5, 6), (3, 6, D5, 2), (3, 8, G5, 2), (3, 10, F5, 4), (3, 14, A5, 4),        # la célula, que ahora sube
    (4, 2, A5, 4), (4, 6, G5, 2), (4, 8, G5, 2), (4, 10, E5, 2), (4, 12, C5, 4),
    (5, 0, D5, 6), (5, 6, D5, 2), (5, 8, F5, 2), (5, 10, D5, 4), (5, 14, Bb4, 4),       # su ritmo sobre Si♭
    (6, 2, Bb4, 4), (6, 6, D5, 2), (6, 8, E5, 4), (6, 12, G5, 4),
    (7, 0, G5, 3), (7, 3, F5, 3), (7, 6, D5, 2), (7, 8, Bb4, 3), (7, 11, D5, 3), (7, 14, G5, 2),   # tresillos que bajan
]
A_END = [(8, 0, A5, 6), (8, 6, G5, 2), (8, 8, E5, 2), (8, 10, Cs5, 4), (8, 14, A4, 2)]  # dominante: pregunta
A_END2 = [(8, 0, E5, 3), (8, 3, Cs5, 3), (8, 6, E5, 2), (8, 8, A5, 8)]                  # dominante: sube al estribillo
PH_B = [
    (1, 0, A5, 12), (1, 12, G5, 2), (1, 14, A5, 2),                                     # el giro del estribillo
    (2, 0, G5, 6), (2, 6, E5, 2), (2, 8, C5, 4), (2, 12, E5, 4),
    (3, 0, F5, 12), (3, 12, E5, 2), (3, 14, F5, 2),
    (4, 0, D5, 6), (4, 6, F5, 2), (4, 8, Bb5, 8),
    (5, 0, C6, 6), (5, 6, A5, 2), (5, 8, F5, 4), (5, 12, A5, 4),
    (6, 0, G5, 6), (6, 6, E5, 2), (6, 8, G5, 4), (6, 12, C6, 4),
]
B_END = [(7, 0, Bb5, 3), (7, 3, A5, 3), (7, 6, F5, 2), (7, 8, D5, 3), (7, 11, F5, 3), (7, 14, Bb5, 2),
         (8, 0, E5, 6), (8, 6, Cs5, 2), (8, 8, A4, 8)]
B_END2 = [(7, 0, G5, 3), (7, 3, Bb5, 3), (7, 6, G5, 2), (7, 8, D5, 3), (7, 11, G5, 3), (7, 14, Bb5, 2),
          (8, 0, A5, 6), (8, 6, G5, 2), (8, 8, E5, 4), (8, 12, Cs5, 4)]
# Puente tribal: tambores y el riff en el BAJO; la voz contesta desde el 5º compás (la célula, una octava abajo)
PH_BR = [(5, 0, D5 - 12, 6), (5, 6, D5 - 12, 2), (5, 8, G5 - 12, 2), (5, 10, F5 - 12, 4),
         (7, 0, D5, 6), (7, 6, D5, 2), (7, 8, G5, 2), (7, 10, F5, 4), (7, 14, A5, 4)]
# Coda: notas repetidas sincopadas (6-4-4-4) subiendo ♭VI–♭VII–i, y la llamada
PH_CODA = [
    (1, 0, F5, 6), (1, 6, F5, 4), (1, 10, F5, 4), (1, 14, G5, 4),
    (2, 2, G5, 6), (2, 8, G5, 4), (2, 12, G5, 4),
    (3, 0, A5, 6), (3, 6, A5, 4), (3, 10, A5, 4), (3, 14, A5, 4),
    (4, 2, A5, 4), (4, 6, G5, 2), (4, 8, F5, 4), (4, 12, D5, 4),
    (5, 0, Bb5, 6), (5, 6, Bb5, 4), (5, 10, Bb5, 4), (5, 14, C6, 4),
    (6, 2, C6, 6), (6, 8, C6, 4), (6, 12, C6, 4),
    (7, 0, D6, 6), (7, 6, D6, 4), (7, 10, D6, 4), (7, 14, D6, 2),
    (8, 0, A4, 4), (8, 4, D5, 2), (8, 6, F5, 2), (8, 8, A5, 6),                         # la llamada: La-Re-Fa-La
]
# Armonía: por compás, uno o dos acordes (medio compás cada uno)
CH_A = ['Dm', ['Dm', 'Bb'], 'Dm', ['Dm', 'C'], 'Bb', ['Bb', 'C'], 'Gm', 'A']
CH_B = ['F', 'C', 'Dm', 'Bb', 'F', 'C', 'Bb', 'A']
CH_B2 = ['F', 'C', 'Dm', 'Bb', 'F', 'C', 'Gm', 'A']
CH_BR = ['Dm'] * 8
CH_CODA = ['Bb', 'C', 'Dm', 'Dm', 'Bb', 'C', 'Dm', 'Dm']


def song():
    """→ melodía, acordes por compás [(1ª mitad, 2ª mitad)], etiqueta por compás, compases donde empieza frase"""
    mel, chords, tag, starts = [], [], [], []

    def section(kind, ph, cs):
        base = len(chords)
        starts.append(base + 1)
        for b, st, n, d in ph: mel.append((base + b, st, n, d))
        for c in cs:
            chords.append((ch(c[0]), ch(c[1])) if isinstance(c, list) else (ch(c), ch(c)))
            tag.append(kind)
    section('intro', [], ['Dm'] * INTRO)
    section('A', PH_A + A_END, CH_A)
    section('A', PH_A + A_END2, CH_A)
    section('B', PH_B + B_END, CH_B)
    section('B2', PH_B + B_END2, CH_B2)
    section('BR', PH_BR, CH_BR)
    section('A', PH_A + A_END, CH_A)
    section('CODA', PH_CODA, CH_CODA)
    return mel, chords, tag, starts


def check(mel, chords):
    """Las reglas del usuario: notas largas (≥ 4) del acorde que suena cuando empiezan; todo dentro de la escala"""
    def at(b, st):                                 # (una nota que entra en la última corchea y cruza la barra ANTICIPA el compás siguiente)
        if st >= 14: return chords[b % len(chords)][0]
        return chords[b - 1][0 if st < 8 else 1]
    bad = [(b, st) for b, st, n, d in mel if d >= 4 and (n - at(b, st)[0]) % 12 not in at(b, st)[1]]
    out = [(b, st) for b, st, n, d in mel if n % 12 not in SCALE]
    return bad, out


I_SAW = {'vol': [15, 15, 14, 14, 13, 13], 'sus': 13, 'vib': (14, 0.2, 6)}
I_PUL = {'vol': [11, 10, 9, 8, 8, 7], 'sus': 7, 'duty': [0.125, 0.25]}
I_TRI = {'vol': [15], 'sus': 15}
I_BDEF = {'vol': [12, 9, 6, 4, 3, 2], 'sus': 2, 'duty': 0.5}                 # el pulso que dibuja el bajo
I_MAR = {'vol': [11, 8, 5, 3, 2, 1], 'sus': 0, 'duty': 0.5}                  # la marimba de la costa
I_STAB = {'vol': [13, 11, 8, 5, 3, 2], 'sus': 1, 'duty': 0.25}
I_ECHO = {'vol': [5, 5, 4, 3], 'sus': 2, 'duty': 0.5}
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
TRES = (0, 6, 12)                                                             # el tresillo 3+3+2 (en corcheas)


def build(lufs=-10.0):
    mel, chords, tag, starts = song()
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'dbl', 'echo', 'c1', 'c2', 'bass', 'bdef', 'mar')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # MELODÍA: sierra una octava abajo (cuerpo) + pulso a su altura; en B', el puente y la coda, también la octava
    for b, st, n, d in mel:
        t0, t1 = tv(b, st), tv(b, st) + d * S16 * 0.93
        kind = tag[b - 1]
        play(Cn['lead'], t0, t1, n - 12, I_SAW, q=q_saw, release=3)
        play(Cn['dbl'], t0, t1, n + (12 if kind in ('B2', 'CODA') else 0), I_PUL, release=2)
        if d >= 3: play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 3) * S16 * 0.8, n, I_ECHO, release=1)

    def bass(b, st, ln, note):
        t = tv(b, st)
        play(Cn['bass'], t, t + ln * S16, note, I_TRI, q=q_tri, release=0)
        play(Cn['bdef'], t, t + min(ln, 2.5) * S16, note + 12, I_BDEF, release=1)

    for b in range(1, NB + 1):
        kind = tag[b - 1]
        (r1, q1), (r2, q2) = chords[b - 1]
        lo = lambda r: 38 + (r - 38) % 12                      # (el bajo, de Re1 hacia arriba)
        nxt = chords[b % NB][0][0] if b < NB else chords[INTRO][0][0]
        # ── BAJO ──
        if kind == 'intro':
            if b >= 3:                                         # entra con la célula del riff
                for st, ln, iv in ((0, 5.5, 0), (6, 1.8, 0), (8, 1.8, 5), (10, 3.6, 3), (14, 1.8, 0)): bass(b, st, ln, lo(r1) + iv)
        elif kind == 'BR':                                     # el riff, en el bajo
            for st, ln, iv in ((0, 5.5, 0), (6, 1.8, 0), (8, 1.8, 5), (10, 3.6, 3), (14, 1.8, -2 if b % 2 == 0 else 0)): bass(b, st, ln, lo(r1) + iv)
        elif kind in ('B', 'B2'):                              # estribillo: corcheas que empujan, octava en las "y" del 2 y el 4
            for st in range(0, 16, 2):
                r = r1 if st < 8 else r2
                bass(b, st, 1.7, lo(r) + (12 if st in (6, 14) else 0))
        else:                                                  # tresillo 6-6-4 y una nota de paso hacia el compás siguiente
            bass(b, 0, 5.5, lo(r1)); bass(b, 6, 1.8 if r2 != r1 else 5.5, lo(r1))
            if r2 != r1: bass(b, 8, 3.6, lo(r2))
            step = lo(r2) + (7 if (lo(r2) + 7 - nxt) % 12 in (0, 5, 7) else 12)
            bass(b, 12, 1.8, lo(r2)); bass(b, 14, 1.8, step if kind != 'CODA' else lo(r2) + 12)
        # ── MARIMBA (la costa): el acorde en el tresillo 3+3+2 de semicorcheas; calla en el puente hasta el 5º compás ──
        if kind != 'intro' or b >= 3:
            if not (kind == 'BR' and b - starts[5] < 4):
                for half, (r, q) in enumerate(((r1, q1), (r2, q2))):
                    notes = [72 + (r - 72) % 12 + iv for iv in q]
                    for k, st in enumerate((0, 3, 6)):
                        play(Cn['mar'], tv(b, half * 8 + st), tv(b, half * 8 + st) + S16 * 1.5, notes[(k + half) % 3], I_MAR, release=1)
        # ── GOLPES de quinta (potencia): en el tresillo, en A y la coda; a tiempo en el estribillo ──
        if kind in ('A', 'CODA', 'B', 'B2'):
            for st in (TRES if kind in ('A', 'CODA') else (0, 8)):
                r, q = (r1, q1) if st < 8 else (r2, q2)
                root = 50 + (r - 50) % 12
                ln = 2.5 if kind in ('A', 'CODA') else 6.5
                play(Cn['c1'], tv(b, st), tv(b, st) + ln * S16, root, I_STAB, release=2)
                play(Cn['c2'], tv(b, st), tv(b, st) + ln * S16, root + 7, I_STAB, release=2)
        # ── BATERÍA ──
        last = (b + 1) in starts or b == NB                    # último compás de la frase: redoble
        for st in range(16):
            t = tv(b, st)
            if kind == 'intro' or kind == 'BR':                # TRIBAL: bombo en el tresillo, timbales en ostinato
                k = b if kind == 'intro' else b - starts[5] + 1
                if st in TRES: hit(kick, TN.KICK_DEEP, t, 1.0)
                pat = {2: 0, 3: 1, 8: 2, 10: 0, 11: 1, 14: 2, 15: 2}
                if k % 2 == 0: pat = {2: 0, 3: 0, 4: 1, 8: 2, 9: 2, 10: 1, 11: 0, 14: 2, 15: 1}
                if st in pat: hit(tom, W.TOMS[pat[st]], t, 1.0)
                if kind == 'BR' and st % 2 == 0: NZ['hat'].hit(t, 1, [4, 2, 1])
                if kind == 'BR' and k >= 5 and st == 8: snare(t, 0.9)
                if last and st >= 8: snare(t, 0.4 + (st - 8) * 0.07, [7 + (st - 8), 5, 2])
            elif kind in ('B', 'B2'):                          # estribillo: bombo a negras, caja en 2 y 4 (doble tiempo)
                if st % 4 == 0: hit(kick, TN.KICK, t, 1.0)
                if st in (4, 12): snare(t, 0.95)
                else: NZ['hat'].hit(t, 1, [5, 2, 1] if st % 2 == 0 else [3, 1])
                if st in (10, 11) and b % 2 == 0: hit(tom, W.TOMS[1 if st == 10 else 2], t, 0.8)
            else:                                              # A y coda: tresillo en el bombo, caja en el 3 (medio tiempo), timbales
                if st in TRES or (st == 10 and b % 2 == 0): hit(kick, TN.KICK, t, 1.0)
                if st == 8 or (kind == 'CODA' and st == 4): snare(t, 1.0)
                elif st in (3, 14, 15): hit(tom, W.TOMS[2 if st == 3 else (1 if st == 14 else 2)], t, 0.85)
                else: NZ['hat'].hit(t, 1, [4, 2, 1] if st % 2 == 0 else [3, 1])        # maraca en semicorcheas
            if last and kind not in ('intro', 'BR') and st >= 12:                       # entrada a la frase siguiente
                snare(t, 0.6 + (st - 12) * 0.1, [9 + (st - 12), 5, 2]); hit(tom, W.TOMS[min(2, st - 12)], t, 0.7)
            if st == 0 and (b in starts or (kind in ('B', 'B2', 'CODA') and b % 2 == 1)) and b > 1: NZ['crash'].hit(t, 3, CRASH)

    n = int(NB * BAR * SR)
    n_i = int(INTRO * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k: cut(F.pulse_dac(F.render_pulse(Cn[k])))
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    S = {
        'lead': cut(F.pulse_dac(F.render_saw(Cn['lead']))), 'dbl': pulse('dbl'), 'echo': pulse('echo'),
        'stabs': pulse('c1') + pulse('c2'), 'mar': pulse('mar'),
        'bass': cut(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)), 'bdef': pulse('bdef'),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + cut(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
        'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12)), 'crash': cut(F.tnd_dac(NZ['crash'].render() / 22638.0 * 12)),
    }
    S = {k: GN.fold(v, n, n_i) for k, v in S.items()}
    LV = {'lead': 0, 'dbl': -8, 'echo': -12, 'stabs': -9, 'mar': -9, 'bass': 0, 'bdef': -8,
          'kick': 0, 'toms': -2, 'snare': -3, 'hat': -12, 'crash': -10}
    g = GN.level(S, LV, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    side = S['mar'] * g['mar'] * 0.5 - S['echo'] * g['echo'] * 0.6 + S['stabs'] * g['stabs'] * 0.3 + S['hat'] * g['hat'] * 0.3
    y = F.master(np.stack([x + side, x - side], 1), lufs=lufs)
    GN.report('crab_tantrum', y, S, g, n)
    bad, out = check(mel, chords)
    drums = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ('kick', 'toms', 'snare', 'hat', 'crash')) / sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    print(f'  {BPM} BPM, intro {INTRO} + bucle {NB - INTRO} compases ({(NB - INTRO) * BAR:.1f} s); melodía {len(mel)} notas; batería {100 * drums:.0f} % de la energía')
    print(f'  notas largas fuera del acorde: {bad or "ninguna"} · fuera de la escala: {out or "ninguna"}')
    return y, mel, n_i


if __name__ == '__main__':
    y, mel, n_i = build()
    if not os.environ.get('REPORT'):
        GN.export('crab_tantrum', y, n_i)
        W.write_mid(F.out('crab_tantrum', 'mid'), mel, BPM)
