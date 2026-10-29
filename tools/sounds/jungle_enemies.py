#!/usr/bin/env python3
# tools/sounds/jungle_enemies.py — sonidos del TOPO, la PIRAÑA y la PLANTA CARNÍVORA (0.5.96), con el tramo más fuerte
# de 100 ms a -12 dBFS (sin GAIN en Sound.lua; el código baja los que van flojos con el volumen de Sound.play):
#   enemies/mole/dig.wav            el montículo avanza: tierra que se remueve (ruido grave a golpecitos)
#   enemies/mole/pop.wav            asoma del suelo: un "plop" de tierra que salta
#   enemies/mole/bite.wav           muerde: dos chasquidos de dientes pequeños, rápidos
#   enemies/piranha/bite.wav        la piraña muerde en el aire: un chasquido seco y agudo
#   enemies/carnivoreplant/rustle.wav  el aviso: las hojas tiemblan (siseo vegetal que crece)
#   enemies/carnivoreplant/snap.wav    se cierra de golpe: golpe húmedo y grave con un chasquido
#   enemies/carnivoreplant/crunch.wav  se come algo: crujidos de caparazón y masticar
# (el salto de la piraña usa los chapoteos de siempre: waterSplashOut / waterSplash). Nadie los ha escuchado aún.
# Desde la raíz del repo:  python3 tools/sounds/jungle_enemies.py
import os, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 44100
rng = np.random.default_rng(1029)


def t_(d): return np.arange(int(SR * d)) / SR


def save(rel, x):
    x = x - np.mean(x)
    n = int(SR * 0.1)
    if len(x) > n:
        best = max(np.mean(x[i:i + n] ** 2) for i in range(0, len(x) - n + 1, max(1, n // 4)))
    else:
        best = np.mean(x ** 2) * len(x) / n
    x = np.clip(x * (10 ** (-12 / 20) / np.sqrt(best + 1e-12)), -0.98, 0.98)
    k = int(SR * 0.004)
    x[:k] *= np.linspace(0, 1, k); x[-k:] *= np.linspace(1, 0, k)
    path = os.path.join('assets/sounds/enemies', rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print('  %s  %.2f s' % (path, len(x) / SR))


def band(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], btype='band')
    return lfilter(b, a, x)


def low(x, f):
    b, a = butter(2, f / (SR / 2))
    return lfilter(b, a, x)


def noise(d): return rng.standard_normal(int(SR * d))


def env(d, att, tau):
    tt = t_(d)
    return np.minimum(1, tt / max(att, 1e-4)) * np.exp(-tt / tau)


def place(total, parts):
    y = np.zeros(int(SR * total))
    for at, x in parts:
        i = int(SR * at)
        n = min(len(x), len(y) - i)
        y[i:i + n] += x[:n]
    return y


def click(f, d=0.025, tau=0.006):
    tt = t_(d)
    return (np.sin(2 * np.pi * f * tt) + 0.5 * band(noise(d), f * 0.7, min(f * 2.2, 18000))) * np.exp(-tt / tau)


def thud(f0, f1, d, tau):
    tt = t_(d)
    f = f1 + (f0 - f1) * np.exp(-tt / (d * 0.25))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / tau)


if __name__ == '__main__':
    # TOPO: escarbar = golpecitos de tierra (ruido grave filtrado) a ritmo irregular
    grains = [(0.02 + i * 0.045 + rng.uniform(-0.01, 0.01), band(noise(0.05), 120, 900) * env(0.05, 0.003, 0.014)
               * rng.uniform(0.6, 1.0)) for i in range(6)]
    save('mole/dig.wav', place(0.32, grains))
    # asoma: un "plop" (tono que baja) + tierra que salta
    save('mole/pop.wav', place(0.3, [(0, thud(420, 140, 0.16, 0.05)),
                                     (0.01, band(noise(0.22), 300, 2500) * env(0.22, 0.004, 0.05) * 0.5)]))
    # muerde: dos chasquidos de dientes
    save('mole/bite.wav', place(0.2, [(0, click(2600)), (0.07, click(3100) * 0.85)]))
    # PIRAÑA: chasquido seco y agudo (dos mandíbulas que chocan) con un golpe de cuerpo
    save('piranha/bite.wav', place(0.16, [(0, click(3800, 0.03, 0.005)), (0.004, thud(900, 300, 0.06, 0.015) * 0.6)]))
    # PLANTA: el aviso — siseo de hojas que crece y tiembla
    d = 0.4
    tt = t_(d)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * 24 * tt)
    save('carnivoreplant/rustle.wav', band(noise(d), 1500, 7000) * np.minimum(1, tt / 0.3) * trem * np.exp(-np.maximum(0, tt - 0.32) / 0.03))
    # se cierra: golpe húmedo grave + chasquido + un poco de aire
    save('carnivoreplant/snap.wav', place(0.35, [(0, thud(260, 70, 0.3, 0.08)), (0, click(1800, 0.04, 0.008) * 0.9),
                                                (0.005, low(noise(0.2), 900) * env(0.2, 0.002, 0.04) * 0.6)]))
    # se come algo: crujidos (clics agudos al azar) y tres mordiscos sordos
    cr = [(rng.uniform(0, 0.5), click(rng.uniform(2500, 5000), 0.02, 0.004) * rng.uniform(0.4, 0.9)) for _ in range(14)]
    ch = [(0.04 + i * 0.17, thud(200, 90, 0.12, 0.04) * 0.8) for i in range(3)]
    save('carnivoreplant/crunch.wav', place(0.6, cr + ch))
