#!/usr/bin/env python3
# FINAL FALL — tema de jefe, TERCERA versión: composición nueva sobre la BASE de "Final Fall" (Fall Guys).
#
# Historia: v1 = tres arreglos (el usuario eligió el "Jefe"); v2 = ese, con más muestras literales de Final Fall
# (motivo, llamada, sección D, el gran solo) y transiciones suavizadas. El usuario: hazlo como Crab Tantrum (icy) —
# "fácilmente el mejor tema del juego" —: una melodía BUENA y ORIGINAL que casi ni se reconoce, a partir de una buena
# base. (v2 archivada fuera del repo: FlappyMonster_originals/music/versiones/final_fall_v2/.)
#
# La BASE (lo que se queda, como en icy se quedó la célula de Tentacle Tantrum y su 3+3+2):
#   · el RIFF DEL BAJO (Fa#1, su octava "pop", la cola sincopada; el giro La–Si–Do# / Re–Si–Do#) y su surco de batería.
#     El bajo NO es chip: el usuario quiere un bajo "real" (Slap Bass GM de TimGM6mb, renderizado con fluidsynth).
#     En las secciones nuevas el bajo toca EL RITMO DEL RIFF sobre cada acorde.
#   · la armonía de Final Fall (pedal de Fa#m con sus giros; el bajo del verso Fa#–Mi–Re) y su INTRO (8 compases) con
#     las voces del original en crunch de 8 bits (famicom.ref('final_fall_vocals_crunch.wav'), fuera del repo).
# De las MELODÍAS de Final Fall solo se toman IDEAS (ningún compás copiado: se mide al generar):
#   a) el CONTORNO del motivo (la 5ª, cae a la tónica de abajo, salta la octava, baja por grados) → el TEMA A lo canta
#      con el RITMO DEL RIFF (pop en el "y", cola sincopada), no con el suyo; el ESTRIBILLO lo canta desde la 5ª con el
#      salto de octava y la bajada, en el 3+3+2 de la casa y en secuencia.
#   b) la LLAMADA (nota corta, silencio, dos notas que caen a una larga, y la vecina larga) → la sección B la INVIERTE
#     (las dos notas suben a la larga); el RESPIRO la canta en valores largos y sigue por su cuenta.
#   c) el GIRO del bajo (La–Si–Do#, que ya va en 3+3+2) → la cadencia del tema: tres notas que suben en 3+3+2.
#   d) la COLA del riff (notas repetidas en su ritmo sincopado y un salto) → cierra la B y el respiro.
# Y se JUNTAN: en la tercera vuelta del tema, una voz nueva en notas largas canta por encima (contrapunto). La coda
# cita "la llamada" del juego (Do#–Fa#–La–Do#) y acaba en Do#: la dominante de la intro, por donde vuelve el bucle.
#
# Fa# menor natural; estribillo i–VI–III–VII (Fa#m · Re · La · Mi). 181 BPM como el original.
# Forma: INTRO 8 · RIFF 8 · A 8 · A' 8 · B 8 · C 8 (estribillo) · K 8 (respiro) · A'' 8 (+ contrapunto) · B' 8 ·
# C' 8 · PREPARACIÓN 8 · C'' 8 (estribillo con todo) · CODA 4 = 100 compases. Un solo archivo: el bucle incluye la intro.
#
#   python tools/music/final_fall.py          → previas en FlappyMonster_pruebas/musica/final_fall/
#   INSTALL=1 …                               → además assets/music/bosses/final_fall.ogg + tools/music/mid/final_fall.mid
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys, subprocess, tempfile
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_saw, q_n163
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W

BPM = 181
S16 = 60.0 / BPM / 4
BAR = 16 * S16
NAME = 'final_fall'
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/musica/final_fall'
SF_GM = os.environ.get('FM_SF_GM', '/home/mtvemo/.venvs/fm-music/lib/python3.11/site-packages/pretty_midi/TimGM6mb.sf2')   # (FM_SF_GM: en otra máquina)
VOX = F.ref('final_fall_vocals_crunch.wav')

N = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
MAJ, MIN = (0, 4, 7), (0, 3, 7)
SCALE = {6, 8, 9, 11, 1, 2, 4}                    # Fa# menor natural


def ch(s):
    return (N[s[:-1]], MIN) if s.endswith('m') else (N[s], MAJ)


def nt(s):                                        # 'C#5' → 73
    return 12 * (int(s[-1]) + 1) + N[s[:-1]]


# ══ LA BASE ══════════════════════════════════════════════════════════════════════════════════════════════════════
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
# El bajo del verso del original (Fa#1 · Mi1 · Re1 · Mi1, sostenidos): la sección B
BASS_V = [(1, 0, 30, 4), (1, 10, 28, 4), (1, 14, 26, 8), (2, 6, 28, 10), (3, 0, 30, 2), (3, 4, 30, 3), (3, 10, 28, 4),
          (3, 14, 26, 8), (4, 6, 28, 10)]
BASS_V = BASS_V + [(b + 4, st, n, d) for b, st, n, d in BASS_V]
CH_V = [['F#m', 'E', 'D'], ['D', 'E', 'E']] * 4                    # (como el bajo: Fa# · Mi en el 3,5 · Re en el 4,5)
RIFF_RHY = [(0, 0, 2), (2, 12, 2), (8, 0, 2), (10, 0, 1), (11, 0, 2), (13, 0, 2), (15, 0, 1)]   # el ritmo del riff


def lo(r):                                        # la tónica del acorde en el registro del riff (Re1…Do#2)
    return 26 + (r - 26) % 12


def riff_on(chords, base, nb):
    """El ritmo del riff sobre los acordes de una sección nueva (un acorde por compás: el de su 1ª mitad)"""
    return [(base + b, st, lo(chords[base + b - 1][0][0]) + iv, d) for b in range(1, nb + 1) for st, iv, d in RIFF_RHY]


# ══ LAS MELODÍAS NUEVAS ══════════════════════════════════════════════════════════════════════════════════════════
# EL MOTIVO (v4, nuevo; el usuario: la melodía de v3 sonaba "rara e incoherente" — saltos de quinta y de octava en
# casi cada compás —; "no importa si se aleja de Final Fall"): UNA idea de dos compases, cantable, casi por grados, en
# el 3+3+2 de la casa: sube Fa#–Sol#–La hasta un Do# largo y baja, y se posa en la tónica. Todo lo demás sale de él:
# el tema A lo pregunta y lo contesta en secuencia, la B lo INVIERTE (baja Do#–Si–La en 3+3+2), el estribillo lo
# ABRE (sube por el acorde hasta una cima) y el respiro lo canta en valores largos. Notas largas = notas del acorde.
T_A = ["0:F#5/3 3:G#5/3 6:A5/2 8:C#6/4 12:B5/2 14:A5/2",              # el motivo (pregunta)…
       "2:A5/2 4:G#5/2 6:F#5/4 10:E5/2 12:F#5/4",
       "0:C#6/3 3:B5/3 6:A5/2 8:F#5/4 12:A5/4",                           # …la respuesta, que baja
       "0:E5/3 3:A5/3 6:C#6/2 8:B5/4 12:G#5/4",                           # (el giro del bajo, La–Si–Do#, en la melodía)
       "0:F#5/3 3:G#5/3 6:A5/2 8:C#6/4 12:D6/2 14:C#6/2",                 # el motivo otra vez, con bordadura arriba
       "2:B5/2 4:A5/2 6:G#5/2 8:A5/4 12:F#5/4",
       "0:E5/2 2:F#5/2 4:A5/4 8:C#6/4 12:A5/4"]
A_END = ["0:F#5/3 3:A5/3 6:D6/2 8:B5/4 12:C#6/4"]                       # (Re–Si–Do#: vuelve a empezar)
A_END2 = ["0:D6/4 4:A5/4 8:B5/4 12:C#6/4"]
# B — el motivo INVERTIDO (baja en 3+3+2 y se posa), sobre el bajo del verso (Fa#m · Mi · Re | Re · Mi)
T_B = ["0:C#6/3 3:B5/3 6:A5/2 8:G#5/4 12:F#5/4",
       "2:F#5/2 4:E5/2 6:D5/2 8:E5/8",
       "0:A5/3 3:G#5/3 6:F#5/2 8:E5/4 12:F#5/4",
       "2:A5/2 4:B5/2 6:C#6/2 8:B5/8",
       "0:C#6/3 3:B5/3 6:A5/2 8:B5/4 12:A5/4",
       "2:F#5/2 4:G#5/2 6:A5/2 8:G#5/8",
       "0:F#5/3 3:E5/3 6:F#5/2 8:G#5/4 12:A5/4",
       "0:F#5/4 4:E5/2 6:D5/2 8:E5/4 12:G#5/4"]
# C (estribillo) — el motivo ABIERTO: sube por el acorde hasta una cima y baja por grados (Fa#m · Re · La · Mi …)
T_C = ["0:A5/3 3:C#6/3 6:E6/2 8:C#6/4 12:A5/4",
       "0:A5/3 3:B5/3 6:C#6/2 8:D6/4 12:A5/4",
       "0:C#6/3 3:B5/3 6:A5/2 8:E6/4 12:C#6/4",
       "0:B5/3 3:G#5/3 6:E5/2 8:G#5/8",
       "0:A5/3 3:C#6/3 6:E6/2 8:F#6/4 12:C#6/4",
       "0:D6/3 3:C#6/3 6:B5/2 8:A5/4 12:F#5/4",
       "0:G#5/3 3:A5/3 6:B5/2 8:E6/4 12:B5/4",
       "0:C#6/4 4:A5/4 8:F#5/8"]
CH_C = ['F#m', 'D', 'A', 'E', 'F#m', 'D', 'E', 'F#m']
# K (respiro) — el motivo en valores largos, que va por su cuenta
T_K = ["0:F#5/6 6:E5/2 8:D5/8", "0:E5/6 6:F#5/2 8:G#5/8", "0:A5/6 6:G#5/2 8:F#5/8", "0:C#6/8 8:A5/8",
       "0:B5/6 6:A5/2 8:F#5/8", "0:A5/6 6:B5/2 8:D6/8", "0:E6/6 6:D6/2 8:B5/8", "0:G#5/4 4:B5/4 8:E6/4 12:D6/2 14:C#6/2"]
CH_K = ['D', 'E', 'F#m', 'F#m', 'Bm', 'D', 'E', 'E']
BASS_K = [(1, 0, 26, 14), (2, 0, 28, 14)] + [(3 + k, st, n, d) for k in range(2) for st, n, d in
                                              [(0, 30, 2), (2, 42, 2), (8, 30, 2), (10, 30, 1), (11, 30, 2), (13, 30, 2), (15, 30, 1)]] + \
         [(5, 0, 35, 14), (6, 0, 26, 14), (7, 0, 28, 6), (7, 8, 28, 2), (7, 10, 40, 2), (7, 12, 28, 4),
          (8, 0, 28, 2), (8, 2, 40, 2), (8, 8, 28, 2), (8, 10, 28, 1), (8, 11, 28, 2), (8, 13, 28, 2), (8, 15, 28, 1)]
# El CONTRACANTO de la tercera vuelta del tema: notas largas del acorde, POR DEBAJO de la melodía (regla de la casa)
T_DESC = ["0:C#5/8 8:A4/8", "0:F#4/8 8:A4/8", "0:C#5/8 8:F#4/8", "0:E4/8 8:F#4/4 12:G#4/4",
          "0:A4/8 8:C#5/8", "0:F#4/8 8:A4/8", "0:C#5/8 8:A4/8", "0:A4/8 8:F#4/4 12:G#4/4"]
# CODA — "la llamada" del juego (Do#–Fa#–La–Do#) y Do#: la dominante de la intro
T_CODA = ["0:F#5/4 4:A5/4 8:D6/8", "0:E6/4 4:B5/4 8:G#5/8", "0:C#5/2 2:F#5/2 4:A5/2 6:C#6/10", "0:C#6/4 4:G#5/4 8:C#6/8"]
CH_CODA = ['D', 'E', 'F#m', 'C#']
# PREPARACIÓN — la pregunta del motivo en el eco, y la subida
T_P = [T_A[0], T_A[1], "", T_A[3]]

# ── LA INTRO de Final Fall, en 8 compases ──
PL_A = ['A', 'A', 'A', 'F#', 'A', 'A', 'F#', 'A', 'A', 'F#', 'A', 'A', 'G#', 'G#', 'E', 'G#']           # compases impares (v4: en MENOR, La y no La#: el original estaba en Fa# mayor y chocaba con el resto)
PL_B = ['F#', 'F#', 'F#', 'D', 'F#', 'F#', 'D', 'F#', 'F#', 'D', 'F#', 'F#', 'G#', 'G#', 'E', 'G#']     # compases pares
RISERS = {2: 0, 4: 12, 6: 12, 8: 12}                              # compás → octava de la subida Fa#-Sol#-La-Do#
HOLDS = {3: ['C#4', 'F#4'], 5: ['A4', 'C#5'], 7: ['F#4', 'A4', 'C#5']}
CH_I = [['F#m', 'F#m', 'E'], ['D', 'D', 'E']] * 4
# la intro presenta el motivo en la caja de música (adaptado a SUS acordes: Fa#m–Mi / Re–Mi)
T_IN = ['', '', '', '', "0:F#5/3 3:G#5/3 6:A5/2 8:C#6/4 12:B5/4", "0:A5/4 4:F#5/2 6:A5/2 8:D6/4 12:B5/4",
        "0:C#6/3 3:B5/3 6:A5/2 8:F#5/4 12:G#5/4", "0:F#5/3 3:A5/3 6:D6/2 8:A5/4 12:B5/2 14:C#6/2"]

SECTIONS = [('I', 8), ('R', 8), ('A', 8), ('A2', 8), ('B', 8), ('C', 8), ('K', 8), ('A3', 8), ('B2', 8), ('C2', 8),
            ('P', 8), ('C3', 8), ('CODA', 4)]
LEN = dict(SECTIONS)
ROLE = {'I': 'I', 'R': 'R', 'A': 'A', 'A2': 'A', 'A3': 'A', 'B': 'B', 'B2': 'B', 'C': 'C', 'C2': 'C', 'C3': 'C',
        'K': 'K', 'P': 'P', 'CODA': 'CODA'}

# Las melodías de Final Fall, SOLO para medir que no se copia ningún compás (ritmo + intervalos)
FF_BARS = ["0:C#5/2 4:F#4/2 8:F#5/2 10:E5/2 14:C#5/2", "2:D5/2 4:E5/2 6:B4/2 10:A4/2 12:G#4/2 14:E4/2",
           "2:D5/2 4:E5/2 6:A5/2 10:G#5/2 12:E5/2 14:B4/2", "0:C#5/2 10:B4/2 14:A4/8", "6:B4/10",
           "0:C#5/4 10:B4/4 14:A4/6", "6:B4/8"]


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

    def add(base, bars, voice='lead'):
        mel.extend((base + b, st, n, d, voice) for b, st, n, d in W.PH(*bars))

    def addb(base, line):
        bass.extend((base + b, st, n, d) for b, st, n, d in line)
    for kind, nb in SECTIONS:
        base = len(chords)
        starts[kind] = base + 1
        tag += [kind] * nb
        role = ROLE[kind]
        if role == 'I':
            chs(CH_I); add(base, T_IN, 'box')
            # el bajo ENTRA ya en la intro (para que el riff no llegue de golpe): el pedal Fa#1 en redondas, blancas,
            # el ritmo del riff a medias y la anacrusa en Do#, cada vez más fuerte
            bass.extend([(base + 5, 0, 30, 15, 55), (base + 6, 0, 30, 15, 62), (base + 7, 0, 30, 7, 70), (base + 7, 8, 30, 7, 74),
                         (base + 8, 0, 30, 2, 80), (base + 8, 2, 42, 2, 80), (base + 8, 8, 30, 2, 84)])
            bass.append((base + 8, 12, 37, 2, 90)); bass.append((base + 8, 14, 37, 2, 95))   # anacrusa: el giro, en Do#
        elif role in ('R', 'A', 'P'):
            chs(CH_RIFF); addb(base, RIFF)
            if role == 'A':
                add(base, T_A + (A_END2 if kind in ('A2', 'A3') else A_END))
                if kind == 'A3': add(base, T_DESC, 'desc')
            if role == 'P': add(base, T_P, 'call')
        elif role == 'B':
            chs(CH_V); addb(base, BASS_V); add(base, T_B)
        elif role == 'C':
            chs(CH_C); bass.extend(riff_on(chords, base, nb)); add(base, T_C)
        elif role == 'K':
            chs(CH_K); addb(base, BASS_K); add(base, T_K, 'call')
        elif role == 'CODA':
            chs(CH_CODA); bass.extend(riff_on(chords, base, nb)); add(base, T_CODA)
    mel.sort()
    return mel, chords, tag, starts, bass


def chord_at(chords, b, st):
    c = chords[b - 1]
    return c[0] if st < 8 else (c[1] if st < 12 else c[2])


def check(mel, chords, tag):
    """Reglas de la casa: notas largas (≥ 4) del acorde que suena; todo en la escala (la coda acaba en Do# mayor)"""
    bad = [(b, st) for b, st, n, d, v in mel if d >= 4 and (n - chord_at(chords, b, st)[0]) % 12 not in chord_at(chords, b, st)[1]]
    out = [(b, st) for b, st, n, d, v in mel if n % 12 not in SCALE and tag[b - 1] != 'I']
    return bad, out


def copied(mel):
    """Compases de la melodía que repiten ritmo + intervalos de un compás de Final Fall (lo que se quiere: 0)"""
    sig = lambda notes: tuple((st, n - notes[0][1], d) for st, n, d in notes) if notes else None
    ff = {sig([(st, n, d) for b, st, n, d in W.PH(t)]) for t in FF_BARS}
    bars = {}
    for b, st, n, d, v in mel:
        if v in ('lead', 'call'): bars.setdefault(b, []).append((st, n, d))
    return [b for b, x in bars.items() if sig(sorted(x)) in ff], len(bars)


# ── INSTRUMENTOS (los de la casa: worlds_nes / crab_tantrum / gloomy_nes) ─────────────────────────────────────────
WAVES = [wavetable([1.0, 0.7, 0.35, 0.45, 0.1, 0.2]),        # 0 koto (metálico, brillante)
         wavetable([1.0, 0.3, 0.1]),                          # 1 colchón (casi seno)
         GN.CWAVES[0]]                                        # 2 caja de música
I_SAWL = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.18, 6)}
I_SAWBIG = {'vol': [13, 15, 15, 14, 14, 14], 'sus': 14, 'vib': (10, 0.3, 5.6)}             # notas largas: vibrato ancho
I_PUL = {'vol': [11, 10, 9, 8, 8, 7], 'sus': 7, 'duty': [0.125, 0.25]}
I_CALL = {'vol': [6, 9, 11, 12, 12, 11], 'sus': 11, 'vib': (16, 0.25, 5.2), 'duty': 1.0}   # la voz del respiro (colchón)
I_BOX = dict(GN.I_BELL, duty=2.0)                                                            # caja de música (contrapunto)
I_ECHO = {'vol': [5, 5, 4, 3], 'sus': 2, 'duty': 0.5}
I_PLUCK = {'vol': [8, 6, 4, 2, 1], 'sus': 0, 'duty': 0.5}          # el ostinato de la intro: redondo y suave (era 0.25 y fuerte)
I_RISE = {'vol': [13, 12, 11, 10], 'sus': 10}
I_HOLD = {'vol': [6, 8, 9, 9, 8, 8], 'sus': 8, 'vib': (20, 0.15, 5.0), 'duty': 0.25}
I_DRONE = {'vol': [3, 5, 6, 7, 7, 7], 'sus': 7, 'duty': 1.0}
I_PULSE8 = {'vol': [7, 5, 3, 2, 1], 'sus': 0, 'duty': 0.125}      # los "pulsos" de fondo (corcheas)
I_STAB = {'vol': [13, 10, 7, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_CM = {'vol': [4, 6, 7, 7, 7, 6], 'sus': 6, 'vib': (18, 0.12, 5.0), 'duty': 1.0}       # contracanto bajo la melodía
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
CRASH_SOFT = [9, 8, 7, 6, 5, 4, 3, 3, 2, 2, 1, 1]
TRES = (0, 6, 12)
LV = {'lead': 0, 'dbl': -6, 'echo': -13, 'call': -2, 'desc': -7, 'box': -3, 'pluck': -13, 'rise': -6, 'hold': -9,
      'drone': -12, 'pulses': -13, 'stabs': -7, 'cm': -10, 'bass': 3, 'kick': 3, 'snare': 1, 'hat': -14,
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
    for x in bass:                                             # (compás, semicorchea, nota, dur[, velocidad])
        b, st, n, d = x[:4]
        t0 = ((b - 1) * 16 + st) * T // 4
        ev += [(t0 + d * T // 4 - 6, 0, n, 0), (t0, 1, n, x[4] if len(x) > 4 else 100)]
    t = 0
    for tt, on, n, vel in sorted(ev):
        tr.append(mido.Message('note_on' if on else 'note_off', channel=0, note=n, velocity=vel, time=tt - t)); t = tt
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
    keys = ('lead', 'dbl', 'echo', 'call', 'desc', 'box', 'pluck', 'rise', 'h1', 'h2', 'h3', 'drone', 'pulses', 'c1', 'c2', 'cm')
    Cn = {k: Chan(NF) for k in keys}
    NZ = {k: Noise(NF) for k in ('hat', 'phat', 'snare', 'crash', 'nrise')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16
    sec = lambda b: tag[b - 1]
    role = lambda b: ROLE[sec(b)]
    pos = lambda b: b - starts[sec(b)] + 1                                  # compás dentro de su sección (1…)

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # ── MELODÍA ──
    for b, st, n, d, voice in mel:
        kind = sec(b)
        t0 = tv(b, st)
        if voice == 'call':                                                 # respiro / preparación: el colchón con eco
            vs = 0.7 if kind == 'P' else 1.0
            play(Cn['call'], t0, t0 + d * S16, n, I_CALL, q=q_n163, vs=vs, release=6)
            play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 4) * S16, n, I_ECHO, vs=vs, release=2); continue
        if voice == 'desc':                                                 # el contracanto (por debajo): el colchón
            play(Cn['desc'], t0, t0 + d * S16, n, I_CM, q=q_n163, release=6); continue
        if voice == 'box':                                                  # (intro) el motivo en la caja de música, con eco
            play(Cn['box'], t0, t0 + max(d, 3) * S16, n, I_BOX, q=q_n163, release=6)
            play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + 2 * S16, n, I_ECHO, vs=0.6, release=1); continue
        up = kind in ('A2', 'A3', 'B2', 'C2', 'C3', 'CODA')                 # las vueltas siguientes doblan a la octava
        play(Cn['lead'], t0, t0 + d * S16 * 0.93, n - 12, I_SAWBIG if d >= 6 else I_SAWL, q=q_saw, release=3)
        play(Cn['dbl'], t0, t0 + d * S16 * 0.93, n + (12 if up else 0), I_PUL, release=2)
        if d >= 3: play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 3) * S16 * 0.8, n, I_ECHO, release=1)

    # la cabeza del tema A ANUNCIADA en el eco en los dos últimos compases del riff
    pre = starts['A'] - 2
    for b, st, n, d in W.PH(*T_A[:2]):
        play(Cn['echo'], tv(pre + b - 1, st), tv(pre + b - 1, st) + d * S16, n, I_ECHO, vs=0.6 + 0.4 * (b - 1), release=1)

    # contracanto bajo la melodía en los estribillos 2 y 3 y en la B': notas largas del acorde
    for b in range(1, NB + 1):
        if sec(b) in ('C2', 'C3', 'B2'):
            for half, st in enumerate((0, 8)):
                r, q = chord_at(chords, b, st)
                play(Cn['cm'], tv(b, st), tv(b, st) + 7.5 * S16, 60 + (r - 60) % 12 + (q[1] if half == 0 else q[2]), I_CM, q=q_n163, release=4)

    # ── LA INTRO (su ostinato sigue cuatro compases dentro del riff apagándose, y el pedal dos) ──
    for b in list(range(starts['I'], starts['I'] + 8 + 4)):
        k = b - starts['I'] + 1
        fade = 1.0 if sec(b) == 'I' else (0.8, 0.6, 0.4, 0.2)[k - 9]
        pat = PL_A if k % 2 == 1 else PL_B
        for st, p in enumerate(pat):
            play(Cn['pluck'], tv(b, st), tv(b, st) + S16 * 0.7, 60 + N[p] - (12 if N[p] > 7 else 0), I_PLUCK, vs=fade, release=1)
        if k <= 10:
            play(Cn['drone'], tv(b, 0), tv(b, 16) - 0.01, 42, I_DRONE, q=q_n163, vs=fade, release=0)
        if sec(b) != 'I': continue
        if k in RISERS:
            for i, iv in enumerate((0, 2, 3, 7)):
                play(Cn['rise'], tv(b, 12 + i), tv(b, 13 + i), 54 + RISERS[k] + iv, I_RISE, q=q_saw, release=1)
        if k in HOLDS:
            for j, x in enumerate(HOLDS[k]):
                play(Cn[('h1', 'h2', 'h3')[j]], tv(b, 0), tv(b, 0) + 28 * S16, nt(x), I_HOLD, release=6)

    # ── ACOMPAÑAMIENTO por compás ──
    for b in range(1, NB + 1):
        kind, k, rl = sec(b), pos(b), role(b)
        if rl == 'I': continue
        # los "pulsos" de fondo: crecen durante el riff; en el respiro, a medias
        vs = min(1.0, 0.25 + 0.1 * (k - 1)) if rl == 'R' else ((0.9, 0.7)[k - 1] if rl == 'K' and k <= 2 else (0.5 if rl == 'K' else 1.0))
        for st in range(0, 16, 2):
            r, q = chord_at(chords, b, st)
            play(Cn['pulses'], tv(b, st), tv(b, st) + S16, 78 + (r - 78) % 12 + (q[2] if st % 4 == 0 else 0), I_PULSE8, vs=vs, release=0)
        # golpes de quinta en el tresillo: tema (desde la 2ª vuelta), estribillos, coda; fuera en el riff, la B y el respiro
        # (al salir de un estribillo hacia el respiro o la preparación, los golpes no se cortan: se apagan en 2 compases)
        tail_ = rl in ('K', 'P') and k <= 2 and ROLE[tag[starts[kind] - 2]] == 'C'
        stabs = kind in ('A2', 'A3') or rl in ('C', 'CODA') or (rl == 'P' and k > 4) or tail_
        if stabs:
            for st in TRES:
                r, q = chord_at(chords, b, st)
                root = 54 + (r - 54) % 12
                v_ = (0.5, 0.25)[k - 1] if tail_ else (0.6 if rl == 'P' else 1.0)
                play(Cn['c1'], tv(b, st), tv(b, st) + 2.5 * S16, root, I_STAB, vs=v_, release=2)
                play(Cn['c2'], tv(b, st), tv(b, st) + 2.5 * S16, root + 7, I_STAB, vs=v_, release=2)
        if rl == 'P' and k > 4:                                             # la subida de la preparación
            r, q = chord_at(chords, b, 0)
            for st in range(16):
                nn = 54 + (k - 5) * 5 + (q + (12, 12 + q[1], 12 + q[2], 24))[st % 6] + (r - 54) % 12
                play(Cn['pulses'], tv(b, st), tv(b, st) + S16 * 0.8, nn, I_PULSE8, vs=0.6 + 0.1 * (k - 4), release=0)

    # ── BATERÍA ──
    for b in range(1, NB + 1):
        kind, k, rl = sec(b), pos(b), role(b)
        last = k == LEN[kind]
        nxt = ROLE[tag[b]] if b < NB else 'I'
        for st in range(16):
            t = tv(b, st)
            if rl == 'I':                                                  # la intro del original: crece (en 8 compases)
                if st % 4 == 0: hit(kick, TN.KICK, t, 1.0)
                if k >= 5 and st % 4 == 0: snare(t, 0.7, [10, 6, 3, 1])
                if k == 6 and st % 4 == 2: snare(t, 0.5, [8, 5, 2])
                if k == 7 and st % 2 == 1: snare(t, 0.35 + 0.02 * st, [6, 4, 2])
                if k == 8 and st % 4 != 0: snare(t, 0.4 + 0.035 * st, [6 + st // 3, 4, 2])
                if k == 8 and st >= 12: hit(tom, W.TOMS[min(2, (st - 12) // 2 + 1)], t, 0.6)
                if st == 0 and k == 1: NZ['crash'].hit(t, 3, CRASH_SOFT)
                if st == 0 and k == 5: NZ['crash'].hit(t, 3, CRASH)
                continue
            if rl == 'K':                                                  # RESPIRO: bombo en el tresillo, charles de pedal
                if st in TRES: hit(kick, TN.KICK_DEEP, t, 0.9 if k >= 3 else 0.8)
                if st % 4 == 2: NZ['phat'].hit(t, 1, [4, 2, 1])
                if k <= 2 and st % 2 == 1: NZ['hat'].hit(t, 1, [2, 1] if k == 2 else [3, 1])    # (el charles se va apagando)
                if k >= 5 and st in (4, 12): snare(t, 0.45, [7, 4, 2])     # vuelven los tambores
                if last and st >= 8: snare(t, 0.35 + (st - 8) * 0.07, [6 + (st - 8), 4, 2])
                continue
            if rl == 'P' and k <= 4:                                       # preparación: el riff, el bombo y poco más
                if st in TRES: hit(kick, TN.KICK_DEEP, t, 0.9)
                if st in (4, 12): snare(t, 0.6 if k <= 2 else 0.4, [7, 4, 2])
                if st % 4 == 2: NZ['phat'].hit(t, 1, [3, 2, 1])
                if k <= 2 and st % 2 == 1: NZ['hat'].hit(t, 1, [2, 1])
                continue
            if rl == 'P':                                                  # …y crece: caja en corcheas, luego semicorcheas
                if st % 4 == 0: hit(kick, TN.KICK_DEEP, t, 1.0)
                step = 2 if k <= 6 else 1
                if st % step == 0: snare(t, 0.3 + 0.08 * (k - 5) + 0.02 * st, [6 + (k - 5) + st // 4, 4, 2])
                if k == 8 and st >= 8: hit(tom, W.TOMS[(st - 8) // 3 % 3], t, 0.7)
                continue
            # el surco del original: bombo en 1 y 3 (y en el tresillo en los estribillos), caja en 2 y 4, charles suave
            if st in (0, 8) or (rl == 'C' and st in (6, 14)): hit(kick, TN.KICK_DEEP, t, 1.0)
            if st in (4, 12): snare(t, 1.0)
            elif st in (7, 15) and rl not in ('R', 'B', 'CODA'): snare(t, 0.3, [6, 3, 1])
            if st % 4 == 2: NZ['phat'].hit(t, 1, [6, 4, 2, 1])
            elif st % 2 == 1 or rl != 'R': NZ['hat'].hit(t, 1, [3, 1] if st % 2 else [4, 2, 1])
            if rl in ('A', 'C') and st in (3, 14) and b % 2 == 0: hit(tom, W.TOMS[{3: 2, 14: 1}[st]], t, 0.8)
            # ── transiciones ──
            if last:
                if nxt in ('K', 'P'):                                      # estribillo → respiro / preparación: timbales que bajan, suaves
                    if st >= 8 and st % 2 == 0: hit(tom, W.TOMS[min(2, (st - 8) // 3)], t, 0.55)
                elif nxt == 'I':                                           # coda → intro: un redoble suave
                    if st >= 12: snare(t, 0.25 + (st - 12) * 0.08, [5 + (st - 12), 3, 1])
                elif st >= 12:                                             # redoble de timbales hacia la sección siguiente
                    hit(tom, W.TOMS[min(2, st - 12)], t, 0.75)
                    if st >= 14: snare(t, 0.45 + (st - 14) * 0.15, [8 + (st - 14), 5, 2])
            # platos: fuertes en las llegadas grandes (riff, estribillos); suaves en las demás; el último estribillo, cada 2
            if st == 0:
                if k == 1 and rl in ('R', 'C'): NZ['crash'].hit(t, 3, CRASH)
                elif k == 1: NZ['crash'].hit(t, 3, CRASH_SOFT)
                elif kind == 'C3' and k % 2 == 1: NZ['crash'].hit(t, 3, CRASH)
                elif rl == 'C' and k == 5: NZ['crash'].hit(t, 3, CRASH_SOFT)
        if rl == 'P' and k == 7:                                           # el soplido de ruido que sube hacia el estribillo
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
        'call': wave('call'), 'desc': wave('desc'), 'box': wave('box'), 'pluck': pulse('pluck'),
        'rise': cut(F.pulse_dac(F.render_saw(Cn['rise']))), 'hold': pulse('h1') + pulse('h2') + pulse('h3'),
        'drone': wave('drone'), 'pulses': pulse('pulses'), 'stabs': pulse('c1') + pulse('c2'), 'cm': wave('cm'),
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
    chop = v[:int(2 * BAR * SR)].copy()                                    # cortes de voz al cerrar los estribillos
    k_ = int(0.01 * SR); chop[-k_:] *= np.linspace(1, 0, k_)
    S['chop'] = np.zeros(n + tail)
    for b in (starts['C2'] + 6, starts['C3'] + 2, starts['C3'] + 6):
        i = int(tv(b, 0) * SR); S['chop'][i:i + len(chop)] += chop[:n + tail - i]
    S = {k: GN.fold(x, n, 0) for k, x in S.items() if np.abs(x).max() > 0}     # bucle sin costura (vuelve a la intro)
    g = GN.level(S, {k: LV.get(k, -10) for k in S}, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('pulses', 0.4) - sd('echo', 0.6) + sd('stabs', 0.3) + sd('hat', 0.3) - sd('phat', 0.2) + sd('pluck', 0.25) \
        - sd('hold', 0.3) + sd('desc', 0.35)
    y = F.master(np.stack([x + side, x - side], 1), lufs=LUFS)
    GN.report(NAME, y, S, g, n)
    bad, out = check(mel, chords, tag)
    cp, nbars = copied(mel)
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    print(f'  {BPM} BPM, {NB} compases ({NB * BAR:.1f} s, bucle con la intro); melodía {len(mel)} notas; '
          f'batería {grp(("kick", "snare", "hat", "phat", "crash", "toms", "nrise")):.0f} %, bajo {grp(("bass",)):.0f} %, '
          f'melodía {grp(("lead", "dbl", "call")):.0f} %, ostinato {grp(("pluck",)):.1f} %')
    print('  secciones: ' + ' · '.join(f'{k} {(starts[k] - 1) * BAR // 60:.0f}:{(starts[k] - 1) * BAR % 60:04.1f}' for k, _ in SECTIONS))
    print(f'  notas largas fuera del acorde: {bad or "ninguna"} · fuera de la escala: {out or "ninguna"}')
    print(f'  compases de melodía copiados de Final Fall (ritmo + intervalos): {len(cp)} de {nbars} {cp or ""}')
    return y, mel, starts


def preview(y, starts):
    """Previas: la pista entera, la costura (coda → intro) y cada cambio de sección (4 compases antes y después)"""
    os.makedirs(PREVIEW, exist_ok=True)
    for f in os.listdir(PREVIEW):
        if f.startswith('final_fall_v4'): os.remove(os.path.join(PREVIEW, f))
    def enc(x, name):
        wav = os.path.join(PREVIEW, name + '.wav'); ogg = wav[:-4] + '.ogg'
        F.write_wav(wav, x)
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"'); os.remove(wav)
    enc(y, 'final_fall_v4')
    k = int(8 * BAR * SR)
    enc(np.concatenate([y[-k:], y[:k]]), 'final_fall_v4_costura')
    for i, (kind, _) in enumerate(SECTIONS[1:], 1):
        c = int((starts[kind] - 1) * BAR * SR); w = int(4 * BAR * SR)
        enc(y[c - w:c + w], f'final_fall_v4_paso_{i:02d}_{SECTIONS[i - 1][0]}-{kind}')
    print(f'  previas en {PREVIEW}')


if __name__ == '__main__':
    y, mel, starts = build()
    if not os.environ.get('REPORT'):
        preview(y, starts)
        if os.environ.get('INSTALL'):
            GN.export(NAME, y, 0)
            W.write_mid(F.out(NAME, 'mid'), [(b, st, n, d) for b, st, n, d, v in mel if v == 'lead'], BPM)
