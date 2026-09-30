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
import os, sys, wave
import numpy as np

SR = 44100
BPM = 185
E = 60.0 / BPM / 2                 # s por corchea
BAR = 8 * E
NBARS = 144                        # 72 × 2 vueltas (como el original)
FPS = 60.0988                      # frames del driver (NTSC)
CPU = 1789773.0
HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, '..', '..', 'assets', 'music')
# (partitura y MIDI de Musescore: con copyright, solo en local — tools/music/ref/ está en .gitignore)
MIDI_IN = os.path.join(HERE, 'ref', 'tentacle-tantrum-fall-guys-ss3s9.mid')
NAME = 'tentacle_nes'
rng = np.random.default_rng(2020)

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
def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def q_pulse(f):                      # frecuencia real del pulso (periodo de 11 bits)
    t = np.clip(np.round(CPU / (16 * f) - 1), 8, 2047)
    return CPU / (16 * (t + 1))


def q_tri(f):
    t = np.clip(np.round(CPU / (32 * f) - 1), 2, 2047)
    return CPU / (32 * (t + 1))


def q_vrc6(f):                       # (12 bits)
    t = np.clip(np.round(CPU / (16 * f) - 1), 8, 4095)
    return CPU / (16 * (t + 1))


def q_saw(f):
    t = np.clip(np.round(CPU / (14 * f) - 1), 8, 4095)
    return CPU / (14 * (t + 1))


NF = int(NBARS * BAR * FPS) + int(FPS * 2)
FRAME_S = SR / FPS


class Chan:
    """Registros por frame: frecuencia (Hz), volumen (0-15), duty"""
    def __init__(self):
        self.f = np.zeros(NF)
        self.v = np.zeros(NF)
        self.d = np.full(NF, 0.5)


def fr(t):
    return int(round(t * FPS))


def play(chn, t0, t1, m, inst, q=q_pulse, vs=1.0, arp=None, release=3):
    """Una nota con su instrumento: envolvente de volumen, duty, vibrato y
    arpegio frame a frame (como un driver de NES/FamiTracker)"""
    a, b = fr(t0), max(fr(t0) + 1, fr(t1))
    env = inst['vol']
    for k in range(a, min(NF, b + release)):
        i = k - a
        if k < b:
            vol = env[i] if i < len(env) else inst.get('sus', env[-1])
        else:                                                     # soltar
            vol = (env[min(i, len(env) - 1)] if i < len(env) else inst.get('sus', env[-1])) * (1 - (k - b + 1) / (release + 1))
        semi = 0.0
        vd, vdep, vrate = inst.get('vib', (0, 0, 0))
        if vdep and i >= vd:
            semi += vdep * np.sin(2 * np.pi * vrate * (i - vd) / FPS)
        if arp:
            semi += arp[(i // inst.get('arp_speed', 1)) % len(arp)]
        if inst.get('drop') and i < len(inst['drop']):
            semi += inst['drop'][i]
        chn.f[k] = q(hz(m + semi))
        chn.v[k] = min(15, round(vol * vs)) if k < b else round(vol * vs)
        dseq = inst.get('duty', 0.5)
        chn.d[k] = dseq[min(i, len(dseq) - 1)] if isinstance(dseq, (list, tuple)) else dseq


def polyblep(t, dt):
    y = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    y[m] = x + x - x * x - 1
    m2 = t > 1 - dt
    x = (t[m2] - 1) / dt[m2]
    y[m2] = x * x + x + x + 1
    return y


def per_sample(arr):
    idx = (np.arange(int(NF * FRAME_S)) / FRAME_S).astype(int)
    return arr[np.minimum(idx, NF - 1)]


def render_pulse(chn):
    f, v, d = per_sample(chn.f), per_sample(chn.v), per_sample(chn.d)
    dt = f / SR
    ph = np.cumsum(dt) % 1.0
    sq = np.where(ph < d, 1.0, -1.0)
    sq += polyblep(ph, np.maximum(dt, 1e-9))
    sq -= polyblep((ph - d) % 1.0, np.maximum(dt, 1e-9))
    return (sq * 0.5 + 0.5) * v                                  # 0..15 (como el DAC)


TRI32 = np.concatenate([np.arange(15, -1, -1), np.arange(0, 16)]).astype(float)


def render_tri(chn):
    f, on = per_sample(chn.f), per_sample(chn.v) > 0
    dt = np.where(on, f / SR, 0.0)                               # parado: se queda en su paso
    ph = np.cumsum(dt) % 1.0
    return TRI32[(ph * 32).astype(int) % 32]


def render_saw(chn):
    """Sierra del VRC6: 7 pasos de un acumulador (se oye escalonada)"""
    f, v = per_sample(chn.f), per_sample(chn.v)
    dt = f / SR
    ph = np.cumsum(dt) % 1.0
    step = np.floor(ph * 7) / 6.0
    s = step - polyblep(ph, np.maximum(dt, 1e-9)) * 0.5
    return s * v * 2.0                                           # 0..~31


NOISE_PER = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]


def lfsr(short):
    reg, out = 1, []
    n = 93 if short else 32767
    for _ in range(n):
        tap = 6 if short else 1
        fb = (reg & 1) ^ ((reg >> tap) & 1)
        reg = (reg >> 1) | (fb << 14)
        out.append(reg & 1)
    return np.array(out, float)


LFSR_LONG, LFSR_SHORT = lfsr(False), lfsr(True)


def render_noise(per, vol, short):
    p, v, s = per_sample(per), per_sample(vol), per_sample(short)
    rate = CPU / np.array(NOISE_PER)[p.astype(int)] / SR
    pos = np.cumsum(rate)
    a = LFSR_LONG[pos.astype(np.int64) % len(LFSR_LONG)]
    b = LFSR_SHORT[pos.astype(np.int64) % len(LFSR_SHORT)]
    return np.where(s > 0, b, a) * v


def dpcm(x, rate=33144.0):
    """Codifica en DPCM de 1 bit (±2 sobre 7 bits) y decodifica: el sonido real
    de las muestras del NES"""
    n = int(len(x) * rate / SR)
    src = np.interp(np.arange(n) * SR / rate, np.arange(len(x)), x)
    lvl, out = 64, np.zeros(n)
    tgt = 64 + src * 60
    for i in range(n):
        if tgt[i] > lvl and lvl <= 125: lvl += 2
        elif tgt[i] < lvl and lvl >= 2: lvl -= 2
        out[i] = lvl
    idx = (np.arange(int(n * SR / rate)) * rate / SR).astype(int)
    return out[np.minimum(idx, n - 1)] - 64


def t_(n):
    return np.arange(n) / SR


# Bombo afinado como el del original (su tono se queda en ~Fa#2: se ve en la
# croma de todo el tema como Fa-Fa#-Sol), cayendo desde ~220 Hz
KICK = dpcm(np.sin(2 * np.pi * np.cumsum(92 + 130 * np.exp(-t_(int(0.26 * SR)) / 0.025)) / SR) * np.exp(-t_(int(0.26 * SR)) / 0.11))
SNARE = dpcm((rng.uniform(-1, 1, int(0.14 * SR)) * 0.7 + np.sin(2 * np.pi * 190 * t_(int(0.14 * SR))) * 0.6)
             * np.exp(-t_(int(0.14 * SR)) / 0.045))

# ── Instrumentos (secuencias por frame) ──────────────────────────────────────
I_LEAD = {'vol': [15, 15, 14, 13, 13, 12], 'sus': 12, 'duty': 0.25, 'vib': (14, 0.22, 5.8)}
I_LEAD_BIG = {'vol': [15, 15, 14, 13, 13, 12], 'sus': 12, 'duty': 0.5, 'vib': (12, 0.28, 5.6)}
I_LEAD_RUN = {'vol': [14, 12, 11, 10], 'sus': 9, 'duty': [0.125, 0.125, 0.25], 'vib': (20, 0.15, 6)}
I_STAB = {'vol': [15, 13, 10, 8, 6, 5, 4], 'sus': 3, 'duty': [0.5, 0.25]}
I_ECHO = {'vol': [6, 6, 5, 5, 4], 'sus': 4, 'duty': 0.125}
I_HARM = {'vol': [10, 9, 9, 8], 'sus': 8, 'duty': 0.25, 'vib': (14, 0.2, 5.8)}
I_TRI = {'vol': [15], 'sus': 15}
I_CHOP = {'vol': [12, 10, 8, 6, 4, 3], 'sus': 0, 'duty': 0.375, 'arp_speed': 1}
I_PAD = {'vol': [4, 5, 5], 'sus': 5, 'duty': 0.25, 'arp_speed': 2}
I_SAW = {'vol': [12, 12, 11, 11, 10], 'sus': 10, 'vib': (14, 0.22, 5.6)}


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
    C = {k: Chan() for k in ('p1', 'p2', 'tri', 'v1', 'v2', 'saw')}
    nper, nvol, nshort = np.zeros(NF), np.zeros(NF), np.zeros(NF)
    dmc = np.zeros(int(NF * FRAME_S) + SR)
    ev = {k: [] for k in ('p1', 'p2', 'tri', 'v1', 'saw', 'drums')}

    def bar_of(t):
        return int(t / BAR + 1e-6) + 1

    # Melodía (pulso 1) + sierra (épico) + eco / 2ª voz (pulso 2)
    for s, e, n in top:
        b = bar_of(s)
        sec, second = section(b), b > 72
        dur = e - s
        inst = {'A': I_LEAD, 'BR': I_STAB, 'B': I_LEAD_BIG, 'C': I_LEAD_RUN, 'D': I_LEAD_BIG}[sec]
        gate = dur * (0.55 if sec == 'BR' else 0.92)
        play(C['p1'], s, s + gate, n, inst)
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

    # Bajo (triángulo): el del MIDI, menos la sección final (del original)
    for s, e, n in lh:
        b = bar_of(s)
        if section(b) == 'D':
            continue
        while n < 33: n += 12
        g = (e - s) * 0.88
        play(C['tri'], s, s + g, n, I_TRI, q=q_tri, release=0)
        ev['tri'].append((s, n, g))
    for b in range(1, NBARS + 1):
        if section(b) != 'D':
            continue
        r, _ = chord_at(b, 0)
        root = 36 + (r - 36) % 12 - (12 if r >= 8 else 0)         # Si1, Do#2, Re#2
        t0 = (b - 1) * BAR
        for st, dm, ln in ((0, 0, 3), (3, 7, 2), (5, 0, 3)):      # tresillo: raíz, 5ª, raíz
            play(C['tri'], t0 + st * E, t0 + (st + ln) * E * 0.9, root + dm, I_TRI, q=q_tri, release=0)
            ev['tri'].append((t0 + st * E, root + dm, ln * E * 0.9))

    # Acordes (VRC6): el "chop" en 2 y 4 como arpegio rápido; en el estribillo
    # y el final, además un colchón arpegiado suave
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
            if sec in ('B', 'D', 'BR') or (sec == 'C' and b > 72):
                play(C['v2'], t0 + half * 4 * E, t0 + (half * 4 + 4) * E * 0.98, base - 12, I_PAD, q=q_vrc6,
                     arp=[0, q[1], q[2], 12])

    # Batería: ruido (hi-hat, caja, platillos, redobles) + DPCM (bombo, caja)
    def noise(t, per, vols, short=0):
        a = fr(t)
        for i, v in enumerate(vols):
            if a + i < NF:
                nper[a + i], nvol[a + i], nshort[a + i] = per if not isinstance(per, list) else per[min(i, len(per) - 1)], v, short

    def sample(t, smp, g):
        i = int(t * SR)
        j = min(len(dmc), i + len(smp))
        dmc[i:j] = smp[:j - i] * g                                 # (monofónico: la nueva corta la anterior)
        dmc[j:j + int(0.01 * SR)] *= 0

    HAT = [8, 6, 3, 1]
    SN = [15, 13, 11, 9, 8, 6, 5, 4, 3, 2, 1]
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
            sample(t0 + st * E, KICK, 0.85)
            ev['drums'].append((t0 + st * E, 36, 0.1))
        for st in range(8):
            if st in snares:
                continue
            noise(t0 + st * E, 1 if st % 2 else 0, [x * (1.0 if st % 2 else 0.7) for x in HAT])
            ev['drums'].append((t0 + st * E, 42, 0.05))
        for st in snares:
            sample(t0 + st * E, SNARE, 0.8)
            noise(t0 + st * E, 5, SN)
            ev['drums'].append((t0 + st * E, 38, 0.1))
        if sec == 'C':                                             # (fantasma en el 2 del medio tiempo)
            noise(t0 + 2 * E, 6, [x * 0.45 for x in SN])
        # Platillo al empezar cada sección y redoble de caja antes
        if bb in (1, 17, 25, 41, 49, 57):
            noise(t0, 3, CRASH)
            ev['drums'].append((t0, 49, 0.5))
        if bb in (16, 24, 40, 56, 72):
            for k in range(8):
                ts = t0 + 4 * E + k * E / 2
                noise(ts, [5, 6], [int(8 + k), int(6 + k * 0.8), 4, 2])
                if k % 2 == 0:
                    sample(ts, SNARE, 0.5 + k * 0.06)
                ev['drums'].append((ts, 38, 0.05))
    return C, (nper, nvol, nshort), dmc, ev


def mix(C, noise, dmc):
    p1, p2 = render_pulse(C['p1']), render_pulse(C['p2'])
    tri = render_tri(C['tri'])
    nz = render_noise(*noise)
    v1, v2, saw = render_pulse(C['v1']), render_pulse(C['v2']), render_saw(C['saw'])
    n = min(len(p1), len(dmc))
    dm = (dmc[:n] + 64)
    solo = os.environ.get('SOLO')
    if solo:
        keep = set(solo.split(','))
        z = np.zeros(n)
        p1 = p1 if 'p1' in keep else z; p2 = p2 if 'p2' in keep else z
        tri = tri if 'tri' in keep else z; nz = nz if 'noise' in keep else z
        dm = dm if 'dmc' in keep else z + 64; v1 = v1 if 'v1' in keep else z
        v2 = v2 if 'v2' in keep else z; saw = saw if 'saw' in keep else z
    p = p1[:n] + p2[:n]
    pulse_out = np.where(p > 0, 95.88 / (8128.0 / np.maximum(p, 1e-6) + 100), 0.0)
    tnd = tri[:n] / 8227.0 + nz[:n] / 12241.0 + dm / 22638.0
    tnd_out = np.where(tnd > 0, 159.79 / (1.0 / np.maximum(tnd, 1e-9) + 100), 0.0)
    vrc6 = (v1[:n] + v2[:n] + saw[:n]) * 0.0085
    x = pulse_out + tnd_out + vrc6
    # Filtros de la consola: paso alto ~37 Hz, paso bajo ~14 kHz
    from scipy.signal import butter, sosfilt
    x = sosfilt(butter(1, 37, btype='high', fs=SR, output='sos'), x)
    x = sosfilt(butter(1, 14000, btype='low', fs=SR, output='sos'), x)
    # Estéreo discreto (como un emulador con separación de canales suave)
    L = x + (p2[:n] * 0.004 - v1[:n] * 0.003)
    R = x + (v1[:n] * 0.003 - p2[:n] * 0.004)
    y = np.stack([L, R], 1)
    y = y[:int(NBARS * BAR * SR)]
    # Nivel como el original (RMS ≈ 0.19): limitador suave
    y = y / (np.sqrt(np.mean(y ** 2)) + 1e-9) * 0.19
    return np.tanh(y * 1.4) / 1.4


def write_wav(path, x):
    with wave.open(path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())


def write_midi(path, ev):
    import mido
    tpb = 480
    mf = mido.MidiFile(ticks_per_beat=tpb)
    meta = mido.MidiTrack(); mf.tracks.append(meta)
    meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(BPM)))
    meta.append(mido.MetaMessage('time_signature', numerator=4, denominator=4))
    chans = (('p1', 0, 80, 'Pulso 1 (melodia)'), ('p2', 1, 80, 'Pulso 2 (2a voz)'), ('tri', 2, 38, 'Triangulo (bajo)'),
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
    C, nz, dmc, ev = arrange()
    y = mix(C, nz, dmc)
    wav = os.path.join(OUT, NAME + '.wav')
    write_wav(wav, y)
    write_midi(os.path.join(OUT, NAME + '.mid'), ev)
    ogg = os.path.join(OUT, NAME + '.ogg')
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
