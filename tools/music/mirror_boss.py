#!/usr/bin/env python3
# EL ESPEJO — el tema del jefe final de la historia (composición propia; sustituye a las dos pistas "chip").
#
# El encargo: el enfrentamiento definitivo. Distinto de TODO lo anterior, épico, enérgico, muy cargado de capas y con
# sentido de escala; pero no intensidad sin parar: puentes y partes tranquilas que dejen respirar (como el 1:48 de
# winter.ogg) para que lo siguiente pegue más; progresión y escalada; un clímax que sea la culminación de la banda
# sonora. Identidad propia: instrumentos, motivos, lenguaje armónico y estructura.
#
# Qué lo hace distinto:
#   · COMPÁS de 12/8 (cuatro tiempos de tres corcheas): todo lo demás del juego va en 4/4 de semicorcheas.
#   · Fa# menor ARMÓNICO (dominante mayor Do# con su sensible Mi#, napolitana Sol); el clímax, en menor y con
#     quintas (la 1ª versión lo llevaba a Fa# MAYOR: triunfal pero melancólico; ver T_G / T_E).
#   · El MOTIVO DEL ESPEJO: "la llamada" del juego (5-1-3-5 subiendo: Do#-Fa#-La-Do#) REFLEJADA — invertidos sus
#     intervalos baja Do#-Sol#-Mi#-Do#, que es justo el acorde de dominante. El jefe es tu reflejo, y su motivo es el
#     del héroe del revés. Cierra la frase del tema, suena solo en la intro y sube en secuencia en la subida.
#   · CONTRAPUNTO EN ESPEJO: en la última vuelta del tema suena a la vez su inversión diatónica (otra voz, abajo).
#   · En el clímax contesta por fin LA LLAMADA de verdad, subiendo y martilleada, con todo: coro, campanas, octavas.
#
# Forma (compás de 1,52 s a ♩. = 158): INTRO 4 (suena una vez: pedal de dominante, timbales, el motivo del espejo
# despacio) · A 8 (tema) · A' 8 (más capas) · B 8 (desarrollo: secuencia con hemiolia que sube, napolitana, el motivo)
# · C 8 (PUENTE tranquilo: caja de música y voz suave en el relativo mayor, arpegios, sin caja) · D 4 (SUBIDA sobre
# la dominante: redoble que crece, el motivo trepando) · A'' 8 (tema + su espejo + doble bombo) · F 8 ("el tema del
# héroe": la muestra de la antigua música de nivel, ver T_F) · G 16 (FURIA: riff en picado, y otra vez una cuarta arriba) · E 8
# (CLÍMAX: la llamada martilleada) · H 4 (CAÍDA: la intro otra vez, para que el bucle vuelva al tema como la primera
# vez) = bucle de 80 compases.
#
#   python tools/music/mirror_boss.py   → assets/music/bosses/mirror_boss_{intro,loop}.ogg + .mid
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_tri, q_saw, q_n163
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W

BPM = 158                               # (negras con puntillo por minuto; 150 en la primera versión)
S8 = 60.0 / BPM / 3                     # una corchea
BAR = 12 * S8
INTRO = 4

N = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
MAJ, MIN = (0, 4, 7), (0, 3, 7)
SCALE = [6, 8, 9, 11, 1, 2, 4]          # Fa# menor natural (para la inversión diatónica)


def ch(s):
    return (N[s[:-1]], MIN) if s.endswith('m') else (N[s], MAJ)


def PH(*bars):
    """Frase: un texto por compás, '0:F#5/3 3:C#5/2' = corchea de entrada : nota / duración en corcheas"""
    out = []
    for i, txt in enumerate(bars):
        for tok in txt.split():
            st, rest = tok.split(':'); nm, d = rest.split('/')
            out.append((i + 1, float(st), 12 * (int(nm[-1]) + 1) + N[nm[:-1]], float(d)))
    return out


MIRROR = "0:C#6/3 3:G#5/3 6:F5/3 9:C#5/3"                    # el motivo del espejo (Mi# escrito Fa)
T_A = ["0:F#5/3 3:C#5/2 5:F#5/1 6:A5/3 9:G#5/2 11:F#5/1", "0:A5/3 3:F#5/2 5:A5/1 6:D6/6",
       "0:B5/3 3:G#5/2 5:B5/1 6:E6/3 9:D6/2 11:B5/1", MIRROR,
       "0:F#5/3 3:C#5/2 5:F#5/1 6:A5/3 9:B5/2 11:C#6/1", "0:D6/3 3:B5/2 5:D6/1 6:F#6/6",
       "0:D6/2 2:B5/2 4:G5/2 6:F5/2 8:G#5/2 10:C#6/2"]       # napolitana y dominante, en hemiolia: el espejo, hacia arriba
A_END = ["0:F#5/6 6:A5/3 9:C#6/3"]
A_END2 = ["0:F#5/9"]
CH_A = ['F#m', 'D', 'E', 'C#', 'F#m', 'Bm', ['G', 'C#'], 'F#m']
T_B = ["0:B5/2 2:D6/2 4:F#6/2 6:D6/3 9:B5/3", "0:G#5/2 2:B5/2 4:E6/2 6:B5/3 9:G#5/3",
       "0:A5/2 2:C#6/2 4:E6/2 6:C#6/3 9:A5/3", "0:F#5/2 2:A5/2 4:D6/2 6:A5/3 9:F#5/3",
       "0:G5/3 3:B5/3 6:D6/6", "0:D6/3 3:B5/3 6:G5/3 9:B5/3", MIRROR, "0:F5/3 3:G#5/3 6:C#6/6"]
CH_B = ['Bm', 'E', 'A', 'D', 'G', 'G', 'C#', 'C#']
T_C = ["0:E5/6 6:A5/3 9:C#6/3", "0:B5/9 9:G#5/3", "0:A5/6 6:C#6/3 9:F#5/3", "0:F#5/9 9:A5/3",
       "0:C#6/6 6:A5/3 9:E5/3", "0:G#5/6 6:B5/3 9:E6/3", "0:D6/6 6:A5/3 9:F#5/3", "0:F5/12"]
CH_C = ['A', 'E', 'F#m', 'D', 'A', 'E', 'D', 'C#']
T_D = ["0:C#5/3 3:F5/3 6:G#5/6", "0:F5/3 3:G#5/3 6:C#6/6", "0:G#5/3 3:C#6/3 6:F6/6",
       "0:C#6/2 2:C#6/2 4:C#6/2 6:C#6/1 7:C#6/1 8:C#6/1 9:C#6/1 10:C#6/1 11:C#6/1"]
CH_D = ['C#'] * 4
# SEGUNDA VERSIÓN del final (el usuario, tras jugar la pelea: "más épica-MELANCÓLICA que épica-AGRESIVA; después de la
# muestra de level, melodías más agresivas, de notas cortas y con pegada, más movimiento rítmico y urgencia; los
# respiros y la atmósfera, bien"). Antes el clímax era Fa# MAYOR con la llamada en notas largas: triunfal, dulce.
# Ahora, tras "el tema del héroe":
#   G — FURIA: un riff en picado, corchea a corchea, nota repetida y salto (Fa#m, con la napolitana Sol), y el motivo
#       del espejo MARTILLEADO (cada nota tres veces); bajo al unísono en corcheas, doble bombo continuo.
#   E — CLÍMAX en menor y con quintas (sin terceras dulces): la llamada martilleada (Do#×3 Fa#×3 La×3 Do#) y frases de
#       galope (larga-corta) sobre i–♭VI–♭VII–i; acaba con el espejo, también a golpes, sobre la dominante.
# Además, en TODAS las secciones fuertes: el tema va al galope (cada negra con puntillo se parte en larga-corta, la
# corta repitiendo la nota), las notas cortas se cortan antes (picado), el pulso que dobla la melodía TREMOLA en
# corcheas sobre las notas largas, y el bombo galopa. Y sube de 150 a 158.
T_G = ["0:F#5/1 1:F#5/1 2:A5/1 3:F#5/1 4:F#5/1 5:C#6/1 6:F#5/1 7:F#5/1 8:A5/1 9:G#5/1 10:F#5/1 11:E5/1",
       "0:F#5/1 1:F#5/1 2:A5/1 3:F#5/1 4:F#5/1 5:C#6/1 6:B5/2 8:A5/2 10:G#5/2",
       "0:G5/1 1:G5/1 2:B5/1 3:G5/1 4:G5/1 5:D6/1 6:G5/1 7:G5/1 8:B5/1 9:A5/1 10:G5/1 11:F#5/1",
       "0:F#5/1 3:F#5/1 6:C#6/1 7:C#6/1 8:C#6/1 9:A5/1 10:G#5/1 11:F#5/1",
       "0:C#6/1 1:C#6/1 2:E6/1 3:C#6/1 4:C#6/1 5:F#6/1 6:C#6/1 7:C#6/1 8:E6/1 9:D6/1 10:C#6/1 11:B5/1",
       "0:B5/1 1:B5/1 2:D6/1 3:B5/1 4:B5/1 5:G5/1 6:B5/1 7:B5/1 8:D6/1 9:C#6/1 10:B5/1 11:A5/1",
       "0:C#6/1 1:C#6/1 2:C#6/1 3:G#5/1 4:G#5/1 5:G#5/1 6:F5/1 7:F5/1 8:F5/1 9:C#5/1 10:C#5/1 11:C#5/1",
       "0:C#5/1 1:F5/1 2:G#5/1 3:C#6/1 4:G#5/1 5:F5/1 6:C#6/2 8:C#6/2 10:C#6/2"]
CH_G = ['F#m', 'F#m', 'G', 'F#m', 'F#m', 'G', 'C#', 'C#']
# (3ª versión del final. La furia duraba 8 compases y tras el clímax el bucle saltaba DIRECTO al tema A: "se acaba
# antes de que la furia termine de desarrollarse y el bucle queda raro, de lo más intenso a la parte inicial más
# calmada". Ahora la furia tiene una segunda mitad — el riff una cuarta arriba (Sim, Do) y su remate martilleado —
# y después del clímax hay una CAÍDA de 4 compases que es la intro otra vez (el motivo del espejo despacio sobre la
# dominante, timbales, la música se vacía y el redoble vuelve a subir): el tema A entra igual que la primera vez.)
def _up(bars, semis):
    out = []
    for txt in bars:
        toks = []
        for tok in txt.split():
            st, rest = tok.split(':'); nm, d = rest.split('/')
            m = 12 * (int(nm[-1]) + 1) + N[nm[:-1]] + semis
            toks.append('%s:%s%d/%s' % (st, [k for k, v in N.items() if v == m % 12][0], m // 12 - 1, d))
        out.append(' '.join(toks))
    return out
T_G2 = _up(T_G[:4], 5) + T_G[4:]
CH_G2 = ['Bm', 'Bm', 'C', 'Bm', 'F#m', 'G', 'C#', 'C#']
T_H = ["0:C#6/6 6:G#5/6", "0:F5/6 6:C#5/6", "0:C#5/3 3:G#4/3 6:F4/3 9:C#4/3", "0:C#5/12"]
CH_H = ['C#'] * 4
T_E = ["0:C#5/1 1:C#5/1 2:C#5/1 3:F#5/1 4:F#5/1 5:F#5/1 6:A5/1 7:A5/1 8:A5/1 9:C#6/3",          # LA LLAMADA, martilleada
       "0:D6/2 2:D6/1 3:A5/2 5:A5/1 6:F#5/2 8:F#5/1 9:A5/3", "0:E6/2 2:E6/1 3:B5/2 5:B5/1 6:G#5/2 8:G#5/1 9:B5/3",
       "0:F#6/3 3:C#6/1 4:C#6/1 5:C#6/1 6:F#6/6",
       "0:C#6/1 1:C#6/1 2:C#6/1 3:F#6/1 4:F#6/1 5:F#6/1 6:A5/1 7:A5/1 8:A5/1 9:C#6/3",
       "0:F#6/2 2:F#6/1 3:D6/2 5:D6/1 6:A5/2 8:A5/1 9:D6/3", "0:E6/2 2:E6/1 3:G#5/2 5:G#5/1 6:B5/2 8:B5/1 9:E6/3",
       "0:C#6/2 2:C#6/1 3:G#5/2 5:G#5/1 6:F5/2 8:F5/1 9:C#5/3"]                                    # …y el espejo, a golpes
CH_E = ['F#m', 'D', 'E', 'F#m', 'F#m', 'D', 'E', 'C#']
# F — "EL TEMA DEL HÉROE": la muestra de la antigua música de nivel del juego (level.ogg, 0:40-1:01 = sus compases
# 25-28 y el cierre 33-36), pedida por el usuario. Estaba en Do menor (Fam · Sol · Dom | Fam · Sol · La♭ · Si♭): subida
# un tritono cae en Sim · Do# · Fa#m | Sim · Do# · Re · Mi, que son los acordes de ESTE tema; sus ritmos 3+3+2 pasan a
# tres negras (la hemiolia que el tema ya usa en su compás 7); y su cierre ♭VI–♭VII (Re–Mi, con La-Sol#-La-Si subiendo)
# desemboca en el clímax en Fa# MAYOR, donde contesta la llamada. Va justo antes del clímax: la música de los niveles
# vuelve en la batalla final.
T_F = ["0:A5/6 6:F#5/6", "0:C#6/2 2:B5/2 4:A5/2 6:G#5/2 8:A5/2 10:B5/2",
       "0:C#5/2 2:E5/2 4:A5/2 6:G#5/3 9:E5/2 11:F#5/1", "0:C#5/9",
       "0:D5/3 4:D5/1 5:E5/1 6:F#5/2 8:E5/2 10:D5/2", "0:E5/3 4:E5/1 5:F#5/1 6:G#5/2 8:F#5/2 10:E5/2",
       "0:F#5/6 6:D5/6", "0:A5/3 3:G#5/3 6:A5/3 9:B5/3"]
CH_F = ['Bm', 'C#', 'F#m', 'F#m', 'Bm', 'C#', 'D', 'E']
T_IN = ["0:C#6/6 6:G#5/6", "0:F5/6 6:C#5/6", "0:C#5/3 3:G#4/3 6:F4/3 9:C#4/3", "0:C#5/12"]
CH_IN = ['C#'] * 4


GALLOP = ('A', 'A2', 'A3', 'B')            # (las secciones del tema; F, G y E ya traen su ritmo escrito)


def song():
    mel, chords, tag, starts = [], [], [], []

    def section(kind, bars, cs):
        base = len(chords)
        starts.append(base + 1)
        for b, st, n, d in PH(*bars):
            if kind in GALLOP and d == 3 and st % 3 == 0:      # al GALOPE: la negra con puntillo se parte en larga-corta
                mel.append((base + b, st, n, 2)); mel.append((base + b, st + 2, n, 1))
            else:
                mel.append((base + b, st, n, d))
        for c in cs:
            chords.append((ch(c[0]), ch(c[1])) if isinstance(c, list) else (ch(c), ch(c)))
            tag.append(kind)
    section('IN', T_IN, CH_IN)
    section('A', T_A + A_END, CH_A)
    section('A2', T_A + A_END2, CH_A)
    section('B', T_B, CH_B)
    section('C', T_C, CH_C)
    section('D', T_D, CH_D)
    section('A3', T_A + A_END, CH_A)
    section('F', T_F, CH_F)
    section('G', T_G, CH_G)
    section('G2', T_G2, CH_G2)
    section('E', T_E, CH_E)
    section('H', T_H, CH_H)
    SAMPLE.clear(); SAMPLE.update(range(starts[7], starts[7] + 8))
    SAMPLE.update(range(starts[8], starts[8] + 16))                # (la furia: riff de notas de paso, no cuenta)
    return mel, chords, tag, starts


def invert(n, chord):
    """El ESPEJO de una nota: inversión diatónica alrededor de Fa#5; si cae fuera del acorde, a su nota más cercana"""
    pc = n % 12
    i = SCALE.index(pc) if pc in SCALE else SCALE.index(min(SCALE, key=lambda p: min((pc - p) % 12, (p - pc) % 12)))
    deg = (n - 78 - ((SCALE[i] - 6) % 12)) // 12 * 7 + i          # grados desde Fa#5
    k = -deg
    m = 78 + (k // 7) * 12 + (SCALE[k % 7] - 6) % 12
    r, q = chord
    tones = [m + dd for dd in range(-4, 5) if (m + dd - r) % 12 in q]
    return min(tones, key=lambda t: abs(t - m))


SAMPLE = set()                           # compases de la muestra prestada (sus séptimas y notas de paso no cuentan)


def check(mel, chords):
    """Las notas que duran un tiempo (≥ 3 corcheas) son del acorde que suena cuando empiezan"""
    return [(b, st) for b, st, n, d in mel if d >= 3 and b not in SAMPLE and (n - chords[b - 1][0 if st < 6 else 1][0]) % 12 not in chords[b - 1][0 if st < 6 else 1][1]]


WAVES = [wavetable([1.0, 0.5, 0.33, 0.2, 0.12]),               # 0 voz suave (puente)
         GN.CWAVES[0],                                         # 1 caja de música / campanas
         wavetable([1.0, 0.25, 0.4, 0.1, 0.2])]                # 2 coro (colchón)
I_SAW = {'vol': [15, 15, 14, 14, 13, 13], 'sus': 13, 'vib': (14, 0.2, 6)}
I_PUL = {'vol': [11, 10, 9, 8, 8, 7], 'sus': 7, 'duty': [0.125, 0.25]}
I_CTR = {'vol': [10, 9, 8, 8, 7, 7], 'sus': 7, 'duty': 0.125}                # la voz del espejo
I_SOFT = {'vol': [8, 11, 12, 12, 11, 11], 'sus': 11, 'vib': (16, 0.18, 5.0), 'duty': 0.0}
I_BELL = dict(GN.I_BELL, duty=1.0)
I_CHOIR = {'vol': [3, 5, 7, 8, 9, 9, 10], 'sus': 10, 'vib': (20, 0.12, 4.5), 'duty': 2.0}
I_TRI = {'vol': [15], 'sus': 15}
I_BDEF = {'vol': [12, 9, 6, 4, 3, 2], 'sus': 2, 'duty': 0.5}
I_STAB = {'vol': [13, 11, 8, 5, 3, 2], 'sus': 1, 'duty': 0.25}
I_ARP = {'vol': [7, 5, 3, 2], 'sus': 1, 'duty': 0.125}
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
LOUD = ('A', 'A2', 'A3', 'B', 'E', 'F', 'G')


def build(lufs=-9.5):
    mel, chords, tag, starts = song()
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'dbl', 'ctr', 'soft', 'bell', 'p1', 'p2', 'c1', 'c2', 'arp', 'bass', 'bdef')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash', 'fx')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S8

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # ── MELODÍA y sus capas ──
    # LA FURIA, INTEGRADA (el usuario: buena, pero contrasta demasiado con el resto): mismo bajo al galope que el tema
    # (el unísono en corcheas solo en su remate), bombo al galope hasta ese remate, el mismo arpegio brillante y el
    # coro con tercera que llevan las demás secciones, notas un poco menos secas, y entra al volumen en que acabó F
    ALIAS = {'G2': 'G', 'H': 'IN'}                             # (la 2ª mitad de la furia y la caída se arreglan como G y la intro)
    for b, st, n, d in mel:
        kind = ALIAS.get(tag[b - 1], tag[b - 1])
        t0, t1 = tv(b, st), tv(b, st) + d * S8 * 0.93
        if kind == 'C':                                        # el puente: voz suave + caja de música una octava arriba
            play(Cn['soft'], t0, t1, n, I_SOFT, q=q_n163, release=4)
            play(Cn['bell'], t0, t0 + max(d, 3) * S8, n + 12, I_BELL, q=q_n163, release=6)
        elif kind == 'IN':                                     # la intro: el motivo en las campanas y el coro
            play(Cn['bell'], t0, t0 + d * S8, n, I_BELL, q=q_n163, release=8)
            play(Cn['p1'], t0, t1, n - 12, I_CHOIR, q=q_n163, release=6)
        elif kind == 'D':                                      # la subida: solo el pulso, cada vez más fuerte
            play(Cn['dbl'], t0, t1, n, I_PUL, vs=0.8 + 0.12 * (b - starts[4]), release=2)
        else:
            if d <= 2: t1 = tv(b, st) + d * S8 * (0.85 if kind == 'G' else 0.7)     # picado: las notas cortas, más cortas
            play(Cn['lead'], t0, t1, n - 12, I_SAW, q=q_saw, release=2 if d <= 2 else 3)
            up = 12 if kind in ('E', 'F', 'G') else 0
            if d >= 4:                                             # sobre las notas largas el pulso TREMOLA en corcheas
                for i_ in range(int(d)):
                    play(Cn['dbl'], t0 + i_ * S8, t0 + (i_ + 0.6) * S8, n + up, I_PUL, release=1)
            else:
                play(Cn['dbl'], t0, t1, n + up, I_PUL, release=2)
            if kind in ('A2', 'A3', 'E', 'F', 'G'): play(Cn['bell'], t0, t0 + max(d, 3) * S8, n + 12, I_BELL, q=q_n163, release=6)
            if kind == 'A3':                                   # el ESPEJO: la inversión, a la vez, una octava abajo
                play(Cn['ctr'], t0, t1, invert(int(n), chords[b - 1][0 if st < 6 else 1]) - 12, I_CTR, release=2)

    def bass(b, st, ln, note, define=True):
        t = tv(b, st)
        play(Cn['bass'], t, t + ln * S8, note, I_TRI, q=q_tri, release=0)
        if define: play(Cn['bdef'], t, t + min(ln, 1.6) * S8, note + 12, I_BDEF, release=1)

    for b in range(1, NB + 1):
        kind = tag[b - 1]
        k = b - starts[['IN', 'A', 'A2', 'B', 'C', 'D', 'A3', 'F', 'G', 'G2', 'E', 'H'].index(kind)] + 1
        raw = kind                            # compás dentro de la sección
        kind = ALIAS.get(kind, kind)
        fin = raw == 'G2' and k >= 5          # el remate de la furia: ahí sí, todo a corcheas
        last = (b + 1) in starts or b == NB
        lo = lambda r: 30 + (r - 30) % 12                      # (el bajo, de Fa#1 hacia arriba)
        for half, (r, q) in enumerate(chords[b - 1]):
            s0 = half * 6
            notes = [66 + (r - 66) % 12 + iv for iv in q]
            # ── BAJO ──
            if kind == 'IN':
                if half == 0: bass(b, 0, 11.5, lo(r), False)                  # pedal
            elif kind == 'C':
                bass(b, s0, 5.6, lo(r) + 12, False)                           # notas largas, una octava arriba
            elif kind == 'D' or fin:
                for st in range(6): bass(b, s0 + st, 0.9, lo(r) + (12 if fin and st in (2, 5) else 0))   # corcheas (remate de la furia: al unísono con el riff)
            else:                                                             # GALOPE: larga-corta, la corta en la octava
                for bt in (0, 3):
                    bass(b, s0 + bt, 1.8, lo(r)); bass(b, s0 + bt + 2, 0.9, lo(r) + (12 if kind != 'B' else 7))
            # ── CORO (colchón): tercera y quinta; fuerte en el clímax ──
            if kind in ('A2', 'A3', 'B', 'C', 'E', 'D', 'F', 'G'):
                if kind == 'E': notes = [notes[0], notes[0] + 12, notes[2]]                # (clímax: quintas, sin la tercera)
                vs = {'E': 1.5, 'G': 1.1, 'F': 1.2, 'C': 0.9, 'D': 0.6 + 0.2 * k}.get(kind, 0.8)
                play(Cn['p1'], tv(b, s0), tv(b, s0) + 5.7 * S8, notes[1], I_CHOIR, q=q_n163, vs=vs, release=5)
                play(Cn['p2'], tv(b, s0), tv(b, s0) + 5.7 * S8, notes[2], I_CHOIR, q=q_n163, vs=vs, release=5)
            # ── GOLPES de quinta en cada tiempo fuerte ──
            if kind in LOUD:
                for bt in ((0, 3) if kind in ('A3', 'E', 'F', 'G') else (0,)):
                    root = 54 + (r - 54) % 12
                    play(Cn['c1'], tv(b, s0 + bt), tv(b, s0 + bt) + 2.2 * S8, root, I_STAB, release=2)
                    play(Cn['c2'], tv(b, s0 + bt), tv(b, s0 + bt) + 2.2 * S8, root + 7, I_STAB, release=2)
            # ── ARPEGIO en corcheas: el acompañamiento del puente, y brillo en A', A'' y el clímax ──
            if kind in ('C', 'A2', 'A3', 'E', 'F', 'G'):
                if kind == 'E': notes = [66 + (r - 66) % 12 + iv for iv in q]
                for st in range(6):
                    nn = notes[(0, 1, 2, 1, 2, 1)[st] if kind == 'C' else st % 3] + (12 if kind != 'C' else 0) + (12 if st >= 3 and kind != 'C' else 0)
                    play(Cn['arp'], tv(b, s0 + st), tv(b, s0 + st) + S8 * (1.6 if kind == 'C' else 0.7), nn, I_ARP, vs=1.4 if kind == 'C' else 1.0, release=2 if kind == 'C' else 0)
        # ── BATERÍA (12/8: tiempos en 0, 3, 6, 9) ──
        for st in range(12):
            t = tv(b, st)
            if kind == 'IN':                                                  # timbales y, al final, el redoble
                if st in (0, 6): hit(tom, W.TOMS[2], t, 1.0); hit(kick, TN.KICK_DEEP, t, 0.9)
                if k >= 3 and st % 3 == 0: hit(tom, W.TOMS[1], t, 0.7)
                if k == 4:
                    snare(t, 0.3 + st * 0.05, [5 + st // 2, 3, 1]); snare(t + S8 / 2, 0.25 + st * 0.05, [4 + st // 2, 2, 1])
            elif kind == 'C':                                                 # casi nada: bombo en el 1 y el 3, platos en los tiempos
                if st in (0, 6): hit(kick, TN.KICK, t, 0.6)
                if st % 3 == 0: NZ['hat'].hit(t, 0, [4, 2, 1])
                elif st % 3 == 2: NZ['hat'].hit(t, 0, [2, 1])
            elif kind == 'D':                                                 # redoble que crece: corcheas → semicorcheas, timbales al final
                v = 0.3 + 0.15 * k + st * 0.02
                snare(t, v, [5 + 2 * k, 4, 2])
                if k >= 3: snare(t + S8 / 2, v * 0.8, [4 + 2 * k, 3, 1])
                if st % 3 == 0: hit(kick, TN.KICK, t, 0.8)
                if k == 4 and st >= 6: hit(tom, W.TOMS[min(2, (st - 6) // 2)], t, 1.0)
            else:
                heavy = kind in ('A3', 'E', 'F', 'G')
                # bombo al GALOPE en todo lo fuerte (0·2·3·5·6·8·9·11); en la furia y el clímax, corcheas seguidas
                if st % 3 != 1 or kind == 'E' or fin: hit(kick, TN.KICK, t, 1.0 if st in (0, 6) else (0.85 if st % 3 == 0 else 0.7))
                if st in (3, 9): snare(t, 1.0)
                elif heavy and st in (7, 10): snare(t, 0.35, [6, 3, 1])
                NZ['hat'].hit(t, 1, [5, 2, 1] if st % 3 == 0 else [3, 1]) if st not in (3, 9) else None
                if kind == 'B' and st in (10, 11) and k % 2 == 0: hit(tom, W.TOMS[st - 9], t, 0.9)
                if kind == 'E' and st == 0: hit(tom, W.TOMS[2], t, 0.9)       # timbal en cada compás del clímax
                if last and st >= 6: snare(t, 0.5 + (st - 6) * 0.08, [8 + (st - 6), 5, 2]); hit(tom, W.TOMS[min(2, (st - 6) // 2)], t, 0.7)
            # platillos: al entrar cada sección; cada 2 compases en las fuertes; cada compás en el clímax
            if st == 0 and b > INTRO and (k == 1 and kind != 'C' or (kind in LOUD and k % 2 == 1) or kind in ('E', 'G')): NZ['crash'].hit(t, 3, CRASH)
        # subida de ruido en el último compás de la intro y de D, y antes del clímax
        if (kind in ('IN', 'D') and k == 4) or (kind in ('F', 'G') and k == 8):
            n_ = int(BAR * 60)
            for i_ in range(n_):
                x_ = i_ / (n_ - 1)
                NZ['fx'].hit(tv(b, 0) + i_ / 60.0, int(round(9 - 7 * x_)), [max(1, int(round(10 * x_ ** 1.5)))])

    n = int(NB * BAR * SR)
    n_i = int(INTRO * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k_: cut(F.pulse_dac(F.render_pulse(Cn[k_])))
    wave = lambda k_: cut(F.render_wave(Cn[k_], WAVES) * 0.0075)
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    S = {
        'lead': cut(F.pulse_dac(F.render_saw(Cn['lead']))), 'dbl': pulse('dbl'), 'mirror': pulse('ctr'), 'soft': wave('soft'),
        'bell': wave('bell'), 'choir': wave('p1') + wave('p2'), 'stabs': pulse('c1') + pulse('c2'), 'arp': pulse('arp'),
        'bass': cut(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)), 'bdef': pulse('bdef'),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + cut(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
        'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12)),
        'crash': cut(F.tnd_dac(NZ['crash'].render() / 22638.0 * 12)) + cut(F.tnd_dac(NZ['fx'].render() / 22638.0 * 12)),
    }
    S = {k_: GN.fold(v, n, n_i) for k_, v in S.items()}
    S['bell'] = GN.delay(S['bell'], 2 * S8, 0.3, 2, 3000)[:len(S['bell'])]
    LV = {'lead': 0, 'dbl': -7, 'mirror': -5, 'soft': -3, 'bell': -5, 'choir': -6, 'stabs': -9, 'arp': -12,
          'bass': 0, 'bdef': -8, 'kick': 0, 'toms': -2, 'snare': -2, 'hat': -12, 'crash': -9}
    # (el acompañamiento, +3 dB respecto a la melodía: en el juego la melodía tapaba lo demás — BACKING, worlds_nes.py)
    for k_ in ('choir', 'stabs', 'arp', 'bass', 'bdef', 'kick', 'toms', 'snare', 'hat', 'crash'): LV[k_] = LV[k_] + 3.0
    g = GN.level(S, LV, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k_] * g[k_] for k_ in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    side = S['arp'] * g['arp'] * 0.6 + S['choir'] * g['choir'] * 0.4 - S['mirror'] * g['mirror'] * 0.5 + S['bell'] * g['bell'] * 0.3 + S['hat'] * g['hat'] * 0.3
    # DINÁMICA por secciones (dB): la mezcla por capas deja todo igual de fuerte — el puente salía MÁS alto que el
    # tema —; aquí se dibuja la escalada: intro contenida, respiro en el puente, la subida crece y el clímax es el techo
    DYN = {'IN': (-3.5, -2.0), 'A': (0, 0), 'A2': (0.5, 0.5), 'B': (0.5, 1.0), 'C': (-6.0, -5.0), 'D': (-6.0, -0.5), 'A3': (1.0, 1.5), 'F': (1.5, 2.0), 'G': (2.0, 2.8), 'G2': (2.8, 3.5), 'E': (4.0, 4.0), 'H': (1.5, -2.5)}
    env = np.ones(len(x))
    for b in range(1, NB + 1):
        a_, e_ = DYN[tag[b - 1]]
        first = max(i for i in starts if i <= b); nxt = min([i for i in starts if i > b] + [NB + 1])
        i0, i1 = int((b - 1) * BAR * SR), min(len(x), int(b * BAR * SR))
        u = (np.arange(i1 - i0) / (i1 - i0) + (b - first)) / (nxt - first)
        env[i0:i1] = 10 ** ((a_ + (e_ - a_) * u) / 20)
    k_ = int(0.03 * SR); env = np.convolve(np.pad(env, k_, mode='edge'), np.ones(2 * k_ + 1) / (2 * k_ + 1), mode='valid')[:len(x)]
    x, side = x * env, side * env
    y = F.master(np.stack([x + side, x - side], 1), lufs=lufs)
    GN.report('mirror_boss', y, S, g, n)
    # cuánto suena cada sección (la escalada y los respiros, en dB respecto al tema A)
    mono = y.mean(1)
    def rms(i0, i1): return 20 * np.log10(np.sqrt(np.mean(mono[int((i0 - 1) * BAR * SR):int((i1 - 1) * BAR * SR)] ** 2)) + 1e-9)
    names = ['intro', 'A', "A'", 'B', 'C puente', 'D subida', "A''", 'F héroe', 'G furia', 'G furia 2', 'E clímax', 'H caída']
    ends = starts[1:] + [NB + 1]
    ref = rms(starts[1], ends[1])
    print('  secciones (dB respecto a A): ' + ' · '.join('%s %+.1f' % (nm, rms(a, e) - ref) for nm, a, e in zip(names, starts, ends)))
    print(f'  {BPM} negras con puntillo/min, 12/8; intro {INTRO} + bucle {NB - INTRO} compases ({(NB - INTRO) * BAR:.1f} s); melodía {len(mel)} notas')
    print(f'  notas de un tiempo o más fuera del acorde: {check(mel, chords) or "ninguna"}')
    return y, mel, n_i


def write_mid(path, mel):
    import mido
    mid = mido.MidiFile(ticks_per_beat=480)
    tr = mido.MidiTrack(); mid.tracks.append(tr)
    tr.append(mido.MetaMessage('time_signature', numerator=12, denominator=8, time=0))
    tr.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / (BPM * 1.5)), time=0))
    ev = []
    for b, st, n, d in mel:
        t0 = int(((b - 1) * 12 + st) * 240)
        ev += [(t0, 'note_on', n), (t0 + int(d * 240) - 10, 'note_off', n)]
    t = 0
    for tt, kind, n in sorted(ev):
        tr.append(mido.Message(kind, note=int(n), velocity=96, time=tt - t)); t = tt
    mid.save(path)


if __name__ == '__main__':
    y, mel, n_i = build()
    if not os.environ.get('REPORT'):
        GN.export('mirror_boss', y, n_i)
        write_mid(F.out('mirror_boss', 'mid'), mel)
