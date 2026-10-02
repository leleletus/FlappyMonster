#!/usr/bin/env python3
# tools/sounds/mechanics.py
# Genera los sonidos de los bloques ON/OFF, del casco de los Gummies y del pez globo.
# Síntesis sencilla (ondas cuadradas/senos con envolventes, estilo 8 bits).
# Ejecutar desde la raíz del repo:
#     python3 tools/sounds/mechanics.py
import os, wave
import numpy as np

SR = 22050
rng = np.random.default_rng(11)


def t_(d): return np.arange(int(SR * d)) / SR


def env(n, attack=0.002, decay=0.1):
    t = np.arange(n) / SR
    return np.clip(t / max(attack, 1e-6), 0, 1) * np.exp(-t / decay)


def square(f, d, duty=0.5):
    ph = (np.cumsum(np.full(int(SR * d), f)) / SR) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def pad(x, n): return np.concatenate([x, np.zeros(max(0, n - len(x)))])


def mix(*parts):
    n = max(len(p) for p in parts)
    return sum(pad(p, n) for p in parts)


def at(x, delay): return np.concatenate([np.zeros(int(SR * delay)), x])


def save(path, x, peak=0.85, drive=None):
    x = x / (np.max(np.abs(x)) + 1e-9)
    if drive:                           # compresión suave: más densidad, mismo pico
        x = np.tanh(x * drive) / np.tanh(drive)
    x = x * peak
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'  {path}  {len(x) / SR:.2f} s')


# Golpe seco del bloque (común a ON y OFF)
def thunk():
    d = 0.08
    f = np.linspace(180, 90, int(SR * d))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(f), 0.001, 0.03)
    return body


# ON: dos notas que suben (interruptor que se enciende)
def switch_on():
    a = square(660, 0.07, 0.25) * env(int(SR * 0.07), 0.002, 0.05)
    b = square(990, 0.12, 0.25) * env(int(SR * 0.12), 0.002, 0.08)
    return mix(thunk() * 0.9, at(a * 0.5, 0.01), at(b * 0.5, 0.07))


# OFF: las mismas notas bajando
def switch_off():
    a = square(740, 0.07, 0.25) * env(int(SR * 0.07), 0.002, 0.05)
    b = square(440, 0.14, 0.25) * env(int(SR * 0.14), 0.002, 0.09)
    return mix(thunk() * 0.9, at(a * 0.5, 0.01), at(b * 0.5, 0.07))


def sweep(f0, f1, d, curve=1.0):
    t = t_(d)
    f = f0 + (f1 - f0) * (t / d) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(d): return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y, acc = np.zeros_like(x), 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


# Rebote en el casco: "bonk" hueco y metálico, corto (el casco aguanta)
def helmet_bounce():
    d = 0.22
    body = sweep(520, 380, d, 0.5) * env(int(SR * d), 0.001, 0.05)
    ring = sum(np.sin(2 * np.pi * f * t_(d)) * k for f, k in ((1180, 0.5), (1760, 0.3)))
    ring = ring * env(int(SR * d), 0.001, 0.06)
    tick = noise(0.01) * env(int(SR * 0.01), 0.0005, 0.003)
    return mix(body, ring * 0.6, tick * 0.5)


# Casco que se rompe (ground pound): golpe, "clonk" que se rompe y trozos
def helmet_break():
    ring = sum(np.sin(2 * np.pi * f * t_(0.3)) * k for f, k in ((820, 1), (1370, 0.6), (2210, 0.35)))
    ring = ring * env(int(SR * 0.3), 0.001, 0.05)
    crack = lowpass(noise(0.18), 5000) * env(int(SR * 0.18), 0.001, 0.05)
    bits = [at(square(1500 + 400 * i, 0.03, 0.3) * env(int(SR * 0.03), 0.001, 0.01), 0.06 + i * 0.045)
            for i in range(4)]
    thud = sweep(160, 70, 0.15, 0.6) * env(int(SR * 0.15), 0.001, 0.05)
    return mix(ring * 0.8, crack * 0.9, thud, *[b * 0.35 for b in bits])


# ── Pez globo ─────────────────────────────────────────────────────────────────
# Burbuja: "blup" (seno con subida rápida de tono)
def blup(f0=300, f1=900, d=0.07):
    return sweep(f0, f1, d, 2.0) * env(int(SR * d), 0.002, 0.03)


# Aviso (medio hinchado): dos burbujas y un temblor que sube
def puffer_warn():
    d = 0.45
    wob = sweep(220, 420, d, 1.2) * (1 + 0.5 * np.sin(2 * np.pi * 18 * t_(d)))
    wob = wob * env(int(SR * d), 0.03, 0.35) * 0.45
    return mix(blup(), at(blup(350, 1000), 0.12), wob)


# Se hincha del todo: tono que sube como un globo + aire
def puffer_inflate():
    d = 0.4
    tone = sweep(260, 780, d, 0.7) * env(int(SR * d), 0.01, 0.5)
    air = lowpass(noise(d), 2500) * np.linspace(0.2, 1, int(SR * d)) * env(int(SR * d), 0.01, 0.25)
    pop = blup(500, 1300, 0.05)
    return mix(tone * 0.8, air * 0.6, at(pop, d - 0.03))


# Se deshincha: tono que baja con aire que se escapa
def puffer_deflate():
    d = 0.5
    t = t_(d)
    f = 700 * (160 / 700) ** (t / d) + 25 * np.sin(2 * np.pi * 14 * t)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.01, 0.4)
    hiss = (noise(d) - lowpass(noise(d), 2000)) * np.exp(-t / 0.3) * 0.5
    return mix(tone * 0.7, hiss)


# Pinchazo al jugador: "tsk" agudo + golpecito
def puffer_prick():
    stab = (noise(0.03) - lowpass(noise(0.03), 3000)) * env(int(SR * 0.03), 0.0005, 0.01)
    ping = sweep(2600, 1900, 0.09) * env(int(SR * 0.09), 0.0005, 0.03)
    hit = sweep(300, 120, 0.12, 0.6) * env(int(SR * 0.12), 0.001, 0.04)
    return mix(stab * 1.2, ping * 0.6, at(hit, 0.01))


if __name__ == '__main__':
    print('Sonidos de mecanismos:')
    save('assets/sounds/mechanics/switch_on.wav', switch_on())
    save('assets/sounds/mechanics/switch_off.wav', switch_off())
    save('assets/sounds/enemies/gummy/helmet_break.wav', helmet_break(), drive=2.5)
    save('assets/sounds/enemies/gummy/helmet_bounce.wav', helmet_bounce())
    save('assets/sounds/enemies/pufferfish/warn.wav', puffer_warn())
    save('assets/sounds/enemies/pufferfish/inflate.wav', puffer_inflate())
    save('assets/sounds/enemies/pufferfish/deflate.wav', puffer_deflate())
    save('assets/sounds/enemies/pufferfish/prick.wav', puffer_prick(), drive=3.0)
