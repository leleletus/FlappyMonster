#!/usr/bin/env python3
# tools/sounds/bomb.py
# Sonidos de las bombas (assets/sounds/enemies/bomb_*.wav):
#   bomb_ignite  se enciende la mecha: "chisss" de cerilla + chispazo
#   bomb_fizz    la mecha chisporrotea (0,5 s: la bomba lo repite mientras arde)
#   bomb_blast   la explosión: golpe grave, estallido de ruido y cola de escombros
#   bomb_kick    patada / pisotón a la bomba (golpe hueco de metal)
# Ejecutar desde la raíz del repo:  python3 tools/sounds/bomb.py [nombres...]
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, pad, mix, at, reson, sweep   # noqa: E402

OUT = 'assets/sounds/enemies'
rng = np.random.default_rng(21)


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


def crackles(d, n, g):
    parts = [np.zeros(int(SR * d))]
    for _ in range(n):
        c = highpass(noise(0.004), 3000) * env(int(SR * 0.004), 0.0002, 0.0012) * rng.uniform(0.3, 1.0) * g
        parts.append(at(c, rng.uniform(0, d - 0.01)))
    return mix(*parts)


def ignite():
    d = 0.45
    strike = highpass(noise(0.06), 1800) * env(int(SR * 0.06), 0.001, 0.02) * 1.2
    whoosh = highpass(lowpass(noise(d), 6000), 1500) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 0.6 * 0.6
    return mix(strike, whoosh, crackles(d, 18, 0.7))


def fizz():
    d = 0.5
    tt = t_(d)
    hiss = highpass(lowpass(noise(d), 7000), 2500) * (0.7 + 0.3 * np.sin(2 * np.pi * 13 * tt)) * 0.5
    edge = np.clip(tt / 0.02, 0, 1) * np.clip((d - tt) / 0.02, 0, 1)      # (se puede encadenar)
    return mix(hiss * edge, crackles(d, 22, 0.8) * edge)


def blast():
    d = 1.3
    boom = sweep(90, 30, 0.9, 0.5) * env(int(SR * 0.9), 0.002, 0.25) * 1.4
    crack = lowpass(noise(0.5), 4000) * env(int(SR * 0.5), 0.0005, 0.08) * 1.6
    rumble = lowpass(noise(d), 220) * env(int(SR * d), 0.01, 0.45) * 1.2
    debris = [np.zeros(int(SR * d))]
    for _ in range(26):
        t0 = rng.uniform(0.08, 1.1)
        c = reson(pad(noise(0.003) * env(int(SR * 0.003), 0.0002, 0.001), int(SR * 0.06)), rng.uniform(900, 3200), 12)
        debris.append(at(c / (np.max(np.abs(c)) + 1e-9) * rng.uniform(0.1, 0.35) * (1.2 - t0), t0))
    return mix(boom, crack, rumble, mix(*debris))


def kick():
    d = 0.25
    body = reson(pad(noise(0.005) * env(int(SR * 0.005), 0.0003, 0.002), int(SR * d)), 520, 14)
    body2 = reson(pad(noise(0.005) * env(int(SR * 0.005), 0.0003, 0.002), int(SR * d)), 1180, 18)
    thump = sweep(160, 70, 0.12) * env(int(SR * 0.12), 0.002, 0.04)
    return mix(body / (np.max(np.abs(body)) + 1e-9), body2 / (np.max(np.abs(body2)) + 1e-9) * 0.5, thump * 0.8)


if __name__ == '__main__':
    only = set(sys.argv[1:])
    print('Sonidos de las bombas:')
    for name, fn in (('bomb_ignite', ignite), ('bomb_fizz', fizz), ('bomb_blast', blast), ('bomb_kick', kick)):
        if only and name not in only: continue
        save(name, fn(), drive=3.0 if name == 'bomb_blast' else 2.5)
