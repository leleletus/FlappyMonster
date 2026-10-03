#!/usr/bin/env python3
# Para los vídeos de la banda sonora (tools/video/ost): el ESPECTRO de la pista, fotograma a fotograma, para las
# barras del visualizador. Una línea por fotograma de vídeo, con N números 0-99 (bandas de grave a agudo, en escala
# logarítmica de 40 Hz a 12 kHz; cada banda normalizada a su propio máximo, con caída suave).
#   python tools/video/spectrum.py <audio.wav> <fps> <bandas> <salida.txt>
import sys
import numpy as np
import soundfile as sf

wav, fps, nb, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
y, sr = sf.read(wav)
if y.ndim == 2: y = y.mean(1)
N = 2048
frames = int(len(y) / sr * fps)
edges = np.geomspace(40, 12000, nb + 1)
freqs = np.fft.rfftfreq(N, 1 / sr)
win = np.hanning(N)
M = np.zeros((frames, nb))
for f in range(frames):
    c = int((f + 0.5) / fps * sr)
    seg = y[max(0, c - N // 2):c + N // 2]
    if len(seg) < N: seg = np.pad(seg, (0, N - len(seg)))
    sp = np.abs(np.fft.rfft(seg * win))
    for b in range(nb):
        m = (freqs >= edges[b]) & (freqs < edges[b + 1])
        M[f, b] = np.sqrt(np.mean(sp[m] ** 2)) if m.any() else 0
db = 20 * np.log10(M + 1e-6)
top = np.percentile(db, 99, axis=0)                # cada banda, respecto a su propio máximo (las graves no se comen a las agudas)
v = np.clip((db - (top - 22)) / 22, 0, 1) ** 1.3
for f in range(1, frames):                          # caída suave: sube de golpe, baja poco a poco
    v[f] = np.maximum(v[f], v[f - 1] - 0.13)
np.savetxt(out, np.round(v * 99).astype(int), fmt='%d')
print('espectro: %d fotogramas x %d bandas → %s' % (frames, nb, out))
