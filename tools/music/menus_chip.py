#!/usr/bin/env python3
# tools/music/menus_chip.py
# "Menús" (el tema principal del juego) rehecho en chiptune DE VERDAD. El
# original (assets/music/menus.ogg, ya no se carga) es una canción del usuario con un
# efecto "crunch" encima; aquí se recrea nota a nota a partir de su ANÁLISIS
# (librosa: ver el final del archivo) con instrumentos de consola de 8 bits.
#
#   python3 tools/music/menus_chip.py   → assets/music/menus_chip.ogg (+ .mid)
#   SOLO=lead,bass python3 ...          → solo esas pistas (para escucharlas)
#
# Lo medido en el original:
#   · 140 BPM exactos en 4/4, 18 compases (30.86 s) en bucle; el compás 1
#     empieza a los 0.03 s.
#   · Forma: 3 frases de 6 compases (5 + uno de enlace); el bucle empieza en
#     un enlace:
#       1  enlace/intro: escala cromática que baja de Sol (sin bajo, "stop time")
#       2-7   A A B A C | 7 = bajada cromática del bajo (Sol → Si) con la escala
#       8-13  A A B A C | 13 = el enlace otra vez (una octava más arriba)
#       14-18 A A B A C | → vuelve al 1
#     A = Do, B = Fa, C = Re (I-IV-I-II-V, un boogie).
#   · Bajo boogie en corcheas: C E G A C' E G A (Fa y Re igual), acordes de
#     sexta sostenidos (C6, F6, D6; G7 en el 7), bombo en cada negra, hi-hat
#     en las corcheas.
#   · Melodía (solo en la 2ª frase): lick de blues con la escala de blues de Do
#     (Re# → Do como apoyatura, Mi-Re, La-Sol).
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from tentacle_chip import pulse, tri, noise, adsr, lowpass, highpass, Track, t_, hz, SR   # (síntesis chip común)

BPM = 140
SIX = 60.0 / BPM / 4                 # s por semicorchea
BAR = 16 * SIX
NBARS = 18
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'music')
NAME = 'menus_chip'

# ── Partitura ────────────────────────────────────────────────────────────────
# Tipo de cada compás (1-18)
FORM = ['X', 'A', 'A', 'B', 'A', 'C', 'W',
             'A', 'A', 'B', 'A', 'C', 'X',
             'A', 'A', 'B', 'A', 'C']
# Bajo en corcheas (MIDI)
BASS = {
    'A': [36, 40, 43, 45, 48, 40, 43, 45],          # Do: C E G A C' E G A
    'B': [29, 33, 36, 38, 41, 33, 36, 38],          # Fa: F A C D F' A C D
    'C': [38, 42, 45, 47, 38, 42, 45, 47],          # Re: D F# A B
    'W': [43, 42, 41, 40, 38, 37, 36, 35],          # bajada cromática Sol → Si (a Do)
}
# Acordes sostenidos (sexta del boogie)
PAD = {'A': [48, 52, 55, 57], 'B': [48, 50, 53, 57], 'C': [50, 54, 57, 59], 'W': [53, 55, 59, 62]}
# La escala del enlace: (semicorchea, semitonos desde Sol, duración)
RUN = [(0, 0, 2), (2, -1, 1), (3, -2, 2), (5, -3, 2), (7, -4, 2), (9, -5, 1), (10, -6, 1), (11, -7, 2), (14, -9, 2)]
RUN_BASE = {1: 67, 7: 67, 13: 79}                   # Sol4 (intro y compás 7), Sol5 (el break)
PICKUP = {13: (12, 43, 4)}                         # Sol2 del bajo al final del break (en la intro no)
# Melodía de la 2ª frase: compás → [(semicorchea, nota, duración)]
MEL = {
    8:  [(0, 75, 1), (1, 72, 7), (8, 76, 1), (9, 74, 3), (12, 69, 2), (14, 72, 2)],
    9:  [(0, 75, 1), (1, 72, 4), (5, 69, 2), (7, 67, 5), (12, 72, 3), (15, 75, 1)],
    10: [(0, 75, 3), (3, 72, 1), (4, 69, 2), (6, 72, 2), (8, 76, 1), (9, 74, 2), (11, 69, 3), (14, 72, 1), (15, 75, 1)],
    11: [(0, 75, 1), (1, 72, 5), (6, 76, 3), (9, 74, 2), (11, 67, 2), (13, 69, 2), (15, 74, 1)],
    12: [(0, 74, 5), (5, 72, 1), (6, 74, 2), (8, 76, 2), (10, 74, 1), (11, 72, 1), (12, 69, 2), (14, 72, 2)],
}


# ── Instrumentos ─────────────────────────────────────────────────────────────
def bass_voice(m, n, gate):
    """Bajo: triángulo de la NES (cuerpo) + pulso del 25 % (mordida, la del original)"""
    f = hz(m)
    env = adsr(n, a=0.002, d=0.12, s=0.7, r=0.02, gate=gate)
    return (tri(f, n) * 0.75 + pulse(f, n, 0.25) * 0.35) * env


def lead_voice(m, n, gate, ln):
    """Lead: dos pulsos (25 % + 50 % desafinado, efecto coro) con vibrato en
    las notas largas"""
    f = hz(m)
    vib = 0.22 if ln >= 3 else 0.0
    env = adsr(n, a=0.003, d=0.09, s=0.8, r=0.03, gate=gate)
    a = pulse(f, n, 0.25, vib=vib, vib_rate=6.0, vib_delay=0.12, bend=-0.6, bend_t=0.01)
    b = pulse(f * 2 ** (6 / 1200), n, 0.5, vib=vib, vib_rate=6.0, vib_delay=0.12)
    return (a * 0.6 + b * 0.35) * env


def pad_voice(m, n):
    """Acorde: pulso fino (12.5 %), suave y sostenido"""
    env = adsr(n, a=0.012, d=0.25, s=0.6, r=0.05, gate=n / SR - 0.05)
    return pulse(hz(m), n, 0.125) * env


def kick(n):
    t = t_(n)
    f = 50 + 110 * np.exp(-t / 0.025)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12)


def hat(n, open_=False):
    t = t_(n)
    return highpass(noise(n), 7000) * np.exp(-t / (0.09 if open_ else 0.018))


# ── Render ───────────────────────────────────────────────────────────────────
def render():
    total = NBARS * BAR
    lead, bass, pad, kik, hh = (Track(total) for _ in range(5))
    ev = {'lead': [], 'bass': [], 'pad': [], 'drums': []}
    for bi in range(NBARS):
        b = bi + 1
        kind = FORM[bi]
        t0 = bi * BAR
        # Bajo
        if kind in BASS:
            for e, m in enumerate(BASS[kind]):
                n = int((2 * SIX + 0.03) * SR)
                bass.add(t0 + e * 2 * SIX, bass_voice(m, n, 2 * SIX * 0.82))
                ev['bass'].append((t0 + e * 2 * SIX, m, 2 * SIX * 0.82))
        else:
            # Enlace ("stop time"): solo un golpe de Sol al empezar (la anacrusa
            # del final la hace el bombo)
            for st in (0,):
                n = int((2 * SIX + 0.03) * SR)
                bass.add(t0 + st * SIX, bass_voice(43, n, 2 * SIX * 0.8))
                ev['bass'].append((t0 + st * SIX, 43, 2 * SIX * 0.8))
            # (en el break, además, un Sol largo de anacrusa hacia el Do)
            if b in PICKUP:
                st, m, ln = PICKUP[b]
                n = int((ln * SIX + 0.03) * SR)
                bass.add(t0 + st * SIX, bass_voice(m, n, ln * SIX * 0.9))
                ev['bass'].append((t0 + st * SIX, m, ln * SIX * 0.9))
        # Acordes
        if kind in PAD:
            n = int((BAR + 0.02) * SR)
            for m in PAD[kind]:
                pad.add(t0, pad_voice(m, n), 1.0)
                ev['pad'].append((t0, m, BAR * 0.95))
        # Escala cromática (enlaces y compás 7)
        if b in RUN_BASE:
            for st, dm, ln in RUN:
                m = RUN_BASE[b] + dm
                dur = ln * SIX
                n = int((dur + 0.05) * SR)
                lead.add(t0 + st * SIX, lead_voice(m, n, dur * 0.85, ln), 0.9)
                ev['lead'].append((t0 + st * SIX, m, dur * 0.85))
        # Melodía (2ª frase)
        for st, m, ln in MEL.get(b, []):
            dur = ln * SIX
            n = int((dur + 0.05) * SR)
            lead.add(t0 + st * SIX, lead_voice(m, n, dur * 0.9, ln))
            ev['lead'].append((t0 + st * SIX, m, dur * 0.9))
        # Batería
        if kind in BASS:
            for st in (0, 4, 8, 12):
                kik.add(t0 + st * SIX, kick(int(0.2 * SR)), 1.0)
                ev['drums'].append((t0 + st * SIX, 36, 0.1))
            for st in range(0, 16, 2):
                hh.add(t0 + st * SIX, hat(int(0.06 * SR)), 0.8 if st % 4 else 0.55)
                ev['drums'].append((t0 + st * SIX, 42, 0.05))
        else:
            kik.add(t0, kick(int(0.2 * SR)), 1.0)
            hh.add(t0, hat(int(0.3 * SR), True), 0.8)
            ev['drums'] += [(t0, 36, 0.1), (t0, 46, 0.2)]
            for st in (14, 15):
                kik.add(t0 + st * SIX, kick(int(0.2 * SR)), 0.85)
                ev['drums'].append((t0 + st * SIX, 36, 0.1))

    # ── Mezcla ───────────────────────────────────────────────────────────────
    def st_(tr, g, pan):
        return tr.buf * g * (1 - pan), tr.buf * g * (1 + pan)
    for tr in (lead, pad):
        tr.buf = lowpass(tr.buf, 8000)
    named = [('lead', st_(lead, 0.55, 0.05)), ('bass', st_(bass, 0.95, 0.0)), ('pad', st_(pad, 0.10, -0.2)),
             ('kick', st_(kik, 0.85, 0.0)), ('hat', st_(hh, 0.22, 0.25))]
    solo = os.environ.get('SOLO')
    if solo:
        named = [(nm, p) for nm, p in named if nm in solo.split(',')]
    L = sum(p[0] for _, p in named)
    R = sum(p[1] for _, p in named)
    x = np.stack([L, R], 1)
    # Bucle sin costura: las colas del final se suman al principio
    end = int(total * SR)
    tail = x[end:]
    x = x[:end].copy()
    x[:len(tail)] += tail
    if os.environ.get('RAW'):
        return x, ev
    # nivel como el original (RMS ≈ 0.15 en mono) con compresión suave
    x = x / (np.sqrt(np.mean(x.mean(1) ** 2)) + 1e-9) * 0.16
    x = np.tanh(x * 1.5) / 1.5
    return x, ev


def write_wav(path, x):
    with wave.open(path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())


def write_midi(path, ev):
    import mido
    tpb = 480
    mf = mido.MidiFile(ticks_per_beat=tpb)
    meta = mido.MidiTrack(); mf.tracks.append(meta)
    meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(BPM)))
    meta.append(mido.MetaMessage('time_signature', numerator=4, denominator=4))
    # (canal 10 = batería General MIDI: bombo 36, hi-hat 42, abierto 46)
    for ch, (name, prog) in ((0, ('lead', 80)), (1, ('bass', 38)), (2, ('pad', 81)), (9, ('drums', 0))):
        tr = mido.MidiTrack(); mf.tracks.append(tr)
        tr.append(mido.MetaMessage('track_name', name=name))
        if ch != 9:
            tr.append(mido.Message('program_change', program=prog, channel=ch))
        evs = []
        for t, n, d in ev[name]:
            a = int(round(t / (60 / BPM) * tpb)); b = int(round((t + d) / (60 / BPM) * tpb))
            evs += [(a, 1, n), (b, 0, n)]
        evs.sort(key=lambda e: (e[0], e[1]))
        last = 0
        for tick, on, n in evs:
            tr.append(mido.Message('note_on' if on else 'note_off', note=int(n), velocity=96 if on else 0,
                                   channel=ch, time=tick - last))
            last = tick
    mf.save(path)


if __name__ == '__main__':
    x, ev = render()
    wav = os.path.join(OUT, NAME + '.wav')
    write_wav(wav, x)
    write_midi(os.path.join(OUT, NAME + '.mid'), ev)
    ogg = os.path.join(OUT, NAME + '.ogg')
    os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 5 "{ogg}"')
    os.remove(wav)
    print(f'  {ogg}  {len(x) / SR:.2f} s  (+ {NAME}.mid)')

# ── Cómo se analizó el original (para repetirlo) ─────────────────────────────
#   · Tempo: rejilla de semicorcheas ajustada a la fuerza de los ataques
#     (librosa.onset_strength) → 140.00 BPM, fase 0.03 s; 18 compases exactos.
#   · Forma: similitud entre compases (CQT por semicorchea).
#   · Bajo: librosa.pyin sobre lo de debajo de 250 Hz, por semicorchea.
#   · Acordes: energía media por nota (CQT) en cada tipo de compás.
#   · Melodía: pyin en la banda 500-3000 Hz y, para verla limpia, el compás
#     de la 2ª frase MENOS el mismo compás de la 1ª (que no tiene melodía).
#   · Batería: flujo espectral por bandas (bombo en cada negra; ruido en las
#     corcheas sin acento en 2 y 4: hi-hat, no caja).
