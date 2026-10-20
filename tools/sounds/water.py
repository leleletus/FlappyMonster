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
#   drowning    la MÚSICA de urgencia del ahogo (12,1 s): ver drowning() — trino de semitono sobre un arpegio menor,
#               todo sube un semitono por compás y acelera (140 → 236 BPM); acaba en el acorde de la tónica, temblando
#   one_up      la VIDA EXTRA: arpegio rápido de sol mayor que sube y un trino brillante (ver one_up())
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
BPM0, BPM1 = 140, 236


def _note(y, t, dur, fn, gain, n):
    a = int(SR * t)
    m = min(int(SR * dur), n - a)
    if m <= 0: return
    y[a:a + m] += gain * fn(t_(m))


def blpulse(f, tt, duty):
    """Pulso SIN aliasing (suma de armónicos hasta ~16 kHz): los agudos de un pulso ingenuo raspaban y sonaban raros"""
    out = np.zeros(len(tt))
    for k in range(1, max(1, int(16000 / f)) + 1):
        out += (2 / (k * np.pi)) * np.sin(np.pi * k * duty) * np.cos(2 * np.pi * k * f * tt - np.pi * k * duty)
    return out * 1.6


def gate(tt, d, rel=0.006):
    """Nota de chip: ataque instantáneo, sostenida, cortada al `d` con una caída cortísima"""
    return np.clip((d - tt) / rel, 0, 1) * np.minimum(1, tt / 0.002)


def hz(semis):                                         # semitonos desde la4 (440 Hz)
    return 440.0 * 2 ** (semis / 12)


def drowning():
    """3ª versión, HECHA DE NUEVO (la 2ª, con batería y un golpe disminuido, sonaba rara; el usuario: que la urgencia
    venga de lo extraño que resulta, más en la línea de la original). Inspirada en la FORMA de la de Sonic 1 —una
    figura corta de chip que no para, SUBE de tono cada compás y ACELERA, y acaba en una nota sostenida— sin copiar su
    melodía:
      · voces (pulsos sin aliasing y un triángulo, sin batería ni reverb):
          1. pulso 12,5 %: TRINO en semicorcheas entre la QUINTA y la SEXTA MENOR (mi – fa sobre la menor: el par de
             semitono de la receta) — la parte inquietante
          2. pulso 25 %: arpegio del acorde menor en corcheas (1 – 3 – 5 – 3), una octava abajo
          3. triángulo: el bajo, la tónica en corcheas saltando de octava
      · cada COMPÁS todo sube UN SEMITONO (9 compases: de la menor a fa# menor) y el tempo pasa de 140 a 236 BPM
      · final: la figura se corta y queda el ACORDE de la tónica (resuelto) en lo más agudo, con un temblor rápido de
        volumen (tensión), que se apaga a tiempo para el glu-glu"""
    n = TARGET['water/drowning'][0]
    total = n / SR
    END = total - 0.95                                  # (el acorde final: los últimos 0,95 s)
    y = np.zeros(n)
    t, step, bar = 0.0, 0, 0
    while t < END:
        bpm = BPM0 + (BPM1 - BPM0) * (t / END)
        six = 60.0 / bpm / 4                            # semicorchea
        root = step // 16                               # compás → semitonos que ha subido
        R = root                                        # (la menor = 0)
        pos = step % 16
        # 1. trino quinta / sexta menor, octava 5 (mi5 = la4 + 7 + 12)
        sem = 12 + 7 + (pos % 2)
        _note(y, t, six, lambda tt, f=hz(R + sem), d=six * 0.8: blpulse(f, tt, 0.125) * gate(tt, d), 0.30, n)
        # 2. arpegio del acorde menor en corcheas, octava 4
        if pos % 2 == 0:
            arp = (0, 3, 7, 3)[(pos // 2) % 4]
            _note(y, t, 2 * six, lambda tt, f=hz(R + arp), d=2 * six * 0.7: blpulse(f, tt, 0.25) * gate(tt, d), 0.24, n)
        # 3. bajo: tónica en corcheas, saltando de octava
        if pos % 2 == 0:
            fb = hz(R - 24 + (12 if (pos // 2) % 2 else 0))
            _note(y, t, 2 * six, lambda tt, f=fb, d=2 * six * 0.85: tri(f * tt) * gate(tt, d, 0.01), 0.55, n)
        t += six
        step += 1
    # FINAL: el acorde de la tónica (menor) sostenido, arriba, temblando — resuelto pero tenso
    R = step // 16
    a = int(SR * END)
    m = n - a
    tt = t_(m)
    trem = 0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 18 * tt))          # temblor de volumen (de chip)
    fade = np.exp(-tt / 0.45)
    chord = (0.32 * blpulse(hz(R + 12), tt, 0.125) + 0.26 * blpulse(hz(R + 15), tt, 0.25)
             + 0.26 * blpulse(hz(R + 19), tt, 0.25) + 0.5 * tri(hz(R - 24) * tt))
    y[a:a + m] += chord * trem * fade
    return y


# ── VIDA EXTRA ─────────────────────────────────────────────────────────────────
def one_up():
    """2ª versión (la 1ª, el "boing" de gelatina, sonaba rara): un arpegio rápido que sube por el acorde de SOL mayor
    (sol5 – si5 – re6 – sol6, distinto del de Mario) y la última nota se queda brillando con un trino corto
    con la octava de arriba que se apaga."""
    n = TARGET['items/one_up'][0]
    y = np.zeros(n)
    notes = (783.99, 987.77, 1174.66, 1567.98)
    for i, f in enumerate(notes):
        last = i == len(notes) - 1
        d = 0.26 if last else 0.065
        _note(y, i * 0.055, d, lambda tt, f=f, last=last: (square(f * tt, 0.25) * 0.7 + 0.3 * square(f * 1.003 * tt, 0.5))
              * (np.exp(-tt / 0.16) if last else np.exp(-tt / 0.08)), 0.75, n)
    # trino brillante sol6 – re7 (quinta) que se apaga
    t0 = 0.36
    for j in range(8):
        f = 2349.32 if j % 2 else 1567.98
        _note(y, t0 + j * 0.03, 0.028, lambda tt, f=f: square(f * tt, 0.125) * np.exp(-tt / 0.05), 0.3 * (1 - j / 8), n)
    return y


if __name__ == '__main__':
    save('water/warning', warning())
    save('water/air_gasp', air_gasp())
    save('water/glugluglu', glugluglu())
    save('water/drowning', drowning())
    save('items/one_up', one_up())
    print('ahogo: %d → %d BPM, sube un semitono por compás' % (BPM0, BPM1))
