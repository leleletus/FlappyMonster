#!/usr/bin/env python3
# tools/music/reina.py — tema de jefe de LA REINA CARNÍVORA (jefe secreto del templo de la jungla: una planta enorme,
# tumbada, cuyas bocas brotan de paredes, suelo y techo). PREVIAS para elegir; no toca assets/ salvo con INSTALL=1 (nunca
# el index.json). Se comprueba con números: NO SE HA ESCUCHADO.
#
# El usuario: muy inspirado en los temas de NIVEL de la jungla (jungla_nes.py), con su toque propio de jefe, y SOBRE TODO en
# el trozo de Temple Tumble del Escarabajo: EL RIFF de templo.py (Do Do Do# Re# Sol# Sol#, 0·2·5·8·11·14, Fa menor).
#   · El riff se IMPORTA de templo.py, con sus notas, sus acordes medidos (Reb Mib Sibm Fam…) y su línea larga.
#   · LA REGLA del Templo: "el riff ES la melodía" (cuatro voces encima, rechazadas). Aquí NINGUNA melodía suena a la vez
#     que el riff (se comprueba: una aserción en build); solo la línea larga de la referencia, que ya estaba aprobada.
#   · Como en el Templo, la canción NO empieza con el riff: va en mitad y vuelve en el clímax.
#   · De la jungla: Fa menor, Reb Mib Fam (VI VII i), giro oscuro Solb, flauta de pan con ocarina en terceras, marimba en
#     3+3+3+3+2+2, kalimba, congas, tumbao, cabasa, campana africana 2-2-1-2-2-2-1 en 12/8, tucán y ave nocturna.
#   · LO PROPIO: LAS BOCAS, un chasquido que muerde (voz hueca del N163 que cae una octava + vibraslap + taiko) y que brota en
#     tres sitios: SUELO (grave, centro), PARED (medio, a un lado) y TECHO (agudo, al otro); solo donde nadie canta. Y la V,
#     LA ENREDADERA: 8 compases en 12/8 al mismo pulso, sin riff.
#
# TRES VARIANTES (misma armonía y forma; 168, compás de 63 000 muestras):
#   A "enredadera"  tema en hemiolia (flauta y ocarina en terceras). El riff, entero y desnudo, en marimba + kalimba.
#   B "bocas"       tema con el RITMO DEL RIFF (2+3+3+3+3+2), en marimba; el riff, en DIÁLOGO: la cabeza a un lado y la cola al
#                   otro, con una boca entre las dos; en el clímax, entero.
#   C "balafon"     tema en 12/8, marimba con redobles (de jungla_2); de ahí el riff entra en 4/4 de golpe; en el clímax el slap
#                   toca SU RITMO en la raíz.
#
# Forma: INTRO 8 (tambores y bocas; el bajo en el 5º) · T 16 (tema) · R 16 (EL RIFF con la línea larga) · K 8 (corro de
# tambores y trozos del riff) · V 8 (12/8) · S 8 (subida con el riff) · C 16 (riff y línea, todo) · O 4 = 8 + 76 compases.
#
#   ~/.venvs/fm-music/bin/python tools/music/reina.py [A B C] → previas en FlappyMonster_pruebas/musica/reina/
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
import templo as TP
import gm as GM

CH, P, nm, place = M.CH, M.P, J.nm, M.place
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/reina'
INSTALL_DIR = os.path.join(F.MUSIC_DIR, 'bosses')
TRACK = 'reina'
BPM, LUFS, CEILING = 168, -10.0, 0.66
VNAME = {'A': 'enredadera', 'B': 'bocas', 'C': 'balafon'}
SCALE = TP.SCALE

# ══ LA ARMONÍA ══════════════════════════════════════════════════════════════════════════════════════════════════════
H_IN = "Fm Fm Fm Fm Fm Fm Db Eb"
H_T = "Db Eb Fm Fm Bbm Cm Db|Eb Fm " + "Db Eb Bbm Cm Db Eb Gb Fm"     # jungla_1; el GIRO OSCURO: Solb → Fam
H_R = ' '.join(TP.H_A)                                                # (los acordes medidos de la referencia)
H_K = "Fm " * 8
H_V = "Bbm Bbm Fm Fm Db Db Cm Cm"
H_S = "Db Db Eb Eb Bbm Bbm Cm Cm"
H_O = "Fm Fm Db Eb"

# ══ EL TEMA (nunca junto al riff), según la variante ════════════════════════════════════════════════════════════════
LL_16 = "0:C5/4 4:F5/2 6:Ab5/2 8:C6/8"                                # LA LLAMADA (Do-Fa-Lab-Do), lleva al riff
T_MEL = {
    'A': ["0:F5/3 3:Ab5/3 6:Db6/3 9:C6/2 11:Bb5/1 12:Ab5/4", "0:G5/3 3:Bb5/3 6:Eb6/3 9:C6/2 11:Bb5/1 12:G5/4",
          "0:Ab5/3 3:C6/3 6:F6/3 9:Eb6/2 11:Db6/1 12:C6/4", "0:C6/6 6:Ab5/2 8:F5/4",
          "0:F5/3 3:Bb5/3 6:Db6/3 9:F6/3 12:Db6/4", "0:Eb6/3 3:C6/3 6:G5/3 9:C6/3 12:Eb6/4",
          "0:F6/3 3:Db6/3 6:Ab5/2 8:Bb5/3 11:Eb6/3 14:G6/2", "0:Ab6/4 4:F6/4 8:C6/4",
          "0:F5/3 3:Ab5/3 6:Db6/3 9:C6/2 11:Bb5/1 12:Ab5/4", "0:G5/3 3:Bb5/3 6:Eb6/3 9:C6/2 11:Bb5/1 12:G5/4",
          "0:Bb5/3 3:Db6/3 6:F6/3 9:F6/2 11:Eb6/1 12:Db6/4", "0:C6/3 3:Eb6/3 6:G6/3 9:G6/2 11:F6/1 12:Eb6/4",
          "0:F6/3 3:Ab6/3 6:F6/3 9:Db6/3 12:Ab5/4", "0:G5/3 3:Bb5/3 6:Eb6/3 9:G6/3 12:Eb6/4",
          "0:Db6/3 3:Bb5/3 6:Gb5/3 9:Bb5/3 12:Db6/4", LL_16],
    # B: cada compás, en el ritmo del riff; subiendo el acorde, repitiendo la primera nota como él
    'B': ["0:F5/2 2:F5/3 5:Ab5/3 8:Db6/3 11:Ab5/3 14:F5/2", "0:G5/2 2:G5/3 5:Bb5/3 8:Eb6/3 11:Bb5/3 14:G5/2",
          "0:Ab5/2 2:Ab5/3 5:C6/3 8:F6/3 11:C6/3 14:Ab5/2", "0:C6/2 2:C6/3 5:C6/3 8:Ab5/4",
          "0:Db6/2 2:Db6/3 5:F6/3 8:F6/3 11:Db6/3 14:Bb5/2", "0:Eb6/2 2:Eb6/3 5:G6/3 8:Eb6/3 11:C6/3 14:G5/2",
          "0:Ab5/2 2:Ab5/3 5:Db6/3 8:Eb6/3 11:G6/3 14:Bb6/2", "0:Ab6/2 2:F6/3 5:C6/3 8:Ab5/4",
          "0:F5/2 2:F5/3 5:Ab5/3 8:Db6/3 11:Ab5/3 14:F5/2", "0:G5/2 2:G5/3 5:Bb5/3 8:Eb6/3 11:Bb5/3 14:G5/2",
          "0:Bb5/2 2:Bb5/3 5:Db6/3 8:F6/3 11:Db6/3 14:Bb5/2", "0:C6/2 2:C6/3 5:Eb6/3 8:G6/3 11:Eb6/3 14:C6/2",
          "0:Db6/2 2:Db6/3 5:F6/3 8:Ab6/3 11:F6/3 14:Db6/2", "0:Eb6/2 2:Eb6/3 5:G6/3 8:Bb6/3 11:G6/3 14:Eb6/2",
          "0:Db6/2 2:Db6/3 5:Bb5/3 8:Gb5/3 11:Bb5/3 14:Db6/2", LL_16],
    # C: en 12 corcheas: dos repetidas de mazo, sube, se posa; rueda (lo largo, en redoble)
    'C': ["0:F5/1 1:F5/1 2:Ab5/1 3:Db6/3 6:C6/1 7:Bb5/1 8:Ab5/1 9:F5/3", "0:G5/1 1:G5/1 2:Bb5/1 3:Eb6/3 6:C6/1 7:Bb5/2 9:G5/3",
          "0:Ab5/1 1:Ab5/1 2:C6/1 3:F6/3 6:Eb6/1 7:Db6/1 8:C6/1 9:Ab5/3", "0:C6/6 6:F5/1 7:Ab5/1 8:C6/1 9:F6/3",
          "0:F6/1 1:F6/1 2:Db6/1 3:Bb5/3 6:Db6/1 7:F6/2 9:Db6/3", "0:Eb6/1 1:Eb6/1 2:C6/1 3:G5/3 6:C6/1 7:Eb6/2 9:G6/3",
          "0:F6/1 1:Eb6/1 2:Db6/1 3:Ab5/3 6:Bb5/1 7:Eb6/2 9:G6/3", "0:F6/6 6:C6/3 9:Ab5/3",
          "0:F5/1 1:F5/1 2:Ab5/1 3:Db6/3 6:C6/1 7:Bb5/1 8:Ab5/1 9:F5/3", "0:G5/1 1:G5/1 2:Bb5/1 3:Eb6/3 6:C6/1 7:Bb5/2 9:G5/3",
          "0:Bb5/1 1:Bb5/1 2:Db6/1 3:F6/3 6:Eb6/1 7:Db6/2 9:Bb5/3", "0:C6/1 1:C6/1 2:Eb6/1 3:G6/3 6:F6/1 7:Eb6/2 9:C6/3",
          "0:Db6/1 1:Db6/1 2:F6/1 3:Ab6/3 6:F6/1 7:Db6/2 9:Ab5/3", "0:Eb6/1 1:Eb6/1 2:G6/1 3:Bb6/3 6:G6/1 7:Eb6/2 9:Bb5/3",
          "0:Db6/1 1:Bb5/1 2:Gb5/1 3:Bb5/3 6:Db6/1 7:Bb5/2 9:Gb5/3", "0:C5/3 3:F5/2 5:Ab5/1 6:C6/6"],
}
# V, LA ENREDADERA (12/8): el shakuhachi, notas largas que trepan
V_MEL = ["0:F5/6 6:Db6/5 11:C6/1", "0:Bb5/6 6:F5/6", "0:Ab5/6 6:C6/5 11:Bb5/1", "0:Ab5/6 6:F5/6",
         "0:F5/6 6:Ab5/6", "0:Db6/6 6:F6/6", "0:Eb6/6 6:G6/6", "0:G6/3 3:Eb6/3 6:C6/6"]


def sections(v):
    return [('intro', H_IN, [''] * 8, 16, ''), ('T', H_T, T_MEL[v], 12 if v == 'C' else 16, ''), ('R', H_R, [''] * 16, 16, ''),
            ('K', H_K, [''] * 8, 16, ''), ('V', H_V, V_MEL, 12, ''), ('S', H_S, [''] * 8, 16, ''), ('C', H_R, [''] * 16, 16, ''),
            ('O', H_O, [''] * 4, 16, '')]


J.TRACKS[TRACK] = dict(secs=sections, bpm=BPM, scale=SCALE, tonic=(5, M.MIN), lufs=LUFS, variants=tuple(VNAME), title='La Reina', vname=VNAME)

# ══ EL REPARTO ══════════════════════════════════════════════════════════════════════════════════════════════════════
MARIMBA, KALIMBA, PAN, OCARINA, BOTTLE, SHAKU, TAIKO = J.P_MARIMBA, J.P_KALIMBA, J.P_PAN, J.P_OCARINA, J.P_BOTTLE, 77, J.P_TAIKO
ROOTS = {5: 41, 1: 37, 3: 39, 10: 34, 0: 36, 6: 42, 8: 44}
VSLAP, CLAP, RIM, SNARE, CRASH_GM = 58, 39, 37, 38, 49
I_BOCA = {'vol': [13, 12, 9, 6, 3, 1], 'sus': 0, 'duty': 2, 'drop': [12, 8, 4, 1]}   # (voz hueca que CAE y se cierra)
I_PAD = M.I_PAD


class Rig(M.Rig):
    def __init__(self, sg):
        super().__init__(sg)
        self.slap = SL.Rec()
        for k in ('snare', 'crash'): self.NZ[k].exact = True
        self.riff_bars = set()
        self.bocas = 0

    def sl(self, b, st, n, d, vel=100):
        sg = self.sg
        self.slap.add(sg.t(b, st), sg.t(b, st) + sg.dur(b, d) * 0.95, n, vel)
        self.notes.setdefault('bass', []).append((sg.q(b, st), sg.q(b, st + d), n))


def boca(sg, R, b, st, where):
    """UNA BOCA: 0 suelo · 1 pared · 2 techo. Muerde en la raíz del acorde (nota del acorde: rule 9), y se oye dónde brota"""
    r = sg.chord(b, st)[0]
    lo = {0: 48, 1: 60, 2: 72}[where]
    n = lo + (r - lo) % 12
    key = ('boca0', 'boca1', 'boca2')[where]
    R.Cn.setdefault(key, F.Chan(len(R.Cn['lead'].f)))
    F.play(R.Cn[key], sg.t(b, st), sg.t(b, st) + sg.dur(b, 2), n, I_BOCA, q=F.q_n163, release=1)
    R.dr('vslap', b, st, VSLAP, {0: 66, 1: 78, 2: 90}[where])
    if where == 0: R.gm('taiko', TAIKO, b, st, 36 + (r - 36) % 12, 3, 104)
    R.bocas += 1


def riff_bar(sg, R, b, v, tag, k):
    c = sg.chord(b, 0)
    fm = c == (5, M.MIN)
    txt = TP.RIFF_F if fm else TP.RIFF
    R.riff_bars.add(b)
    ev = M.P(b, txt)
    dialog = v == 'B' and tag in ('R', 'S') and not (tag == 'R' and k > 8)
    vel = {'R': 104, 'S': 82 + 3 * k, 'C': 108, 'K': 96}.get(tag, 100)
    for _, st, n, d in ev:
        if dialog and st >= 8:                                         # (la cola, al otro lado, en kalimba + marimba arriba)
            R.gm('riff2', KALIMBA, b, st, n, d, vel); R.gm('riffr', MARIMBA, b, st, n, d, int(vel * 0.75))
        elif dialog:
            R.gm('riff', MARIMBA, b, st, n, d, vel)
        else:
            R.gm('riff', MARIMBA, b, st, n, d, vel); R.gm('riff2', KALIMBA, b, st, n, d, int(vel * 0.8))
        if v == 'C' and tag == 'C':                                    # el slap toca SU RITMO en raíz y octava (sus notas, abajo, chocarían con el acorde)
            r0 = ROOTS[c[0]]
            R.sl(b, st, r0 + {0: 0, 2: 12, 5: 0, 8: 7, 11: 12, 14: 0}[st], d, 122 if st in (2, 11) else 106)


def bass_16(sg, R, b, tag, k, hot=False):
    r0 = ROOTS[sg.chord(b, 0)[0]]
    if tag in ('R', 'S'):                                              # el de la referencia: corcheas; en el par, octavas
        if k % 2:
            for st in range(0, 16, 2): R.sl(b, st, r0, 2, 104 if st % 4 == 0 else 92)
        else:
            for st, iv, d, vv in ((0, 0, 2, 104), (2, 12, 1, 122), (3, 0, 1, 48), (4, 0, 2, 96), (6, 12, 1, 122), (7, 0, 1, 48), (8, 0, 2, 100), (10, 0, 2, 92), (12, 12, 1, 122), (13, 0, 1, 48), (14, 0, 2, 96)):
                R.sl(b, st, r0 + iv, d, vv)
        return
    pat = ((0, 0, 2, 106), (2, 12, 1, 122), (3, 0, 1, 48), (4, 7, 2, 96), (6, 0, 1, 90), (7, 0, 1, 48), (8, 0, 2, 104), (10, 12, 1, 122), (11, 0, 1, 48), (12, 7, 2, 96), (14, 12, 1, 122))
    if hot: pat = ((0, 0, 2, 110), (2, 12, 1, 122), (3, 0, 1, 48), (4, 7, 1, 98), (5, 12, 1, 122), (6, 0, 1, 90), (7, 0, 1, 48), (8, 0, 2, 106), (10, 12, 1, 122), (11, 0, 1, 48), (12, 7, 1, 98), (13, 12, 1, 122), (14, 7, 1, 96))
    for st, iv, d, vv in pat:
        R.sl(b, st, ROOTS[sg.chord(b, st)[0]] + iv, d, vv)
    nr = (sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0])[0]
    if nr != sg.chord(b, 15)[0]:
        n2 = ROOTS[nr]
        c = [p for p in (n2 - 2, n2 + 2, n2 - 1, n2 + 1) if p % 12 in SCALE | sg.tones(b, 15)]
        R.sl(b, 15, c[0] if c else ROOTS[sg.chord(b, 15)[0]] + 7, 1, 92)


def bass_12(sg, R, b):
    for st, iv, d, vv in ((0, 0, 2, 108), (2, 0, 1, 56), (3, 12, 2, 120), (5, 0, 1, 56), (6, 7, 2, 98), (8, 0, 1, 56), (9, 12, 2, 118), (11, 0, 1, 80)):
        R.sl(b, st, ROOTS[sg.chord(b, st)[0]] + iv, d, vv)


def drums_16_tema(sg, R, b, k):
    big = k > 8
    for st in range(16):
        if st in (0, 10) or (big and st == 7): R.kick(b, st, 1.0 if st == 0 else 0.85)
        if st in (4, 12):
            if big: R.snare(b, st, 0.85)
            else: R.dr('rim', b, st, RIM, 88)
        if st in (4, 6, 12, 14, 15): R.dr('congas', b, st, (J.CONGA_M, J.CONGA_O, J.CONGA_O, J.CONGA_L, J.CONGA_L)[(4, 6, 12, 14, 15).index(st)], 90 if st in (6, 14) else 76)
        R.dr('shaker', b, st, J.MARACAS if big else J.CABASA, 66 if st % 4 == 2 else 46)
        if st % 4 == 2: R.NZ['hat'].hit(sg.t(b, st), 1, J.HAT if big else [4, 1])
    if k in (1, 9): R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N); R.gm('taiko', TAIKO, b, 0, 41, 4, 104)


def drums_ref(sg, R, b, k, big):
    """la batería de la referencia (bombo 1 · 7 · 9 · 14; congas 3 y 13; palmas en 7 y 10): deja sitio al riff; en el clímax, caja"""
    for st in range(16):
        if st in (0, 6, 8, 13): R.kick(b, st, 1.0 if st in (0, 8) else 0.8)
        if st in (2, 12): R.dr('congas', b, st, J.CONGA_O if st == 2 else J.CONGA_L, 98)
        if st in (5, 11) and not big: R.dr('congas', b, st, J.BONGO_H, 58)
        if big and st in (4, 12): R.snare(b, st, 0.95)
        if st in (6, 9): R.dr('clap', b, st, CLAP, 88 if not big else 74)
        R.dr('shaker', b, st, J.MARACAS, 66 if st % 4 == 0 else 48 if st % 2 == 0 else 36)
        if not big and ((st in (0, 3, 6, 10, 12) and b % 2 == 1) or (st in (2, 8) and b % 2 == 0)): R.dr('bell', b, st, J.AGOGO_H if st in (0, 6, 2) else J.AGOGO_L, 62)
        if big and st % 4 == 2: R.NZ['hat'].hit(sg.t(b, st), 1, J.HAT)
    if big and k % 2 == 1: R.gm('taiko', TAIKO, b, 0, 36 + (sg.chord(b, 0)[0] - 36) % 12, 4, 110)
    if k == 1 or (big and k % 4 == 1) or k == 9: R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)


def drums_12(sg, R, b, k, tag):
    big = tag == 'T' and k > 8
    for st in range(12):
        if st in (0, 2, 4, 5, 7, 9, 11): R.dr('bell', b, st, J.AGOGO_H if st in (0, 7) else J.AGOGO_L, 80 if st == 0 else 66)
        R.dr('shaker', b, st, J.CABASA, 56 if st % 3 else 72)
        if st in (1, 4, 7): R.dr('congas', b, st, J.CONGA_M, 72)
        if st in (3, 10): R.dr('congas', b, st, J.CONGA_O, 90)
        if st in (9, 11): R.dr('congas', b, st, J.CONGA_L, 86)
        if st in (0, 6): R.kick(b, st, 1.0 if st == 0 else 0.85)
        if big and st in (3, 9): R.snare(b, st, 0.85)
        if not big and st in (3, 9): R.dr('rim', b, st, RIM, 76)
    if k in (1, 5): R.gm('taiko', TAIKO, b, 0, 36 + (sg.chord(b, 0)[0] - 36) % 12, 3, 104)
    if k in (1, 9): R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)


def arrange(sg, R, v):
    # ── EL TEMA y la enredadera ──
    for b, st, n, d in sg.mel:
        tag = sg.tag[b - 1]
        if tag == 'V':
            R.gm('lead', SHAKU, b, st, n, d, 96, gate=0.97)
        elif v == 'A':
            R.gm('lead', PAN, b, st, n, d, 100, gate=0.97)
            R.chip('cm', b, st, n - 12, d, J.I_WOOD, q=F.q_n163, release=3)
        elif v == 'B':
            R.gm('lead', MARIMBA, b, st, n, d, 110); R.gm('lead2', KALIMBA, b, st, n, min(d, 2), 62)
        else:
            d16 = sg.q(b, st + d) - sg.q(b, st)
            if d16 >= 4:                                               # el redoble del balafón
                x, kk = 0.0, 0
                while x < d - 0.01:
                    R.G.setdefault('lead', M.Rec(MARIMBA)).add(sg.t(b, st) + sg.dur(b, x), sg.t(b, st) + sg.dur(b, x + 0.5), n, max(60, 110 - 6 * kk - (12 if kk % 2 else 0)))
                    x += 0.5; kk += 1
                R.notes.setdefault('lead', []).append((sg.q(b, st), sg.q(b, st + d), n))
            else:
                R.gm('lead', MARIMBA, b, st, n, d, 110)
            R.gm('lead2', KALIMBA, b, st, n + 12 if n + 12 <= 96 else n, min(d, 2), 58)
    if v == 'A':
        J.thirds(sg, R, {b for b in range(1, sg.NB + 1) if sg.tag[b - 1] == 'T' and sg.pos[b - 1] > 8}, OCARINA, 78)
    # ── EL RESTO ──
    for b in range(1, sg.NB + 1):
        tag, k, L = sg.tag[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        twelve = sg.steps[b - 1] == 12
        # EL RIFF
        if tag in ('R', 'S', 'C'): riff_bar(sg, R, b, v, tag, k)
        if tag == 'K' and k >= 7: riff_bar(sg, R, b, v, 'K', k)
        if tag == 'K' and k in (1, 2, 5, 6):                           # (solo la cabeza; luego, tambores)
            R.riff_bars.add(b)
            for _, st, n, d in M.P(b, TP.RIFF_F):
                if st < 8: R.gm('riff', MARIMBA, b, st, n, d, 96); R.gm('riff2', KALIMBA, b, st, n, d, 76)
        # LA LÍNEA LARGA de la referencia (flauta de pan en octavas): debajo del riff, como en el Templo
        if tag in ('R', 'C') and TP.LINEA[k - 1][0]:
            for _, st, n, d in M.P(b, TP.LINEA[k - 1][0]):
                R.G.setdefault('flute', M.Rec(PAN)).add(sg.t(b, st), sg.t(b, st) + d * sg.BAR / 16 - 0.02, n, 92 if tag == 'C' else 86)
            for _, st, n, d in M.P(b, TP.LINEA[k - 1][1]):
                R.G.setdefault('flute', M.Rec(PAN)).add(sg.t(b, st), sg.t(b, st) + d * sg.BAR / 16 - 0.02, n, 70)
        # EL BAJO
        if tag == 'intro':
            if k >= 5: bass_16(sg, R, b, tag, k)
        elif tag == 'K':
            if k >= 3: bass_16(sg, R, b, tag, k)
        elif twelve: bass_12(sg, R, b)
        elif not (v == 'C' and tag == 'C'): bass_16(sg, R, b, tag, k, hot=tag == 'C')
        # ACOMPAÑAMIENTO: marimba en hemiolia y kalimba, en el tema (o, en 12/8, la kalimba que rueda). NUNCA con el riff
        if tag == 'T' and not twelve:
            if v != 'B':
                for st, deg in ((0, 0), (3, 2), (6, 3), (9, 1), (12, 2), (14, 1)):
                    n = place(None, sg.chord(b, st), 55)[deg]
                    if not R.rub(b, st, n, 3): R.gm('marimba', MARIMBA, b, st, n, 3, 86 if st == 0 else 66)
            for st in (2, 10):
                for n in place(None, sg.chord(b, st), 67)[1:3]:
                    if not R.rub(b, st, n, 2): R.gm('kal', KALIMBA, b, st, n, 2, 60)
        if twelve:
            for st in range(12):
                n = place(None, sg.chord(b, st), 60)[(0, 1, 2, 3, 2, 1)[st % 6]]
                if not R.rub(b, st, n, 1): R.gm('kal', KALIMBA, b, st, n, 1, 68 if st % 3 == 0 else 52)
        if tag in ('T', 'V', 'C') or (tag == 'S' and k > 4):           # colchón N163
            H = sg.steps[b - 1] // 2
            for half in (0, 1):
                r, q = sg.chords[b - 1][half]
                base = 53 + (r - 53) % 12
                for j, iv in enumerate(q[1:]):
                    R.chip(('pad1', 'pad2')[j], b, half * H, base + iv, H, I_PAD, q=F.q_n163, gate=0.97, release=5)
        # ACENTOS de la jungla: el tucán en el tema, el ave en la enredadera, donde se posa la voz
        if tag == 'T' and not twelve: J.toucan(sg, R, b, 70)
        if tag == 'V' and k % 2 == 0:
            r, q = sg.chord(b, 9); f5 = 72 + (r + 7 - 72) % 12
            if not R.rub(b, 8, f5, 2): R.gm('accent', BOTTLE, b, 8, f5, 2, 76)
            if not R.rub(b, 10, f5 - 4, 2): R.gm('accent', BOTTLE, b, 10, f5 - 7 + q[1] + 12 if f5 - 7 + q[1] + 12 < f5 else f5 - 7 + q[1], 2, 68)
        # LAS BOCAS: en lo que queda libre
        if tag == 'intro':
            if k <= 4:
                for st, w in ((0, 0), (6, 1), (12, 2)) if k % 2 else ((0, 0), (3, 1), (6, 2), (12, 0)): boca(sg, R, b, st, w)
        elif tag == 'R' and v == 'B' and k <= 8: boca(sg, R, b, 7, 1 if k % 2 else 2)     # (entre la cabeza y la cola: 5+3 = 8, en su silencio de ataque)
        elif tag == 'R' and k in (4, 12): boca(sg, R, b, 15, 2)
        elif tag == 'K' and k in (3, 4, 7, 8):
            for st, w in ((0, 0), (8, 1 + (k % 2))): boca(sg, R, b, st, w)
        elif tag == 'V' and k % 4 == 0: boca(sg, R, b, 9, 0)
        elif tag == 'C' and k in (8, 16):
            for st, w in ((12, 0), (14, 2)): boca(sg, R, b, st, w)
        elif tag == 'O': boca(sg, R, b, 8, (k - 1) % 3)
        # BATERÍA
        if tag == 'intro':
            for st in range(16):
                if k >= 3: R.dr('shaker', b, st, J.MARACAS, 56 if st % 4 == 0 else 38)
                if k >= 2 and st in (10, 13, 14): R.dr('congas', b, st, J.CONGA_O if st % 2 else J.CONGA_L, 78 + 4 * k)
                if k >= 5:
                    if st in (0, 6, 8, 13): R.kick(b, st, 0.85)
                    if st in (2, 12): R.dr('congas', b, st, J.CONGA_O, 88)
                    if st in (6, 9): R.dr('clap', b, st, CLAP, 70)
                if k == 8 and st >= 12: R.dr('timb', b, st, J.TIMB_H if st < 14 else J.TIMB_L, 96)
            if k == 5: R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)
            continue
        if twelve: drums_12(sg, R, b, k, tag)
        elif tag == 'T': drums_16_tema(sg, R, b, k)
        elif tag == 'R': drums_ref(sg, R, b, k, False)
        elif tag == 'C': drums_ref(sg, R, b, k, True)
        elif tag == 'K':                                               # el corro
            for st in range(16):
                if st in (0, 6, 12) or (k % 2 == 0 and st == 10): R.gm('taiko', TAIKO, b, st, 41 if st != 10 else 45, 4, 114 if st == 0 else 96)
                if k % 2 == 1 and st in (2, 3, 5, 9, 10, 13, 14): R.dr('congas', b, st, (J.CONGA_O, J.CONGA_M, J.CONGA_L)[st % 3], 94)
                if k % 2 == 0 and st in (1, 2, 4, 7): R.dr('wood', b, st, J.WOOD_H if st < 3 else J.WOOD_L, 88)
                if k >= 3: R.dr('shaker', b, st, J.MARACAS, 58 if st % 4 == 0 else 38)
                if k >= 5 and st in (0, 8): R.kick(b, st)
                if k >= 5 and st in (6, 9): R.dr('clap', b, st, CLAP, 80)
                if k == L and st >= 8: R.dr('timb', b, st, J.TIMB_H if (st - 8) % 3 < 2 else J.TIMB_L, 80 + 4 * (st - 8))
        elif tag == 'S':
            for st in range(16):
                if st % 4 == 0: R.kick(b, st)
                step = 4 if k <= 3 else (2 if k <= 6 else 1)
                if st % step == 0: R.snare(b, st, 0.3 + 0.06 * k + 0.015 * st)
                if st % 2 == 0: R.dr('timb', b, st, J.TIMB_H if st % 4 else J.TIMB_L, 50 + 5 * k)
                R.dr('shaker', b, st, J.MARACAS, 56 if st % 4 == 0 else 36)
        elif tag == 'O':
            for st in range(16):
                if st in (0, 6, 12): R.gm('taiko', TAIKO, b, st, 36 + (sg.chord(b, st)[0] - 36) % 12, 4, 100)
                if st in (2, 12): R.dr('congas', b, st, J.CONGA_O if st == 2 else J.CONGA_L, 86)
                R.dr('shaker', b, st, J.MARACAS, 56 if st % 4 == 0 else 36)
                if k == L and st >= 10: R.dr('timb', b, st, J.TIMB_H if st < 13 else J.TIMB_L, 84 + 5 * (st - 10))
        if k == L and tag in ('T', 'R', 'C') and not twelve:
            for st in (12, 13, 14, 15): R.dr('timb', b, st, J.TIMB_H if st < 14 else J.TIMB_L, 96)


# ══ LA MEZCLA ═══════════════════════════════════════════════════════════════════════════════════════════════════════
LV = {'bass': 0, 'riff': 3, 'riff2': -1, 'riffr': -2, 'flute': -3, 'lead': 2, 'lead2': -7, 'thirds': -3, 'cm': -10, 'marimba': -5, 'kal': -9, 'pad': -12,
      'accent': -4, 'boca': -3, 'kick': -2, 'snare': -3, 'congas': -5, 'clap': -6, 'rim': -6, 'taiko': -3, 'timb': -7, 'bell': -11, 'shaker': -14,
      'wood': -6, 'vslap': -9, 'hat': -13, 'crash': -8}
DRUMS = ('kick', 'snare', 'congas', 'clap', 'rim', 'taiko', 'timb', 'bell', 'shaker', 'wood', 'vslap', 'hat', 'crash')


def build(v):
    sg = J.Song(TRACK, v)
    R = Rig(sg)
    arrange(sg, R, v)
    n = int(round(sg.NB * sg.BAR * SR))
    at = int(round(sg.INTRO * sg.BAR * SR))
    L = n + 5 * SR
    # LA REGLA: ninguna melodía suena a la vez que el riff
    assert not [m for m in sg.mel if m[0] in R.riff_bars], 'una melodía sobre el riff'
    S = M.render_stems(R, n, L, True, at / SR)
    def cut(x):
        x = x[:L] - np.mean(x[:n])
        return np.concatenate([x, np.zeros(L - len(x))]) if len(x) < L else x
    y = GM.cached(R.slap, L)
    S['bass'] = np.concatenate([y[M.GM_LAT:], np.zeros(M.GM_LAT)])
    # las bocas: una voz por sitio, cada una con su lado
    wave = lambda k: cut(F.render_wave(R.Cn[k], M.WAVES) * 0.0075) if k in R.Cn else np.zeros(L)
    b0, b1, b2 = wave('boca0'), wave('boca1'), wave('boca2')
    S['boca'] = b0 + b1 + b2
    from scipy.signal import butter, sosfilt
    hp = butter(2, 30, btype='high', fs=SR, output='sos')
    S = {k: sosfilt(hp, x) for k, x in S.items() if np.abs(x).max() > 0}
    # (el riff, igual de delante en las tres: en B su cabeza y su cola van en capas separadas y la medida cambia)
    OFF = {'A': 1.0, 'B': -1.0, 'C': 1.0}[v]
    g = GN.level(S, {k: LV.get(k, -10) + (OFF if k in ('riff', 'riff2', 'riffr') else 0) for k in S}, 'bass')
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    gb = g.get('boca', 0)
    side = -sd('riff', 0.25) + sd('riff2', 0.25) + sd('riffr', 0.3) + sd('kal', 0.35) - sd('marimba', 0.2) + sd('bell', 0.35) - sd('shaker', 0.3) + sd('congas', 0.2) \
        - sd('wood', 0.3) + sd('thirds', 0.2) - sd('flute', 0.15) + sd('accent', 0.3) + (sosfilt(hp, b1) * 0.45 - sosfilt(hp, b2) * 0.45) * gb
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
    print(f'  intro {sg.INTRO} = {at} muestras ({at / SR:.2f} s) + bucle {sg.NB - sg.INTRO} = {n - at} muestras ({(n - at) / SR:.2f} s = {(n - at) / B:.4f} compases) · {lufs:.1f} LUFS, pico {np.abs(y).max():.2f}')
    print(f'  energía: riff {grp(("riff", "riff2", "riffr")):.0f} %, melodía {grp(("lead", "lead2", "thirds", "cm")):.0f} %, línea {grp(("flute",)):.0f} %, bajo {grp(("bass",)):.0f} %, batería {grp(DRUMS):.0f} %, bocas {grp(("boca",)):.1f} %')
    print('  ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    lp = [b for b in R.riff_bars if b > sg.INTRO]
    print(f'  riff: {len(lp)} de {sg.NB - sg.INTRO} compases del bucle ({100 * len(lp) / (sg.NB - sg.INTRO):.0f} %); 1ª vez a los {(min(lp) - 1) * sg.BAR:.1f} s; melodías sobre él: 0 (aserción); bocas {R.bocas}')
    from scipy.signal import butter, sosfilt
    bp = butter(2, [400, 3000], btype='band', fs=SR, output='sos')
    rs = sum(S[k] * g[k] for k in ('riff', 'riff2', 'riffr') if k in S)
    rest = sum(S[k] * g[k] for k in S if k not in ('riff', 'riff2', 'riffr'))
    for tag in ('R', 'C'):
        i = sg.starts[['intro', 'T', 'R', 'K', 'V', 'S', 'C', 'O'].index(tag)]
        a, b_ = int((i - 1) * B), int((i + 15) * B)
        print(f'    en {tag}, 400 Hz-3 kHz: riff {20 * np.log10(np.sqrt(np.mean(sosfilt(bp, rs[a:b_]) ** 2)) / np.sqrt(np.mean(sosfilt(bp, rest[a:b_]) ** 2))):+.1f} dB frente a todo lo demás')
    lb, lo, out, off = J.check(sg)
    mel = [m for m in sg.mel if sg.tag[m[0] - 1] == 'T']
    print(f'  tema: {len(mel)} notas, del acorde {100 * np.mean([m[2] % 12 in sg.tones(m[0], m[1]) for m in mel]):.0f} %, tiempo 1 {100 * np.mean([m[2] % 12 in sg.tones(m[0], 0) for m in mel if m[1] == 0]):.0f} %; {nm(min(m[2] for m in mel))}-{nm(max(m[2] for m in mel))}')
    print(f'    largas fuera del acorde: {lb or "ninguna"}; sueltas: {lo or "ninguna"}; fuera de escala: {out or "ninguna"}')
    cnt = 0
    for k, notes in R.notes.items():
        if k in ('lead', 'lead2', 'taiko', 'cm') or not notes: continue
        cl = J.clashes(sg, sg.mel, notes)
        cnt += len(cl)
        if cl: print(f'    choques melodía / {k} (≥ corchea): {len(cl)} {cl[:5]}')
    print(f'    choques melodía / resto: {cnt}')
    badb = [q for q in R.notes['bass'] if q[1] - q[0] >= 2 and (q[2] - sg.chord(int(q[0] // 16) + 1, (q[0] % 16) * sg.steps[int(q[0] // 16)] / 16)[0]) % 12 not in (0, 7)]
    print(f'    bajo: {len(R.notes["bass"])} notas; de corchea o más ni raíz ni 5ª: {len(badb)}')
    ln, bars, jr, dbs, ji, dbi = M.seam_numbers(y, at, B, [(s - 1) * B for s in sg.starts[2:]])
    print(f'  BUCLE: costura {jr:.2f}× otro tiempo 1 de sección, {dbs:+.1f} dB; intro → bucle {ji:.2f}×, {dbi:+.1f} dB')
    def db(s, l):
        z = y[int((s - 1) * B):int((s - 1 + l) * B)]
        return 10 * np.log10(np.mean(z ** 2) + 1e-12)
    r0 = db(sg.starts[1], 16)
    print('  sonoridad vs T (dB): ' + ' '.join(f'{sg.tag[s - 1]} {db(s, sg.slen[s - 1]) - r0:+.1f}' for s in sg.starts))
    return dict(lufs=lufs, loop=n - at, intro=at, bars=bars, jr=jr, nlb=len(lb), nlo=len(lo), ncl=cnt, riff=len(lp))


def mmss(t):
    return f'{int(t // 60)}:{t % 60:04.1f}'


def readme(sg, nums):
    desc = {'intro': 'INTRO: tambores y las bocas (suelo, pared, techo); el bajo entra a la mitad. Sin riff',
            'T': 'T: EL TEMA, sin riff (A flautas · B marimba en el ritmo del riff · C marimba en 12/8). Giro oscuro Solb y la llamada',
            'R': 'R: EL RIFF de Temple Tumble, con su línea larga. Ninguna melodía encima (B: la cabeza y la cola en diálogo, 8 compases)',
            'K': 'K: corro de tambores, trozos del riff, bocas',
            'V': 'V: LA ENREDADERA, en 12/8: shakuhachi, campana, ave nocturna. Sin riff',
            'S': 'S: SUBIDA con el riff que va a más',
            'C': 'C: CLÍMAX: el riff y la línea con toda la banda (C: el slap toca el ritmo del riff)',
            'O': 'O: se vacía y vuelve al tema'}
    t = ['LA REINA CARNÍVORA: tema de jefe. tools/music/reina.py',
         'NO SE HA ESCUCHADO: comprobado solo con números. El oído es el tuyo. No está instalado.', '',
         'El riff del Escarabajo (Temple Tumble) es tal cual el de templo.py. Por lo aprendido allí, NINGUNA melodía suena a la vez que él.',
         'Fa menor, 168 BPM. Slap en todo. Lo propio del jefe: LAS BOCAS (un mordisco que brota en el suelo, una pared o el techo).', '',
         'VARIANTES (misma armonía y forma; otra melodía, otro uso del riff):',
         '  A enredadera  tema en hemiolia, flauta de pan y ocarina en terceras. El riff entero y desnudo.',
         '  B bocas       el tema ES el ritmo del riff, en marimba. El riff, en diálogo: cabeza a un lado, cola al otro, una boca entre medias.',
         '  C balafon     tema en 12/8, marimba con redobles; del 12/8 cae al riff en 4/4. En el clímax, el slap toca su ritmo.', '',
         'ARCHIVOS por variante: reina_<v>_preview.mp3 (intro + bucle dos veces), _intro.ogg, _loop.ogg.', '', 'SECCIONES (iguales en las tres):']
    for s in sg.starts: t.append(f'  {mmss((s - 1) * sg.BAR)}  {desc[sg.tag[s - 1]]}')
    lp = (sg.NB - sg.INTRO) * sg.BAR
    t.append(f'  {mmss(sg.NB * sg.BAR)}  segunda vuelta: los mismos tiempos + {mmss(lp)}')
    t += [f'  {mmss((sg.NB + sg.NB - sg.INTRO) * sg.BAR)}  fin de la previa', '', 'NÚMEROS:'] + nums
    t += ['', 'A JUZGAR DE OÍDO: si el riff manda de verdad; si el tema de cada variante te suena a la misma canción que el riff o "forzado" (dime en qué tiempo);',
          'las bocas (¿muerden o molestan?); el paso 12/8 ↔ 4/4; el riff sobre Reb a 168 (la referencia iba a 170).']
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
        nums.append(f'  {v} {VNAME[v]}: intro {r["intro"] / SR:.2f} s + bucle {r["loop"]} muestras ({r["loop"] / SR:.2f} s = {r["bars"]:.4f} compases), {r["lufs"]:.1f} LUFS; riff en {r["riff"]} compases; largas fuera {r["nlb"]}, sueltas {r["nlo"]}, choques {r["ncl"]}')
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
