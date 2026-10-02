#!/usr/bin/env python3
# tools/sounds/bomb.py
# Sonidos de las bombas (assets/sounds/enemies/bomb/*.wav):
#   bomb_ignite  se enciende la mecha: "chisss" de cerilla + chispazo
#   bomb_fizz    la mecha chisporrotea (0,5 s: la bomba lo repite mientras arde)
#   bomb_blast   la explosión: golpe grave, estallido de ruido y cola de escombros
#   bomb_kick    patada / pisotón a la bomba (golpe hueco de metal)
# Ejecutar desde la raíz del repo:  python3 tools/sounds/bomb.py [nombres...]
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, pad, mix, at, reson, sweep   # noqa: E402

OUT = 'assets/sounds/enemies/bomb'
rng = np.random.default_rng(21)


def save(name, x, peak=0.95, drive=2.5):
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(x * drive) / np.tanh(drive)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    name = name.replace('bomb_', '')                    # (archivo: enemies/bomb/ignite.wav...)
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
    # Explosión con POTENCIA: sub grave largo, chasquido saturado, rugido de
    # banda media saturado, retumbar que rueda 2 s y escombros cayendo
    d = 2.2
    tt = t_(d)
    sub = sweep(55, 22, 1.6, 0.45) * env(int(SR * 1.6), 0.002, 0.55) * 2.0
    thump = sweep(140, 45, 0.25, 0.6) * env(int(SR * 0.25), 0.001, 0.06) * 1.6
    crack = np.tanh(highpass(noise(0.12), 900) * env(int(SR * 0.12), 0.0003, 0.025) * 6) * 0.9
    roar_n = lowpass(noise(1.0), 1500)
    roar = np.tanh(roar_n / (np.max(np.abs(roar_n)) + 1e-9) * 4) * env(int(SR * 1.0), 0.004, 0.22) * 1.3
    rumble = lowpass(noise(d), 160) * np.exp(-tt / 0.9) * np.clip(tt / 0.05, 0, 1) * 2.2
    debris = [np.zeros(int(SR * d))]
    for _ in range(40):
        t0 = rng.uniform(0.15, 1.8)
        c = reson(pad(noise(0.003) * env(int(SR * 0.003), 0.0002, 0.001), int(SR * 0.06)), rng.uniform(700, 2800), 10)
        debris.append(at(c / (np.max(np.abs(c)) + 1e-9) * rng.uniform(0.08, 0.3) * (2.0 - t0) / 2, t0))
    return mix(sub, thump, crack, roar, rumble, mix(*debris))


def kick():
    # Patada METÁLICA: golpe seco + campana de chapa (modos inarmónicos con
    # poco amortiguamiento) + un eco corto del casco
    d = 0.6
    hit = pad(noise(0.004) * env(int(SR * 0.004), 0.0002, 0.0015), int(SR * d))
    modes = ((820, 60, 1.0), (1370, 70, 0.7), (2230, 80, 0.55), (3510, 90, 0.35), (5020, 100, 0.2))
    ring = sum(reson(hit, f, q) * g for f, q, g in modes)
    ring = ring / (np.max(np.abs(ring)) + 1e-9)
    clank = highpass(noise(0.03), 2500) * env(int(SR * 0.03), 0.0003, 0.008) * 0.8
    thump = sweep(180, 80, 0.1) * env(int(SR * 0.1), 0.001, 0.03) * 0.7
    return mix(ring, clank, thump, at(ring[:int(SR * 0.3)] * 0.18, 0.07))


if __name__ == '__main__':
    only = set(sys.argv[1:])
    print('Sonidos de las bombas:')
    for name, fn in (('bomb_ignite', ignite), ('bomb_fizz', fizz), ('bomb_blast', blast), ('bomb_kick', kick)):
        if only and name not in only: continue
        save(name, fn(), drive=4.5 if name == 'bomb_blast' else 2.5)
