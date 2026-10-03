#!/usr/bin/env python3
# CRAB TANTRUM — el tema del Mega Crabby, composición propia (ya no es el arreglo nota a nota de "Tentacle Tantrum").
#
# Es la BASE de los tres Mega Crabbies: de aquí saldrán la versión lúgubre y la helada (mismo tema, otra atmósfera).
#
# De "Tentacle Tantrum" solo se toman MUESTRAS, como quien samplea (lo demás es nuevo: respuestas, estribillo, puente,
# armonía, bajo y batería):
#   1. la CÉLULA del riff: tónica larga, tónica, sube una cuarta, baja a la tercera, tónica — con su ritmo 6-2-2-4-4.
#      Abre las frases de A (compases 1, 3 y, variada, 5) y la toca el BAJO en el puente tribal
#   2. el TRESILLO 3+3+2 (6-6-4 semicorcheas) del bajo y el bombo
#   3. el giro del estribillo: nota larga y bordadura inferior (una vez por frase de B)
#   4. la idea rítmica del final: notas repetidas sincopadas (6-4-4-4) sobre acordes que suben
# Y es de la COSTA, la isla del Mega Crabby: Re menor = el relativo de Fa
# mayor (la primera versión abría el estribillo a Fa mayor: quitado, ver PH_B); la marimba de la costa toca el tresillo; la maraca en semicorcheas; cierra con "la llamada" (La-Re-Fa-La).
# Carácter (el usuario): potente, TRIBAL y agresivo — timbales en ostinato, bombo marcado, bajo bien definido
# (triángulo + un pulso que lo dibuja una octava arriba), sierra del VRC6 + pulso en la melodía.
#
# Forma (compases de 16 semicorcheas a 180; se siente a 90): intro 4 (tambores; suena una vez, archivo aparte) ·
# A 8 · A' 8 · B 8 · B' 8 · PUENTE tribal 8 · A'' 8 · CODA 8 = bucle de 56 compases (74,7 s).
#
#   python tools/music/crab_tantrum.py [normal gloomy icy]  → assets/music/bosses/crab_tantrum_<x>_{intro,loop}.ogg + .mid
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_tri, q_saw, q_n163, q_vrc6
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W

BPM = 180
S16 = 60.0 / BPM / 4
BAR = 16 * S16
INTRO = 4

N = {'C': 0, 'C#': 1, 'D': 2, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'Ab': 8, 'A': 9, 'Bb': 10, 'B': 11}
MAJ, MIN = (0, 4, 7), (0, 3, 7)
SCALE = {2, 4, 5, 7, 9, 10, 0}                    # Re menor natural


def ch(s):
    return (N[s[:-1]], MIN) if s.endswith('m') else (N[s], MAJ)


A4, Bb4, C5, Cs5, D5, E5, F5, G5, A5, Bb5, C6, D6 = 69, 70, 72, 73, 74, 76, 77, 79, 81, 82, 84, 86

# ── Melodía: (compás de la frase, semicorchea, nota, duración). Una nota puede cruzar la barra (como en el riff) ──
CELL = [(1, 0, D5, 6), (1, 6, D5, 2), (1, 8, G5, 2), (1, 10, F5, 4)]                    # la muestra del riff
PH_A = CELL + [
    (1, 14, D5, 4),
    (2, 2, A4, 2), (2, 4, C5, 2), (2, 6, D5, 2), (2, 8, F5, 4), (2, 12, D5, 4),         # respuesta (nueva)
    (3, 0, D5, 6), (3, 6, D5, 2), (3, 8, G5, 2), (3, 10, F5, 4), (3, 14, A5, 4),        # la célula, que ahora sube
    (4, 2, A5, 4), (4, 6, G5, 2), (4, 8, G5, 2), (4, 10, E5, 2), (4, 12, C5, 4),
    (5, 0, D5, 6), (5, 6, D5, 2), (5, 8, F5, 2), (5, 10, D5, 4), (5, 14, Bb4, 4),       # su ritmo sobre Si♭
    (6, 2, Bb4, 4), (6, 6, D5, 2), (6, 8, E5, 4), (6, 12, G5, 4),
    (7, 0, D5, 6), (7, 6, D5, 2), (7, 8, G5, 2), (7, 10, F5, 4), (7, 14, D5, 4),        # la célula otra vez…
]
# CUARTO ENFOQUE para lo que no es muestra (el cierre de A y el estribillo). v1: cadencia en La mayor y estribillo en
# Fa mayor ("la melodía no encaja, armonía rara"); v2: otra progresión menor y otra melodía ("más raro"); v3:
# pentatónica y estribillo de notas largas en secuencia ("mejor, pero no encaja del todo con el personaje, y el paso
# de lo que estaba bien a estas partes es raro"). Ahora: (a) A se cierra con el propio riff — la célula y su COLA
# (tónica, tónica, ♭VI, ♭VII: la segunda mitad del riff original, otra muestra), nada inventado encima; (b) el
# estribillo ya no es "cantado": es un GRITO DE GUERRA — notas cortas repetidas a golpe de tresillo (3+3+2) y una
# caída con el ritmo de la célula —, y NO cambia de ritmo: sigue el mismo tresillo a medio tiempo de A, con más
# timbales (antes pasaba a bombo a negras y bajo en corcheas: de ahí la transición rara).
A_END = [(8, 2, D5, 4), (8, 6, D5, 2), (8, 8, Bb4, 4), (8, 12, C5, 4)]                  # …y su cola: ♭VI–♭VII
A_END2 = [(8, 2, D5, 4), (8, 6, D5, 2), (8, 8, F5, 4), (8, 12, G5, 4)]                  # la cola, hacia arriba (al estribillo)
PH_B = [
    (1, 0, D5, 2), (1, 3, D5, 2), (1, 6, D5, 2), (1, 8, F5, 2), (1, 11, F5, 2), (1, 14, G5, 2),      # el grito: 3+3+2
    (2, 0, A5, 6), (2, 6, G5, 2), (2, 8, F5, 2), (2, 10, D5, 4),                                     # la caída
    (3, 0, D5, 2), (3, 3, D5, 2), (3, 6, D5, 2), (3, 8, F5, 2), (3, 11, F5, 2), (3, 14, Bb5, 2),
    (4, 0, C6, 6), (4, 6, A5, 2), (4, 8, G5, 6),
    (5, 0, A5, 2), (5, 3, A5, 2), (5, 6, A5, 2), (5, 8, C6, 2), (5, 11, C6, 2), (5, 14, D6, 2),      # más arriba
    (6, 0, D6, 6), (6, 6, C6, 2), (6, 8, A5, 2), (6, 10, F5, 4),
    (7, 0, F5, 2), (7, 3, F5, 2), (7, 6, F5, 2), (7, 8, D5, 2), (7, 11, D5, 2), (7, 14, F5, 2),
]
B_END = [(8, 0, G5, 6), (8, 6, G5, 2), (8, 8, E5, 2), (8, 10, G5, 4)]
B_END2 = [(8, 0, G5, 3), (8, 3, A5, 3), (8, 6, C6, 2), (8, 8, C6, 8)]
# Puente tribal: tambores y el riff en el BAJO; la voz contesta desde el 5º compás (la célula, una octava abajo)
PH_BR = [(5, 0, D5 - 12, 6), (5, 6, D5 - 12, 2), (5, 8, G5 - 12, 2), (5, 10, F5 - 12, 4),
         (7, 0, D5, 6), (7, 6, D5, 2), (7, 8, G5, 2), (7, 10, F5, 4), (7, 14, A5, 4)]
# Coda: notas repetidas sincopadas (6-4-4-4) subiendo ♭VI–♭VII–i, y la llamada
PH_CODA = [
    (1, 0, F5, 6), (1, 6, F5, 4), (1, 10, F5, 4), (1, 14, G5, 4),
    (2, 2, G5, 6), (2, 8, G5, 4), (2, 12, G5, 4),
    (3, 0, A5, 6), (3, 6, A5, 4), (3, 10, A5, 4), (3, 14, A5, 4),
    (4, 2, A5, 4), (4, 6, G5, 2), (4, 8, F5, 4), (4, 12, D5, 4),
    (5, 0, Bb5, 6), (5, 6, Bb5, 4), (5, 10, Bb5, 4), (5, 14, C6, 4),
    (6, 2, C6, 6), (6, 8, C6, 4), (6, 12, C6, 4),
    (7, 0, D6, 6), (7, 6, D6, 4), (7, 10, D6, 4), (7, 14, D6, 2),
    (8, 0, A4, 4), (8, 4, D5, 2), (8, 6, F5, 2), (8, 8, A5, 6),                         # la llamada: La-Re-Fa-La
]
# Armonía: por compás, uno o dos acordes (medio compás cada uno)
CH_A = ['Dm', ['Dm', 'Bb'], 'Dm', ['Dm', 'C'], 'Bb', ['Bb', 'C'], 'Dm', ['Dm', 'Bb', 'C']]    # (la cola: Si♭ y Do, una negra cada uno)
CH_B = ['Dm', 'Dm', 'Bb', 'C', 'Dm', 'Dm', 'Bb', 'C']
CH_B2 = CH_B
CH_BR = ['Dm'] * 8
CH_CODA = ['Bb', 'C', 'Dm', 'Dm', 'Bb', 'C', 'Dm', 'Dm']


Q4 = {}                                            # compás → acorde de su última negra (la cola del riff)


# ══ LAS OTRAS DOS CARAS (el mismo tema: célula, cola, grito, puente, coda; otra atmósfera) ═══════════════════════
# LÚGUBRE (cueva): más lento (144), casi sin carga — voz hueca con eco, bajo de triángulo, batería seca (bombo
# hondo, "chasquidos" de pinza en vez de caja, timbales lejanos) — y las PATAS (how_to_spider.txt): semicorcheas sin
# parar en grupos de 8, pulso al 12,5 % muy corto, sobre la pentatónica menor del acorde + la blue note; en primer
# plano cuando la melodía calla, al fondo cuando canta; un segundo patrón de 6 contra el de 8 desde el estribillo;
# salto de octava cada 4 compases; y la PAUSA al cerrar cada frase (una bajada cromática y media parte de silencio:
# solo queda la melodía — la cola del riff —, y el platillo de la vuelta es la "caída").
# HELADO: el mismo tempo y la misma fuerza, con el MOTIVO NAVIDEÑO de la caja de música de "Winter Fallympics" como
# segunda idea. Va solo donde está SU armonía (Si♭ Si♭ Do Do), que aquí es el giro ♭VI–♭VII del propio riff y
# resuelve en Re menor: la intro (caja de música sola), la primera mitad de los dos estribillos y la primera mitad
# del puente (la batería se vacía: cascabeles y bombo). Se desarrolla: en el estribillo le contesta una frase nueva
# hecha con su salto de octava, y la segunda vez lo canta también la voz y lo remata el grito de guerra. Timbres de
# hielo: voz suave del N163 doblada por la caja de música una octava arriba, campanillas en el tresillo (donde iba
# la marimba), cascabeles, arpegio brillante en semicorcheas.
STYLES = {
    # (normal y helada: 180 con la caja en el 3 = medio tiempo, se sentían a 90 — "demasiado lentas" en el juego, dijo el
    # usuario; la lúgubre así está bien. A 200 y a TIEMPO ENTERO (caja en 2 y 4, bombo doble, redoblitos, platos) "te pasaste un poco": punto medio = el mismo
    # ritmo a tiempo entero, a 172 → "muy lento"; 186)
    'normal': dict(bpm=186, lufs=-10.0, out='crab_tantrum'),
    'gloomy': dict(bpm=144, lufs=-11.0, out='crab_tantrum_gloomy'),
    'icy':    dict(bpm=186, lufs=-10.0, out='crab_tantrum_icy'),
}
MOTIF = [[77, 89, 88, 86], [84, 82, 81, 82], [84, 86, 84, 82], [81, 79, 77, 79]]      # (negras; 4 compases: Si♭ Si♭ Do Do)
MOTIF_PH = [(i + 1, k * 4, m, 4) for i, bar in enumerate(MOTIF) for k, m in enumerate(bar)]
# la respuesta al motivo (nueva): su salto de octava sobre la tónica, y baja por el acorde
DEV = [(5, 0, D5, 4), (5, 4, D6, 4), (5, 8, A5, 4), (5, 12, F5, 4),
       (6, 0, A5, 4), (6, 4, G5, 2), (6, 6, F5, 2), (6, 8, D5, 8),
       (7, 0, Bb4, 4), (7, 4, Bb5, 4), (7, 8, F5, 4), (7, 12, D5, 4),
       (8, 0, E5, 4), (8, 4, G5, 4), (8, 8, C6, 8)]
CH_MOT = ['Bb', 'Bb', 'C', 'C']


def song(style='normal'):
    """→ melodía, acordes por compás [(1ª mitad, 2ª mitad)], etiqueta por compás, compases donde empieza frase"""
    mel, chords, tag, starts = [], [], [], []

    def section(kind, ph, cs):
        base = len(chords)
        starts.append(base + 1)
        for b, st, n, d in ph: mel.append((base + b, st, n, d))
        for c in cs:
            chords.append((ch(c[0]), ch(c[1])) if isinstance(c, list) else (ch(c), ch(c)))
            if isinstance(c, list) and len(c) == 3: Q4[len(chords)] = ch(c[2])      # (tercer acorde: la última negra)
            tag.append(kind)
    Q4.clear()
    bell = []                                      # (helado) el motivo en la caja de música: (compás, semicorchea, nota, dur)
    def motif():
        base = len(chords)
        for b, st, n, d in MOTIF_PH: bell.append((base + b, st, n, d))
    if style == 'icy':
        motif(); section('intro', [], CH_MOT)
    else:
        section('intro', [], ['Dm'] * INTRO)
    section('A', PH_A + A_END, CH_A)
    section('A', PH_A + A_END2, CH_A)
    if style == 'icy':
        late = [x for x in PH_B + B_END2 if x[0] >= 5]
        motif(); section('B', DEV, CH_MOT + ['Dm', 'Dm', 'Bb', 'C'])                    # el motivo (caja sola) y su respuesta
        section('B2', [(b, st, n - 12, d) for b, st, n, d in MOTIF_PH] + late, CH_MOT + ['Dm', 'Dm', 'Bb', 'C'])   # lo canta la voz; remata el grito
        motif(); section('BR', PH_BR, CH_MOT + ['Dm'] * 4)
    else:
        section('B', PH_B + B_END, CH_B)
        section('B2', PH_B + B_END2, CH_B2)
        section('BR', PH_BR, CH_BR)
    section('A', PH_A + A_END, CH_A)
    section('CODA', PH_CODA, CH_CODA)
    return mel, chords, tag, starts, bell


def check(mel, chords, motif_bars=()):
    """Las reglas del usuario: notas largas (≥ 4) del acorde que suena cuando empiezan; todo dentro de la escala"""
    def at(b, st):                                 # (una nota que entra en la última corchea y cruza la barra ANTICIPA el compás siguiente)
        if st >= 14: return chords[b % len(chords)][0]
        if st >= 12 and b in Q4: return Q4[b]
        return chords[b - 1][0 if st < 8 else 1]
    bad = [(b, st) for b, st, n, d in mel if d >= 4 and b not in motif_bars and (n - at(b, st)[0]) % 12 not in at(b, st)[1]]      # (el motivo prestado va por grados: sus notas de paso no cuentan)
    out = [(b, st) for b, st, n, d in mel if n % 12 not in SCALE]
    return bad, out


I_SAW = {'vol': [15, 15, 14, 14, 13, 13], 'sus': 13, 'vib': (14, 0.2, 6)}
I_PUL = {'vol': [11, 10, 9, 8, 8, 7], 'sus': 7, 'duty': [0.125, 0.25]}
I_TRI = {'vol': [15], 'sus': 15}
I_BDEF = {'vol': [12, 9, 6, 4, 3, 2], 'sus': 2, 'duty': 0.5}                 # el pulso que dibuja el bajo
I_MAR = {'vol': [11, 8, 5, 3, 2, 1], 'sus': 0, 'duty': 0.5}                  # la marimba de la costa
I_STAB = {'vol': [13, 11, 8, 5, 3, 2], 'sus': 1, 'duty': 0.25}
I_ECHO = {'vol': [5, 5, 4, 3], 'sus': 2, 'duty': 0.5}
SNARE_N, CRASH = [14, 10, 6, 3, 1], [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
TRES = (0, 6, 12)                                                             # el tresillo 3+3+2 (en corcheas)


WAVES = [wavetable([1.0, 0.45, 0.2, 0.1]),                     # 0 voz suave (helado)
         GN.CWAVES[0],                                         # 1 caja de música
         wavetable([1.0, 0.0, 0.5, 0.0, 0.28, 0.0, 0.12])]     # 2 voz hueca (lúgubre)
I_SMOOTH = {'vol': [12, 14, 15, 14, 13, 13], 'sus': 13, 'vib': (12, 0.2, 5.5), 'duty': 0.0}
I_BELL = dict(GN.I_BELL, duty=1.0)
I_HOLLOW = {'vol': [10, 13, 14, 13, 12, 12], 'sus': 12, 'vib': (8, 0.3, 7.5), 'duty': 2.0}
I_ICE = {'vol': [9, 6, 4, 3, 2, 1], 'sus': 0, 'duty': 0.125}
I_SHIM = {'vol': [6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
LEVELS = {
    'normal': {'lead': 0, 'dbl': -8, 'echo': -12, 'stabs': -9, 'mar': -9, 'bass': 0, 'bdef': -8,
               'kick': 0, 'toms': -2, 'snare': -3, 'hat': -12, 'crash': -10},
    'icy':    {'lead': 0, 'bell': -3, 'echo': -12, 'stabs': -10, 'mar': -9, 'shim': -13, 'bass': 0, 'bdef': -8,
               'kick': 0, 'toms': -3, 'snare': -3, 'hat': -10, 'crash': -10},
    'gloomy': {'lead': 0, 'echo': -7, 'legs': -5, 'legs2': -12, 'bass': -1,
               'kick': -1, 'toms': -6, 'snare': -2, 'hat': -15, 'crash': -9},
}


def build(style='normal'):
    cfg = STYLES[style]
    bpm, lufs = cfg['bpm'], cfg['lufs']
    S16 = 60.0 / bpm / 4
    BAR = 16 * S16
    icy, dark = style == 'icy', style == 'gloomy'
    fast = not dark
    mel, chords, tag, starts, bell = song(style)
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'dbl', 'echo', 'c1', 'c2', 'bass', 'bdef', 'mar', 'bell', 'shim', 'legs', 'legs2')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    # MELODÍA: sierra una octava abajo (cuerpo) + pulso a su altura; en B', el puente y la coda, también la octava
    for b, st, n, d in mel:
        t0, t1 = tv(b, st), tv(b, st) + d * S16 * 0.93
        kind = tag[b - 1]
        if icy:                                                # voz suave + la caja de música una octava arriba
            play(Cn['lead'], t0, t1, n, I_SMOOTH, q=q_n163, release=3)
            play(Cn['bell'], t0, t0 + max(d, 4) * S16, n + 12, I_BELL, q=q_n163, release=6)
        elif dark:                                             # voz hueca, sola
            play(Cn['lead'], t0, t1, n, I_HOLLOW, q=q_n163, release=4)
        else:
            play(Cn['lead'], t0, t1, n - 12, I_SAW, q=q_saw, release=3)
            play(Cn['dbl'], t0, t1, n + (12 if kind in ('B2', 'CODA') else 0), I_PUL, release=2)
        if d >= 3: play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 3) * S16 * 0.8, n, I_ECHO, release=1)

    for b, st, n, d in bell:                                   # (helado) el motivo: caja de música y su octava baja
        play(Cn['bell'], tv(b, st), tv(b, st) + d * S16 * 1.2, n, I_BELL, q=q_n163, release=6)
        play(Cn['shim'], tv(b, st), tv(b, st) + d * S16, n - 12, dict(I_ICE, vol=[8, 7, 6, 5, 4, 3, 2, 1]), release=2)
    sung = {(b, st + k) for b, st, n, d in mel for k in range(d)}
    pause = lambda b, st: dark and st >= 12 and ((b + 1) in starts or b == NB)       # la PAUSA de la araña

    def bass(b, st, ln, note):
        if pause(b, st): return
        t = tv(b, st)
        play(Cn['bass'], t, t + ln * S16, note, I_TRI, q=q_tri, release=0)
        if not dark: play(Cn['bdef'], t, t + min(ln, 2.5) * S16, note + 12, I_BDEF, release=1)

    i6 = 0
    for b in range(1, NB + 1):
        kind = tag[b - 1]
        (r1, q1), (r2, q2) = chords[b - 1]
        lo = lambda r: 38 + (r - 38) % 12                      # (el bajo, de Re1 hacia arriba)
        nxt = chords[b % NB][0][0] if b < NB else chords[INTRO][0][0]
        # ── BAJO ──
        mot = icy and (kind == 'intro' or (kind == 'BR' and b - starts[5] < 4))    # compases del motivo sin la banda
        if mot:
            if kind != 'intro' or b >= 3:
                bass(b, 0, 5.5, lo(r1)); bass(b, 6, 5.5, lo(r1)); bass(b, 12, 3.6, lo(r1))
        elif kind == 'intro':
            if b >= 3:                                         # entra con la célula del riff
                for st, ln, iv in ((0, 5.5, 0), (6, 1.8, 0), (8, 1.8, 5), (10, 3.6, 3), (14, 1.8, 0)): bass(b, st, ln, lo(r1) + iv)
        elif kind == 'BR':                                     # el riff, en el bajo
            for st, ln, iv in ((0, 5.5, 0), (6, 1.8, 0), (8, 1.8, 5), (10, 3.6, 3), (14, 1.8, -2 if b % 2 == 0 else 0)): bass(b, st, ln, lo(r1) + iv)
        else:                                                  # tresillo 6-6-4 y una nota de paso hacia el compás siguiente
            bass(b, 0, 5.5, lo(r1)); bass(b, 6, 1.8 if r2 != r1 else 5.5, lo(r1))
            if r2 != r1: bass(b, 8, 3.6, lo(r2))
            if b in Q4: r2 = Q4[b][0]                          # (la cola: el bajo pasa a ♭VII en la última negra)
            step = lo(r2) + (7 if (lo(r2) + 7 - nxt) % 12 in (0, 5, 7) else 12)
            bass(b, 12, 1.8, lo(r2)); bass(b, 14, 1.8, step if kind != 'CODA' else lo(r2) + 12)
        # ── MARIMBA (la costa): el acorde en el tresillo 3+3+2 de semicorcheas; calla en el puente hasta el 5º compás ──
        if dark:
            # ── LAS PATAS ──
            for st in range(16):
                if pause(b, st): continue
                r, q = (r1, q1) if st < 8 else (Q4[b] if st >= 12 and b in Q4 else (r2, q2))
                alone = kind == 'intro' or (kind == 'BR' and b - starts[5] < 4)
                base_ = 62 + (r - 62) % 12 + (12 if alone or (b - 1) % 4 == 3 else 0)
                note = base_ + GN.LEG8[q][st % 8]
                if ((b + 1) in starts or b == NB) and st >= 8: note = base_ + 12 - (st - 8)     # bajada cromática hacia la pausa
                t = tv(b, st)
                play(Cn['legs'], t, t + S16 * 0.5, note, GN.I_LEG, vs=0.4 if (b, st) in sung else 1.0, release=0)
                if kind in ('B', 'B2', 'CODA'):
                    play(Cn['legs2'], t, t + S16 * 0.5, base_ + GN.LEG6[q][i6 % 6], GN.I_LEG2, q=q_vrc6, release=0)
                    i6 += 1
        elif kind != 'intro' or b >= 3:
            if not (kind == 'BR' and b - starts[5] < 4):
                for half, (r, q) in enumerate(((r1, q1), (r2, q2))):
                    notes = [(84 if icy else 72) + (r - 72) % 12 + iv for iv in q]
                    for k, st in enumerate((0, 3, 6)):
                        if half == 1 and st == 6 and b in Q4: notes = [(84 if icy else 72) + (Q4[b][0] - 72) % 12 + iv for iv in Q4[b][1]]
                        play(Cn['mar'], tv(b, half * 8 + st), tv(b, half * 8 + st) + S16 * 1.5, notes[(k + half) % 3], I_ICE if icy else I_MAR, release=1)
        # ── GOLPES de quinta (potencia): en el tresillo, en A y la coda; a tiempo en el estribillo ──
        if icy and kind in ('B', 'B2', 'CODA') and not mot:          # arpegio brillante en semicorcheas
            for st in range(16):
                r, q = (r1, q1) if st < 8 else (r2, q2)
                if (b, st) not in {(bb, s_) for bb, s_, _, _ in bell}:
                    play(Cn['shim'], tv(b, st), tv(b, st) + S16 * 0.7, 72 + (r - 72) % 12 + (q + (12,))[st % 4], I_SHIM, release=0)
        if kind in ('A', 'CODA', 'B', 'B2') and not dark:
            for st in TRES:
                r, q = (r1, q1) if st < 8 else (Q4[b] if st >= 12 and b in Q4 else chords[b - 1][1])
                root = 50 + (r - 50) % 12
                ln = 2.5
                play(Cn['c1'], tv(b, st), tv(b, st) + ln * S16, root, I_STAB, release=2)
                play(Cn['c2'], tv(b, st), tv(b, st) + ln * S16, root + 7, I_STAB, release=2)
        # ── BATERÍA ──
        last = (b + 1) in starts or b == NB                    # último compás de la frase: redoble
        for st in range(16):
            t = tv(b, st)
            if pause(b, st): continue
            if mot:                                            # (helado) el motivo: cascabeles y, desde el 3er compás, el bombo
                k = b if kind == 'intro' else b - starts[5] + 1
                if st % 2 == 0: NZ['hat'].hit(t, 0, [5, 3, 1])
                if st in TRES and k >= 3: hit(kick, TN.KICK_DEEP, t, 0.9)
                if last and st >= 8: snare(t, 0.4 + (st - 8) * 0.07, [7 + (st - 8), 5, 2])
            elif dark and kind not in ('intro', 'BR'):         # (lúgubre) seca: bombo hondo, chasquido de pinza en el 3, timbal lejano
                if st in TRES: hit(kick, TN.KICK_DEEP, t, 1.0)
                if st == 8: NZ['snare'].hit(t, 3, [10, 5, 2], short=1)
                elif st in (3, 14): hit(tom, W.TOMS[2], t, 0.6)
                elif kind in ('B', 'B2', 'CODA') and st % 4 == 2: NZ['hat'].hit(t, 1, [3, 1])
            elif kind == 'intro' or kind == 'BR':              # TRIBAL: bombo en el tresillo, timbales en ostinato
                k = b if kind == 'intro' else b - starts[5] + 1
                if st in TRES: hit(kick, TN.KICK_DEEP, t, 1.0)
                pat = {2: 0, 3: 1, 8: 2, 10: 0, 11: 1, 14: 2, 15: 2}
                if k % 2 == 0: pat = {2: 0, 3: 0, 4: 1, 8: 2, 9: 2, 10: 1, 11: 0, 14: 2, 15: 1}
                if st in pat: hit(tom, W.TOMS[pat[st]], t, 1.0)
                if kind == 'BR' and st % 2 == 0 and not dark: NZ['hat'].hit(t, 1 if not icy else 0, [4, 2, 1])
                if kind == 'BR' and k >= 5 and not dark and st in (4, 12): snare(t, 0.95)
                if not dark and st % 2 == 1 and st not in pat and (kind == 'BR' or k >= 3): NZ['hat'].hit(t, 1 if not icy else 0, [3, 1])
                if not dark and kind == 'BR' and k >= 5 and st == 10: hit(kick, TN.KICK, t, 0.9)
                if last and st >= 8 and not dark: snare(t, 0.4 + (st - 8) * 0.07, [7 + (st - 8), 5, 2])
            else:                                              # A y coda: tresillo en el bombo, caja en el 3 (medio tiempo), timbales
                if st in TRES or st == 10 or (st == 3 and b % 2 == 0 and kind != 'A'): hit(kick, TN.KICK, t, 1.0 if st in TRES else 0.85)
                if st in (4, 12): snare(t, 1.0)                                      # a tiempo entero: caja en 2 y 4
                elif st in (7, 15) and (kind != 'A' or b % 2 == 0): snare(t, 0.35, [6, 3, 1])      # redoblitos
                elif st in (3, 14) or (kind in ('B', 'B2') and st in (2, 10, 11)):       # (el estribillo: el mismo ritmo, más timbales)
                    hit(tom, W.TOMS[{2: 0, 3: 2, 10: 0, 11: 1, 14: 1}[st]], t, 0.9)
                elif icy: NZ['hat'].hit(t, 0, [5, 3, 1] if st % 2 == 0 else [2, 1])     # cascabeles
                else: NZ['hat'].hit(t, 1, [4, 2, 1] if st % 2 == 0 else [3, 1])        # maraca en semicorcheas
            if last and kind not in ('intro', 'BR') and st >= 12 and not dark:                       # entrada a la frase siguiente
                snare(t, 0.6 + (st - 12) * 0.1, [9 + (st - 12), 5, 2]); hit(tom, W.TOMS[min(2, st - 12)], t, 0.7)
            if st == 0 and (b in starts or (kind in ('B', 'B2', 'CODA') and b % 2 == 1) or (fast and kind == 'A' and (b - 1) % 4 == 0)) and b > 1: NZ['crash'].hit(t, 3, CRASH)

    n = int(NB * BAR * SR)
    n_i = int(INTRO * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k: cut(F.pulse_dac(F.render_pulse(Cn[k])))
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    S = {
        'lead': cut(F.render_wave(Cn['lead'], WAVES) * 0.0075) if icy or dark else cut(F.pulse_dac(F.render_saw(Cn['lead']))),
        'dbl': pulse('dbl'), 'echo': pulse('echo'), 'bell': cut(F.render_wave(Cn['bell'], WAVES) * 0.0075), 'shim': pulse('shim'),
        'legs': pulse('legs'), 'legs2': cut(F.render_pulse(Cn['legs2']) * 0.0075),
        'stabs': pulse('c1') + pulse('c2'), 'mar': pulse('mar'),
        'bass': cut(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)), 'bdef': pulse('bdef'),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + cut(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
        'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12)), 'crash': cut(F.tnd_dac(NZ['crash'].render() / 22638.0 * 12)),
    }
    S = {k: GN.fold(v, n, n_i) for k, v in S.items() if np.abs(v).max() > 0}
    if dark: S['lead'] = GN.delay(S['lead'], 3 * S16, 0.22, 2)             # (un poco de cueva en la voz)
    # (el acompañamiento, +3 dB respecto a la melodía en las versiones normal y helada: en el juego la melodía tapaba
    # el bajo y la batería — ver BACKING en worlds_nes.py —; la lúgubre, que el usuario dio por buena, no se toca)
    LVS = {k: LEVELS[style][k] + (3.0 if not dark and k in ('stabs', 'mar', 'shim', 'bass', 'bdef', 'kick', 'toms', 'snare', 'hat', 'crash') else 0) for k in S}
    g = GN.level(S, LVS, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('mar', 0.5) - sd('echo', 0.6) + sd('stabs', 0.3) + sd('hat', 0.3) + sd('shim', 0.5) + sd('legs', 0.35) - sd('legs2', 0.5)
    y = F.master(np.stack([x + side, x - side], 1), lufs=lufs)
    GN.report(cfg['out'], y, S, g, n)
    bad, out = check(mel, chords, {b for b, st, nn, d in bell} | ({b for b in range(starts[4], starts[4] + 4)} if icy else set()))
    drums = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ('kick', 'toms', 'snare', 'hat', 'crash')) / sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    print(f'  {bpm} BPM, intro {INTRO} + bucle {NB - INTRO} compases ({(NB - INTRO) * BAR:.1f} s); melodía {len(mel)} notas; batería {100 * drums:.0f} % de la energía')
    print(f'  notas largas fuera del acorde: {bad or "ninguna"} · fuera de la escala: {out or "ninguna"}')
    return y, mel, n_i, bpm


if __name__ == '__main__':
    for style in (sys.argv[1:] or ['normal']):
        y, mel, n_i, bpm = build(style)
        if not os.environ.get('REPORT'):
            GN.export(STYLES[style]['out'], y, n_i)
            W.write_mid(F.out(STYLES[style]['out'], 'mid'), mel, bpm)
