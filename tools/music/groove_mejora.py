#!/usr/bin/env python3
# tools/music/groove_mejora.py — MEJORA de "El Groove", el tema del Cangrejo Groove (slap_boss.py sigue intacto). PREVIAS
# para elegir; no toca assets/ salvo con INSTALL=1 (y nunca el index.json). Se comprueba con números: NO SE HA ESCUCHADO.
#
# El usuario: el tema ya es bastante bueno, su único problema es que es muy repetitivo; las pocas secciones nuevas que
# tiene son muy buenas. Más instrumentos, más épica, más ganas de bailar, menos repetición. NO es reescribirlo.
#
# SE QUEDA: Mi menor a 150 BPM, el slap como voz principal, el riff, la B alta, el SOLO en paradas, la SUBIDA, el CLÍMAX, la
# banda de Famicom de slap_boss.py (mismos golpes, mismas notas) y dónde caen los POPS y los golpes que sigue la pelea.
# SE AÑADE (GM sobre el chip; todo sale del bajo o de sus acordes, sin una melodía encima que le quite el sitio):
#   · VARIANTES DEL RIFF: compases nuevos que conservan sus pops y su perfil, para que no suene igual cada 4;
#   · capas que cambian CADA FRASE: guitarra funk apagada, clavinete, palmas, cencerro, tumbadoras, metal que dobla la cola
#     del riff, cuerda y coro que sostienen, timbal y golpes de orquesta en los cierres;
#   · bombo a negras en la mitad del clímax (para bailar).
# (el usuario eligió la B, pero el metal y los golpes de orquesta "no terminan de combinar con el resto de la canción": el gancho va
#  en la SIERRA del VRC6, los acentos en pulsos y los golpes grandes en el golpe de sierra de la propia banda: su mismo chip)
# TRES VARIANTES, por cómo crecen:
#   A "mismo_mapa"  LA MISMA FORMA, compás a compás: 8 + 68. La pelea no necesita ni un cambio.
#   B "la_pista"    + D "LA PISTA" (16, nueva): disco en Lam Re Sol Do con bajo en octavas, bombo a negras y un gancho de metal.
#                   8 + 84.
#   C "el_duelo"    B + K' "EL DUELO" (8, nueva: el solo, ahora el metal contesta al bajo) + C' (16: el clímax otra vez,
#                   con otros bajos, el coro y el gancho de la pista). 8 + 108.
#
#   ~/.venvs/fm-music/bin/python tools/music/groove_mejora.py [A B C] → previas en FlappyMonster_pruebas/musica/groove_mejora/
#   REPORT=1 → solo números · INSTALL=1 GROOVE=A|B|C → assets/music/bosses/groove_intro|_loop.ogg
import os, sys, collections
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, q_saw, q_n163
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W
import jungla_nes as J
import montana_nes as M
import slap as SL
import slap_boss as SB
import gm as GM

BPM, S16, BAR = SB.BPM, SB.S16, SB.BAR
BL, ch, note = SB.BL, SB.ch, SB.note
R1, R2, R3, R4, R1V, R7, R8, FILL = SB.R1, SB.R2, SB.R3, SB.R4, SB.R1V, SB.R7, SB.R8, SB.FILL
B1, B2, B3, B4, B5, B6, B7, B8, B9, B11, B16 = SB.B1, SB.B2, SB.B3, SB.B4, SB.B5, SB.B6, SB.B7, SB.B8, SB.B9, SB.B11, SB.B16
K1, K2, K3, K4, K8 = SB.K1, SB.K2, SB.K3, SB.K4, SB.K8
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/groove_mejora'
INSTALL_DIR = os.path.join(F.MUSIC_DIR, 'bosses')
VNAME = {'A': 'mismo_mapa', 'B': 'la_pista', 'C': 'el_duelo'}
LUFS, CEILING = -9.5, 0.64                                            # (techo bajo: ni el OGG ni el MP3 deben pasar de 1,0)

# ══ VARIANTES DEL RIFF: mismos pops (2 y 11) y mismo acorde; cambian los tramos de en medio y la cola ═══════════════
R1b = "0:E2/2 2:E3/1! 3:E2/1x 4:G2/1 5:G2/1x 6:A2/1 7:B2/1 8:D3/2 10:B2/1 11:E3/1! 12:G3/1! 13:E3/1 14:D3/1 15:B2/1"
R2b = "0:G2/2 2:G3/1! 3:E2/1x 4:A2/1 5:B2/1 6:D3/2 8:E2/2 10:E2/1x 11:E3/1! 12:G3/1 13:E3/1 14:D3/1 15:B2/1"
R3b = "0:C2/2 2:C3/1! 3:C2/1x 4:G2/2 6:A2/1 7:B2/1 8:C3/2 10:E3/1 11:G3/1! 12:E3/2 14:C3/1 15:B2/1"
R4b = "0:D2/2 2:D3/1! 3:D2/1x 4:A2/2 6:C3/1 7:D3/1 8:F#3/2 10:E3/1 11:D3/1! 12:A3/1! 13:F#3/1 14:E3/1 15:D#3/1"
R7b = "0:C3/2 2:C4/1! 3:C3/1x 4:E3/1 5:G3/1 6:C4/2 8:B3/1 9:A3/1 10:G3/1 11:E3/1 12:C4/2! 14:B3/1 15:A3/1"
R8b = "0:B2/2 2:B3/1! 3:B2/1x 4:F#3/2 6:D#3/2 8:A3/2 10:B3/1 11:A3/1 12:F#3/1 13:D#3/1 14:F#3/1 15:A3/1"
K6 = "0:E2/1 1:E3/1! 2:G3/1! 3:E3/1 4:D3/1 5:B2/1 6:A2/1 7:Bb2/1 8:B2/2 10:G3/1! 11:E3/1 12:D3/1 13:B2/1 14:G2/2"
K7 = "0:E2/2 2:E3/1! 3:G3/1 4:A3/1 5:Bb3/1 6:B3/2! 8:A3/1 9:G3/1 10:E3/1 11:D3/1 12:E3/2! 14:G2/1 15:B2/1"
H4 = ['Em', 'Em', 'C', 'D']
H_C2 = ['Am', 'Am', 'Em', 'Em', 'C', 'C', 'B', 'B']


def disco(c, tail=''):
    """LA PISTA: el slap en octavas de disco; los pops, en los contratiempos (2 6 10 14)"""
    r, q = ch(c)
    b = 40 + (r - 40) % 12
    if b > 47: b -= 12
    N = lambda m: f"{['C','C#','D','D#','E','F','F#','G','G#','A','Bb','B'][m % 12]}{m // 12 - 1}"
    t = f"0:{N(b)}/1 1:{N(b)}/1x 2:{N(b + 12)}/1! 3:{N(b)}/1x 4:{N(b)}/1 5:{N(b + 7)}/1 6:{N(b + 12)}/1! 7:{N(b)}/1x " \
        f"8:{N(b)}/1 9:{N(b)}/1x 10:{N(b + 12)}/1! 11:{N(b + 7)}/1 12:{N(b)}/1 13:{N(b + q[1])}/1 14:{N(b + 12)}/1! 15:{N(b + 7)}/1"
    return t


H_D = ['Am', 'D', 'G', 'C', 'Am', 'D', 'B', 'B'] * 2
D_BASS = [disco(c) for c in H_D]
D_BASS[15] = SB.B16                                                   # (el último, la bajada de la B: lleva a la vuelta)

# EL GANCHO de la pista (metal, en los huecos del bajo: salta del pop al acorde, siempre notas del acorde o de paso)
HOOK = ["2:E5/2 4:A5/2 6:B5/1 7:C6/3 10:B5/2 12:A5/2 14:E5/2", "2:F#5/2 4:A5/2 6:B5/1 7:C6/3 10:A5/2 12:F#5/2 14:D5/2",
        "2:G5/2 4:B5/2 6:C6/1 7:D6/3 10:B5/2 12:G5/2 14:B5/2", "0:C6/2 2:E6/2 4:G6/4 8:E6/2 10:C6/2 12:G5/4",
        "2:E5/2 4:A5/2 6:B5/1 7:C6/3 10:B5/2 12:A5/2 14:E5/2", "2:F#5/2 4:A5/2 6:B5/1 7:C6/3 10:A5/2 12:F#5/2 14:D5/2",
        "2:B5/2 4:D#6/2 6:E6/1 7:F#6/3 10:D#6/2 12:B5/2 14:F#5/2", "0:B5/4 4:A5/2 6:F#5/2 8:D#5/4 12:F#5/2 14:A5/2"]
# EL DUELO: el bajo pregunta (impares), el metal contesta (pares) con su blue note
DUEL_B = [K1, "", K3, "", K7, "", K6, K8]
DUEL_M = {2: "0:E5/2 2:G5/2 4:A5/1 5:Bb5/1 6:B5/2 8:G5/2 10:E5/2 12:D5/2 14:E5/2", 4: "0:G5/2 2:A5/2 4:B5/2 6:D6/2 8:E6/4 12:D6/2 14:B5/2",
          6: "0:E6/2 2:D6/2 4:B5/1 5:Bb5/1 6:A5/2 8:G5/2 10:A5/2 12:B5/2 14:D6/2"}


def sections(v):
    A = ('A', [R1, R2, R3, R4, R1b, R2, R7, R8, R1, R2b, R3b, R4, R1V, R2b, R3, FILL], H4 + ['Em', 'Em', 'C', 'B'] + H4 + H4, 'A')
    Bs = ('B', [B1, B2, B3, B4, B5, B6, B7, B8, B9, B2, B11, B4, B5, B6, B7, B16], H_C2 * 2, 'B')
    Ks = ('K', [K1, K2, K3, K4, K1, K6, K7, K8], ['Em'] * 8, 'solo')
    Ss = ('S', [R1, R2, R3, R4, R1b, R2b, R3b, R8], H4 + ['Em', 'Em', 'C', 'B'], 'build')
    Cs = ('C', [R1, R2, R7, R8, R1V, R2, R7b, R8b, B9, B2, B11, B4, B5, B6, B7, B16], ['Em', 'Em', 'C', 'B'] * 2 + H_C2, 'climax')
    Os = ('O', [R1, R2b, R3b, R4], H4, 'out')
    Is = ('I', [R1, R2, R3, R4, R1, R2, R7, R8], H4 + ['Em', 'Em', 'C', 'B'], 'intro')
    Ds = ('D', D_BASS, H_D, 'dance')
    if v == 'A': return [Is, A, Bs, Ks, Ss, Cs, Os]
    if v == 'B': return [Is, A, Bs, Ks, Ss, Cs, Ds, Os]
    Du = ('K', DUEL_B, ['Em'] * 8, 'duel')
    C2 = ('C', [R1b, R2b, R7b, R8b, R1V, R2, R7, R8, B9, B2, B11, B4, B5, B6, B7, B16], ['Em', 'Em', 'C', 'B'] * 2 + H_C2, 'climax2')
    return [Is, A, Bs, Ks, Ss, Cs, Ds, Du, C2, Os]


# ══ EL REPARTO GM ═══════════════════════════════════════════════════════════════════════════════════════════════════
CLAV, MUTED, STRINGS, CHOIR, ORCH, BRASS, SYNBRASS, TIMP = 7, 28, 48, 52, 55, 61, 62, 47
CLAP, TAMB, COWBELL, CONGA_M, CONGA_O, CONGA_L, SHAKER = 39, 54, 56, 62, 63, 64, 82
# (GN.level iguala el RMS mientras suena: lo nuevo, claro pero siempre por debajo del slap)
I_HOOK = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.18, 6)}
I_ACC = {'vol': [13, 11, 8, 5, 3, 1], 'sus': 0, 'duty': 0.25}
CHIP_VOICE = {'hook': (('hook',), I_HOOK, q_saw), 'brass': (('b1', 'b2'), I_ACC, F.q_pulse), 'orch': (('o1', 'o2'), SB.I_HIT, q_saw)}
LV = dict(SB.LV, guit=-4, clav=-5, brass=-9, hook=-7, strings=-8, choir=-8, orch=-8, timp=-3, clap=-5, cow=-9, conga=-5, shak=-12, tamb=-11, kick=-3, snare=-4)
GM_KEYS = ('guit', 'clav', 'strings', 'choir', 'timp', 'clap', 'cow', 'conga', 'shak', 'tamb')
GUIT_PAT = {0: (2, 3, 6, 10, 11, 14), 1: (0, 3, 6, 7, 10, 14, 15), 2: (2, 5, 6, 9, 10, 13, 14), 3: (0, 2, 3, 6, 8, 10, 11, 14)}
CONGA_PAT = {0: ((6, CONGA_O), (14, CONGA_O), (15, CONGA_L)), 1: ((3, CONGA_M), (6, CONGA_O), (10, CONGA_M), (14, CONGA_O), (15, CONGA_L))}


def build(v):
    secs = sections(v)
    bass, chords, role, sec, pos, slen, starts = [], [], [], [], [], [], []
    for name, bars, harm, rl in secs:
        base = len(chords)
        starts.append((name, rl, base + 1, len(bars)))
        for i, t in enumerate(bars):
            bass += [(base + i + 1, st, n, d, vl) for st, n, d, vl in BL(t)]
        chords += [ch(c) for c in harm]
        role += [rl] * len(harm); sec += [name] * len(harm); pos += list(range(1, len(harm) + 1)); slen += [len(harm)] * len(harm)
    NB = len(chords)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('c1', 'c2', 'scr', 'pad1', 'pad2', 'h1', 'h2', 'spark', 'hook', 'b1', 'b2', 'o1', 'o2')}
    busy = {}
    NZ = {k: Noise(NF) for k in ('hat', 'ohat', 'snare', 'crash', 'nrise')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16
    rl = lambda b: role[b - 1]
    G = {}
    lead_notes = {}

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    def snare(t, g=1.0, vols=SB.SNARE_N):
        NZ['snare'].hit(t, 4, vols); hit(sn, TN.SNARE_BODY, t, g)

    def gm(k, prog, b, st, n, d, vel, gate=0.95):
        if k in CHIP_VOICE:                                             # (del chip de la banda, no GM; dos notas a la vez como mucho)
            names, inst, q = CHIP_VOICE[k]
            i = busy.get((k, b, st), 0)
            busy[(k, b, st)] = i + 1
            if i < len(names):
                play(Cn[names[i]], tv(b, st), tv(b, st) + d * S16 * gate, n, inst, q=q, release=2)
            return
        G.setdefault(k, M.Rec(prog)).add(tv(b, st), tv(b, st) + d * S16 * gate, n, vel)

    def dr(k, b, st, n, vel):
        G.setdefault(k, M.Rec(drums=True)).add(tv(b, st), tv(b, st) + S16, n, vel)

    def bass_at(b, st):
        return [x for x in bass if x[0] == b and x[1] <= st < x[1] + x[3]]

    def stab_chord(k, prog, b, st, d, lo, vel, gate=0.7, n=3):
        for p in M.place(None, chords[b - 1], lo)[:n]:
            gm(k, prog, b, st, p, d, vel, gate)

    # ── EL BAJO ──
    slap = SL.Rec()
    for b, st, n, d, vl in bass:
        r_, k = rl(b), pos[b - 1]
        if r_ == 'intro' and k <= 4: vl = int(vl * 0.9)
        slap.add(tv(b, st), tv(b, st) + d * S16 * 0.95, n, vl)
        if r_ in ('climax', 'climax2') and vl >= 120:
            play(Cn['spark'], tv(b, st), tv(b, st) + S16 * 0.9, n + 24, SB.I_SPARK, release=1)

    # ── LA BANDA DE FAMICOM: la de slap_boss.py, igual; la pista y el duelo, a su manera ──
    for b in range(1, NB + 1):
        r_, k = rl(b), pos[b - 1]
        r, q = chords[b - 1]
        band = not (r_ == 'intro' and k <= 4)
        strong = r_ in ('B', 'climax', 'climax2', 'dance')
        if band and r_ not in ('solo', 'duel'):
            base = 64 + (r - 64) % 12
            for st in (2, 6, 10, 14) if strong else (6, 14):
                play(Cn['c1'], tv(b, st), tv(b, st) + 1.2 * S16, base + q[1], SB.I_STAB, release=1)
                play(Cn['c2'], tv(b, st), tv(b, st) + 1.2 * S16, base + q[2], SB.I_STAB, release=1)
        if r_ in ('A', 'climax', 'climax2', 'build', 'dance'):
            hi = 76 + (r - 76) % 12
            for st in range(16):
                play(Cn['scr'], tv(b, st), tv(b, st) + S16 * 0.4, hi + (q[1] if st % 2 else q[2]), SB.I_SCR, vs=1.0 if st % 4 == 2 else 0.5, release=0)
        if strong:
            base = 57 + (r - 57) % 12
            for j, iv in enumerate(q[1:]):
                play(Cn[('pad1', 'pad2')[j]], tv(b, 0), tv(b, 0) + BAR * 0.97, base + iv, SB.I_PAD, q=q_n163, release=6)
        if r_ in ('solo', 'duel') and k % 2 == 1:
            base = 64 + (r - 64) % 12
            play(Cn['h1'], tv(b, 0), tv(b, 0) + 3 * S16, base + q[1], SB.I_HIT, q=q_saw, release=3)
            play(Cn['h2'], tv(b, 0), tv(b, 0) + 3 * S16, base + q[2], SB.I_HIT, q=q_saw, release=3)
        if band and r_ in ('A', 'B', 'climax', 'climax2', 'build', 'dance') and k % 4 == 0:
            for st in (12, 14) if k % 8 == 0 else (14,):
                base = 64 + (r - 64) % 12
                play(Cn['h1'], tv(b, st), tv(b, st) + 1.5 * S16, base + q[1], SB.I_HIT, q=q_saw, release=2)
                play(Cn['h2'], tv(b, st), tv(b, st) + 1.5 * S16, base + q[2], SB.I_HIT, q=q_saw, release=2)

    # ── LAS CAPAS NUEVAS: cambian cada frase (`fr` = cuántos grupos de 4 compases lleva la sección) ──
    for b in range(1, NB + 1):
        r_, k, L = rl(b), pos[b - 1], slen[b - 1]
        fr = (k - 1) // 4
        c = chords[b - 1]
        tail_brass = False
        if r_ == 'intro':
            if k >= 5: dr('shak', b, 2, SHAKER, 54); dr('shak', b, 10, SHAKER, 54)
            continue
        if r_ == 'A':
            if fr >= 0:                                                 # A1-4: la guitarra funk, sola, entra
                for st in GUIT_PAT[fr % 4]: stab_chord('guit', MUTED, b, st, 1, 67, 76, gate=0.6, n=2)
            if fr >= 1:                                                 # A5-8: + palmas y tumbadoras
                dr('clap', b, 4, CLAP, 90); dr('clap', b, 12, CLAP, 90)
                for st, n_ in CONGA_PAT[0]: dr('conga', b, st, n_, 84)
            if fr >= 2:                                                 # A9-12: + clavinete y el metal dobla la cola del riff
                for st in (3, 7, 11, 15): stab_chord('clav', CLAV, b, st, 1, 72, 84, gate=0.6, n=2)
                tail_brass = True
            if fr >= 3:                                                 # A13-16: + cencerro y cuerda que empuja
                for st in (0, 4, 8, 12): dr('cow', b, st, COWBELL, 76)
                stab_chord('strings', STRINGS, b, 0, 16, 60, 80, gate=0.98)
        elif r_ == 'B':
            for st, n_ in CONGA_PAT[1]: dr('conga', b, st, n_, 86)
            dr('clap', b, 4, CLAP, 82); dr('clap', b, 12, CLAP, 82)
            if fr % 2 == 1 or fr >= 2: stab_chord('strings', STRINGS, b, 0, 16, 60, 84, gate=0.98)   # (compases 5-16: la cuerda)
            if fr >= 2:
                for st in GUIT_PAT[1]: stab_chord('guit', MUTED, b, st, 1, 67, 70, gate=0.6, n=2)
            if k in (8, 16):                                            # el cierre: metal
                for st in (12, 14): stab_chord('brass', BRASS, b, st, 2, 60, 104, n=4)
        elif r_ in ('solo', 'duel'):
            if k % 2 == 1:
                stab_chord('orch', ORCH, b, 0, 3, 60, 92, n=3); gm('timp', TIMP, b, 0, 40, 3, 104)
            if k >= 5: dr('tamb', b, 4, TAMB, 66); dr('tamb', b, 12, TAMB, 66)
            if r_ == 'duel':
                if k in DUEL_M:
                    for bb, st, n, d in W.P(b, DUEL_M[k]):
                        gm('hook', SYNBRASS, b, st, n, d, 104); gm('brass', BRASS, b, st, n - 12, d, 92)
                        lead_notes.setdefault(b, []).append((st, n, d))
                for st in (4, 12): dr('clap', b, st, CLAP, 92)
        elif r_ == 'build':
            for st in GUIT_PAT[fr + 2]: stab_chord('guit', MUTED, b, st, 1, 67, 74, gate=0.6, n=2)
            tail_brass = k >= 5
            for st in range(0, 16, 2) if k >= 5 else (): dr('shak', b, st, SHAKER, 60)
            if k >= 7:                                                  # redoble de timbal
                for st in range(0, 16, 2 if k == 7 else 1): gm('timp', TIMP, b, st, 40 + (c[0] - 40) % 12, 1, 60 + 3 * st)
        elif r_ in ('climax', 'climax2'):
            for st in GUIT_PAT[3]: stab_chord('guit', MUTED, b, st, 1, 67, 78, gate=0.6, n=2)
            for st in (3, 7, 11, 15): stab_chord('clav', CLAV, b, st, 1, 72, 84, gate=0.6, n=2)
            for st, n_ in CONGA_PAT[1]: dr('conga', b, st, n_, 90)
            for st in (0, 4, 8, 12): dr('cow', b, st, COWBELL, 78)
            dr('clap', b, 4, CLAP, 96); dr('clap', b, 12, CLAP, 96)
            stab_chord('strings', STRINGS, b, 0, 16, 60, 90, gate=0.98)
            if k <= 8: tail_brass = True
            else:
                stab_chord('choir', CHOIR, b, 0, 16, 60, 92, gate=0.98)
                for st in (2, 10): stab_chord('brass', BRASS, b, st, 2, 60, 98, n=4)
            if k % 8 == 1: stab_chord('orch', ORCH, b, 0, 3, 60, 96); gm('timp', TIMP, b, 0, 40 + (c[0] - 40) % 12, 3, 112)
            if r_ == 'climax2' and k <= 8:                              # el gancho de la pista, ahora sobre el riff
                if k in (3, 7):
                    for bb, st, n, d in W.P(b, "2:G5/2 4:C6/2 6:D6/1 7:E6/3 10:D6/2 12:C6/2 14:G5/2" if k == 3 else "2:G5/2 4:C6/2 6:D6/1 7:E6/3 10:G6/2 12:E6/2 14:C6/2"):
                        gm('hook', SYNBRASS, b, st, n, d, 104); lead_notes.setdefault(b, []).append((st, n, d))
                stab_chord('choir', CHOIR, b, 0, 16, 60, 88, gate=0.98)
        elif r_ == 'dance':
            for st in (2, 6, 10, 14): stab_chord('clav', CLAV, b, st, 1, 72, 88, gate=0.6, n=2)
            for st in GUIT_PAT[fr % 4]: stab_chord('guit', MUTED, b, st, 1, 67, 80, gate=0.6, n=2)
            for st in (4, 12): dr('clap', b, st, CLAP, 104)
            for st in (2, 6, 10, 14): dr('tamb', b, st, TAMB, 78)
            for st in (0, 4, 8, 12): dr('cow', b, st, COWBELL, 74)
            if k >= 9 or fr == 1: stab_chord('strings', STRINGS, b, 0, 16, 60, 88, gate=0.98)
            if k >= 9: stab_chord('choir', CHOIR, b, 0, 16, 60, 84, gate=0.98)
            if k <= 15:                                                 # el gancho (1ª vez solo; 2ª con octava debajo)
                for bb, st, n, d in W.P(b, HOOK[(k - 1) % 8]):
                    gm('hook', SYNBRASS, b, st, n, d, 106)
                    if k > 8: gm('brass', BRASS, b, st, n - 12, d, 96)
                    lead_notes.setdefault(b, []).append((st, n, d))
            if k in (1, 9): stab_chord('orch', ORCH, b, 0, 3, 60, 100); gm('timp', TIMP, b, 0, 40 + (c[0] - 40) % 12, 3, 112)
        elif r_ == 'out':
            for st in GUIT_PAT[0]: stab_chord('guit', MUTED, b, st, 1, 67, 62, gate=0.6, n=2)
            dr('clap', b, 4, CLAP, 72); dr('clap', b, 12, CLAP, 72)
        if tail_brass:                                                  # la cola del riff, doblada (son las notas del bajo)
            for bb, st, n, d, vl in bass:
                if bb == b and st >= 8 and vl > 60: gm('brass', BRASS, b, st, n + 24, d, 92 if vl < 120 else 108, gate=0.85)
        if r_ in ('A', 'build', 'climax', 'climax2', 'B', 'dance') and k == L:    # un golpe de orquesta en el último cierre
            gm('timp', TIMP, b, 12, 40 + (c[0] - 40) % 12, 2, 100)

    # ── LA BATERÍA: la de slap_boss.py; a negras en la 1ª mitad del clímax; la pista, disco ──
    for b in range(1, NB + 1):
        r_, k, L = rl(b), pos[b - 1], slen[b - 1]
        last = k == L
        for st in range(16):
            t = tv(b, st)
            if r_ == 'intro' and k <= 4:
                if k >= 3 and st % 2 == 0: NZ['hat'].hit(t, 1, [4, 2, 1] if st % 4 else [6, 3, 1])
                if k == 4 and st >= 12: snare(t, 0.3 + 0.12 * (st - 12), [7 + (st - 12), 4, 2])
                continue
            if r_ in ('solo', 'duel'):
                if k % 2 == 1 and st == 0: hit(kick, TN.KICK_DEEP, t, 1.0); snare(t, 0.9); NZ['crash'].hit(t, 3, SB.CRASH)
                if st % 2 == 0: NZ['hat'].hit(t, 1, [4, 2, 1])
                if r_ == 'duel' and k % 2 == 0 and st % 4 == 0: hit(kick, TN.KICK_DEEP, t, 0.8)
                if k == 8 and st >= 8: hit(tom, W.TOMS[(st - 8) // 3 % 3], t, 0.6)
                continue
            if r_ == 'build':
                if st % 4 == 0: hit(kick, TN.KICK_DEEP, t, 1.0)
                step = 4 if k <= 3 else (2 if k <= 6 else 1)
                if st % step == 0: snare(t, 0.3 + 0.06 * k + 0.015 * st, [6 + k // 2 + st // 5, 4, 2])
                if st % 2 == 1: NZ['hat'].hit(t, 1, [3, 1])
                continue
            if r_ == 'dance':
                if st % 4 == 0: hit(kick, TN.KICK_DEEP, t, 1.0)
                if st in (4, 12): snare(t, 1.0)
                if st % 4 == 2: NZ['ohat'].hit(t, 1, [7, 6, 5, 4, 3, 2, 1])
                else: NZ['hat'].hit(t, 1, [5, 2, 1] if st % 2 == 0 else [3, 1])
                if st == 0 and k in (1, 5, 9, 13): NZ['crash'].hit(t, 3, SB.CRASH)
                if last and st >= 12:
                    hit(tom, W.TOMS[min(2, st - 12)], t, 0.7)
                    if st >= 14: snare(t, 0.5 + (st - 14) * 0.15, [8 + (st - 14), 5, 2])
                continue
            big = r_ in ('climax', 'climax2')
            floor = big and k <= 8 and st % 4 == 0
            if st in (0, 10) or (st == 7 and k % 2 == 0) or (big and st == 3 and k % 2 == 1) or floor: hit(kick, TN.KICK_DEEP, t, 1.0)
            if st in (4, 12): snare(t, 1.0)
            elif st in (7, 15) or (st == 9 and r_ == 'B'): snare(t, 0.22, [5, 2, 1])
            if st % 4 == 2: NZ['ohat'].hit(t, 1, [6, 5, 4, 3, 2, 1])
            else: NZ['hat'].hit(t, 1, [5, 2, 1] if st % 2 == 0 else [3, 1])
            if st == 0 and (k == 1 or (big and k % 4 == 1)): NZ['crash'].hit(t, 3, SB.CRASH)
            if last and st >= 12:
                hit(tom, W.TOMS[min(2, st - 12)], t, 0.7)
                if st >= 14: snare(t, 0.5 + (st - 14) * 0.15, [8 + (st - 14), 5, 2])
        if r_ == 'build' and k == 7:
            nf = int(2 * BAR * F.FPS)
            NZ['nrise'].hit(tv(b, 0), [int(12 - 9 * i / nf) for i in range(nf)], [int(1 + 9 * i / nf) for i in range(nf)])

    # ── STEMS ──
    n = int(round(NB * BAR * SR))
    at = int(round(SB.INTRO * BAR * SR))
    tail = 3 * SR
    cut = lambda x: (x[:n + tail] - np.mean(x[:n]))
    pulse = lambda k: cut(F.pulse_dac(F.render_pulse(Cn[k])))
    wave = lambda k: cut(F.render_wave(Cn[k], SB.WAVES) * 0.0075)
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    noise = lambda k: cut(F.tnd_dac(NZ[k].render() / 22638.0 * 12))
    S = {'bass': slap.render(n + tail), 'stabs': pulse('c1') + pulse('c2'), 'scr': pulse('scr'), 'pad': wave('pad1') + wave('pad2'),
         'hits': cut(F.pulse_dac(F.render_saw(Cn['h1']))) + cut(F.pulse_dac(F.render_saw(Cn['h2']))),
         'spark': GN.delay(pulse('spark'), 3 * S16, 0.35, 2, 4000),
         'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
         'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + noise('snare'),
         'hook': cut(F.pulse_dac(F.render_saw(Cn['hook']))), 'brass': pulse('b1') + pulse('b2'),
         'orch': cut(F.pulse_dac(F.render_saw(Cn['o1']))) + cut(F.pulse_dac(F.render_saw(Cn['o2']))),
         'hat': noise('hat'), 'ohat': noise('ohat'), 'crash': noise('crash'), 'nrise': noise('nrise')}
    L = n + tail
    for k, r in G.items():                                              # (cada capa GM adelantada lo que tarda su ataque, a tiempo)
        adv = M.attack_smp(r, 0.25 if k in ('strings', 'choir') or r.drums else 0.5)
        y = GM.cached(r, L)
        S[k] = np.concatenate([y[adv:], np.zeros(adv)])
    S = {k: GN.fold(x, n, at) for k, x in S.items() if np.abs(x).max() > 0}
    g = GN.level(S, {k: LV.get(k, -10) for k in S}, 'bass')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('stabs', 0.35) - sd('scr', 0.5) + sd('pad', 0.3) + sd('ohat', 0.3) - sd('hat', 0.2) + sd('spark', 0.5) - sd('hits', 0.15) \
        + sd('guit', 0.4) - sd('clav', 0.4) + sd('conga', 0.3) - sd('cow', 0.3) + sd('strings', 0.25) - sd('choir', 0.2) + sd('brass', 0.15) - sd('shak', 0.3)
    y = F.master(np.stack([x + side, x - side], 1), lufs=LUFS, ceiling=CEILING)
    info = dict(bass=bass, chords=chords, role=role, pos=pos, starts=starts, lead=lead_notes, secs=secs, NB=NB)
    return y, n, at, S, g, info


# ══ INFORME (números: NO se ha escuchado) ═══════════════════════════════════════════════════════════════════════════
def bar_similarity(mono, nb):
    """lo que mide la repetición: cada compás contra su gemelo más parecido del bucle (espectrograma mel correlado)"""
    import librosa
    B = int(round(BAR * SR))
    fs = []
    for b in range(nb):
        M_ = librosa.feature.melspectrogram(y=mono[b * B:(b + 1) * B], sr=SR, n_mels=32, hop_length=512)
        fs.append(librosa.power_to_db(M_, ref=1).flatten())
    X = np.array(fs); X = X - X.mean(1, keepdims=True); X /= np.linalg.norm(X, axis=1, keepdims=True)
    C = X @ X.T; np.fill_diagonal(C, 0)
    return C


def report(v, y, n, at, S, g, I):
    print(f'── groove variante {v} "{VNAME[v]}"')
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    lufs = F.loudness(y)
    nb = I['NB'] - SB.INTRO
    print(f'  intro 8 = {at} muestras ({at / SR:.2f} s) + bucle {nb} = {n - at} muestras ({(n - at) / SR:.2f} s = {(n - at) / (BAR * SR):.4f} compases) · {lufs:.1f} LUFS, pico {np.abs(y).max():.2f}')
    print(f'  energía: bajo {grp(("bass",)):.0f} %, batería {grp(("kick", "snare", "hat", "ohat", "crash", "toms", "timp", "clap", "cow", "conga", "shak", "tamb")):.0f} %, gancho + metal {grp(("hook", "brass")):.0f} %, GM de acompañar {grp(("guit", "clav", "strings", "choir", "orch")):.0f} %')
    print('  ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    # repetición
    rows = [(nm, i + 1, t) for nm, bars, h, rl in I['secs'] if nm != 'I' for i, t in enumerate(bars)]
    cnt = collections.Counter(r[2] for r in rows if r[2])
    print(f'  bajo: {len(cnt)} compases distintos de {len(rows)}; los 4 más usados, {100 * sum(c for _, c in cnt.most_common(4)) / len(rows):.0f} %')
    C = bar_similarity(y[at:].mean(1), nb)
    bm = C.max(1)
    print(f'  audio: compases con gemelo ≥ 0,95: {100 * np.mean(bm >= 0.95):.0f} %, ≥ 0,90: {100 * np.mean(bm >= 0.90):.0f} %; parecido medio {bm.mean():.3f}; a 4 compases {np.mean([C[i, i + 4] for i in range(nb - 4)]):.3f}')
    # armonía
    bad = sum((nn - I['chords'][b - 1][0]) % 12 in (1, 6) for b, st, nn, d, vl in I['bass'] if d >= 2)
    print(f'  bajo: notas de corchea o más a 2ª menor o tritono del acorde: {bad}')
    badh, cl = [], []
    for b, ns in I['lead'].items():
        r, q = I['chords'][b - 1]
        tones = {(r + i) % 12 for i in q}
        for st, nn, d in ns:
            if d >= 3 and nn % 12 not in tones: badh.append((b, st, J.nm(nn)))
            for bb, s2, n2, d2, vl in I['bass']:
                if bb == b and vl > 60 and max(st, s2) < min(st + d, s2 + d2) and min(st + d, s2 + d2) - max(st, s2) >= 2 and (nn - n2) % 12 in (1, 6, 11): cl.append((b, st, J.nm(nn), J.nm(n2)))
    print(f'  gancho y metal: largas fuera del acorde {badh or "ninguna"}; choques con el bajo (≥ corchea) {len(cl)} {cl[:6]}')
    B = BAR * SR
    ln, bars, jr, dbs, ji, dbi = M.seam_numbers(y, at, B, [(s[2] - 1) * B for s in I['starts'][2:]])
    print(f'  BUCLE: costura {jr:.2f}× otro tiempo 1 de sección, {dbs:+.1f} dB; intro → bucle {ji:.2f}×, {dbi:+.1f} dB')
    span = lambda s: (int((s[2] - 1) * B), int((s[2] - 1 + s[3]) * B))
    def db(s):
        a, b_ = span(s); z = y[a:b_]
        return 10 * np.log10(np.mean(z ** 2) + 1e-12)
    r0 = db(I['starts'][1])
    print('  sonoridad vs A (dB): ' + ' '.join(f'{s[0]} {db(s) - r0:+.1f}' for s in I['starts']))
    return dict(lufs=lufs, loop=n - at, bars=nb, tw95=np.mean(bm >= 0.95), tw90=np.mean(bm >= 0.90), mean=bm.mean(), dist=len(cnt), rows=len(rows), jr=jr)


def mmss(t):
    return f'{int(t // 60)}:{t % 60:04.1f}'


DESC = {'intro': ('SE QUEDA', 'INTRO: el bajo solo y luego la banda (igual; un toque de maraca)'),
        'A': ('MEJORADA', 'A: el riff, con 4 compases variados; cada 4 compases entra algo: guitarra funk, palmas y tumbadoras, clavinete y metal, cencerro y cuerda'),
        'B': ('SE QUEDA + capas', 'B: el bajo canta alto, las mismas notas; tumbadoras, palmas, cuerda, cierre de metal'),
        'solo': ('SE QUEDA + capas', 'SOLO: las paradas; golpe de orquesta y timbal; dos licks nuevos en la 2ª mitad'),
        'build': ('MEJORADA', 'SUBIDA: guitarra, metal con la cola, redoble de timbal'),
        'climax': ('MEJORADA', 'CLÍMAX: bombo a negras en la 1ª mitad, metal, cuerda, coro en la 2ª; las mismas notas del bajo salvo dos compases'),
        'dance': ('NUEVA', 'D LA PISTA: disco en Lam Re Sol Do, bajo en octavas, bombo a negras, gancho de metal'),
        'duel': ('NUEVA', 'K\' EL DUELO: el bajo pregunta, el metal contesta con la blue note'),
        'climax2': ('NUEVA', 'C\' EL CLÍMAX OTRA VEZ: otros compases de bajo, coro y el gancho de la pista'),
        'out': ('SE QUEDA + capas', 'VUELTA: 4 compases hacia el riff')}


def readme(results):
    t = ['EL GROOVE (mejora): el tema del Cangrejo Groove. tools/music/groove_mejora.py',
         'NO SE HA ESCUCHADO: comprobado solo con números. El oído es el tuyo. No está instalado; slap_boss.py sigue igual.',
         '', 'Mismo tempo (150), misma tonalidad y mismo slap de protagonista. Más instrumentos y menos repetición.', '',
         'ARCHIVOS por variante: groove_<v>_preview.mp3 (intro + bucle dos veces), _intro.ogg, _loop.ogg.', '']
    for v, I, r, n, at in results:
        t.append(f'VARIANTE {v} "{VNAME[v]}": 8 + {r["bars"]} compases, bucle {r["loop"] / SR:.1f} s, {r["lufs"]:.1f} LUFS; bajo {r["dist"]} compases distintos de {r["rows"]}; compases con gemelo ≥ 0,95: {100 * r["tw95"]:.0f} %')
        for s in I['starts']:
            k, d = DESC[s[1]]
            t.append(f'  {mmss((s[2] - 1) * BAR)}  [{k}] {d}')
        t.append(f'  {mmss(I["NB"] * BAR)}  segunda vuelta: los mismos tiempos + {mmss(r["bars"] * BAR)}')
        t.append('')
    t += ['Referencia, el tema actual: bajo 23 compases distintos de 68; compases con gemelo ≥ 0,95: 76 %.', '',
          'A JUZGAR DE OÍDO: si las capas le quitan sitio al slap (es lo que hace bueno al tema); si la pista suena a Groove o a otro tema;',
          'el gancho de metal (sobre todo con el GM Synth Brass); si el coro y la cuerda dan épica o empastan; si el tema sigue mandando con todo esto.']
    return '\n'.join(t) + '\n'


def enc_mp3(y, path):
    """la previa en MP3: el códec sube los picos; si pasan de 0,97, se baja SOLO la previa y se codifica otra vez"""
    import soundfile as sf
    wav = path[:-4] + '.wav'
    for _ in range(5):
        F.write_wav(wav, y)
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libmp3lame -b:a 320k "{path}"')
        pk = np.abs(sf.read(path)[0]).max()
        if pk < 0.97: break
        y = y * (0.94 / pk)
    os.remove(wav)


if __name__ == '__main__':
    which = [a for a in sys.argv[1:] if a in VNAME] or list(VNAME)
    if os.environ.get('INSTALL'): which = [os.environ.get('GROOVE', 'A')]
    os.makedirs(PRUEBAS, exist_ok=True)
    res = []
    for v in which:
        y, n, at, S, g, I = build(v)
        r = report(v, y, n, at, S, g, I)
        res.append((v, I, r, n, at))
        if os.environ.get('REPORT'): continue
        if os.environ.get('INSTALL'):
            J.export(y, at, os.path.join(INSTALL_DIR, 'groove'))
            continue
        base = os.path.join(PRUEBAS, f'groove_{v}_{VNAME[v]}')
        J.export(y, at, base)
        enc_mp3(np.concatenate([y, y[at:]]), base + '_preview.mp3')
    if not os.environ.get('REPORT') and not os.environ.get('INSTALL') and len(which) == len(VNAME):
        with open(os.path.join(PRUEBAS, 'LEEME.txt'), 'w') as f:
            f.write(readme(res))
        print(f'  previas en {PRUEBAS}')
