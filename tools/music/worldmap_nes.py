#!/usr/bin/env python3
# tools/music/worldmap_nes.py
# La música del MAPA DEL MUNDO del modo historia (música de Famicom; motor: famicom.py): UNA canción —
# "Rumbo a las islas" — con la MISMA melodía, acordes, tempo y largo en siete arreglos, uno por isla, para que
# el mapa cambie de versión al cruzar a otra isla sin perder el compás (src/states/story/StoryMapState.lua salta a la
# misma posición de la nueva). Cada isla tiene su instrumentación y su LEITMOTIV (un motivo propio que contesta
# a la melodía en los compases en que esta se queda quieta):
#   map_pradera    pulso cantarín + pulso al 25 % en acordes a contratiempo, triángulo saltarín, batería
#                  ligera; motivo: un trino de pájaro
#   map_costa      "steel drum" (onda del N163 con parciales de campana metálica), bajo de calipso (1, 1y, 3),
#                  maraca en semicorcheas; motivo: arpegio de marimba que sube
#   map_fortaleza  sierra del VRC6 (metal), caja de marcha en redobles, bajo en octavas; motivo: fanfarria de
#                  tresillos
#   map_nieve      caja de música (la del nivel a oscuras) una octava arriba, cascabeles, bajo en blancas,
#                  colchón suave; motivo: campanitas que caen
#   map_cuevas     caja de música con ECO de cueva, a medio tiempo, bombo grave, bordón de triángulo, nada de
#                  platillos; motivo: gotas
#   map_final      sierra + pulso una octava arriba, bajo en corcheas, doble bombo, platillo cada 2 compases;
#                  motivo: golpes de "erupción" (acorde de potencia + ruido)
#   map_jungla     los instrumentos GM de la jungla (gm.py, como jungla_nes.py): flauta de pan GM con la flauta de
#                  madera del N163 una octava abajo, marimba como balafón (nota repetida que rebota por el acorde),
#                  kalimba a contratiempo y colchón de N163 en B, bajo de triángulo que rebota y se acerca por grado
#                  a la raíz siguiente, congas en tumbao, cabasa / maracas en semicorcheas, taiko en las cabezas;
#                  motivo: el TUCÁN (ocarina: la 5ª dos veces y la raíz una 4ª arriba; sobre el Sol7 del compás 12,
#                  la 3ª dos veces y la raíz arriba: solo notas del acorde)
# Forma: A (8) · B (8) · A (8) = 24 compases a 120 BPM = 48 s, bucle sin costura.
# Se comprueba con números (NO se ha escuchado): duración igual en las siete, sonoridad, reparto de energía.
#   python3 tools/music/worldmap_nes.py [pradera costa ...]      REPORT=1 → números, sin exportar
#   (jungla: además tools/music/mid/map_jungla.mid y las previas en FlappyMonster_pruebas/musica/mapa/)
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_n163, q_tri, q_vrc6, q_pulse, q_saw
import tentacle_nes as TN
import gloomy_nes as GN
import jungla_nes as J
import gm as GM

BPM = 120
S16 = 60.0 / BPM / 4
BAR = 16 * S16
MAJ, MIN, DOM = (0, 4, 7), (0, 3, 7), (0, 4, 10)
C, D, E, F_, G, A, B = 0, 2, 4, 5, 7, 9, 11

# ── La melodía (compás, semicorchea, nota, duración en semicorcheas) ─────────
G4, A4, B4, C5, D5, E5, F5, G5, A5, B5, C6 = 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84
MEL_A = [
    (1, 0, G4, 4), (1, 4, C5, 2), (1, 6, E5, 2), (1, 8, G5, 4), (1, 12, E5, 4),          # la llamada: sube por el acorde
    (2, 0, F5, 2), (2, 2, E5, 2), (2, 4, D5, 2), (2, 6, C5, 2), (2, 8, D5, 8),
    (3, 0, E5, 4), (3, 4, C5, 2), (3, 6, A4, 2), (3, 8, G4, 4), (3, 12, C5, 4),
    (4, 0, D5, 10),                                                                    # (se queda: aquí contesta la isla)
    (5, 0, G4, 4), (5, 4, C5, 2), (5, 6, E5, 2), (5, 8, G5, 4), (5, 12, A5, 4),          # la llamada, llega más alto
    (6, 0, G5, 2), (6, 2, F5, 2), (6, 4, E5, 2), (6, 6, D5, 2), (6, 8, E5, 8),
    (7, 0, F5, 4), (7, 4, D5, 2), (7, 6, B4, 2), (7, 8, G4, 4), (7, 12, D5, 4),
    (8, 0, C5, 10),                                                                    # (cierra: contesta la isla)
]
MEL_B = [
    (9, 0, A5, 4), (9, 4, G5, 2), (9, 6, F5, 2), (9, 8, E5, 4), (9, 12, F5, 4),
    (10, 0, G5, 6), (10, 6, E5, 2), (10, 8, C5, 6),
    (11, 0, F5, 4), (11, 4, E5, 2), (11, 6, D5, 2), (11, 8, C5, 4), (11, 12, D5, 4),
    (12, 0, E5, 6), (12, 6, D5, 2), (12, 8, B4, 6),
    (13, 0, A4, 2), (13, 2, C5, 2), (13, 4, F5, 4), (13, 8, E5, 2), (13, 10, D5, 2), (13, 12, C5, 4),
    (14, 0, B4, 2), (14, 2, D5, 2), (14, 4, G5, 4), (14, 8, F5, 2), (14, 10, E5, 2), (14, 12, D5, 4),
    (15, 0, E5, 4), (15, 4, G5, 4), (15, 8, C6, 4), (15, 12, B5, 2), (15, 14, A5, 2),
    (16, 0, G5, 8), (16, 12, G4, 2),                                                   # (la dominante: vuelve a A)
]
NB = 24
# compás de la canción → (compás de la melodía, acorde por medio compás)
CH_A = [(C, MAJ), (G, MAJ), (A, MIN), (G, MAJ), (C, MAJ), (C, MAJ), (G, DOM), (C, MAJ)]
CH_B = [(F_, MAJ), (C, MAJ), (D, MIN), (G, DOM), (F_, MAJ), (G, MAJ), (C, MAJ), (G, DOM)]


def song_bar(b):
    """compás de la canción (1-24) → compás de la melodía (1-16)"""
    return b if b <= 16 else b - 16


def chord(b):
    m = song_bar(b)
    return CH_A[m - 1] if m <= 8 else CH_B[m - 9]


def melody():
    out = []
    for b in range(1, NB + 1):
        m = song_bar(b)
        for (mb, st, n, d) in (MEL_A if m <= 8 else MEL_B):
            if mb == m: out.append((b, st, n, d))
    return out


ANSWER_BARS = (4, 8, 20, 24)          # compases donde la melodía se queda quieta: contesta la isla

# ── Instrumentos ──────────────────────────────────────────────────────────────
I_LEAD = {'vol': [15, 14, 13, 13, 12, 12], 'sus': 12, 'vib': (12, 0.22, 5.6), 'duty': [0.25, 0.5]}
I_PLUCK = {'vol': [12, 9, 6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_TRI = {'vol': [15], 'sus': 15}
I_STEEL = {'vol': [15, 13, 11, 10, 9, 8, 7, 6, 5, 5, 4, 4, 3, 3, 2], 'sus': 2}
I_BELL = GN.I_BELL
I_SAW = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.18, 6)}
I_BRASS = {'vol': [14, 12, 10, 8], 'sus': 6}
I_PAD = {'vol': [1, 2, 3, 4, 5, 6], 'sus': 6, 'vib': (20, 0.12, 4.5)}
I_TRILL = {'vol': [9, 8, 7, 6, 5, 4], 'sus': 3, 'duty': 0.125}
I_DRIP = GN.I_DRIP
WAVES = [wavetable([1.0, 0.0, 0.55, 0.0, 0.0, 0.32, 0.0, 0.18]),            # 0 caja de música / campana
         wavetable([1.0, 0.7, 0.35, 0.45, 0.1, 0.2]),                        # 1 steel drum (metálico, brillante)
         wavetable([1.0, 0.3, 0.1])]                                         # 2 colchón
HAT, SHAKE = [5, 2, 1], [3, 2, 1]
CRASH = GN.CRASH if hasattr(GN, 'CRASH') else [13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
SNARE_N = [13, 9, 5, 2]
ROLL = [8, 5, 2]
SLEIGH = [6, 4, 3, 2, 1]


def tval(b, st):
    return (b - 1) * BAR + st * S16


def build(island):
    if island == 'jungla':
        return build_jungla()[0]
    rng =np.random.default_rng({'pradera': 1, 'costa': 2, 'fortaleza': 3, 'nieve': 4, 'cuevas': 5, 'final': 6}[island])
    NF = F.frames_for(NB * BAR + 3)
    C_ = {k: Chan(NF) for k in ('lead', 'lead2', 'arp', 'bass', 'motif', 'pad1', 'pad2')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash')}
    NS = int(NF * F.FRAME_S) + SR
    kick = np.zeros(NS)
    sn = np.zeros(NS)

    def hitk(t, g=1.0, deep=False):
        smp = TN.KICK_DEEP if deep else TN.KICK
        i = int(t * SR)
        kick[i:i + len(smp)] += smp[:max(0, min(len(smp), NS - i))] * g

    def hits(t, g=1.0):
        i = int(t * SR)
        sn[i:i + len(TN.SNARE_BODY)] += TN.SNARE_BODY[:max(0, min(len(TN.SNARE_BODY), NS - i))] * g

    # ── MELODÍA (la misma en todas; cambia el instrumento) ──
    oct_ = {'nieve': 12, 'cuevas': 0, 'final': 0}.get(island, 0)
    for b, st, n, d in melody():
        t0, t1 = tval(b, st), tval(b, st) + d * S16 * 0.95
        if island in ('pradera',):
            play(C_['lead'], t0, t1, n, I_LEAD, release=3)
        elif island == 'costa':
            play(C_['lead'], t0, t1, n, dict(I_STEEL, duty=1.0), q=q_n163, release=4)
        elif island == 'fortaleza':
            play(C_['lead'], t0, t1, n - 12, I_SAW, q=q_saw, release=3)
            play(C_['lead2'], t0, t0 + min(d, 2) * S16, n, dict(I_BRASS, duty=0.5), release=2)
        elif island in ('nieve', 'cuevas'):
            play(C_['lead'], t0, t0 + S16 * max(d, 6), n + oct_, dict(I_BELL, duty=0.0), q=q_n163, release=6)
        else:   # final
            play(C_['lead'], t0, t1, n - 12, I_SAW, q=q_saw, release=2)
            play(C_['lead2'], t0, t1, n, dict(I_LEAD, duty=0.125), release=2)

    for b in range(1, NB + 1):
        t0 = tval(b, 0)
        r, q = chord(b)
        root = 36 + (r - 36) % 12
        last_a = b in (8, 24)
        # ── BAJO ──
        if island == 'pradera':
            for st, iv in ((0, 0), (4, 7), (8, 12), (12, 7)):
                play(C_['bass'], tval(b, st), tval(b, st) + 3 * S16, root + iv, I_TRI, q=q_tri, release=0)
        elif island == 'costa':
            for st, iv, ln in ((0, 0, 3), (3, 7, 1), (4, 12, 3), (8, 0, 3), (11, 7, 1), (12, 12, 3)):
                play(C_['bass'], tval(b, st), tval(b, st) + ln * S16, root + iv, I_TRI, q=q_tri, release=0)
        elif island == 'fortaleza':
            for st in range(0, 16, 2):
                play(C_['bass'], tval(b, st), tval(b, st) + S16, root + (12 if st % 4 else 0), I_TRI, q=q_tri, release=0)
        elif island == 'nieve':
            for st in (0, 8):
                play(C_['bass'], tval(b, st), tval(b, st) + 7 * S16, root + (0 if st == 0 else 7), I_TRI, q=q_tri, release=0)
        elif island == 'cuevas':
            play(C_['bass'], t0, t0 + BAR * 0.98, root, I_TRI, q=q_tri, release=0)
        else:
            for st in range(0, 16, 2):
                play(C_['bass'], tval(b, st), tval(b, st) + 1.6 * S16, root + (12 if st in (6, 14) else 0), I_TRI, q=q_tri, release=0)
        # ── ACOMPAÑAMIENTO ──
        notes = [60 + (r - 60) % 12 + iv for iv in q]
        if island == 'pradera':
            for st in (2, 6, 10, 14):                               # acordes a contratiempo
                for k, nn in enumerate(notes[:2]):
                    play(C_['arp' if k == 0 else 'motif'], tval(b, st), tval(b, st) + S16, nn, I_PLUCK, release=1)
        elif island == 'costa':
            for st in range(0, 16, 2):                              # marimba: arpegio en corcheas
                nn = notes[(st // 2) % 3] + (12 if (st // 2) % 4 == 3 else 0)
                play(C_['arp'], tval(b, st), tval(b, st) + S16 * 1.5, nn, dict(I_STEEL, duty=0.0), q=q_n163, vs=0.6, release=2)
        elif island == 'fortaleza':
            for st in (0, 6, 12):                                   # golpes de metal
                play(C_['arp'], tval(b, st), tval(b, st) + S16 * 1.5, notes[0], dict(I_BRASS, duty=0.25), release=1)
        elif island in ('nieve', 'cuevas'):
            k_ = 0.0075
            play(C_['pad1'], t0, t0 + BAR * 0.97, notes[1], dict(I_PAD, duty=2.0), q=q_n163, release=8)
            play(C_['pad2'], t0, t0 + BAR * 0.97, notes[2], dict(I_PAD, duty=2.0), q=q_n163, release=8)
        else:
            for st in (0, 3, 6, 10):                                # acordes de potencia a síncopa
                play(C_['arp'], tval(b, st), tval(b, st) + S16 * 1.2, notes[0] - 12, dict(I_SAW), q=q_vrc6, vs=0.6, release=1)
        # ── LEITMOTIV de la isla (donde la melodía se queda quieta) ──
        if b in ANSWER_BARS or (b == 12 and island != 'cuevas'):
            t = lambda st: tval(b, st)
            if island == 'pradera':                                 # trino de pájaro
                for i, st in enumerate(range(6, 14)):
                    nn = notes[2] + 24 + (2 if i % 2 else 0)
                    play(C_['motif'], t(st), t(st) + S16 * 0.9, nn, I_TRILL, release=0)
            elif island == 'costa':                                 # marimba que sube
                for i, st in enumerate((10, 11, 12, 13, 14)):
                    play(C_['motif'], t(st), t(st) + S16, notes[i % 3] + 12 * (1 + i // 3), dict(I_STEEL, duty=1.0), q=q_n163, release=2)
            elif island == 'fortaleza':                             # fanfarria de tresillos
                for i in range(6):
                    tt = t(10) + i * (S16 * 4 / 6)
                    play(C_['motif'], tt, tt + S16 * 0.55, notes[[0, 0, 1, 0, 1, 2][i]] + 12, dict(I_BRASS, duty=0.5), release=1)
            elif island == 'nieve':                                 # campanitas que caen
                for i, st in enumerate((9, 10, 11, 12, 13, 14)):
                    play(C_['motif'], t(st), t(st) + S16 * 4, notes[2 - i % 3] + 24 - 12 * (i // 3), dict(I_BELL, duty=0.0), q=q_n163, release=4)
            elif island == 'cuevas':                                # gotas
                for st in (9, 12, 14):
                    play(C_['motif'], t(st), t(st) + 0.07, notes[int(rng.integers(0, 3))] + 24, I_DRIP, release=0)
            else:                                                   # erupción
                for st in (10, 12, 14):
                    play(C_['motif'], t(st), t(st) + S16 * 1.5, notes[0] - 12, dict(I_SAW), q=q_vrc6, release=1)
                    NZ['crash'].hit(t(st), 6, [12, 8, 5, 3, 1])
        # ── BATERÍA ──
        for st in range(16):
            tt = tval(b, st)
            if island == 'pradera':
                if st in (0, 8): hitk(tt, 0.8)
                if st in (4, 12): NZ['snare'].hit(tt, 4, SNARE_N); hits(tt, 0.5)
                if st % 2 == 0: NZ['hat'].hit(tt, 0, HAT, short=0)
            elif island == 'costa':
                if st in (0, 6, 8, 14): hitk(tt, 0.7)
                if st in (4, 12): NZ['snare'].hit(tt, 5, SNARE_N[:3])
                NZ['hat'].hit(tt, 1, SHAKE if st % 2 else [4, 2, 1])
            elif island == 'fortaleza':
                if st in (0, 8): hitk(tt, 1.0)
                if st in (4, 12): NZ['snare'].hit(tt, 4, SNARE_N); hits(tt, 0.7)
                if st in (13, 14, 15) and b % 2 == 0: NZ['snare'].hit(tt, 4, ROLL)
                if st % 4 == 2: NZ['hat'].hit(tt, 0, HAT)
            elif island == 'nieve':
                if st == 0: hitk(tt, 0.5)
                if st in (4, 12): NZ['snare'].hit(tt, 6, [6, 3, 1])
                if st % 2 == 1: NZ['hat'].hit(tt, 0, SLEIGH, short=1)        # cascabeles (ruido corto, metálico)
            elif island == 'cuevas':
                if st == 0 and b % 2 == 1: hitk(tt, 0.9, deep=True)
                if st == 8: NZ['snare'].hit(tt, 8, [5, 3, 1])
            else:
                if st in (0, 2, 8, 10, 11): hitk(tt, 1.0)
                if st in (4, 12): NZ['snare'].hit(tt, 3, SNARE_N); hits(tt, 0.9)
                if st % 2 == 0: NZ['hat'].hit(tt, 0, HAT, short=1)
                if st == 0 and b % 2 == 1: NZ['crash'].hit(tt, 3, CRASH)

    n = int(NB * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    wave = lambda ch: cut(F.render_wave(C_[ch], WAVES) * 0.0075)
    pulse = lambda ch: cut(F.pulse_dac(F.render_pulse(C_[ch])))
    saw = lambda ch: cut(F.pulse_dac(F.render_saw(C_[ch])))
    lead_kind = {'pradera': pulse, 'costa': wave, 'fortaleza': saw, 'nieve': wave, 'cuevas': wave, 'final': saw}[island]
    S = {'lead': lead_kind('lead'), 'bass': cut(F.tnd_dac(F.render_tri(C_['bass']) / 8227.0)),
         'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - F.tnd_dac(np.full(NS, 64 / 22638.0))),
         'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - F.tnd_dac(np.full(NS, 64 / 22638.0))) + cut(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
         'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12)), 'crash': cut(F.tnd_dac(NZ['crash'].render() / 22638.0 * 12))}
    if island in ('fortaleza', 'final'): S['lead2'] = pulse('lead2')
    if island in ('pradera',): S['arp'] = pulse('arp') + pulse('motif') * 0.0
    if island in ('costa',): S['arp'] = wave('arp')
    if island in ('fortaleza', 'final'): S['arp'] = pulse('arp') if island == 'fortaleza' else saw('arp')
    if island in ('nieve', 'cuevas'): S['pad'] = wave('pad1') + wave('pad2')
    S['motif'] = {'pradera': pulse, 'costa': wave, 'fortaleza': pulse, 'nieve': wave, 'cuevas': pulse, 'final': saw}[island]('motif')
    if island == 'cuevas':
        S['lead'] = GN.delay(S['lead'], 3 * S16, 0.5, 4, 2600)
        S['motif'] = GN.delay(S['motif'], 0.31, 0.4, 3, 3000)
    if island == 'nieve':
        S['lead'] = GN.delay(S['lead'], 2 * S16, 0.3, 2, 4000)
    S = {k: GN.fold(v, n) for k, v in S.items() if np.abs(v).max() > 0}
    # (niveles respecto a la melodía; la melodía no debe pasar de ~1/3 de la energía: es el mapa, no un solo)
    LV = {
        'pradera':   {'lead': 0, 'bass': -2, 'kick': -2, 'snare': -4, 'hat': -12, 'crash': -12, 'arp': -5, 'motif': -4},
        'costa':     {'lead': 0, 'bass': -2, 'kick': -3, 'snare': -6, 'hat': -11, 'crash': -12, 'arp': -4, 'motif': -4},
        'fortaleza': {'lead': 0, 'lead2': -5, 'bass': -2, 'kick': -2, 'snare': -2, 'hat': -12, 'crash': -12, 'arp': -5, 'motif': -3},
        'nieve':     {'lead': 0, 'bass': -3, 'kick': -5, 'snare': -8, 'hat': -9, 'crash': -12, 'pad': -5, 'motif': -3},
        'cuevas':    {'lead': 0, 'bass': -2, 'kick': -2, 'snare': -8, 'crash': -12, 'pad': -4, 'motif': -5},
        'final':     {'lead': 0, 'lead2': -6, 'bass': -1, 'kick': -1, 'snare': -3, 'hat': -10, 'crash': -8, 'arp': -4, 'motif': -3},
    }[island]
    g = GN.level(S, {k: LV.get(k, -12) for k in S}, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    side = (S.get('arp', 0) * g.get('arp', 0) * 0.35 - S['motif'] * g['motif'] * 0.35
            + (S['hat'] * g['hat'] * 0.3 if 'hat' in S else 0))
    y = F.master(np.stack([x + side, x - side], 1), lufs={'cuevas': -13.0, 'nieve': -12.0}.get(island, -11.5))
    GN.report('map_' + island, y, S, g, n)
    return y


# ══ map_jungla: el arreglo de la JUNGLA, con los instrumentos y las herramientas de jungla_nes.py ═══════════════
# (J.Rig toca los canales de Famicom y las grabaciones GM y apunta las notas de cada voz; MapSong le da la rejilla
# de esta canción con la forma que espera: compases de 16 semicorcheas, un acorde por compás)
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/mapa'
GM_LAT = 64                                                          # (muestras: el retraso MÍNIMO de fluidsynth, medido: 71)
SCALE_C = {0, 2, 4, 5, 7, 9, 11}


class MapSong:
    bpm, BAR, NB, INTRO, scale, tonic = BPM, BAR, NB, 0, SCALE_C, (C, MAJ)

    def __init__(self):
        self.steps = [16] * NB
        self.chords = [(chord(b), chord(b)) for b in range(1, NB + 1)]
        self.mel = sorted(melody())

    def t(self, b, st): return tval(b, st)
    def q(self, b, st): return (b - 1) * 16 + st
    def dur(self, b, d): return d * S16
    def chord(self, b, st): return chord(b)
    def tones(self, b, st):
        r, q = chord(b)
        return {(r + i) % 12 for i in q}


def toucan_map(sg, R, b, vel=72):
    """el LEITMOTIV de la jungla en el mapa: el tucán de jungla_nes.py (ocarina, la 5ª dos veces y la raíz una 4ª
    arriba) donde la melodía se queda quieta; sobre el Sol7 (sin 5ª en CH_B) la 3ª dos veces y la raíz arriba"""
    r, q = sg.chord(b, 12)
    if q != DOM:
        return J.toucan(sg, R, b, vel)
    t3 = 79 + (r + q[1] - 79) % 12
    top = t3 + (r - t3) % 12
    for st, n, d, v in ((10, t3, 1, vel - 10), (11, t3, 1, vel - 14), (12, top, 3, vel)):
        if not R.rub(b, st, n, d): R.gm('accent', J.P_OCARINA, b, st, n, d, v, gate=0.85)


def arrange_jungla(sg, R):
    for b, st, n, d in sg.mel:                                       # ── LA MELODÍA: flauta de pan + flauta de N163 ──
        R.gm('lead', J.P_PAN, b, st, n, d, 100 if 9 <= b <= 16 else 94, gate=0.97)
        R.chip('lead', b, st, n - 12, d, J.I_WOOD, q=q_n163, release=4)
    for b in range(1, NB + 1):
        r, q = sg.chord(b, 0)
        B = 9 <= b <= 16                                             # (B: más capas — kalimba, colchón, caja)
        nxt = sg.chord(b % NB + 1, 0)
        # ── EL BAJO (triángulo): rebota (1, 8ª, 5ª, 1, 8ª) y se acerca por grado a la raíz siguiente ──
        root = 36 + (r - 36) % 12
        for st, iv, d in ((0, 0, 3), (3, 12, 2), (6, 7, 2), (10, 0, 2), (12, 12, 1)):
            nn = next((p for p in (root + iv, root + 7, root + 19) if not R.rub(b, st, p, d)), root + iv)   # (sin choques)
            R.chip('bass', b, st, nn, d, J.I_TRI, q=q_tri, gate=0.9, release=1)
        n2 = 36 + (nxt[0] - 36) % 12
        if nxt[0] != r:
            ap = [p for p in (n2 - 2, n2 - 1, n2 + 2, n2 + 1) if p % 12 in SCALE_C and not R.rub(b, 14, p, 2)]
            R.chip('bass', b, 14, ap[0] if ap else n2, 2, J.I_TRI, q=q_tri, gate=0.9, release=1)
        else:
            R.chip('bass', b, 14, root + 7, 2, J.I_TRI, q=q_tri, gate=0.9, release=1)
        # ── LA MARIMBA (balafón): la nota repetida que rebota por el acorde (1 · 5-5 · 10ª · 8ª · 12ª-12ª · 10ª) ──
        pl = J.place(None, (r, q), 47)
        for st, deg in ((0, 0), (2, 2), (3, 2), (6, 4), (8, 3), (10, 5), (11, 5), (14, 4)):
            nn = pl[deg]
            vel = 84 if st == 0 else (72 if st in (2, 8, 10) else 60)
            if not R.rub(b, st, nn, 2): R.gm('marimba', J.P_MARIMBA, b, st, nn, 2, vel)
        # ── LA KALIMBA: dos notas del acorde a contratiempo, arriba (en B y la vuelta de A) ──
        if b >= 9:
            for st in (2, 10):
                for nn in J.place(None, (r, q), 79)[1:3]:
                    if not R.rub(b, st, nn, 2): R.gm('kal', J.P_KALIMBA, b, st, nn, 2, 62 if B else 54)
        # ── EL COLCHÓN (N163) en B ──
        if B:
            base = 53 + (r - 53) % 12
            pn = [base + iv for iv in q[1:] + q[:1] if not R.rub(b, 0, base + iv, 16)][:2]           # (sin choques)
            for j, nn in enumerate(pn):
                R.chip(('pad1', 'pad2')[j], b, 0, nn, 16, J.I_PAD, q=q_n163, gate=0.97, release=6)
        # ── EL LEITMOTIV ──
        if b in ANSWER_BARS or b == 12:
            toucan_map(sg, R, b)
        # ── BATERÍA: bombo 1 · 3y, aro (A) / caja (B) en 2 y 4, congas en tumbao, cabasa / maracas en semicorcheas ──
        for st in range(16):
            if st in (0, 10): R.kick(b, st, 1.0 if st == 0 else 0.85)
            if st in (4, 12):
                if B: R.snare(b, st, 0.75)
                else: R.dr('rim', b, st, J.RIM, 86)
            if st in (4, 6, 12, 14, 15):
                R.dr('congas', b, st, (J.CONGA_M, J.CONGA_O, J.CONGA_O, J.CONGA_L, J.CONGA_L)[(4, 6, 12, 14, 15).index(st)], 90 if st in (6, 14) else 76)
            if B and st in (3, 11): R.dr('congas', b, st, J.BONGO_H, 56)
            R.dr('shaker', b, st, J.MARACAS if B else J.CABASA, 64 if st % 4 == 2 else 44)
            if st % 4 == 2: R.NZ['hat'].hit(tval(b, st), 1, HAT if B else [4, 1])
            if st == 0 and b in (1, 9, 17):
                R.NZ['crash'].hit(tval(b, st), 3, J.CRASH_N); R.gm('taiko', J.P_TAIKO, b, st, 41, 4, 100)
            if (b in (8, 16) and st >= 12) or (b == 24 and st >= 14):      # (redobles hacia B, la vuelta y el bucle)
                R.dr('timb', b, st, J.TIMB_H if st < 14 else J.TIMB_L, 84 + 3 * (st - 12))


def build_jungla():
    sg = MapSong()
    R = J.Rig(sg)
    arrange_jungla(sg, R)
    n = int(NB * BAR * SR)
    L = n + 3 * SR
    cut = lambda x: x[:L] - np.mean(x[:n])
    base = F.tnd_dac(np.full(R.NS, 64 / 22638.0))
    wave = lambda k: cut(F.render_wave(R.Cn[k], J.WAVES) * 0.0075)
    S = {k: GM.cached(R.G[k], L) for k in R.G}
    S.update({k: GM.cached(R.D[k], L) for k in R.D})
    # (fluidsynth hace sonar cada nota 70-130 muestras tarde (procesa los eventos en bloques de 64): se adelantan las
    #  capas GM lo mínimo — sin comerse ningún ataque — para que caigan con los golpes de Famicom de los otros seis
    #  arreglos: el mapa salta de uno a otro sin perder el pulso)
    S = {k: np.concatenate([x[GM_LAT:], np.zeros(GM_LAT)]) for k, x in S.items()}
    S['lead'] = S['lead'] + 0.35 * wave('lead')                         # (la flauta de N163 debajo: el color de la casa)
    S['lead'] = GN.delay(S['lead'], 3 * S16, 0.22, 2, 3200)             # (eco corto: el aire de la selva, como jungla_1)
    S.update({'pad': wave('pad1') + wave('pad2'),
              'bass': cut(F.tnd_dac(F.render_tri(R.Cn['bass']) / 8227.0)),
              'kick': cut(F.tnd_dac((R.dk + 64) / 22638.0) - base),
              'snare': cut(F.tnd_dac((R.sn + 64) / 22638.0) - base) + cut(F.tnd_dac(R.NZ['snare'].render() / 22638.0 * 12)),
              'hat': cut(F.tnd_dac(R.NZ['hat'].render() / 22638.0 * 12)),
              'crash': cut(F.tnd_dac(R.NZ['crash'].render() / 22638.0 * 12))})
    from scipy.signal import butter, sosfilt
    hp = butter(1, 30, btype='high', fs=SR, output='sos')
    S = {k: GN.fold(sosfilt(hp, x), n) for k, x in S.items() if np.abs(x).max() > 0}   # (filtro antes del pliegue: costura limpia)
    # (niveles respecto a la melodía, como los otros arreglos del mapa: la melodía, ~1/3 de la energía)
    LV = {'lead': 0, 'bass': -2, 'kick': -1, 'snare': -5, 'rim': -6, 'congas': -3, 'shaker': -11, 'hat': -13,
          'crash': -12, 'taiko': -4, 'timb': -7, 'marimba': -3, 'kal': -7, 'pad': -8, 'accent': -3}
    g = GN.level(S, {k: LV.get(k, -12) for k in S}, 'lead')
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('marimba', 0.3) - sd('kal', 0.4) + sd('shaker', 0.4) - sd('congas', 0.2) + sd('hat', 0.3) \
        - sd('pad', 0.2) + sd('accent', 0.35)
    y = F.master(np.stack([x + side, x - side], 1), lufs=-11.5)
    GN.report('map_jungla', y, S, g, n)
    return y, sg, R


def check_jungla(sg, R):
    """melodía (la misma de siempre), leitmotiv (solo notas del acorde) y choques con la melodía"""
    nm = J.nm
    lb, lo, out, off = J.check(sg)
    print(f'  melodía: {len(sg.mel)} notas, a contratiempo {100 * off:.0f} %; largas fuera del acorde (las de la '
          f'canción): {len(lb)}; fuera de la escala: {out or "ninguna"}')
    acc = R.notes.get('accent', [])
    bad = [(int(q0 // 16) + 1, q0 % 16, nm(nn)) for q0, q1, nn in acc if nn % 12 not in sg.tones(int(q0 // 16) + 1, 0)]
    bars = sorted({int(q0 // 16) + 1 for q0, q1, nn in acc})
    print(f'  leitmotiv (tucán): {len(acc)} notas en los compases {bars}; fuera del acorde: {bad or "ninguna"}; '
          + ' | '.join(f'{b}: ' + ' '.join(nm(nn) for q0, q1, nn in acc if int(q0 // 16) + 1 == b) for b in bars))
    for k in ('bass', 'marimba', 'kal', 'accent', 'pad1', 'pad2'):
        if k in R.notes:
            cl = J.clashes(sg, sg.mel, R.notes[k])
            print(f'  choques melodía / {k} (≥ corchea): {len(cl)} {cl[:6] if cl else ""}')


ISLANDS = ['pradera', 'costa', 'fortaleza', 'nieve', 'cuevas', 'final', 'jungla']

if __name__ == '__main__':
    which = [a for a in sys.argv[1:]] or ISLANDS
    print(f'Rumbo a las islas: {BPM} BPM, {NB} compases ({NB * BAR:.1f} s), melodía {len(melody())} notas')
    for w in which:
        if w == 'jungla':
            y, sg, R = build_jungla()
            check_jungla(sg, R)
        else:
            y = build(w)
        if not os.environ.get('REPORT'):
            GN.export('map_' + w, y)
            if w == 'jungla':
                J.write_mid(F.out('map_jungla', 'mid'), sg, R)
                os.makedirs(PRUEBAS, exist_ok=True)
                J.enc(np.concatenate([y, y]), os.path.join(PRUEBAS, 'map_jungla_preview.ogg'))
                print(f'  {PRUEBAS}/map_jungla_preview.ogg (el bucle dos veces)')
