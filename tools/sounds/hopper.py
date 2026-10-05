#!/usr/bin/env python3
# tools/sounds/hopper.py — sonidos del SALTARÍN (assets/sounds/enemies/hopper/*.wav), con el tramo más fuerte de
# 100 ms a -12 dBFS (GAIN 1 en Sound.lua):
#   wind   se agacha: el muelle se aprieta (un chirrido corto que sube)
#   jump   salta: "boing" de muelle (tono que sube con vibrato rápido que se apaga)
#   land   cae: golpe sordo y el muelle que tiembla un instante
# Desde la raíz del repo:  python3 tools/sounds/hopper.py
import os, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(404)


def t_(d): return np.arange(int(SR * d)) / SR


def save(name, x):
    x = x - np.mean(x)
    n = int(SR * 0.1)
    best = max(np.mean(x[i:i + n] ** 2) for i in range(0, max(1, len(x) - n + 1), max(1, n // 4))) if len(x) > n else np.mean(x ** 2) * len(x) / n
    x = np.clip(x * (10 ** (-12 / 20) / np.sqrt(best + 1e-12)), -0.98, 0.98)
    k = int(SR * 0.004)
    x[:k] *= np.linspace(0, 1, k); x[-k:] *= np.linspace(1, 0, k)
    path = os.path.join('assets/sounds/enemies/hopper', name + '.wav')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print('  %s  %.2f s' % (path, len(x) / SR))


def spring(f0, f1, d, wob, wob_hz, tau):
    """Tono de muelle: de f0 a f1, con un vibrato (wob semitonos, wob_hz) que se apaga"""
    tt = t_(d)
    f = f0 * (f1 / f0) ** (tt / d)
    f = f * 2 ** (wob / 12 * np.sin(2 * np.pi * wob_hz * tt) * np.exp(-tt / (d * 0.5)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)) * np.exp(-tt / tau)


if __name__ == '__main__':
    d = 0.22
    tt = t_(d)
    save('wind', spring(190, 420, d, 0.6, 38, 0.3) * np.minimum(1, tt / 0.03) * (0.4 + 0.6 * tt / d))
    save('jump', spring(260, 760, 0.3, 2.2, 26, 0.13))
    thud = np.sin(2 * np.pi * np.cumsum(150 * np.exp(-t_(0.12) / 0.03) + 55) / SR) * np.exp(-t_(0.12) / 0.035)
    tail = spring(330, 240, 0.2, 1.6, 30, 0.06) * 0.45
    y = np.zeros(int(SR * 0.24)); y[:len(thud)] += thud; y[int(SR * 0.02):int(SR * 0.02) + len(tail)] += tail
    save('land', y)
