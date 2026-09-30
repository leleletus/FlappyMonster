#!/usr/bin/env python3
# tools/sounds/ice.py
# Sonidos del hielo (assets/sounds/mechanics/ice_*.wav):
#   ice_crack  el hielo fino se agrieta: chasquido seco y agudo + crujido corto
#   ice_break  el hielo fino se rompe: estallido de hielo + trozos tintineando
# Ejecutar desde la raíz del repo:  python3 tools/sounds/ice.py [nombres...]
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, pad, mix, at, reson, sweep   # noqa: E402

OUT = 'assets/sounds/mechanics'
rng = np.random.default_rng(31)


def save(name, x, peak=0.95, drive=2.5):
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(x * drive) / np.tanh(drive)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'  {OUT}/{name}.wav  {len(x) / SR:.2f} s')


def tink(f, d, g):
    tt = t_(d)
    y = sum(np.sin(2 * np.pi * f * k * tt) * a for k, a in ((1, 1.0), (2.9, 0.4), (5.2, 0.2)))
    return y * env(len(tt), 0.0006, d / 5) * g


def crack():
    d = 0.4
    snap = highpass(noise(0.02), 2200) * env(int(SR * 0.02), 0.0002, 0.004) * 1.4
    body = reson(pad(noise(0.004) * env(int(SR * 0.004), 0.0002, 0.001), int(SR * 0.2)), 1900, 18)
    body = body / (np.max(np.abs(body)) + 1e-9) * 0.7
    parts = [np.zeros(int(SR * d)), snap, body]
    t0 = 0.03                                     # crujido: chasquidos cada vez más flojos
    for k in range(6):
        c = highpass(noise(0.006), 1800) * env(int(SR * 0.006), 0.0003, 0.0015) * (0.6 - k * 0.08)
        parts.append(at(c, t0))
        t0 += rng.uniform(0.025, 0.05)
    parts.append(at(tink(3100, 0.18, 0.35), 0.01))
    return mix(*parts)


def shatter():
    d = 0.9
    burst = highpass(noise(0.12), 1500) * env(int(SR * 0.12), 0.0005, 0.03) * 1.3
    thud = sweep(260, 90, 0.15) * env(int(SR * 0.15), 0.001, 0.04) * 0.9
    parts = [np.zeros(int(SR * d)), burst, thud]
    for _ in range(24):
        t0 = rng.uniform(0.02, 0.7)
        parts.append(at(tink(rng.uniform(2200, 6000), rng.uniform(0.08, 0.2), rng.uniform(0.15, 0.5) * (1 - t0 * 0.9)), t0))
    return mix(*parts)


if __name__ == '__main__':
    only = set(sys.argv[1:])
    print('Sonidos del hielo:')
    for name, fn in (('ice_crack', crack), ('ice_break', shatter)):
        if only and name not in only: continue
        save(name, fn())
