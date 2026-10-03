#!/usr/bin/env python3
# tools/music/study.py
# ESTUDIO de la banda sonora (para docs/musica/GUIA_MUSICAL.md): saca de los .mid de tools/music/mid/ (los que
# escriben los generadores) lo que define cada pista — tempo, tonalidad (perfil de clases de altura ponderado por
# duración, Krumhansl), ámbito y registro de la melodía, intervalos, densidad rítmica, síncopa, células rítmicas e
# interválicas más repetidas — y qué células comparten las pistas entre sí (los "motivos de la casa").
#   ~/.venvs/fm-music/bin/python tools/music/study.py
import glob, os, collections
import mido
import numpy as np

NOTES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
MAJ = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MIN = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])


def notes_of(path):
    mid = mido.MidiFile(path)
    tpb, tempo, out = mid.ticks_per_beat, 500000, []
    for ti, tr in enumerate(mid.tracks):
        t, on = 0, {}
        for m in tr:
            t += m.time
            if m.type == 'set_tempo': tempo = m.tempo
            if m.type == 'note_on' and m.velocity > 0: on[(m.channel, m.note)] = t
            elif m.type in ('note_off', 'note_on') and (m.channel, m.note) in on:
                t0 = on.pop((m.channel, m.note))
                out.append((t0 / tpb, (t - t0) / tpb, m.note, m.channel, ti))
    return sorted(out), 60e6 / tempo


def study(path):
    N, bpm = notes_of(path)
    mel_n = [n for n in N if n[3] != 9]
    if not mel_n: return None
    pc = np.zeros(12)
    for t, d, n, ch, tr in mel_n: pc[n % 12] += d
    key = max((np.corrcoef(np.roll(M, k), pc)[0, 1], NOTES[k] + (' mayor' if M is MAJ else ' menor')) for k in range(12) for M in (MAJ, MIN))
    # la MELODÍA: la voz (pista, canal) más aguda de media entre las que tienen bastantes notas
    by = collections.defaultdict(list)
    for x in mel_n: by[(x[4], x[3])].append(x)
    voices = [(np.mean([x[2] for x in v]), k) for k, v in by.items() if len(v) > 40]
    lead = by[max(voices)[1]] if voices else mel_n
    # monofónica: la más aguda en cada instante
    lead = sorted(lead)
    mono = []
    for x in lead:
        if mono and abs(x[0] - mono[-1][0]) < 0.02:
            if x[2] > mono[-1][2]: mono[-1] = x
        else: mono.append(x)
    iv = [b[2] - a[2] for a, b in zip(mono, mono[1:])]
    durs = [round(b[0] - a[0], 2) for a, b in zip(mono, mono[1:])]
    step = np.mean([abs(i) <= 2 for i in iv]); leap = np.mean([abs(i) >= 5 for i in iv]); rep = np.mean([i == 0 for i in iv])
    off = np.mean([abs((x[0] * 2) % 1) > 0.05 for x in mono])          # no cae en corchea
    synco = np.mean([abs(x[0] % 1 - 0.5) < 0.05 or abs(x[0] % 1 - 0.75) < 0.05 or abs(x[0] % 1 - 0.25) < 0.05 for x in mono])
    cells = collections.Counter(tuple(iv[i:i + 3]) for i in range(len(iv) - 2))
    rcells = collections.Counter(tuple(durs[i:i + 3]) for i in range(len(durs) - 2))
    beats = max(x[0] + x[1] for x in N)
    return dict(name=os.path.basename(path)[:-4], bpm=bpm, key=key[1], r=key[0], lo=min(x[2] for x in mono), hi=max(x[2] for x in mono),
                mean=np.mean([x[2] for x in mono]), nps=len(mono) / (beats * 60 / bpm), step=step, leap=leap, rep=rep, off=off, synco=synco,
                cells=cells, rcells=rcells, bars=beats / 4, voices=len(by))


if __name__ == '__main__':
    R = [s for s in (study(f) for f in sorted(glob.glob(os.path.join(os.path.dirname(__file__), 'mid', '*.mid')))) if s]
    nm = lambda n: NOTES[n % 12] + str(n // 12 - 1)
    for s in R:
        print('%-22s %5.1f BPM  %-9s (r %.2f)  %3.0f compases  %d voces  melodía %s-%s (media %s)  %.1f notas/s  grados conjuntos %2.0f%%  saltos≥4ª %2.0f%%  repetidas %2.0f%%  a contratiempo %2.0f%%'
              % (s['name'], s['bpm'], s['key'], s['r'], s['bars'], s['voices'], nm(s['lo']), nm(s['hi']), nm(int(s['mean'])), s['nps'],
                 s['step'] * 100, s['leap'] * 100, s['rep'] * 100, s['synco'] * 100))
        print('    células de intervalos: ' + '  '.join('%s×%d' % (c, n) for c, n in s['cells'].most_common(5)))
        print('    células rítmicas (tiempos): ' + '  '.join('%s×%d' % (c, n) for c, n in s['rcells'].most_common(4)))
    # células de intervalos que aparecen (≥ 4 veces) en varias pistas
    share = collections.defaultdict(list)
    for s in R:
        for c, n in s['cells'].items():
            if n >= 4 and any(c): share[c].append(s['name'])
    print('\nCélulas compartidas por 3 o más pistas:')
    for c, names in sorted(share.items(), key=lambda kv: -len(kv[1])):
        if len(names) >= 3: print('   %s  en %d: %s' % (c, len(names), ', '.join(names)))
