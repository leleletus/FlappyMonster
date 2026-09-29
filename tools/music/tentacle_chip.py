#!/usr/bin/env python3
# tools/music/tentacle_chip.py
# "Tentacle Chip": música de jefe chiptune (la del Mega Crabby) hecha a partir
# del ANÁLISIS de TentacleTantrum.ogg (el placeholder): mismo tempo, misma
# forma y el mismo groove tropical, con los mismos gestos armónicos pero todo
# en Sol menor (cadencia andaluza en A, bajo que baja en el estribillo,
# ♭VI–♭VII–i en el final) y una MELODÍA NUEVA hecha de un solo motivo (la
# bordadura Sol–Fa#–Sol de la referencia sobre el ritmo del tresillo) que se
# desarrolla en todas las secciones. Batería y bajo con la fuerza de
# chiptune_tentacle (bombo en tresillo, caja en los contratiempos, hi-hat).
#
#   python3 tools/music/tentacle_chip.py      → assets/music/tentacle_chip.ogg (+ .mid)
#   SOLO=lead,bass python3 ...                → solo esas pistas (para escucharlas)
#   python3 tools/music/tentacle_chip.py --instrumental
#                                             → tentacle_chip_instrumental.ogg: sin la melodía y con
#                                               capas propias para que no quede vacía: colchón de
#                                               "cuerdas" chip, acordes rítmicos en tresillo, arpegios
#                                               en todas partes, cencerro, palmas, congas, timbales,
#                                               shaker, impactos, subidas, platillos al revés y zaps;
#                                               al mismo volumen total que la versión completa
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
INSTRUMENTAL = '--instrumental' in sys.argv
NAME = 'tentacle_chip' + ('_instrumental' if INSTRUMENTAL else '')
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


# Armonía de una pasada (36 compases), 2 acordes por compás (medio compás
# cada uno). Todo en Sol menor, por bloques que llevan de uno a otro:
#   A      i – ♭VII – ♭VI – V (cadencia andaluza: enérgica, latina), dos veces
#   Break  ♭VI – iv – V (suspendido en la dominante: pide seguir)
#   B      relativo mayor, luminoso: ♭III – ♭VII – i – ♭VI (bajo que baja Re–Do–Sib,
#          como el estribillo de la referencia) y cierra en V
#   C      desarrollo: iv – i – iv – V – ♭VI – ♭III – iv/V – V (tensión en la dominante)
#   D      el final: ♭VI – ♭VII – i (el mismo gesto que la referencia, en nuestra
#          tonalidad) y termina en V para volver al principio (bucle)
H = [
    # A
    ('Gm', 'Gm'), ('Gm', 'F'), ('Eb', 'Eb'), ('D', 'D'),
    ('Gm', 'Gm'), ('Gm', 'F'), ('Eb', 'F'), ('D', 'D'),
    # Break
    ('Eb', 'Eb'), ('Cm', 'Cm'), ('D', 'D7'), ('D7', 'D7'),
    # B (estribillo)
    ('Bb', 'Bb'), ('F', 'F'), ('Gm', 'Gm'), ('Eb', 'Eb'),
    ('Bb', 'Bb'), ('F', 'F'), ('Eb', 'F'), ('Cm', 'D'),
    # C
    ('Cm', 'Cm'), ('Gm', 'Gm'), ('Cm', 'Cm'), ('D', 'D'),
    ('Eb', 'Eb'), ('Bb', 'Bb'), ('Cm', 'D'), ('D', 'D'),
    # D (final)
    ('Eb', 'F'), ('Gm', 'Gm'), ('Eb', 'F'), ('Gm', 'Gm'),
    ('Eb', 'F'), ('Gm', 'Eb'), ('Cm', 'D'), ('D', 'D7'),
]
SECTION = ['A'] * 8 + ['BR'] * 4 + ['B'] * 8 + ['C'] * 8 + ['D'] * 8

# ── Melodía: por compás "paso:nota:largo" en semicorcheas ────────────────────
# MOTIVO (de la referencia: su melodía gira alrededor de Sol–Fa#–Sol): la
# bordadura Sol–Fa#–Sol sobre el ritmo del tresillo "X . . X X . X X".
#   A      el motivo, respondido y subiendo; cada 4 compases cae en la dominante
#   Break  contraste: notas largas y tranquilas; luego el motivo en fragmentos
#          que suben hasta el golpe del compás 12
#   B      mismo ritmo del motivo, en secuencias que bajan un grado por compás
#          (Re–Do–Sib–Sol) con el bajo; anticipaciones en el 7 y el 15
#   C      el motivo en Do (con Si natural) y carreras de semicorcheas
#   D      el motivo ampliado arriba, y la 2ª mitad una octava más alta
# Cada sección acaba en una línea que lleva a la siguiente (p. ej. Fa# → Sol).
MEL = {
    # A
    1: '0:G5:2 3:F#5:1 4:G5:2 6:D5:1 7:G5:1 8:Bb5:2 10:A5:1 11:G5:1 12:F#5:1 13:G5:1 14:D5:2',
    2: '0:G5:2 3:F#5:1 4:G5:2 6:D5:1 7:G5:1 8:A5:2 10:F5:1 11:C5:1 12:F5:1 13:A5:1 14:C6:2',
    3: '0:Bb5:2 3:A5:1 4:Bb5:2 6:G5:1 7:Eb5:1 8:G5:2 10:Bb5:1 11:Eb6:1 12:D6:1 13:C6:1 14:Bb5:2',
    4: '0:A5:2 3:G5:1 4:F#5:2 6:D5:1 7:F#5:1 8:A5:2 10:C6:1 11:A5:1 12:F#5:1 13:E5:1 14:D5:2',
    5: '0:G5:2 3:F#5:1 4:G5:2 6:D5:1 7:G5:1 8:Bb5:1 9:C6:1 10:D6:2 12:C6:1 13:Bb5:1 14:A5:2',
    6: '0:Bb5:2 3:A5:1 4:G5:2 6:F#5:1 7:G5:1 8:A5:2 10:C6:1 11:A5:1 12:F5:2 14:A5:2',
    7: '0:G5:1 1:Bb5:1 2:Eb6:2 4:D6:1 5:C6:1 6:Bb5:2 8:A5:1 9:C6:1 10:F6:2 12:Eb6:1 13:D6:1 14:C6:2',
    8: '0:D6:2 3:C6:1 4:A5:2 6:F#5:1 7:A5:1 8:D6:1 9:C6:1 10:A5:1 11:F#5:1 12:D5:1 13:E5:1 14:F#5:1 15:A5:1',
    # Break (el contraste tranquilo, y la subida)
    9: '0:G5:4 4:Bb5:2 6:G5:2 8:Eb5:6 14:F5:2',
    10: '0:G5:4 4:C6:2 6:Bb5:2 8:G5:6 14:A5:2',
    11: '0:A5:1 1:G5:1 2:F#5:2 4:A5:1 5:G5:1 6:F#5:2 8:C6:1 9:Bb5:1 10:A5:2 12:D6:1 13:C6:1 14:A5:2',
    12: '0:D6:2 2:D6:1 3:D6:1 4:C6:1 5:A5:1 6:F#5:1 7:A5:1 8:C6:1 9:D6:1 10:F#6:2 12:C6:1 13:D6:1 14:F#6:1 15:A6:1',
    # B (estribillo)
    13: '0:D6:2 3:D6:1 4:C6:1 5:Bb5:1 6:C6:1 7:D6:2 9:F6:1 10:D6:2 12:Bb5:2 14:C6:1 15:D6:1',
    14: '0:C6:2 3:C6:1 4:A5:1 5:F5:1 6:A5:1 7:C6:2 9:F6:1 10:C6:2 12:A5:2 14:Bb5:1 15:C6:1',
    15: '0:Bb5:2 3:Bb5:1 4:A5:1 5:G5:1 6:A5:1 7:Bb5:2 9:D6:1 10:Bb5:2 12:G5:2 14:A5:1 15:Bb5:1',
    16: '0:G5:2 3:G5:1 4:F5:1 5:Eb5:1 6:F5:1 7:G5:2 9:Bb5:1 10:G5:2 12:Eb5:1 13:F5:1 14:G5:1 15:A5:1',
    17: '0:D6:2 3:D6:1 4:C6:1 5:Bb5:1 6:C6:1 7:D6:2 9:F6:1 10:D6:2 12:Bb5:2 14:C6:1 15:D6:1',
    18: '0:C6:2 3:C6:1 4:A5:1 5:F5:1 6:A5:1 7:C6:2 9:F6:1 10:C6:2 12:A5:2 14:Bb5:1 15:C6:1',
    19: '0:G5:2 3:G5:1 4:Bb5:1 5:Eb6:1 6:D6:1 7:Eb6:1 8:F6:2 10:C6:1 11:A5:1 12:F6:1 13:Eb6:1 14:D6:1 15:C6:1',
    20: '0:Eb6:1 1:D6:1 2:C6:2 4:G5:1 5:C6:1 6:Eb6:2 8:D6:1 9:C6:1 10:A5:1 11:F#5:1 12:D5:1 13:F#5:1 14:A5:1 15:C6:1',
    # C (desarrollo)
    21: '0:C6:2 3:B5:1 4:C6:2 6:G5:1 7:C6:1 8:Eb6:1 9:D6:1 10:C6:1 11:Bb5:1 12:Ab5:1 13:G5:1 14:F5:1 15:Eb5:1',
    22: '0:D5:1 1:G5:1 2:Bb5:1 3:D6:1 4:G6:2 6:F#6:1 7:G6:1 8:D6:1 9:Bb5:1 10:G5:1 11:Bb5:1 12:A5:1 13:G5:1 14:F#5:1 15:G5:1',
    23: '0:C6:2 3:B5:1 4:C6:2 6:G5:1 7:C6:1 8:Eb6:1 9:F6:1 10:G6:2 12:F6:1 13:Eb6:1 14:D6:1 15:C6:1',
    24: '0:D6:1 1:A5:1 2:F#5:1 3:A5:1 4:D6:1 5:F#6:1 6:A6:2 8:F#6:1 9:E6:1 10:D6:1 11:C6:1 12:A5:1 13:F#5:1 14:D5:1 15:F#5:1',
    25: '0:G5:1 1:Bb5:1 2:Eb6:1 3:G6:1 4:F6:1 5:Eb6:1 6:D6:1 7:Eb6:1 8:Bb5:2 10:G5:1 11:Bb5:1 12:Eb6:2 14:D6:1 15:C6:1',
    26: '0:D6:1 1:F6:1 2:D6:1 3:Bb5:1 4:F5:1 5:Bb5:1 6:D6:2 8:D6:1 9:Eb6:1 10:F6:2 12:Eb6:1 13:D6:1 14:C6:1 15:Bb5:1',
    27: '0:C6:1 1:Eb6:1 2:G6:1 3:Eb6:1 4:C6:1 5:G5:1 6:Eb5:1 7:G5:1 8:F#5:1 9:A5:1 10:C6:1 11:D6:1 12:F#6:1 13:D6:1 14:C6:1 15:A5:1',
    28: '0:D5:1 2:D5:1 3:D5:1 4:E5:1 6:E5:1 7:E5:1 8:F#5:1 10:F#5:1 11:F#5:1 12:A5:1 13:C6:1 14:A5:1 15:F#5:1',
    # D (final)
    29: '0:G5:2 2:Eb5:1 3:G5:1 4:Bb5:2 6:G5:2 8:A5:2 10:F5:1 11:A5:1 12:C6:2 14:A5:2',
    30: '0:Bb5:2 3:A5:1 4:Bb5:2 6:G5:1 7:D5:1 8:G5:2 10:Bb5:1 11:A5:1 12:G5:1 13:F#5:1 14:G5:2',
    31: '0:G5:1 1:Bb5:1 2:G5:1 3:Eb5:1 4:G5:2 6:Bb5:2 8:C6:1 9:A5:1 10:F5:1 11:A5:1 12:C6:2 14:D6:2',
    32: '0:D6:2 3:C6:1 4:Bb5:2 6:A5:1 7:G5:1 8:G5:1 9:F#5:1 10:G5:1 11:Bb5:1 12:D6:2 14:G5:2',
    33: '0:G6:2 2:Eb6:1 3:G6:1 4:Bb6:2 6:G6:2 8:A6:2 10:F6:1 11:A6:1 12:C7:2 14:A6:2',
    34: '0:Bb6:2 3:A6:1 4:Bb6:2 6:G6:1 7:D6:1 8:Eb6:2 10:G6:1 11:Bb6:1 12:G6:1 13:F6:1 14:Eb6:2',
    35: '0:C6:1 1:Eb6:1 2:G6:1 3:Eb6:1 4:C6:1 5:Eb6:1 6:G6:2 8:F#6:1 9:A6:1 10:D6:2 12:C6:1 13:A5:1 14:F#5:1 15:D5:1',
    36: '0:D5:1 1:F#5:1 2:A5:1 3:D6:1 4:C6:1 5:A5:1 6:F#5:1 7:D5:1 8:C5:1 9:A4:1 10:F#4:1 11:A4:1 12:D5:1 13:E5:1 14:F#5:1 15:A5:1',
}


# Dónde calla la melodía (para respirar y dejar sitio a solos instrumentales):
#   'h2'   la 2ª mitad del compás: golpes de acorde en tresillo + redoble de toms
#   'perc' solo de percusión (toms, redoble, golpes de acorde, subida)
#   'steel' solo de steel drum (arpegios tropicales rápidos)
#   'drums' solo de batería (toms + bongós + golpes)
# Clave: (vuelta 1|2, compás 1-36). Sin vuelta = las dos.
def rest(passno, bar):
    if bar in (4, 16, 20, 32): return 'h2'
    if bar in (11, 12): return 'perc'
    if bar in (25, 26): return 'steel' if passno == 1 else 'drums'
    if passno == 2 and bar <= 4: return 'steel'        # la 2ª vuelta empieza instrumental
    return None


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
# Con fuerza (la energía de chiptune_tentacle): bombo en tresillo (0, 3, 5 de
# cada medio compás), caja dura en los contratiempos (2, 6, 10, 14: donde la
# referencia tiene el "chop") y hi-hat continuo en semicorcheas (`hh`: volumen
# de los tiempos de corchea / de las semicorcheas de en medio)
TRES = {0: 1, 3: .8, 5: .75, 8: .95, 11: .8, 13: .75}
DR = {
    'A':  {'k': TRES, 'chop': (2, 6, 10, 14), 'sn': {2: .8, 6: .9, 10: .8, 14: .9}, 'hh': (1, .5),
           'sh': {}, 'bongo': {1: .35, 3: .6, 7: .65, 9: .35, 11: .6, 15: .65}},
    'BR': {'k': {0: 1, 8: .9}, 'chop': (2, 6, 10, 14), 'sn': {}, 'hh': (.7, 0),
           'sh': {2: .6, 6: .6, 10: .6, 14: .6}, 'bongo': {}},
    'B':  {'k': {**TRES, 15: .5}, 'chop': (2, 6, 10, 14), 'sn': {2: .7, 6: 1, 10: .7, 14: 1}, 'hh': (1, .55),
           'sh': {}, 'bongo': {1: .4, 3: .7, 4: .35, 7: .75, 9: .4, 11: .7, 12: .35, 15: .75}},
    'C':  {'k': {0: 1, 3: .8, 6: .8, 8: 1, 11: .8, 14: .8}, 'chop': (2, 6, 10, 14),
           'sn': {4: .9, 12: .9, 2: .5, 10: .5, 15: .5}, 'hh': (1, .6), 'sh': {},
           'bongo': {1: .4, 3: .6, 5: .4, 7: .6, 9: .4, 11: .6, 13: .4, 15: .6}},
    'D':  {'k': {**TRES, 4: .6, 12: .6}, 'chop': (2, 6, 10, 14), 'sn': {2: .8, 6: 1, 10: .8, 14: 1},
           'hh': (1, .6), 'sh': {}, 'bongo': {1: .4, 3: .6, 5: .35, 7: .7, 9: .4, 11: .6, 13: .35, 15: .7}},
}
# Energía por compás (mezcla): el break baja, el compás 12 es el golpe más
# fuerte de la canción, el 28 crece antes del final y el 35-36 respira
BAR_GAIN = {8: 0.9, 9: 0.9, 10: 1.0, 11: 0.95, 27: 1.18, 34: 0.9, 35: 0.94}   # (el 12 ya lleva golpes y toms)

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


def lead_voice(f, n, ln, env):
    """Lead con más energía: dos pulsos desafinados (50 % + 25 %, efecto coro),
    una capa fina una octava arriba, un "scoop" de tono al atacar y un poco de
    saturación (más brillante y con más mordida que un pulso solo)."""
    vib = 0.25 if ln >= 3 else 0.0
    a = pulse(f * 2 ** (-7 / 1200), n, 0.5, vib=vib, vib_rate=6.5, vib_delay=0.1, bend=-1.0, bend_t=0.018)
    b = pulse(f * 2 ** (7 / 1200), n, 0.25, vib=vib, vib_rate=6.5, vib_delay=0.1, bend=-1.0, bend_t=0.018)
    c = pulse(f * 2, n, 0.125, bend=-1.0, bend_t=0.018)
    return np.tanh((0.55 * a + 0.45 * b + 0.22 * c) * 1.5) * env


def tom(f0, n):
    t = t_(n)
    return np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.7 * np.exp(-t / 0.02))) / SR) * np.exp(-t / 0.14)


def bandpass_(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


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
    pad, rhythm, perc2, fx = (Track(total) for _ in range(4))     # (solo en la instrumental)
    midi_ev = {k: [] for k in ('lead', 'harm', 'bass', 'arp')}   # (inicio s, nota, largo s)
    for b in range(nbars):
        bi = b % 36
        second = b >= 36
        sec = SECTION[bi]
        t0 = b * BAR
        pat = DR[sec]
        halves = [chord(c) for c in H[bi]]

        # ── Melodía (lead chip) + eco de 3 semicorcheas (tresillo) ──────────
        rs = rest(2 if second else 1, bi + 1)
        for st, m, ln in parse(MEL[bi + 1]):
            if rs in ('perc', 'steel', 'drums') or (rs == 'h2' and st >= 8):
                continue                                          # (respiro / solo)
            dur = ln * SIX
            n = int((dur + 0.06) * SR)
            env = adsr(n, a=0.003, d=0.1, s=0.75, r=0.04, gate=dur * 0.9)
            sig = lead_voice(hz(m), n, ln, env)
            lead.add(t0 + st * SIX, sig)
            echo.add(t0 + st * SIX + 3 * SIX, pulse(hz(m), n, 0.125) * env, 0.33)
            midi_ev['lead'].append((t0 + st * SIX, m, dur))
            # 2ª vuelta del final: la melodía doblada una octava abajo (más cuerpo)
            if second and sec == 'D':
                harm.add(t0 + st * SIX, pulse(hz(m - 12), n, 0.5) * env, 0.5)
                midi_ev['harm'].append((t0 + st * SIX, m - 12, dur))
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

        # ── Solos y respiros ─────────────────────────────────────────────────
        def hits(steps, gain=1.0):
            # Golpes del acorde entero (pulso + steel), con bombo debajo
            for k_, st in enumerate(steps):
                r, q, _ = halves[0 if st < 8 else 1]
                for iv in q[:4]:
                    m = 60 + (r + iv) % 12
                    n = int(0.3 * SR)
                    e = np.exp(-t_(n) / 0.09)
                    steel.add(t0 + st * SIX, (pulse(hz(m), n, 0.5) * 0.7 + pulse(hz(m) * 2, n, 0.125) * 0.4) * e, 0.55 * gain)
                kick.add(t0 + st * SIX, np.tanh(np.sin(2 * np.pi * np.cumsum(48 + 140 * np.exp(-t_(int(0.18 * SR)) / 0.022)) / SR)
                                                * np.exp(-t_(int(0.18 * SR)) / 0.12) * 1.8), gain)
        TOMS = {'H': 220, 'M': 165, 'L': 120}
        def toms(seq, gain=1.0):
            for tok in seq.split():
                st, pitch = tok.split(':')
                bongo.add(t0 + int(st) * SIX, tom(TOMS[pitch], int(0.25 * SR)), 0.9 * gain)
        def steel_solo(shape):
            # Solo de steel drum: olas de arpegio por las notas del acorde (2 octavas)
            for st in range(16):
                r, q, _ = halves[0 if st < 8 else 1]
                tones = sorted({58 + (r + iv - 58) % 12 + o for iv in q for o in (0, 12, 24)})
                m = tones[min(len(tones) - 1, shape[st])]
                n = int(0.24 * SR)
                e = np.exp(-t_(n) / 0.1)
                v = 1.0 if st in (0, 3, 6, 8, 11, 14) else 0.7
                sig = pulse(hz(m), n, 0.125, bend=0.35, bend_t=0.012) * 0.8 + np.sin(2 * np.pi * hz(m) * 2.01 * t_(n)) * np.exp(-t_(n) / 0.05) * 0.6
                steel.add(t0 + st * SIX, sig * e, 0.62 * v)
                midi_ev['arp'].append((t0 + st * SIX, m, 0.2))
        if rs == 'h2':
            hits((8, 11, 14))
            toms('12:H 13:H 14:M 15:L')
        elif rs == 'perc':
            if bi == 10:
                toms('0:H 1:H 2:M 3:H 4:M 5:M 6:L 7:M 8:H 9:H 10:M 11:H 12:M 13:L 14:L 15:L', 1.3)
                hits((0, 3, 6), 0.8)                                  # (acentos del tresillo)
            else:
                hits((0, 3, 6), 1.2)
                toms('8:H 9:H 10:H 11:M 12:M 13:M 14:L 15:L', 1.1)
        elif rs == 'steel':
            ups = [[0, 2, 4, 5, 4, 2, 3, 5, 6, 5, 4, 2, 3, 4, 6, 7], [7, 6, 4, 3, 4, 6, 5, 3, 2, 3, 5, 4, 2, 1, 2, 0]]
            steel_solo(ups[bi % 2])
        elif rs == 'drums':
            hits((0, 8), 0.9)
            toms('2:H 3:H 5:M 6:H 7:M 10:H 11:M 12:M 13:L 14:L 15:L' if bi % 2 == 0 else
                 '0:H 1:M 2:L 3:H 4:M 5:L 6:H 7:H 9:M 10:M 11:L 12:H 13:M 14:L 15:L')

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
                bl += [(o + 0, R, 3), (o + 3, R + 12, 2), (o + 5, R, 1), (o + 6, R + 12, 2)]
            elif sec == 'B':
                bl += [(o + 0, R, 2), (o + 2, R + 12, 1), (o + 3, R, 2), (o + 5, fifth, 1), (o + 6, R + 12, 2)]
            elif sec == 'C':
                bl += [(o + i, R + (12 if i % 2 else 0), 1) for i in range(8)]
            elif sec == 'D':
                bl += [(o + 0, R, 3), (o + 3, R + 12, 2), (o + 5, fifth, 1), (o + 6, R + 12, 2)]
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
            bass.add(t0 + st * SIX, (tri(hz(m), n) + pulse(hz(m) * 2, n, 0.5) * 0.18) * env)
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
            f = 48 + 140 * np.exp(-t / 0.022)                     # más grave y con más pegada
            k = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12)
            k = np.tanh(k * 1.8)
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
        # Hi-hat continuo en semicorcheas (más fuerte en las corcheas), con
        # fusas antes de cada tiempo y hi-hat abierto en los contratiempos
        hv, hw = pat['hh']
        busy = sec in ('A', 'B', 'C', 'D')
        for st in range(16):
            v = hv if st % 2 == 0 else hw
            if v > 0:
                n = int(0.035 * SR)
                s = highpass(noise(n), 8000) * np.exp(-t_(n) / 0.009)
                shaker.add(t0 + st * SIX, s, v * 0.8)
                if busy and st % 4 == 3:                               # fusa: "tsk-tsk"
                    shaker.add(t0 + st * SIX + SIX / 2, s, v * 0.55)
                if busy and st % 4 == 2 and sec in ('B', 'D'):         # abierto
                    no = int(0.12 * SR)
                    shaker.add(t0 + st * SIX, highpass(noise(no), 6000) * np.exp(-t_(no) / 0.05), 0.35)
        if busy:                                                        # caja fantasma
            for st in (1, 5, 9, 13):
                n = int(0.08 * SR)
                snare.add(t0 + st * SIX, highpass(noise(n, 2), 1200) * np.exp(-t_(n) / 0.03), 0.22)
        for st, v in pat['bongo'].items():                          # bongós: 2 alturas
            n = int(0.12 * SR)
            f0 = 330 if st % 4 == 3 else 250
            t = t_(n)
            s = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.5 * np.exp(-t / 0.01))) / SR) * np.exp(-t / 0.04)
            bongo.add(t0 + st * SIX, s, v)
        # ── Solo en la instrumental: capas extra para que no quede vacía ─────
        if INSTRUMENTAL:
            energetic = sec in ('A', 'B', 'C', 'D')
            # Colchón de acordes: "cuerdas" chip (pulso con trémolo en fusas)
            for h in range(2):
                r, q, _ = halves[h]
                n = int(BAR / 2 * SR) + int(0.03 * SR)
                tt = t_(n)
                trem = 0.65 + 0.35 * np.sign(np.sin(2 * np.pi * (4 / SIX) * tt))
                env = np.clip(tt / 0.04, 0, 1) * np.clip((BAR / 2 + 0.03 - tt) / 0.03, 0, 1)
                for iv in q[:3]:
                    m = 55 + (r + iv - 55) % 12
                    pad.add(t0 + h * BAR / 2, pulse(hz(m), n, 0.5) * trem * env, 0.9 if sec == 'BR' else 0.6)
            # Acordes rítmicos en tresillo (como una guitarra rítmica)
            if energetic:
                for st in (0, 3, 6, 8, 11, 14):
                    r, q, _ = halves[0 if st < 8 else 1]
                    n = int(0.11 * SR)
                    e = np.exp(-t_(n) / 0.045)
                    for iv in q[:3]:
                        m = 62 + (r + iv - 62) % 12
                        rhythm.add(t0 + st * SIX, pulse(hz(m), n, 0.25) * e, 1.0 if st in (0, 8) else 0.8)
            # Arpegios también en A, en el break y en el estribillo de la 1ª vuelta
            if sec == 'A' or (sec == 'B' and not second):
                for st in range(16):
                    r, q, _ = halves[0 if st < 8 else 1]
                    pcs = [r + iv for iv in q]
                    m = 72 + (pcs[st % len(pcs)] % 12) + (12 if (st // len(pcs)) % 2 else 0)
                    n = int(SIX * 0.9 * SR)
                    arp.add(t0 + st * SIX, pulse(hz(m), n, 0.125) * np.exp(-t_(n) / 0.05), 0.13)
            # Percusión tropical extra
            if energetic:
                for st in (0, 3, 6, 8, 11, 14):                     # cencerro en el tresillo
                    n = int(0.09 * SR)
                    cb = (pulse(540, n, 0.5) + pulse(800, n, 0.5)) * np.exp(-t_(n) / 0.035)
                    perc2.add(t0 + st * SIX, bandpass_(cb, 500, 3000), 0.45 if st in (0, 8) else 0.32)
                for st in (4, 12):                                   # palmas en el 2 y el 4
                    n = int(0.09 * SR)
                    cl = np.zeros(n)
                    for k in range(3):
                        i0 = int(k * 0.009 * SR)
                        m = n - i0
                        cl[i0:] += bandpass_(noise(m), 900, 3500) * np.exp(-t_(m) / (0.012 if k < 2 else 0.04))
                    perc2.add(t0 + st * SIX, cl, 0.6)
                for st, f0, v in ((3, 260, .5), (7, 185, .7), (11, 260, .5), (15, 185, .7), (10, 220, .35)):
                    n = int(0.16 * SR)                               # congas (tumbao)
                    tt = t_(n)
                    cg = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.3 * np.exp(-tt / 0.008))) / SR) * np.exp(-tt / 0.07)
                    perc2.add(t0 + st * SIX, cg, v)
                for st in range(16):                                 # shaker continuo
                    n = int(0.04 * SR)
                    perc2.add(t0 + st * SIX, highpass(noise(n), 5500) * np.exp(-t_(n) / 0.012) * (1 if st % 2 else 0.6), 0.22)
            if (bi + 1) % 4 == 0:                                    # timbales al final de cada frase
                for st in (12, 13, 14, 15) if bi % 8 != 7 else range(8, 16):
                    n = int(0.12 * SR)
                    tt = t_(n)
                    tb = (pulse(880 if st % 2 else 660, n, 0.5) * 0.5 + highpass(noise(n), 2000) * 0.5) * np.exp(-tt / 0.05)
                    perc2.add(t0 + st * SIX, tb, 0.35 + 0.05 * (st - 8))
            # Efectos: impacto al empezar cada sección, subida antes, zaps
            if bi in (0, 8, 12, 20, 28):
                n = int(1.0 * SR)
                tt = t_(n)
                boom = np.sin(2 * np.pi * np.cumsum(38 + 40 * np.exp(-tt / 0.08)) / SR) * np.exp(-tt / 0.35)
                fx.add(t0, boom * 1.2 + highpass(noise(n), 4000) * np.exp(-tt / 0.4) * 0.5, 0.9)
                nz = int(0.18 * SR)
                zap = pulse(1, nz, 0.5) * 0 + pulse(2000, nz, 0.25)
                ph = np.cumsum(2000 * np.exp(-t_(nz) / 0.05) + 150) / SR
                zap = np.where((ph % 1) < 0.25, 1.0, -1.0) * np.exp(-t_(nz) / 0.08)
                fx.add(t0 + 0.02, zap, 0.35)
            if bi in (7, 19, 27, 35):                                # subida + platillo al revés
                n = int(BAR * SR)
                tt = t_(n)
                sweep = highpass(noise(n), 1500) * (tt / (BAR)) ** 2.2
                fx.add(t0, sweep, 0.45)
                rv = highpass(noise(int(BAR / 2 * SR)), 5000) * np.exp((t_(int(BAR / 2 * SR)) - BAR / 2) / 0.25)
                fx.add(t0 + BAR / 2, rv, 0.5)
            if rs in ('h2', 'perc', 'drums'):                        # zaps en los golpes de los solos
                for st in ((8, 14) if rs == 'h2' else (0, 6)):
                    nz = int(0.12 * SR)
                    ph = np.cumsum(1600 * np.exp(-t_(nz) / 0.04) + 120) / SR
                    fx.add(t0 + st * SIX, np.where((ph % 1) < 0.5, 1.0, -1.0) * np.exp(-t_(nz) / 0.05), 0.25)

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
    for tr in (lead, echo, harm, steel, arp, pad, rhythm):
        tr.buf = lowpass(tr.buf, 7500)
    parts = [
        st_(lead, 0.72, -0.05), st_(echo, 0.30, 0.35), st_(harm, 0.30, 0.25), st_(steel, 0.75, 0.2),
        st_(arp, 0.24, -0.3), st_(bass, 0.72, 0.0), st_(kick, 0.95, 0.0), st_(snare, 0.50, -0.1),
        st_(shaker, 0.30, 0.3), st_(bongo, 0.34, -0.35), st_(chop, 0.22, 0.15),
    ]
    # Instrumental: fuera la melodía (lead, su eco y la 2ª voz); el steel y los
    # arpegios suben ~4 dB para llevar la canción. La normalización de abajo la
    # deja al mismo volumen total que la versión completa.
    if INSTRUMENTAL:
        names = ['lead', 'echo', 'harm', 'steel', 'arp', 'bass', 'kick', 'snare', 'shaker', 'bongo', 'chop']
        boost = {'steel': 1.6, 'arp': 1.6}
        parts = [(p[0] * boost.get(nm, 1.0), p[1] * boost.get(nm, 1.0)) for nm, p in zip(names, parts)
                 if nm not in ('lead', 'echo', 'harm')]
        parts += [st_(pad, 0.16, -0.25), st_(rhythm, 0.20, 0.3), st_(perc2, 0.42, -0.2), st_(fx, 0.55, 0.0)]
    # SOLO=lead,bass... → solo esas pistas (para escucharlas o medirlas); RAW=1 → sin normalizar
    solo = os.environ.get('SOLO')
    if solo and INSTRUMENTAL: solo = None
    if solo:
        names = ['lead', 'echo', 'harm', 'steel', 'arp', 'bass', 'kick', 'snare', 'shaker', 'bongo', 'chop']
        parts = [p for nm, p in zip(names, parts) if nm in solo.split(',')]
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
    if os.environ.get('RAW'):
        return x, midi_ev
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
    if not INSTRUMENTAL:                                     # (el .mid es el de la versión completa)
        write_midi(os.path.join(OUT, NAME + '.mid'), ev)
    ogg = os.path.join(OUT, NAME + '.ogg')
    os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 5 "{ogg}"')
    os.remove(wav)
    print(f'  {ogg}  {len(x) / SR:.1f} s' + ('' if INSTRUMENTAL else f'  (+ {NAME}.mid)'))
