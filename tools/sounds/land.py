#!/usr/bin/env python3
# tools/sounds/land.py — el GOLPE de una caída fuerte del monstruo (`landHard`, assets/sounds/player/land_hard.wav).
# Golpe sordo: un grave que baja, un chasquido de tierra y un poco de polvo. El juego varía tono y volumen según la altura
# de la caída (PlayerAdventure, LAND_HARD_VY). Tramo fuerte de 100 ms a ≈ −12 dBFS.
#   python3 tools/sounds/land.py            → vista previa en FlappyMonster_pruebas/caida/
#   python3 tools/sounds/land.py --apply    → además assets/sounds/player/land_hard.wav
# Se comprueba con números: NO se ha escuchado.
import os, sys, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 22050
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'caida')
rng = np.random.default_rng(1110)


def loudest_db(x):
    k = int(SR * 0.1)
    rms = np.sqrt(np.convolve(x * x, np.ones(k) / k, mode='valid'))
    return 20 * np.log10(max(rms.max(), 1e-9))


def save(path, x, target=-12.0):
    x = x * 10 ** ((target - loudest_db(x)) / 20)
    x = np.clip(x, -1, 1)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(path, 'pico %.2f' % np.abs(x).max(), 'fuerte %.1f dB' % loudest_db(x))


def land_hard():
    d = 0.32
    n = int(SR * d)
    t = np.arange(n) / SR
    f = 42 + 96 * np.exp(-t / 0.035)                       # el grave cae deprisa
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.075)
    noise = rng.uniform(-1, 1, n)
    crack = sosfilt(butter(2, [500, 2600], btype='band', fs=SR, output='sos'), noise) * np.exp(-t / 0.018)
    dust = sosfilt(butter(2, 900, btype='low', fs=SR, output='sos'), noise) * np.exp(-t / 0.09) * 0.25
    x = thump + crack * 0.7 + dust
    x[:int(SR * 0.001)] *= np.linspace(0, 1, int(SR * 0.001))
    k = int(SR * 0.04)
    x[-k:] *= np.linspace(1, 0, k)
    return x


if __name__ == '__main__':
    x = land_hard()
    save(os.path.join(PRUEBAS, 'land_hard.wav'), x)
    if '--apply' in sys.argv[1:]:
        save(os.path.join(ROOT, 'assets', 'sounds', 'player', 'land_hard.wav'), x)
