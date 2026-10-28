#!/usr/bin/env python3
# EL TEMPLO — tema del jefe de la jungla (el Escarabajo Rinoceronte Gigante, prototipo; isla aún sin integrar). v4.
# Referencia del usuario: "Temple Tumble", la sección 0:45-1:08 — su RIFF, que el usuario corrigió nota a nota con el
# comparador (FlappyMonster_pruebas/musica/escarabajo/comparador.html, 2026-10-28): Do Do Do# Re# Sol# Sol# en
# semicorcheas 0·2·5·8·11·14 (2+3+3+3+3+2), el mismo sobre todos los acordes salvo el de Fa menor (Mib Mib Sol Lab Do
# Do); y la LÍNEA LARGA en octavas. Armonía medida: Reb · Reb · Mib · Mib · Sibm · Sibm · Fam · Fam · Reb · Reb · Mib ·
# Mib · Sibm · Dom · Reb · Mib. Batería medida: bombo 1 · 7 · 9 · 14, congas en 3 y 13, palmas en 7 y 10.
#
# v1 → v2 (el usuario): (1) la canción NO empieza con el riff: va en mitad (y vuelve debajo del clímax); (2) el tema
# del jefe no sonaba "disfrutable" ni armónico con el riff → rehecho sobre los MISMOS acordes del riff (Fam · Reb · Mib
# · Sibm) y comprobado nota a nota contra el riff (sin 2ª menor / 7ª mayor / tritono de una corchea o más); tres
# versiones para elegir (TEMAS); (3) instrumentos nuevos, más de jungla: un soundfont GM (GeneralUser GS, gm.py) —
# marimba y kalimba (el riff), flauta de pan (la línea larga), ocarina (el tema), shakuhachi (el puente), taiko, congas,
# bongós, timbales, agogó, güiro, maracas, cuíca — con el slap bass de la casa y la sierra de Famicom debajo del tema.
#
# Fa menor natural, 170 BPM. Forma: INTRO 8 (una vez: tambores; el bajo entra en el 5º) · TEMA 16 · PUENTE 8 ·
# RIFF 16 (la sección de la referencia) · SELVA 8 (tambores solos, trozos del riff, "la llamada") · SUBIDA 8 ·
# CLÍMAX 16 (el tema con el riff debajo) · VUELTA 4 = 8 + 76 compases.
# v4 (el usuario): ninguna melodía encajó — ni las tres de la v2 ni la v3 (metales al estilo del original, en Fa mayor:
# "horrible") → la v2 SIN melodía: callan la ocarina, la sierra y sus dobles; queda todo lo demás (el riff debajo del
# clímax incluido). MELODIA=1 devuelve las melodías de la v2.
#
#   python tools/music/templo.py   → FlappyMonster_pruebas/musica/templo/templo_v4_sin_melodia (MELODIA=1 [canto|grito|aventura]: la v2)
#   INSTALL=1 …                    → assets/music/bosses/templo_intro.ogg + templo_loop.ogg (+ tools/music/mid/templo.mid: el riff)
#   REPORT=1 → solo números · CAPAS=1 → también cada instrumento por separado. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_saw, q_n163
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W
import slap as SL
import gm as GM

BPM = 170
MELODIA = os.environ.get('MELODIA') == '1'                     # v4 (el usuario): SIN melodía; MELODIA=1 → con la de TEMA
S16 = 60.0 / BPM / 4
BAR = 16 * S16
NAME = 'templo'
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/musica/templo'
NN = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8,
      'A': 9, 'Bb': 10, 'B': 11}
MAJ, MIN = (0, 4, 7), (0, 3, 7)
SCALE = {5, 7, 8, 10, 0, 1, 3}                                   # Fa menor natural


def ch(s):
    return (NN[s[:-1]], MIN) if s.endswith('m') else (NN[s], MAJ)


def note(s):
    return 12 * (int(s[-1]) + 1) + NN[s[:-1]]


def nm(m):
    return ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'][m % 12] + str(m // 12 - 1)


# ══ LA REFERENCIA (corregida por el usuario) ═══════════════════════════════════════════════════════════════════════
RIFF = "0:C5/2 2:C5/3 5:Db5/3 8:Eb5/3 11:Ab4/3 14:Ab4/2"
RIFF_F = "0:Eb5/2 2:Eb5/3 5:G5/3 8:Ab5/3 11:C5/3 14:C5/2"         # (sobre Fa menor)
H_A = ['Db', 'Db', 'Eb', 'Eb', 'Bbm', 'Bbm', 'Fm', 'Fm', 'Db', 'Db', 'Eb', 'Eb', 'Bbm', 'Cm', 'Db', 'Eb']
LINEA = [("0:Ab5/32", "0:F5/32"), ('', ''), ("0:Bb5/32", "0:Bb4/32"), ('', ''), ("0:C6/32", "0:C5/32"), ('', ''),
         ("0:C6/16", "0:Eb5/16"), ("0:G5/16", "0:Bb4/8 8:Bb5/8"), ("0:C6/32", "0:Ab5/32"), ('', ''),
         ("0:G5/16", "0:Bb4/8 8:Bb5/8"), ("0:Bb5/16", "0:Eb5/16"), ("0:C6/16", "0:F5/16"), ("0:G5/16", "0:Eb5/16"),
         ("0:Ab5/16", "0:F5/16"), ("0:Bb5/16", "0:G5/16")]

# ══ EL TEMA (tres versiones) sobre los acordes del riff: i · i · VI · VII · i · i · VI · VII · iv · iv · i · i · VI ·
# VI · VII · VII. Notas largas = del acorde; las de paso entran y salen por grado ═════════════════════════════════
H_T = ['Fm', 'Fm', 'Db', 'Eb', 'Fm', 'Fm', 'Db', 'Eb', 'Bbm', 'Bbm', 'Fm', 'Fm', 'Db', 'Db', 'Eb', 'Eb']
TEMAS = {
    # CANTO: cantable, notas largas; pregunta (sube el acorde en 3+3+2) y respuesta (baja por grados)
    'canto': ["0:C5/3 3:F5/3 6:G5/2 8:Ab5/2 10:C6/4 14:Bb5/2", "0:Ab5/4 4:G5/2 6:F5/2 8:F5/8",
              "0:Ab4/3 3:F5/3 6:Ab5/2 8:Db6/6 14:C6/2", "0:Bb5/6 6:Ab5/2 8:G5/2 10:Eb5/6",
              "0:C5/3 3:F5/3 6:G5/2 8:Ab5/2 10:C6/2 12:F6/4", "0:Eb6/2 2:Db6/2 4:C6/4 8:Ab5/4 12:F5/4",
              "0:F5/3 3:Ab5/3 6:Db6/2 8:F6/6 14:Eb6/2", "0:Eb6/6 6:Db6/2 8:C6/2 10:Bb5/6",
              "0:F6/6 6:Eb6/2 8:Db6/4 12:Bb5/4", "0:F5/2 2:Bb5/3 5:Db6/3 8:F6/8",
              "0:Ab6/4 4:G6/2 6:F6/2 8:C6/8", "0:Ab5/4 4:G5/2 6:F5/2 8:C5/8",
              "0:Ab4/3 3:F5/3 6:Ab5/2 8:Db6/4 12:F6/4", "0:Eb6/2 2:F6/2 4:Ab6/4 8:F6/4 12:Db6/4",
              "0:Eb6/6 6:Db6/2 8:C6/2 10:Bb5/6", "0:G5/4 4:Bb5/4 8:Eb6/8"],
    # GRITO: un canto tribal — notas repetidas en 3+3+2 y caída; pregunta y respuesta cortas
    'grito': ["0:F5/3 3:F5/3 6:G5/2 8:Ab5/2 10:F5/2 12:C5/4", "0:C5/2 2:F5/2 4:C6/4 8:Ab5/8",
              "0:F5/3 3:F5/3 6:Ab5/2 8:Db6/4 12:Ab5/4", "0:G5/2 2:Bb5/2 4:Eb6/4 8:Db6/2 10:C6/2 12:Bb5/4",
              "0:Ab5/3 3:Ab5/3 6:C6/2 8:Bb5/2 10:Ab5/2 12:F5/4", "0:F5/2 2:Ab5/2 4:C6/4 8:Ab5/8",
              "0:Ab5/3 3:Ab5/3 6:Db6/2 8:F6/4 12:Db6/4", "0:Eb6/6 6:Db6/2 8:C6/2 10:Bb5/6",
              "0:Bb5/3 3:Bb5/3 6:Db6/2 8:C6/2 10:Bb5/2 12:F5/4", "0:F5/2 2:Bb5/2 4:Db6/4 8:F6/8",
              "0:F6/3 3:F6/3 6:Eb6/2 8:Db6/2 10:C6/2 12:Ab5/4", "0:F5/4 4:C6/4 8:Ab5/8",
              "0:F6/3 3:F6/3 6:Ab6/2 8:F6/2 10:Eb6/2 12:Db6/4", "0:F5/2 2:Ab5/2 4:Db6/4 8:F6/8",
              "0:Eb6/3 3:Eb6/3 6:Eb6/2 8:G6/2 10:F6/2 12:Eb6/4", "0:G5/4 4:Bb5/4 8:Eb6/8"],
    # AVENTURA: corre en corcheas desde el contratiempo, saltos que rebotan, el pentatónico del riff
    'aventura': ["2:C5/2 4:F5/2 6:G5/2 8:Ab5/2 10:F5/2 12:C6/4", "0:Bb5/2 2:Ab5/2 4:F5/4 8:Ab5/2 10:G5/2 12:F5/4",
                 "2:F5/2 4:Ab5/2 6:Db6/4 10:Ab5/2 12:F5/4", "0:Eb5/2 2:G5/2 4:Bb5/4 8:G5/2 10:Ab5/2 12:Bb5/4",
                 "2:C6/2 4:F6/2 6:Eb6/2 8:Db6/2 10:C6/2 12:Ab5/4", "0:G5/2 2:Ab5/2 4:C6/4 8:F6/8",
                 "2:F6/2 4:Eb6/2 6:Db6/4 10:Eb6/2 12:F6/4", "0:Eb6/6 6:Db6/2 8:C6/2 10:Bb5/6",
                 "2:F5/2 4:Bb5/2 6:Db6/4 10:C6/2 12:Bb5/4", "0:Ab5/2 2:Bb5/2 4:Db6/4 8:F6/8",
                 "2:Ab6/2 4:G6/2 6:F6/4 10:C6/2 12:Ab5/4", "0:G5/2 2:Ab5/2 4:C6/4 8:F5/8",
                 "2:F5/2 4:Ab5/2 6:Db6/4 10:F6/2 12:Ab6/4", "0:G6/2 2:F6/2 4:Db6/4 8:Ab5/8",
                 "2:G5/2 4:Bb5/2 6:Eb6/4 10:F6/2 12:Eb6/4", "0:F6/2 2:Eb6/2 4:Bb5/4 8:G5/2 10:Bb5/6"],
}
# PUENTE: otro color (shakuhachi, medio tiempo), notas largas; acaba en Dom → Reb (empieza el riff)
H_P = ['Bbm', 'Bbm', 'Fm', 'Fm', 'Db', 'Db', 'Cm', 'Cm']
M_P = ["0:F5/8 8:Db6/6 14:C6/2", "0:Bb5/8 8:F5/8", "0:Ab5/8 8:C6/6 14:Bb5/2", "0:Ab5/8 8:F5/8",
       "0:F5/8 8:Ab5/8", "0:Db6/8 8:F6/8", "0:Eb6/8 8:G6/8", "0:G6/4 4:Eb6/4 8:C6/8"]
LLAMADA = "0:C5/4 4:F5/4 8:Ab5/4 12:C6/4"                          # la llamada (5ª–1ª–3ª–5ª) sobre Fa menor

# ══ EL BAJO (el slap): 'st:NOTA/dur' + '!' = pop · 'x' = fantasma ═════════════════════════════════════════════════
LOW = {'Db': 'Db2', 'Eb': 'Eb2', 'Bbm': 'Bb1', 'Fm': 'F2', 'Cm': 'C2'}


def BL(t):
    out = []
    for tok in t.split():
        st, rest = tok.split(':')
        vel = 122 if rest.endswith('!') else (48 if rest.endswith('x') else 98)
        n, d = rest.rstrip('!x').split('/')
        out.append((int(st), note(n), int(d), vel))
    return out


def bass_ref(c, second):
    """La de la referencia: corcheas en la raíz; el 2º compás del acorde, con golpes de octava"""
    r = note(LOW[c]); o = nm(r + 12); R = nm(r)
    if not second:
        return BL(' '.join(f'{st}:{R}/2' for st in range(0, 16, 2)) + f' 7:{R}/1x 15:{R}/1x')
    return BL(f'0:{R}/2 2:{o}/1! 3:{R}/1x 4:{R}/2 6:{o}/1! 7:{R}/1x 8:{R}/2 10:{R}/2 12:{o}/1! 13:{R}/1x 14:{R}/2')


def bass_funk(c, nxt, hot=False):
    """El tema: pulgar en la raíz, pops a la octava, la 5ª; si cambia el acorde, se acerca a la raíz siguiente"""
    r = note(LOW[c]); R, o, f = nm(r), nm(r + 12), nm(r + 7)
    t = f'0:{R}/2 2:{o}/1! 3:{R}/1x 4:{f}/2 6:{R}/1 7:{R}/1x 8:{R}/2 10:{o}/1! 11:{R}/1x 12:{f}/2 14:{o}/1! 15:{R}/1x'
    if hot:
        t = f'0:{R}/2 2:{o}/1! 3:{R}/1x 4:{f}/1 5:{o}/1! 6:{R}/1 7:{R}/1x 8:{R}/2 10:{o}/1! 11:{R}/1x 12:{f}/1 13:{o}/1! 14:{f}/1 15:{R}/1x'
    if nxt and nxt != c:
        n2 = note(LOW[nxt])
        if n2 < r - 6: n2 += 12
        if n2 > r + 6: n2 -= 12
        ap = nm(n2 - 1 if n2 > r else n2 + 1)                            # (aproximación cromática, una semicorchea)
        t = f'0:{R}/2 2:{o}/1! 3:{R}/1x 4:{f}/2 6:{o}/1! 7:{R}/1x 8:{R}/2 10:{f}/1 11:{o}/1! 12:{R}/2 14:{f}/1 15:{ap}/1'
    return BL(t)


def bass_half(c):
    r = note(LOW[c]); R, o, f = nm(r), nm(r + 12), nm(r + 7)
    return BL(f'0:{R}/6 6:{o}/2! 8:{f}/4 12:{R}/2 14:{o}/1! 15:{R}/1x')


BASS_SELVA = ["0:F2/3 3:F2/1x 4:F2/1x 6:F3/1! 8:F2/2 10:C3/1 11:F2/1x 12:F2/2 14:F3/1! 15:F2/1x",
              "0:F2/3 3:F2/1x 6:F3/1! 7:F2/1x 8:C3/2 10:F3/1! 11:F2/1x 12:Eb3/1 13:F3/1! 14:C3/2"]

SECTIONS = [   # (nombre, armonía, papel)
    ('I', ['Fm'] * 6 + ['Db', 'Eb'], 'intro'),
    ('T', H_T, 'tema'),
    ('P', H_P, 'puente'),
    ('A', H_A, 'riff'),
    ('K', ['Fm'] * 8, 'selva'),
    ('S', ['Db', 'Db', 'Eb', 'Eb', 'Bbm', 'Bbm', 'Cm', 'Cm'], 'build'),
    ('C', H_T, 'climax'),
    ('O', ['Fm', 'Fm', 'Db', 'Eb'], 'out'),
]
INTRO = 8


def song(tema):
    chords, role, sec, starts = [], [], [], {}
    riff, linea, mel, pte, bass, call = [], [], [], [], [], []
    M = TEMAS[tema]
    allh = [c for _, h, _ in SECTIONS for c in h]
    for name, harm, rl in SECTIONS:
        base = len(chords)
        starts[name] = base + 1
        nb = len(harm)
        chords += [ch(c) for c in harm]
        role += [rl] * nb; sec += [name] * nb
        for i, c in enumerate(harm):
            b = base + i + 1
            nxt = allh[b] if b < len(allh) else allh[INTRO]               # (el acorde siguiente; el bucle vuelve al TEMA)
            if rl in ('riff', 'build', 'climax'):
                riff += W.P(b, RIFF_F if c == 'Fm' else RIFF)
            elif rl == 'selva':
                if i in (0, 1, 4, 5): riff += [x for x in W.P(b, RIFF_F) if x[1] < 8]
                elif i >= 6: riff += W.P(b, RIFF_F)
            if rl == 'riff' and LINEA[i][0]:
                linea += [x + ('hi',) for x in W.P(b, LINEA[i][0])] + [x + ('lo',) for x in W.P(b, LINEA[i][1])]
            if rl in ('tema', 'climax'): mel += W.P(b, M[i])
            if rl == 'puente': pte += W.P(b, M_P[i])
            if rl == 'selva' and i == 2: call += W.P(b, LLAMADA)
            if rl == 'riff': bl = bass_ref(c, i % 2 == 1 and harm[i - 1] == c)
            elif rl == 'build': bl = bass_ref(c, i % 2 == 1)
            elif rl == 'intro': bl = [] if i < 4 else bass_funk(c, nxt)
            elif rl == 'selva': bl = BL(BASS_SELVA[i % 2]) if i >= 2 else []
            elif rl == 'puente': bl = bass_half(c)
            else: bl = bass_funk(c, nxt, hot=rl == 'climax')
            bass += [(b,) + x for x in bl]
    return dict(chords=chords, role=role, sec=sec, starts=starts, riff=riff, linea=linea, mel=sorted(mel), pte=pte,
                bass=bass, call=call)


def third_up(n):
    pcs = [p for p in range(n + 1, n + 6) if p % 12 in SCALE]
    return pcs[1]


def check(mel, chords):
    """Notas largas fuera del acorde y notas fuera del acorde que no entran y salen por grado (regla 2 de la guía)"""
    tones = lambda b: {(chords[b - 1][0] + i) % 12 for i in chords[b - 1][1]}
    T = lambda m: (m[0] - 1) * 16 + m[1]
    long_bad = [(b, st) for b, st, n, d in mel if d >= 3 and n % 12 not in tones(b)]
    loose = []
    for i, (b, st, n, d) in enumerate(mel):
        if n % 12 in tones(b): continue
        p = mel[i - 1] if i and T(mel[i - 1]) + mel[i - 1][3] >= T(mel[i]) - 2 else None
        x = mel[i + 1] if i + 1 < len(mel) and T(mel[i]) + d >= T(mel[i + 1]) - 2 else None
        if d >= 3 or not p or abs(n - p[2]) > 2 or not x or abs(x[2] - n) > 2: loose.append((b, st))
    out = [(b, st) for b, st, n, d in mel if n % 12 not in SCALE]
    return long_bad, loose, out


def clashes(a, b_):
    """Choques entre dos voces: 2ª menor, 7ª mayor o tritono que duran una corchea (2 semicorcheas) o más"""
    out = []
    for b, st, n, d in a:
        s0 = (b - 1) * 16 + st
        for bb, st2, n2, d2 in b_:
            s1 = (bb - 1) * 16 + st2
            ov = min(s0 + d, s1 + d2) - max(s0, s1)
            if ov >= 2 and (n - n2) % 12 in (1, 6, 11): out.append((b, st, nm(n), nm(n2)))
    return out


# ── INSTRUMENTOS ─────────────────────────────────────────────────────────────────────────────────────────────────
WAVES = [wavetable([1.0, 0.3, 0.1])]                                         # 0 colchón
I_SAWL = {'vol': [13, 12, 12, 11, 11, 10], 'sus': 10, 'vib': (14, 0.2, 6)}
I_UP = {'vol': [7, 6, 6, 5, 5, 4], 'sus': 4, 'duty': 0.25}
I_HARM = {'vol': [9, 8, 8, 7, 7, 6], 'sus': 6, 'duty': 0.25}
I_PAD = {'vol': [2, 3, 4, 5, 5, 5], 'sus': 5, 'vib': (24, 0.12, 4.5), 'duty': 0}
# GM: programas y batería (kit estándar, canal 10)
P_MARIMBA, P_KALIMBA, P_PANFLUTE, P_OCARINA, P_SHAKU, P_TAIKO = 12, 108, 75, 79, 77, 116
KICK, RIM, SNARE, CLAP, FTL, FTH, CHH, OHH, CRASH, VSLAP = 36, 37, 38, 39, 41, 43, 42, 46, 49, 58
BONGO_H, BONGO_L, CONGA_MH, CONGA_OH, CONGA_L, TIMB_H, TIMB_L = 60, 61, 62, 63, 64, 65, 66
AGOGO_H, AGOGO_L, CABASA, MARACAS, GUIRO_S, GUIRO_L, CLAVES, CUICA_M, CUICA_O = 67, 68, 69, 70, 73, 74, 75, 78, 79
TRES = (0, 6, 12)
# niveles (dB, RMS mientras suena) respecto al bajo
LV = {'bass': 0, 'riff': 1, 'kal': -10, 'flute': -2, 'tema': 1, 'saw': -5, 'up': -9, 'harm': -6, 'pte': 0, 'call': 0,
      'pad': -13, 'kick': -1, 'dpcm': -6, 'snare': -4, 'congas': -6, 'timb': -7, 'bells': -12, 'shaker': -15,
      'guiro': -15, 'cuica': -13, 'hats': -16, 'crash': -9, 'taiko': -3, 'toms': -6, 'nrise': -13}
LUFS = -10.0
PROT = {'I': ['taiko', 'congas'], 'T': ['tema', 'saw'], 'P': ['pte'], 'A': ['riff'], 'K': ['taiko', 'congas', 'toms'],
        'S': ['riff'], 'C': ['tema', 'saw', 'up', 'harm'], 'O': ['taiko', 'congas']}      # (lo que manda en cada sección)
DR = ('kick', 'dpcm', 'snare', 'congas', 'timb', 'bells', 'shaker', 'guiro', 'cuica', 'hats', 'crash', 'taiko', 'toms', 'nrise')


def build(tema):
    sg = song(tema)
    chords, role, sec, starts = sg['chords'], sg['role'], sg['sec'], sg['starts']
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('saw', 'up', 'harm', 'pad1', 'pad2')}
    NZ = {k: Noise(NF) for k in ('nrise',)}
    NS = int(NF * F.FRAME_S) + SR
    dk = np.zeros(NS)
    G = {k: GM.Rec(p) for k, p in (('riff', P_MARIMBA), ('riff2', P_KALIMBA), ('kal', P_KALIMBA), ('flute', P_PANFLUTE),
                                   ('tema', P_OCARINA), ('pte', P_SHAKU), ('call', P_OCARINA), ('taiko', P_TAIKO))}
    D = {k: GM.Rec(drums=True) for k in ('kick', 'snare', 'congas', 'timb', 'bells', 'shaker', 'guiro', 'cuica', 'hats', 'crash', 'toms')}
    tv = lambda b, st: (b - 1) * BAR + st * S16
    rl = lambda b: role[b - 1]
    pos = lambda b: b - starts[sec[b - 1]] + 1
    LEN = {name: len(h) for name, h, _ in SECTIONS}

    def dr(k, b, st, n, vel, dur=1):
        D[k].add(tv(b, st), tv(b, st) + dur * S16, n, vel)

    def taiko(b, st, n=41, vel=100):
        G['taiko'].add(tv(b, st), tv(b, st) + 4 * S16, n, vel)

    # ── EL RIFF: marimba + kalimba (en el clímax, una octava abajo y sin kalimba: va debajo del tema) ──
    for b, st, n, d in sg['riff']:
        r_, k = rl(b), pos(b)
        v = {'riff': 100, 'selva': 92, 'build': 80 + 3 * k, 'climax': 84}[r_]
        t0, t1 = tv(b, st), tv(b, st) + d * S16 * 0.95
        G['riff'].add(t0, t1, n - (12 if r_ == 'climax' else 0), v)
        if r_ != 'climax': G['riff2'].add(t0, t1, n, int(v * 0.8))

    # ── LA LÍNEA LARGA (flauta de pan, en octavas) y LA LLAMADA (ocarina) ──
    for b, st, n, d, v in sg['linea']:
        G['flute'].add(tv(b, st), tv(b, st) + d * S16 - 0.02, n, 88 if v == 'hi' else 70)
    for b, st, n, d in sg['call']:
        G['call'].add(tv(b, st), tv(b, st) + d * S16 * 0.95, n, 100)

    riff_near = lambda b: [x for x in sg['riff'] if abs(x[0] - b) <= 1]
    # ── EL TEMA: ocarina + la sierra una octava abajo; en el clímax, octava arriba y terceras (pulsos) ──
    for b, st, n, d in (sg['mel'] if MELODIA else []):
        r_, k = rl(b), pos(b)
        t0, t1 = tv(b, st), tv(b, st) + d * S16 * 0.93
        up8 = r_ == 'climax' and k > 8 and n + 12 <= 93                     # (la 2ª mitad del clímax, arriba)
        G['tema'].add(t0, t1, n + (12 if up8 else 0), 108 if r_ == 'climax' else 100)
        play(Cn['saw'], t0, t1, n - 12, I_SAWL, q=q_saw, release=3)
        if r_ == 'climax' and not up8 and n + 12 <= 96: play(Cn['up'], t0, t1, n + 12, I_UP, release=2)
        if r_ == 'climax' and k <= 8:
            h = third_up(n); r, q = chords[b - 1]
            if (d < 3 or (h - r) % 12 in q) and not clashes([(b, st, h, d)], riff_near(b)):   # (la tercera, si no roza el riff)
                play(Cn['harm'], t0, t1, h, I_HARM, release=2)
    for b, st, n, d in sg['pte']:
        G['pte'].add(tv(b, st), tv(b, st) + d * S16 * 0.96, n, 96)

    # ── ACOMPAÑAMIENTO: kalimba en arpegio sincopado (notas del acorde); colchón grave ──
    ARP = ((0, 0), (2, 2), (3, 1), (6, 2), (8, 0), (10, 2), (11, 1), (14, 3))      # (semicorchea, grado: 0 raíz 1 3ª 2 5ª 3 octava)
    lead = (sg['mel'] if MELODIA else []) + sg['pte']
    def rub(b, st, n, d=2):                                                  # ¿choca con la melodía que suena? (entonces calla)
        s0 = (b - 1) * 16 + st
        return any(min(s0 + d, (bb - 1) * 16 + s2 + d2) - max(s0, (bb - 1) * 16 + s2) >= 1 and (n - n2) % 12 in (1, 6, 11)
                   for bb, s2, n2, d2 in lead if abs(bb - b) <= 1)
    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        r, q = chords[b - 1]
        if r_ in ('tema', 'climax', 'puente') or (r_ == 'intro' and k >= 5) or r_ == 'out':
            base = 72 + (r - 72) % 12 - (12 if r_ == 'puente' else 0)
            for st, gdeg in ARP:
                if r_ == 'puente' and st % 4: continue
                kn = base + (q + (12,))[gdeg]
                if not rub(b, st, kn): G['kal'].add(tv(b, st), tv(b, st) + 2 * S16, kn, 70 if st % 4 else 84)
        if r_ in ('tema', 'climax', 'build', 'puente'):
            base = 53 + (r - 53) % 12
            for j, iv in enumerate(q[1:]):
                play(Cn[('pad1', 'pad2')[j]], tv(b, 0), tv(b, 0) + BAR * 0.97, base + iv, I_PAD, q=q_n163, release=6)

    # ── TAMBORES (GM; el bombo, reforzado con el DPCM de la casa) ──
    def kick(b, st, v=110):
        dr('kick', b, st, KICK, v)
        i = int(tv(b, st) * SR); m = min(len(TN.KICK_DEEP), NS - i); dk[i:i + m] += TN.KICK_DEEP[:m] * v / 127

    for b in range(1, NB + 1):
        r_, k = rl(b), pos(b)
        last = k == LEN[sec[b - 1]]
        for st in range(16):
            mar = 70 if st % 4 == 0 else (50 if st % 2 == 0 else 38)       # maracas en semicorcheas
            if r_ == 'intro':
                if k <= 4:                                                   # los tambores llaman
                    if (k % 2 == 1 and st in (0, 6)) or (k % 2 == 0 and st in TRES): taiko(b, st, 41, 96 + 6 * k)
                    if st in (10, 13) or (k >= 2 and st in (3, 14)): dr('congas', b, st, CONGA_OH if st % 2 else CONGA_L, 80 + 6 * k)
                    if k >= 3 and st in (8, 9, 11): dr('congas', b, st, BONGO_H if st != 9 else BONGO_L, 70)
                    if k >= 2: dr('shaker', b, st, MARACAS, mar)
                    if k == 2 and st == 8: dr('cuica', b, st, CUICA_O, 80, 3)
                    if k == 4 and st >= 12: dr('timb', b, st, TIMB_H if st < 14 else TIMB_L, 90 + 8 * (st - 12))
                    continue
                if st in (0, 6, 8, 13): kick(b, st, 100)
                if st in (2, 12): dr('congas', b, st, CONGA_OH if st == 2 else CONGA_L, 92)
                if st in (6, 9): dr('snare', b, st, CLAP, 72)
                dr('shaker', b, st, MARACAS, mar)
                if (st in (0, 3, 6, 10, 12) and k % 2 == 1) or (st in (2, 8) and k % 2 == 0):
                    dr('bells', b, st, AGOGO_H if st in (0, 6, 2) else AGOGO_L, 66)
                if k == 5 and st == 0: dr('crash', b, st, CRASH, 70, 8)
                if k == 8 and st >= 12: dr('timb', b, st, TIMB_H if st < 14 else TIMB_L, 96)
                continue
            if r_ == 'selva':                                                # los tambores solos
                if st in TRES or (k % 2 == 0 and st == 10): taiko(b, st, 41 if st != 10 else 45, 118 if st == 0 else 100)
                if k % 2 == 1 and st in (2, 3, 5, 9, 10, 13, 14): dr('congas', b, st, (CONGA_OH, CONGA_MH, CONGA_L)[st % 3], 96)
                if k % 2 == 0 and st in (1, 2, 4, 7): dr('toms', b, st, (FTH, FTH, FTL, FTL)[(1, 2, 4, 7).index(st)], 100)
                if k >= 3: dr('shaker', b, st, MARACAS, mar)
                if k >= 3 and st in (4, 12): dr('guiro', b, st, GUIRO_L, 70, 3)
                if k >= 5 and st in (0, 8): kick(b, st, 104)
                if k >= 5 and st in (6, 9): dr('snare', b, st, CLAP, 80)
                if k in (2, 6) and st == 12: dr('cuica', b, st, CUICA_O, 84, 3)
                if k == 4 and st == 12: dr('cuica', b, st, VSLAP, 90, 4)
                if last and st >= 8: dr('timb', b, st, TIMB_H if (st - 8) % 3 < 2 else TIMB_L, 80 + 4 * (st - 8))
                continue
            if r_ == 'puente':                                               # medio tiempo, ligero
                if st == 0: kick(b, st, 96)
                if st == 8: taiko(b, st, 43, 90)
                if st in (2, 12) or (st == 14 and k % 2 == 0): dr('congas', b, st, CONGA_OH if st == 2 else CONGA_L, 76)
                if st % 2 == 0: dr('shaker', b, st, CABASA, 58 if st % 4 else 72)
                if st in (6, 14): dr('snare', b, st, RIM, 60)
                if last and st >= 12: dr('timb', b, st, TIMB_H if st < 14 else TIMB_L, 92)
                continue
            if r_ == 'build':                                                # la subida
                if st % 4 == 0: kick(b, st, 108)
                step = 4 if k <= 3 else (2 if k <= 6 else 1)
                if st % step == 0: dr('snare', b, st, SNARE, int(48 + 7 * k + st))
                if st % 2 == 0: dr('timb', b, st, TIMB_H if st % 4 else TIMB_L, 50 + 5 * k)
                dr('shaker', b, st, MARACAS, mar)
                if k == 8 and st == 12: dr('crash', b, st, CRASH, 80, 4)
                continue
            if r_ == 'out':                                                  # la vuelta: se vacía hacia el tema
                if st in TRES: taiko(b, st, 41, 100)
                if st in (0, 8) and k <= 2: kick(b, st, 96)
                if st in (2, 12): dr('congas', b, st, CONGA_OH if st == 2 else CONGA_L, 88)
                dr('shaker', b, st, MARACAS, mar)
                if k == 4 and st >= 10: dr('timb', b, st, TIMB_H if st < 13 else TIMB_L, 84 + 5 * (st - 10))
                continue
            # tema · riff · clímax: el ritmo de la referencia
            big = r_ == 'climax'
            drive = r_ in ('tema', 'climax')
            if st in (0, 6, 8, 13) or (big and st == 10 and k % 2 == 0): kick(b, st, 112 if st in (0, 8) else 96)
            if st in (2, 12): dr('congas', b, st, CONGA_OH if st == 2 else CONGA_L, 100)
            elif st in (9, 15): dr('congas', b, st, CONGA_MH, 70)
            if r_ == 'riff' and st in (5, 11): dr('congas', b, st, BONGO_H, 60)
            if drive and st in (4, 12): dr('snare', b, st, SNARE, 108)
            if st in (6, 9) and not drive: dr('snare', b, st, CLAP, 92)
            elif st == 9 and drive: dr('snare', b, st, CLAP, 70)
            dr('shaker', b, st, MARACAS, mar)
            if drive and st % 4 == 2: dr('hats', b, st, OHH, 60, 2)
            if r_ == 'riff' and st in (4, 12): dr('guiro', b, st, GUIRO_L, 74, 3)
            if drive and ((st in (0, 3, 6) and b % 2 == 1) or (st in (4, 8) and b % 2 == 0)): dr('bells', b, st, CLAVES, 76)
            if r_ == 'riff' and ((st in (0, 3, 6, 10, 12) and b % 2 == 1) or (st in (2, 8) and b % 2 == 0)):
                dr('bells', b, st, AGOGO_H if st in (0, 6, 2) else AGOGO_L, 64)
            if (big or k % 4 == 1) and st == 0: taiko(b, st, 41, 110 if big else 96)
            if big and st in (3, 14) and b % 2 == 0: dr('timb', b, st, TIMB_H if st == 3 else TIMB_L, 90)
            if r_ == 'riff' and k in (4, 12) and st == 14: dr('cuica', b, st, CUICA_O, 70, 2)
            if last and st >= 12:                                            # redoble hacia la siguiente
                dr('timb', b, st, TIMB_H if st < 14 else TIMB_L, 100)
                if st >= 14: dr('snare', b, st, SNARE, 80 + 15 * (st - 14))
            if st == 0 and (k == 1 or (big and k % 2 == 1) or k == 9):
                dr('crash', b, st, CRASH, 96 if (k == 1 and r_ != 'riff') or big else 70, 8)
        if r_ == 'build' and k == 7:
            nf = int(2 * BAR * F.FPS)
            NZ['nrise'].hit(tv(b, 0), [int(12 - 9 * i / nf) for i in range(nf)], [int(1 + 9 * i / nf) for i in range(nf)])

    # ── EL BAJO ──
    slap = SL.Rec()
    for b, st, n, d, v in sg['bass']:
        slap.add(tv(b, st), tv(b, st) + d * S16 * 0.95, n, v)

    # ── STEMS ──
    n = int(NB * BAR * SR)
    at = int(INTRO * BAR * SR)
    L = n + 3 * SR
    cut = lambda x: x[:L] - np.mean(x[:n])
    pulse = lambda k: cut(F.pulse_dac(F.render_pulse(Cn[k])))
    wave = lambda k: cut(F.render_wave(Cn[k], WAVES) * 0.0075)
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    S = {k: GM.cached(G[k], L) for k in ('riff', 'kal', 'flute', 'tema', 'pte', 'call', 'taiko')}
    S['riff'] = S['riff'] + GM.cached(G['riff2'], L) * 0.8
    S.update({k: GM.cached(D[k], L) for k in D})
    S.update({'saw': cut(F.pulse_dac(F.render_saw(Cn['saw']))), 'up': pulse('up'), 'harm': pulse('harm'),
              'pad': wave('pad1') + wave('pad2'), 'bass': GM.cached(slap, L),
              'dpcm': cut(F.tnd_dac((dk + 64) / 22638.0) - base),
              'nrise': cut(F.tnd_dac(NZ['nrise'].render() / 22638.0 * 12))})
    from scipy.signal import butter, sosfilt
    hp = butter(2, 30, btype='high', fs=SR, output='sos')               # (sin la continua de los DAC: niveles reales)
    S = {k: sosfilt(hp, GN.fold(x, n, at)) for k, x in S.items() if np.abs(x).max() > 0}
    g = GN.level(S, {k: LV.get(k, -12) for k in S}, 'bass')
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('riff', 0.12) - sd('flute', 0.25) + sd('kal', 0.45) - sd('pad', 0.25) + sd('bells', 0.45) - sd('shaker', 0.4) \
        + sd('congas', 0.25) - sd('timb', 0.2) + sd('guiro', 0.35) - sd('cuica', 0.4) + sd('hats', 0.3) + sd('up', 0.3) \
        - sd('harm', 0.3) - sd('call', 0.2)
    y = F.master(np.stack([x + side, x - side], 1), lufs=LUFS)
    report(tema, sg, S, g, y, n)
    return y, at, S, g, sg


def report(tema, sg, S, g, y, n):
    print(f'── {tema}')
    GN.report(NAME + '_' + tema, y, S, g, n)
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    NB = len(sg['chords'])
    print(f'  {BPM} BPM, {NB} compases ({NB * BAR:.1f} s: intro {INTRO * BAR:.1f} + bucle {(NB - INTRO) * BAR:.1f}); '
          f'tambores {grp(DR):.0f} %, bajo {grp(("bass",)):.0f} %, riff {grp(("riff",)):.0f} %, tema {grp(("tema", "saw", "up", "harm")):.0f} %, '
          f'flautas {grp(("flute", "pte", "call")):.0f} %, acompañamiento {grp(("kal", "pad")):.0f} %')
    print('  secciones: ' + ' · '.join(f'{nm_} {(sg["starts"][nm_] - 1) * BAR // 60:.0f}:{(sg["starts"][nm_] - 1) * BAR % 60:04.1f}' for nm_, *_ in SECTIONS))
    mel = sg['mel']
    lb, lo, out = check(mel, sg['chords'])
    lb2, lo2, out2 = check(sg['pte'], sg['chords'])
    cl = clashes([m for m in mel if sg['role'][m[0] - 1] == 'climax'], sg['riff'])
    print(f'  tema: {len(mel)} notas, largas fuera del acorde {lb or "ninguna"}, sueltas {lo or "ninguna"}, fuera de la escala {out or "ninguna"}, '
          f'a contratiempo {100 * np.mean([m[1] % 4 != 0 for m in mel]):.0f} % · puente: {lb2 + lo2 + out2 or "bien"}')
    print(f'  tema contra el riff (clímax): choques de 2ª menor / 7ª mayor / tritono de una corchea o más: {cl or "ninguno"}')
    bad = [(b, st, nm(nn)) for b, st, nn, d, v in sg['bass'] if d >= 2 and (nn - sg['chords'][b - 1][0]) % 12 not in (0, 7)]
    print(f'  bajo: {len(sg["bass"])} notas; de 2+ semicorcheas que no son raíz ni 5ª: {bad or "ninguna"}')
    span = {nm_: ((sg['starts'][nm_] - 1) * BAR, (sg['starts'][nm_] - 1 + len(h)) * BAR) for nm_, h, _ in SECTIONS}
    def db(ks, a, b):
        z = sum(S[k][int(a * SR):int(b * SR)] * g[k] for k in ks if k in S)
        return 10 * np.log10(np.mean(np.asarray(z) ** 2) + 1e-12)
    print('  por sección (dB): ' + ' | '.join(
        f'{nm_}: total {db(list(S), *span[nm_]):.0f} protagonista {db(PROT[nm_], *span[nm_]):.0f} '
        f'bajo {db(["bass"], *span[nm_]):.0f} tambores {db(DR, *span[nm_]):.0f}' for nm_, *_ in SECTIONS))


def preview(tema, y, at):
    os.makedirs(PREVIEW, exist_ok=True)
    def enc(x, name):
        wav = os.path.join(PREVIEW, name + '.wav'); ogg = wav[:-4] + '.ogg'
        F.write_wav(wav, x)
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"'); os.remove(wav)
    loop = y[at:]
    tag = f'v2_{tema}' if MELODIA else 'v4_sin_melodia'
    enc(np.concatenate([y, loop]), f'{NAME}_{tag}')
    k = int(8 * BAR * SR)
    enc(np.concatenate([loop[-k:], loop[:k]]), f'{NAME}_{tag}_costura')


def capas(S, g, tema):
    cap = os.path.join(PREVIEW, f'capas_{tema}'); os.makedirs(cap, exist_ok=True)
    peak = max(np.abs(sum(S[k] * g[k] for k in S)).max(), 1e-9)
    for k_ in S:
        wav = os.path.join(cap, k_ + '.wav'); ogg = wav[:-4] + '.ogg'
        F.write_wav(wav, np.repeat(S[k_] * g[k_] / peak * 0.8, 2))
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 4 "{ogg}"'); os.remove(wav)


if __name__ == '__main__':
    which = [a for a in sys.argv[1:] if a in TEMAS] or (list(TEMAS) if MELODIA else ['canto'])
    for tema in which:
        y, at, S, g, sg = build(tema)
        if not os.environ.get('REPORT'):
            preview(tema, y, at)
            if os.environ.get('CAPAS'): capas(S, g, tema)
            if os.environ.get('INSTALL') and not MELODIA:            # (la v4, sin melodía: la aprobada, 2026-10-28)
                GN.export(NAME, y, at)
                W.write_mid(F.out(NAME, 'mid'), sorted(sg['riff']), BPM)
    if not os.environ.get('REPORT'): print(f'  previas en {PREVIEW}')
