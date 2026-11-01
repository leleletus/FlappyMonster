#!/usr/bin/env python3
# tools/sounds/plant_bites.py — los MORDISCOS de las plantas (el usuario: "un sonido más realista"), con el tramo más fuerte de
# 100 ms a -12 dBFS. Un mordisco de verdad no es un tono: dientes que chocan, algo que cruje a trozos muy seguidos, el golpe
# sordo de la mandíbula, el hueco de la boca y un resto húmedo.
#   enemies/carnivoreplant/bite.wav   plantBite: la planta chiquita y las Lanzas de la Reina
#   bosses/carnqueen/bite.wav         queenBite: la Reina; más grave, más larga y con un golpe que se siente
#   python3 tools/sounds/plant_bites.py           → previas en FlappyMonster_pruebas/reina/sonidos/
#   python3 tools/sounds/plant_bites.py --apply   → assets/sounds/
# Nadie los ha escuchado: comprobados solo por números.
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from jungle_enemies import SR, t_, band, low, noise, env, place, thud, click

PREV = '/home/mtvemo/FlappyMonster_pruebas/reina/sonidos'
rng = np.random.default_rng(1101)


def grains(n, span, lo, hi, dmin, dmax, curve=1.8):
    """lo que cruje: trocitos de ruido muy seguidos, cada vez más flojos y separados"""
    out = []
    for i in range(n):
        u = (i + rng.random() * 0.7) / n
        d = rng.uniform(dmin, dmax)
        f0 = rng.uniform(lo, hi * 0.6)
        g = band(noise(d), f0, min(hi, f0 * 2.4)) * env(d, 0.0004, d / 3)
        out.append((span * u ** curve, g * (1 - 0.75 * u) * rng.uniform(0.55, 1)))
    return out


def wet(d, f0, f1, level):
    """el resto húmedo: ruido con una banda que baja, por tramos"""
    n = 8
    parts = []
    for i in range(n):
        u = i / (n - 1)
        f = f0 + (f1 - f0) * u
        s = band(noise(d / n * 1.5), f * 0.6, f * 1.5) * np.hanning(int(SR * d / n * 1.5))
        parts.append((d / n * i, s * (1 - u) ** 1.4))
    return place(d * 1.3, parts) * level


def small():
    return place(0.34, [
        (0.000, click(2600, 0.012, 0.002) * 1.0), (0.004, click(3500, 0.010, 0.0016) * 0.8),   # los dientes
        (0.000, thud(210, 95, 0.12, 0.03) * 0.42),                                             # la mandíbula
        (0.002, band(noise(0.07), 380, 1200) * env(0.07, 0.001, 0.02) * 2.0),                # el hueco de la boca
        (0.070, wet(0.17, 1300, 450, 0.3)),
    ] + [(0.006 + at, g * 1.5) for at, g in grains(13, 0.10, 1400, 7000, 0.003, 0.009)])


def queen():
    return place(0.80, [
        (0.000, click(980, 0.04, 0.008) * 0.9), (0.009, click(1450, 0.03, 0.006) * 0.8), (0.018, click(720, 0.04, 0.009) * 0.6),
        (0.000, thud(120, 45, 0.40, 0.07) * 0.5),                                              # el golpe que se siente
        (0.004, band(noise(0.16), 180, 800) * env(0.16, 0.002, 0.05) * 2.2),
        (0.150, wet(0.42, 750, 220, 1.0)),
    ] + [(0.014 + at, g * 2.8) for at, g in grains(20, 0.30, 650, 4200, 0.006, 0.02)])


def out(path, x):
    x = x - np.mean(x)
    n = int(SR * 0.1)
    best = max(np.mean(x[i:i + n] ** 2) for i in range(0, max(1, len(x) - n + 1), n // 4))
    x = x * (10 ** (-12 / 20) / np.sqrt(best + 1e-12))
    x = x * min(1, 0.9 / np.max(np.abs(x)))                  # (sin recortar: el golpe es lo que da el mordisco)
    k = int(SR * 0.012)
    x[-k:] *= np.linspace(1, 0, k)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    spec = np.abs(np.fft.rfft(x)) ** 2
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    tot = spec.sum()
    print('  %-52s %.2f s  pico %.2f  <200 Hz %2.0f %%  200-2k %2.0f %%  >2k %2.0f %%' % (
        path, len(x) / SR, np.max(np.abs(x)), 100 * spec[fr < 200].sum() / tot,
        100 * spec[(fr >= 200) & (fr < 2000)].sum() / tot, 100 * spec[fr >= 2000].sum() / tot))


if __name__ == '__main__':
    apply_ = '--apply' in sys.argv
    a, b = small(), queen()
    out(os.path.join(PREV, 'plantBite.wav'), a)
    out(os.path.join(PREV, 'queenBite.wav'), b)
    if apply_:
        out('assets/sounds/enemies/carnivoreplant/bite.wav', a)
        out('assets/sounds/bosses/carnqueen/bite.wav', b)
