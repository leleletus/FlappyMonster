#!/usr/bin/env python3
# tools/music/tentacle_winter.py
# "Tentacle Tantrum" × "Winter Fallympics": la música del Mega Crabby helado.
# NO es una mezcla de las dos pistas: es un arreglo nuevo (mismo motor de Famicom) con
#   · la BASE de tentacle_nes: su melodía nota a nota (MIDI, mano derecha), su bajo
#     (mano izquierda), su armonía (HARM, medida en el original) y su batería (bombo en
#     tresillo, caja en 2 y 4, break en negras, redobles);
#   · la PALETA y la FUERZA de winter_nes: lead de sierra del VRC6 + brillo de pulso a la
#     octava, cuerdas huecas, colchón, subgrave de triángulo con "slap", acordes en pulsos
#     doblados una octava abajo, centelleo en semicorcheas, su batería (bombo / caja DPCM)
#     y lo que le da el empuje (lo mismo que su `escalate`): bajo a corcheas, hats abiertos
#     a contratiempo, bombo a negras, crash cada pocos compases, la melodía armonizada;
#     + CASCABELES (ruido corto del 2A03: nuevo);
#   · una SECCIÓN NUEVA, propia de esta pista, entre las dos vueltas de Tentacle: la
#     melodía de winter de 1:48 (Smooth Synth, compases 85-116: 32 compases), con el
#     arreglo ENTERO de winter_nes (se llama a su `build` y se queda solo ese tramo),
#     un semitono arriba: Fa# MAYOR. Así entra desde el Re# del final de Tentacle (tercera
#     arriba) y su último acorde (Do#) es la dominante del riff, que vuelve en Fa# menor.
#   Forma: riff · break · estribillo · escalas · final | INVIERNO | (2ª vuelta, más cargada).
#   El motivo navideño de la caja de música NO se usa: metido en los huecos de la melodía
#   de Tentacle sonaba forzado en casi todas sus apariciones (el usuario lo descartó).
#
#   python3 tools/music/tentacle_winter.py        → assets/music/tentacle_winter.ogg (+ .mid)
#   REPORT=1 python3 ...                           → solo los números (sin exportar)
#   SOLO=lead,bell python3 ...                     → solo esos instrumentos
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import tentacle_nes as TN                      # melodía, bajo, armonía, forma
import winter_nes as W                         # paleta: canción, instrumentos, batería
from famicom import (master, SR, Noise, tnd_dac, band_power, OCT, write_wav, loudness, biquad)

BPM, BAR, S16 = W.BPM, W.BAR, W.S16
E = BAR / 8                                    # corchea
assert abs(BAR - TN.BAR) < 1e-9, 'las dos canciones van al mismo tempo (185 BPM)'
OUT = W.OUT
NAME = 'tentacle_winter'
W_FROM, W_TO, W_UP = 85, 116, 1                # el tramo de winter y su transposición
W_LEN = W_TO - W_FROM + 1
W_DB = -0.8                                    # nivel de la sección nueva en la mezcla
TR = 4                                         # compases del puente hacia la sección nueva
W_AT = 73 + TR                                 # donde empieza la sección nueva
NB = 144 + TR + W_LEN
LAP2 = 72 + TR + W_LEN                              # compases que se desplaza la 2ª vuelta
SECT = [('A', 1, 16), ('BR', 17, 24), ('B', 25, 40), ('C', 41, 56), ('D', 57, 72), ('TR', 73, 72 + TR), ('W', W_AT, W_AT + W_LEN - 1)]


def bar_of(t):
    return int(t / BAR + 1e-6) + 1


def loc(b):
    """Compás de Tentacle 1-144 → (compás 1-72 de la forma, vuelta 1 o 2)"""
    return (b - 1) % 72 + 1, 1 if b <= 72 else 2


def at(t):
    """Tiempo en Tentacle (144 compases) → tiempo en esta pista (la 2ª vuelta, tras la sección nueva)"""
    return t + ((TR + W_LEN) * BAR if t >= 72 * BAR - 1e-6 else 0.0)


class Part:
    """Lo que `winter_nes.build` escribe, pero solo los compases a..b, movidos a `to` y
    transpuestos: así la sección nueva es el arreglo de winter_nes tal cual"""
    def __init__(self, real, a, b, to, up):
        self.real, self.t0, self.t1, self.sh, self.up = real, (a - 1) * BAR, b * BAR, (to - a) * BAR, up
        part = self

        class NZ:
            def __init__(self, k): self.k = k
            def hit(self, t, *a_, **k_):
                if part.ok(t):
                    real.NZ[self.k].hit(t + part.sh, *a_, **k_)
        self.NZ = {k: NZ(k) for k in real.NZ}
        self.pads = []                                   # (t, dur, nota) del colchón: la armonía de la sección

    def ok(self, t):
        return self.t0 - 1e-6 <= t < self.t1 - 1e-6

    def note(self, name, kind, t0, dur, m, inst, **k):
        if self.ok(t0):
            d = min(dur, self.t1 - t0)
            self.real.note(name, kind, t0 + self.sh, d, m + self.up, inst, **k)
            if name == 'lead3':
                # la MISMA voz que lleva la melodía de Tentacle (caja de música a la octava + pulso):
                # que al cambiar de sección no cambie también el instrumento que canta
                vs = k.get('vs', 1.0)
                hi_n = m + self.up + (12 if m + self.up + 12 <= 98 else 0)
                self.real.note('lead_bell', 'n163', t0 + self.sh, d, hi_n, W.I_BELL, vs=0.9 * vs, gate=1.1, midi='lead', release=5)
                self.real.note('lead2', 'pulse', t0 + self.sh, d, m + self.up, W.I_LEAD_P, vs=0.6 * vs, midi='lead')
            if name.startswith('pad'):
                self.pads.append((t0 + self.sh, d, m + self.up))

    def drum(self, t, n, vel=1.0, bus=''):
        if self.ok(t):
            self.real.drum(t + self.sh, n, vel, bus)

    def riser(self, t0, t1, top=11):
        if self.ok(t0):
            self.real.riser(t0 + self.sh, t1 + self.sh, top)


# ── Arreglo ──────────────────────────────────────────────────────────────────
I_SLEIGH = [7, 5, 4, 3, 2, 1]                  # cascabel: ruido corto (metálico), agudo
I_SLEIGH_OFF = [4, 3, 2, 1]
I_STAB = {'vol': [15, 13, 11, 8, 6, 4], 'sus': 3}
STATS = {'strings': 0, 'harm': 0, 'var': 0}


DMIN = [0, 2, 4, 5, 7, 9, 10]                   # Re menor natural (el estribillo)


def vary(top):
    """La melodía de Tentacle con VARIACIONES propias de esta pista (que no sea la de
    tentacle_nes nota por nota), todas sacadas de la propia melodía:
      · estribillo: en los compases que la melodía deja vacíos (27, 31, 35, 39) una RESPUESTA:
        la frase del compás anterior en secuencia, una tercera diatónica abajo (la 2ª vuelta,
        una sexta arriba), ajustada al acorde;
      · riff: mordente (nota – vecina de arriba – nota) en las notas largas, compases 9-16 (la
        2ª vuelta desde el 5), y la 2ª vuelta los compases 5-8 y 13-16 una octava arriba.
    Los 4 primeros compases del riff, las escalas y el final quedan como en el original
    (el final ya va rearticulado: no tiene notas largas que variar). → (s, e, n, vs)"""
    out = []
    by_bar = {}
    for s, e, n in top:
        by_bar.setdefault(bar_of(s), []).append((s, e, n))
    # escala de cada frase de 8 compases del riff = las notas que la melodía usa en ella
    scale = {}
    for b, ns in by_bar.items():
        fb, _ = loc(b)
        scale.setdefault((fb - 1) // 8, set()).update(n % 12 for _, _, n in ns)
    for s, e, n in top:
        b = bar_of(s)
        fb, lap = loc(b)
        sec = TN.section(b)
        hi = lap == 2
        d = e - s
        if sec == 'A':
            if hi and (5 <= fb <= 8 or 13 <= fb <= 16) and n + 12 <= 86:
                n += 12
            if d >= 2 * E * 0.95 and fb >= (5 if hi else 9):
                up = next((m for m in (n + 1, n + 2) if m % 12 in scale[(fb - 1) // 8]), None)
                if up:
                    out += [(s, s + S16, n, 1.0), (s + S16, s + 2 * S16, up, 0.9), (s + 2 * S16, e, n, 1.0)]
                    STATS['var'] += 1
                    continue
        out.append((s, e, n, 1.0))
    # respuestas del estribillo
    for lap in (1, 2):
        for g in (27, 31, 35, 39):
            b = g + 72 * (lap - 1)
            busy = by_bar.get(b, [])
            for s, e, n in by_bar.get(b - 1, []):
                s2, e2 = s + BAR, e + BAR
                if any(bs < e2 + S16 and be > s2 - S16 for bs, be, _ in busy):
                    continue                               # (donde el original ya canta, manda él)
                pc = n % 12
                m = n - 3
                if pc in DMIN:
                    i = DMIN.index(pc)
                    m = n - ((pc - DMIN[(i - 2) % 7]) % 12)
                r, q = TN.chord_at(b, min(1, int((s2 - (b - 1) * BAR) / (BAR / 2) + 1e-6)))
                pcs = [(r + x) % 12 for x in q]
                if m % 12 not in pcs and (m - 1) % 12 in pcs:
                    m -= 1                                 # (nota a evitar → la del acorde)
                if lap == 2 and m + 12 <= 88:
                    m += 12
                out.append((s2, e2, m, 0.8))
                STATS['var'] += 1
    return sorted(out)


def bridge(S, top, lead):
    """El PUENTE hacia la sección nueva (4 compases): que el cambio avise y tenga sentido.
    Armonía: Si – Si – Do# – Do# = los dos primeros acordes del final de Tentacle (que acaba
    de sonar: Si – Do# – Re#), pero ahora son el IV y el V de Fa# mayor y resuelven en la
    sección nueva. La melodía repite la célula del final sobre esos acordes y sube por el
    arpegio de Do#; la batería se vacía y vuelve creciendo (caja a negras → corcheas →
    semicorcheas, toms, subida de ruido); cuerdas que crecen y la caja de música anunciando"""
    t0 = 72 * BAR
    cell = {b: [(s - (b - 1) * BAR, e - s, n) for s, e, n in top if bar_of(s) == b] for b in (57, 58)}
    for i in range(3):                                     # la célula del final: Si, Si, Do#
        for dt, d, n in cell[57 if i < 2 else 58]:
            if i == 2 and n % 12 == 7:
                n += 1                                     # (Sol → Sol#: ya estamos en Fa# mayor)
            lead(t0 + i * BAR + dt, d, n, 'A', 0.92, vs=0.85 + 0.05 * i)
    for k, n in enumerate((68, 73, 77, 80, 85, 89)):       # arpegio de Do# hacia arriba, y se queda
        lead(t0 + 3 * BAR + k * E, E if k < 5 else 3 * E, n, 'B', 0.95)
    for i in range(4):
        tb = t0 + i * BAR
        r = 11 if i < 2 else 1                             # Si / Do#
        S.note('bass_tri', 'tri', tb, BAR, 35 + (r - 11), W.I_TRI, gate=0.97, midi='bass')
        for k in range(8 if i >= 2 else 4):                # bajo: negras, luego corcheas
            step = BAR / (8 if i >= 2 else 4)
            S.note('bass_n', 'n163', tb + k * step, S16 * 1.6, 35 + (r - 11) + (12 if (i >= 2 and k % 2) else 0), W.I_BASSN, gate=0.9, midi='bass')
        vs = 0.55 + 0.15 * i
        for nm_, ins, m in (('pad0', W.I_PAD, 48 + r), ('pad1', W.I_PAD, 55 + r), ('str0', W.I_STR, 60 + r + 4 - (12 if r == 11 else 0) + 12),
                            ('str1', W.I_STR2, 67 + r), ('strh0', W.I_STR2, 72 + r)):
            S.note(nm_, 'n163', tb, BAR, m, ins, vs=min(1, vs), gate=0.99, midi='keys')
        # Caja de música: arpegio del acorde en corcheas, cada compás una octava más de recorrido
        tri = [r, r + 4, r + 7]
        for k in range(8):
            m = 72 + tri[k % 3] + 12 * ((k // 3) if i >= 1 else 0) - (12 if r == 11 else 0)
            S.note('bell0', 'n163', tb + k * E, E, m, W.I_BELL, vs=0.35 + 0.1 * i, gate=1.2, midi='keys', release=5)
        if i >= 2:
            for k in range(16):
                S.note('lay_shim', 'pulse', tb + k * S16, S16, 73 + (0, 4, 7)[k % 3] + (12 if 3 <= k % 8 < 6 else 0), W.I_SHIM,
                       vs=0.45 + 0.15 * (i - 2), gate=0.7, midi='keys')
        # Batería: se vacía y vuelve creciendo
        for beat in range(4):
            S.drum(tb + beat * BAR / 4, 36, 0.8 + 0.05 * i)
            S.drum(tb + beat * BAR / 4 + E, 42, 0.8)
        n = (0, 4, 8, 16)[i]
        for k in range(n):
            if i == 3 and k >= 12:
                continue
            S.drum(tb + k * BAR / n, 40, 0.4 + 0.5 * (i * 16 + k * 16 / n) / 64)
        for st in range(8):
            S.NZ['sleigh'].hit(tb + st * E, 1, I_SLEIGH if st % 2 == 0 else I_SLEIGH_OFF, short=1)
            if i >= 2:
                S.NZ['sleigh'].hit(tb + st * E + S16, 1, I_SLEIGH_OFF, short=1)
    S.drum(t0, 49, 1.0)
    for k, n in ((12, 50), (13, 48), (14, 47), (15, 45)):
        S.drum(t0 + 3 * BAR + k * S16, n, 1.0, bus='x')
    S.riser(t0 + 2 * BAR, t0 + 4 * BAR, top=12)


def build():
    rh, lh = TN.load_midi()
    top, _ = TN.voices(rh)
    assert max(s for s, e, n in top) > 72 * BAR, 'el MIDI de Tentacle trae las dos vueltas'
    S = W.Song(NB)
    S.NZ['sleigh'] = Noise(S.nf)

    # ── La sección nueva: winter 85-116 con su arreglo entero, en Fa# mayor ──
    real_song = W.Song
    part = Part(S, W_FROM, W_TO, W_AT, W_UP)
    W.Song = lambda nb: part
    try:
        W.build(W.load_midi())
    finally:
        W.Song = real_song
    # … y con el ACOMPAÑAMIENTO de Tentacle por debajo, para que el cambio de sección no sea un
    # cambio de banda: su "chop" en 2 y 4 (con las notas del colchón de winter: la armonía de
    # esta sección) y su bombo en tresillo
    for b in range(W_AT, W_AT + W_LEN):
        t0 = (b - 1) * BAR
        for st in (2, 6):
            t = t0 + st * E
            ns = sorted({m for (pt, pd, m) in part.pads if pt <= t + 1e-6 < pt + pd})
            ns = sorted({60 + (m - 60) % 12 for m in ns})[:2]
            for i, m in enumerate(ns):
                S.note('chord%d' % i, 'vrc6', t, E, m + (12 if m < 64 else 0), W.I_CHORD if i == 0 else W.I_CHORD2, vs=0.9, gate=0.8, midi='keys')
            if ns:
                S.note('chordlo', 'n163', t, E, ns[0], W.I_CHORDLO, vs=0.9, gate=0.8, midi='keys')
        for st in (3, 5):
            S.drum(t0 + st * E, 36, 0.8, bus='x')

    # Melodía de Tentacle con las voces de winter (NO la sierra: con ella seguía sonando a
    # Tentacle): el Smooth Synth (N163, el de la sección nueva) + la CAJA DE MÚSICA doblando
    # cada nota una octava arriba + el pulso "8-Bit Square" de winter en estribillo y final;
    # en las escalas, caja de música + Smooth Synth + pulso; en el break, punteo (pluck); en el final se
    # suma la sierra una octava arriba, como en el final de winter
    def lead(t, dur, n, sec, gate, vs=1.0):
        hi_n = n + 12 if n + 12 <= 98 else n
        if sec == 'BR':
            S.note('lead3', 'n163', t, dur, n, W.I_PLUCK, vs=vs, gate=gate, midi='lead')
            S.note('lead_bell', 'n163', t, dur, hi_n, W.I_BELL, vs=0.8 * vs, gate=1.0, midi='lead', release=5)
            return
        if sec == 'C':
            S.note('lead_bell', 'n163', t, dur, hi_n, W.I_BELL, vs=vs, gate=1.1, midi='lead', release=5)
            S.note('lead3', 'n163', t, dur, n, W.I_LEAD_N, vs=0.85 * vs, gate=gate, midi='lead')
            S.note('lead2', 'pulse', t, dur, n, W.I_LEAD_P, vs=0.75 * vs, gate=gate, midi='lead')
            return
        S.note('lead3', 'n163', t, dur, n, W.I_LEAD_N, vs=vs, gate=gate, midi='lead')
        S.note('lead_bell', 'n163', t, dur, hi_n, W.I_BELL, vs=0.9 * vs, gate=1.1, midi='lead', release=5)
        S.note('lead_low', 'n163', t, dur, n - 12, W.I_LEAD_N, vs=0.6 * vs, gate=gate, midi='lead')
        # (el pulso da la presencia en 1-5 kHz que tenía la sierra; en el riff, a la misma altura)
        S.note('lead2', 'pulse', t, dur, hi_n if sec in ('B', 'D') else n, W.I_LEAD_P, vs=0.7 * vs, gate=gate, midi='lead')
        if sec == 'D':
            S.note('lead_saw', 'saw', t, dur, hi_n, W.I_SAW, vs=0.7 * vs, gate=gate, midi='lead')

    lead_at = {}                                # semicorchea → notas de la melodía sonando
    for s, e, n, vs_ in vary(top):
        b = bar_of(s)
        fb, lap = loc(b)
        sec = TN.section(b)
        dur = e - s
        t = at(s)
        gate = 0.55 if sec == 'BR' else 0.92
        lead(t, dur, n, sec, gate, vs_)
        if lap == 2 and sec == 'A' and fb <= 8:
            # (la octava de pulso de la sección de invierno se queda 8 compases sobre el riff)
            S.note('lay_lead8', 'pulse', t, dur, n + 12, W.I_OCT, vs=0.75 - 0.04 * fb, gate=gate, midi='lead')
            S.note('lead_saw', 'saw', t, dur, n + 12, W.I_SAW, vs=0.75 - 0.04 * fb, gate=gate, midi='lead')
        if (sec == 'D' or (lap == 2 and sec == 'B')) and dur >= E * 0.9:
            # armonizada (como la melodía de winter): la nota del acorde que queda una tercera
            # o más por debajo, en un pulso del VRC6
            r, q = TN.chord_at(b, min(1, int((s - (b - 1) * BAR) / (BAR / 2) + 1e-6)))
            pcs = [(r + x) % 12 for x in q]
            h = next((m for m in range(n - 3, n - 10, -1) if m % 12 in pcs), None)
            if h:
                S.note('lead_h1', 'vrc6', t, dur, h, W.I_CHORD2, vs=0.75, gate=gate, midi='lead')
                STATS['harm'] += 1
        k0, k1 = int(round(t / S16)), max(int(round(t / S16)) + 1, int(round((t + dur * gate) / S16)))
        for k in range(k0, k1):
            lead_at.setdefault(k, []).append(n)

    def lead_during(t0, steps=5):
        k0 = int(round(t0 / S16))
        out = []
        for k in range(k0, k0 + steps):
            out += lead_at.get(k, [])
        return out

    # Bajo de Tentacle con el de winter: triángulo de subgrave + "slap" N163 corto
    def bass(t0, t1, n, sub=True):
        S.note('bass_tri', 'tri', t0, t1 - t0, n - 12 if (n >= 40 and sub) else n, W.I_TRI, gate=1.0, midi='bass')
        S.note('bass_n', 'n163', t0, min(t1 - t0, S16 * 1.6), n, W.I_BASSN, gate=0.9, midi='bass')
    for s, e, n in lh:
        sec = TN.section(bar_of(s))
        if sec == 'D':
            continue
        while n < 33:
            n += 12
        if sec == 'BR':
            bass(at(s), at(s) + (e - s) * 0.4, n, sub=False)
        else:
            bass(at(s), at(s) + (e - s) * 0.88, n)

    for b in range(1, 145):
        fb, lap = loc(b)
        sec = TN.section(b)
        t0 = at((b - 1) * BAR)
        hi = lap == 2
        if sec == 'D':                           # el final: tresillo raíz – 5ª – raíz (del original)
            r, _ = TN.chord_at(b, 0)
            root = 36 + (r - 36) % 12 - (12 if r >= 8 else 0)
            for st, dm, ln in ((0, 0, 3), (3, 7, 2), (5, 0, 3)):
                bass(t0 + st * E, t0 + (st + ln) * E * 0.9, root + dm)
        for half in (0, 1):
            r, q = TN.chord_at(b, half)
            base = 60 + (r - 60) % 12
            th = t0 + half * BAR / 2
            # Acordes: el "chop" de Tentacle en 2 y 4 con los pulsos de winter, doblado una octava
            # abajo (el comp grave de winter)
            if sec != 'BR':
                st = 2 + half * 4
                S.note('chord0', 'vrc6', t0 + st * E, E, base + q[1], W.I_CHORD, gate=0.8, midi='keys')
                S.note('chord1', 'vrc6', t0 + st * E, E, base + q[2], W.I_CHORD2, gate=0.8, midi='keys')
                S.note('chordlo', 'n163', t0 + st * E, E, base + q[1] - 12, W.I_CHORDLO, gate=0.8, midi='keys')
            else:
                for k in (0, 2):                                       # break: golpe en cada negra
                    tt = t0 + (half * 4 + k) * E
                    S.note('chord0', 'vrc6', tt, E, base + q[1], W.I_CHORD, vs=0.8, gate=0.6, midi='keys')
                    S.note('chord1', 'vrc6', tt, E, base + q[2] - 12, W.I_CHORD2, vs=0.8, gate=0.6, midi='keys')
            # Bajo a corcheas (el "pump" del final de winter: raíz, alternando la octava)
            if sec == 'D' or (hi and sec in ('B', 'C')) or (hi and sec == 'A' and fb <= 8):
                for k in range(4):
                    S.note('lay_pump', 'n163', th + k * E, E / 2, 36 + r % 12 + (12 if k % 2 else 0), W.I_PUMP, midi='bass')
            # Colchón (seno de winter): raíz y quinta, graves
            if sec != 'BR':
                S.note('pad0', 'n163', th, BAR / 2, 48 + r % 12, W.I_PAD, vs=0.9, gate=0.98, midi='keys')
                S.note('pad1', 'n163', th, BAR / 2, 48 + r % 12 + q[2], W.I_PAD, vs=0.8, gate=0.98, midi='keys')
            # Cuerdas: estribillo, escalas y final (y el riff de la 2ª vuelta, más flojas); en la
            # 2ª vuelta también una octava arriba (como en winter)
            if sec in ('B', 'C', 'D') or (sec == 'A' and hi):
                vs = {'A': 0.55, 'B': 0.85, 'C': 0.7, 'D': 1.0}[sec]
                ld = lead_during(th, 8)
                # (nota sostenida: si la melodía pasa a un semitono de ella, la raíz; si tampoco, nada)
                for nm_, ins, m in (('str0', W.I_STR, base + q[2] - (12 if base + q[2] > 70 else 0)),
                                    ('str1', W.I_STR2, base + 12 + q[1] - (12 if base + q[1] > 70 else 0))):
                    if any((m - l) % 12 in (1, 11) for l in ld):
                        m = base + (12 if nm_ == 'str1' else 0)
                        STATS['strings'] += 1
                        if any((m - l) % 12 in (1, 11) for l in ld):
                            continue
                    S.note(nm_, 'n163', th, BAR / 2, m, ins, vs=vs, gate=0.98, midi='keys')
                    if hi and sec in ('B', 'D') and nm_ == 'str0':
                        S.note('strh0', 'n163', th, BAR / 2, m + 12, W.I_STR2, vs=vs * 0.8, gate=0.98, midi='keys')
            # Centelleo (arpegio en semicorcheas): las escalas y el final de la 2ª vuelta; y, para
            # que la sección de invierno no llegue ni se vaya de golpe, ya suena en los 8 últimos
            # compases antes del puente y se queda (apagándose) los 8 primeros del riff que vuelve
            shim = 0.5 if sec == 'C' else 0.75 if (sec == 'D' and hi) else (0.3 + 0.03 * (fb - 64)) if (sec == 'D' and fb >= 65) \
                else (0.6 - 0.04 * fb) if (sec == 'A' and hi and fb <= 8) else 0
            if shim:
                notes = sorted(72 + ((r + x) % 12) for x in q)
                for k in range(8):
                    S.note('lay_shim', 'pulse', th + k * S16, S16, notes[k % 3] + (12 if 3 <= k < 6 else 0),
                           W.I_SHIM, vs=shim, gate=0.7, midi='keys')
            if (sec == 'D' and not hi and fb >= 65) or (sec == 'A' and hi and fb <= 8):
                # … y las cuerdas agudas de winter, lo mismo
                S.note('strh1', 'n163', th, BAR / 2, 72 + (r + q[2]) % 12, W.I_STR2, vs=0.6, gate=0.98, midi='keys')
        # Break: la caja de música puntea el acorde con los golpes (frío, vacío). SIN eco: el eco de
        # winter (3 semicorcheas después) sobre este punteo a contratiempo sonaba desfasado
        if sec == 'BR' and fb <= 22:
            r, q = TN.chord_at(b, 0)
            base = 84 + (r - 84) % 12
            for st, x in ((6, q[2]), (10, q[1]), (14, 0)):
                S.note('bell0', 'n163', t0 + st * S16, S16 * 2, base + x - 12, W.I_BELL, vs=0.4, gate=1.2,
                       midi='keys', release=5)

        # ── Batería: los patrones de Tentacle con la batería de winter ───────
        if sec == 'BR':
            kicks, snares = (0, 2, 4, 6), (2, 6)
        elif sec == 'C':
            kicks, snares = (0, 3, 6), (4,)
        else:
            kicks, snares = (0, 3, 5), (2, 6)
        if sec == 'D' and fb % 2 == 0:
            kicks = (0, 3, 5, 7)
        for st in kicks:
            S.drum(t0 + st * E, 36, 1.0)
        for st in snares:
            S.drum(t0 + st * E, 40, 1.0)
        if sec == 'C':
            S.drum(t0 + 2 * E, 40, 0.45)                              # (fantasma del medio tiempo)
        # … y el empuje de winter (bus x): hats abiertos a contratiempo, bombo a negras
        opened = sec in ('B', 'D') or (hi and sec in ('A', 'C'))
        for st in range(8):
            if st in snares:
                continue
            if opened and st % 2 == 1:
                S.drum(t0 + st * E, 46, 0.6 if not hi else 0.72, bus='x')
            else:
                S.drum(t0 + st * E, 42, 1.0 if st % 2 else 0.65)
            if sec != 'BR' and (sec != 'A' or hi) and st + 1 not in snares:
                S.NZ['hat'].hit(t0 + st * E + S16, 0, [4, 2, 1])      # (semicorchea fantasma)
        if sec == 'D' or (hi and sec == 'B') or (hi and sec == 'A' and fb <= 4):   # (y al volver de la sección nueva)
            for st in (2, 4, 6):
                if st not in kicks:
                    S.drum(t0 + st * E, 36, 0.7, bus='x')
        if fb in (1, 17, 25, 41, 49, 57):
            S.drum(t0, 49, 1.0)
        elif (sec in ('B', 'C', 'D') and fb % 4 == 1) or (hi and sec == 'D' and fb % 2 == 1) or (hi and sec == 'A' and fb % 8 == 1):
            S.drum(t0, 49, 0.9, bus='x')
        if fb in (16, 24, 40, 56, 72):                                # redoble antes de cada sección
            for k in range(8):
                S.drum(t0 + 4 * E + k * S16, 40, 0.5 + 0.06 * k)
        if fb == 72 and hi:                                           # … y toms al cerrar la vuelta
            for k, n in ((0, 50), (1, 48), (2, 47), (3, 45)):
                S.drum(t0 + 2 * E + k * S16, n, 1.0, bus='x')
        if fb in (24, 56):                   # subida de ruido a lo que viene
            S.riser(t0 - BAR, t0 + BAR, top=10)
        # Cascabeles: en corcheas (acento en los tiempos); en el riff solo la 2ª vuelta
        if sec in ('B', 'C', 'D') or (sec == 'A' and hi) or (sec == 'BR' and fb >= 23):
            for st in range(8):
                S.NZ['sleigh'].hit(t0 + st * E, 1, I_SLEIGH if st % 2 == 0 else I_SLEIGH_OFF, short=1)
                if sec == 'BR' or (sec == 'D' and hi):                # (trémolo en semicorcheas)
                    S.NZ['sleigh'].hit(t0 + st * E + S16, 1, I_SLEIGH_OFF, short=1)
    bridge(S, top, lead)
    for b in range(W_AT, W_AT + W_LEN):                                   # (y en la sección nueva)
        for st in range(8):
            S.NZ['sleigh'].hit((b - 1) * BAR + st * E, 1, I_SLEIGH if st % 2 == 0 else I_SLEIGH_OFF, short=1)
    return S


def stems(S):
    st = S.stems()
    n = int(NB * BAR * SR)
    x = tnd_dac(S.NZ['sleigh'].render() / 12241.0)
    x = np.concatenate([x, np.zeros(max(0, n + 3 * SR - len(x)))])[:n + 2 * SR]
    st['sleigh'] = x - np.mean(x[:n])
    return st


# ── Mezcla (la de winter: nivel de cada grupo respecto a la melodía) ─────────
GROUPS = dict(W.GROUPS, sleigh=('sleigh',))
del GROUPS['layer'], GROUPS['xdrums']
# (el cuerpo sostenido es lo que da la fuerza de winter: con el bombo a +1.5 dB el factor de
# cresta salía 11 dB frente a los 9.7 de winter y las secciones 1-2 dB más flojas)
LEVEL_DB = dict(W.LEVEL_DB, sleigh=-11, kick=0.3, snare=-1.2, bass=0, soft=-5)


def group_of(k):
    if k.startswith('lay_'):
        return next(v for pre, v in W.LAYER_OF.items() if k.startswith(pre))
    k = W.XBUS.get(k, k)
    return next((g for g, pre in GROUPS.items() if any(k.startswith(p) for p in pre)), None)


def balance(st):
    """Como winter: cada grupo, a su nivel respecto a la melodía (medido sin capas ni golpes
    añadidos); las capas, la ganancia del instrumento al que doblan × LAYER_K"""
    g = {k: 1.0 for k in st}
    own = lambda k: not k.startswith('lay_') and k not in W.XBUS
    lead = W.active_rms(sum(st[k] for k in st if group_of(k) == 'lead' and own(k)))
    for gr in GROUPS:
        ks = [k for k in st if group_of(k) == gr]
        base = [k for k in ks if own(k)] or ks
        if not ks:
            continue
        lvl = W.active_rms(sum(st[k] for k in base))
        for k in ks:
            g[k] = lead * 10 ** (LEVEL_DB[gr] / 20) / lvl
            if k.startswith('lay_'):
                g[k] *= W.LAYER_K.get(k, W.LAYER_K['*'])
            if k == 'xriser':
                g[k] *= 0.8
    return g


def mixdown(st, g):
    solo = os.environ.get('SOLO')
    keep = set(solo.split(',')) if solo else None
    use = [k for k in st if group_of(k) and (keep is None or any(k.startswith(w) for w in keep))]
    x = sum(st[k] * g[k] for k in use)
    from scipy.signal import butter, sosfilt
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    x = sosfilt(butter(1, 15000, btype='low', fs=SR, output='sos'), x)
    side = np.zeros_like(x)
    for k, p in (('lead_sheen', 0.25), ('lead_bell', 0.25), ('lead2', -0.2), ('lead_h1', -0.3), ('lead_h2', 0.3), ('chord0', -0.3), ('chord1', 0.3), ('bell1', 0.3),
                 ('echo', -0.4), ('arp', 0.25), ('lay_shim', 0.25), ('str0', -0.25), ('str1', 0.25), ('flute0', -0.25),
                 ('flute1', 0.25), ('pad1', -0.2), ('hat', 0.2), ('xhat', -0.2), ('sleigh', -0.3)):
        if k in st and k in use:
            side += st[k] * g[k] * p
    return np.stack([x + side, x - side], 1)


def eq_to(y, ref):
    """La forma del espectro (bandas de octava) hacia la de winter_nes: la misma paleta"""
    mono = y.mean(1)
    n = min(len(mono), len(ref)) / SR
    P, R = band_power(mono, 6, n - 6), band_power(ref, 6, n - 6)
    dev = 10 * np.log10((P / P.sum() + 1e-12) / (R / R.sum() + 1e-12))
    gains = np.clip(-0.6 * dev, -4, 4)
    for (lo, hi), gdb in zip(OCT, gains):
        if abs(gdb) >= 0.5 and hi <= 16000:
            y = biquad(y, 'peak', np.sqrt(lo * hi), gdb, 1.1)
    print('  EQ hacia winter_nes: ' + ' '.join(f'{int(np.sqrt(lo * hi))}Hz {gdb:+.1f}' for (lo, hi), gdb in zip(OCT, gains)))
    return y


def report(y, st, g):
    mono = y.mean(1)
    print('  sonoridad: %.1f LUFS, pico %.3f' % (loudness(y), np.abs(y).max()))
    e = {}
    for k in st:
        gr = group_of(k)
        if gr:
            e[gr] = e.get(gr, 0) + float(np.mean((st[k] * g[k]) ** 2))
    tot = sum(e.values())
    print('  energía: ' + ' '.join(f'{k} {100 * v / tot:.0f}%' for k, v in sorted(e.items(), key=lambda z: -z[1])))
    # ¿Tapa algo a la melodía? (1-5 kHz, por sección: acompañamiento / melodía)
    lead = sum(st[k] * g[k] for k in st if group_of(k) == 'lead')
    rows = []
    for name, a, b in SECT:
        t0, t1 = (a - 1) * BAR, b * BAR
        L = W.band_rms(lead, t0, t1)
        r = {gr: W.band_rms(sum(st[k] * g[k] for k in st if group_of(k) == gr), t0, t1) / max(L, 1e-9)
             for gr in ('chords', 'strings', 'soft', 'arp', 'bell')}
        rows.append('%s ' % name + ' '.join('%s %.2f' % (k, v) for k, v in r.items()))
    print('  frente a la melodía (1-5 kHz): ' + ' | '.join(rows))
    def lv(a, b):
        return 20 * np.log10(np.sqrt(np.mean(mono[int((a - 1) * BAR * SR):int(b * BAR * SR)] ** 2)))
    v1 = [(n, lv(a, b)) for n, a, b in SECT]
    v2 = [(n, lv(a + LAP2, b + LAP2)) for n, a, b in SECT[:5]]
    m = max(v for _, v in v1 + v2)
    print('  dinámica (dB bajo la sección más fuerte) vuelta 1: ' + ' '.join(f'{n} {v - m:+.1f}' for n, v in v1)
          + ' · vuelta 2: ' + ' '.join(f'{n} {v - m:+.1f}' for n, v in v2))


if __name__ == '__main__':
    import librosa
    S = build()
    print('  cuerdas a la raíz por roce con la melodía: %d · notas de la melodía armonizadas: %d' % (STATS['strings'], STATS['harm']) + ' · variaciones de la melodía: %d' % STATS['var'])
    st = stems(S)
    g = balance(st)
    n = int(NB * BAR * SR)
    y = W.fold_tail(mixdown(st, g), n)
    # La sección nueva lleva más voces (el arreglo de winter + el acompañamiento de Tentacle):
    # a la altura del final de Tentacle, que el cambio no sea además un salto de volumen
    tt = np.arange(len(y)) / SR
    a_, b_ = (W_AT - 1) * BAR, (W_AT - 1 + W_LEN) * BAR
    env = np.clip((tt - a_) / (BAR / 2) + 1, 0, 1) * np.clip((b_ - tt) / (BAR / 2) + 1, 0, 1)
    out = np.clip((tt - (b_ - 4 * BAR)) / (4 * BAR), 0, 1) * (tt < b_)      # (y su redoble final, 1 dB menos: el riff vuelve con huecos)
    y = y * (10 ** ((W_DB * env - 1.0 * out) / 20))[:, None]
    y = eq_to(y, librosa.load(os.path.join(OUT, 'winter_nes.ogg'), sr=SR, mono=True)[0])
    y = master(y, lufs=-9.3)       # (sin tramos flojos como la intro de winter: así sus secciones igualan a las fuertes de winter)
    f = int(0.003 * SR)
    y[:f] *= np.linspace(0, 1, f)[:, None]
    y[-f:] *= np.linspace(1, 0, f)[:, None]
    report(y, st, g)
    if not os.environ.get('REPORT') and not os.environ.get('SOLO'):
        wav = os.path.join(OUT, NAME + '.wav')
        write_wav(wav, y)
        W.write_midi(os.path.join(OUT, NAME + '.mid'), S.ev)
        ogg = os.path.join(OUT, NAME + '.ogg')
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"')
        os.remove(wav)
        print(f'  {ogg}  {len(y) / SR:.2f} s')
    elif os.environ.get('SOLO'):
        write_wav('/tmp/%s_solo.wav' % NAME, y)
