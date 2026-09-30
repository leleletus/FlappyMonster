#!/usr/bin/env python3
# tools/music/boss_nes.py
# "Boss Battle" (assets/music/boss_battle_intro.wav + boss_battle_loop.wav)
# recreada como música de Famicom (2A03 + VRC6 + Namco 163, el motor de
# famicom.py) SIN partitura: todo sale del ANÁLISIS del audio original.
#
#   python3 tools/music/boss_nes.py   → assets/music/boss_nes_intro.ogg, boss_nes_loop.ogg (+ .mid)
#   SOLO=lead,bass python3 ...        → solo esos instrumentos
#
# Lo medido (ver el final del archivo):
#   · 140.381 BPM, Do menor. Intro: 9 compases (un Do sostenido que crece con un
#     redoble al final + 8 del riff). Bucle: 32 compases en 4 secciones de 8:
#       1-8   riff del bajo sincopado (Do–Do–Do… Mi♭–Mi♭ | Do–Do… Do# … Fa#)
#       9-16  quintas (power chords) de Dom y Fa en corcheas
#       17-24 la parte con MELODÍA: Dom–Sol, Fa–Sol, La♭–Si♭ (Do5 Sol5 Fa5 Mi♭5 / Si4…)
#       25-32 Dom con finales en Si♭ / Si / Do#
#   · Notas: transcripción polifónica con basic-pitch (validada con Tentacle
#     Tantrum: acierta el 80 % de la melodía y el 77 % del bajo) y VOTADA entre
#     los compases que se repiten (un error de transcripción no se repite).
#   · Batería: bombo doble en semicorcheas, caja en 2 y 4, hi-hat a
#     contratiempo; platillo en cada tiempo en la última sección.
#   · Timbres: huella de armónicos de bajo, quintas y melodía medida en las
#     notas transcritas → ondas del N163. Las quintas, "guitarra" chip: sierra
#     del VRC6 (fundamental) + pulso del VRC6 (quinta), con palm mute.
#   · Mezcla: ganancias por instrumento ajustadas al reparto por bandas del
#     original (mínimos cuadrados) y batería hasta su proporción percusión /
#     armonía (0.28).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from famicom import (SR, FRAME_S, frames_for, t_, Chan, hz, q_pulse, q_tri, q_vrc6, q_saw, q_n163, play,
                     render_pulse, render_tri, render_saw, dpcm, wavetable, render_wave, Noise, pulse_dac,
                     tnd_dac, band_power, OCT, write_wav)

BPM = 140.381
BAR = 4 * 60 / BPM
S16 = BAR / 16
HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, '..', '..', 'assets', 'music')
rng = np.random.default_rng(140)

# ── Partitura (transcrita y votada) ──────────────────────────────────────────
# Tipo de cada compás: el bucle alterna parejas; los sueltos llevan lo suyo
FORM_LOOP = ['L_a', 'L_b', 'L_a', 'L_b', 'L_a', 'L_b', 'L_a', 'L_8',
             'L_c', 'L_d', 'L_c', 'L_d', 'L_c', 'L_d', 'L_c', 'L_16',
             'L_e1', 'L_f1', 'L_19', 'L_20', 'L_e1', 'L_f1', 'L_23', 'L_24',
             'L_g', 'L_h', 'L_g', 'L_h', 'L_g', 'L_h', 'L_g', 'L_32']
FORM_INTRO = ['I_1', 'I_b', 'I_a', 'I_b', 'I_a', 'I_b', 'I_a', 'I_b', 'I_9']
# Fundamental por medio compás (para el "palm mute" continuo de la guitarra):
# Do casi siempre; Fa en 10-16; la sección de la melodía cambia
R = {'C': 0, 'F': 5, 'F#': 6, 'G': 7, 'Ab': 8, 'Bb': 10, 'B': 11}
ROOTS_LOOP = (['C C'] * 8 + ['C C', 'F F', 'C C', 'F F', 'C C', 'F F', 'C C', 'F F#'] +
              ['C F', 'G G', 'C C', 'C C', 'F F', 'G G', 'Ab Ab', 'Bb B'] + ['C C'] * 8)
ROOTS_INTRO = ['C C'] * 9
BASS = {
    'L_a': [(2, 36, 1), (5, 36, 1), (6, 36, 1), (14, 39, 1), (15, 39, 1)],
    'L_b': [(5, 36, 1), (6, 36, 1), (9, 37, 1), (14, 30, 2)],
    'L_8': [(5, 36, 2)],
    'L_c': [(2, 36, 1), (5, 36, 1), (6, 36, 1), (8, 36, 1), (14, 39, 1)],
    'L_d': [(0, 41, 2), (2, 41, 1), (3, 41, 1), (4, 41, 2), (5, 41, 1), (6, 41, 1), (8, 41, 2), (9, 41, 1), (10, 41, 1), (11, 41, 1), (12, 41, 2), (14, 39, 1), (15, 39, 1)],
    'L_16': [(2, 41, 1), (3, 41, 1), (5, 41, 2), (8, 43, 1), (9, 43, 1), (14, 42, 1), (15, 42, 1)],
    'L_e1': [(8, 44, 2), (9, 29, 1), (14, 41, 2)],
    'L_f1': [(4, 43, 1), (5, 43, 1), (6, 31, 1), (9, 43, 2), (12, 38, 1), (13, 38, 2), (14, 31, 1)],
    'L_19': [(1, 36, 1), (6, 36, 1)],
    'L_20': [(2, 36, 2), (14, 39, 1)],
    'L_23': [(0, 32, 1), (1, 32, 1), (6, 32, 1), (12, 39, 1), (13, 39, 1), (14, 44, 2)],
    'L_24': [(0, 34, 8), (8, 35, 8)],                               # (a mano: Si♭ → Si, sube al Do del 25)
    'L_g': [(2, 36, 2), (5, 36, 1), (6, 36, 1), (8, 39, 1), (9, 39, 1), (14, 41, 1)],
    'L_h': [(2, 36, 2), (5, 36, 1), (6, 36, 1), (8, 41, 1), (9, 41, 1), (14, 34, 1)],
    'L_32': [(2, 36, 1), (5, 36, 1), (6, 36, 1)],
    'I_1': [],
    'I_a': [(0, 39, 1), (1, 39, 1), (4, 36, 1), (11, 37, 1)],
    'I_b': [(0, 42, 1), (4, 36, 2), (7, 36, 1), (8, 36, 1), (10, 37, 1), (11, 37, 1)],
    'I_9': [(0, 39, 1), (1, 39, 1), (4, 36, 1), (7, 36, 1)],
}
CHORD = {                        # raíz de la quinta (power chord) por semicorchea
    'L_a': [(5, 48, 1), (9, 49, 1), (12, 48, 2)],
    'L_b': [(2, 48, 1), (3, 48, 1), (8, 49, 1), (9, 49, 1), (11, 48, 1), (12, 48, 2), (14, 49, 1)],
    'L_8': [],
    'L_c': [(0, 48, 1), (2, 48, 1), (3, 48, 1), (5, 48, 1), (6, 48, 1), (7, 48, 3), (8, 53, 1), (11, 53, 1), (12, 48, 1), (14, 60, 1)],
    'L_d': [(0, 53, 1), (2, 48, 1), (3, 48, 2), (4, 53, 1), (5, 48, 2), (6, 53, 2), (7, 53, 1), (8, 53, 2), (11, 53, 1), (12, 53, 2), (14, 60, 1)],
    'L_16': [(0, 53, 1), (3, 48, 1), (8, 62, 1)],
    'L_e1': [(0, 48, 2), (5, 63, 1), (6, 48, 2), (8, 56, 1), (14, 56, 2)],
    'L_f1': [(2, 48, 1), (4, 52, 1), (5, 62, 1), (8, 56, 1), (12, 55, 1), (14, 50, 2)],
    'L_19': [(2, 48, 1), (3, 48, 1), (5, 48, 2)],
    'L_20': [(5, 48, 1), (8, 49, 1), (9, 49, 1)],
    'L_23': [(1, 56, 1), (4, 51, 1)],
    'L_24': [(0, 58, 8), (8, 59, 8)],                               # (a mano, del espectro: quintas Si♭ y Si)
    'L_g': [(0, 48, 2), (2, 48, 2), (3, 48, 1), (5, 48, 1), (6, 48, 1), (7, 48, 1), (8, 51, 1), (11, 55, 1), (12, 48, 1), (13, 48, 1), (14, 62, 1)],
    'L_h': [(3, 48, 2), (5, 48, 1), (6, 48, 1), (8, 53, 2)],
    'L_32': [],
    'I_1': [],
    'I_a': [(0, 51, 1), (2, 52, 1), (4, 48, 1), (5, 48, 1), (7, 48, 1), (8, 48, 1), (10, 49, 2)],
    'I_b': [(4, 48, 1), (5, 48, 1), (7, 48, 1), (14, 48, 1)],
    'I_9': [(7, 48, 1)],
}
LEAD = {                         # compás del bucle → notas (semicorchea, nota, largo)
    17: [(4, 72, 1), (6, 79, 1), (8, 77, 3), (11, 75, 1), (13, 77, 1)],
    18: [(1, 71, 1), (4, 71, 1), (5, 65, 1), (9, 71, 2), (13, 71, 1), (14, 65, 1)],
    19: [(0, 75, 5), (6, 75, 2), (8, 74, 2)],
    20: [(8, 67, 2)],
    21: [(2, 68, 2), (4, 72, 1), (5, 68, 1), (6, 79, 2), (8, 77, 1)],
    22: [(1, 71, 1), (4, 71, 1), (5, 65, 1), (8, 71, 2), (14, 65, 1)],
    23: [(1, 75, 2), (6, 67, 1), (7, 75, 1), (11, 77, 2)],
    24: [],                                                          # (el Sol5 largo era un armónico: el original no tiene Sol ahí)
}


# ── Timbres (huellas medidas) ────────────────────────────────────────────────
WAVES = [
    wavetable([1.0, 0.64, 0.38, 0.13, 0.05, 0.06, 0.03, 0.1]),      # 0 bajo (sierra filtrada)
    wavetable([1.0, 0.52, 0.74, 0.58, 0.32, 0.2, 0.11, 0.08]),      # 1 melodía (brillante, 3º fuerte)
]
I_BASS = {'vol': [15, 15, 14, 13, 12], 'sus': 12, 'duty': 0.0}
I_BASS_FILL = {'vol': [10, 8, 6, 4], 'sus': 3, 'duty': 0.0}
I_TRI = {'vol': [15], 'sus': 15}
I_LEAD = {'vol': [15, 15, 14, 14, 13], 'sus': 13, 'vib': (12, 0.25, 6.0), 'duty': 1.0}
I_LEAD_P = {'vol': [9, 9, 8, 8, 7], 'sus': 7, 'vib': (12, 0.25, 6.0), 'duty': 0.25}
I_ECHO = {'vol': [5, 5, 4, 4, 3], 'sus': 3, 'duty': 0.125}
I_GTR = {'vol': [15, 14, 13, 12, 12, 11], 'sus': 11}                 # quinta sostenida (acento)
I_GTR5 = {'vol': [12, 11, 10, 10, 9], 'sus': 9, 'duty': 0.25}
I_CHUG = {'vol': [10, 6, 3, 1], 'sus': 0}                            # palm mute
I_CHUG5 = {'vol': [7, 4, 2], 'sus': 0, 'duty': 0.25}
# (octava con duty 12.5 %: el brillo de 1-8 kHz de una guitarra distorsionada)
I_GTR8 = {'vol': [9, 8, 8, 7, 7, 6], 'sus': 6, 'duty': 0.125}
I_CHUG8 = {'vol': [6, 3, 1], 'sus': 0, 'duty': 0.125}
I_SWELL = {'vol': [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], 'sus': 14}

# Batería: bombo metálico y corto (doble bombo), caja con cuerpo, hi-hat
_kt = t_(int(0.16 * SR))
KICK = dpcm(np.clip(1.3 * np.sin(2 * np.pi * np.cumsum(55 + 150 * np.exp(-_kt / 0.012)) / SR) * np.exp(-_kt / 0.05), -1, 1)
            + np.concatenate([rng.uniform(-0.7, 0.7, int(0.003 * SR)), np.zeros(len(_kt) - int(0.003 * SR))]))
SNARE_BODY = dpcm(np.sin(2 * np.pi * np.cumsum(180 + 80 * np.exp(-t_(int(0.09 * SR)) / 0.01)) / SR)
                  * np.exp(-t_(int(0.09 * SR)) / 0.03))
TOM = dpcm(np.sin(2 * np.pi * np.cumsum(110 + 90 * np.exp(-t_(int(0.2 * SR)) / 0.04)) / SR) * np.exp(-t_(int(0.2 * SR)) / 0.08))


def section(i, intro):
    if intro:
        return 'I1' if i == 0 else 'S1'
    return ('S1', 'S2', 'S3', 'S4')[i // 8]


def render_part(intro):
    form = FORM_INTRO if intro else FORM_LOOP
    roots = ROOTS_INTRO if intro else ROOTS_LOOP
    nb = len(form)
    NF = frames_for(nb * BAR)
    C = {k: Chan(NF) for k in ('bass', 'tri', 'lead', 'p1', 'p2', 'saw', 'v1', 'v2')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash', 'grit')}
    NS = int(NF * FRAME_S) + SR
    DM = {'kick': np.zeros(NS), 'snare': np.zeros(NS)}
    ev = {k: [] for k in ('lead', 'bass', 'gtr', 'drums')}

    def sample(buf, t, smp, g):
        i = int(t * SR); j = min(len(buf), i + len(smp))
        buf[i:j] = smp[:j - i] * g

    for i, key in enumerate(form):
        t0 = i * BAR
        sec = section(i, intro)
        rt = [R[x] for x in roots[i].split()]
        if sec == 'I1':
            # El Do sostenido que crece + redoble al final (entra el riff)
            play(C['saw'], t0 + S16, t0 + BAR, 48, I_SWELL, q=q_saw, vs=0.38)
            play(C['v1'], t0 + S16, t0 + BAR, 55, dict(I_SWELL, duty=0.25), q=q_vrc6, vs=0.38)
            play(C['v2'], t0 + S16, t0 + BAR, 60, dict(I_SWELL, duty=0.125), q=q_vrc6, vs=0.3)
            ev['gtr'] += [(t0 + S16, 48, BAR - S16), (t0 + S16, 55, BAR - S16)]
            for k in range(11, 16):
                sample(DM['snare'], t0 + k * S16, TOM, 0.6 + 0.08 * (k - 11))
                NZ['snare'].hit(t0 + k * S16, 3, [8 + k - 11, 6, 3, 1])
                ev['drums'].append((t0 + k * S16, 45, 0.05))
            NZ['crash'].hit(t0 + 14 * S16, 1, [2, 4, 6, 8, 10, 12, 14])
            play(C['bass'], t0 + 12 * S16, t0 + BAR, 36, I_BASS, q=q_n163)
            continue
        # Bajo: las notas transcritas + corcheas de la fundamental donde no hay
        bnotes = {k: (p, l) for k, p, l in BASS.get(key, [])}
        for k in range(16):
            r = rt[0 if k < 8 else 1]
            if k in bnotes:
                p, l = bnotes[k]
                while p < 29: p += 12
                play(C['bass'], t0 + k * S16, t0 + (k + l) * S16 * 0.95, p, I_BASS, q=q_n163)
                play(C['tri'], t0 + k * S16, t0 + (k + l) * S16 * 0.9, p, I_TRI, q=q_tri, release=0)
                ev['bass'].append((t0 + k * S16, p, l * S16 * 0.9))
            elif k % 2 == 0 and not any(k - d in bnotes and bnotes[k - d][1] > d for d in (1, 2, 3)):
                p = 36 + (r - 36) % 12
                play(C['bass'], t0 + k * S16, t0 + (k + 1) * S16, p, I_BASS_FILL, q=q_n163)
                ev['bass'].append((t0 + k * S16, p, S16))
        # Guitarra (quintas): acentos transcritos + palm mute en semicorcheas
        cnotes = {k: (p, l) for k, p, l in CHORD.get(key, [])}
        step = 2 if sec == 'S3' else 1                          # (con melodía, palm mute en corcheas)
        for k in range(16):
            r = rt[0 if k < 8 else 1]
            if k in cnotes:
                p, l = cnotes[k]
                p = 48 + (p - 48) % 12
                play(C['saw'], t0 + k * S16, t0 + (k + l) * S16 * 0.95, p, I_GTR, q=q_saw)
                play(C['v1'], t0 + k * S16, t0 + (k + l) * S16 * 0.95, p + 7, I_GTR5, q=q_vrc6)
                play(C['v2'], t0 + k * S16, t0 + (k + l) * S16 * 0.95, p + 12, I_GTR8, q=q_vrc6)
                # (la "fritura" de la distorsión: ruido a reloj lento — su energía cae en 2-5 kHz)
                nfr = max(3, int(l * S16 * 60))
                NZ['grit'].hit(t0 + k * S16, 7, [max(1, 7 - j // 3) for j in range(nfr)])
                ev['gtr'] += [(t0 + k * S16, p, l * S16), (t0 + k * S16, p + 7, l * S16)]
            elif k % step == 0 and not any(k - d in cnotes and cnotes[k - d][1] > d for d in (1, 2)):
                p = 48 + (r - 48) % 12
                play(C['saw'], t0 + k * S16, t0 + (k + 0.6) * S16, p, I_CHUG, q=q_saw, release=0)
                play(C['v1'], t0 + k * S16, t0 + (k + 0.6) * S16, p + 7, I_CHUG5, q=q_vrc6, release=0)
                play(C['v2'], t0 + k * S16, t0 + (k + 0.6) * S16, p + 12, I_CHUG8, q=q_vrc6, release=0)
                NZ['grit'].hit(t0 + k * S16, 7, [5, 3, 1])
        # Melodía (sección 3): N163 + pulso para el mordiente + eco
        if not intro and (i + 1) in LEAD:
            for k, p, l in LEAD[i + 1]:
                s, e = t0 + k * S16, t0 + (k + l) * S16 * 0.95
                play(C['lead'], s, e, p, I_LEAD, q=q_n163)
                play(C['p1'], s, e, p, I_LEAD_P)
                play(C['p2'], s + 3 * S16, e + 3 * S16, p, I_ECHO)
                ev['lead'].append((s, p, e - s))
        # Batería
        for k in range(16):
            acc = k % 4 == 0
            if sec != 'S3' or k % 2 == 0:
                sample(DM['kick'], t0 + k * S16, KICK, 1.0 if acc else 0.7)
                ev['drums'].append((t0 + k * S16, 36, 0.05))
        for k in (4, 12):
            sample(DM['snare'], t0 + k * S16, SNARE_BODY, 1.0)
            NZ['snare'].hit(t0 + k * S16, [1, 2, 3, 4], [15, 11, 8, 5, 3, 2, 1])
            ev['drums'].append((t0 + k * S16, 38, 0.1))
        for k in range(16):
            if k in (4, 12):
                continue
            if k % 4 == 2:
                NZ['hat'].hit(t0 + k * S16, 0, [11, 8, 5, 3, 1])       # contratiempo
            else:
                NZ['hat'].hit(t0 + k * S16, 0, [5, 3, 1])
            ev['drums'].append((t0 + k * S16, 42, 0.03))
        if sec == 'S4':
            for k in (0, 4, 8, 12):                                     # platillo en cada tiempo
                NZ['crash'].hit(t0 + k * S16, 2, [10, 9, 8, 7, 6, 5, 4, 3, 2, 1], short=0)
                ev['drums'].append((t0 + k * S16, 51, 0.1))
        if not intro and i in (0, 8, 16, 24):                           # platillo al empezar cada sección
            NZ['crash'].hit(t0, 2, [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1])
            ev['drums'].append((t0, 49, 0.4))
        if intro and i == 1:
            NZ['crash'].hit(t0, 2, [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1])
    return C, NZ, DM, ev, nb


def stems(C, NZ, DM, nb):
    n = int(nb * BAR * SR)
    cut = lambda x: x[:n] - np.mean(x[:n])
    return {
        'lead':  cut(render_wave(C['lead'], WAVES) * 0.0075),
        'p1':    cut(pulse_dac(render_pulse(C['p1']))),
        'p2':    cut(pulse_dac(render_pulse(C['p2']))),
        'bass':  cut(render_wave(C['bass'], WAVES) * 0.0075),
        'tri':   cut(tnd_dac(render_tri(C['tri']) / 8227.0)),
        'saw':   cut(render_saw(C['saw']) * 0.0075),
        'v1':    cut(render_pulse(C['v1']) * 0.0075),
        'v2':    cut(render_pulse(C['v2']) * 0.0075),
        'kick':  cut(tnd_dac((DM['kick'] + 64) / 22638.0)),
        'snare': cut(tnd_dac(NZ['snare'].render() / 12241.0)) + cut(tnd_dac((DM['snare'] + 64) / 22638.0)),
        'hat':   cut(tnd_dac(NZ['hat'].render() / 12241.0)),
        'crash': cut(tnd_dac(NZ['crash'].render() / 12241.0)),
        'grit':  cut(tnd_dac(NZ['grit'].render() / 12241.0)),
    }


BOUNDS = {'lead': (0.3, 2), 'p1': (0.1, 1.5), 'p2': (0.1, 1.5), 'bass': (0.3, 6), 'tri': (0.3, 4), 'saw': (0.3, 5),
          'v1': (0.2, 5), 'v2': (0.2, 6), 'grit': (0.1, 4), 'kick': (0.3, 6), 'snare': (0.3, 6), 'hat': (0.3, 6), 'crash': (0.2, 4)}
SECTIONS = {'S1': (0, 8), 'S2': (8, 16), 'S3': (16, 24), 'S4': (24, 32)}
PERC = ('kick', 'snare', 'hat', 'crash')
PERC_TARGET = 0.28                                                   # (HPSS del original)


def fit_gains(S, ref, t_off):
    from scipy.optimize import lsq_linear
    names = list(S)
    rows, tgt = [], []
    for sec, (b0, b1) in SECTIONS.items():
        Rp = band_power(ref, b0 * BAR + t_off, b1 * BAR + t_off)
        M = np.array([band_power(S[k], b0 * BAR, b1 * BAR) for k in names]).T
        for j in range(len(OCT)):
            rows.append(M[j] / Rp[j]); tgt.append(1.0)
    A, y = np.array(rows), np.array(tgt)
    lo = np.array([BOUNDS[k][0] ** 2 for k in names]); hi = np.array([BOUNDS[k][1] ** 2 for k in names])
    s = np.sum(A.sum(1) * y) / np.sum(A.sum(1) ** 2)
    return dict(zip(names, np.sqrt(lsq_linear(A * s, y, bounds=(lo, hi)).x)))


def perc_ratio(x):
    import librosa
    h, p = librosa.effects.hpss(x[:SR * 40].astype(np.float32))
    return np.sum(p ** 2) / np.sum(h ** 2)


def mixdown(S, g):
    solo = os.environ.get('SOLO')
    keep = set(solo.split(',')) if solo else set(S)
    x = sum(S[k] * g[k] for k in S if k in keep)
    from scipy.signal import butter, sosfilt
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    x = sosfilt(butter(1, 14000, btype='low', fs=SR, output='sos'), x)
    side = S['p2'] * g['p2'] * 0.35 - S['v1'] * g['v1'] * 0.25 + S['hat'] * g['hat'] * 0.2
    return np.stack([x + side, x - side], 1)


def write_midi(path, ev):
    import mido
    tpb = 480
    mf = mido.MidiFile(ticks_per_beat=tpb)
    meta = mido.MidiTrack(); mf.tracks.append(meta)
    meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(BPM)))
    for key, c, prog, name in (('lead', 0, 80, 'N163 + pulso (melodia)'), ('gtr', 1, 30, 'VRC6 sierra + pulso (quintas)'),
                               ('bass', 2, 38, 'N163 + triangulo (bajo)'), ('drums', 9, 0, 'Ruido + DPCM')):
        tr = mido.MidiTrack(); mf.tracks.append(tr)
        tr.append(mido.MetaMessage('track_name', name=name))
        if c != 9:
            tr.append(mido.Message('program_change', program=prog, channel=c))
        evs = []
        for t, n, d in ev[key]:
            a = int(round(t / (60 / BPM) * tpb)); b = max(a + 1, int(round((t + d) / (60 / BPM) * tpb)))
            evs += [(a, 1, n), (b, 0, n)]
        evs.sort(key=lambda z: (z[0], z[1]))
        last = 0
        for tick, on, n in evs:
            tr.append(mido.Message('note_on' if on else 'note_off', note=int(n), velocity=100 if on else 0,
                                   channel=c, time=tick - last))
            last = tick
    mf.save(path)


if __name__ == '__main__':
    import librosa
    # Bucle: ganancias ajustadas a su original; la intro usa las mismas
    C, NZ, DM, ev, nb = render_part(False)
    S = stems(C, NZ, DM, nb)
    ref, _ = librosa.load(os.path.join(OUT, 'boss_battle_loop.wav'), sr=SR, mono=True)
    g = fit_gains(S, ref, 0.032)
    x = sum(S[k] * g[k] for k in S)
    r = perc_ratio(x)
    boost = min(2.0, (PERC_TARGET / max(r, 1e-6)) ** 0.5)
    for k in PERC:
        g[k] *= boost
    print('  ganancias: ' + ' '.join(f'{k}={v:.2f}' for k, v in g.items()) + f'  (batería ×{boost:.2f})')
    loop = mixdown(S, g)
    # Bucle sin costura: lo que suena pasado el final (colas) se suma al principio
    Ci, NZi, DMi, evi, nbi = render_part(True)
    intro = mixdown(stems(Ci, NZi, DMi, nbi), g)
    level = 0.19 / (np.sqrt(np.mean(loop ** 2)) + 1e-9)             # (mismo nivel para las dos partes)
    for name, y, e in (('boss_nes_intro', intro, evi), ('boss_nes_loop', loop, ev)):
        y = np.tanh(y * level * 1.4) / 1.4
        wav = os.path.join(OUT, name + '.wav')
        write_wav(wav, y)
        write_midi(os.path.join(OUT, name + '.mid'), e)
        ogg = os.path.join(OUT, name + '.ogg')
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"')
        os.remove(wav)
        print(f'  {ogg}  {len(y) / SR:.2f} s')

# ── Cómo se analizó (para repetirlo) ─────────────────────────────────────────
#   · Tempo: rejilla ajustada a los ataques → 140.381 BPM (bucle: 32 compases
#     exactos desde 0.032 s; intro: desde 0.096 s).
#   · Forma: similitud entre compases (CQT por semicorchea) → parejas que se
#     repiten.
#   · Notas: basic-pitch (Spotify, modelo ONNX; entorno aparte con Python
#     3.11) sobre cada archivo; cada nota se coloca en su semicorchea y se VOTA
#     entre los compases del mismo tipo (se queda si aparece en más de la
#     mitad); los compases sueltos piden más confianza.
#   · Fundamentales por medio compás: croma de la parte armónica + graves.
#   · Batería: ataques por bandas en la parte percusiva, por semicorchea.
#   · Timbres: armónicos 1-10 sobre las notas transcritas (mediana).
