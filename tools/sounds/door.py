#!/usr/bin/env python3
# tools/sounds/door.py — los SONIDOS de la Puerta activable (types/mechanisms/door.lua, 2026-10-29). Síntesis sencilla
# (ruido filtrado, senos, envolventes), como tools/sounds/avalanche_cablecar.py. Cada sonido sale con su tramo más
# fuerte de 100 ms a ≈ −12 dBFS (lo que pide el arnés `sounds`), así no necesita entrada en Sound.GAIN.
#   doorClick  (mechanics/door_click.wav, 0,3 s) su Activador la suelta: el cerrojo salta (clac metálico + golpe sordo);
#              suena en la puerta Y en el Activador (quien lo pulsa, lejos, sabe que algo se abrió)
#   doorOpen   (mechanics/door_open.wav, 1,0 s) se abre: piedra / madera que roza al subir, con un retumbo grave
#   doorThud   (mechanics/door_thud.wav, 0,4 s) acaba de cerrarse: golpe pesado
#   python3 tools/sounds/door.py            → vistas previas en FlappyMonster_pruebas/puertas/sonidos/
#   python3 tools/sounds/door.py --apply    → además assets/sounds/…
# Se comprueban con números: NO se han escuchado.
import os, sys, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 22050
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'puertas', 'sonidos')
rng = np.random.default_rng(2910)


def n_(d): return int(SR * d)
def t_(d): return np.arange(n_(d)) / SR
def noise(d): return rng.uniform(-1, 1, n_(d))
def band(x, lo, hi): return sosfilt(butter(2, [lo, hi], btype='band', fs=SR, output='sos'), x)
def low(x, f): return sosfilt(butter(2, f, btype='low', fs=SR, output='sos'), x)
def env(n, a=0.005, d=0.1):
    t = np.arange(n) / SR
    return np.clip(t / max(a, 1e-6), 0, 1) * np.exp(-t / d)
def sweep(f0, f1, d):
    f = np.geomspace(f0, f1, n_(d))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)
def pad(x, n): return np.concatenate([x, np.zeros(max(0, n - len(x)))])
def mix(*ps):
    n = max(len(p) for p in ps)
    return sum(pad(p, n) for p in ps)
def at(x, d): return np.concatenate([np.zeros(n_(d)), x])
def fades(x, a=0.03, b=0.06):
    ka, kb = min(len(x), n_(a)), min(len(x), n_(b))
    x[:ka] *= np.linspace(0, 1, ka); x[-kb:] *= np.linspace(1, 0, kb)
    return x


def loudest_db(x):
    win = n_(0.1)
    sq = np.convolve(x * x, np.ones(win) / win, mode='valid') if len(x) > win else [np.mean(x * x)]
    return 10 * np.log10(np.max(sq) + 1e-12)


def save(path, x, target=-12.0):
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(x * 1.6) / np.tanh(1.6)
    x = x * 10 ** ((target - loudest_db(x)) / 20)
    x = np.clip(x, -0.99, 0.99)
    k = min(len(x), n_(0.004)); x[-k:] *= np.linspace(1, 0, k)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'  {os.path.relpath(path, ROOT) if path.startswith(ROOT) else path:52s} {len(x) / SR:.2f} s  {loudest_db(x):.1f} dBFS')


def door_click():
    """El cerrojo salta (0,3 s): un clac metálico seco y, justo detrás, un golpe sordo de algo pesado que se suelta"""
    d = 0.3
    clack = (band(noise(0.05), 1800, 5200) + np.sin(2 * np.pi * 2300 * t_(0.05)) * 0.5) * env(n_(0.05), 0.0005, 0.01)
    ring = sum(np.sin(2 * np.pi * f * t_(0.2)) * g for f, g in ((880, 1), (1460, 0.4))) * env(n_(0.2), 0.001, 0.05) * 0.35
    thunk = sweep(120, 60, 0.2) * env(n_(0.2), 0.002, 0.06) * 1.2
    return fades(mix(clack, ring, at(thunk, 0.06), np.zeros(n_(d))), 0.001, 0.04)


def door_open():
    """Se abre (1,0 s): roce áspero (ruido medio con temblor) que sube un poco de tono, y un retumbo grave debajo"""
    d = 1.0
    t = t_(d)
    grind = band(noise(d), 260, 1400) * (0.7 + 0.3 * np.sin(2 * np.pi * 11 * t)) * (0.6 + 0.4 * np.sin(np.pi * t / d))
    scrape = band(noise(d), 1500, 3800) * 0.18 * (0.5 + 0.5 * np.sin(2 * np.pi * 5 * t + 0.7) ** 2)
    rumble = low(noise(d), 90) * 3.0 * np.sin(np.pi * t / d) ** 0.5
    return fades(mix(grind, scrape, rumble), 0.06, 0.18)


def door_thud():
    """Se cierra (0,4 s): golpe pesado (bajada grave) con polvo (ruido corto)"""
    d = 0.4
    boom = sweep(110, 45, 0.35) * env(n_(0.35), 0.001, 0.09) * 1.4
    dust = band(noise(0.15), 300, 2200) * env(n_(0.15), 0.001, 0.04) * 0.5
    return fades(mix(boom, dust, np.zeros(n_(d))), 0.001, 0.08)


SOUNDS = {'mechanics/door_click': door_click, 'mechanics/door_open': door_open, 'mechanics/door_thud': door_thud}

if __name__ == '__main__':
    apply = '--apply' in sys.argv
    for name, fn in SOUNDS.items():
        x = fn()
        save(os.path.join(PRUEBAS, os.path.basename(name) + '.wav'), x.copy())
        if apply: save(os.path.join(ROOT, 'assets', 'sounds', name + '.wav'), x.copy())
