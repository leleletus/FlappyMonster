#!/usr/bin/env python3
# tools/sounds/snowboss.py
# Sonidos del jefe GRAN BOLA DE NIEVE (assets/sounds/bosses/snowboss/*.wav):
#   laugh      risita juguetona (4 "jeje" que suben, con vibrato)
#   roar       enfadado: gruñido grave + siseo de escarcha
#   spit       escupe una bola ("ptuu"): chasquido de labios + soplido
#   splat      la bola se estampa: golpe blando de nieve + crujido
#   roll       rodando (BUCLE sin cortes): crujido de nieve con retumbo
#   land       aterriza de un salto: golpe sordo + crujido
#   slam       el gran golpe contra el suelo: golpe muy grave, crujido largo
#   crash      choca contra una compuerta de hielo: golpe + tintineo de hielo
#   dizzy      mareado: pajaritos (piar que sube y baja)
#   crack      se agrieta (muerte, fase 3): crujido seco de hielo
#   burst      revienta en nieve: explosión blanda + polvo + trocitos
#   flee       la bolita huye: rodar chiquito y agudo con un "iii"
#   intro_roll entrada: bola que rueda creciendo (grave y cada vez más fuerte)
#   breath     aliento helado (vuelve a congelar el lago): siseo frío
# Desde la raíz del repo:  python3 tools/sounds/snowboss.py [nombres...]
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, pad, mix, at, reson, sweep   # noqa: E402

OUT = 'assets/sounds/bosses/snowboss'
rng = np.random.default_rng(1207)


def save(name, x, peak=0.95, drive=1.8):
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(x * drive) / np.tanh(drive)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = min(len(x), int(SR * 0.006))
    x[-fade:] *= np.linspace(1, 0, fade)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'  {OUT}/{name}.wav  {len(x) / SR:.2f} s')


def norm(x): return x / (np.max(np.abs(x)) + 1e-9)


def crunch(d, cut=2500, grain=0.004):
    """Crujido de nieve: muchos granitos de ruido filtrado."""
    n = int(SR * d)
    out = np.zeros(n)
    t0 = 0.0
    while t0 < d:
        g = lowpass(highpass(noise(grain), 400), cut) * env(int(SR * grain), 0.0003, grain / 3)
        i = int(t0 * SR)
        out[i:i + len(g)] += g[:max(0, n - i)] * rng.uniform(0.3, 1.0)
        t0 += rng.uniform(0.002, 0.012)
    return out


def thud(f0, f1, d, decay):
    return sweep(f0, f1, d, 0.5) * env(int(SR * d), 0.002, decay)


def tink(f, d, g):
    tt = t_(d)
    y = sum(np.sin(2 * np.pi * f * k * tt) * a for k, a in ((1, 1.0), (2.76, 0.4), (5.4, 0.15)))
    return y * env(len(tt), 0.0005, d / 4) * g


def voice(f0, d, vib=6.0, formants=((700, 5), (1200, 6))):
    """Vocal simple: pulso con vibrato por dos formantes (voz de dibujo)."""
    tt = t_(d)
    f = f0 * (1 + 0.04 * np.sin(2 * np.pi * vib * tt))
    ph = np.cumsum(f) / SR
    src = 2 * (ph % 1) - 1
    y = sum(norm(reson(src, fr, q)) * (1.0 / (i + 1)) for i, (fr, q) in enumerate(formants))
    return y * env(len(tt), 0.01, d / 2.5)


def laugh():
    parts = []
    for i, (f, t0) in enumerate(((420, 0.0), (470, 0.16), (530, 0.31), (600, 0.45), (680, 0.58))):
        parts.append(at(voice(f, 0.13, 9, ((900, 5), (1700, 7))) * (0.8 + i * 0.05), t0))
        parts.append(at(lowpass(noise(0.03), 4000) * env(int(SR * 0.03), 0.001, 0.01) * 0.25, t0))
    return mix(*parts)


def roar():
    d = 1.3
    n = int(SR * d)
    tt = t_(d)
    f = 70 + 25 * np.sin(2 * np.pi * 0.8 * tt) + 15 * np.sin(2 * np.pi * 17 * tt)
    ph = np.cumsum(f) / SR
    growl = np.tanh(3 * np.sin(2 * np.pi * ph)) * (0.7 + 0.3 * np.sin(2 * np.pi * 21 * tt))
    growl = norm(reson(growl, 320, 3)) + 0.6 * norm(reson(growl, 700, 4))
    e = np.minimum(1, tt / 0.15) * np.exp(-np.maximum(0, tt - 0.8) / 0.25)
    hiss = highpass(noise(d), 3000) * np.minimum(1, tt / 0.4) * np.exp(-tt / 0.9) * 0.35
    return growl * e + hiss + crunch(d, 1800) * 0.2 * e


def spit():
    pop = thud(240, 90, 0.06, 0.02)
    puff = lowpass(highpass(noise(0.25), 600), 3000) * env(int(SR * 0.25), 0.01, 0.07)
    return mix(pop, at(puff * 0.6, 0.02), at(sweep(500, 1300, 0.12) * env(int(SR * 0.12), 0.005, 0.05) * 0.25, 0.03))


def splat():
    return mix(thud(150, 60, 0.15, 0.05) * 0.9, crunch(0.22, 2200) * env(int(SR * 0.22), 0.001, 0.07) * 0.7)


def roll():
    """Bucle de 1 s: retumbo + crujido con pulso de giro (4 por segundo); sin corte."""
    d = 1.0
    n = int(SR * d)
    tt = t_(d)
    rum = lowpass(noise(d + 0.2), 140)[:n]
    rum = rum / (np.max(np.abs(rum)) + 1e-9)
    puls = 0.6 + 0.4 * np.sin(2 * np.pi * 4 * tt) ** 2
    cr = crunch(d + 0.2, 2000)[:n]
    y = rum * 0.9 * puls + cr * 0.45 * puls
    # cola sobre el principio (bucle sin corte)
    xf = int(SR * 0.1)
    y[:xf] = y[:xf] * np.linspace(0, 1, xf) + y[-xf:] * np.linspace(1, 0, xf)
    return y


def land():
    return mix(thud(110, 45, 0.25, 0.08), crunch(0.25, 2000) * env(int(SR * 0.25), 0.002, 0.08) * 0.6)


def slam():
    d = 0.9
    boom = thud(90, 32, d, 0.25)
    sub = np.sin(2 * np.pi * 42 * t_(d)) * env(int(SR * d), 0.003, 0.3) * 0.6
    cr = crunch(0.7, 2200) * env(int(SR * 0.7), 0.002, 0.2) * 0.7
    return mix(boom, sub, cr)


def crash():
    parts = [thud(140, 50, 0.3, 0.07), crunch(0.3, 2600) * env(int(SR * 0.3), 0.001, 0.06) * 0.6]
    for _ in range(10):
        parts.append(at(tink(rng.uniform(2200, 5500), rng.uniform(0.08, 0.16), rng.uniform(0.2, 0.45)), rng.uniform(0.01, 0.3)))
    return mix(*parts)


def dizzy():
    parts = []
    t0 = 0.0
    for i in range(6):
        f0, f1 = (2400, 3400) if i % 2 == 0 else (3300, 2500)
        c = sweep(f0, f1, 0.09) * env(int(SR * 0.09), 0.004, 0.04)
        parts.append(at(c * 0.8, t0)); parts.append(at(c * 0.5, t0 + 0.1))
        t0 += 0.2
    return mix(*parts)


def crack():
    snap = highpass(noise(0.02), 2500) * env(int(SR * 0.02), 0.0002, 0.006)
    body = reson(highpass(noise(0.2), 900), 1800, 8) * env(int(SR * 0.2), 0.001, 0.05)
    return mix(snap * 1.2, norm(body) * 0.5, at(tink(3100, 0.15, 0.3), 0.01))


def burst():
    d = 1.2
    boom = thud(120, 40, 0.6, 0.18)
    puff = lowpass(noise(d), 1500) * env(int(SR * d), 0.005, 0.3) * 0.7
    cr = crunch(d, 2400) * env(int(SR * d), 0.003, 0.35) * 0.6
    parts = [boom, puff, cr]
    for _ in range(8):
        parts.append(at(tink(rng.uniform(2500, 5000), 0.1, 0.25), rng.uniform(0.05, 0.6)))
    return mix(*parts)


def flee():
    d = 0.7
    tt = t_(d)
    sq = voice(900, 0.25, 14, ((1800, 6), (3000, 8)))
    rollp = crunch(d, 3200) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * tt) ** 2) * np.exp(-tt / 0.5) * 0.5
    return mix(sq * 0.8, rollp)


def intro_roll():
    d = 2.2
    tt = t_(d)
    k = (tt / d) ** 1.5
    rum = mix(lowpass(noise(d), 90) * (1 - tt / d), lowpass(noise(d), 230) * (tt / d))
    rum = rum / (np.max(np.abs(rum)) + 1e-9)
    puls = 0.6 + 0.4 * np.sin(2 * np.pi * np.cumsum(3 + 5 * tt / d) / SR) ** 2
    cr = crunch(d, 1500 + 1200 * 0.5)
    y = (rum * 0.9 + cr * 0.45) * puls * (0.15 + 0.85 * k)
    return y


def breath():
    d = 0.9
    tt = t_(d)
    h = highpass(noise(d), 2500) * np.minimum(1, tt / 0.15) * np.exp(-np.maximum(0, tt - 0.4) / 0.2)
    sp = []
    for _ in range(6):
        sp.append(at(tink(rng.uniform(3500, 6500), 0.06, 0.15), rng.uniform(0.1, 0.7)))
    return mix(h, *sp)


ALL = (('laugh', laugh), ('roar', roar), ('spit', spit), ('splat', splat), ('roll', roll), ('land', land),
       ('slam', slam), ('crash', crash), ('dizzy', dizzy), ('crack', crack), ('burst', burst), ('flee', flee),
       ('intro_roll', intro_roll), ('breath', breath))

if __name__ == '__main__':
    only = set(sys.argv[1:])
    print('Sonidos de la Gran Bola de Nieve:')
    for name, fn in ALL:
        if only and name not in only: continue
        save(name, fn(), drive=1.4 if name == 'roll' else 1.8)
