#!/usr/bin/env python3
# CAÍDA LIBRE — tema de jefe COMPLETAMENTE ORIGINAL sobre el bajo de "Final Fall".
#
# El usuario (tras final_fall v4, que se queda como está): "otro aparte, completamente original; lo único que conserve
# de Final Fall es el bajo (esa parte que me gusta tanto, con su sonido, acordes y notas) y las voces (usadas más a
# menudo). Todo lo demás, una melodía de 2:40 completa, desde cero, sin unir partes, para que suene continua y natural".
#
# De Final Fall, SOLO:
#   · el RIFF DEL BAJO tal cual (Fa#1, su octava "pop", la cola sincopada; el giro La–Si–Do# / Re–Si–Do#), con su
#     sonido de bajo "real" (Slap Bass GM de TimGM6mb, fluidsynth; `final_fall.render_bass`). Suena todo el tema salvo
#     en el respiro, donde se queda en su nota (Fa#1 largo).
#   · las VOCES del original con el crunch de 8 bits (`final_fall.VOX`): el bloque entero al empezar y al cerrar (el
#     cierre lleva la 2ª mitad y la apertura la 1ª: cruzan la costura del bucle seguidas), filtradas en el respiro, y
#     cortes de un compás o de medio al final de las frases y en el diálogo del segundo clímax.
# Todo lo demás es nuevo y se compone DE CORRIDO (una sola línea de 120 compases, no bloques repetidos): una idea
# (sube por grados hasta una nota larga y se posa) que se va desarrollando frase a frase. La armonía se mueve ENCIMA del
# bajo sin tocarlo (Fa#m, Re, Mi, Sim sobre su Fa#; en los compases del giro, los acordes del giro).
#
# Recorrido (frases de 8 = una vuelta del riff; 181 BPM, Fa# menor):
#   1 apertura (riff + voces) · 2 el tema · 3 la respuesta · 4 desarrollo, más arriba · 5 el tema con contracanto ·
#   6 carrera hacia el respiro · 7 RESPIRO (sin riff: Fa#1 largo, caja de música, voces filtradas) · 8 vuelve el riff,
#   melodía cantabile · 9 la misma, intensificada · 10 CLÍMAX · 11 clímax en diálogo con las voces · 12 puente a medio
#   tiempo · 13 subida · 14 final con todo · 15 salida (las capas se van, vuelve la apertura) = 120 compases, 159,1 s.
# El timbre crece con la canción (regla de la casa): pulso con eco → N163 cálido → sierra del VRC6 doblando.
#
#   python tools/music/caida_libre.py     → previas en FlappyMonster_pruebas/musica/caida_libre/
#   INSTALL=1 …                           → assets/music/bosses/caida_libre.ogg + tools/music/mid/caida_libre.mid
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_saw, q_n163
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W
import final_fall as FF

BPM = FF.BPM
S16 = 60.0 / BPM / 4
BAR = 16 * S16
NAME = 'caida_libre'
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/musica/caida_libre'
SCALE = FF.SCALE
ch, nt = FF.ch, FF.nt
T1, T2 = ['A', 'B', 'C#'], ['D', 'B', 'C#']                       # los dos giros del riff (8 + 4 + 4 semicorcheas)
PLAIN = ['F#m', 'F#m', 'F#m', T1, 'F#m', 'F#m', 'F#m', T2]         # la armonía del riff
COLOR = ['F#m', 'D', 'E', T1, 'F#m', 'Bm', 'D', T2]                # la misma vuelta, coloreada por encima del pedal

# ══ LA MELODÍA, de corrido: (frase, armonía, papel) ══════════════════════════════════════════════════════════════
PHRASES = [
    # 1 apertura: el riff y las voces solos
    ([''] * 8, PLAIN, 'open'),
    # 2 el tema (pulso con eco, en el registro medio)
    (["2:C#5/2 4:E5/2 6:F#5/6 14:E5/2", "0:C#5/4 6:A4/2 8:B4/2 10:C#5/6",
      "2:E5/2 4:F#5/2 6:A5/4 10:G#5/2 12:F#5/4", "0:E5/4 4:C#5/2 6:E5/2 8:D#5/4 12:C#5/4",
      "2:C#5/2 4:E5/2 6:F#5/4 10:A5/2 12:G#5/2 14:F#5/2", "0:E5/2 2:F#5/2 4:C#5/8 12:A4/4",
      "2:B4/2 4:C#5/2 6:E5/2 8:F#5/6 14:G#5/2", "0:A5/4 4:F#5/2 6:D5/2 8:F#5/4 12:G#5/4"], PLAIN, 'theme'),
    # 3 la respuesta: lo mismo una sexta más arriba y por otros acordes
    (["2:F#5/2 4:A5/2 6:C#6/6 12:B5/2 14:A5/2", "0:A5/4 6:F#5/2 8:D5/2 10:F#5/6",
      "2:G#5/2 4:A5/2 6:B5/4 10:E5/2 12:G#5/4", "0:A5/3 3:C#6/3 6:E6/2 8:D#6/4 12:C#6/4",
      "2:C#6/2 4:B5/2 6:A5/6 12:G#5/2 14:F#5/2", "0:F#5/4 4:D5/2 6:F#5/2 8:B5/6 14:A5/2",
      "0:A5/2 2:F#5/2 4:A5/2 6:D6/6 12:C#6/2 14:A5/2", "0:F#5/4 4:A5/2 6:D6/2 8:D#6/4 12:C#6/4"], COLOR, 'answer'),
    # 4 desarrollo: más arriba, cabezas en 3+3+2
    (["0:A5/3 3:D6/3 6:F#6/4 10:E6/2 12:D6/4", "2:B5/2 4:E6/6 10:D6/2 12:B5/4",
      "0:C#6/3 3:A5/3 6:C#6/2 8:F#6/4 12:E6/2 14:C#6/2", "0:E6/4 4:C#6/2 6:A5/2 8:B5/4 12:G#5/4",
      "0:F#6/3 3:D6/3 6:A5/2 8:D6/4 12:A5/4", "2:G#5/2 4:B5/2 6:E6/6 12:D6/2 14:B5/2",
      "0:A5/4 4:C#6/4 8:E6/2 10:C#6/2 12:A5/4", "0:A5/3 3:F#5/3 6:D5/2 8:D#5/4 12:G#5/4"],
     ['D', 'E', 'F#m', T1, 'D', 'E', 'F#m', T2], 'dev'),
    # 5 el tema vuelve, cambiado, con un contracanto por debajo
    (["2:C#5/2 4:E5/2 6:F#5/4 10:G#5/2 12:A5/4", "0:G#5/2 2:F#5/2 4:E5/2 6:C#5/6 12:E5/2 14:F#5/2",
      "0:A5/4 4:G#5/2 6:F#5/2 8:C#6/6 14:B5/2", "0:A5/4 4:E5/2 6:C#5/2 8:F#5/4 12:G#5/4",
      "2:C#6/2 4:B5/2 6:A5/4 10:F#5/2 12:A5/4", "0:C#6/2 2:E6/2 4:C#6/8 12:A5/4",
      "2:F#5/2 4:G#5/2 6:A5/2 8:B5/2 10:C#6/6", "0:D6/4 4:A5/2 6:F#5/2 8:B5/4 12:C#6/4"], PLAIN, 'theme2'),
    # 6 carrera hacia el respiro: corcheas que suben por el acorde
    (["0:F#5/2 2:G#5/2 4:A5/2 6:C#6/2 8:F#5/2 10:G#5/2 12:A5/4", "2:A5/2 4:D6/2 6:A5/2 8:F#5/4 12:D5/4",
      "0:E5/2 2:G#5/2 4:B5/2 6:E6/2 8:B5/4 12:G#5/4", "0:C#6/2 2:A5/2 4:E5/2 6:A5/2 8:B5/2 10:D#6/2 12:C#6/4",
      "0:F#6/2 2:E6/2 4:C#6/2 6:A5/2 8:C#6/4 12:F#5/4", "0:D6/2 2:A5/2 4:F#5/2 6:A5/2 8:D6/4 12:A5/4",
      "0:B5/2 2:G#5/2 4:E5/2 6:G#5/2 8:B5/4 12:E6/4", "0:D6/4 4:A5/4 8:F#5/4 12:G#5/4"],
     ['F#m', 'D', 'E', T1, 'F#m', 'D', 'E', T2], 'run'),
    # 7 RESPIRO: sin riff (el bajo se queda en Fa#1), caja de música en notas largas
    (["0:C#6/8 8:A5/8", "0:F#5/8 8:A5/4 12:D6/4", "0:D6/6 6:C#6/2 8:B5/8", "0:G#5/8 8:B5/8",
      "0:A5/6 6:B5/2 8:C#6/8", "0:D6/6 6:E6/2 8:F#6/8", "0:E6/6 6:D6/2 8:B5/8", "0:G#5/4 4:B5/4 8:E6/8"],
     ['F#m', 'D', 'Bm', 'E', 'F#m', 'D', 'E', 'E'], 'breath'),
    # 8 vuelve el riff: melodía cantabile (N163 cálido)
    (["0:F#5/4 4:A5/4 8:C#6/6 14:B5/2", "0:A5/6 6:G#5/2 8:F#5/8", "0:F#5/4 4:A5/4 8:D6/6 14:C#6/2",
      "0:C#6/6 6:B5/2 8:B5/4 12:G#5/4", "0:A5/4 4:C#6/4 8:F#6/6 14:E6/2", "0:D6/4 4:F#6/2 6:E6/2 8:D6/8",
      "0:B5/4 4:G#5/4 8:E5/6 14:F#5/2", "0:A5/4 4:F#5/4 8:F#5/4 12:G#5/4"],
     ['F#m', 'F#m', 'D', T1, 'F#m', 'Bm', 'E', T2], 'cant'),
    # 9 la misma idea, intensificada (más arriba, la sierra dobla)
    (["0:A5/2 2:B5/2 4:C#6/4 8:F#6/6 14:E6/2", "0:C#6/6 6:B5/2 8:A5/6 14:B5/2", "0:A5/4 4:D6/4 8:F#6/6 14:E6/2",
      "0:E6/6 6:C#6/2 8:D#6/4 12:C#6/4", "0:C#6/4 4:F#6/4 8:E6/2 10:F#6/2 12:A6/4", "0:F#6/6 6:E6/2 8:D6/8",
      "0:E6/4 4:B5/4 8:G#5/6 14:A5/2", "0:A5/3 3:D6/3 6:F#6/2 8:F#6/4 12:G#6/4"],
     ['F#m', 'F#m', 'D', T1, 'F#m', 'Bm', 'E', T2], 'cant2'),
    # 10 CLÍMAX: el gancho en 3+3+2
    (["0:C#6/3 3:C#6/3 6:F#6/2 8:E6/3 11:C#6/3 14:A5/2", "0:A5/3 3:A5/3 6:D6/2 8:F#6/4 12:D6/4",
      "0:B5/3 3:B5/3 6:E6/2 8:G#6/4 12:E6/4", "0:E6/3 3:C#6/3 6:A5/2 8:D#6/4 12:C#6/4",
      "0:C#6/3 3:C#6/3 6:F#6/2 8:A6/3 11:G#6/3 14:F#6/2", "0:F#6/3 3:D6/3 6:A5/2 8:D6/4 12:F#6/4",
      "0:E6/3 3:B5/3 6:G#5/2 8:B5/4 12:E6/4", "0:D6/4 4:F#6/4 8:F#6/4 12:G#6/4"],
     ['F#m', 'D', 'E', T1, 'F#m', 'D', 'E', T2], 'climax'),
    # 11 clímax en DIÁLOGO: la melodía deja medio compás y contestan las voces
    (["0:C#6/3 3:C#6/3 6:F#6/2 8:C#6/4", "0:D6/3 3:A5/3 6:F#5/2 8:A5/4", "0:E6/3 3:B5/3 6:G#5/2 8:B5/4",
      "0:C#6/3 3:A5/3 6:E5/2 8:F#5/4 12:G#5/4", "0:F#6/3 3:E6/3 6:C#6/2 8:A5/4", "0:A5/3 3:D6/3 6:F#6/2 8:D6/4",
      "0:G#5/3 3:B5/3 6:E6/2 8:B5/4", "0:A5/4 4:F#5/4 8:B5/4 12:C#6/4"],
     ['F#m', 'D', 'E', T1, 'F#m', 'D', 'E', T2], 'dialog'),
    # 12 puente a MEDIO TIEMPO: notas largas, el N163 cálido
    (["0:B5/6 6:A5/2 8:F#5/8", "0:A5/4 4:D6/4 8:F#6/8", "0:E6/4 4:G#5/2 6:B5/2 8:E6/8", "0:A5/4 4:C#6/4 8:B5/4 12:G#5/4",
      "0:B5/4 4:D6/4 8:F#6/6 14:D6/2", "0:F#6/4 4:E6/2 6:D6/2 8:A5/8", "0:B5/4 4:E6/4 8:G#5/8", "0:D6/4 4:A5/4 8:D#6/4 12:C#6/4"],
     ['Bm', 'D', 'E', T1, 'Bm', 'D', 'E', T2], 'half'),
    # 13 subida: arpegios que trepan
    (["0:F#5/2 2:A5/2 4:C#6/2 6:A5/2 8:F#5/2 10:A5/2 12:C#6/4", "0:G#5/2 2:B5/2 4:E6/2 6:B5/2 8:G#5/2 10:B5/2 12:E6/4",
      "0:A5/2 2:C#6/2 4:F#6/2 6:C#6/2 8:A5/2 10:C#6/2 12:F#6/4", "0:E6/2 2:C#6/2 4:A5/2 6:C#6/2 8:D#6/2 10:F#6/2 12:G#6/4",
      "0:F#6/4 4:C#6/2 6:A5/2 8:F#6/4 12:C#6/4", "0:E6/2 2:C#6/2 4:A5/2 6:C#6/2 8:F#6/4 12:A6/4",
      "0:G#6/2 2:F#6/2 4:E6/2 6:C#6/2 8:F#6/8", "0:F#6/4 4:D6/4 8:D#6/4 12:G#6/4"],
     ['F#m', 'E', 'F#m', T1, 'F#m', 'F#m', 'F#m', T2], 'build'),
    # 14 final con todo: el tema, transformado y arriba
    (["2:C#6/2 4:E6/2 6:F#6/6 14:E6/2", "0:D6/4 6:A5/2 8:F#5/2 10:A5/6", "2:E6/2 4:F#6/2 6:G#6/4 10:E6/2 12:B5/4",
      "0:E6/3 3:A5/3 6:C#6/2 8:D#6/4 12:G#5/4", "2:C#6/2 4:E6/2 6:F#6/4 10:A6/2 12:G#6/2 14:F#6/2",
      "0:F#6/2 2:D6/2 4:B5/8 12:D6/4", "2:A5/2 4:D6/2 6:F#6/2 8:A6/6 14:G#6/2", "0:F#6/4 4:D6/4 8:D#6/4 12:C#6/4"],
     COLOR, 'final'),
    # 15 salida: la melodía se posa y se va; vuelve la apertura (riff + voces)
    (["0:C#6/4 4:A5/4 8:F#5/8", "2:E5/2 4:F#5/2 6:A5/6 12:F#5/4", "0:C#5/8 8:A4/4 12:F#5/4", "0:E5/8 8:D#5/4 12:C#5/4",
      "", "", "", ""], PLAIN, 'out'),
]


def song():
    """→ melodía [(compás, semicorchea, nota, dur)], acordes por compás (3 tramos), papel por compás, bajo"""
    mel, chords, role, bass = [], [], [], []
    for i, (bars, harm, rl) in enumerate(PHRASES):
        base = 8 * i
        mel.extend((base + b, st, n, d) for b, st, n, d in W.PH(*bars))
        for c in harm:
            if isinstance(c, list): chords.append(tuple(ch(x) for x in c))
            else: chords.append((ch(c),) * 3)
        role += [rl] * 8
        if rl == 'breath':                                       # el bajo se queda en su nota
            bass.extend([(base + 1, 0, 30, 30, 70), (base + 3, 0, 30, 30, 66), (base + 5, 0, 30, 30, 70),
                         (base + 7, 0, 30, 24, 76), (base + 8, 12, 37, 2, 90), (base + 8, 14, 37, 2, 96)])
        else:
            bass.extend((base + b, st, n, d) for b, st, n, d in FF.RIFF)
    return sorted(mel), chords, role, bass


def chord_at(chords, b, st):
    c = chords[b - 1]
    return c[0] if st < 8 else (c[1] if st < 12 else c[2])


def check(mel, chords):
    """Notas largas (≥ 4) del acorde que suena; cada nota en la escala o en su acorde (el giro lleva Re# y Mi#)"""
    def tones(b, st):
        r, q = chord_at(chords, b, st)
        return {(r + i) % 12 for i in q}
    bad = [(b, st) for b, st, n, d in mel if d >= 4 and n % 12 not in tones(b, st)]
    out = [(b, st) for b, st, n, d in mel if n % 12 not in SCALE and n % 12 not in tones(b, st)]
    return bad, out


def literal_repeats(mel):
    """Compases de melodía idénticos (notas y ritmo) a otro compás anterior: el tema se compone de corrido"""
    bars = {}
    for b, st, n, d in mel: bars.setdefault(b, []).append((st, n, d))
    seen, rep = {}, []
    for b in sorted(bars):
        k = tuple(sorted(bars[b]))
        if k in seen: rep.append((b, seen[k]))
        else: seen[k] = b
    return rep, len(bars)


# ── INSTRUMENTOS (los de la casa) ─────────────────────────────────────────────────────────────────────────────────
WAVES = [wavetable([1.0, 0.6, 0.4, 0.25, 0.15]),              # 0 metal cálido (N163)
         wavetable([1.0, 0.3, 0.1]),                          # 1 colchón (casi seno)
         GN.CWAVES[0]]                                        # 2 caja de música
I_LP = {'vol': [15, 14, 13, 13, 12, 12], 'sus': 12, 'vib': (12, 0.22, 5.6), 'duty': [0.125, 0.25, 0.5]}   # pulso con barrido
I_HOT = {'vol': [11, 14, 15, 14, 13, 13], 'sus': 13, 'vib': (14, 0.2, 5.5), 'duty': 0.0}                  # N163 cálido
I_SAW = {'vol': [13, 13, 12, 12, 11, 11], 'sus': 11, 'vib': (14, 0.2, 6)}
I_DBL = {'vol': [9, 8, 7, 7, 6, 6], 'sus': 6, 'duty': 0.25}
I_BOX = dict(GN.I_BELL, duty=2.0)
I_ECHO = {'vol': [5, 5, 4, 3], 'sus': 2, 'duty': 0.5}
I_PAD = {'vol': [2, 3, 4, 5, 5, 5], 'sus': 5, 'vib': (24, 0.12, 4.5), 'duty': 1.0}
I_CM = {'vol': [4, 6, 7, 7, 7, 6], 'sus': 6, 'vib': (18, 0.12, 5.0), 'duty': 1.0}
I_PULSE8 = {'vol': [7, 5, 3, 2, 1], 'sus': 0, 'duty': 0.125}
I_SKANK = {'vol': [10, 8, 5, 3, 1], 'sus': 0, 'duty': 0.5}
I_STAB = {'vol': [13, 10, 7, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_SHIM = {'vol': [6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
CRASH_SOFT = [9, 8, 7, 6, 5, 4, 3, 3, 2, 2, 1, 1]
TRES = (0, 6, 12)
LV = {'lp': 0, 'lw': 0, 'ls': -1,  # (el acompañamiento va +5 dB: ver BACKING_UP)
      'dbl': -7, 'echo': -13, 'box': -2, 'pad': -11, 'cm': -9, 'pulses': -13,
      'skank': -10, 'stabs': -8, 'shim': -14, 'bass': 1, 'kick': 0, 'snare': -2, 'hat': -15, 'phat': -12,
      'crash': -7, 'toms': -2, 'nrise': -12, 'vox': -1, 'voxf': -6, 'chop': -2}
# la melodía cambia de timbre por secciones (3 grupos que no suenan a la vez): el resto sube para que la melodía quede
# en el ~15 % de la energía (regla de la casa: BACKING de worlds_nes.py)
BACKING_UP = 5.0
LUFS = -10.0
LEAD_OF = {'theme': 'lp', 'answer': 'lp', 'dev': 'lp', 'theme2': 'lp', 'run': 'lp', 'breath': 'box', 'cant': 'lw',
           'cant2': 'lw', 'climax': 'ls', 'dialog': 'ls', 'half': 'lw', 'build': 'lp', 'final': 'ls', 'out': 'lw'}
# cuánto lleva cada papel (la canción crece por capas): pulsos, golpes, contratiempo, arpegio, contracanto, colchón
LAYERS = {'open': 'p', 'theme': 'p', 'answer': 'pk', 'dev': 'pkd', 'theme2': 'pkdc', 'run': 'pkdsa', 'breath': 'c',
          'cant': 'pc', 'cant2': 'pkdc', 'climax': 'psda', 'dialog': 'psda', 'half': 'pc', 'build': 'pda',
          'final': 'psdac', 'out': 'p'}


def build():
    mel, chords, role, bass = song()
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    keys = ('lp', 'lw', 'ls', 'dbl', 'echo', 'box', 'pad1', 'pad2', 'cm', 'pulses', 'sk1', 'sk2', 'c1', 'c2', 'shim')
    Cn = {k: Chan(NF) for k in keys}
    NZ = {k: Noise(NF) for k in ('hat', 'phat', 'snare', 'crash', 'nrise')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16
    rl = lambda b: role[b - 1]
    k8 = lambda b: (b - 1) % 8 + 1                                         # compás dentro de su frase

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # ── MELODÍA ──
    for b, st, n, d in mel:
        r_ = rl(b); t0 = tv(b, st); lead = LEAD_OF[r_]
        if lead == 'box':
            play(Cn['box'], t0, t0 + d * S16, n, I_BOX, q=q_n163, release=6)
            play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 4) * S16, n, I_ECHO, vs=0.7, release=2); continue
        if lead == 'lp':
            play(Cn['lp'], t0, t0 + d * S16 * 0.93, n, I_LP, release=3)
        elif lead == 'lw':
            play(Cn['lw'], t0, t0 + d * S16 * 0.95, n, I_HOT, q=q_n163, release=4)
        else:                                                              # la sierra (una octava abajo: cuerpo) + el pulso
            play(Cn['ls'], t0, t0 + d * S16 * 0.93, n - 12, I_SAW, q=q_saw, release=3)
            play(Cn['lp'], t0, t0 + d * S16 * 0.93, n, I_LP, vs=0.8, release=3)
        if r_ in ('cant2', 'climax', 'dialog', 'final', 'answer'):        # doblada a la octava cuando hay más fuerza
            play(Cn['dbl'], t0, t0 + d * S16 * 0.9, n + 12 if n < 86 else n, I_DBL, release=2)
        if d >= 3: play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 3) * S16 * 0.8, n, I_ECHO, release=1)

    # ── ACOMPAÑAMIENTO ──
    for b in range(1, NB + 1):
        r_, k = rl(b), k8(b); L = LAYERS[r_]
        if r_ == 'run' and k >= 7: L = L.replace('s', '').replace('a', '').replace('k', '')   # (se vacía antes del respiro)
        if r_ == 'breath' and k <= 2:                                      # (y los pulsos se van apagando dentro de él)
            for st in range(0, 16, 2):
                r, q = chord_at(chords, b, st)
                play(Cn['pulses'], tv(b, st), tv(b, st) + S16, 78 + (r - 78) % 12 + (q[2] if st % 4 == 0 else q[1]), I_PULSE8, vs=(0.6, 0.35)[k - 1], release=0)
        if 'p' in L:                                                       # pulsos de fondo en corcheas
            vs = 0.4 + 0.075 * (k - 1) if r_ == 'open' and b <= 8 else (1.0 - 0.1 * (k - 1) if r_ == 'out' else 1.0)
            for st in range(0, 16, 2):
                r, q = chord_at(chords, b, st)
                play(Cn['pulses'], tv(b, st), tv(b, st) + S16, 78 + (r - 78) % 12 + (q[2] if st % 4 == 0 else q[1]), I_PULSE8, vs=max(0.3, vs), release=0)
        if 'c' in L:                                                       # colchón: el acorde de arriba, tenido
            for half, st in enumerate((0, 8)):
                r, q = chord_at(chords, b, st)
                for j, iv in enumerate(q[1:]):
                    play(Cn[('pad1', 'pad2')[j]], tv(b, st), tv(b, st) + 7.8 * S16, 64 + (r - 64) % 12 + iv, I_PAD, q=q_n163, release=4)
        if 'k' in L:                                                       # acordes a contratiempo
            for st in (2, 6, 10, 14):
                r, q = chord_at(chords, b, st)
                for j, iv in enumerate(q[1:]):
                    play(Cn[('sk1', 'sk2')[j]], tv(b, st), tv(b, st) + 1.5 * S16, 66 + (r - 66) % 12 + iv, I_SKANK, release=1)
        if 's' in L:                                                       # golpes de quinta en el tresillo
            for st in TRES:
                r, q = chord_at(chords, b, st)
                root = 54 + (r - 54) % 12
                play(Cn['c1'], tv(b, st), tv(b, st) + 2.5 * S16, root, I_STAB, release=2)
                play(Cn['c2'], tv(b, st), tv(b, st) + 2.5 * S16, root + 7, I_STAB, release=2)
        if 'a' in L:                                                       # arpegio brillante en semicorcheas
            for st in range(16):
                r, q = chord_at(chords, b, st)
                play(Cn['shim'], tv(b, st), tv(b, st) + S16 * 0.7, 78 + (r - 78) % 12 + (q + (12,))[st % 4], I_SHIM, release=0)
        if 'd' in L or r_ == 'theme2':                                     # contracanto, por debajo de la melodía
            if r_ in ('theme2', 'cant2', 'final'):
                for half, st in enumerate((0, 8)):
                    r, q = chord_at(chords, b, st)
                    play(Cn['cm'], tv(b, st), tv(b, st) + 7.5 * S16, 60 + (r - 60) % 12 + (q[1] if half == 0 else q[2]), I_CM, q=q_n163, release=4)

    # ── BATERÍA ──
    for b in range(1, NB + 1):
        r_, k = rl(b), k8(b)
        nxt = role[b] if b < NB else 'open'
        last = k == 8
        for st in range(16):
            t = tv(b, st)
            if r_ == 'breath':                                             # respiro: casi nada; vuelve al final
                if k <= 2 and st == 0: hit(kick, TN.KICK_DEEP, t, (0.6, 0.4)[k - 1])
                if k >= 5 and st in (0, 8): hit(kick, TN.KICK_DEEP, t, 0.5 + 0.08 * (k - 5))
                if k >= 7 and st % 4 == 2: NZ['phat'].hit(t, 1, [3, 2, 1])
                if k == 8 and st >= 8: snare(t, 0.3 + (st - 8) * 0.07, [5 + (st - 8), 4, 2])
                continue
            if r_ == 'open' or r_ == 'out':                                # apertura / salida: bombo, charles; caja al final
                if st in (0, 8): hit(kick, TN.KICK, t, 0.9)
                if st % 4 == 2: NZ['phat'].hit(t, 1, [5, 3, 1])
                if (r_ == 'open' and k >= 5 or r_ == 'out' and k <= 4) and st in (4, 12): snare(t, 0.7, [10, 6, 3, 1])
                if r_ == 'open' and k == 8 and st >= 8: snare(t, 0.3 + (st - 8) * 0.07, [6 + (st - 8), 4, 2])
                if st == 0 and r_ == 'open' and k == 1: NZ['crash'].hit(t, 3, CRASH_SOFT)
                continue
            if r_ == 'half':                                               # medio tiempo
                if st == 0 or (st == 10 and k % 2 == 0): hit(kick, TN.KICK_DEEP, t, 1.0)
                if st == 8: snare(t, 0.9)
                if st % 4 == 2: NZ['phat'].hit(t, 1, [5, 3, 2, 1])
                if st == 0 and k == 1: NZ['crash'].hit(t, 3, CRASH_SOFT)
                if last and st >= 12: snare(t, 0.4 + (st - 12) * 0.1, [7 + (st - 12), 4, 2])
                continue
            if r_ == 'build':                                              # subida: la caja se apura
                if st % 4 == 0: hit(kick, TN.KICK_DEEP, t, 1.0)
                step = 4 if k <= 2 else (2 if k <= 5 else 1)
                if st % step == 0: snare(t, 0.3 + 0.06 * k + 0.015 * st, [6 + k // 2 + st // 5, 4, 2])
                if k == 8 and st >= 8: hit(tom, W.TOMS[(st - 8) // 3 % 3], t, 0.7)
                if k == 1 and st == 0: NZ['crash'].hit(t, 3, CRASH_SOFT)
                continue
            if r_ == 'run' and k >= 7:                                     # carrera → respiro: la batería se retira
                if st in (0, 8): hit(kick, TN.KICK, t, 0.8 if k == 7 else 0.6)
                if st in (4, 12): snare(t, 0.6 if k == 7 else 0.4, [9, 5, 2] if k == 7 else [7, 4, 1])
                if k == 7 and st % 4 == 2: NZ['phat'].hit(t, 1, [4, 2, 1])
                continue
            # el surco: bombo en 1 y 3 (y en el tresillo en el clímax), caja en 2 y 4, charles muy suave
            big = r_ in ('climax', 'dialog', 'final')
            if st in (0, 8) or (big and st in (6, 14)): hit(kick, TN.KICK_DEEP if big else TN.KICK, t, 1.0)
            if st in (4, 12) and not (r_ == 'theme' and k <= 4): snare(t, 1.0)
            elif st in (7, 15) and big: snare(t, 0.3, [6, 3, 1])
            if st % 4 == 2: NZ['phat'].hit(t, 1, [6, 4, 2, 1])
            elif st % 2 == 1: NZ['hat'].hit(t, 1, [3, 1])
            if big and st in (3, 14) and b % 2 == 0: hit(tom, W.TOMS[{3: 2, 14: 1}[st]], t, 0.8)
            # transiciones: redoble de timbales que baja (suave hacia el respiro y el medio tiempo)
            if last and st >= 12:
                soft = nxt in ('breath', 'half', 'out')
                hit(tom, W.TOMS[min(2, st - 12)], t, 0.5 if soft else 0.75)
                if st >= 14 and not soft: snare(t, 0.45 + (st - 14) * 0.15, [8 + (st - 14), 5, 2])
            if st == 0:
                if k == 1 and r_ in ('answer', 'cant', 'climax', 'final', 'dev'): NZ['crash'].hit(t, 3, CRASH)
                elif k == 1: NZ['crash'].hit(t, 3, CRASH_SOFT)
                elif big and k % 2 == 1: NZ['crash'].hit(t, 3, CRASH if r_ != 'dialog' else CRASH_SOFT)
        if r_ == 'build' and k == 7:                                       # el soplido de ruido antes del final
            nf = int(2 * BAR * F.FPS)
            NZ['nrise'].hit(tv(b, 0), [int(12 - 9 * i / nf) for i in range(nf)], [int(1 + 9 * i / nf) for i in range(nf)])

    # ── STEMS ──
    n = int(NB * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k: cut(F.pulse_dac(F.render_pulse(Cn[k])))
    wave = lambda k: cut(F.render_wave(Cn[k], WAVES) * 0.0075)
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    noise = lambda k: cut(F.tnd_dac(NZ[k].render() / 22638.0 * 12))
    S = {
        'lp': pulse('lp'), 'lw': wave('lw'), 'ls': cut(F.pulse_dac(F.render_saw(Cn['ls']))), 'dbl': pulse('dbl'),
        'echo': pulse('echo'), 'box': wave('box'), 'pad': wave('pad1') + wave('pad2'), 'cm': wave('cm'),
        'pulses': pulse('pulses'), 'skank': pulse('sk1') + pulse('sk2'), 'stabs': pulse('c1') + pulse('c2'),
        'shim': pulse('shim'),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + noise('snare'),
        'hat': noise('hat'), 'phat': noise('phat'), 'crash': noise('crash'), 'nrise': noise('nrise'),
    }
    # el bajo "real" y las voces (muestras de audio)
    import soundfile as sf
    from scipy.signal import butter, sosfilt
    yb = FF.render_bass(bass)
    S['bass'] = np.zeros(n + tail); S['bass'][:min(len(yb), n + tail)] = yb[:n + tail]
    v, vsr = sf.read(FF.VOX)
    v = v.mean(1) if v.ndim == 2 else v
    assert vsr == SR
    vb = lambda b0, b1: v[int(b0 * BAR * SR):int(b1 * BAR * SR)].copy()
    def place(dst, seg, b, fade=0.02):
        k_ = int(fade * SR); seg = seg.copy(); seg[:k_] *= np.linspace(0, 1, k_); seg[-k_:] *= np.linspace(1, 0, k_)
        i = int(tv(b, 0) * SR); dst[i:i + len(seg)] += seg[:len(dst) - i]
    S['vox'] = np.zeros(n + tail); S['voxf'] = np.zeros(n + tail); S['chop'] = np.zeros(n + tail)
    place(S['vox'], vb(0, 8), 1)                                           # apertura: la 1ª mitad del bloque de voces
    place(S['vox'], vb(8, 16), NB - 7)                                     # salida: la 2ª mitad (cruza la costura seguida)
    lp_ = butter(2, 1400, btype='low', fs=SR, output='sos')
    place(S['voxf'], sosfilt(lp_, vb(0, 8)), 48 + 1, fade=0.3)             # respiro: las voces, lejos (filtradas)
    chops = [vb(2 * i, 2 * i + 1) for i in range(8)]                      # un compás de canto por cada compás par
    ci = 0
    for b in range(9, NB - 8):                                             # cortes al final de las frases que empujan
        r_, k = rl(b), k8(b)
        if k == 8 and r_ in ('theme', 'answer', 'dev', 'theme2', 'cant2', 'climax', 'final'):
            place(S['chop'], chops[ci % 8], b); ci += 1
        if r_ == 'dialog' and k in (1, 2, 3, 5, 6, 7):                    # el diálogo: contestan en el medio compás libre
            seg = chops[ci % 8][:int(BAR * SR / 2)].copy()
            k_ = int(0.01 * SR); seg[:k_] *= np.linspace(0, 1, k_); seg[-k_:] *= np.linspace(1, 0, k_)
            i1 = int(tv(b, 8) * SR); S['chop'][i1:i1 + len(seg)] += seg; ci += 1
    S = {k: GN.fold(x, n, 0) for k, x in S.items() if np.abs(x).max() > 0}     # bucle sin costura
    lead_ref = 'lp'
    g = GN.level(S, {k: LV.get(k, -10) + (BACKING_UP if k not in ('lp', 'lw', 'ls', 'box', 'dbl', 'echo') else 0) for k in S}, lead_ref)
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('pulses', 0.4) - sd('echo', 0.6) + sd('skank', 0.3) + sd('stabs', 0.25) + sd('shim', 0.4) - sd('pad', 0.25) \
        + sd('hat', 0.3) - sd('phat', 0.2) + sd('box', 0.2) - sd('cm', 0.25)
    y = F.master(np.stack([x + side, x - side], 1), lufs=LUFS)
    GN.report(NAME, y, S, g, n)
    bad, out = check(mel, chords)
    rep, nb_ = literal_repeats(mel)
    iv = np.abs(np.diff([m[2] for m in mel]))
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    print(f'  {BPM} BPM, {NB} compases ({NB * BAR:.1f} s, un bucle); melodía {len(mel)} notas en {nb_} compases; '
          f'batería {grp(("kick", "snare", "hat", "phat", "crash", "toms", "nrise")):.0f} %, bajo {grp(("bass",)):.0f} %, '
          f'melodía {grp(("lp", "lw", "ls", "box", "dbl")):.0f} %, voces {grp(("vox", "voxf", "chop")):.1f} %')
    print(f'  notas largas fuera del acorde: {bad or "ninguna"} · fuera de escala y acorde: {out or "ninguna"}')
    print(f'  compases repetidos literalmente: {len(rep)} de {nb_} {rep[:8] or ""} · intervalo medio {iv.mean():.2f} st, '
          f'grados {np.mean(iv <= 2) * 100:.0f} %, saltos de octava {np.mean(iv >= 12) * 100:.0f} %, '
          f'notas a contratiempo {np.mean([m[1] % 4 != 0 for m in mel]) * 100:.0f} %')
    return y, mel


def preview(y):
    os.makedirs(PREVIEW, exist_ok=True)
    def enc(x, name):
        wav = os.path.join(PREVIEW, name + '.wav'); ogg = wav[:-4] + '.ogg'
        F.write_wav(wav, x)
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"'); os.remove(wav)
    enc(y, NAME)
    k = int(8 * BAR * SR)
    enc(np.concatenate([y[-k:], y[:k]]), NAME + '_costura')
    print(f'  previas en {PREVIEW}')


if __name__ == '__main__':
    y, mel = build()
    if not os.environ.get('REPORT'):
        preview(y)
        if os.environ.get('INSTALL'):
            GN.export(NAME, y, 0)
            W.write_mid(F.out(NAME, 'mid'), mel, BPM)
