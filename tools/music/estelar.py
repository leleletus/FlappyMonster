#!/usr/bin/env python3
# tools/music/estelar.py — LA FAMILIA ESTELAR: las músicas de los niveles con BLOQUES BEEP (Vía Estelar / Starway,
# docs/design/beep-blocks.md). Cuatro pistas con el mismo reparto (flauta GM + glockenspiel GM sobre el chip: pulso
# del 2A03, N163, sierra del VRC6, triángulo, DPCM y ruido) y el MISMO CONTRATO DE TIEMPOS, cada una a su tempo:
#
#   via_estelar     "Vía Estelar" REMASTERIZADA (variante R; la A y la B siguen en via_estelar.py) — Re mayor, 120
#   estelar_pulsar  "Púlsar": el parkour rápido de la Vía Estelar — Si menor / Re mayor, 140
#   estelar_bonus   "Vía Estelar (bonus)": corto y juguetón, con su solo de percusión "estelar" — Sol mayor, 126
#   estelar_boss    "Vía Estelar (jefe)": tenso y heroico, en Re menor, bajo slap — 150
#
# CONTRATO (el juego depende de él; BeatClock.lua cuenta la posición de la MÚSICA):
#   · 4/4, BPM exactos con un número ENTERO de muestras por tiempo a 44 100 Hz (120 → 22 050, 126 → 21 000,
#     140 → 18 900, 150 → 17 640); un solo archivo `file` que se repite, SIN intro.
#   · Frase = 8 tiempos (= 2 compases) = un cambio de bloques. El nivel lleva "beat": {"period": 8 × 60 / BPM} s
#     (4 · 3,8095238 · 3,4285714 · 3,2). El JUEGO toca 3 pitidos en los tiempos 6, 7 y 8 y el cambio en el 1: el
#     archivo instalado NO lleva pitidos.
#   · Un GOLPE (bombo hondo + platillo corto) en el tiempo 1 de CADA frase, en todas las secciones.
#   · La melodía (y la contramelodía) no atacan en los tiempos 6-8: en el 2.º compás de la frase solo atacan dentro
#     del tiempo 5 (semicorcheas 0-3) y sostienen. Debajo siguen el arpegio, el bajo y la batería.
#   · La CAJA en los tiempos 2 y 4 de todos los compases (los pinchos de palmas salen con ella).
#   · Bucle sin costura: se tocan 3 copias seguidas y se queda la del medio.
#
# Lo que pidió el usuario (2026-11-15): el tema de la Vía Estelar es bueno pero, para un nivel largo, REPETITIVO Y
# ABURRIDO. Misma claridad (melodías ordenadas, consonantes, pregunta / respuesta que se repite: el usuario rechazó
# temas "desordenados, impredecibles"), pero con DESARROLLO: secciones que crecen, un estribillo nuevo que levanta, un
# corte (breakdown), una subida, un clímax (en el remaster, el estribillo un tono arriba), contramelodías y redobles
# distintos al entrar cada sección (timbales, parada, bombos, redoble). Todo atado a la rejilla.
#
#   ~/.venvs/fm-music/bin/python tools/music/estelar.py [via_estelar estelar_pulsar estelar_bonus estelar_boss]
#       → previas CON pitidos en FlappyMonster_pruebas/musica/via_estelar/<pista>/ (+ LEEME.txt con las secciones)
#   NOTAS=1   solo las comprobaciones de las notas (sin sonido: barato)
#   REPORT=1  números del render y del comprobador (no escribe nada)
#   INSTALL=1 además, la pista SIN pitidos → assets/music/worlds/via_estelar/<pista>.ogg + tools/music/mid/<pista>.mid
# Se comprueba con números (bloques_beep_check.py, en memoria y luego sobre el .wav); NO se ha escuchado.
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import famicom as F
from famicom import SR, Chan, Noise, play, q_n163, q_tri, q_vrc6
import tentacle_nes as TN
import gloomy_nes as GN
import worldmap_nes as W
import worlds_nes as WN
import montana_nes as MN
import gm as GM
import slap as SL
import bloques_beep_check as BC

AQUI = os.path.dirname(os.path.abspath(__file__))
ROOT_REPO = os.path.normpath(os.path.join(AQUI, '..', '..'))
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/via_estelar'
DST = os.path.join(ROOT_REPO, 'assets', 'music', 'worlds', 'via_estelar')
BEEP_WAV = os.path.join(ROOT_REPO, 'assets', 'sounds', 'mechanics', 'beep_warn.wav')
BEEP_TIEMPOS = (5, 6, 7)                 # tiempos 6, 7 y 8 de la frase (contando desde 0)
BEEP_GAN = 0.55                          # (solo la previa con pitidos)
COPIAS = 3
QUIET_DB = -4.0                          # las secciones tranquilas, respecto a la media de las demás (con pitidos)

PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
nm = lambda m: NAMES[m % 12] + str(m // 12 - 1)
QUAL = {'': (0, 4, 7), 'm': (0, 3, 7), '7': (0, 4, 7, 10), 'm7': (0, 3, 7, 10)}
MAYOR, MENOR = (0, 2, 4, 5, 7, 9, 11), (0, 2, 3, 5, 7, 8, 10)


def N(s):
    """'F#5' / 'Bb4' → nota MIDI"""
    alt = {'b': -1, '#': 1}.get(s[1], 0) if len(s) == 3 else 0
    return 12 * (int(s[-1]) + 1) + PC[s[0]] + alt


def acorde(c):
    """'D' / 'F#m' / 'A7' / 'Bb' → (clase de la raíz, intervalos)"""
    r = c[:2] if len(c) > 1 and c[1] in '#b' else c[:1]
    return (PC[r[0]] + {'#': 1, 'b': -1}.get(r[1:], 0)) % 12, QUAL[c[len(r):]]


def escala(tonica, modo):
    t = PC[tonica[0]] + {'#': 1, 'b': -1}.get(tonica[1:], 0)
    return {(t + i) % 12 for i in modo}


def sube(txt, k):
    """el mismo texto de notas, k semitonos arriba (el estribillo del clímax un tono arriba)"""
    out = []
    for x in txt.split():
        a, n, d = x.split(':')
        out.append(f'{a}:{nm(N(n) + k)}:{d}')
    return ' '.join(out)


# ── Figuras de compás ("semicorchea:nota:duración") ─────────────────────────────────────────────────────────────
H = lambda n: f'0:{n}:16'                                                  # la nota sostenida (tiempos 5-8)
T = lambda a, n: f'0:{a}:2 2:{n}:14'                                       # una corchea en el 5 y la nota sostenida
HK = lambda a, b, c, d, e: f'0:{a}:2 2:{b}:4 6:{c}:2 8:{d}:2 10:{e}:6'     # "ta-TAA ta-ta TAAA" (el estribillo)
PR = lambda a, b, c, p, q: f'0:{a}:2 2:{b}:2 4:{c}:6 10:{p}:2 12:{q}:4'    # sube por el acorde y se posa
TR = lambda a, b, c, d, e, f: f'0:{a}:3 3:{b}:3 6:{c}:2 8:{d}:2 10:{e}:2 12:{f}:4'   # 3+3+2 y dos corcheas
W4 = lambda a, b, c, d, e, f: f'0:{a}:2 2:{b}:2 4:{c}:4 8:{d}:2 10:{e}:2 12:{f}:4'   # "ta-ta TAA ta-ta TAA"
J = lambda a, b, c, d, e, f, g: f'0:{a}:2 2:{b}:1 3:{c}:3 6:{d}:2 8:{e}:2 10:{f}:2 12:{g}:4'   # salta (bonus)
DB = lambda a, b, c, d, e, f: f'0:{a}:3 3:{b}:1 4:{c}:4 8:{d}:2 10:{e}:2 12:{f}:4'  # con puntillo (jefe)


class Pista:
    def __init__(self, **kw):
        self.__dict__.update(kw)
        self.S16 = 60.0 / self.bpm / 4
        self.BAR = 16 * self.S16
        self.BAR_N = int(round(self.BAR * SR))
        assert abs(self.BAR * SR - self.BAR_N) < 1e-6 and self.BAR_N % 4 == 0, 'muestras por tiempo no enteras'
        self.NB = sum(n for _, n in self.secs)
        self.LOOP_N = self.NB * self.BAR_N
        assert len(self.acordes) == self.NB, (len(self.acordes), self.NB)
        self.sec_of, self.ini = {}, {}
        b0 = 0
        for s, n in self.secs:
            assert n % 2 == 0
            self.ini[s] = b0 + 1
            for b in range(b0 + 1, b0 + n + 1): self.sec_of[b] = s
            b0 += n
        self.mel = self._notas(self.melodia, pares=True)
        self.contra_n = self._notas(self.contra, pares=False)
        self.extra = []                                    # (b, st, n, d): los "pings" del solo (glockenspiel)

    def _notas(self, por_sec, pares):
        out = []
        for s, n in self.secs:
            if s not in por_sec: continue
            txts = [t for par in por_sec[s] for t in par] if pares else por_sec[s]
            assert len(txts) == n, f'{self.id} {s}: {len(txts)} compases de notas, la sección tiene {n}'
            for k, txt in enumerate(txts):
                b = self.ini[s] + k
                for x in txt.split():
                    a, nn, d = x.split(':')
                    out.append((b, int(a), N(nn), int(d), s))
        return out

    def A(self, b, k, d=None):
        return self.arr[self.sec_of[b]].get(k, d)

    def chord_at(self, b): return acorde(self.acordes[(b - 1) % self.NB])

    def ultimo(self, b):
        """¿último compás de su sección?"""
        s = self.sec_of[b]
        return b == self.ini[s] + dict(self.secs)[s] - 1

    def esc(self, b):
        r, q = self.chord_at(b)
        return self.escala[self.sec_of[b]] | {(r + i) % 12 for i in q}

    def tval(self, b, st, copia=0):
        return copia * self.NB * self.BAR + (b - 1) * self.BAR + st * self.S16


# ══ BAJO, ARPEGIO, OSTINATO, ACORDES ═══════════════════════════════════════════════════════════════════════════
def raiz_bajo(r): return 38 + (r - 38) % 12                                # Re2..Do#3


def parada(p, b):
    """el último compás de una sección con 'parada': todo calla en los tiempos 7-8 (menos la caja y la melodía)"""
    return p.ultimo(b) and p.A(b, 'fill') == 'parada'


def linea_bajo(p):
    out = []
    for b in range(1, p.NB + 1):
        r, q = p.chord_at(b)
        ra = raiz_bajo(r)
        pat = p.A(b, 'bajo', 'oct8')
        if pat == 'redonda': ev = [(0, ra, 16)]
        elif pat == 'blancas': ev = [(0, ra, 8), (8, ra + 7 if q[2] == 7 else ra, 8)]
        elif pat == 'oct8': ev = [(2 * k, ra + (0, 12)[k % 2], 2) for k in range(8)]
        elif pat == 'oct58': ev = [(2 * k, ra + (0, 12, 7, 12)[k % 4], 2) for k in range(8)]
        elif pat == 'galope': ev = [e for j in range(4) for e in ((4 * j, ra, 2), (4 * j + 2, ra, 1), (4 * j + 3, ra + 12, 1))]
        else: raise ValueError(pat)
        if parada(p, b): ev = [(st, n, min(d, 8 - st)) for st, n, d in ev if st < 8]
        out += [(b, st, n, d) for st, n, d in ev]
    return out


def arpegio(p):
    out = []
    for b in range(1, p.NB + 1):
        k = p.A(b, 'arp')
        if not k: continue
        r, q = p.chord_at(b)
        if k == 'sube':                                                   # 16 que suben (la subida); en el 2.º compás, una octava más
            base = 50 + (r - 50) % 12 + 12 * ((b - 1) % 2)
            cont = [0, q[1], q[2], 12]
            ev = [(st, base + cont[st % 4] + 12 * (st // 8), 1) for st in range(16)]
        else:
            base = 57 + (r - 57) % 12                                     # La3..Sol#4
            cont = [0, q[1], q[2], 12, 12 + q[1], 12, q[2], q[1]]
            paso = 2 if k == 'a8' else 1
            ev = [(i * paso, base + cont[i % 8], paso) for i in range(16 // paso)]
        if parada(p, b): ev = [e for e in ev if e[0] < 8]
        out += [(b, st, n, d) for st, n, d in ev]
    return out


def ostinato(p):
    """EL PÚLSAR: semicorcheas seguidas en una campana del N163, acentos 3+3+2 por el acorde, las demás (flojas) en
    la fundamental — el latido de la estrella. (b, st, nota, ganancia)"""
    out = []
    for b in range(1, p.NB + 1):
        g = p.A(b, 'ost')
        if not g: continue
        r, q = p.chord_at(b)
        r5 = 66 + (r - 66) % 12                                          # Fa#4..Fa5
        acc = dict(zip((0, 3, 6, 8, 11, 14), (r5 + 12, r5 + q[2], r5 + q[1] + 12, r5 + 12, r5 + q[2], r5 + q[1])))
        for st in range(16):
            if parada(p, b) and st >= 8: break
            out.append((b, st, acc.get(st, r5), g * (1.0 if st in acc else 0.45)))
    return out


def voces(r, q, base=55):
    return sorted(base + (r + iv - base) % 12 for iv in q[:3])


# ══ BATERÍA ═════════════════════════════════════════════════════════════════════════════════════════════════════
CRASH = [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 3, 2, 2, 1, 1]
HAT, SNARE_N, METAL = [5, 2, 1], [11, 8, 5, 3, 1], [7, 4, 2, 1]
FILLS = {'toms': [(8, 0), (10, 0), (12, 1), (13, 1), (14, 2), (15, 2)],
         'redoble': [(8, 0), (9, 0), (10, 0), (11, 1), (12, 1), (13, 1), (14, 2), (15, 2)]}


def bateria(p):
    """(segundo, tipo, ganancia) de un bucle. tipos: golpe, crash, kick, snare, hat, metal, tom0-2"""
    ev, p.extra = [], []
    for b in range(1, p.NB + 1):
        t0, s = (b - 1) * p.BAR, p.sec_of[b]
        est, fill = p.A(b, 'bat', 'recta'), (p.A(b, 'fill') if p.ultimo(b) else None)
        k_sec = b - p.ini[s]                                              # compás dentro de la sección (0..)
        mitad = k_sec >= dict(p.secs)[s] // 2
        golpe = (b - 1) % 2 == 0
        at = lambda st: t0 + st * p.S16
        e = []
        if golpe: e += [(0, 'golpe', 1.0), (0, 'crash', 1.0)]
        sn = 0.6 if est == 'media' else 1.0
        e += [(4, 'snare', sn), (12, 'snare', sn)]
        if est == 'solo':
            e += solo_estelar(p, b, k_sec + 1)
        else:
            if est == 'subida': est = 'motor' if mitad else 'recta'
            kicks = {'recta': [8], 'motor': [4, 8, 12], 'rock': [6, 8], 'media': [], 'jefe': [8, 11]}[est]
            if not golpe and est != 'media': kicks = [0] + kicks
            e += [(st, 'kick', 0.55 if st == 0 else 0.5) for st in kicks]
            if est == 'recta': e += [(st, 'hat', 1.0) for st in (2, 6, 10, 14)]
            elif est == 'media': e += [(st, 'hat', 0.6) for st in (2, 6, 10, 14)]
            elif est == 'rock': e += [(st, 'hat', 1.0 if st % 4 == 2 else 0.7) for st in range(0, 16, 2)]
            elif est == 'motor': e += [(st, 'hat', 1.15 if st % 4 == 2 else 0.6) for st in range(16) if st]
            elif est == 'jefe':
                e += [(st, 'hat', 0.6) for st in range(16) if st % 2]
                e += [(st, 'metal', 1.0) for st in (2, 6, 10, 14)]
            if est == 'motor' and p.A(b, 'bat') == 'subida' and p.ultimo(b):
                e += [(st, 'kick', 0.5) for st in (2, 6, 10, 14)]         # (la subida: el bombo a corcheas al final)
        if fill:
            e = [x for x in e if x[0] < 8 or x[1] == 'snare']
            if fill in FILLS: e += [(st, f'tom{k}', p.A(b, 'fill_g', 1.0)) for st, k in FILLS[fill]]
            elif fill == 'bombos': e += [(st, 'kick', 0.5) for st in (8, 10, 14)] + [(14, 'hat', 1.2)]
        # (ni charles ni "metal" EN el tiempo: es donde suenan los pitidos, y su ruido les ensucia los armónicos)
        e = [x for x in e if not (x[1] in ('hat', 'metal') and x[0] % 4 == 0)]
        ev +=[(at(st), k, g) for st, k, g in e]
    return ev


def solo_estelar(p, b, k):
    """SOLO DE PERCUSIÓN de la Vía Estelar (bonus; 8 compases = 4 frases): el CRISTAL (glockenspiel por el acorde)
    pregunta bajando en 3+3+2 y los TIMBALES contestan en 3+3+2; luego juntos, una carrera de timbales y el cristal
    que sube hacia la vuelta. El cristal suena en el 1.er compás de cada frase (o dentro del tiempo 5): nunca encima
    de los pitidos. La caja sigue en 2 y 4 y el golpe, en cada frase."""
    r, q = p.chord_at(b)
    c = [72 + (r - 72) % 12 + o + iv for o in (0, 12) for iv in q[:3]]   # 6 notas del acorde, desde Do5
    e = []
    if k in (1, 3):                                                      # el cristal pregunta
        for st, i in zip((0, 3, 6, 8, 11, 14), (5, 4, 3, 2, 1, 0) if k == 1 else (5, 3, 4, 2, 0, 1)):
            p.extra.append((b, st, c[i], 2))
        e += [(8, 'kick', 0.5)] + [(st, 'hat', 0.6) for st in range(1, 16, 2)]
    elif k in (2, 4):                                                    # los timbales contestan
        e += [(st, 'tom0' if st < 8 else 'tom1', 1.0) for st in (0, 3, 6)] + [(st, 'tom2', 1.0) for st in (8, 11, 14)]
        e += [(0, 'kick', 0.55)] + [(st, 'hat', 0.7) for st in (2, 6, 10, 14)]
    elif k in (5, 6):                                                    # juntos
        e += [(st, 'kick', 0.5) for st in (0, 8) if st or k == 6] + [(st, 'hat', 1.0 if st % 4 == 2 else 0.6) for st in range(1, 16)]
        e += [(st, f'tom{(st // 3) % 3}', 0.9) for st in (2, 3, 6, 9, 11, 14)]
        for st, i in (zip((0, 6, 12), (0, 2, 4)) if k == 5 else ((0, 5),)):
            p.extra.append((b, st, c[i], 3))
    elif k == 7:                                                         # la carrera de timbales
        e += [(st, f'tom{min(2, (st % 8) // 3)}', 0.85 + 0.15 * (st % 2 == 0)) for st in range(16) if st not in (4, 12)]
    else:                                                                # el cristal sube (en el tiempo 5) y vuelve el tema
        e += [(st, 'kick', 0.5) for st in (0, 4, 8, 12)] + [(st, 'hat', 0.8) for st in range(1, 16, 2)]
        for st in range(0, 4):
            p.extra.append((b, st, c[st + 2], 1))
        e += [(st, 'tom2', 0.9) for st in (12, 14)]
    return e


# ══ INSTRUMENTOS ═══════════════════════════════════════════════════════════════════════════════════════════════
I_LEAD = {'vol': [14, 15, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.2, 5.6), 'duty': [0.125, 0.125, 0.25, 0.25, 0.25, 0.5]}
I_SAW = {'vol': [10, 10, 9, 9, 8], 'sus': 8, 'vib': (14, 0.18, 5.6)}
I_N163 = {'vol': [6, 9, 10, 10, 9], 'sus': 9, 'vib': (16, 0.15, 5.2), 'duty': 3.0}
I_CONTRA = {'vol': [8, 10, 10, 9, 9, 8], 'sus': 8, 'vib': (18, 0.12, 5.0), 'duty': 3.0}
I_OST = {'vol': [12, 7, 4, 2, 1], 'sus': 0, 'duty': 0.0}
I_STAB = {'vol': [11, 8, 5, 3, 1], 'sus': 0, 'duty': 2.0}
I_ARP = {'vol': [10, 7, 5, 4, 3, 2], 'sus': 1, 'duty': 0.25}
I_PAD = dict(W.I_PAD, duty=2.0)
I_TRI = {'vol': [15], 'sus': 15}
WAVES = W.WAVES + [F.wavetable([1.0, 0.45, 0.12, 0.2, 0.03])]          # 0 campana (caja de música) … 3 flauta
GM_FLAUTA, GM_GLOCK = 73, 9


def ataque(nuevo, nota, dur):
    """muestras que tarda un instrumento GM en llegar a la mitad de su pico (las capas GM se adelantan eso)"""
    r = nuevo(); r.add(0.5, 0.5 + dur, nota, 100)
    y = r.render(3 * SR)
    e = np.convolve(np.abs(y), np.ones(48) / 48, mode='same')
    return int(np.argmax(e[SR // 2:] >= 0.5 * e.max()))


def poner_frames(p):
    """el driver a 8 frames por semicorchea: todas las voces del chip empiezan a tiempo con el bombo"""
    F.FRAME_S = p.S16 * SR / 8
    F.FPS = SR / F.FRAME_S


def construir(p):
    """los stems (mono) de COPIAS bucles seguidos"""
    poner_frames(p)
    T = COPIAS * p.NB * p.BAR
    NF = F.frames_for(T + 3)
    Cn = {k: Chan(NF) for k in ('pulso', 'saw', 'n163', 'contra', 'arp', 'ost', 'bass',
                                'p1', 'p2', 'p3', 's1', 's2', 's3')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash', 'metal')}
    for z in NZ.values(): z.exact = True
    NS = int(NF * F.FRAME_S) + SR
    kick, body, toms = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    R = {'flauta': MN.Rec(GM_FLAUTA), 'glock': MN.Rec(GM_GLOCK), 'glockm': MN.Rec(GM_GLOCK), 'cflauta': MN.Rec(GM_FLAUTA)}
    slap = SL.Rec() if p.slap else None
    drums = bateria(p)                                                   # (también llena p.extra: los pings del solo)

    def mete(buf, smp, t, g):
        i = int(round(t * SR))
        buf[i:i + len(smp)] += smp[:max(0, min(len(smp), NS - i))] * g

    for c in range(COPIAS):
        tv = lambda b, st: p.tval(b, st, c)
        for b, st, n, d, s in p.mel:
            a = p.arr[s]
            t0, t1 = tv(b, st), tv(b, st + d) - 0.15 * p.S16
            vs = 0.8 if s in p.quiet else 1.0
            lead, dbl = a.get('lead'), a.get('dbl', ())
            if lead == 'flauta':
                R['flauta'].add(t0, t1, n, 92 if s not in p.quiet else 78)
                play(Cn['n163'], t0, t1, n, I_N163, q=q_n163, release=3, vs=vs)
            elif lead == 'pulso':
                play(Cn['pulso'], t0, t1, n, I_LEAD, release=3, vs=vs)
            elif lead == 'glock':
                R['glockm'].add(t0, t1, n, 84)
                play(Cn['n163'], t0, t1, n, I_N163, q=q_n163, release=3, vs=0.7)
            if 'glock' in dbl: R['glock'].add(t0, min(t1, t0 + 0.5), n, 70)
            if 'saw' in dbl: play(Cn['saw'], t0, t1, n - 12, I_SAW, q=q_vrc6, release=2)
        for b, st, n, d, s in p.contra_n:
            t0, t1 = tv(b, st), tv(b, st + d) - 0.15 * p.S16
            if p.arr[s].get('contra') == 'flauta': R['cflauta'].add(t0, t1, n, 70)
            else: play(Cn['contra'], t0, t1, n, I_CONTRA, q=q_n163, release=4)
        for b, st, n, d in p.extra:
            R['glockm'].add(tv(b, st), tv(b, st + d), n, 88)
        for b, st, n, d in linea_bajo(p):
            t0, t1 = tv(b, st), tv(b, st + d) - 0.25 * p.S16
            if slap: slap.add(t0, t1, n, 100 if st % 4 == 0 else 84)
            else: play(Cn['bass'], t0, t1, n, I_TRI, q=q_tri, release=0)
        for b, st, n, d in arpegio(p):
            play(Cn['arp'], tv(b, st), tv(b, st + d) - 0.1 * p.S16, n, I_ARP, release=1,
                 vs=0.8 if p.A(b, 'arp') == 'a16' else 0.9)
        for b, st, n, g in ostinato(p):
            play(Cn['ost'], tv(b, st), tv(b, st + 1) - 0.1 * p.S16, n, I_OST, q=q_n163, release=0, vs=g)
        for b in range(1, p.NB + 1):
            r, q = p.chord_at(b)
            if p.A(b, 'pad'):
                for ch, nn in zip(('p1', 'p2', 'p3'), voces(r, q)):
                    play(Cn[ch], tv(b, 0), tv(b, 16) - 0.1 * p.S16, nn, I_PAD, q=q_n163, release=4)
            if p.A(b, 'stab'):
                for st in (2, 6, 10, 14):
                    if parada(p, b) and st >= 8: break
                    for ch, nn in zip(('s1', 's2', 's3'), voces(r, q, 62)):
                        play(Cn[ch], tv(b, st), tv(b, st + 1), nn, I_STAB, q=q_n163, release=1)
        for t, k, g in drums:
            t += c * p.NB * p.BAR
            if k == 'golpe':
                mete(kick, TN.KICK_DEEP, t, 0.75); mete(kick, TN.KICK, t, 0.45)
            elif k == 'kick': mete(kick, TN.KICK, t, 0.4 * g / 0.5)
            elif k == 'snare':
                NZ['snare'].hit(t, 4, [round(x * g) for x in SNARE_N]); mete(body, TN.SNARE_BODY, t, 0.3 * g)
            elif k == 'hat': NZ['hat'].hit(t, 0, [round(x * g) for x in HAT])
            elif k == 'metal': NZ['metal'].hit(t, 1, [round(x * g) for x in METAL], short=1)
            elif k == 'crash': NZ['crash'].hit(t, 1, CRASH)
            elif k.startswith('tom'): mete(toms, WN.TOMS[int(k[3])], t, 0.6 * g)
    L = int(round(T * SR)) + 2 * SR
    fit = lambda x: np.pad(x, (0, max(0, L - len(x))))[:L]
    wav = lambda ch: fit(F.render_wave(Cn[ch], WAVES) * 0.0075)
    pulse = lambda ch: fit(F.pulse_dac(F.render_pulse(Cn[ch])))
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    from scipy.signal import butter, sosfilt
    blando = butter(1, 2200, btype='low', fs=SR, output='sos')     # (arpegio y púlsar redondos: no tapan los pitidos)
    noise = lambda z, m=12: fit(F.tnd_dac(NZ[z].render() / 22638.0 * m))
    S = {'pulso': pulse('pulso'), 'saw': fit(F.render_saw(Cn['saw']) * 0.004), 'n163': wav('n163'),
         'contra': wav('contra'), 'arp': sosfilt(blando, pulse('arp')), 'ost': sosfilt(blando, wav('ost')),
         'pad': wav('p1') + wav('p2') + wav('p3'), 'stab': wav('s1') + wav('s2') + wav('s3'),
         'kick': fit(F.tnd_dac((kick + 64) / 22638.0) - base),
         'snare': fit(F.tnd_dac((body + 64) / 22638.0) - base) + noise('snare'),
         'toms': fit(F.tnd_dac((toms + 64) / 22638.0) - base),
         'hat': noise('hat'), 'metal': noise('metal'), 'crash': noise('crash')}
    if not slap: S['bass'] = fit(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0))
    capas = [(k, r, lambda r=r: MN.Rec(r.program[1])) for k, r in R.items()]
    if slap: capas.append(('bass', slap, SL.Rec))
    for k, r, nuevo in capas:                                    # las capas GM, adelantadas lo que tarda su ataque
        if not r.ev: continue
        ev = sorted(r.ev)[len(r.ev) // 2]
        adv = ataque(nuevo, ev[2], min(ev[1] - ev[0], 1.0))
        y = GM.cached(r, L) if k != 'bass' else r.render(L)
        S[k] = np.concatenate([y[adv:], np.zeros(adv)])
    # (el GOLPE entra en 0,7 ms, no de un salto: su clic de ruido caía en la costura del bucle como un chasquido)
    ent = np.ones(L)
    for c in range(COPIAS):
        for t, k, g in drums:
            if k == 'golpe':
                i = int(round((t + c * p.NB * p.BAR) * SR))
                ent[i:i + 32] = np.linspace(0, 1, 32)[:max(0, min(32, L - i))]
    for k in ('kick', 'crash'): S[k] = S[k] * ent
    return {k: x - np.mean(x) for k, x in S.items() if np.abs(x).max() > 0}


# ══ MEZCLA ═════════════════════════════════════════════════════════════════════════════════════════════════════
LV0 = {'flauta': 0, 'pulso': 0, 'glockm': -1, 'cflauta': -7, 'glock': -9, 'saw': -10, 'n163': -10, 'contra': -9,
       'arp': -3.5, 'ost': -7, 'stab': -7, 'pad': -6, 'bass': 0.5, 'kick': 3.5, 'snare': -5.5, 'toms': -1,
       'hat': -12, 'metal': -15, 'crash': -8}


def niveles(p, y):
    m = y.mean(1) if y.ndim == 2 else y
    out, b0 = [], 0
    for _, n in p.secs:
        seg = m[b0 * p.BAR_N:(b0 + n) * p.BAR_N]
        out.append(10 * np.log10(np.mean(seg ** 2) + 1e-20)); b0 += n
    return out


def con_pitidos(p, y):
    with wave.open(BEEP_WAV, 'rb') as w:
        bp = np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(float) / 32768.0
    z = y.copy()
    BT = p.BAR_N // 4
    for f in range(p.NB // 2):
        for bt in BEEP_TIEMPOS:
            i = f * 8 * BT + bt * BT
            z[i:i + len(bp)] += (bp * BEEP_GAN)[:, None]
    pk = np.abs(z).max()
    return z * (0.98 / pk) if pk > 0.98 else z


def mezcla(p, S):
    """del medio de las COPIAS: la mezcla estéreo masterizada; las secciones tranquilas bajadas hasta QUIET_DB
    respecto a la media de las demás (medido CON pitidos, como el comprobador)"""
    lv = dict(LV0, **p.lv)
    g = GN.level(S, {k: lv.get(k, -12) for k in S}, p.ref)
    a = p.NB * p.BAR_N
    from scipy.signal import butter, sosfilt
    lado = {'arp': 0.25, 'hat': 0.2, 'glock': 0.15, 'saw': 0.15, 'ost': 0.2, 'stab': 0.15, 'metal': 0.2, 'contra': 0.1}
    x = sum(S[k] * g[k] for k in S)
    side = sum(v * S[k] * g[k] for k, v in lado.items() if k in S)
    # EL SITIO DE LOS PITIDOS: la mezcla entera sin 30 Hz de abajo y con tres huecos estrechos donde viven el pitido
    # (2290 Hz) y sus armónicos 2.º y 3.º — así se oye limpio encima de todo (la caja de 2 y 4 cae con dos de los
    # tres). Sobre las 3 copias: sin costura.
    filtros = [butter(1, 30, btype='high', fs=SR, output='sos')] + [
        butter(2, [f - w, f + w], btype='bandstop', fs=SR, output='sos') for f, w in ((2290, 75), (4580, 60), (6870, 60))]
    for sos in filtros:
        x, side = sosfilt(sos, x), sosfilt(sos, side)
    x, side = x[a:a + p.LOOP_N], side[a:a + p.LOOP_N]
    st = np.stack([x + side, x - side], 1)
    nombres = [s for s, _ in p.secs]
    gan = {s: 1.0 for s in nombres}
    r = int(0.01 * SR)
    for _ in range(10):
        env = np.ones(p.LOOP_N)
        b0, prev = 0, gan[nombres[-1]]
        for s, n in p.secs:
            i0, i1 = b0 * p.BAR_N, (b0 + n) * p.BAR_N
            env[i0:i1] = gan[s]
            if i0 >= r: env[i0 - r:i0] = np.linspace(prev, gan[s], r)   # (cambia justo antes del golpe de la sección)
            prev = gan[s]; b0 += n
        env[p.LOOP_N - r:] = np.linspace(gan[nombres[-1]], gan[nombres[0]], r)   # (y antes de la costura)
        y = F.master(st * env[:, None], lufs=p.lufs)
        lvs = dict(zip(nombres, niveles(p, con_pitidos(p, y))))
        ref = np.mean([v for s, v in lvs.items() if s not in p.quiet])
        err = {s: (lvs[s] - ref - QUIET_DB) for s in p.quiet}
        for s, dd in p.realce.items():                               # el clímax, al menos `dd` dB sobre la siguiente
            e = lvs[s] - max(v for k, v in lvs.items() if k != s) - dd   # (solo se sube, nunca por debajo de 1:
            err[s] = e if (e < 0 or gan[s] > 1.0) else 0.0             #  crece por capas, no por volumen)
        if all(abs(e) < 0.05 for e in err.values()): break
        for s, e in err.items(): gan[s] *= 10 ** (-e / 20)
        for s in p.realce: gan[s] = max(gan[s], 1.0)
    mid = {k: S[k][a:a + p.LOOP_N] * g[k] for k in S}
    return y, g, mid


# ══ COMPROBACIONES (números: no oyen) ════════════════════════════════════════════════════════════════════════════
CLASH = {1, 6, 11}


def sonando(lista, NB):
    """nota que suena en cada semicorchea (compás, st) → nota, de una lista (b, st, n, d, …)"""
    out = {}
    for e in lista:
        b, st, n, d = e[:4]
        for k in range(st, st + d):
            out[(b + k // 16, k % 16)] = n
    return out


def comprueba(p, cual='melodía', mel=None):
    mel = p.mel if mel is None else mel
    if not mel: return {}
    tono, paso, igual, largas, fuera, malas = 0, 0, 0, 0, 0, []
    for i, (b, st, n, d, s) in enumerate(mel):
        r, q = p.chord_at(b)
        en = (n - r) % 12 in [iv % 12 for iv in q]
        assert n % 12 in p.esc(b), f'{p.id} {cual}: {nm(n)} fuera de la escala (compás {b})'
        if (b - 1) % 2 == 1: assert st < 4, f'{p.id} {cual}: ataca en los tiempos 6-8 (compás {b}, semicorchea {st})'
        tono += en; fuera += st % 4 != 0; largas += d >= 4
        ant = mel[i - 1][2] if i else mel[-1][2]
        sig = mel[i + 1][2] if i + 1 < len(mel) else mel[0][2]
        paso += 1 <= abs(n - ant) <= 2; igual += n == ant
        if not en and not (d < 3 and 1 <= abs(n - ant) <= 2 and 1 <= abs(n - sig) <= 2):
            malas.append((b, st, nm(n), d))
    t = len(mel)
    stats = dict(notas=t, acorde=100 * tono / t, grado=100 * paso / t, repetidas=100 * igual / t, largas=100 * largas / t,
                 contratiempo=100 * fuera / t)
    print(f'  {cual}: {t} notas · del acorde {stats["acorde"]:.0f}% (aprobadas 79-90) · por grado {stats["grado"]:.0f}% (20-44) · '
          f'repetidas {stats["repetidas"]:.0f}% (1-23) · largas {stats["largas"]:.0f}% (11-46) · a contratiempo de negra '
          f'{stats["contratiempo"]:.0f}% · ámbito {nm(min(m[2] for m in mel))}-{nm(max(m[2] for m in mel))}')
    print('    notas fuera del acorde que entran o salen por salto, o largas:', malas or 'ninguna')
    bajo = sonando(linea_bajo(p), p.NB)
    otra = sonando(p.contra_n if mel is p.mel else p.mel, p.NB)
    ch_b, ch_o = [], []
    for b, st, n, d, _ in mel:
        for k in range(st + st % 2, st + d, 2):
            pos = (b + k // 16, k % 16)
            bb, oo = bajo.get(pos), otra.get(pos)
            if bb is not None and (n - bb) % 12 in CLASH: ch_b.append((b, k, nm(n), nm(bb)))
            if oo is not None and (n - oo) % 12 in CLASH: ch_o.append((b, k, nm(n), nm(oo)))
    print('    contra el bajo (m2 / M7 / tritono):', ch_b or 'ninguno')
    if mel is p.mel and p.contra_n: print('    melodía contra contramelodía:', ch_o or 'ninguno')
    return dict(stats, malas=malas, choques=ch_b + (ch_o if mel is p.mel else []))


def imprime_forma(p):
    print('  forma (compases, segundos):')
    b0 = 0
    for s, n in p.secs:
        a = p.arr[s]
        lead = a.get('lead') or ('solo de percusión' if a.get('bat') == 'solo' else '—')
        print(f'    {s:3s} {b0 + 1:3d}-{b0 + n:<3d} {b0 * p.BAR:6.1f}-{(b0 + n) * p.BAR:6.1f} s  {lead:8s} '
              f'{"+" + "+".join(a.get("dbl", ())) if a.get("dbl") else "":12s} {" ".join(p.acordes[b0:b0 + n])}')
        b0 += n


def leeme(p, chk):
    L = [f'{p.nombre} (`{p.id}`) — {p.bpm} BPM, {p.NB} compases = {p.NB * p.BAR:.2f} s = {p.LOOP_N} muestras; frase = '
         f'8 tiempos = {8 * 60 / p.bpm:.7f} s ("beat": {{"period": {8 * 60 / p.bpm:.7f}}})',
         p.descr, '', 'Secciones (para decir QUÉ suena raro con un minuto y segundo):']
    b0 = 0
    for s, n in p.secs:
        a = p.arr[s]
        L.append(f'  {s:3s} {int(b0 * p.BAR // 60)}:{b0 * p.BAR % 60:05.2f} - {int((b0 + n) * p.BAR // 60)}:{(b0 + n) * p.BAR % 60:05.2f}  '
                 f'{a.get("nota", "")}')
        b0 += n
    L += ['', f'{p.id}_con_beeps.ogg / .wav  con los 3 pitidos de cada frase (como en el juego)',
          f'{p.id}_juego.ogg  la que se instala (sin pitidos)', f'{p.id}.mid',
          f'Comprobador: {"TODO OK" if chk else "HAY FALLOS"}. NO se ha escuchado: solo números.']
    return '\n'.join(L) + '\n'


def escribe_mid(p, path):
    import mido
    mid = mido.MidiFile(ticks_per_beat=480)
    tk = lambda b, st: ((b - 1) * 16 + st) * 120
    pistas = [('melodia', 0, GM_FLAUTA, [(tk(b, st), d * 120, n) for b, st, n, d, _ in p.mel]),
              ('contramelodia', 1, 11, [(tk(b, st), d * 120, n) for b, st, n, d, _ in p.contra_n]),
              ('bajo', 2, 36 if p.slap else 38, [(tk(b, st), d * 120, n) for b, st, n, d in linea_bajo(p)]),
              ('arpegio', 3, 81, [(tk(b, st), d * 120, n) for b, st, n, d in arpegio(p)]),
              ('glockenspiel', 4, GM_GLOCK, [(tk(b, st), d * 120, n) for b, st, n, d in p.extra])]
    gm_dr = {'golpe': 36, 'kick': 36, 'snare': 38, 'hat': 42, 'metal': 51, 'crash': 49, 'tom0': 50, 'tom1': 47, 'tom2': 43}
    pistas.append(('bateria', 9, None, [(int(round(t / p.S16 * 120)), 60, gm_dr[k]) for t, k, g in bateria(p)]))
    for nombre, ch, prog, ev in pistas:
        if not ev: continue
        tr = mido.MidiTrack(); mid.tracks.append(tr)
        tr.append(mido.MetaMessage('track_name', name=nombre, time=0))
        if nombre == 'melodia': tr.append(mido.MetaMessage('set_tempo', tempo=int(round(60e6 / p.bpm)), time=0))
        if prog is not None: tr.append(mido.Message('program_change', channel=ch, program=prog, time=0))
        e = []
        for t0, d, n in ev: e += [(t0, 1, n), (t0 + d, 0, n)]
        t = 0
        for tt, on, n in sorted(e, key=lambda x: (x[0], x[1])):
            tr.append(mido.Message('note_on' if on else 'note_off', channel=ch, note=n, velocity=96, time=tt - t)); t = tt
    mid.save(path)


def ogg(wavp, oggp):
    os.system(f'ffmpeg -v quiet -y -i "{wavp}" -c:a libvorbis -q:a 6 "{oggp}"')


def zona_pitidos(p, mid, z=None):
    """qué capas suenan donde miran los pitidos (2245-2335 Hz y sus armónicos 2.º y 3.º, en los tiempos 6-8): % de
    la energía de esas bandas en esos ratos, por capa (para saber a quién callar)"""
    BT = p.BAR_N // 4
    win = np.zeros(p.LOOP_N, bool)
    for f in range(p.NB // 2):
        for bt in BEEP_TIEMPOS:
            i = f * 8 * BT + bt * BT
            win[i:i + int(0.15 * SR)] = True
    out = {}
    for nom, (lo, hi) in (('2290', (2245, 2335)), ('x2', (4555, 4605)), ('x3', (6845, 6895))):
        e = {k: np.mean(BC.band(x, SR, lo, hi)[win] ** 2) for k, x in mid.items()}
        tot = sum(e.values()) + 1e-30
        out[nom] = sorted(((100 * v / tot, k) for k, v in e.items()), reverse=True)[:4]
    print('  en la zona de los pitidos: ' + ' · '.join(f'{n}: ' + ', '.join(f'{k} {v:.0f}%' for v, k in L) for n, L in out.items()))
    b0 = 0
    for s, n in p.secs:                                              # qué capas pesan en cada sección
        seg = {k: np.var(x[b0 * p.BAR_N:(b0 + n) * p.BAR_N]) for k, x in mid.items()}
        tot = sum(seg.values()) + 1e-30
        print(f'    {s:3s} {10 * np.log10(tot):6.1f} dB: ' + ', '.join(f'{k} {100 * v / tot:.0f}%' for k, v in
                                                               sorted(seg.items(), key=lambda kv: -kv[1])[:7]))
        b0 += n
    if z is not None:
        bs = BC.detect_beeps(z.mean(1), SR, 2290.0)
        malos = sorted(bs, key=lambda b: -max(b['harm'] / 0.10, b['dur'] / 0.085))[:6]
        donde = lambda t: (p.sec_of[int(t // p.BAR) + 1], int(t // p.BAR) + 1, round((t % (2 * p.BAR)) / (p.BAR / 4)) + 1)
        print('  los peores pitidos (sección, compás, tiempo de la frase, ms, armónicos %): ' +
              ' · '.join(f'{donde(b["t"])} {1000 * b["dur"]:.0f} {100 * b["harm"]:.0f}' for b in malos))


def args_comprobador(p):
    names = [s for s, _ in p.secs]
    a = dict(bpm=float(p.bpm), sections=tuple(n for _, n in p.secs), names=names, quiet=list(p.quiet) or None,
             climax=p.climax)
    cli = (f'--bpm {p.bpm} --sections {",".join(str(n) for _, n in p.secs)} --names {",".join(names)}'
           + (f' --quiet {",".join(p.quiet)}' if p.quiet else '') + (f' --climax {p.climax}' if p.climax else ''))
    return a, cli


def pista(nombre):
    p = PISTAS[nombre]()
    print(f'══ {p.id} "{p.nombre}": {p.bpm} BPM ({p.BAR_N // 4} muestras por tiempo), {p.NB} compases = '
          f'{p.NB * p.BAR:.2f} s ({p.LOOP_N} muestras); frase = {8 * 60 / p.bpm:.7f} s')
    imprime_forma(p)
    st = comprueba(p, 'melodía')
    sc = comprueba(p, 'contramelodía', p.contra_n) if p.contra_n else {}
    assert not st['malas'] and not st['choques'] and not sc.get('malas') and not sc.get('choques'), 'las notas no pasan'
    if os.environ.get('NOTAS'):
        return
    S = construir(p)
    y, g, mid = mezcla(p, S)
    assert len(y) == p.LOOP_N
    GN.report(p.id, y, mid, {k: 1.0 for k in mid}, p.LOOP_N)
    z = con_pitidos(p, y)
    a, cli = args_comprobador(p)
    R = BC.check_signal(z.mean(1), SR, f'{p.id} (con pitidos, en memoria)', **a)
    if os.environ.get('REPORT'):
        zona_pitidos(p, mid, z)
        return R
    d = os.path.join(PRUEBAS, p.id)
    os.makedirs(d, exist_ok=True)
    for nom, x in ((f'{p.id}_juego', y), (f'{p.id}_con_beeps', z)):
        wp = os.path.join(d, nom + '.wav')
        F.write_wav(wp, x)
        ogg(wp, os.path.join(d, nom + '.ogg'))
        if nom.endswith('juego'): os.remove(wp)                      # (el .wav con pitidos se queda: lo mide el comprobador)
    escribe_mid(p, os.path.join(d, f'{p.id}.mid'))
    open(os.path.join(d, 'LEEME.txt'), 'w').write(leeme(p, R['ok']))
    print(f'  → {d}/  ({p.id}_juego.ogg · {p.id}_con_beeps.ogg/.wav · {p.id}.mid · LEEME.txt)')
    print(f'  comprobador: python3 tools/music/bloques_beep_check.py {d}/{p.id}_con_beeps.wav {cli}')
    if os.environ.get('INSTALL'):
        os.makedirs(DST, exist_ok=True)
        wp = os.path.join(DST, p.id + '.wav')
        F.write_wav(wp, y)
        ogg(wp, os.path.join(DST, p.id + '.ogg'))
        os.remove(wp)
        escribe_mid(p, os.path.join(AQUI, 'mid', p.id + '.mid'))
        print(f'  → instalada: assets/music/worlds/via_estelar/{p.id}.ogg + tools/music/mid/{p.id}.mid')
    return R


# ══ 1. VÍA ESTELAR, REMASTER (R) ═══════════════════════════════════════════════════════════════════════════════
# El tema (la melodía de la flauta, variante B: la instalada hasta ahora) sigue siendo la sección A, igual nota por
# nota. Lo nuevo: una SUBIDA (ii-iii-IV-V, cada frase un paso más arriba), un ESTRIBILLO propio (I-V-vi-IV, el
# gancho "ta-TAA ta-ta TAAA" y su suspiro en el tiempo 5), un CORTE (el glockenspiel con la llamada, colchón y caja
# floja), la subida otra vez con el bombo a negras y el arpegio que sube, y el CLÍMAX: el estribillo UN TONO ARRIBA
# (Mi mayor) con la sierra una octava abajo, el glockenspiel doblando y una contramelodía. La vuelta a Re es la
# cadencia rota Si7 → Do (el giro oscuro: ♭VI de Mi) → Re: Do Re | Sol La7 y la costura cae en Re, como siempre.
def via_estelar():
    import via_estelar as VE
    pre = [(PR('E5', 'G5', 'B5', 'A5', 'G5'), T('F#5', 'A5')),          # Em | F#m
           (PR('G5', 'B5', 'D6', 'E6', 'D6'), T('C#6', 'E6')),          # G  | A
           (PR('G5', 'B5', 'E6', 'F#6', 'E6'), H('C#6')),               # Em | F#m (un paso más arriba)
           ('0:B5:2 2:D6:2 4:G6:4 8:D6:2 10:E6:2 12:D6:4', T('C#6', 'E6'))]   # G | A7
    c1 = (HK('A5', 'D6', 'E6', 'D6', 'F#6'), T('E6', 'C#6'))             # D  | A    pregunta
    c2 = (HK('F#5', 'B5', 'C#6', 'B5', 'D6'), T('E6', 'D6'))             # Bm | G    respuesta abierta (el suspiro)
    c3 = (HK('A5', 'D6', 'E6', 'D6', 'F#6'), '0:G6:1 1:F#6:1 2:E6:14')   # D  | A    la pregunta, que se enrosca arriba
    c4 = (HK('D6', 'B5', 'A5', 'B5', 'D6'), T('C#6', 'A5'))              # G  | A7   se posa
    c7 = (HK('G5', 'B5', 'C#6', 'B5', 'E6'), T('F#6', 'C#6'))            # Em | F#m
    c8 = (HK('D6', 'B5', 'A5', 'B5', 'D6'), T('E6', 'C#6'))              # G  | A7
    coro = [c1, c2, c3, c4, c1, c2, c7, c8]
    corte = [('0:B4:4 4:C#5:2 6:D5:2 8:F#5:8', H('G5')),                 # Bm | G
             ('0:A4:4 4:D5:4 8:F#5:4 12:A5:4', H('E5')),                  # D  | A    LA LLAMADA en Re
             ('0:B4:4 4:C#5:2 6:D5:2 8:F#5:8', H('B5')),
             ('0:E5:4 4:F#5:2 6:G5:2 8:B5:6 14:A5:2', H('G5'))]           # Em | A7
    coda = [(HK('G5', 'C6', 'D6', 'C6', 'E6'), T('D6', 'A5')),           # C  | D
            c4]                                                           # G  | A7 → la costura
    return Pista(
        id='via_estelar', nombre='Vía Estelar (remaster)', bpm=120, lufs=-11.5, slap=False, ref='flauta',
        descr='Re mayor. A = el tema de siempre; luego subida, estribillo nuevo, corte con la llamada, subida, clímax '
              'en Mi mayor (el estribillo un tono arriba) y la vuelta Do-Re-Sol-La7.',
        secs=[('A1', 8), ('A2', 8), ('B', 8), ('C', 16), ('D', 8), ('E', 8), ('F', 16), ('K', 4)],
        acordes=('D G A7 D  D G A7 D '
                 'Bm G Em A7  D G A7 D '
                 'Em F#m G A  Em F#m G A7 '
                 'D A Bm G  D A G A7  D A Bm G  Em F#m G A7 '
                 'Bm G D A  Bm G Em A7 '
                 'Em F#m G A  Em F#m G A7 '
                 'E B C#m A  E B A B7  E B C#m A  F#m G#m A B7 '
                 'C D G A7').split(),
        escala={**{s: escala('D', MAYOR) for s in ('A1', 'A2', 'B', 'C', 'D', 'E', 'K')}, 'F': escala('E', MAYOR)},
        melodia={'A1': [VE.Q_B, VE.R1_B, VE.Q_B, VE.R2_B],
                 'A2': [VE.P1_B, VE.P2_B, VE.Q_B, VE.R2_B],
                 'B': pre, 'C': coro, 'D': corte, 'E': pre,
                 'F': [(sube(a, 2), sube(b, 2)) for a, b in coro], 'K': coda},
        contra={'A2': ['0:F#4:16', '0:G4:16', '0:G4:8 8:B4:8', '0:A4:16', '0:A4:16', '0:B4:16', '0:A4:8 8:E4:8', '0:F#4:16'],
                'F': [f'0:{n}:16' for n in 'G#4 F#4 G#4 A4 G#4 F#4 E4 D#4 G#4 F#4 G#4 A4 C#5 B4 C#5 D#5'.split()]},
        arr={'A1': dict(lead='flauta', arp='a8', bajo='oct8', bat='recta', nota='el tema (flauta), como siempre'),
             'A2': dict(lead='flauta', contra='n163', arp='a8', bajo='oct58', bat='recta', fill='toms',
                        nota='el puente del tema y vuelta, con una contramelodía debajo'),
             'B': dict(lead='flauta', dbl=('glock',), arp='a16', bajo='oct58', bat='subida', fill='parada',
                       nota='la SUBIDA (Em F#m G A): cada frase un paso más arriba; acaba en una parada'),
             'C': dict(lead='flauta', dbl=('glock',), arp='a16', bajo='galope', pad=True, bat='motor', fill='toms',
                       nota='el ESTRIBILLO nuevo (D A Bm G): el gancho "ta-TAA ta-ta TAAA"'),
             'D': dict(lead='glock', pad=True, bajo='redonda', bat='media', fill='bombos',
                       nota='el CORTE: glockenspiel con la llamada, colchón, caja floja (~4 dB más bajo)'),
             'E': dict(lead='flauta', arp='sube', bajo='oct8', bat='subida', fill='redoble',
                       nota='la subida otra vez, con el bombo a negras y el arpegio que sube; redoble de timbales'),
             'F': dict(lead='flauta', dbl=('glock', 'saw'), contra='n163', arp='a16', pad=True, bajo='galope',
                       bat='motor', fill='toms', nota='el CLÍMAX: el estribillo un tono arriba (Mi mayor), todo junto'),
             'K': dict(lead='flauta', dbl=('glock',), arp='a8', bajo='oct8', bat='recta', fill='toms',
                       nota='la vuelta: Do (cadencia rota) Re | Sol La7 → la costura, en Re')},
        quiet=['D'], climax='F', lv={}, realce={'F': 0.6})


# ══ 2. PÚLSAR (140) ═══════════════════════════════════════════════════════════════════════════════════════════════
# Más rápido y con más empuje: Si menor (la relativa de Re: el mismo cielo) con el estribillo en Re mayor. Lo que lo
# hace suyo: EL PÚLSAR, una campana del N163 que late en semicorcheas con acentos 3+3+2 (el tresillo de la casa),
# el bajo al GALOPE, la melodía del pulso en 3+3+2, y la flauta que toma la melodía en la subida y en el corte. El
# clímax junta el estribillo (pulso + sierra + glockenspiel) con la flauta como contramelodía debajo.
def estelar_pulsar():
    v1 = (TR('B4', 'D5', 'F#5', 'E5', 'D5', 'F#5'), T('G5', 'B5'))       # Bm | G
    v2 = (TR('A4', 'D5', 'F#5', 'E5', 'D5', 'A5'), T('B5', 'C#6'))       # D  | A
    v3 = (v1[0], T('G5', 'D5'))                                          # Bm | G
    v4 = (TR('E5', 'G5', 'B5', 'A5', 'G5', 'B5'), T('A#5', 'C#6'))       # Em | F#7
    v5 = (TR('F#5', 'B5', 'D6', 'C#6', 'B5', 'D6'), T('E6', 'D6'))       # Bm | G   (la respuesta, una octava arriba)
    v6 = (TR('F#5', 'A5', 'D6', 'E6', 'D6', 'A5'), T('C#6', 'E6'))       # D  | A
    v7 = (v5[0], H('B5'))
    v8 = (TR('G5', 'B5', 'E6', 'D6', 'C#6', 'B5'), T('A#5', 'F#5'))      # Em | F#7
    p2 = ('0:G5:3 3:B5:3 6:D6:2 8:E6:2 10:D6:6', T('C#6', 'E6'))
    faro = [('0:F#5:3 3:B5:3 6:D6:2 8:C#6:2 10:B5:6', H('F#5')),         # Bm | Bm  la señal del púlsar (glockenspiel)
            p2,                                                           # G  | A
            ('0:F#5:3 3:B5:3 6:D6:2 8:C#6:2 10:B5:6', H('D6')),
            (p2[0], T('C#6', 'A#5'))]                                     # G  | F#7
    sub = [('0:B4:2 2:D5:2 4:G5:4 8:A5:2 10:G5:2 12:B5:4', T('C#6', 'E6')),       # G   | A
           ('0:C#5:2 2:F#5:2 4:A5:4 8:B5:2 10:A5:2 12:C#6:4', T('D6', 'B5')),     # F#m | Bm
           ('0:B4:2 2:D5:2 4:G5:4 8:A5:2 10:G5:2 12:D6:4', T('E6', 'C#6')),       # G   | A
           ('0:E5:2 2:G5:2 4:B5:4 8:C#6:2 10:B5:2 12:G5:4', H('A5'))]             # Em  | A7
    c1 = (W4('F#5', 'A5', 'D6', 'E6', 'D6', 'A5'), H('C#6'))             # D  | F#m
    c2 = (W4('G5', 'B5', 'D6', 'E6', 'D6', 'B5'), T('C#6', 'E6'))        # G  | A
    c3 = (W4('F#5', 'A5', 'D6', 'E6', 'D6', 'F#6'), H('A5'))             # D  | F#m
    c4 = (W4('G5', 'B5', 'E6', 'D6', 'C#6', 'B5'), T('A5', 'C#6'))       # Em | A7
    c7 = (W4('F#5', 'B5', 'D6', 'E6', 'D6', 'B5'), H('D6'))              # Bm | G
    c8 = (c4[0], T('A5', 'E6'))                                          # Em | A7
    c8f = (c4[0], T('A#5', 'F#5'))                                       # Em | F#7 → la costura, en Si menor
    corte = [('0:F#5:6 6:E5:2 8:D5:2 10:E5:2 12:F#5:4', H('G5')),        # Bm | G
             ('0:A5:6 6:G5:2 8:F#5:2 10:E5:2 12:D5:4', T('C#5', 'E5')),  # D  | A
             ('0:F#5:6 6:G5:2 8:A5:2 10:G5:2 12:F#5:4', T('G5', 'B5')),  # Bm | G
             ('0:E5:6 6:F#5:2 8:G5:2 10:A5:2 12:B5:4', T('C#6', 'A5'))]  # Em | A7
    return Pista(
        id='estelar_pulsar', nombre='Púlsar', bpm=140, lufs=-11.0, slap=False, ref='pulso',
        descr='Si menor / Re mayor. P = la señal (glockenspiel sobre el púlsar); V = la estrofa del pulso en 3+3+2; '
              'B = la subida (flauta); C = el estribillo en Re; D = el corte (flauta y colchón); F = el clímax.',
        secs=[('P', 8), ('V', 16), ('B', 8), ('C', 16), ('D', 8), ('F', 16)],
        acordes=('Bm Bm G A  Bm Bm G F#7 '
                 'Bm G D A  Bm G Em F#7  Bm G D A  Bm G Em F#7 '
                 'G A F#m Bm  G A Em A7 '
                 'D F#m G A  D F#m Em A7  D F#m G A  Bm G Em A7 '
                 'Bm G D A  Bm G Em A7 '
                 'D F#m G A  D F#m Em A7  D F#m G A  Bm G Em F#7').split(),
        escala={s: escala('D', MAYOR) for s in ('P', 'V', 'B', 'C', 'D', 'F')},
        melodia={'P': faro, 'V': [v1, v2, v3, v4, v5, v6, v7, v8], 'B': sub, 'C': [c1, c2, c3, c4, c1, c2, c7, c8],
                 'D': corte, 'F': [c1, c2, c3, c4, c1, c2, c7, c8f]},
        contra={'F': [f'0:{n}:16' for n in 'A4 A4 B4 C#5 D5 C#5 B4 C#5 A4 A4 B4 C#5 D5 D5 E5 C#5'.split()]},
        arr={'P': dict(lead='glock', ost=1.0, bajo='galope', bat='rock', fill='toms',
                       nota='la señal: el glockenspiel sobre el PÚLSAR (campana en 3+3+2) y el bajo al galope'),
             'V': dict(lead='pulso', ost=0.7, bajo='galope', bat='rock', fill='parada',
                       nota='la estrofa: el pulso en 3+3+2, pregunta y respuesta (la respuesta una octava arriba)'),
             'B': dict(lead='flauta', arp='sube', bajo='blancas', bat='subida', fill='redoble',
                       nota='la subida: la flauta toma la melodía; bombo a negras en la 2.ª mitad, redoble'),
             'C': dict(lead='pulso', dbl=('saw', 'glock'), stab=True, pad=True, ost=0.6, bajo='galope', bat='motor', fill='toms',
                       nota='el ESTRIBILLO en Re mayor: pulso + sierra + glockenspiel, acordes a contratiempo'),
             'D': dict(lead='flauta', pad=True, ost=0.5, bajo='redonda', bat='media', fill='bombos',
                       nota='el CORTE: la flauta sola sobre el colchón y el púlsar flojo (~4 dB más bajo)'),
             'F': dict(lead='pulso', dbl=('saw', 'glock'), contra='flauta', ost=0.8, stab=True, bajo='galope',
                       bat='motor', fill='toms', fill_g=0.6, nota='el CLÍMAX: el estribillo con todo y la flauta debajo')},
        quiet=['D'], climax='F', lv={'flauta': 0, 'ost': -3, 'stab': -9, 'cflauta': -6, 'arp': -9}, realce={'F': 0.6})


# ══ 3. BONUS (126) ═══════════════════════════════════════════════════════════════════════════════════════════════
# Como los demás bonus (worlds_nes.py BONUS, jungla_bonus): un tema propio, corto (32 compases, ~1 min), batería de
# "competición" (bombo a negras) y un SOLO DE PERCUSIÓN de 8 compases propio de la isla: el "estelar" (timbales que
# preguntan en 3+3+2 y el cristal que contesta). Sol mayor, juguetón: el pulso salta con una anticipación de
# semicorchea; la flauta contesta en B y cierra con la llamada en Sol.
def estelar_bonus():
    a = [(J('G5', 'B5', 'D6', 'B5', 'G5', 'A5', 'B5'), T('A5', 'F#5')),           # G  | D
         (J('E5', 'G5', 'B5', 'G5', 'E5', 'F#5', 'G5'), T('A5', 'G5')),           # Em | C
         (J('G5', 'B5', 'D6', 'B5', 'D6', 'E6', 'D6'), T('E6', 'F#6')),           # G  | D
         ('0:E6:2 2:C6:1 3:G5:3 6:A5:2 8:G5:2 10:E5:2 12:G5:4', T('F#5', 'A5'))]  # C  | D7
    b = [('0:C5:2 2:E5:2 4:G5:4 8:A5:2 10:G5:2 12:E5:4', T('F#5', 'A5')),         # C  | D
         ('0:B4:2 2:D5:2 4:F#5:4 8:G5:2 10:F#5:2 12:D5:4', T('E5', 'G5')),        # Bm | Em
         ('0:C5:2 2:E5:2 4:G5:4 8:A5:2 10:G5:2 12:C6:4', T('D6', 'A5')),          # C  | D
         ('0:D5:4 4:G5:4 8:B5:4 12:D6:4', H('C6'))]                               # G  | D7  LA LLAMADA en Sol
    return Pista(
        id='estelar_bonus', nombre='Vía Estelar (bonus)', bpm=126, lufs=-11.0, slap=False, ref='pulso',
        descr='Sol mayor. A (pulso) · B (flauta, cierra con la llamada) · S = solo de percusión "estelar" · A2 (con '
              'glockenspiel y contramelodía).',
        secs=[('A', 8), ('B', 8), ('S', 8), ('A2', 8)],
        acordes=('G D Em C  G D C D7 '
                 'C D Bm Em  C D G D7 '
                 'G G C D  G G C D7 '
                 'G D Em C  G D C D7').split(),
        escala={s: escala('G', MAYOR) for s in ('A', 'B', 'S', 'A2')},
        melodia={'A': a, 'B': b, 'A2': a},
        contra={'A2': [f'0:{n}:16' for n in 'B4 A4 B4 C5 B4 A4 G4 F#4'.split()]},
        arr={'A': dict(lead='pulso', stab=True, bajo='oct58', bat='motor', fill='toms',
                       nota='el tema: el pulso que salta, acordes a contratiempo, bombo a negras'),
             'B': dict(lead='flauta', arp='a16', bajo='oct8', bat='motor', fill='redoble',
                       nota='la flauta contesta y cierra con la llamada en Sol'),
             'S': dict(bat='solo', bajo='redonda', nota='el SOLO DE PERCUSIÓN "estelar": timbales y cristal'),
             'A2': dict(lead='pulso', dbl=('glock',), contra='n163', stab=True, bajo='oct58', bat='motor', fill='toms',
                        nota='el tema otra vez, con glockenspiel y contramelodía')},
        quiet=[], climax=None, lv={'flauta': 0, 'glockm': -2, 'stab': -8}, realce={})


# ══ 4. JEFE (150) ═══════════════════════════════════════════════════════════════════════════════════════════════
# Tenso y heroico: el color estelar en Re MENOR (la tónica de la Vía Estelar, oscurecida; melodía propia), el bajo
# SLAP de los jefes (slap.py), batería de jefe (bombo 3+3+2, "metal" a contratiempo). A = el tema con puntillo (pulso
# + sierra); B = la parte heroica en la relativa (Si♭ Do Fa) con el giro oscuro: Mi♭ (el ♭II napolitano) → La7;
# C = el corte (el cristal solo sobre el slap); D = la subida; E = el clímax (todo + contramelodía); R = la vuelta.
def estelar_boss():
    a1 = (DB('D5', 'F5', 'A5', 'G5', 'F5', 'A5'), T('Bb5', 'D6'))        # Dm | Bb
    a2 = (DB('E5', 'G5', 'C6', 'Bb5', 'A5', 'G5'), T('F5', 'A5'))        # C  | Dm
    a3 = (DB('D5', 'F5', 'A5', 'Bb5', 'C6', 'D6'), T('F6', 'D6'))        # Dm | Bb
    a4 = (DB('D6', 'Bb5', 'G5', 'A5', 'Bb5', 'G5'), T('E5', 'C#6'))      # Gm | A7
    a8 = (DB('G5', 'Bb5', 'D6', 'C6', 'Bb5', 'G5'), H('A5'))             # Gm | A7
    b1 = (W4('F5', 'Bb5', 'D6', 'C6', 'Bb5', 'F5'), T('G5', 'C6'))       # Bb | C
    b2 = (W4('A5', 'C6', 'F6', 'G6', 'F6', 'C6'), T('D6', 'A5'))         # F  | Dm
    b3 = (b1[0], T('G5', 'E6'))
    b4 = (W4('G5', 'Bb5', 'D6', 'E6', 'D6', 'Bb5'), T('A5', 'C#6'))      # Gm | A7
    b7 = (W4('D6', 'Bb5', 'G5', 'A5', 'Bb5', 'D6'), H('Eb6'))            # Gm | Eb  el giro oscuro
    b8 = (W4('E5', 'A5', 'C#6', 'E6', 'D6', 'C#6'), H('G5'))             # A7 | A7
    corte = [(W4('A5', 'D6', 'F6', 'E6', 'D6', 'A5'), H('D6')),          # Dm | Dm
             (W4('F5', 'Bb5', 'D6', 'C6', 'Bb5', 'F5'), T('E5', 'C#6')),  # Bb | A7
             (W4('A5', 'D6', 'F6', 'E6', 'D6', 'A5'), H('F5')),
             (W4('G5', 'Bb5', 'D6', 'C6', 'Bb5', 'G5'), T('A5', 'E6'))]   # Gm | A7
    sub = [(PR('D5', 'G5', 'Bb5', 'A5', 'G5'), T('A5', 'C#6')),          # Gm | A
           (PR('F5', 'Bb5', 'D6', 'C6', 'Bb5'), T('C6', 'E6')),          # Bb | C
           (PR('G5', 'Bb5', 'D6', 'E6', 'D6'), T('C#6', 'E6')),          # Gm | A
           ('0:D6:2 2:F6:6 8:D6:2 10:C6:2 12:Bb5:4', T('A5', 'C#6'))]     # Bb | A7
    vuelta = [('0:D6:2 2:Bb5:2 4:F5:4 8:D5:2 10:F5:2 12:Bb5:4', T('C6', 'G5')),      # Bb | C
              ('0:Bb5:2 2:G5:2 4:D5:4 8:E5:2 10:F5:2 12:G5:4', T('E5', 'C#5'))]      # Gm | A7 → la costura
    return Pista(
        id='estelar_boss', nombre='Vía Estelar (jefe)', bpm=150, lufs=-10.5, slap=True, ref='pulso',
        descr='Re menor. A = el tema con puntillo · B = la parte heroica (Si♭ Do Fa) con el Mi♭ napolitano · '
              'C = el corte · D = la subida · E = el clímax · R = la vuelta.',
        secs=[('A', 16), ('B', 16), ('C', 8), ('D', 8), ('E', 12), ('R', 4)],
        acordes=('Dm Bb C Dm  Dm Bb Gm A7  Dm Bb C Dm  Dm Bb Gm A7 '
                 'Bb C F Dm  Bb C Gm A7  Bb C F Dm  Gm Eb A7 A7 '
                 'Dm Dm Bb A7  Dm Dm Gm A7 '
                 'Gm A Bb C  Gm A Bb A7 '
                 'Dm Bb C Dm  Dm Bb Gm A7  Bb C F Dm '
                 'Bb C Gm A7').split(),
        escala={s: escala('D', MENOR) for s in ('A', 'B', 'C', 'D', 'E', 'R')},
        melodia={'A': [a1, a2, a3, a4, a1, a2, a3, a8], 'B': [b1, b2, b3, b4, b1, b2, b7, b8], 'C': corte,
                 'D': sub, 'E': [a1, a2, a3, a4, b1, b2], 'R': vuelta},
        contra={'E': [f'0:{n}:16' for n in 'F4 F4 G4 F4 F4 Bb4 D5 C#5 Bb4 C5 C5 D5'.split()]},
        arr={'A': dict(lead='pulso', dbl=('saw',), bajo='galope', bat='jefe', fill='toms',
                       nota='el tema: pulso + sierra, bajo slap al galope, batería de jefe'),
             'B': dict(lead='pulso', dbl=('saw', 'glock'), arp='a16', pad=True, bajo='oct8', bat='jefe', fill='parada',
                       nota='la parte heroica en la relativa (Si♭ Do Fa) y el Mi♭ napolitano; acaba en parada'),
             'C': dict(lead='glock', pad=True, bajo='blancas', bat='media', fill='bombos',
                       nota='el CORTE: el cristal (glockenspiel) solo sobre el slap y el colchón (~4 dB más bajo)'),
             'D': dict(lead='pulso', arp='sube', bajo='galope', bat='subida', fill='redoble',
                       nota='la subida: bombo a negras, el arpegio que sube, redoble'),
             'E': dict(lead='pulso', dbl=('saw', 'glock'), contra='n163', arp='a16', pad=True, bajo='galope',
                       bat='jefe', fill='toms', nota='el CLÍMAX: el tema y la parte heroica con todo'),
             'R': dict(lead='pulso', bajo='oct8', bat='recta', fill='toms', fill_g=0.6,
                       nota='la vuelta: más fina (sin sierra ni colchón) hacia el principio')},
        quiet=['C'], climax='E', lv={'glockm': 0, 'n163': -14}, realce={'E': 0.6})


PISTAS = {'via_estelar': via_estelar, 'estelar_pulsar': estelar_pulsar, 'estelar_bonus': estelar_bonus,
          'estelar_boss': estelar_boss}

if __name__ == '__main__':
    for k in [a for a in sys.argv[1:] if a in PISTAS] or list(PISTAS):
        pista(k)
