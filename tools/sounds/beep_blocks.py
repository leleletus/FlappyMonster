#!/usr/bin/env python3
# tools/sounds/beep_blocks.py
# Los sonidos de los BLOQUES BEEP de cristal (docs/design/beep-blocks.md; src/world/systems/BeatClock.lua):
#   beep_warn.wav    el BEEP de aviso (pulsos 6, 7 y 8 de cada frase de 4 s): seno casi puro a 2290 Hz, 70 ms, ataque
#                    instantáneo y caída corta — el MISMO beep que lleva la música de la Vía Estelar
#                    (tools/music/bloques_beep.py: BEEP_HZ / BEEP_MS), que se instala SIN él: lo toca el reloj
#   beep_switch.wav  el CAMBIO de bloque (pulso 1): un «clin» corto de cristal, por encima del golpe de la música
# Ejecutar desde la raíz del repo:  python3 tools/sounds/beep_blocks.py
import os, wave
import numpy as np

SR = 44100
OUT = 'assets/sounds/mechanics'
BEEP_HZ, BEEP_MS = 2290.0, 70


def save(path, x, peak=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print('escrito', path)


def beep():
    n = int(SR * BEEP_MS / 1000)
    t = np.arange(n) / SR
    att = np.clip(t / 0.001, 0, 1)                              # 1 ms
    rel = np.clip((n - np.arange(n)) / (SR * 0.012), 0, 1)       # caída de 12 ms al final (sin clic)
    body = np.exp(-t / 0.09)
    return np.sin(2 * np.pi * BEEP_HZ * t) * att * rel * body


def clink():
    d = 0.32
    t = np.arange(int(SR * d)) / SR
    x = np.zeros_like(t)
    for f, a, dec in ((2093.0, 1.0, 0.09), (3136.0, 0.55, 0.07), (4699.0, 0.35, 0.05), (6272.0, 0.2, 0.035)):
        x += a * np.sin(2 * np.pi * f * t) * np.exp(-t / dec)   # parciales de cristal (Do, Sol, Re, Sol agudos)
    rng = np.random.default_rng(7)
    tick = rng.standard_normal(len(t)) * np.exp(-t / 0.004) * 0.5    # el toque
    x = x + tick
    x *= np.clip(t / 0.0008, 0, 1)
    return x


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    save(os.path.join(OUT, 'beep_warn.wav'), beep())
    save(os.path.join(OUT, 'beep_switch.wav'), clink(), peak=0.7)
