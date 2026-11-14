#!/usr/bin/env python3
# tools/sounds/hurry.py — el aviso «¡DATE PRISA!» (assets/sounds/jingles/hurry.wav, id 'hurryUp'): suena una vez
# cuando queda 1 minuto del tiempo límite del nivel, ENCIMA de la música (que se agacha mientras dura); justo después
# la música del nivel vuelve más rápida (×1.15).
# Composición original, do mayor, semicorchea = STEP s:
#   1) sirena de dos tonos sobre la dominante (sol7): si5–fa6 (el tritono del acorde) ×3 y un silencio;
#   2) la misma sirena otra vez, más fuerte y doblada una octava arriba (pulso de 12,5 %);
#   3) «la llamada» del juego (sol–do–mi–sol, el arranque de la música del mapa) subiendo a toda prisa;
#   4) el golpe final: do7 con acorde de do mayor, platillo de ruido y bombo; se apaga en ~0,4 s.
# Pulsos tipo 2A03 (25 % con barrido de ciclo), triángulo de bajo, ruido y bombo «DPCM» (seno con caída de tono).
# Solo biblioteca estándar (no hace falta numpy). Tramo más fuerte de 100 ms a -12 dBFS, como el resto de jingles.
# Desde la raíz del repo:  python3 tools/sounds/hurry.py
import array
import math
import random
import wave

SR, STEP = 44100, 0.06
OUT = 'assets/sounds/jingles/hurry.wav'
NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def hz(name):
    # 'F#6' -> frecuencia (la4 = 440)
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NAMES.index(n) + 12 * (o + 1) - 69) / 12)


# --- la partitura: (semicorchea de inicio, duración en semicorcheas, nota) ---
SIREN = ['B5', 'F6', 'B5', 'F6', 'B5', 'F6']           # tritono del sol7: alarma, pero dentro de la armonía
LEAD = [(i, 1, n) for i, n in enumerate(SIREN)]          # sirena 1 (semicorcheas 0-5, 6-7 silencio)
LEAD += [(8 + i, 1, n) for i, n in enumerate(SIREN)]     # sirena 2 (8-13, 14-15 silencio)
LLAMADA = ['G5', 'C6', 'E6', 'G6']
LEAD += [(16 + i, 1, n) for i, n in enumerate(LLAMADA)]  # la llamada (16-19)
ACCENT_AT = 20                                           # golpe final en la semicorchea 20
LEAD += [(ACCENT_AT, 8, 'C7')]
CHORD = ['C6', 'E6', 'G6']                               # acorde del golpe (pulso 50 %)
BASS = [(0, 2, 'G2'), (2, 2, 'G3'), (4, 2, 'G2'), (6, 2, 'G3'),
        (8, 2, 'G2'), (10, 2, 'G3'), (12, 2, 'G2'), (14, 2, 'G3'),
        (16, 2, 'G2'), (18, 2, 'B2'), (ACCENT_AT, 8, 'C3')]
SNARE = [0, 8, 12, 16, 18]                               # golpes de ruido corto
KICK = [0, 4, 8, 12, 16, ACCENT_AT]

TOTAL = ACCENT_AT * STEP + 0.42
N = int(SR * TOTAL)
y = [0.0] * N


def add(at, samples, g):
    i0 = int(SR * at)
    for k, v in enumerate(samples):
        if i0 + k >= N:
            break
        y[i0 + k] += v * g


def pulse(f, d, duty0, duty1, decay, vib=0.0):
    # pulso con barrido de ciclo (duty0 -> duty1), ataque de 3 ms y caída exponencial; vib = vibrato en semitonos
    out, ph = [], 0.0
    n = int(SR * d)
    for k in range(n):
        t = k / SR
        ff = f * 2 ** (vib * math.sin(2 * math.pi * 7 * t) * min(1, t / 0.12) / 12)
        ph = (ph + ff / SR) % 1
        duty = duty0 + (duty1 - duty0) * min(1, t / d)
        env = math.exp(-t / decay) * min(1, t / 0.003) * min(1, (d - t) / 0.004)
        out.append((1.0 if ph < duty else -1.0) * env)
    return out


def triangle(f, d, decay):
    out = []
    n = int(SR * d)
    for k in range(n):
        t = k / SR
        p = (t * f) % 1
        v = 4 * abs(p - 0.5) - 1
        v = round(v * 7.5) / 7.5                     # 16 escalones, como el triángulo del 2A03
        out.append(v * math.exp(-t / decay) * min(1, t / 0.002) * min(1, (d - t) / 0.004))
    return out


def noise(d, decay, period):
    # ruido de registro LFSR muestreado cada `period` muestras (corto = metálico)
    rnd = random.Random(7)
    out, v = [], 0.0
    for k in range(int(SR * d)):
        if k % period == 0:
            v = rnd.choice((-1.0, 1.0))
        out.append(v * math.exp(-k / SR / decay))
    return out


def kick(d=0.12):
    out, ph = [], 0.0
    for k in range(int(SR * d)):
        t = k / SR
        f = 55 + 110 * math.exp(-t / 0.02)
        ph += f / SR
        v = 1.0 if math.sin(2 * math.pi * ph) >= 0 else -1.0   # 1 bit, como el DPCM
        out.append(v * math.exp(-t / 0.035))
    return out


# --- mezcla ---
for s, n, note in LEAD:
    at, d = s * STEP, n * STEP
    if s >= ACCENT_AT:                                   # nota final: larga, con vibrato
        add(at, pulse(hz(note), 0.42, 0.125, 0.5, 0.13, vib=0.25), 0.55)
        add(at, pulse(hz(note) / 2, 0.42, 0.25, 0.25, 0.13), 0.30)    # doblada una octava abajo
        continue
    g = 0.42 if s < 8 else 0.50                          # la segunda sirena entra más fuerte
    add(at, pulse(hz(note), d * 0.9, 0.125, 0.5, 0.09), g)
    if s >= 8:                                           # sirena 2 y llamada: doblada una octava arriba
        add(at, pulse(hz(note) * 2, d * 0.85, 0.125, 0.125, 0.06), 0.16)
for k, note in enumerate(CHORD):
    add(ACCENT_AT * STEP + k * 0.006, pulse(hz(note), 0.40, 0.5, 0.5, 0.12), 0.16)
for s, n, note in BASS:
    d = n * STEP * 0.95 if s < ACCENT_AT else 0.42
    add(s * STEP, triangle(hz(note), d, 0.5 if s < ACCENT_AT else 0.15), 0.40)
for s in SNARE:
    add(s * STEP, noise(0.05, 0.015, 3), 0.18)
for s in KICK:
    add(s * STEP, kick(), 0.30)
add(ACCENT_AT * STEP, noise(0.40, 0.08, 1), 0.16)       # platillo del golpe final

# suavizado: paso bajo de un polo a ~6 kHz (los pulsos crudos pinchan por encima de la música)
a = math.exp(-2 * math.pi * 6000 / SR)
for i in range(1, N):
    y[i] = (1 - a) * y[i] + a * y[i - 1]
m = sum(y) / N
y = [v - m for v in y]

# nivel: tramo más fuerte de 100 ms a -12 dBFS
w100 = int(SR * 0.1)
best = max(sum(v * v for v in y[i:i + w100]) / w100 for i in range(0, N - w100, w100 // 4))
gain = 10 ** (-12 / 20) / math.sqrt(best)
# limitador suave (tanh) con techo en -6 dBFS: los picos sueltos del ataque no pinchan encima de la música;
# dos pasadas para que el tramo más fuerte vuelva a quedar a -12 dBFS
CEIL = 0.5
for _ in range(2):
    y = [CEIL * math.tanh(v * gain / CEIL) for v in y]
    best = max(sum(v * v for v in y[i:i + w100]) / w100 for i in range(0, N - w100, w100 // 4))
    gain = 10 ** (-12 / 20) / math.sqrt(best)
y = [max(-0.98, min(0.98, v)) for v in y]
fade = int(SR * 0.10)                                    # fundido de las últimas 100 ms
for k in range(fade):
    y[N - fade + k] *= 1 - k / fade

with wave.open(OUT, 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(array.array('h', (int(v * 32767) for v in y)).tobytes())


def db(x):
    return 10 * math.log10(sum(v * v for v in x) / max(1, len(x)) + 1e-12)


peak = max(abs(v) for v in y)
print('  %s  %.2f s · pico %.1f dBFS · RMS %.1f dBFS · recortadas %d muestras'
      % (OUT, N / SR, 20 * math.log10(peak), db(y), sum(1 for v in y if abs(v) >= 0.98)))
last = max(i for i, v in enumerate(y) if abs(v) > 10 ** (-40 / 20))
print('    último instante por encima de -40 dBFS: %.2f s' % (last / SR))
for t0 in (0.0, 8 * STEP, 16 * STEP, ACCENT_AT * STEP, ACCENT_AT * STEP + 0.15):
    print('    RMS %.2f-%.2f s: %.1f dBFS' % (t0, t0 + 0.15, db(y[int(SR * t0):int(SR * (t0 + 0.15))])))
for s, n, note in LEAD:
    print('    %.3f s  %-3s %6.0f Hz  (%d semicorchea%s)' % (s * STEP, note, hz(note), n, '' if n == 1 else 's'))
