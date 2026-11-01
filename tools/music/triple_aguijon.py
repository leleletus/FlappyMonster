#!/usr/bin/env python3
# tools/music/triple_aguijon.py — "Triple Aguijón", el tema del ESCORPIÓN TRIPLE AGUIJÓN (jefe secreto del volcán).
# PREVIAS para que el usuario elija; no toca assets/ salvo con INSTALL=1 (y nunca el index.json).
#
# Hecho con la receta de la JUNGLA, los temas favoritos del usuario (docs/audio/music-guide.md § 8): una idea propia sacada
# del personaje, instrumentos GM TEMÁTICOS sobre el chip de la casa, un ritmo que el juego no tenía y una forma que crece a su
# manera. La isla es el VOLCÁN (frigio, ♭II); el escorpión lo lleva al desierto: La FRIGIO DOMINANTE (hiyaz: La Si♭ Do# Re Mi Fa Sol).
#   · LA IDEA: su MATRACA en la percusión: a 168 BPM una semicorchea dura 0,089 s, lo mismo que entre dos clics (0,09 s).
#   · LA FORMA CUENTA SU PELEA: B = SEPARADAS: la melodía va pasando por tres instrumentos, cada dos compases ("cada una a su
#     vez"); C = ENROLLADAS: las tres voces a la vez, mismo ritmo (terceras y octava), "atacan como una sola"; K = el corro de la
#     matraca: solo percusión, bloques y castañuelas de tres en tres.
#   · INSTRUMENTOS del soundfont: shanai (la voz), sitar, koto, dulcémele, taiko, darbuka (congas y bongós en maqsum), castañuelas,
#     bloques, claves, vibraslap (la matraca de verdad), timbales. El chip debajo: N163 (colchón y una pizca bajo la voz), bombo y
#     caja de DPCM, platos de ruido. Bajo: el SLAP de los jefes (slap.py), el favorito del usuario.
#   · A TIEMPO (lo aprendido con montana_2: "llegan tarde y se superponen"): cada capa adelantada según su ataque, sin cola sobre la
#     nota siguiente, sin eco ni reverb.
#
#   Dos variantes (forma y armonía iguales; otro compás, otra melodía y otra voz):
#     A "shanai"  4/4 a 168 (más cerca de la casa): shanai, sitar en ostinato; bajo y marimba 3+3+2.
#     B "aksak"   7/8 (2+2+3) a la misma semicorchea: el primer compás de amalgama del juego. Sitar y shanai juntos; todo cojea.
#
#   ~/.venvs/fm-music/bin/python tools/music/triple_aguijon.py   → FlappyMonster_pruebas/musica/escorpion/
#   REPORT=1 → solo números · INSTALL=1 TRIPLE=A|B → assets/music/bosses/ (el index.json y levels.py, aparte).
#   Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import famicom as F
from famicom import SR, q_n163
import gloomy_nes as GN
import jungla_nes as J
import montana_nes as MN
import slap

PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/escorpion'
SCALE = {9, 10, 1, 2, 4, 5, 7}
SHANAI, SITAR, KOTO, DULCIMER, TAIKO, TIMPANI = 111, 104, 107, 15, 116, 47
DUM, DUM2, TEK, TEK2, TAMB, CASTANETS, CLAVES, WOOD_H, WOOD_L, VIBRA, TRI_O = \
    J.CONGA_L, J.CONGA_O, J.BONGO_H, J.BONGO_L, 54, 85, 75, 76, 77, 58, 81
REV_CYM = 119
I_PAD, I_VOICE = J.I_PAD, {'vol': [6, 8, 8, 8, 7, 7], 'sus': 6, 'vib': (14, 0.2, 5.6), 'duty': 1}

IN_ = "A A A Bb|A"
CH_A = "A A|Bb Gm|A Dm|Bb A A|Bb Gm Bb|A"
CH_B = "Dm Bb Gm A Dm Bb Bbm A"                                  # el GIRO OSCURO: Si♭ menor (♭ii), la llamada al cerrar
CH_C = "A Gm|A Bb|A Dm A Gm|A Bb A"
CH_K = "A A A Bb|A A A Gm Bb|A"

# (v1 rechazada, el usuario: "la melodía se siente forzada, no encaja con el flujo de la canción". Medido: 100 % notas del acorde,
#  7 % por grado y 26 % repetidas; las de la jungla y las montañas, 80-90 %, 30-44 % y ~8 %. Era un arpegio con un concepto encima. La
#  v2 CANTA: por grados, con notas de paso y notas largas; la matraca se queda en la percusión, que es donde funciona)
# ── A: 4/4 (16 semicorcheas) ───────────────────────────────────────────────────────────────────────────────────────────
MEL_A = {
    'A': ["0:A5/2 2:Bb5/1 3:A5/1 4:C#6/4 8:E6/6 14:D6/1 15:C#6/1",
          "0:C#6/3 3:D6/1 4:E6/4 8:F6/4 12:E6/1 13:D6/1 14:Bb5/2",
          "0:Bb5/3 3:A5/1 4:G5/4 8:C#6/4 12:D6/1 13:E6/3",
          "0:F6/3 3:E6/1 4:D6/4 8:F6/3 11:D6/3 14:Bb5/2",
          "0:A5/2 2:C#6/2 4:E6/4 8:A6/6 14:G6/1 15:F6/1",
          "0:E6/3 3:D6/1 4:C#6/4 8:D6/4 12:F6/4",
          "0:G6/4 4:D6/4 8:Bb5/3 11:A5/1 12:G5/4"],
    'E1': "0:Bb5/2 2:D6/2 4:F6/4 8:E6/8",
    'E2': "0:F6/2 2:D6/2 4:Bb5/4 8:A5/8",
    'B': ["0:F6/6 6:E6/2 8:D6/8",
          "0:D6/6 6:E6/1 7:F6/1 8:Bb6/6 14:A6/2",
          "0:G6/6 6:F6/1 7:E6/1 8:D6/8",
          "0:C#6/3 3:D6/1 4:E6/4 8:A6/8",
          "0:A6/6 6:G6/2 8:F6/6 14:E6/2",
          "0:D6/6 6:E6/1 7:F6/1 8:D6/8",
          "0:Db6/4 4:F6/4 8:F6/8",
          "0:E5/4 4:A5/2 6:C#6/2 8:E6/8"],                                # LA LLAMADA (Mi-La-Do#-Mi)
    'C': ["0:A5/2 2:C#6/2 4:E6/4 8:A6/8",
          "0:G6/6 6:F6/2 8:E6/8",
          "0:F6/3 3:E6/1 4:D6/4 8:C#6/3 11:D6/1 12:E6/4",
          "0:F6/3 3:E6/1 4:D6/4 8:A5/8",
          "0:C#6/2 2:E6/2 4:A6/4 8:C#7/8",
          "0:Bb6/6 6:A6/2 8:A6/8",
          "0:F6/3 3:E6/1 4:D6/4 8:Bb5/4 12:D6/4",
          "0:C#6/3 3:D6/1 4:E6/4 8:A5/8"],
}
# ── B: 7/8 = 2+2+3 corcheas (14 semicorcheas: grupos en 0, 4, 8) ───────────────────────────────────────────────────────────
MEL_B = {
    'A': ["0:A5/2 2:Bb5/1 3:A5/1 4:C#6/4 8:E6/4 12:D6/1 13:C#6/1",
          "0:C#6/2 2:D6/2 4:E6/3 7:F6/5 12:E6/1 13:D6/1",
          "0:Bb5/2 2:A5/2 4:G5/3 8:C#6/3 11:D6/1 12:E6/2",
          "0:F6/2 2:E6/2 4:D6/3 8:F6/2 10:D6/2 12:Bb5/2",
          "0:A5/2 2:C#6/2 4:E6/3 8:A6/4 12:G6/1 13:F6/1",
          "0:E6/2 2:D6/2 4:C#6/3 8:D6/3 11:F6/3",
          "0:G6/4 4:D6/4 8:Bb5/2 10:A5/2 12:G5/2"],
    'E1': "0:Bb5/2 2:D6/2 4:F6/3 8:E6/6",
    'E2': "0:F6/2 2:D6/2 4:Bb5/3 8:A5/6",
    'B': ["0:F6/4 4:E6/2 6:D6/2 8:A5/6",
          "0:D6/4 4:E6/1 5:F6/3 8:Bb6/4 12:A6/2",
          "0:G6/4 4:F6/1 5:E6/1 6:D6/2 8:D6/6",
          "0:C#6/2 2:D6/2 4:E6/3 8:A6/6",
          "0:A6/4 4:G6/2 6:F6/2 8:F6/4 12:E6/2",
          "0:D6/4 4:E6/1 5:F6/3 8:D6/6",
          "0:Db6/4 4:F6/3 8:F6/6",
          "0:E5/3 3:A5/2 5:C#6/3 8:E6/6"],                                # LA LLAMADA
    'C': ["0:A5/2 2:C#6/2 4:E6/3 8:A6/6",
          "0:G6/5 5:F6/2 8:E6/6",
          "0:F6/2 2:E6/2 4:D6/3 8:C#6/2 10:D6/2 12:E6/2",
          "0:F6/2 2:E6/2 4:D6/3 8:A5/6",
          "0:C#6/2 2:E6/2 4:A6/3 8:C#7/6",
          "0:Bb6/5 5:A6/2 8:A6/6",
          "0:F6/2 2:E6/2 4:D6/3 8:Bb5/3 11:D6/3",
          "0:C#6/2 2:D6/2 4:E6/3 8:A5/6"],
}


def anticipate(txt, chord, minlen):
    """las notas largas que caen en un tiempo entran una semicorchea antes, robándosela a la anterior (la síncopa de la casa, sobre
    el 3+3+2 del bajo); en la mitad del compás, solo si no cambia el acorde"""
    if not txt: return txt
    notes = [t.split(':') for t in txt.split()]
    notes = [[int(a), *b.split('/')] for a, b in notes]
    for i in range(1, len(notes)):
        st, n, d = notes[i][0], notes[i][1], int(notes[i][2])
        pd = int(notes[i - 1][2])
        if d >= minlen and st in (4, 8, 12) and pd >= 2 and (st != 8 or '|' not in chord):
            notes[i - 1][2] = str(pd - 1)
            notes[i][0], notes[i][2] = st - 1, str(d + 1)
    return ' '.join(f'{a}:{n}/{d}' for a, n, d in notes)


def sync(bars, chords, minlen):
    return [anticipate(t, c, minlen) for t, c in zip(bars, chords.split())]


def sections(v):
    M, S = (MEL_A, 16) if v == 'A' else (MEL_B, 14)
    ml = 4 if v == 'A' else 3
    M = dict(M, A=sync(M['A'], CH_A, ml), E1=anticipate(M['E1'], 'Bb|A', ml), E2=anticipate(M['E2'], 'Bb|A', ml),
             B=sync(M['B'], CH_B, ml), C=sync(M['C'], CH_C, ml))
    A1, A2 = M['A'] + [M['E1']], M['A'] + [M['E2']]
    out = [('intro', IN_, [''] * 4, S, ''),
           ('A', CH_A, A1, S, ''), ('A', CH_A, A2, S, ''), ('B', CH_B, M['B'], S, ''), ('C', CH_C, M['C'], S, ''),
           ('K', CH_K, [''] * 8, S, '')]
    if v == 'B': out.append(('A', CH_A, A1, S, ''))                    # (sus compases son más cortos: que el bucle pase de 1:30)
    return out + [('A', CH_A, A2, S, 'stop'), ('B', CH_B, M['B'], S, 'dbl'), ('C', CH_C, M['C'], S, 'dbl')]


# (B: 14 semicorcheas de 0,0893 s = 1,25 s por compás; J.Song cuenta 4 pulsos por compás → 192 "BPM" dan esa duración)
J.TRACKS['triple_aguijon'] = dict(secs=sections, bpm=168, scale=SCALE, tonic=(9, (0, 4, 7)), lufs=-11.0)
TRACKS_BPM = {'A': 168, 'B': 192}
VNAME = {'A': 'shanai', 'B': 'aksak'}


def bass_at(sg, b, st, deg):
    r, q = sg.chord(b, st)
    base = 33 + (r - 33) % 12
    return base + {0: 0, 5: 7, 8: 12}[deg]


def arrange(sg, R, v):
    R.NZ['snare'].exact = R.NZ['crash'].exact = True
    S = sg.steps[0]
    aksak = S == 14
    slp = slap.Rec()
    R.slap = slp
    voice = (SITAR if aksak else SHANAI)
    other = (SHANAI if aksak else SITAR)
    # patrones: { semicorcheas }
    BASS = ((0, 0), (4, 8), (8, 0), (11, 5)) if aksak else ((0, 0), (3, 0), (6, 8), (8, 0), (11, 5), (14, 8))
    KICK = (0, 8, 11) if aksak else (0, 6, 8, 14)
    SNARE = (4,) if aksak else (4, 12)
    DUMS = (0, 8) if aksak else (0, 6, 8)
    TEKS = (2, 4, 6, 10, 12) if aksak else (3, 4, 10, 12, 14)
    TRIPLE = (8, 9, 10) if aksak else (8, 9, 10)                       # la matraca, en la parte de atrás del compás
    for i, (b, st, n, d) in enumerate(sg.mel):
        tag, var = sg.tag[b - 1], sg.var[b - 1]
        if tag == 'B':                                                 # SEPARADAS: cada nota, un instrumento (hoquetus)
            # (v2: pasa de un instrumento a otro cada dos compases, pregunta y respuesta; nota a nota cortaba el canto)
            k, prog = (('hk1', voice), ('hk2', other), ('hk3', KOTO), ('hk1', voice))[(sg.pos[b - 1] - 1) // 2]
            R.gm(k, prog, b, st, n, d, 100 if 'dbl' not in var else 108, gate=0.95)
            R.notes.setdefault('lead', []).append((sg.q(b, st), sg.q(b, st + d), n))
        else:
            R.gm('lead', voice, b, st, n, d, 106 if d > 1 else 92, gate=0.96)
            if not aksak: R.chip('voice', b, st, n - 12, d, I_VOICE, q=q_n163, gate=0.92, release=2)
            if tag == 'C':                                             # ENROLLADAS: las tres a la vez
                R.gm('low', KOTO, b, st, n - 12, d, 92 if 'dbl' in var else 84, gate=0.95)
    tb = [b for b in range(1, sg.NB + 1) if sg.tag[b - 1] == 'C']
    J.thirds(sg, R, set(tb), other, 84)
    for b in range(1, sg.NB + 1):
        tag, var, k, L, si = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1], sg.sidx[b - 1]
        last, stop = k == L, 'stop' in var and k < L
        nxt = sg.tag[b] if b < sg.NB else sg.tag[sg.INTRO]
        full = tag != 'intro' or k >= 3
        # ── BAJO ──
        if full and not (tag == 'K' and k <= 4):
            for st, deg in ((BASS[0],) if stop else BASS):
                t0 = sg.t(b, st)
                slp.add(t0, t0 + sg.dur(b, 2) * 0.9, bass_at(sg, b, st, deg), 112 if st == 0 else 96)
        # ── OSTINATO: dulcémele en semicorcheas por el acorde, el acento en el grupo ──
        if tag in ('A', 'C') and not stop or (tag == 'intro' and k == 4):
            for st in range(S):
                c = sg.chord(b, st)
                nn = J.place(None, c, 57)[(0, 1, 2, 3, 2, 1, 2, 3)[st % 8]]
                vel = 74 if st in (BASS[0][0], 4, 8) else 52
                if not R.rub(b, st, nn, 1): R.gm('ost', DULCIMER, b, st, nn, 1, vel)
        # ── COLCHÓN N163 en B y C ──
        if tag in ('B', 'C'):
            for half in (0, 1):
                r, q = sg.chords[b - 1][half]
                base = 53 + (r - 53) % 12
                st0 = 0 if half == 0 else S // 2
                for j, iv in enumerate(q[1:]):
                    R.chip(('pad1', 'pad2')[j], b, st0, base + iv, S // 2, I_PAD, q=q_n163, gate=0.97, release=6)
        # ── EL ACENTO: el koto pellizca bajando por el acorde donde la melodía se posa (el adorno del volcán) ──
        if tag == 'A' and not stop and k in (4, 8):
            c = sg.chord(b, S - 2)
            for st, idx in ((S - 3, 3), (S - 2, 2), (S - 1, 1)):
                nn = J.place(None, c, 69)[idx]
                if not R.rub(b, st, nn, 1): R.gm('accent', KOTO, b, st, nn, 1, 68)
        # ── BATERÍA ──
        if tag == 'K':                                                 # EL CORRO DE LA MATRACA
            for st in range(S):
                if k <= 4:
                    if st in (0, 1, 2): R.dr('wood', b, st, CASTANETS, 112 - 10 * st)
                    if k >= 2 and st in TRIPLE: R.dr('wood', b, st, WOOD_H, 100)
                    if k >= 3 and st in DUMS: R.dr('dar', b, st, DUM, 108)
                    if k >= 3 and st in TEKS: R.dr('dar', b, st, TEK, 84)
                else:
                    if st in DUMS: R.dr('dar', b, st, DUM, 112)
                    if st % 2 == 1: R.dr('dar', b, st, TEK2, 70)
                    if st in TEKS: R.dr('dar', b, st, TEK, 92)
                    if st in (0, 1, 2) or st in TRIPLE: R.dr('wood', b, st, CASTANETS if st < 4 else CLAVES, 104)
                    if st in KICK: R.kick(b, st, 0.9)
            if k in (1, 5): R.gm('taiko', TAIKO, b, 0, 45, 4, 112)
            if k == 4: R.dr('vibra', b, 0, VIBRA, 110, 8)
            if last:
                for st in range(S // 2, S):
                    R.gm('timp', TIMPANI, b, st, 45, 1, 70 + 4 * (st - S // 2), gate=0.9)
            continue
        if tag == 'intro':
            for st in range(S):
                if st in (0, 1, 2) or st in TRIPLE: R.dr('wood', b, st, CASTANETS, 112 if st in (0, 8) else 92)
                if k >= 2 and st in DUMS: R.dr('dar', b, st, DUM, 100)
                if k >= 2 and st in TEKS: R.dr('dar', b, st, TEK, 78)
                if k >= 3 and st in KICK: R.kick(b, st, 0.85)
            if k == 1: R.gm('taiko', TAIKO, b, 0, 45, 4, 104)
            if k == 2: R.dr('vibra', b, 0, VIBRA, 96, 8)
            if k == 4:
                for st in range(S // 2, S): R.gm('timp', TIMPANI, b, st, 45, 1, 66 + 4 * (st - S // 2), gate=0.9)
            continue
        if stop:                                                       # a GOLPES: la banda solo en el 1; la melodía sigue
            R.kick(b, 0, 1.0); R.snare(b, 0, 0.5); R.gm('taiko', TAIKO, b, 0, 45, 3, 104)
            for st in TRIPLE: R.dr('wood', b, st, CASTANETS, 100)
            R.dr('dar', b, 0, DUM, 110)
            continue
        for st in range(S):
            t = sg.t(b, st)
            if st in KICK: R.kick(b, st, 1.0 if st == 0 else 0.85)
            if st in SNARE: R.snare(b, st, 0.9)
            if st in DUMS: R.dr('dar', b, st, DUM2, 92)
            if st in TEKS: R.dr('dar', b, st, TEK, 72)
            if st % 2 == 0: R.NZ['hat'].hit(t, 0, [4, 2, 1] if st % 4 == 0 else [3, 1])
            if tag == 'C' and st % 2 == 0: R.dr('tamb', b, st, TAMB, 66 if st % 4 else 84)
            if tag == 'B' and st in TRIPLE: R.dr('wood', b, st, CLAVES, 70)
        if k in (1, 5): R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)
        if k == 1: R.gm('taiko', TAIKO, b, 0, 45, 4, 108)
        if tag != 'B' and k % 2 == 0:                                  # la matraca al final de cada dos compases
            for st in TRIPLE: R.dr('wood', b, st, CASTANETS, 96 if st == TRIPLE[-1] else 80)
        if last and nxt == 'C':
            t = sg.t(b + 1, 0) if b < sg.NB else 0
            R.gmt('revcym', REV_CYM, t - 1.35, t + 0.1, 60, 80)
        if last and nxt in ('K',):
            R.dr('vibra', b, S // 2, VIBRA, 100, 4)


LV = {'lead': 0, 'hk1': -1, 'hk2': -1, 'hk3': -1, 'thirds': -7, 'low': -7, 'voice': -11, 'ost': -8, 'accent': -7, 'pad': -10,
      'bass': 1, 'kick': -1, 'snare': 2, 'dar': -2, 'wood': -4, 'tamb': -9, 'hat': -9, 'crash': -7, 'taiko': -3, 'timp': -2,
      'vibra': -6, 'revcym': -9}
TIGHT = ('lead', 'hk1', 'hk2', 'hk3', 'thirds', 'low', 'ost', 'accent')


def slap_adv(n):
    r = slap.Rec(); r.add(0.5, 1.0, 45, 100)
    y = r.render(2 * SR)
    e = np.convolve(np.abs(y), np.ones(48) / 48, mode='same')
    return int(np.argmax(e[SR // 2:] >= 0.5 * e.max()))


MUTE = ('lead', 'hk1', 'hk2', 'hk3', 'thirds', 'low', 'voice')


def build(v, instrumental=False):
    J.TRACKS['triple_aguijon']['bpm'] = TRACKS_BPM[v]
    sg = J.Song('triple_aguijon', v)
    R = MN.Rig(sg)
    R.Cn['voice'] = F.Chan(len(R.Cn['lead'].f))
    arrange(sg, R, v)
    n = int(sg.NB * sg.BAR * SR)
    at = int(sg.INTRO * sg.BAR * SR)
    L = n + 3 * SR
    S = {}
    for pre, recs in (('', R.G), ('d_', R.D)):
        for k, r in recs.items():
            if k == 'revcym':
                y = r.render(L); adv = MN.GM_LAT
                y = np.concatenate([y[adv:], np.zeros(adv)])
            else:
                adv = MN.attack_smp(r, 0.25 if r.drums else 0.5)
                if k in TIGHT: y = MN.tight_stem(r, L, adv, 0.012)
                else:
                    y = r.render(L); y = np.concatenate([y[adv:], np.zeros(adv)])
                S[pre + k] = y
                MN.wrap_pre_roll(S, pre + k, r, adv, at / SR, n)
                continue
            S[pre + k] = y
    for k in list(S):
        if k.startswith('d_'):
            q = k[2:]
            S[q] = (S[q] + S.pop(k)) if q in S else S.pop(k)
    adv = slap_adv(n)
    y = R.slap.render(L + adv)
    S['bass'] = y[adv:adv + L]
    base = F.tnd_dac(np.full(R.NS, 64 / 22638.0))
    def cut(x):
        x = x[:L] - np.mean(x[:n])
        return np.concatenate([x, np.zeros(L - len(x))]) if len(x) < L else x
    S.update({'kick': cut(F.tnd_dac((R.dk + 64) / 22638.0) - base),
              'snare': cut(F.tnd_dac((R.sn + 64) / 22638.0) - base) + cut(F.tnd_dac(R.NZ['snare'].render() / 22638.0 * 12)),
              'hat': cut(F.tnd_dac(R.NZ['hat'].render() / 22638.0 * 12)),
              'crash': cut(F.tnd_dac(R.NZ['crash'].render() / 22638.0 * 12)),
              'pad': cut(F.render_wave(R.Cn['pad1'], J.WAVES) * 0.0075) + cut(F.render_wave(R.Cn['pad2'], J.WAVES) * 0.0075),
              'voice': cut(F.render_wave(R.Cn['voice'], J.WAVES) * 0.0075)})
    from scipy.signal import butter, sosfilt
    hp = butter(2, 30, btype='high', fs=SR, output='sos')
    S = {k: sosfilt(hp, GN.fold(x, n, at)) for k, x in S.items() if np.abs(x).max() > 0}
    g = GN.level(S, {k: LV.get(k, -10) for k in S}, 'lead')
    if instrumental:                                                   # (sin melodía: el Templo se aprobó así)
        for k in MUTE:
            if k in g: g[k] = 0.0
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    # (las tres voces del hoquetus, abiertas: izquierda, centro, derecha — se oye cómo se separan)
    side = sd('hk1', 0.45) - sd('hk3', 0.45) + sd('ost', 0.3) - sd('dar', 0.15) + sd('wood', 0.3) - sd('thirds', 0.25) \
        + sd('low', 0.2) + sd('hat', 0.3) - sd('tamb', 0.3) + sd('accent', 0.35)
    y = F.master(np.stack([x + side, x - side], 1), lufs=-11.0, ceiling=0.8)
    return sg, R, S, g, y, n, at


def report(v, sg, R, S, g, y, n, at):
    print(f'── triple_aguijon {v} "{VNAME[v]}"')
    print(f'  {sg.NB} compases × {sg.BAR:.3f} s (semicorchea {sg.BAR / sg.steps[0] * 1000:.1f} ms; matraca 90 ms): intro {at / SR:.2f} s + bucle {(n - at) / SR:.2f} s, '
          f'{F.loudness(y):.1f} LUFS, pico {np.abs(y).max():.2f}')
    tot = sum(np.mean((S[k] * g[k]) ** 2) for k in S)
    e = {k: 100 * np.mean((S[k] * g[k]) ** 2) / tot for k in S}
    print('  energía: ' + ' '.join(f'{k} {e[k]:.0f}' for k in sorted(e, key=e.get, reverse=True)))
    lb, lo, out, off = J.check(sg)
    beats = {16: 4, 14: None}
    groups = (0, 4, 8)
    off = np.mean([(st % 4 != 0) if sg.steps[b - 1] == 16 else (st not in groups) for b, st, nn, d in sg.mel])
    iv = np.array([sg.mel[i + 1][2] - sg.mel[i][2] for i in range(len(sg.mel) - 1)])
    tn = np.mean([nn % 12 in sg.tones(b, st) for b, st, nn, d in sg.mel])
    print(f'  ¿canta? (jungla y montañas: acorde 79-90 %, por grado 20-44 %, repetidas 1-23 %, largas 11-46 %): acorde {100 * tn:.0f} %, por grado '
          f'{100 * np.mean((abs(iv) > 0) & (abs(iv) <= 2)):.0f} %, repetidas {100 * np.mean(iv == 0):.0f} %, '
          f'largas {100 * np.mean([sg.q(b, st + d) - sg.q(b, st) >= 4 for b, st, nn, d in sg.mel]):.0f} %')
    print(f'  melodía: {len(sg.mel)} notas, a contratiempo {100 * off:.0f} %; largas fuera del acorde: {lb or "ninguna"}; sueltas: {lo or "ninguna"}; fuera de la escala: {out or "ninguna"}')
    others = []
    for k in ('ost', 'pad1', 'pad2', 'accent', 'thirds', 'low'):
        others += R.notes.get(k, [])
    cl = J.clashes(sg, sg.mel, others)
    print(f'  choques de 2ª menor / 7ª mayor / tritono con otra voz: {len(cl)} {cl[:6]}')
    print('  secciones: ' + ' | '.join(f'{sg.tag[s - 1]} {(s - 1) * sg.BAR:.1f}' for s in sg.starts))
    lp = y[at:]
    print(f'  costura: salto {np.abs(lp[0] - lp[-1]).max():.3f} (pista entera, p99,9: {np.percentile(np.abs(np.diff(lp, axis=0)).max(1), 99.9):.3f})')


if __name__ == '__main__':
    os.makedirs(PRUEBAS, exist_ok=True)
    for v in ('A', 'B'):
        if os.environ.get('INSTALL') and os.environ.get('TRIPLE', 'A') != v: continue
        sg, R, S, g, y, n, at = build(v)
        report(v, sg, R, S, g, y, n, at)
        if os.environ.get('REPORT'): continue
        if os.environ.get('INSTALL'):
            J.export(y, at, os.path.join(F.MUSIC_DIR, 'bosses', 'triple_aguijon'))
            J.write_mid(F.out('triple_aguijon', 'mid'), sg, R)
            continue
        base = os.path.join(PRUEBAS, f'v2_{v}_{VNAME[v]}')
        J.export(y, at, base)
        _, _, _, _, yi, _, _ = build(v, True)
        J.enc(np.concatenate([yi, yi[at:]]), base + '_sin_melodia.ogg')
        os.system(f'ffmpeg -v quiet -y -i "{base}_sin_melodia.ogg" -q:a 3 "{base}_sin_melodia.mp3"')
        J.enc(np.concatenate([y, y[at:]]), base + '_preview.ogg')
        os.system(f'ffmpeg -v quiet -y -i "{base}_preview.ogg" -q:a 3 "{base}_preview.mp3"')
