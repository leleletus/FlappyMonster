#!/usr/bin/env python3
# tools/sounds/mirror.py
# Sonidos nuevos del jefe Espejo (assets/sounds/bosses/mirror/*.wav):
#   warp   = se rompe en cristales y desaparece (estallido + campanitas que caen)
#   appear = reaparece en un espejo (brillo que sube + "ting" de cristal)
#   portal = zumbido de cristal mientras apunta desde el espejo (corto, se repite)
# Ejecutar desde la raíz del repo:  python3 tools/sounds/mirror.py [nombres...]
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, pad, mix, at, reson   # noqa: E402

OUT = 'assets/sounds/bosses/mirror'
rng = np.random.default_rng(11)


def save(name, x, peak=0.95, drive=2.5):
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(x * drive) / np.tanh(drive)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'  {OUT}/{name}.wav  {len(x) / SR:.2f} s')


# Campanita de cristal: modos inarmónicos agudos que se apagan
def tink(f, d=0.25, g=1.0):
    tt = t_(d)
    y = sum(np.sin(2 * np.pi * f * k * tt) * a for k, a in ((1, 1.0), (2.76, 0.5), (5.4, 0.25)))
    return y * env(len(tt), 0.0008, d / 4) * g


# Se rompe: golpe seco de cristal, crujido de ruido agudo y trocitos que caen
def warp():
    d = 0.8
    crack = highpass(noise(0.09), 2500) * env(int(SR * 0.09), 0.0005, 0.025) * 1.4
    body = sum(reson(pad(noise(0.004) * env(int(SR * 0.004), 0.0002, 0.001), int(SR * 0.2)), f, 25) * g
               for f, g in ((2350, 1.0), (3700, 0.7), (5200, 0.45)))
    body = body / (np.max(np.abs(body)) + 1e-9)
    parts = [np.zeros(int(SR * d)), crack, body * 0.9]
    for _ in range(14):                                  # trocitos rebotando
        t0 = rng.uniform(0.05, 0.6)
        parts.append(at(tink(rng.uniform(2800, 6500), 0.09, rng.uniform(0.15, 0.45) * (1 - t0)), t0))
    swoosh = lowpass(noise(0.3), 1800) * np.linspace(1, 0, int(SR * 0.3)) ** 2 * 0.35
    parts.append(at(swoosh, 0.02))
    return mix(*parts)


# Reaparece: arpegio brillante que sube (con vibrato) y un "ting" final
def appear():
    d = 0.6
    parts = [np.zeros(int(SR * d))]
    for i, f in enumerate((880, 1109, 1319, 1760, 2217)):
        tt = t_(0.18)
        vib = np.sin(2 * np.pi * (f + 25 * np.sin(2 * np.pi * 9 * tt)) * tt)
        parts.append(at(vib * env(len(tt), 0.004, 0.05) * 0.5, i * 0.055))
    parts.append(at(tink(2640, 0.35, 1.0), 0.3))
    air = highpass(noise(0.35), 4000) * np.sin(np.linspace(0, np.pi, int(SR * 0.35))) * 0.12
    parts.append(air)
    return mix(*parts)


# Zumbido del espejo mientras apunta: cristal que vibra (batido) y sube un poco
def portal():
    d = 0.7
    tt = t_(d)
    f = 1180 + 120 * tt / d
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.8 * np.sin(2 * np.pi * np.cumsum(f * 1.013) / SR)
    y += 0.4 * np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR)
    shape = np.clip(tt / 0.08, 0, 1) * np.clip((d - tt) / 0.2, 0, 1)
    return y * shape * 0.6


# Cristal roto de jefe (evento): aviso = crujidos de cristal que se agrieta
# sobre un retumbar grave; salen = estallido de cristales hacia arriba;
# tocarlos = crujido de pisar cristal
def glass_warn():
    d = 1.6
    tt = t_(d)
    rumble = lowpass(noise(d), 160) * np.clip(tt / 0.3, 0, 1) * 1.6
    parts = [np.zeros(int(SR * d)), rumble]
    t0 = 0.05
    while t0 < 1.5:
        k = t0 / 1.5
        crk = highpass(noise(0.012), 2000) * env(int(SR * 0.012), 0.0003, 0.003)
        parts.append(at(crk * (0.3 + 0.7 * k), t0))
        if rng.uniform() < 0.5:
            parts.append(at(tink(rng.uniform(2500, 5200), 0.08, 0.25 + 0.3 * k), t0 + 0.005))
        t0 += 0.16 - 0.1 * k + rng.uniform(0, 0.04)
    return mix(*parts)


def glass_rise():
    d = 0.9
    boom = lowpass(noise(0.3), 400) * env(int(SR * 0.3), 0.002, 0.08) * 1.5
    parts = [np.zeros(int(SR * d)), boom, warp() * 0.8]
    for i in range(8):
        parts.append(at(tink(rng.uniform(2200, 4200), 0.3, 0.6), 0.02 + i * 0.02))
    return mix(*parts)


def glass_hit():
    d = 0.35
    crunch = highpass(noise(0.12), 1500) * env(int(SR * 0.12), 0.001, 0.03) * 1.3
    parts = [np.zeros(int(SR * d)), crunch]
    for i in range(5):
        parts.append(at(tink(rng.uniform(3000, 6500), 0.12, 0.5), rng.uniform(0, 0.08)))
    return mix(*parts)


if __name__ == '__main__':
    only = set(sys.argv[1:])
    print('Sonidos del Espejo:')
    for name, fn in (('warp', warp), ('appear', appear), ('portal', portal),
                     ('glass_warn', glass_warn), ('glass_rise', glass_rise), ('glass_hit', glass_hit)):
        if only and name not in only: continue
        save(name, fn())
