#!/usr/bin/env python3
# tools/sounds/props.py — los SONIDOS de lo nuevo aprobado en 0.5.67 (diseño en curso): el Soplón, la Balanza, la Caja,
# la Semilla, la Ventisca y el Géiser. Síntesis sencilla de 8 bits (ruido filtrado, cuadradas y senos con envolventes), como tools/sounds/mechanics.py.
#   python3 tools/sounds/props.py            → vistas previas (.wav) en FlappyMonster_pruebas/nuevos/sonidos/
#   python3 tools/sounds/props.py --apply    → assets/sounds/props/*.wav
# Se comprueban con números: NO se han escuchado.
import os, sys, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 22050
rng = np.random.default_rng(67)
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'nuevos', 'sonidos')
OUT = os.path.join(ROOT, 'assets', 'sounds', 'props')


def n_(d): return int(SR * d)
def t_(d): return np.arange(n_(d)) / SR
def noise(d): return rng.uniform(-1, 1, n_(d))
def band(x, lo, hi): return sosfilt(butter(2, [lo, hi], btype='band', fs=SR, output='sos'), x)
def low(x, f): return sosfilt(butter(2, f, btype='low', fs=SR, output='sos'), x)
def env(n, a=0.005, d=0.1):
    t = np.arange(n) / SR
    return np.clip(t / max(a, 1e-6), 0, 1) * np.exp(-t / d)
def sweep(f0, f1, d, wave='sin', duty=0.5):
    f = np.geomspace(f0, f1, n_(d)) if f0 > 0 and f1 > 0 else np.linspace(f0, f1, n_(d))
    ph = np.cumsum(f) / SR
    return np.sin(2 * np.pi * ph) if wave == 'sin' else np.where(ph % 1 < duty, 1.0, -1.0)
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


# ── EL SOPLÓN ──
def gust_inhale():
    """Inspira: aire que sube de tono y de fuerza (0,9 s) y una notita que sube (se hincha)"""
    d = 0.9
    x = noise(d)
    out = np.zeros(n_(d))
    for i in range(0, n_(d), 512):                           # (un paso-banda que sube: aspirar)
        u = i / n_(d)
        seg = band(x[i:i + 512 + 256], 300 + 1600 * u, 900 + 2600 * u)[:512]
        out[i:i + len(seg)] += seg * (0.2 + 0.8 * u)
    tone = sweep(220, 440, d, 'sq', 0.25) * np.linspace(0, 0.15, n_(d))
    return out + tone
def gust_blow():
    """Sopla: una racha que empieza fuerte y se va, con un silbido que baja (0,7 s)"""
    d = 0.7
    x = band(noise(d), 500, 4200) * env(n_(d), 0.01, 0.28)
    whistle = sweep(1400, 700, d) * env(n_(d), 0.02, 0.2) * 0.25
    return x + whistle
def gust_pop():
    """Revienta: un 'pop' corto y un soplo que se escapa"""
    pop = sweep(900, 180, 0.06) * env(n_(0.06), 0.001, 0.02)
    puff = band(noise(0.35), 400, 3000) * env(n_(0.35), 0.003, 0.09) * 0.7
    return mix(pop, at(puff, 0.02))


# ── LA BALANZA ──
def scale_creak():
    """La cuerda cruje al moverse: un chirrido corto que vibra (0,35 s)"""
    d = 0.35
    f = 260 + 60 * np.sin(2 * np.pi * 7 * t_(d))
    sq = np.where((np.cumsum(f) / SR) % 1 < 0.2, 1.0, -1.0)
    return low(sq, 1800) * env(n_(d), 0.02, 0.12) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t_(d)))
def scale_launch():
    """Catapulta: golpe seco de madera y un muelle que sube"""
    thunk = sweep(170, 70, 0.1) * env(n_(0.1), 0.001, 0.04)
    boing = sweep(180, 720, 0.32, 'sq', 0.3) * env(n_(0.32), 0.005, 0.16) * 0.5
    return mix(thunk, at(boing, 0.03))


# ── LA CAJA ──
def box_push():
    """Arrastrarla: un roce granulado (se repite mientras se empuja), 0,4 s"""
    d = 0.4
    g = band(noise(d), 120, 900)
    grit = (rng.random(n_(d)) < 0.004) * rng.uniform(-1, 1, n_(d)) * 3
    return (g + band(grit, 800, 3000)) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t_(d)) ** 2)
def box_land():
    """Cae al suelo: golpe hueco"""
    body = sweep(140, 60, 0.18) * env(n_(0.18), 0.001, 0.06)
    knock = band(noise(0.06), 300, 1500) * env(n_(0.06), 0.001, 0.015) * 0.6
    return mix(body, knock)
def box_break():
    """Se rompe: crujido de astillas en ráfaga y trozos que caen"""
    crack = band(noise(0.08), 1200, 6000) * env(n_(0.08), 0.001, 0.02)
    crunch = band(noise(0.3), 200, 1800) * env(n_(0.3), 0.002, 0.08) * 0.8
    bits = [at(band(noise(0.04), 900, 3500) * env(n_(0.04), 0.001, 0.012) * 0.5, 0.12 + i * 0.07) for i in range(4)]
    return mix(crack, crunch, *bits)


# ── LA SEMILLA ──
def seed_pickup():
    """Cogerla: dos notas brillantes que suben"""
    a = sweep(784, 784, 0.07, 'sq', 0.25) * env(n_(0.07), 0.002, 0.05)
    b = sweep(1175, 1175, 0.12, 'sq', 0.25) * env(n_(0.12), 0.002, 0.08)
    return mix(a, at(b, 0.06))
def seed_plant():
    """Plantarla: golpe en la tierra y un susurro"""
    thud = sweep(120, 55, 0.12) * env(n_(0.12), 0.001, 0.05)
    rustle = band(noise(0.2), 2000, 6000) * env(n_(0.2), 0.01, 0.06) * 0.4
    return mix(thud, at(rustle, 0.04))
def seed_grow():
    """Crece: un arpegio que sube con un roce de hojas (≈1 s)"""
    notes = [262, 330, 392, 523, 659, 784]
    parts = [at(sweep(f, f, 0.12, 'sq', 0.25) * env(n_(0.12), 0.002, 0.07) * 0.6, i * 0.13) for i, f in enumerate(notes)]
    leaves = band(noise(0.9), 1800, 5000) * env(n_(0.9), 0.05, 0.4) * 0.25
    return mix(leaves, *parts)
def seed_wilt():
    """Se marchita: notas que bajan, blandas"""
    notes = [523, 440, 349, 262]
    return mix(*[at(sweep(f, f * 0.94, 0.16) * env(n_(0.16), 0.01, 0.1), i * 0.14) for i, f in enumerate(notes)])


# ── LA VENTISCA ──
def wind_warn():
    """El aviso: un silbido que sube y crece (1,0 s), con un aire grave debajo"""
    d = 1.0
    whistle = sweep(500, 1300, d) * np.linspace(0.05, 0.4, n_(d))
    air = band(noise(d), 200, 900) * np.linspace(0.1, 0.6, n_(d))
    return whistle + air
def wind_gust():
    """La racha (se repite mientras sopla, 1,2 s): aire fuerte con remolinos"""
    d = 1.2
    x = band(noise(d), 250, 2400) * (0.7 + 0.3 * np.sin(2 * np.pi * 3.1 * t_(d)))
    howl = sweep(340, 300, d) * 0.12 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.9 * t_(d)))
    k = n_(0.08); x[:k] *= np.linspace(0, 1, k); x[-k:] *= np.linspace(1, 0, k)
    return x + howl


# ── EL GÉISER ──
def geyser_rumble():
    """El aviso: borboteo grave que crece (0,9 s)"""
    d = 0.9
    rum = low(noise(d), 160) * np.linspace(0.3, 1.0, n_(d)) * 3
    pops = [at(sweep(220 + 40 * i, 120, 0.05) * env(n_(0.05), 0.001, 0.02) * 0.5, 0.1 + i * 0.12) for i in range(6)]
    return mix(rum, *pops)
def geyser_burst():
    """La erupción de AGUA: golpe y chorro que sale (1,0 s)"""
    boom = sweep(110, 50, 0.15) * env(n_(0.15), 0.001, 0.06)
    jet = band(noise(1.0), 600, 6000) * env(n_(1.0), 0.01, 0.45)
    return mix(boom, jet * 0.8)
def steam_hiss():
    """VAPOR / humo (fortaleza, cueva, volcán): siseo agudo (1,0 s)"""
    x = band(noise(1.0), 3000, 9000) * env(n_(1.0), 0.02, 0.5)
    return x + low(noise(1.0), 300) * env(n_(1.0), 0.01, 0.2) * 0.6
def ice_freeze():
    """Nieve: el chorro se CONGELA — crujidos que suben"""
    cr = [at(band(noise(0.03), 2500, 8000) * env(n_(0.03), 0.001, 0.008), i * 0.05) for i in range(8)]
    ring = sweep(1500, 1900, 0.4) * env(n_(0.4), 0.005, 0.18) * 0.3
    return mix(ring, *cr)


SOUNDS = {
    'wind_warn': wind_warn, 'wind_gust': wind_gust,
    'geyser_rumble': geyser_rumble, 'geyser_burst': geyser_burst, 'steam_hiss': steam_hiss, 'ice_freeze': ice_freeze,
    'gust_inhale': gust_inhale, 'gust_blow': gust_blow, 'gust_pop': gust_pop,
    'scale_creak': scale_creak, 'scale_launch': scale_launch,
    'box_push': box_push, 'box_land': box_land, 'box_break': box_break,
    'seed_pickup': seed_pickup, 'seed_plant': seed_plant, 'seed_grow': seed_grow, 'seed_wilt': seed_wilt,
}

if __name__ == '__main__':
    dst = OUT if '--apply' in sys.argv else PRUEBAS
    for name, fn in SOUNDS.items(): save(os.path.join(dst, name + '.wav'), fn())
    print('  en ' + dst)
