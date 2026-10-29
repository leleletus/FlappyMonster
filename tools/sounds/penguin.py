#!/usr/bin/env python3
# tools/sounds/penguin.py — sonidos del PINGÜINO (Costa Helada), con el tramo más fuerte de 100 ms a -12 dBFS como los
# demás (tools/sounds/jungle_enemies.py: save, band, low, noise, env, place):
#   enemies/penguin/squawk.wav   te ve y se tira: un graznido corto y nasal en dos golpes ("¡ah-ah!": tono zumbón que sube
#                                y baja, con armónicos de lengüeta)
#   enemies/penguin/slide.wav    se tira / echa a correr de barriga: un roce de barriga sobre nieve y hielo (ruido que
#                                sube y se aleja, con un siseo agudo de hielo)
# Nadie los ha escuchado aún. Desde la raíz del repo:  python3 tools/sounds/penguin.py
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from jungle_enemies import SR, t_, save, band, low, noise, env, place   # noqa


def honk(f0, f1, d):
    """Un golpe de graznido: zumbido de lengüeta (diente de sierra suave) que va de f0 a f1, filtrado nasal"""
    tt = t_(d)
    f = f0 + (f1 - f0) * np.sin(np.pi * tt / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(np.sin(k * ph) / k for k in range(1, 9))
    x = band(x, 500, 3200) + 0.3 * band(noise(d), 1200, 2600)
    return x * np.minimum(1, tt / 0.01) * np.exp(-np.maximum(0, tt - d * 0.6) / (d * 0.15))


if __name__ == '__main__':
    save('penguin/squawk.wav', place(0.34, [(0, honk(520, 700, 0.12)), (0.15, honk(560, 760, 0.17) * 0.9)]))
    d = 0.55
    tt = t_(d)
    shape = np.minimum(1, tt / 0.05) * np.exp(-tt / 0.22)
    rub = low(band(noise(d), 200, 2400), 1800) * shape
    hiss = band(noise(d), 5000, 11000) * shape * 0.35 * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * tt))
    save('penguin/slide.wav', rub + hiss)
