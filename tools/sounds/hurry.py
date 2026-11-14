#!/usr/bin/env python3
# tools/sounds/hurry.py — el aviso «¡DATE PRISA!» (assets/sounds/jingles/hurry.wav, id 'hurryUp'): suena una vez
# cuando quedan 60 s del tiempo límite del nivel (el reloj del HUD se pone rojo a 1:00), ENCIMA de la música (que se
# agacha mientras dura); después la música vuelve más rápida (src/audio/Hurry.lua, Hurry.RATE).
#
# v3 (esta): TENSIÓN CRECIENTE con una escalera cromática. La fórmula, medida sobre un clip de referencia:
#   motivo corto de 2 notas agudas sobre una nota más grave que alterna con ellas (~0,54 s)
#   → el mismo motivo +1 semitono → +2 semitonos (inicios cada 3 corcheas = 0,643 s a 140 BPM)
#   → cierre: una nota larga aguda sobre un bajo grave sostenido, con bombo y plato, que se apaga (~0,86 s).
# Melodía ORIGINAL, hecha con el vocabulario de la casa (docs/audio/music-guide.md):
#   - Do mayor (la tonalidad del mapa y los menús); el motivo es la 4ª sol→do de «la llamada» (sol–do–mi–sol);
#   - la segunda nota cae a contratiempo (en la corchea «y») y la nota grave alterna en semicorcheas «e» / «a»;
#   - los inicios cada 3 corcheas son el «3» del tresillo 3+3+2 seguido en hemiolia contra el 4/4;
#   - el cierre salta otra 4ª (re6 → sol6 en D; en E fa#6 → sol6, sensible que sube) y se queda en SOL, la 5ª:
#     la última nota de «la llamada», abierta, que empuja hacia la música más rápida.
# Timbres (los roles de siempre): melodía = pulso 2A03 con barrido de ciclo 12,5 → 50 % y vibrato en la nota larga,
# doblado a la octava por el «bip» de la cuenta atrás (pulso 25 %, ataque 2 ms, caída exponencial, paso bajo a
# 6 kHz: tools/sounds/ui.py); acompañamiento = pulso 12,5 % corto; bajo = triángulo; bombo DPCM de 1 bit; plato de
# ruido (LFSR de 15 bits).
# Lo rechazado (docs/audio/sound.md § Hurry-up jingle): v1 sirena + carrerilla + acorde de fanfarria («más melódico
# de lo que debería»); v2 A / B / C (bips ×3, alarma de dos tonos, «uuuip»: «no termina de convencer»; están en el
# historial de git y en ~/FlappyMonster_pruebas/hurry/).
# 44100 Hz mono 16 bits, pulsos sin aliasing (PolyBLEP). Guardado como story.save / ui.py: normalizar, tanh(×1,8),
# tramo más fuerte de 100 ms a -12 dBFS, pico ≤ 0,97, fundido de 6 ms.
# Solo biblioteca estándar (sin numpy). tools/sounds/jingles.py reutiliza estas piezas.
#   python3 tools/sounds/hurry.py               escribe la variante por defecto en assets/sounds/jingles/hurry.wav
#                                               (y su partitura en ~/FlappyMonster_pruebas/hurry/hurry.mid)
#   VARIANTES=1 python3 tools/sounds/hurry.py   además escribe hurry_D/E/F.wav + .mid en ~/FlappyMonster_pruebas/hurry/
import array
import math
import os
import struct
import wave

# --- parámetros ---
TONALIDAD = 'C'          # Do mayor (todas las alturas de abajo son de Do mayor; se transportan con TRANSPORTE)
TRANSPORTE = 0           # semitonos para mover el jingle entero
BPM = 140
REPETICIONES = 3         # veces que suena el motivo
SEMITONOS_PASO = 1       # cuánto sube cada repetición
PASO = 6                 # semicorcheas entre inicios del motivo (3 corcheas = 0,643 s a 140 BPM)
CIERRE = 8               # semicorcheas de la nota larga del cierre (0,857 s), que se apaga
ANTES = 0.03             # s de silencio antes del primer golpe
DESPUES = 0.12           # s de silencio al final

SR = 44100
TARGET_DB = -12.0
OUT = 'assets/sounds/jingles/hurry.wav'
PRUEBAS = os.path.expanduser('~/FlappyMonster_pruebas/hurry')
DEFAULT = 'D'
S16 = 60.0 / BPM / 4     # una semicorchea en segundos
NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def midi_of(name):
    # 'F#4' -> número MIDI (do4 = 60)
    return NAMES.index(name[:-1]) + 12 * (int(name[-1]) + 1)


def hz_of(m):
    return 440.0 * 2 ** ((m - 69) / 12)


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
    # onda de pulso de chip SIN aliasing (PolyBLEP) y sin continua; f y duty pueden ser números o funciones del tiempo
    out, ph = [], 0.0
    for k in range(int(SR * d)):
        t = k / SR
        ff = f(t) if callable(f) else f
        du = duty(t) if callable(duty) else duty
        dt = ff / SR
        v = (1.0 if ph < du else -1.0) + _blep(ph, dt) - _blep((ph - du) % 1.0, dt)
        out.append(v - (2 * du - 1))
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
    # envolvente plana con bordes secos
    return [min(1.0, (k / SR) / attack, ((n - k) / SR) / release) for k in range(n)]


def mul(a, b, g=1.0):
    return [x * y * g for x, y in zip(a, b)]


def place(y, x, at):
    i0 = int(SR * at)
    if len(y) < i0 + len(x):
        y.extend([0.0] * (i0 + len(x) - len(y)))
    for k, v in enumerate(x):
        y[i0 + k] += v


# --- instrumentos del jingle ---
def lead(f, d, decay=0.35, release=0.02, vib=0.0, gain=1.0):
    # melodía: pulso 2A03 con barrido de ciclo 12,5 → 50 % en los primeros 0,12 s; vibrato (semitonos, 5,5 Hz) que
    # entra a los 0,15 s en las notas largas
    fn = (lambda t: f * 2 ** (vib * min(1.0, max(0.0, t - 0.15) / 0.2) * math.sin(2 * math.pi * 5.5 * t) / 12)) \
        if vib else f
    duty = lambda t: 0.125 + 0.375 * min(1.0, t / 0.12)
    n = int(SR * d)
    e = [a * b for a, b in zip(env(n, 0.003, decay), flat(n, 0.003, release))]
    return mul(pulse(fn, d, duty, 7000), e, gain)


def beep(f, d, decay=0.08, gain=0.5, vib=0.0):
    # el «bip» de la cuenta atrás (count_tick / count_go): 25 %, ataque 2 ms, caída exponencial, paso bajo 6 kHz
    fn = (lambda t: f * 2 ** (vib * min(1.0, max(0.0, t - 0.15) / 0.2) * math.sin(2 * math.pi * 5.5 * t) / 12)) \
        if vib else f
    n = int(SR * d)
    e = [a * b for a, b in zip(env(n, 0.002, decay), flat(n, 0.002, 0.01))]
    return mul(pulse(fn, d, 0.25), e, gain)


def stab(f, d=0.07, gain=0.32):
    # acompañamiento: pulso 12,5 % muy corto (la nota grave que alterna)
    n = int(SR * d)
    e = [a * b for a, b in zip(env(n, 0.002, 0.05), flat(n, 0.002, 0.008))]
    return mul(pulse(f, d, 0.125, 5000), e, gain)


def bass(f, d, decay=0.3, gain=0.55):
    n = int(SR * d)
    e = [a * b for a, b in zip(env(n, 0.004, decay), flat(n, 0.004, 0.02))]
    return mul(triangle(f, d), e, gain)


def kick(gain=0.8):
    # bombo DPCM de 1 bit: un seno que cae 160 → 45 Hz codificado en deltas de ±1/32 a 33,1 kHz (como el canal DMC)
    d = 0.16
    target, ph, out = [], 0.0, []
    for k in range(int(SR * d)):
        t = k / SR
        ph += 2 * math.pi * (45 + 115 * math.exp(-t / 0.03)) / SR
        target.append(math.sin(ph) * math.exp(-t / 0.06))
    lvl, step, acc = 0.0, 1 / 32, 0.0
    for v in target:
        acc += 33144 / SR
        while acc >= 1:
            acc -= 1
            lvl += step if v > lvl else -step
        out.append(lvl)
    return [v * gain for v in lowpass(out, 9000)]


def cymbal(d=0.9, gain=0.32):
    # plato de ruido: LFSR de 15 bits (modo largo) a ~25 kHz, sin graves, con caída larga
    reg, out, acc, v = 1, [], 0.0, 1.0
    for k in range(int(SR * d)):
        acc += 25000 / SR
        while acc >= 1:
            acc -= 1
            b = (reg ^ (reg >> 1)) & 1
            reg = (reg >> 1) | (b << 14)
            v = 1.0 if reg & 1 else -1.0
        out.append(v)
    lo = lowpass(out, 2500)
    hp = [a - b for a, b in zip(out, lo)]
    n = len(hp)
    e = [a * b for a, b in zip(env(n, 0.001, 0.28), flat(n, 0.001, 0.05))]
    return mul(lowpass(hp, 9000), e, gain)


def hat(gain=0.12):
    # ruido corto (charles) que marca cada repetición
    c = cymbal(0.05, 1.0)
    return mul(c, env(len(c), 0.001, 0.015), gain)


# --- la partitura: (voz, semicorchea de inicio, semicorcheas de duración, nota) por repetición, en Do mayor ---
# Cada variante: el motivo (voz aguda + grave alterna + bajo) y el cierre. 'oct' = doblado del bip a la octava.
VARIANTES = {
    # D (POR DEFECTO): la 4ª de «la llamada» sol5 → do6 (do6 a contratiempo, en la corchea «y»); la nota grave mi5
    # en las semicorcheas «e» y «a» (alterna con la aguda); bajo do3. Cierre: sol6 sobre sol2 (la 5ª, abierta).
    'D': {
        'motivo': [('lead', 0, 2, 'G5'), ('lead', 2, 3, 'C6'), ('acc', 1, 1, 'E5'), ('acc', 3, 1, 'E5'),
                   ('acc', 5, 1, 'E5'), ('bass', 0, 4, 'C3')],
        'cierre': [('lead', 0, CIERRE, 'G6'), ('bass', 0, CIERRE, 'G2'), ('acc', 0, 1, 'D6'), ('acc', 0, 1, 'B5')],
    },
    # E: la 3ª de «la llamada» do6 → mi6, grave sol5 alternando; la escalera llega a re6 → fa#6 y el cierre sube
    # medio tono a sol6 (fa# = sensible de Sol) sobre sol2.
    'E': {
        'motivo': [('lead', 0, 2, 'C6'), ('lead', 2, 3, 'E6'), ('acc', 1, 1, 'G5'), ('acc', 3, 1, 'G5'),
                   ('acc', 5, 1, 'G5'), ('bass', 0, 4, 'C3')],
        'cierre': [('lead', 0, CIERRE, 'G6'), ('bass', 0, CIERRE, 'G2'), ('acc', 0, 1, 'D6'), ('acc', 0, 1, 'B5')],
    },
    # F: el motivo de D con la nota grave como arpegio 4-3-5 en semicorcheas (do5 mi5 sol5 do6 … la célula de la
    # casa) en vez de una nota repetida; bajo do3–sol2 en corcheas. Cierre igual que D.
    'F': {
        'motivo': [('lead', 0, 2, 'G5'), ('lead', 2, 3, 'C6'), ('acc', 1, 1, 'E5'), ('acc', 3, 1, 'G5'),
                   ('acc', 4, 1, 'E5'), ('acc', 5, 1, 'C5'), ('bass', 0, 2, 'C3'), ('bass', 3, 2, 'G2')],
        'cierre': [('lead', 0, CIERRE, 'G6'), ('bass', 0, CIERRE, 'G2'), ('acc', 0, 1, 'D6'), ('acc', 0, 1, 'B5')],
    },
}


def score(name):
    # lista de eventos (voz, inicio en semicorcheas, duración en semicorcheas, nota MIDI) ya transportados
    v = VARIANTES[name]
    ev = []
    for r in range(REPETICIONES):
        up = TRANSPORTE + r * SEMITONOS_PASO
        for voz, at, dur, n in v['motivo']:
            ev.append((voz, r * PASO + at, dur, midi_of(n) + up))
        ev.append(('hat', r * PASO, 1, 42))
    c0 = REPETICIONES * PASO
    for voz, at, dur, n in v['cierre']:
        ev.append((voz, c0 + at, dur, midi_of(n) + TRANSPORTE))
    ev.append(('kick', c0, 2, 36))
    ev.append(('crash', c0, CIERRE, 49))
    return ev


def render(name):
    y = []
    last = max(at for voz, at, dur, m in score(name) if voz == 'lead')
    for voz, at, dur, m in score(name):
        t, d, f = ANTES + at * S16, dur * S16, hz_of(m)
        if voz == 'lead':
            if at == last:                          # la nota larga del cierre: vibrato, se apaga
                place(y, lead(f, d + 0.05, 0.45, 0.25, vib=0.25), t)
                place(y, beep(f / 2, d + 0.05, 0.5, 0.22, vib=0.25), t)    # refuerzo una octava abajo
            else:
                place(y, lead(f, d * 0.92, 0.25), t)
                place(y, beep(f * 2, d * 0.92, 0.07, 0.35), t)             # el bip de la cuenta atrás, octava arriba
        elif voz == 'acc':
            place(y, stab(f), t)
        elif voz == 'bass':
            place(y, bass(f, d + (0.05 if dur >= CIERRE else 0), 0.5 if dur >= CIERRE else 0.25), t)
        elif voz == 'hat':
            place(y, hat(), t)
        elif voz == 'kick':
            place(y, kick(), t)
        elif voz == 'crash':
            place(y, cymbal(d + 0.05), t)
    place(y, [0.0] * int(SR * DESPUES), len(y) / SR)
    return y


# --- .mid (escrito a mano: tipo 1, 480 por negra) ---
def write_mid(path, name):
    tpq = 480
    t16 = tpq // 4

    def vlq(n):
        b = [n & 0x7F]
        n >>= 7
        while n:
            b.insert(0, (n & 0x7F) | 0x80)
            n >>= 7
        return bytes(b)

    def track(events, meta=b''):
        # events: (tick, bytes); ordenados, con los «note off» antes que los «note on» del mismo tick
        events.sort(key=lambda e: (e[0], e[1][0] & 0xF0 == 0x90))
        data, now = bytearray(meta), 0
        for tick, msg in events:
            data += vlq(tick - now) + msg
            now = tick
        data += b'\x00\xff\x2f\x00'
        return b'MTrk' + struct.pack('>I', len(data)) + bytes(data)

    # voz -> (canal, programa GM, velocidad)
    chans = {'lead': (0, 80, 100), 'acc': (1, 81, 70), 'bass': (2, 38, 90),
             'hat': (9, None, 50), 'kick': (9, None, 110), 'crash': (9, None, 100)}
    names = {'lead': b'melodia (pulso)', 'acc': b'acompanamiento', 'bass': b'bajo (triangulo)', 'hat': b'percusion'}
    groups = {}
    for voz, at, dur, m in score(name):
        g = 'hat' if chans[voz][0] == 9 else voz
        ch, _, vel = chans[voz]
        groups.setdefault(g, []).append((at * t16, bytes([0x90 | ch, m, vel])))
        groups[g].append(((at + dur) * t16, bytes([0x80 | ch, m, 0])))
    tempo = 60000000 // BPM
    head = track([], b'\x00\xff\x51\x03' + tempo.to_bytes(3, 'big') + b'\x00\xff\x58\x04\x04\x02\x18\x08'
                 + b'\x00\xff\x59\x02\x00\x00')                     # 4/4, Do mayor
    tracks = [head]
    for g in ('lead', 'acc', 'bass', 'hat'):
        ch, prog, _ = chans[g]
        meta = b'\x00\xff\x03' + vlq(len(names[g])) + names[g]
        if prog is not None:
            meta += b'\x00' + bytes([0xC0 | ch, prog])
        tracks.append(track(groups[g], meta))
    with open(path, 'wb') as fh:
        fh.write(b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), tpq) + b''.join(tracks))


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
    for name in (VARIANTES if todas else [DEFAULT]):
        x = finish(render(name))
        if name == DEFAULT:
            write(OUT, x); report(OUT, x)
            write_mid(os.path.join(PRUEBAS, 'hurry.mid'), name)       # la partitura (no es un recurso del juego)
        if todas:
            p = os.path.join(PRUEBAS, 'hurry_%s.wav' % name)
            write(p, x); report(p, x)
            write_mid(os.path.join(PRUEBAS, 'hurry_%s.mid' % name), name)
