#!/usr/bin/env python3
# tools/sounds/scorpion.py — sonidos del ESCORPIÓN del volcán y del ESCORPIÓN DE TRES COLAS (jefe secreto), con el tramo
# más fuerte de 100 ms a -12 dBFS (sin GAIN en Sound.lua). LOS CLICS son su firma: 3 archivos, uno por cola y de grave a
# agudo, para que el código los toque uno a uno a la vez que brilla cada aguijón (como una matraca):
#   enemies/scorpion/click1|2|3.wav   un diente de la matraca (la cola 1, 2, 3)
#   enemies/scorpion/sting.wav        un aguijón golpea: pinchazo seco
#   enemies/scorpion/snap.wav         la pinza se cierra
#   enemies/scorpion/skitter.wav      patitas sobre la roca
#   bosses/giantscorpion/strike.wav   las 3 colas entrelazadas se clavan: golpe grave y roca que salta
#   bosses/giantscorpion/pull.wav     arranca la cola del suelo: roca que raspa y sale
#   bosses/giantscorpion/hiss.wav     el rugido: siseo de caparazón que vibra
#
# Tres timbres de clic: A "quitina" (seco, caparazón) · B "matraca" (madera hueca, el diente salta y golpea; ELEGIDO para
# empezar: la palabra del usuario) · C "hueso" (más grave). Nadie los ha escuchado aún.
#   python3 tools/sounds/scorpion.py           → previas en FlappyMonster_pruebas/escorpion/sonidos/ (los 3 timbres)
#   python3 tools/sounds/scorpion.py --apply [--click A|B|C]   → assets/sounds/
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jungle_enemies as JE
from jungle_enemies import SR, t_, band, low, noise, env, place, thud, click

PREV = '/home/mtvemo/FlappyMonster_pruebas/escorpion/sonidos'
CLICK_F = (0.88, 1.0, 1.14)                # (cada cola, un poco más aguda que la anterior)


def res(f, d, tau):
    tt = t_(d)
    return np.sin(2 * np.pi * f * tt) * np.exp(-tt / tau)


def tooth(kind, p):
    """un diente: lo que distingue la matraca es el golpe en dos tiempos (salta y cae) y el cuerpo que resuena"""
    d = 0.07
    if kind == 'A':                        # quitina: chasquido agudo y seco
        return place(d, [(0, band(noise(0.012), 2500 * p, 9000) * env(0.012, 0.0003, 0.002)),
                         (0, res(2300 * p, 0.03, 0.004) * 0.6), (0, res(1150 * p, 0.04, 0.007) * 0.45)])
    if kind == 'B':                        # matraca: el diente salta (tic) y golpea la madera hueca (toc)
        return place(d, [(0, band(noise(0.006), 3000 * p, 8000) * env(0.006, 0.0002, 0.0012) * 0.5),
                         (0.006, band(noise(0.012), 1200 * p, 6000) * env(0.012, 0.0003, 0.0025)),
                         (0.006, res(720 * p, 0.06, 0.018) * 0.8), (0.006, res(1560 * p, 0.04, 0.008) * 0.45)])
    return place(d, [(0, band(noise(0.01), 900 * p, 4500) * env(0.01, 0.0003, 0.002)),    # hueso: grave
                     (0, res(430 * p, 0.06, 0.016)), (0, res(980 * p, 0.04, 0.007) * 0.5)])


def write(path, x):
    x = x - np.mean(x)
    n = int(SR * 0.1)
    # (los sonidos muy cortos no llegan a -12 dBFS sin recortar: se saturan suave, que además les da mordida)
    x = x / (np.abs(x).max() + 1e-12)
    drive = 1.0
    while drive < 12:
        y = np.tanh(x * drive) * 0.95
        rms = np.sqrt(max(np.mean(y[i:i + n] ** 2) for i in range(0, max(1, len(y) - n + 1), max(1, n // 4))) if len(y) > n else np.mean(y ** 2) * len(y) / n)
        if rms >= 10 ** (-12 / 20): break
        drive *= 1.1
    x = y * min(1.0, 10 ** (-12 / 20) / rms)
    k = int(SR * 0.002)
    x[-k:] *= np.linspace(1, 0, k)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print('  %s  %.2f s, pico %.2f' % (path, len(x) / SR, np.abs(x).max()))


def others():
    d = 0.3
    sting = place(0.22, [(0, band(noise(0.02), 2500, 9000) * env(0.02, 0.0003, 0.004)), (0, thud(900, 180, 0.14, 0.03) * 0.8),
                         (0.008, band(noise(0.12), 500, 3000) * env(0.12, 0.002, 0.03) * 0.4)])
    snap = place(0.2, [(0, click(2100, 0.03, 0.006)), (0.012, click(1300, 0.04, 0.008) * 0.9), (0.01, thud(420, 160, 0.1, 0.025) * 0.6)])
    grains = [(i * 0.035 + JE.rng.uniform(-0.006, 0.006), click(JE.rng.uniform(2600, 4200), 0.012, 0.003) * JE.rng.uniform(0.45, 1)) for i in range(8)]
    skitter = place(0.32, grains)
    rocks = [(0.03 + i * 0.05 + JE.rng.uniform(-0.015, 0.02), band(noise(0.05), 800, 5000) * env(0.05, 0.001, 0.012) * JE.rng.uniform(0.2, 0.5)) for i in range(9)]
    strike = place(0.7, [(0, thud(170, 42, 0.6, 0.16)), (0, click(1700, 0.04, 0.008) * 0.9),
                         (0.002, low(noise(0.4), 1500) * env(0.4, 0.002, 0.09) * 0.7)] + rocks)
    tt = t_(0.5)
    scrape = band(noise(0.5), 500, 3500) * np.minimum(1, tt / 0.3) * (0.65 + 0.35 * np.sin(2 * np.pi * 31 * tt)) * np.exp(-np.maximum(0, tt - 0.32) / 0.03)
    pull = place(0.62, [(0, scrape * 0.7), (0.33, thud(320, 90, 0.2, 0.05) * 0.9), (0.33, band(noise(0.1), 1500, 6000) * env(0.1, 0.001, 0.02) * 0.5)])
    tt = t_(0.9)
    trem = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 26 * tt))                       # (el caparazón vibra)
    hiss = band(noise(0.9), 1300, 8000) * np.minimum(1, tt / 0.12) * np.minimum(1, (0.9 - tt) / 0.25) * trem + \
        res(95, 0.9, 0.5) * np.minimum(1, tt / 0.1) * 0.5
    return {'enemies/scorpion/sting.wav': sting, 'enemies/scorpion/snap.wav': snap, 'enemies/scorpion/skitter.wav': skitter,
            'bosses/giantscorpion/strike.wav': strike, 'bosses/giantscorpion/pull.wav': pull, 'bosses/giantscorpion/hiss.wav': hiss}


if __name__ == '__main__':
    kind = sys.argv[sys.argv.index('--click') + 1] if '--click' in sys.argv else 'B'
    if '--apply' in sys.argv:
        for i, p in enumerate(CLICK_F):
            write(f'assets/sounds/enemies/scorpion/click{i + 1}.wav', tooth(kind, p))
        for rel, x in others().items():
            write('assets/sounds/' + rel, x)
    else:
        for k in 'ABC':
            for name, order in (('entrelazan', (0, 1, 2)), ('separan', (2, 1, 0))):
                write(f'{PREV}/tres_clics_{k}_{name}.wav', place(0.55, [(0.02 + j * 0.16, tooth(k, CLICK_F[o])) for j, o in enumerate(order)]))
