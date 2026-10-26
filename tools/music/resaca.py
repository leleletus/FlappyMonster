#!/usr/bin/env python3
# RESACA (antes "Caída libre") — tema de jefe ORIGINAL sobre el bajo de "Final Fall": el del Pez Globo Gigante, el
# nuevo jefe de la costa (docs/bosses/new-bosses-plan.md). Nombre del usuario (2026-10-25). SEGUNDA versión (+ la v3).
#
# v1 (archivada: FlappyMonster_originals/music/versiones/caida_libre_v1/) — el usuario: "la melodía principal y las
# cosas nuevas no terminan de funcionar, no suena armonioso ni a jefe". Las dos causas: (1) la armonía de arriba
# (Re, Mi, Sim) iba CONTRA el bajo, que nunca salía de Fa#; (2) la melodía vagaba sin una idea que volviera. Ahora:
#   · LA ARMONÍA ES LA DEL BAJO, siempre. Cuando los acordes se mueven, el bajo se mueve con ellos (el usuario lo
#     permite: "que siga sonando como ya lo hace, pero que no siempre sea así"): el riff de Final Fall tal cual en las
#     secciones A; en la B y el clímax, EL RITMO DEL RIFF sobre las raíces de la progresión (Fa# · Re · Mi · Fa# …);
#     notas largas en el respiro; y en el A final, el riff con más golpes de octava.
#   · UN GANCHO de jefe: Fa# Fa# La · Sol# Fa# Do#~ (grito en 3+3+2 y caída), que se repite, varía el final de la
#     frase y en la B baja en SECUENCIA por los acordes (i–VI–VII–i: Fa#m · Re · Mi · Fa#m), como un grito de guerra.
#   · Arreglo de jefe como Crab Tantrum (aprobado): sierra del VRC6 una octava abajo + pulso, golpes de quinta en el
#     tresillo, timbales, plato cada dos compases en el clímax; la caja de música solo en el respiro.
# De Final Fall: SOLO el riff del bajo (su sonido de bajo real: `final_fall.render_bass`) y las voces en crunch (al
# abrir y cerrar —cruzan la costura seguidas—, filtradas en el respiro, y cortes que contestan al gancho).
#
# Forma (181 BPM, Fa# menor natural): INTRO 8 · A 16 · B 16 · A' 16 · RESPIRO 8 · SUBIDA 8 · CLÍMAX 16 · A FINAL 16 ·
# CODA 8 · SALIDA 8 = 120 compases (159,1 s), un solo archivo en bucle (la salida vuelve a la intro).
#
#   python tools/music/resaca.py          → previas en FlappyMonster_pruebas/musica/resaca/
#   INSTALL=1 …                           → assets/music/bosses/resaca.ogg + tools/music/mid/resaca.mid
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
NAME = 'resaca'
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/musica/resaca'
SCALE = FF.SCALE
ch = FF.ch
T1, T2 = ['A', 'Bm', 'C#m'], ['D', 'Bm', 'C#m']                   # los giros del riff (8 + 4 + 4 semicorcheas). v3: Sim y
# Do#m, como suena en Final Fall (medido: Re > Re#, Mi > Mi#); v2 los tomaba mayores y los pulsos tocaban Re# y Mi#
RIFF_H = ['F#m', 'F#m', 'F#m', T1, 'F#m', 'F#m', 'F#m', T2]        # la armonía del riff = lo que toca el bajo
ROOT = {'F#': 30, 'D': 26, 'E': 28, 'A': 33, 'B': 35, 'C#': 37}  # raíces en el registro del riff

# ══ EL BAJO: el riff de Final Fall y sus variantes ═══════════════════════════════════════════════════════════════
RIFF_RHY = [(0, 0, 2), (2, 12, 2), (8, 0, 2), (10, 0, 1), (11, 0, 2), (13, 0, 2), (15, 0, 1)]   # su ritmo (y la octava "pop")
RIFF_POP = [(0, 0, 2), (2, 12, 2), (6, 12, 1), (8, 0, 2), (10, 12, 1), (11, 0, 2), (13, 0, 2), (15, 12, 1)]   # (A final)


def bass_riff(base, pops=False):
    if not pops: return [(base + b, st, n, d) for b, st, n, d in FF.RIFF]
    out = []
    for b in range(1, 9):
        if b in (4, 8): out += [(base + bb, st, n, d) for bb, st, n, d in FF.RIFF if bb == b]       # (los giros, iguales)
        else: out += [(base + b, st, 30 + iv, d) for st, iv, d in RIFF_POP]
    return out


def bass_prog(base, harm, push=True):
    """El ritmo del riff sobre la raíz de cada compás; el último de cada 4 empuja en corcheas hacia el siguiente"""
    out = []
    for i, c in enumerate(harm):
        r = ROOT[c.rstrip('m')]
        if push and i % 4 == 3:
            out += [(base + i + 1, st, r + (12 if st in (2, 10) else 0), 1 if st >= 12 else 2) for st in (0, 2, 4, 6, 8, 10, 12, 13, 14, 15)]
        else:
            out += [(base + i + 1, st, r + iv, d) for st, iv, d in RIFF_RHY]
    return out


def bass_long(base, harm):
    return [(base + i + 1, 0, ROOT[c.rstrip('m')], 15, 78) for i, c in enumerate(harm)]


# ══ LA MELODÍA ═══════════════════════════════════════════════════════════════════════════════════════════════════
HOOK = "0:F#5/3 3:F#5/3 6:A5/2 8:G#5/2 10:F#5/2 12:C#5/4"          # el gancho: grito en 3+3+2 y caída
HOOK_A = "0:A5/3 3:A5/3 6:C#6/2 8:B5/2 10:A5/2 12:F#5/4"            # (el gancho desde La y desde Do#)
HOOK_C = "0:C#6/3 3:C#6/3 6:F#6/2 8:E6/2 10:D6/2 12:C#6/4"
# v5 (0.5.43, el usuario: "la progresión / el desarrollo de las melodías es algo extraño"). Medido en la v4: 84 de
# 100 compases acababan en nota larga, 61 usaban los mismos dos ritmos y en el 42 % el compás siguiente empezaba a
# 5 semitonos o más del anterior — la melodía iba compás a compás, volviendo a empezar; y la B era el gancho copiado
# sobre cada raíz (Fa#→Re→Mi). Ahora FRASES de 8: el gancho abre, la respuesta cambia de ritmo y enlaza por grado, una
# cima hacia el compás 6-7, el 4 se queda abierto (en Sol#/Do#, el giro) y el 8 lleva a la frase siguiente.
M_A = [HOOK,
       "0:D5/2 2:E5/2 4:F#5/2 6:A5/6 12:G#5/2 14:F#5/2",                 # (sube por grados y enlaza)
       "0:F#5/3 3:F#5/3 6:A5/2 8:B5/2 10:C#6/6",                        # (la pregunta: sube a Do#)
       "0:B5/2 2:A5/2 4:E5/4 8:F#5/2 10:B5/2 12:G#5/4",                  # (el giro: abierta en Sol#)
       HOOK,
       "0:D5/2 2:E5/2 4:F#5/4 8:A5/2 10:B5/2 12:C#6/4",
       "0:F#6/3 3:C#6/3 6:A5/2 8:B5/2 10:C#6/2 12:A5/4",                 # (la cima)
       "0:A5/2 2:F#5/2 4:D5/4 8:F#5/2 10:B5/2 12:C#6/4"]
M_A2 = [HOOK_A,                                                         # la 2ª mitad: el gancho más arriba
        "0:G#5/2 2:A5/2 4:C#6/6 10:B5/2 12:A5/2 14:B5/2",
        HOOK_C,
        "0:E6/2 2:C#6/2 4:A5/4 8:B5/2 10:D6/2 12:C#6/4",
        "0:C#6/3 3:C#6/3 6:D6/2 8:E6/2 10:F#6/2 12:A6/4",                # (carrera a la cima)
        "0:A6/4 4:G#6/2 6:F#6/6 12:E6/2 14:D6/2",
        "0:C#6/3 3:A5/3 6:B5/2 8:C#6/4 12:A5/2 14:G#5/2",
        "0:F#5/4 4:A5/4 8:F#5/2 10:D5/2 12:C#5/2 14:E5/2"]
# A': la misma idea con otras respuestas
M_A_2 = [HOOK,
         "0:D5/2 2:E5/2 4:F#5/2 6:C#6/6 12:B5/2 14:A5/2",
         "0:F#5/3 3:F#5/3 6:A5/2 8:B5/2 10:C#6/6",
         "0:B5/2 2:A5/2 4:E5/4 8:F#5/2 10:B5/2 12:G#5/4",
         HOOK,
         "0:D5/2 2:E5/2 4:F#5/4 8:A5/2 10:B5/2 12:C#6/4",
         "0:C#6/2 2:D6/2 4:E6/2 6:F#6/6 12:E6/2 14:D6/2",
         "0:D6/2 2:A5/2 4:F#5/4 8:B5/2 10:F#5/2 12:G#5/4"]
M_A2_2 = [HOOK_A,
          "0:G#5/2 2:A5/2 4:C#6/6 10:B5/2 12:A5/2 14:B5/2",
          HOOK_C,
          "0:E6/2 2:C#6/2 4:A5/4 8:B5/2 10:D6/2 12:C#6/4",
          "0:C#6/3 3:C#6/3 6:D6/2 8:E6/2 10:F#6/2 12:A6/4",
          "0:A6/3 3:A6/3 6:G#6/2 8:F#6/4 12:E6/2 14:D6/2",
          "0:C#6/4 4:B5/2 6:A5/2 8:F#5/4 12:A5/2 14:G#5/2",
          "0:F#5/4 4:A5/4 8:B5/2 10:D6/2 12:C#6/4"]
# B: un grito en notas repetidas (el tresillo) que contesta con una línea que cruza los acordes por notas comunes
# (v4: el gancho copiado sobre cada raíz)
H_B = ['F#m', 'D', 'E', 'F#m', 'F#m', 'D', 'A', 'E']
M_B = ["0:C#6/2 3:C#6/2 6:C#6/2 8:A5/2 10:B5/2 12:C#6/4",
       "0:D6/4 4:E6/2 6:D6/2 8:A5/4 12:F#5/4",
       "0:B5/2 3:B5/2 6:B5/2 8:G#5/2 10:A5/2 12:B5/4",
       "0:C#6/3 3:A5/3 6:F#5/2 8:G#5/2 10:A5/2 12:C#6/4",
       "0:F#6/2 3:F#6/2 6:F#6/2 8:E6/2 10:D6/2 12:C#6/4",
       "0:D6/4 4:E6/2 6:F#6/2 8:D6/4 12:A5/4",
       "0:C#6/2 3:C#6/2 6:C#6/2 8:E6/2 10:A6/2 12:E6/4",
       "0:E6/4 4:B5/4 8:G#5/4 12:B5/4"]
M_B2_2 = ["0:A5/2 3:A5/2 6:A5/2 8:C#6/2 10:B5/2 12:A5/4",
          "0:D6/4 4:C#6/2 6:D6/2 8:F#6/4 12:D6/4",
          "0:B5/2 3:B5/2 6:B5/2 8:E6/2 10:F#6/2 12:G#6/4",
          "0:A6/4 4:G#6/2 6:F#6/2 8:C#6/4 12:A5/4",
          "0:F#5/2 3:F#5/2 6:A5/2 8:C#6/2 11:C#6/2 14:B5/2",
          "0:A5/3 3:F#5/3 6:A5/2 8:D6/4 12:F#6/4",
          "0:E6/3 3:C#6/3 6:E6/2 8:A6/4 12:G#6/2 14:F#6/2",
          "0:E6/4 4:B5/4 8:G#5/4 12:E5/4"]
# CLÍMAX: su propia línea, arriba, con la cima en el compás 4 y en el 12; 2ª mitad armonizada en terceras
M_CL = [HOOK_C,
        "0:D6/2 2:E6/2 4:F#6/4 8:A6/4 12:F#6/4",
        "0:E6/3 3:B5/3 6:E6/2 8:G#6/4 12:F#6/2 14:E6/2",
        "0:F#6/4 4:G#6/2 6:A6/2 8:F#6/4 12:C#6/4",
        "0:A6/2 3:A6/2 6:A6/2 8:G#6/2 10:F#6/2 12:C#6/4",
        "0:D6/3 3:F#6/3 6:A6/2 8:F#6/4 12:D6/4",
        "0:E6/3 3:C#6/3 6:E6/2 8:A6/4 12:G#6/2 14:F#6/2",
        "0:E6/4 4:B5/4 8:G#5/4 12:B5/4"]
M_CL2 = [HOOK_C,
         "0:D6/2 2:E6/2 4:F#6/4 8:D6/2 10:F#6/2 12:A6/4",
         "0:G#6/4 4:F#6/2 6:E6/2 8:B5/4 12:E6/4",
         "0:F#6/2 2:G#6/2 4:A6/4 8:G#6/2 10:F#6/2 12:C#6/4",
         "0:A6/2 3:A6/2 6:A6/2 8:F#6/2 11:F#6/2 14:E6/2",
         "0:D6/4 4:F#6/4 8:A6/4 12:F#6/2 14:E6/2",
         "0:E6/3 3:C#6/3 6:E6/2 8:A6/4 12:E6/4",
         "0:G#6/4 4:E6/4 8:B5/4 12:G#5/4"]
# A FINAL: variado; el gancho una OCTAVA arriba en el compás 13 (la cima de la canción)
M_F = [HOOK,
       "0:C#5/2 2:F#5/2 4:A5/6 10:G#5/2 12:A5/2 14:B5/2",
       HOOK_A,
       "0:E5/2 2:A5/2 4:C#6/4 8:D6/2 10:B5/2 12:C#6/4",
       HOOK,
       "0:D5/2 2:E5/2 4:F#5/4 8:A5/2 10:B5/2 12:C#6/4",
       "0:F#6/3 3:A6/3 6:G#6/2 8:F#6/4 12:C#6/4",
       "0:D6/2 2:A5/2 4:F#5/4 8:B5/2 10:D6/2 12:C#6/4",
       HOOK_A,
       "0:G#5/2 2:A5/2 4:C#6/6 10:B5/2 12:A5/2 14:B5/2",
       HOOK_C,
       "0:E6/2 2:C#6/2 4:A5/4 8:B5/2 10:D6/2 12:C#6/4",
       "0:F#6/3 3:F#6/3 6:A6/2 8:G#6/2 10:F#6/2 12:C#6/4",
       "0:D6/2 2:E6/2 4:F#6/4 8:A6/2 10:G#6/2 12:F#6/4",
       "0:C#6/3 3:A5/3 6:B5/2 8:C#6/4 12:A5/2 14:G#5/2",
       "0:F#5/4 4:A5/4 8:B5/2 10:F#5/2 12:G#5/4"]
HARM3 = {('C', k) for k in range(9, 13)} | {('F', k) for k in (1, 3, 5, 9, 11)}   # (sección, compás) con terceras

# RESPIRO: el gancho en valores largos (caja de música); el bajo en redondas
H_R = ['F#m', 'D', 'E', 'F#m', 'D', 'D', 'E', 'E']
M_R = ["0:C#6/8 8:A5/8", "0:F#5/8 8:D6/8", "0:E6/8 8:B5/8", "0:A5/8 8:F#5/8",
       "0:F#5/4 4:A5/4 8:D6/8", "0:D6/6 6:C#6/2 8:D6/8", "0:B5/8 8:G#5/8", "0:E5/4 4:G#5/4 8:B5/8"]
# SUBIDA: vuelve el riff; el gancho a trozos (las voces contestan en los huecos) y una carrera hacia el clímax
M_S = ["0:F#5/3 3:F#5/3 6:A5/2", "", "0:F#5/3 3:F#5/3 6:A5/2 8:C#6/4", "0:E5/3 3:A5/3 6:C#6/2 8:B5/4 12:G#5/4",
       HOOK, "0:F#5/2 2:A5/2 4:C#6/2 6:F#6/2 8:E6/2 10:F#6/2 12:C#6/4",
       "0:C#6/2 2:A5/2 4:F#5/2 6:A5/2 8:C#6/2 10:F#6/2 12:C#6/4", "0:D6/4 4:F#6/4 8:F#6/4 12:G#6/4"]
# CODA: el gancho se posa en la tónica
M_C = [HOOK, "0:F#5/3 3:F#5/3 6:A5/2 8:C#6/8", "0:C#6/3 3:A5/3 6:G#5/2 8:F#5/8",
       "0:E5/3 3:A5/3 6:C#6/2 8:B5/4 12:G#5/4", "0:F#5/16", "", "", ""]

# (sección, compases de melodía, armonía por compás, bajo, papel)
SECTIONS = [
    ('I', [''] * 8, RIFF_H, 'riff', 'intro'),
    ('A', M_A + M_A2, RIFF_H * 2, 'riff', 'A'),
    ('B', M_B + M_B2_2, H_B * 2, 'prog', 'B'),
    ('A2', M_A_2 + M_A2_2, RIFF_H * 2, 'riff', 'A2'),
    ('R', M_R, H_R, 'long', 'breath'),
    ('S', M_S, RIFF_H, 'riff', 'build'),
    ('C', M_CL + M_CL2, H_B * 2, 'prog', 'climax'),
    ('F', M_F, RIFF_H * 2, 'pops', 'final'),
    ('CO', M_C, RIFF_H, 'riff', 'coda'),
    ('O', [''] * 8, RIFF_H, 'riff', 'out'),
]


def song():
    mel, chords, role, sec, bass, starts = [], [], [], [], [], {}
    for name, bars, harm, bk, rl in SECTIONS:
        base = len(chords)
        starts[name] = base + 1
        nb = len(harm)
        mel.extend((base + b, st, n, d) for b, st, n, d in W.PH(*bars))
        for c in harm:
            chords.append(tuple(ch(x) for x in c) if isinstance(c, list) else (ch(c),) * 3)
        role += [rl] * nb; sec += [name] * nb
        if bk == 'riff':
            for k in range(nb // 8): bass.extend(bass_riff(base + 8 * k))
        elif bk == 'pops':
            for k in range(nb // 8): bass.extend(bass_riff(base + 8 * k, pops=True))
        elif bk == 'prog': bass.extend(bass_prog(base, harm))
        elif bk == 'long': bass.extend(bass_long(base, harm))
    return sorted(mel), chords, role, sec, bass, starts


SCALE_UP = sorted(SCALE)


def third_up(n):
    """La tercera diatónica de arriba (en Fa# menor natural)"""
    pcs = [p for p in range(n + 1, n + 6) if p % 12 in SCALE]
    return pcs[1]


def chord_at(chords, b, st):
    c = chords[b - 1]
    return c[0] if st < 8 else (c[1] if st < 12 else c[2])


def check(mel, chords):
    def tones(b, st):
        r, q = chord_at(chords, b, st)
        return {(r + i) % 12 for i in q}
    bad = [(b, st) for b, st, n, d in mel if d >= 4 and n % 12 not in tones(b, st)]
    out = [(b, st) for b, st, n, d in mel if n % 12 not in SCALE and n % 12 not in tones(b, st)]
    return bad, out


def loose(mel, tones_at):
    """Notas fuera del acorde que NO van por grado (entran o salen saltando) o duran ≥ 3 semicorcheas: lo que suena
    "raro" (el usuario, 0.5.42). Las de paso y las bordaduras, que entran y salen por grado, sí valen"""
    T = lambda m: (m[0] - 1) * 16 + m[1]
    bad = []
    for i, (b, st, n, d) in enumerate(mel):
        if n % 12 in tones_at(b, st): continue
        p = mel[i - 1] if i and T(mel[i - 1]) + mel[i - 1][3] >= T(mel[i]) - 2 else None
        x = mel[i + 1] if i + 1 < len(mel) and T(mel[i]) + d >= T(mel[i + 1]) - 2 else None
        if d >= 3 or not p or abs(n - p[2]) > 2 or not x or abs(x[2] - n) > 2: bad.append((b, st))
    return bad

def bass_vs_harmony(bass, chords):
    """Notas del bajo que NO son la raíz/5ª/octava del acorde que suena (la v1 fallaba aquí: debe dar 0)"""
    bad = 0
    for x in bass:
        b, st, n = x[0], x[1], x[2]
        r, q = chord_at(chords, b, st)
        if (n - r) % 12 not in (0, 7): bad += 1
    return bad, len(bass)


# ── INSTRUMENTOS (los de la casa; como Crab Tantrum) ──────────────────────────────────────────────────────────────
WAVES = [wavetable([1.0, 0.3, 0.1]), GN.CWAVES[0]]            # 0 colchón · 1 caja de música
I_SAWL = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.2, 6)}
I_PUL = {'vol': [11, 10, 9, 8, 8, 7], 'sus': 7, 'duty': [0.125, 0.25]}
I_UP = {'vol': [8, 7, 7, 6, 6, 5], 'sus': 5, 'duty': 0.25}
I_HARM = {'vol': [10, 9, 8, 8, 7, 7], 'sus': 7, 'duty': 0.25}
I_BOX = dict(GN.I_BELL, duty=1.0)
I_ECHO = {'vol': [5, 5, 4, 3], 'sus': 2, 'duty': 0.5}
I_PAD = {'vol': [2, 3, 4, 5, 5, 5], 'sus': 5, 'vib': (24, 0.12, 4.5), 'duty': 0.0}
I_CM = {'vol': [4, 6, 7, 7, 7, 6], 'sus': 6, 'vib': (18, 0.12, 5.0), 'duty': 0.0}
I_PULSE8 = {'vol': [7, 5, 3, 2, 1], 'sus': 0, 'duty': 0.125}
I_STAB = {'vol': [13, 10, 7, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_SHIM = {'vol': [6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
CRASH_SOFT = [9, 8, 7, 6, 5, 4, 3, 3, 2, 2, 1, 1]
TRES = (0, 6, 12)
LV = {'lead': 0, 'dbl': -6, 'up': -8, 'harm': -5, 'echo': -13, 'box': -2, 'pad': -12, 'cm': -10, 'pulses': -13, 'stabs': -7,
      'shim': -14, 'bass': 2, 'kick': -0.5, 'snare': -2.5, 'hat': -15, 'phat': -12, 'crash': -7, 'toms': -2,
      'nrise': -12, 'vox': -1, 'voxf': -6, 'chop': -2}
BACKING_UP = 3.0                  # (el acompañamiento, +3 dB respecto a la melodía: regla BACKING de la casa)
LUFS = -10.0
UP = {'A2', 'climax', 'final'}                                     # papeles con el pulso una octava arriba
STABS = {'A2', 'B', 'climax', 'final', 'coda'}


def build():
    mel, chords, role, sec, bass, starts = song()
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    keys = ('lead', 'dbl', 'up', 'harm', 'echo', 'box', 'pad1', 'pad2', 'cm', 'pulses', 'c1', 'c2', 'shim')
    Cn = {k: Chan(NF) for k in keys}
    NZ = {k: Noise(NF) for k in ('hat', 'phat', 'snare', 'crash', 'nrise')}
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

    # ── MELODÍA: sierra una octava abajo (cuerpo) + pulso; arriba, otro pulso en las secciones fuertes ──
    for b, st, n, d in mel:
        r_ = rl(b); t0 = tv(b, st)
        if r_ == 'breath':
            play(Cn['box'], t0, t0 + d * S16, n, I_BOX, q=q_n163, release=6)
            play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 4) * S16, n, I_ECHO, vs=0.7, release=2); continue
        play(Cn['lead'], t0, t0 + d * S16 * 0.93, n - 12, I_SAWL, q=q_saw, release=3)
        play(Cn['dbl'], t0, t0 + d * S16 * 0.93, n, I_PUL, release=2)
        if r_ in UP or (r_ == 'A' and pos(b) > 8): play(Cn['up'], t0, t0 + d * S16 * 0.9, n + 12, I_UP, release=2)
        if d >= 3: play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 3) * S16 * 0.8, n, I_ECHO, release=1)
        if (sec[b - 1], pos(b)) in HARM3:                                  # v3: el gancho armonizado en terceras
            h = third_up(n)
            r, q = chord_at(chords, b, st)
            if d < 4 or (h - r) % 12 in q:                                 # (una tercera larga que no sea del acorde, no)
                play(Cn['harm'], t0, t0 + d * S16 * 0.9, h, I_HARM, release=2)

    # ── ACOMPAÑAMIENTO (todo sobre la armonía del bajo) ──
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        vs = {'intro': 0.4 + 0.07 * (k - 1), 'out': max(0.3, 1 - 0.09 * (k - 1)), 'breath': 0.0}.get(r_, 1.0)
        if r_ == 'breath' and k <= 2: vs = (0.6, 0.35)[k - 1]               # (los pulsos se apagan dentro del respiro)
        thin = r_ == 'A2' and k >= 15                                      # (A' se vacía antes del respiro)
        if vs > 0:                                                         # pulsos de fondo: notas del acorde en corcheas
            for st in range(0, 16, 2):
                r, q = chord_at(chords, b, st)
                play(Cn['pulses'], tv(b, st), tv(b, st) + S16, 78 + (r - 78) % 12 + (q[2] if st % 4 == 0 else q[1]), I_PULSE8, vs=vs, release=0)
        if r_ in STABS and not (r_ == 'B' and k <= 4) and not thin:                    # golpes de quinta en el tresillo
            for st in TRES:
                r, q = chord_at(chords, b, st)
                root = 54 + (r - 54) % 12
                play(Cn['c1'], tv(b, st), tv(b, st) + 2.5 * S16, root, I_STAB, release=2)
                play(Cn['c2'], tv(b, st), tv(b, st) + 2.5 * S16, root + 7, I_STAB, release=2)
        if r_ == 'climax' or (r_ == 'final' and k > 8):                   # arpegio brillante en semicorcheas
            for st in range(16):
                r, q = chord_at(chords, b, st)
                play(Cn['shim'], tv(b, st), tv(b, st) + S16 * 0.7, 78 + (r - 78) % 12 + (q + (12,))[st % 4], I_SHIM, release=0)
        if r_ == 'breath':                                                 # colchón: el acorde del bajo, tenido
            r, q = chord_at(chords, b, 0)
            for j, iv in enumerate(q[1:]):
                play(Cn[('pad1', 'pad2')[j]], tv(b, 0), tv(b, 0) + 15.5 * S16, 64 + (r - 64) % 12 + iv, I_PAD, q=q_n163, release=6)
        if r_ == 'climax' and k > 8:                                       # contracanto: notas largas del acorde, por debajo
            for half, st in enumerate((0, 8)):
                r, q = chord_at(chords, b, st)
                play(Cn['cm'], tv(b, st), tv(b, st) + 7.5 * S16, 60 + (r - 60) % 12 + (q[1] if half == 0 else q[2]), I_CM, q=q_n163, release=4)

    # ── BATERÍA ──
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        last = k == LEN[sec[b - 1]]
        nxt = role[b] if b < NB else 'intro'
        for st in range(16):
            t = tv(b, st)
            if r_ in ('intro', 'out'):                                     # apertura / salida
                if st in (0, 8): hit(kick, TN.KICK, t, 0.9)
                if st % 4 == 2: NZ['phat'].hit(t, 1, [5, 3, 1])
                if (r_ == 'intro' and k >= 5 or r_ == 'out' and k <= 4) and st in (4, 12): snare(t, 0.7, [10, 6, 3, 1])
                if r_ == 'intro' and k == 8 and st >= 8: snare(t, 0.3 + (st - 8) * 0.07, [6 + (st - 8), 4, 2])
                if r_ == 'intro' and k == 1 and st == 0: NZ['crash'].hit(t, 3, CRASH_SOFT)
                continue
            if r_ == 'A2' and k >= 15:                                     # A' → respiro: la batería se retira
                if st in (0, 8): hit(kick, TN.KICK, t, 0.8 if k == 15 else 0.6)
                if st in (4, 12): snare(t, 0.6 if k == 15 else 0.4, [9, 5, 2] if k == 15 else [7, 4, 1])
                if k == 15 and st % 4 == 2: NZ['phat'].hit(t, 1, [4, 2, 1])
                continue
            if r_ == 'breath':                                             # respiro: medio tiempo, suave
                if st == 0: hit(kick, TN.KICK_DEEP, t, 0.6 if k <= 4 else 0.8)
                if st == 8 and k >= 3: snare(t, 0.5, [8, 4, 2])
                if st % 4 == 2 and k >= 5: NZ['phat'].hit(t, 1, [3, 2, 1])
                if last and st >= 8: snare(t, 0.3 + (st - 8) * 0.07, [5 + (st - 8), 4, 2])
                continue
            if r_ == 'build':                                              # subida: la caja se apura
                if st % 4 == 0: hit(kick, TN.KICK_DEEP, t, 1.0)
                step = 4 if k <= 3 else (2 if k <= 6 else 1)
                if st % step == 0: snare(t, 0.3 + 0.06 * k + 0.015 * st, [6 + k // 2 + st // 5, 4, 2])
                if k == 8 and st >= 8: hit(tom, W.TOMS[(st - 8) // 3 % 3], t, 0.7)
                continue
            big = r_ in ('climax', 'final')
            # bombo: en 1 y 3; en la B y el clímax, también el tresillo
            if st in (0, 8) or (r_ in ('B', 'climax') and st in (6, 14)) or (big and st == 10 and k % 2 == 0):
                hit(kick, TN.KICK_DEEP, t, 1.0)
            if st in (4, 12): snare(t, 1.0)
            elif st in (7, 15) and r_ != 'A': snare(t, 0.3, [6, 3, 1])
            if st % 4 == 2: NZ['phat'].hit(t, 1, [6, 4, 2, 1])
            elif st % 2 == 1: NZ['hat'].hit(t, 1, [3, 1])
            if r_ in ('B', 'climax', 'final', 'A2') and st in (3, 14) and b % 2 == 0: hit(tom, W.TOMS[{3: 2, 14: 1}[st]], t, 0.8)
            if last and st >= 12:                                          # redoble hacia la sección siguiente
                soft = nxt in ('breath', 'out')
                hit(tom, W.TOMS[min(2, st - 12)], t, 0.5 if soft else 0.75)
                if st >= 14 and not soft: snare(t, 0.45 + (st - 14) * 0.15, [8 + (st - 14), 5, 2])
            if st == 0:
                if k == 1 and r_ in ('A', 'B', 'climax', 'final'): NZ['crash'].hit(t, 3, CRASH)
                elif k == 1: NZ['crash'].hit(t, 3, CRASH_SOFT)
                elif big and k % 2 == 1: NZ['crash'].hit(t, 3, CRASH)
                elif k == 9: NZ['crash'].hit(t, 3, CRASH_SOFT)
        if r_ == 'build' and k == 7:                                       # soplido de ruido hacia el clímax
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
        'lead': cut(F.pulse_dac(F.render_saw(Cn['lead']))), 'dbl': pulse('dbl'), 'up': pulse('up'), 'harm': pulse('harm'),
        'echo': pulse('echo'),
        'box': wave('box'), 'pad': wave('pad1') + wave('pad2'), 'cm': wave('cm'), 'pulses': pulse('pulses'),
        'stabs': pulse('c1') + pulse('c2'), 'shim': pulse('shim'),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + noise('snare'),
        'hat': noise('hat'), 'phat': noise('phat'), 'crash': noise('crash'), 'nrise': noise('nrise'),
    }
    import soundfile as sf
    from scipy.signal import butter, sosfilt
    yb = FF.render_bass(bass)
    S['bass'] = np.zeros(n + tail); S['bass'][:min(len(yb), n + tail)] = yb[:n + tail]
    v, vsr = sf.read(FF.VOX)
    v = v.mean(1) if v.ndim == 2 else v
    assert vsr == SR
    vb = lambda b0, b1: v[int(b0 * BAR * SR):int(b1 * BAR * SR)].copy()
    def place(dst, seg, t, fade=0.02):
        k_ = int(fade * SR); seg = seg.copy(); seg[:k_] *= np.linspace(0, 1, k_); seg[-k_:] *= np.linspace(1, 0, k_)
        i = int(t * SR); dst[i:i + len(seg)] += seg[:len(dst) - i]
    S['vox'] = np.zeros(n + tail); S['voxf'] = np.zeros(n + tail); S['chop'] = np.zeros(n + tail)
    place(S['vox'], vb(0, 8), 0)                                           # apertura: 1ª mitad del bloque de voces
    place(S['vox'], vb(8, 16), tv(NB - 7, 0))                              # salida: 2ª mitad (cruza la costura seguida)
    place(S['voxf'], sosfilt(butter(2, 1400, btype='low', fs=SR, output='sos'), vb(0, 8)), tv(starts['R'], 0), fade=0.3)
    chops = [vb(2 * i, 2 * i + 1) for i in range(8)]                      # un compás de canto por cada compás par
    half = int(BAR * SR / 2)
    ci = 0
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        if r_ in ('A', 'A2', 'final', 'B', 'climax') and k in (8, 16):     # al cerrar la frase
            place(S['chop'], chops[ci % 8][:half], tv(b, 8), fade=0.01); ci += 1
        if r_ == 'build' and k in (1, 2):                                  # la subida: contestan al gancho a trozos
            place(S['chop'], chops[ci % 8][:half], tv(b, 8), fade=0.01); ci += 1
        if r_ == 'climax' and k in (5, 7, 13, 15):                         # el grito del clímax, con respuesta
            place(S['chop'], chops[ci % 8][:half // 2], tv(b, 12), fade=0.01); ci += 1
    S = {k: GN.fold(x, n, 0) for k, x in S.items() if np.abs(x).max() > 0}
    LEADS = ('lead', 'dbl', 'up', 'harm', 'echo', 'box')
    g = GN.level(S, {k: LV.get(k, -10) + (BACKING_UP if k not in LEADS else 0) for k in S}, 'lead')
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('pulses', 0.4) - sd('echo', 0.6) + sd('stabs', 0.25) + sd('shim', 0.4) - sd('pad', 0.25) + sd('hat', 0.3) \
        - sd('phat', 0.2) + sd('box', 0.2) - sd('cm', 0.25) + sd('up', 0.3) - sd('harm', 0.3)
    y = F.master(np.stack([x + side, x - side], 1), lufs=LUFS)
    GN.report(NAME, y, S, g, n)
    bad, out = check(mel, chords)
    bh, nbh = bass_vs_harmony(bass, chords)
    same = [(a[0], b_[0]) for i, a in enumerate(SECTIONS) for b_ in SECTIONS[i + 1:] if a[1] == b_[1] and any(a[1])]
    hooks = sum(t == HOOK for _, bars, *_ in SECTIONS for t in bars)
    print(f'  secciones con la MISMA melodía: {same or "ninguna"} · gancho literal en {hooks} compases')
    iv = np.abs(np.diff([m[2] for m in mel]))
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    print(f'  {BPM} BPM, {NB} compases ({NB * BAR:.1f} s, un bucle); melodía {len(mel)} notas; '
          f'batería {grp(("kick", "snare", "hat", "phat", "crash", "toms", "nrise")):.0f} %, bajo {grp(("bass",)):.0f} %, '
          f'melodía {grp(LEADS):.0f} %, voces {grp(("vox", "voxf", "chop")):.1f} %')
    print('  secciones: ' + ' · '.join(f'{nm} {(starts[nm] - 1) * BAR // 60:.0f}:{(starts[nm] - 1) * BAR % 60:04.1f}' for nm, *_ in SECTIONS))
    print(f'  notas largas fuera del acorde: {bad or "ninguna"} · fuera de escala y acorde: {out or "ninguna"}')
    sk = loose(mel, lambda b, st: {(chord_at(chords, b, st)[0] + i) % 12 for i in chord_at(chords, b, st)[1]})
    print(f'  notas fuera del acorde que saltan o se alargan: {sk or "ninguna"}')
    print(f'  bajo contra la armonía (ni raíz ni 5ª): {bh} de {nbh} · intervalo medio {iv.mean():.2f} st, '
          f'grados {np.mean(iv <= 2) * 100:.0f} %, saltos de octava {np.mean(iv >= 12) * 100:.0f} %, '
          f'a contratiempo {np.mean([m[1] % 4 != 0 for m in mel]) * 100:.0f} %')
    return y, mel


def preview(y):
    os.makedirs(PREVIEW, exist_ok=True)
    def enc(x, name):
        wav = os.path.join(PREVIEW, name + '.wav'); ogg = wav[:-4] + '.ogg'
        F.write_wav(wav, x)
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"'); os.remove(wav)
    enc(y, NAME + '_v5')
    k = int(8 * BAR * SR)
    enc(np.concatenate([y[-k:], y[:k]]), NAME + '_v5_costura')
    print(f'  previas en {PREVIEW}')


if __name__ == '__main__':
    y, mel = build()
    if not os.environ.get('REPORT'):
        preview(y)
        if os.environ.get('INSTALL'):
            GN.export(NAME, y, 0)
            W.write_mid(F.out(NAME, 'mid'), mel, BPM)
