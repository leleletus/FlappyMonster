#!/usr/bin/env python3
# tools/music/montana_nes.py — la música de LAS MONTAÑAS HELADAS (mundo `nieve`, el de la Bola de Nieve) tras partir la
# isla helada en dos: los temas de antes (nieve_1, nieve_2, nieve_bonus de worlds_nes.py y el map_nieve de
# worldmap_nes.py) pasan a LA COSTA HELADA y las montañas estrenan los suyos. PREVIAS para que el usuario elija; no
# toca assets/ ni el index.json.
#
# El usuario: "los mismos motifs que con la isla helada pero temas originales; instrumentos más originales y
# 'helados'" — la primera isla con un reparto moderno (instrumentos GM del soundfont, gm.py) en vez del de Famicom;
# el chip queda debajo como color de la casa (bajo de triángulo, bombo y caja de DPCM, platos de ruido, colchón N163).
#
# LOS MOTIVOS DE LA ISLA HELADA que se citan (cada uno en su sitio, sobre su propio acorde):
#   · el MOTIVO navideño de la caja de música (`W.WMOTIF`: la nota, su octava arriba en negras y la bajada por grados):
#     su cabeza abre el estribillo de montana_1, sobre el IV como en nieve_1;
#   · la frase de 1:48 (`W.W148`): tres corcheas que suben y la nota larga a contratiempo (2-2-2-6) — la "trepada" de
#     B en montana_1 y la respuesta de cada frase de montana_2; y su cierre (`W.W148_END`): tres notas repetidas con
#     puntillo y un salto — la RACHA con que empieza cada frase de montana_2 (el mismo golpe del jefe, la Bola);
#   · las CAMPANITAS QUE CAEN (el leitmotiv de map_nieve: las notas del acorde bajando en semicorcheas): la cascada de
#     la avalancha (montana_1 B) y los carámbanos del solo del bonus;
#   · los CASCABELES (ahora los de la batería GM) y la CAJA DE MÚSICA una octava arriba (ahora celesta / música GM);
#   · LA LLAMADA (5-1-3-5), una vez por pista, sobre su acorde.
# El ACENTO propio de las montañas (regla 9: melódico, solo notas del acorde, donde la melodía se posa): el YODEL —
# la 5ª abajo, la 3ª una sexta arriba, la 5ª otra vez y la raíz arriba (un salto de voz de los Alpes). En la noche
# (montana_2): el AULLIDO del viento — una voz hueca del N163 que sube deslizándose hasta la 5ª del acorde.
#
#   montana_1      "La escalada" — el TEMA (niveles impares): Re mayor, 144 BPM. Zancadas que suben por el acorde
#                  (6+4+6) y trepadas de semicorcheas; cada intento llega más alto; un destello lidio (Do# sobre Sol).
#                  Giro oscuro: Si♭ (♭VI). Estribillo C: la cabeza del motivo navideño + la llamada.
#                    A "carillón"  vibráfono + celesta una octava arriba, arpa en corcheas que suben, colchón N163,
#                                  escobillas y cascabeles; yodel de glockenspiel; eco corto (de la casa, sin reverb)
#                    B "glaciar"   (más original) "Crystal" GM + coro en las notas largas, Ice Rain en 3+3+2, vidrio
#                                  frotado, caja de orquesta y bombo de concierto, platillo al revés; yodel de TROMPA
#                                  (la trompa alpina); reverb de "escarcha"; sección nueva V = la AVALANCHA
#   montana_2      "Viento negro" — la noche y la ventisca (niveles pares; torre_viento): Si menor, 128 BPM. Cada
#                  frase empieza con la RACHA (tres repetidas y salto) y contesta trepando (2-2-2-6). Un remolino de
#                  6 notas contra el compás de 8 corcheas (se desfasa: el viento). Giro oscuro: Sol menor (el Si♭).
#                  W = la TORMENTA: la racha se acelera (puntillos → corcheas → semicorcheas).
#                    A "flauta"     flauta GM + celesta en las notas largas, arpa en el remolino, vidrio en B
#                    B "coro"       (más original) "Voice Oohs" + glockenspiel una octava arriba, mazo sintético
#                                   en el remolino, coro en B, viento aullando, timbales; E = el OJO de la tormenta
#   montana_bonus  "Guerra de nieve" — su PROPIO tema corto: Mi♭ mayor, 160: tirar la bola (tres semicorcheas que
#                  suben y la nota a contratiempo) y que caiga (corcheas que bajan). Solo de percusión "hielo".
#                    A "carámbanos" glockenspiel + pulso, pizzicato a contratiempo, batería de competición
#                    B "polca"      (más original) silbido + celesta, pizzicato y bajo en "um-pa", trompa en el yodel
#
#   ~/.venvs/fm-music/bin/python tools/music/montana_nes.py [montana_1 montana_2 montana_bonus mapa]
#   → previas en FlappyMonster_pruebas/musica_montanas/ · REPORT=1 → solo números · INSTALL=1 → lo elegido (CHOSEN)
#   en assets/music/worlds/montanas/ y map/map_nieve.ogg. Se comprueba con números (NO se ha escuchado). El arreglo
#   del mapa ("Rumbo a las islas", misma melodía, acordes, tempo y 2 116 800 muestras que los otros) es
#   `build_map(v)`; worldmap_nes.py lo usa para map_nieve (variante A).
# ELEGIDAS (2026-10-29): montana_1 B, montana_2 B (sin el eco del aullido), montana_bonus A, mapa A.
import os, sys, subprocess, tempfile
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, play, wavetable, q_n163, q_tri
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W
import jungla_nes as J
import worldmap_nes as M
import gm as GM

P, CH, nm, place = W.P, W.CH, J.nm, J.place
MAJ, MIN = (0, 4, 7), (0, 3, 7)
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica_montanas'
GM_LAT = M.GM_LAT                                                    # (muestras: el retraso mínimo de fluidsynth)

# ══ INSTRUMENTOS GM (banco, programa) del GeneralUser GS — el reparto helado ══════════════════════════════════════
CELESTA, GLOCK, MUSICBOX, VIBES, TUBULAR = 8, 9, 10, 11, 14
PIZZ, HARP, TIMPANI, TREM = 45, 46, 47, 44
CHOIR, OOHS = 52, 53
FLUTE, WHISTLE = 73, 78
BOWED_GLASS, HALO, ICE_RAIN, CRYSTAL = 92, 94, 96, 98
REV_CYM = 119
WIND = (3, 122)                       # viento (efecto)
SYNTH_MALLET = (1, 98)
HORN = (1, 60)                        # trompa solista: la trompa alpina del yodel
# batería GM (canal 10): kit 0 estándar · 40 escobillas · 48 orquesta
K_STD, K_BRUSH, K_ORCH = 0, 40, 48
BD, SN, RIDE_BELL, SPLASH, CRASH_GM, TRI_M, TRI_O, JINGLE, BELL_TREE, CASTANETS, CLAVES, WOOD_H, WOOD_L = \
    36, 38, 53, 55, 49, 80, 81, 83, 84, 85, 75, 76, 77
CONCERT_BD = (8, 116)

# ══ CHIP: ondas del N163 y sus instrumentos ═══════════════════════════════════════════════════════════════════════
WAVES = [wavetable([1.0, 0.0, 0.55, 0.0, 0.0, 0.32, 0.0, 0.18]),            # 0 caja de música / campana
         wavetable([1.0, 0.3, 0.1]),                                         # 1 colchón
         wavetable([1.0, 0.05, 0.45, 0.03, 0.2, 0.02, 0.08])]                 # 2 hueca (el aullido)
I_PAD = {'vol': [2, 3, 4, 5, 5, 5], 'sus': 5, 'vib': (24, 0.12, 4.5), 'duty': 1}
I_TRI = {'vol': [15], 'sus': 15}
I_PULSE = J.I_PULSE
I_DBL = J.I_DBL
# el AULLIDO: entra una 5ª por debajo y sube deslizándose (~0,25 s) hasta su nota; vibrato lento; se apaga despacio
I_HOWL = {'vol': [2, 3, 4, 5, 6, 7, 8, 8, 9, 9, 9, 9, 8, 8, 8, 7, 7, 7, 6, 6, 6, 5, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 1],
          'sus': 1, 'vib': (16, 0.25, 4.2), 'duty': 2,
          'drop': [-7, -6.4, -5.8, -5.2, -4.6, -4.0, -3.4, -2.8, -2.3, -1.8, -1.4, -1.0, -0.7, -0.45, -0.25, -0.1]}
HAT, SNARE_N, CRASH_N = J.HAT, J.SNARE_N, J.CRASH_N


class Rec(GM.Rec):
    """gm.Rec con BANCO (los sonidos 'helados' del GeneralUser GS viven en otros bancos: Wind 3, Synth Mallet 1…) y
    con KIT de batería (escobillas, orquesta). `program` guarda (banco, programa) para que gm.cached los distinga."""
    def __init__(self, prog=0, drums=False, kit=0):
        bank, p = prog if isinstance(prog, tuple) else (0, prog)
        super().__init__(p, drums)
        self.bank, self.prog, self.kit = bank, p, kit
        self.program = (bank, p, kit)

    def render(self, n):
        out = np.zeros(n)
        if not self.ev:
            return out
        import mido, soundfile as sf
        ch = 9 if self.drums else 0
        m = mido.MidiFile(type=0, ticks_per_beat=480); tr = mido.MidiTrack(); m.tracks.append(tr)
        tr.append(mido.MetaMessage('set_tempo', tempo=500000))
        if self.drums:
            tr.append(mido.Message('program_change', channel=ch, program=self.kit))
        else:
            tr.append(mido.Message('control_change', channel=ch, control=0, value=self.bank))
            tr.append(mido.Message('program_change', channel=ch, program=self.prog))
        ev = []
        for t0, t1, note, vel in self.ev:
            a, b = int(round(t0 * GM.TPS)), int(round(t1 * GM.TPS))
            ev += [(max(a + 1, b), 0, note, 0), (a, 1, note, vel)]
        t = 0
        for tt, on, note, vel in sorted(ev):
            tr.append(mido.Message('note_on' if on else 'note_off', channel=ch, note=note, velocity=vel, time=tt - t)); t = tt
        with tempfile.TemporaryDirectory() as d:
            mp, wp = os.path.join(d, 'g.mid'), os.path.join(d, 'g.wav')
            m.save(mp)
            subprocess.run(['fluidsynth', '-ni', '-R', '0', '-C', '0', '-g', '1.0', '-r', str(SR), '-F', wp, self.sf, mp],
                           capture_output=True)
            y, _ = sf.read(wp)
        y = y.mean(1) if y.ndim == 2 else y
        out[:min(n, len(y))] = y[:n]
        return out - np.mean(out)


class Rig(J.Rig):
    """el Rig de la jungla con bancos GM, kits de batería y más canales de chip (el aullido)"""
    def __init__(self, sg):
        super().__init__(sg)
        NF = len(self.Cn['lead'].f)
        self.Cn['howl'] = Chan(NF)
        self.NZ['hat'].exact = True              # (el siseo de nieve en semicorcheas, cada golpe en su muestra: famicom.Noise.exact)

    def gm(self, k, prog, b, st, n, d, vel, gate=0.95):
        sg = self.sg
        self.G.setdefault(k, Rec(prog)).add(sg.t(b, st), sg.t(b, st) + sg.dur(b, d) * gate, n, vel)
        self.notes.setdefault(k, []).append((sg.q(b, st), sg.q(b, st + d), n))

    def gmt(self, k, prog, t0, t1, n, vel):
        """una nota GM en segundos (platillos al revés, viento: empiezan antes del compás)"""
        self.G.setdefault(k, Rec(prog)).add(max(0.0, t0), t1, n, vel)

    def dr(self, k, b, st, n, vel, d=1, kit=0):
        sg = self.sg
        self.D.setdefault(k, Rec(drums=True, kit=kit)).add(sg.t(b, st), sg.t(b, st) + sg.dur(b, d), n, vel)


# ══ MONTANA_1 "La escalada" (Re mayor, 144) ══════════════════════════════════════════════════════════════════════
SCALE_D = {2, 4, 6, 7, 9, 11, 1}
M1_IN = "D D G A"
M1_A = "D A Bm G D F#m G|A D"
M1_B = "G D Em Bm G D Bb A"                                          # el GIRO OSCURO: Si♭ (♭VI) → La
M1_C = "G A Bm F#m G A Em|A D"                                       # estribillo: el motivo sobre el IV, la llamada
M1_V = "Bm Bm G G Em Em F# A"                                        # (B) la AVALANCHA: en el relativo, cae
M1_MEL = {
    # A: la ZANCADA (6+4+6 por el acorde, la última adelantada) y la TREPADA (semicorcheas que suben, giran y caen); cada intento más alto
    'A': ["0:D5/6 6:F#5/4 10:A5/6",
          "0:B5/1 1:C#6/1 2:B5/1 3:A5/1 4:E5/6 10:A5/2 12:C#6/4",
          "0:D5/6 6:F#5/4 10:B5/6",
          "0:C#6/1 1:D6/1 2:B5/1 3:A5/1 4:G5/6 10:B5/2 12:D6/4",                      # (Do# sobre Sol: el destello lidio)
          "0:F#5/6 6:A5/4 10:D6/6",
          "0:C#6/2 2:D6/1 3:E6/1 4:F#6/6 10:E6/1 11:D6/1 12:C#6/4",                   # la cima de la frase
          "0:B5/3 3:G5/3 6:D5/2 8:C#5/3 11:E5/3 14:A5/2"],                            # el tresillo 3+3+2
    'E1': "0:F#5/2 2:A5/2 4:D6/8 12:A5/4",
    'E2': "0:F#5/6 6:E5/2 8:D5/8",
    # B: la VISTA desde arriba — notas largas que caen; la trepada de la frase de 1:48 (2-2-2 y la larga); Si♭
    'B': ["0:D6/6 6:B5/4 10:G5/6",
          "2:F#5/2 4:A5/2 6:D6/10",
          "0:B5/6 6:G5/4 10:E5/6",
          "2:D5/2 4:F#5/2 6:B5/10",
          "0:D6/6 6:B5/2 8:G5/2 10:B5/6",
          "0:A5/6 6:D6/2 8:F#6/8",
          "0:F6/6 6:D6/2 8:Bb5/8",
          "2:C#6/2 4:A5/2 6:E5/10"],
    # C: el ESTRIBILLO — la cabeza del motivo navideño (la nota, su octava, la bajada) sobre Sol, y la llamada
    'C': ["0:D5/4 4:D6/4 8:C#6/2 10:B5/6",
          "0:C#6/2 2:B5/2 4:A5/4 8:E5/4 12:A5/4",
          "0:B4/4 4:B5/4 8:A5/2 10:G5/2 12:F#5/4",
          "0:E5/2 2:F#5/2 4:A5/4 8:C#6/8",
          "0:D5/4 4:D6/4 8:E6/2 10:D6/2 12:B5/4",
          "0:C#6/2 2:D6/2 4:E6/6 10:D6/2 12:C#6/4",
          "0:B5/3 3:G5/3 6:E5/2 8:C#6/3 11:A5/3 14:E5/2",
          "0:A4/4 4:D5/2 6:F#5/2 8:A5/8"],                                             # LA LLAMADA (La-Re-Fa#-La)
    # V: la AVALANCHA — las campanitas que caen hechas cascada (semicorcheas por el acorde) y un salto que remonta
    'V': ["0:F#6/1 1:E6/1 2:D6/1 3:C#6/1 4:B5/4 8:F#5/8",
          "4:B5/2 6:D6/2 8:F#6/8",
          "0:G6/1 1:F#6/1 2:E6/1 3:D6/1 4:B5/4 8:G5/8",
          "4:G5/2 6:B5/2 8:D6/8",
          "0:E6/1 1:D6/1 2:C#6/1 3:B5/1 4:G5/4 8:E5/8",
          "4:E5/2 6:G5/2 8:B5/8",
          "0:A#5/6 6:C#6/2 8:F#6/8",
          "0:E6/4 4:C#6/4 8:A5/4 12:E5/4"],
}


def sections_m1(v):
    M_ = M1_MEL
    A1, A2 = M_['A'] + [M_['E1']], M_['A'] + [M_['E2']]
    head = [('intro', M1_IN, [''] * 4, 16, ''),
            ('A', M1_A, A1, 16, ''), ('A', M1_A, A2, 16, ''), ('B', M1_B, M_['B'], 16, ''), ('C', M1_C, M_['C'], 16, '')]
    if v == 'A':
        return head + [('A', M1_A, A1, 16, 'thin'), ('A', M1_A, A2, 16, 'cm'), ('C', M1_C, M_['C'], 16, 'dbl')]
    return head + [('V', M1_V, M_['V'], 16, ''), ('A', M1_A, A2, 16, 'thirds'), ('C', M1_C, M_['C'], 16, 'dbl')]


# ══ MONTANA_2 "Viento negro" (Si menor, 128) ═════════════════════════════════════════════════════════════════════
SCALE_Bm = {11, 1, 2, 4, 6, 7, 9}
M2_IN = "Bm Bm G F#"
M2_A = "Bm G A F# Bm Em Em|F# Bm"
M2_B = "G D Em Bm G D Gm|F# Bm"                                      # el GIRO OSCURO: Sol menor (el Si♭ = La#)
M2_W = "Bm Bm G G Em Em F# F#"                                       # la TORMENTA
M2_E = "Bm A G F#m Em Bm Em|F# Bm"                                   # (B) el OJO de la tormenta
M2_MEL = {
    # A: la RACHA (tres repetidas con puntillo y el salto: el cierre de la frase de 1:48), una semicorchea tarde,
    # y la TREPADA (tres corcheas que suben y la larga: el 2º compás de la frase de 1:48)
    'A': ["1:F#5/3 5:F#5/3 9:F#5/3 13:D6/3",                                         # (llega tarde: el viento empuja)
          "2:G5/2 4:A5/2 6:B5/2 8:D6/8",
          "1:E5/3 5:E5/3 9:E5/3 13:C#6/3",
          "2:C#6/2 4:B5/2 6:A#5/2 8:F#5/8",
          "1:F#5/3 5:F#5/3 9:F#5/3 13:B5/3",
          "2:B5/2 4:C#6/2 6:D6/2 8:E6/8",
          "0:G5/3 3:B5/3 6:E6/2 8:C#6/3 11:A#5/3 14:F#5/2"],                         # el tresillo 3+3+2
    'E1': "0:D6/2 2:C#6/2 4:B5/2 6:F#5/10",
    'E2': "0:F#5/3 3:D5/3 6:B4/10",
    # B: el aullido largo del viento, en secuencia, y el Sol menor
    'B': ["0:B5/6 6:A5/2 8:G5/8",
          "0:F#5/6 6:E5/2 8:D5/8",
          "0:E5/2 2:G5/2 4:B5/4 8:E6/6 14:D6/2",
          "0:D6/4 4:C#6/2 6:B5/2 8:F#5/8",
          "0:G5/2 2:B5/2 4:D6/4 8:G6/6 14:F#6/2",
          "0:F#6/4 4:E6/2 6:D6/2 8:A5/8",
          "0:D6/6 6:Bb5/2 8:C#6/6 14:A#5/2",
          "0:F#5/4 4:B5/2 6:D6/2 8:F#6/8"],                                           # LA LLAMADA (Fa#-Si-Re-Fa#)
    # W: la TORMENTA — la racha se acelera: puntillos, corcheas, semicorcheas; luego se deja caer
    'W': ["1:F#5/3 5:F#5/3 9:F#5/3 13:B5/3",
          "0:D6/2 2:D6/2 4:D6/2 6:C#6/2 8:B5/8",
          "1:G5/3 5:G5/3 9:G5/3 13:D6/3",
          "0:B5/2 2:B5/2 4:B5/2 6:A5/2 8:G5/8",
          "0:E6/1 1:E6/1 2:E6/1 3:E6/1 4:D6/1 5:D6/1 6:D6/1 7:C#6/1 8:B5/8",
          "0:G6/1 1:G6/1 2:G6/1 3:G6/1 4:F#6/1 5:F#6/1 6:F#6/1 7:E6/1 8:B5/8",
          "0:F#6/6 6:E6/1 7:D6/1 8:C#6/4 12:A#5/4",
          "0:C#6/4 4:A#5/4 8:F#5/8"],
    # E: el OJO de la tormenta — notas largas, el coro solo
    'E': ["0:D6/8 8:B5/8", "0:C#6/12 12:A5/4", "0:B5/8 8:D6/8", "0:A5/4 4:C#6/4 8:F#6/8",
          "0:G5/4 4:B5/4 8:E6/8", "0:D6/8 8:F#5/8", "0:E6/6 6:D6/2 8:C#6/8", "0:D6/4 4:B5/4 8:F#5/8"],
}


def sections_m2(v):
    M_ = M2_MEL
    A1, A2 = M_['A'] + [M_['E1']], M_['A'] + [M_['E2']]
    head = [('intro', M2_IN, [''] * 4, 16, ''),
            ('A', M2_A, A1, 16, ''), ('A', M2_A, A2, 16, ''), ('B', M2_B, M_['B'], 16, ''), ('W', M2_W, M_['W'], 16, '')]
    if v == 'A':
        return head + [('A', M2_A, A1, 16, 'stop'), ('B', M2_B, M_['B'], 16, 'dbl')]
    return head + [('E', M2_E, M_['E'], 16, 'thin'), ('A', M2_A, A2, 16, 'thirds'), ('B', M2_B, M_['B'], 16, 'dbl')]


# ══ MONTANA_BONUS "Guerra de nieve" (Mi♭ mayor, 160) ═════════════════════════════════════════════════════════════
SCALE_Eb = {3, 5, 7, 8, 10, 0, 2}
MB_IN = "Eb Eb Eb Bb"
MB_A = "Eb Bb Cm Ab Eb Bb Ab|Bb Eb"
MB_B = "Ab Bb Gm Cm Ab Abm Fm|Bb Eb"                                 # el GIRO OSCURO: La♭ menor (iv menor prestado)
MB_MEL = {
    # A: TIRAR la bola (tres semicorcheas que suben y la nota a contratiempo, un rebote y la nota alta en el 3) y que
    # CAIGA (corcheas que bajan por el acorde y la larga)
    'A': ["0:Bb4/1 1:Eb5/1 2:G5/1 3:Bb5/3 6:G5/1 7:Bb5/1 8:Eb6/6 14:D6/2",
          "0:C6/1 1:Bb5/1 2:F5/2 4:D5/2 6:F5/2 8:Bb5/8",
          "0:G4/1 1:C5/1 2:Eb5/1 3:G5/3 6:Eb5/1 7:G5/1 8:C6/6 14:Bb5/2",
          "0:Ab5/2 2:Eb5/2 4:C5/2 6:Eb5/2 8:Ab5/8",
          "0:Bb4/1 1:Eb5/1 2:G5/1 3:Bb5/3 6:G5/1 7:Bb5/1 8:G6/6 14:F6/2",
          "0:F6/1 1:Eb6/1 2:D6/2 4:Bb5/2 6:F5/2 8:Bb5/8",
          "0:C6/3 3:Ab5/3 6:Eb5/2 8:D5/3 11:F5/3 14:Bb5/2"],                          # el tresillo 3+3+2
    'E1': "0:G5/2 2:Bb5/2 4:Eb6/8 12:Bb5/4",
    'E2': "0:Bb5/4 4:G5/4 8:Eb5/8",
    'B': ["0:Ab5/4 4:C6/4 8:Eb6/6 14:D6/2",
          "0:D6/4 4:Bb5/2 6:F5/2 8:Bb5/8",
          "0:G5/4 4:Bb5/4 8:D6/6 14:C6/2",
          "0:C6/4 4:G5/2 6:Eb5/2 8:G5/8",
          "0:Eb6/4 4:C6/2 6:Ab5/2 8:C6/6 14:Bb5/2",
          "0:Cb6/4 4:Ab5/2 6:Eb5/2 8:Cb6/8",                                          # La♭ menor (Do♭)
          "0:F5/2 2:Ab5/2 4:C6/4 8:D6/2 10:C6/2 12:Bb5/4",
          "0:Bb4/4 4:Eb5/2 6:G5/2 8:Bb5/8"],                                           # LA LLAMADA (Si♭-Mi♭-Sol-Si♭)
}


def sections_bonus(v):
    M_ = MB_MEL
    A1, A2 = M_['A'] + [M_['E1']], M_['A'] + [M_['E2']]
    return [('intro', MB_IN, [''] * 4, 16, ''),
            ('A', MB_A, A1, 16, ''), ('A', MB_A, A2, 16, ''), ('B', MB_B, M_['B'], 16, ''),
            ('solo', 'Eb ' * 8, [''] * 8, 16, ''), ('A', MB_A, A2, 16, 'dbl')]


TRACKS = {
    'montana_1': dict(secs=sections_m1, bpm=144, scale=SCALE_D, tonic=(2, MAJ), lufs=-11.0, variants=('A', 'B'),
                      title='La escalada', vname={'A': 'carillon', 'B': 'glaciar'}),
    'montana_2': dict(secs=sections_m2, bpm=128, scale=SCALE_Bm, tonic=(11, MIN), lufs=-11.5, ceiling=0.72, variants=('A', 'B'),
                      title='Viento negro', vname={'A': 'flauta', 'B': 'coro'}),
    'montana_bonus': dict(secs=sections_bonus, bpm=160, scale=SCALE_Eb, tonic=(3, MAJ), lufs=-11.0, variants=('A', 'B'),
                          title='Guerra de nieve', vname={'A': 'carambanos', 'B': 'polca'}),
}
J.TRACKS.update(TRACKS)                                             # (J.Song lee la forma de aquí)


# ══ PIEZAS COMUNES ═══════════════════════════════════════════════════════════════════════════════════════════════
def mel_bar(sg, b):
    return [m for m in sg.mel if m[0] == b]


def d16(sg, b, st, d):
    return sg.q(b, st + d) - sg.q(b, st)


def free_from(sg, b):
    """la semicorchea desde la que la melodía no ATACA en el compás b (puede seguir tenida: el acento suena
    con ella, sin choques — como el tucán de la jungla)"""
    return max([st + 1 for bb, st, n, d in sg.mel if bb == b] or [0])


def yodel(sg, R, b, prog, vel, lo=67, key='accent'):
    """EL YODEL (acento de las montañas): la 5ª abajo · la 3ª una sexta arriba · la 5ª · la raíz arriba (16ª 10-13+),
    solo donde la melodía se posa; sin 2ª menor / 7ª mayor / tritono con lo que suena de la melodía"""
    if free_from(sg, b) > 10:
        return
    r, q = sg.chord(b, 12)
    f5 = lo + (r + q[2] - lo) % 12
    t3 = f5 + (r + q[1] - f5) % 12
    top = f5 + (r - f5) % 12
    for st, n, d, vv in ((10, f5, 1, vel - 12), (11, t3, 1, vel - 6), (12, f5, 1, vel - 14), (13, top, 3, vel)):
        if not R.rub(b, st, n, d): R.gm(key, prog, b, st, n, d, vv, gate=0.9)


def howl(sg, R, b, vs=1.0):
    """EL AULLIDO (acento de montana_2): voz hueca del N163 que sube deslizándose hasta la 5ª del acorde"""
    if free_from(sg, b) > 9:
        return
    r, q = sg.chord(b, 12)
    n = 74 + (r + q[2] - 74) % 12
    if not R.rub(b, 10, n, 6):
        play(R.Cn['howl'], sg.t(b, 10), sg.t(b, 16) - 0.02, n, I_HOWL, q=q_n163, vs=vs, release=14)
        R.notes.setdefault('howl', []).append((sg.q(b, 10), sg.q(b, 16), n))


def counter_gm(sg, R, bars, prog, vel, lo=55, hi=67, key='cm'):
    """contracanto (como J.counter, con un instrumento GM): una nota del acorde por medio compás, la más cercana a la
    anterior, por debajo de la melodía y sin 2ª menor / 7ª mayor / tritono con ella"""
    prev = None
    for b in bars:
        for half in (0, 1):
            st, d = half * 8, 8
            r, q = sg.chords[b - 1][half]
            cands = sorted((p for p in range(lo, hi + 1) if (p - r) % 12 in q), key=lambda p: (abs(p - (prev or lo + 6)), p))
            cands = [p for p in cands if not R.rub(b, st, p, d)] or cands
            prev = cands[0]
            R.gm(key, prog, b, st, prev, d, vel, gate=0.97)


# (2026-10-29, el usuario: "deja montaña 1 como estaba antes" — montana_1 conserva sus cascabeles de 0.5.103, a
#  contratiempo; las demás pistas, a tiempo con jv())
M1_OLD_JINGLES = True


def jv(st, beat=68, eighth=54, sixteenth=38):
    """velocidad de los cascabeles A TIEMPO (2026-10-29, el usuario: la "nevada" sonaba a destiempo — iba solo entre
    los tiempos —): el tiempo, fuerte; la corchea, media; la semicorchea, floja"""
    return beat if st % 4 == 0 else (eighth if st % 2 == 0 else sixteenth)


def bass_note(sg, b, st, deg, lo=38):
    r, q = sg.chord(b, st)
    base = lo + (r - lo) % 12
    return base + {0: 0, 5: 7, 8: 12, 3: q[1]}[deg]


def approach(sg, R, b, lo=38):
    """la nota de paso del bajo (16ª 14) hacia la raíz del compás siguiente"""
    nxt = sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0]
    n2 = lo + (nxt[0] - lo) % 12
    if nxt[0] == sg.chord(b, 14)[0]:
        return bass_note(sg, b, 14, 5, lo)
    ap = [p for p in (n2 - 2, n2 - 1, n2 + 2, n2 + 1) if p % 12 in sg.scale | sg.tones(b, 14) and p >= lo - 2 and not R.rub(b, 14, p, 2)]
    return ap[0] if ap else n2


def pad_chip(sg, R, b):
    for half in (0, 1):
        r, q = sg.chords[b - 1][half]
        base = 60 + (r - 60) % 12 - 12
        pn = [base + iv for iv in q[1:] + q[:1] if not R.rub(b, half * 8, base + iv, 8)][:2]
        for j, nn in enumerate(pn):
            R.chip(('pad1', 'pad2')[j], b, half * 8, nn, 8, I_PAD, q=q_n163, gate=0.97, release=6)


def pad_gm(sg, R, b, prog, vel, key='glass', lo=57, whole=False):
    """colchón GM: 3ª y 5ª (y la raíz arriba) del acorde de cada medio compás, sin choques con la melodía"""
    halves = ((0, 16),) if whole and sg.chords[b - 1][0] == sg.chords[b - 1][1] else ((0, 8), (8, 8))
    for st, d in halves:
        r, q = sg.chord(b, st)
        for iv in (q[1], q[2], 12):
            nn = lo + (r + iv - lo) % 12
            if not R.rub(b, st, nn, d): R.gm(key, prog, b, st, nn, d, vel, gate=0.98)


def timp_roll(sg, R, b, st0=8, vel0=60, root_lo=40, key='timp'):
    """redoble de timbal hacia el compás siguiente (la raíz del que viene)"""
    nxt = sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0]
    n = root_lo + (nxt[0] - root_lo) % 12
    for st in range(st0, 16):
        R.gm(key, TIMPANI, b, st, n, 1, min(120, vel0 + 4 * (st - st0)), gate=0.9)


def rev_cym(sg, R, b, vel=80):
    """platillo al revés que llega a su punta en el tiempo 1 del compás b (su muestra crece durante 1,35 s)"""
    t = sg.t(b, 0)
    R.gmt('revcym', REV_CYM, t - 1.35, t + 0.1, 60, vel)


# ══ ARREGLO: MONTANA_1 ═══════════════════════════════════════════════════════════════════════════════════════════
def arrange_m1(sg, R, v):
    thirds_bars = []
    for b in range(1, sg.NB + 1):
        tag, var = sg.tag[b - 1], sg.var[b - 1]
        for bb, st, n, d in mel_bar(sg, b):
            L16 = d16(sg, b, st, d)
            if v == 'A':                                                     # vibráfono + celesta una octava arriba
                R.gm('lead', VIBES, b, st, n, d, 100 if tag == 'C' else 94)
                R.gm('lead2', CELESTA, b, st, n + 12, d, 80)
                if 'dbl' in var: R.gm('dbl', GLOCK, b, st, n + 12, min(d, 2), 62)
            else:                                                            # "Crystal" + el coro en las notas largas
                R.gm('lead', CRYSTAL, b, st, n, d, 102 if tag == 'C' else 96)
                R.gm('lead2', GLOCK, b, st, n + 12, min(d, 2), 58)
                if L16 >= 6 or (tag == 'C' and L16 >= 4) or 'dbl' in var:
                    R.gm('choir', CHOIR, b, st, n, d, 84 if tag == 'C' else 74, gate=0.98)
        if 'thirds' in var: thirds_bars.append(b)
    if thirds_bars: J.thirds(sg, R, set(thirds_bars), CELESTA, 70)
    cm = [b for b in range(1, sg.NB + 1) if 'cm' in sg.var[b - 1]]
    if cm: counter_gm(sg, R, cm, HALO, 70)
    for b in range(1, sg.NB + 1):
        tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        last = k == L
        thin = 'thin' in var and k <= L - 2
        nxt_tag = sg.tag[b] if b < sg.NB else sg.tag[sg.INTRO]
        # ── EL BAJO (triángulo) ──
        if tag == 'intro':
            if k >= 3: R.chip('bass', b, 0, bass_note(sg, b, 0, 0), 14, I_TRI, q=q_tri, gate=0.95, release=1)
        elif thin or tag == 'B':                                             # blancas: raíz y 5ª
            R.chip('bass', b, 0, bass_note(sg, b, 0, 0), 8, I_TRI, q=q_tri, gate=0.92, release=1)
            R.chip('bass', b, 8, bass_note(sg, b, 8, 5 if tag == 'B' else 0), 8, I_TRI, q=q_tri, gate=0.92, release=1)
        elif tag == 'V':                                                     # la avalancha: corcheas que empujan
            for st in range(0, 16, 2):
                R.chip('bass', b, st, bass_note(sg, b, st, 8 if st % 4 == 2 else 0), 2, I_TRI, q=q_tri, gate=0.8, release=1)
        else:                                                                # la zancada: 3+3+2 · 3+3+2
            for st, deg, d in ((0, 0, 3), (3, 0, 3), (6, 5, 2), (8, 0, 3), (11, 8, 3)):
                R.chip('bass', b, st, bass_note(sg, b, st, deg), d, I_TRI, q=q_tri, gate=0.85, release=1)
            R.chip('bass', b, 14, approach(sg, R, b), 2, I_TRI, q=q_tri, gate=0.85, release=1)
        # ── ARPEGIOS ──
        if v == 'A':                                                         # ARPA: corcheas que suben (16ª en C)
            if tag in ('A', 'B', 'C') or (tag == 'intro'):
                step = 1 if tag == 'C' else 2
                for st in range(0, 16, step):
                    c = sg.chord(b, st)
                    i = (st // step) % (8 // step)
                    nn = place(None, c, 55)[min(i, 6)] if step == 2 else place(None, c, 55)[(0, 1, 2, 3, 4, 3, 2, 1)[i]]
                    vel = 76 if st % 8 == 0 else 60
                    if thin and st % 4: continue
                    if not R.rub(b, st, nn, step): R.gm('harp', HARP, b, st, nn, step, vel - (8 if thin else 0))
        else:                                                                # ICE RAIN en 3+3+2, y el arpa en C
            if tag in ('A', 'B', 'C', 'V') or (tag == 'intro' and k >= 2):
                for st, deg in ((0, 0), (3, 2), (6, 4), (8, 1), (11, 3), (14, 5)):
                    c = sg.chord(b, st)
                    nn = place(None, c, 62)[deg]
                    if not R.rub(b, st, nn, 2): R.gm('ice', ICE_RAIN, b, st, nn, 2, 74 if st in (0, 8) else 62)
            if tag == 'C':
                for st in range(0, 16, 2):
                    nn = place(None, sg.chord(b, st), 55)[(st // 2) % 4]
                    if not R.rub(b, st, nn, 2): R.gm('harp', HARP, b, st, nn, 2, 64)
        # ── COLCHÓN ──
        if v == 'A':
            if tag in ('B', 'C') or 'cm' in var: pad_chip(sg, R, b)
        else:
            if tag in ('A', 'B', 'V') and not (tag == 'A' and sg.sidx[b - 1] == 1): pad_gm(sg, R, b, BOWED_GLASS, 70)
            if tag == 'C': pad_gm(sg, R, b, HALO, 62, key='halo')
            if tag == 'V': R.gm('trem', TREM, b, 0, bass_note(sg, b, 0, 0, 43), 16, 84, gate=0.98)
        # ── PIZZICATO (A: en B, a contratiempo) ──
        if v == 'A' and tag == 'B':
            for st in (2, 6, 10, 14):
                for nn in place(None, sg.chord(b, st), 60)[1:3]:
                    if not R.rub(b, st, nn, 2): R.gm('pizz', PIZZ, b, st, nn, 2, 70)
        # ── EL ACENTO: el yodel ──
        if tag in ('A', 'B', 'C') and not ('dbl' in var and k in (2, 4)):
            if v == 'A': yodel(sg, R, b, GLOCK, 70)
            else: yodel(sg, R, b, HORN, 70, lo=55)
        if tag == 'intro' and k in (2, 4):
            yodel(sg, R, b, GLOCK if v == 'A' else HORN, 66, lo=67 if v == 'A' else 55)
        # ── TIMBALES ──
        if k == 1 and tag != 'intro' and not thin:
            R.gm('timp', TIMPANI, b, 0, bass_note(sg, b, 0, 0, 40), 4, 104)
        if tag == 'intro' and k in (1, 3): R.gm('timp', TIMPANI, b, 0, bass_note(sg, b, 0, 0, 40), 4, 96)
        if last and nxt_tag in ('C', 'V') or (tag == 'intro' and k == 4): timp_roll(sg, R, b, 8, 64)
        if tag == 'V' and k in (1, 3, 5, 7):                                  # la avalancha retumba
            for st in range(0, 16, 2): R.gm('timp', TIMPANI, b, st, bass_note(sg, b, 0, 0, 40), 1, 70 + 3 * st, gate=0.9)
        # ── EFECTOS (B): platillo al revés y viento ──
        if v == 'B':
            if k == 1 and tag in ('C', 'V'): rev_cym(sg, R, b, 84)
            if tag == 'intro' and k == 1: R.gm('wind', WIND, b, 0, 60, 32, 90, gate=1.0)
            if tag == 'V' and k in (1, 5): R.gm('wind', WIND, b, 0, 60, 32, 100, gate=1.0)
        # ── BATERÍA ──
        kit = K_BRUSH if v == 'A' else K_ORCH
        for st in range(16):
            t = sg.t(b, st)
            if tag == 'intro':
                if M1_OLD_JINGLES:
                    if k >= 2 and st % 4 == 2: R.dr('jingle', b, st, JINGLE, 64)
                elif k >= 2 and st % 2 == 0: R.dr('jingle', b, st, JINGLE, jv(st, 64, 50))
                if k >= 3 and st in (0, 8): R.kick(b, st, 0.8)
                continue
            if thin:
                if st % 4 == (2 if M1_OLD_JINGLES else 0): R.dr('jingle', b, st, JINGLE, 48)
                continue
            big = tag in ('C', 'V')
            if tag == 'B':                                                   # la vista: medio tiempo
                if st == 0: R.kick(b, st, 0.9)
                if st == 8: R.dr('snare', b, st, SN, 92, kit=kit)
                if M1_OLD_JINGLES:
                    if st % 4 == 2: R.dr('jingle', b, st, JINGLE, 62)
                elif st % 2 == 0: R.dr('jingle', b, st, JINGLE, jv(st, 62, 50))
            else:
                if st in (0, 8) or (big and st in (6, 14)) or st == 6: R.kick(b, st, 1.0 if st in (0, 8) else 0.75)
                if st in (4, 12): R.dr('snare', b, st, SN, 100 if big else 90, kit=kit)
                if big and st in (7, 15) and v == 'B': R.dr('snare', b, st, SN, 46, kit=kit)
                if M1_OLD_JINGLES:
                    if st % 2 == 1 and big: R.dr('jingle', b, st, JINGLE, 50)
                    if st % 4 == 2: R.dr('jingle', b, st, JINGLE, 72 if big else 64)
                elif big or st % 2 == 0: R.dr('jingle', b, st, JINGLE, jv(st, 72, 58, 42) if big else jv(st, 64, 52))
                if v == 'B' and st in (0, 8) and big: R.gm('bd', CONCERT_BD, b, st, 36, 2, 92 if st == 0 else 74)
            if st == 0 and k in (1, 5) and tag in ('A', 'C', 'V'): R.NZ['crash'].hit(t, 3, CRASH_N)
            if v == 'A' and big and st % 4 == 0: R.dr('ride', b, st, RIDE_BELL, 56)
            if last and st >= 12 and tag != 'V' and not (nxt_tag in ('C', 'V')):
                R.dr('snare', b, st, SN, 60 + 8 * (st - 12), kit=kit)


# ══ ARREGLO: MONTANA_2 ═══════════════════════════════════════════════════════════════════════════════════════════
STOP_HITS = (0, 3, 6, 12)


def arrange_m2(sg, R, v):
    thirds_bars = []
    for b in range(1, sg.NB + 1):
        tag, var = sg.tag[b - 1], sg.var[b - 1]
        for bb, st, n, d in mel_bar(sg, b):
            L16 = d16(sg, b, st, d)
            if v == 'A':                                                     # flauta + celesta en las largas
                R.gm('lead', FLUTE, b, st, n, d, 98 if tag in ('W', 'B') else 92, gate=0.96)
                if L16 >= 4: R.gm('lead2', CELESTA, b, st, n + 12, min(d, 4), 72)
                if 'dbl' in var: R.gm('dbl', VIBES, b, st, n - 12, d, 70)
            else:                                                            # voces + glockenspiel una octava arriba
                R.gm('lead', OOHS, b, st, n, d, 104 if tag in ('W', 'B') else 98, gate=0.97)
                R.gm('lead2', GLOCK, b, st, n + 12, min(d, 2), 56 if tag != 'E' else 48)
                if 'dbl' in var: R.gm('dbl', CRYSTAL, b, st, n + 12, d, 66)
        if 'thirds' in var: thirds_bars.append(b)
    if thirds_bars: J.thirds(sg, R, set(thirds_bars), VIBES, 68)
    swirl_prog = HARP if v == 'A' else SYNTH_MALLET
    for b in range(1, sg.NB + 1):
        tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        last = k == L
        stop = 'stop' in var and k < L
        thin = 'thin' in var and k <= L - 2
        nxt_tag = sg.tag[b] if b < sg.NB else sg.tag[sg.INTRO]
        # ── EL BAJO (triángulo): corcheas tensas (raíz y octava); blancas en B; golpes en 'stop' ──
        if tag == 'intro':
            if k >= 3:
                for st in range(0, 16, 2):
                    R.chip('bass', b, st, bass_note(sg, b, st, 8 if st in (4, 12) else 0, 35), 2, I_TRI, q=q_tri, gate=0.7, release=1)
        elif tag in ('B', 'E') or thin:
            R.chip('bass', b, 0, bass_note(sg, b, 0, 0, 35), 8, I_TRI, q=q_tri, gate=0.92, release=1)
            R.chip('bass', b, 8, bass_note(sg, b, 8, 5 if tag == 'B' else 0, 35), 8, I_TRI, q=q_tri, gate=0.92, release=1)
        elif stop:
            for st in STOP_HITS: R.chip('bass', b, st, bass_note(sg, b, st, 0, 35), 2, I_TRI, q=q_tri, gate=0.8, release=1)
        else:
            for st, deg in ((0, 0), (2, 0), (4, 8), (6, 0), (8, 0), (10, 5), (12, 8)):
                R.chip('bass', b, st, bass_note(sg, b, st, deg, 35), 2, I_TRI, q=q_tri, gate=0.75, release=1)
            R.chip('bass', b, 14, approach(sg, R, b, 35), 2, I_TRI, q=q_tri, gate=0.75, release=1)
        # ── EL REMOLINO: 6 notas del acorde en semicorcheas contra el compás de 8 corcheas (se desfasa) ──
        if not stop and not (tag == 'E') and not (tag == 'B' and v == 'B'):
            for st in range(16):
                gq = int(sg.q(b, st))
                i = (gq % 6)
                c = sg.chord(b, st)
                nn = place(None, c, 59)[(0, 1, 2, 3, 2, 1)[i]]
                vel = (78 if i == 0 else 56) + (8 if tag == 'W' else 0) - (14 if tag == 'intro' and k <= 2 else 0)
                if thin: vel -= 16
                if not R.rub(b, st, nn, 1): R.gm('swirl', swirl_prog, b, st, nn, 1, vel)
        # ── COLCHONES ──
        if tag == 'B':
            if v == 'A': pad_gm(sg, R, b, BOWED_GLASS, 76)
            else:
                pad_gm(sg, R, b, CHOIR, 70, key='choir', lo=55)
                pad_gm(sg, R, b, BOWED_GLASS, 62)
        if tag == 'E':
            pad_gm(sg, R, b, CHOIR, 72, key='choir', lo=55, whole=True)
            pad_gm(sg, R, b, BOWED_GLASS, 66, whole=True)
            for bb, st, n, d in mel_bar(sg, b):
                R.gm('box', MUSICBOX, b, st, n + 12, min(d, 4), 64)
        if tag == 'W':
            R.gm('trem', TREM, b, 0, bass_note(sg, b, 0, 0, 40), 16, 90, gate=0.98)
            R.gm('trem', TREM, b, 0, bass_note(sg, b, 0, 5, 40), 16, 80, gate=0.98)
        if tag == 'A' and sg.sidx[b - 1] >= 2 and not stop: pad_chip(sg, R, b)
        # ── EL ACENTO: el aullido ──
        if tag in ('A', 'B') and not stop:
            howl(sg, R, b)
        if tag == 'intro' and k in (2, 4): howl(sg, R, b, 0.9)
        # ── TIMBALES y VIENTO ──
        if k == 1 and tag in ('A', 'B', 'W') and not stop:
            R.gm('timp', TIMPANI, b, 0, bass_note(sg, b, 0, 0, 40), 4, 100)
        if tag == 'intro' and k == 1: R.gm('timp', TIMPANI, b, 0, bass_note(sg, b, 0, 0, 40), 4, 90)
        if last and nxt_tag == 'W' or (tag == 'intro' and k == 4): timp_roll(sg, R, b, 8, 60)
        if tag == 'W' and k in (5, 6, 7):
            for st in range(0, 16, 2): R.gm('timp', TIMPANI, b, st, bass_note(sg, b, 0, 0, 40), 1, 66 + 3 * st, gate=0.9)
        wind_bars = (1,) if tag == 'intro' else ((1, 5) if tag == 'W' else (7,))
        if k in wind_bars and tag != 'E' and (v == 'B' or tag in ('intro', 'W')):
            R.gm('wind', WIND, b, 0, 60, 32 if tag == 'W' else 24, 96 if v == 'B' else 84, gate=1.0)
        if v == 'B' and k == 1 and tag in ('W', 'B') and sg.sidx[b - 1] > 1: rev_cym(sg, R, b, 80)
        # ── BATERÍA: medio tiempo (bombo 1 · 3y, caja en 3), siseo de nieve en semicorcheas ──
        for st in range(16):
            t = sg.t(b, st)
            if tag == 'intro':
                if k >= 2: R.NZ['hat'].hit(t, 0, [3, 1] if st % 2 else [4, 2, 1])
                if k >= 3 and st in (0, 10): R.kick(b, st, 0.8)
                continue
            if tag == 'E' or thin:
                if st % 4 == 0 and tag != 'E': R.NZ['hat'].hit(t, 0, [3, 1])
                if last and st >= 12: R.snare(b, st, 0.35 + 0.08 * (st - 12))
                continue
            if stop:
                if st in STOP_HITS: R.kick(b, st, 1.0); R.snare(b, st, 0.6) if st == 12 else None
                continue
            if tag == 'W':                                                   # la tormenta: a doble tiempo
                if st in (0, 3, 6, 8, 11, 14): R.kick(b, st, 1.0 if st in (0, 8) else 0.8)
                if st in (4, 12): R.snare(b, st, 0.9)
                R.NZ['hat'].hit(t, 0, [5, 3, 1] if st % 2 == 0 else [3, 2, 1], short=0)
                if v == 'B' and st in (0, 8): R.gm('bd', CONCERT_BD, b, st, 36, 2, 96)
            else:
                if st in (0, 10): R.kick(b, st, 1.0 if st == 0 else 0.85)
                if st == 8: R.snare(b, st, 0.9)
                if st == 15 and k % 2 == 0: R.snare(b, st, 0.35)
                R.NZ['hat'].hit(t, 0, [4, 2, 1] if st % 4 == 0 else ([3, 1] if st % 2 == 0 else [2, 1]))   # (el tiempo, fuerte)
                if tag == 'B' and st % 2 == 0: R.dr('jingle', b, st, JINGLE, jv(st, 56, 44))
            if st == 0 and k in (1, 5): R.NZ['crash'].hit(t, 3, CRASH_N)
        if 'stop' in var and k == L:
            for st in range(8, 16): R.gm('timp', TIMPANI, b, st, bass_note(sg, b, 0, 0, 40), 1, 70 + 5 * (st - 8), gate=0.9)


# ══ ARREGLO: MONTANA_BONUS ═══════════════════════════════════════════════════════════════════════════════════════
def solo_hielo(sg, R, b, k, v):
    """SOLO DE PERCUSIÓN de las montañas (8 compases, distinto de los cascabeles y campanas de la nieve):
    1-2 BOLAS DE NIEVE — bombo de concierto en 3+3+2 y el "plof" (ruido corto) contestado por castañuelas ·
    3-4 CARÁMBANOS — el glockenspiel cae por el acorde (las campanitas que caen) en grupos de 3 contra la escobilla en
    negras · 5-6 EL HIELO SE RAJA — bloques y claves en semicorcheas, triángulo en corcheas · 7 el ritmo del YODEL
    golpeado por los timbales con el glockenspiel · 8 redoble de timbal que crece y el árbol de campanas"""
    tones = place(None, sg.tonic, 63)
    for st in range(16):
        t = sg.t(b, st)
        if k in (1, 2):
            if st in (0, 3, 6, 8, 11, 14): R.gm('bd', CONCERT_BD, b, st, 36, 2, 112 if st in (0, 8) else 92)
            if st in (0, 3, 6, 8, 11, 14): R.NZ['crash'].hit(t, 6, [9, 5, 2, 1])
            if st in (1, 2, 9, 10, 15): R.dr('wood', b, st, CASTANETS, 96)
            if k == 2 and st >= 12: R.dr('brush', b, st, SN, 70 + 8 * (st - 12), kit=K_BRUSH)
        elif k in (3, 4):
            seq = (5, 4, 3, 2, 1, 0) if k == 3 else (4, 3, 2, 3, 2, 1)
            if st % 3 == 0 and st < 15: R.gm('glock', GLOCK, b, st, tones[seq[(st // 3) % 6]] + 12, 2, 86)
            if st % 4 == 0: R.dr('brush', b, st, SN, 80, kit=K_BRUSH)
            if st in (0, 8): R.kick(b, st, 0.7)
            R.dr('jingle', b, st, JINGLE, jv(st, 60, 50, 36))
        elif k in (5, 6):
            R.dr('wood', b, st, (WOOD_H, WOOD_L, CLAVES, WOOD_L)[st % 4], 88 if st % 4 == 0 else 66)
            if st % 2 == 0: R.dr('tri', b, st, TRI_M if st % 4 else TRI_O, 70)
            if st in (0, 6, 8, 14): R.gm('bd', CONCERT_BD, b, st, 36, 2, 100)
            if k == 6 and st in (4, 12): R.dr('snare', b, st, SN, 96, kit=K_ORCH)
        elif k == 7:                                                         # el yodel, golpeado
            for s0, deg in ((0, 2), (2, 1), (4, 2), (6, 3), (8, 2), (10, 1), (12, 2), (13, 3)):
                if st == s0:
                    R.gm('timp', TIMPANI, b, st, (43, 46, 43, 51)[(2, 1, 2, 3).index(deg)] if deg != 3 else 39, 2, 108)
                    R.gm('glock', GLOCK, b, st, tones[deg + 3] + 12 if deg != 3 else tones[6] + 12, 2, 92)
            R.dr('jingle', b, st, JINGLE, jv(st, 64, 52, 40))
        else:
            R.gm('timp', TIMPANI, b, st, 39, 1, 60 + 4 * st, gate=0.9)
            if st == 0: R.dr('tree', b, st, BELL_TREE, 100, d=8)
            if st >= 12: R.dr('snare', b, st, SN, 70 + 9 * (st - 12), kit=K_ORCH)
        if st == 0 and k in (1, 5, 7): R.NZ['crash'].hit(t, 3, CRASH_N)


def arrange_bonus(sg, R, v):
    for b in range(1, sg.NB + 1):
        tag, var = sg.tag[b - 1], sg.var[b - 1]
        for bb, st, n, d in mel_bar(sg, b):
            if v == 'A':                                                     # glockenspiel + pulso
                R.gm('lead', GLOCK, b, st, n, d, 98)
                R.chip('lead', b, st, n, d, I_PULSE, release=3)
                if 'dbl' in var and n + 12 <= 96: R.chip('dbl', b, st, n + 12, d, I_DBL, release=2)
            else:                                                            # silbido + celesta una octava arriba
                R.gm('lead', WHISTLE, b, st, n, d, 98, gate=0.9)
                R.gm('lead2', CELESTA, b, st, n + 12, min(d, 3), 78)
                if 'dbl' in var: R.gm('dbl', GLOCK, b, st, n + 12, min(d, 2), 64)
    for b in range(1, sg.NB + 1):
        tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        last = k == L
        nxt_tag = sg.tag[b] if b < sg.NB else sg.tag[sg.INTRO]
        if tag == 'solo':
            solo_hielo(sg, R, b, k, v)
            if k in (1, 5): R.chip('bass', b, 0, 39, 16, I_TRI, q=q_tri, gate=0.5, release=1)
            continue
        # ── EL BAJO ──
        if not (tag == 'intro' and k < 3):
            if v == 'A':                                                     # corcheas con octavas
                for st in range(0, 16, 2):
                    n = bass_note(sg, b, st, 8 if st % 4 == 2 else 0, 39)
                    if st == 14: n = approach(sg, R, b, 39)
                    R.chip('bass', b, st, n, 2, I_TRI, q=q_tri, gate=0.8, release=1)
            else:                                                            # UM-PA: raíz y 5ª en negras
                for st in (0, 8):
                    R.chip('bass', b, st, bass_note(sg, b, st, 0 if st == 0 else 5, 39), 3, I_TRI, q=q_tri, gate=0.8, release=1)
                if sg.chord(b, 14)[0] != (sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0])[0]:
                    R.chip('bass', b, 14, approach(sg, R, b, 39), 2, I_TRI, q=q_tri, gate=0.8, release=1)
        # ── ACOMPAÑAMIENTO ──
        if tag in ('A', 'B') or (tag == 'intro' and k >= 2):
            hits = (2, 6, 10, 14) if v == 'A' else (4, 12)
            for st in hits:
                for nn in place(None, sg.chord(b, st), 60)[1:3 if v == 'A' else 4]:
                    if not R.rub(b, st, nn, 2): R.gm('pizz', PIZZ, b, st, nn, 2, 74 if v == 'A' else 80)
            if v == 'B' and tag == 'B':
                for st in range(0, 16, 2):
                    nn = place(None, sg.chord(b, st), 72)[(0, 1, 2, 3, 2, 1, 2, 3)[st // 2]]
                    if not R.rub(b, st, nn, 1): R.gm('ice', ICE_RAIN, b, st, nn, 1, 58)
        if tag == 'B':
            if v == 'A': pad_chip(sg, R, b)
            else: pad_gm(sg, R, b, HALO, 58, key='halo')
        # ── EL YODEL ──
        if tag in ('A', 'B') or (tag == 'intro' and k == 4):
            if v == 'A': yodel(sg, R, b, GLOCK, 66, lo=67)
            else: yodel(sg, R, b, HORN, 70, lo=55)
        # ── BATERÍA DE COMPETICIÓN ──
        for st in range(16):
            t = sg.t(b, st)
            if tag == 'intro':
                if st % 4 == 0: R.gm('timp', TIMPANI, b, st, 39 if st % 8 == 0 else 46, 2, 70 + 8 * k)
                if k >= 2: R.dr('jingle', b, st, JINGLE, jv(st, 60, 50, 36))
                if k >= 3 and st % 4 == 0: R.kick(b, st, 0.9)
                if k == 4 and st >= 12: R.dr('snare', b, st, SN, 80 + 8 * (st - 12), kit=K_ORCH)
                continue
            if st % 4 == 0: R.kick(b, st, 1.0 if st % 8 == 0 else 0.9)
            if st in (4, 12): R.snare(b, st, 0.9) if v == 'A' else R.dr('snare', b, st, SN, 100, kit=K_ORCH)
            R.dr('jingle', b, st, JINGLE, jv(st, 66, 54, 40))
            if v == 'B' and st in (0, 8): R.gm('bd', CONCERT_BD, b, st, 36, 2, 84)
            if st == 0 and k in (1, 5): R.NZ['crash'].hit(t, 3, CRASH_N)
            if last and st >= 12 and nxt_tag in ('solo', 'A') and b != sg.NB:
                R.gm('timp', TIMPANI, b, st, 39 + 2 * (st - 12), 1, 90 + 6 * (st - 12), gate=0.9)
            if b == sg.NB and st >= 12: R.dr('snare', b, st, SN, 64 + 8 * (st - 12), kit=K_ORCH)


# ══ MEZCLA ═══════════════════════════════════════════════════════════════════════════════════════════════════════
def frost(x, rt=1.6, seed=7, pre=0.018, lp=6500.0, hp=350.0, length=2.4):
    """'escarcha': reverb con una respuesta sintética (ruido que decae, más oscuro al final) → (izq., der.).
    La casa no usa reverb de estudio: solo la llevan las variantes B, como novedad para que el usuario elija."""
    from scipy.signal import butter, sosfilt, fftconvolve
    N = int(length * SR)
    t = np.arange(N) / SR
    out = []
    for s in (seed, seed + 1):
        rng = np.random.default_rng(s)
        nz = rng.standard_normal(N) * np.exp(-6.9 * t / rt)
        dark = sosfilt(butter(1, 2200, btype='low', fs=SR, output='sos'), nz)
        ir = nz * np.exp(-t / (rt * 0.6)) + dark * (1 - np.exp(-t / (rt * 0.6)))                  # se oscurece
        ir = sosfilt(butter(2, [hp, lp], btype='band', fs=SR, output='sos'), ir)
        ir = np.concatenate([np.zeros(int(pre * SR)), ir])
        ir /= np.sqrt(np.sum(ir ** 2))
        out.append(fftconvolve(x, ir)[:len(x)])
    return out


LV = {
    'montana_1': {'lead': 0, 'lead2': -5, 'choir': -6, 'dbl': -9, 'thirds': -6, 'cm': -6, 'harp': -4, 'ice': -3,
                  'glass': -7, 'halo': -8, 'trem': -5, 'pizz': -4, 'pad': -7, 'accent': -5, 'bass': -2, 'timp': 0,
                  'kick': 1, 'snare': 1, 'jingle': -6, 'ride': -8, 'bd': -1, 'hat': -9, 'crash': -6, 'revcym': -7,
                  'wind': -10},
    'montana_2': {'lead': 0, 'lead2': -7, 'dbl': -9, 'thirds': -6, 'swirl': -3, 'glass': -5, 'choir': -5, 'box': -8,
                  'trem': -3, 'pad': -8, 'howl': -6, 'bass': -5, 'timp': 0, 'kick': 1, 'snare': 2, 'hat': -6,
                  'jingle': -9, 'crash': -7, 'bd': -2, 'revcym': -8, 'wind': -9},
    'montana_bonus': {'lead': 0, 'lead2': -5, 'dbl': -9, 'pizz': -4, 'ice': -8, 'pad': -9, 'halo': -10, 'accent': -6,
                      'bass': -3, 'kick': -2, 'snare': 1, 'jingle': -6, 'crash': -6, 'timp': -1, 'bd': -5, 'wood': -3,
                      'tri': -8, 'glock': -2, 'tree': -6, 'brush': -3},
}
BACKING = 2.5                # dB: todo lo que no es la melodía, más arriba (para el juego, como worlds_nes)
LEAD_KEYS = ('lead', 'lead2', 'thirds')
DRUM_KEYS = ('kick', 'snare', 'brush', 'hat', 'crash', 'jingle', 'ride', 'bd', 'timp', 'wood', 'tri', 'tree', 'revcym', 'glock')
ACC_KEYS = ('harp', 'ice', 'glass', 'halo', 'trem', 'pizz', 'pad', 'swirl', 'cm', 'box', 'choir', 'dbl')
REVERB_SEND = {'lead': 0.22, 'lead2': 0.35, 'choir': 0.4, 'glass': 0.45, 'halo': 0.45, 'ice': 0.35, 'harp': 0.25,
               'swirl': 0.3, 'accent': 0.35, 'thirds': 0.3, 'box': 0.4, 'dbl': 0.3, 'timp': 0.15, 'howl': 0.3,
               'trem': 0.2, 'pizz': 0.2, 'glock': 0.3}


def render_stems(R, n, L):
    def cut(x):
        x = x[:L] - np.mean(x[:n])
        return np.concatenate([x, np.zeros(L - len(x))]) if len(x) < L else x
    base = F.tnd_dac(np.full(R.NS, 64 / 22638.0))
    S = {k: GM.cached(R.G[k], L) for k in R.G}
    S.update({('d_' + k if k in S else k): GM.cached(R.D[k], L) for k in R.D})
    for k in list(S):
        if k.startswith('d_'): S[k[2:]] = S[k[2:]] + S.pop(k)
    S = {k: np.concatenate([x[GM_LAT:], np.zeros(GM_LAT)]) for k, x in S.items()}      # (las capas GM, a tiempo con el chip)
    chip = {'pad': cut(F.render_wave(R.Cn['pad1'], WAVES) * 0.0075) + cut(F.render_wave(R.Cn['pad2'], WAVES) * 0.0075),
            'howl': cut(F.render_wave(R.Cn['howl'], WAVES) * 0.0075),
            'cm_chip': cut(F.render_wave(R.Cn['cm'], WAVES) * 0.0075),
            'bass': cut(F.tnd_dac(F.render_tri(R.Cn['bass']) / 8227.0)),
            'kick': cut(F.tnd_dac((R.dk + 64) / 22638.0) - base),
            'snare_chip': cut(F.tnd_dac((R.sn + 64) / 22638.0) - base) + cut(F.tnd_dac(R.NZ['snare'].render() / 22638.0 * 12)),
            'hat': cut(F.tnd_dac(R.NZ['hat'].render() / 22638.0 * 12)),
            'crash': cut(F.tnd_dac(R.NZ['crash'].render() / 22638.0 * 12)),
            'lead_pulse': cut(F.pulse_dac(F.render_pulse(R.Cn['lead']))),
            'dbl_chip': cut(F.pulse_dac(F.render_pulse(R.Cn['dbl'])))}
    for k, x in chip.items():
        if np.abs(x).max() <= 0: continue
        dst = {'snare_chip': 'snare', 'lead_pulse': 'lead', 'dbl_chip': 'dbl', 'cm_chip': 'cm'}.get(k, k)
        if dst in S and k != dst:
            w = {'lead_pulse': 0.45, 'snare_chip': 1.0, 'dbl_chip': 1.0, 'cm_chip': 1.0}[k]
            S[dst] = S[dst] + w * x * (np.sqrt(np.mean(S[dst] ** 2)) / (np.sqrt(np.mean(x ** 2)) + 1e-12) if k == 'lead_pulse' else 1.0)
        else:
            S[dst] = x
    return S


def build(track, v):
    sg = J.Song(track, v)
    R = Rig(sg)
    {'montana_1': arrange_m1, 'montana_2': arrange_m2, 'montana_bonus': arrange_bonus}[track](sg, R, v)
    n = int(sg.NB * sg.BAR * SR)
    at = int(sg.INTRO * sg.BAR * SR)
    L = n + 5 * SR
    S = render_stems(R, n, L)
    from scipy.signal import butter, sosfilt
    hp = butter(2, 30, btype='high', fs=SR, output='sos')
    S = {k: sosfilt(hp, x) for k, x in S.items() if np.abs(x).max() > 0}
    if v == 'A' and track == 'montana_1':                                # (eco corto de la casa en la voz)
        S['lead2'] = GN.delay(S['lead2'], 3 * 60.0 / sg.bpm / 4, 0.25, 2, 5000)[:L]
    if v == 'A' and track == 'montana_2':
        S['lead'] = GN.delay(S['lead'], 3 * 60.0 / sg.bpm / 4, 0.2, 2, 3500)[:L]
    if 'howl' in S and (track, v) != ('montana_2', 'B'):                 # (el eco del aullido: 3 repeticiones cada 0,33 s)
        # (0.5.100, el usuario eligió montana_2 B "pero sin el efecto de notas con retraso": la B ya no lleva el eco del
        #  aullido — lo único con retraso que tenía; la racha que llega una semicorchea tarde es el ritmo y se queda)
        S['howl'] = GN.delay(S['howl'], 0.33, 0.35, 3, 2500)[:L]
    g = GN.level(S, {k: LV[track].get(k, -10) + (0 if k in ('lead', 'lead2', 'thirds') else BACKING) for k in S}, 'lead')
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('harp', 0.3) - sd('ice', 0.35) + sd('jingle', 0.4) - sd('glass', 0.25) + sd('accent', 0.35) \
        - sd('lead2', 0.2) + sd('swirl', 0.3) - sd('pizz', 0.25) + sd('hat', 0.3) - sd('howl', 0.3) + sd('halo', 0.25) \
        - sd('wood', 0.3) + sd('choir', 0.15) - sd('box', 0.3) + sd('tri', 0.3) - sd('glock', 0.25)
    Lx, Rx = x + side, x - side
    if v == 'B':                                                         # la ESCARCHA (reverb), solo en B
        send = sum(S[k] * g[k] * w for k, w in REVERB_SEND.items() if k in S)
        rl, rr = frost(send, rt=1.8 if track != 'montana_bonus' else 1.2)
        wet = 0.55 if track != 'montana_bonus' else 0.4
        Lx, Rx = Lx + wet * rl, Rx + wet * rr
    y = np.stack([GN.fold(Lx, n, at), GN.fold(Rx, n, at)], 1)              # (la cola, sobre el principio del bucle)
    y = F.master(y, lufs=TRACKS[track]['lufs'], ceiling=TRACKS[track].get('ceiling', 0.8))     # (montana_2: el OGG subía el pico a 0,98)
    S = {k: GN.fold(x_, n, at) for k, x_ in S.items()}
    return sg, R, S, g, y, n, at


# ══ INFORME (números: no se ha escuchado) ════════════════════════════════════════════════════════════════════════
def seam_numbers(y, at, bar_smp, starts=()):
    """costura del bucle (fin → principio) y paso intro → bucle: el salto de muestra frente al mayor salto de los
    otros tiempos 1 de sección dentro del bucle (que llevan el mismo golpe de bombo: < 1 = no se nota más que un
    tiempo 1 cualquiera) y la sonoridad a ambos lados (dB, 100 ms)"""
    lp = y[at:]
    ref = max([np.abs(y[int(s)] - y[int(s) - 1]).max() for s in starts] or [1e-9])
    jump = np.abs(lp[0] - lp[-1]).max()
    w = int(0.1 * SR)
    db = lambda z: 10 * np.log10(np.mean(z ** 2) + 1e-12)
    return (len(lp), len(lp) / bar_smp, jump / (ref + 1e-9), db(lp[-w:]) - db(lp[:w]),
            np.abs(y[at]).max() / (ref + 1e-9), db(y[at - w:at]) - db(y[at:at + w]))


def report(track, v, sg, R, S, g, y, n, at):
    lab = f'{track} variante {v} "{TRACKS[track]["vname"][v]}"'
    print(f'── {lab}')
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    bar = sg.BAR * SR
    print(f'  {sg.bpm} BPM, {sg.NB} compases: intro {sg.INTRO} c. = {at} muestras ({at / SR:.2f} s) + bucle {sg.NB - sg.INTRO} c. '
          f'= {n - at} muestras ({(n - at) / SR:.2f} s); {F.loudness(y):.1f} LUFS, pico {np.abs(y).max():.2f}')
    print(f'  energía: melodía {grp(("lead",)):.0f} % (con sus dobles {grp(LEAD_KEYS + ("dbl",)):.0f} %), batería {grp(DRUM_KEYS):.0f} %, '
          f'bajo {grp(("bass",)):.0f} %, acompañamiento {grp(ACC_KEYS):.0f} %, acento {grp(("accent", "howl")):.1f} %')
    print('  ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    lb, lo, out, off = J.check(sg)
    print(f'  melodía: {len(sg.mel)} notas, ámbito {nm(min(m[2] for m in sg.mel))}-{nm(max(m[2] for m in sg.mel))}, '
          f'a contratiempo {100 * off:.0f} %; largas fuera del acorde: {lb or "ninguna"}; sueltas: {lo or "ninguna"}; '
          f'fuera de la escala: {out or "ninguna"}')
    for k in ('bass', 'harp', 'ice', 'swirl', 'pizz', 'cm', 'thirds', 'accent', 'howl', 'glass', 'choir', 'halo', 'pad1', 'pad2', 'trem'):
        if k in R.notes:
            cl = J.clashes(sg, sg.mel, R.notes[k])
            if cl: print(f'  choques melodía / {k} (≥ corchea): {len(cl)} {cl[:6]}')
    acc = R.notes.get('accent', []) + R.notes.get('howl', [])
    bad = [(int(q0 // 16) + 1, nm(nn)) for q0, q1, nn in acc if nn % 12 not in sg.tones(int(q0 // 16) + 1, (q0 % 16))]
    print(f'  acento: {len(acc)} notas; fuera del acorde: {bad or "ninguna"}')
    if 'thirds' in R.notes:
        lb2, lo2, out2, _ = J.check(sg, sorted((int(q0 // 16) + 1, int(q0 % 16), nn, int(round(q1 - q0))) for q0, q1, nn in R.notes['thirds']))
        print(f'  2ª voz (terceras): largas fuera del acorde {lb2 or "ninguna"}, fuera de escala {out2 or "ninguna"}')
    badb = [(b, st, nm(nn)) for (q0, q1, nn) in R.notes.get('bass', []) for b, st in [(int(q0 // 16) + 1, q0 % 16)]
            if q1 - q0 >= 3 and (nn - sg.chord(b, st)[0]) % 12 not in (0, 7, 12)]
    print(f'  bajo: {len(R.notes.get("bass", []))} notas; largas que no son raíz ni 5ª: {badb or "ninguna"}')
    ov, who, mean = J.attack_overlap(sg)
    a0 = sg.starts[1]
    mine = {(b - a0, round(sg.q(b, st) - (b - 1) * 16, 2)) for b, st, n, d in sg.mel if a0 <= b < a0 + 7}
    vs = {k: len(mine & {(b - 1, float(st)) for b, st, n, d in ph if b <= 7}) / max(1, len(mine))
          for k, ph in (('nieve_1', W.S_A), ('nieve_2', W.V_A), ('nieve_bonus', W.BONUS['descenso'][0]))}
    print(f'  frase A: golpes compartidos con otras islas — máx. {100 * ov:.0f} % ({who}), media {100 * mean:.0f} %; '
          f'con la isla helada (ahora la costa): ' + ', '.join(f'{k} {100 * x:.0f} %' for k, x in vs.items()))
    secs = []
    for b0 in sg.starts:
        tsec = (b0 - 1) * sg.BAR
        secs.append(f'{sg.tag[b0 - 1]}{"·" + sg.var[b0 - 1] if sg.var[b0 - 1] else ""} {int(tsec // 60)}:{tsec % 60:04.1f}')
    print('  secciones (desde el principio de la intro): ' + ' | '.join(secs))
    span = lambda b0, L_: (int((b0 - 1) * sg.BAR * SR), int((b0 - 1 + L_) * sg.BAR * SR))
    def db(a, b_):
        z = sum(S[k][a:b_] * g[k] for k in S)
        return 10 * np.log10(np.mean(np.asarray(z) ** 2) + 1e-12)
    ref = db(*span(sg.starts[1], sg.slen[sg.starts[1] - 1]))
    print('  sonoridad por sección vs la 1ª A (dB): ' + ' '.join(f'{sg.tag[b0 - 1]} {db(*span(b0, sg.slen[b0 - 1])) - ref:+.1f}' for b0 in sg.starts))
    ln, bars, jr, dbs, ji, dbi = seam_numbers(y, at, bar, [(b0 - 1) * sg.BAR * SR for b0 in sg.starts[2:]])
    print(f'  BUCLE: {ln} muestras = {bars:.4f} compases; costura (fin → principio): salto {jr:.2f}× el mayor de los '
          f'otros tiempos 1 de sección, {dbs:+.1f} dB; intro (que acaba en silencio) → bucle: {ji:.2f}×, {dbi:+.1f} dB')
    seams = [(b0 - 1, b0) for b0 in sg.starts[2:]] + [(sg.NB, sg.INTRO + 1)]
    def last_note(b):
        ms = [m for m in sg.mel if m[0] <= b]
        return f'{nm(ms[-1][2])}' if ms and ms[-1][0] >= b - 1 else '—'
    def first_note(b):
        ms = [m for m in sg.mel if m[0] >= b]
        return f'{nm(ms[0][2])}@{ms[0][1]}' if ms and ms[0][0] <= b + 1 else '—'
    cn = lambda c: J.NAMES[c[0]] + ('m' if c[1] == MIN else '')
    print('  costuras (compás: acorde, última nota → acorde, primera nota): ' + ' | '.join(
        f'{a}→{c}: {cn(sg.chords[a - 1][1])} {last_note(a)} → {cn(sg.chords[c - 1][0])} {first_note(c)}' for a, c in seams))
    return dict(lb=lb, lo=lo, out=out, off=off, lufs=F.loudness(y), intro=at, loop=n - at, bars=bars, jr=jr, dbs=dbs)


# ══ EL MAPA: "Rumbo a las islas" con el reparto helado y el YODEL en los compases que la melodía sostiene ══════════
def arrange_map(sg, R, v):
    for b, st, n, d in sg.mel:
        if v == 'A':                                                         # celesta una 8ª arriba + vibráfono
            R.gm('lead', CELESTA, b, st, n + 12, d, 96, gate=0.97)
            R.gm('lead2', VIBES, b, st, n, d, 80, gate=0.97)
        else:                                                                # "Crystal" + coro en las largas
            R.gm('lead', CRYSTAL, b, st, n, d, 100 if 9 <= b <= 16 else 94, gate=0.97)
            R.gm('lead2', GLOCK, b, st, n + 12, min(d, 2), 56)
            if d >= 6: R.gm('choir', CHOIR, b, st, n, d, 76, gate=0.98)
    for b in range(1, sg.NB + 1):
        r, q = sg.chord(b, 0)
        B = 9 <= b <= 16
        root = 36 + (r - 36) % 12
        # EL BAJO (triángulo): blancas, raíz y 5ª (la nieve), y la de paso hacia el compás siguiente en B
        R.chip('bass', b, 0, root, 8, I_TRI, q=q_tri, gate=0.92, release=1)
        R.chip('bass', b, 8, root + 7, 6 if B else 8, I_TRI, q=q_tri, gate=0.92, release=1)
        if B:
            nxt = sg.chord(b % sg.NB + 1, 0)[0]
            n2 = 36 + (nxt - 36) % 12
            ap = [p for p in (n2 - 2, n2 - 1, n2 + 2, n2 + 1) if p % 12 in M.SCALE_C and not R.rub(b, 14, p, 2)] if nxt != r else [root + 7]
            R.chip('bass', b, 14, ap[0] if ap else n2, 2, I_TRI, q=q_tri, gate=0.9, release=1)
        # ACOMPAÑAMIENTO
        if v == 'A':                                                         # arpa: corcheas que suben
            for st in range(0, 16, 2):
                nn = place(None, (r, q), 55)[(st // 2) % 4 + (1 if B and st >= 8 else 0)]
                if not R.rub(b, st, nn, 2): R.gm('harp', HARP, b, st, nn, 2, 72 if st % 8 == 0 else 58)
            if B: pad_gm(sg, R, b, BOWED_GLASS, 66)
            else: pad_chip(sg, R, b)
        else:                                                                # Ice Rain en 3+3+2, vidrio, halo en B
            for st, deg in ((0, 0), (3, 2), (6, 4), (8, 1), (11, 3), (14, 5)):
                nn = place(None, (r, q), 62)[deg]
                if not R.rub(b, st, nn, 2): R.gm('ice', ICE_RAIN, b, st, nn, 2, 72 if st in (0, 8) else 60)
            pad_gm(sg, R, b, HALO if B else BOWED_GLASS, 62, key='halo' if B else 'glass')
        # EL LEITMOTIV: el yodel (sobre el Sol7 del compás 12: la 3ª y la raíz, sin la 7ª — choca con el Si de la melodía)
        if b in M.ANSWER_BARS or b == 12:
            prog, lo, vel = (GLOCK, 67, 70) if v == 'A' else (HORN, 55, 72)
            if q == M.DOM:
                f3 = lo + (r + 4 - lo) % 12
                top = f3 + (r - f3) % 12
                for st, nn, d, vv in ((10, f3, 1, vel - 12), (11, top, 1, vel - 6), (12, f3, 1, vel - 14), (13, top, 3, vel)):
                    if not R.rub(b, st, nn, d): R.gm('accent', prog, b, st, nn, d, vv, gate=0.9)
            else:
                yodel(sg, R, b, prog, vel, lo=lo)
        # BATERÍA: bombo 1 (y 3 en B), escobilla / caja en 2 y 4, cascabeles a contratiempo, timbal en las cabezas
        kit = K_BRUSH if v == 'A' else K_ORCH
        for st in range(16):
            if st == 0 or (B and st == 8): R.kick(b, st, 0.7 if st == 0 else 0.55)
            if st in (4, 12): R.dr('snare', b, st, SN, 74 if not B else 84, kit=kit)
            if st % 2 == 0 or B: R.dr('jingle', b, st, JINGLE, jv(st, 66, 52, 38))
            if st == 0 and b in (1, 9, 17):
                R.NZ['crash'].hit(sg.t(b, st), 3, CRASH_N)
                R.gm('timp', TIMPANI, b, st, 40 + (r - 40) % 12, 4, 96)
            if (b in (8, 16) and st >= 12) or (b == 24 and st >= 14):
                R.gm('timp', TIMPANI, b, st, 43, 1, 70 + 6 * (st - 12), gate=0.9)
        if v == 'B' and b in (9, 17): rev_cym(sg, R, b, 74)


def build_map(v):
    """map_nieve nuevo (las MONTAÑAS): 24 compases a 120, exactamente 2 116 800 muestras como los otros siete"""
    sg = M.MapSong()
    R = Rig(sg)
    arrange_map(sg, R, v)
    n = int(M.NB * M.BAR * SR)
    L = n + 4 * SR
    S = render_stems(R, n, L)
    from scipy.signal import butter, sosfilt
    hp = butter(1, 30, btype='high', fs=SR, output='sos')
    S = {k: sosfilt(hp, x) for k, x in S.items() if np.abs(x).max() > 0}
    if v == 'A': S['lead'] = GN.delay(S['lead'], 2 * M.S16, 0.3, 2, 5000)[:L]     # (el eco de map_nieve)
    LVm = {'lead': 0, 'lead2': -5, 'choir': -7, 'bass': -2, 'kick': -4, 'snare': -6, 'jingle': -9, 'crash': -12,
           'timp': -4, 'harp': -5, 'ice': -5, 'glass': -9, 'halo': -10, 'pad': -8, 'accent': -4, 'revcym': -10}
    g = GN.level(S, {k: LVm.get(k, -12) for k in S}, 'lead')
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('harp', 0.3) - sd('ice', 0.35) + sd('jingle', 0.4) - sd('glass', 0.25) + sd('accent', 0.35) \
        - sd('lead2', 0.2) + sd('halo', 0.25) - sd('pad', 0.2)
    Lx, Rx = x + side, x - side
    if v == 'B':
        send = sum(S[k] * g[k] * w for k, w in REVERB_SEND.items() if k in S)
        rl, rr = frost(send, rt=1.8)
        Lx, Rx = Lx + 0.5 * rl, Rx + 0.5 * rr
    y = np.stack([GN.fold(Lx, n), GN.fold(Rx, n)], 1)
    y = F.master(y, lufs=-12.0)
    S = {k: GN.fold(x_, n) for k, x_ in S.items()}
    return y, sg, R, S, g, n


def onset_env(y):
    import librosa
    m = y.mean(1) if y.ndim == 2 else y
    return librosa.onset.onset_strength(y=m.astype(np.float32), sr=SR, hop_length=128)


def map_report(v, y, sg, R, S, g, n):
    print(f'── map (montañas) variante {v} "{MAP_VNAME[v]}"')
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    print(f'  {len(y)} muestras ({len(y) / SR:.3f} s; los otros mapas: 2116800), {F.loudness(y):.1f} LUFS, pico {np.abs(y).max():.2f}')
    print('  energía: ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    acc = R.notes.get('accent', [])
    bad = [(int(q0 // 16) + 1, nm(nn)) for q0, q1, nn in acc if nn % 12 not in sg.tones(int(q0 // 16) + 1, 0)]
    bars = sorted({int(q0 // 16) + 1 for q0, q1, nn in acc})
    print(f'  leitmotiv (yodel): {len(acc)} notas en los compases {bars}; fuera del acorde: {bad or "ninguna"}')
    for k in ('bass', 'harp', 'ice', 'accent', 'glass', 'halo', 'pad1', 'choir'):
        if k in R.notes:
            cl = J.clashes(sg, sg.mel, R.notes[k])
            print(f'  choques melodía / {k} (≥ corchea): {len(cl)} {cl[:6] if cl else ""}')
    # a tiempo con los otros arreglos: retraso de la envolvente de ataques frente a map_nieve / map_jungla instalados
    import soundfile as sf
    oe = onset_env(y)
    for other in ('map_nieve', 'map_jungla', 'map_pradera'):
        p = os.path.join(F.MUSIC_DIR, 'map', other + '.ogg')
        if not os.path.exists(p): continue
        z, _ = sf.read(p)
        oz = onset_env(z)
        m_ = min(len(oe), len(oz))
        a, b_ = oe[:m_] - oe[:m_].mean(), oz[:m_] - oz[:m_].mean()
        lags = range(-20, 21)
        cc = [np.sum(a[max(0, l):m_ + min(0, l)] * b_[max(0, -l):m_ - max(0, l)]) for l in lags]
        best = list(lags)[int(np.argmax(cc))]
        print(f'  ataques frente a {other}: retraso {best * 128 / SR * 1000:+.1f} ms (correlación {max(cc) / (np.linalg.norm(a) * np.linalg.norm(b_) + 1e-9):.2f})')


MAP_VNAME = {'A': 'carillon', 'B': 'glaciar'}


def enc(x, ogg):
    J.enc(x, ogg)


def readme(nums):
    lines = """LAS MONTAÑAS HELADAS — música nueva, previas para elegir (2026-10-29)
====================================================================

NO SE HA ESCUCHADO: todo se ha comprobado solo con números (abajo). Tu oído manda.
Nada está instalado: ni assets/music ni index.json se han tocado.
Generador: tools/music/montana_nes.py (sin parámetros escribe todo esto).

Archivos de cada pista / variante:
  <nombre>_preview.ogg   intro + bucle dos veces (para oír la costura)
  <nombre>_intro.ogg     la intro (suena una vez), como se instalaría
  <nombre>_loop.ogg      el bucle (se repite sin volver a la intro), como se instalaría
  <nombre>.mid           melodía + bajo
Mapa: map_montanas_<A|B>.ogg (el archivo tal cual, 48 s), map_montanas_<A|B>_preview.ogg (dos vueltas) y
map_nieve_a_montanas_<A|B>_compas9.ogg (los compases 1-8 del map_nieve ACTUAL y del 9 en adelante el nuevo: para
comprobar que el cambio de isla en el mapa no pierde el compás).

LOS MOTIVOS DE LA ISLA HELADA QUE SE REUTILIZAN (temas nuevos; los motivos, citados en su acorde)
-----------------------------------------------------------------------------------------------
- El MOTIVO navideño de la caja de música (la nota, su octava arriba y la bajada por grados): su cabeza abre el
  estribillo C de montana_1 (Re5-Re6-Do#6-Si5 sobre Sol, el IV, como en nieve_1).
- La frase de 1:48: "tres corcheas que suben y la nota larga a contratiempo" (2-2-2-6) = la trepada de B en montana_1
  y la respuesta de cada frase de montana_2; su cierre, "tres repetidas con puntillo y un salto" = la RACHA con que
  empieza cada frase de montana_2 (el mismo golpe que el riff de la Bola de Nieve, el jefe de estas montañas).
- Las CAMPANITAS QUE CAEN del mapa (notas del acorde bajando en semicorcheas) = la cascada de la avalancha (V de
  montana_1 B) y los carámbanos del solo del bonus.
- Los CASCABELES y la CAJA DE MÚSICA una octava arriba (ahora celesta / glockenspiel GM sobre la voz).
- LA LLAMADA (5-1-3-5), una vez por pista, sobre su acorde.
- NUEVO, el acento de las montañas: el YODEL (5ª abajo · 3ª una sexta arriba · 5ª · raíz arriba), solo notas del
  acorde, donde la melodía se posa; en montana_2 el AULLIDO del viento (voz hueca de N163 que sube deslizándose).
- El reparto: instrumentos GM "helados" del soundfont (celesta, glockenspiel, vibráfono, caja de música, Crystal,
  Ice Rain, vidrio frotado, Halo, coro, voces, arpa, pizzicato, trémolo de cuerdas, timbales, bombo de concierto,
  escobillas, cascabeles, árbol de campanas, viento, platillo al revés, trompa) con el chip de la casa debajo
  (bajo de triángulo, bombo y caja de DPCM, platos de ruido, colchón y aullido de N163).
- Las variantes B llevan una REVERB ("escarcha"): la casa no la usa nunca; es la novedad "moderna" para que elijas.

QUÉ CAMBIA ENTRE A Y B
----------------------
montana_1 "La escalada" (Re mayor, 144; niveles impares)
  A "carillon"  vibráfono + celesta una 8ª arriba; arpa en corcheas que suben; colchón N163; escobillas, cascabeles;
                yodel de glockenspiel; eco corto (sin reverb). Forma: intro · A · A' · B · C · A (parón) · A + contracanto
                (Halo) · C + glockenspiel.
  B "glaciar"   (más original) Crystal + coro en las notas largas + glockenspiel en los ataques; Ice Rain en 3+3+2;
                vidrio frotado y Halo; caja de orquesta y bombo de concierto; platillo al revés y viento; yodel de
                TROMPA (la trompa alpina); reverb. Forma: ... C · V = LA AVALANCHA (8 compases nuevos en Si menor:
                cascadas que caen, timbales que retumban, trémolo grave) · A + celesta en terceras · C + coro.
montana_2 "Viento negro" (Si menor, 128; niveles pares: torre_viento, la noche, la ventisca)
  A "flauta"    flauta GM (+ celesta en las notas largas), el remolino en el ARPA, vidrio frotado en B. Forma: intro ·
                A · A' · B · W (la tormenta) · A a golpes (stop) · B + vibráfono una 8ª abajo.
  B "coro"      (más original) "Voice Oohs" + glockenspiel una 8ª arriba, el remolino en un mazo sintético, coro en B,
                viento aullando más fuerte, platillo al revés, bombo de concierto en la tormenta; reverb. Forma: ... W ·
                E = el OJO de la tormenta (8 compases nuevos: coro, vidrio y caja de música, sin batería) · A + vibráfono
                en terceras · B + Crystal.
montana_bonus "Guerra de nieve" (Mi♭ mayor, 160; ~1 minuto; zonas bonus de las montañas)
  A "carambanos" glockenspiel + pulso de la casa; pizzicato a contratiempo; bajo en corcheas con octavas.
  B "polca"      (más original) silbido + celesta; bajo y pizzicato en UM-PA (polca alpina); Ice Rain y Halo en B;
                 yodel de TROMPA; caja de orquesta y bombo de concierto; reverb corta.
  El SOLO "hielo" es el mismo en las dos: bolas de nieve (bombo de concierto 3+3+2 + plof + castañuelas) · carámbanos
  (glockenspiel que cae por el acorde contra la escobilla) · el hielo se raja (bloques, claves, triángulo) · el ritmo
  del yodel en timbales y glockenspiel · redoble y árbol de campanas.
Mapa "Rumbo a las islas" (montañas; será map_nieve; el actual pasa a map_costa_helada)
  A "carillon"  celesta una 8ª arriba (como la caja de música de antes) + vibráfono, arpa en corcheas, vidrio/colchón,
                bajo en blancas, escobillas y cascabeles; yodel de glockenspiel en los compases 4, 8, 12, 20, 24.
  B "glaciar"   Crystal + glockenspiel + coro en las largas, Ice Rain en 3+3+2, vidrio y Halo, caja de orquesta,
                platillo al revés hacia B y la vuelta; yodel de trompa; reverb.

LOS NÚMEROS
-----------
"""
    return lines + '\n'.join(nums) + """

LO QUE SOLO SE PUEDE JUZGAR DE OÍDO
-----------------------------------
- Si el reparto GM suena "helado" y moderno o demasiado de banda sonora; si la reverb de B gusta o sobra.
- El nivel del coro y de la trompa del yodel (B); la flauta / voces de montana_2 frente al remolino.
- Si la racha de montana_2 recuerda demasiado al jefe (es su motivo a propósito).
- El paso del mapa de una isla a otra (los ataques de las capas GM llegan unos ms después que los del chip).
"""


ORDER = ['montana_1', 'montana_2', 'montana_bonus', 'mapa']
# LO QUE ELIGIÓ EL USUARIO (2026-10-29): montana_1 B "glaciar", montana_2 B "coro" (sin el eco del aullido), el bonus
# A "carámbanos" y el mapa A "carillón" (→ map_nieve; el arreglo de la nieve de antes es map_costa_helada en
# worldmap_nes.py). INSTALL=1 [MONTANA_1=A|B ...] escribe assets/music/worlds/montanas/<pista>_intro|_loop.ogg,
# map/map_nieve.ogg y tools/music/mid/<pista>.mid (el index.json y los volúmenes, aparte: levels.py).
CHOSEN = {'montana_1': 'B', 'montana_2': 'B', 'montana_bonus': 'A', 'mapa': 'A'}
INSTALL_DIR = os.path.join(F.MUSIC_DIR, 'worlds', 'montanas')

if __name__ == '__main__':
    which = [a for a in sys.argv[1:] if a in ORDER] or ORDER
    os.makedirs(PRUEBAS, exist_ok=True)
    nums = []
    for track in which:
        if track == 'mapa':
            import soundfile as sf
            for v in ('A', 'B'):
                if os.environ.get('INSTALL') and v != os.environ.get('MAPA', CHOSEN['mapa']): continue
                y, sg, R, S, g, n = build_map(v)
                map_report(v, y, sg, R, S, g, n)
                assert len(y) == 2116800, len(y)
                nums.append(f'map_montanas_{v}: {len(y)} muestras (= los otros mapas), {F.loudness(y):.1f} LUFS')
                if os.environ.get('REPORT'): continue
                base = os.path.join(PRUEBAS, f'map_montanas_{v}')
                enc(y, base + '.ogg')
                enc(np.concatenate([y, y]), base + '_preview.ogg')
                if os.environ.get('INSTALL'):
                    GN.export('map_nieve', y)
                    J.write_mid(F.out('map_nieve', 'mid'), sg, R)
                    continue
                old, _ = sf.read(os.path.join(F.MUSIC_DIR, 'map', 'map_costa_helada.ogg'))      # (el map_nieve de antes)
                k9 = int(8 * M.BAR * SR)
                enc(np.concatenate([old[:k9], y[k9:]]), os.path.join(PRUEBAS, f'map_nieve_a_montanas_{v}_compas9.ogg'))
            continue
        for v in TRACKS[track]['variants']:
            if os.environ.get('INSTALL') and v != os.environ.get(track.upper(), CHOSEN[track]): continue
            sg, R, S, g, y, n, at = build(track, v)
            r = report(track, v, sg, R, S, g, y, n, at)
            nums.append(f'{track}_{v}_{TRACKS[track]["vname"][v]}: {sg.bpm} BPM, intro {sg.INTRO} c. ({at / SR:.2f} s) + bucle '
                        f'{sg.NB - sg.INTRO} c. ({(n - at) / SR:.2f} s = {r["bars"]:.4f} compases exactos), {r["lufs"]:.1f} LUFS; '
                        f'melodía a contratiempo {100 * r["off"]:.0f} %, largas fuera del acorde {len(r["lb"])}, '
                        f'sueltas {len(r["lo"])}; costura del bucle: salto {r["jr"]:.2f}× el de un tiempo 1 de sección, {r["dbs"]:+.1f} dB')
            if os.environ.get('REPORT'): continue
            if os.environ.get('INSTALL'):
                os.makedirs(INSTALL_DIR, exist_ok=True)
                J.export(y, at, os.path.join(INSTALL_DIR, track))
                J.write_mid(F.out(track, 'mid'), sg, R)
                print(f'  instalada: {INSTALL_DIR}/{track}_intro|_loop.ogg')
                continue
            base = os.path.join(PRUEBAS, f'{track}_{v}_{TRACKS[track]["vname"][v]}')
            J.export(y, at, base)
            enc(np.concatenate([y, y[at:]]), base + '_preview.ogg')
            J.write_mid(base + '.mid', sg, R)
    if not os.environ.get('REPORT') and not os.environ.get('INSTALL') and set(which) == set(ORDER):
        with open(os.path.join(PRUEBAS, 'LEEME.txt'), 'w') as f:
            f.write(readme(nums))
        print(f'  previas en {PRUEBAS}')
