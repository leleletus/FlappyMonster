#!/usr/bin/env python3
# tools/sounds/startup.py — la MELODÍA DEL LOGO (assets/sounds/jingles/startup.wav) de la pantalla de inicio
# (src/states/menu/StartupState.lua): seis notas, una por letra de «MTVemo» (re mayor: re5 la5 fa#5 si5 la5 re6,
# una cada STEP s), y un acorde de re con novena que se queda sonando cuando el logo está entero.
# Pulso de 25 % con caída (como el resto del juego) + un triángulo una octava abajo. Tramo más fuerte de 100 ms a
# -12 dBFS. Si cambias STEP o CHORD_AT, cámbialos también en StartupState.lua (NOTE_STEP, CHORD_AT).
# Desde la raíz del repo:  python3 tools/sounds/startup.py
import wave
import numpy as np

SR, STEP, CHORD_AT, TOTAL = 44100, 0.15, 0.90, 2.6
NOTES = [587.33, 880.00, 739.99, 987.77, 880.00, 1174.66]
CHORD = [(146.83, 0.55), (293.66, 0.5), (440.00, 0.45), (739.99, 0.4), (1174.66, 0.38), (1318.51, 0.3)]


def voice(f, d, decay, duty=0.25, tri=0.5):
    t = np.arange(int(SR * d)) / SR
    p = np.where((t * f) % 1 < duty, 1.0, -1.0)
    tr = 2 * np.abs(2 * ((t * f / 2) % 1) - 1) - 1
    env = np.exp(-t / decay) * np.minimum(1, t / 0.004)
    return (p * 0.5 + tr * tri) * env


y = np.zeros(int(SR * TOTAL))
def add(x, at, g):
    i = int(SR * at); x = x[:len(y) - i]; y[i:i + len(x)] += x * g
for i, f in enumerate(NOTES):
    add(voice(f, 0.5, 0.11), i * STEP, 0.55)
for k, (f, g) in enumerate(CHORD):
    add(voice(f, TOTAL - CHORD_AT, 0.55, duty=0.5 if f < 400 else 0.25, tri=0.8), CHORD_AT + k * 0.012, g * 0.5)
# suavizado (los pulsos crudos pinchan en una pantalla en silencio): paso bajo de un polo a ~5 kHz
a = np.exp(-2 * np.pi * 5000 / SR)
for i in range(1, len(y)): y[i] = (1 - a) * y[i] + a * y[i - 1]
y -= np.mean(y)
n = int(SR * 0.1)
best = max(np.mean(y[i:i + n] ** 2) for i in range(0, len(y) - n, n // 4))
y = np.clip(y * (10 ** (-12 / 20) / np.sqrt(best)), -0.98, 0.98)
k = int(SR * 0.25); y[-k:] *= np.linspace(1, 0, k)
with wave.open('assets/sounds/jingles/startup.wav', 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((y * 32767).astype(np.int16).tobytes())
rms = lambda x: 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
print('  assets/sounds/jingles/startup.wav  %.2f s · pico %.1f dBFS · RMS %.1f dBFS · recortadas %d muestras'
      % (len(y) / SR, 20 * np.log10(np.abs(y).max()), rms(y), int((np.abs(y) >= 0.98).sum())))
for i in range(6): print('    nota %d a %.2f s: %.0f Hz, RMS %.1f dBFS' % (i + 1, i * STEP, NOTES[i], rms(y[int(SR * i * STEP):int(SR * (i + 1) * STEP)])))
print('    acorde a %.2f s: RMS %.1f dBFS (primer medio segundo)' % (CHORD_AT, rms(y[int(SR * CHORD_AT):int(SR * (CHORD_AT + 0.5))])))
