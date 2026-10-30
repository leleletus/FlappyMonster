#!/usr/bin/env python3
# tools/sounds/map_cannon.py
# Sonidos del CAÑÓN del mapa del mundo (src/states/story/StoryMapCannons.lua) → assets/sounds/story/cannon_*.wav,
# a ≈ -12 dBFS como los demás de la historia (save de tools/sounds/story.py):
#   cannon_load    el monstruo cae dentro: "clonc" hueco de metal y un muelle cómico
#   cannon_fuse    la mecha: chisporroteo que sube (0,6 s)
#   cannon_boom    ¡BUM!: golpe grave, estallido y cola de humo
#   cannon_whoosh  el monstruo cruza el aire: soplido que pasa (sube y baja)
#   cannon_land    cae en la otra orilla: golpe sordo y un bote
#   python3 tools/sounds/map_cannon.py [nombres...]
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, mix, at, sweep   # noqa: E402
from story import save                                                          # noqa: E402

rng = np.random.default_rng(1729)


def load():
    # clonc: dos parciales inarmónicos de tubo de hierro, apagados, y un "boing" corto que baja
    tt = t_(0.5)
    tube = (np.sin(2 * np.pi * 210 * tt) + 0.6 * np.sin(2 * np.pi * 534 * tt) + 0.3 * np.sin(2 * np.pi * 1130 * tt)) * np.exp(-tt / 0.09)
    thud = lowpass(noise(0.08), 500) * env(int(SR * 0.08), 0.001, 0.03) * 1.5
    boing = sweep(520, 300, 0.22) * np.exp(-t_(0.22) / 0.1) * (1 + 0.5 * np.sin(2 * np.pi * 28 * t_(0.22))) * 0.35
    return mix(tube, thud, at(boing, 0.05))


def fuse():
    d = 0.6
    tt = t_(d)
    hiss = highpass(noise(d), 2500) * (0.35 + 0.65 * tt / d)
    crackle = np.zeros(len(tt))
    for _ in range(40):                                   # chispazos sueltos
        i = rng.integers(0, len(tt) - 200)
        crackle[i:i + 120] += rng.uniform(0.5, 1.0) * np.exp(-np.arange(120) / 20) * rng.choice([-1, 1])
    return (hiss * 0.5 + highpass(crackle, 1200) * 0.7) * np.clip((d - tt) / 0.03, 0, 1)


def boom():
    d = 1.2
    tb = t_(d)
    body = np.sin(2 * np.pi * np.cumsum(np.linspace(95, 32, len(tb))) / SR) * np.exp(-tb / 0.22) * 1.3
    crack = highpass(noise(0.12), 900) * env(int(SR * 0.12), 0.0005, 0.03) * 1.2
    smoke = lowpass(noise(d), 700) * np.exp(-tb / 0.35) * 0.6
    return mix(body, crack, smoke)


def whoosh():
    d = 0.9
    tt = t_(d)
    shape = np.sin(np.pi * tt / d) ** 2
    air = noise(d)
    # (un barrido de filtro: grave → agudo → grave, como algo que pasa cerca)
    lo, hi = lowpass(air, 600), lowpass(air, 2400)
    k = np.sin(np.pi * tt / d)
    return (lo * (1 - k) + hi * k) * shape


def land():
    tt = t_(0.35)
    thud = np.sin(2 * np.pi * np.cumsum(np.linspace(120, 55, len(tt))) / SR) * np.exp(-tt / 0.07)
    dust = lowpass(noise(0.3), 1500) * env(int(SR * 0.3), 0.002, 0.08) * 0.5
    t2 = t_(0.2)
    bounce = np.sin(2 * np.pi * np.cumsum(np.linspace(150, 90, len(t2))) / SR) * np.exp(-t2 / 0.04) * 0.45
    return mix(thud, dust, at(bounce, 0.17))


ALL = {'cannon_load': load, 'cannon_fuse': fuse, 'cannon_boom': boom, 'cannon_whoosh': whoosh, 'cannon_land': land}

if __name__ == '__main__':
    for name in (sys.argv[1:] or list(ALL)):
        save(name, np.asarray(ALL[name](), dtype=float))
