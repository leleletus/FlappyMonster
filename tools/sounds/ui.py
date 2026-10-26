#!/usr/bin/env python3
# tools/sounds/ui.py
# Sonidos de INTERFAZ (assets/sounds/ui/*.wav). Todos quedan a ≈ -12 dBFS (su tramo más fuerte de 100 ms).
#   level_enter  entrar a un nivel desde el mapa del mundo: un barrido que baja mientras el iris se cierra
#                sobre el monstruo y una campanita que cae al cerrarse
#   count_tick   la cuenta atrás del principio de cada nivel (3, 2, 1): un "bip" de chip seco
#   count_go     ¡YA!: el mismo bip una octava más alto, más largo y con un acorde que sube
#   python3 tools/sounds/ui.py [nombres...]
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, mix, at   # noqa: E402
import story                                                           # noqa: E402

story.OUT = 'assets/sounds/ui'


def pulse(f, d, duty=0.25):                      # onda cuadrada de chip (pulso), con un poco de filtro
    tt = t_(d)
    ph = (f * tt) % 1.0
    return lowpass(np.where(ph < duty, 1.0, -1.0), 6000)


def level_enter():
    d = 0.75
    tt = t_(d)
    # barrido de 900 → 140 Hz (el círculo se cierra), triángulo suave, que se apaga al final
    f = 900 * (140 / 900) ** (tt / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tri = (2 / np.pi) * np.arcsin(np.sin(ph))
    body = tri * np.clip(tt / 0.02, 0, 1) * np.clip((d - tt) / 0.25, 0, 1) * 0.8
    air = lowpass(highpass(noise(d), 1200), 4000) * np.sin(np.pi * tt / d) ** 2 * 0.18
    # dos campanitas que caen (sol → do) al cerrarse
    return mix(body, air, story.tink(1568, 0.3, 0.55), at(story.tink(1047, 0.4, 0.7), 0.16),
               at(story.bellnote(523, 0.5, 0.6), 0.5))


def count_tick():
    d = 0.16
    return pulse(880, d, 0.25) * env(int(SR * d), 0.002, 0.06)


def count_go():
    d = 0.6
    parts = [pulse(1760, d, 0.25) * env(int(SR * d), 0.002, 0.22)]
    for i, f in enumerate((880, 1109, 1319)):             # la mayor que sube, rápido
        parts.append(at(pulse(f, 0.3, 0.125) * env(int(SR * 0.3), 0.002, 0.1) * 0.45, i * 0.04))
    return mix(*parts)


ALL = {'level_enter': level_enter, 'count_tick': count_tick, 'count_go': count_go}

if __name__ == '__main__':
    for name in (sys.argv[1:] or list(ALL)):
        story.save(name, np.asarray(ALL[name](), dtype=float))
