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


# Resonador (filtro paso banda de 2 polos): el "hueco" de la cáscara
def reson(x, f, q):
    r = np.exp(-np.pi * f / q / SR)
    c1, c2 = 2 * r * np.cos(2 * np.pi * f / SR), -r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i, v in enumerate(x):
        y0 = (1 - r) * v + c1 * y1 + c2 * y2
        y[i] = y0
        y2, y1 = y1, y0
    return y


# Golpe de quitina: ruido muy corto por modos inarmónicos (hueco, seco, sin
# el "pitido" de un seno puro)
def chitin(scale=1.0, d=0.07):
    n = int(SR * d)
    hit = pad(noise(0.004) * env(int(SR * 0.004), 0.0002, 0.0015), n)
    modes = ((1180, 9, 1.0), (1790, 11, 0.7), (2710, 13, 0.5), (430, 6, 0.8))
    out = sum(reson(hit, f * scale, q) * g for f, q, g in modes)
    tick = highpass(pad(noise(0.003), n), 3500) * env(n, 0.0001, 0.0012) * 0.25
    return mix(out / (np.max(np.abs(out)) + 1e-9), tick)


# Chasquido de pinzas: las puntas rozan, se cierran de golpe y rebotan
def clack():
    scrape = highpass(lowpass(noise(0.03), 4200), 1800) * np.linspace(0.05, 0.5, int(SR * 0.03)) ** 2
    snap = chitin(1.0)
    rebound = chitin(1.12, 0.05) * 0.35
    rattle = chitin(0.93, 0.04) * 0.18
    return mix(scrape * 0.8, at(snap, 0.028), at(rebound, 0.028 + 0.034), at(rattle, 0.028 + 0.058))


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


# Aviso de embestida (cangrejo de verdad): las patas escarban en el sitio
# (tic-tic graves y rápidos de quitina) mientras las pinzas chasquean cada vez
# más deprisa, alternando, hasta un chasquido doble fuerte al lanzarse.
# Los tiempos de los chasquidos = WINDUP_SNAPS de megacrabby.lua (el dibujo
# cierra la pinza a la vez).
WINDUP_SNAPS = (0.02, 0.16, 0.27, 0.35, 0.41, 0.46, 0.50)


def windup():
    d = 0.62
    parts = [np.zeros(int(SR * d))]
    # Patas escarbando: tics graves a ~22/s que van a más
    t = 0.0
    i = 0
    while t < 0.52:
        g = 0.25 + 0.35 * t / 0.52
        parts.append(at(chitin(0.42 + 0.05 * (i % 3), 0.05) * g, t))
        scrape = lowpass(noise(0.03), 900) * env(int(SR * 0.03), 0.002, 0.01) * g * 0.6
        parts.append(at(scrape, t))
        t += 0.045 - 0.012 * t / 0.52
        i += 1
    # Chasquidos de pinzas acelerando, alternando tono (una pinza y la otra)
    for k, t0 in enumerate(WINDUP_SNAPS):
        g = 0.55 + 0.45 * k / (len(WINDUP_SNAPS) - 1)
        parts.append(at(clack() * g, t0, None) if k % 2 == 0 else at(chitin(0.86, 0.06) * g, t0 + 0.028))
    # Golpe final: las dos pinzas a la vez + un "hff" de aire
    parts.append(at(clack() * 1.1, 0.53))
    parts.append(at(chitin(0.8, 0.07) * 0.9, 0.56))
    huff = highpass(lowpass(noise(0.12), 2600), 500) * env(int(SR * 0.12), 0.01, 0.04) * 0.5
    parts.append(at(huff, 0.53))
    return mix(*parts)


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


# Burbuja: blip corto que sube de tono (la espuma de la boca de un cangrejo)
def bubble(f0):
    d = 0.018
    tt = t_(d)
    f = f0 * (1 + 0.7 * tt / d)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.001, 0.005)


# Rugido de CANGREJO (entrada y descansos), no de león: estridulación (el
# raspado rapidísimo de quitina contra quitina, cada vez más rápido y luego
# frenando), espuma burbujeante, un siseo áspero por la boca, un fondo grave
# que lo hace enorme y un castañeteo de pinzas al final
def roar():
    d = 1.2
    tt = t_(d)
    shape = np.sin(np.pi * np.clip(tt / 1.0, 0, 1)) ** 0.6              # sube y baja (0-1 s)
    parts = [np.zeros(int(SR * d))]
    # Estridulación: raspados de 18/s a 60/s y de vuelta
    t = 0.04
    i = 0
    while t < 1.0:
        s = np.sin(np.pi * t / 1.0) ** 0.6
        parts.append(at(chitin(0.55 + 0.25 * s + 0.04 * (i % 2), 0.04) * (0.35 + 0.65 * s), t))
        t += 1 / (18 + 42 * s)
        i += 1
    # Espuma: burbujas al azar, más densas en el centro
    for _ in range(170):
        t0 = rng.uniform(0.05, 1.0)
        if rng.uniform() < np.sin(np.pi * t0) ** 0.8:
            parts.append(at(bubble(rng.uniform(320, 1100)) * rng.uniform(0.25, 0.6), t0))
    # Siseo por la boca (ruido de banda media con aspereza) y fondo grave
    rasp = 1 + 0.5 * np.sign(np.sin(2 * np.pi * 34 * tt))
    hiss = highpass(lowpass(noise(d), 2400), 450) * rasp * shape * 0.55
    ph = np.cumsum(46 + 14 * shape) / SR
    rumble = lowpass(np.where((ph % 1) < 0.5, 1.0, -1.0), 260) * shape * 0.55
    parts += [hiss, rumble, at(clack() * 0.8, 1.0), at(chitin(1.1, 0.05) * 0.4, 1.06)]
    return mix(*parts)


# Caída desde el cielo: silbido que baja (antes del golpe)
def fall():
    d = 1.0
    tt = t_(d)
    f = 1500 * (260 / 1500) ** (tt / d)
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.clip(tt / 0.1, 0, 1) * (0.5 + 0.5 * tt / d)
    air = (noise(d) - lowpass(noise(d), 3000)) * (tt / d) * 0.25
    return mix(whistle * 0.8, air)


if __name__ == '__main__':
    # (con nombres: solo esos, p. ej. `megacrabby.py roar windup`; los demás no se tocan)
    import sys
    only = set(sys.argv[1:])
    print('Sonidos del Mega Crabby:')
    for name, fn in (('step', step), ('clack', clack), ('hurt', hurt), ('slam', slam),
                     ('windup', windup), ('shrink', shrink), ('flee', flee), ('roar', roar), ('fall', fall)):
        if only and name not in only: continue
        save(name, fn(), drive=4.0 if name == 'clack' else 2.2)   # (el chasquido es muy corto: más denso)
