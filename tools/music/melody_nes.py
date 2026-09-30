#!/usr/bin/env python3
# tools/music/melody_nes.py
# La canción de los niveles (level.ogg) y su remix de jefe, como música de
# Famicom (2A03 + VRC6 + Namco 163, motor de famicom.py), a partir del MIDI de
# la canción original (tools/music/ref/melody.mid: solo en local, fuera de git).
#
#   python3 tools/music/melody_nes.py          → assets/music/level_nes.ogg (+ .mid)
#                                                 assets/music/boss_nes_intro.ogg + boss_nes_loop.ogg (+ .mid)
#   ONLY=level|boss python3 ...                 → solo una de las dos
#   SOLO=lead,bass python3 ...                  → solo esos instrumentos
#
# El MIDI: 140 BPM (level.ogg va a 137.5), 4/4, 36 compases, Do menor (dórico en 1-8):
#   1-8   vibráfono + pianos, lead cuadrado, bajo slap (Do–La–Sol–Si♭)
#   9-16  el riff del bajo (Do Mi♭ Fa Mi♭ Fa Sol) con lead de sierra
#   17-23 Do / Fa alternando, sierra + cuadrado     24 enlace
#   25-36 Fa–Sol–Do–Do (×2), Fa–Sol–La♭–Si♭ (el final épico) con metales
# level.ogg es esta misma canción (a 137.5 BPM, desde 0.04 s; algunos compases
# del arreglo difieren del MIDI); la música de jefe
# original (boss_battle_*.wav) era un remix de ella.
#
# NIVEL: fiel al MIDI, un canal de la consola por instrumento:
#   Cuadrado → pulsos del 2A03 · Sierra → sierra del VRC6 + N163 · Vibráfono,
#   pianos y metales → ondas del N163 con sus envolventes · Bajo → triángulo +
#   N163 · Batería → ruido + muestras DPCM (bombo, caja, toms).
# JEFE: las mismas NOTAS (que se reconozca), estilo de jefe por timbres y
# ritmo: lead de pulso ancho, sierra al frente, vibráfono → campana oscura,
# piano → órgano hueco, las notas largas (piano 2) → coro limpio con vibrato,
# "guitarra" del VRC6 (quintas SOLO si están en la armonía; palm mute en
# semicorcheas con un golpe corto de ruido en las partes fuertes), doble
# bombo, platillos y redobles de toms. (Una versión anterior pasaba La → La♭,
# sacaba las quintas de cada nota del bajo y dejaba ruido sostenido bajo las
# notas largas: sonaba desafinada y saturada.) Intro de 4 compases (Do grave que crece + el
# riff que arranca) y bucle que empieza en el riff (compases 9-36 y 1-8).
# Mezcla: ganancias por instrumento ajustadas al espectro por bandas de octava
# de level.ogg (nivel, por secciones) y de boss_battle_loop.wav (jefe: el
# "sonido de jefe" del remix original), y la batería hasta la proporción
# percusión / armonía de cada uno.
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from famicom import (master, SR, FRAME_S, frames_for, t_, Chan, q_pulse, q_tri, q_vrc6, q_saw, q_n163, play,
                     render_pulse, render_tri, render_saw, dpcm, wavetable, render_wave, Noise, pulse_dac,
                     tnd_dac, band_power, OCT, write_wav)

BPM = 140
BAR = 4 * 60 / BPM
S16 = BAR / 16
NB = 36
# level.ogg va a 137.5 BPM (no a los 140 del MIDI: 36 compases = 62.84 s, su
# duración exacta) y empieza a los 0.04 s: la versión del nivel usa su tempo;
# la de jefe, 140 (como el remix original, 140.4)
LEVEL_BPM, BOSS_BPM = 137.5, 148.0                   # (el jefe, más rápido: más agresivo)


def set_tempo(bpm):
    global BPM, BAR, S16
    BPM, BAR, S16 = bpm, 4 * 60 / bpm, 4 * 60 / bpm / 16
HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, '..', '..', 'assets', 'music')
MIDI_IN = os.path.join(HERE, 'ref', 'melody.mid')
LEVEL_OFF = 0.04                                 # level.ogg empieza así de tarde respecto al MIDI
rng = np.random.default_rng(36)


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
    """Reparte notas (polifónicas) en n voces monofónicas: la que antes quede libre"""
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
    wavetable([1.0, 0, 0, 0.32, 0, 0, 0, 0, 0, 0.1]),              # 0 vibráfono (parciales 1 y 4)
    wavetable([1.0, 0.5, 0.33, 0.25, 0.2, 0.16, 0.14, 0.12]),      # 1 sierra suave
    wavetable([1.0, 0.8, 0.6, 0.45, 0.3, 0.2, 0.12]),              # 2 metales
    wavetable([1.0, 0.3, 0.1, 0.05]),                              # 3 piano eléctrico
    wavetable([1.0, 0.6, 0.35, 0.2, 0.1]),                         # 4 bajo slap
    wavetable([1.0, 0, 0.45, 0, 0.28, 0, 0.16, 0, 0.08]),          # 5 coro oscuro (armónicos impares: hueco)
    wavetable([1.0, 0.75, 0.55, 0.5, 0.38, 0.3, 0.2, 0.15]),       # 6 lead oscuro
    wavetable([1.0, 0, 0.2, 0, 0, 0.45, 0, 0, 0.15]),              # 7 campana oscura (parciales 1, 3, 6)
    np.round(np.clip(np.sin(2 * np.pi * np.arange(32) / 32) * 2.2 + 0.35 * np.sin(6 * np.pi * np.arange(32) / 32), -1, 1)
             * 7.5 + 7.5),                                          # 8 lead "saturado" (seno recortado: áspero)
    wavetable([1.0, 0.9, 0.7, 0.6, 0.45, 0.4, 0.3]),               # 9 bajo áspero (casi sierra)
]
I_SQR = {'vol': [12, 12, 11, 11, 10, 10], 'sus': 10, 'duty': 0.25, 'vib': (16, 0.18, 5.8)}
I_SQR2 = dict(I_SQR, duty=0.125)
I_SAW = {'vol': [13, 13, 12, 12, 11], 'sus': 11, 'vib': (16, 0.2, 5.6)}
I_SAWN = dict(I_SAW, duty=1.0)
I_VIB = {'vol': [15, 14, 13, 12, 11, 10, 10, 9, 9, 8, 8, 7, 7, 7, 6, 6, 6, 5, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 1],
         'sus': 1, 'duty': 0.0}
I_EP = {'vol': [13, 12, 11, 10, 9, 9, 8, 8, 7, 7, 6, 6, 5, 5, 5, 4], 'sus': 4, 'duty': 0.5}
I_EPN = dict(I_EP, duty=3.0)
I_BRS = {'vol': [5, 7, 9, 10, 11, 12, 12], 'sus': 12, 'duty': 2.0, 'vib': (18, 0.15, 5.5)}
I_BASS = {'vol': [15, 14, 12, 11, 10, 9, 9, 8, 8, 7], 'sus': 7, 'duty': 4.0}
I_TRI = {'vol': [15], 'sus': 15}
# Jefe
I_LEAD_B = {'vol': [15, 15, 14, 14, 13], 'sus': 13, 'duty': 0.5, 'vib': (14, 0.25, 5.6)}
I_LEAD_B2 = {'vol': [12, 12, 11, 11, 10], 'sus': 10, 'duty': 0.25, 'vib': (14, 0.25, 5.6)}
I_SAW_B = {'vol': [15, 15, 14, 14, 13], 'sus': 13, 'duty': 6.0, 'vib': (14, 0.25, 5.4)}
I_CHOIR = {'vol': [6, 9, 11, 12, 13, 13], 'sus': 13, 'duty': 5.0, 'vib': (20, 0.14, 5.0)}
I_BRS_B = {'vol': [7, 9, 11, 12, 13, 14, 14], 'sus': 14, 'duty': 2.0, 'vib': (16, 0.2, 5.2)}
I_BASS_B = {'vol': [15, 15, 14, 13, 13, 12], 'sus': 12, 'duty': 4.0}
I_CHUG = {'vol': [11, 7, 4, 2], 'sus': 0, 'duty': 0.5}
I_CHUG5 = {'vol': [8, 5, 3, 1], 'sus': 0, 'duty': 0.25}
I_GTR = {'vol': [14, 13, 12, 12, 11], 'sus': 11, 'duty': 0.5}
I_GTR5 = {'vol': [11, 10, 10, 9, 9], 'sus': 9, 'duty': 0.25}
I_LEAD_DIST = {'vol': [15, 15, 15, 14, 14, 13], 'sus': 13, 'duty': 8.0, 'vib': (12, 0.3, 6.2)}
I_SHEEN = {'vol': [7, 6, 6, 5, 5], 'sus': 5, 'duty': 0.125, 'vib': (12, 0.3, 6.2)}
I_ARP_ORG = {'vol': [12, 11, 10, 10, 9, 9, 8], 'sus': 8, 'duty': 5.0, 'arp_speed': 2}
I_BASS_HARSH = {'vol': [15, 15, 14, 14, 13, 13], 'sus': 13, 'duty': 9.0}
I_SAW_BOSS = {'vol': [15, 15, 14, 14, 13], 'sus': 13, 'vib': (14, 0.22, 5.4)}
I_BELL_B = {'vol': [14, 13, 11, 10, 9, 8, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1], 'sus': 1, 'duty': 7.0}
I_ORGAN_B = {'vol': [11, 10, 9, 9, 8, 8, 7, 7, 6], 'sus': 6, 'duty': 5.0}
I_SWELL = {'vol': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], 'sus': 14, 'duty': 5.0}

# Batería (muestras DPCM de 1 bit)
_kt = t_(int(0.3 * SR))
# (golpe con clic de ataque y caída de tono rápida: pega más)
KICK = dpcm(np.clip(1.4 * np.sin(2 * np.pi * np.cumsum(55 + 170 * np.exp(-_kt / 0.016)) / SR) * np.exp(-_kt / 0.12), -1, 1)
            + np.concatenate([rng.uniform(-0.6, 0.6, int(0.003 * SR)), np.zeros(len(_kt) - int(0.003 * SR))]))
KICK_B = dpcm(np.clip(1.35 * np.sin(2 * np.pi * np.cumsum(46 + 160 * np.exp(-_kt / 0.015)) / SR) * np.exp(-_kt / 0.14), -1, 1)
              + np.concatenate([rng.uniform(-0.7, 0.7, int(0.003 * SR)), np.zeros(len(_kt) - int(0.003 * SR))]))
SNARE = dpcm(np.clip(1.3 * np.sin(2 * np.pi * np.cumsum(185 + 110 * np.exp(-t_(int(0.12 * SR)) / 0.008)) / SR)
                     * np.exp(-t_(int(0.12 * SR)) / 0.045), -1, 1))


def tom(f):
    n = int(0.25 * SR)
    return dpcm(np.sin(2 * np.pi * np.cumsum(f + f * 0.8 * np.exp(-t_(n) / 0.03)) / SR) * np.exp(-t_(n) / 0.1))


TOMS = {45: tom(95), 47: tom(125), 48: tom(160)}
DRUM_NAMES = {36: 'bombo', 40: 'caja', 42: 'hi-hat', 45: 'tom', 47: 'tom', 48: 'tom'}


# ── Canción ──────────────────────────────────────────────────────────────────
class Song:
    """Canales, ruido y DPCM de una pieza de `nbars` compases + eventos para el .mid"""
    def __init__(self, nbars):
        self.nb = nbars
        self.nf = frames_for(nbars * BAR)
        self.C = {}
        self.NZ = {k: Noise(self.nf) for k in ('hat', 'snare', 'crash', 'grit', 'metal')}
        ns = int(self.nf * FRAME_S) + SR
        self.DM = {'kick': np.zeros(ns), 'snare': np.zeros(ns), 'tom': np.zeros(ns)}
        self.ev = {}
        self.kind = {}                                 # canal → 'pulse' | 'tri' | 'saw' | 'vrc6' | 'n163'

    def chan(self, name, kind):
        if name not in self.C:
            self.C[name] = Chan(self.nf)
            self.kind[name] = kind
        return self.C[name]

    def note(self, name, kind, t0, dur, m, inst, vs=1.0, gate=0.92, midi='lead', release=3):
        q = {'pulse': q_pulse, 'tri': q_tri, 'saw': q_saw, 'vrc6': q_vrc6, 'n163': q_n163}[kind]
        g = max(dur * gate, 1.2 / 60)
        play(self.chan(name, kind), t0, t0 + g, m, inst, q=q, vs=vs, release=0 if kind == 'tri' else release)
        self.ev.setdefault(midi, []).append((t0, m, g))

    def sample(self, buf, t, smp, g):
        d = self.DM[buf]
        i = int(t * SR); j = min(len(d), i + len(smp))
        d[i:j] = smp[:j - i] * g

    def drum(self, t, n, vel=1.0, boss=False):
        if n == 36:
            self.sample('kick', t, KICK_B if boss else KICK, vel)
        elif n == 40:
            self.sample('snare', t, SNARE, vel)
            self.NZ['snare'].hit(t, [1, 2, 3, 4, 5], [int(x * vel) for x in ([15, 13, 11, 9, 7, 6, 5, 4, 3, 2, 1] if boss
                                                                               else [14, 11, 8, 6, 4, 3, 2, 1])])
        elif n == 42:
            self.NZ['hat'].hit(t, 0, [int(x * vel) for x in [8, 5, 3, 1]])
        elif n in TOMS:
            self.sample('tom', t, TOMS[n], vel)
        elif n == 49:
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
        if self.NZ['metal'].vol.any():
            out['metal'] = cut(tnd_dac(self.NZ['metal'].render() / 12241.0))
        if self.NZ['grit'].vol.any():
            out['grit'] = cut(tnd_dac(self.NZ['grit'].render() / 12241.0))
        return out


PERC = ('kick', 'snare', 'tom', 'hat', 'crash', 'metal')


# ── Versión del NIVEL (fiel) ─────────────────────────────────────────────────
def build_level(T):
    S = Song(NB)
    for i, vs in enumerate(voices(T['Square Wave Lead'], 2)):
        for s, d, m, v in vs:
            S.note('sqr%d' % i, 'pulse', s, d, m, I_SQR if i == 0 else I_SQR2, vs=v / 80, midi='lead')
    saw = voices(T['Saw Wave Lead'], 3)
    for s, d, m, v in saw[0]:
        S.note('saw', 'saw', s, d, m, I_SAW, vs=v / 96, midi='saw')
    for i in (1, 2):
        for s, d, m, v in saw[i]:
            S.note('sawn%d' % i, 'n163', s, d, m, I_SAWN, vs=v / 96, midi='saw')
    for i, vs in enumerate(voices(T['Vibes'], 2)):
        for s, d, m, v in vs:
            S.note('vib%d' % i, 'n163', s, d, m, I_VIB, vs=v / 80, gate=1.3, midi='keys', release=6)
    for i, vs in enumerate(voices(T['Electric Piano 1'], 2)):
        for s, d, m, v in vs:
            S.note('ep%d' % i, 'vrc6', s, d, m, I_EP, vs=v / 96, midi='keys')
    for s, d, m, v in T['Electric Piano 2']:
        S.note('ep2', 'n163', s, d, m, I_EPN, vs=v / 80, midi='keys')
    for i, vs in enumerate(voices(T['Synth Brass'], 2)):
        for s, d, m, v in vs:
            S.note('brs%d' % i, 'n163', s, d, m, I_BRS, midi='brass')
    b = voices(T['Slap Bass'], 2)
    for s, d, m, v in b[0]:
        S.note('tri', 'tri', s, d, m, I_TRI, gate=0.85, midi='bass')
        S.note('bass', 'n163', s, d, m, I_BASS, gate=0.85, midi='bass')
    for s, d, m, v in b[1]:
        S.note('bass', 'n163', s, d, m, I_BASS, gate=0.85, midi='bass')
    for s, d, n, v in T['Drums']:
        S.drum(s, n, 1.0)
    return S


# ── Versión de JEFE ──────────────────────────────────────────────────────────
# Las NOTAS del MIDI intactas (que se reconozca la canción); el estilo de jefe
# sale de los timbres, la "guitarra" y la batería. Cada instrumento en su
# canal, como en la versión del nivel.
DRIVE = set(range(9, 24)) | {33, 34, 35, 36}      # compases con doble bombo y quintas en semicorcheas
LOOP_ORDER = list(range(9, 37)) + list(range(1, 9))


def bar_notes(notes, b):
    """Notas del compás b (1-36) con el tiempo relativo al compás"""
    t0 = (b - 1) * BAR
    return [(s - t0, d, m, v) for s, d, m, v in notes if t0 - 1e-6 <= s < t0 + BAR - 1e-6]


def half_harmony(T, b, h):
    """Nota del bajo al empezar el medio compás h y notas (clases) que suenan en él"""
    t0 = (b - 1) * BAR + h * BAR / 2
    t1 = t0 + BAR / 2
    pcs = set()
    for k, v in T.items():
        if k == 'Drums':
            continue
        for s, d, m, vel in v:
            if s < t1 - 1e-4 and s + d > t0 + 1e-4:
                pcs.add(m % 12)
    bass = [m for s, d, m, v in T['Slap Bass'] if s <= t0 + S16 and s + d > t0 - 1e-4]
    if not bass:
        bass = [m for s, d, m, v in T['Slap Bass'] if t0 <= s < t1] or [36]
    return min(bass), pcs


def power(root, pcs):
    """Quinta de "guitarra" SOLO si esa nota está en la armonía; si no, octava"""
    r = 36 + (root - 36) % 12 + 12                 # (Do3-Si3)
    return r, (r + 7 if (r + 7) % 12 in pcs else r + 12)


def L_chan(S, name):
    return S.chan(name, 'n163')


def boss_bar(S, T, b, t0, part):
    """Toca el compás b del MIDI (estilo jefe) a partir de t0"""
    drive = b in DRIVE
    # Lead: N163 con onda "saturada" + un pulso fino a la octava (brillo); la
    # 2ª voz en pulso (en el nivel el lead es un pulso: aquí suena distinto)
    for i, vs in enumerate(voices(bar_notes(T['Square Wave Lead'], b), 2)):
        for s, d, m, v in vs:
            if i == 0:
                S.note('leadn', 'n163', t0 + s, d, m, I_LEAD_DIST, midi='lead')
                S.note('lead0', 'pulse', t0 + s, d, m + 12, I_SHEEN, midi='lead')
            else:
                S.note('lead1', 'pulse', t0 + s, d, m, I_LEAD_B2, midi='lead')
    saw = voices(bar_notes(T['Saw Wave Lead'], b), 3)
    for s, d, m, v in saw[0]:
        S.note('saw', 'saw', t0 + s, d, m, I_SAW_BOSS, vs=v / 96, midi='saw')
    for i in (1, 2):
        for s, d, m, v in saw[i]:
            S.note('sawn%d' % i, 'n163', t0 + s, d, m, I_SAW_B, vs=v / 96, midi='saw')
    for i, vs in enumerate(voices(bar_notes(T['Vibes'], b), 2)):
        for s, d, m, v in vs:
            S.note('vib%d' % i, 'n163', t0 + s, d, m, I_BELL_B, vs=v / 80, gate=1.1, midi='keys', release=6)
    # Piano → órgano con arpegio de octava rápido (tipo chiptune agresivo)
    for i, vs in enumerate(voices(bar_notes(T['Electric Piano 1'], b), 2)):
        for s, d, m, v in vs:
            play(L_chan(S, 'ep%d' % i), t0 + s, t0 + s + d * 0.92, m, I_ARP_ORG, q=q_n163, arp=[0, 12])
            S.ev.setdefault('keys', []).append((t0 + s, m, d * 0.92))
    # Las notas largas (piano 2 desde el compás 24): coro limpio, con vibrato suave
    for s, d, m, v in bar_notes(T['Electric Piano 2'], b):
        S.note('ep2', 'n163', t0 + s, d, m, I_CHOIR, gate=0.96, midi='keys')
    for i, vs in enumerate(voices(bar_notes(T['Synth Brass'], b), 2)):
        for s, d, m, v in vs:
            S.note('brs%d' % i, 'n163', t0 + s, d, m, I_BRS_B, midi='brass')
    for s, d, m, v in voices(bar_notes(T['Slap Bass'], b), 2)[0]:
        S.note('tri', 'tri', t0 + s, d, m, I_TRI, gate=0.9, midi='bass')
        S.note('bass', 'n163', t0 + s, d, m, I_BASS_HARSH, gate=0.9, midi='bass')
    # "Guitarra" (pulsos del VRC6): quintas en semicorcheas con palm mute y un
    # golpe de "fritura" CORTO en las partes fuertes; en el resto, un acorde
    # por medio compás, suave y limpio (sin ruido: no tapa las notas largas)
    for h in (0, 1):
        root, pcs = half_harmony(T, b, h)
        r, r2 = power(root, pcs)
        if drive:
            for k in range(8):
                tt = t0 + (h * 8 + k) * S16
                S.note('gtr', 'vrc6', tt, S16 * 0.6, r, I_CHUG, gate=1.0, midi='gtr', release=0)
                S.note('gtr5', 'vrc6', tt, S16 * 0.6, r2, I_CHUG5, gate=1.0, midi='gtr', release=0)
                S.NZ['grit'].hit(tt, 7, [5, 3, 1])
        else:
            S.note('gtr', 'vrc6', t0 + h * BAR / 2, BAR / 2 * 0.9, r, I_GTR, vs=0.7, midi='gtr')
            S.note('gtr5', 'vrc6', t0 + h * BAR / 2, BAR / 2 * 0.9, r2, I_GTR5, vs=0.7, midi='gtr')
    # Batería INDUSTRIAL: la del MIDI con muestras más duras + doble bombo,
    # "metal" (ruido corto del 2A03: suena a chapa/yunque) en los
    # contratiempos y bajo cada caja, bombo grave en el 1, platillos
    for s, d, n, v in bar_notes(T['Drums'], b):
        S.drum(t0 + s, n, 1.0, boss=True)
        if n == 40:
            S.NZ['metal'].hit(t0 + s, 3, [15, 12, 9, 7, 5, 3, 2, 1], short=1)
    if drive:
        for k in range(16):
            if k % 4:
                S.drum(t0 + k * S16, 36, 0.5, boss=True)
        S.sample('tom', t0, TOMS[45], 0.9)                          # (golpe grave en el 1)
        for k in range(16):
            if k % 4 == 2:
                S.NZ['metal'].hit(t0 + k * S16, 4, [12, 9, 6, 4, 2, 1], short=1)
            elif k % 2:
                S.NZ['metal'].hit(t0 + k * S16, 2, [5, 3, 1], short=1)
        if b % 2 == 1:
            S.drum(t0, 49)
    else:
        for k in (2, 6, 10, 14):
            S.NZ['metal'].hit(t0 + k * S16, 4, [8, 5, 3, 1], short=1)
    if b in (9, 17, 25, 33, 1):
        S.drum(t0, 49)
    if b in (8, 16, 24, 32, 36):                    # redoble de toms al final de cada parte
        for j, n in enumerate((48, 48, 47, 47, 45, 45, 45, 45)):
            S.drum(t0 + (8 + j) * S16, n, 0.75 + 0.03 * j, boss=True)


def build_boss(T):
    # Intro: Do grave que crece + el riff (compás 9) arrancando, con redoble al final
    I = Song(4)
    I.note('ep0', 'n163', 0, BAR, 48, I_SWELL, midi='keys')
    I.note('ep1', 'n163', 0, BAR, 55, I_SWELL, midi='keys')
    I.note('tri', 'tri', 0, BAR * 0.98, 24, I_TRI, midi='bass')
    I.note('gtr', 'vrc6', BAR * 0.5, BAR * 0.5, 48, dict(I_SWELL, duty=0.5), vs=0.7, midi='gtr')
    I.note('gtr5', 'vrc6', BAR * 0.5, BAR * 0.5, 55, dict(I_SWELL, duty=0.25), vs=0.6, midi='gtr')
    for j in range(8):
        I.drum(BAR * 0.5 + j * S16 * 2, 45 if j < 4 else 47, 0.5 + 0.06 * j, boss=True)
    for j in range(4):
        I.drum(BAR * 0.75 + j * S16, 48, 0.8 + 0.05 * j, boss=True)
    for i in (1, 2, 3):
        boss_bar(I, T, 9, i * BAR, 'intro')
    I.drum(BAR, 49)
    L = Song(len(LOOP_ORDER))
    for i, b in enumerate(LOOP_ORDER):
        boss_bar(L, T, b, i * BAR, 'loop')
    return I, L


# ── Mezcla ───────────────────────────────────────────────────────────────────
def load_ref(name):
    import librosa
    return librosa.load(os.path.join(OUT, name), sr=SR, mono=True)[0]


# Grupos de instrumentos (las voces de un instrumento van juntas) con su
# volumen de partida (musical) y cuánto puede corregirlo el ajuste
GROUPS = {'lead': ('sqr', 'lead'), 'saw': ('saw',), 'keys': ('vib', 'ep', 'choir'), 'brass': ('brs',),
          'gtr': ('gtr', 'grit'), 'bass': ('tri', 'bass'), 'kick': ('kick',), 'snare': ('snare', 'tom'),
          'metal': ('metal',),
          'cymbals': ('hat', 'crash')}
BASE = {'lead': 1.0, 'saw': 1.0, 'keys': 0.8, 'brass': 0.9, 'gtr': 0.8, 'bass': 1.0, 'kick': 1.0, 'snare': 0.45,
        'cymbals': 0.3, 'metal': 0.4}
RANGE = {'lead': (0.8, 2.0), 'bass': (0.3, 2.0), 'gtr': (0.5, 3.0), 'snare': (0.5, 3.0), 'cymbals': (0.5, 3.0)}  # (la melodía nunca queda enterrada)


def group_of(k):
    return next(g for g, pre in GROUPS.items() if any(k.startswith(p) for p in pre))


def fit_gains(S, rows_spec):
    """rows_spec = [(t0, t1, R)]: tramo de la pieza y potencia por bandas del
    original a imitar. Mínimos cuadrados por GRUPO de instrumentos, con límites
    alrededor del volumen de partida (nada se apaga ni se dispara)"""
    from scipy.optimize import lsq_linear
    groups = [g for g in GROUPS if any(group_of(k) == g for k in S)]
    G = {g: sum(S[k] for k in S if group_of(k) == g) * BASE[g] for g in groups}
    rows, tgt = [], []
    for a, b, R in rows_spec:
        M = np.array([band_power(G[g], a, b) for g in groups]).T
        for j in range(len(OCT)):
            rows.append(M[j] / R[j]); tgt.append(1.0)
    A, y = np.array(rows), np.array(tgt)
    s = np.sum(A.sum(1) * y) / np.sum(A.sum(1) ** 2)
    lo = np.array([RANGE.get(g, (0.5, 2.0))[0] ** 2 for g in groups])
    hi = np.array([RANGE.get(g, (0.5, 2.0))[1] ** 2 for g in groups])
    gg = dict(zip(groups, np.sqrt(lsq_linear(A * s, y, bounds=(lo, hi)).x)))
    return {k: gg[group_of(k)] * BASE[group_of(k)] for k in S}, gg


def perc_ratio(x):
    import librosa
    h, p = librosa.effects.hpss(x[:SR * 40].astype(np.float32))
    return np.sum(p ** 2) / np.sum(h ** 2)


def mixdown(S, g, n):
    solo = os.environ.get('SOLO')
    keep = set(solo.split(',')) if solo else set(S)
    x = sum(S[k] * g.get(k, 1.0) for k in S if any(k.startswith(w) for w in keep))
    from scipy.signal import butter, sosfilt
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    x = sosfilt(butter(1, 14000, btype='low', fs=SR, output='sos'), x)
    # Estéreo discreto: cada canal un poco a un lado (como un emulador)
    side = np.zeros_like(x)
    for k, p in (('sqr1', 0.3), ('lead2', 0.25), ('ep1', -0.3), ('vib1', 0.3), ('choir1', -0.35), ('choir2', 0.35),
                 ('brs1', -0.3), ('gtr5', 0.3), ('hat', 0.2), ('sawn1', -0.25), ('sawn2', 0.25)):
        if k in S:
            side += S[k] * g.get(k, 1.0) * p
    return np.stack([x + side, x - side], 1)


def fold_tail(y, n):
    """Bucle sin costura: lo que suena pasado el final se suma al principio"""
    out = y[:n].copy()
    tail = y[n:]
    out[:len(tail)] += tail[:n]
    return out


# Batería: tras el reparto por bandas, un empuje FIJO (más energía que el
# original). No se persigue la proporción percusión/armonía del original: su
# "crunch" hace que la medida vea percusión en todo, y perseguirla enterraba
# la melodía (×6 → los medios −8 dB)
PERC_EXTRA = {'level': 1.6, 'boss': 2.4}


# Reparto DENTRO de la batería (energía): bombo y caja parejos, platillos
# detrás. (El ajuste por bandas lo descuadraba: bombo y bajo comparten graves)
DRUM_SPLIT = {'level': {'kick': 0.45, 'snare': 0.45, 'cymbals': 0.10},
              'boss': {'kick': 0.34, 'snare': 0.34, 'cymbals': 0.10, 'metal': 0.22}}


def balance(S, rows_spec, boost, ver):
    g, gg = fit_gains(S, rows_spec)
    print('  grupos: ' + ' '.join(f'{k}×{v:.2f}' for k, v in gg.items()))
    rms = lambda grp: sum(np.sqrt(np.mean((S[k] * g[k]) ** 2)) for k in S if group_of(k) == grp)
    total = sum(rms(d) for d in DRUM_SPLIT[ver])
    for d, share in DRUM_SPLIT[ver].items():
        cur = rms(d)
        if cur > 0:
            for k in S:
                if group_of(k) == d:
                    g[k] *= total * share / cur
    for k in S:
        if k in PERC:
            g[k] *= boost
    return g, boost


def export(name, y, ev):
    wav = os.path.join(OUT, name + '.wav')
    write_wav(wav, y)
    write_midi(os.path.join(OUT, name + '.mid'), ev)
    ogg = os.path.join(OUT, name + '.ogg')
    os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"')
    os.remove(wav)
    print(f'  {ogg}  {len(y) / SR:.2f} s')


def write_midi(path, ev):
    import mido
    tpb = 480
    mf = mido.MidiFile(ticks_per_beat=tpb)
    meta = mido.MidiTrack(); mf.tracks.append(meta)
    meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(BPM)))
    meta.append(mido.MetaMessage('time_signature', numerator=4, denominator=4))
    progs = {'lead': (0, 80), 'saw': (1, 81), 'keys': (2, 11), 'brass': (3, 62), 'gtr': (4, 30), 'bass': (5, 38),
             'drums': (9, 0)}
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


SECT = [(1, 8), (9, 16), (17, 24), (25, 36)]

if __name__ == '__main__':
    only = os.environ.get('ONLY')
    if only in (None, 'level'):
        set_tempo(LEVEL_BPM)
        T = load_midi()
        S = build_level(T)
        st = S.stems()
        ref = load_ref('level.ogg')
        spec = [((a - 1) * BAR, b * BAR, band_power(ref, (a - 1) * BAR + LEVEL_OFF, b * BAR + LEVEL_OFF)) for a, b in SECT]
        g, boost = balance(st, spec, PERC_EXTRA['level'], 'level')
        print(f'  nivel: batería ×{boost:.2f}')
        n = int(NB * BAR * SR)
        export('level_nes', master(fold_tail(mixdown(st, g, n), n), lufs=-11.0), S.ev)
    if only in (None, 'boss'):
        set_tempo(BOSS_BPM)
        T = load_midi()
        I, L = build_boss(T)
        sl = L.stems()
        ref = load_ref('boss_battle_loop.wav')
        R = band_power(ref, 0.032, 0.032 + 32 * BAR)            # (el sonido del remix de jefe original)
        spec = [(i * BAR, (i + 8) * BAR, R) for i in range(0, L.nb - 7, 8)]
        g, boost = balance(sl, spec, PERC_EXTRA['boss'], 'boss')
        print(f'  jefe: batería ×{boost:.2f}')
        n = int(L.nb * BAR * SR)
        loop = fold_tail(mixdown(sl, g, n), n)
        si = I.stems()
        intro = mixdown(si, g, int(I.nb * BAR * SR))[:int(I.nb * BAR * SR)]
        # (masterizadas juntas: mismo nivel en las dos partes)
        both = master(np.concatenate([intro, loop]), lufs=-10.0)
        export('boss_nes_intro', both[:len(intro)], I.ev)
        export('boss_nes_loop', both[len(intro):], L.ev)
