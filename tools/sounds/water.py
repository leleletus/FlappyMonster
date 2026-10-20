#!/usr/bin/env python3
# tools/sounds/water.py — los sonidos del AGUA y la vida extra, ORIGINALES (los anteriores venían de otros juegos: el
# ahogo, el "glu glu", la bocanada y la alarma eran de Sonic 1 y la vida extra sonaba como la de Mario; el usuario,
# 2026-10-20). Cada uno dura EXACTAMENTE lo mismo que el que sustituye (el juego cuenta con esas duraciones: el
# ahogo mata al acabar su audio, DROWN_AUDIO_DUR = 12 s) y suena igual de fuerte (su tramo más fuerte de 100 ms), así
# la mezcla de Sound.GAIN sigue valiendo.
#
#   warning     la ALARMA bajo el agua (cada pocos segundos sin aire): dos "bips" secos de chip a un semitono, el
#               mismo par de notas que el ahogo
#   air_gasp    la BOCANADA al salir o al coger una burbuja: aire que entra (soplo con filtro que sube) y un "pop"
#   glugluglu   AHOGADO: burbujas que suben y se apagan (cada burbuja, un tono que sube muy rápido), un golpe sordo
#   drowning    la MÚSICA de urgencia del ahogo (12,1 s). Receta del usuario:
#                 · material: solo DOS notas a un semitono (mi5 – fa5) que alternan; ninguna melodía
#                 · se repite en bucle sin variar, sin cadencia
#                 · ACELERA: de 132 BPM a 264 BPM (corcheas: cada nota es media negra)
#                 · seca: como mucho 4 voces (pulso 25 %, pulso 12,5 % una octava arriba desde los 3 s, golpecito de
#                   ruido en cada nota, pulso grave en mi3 – fa3 desde los 7 s), sin reverb ni colchones
#                 · final abierto: corta en FA (la nota de arriba, sin resolver), en pleno impulso
#   one_up      la VIDA EXTRA: el icono de vida es una gelatina — un "boing" que sube con vibrato y un destello de
#               dos notas (do6 + la6) que se apaga
#
# Desde la raíz del repo:  python3 tools/sounds/water.py      (necesita numpy y ffmpeg para los .ogg)
import os, subprocess, tempfile, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(2026)

# Lo que dura cada uno (en muestras a 44,1 kHz) y lo fuerte que sonaba el anterior (dBFS del tramo de 100 ms)
TARGET = {
    'water/warning':   (33053, -12.8),
    'water/air_gasp':  (21231, -6.8),
    'water/drowning':  (533696, -5.8),
    'water/glugluglu': (83960, -6.7),
    'items/one_up':    (26462, -13.0),
}


def t_(n): return np.arange(n) / SR


def square(phase, duty=0.5):
    return np.where((phase % 1.0) < duty, 1.0, -1.0)


def tri(phase):
    p = phase % 1.0
    return 4 * np.abs(p - 0.5) - 1


def fit(x, n):
    if len(x) >= n: return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def save(name, x):
    n, db = TARGET[name]
    x = fit(x - np.mean(x), n)
    w = int(SR * 0.1)
    best = max(np.mean(x[i:i + w] ** 2) for i in range(0, max(1, n - w + 1), w // 4))
    x = x * (10 ** (db / 20) / np.sqrt(best + 1e-12))
    x = np.clip(x, -0.98, 0.98)
    k = int(SR * 0.003)
    x[:k] *= np.linspace(0, 1, k); x[-k:] *= np.linspace(1, 0, k)
    pcm = (x * 32767).astype(np.int16)
    out = os.path.join('assets/sounds', name)
    if name.startswith('items/'):
        with wave.open(out + '.wav', 'wb') as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR); f.writeframes(pcm.tobytes())
        path = out + '.wav'
    else:
        # (codificado en estéreo, se mide igual que se midió el anterior —decodificado a mono— y se corrige: el paso
        # a .ogg cambiaba el nivel unos 3 dB)
        gain = 1.0
        for _ in range(3):
            q = (np.clip(x * gain, -0.98, 0.98) * 32767).astype(np.int16)
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
                with wave.open(tmp.name, 'wb') as f:
                    f.setnchannels(2); f.setsampwidth(2); f.setframerate(SR)
                    f.writeframes(np.repeat(q, 2).tobytes())
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp.name, '-c:a', 'libvorbis', '-q:a', '6', out + '.ogg'],
                               check=True)
                os.unlink(tmp.name)
            got = loudness(out + '.ogg')
            if abs(got - db) < 0.3: break
            gain *= 10 ** ((db - got) / 20)
        path = out + '.ogg'
    print('  %-34s %.3f s' % (path, n / SR))


def loudness(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-ac', '1', '-ar', str(SR), '-'],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float32)
    w = int(SR * 0.1)
    best = max(np.mean(x[i:i + w] ** 2) for i in range(0, max(1, len(x) - w + 1), w // 4))
    return 10 * np.log10(best + 1e-12)


def env(n, a, d):
    """Ataque `a` s, caída exponencial de `d` s"""
    tt = t_(n)
    return np.minimum(1, tt / max(a, 1e-4)) * np.exp(-tt / d)


# ── ALARMA ──────────────────────────────────────────────────────────────────────
def warning():
    n = TARGET['water/warning'][0]
    y = np.zeros(n)
    for i, f in enumerate((659.26, 698.46)):            # mi5, fa5 (el par del ahogo)
        m = int(SR * 0.13)
        tt = t_(m)
        ph = np.cumsum(f * (1 + 0.01 * np.sin(2 * np.pi * 28 * tt))) / SR
        b = square(ph, 0.25) * env(m, 0.002, 0.07)
        b += 0.4 * square(2 * ph, 0.125) * env(m, 0.002, 0.04)
        a = int(SR * (0.02 + i * 0.16))
        y[a:a + m] += b
    # una cola corta y seca: el segundo bip repetido muy flojo (no es reverb: un eco de chip)
    m = int(SR * 0.13)
    tt = t_(m)
    y[int(SR * 0.42):int(SR * 0.42) + m] += 0.25 * square(698.46 * tt, 0.25) * env(m, 0.002, 0.05)
    return y


# ── BOCANADA ────────────────────────────────────────────────────────────────────
def air_gasp():
    n = TARGET['water/air_gasp'][0]
    tt = t_(n)
    noise = rng.standard_normal(n)
    # soplo que entra: ruido filtrado con un pasa-banda que sube (barrido 500 → 2600 Hz)
    out = np.zeros(n)
    lo = 0.0
    fc = 500 + 2100 * np.clip(tt / 0.3, 0, 1)
    for i in range(n):                                   # filtro de estado variable, a mano
        k = 2 * np.sin(np.pi * fc[i] / SR)
        lo += k * (noise[i] - lo)
        out[i] = lo
    out = (out - np.convolve(out, np.ones(8) / 8, 'same')) * np.minimum(1, tt / 0.12) * np.exp(-np.maximum(0, tt - 0.18) / 0.08)
    # el "pop" de salir: un tono que sube rápido (no una nota de chip)
    m = int(SR * 0.09)
    pt = t_(m)
    pop = np.sin(2 * np.pi * np.cumsum(300 + 900 * (pt / 0.09) ** 0.5) / SR) * env(m, 0.001, 0.03)
    a = int(SR * 0.22)
    out[a:a + m] += 0.9 * pop
    return out


# ── GLU GLU (ahogado) ─────────────────────────────────────────────────────────
def glugluglu():
    n = TARGET['water/glugluglu'][0]
    y = np.zeros(n)
    # golpe sordo al principio (se le escapa el aire)
    m = int(SR * 0.18)
    tt = t_(m)
    y[:m] += 0.8 * np.sin(2 * np.pi * np.cumsum(140 - 60 * tt / 0.18) / SR) * env(m, 0.003, 0.06)
    # burbujas: cada una un seno cuyo tono sube de golpe (así suenan las burbujas de verdad), cada vez más espaciadas,
    # más graves y más flojas
    t0, gap, f0, amp = 0.12, 0.09, 520.0, 1.0
    while t0 < 1.75:
        dur = 0.05 + 0.03 * rng.random()
        m = int(SR * dur)
        tt = t_(m)
        f = f0 * (1 + 1.6 * (tt / dur) ** 1.5) * (0.9 + 0.2 * rng.random())
        b = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(m, 0.002, dur * 0.45)
        a = int(SR * t0)
        y[a:a + m] += amp * b
        t0 += gap * (0.8 + 0.4 * rng.random())
        gap *= 1.12; f0 *= 0.95; amp *= 0.88
    return y


# ── AHOGO (música de urgencia) ────────────────────────────────────────────────
BPM0, BPM1 = 132, 264


def drowning():
    n = TARGET['water/drowning'][0]
    total = n / SR
    # tiempos de cada corchea con el tempo subiendo (lineal en BPM con el tiempo)
    times = []
    t = 0.0
    while t < total:
        times.append(t)
        bpm = BPM0 + (BPM1 - BPM0) * (t / total)
        t += 60.0 / bpm / 2
    y = np.zeros(n)
    E5, F5 = 659.26, 698.46
    for i, t in enumerate(times):
        f = E5 if i % 2 == 0 else F5
        nxt = times[i + 1] if i + 1 < len(times) else total
        m = int(SR * min(nxt - t, 0.25))
        a = int(SR * t)
        m = min(m, n - a)
        if m <= 0: break
        tt = t_(m)
        k = t / total                                     # 0 → 1 a lo largo de la pieza
        gate = np.where(tt < (nxt - t) * 0.7, 1.0, 0.0)   # notas secas y separadas
        ph = f * tt
        v = 0.55 * square(ph, 0.25) * gate * np.exp(-tt / 0.5)                         # 1) pulso 25 %
        if t >= 3.0: v += 0.32 * square(2 * ph, 0.125) * gate * np.exp(-tt / 0.3)     # 2) octava arriba
        hm = int(SR * 0.012)                                                            # 3) golpecito de ruido
        v[:hm] += (0.25 + 0.2 * k) * rng.standard_normal(hm) * np.linspace(1, 0, hm)
        if t >= 7.0: v += 0.45 * tri(f / 4 * tt) * gate                               # 4) grave, dos octavas abajo
        y[a:a + m] += v * (0.7 + 0.3 * k)                                               # (sube la intensidad)
    # final abierto: la última nota (FA) suena hasta el corte, sin caer
    return y


# ── VIDA EXTRA ─────────────────────────────────────────────────────────────────
def one_up():
    n = TARGET['items/one_up'][0]
    y = np.zeros(n)
    # "boing" de gelatina: tono que sube de 330 a 990 Hz con vibrato rápido, timbre triangular
    m = int(SR * 0.22)
    tt = t_(m)
    f = 330 * 3 ** (tt / 0.22) * (1 + 0.06 * np.sin(2 * np.pi * 22 * tt))
    y[:m] += 0.8 * tri(np.cumsum(f) / SR) * env(m, 0.004, 0.2)
    # destello: do6 + la6 a la vez (sexta mayor), pulso fino, que se apaga
    m = int(SR * 0.36)
    tt = t_(m)
    d = 0.6 * square(1046.5 * tt, 0.125) + 0.45 * square(1760.0 * tt, 0.25)
    a = int(SR * 0.2)
    y[a:a + m] += d * env(m, 0.003, 0.14)
    return y


if __name__ == '__main__':
    save('water/warning', warning())
    save('water/air_gasp', air_gasp())
    save('water/glugluglu', glugluglu())
    save('water/drowning', drowning())
    save('items/one_up', one_up())
    print('BPM del ahogo: %d → %d' % (BPM0, BPM1))
