#!/usr/bin/env python3
# tools/sounds/tifon.py — sonidos de TIFÓN, el Soplón Supremo (jefe secreto de la fortaleza; docs/design/tifon.md), con el
# tramo más fuerte de 100 ms a -12 dBFS (como los del escorpión). Todos salen de ruido filtrado y senos: viento, rayo,
# granizo, metal. Ronda 1: previas, nadie los ha escuchado.
#   bosses/tifon/roar.wav       el rugido de tormenta: aullido de viento + trueno que rueda (entrada, cambio de fase)
#   bosses/tifon/warn.wav       el aviso del soplo (1 s): coge aire, un silbido que sube
#   bosses/tifon/blow.wav       el soplo (2,6 s): ventarrón grave que empuja, con ráfagas
#   bosses/tifon/inhale.wav     aspira (2 s): succión que sube de tono, como un desagüe al revés
#   bosses/tifon/gulp.wav       se traga la bomba: un trago hueco
#   bosses/tifon/boom.wav       la bomba revienta DENTRO: explosión ahogada + la nube que se deshincha
#   bosses/tifon/cough.wav      tose lo que no era una bomba encendida (la caja / la bomba apagada sale disparada)
#   bosses/tifon/charge.wav     carga el rayo (1 s): chisporroteo que crece
#   bosses/tifon/thunder.wav    cae el rayo: chasquido seco + retumbo
#   bosses/tifon/chain.wav      el rayo salta de chimenea en chimenea (fase 2): zumbido eléctrico corto
#   bosses/tifon/hail.wav       una piedra de granizo contra las tejas
#   bosses/tifon/vane.wav       la veleta gira (avisa del cambio de viento): chirrido de metal oxidado
#   bosses/tifon/spin.wav       gira sobre sí mismo (fase 2): remolino que pasa
#   bosses/tifon/dizzy.wav      aturdido en el tejado: la nube se deshincha con un silbido que baja
#
#   python3 tools/sounds/tifon.py            → previas en FlappyMonster_pruebas/tifon/sonidos/
#   python3 tools/sounds/tifon.py --apply    → assets/sounds/bosses/tifon/
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jungle_enemies as JE
from jungle_enemies import SR, t_, band, low, noise, env, place, thud, click
from scorpion import write, res

PREV = '/home/mtvemo/FlappyMonster_pruebas/tifon/sonidos'
rng = np.random.default_rng(1104)


def fade(x, a=0.02, b=0.05):
    n, m = int(SR * a), int(SR * b)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n); x[-m:] *= np.linspace(1, 0, m)
    return x


def sweep_band(x, f0, f1, q=0.35, steps=40):
    """ruido por un filtro de banda que se mueve de f0 a f1 (a trozos que se solapan): el viento que silba"""
    y = np.zeros(len(x))
    n = len(x)
    seg = n // steps
    win = np.hanning(seg * 2)
    for k in range(steps):
        i = max(0, k * seg - seg // 2)
        j = min(n, i + seg * 2)
        f = f0 * (f1 / f0) ** (k / max(1, steps - 1))
        part = band(x[i:j], max(30, f * (1 - q)), min(19000, f * (1 + q)))
        y[i:j] += part * win[:j - i]
    return y


def gusts(d, rate=1.3, depth=0.5, seed=0):
    """el vaivén de las ráfagas: una envolvente lenta y algo irregular"""
    tt = t_(d)
    r = np.random.default_rng(seed)
    ph = r.uniform(0, 6.28, 3)
    g = 1 + depth * (0.6 * np.sin(2 * np.pi * rate * tt + ph[0]) + 0.3 * np.sin(2 * np.pi * rate * 2.3 * tt + ph[1]) +
                     0.2 * np.sin(2 * np.pi * rate * 0.45 * tt + ph[2]))
    return np.maximum(0.1, g)


def rumble(d, f=55, tau=0.8):
    """retumbo de trueno: ruido muy grave que rueda (golpes sueltos que se apagan)"""
    y = low(noise(d), 160) * 2.5
    tt = t_(d)
    rolls = np.zeros(len(tt))
    for k in range(7):
        at = rng.uniform(0, d * 0.6)
        rolls += np.exp(-np.maximum(0, tt - at) / rng.uniform(0.08, 0.25)) * (tt >= at) * rng.uniform(0.4, 1)
    return y * (0.35 + rolls) * np.exp(-tt / tau) + res(f, d, tau * 0.6) * 0.3


def crack():
    """el chasquido del rayo: ruido brillante, muy corto, con un rebote"""
    return place(0.12, [(0, band(noise(0.06), 1500, 12000) * env(0.06, 0.0002, 0.012)),
                        (0.018, band(noise(0.05), 900, 7000) * env(0.05, 0.0002, 0.015) * 0.7),
                        (0, click(3200, 0.02, 0.004) * 0.6)])


def sounds():
    out = {}
    # ── el rugido: aullido de viento (silbido que sube y baja) sobre un trueno que rueda
    d = 2.2
    tt = t_(d)
    howl = sweep_band(noise(d), 280, 900, q=0.18) * np.interp(tt, [0, 0.5, 1.4, d], [0, 1, 0.8, 0]) * 2.2
    howl2 = sweep_band(noise(d), 180, 420, q=0.2) * np.interp(tt, [0, 0.4, 1.6, d], [0, 0.9, 0.6, 0]) * 1.6
    out['roar'] = fade(place(d, [(0, howl), (0, howl2), (0.05, crack() * 0.8), (0.08, rumble(2.1) * 0.9)]))
    # ── el aviso: coge aire (silbido que sube, 1 s) y se corta justo antes del soplo
    d = 1.0
    tt = t_(d)
    out['warn'] = fade(sweep_band(noise(d), 400, 2200, q=0.25) * np.interp(tt, [0, 0.8, 0.96, d], [0.1, 1, 1, 0]) * 1.8 +
                       band(noise(d), 150, 600) * np.interp(tt, [0, 0.9, d], [0, 0.5, 0]), 0.01, 0.03)
    # ── el soplo: ventarrón grave con ráfagas (2,6 s)
    d = 2.6
    tt = t_(d)
    body = (band(noise(d), 80, 700) * 1.4 + band(noise(d), 700, 3000) * 0.45) * gusts(d, 1.6, 0.45, 2)
    whistle = sweep_band(noise(d), 900, 650, q=0.08) * 0.6 * gusts(d, 0.9, 0.6, 3)
    out['blow'] = fade((body + whistle) * np.interp(tt, [0, 0.12, d - 0.5, d], [0, 1, 0.85, 0]), 0.01, 0.2)
    # ── aspira: succión que sube de tono (2 s) y acaba en un sorbo
    d = 2.0
    tt = t_(d)
    suck = sweep_band(noise(d), 250, 1600, q=0.3) * np.interp(tt, [0, 0.3, 1.8, d], [0.2, 0.7, 1, 0]) * 1.8
    low_ = band(noise(d), 60, 300) * np.interp(tt, [0, 1.0, d], [0.8, 0.4, 0]) * 0.9
    out['inhale'] = fade(suck + low_, 0.08, 0.06)
    # ── el trago: dos golpes huecos que bajan
    out['gulp'] = place(0.45, [(0, thud(260, 90, 0.25, 0.07)), (0.11, thud(180, 60, 0.3, 0.09) * 0.9),
                               (0, band(noise(0.15), 300, 1200) * env(0.15, 0.005, 0.04) * 0.4)])
    # ── la bomba revienta dentro: explosión ahogada (pasa por la nube: sin agudos) + se deshincha
    d = 1.4
    tt = t_(d)
    muffled = low(noise(0.9), 500) * env(0.9, 0.002, 0.22) * 3 + thud(110, 35, 0.9, 0.3) * 1.2
    deflate = sweep_band(noise(0.8), 900, 250, q=0.25) * np.interp(t_(0.8), [0, 0.1, 0.8], [0, 1, 0]) * 1.4
    out['boom'] = fade(place(d, [(0, muffled), (0.35, deflate)]), 0.002, 0.1)
    # ── tose: tres golpes de aire roncos
    tos = lambda: place(0.16, [(0, band(noise(0.16), 250, 2200) * env(0.16, 0.004, 0.05) * 1.6), (0, thud(200, 120, 0.12, 0.04) * 0.6)])
    out['cough'] = place(0.7, [(0, tos()), (0.17, tos() * 0.85), (0.36, tos() * 1.1), (0.36, band(noise(0.3), 600, 4000) * env(0.3, 0.003, 0.06) * 0.6)])
    # ── carga el rayo: chispas cada vez más seguidas sobre un zumbido que sube (1 s)
    d = 1.0
    tt = t_(d)
    hum = (np.sign(np.sin(2 * np.pi * (60 + 60 * tt) * tt)) * 0.15 + band(noise(d), 2000, 7000) * 0.2) * np.interp(tt, [0, d], [0.2, 1])
    sparks = []
    at = 0.0
    while at < d - 0.03:
        sparks.append((at, band(noise(0.015), 3000, 12000) * env(0.015, 0.0002, 0.003) * rng.uniform(0.5, 1.2)))
        at += 0.09 * (1 - at / d) + 0.012
    out['charge'] = fade(place(d, [(0, hum)] + sparks), 0.01, 0.02)
    # ── cae el rayo: chasquido + retumbo
    out['thunder'] = fade(place(1.6, [(0, crack() * 1.3), (0.01, rumble(1.55, 48, 0.5) * 1.1)]), 0.0005, 0.15)
    # ── el rayo encadenado: zumbido eléctrico que salta (0,35 s)
    d = 0.35
    tt = t_(d)
    zap = np.sign(np.sin(2 * np.pi * 120 * tt)) * band(noise(d), 1500, 9000) * 0.6 + np.sign(np.sin(2 * np.pi * 240 * tt)) * 0.15
    out['chain'] = fade(zap * np.interp(tt, [0, 0.02, 0.25, d], [0, 1, 0.7, 0]) * (0.6 + 0.4 * (np.sin(2 * np.pi * 23 * tt) > 0)), 0.002, 0.04)
    # ── granizo contra una teja: tic de hielo + teja
    out['hail'] = place(0.18, [(0, click(4200, 0.02, 0.004)), (0.002, click(1500, 0.05, 0.012) * 0.6),
                               (0.03, click(5200, 0.012, 0.003) * 0.3)])
    # ── la veleta gira: chirrido de metal (dos tirones de fricción)
    def squeak(d, f0, f1):
        tt = t_(d)
        f = f0 + (f1 - f0) * tt / d
        stick = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 34 * tt))                                 # (agarra y suelta)
        tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(2 * np.pi * 2.01 * np.cumsum(f) / SR)
        return tone * stick * np.interp(tt, [0, 0.03, d - 0.05, d], [0, 1, 0.8, 0])
    out['vane'] = place(0.62, [(0, squeak(0.24, 1500, 1800) * 0.5), (0.3, squeak(0.3, 1700, 1300) * 0.6),
                               (0, band(noise(0.6), 2000, 6000) * 0.08)])
    # ── gira: remolino que pasa (sube y baja; 0,9 s)
    d = 0.9
    tt = t_(d)
    out['spin'] = fade(sweep_band(noise(d), 300, 1400, q=0.3) * np.sin(np.pi * tt / d) ** 2 * 1.8 +
                       band(noise(d), 80, 300) * np.sin(np.pi * tt / d) * 0.8, 0.02, 0.05)
    # ── aturdido: se deshincha con un silbido que baja y un tambaleo
    d = 1.1
    tt = t_(d)
    wob = 1 + 0.08 * np.sin(2 * np.pi * 6 * tt)
    f = 900 * (0.35 ** (tt / d)) * wob
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.35
    out['dizzy'] = fade(tone * np.interp(tt, [0, 0.05, d], [0, 1, 0]) + sweep_band(noise(d), 1200, 300, q=0.3) * np.interp(tt, [0, 0.05, d], [0, 1, 0]) * 1.2, 0.01, 0.1)
    return out


if __name__ == '__main__':
    dest = 'assets/sounds/bosses/tifon' if '--apply' in sys.argv else PREV
    for name, x in sounds().items():
        write(os.path.join(dest, name + '.wav'), x, {'hail': -15, 'chain': -14}.get(name, -12))
