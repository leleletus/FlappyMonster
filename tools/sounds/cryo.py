#!/usr/bin/env python3
# tools/sounds/cryo.py
# Sonidos del congelador (assets/sounds/traps/cryo_*.wav):
#   cryo_windup  carga: siseo que sube de tono + crujidos de presión cada vez más seguidos
#   cryo_blast   disparo: chorro de gas (ruido que baja) con chasquidos de hielo dentro
#   cryo_freeze  algo queda congelado: crepitar cristalino que se cierra + tintineo
#   cryo_free    se rompe el bloque de hielo (salir o romperlo): estallido corto + trocitos
# Ejecutar desde la raíz del repo:  python3 tools/sounds/cryo.py [nombres...]
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, pad, mix, at, reson, sweep   # noqa: E402

OUT = 'assets/sounds/traps'
rng = np.random.default_rng(77)


def save(name, x, peak=0.95, drive=2.0):
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(x * drive) / np.tanh(drive)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = min(len(x), int(SR * 0.006))
    x[-fade:] *= np.linspace(1, 0, fade)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'  {OUT}/{name}.wav  {len(x) / SR:.2f} s')


def tink(f, d, g):
    tt = t_(d)
    y = sum(np.sin(2 * np.pi * f * k * tt) * a for k, a in ((1, 1.0), (2.76, 0.4), (5.4, 0.15)))
    return y * env(len(tt), 0.0005, d / 4) * g


def hiss_band(d, f0, f1):
    """Ruido filtrado por una banda que va de f0 a f1 (resonador que se mueve por tramos)."""
    n = int(SR * d)
    out = np.zeros(n)
    steps = 24
    for i in range(steps):
        a, b = i * n // steps, (i + 1) * n // steps
        f = f0 + (f1 - f0) * i / (steps - 1)
        seg = reson(noise((b - a) / SR), f, 6)
        seg = seg / (np.max(np.abs(seg)) + 1e-9)
        out[a:b] = seg[:b - a] * np.hanning(b - a) ** 0.3
    return out


def windup():
    d = 0.75
    h = hiss_band(d, 1800, 5200) * np.linspace(0.2, 1.0, int(SR * d)) * 0.8
    parts = [h]
    t0 = 0.05
    k = 0
    while t0 < d - 0.05:                                   # crujidos de presión que se aceleran
        c = reson(pad(noise(0.003) * env(int(SR * 0.003), 0.0002, 0.001), int(SR * 0.05)), 420 + k * 30, 14)
        c = c / (np.max(np.abs(c)) + 1e-9) * 0.5
        parts.append(at(c, t0))
        t0 += max(0.04, 0.16 - k * 0.022); k += 1
    return mix(*parts)


def blast():
    d = 0.95
    n = int(SR * d)
    gas = highpass(noise(d), 900) * env(n, 0.004, 0.45)
    gas = lowpass(gas, 7000)
    whoosh = sweep(900, 220, d) * env(n, 0.01, 0.3) * 0.25
    parts = [gas * 1.1, whoosh]
    for _ in range(14):
        t0 = rng.uniform(0.05, 0.75)
        parts.append(at(tink(rng.uniform(3000, 7000), rng.uniform(0.04, 0.09), rng.uniform(0.1, 0.3)), t0))
    return mix(*parts)


def freeze():
    d = 0.6
    parts = [np.zeros(int(SR * d))]
    t0 = 0.0
    k = 0
    while t0 < 0.38:                                       # crepitar que se va cerrando
        c = highpass(noise(0.004), 3000) * env(int(SR * 0.004), 0.0002, 0.0012) * (0.5 + 0.03 * k)
        parts.append(at(c, t0))
        t0 += max(0.008, 0.045 - k * 0.003); k += 1
    for f, t, g in ((2600, 0.36, 0.5), (3300, 0.39, 0.4), (4100, 0.42, 0.35)):
        parts.append(at(tink(f, 0.18, g), t))
    return mix(*parts)


def free():
    d = 0.55
    burst = highpass(noise(0.08), 1500) * env(int(SR * 0.08), 0.0005, 0.02) * 1.2
    parts = [np.zeros(int(SR * d)), burst]
    for _ in range(12):
        t0 = rng.uniform(0.01, 0.4)
        parts.append(at(tink(rng.uniform(2500, 6500), rng.uniform(0.06, 0.14), rng.uniform(0.15, 0.4) * (1 - t0)), t0))
    return mix(*parts)


if __name__ == '__main__':
    only = set(sys.argv[1:])
    print('Sonidos del congelador:')
    for name, fn in (('cryo_windup', windup), ('cryo_blast', blast), ('cryo_freeze', freeze), ('cryo_free', free)):
        if only and name not in only: continue
        save(name, fn())
