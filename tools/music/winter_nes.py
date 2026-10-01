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
#   8-Bit Sine (notas largas 85-132)→ onda casi seno N163 (colchón) + CUERDAS: las mismas notas
#                                     una y dos octavas arriba (el ogg las tiene ahí: el MIDI solo
#                                     guarda la octava grave; medido por saliencia, ver strings)
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
# Acordes del comp (Pop Synth) que el ogg cambia: las vueltas 2 y 3 del motivo van en
# Si♭ Si♭ Do Do (como el final) y no en Fa / Solm del MIDI (mismo método que PAD_FIX)
TRI = {'Bb': (10, 2, 5), 'C': (0, 4, 7), 'F': (5, 9, 0), 'Dm': (2, 5, 9)}
CHORD_FIX = {12: TRI['C'], 28: TRI['C'], 29: TRI['Bb'], 30: TRI['Bb'], 31: TRI['C'], 32: TRI['C'], 36: TRI['C'],
             37: TRI['Bb'], 38: TRI['Bb'], 39: TRI['C'], 40: TRI['C'], 44: TRI['Dm']}
# Compases en que el ogg dobla el comp una octava abajo (saliencia: la octava baja ≥ 0.8 de la
# del MIDI). En los impares del motivo (golpes Fa/La) no: doblarlos añadía un La grave → La menor
COMP_LOW = {5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 19, 22, 23, 24, 26, 27, 28, 30, 32, 34, 36, 38, 40,
            42, 44, 78, 82, 83, 84}
COMP_HIGH = {20}                    # el paso cromático Do#-Mi-Re#-Re-Do# suena también una octava arriba


def snap(m, pcs):
    """La nota del acorde `pcs` más cercana a m (empate: abajo); sin acorde, m"""
    if not pcs:
        return m
    for d in range(0, 7):
        for q in (m - d, m + d):
            if q % 12 in pcs:
                return q
    return m


# Acordes del colchón (8-Bit Sine) corregidos según el ogg. El MIDI repite el mismo ciclo de 16
# compases tres veces (85, 101, 117) y el ogg no: para cada compás se ajustó la tríada diatónica
# (Fa, Solm, Lam, Si♭, Do, Rem, Do/Si♭) que mejor explica su perfil de alturas (saliencia del stem
# 'other' de demucs) y se corrigen SOLO los compases donde la del ogg está clara y no coincide.
# El final (117-132) sigue en el ogg Si♭ Si♭ Do Do | Fa Fa Rem Do | Si♭ Si♭ Do Do | Fa Fa Fa Rem.
# Voces como en el ogg: Si♭ con el Fa arriba, Do con el Sol arriba; en 88 y 104 el ogg tiene La7
# con el Sol y el Do# delante (el La3/Do#4 del MIDI dejaba el La arriba) y en 120, Do con el Mi.
_BB, _C, _F, _DM, _C_BB, _A7, _CE = (53, 58), (55, 60), (57, 60), (57, 62), (58, 64), (55, 61), (60, 64)
PAD_FIX = {91: _BB, 99: _BB, 107: _BB, 115: _BB, 123: _DM, 131: _F,
           87: _BB, 88: _A7, 92: _C, 94: _C_BB, 103: _BB, 104: _A7, 108: _C, 110: _C_BB,
           117: _BB, 118: _BB, 119: _C, 120: _CE, 121: _F, 122: _F, 124: _C,
           125: _BB, 126: _BB, 127: _C, 128: _C, 129: _F, 130: _F, 132: _DM}


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
I_CHORDLO = {'vol': [11, 10, 9, 8, 7, 6, 6, 5], 'sus': 5, 'duty': 5.0}                     # comp grave (N163 hueca)
I_STR = {'vol': [4, 6, 8, 9, 10, 10], 'sus': 10, 'duty': 5.0, 'vib': (20, 0.12, 5.0)}      # cuerdas (onda hueca)
I_STR2 = {'vol': [3, 5, 6, 7, 8, 8], 'sus': 8, 'duty': 4.0, 'vib': (20, 0.12, 5.0)}
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
        # (bus 'x': los golpes AÑADIDOS para la escalada, en pistas aparte con la misma
        # ganancia que los del MIDI: no cambian el reparto de las secciones de antes)
        self.NZ = {k: Noise(self.nf) for k in ('hat', 'snare', 'crash', 'xhat', 'xsnare', 'xcrash', 'xriser')}
        ns = int(self.nf * FRAME_S) + SR
        self.DM = {k: np.zeros(ns) for k in ('kick', 'snare', 'tom', 'xkick', 'xsnare', 'xtom')}

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

    def drum(self, t, n, vel=1.0, bus=''):
        if n in (35, 36):
            self.sample(bus + 'kick', t, KICK, vel)
        elif n in (38, 40):
            self.sample(bus + 'snare', t, SNARE, vel)
            self.NZ[bus + 'snare'].hit(t, [1, 2, 3, 4, 5], [int(x * vel + 0.5) for x in [15, 13, 11, 9, 7, 5, 4, 3, 2, 1]])
        elif n in (42, 44):
            self.NZ[bus + 'hat'].hit(t, 0, [int(x * vel + 0.5) for x in ([9, 6, 3, 1] if n == 42 else [6, 4, 2])])
        elif n == 46:
            self.NZ[bus + 'hat'].hit(t, 0, [int(x * vel + 0.5) for x in [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]])
        elif n in TOMS:
            self.sample(bus + 'tom', t, TOMS[n], vel)
        elif n in (49, 57):
            self.NZ[bus + 'crash'].hit(t, 2, [15, 14, 13, 12, 11, 10, 10, 9, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1])
        self.ev.setdefault('drums', []).append((t, n, 0.08))

    def riser(self, t0, t1, top=11):
        """Subida de ruido (de grave a agudo, cada vez más fuerte) antes de una entrada"""
        n = max(2, int((t1 - t0) * 60))
        self.NZ['xriser'].hit(t0, [int(round(13 - 12 * i / (n - 1))) for i in range(n)],
                              [int(round(1 + (top - 1) * (i / (n - 1)) ** 1.5)) for i in range(n)])

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
        for k in ('xkick', 'xtom'):
            if self.DM[k].any():
                out[k] = cut(tnd_dac((self.DM[k] + 64) / 22638.0))
        if self.DM['xsnare'].any() or self.NZ['xsnare'].vol.any():
            out['xsnare'] = cut(tnd_dac(self.NZ['xsnare'].render() / 12241.0)) + cut(tnd_dac((self.DM['xsnare'] + 64) / 22638.0))
        for k in ('xhat', 'xcrash', 'xriser'):
            if self.NZ[k].vol.any():
                out[k] = cut(tnd_dac(self.NZ[k].render() / 12241.0))
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
    # Acordes (Pop Synth): 2 pulsos del VRC6, golpes cortos. Donde el ogg tiene otro acorde
    # (CHORD_FIX) cada nota va a la nota del acorde bueno más cercana (mismo ritmo y registro);
    # en 5-44 el ogg los dobla una octava abajo (COMP_LOW)
    pop = [(s, d, snap(m, CHORD_FIX.get(bar_of(s))), v) for s, d, m, v in T['Pop Synth (Classic)']]
    for i, vs in enumerate(voices(pop, 2)):
        for s, d, m, v in vs:
            S.note('chord%d' % i, 'vrc6', s, d, m, I_CHORD if i == 0 else I_CHORD2, vs=min(1, 0.6 + v / 120),
                   gate=0.8, midi='keys')
    for s, d, m, v in pop:
        if bar_of(s) in COMP_HIGH:                     # (el paso cromático también una octava arriba)
            S.note('chordhi', 'pulse', s, d, m + 12, I_SHIM, vs=1.0, gate=0.9, midi='keys')
        if bar_of(s) in COMP_LOW and m >= 64:
            S.note('chordlo', 'n163', s, d, m - 12, I_CHORDLO, vs=min(1, 0.6 + v / 120), gate=0.8, midi='keys')
    # Caja de música: campana + eco 3/16 después (truco de eco de los juegos de NES)
    for i, vs in enumerate(voices(T['Music Box'], 2)):
        for s, d, m, v in vs:
            S.note('bell%d' % i, 'n163', s, d, m, I_BELL, vs=min(1, v / 90), gate=1.2, midi='keys', release=6)
            if i == 0:
                S.note('echo', 'n163', s + 3 * S16, d, m, I_ECHO, gate=1.2, midi='keys', release=4)
    # Scifi: pulso 12.5 % con arpegio de octava (centelleo)
    for s, d, m, v in T['Scifi']:
        k = 1.0
        S.note('arp', 'pulse', s, d, m, I_ARP, vs=min(1, 0.55 + v / 150) * k, midi='keys', arp=[0, 12])
    # Flauta (contramelodía suave) y seno (notas largas)
    for i, vs in enumerate(voices(T['Flute'], 2)):
        for s, d, m, v in vs:
            S.note('flute%d' % i, 'n163', s, d, m, I_FLUTE, vs=min(1, 0.5 + v / 100), midi='keys')
    # (el ogg manda: el colchón del MIDI repite el mismo ciclo de 16 compases tres veces, pero
    # el ogg cambia la armonía; PAD_FIX = el acorde del ogg en esos compases, ver arriba)
    sine = [x for x in T['8-Bit Sine'] if bar_of(x[0]) not in PAD_FIX]
    for b, notes in PAD_FIX.items():
        for m in notes:
            sine.append(((b - 1) * BAR, BAR, m, 51))
    sine.sort()
    for i, vs in enumerate(voices(sine, 2)):
        for s, d, m, v in vs:
            S.note('pad%d' % i, 'n163', s, d, m, I_PAD, vs=min(1, 0.55 + v / 120), gate=0.98, midi='keys')
            # Cuerdas: el ogg tiene estos acordes una y dos octavas arriba (saliencia del stem
            # 'other' de demucs frente al chiptune: compases 97-100, 107, 110, 115-116 y el final
            # 117-132 — p. ej. el Sol3/La#3 del MIDI en el 107 suena como La#4/La#5/Re6 —)
            S.note('str%d' % i, 'n163', s, d, m + 12, I_STR, vs=min(1, 0.55 + v / 120), gate=0.98, midi='keys')
            S.note('strh%d' % i, 'n163', s, d, m + 24, I_STR2, vs=min(1, 0.55 + v / 120), gate=0.98, midi='keys')
    # Batería del MIDI
    drums = T['Electric Drum Kit']
    has = {}
    for s, d, n, v in drums:
        vel = min(1.0, 0.55 + v / 110)
        if bar_of(s) in BREAK and n in (42, 44, 46):
            vel *= 1.1                                         # (el break es de batería)
        if bar_of(s) in BREAK and n in (35, 36):
            vel *= 0.5                                         # (y sin graves: el ogg quita el grave ahí)
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
    escalate(S, T, has)
    return S


# ── Escalada: cada repetición del motivo, más grande ─────────────────────────
# El ogg no sube de volumen (está limitado), sube de DENSIDAD y BRILLO: más voces
# (picos espectrales por trama: el motivo 15.5 → 18 → 19.6 → 21.9; la melodía del
# Smooth Synth 15 → 26) y más presencia / agudos. Aquí, sin tocar ninguna nota del
# MIDI, cada repetición suma capas (grupo 'layer') y golpes (bus 'x'):
#   motivo (Music Box)  21 base · 29 + campana una octava arriba, hats abiertos ·
#                       37 + terceras, centelleo de semicorcheas, crash cada 4, subida al break
#   break 45-60         la melodía se queda (solo se va el grave) y vuelve a crecer desde el 53
#   Smooth Synth        85 base · 93 + octava, hats abiertos · 101 + terceras, centelleo,
#                       bombo a negras · 109 + crash cada 4, redoble y subida al 117
#   FINAL 117-132       todo: campana + octava + terceras, lead (8-Bit Square) doblado a la
#                       octava y en terceras, centelleo fuerte, bajo a corcheas, bombo a negras,
#                       semicorcheas de hat, crash cada 2 compases (cada compás desde el 125),
#                       redobles y toms al final
SCALE = [5, 7, 9, 10, 0, 2, 4]                  # Fa mayor


def third(m, up=True):
    """Tercera diatónica (Fa mayor) encima / debajo; None si la nota no es de la escala"""
    pc = m % 12
    if pc not in SCALE:
        return None
    i = SCALE.index(pc)
    j = i + (2 if up else -2)
    pc2 = SCALE[j % 7]
    d = (pc2 - pc) % 12
    return m + d if up else m - ((pc - pc2) % 12)


def harmony_pcs(T, t0, t1):
    pcs = {}
    for name, notes in T.items():
        if name == 'Electric Drum Kit':
            continue
        for s, d, m, v in notes:
            if s < t1 and s + d > t0:
                pcs[m % 12] = pcs.get(m % 12, 0) + min(s + d, t1) - max(s, t0)
    return [pc for pc, _ in sorted(pcs.items(), key=lambda z: -z[1])[:4]]


I_SPARK = {'vol': [9, 8, 7, 6, 5, 4, 4, 3, 3, 2, 2, 1], 'sus': 1, 'duty': 0.125}
I_THIRD = {'vol': [10, 9, 8, 7, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1], 'sus': 1, 'duty': 0.0}
I_SHIM = {'vol': [7, 5, 3, 2], 'sus': 1, 'duty': 0.25}
I_OCT = {'vol': [9, 9, 8, 8, 7], 'sus': 7, 'duty': 0.125, 'vib': (14, 0.2, 5.6)}
I_HARM = {'vol': [9, 9, 8, 8, 7], 'sus': 7, 'duty': 5.0, 'vib': (14, 0.2, 5.6)}
I_PUMP = {'vol': [12, 10, 8, 6, 4, 2], 'sus': 0, 'duty': 1.0}


def escalate(S, T, has):
    def notes_in(lst, a, b):
        return [x for x in lst if a <= bar_of(x[0]) <= b]
    bells = voices(T['Music Box'], 2)[0]
    smooth = T.get('Smooth Synth (Classic)', [])
    square = voices(T.get('8-Bit Square', []), 2)[0]
    FINAL = (117, 132)
    # Cada capa crece con la repetición (vs): pronto, flojita; en el final, entera
    # Motivo: octava (29-44 y el final), terceras (37-44 y el final)
    for s, d, m, v in notes_in(bells, 29, 44) + notes_in(bells, *FINAL):
        k = 0.6 if bar_of(s) < 37 else (0.8 if bar_of(s) < 45 else 1.0)
        S.note('lay_bell8', 'pulse', s, d, m + 12, I_SPARK, vs=k, gate=1.0, midi='keys')
    for s, d, m, v in notes_in(bells, 37, 44) + notes_in(bells, *FINAL):
        th = third(m, up=False)
        if th:
            S.note('lay_bell3', 'n163', s, d, th, I_THIRD, vs=0.8 if bar_of(s) < 45 else 1.0, gate=1.1, midi='keys', release=5)
    for s, d, m, v in notes_in(bells, 125, 132):                 # (la última: brillo a dos octavas)
        S.note('lay_bell16', 'pulse', s, d, m + 24, I_SPARK, vs=0.7, gate=1.0, midi='keys')
    # Smooth Synth: octava desde el 93, terceras desde el 101
    for s, d, m, v in notes_in(smooth, 93, 116):
        S.note('lay_lead8', 'pulse', s, d, m + 12, I_OCT, vs=0.6 if bar_of(s) < 101 else 0.75, midi='lead')
    for s, d, m, v in notes_in(smooth, 101, 116):
        th = third(m, up=False)
        if th:
            S.note('lay_lead3', 'n163', s, d, th, I_HARM, vs=0.7, midi='lead')
    # Final: el lead del MIDI ahí (8-Bit Square) suena ~6 dB por debajo de la melodía del
    # tramo anterior (Smooth Synth: medido en 1-4 kHz) → doblado en la sierra del VRC6 (la
    # voz de la melodía principal) y la campana del motivo, al unísono en otra onda
    # (y el ogg la toca UNA OCTAVA ARRIBA: su línea de arriba es la voz alta del 8-Bit Square
    # +12 — compás 124: Sol4-Fa4-Mi4-Re4 del MIDI → Sol5-Fa5-Mi5-Re6 —; medido por saliencia)
    for s, d, m, v in notes_in(square, *FINAL):
        S.note('lay_leadsaw', 'saw', s, d, m + 12, I_SAW, vs=0.85 if bar_of(s) < 125 else 1.0, midi='lead')
    for s, d, m, v in notes_in(bells, *FINAL):
        S.note('lay_bellx', 'n163', s, d, m, I_PLUCK, vs=0.85 if bar_of(s) < 125 else 1.0, gate=1.0, midi='keys')
    # Pedal de Fa en la segunda mitad de cada frase del motivo del final: en el ogg el Fa es la
    # nota más fuerte de los compases 121-123 y 129-132 (el chiptune quedaba en La / Sol)
    # (en el 124 el ogg ya va a Do: Mi y Sol; el pedal acaba antes). Las vueltas 2 y 3 del
    # motivo tienen el mismo pedal (33-35, 41-44) y en el 36, sobre el Do, un Sol tenido
    for b0, nb, (m1, m2, m3) in ((33, 3, (65, 77, 89)), (36, 1, (67, 79, 91)), (41, 4, (65, 77, 89)),
                                 (121, 3, (65, 77, 89)), (129, 4, (65, 77, 89))):
        for m_, inst in ((m1, I_STR), (m2, I_STR), (m3, I_STR2)):
            S.note('lay_ped%d' % (m_ - (m1 - 65)), 'n163', (b0 - 1) * BAR, nb * BAR - S16, m_, inst, gate=1.0, midi='keys')
    # El motivo del final va ARMONIZADO a la quinta por encima (una octava más arriba) en el
    # ogg: Do6-La#5-La5-La#5 (la voz alta de la caja de música) → Sol6-Fa6-Mi6-Fa6 (compás 118); el
    # MIDI no la trae
    # (y en TODAS las vueltas: el ogg ya la tiene en la primera, compases 22-25; crece con la vuelta)
    for s, d, m, v in notes_in(bells, 21, 44) + notes_in(bells, *FINAL):
        b = bar_of(s)
        k = 0.6 if b < 29 else 0.72 if b < 37 else 0.8 if b < 45 else 0.85 if b < 125 else 1.0
        S.note('lay_bell5', 'pulse', s, d, m + 7, I_SPARK, vs=k, gate=1.0, midi='keys')
    # Final: el lead doblado a la octava, terceras debajo Y encima (brillo)
    for s, d, m, v in notes_in(square, *FINAL):
        S.note('lay_lead8', 'pulse', s, d, m + 12, I_OCT, midi='lead')
        lo, hi = third(m, up=False), third(m, up=True)
        if lo:
            S.note('lay_lead3', 'n163', s, d, lo, I_HARM, midi='lead')
        if hi:
            S.note('lay_leadhi', 'vrc6', s, d, hi + 12, I_OCT, vs=0.8 if bar_of(s) < 125 else 1.0, midi='lead')
    for b in range(FINAL[0], FINAL[1] + 1):
        root = None
        for s, d, m, v in T['Slap Bass']:
            if bar_of(s) == b:
                root = m; break
        if root is None:
            continue
        for k in range(8):
            t0 = (b - 1) * BAR + k * BAR / 8
            mm = None
            for s, d, m, v in T['Slap Bass']:                       # (la nota del bajo que suena ahí)
                if s <= t0 + 1e-6 < s + max(d, BAR / 8):
                    mm = m
            S.note('lay_pump', 'n163', t0, BAR / 16, (mm or root) - 12 + (12 if k % 2 else 0), I_PUMP, midi='bass')
    # Centelleo: arpegio de semicorcheas de la armonía (suave en 37-44 y 101-116, fuerte al final)
    for (a, b, vs) in ((37, 44, 0.75), (101, 116, 0.75), (117, 124, 1.0), (125, 132, 1.15)):
        for bb in range(a, b + 1):
            for h in range(2):
                t0 = (bb - 1) * BAR + h * BAR / 2
                pcs = sorted(harmony_pcs(T, t0, t0 + BAR / 2))
                if not pcs:
                    continue
                notes = [72 + pc if 72 + pc >= 74 else 84 + pc for pc in pcs]
                notes.sort()
                for k in range(8):
                    S.note('lay_shim', 'pulse', t0 + k * S16, S16, notes[k % len(notes)] + (12 if k >= 4 else 0),
                           I_SHIM, vs=vs, gate=0.7, midi='keys')
    # Batería añadida (bus x)
    def offbeat_open(a, b, vel):
        for bb in range(a, b + 1):
            for beat in range(4):
                S.drum((bb - 1) * BAR + beat * BAR / 4 + BAR / 8, 46, vel, bus='x')
    offbeat_open(29, 44, 0.55); offbeat_open(93, 116, 0.6); offbeat_open(117, 132, 0.75)
    def four_floor(a, b, vel):
        for bb in range(a, b + 1):
            kicks = {k for k, n in has.get(bb, set()) if n in (35, 36)}
            for beat in range(4):
                if beat * 4 not in kicks:
                    S.drum((bb - 1) * BAR + beat * BAR / 4, 36, vel, bus='x')
    four_floor(101, 116, 0.7); four_floor(117, 132, 0.85)
    for bb in list(range(37, 45, 4)) + list(range(101, 117, 4)) + list(range(117, 125, 2)) + list(range(125, 133)):
        if not any(n in (49, 57) and k == 0 for k, n in has.get(bb, set())):
            S.drum((bb - 1) * BAR, 49, 0.9, bus='x')
    for bb in range(117, 133):                                       # semicorcheas de hat al final
        for k in range(0, 16, 2):
            S.NZ['xhat'].hit((bb - 1) * BAR + k * S16 + S16, 0, [5, 3, 1])
    # Redobles: 115-116 (a corcheas y luego semicorcheas, creciendo), 124, 131-132 con toms
    for k in range(8):
        S.drum((115 - 1) * BAR + k * BAR / 8, 40, 0.45 + 0.04 * k, bus='x')
    for k in range(16):
        S.drum((116 - 1) * BAR + k * S16, 40, 0.6 + 0.025 * k, bus='x')
    for k in range(12, 16):
        S.drum((124 - 1) * BAR + k * S16, 40, 0.7 + 0.08 * (k - 12), bus='x')
    for i, (k, n) in enumerate(((8, 50), (10, 48), (12, 47), (13, 45), (14, 43), (15, 41))):
        S.drum((132 - 1) * BAR + k * S16, n, 1.0, bus='x')
    # Subidas de ruido antes de cada entrada grande
    for a in (45, 61, 117):
        S.riser((a - 3) * BAR, (a - 1) * BAR, top=9 if a != 117 else 12)


# ── Mezcla ───────────────────────────────────────────────────────────────────
GROUPS = {'lead': ('lead',), 'bass': ('bass',), 'chords': ('chord',), 'bell': ('bell', 'echo'),
          'arp': ('arp',), 'soft': ('flute', 'pad', 'pluck'), 'strings': ('str',), 'kick': ('kick',), 'snare': ('snare', 'tom'),
          'cymbals': ('hat', 'crash'), 'layer': ('lay_',), 'xdrums': ('x',)}
LAYER_OF = {'lay_ped': 'strings', 'lay_bell': 'bell', 'lay_leadsaw': 'lead', 'lay_lead': 'lead', 'lay_shim': 'arp', 'lay_pump': 'bass'}
# (una capa suena un poco por debajo del instrumento que dobla; las dos "estrellas" del
# final — la sierra que dobla el lead y la campana del motivo — a la par)
LAYER_K = {'*': 0.75, 'lay_leadsaw': 1.0, 'lay_bellx': 1.1, 'lay_ped65': 1.0, 'lay_ped77': 1.2, 'lay_ped89': 1.0}
XBUS = {'xkick': 'kick', 'xsnare': 'snare', 'xtom': 'tom', 'xhat': 'hat', 'xcrash': 'crash', 'xriser': 'crash'}


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
            'soft': -7, 'strings': -5}
BREAK_DB = -4.0                     # el break (45-52) baja así y del 53 al 60 vuelve a subir poco a poco


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
    groups = [gr for gr in GROUPS if gr not in ('xdrums', 'layer') and any(group_of(k) == gr for k in S)]
    lvl = {gr: active_rms(sum(S[k] for k in S if group_of(k) == gr)) for gr in groups}
    for gr in groups:
        if lvl[gr] > 0:
            want = lvl['lead'] * 10 ** (LEVEL_DB[gr] / 20)
            for k in S:
                if group_of(k) == gr:
                    g[k] = want / lvl[gr]
    # (dentro de la batería: el reparto bombo / caja / platillos sale de LEVEL_DB)
    for k in S:                                       # golpes añadidos: como los del MIDI
        if k in XBUS:
            g[k] = g.get(XBUS[k], 1.0) * (0.8 if k == 'xriser' else 1.0)
    # Capas de la escalada: la ganancia del instrumento al que doblan (su vs decide cuánto
    # suena cada repetición; normalizarlas como grupo aplanaba la subida)
    for k in S:
        if k.startswith('lay_'):
            base = next(v for pre, v in LAYER_OF.items() if k.startswith(pre))
            ref = next((kk for kk in S if group_of(kk) == base), None)
            g[k] = (g[ref] if ref else 1.0) * LAYER_K.get(k, LAYER_K['*'])
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
    # El break: baja en medio compás y, del 53 al 60, vuelve a subir poco a poco (en dB)
    a, b = (min(BREAK) - 1) * BAR, max(BREAK) * BAR
    t = np.arange(len(y)) / SR
    down = np.clip((t - a) / (BAR / 2), 0, 1)
    up = np.clip((t - (52 * BAR)) / (b - 52 * BAR), 0, 1)
    db = np.where((t >= a) & (t < b), BREAK_DB * down * (1 - up), 0.0)
    y *= (10 ** (db / 20))[:, None]
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
