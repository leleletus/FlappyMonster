#!/usr/bin/env python3
# tools/sounds/jungle.py
# Sonidos de AMBIENTE de la SELVA (la isla de la jungla; propuesta, aún sin aprobar):
#   jungle_cicada   enjambre de cigarras que crece y se apaga (el fondo de la selva)
#   jungle_toucan   graznido ronco de tucán, tres veces
#   jungle_whistle  silbido de pájaro tropical que baja, dos notas
#   jungle_trill    trino rápido y agudo de un pájaro pequeño
#   jungle_frog     croar de rana (dos sílabas: la decoración de la rana y el ambiente)
#   jungle_howler   mono aullador LEJANO (muy de fondo)
#   jungle_rustle   hojas que se agitan (algo que se mueve entre las plantas)
#   fire_crackle    chisporroteo del brasero del templo
# Sin flags: escribe las vistas previas (cada sonido + una mezcla de 40 s de cómo sonaría el nivel) en
# /home/mtvemo/FlappyMonster_pruebas/selva/sonidos/. Con --apply: assets/sounds/ambience/ (aún NO).
#   python3 tools/sounds/jungle.py [--apply] [nombres...]
import os, sys, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 22050
APPLY = '--apply' in sys.argv
OUT = 'assets/sounds/ambience' if APPLY else '/home/mtvemo/FlappyMonster_pruebas/selva/sonidos'
rng = np.random.default_rng(1234)


def t_(d): return np.arange(int(SR * d)) / SR


def env(n, attack=0.002, decay=0.1):
    t = np.arange(n) / SR
    return np.clip(t / max(attack, 1e-6), 0, 1) * np.exp(-t / decay)


def band(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], 'band')
    return lfilter(b, a, x)


def lowpass(x, f, order=2):
    b, a = butter(order, f / (SR / 2))
    return lfilter(b, a, x)


def noise(d): return rng.uniform(-1, 1, int(SR * d))


def pad(x, n): return np.concatenate([x, np.zeros(max(0, n - len(x)))])


def place(out, x, at, gain=1.0):
    i = int(SR * at)
    n = min(len(x), len(out) - i)
    if n > 0: out[i:i + n] += x[:n] * gain


def tone(freq_fn, d):
    """Oscilador con la frecuencia (array o función de t) que se le dé"""
    tt = t_(d)
    f = freq_fn(tt) if callable(freq_fn) else freq_fn
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def forest(x, wet=0.35, dark=3000):
    """Cola de bosque: muchos ecos cortos, oscuros y difusos (no una cueva)"""
    out = pad(x, len(x) + int(SR * 0.6))
    for k in range(9):
        dl = rng.uniform(0.03, 0.45)
        g = wet * (1 - dl / 0.5) * rng.uniform(0.5, 1)
        place(out, lowpass(x, dark), dl, g)
    return out


def cicada():
    d = 3.6
    tt = t_(d)
    carrier = band(noise(d), 4200, 6800, 3)
    pulse = (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 52 * tt))) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * tt) ** 2)
    swell = np.sin(np.pi * tt / d) ** 1.5
    return lowpass(carrier * pulse, 9000) * swell


def toucan():
    out = np.zeros(int(SR * 1.3))
    for k in range(3):
        d = 0.16
        tt = t_(d)
        saw = 2 * ((np.cumsum(np.full(len(tt), 1.0)) * (430 - 120 * tt / d) / SR) % 1) - 1   # (diente de sierra que baja)
        rasp = 1 + 0.6 * np.sign(np.sin(2 * np.pi * 70 * tt))                              # (lo ronco: pulsos)
        x = band(saw * rasp, 600, 2600) * env(len(tt), 0.01, 0.07)
        place(out, x, 0.05 + k * 0.32, 1 - 0.15 * k)
    return forest(out, 0.3)


def whistle():
    out = np.zeros(int(SR * 1.1))
    for k, (f0, f1) in enumerate(((2900, 2100), (2600, 1800))):
        d = 0.24
        x = tone(lambda tt: f0 + (f1 - f0) * (tt / d) ** 0.7, d) * env(int(SR * d), 0.02, 0.12)
        x += 0.25 * tone(lambda tt: 2 * (f0 + (f1 - f0) * (tt / d) ** 0.7), d) * env(int(SR * d), 0.02, 0.08)
        place(out, x, 0.05 + k * 0.33)
    return forest(out, 0.25, 5000)


def trill():
    d = 0.9
    tt = t_(d)
    f = 3600 + 500 * np.sin(2 * np.pi * 26 * tt) - 400 * tt
    am = (0.5 + 0.5 * np.sin(2 * np.pi * 26 * tt)) ** 2
    return forest(tone(f, d) * am * env(len(tt), 0.05, 0.45), 0.2, 6000)


def frog():
    out = np.zeros(int(SR * 0.7))
    for k, n in enumerate((9, 6)):
        d = n / 60
        tt = t_(d)
        pulses = (np.sin(2 * np.pi * 60 * tt) > 0.2).astype(float)                         # (el "rrr": 60 golpes/s)
        body = band(tone(lambda t: 380 + 140 * t / d, d) + 0.5 * tone(lambda t: 1150 + 300 * t / d, d), 250, 1800)
        x = body * pulses * env(len(tt), 0.01, d * 0.8)
        place(out, x, 0.04 + k * 0.22)
    return forest(lowpass(out, 3000), 0.2)


def howler():
    d = 2.6
    tt = t_(d)
    f = 150 + 90 * np.sin(np.pi * tt / d) + 8 * np.sin(2 * np.pi * 5 * tt)
    voice = tone(f, d) + 0.6 * tone(2 * f, d) + 0.35 * tone(3 * f, d)
    breath = band(noise(d), 300, 1400) * 0.25
    x = band(voice + breath, 200, 900) * np.sin(np.pi * tt / d) ** 2
    return forest(lowpass(x, 900), 0.5, 700)                                               # (lejos: oscuro y con cola)


def rustle():
    d = 0.9
    out = np.zeros(int(SR * d))
    t0 = 0
    while t0 < d - 0.1:
        g = rng.uniform(0.4, 1)
        n = rng.uniform(0.03, 0.09)
        place(out, band(noise(n), 1800, 6500) * env(int(SR * n), 0.004, n * 0.4), t0, g)
        t0 += rng.uniform(0.02, 0.07)
    return out * np.sin(np.pi * t_(d) / d)


def crackle():
    d = 1.6
    out = band(noise(d), 300, 1200) * 0.12                                                 # (el soplo del fuego)
    for _ in range(26):
        at = rng.uniform(0, d - 0.05)
        n = rng.uniform(0.004, 0.015)
        place(out, band(noise(n), 1500, 7000) * env(int(SR * n), 0.0005, n * 0.3), at, rng.uniform(0.3, 1))
    return out


ALL = {'jungle_cicada': cicada, 'jungle_toucan': toucan, 'jungle_whistle': whistle, 'jungle_trill': trill,
       'jungle_frog': frog, 'jungle_howler': howler, 'jungle_rustle': rustle, 'fire_crackle': crackle}

# Cómo sonaría el nivel: { sonido, cada [a, b] s, volumen [a, b] } (como src/fx/CaveAmbience: flojo y espaciado)
LAYERS = [('jungle_cicada', 5, 11, 0.10, 0.18), ('jungle_whistle', 6, 14, 0.08, 0.16),
          ('jungle_trill', 9, 18, 0.06, 0.12), ('jungle_toucan', 12, 25, 0.08, 0.14),
          ('jungle_frog', 8, 16, 0.08, 0.14), ('jungle_howler', 25, 45, 0.10, 0.16),
          ('jungle_rustle', 10, 20, 0.05, 0.10)]


def loud(x):
    """dBFS del tramo más fuerte de 100 ms (como lo mide el arnés `sounds`)"""
    n = int(SR * 0.1)
    return max(10 * np.log10(np.mean(x[i:i + n] ** 2) + 1e-12) for i in range(0, max(1, len(x) - n), n // 4))


def norm(x, peak=0.9, target=-12.0):
    # (al nivel del resto de efectos — su tramo más fuerte a −12 dBFS —; si así pasa del pico, se recorta suave)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    for _ in range(4):
        x = x * 10 ** ((target - loud(x)) / 20)
        if np.max(np.abs(x)) > peak: x = np.tanh(x / peak) * peak
    f = min(len(x), int(SR * 0.01))
    x[-f:] *= np.linspace(1, 0, f)
    return x


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())
    print('  %s/%s.wav  %.2f s' % (OUT, name, len(x) / SR))


def demo(sounds, secs=40):
    out = np.zeros(int(SR * secs))
    for name, a, b, v0, v1 in LAYERS:
        t = rng.uniform(a, b) * 0.4
        while t < secs:
            pitch = rng.uniform(0.9, 1.1)
            x = sounds[name]
            idx = np.arange(0, len(x) - 1, pitch)                                          # (otro tono cada vez)
            place(out, np.interp(idx, np.arange(len(x)), x), t, rng.uniform(v0, v1))
            t += rng.uniform(a, b)
    return out / max(1.0, np.max(np.abs(out)) / 0.9)


if __name__ == '__main__':
    names = [a for a in sys.argv[1:] if not a.startswith('--')] or list(ALL)
    sounds = {n: norm(ALL[n]()) for n in ALL}
    for n in names: save(n, sounds[n])
    if not APPLY: save('mezcla_nivel_40s', demo(sounds))
