#!/usr/bin/env python3
# tools/sounds/gloomy.py
# Sonidos de la LINTERNA y del CRABBY LÚGUBRE (assets/sounds/player/light_*.wav, assets/sounds/enemies/gloomy/*.wav), todos con el tramo
# más fuerte de 100 ms a -12 dBFS (GAIN 1 en Sound.lua):
#   light_on     clic de interruptor que sube       light_off   clic que baja
#   light_out    se agota: zumbido que cae y chasquido   light_dead  no enciende: doble clic sordo
#   wind         va a saltar: castañeteo seco y grave que se acelera (como un insecto de cueva; el
#                siseo con tono de antes no pegaba con el bicho)
#   leap         salta: silbido corto
# (Solo esos dos del Crabby lúgubre: el usuario lo encontró ruidoso. Oír algo, buscar y perder el rastro
#  son ICONOS sobre él — assets/images/gloomy/icons-Sheet.png —, no sonidos: el silencio es la tensión.)
# … y los del jefe, el Mega Crabby lúgubre (más abajo: MEGA → assets/sounds/bosses/megagloomy/).
# Desde la raíz del repo:  python3 tools/sounds/gloomy.py
import os, wave
import numpy as np

SR = 44100
OUT = None
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
    # (la linterna es del jugador; lo del Crabby lúgubre, con los demás enemigos; lo del jefe, en su carpeta)
    if OUT is None:
        path = os.path.join('assets/sounds/player', name + '.wav') if name.startswith('light_') \
            else os.path.join('assets/sounds/enemies/gloomy', name + '.wav')
    else:
        os.makedirs(OUT, exist_ok=True)
        path = os.path.join(OUT, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print('%-11s %.2f s' % (name, len(x) / SR))


SOUNDS = {
    'light_on':   lambda: at([(0, click(1800)), (0.035, click(2600, 0.05, 0.012))], 0.11),
    'light_off':  lambda: at([(0, click(2200)), (0.035, click(1300, 0.05, 0.012))], 0.11),
    'light_out':  lambda: at([(0, tone(900, 140, 0.32, (1, 0.5, 0.3, 0.2)) * env(int(SR * 0.32), 0.005, 0.12) * (1 + 0.5 * np.sin(2 * np.pi * 38 * t_(0.32)))),
                              (0.3, click(700, 0.06, 0.015))], 0.4),
    'light_dead': lambda: at([(0, click(500, 0.04, 0.008)), (0.07, click(420, 0.04, 0.008))], 0.14),
    'wind':       lambda: at([(t0, (tone(520 + 30 * i, 300, 0.035, (1, 0.6, 0.35)) + 0.5 * bp(noise(0.035), 500, 3500)) * decay(0.035, 0.009)
                               * (0.45 + 0.07 * i))
                              for i, t0 in enumerate([0.0, 0.085, 0.16, 0.225, 0.28, 0.325, 0.36, 0.39, 0.415])], 0.46),
    'leap':       lambda: (bp(noise(0.2), 900, 6000) * 0.8 + 0.5 * tone(1300, 500, 0.2)) * env(int(SR * 0.2), 0.004, 0.14),
}

# ── Mega Crabby lúgubre (assets/sounds/bosses/megagloomy/) ───────────────────
#   ping      ecolocalización: chasquido + pío que sube (se oye de dónde viene)
#   listen    escucha antes de atacar: siseo grave que sube con gruñido (el aviso)
#   drop      se lanza: silbido grave
#   slam      cae: golpe sordo + crujido de roca
#   dazzled   deslumbrado: chillido largo que tiembla
#   shriek    grito que oscurece la arena: chirrido largo
#   hurt      golpe: crujido + chillido corto
#   step      pata gorda en la roca
#   roar      entrada: gruñido que sube y chasquidos
def growl(f0, f1, d, am=27):
    return tone(f0, f1, d, (1, 0.7, 0.5, 0.35, 0.2)) * (1 + 0.6 * np.sin(2 * np.pi * am * t_(d)))

MEGA = {
    'ping':    lambda: at([(0, click(2400, 0.03, 0.006)), (0.03, tone(1500, 2600, 0.16, (1, 0.3)) * env(int(SR * 0.16), 0.004, 0.11))], 0.22),
    'listen':  lambda: (0.7 * bp(noise(0.9), 600, 5000) * (0.3 + 0.7 * t_(0.9) / 0.9) + growl(70, 150, 0.9)) * env(int(SR * 0.9), 0.08, 0.04),
    'drop':    lambda: (bp(noise(0.34), 300, 3000) + 0.6 * tone(500, 160, 0.34)) * env(int(SR * 0.34), 0.01, 0.22),
    'slam':    lambda: at([(0, tone(95, 38, 0.5, (1, 0.5, 0.25)) * decay(0.5, 0.13) * 1.6),
                           (0, bp(noise(0.3), 200, 4000) * decay(0.3, 0.05)),
                           (0.06, bp(noise(0.25), 1500, 7000) * decay(0.25, 0.04) * 0.5)], 0.55),
    'dazzled': lambda: tone(2100, 1300, 0.55, (1, 0.6, 0.4, 0.2)) * (1 + 0.7 * np.sin(2 * np.pi * 34 * t_(0.55))) * env(int(SR * 0.55), 0.01, 0.2),
    'shriek':  lambda: (tone(900, 2400, 1.0, (1, 0.7, 0.5, 0.3)) * (1 + 0.8 * np.sin(2 * np.pi * 52 * t_(1.0))) + 0.4 * bp(noise(1.0), 2500, 9000))
                       * env(int(SR * 1.0), 0.05, 0.25),
    'hurt':    lambda: at([(0, bp(noise(0.12), 400, 5000) * decay(0.12, 0.03)), (0.03, tone(1700, 800, 0.22, (1, 0.5, 0.3)) * env(int(SR * 0.22), 0.004, 0.12))], 0.27),
    'step':    lambda: (tone(900, 500, 0.05, (1, 0.5)) + bp(noise(0.05), 700, 5000)) * decay(0.05, 0.01),
    'roar':    lambda: at([(0, growl(60, 170, 1.1, 21) * env(int(SR * 1.1), 0.15, 0.3)),
                           (0.75, click(1500, 0.04, 0.01)), (0.86, click(1900, 0.04, 0.01)), (0.97, click(2300, 0.05, 0.012))], 1.2),
}

if __name__ == '__main__':
    for n, f in SOUNDS.items():
        save(n, f())
    OUT = 'assets/sounds/bosses/megagloomy'
    for n, f in MEGA.items():
        save(n, f())
