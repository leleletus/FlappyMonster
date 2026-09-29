#!/usr/bin/env python3
# tools/music/tentacle_chip.py
# "Tentacle Chip": música de jefe chiptune (la del Mega Crabby) hecha a partir
# del ANÁLISIS de TentacleTantrum.ogg (el placeholder): mismo tempo, misma
# forma, mismo recorrido armónico y el mismo groove tropical, pero con una
# MELODÍA NUEVA, escrita aquí. Instrumentos chip (pulsos, triángulo, ruido).
#
#   python3 tools/music/tentacle_chip.py      → assets/music/tentacle_chip.ogg (+ .mid)
#
# Lo que se midió en la referencia (librosa, ver el final de este archivo):
#   · 92.5 BPM en 4/4 con semicorcheas (el "pulso" que parece de 123 es el
#     tresillo 3+3+2 del groove caribeño), compases de 2.595 s.
#   · Una pasada de 36 compases que se repite (72 compases ≈ 187 s):
#       A 1-8     riff cromático sobre Sol (Sol–Fa#–Si–Fa#, Re–Mi) y otra vez una 4ª arriba
#       Break 9-12  baja la energía, pedal de Fa#, golpe en el 12
#       B 13-20   estribillo tropical: Re–Do / Sib / Fa–La / Sib–Do, bajo "oom-pah"
#       C 21-28   tensión cromática (Do#–Si, La–Sol#, Fa#, Sol–Sol#...)
#       D 29-36   ♭VI–♭VII–I en Mib (Si – Do# – Re#): el "final" épico
#   · Batería: "chop" en todos los contratiempos (2, 6, 10, 14 de 16) y bombo
#     sincopado (1, 2e, 3, 4e).
# Lo que es de aquí (nuevo): todas las melodías, los contracantos, los
# arpegios, los rellenos y los sonidos.
import os, sys, wave
import numpy as np

SR = 44100
BPM = 92.5
SIX = 60.0 / BPM / 4                 # s por semicorchea
BAR = 16 * SIX
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'music')
NAME = 'tentacle_chip'
rng = np.random.default_rng(1985)

NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6,
        'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11, 'Cb': 11}


def midi(n):
    """'G4' → 67"""
    name, octv = n[:-1], int(n[-1])
    return 12 * (octv + 1) + NOTE[name]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# ── Acordes ───────────────────────────────────────────────────────────────────
QUAL = {'': (0, 4, 7), 'm': (0, 3, 7), '7': (0, 4, 7, 10), 'm7': (0, 3, 7, 10), 'dim': (0, 3, 6),
        'dim7': (0, 3, 6, 9), 'sus4': (0, 5, 7), 'aug': (0, 4, 8)}


def chord(sym):
    """'Gm' / 'D7/F#' → (raíz, notas relativas, bajo)"""
    bass = None
    if '/' in sym:
        sym, bass = sym.split('/')
    root = sym[:2] if len(sym) > 1 and sym[1] in '#b' else sym[:1]
    q = sym[len(root):]
    r = NOTE[root]
    return r, QUAL[q], NOTE[bass] if bass else r


# Armonía de una pasada (36 compases), 2 acordes por compás (medio compás cada uno)
H = [
    # A: riff sobre Sol (con Fa# cromático) y una 4ª arriba
    ('Gm', 'D7/F#'), ('Gm', 'D7/F#'), ('Gm', 'A7'), ('G/B', 'A7'),
    ('Cm', 'G/B'), ('Cm', 'Ab7'), ('Cm', 'Bb'), ('G/B', 'Bb'),
    # Break
    ('Gm', 'Bb'), ('F', 'Bdim'), ('F#dim7', 'F#dim7'), ('D7', 'D7'),
    # B: estribillo tropical
    ('Dm', 'C'), ('Bb', 'Bb'), ('F', 'Am'), ('Bb', 'C'),
    ('Dm', 'C'), ('Bb', 'Bb'), ('F', 'Am'), ('Bb', 'A7'),
    # C: tensión cromática
    ('A7/C#', 'G/B'), ('A7', 'A7'), ('F#dim7', 'G#dim7'), ('Am', 'B7'),
    ('D', 'C'), ('Bb', 'Bb'), ('Gm', 'A7'), ('Bb', 'C'),
    # D: ♭VI – ♭VII – I en Mib (Si = Dob)
    ('B', 'C#'), ('D#', 'D#'), ('B', 'C#'), ('D#', 'Cm7'),
    ('B', 'C#'), ('D#', 'D#'), ('Bdim', 'C#'), ('Bb', 'D7'),
]
SECTION = ['A'] * 8 + ['BR'] * 4 + ['B'] * 8 + ['C'] * 8 + ['D'] * 8

# ── Melodía (NUEVA): por compás "paso:nota:largo" en semicorcheas ────────────
MEL = {
    # A — llamada heroica y pícara, con el Fa# cromático
    1: '0:G4:2 2:D5:2 4:C5:1 5:Bb4:3 8:A4:2 10:F#4:2 12:A4:4',
    2: '0:G4:2 2:Bb4:2 4:D5:3 7:Eb5:1 8:D5:3 11:C5:1 12:A4:4',
    3: '0:Bb4:3 3:C5:1 4:D5:4 8:C#5:2 10:E5:2 12:G5:4',
    4: '0:F5:3 3:E5:1 4:D5:2 6:Bb4:2 8:C#5:4 12:E5:2 14:C#5:2',
    5: '0:C5:2 2:G5:2 4:F5:1 5:Eb5:3 8:D5:2 10:B4:2 12:D5:4',
    6: '0:C5:2 2:Eb5:2 4:G5:3 7:Ab5:1 8:G5:3 11:F#5:1 12:Eb5:4',
    7: '0:Eb5:3 3:F5:1 4:G5:4 8:F5:2 10:D5:2 12:Bb4:4',
    8: '0:B4:2 2:D5:2 4:F5:2 6:D5:2 8:C5:2 10:Bb4:2 12:A4:2 14:F#4:2',
    # Break — casi nada, y la subida
    9: '7:D5:2 9:C5:3 12:Bb4:2 14:A4:2',
    10: '7:F5:2 9:Eb5:3 12:D5:2 14:B4:2',
    11: '0:F#4:2 2:A4:2 4:C5:2 6:Eb5:2 8:F#5:2 10:A5:2 12:C6:2 14:Eb6:2',
    12: '0:D6:4 8:C6:1 9:A5:1 10:F#5:1 11:D5:1 12:C5:1 13:A4:1 14:F#4:1 15:A4:1',
    # B — estribillo tropical (anticipaciones en el 7 y el 15)
    13: '0:F5:3 3:E5:1 4:D5:2 6:A4:1 7:C5:3 10:E5:2 12:G5:3 15:F5:1',
    14: '0:D5:6 6:C5:1 7:D5:3 10:F5:2 12:D5:2 14:Bb4:2',
    15: '0:C5:3 3:A4:1 4:C5:2 6:F5:1 7:E5:3 10:C5:2 12:A4:3 15:G4:1',
    16: '0:Bb4:3 3:D5:1 4:F5:2 6:Bb5:1 7:A5:3 10:G5:2 12:E5:2 14:C5:2',
    17: '0:F5:3 3:E5:1 4:D5:2 6:A4:1 7:C5:3 10:E5:2 12:G5:3 15:F5:1',
    18: '0:D5:6 6:C5:1 7:D5:3 10:F5:2 12:D5:2 14:Bb4:2',
    19: '0:C5:3 3:A4:1 4:C5:2 6:F5:1 7:G5:3 10:A5:2 12:C6:3 15:Bb5:1',
    20: '0:A5:3 3:G5:1 4:F5:2 6:D5:1 7:E5:3 10:G5:2 12:E5:2 14:C#5:2',
    # C — carreras cromáticas de villano
    21: '0:E5:1 1:G5:1 2:Bb5:1 3:A5:1 4:G5:2 6:E5:1 7:C#5:1 8:D5:1 9:F5:1 10:G5:1 11:F5:1 12:D5:2 14:B4:1 15:D5:1',
    22: '0:C#5:2 2:E5:1 3:G5:1 4:A5:2 6:G5:1 7:E5:1 8:G#5:2 10:A5:1 11:C6:1 12:A5:2 14:E5:2',
    23: '0:Eb5:1 1:C5:1 2:A4:1 3:F#4:1 4:A4:2 6:C5:2 8:F5:1 9:D5:1 10:B4:1 11:G#4:1 12:B4:2 14:D5:2',
    24: '0:C5:2 2:E5:2 4:A5:2 6:G5:1 7:E5:1 8:D#5:2 10:F#5:2 12:A5:2 14:B5:2',
    25: '0:A5:2 2:F#5:1 3:D5:1 4:F#5:2 6:A5:2 8:G5:2 10:E5:1 11:C5:1 12:E5:2 14:G5:2',
    26: '0:F5:3 3:D5:1 4:Bb4:2 6:D5:1 7:F5:1 8:Bb5:2 10:A5:1 11:F5:1 12:D5:2 14:Bb4:2',
    27: '0:G5:2 2:F#5:1 3:F5:1 4:F#5:2 6:D5:2 8:C#5:2 10:E5:1 11:A5:1 12:G#5:2 14:A5:2',
    28: '0:Bb5:4 4:A5:2 6:F5:2 8:C6:4 12:G5:1 13:A5:1 14:Bb5:1 15:B5:1',
    # D — el final épico: notas largas que suben
    29: '0:D#5:4 4:F#5:2 6:D#5:2 8:F5:4 12:G#5:4',
    30: '0:A#5:8 8:G5:2 10:A#5:2 12:D#6:4',
    31: '0:D#6:3 3:C#6:1 4:B5:4 8:C#6:2 10:G#5:2 12:F5:4',
    32: '0:G5:6 6:A#5:2 8:G5:2 10:D#5:2 12:C5:4',
    33: '0:F#5:4 4:B5:2 6:F#5:2 8:G#5:4 12:C#6:4',
    34: '0:A#5:6 6:G5:1 7:A#5:1 8:D#6:8',
    35: '0:D6:2 2:B5:2 4:F5:2 6:D5:2 8:F5:2 10:G#5:2 12:C#6:4',
    36: '0:A#5:4 4:F5:2 6:D5:2 8:C5:2 10:D5:2 12:F#5:2 14:A5:2',
}


def parse(s):
    out = []
    for tok in s.split():
        st, n, ln = tok.split(':')
        out.append((int(st), midi(n), int(ln)))
    return out


# ── Patrones de batería por sección (16 semicorcheas; volumen 0-1) ───────────
# Medidos en la referencia y simplificados (ver el análisis al final)
# (Ojo: la "caja" de la referencia NO es un backbeat en 2 y 4: son los
# contratiempos del "chop" (skank tropical). Solo C lleva golpes de caja.)
DR = {
    'A':  {'k': {0: .6, 1: .5, 5: 1, 8: .85, 9: .5, 13: .5}, 'chop': (2, 6, 10, 14), 'sh': {2: 1, 6: 1, 10: 1, 14: 1},
           'sn': {0: .35, 5: .3, 9: .3}, 'bongo': {}},
    'BR': {'k': {0: 1, 2: .8, 4: .4, 5: .4, 6: .4, 8: 1, 9: .4, 12: .4, 14: .4}, 'chop': (2, 3, 6, 10, 11, 14),
           'sh': {2: .8, 3: .4, 4: .4, 6: .8, 10: .8, 11: .4, 12: .4, 14: .8}, 'sn': {}, 'bongo': {}},
    'B':  {'k': {0: .5, 1: .5, 5: .45, 8: .8, 9: .8, 13: .45}, 'chop': (2, 6, 10, 14), 'sh': {2: .8, 6: 1, 10: 1, 14: 1},
           'sn': {}, 'bongo': {3: .6, 7: .7, 11: .6, 15: .7}},
    'C':  {'k': {0: .8, 5: .8, 8: .45, 9: .45, 13: .8}, 'chop': (2, 3, 6, 10, 11, 14),
           'sh': {2: .8, 3: .5, 6: .8, 7: .5, 10: .8, 11: .5, 14: .8, 15: .5}, 'sn': {0: .6, 8: .6, 12: .6, 15: .6},
           'bongo': {}},
    'D':  {'k': {0: .45, 5: .45, 8: .7, 13: .5}, 'chop': (2, 6, 10, 14), 'sh': {2: .8, 6: 1, 10: 1, 11: .7, 14: 1},
           'sn': {}, 'bongo': {3: .5, 7: .6, 11: .5, 15: .6}},
}
# Energía por compás (mezcla): el break baja, el compás 12 es el golpe más
# fuerte de la canción, el 28 crece antes del final y el 35-36 respira
BAR_GAIN = {8: 0.9, 9: 0.9, 10: 0.92, 11: 1.3, 27: 1.18, 34: 0.9, 35: 0.94}

# ── Síntesis ─────────────────────────────────────────────────────────────────


def t_(n):
    return np.arange(n) / SR


def pulse(f, n, duty, vib=0.0, vib_rate=5.5, vib_delay=0.15, bend=0.0, bend_t=0.02):
    """Onda de pulso (duty 0.125/0.25/0.5) con vibrato y un golpe de tono al empezar"""
    t = t_(n)
    semi = np.zeros(n)
    if vib:
        semi += vib * np.sin(2 * np.pi * vib_rate * t) * np.clip((t - vib_delay) / 0.1, 0, 1)
    if bend:
        semi += bend * np.exp(-t / bend_t)
    ph = np.cumsum(f * 2 ** (semi / 12)) / SR
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def tri(f, n, steps=16):
    """Triángulo escalonado (4 bits, como el de la NES)"""
    ph = (np.arange(n) * f / SR) % 1.0
    x = 2 * np.abs(2 * ph - 1) - 1
    return np.round(x * (steps / 2)) / (steps / 2)


def noise(n, period=1):
    """Ruido tipo LFSR (period > 1 = más grave/metálico)"""
    base = rng.choice([-1.0, 1.0], size=n // period + 1)
    return np.repeat(base, period)[:n]


def adsr(n, a=0.004, d=0.08, s=0.7, r=0.03, gate=None):
    t = t_(n)
    gate = n / SR if gate is None else gate
    e = np.where(t < a, t / a, s + (1 - s) * np.exp(-(t - a) / d))
    rel = np.clip(1 - (t - gate) / r, 0, 1)
    return e * np.where(t > gate, rel, 1)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    from scipy.signal import lfilter
    return lfilter([1 - a], [1, -a], x)


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


class Track:
    def __init__(self, seconds):
        self.buf = np.zeros(int(seconds * SR) + SR)

    def add(self, start, sig, gain=1.0):
        i = int(start * SR)
        j = min(len(self.buf), i + len(sig))
        if i < len(self.buf):
            self.buf[i:j] += sig[:j - i] * gain


def render(passes=2):
    nbars = 36 * passes
    total = nbars * BAR
    lead, echo, harm, steel, arp, bass, kick, snare, shaker, bongo, chop = (Track(total) for _ in range(11))
    midi_ev = {k: [] for k in ('lead', 'harm', 'bass', 'arp')}   # (inicio s, nota, largo s)
    for b in range(nbars):
        bi = b % 36
        second = b >= 36
        sec = SECTION[bi]
        t0 = b * BAR
        pat = DR[sec]
        halves = [chord(c) for c in H[bi]]

        # ── Melodía (pulso 25%, vibrato) + eco de 3 semicorcheas (tresillo) ──
        for st, m, ln in parse(MEL[bi + 1]):
            if second and sec in ('D',):
                m += 12 if m < midi('C6') else 0        # el final, una octava arriba la 2ª vez
            dur = ln * SIX
            n = int((dur + 0.06) * SR)
            env = adsr(n, a=0.004, d=0.12, s=0.72, r=0.05, gate=dur * 0.92)
            sig = pulse(hz(m), n, 0.25, vib=0.22 if ln >= 3 else 0.0, bend=-0.6 if ln >= 2 else 0) * env
            lead.add(t0 + st * SIX, sig)
            echo.add(t0 + st * SIX + 3 * SIX, pulse(hz(m), n, 0.125) * env, 0.33)
            midi_ev['lead'].append((t0 + st * SIX, m, dur))
            # 2ª vuelta del estribillo: segunda voz una 3ª/6ª por debajo (del acorde)
            if second and sec == 'B' and ln >= 2:
                r, q, _ = halves[0 if st < 8 else 1]
                pcs = sorted({(r + i) % 12 for i in q})
                below = [x for x in range(m - 9, m - 2) if x % 12 in pcs]
                if below:
                    hm = below[-1]
                    harm.add(t0 + st * SIX, pulse(hz(hm), n, 0.5) * env, 0.45)
                    midi_ev['harm'].append((t0 + st * SIX, hm, dur))

        # ── "Steel drum": golpes cortos del acorde en los contratiempos ──────
        for st in pat['chop']:
            r, q, _ = halves[0 if st < 8 else 1]
            for k, iv in enumerate(q[:3]):
                m = 60 + (r + iv - 60 % 12) % 12 + (0 if (r + iv) % 12 >= 5 else 12)   # voz en la 4ª/5ª octava
                n = int(0.22 * SR)
                env = np.exp(-t_(n) / 0.07)
                s1 = pulse(hz(m), n, 0.125, bend=0.35, bend_t=0.012)
                s2 = np.sin(2 * np.pi * hz(m) * 2.01 * t_(n)) * np.exp(-t_(n) / 0.035)   # el "tin" del steel
                steel.add(t0 + st * SIX + k * 0.004, (s1 * 0.8 + s2 * 0.6) * env, 0.34 if sec != 'BR' else 0.26)
            nn = int(0.03 * SR)                                         # el rasgueo del skank
            scr = highpass(lowpass(noise(nn), 4200), 1500) * np.exp(-t_(nn) / 0.008)
            chop.add(t0 + st * SIX, scr, 1.3 if sec in ('BR', 'B', 'C') else 0.9)   # (más brillo en break y estribillo)

        # ── Arpegios rápidos (el final y la tensión) ─────────────────────────
        if sec in ('D', 'C') or (sec == 'B' and second):
            for st in range(16):
                r, q, _ = halves[0 if st < 8 else 1]
                pcs = [r + iv for iv in q]
                m = 72 + (pcs[st % len(pcs)] % 12) + (12 if (st // len(pcs)) % 2 else 0)
                n = int(SIX * 0.9 * SR)
                arp.add(t0 + st * SIX, pulse(hz(m), n, 0.125) * np.exp(-t_(n) / 0.05), 0.16 if sec == 'D' else 0.11)
                midi_ev['arp'].append((t0 + st * SIX, m, SIX * 0.9))

        # ── Break: destellos agudos (el bajón de la referencia es brillante) ──
        if sec == 'BR' and bi != 11:
            for st in range(0, 16, 2):
                r, q, _ = halves[0 if st < 8 else 1]
                pcs = [r + iv for iv in q]
                m = 84 + pcs[(st // 2) % len(pcs)] % 12
                n = int(SIX * 1.8 * SR)
                arp.add(t0 + st * SIX, pulse(hz(m), n, 0.125) * np.exp(-t_(n) / 0.12), 0.2)
                midi_ev['arp'].append((t0 + st * SIX, m, SIX * 1.8))

        # ── Bajo (triángulo): tresillo en A, oom-pah en B, cromático en C ─────
        bl = []
        for h in range(2):
            r, q, bnote = halves[h]
            R = 36 + bnote                                       # Do2..Si2
            if R > 45: R -= 12
            fifth = R + 7 if R + 7 <= 50 else R - 5
            o = h * 8
            if sec == 'A':
                bl += [(o + 0, R, 3), (o + 3, R, 3), (o + 6, R + 12, 2)]
            elif sec == 'B':
                bl += [(o + 0, R, 2), (o + 2, fifth, 2), (o + 4, fifth, 2), (o + 6, R, 2)]
            elif sec == 'C':
                bl += [(o + 0, R, 2), (o + 2, R + 12, 1), (o + 3, R, 2), (o + 5, R + 1 if h == 0 else R - 1, 1), (o + 6, R, 2)]
            elif sec == 'D':
                bl += [(o + i * 2, R + (12 if i % 2 else 0), 2) for i in range(4)]
            else:  # break (sin huecos: la referencia no se calla nunca)
                if bi == 10:
                    bl += [(o + i, R, 1) for i in range(8)]      # pedal en semicorcheas
                elif bi == 11:
                    bl += [(o + i * 2, R + (12 if i % 2 else 0), 2) for i in range(4)]   # corcheas que empujan
                else:
                    bl += [(o, R, 4), (o + 4, R + 12, 2), (o + 6, fifth, 2)]
        for st, m, ln in bl:
            dur = ln * SIX
            n = int((dur + 0.02) * SR)
            env = adsr(n, a=0.002, d=0.15, s=0.6, r=0.02, gate=dur * (0.98 if sec == 'BR' else 0.85))   # (legato en el break)
            bass.add(t0 + st * SIX, tri(hz(m), n) * env)
            midi_ev['bass'].append((t0 + st * SIX, m, dur))

        # ── Batería ─────────────────────────────────────────────────────────
        fill = (bi in (7, 11, 19, 27, 35))                          # fin de frase: redoble
        # Subida de ruido en los compases 11-12 (el break acaba en un "riser")
        if bi == 10:
            n = int(2 * BAR * SR)
            ramp = np.linspace(0, 1, n) ** 2.5
            rise = highpass(noise(n), 2500) * ramp
            shaker.add(t0, rise, 0.55)
        for st, v in pat['k'].items():
            n = int(0.18 * SR)
            t = t_(n)
            f = 55 + 120 * np.exp(-t / 0.025)
            k = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.09)
            # (golpe sin agudos: un clic de ruido sonaba también como caja y hi-hat)
            k += lowpass(noise(n), 900) * np.exp(-t / 0.006) * 0.6
            kick.add(t0 + st * SIX, k, v)
        sn = dict(pat['sn'])
        if fill:
            sn.update({12: .6, 13: .7, 14: .85, 15: 1})
        if bi == 11:                                                # redoble creciente hacia el estribillo
            sn.update({s_: 0.35 + 0.65 * (s_ - 4) / 11 for s_ in range(4, 16)})
        for st, v in sn.items():
            n = int(0.16 * SR)
            t = t_(n)
            s = highpass(noise(n, 2), 900) * np.exp(-t / 0.06) + tri(190, n) * np.exp(-t / 0.03) * 0.5
            snare.add(t0 + st * SIX, s, v)
        for st, v in pat['sh'].items():
            n = int(0.07 * SR)
            s = highpass(noise(n), 7000) * np.exp(-t_(n) / 0.02)
            shaker.add(t0 + st * SIX, s, v * (1.35 if sec in ('BR', 'B') else 1.0))
        for st, v in pat['bongo'].items():                          # bongós: 2 alturas
            n = int(0.12 * SR)
            f0 = 330 if st % 4 == 3 else 250
            t = t_(n)
            s = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.5 * np.exp(-t / 0.01))) / SR) * np.exp(-t / 0.04)
            bongo.add(t0 + st * SIX, s, v)
        # Golpe del break (compás 12): acorde entero, largo y fuerte
        if bi == 11:
            r, q, _ = halves[0]
            for iv in q:
                m = 60 + (r + iv) % 12
                n = int(1.2 * SR)
                steel.add(t0, pulse(hz(m), n, 0.25) * adsr(n, d=0.4, s=0.3, r=0.2, gate=1.0), 0.5)
        # Golpe del break (compás 12) y entrada del final
        if bi in (11, 12, 28):
            n = int(0.6 * SR)
            crash = highpass(noise(n), 3000) * np.exp(-t_(n) / 0.25)
            shaker.add(t0, crash, 1.2)

    # ── Mezcla ───────────────────────────────────────────────────────────────
    def st_(tr, g, pan):
        return tr.buf * g * (1 - pan), tr.buf * g * (1 + pan)
    # Los pulsos tienen muchos agudos en cada ataque: se suavizan SOLO ellos
    # (el shaker y el rasgueo tienen que sonar arriba, en los contratiempos)
    for tr in (lead, echo, harm, steel, arp):
        tr.buf = lowpass(tr.buf, 7500)
    parts = [
        st_(lead, 0.36, -0.05), st_(echo, 0.34, 0.35), st_(harm, 0.30, 0.25), st_(steel, 0.42, 0.2),
        st_(arp, 0.30, -0.3), st_(bass, 0.62, 0.0), st_(kick, 0.72, 0.0), st_(snare, 0.28, -0.1),
        st_(shaker, 0.30, 0.3), st_(bongo, 0.34, -0.35), st_(chop, 0.22, 0.15),
    ]
    L = sum(p[0] for p in parts)
    R = sum(p[1] for p in parts)
    x = np.stack([L, R], 1)
    # Bucle sin costura: lo que suena después del final (ecos, colas) se suma
    # al principio, que es por donde sigue la canción al repetirse
    end = int(total * SR)
    tail = x[end:]
    x = x[:end].copy()
    x[:len(tail)] += tail
    # ganancia por compás (con rampas cortas para que no haya saltos)
    g = np.ones(len(x))
    for b in range(nbars):
        g[int(b * BAR * SR): int((b + 1) * BAR * SR)] = BAR_GAIN.get(b % 36, 1.0)
    k = int(0.05 * SR)
    g = np.convolve(g, np.ones(k) / k, mode='same')
    x = x * g[:, None]
    # nivel como la referencia (RMS ≈ 0.19) sin recortar: compresión suave
    x = x / (np.sqrt(np.mean(x ** 2)) + 1e-9) * 0.215
    x = np.tanh(x * 1.6) / 1.6
    return x, midi_ev


def write_wav(path, x):
    with wave.open(path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())


def write_midi(path, ev):
    try:
        import mido
    except ImportError:
        print('  (sin mido: no se escribe el .mid)')
        return
    tpb = 480
    mf = mido.MidiFile(ticks_per_beat=tpb)
    meta = mido.MidiTrack(); mf.tracks.append(meta)
    meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(BPM)))
    for ch, (name, prog) in enumerate((('lead', 80), ('harm', 81), ('bass', 38), ('arp', 80))):
        tr = mido.MidiTrack(); mf.tracks.append(tr)
        tr.append(mido.MetaMessage('track_name', name=name))
        tr.append(mido.Message('program_change', program=prog, channel=ch))
        evs = []
        for t, n, d in ev[name]:
            a = int(round(t / (60 / BPM) * tpb)); b = int(round((t + d) / (60 / BPM) * tpb))
            evs += [(a, 1, n), (b, 0, n)]
        evs.sort(key=lambda e: (e[0], e[1]))
        last = 0
        for tick, on, n in evs:
            tr.append(mido.Message('note_on' if on else 'note_off', note=int(n), velocity=96 if on else 0,
                                   channel=ch, time=tick - last))
            last = tick
    mf.save(path)


if __name__ == '__main__':
    x, ev = render()
    wav = os.path.join(OUT, NAME + '.wav')
    write_wav(wav, x)
    write_midi(os.path.join(OUT, NAME + '.mid'), ev)
    ogg = os.path.join(OUT, NAME + '.ogg')
    os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 5 "{ogg}"')
    os.remove(wav)
    print(f'  {ogg}  {len(x) / SR:.1f} s  (+ {NAME}.mid)')
