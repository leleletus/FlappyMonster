#!/usr/bin/env python3
# tools/sounds/snowball.py — sonidos de la BOLA DE NIEVE (`snowball`, enemigo de datos), con el tramo más fuerte de
# 100 ms a -12 dBFS (como tools/sounds/jungle_enemies.py; el volumen fino va en Sound.lua):
#   enemies/snowball/windup.wav   se aplasta para lanzarse: nieve que se aprieta (crujidos cortos que aceleran)
#   enemies/snowball/launch.wav   sale disparada: un "fffump" de nieve + el siseo de rodar que se aleja
#   enemies/snowball/shove.wav    empuja a alguien: golpe blando y grave de nieve ("pomf") y una risita aguda
#   enemies/snowball/bonk.wav     se estrella contra una pared: golpe sordo y polvo de nieve que cae
# Nadie los ha escuchado aún (verificados solo por números).
# Desde la raíz del repo:  python3 tools/sounds/snowball.py
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jungle_enemies as J                    # (las mismas herramientas: save, band, low, env, place, thud…)

SR = J.SR
J.rng = np.random.default_rng(2910)
t_, band, low, noise, env, place, thud = J.t_, J.band, J.low, J.noise, J.env, J.place, J.thud


def crunch(d=0.05, lo=1500, hi=7000, tau=0.012):
    return band(noise(d), lo, hi) * env(d, 0.002, tau)


def windup():
    parts, at = [], 0.0
    for i in range(7):                                          # crujidos de nieve apretada, cada vez más juntos
        parts.append((at, crunch(0.05, 1200 + 150 * i, 6000 + 300 * i, 0.010) * (0.6 + 0.07 * i)))
        at += 0.075 - 0.007 * i
    body = low(noise(0.5), 500) * env(0.5, 0.25, 0.3) * 0.35    # (y un fondo grave que crece)
    return place(0.52, parts + [(0.0, body)])


def launch():
    d = 0.55
    pomf = thud(160, 70, 0.18, 0.06) * 0.9 + low(noise(0.18), 900) * env(0.18, 0.003, 0.04) * 0.8
    tt = t_(d)
    hiss = band(noise(d), 2500, 9000) * np.exp(-tt / 0.22) * np.minimum(1, tt / 0.03) * 0.5
    rumble = low(noise(d), 260) * np.exp(-tt / 0.3) * 0.5
    return place(d, [(0.0, pomf), (0.02, hiss), (0.0, rumble)])


def shove():
    pomf = thud(140, 55, 0.22, 0.07) + low(noise(0.22), 700) * env(0.22, 0.002, 0.05) * 1.2
    puff = band(noise(0.3), 1800, 8000) * env(0.3, 0.01, 0.07) * 0.5
    giggle = []
    for i, f in enumerate([880, 990, 880]):                     # "ji-ji-ji" corto y agudo
        tt = t_(0.06)
        v = np.sin(2 * np.pi * (f + 60 * np.sin(2 * np.pi * 30 * tt)) * tt) * env(0.06, 0.005, 0.025) * 0.35
        giggle.append((0.16 + i * 0.075, v))
    return place(0.45, [(0.0, pomf), (0.0, puff)] + giggle)


def bonk():
    hit = thud(110, 45, 0.3, 0.08) * 1.1
    thump = low(noise(0.12), 600) * env(0.12, 0.001, 0.03)
    dust = band(noise(0.5), 2000, 8000) * env(0.5, 0.05, 0.15) * 0.3
    return place(0.55, [(0.0, hit), (0.0, thump), (0.06, dust)])


if __name__ == '__main__':
    for name, fn in [('windup', windup), ('launch', launch), ('shove', shove), ('bonk', bonk)]:
        J.save('snowball/%s.wav' % name, fn())
