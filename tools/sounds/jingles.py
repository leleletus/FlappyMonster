#!/usr/bin/env python3
# tools/sounds/jingles.py — REMASTER de los tres jingles viejos (assets/sounds/jingles/):
#   fanfare        nivel ganado (id 'fanfare', ~1,1 s): sol4 do5 mi5 sol5 · mi5 sol5 do6~~~ (con vibrato)
#   finish         llegar a la meta (id 'finish', ~0,43 s): do5 mi5 sol5 do6~
#   sad_trombone   fallo / fin de partida (id 'sadtrombone', ~1,5 s): «ua-ua-ua-uaaa» sol4 fa#4 fa4 mi4
# Los originales no tenían generador: eran ondas cuadradas crudas a 22050 Hz, de volumen plano y llenas de aliasing.
# El usuario: «suenan de baja calidad, como grabados con un móvil, y no pegan con el resto de efectos». Aquí se
# rehacen con las MISMAS notas y tiempos (medidos sobre los originales) pero a 44100 Hz, con pulsos sin aliasing
# (PolyBLEP, piezas de tools/sounds/hurry.py), envolventes con ataque y caída, un triángulo de bajo, y el trombón
# como diente de sierra con filtro «ua» que se abre y se cierra. Nivel: tramo más fuerte de 100 ms a -12 dBFS (el
# guardado de story.save / ui.py). Copias de los originales: ~/FlappyMonster_pruebas/jingles_originales/.
# Solo biblioteca estándar (sin numpy).
#   python3 tools/sounds/jingles.py [fanfare finish sad_trombone]
#   VARIANTES=1 …  además escribe <nombre>_nuevo.wav en ~/FlappyMonster_pruebas/jingles_originales/ para comparar
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from hurry import SR, pulse, saw, triangle, env, flat, mul, place, finish, write, report   # noqa: E402

OUT = 'assets/sounds/jingles'
PRUEBAS = os.path.expanduser('~/FlappyMonster_pruebas/jingles_originales')
NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def hz(name):
    # 'F#4' -> frecuencia (la4 = 440)
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NAMES.index(n) + 12 * (o + 1) - 69) / 12)


def note(f, d, duty=0.25, decay=0.3, release=0.012, vib=0.0, vib_in=0.15):
    # nota de pulso: ataque 3 ms, caída exponencial, final seco pero sin chasquido; vib = vibrato en semitonos (5,5 Hz)
    if vib:
        fn = lambda t: f * 2 ** (vib * min(1.0, t / vib_in) * math.sin(2 * math.pi * 5.5 * t) / 12)
    else:
        fn = f
    n = int(SR * d)
    e = [a * b for a, b in zip(env(n, 0.003, decay), flat(n, 0.003, release))]
    return mul(pulse(fn, d, duty), e)


def bass(f, d, decay=0.4, g=0.5):
    n = int(SR * d)
    e = [a * b for a, b in zip(env(n, 0.004, decay), flat(n, 0.004, 0.015))]
    return mul(triangle(f, d), e, g)


def fanfare():
    # medido en el original: cuatro notas de 85 ms (sol4 do5 mi5 sol5), silencio, mi5 y sol5 de 80 ms, y do6 desde
    # 0,56 s hasta el final con vibrato
    y = []
    for i, n in enumerate(('G4', 'C5', 'E5', 'G5')):
        place(y, note(hz(n), 0.08, 0.25, 0.25), i * 0.085)
    place(y, note(hz('E5'), 0.075, 0.25, 0.25), 0.40)
    place(y, note(hz('G5'), 0.075, 0.25, 0.25), 0.48)
    place(y, note(hz('C6'), 0.56, 0.25, 0.35, release=0.12, vib=0.3), 0.56)
    for i, n in enumerate(('C5', 'E5', 'G5')):            # acorde suave del final (como el de count_go)
        place(y, mul(note(hz(n), 0.54, 0.125, 0.25, release=0.12), [0.3] * int(SR * 0.54)), 0.56 + i * 0.01)
    place(y, bass(hz('C3'), 0.34, 0.3), 0.0)              # bajo: do · sol · do
    place(y, bass(hz('G2'), 0.16, 0.3), 0.40)
    place(y, bass(hz('C3'), 0.56, 0.35), 0.56)
    return y


def finish_jingle():
    # medido: do5 mi5 sol5 (60 · 60 · 80 ms) y do6 desde 0,20 s hasta 0,43 s
    y = []
    for at, d, n in ((0.0, 0.06, 'C5'), (0.06, 0.06, 'E5'), (0.12, 0.08, 'G5')):
        place(y, note(hz(n), d, 0.25, 0.25), at)
        place(y, bass(hz(n) / 4, d, 0.3, 0.35), at)       # el triángulo dobla dos octavas abajo
    place(y, note(hz('C6'), 0.23, 0.25, 0.3, release=0.06, vib=0.2, vib_in=0.1), 0.20)
    place(y, bass(hz('C4') / 2, 0.23, 0.3), 0.20)
    return y


def wah(f0, d, bend=-0.5, vib=0.0, decay=None):
    # nota de trombón: diente de sierra que se dobla hacia abajo `bend` semitonos, por un filtro paso bajo de dos
    # polos que se abre al soplar (400 → 2400 Hz en 70 ms) y se va cerrando («ua»); vibrato que crece al final
    fn = lambda t: f0 * 2 ** ((0.3 + (bend - 0.3) * min(1.0, t / d)
                               + vib * min(1.0, t / (d * 0.6)) * math.sin(2 * math.pi * 5.2 * t)) / 12)
    x = saw(fn, d)
    n = len(x)
    out, a1, a2 = [], 0.0, 0.0
    for k, v in enumerate(x):
        t = k / SR
        c = 400 + 2000 * min(1.0, t / 0.07) * math.exp(-max(0.0, t - 0.07) / (d * 0.8))
        a = math.exp(-2 * math.pi * c / SR)
        a1 = (1 - a) * v + a * a1
        a2 = (1 - a) * a1 + a * a2
        out.append(a2)
    e = [min(1.0, (k / SR) / 0.02, ((n - k) / SR) / 0.03) for k in range(n)]
    if decay:
        e = [g * math.exp(-(k / SR) / decay) for k, g in enumerate(e)]
    return mul(out, e)


def sad_trombone():
    # medido: sol4 (0-0,26) fa#4 (0,28-0,54) fa4 (0,56-0,82) mi4 (0,84-1,54, con vibrato que se ensancha)
    y = []
    for i, n in enumerate(('G4', 'F#4', 'F4')):
        place(y, wah(hz(n), 0.26), i * 0.28)
    place(y, wah(hz('E4'), 0.70, bend=-0.2, vib=0.8, decay=0.9), 0.84)
    return y


ALL = {'fanfare': fanfare, 'finish': finish_jingle, 'sad_trombone': sad_trombone}

if __name__ == '__main__':
    todas = os.environ.get('VARIANTES') == '1'
    for name in (sys.argv[1:] or list(ALL)):
        x = finish(ALL[name]())
        p = os.path.join(OUT, name + '.wav')
        write(p, x); report(p, x)
        if todas:
            write(os.path.join(PRUEBAS, name + '_nuevo.wav'), x)
