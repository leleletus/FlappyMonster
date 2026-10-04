#!/usr/bin/env python3
# tools/sounds/story.py
# Sonidos de la HISTORIA (assets/sounds/story/*.wav): las cinemáticas (src/story/films/) y los fragmentos
# del espejo en los niveles (src/story/Shards.lua). Todos quedan a ≈ -12 dBFS (su tramo más fuerte de 100 ms).
#   glint    el destello a lo lejos           crash    el espejo se rompe (golpe + cristales cayendo)
#   orb      el aleteo, hecho magia           blast    el Reflejo lo echa todo del cráter
#   shard    un fragmento cruza el aire       grow     un jefe crece (la furia del espejo)
#   clink    un fragmento encaja (se afina en el juego: una escala que sube)
#   restore  el espejo, entero                bell     la luz llega a una isla
#   shrink   un jefe vuelve a ser pequeño     wave     la onda de luz
#   shard_drop / shard_get   un jefe suelta su fragmento / el jugador lo recoge
#   python3 tools/sounds/story.py [nombres...]
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, pad, mix, at, sweep   # noqa: E402

OUT = 'assets/sounds/story'
rng = np.random.default_rng(23)
TARGET_DB = -12.0


def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(x * 1.8) / np.tanh(1.8)
    n = int(SR * 0.1)
    p = np.convolve(x * x, np.ones(n) / n, mode='valid') if len(x) > n else np.array([np.mean(x * x)])
    db = 10 * np.log10(np.max(p) + 1e-12)
    x = x * 10 ** ((TARGET_DB - db) / 20)
    pk = np.max(np.abs(x))
    if pk > 0.97: x = x * 0.97 / pk
    fade = min(len(x), int(SR * 0.006))
    x[-fade:] *= np.linspace(1, 0, fade)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print('  %s/%s.wav  %.2f s' % (OUT, name, len(x) / SR))


def tink(f, d=0.25, g=1.0):                      # campanita de cristal
    tt = t_(d)
    y = sum(np.sin(2 * np.pi * f * k * tt) * a for k, a in ((1, 1.0), (2.76, 0.5), (5.4, 0.25)))
    return y * env(len(tt), 0.0008, d / 4) * g


def bellnote(f, d=0.8, g=1.0):                   # campana suave (parciales casi armónicos)
    tt = t_(d)
    y = sum(np.sin(2 * np.pi * f * k * tt) * a * np.exp(-tt * k * 2.2) for k, a in ((1, 1.0), (2.0, 0.45), (3.01, 0.22), (4.2, 0.1)))
    return y * np.clip(tt / 0.003, 0, 1) * g


def glint():
    return mix(tink(2637, 0.3), at(tink(3520, 0.35, 0.8), 0.07), at(tink(4186, 0.3, 0.4), 0.14))


def crash():
    d = 1.5
    tt = t_(0.5)
    boom = np.sin(2 * np.pi * np.cumsum(np.linspace(110, 45, len(tt))) / SR) * np.exp(-tt / 0.16) * 1.3
    crack = highpass(noise(0.14), 2200) * env(int(SR * 0.14), 0.0005, 0.04) * 1.5
    parts = [np.zeros(int(SR * d)), boom, crack]
    for _ in range(26):
        t0 = rng.uniform(0.04, 1.0)
        parts.append(at(tink(rng.uniform(2400, 6800), 0.11, rng.uniform(0.2, 0.55) * (1.15 - t0)), t0))
    return mix(*parts)


def orb():
    d = 0.9
    parts = [np.zeros(int(SR * d))]
    for i, f in enumerate((523, 659, 784, 1047, 1319, 1568)):
        tt = t_(0.3)
        y = np.sin(2 * np.pi * (f + 6 * np.sin(2 * np.pi * 7 * tt)) * tt) * env(len(tt), 0.01, 0.12)
        parts.append(at(y * 0.6, i * 0.085))
    air = highpass(noise(d), 3500) * np.sin(np.pi * t_(d) / d) ** 2 * 0.18
    parts.append(air)
    return mix(*parts)


def blast():
    d = 1.1
    tt = t_(d)
    rise = lowpass(noise(d), 1400) * (tt / d) ** 2 * 0.9
    whine = sweep(180, 900, d) * (tt / d) ** 3 * 0.35
    tb = t_(0.4)
    boom = np.sin(2 * np.pi * np.cumsum(np.linspace(120, 40, len(tb))) / SR) * np.exp(-tb / 0.12) * 1.4
    return mix(rise, whine, at(boom, d - 0.12), at(highpass(noise(0.2), 1500) * env(int(SR * 0.2), 0.001, 0.06), d - 0.12))


def shard():
    w = lowpass(noise(0.22), 2600) * np.sin(np.pi * t_(0.22) / 0.22) ** 2 * 0.5
    return mix(w, at(tink(2093, 0.3, 0.9), 0.12), at(tink(3136, 0.22, 0.4), 0.16))


def grow():
    d = 0.75
    tt = t_(d)
    f = np.linspace(55, 170, len(tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.33 * np.sin(3 * ph)) * (0.6 + 0.4 * np.sin(2 * np.pi * 21 * tt))
    y = lowpass(saw, 900) * np.clip(tt / 0.05, 0, 1) * np.clip((d - tt) / 0.12, 0, 1)
    tb = t_(0.25)
    thump = np.sin(2 * np.pi * np.cumsum(np.linspace(140, 50, len(tb))) / SR) * np.exp(-tb / 0.07)
    return mix(y, at(thump * 0.9, d - 0.2))


def clink():
    return mix(tink(880, 0.5, 1.0), bellnote(880, 0.5, 0.6))


def restore():
    d = 1.7
    parts = [np.zeros(int(SR * d))]
    for i, f in enumerate((523, 659, 784, 1047, 1319, 1568, 2093)):
        parts.append(at(bellnote(f, 1.0, 0.7), i * 0.07))
        parts.append(at(tink(f * 2, 0.3, 0.22), i * 0.07))
    tt = t_(d)
    padc = sum(np.sin(2 * np.pi * f * tt) for f in (261.6, 329.6, 392, 523.2)) * np.sin(np.pi * tt / d) ** 1.5 * 0.2
    parts.append(padc)
    parts.append(highpass(noise(d), 4000) * np.exp(-tt / 0.5) * 0.2)
    return mix(*parts)


def bell():
    return bellnote(660, 0.9, 1.0)


def shrink():
    d = 0.42
    tt = t_(d)
    y = np.sin(2 * np.pi * np.cumsum(np.linspace(980, 300, len(tt))) / SR) * np.clip((d - tt) / 0.1, 0, 1) * np.clip(tt / 0.01, 0, 1)
    tp = t_(0.08)
    pop = np.sin(2 * np.pi * np.cumsum(np.linspace(500, 1500, len(tp))) / SR) * np.exp(-tp / 0.02)
    return mix(y * 0.8, at(pop, d - 0.02))


def wave_():
    d = 1.7
    tt = t_(d)
    w = lowpass(noise(d), 1100) * np.sin(np.pi * tt / d) ** 2
    sh = highpass(noise(d), 3800) * np.sin(np.pi * tt / d) ** 3 * 0.3
    return mix(w, sh, sweep(200, 520, d) * np.sin(np.pi * tt / d) ** 2 * 0.25)


def shard_drop():
    return mix(tink(1760, 0.3, 0.9), at(tink(2349, 0.3, 0.7), 0.09), at(tink(2794, 0.35, 0.6), 0.18),
               highpass(noise(0.3), 3500) * np.exp(-t_(0.3) / 0.1) * 0.2)


def shard_get():
    parts = [np.zeros(int(SR * 0.9))]
    for i, f in enumerate((784, 1047, 1319, 1568)):
        parts.append(at(bellnote(f, 0.6, 0.8), i * 0.09))
        parts.append(at(tink(f * 2, 0.25, 0.3), i * 0.09))
    return mix(*parts)


ALL = {'glint': glint, 'crash': crash, 'orb': orb, 'blast': blast, 'shard': shard, 'grow': grow, 'clink': clink,
       'restore': restore, 'bell': bell, 'shrink': shrink, 'wave': wave_, 'shard_drop': shard_drop, 'shard_get': shard_get}

if __name__ == '__main__':
    for name in (sys.argv[1:] or list(ALL)):
        save(name, np.asarray(ALL[name](), dtype=float))
