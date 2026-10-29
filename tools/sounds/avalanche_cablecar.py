#!/usr/bin/env python3
# tools/sounds/avalanche_cablecar.py — los SONIDOS del Alud y del Teleférico (Montañas Heladas, 2026-10-29). Síntesis
# sencilla (ruido filtrado, senos, envolventes), como tools/sounds/props.py. Cada sonido sale con su tramo más fuerte de
# 100 ms a ≈ −12 dBFS (lo que pide el arnés `sounds`), así no necesita entrada en Sound.GAIN.
#   avalancheRumble  (traps/avalanche_rumble.wav, 1,2 s) el AVISO: retumbo grave que crece y la cornisa que cruje
#   avalanchePour    (traps/avalanche_pour.wav, 1,3 s; se repite mientras cae) el TORRENTE: soplido pesado de nieve
#                    con un retumbo debajo
#   cablecarMove     (mechanics/cablecar_move.wav, 0,6 s; se repite mientras se mueve) el cable zumba y las ruedas del
#                    carro pasan por los empalmes (clac-clac)
#   cablecarStop     (mechanics/cablecar_stop.wav, 0,35 s) llega a una estación o arranca: golpe metálico y un chirrido
#   python3 tools/sounds/avalanche_cablecar.py            → vistas previas en FlappyMonster_pruebas/mecanicas_heladas/sonidos/
#   python3 tools/sounds/avalanche_cablecar.py --apply    → además assets/sounds/…
# Se comprueban con números: NO se han escuchado.
import os, sys, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 22050
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'mecanicas_heladas', 'sonidos')
rng = np.random.default_rng(1029)


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
    x = np.tanh(x * 1.6) / np.tanh(1.6)                     # (un poco de compresión: más cuerpo a igual pico)
    x = x * 10 ** ((target - loudest_db(x)) / 20)
    x = np.clip(x, -0.99, 0.99)
    k = min(len(x), n_(0.004)); x[-k:] *= np.linspace(1, 0, k)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'  {os.path.relpath(path, ROOT) if path.startswith(ROOT) else path:52s} {len(x) / SR:.2f} s  {loudest_db(x):.1f} dBFS')


# ── EL ALUD ──
def crack(f=3000, d=0.04):
    return band(noise(d), f * 0.6, min(f * 1.6, 10000)) * env(n_(d), 0.0005, d / 5)


def avalanche_rumble():
    """El aviso (1,2 s): retumbo grave que crece, con crujidos de la cornisa cada vez más seguidos"""
    d = 1.2
    rum = low(noise(d), 110) * np.linspace(0.2, 1.0, n_(d)) ** 1.5 * 5
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * 7 * t_(d))
    parts = [rum * trem]
    t0, gap = 0.12, 0.22
    while t0 < d - 0.06:
        parts.append(at(crack(rng.uniform(1800, 3600)) * rng.uniform(0.25, 0.5), t0))
        t0 += gap; gap *= 0.8
    return fades(mix(*parts), 0.02, 0.08)


def avalanche_pour():
    """El torrente (1,3 s, se repite): soplido pesado de nieve (ruido grave-medio con remolinos) y retumbo"""
    d = 1.3
    whoosh = band(noise(d), 180, 1600) * (0.75 + 0.25 * np.sin(2 * np.pi * 2.3 * t_(d) + 1.0))
    hiss = band(noise(d), 2000, 6000) * 0.25
    rum = low(noise(d), 90) * 3.5
    return fades(mix(whoosh, hiss, rum), 0.08, 0.12)


# ── EL TELEFÉRICO ──
def clack(f=900, d=0.05):
    return (band(noise(d), f * 0.7, f * 1.8) + np.sin(2 * np.pi * f * 1.9 * t_(d)) * 0.4) * env(n_(d), 0.0005, 0.012)


def cablecar_move():
    """Moviéndose (0,6 s, se repite): el cable zumba y las ruedas pasan dos empalmes (clac-clac)"""
    d = 0.6
    hum = (np.sin(2 * np.pi * 96 * t_(d)) + 0.5 * np.sin(2 * np.pi * 192 * t_(d))) * 0.35
    hum = hum * (0.8 + 0.2 * np.sin(2 * np.pi * 3 * t_(d)))
    hiss = band(noise(d), 1200, 3800) * 0.12
    parts = [hum, hiss, at(clack(900) * 0.9, 0.05), at(clack(1050) * 0.7, 0.13),
             at(clack(900) * 0.9, 0.35), at(clack(1050) * 0.7, 0.43)]
    return fades(mix(*parts), 0.03, 0.03)


def cablecar_stop():
    """Llega a una estación / arranca (0,35 s): golpe metálico grave y un chirrido corto"""
    d = 0.35
    thud = sweep(150, 70, 0.18) * env(n_(0.18), 0.001, 0.06)
    clang = sum(np.sin(2 * np.pi * f * t_(d)) * g for f, g in ((520, 1), (1310, 0.5), (2140, 0.3))) * env(n_(d), 0.001, 0.07) * 0.5
    squeal = sweep(1700, 1400, 0.2) * env(n_(0.2), 0.01, 0.06) * 0.25
    return mix(thud, clang, at(squeal, 0.05))


SOUNDS = {
    'traps/avalanche_rumble': avalanche_rumble, 'traps/avalanche_pour': avalanche_pour,
    'mechanics/cablecar_move': cablecar_move, 'mechanics/cablecar_stop': cablecar_stop,
}

if __name__ == '__main__':
    apply = '--apply' in sys.argv
    for name, fn in SOUNDS.items():
        x = fn()
        save(os.path.join(PRUEBAS, os.path.basename(name) + '.wav'), x.copy())
        if apply: save(os.path.join(ROOT, 'assets', 'sounds', name + '.wav'), x.copy())
