#!/usr/bin/env python3
# tools/sounds/megacrabby.py
# Genera los sonidos del Mega Crabby (assets/sounds/bosses/megacrabby/*.wav).
# Síntesis sencilla (senos, ruido filtrado, envolventes); los archivos que
# salen son los que usa el juego. Ejecutar desde la raíz del repo:
#     python3 tools/sounds/megacrabby.py
import os, wave
import numpy as np

SR = 22050
OUT = 'assets/sounds/bosses/megacrabby'
rng = np.random.default_rng(7)


def t_(d): return np.arange(int(SR * d)) / SR


def env(n, attack=0.002, decay=0.1):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-6), 0, 1)
    return a * np.exp(-t / decay)


def sweep(f0, f1, d, curve=1.0):
    t = t_(d)
    k = (t / d) ** curve
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff): return x - lowpass(x, cutoff)


def noise(d): return rng.uniform(-1, 1, int(SR * d))


def pad(x, n): return np.concatenate([x, np.zeros(max(0, n - len(x)))])


def mix(*parts):
    n = max(len(p) for p in parts)
    return sum(pad(p, n) for p in parts)


def at(x, delay, total=None):
    out = np.concatenate([np.zeros(int(SR * delay)), x])
    return pad(out, total) if total else out


def save(name, x, peak=0.95, drive=2.2):
    # Compresión suave (tanh): más densidad = se oye más a igual pico
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


def click(freqs=(2300, 3400), d=0.03):
    n = int(SR * d)
    burst = highpass(noise(0.006), 2500) * env(int(SR * 0.006), 0.0005, 0.002)
    ring = sum(np.sin(2 * np.pi * f * t_(d)) for f in freqs) * env(n, 0.0005, 0.008)
    return mix(burst * 0.9, ring * 0.6)


# Pisada pesada: golpe grave con la cáscara que suena un poco (más grave que
# al principio: todo ~⅓ más bajo de tono; mismas duraciones)
def step():
    d = 0.24
    thump = sweep(66, 28, d, 0.6) * env(int(SR * d), 0.003, 0.08)
    dirt = lowpass(noise(0.08), 600) * env(int(SR * 0.08), 0.001, 0.025) * 1.6
    shell = np.sin(2 * np.pi * 540 * t_(0.05)) * env(int(SR * 0.05), 0.001, 0.012) * 0.25
    clonk = sweep(290, 160, 0.12) * env(int(SR * 0.12), 0.002, 0.035) * 0.6
    return mix(thump * 1.1, dirt, shell, clonk)


# Chasquido de pinzas: dos clics secos seguidos
def clack():
    c = click()
    return mix(c, at(click((2600, 3900)), 0.045))


# Daño: "bonk" hueco en el caparazón + chillido de cangrejo (blips que bajan)
def hurt():
    d = 0.6
    bonk = mix(sweep(210, 150, 0.25) * env(int(SR * 0.25), 0.001, 0.06),
               sweep(470, 380, 0.2) * env(int(SR * 0.2), 0.001, 0.04) * 0.6)
    chirps = []
    for i in range(7):
        f = 1500 - i * 120
        dd = 0.045
        tt = t_(dd)
        vib = np.sin(2 * np.pi * (f + 60 * np.sin(2 * np.pi * 45 * tt)) * tt)
        sq = np.sign(vib) * 0.5 + vib * 0.5
        chirps.append(at(sq * env(len(tt), 0.002, 0.02), 0.06 + i * 0.058))
    return mix(bonk * 1.3, *[c * 0.45 for c in chirps], np.zeros(int(SR * d)))


# Caída del techo clavándose: golpe enorme + crujido + "ting" del pincho
def slam():
    d = 0.7
    boom = sweep(80, 32, d, 0.5) * env(int(SR * d), 0.002, 0.18)
    crunch = lowpass(noise(0.35), 3200) * env(int(SR * 0.35), 0.001, 0.09) * 1.9
    crack = sweep(520, 180, 0.3) * env(int(SR * 0.3), 0.002, 0.07) * 0.8
    ting = np.sin(2 * np.pi * 1850 * t_(0.4)) * env(int(SR * 0.4), 0.001, 0.09) * 0.35
    return mix(boom * 1.2, crunch, crack, at(ting, 0.01))


# Aviso de embestida: castañeteo cada vez más rápido y un tono que sube
def windup():
    d = 0.5
    parts = [np.zeros(int(SR * d))]
    tpos, gap = 0.0, 0.09
    while tpos < d - 0.03:
        parts.append(at(click((2000 + tpos * 1500, 3100)) * 0.7, tpos))
        tpos += gap
        gap = max(0.03, gap * 0.8)
    growl = sweep(260, 620, d, 1.4) * env(int(SR * d), 0.05, 0.5) * 0.35
    growl = np.tanh(growl * 3) * 0.35
    return mix(*parts, growl)


# Muerte: se desinfla (silbato que baja con temblor + escape de aire)
def shrink():
    d = 1.1
    tt = t_(d)
    f = 950 * (180 / 950) ** (tt / d) + 40 * np.sin(2 * np.pi * 9 * tt)
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.02, 0.6)
    hiss = highpass(noise(d), 3000) * np.exp(-tt / 0.35) * 0.35
    pop = lowpass(noise(0.05), 2500) * env(int(SR * 0.05), 0.001, 0.01)
    return mix(pop * 0.9, whistle * 0.8, hiss)


# Huida: chillidos agudos de pánico (cangrejo pequeño)
def flee():
    d = 0.32
    parts = []
    for i, (f0, f1) in enumerate(((1900, 2600), (2100, 2900))):
        c = sweep(f0, f1, 0.07) * env(int(SR * 0.07), 0.002, 0.03)
        parts.append(at(c, i * 0.11))
    return mix(*parts, np.zeros(int(SR * d)))


if __name__ == '__main__':
    print('Sonidos del Mega Crabby:')
    for name, fn in (('step', step), ('clack', clack), ('hurt', hurt), ('slam', slam),
                     ('windup', windup), ('shrink', shrink), ('flee', flee)):
        save(name, fn())
