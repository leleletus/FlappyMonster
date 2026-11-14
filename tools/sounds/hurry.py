#!/usr/bin/env python3
# tools/sounds/hurry.py — el aviso «¡DATE PRISA!» (assets/sounds/jingles/hurry.wav, id 'hurryUp'): suena una vez
# cuando queda 1 minuto del tiempo límite del nivel, ENCIMA de la música (que se agacha mientras dura); justo después
# la música del nivel vuelve más rápida (×1.15).
#
# Es una ALARMA, no una melodía (el usuario rechazó la primera versión, una sirena con carrerilla y acorde final:
# «no pega, es MÁS MELÓDICO de lo que debería»). Hecho como los sonidos cortos del juego:
#   - 44100 Hz mono 16 bits, como los efectos nuevos (items, mecánicas, jefes); el usuario oye «de teléfono» los
#     jingles viejos a 22050 Hz, con ondas cuadradas crudas llenas de aliasing: aquí los pulsos van con PolyBLEP;
#   - pulso de chip de 25 % con paso bajo a 6 kHz y envolvente ataque 2 ms + caída exponencial = el «bip» de la cuenta
#     atrás (tools/sounds/ui.py: count_tick 880 Hz, caída 60 ms; count_go 1760 Hz);
#   - el mismo guardado que story.save / ui.py: normalizar, tanh(×1,8), tramo más fuerte de 100 ms a -12 dBFS,
#     pico ≤ 0,97, fundido de 6 ms.
# Tres variantes:
#   A  «bip-bip-bip» ×3: el bip de la cuenta atrás a 1760 Hz (el tono de count_go) doblado a 880 Hz, en tres grupos
#      de tres: alarma de reloj digital. Una sola altura: nada de melodía. (POR DEFECTO)
#   B  alarma de dos tonos ×3, muy seca: cuadrada 50 % plana re6–la5 (una cuarta, «ni-no») con silencio entre pares.
#   C  tres «uuuip» que suben (520 → 1250 Hz), pulso 25 % plano: claxon de alarma.
# Solo biblioteca estándar (sin numpy). tools/sounds/jingles.py reutiliza estas piezas.
#   python3 tools/sounds/hurry.py               escribe la variante por defecto en assets/sounds/jingles/hurry.wav
#   VARIANTES=1 python3 tools/sounds/hurry.py   además escribe las tres en ~/FlappyMonster_pruebas/hurry/hurry_X.wav
import array
import math
import os
import wave

SR = 44100
TARGET_DB = -12.0
OUT = 'assets/sounds/jingles/hurry.wav'
PRUEBAS = os.path.expanduser('~/FlappyMonster_pruebas/hurry')
DEFAULT = 'A'


# --- piezas (las mismas que megacrabby.py / ui.py, sin numpy) ---
def lowpass(x, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    out, acc = [], 0.0
    for v in x:
        acc = (1 - a) * v + a * acc
        out.append(acc)
    return out


def _blep(t, dt):
    # PolyBLEP: redondea el salto de la onda para que no haya aliasing (lo que hacía «de teléfono» los jingles viejos)
    if t < dt:
        t /= dt
        return t + t - t * t - 1.0
    if t > 1.0 - dt:
        t = (t - 1.0) / dt
        return t * t + t + t + 1.0
    return 0.0


def pulse(f, d, duty=0.25, cutoff=6000):
    # onda de pulso de chip SIN aliasing (PolyBLEP) y sin continua; f puede ser un número o una función del tiempo
    out, ph = [], 0.0
    dc = 2 * duty - 1
    for k in range(int(SR * d)):
        ff = f(k / SR) if callable(f) else f
        dt = ff / SR
        v = (1.0 if ph < duty else -1.0) + _blep(ph, dt) - _blep((ph - duty) % 1.0, dt)
        out.append(v - dc)
        ph = (ph + dt) % 1.0
    return lowpass(out, cutoff)


def saw(f, d):
    # diente de sierra sin aliasing (PolyBLEP); f puede ser una función del tiempo
    out, ph = [], 0.0
    for k in range(int(SR * d)):
        ff = f(k / SR) if callable(f) else f
        dt = ff / SR
        out.append(2 * ph - 1 - _blep(ph, dt))
        ph = (ph + dt) % 1.0
    return out


def triangle(f, d):
    out, ph = [], 0.0
    for k in range(int(SR * d)):
        ff = f(k / SR) if callable(f) else f
        out.append(4 * abs(ph - 0.5) - 1)
        ph = (ph + ff / SR) % 1.0
    return out


def env(n, attack=0.002, decay=0.1):
    # ataque lineal + caída exponencial (env de megacrabby.py)
    return [min(1.0, (k / SR) / attack) * math.exp(-(k / SR) / decay) for k in range(n)]


def flat(n, attack=0.001, release=0.004):
    # envolvente plana con bordes secos (como los jingles viejos de onda cuadrada)
    return [min(1.0, (k / SR) / attack, ((n - k) / SR) / release) for k in range(n)]


def mul(a, b, g=1.0):
    return [x * y * g for x, y in zip(a, b)]


def place(y, x, at):
    i0 = int(SR * at)
    if len(y) < i0 + len(x):
        y.extend([0.0] * (i0 + len(x) - len(y)))
    for k, v in enumerate(x):
        y[i0 + k] += v


# --- las variantes ---
def var_a():
    # bip de cuenta atrás: 25 %, 2 ms de ataque, caída 70 ms; a 1760 Hz con 880 Hz debajo (más cuerpo; en contrafase
    # para que los picos de los dos pulsos no caigan juntos)
    d = 0.10
    bip = [h + l for h, l in zip(mul(pulse(1760, d), env(int(SR * d), 0.002, 0.07)),
                                 mul(pulse(880, d), env(int(SR * d), 0.002, 0.07), -0.5))]
    y = []
    for g in range(3):                    # tres grupos…
        for b in range(3):                # …de tres bips, a 0,10 s
            place(y, bip, g * 0.42 + b * 0.10)
    place(y, [0.0] * int(SR * 0.05), len(y) / SR)
    return y


def var_b():
    # dos tonos planos, 50 %, sin caída: re6 (1175 Hz) – la5 (880 Hz), 0,10 s cada uno, pares a 0,28 s
    d = 0.10
    hi = mul(pulse(1175, d, 0.5), flat(int(SR * d)))
    lo = mul(pulse(880, d, 0.5), flat(int(SR * d)))
    y = []
    for p in range(3):
        place(y, hi, p * 0.28)
        place(y, lo, p * 0.28 + d)
    place(y, [0.0] * int(SR * 0.04), len(y) / SR)
    return y


def var_c():
    # «uuuip»: barrido exponencial 520 → 1250 Hz en 0,22 s, pulso 25 % plano, cada 0,30 s
    d = 0.22
    sweep = lambda t: 520 * (1250 / 520) ** (t / d)
    w = mul(pulse(sweep, d, 0.25), flat(int(SR * d), 0.002, 0.02))
    y = []
    for i in range(3):
        place(y, w, i * 0.30)
    place(y, [0.0] * int(SR * 0.04), len(y) / SR)
    return y


VARIANTS = {'A': var_a, 'B': var_b, 'C': var_c}


# --- guardado: igual que story.save ---
def loud100(x):
    n = int(SR * 0.1)
    acc = sum(v * v for v in x[:n])
    best = acc
    for i in range(n, len(x)):
        acc += x[i] * x[i] - x[i - n] * x[i - n]
        best = max(best, acc)
    return 10 * math.log10(best / n + 1e-12)


def finish(x):
    m = sum(x) / len(x)
    x = [v - m for v in x]
    pk = max(abs(v) for v in x) + 1e-9
    x = [math.tanh(v / pk * 1.8) / math.tanh(1.8) for v in x]
    g = 10 ** ((TARGET_DB - loud100(x)) / 20)
    x = [v * g for v in x]
    pk = max(abs(v) for v in x)
    if pk > 0.97:
        x = [v * 0.97 / pk for v in x]
    fade = int(SR * 0.006)
    for k in range(fade):
        x[len(x) - fade + k] *= 1 - k / fade
    return x


def write(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(array.array('h', (int(round(v * 32767)) for v in x)).tobytes())


def report(path, x):
    rms = 10 * math.log10(sum(v * v for v in x) / len(x) + 1e-12)
    pk = max(abs(v) for v in x)
    # golpes: arranques donde la envolvente de 5 ms sube más de 6 dB respecto a la anterior (y pasa de -30 dBFS)
    seg, ons, prev = int(SR * 0.005), [], -120.0
    for i in range(0, len(x) - seg, seg):
        e = 10 * math.log10(sum(v * v for v in x[i:i + seg]) / seg + 1e-12)
        if e > -30 and e - prev > 6 and (not ons or i / SR - ons[-1] > 0.04):
            ons.append(i / SR)
        prev = e
    print('  %s  %.2f s · pico %.1f dBFS · 100 ms más fuertes %.1f dBFS · RMS %.1f dBFS · recortadas %d'
          % (path, len(x) / SR, 20 * math.log10(pk), loud100(x), rms, sum(1 for v in x if abs(v) >= 0.97)))
    print('    arranques (s): ' + ' '.join('%.2f' % t for t in ons))


if __name__ == '__main__':
    todas = os.environ.get('VARIANTES') == '1'
    for name in (VARIANTS if todas else [DEFAULT]):
        x = finish(VARIANTS[name]())
        if name == DEFAULT:
            write(OUT, x); report(OUT, x)
        if todas:
            p = os.path.join(PRUEBAS, 'hurry_%s.wav' % name)
            write(p, x); report(p, x)
