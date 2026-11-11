#!/usr/bin/env python3
# tools/music/tutorial.py
# La música del nivel TUTORIAL (id `tutorial`, "Primeros pasos"): acogedora, juguetona, sin prisa; suena mientras se
# leen los carteles, así que va DEBAJO de la lectura. No es de ninguna isla ni lleva motivos de jefes o de la historia.
# Mi bemol mayor, 105 BPM (1 compás = 100 800 muestras exactas), con un balanceo ligero de las corcheas (60/40).
# La idea: un PASEO. El bajo de triángulo camina en negras (los pasos del monstruo) y la melodía es una célula de
# 2 compases (un 3+3+2 suave que sube una 6.ª y vuelve a su sitio; la respuesta baja una 3.ª y sube por grados) en secuencia.
# Forma: intro 4 (los pasos solos; luego la guitarrilla) + bucle de 64 compases, 8 frases de 8:
#   A      flauta del N163
#   A'     la misma cabeza, cierre más alto; entra el colchón
#   B      tema propio, notas largas sobre el IV
#   A''    la melodía pasa a la CAJA DE MÚSICA, una octava arriba, sin colchón
#   C      «el rincón de leer»: sin batería, bajo en blancas, caja de música en notas largas; el GIRO OSCURO (La♭ menor,
#          una sola vez) y LA LLAMADA en Mi♭ (Si♭-Mi♭-Sol-Si♭), una vez, sobre su acorde
#   D      «AHORA TÚ»: la flauta enseña un compás y un pulso fino lo repite (como el tutorial); en el último se luce
#   A'''   lo más lleno (octava de pulso, todos los contratiempos): crece por capas, no por volumen
#   V      la vuelta: la célula en voz baja, hasta la textura del principio; su último compás es IGUAL al de la intro
# Acento propio: el GUIÑO (8-5-8, campanita corta del N163, solo notas del acorde) donde la melodía descansa.
# NO se ha escuchado: solo números.
#   REPORT=1 python3 tools/music/tutorial.py    solo números
#   INSTALL=1 python3 tools/music/tutorial.py   escribe worlds/tutorial/tutorial_intro|_loop.ogg y mid/tutorial.mid
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, q_n163, q_tri
import tentacle_nes as TN
import gloomy_nes as GN
import worldmap_nes as W

BPM = 105
S16 = 60.0 / BPM / 4
BAR = 16 * S16
SWING = 0.4                               # (semicorcheas que se retrasa la 2.ª corchea de cada negra: 60/40)
INTRO = 4
NB = INTRO + 64
MAJ, MIN, DOM = (0, 4, 7), (0, 3, 7), (0, 4, 7, 10)
PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
ESCALA = {3, 5, 7, 8, 10, 0, 2}           # Mi♭ mayor


def N(s):
    """'Eb4' → nota MIDI"""
    alt = {'b': -1, '#': 1}.get(s[1], 0) if len(s) == 3 else 0
    return 12 * (int(s[-1]) + 1) + PC[s[0]] + alt


def acorde(c):
    """'Eb' / 'Cm' / 'Bb7' → (clase de nota de la raíz, intervalos)"""
    r = c.rstrip('m7')
    q = c[len(r):]
    return N(r + '0') % 12, {'m': MIN, '7': DOM, '': MAJ}[q]


# ── Acordes por frase (un compás = 'Eb'; dos mitades = 'Fm|Bb7') ─────────────────────────────────────────────────
CH = {
    'in': 'Eb Eb Fm Bb7',
    'A':  'Eb Ab Cm Bb7 Eb Ab Fm|Bb7 Eb',
    'A1': 'Eb Ab Cm Bb7 Eb Cm Ab|Bb7 Eb',
    'B':  'Ab Bb Gm Cm Ab Fm Bb Bb7',
    'A2': 'Eb Ab Cm Bb7 Eb Ab Fm|Bb7 Eb',
    'C':  'Ab Abm Eb Cm Fm Bb Gm Bb7',
    'D':  'Eb Eb Ab Ab Fm Fm Bb7 Bb7',
    'A3': 'Eb Ab Cm Bb7 Eb Cm Ab|Bb7 Eb',
    'V':  'Eb Cm Ab Bb Eb Cm Fm|Bb7 Bb7',
}
ORDEN = ['A', 'A1', 'B', 'A2', 'C', 'D', 'A3', 'V']

# ── La melodía: cada compás, "semicorchea:nota:duración" ─────────────────────────────────────────────────────────
A = ['0:Bb3:3 3:G4:3 6:Ab4:2 8:Bb4:3 11:G4:5',
     '2:C5:2 4:Ab4:2 6:Bb4:1 7:C5:7',
     '0:G3:3 3:Eb4:3 6:F4:2 8:G4:3 11:Eb4:5',
     '2:F4:2 4:D4:2 6:Eb4:1 7:F4:7',
     '0:G4:3 3:Eb5:3 6:D5:2 8:C5:2 10:Bb4:3 13:G4:3',
     '2:Ab4:2 4:C5:2 6:Eb5:5 11:C5:2 13:Ab4:3',
     '2:F4:2 4:Ab4:2 6:C5:2 8:Bb4:2 10:Ab4:2 12:F4:2 14:D4:2',
     '0:Eb4:2 2:G4:8']
A1 = A[:3] + ['2:F4:2 4:D4:2 6:Eb4:1 7:F4:5 12:Ab4:2 14:F4:2',
              '0:G4:3 3:Eb5:3 6:F5:2 8:G5:3 11:Eb5:5',
              '2:Eb5:2 4:C5:2 6:D5:1 7:Eb5:7',
              '2:C5:2 4:Ab4:4 8:D5:3 11:C5:1 12:Bb4:4',
              '2:Eb5:8']
B = ['2:C5:6 8:Bb4:2 10:Ab4:6',
     '2:D5:6 8:C5:2 10:Bb4:6',
     '2:D5:2 4:Eb5:1 5:D5:3 8:Bb4:4 12:G4:4',
     '2:G4:2 4:C5:2 6:D5:1 7:Eb5:9',
     '2:Eb5:2 4:F5:1 5:Eb5:3 8:C5:6',
     '2:Ab4:2 4:C5:2 6:F5:8 14:Eb5:2',
     '0:D5:3 3:Bb4:3 6:C5:2 8:D5:8',
     '']
C = ['0:C5:8 8:Eb5:8',
     '0:Cb5:8 8:Eb5:8',                                  # (el giro oscuro: Do → Do♭)
     '0:Bb3:4 4:Eb4:4 8:G4:4 12:Bb4:4',                  # (la llamada, en Mi♭)
     '0:G4:8 8:Eb4:4 12:G4:4',
     '2:Ab4:6 8:C5:8',
     '0:D5:8 8:Bb4:8',
     '0:Bb4:8 8:G4:8',
     '0:F4:8 8:Ab4:6']
_D = ['2:Bb4:2 4:G4:1 5:Ab4:1 6:Bb4:2 8:Eb5:4',
      '2:C5:2 4:Ab4:1 5:Bb4:1 6:C5:2 8:Eb5:4',
      '2:Ab4:2 4:F4:1 5:G4:1 6:Ab4:2 8:C5:4',
      '2:D5:2 4:Bb4:1 5:C5:1 6:D5:2 8:F5:4']
D = [_D[0], _D[0], _D[1], _D[1], _D[2], _D[2], _D[3], '2:D5:2 4:Bb4:1 5:C5:1 6:D5:2 8:Bb5:4']
V = ['2:Bb4:2 4:G4:2 6:Ab4:1 7:Bb4:7',
     '2:Eb5:2 4:C5:2 6:D5:1 7:Eb5:7',
     '2:C5:2 4:Ab4:2 6:Bb4:1 7:C5:7',
     '2:D5:2 4:Bb4:2 6:C5:1 7:D5:7',
     '0:Bb3:3 3:G4:3 6:Ab4:2 8:Bb4:3 11:G4:5',
     '2:G4:2 4:Eb4:2 6:F4:1 7:G4:7',
     '2:Ab4:2 4:F4:2 6:G4:1 7:Ab4:1 8:F4:4 12:D4:4',
     '']
FRASES = {'A': A, 'A1': A1, 'B': B, 'A2': A, 'C': C, 'D': D, 'A3': A1, 'V': V}

# Qué toca cada frase. comp = contratiempos de la guitarrilla · kick / rim / hat = semicorcheas · pad = colchón
TEXT = {
    'in0': dict(comp=(), cv=0.0, kick=(), rim=(), hat=(2, 6, 10, 14), pad=False),
    'in1': dict(comp=(6, 14), cv=0.8, kick=(0,), rim=(12,), hat=(2, 10), pad=False),
    'A':   dict(comp=(6, 14), cv=1.0, kick=(0,), rim=(12,), hat=(2, 10), pad=False),
    'A1':  dict(comp=(6, 14), cv=1.0, kick=(0, 10), rim=(12,), hat=(2, 6, 10, 14), pad=True),
    'B':   dict(comp=(6, 14), cv=0.9, kick=(0,), rim=(12,), hat=(2, 10), pad=True),
    'A2':  dict(comp=(2, 10), cv=0.8, kick=(0,), rim=(), hat=(2, 6, 10, 14), pad=False),
    'C':   dict(comp=(), cv=0.0, kick=(), rim=(), hat=(), pad=True),
    'D':   dict(comp=(6, 14), cv=1.0, kick=(0, 8), rim=(4, 12), hat=(2, 10), pad=False),
    'A3':  dict(comp=(2, 6, 10, 14), cv=0.85, kick=(0, 8), rim=(4, 12), hat=(2, 6, 10, 14), pad=True),
    'V':   dict(comp=(6, 14), cv=0.8, kick=(0,), rim=(12,), hat=(2, 10), pad=False),
}
GUINO = {'in': (2, 4), 'A': (8,), 'A1': (8,), 'B': (8,), 'A2': (8,), 'A3': (8,), 'V': (8,)}


def seccion(b):
    """Del compás de la canción (1..NB): (frase, compás dentro de la frase, 1..8)"""
    if b <= INTRO: return 'in', b
    i = b - INTRO - 1
    return ORDEN[i // 8], i % 8 + 1


def bal(st):
    """Semicorchea (0..16) → posición con el balanceo: la corchea débil de cada negra se retrasa SWING"""
    beat, x = divmod(st, 4)
    x = x * (2 + SWING) / 2 if x <= 2 else (2 + SWING) + (x - 2) * (2 - SWING) / 2
    return 4 * beat + x


def tval(b, st):
    b += int(st // 16)
    st = st % 16
    return (b - 1) * BAR + bal(st) * S16


def acordes_de(b):
    """Los dos acordes (mitad 1, mitad 2) del compás b"""
    s, m = seccion(b)
    c = CH[s].split()[m - 1].split('|')
    return acorde(c[0]), acorde(c[-1])


def chord_at(b, st): return acordes_de(b)[0 if st < 8 else 1]


def melodia():
    """(compás, semicorchea, nota, duración, frase, compás de la frase)"""
    out = []
    for b in range(INTRO + 1, NB + 1):
        s, m = seccion(b)
        for x in FRASES[s][m - 1].split():
            a, n, d = x.split(':')
            out.append((b, int(a), N(n), int(d), s, m))
    return out


MEL = melodia()


def nota_en(b, st):
    """La nota de la melodía que suena en (compás, semicorchea), o None"""
    for bb, a, n, d, s, m in MEL:
        if bb == b and a <= st < a + d: return n
    return None


CLASH = {1, 6, 11}


def linea_bajo():
    """El bajo camina: (compás, semicorchea, nota, duración). Raíz, 3.ª, 5.ª y una nota de paso hacia la raíz siguiente,
    evitando m2 / M7 / tritono contra la melodía; en C, blancas."""
    def raiz(r): return 38 + (r - 38) % 12
    out = []
    for b in range(1, NB + 1):
        s, m = seccion(b)
        (r1, q1), (r2, q2) = acordes_de(b)
        ra = raiz(r1)
        if s == 'C':
            out += [(b, 0, ra, 8), (b, 8, ra + q1[2], 8)]
            continue
        sig = raiz(acordes_de(b % NB + 1 if b < NB else INTRO + 1)[0][0])
        if (r1, q1) != (r2, q2):
            n1 = [ra, ra + q1[2], raiz(r2)]
        elif b % 2 == 1:
            n1 = [ra, ra + q1[1], ra + q1[2]]
        else:
            n1 = [ra, ra + q1[2], ra + 12]
        prev = n1[2]
        mel = nota_en(b, 12)
        cand = sorted((sig + d for d in (-2, -1, 1, 2) if (sig + d) % 12 in ESCALA), key=lambda x: abs(x - prev))
        ok = [c for c in cand if mel is None or (mel - c) % 12 not in CLASH]
        ap = ok[0] if ok else ra + q2[2]
        out += [(b, st, n, 4) for st, n in zip((0, 4, 8), n1)] + [(b, 12, ap, 4)]
    return out


# ── Instrumentos ─────────────────────────────────────────────────────────────────────────────────────────────────
I_FLAUTA = {'vol': [9, 12, 14, 14, 13, 13], 'sus': 12, 'vib': (16, 0.18, 5.2), 'duty': 3.0}     # entra blandita
I_CAJA = {'vol': [15, 13, 12, 11, 10, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 1], 'sus': 1, 'duty': 0.0}
I_CAJA_L = dict(I_CAJA, vol=[15, 13, 12, 11, 11, 10, 10, 9, 9, 8, 8, 8, 7, 7, 7, 6, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 3, 3, 3, 3, 3, 2], sus=2)
I_ALUMNO = {'vol': [10, 9, 8, 8, 7], 'sus': 6, 'duty': 0.125, 'vib': (18, 0.15, 5.4)}
I_OCT = {'vol': [8, 8, 7, 7, 6], 'sus': 6, 'duty': 0.25, 'vib': (16, 0.18, 5.2)}
I_GUINO = {'vol': [11, 8, 6, 4, 3, 2, 1], 'sus': 0, 'duty': 0.0}
I_COMP = {'vol': [12, 9, 6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_PAD = dict(W.I_PAD, duty=2.0)
I_TRI = {'vol': [15], 'sus': 15}
WAVES = W.WAVES + [F.wavetable([1.0, 0.7, 0.4, 0.25, 0.12, 0.06])]                                    # 3 flauta suave
HAT, RIM = [4, 2, 1], [7, 4, 2, 1]


def voz_acorde(r, q, lo=60):
    """3.ª y 5.ª del acorde, en el registro de la guitarrilla"""
    a = lo + (r + q[1] - lo) % 12
    b = lo + (r + q[2] - lo) % 12
    return a, b


def build():
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'caja', 'alumno', 'oct', 'bass', 'c1', 'c2', 'guino', 'p1', 'p2', 'p3')}
    NZ = {k: Noise(NF) for k in ('hat', 'rim')}
    for z in NZ.values(): z.exact = True
    NS = int(NF * F.FRAME_S) + SR
    kick = np.zeros(NS)
    body = np.zeros(NS)

    def mete(buf, s, t, g):
        i = int(t * SR)
        buf[i:i + len(s)] += s[:max(0, min(len(s), NS - i))] * g

    for b, st, n, d, s, m in MEL:
        t0, t1 = tval(b, st), tval(b, st + d) - 0.05 * S16
        if s == 'A2':
            play(Cn['caja'], t0, t1, n + 12, I_CAJA, q=q_n163, release=3)
        elif s == 'C':
            play(Cn['caja'], t0, t1, n + 12, I_CAJA_L, q=q_n163, release=3)
        elif s == 'D' and m % 2 == 0:
            play(Cn['alumno'], t0, t1, n, I_ALUMNO, release=2)
        else:
            play(Cn['lead'], t0, t1, n, I_FLAUTA, q=q_n163, release=4, vs=0.85 if s == 'V' else 1.0)
            if s == 'A3':
                play(Cn['oct'], t0, t1, n + 12, I_OCT, release=2)
    for b, st, n, d in linea_bajo():
        play(Cn['bass'], tval(b, st), tval(b, st + d) - 0.3 * S16, n, I_TRI, q=q_tri, release=0)
    for b in range(1, NB + 1):
        s, m = seccion(b)
        tx = TEXT['in0' if s == 'in' and b <= 2 else 'in1' if s == 'in' else s]
        for st in tx['comp']:
            r, q = chord_at(b, st)
            a, c = voz_acorde(r, q)
            for ch, nn in zip(('c1', 'c2'), (a, c)):
                play(Cn[ch], tval(b, st), tval(b, st + 1.2), nn, I_COMP, vs=tx['cv'], release=1)
        if tx['pad']:
            (r1, q1), (r2, q2) = acordes_de(b)
            mitades = [(0, 16, r1, q1)] if (r1, q1) == (r2, q2) else [(0, 8, r1, q1), (8, 16, r2, q2)]
            for a0, a1, r, q in mitades:
                voces = sorted(55 + (r + iv - 55) % 12 for iv in q[:3])
                for ch, nn in zip(('p1', 'p2', 'p3'), voces):
                    play(Cn[ch], tval(b, a0), tval(b, a1) - 0.1 * S16, nn, I_PAD, q=q_n163, release=4)
        if m in GUINO.get(s, ()):                           # el guiño: 8-5-8
            r, q = acordes_de(b)[1]
            alto = 72 + (r - 72) % 12
            for st, nn, ln in ((10, alto, 2), (12, alto - 5, 1), (13, alto, 3)):
                play(Cn['guino'], tval(b, st), tval(b, st + ln), nn, I_GUINO, q=q_n163, release=2)
        for st in tx['kick']: mete(kick, TN.KICK, tval(b, st), 0.5 if st == 0 else 0.35)
        for st in tx['rim']:
            NZ['rim'].hit(tval(b, st), 4, RIM)
            mete(body, TN.SNARE_BODY, tval(b, st), 0.25)
        for st in tx['hat']: NZ['hat'].hit(tval(b, st), 0, HAT)

    n = NB * int(round(BAR * SR))
    intro = INTRO * int(round(BAR * SR))
    cut = lambda x: x[:n + 3 * SR] - np.mean(x[:n])
    wave = lambda ch: cut(F.render_wave(Cn[ch], WAVES) * 0.0075)
    pulse = lambda ch: cut(F.pulse_dac(F.render_pulse(Cn[ch])))
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    from scipy.signal import butter, sosfilt
    guita = butter(1, 2400, btype='low', fs=SR, output='sos')
    blando = lambda x: sosfilt(guita, x)                 # (la guitarrilla, redonda: que no tape la melodía en 1-5 kHz)
    S = {'lead': wave('lead'), 'caja': GN.delay(wave('caja'), 3 * S16, 0.22, 2, 3200),
         'alumno': pulse('alumno'), 'oct': pulse('oct'),
         'bass': cut(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)),
         'c1': blando(pulse('c1')), 'c2': blando(pulse('c2')), 'guino': wave('guino'),
         'pad': wave('p1') + wave('p2') + wave('p3'),
         'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base),
         'rim': cut(F.tnd_dac((body + 64) / 22638.0) - base) + cut(F.tnd_dac(NZ['rim'].render() / 22638.0 * 12)),
         'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12))}
    LV = {'lead': 0, 'caja': -2, 'alumno': -6, 'oct': -13, 'bass': 1.5, 'c1': -3, 'c2': -3, 'guino': -6, 'pad': -1, 'kick': 3, 'rim': -7, 'hat': -11}
    S = {k: GN.fold(v, n, intro) for k, v in S.items() if np.abs(v).max() > 0}
    g = GN.level(S, {k: LV.get(k, -12) for k in S}, 'lead')
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), sum(S[k] * g[k] for k in S))
    side = 0.3 * (S['c1'] * g['c1'] - S['c2'] * g['c2']) + 0.25 * S['guino'] * g['guino'] + 0.25 * S['hat'] * g['hat'] + 0.2 * S['caja'] * g['caja']
    y = F.master(np.stack([x + side, x - side], 1), lufs=-11.5)
    GN.report('tutorial', y, S, g, n)
    por_frases(y, S, g, intro)
    return y, intro


def por_frases(y, S, g, intro):
    """Nivel de cada frase, y cuánto tapa el acompañamiento a la melodía en 1-5 kHz (la melodía, mientras suena)"""
    from scipy.signal import butter, sosfilt
    bp = butter(2, (1000, 5000), btype='band', fs=SR, output='sos')
    mel = sum(S[k] * g[k] for k in ('lead', 'caja', 'alumno'))
    aco = sum(S[k] * g[k] for k in S if k not in ('lead', 'caja', 'alumno', 'oct'))
    mf, af = sosfilt(bp, mel), sosfilt(bp, aco)
    bar = int(round(BAR * SR))
    db = lambda x: 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    trozos = [('in', 0, intro)] + [(s, intro + i * 8 * bar, intro + (i + 1) * 8 * bar) for i, s in enumerate(ORDEN)]
    print('  frase: nivel dB · acomp − melodía en 1-5 kHz dB')
    for s, a, b in trozos:
        print(f'    {s:3s} {db(y[a:b]):6.1f} · {db(af[a:b]) - db(mf[a:b]) if np.abs(mf[a:b]).max() > 1e-6 else 0:6.1f}')


# ── Comprobaciones (números: no oyen) ────────────────────────────────────────────────────────────────────────────
def comprueba():
    tono, paso, igual, largas, fuera, malas = 0, 0, 0, 0, 0, []
    for i, (b, st, n, d, s, m) in enumerate(MEL):
        r, q = chord_at(b, st)
        en = (n - r) % 12 in [iv % 12 for iv in q]
        tono += en
        fuera += st % 4 != 0
        largas += d >= 4
        ant = MEL[i - 1][2] if i else None
        sig = MEL[i + 1][2] if i + 1 < len(MEL) else None
        if ant is not None:
            paso += 1 <= abs(n - ant) <= 2
            igual += n == ant
        if not en and not (d < 3 and ant is not None and sig is not None and 1 <= abs(n - ant) <= 2 and 1 <= abs(n - sig) <= 2):
            malas.append((b, st, n, d))
        if d >= 4: assert en, f'nota larga fuera del acorde: compás {b}, semicorchea {st}'
    t = len(MEL)
    print(f'  melodía: {t} notas · del acorde {100 * tono / t:.0f}% (aprobadas 79-90) · por grado {100 * paso / t:.0f}% (20-44) · '
          f'repetidas {100 * igual / t:.0f}% (1-23) · largas {100 * largas / t:.0f}% (11-46) · a contratiempo {100 * fuera / t:.0f}% (regla > 50)')
    print('  notas fuera del acorde que entran o salen por salto, o largas:', malas or 'ninguna')
    assert not malas
    # ¿el compás con 3+3+2?
    assert any([a for bb, a, *_ in MEL if bb == b][:3] == [0, 3, 6] for b in range(INTRO + 1, NB + 1)), 'falta el 3+3+2'
    choques = [(b, st, n, nn) for b, st, n, d in linea_bajo() for nn in [nota_en(b, st)] if nn is not None and (nn - n) % 12 in CLASH and d >= 2]
    print('  bajo contra melodía (m2 / M7 / tritono a la entrada de una negra):', choques or 'ninguno')
    assert seccion(NB)[0] == 'V' and CH['V'].split()[-1] == CH['in'].split()[-1] and V[-1] == ''


def escribe_mid():
    import mido
    mid = mido.MidiFile(ticks_per_beat=480)
    tr = mido.MidiTrack()
    mid.tracks.append(tr)
    tr.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / BPM), time=0))
    ev = []
    for b, st, n, d, s, m in MEL:
        t0 = ((b - 1) * 16 + st) * 120
        ev += [(t0, 1, 'note_on', n), (t0 + d * 120, 0, 'note_off', n)]
    t = 0
    for tt, _, kind, n in sorted(ev):
        tr.append(mido.Message(kind, note=n, velocity=96, time=tt - t))
        t = tt
    mid.save(F.out('tutorial', 'mid'))


if __name__ == '__main__':
    print(f'Primeros pasos: {BPM} BPM, intro {INTRO} + bucle {NB - INTRO} compases ({INTRO * BAR:.2f} + {(NB - INTRO) * BAR:.2f} s)')
    comprueba()
    y, intro = build()
    print(f'  muestras: intro {intro}, bucle {len(y) - intro} ({(len(y) - intro) / int(round(BAR * SR)):.3f} compases)')
    if os.environ.get('INSTALL'):
        GN.export('tutorial', y, intro)
        escribe_mid()
