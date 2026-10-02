#!/usr/bin/env python3
# tools/sounds/ambience.py
# Sonidos de AMBIENTE de las cuevas (assets/sounds/ambience/*.wav):
#   drip_fall    la gota se suelta de la estalactita: un "plic" agudo y cortísimo
#   drip_splash  la gota llega al suelo: el "plop" del agua (tono que sube de golpe + salpicadura)
#   cave_drip    una gota LEJANA, con su propia cola de cueva (ambiente: suena sola de vez en cuando)
#   cave_rumble  un rumor grave y lejano de la roca (ambiente, muy de fondo)
#   cave_pebble  una piedrecita que rueda en algún sitio
# Ejecutar desde la raíz del repo:  python3 tools/sounds/ambience.py [nombres...]
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, pad   # noqa: E402

OUT = 'assets/sounds/ambience'
rng = np.random.default_rng(77)


def save(name, x, peak=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = min(len(x), int(SR * 0.01))
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'  {OUT}/{name}.wav  {len(x) / SR:.2f} s')


def chirp(f0, f1, d, tau):
    """Seno cuyo tono va de f0 a f1 (exponencial, constante tau) y se apaga"""
    tt = t_(d)
    f = f1 + (f0 - f1) * np.exp(-tt / tau)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def echo(x, delay, fb, n, dark=2400):
    out = pad(x, len(x) + int(SR * delay * n) + int(SR * 0.1))
    tap = x
    for k in range(1, n + 1):
        tap = lowpass(tap, dark) * fb
        i = int(SR * delay * k)
        out[i:i + len(tap)] += tap
    return out


def fall():
    d = 0.07
    return chirp(2600, 1900, d, 0.02) * env(int(SR * d), 0.0008, 0.014)


def splash():
    # el "plop": una burbuja resuena y su tono SUBE mientras se cierra + una salpicadura breve
    d = 0.2
    body = chirp(520, 1500, d, 0.05) * env(int(SR * d), 0.002, 0.035)
    spl = highpass(noise(0.03), 3000) * env(int(SR * 0.03), 0.0005, 0.008) * 0.25
    return body + pad(spl, len(body))


def far_drip():
    x = lowpass(splash(), 2600)
    return echo(x, 0.19, 0.5, 5, 1900)


def rumble():
    d = 3.2
    n = lowpass(noise(d), 70)
    n = n / (np.max(np.abs(n)) + 1e-9)
    tt = t_(d)
    swell = np.sin(np.pi * tt / d) ** 2 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.9 * tt))
    return n * swell


def pebble():
    out = np.zeros(int(SR * 0.9))
    t0 = 0.0
    for k in range(5):
        d = 0.03
        tick = lowpass(highpass(noise(d), 900), 3800) * env(int(SR * d), 0.0005, 0.006) * (0.9 ** k) * rng.uniform(0.6, 1)
        i = int(SR * t0)
        out[i:i + len(tick)] += tick
        t0 += rng.uniform(0.05, 0.14) * (0.8 ** k) + 0.03
    return echo(out, 0.16, 0.4, 3, 1800)


ALL = {'drip_fall': fall, 'drip_splash': splash, 'cave_drip': far_drip, 'cave_rumble': rumble, 'cave_pebble': pebble}
if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name in (sys.argv[1:] or ALL):
        save(name, ALL[name]())
