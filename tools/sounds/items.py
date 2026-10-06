#!/usr/bin/env python3
# tools/sounds/items.py — sonidos de OBJETOS (assets/sounds/items/*.wav), con el tramo más fuerte de 100 ms a -12 dBFS:
#   apple   manzana que cura: un mordisco crujiente y dos notas que suben (un "ñam" alegre)
# Desde la raíz del repo:  python3 tools/sounds/items.py
import os, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(77)


def t_(d): return np.arange(int(SR * d)) / SR


def save(name, x):
    x = x - np.mean(x)
    n = int(SR * 0.1)
    best = max(np.mean(x[i:i + n] ** 2) for i in range(0, max(1, len(x) - n + 1), max(1, n // 4)))
    x = np.clip(x * (10 ** (-12 / 20) / np.sqrt(best + 1e-12)), -0.98, 0.98)
    k = int(SR * 0.004)
    x[:k] *= np.linspace(0, 1, k); x[-k:] *= np.linspace(1, 0, k)
    path = os.path.join('assets/sounds/items', name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print('  %s  %.2f s' % (path, len(x) / SR))


def pulse(f, d, duty=0.5):
    tt = t_(d)
    return np.where((tt * f) % 1 < duty, 1.0, -1.0) * np.exp(-tt / (d * 0.45))


if __name__ == '__main__':
    y = np.zeros(int(SR * 0.42))
    # el mordisco: ruido crujiente muy corto, a trocitos
    crunch = rng.standard_normal(int(SR * 0.07)) * np.exp(-t_(0.07) / 0.018) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 90 * t_(0.07))))
    y[:len(crunch)] += crunch * 0.8
    # … y dos notas que suben (quinta): mi5 → si5
    for i, f in enumerate((659.3, 987.8)):
        n = pulse(f, 0.16, 0.25) * 0.55
        a = int(SR * (0.06 + i * 0.11))
        y[a:a + len(n)] += n
    save('apple', y)
