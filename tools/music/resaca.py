#!/usr/bin/env python3
# tools/music/resaca.py — REWORK general de "Resaca", el tema del Pez Globo Gigante (jefe de la costa). El usuario
# eligió la A "galerna": INSTALL=1 RESACA=A la instala (el index.json, aparte). NO SE HA ESCUCHADO.
#
# El usuario: "un super rework general" que conserve el slap bass, "con otro ritmo y melodía
# diferente para que suenen bien, armónico, boss like y disfrutablemente épico".
#
# LO QUE SE QUEDA: el SONIDO del slap (slap.py: el mismo Slap Bass GM de TimGM6mb) y las VOCES en crunch (el mismo archivo
# de resaca.py, final_fall.VOX). Fa# menor y el registro grave del bajo.
# LO QUE CAMBIA: todo lo demás.
#   · EL RITMO: de los 181 BPM en 3+3+2 a un 12/8 de GALOPE, una saloma de tormenta: 4 pulsos de negra con puntillo a 126
#     (compás de 84 000 muestras justas), cada pulso "LAAR-go corto" (2+1). El mar empuja y se retira.
#   · LA ARMONÍA se mueve de verdad y el bajo con ella: i-VI-III-VII (Fa#m Re La Mi) y una DOMINANTE real, Do# mayor, que
#     da la cadencia épica. Giro oscuro (uno): Sol mayor (♭II) → Do#.
#   · EL STEEL DRUM, la voz de la costa en el juego, contesta en los huecos de la melodía (las voces croppeadas que pidió al
#     principio se probaron y el usuario las descartó al elegir la A; la versión anterior: FlappyMonster_originals/music/versiones/).
#   · El reparto épico sobre el de la casa: coro y trémolo de cuerda en los estribillos, metal en los pulsos, timbales
#     en la raíz, taiko. Voz: la SIERRA del VRC6, la elegida en Obsidiana, una octava abajo, y pulso en las fuertes.
#     De la costa: maracas en corcheas y la marimba que sube (su motivo) en la sección K.
#
# TRES VARIANTES con la misma armonía y forma y DISTINTA melodía:
#   A "galerna"  melodía-riff: el galope sube por el acorde, en secuencia (lo que funcionó en Obsidiana B).
#   B "himno"    himno: notas largas en los pulsos, por grados y saltos de 5ª; el bajo galopa debajo.
#   C "saloma"   llamada y respuesta: media frase de la voz y otra media de los gritos, como una canción de marineros.
#
# Forma: INTRO 4 · A 16 · B 8 · C 16 · K 8 (voces y slap, sin melodía) · A' 8 · C' 8 = 4 + 64 compases: 7,6 s + bucle de
# 121,9 s. La intro y el bucle acaban igual, en Do#: la dominante empuja al Fa#m del principio del bucle.
#
#   ~/.venvs/fm-music/bin/python tools/music/resaca.py [A B C] → previas en FlappyMonster_pruebas/musica/resaca_rework/
#   REPORT=1 → solo números · INSTALL=1 RESACA=A|B|C → assets/music/bosses/resaca_intro|_loop.ogg + mid/resaca.mid
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan
import gloomy_nes as GN
import jungla_nes as J
import montana_nes as M
import slap as SL
import gm as GM

place, nm = M.place, J.nm
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/resaca_rework'
INSTALL_DIR = os.path.join(F.MUSIC_DIR, 'bosses')
TRACK = 'resaca_rework'
BPM, LUFS, CEILING = 126, -10.5, 0.64                               # (techo bajo: ni el OGG ni el MP3 deben pasar de 1,0)
VNAME = {'A': 'galerna', 'B': 'himno', 'C': 'saloma'}
SCALE = {6, 8, 9, 11, 1, 2, 4}                                        # Fa# menor natural (Mi# solo en Do#, Sol solo en su acorde)

# ══ LA ARMONÍA (la misma en las tres) ═══════════════════════════════════════════════════════════════════════════════
H_IN = "F#m D E C#"
H_A1 = "F#m D A E F#m D C# C#"
H_A2 = "F#m D A E Bm F#m C# F#m"
H_B = "Bm E A D Bm F#m G C#"                                          # el GIRO OSCURO: Sol → Do#
H_C1 = "D A E F#m D A C# C#"
H_C2 = "D A E F#m D A C# F#m"
H_K = "F#m F#m D D E E C# C#"

# ══ LAS MELODÍAS: 'paso:Nota/duración' en 12 corcheas por compás (pulsos: 0 3 6 9; galope: 2+1) ═════════════════════
_A_HEAD = ["0:C#5/2 2:F#5/1 3:A5/2 5:F#5/1 6:C#6/2 8:A5/1 9:F#5/3",   # Fa#m: el galope sube el acorde y se posa
           "0:D5/2 2:F#5/1 3:A5/2 5:F#5/1 6:D6/2 8:A5/1 9:F#5/3",     # Re: la misma figura
           "0:E5/2 2:A5/1 3:C#6/2 5:A5/1 6:E6/2 8:C#6/1 9:A5/3"]      # La: más arriba
_B_HEAD = ["0:F#5/3 3:C#6/6 9:B5/2 11:A5/1", "0:A5/6 6:F#5/3 9:A5/3", "0:C#6/3 3:E6/6 9:D6/2 11:C#6/1"]
_C_HEAD = ["0:A5/2 2:A5/1 3:C#6/2 5:A5/1 6:F#5/3", "0:A5/2 2:A5/1 3:D6/2 5:A5/1 6:F#5/3", "0:A5/2 2:C#6/1 3:E6/2 5:C#6/1 6:A5/3"]
MEL = {
    'A': {'A1': _A_HEAD + ["0:E5/2 2:G#5/1 3:B5/2 5:G#5/1 6:E6/2 8:F#6/1 9:E6/2 11:B5/1",
                           "0:C#6/2 2:F#5/1 3:A5/2 5:C#6/1 6:F#6/2 8:C#6/1 9:A5/3",     # la cabeza, una octava arriba
                           "0:D6/2 2:F#5/1 3:A5/2 5:D6/1 6:F#6/2 8:A5/1 9:D6/3",
                           "0:G#5/2 2:C#6/1 3:E#6/2 5:C#6/1 6:G#6/2 8:E#6/1 9:C#6/3",   # Do#: la cima, y la dominante
                           "0:G#6/2 2:F#6/1 3:E#6/3 6:C#6/3"],                   # (bajan; en el hueco, la voz)
          'A2': _A_HEAD + ["0:E5/2 2:G#5/1 3:B5/2 5:E6/1 6:G#6/2 8:E6/1 9:B5/3",
                           "0:B5/2 2:D6/1 3:F#6/2 5:D6/1 6:B5/2 8:F#5/1 9:D6/3",
                           "0:C#6/2 2:A5/1 3:F#5/2 5:A5/1 6:C#6/2 8:F#6/1 9:A6/3",
                           "0:G#6/2 2:F#6/1 3:E#6/2 5:C#6/1 6:G#5/3 9:E#5/3",
                           "0:F#5/6"],
          # B: la larga en el acorde, y tres que llevan a la siguiente, cada vez más arriba
          'B': ["0:D6/6 6:B5/2 8:D6/1 9:F#6/3", "0:E6/6 6:B5/2 8:E6/1 9:G#6/3", "0:C#6/6 6:A5/2 8:C#6/1 9:E6/3",
                "0:F#6/6 6:D6/2 8:F#6/1 9:A6/3", "0:F#6/6 6:D6/2 8:B5/1 9:D6/3", "0:C#6/6 6:A5/2 8:C#6/1 9:F#6/3",
                "0:G6/6 6:D6/2 8:B5/1 9:G5/3", "0:G#5/6 6:C#6/2 8:E#6/1 9:G#6/3"],
          # C: el ESTRIBILLO: el Sol# se resuelve en el La de arriba; baja el acorde con su vuelta
          'C1': ["0:A6/3 3:F#6/2 5:E6/1 6:F#6/2 8:A6/1 9:F#6/2 11:D6/1", "0:E6/3 3:C#6/2 5:B5/1 6:C#6/2 8:E6/1 9:C#6/2 11:A5/1",
                 "0:B5/3 3:G#5/2 5:A5/1 6:B5/2 8:E6/1 9:G#6/2 11:F#6/1", "0:F#6/3 3:C#6/2 5:A5/1 6:F#5/3",
                 "0:A6/3 3:F#6/2 5:E6/1 6:F#6/2 8:A6/1 9:F#6/2 11:D6/1", "0:E6/3 3:C#6/2 5:B5/1 6:C#6/2 8:E6/1 9:C#6/2 11:A5/1",
                 "0:C#6/3 3:E#6/2 5:G#6/1 6:C#7/3 9:G#6/3", "0:G#6/2 2:F#6/1 3:E#6/3 6:C#6/3"],
          'C2': ["0:A6/3 3:F#6/2 5:E6/1 6:F#6/2 8:A6/1 9:F#6/2 11:D6/1", "0:E6/3 3:C#6/2 5:B5/1 6:C#6/2 8:E6/1 9:C#6/2 11:A5/1",
                 "0:B5/3 3:G#5/2 5:A5/1 6:B5/2 8:E6/1 9:G#6/2 11:F#6/1", "0:F#6/3 3:C#6/2 5:A5/1 6:F#5/3",
                 "0:D6/3 3:F#6/3 6:A6/2 8:F#6/1 9:D6/2 11:E6/1", "0:E6/3 3:A6/2 5:E6/1 6:C#6/2 8:E6/1 9:A5/2 11:B5/1",
                 "0:C#6/3 3:E#6/2 5:G#6/1 6:C#7/3 9:G#6/3", "0:F#6/6"]},
    'B': {'A1': _B_HEAD + ["0:B5/6 6:G#5/3 9:B5/3", "0:C#6/3 3:F#6/6 9:F#6/2 11:E6/1", "0:D6/3 3:A6/6 9:F#6/2 11:E6/1",
                           "0:E#6/3 3:G#6/6 9:F#6/2 11:E#6/1", "0:C#6/6"],
          'A2': _B_HEAD + ["0:B5/3 3:E6/6 9:G#6/3", "0:F#6/6 6:D6/3 9:B5/3", "0:C#6/6 6:A5/3 9:C#6/3",
                           "0:E#6/3 3:G#6/3 6:F#6/2 8:E#6/1 9:C#6/3", "0:F#6/6"],
          'B': ["0:D6/6 6:F#6/3 9:D6/3", "0:E6/6 6:G#6/3 9:E6/3", "0:C#6/6 6:E6/3 9:A6/3", "0:F#6/6 6:D6/3 9:A5/3",
                "0:B5/6 6:D6/3 9:F#6/3", "0:A6/6 6:F#6/3 9:C#6/3", "0:D6/6 6:B5/3 9:G5/3", "0:G#5/6 6:C#6/3 9:E#6/3"],
          'C1': ["0:F#6/9 9:E6/2 11:D6/1", "0:C#6/9 9:D6/2 11:E6/1", "0:G#6/6 6:F#6/2 8:E6/1 9:B5/3", "0:C#6/6",
                 "0:A6/9 9:F#6/2 11:E6/1", "0:E6/9 9:C#6/3", "0:E#6/6 6:G#6/6", "0:C#7/6 6:G#6/3"],
          'C2': ["0:F#6/9 9:E6/2 11:D6/1", "0:C#6/9 9:D6/2 11:E6/1", "0:G#6/6 6:F#6/2 8:E6/1 9:B5/3", "0:C#6/6",
                 "0:A6/9 9:F#6/2 11:E6/1", "0:E6/9 9:C#6/3", "0:E#6/3 3:G#6/3 6:C#7/6", "0:F#6/9"]},
    'C': {'A1': _C_HEAD + ["0:B5/2 2:G#5/1 3:E6/2 5:B5/1 6:G#5/3", "0:C#6/2 2:C#6/1 3:F#6/2 5:C#6/1 6:A5/3 9:C#6/3",
                           "0:D6/2 2:D6/1 3:F#6/2 5:D6/1 6:A5/3 9:D6/3", "0:E#6/2 2:E#6/1 3:G#6/2 5:E#6/1 6:C#6/3 9:E#6/3",
                           "0:G#6/6"],
          'A2': _C_HEAD + ["0:B5/2 2:G#5/1 3:E6/2 5:B5/1 6:G#5/3", "0:D6/2 2:D6/1 3:F#6/2 5:D6/1 6:B5/3 9:D6/3",
                           "0:C#6/2 2:C#6/1 3:F#6/2 5:C#6/1 6:A5/3 9:C#6/3", "0:E#6/2 2:G#6/1 3:E#6/2 5:C#6/1 6:G#5/3 9:C#6/3",
                           "0:F#5/6"],
          # B: los gritos dan el 1 y la voz sube por grados
          'B': ["3:B5/2 5:C#6/1 6:D6/3 9:F#6/3", "3:G#5/2 5:A5/1 6:B5/3 9:E6/3", "3:A5/2 5:B5/1 6:C#6/3 9:E6/3",
                "3:D6/2 5:E6/1 6:F#6/3 9:A6/3", "3:F#6/2 5:E6/1 6:D6/3 9:B5/3", "3:A5/2 5:B5/1 6:C#6/3 9:F#6/3",
                "3:G6/3 6:D6/3 9:B5/3", "3:C#6/2 5:E#6/1 6:G#6/6"],
          # C: la OLA: sube en dos pulsos, se queda arriba en los otros dos; el grito contesta al final
          'C1': ["0:A5/1 1:D6/1 2:F#6/1 3:A6/6", "0:A6/1 1:E6/1 2:C#6/1 3:E6/6", "0:G#6/1 1:E6/1 2:B5/1 3:E6/6",
                 "0:F#6/1 1:C#6/1 2:A5/1 3:C#6/6", "0:A5/1 1:D6/1 2:F#6/1 3:A6/6", "0:A6/1 1:E6/1 2:C#6/1 3:E6/6",
                 "0:G#6/1 1:E#6/1 2:C#6/1 3:G#6/6", "0:G#6/1 1:E#6/1 2:C#6/1 3:G#5/6"],
          'C2': ["0:A5/1 1:D6/1 2:F#6/1 3:A6/6", "0:A6/1 1:E6/1 2:C#6/1 3:E6/6", "0:G#6/1 1:E6/1 2:B5/1 3:E6/6",
                 "0:F#6/1 1:C#6/1 2:A5/1 3:C#6/6", "0:A5/1 1:D6/1 2:F#6/1 3:A6/6", "0:A6/1 1:E6/1 2:C#6/1 3:E6/6",
                 "0:G#6/1 1:E#6/1 2:C#6/1 3:G#6/6", "0:F#6/1 1:C#6/1 2:A5/1 3:F#6/6"]},
}


def sections(v):
    M_ = MEL[v]
    return [('intro', H_IN, [''] * 4, 12, ''), ('A', H_A1 + ' ' + H_A2, M_['A1'] + M_['A2'], 12, ''), ('B', H_B, M_['B'], 12, ''),
            ('C', H_C1 + ' ' + H_C2, M_['C1'] + M_['C2'], 12, ''), ('K', H_K, [''] * 8, 12, ''),
            ('A', H_A2, M_['A2'], 12, 'rep'), ('C', H_C1, M_['C1'], 12, 'rep')]


J.TRACKS[TRACK] = dict(secs=sections, bpm=BPM, scale=SCALE, tonic=(6, M.MIN), lufs=LUFS, variants=tuple(VNAME), title='Resaca', vname=VNAME)

# ══ EL REPARTO ══════════════════════════════════════════════════════════════════════════════════════════════════════
STEEL = 114
M.TIGHT_KEYS = M.TIGHT_KEYS + ('steel',)
BRASS, MARIMBA, TAIKO, TIMP, CHOIR, TREM, HARP = 61, 12, 116, M.TIMPANI, M.CHOIR, M.TREM, M.HARP
MARACAS = 70
PULSES = (0, 3, 6, 9)
BASS_ROOT = {6: 30, 2: 38, 9: 33, 4: 40, 11: 35, 1: 37, 7: 31}        # (el registro grave del riff de Resaca; Re y Mi, una 8ª arriba si no se pierden)
I_SAW_LEAD = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.18, 6)}
I_UP = {'vol': [8, 7, 7, 6, 6, 5], 'sus': 5, 'duty': 0.25}
I_ARP = {'vol': [8, 5, 3, 2, 1], 'sus': 0, 'duty': 2}
LEADS = ('lead',)


class Rig(M.Rig):
    def __init__(self, sg):
        super().__init__(sg)
        self.Cn['saw'] = Chan(len(self.Cn['lead'].f))
        self.slap = SL.Rec()
        for k in ('snare', 'crash'): self.NZ[k].exact = True          # (cada golpe en su muestra)

    def sl(self, b, st, n, d, vel=100):
        sg = self.sg
        self.slap.add(sg.t(b, st), sg.t(b, st) + sg.dur(b, d) * 0.95, n, vel)
        self.notes.setdefault('bass', []).append((sg.q(b, st), sg.q(b, st + d), n))


def lead_note(sg, R, b, st, n, d):
    """la voz: la sierra una octava abajo (la de Obsidiana); en lo fuerte, además, un pulso arriba"""
    R.notes.setdefault('lead', []).append((sg.q(b, st), sg.q(b, st + d), n))
    R.chip('saw', b, st, n - 12, d, I_SAW_LEAD, q=F.q_saw, release=3)
    R.notes['saw'].pop()                                               # (la misma nota; no se cuenta dos veces)
    if sg.tag[b - 1] == 'C' or sg.var[b - 1] == 'rep': R.chip('dbl', b, st, n, d, I_UP, release=2); R.notes['dbl'].pop()


# ══ LAS VOCES: el muestreador que las afina al acorde ═══════════════════════════════════════════════════════════════
def steel_events(sg, R, v):
    """LA COSTA CONTESTA (el usuario eligió la A "mejor ya sin las voces croppeadas, otro instrumento de alguna sound font costera"):
    el STEEL DRUM, la voz de la costa en el juego, pone notas del acorde donde antes iban los gritos: en los huecos de la melodía"""
    def fig(b, sts, vel):
        for j, (st, idx, d) in enumerate(sts):
            nn = J.place(None, sg.chord(b, st), 69)[idx]
            if not R.rub(b, st, nn, d, voice=LEADS): R.gm('steel', STEEL, b, st, nn, d, vel - 6 * (j % 2), gate=0.9)
    largo = lambda st: ((st, 0, 1), (st + 1, 1, 1), (st + 2, 2, 1), (st + 3, 3, 2))
    corto = lambda st: ((st, 2, 2), (st + 2, 1, 1)) if st <= 9 else ((st, 2, 2),)
    for b in range(1, sg.NB + 1):
        tag, k, L = sg.tag[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        last = max((m[1] + m[3] for m in sg.mel if m[0] == b), default=0)
        if tag == 'intro':
            if k < L: fig(b, largo(0), 92); fig(b, largo(6), 86)
        elif tag == 'K':                                               # lleva la sección, en el ritmo del galope
            if k <= 2:
                fig(b, largo(0), 98); fig(b, largo(6), 98)
            else:
                fig(b, tuple((st, (0, 2, 3, 2)[st // 3], 2) for st in PULSES) + ((5, 1, 1), (11, 1, 1)), 100)
        elif last <= 6: fig(b, largo(6), 94)
        elif last <= 9: fig(b, corto(9), 94)


# ══ EL ARREGLO (el mismo en las tres) ═══════════════════════════════════════════════════════════════════════════════
def root(sg, b, st):
    return BASS_ROOT.get(sg.chord(b, st)[0], 30)


def next_root(sg, b):
    return (sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0])[0]


def bass_bar(sg, R, b, pops):
    """EL GALOPE del slap: cada pulso 2+1. Raíz, octava (pop) en el 2º, 5ª en el 4º; la última corchea, hacia el acorde siguiente"""
    r = root(sg, b, 0)
    nx = BASS_ROOT.get(next_root(sg, b), 30)
    if sg.chord(b, 0)[0] == next_root(sg, b): ap = r + 7
    else:
        c = [p for p in (nx + 2, nx - 2, nx + 1, nx - 1) if p % 12 in sg.scale | sg.tones(b, 11) and not R.rub(b, 11, p, 1, voice=LEADS)]
        ap = c[0] if c else r
    for st, n, d, vv in ((0, r, 2, 112), (2, r, 1, 80), (3, r + 12, 2, 112), (5, r, 1, 78), (6, r, 2, 104), (8, r, 1, 78),
                         (9, r + 7 if not pops else r + 12, 2, 106), (11, ap, 1, 90)):
        R.sl(b, st, n, d, vv)


def timp(sg, R, b, st, d, vel):
    r = sg.chord(b, st)[0]
    R.gm('timp', TIMP, b, st, 41 + (r - 41) % 12, d, vel)


def stab(sg, R, b, sts, vel=98):
    for st in sts:
        for n in place(None, sg.chord(b, st), 57)[:4]:
            if not R.rub(b, st, n, 2, voice=LEADS): R.gm('stab', BRASS, b, st, n, 2, vel, gate=0.75)


def ending(sg, R, b):
    """el último compás de la intro y del bucle (Do#): los cuatro pulsos de toda la banda, cada uno más fuerte"""
    for i, st in enumerate(PULSES):
        R.sl(b, st, root(sg, b, st) + (0, 7, 12, 0)[i], 2, 100 + 6 * i)
        R.kick(b, st, 0.8 + 0.07 * i); R.snare(b, st, 0.6 + 0.12 * i)
        timp(sg, R, b, st, 2, 90 + 8 * i)
        R.gm('taiko', TAIKO, b, st, 36 + (sg.chord(b, st)[0] - 36) % 12, 2, 92 + 6 * i)
    stab(sg, R, b, PULSES, 100)
    R.dr('shaker', b, 11, MARACAS, 70)


def bar_music(sg, R, b):
    tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
    rep = var == 'rep'
    big = tag == 'C' or rep
    last_of_all = b == sg.NB
    if (tag == 'intro' and k == L) or last_of_all: return ending(sg, R, b)
    if tag == 'intro':
        R.sl(b, 0, root(sg, b, 0), 6, 112); R.sl(b, 6, root(sg, b, 6), 3, 104); R.sl(b, 9, root(sg, b, 9) + 12, 3, 108)
        timp(sg, R, b, 0, 3, 100); timp(sg, R, b, 9, 3, 88)
        R.kick(b, 0, 0.9)
        if k >= 2:
            R.snare(b, 9, 0.6)
            for st in range(12): R.dr('shaker', b, st, MARACAS, 58 if st % 3 == 0 else 38)
        return
    # ── EL BAJO ──
    if tag == 'K' and k <= 2:
        R.sl(b, 0, root(sg, b, 0), 9, 112); R.sl(b, 9, root(sg, b, 9) + 12, 2, 106); R.sl(b, 11, root(sg, b, 11) + 7, 1, 90)
    else: bass_bar(sg, R, b, pops=big)
    # ── EL ARPEGIO de N163 en corcheas (sube el acorde por pulsos) ──
    if tag in ('A', 'C') or (tag == 'K' and k > 4):
        for st in range(12):
            c = place(None, sg.chord(b, st), 72)[:6]
            n = c[(0, 1, 2)[st % 3] + (3 if st >= 6 else 0)]
            if not R.rub(b, st, n, 1, voice=LEADS): R.chip('cm', b, st, n, 1, I_ARP, q=F.q_n163, gate=0.8, release=0)
    # ── EL ARPA en B ──
    if tag == 'B':
        for st in range(12):
            c = place(None, sg.chord(b, st), 60)[:5]
            n = c[(0, 1, 2, 3, 4, 3)[st % 6]]
            if not R.rub(b, st, n, 1, voice=LEADS): R.gm('harp', HARP, b, st, n, 1, 72 + (12 if st in PULSES else 0), gate=1.0)
    # ── EL CORO y la cuerda, sostienen ──
    if big or tag == 'B':
        ks, prog, vel = ('choir', CHOIR, 88) if big else ('trem', TREM, 76)
        for n in place(None, sg.chord(b, 0), 57)[:3]:
            if not R.rub(b, 0, n, 12, voice=LEADS): R.gm(ks, prog, b, 0, n, 12, vel, gate=0.98)
    # ── EL METAL en los pulsos ──
    if tag == 'C': stab(sg, R, b, (0, 3, 9) if k % 2 else (0, 9))
    elif rep: stab(sg, R, b, (0, 9))
    # ── LA COSTA: maracas y la marimba que sube ──
    for st in range(12): R.dr('shaker', b, st, MARACAS, 60 if st % 3 == 0 else 40)
    if tag == 'K' and k % 2 == 0:
        for st, n in zip((9, 10, 11), place(None, sg.chord(b, 9), 72)[:3]): R.gm('marimba', MARIMBA, b, st, n, 1, 92)
    # ── LA BATERÍA: bombo con galope, caja en el 2 y el 4 ──
    if tag == 'K' and k <= 2:
        R.kick(b, 0); R.gm('taiko', TAIKO, b, 6, 36 + (sg.chord(b, 6)[0] - 36) % 12, 2, 92)
    else:
        R.kick(b, 0); R.kick(b, 6, 0.9)
        if big or tag == 'K': R.kick(b, 5, 0.65); R.kick(b, 11, 0.65)
        R.snare(b, 3, 0.95); R.snare(b, 9, 0.95)
        for st in range(12): R.NZ['hat'].hit(sg.t(b, st), 1, J.HAT if st % 3 == 0 else [3, 1])
    # ── TIMBALES, TAIKO, PLATOS ──
    if k % 2 == 1: timp(sg, R, b, 0, 3, 104 if big else 92)
    if k == 1 or (big and k % 2 == 1) or k == 9:
        R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)
        R.gm('taiko', TAIKO, b, 0, 36 + (sg.chord(b, 0)[0] - 36) % 12, 3, 104)
    if k == L and b < sg.NB:                                           # redoble de corcheas hacia la sección nueva
        for st in (6, 7, 8, 9, 10, 11): R.snare(b, st, 0.35 + 0.08 * (st - 6))


def arrange(sg, R, v):
    R.notes['saw'] = []; R.notes['dbl'] = []
    for b, st, n, d in sg.mel: lead_note(sg, R, b, st, n, d)
    for b in range(1, sg.NB + 1): bar_music(sg, R, b)
    steel_events(sg, R, v)


# ══ LA MEZCLA ═══════════════════════════════════════════════════════════════════════════════════════════════════════
LV = {'lead': 0, 'dbl': -9, 'cm': -11, 'harp': -6, 'choir': -9, 'trem': -9, 'stab': -8, 'marimba': -6, 'steel': -4,
      'bass': -2, 'kick': -1, 'snare': -1, 'taiko': -5, 'timp': -3, 'shaker': -13, 'hat': -11, 'crash': -7}
LEAD_GROUP = ('lead', 'dbl')
DRUM_GROUP = ('kick', 'snare', 'taiko', 'timp', 'shaker', 'hat', 'crash')
BACKING = 3.5


def build(v):
    sg = J.Song(TRACK, v)
    R = Rig(sg)
    arrange(sg, R, v)
    n = int(round(sg.NB * sg.BAR * SR))
    at = int(round(sg.INTRO * sg.BAR * SR))
    L = n + 5 * SR
    S = M.render_stems(R, n, L, True, at / SR)
    def cut(x):
        x = x[:L] - np.mean(x[:n])
        return np.concatenate([x, np.zeros(L - len(x))]) if len(x) < L else x
    y = GM.cached(R.slap, L)
    S['bass'] = np.concatenate([y[M.GM_LAT:], np.zeros(M.GM_LAT)])
    S['lead'] = cut(F.pulse_dac(F.render_saw(R.Cn['saw'])))
    from scipy.signal import butter, sosfilt
    hp = butter(2, 30, btype='high', fs=SR, output='sos')
    S = {k: sosfilt(hp, x) for k, x in S.items() if np.abs(x).max() > 0}
    g = GN.level(S, {k: LV.get(k, -10) + (0 if k in LEAD_GROUP else BACKING) for k in S}, 'lead')
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('cm', 0.3) - sd('harp', 0.3) + sd('stab', 0.15) - sd('choir', 0.2) + sd('shaker', 0.3) + sd('dbl', 0.15) - sd('marimba', 0.25) + sd('steel', 0.3)
    st = np.stack([GN.fold(x + side, n, at), GN.fold(x - side, n, at)], 1)
    st = F.master(st, lufs=LUFS, ceiling=CEILING)
    S = {k: GN.fold(s, n, at) for k, s in S.items()}
    return sg, R, S, g, st, n, at


# ══ INFORME (números: NO se ha escuchado) ═══════════════════════════════════════════════════════════════════════════
def melody_numbers(sg):
    mel = sg.mel
    bars = sorted({m[0] for m in mel})
    d16 = lambda m: sg.q(m[0], m[1] + m[3]) - sg.q(m[0], m[1])
    per = {b: [m for m in mel if m[0] == b] for b in bars}
    bl = [abs(per[b + 1][0][2] - per[b][-1][2]) for b in bars if b + 1 in per]
    rhy = {}
    for b in bars:
        key = tuple(m[1] for m in per[b]); rhy[key] = rhy.get(key, 0) + 1
    iv = np.diff([m[2] for m in mel])
    rev = [np.sign(a) != np.sign(c) for a, c in zip(iv, iv[1:]) if abs(a) >= 5 and c != 0]
    return dict(notes=len(mel), lo=nm(min(m[2] for m in mel)), hi=nm(max(m[2] for m in mel)), ct=np.mean([m[2] % 12 in sg.tones(m[0], m[1]) for m in mel]),
                ct1=np.mean([m[2] % 12 in sg.tones(m[0], 0) for m in mel if m[1] == 0]), ctl=np.mean([m[2] % 12 in sg.tones(m[0], m[1]) for m in mel if d16(m) >= 4]),
                pulse=np.mean([m[1] in PULSES for m in mel]), bl=np.mean(bl), bl2=np.mean(np.array(bl) <= 2), rhythms=len(rhy),
                top3=sum(sorted(rhy.values())[-3:]) / len(bars), meaniv=np.mean(np.abs(iv)), rev=np.mean(rev), long=np.mean([d16(m) >= 4 for m in mel]))


def report(v, sg, R, S, g, y, n, at):
    print(f'── {TRACK} variante {v} "{VNAME[v]}"')
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    bar = sg.BAR * SR
    lufs = F.loudness(y)
    print(f'  {sg.NB} compases: intro {sg.INTRO} = {at} muestras ({at / SR:.2f} s) + bucle {sg.NB - sg.INTRO} = {n - at} muestras ({(n - at) / SR:.2f} s) · {lufs:.1f} LUFS, pico {np.abs(y).max():.2f}')
    print(f'  energía: melodía {grp(LEAD_GROUP):.0f} %, batería {grp(DRUM_GROUP):.0f} %, bajo {grp(("bass",)):.0f} %, steel drum {grp(("steel",)):.1f} %')
    print('  ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    lb, lo, out, off = J.check(sg)
    mn = melody_numbers(sg)
    print(f'  melodía: {mn["notes"]} notas {mn["lo"]}-{mn["hi"]} · en los pulsos {100 * mn["pulse"]:.0f} % · del acorde {100 * mn["ct"]:.0f} % (tiempo 1: {100 * mn["ct1"]:.0f} %, largas: {100 * mn["ctl"]:.0f} %)')
    print(f'    entre compases {mn["bl"]:.1f} st ({100 * mn["bl2"]:.0f} % ≤ 2) · intervalo medio {mn["meaniv"]:.2f} · tras un salto cambia de sentido {100 * mn["rev"]:.0f} % · ritmos {mn["rhythms"]}, los 3 más usados {100 * mn["top3"]:.0f} % · largas {100 * mn["long"]:.0f} %')
    print(f'    largas fuera del acorde: {lb or "ninguna"}; sueltas: {lo or "ninguna"}; fuera de escala: {out or "ninguna"}')
    cnt = 0
    for k, notes in R.notes.items():
        if k in ('lead', 'saw', 'dbl', 'timp', 'taiko') or not notes: continue
        cl = J.clashes(sg, sg.mel, notes)
        cnt += len(cl)
        if cl: print(f'    choques melodía / {k} (≥ corchea): {len(cl)} {cl[:5]}')
    print(f'    choques melodía / resto: {cnt}')
    badb = sum(1 for q0, q1, nn in R.notes['bass'] if q1 - q0 >= 2.6 and (nn - sg.chord(int(q0 // 16) + 1, (q0 % 16) * 12 / 16)[0]) % 12 not in (0, 7))
    print(f'    bajo: {len(R.notes["bass"])} notas; las de corchea o más que no son raíz ni 5ª: {badb}')
    from scipy.signal import butter, sosfilt
    bp = butter(2, [1000, 5000], btype='band', fs=SR, output='sos')
    rms = lambda z: np.sqrt(np.mean(sosfilt(bp, z[at:n]) ** 2))
    lead = S['lead'] * g['lead']
    print('    en 1-5 kHz, frente a la melodía: ' + ' '.join(f'{k} {100 * rms(S[k] * g[k]) / rms(lead):.0f} %' for k in S if k != 'lead' and rms(S[k] * g[k]) / rms(lead) > 0.3))
    ln, bars, jr, dbs, ji, dbi = M.seam_numbers(y, at, bar, [(b0 - 1) * sg.BAR * SR for b0 in sg.starts[2:]])
    print(f'  BUCLE: {ln} muestras = {bars:.4f} compases; costura {jr:.2f}× otro tiempo 1 de sección, {dbs:+.1f} dB; intro → bucle {ji:.2f}×, {dbi:+.1f} dB')
    span = lambda b0, L_: (int((b0 - 1) * sg.BAR * SR), int((b0 - 1 + L_) * sg.BAR * SR))
    def db(a, b_):
        z = sum(S[k][a:b_] * g[k] for k in S)
        return 10 * np.log10(np.mean(np.asarray(z) ** 2) + 1e-12)
    r0 = db(*span(sg.starts[1], 16))
    print('  sonoridad por sección vs A (dB): ' + ' '.join(f'{sg.tag[b0 - 1]} {db(*span(b0, sg.slen[b0 - 1])) - r0:+.1f}' for b0 in sg.starts))
    return dict(lufs=lufs, loop=n - at, intro=at, bars=bars, jr=jr, nlb=len(lb), nlo=len(lo), ncl=cnt, mn=mn)


def mmss(t):
    return f'{int(t // 60)}:{t % 60:04.1f}'


def readme(sg, nums):
    desc = {'intro': 'INTRO: el slap, los timbales y el steel drum', 'A': 'A: el tema (Fa#m Re La Mi; acaba en la dominante Do#)',
            'B': 'B: se abre; arpa y cuerda; el giro oscuro Sol → Do#', 'C': 'C: EL ESTRIBILLO: coro, metal, lo más alto',
            'K': 'K: el steel drum y el slap, sin melodía; la marimba que sube'}
    t = ['RESACA (rework): el tema del Pez Globo Gigante. tools/music/resaca.py',
         'NO SE HA ESCUCHADO: comprobado solo con números. El oído es el tuyo. No está instalado; resaca.py sigue igual.',
         '',
         'SE QUEDA: el slap bass y Fa# menor. Las voces croppeadas se cambian por steel drum.',
         'CAMBIA: EL RITMO (de 181 BPM en 3+3+2 a un 12/8 de galope, pulso 126, una saloma de tormenta) y LA MELODÍA;',
         'la armonía se mueve con el bajo y tiene una dominante de verdad (Do# mayor). Las voces van AFINADAS: para cada acorde se',
         'elige el recorte que mejor encaja, con un transporte de hasta ±2 semitonos, y suenan en los huecos de la melodía.',
         '',
         'LAS TRES VARIANTES (misma armonía y forma, otra melodía; la voz es la sierra de Obsidiana):',
         '  A galerna  melodía-riff: el galope sube el acorde en secuencia, como lo que elegiste en Obsidiana B.',
         '  B himno    notas largas en los pulsos, de himno; el bajo galopa debajo.',
         '  C saloma   llamada y respuesta: media frase la voz, la otra media los gritos.',
         '',
         'ARCHIVOS por variante: resaca_rework_<v>_preview.mp3 (intro + bucle dos veces), _intro.ogg, _loop.ogg, .mid (melodía y bajo).',
         '',
         'SECCIONES (tiempos de la previa; iguales en las tres):']
    for b0 in sg.starts:
        t.append(f'  {mmss((b0 - 1) * sg.BAR)}  {desc[sg.tag[b0 - 1]]}' + ('  (la vuelta, con más banda)' if sg.var[b0 - 1] == 'rep' else ''))
    lp = (sg.NB - sg.INTRO) * sg.BAR
    t.append(f'  {mmss(sg.NB * sg.BAR)}  el bucle empieza otra vez (segunda vuelta: los mismos tiempos + {mmss(lp)})')
    t += [f'  {mmss((sg.NB + sg.NB - sg.INTRO) * sg.BAR)}  fin de la previa', '', 'NÚMEROS:'] + nums
    t += ['', 'A JUZGAR DE OÍDO: si las voces suenan afinadas de verdad (son ruidosas: la medida no lo asegura) y qué tal los recortes', f'seguidos de la K ({mmss((sg.starts[4] - 1) * sg.BAR)}); si el 12/8 te sigue sonando a jefe a este tempo; el coro y el metal GM junto al chip.',
          'OJO: el jefe suelta anillos de púas "en 3+3+2, el ritmo de Resaca" (docs/bosses/giantpuffer.md): con este ritmo ya no coincidirían.']
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
    if os.environ.get('INSTALL'): which = [os.environ.get('RESACA', 'A')]
    os.makedirs(PRUEBAS, exist_ok=True)
    nums = []
    for v in which:
        sg, R, S, g, y, n, at = build(v)
        r = report(v, sg, R, S, g, y, n, at)
        mn = r['mn']
        nums.append(f'  {v} {VNAME[v]}: intro {r["intro"] / SR:.2f} s + bucle {r["loop"]} muestras ({r["loop"] / SR:.2f} s = {r["bars"]:.4f} compases), {r["lufs"]:.1f} LUFS; '
                    f'del acorde {100 * mn["ct"]:.0f} %, largas fuera {r["nlb"]}, sueltas {r["nlo"]}, choques {r["ncl"]}')
        if os.environ.get('REPORT'): continue
        if os.environ.get('INSTALL'):
            J.export(y, at, os.path.join(INSTALL_DIR, 'resaca'))
            J.write_mid(os.path.join(F.MID_DIR, 'resaca.mid'), sg, R)
            continue
        base = os.path.join(PRUEBAS, f'{TRACK}_{v}_{VNAME[v]}')
        J.export(y, at, base)
        enc_mp3(np.concatenate([y, y[at:]]), base + '_preview.mp3')
        J.write_mid(base + '.mid', sg, R)
    if not os.environ.get('REPORT') and not os.environ.get('INSTALL') and len(which) == len(VNAME):
        with open(os.path.join(PRUEBAS, 'LEEME.txt'), 'w') as f:
            f.write(readme(sg, nums))
        print(f'  previas en {PRUEBAS}')
