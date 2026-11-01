#!/usr/bin/env python3
# tools/sounds/scorpion.py — sonidos del ESCORPIÓN del volcán y del ESCORPIÓN TRIPLE AGUIJÓN (jefe secreto), con el tramo
# más fuerte de 100 ms a -12 dBFS (sin GAIN en Sound.lua). LA MATRACA es su firma: 3 clics de madera SEGUIDOS en UN solo
# archivo por gesto (online, 3 sonidos sueltos llegarían cada uno con su retraso y se perdería el ritmo):
#   bosses/giantscorpion/rattle_join.wav    se enrollan: 3 clics que suben un poco
#   bosses/giantscorpion/rattle_split.wav   se desenrollan: 3 clics que bajan un poco
#   enemies/scorpion/click.wav              un clic suelto (el pequeño, de una sola cola)
#   enemies/scorpion/sting.wav        un aguijón golpea: pinchazo seco
#   enemies/scorpion/snap.wav         la pinza se cierra
#   enemies/scorpion/skitter.wav      patitas sobre la roca
#   bosses/giantscorpion/strike.wav   las 3 colas entrelazadas se clavan: golpe grave y roca que salta
#   bosses/giantscorpion/pull.wav     arranca la cola del suelo: roca que raspa y sale
#   bosses/giantscorpion/hiss.wav     el rugido: siseo de caparazón que vibra
#
# (2026-10-31, el usuario: "justo al timing de como se enrollan / desenrollan, 3 clicks seguidos como una matraca de
# madera": antes eran 3 archivos a 0,36 s entre sí y sonaban a chasquido.)
# Tres maderas: A "seca" (tabla fina) · B "hueca" (caja, la instalada) · C "grave" (caja grande). Nadie las ha escuchado.
#   python3 tools/sounds/scorpion.py                → previas en FlappyMonster_pruebas/escorpion/sonidos/
#   python3 tools/sounds/scorpion.py --apply [--click A|B|C]   → assets/sounds/
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jungle_enemies as JE
from jungle_enemies import SR, t_, band, low, noise, env, place, thud, click

PREV = '/home/mtvemo/FlappyMonster_pruebas/escorpion/sonidos'
GAP = 0.09                                 # (segundos entre clics: make_scorpion.py RATTLE_F, 3 cuadros de 0,03 s)
CLICK_F = (0.94, 1.0, 1.07)                # (cada clic, un poco más agudo que el anterior)


def res(f, d, tau):
    tt = t_(d)
    return np.sin(2 * np.pi * f * tt) * np.exp(-tt / tau)


# modos de la madera: (Hz, duración, nivel). Parciales INARMÓNICOS y graves que se apagan pronto: eso suena a madera
WOOD = {'A': [(620, 0.012, 1.0), (1370, 0.008, 0.6), (2450, 0.004, 0.35)],
        'B': [(340, 0.022, 1.0), (760, 0.016, 0.8), (1290, 0.009, 0.45), (2150, 0.005, 0.22)],
        'C': [(210, 0.03, 1.0), (520, 0.02, 0.7), (980, 0.01, 0.35)]}


def tooth(kind, p):
    """un diente de la matraca: la lengüeta se levanta (tic flojo) y la tabla golpea la caja de madera (toc)"""
    d = 0.085
    jit = 1 + JE.rng.uniform(-0.012, 0.012)                                 # (ningún golpe de madera es idéntico)
    parts = [(0, band(noise(0.004), 1800, 6000) * env(0.004, 0.0002, 0.001) * 0.12),
             (0.004, low(noise(0.006), 3500) * env(0.006, 0.0002, 0.0014) * 0.55)]
    parts += [(0.004, res(f * p * jit, d - 0.004, tau) * a) for f, tau, a in WOOD[kind]]
    return place(d, parts)


def rattle(kind, order):
    return place(GAP * 2 + 0.12, [(j * GAP, tooth(kind, CLICK_F[o]) * (0.85 + 0.15 * (j == 2))) for j, o in enumerate(order)])


def write(path, x, target=-12):
    x = x - np.mean(x)
    n = int(SR * 0.1)
    # (los sonidos muy cortos no llegan a -12 dBFS sin recortar: se saturan suave, que además les da mordida)
    x = x / (np.abs(x).max() + 1e-12)
    drive = 1.0
    while drive < 12:
        y = np.tanh(x * drive) * 0.95
        rms = np.sqrt(max(np.mean(y[i:i + n] ** 2) for i in range(0, max(1, len(y) - n + 1), max(1, n // 4))) if len(y) > n else np.mean(y ** 2) * len(y) / n)
        if rms >= 10 ** (target / 20): break
        drive *= 1.1
    x = y * min(1.0, 10 ** (target / 20) / rms)
    if drive > 1.5: print('    (saturado: %.1f)' % drive)
    k = int(SR * 0.002)
    x[-k:] *= np.linspace(1, 0, k)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print('  %s  %.2f s, pico %.2f' % (path, len(x) / SR, np.abs(x).max()))


def others():
    d = 0.3
    sting = place(0.22, [(0, band(noise(0.02), 2500, 9000) * env(0.02, 0.0003, 0.004)), (0, thud(900, 180, 0.14, 0.03) * 0.8),
                         (0.008, band(noise(0.12), 500, 3000) * env(0.12, 0.002, 0.03) * 0.4)])
    snap = place(0.2, [(0, click(2100, 0.03, 0.006)), (0.012, click(1300, 0.04, 0.008) * 0.9), (0.01, thud(420, 160, 0.1, 0.025) * 0.6)])
    grains = [(max(0.0, i * 0.035 + JE.rng.uniform(-0.006, 0.006)), click(JE.rng.uniform(2600, 4200), 0.012, 0.003) * JE.rng.uniform(0.45, 1)) for i in range(8)]
    skitter = place(0.32, grains)
    rocks = [(0.03 + i * 0.05 + JE.rng.uniform(-0.015, 0.02), band(noise(0.05), 800, 5000) * env(0.05, 0.001, 0.012) * JE.rng.uniform(0.2, 0.5)) for i in range(9)]
    strike = place(0.7, [(0, thud(170, 42, 0.6, 0.16)), (0, click(1700, 0.04, 0.008) * 0.9),
                         (0.002, low(noise(0.4), 1500) * env(0.4, 0.002, 0.09) * 0.7)] + rocks)
    tt = t_(0.5)
    scrape = band(noise(0.5), 500, 3500) * np.minimum(1, tt / 0.3) * (0.65 + 0.35 * np.sin(2 * np.pi * 31 * tt)) * np.exp(-np.maximum(0, tt - 0.32) / 0.03)
    pull = place(0.62, [(0, scrape * 0.7), (0.33, thud(320, 90, 0.2, 0.05) * 0.9), (0.33, band(noise(0.1), 1500, 6000) * env(0.1, 0.001, 0.02) * 0.5)])
    tt = t_(0.9)
    trem = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 26 * tt))                       # (el caparazón vibra)
    hiss = band(noise(0.9), 1300, 8000) * np.minimum(1, tt / 0.12) * np.minimum(1, (0.9 - tt) / 0.25) * trem + \
        res(95, 0.9, 0.5) * np.minimum(1, tt / 0.1) * 0.5
    return {'enemies/scorpion/sting.wav': sting, 'enemies/scorpion/snap.wav': snap, 'enemies/scorpion/skitter.wav': skitter,
            'bosses/giantscorpion/strike.wav': strike, 'bosses/giantscorpion/pull.wav': pull, 'bosses/giantscorpion/hiss.wav': hiss}


if __name__ == '__main__':
    kind = sys.argv[sys.argv.index('--click') + 1] if '--click' in sys.argv else 'B'
    if '--apply' in sys.argv:
        # (-14: sin apenas saturar, la saturación le quita la madera)
        write('assets/sounds/bosses/giantscorpion/rattle_join.wav', rattle(kind, (0, 1, 2)), -14)
        write('assets/sounds/bosses/giantscorpion/rattle_split.wav', rattle(kind, (2, 1, 0)), -14)
        write('assets/sounds/enemies/scorpion/click.wav', tooth(kind, 1.0), -14)
        if '--others' in sys.argv:                                       # (el resto, ya aprobado: no se reescribe sin pedirlo)
            for rel, x in others().items():
                write('assets/sounds/' + rel, x)
    else:
        for k in 'ABC':
            write(f'{PREV}/matraca_{k}_enrollar.wav', rattle(k, (0, 1, 2)), -14)
            write(f'{PREV}/matraca_{k}_desenrollar.wav', rattle(k, (2, 1, 0)), -14)
