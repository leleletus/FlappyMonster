#!/usr/bin/env python3
# tools/sounds/metrogolem.py
# Sonidos del jefe GÓLEM METRÓNOMO (assets/sounds/bosses/metrogolem/*.wav):
#   wake    la entrada: piedra que despierta (rumor grave que sube) + el «clin» de la lámpara
#   wind    carga el golpe: piedra que cruje y un zumbido que sube (dura lo que los 3 beeps)
#   slam    el GOLPE contra el suelo: bombo de piedra, cascotes y un eco de cristal
#   wave    la onda de cristal que sale por el suelo: siseo brillante que se aleja
#   hurt    golpe en la lámpara: «clonc» de piedra hueca + cristal que se raja
#   rise    se levanta y vuelve a flotar: aire que sube y un tic-tac
# Desde la raíz del repo:  python3 tools/sounds/metrogolem.py [nombres...]
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, mix, at, reson, sweep   # noqa: E402
from snowboss import save as _save, norm, tink                                       # noqa: E402
import snowboss                                                                       # noqa: E402

OUT = 'assets/sounds/bosses/metrogolem'


def save(name, x, drive=1.8):
    os.makedirs(OUT, exist_ok=True)
    snowboss.OUT = OUT
    _save(name, x, drive=drive)


def rumble(d, f0=45, f1=70):
    tt = t_(d)
    return lowpass(noise(d), 260) * 0.7 + sweep(f0, f1, d, 0.5) * 0.6


def clink(f=1760, d=0.5):
    return tink(f, d, 1.0)


def wake():
    d = 2.0
    tt = t_(d)
    r = rumble(d, 38, 90) * np.minimum(1, tt / 0.6) * np.exp(-np.maximum(0, tt - 1.4) / 0.25)
    return mix(r, at(clink(1568, 0.7) * 0.5, 1.45), at(clink(2093, 0.6) * 0.35, 1.55))


def wind():
    d = 1.2
    tt = t_(d)
    crack = highpass(noise(d), 1800) * (np.sin(2 * np.pi * 9 * tt) > 0.6) * 0.25
    hum = sweep(110, 330, d, 0.5) * np.minimum(1, tt / 0.2) * np.exp(-np.maximum(0, tt - 1.05) / 0.05) * 0.5
    return mix(crack, hum, rumble(d) * 0.35 * env(len(tt), 0.05, 0.6))


def slam():
    d = 1.4
    tt = t_(d)
    boom = sweep(85, 30, d, 0.35) * env(len(tt), 0.002, 0.4)
    debris = lowpass(highpass(noise(0.6), 300), 3500) * env(int(SR * 0.6), 0.001, 0.15) * 0.8
    glass = mix(clink(2637, 0.9) * 0.25, at(clink(3136, 0.8) * 0.18, 0.06))
    return mix(boom * 1.3, debris, at(glass, 0.03))


def wave():
    d = 0.8
    tt = t_(d)
    s = highpass(noise(d), 2500) * np.minimum(1, tt / 0.03) * np.exp(-tt / 0.3)
    w = sweep(900, 500, d, 0.3) * env(len(tt), 0.01, 0.25) * 0.3
    return mix(norm(s) * 0.6, w)


def hurt():
    d = 0.7
    tt = t_(d)
    clonk = reson(noise(d) * env(len(tt), 0.001, 0.03), 220, 30)
    body = sweep(180, 120, d, 0.4) * env(len(tt), 0.002, 0.12)
    crack = highpass(noise(0.25), 2500) * env(int(SR * 0.25), 0.001, 0.05) * 0.6
    return mix(norm(clonk) * 0.8, body, at(crack, 0.02), at(clink(2349, 0.4) * 0.3, 0.05))


def rise():
    d = 0.9
    tt = t_(d)
    air = lowpass(noise(d), 1200) * np.minimum(1, tt / 0.3) * np.exp(-np.maximum(0, tt - 0.6) / 0.1) * 0.6
    tick = mix(at(clink(1318, 0.15) * 0.4, 0.2), at(clink(1046, 0.15) * 0.4, 0.6))
    return mix(air, tick)


ALL = (('wake', wake), ('wind', wind), ('slam', slam), ('wave', wave), ('hurt', hurt), ('rise', rise))

if __name__ == '__main__':
    only = set(sys.argv[1:])
    print('Sonidos del Gólem Metrónomo:')
    for name, fn in ALL:
        if only and name not in only: continue
        save(name, fn())
