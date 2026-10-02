#!/usr/bin/env python3
# tools/sounds/megagummy.py
# Sonidos del jefe REY GUMMY (assets/sounds/bosses/megagummy/*.wav):
#   hop        saltito persiguiendo: "boing" de gelatina (tono que sube y tiembla)
#   charge     se agacha para el panzazo: gelatina que se estira (tono que baja, temblor)
#   jump       despega hacia lo alto: "fiuuu" que sube
#   flop       el PANZAZO: golpe grave + chapoteo de gelatina + temblor
#   wave       la ola de gelatina sale corriendo: siseo blando que se aleja
#   fanfare    llama a su guardia: trompetilla de 3 notas (la-la-laaa)
#   laugh      risa de rey gordo ("jo jo jo", grave)
#   hurt       golpe en la barriga: "uf" blando con rebote
#   split      se divide: estirón de gelatina + "plop" triple
#   pop        un trozo revienta: plop + confeti (crepitar)
#   crown      la corona sale volando / cae: tintineo dorado
#   land       la entrada: cae del cielo (golpe grave y gelatina)
# Desde la raíz del repo:  python3 tools/sounds/megagummy.py [nombres...]
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from megacrabby import SR, t_, env, lowpass, highpass, noise, mix, at, reson, sweep   # noqa: E402
from snowboss import save as _save, norm, voice, tink                                # noqa: E402
import snowboss                                                                       # noqa: E402

OUT = 'assets/sounds/bosses/megagummy'
rng = np.random.default_rng(4242)


def save(name, x, drive=1.8):
    snowboss.OUT = OUT
    _save(name, x, drive=drive)


def jelly(f0, f1, d, wob=11.0, depth=0.12):
    """Tono de gelatina: barrido con temblor (vibrato rápido que se apaga)."""
    tt = t_(d)
    f = (f0 + (f1 - f0) * (tt / d)) * (1 + depth * np.exp(-tt / (d * 0.6)) * np.sin(2 * np.pi * wob * tt))
    ph = np.cumsum(f) / SR
    y = np.sin(2 * np.pi * ph) + 0.35 * np.sin(4 * np.pi * ph) + 0.12 * np.sin(6 * np.pi * ph)
    return y


def hop():
    d = 0.26
    return jelly(170, 330, d, 18, 0.18) * env(int(SR * d), 0.004, 0.08)


def charge():
    d = 0.6
    tt = t_(d)
    y = jelly(260, 110, d, 9, 0.2) * np.minimum(1, tt / 0.1) * np.exp(-np.maximum(0, tt - 0.45) / 0.08)
    return y * 0.8


def jump():
    d = 0.4
    tt = t_(d)
    w = sweep(180, 720, d, 0.6) * env(len(tt), 0.01, 0.2)
    air = highpass(noise(d), 1500) * np.minimum(1, tt / 0.05) * np.exp(-tt / 0.15) * 0.25
    return mix(w, air)


def flop():
    d = 1.2
    tt = t_(d)
    boom = sweep(90, 34, d, 0.4) * env(len(tt), 0.002, 0.35)
    slap = lowpass(highpass(noise(0.18), 200), 2400) * env(int(SR * 0.18), 0.001, 0.05) * 0.9
    wob = jelly(120, 80, 0.9, 7, 0.25) * env(int(SR * 0.9), 0.03, 0.3) * 0.5
    splash = lowpass(highpass(noise(0.5), 600), 3000) * env(int(SR * 0.5), 0.005, 0.12) * 0.35
    return mix(boom * 1.2, slap, at(wob, 0.05), at(splash, 0.02))


def wave():
    d = 0.9
    tt = t_(d)
    sw = lowpass(noise(d), 900) * np.minimum(1, tt / 0.04) * np.exp(-tt / 0.35)
    w = jelly(200, 140, d, 13, 0.25) * env(len(tt), 0.01, 0.25) * 0.4
    return mix(norm(sw), w)


def brass(f, d):
    """Trompetilla chiptune: cuadrada con un poco de ataque de tono y filtro."""
    tt = t_(d)
    ff = f * (1 - 0.06 * np.exp(-tt / 0.03)) * (1 + 0.012 * np.sin(2 * np.pi * 6 * tt))
    ph = np.cumsum(ff) / SR
    sq = np.sign(np.sin(2 * np.pi * ph)) * 0.6 + 0.4 * (2 * (ph % 1) - 1)
    y = lowpass(sq, 2600)
    return y * np.minimum(1, tt / 0.015) * np.exp(-np.maximum(0, tt - d * 0.7) / 0.06)


def fanfare():
    notes = ((523.25, 0.0, 0.14), (523.25, 0.16, 0.12), (659.25, 0.3, 0.12), (783.99, 0.44, 0.55))
    parts = [at(brass(f, d), t0) for f, t0, d in notes]
    parts += [at(brass(f / 2, d) * 0.45, t0) for f, t0, d in notes]
    return mix(*parts)


def laugh():
    parts = []
    for i, t0 in enumerate((0.0, 0.24, 0.48)):
        v = voice(150 - i * 8, 0.2, vib=7, formants=((600, 5), (1000, 6)))
        parts.append(at(v, t0))
    return mix(*parts)


def hurt():
    v = voice(240, 0.22, vib=12, formants=((700, 5), (1150, 6)))
    tt = t_(0.22)
    v = v * (1 - 0.4 * tt / 0.22)
    thump = sweep(140, 60, 0.15, 0.5) * env(int(SR * 0.15), 0.001, 0.05)
    return mix(v, thump, at(jelly(300, 200, 0.2, 20, 0.2) * env(int(SR * 0.2), 0.003, 0.06) * 0.5, 0.1))


def plop(f, g=1.0):
    d = 0.12
    return sweep(f, f * 2.6, d, 0.5) * env(int(SR * d), 0.001, 0.035) * g


def split():
    d = 0.8
    stretch = jelly(140, 420, d, 6, 0.3) * env(int(SR * d), 0.05, 0.4) * 0.6
    return mix(stretch, at(plop(300), 0.62), at(plop(380), 0.7), at(plop(460), 0.78))


def pop():
    sp = [at(tink(rng.uniform(2500, 6000), 0.05, 0.25), rng.uniform(0.05, 0.4)) for _ in range(10)]
    crackle = highpass(noise(0.4), 3000) * env(int(SR * 0.4), 0.002, 0.08) * 0.3
    return mix(plop(260, 1.2), at(plop(520, 0.6), 0.03), crackle, *sp)


def crown():
    parts = [at(tink(f, 0.35, 0.6), i * 0.06) for i, f in enumerate((1568, 2093, 2637, 3136))]
    return mix(*parts)


def land():
    d = 1.3
    tt = t_(d)
    boom = sweep(70, 28, d, 0.4) * env(len(tt), 0.002, 0.45)
    slap = lowpass(highpass(noise(0.25), 150), 2000) * env(int(SR * 0.25), 0.001, 0.07)
    wob = jelly(110, 70, 1.0, 6, 0.3) * env(int(SR * 1.0), 0.03, 0.35) * 0.5
    return mix(boom * 1.3, slap, at(wob, 0.06))


ALL = (('hop', hop), ('charge', charge), ('jump', jump), ('flop', flop), ('wave', wave), ('fanfare', fanfare),
       ('laugh', laugh), ('hurt', hurt), ('split', split), ('pop', pop), ('crown', crown), ('land', land))

if __name__ == '__main__':
    only = set(sys.argv[1:])
    print('Sonidos del Rey Gummy:')
    for name, fn in ALL:
        if only and name not in only: continue
        save(name, fn(), drive=1.4 if name in ('fanfare', 'crown') else 1.8)
