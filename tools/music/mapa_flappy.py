#!/usr/bin/env python3
# tools/music/mapa_flappy.py
# La música del MAPA DE LA CAMPAÑA FLAPPY (id `map_flappy`, "Cielo abierto"): calma y aventura, en Re mayor como
# "Aleteo" (`flappy`, la música de los niveles del Valle) pero pieza propia; abre con LA LLAMADA en Re (La-Re-Fa#-La).
# Forma: A (8) · B (8) · A (8) = 24 compases a 108 BPM = 53,3 s, bucle sin costura, como el mapa del mundo.
# Acordes: A  D · Si m · Sol · La7 · D · Fa# m · Sol · La   B  Sol · La · Si m · Fa# m · Sol · SOL MENOR (el giro oscuro,
# como en Aleteo) · La · La.
# Dos variantes (NO se han escuchado: solo números; el usuario elige):
#   A  estilo de la casa: pulso cantarín 25 % (y 12,5 % una octava arriba en B), bajo de triángulo saltarín
#      (1-5-8-5), acordes a contratiempo, batería ligera; leitmotiv: el ALETEO (ta-ta-TA: notas del acorde)
#   B  más propia: lead de onda del N163 (flauta-campana) con eco de cielo, bajo de triángulo en blancas con la
#      5ª al medio, la "corriente de aire" (arpegio ascendente de campana en corcheas), sin caja, solo bombo
#      suave y "viento" (ruido largo y flojo); el mismo leitmotiv, en campana
#   python3 tools/music/mapa_flappy.py            previas A y B en FlappyMonster_pruebas/musica/mapa_flappy/
#   REPORT=1 …                                    solo números
#   INSTALL=1 [MAPA_FLAPPY=A|B] …                 escribe assets/music/map/map_flappy.ogg (A por defecto)
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, q_n163, q_tri
import tentacle_nes as TN
import gloomy_nes as GN
import worldmap_nes as W

BPM = 108
S16 = 60.0 / BPM / 4
BAR = 16 * S16
NB = 24
MAJ, MIN, DOM = W.MAJ, W.MIN, W.DOM
C, D, E, F_, G, A, B_ = 0, 2, 4, 5, 7, 9, 11
FS = 6                                    # Fa# (clase de nota)
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'musica', 'mapa_flappy')

# ── La melodía (compás, semicorchea, nota MIDI, duración en semicorcheas) ────────────────────────────────────
# A: la llamada en Re (La-Re-Fa#-La) abre; el compás 5 la repite más alto; 4 y 8 se quedan quietos (contesta el aleteo)
MEL_A = [
    (1, 0, 69, 4), (1, 4, 74, 2), (1, 6, 78, 2), (1, 8, 81, 4), (1, 12, 78, 4),
    (2, 0, 78, 2), (2, 2, 76, 2), (2, 4, 74, 2), (2, 6, 71, 2), (2, 8, 74, 8),
    (3, 0, 74, 4), (3, 4, 71, 2), (3, 6, 67, 2), (3, 8, 71, 4), (3, 12, 74, 4),
    (4, 0, 76, 10),
    (5, 0, 69, 4), (5, 4, 74, 2), (5, 6, 78, 2), (5, 8, 81, 4), (5, 12, 86, 4),
    (6, 0, 85, 2), (6, 2, 83, 2), (6, 4, 81, 2), (6, 6, 78, 2), (6, 8, 81, 8),
    (7, 0, 83, 4), (7, 4, 79, 2), (7, 6, 76, 2), (7, 8, 74, 4), (7, 12, 71, 4),
    (8, 0, 73, 10),
]
# B (escrita una octava arriba: el lead la toca 12 abajo y el pulso al 12,5 % dobla a la octava escrita)
MEL_B = [
    (9, 0, 86, 4), (9, 4, 83, 2), (9, 6, 79, 2), (9, 8, 83, 4), (9, 12, 86, 4),
    (10, 0, 85, 6), (10, 6, 81, 2), (10, 8, 76, 4), (10, 12, 81, 4),
    (11, 0, 86, 4), (11, 4, 83, 2), (11, 6, 78, 2), (11, 8, 83, 4), (11, 12, 86, 4),
    (12, 0, 85, 6), (12, 6, 81, 2), (12, 8, 78, 8),
    (13, 0, 83, 2), (13, 2, 86, 2), (13, 4, 91, 4), (13, 8, 90, 2), (13, 10, 88, 2), (13, 12, 86, 4),
    (14, 0, 82, 2), (14, 2, 86, 2), (14, 4, 91, 4), (14, 8, 89, 2), (14, 10, 87, 2), (14, 12, 86, 4),
    (15, 0, 85, 4), (15, 4, 88, 4), (15, 8, 93, 4), (15, 12, 91, 2), (15, 14, 90, 2),
    (16, 0, 88, 6), (16, 6, 85, 2), (16, 8, 81, 8),
]
CH_A = [(D, MAJ), (B_, MIN), (G, MAJ), (A, DOM), (D, MAJ), (FS, MIN), (G, MAJ), (A, MAJ)]
CH_B = [(G, MAJ), (A, MAJ), (B_, MIN), (FS, MIN), (G, MAJ), (G, MIN), (A, MAJ), (A, MAJ)]
ANSWER = (4, 8, 12, 20, 24)


def sb(b): return b if b <= 16 else b - 16


def chord(b):
    m = sb(b)
    return CH_A[m - 1] if m <= 8 else CH_B[m - 9]


def tval(b, st): return (b - 1) * BAR + st * S16


def melody():
    return [(b, st, n, d) for b in range(1, NB + 1) for (mb, st, n, d) in (MEL_A if sb(b) <= 8 else MEL_B) if mb == sb(b)]


# ── Instrumentos ───────────────────────────────────────────────────────────────────────────────────────────────
I_LEAD = W.I_LEAD
I_HI = {'vol': [8, 8, 7, 7, 6], 'sus': 6, 'duty': 0.125, 'vib': (12, 0.18, 5.6)}
I_FLAP = {'vol': [12, 8, 4, 2, 1], 'sus': 0, 'duty': 0.125}              # el aleteo: respingo corto
I_WIND = [4, 3, 3, 2, 2, 1]
I_AIR = {'vol': [10, 9, 8, 7, 6, 5, 4, 3, 3, 2], 'sus': 2}                # corriente de aire (campana)
I_FLUTE = {'vol': [13, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (12, 0.2, 5.4), 'duty': 3.0}
WAVES = W.WAVES + [F.wavetable([1.0, 0.45, 0.2, 0.08])]                    # 3 flauta suave


def build(var):
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'lead2', 'arp', 'bass', 'motif')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare')}
    NS = int(NF * F.FRAME_S) + SR
    kick = np.zeros(NS)
    sn = np.zeros(NS)

    def hitk(t, g):
        i = int(t * SR)
        s = TN.KICK
        kick[i:i + len(s)] += s[:max(0, min(len(s), NS - i))] * g

    def hits(t, g):
        i = int(t * SR)
        s = TN.SNARE_BODY
        sn[i:i + len(s)] += s[:max(0, min(len(s), NS - i))] * g

    for b, st, n, d in melody():
        t0, t1 = tval(b, st), tval(b, st) + d * S16 * 0.95
        hi = sb(b) >= 9
        if var == 'A':
            play(Cn['lead'], t0, t1, n - (12 if hi else 0), I_LEAD, release=3)
            if hi:
                play(Cn['lead2'], t0, t1, n, I_HI, release=2)
        else:
            play(Cn['lead'], t0, t0 + S16 * max(d, 3) * 0.97, n - (12 if hi else 0), I_FLUTE, q=q_n163, release=4)
    for b in range(1, NB + 1):
        r, q = chord(b)
        root = 36 + (r - 36) % 12
        notes = [60 + (r - 60) % 12 + iv for iv in q]
        if var == 'A':
            for st, iv in ((0, 0), (4, 7), (8, 12), (12, 7)):         # bajo saltarín 1-5-8-5
                play(Cn['bass'], tval(b, st), tval(b, st) + 3 * S16, root + iv, W.I_TRI, q=q_tri, release=0)
            for st in (2, 6, 10, 14):                                  # acordes a contratiempo
                for k, nn in enumerate(notes[:2]):
                    play(Cn['arp' if k == 0 else 'motif'], tval(b, st), tval(b, st) + S16, nn, W.I_PLUCK, release=1)
        else:
            for st, iv in ((0, 0), (8, 7)):                            # blancas: raíz y quinta
                play(Cn['bass'], tval(b, st), tval(b, st) + 8 * S16 * 0.97, root + iv, W.I_TRI, q=q_tri, release=0)
            seq = [notes[0], notes[1], notes[2], notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[1] + 12, notes[0] + 12]
            for j, st in enumerate(range(0, 16, 2)):                   # la corriente de aire: sube en corcheas
                play(Cn['arp'], tval(b, st), tval(b, st) + S16 * 2.5, seq[j], dict(I_AIR, duty=0.0), q=q_n163, vs=0.6, release=3)
        if b in ANSWER:                                                # LEITMOTIV: el aleteo ta-ta-TA (notas del acorde) al final de los compases 4, 8, 12, 20 y 24 (en el 12 se solapa con la melodía)
            fl = [notes[2], notes[2], notes[0] + 12]
            for st, nn, ln in zip((10, 11, 12), fl, (1, 1, 3)):
                if var == 'A':
                    play(Cn['motif'], tval(b, st), tval(b, st) + S16 * ln, nn + 12, I_FLAP, release=0)
                else:
                    play(Cn['motif'], tval(b, st), tval(b, st) + S16 * ln, nn + 12, dict(I_AIR, duty=1.0), q=q_n163, release=2)
        for st in range(16):
            tt = tval(b, st)
            if var == 'A':
                if st in (0, 8): hitk(tt, 0.6)
                if st == 12: NZ['snare'].hit(tt, 4, W.SNARE_N); hits(tt, 0.35)
                if st % 4 == 2: NZ['hat'].hit(tt, 0, W.HAT, short=0)
            else:
                if st == 0 and b % 2 == 1: hitk(tt, 0.5)
                if st % 8 == 4: NZ['hat'].hit(tt, 1, I_WIND)            # viento: ruido largo y flojo

    n = int(NB * BAR * SR)
    cut = lambda x: x[:n + 3 * SR] - np.mean(x[:n])
    wave = lambda ch: cut(F.render_wave(Cn[ch], WAVES) * 0.0075)
    pulse = lambda ch: cut(F.pulse_dac(F.render_pulse(Cn[ch])))
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    S = {'bass': cut(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)),
         'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base),
         'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + cut(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
         'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12))}
    if var == 'A':
        S.update(lead=pulse('lead'), lead2=pulse('lead2'), arp=pulse('arp'), motif=pulse('motif'))
        LV = {'lead': 0, 'lead2': -9, 'bass': -2, 'kick': -3, 'snare': -7, 'hat': -13, 'arp': -6, 'motif': -4}
    else:
        S.update(lead=GN.delay(wave('lead'), 3 * S16, 0.32, 3, 3600), arp=wave('arp'), motif=wave('motif'))
        LV = {'lead': 0, 'bass': -2, 'kick': -4, 'snare': -20, 'hat': -9, 'arp': -2, 'motif': -2}
    S = {k: GN.fold(v, n) for k, v in S.items() if np.abs(v).max() > 0}
    g = GN.level(S, {k: LV.get(k, -12) for k in S}, 'lead')
    from scipy.signal import butter, sosfilt
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), sum(S[k] * g[k] for k in S))
    side = 0.35 * (S.get('arp', 0) * g.get('arp', 0) - S.get('motif', 0) * g.get('motif', 0)) \
        + (0.3 * S['hat'] * g['hat'] if 'hat' in S else 0)
    y = F.master(np.stack([x + side, x - side], 1), lufs=-11.5)
    GN.report('map_flappy ' + var, y, S, g, n)
    return y


if __name__ == '__main__':
    print(f'Cielo abierto: {BPM} BPM, {NB} compases ({NB * BAR:.1f} s), melodía {len(melody())} notas')
    ys = {v: build(v) for v in 'AB'}
    if os.environ.get('REPORT'):
        sys.exit()
    os.makedirs(PRUEBAS, exist_ok=True)
    import jungla_nes as J
    for v, y in ys.items():
        J.enc(np.concatenate([y, y]), os.path.join(PRUEBAS, f'mapa_flappy_{v}.ogg'))
        print(f'  {PRUEBAS}/mapa_flappy_{v}.ogg (el bucle dos veces)')
    open(os.path.join(PRUEBAS, 'LEEME.txt'), 'w').write(
        'map_flappy "Cielo abierto" (mapa de la campana Flappy). NO se ha escuchado: solo numeros.\n'
        'A = estilo de la casa (pulso cantarin, bajo saltarin, acordes a contratiempo; instalada de momento).\n'
        'B = mas propia (flauta-campana con eco, bajo en blancas, corriente de aire en arpegio, sin caja).\n'
        'Elige A o B: INSTALL=1 MAPA_FLAPPY=B python3 tools/music/mapa_flappy.py\n')
    if os.environ.get('INSTALL'):
        v = os.environ.get('MAPA_FLAPPY', 'A')
        GN.export('map_flappy', ys[v])
        print('  instalada la variante', v)
