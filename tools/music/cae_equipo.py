#!/usr/bin/env python3
# tools/music/cae_equipo.py — "Cae por el equipo": tema ORIGINAL construido sobre el esqueleto de "Fall for the Team"
# (Fall Guys). Mismo tempo (185), misma tonalidad (Si♭ mayor), misma forma compás a compás (148 compases, ~192 s) y
# los mismos momentos; melodías, bajo, arpegios, batería y armonía de detalle son PROPIOS.
#
# MUESTRAS LITERALES (petición del usuario: "cortar y usar ese mismo sonido aislado"):
#   golpes_a / golpes_b / golpes_c  = los golpes en hemiola (negras con puntillo) de los compases 1-2, 33-34 y 65-66
#       del original (0:00-0:02, 0:41-0:44), SIN su bajo (mezcla − bajo de demucs); suenan en 1, 33, 65 y 129, igual
#       que en el original (en 129 vuelve golpes_a: el original repite 1-18 ahí).
#   efecto = el redoble + barrido "sci-fi" del compás 10 (0:12-0:13), sin bajo; suena en 10, 42 y 138 como allí.
#   voz_<nota> = notas sueltas del sintetizador "vocal" de esos golpes (pista vocals de demucs, cps 1-3): un
#       sampler propio las toca (granular para notas largas) donde el original usa ese instrumento: díadas del
#       puente, de los estribillos y de la sección C.
# Las muestras son de una canción con derechos: viven FUERA del repo (FlappyMonster_originals/music/muestras/).
#
#   ~/.venvs/fm-music/bin/python tools/music/cae_equipo.py --cortar [--stems DIR]   corta las muestras del original
#   ~/.venvs/fm-music/bin/python tools/music/cae_equipo.py                          compone, mezcla y exporta
#   ... --informe                                                                   solo las comprobaciones
import os, sys, glob, json, argparse, subprocess, tempfile
import numpy as np
import soundfile as sf
from scipy import signal as sg
from numba import njit

SR = 44100
BPM = 185.0
SX = 60.0 / BPM / 4                     # semicorchea (s)
BAR = 16 * SX
NBARS = 148
ORIG_T0 = 0.07                          # primer tiempo del compás 1 en el m4a original (medido: onsets + rejilla)
FUENTE = os.path.expanduser('~/Escritorio/Cae por el equipo')
MUESTRAS = os.path.join(os.environ.get('FM_ORIGINALS', '/home/mtvemo/FlappyMonster_originals'), 'music', 'muestras', 'cae_equipo')
SALIDA = '/home/mtvemo/FlappyMonster_pruebas/musica/cae_por_el_equipo'
SF_GS = os.path.expanduser('~/.local/share/soundfonts/GeneralUser-GS.sf2')
RNG = np.random.default_rng(7)

NOMBRES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def nt(s):                                                   # 'Bb4' / 'F#5' → MIDI
    p = NOMBRES[s[0]]; i = 1
    while i < len(s) and s[i] in '#b':
        p += 1 if s[i] == '#' else -1; i += 1
    return p + 12 * (int(s[i:]) + 1)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def fr(txt, bar, vel=100):
    """'0:D5/2 2:F5/2' → [(pos16 absoluta, dur16, midi, vel)] en el compás `bar` (1…)"""
    out = []
    for tok in txt.split():
        p, rest = tok.split(':'); n, d = rest.split('/')
        out.append(((bar - 1) * 16 + int(p), int(d), nt(n), vel))
    return out


# ── ACORDES ─────────────────────────────────────────────────────────────────────────────────────
CAL = {'': [0, 4, 7], 'm': [0, 3, 7], '7': [0, 4, 7, 10], 'maj7': [0, 4, 7, 11], 'm7': [0, 3, 7, 10],
       'sus4': [0, 5, 7], '7sus4': [0, 5, 7, 10]}


def acorde(sym):
    """'D7/F#' → (raíz pc, [pcs], bajo pc)"""
    base, _, bajo = sym.partition('/')
    r = NOMBRES[base[0]]; i = 1
    while i < len(base) and base[i] in '#b':
        r += 1 if base[i] == '#' else -1; i += 1
    q = base[i:]
    pcs = [(r + k) % 12 for k in CAL[q]]
    b = r % 12
    if bajo:
        b = NOMBRES[bajo[0]] + sum(1 if c == '#' else -1 for c in bajo[1:])
        b %= 12
    return r % 12, pcs, b


# ── LA FORMA (la del original, medida compás a compás) ─────────────────────────────────────────────
#   1-2 golpes · 3-10 groove (efecto en 10) · 11-18 groove + pizz · 19-32 puente sin bajo · 33-34 golpes ·
#   35-42 groove + pizz (efecto en 42) · 43-50 groove + tema A (50: parón de batería) · 51-64 estribillo 1 (8+6) ·
#   65-66 golpes · 67-82 sección C · 83-98 C' · 99-128 estribillo 2 (8+8+8+6) · 129-130 golpes · 131-146 groove
#   de salida (efecto en 138; fundido desde 141) · 147-148 cola.
GOLPES = {1: 'golpes_a', 33: 'golpes_b', 65: 'golpes_c', 129: 'golpes_a'}
EFECTO = (10, 18, 42, 138, 146)                  # como en el original (18 y 146: la misma muestra)
GIRO = (10, 18, 42, 50, 138, 146)                            # compases con la vuelta La♭ – Sol m – Fa sus


def seccion(b):
    if b in (1, 2, 33, 34, 65, 66, 129, 130): return 'golpes'
    if 3 <= b <= 18: return 'groove'
    if 19 <= b <= 32: return 'puente'
    if 35 <= b <= 50: return 'groove'
    if 51 <= b <= 64: return 'estribillo'
    if 67 <= b <= 98: return 'C'
    if 99 <= b <= 128: return 'estribillo'
    if 131 <= b <= 146: return 'groove'
    return 'cola'


def acordes():
    A = {}
    for b in range(1, NBARS + 1):
        if seccion(b) in ('groove', 'golpes'):
            A[b] = [(0, 'Bb7')] if b not in GIRO else [(0, 'Bb7'), (6, 'Ab'), (12, 'Gm'), (14, 'Fsus4')]
    A[1] = A[2] = A[33] = A[34] = A[65] = A[66] = A[129] = A[130] = [(0, 'Bb')]
    pu = ['Ebmaj7', [(0, 'Ebmaj7'), (8, 'Dm7')], 'Gm7', [(0, 'F/A'), (8, 'Bb')], 'Cm7', [(0, 'F7'), (8, 'Eb/G')],
          'Bb/D', [(0, 'Cm7'), (8, 'Dm7')], 'Ebmaj7', 'Dm7', [(0, 'Gm7'), (8, 'F/A')], 'Bbmaj7', 'Cm7',
          [(0, 'F7sus4'), (8, 'F7')]]
    for i, c in enumerate(pu): A[19 + i] = c
    ciclo = ['Ebmaj7', 'F', 'Gm7', 'Bb', 'Ebmaj7', 'C7', 'Gm7', [(0, 'Cm7/Bb'), (4, 'Ab'), (8, 'Gm7'), (12, 'D7/F#')]]
    final6 = ['Ebmaj7', 'F', 'Gm7', 'Bb', 'Ebmaj7', [(0, 'Fsus4'), (8, 'F')]]
    for i, c in enumerate(ciclo + final6): A[51 + i] = c
    A[64] = [(0, 'Fsus4'), (4, 'F')]
    for i, c in enumerate(ciclo * 3 + final6): A[99 + i] = c
    c1 = ['Bb', 'Dm7', 'Ebmaj7', 'F', 'Bb', 'Dm7', 'Ebmaj7', [(0, 'F'), (8, 'D7/F#')],
          'Gm', [(0, 'F'), (8, 'F7/Eb')], 'Ebmaj7', 'D7/F#', 'Gm', [(0, 'F'), (8, 'F7/Eb')], 'Ebmaj7', [(0, 'Fsus4'), (4, 'F')]]
    c2 = c1[:8] + c1[8:14] + ['Cm7', 'Dm7']
    for i, c in enumerate(c1 + c2): A[67 + i] = c
    A[147] = 'Ebmaj7'; A[148] = 'Bb'
    return {b: ([(0, c)] if isinstance(c, str) else c) for b, c in A.items()}


ACORDES = acordes()


def acorde_en(pos):
    b = pos // 16 + 1; s = pos % 16
    cur = ACORDES[b][0][1]
    for st, c in ACORDES[b]:
        if st <= s: cur = c
    return cur


# ── MELODÍAS (propias) ────────────────────────────────────────────────────────────────────────────
# v2 (usuario: la v1 "rancia y desordenada"): TODO sale de UNA célula de un compás, en 3+3+2+4+4:
#   sube a la 3ª y la 5ª del acorde, bordado a la 6ª, vuelve a la 3ª, cae a la fundamental ("sube-sube-borda-posa-cae")
# y se SECUENCIA sobre cada acorde; los compases 4 y 8 de cada frase resuelven. El tema A es la misma célula sobre
# Si♭7, la sección C es la célula INVERTIDA (cae y sube), el puente es una contramelodía de blancas.
CELULA = '0:{a}/3 3:{b}/3 6:{c}/2 8:{a}/4 12:{d}/4'
def cel(a, b, c, d): return CELULA.format(a=a, b=b, c=c, d=d)
TEMA_A = [cel('D5', 'F5', 'G5', 'Bb4'),
          '4:F4/2 6:Ab4/2 8:Bb4/8',
          cel('F5', 'Ab5', 'Bb5', 'D5'),
          '4:F5/2 6:Ab5/2 8:Bb5/8',
          cel('D5', 'F5', 'G5', 'Bb4'),
          '4:F4/2 6:Ab4/2 8:Bb4/8',
          cel('F5', 'Ab5', 'Bb5', 'D5'),
          '0:Bb5/4 4:Ab5/2 6:Eb5/4 10:C5/2 12:D5/2 14:C5/2']
PUENTE = ['0:D6/8 8:Bb5/8', '0:G5/8 8:A5/8', '0:Bb5/12 12:D6/4', '0:C6/8 8:D6/8',
          '0:Eb6/8 8:C6/8', '0:C6/8 8:Bb5/8', '0:D6/8 8:F5/8', '0:G5/8 8:A5/8',
          '0:Bb5/8 8:G5/8', '0:A5/8 8:F5/8', '0:G5/8 8:A5/8', '0:D6/16',
          '0:Eb6/8 8:G5/8', '0:Bb5/8 8:A5/8']
GANCHO = [cel('G5', 'Bb5', 'C6', 'Eb5'),
          cel('A5', 'C6', 'D6', 'F5'),
          '0:Bb5/3 3:D6/3 6:C6/2 8:Bb5/2 10:A5/2 12:G5/4',
          '0:F5/4 4:D5/2 6:Eb5/2 8:F5/8',
          cel('G5', 'Bb5', 'C6', 'Eb5'),
          cel('G5', 'Bb5', 'A5', 'E5'),
          cel('D5', 'F5', 'G5', 'Bb4'),
          '0:C5/4 4:Eb5/4 8:D5/4 12:F#5/2 14:A5/2']
GANCHO_FIN1 = GANCHO[:4] + [cel('G5', 'Bb5', 'C6', 'G5').replace('8:G5/4', '8:Bb5/4'),
                            '0:Bb5/4 4:A5/4 8:F5/8']
GANCHO_115 = GANCHO[:3] + ['0:F5/3 3:Bb5/3 6:C6/2 8:D6/8'] + GANCHO[4:]
GANCHO_FIN2 = GANCHO[:3] + ['0:F5/3 3:Bb5/3 6:D6/2 8:F6/8',              # LA LLAMADA (5-1-3-5) sobre Si♭
                            '0:Eb6/3 3:D6/3 6:C6/2 8:Bb5/4 12:G5/4',
                            '0:C6/4 4:Bb5/4 8:A5/8']
INV = '0:{a}/3 3:{b}/3 6:{c}/2 8:{a}/4 12:{d}/4'                           # la célula invertida: cae por el acorde y salta
def inv(a, b, c, d): return INV.format(a=a, b=b, c=c, d=d)
TEMA_C = [inv('F5', 'D5', 'Bb4', 'Bb5'), inv('A5', 'F5', 'D5', 'D6'), inv('Bb5', 'G5', 'Eb5', 'Eb6'),
          '0:C6/4 4:A5/4 8:F5/8',
          inv('F5', 'D5', 'Bb4', 'Bb5'), inv('A5', 'F5', 'D5', 'D6'),
          '0:Bb5/3 3:G5/3 6:Ab5/2 8:Bb5/2 10:D6/2 12:Eb6/4',
          '0:C6/4 4:A5/4 8:F#5/2 10:A5/2 12:C6/4',
          '0:Bb5/6 6:A5/2 8:G5/4 12:D5/4',
          '0:C5/3 3:F5/3 6:G5/2 8:A5/4 12:C6/4',
          '0:Bb5/6 6:Ab5/2 8:G5/4 12:Eb5/4',
          '0:D5/3 3:F#5/3 6:G5/2 8:A5/4 12:C6/4',
          '0:Bb5/6 6:A5/2 8:G5/4 12:D5/4',
          '0:C5/3 3:F5/3 6:G5/2 8:A5/2 10:C6/2 12:Eb6/4',
          '0:D6/4 4:Bb5/4 8:G5/4 12:Bb5/4',
          '0:Bb5/4 4:A5/4 8:C6/4']
TEMA_C2_FIN = [inv('G5', 'Eb5', 'C5', 'C6'),
               '0:A5/3 3:F5/3 6:G5/2 8:A5/2 10:C6/2 12:A5/2 14:F5/2']


def frases(lista, bar0, vel=100):
    out = []
    for i, t in enumerate(lista):
        out += fr(t, bar0 + i, vel)
    return out


def melodias():
    M = {}
    M['tema_a'] = frases(TEMA_A, 43) + [(p, d, m, 82) for p, d, m, v in frases(TEMA_A, 139)]
    M['puente'] = frases(PUENTE, 19)
    g1 = frases(GANCHO + GANCHO_FIN1, 51)
    g2 = frases(GANCHO, 99) + frases(GANCHO, 107) + frases(GANCHO_115, 115) + frases(GANCHO_FIN2, 123)
    M['gancho'] = g1 + g2
    M['tema_c'] = frases(TEMA_C, 67) + frases(TEMA_C[:14] + TEMA_C2_FIN, 83)
    return M


# ── PARTES GENERADAS DESDE LOS ACORDES ───────────────────────────────────────────────────────────
def tonos(sym, lo, hi, triada=False):
    _, pcs, _ = acorde(sym)
    if triada: pcs = pcs[:3]
    return [m for m in range(lo, hi + 1) if m % 12 in pcs]


def diada(sym, mel=(), lo=50, hi=66):
    """dos tonos del acorde en el registro de la voz muestreada (Re3-Fa#4), con la 3ª si se puede, elegidos para
    no rozar (2ª m / 7ª M / tritono) con las notas de la melodía que suenan encima"""
    r, pcs, _ = acorde(sym)
    if 'maj7' in sym: pcs = pcs[:3]                            # la 7ª mayor contra la tónica del pluck roza
    ts = [m for m in range(lo, hi + 1) if m % 12 in pcs]
    mejor = None
    for i, a in enumerate(ts):
        for b in ts[i + 1:]:
            if not 3 <= b - a <= 9 or a % 12 == b % 12: continue
            roces = sum(1 for m in mel for x in (a, b) if (m - x) % 12 in (1, 11, 6))
            nota = roces * 10 - (3 if pcs[1] in (a % 12, b % 12) else 0) + abs((a + b) / 2 - 58) * 0.2
            if mejor is None or nota < mejor[0]: mejor = (nota, a, b)
    return [mejor[1], mejor[2]]


def voz_partes(melodia):
    """el sintetizador vocal muestreado: díadas donde el original lo usa (puente, estribillos, C)"""
    out = []
    def encima(p0, p1): return [m for p, d, m, v in melodia if p < p1 and p + d > p0 and d >= 2]
    for b in range(1, NBARS + 1):
        s = seccion(b)
        if s not in ('puente', 'estribillo', 'C', 'cola'): continue
        ch = ACORDES[b]
        for i, (st, sym) in enumerate(ch):
            en = ch[i + 1][0] if i + 1 < len(ch) else 16
            if s == 'C':                                   # blancas
                for h in range(st, en, 8):
                    p0 = (b - 1) * 16 + h
                    for m in diada(sym, encima(p0, p0 + min(8, en - h))): out.append((p0, min(8, en - h), m, 80))
            else:
                p0 = (b - 1) * 16 + st
                for m in diada(sym, encima(p0, p0 + en - st)): out.append((p0, en - st, m, 78 if s == 'puente' else 84))
    return out


def voz_chops(melodia):
    """el sinte vocal muestreado donde y COMO lo usa el original (puente, parón del 50, estribillos, C): cada nota
    del original (voz_notas.json: inicio, duración — cortes cortos o notas sostenidas —) se toca con la misma
    duración y dinámica, pero sobre MIS acordes: el tono de mi acorde más cercano a la altura original, en Sol2-Sol4,
    evitando rozar con la melodía; sin cruzar un cambio de acorde (ahí se rearticula)"""
    R = json.load(open(os.path.join(MUESTRAS, 'voz_ritmo.json')))
    N = json.load(open(os.path.join(MUESTRAS, 'voz_notas.json')))
    out = []
    def encima(p0, p1): return [m for p, d, m, v in melodia if p < p1 and p + d > p0 and d >= 2]
    unidas = []                                    # en la sección C la voz SOSTIENE: se unen los trozos de igual altura
    for k, d, p in N:
        if unidas and seccion(k // 16 + 1) == 'C' and unidas[-1][2] == p and unidas[-1][0] + unidas[-1][1] == k:
            unidas[-1][1] += d
        else:
            unidas.append([k, d, p])
    for k, d, p in unidas:
        b = k // 16 + 1
        if b > NBARS or seccion(b) in ('golpes', 'cola'): continue
        lv = R[str(b)][0]
        if lv < -55: continue                                  # TODAS las apariciones, también las flojas del groove
        if b in EFECTO and k % 16 >= 2: continue               # ahí suena la muestra del efecto
        if b in (3, 35, 131) and k % 16 < 6: continue          # la cola de la voz de los golpes ya suena ahí
        vel = int(np.clip(100 + 1.5 * (lv + 28), 48, 118))
        pos, fin = k, k + d
        while pos < fin:                                       # se parte en los cambios de acorde
            bb, h = pos // 16 + 1, pos % 16
            if bb > NBARS or seccion(bb) in ('golpes', 'cola') or (bb in EFECTO and h >= 2): break
            cambio = (bb - 1) * 16 + min([st for st, _ in ACORDES[bb] if st > h] + [16])
            e = min(fin, cambio)
            sym = acorde_en(pos)
            ts = [m for m in tonos(sym, 43, 68, True) if not any((x - m) % 12 in (1, 11, 6) for x in encima(pos, e))]
            if ts:
                m = min(ts, key=lambda t: (abs(t - p), t))
                out.append((pos, e - pos, m, vel if pos == k else int(vel * 0.85)))
            pos = e
    return out


# ── GOLPES SUELTOS (las versiones cortadas y pequeñas de los golpes del principio) ───────────────────────────────
# El original repite, sobre todo en la sección C (1:26-2:07) y en el estribillo 2, UNO o DOS golpes sueltos de la
# figura del compás 1-2 (detectados compás a compás: golpes_mini_detect.json, puntuación ≥ 0,79 contra cada golpe).
# Aquí suena el MISMO trozo de golpes_a (golpe i = semicorcheas 6i…6i+6 de los compases 1-2: Si♭ Fa Re Do Re Do),
# el que usa el original si su nota es del acorde propio; si no, el más cercano que lo sea.
NOTA_GOLPE = [58, 53, 50, 48, 62, 60]
MINI_DESDE = 46                                   # antes de 46 los aciertos ya los cubren los golpes y el efecto


def golpes_mini():
    det = json.load(open(os.path.join(MUESTRAS, 'golpes_mini_detect.json')))
    out = []
    for b, h, sc, i in det:
        if b < MINI_DESDE or seccion(b) in ('golpes', 'cola') or b in EFECTO: continue
        p = (b - 1) * 16 + h
        _, pcs, _ = acorde(acorde_en(min(p + 2, NBARS * 16 - 1)))            # el acorde al que llega
        _, ahora, _ = acorde(acorde_en(p))                                    # y el que aún suena (anacrusa)
        def vale(pc):
            return pc in pcs and (pcs.index(pc) < 3 or len(pcs) == 4 and 'maj7' not in acorde_en(p + 2)) and \
                not any((pc - q) % 12 in (1, 11) for q in ahora[:3])
        orden = [i] + sorted(range(6), key=lambda j: abs(NOTA_GOLPE[j] - NOTA_GOLPE[i]))
        j = next((j for j in orden if vale(NOTA_GOLPE[j] % 12)), None)
        if j is None: continue
        out.append((p, 6, NOTA_GOLPE[j], j))
    # cada golpe dura hasta el siguiente (máx. una negra con puntillo)
    out.sort()
    return [(p, min(d, (out[k + 1][0] - p) if k + 1 < len(out) else d), m, j) for k, (p, d, m, j) in enumerate(out)]


def bajo_partes():
    out = []
    riff = ['0:Bb1/3 3:Bb2/1 4:Bb1/2 7:D2/1 8:F2/3 11:Bb1/2 14:Ab1/2',
            '0:Bb1/2 2:Bb2/2 6:F2/2 8:Bb2/2 10:Ab2/2 12:F2/2 14:D2/2']
    giro = '0:Bb1/2 2:Bb2/2 4:Bb2/2 6:Ab1/2 8:Ab2/3 12:G1/2 14:F1/2'
    for b in range(1, NBARS + 1):
        s = seccion(b)
        if s == 'groove':
            k = (b - (3 if b < 19 else 35 if b < 51 else 131)) % 2
            out += fr(giro if b in GIRO else riff[k], b, 108)
        elif s == 'estribillo' or s == 'C':
            for i, (st, sym) in enumerate(ACORDES[b]):
                en = ACORDES[b][i + 1][0] if i + 1 < len(ACORDES[b]) else 16
                _, _, bp = acorde(sym)
                R = [m for m in range(39, 51) if m % 12 == bp][0]
                if en - st <= 4:                                # paseo de negras: nota + octava
                    out += [((b - 1) * 16 + st, 2, R, 108), ((b - 1) * 16 + st + 2, 2, R + 12, 96)]
                    continue
                if s == 'estribillo':
                    pat = [(0, 3, 0), (3, 1, 0), (4, 2, 12), (6, 2, 0), (8, 2, 7), (10, 2, 12), (12, 2, 0), (14, 2, 12)]
                else:
                    pat = [(h, 2, 12 * (h // 2 % 2)) for h in range(0, 16, 2)]
                for h, d, iv in pat:
                    if st <= h < en:
                        n = R + iv
                        if iv == 7 and (n % 12) not in acorde(sym)[1]: n = R + 12
                        out.append(((b - 1) * 16 + h, d, n, 110 if h % 4 == 0 else 96))
    for b in (2, 34, 130):                                  # anacrusa hacia el groove, como el original
        out += fr('14:Bb1/2', b, 100)
    out += [((147 - 1) * 16, 16, nt('Eb1'), 90), ((148 - 1) * 16, 20, nt('Bb0'), 90)]
    return out


def arpegios_chip():
    """groove: corcheas de pulso 25 % sobre Si♭7 (vuelta: La♭ – Sol m – Fa sus)"""
    out = []
    p = ['0:Bb4/2 2:F5/2 4:D5/2 6:Bb5/2 8:F5/2 10:D5/2 12:Ab5/2 14:F5/2',
         '0:Bb4/2 2:F5/2 4:C6/2 6:Bb5/2 8:F5/2 10:D5/2 12:F5/2 14:D5/2']
    g = '0:Bb4/2 2:F5/2 4:D5/2 6:Eb5/2 8:C5/2 10:Ab4/2 12:D5/2 14:C5/2'
    for b in range(1, NBARS + 1):
        if seccion(b) != 'groove': continue
        k = (b - (3 if b < 19 else 35 if b < 51 else 131)) % 2
        n = fr(g if b in GIRO else p[k], b, 90)
        if b in EFECTO: n = [x for x in n if x[0] % 16 < 2]
        out += n
    return out


def skank_c():
    """sección C: díadas a contratiempo (la marca de la casa), pulso 12,5 %"""
    out = []
    for b in range(67, 99):
        for h in (2, 6, 10, 14):
            sym = acorde_en((b - 1) * 16 + h)
            t = tonos(sym, 65, 77)
            for m in t[:2]: out.append(((b - 1) * 16 + h, 1, m, 70))
    return out


def pizz_partes():
    out = []
    p = ['0:F5/1 3:D5/1 6:F5/1 8:G5/1 11:F5/1 14:D5/1', '0:C5/1 3:D5/1 6:F5/1 10:Bb4/1 12:C5/1 14:D5/1']
    g = '0:F5/1 3:D5/1 6:Eb5/1 8:C5/1 12:D5/1 14:C5/1'
    for b in list(range(11, 19)) + list(range(35, 43)) + list(range(131, 147)):
        k = (b - 1) % 2
        n = fr(g if b in GIRO else p[k], b, 92)
        if b in EFECTO: n = [x for x in n if x[0] % 16 < 2]
        out += n
    return out


def pluck_partes():
    out = []
    for b in range(19, 33):                                 # puente: semicorcheas 3+3+2 de tonos del acorde
        for h in range(16):
            sym = acorde_en((b - 1) * 16 + h)
            t = tonos(sym, 58, 79, True)
            idx = [0, 1, 2, 0, 1, 2, 3, 2][h % 8]
            if b == 32 and h >= 12: continue
            out.append(((b - 1) * 16 + h, 1, t[min(idx, len(t) - 1) + 1], 118 if h % 8 in (0, 3, 6) else 88))
    for b in list(range(51, 65)) + list(range(99, 129)):      # estribillos: corcheas en células de 3 (hemiola)
        for i, h in enumerate(range(0, 16, 2)):
            sym = acorde_en((b - 1) * 16 + h)
            t = tonos(sym, 62, 80, True)
            out.append(((b - 1) * 16 + h, 2, t[[0, 1, 2, 0, 1, 2, 0, 1][i] + 1], 86 if i in (0, 3, 6) else 66))
    return out


def armonia_tercera(mel):
    """2ª voz del gancho: el tono del acorde más alto entre 3 y 7 semitonos por debajo"""
    out = []
    for p, d, m, v in mel:
        _, pcs, _ = acorde(acorde_en(p))
        pcs = pcs[:3]
        cand = [x for x in range(m - 7, m - 2) if x % 12 in pcs]
        if cand: out.append((p, d, max(cand), int(v * 0.8)))
    return out


# ── BATERÍA (propia; GM en GeneralUser GS) ─────────────────────────────────────────────────────────
K, SN, RIM, CL, CH, OH, CR, SH, T1, T2, T3, T4 = 36, 38, 37, 39, 42, 46, 49, 70, 50, 47, 45, 41


def bateria():
    ev = []
    def at(b, h, n, v): ev.append(((b - 1) * 16 + h, n, v))
    for b in range(1, NBARS + 1):
        s = seccion(b); k = b % 2
        if s == 'groove':
            if b in EFECTO:
                at(b, 0, K, 112); at(b, 0, CH, 80); continue
            if b == 50:
                continue                                    # el parón (como el original)
            if k == 1: kicks, sn = [0, 7, 10], [8]
            else: kicks, sn = [2, 4, 10], [8]
            if b in GIRO: kicks, sn = [0, 6], [8, 12, 14]
            for h in kicks: at(b, h, K, 112)
            for h in sn: at(b, h, SN, 108)
            at(b, 13, SN, 40); at(b, 15, SN, 34)
            for h in range(0, 16, 2): at(b, h, CH if h != 14 else OH, 82 if h % 4 == 0 else 60)
        elif s == 'puente':
            for h in (0, 2, 10): at(b, h, K, 46)
            at(b, 8, RIM, 80)
            for h in range(16): at(b, h, SH, 42 if h % 4 == 2 else 26)
            if b >= 27:
                for h in range(2, 16, 4): at(b, h, CH, 50)
            if b == 32:
                for h, n in zip((8, 10, 12, 14), (T1, T2, T3, T4)): at(b, h, n, 70 + h * 2)
        elif s == 'estribillo':
            fuerte = b >= 99
            if k == 1: kicks = [0, 6, 10]
            else: kicks = [2, 8, 10]
            for h in kicks: at(b, h, K, 115)
            for h in (4, 12): at(b, h, SN, 112)
            at(b, 15, SN, 44); at(b, 7, SN, 36)
            for h in range(0, 16, 2): at(b, h, OH if h % 4 == 2 and fuerte else CH, 86 if h % 4 == 0 else 66)
            if fuerte and b >= 115:
                for h in range(1, 16, 2): at(b, h, CH, 42)
            if b in (51, 59, 99, 107, 115, 123) or (fuerte and b % 4 == 3):
                at(b, 0, CR, 96 if b in (51, 99) else 80)
            if b in (58, 106, 114, 122):
                for h, n in zip((12, 13, 14, 15), (T1, T2, T3, T4)): at(b, h, n, 96)
            if b in (64, 128):
                for h in (8, 10, 12, 13, 14, 15): at(b, h, SN, 70 + h * 3)
        elif s == 'C':
            if k == 1: kicks, sn = [0, 2, 11], [8]
            else: kicks, sn = [4, 6, 14], [8]
            for h in kicks: at(b, h, K, 112)
            for h in sn: at(b, h, SN, 110)
            at(b, 13, SN, 40)
            for h in range(2, 16, 4): at(b, h, CH, 72)
            for h in range(0, 16, 4): at(b, h, CH, 54)
            if b >= 83:
                for h in range(1, 16, 2): at(b, h, SH, 46)
            if b in (67, 75, 83, 91): at(b, 0, CR, 92)
            if b == 97:
                for h in range(0, 16, 2): at(b, h, SN, 60 + h * 2)
            if b == 98:
                for h in range(16): at(b, h, SN, 62 + h * 3)
            if b in (74, 82, 90):
                for h, n in zip((12, 13, 14, 15), (T1, T2, T3, T4)): at(b, h, n, 92)
        if b in (3, 35, 131): at(b, 0, CR, 100)
        if b in (11, 43, 139): at(b, 0, CR, 84)
        if b == 19: at(b, 0, CR, 70)
        if b == 18 or b == 146:
            pass
    return ev


# ── SÍNTESIS ───────────────────────────────────────────────────────────────────────────────────────
@njit(cache=True)
def svf_lp(x, fc, q):
    """filtro de estado variable, paso bajo, corte por muestra"""
    y = np.zeros_like(x); lo = 0.0; bp = 0.0
    for i in range(len(x)):
        f = 2.0 * np.sin(np.pi * min(fc[i], 16000.0) / 44100.0)
        hp = x[i] - lo - q * bp
        bp += f * hp
        lo += f * bp
        y[i] = lo
    return y


@njit(cache=True)
def karplus(n, per, decay, seed):
    np.random.seed(seed)
    P = int(per)
    buf = np.random.uniform(-1.0, 1.0, P)
    # ataque más suave: el ruido inicial pasado por un paso bajo
    for i in range(1, P): buf[i] = 0.5 * buf[i] + 0.5 * buf[i - 1]
    y = np.zeros(n); j = 0
    for i in range(n):
        a = buf[j]; b = buf[(j + 1) % P]
        y[i] = a
        buf[j] = decay * 0.5 * (a + b)
        j = (j + 1) % P
    return y


def blep(ph, dt):
    out = np.zeros_like(ph)
    m = ph < dt; t = ph[m] / dt[m]; out[m] = t + t - t * t - 1
    m = ph > 1 - dt; t = (ph[m] - 1) / dt[m]; out[m] = t * t + t + t + 1
    return out


def saw(f):
    dt = f / SR; ph = np.cumsum(dt) % 1.0
    return 2 * ph - 1 - blep(ph, dt)


def pulse(f, duty):
    dt = f / SR; ph = np.cumsum(dt) % 1.0
    ph2 = (ph + 1 - duty) % 1.0
    return (2 * ph - 1 - blep(ph, dt)) - (2 * ph2 - 1 - blep(ph2, dt))


def env_adsr(n, gate, a, d, s, r):
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    g = int(gate * SR)
    if g < n:
        lv = e[g - 1] if g > 0 else 0
        e[g:] = lv * np.exp(-(t[g:] - gate) / max(r, 1e-4))
    return e


def vib(n, f, depth_c, rate, delay):
    t = np.arange(n) / SR
    amt = np.clip((t - delay) / 0.25, 0, 1) * depth_c
    return f * 2 ** (amt * np.sin(2 * np.pi * rate * t) / 1200)


def v_bajo(m, d, v):
    f = hz(m); dur = d * SX; n = int((dur + 0.08) * SR)
    x = 0.5 * saw(np.full(n, f)) + 0.5 * saw(np.full(n, f * 1.004)) + 0.6 * pulse(np.full(n, f / 2), 0.5)
    t = np.arange(n) / SR
    fc = 160 + (1500 + 1400 * v / 127) * np.exp(-t / 0.10)
    y = svf_lp(x, fc, 0.7)
    y += 0.55 * np.sin(2 * np.pi * f * t)
    y = np.tanh(1.6 * y) * env_adsr(n, dur - 0.01, 0.003, 0.25, 0.75, 0.03)
    return y * (v / 127)


def v_chip(m, d, v, duty=0.25, larga=False):
    f = hz(m); dur = d * SX; n = int((dur + 0.06) * SR)
    fr_ = vib(n, f, 14, 5.8, 0.16) if larga else np.full(n, f)
    x = pulse(fr_, duty)
    e = env_adsr(n, dur, 0.002, 0.18 if not larga else 0.5, 0.45 if not larga else 0.8, 0.03)
    return x * e * (v / 127) * 0.5


def v_lead(m, d, v):
    f = hz(m); dur = d * SX; n = int((dur + 0.12) * SR)
    fv = vib(n, f, 16, 5.6, 0.14)
    x = 0.45 * saw(fv * 2 ** (6 / 1200)) + 0.45 * saw(fv * 2 ** (-6 / 1200)) + 0.35 * pulse(fv, 0.5)
    t = np.arange(n) / SR
    fc = 2200 + 2800 * np.exp(-t / 0.18)
    y = svf_lp(x, fc, 0.9)
    return y * env_adsr(n, dur - 0.005, 0.006, 0.4, 0.85, 0.06) * (v / 127) * 0.6


def v_pluck(m, d, v):
    f = hz(m); n = int(min(d * SX + 0.35, 1.0) * SR)
    y = karplus(n, SR / f, 0.994, int(m * 13 + d))
    t = np.arange(n) / SR
    return y * np.exp(-t / 0.35) * (v / 127) * 0.6


def v_campana(m, d, v):
    f = hz(m); dur = d * SX; n = int((dur + 0.9) * SR); t = np.arange(n) / SR
    idx = 2.2 * np.exp(-t / 0.18) + 0.25
    y = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * 4 * f * t)) * np.exp(-t / 0.7)
    y += 0.3 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.3)
    y *= env_adsr(n, dur + 0.25, 0.003, 10, 1, 0.25)
    return y * (v / 127) * 0.5


# ── EL SAMPLER DE LA VOZ (notas literales del original) ───────────────────────────────────────────
_VOZ = None


def voz_carga():
    global _VOZ
    if _VOZ is None:
        meta = json.load(open(os.path.join(MUESTRAS, 'voz.json')))
        _VOZ = []
        for k, p in meta.items():
            y, sr = sf.read(os.path.join(MUESTRAS, f'voz_{k}.wav'))
            _VOZ.append((p, y if y.ndim == 1 else y.mean(1)))
    return _VOZ


def v_voz(m, d, v):
    """nota del sintetizador vocal: la muestra más cercana, reafinada; el cuerpo se alarga con granos"""
    src = min(voz_carga(), key=lambda s: abs(s[0] - m))
    p0, y = src
    ratio = 2 ** ((m - p0) / 12)
    xi = np.arange(0, len(y) - 1, ratio)
    z = np.interp(xi, np.arange(len(y)), y)                   # reafinado (remuestreo)
    dur = d * SX; n = int((dur + 0.18) * SR)
    att = int(0.07 * SR)
    out = np.zeros(n)
    a = min(att, len(z), n)
    out[:a] = z[:a]
    if n > att:                                               # granos de 90 ms del tramo estable
        g = int(0.09 * SR); hop = g // 2; w = np.hanning(g)
        lo, hi = int(0.06 * SR), max(int(0.06 * SR) + 1, len(z) - g - int(0.03 * SR))
        pos = att - hop
        rng = np.random.default_rng(int(m * 31 + d))
        cuerpo = np.zeros(n + g)
        while pos < n:
            s = rng.integers(lo, hi)
            cuerpo[pos:pos + g] += z[s:s + g] * w
            pos += hop
        cf = np.clip((np.arange(n) - (att - hop)) / hop, 0, 1)
        out = out * (1 - cf) + cuerpo[:n] * cf
    e = env_adsr(n, dur, 0.004, 10, 1, 0.12)
    return out * e * (v / 127)


# ── RENDER ─────────────────────────────────────────────────────────────────────────────────────────
NTOT = int((NBARS * BAR + 3.0) * SR)


def pista(notas, voz, **kw):
    y = np.zeros(NTOT)
    for p, d, m, v in notas:
        s = voz(m, d, v, **kw)
        i = int(round(p * SX * SR))
        e = min(NTOT, i + len(s)); y[i:e] += s[:e - i]
    return y


def fluid(eventos, programa, drums=False):
    """renderiza notas con GeneralUser GS (fluidsynth); eventos: (pos16, dur16, nota, vel)"""
    import mido
    T = 480
    mf = mido.MidiFile(type=0, ticks_per_beat=T); tr = mido.MidiTrack(); mf.tracks.append(tr)
    tr.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / BPM)))
    ch = 9 if drums else 0
    tr.append(mido.Message('program_change', channel=ch, program=programa))
    ev = []
    for p, d, n, v in eventos:
        t0 = p * T // 4
        ev += [(t0 + max(1, d * T // 4 - 8), 0, n, 0), (t0, 1, n, v)]
    t = 0
    for tt, on, n, vel in sorted(ev):
        tr.append(mido.Message('note_on' if on else 'note_off', channel=ch, note=n, velocity=vel, time=tt - t)); t = tt
    with tempfile.TemporaryDirectory() as dd:
        mp, wp = os.path.join(dd, 'x.mid'), os.path.join(dd, 'x.wav')
        mf.save(mp)
        subprocess.run(['fluidsynth', '-ni', '-R', '0', '-C', '0', '-g', '0.6', '-r', str(SR), '-F', wp, SF_GS, mp],
                       capture_output=True)
        y, _ = sf.read(wp)
    out = np.zeros((NTOT, 2)); L = min(NTOT, len(y)); out[:L] = y[:L]
    return out


def estereo(x, pan=0.0):
    a = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], 1) * np.sqrt(2)


def reverb_ir(seg=1.1):
    n = int(seg * SR); t = np.arange(n) / SR
    ir = RNG.standard_normal((n, 2)) * np.exp(-t / 0.32)[:, None]
    ir = sg.sosfilt(sg.butter(2, 6000 / (SR / 2), output='sos'), ir, axis=0)
    ir[:int(0.012 * SR)] = 0
    return ir / np.sqrt(np.sum(ir ** 2) / 2)


def reverb(x, ir):
    return np.stack([sg.fftconvolve(x[:, c], ir[:, c])[:len(x)] for c in range(2)], 1)


def eco(x, delay16=3, fb=0.3, mix=0.25):
    d = int(delay16 * SX * SR); y = x.copy(); g = mix
    for k in range(1, 4):
        s = np.zeros_like(x); s[d * k:] = x[:-d * k] * g
        if k % 2: s = s[:, ::-1]
        y += s; g *= fb
    return y


def ducking(kicks, prof=0.45, rel=0.12):
    """sidechain: baja el pad/bajo/arpegios en cada bombo"""
    g = np.ones(NTOT); t = np.arange(int(0.4 * SR)) / SR; curva = 1 - prof * np.exp(-t / rel)
    for p in kicks:
        i = int(p * SX * SR); e = min(NTOT, i + len(curva))
        g[i:e] = np.minimum(g[i:e], curva[:e - i])
    return g[:, None]


def rms(x):
    return np.sqrt(np.mean(x ** 2) + 1e-12)


def tramo(b0, b1):
    return slice(int((b0 - 1) * BAR * SR), int((b1) * BAR * SR))


def mutear(y, bares, desde16=0):
    for b in bares:
        a = int(((b - 1) * 16 + desde16) * SX * SR); e = int(b * BAR * SR)
        r = int(0.008 * SR)
        y[a:a + r] *= np.linspace(1, 0, r)[:, None] if y.ndim == 2 else np.linspace(1, 0, r)
        y[a + r:e] = 0
    return y


# ── COMPROBACIONES (consonancia) ──────────────────────────────────────────────────────────────────
def comprobar(partes):
    """notas largas fuera del acorde y choques m2 / 7M / tritono de una corchea o más entre voces"""
    avisos = []
    for nombre in ('gancho', 'tema_c', 'puente', 'tema_a'):
        for p, d, m, v in partes[nombre]:
            r, pcs, _ = acorde(acorde_en(p))
            if 'maj7' in acorde_en(p): pcs = pcs + [(r + 2) % 12]          # la 9ª sobre maj7: tensión, no roce
            if m % 12 not in pcs and (d >= 3 or (p % 4 == 0 and d >= 2)):
                avisos.append(f'{nombre} c{p // 16 + 1}:{p % 16} {m} fuera del acorde {acorde_en(p)} ({d}/16)')
    voces = [(k, n) for k in partes for n in partes[k] if k not in ('bateria',)]
    malos = {1, 11, 6}
    choques = 0
    cub = {}
    for i, (k, n) in enumerate(voces):
        for h in range(n[0], n[0] + n[1]): cub.setdefault(h, []).append(i)
    vistos = set()
    for h, ids in sorted(cub.items()):
        for x in range(len(ids)):
            for y in range(x + 1, len(ids)):
                i, j = ids[x], ids[y]
                if (i, j) in vistos: continue
                (ka, a), (kb, b) = voces[i], voces[j]
                if ka == kb: continue
                vistos.add((i, j))
                ini = max(a[0], b[0]); fin = min(a[0] + a[1], b[0] + b[1])
                iv = abs(a[2] - b[2]) % 12
                if fin - ini >= 2 and iv in malos and abs(a[2] - b[2]) < 24:
                    _, pcs, _ = acorde(acorde_en(ini))
                    if iv != 1 and a[2] % 12 in pcs and b[2] % 12 in pcs: continue
                    choques += 1
                    if choques <= 25:
                        avisos.append(f'choque {ka}/{kb} c{ini // 16 + 1}:{ini % 16} {a[2]}-{b[2]}')
    return avisos, choques


# ── CORTE DE LAS MUESTRAS ─────────────────────────────────────────────────────────────────────────
def ritmo_voz(stems):
    """dónde y cómo suena el sinte vocal en el original: por compás, su nivel (dB) y sus ataques en la rejilla de
    semicorcheas ('X' fuerte, 'x' flojo, '.' nada), medidos sobre la pista vocals de demucs. Se guarda en
    voz_ritmo.json: el arreglo propio usa ese RITMO y esa DINÁMICA con sus propios acordes"""
    import librosa
    sr = 22050
    v = librosa.load(os.path.join(stems, 'vocals.wav'), sr=sr)[0]
    on = librosa.onset.onset_strength(y=v, sr=sr, hop_length=128)
    rr = librosa.feature.rms(y=v, hop_length=128)[0]
    fr_ = lambda t: int(t * sr / 128)
    m = np.percentile(on, 98); out = {}
    for b in range(1, NBARS + 1):
        a = ORIG_T0 + (b - 1) * BAR
        lv = 20 * np.log10(rr[fr_(a):fr_(a + BAR)].mean() + 1e-9)
        vals = [on[max(0, fr_(a + k * SX) - 2):fr_(a + k * SX) + 3].max() for k in range(16)]
        out[b] = [round(float(lv), 1), ''.join('X' if x > 0.6 * m else 'x' if x > 0.3 * m else '.' for x in vals)]
    json.dump(out, open(os.path.join(MUESTRAS, 'voz_ritmo.json'), 'w'), indent=0)
    # las NOTAS (inicio y duración en semicorcheas, altura original): la voz del original no solo corta, también
    # sostiene notas largas (sección C) — el arreglo propio respeta esas duraciones
    f0, _, _ = librosa.pyin(v, fmin=90, fmax=900, sr=sr, frame_length=2048, hop_length=128)
    alt = []
    for k in range(NBARS * 16):
        a = ORIG_T0 + k * SX
        f = f0[fr_(a):fr_(a + SX)]; f = f[~np.isnan(f)]
        alt.append(float(np.median(librosa.hz_to_midi(f))) if len(f) >= 4 else None)
    notas, k = [], 0
    while k < len(alt):
        if alt[k] is None: k += 1; continue
        b, h = k // 16 + 1, k % 16
        p0 = round(alt[k]); j = k + 1
        while j < len(alt) and alt[j] is not None and abs(alt[j] - p0) < 0.7 and \
                out[j // 16 + 1][1][j % 16] != 'X' and j - k < 32:
            j += 1
        notas.append([k, j - k, p0]); k = j
    json.dump(notas, open(os.path.join(MUESTRAS, 'voz_notas.json'), 'w'))


def cortar(stems):
    os.makedirs(MUESTRAS, exist_ok=True)
    m4a = glob.glob(os.path.join(FUENTE, '*.m4a'))[0]
    with tempfile.TemporaryDirectory() as dd:
        w = os.path.join(dd, 'orig.wav')
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', m4a, '-ar', str(SR), w], check=True)
        if not stems:
            subprocess.run([os.path.expanduser('~/.venvs/fm-music/bin/demucs'), '-n', 'htdemucs_6s', '-o', dd, w], check=True)
            stems = os.path.join(dd, 'htdemucs_6s', 'orig')
        mix, _ = sf.read(w)
        S = {k: sf.read(os.path.join(stems, k + '.wav'))[0] for k in ('bass', 'vocals', 'guitar', 'drums')}
    n = min(len(mix), *(len(v) for v in S.values()))
    mix = mix[:n]; S = {k: v[:n] for k, v in S.items()}
    sinbajo = mix - S['bass']
    pos = lambda bar, s16: int(round((ORIG_T0 + ((bar - 1) * 16 + s16) * SX) * SR))
    ms = lambda s: int(s * SR)
    def rampa(n_, up=True):
        r = np.linspace(0, 1, n_) if up else np.linspace(1, 0, n_); return r[:, None]
    for tag, bar in (('a', 1), ('b', 33), ('c', 65)):
        a = pos(bar, 0) - ms(0.02); e = pos(bar + 2, 0)
        cola = ms(0.8); x = np.zeros((e - a + cola, 2))
        x[:e - a] = sinbajo[a:e]; x[:ms(0.02)] *= rampa(ms(0.02))
        # tras el compás 3 solo sigue sonando la voz (y lo demás se apaga en 60 ms: el platillo no se corta en seco)
        x[e - a:] += S['vocals'][e:e + cola] * np.exp(-np.arange(cola) / (0.25 * SR))[:, None]
        resto = (sinbajo - S['vocals'])[e:e + ms(0.06)] * rampa(ms(0.06), False)
        x[e - a:e - a + ms(0.06)] += resto
        sf.write(os.path.join(MUESTRAS, f'golpes_{tag}.wav'), x, SR, subtype='FLOAT')
    a = pos(10, 2) - ms(0.015); e = pos(11, 0)
    cola = ms(0.5); x = np.zeros((e - a + cola, 2))
    x[:e - a] = sinbajo[a:e]; x[:ms(0.015)] *= rampa(ms(0.015))
    tonal = S['vocals'] + S['guitar']
    x[e - a:] += tonal[e:e + cola] * np.exp(-np.arange(cola) / (0.18 * SR))[:, None]
    x[e - a:e - a + ms(0.05)] += (sinbajo - tonal)[e:e + ms(0.05)] * rampa(ms(0.05), False)
    sf.write(os.path.join(MUESTRAS, 'efecto.wav'), x, SR, subtype='FLOAT')
    # notas de la voz (medidas con pyin: mediana de la altura de cada tramo)
    notas = {'C3': (4.5, 6.0, 48.04), 'D3': (3.0, 4.5, 50.29), 'F3': (1.5, 3.0, 53.09), 'Bb3': (7.5, 10.5, 58.09)}
    meta = {}
    for k, (b0, b1, p) in notas.items():
        a = pos(1, 0) + int(b0 * 4 * SX * SR) + ms(0.012); e = pos(1, 0) + int(b1 * 4 * SX * SR) - ms(0.015)
        y = S['vocals'][a:e].mean(1)
        y[:ms(0.004)] *= np.linspace(0, 1, ms(0.004)); y[-ms(0.02):] *= np.linspace(1, 0, ms(0.02))
        y /= np.abs(y).max() + 1e-9
        sf.write(os.path.join(MUESTRAS, f'voz_{k}.wav'), y, SR, subtype='FLOAT')
        meta[k] = p
    json.dump(meta, open(os.path.join(MUESTRAS, 'voz.json'), 'w'), indent=1)
    ritmo_voz(stems)
    print('muestras en', MUESTRAS)


# ── MEZCLA ─────────────────────────────────────────────────────────────────────────────────────────
MELODICAS = ('gancho', 'gancho8', 'arm', 'c', 'c8', 'cpl', 'tema_a', 'bell')


SUFIJO = ''


def construir(informe=False, capas_dir=None, modulo=None):
    """modulo: otro archivo de melodías (p. ej. cae_equipo_melodias) con melodias() → dict como el de aquí y,
    opcional, ajustar_acordes(ACORDES) que retoca acordes de detalle (misma forma). Sale con su sufijo."""
    global SUFIJO
    if modulo:
        import importlib
        mod = importlib.import_module(modulo)
        if hasattr(mod, 'ajustar_acordes'): mod.ajustar_acordes(ACORDES)
        M = mod.melodias(); SUFIJO = '_' + getattr(mod, 'SUFIJO', modulo)
    else:
        M = melodias()
    partes = {'gancho': M['gancho'], 'tema_c': M['tema_c'], 'puente': M['puente'], 'tema_a': M['tema_a'],
              'voz': voz_partes(M['gancho'] + M['tema_c'] + M['puente']), 'chops': voz_chops(M['gancho'] + M['tema_c'] + M['puente']), 'bajo': bajo_partes(), 'chip': arpegios_chip(), 'skank': skank_c(),
              'pizz': pizz_partes(), 'pluck': pluck_partes(),
              'armonia': armonia_tercera([n for n in M['gancho'] if 107 <= n[0] // 16 + 1 <= 114]),
              'golpes_mini': golpes_mini()}
    avisos, choques = comprobar(partes)
    print(f'comprobación: {len(avisos) - min(choques, 25)} notas largas fuera del acorde, {choques} choques')
    for a in avisos: print('  ', a)
    if informe: return

    ir = reverb_ir()
    bat = bateria()
    kicks = [p for p, n, v in bat if n == K]
    duck = ducking(kicks)
    print('render…')
    y_bajo = estereo(pista(partes['bajo'], v_bajo))
    y_chip = estereo(pista(partes['chip'], v_chip), -0.35)
    y_skank = estereo(pista(partes['skank'], v_chip, duty=0.125), 0.35)
    y_pluck = estereo(pista(partes['pluck'], v_pluck), 0.3)
    y_bell = estereo(pista(partes['puente'], v_campana), -0.1)
    y_voz = estereo(pista([n for n in partes['voz'] if n[2] % 2 == 0], v_voz), -0.3) + \
            estereo(pista([n for n in partes['voz'] if n[2] % 2 == 1], v_voz), 0.3)
    y_chops = estereo(pista(partes['chops'], v_voz), 0.1)
    y_tema_a = estereo(pista(partes['tema_a'], v_chip, larga=True), 0.0)
    gancho = partes['gancho']
    y_gancho = estereo(pista(gancho, v_lead))
    oct2 = [(p, d, m + 12, int(v * 0.7)) for p, d, m, v in gancho if p // 16 + 1 >= 99]
    y_gancho8 = estereo(pista(oct2, v_chip, duty=0.25, larga=True), 0.2)
    y_arm = estereo(pista(partes['armonia'], v_lead), -0.25)
    y_c = estereo(pista(partes['tema_c'], v_lead))
    c2 = [n for n in partes['tema_c'] if n[0] // 16 + 1 >= 83]
    y_c8 = estereo(pista([(p, d, m + 12, int(v * 0.65)) for p, d, m, v in c2], v_chip, duty=0.5, larga=True), -0.2)
    y_cpl = estereo(pista(c2, v_pluck), 0.25)
    pizz = fluid(partes['pizz'], 45)
    drums = {}
    for nom, notas in (('bombo', [K]), ('caja', [SN, RIM, CL]), ('charles', [CH, OH, SH]), ('platos', [CR]),
                       ('toms', [T1, T2, T3, T4])):
        drums[nom] = fluid([(p, 1, n, v) for p, n, v in bat if n in notas], 16, drums=True)

    # niveles (dB) por capa
    LV = {'bajo': -4, 'chip': -17, 'skank': -19, 'pluck': -15, 'bell': -7, 'voz': -17, 'chops': -6, 'tema_a': -8, 'gancho': -6.5,
          'gancho8': -15, 'arm': -12, 'c': -6.5, 'c8': -16, 'cpl': -17, 'pizz': -6, 'bombo': 0, 'caja': -2,
          'charles': -16, 'platos': -8, 'toms': -4}
    db = lambda k: 10 ** (LV[k] / 20)
    secos = {
        'bajo': y_bajo * (0.6 + 0.4 * duck), 'chip': y_chip * duck, 'skank': y_skank * duck, 'pluck': y_pluck * duck,
        'bell': y_bell, 'voz': y_voz * duck, 'chops': y_chops, 'tema_a': y_tema_a, 'gancho': y_gancho, 'gancho8': y_gancho8,
        'arm': y_arm, 'c': y_c, 'c8': y_c8, 'cpl': y_cpl, 'pizz': pizz * duck, **drums}
    # normaliza cada capa por su propio pico de RMS (500 ms) antes del nivel: así LV es comparable
    def norm(x):
        w = int(0.5 * SR); c = np.concatenate([[0], np.cumsum(np.mean(x ** 2, 1))]); e = np.sqrt(np.maximum(c[w:] - c[:-w], 0) / w)
        return x / (e.max() + 1e-9) * 0.25
    capas = {k: norm(v) * db(k) for k, v in secos.items()}
    capas['charles'] = sg.sosfilt(sg.butter(2, 11000 / (SR / 2), output='sos'), capas['charles'], axis=0)
    envio = {'bell': 0.35, 'voz': 0.3, 'chops': 0.2, 'tema_a': 0.18, 'gancho': 0.2, 'gancho8': 0.25, 'arm': 0.25, 'c': 0.18,
             'c8': 0.25, 'pluck': 0.25, 'cpl': 0.2, 'caja': 0.12, 'pizz': 0.15, 'skank': 0.15, 'toms': 0.1}
    capas['gancho'] = eco(capas['gancho'], 3, 0.3, 0.16)
    capas['c'] = eco(capas['c'], 3, 0.3, 0.14)
    capas['tema_a'] = eco(capas['tema_a'], 3, 0.3, 0.2)
    if capas_dir:
        os.makedirs(capas_dir, exist_ok=True)
        for k, v in capas.items(): sf.write(os.path.join(capas_dir, k + '.wav'), v[:int((NBARS * BAR + 1) * SR)], SR, subtype='FLOAT')
    MINI[:] = partes['golpes_mini']
    print('golpes sueltos:', len(MINI), [f'c{p // 16 + 1}:{p % 16}' for p, d, m, j in MINI])
    for nombre, quitar, lufs in (('cae_por_el_equipo' + SUFIJO, (), -10.5),
                                 ('cae_por_el_equipo' + SUFIJO + '_sin_melodia', MELODICAS, -11.0)):
        mezcla(nombre, {k: v for k, v in capas.items() if k not in quitar}, envio, ir, lufs)
    exportar_mid(partes, bat)


MINI = []


def mezcla(nombre, capas, envio, ir, lufs):
    musica = sum(capas.values())
    musica += reverb(sum(capas[k] * g for k, g in envio.items() if k in capas), ir) * 0.5

    # silencio propio bajo los golpes (salvo la anacrusa del bajo) y bajo el efecto (salvo el bajo)
    sin_bajo = musica - capas['bajo']
    mutear(sin_bajo, [b for b in GOLPES] + [b + 1 for b in GOLPES])
    mutear(sin_bajo, EFECTO, 2)
    bajo_m = capas['bajo'].copy()
    for b in GOLPES:
        a = int((b - 1) * BAR * SR); e = int(((b) * 16 + 14) * SX * SR)
        bajo_m[a:e] = 0
    musica = sin_bajo + bajo_m

    # muestras literales, igualadas en nivel al groove propio
    ref = rms(musica[tramo(3, 9)])
    for b, nom in GOLPES.items():
        x, _ = sf.read(os.path.join(MUESTRAS, nom + '.wav'))
        g = ref * 10 ** (-1 / 20) / rms(x[:int(2 * BAR * SR)])
        i = int(((b - 1) * BAR - 0.02) * SR); o = max(0, -i); i = max(0, i); e = min(NTOT, i + len(x) - o)
        musica[i:e] += x[o:o + e - i] * g
    ga, _ = sf.read(os.path.join(MUESTRAS, 'golpes_a.wav'))
    gmini = ref * 10 ** (-3 / 20) / rms(ga[:int(2 * BAR * SR)])
    for p, d, m, j in MINI:
        a0 = int((0.02 + 6 * j * SX) * SR); L = int(d * SX * SR); cola = int(0.10 * SR)
        x = ga[a0:a0 + L + cola].copy()
        x[:int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))[:, None]
        x[L:] *= np.linspace(1, 0, len(x) - L)[:, None]
        i = int(p * SX * SR); e = min(NTOT, i + len(x))
        musica[i:e] += x[:e - i] * gmini
    fx, _ = sf.read(os.path.join(MUESTRAS, 'efecto.wav'))
    ref_sb = rms(sin_bajo[tramo(3, 9)])
    gfx = ref_sb * 10 ** (1 / 20) / rms(fx[:int(14 * SX * SR)])
    for b in EFECTO:
        i = int((((b - 1) * 16 + 2) * SX - 0.015) * SR); e = min(NTOT, i + len(fx))
        musica[i:e] += fx[:e - i] * gfx

    # fundido de salida (141 → 147) y cola
    t = np.arange(NTOT) / SR
    a, e = 140 * BAR, 146 * BAR
    gdb = np.where(t < a, 0, np.where(t < e, -26 * (t - a) / (e - a), -26 - 20 * (t - e) / (2 * BAR)))
    musica *= (10 ** (gdb / 20))[:, None]
    musica = musica[:int((NBARS * BAR + 0.8) * SR)]
    musica[-int(0.8 * SR):] *= np.linspace(1, 0, int(0.8 * SR))[:, None]

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import famicom as F
    musica = F.biquad(musica, 'peak', 450, -2.5, 0.8)            # medios: el original es menos espeso en 320-640 Hz
    musica = F.biquad(musica, 'peak', 1800, 1.5, 0.9)            # presencia del solista
    musica = F.biquad(musica, 'peak', 900, -1.5, 1.0)
    musica = F.master(musica, lufs=lufs, ceiling=0.8)
    os.makedirs(SALIDA, exist_ok=True)
    wav = os.path.join(SALIDA, nombre + '.wav')
    sf.write(wav, musica, SR, subtype='PCM_16')
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6',
                    wav.replace('.wav', '.ogg')], check=True)
    # niveles por sección (para comparar con el original)
    print('duración', round(len(musica) / SR, 2), 's')
    for nom, (b0, b1) in {'golpes': (1, 2), 'groove': (3, 18), 'puente': (19, 32), 'grooveA': (43, 50),
                          'estribillo1': (51, 64), 'C': (67, 98), 'estribillo2': (99, 128), 'salida': (131, 140)}.items():
        print(f'  {nom:12s} {20 * np.log10(rms(musica[tramo(b0, b1)])):6.1f} dB')
    return musica


def exportar_mid(partes, bat):
    import mido
    T = 480
    mf = mido.MidiFile(type=1, ticks_per_beat=T)
    t0 = mido.MidiTrack(); mf.tracks.append(t0)
    t0.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / BPM)))
    t0.append(mido.MetaMessage('key_signature', key='Bb'))
    for ci, k in enumerate(['gancho', 'tema_c', 'puente', 'tema_a', 'voz', 'chops', 'bajo', 'chip', 'skank', 'pizz', 'pluck', 'armonia']):
        tr = mido.MidiTrack(); mf.tracks.append(tr); tr.append(mido.MetaMessage('track_name', name=k))
        ch = ci if ci < 9 else ci + 1
        ev = []
        for p, d, n, v in partes[k]:
            ev += [(p * T // 4, 1, n, v), (p * T // 4 + d * T // 4 - 4, 0, n, 0)]
        t = 0
        for tt, on, n, v in sorted(ev, key=lambda e: (e[0], e[1])):
            tr.append(mido.Message('note_on' if on else 'note_off', channel=ch, note=n, velocity=v, time=tt - t)); t = tt
    tr = mido.MidiTrack(); mf.tracks.append(tr); tr.append(mido.MetaMessage('track_name', name='bateria'))
    ev = []
    for p, n, v in bat:
        ev += [(p * T // 4, 1, n, v), (p * T // 4 + T // 8, 0, n, 0)]
    t = 0
    for tt, on, n, v in sorted(ev, key=lambda e: (e[0], e[1])):
        tr.append(mido.Message('note_on' if on else 'note_off', channel=9, note=n, velocity=v, time=tt - t)); t = tt
    mf.save(os.path.join(SALIDA, 'cae_por_el_equipo' + SUFIJO + '.mid'))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--cortar', action='store_true')
    ap.add_argument('--stems')
    ap.add_argument('--informe', action='store_true')
    ap.add_argument('--capas', action='store_true', help='escribe cada capa en SALIDA/capas/')
    ap.add_argument('--melodia', help='módulo de melodías alternativo (tools/music/<módulo>.py)')
    a = ap.parse_args()
    if a.cortar: cortar(a.stems)
    else: construir(a.informe, os.path.join(SALIDA, 'capas') if a.capas else None, a.melodia)
