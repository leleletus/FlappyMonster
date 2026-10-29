#!/usr/bin/env python3
# tools/sounds/iceberg.py — los SONIDOS del Iceberg (types/mechanisms/iceberg.lua; la Costa Helada, 2026-10-29).
# Síntesis sencilla de 8 bits como tools/sounds/props.py (ruido filtrado, senos con envolventes).
#   python3 tools/sounds/iceberg.py            → vistas previas (.wav) en FlappyMonster_pruebas/mecanicas_heladas/sonidos/
#   python3 tools/sounds/iceberg.py --apply    → assets/sounds/props/iceberg_*.wav
# Se comprueban con números (run.sh sounds NAMES=icebergCreak,icebergSink): NO se han escuchado.
import os, sys, wave, zlib
import numpy as np
from scipy.signal import butter, sosfilt

SR = 22050
rng = np.random.default_rng(1029)
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'mecanicas_heladas', 'sonidos')
OUT = os.path.join(ROOT, 'assets', 'sounds', 'props')


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


def save(path, x, peak=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    k = min(len(x), n_(0.004)); x[-k:] *= np.linspace(1, 0, k)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'  {os.path.basename(path):24s} {len(x) / SR:.2f} s')


def crack(f=3200, d=0.03):
    """Un chasquido de hielo: ruido agudo muy corto con un "tink" inarmónico"""
    tt = t_(d)
    ring = np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(2 * np.pi * f * 1.7 * tt)
    return band(noise(d), 2000, 9000) * env(n_(d), 0.0003, 0.004) + ring * env(n_(d), 0.0003, 0.008) * 0.3


def iceberg_creak():
    """AVISO (sobrepeso, 0,7 s): el hielo GIME grave (un roce que sube y baja de tono) y se oyen chasquidos"""
    d = 0.7
    f = 70 * (1 + 0.25 * np.sin(2 * np.pi * 1.6 * t_(d))) * np.geomspace(1, 1.3, n_(d))
    ph = np.cumsum(f) / SR
    groan = np.exp(-((ph % 1) * 7)) * (0.7 + 0.3 * rng.random(n_(d)) ** 4)
    groan = band(groan - groan.mean(), 120, 1400) * np.sin(np.pi * np.linspace(0, 1, n_(d))) ** 0.6
    parts = [groan / (np.max(np.abs(groan)) + 1e-9)]
    for k in range(5):
        parts.append(at(crack(rng.uniform(2600, 4200)) * rng.uniform(0.3, 0.6), 0.05 + k * 0.12 + rng.uniform(0, 0.05)))
    x = mix(*parts)
    return np.tanh(2.2 * x / (np.max(np.abs(x)) + 1e-9))       # (más cuerpo: el gemido se oye entero, no solo los chasquidos)


def iceberg_sink():
    """SE HUNDE: un "glub" grave (seno que baja) con el agua que se cierra encima (ruido que se apaga) y burbujas"""
    d = 0.6
    glub = sweep(160, 55, d) * env(n_(d), 0.01, 0.2)
    wash = low(noise(d), 900) * env(n_(d), 0.02, 0.18) * 0.6
    parts = [glub, wash]
    for k in range(4):
        b = sweep(500 + 150 * k, 900 + 200 * k, 0.05) * env(n_(0.05), 0.002, 0.015) * 0.25
        parts.append(at(b, 0.18 + k * 0.08 + rng.uniform(0, 0.03)))
    return mix(*parts)


SOUNDS = {'iceberg_creak': iceberg_creak, 'iceberg_sink': iceberg_sink}
PEAK = {'iceberg_sink': 0.55}                    # (run.sh sounds: entre -15 y -8 dBFS)

if __name__ == '__main__':
    dst = OUT if '--apply' in sys.argv else PRUEBAS
    for name, fn in SOUNDS.items():
        rng = np.random.default_rng(zlib.crc32(name.encode()))
        save(os.path.join(dst, name + '.wav'), fn(), PEAK.get(name, 0.8))
    print('  en ' + dst)
