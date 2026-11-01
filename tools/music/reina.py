#!/usr/bin/env python3
# tools/music/reina.py — tema de jefe de LA REINA CARNÍVORA (jefe secreto del templo de la jungla: una planta enorme,
# tumbada, cuyas bocas brotan de paredes, suelo y techo). PREVIAS para elegir; no toca assets/ salvo con INSTALL=1 (nunca
# el index.json). Se comprueba con números: NO SE HA ESCUCHADO.
#
# v2. La v1 (el historial de git la guarda) la rechazó el usuario: "literalmente remixes del tema del Escarabajo". Lo que
# pidió: inspiración en el RITMO, los INSTRUMENTOS y el riff del templo; la estructura, la melodía y los acordes, propios.
# Así que esto es una canción con vida propia:
#   · SOL MENOR, 140 BPM (el Templo: Fa menor, 170). Sus acordes: i-iv-III-V (Solm Dom Sib Re), con dominante mayor de verdad;
#     estribillo que arranca en el VI (Mib Sib Dom Re). Giro oscuro: La♭ (♭II).
#   · SU RITMO: EL MORDISCO, 3+3+2+3+3+2 en un compás. Primo del riff del templo (2+3+3+3+3+2) y de la hemiolia de la jungla,
#     pero suyo: lo tocan a la vez el slap, el bombo y la melodía.
#   · SU MELODÍA principal, en todas las secciones menos dos.
#   · SU FORMA: INTRO 4 · A 16 · P 8 (el puente sube) · C 16 (estribillo) · D 8 (el bajo y las bocas) · A' 8 · C' 8 · R 4
#     = 4 + 68 compases.
#   · EL RIFF DEL TEMPLO, SOLO COMO CITA: 4 compases de 68, transportado (Re Re Mib Fa Sib Sib: el mismo papel que tiene sobre
#     el III en jungla_1) sobre el Sib de ESTA canción: al final del puente (lo llama el estribillo) y en mitad de la D.
#     Nunca con melodía encima.
#   · Paleta de la jungla: marimba, kalimba, flauta de pan, ocarina, congas, cabasa, agogó, taiko, tambores de tronco. Slap y
#     chip de la casa. LAS BOCAS, el acento propio: una voz hueca que cae y se cierra, en suelo, pared o techo.
#
# TRES VARIANTES (misma armonía, forma y banda; OTRA MELODÍA):
#   A "dientes"  melodía-riff en la sierra del VRC6 (la de Obsidiana): cada compás, EL MORDISCO subiendo por el acorde.
#   B "raices"   marimba + sierra: repetidas y por grados, una frase que se para en una nota con redoble, la siguiente la contesta.
#   C "flor"     flauta de pan cantada, notas largas sobre el mismo surco; ocarina en terceras.
#
#   ~/.venvs/fm-music/bin/python tools/music/reina.py [A B C] → previas en FlappyMonster_pruebas/musica/reina_v2/
#   REPORT=1 → solo números · INSTALL=1 REINA=A|B|C → assets/music/bosses/reina_intro|_loop.ogg
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR
import gloomy_nes as GN
import jungla_nes as J
import montana_nes as M
import slap as SL
import gm as GM

P, nm, place = M.P, J.nm, M.place
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/reina_v2'
INSTALL_DIR = os.path.join(F.MUSIC_DIR, 'bosses')
TRACK = 'reina'
BPM, LUFS, CEILING = 140, -10.0, 0.66
VNAME = {'A': 'dientes', 'B': 'raices', 'C': 'flor'}
SCALE = {7, 9, 10, 0, 2, 3, 5}                                        # Sol menor natural (Fa# solo en su Re mayor; La♭ solo en su acorde)
BITE = (0, 3, 6, 8, 11, 14)                                           # EL MORDISCO: 3+3+2+3+3+2

# ══ LA ARMONÍA ══════════════════════════════════════════════════════════════════════════════════════════════════════
H_IN = "Gm Cm Bb D"
H_A1, H_A2 = "Gm Cm Bb D Gm Cm Eb D", "Gm Cm Bb D Eb Cm D D"
H_P = "Eb Bb Cm Gm Ab Eb Bb Bb"                                       # el GIRO: La♭. Los dos últimos, la CITA del riff
H_C1, H_C2 = "Eb Bb Cm D Eb Bb D Gm", "Eb Bb Cm D Eb Bb D D"
H_D = "Gm Gm Eb Eb Bb Bb D D"                                         # (5 y 6, la cita otra vez)
H_R = "Gm Cm Bb D"
RIFF_Bb = "0:D5/2 2:D5/3 5:Eb5/3 8:F5/3 11:Bb4/3 14:Bb4/2"            # el riff del templo, sobre el III de esta canción

# ══ LAS MELODÍAS ════════════════════════════════════════════════════════════════════════════════════════════════════
_A = ["0:G5/3 3:D5/3 6:G5/2 8:Bb5/3 11:D6/3 14:Bb5/2", "0:C6/3 3:G5/3 6:C6/2 8:Eb6/3 11:G6/3 14:Eb6/2",
      "0:D6/3 3:Bb5/3 6:D6/2 8:F6/3 11:Bb6/3 14:F6/2"]
_B = ["0:G5/2 2:G5/1 3:Bb5/3 6:Bb5/2 8:A5/2 10:Bb5/1 11:G5/3 14:D5/2", "0:Eb5/3 3:G5/3 6:C6/10",
      "0:Bb5/2 2:Bb5/1 3:D6/3 6:D6/2 8:C6/2 10:D6/1 11:Bb5/3 14:F5/2", "0:F#5/3 3:A5/3 6:D6/10"]
_C = ["0:D6/6 6:Bb5/2 8:G5/8", "0:G5/3 3:C6/3 6:Eb6/2 8:G6/8", "0:F6/6 6:D6/2 8:Bb5/8"]
CB = ["0:Bb5/3 3:Eb6/3 6:G6/2 8:Bb6/3 11:G6/3 14:Eb6/2", "0:F6/3 3:D6/3 6:F6/2 8:Bb6/3 11:F6/3 14:D6/2"]
CR = ["0:Bb5/4 4:G5/2 6:Eb6/2 8:G6/4 12:F6/2 14:Eb6/2", "0:D6/4 4:Bb5/2 6:F6/2 8:Bb6/4 12:F6/2 14:D6/2"]
CF = ["0:G6/6 6:F6/2 8:Eb6/8", "0:F6/6 6:D6/2 8:Bb5/8"]
MEL = {
    'A': {'A1': _A + ["0:F#6/3 3:D6/3 6:A5/2 8:F#5/3 11:A5/3 14:D6/2"] + _A[:2] + ["0:Eb6/3 3:Bb5/3 6:Eb6/2 8:G6/3 11:Bb6/3 14:G6/2", "0:F#6/3 3:A6/3 6:F#6/2 8:D6/4"],
          'A2': _A + ["0:D6/3 3:F#6/3 6:A6/2 8:F#6/3 11:D6/3 14:A5/2", "0:G6/3 3:Eb6/3 6:Bb5/2 8:Eb6/3 11:G6/3 14:Bb6/2",
                      "0:G6/3 3:Eb6/3 6:C6/2 8:Eb6/3 11:C6/3 14:G5/2", "0:A5/3 3:D6/3 6:F#6/2 8:A6/3 11:F#6/3 14:D6/2", "0:A5/4"],
          'P': ["0:Bb5/6 6:G5/2 8:Eb6/8", "0:D6/6 6:Bb5/2 8:F5/8", "0:G5/6 6:Eb5/2 8:C6/8", "0:Bb5/6 6:G5/2 8:D5/8",
                "0:C6/6 6:Ab5/2 8:Eb6/8", "0:Bb5/6 6:G5/2 8:Eb5/8", "", ""],
          'C1': CB + ["0:Eb6/3 3:C6/3 6:Eb6/2 8:G6/3 11:Eb6/3 14:C6/2", "0:D6/3 3:F#6/3 6:A6/2 8:D7/6 14:A6/2"] + CB +
                ["0:A6/3 3:F#6/3 6:D6/2 8:F#6/3 11:A6/3 14:F#6/2", "0:G6/8"],
          'C2': CB + ["0:Eb6/3 3:C6/3 6:Eb6/2 8:G6/3 11:Eb6/3 14:C6/2", "0:D6/3 3:F#6/3 6:A6/2 8:D7/6 14:A6/2"] + CB +
                ["0:A6/3 3:F#6/3 6:D6/2 8:F#6/3 11:A6/3 14:F#6/2", "0:A6/3 3:F#6/3 6:D6/2 8:A5/4"]},
    'B': {'A1': _B + ["0:D6/2 2:D6/1 3:D6/3 6:Bb5/2 8:A5/2 10:Bb5/1 11:G5/3 14:D5/2", "0:G5/3 3:C6/3 6:Eb6/10",
                      "0:Eb6/2 2:Eb6/1 3:G6/3 6:Eb6/2 8:Bb5/3 11:G5/3 14:Bb5/2", "0:A5/3 3:D6/3 6:F#6/2 8:A6/8"],
          'A2': _B + ["0:G5/2 2:G5/1 3:Bb5/3 6:Eb6/2 8:G6/3 11:Eb6/3 14:Bb5/2", "0:C6/2 2:C6/1 3:Eb6/3 6:G6/10",
                      "0:F#6/2 2:F#6/1 3:D6/3 6:A5/2 8:F#5/3 11:A5/3 14:D6/2", "0:D6/4"],
          'P': ["3:Bb5/3 6:Eb6/2 8:G6/8", "3:F5/3 6:Bb5/2 8:D6/8", "3:G5/3 6:C6/2 8:Eb6/8", "3:D5/3 6:G5/2 8:Bb5/8",
                "3:Eb5/3 6:Ab5/2 8:C6/8", "3:Bb5/3 6:Eb6/2 8:G6/8", "", ""],
          'C1': CR + ["0:C6/4 4:G5/2 6:Eb6/2 8:G6/4 12:Eb6/2 14:C6/2", "0:F#6/4 4:D6/2 6:A5/2 8:F#6/8"] + CR +
                ["0:A6/4 4:F#6/2 6:D6/2 8:A5/4 12:D6/4", "0:Bb5/4 4:G5/4 8:D6/4"],
          'C2': CR + ["0:C6/4 4:G5/2 6:Eb6/2 8:G6/4 12:Eb6/2 14:C6/2", "0:F#6/4 4:D6/2 6:A5/2 8:F#6/8"] + CR +
                ["0:A6/4 4:F#6/2 6:D6/2 8:A5/4 12:F#5/4", "0:D6/8"]},
    'C': {'A1': _C + ["0:A5/3 3:D6/3 6:F#6/2 8:A6/8", "0:G6/6 6:D6/2 8:Bb5/8", "0:C6/6 6:G5/2 8:Eb6/8", "0:Bb5/3 3:Eb6/3 6:G6/2 8:Bb6/8", "0:A6/6 6:F#6/2 8:D6/8"],
          'A2': _C + ["0:F#6/6 6:D6/2 8:A5/8", "0:G5/3 3:Bb5/3 6:Eb6/2 8:G6/8", "0:Eb6/6 6:C6/2 8:G5/8", "0:A5/3 3:D6/3 6:F#6/2 8:A6/8", "0:F#6/4 4:D6/4"],
          'P': ["0:Eb6/8 8:Bb5/8", "0:D6/8 8:F5/8", "0:G5/8 8:Eb6/8", "0:D6/8 8:Bb5/8", "0:C6/8 8:Eb6/8", "0:Bb5/8 8:G5/8", "", ""],
          'C1': CF + ["0:C6/3 3:Eb6/3 6:G6/2 8:C7/8", "0:A6/6 6:F#6/2 8:D6/8"] + CF + ["0:D6/3 3:F#6/3 6:A6/2 8:D7/8", "0:Bb6/6 6:G6/2 8:D6/8"],
          'C2': CF + ["0:C6/3 3:Eb6/3 6:G6/2 8:C7/8", "0:A6/6 6:F#6/2 8:D6/8"] + CF + ["0:D6/3 3:F#6/3 6:A6/2 8:D7/8", "0:A6/8"]},
}


def sections(v):
    M_ = MEL[v]
    return [('intro', H_IN, [''] * 4, 16, ''), ('A', H_A1 + ' ' + H_A2, M_['A1'] + M_['A2'], 16, ''), ('P', H_P, M_['P'], 16, ''),
            ('C', H_C1 + ' ' + H_C2, M_['C1'] + M_['C2'], 16, ''), ('D', H_D, [''] * 8, 16, ''),
            ('A', H_A1, M_['A1'], 16, 'rep'), ('C', H_C2, M_['C2'], 16, 'rep'), ('R', H_R, [''] * 4, 16, '')]


J.TRACKS[TRACK] = dict(secs=sections, bpm=BPM, scale=SCALE, tonic=(7, M.MIN), lufs=LUFS, variants=tuple(VNAME), title='La Reina', vname=VNAME)

# ══ EL REPARTO ══════════════════════════════════════════════════════════════════════════════════════════════════════
MARIMBA, KALIMBA, PAN, OCARINA, TAIKO, LOGDRUM = J.P_MARIMBA, J.P_KALIMBA, J.P_PAN, J.P_OCARINA, J.P_TAIKO, J.P_LOGDRUM
ROOTS = {7: 31, 0: 36, 10: 34, 2: 38, 3: 39, 8: 32, 5: 41}
VSLAP, CLAP, RIM = 58, 39, 37
I_SAW = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.18, 6)}
I_SAWSOFT = {'vol': [9, 8, 7, 7, 6], 'sus': 6, 'vib': (20, 0.12, 5.4)}
I_UP = {'vol': [8, 7, 7, 6, 6, 5], 'sus': 5, 'duty': 0.25}
I_BOCA = {'vol': [13, 12, 9, 6, 3, 1], 'sus': 0, 'duty': 2, 'drop': [12, 8, 4, 1]}   # (voz hueca que CAE y se cierra)
LEADS = ('lead', 'lead2', 'thirds')


class Rig(M.Rig):
    def __init__(self, sg):
        super().__init__(sg)
        self.Cn['saw'] = F.Chan(len(self.Cn['lead'].f))
        self.slap = SL.Rec()
        for k in ('snare', 'crash'): self.NZ[k].exact = True
        self.riff_bars, self.bocas = set(), 0

    def sl(self, b, st, n, d, vel=100):
        sg = self.sg
        self.slap.add(sg.t(b, st), sg.t(b, st) + sg.dur(b, d) * 0.95, n, vel)
        self.notes.setdefault('bass', []).append((sg.q(b, st), sg.q(b, st + d), n))


def boca(sg, R, b, st, where):
    """UNA BOCA: 0 suelo · 1 pared · 2 techo. Muerde en la raíz del acorde y se oye dónde brota"""
    r = sg.chord(b, st)[0]
    lo = {0: 48, 1: 60, 2: 72}[where]
    key = ('boca0', 'boca1', 'boca2')[where]
    R.Cn.setdefault(key, F.Chan(len(R.Cn['lead'].f)))
    F.play(R.Cn[key], sg.t(b, st), sg.t(b, st) + sg.dur(b, 2), lo + (r - lo) % 12, I_BOCA, q=F.q_n163, release=1)
    R.dr('vslap', b, st, VSLAP, {0: 70, 1: 82, 2: 94}[where])
    if where == 0: R.gm('taiko', TAIKO, b, st, 36 + (r - 36) % 12, 3, 106)
    R.bocas += 1


def quote(sg, R, b):
    """LA CITA del riff del templo: marimba + kalimba, sin nada que cante encima"""
    R.riff_bars.add(b)
    for _, st, n, d in P(b, RIFF_Bb):
        R.gm('riff', MARIMBA, b, st, n, d, 110); R.gm('riff', KALIMBA, b, st, n + 12, d, 80)


def bass_bar(sg, R, b, heavy=False):
    """EL MORDISCO en el slap: raíz · pop · 5ª · raíz · pop · la que se acerca al acorde siguiente"""
    root = lambda st: ROOTS[sg.chord(b, st)[0]]
    nr = (sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0])[0]
    if nr != sg.chord(b, 14)[0]:
        n2 = ROOTS[nr]
        c = [p for p in (n2 - 2, n2 + 2, n2 - 1, n2 + 1) if p % 12 in SCALE | sg.tones(b, 14) and not R.rub(b, 14, p, 2, voice=LEADS)]
        ap = c[0] if c else root(14) + 7
    else: ap = root(14) + 7
    for st, n, d, vv in ((0, root(0), 3, 112), (3, root(3) + 12, 3, 122), (6, root(6) + 7, 2, 100), (8, root(8), 3, 108), (11, root(11) + 12, 3, 122), (14, ap, 2, 96)):
        R.sl(b, st, n, d, vv)
    if heavy:
        for st, vv in ((2, 50), (5, 50), (10, 50), (13, 50)): R.sl(b, st, root(st), 1, vv)


def drums(sg, R, b, tag, k, L, big):
    """EL SURCO: bombo en el mordisco, caja en 2 y 4, congas y agogó que le contestan, cabasa"""
    rep = sg.var[b - 1] == 'rep'
    for st in range(16):
        if st in (0, 3, 8, 11) or (big and st in (6, 14)): R.kick(b, st, 1.0 if st in (0, 8) else 0.8)
        if st in (4, 12): R.snare(b, st, 0.95 if big or k > 8 else 0.8)
        if st in (6, 14, 15): R.dr('congas', b, st, J.CONGA_O if st == 6 else J.CONGA_L, 92)
        if st in (2, 10) and (big or k > 4): R.dr('congas', b, st, J.CONGA_M, 72)
        if (big or k > 8) and st in (0, 3, 6, 10, 12): R.dr('bell', b, st, J.AGOGO_H if st in (0, 6) else J.AGOGO_L, 66)
        R.dr('shaker', b, st, J.MARACAS if big else J.CABASA, 62 if st % 4 == 2 else 42)
        if big and st % 4 == 2: R.NZ['hat'].hit(sg.t(b, st), 1, J.HAT)
    if k == 1 or k == 9 or (big and k % 4 == 1):
        R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)
        R.gm('taiko', TAIKO, b, 0, 36 + (sg.chord(b, 0)[0] - 36) % 12, 4, 108)
    if k == L:
        for st in (12, 13, 14, 15): R.dr('timb', b, st, J.TIMB_H if st < 14 else J.TIMB_L, 92 + 2 * st)


def arrange(sg, R, v):
    thirds = set()
    for b, st, n, d in sg.mel:
        tag, var = sg.tag[b - 1], sg.var[b - 1]
        strong = tag == 'C' or var == 'rep'
        if v == 'A':
            R.chip('saw', b, st, n - 12, d, I_SAW, q=F.q_saw, release=3)
            R.notes.setdefault('lead', []).append((sg.q(b, st), sg.q(b, st + d), n)); R.notes['saw'].pop()
            if strong:
                R.gm('lead2', MARIMBA, b, st, n, min(d, 3), 96)
                if n + 12 <= 96: R.chip('dbl', b, st, n + 12, d, I_UP, release=2); R.notes['dbl'].pop()
        elif v == 'B':
            d16 = sg.q(b, st + d) - sg.q(b, st)
            if d16 >= 4:                                               # el redoble en la nota larga
                x, kk = 0.0, 0
                while x < d - 0.01:
                    R.G.setdefault('lead', M.Rec(MARIMBA)).add(sg.t(b, st) + sg.dur(b, x), sg.t(b, st) + sg.dur(b, x + 1), n, max(66, 112 - 4 * kk - (10 if kk % 2 else 0)))
                    x += 1; kk += 1
                R.notes.setdefault('lead', []).append((sg.q(b, st), sg.q(b, st + d), n))
            else:
                R.gm('lead', MARIMBA, b, st, n, d, 112)
            R.chip('saw', b, st, n - 12, d, I_SAWSOFT, q=F.q_saw, release=2); R.notes['saw'].pop()
            if strong: R.gm('lead2', KALIMBA, b, st, n + 12 if n + 12 <= 96 else n, min(d, 2), 70)
        else:
            R.gm('lead', PAN, b, st, n, d, 106 if strong else 98, gate=0.97)
            R.chip('cm', b, st, n - 12, d, J.I_WOOD, q=F.q_n163, release=3); R.notes['cm'].pop()
            if strong: thirds.add(b)
    if thirds: J.thirds(sg, R, thirds, OCARINA, 78)
    for b in range(1, sg.NB + 1):
        tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        rep = var == 'rep'
        big = tag == 'C' or rep
        if tag == 'P' and k >= 7: quote(sg, R, b)
        if tag == 'D' and k in (5, 6): quote(sg, R, b)
        # EL SLAP
        if tag == 'intro':
            if k >= 3: bass_bar(sg, R, b)
            else: R.sl(b, 0, ROOTS[sg.chord(b, 0)[0]], 8, 112)
        else: bass_bar(sg, R, b, heavy=big or tag == 'D')
        # KALIMBA (contratiempos) y MARIMBA de acompañar (el arpegio en el mordisco); nunca bajo la cita
        if b not in R.riff_bars and tag in ('A', 'P', 'C', 'R'):
            for st in (2, 10):
                for n in place(None, sg.chord(b, st), 67)[1:3]:
                    if not R.rub(b, st, n, 2, voice=LEADS): R.gm('kal', KALIMBA, b, st, n, 2, 64)
        if big or tag == 'P':
            if b not in R.riff_bars and v != 'B':
                for i, st in enumerate(BITE):
                    n = place(None, sg.chord(b, st), 55)[(0, 2, 3, 1, 2, 3)[i]]
                    if not R.rub(b, st, n, 2, voice=LEADS): R.gm('marimba', MARIMBA, b, st, n, 2, 74 + (10 if st in (0, 8) else 0))
            H = 8
            for half in (0, 1):
                r, q = sg.chords[b - 1][half]
                base = 53 + (r - 53) % 12
                for j, iv in enumerate(q[1:]):
                    R.chip(('pad1', 'pad2')[j], b, half * H, base + iv, H, M.I_PAD, q=F.q_n163, gate=0.97, release=5)
        # LAS BOCAS: donde la melodía calla
        free = not [m for m in sg.mel if m[0] == b and m[1] + m[3] > 12]
        if tag == 'intro' and k <= 2:
            for st, w in ((0, 0), (6, 1), (12, 2)): boca(sg, R, b, st, w)
        elif tag in ('A', 'C') and free: boca(sg, R, b, 12, 1 + b % 2); boca(sg, R, b, 14, 0)
        elif tag == 'D' and k not in (5, 6):
            for st, w in ((4, 1), (12, 2)): boca(sg, R, b, st, w)
        elif tag == 'R': boca(sg, R, b, 8, (k - 1) % 3)
        # BATERÍA
        if tag == 'intro':
            for st in range(16):
                if st in (0, 3, 8, 11) and k >= 3: R.kick(b, st, 0.85)
                if st % 3 == 0: R.gm('logs', LOGDRUM, b, st, 43 + (0, 3, 7)[(st // 3) % 3], 2, 88)
                if k >= 2: R.dr('shaker', b, st, J.CABASA, 56 if st % 4 == 2 else 36)
                if k == L and st >= 12: R.dr('timb', b, st, J.TIMB_H if st < 14 else J.TIMB_L, 96)
        elif tag == 'D':
            for st in range(16):                                       # los tambores contestan al slap
                if st in (0, 8): R.kick(b, st)
                if st in (6, 14): R.gm('taiko', TAIKO, b, st, 36 + (sg.chord(b, st)[0] - 36) % 12, 3, 100)
                if st % 3 == 0: R.gm('logs', LOGDRUM, b, st, 43 + (0, 3, 7, 10, 7, 3)[(st // 3) % 6], 2, 94)
                if st in (2, 5, 9, 13): R.dr('congas', b, st, J.CONGA_O if st % 2 else J.CONGA_M, 90)
                if k > 2: R.dr('shaker', b, st, J.MARACAS, 60 if st % 4 == 2 else 40)
                if k >= 7 and st in (4, 12): R.snare(b, st, 0.85)
                if k == L and st >= 8: R.snare(b, st, 0.35 + 0.05 * (st - 8))
            if k == 1: R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)
        elif tag == 'R':
            for st in range(16):
                if st in (0, 8) and k <= 3: R.kick(b, st, 0.85)
                if st % 3 == 0: R.gm('logs', LOGDRUM, b, st, 43 + (0, 3, 7)[(st // 3) % 3], 2, 84)
                R.dr('shaker', b, st, J.CABASA, 54 if st % 4 == 2 else 34)
                if k == L and st >= 10: R.dr('timb', b, st, J.TIMB_H if st < 13 else J.TIMB_L, 84 + 5 * (st - 10))
        else:
            drums(sg, R, b, tag, k, L, big)


# ══ LA MEZCLA ═══════════════════════════════════════════════════════════════════════════════════════════════════════
LV = {'bass': 0, 'lead': -3, 'lead2': -8, 'thirds': -5, 'saw': -7, 'cm': -10, 'dbl': -11, 'riff': 1, 'marimba': -6, 'kal': -9, 'pad': -12, 'logs': -5,
      'boca': -3, 'kick': -2, 'snare': -2, 'congas': -5, 'taiko': -3, 'timb': -7, 'bell': -11, 'shaker': -14, 'vslap': -9, 'hat': -13, 'crash': -8}
DRUMS = ('kick', 'snare', 'congas', 'taiko', 'timb', 'bell', 'shaker', 'vslap', 'hat', 'crash', 'logs')


def build(v):
    sg = J.Song(TRACK, v)
    R = Rig(sg)
    arrange(sg, R, v)
    assert not [m for m in sg.mel if m[0] in R.riff_bars], 'una melodía sobre la cita'
    n = int(round(sg.NB * sg.BAR * SR))
    at = int(round(sg.INTRO * sg.BAR * SR))
    L = n + 5 * SR
    S = M.render_stems(R, n, L, True, at / SR)
    def cut(x):
        x = x[:L] - np.mean(x[:n])
        return np.concatenate([x, np.zeros(L - len(x))]) if len(x) < L else x
    y = GM.cached(R.slap, L)
    S['bass'] = np.concatenate([y[M.GM_LAT:], np.zeros(M.GM_LAT)])
    saw = cut(F.pulse_dac(F.render_saw(R.Cn['saw'])))
    if v == 'A': S['lead'] = saw
    else: S['saw'] = saw
    wave = lambda k: cut(F.render_wave(R.Cn[k], M.WAVES) * 0.0075) if k in R.Cn else np.zeros(L)
    b0, b1, b2 = wave('boca0'), wave('boca1'), wave('boca2')
    S['boca'] = b0 + b1 + b2
    from scipy.signal import butter, sosfilt
    hp = butter(2, 30, btype='high', fs=SR, output='sos')
    S = {k: sosfilt(hp, x) for k, x in S.items() if np.abs(x).max() > 0}
    g = GN.level(S, {k: LV.get(k, -10) for k in S}, 'bass')
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    gb = g.get('boca', 0)
    side = sd('riff', 0.15) + sd('kal', 0.35) - sd('marimba', 0.25) + sd('bell', 0.35) - sd('shaker', 0.3) + sd('congas', 0.2) - sd('logs', 0.2) \
        + sd('thirds', 0.2) + sd('lead2', 0.2) + (sosfilt(hp, b1) * 0.45 - sosfilt(hp, b2) * 0.45) * gb
    st = np.stack([GN.fold(x + side, n, at), GN.fold(x - side, n, at)], 1)
    st = F.master(st, lufs=LUFS, ceiling=CEILING)
    S = {k: GN.fold(s, n, at) for k, s in S.items()}
    return sg, R, S, g, st, n, at


# ══ INFORME (números: NO se ha escuchado) ═══════════════════════════════════════════════════════════════════════════
def report(v, sg, R, S, g, y, n, at):
    print(f'── reina variante {v} "{VNAME[v]}"')
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    lufs = F.loudness(y)
    B = sg.BAR * SR
    nb = sg.NB - sg.INTRO
    print(f'  intro {sg.INTRO} = {at} muestras ({at / SR:.2f} s) + bucle {nb} = {n - at} muestras ({(n - at) / SR:.2f} s = {(n - at) / B:.4f} compases) · {lufs:.1f} LUFS, pico {np.abs(y).max():.2f}')
    print(f'  energía: melodía {grp(("lead", "lead2", "thirds", "saw", "cm", "dbl")):.0f} %, bajo {grp(("bass",)):.0f} %, batería {grp(DRUMS):.0f} %, cita {grp(("riff",)):.1f} %, bocas {grp(("boca",)):.1f} %')
    print('  ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    rb = sorted(R.riff_bars)
    print(f'  cita del riff: {len(rb)} de {nb} compases ({100 * len(rb) / nb:.0f} %), a los ' + ', '.join(mmss((b - 1) * sg.BAR) for b in rb[::2]))
    lb, lo, out, off = J.check(sg)
    mel = sg.mel
    per = {}
    for m in mel: per.setdefault(m[0], []).append(m)
    bars = sorted(per)
    bl = [abs(per[b + 1][0][2] - per[b][-1][2]) for b in bars if b + 1 in per]
    rhy = {}
    for b in bars:
        key = tuple(m[1] for m in per[b]); rhy[key] = rhy.get(key, 0) + 1
    locked = np.mean([m[1] in BITE for m in mel])
    print(f'  melodía: {len(mel)} notas {nm(min(m[2] for m in mel))}-{nm(max(m[2] for m in mel))}, en {100 * len(bars) / nb:.0f} % de los compases · del acorde {100 * np.mean([m[2] % 12 in sg.tones(m[0], m[1]) for m in mel]):.0f} %, tiempo 1 {100 * np.mean([m[2] % 12 in sg.tones(m[0], 0) for m in mel if m[1] == 0]):.0f} % · sobre los golpes del mordisco {100 * locked:.0f} %')
    print(f'    entre compases {np.mean(bl):.1f} st ({100 * np.mean(np.array(bl) <= 2):.0f} % ≤ 2) · ritmos {len(rhy)}, los 3 más usados {100 * sum(sorted(rhy.values())[-3:]) / len(bars):.0f} %')
    print(f'    largas fuera del acorde: {lb or "ninguna"}; sueltas: {lo or "ninguna"}; fuera de escala: {out or "ninguna"}')
    cnt = 0
    for k, notes in R.notes.items():
        if k in LEADS or k in ('taiko', 'logs') or not notes: continue
        cl = J.clashes(sg, mel, notes)
        cnt += len(cl)
        if cl: print(f'    choques melodía / {k} (≥ corchea): {len(cl)} {cl[:5]}')
    print(f'    choques melodía / resto: {cnt}')
    badb = [q for q in R.notes['bass'] if q[1] - q[0] >= 2 and q[0] % 16 != 14 and (q[2] - sg.chord(int(q[0] // 16) + 1, q[0] % 16)[0]) % 12 not in (0, 7)]
    print(f'    bajo: {len(R.notes["bass"])} notas; de corchea o más ni raíz ni 5ª (sin contar la de acercarse, en la 14): {len(badb)} {[(int(q[0] // 16) + 1, nm(q[2])) for q in badb[:5]]}')
    ln, bars_, jr, dbs, ji, dbi = M.seam_numbers(y, at, B, [(s - 1) * B for s in sg.starts[2:]])
    print(f'  BUCLE: costura {jr:.2f}× otro tiempo 1 de sección, {dbs:+.1f} dB; intro → bucle {ji:.2f}×, {dbi:+.1f} dB')
    def db(s, l):
        z = y[int((s - 1) * B):int((s - 1 + l) * B)]
        return 10 * np.log10(np.mean(z ** 2) + 1e-12)
    r0 = db(sg.starts[1], 16)
    print('  sonoridad vs A (dB): ' + ' '.join(f'{sg.tag[s - 1]} {db(s, sg.slen[s - 1]) - r0:+.1f}' for s in sg.starts))
    return dict(lufs=lufs, loop=n - at, intro=at, bars=bars_, nlb=len(lb), nlo=len(lo), ncl=cnt, cita=len(rb))


def mmss(t):
    return f'{int(t // 60)}:{t % 60:04.1f}'


def readme(sg, nums):
    desc = {'intro': 'INTRO: tambores de tronco, bocas; el slap entra en el 3º', 'A': 'A: EL TEMA, sobre Solm Dom Sib Re, en el mordisco 3+3+2+3+3+2',
            'P': 'P: el puente, notas largas; el giro La♭; los dos últimos compases, LA CITA DEL RIFF DEL TEMPLO (sin melodía)',
            'C': 'C: EL ESTRIBILLO, lo más alto', 'D': 'D: el slap, los tambores y las bocas; en sus compases 5-6, LA CITA otra vez', 'R': 'R: se vacía y vuelve'}
    t = ['LA REINA CARNÍVORA (v2): tema de jefe. tools/music/reina.py',
         'NO SE HA ESCUCHADO: comprobado solo con números. El oído es el tuyo. No está instalado.', '',
         'Una canción propia, no un remix del Escarabajo: Sol menor, 140 BPM, sus acordes, su forma, su ritmo (EL MORDISCO: 3+3+2+3+3+2 en slap,',
         'bombo y melodía) y su melodía. Del templo: la paleta de jungla, el aire del ritmo y el riff SOLO como cita, 4 compases de 68.', '',
         'VARIANTES (misma armonía, forma y banda; otra melodía):',
         '  A dientes  melodía-riff en la sierra del VRC6: cada compás el mordisco subiendo por el acorde.',
         '  B raices   marimba + sierra: repetidas y por grados, se para en una nota con redoble; la frase siguiente contesta.',
         '  C flor     flauta de pan cantada, notas largas sobre el mismo surco; ocarina en terceras en lo fuerte.', '',
         'ARCHIVOS por variante: reina_<v>_preview.mp3 (intro + bucle dos veces), _intro.ogg, _loop.ogg.', '', 'SECCIONES (iguales en las tres):']
    for s in sg.starts:
        t.append(f'  {mmss((s - 1) * sg.BAR)}  {desc[sg.tag[s - 1]]}' + ('  (la vuelta, con más banda)' if sg.var[s - 1] == 'rep' else ''))
    lp = (sg.NB - sg.INTRO) * sg.BAR
    t.append(f'  {mmss(sg.NB * sg.BAR)}  segunda vuelta: los mismos tiempos + {mmss(lp)}')
    t += [f'  {mmss((sg.NB + sg.NB - sg.INTRO) * sg.BAR)}  fin de la previa', '', 'NÚMEROS:'] + nums
    t += ['', 'A JUZGAR DE OÍDO: si suena a canción propia o aún al Escarabajo; si la melodía encaja o se fuerza (dime en qué tiempo); si la cita se reconoce y entra con',
          'naturalidad; si el mordisco, con bajo y melodía a la vez, baila o pesa; las bocas (¿muerden o molestan?).']
    return '\n'.join(t) + '\n'


def enc_mp3(y, path):
    """la previa en MP3; si el códec pasa de 0,97, se baja SOLO la previa"""
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
    if os.environ.get('INSTALL'): which = [os.environ.get('REINA', 'A')]
    os.makedirs(PRUEBAS, exist_ok=True)
    nums = []
    for v in which:
        sg, R, S, g, y, n, at = build(v)
        r = report(v, sg, R, S, g, y, n, at)
        nums.append(f'  {v} {VNAME[v]}: intro {r["intro"] / SR:.2f} s + bucle {r["loop"]} muestras ({r["loop"] / SR:.2f} s = {r["bars"]:.4f} compases), {r["lufs"]:.1f} LUFS; cita en {r["cita"]} compases; largas fuera {r["nlb"]}, sueltas {r["nlo"]}, choques {r["ncl"]}')
        if os.environ.get('REPORT'): continue
        if os.environ.get('INSTALL'):
            J.export(y, at, os.path.join(INSTALL_DIR, TRACK))
            continue
        base = os.path.join(PRUEBAS, f'{TRACK}_{v}_{VNAME[v]}')
        J.export(y, at, base)
        enc_mp3(np.concatenate([y, y[at:]]), base + '_preview.mp3')
    if not os.environ.get('REPORT') and not os.environ.get('INSTALL') and len(which) == len(VNAME):
        with open(os.path.join(PRUEBAS, 'LEEME.txt'), 'w') as f:
            f.write(readme(sg, nums))
        print(f'  previas en {PRUEBAS}')
