#!/usr/bin/env python3
# tools/sounds/gloomy.py
# Sonidos de la LINTERNA y del CRABBY LÚGUBRE (assets/sounds/gloomy/*.wav), todos con el tramo
# más fuerte de 100 ms a -12 dBFS (GAIN 1 en Sound.lua):
#   light_on     clic de interruptor que sube       light_off   clic que baja
#   light_out    se agota: zumbido que cae y chasquido   light_dead  no enciende: doble clic sordo
#   tick         una pata en la roca (tic seco y agudo: se oye cerca aunque no se le vea)
#   alert        ha oído algo: tres chasquidos que suben (el jugador sabe que viene)
#   wind         va a saltar: siseo que sube (el aviso del salto)
#   leap         salta: silbido corto
#   scared       le da la luz: chillido agudo que cae
#   lost         pierde el rastro: dos notas que bajan
# Desde la raíz del repo:  python3 tools/sounds/gloomy.py
import os, wave
import numpy as np

SR = 44100
OUT = 'assets/sounds/gloomy'
rng = np.random.default_rng(1977)


def t_(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.003, r=0.05):
    e = np.ones(n)
    na, nr = max(1, int(SR * a)), max(1, int(SR * r))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return e
def decay(d, tau): return np.exp(-t_(d) / tau)
def tone(f0, f1, d, harm=(1, 0.3, 0.1)):
    tt = t_(d)
    ph = np.cumsum(f0 + (f1 - f0) * tt / d) / SR
    return sum(h * np.sin(2 * np.pi * (i + 1) * ph) for i, h in enumerate(harm))
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def bp(x, lo, hi):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))
def at(parts, d):
    y = np.zeros(int(SR * d))
    for t0, x in parts:
        i = int(SR * t0); n = min(len(x), len(y) - i)
        y[i:i + n] += x[:n]
    return y
def click(f, d=0.03, tau=0.006): return (tone(f, f * 0.6, d) + 0.6 * bp(noise(d), 1500, 9000)) * decay(d, tau)


def save(name, x):
    x = x - np.mean(x)
    n = int(SR * 0.1)
    best = max(np.mean(x[i:i + n] ** 2) for i in range(0, max(1, len(x) - n + 1), max(1, n // 4))) if len(x) > n else np.mean(x ** 2) * len(x) / n
    x = x * (10 ** (-12 / 20) / np.sqrt(best + 1e-12))
    x = np.clip(x, -0.98, 0.98)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print('%-11s %.2f s' % (name, len(x) / SR))


SOUNDS = {
    'light_on':   lambda: at([(0, click(1800)), (0.035, click(2600, 0.05, 0.012))], 0.11),
    'light_off':  lambda: at([(0, click(2200)), (0.035, click(1300, 0.05, 0.012))], 0.11),
    'light_out':  lambda: at([(0, tone(900, 140, 0.32, (1, 0.5, 0.3, 0.2)) * env(int(SR * 0.32), 0.005, 0.12) * (1 + 0.5 * np.sin(2 * np.pi * 38 * t_(0.32)))),
                              (0.3, click(700, 0.06, 0.015))], 0.4),
    'light_dead': lambda: at([(0, click(500, 0.04, 0.008)), (0.07, click(420, 0.04, 0.008))], 0.14),
    'tick':       lambda: (tone(3400, 2600, 0.03, (1, 0.4)) + bp(noise(0.03), 2500, 9000)) * decay(0.03, 0.005),
    'alert':      lambda: at([(i * 0.07, (tone(1500 + i * 500, 1900 + i * 500, 0.05, (1, 0.5, 0.25)) + 0.4 * bp(noise(0.05), 2000, 8000)) * decay(0.05, 0.014))
                              for i in range(3)], 0.26),
    'wind':       lambda: (bp(noise(0.42), 2200, 9000) * (0.4 + 0.6 * t_(0.42) / 0.42) + 0.35 * tone(700, 1700, 0.42, (1, 0.6, 0.3))
                           * (1 + 0.6 * np.sin(2 * np.pi * 31 * t_(0.42)))) * env(int(SR * 0.42), 0.04, 0.03),
    'leap':       lambda: (bp(noise(0.2), 900, 6000) * 0.8 + 0.5 * tone(1300, 500, 0.2)) * env(int(SR * 0.2), 0.004, 0.14),
    'scared':     lambda: tone(3000, 1200, 0.2, (1, 0.5, 0.3)) * (1 + 0.5 * np.sin(2 * np.pi * 46 * t_(0.2))) * env(int(SR * 0.2), 0.004, 0.09),
    'lost':       lambda: at([(0, tone(1200, 1000, 0.1, (1, 0.4)) * env(int(SR * 0.1), 0.006, 0.05)),
                              (0.13, tone(820, 640, 0.16, (1, 0.4)) * env(int(SR * 0.16), 0.006, 0.09))], 0.32),
}

if __name__ == '__main__':
    for n, f in SOUNDS.items():
        save(n, f())
