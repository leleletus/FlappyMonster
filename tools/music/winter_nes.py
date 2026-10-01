#!/usr/bin/env python3
# tools/music/winter_nes.py
# "Winter Fallympics" (assets/music/winter.ogg, la pelea de la Gran Bola de Nieve)
# como música de Famicom MUY cargada (2A03 + VRC6 + Namco 163, motor de famicom.py),
# a partir del MIDI de la canción (tools/music/ref/winter.mid, solo en local) y
# MEDIDA contra winter.ogg, que manda cuando no coinciden.
#
#   python3 tools/music/winter_nes.py          → assets/music/winter_nes.ogg (+ .mid)
#   SOLO=lead,bass python3 ...                  → solo esos instrumentos
#   REPORT=1 python3 ...                        → solo el informe de la mezcla (sin exportar)
#
# Lo medido (análisis con librosa, ver el informe al final):
#   185 BPM exactos, 4/4, 144 compases (186.8 s), la canción empieza a los 0.045 s del
#   ogg; Fa mayor. El MIDI coincide con el audio compás a compás (DTW por pulsos sin
#   desplazamiento salvo una zona ambigua 117-135 que repite material), salvo la
#   DINÁMICA: los compases 45-60 del ogg son un "break" ~10 dB más bajo y casi solo
#   batería (proporción percusión/armonía 1.5-2.4) mientras el MIDI sigue con acordes
#   → aquí el break baja los acordes y deja la batería delante, como el ogg. La intro
#   (1-4) va -4 dB y el final (141-144) se apaga como en el ogg.
#
# Instrumentos del MIDI → canales de la consola (las NOTAS intactas):
#   8-Bit Sawtooth (melodía 1-116)  → sierra del VRC6 + pulso 12.5 % una octava arriba
#   Slap Bass (5-132)               → triángulo de SUBGRAVE (2 octavas abajo; 1 si bajaría de Mi1)
#                                     + bajo N163 áspero una octava abajo, corto (el "slap"): el ogg
#                                     tiene el bajo en Fa1/Fa2 bajo el Fa3 del MIDI (medido por CQT)
#   Pop Synth (acordes 5-84)        → 2 pulsos del VRC6 (25 % / 50 %), golpes cortos
#   Music Box (21-128)              → campana N163 + ECO (la misma nota 3/16 después, flojita)
#   Scifi (53-144)                  → pulso del 2A03 12.5 % con arpegio de octava
#   Synth Bass (alto, 61-76), Smooth Synth (85-116), 8-Bit Square (117-132),
#   Synth Pluck (133-140), 8-Bit Triangle → melodías de cada sección: pulsos / N163
#   Flute (contramelodía suave)     → onda N163 suave
#   8-Bit Sine (notas largas 85-132)→ onda casi seno N163 (colchón)
#   Electric Drum Kit               → bombo / caja DPCM + ruido (caja, hats, platillos, toms)
# ENERGÍA (sin cambiar la canción): semicorcheas fantasma de hat entre los hats del
# MIDI en las secciones fuertes, redoble de caja al final de cada frase de 8 compases
# (si el MIDI no trae ya uno), crash en cada entrada de sección, bombo DPCM con clic de
# ataque, bajo doblado. Mezcla: NIVEL de cada grupo respecto a la melodía (LEVEL_DB,
# RMS mientras suena: batería y bajo a la par, acompañamiento audible detrás; ajustar
# las bandas al ogg dejaba los acordes y campanas a ~0 % y el bajo al 33 %) y después
# una EQ por bandas MEDIDA contra el ogg (eq_to_ref).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from famicom import (master, SR, FRAME_S, frames_for, t_, Chan, q_pulse, q_tri, q_vrc6, q_saw, q_n163, play,
                     render_pulse, render_tri, render_saw, dpcm, wavetable, render_wave, Noise, pulse_dac,
                     tnd_dac, band_power, OCT, write_wav, loudness, biquad)

BPM = 185.0
BAR = 4 * 60 / BPM
S16 = BAR / 16
NB = 144
OFF = 0.045                                  # la canción empieza así de tarde en winter.ogg
HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, '..', '..', 'assets', 'music')
MIDI_IN = os.path.join(HERE, 'ref', 'winter.mid')
REF = os.path.join(OUT, 'winter.ogg')
rng = np.random.default_rng(144)

# Secciones (compases, ambos incluidos) medidas en el ogg: (nombre, a, b, nivel relativo)
SECT = [('intro', 1, 4), ('A', 5, 20), ('B', 21, 44), ('break', 45, 60), ('C', 61, 84), ('D', 85, 116),
        ('E', 117, 140), ('fin', 141, 144)]
LOUD = set(range(5, 45)) | set(range(61, 141))          # secciones fuertes (hats fantasma, redobles)
BREAK = set(range(45, 61))


# ── MIDI ─────────────────────────────────────────────────────────────────────
def load_midi():
    import mido
    m = mido.MidiFile(MIDI_IN)
    sec = 60 / BPM / m.ticks_per_beat
    tracks = {}
    for t in m.tracks:
        name = next((e.name for e in t if e.type == 'track_name'), '?')
        ab, on, out = 0, {}, []
        for e in t:
            ab += e.time
            if e.type == 'note_on' and e.velocity > 0:
                on[e.note] = (ab, e.velocity)
            elif e.type in ('note_off', 'note_on') and e.note in on:
                s, v = on.pop(e.note)
                out.append((s * sec, (ab - s) * sec, e.note, v))
        if out:
            tracks[name] = sorted(out)
    return tracks


def voices(notes, n):
    vs, ends = [[] for _ in range(n)], [-1.0] * n
    for s, d, m, v in sorted(notes, key=lambda x: (x[0], -x[2])):
        free = [i for i in range(n) if ends[i] <= s + 1e-4]
        i = free[0] if free else int(np.argmin(ends))
        vs[i].append((s, d, m, v))
        ends[i] = s + d
    return vs


def bar_of(t):
    return int(t / BAR + 1e-6) + 1


# ── Timbres ──────────────────────────────────────────────────────────────────
WAVES = [
    wavetable([1.0, 0, 0, 0.35, 0, 0, 0, 0, 0, 0.12]),             # 0 campana (caja de música)
    wavetable([1.0, 0.9, 0.7, 0.6, 0.45, 0.4, 0.3]),               # 1 bajo áspero (casi sierra)
    wavetable([1.0, 0.25, 0.08]),                                  # 2 flauta suave
    wavetable([1.0, 0.04]),                                        # 3 casi seno (colchón)
    wavetable([1.0, 0.6, 0.45, 0.3, 0.22, 0.15]),                  # 4 lead brillante
    wavetable([1.0, 0, 0.5, 0, 0.3, 0, 0.18]),                     # 5 hueco (impares)
]
I_SAW = {'vol': [15, 15, 14, 14, 13], 'sus': 13, 'vib': (14, 0.2, 5.6)}
I_SHEEN = {'vol': [8, 7, 7, 6, 6], 'sus': 6, 'duty': 0.125, 'vib': (14, 0.2, 5.6)}
I_TRI = {'vol': [15], 'sus': 15}
I_BASSN = {'vol': [14, 13, 11, 9, 7, 5], 'sus': 4, 'duty': 1.0}
I_CHORD = {'vol': [13, 12, 10, 9, 8, 7, 7, 6], 'sus': 6, 'duty': [0.5, 0.25]}
I_CHORD2 = {'vol': [11, 10, 9, 8, 7, 6, 6, 5], 'sus': 5, 'duty': [0.25, 0.125]}
I_BELL = {'vol': [15, 13, 12, 10, 9, 8, 7, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1], 'sus': 1, 'duty': 0.0}
I_ECHO = {'vol': [6, 6, 5, 4, 4, 3, 3, 2, 2, 1], 'sus': 1, 'duty': 0.0}
I_ARP = {'vol': [11, 10, 9, 9, 8], 'sus': 8, 'duty': 0.125, 'arp_speed': 2}
I_LEAD_P = {'vol': [13, 13, 12, 12, 11], 'sus': 11, 'duty': [0.125, 0.25, 0.5], 'vib': (14, 0.2, 5.8)}
I_LEAD_N = {'vol': [14, 14, 13, 13, 12], 'sus': 12, 'duty': 4.0, 'vib': (14, 0.2, 5.6)}
I_PLUCK = {'vol': [14, 11, 9, 7, 5, 4, 3, 2], 'sus': 2, 'duty': 4.0}
I_FLUTE = {'vol': [6, 8, 9, 10, 10], 'sus': 10, 'duty': 2.0, 'vib': (16, 0.15, 5.0)}
I_PAD = {'vol': [5, 7, 9, 10, 11, 11], 'sus': 11, 'duty': 3.0, 'vib': (24, 0.1, 4.5)}
I_TRI_LEAD = {'vol': [11, 11, 10, 10], 'sus': 10, 'duty': 0.25, 'vib': (16, 0.18, 5.5)}

# Batería (muestras DPCM de 1 bit): bombo con clic y caída de tono, caja corta y brillante
_kt = t_(int(0.28 * SR))
KICK = dpcm(np.clip(1.45 * np.sin(2 * np.pi * np.cumsum(52 + 190 * np.exp(-_kt / 0.014)) / SR) * np.exp(-_kt / 0.11), -1, 1)
            + np.concatenate([rng.uniform(-0.7, 0.7, int(0.003 * SR)), np.zeros(len(_kt) - int(0.003 * SR))]))
_st = t_(int(0.12 * SR))
SNARE = dpcm(np.clip(1.3 * np.sin(2 * np.pi * np.cumsum(200 + 120 * np.exp(-_st / 0.007)) / SR) * np.exp(-_st / 0.04), -1, 1))


def tom(f):
    n = int(0.22 * SR)
    return dpcm(np.sin(2 * np.pi * np.cumsum(f + f * 0.8 * np.exp(-t_(n) / 0.03)) / SR) * np.exp(-t_(n) / 0.09))


TOMS = {41: tom(85), 43: tom(100), 45: tom(115), 47: tom(140), 48: tom(165), 50: tom(195)}


# ── Canción ──────────────────────────────────────────────────────────────────
class Song:
    def __init__(self, nbars):
        self.nb = nbars
        self.nf = frames_for(nbars * BAR)
        self.C, self.kind, self.ev = {}, {}, {}
        self.NZ = {k: Noise(self.nf) for k in ('hat', 'snare', 'crash')}
        ns = int(self.nf * FRAME_S) + SR
        self.DM = {'kick': np.zeros(ns), 'snare': np.zeros(ns), 'tom': np.zeros(ns)}

    def chan(self, name, kind):
        if name not in self.C:
            self.C[name] = Chan(self.nf)
            self.kind[name] = kind
        return self.C[name]

    def note(self, name, kind, t0, dur, m, inst, vs=1.0, gate=0.92, midi='lead', release=3, arp=None):
        q = {'pulse': q_pulse, 'tri': q_tri, 'saw': q_saw, 'vrc6': q_vrc6, 'n163': q_n163}[kind]
        g = max(dur * gate, 1.2 / 60)
        play(self.chan(name, kind), t0, t0 + g, m, inst, q=q, vs=vs, release=0 if kind == 'tri' else release, arp=arp)
        self.ev.setdefault(midi, []).append((t0, m, g))

    def sample(self, buf, t, smp, g):
        d = self.DM[buf]
        i = int(t * SR); j = min(len(d), i + len(smp))
        d[i:j] = np.where(np.abs(smp[:j - i] * g) > np.abs(d[i:j]), smp[:j - i] * g, d[i:j])

    def drum(self, t, n, vel=1.0):
        if n in (35, 36):
            self.sample('kick', t, KICK, vel)
        elif n in (38, 40):
            self.sample('snare', t, SNARE, vel)
            self.NZ['snare'].hit(t, [1, 2, 3, 4, 5], [int(x * vel + 0.5) for x in [15, 13, 11, 9, 7, 5, 4, 3, 2, 1]])
        elif n in (42, 44):
            self.NZ['hat'].hit(t, 0, [int(x * vel + 0.5) for x in ([9, 6, 3, 1] if n == 42 else [6, 4, 2])])
        elif n == 46:
            self.NZ['hat'].hit(t, 0, [int(x * vel + 0.5) for x in [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]])
        elif n in TOMS:
            self.sample('tom', t, TOMS[n], vel)
        elif n in (49, 57):
            self.NZ['crash'].hit(t, 2, [15, 14, 13, 12, 11, 10, 10, 9, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1])
        self.ev.setdefault('drums', []).append((t, n, 0.08))

    def stems(self):
        n = int(self.nb * BAR * SR)
        cut = lambda x: np.concatenate([x, np.zeros(max(0, n + 3 * SR - len(x)))])[:n + 2 * SR] - np.mean(x[:n])
        out = {}
        for name, ch in self.C.items():
            k = self.kind[name]
            if k == 'pulse':
                x = pulse_dac(render_pulse(ch))
            elif k == 'tri':
                x = tnd_dac(render_tri(ch) / 8227.0)
            elif k == 'saw':
                x = render_saw(ch) * 0.0075
            elif k == 'vrc6':
                x = render_pulse(ch) * 0.0075
            else:
                x = render_wave(ch, WAVES) * 0.0075
            out[name] = cut(x)
        out['kick'] = cut(tnd_dac((self.DM['kick'] + 64) / 22638.0))
        out['snare'] = cut(tnd_dac(self.NZ['snare'].render() / 12241.0)) + cut(tnd_dac((self.DM['snare'] + 64) / 22638.0))
        out['tom'] = cut(tnd_dac((self.DM['tom'] + 64) / 22638.0))
        out['hat'] = cut(tnd_dac(self.NZ['hat'].render() / 12241.0))
        out['crash'] = cut(tnd_dac(self.NZ['crash'].render() / 12241.0))
        return out


def in_bars(notes, bars):
    return [x for x in notes if bar_of(x[0]) in bars]


# ── Arreglo ──────────────────────────────────────────────────────────────────
def build(T):
    S = Song(NB)
    # Melodía (sierra): sierra del VRC6 (la voz de arriba) + brillo de pulso una
    # octava arriba; las otras voces (acordes de la melodía) en un pulso del VRC6
    saw = voices(T['8-Bit Sawtooth'], 3)
    for s, d, m, v in saw[0]:
        S.note('lead_saw', 'saw', s, d, m, I_SAW, vs=min(1, v / 80), midi='lead')
        S.note('lead_sheen', 'pulse', s, d, m + 12, I_SHEEN, vs=min(1, v / 80), midi='lead')
    for i in (1, 2):
        for s, d, m, v in saw[i]:
            S.note('lead_h%d' % i, 'vrc6', s, d, m, I_CHORD2, vs=min(1, v / 90), midi='lead')
    # Melodías de otras secciones
    for name, key, kind, inst in (('Synth Bass (Classic)', 'lead2', 'pulse', I_LEAD_P),
                                  ('Smooth Synth (Classic)', 'lead3', 'n163', I_LEAD_N),
                                  ('8-Bit Triangle', 'lead2', 'pulse', I_TRI_LEAD)):
        for s, d, m, v in T.get(name, []):
            S.note(key, kind, s, d, m, inst, vs=min(1, 0.55 + v / 150), midi='lead')
    for i, vs in enumerate(voices(T.get('8-Bit Square', []), 2)):
        for s, d, m, v in vs:
            S.note('lead4_%d' % i, 'pulse', s, d, m, I_LEAD_P, vs=min(1, 0.6 + v / 150) * (1 if i == 0 else 0.8), midi='lead')
    for i, vs in enumerate(voices(T.get('Synth Pluck', []), 2)):
        for s, d, m, v in vs:
            S.note('pluck%d' % i, 'n163', s, d, m, I_PLUCK, vs=min(1, 0.55 + v / 150), midi='keys')
    # Bajo: triángulo de subgrave (el ogg lo tiene en Fa1 bajo el Fa3 del MIDI) + N163
    # áspero una octava abajo, cortito (el "slap")
    for s, d, m, v in T['Slap Bass']:
        sub = m - 24 if m - 24 >= 28 else m - 12
        slap = m - 12 if m - 12 >= 36 else m
        S.note('bass_tri', 'tri', s, d, sub, I_TRI, gate=0.85, midi='bass')
        S.note('bass_n', 'n163', s, min(d, S16 * 1.6), slap, I_BASSN, vs=min(1, 0.6 + v / 160), gate=0.9, midi='bass')
    # Acordes (Pop Synth): 2 pulsos del VRC6, golpes cortos; en el break, más flojos
    for i, vs in enumerate(voices(T['Pop Synth (Classic)'], 2)):
        for s, d, m, v in vs:
            k = 0.2 if bar_of(s) in BREAK else 1.0
            S.note('chord%d' % i, 'vrc6', s, d, m, I_CHORD if i == 0 else I_CHORD2, vs=min(1, 0.6 + v / 120) * k,
                   gate=0.8, midi='keys')
    # Caja de música: campana + eco 3/16 después (truco de eco de los juegos de NES)
    for i, vs in enumerate(voices(T['Music Box'], 2)):
        for s, d, m, v in vs:
            S.note('bell%d' % i, 'n163', s, d, m, I_BELL, vs=min(1, v / 90), gate=1.2, midi='keys', release=6)
            if i == 0:
                S.note('echo', 'n163', s + 3 * S16, d, m, I_ECHO, gate=1.2, midi='keys', release=4)
    # Scifi: pulso 12.5 % con arpegio de octava (centelleo)
    for s, d, m, v in T['Scifi']:
        k = 0.45 if bar_of(s) in BREAK else 1.0
        S.note('arp', 'pulse', s, d, m, I_ARP, vs=min(1, 0.55 + v / 150) * k, midi='keys', arp=[0, 12])
    # Flauta (contramelodía suave) y seno (notas largas)
    for i, vs in enumerate(voices(T['Flute'], 2)):
        for s, d, m, v in vs:
            S.note('flute%d' % i, 'n163', s, d, m, I_FLUTE, vs=min(1, 0.5 + v / 100), midi='keys')
    for i, vs in enumerate(voices(T['8-Bit Sine'], 2)):
        for s, d, m, v in vs:
            S.note('pad%d' % i, 'n163', s, d, m, I_PAD, vs=min(1, 0.55 + v / 120), gate=0.98, midi='keys')
    # Batería del MIDI
    drums = T['Electric Drum Kit']
    has = {}
    for s, d, n, v in drums:
        vel = min(1.0, 0.55 + v / 110)
        if bar_of(s) in BREAK and n in (42, 44, 46):
            vel *= 1.1                                         # (el break es de batería)
        S.drum(s, n, vel)
        has.setdefault(bar_of(s), set()).add((round((s % BAR) / S16), n))
    # Energía: hats fantasma en las semicorcheas libres de las secciones fuertes
    for b in sorted(LOUD):
        hit = has.get(b, set())
        steps_hat = {k for k, n in hit if n in (42, 44, 46)}
        if len(steps_hat) < 4:
            continue                                           # (sin hats en el MIDI: no se inventan)
        for k in range(16):
            if k % 2 == 1 and k not in steps_hat:
                S.NZ['hat'].hit((b - 1) * BAR + k * S16, 0, [4, 2, 1])
    # Redoble de caja al final de cada frase de 8 compases (si no hay ya toms / caja allí)
    for b in range(8, NB, 8):
        if b not in LOUD or (b + 1) not in LOUD and (b + 1) not in BREAK:
            continue
        busy = {k for k, n in has.get(b, set()) if n in (38, 40) or n in TOMS}
        tail = [k for k in range(12, 16) if k not in busy]
        if len(busy & set(range(12, 16))) >= 2:
            continue
        for k in tail:
            S.drum((b - 1) * BAR + k * S16, 40, 0.55 + 0.12 * (k - 12))
    # Intro: el ogg tiene un golpe grave (Si1-Do2) que el MIDI no trae → bombo en 1 y 3
    for b in range(1, 5):
        for beat in (0, 2):
            S.drum((b - 1) * BAR + beat * BAR / 4, 36, 0.85)
    # Crash en cada entrada de sección (si el MIDI no lo trae)
    for _, a, _b in SECT[1:]:
        if not any(n in (49, 57) and k == 0 for k, n in has.get(a, set())):
            S.drum((a - 1) * BAR, 49, 1.0)
    return S


# ── Mezcla ───────────────────────────────────────────────────────────────────
GROUPS = {'lead': ('lead',), 'bass': ('bass',), 'chords': ('chord',), 'bell': ('bell', 'echo'),
          'arp': ('arp',), 'soft': ('flute', 'pad', 'pluck'), 'kick': ('kick',), 'snare': ('snare', 'tom'),
          'cymbals': ('hat', 'crash')}


def group_of(k):
    return next(g for g, pre in GROUPS.items() if any(k.startswith(p) for p in pre))


def sec_span(a, b):
    return (a - 1) * BAR, b * BAR


def band_rms(x, t0, t1, lo=1000, hi=5000):
    from scipy.signal import butter, sosfilt
    seg = x[int(t0 * SR):int(t1 * SR)]
    if not len(seg):
        return 0.0
    y = sosfilt(butter(2, [lo, hi], btype='band', fs=SR, output='sos'), seg)
    return float(np.sqrt(np.mean(y ** 2)))


# Nivel de cada grupo respecto a la melodía (dB, RMS mientras suena): la batería y el
# bajo a la par que la melodía, el acompañamiento audible pero detrás
LEVEL_DB = {'lead': 0, 'bass': -1, 'kick': 1.5, 'snare': -0.5, 'cymbals': -7, 'chords': -4, 'bell': -3, 'arp': -6,
            'soft': -7}
BREAK_DB = -5.0                     # el break (45-60) baja así (el ogg: ~-10 dB y casi solo batería)


def active_rms(x, win=0.1):
    """RMS de los tramos (de 0.1 s) en que el instrumento suena (> -30 dB de su máximo)"""
    n = int(win * SR)
    k = len(x) // n
    if k == 0:
        return 0.0
    r = np.sqrt(np.mean(x[:k * n].reshape(k, n) ** 2, axis=1))
    on = r > r.max() * 10 ** (-30 / 20)
    return float(np.sqrt(np.mean(r[on] ** 2))) if on.any() else 0.0


def balance(S, ref):
    g = {k: 1.0 for k in S}
    groups = [gr for gr in GROUPS if any(group_of(k) == gr for k in S)]
    lvl = {gr: active_rms(sum(S[k] for k in S if group_of(k) == gr)) for gr in groups}
    for gr in groups:
        if lvl[gr] > 0:
            want = lvl['lead'] * 10 ** (LEVEL_DB[gr] / 20)
            for k in S:
                if group_of(k) == gr:
                    g[k] = want / lvl[gr]
    # (dentro de la batería: el reparto bombo / caja / platillos sale de LEVEL_DB)
    print('  grupos (dB de partida → ganancia): ' + ' '.join(f'{gr}×{want_g:.2f}' for gr, want_g in
                                                            ((gr, next(g[k] for k in S if group_of(k) == gr)) for gr in groups)))
    return g


def eq_to_ref(y, ref):
    """Corrección de timbre MEDIDA: la forma del espectro por bandas de octava de la
    mezcla frente a la del ogg en las secciones fuertes; campanas de ±5 dB como mucho
    (70 % de la diferencia: se acerca sin copiar el "crunch" del original)"""
    mono = y.mean(1)
    dev = np.zeros(len(OCT))
    n = 0
    for name, a, b in SECT:
        if name in ('intro', 'break', 'fin'):
            continue
        t0, t1 = sec_span(a, b)
        P = band_power(mono, t0, t1); R = band_power(ref, t0 + OFF, t1 + OFF)
        dev += 10 * np.log10((P / P.sum() + 1e-12) / (R / R.sum() + 1e-12)); n += 1
    dev /= n
    gains = np.clip(-0.7 * dev, -5, 5)
    for (lo, hi), gdb in zip(OCT, gains):
        if abs(gdb) >= 0.5 and hi <= 16000:
            y = biquad(y, 'peak', np.sqrt(lo * hi), gdb, 1.1)
    print('  EQ por bandas: ' + ' '.join(f'{int(np.sqrt(lo * hi))}Hz {gdb:+.1f}' for (lo, hi), gdb in zip(OCT, gains)))
    return y


def mixdown(S, g, n):
    solo = os.environ.get('SOLO')
    keep = set(solo.split(',')) if solo else None
    x = sum(S[k] * g.get(k, 1.0) for k in S if keep is None or any(k.startswith(w) for w in keep))
    from scipy.signal import butter, sosfilt
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    x = sosfilt(butter(1, 15000, btype='low', fs=SR, output='sos'), x)
    side = np.zeros_like(x)
    for k, p in (('lead_sheen', 0.25), ('lead_h1', -0.3), ('lead_h2', 0.3), ('chord0', -0.3), ('chord1', 0.3),
                 ('bell1', 0.3), ('echo', -0.4), ('arp', 0.25), ('flute0', -0.25), ('flute1', 0.25), ('hat', 0.2),
                 ('pad1', -0.2)):
        if k in S and (keep is None or any(k.startswith(w) for w in keep)):
            side += S[k] * g.get(k, 1.0) * p
    y = np.stack([x + side, x - side], 1)
    # El break, más bajo (rampa de un pulso a cada lado)
    a, b = (min(BREAK) - 1) * BAR, max(BREAK) * BAR
    t = np.arange(len(y)) / SR
    ramp = np.clip(np.minimum(t - a, b - t) / (BAR / 4), 0, 1)
    y *= (1 + (10 ** (BREAK_DB / 20) - 1) * ramp)[:, None]
    return y


def fold_tail(y, n):
    out = y[:n].copy()
    tail = y[n:]
    out[:len(tail)] += tail[:n]
    return out


# ── Informe (números: no se ha escuchado) ────────────────────────────────────
def report(y, ref, S, g):
    import librosa
    mono = y.mean(1) if y.ndim == 2 else y
    print('  sonoridad: %.1f LUFS (original %.1f)' % (loudness(y), loudness(ref[:, None].repeat(2, 1))))
    print('  sección    dB(nes-orig por bandas 63-250-1k-4k-8k)   perc/arm nes  orig')
    import librosa as lr
    for name, a, b in SECT:
        t0, t1 = sec_span(a, b)
        P = band_power(mono, t0, t1); R = band_power(ref, t0 + OFF, t1 + OFF)
        P = P / P.sum(); R = R / R.sum()
        d = [10 * np.log10((P[j] + 1e-12) / (R[j] + 1e-12)) for j in (1, 2, 4, 6, 7)]
        seg = mono[int(t0 * SR):int(min(t1, t0 + 12) * SR)].astype(np.float32)
        rseg = ref[int((t0 + OFF) * SR):int((min(t1, t0 + 12) + OFF) * SR)].astype(np.float32)
        h, p = lr.effects.hpss(seg); rh, rp = lr.effects.hpss(rseg)
        print('  %-6s %s   %.2f  %.2f' % (name, ' '.join('%+5.1f' % v for v in d),
                                         np.sum(p ** 2) / np.sum(h ** 2), np.sum(rp ** 2) / np.sum(rh ** 2)))
    # Reparto de energía por grupos (toda la canción)
    e = {}
    for k in S:
        e[group_of(k)] = e.get(group_of(k), 0) + float(np.mean((S[k] * g[k]) ** 2))
    tot = sum(e.values())
    print('  energía: ' + ' '.join(f'{k} {100 * v / tot:.0f}%' for k, v in sorted(e.items(), key=lambda z: -z[1])))
    # Dinámica por secciones (dB relativos a la sección más fuerte) frente al original
    lv = []
    for name, a, b in SECT:
        t0, t1 = sec_span(a, b)
        r1 = np.sqrt(np.mean(mono[int(t0 * SR):int(t1 * SR)] ** 2))
        r2 = np.sqrt(np.mean(ref[int((t0 + OFF) * SR):int((t1 + OFF) * SR)] ** 2))
        lv.append((name, 20 * np.log10(r1), 20 * np.log10(r2)))
    m1 = max(v[1] for v in lv); m2 = max(v[2] for v in lv)
    print('  dinámica (dB bajo la sección más fuerte): ' + ' '.join(f'{n} {a - m1:+.1f}/{b - m2:+.1f}' for n, a, b in lv))


def write_midi(path, ev):
    import mido
    tpb = 480
    mf = mido.MidiFile(ticks_per_beat=tpb)
    meta = mido.MidiTrack(); mf.tracks.append(meta)
    meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(BPM)))
    meta.append(mido.MetaMessage('time_signature', numerator=4, denominator=4))
    progs = {'lead': (0, 81), 'keys': (1, 10), 'bass': (2, 38), 'drums': (9, 0)}
    for key, (c, prog) in progs.items():
        if key not in ev:
            continue
        tr = mido.MidiTrack(); mf.tracks.append(tr)
        tr.append(mido.MetaMessage('track_name', name=key))
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
    T = load_midi()
    S = build(T)
    st = S.stems()
    ref = librosa.load(REF, sr=SR, mono=True)[0]
    g = balance(st, ref)
    n = int(NB * BAR * SR)
    y = master(eq_to_ref(fold_tail(mixdown(st, g, n), n), ref), lufs=-10.0)
    # Punto del bucle sin clic: 3 ms de fundido a cada lado (el final y el principio no casan)
    f = int(0.003 * SR)
    y[:f] *= np.linspace(0, 1, f)[:, None]
    y[-f:] *= np.linspace(1, 0, f)[:, None]
    report(y, ref, st, g)
    if not os.environ.get('REPORT') and not os.environ.get('SOLO'):
        wav = os.path.join(OUT, 'winter_nes.wav')
        write_wav(wav, y)
        write_midi(os.path.join(OUT, 'winter_nes.mid'), S.ev)
        ogg = os.path.join(OUT, 'winter_nes.ogg')
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"')
        os.remove(wav)
        print(f'  {ogg}  {len(y) / SR:.2f} s')
