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
#   drowning    la MÚSICA de urgencia del ahogo (12,1 s): ver drowning() — el motivo de dos notas a un semitono
#               (mi5 – fa5) en bucle, de 132 a 264 BPM, 4 canales de chip y un golpe final resuelto en mi pero tenso
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
BPM0, BPM1 = 132, 264
E2, F2 = 82.41, 87.31
E5, F5, G5, BB5 = 659.26, 698.46, 783.99, 932.33


def _note(y, t, dur, fn, gain, n):
    a = int(SR * t)
    m = min(int(SR * dur), n - a)
    if m <= 0: return
    y[a:a + m] += gain * fn(t_(m))


def _kick(tt): return np.sin(2 * np.pi * np.cumsum(150 * np.exp(-tt / 0.03) + 45) / SR) * np.exp(-tt / 0.07)
def _snare(tt): return (rng.standard_normal(len(tt)) * 0.8 + 0.4 * square(190 * tt)) * np.exp(-tt / 0.05)
def _hat(tt): return rng.standard_normal(len(tt)) * np.exp(-tt / 0.012)


def drowning():
    """La música de urgencia (receta del usuario, 2ª versión: "más instrumentación de urgencia, si no suena vacía";
    y como la de Sonic 1, que TERMINE resuelta pero en tensión, para dar paso al glu-glu).
    Cuatro canales de chip, como una consola de 8 bits (nunca más de 4 a la vez):
      1. pulso 25 %: el motivo mi5 – fa5 en corcheas (en semicorcheas en la última parte)
      2. pulso 12,5 %: el mismo motivo una tercera menor arriba (sol5 – la♭5), desde la parte B
      3. triángulo: el bajo, mi2 – fa2 en octavas que saltan (corcheas → semicorcheas)
      4. ruido: charles en cada corchea desde el principio; bombo y caja desde la parte B; redobles al final
    Partes (el tempo sube SIEMPRE de 132 a 264 BPM): A 0–3 s · B 3–6,5 s · C 6,5–9,5 s · D 9,5 s – golpe.
    Final: a 0,55 s del fin, un GOLPE seco de todos en MI (la nota de reposo: resuelve el vaivén mi–fa) con el sol y
    el si♭ encima (acorde disminuido: tensión) y un platillo corto; luego silencio para el glu-glu."""
    n = TARGET['water/drowning'][0]
    total = n / SR
    hit = total - 0.55
    y = np.zeros(n)
    t, i = 0.0, 0
    while t < hit:
        bpm = BPM0 + (BPM1 - BPM0) * (t / total)
        eighth = 60.0 / bpm / 2
        part = 'A' if t < 3 else 'B' if t < 6.5 else 'C' if t < 9.5 else 'D'
        k = t / total
        up = i % 2 == 1
        sub = 2 if part == 'D' else 1                    # (la última parte, en semicorcheas)
        for s_ in range(sub):
            ts = t + s_ * eighth / sub
            if ts >= hit: break
            upS = (i * sub + s_) % 2 == 1
            f = F5 if upS else E5
            d = eighth / sub * 0.72
            _note(y, ts, d, lambda tt, f=f: square(f * tt, 0.25) * np.exp(-tt / 0.6), 0.42, n)          # 1
            if part != 'A':
                h = G5 * 2 ** (1 / 12) if upS else G5                                                  # 2 sol5 – la♭5
                _note(y, ts, d, lambda tt, h=h: square(h * tt, 0.125) * np.exp(-tt / 0.4), 0.26, n)
        # 3. bajo: corcheas en A/B (mi2/fa2 con salto de octava), semicorcheas en C/D
        bsub = 1 if part in ('A', 'B') else 2
        for s_ in range(bsub):
            ts = t + s_ * eighth / bsub
            if ts >= hit: break
            base = F2 if up else E2
            fb = base * (2 if s_ % 2 == 1 else 1)
            _note(y, ts, eighth / bsub * 0.8, lambda tt, fb=fb: tri(fb * tt), 0.5 if part != 'A' else 0.35, n)
        # 4. ruido
        _note(y, t, 0.03, _hat, 0.16 + 0.1 * k, n)
        if part != 'A':
            beat = i % 4
            if beat == 0: _note(y, t, 0.12, _kick, 0.75, n)
            if beat == 2: _note(y, t, 0.1, _snare, 0.42, n)
            if part == 'D' and beat == 3:                 # redoble: dos golpes más de caja
                _note(y, t, 0.05, _snare, 0.3, n)
                _note(y, t + eighth / 2, 0.05, _snare, 0.34, n)
        t += eighth
        i += 1
    # GOLPE final: mi (resuelve) con sol y si♭ (disminuido: tensión), platillo y bombo; corto y seco
    m = int(SR * 0.5)
    tt = t_(m)
    a = int(SR * hit)
    m = min(m, n - a)
    tt = tt[:m]
    stab = (0.45 * square(E5 * tt, 0.25) + 0.3 * square(G5 * tt, 0.125) + 0.3 * square(BB5 * tt, 0.25)
            + 0.55 * tri(E2 * tt) + 0.35 * tri(2 * E2 * tt)) * np.exp(-tt / 0.16)
    crash = rng.standard_normal(m) * np.exp(-tt / 0.18) * 0.45
    y[a:a + m] += stab + crash + 0.8 * _kick(tt) * (tt < 0.12)
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
    print('BPM del ahogo: %d → %d' % (BPM0, BPM1))
