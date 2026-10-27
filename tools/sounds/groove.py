#!/usr/bin/env python3
# tools/sounds/groove.py
# El PÚBLICO del escenario del Cangrejo Groove (assets/sounds/bosses/groove/*.wav; docs/bosses/groovecrab.md):
#   cheer = le VITOREAN a él (te dio un golpe o caíste): un "¡uuuh!" de muchas voces que sube, palmas y silbidos
#   boo   = le ABUCHEAN (le diste, o lo venciste): un "buuuh" grave de muchas voces que baja
# Voces = dientes de sierra desafinados entre sí con un formante de "u" (resonadores), vibrato y entradas a destiempo:
# una multitud, sin muestras de nadie. Ejecutar desde la raíz del repo:  python3 tools/sounds/groove.py [nombres...]
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, pad, mix, at, reson   # noqa: E402

OUT = 'assets/sounds/bosses/groove'
rng = np.random.default_rng(23)


def save(name, x, peak=0.9, drive=1.8):
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(x * drive) / np.tanh(drive)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = min(len(x), int(SR * 0.02))
    x[-fade:] *= np.linspace(1, 0, fade)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'  {OUT}/{name}.wav  {len(x) / SR:.2f} s')


def voice(d, f0, f1, vow=(320, 800), att=0.12, rel=0.5, vib=5.0):
    """Una voz: sierra que va de f0 a f1 Hz con vibrato, por un formante de vocal (dos resonadores)"""
    tt = t_(d)
    f = f0 + (f1 - f0) * np.clip(tt / d, 0, 1) ** 0.8
    f = f * (1 + 0.012 * np.sin(2 * np.pi * (vib + rng.uniform(-0.6, 0.6)) * tt + rng.uniform(0, 6)))
    ph = np.cumsum(f) / SR
    saw = 2 * (ph % 1) - 1
    y = reson(saw, vow[0], 6) * 1.0 + reson(saw, vow[1], 8) * 0.45
    e = np.clip(tt / att, 0, 1) * np.clip((d - tt) / rel, 0, 1)
    return y * e


def crowd(n, d, f0s, f1s, vow, spread=0.12, att=0.12, rel=0.5):
    parts = []
    for _ in range(n):
        f0 = rng.uniform(*f0s); k = rng.uniform(*f1s)
        dd = d * rng.uniform(0.75, 1.0)
        parts.append(at(voice(dd, f0, f0 * k, vow, att, rel) * rng.uniform(0.5, 1.0), rng.uniform(0, spread)))
    return mix(*parts)


def clap(g=1.0):
    x = highpass(noise(0.05), 900) * env(int(SR * 0.05), 0.0005, 0.012)
    return reson(x, rng.uniform(1100, 1800), 3) * g


# ¡Uuuh! — sube de tono y se abre (vocal "u" → "a"); palmas por encima y dos silbidos
def cheer():
    d = 1.4
    v = crowd(18, d, (210, 420), (1.25, 1.6), (420, 1100), spread=0.15, att=0.08, rel=0.6)
    claps = mix(*[at(clap(rng.uniform(0.3, 0.7)), rng.uniform(0.05, d - 0.1)) for _ in range(26)])
    w = []
    for s in (0.25, 0.7):
        tt = t_(0.35)
        f = 2200 + 900 * np.sin(np.pi * tt / 0.35)
        w.append(at(np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.02, 0.25) * 0.25, s))
    air = lowpass(noise(d), 2500) * np.clip(t_(d) / 0.1, 0, 1) * np.clip((d - t_(d)) / 0.6, 0, 1) * 0.15
    save('cheer', mix(v, claps * 0.8, *w, air))


# Buuuh — grave, baja despacio (vocal "u"), con un murmullo de aire
def boo():
    d = 1.6
    v = crowd(20, d, (120, 230), (0.72, 0.85), (300, 700), spread=0.2, att=0.18, rel=0.7)
    air = lowpass(noise(d), 900) * np.clip(t_(d) / 0.25, 0, 1) * np.clip((d - t_(d)) / 0.8, 0, 1) * 0.2
    save('boo', mix(v, air))


SOUNDS = {'cheer': cheer, 'boo': boo}
if __name__ == '__main__':
    for nm in (sys.argv[1:] or SOUNDS):
        SOUNDS[nm]()
