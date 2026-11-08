#!/usr/bin/env python3
# tools/sounds/netcopter.py — sonidos del Redcóptero (Net-Copter; docs/bosses/netcopter.md, plan 5c), con el tramo más
# fuerte de 100 ms a -12 dBFS (los cortos y agudos, algo más bajos). Ruido filtrado y senos, estilo retro. Ronda 1:
# previas, nadie los ha escuchado.
#   bosses/netcopter/net_fire.wav     sale la red del cañón: «fump» de aire comprimido + silbido que se abre
#   bosses/netcopter/net_snare.wav    la red envuelve al monstruo: tela que se cierra + hebras que restallan
#   bosses/netcopter/net_snag.wav     la red se engancha en un sólido y se deshace: tirón + hilos que se sueltan
#   bosses/netcopter/pedal_squeak.wav chirrido corto de un pedal sin aceite (se limita en el jefe)
#   bosses/netcopter/prop_whir.wav    un tic de hélice: zumbido grave de palas que pasan (se limita en el jefe)
#   bosses/netcopter/balloon_pop.wav  el globo revienta (fase 2): estallido + chorro de aire que se escapa
#   bosses/netcopter/claw_servo.wav   la garra se prepara: motorcito que sube + trinquete
#   bosses/netcopter/bomb_lob.wav     la bomba lanzada en arco: golpe seco + silbido que sube y baja
#   bosses/netcopter/leak_hiss.wav    fuga de aire del globo roto (fase 2): siseo corto
#   bosses/netcopter/claw_open.wav    la garra se abre (aviso): muelle que se suelta + clac de los dedos (ronda 2)
#   bosses/netcopter/claw_snap.wav    la garra se cierra de golpe al final del barrido: chasquido de hierro (ronda 2)
#
#   python3 tools/sounds/netcopter.py            → previas en FlappyMonster_pruebas/netcopter/sonidos/
#   python3 tools/sounds/netcopter.py --apply    → assets/sounds/bosses/netcopter/
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jungle_enemies as JE
from jungle_enemies import SR, t_, band, low, noise, env, place, thud, click
from scorpion import write, res

PREV = '/home/mtvemo/FlappyMonster_pruebas/netcopter/sonidos'
JE.rng = np.random.default_rng(2205)
rng = np.random.default_rng(2205)


def fade(x, a=0.004, b=0.03):
    n, m = int(SR * a), int(SR * b)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n); x[-m:] *= np.linspace(1, 0, m)
    return x


def sweep_band(x, f0, f1, q=0.3, steps=24):
    """ruido por un filtro de banda que se mueve de f0 a f1 (a trozos que se solapan)"""
    y = np.zeros(len(x))
    n = len(x)
    seg = max(2, n // steps)
    win = np.hanning(seg * 2)
    for k in range(steps):
        i = max(0, k * seg - seg // 2)
        j = min(n, i + seg * 2)
        f = f0 * (f1 / f0) ** (k / max(1, steps - 1))
        y[i:j] += band(x[i:j], max(30, f * (1 - q)), min(19000, f * (1 + q))) * win[:j - i]
    return y


def tone(f0, f1, d, harm=0.4):
    tt = t_(d)
    ph = 2 * np.pi * np.cumsum(f0 + (f1 - f0) * tt / d) / SR
    return np.sin(ph) + harm * np.sin(2 * ph)


def sounds():
    out = {}
    # ── la red sale del cañón: golpe de aire + silbido que se abre (0,4 s)
    d = 0.4
    tt = t_(d)
    out['net_fire'] = fade(place(d, [(0, thud(220, 80, 0.2, 0.05) * 0.9),
                                     (0, band(noise(0.12), 500, 3500) * env(0.12, 0.002, 0.03) * 1.2),
                                     (0.04, sweep_band(noise(0.34), 500, 2600, q=0.3) * np.interp(t_(0.34), [0, 0.06, 0.34], [0, 1, 0]) * 1.1)]))
    # ── la red envuelve: tela que se cierra (ruido que baja) + tres restallidos de hebra (0,55 s)
    d = 0.55
    cloth = sweep_band(noise(d), 2400, 500, q=0.35) * np.interp(t_(d), [0, 0.04, 0.35, d], [0, 1, 0.5, 0]) * 1.3
    strands = [(a, click(f, 0.02, 0.005) * g) for a, f, g in ((0.02, 3200, 0.8), (0.11, 2600, 0.6), (0.2, 3600, 0.5))]
    out['net_snare'] = fade(place(d, [(0, cloth), (0, thud(150, 70, 0.15, 0.04) * 0.6)] + strands))
    # ── la red se engancha y se deshace: tirón seco y hilos que se sueltan, cada vez más flojos (0,6 s)
    d = 0.6
    parts = [(0, click(900, 0.04, 0.012) * 1.0), (0, thud(180, 90, 0.1, 0.03) * 0.7)]
    at = 0.05
    for k in range(6):
        parts.append((at, band(noise(0.03), 1800, 7000) * env(0.03, 0.0005, 0.007) * (0.7 - 0.1 * k)))
        at += 0.045 + 0.02 * k
    out['net_snag'] = fade(place(d, parts))
    # ── chirrido de pedal: dos tirones de fricción agudos (0,16 s)
    d = 0.16
    tt = t_(d)
    stick = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 38 * tt))
    out['pedal_squeak'] = fade(tone(1900, 2300, d, 0.35) * stick * np.interp(tt, [0, 0.02, 0.1, d], [0, 1, 0.8, 0]) +
                               band(noise(d), 3000, 7000) * 0.05, 0.003, 0.03)
    # ── tic de hélice: palas que pasan (0,22 s)
    d = 0.22
    tt = t_(d)
    blades = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 36 * tt))
    out['prop_whir'] = fade((band(noise(d), 120, 900) * 1.3 + tone(95, 85, d, 0.6) * 0.5) * blades *
                            np.interp(tt, [0, 0.03, 0.14, d], [0, 1, 0.8, 0]), 0.006, 0.05)
    # ── el globo revienta: estallido seco + chorro de aire que baja (0,9 s)
    d = 0.9
    tt = t_(d)
    bang = band(noise(0.3), 300, 9000) * env(0.3, 0.0003, 0.02) * 2.0 + thud(160, 50, 0.3, 0.08) * 1.1
    gush = sweep_band(noise(0.8), 3000, 400, q=0.3) * np.interp(t_(0.8), [0, 0.05, 0.8], [0, 1, 0]) * 1.0
    out['balloon_pop'] = fade(place(d, [(0, bang), (0.03, gush)]), 0.0005, 0.1)
    # ── servo de la garra: motorcito que sube y trinquete (0,6 s)
    d = 0.6
    tt = t_(d)
    motor = np.sign(np.sin(2 * np.pi * np.cumsum(180 + 420 * tt / d) / SR)) * 0.25 + tone(180, 600, d, 0.3) * 0.4
    ticks = [(a, click(2000, 0.014, 0.003) * 0.7) for a in np.arange(0.05, d - 0.05, 0.075)]
    out['claw_servo'] = fade(place(d, [(0, motor * np.interp(tt, [0, 0.1, d - 0.08, d], [0, 1, 1, 0]))] + ticks), 0.01, 0.06)
    # ── la bomba lanzada: golpe seco del lanzador + silbido que sube y baja (0,5 s)
    d = 0.5
    tt = t_(d)
    whistle = tone(500, 900, d, 0.2) * np.interp(tt, [0, 0.15, d], [0, 1, 0]) * 0.35
    out['bomb_lob'] = fade(place(d, [(0, thud(240, 70, 0.18, 0.045) * 1.0), (0, click(1400, 0.03, 0.008) * 0.6),
                                     (0.04, whistle), (0.02, band(noise(0.3), 800, 3000) * env(0.3, 0.01, 0.08) * 0.35)]))
    # ── fuga de aire: siseo corto con un vaivén (0,5 s)
    d = 0.5
    tt = t_(d)
    out['leak_hiss'] = fade(sweep_band(noise(d), 4200, 2800, q=0.35) * np.interp(tt, [0, 0.06, 0.3, d], [0, 1, 0.7, 0]) *
                            (0.8 + 0.2 * np.sin(2 * np.pi * 9 * tt)) * 1.2, 0.02, 0.1)
    # (ronda 2, al final para no cambiar el azar de los de arriba)
    # ── la garra se abre: trinquete que se suelta, muelle que baja y el clac de los dedos al llegar (0,3 s)
    d = 0.3
    spring = tone(1300, 520, 0.18, 0.5) * np.interp(t_(0.18), [0, 0.02, 0.18], [0, 1, 0]) * 0.35
    out['claw_open'] = fade(place(d, [(0, click(2400, 0.012, 0.003) * 0.6), (0.015, spring),
                                      (0.02, band(noise(0.14), 1500, 5000) * env(0.14, 0.004, 0.05) * 0.4),
                                      (0.17, click(1700, 0.03, 0.007) * 0.9), (0.17, thud(260, 120, 0.08, 0.02) * 0.5)]))
    # ── la garra se cierra de golpe: dos dedos de hierro que chocan + golpe seco (0,35 s)
    d = 0.35
    out['claw_snap'] = fade(place(d, [(0, click(3000, 0.02, 0.004) * 1.0), (0.012, click(2200, 0.03, 0.006) * 0.9),
                                      (0, thud(300, 90, 0.16, 0.04) * 0.9),
                                      (0.01, band(noise(0.22), 2000, 8000) * env(0.22, 0.001, 0.05) * 0.5)]))
    return out


LEVELS = {'pedal_squeak': -15, 'prop_whir': -14, 'leak_hiss': -15, 'net_snag': -14}

if __name__ == '__main__':
    dest = 'assets/sounds/bosses/netcopter' if '--apply' in sys.argv else PREV
    for name, x in sounds().items():
        write(os.path.join(dest, name + '.wav'), x, LEVELS.get(name, -12))
