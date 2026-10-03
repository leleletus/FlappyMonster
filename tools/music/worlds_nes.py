#!/usr/bin/env python3
# tools/music/worlds_nes.py
# La música de NIVEL de cada isla (música de Famicom; motor: famicom.py), según docs/musica/GUIA_MUSICAL.md:
# una idea por pieza, frases de 8 compases (intro 4 · A · A' · B · A''), más de la mitad de la melodía a
# contratiempo, un compás con el tresillo 3+3+2, y la cita de "la llamada" (el motivo del juego: 5ª-1ª-3ª-5ª, el
# arranque de la música del mapa) al cerrar la frase B, sobre SU acorde. Bucle sin costura.
#
#   PRADERA (Sol mayor, pulso cantarín, bajo saltarín 1-5-8-5, acordes a contratiempo, batería ligera, trino):
#     pradera_1      el TEMA de la pradera (136 BPM). Tres variantes para elegir (--variante A|B|C):
#                      A  melodía a saltitos sobre el tresillo, con la subida pentatónica Sol-La-Si-Re
#                      B  melodía "de canción", en corcheas y por grados
#                      C  la A con flauta (tabla de onda) en vez de pulso, algo más rápida (140)
#     pradera_2      su segunda cara: el mismo motivo en Mi menor (el relativo), 140 BPM, más empuje
#     pradera_bonus  el tema a 152 BPM con batería de "competición" (la arena de Rey de la Colina de la isla)
#
#   python3 tools/music/worlds_nes.py pradera_1 [--variante B] | pradera_2 | pradera_bonus | previas
#   `previas` = las tres variantes de pradera_1 en FlappyMonster_pruebas/musica/ (fuera del repo), sin tocar el juego.
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_n163, q_tri, q_pulse
import tentacle_nes as TN
import gloomy_nes as GN

MAJ, MIN = (0, 4, 7), (0, 3, 7)
C, D, E, G, A, B = 0, 2, 4, 7, 9, 11
D4, E4, G4, A4, B4, C5, D5, E5, Fs5, G5, A5, B5, D6 = 62, 64, 67, 69, 71, 72, 74, 76, 78, 79, 81, 83, 86

# ── PRADERA: la melodía (compás de la frase, semicorchea, nota, duración en semicorcheas) ──
# Frase A, variante A: a saltitos; golpes en 0-3-6 (3+3+2) y la subida pentatónica Sol-La-Si-Re
A_HOP = [
    (1, 0, G4, 3), (1, 3, A4, 3), (1, 6, B4, 2), (1, 8, D5, 4), (1, 12, B4, 2), (1, 14, D5, 2),
    (2, 0, E5, 3), (2, 3, D5, 3), (2, 6, B4, 2), (2, 8, D5, 6),
    (3, 0, G5, 3), (3, 3, E5, 3), (3, 6, D5, 2), (3, 8, E5, 4), (3, 12, D5, 2), (3, 14, B4, 2),
    (4, 0, C5, 3), (4, 3, E5, 3), (4, 6, G5, 2), (4, 8, E5, 6),
    (5, 0, G4, 3), (5, 3, A4, 3), (5, 6, B4, 2), (5, 8, D5, 4), (5, 12, B4, 2), (5, 14, D5, 2),
    (6, 0, Fs5, 3), (6, 3, E5, 3), (6, 6, D5, 2), (6, 8, A4, 4), (6, 12, D5, 2), (6, 14, Fs5, 2),
    (7, 0, G5, 2), (7, 2, E5, 2), (7, 4, C5, 2), (7, 6, E5, 2), (7, 8, Fs5, 2), (7, 10, D5, 2), (7, 12, A4, 2), (7, 14, D5, 2),
]
A_HOP_END = [(8, 0, B4, 2), (8, 2, D5, 2), (8, 4, G5, 8)]                       # cierra abajo (pregunta)
A_HOP_END2 = [(8, 0, G5, 3), (8, 3, A5, 3), (8, 6, B5, 2), (8, 8, G5, 8)]        # cierra arriba (respuesta)
# Frase A, variante B: "de canción", en corcheas y por grados
A_SONG = [
    (1, 0, D5, 2), (1, 2, E5, 2), (1, 4, D5, 2), (1, 6, B4, 2), (1, 8, G4, 2), (1, 10, B4, 2), (1, 12, D5, 4),
    (2, 0, E5, 2), (2, 2, G5, 2), (2, 4, E5, 2), (2, 6, D5, 2), (2, 8, B4, 6), (2, 14, D5, 2),
    (3, 0, E5, 2), (3, 2, Fs5, 2), (3, 4, G5, 4), (3, 8, E5, 2), (3, 10, D5, 2), (3, 12, B4, 4),
    (4, 0, C5, 2), (4, 2, D5, 2), (4, 4, E5, 4), (4, 8, G5, 8),
    (5, 0, D5, 2), (5, 2, E5, 2), (5, 4, D5, 2), (5, 6, B4, 2), (5, 8, G4, 2), (5, 10, B4, 2), (5, 12, D5, 4),
    (6, 0, Fs5, 2), (6, 2, E5, 2), (6, 4, D5, 2), (6, 6, A4, 2), (6, 8, D5, 2), (6, 10, E5, 2), (6, 12, Fs5, 4),
    (7, 0, G5, 2), (7, 2, E5, 2), (7, 4, C5, 4), (7, 8, A4, 2), (7, 10, D5, 2), (7, 12, Fs5, 4),
]
A_SONG_END = [(8, 0, G5, 10)]
A_SONG_END2 = [(8, 0, G5, 4), (8, 4, B5, 4), (8, 8, G5, 8)]
# Frase B (contraste: más alta y en notas largas) y, al cerrar, LA LLAMADA: Re-Sol-Si-Re sobre Sol
PH_B = [
    (1, 0, C5, 4), (1, 4, E5, 4), (1, 8, G5, 6), (1, 14, E5, 2),
    (2, 0, D5, 6), (2, 6, B4, 2), (2, 8, G4, 4), (2, 12, B4, 4),
    (3, 0, C5, 4), (3, 4, E5, 4), (3, 8, A5, 6), (3, 14, G5, 2),
    (4, 0, Fs5, 6), (4, 6, E5, 2), (4, 8, D5, 8),
    (5, 0, E5, 3), (5, 3, G5, 3), (5, 6, E5, 2), (5, 8, C5, 3), (5, 11, E5, 3), (5, 14, G5, 2),
    (6, 0, D5, 3), (6, 3, G5, 3), (6, 6, D5, 2), (6, 8, B4, 3), (6, 11, D5, 3), (6, 14, G5, 2),
    (7, 0, A5, 2), (7, 2, G5, 2), (7, 4, E5, 2), (7, 6, C5, 2), (7, 8, D5, 2), (7, 10, Fs5, 2), (7, 12, A5, 4),
    (8, 0, D5, 4), (8, 4, G5, 2), (8, 6, B5, 2), (8, 8, D6, 6),
]
CH_A = [(G, MAJ), (G, MAJ), (E, MIN), (C, MAJ), (G, MAJ), (D, MAJ), (C, MAJ), (G, MAJ)]
CH_A7 = (D, MAJ)                                  # (el compás 7 de A: Do | Re, medio compás cada uno)
CH_B = [(C, MAJ), (G, MAJ), (A, MIN), (D, MAJ), (C, MAJ), (G, MAJ), (A, MIN), (G, MAJ)]
INTRO = 4

G_MAJOR = [0, 2, 4, 5, 7, 9, 11]                  # (grados desde Do: la escala de Sol mayor = Do# no, Fa#)


def shift_diatonic(n, steps, scale=(7, 9, 11, 0, 2, 4, 6)):
    """Mueve una nota `steps` grados dentro de Sol mayor (para pasar el tema a Mi menor: 2 grados abajo)"""
    pcs = list(scale)
    pc, octv = n % 12, n // 12
    i = pcs.index(pc) if pc in pcs else min(range(7), key=lambda k: abs(pcs[k] - pc))
    j = i + steps
    # (la escala empieza en Sol: al pasar de Fa# a Sol hacia arriba sube la "octava de la escala")
    order = sorted(range(7), key=lambda k: pcs[k])
    abs_ = [octv * 12 + pcs[k] for k in range(7)]
    idx = order.index(i) + steps
    o2, k2 = divmod(idx, 7)
    return (octv + o2) * 12 + pcs[order[k2]]


def song(variant, minor=False):
    """→ (melodía [(compás, semicorchea, nota, dur)], acordes por medio compás [(raíz, tipo)] ×2 por compás, nº de compases)"""
    pa, e1, e2 = (A_SONG, A_SONG_END, A_SONG_END2) if variant == 'B' else (A_HOP, A_HOP_END, A_HOP_END2)
    mel, ch = [], []
    def add(ph, base):
        for b, st, n, d in ph: mel.append((base + b, st, n, d))
    def chords(seq, seventh):
        for i, c in enumerate(seq):
            ch.append((c, seventh if (seventh and i == 6) else c))
    for _ in range(INTRO): ch.append(((G, MAJ), (G, MAJ)))
    add(pa + e1, INTRO); chords(CH_A, CH_A7)
    add(pa + e2, INTRO + 8); chords(CH_A, CH_A7)
    add(PH_B, INTRO + 16); chords(CH_B, CH_A7)
    add(pa + e2, INTRO + 24); chords(CH_A, CH_A7)
    if minor:
        # el relativo: todo dos grados abajo (Sol mayor → Mi menor); acordes: su relativo
        REL = {(G, MAJ): (E, MIN), (E, MIN): (C, MAJ), (C, MAJ): (A, MIN), (D, MAJ): (B, MIN), (A, MIN): (D, MAJ)}
        mel = [(b, st, shift_diatonic(n, -2), d) for b, st, n, d in mel]
        ch = [(REL[a], REL[b_]) for a, b_ in ch]
    return mel, ch, INTRO + 32


I_LEAD = {'vol': [15, 14, 13, 13, 12, 12], 'sus': 12, 'vib': (12, 0.22, 5.6), 'duty': [0.25, 0.5]}
I_FLUTE = {'vol': [9, 12, 14, 14, 13, 13], 'sus': 12, 'vib': (10, 0.25, 5.4)}
I_PLUCK = {'vol': [12, 9, 6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_TRI = {'vol': [15], 'sus': 15}
I_TRILL = {'vol': [9, 8, 7, 6, 5, 4], 'sus': 3, 'duty': 0.125}
I_ECHO = {'vol': [5, 5, 4, 3], 'sus': 2, 'duty': 0.5}
WAVES = [wavetable([1.0, 0.45, 0.12, 0.2, 0.03]),            # 0 flauta
         wavetable([1.0, 0.3, 0.1])]                         # 1 colchón
HAT, SNARE_N, CRASH = [5, 2, 1], [13, 9, 5, 2], [13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]


def build(name, variant='A', bpm=136, minor=False, drive=0, lufs=-11.5):
    """drive: 0 = tema (batería ligera) · 1 = segunda cara (más empuje) · 2 = bonus (competición)"""
    S16 = 60.0 / bpm / 4
    BAR = 16 * S16
    mel, ch, NB = song(variant, minor)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'echo', 'c1', 'c2', 'bass', 'trill')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn = np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16
    flute = variant == 'C'

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    busy = set()
    for b, st, n, d in mel:
        t0, t1 = tv(b, st), tv(b, st) + d * S16 * 0.94
        if flute: play(Cn['lead'], t0, t1, n, dict(I_FLUTE, duty=0.0), q=q_n163, release=3)
        else: play(Cn['lead'], t0, t1, n, I_LEAD, release=3)
        # eco: la misma nota 3 semicorcheas después, floja (más melodía de la que se toca)
        if d >= 3: play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 3) * S16 * 0.8, n, I_ECHO, release=1)
        for k in range(d): busy.add((b, st + k))
    last_in_bar = {}
    for b, st, n, d in mel: last_in_bar[b] = max(last_in_bar.get(b, 0), st + d)

    for b in range(1, NB + 1):
        intro = b <= INTRO
        in_b = INTRO + 16 < b <= INTRO + 24
        for half in (0, 1):
            r, q = ch[b - 1][half]
            root = 36 + (r - 36) % 12
            notes = [60 + (r - 60) % 12 + iv for iv in q]
            s0 = half * 8
            # BAJO saltarín: 1-5-8-5 en corcheas (en la intro entra en el compás 3; en B, negras)
            if not intro or b >= 3:
                pat = ((0, 0, 3.4), (4, 12, 3.4)) if in_b else ((0, 0, 1.7), (2, 7, 1.7), (4, 12, 1.7), (6, 7, 1.7))
                if drive: pat = ((0, 0, 1.6), (2, 12, 1.6), (4, 0, 1.6), (6, 7, 1.6))
                for st, iv, ln in pat:
                    play(Cn['bass'], tv(b, s0 + st), tv(b, s0 + st) + ln * S16, root + iv, I_TRI, q=q_tri, release=0)
            # ACORDES a contratiempo (en las "y")
            for st in (2, 6):
                play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + S16, notes[0] + 12 if notes[0] < 64 else notes[0], I_PLUCK, release=1)
                play(Cn['c2'], tv(b, s0 + st), tv(b, s0 + st) + S16, notes[1] + (12 if notes[1] < 66 else 0), I_PLUCK, release=1)
        # TRINO de pájaro (el motivo de la isla): donde la melodía se queda quieta, y en la intro
        free_from = last_in_bar.get(b, 0)
        long_tail = any(bb == b and st + d >= 14 and d >= 6 for bb, st, n, d in mel)
        if (intro and b % 2 == 0) or (long_tail and not in_b):
            r, q = ch[b - 1][1]
            top = 84 + (r - 84) % 12 + q[2] - 12
            for i, st in enumerate(range(10, 16)):
                play(Cn['trill'], tv(b, st), tv(b, st) + S16 * 0.9, top + (2 if i % 2 else 0), I_TRILL, release=0)
        # BATERÍA
        for st in range(16):
            t = tv(b, st)
            if intro and b < 3:
                if st % 4 == 2: NZ['hat'].hit(t, 0, HAT)
                continue
            if drive == 2:                                   # competición: bombo a negras, caja en 2 y 4, platos en semicorcheas
                if st % 4 == 0: hit(kick, TN.KICK, t, 0.95)
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.8)
                NZ['hat'].hit(t, 0, HAT if st % 2 == 0 else [3, 1])
            else:
                if st in (0, 6, 8) or (drive and st == 14): hit(kick, TN.KICK, t, 0.8 if st else 0.9)      # 3+3+2
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.55 + 0.2 * drive)
                if st % 2 == 0: NZ['hat'].hit(t, 0, HAT)
                elif drive: NZ['hat'].hit(t, 0, [3, 1])
            if st == 0 and b in (INTRO + 1, INTRO + 9, INTRO + 17, INTRO + 25): NZ['crash'].hit(t, 3, CRASH)
            # redoble de entrada: el último medio compás antes de cada frase
            if b in (INTRO, INTRO + 8, INTRO + 16, INTRO + 24) and st >= 12: NZ['snare'].hit(t, 4, [9, 5, 2])

    n = int(NB * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k: cut(F.pulse_dac(F.render_pulse(Cn[k])))
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    S = {
        'lead': cut(F.render_wave(Cn['lead'], WAVES) * 0.0075) if flute else pulse('lead'),
        'echo': pulse('echo'), 'chords': pulse('c1') + pulse('c2'),
        'bass': cut(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)), 'trill': pulse('trill'),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + cut(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
        'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12)), 'crash': cut(F.tnd_dac(NZ['crash'].render() / 22638.0 * 12)),
    }
    S = {k: GN.fold(v, n) for k, v in S.items() if np.abs(v).max() > 0}
    LV = {'lead': 0, 'echo': -11, 'chords': -6, 'bass': -2, 'trill': -6, 'kick': -2 + drive, 'snare': -5 + drive, 'hat': -12, 'crash': -11}
    g = GN.level(S, {k: LV[k] for k in S}, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    side = S['chords'] * g['chords'] * 0.35 - S['echo'] * g['echo'] * 0.6 + S['trill'] * g['trill'] * 0.4 + S['hat'] * g['hat'] * 0.3
    y = F.master(np.stack([x + side, x - side], 1), lufs=lufs)
    GN.report(name, y, S, g, n)
    off = np.mean([st % 4 != 0 for b, st, nn, d in mel])
    print(f'  {bpm} BPM, {NB} compases ({NB * BAR:.1f} s); melodía: {len(mel)} notas, {100 * off:.0f} % fuera del tiempo, '
          f'ámbito {min(m[2] for m in mel)}-{max(m[2] for m in mel)}')
    return y, mel, bpm


def write_mid(path, mel, bpm):
    import mido
    mid = mido.MidiFile(ticks_per_beat=480)
    tr = mido.MidiTrack(); mid.tracks.append(tr)
    tr.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / bpm), time=0))
    ev = []
    for b, st, n, d in mel:
        t0 = ((b - 1) * 16 + st) * 120
        ev += [(t0, 'note_on', n), (t0 + d * 120 - 10, 'note_off', n)]
    t = 0
    for tt, kind, n in sorted(ev):
        tr.append(mido.Message(kind, note=n, velocity=96, time=tt - t)); t = tt
    mid.save(path)


TRACKS = {
    'pradera_1':     dict(variant='A', bpm=136),
    'pradera_2':     dict(variant='A', bpm=140, minor=True, drive=1),
    'pradera_bonus': dict(variant='A', bpm=152, drive=2, lufs=-11.0),
}
VARIANTS = {'A': dict(variant='A', bpm=136), 'B': dict(variant='B', bpm=132), 'C': dict(variant='C', bpm=140)}

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    var = sys.argv[sys.argv.index('--variante') + 1] if '--variante' in sys.argv else None
    for a in args:
        if a == 'previas':
            out = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'musica')
            os.makedirs(out, exist_ok=True)
            for v, kw in VARIANTS.items():
                y, mel, bpm = build('pradera_1 variante ' + v, **kw)
                wav = os.path.join(out, 'pradera_1_%s.wav' % v)
                F.write_wav(wav, y)
                os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{wav[:-4]}.ogg"'); os.remove(wav)
                print('  ' + wav[:-4] + '.ogg')
            continue
        kw = dict(TRACKS[a])
        if var and a == 'pradera_1': kw = dict(VARIANTS[var])
        y, mel, bpm = build(a, **kw)
        if not os.environ.get('REPORT'):
            GN.export(a, y)
            write_mid(F.out(a, 'mid'), mel, bpm)
