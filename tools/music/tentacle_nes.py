#!/usr/bin/env python3
# tools/music/tentacle_nes.py
# "Tentacle Tantrum" (Fall Guys, Daniel Hagström) recreado FIELMENTE como
# música de NES: la partitura/MIDI (tools/music/ref/, solo en local; arreglo
# para piano) da la melodía y el bajo nota a nota; el audio original
# (TentacleTantrum.ogg) da lo que el MIDI no tiene o tiene distinto: la batería,
# los acordes y el bajo de la sección final (el MIDI la armoniza con La♭–Mi♭–Sol;
# el original hace Si–Do#–Re#, ♭VI–♭VII–I).
#
#   python3 tools/music/tentacle_nes.py   → assets/music/tentacle_nes.ogg (+ .mid)
#   SOLO=p1,tri python3 ...               → solo esos canales
#
# Sonido de consola REAL (NES 2A03 + chip de expansión VRC6, el de Akumajō
# Densetsu / Castlevania III): cada canal es monofónico, el "driver" actualiza
# volumen (4 bits), duty, vibrato y arpegios a 60 Hz, las frecuencias salen de
# los periodos del chip, el triángulo tiene 32 pasos, el ruido es el LFSR de 15
# bits, el bombo y la caja son muestras DPCM de 1 bit, y se mezcla con el
# mezclador no lineal y los filtros de la consola.
#   Pulso 1  melodía              Pulso 2  eco (NES clásico) / 2ª voz
#   Triángulo  bajo               Ruido  hi-hat, caja, platillos, redobles
#   DPCM  bombo y caja            VRC6 pulsos  acordes en arpegio (el "chop")
#   VRC6 sierra  dobla la melodía en el estribillo y el final (lo épico)
#
# Lo medido en el original (librosa; ver el final del archivo): 185 BPM
# exactos (la rejilla de corcheas empieza a los 0.042 s), 72 compases que se
# repiten (186.8 s), en la misma tonalidad que el MIDI. Secciones y acordes:
#   1-8   riff en Fa#m (Fa#m/Re, Sim, Re)      9-16  el riff medio tono arriba (Solm)
#   17-24 break: golpes Si♭/Si en negras     25-40 estribillo: Rem Do Si♭ Si♭ Solm La Si♭ Do
#   41-48 escalas en Mi: Do#m Si La La Fa#m Sol#m La Si
#   49-56 las mismas en Fa (Rem Do Si♭ Si♭ Solm Lam Si♭ Do)
#   57-72 el final: Si – Do# – Re# – Re# (×4)
#   Batería: bombo en tresillo (corcheas 0, 3 y 5), caja en 2 y 4, hi-hat en
#   corcheas; el break en negras.
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as _fam
from famicom import (master, biquad, SR, FPS, CPU, FRAME_S, frames_for, t_, Chan, fr, hz, q_pulse, q_tri, q_vrc6, q_saw, q_n163,
                     play, per_sample, render_pulse, render_tri, render_saw, render_noise, dpcm, wavetable,
                     render_wave, Noise, pulse_dac, tnd_dac, OCT, band_power, write_wav)   # (motor de Famicom)

BPM = 185
E = 60.0 / BPM / 2                 # s por corchea
BAR = 8 * E
NBARS = 144                        # 72 × 2 vueltas (como el original)
HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, '..', '..', 'assets', 'music')
# (partitura y MIDI de Musescore: con copyright, solo en local — tools/music/ref/ está en .gitignore)
MIDI_IN = os.path.join(HERE, 'ref', 'tentacle-tantrum-fall-guys-ss3s9.mid')
NAME = 'tentacle_nes'
rng = np.random.default_rng(2020)
NF = frames_for(NBARS * BAR)

# ── Armonía (del original, por compás; una lista = por mitades) ──────────────
MAJ, MIN = (0, 4, 7), (0, 3, 7)
N = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7,
     'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def ch(s):
    m = s.endswith('m')
    return (N[s[:-1] if m else s], MIN if m else MAJ)


HARM = (['F#m', ['F#m', 'D'], 'F#m', ['F#m', 'D'], 'F#m', 'D', 'Bm', 'D'] +
        ['Gm', ['Gm', 'Eb'], 'Gm', ['Gm', 'Eb'], 'Gm', 'Eb', 'Cm', 'Eb'] +
        ['Bb', 'B', 'Bb', 'B', 'Bb', 'B', 'Dm', ['F', 'G']] +
        ['Dm', 'C', 'Bb', 'Bb', 'Gm', 'A', 'Bb', 'C'] * 2 +
        ['C#m', 'B', 'A', 'A', 'F#m', 'G#m', 'A', 'B'] +
        ['Dm', 'C', 'Bb', 'Bb', 'Gm', 'Am', 'Bb', 'C'] +
        ['B', 'C#', 'D#', 'D#'] * 4)
assert len(HARM) == 72


def chord_at(bar, half):               # bar 1-based (1-144)
    h = HARM[(bar - 1) % 72]
    return ch(h[half] if isinstance(h, list) else h)


def section(bar):
    b = (bar - 1) % 72 + 1
    return 'A' if b <= 16 else 'BR' if b <= 24 else 'B' if b <= 40 else 'C' if b <= 56 else 'D'


# ── Motor NES ────────────────────────────────────────────────────────────────
# ── Ondas del Namco 163 (tablas de 32 muestras de 4 bits) ────────────────────
# Hechas con la HUELLA de los instrumentos del original: fuerza de cada
# armónico medida en el ogg sobre las notas del MIDI (mediana de decenas de
# notas por sección; ver el final del archivo). El N163 es un chip de
# expansión real de la Famicom: así el timbre se parece al original sin dejar
# de ser 4 bits.
WAVES = [
    wavetable([1.0, 1.2, 0.65, 0.6, 0.25, 0.5, 0.08, 0.1]),       # 0 melodía del riff y el break
    wavetable([1.0, 1.1, 0.8, 0.65, 0.1, 0.45, 0.07, 0.2]),       # 1 estribillo
    wavetable([1.0, 0.6, 0.6, 0.55, 0.15, 0.26, 0.11, 0.12]),     # 2 escalas
    wavetable([1.0, 0.94, 0.13, 0.15, 0.05, 0.11]),               # 3 final (casi puro: fundamental + octava)
    wavetable([1.0, 0.39, 0.02, 0.06, 0.0, 0.07]),                # 4 bajo (redondo: seno + un poco de octava)
]
WAVE_OF = {'A': 0, 'BR': 0, 'B': 1, 'C': 2, 'D': 3}


# ── Batería (medida en el original) ──────────────────────────────────────────
# Bombo: golpe que cae de ~275 a ~160 Hz en 100 ms y se queda en ~Fa#2 (su
# tono se ve en la croma de todo el tema), con un clic de ataque. DPCM de 1 bit.
_kt = t_(int(0.36 * SR))
KICK = dpcm(np.clip(1.25 * np.sin(2 * np.pi * np.cumsum(92 + 60 * np.exp(-_kt / 0.08) + 140 * np.exp(-_kt / 0.018)) / SR)
                    * np.exp(-_kt / 0.17), -1, 1)
            + np.concatenate([rng.uniform(-0.6, 0.6, int(0.004 * SR)), np.zeros(len(_kt) - int(0.004 * SR))]))
# En el break el bombo es un "boom" una octava más grave (~Fa#1-Sol1, 47 Hz:
# ahí está casi toda la energía del original en esa sección)
_kd = t_(int(0.34 * SR))
KICK_DEEP = dpcm(np.clip(1.3 * np.sin(2 * np.pi * np.cumsum(47 + 40 * np.exp(-_kd / 0.06) + 110 * np.exp(-_kd / 0.015)) / SR)
                         * np.exp(-_kd / 0.2), -1, 1))
# Caja: brillante y MUY corta (a la mitad en 15 ms, al 20 % en 45 ms): ruido
# agudo + un poco de cuerpo; la muestra DPCM solo da el golpe
SNARE_BODY = dpcm(np.sin(2 * np.pi * 200 * t_(int(0.05 * SR))) * np.exp(-t_(int(0.05 * SR)) / 0.015))

# ── Instrumentos (secuencias por frame) ──────────────────────────────────────
I_LEAD = {'vol': [15, 15, 14, 14, 13, 13], 'sus': 13, 'vib': (14, 0.2, 5.8)}
I_LEAD_BIG = {'vol': [15, 15, 15, 14, 14, 14], 'sus': 14, 'vib': (12, 0.26, 5.6)}
I_LEAD_RUN = {'vol': [15, 14, 13, 12], 'sus': 12, 'vib': (20, 0.12, 6)}
I_STAB = {'vol': [15, 13, 11, 9, 7, 6, 5], 'sus': 4}
I_ECHO = {'vol': [6, 6, 5, 5, 4], 'sus': 4, 'duty': 0.125}
I_HARM = {'vol': [10, 9, 9, 8], 'sus': 8, 'duty': 0.25, 'vib': (14, 0.2, 5.8)}
I_TRI = {'vol': [15], 'sus': 15}
I_BASS = {'vol': [15, 15, 14, 14, 13], 'sus': 13}
I_CHOP = {'vol': [15, 13, 11, 9, 7, 5, 3], 'sus': 0, 'duty': 0.25, 'arp_speed': 1}
I_PAD = {'vol': [4, 5, 5], 'sus': 5, 'duty': 0.25, 'arp_speed': 2}
I_SAW = {'vol': [12, 12, 11, 11, 10], 'sus': 10, 'vib': (14, 0.22, 5.6)}
# Energía (le faltaba brillo y ataque al compararla con el original): capa de
# pulso del 2A03 sobre la melodía con barrido de duty y un golpe de tono al
# atacar (el lead "que corta" de los juegos de NES), acordes más brillantes
I_BITE = {'vol': [13, 12, 11, 10, 10, 9], 'sus': 9, 'duty': [0.125, 0.125, 0.25, 0.25, 0.25, 0.5],
          'vib': (14, 0.22, 5.8), 'drop': [0.7, 0.35, 0.15]}
I_BITE_STAB = {'vol': [15, 13, 10, 8, 6, 4, 3], 'sus': 2, 'duty': [0.5, 0.25, 0.25, 0.125], 'drop': [1.0, 0.5, 0.2]}
I_SHIMMER = {'vol': [8, 7, 6, 5, 4, 3], 'sus': 2, 'duty': 0.125, 'arp_speed': 1}


# ── MIDI de referencia ───────────────────────────────────────────────────────
def load_midi():
    import mido
    m = mido.MidiFile(MIDI_IN)
    rh, lh = [], []
    for i, tr in enumerate(m.tracks):
        t, on = 0.0, {}
        for e in tr:
            t += mido.tick2second(e.time, m.ticks_per_beat, mido.bpm2tempo(BPM))
            if e.type == 'note_on' and e.velocity > 0:
                on[e.note] = t
            elif e.type in ('note_off', 'note_on') and e.note in on:
                (rh if i == 0 else lh).append((on.pop(e.note), t, e.note))
    return sorted(rh), sorted(lh)


def voices(notes):
    """Mano derecha → voz de arriba (melodía) y, si suena a la vez otra más
    grave, la 2ª voz"""
    top, low = [], []
    groups = {}
    for s, e, n in notes:
        groups.setdefault(round(s / E * 2), []).append((s, e, n))
    for k in sorted(groups):
        g = sorted(groups[k], key=lambda x: -x[2])
        top.append(g[0])
        low += g[1:2]
    return top, low


# ── Arreglo ──────────────────────────────────────────────────────────────────
def arrange():
    rh, lh = load_midi()
    top, low = voices(rh)
    C = {k: Chan(NF) for k in ('lead', 'p1', 'p2', 'tri', 'bass', 'v1', 'v2', 'saw')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash')}
    NS = int(NF * FRAME_S) + SR
    DM = {'kick': np.zeros(NS), 'snare': np.zeros(NS)}
    ev = {k: [] for k in ('p1', 'p2', 'tri', 'v1', 'saw', 'drums')}

    def bar_of(t):
        return int(t / BAR + 1e-6) + 1

    # Melodía (N163, con la onda de cada sección) + sierra (épico) + eco / 2ª voz (pulso 2)
    for s, e, n in top:
        b = bar_of(s)
        sec, second = section(b), b > 72
        dur = e - s
        inst = {'A': I_LEAD, 'BR': I_STAB, 'B': I_LEAD_BIG, 'C': I_LEAD_RUN, 'D': I_LEAD_BIG}[sec]
        gate = dur * (0.55 if sec == 'BR' else 0.92)
        inst = dict(inst, duty=float(WAVE_OF[sec]))              # (en el N163, "duty" = nº de onda)
        play(C['lead'], s, s + gate, n, inst, q=q_n163)
        play(C['p1'], s, s + gate, n, I_BITE_STAB if sec == 'BR' else I_BITE)
        ev['p1'].append((s, n, gate))
        if sec == 'D' or (second and sec == 'B'):
            play(C['saw'], s, s + gate, n - 12, I_SAW, q=q_saw)
            ev['saw'].append((s, n - 12, gate))
    has_low = {round(s / E * 2) for s, e, n in low}
    for s, e, n in low:
        if section(bar_of(s)) != 'BR':
            play(C['p2'], s, s + (e - s) * 0.9, n, I_HARM)
            ev['p2'].append((s, n, (e - s) * 0.9))
    for s, e, n in top:                                          # eco a una corchea
        b = bar_of(s)
        if round(s / E * 2) in has_low or section(b) == 'BR':
            continue
        play(C['p2'], s + E, s + E + (e - s) * 0.8, n, I_ECHO)

    # Bajo: N163 con la onda medida (redonda) + el triángulo debajo (peso)
    def bass_note(t0, t1, n, sub=True):
        play(C['bass'], t0, t1, n, dict(I_BASS, duty=4.0), q=q_n163, release=2)
        # (el triángulo una octava por debajo: el sub-grave del original, 40-63 Hz)
        play(C['tri'], t0, t1, n - 12 if n >= 40 and sub else n, I_TRI, q=q_tri, release=0)
        ev['tri'].append((t0, n, t1 - t0))
    for s, e, n in lh:
        sec = section(bar_of(s))
        if sec == 'D':
            continue
        while n < 33: n += 12
        if sec == 'BR':
            # (en el break el bajo va con los golpes, corto y sin sub: manda el bombo)
            bass_note(s, s + (e - s) * 0.4, n, sub=False)
        else:
            bass_note(s, s + (e - s) * 0.88, n)
    for b in range(1, NBARS + 1):                                # la sección final: del original
        if section(b) != 'D':
            continue
        r, _ = chord_at(b, 0)
        root = 36 + (r - 36) % 12 - (12 if r >= 8 else 0)         # Si1, Do#2, Re#2
        t0 = (b - 1) * BAR
        for st, dm, ln in ((0, 0, 3), (3, 7, 2), (5, 0, 3)):      # tresillo: raíz, 5ª, raíz
            bass_note(t0 + st * E, t0 + (st + ln) * E * 0.9, root + dm)

    # Acordes (VRC6): el "chop" en 2 y 4 como arpegio rápido; colchón arpegiado
    for b in range(1, NBARS + 1):
        sec = section(b)
        t0 = (b - 1) * BAR
        for half in (0, 1):
            r, q = chord_at(b, half)
            base = 60 + (r - 60) % 12
            arp = [0, q[1], q[2]]
            if sec != 'BR':
                st = 2 + half * 4                                  # tiempos 2 y 4
                play(C['v1'], t0 + st * E, t0 + (st + 1) * E, base, I_CHOP, q=q_vrc6, arp=arp)
                ev['v1'] += [(t0 + st * E, base + x, E * 0.6) for x in arp]
            if sec == 'C':
                # Escalas: brillo en semicorcheas (arpegio del acorde a la octava alta)
                for k in range(4):
                    tt = t0 + (half * 4 + k) * E
                    play(C['v2'], tt, tt + E * 0.9, base + 12, I_SHIMMER, q=q_vrc6, arp=[0, q[1], q[2], 12])
            elif sec == 'BR':
                # Break: golpe de acorde en cada negra (antes el break se quedaba sin medios)
                for k in (0, 2):
                    tt = t0 + (half * 4 + k) * E
                    play(C['v2'], tt, tt + E * 0.8, base, I_SHIMMER, q=q_vrc6, arp=arp)
            elif sec in ('B', 'D'):
                play(C['v2'], t0 + half * 4 * E, t0 + (half * 4 + 4) * E * 0.98, base - 12, I_PAD, q=q_vrc6,
                     arp=[0, q[1], q[2], 12])

    # Batería
    def sample(buf, t, smp, g):
        i = int(t * SR)
        j = min(len(buf), i + len(smp))
        buf[i:j] = smp[:j - i] * g                                 # (monofónico: la nueva corta la anterior)

    HAT = [9, 8, 7, 6, 5, 4, 3, 2, 1]                               # (a la mitad en ~70 ms, como el original)
    SN_HI, SN_MID = [15, 12, 8, 5, 3, 2, 1], [9, 5, 3, 1]           # (brillante y con algo más de cola)
    CRASH = [15, 14, 13, 12, 12, 11, 10, 10, 9, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1]
    for b in range(1, NBARS + 1):
        sec = section(b)
        bb = (b - 1) % 72 + 1
        t0 = (b - 1) * BAR
        if sec == 'BR':
            kicks, snares = (0, 2, 4, 6), (2, 6)                   # (el break: bombo en cada negra)
        elif sec == 'C':
            kicks, snares = (0, 3, 6), (4,)
        else:
            kicks, snares = (0, 3, 5), (2, 6)
        if sec == 'D' and bb % 2 == 0:
            kicks = (0, 3, 5, 7)
        for st in kicks:
            sample(DM['kick'], t0 + st * E, KICK_DEEP if sec == 'BR' else KICK, 1.0)
            ev['drums'].append((t0 + st * E, 36, 0.1))
        for st in range(8):
            if st in snares:
                continue
            NZ['hat'].hit(t0 + st * E, 0, [x * (1.0 if st % 2 else 0.6) for x in HAT])
            ev['drums'].append((t0 + st * E, 42, 0.05))
            if sec in ('B', 'C', 'D') and st + 1 not in snares:     # (semicorchea fantasma: más empuje)
                NZ['hat'].hit(t0 + st * E + E / 2, 0, [4, 2, 1])
        for st in snares:
            NZ['snare'].hit(t0 + st * E, [0, 1, 1, 2, 3, 4], SN_HI)
            sample(DM['snare'], t0 + st * E, SNARE_BODY, 1.0)
            ev['drums'].append((t0 + st * E, 38, 0.1))
        if sec == 'C':                                             # (fantasma en el 2 del medio tiempo)
            NZ['snare'].hit(t0 + 2 * E, 2, [x * 0.45 for x in SN_MID])
        if bb in (1, 17, 25, 41, 49, 57):                          # platillo al empezar cada sección
            NZ['crash'].hit(t0, 3, CRASH)
            ev['drums'].append((t0, 49, 0.5))
        if bb in (16, 24, 40, 56, 72):                             # redoble antes
            for k in range(8):
                ts = t0 + 4 * E + k * E / 2
                NZ['snare'].hit(ts, [2, 3], [int(7 + k), int(5 + k * 0.7), 3, 1])
                if k % 2 == 0:
                    sample(DM['snare'], ts, SNARE_BODY, 0.5 + k * 0.06)
                ev['drums'].append((ts, 38, 0.05))
    return C, NZ, DM, ev


# ── Mezcla ───────────────────────────────────────────────────────────────────
# Cada instrumento se renderiza aparte con la salida de su chip (2A03: curvas
# no lineales del DAC; VRC6 y N163: lineales) y se mezcla con GANANCIAS
# AJUSTADAS al original: potencia por bandas de octava de cada sección del
# original ≈ suma de las de los instrumentos (mínimos cuadrados con límites,
# para que nada desaparezca ni se dispare). Así el equilibrio melodía /
# percusión / bajo es el del original, no el de "todo a tope".
def stems(C, NZ, DM):
    n = int(NBARS * BAR * SR)
    cut = lambda x: x[:n] - np.mean(x[:n])
    return {
        'lead':  cut(render_wave(C['lead'], WAVES) * 0.0075),
        'p1':    cut(pulse_dac(render_pulse(C['p1']))),
        'saw':   cut(render_saw(C['saw']) * 0.0075),
        'p2':    cut(pulse_dac(render_pulse(C['p2']))),
        'bass':  cut(render_wave(C['bass'], WAVES) * 0.0075),
        'tri':   cut(tnd_dac(render_tri(C['tri']) / 8227.0)),
        'v1':    cut(render_pulse(C['v1']) * 0.0075),
        'v2':    cut(render_pulse(C['v2']) * 0.0075),
        'kick':  cut(tnd_dac((DM['kick'] + 64) / 22638.0)),
        'snare': cut(tnd_dac(NZ['snare'].render() / 12241.0)) + cut(tnd_dac((DM['snare'] + 64) / 22638.0)),
        'hat':   cut(tnd_dac(NZ['hat'].render() / 12241.0)),
        'crash': cut(tnd_dac(NZ['crash'].render() / 12241.0)),
    }


SECS = {'A': (1, 16), 'BR': (17, 24), 'B': (25, 40), 'C': (41, 56), 'D': (57, 72)}
# Límites de la ganancia (× la de partida): la melodía puede bajar mucho, la
# percusión y el bajo subir mucho, y nada se apaga del todo
BOUNDS = {'lead': (0.15, 1.5), 'p1': (0.15, 1.2), 'saw': (0.1, 1.5), 'p2': (0.5, 1.5), 'bass': (0.3, 6), 'tri': (0.3, 4),
          'v1': (0.2, 1.6), 'v2': (0.2, 1.6), 'kick': (0.5, 8), 'snare': (0.3, 8), 'hat': (0.3, 6), 'crash': (0.2, 3)}


def fit_gains(S):
    """Ganancias por instrumento para que el reparto por bandas y secciones se
    parezca al del original (TentacleTantrum.ogg, desfase 0.042 s)"""
    import librosa
    from scipy.optimize import lsq_linear
    ref, _ = librosa.load(_fam.ref('TentacleTantrum.ogg'), sr=SR, mono=True)
    names = list(S)
    rows, tgt = [], []
    for sec, (b0, b1) in SECS.items():
        for p in (0, 72):
            t0, t1 = (p + b0 - 1) * BAR, (p + b1) * BAR
            R = band_power(ref, t0 + 0.042, t1 + 0.042)
            M = np.array([band_power(S[k], t0, t1) for k in names]).T  # bandas × instrumentos
            for j in range(len(OCT)):
                rows.append(M[j] / R[j]); tgt.append(1.0)          # (error relativo por banda)
    A, y = np.array(rows), np.array(tgt)
    lo = np.array([BOUNDS[k][0] ** 2 for k in names]); hi = np.array([BOUNDS[k][1] ** 2 for k in names])
    # (escala común libre: se ajusta primero con todo a 1)
    s = np.sum(A.sum(1) * y) / np.sum(A.sum(1) ** 2)
    res = lsq_linear(A * s, y, bounds=(lo, hi))
    g = np.sqrt(res.x)
    return dict(zip(names, g)), s


# El original tiene más percusión respecto a lo armónico (HPSS: 0.21) que lo
# que da el ajuste por bandas (0.13): la batería se sube después
PERC_BOOST = {'kick': 2.0, 'snare': 1.8, 'hat': 1.4, 'crash': 0.45}   # (el platillo tapaba la melodía)
# En el juego (música a 0.9, efectos encima) el acompañamiento se perdía
# detrás de la melodía: se sube y la melodía baja un poco
BACKING = {'v1': 1.8, 'v2': 0.9, 'bass': 1.0, 'tri': 1.0, 'p2': 1.3, 'saw': 1.3, 'lead': 0.85}   # (bajo sin empuje: embarraba 125-250 Hz)


MAX_UNDER_MELODY = 0.45


def mix(C, NZ, DM, report=True):
    S = stems(C, NZ, DM)
    g, s = fit_gains(S)
    for k, v in list(PERC_BOOST.items()) + list(BACKING.items()):
        g[k] *= v
    # La melodía manda: ninguna capa de acompañamiento pasa del 45 % de la
    # melodía en su banda (1-5 kHz) en ninguna sección
    from scipy.signal import butter, sosfilt
    sos = butter(4, [1000, 5000], btype='band', fs=SR, output='sos')
    band = {k: sosfilt(sos, S[k]) for k in S}
    for k in S:
        if k in ('lead', 'p1', 'kick', 'tri', 'bass'):
            continue
        worst = 0.0
        for a, b in SECS.values():
            for p in (0, 72):
                i, j = int((p + a - 1) * BAR * SR), int((p + b) * BAR * SR)
                mel = np.sqrt(np.mean((band['lead'][i:j] * g['lead'] + band['p1'][i:j] * g['p1']) ** 2))
                x = np.sqrt(np.mean((band[k][i:j] * g[k]) ** 2))
                if mel > 0:
                    worst = max(worst, x / mel)
        if worst > MAX_UNDER_MELODY:
            g[k] *= MAX_UNDER_MELODY / worst
    if report:
        print('  ganancias ajustadas al original: ' + ' '.join(f'{k}={v:.2f}' for k, v in g.items()))
    solo = os.environ.get('SOLO')
    keep = set(solo.split(',')) if solo else set(S)
    x = sum(S[k] * g[k] for k in S if k in keep)
    from scipy.signal import butter, sosfilt
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    x = sosfilt(butter(1, 14000, btype='low', fs=SR, output='sos'), x)
    # Estéreo discreto (separación suave de canales, como un emulador)
    side = S['p2'] * g['p2'] * 0.35 - S['v1'] * g['v1'] * 0.3 + S['hat'] * g['hat'] * 0.2
    y = np.stack([x + side, x - side], 1)
    # EQ (medido frente al original): menos barro en 125-250 Hz, más brillo arriba
    y = biquad(y, 'peak', 180, -3.5, 0.9)
    y = biquad(y, 'high', 4500, 1.2)
    # Más fuerte que el original (-12.2 LUFS) para que en el juego se oiga lleno
    return master(y, lufs=-10.5)


def write_midi(path, ev):
    import mido
    tpb = 480
    mf = mido.MidiFile(ticks_per_beat=tpb)
    meta = mido.MidiTrack(); mf.tracks.append(meta)
    meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(BPM)))
    meta.append(mido.MetaMessage('time_signature', numerator=4, denominator=4))
    chans = (('p1', 0, 80, 'N163 (melodia)'), ('p2', 1, 80, 'Pulso 2 (2a voz)'), ('tri', 2, 38, 'N163 + triangulo (bajo)'),
             ('v1', 3, 81, 'VRC6 (acordes)'), ('saw', 4, 81, 'VRC6 sierra'), ('drums', 9, 0, 'Ruido + DPCM'))
    for key, c, prog, name in chans:
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
    C, NZ, DM, ev = arrange()
    y = mix(C, NZ, DM)
    wav = _fam.out(NAME, 'wav')
    write_wav(wav, y)
    write_midi(_fam.out(NAME, 'mid'), ev)
    ogg = _fam.out(NAME, 'ogg')
    os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"')
    os.remove(wav)
    print(f'  {ogg}  {len(y) / SR:.1f} s  (+ {NAME}.mid)')

# ── Cómo se analizó (para repetirlo) ─────────────────────────────────────────
#   · MIDI ↔ audio: croma del MIDI (piano roll) contra la del ogg en todas las
#     transposiciones y desfases → misma tonalidad, el ogg ~0.1 s después.
#   · Tempo/rejilla: corcheas ajustadas a los ataques (onset_strength) → 185.00
#     BPM, fase 0.042 s.
#   · Correlación por compás MIDI vs ogg: bien salvo 17-24 (el break: domina la
#     batería; las notas del MIDI valen) y 57-72 (armonía distinta: el bajo del
#     original, con pyin por corcheas, hace Si – Do# – Re#).
#   · Acordes: croma de la parte armónica (HPSS) por medio compás contra
#     tríadas, con el bajo del MIDI como pista de la fundamental.
#   · Batería: flujo espectral por bandas en la parte percusiva, promediado
#     por sección en semicorcheas.
