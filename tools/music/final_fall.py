#!/usr/bin/env python3
# FINAL FALL — tema de jefe propio, como se hizo con Tentacle Tantrum (Crab Tantrum) y Winter Fallympics.
#
# De "Final Fall" (Fall Guys; la transcripción 1:1 corregida del usuario) se toman MUESTRAS:
#   1. el RIFF DEL BAJO de la parte donde el bajo lleva la canción (Fa#1 con su octava "pop" y la cola sincopada,
#      tres compases, y el giro La–Si–Do# / Re–Si–Do#). Es lo único que NO suena a Famicom: el usuario quiere un bajo
#      "real" (Slap Bass General MIDI de TimGM6mb, renderizado con fluidsynth y mezclado como un grupo más).
#   2. el MOTIVO principal (Do#–Fa#–Fa#·Mi–Do# | Re Mi Si · La Sol# Mi, y su variante que sube).
#   3. la LLAMADA del verso (Do# · Si La~ | Si~, y el motivo detrás: 4 compases de pregunta y respuesta).
#   4. la sección D del original (el motivo armonizado en terceras/sextas sobre La mayor, acordes de flauta y su bajo
#      Re–Mi–Fa#–Si–Do# / La–Mi).
#   5. el GRAN SOLO del final del original (la llamada en notas largas con vibrato y el motivo): el clímax.
#   6. la INTRO de Final Fall, acortada a 8 compases, con las VOCES del original pasadas por un crunch de 8 bits
#      (famicom.ref('final_fall_vocals_crunch.wav'), fuera del repo), y el bajo de su sección B (Fa#1 · Mi1 · Re1).
# Lo nuevo: la sección B (melodía con las células del motivo — cabeza en 3+3+2, salto de cuarta, su bajada — que
# cita "la llamada" del juego Do#–Fa#–La–Do#), la PREPARACIÓN antes del clímax, los arreglos, la batería y las
# TRANSICIONES (el usuario: "a veces se siente brusco"): anacrusas del bajo, capas que entran o salen un compás antes,
# el motivo anunciado en el eco antes de llegar, redobles de timbal en vez de cortes, medio compás vacío antes de la
# sección D, y platos fuertes solo en las llegadas grandes.
#
# Forma (181 BPM como el original, Fa# menor; la intro en Fa# mayor como en el original):
#   INTRO 8 · RIFF 16 · MOTIVO 16 · VERSO 16 · B 16 · D 8 · PREPARACIÓN 8 · CLÍMAX 16 · SALIDA 8 = 112 compases.
# Como el original, el bucle INCLUYE la intro: tras el último giro (Do#, la dominante) vuelve a la intro. Un archivo.
#
#   python tools/music/final_fall.py          → assets/music/bosses/final_fall.ogg (+ previa en FlappyMonster_pruebas)
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys, subprocess, tempfile
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_tri, q_saw, q_n163, q_vrc6
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W

BPM = 181
S16 = 60.0 / BPM / 4
BAR = 16 * S16
NAME = 'final_fall'
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/musica/final_fall'
SF_GM = '/home/mtvemo/.venvs/fm-music/lib/python3.11/site-packages/pretty_midi/TimGM6mb.sf2'
VOX = F.ref('final_fall_vocals_crunch.wav')

N = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
MAJ, MIN = (0, 4, 7), (0, 3, 7)
SCALE = {6, 8, 9, 11, 1, 2, 4}                    # Fa# menor natural


def ch(s):
    return (N[s[:-1]], MIN) if s.endswith('m') else (N[s], MAJ)


def nt(s):                                        # 'C#5' → 73
    return 12 * (int(s[-1]) + 1) + N[s[:-1]]


def ph(*bars):                                    # frases como texto: "0:C#5/2 10:B4/2" por compás
    return W.PH(*bars)


# ── MUESTRAS ─────────────────────────────────────────────────────────────────────────────────────────────────────
# El riff del bajo (compás 1-8, semicorchea, nota MIDI, duración): dos vueltas de 4, la 1ª gira por La, la 2ª por Re
RIFF = [(1, 0, 30, 2), (1, 2, 42, 2), (1, 8, 30, 2), (1, 10, 30, 1), (1, 11, 30, 2), (1, 13, 30, 2), (1, 15, 30, 1),
        (2, 0, 30, 2), (2, 2, 42, 2), (2, 8, 30, 2), (2, 10, 30, 1), (2, 11, 30, 2), (2, 13, 30, 2), (2, 15, 30, 1),
        (3, 0, 30, 2), (3, 2, 42, 2), (3, 8, 30, 2), (3, 10, 30, 1), (3, 11, 30, 2), (3, 13, 30, 2), (3, 15, 30, 1),
        (4, 0, 33, 3), (4, 3, 45, 3), (4, 6, 33, 2), (4, 8, 35, 2), (4, 10, 35, 2), (4, 12, 37, 2), (4, 14, 37, 2),
        (5, 0, 30, 2), (5, 2, 42, 2), (5, 8, 30, 2), (5, 10, 30, 1), (5, 11, 30, 2), (5, 13, 30, 2), (5, 15, 30, 1),
        (6, 0, 30, 2), (6, 2, 42, 2), (6, 8, 30, 2), (6, 10, 30, 1), (6, 11, 30, 2), (6, 13, 30, 2), (6, 15, 30, 1),
        (7, 0, 30, 2), (7, 2, 42, 2), (7, 8, 30, 2), (7, 10, 30, 1), (7, 11, 30, 2), (7, 13, 30, 2), (7, 15, 30, 1),
        (8, 0, 26, 3), (8, 3, 38, 3), (8, 6, 26, 2), (8, 8, 35, 2), (8, 10, 47, 1), (8, 12, 37, 2), (8, 14, 37, 2)]
CH_RIFF = ['F#m', 'F#m', 'F#m', ['A', 'B', 'C#'], 'F#m', 'F#m', 'F#m', ['D', 'B', 'C#']]   # (3 acordes: 8+4+4 semicorcheas)
# El bajo de la sección B del original (Fa#1 · Mi1 · Re1 · Mi1, sostenidos): verso y B nueva
BASS_V = [(1, 0, 30, 4), (1, 10, 28, 4), (1, 14, 26, 8), (2, 6, 28, 10), (3, 0, 30, 2), (3, 4, 30, 3), (3, 10, 28, 4),
          (3, 14, 26, 8), (4, 6, 28, 10)]
BASS_V = BASS_V + [(b + 4, st, n, d) for b, st, n, d in BASS_V]
CH_V = [['F#m', 'E', 'D'], ['D', 'E', 'E']] * 4                    # (como el bajo: Fa# · Mi en el 3,5 · Re en el 4,5)
# El bajo de la sección D del original (Re · Re-Mi · Fa# · Fa#-Si-Do# · La · La-Mi · Mi · Mi-Si-Do#)
BASS_D = [(1, 0, 26, 2), (1, 2, 38, 2), (1, 8, 26, 2), (1, 10, 26, 1), (1, 11, 26, 2), (1, 13, 26, 2), (1, 15, 26, 1),
          (2, 0, 26, 2), (2, 2, 38, 2), (2, 8, 28, 2), (2, 10, 28, 1), (2, 11, 28, 2), (2, 13, 28, 2), (2, 15, 28, 1),
          (3, 0, 30, 2), (3, 2, 42, 2), (3, 8, 30, 2), (3, 10, 30, 1), (3, 11, 30, 2), (3, 13, 30, 2), (3, 15, 30, 1),
          (4, 0, 30, 2), (4, 2, 30, 1), (4, 3, 42, 1), (4, 4, 30, 2), (4, 6, 30, 1), (4, 7, 30, 1), (4, 8, 35, 2),
          (4, 10, 47, 1), (4, 11, 47, 1), (4, 12, 37, 4),
          (5, 0, 33, 2), (5, 2, 45, 2), (5, 8, 33, 2), (5, 10, 33, 1), (5, 11, 33, 2), (5, 13, 33, 2), (5, 15, 33, 1),
          (6, 0, 33, 2), (6, 2, 45, 2), (6, 8, 33, 2), (6, 10, 28, 1), (6, 11, 28, 2), (6, 13, 28, 2), (6, 15, 33, 1),
          (7, 0, 28, 1), (7, 2, 40, 2), (7, 8, 28, 2), (7, 10, 28, 1), (7, 11, 28, 2), (7, 13, 28, 2), (7, 15, 28, 1),
          (8, 0, 28, 2), (8, 2, 28, 1), (8, 3, 40, 1), (8, 4, 28, 2), (8, 6, 28, 1), (8, 7, 35, 1), (8, 8, 35, 2),
          (8, 10, 35, 1), (8, 11, 35, 1), (8, 12, 37, 4)]
CH_D = ['D', ['D', 'E', 'E'], 'F#m', ['F#m', 'B', 'C#'], 'A', ['A', 'E', 'E'], 'E', ['E', 'B', 'C#']]
# El MOTIVO (una octava arriba de como lo escribe la transcripción: aquí lo canta el chip)
MOT1 = "0:C#5/2 4:F#4/2 8:F#5/2 10:E5/2 14:C#5/2"
MOT2 = "2:D5/2 4:E5/2 6:B4/2 10:A4/2 12:G#4/2 14:E4/2"
MOT2V = "2:D5/2 4:E5/2 6:A5/2 10:G#5/2 12:E5/2 14:B4/2"            # la variante que sube
MOTIF8 = ph(MOT1, MOT2, MOT1, MOT2, MOT1, MOT2, MOT1, MOT2V)        # 8 compases como en el original
# La LLAMADA del verso (Do# · Si La~ | Si~) + el motivo: 4 compases; el gran solo la canta en notas largas
CALL = ("0:C#5/2 10:B4/2 14:A4/8", "6:B4/10")
CALL_BIG = ("0:C#5/4 10:B4/4 14:A4/6", "6:B4/8")
VERSE8 = ph(*CALL, MOT1, MOT2, *CALL, MOT1, MOT2V)
BIG8 = ph(*CALL_BIG, MOT1, MOT2, *CALL_BIG, MOT1, MOT2V)
# La sección D del original: el motivo en dos voces (arriba = melodía, abajo = 'harm') y la flauta en negras
D_TOP = ph("0:C#5/2 4:F#4/2 8:F#5/2 10:E5/2 14:C#5/2", "2:D5/2 4:E5/2 6:B4/2 10:A4/2 12:G#4/2 14:E4/2", "0:C#5/14",
           "0:B4/14", "0:C#5/2 4:F#4/2 8:F#5/2 10:E5/2 14:C#5/2", "2:D5/2 4:E5/2 6:A5/2 10:G#5/2 12:E5/2 14:G#5/2",
           "0:A5/14", "0:G#5/14")
D_LOW = ph("0:A4/2 4:D4/2 8:C#5/2 10:C#5/2 14:A4/2", "2:A4/2 4:G#4/2 6:F#4/2 10:F#4/2 12:E4/2 14:A3/2", "0:A4/14",
           "0:G#4/14", "0:A4/2 4:D4/2 8:C#5/2 10:C#5/2 14:A4/2", "2:A4/2 4:G#4/2 6:E5/2 10:E5/2 12:C#5/2 14:E5/2",
           "0:E5/14", "0:E5/14")
D_FLUTE = [['C#5'], ['C#5', 'C#5', 'G#5', 'G#5'], ['A4', 'C#5'], ['G#4', 'B4'], ['C#5'], ['C#5', 'C#5', 'F#5', 'F#5'],
           ['B4', 'A5'], ['C#5', 'G#5']]                           # (una lista de 4 = una nota por negra)
# La sección B (NUEVA): las células del motivo sobre el bajo del verso; el 7º compás es "la llamada" del juego
PH_B = ph("0:C#5/3 3:F#4/3 6:F#5/2 8:E5/2 10:B4/2 12:A4/4",
          "0:D5/2 2:E5/2 4:F#5/4 8:E5/3 11:B4/3 14:G#4/2",
          "0:A4/3 3:C#5/3 6:F#5/2 8:G#5/4 12:F#5/4",
          "0:F#5/4 4:E5/2 6:D5/2 8:E5/8",
          "0:E5/3 3:A4/3 6:A5/2 8:G#5/2 10:E5/2 12:F#5/4",
          "0:F#5/2 2:G#5/2 4:A5/4 8:G#5/3 11:E5/3 14:B4/2",
          "0:C#5/2 2:F#5/2 4:A5/2 6:C#6/6 12:B5/2 14:A5/2",
          "0:A5/4 4:F#5/4 8:G#5/4 12:E5/4")
# ── LA INTRO de Final Fall, en 8 compases (el original tiene 16: se queda el ostinato y la batería que crece) ──
PL_A = ['A#', 'A#', 'A#', 'F#', 'A#', 'A#', 'F#', 'A#', 'A#', 'F#', 'A#', 'A#', 'G#', 'G#', 'E', 'G#']   # compases impares
PL_B = ['F#', 'F#', 'F#', 'D', 'F#', 'F#', 'D', 'F#', 'F#', 'D', 'F#', 'F#', 'G#', 'G#', 'E', 'G#']     # compases pares
RISERS = {2: 0, 4: 12, 6: 12, 8: 12}                              # compás → octava de la subida Fa#-Sol#-La#-Do#
HOLDS = {3: ['C#4', 'F#4'], 5: ['C#5', 'F#5'], 7: ['A#4', 'C#5', 'F#5']}
CH_I = [['F#', 'F#', 'E'], ['D', 'D', 'E']] * 4

SECTIONS = [('I', 8), ('R', 16), ('M', 16), ('V', 16), ('B', 16), ('D', 8), ('P', 8), ('C', 16), ('O', 8)]
LEN = dict(SECTIONS)


def song():
    """→ melodía [(compás, semicorchea, nota, dur, voz)], acordes por compás (3 tramos: 8+4+4), etiqueta por compás,
    compás donde empieza cada sección, bajo [(compás, semicorchea, nota, dur)]"""
    mel, chords, tag, starts, bass = [], [], [], {}, []

    def chs(cs):
        for c in cs:
            if isinstance(c, list):
                c3 = c if len(c) == 3 else [c[0], c[1], c[1]]
                chords.append(tuple(ch(x) for x in c3))
            else:
                chords.append((ch(c),) * 3)

    def add(base, phr, voice='lead', reps=1, nb=8):
        for k in range(reps): mel.extend((base + nb * k + b, st, n, d, voice) for b, st, n, d in phr)

    def addb(base, line, reps=1, nb=8):
        for k in range(reps): bass.extend((base + nb * k + b, st, n, d) for b, st, n, d in line)
    for kind, nb in SECTIONS:
        base = len(chords)
        starts[kind] = base + 1
        tag += [kind] * nb
        if kind == 'I':
            chs(CH_I)
            bass.append((base + 8, 12, 37, 2)); bass.append((base + 8, 14, 37, 2))       # anacrusa: el giro, en Do#
        elif kind in ('R', 'M', 'P', 'C', 'O'):
            chs((CH_RIFF * 2)[:nb]); addb(base, RIFF, reps=nb // 8)
            if kind == 'M': add(base, MOTIF8, reps=2)
            if kind == 'O': add(base, MOTIF8)
            if kind == 'P': add(base, ph(*CALL_BIG, *CALL_BIG), voice='call', nb=4)       # la llamada, sola
            if kind == 'C':
                add(base, BIG8, reps=2)
                # el motivo, de RESPUESTA en los compases de la llamada (donde el solo sostiene)
                ans = ph(MOT1, MOT2, '', '', MOT1, MOT2V, '', '')
                add(base, [(b, st, n + 12, d) for b, st, n, d in ans], voice='koto', reps=2)
        elif kind in ('V', 'B'):
            chs(CH_V * 2); addb(base, BASS_V, reps=2)
            add(base, VERSE8 if kind == 'V' else PH_B, reps=2)
        elif kind == 'D':
            chs(CH_D); addb(base, BASS_D)
            add(base, D_TOP); add(base, D_LOW, voice='harm')
    mel.sort()
    return mel, chords, tag, starts, bass


def chord_at(chords, b, st):
    c = chords[b - 1]
    return c[0] if st < 8 else (c[1] if st < 12 else c[2])


def check(mel, chords, tag):
    """Reglas de la casa para lo NUEVO (sección B): notas largas (≥ 4) del acorde; todo en la escala"""
    bad = [(b, st) for b, st, n, d, v in mel if tag[b - 1] == 'B' and d >= 4
           and (n - chord_at(chords, b, st)[0]) % 12 not in chord_at(chords, b, st)[1]]
    out = [(b, st) for b, st, n, d, v in mel if tag[b - 1] == 'B' and n % 12 not in SCALE]
    return bad, out


# ── INSTRUMENTOS (los de la casa: worlds_nes / crab_tantrum / gloomy_nes) ─────────────────────────────────────────
WAVES = [wavetable([1.0, 0.7, 0.35, 0.45, 0.1, 0.2]),        # 0 koto (metálico, brillante)
         wavetable([1.0, 0.3, 0.1])]                          # 1 colchón (casi seno)
I_SAWL = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.18, 6)}
I_SAWBIG = {'vol': [13, 15, 15, 14, 14, 14], 'sus': 14, 'vib': (10, 0.32, 5.6)}            # el gran solo: vibrato ancho
I_PUL = {'vol': [11, 10, 9, 8, 8, 7], 'sus': 7, 'duty': [0.125, 0.25]}
I_HARM = {'vol': [10, 9, 8, 7, 7, 6], 'sus': 6, 'duty': 0.25}
I_CALL = {'vol': [6, 9, 11, 12, 12, 11], 'sus': 11, 'vib': (16, 0.25, 5.2), 'duty': 1.0}   # la llamada en el colchón
I_KOTO = {'vol': [15, 13, 11, 9, 8, 7, 6, 5, 4, 3, 2, 1], 'sus': 0, 'duty': 0.0, 'vib': (10, 0.12, 6)}
I_ECHO = {'vol': [5, 5, 4, 3], 'sus': 2, 'duty': 0.5}
I_PLUCK = {'vol': [12, 9, 6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_RISE = {'vol': [13, 12, 11, 10], 'sus': 10}
I_HOLD = {'vol': [6, 8, 9, 9, 8, 8], 'sus': 8, 'vib': (20, 0.15, 5.0), 'duty': 0.25}
I_DRONE = {'vol': [3, 5, 6, 7, 7, 7], 'sus': 7, 'duty': 1.0}
I_PULSE8 = {'vol': [7, 5, 3, 2, 1], 'sus': 0, 'duty': 0.125}      # los "pulsos" de fondo (corcheas)
I_STAB = {'vol': [13, 10, 7, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_FLUTE = {'vol': [5, 8, 9, 9, 8, 8], 'sus': 8, 'vib': (12, 0.2, 5.2), 'duty': 1.0}
I_CM = {'vol': [4, 6, 7, 7, 7, 6], 'sus': 6, 'vib': (18, 0.12, 5.0), 'duty': 1.0}       # contracanto (colchón)
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
CRASH_SOFT = [9, 8, 7, 6, 5, 4, 3, 3, 2, 2, 1, 1]
TRES = (0, 6, 12)
LV = {'lead': 0, 'dbl': -6, 'echo': -13, 'harm': -4, 'call': -2, 'koto': -7, 'pluck': -4, 'rise': -6, 'hold': -9,
      'drone': -12, 'pulses': -13, 'stabs': -7, 'flute': -9, 'cm': -10, 'bass': 3, 'kick': 3, 'snare': 1, 'hat': -14,
      'phat': -12, 'crash': -7, 'toms': -1, 'nrise': -12, 'vox': -2, 'chop': -4}
LUFS = -10.0


def render_bass(bass):
    """El bajo "real": Slap Bass GM (TimGM6mb) con fluidsynth, a 44,1 kHz mono"""
    import mido, soundfile as sf
    T = 480
    m = mido.MidiFile(type=0, ticks_per_beat=T); tr = mido.MidiTrack(); m.tracks.append(tr)
    tr.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / BPM)))
    tr.append(mido.Message('program_change', channel=0, program=36))
    ev = []
    for b, st, n, d in bass:
        t0 = ((b - 1) * 16 + st) * T // 4
        ev += [(t0, 1, n), (t0 + d * T // 4 - 6, 0, n)]
    t = 0
    for tt, on, n in sorted(ev):
        tr.append(mido.Message('note_on' if on else 'note_off', channel=0, note=n, velocity=100 if on else 0, time=tt - t)); t = tt
    with tempfile.TemporaryDirectory() as d:
        mp, wp = os.path.join(d, 'b.mid'), os.path.join(d, 'b.wav')
        m.save(mp)
        subprocess.run(['fluidsynth', '-ni', '-R', '0', '-C', '0', '-g', '1.0', '-r', str(SR), '-F', wp, SF_GM, mp], capture_output=True)
        y, _ = sf.read(wp)
    return y.mean(1) if y.ndim == 2 else y


def build():
    mel, chords, tag, starts, bass = song()
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    keys = ('lead', 'dbl', 'echo', 'harm', 'call', 'koto', 'pluck', 'rise', 'h1', 'h2', 'h3', 'drone', 'pulses',
            'c1', 'c2', 'fl1', 'fl2', 'cm')
    Cn = {k: Chan(NF) for k in keys}
    NZ = {k: Noise(NF) for k in ('hat', 'phat', 'snare', 'crash', 'nrise')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16
    sec = lambda b: tag[b - 1]
    pos = lambda b: b - starts[sec(b)] + 1                                  # compás dentro de su sección (1…)

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # ── MELODÍA ──
    for b, st, n, d, voice in mel:
        kind, k = sec(b), pos(b)
        t0 = tv(b, st)
        if voice == 'harm':                                                 # (D) la segunda voz, un pulso
            play(Cn['harm'], t0, t0 + d * S16 * 0.93, n, I_HARM, release=2); continue
        if voice == 'call':                                                 # (preparación) la llamada en el colchón, con eco
            play(Cn['call'], t0, t0 + d * S16, n, I_CALL, q=q_n163, release=6)
            play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 4) * S16, n, I_ECHO, release=2); continue
        if voice == 'koto':                                                 # (clímax) el motivo de respuesta
            play(Cn['koto'], t0, t0 + 3 * S16, n, I_KOTO, q=q_n163, release=4); continue
        big = kind == 'C'
        up = kind in ('C', 'O') or (kind in ('M', 'V', 'B') and k > 8)      # la 2ª mitad dobla una octava arriba
        play(Cn['lead'], t0, t0 + d * S16 * 0.93, n - 12, I_SAWBIG if big and d >= 4 else I_SAWL, q=q_saw, release=3)
        play(Cn['dbl'], t0, t0 + d * S16 * 0.93, n + (12 if up else 0), I_PUL, release=2)
        if d >= 3: play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 3) * S16 * 0.8, n, I_ECHO, release=1)

    # el motivo ANUNCIADO en el eco antes de llegar (los dos últimos compases del riff), cada vez más presente
    pre = starts['M'] - 2
    for b, st, n, d in ph(MOT1, MOT2V):
        play(Cn['echo'], tv(pre + b - 1, st), tv(pre + b - 1, st) + d * S16, n, I_ECHO, vs=0.6 + 0.4 * (b - 1), release=1)

    # contracanto: 2ª mitad de la B y el clímax — notas largas del acorde, por DEBAJO de la melodía
    for b in range(1, NB + 1):
        kind, k = sec(b), pos(b)
        if kind == 'C' or (kind == 'B' and k > 8):
            for half, st in enumerate((0, 8)):
                r, q = chord_at(chords, b, st)
                play(Cn['cm'], tv(b, st), tv(b, st) + 7.5 * S16, 60 + (r - 60) % 12 + (q[1] if half == 0 else q[2]), I_CM, q=q_n163, release=4)

    # ── LA INTRO (su ostinato sigue cuatro compases dentro del riff apagándose, y el pedal dos: el paso no es un corte) ──
    for b in list(range(starts['I'], starts['I'] + 8 + 4)):
        k = b - starts['I'] + 1
        fade = 1.0 if sec(b) == 'I' else (0.8, 0.6, 0.4, 0.2)[k - 9]
        pat = PL_A if k % 2 == 1 else PL_B
        for st, p in enumerate(pat):
            play(Cn['pluck'], tv(b, st), tv(b, st) + S16 * 0.8, 60 + N[p] - (12 if N[p] > 7 else 0), I_PLUCK, vs=fade, release=1)
        if k <= 10:
            play(Cn['drone'], tv(b, 0), tv(b, 16) - 0.01, 42, I_DRONE, q=q_n163, vs=fade, release=0)
        if sec(b) != 'I': continue
        if k in RISERS:
            for i, iv in enumerate((0, 2, 4, 7)):
                play(Cn['rise'], tv(b, 12 + i), tv(b, 13 + i), 54 + RISERS[k] + iv, I_RISE, q=q_saw, release=1)
        if k in HOLDS:
            for j, x in enumerate(HOLDS[k]):
                play(Cn[('h1', 'h2', 'h3')[j]], tv(b, 0), tv(b, 0) + 28 * S16, nt(x), I_HOLD, release=6)

    # ── ACOMPAÑAMIENTO por compás ──
    for b in range(1, NB + 1):
        kind, k = sec(b), pos(b)
        if kind == 'I': continue
        # los "pulsos" de fondo: crecen durante el riff (no entran de golpe) y callan en la D
        if kind != 'D':
            vs = min(1.0, 0.25 + 0.075 * (k - 1)) if kind == 'R' else 1.0
            for st in range(0, 16, 2):
                r, q = chord_at(chords, b, st)
                play(Cn['pulses'], tv(b, st), tv(b, st) + S16, 78 + (r - 78) % 12 + (q[2] if st % 4 == 0 else 0), I_PULSE8, vs=vs, release=0)
        # golpes de quinta en el tresillo: desde la 2ª mitad del motivo; fuera en la D y en la 1ª mitad de la preparación;
        # en la salida se van al final (las capas se retiran antes de volver a la intro)
        stabs = (kind == 'M' and k > 8) or kind in ('V', 'B', 'C') or (kind == 'P' and k > 4) or (kind == 'O' and k <= 4)
        if stabs:
            for st in TRES:
                r, q = chord_at(chords, b, st)
                root = 54 + (r - 54) % 12
                vs = 0.6 if (kind == 'P') else 1.0
                play(Cn['c1'], tv(b, st), tv(b, st) + 2.5 * S16, root, I_STAB, vs=vs, release=2)
                play(Cn['c2'], tv(b, st), tv(b, st) + 2.5 * S16, root + 7, I_STAB, vs=vs, release=2)
        if kind == 'D':                                                     # la flauta del original, en negras
            notes = D_FLUTE[k - 1]
            for qn in range(4):
                n_ = nt(notes[qn] if len(notes) == 4 else notes[0])
                play(Cn['fl1'], tv(b, qn * 4), tv(b, qn * 4) + 3.6 * S16, n_, I_FLUTE, q=q_n163, release=3)
                if len(notes) == 2: play(Cn['fl2'], tv(b, qn * 4), tv(b, qn * 4) + 3.6 * S16, nt(notes[1]), I_FLUTE, q=q_n163, release=3)
        if kind == 'P' and k <= 2:                                          # la flauta de la D se queda dos compases, apagándose
            for qn in range(4):
                for j, x in enumerate(('A4', 'C#5')):
                    play(Cn[('fl1', 'fl2')[j]], tv(b, qn * 4), tv(b, qn * 4) + 3.6 * S16, nt(x), I_FLUTE, q=q_n163,
                         vs=(0.8, 0.45)[k - 1] * (1 - qn * 0.1), release=3)
        if kind == 'P' and k > 4:                                           # la subida de la preparación (sierra, cada compás más arriba)
            r, q = chord_at(chords, b, 0)
            for st in range(16):
                nn = 54 + (k - 5) * 5 + (q + (12, 12 + q[1], 12 + q[2], 24))[st % 6] + (r - 54) % 12
                play(Cn['pulses'], tv(b, st), tv(b, st) + S16 * 0.8, nn, I_PULSE8, vs=0.6 + 0.1 * (k - 4), release=0)

    # ── BATERÍA ──
    for b in range(1, NB + 1):
        kind, k = sec(b), pos(b)
        last = k == LEN[kind]
        nxt = tag[b] if b < NB else 'I'
        for st in range(16):
            t = tv(b, st)
            if kind == 'I':                                                # la intro del original: crece (en 8 compases)
                if st % 4 == 0: hit(kick, TN.KICK, t, 1.0)
                if k >= 5 and st % 4 == 0: snare(t, 0.7, [10, 6, 3, 1])
                if k == 6 and st % 4 == 2: snare(t, 0.5, [8, 5, 2])
                if k == 7 and st % 2 == 1: snare(t, 0.35 + 0.02 * st, [6, 4, 2])
                if k == 8 and st % 4 != 0: snare(t, 0.4 + 0.035 * st, [6 + st // 3, 4, 2])
                if k == 8 and st >= 12: hit(tom, W.TOMS[min(2, (st - 12) // 2 + 1)], t, 0.6)
                if st == 0 and k == 1: NZ['crash'].hit(t, 3, CRASH_SOFT)
                if st == 0 and k == 5: NZ['crash'].hit(t, 3, CRASH)
                continue
            if kind == 'D':                                                # MEDIO TIEMPO: bombo en el 1, caja en el 3, charles abierto suave
                if st == 0 or (st == 10 and k % 2 == 0): hit(kick, TN.KICK_DEEP, t, 1.0)
                if st == 8: snare(t, 0.9)
                if st % 4 == 2: NZ['phat'].hit(t, 1, [5, 3, 2, 1])
                if last and st >= 8: snare(t, 0.3 + (st - 8) * 0.06, [5 + (st - 8), 4, 2])
                if st == 0 and k == 1: NZ['crash'].hit(t, 3, CRASH_SOFT)
                continue
            if kind == 'P' and k <= 4:                                     # preparación: el riff, el bombo y poco más
                if st in (0, 8): hit(kick, TN.KICK_DEEP, t, 0.9)
                if st in (4, 12) and k >= 3: snare(t, 0.4, [7, 4, 2])
                if st % 4 == 2: NZ['phat'].hit(t, 1, [3, 2, 1])
                continue
            if kind == 'P':                                                # …y crece: caja en corcheas, luego semicorcheas
                if st % 4 == 0: hit(kick, TN.KICK_DEEP, t, 1.0)
                step = 2 if k <= 6 else 1
                if st % step == 0: snare(t, 0.3 + 0.08 * (k - 5) + 0.02 * st, [6 + (k - 5) + st // 4, 4, 2])
                if k == 8 and st >= 8: hit(tom, W.TOMS[(st - 8) // 3 % 3], t, 0.7)
                continue
            # el surco: bombo en 1 y 3 (y en el tresillo en el clímax), caja en 2 y 4, charles suave
            if st in (0, 8) or (kind == 'C' and st in (6, 14)): hit(kick, TN.KICK_DEEP, t, 1.0)
            if st in (4, 12): snare(t, 1.0)
            elif st in (7, 15) and kind not in ('R', 'O'): snare(t, 0.3, [6, 3, 1])
            if st % 4 == 2: NZ['phat'].hit(t, 1, [6, 4, 2, 1])
            elif st % 2 == 1 or kind != 'R': NZ['hat'].hit(t, 1, [3, 1] if st % 2 else [4, 2, 1])
            if kind in ('M', 'V', 'B', 'C') and st in (3, 14) and b % 2 == 0: hit(tom, W.TOMS[{3: 2, 14: 1}[st]], t, 0.8)
            # ── transiciones ──
            if last:
                if nxt == 'D':                                             # B → D: medio compás vacío antes de entrar
                    if st >= 8: continue
                elif nxt == 'I':                                           # salida → intro: el bombo solo y un redoble suave
                    if st >= 12: snare(t, 0.25 + (st - 12) * 0.08, [5 + (st - 12), 3, 1])
                elif st >= 12:                                             # redoble de timbales hacia la sección siguiente
                    hit(tom, W.TOMS[min(2, st - 12)], t, 0.75)
                    if st >= 14: snare(t, 0.45 + (st - 14) * 0.15, [8 + (st - 14), 5, 2])
            # platos: fuertes solo en las llegadas grandes; suaves en las demás; en el clímax cada 2 compases
            if st == 0:
                if k == 1 and kind in ('R', 'V', 'C'): NZ['crash'].hit(t, 3, CRASH)
                elif k == 1: NZ['crash'].hit(t, 3, CRASH_SOFT)
                elif kind == 'C' and k % 2 == 1: NZ['crash'].hit(t, 3, CRASH)
                elif kind in ('M', 'V', 'B') and k == 9: NZ['crash'].hit(t, 3, CRASH_SOFT)
        if kind == 'P' and k == 7:                                         # el soplido de ruido que sube hacia el clímax
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
        'lead': cut(F.pulse_dac(F.render_saw(Cn['lead']))), 'dbl': pulse('dbl'), 'echo': pulse('echo'),
        'harm': pulse('harm'), 'call': wave('call'), 'koto': wave('koto'), 'pluck': pulse('pluck'),
        'rise': cut(F.pulse_dac(F.render_saw(Cn['rise']))), 'hold': pulse('h1') + pulse('h2') + pulse('h3'),
        'drone': wave('drone'), 'pulses': pulse('pulses'), 'stabs': pulse('c1') + pulse('c2'),
        'flute': wave('fl1') + wave('fl2'), 'cm': wave('cm'),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + noise('snare'),
        'hat': noise('hat'), 'phat': noise('phat'), 'crash': noise('crash'), 'nrise': noise('nrise'),
    }
    # el bajo "real" y las voces (muestras de audio, no chip)
    import soundfile as sf
    yb = render_bass(bass)
    S['bass'] = np.zeros(n + tail); S['bass'][:min(len(yb), n + tail)] = yb[:n + tail]
    v, vsr = sf.read(VOX)
    v = v.mean(1) if v.ndim == 2 else v
    assert vsr == SR
    S['vox'] = np.zeros(n + tail)
    seg = v[:int(8 * BAR * SR)].copy()                                     # las voces de la intro (sus 8 primeros compases)
    k_ = int(0.25 * SR); seg[-k_:] *= np.linspace(1, 0, k_)
    S['vox'][:len(seg)] = seg
    chop = v[:int(2 * BAR * SR)].copy()                                    # cortes de voz al cerrar frases fuertes
    k_ = int(0.01 * SR); chop[-k_:] *= np.linspace(1, 0, k_)
    S['chop'] = np.zeros(n + tail)
    for b in (starts['B'] + 6, starts['B'] + 14, starts['C'] + 6, starts['C'] + 14):
        i = int(tv(b, 0) * SR); S['chop'][i:i + len(chop)] += chop[:n + tail - i]
    S = {k: GN.fold(x, n, 0) for k, x in S.items() if np.abs(x).max() > 0}     # bucle sin costura (vuelve a la intro)
    g = GN.level(S, {k: LV.get(k, -10) for k in S}, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('pulses', 0.4) - sd('echo', 0.6) + sd('stabs', 0.3) + sd('hat', 0.3) - sd('phat', 0.2) + sd('pluck', 0.25) \
        - sd('hold', 0.3) + sd('koto', 0.35) - sd('harm', 0.25) + sd('flute', 0.3)
    y = F.master(np.stack([x + side, x - side], 1), lufs=LUFS)
    GN.report(NAME, y, S, g, n)
    bad, out = check(mel, chords, tag)
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    print(f'  {BPM} BPM, {NB} compases ({NB * BAR:.1f} s, bucle con la intro); melodía {len(mel)} notas; '
          f'batería {grp(("kick", "snare", "hat", "phat", "crash", "toms", "nrise")):.0f} %, bajo {grp(("bass",)):.0f} %, '
          f'melodía {grp(("lead", "dbl")):.0f} %')
    print('  secciones: ' + ' · '.join(f'{k} {(starts[k] - 1) * BAR // 60:.0f}:{(starts[k] - 1) * BAR % 60:04.1f}' for k, _ in SECTIONS))
    print(f'  B (nueva): notas largas fuera del acorde: {bad or "ninguna"} · fuera de la escala: {out or "ninguna"}')
    return y, mel, starts


def preview(y, starts):
    """Previas: la pista entera, la costura (salida → intro) y cada cambio de sección (4 compases antes y después)"""
    os.makedirs(PREVIEW, exist_ok=True)
    def enc(x, name):
        wav = os.path.join(PREVIEW, name + '.wav'); ogg = wav[:-4] + '.ogg'
        F.write_wav(wav, x)
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"'); os.remove(wav)
    enc(y, 'final_fall_v2')
    k = int(8 * BAR * SR)
    enc(np.concatenate([y[-k:], y[:k]]), 'final_fall_v2_costura')
    for i, (kind, _) in enumerate(SECTIONS[1:], 1):
        c = int((starts[kind] - 1) * BAR * SR); w = int(4 * BAR * SR)
        enc(y[c - w:c + w], f'final_fall_v2_paso_{i}_{SECTIONS[i - 1][0]}-{kind}')
    print(f'  previas en {PREVIEW}')


if __name__ == '__main__':
    y, mel, starts = build()
    if not os.environ.get('REPORT'):
        preview(y, starts)
        if os.environ.get('INSTALL'):
            GN.export(NAME, y, 0)
            W.write_mid(F.out(NAME, 'mid'), [(b, st, n, d) for b, st, n, d, v in mel if v == 'lead'], BPM)
