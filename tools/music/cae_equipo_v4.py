#!/usr/bin/env python3
# tools/music/cae_equipo_v4.py — "Cae por el equipo" v4: la canción REHECHA DESDE CERO sobre la misma forma.
#
# Lo único que se conserva de cae_equipo.py es (1) la forma y los tiempos (185, Si♭ mayor, 148 compases, las
# mismas secciones) y (2) las MUESTRAS literales con su código tal cual (golpes, efecto, golpes sueltos, el sinte
# vocal en todas sus notas): se importan de allí sin cambiar su comportamiento. Armonía de detalle, bajo, batería,
# acompañamiento, timbres, melodías, arreglo y mezcla son nuevos.
#
# LA IDEA: "el traspié" — un bordado (la nota, la vecina, la nota) que coge impulso y SALTA a una nota larga a
# contratiempo; el compás siguiente cae por grados. Pop de concurso saltarín: bajo que rebota en octavas, marimba
# en hemiola (3+3+3+3+4), acordes cortos a contratiempo, y un solista "vocal" (sierras por un filtro de formantes
# "a") que empasta con el sinte vocal muestreado.
#
#   ~/.venvs/fm-music/bin/python tools/music/cae_equipo_v4.py              compone, mezcla, exporta y comprueba
#   ... --informe                                                           solo las comprobaciones de notas
import os, sys, json, argparse, subprocess, tempfile, glob
import numpy as np
import soundfile as sf
from scipy import signal as sg

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cae_equipo as C
from cae_equipo import (SR, BPM, SX, BAR, NBARS, MUESTRAS, SALIDA, ORIG_T0, FUENTE, nt, hz, fr, acorde, seccion,
                        GOLPES, EFECTO, GIRO, svf_lp, saw, pulse, env_adsr, vib, v_voz, estereo, rms, tramo, mutear,
                        tonos, NTOT)

SUFIJO = '_v4'
RNG = np.random.default_rng(41)


# ── ARMONÍA (propia; los compases de las muestras siguen en Si♭ y la vuelta del efecto intacta) ─────────────
VUELTA = [(0, 'Bb7'), (6, 'Ab'), (12, 'Gm'), (14, 'Fsus4')]          # la del efecto: La♭ → Sol → Fa sobre Si♭
GROOVE8 = ['Bb', 'Eb/Bb', 'Bb', 'Eb/Bb', 'Gm7', 'Cm7', [(0, 'Ebmaj7'), (8, 'F')], VUELTA]
PUENTE = ['Ebmaj7', 'F7/Eb', 'Dm7', 'Gm7', 'Cm7', [(0, 'Cm7/Bb'), (8, 'F/A')], 'Bb', [(0, 'Eb/G'), (8, 'F/A')],
          'Ebmaj7', 'F7/Eb', 'Dm7', 'Gm7', [(0, 'Cm7'), (8, 'Ebm')], [(0, 'F7sus4'), (8, 'F7')]]
CICLO = ['Bb', 'Dm7', 'Ebmaj7', 'F', 'Gm7', 'Ebmaj7', 'Cm7', [(0, 'F7sus4'), (8, 'F7')]]
FINAL1 = ['Bb', 'Dm7', 'Ebmaj7', 'F', 'Cm7', [(0, 'F7sus4'), (8, 'F7')]]
FINAL2 = ['Bb', 'Dm7', 'Ebmaj7', 'F', [(0, 'Cm7'), (8, 'Ebm')], [(0, 'F7sus4'), (8, 'F7')]]   # el giro oscuro (iv menor)
SC1 = ['Gm7', 'Ebmaj7', 'Bb', 'F', 'Gm7', 'Ebmaj7', 'Cm7', [(0, 'F7sus4'), (8, 'F7')]]
SC2 = ['Gm7', 'Ebmaj7', 'Bb/D', 'Ebmaj7', 'Cm7', 'Dm7', 'Ebmaj7', [(0, 'F7sus4'), (8, 'F7')]]


def acordes4():
    A = {}
    for b0 in (3, 11, 35, 43, 131, 139):
        for i, c in enumerate(GROOVE8): A[b0 + i] = c
    for b in (1, 2, 33, 34, 65, 66, 129, 130): A[b] = 'Bb'
    for i, c in enumerate(PUENTE): A[19 + i] = c
    for i, c in enumerate(CICLO + FINAL1): A[51 + i] = c
    for i, c in enumerate(CICLO * 3 + FINAL2): A[99 + i] = c
    for i, c in enumerate(SC1 + SC2 + SC1 + SC2): A[67 + i] = c
    A[147] = 'Ebmaj7'; A[148] = 'Bb'
    out = {b: ([(0, c)] if isinstance(c, str) else c) for b, c in A.items()}
    for b in EFECTO: assert out[b] == VUELTA, b                        # la muestra del efecto lleva esta vuelta
    return out


# el código de las muestras (voz_chops, golpes_mini) lee los acordes de cae_equipo: se le dan los nuevos
C.ACORDES.clear(); C.ACORDES.update(acordes4())
ACORDES = C.ACORDES
acorde_en = C.acorde_en


def segmentos(b):
    """[(inicio16, fin16, símbolo)] de un compás"""
    ch = ACORDES[b]
    return [(st, ch[i + 1][0] if i + 1 < len(ch) else 16, s) for i, (st, s) in enumerate(ch)]


def triada(sym, lo, hi):
    return tonos(sym, lo, hi, True)


# ── MELODÍAS ──────────────────────────────────────────────────────────────────────────────────────────
# Vecinas "seguras" (a tono entero de todos los tonos del acorde) cuando duran una corchea; las demás, semicorchea.
# TEMA A (groove 43-50 y 139-146): el traspié en pequeño, picado, juguetón
TEMA_A = ['0:D5/2 2:C5/2 4:D5/2 6:F5/2 8:Bb5/3 11:A5/1 12:Bb5/4',          # Si♭
          '2:G5/2 4:Eb5/2 6:F5/1 7:G5/3 10:Bb5/6',                           # Mi♭/Si♭
          '0:D5/2 2:C5/2 4:D5/2 6:F5/2 8:D6/3 11:C6/1 12:D6/4',              # Si♭: el salto más grande
          '2:Eb6/2 4:Bb5/2 6:G5/2 8:Bb5/2 10:G5/2 12:Eb5/4',                 # Mi♭/Si♭: rebota hacia abajo
          '0:F5/2 2:E5/1 3:F5/3 6:G5/2 8:Bb5/3 11:A5/1 12:G5/4',             # Sol m7
          '2:G5/2 4:Eb5/2 6:F5/1 7:G5/3 10:C6/6',                            # Do m7
          '0:Bb5/3 3:G5/3 6:Bb5/2 8:A5/3 11:C6/3 14:A5/2',                   # Mi♭maj7 | Fa
          '0:F5/2 2:D5/2 4:F5/2 6:Eb5/3 9:C5/3 12:D5/2 14:C5/2']             # la vuelta La♭ – Sol m – Fa sus
TEMA_A_SALIDA = TEMA_A[:7] + ['0:F5/2']                                     # c146: el efecto desde la semicorchea 2

# ESTRIBILLO: el traspié entero (Si♭ · Re m7 · Mi♭maj7 · Fa · Sol m7 · Mi♭maj7 · Do m7 · Fa7sus4 Fa7)
H = ['0:F5/2 2:G5/2 4:F5/3 7:Bb5/3 10:D6/6',              # bordado, salto, Re largo a contratiempo
     '0:C6/2 2:D6/2 4:C6/3 7:A5/3 10:F5/6',               # el mismo gesto, cayendo
     '0:G5/2 2:F5/2 4:G5/3 7:Bb5/3 10:Eb6/6',             # sube a la tónica del acorde
     '0:C6/3 3:Bb5/1 4:A5/2 6:G5/2 8:A5/8',               # rueda por grados
     '0:Bb5/2 2:C6/2 4:Bb5/3 7:D6/3 10:F6/6',             # el traspié una tercera arriba: la cima
     '0:Eb6/2 2:F6/2 4:Eb6/3 7:D6/3 10:Bb5/6',
     '0:C6/3 3:Bb5/3 6:G5/2 8:Eb5/2 10:F5/2 12:G5/4',
     '0:Bb5/6 6:C6/2 8:A5/6 14:G5/2']                     # el retardo Si♭ → La; Sol lleva al Fa del principio
FIN1 = H[:3] + ['0:A5/3 3:C6/3 6:D6/2 8:C6/8',
                '0:Eb6/3 3:D6/1 4:C6/2 6:Bb5/2 8:G5/8',
                '0:Bb5/4 4:C6/4 8:A5/6']
LLAMADA = '0:F5/2 2:Bb5/2 4:D6/2 6:F6/10'                 # LA LLAMADA (5-1-3-5) sobre Si♭, una sola vez (c123)
FIN2 = [LLAMADA] + H[1:3] + ['0:A5/3 3:C6/3 6:D6/2 8:C6/8',
                             '0:Eb6/3 3:D6/1 4:C6/2 6:Bb5/2 8:Bb5/4 12:Gb5/4',   # Do m7 | Mi♭m: el giro oscuro
                             '0:Bb5/4 4:C6/4 8:A5/6']

# SECCIÓN C: el contraste — notas largas que cantan sobre la marimba en hemiola (Sol m7 · Mi♭ · Si♭ · Fa …)
C1 = ['2:D6/4 6:C6/2 8:Bb5/3 11:G5/5',
      '2:Eb6/4 6:D6/2 8:Bb5/3 11:G5/5',
      '0:F5/3 3:G5/1 4:F5/4 8:Bb5/3 11:D6/5',
      '2:C6/4 6:Bb5/1 7:C6/1 8:A5/8',
      '2:D6/4 6:C6/2 8:Bb5/3 11:G5/5',
      '2:Bb5/4 6:C6/2 8:D6/2 10:Eb6/6',
      '0:Eb6/3 3:D6/1 4:C6/4 8:G5/3 11:Bb5/5',
      '2:Bb5/4 6:C6/2 8:A5/8']
C2 = ['2:D6/4 6:C6/2 8:D6/3 11:F6/5',                    # Sol m7: más arriba
      '2:Eb6/4 6:D6/2 8:Bb5/8',
      '2:D6/4 6:C6/2 8:Bb5/3 11:F5/5',
      '2:G5/4 6:F5/2 8:Eb5/8',
      '0:Eb5/2 2:F5/2 4:G5/4 8:C6/8',
      '2:D6/4 6:C6/2 8:A5/8',
      '2:Bb5/4 6:C6/2 8:D6/3 11:Bb5/5',
      '2:Bb5/4 6:C6/2 8:A5/3 11:C6/5']
C2_FIN = C2[:7] + ['2:Bb5/4 6:C6/2 8:A5/4']             # c98: respira antes del estribillo

# PUENTE: la campana, notas guía largas bajo los cortes de la voz
CAMPANA = ['0:D6/14 14:C6/2', '0:C6/8 8:A5/8', '0:A5/8 8:F5/4 12:A5/4', '0:Bb5/12 12:D6/4',
           '0:Eb6/8 8:C6/8', '0:Bb5/8 8:A5/8', '0:Bb5/6 6:C6/2 8:D6/8', '0:Eb6/8 8:C6/8',
           '0:D6/8 8:Bb5/8', '0:C6/6 6:Eb6/2 8:C6/4 12:A5/4', '0:A5/6 6:C6/2 8:D6/8', '0:D6/6 6:F6/2 8:D6/4 12:Bb5/4',
           '0:C6/8 8:Bb5/8', '0:Bb5/8 8:A5/8']


def frases(lista, bar0, vel=100):
    out = []
    for i, t in enumerate(lista): out += fr(t, bar0 + i, vel)
    return out


def melodias():
    M = {}
    M['tema_a'] = frases(TEMA_A, 43, 96) + frases(TEMA_A_SALIDA, 139, 80)
    M['campana'] = frases(CAMPANA, 19, 90)
    M['gancho'] = frases(H + FIN1, 51) + frases(H * 3, 99) + frases(FIN2, 123)
    M['tema_c'] = frases(C1 + C2, 67, 98) + frases(C1 + C2_FIN, 83, 100)
    return M


# ── PARTES GENERADAS DESDE LOS ACORDES ──────────────────────────────────────────────────────────────────
def bajo_nota(sym):
    _, _, bp = acorde(sym)
    return [m for m in range(34, 46) if m % 12 == bp][0]


def bajo():
    out = []
    GR = [(0, 3, 0), (3, 1, 12), (4, 2, 0), (6, 2, 12), (8, 3, 0), (11, 1, 12), (12, 2, 7), (14, 2, 12)]   # rebota
    ES = [(h, 2, 0 if h % 4 == 0 else 12) for h in range(0, 16, 2)]                                        # bombea
    SCC = [(0, 3, 0), (3, 3, 0), (6, 2, 12), (8, 3, 0), (11, 3, 7), (14, 2, 12)]                           # tresillo
    for b in range(1, NBARS + 1):
        s = seccion(b)
        if b in GIRO:                                    # la vuelta del efecto, como la tiene la muestra
            out += fr('0:Bb1/2 2:Bb2/2 4:Bb2/2 6:Ab1/2 8:Ab2/3 12:G1/2 14:F1/2', b, 108)
            continue
        pat = {'groove': GR, 'estribillo': ES, 'C': SCC}.get(s)
        if not pat: continue
        for st, en, sym in segmentos(b):
            R = bajo_nota(sym); pcs = acorde(sym)[1]
            if en - st <= 8 and s != 'groove':           # medio compás: negras nota-octava
                for h in range(st, en, 4):
                    out += [((b - 1) * 16 + h, 2, R, 108), ((b - 1) * 16 + h + 2, 2, R + 12, 96)]
                continue
            for h, d, iv in pat:
                if st <= h < en:
                    n = R + iv
                    if n % 12 not in pcs: n = R + 12
                    out.append(((b - 1) * 16 + h, min(d, en - h), n, 112 if h % 4 == 0 else 98))
    for b in (2, 34, 130):                               # anacrusa hacia el groove (bajo los golpes sí suena)
        out += fr('14:Bb1/2', b, 100)
    out += [((147 - 1) * 16, 16, nt('Eb1') + 12, 90), ((148 - 1) * 16, 16, nt('Bb1'), 90)]
    return out


def acordes_cortos():
    """acordes cortos a contratiempo (tríadas, Sol4-Sol5): el 'skank' saltarín del groove, el estribillo y C"""
    out = []
    for b in range(1, NBARS + 1):
        s = seccion(b)
        if s not in ('groove', 'estribillo', 'C') or b == 50: continue
        hs = {'groove': (2, 6, 10, 14) if not 3 <= b <= 10 else (6, 14), 'estribillo': (2, 6, 10, 14),
              'C': (2, 6, 10, 14)}[s]
        for h in hs:
            if b in EFECTO and h >= 2: continue
            sym = acorde_en((b - 1) * 16 + h)
            for m in triada(sym, 64, 76)[:3]: out.append(((b - 1) * 16 + h, 1, m, 78 if h % 4 == 2 else 70))
    return out


def colchon():
    """colchón de sierras (tríadas) en el puente, los estribillos, C y la cola; se corta en cada cambio de acorde"""
    out = []
    for b in range(1, NBARS + 1):
        s = seccion(b)
        if s not in ('puente', 'estribillo', 'C', 'cola'): continue
        for st, en, sym in segmentos(b):
            for m in triada(sym, 55, 67): out.append(((b - 1) * 16 + st, en - st, m, 70 if s == 'C' else 80))
    return out


def marimba():
    """la marimba: en el groove un ostinato de un compás; en el puente y C, arpegios en hemiola 3+3+3+3+4"""
    out = []
    for b in range(1, NBARS + 1):
        s = seccion(b)
        if s == 'groove' and (11 <= b <= 18 or 35 <= b <= 50 or 131 <= b <= 146) and b != 50:
            hs = [(0, 0), (3, 2), (6, 1), (8, 2), (10, 0), (12, 1), (14, 2)]
        elif s == 'puente' or (s == 'C'):
            hs = [(0, 0), (3, 1), (6, 2), (9, 3), (12, 2)]
        else: continue
        for h, k in hs:
            if b in EFECTO and h >= 2: continue
            p = (b - 1) * 16 + h; sym = acorde_en(p)
            t = triada(sym, 67, 84)
            cambio = min([st for st, _ in ACORDES[b] if st > h] + [16])
            d = min(3 if s != 'groove' else 2, cambio - h)
            out.append((p, d, t[min(k, len(t) - 1)], 92 if h in (0, 6, 12) else 76))
    return out


def burbujas():
    """arpegio de semicorcheas (pluck FM) en el estribillo 2 y en C': sube y baja por la tríada"""
    out = []
    ord_ = [0, 1, 2, 3, 2, 1, 2, 3]
    for b in list(range(83, 99)) + list(range(107, 129)):
        for h in range(16):
            p = (b - 1) * 16 + h; sym = acorde_en(p)
            t = triada(sym, 72, 88)
            if b == 98 and h >= 12: continue
            out.append((p, 1, t[ord_[h % 8] % len(t)], 84 if h % 4 == 0 else 62))
    return out


def armonia(mel, b0, b1):
    """2ª voz del estribillo (tercera / sexta por debajo, siempre tono del acorde)"""
    out = []
    for p, d, m, v in mel:
        if not b0 <= p // 16 + 1 <= b1: continue
        pcs = acorde(acorde_en(p))[1][:3]
        cand = [x for x in range(m - 9, m - 2) if x % 12 in pcs]
        if cand and d >= 2: out.append((p, d, max(cand), int(v * 0.75)))
    return out


def voz(melodia):
    """EL SINTE VOCAL MUESTREADO: cada nota del original (voz_notas.json) con su inicio, duración y dinámica (el
    mismo recorrido que cae_equipo.voz_chops); la altura es el tono de MI acorde más cercano al original que no roce
    con lo que suena encima. Nunca se pierde una nota: si todo roza, el tono más cercano igualmente."""
    R = json.load(open(os.path.join(MUESTRAS, 'voz_ritmo.json')))
    N = json.load(open(os.path.join(MUESTRAS, 'voz_notas.json')))
    out = []
    def encima(p0, p1): return [m for p, d, m, v in melodia if p < p1 and p + d > p0 and d >= 2]
    unidas = []
    for k, d, p in N:
        if unidas and seccion(k // 16 + 1) == 'C' and unidas[-1][2] == p and unidas[-1][0] + unidas[-1][1] == k:
            unidas[-1][1] += d
        else:
            unidas.append([k, d, p])
    for k, d, p in unidas:
        b = k // 16 + 1
        if b > NBARS or seccion(b) in ('golpes', 'cola'): continue
        lv = R[str(b)][0]
        if lv < -55: continue
        if b in EFECTO and k % 16 >= 2: continue
        if b in (3, 35, 131) and k % 16 < 6: continue
        vel = int(np.clip(100 + 1.5 * (lv + 28), 48, 118))
        pos, fin = k, k + d
        while pos < fin:
            bb, h = pos // 16 + 1, pos % 16
            if bb > NBARS or seccion(bb) in ('golpes', 'cola') or (bb in EFECTO and h >= 2): break
            cambio = (bb - 1) * 16 + min([st for st, _ in ACORDES[bb] if st > h] + [16])
            e = min(fin, cambio)
            sym = acorde_en(pos)
            todos = triada(sym, 43, 68)
            ts = [m for m in todos if not any((x - m) % 12 in (1, 11, 6) for x in encima(pos, e))] or todos
            m = min(ts, key=lambda t: (abs(t - p), t))
            out.append((pos, e - pos, m, vel if pos == k else int(vel * 0.85)))
            pos = e
    return out


def voz_esperadas():
    """los tramos (inicio, duración) que manda el código de las muestras de cae_equipo (voz_chops): la voz propia
    tiene que tenerlos TODOS, con el mismo inicio y la misma duración"""
    return sorted((p, d) for p, d, m, v in C.voz_chops([]))


# ── BATERÍA (sintetizada: electrónica, como la de las muestras) ────────────────────────────────────────
def bateria():
    ev = []
    def at(b, h, n, v): ev.append(((b - 1) * 16 + h, n, v))
    for b in range(1, NBARS + 1):
        s = seccion(b); k = b % 2
        if s == 'groove':
            if b in EFECTO: at(b, 0, 'bombo', 112); at(b, 0, 'charles', 80); continue
            if b == 50: continue                                     # el parón
            kicks = [0, 6, 10] if k else [0, 3, 6, 10]
            if b in GIRO: kicks = [0, 6]
            for h in kicks: at(b, h, 'bombo', 112)
            at(b, 8, 'caja', 110); at(b, 8, 'palmas', 90); at(b, 14, 'caja', 46)
            for h in range(0, 16, 2): at(b, h, 'abierto' if h == 14 else 'charles', 84 if h % 4 == 2 else 58)
            if b >= 11:
                for h in range(1, 16, 2): at(b, h, 'shaker', 44)
        elif s == 'puente':
            for h in (0, 2, 10): at(b, h, 'bombo', 44)
            at(b, 8, 'palmas', 70)
            for h in range(16): at(b, h, 'shaker', 30 if h % 4 == 2 else 18)
            if b >= 27:
                for h in range(2, 16, 4): at(b, h, 'charles', 60)
            if b == 32:
                for h, n in zip((8, 10, 12, 14), ('tom1', 'tom1', 'tom2', 'tom3')): at(b, h, n, 80 + h)
        elif s == 'estribillo':
            fuerte = b >= 99
            kicks = [0, 6, 10] if k else [0, 2, 8, 10]
            for h in kicks: at(b, h, 'bombo', 116)
            for h in (4, 12): at(b, h, 'caja', 112); at(b, h, 'palmas', 96)
            at(b, 15, 'caja', 40)
            for h in range(0, 16, 2): at(b, h, 'abierto' if h % 4 == 2 and fuerte else 'charles', (62 if fuerte else 86) if h % 4 == 2 else 62)
            if b >= 115:
                for h in range(1, 16, 2): at(b, h, 'shaker', 46)
            if b in (51, 59, 99, 107, 115, 123) or (fuerte and b % 4 == 3): at(b, 0, 'plato', 100 if b in (51, 99) else 80)
            if b in (58, 106, 114, 122):
                for h, n in zip((12, 13, 14, 15), ('tom1', 'tom2', 'tom2', 'tom3')): at(b, h, n, 96)
            if b in (64, 128):
                for h in (8, 10, 12, 13, 14, 15): at(b, h, 'caja', 70 + h * 3)
        elif s == 'C':
            kicks = [0, 3, 8, 14] if k else [0, 3, 8, 11]
            for h in kicks: at(b, h, 'bombo', 112)
            at(b, 4, 'palmas', 80); at(b, 12, 'caja', 110); at(b, 12, 'palmas', 92)
            for h in range(2, 16, 4): at(b, h, 'abierto' if b >= 83 else 'charles', 76)
            for h in range(0, 16, 4): at(b, h, 'charles', 54)
            if b >= 83:
                for h in range(1, 16, 2): at(b, h, 'shaker', 44)
            if b in (67, 75, 83, 91): at(b, 0, 'plato', 92)
            if b == 97:
                for h in range(0, 16, 2): at(b, h, 'caja', 60 + h * 2)
            if b == 98:
                for h in range(16): at(b, h, 'caja', 62 + h * 3)
            if b in (74, 82, 90):
                for h, n in zip((12, 13, 14, 15), ('tom1', 'tom2', 'tom2', 'tom3')): at(b, h, n, 92)
        if b in (3, 35, 131): at(b, 0, 'plato', 100)
        if b in (11, 43, 139): at(b, 0, 'plato', 84)
        if b == 19: at(b, 0, 'plato', 70)
    return ev


def ruido(n, seed):
    return np.random.default_rng(seed).standard_normal(n)


def hp(x, f, o=2): return sg.sosfilt(sg.butter(o, f / (SR / 2), 'high', output='sos'), x)
def lp(x, f, o=2): return sg.sosfilt(sg.butter(o, f / (SR / 2), output='sos'), x)
def bp(x, a, b, o=2): return sg.sosfilt(sg.butter(o, [a / (SR / 2), b / (SR / 2)], 'band', output='sos'), x)


def fin_suave(y, ms=4):
    k = min(len(y), int(ms * SR / 1000)); y[-k:] *= np.linspace(1, 0, k); return y


def golpe_bateria(tipo):
    t = lambda s: np.arange(int(s * SR)) / SR
    if tipo == 'bombo':
        tt = t(0.42); f = 48 + 110 * np.exp(-tt / 0.028)
        y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.26)
        y += 0.35 * hp(ruido(len(tt), 1), 2500) * np.exp(-tt / 0.004)
        y = np.tanh(1.8 * y)
    elif tipo == 'caja':
        tt = t(0.3)
        y = 0.7 * np.sin(2 * np.pi * np.cumsum(185 + 60 * np.exp(-tt / 0.01)) / SR) * np.exp(-tt / 0.055)
        y += 0.8 * bp(ruido(len(tt), 2), 1200, 9000) * np.exp(-tt / 0.11)
    elif tipo == 'palmas':
        tt = t(0.3); y = np.zeros(len(tt)); nz = bp(ruido(len(tt), 3), 1000, 6000)
        for k, o in enumerate((0, 0.009, 0.019)):
            e = np.where(tt >= o, np.exp(-(tt - o) / (0.007 if k < 2 else 0.09)), 0); y += nz * e
    elif tipo in ('charles', 'abierto'):
        tt = t(0.06 if tipo == 'charles' else 0.3)
        y = hp(ruido(len(tt), 4), 7500, 4) * np.exp(-tt / (0.018 if tipo == 'charles' else 0.12))
    elif tipo == 'shaker':
        tt = t(0.08)
        y = bp(ruido(len(tt), 5), 5000, 11000) * np.minimum(tt / 0.006, 1) * np.exp(-tt / 0.03)
    elif tipo == 'plato':
        tt = t(1.8)
        y = hp(ruido(len(tt), 6), 4500, 2) * np.exp(-tt / 0.7) * (0.6 + 0.4 * np.exp(-tt / 0.05))
    else:                                                      # toms
        f0 = {'tom1': 210, 'tom2': 160, 'tom3': 120}[tipo]; tt = t(0.9)
        y = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.5 * np.exp(-tt / 0.03))) / SR) * np.exp(-tt / 0.16)
    y = np.asarray(y, float)
    a = int((0.002 if tipo.startswith('tom') else 0.0008) * SR)
    y[:a] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    return fin_suave(y / (np.abs(y).max() + 1e-9))


def pista_bateria(ev, tipos):
    y = np.zeros(NTOT)
    cache = {k: golpe_bateria(k) for k in tipos}
    for p, n, v in ev:
        if n not in tipos: continue
        s = cache[n] * (v / 127); i = int(round(p * SX * SR)); e = min(NTOT, i + len(s)); y[i:e] += s[:e - i]
    return y


def subida(bares):
    """ruido que sube (barrido) hacia una entrada fuerte"""
    y = np.zeros(NTOT)
    for b, h0 in bares:
        i = int(((b - 1) * 16 + h0) * SX * SR); e = int(b * BAR * SR); n = e - i
        tt = np.linspace(0, 1, n)
        x = ruido(n, b) ; fc = 600 + 9000 * tt ** 2
        z = svf_lp(x, fc, 0.6) * tt ** 2.2
        y[i:e] += fin_suave(z / (np.abs(z).max() + 1e-9), 20)
    return y


# ── TIMBRES ──────────────────────────────────────────────────────────────────────────────────────────
def _env(n, dur, a, d, s, r):
    e = env_adsr(n, dur, a, d, s, r); return fin_suave(e, 3)


def formantes(x, f=(730, 1090, 2440), g=(1.0, 0.6, 0.35), q=6.0):
    """filtro de formantes "a": lo que hace que el solista suene a voz y empaste con el sinte vocal"""
    y = np.zeros_like(x)
    for fc, gg in zip(f, g):
        b, a = sg.iirpeak(fc / (SR / 2), q); y += gg * sg.lfilter(b, a, x)
    return y


def v_solista(m, d, v):
    f = hz(m); dur = d * SX; n = int((dur + 0.10) * SR); t = np.arange(n) / SR
    fv = vib(n, f, 14, 5.6, 0.16) * (1 + 0.012 * np.exp(-t / 0.012))          # un pellizco de afinación al atacar
    x = 0.5 * saw(fv * 2 ** (7 / 1200)) + 0.5 * saw(fv * 2 ** (-7 / 1200)) + 0.4 * pulse(fv, 0.32)
    seco = svf_lp(x, 1800 + 3200 * np.exp(-t / 0.09) + 18 * v, 0.8)
    y = 0.55 * seco + 0.9 * formantes(x)
    return y * _env(n, dur - 0.004, 0.004, 0.35, 0.8, 0.05) * (v / 127) * 0.5


def v_octava(m, d, v):
    """el doble a la octava: pulso fino, sin formantes"""
    f = hz(m); dur = d * SX; n = int((dur + 0.06) * SR)
    x = pulse(vib(n, f, 10, 5.6, 0.16), 0.25)
    return x * _env(n, dur, 0.003, 0.25, 0.6, 0.04) * (v / 127) * 0.4


def v_marimba(m, d, v):
    f = hz(m); n = int(min(d * SX + 0.4, 0.9) * SR); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * f * t + 0.8 * np.exp(-t / 0.012) * np.sin(2 * np.pi * 3.93 * f * t)) * np.exp(-t / 0.22)
    y += 0.25 * np.sin(2 * np.pi * 3.93 * f * t) * np.exp(-t / 0.035)
    y *= np.minimum(t / 0.0015, 1)
    return fin_suave(y) * (v / 127) * 0.6


def v_campana(m, d, v):
    f = hz(m); dur = d * SX; n = int((dur + 0.7) * SR); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * f * t + (1.6 * np.exp(-t / 0.15) + 0.2) * np.sin(2 * np.pi * 3 * f * t)) * np.exp(-t / 0.9)
    y *= np.minimum(t / 0.003, 1) * np.where(t < dur + 0.15, 1, np.exp(-(t - dur - 0.15) / 0.12))
    return fin_suave(y) * (v / 127) * 0.5


def v_burbuja(m, d, v):
    f = hz(m); n = int(0.22 * SR); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * f * t + 1.4 * np.exp(-t / 0.03) * np.sin(2 * np.pi * 2 * f * t)) * np.exp(-t / 0.07)
    y *= np.minimum(t / 0.0015, 1)
    return fin_suave(y) * (v / 127) * 0.5


def v_corto(m, d, v):
    """acorde corto a contratiempo: sierra con filtro que se cierra deprisa"""
    f = hz(m); n = int(0.16 * SR); t = np.arange(n) / SR
    x = 0.5 * saw(np.full(n, f * 2 ** (5 / 1200))) + 0.5 * saw(np.full(n, f * 2 ** (-5 / 1200)))
    y = svf_lp(x, 700 + 4200 * np.exp(-t / 0.035), 0.9) * np.minimum(t / 0.002, 1) * np.exp(-t / 0.06)
    return fin_suave(y) * (v / 127) * 0.5


def v_colchon(m, d, v):
    f = hz(m); dur = d * SX; n = int((dur + 0.12) * SR); t = np.arange(n) / SR
    x = sum(saw(np.full(n, f * 2 ** (c / 1200))) for c in (-14, -6, 0, 7, 15)) / 5
    y = svf_lp(x, np.full(n, 1700.0), 0.5)
    return y * _env(n, dur - 0.01, 0.03, 0.4, 0.85, 0.09) * (v / 127) * 0.5


def v_bajo4(m, d, v):
    f = hz(m); dur = d * SX; n = int((dur + 0.05) * SR); t = np.arange(n) / SR
    x = 0.55 * pulse(np.full(n, f), 0.5) + 0.35 * saw(np.full(n, f * 1.003))
    y = svf_lp(x, 220 + (900 + 1200 * v / 127) * np.exp(-t / 0.05), 0.75) + 0.8 * np.sin(2 * np.pi * f * t)
    y = np.tanh(1.4 * y)
    return y * _env(n, dur - 0.008, 0.002, 0.2, 0.8, 0.02) * (v / 127) * 0.6


# ── RENDER ──────────────────────────────────────────────────────────────────────────────────────────
def pista(notas, voz_, **kw):
    y = np.zeros(NTOT)
    for p, d, m, v in notas:
        s = voz_(m, d, v, **kw); i = int(round(p * SX * SR)); e = min(NTOT, i + len(s)); y[i:e] += s[:e - i]
    return y


def reverb_ir(seg=1.0):
    n = int(seg * SR); t = np.arange(n) / SR
    ir = RNG.standard_normal((n, 2)) * np.exp(-t / 0.28)[:, None]
    ir = sg.sosfilt(sg.butter(2, 5500 / (SR / 2), output='sos'), ir, axis=0)
    ir[:int(0.015 * SR)] = 0
    return ir / np.sqrt(np.sum(ir ** 2) / 2)


def reverb(x, ir):
    return np.stack([sg.fftconvolve(x[:, c], ir[:, c])[:len(x)] for c in range(2)], 1)


def eco(x, delay16=3, fb=0.3, mix=0.2):
    d = int(delay16 * SX * SR); y = x.copy(); g = mix
    for k in range(1, 4):
        s = np.zeros_like(x); s[d * k:] = x[:-d * k] * g
        if k % 2: s = s[:, ::-1]
        y += s; g *= fb
    return y


def ducking(kicks, prof=0.5, rel=0.11):
    """sidechain: baja colchón, bajo y acordes en cada bombo (bajada de 3 ms: sin chasquido)"""
    g = np.ones(NTOT); t = np.arange(int(0.4 * SR)) / SR
    curva = 1 - prof * np.minimum(t / 0.003, 1) * np.exp(-np.maximum(t - 0.003, 0) / rel)
    for p in kicks:
        i = int(p * SX * SR); e = min(NTOT, i + len(curva)); g[i:e] = np.minimum(g[i:e], curva[:e - i])
    return g[:, None]


# ── COMPROBACIONES ──────────────────────────────────────────────────────────────────────────────────────
MELODIAS = ('gancho', 'tema_c', 'tema_a', 'campana')


def comprobar(partes):
    """sobre TODAS las partes con altura (también la voz y los golpes sueltos): notas largas fuera del acorde y
    choques 2ª m / 7ª M / tritono de una corchea o más (salvo entre tonos del acorde, y la 2ª m nunca)"""
    avisos = []; largas = 0
    for nombre in partes:
        for p, d, m, v in partes[nombre]:
            if nombre == 'bajo' and (p // 16 + 1) in GIRO: continue          # la vuelta del efecto: la de la muestra
            q = p
            while q < p + d:                                              # tramo a tramo, por cada acorde que pisa
                b = q // 16 + 1
                if b > NBARS: break
                sym = acorde_en(q); r, pcs, _ = acorde(sym)
                if 'maj7' in sym and nombre in MELODIAS: pcs = pcs + [(r + 2) % 12]
                fin = min(p + d, (b - 1) * 16 + min([st for st, _ in ACORDES[b] if st > q % 16] + [16]))
                dd = fin - q
                if m % 12 not in pcs and (dd >= 3 or (q % 4 == 0 and dd >= 2) or
                                          (nombre not in MELODIAS and nombre != 'golpes_sueltos' and dd >= 2)):
                    largas += 1; avisos.append(f'fuera del acorde {nombre} c{b}:{q % 16} {m} {sym} ({dd}/16)')
                q = fin
    voces = [(k, n) for k in partes for n in partes[k]]
    cub = {}
    for i, (k, n) in enumerate(voces):
        for h in range(n[0], n[0] + n[1]): cub.setdefault(h, []).append(i)
    vistos = set(); choques = 0
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
                if fin - ini >= 2 and iv in (1, 11, 6) and abs(a[2] - b[2]) < 24:
                    sym = acorde_en(ini); r, pcs, _ = acorde(sym)
                    if 'maj7' in sym: pcs = pcs + [(r + 2) % 12]
                    if iv != 1 and a[2] % 12 in pcs and b[2] % 12 in pcs: continue
                    choques += 1
                    if choques <= 30: avisos.append(f'choque {ka}/{kb} c{ini // 16 + 1}:{ini % 16} {a[2]}-{b[2]} {sym}')
    return avisos, largas, choques


def metricas(N):
    N = sorted(N)
    ct = 0
    for p, d, m, v in N:
        sym = acorde_en(p); r, pcs, _ = acorde(sym)
        if 'maj7' in sym: pcs = pcs + [(r + 2) % 12]
        ct += m % 12 in pcs
    iv = [b[2] - a[2] for a, b in zip(N, N[1:]) if b[0] - a[0] <= 16]
    return dict(n=len(N), acorde=ct / len(N), grado=np.mean([1 <= abs(i) <= 2 for i in iv]),
                rep=np.mean([i == 0 for i in iv]), salto=np.mean([abs(i) >= 5 for i in iv]),
                larga=np.mean([n[1] >= 4 for n in N]), contra=np.mean([n[0] % 4 != 0 for n in N]))


def partes_todas():
    M = melodias()
    P = dict(M)
    P['bajo'] = bajo(); P['cortos'] = acordes_cortos(); P['colchon'] = colchon(); P['marimba'] = marimba()
    P['burbujas'] = burbujas()
    P['armonia'] = armonia(M['gancho'], 107, 122)
    mel = M['gancho'] + M['tema_c'] + M['campana'] + M['tema_a']
    P['voz'] = voz(mel)
    P['golpes_sueltos'] = [(p, d, m, 100) for p, d, m, j in C.golpes_mini()]
    return P


# ── MEZCLA (las muestras: el mismo código que cae_equipo.mezcla) ─────────────────────────────────────────
def poner_muestras(musica, sin_bajo, mini):
    ref = rms(musica[tramo(3, 9)])
    for b, nom in GOLPES.items():
        x, _ = sf.read(os.path.join(MUESTRAS, nom + '.wav'))
        g = ref * 10 ** (-1 / 20) / rms(x[:int(2 * BAR * SR)])
        i = int(((b - 1) * BAR - 0.02) * SR); o = max(0, -i); i = max(0, i); e = min(NTOT, i + len(x) - o)
        musica[i:e] += x[o:o + e - i] * g
    ga, _ = sf.read(os.path.join(MUESTRAS, 'golpes_a.wav'))
    gmini = ref * 10 ** (-3 / 20) / rms(ga[:int(2 * BAR * SR)])
    for p, d, m, j in mini:
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
    return musica


SECCIONES = {'groove': (3, 18), 'puente': (19, 32), 'groove2': (35, 50), 'estribillo1': (51, 64), 'C': (67, 98),
             'estribillo2': (99, 128), 'salida': (131, 140)}
BANDAS = [63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]


def original():
    with tempfile.TemporaryDirectory() as dd:
        w = os.path.join(dd, 'o.wav')
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', glob.glob(os.path.join(FUENTE, '*.m4a'))[0],
                        '-ar', str(SR), w], check=True)
        y, _ = sf.read(w)
    i = int(ORIG_T0 * SR)
    return y[i:]


def perfil(x):
    """nivel por octava (dB) de un tramo"""
    X = np.abs(np.fft.rfft(x.mean(1) * np.hanning(len(x)))) ** 2; f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.array([10 * np.log10(X[(f >= c / np.sqrt(2)) & (f < c * np.sqrt(2))].sum() + 1e-12) for c in BANDAS])


def eq_octavas(x, ganancias):
    import famicom as F
    for c, g in zip(BANDAS, ganancias):
        if abs(g) > 0.2 and c < 16000: x = F.biquad(x, 'peak', c, float(g), 1.0)
        elif abs(g) > 0.2: x = F.biquad(x, 'high', 12000, float(g))
    return x


def mezclar(capas, envio, ir, mini, lufs, auto=None, eq_puente=None):
    """suma, reverb, silencio bajo las muestras, muestras, automatización por sección, fundido, EQ y master"""
    import famicom as F
    musica = sum(capas.values())
    musica = musica + reverb(sum(capas[k] * g for k, g in envio.items() if k in capas), ir) * 0.5
    sin_bajo = musica - capas['bajo']
    mutear(sin_bajo, [b for b in GOLPES] + [b + 1 for b in GOLPES])
    mutear(sin_bajo, EFECTO, 2)
    bajo_m = capas['bajo'].copy()
    for b in GOLPES:
        a = int((b - 1) * BAR * SR); e = int(((b) * 16 + 14) * SX * SR); bajo_m[a:e] = 0
    musica = sin_bajo + bajo_m
    if auto is not None: musica = musica * auto[:, None]           # nivel por sección (antes de las muestras)
    if eq_puente is not None:              # el puente con su propia ecualización (entra y sale en un compás)
        w = np.zeros(NTOT); w[tramo(19, 32)] = 1
        k = int(BAR * SR); c = np.concatenate([[0], np.cumsum(w)]); ws = w.copy()
        ws[k // 2:len(w) - k // 2] = (c[k:] - c[:-k])[:len(w) - k] / k
        musica = musica * (1 - ws[:, None]) + eq_octavas(musica, eq_puente) * ws[:, None]
    musica = poner_muestras(musica, sin_bajo * (auto[:, None] if auto is not None else 1), mini)
    t = np.arange(NTOT) / SR
    a, e = 140 * BAR, 146 * BAR
    gdb = np.where(t < a, 0, np.where(t < e, -14 * (t - a) / (e - a), -14 - 26 * (t - e) / (2 * BAR)))   # como el original
    musica *= (10 ** (gdb / 20))[:, None]
    musica = musica[:int((NBARS * BAR + 0.8) * SR)]
    musica[-int(0.8 * SR):] *= np.linspace(1, 0, int(0.8 * SR))[:, None]
    return musica


def automatizacion(musica_seca, ref):
    """ganancia por sección para que el reparto de niveles entre secciones sea el del original (rampa de 1 compás)"""
    g = np.ones(NTOT)
    tot_m = rms(musica_seca[tramo(3, 128)]); tot_o = rms(ref[tramo(3, 128)])
    puntos = []
    for nom, (b0, b1) in SECCIONES.items():
        dm = 20 * np.log10(rms(musica_seca[tramo(b0, b1)]) / tot_m); do = 20 * np.log10(rms(ref[tramo(b0, b1)]) / tot_o)
        puntos.append((b0, b1, float(np.clip(do - dm, -6, 6))))
    for b0, b1, gdb in puntos:
        g[tramo(b0, b1)] = 10 ** (gdb / 20)
    # huecos (golpes, cola) heredan el valor siguiente; luego rampa de un compás
    w = int(BAR * SR); c = np.concatenate([[0], np.cumsum(g)])
    gs = g.copy(); gs[w // 2:-w // 2] = (c[w:] - c[:-w])[:len(gs) - w] / w
    return gs, puntos


def construir(informe=False):
    P = partes_todas()
    avisos, largas, choques = comprobar(P)
    print(f'comprobación: {largas} notas largas fuera del acorde, {choques} choques')
    for a in avisos: print('  ', a)
    esp = voz_esperadas(); mia = sorted((p, d) for p, d, m, v in P['voz'])
    det = json.load(open(os.path.join(MUESTRAS, 'golpes_mini_detect.json')))
    candidatos = [x for x in det if x[0] >= C.MINI_DESDE and seccion(x[0]) not in ('golpes', 'cola') and x[0] not in EFECTO]
    print(f"voz: {len(mia)} tramos, iguales a los de cae_equipo.voz_chops: {mia == esp} ({len(esp)}); "
          f"golpes sueltos: {len(P['golpes_sueltos'])} de {len(candidatos)} posiciones")
    callar = [(k, p) for k in MELODIAS + ('armonia', 'marimba', 'cortos', 'colchon', 'burbujas')
              for p, d, m, v in P[k] for q in range(p, p + d)
              if seccion(q // 16 + 1) == 'golpes' or (q // 16 + 1 in EFECTO and q % 16 >= 2)]
    print(f"notas propias bajo los golpes o el efecto: {len(callar)}")
    for k in MELODIAS:
        m = metricas(P[k])
        print(f"  {k:8s} n={m['n']:3d} acorde {m['acorde']:.0%} grados {m['grado']:.0%} repetidas {m['rep']:.0%} "
              f"saltos≥4ª {m['salto']:.0%} largas {m['larga']:.0%} contratiempo {m['contra']:.0%}")
    if informe: return
    import time; t0 = time.time()
    bat = bateria()
    kicks = [p for p, n, v in bat if n == 'bombo']
    duck = ducking(kicks)
    oct8 = [(p, d, m + 12, int(v * 0.7)) for p, d, m, v in P['gancho'] if p // 16 + 1 >= 99]
    c8 = [(p, d, m + 12, int(v * 0.65)) for p, d, m, v in P['tema_c'] if p // 16 + 1 >= 83]
    secos = {
        'bajo': estereo(pista(P['bajo'], v_bajo4)) * (0.55 + 0.45 * duck),
        'cortos': estereo(pista(P['cortos'], v_corto), 0.3) * duck,
        'colchon': estereo(pista(P['colchon'], v_colchon), -0.2) * duck,
        'marimba': estereo(pista(P['marimba'], v_marimba), -0.35),
        'burbujas': estereo(pista(P['burbujas'], v_burbuja), 0.4) * duck,
        'voz': estereo(pista(P['voz'], lambda m, d, v: fin_suave(v_voz(m, d, v), 6)), 0.1),
        'gancho': estereo(pista(P['gancho'], v_solista)),
        'gancho8': estereo(pista(oct8, v_octava), 0.25),
        'armonia': estereo(pista(P['armonia'], v_solista), -0.3),
        'tema_c': estereo(pista(P['tema_c'], v_solista)),
        'c8': estereo(pista(c8, v_octava), -0.25),
        'tema_a': estereo(pista(P['tema_a'], v_solista)),
        'campana': estereo(pista(P['campana'], v_campana), 0.15),
        'subida': estereo(subida([(50, 6), (98, 0), (32, 8)])),
    }
    for nom, tipos, pan in (('bombo', ['bombo'], 0), ('caja', ['caja', 'palmas'], 0.05),
                            ('charles', ['charles', 'abierto', 'shaker'], 0.3), ('platos', ['plato'], -0.2),
                            ('toms', ['tom1', 'tom2', 'tom3'], -0.1)):
        secos[nom] = estereo(pista_bateria(bat, tipos), pan)
    print(f'síntesis {time.time() - t0:.1f} s')

    def norm(x):
        w = int(0.5 * SR); c = np.concatenate([[0], np.cumsum(np.mean(x ** 2, 1))]); e = np.sqrt(np.maximum(c[w:] - c[:-w], 0) / w)
        return x / (e.max() + 1e-9) * 0.25
    LV = {'bajo': -3.5, 'cortos': -14, 'colchon': -15, 'marimba': -12, 'burbujas': -19, 'voz': -6, 'gancho': -6,
          'gancho8': -17, 'armonia': -13, 'tema_c': -6.5, 'c8': -18, 'tema_a': -8, 'campana': -9, 'subida': -16,
          'bombo': 0, 'caja': -3, 'charles': -15, 'platos': -12, 'toms': -6}
    capas = {k: norm(v) * 10 ** (LV[k] / 20) for k, v in secos.items()}
    for k in ('gancho', 'tema_c', 'tema_a'): capas[k] = eco(capas[k], 3, 0.3, 0.16)
    envio = {'campana': 0.4, 'voz': 0.25, 'gancho': 0.2, 'gancho8': 0.25, 'armonia': 0.25, 'tema_c': 0.2, 'c8': 0.25,
             'tema_a': 0.15, 'colchon': 0.3, 'marimba': 0.2, 'burbujas': 0.25, 'caja': 0.12, 'toms': 0.1, 'cortos': 0.1}
    ir = reverb_ir()
    mini = C.golpes_mini()
    ref = original()
    ref = np.concatenate([ref, np.zeros((max(0, NTOT - len(ref)), 2))])[:NTOT]

    # 1ª pasada: niveles por sección y perfil de octavas frente al original → automatización y EQ correctora
    prueba = mezclar(capas, envio, ir, mini, -10.5)
    prueba = np.concatenate([prueba, np.zeros((NTOT - len(prueba), 2))])
    auto, puntos = automatizacion(prueba, ref)
    print('automatización por sección (dB):', ', '.join(f'{b0}-{b1} {g:+.1f}' for b0, b1, g in puntos))
    def rel(x): pp = perfil(x); return pp - pp[2:7].mean()
    dif = np.mean([rel(ref[tramo(b0, b1)]) - rel(prueba[tramo(b0, b1)])
                   for nom, (b0, b1) in SECCIONES.items() if nom != 'puente'], 0)      # el puente lleva su filtro
    eq = np.clip(dif, -6, 6)
    eqp = np.clip(rel(ref[tramo(19, 32)]) - rel(prueba[tramo(19, 32)]) - eq, -8, 8)
    print('EQ propia del puente (dB):', ' '.join(f'{c}:{g:+.1f}' for c, g in zip(BANDAS, eqp)))
    print('EQ correctora por octava (dB):', ' '.join(f'{c}:{g:+.1f}' for c, g in zip(BANDAS, eq)))

    import famicom as F
    # 2ª pasada: lo mismo ya con EQ y master (el limitador cambia el reparto)
    y = F.master(eq_octavas(mezclar(capas, envio, ir, mini, -10.5, auto, eqp), eq), lufs=-10.5, ceiling=0.8)
    y = np.concatenate([y, np.zeros((NTOT - len(y), 2))])
    auto2, puntos = automatizacion(y, ref)
    auto = auto * auto2
    print('ajuste fino por sección (dB):', ', '.join(f'{b0}-{b1} {g:+.1f}' for b0, b1, g in puntos))
    for nombre, quitar, lufs in (('cae_por_el_equipo' + SUFIJO, (), -10.5),
                                 ('cae_por_el_equipo' + SUFIJO + '_sin_melodia',
                                  ('gancho', 'gancho8', 'armonia', 'tema_c', 'c8', 'tema_a', 'campana'), -11.0)):
        y = mezclar({k: v for k, v in capas.items() if k not in quitar}, envio, ir, mini, lufs, auto, eqp)
        y = eq_octavas(y, eq)
        y = F.master(y, lufs=lufs, ceiling=0.8)
        wav = os.path.join(SALIDA, nombre + '.wav'); os.makedirs(SALIDA, exist_ok=True)
        sf.write(wav, y, SR, subtype='PCM_16')
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6',
                        wav.replace('.wav', '.ogg')], check=True)
        if not quitar: final = y
    print(f'render total {time.time() - t0:.1f} s')
    exportar_mid(P, bat)
    verificar(final, ref, capas)
    tramos(final)


def verificar(y, ref, capas):
    import pyloudnorm as pyln
    print('── verificación de la mezcla')
    print(f'  LUFS {pyln.Meter(SR).integrated_loudness(y):.2f}  pico {np.abs(y).max():.3f}  duración {len(y) / SR:.1f} s')
    yy = np.concatenate([y, np.zeros((NTOT - len(y), 2))])
    sec_o = {k: 20 * np.log10(rms(ref[tramo(*v)])) for k, v in SECCIONES.items()}
    sec_m = {k: 20 * np.log10(rms(yy[tramo(*v)])) for k, v in SECCIONES.items()}
    lo = pyln.Meter(SR).integrated_loudness(ref[:len(y)])
    off = -10.5 - lo
    print('  sección        mía    original (a −10.5 LUFS)   máx. desvío por octava')
    for k, (b0, b1) in SECCIONES.items():
        pm = perfil(yy[tramo(b0, b1)]); po = perfil(ref[tramo(b0, b1)])
        d = (pm - pm[2:7].mean()) - (po - po[2:7].mean())
        print(f'  {k:12s} {sec_m[k]:6.1f}  {sec_o[k] + off:6.1f}      {np.abs(d[:8]).max():4.1f} dB  ' +
              ' '.join(f'{c}:{x:+.1f}' for c, x in zip(BANDAS, d)))
    # posición de las muestras: correlación cruzada contra el original (envolvente de ataques, ±40 ms)
    print('  cola por compás (mía / original):', ' '.join(
        f'{b}:{20 * np.log10(rms(yy[tramo(b, b)])):.0f}/{20 * np.log10(rms(ref[tramo(b, b)])) + off:.0f}' for b in range(139, 149)))
    print('  muestras (desfase frente al original):')
    def env(x):
        e = np.abs(np.diff(x.mean(1))); w = 32; c = np.concatenate([[0], np.cumsum(e)]); return c[w:] - c[:-w]
    z = np.zeros((int(0.04 * SR), 2)); ym = np.concatenate([z, yy]); rf = np.concatenate([z, ref])
    for b, nom in list(GOLPES.items()) + [(b, 'efecto') for b in EFECTO]:
        h0 = 0 if nom != 'efecto' else 2
        L = int(0.04 * SR); a = int(((b - 1) * 16 + h0) * SX * SR) + L; e = a + int(1.0 * SR)
        m_ = env(ym[a - L:e + L]); o_ = env(rf[a - L:e + L])
        cc = sg.correlate(m_ - m_.mean(), o_[L:-L] - o_[L:-L].mean(), 'valid')
        lag = (np.argmax(cc) - L) / SR * 1000
        print(f'    c{b:3d} {nom:9s} {lag:+5.1f} ms')
    # chasquidos: picos de la 2ª diferencia frente a su valor eficaz local (10 ms); un salto o esquina en una señal
    # suave da un factor enorme, el ruido y los ataques normales quedan por debajo de ~8
    def chasquidos(x, umbral=12.0):
        d2 = np.diff(x, 2); w = 441; c = np.concatenate([[0], np.cumsum(d2 ** 2)])
        loc = np.sqrt(np.maximum(c[w:] - c[:-w], 0) / w) + 1e-7 + 1e-4 * np.abs(d2).max()
        f = np.abs(d2[w // 2:w // 2 + len(loc)]) / loc
        return int((f > umbral).sum()), float(f.max())
    res = []
    for k, x in list(capas.items()) + [('MEZCLA FINAL', yy)]:
        n, fm = chasquidos(x[:, 0]); res.append(f'{k} {n} ({fm:.1f})')
    print('  chasquidos por capa (puntos > 12, factor máximo):', ', '.join(res))
    # entradas de sección: salto de nivel entre el compás anterior y el siguiente, y el mayor salto de 20 ms
    print('  entradas (dB compás antes → después; mayor salto de envolvente de 20 ms en ±1 compás frente a un tiempo fuerte típico):')
    env20 = lambda x: 20 * np.log10(np.sqrt(np.mean(x.reshape(-1, int(0.02 * SR), 2) ** 2, (1, 2))) + 1e-6)
    tip = []
    for b in range(4, 9):
        a = int(((b - 1) * BAR - 0.1) * SR); e = a + int(0.2 * SR); e = a + (e - a) // int(0.02 * SR) * int(0.02 * SR)
        v = env20(yy[a:e]); tip.append(np.max(np.diff(v)))
    tip = float(np.median(tip))
    for b in (3, 19, 33, 35, 43, 51, 65, 67, 83, 99, 129, 131, 141, 147):
        r0 = 20 * np.log10(rms(yy[tramo(b - 1, b - 1)])); r1 = 20 * np.log10(rms(yy[tramo(b, b)]))
        a = int((b - 1.5) * BAR * SR); n = int(BAR * SR) // int(0.02 * SR) * int(0.02 * SR)
        v = env20(yy[a:a + n]); vo = env20(ref[a:a + n])
        o0 = 20 * np.log10(rms(ref[tramo(b - 1, b - 1)])) + off; o1 = 20 * np.log10(rms(ref[tramo(b, b)])) + off
        print(f'    c{b:3d} {r0:6.1f} → {r1:6.1f} dB (original {o0:6.1f} → {o1:6.1f})   salto {np.max(np.diff(v)):4.1f} dB'
              f' (original {np.max(np.diff(vo)):4.1f}; tiempo fuerte típico {tip:.1f})')


def tramos(y):
    cambios = {'golpes_groove': 3, 'groove_puente': 19, 'puente_golpes': 33, 'golpes_groove2': 35, 'temaA': 43,
               'estribillo1': 51, 'golpes_C': 65, 'C_prima': 83, 'estribillo2': 99, 'golpes_salida': 129, 'cola': 145}
    for nom, b in cambios.items():
        a = int(max(0, (b - 5) * BAR) * SR); e = int(min(NBARS * BAR + 0.8, (b + 3) * BAR) * SR)
        sf.write(os.path.join(SALIDA, f'tramo_v4_{nom}.wav'), y[a:e], SR, subtype='PCM_16')
    sf.write(os.path.join(SALIDA, 'tramo_v4_1m25_2m10.wav'), y[int(85 * SR):int(130 * SR)], SR, subtype='PCM_16')


def exportar_mid(P, bat):
    import mido
    T = 480
    mf = mido.MidiFile(type=1, ticks_per_beat=T)
    t0 = mido.MidiTrack(); mf.tracks.append(t0)
    t0.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / BPM)))
    t0.append(mido.MetaMessage('key_signature', key='Bb'))
    for ci, k in enumerate(['gancho', 'tema_c', 'tema_a', 'campana', 'voz', 'bajo', 'cortos', 'colchon', 'marimba',
                            'burbujas', 'armonia', 'golpes_sueltos']):
        tr = mido.MidiTrack(); mf.tracks.append(tr); tr.append(mido.MetaMessage('track_name', name=k))
        ch = ci if ci < 9 else ci + 1
        ev = []
        for p, d, n, v in P[k]: ev += [(p * T // 4, 1, n, v), (p * T // 4 + d * T // 4 - 4, 0, n, 0)]
        t = 0
        for tt, on, n, v in sorted(ev, key=lambda e: (e[0], e[1])):
            tr.append(mido.Message('note_on' if on else 'note_off', channel=ch, note=n, velocity=v, time=tt - t)); t = tt
    GM = {'bombo': 36, 'caja': 38, 'palmas': 39, 'charles': 42, 'abierto': 46, 'shaker': 70, 'plato': 49,
          'tom1': 50, 'tom2': 47, 'tom3': 45}
    tr = mido.MidiTrack(); mf.tracks.append(tr); tr.append(mido.MetaMessage('track_name', name='bateria'))
    ev = []
    for p, n, v in bat: ev += [(p * T // 4, 1, GM[n], v), (p * T // 4 + T // 8, 0, GM[n], 0)]
    t = 0
    for tt, on, n, v in sorted(ev, key=lambda e: (e[0], e[1])):
        tr.append(mido.Message('note_on' if on else 'note_off', channel=9, note=n, velocity=v, time=tt - t)); t = tt
    mf.save(os.path.join(SALIDA, 'cae_por_el_equipo' + SUFIJO + '.mid'))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--informe', action='store_true')
    construir(ap.parse_args().informe)
