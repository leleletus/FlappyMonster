#!/usr/bin/env python3
# tools/music/jungla_nes.py — la música de NIVEL de la JUNGLA (la isla aún no está en el juego; los temas, sí).
# PREVIAS para que el usuario elija; no toca assets/ salvo con INSTALL=1 (y nunca el index.json).
#
# La identidad de la isla, sacada del tema del jefe (templo.py, el Escarabajo Rinoceronte Gigante):
#   · el COLOR: Fa menor natural con sus acordes prestados de la referencia (Re♭ y Mi♭ = VI y VII; Si♭m, Dom);
#   · EL RIFF (corregido por el usuario): Do Do Do# Re# Sol# Sol# en semicorcheas 0·2·5·8·11·14 (2+3+3+3+3+2) —
#     en los temas de nivel se cita su RITMO y el perfil de su cabeza (nota repetida, sube por grado dos veces, cae
#     por debajo de donde empezó, repite) donde su armonía encaja: tal cual sobre La♭ (Do y Mi♭ son del acorde; el Re♭
#     es de paso), y en secuencia sobre otros acordes mayores; y luego sigue con material propio;
#   · los INSTRUMENTOS de jungla del soundfont GM (gm.py + GeneralUser GS): marimba, kalimba, flauta de pan, ocarina,
#     botella soplada, taiko, congas, bongós, agogó, cabasa, maracas, shaker, bloques de madera, surdos, timbales,
#     silbato — MEZCLADOS con el reparto de Famicom de la casa (bajo de triángulo, bombo y caja de DPCM + ruido,
#     platos de ruido, colchón y voz de N163, pulso con barrido de ciclo) para que siga sonando a Flappy Monster.
#
#   jungla_1      "Corazón de la selva" — el TEMA (lo más cantable): Fa menor, 138 BPM, 4/4. Bajo que rebota
#                 (anticipa la raíz), marimba en 3+3+3+3+2+2, congas en tumbao, maracas; acento: el TUCÁN (ocarina,
#                 5ª-5ª-octava). Forma: intro 4 · A · A' · B (cierra con la llamada) · C (estribillo: el RIFF) ·
#                 K (corro de tambores) · A'' · C'.  Dos variantes:
#                   A "liana"        (de la casa) voz de N163 "flauta de madera"; contracanto y octava de pulso
#                   B "dos flautas"  (más original) flauta de pan GM; melodía en hemiolia 3+3+3+3+2+2; la ocarina
#                                    la acompaña en terceras (dos melodías en paralelo, algo que la casa no hace)
#   jungla_2      "Río de tambores" — su segunda cara: Si♭ DÓRICO, 12/8 (negra con puntillo = 120): otro tono, otro
#                 ritmo (compás compuesto, campana africana 2-2-1-2-2-2-1) y otro timbre. Acento: la BOTELLA
#                 soplada (un ave nocturna: 5ª → 3ª). Su forma crece a su manera: R = la "sombra del escarabajo",
#                 8 compases en 4/4 (el pulso no cambia, la subdivisión sí: de tresillos a semicorcheas) con la
#                 batería de la referencia y el RIFF. Dos variantes:
#                   A "pulso"        (de la casa) pulso del 2A03 con barrido de ciclo y vibrato
#                   B "balafón"      (más original) la marimba GM canta, con trémolo en las notas largas y la
#                                    kalimba una octava arriba
#   jungla_bonus  "Lianas" — su PROPIO tema corto: La♭ MIXOLIDIO, 160 BPM, batería de competición (negras de
#                 bombo, surdos, silbato de samba) y un SOLO de 8 compases "selva": taiko y congas en 3 contra 4,
#                 tambores de tronco afinados, y el RITMO DEL RIFF golpeado por toda la percusión al unísono.
#
#   ~/.venvs/fm-music/bin/python tools/music/jungla_nes.py [pista ...]  → previas en FlappyMonster_pruebas/musica/jungla/
#   REPORT=1 → solo números · INSTALL=1 JUNGLA_1=A|B JUNGLA_2=A|B → assets/music/worlds/jungla/<pista>_intro|_loop.ogg
#   (+ tools/music/mid/<pista>.mid). Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_n163, q_tri
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W
import gm as GM

P, CH = W.P, W.CH
MAJ, MIN = (0, 4, 7), (0, 3, 7)
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/jungla'
INSTALL_DIR = os.path.join(F.MUSIC_DIR, 'worlds', 'jungla')
NAMES = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B']
nm = lambda m: NAMES[m % 12] + str(m // 12 - 1)

# ══ EL RIFF DEL ESCARABAJO (templo.py) y sus citas ════════════════════════════════════════════════════════════════
RIFF_RHYTHM = (0, 2, 5, 8, 11, 14)                                   # 2+3+3+3+3+2


def riff_head(top, third, up, root):
    """La cabeza del riff sobre un acorde: nota repetida (2, 3), sube por grado dos veces, cae, repite.
    El 3er golpe dura 2 (es de paso: entra y sale por grado, regla 2). Notas como texto."""
    return f"0:{top}/2 2:{top}/3 5:{third}/2 8:{up}/3 11:{root}/3 14:{root}/2"


RIFF_Ab = riff_head('C6', 'Db6', 'Eb6', 'Ab5')                       # tal cual (una octava arriba): Do Do Re♭ Mi♭ La♭ La♭
RIFF_Eb = riff_head('G5', 'Ab5', 'Bb5', 'Eb5')                       # en secuencia sobre Mi♭ (jungla_2)
RIFF_Fm = riff_head('Ab5', 'Bb5', 'C6', 'F5')                        # sobre Fa menor (jungla_2)

# ══ JUNGLA_1 "Corazón de la selva" (Fa menor) ═════════════════════════════════════════════════════════════════════
SCALE_Fm = {5, 7, 8, 10, 0, 1, 3}
J1_A = "Db Eb Fm Fm Bbm Cm Db|Eb Fm"                                 # VI VII i — el color de la referencia
J1_B = "Db Eb Bbm Cm Db Eb Gb Fm"                                    # el GIRO OSCURO: Sol♭ (♭II) → Fa menor
J1_C = "Ab Ab Db Eb Ab Fm Bbm|Eb Fm"                                 # el estribillo en La♭ (III): el riff tal cual
J1_K = "Fm Fm Db Eb Fm Fm Db Eb"                                     # el corro de tambores
J1_IN = "Fm Fm Db Eb"
J1_MEL = {
    # A "liana": golpes 3+2+3+3+2+3 (primo del 2+3+3+3+3+2 del riff); sube por el acorde (5-4-3) y vuelve por grados;
    # la respuesta, en secuencia
    'A': {'A': ["0:Ab4/3 3:Db5/2 5:F5/3 8:Ab5/3 11:G5/2 13:F5/3",
                "0:G5/3 3:F5/2 5:Eb5/3 8:G5/3 11:Ab5/2 13:Bb5/3",
                "0:C6/3 3:Bb5/2 5:Ab5/3 8:F5/3 11:G5/2 13:Ab5/3",
                "0:F5/3 3:G5/2 5:Ab5/11",
                "0:Db5/3 3:F5/2 5:Bb5/3 8:Db6/3 11:C6/2 13:Bb5/3",
                "0:G5/3 3:F5/2 5:Eb5/3 8:G5/3 11:Ab5/2 13:G5/3",
                "0:Ab5/3 3:F5/3 6:Db5/2 8:Bb5/3 11:G5/3 14:Eb5/2"],                         # el tresillo 3+3+2
          'E1': "0:F5/3 3:G5/2 5:Ab5/3 8:C6/8",
          'E2': "0:Ab5/3 3:G5/2 5:F5/11",
          'B': ["0:F5/3 3:Ab5/5 8:Db6/6 14:C6/2",
                "0:Bb5/6 6:G5/2 8:Eb5/3 11:G5/5",
                "0:Bb5/3 3:Db6/5 8:F6/6 14:Eb6/2",
                "0:Eb6/6 6:C6/2 8:G5/6 14:Ab5/2",
                "0:Ab5/3 3:F5/5 8:Ab5/2 10:Db6/2 12:F6/4",
                "0:Eb6/3 3:Bb5/5 8:G5/6 14:Bb5/2",
                "2:Db6/2 4:Bb5/4 8:Gb5/2 10:Db5/6",                                           # Sol♭: baja el acorde
                "0:C5/4 4:F5/2 6:Ab5/2 8:C6/8"],                                              # LA LLAMADA (Do-Fa-La♭-Do)
          'C': [RIFF_Ab,
                "0:C6/2 2:Bb5/2 4:Ab5/2 6:Eb5/4 10:F5/2 12:G5/2 14:Ab5/2",
                "0:Ab5/3 3:F5/3 6:Ab5/2 8:Db6/4 12:C6/2 14:Bb5/2",
                "0:Bb5/6 6:G5/2 8:Eb5/8",
                RIFF_Ab,
                "0:C6/2 2:Ab5/3 5:F5/3 8:G5/2 10:Ab5/2 12:C6/4",
                "0:Db6/2 2:C6/1 3:Bb5/3 6:F5/2 8:G5/2 10:Bb5/2 12:Eb6/4",
                "0:C6/4 4:Ab5/2 6:G5/2 8:F5/8"]},
    # B "dos flautas": hemiolia — golpes cada 3 semicorcheas (3+3+3+3+2+2), notas largas, adornos de flauta
    'B': {'A': ["0:Ab5/3 3:F5/3 6:Ab5/3 9:Db6/4 13:C6/2 15:Db6/1",
                "2:Bb5/2 4:G5/6 10:Ab5/2 12:Bb5/4",
                "0:C6/3 3:Ab5/3 6:C6/3 9:F6/4 13:Eb6/2 15:Db6/1",
                "0:C6/10 10:Bb5/2 12:Ab5/4",
                "0:F5/3 3:Db5/3 6:F5/3 9:Bb5/4 13:C6/2 15:Db6/1",
                "2:Eb6/2 4:G6/6 10:F6/2 12:Eb6/4",
                "0:F5/3 3:Ab5/3 6:Db6/2 8:G5/3 11:Bb5/3 14:Eb6/2"],                           # el tresillo, subiendo
          'E1': "0:Eb6/1 1:Db6/1 2:C6/6 8:Ab5/3 11:F5/5",
          'E2': "0:Eb6/1 1:Db6/1 2:C6/2 4:Ab5/2 6:G5/2 8:F5/8",
          'B': ["0:Ab5/3 3:Db6/5 8:F6/6 14:Eb6/2",
                "0:Eb6/3 3:Bb5/5 8:G5/3 11:Bb5/5",
                "0:Bb5/3 3:Db6/5 8:F6/3 11:Db6/5",
                "0:C6/3 3:Eb6/5 8:G6/6 14:F6/2",
                "0:F6/3 3:Db6/3 6:Ab5/2 8:Bb5/2 10:C6/2 12:Db6/4",
                "0:Eb6/3 3:Bb5/3 6:G5/2 8:Ab5/2 10:Bb5/2 12:Eb6/4",
                "0:Db6/3 3:Bb5/3 6:Gb5/2 8:Bb5/3 11:Gb5/3 14:Db5/2",
                "0:C5/4 4:F5/2 6:Ab5/2 8:C6/8"],                                              # LA LLAMADA
          'C': [RIFF_Ab,
                "0:Eb6/3 3:C6/3 6:Ab5/3 9:Eb5/3 12:F5/2 14:G5/2",
                "0:Ab5/3 3:Db6/3 6:F6/3 9:Db6/3 12:Eb6/2 14:F6/2",
                "0:G6/6 6:Eb6/3 9:Bb5/3 12:G5/4",
                RIFF_Ab,
                "0:C6/3 3:Ab5/3 6:F5/3 9:Ab5/3 12:Bb5/2 14:C6/2",
                "0:Db6/3 3:Bb5/3 6:F5/2 8:G5/3 11:Bb5/3 14:Eb6/2",
                "0:C6/1 1:Db6/1 2:C6/6 8:Ab5/3 11:F5/5"]},
}

# ══ JUNGLA_2 "Río de tambores" (Si♭ dórico, 12/8; R en 4/4) ══════════════════════════════════════════════════════
SCALE_Bbd = {10, 0, 1, 3, 5, 7, 8}
J2_A = "Bbm Eb Bbm Fm Db Ab Eb Bbm"
J2_B = "Db Ab Eb Bbm Gb Db Eb|Fm Bbm"                                 # el GIRO OSCURO: Sol♭ (el ♭6 del menor natural)
J2_B2 = "Db Ab Eb Bbm Gb Db Eb|Fm Fm"                                   # (B': acaba en la dominante menor → vuelve a A)
J2_R = "Eb Eb Fm Bbm Eb Eb Db|Eb Fm"                                 # 4/4: la sombra del escarabajo
J2_IN = "Bbm Bbm Bbm Fm"
J2_MEL = {
    # A "pulso": la corriente del río — tres corcheas que ruedan y una nota que se posa, en secuencia; la hemiolia
    'A': {'A': ["1:F5/1 2:Bb5/2 4:Db6/2 6:C6/1 7:Bb5/2 9:F5/3",
                "1:G5/1 2:Bb5/2 4:Eb6/2 6:F6/1 7:Eb6/2 9:Bb5/3",
                "1:F6/2 3:Eb6/1 4:Db6/2 6:C6/1 7:Bb5/2 9:F5/3",
                "1:C5/1 2:F5/2 4:Ab5/2 6:G5/1 7:F5/2 9:C5/3",
                "1:Ab5/1 2:Db6/2 4:F6/2 6:Eb6/1 7:Db6/2 9:Ab5/3",
                "0:C6/3 3:Bb5/1 4:Ab5/2 6:Eb5/2 8:F5/1 9:G5/1 10:Ab5/2",
                "0:Bb5/2 2:G5/2 4:Eb5/2 6:G5/2 8:Bb5/2 10:Eb6/2"],                            # HEMIOLIA (3/4 sobre 12/8)
          'E1': "1:Db6/2 3:C6/1 4:Db6/2 6:F5/6",
          'E2': "1:Db6/1 2:C6/1 3:Bb5/9",
          'B': ["0:F6/4 4:Eb6/1 5:Db6/1 6:Ab5/6",
                "0:C6/4 4:Bb5/1 5:Ab5/1 6:Eb5/6",
                "0:Bb5/4 4:C6/1 5:Bb5/1 6:G5/3 9:Bb5/3",
                "1:Db6/2 3:C6/1 4:Bb5/2 6:F5/6",
                "0:Bb5/4 4:Db6/2 6:Gb6/6",                                                    # Sol♭
                "0:F6/4 4:Eb6/1 5:Db6/1 6:Ab5/3 9:F5/3",
                "0:G5/2 2:Bb5/2 4:Eb6/2 6:C6/2 8:Ab5/2 10:F5/2",
                "0:F5/3 3:Bb5/2 5:Db6/1 6:F6/6"],                                             # LA LLAMADA (Fa-Si♭-Re♭-Fa)
          'B8': "0:F6/3 3:Eb6/1 4:Db6/1 5:C6/1 6:Ab5/3 9:F5/3",                                               # (B': otro final, hacia A)
          'R': [RIFF_Eb,
                "0:G5/2 2:Bb5/2 4:Eb6/4 8:Db6/1 9:C6/1 10:Bb5/2 12:G5/4",
                RIFF_Fm,
                "0:Db6/2 2:C6/1 3:Bb5/3 6:F5/2 8:G5/1 9:Ab5/1 10:Bb5/6",
                "0:G5/2 2:G5/3 5:Ab5/2 8:Bb5/3 11:Eb6/3 14:Eb6/2",                            # (la cabeza, y sigue arriba)
                "0:G6/4 4:F6/1 5:Eb6/1 6:Bb5/2 8:G5/2 10:Bb5/2 12:Eb6/4",
                "0:F6/3 3:Db6/3 6:Ab5/2 8:G5/3 11:Bb5/3 14:Eb6/2",                            # el tresillo 3+3+2
                "0:C6/4 4:Ab5/2 6:G5/2 8:F5/8"]},
    # B "balafón": figuras de mazo — notas repetidas, arpegios que bajan y suben, rollos en las notas largas
    'B': {'A': ["0:Bb5/1 1:Bb5/1 2:F5/1 3:Db6/2 5:Bb5/1 6:F6/3 9:Db6/1 10:C6/1 11:Bb5/1",
                "0:G5/3 3:Bb5/1 4:Bb5/1 5:Eb6/1 6:G6/2 8:F6/1 9:Eb6/3",
                "0:Db6/1 1:Db6/1 2:Bb5/1 3:F6/2 5:Db6/1 6:Bb5/3 9:F5/1 10:Bb5/1 11:Db6/1",
                "0:C6/3 3:Ab5/1 4:Ab5/1 5:F5/1 6:C6/2 8:Bb5/1 9:Ab5/3",
                "0:F6/1 1:F6/1 2:Db6/1 3:Ab6/2 5:F6/1 6:Db6/3 9:Ab5/1 10:Bb5/1 11:C6/1",
                "0:C6/3 3:Ab5/1 4:Ab5/1 5:Eb5/1 6:C6/2 8:Bb5/1 9:Ab5/3",
                "0:Bb5/2 2:G5/2 4:Eb5/2 6:G5/2 8:Bb5/2 10:Eb6/2"],                            # HEMIOLIA
          'E1': "0:Db6/1 1:Db6/1 2:Bb5/1 3:F5/9",
          'E2': "0:F6/1 1:Eb6/1 2:Db6/1 3:Bb5/9",
          'B': ["0:Ab5/1 1:Db6/1 2:F6/1 3:Ab6/3 6:F6/1 7:Eb6/1 8:Db6/1 9:Ab5/3",
                "0:Ab5/1 1:C6/1 2:Eb6/1 3:Ab6/3 6:Eb6/1 7:Db6/1 8:C6/1 9:Ab5/3",
                "0:G5/1 1:Bb5/1 2:Eb6/1 3:G6/3 6:Eb6/1 7:F6/1 8:Eb6/1 9:Bb5/3",
                "0:Bb5/1 1:Db6/1 2:F6/1 3:Db6/3 6:Bb5/6",
                "0:Gb5/1 1:Bb5/1 2:Db6/1 3:Gb6/3 6:Db6/1 7:Bb5/1 8:Db6/1 9:Gb6/3",           # Sol♭
                "0:F6/3 3:Eb6/1 4:Db6/2 6:Ab5/3 9:F5/3",
                "0:G5/2 2:Bb5/2 4:Eb6/2 6:C6/2 8:Ab5/2 10:F5/2",
                "0:F5/3 3:Bb5/2 5:Db6/1 6:F6/6"],                                             # LA LLAMADA
          'B8': "0:F6/1 1:Eb6/1 2:Db6/1 3:C6/3 6:Ab5/1 7:Bb5/1 8:C6/1 9:F6/3",
          'R': [RIFF_Eb,
                "0:Bb5/1 1:Eb6/1 2:G6/2 4:Bb5/1 5:Eb6/1 6:G6/2 8:F6/1 9:Eb6/1 10:Db6/1 11:C6/1 12:Bb5/4",
                RIFF_Fm,
                "0:Bb5/1 1:Db6/1 2:F6/2 4:Bb5/1 5:Db6/1 6:F6/2 8:Eb6/1 9:Db6/1 10:C6/1 11:Db6/1 12:Bb5/4",
                "0:G5/2 2:G5/3 5:Ab5/2 8:Bb5/3 11:Eb6/3 14:Eb6/2",
                "0:G6/2 2:Eb6/1 3:Bb5/1 4:G6/2 6:Eb6/1 7:Bb5/1 8:G5/2 10:Bb5/2 12:Eb6/4",
                "0:F6/3 3:Db6/3 6:Ab5/2 8:G5/3 11:Bb5/3 14:Eb6/2",                            # el tresillo 3+3+2
                "0:C6/2 2:Ab5/1 3:F5/1 4:C6/2 6:Ab5/1 7:G5/1 8:F5/8"]},
}

# ══ JUNGLA_BONUS "Lianas" (La♭ mixolidio, 160) ═══════════════════════════════════════════════════════════════════
SCALE_Abx = {8, 10, 0, 1, 3, 5, 6}
JB_A = "Ab Gb Ab Db Ab Gb Db|Ebm Ab"
JB_B = "Db Ab Gb Ebm Db Dbm Gb|Ebm Ab"                               # el GIRO OSCURO: Re♭ menor (iv menor prestado)
JB_IN = "Ab Ab Ab Ab"
JB_MEL = {'A': ["0:Ab5/2 2:Ab5/1 3:C6/2 5:Eb6/3 8:Db6/1 9:C6/2 11:Ab5/3 14:Bb5/2",            # la liana: salta y se balancea
                "0:Bb5/2 2:Bb5/1 3:Db6/2 5:Gb6/3 8:F6/1 9:Eb6/2 11:Db6/3 14:Eb6/2",
                "0:Eb6/3 3:C6/3 6:Ab5/2 8:C6/2 10:Bb5/1 11:Ab5/1 12:Eb5/4",
                "0:F5/2 2:Ab5/2 4:Db6/4 8:C6/1 9:Bb5/1 10:Ab5/6",
                "0:Ab5/2 2:Ab5/1 3:C6/2 5:Eb6/3 8:Db6/1 9:C6/2 11:Ab5/3 14:C6/2",
                "0:Db6/2 2:Db6/1 3:Bb5/2 5:Gb5/3 8:Ab5/1 9:Bb5/2 11:Db6/3 14:Bb5/2",
                "0:Ab5/3 3:F5/3 6:Db5/2 8:Gb5/3 11:Bb5/3 14:Eb6/2"],                               # el tresillo
          'E1': "0:C6/2 2:Bb5/1 3:Ab5/3 6:C6/2 8:Eb6/8",
          'E2': "0:Eb6/2 2:Db6/1 3:C6/3 6:Ab5/2 8:Eb5/8",
          'B': ["0:F6/4 4:Eb6/2 6:Db6/2 8:Ab5/6 14:Bb5/2",
                "0:C6/4 4:Bb5/2 6:Ab5/2 8:Eb5/6 14:F5/2",
                "0:Gb5/3 3:Bb5/3 6:Db6/2 8:Gb6/6 14:F6/2",
                "0:Eb6/4 4:Db6/1 5:C6/1 6:Bb5/2 8:Gb5/6 14:Ab5/2",
                "0:Ab5/3 3:Db6/3 6:F6/2 8:Ab6/6 14:Gb6/2",
                "0:Fb6/4 4:Db6/2 6:Ab5/2 8:Fb5/6 14:Eb5/2",                                       # Re♭ menor (Fa♭)
                "0:Db5/2 2:Gb5/2 4:Bb5/2 6:Db6/2 8:Bb5/2 10:Gb5/2 12:Eb5/2 14:F5/2",
                "0:Eb5/4 4:Ab5/2 6:C6/2 8:Eb6/8"]}                                                 # LA LLAMADA (Mi♭-La♭-Do-Mi♭)


def sections_j1(v):
    M = J1_MEL[v]
    A1, A2 = M['A'] + [M['E1']], M['A'] + [M['E2']]
    return [('intro', J1_IN, [''] * 4, 16, ''),
            ('A', J1_A, A1, 16, ''), ('A', J1_A, A2, 16, ''), ('B', J1_B, M['B'], 16, ''), ('C', J1_C, M['C'], 16, ''),
            ('K', J1_K, [''] * 8, 16, 'thin'),
            ('A', J1_A, A2, 16, 'cm' if v == 'A' else 'thirds'), ('C', J1_C, M['C'], 16, 'dbl' if v == 'A' else 'thirds dbl')]


def sections_j2(v):
    M = J2_MEL[v]
    A1, A2 = M['A'] + [M['E1']], M['A'] + [M['E2']]
    return [('intro', J2_IN, [''] * 4, 12, ''),
            ('A', J2_A, A1, 12, ''), ('A', J2_A, A2, 12, ''), ('B', J2_B, M['B'], 12, ''),
            ('R', J2_R, M['R'], 16, ''),
            ('A', J2_A, A2, 12, 'stop'), ('B', J2_B2, M['B'][:7] + [M['B8']], 12, 'dbl')]


def sections_bonus(v=None):
    M = JB_MEL
    A1, A2 = M['A'] + [M['E1']], M['A'] + [M['E2']]
    return [('intro', JB_IN, [''] * 4, 16, ''),
            ('A', JB_A, A1, 16, ''), ('A', JB_A, A2, 16, ''), ('B', JB_B, M['B'], 16, ''),
            ('solo', 'Ab ' * 8, [''] * 8, 16, ''), ('A', JB_A, A2, 16, 'dbl')]


TRACKS = {
    'jungla_1': dict(secs=sections_j1, bpm=138, scale=SCALE_Fm, tonic=(5, MIN), lufs=-11.0, variants=('A', 'B'),
                     title='Corazón de la selva', vname={'A': 'liana', 'B': 'dos_flautas'}),
    'jungla_2': dict(secs=sections_j2, bpm=120, scale=SCALE_Bbd, tonic=(10, MIN), lufs=-11.0, variants=('A', 'B'),
                     title='Río de tambores', vname={'A': 'pulso', 'B': 'balafon'}),
    'jungla_bonus': dict(secs=sections_bonus, bpm=160, scale=SCALE_Abx, tonic=(8, MAJ), lufs=-11.0, variants=(None,),
                         title='Lianas', vname={None: ''}),
}


# ══ LA CANCIÓN: compases, rejilla (16 = 4/4 en semicorcheas · 12 = 12/8 en corcheas), acordes, melodía ══════════════
class Song:
    def __init__(self, track, v):
        spec = TRACKS[track]
        self.track, self.v, self.bpm, self.scale, self.tonic = track, v, spec['bpm'], spec['scale'], spec['tonic']
        self.BAR = 4 * 60.0 / self.bpm                                   # (4 pulsos por compás: negras o negras con puntillo)
        self.chords, self.steps, self.tag, self.var, self.pos, self.slen, self.sidx = [], [], [], [], [], [], []
        self.mel, self.starts = [], []
        for si, (tag, ch, bars, steps, var) in enumerate(spec['secs'](v)):
            base = len(self.chords)
            self.starts.append(base + 1)
            cc = CH(ch)
            assert len(cc) == len(bars), (track, tag)
            for i, (c, txt) in enumerate(zip(cc, bars)):
                self.chords.append(c if isinstance(c[0], tuple) else (c, c))
                self.steps.append(steps); self.tag.append(tag); self.var.append(var)
                self.pos.append(i + 1); self.slen.append(len(bars)); self.sidx.append(si)
                if txt: self.mel += P(base + i + 1, txt)
        self.NB = len(self.chords)
        self.INTRO = self.slen[0]
        self.mel.sort()

    def t(self, b, st):                                                  # segundos
        return (b - 1) * self.BAR + st * self.BAR / self.steps[b - 1]

    def q(self, b, st):                                                  # semicorcheas (de 4/4) desde el principio
        return (b - 1) * 16 + st * 16.0 / self.steps[b - 1]

    def dur(self, b, d):
        return d * self.BAR / self.steps[b - 1]

    def chord(self, b, st):
        return self.chords[b - 1][0 if st < self.steps[b - 1] / 2 else 1]

    def tones(self, b, st):
        r, q = self.chord(b, st)
        return {(r + i) % 12 for i in q}


# ══ LAS COMPROBACIONES (reglas 2 y 3 de la guía) ════════════════════════════════════════════════════════════════════
def check(sg, mel=None):
    """→ largas fuera del acorde · sueltas (fuera del acorde y no entran / salen por grado, o duran ≥ 3 semicorcheas) ·
    fuera de la escala (la escala + las notas del acorde que suena: los prestados) · % a contratiempo"""
    mel = sg.mel if mel is None else mel
    Q = lambda m: sg.q(m[0], m[1])
    E = lambda m: sg.q(m[0], m[1] + m[3])
    long_bad, loose, out = [], [], []
    for i, m in enumerate(mel):
        b, st, n, d = m
        tones = sg.tones(b, st)
        if n % 12 not in sg.scale | tones: out.append((b, st, nm(n)))
        if n % 12 in tones: continue
        d16 = E(m) - Q(m)
        if d16 >= 4: long_bad.append((b, st, nm(n)))
        p = mel[i - 1] if i and E(mel[i - 1]) >= Q(m) - 2 else None
        x = mel[i + 1] if i + 1 < len(mel) and E(m) >= Q(mel[i + 1]) - 2 else None
        if d16 >= 3 or not p or abs(n - p[2]) > 2 or not x or abs(x[2] - n) > 2: loose.append((b, st, nm(n)))
    beat = lambda b: 4 if sg.steps[b - 1] == 16 else 3
    off = np.mean([st % beat(b) != 0 for b, st, n, d in mel]) if mel else 0
    return long_bad, loose, out, off


def clashes(sg, a, others, min16=2):
    """2ª menor / 7ª mayor / tritono entre la melodía y otra voz que duran una corchea (2 semicorcheas) o más"""
    out = []
    for b, st, n, d in a:
        s0, e0 = sg.q(b, st), sg.q(b, st + d)
        if n % 12 not in sg.tones(b, st) and e0 - s0 < 3: continue          # (de paso: entra y sale por grado, ver check)
        for (q0, q1, n2) in others:
            if q1 <= s0 or q0 >= e0: continue
            if min(e0, q1) - max(s0, q0) >= min16 and (n - n2) % 12 in (1, 6, 11): out.append((b, st, nm(n), nm(n2)))
    return out


def attack_overlap(sg):
    """Dónde caen los golpes de la frase A (compases 1-7) frente a las frases A de las demás islas (regla 8)"""
    a0 = sg.starts[1]
    mine = {(b - a0, round(sg.q(b, st) - (b - 1) * 16, 2)) for b, st, n, d in sg.mel if a0 <= b < a0 + 7}
    others = {'pradera_1': W.A_HOP, 'pradera_2': W.P_A, 'costa_1': W.K_A, 'costa_2': W.R_A, 'fortaleza_1': W.H_A,
              'fortaleza_2': W.N_A, 'nieve_1': W.S_A, 'nieve_2': W.V_A, 'cuevas_1': W.C_A, 'cuevas_2': W.U_A,
              'volcan_1': W.L_A, 'volcan_2': W.F_A, 'flappy': W.FL_A}
    others.update({k + '(bonus)': W.BONUS[k][0] for k in W.BONUS})
    res = {k: len(mine & {(b - 1, float(st)) for b, st, n, d in ph if b <= 7}) / max(1, len(mine)) for k, ph in others.items()}
    k = max(res, key=res.get)
    return res[k], k, np.mean(list(res.values()))


# ══ INSTRUMENTOS ═════════════════════════════════════════════════════════════════════════════════════════════════
WAVES = [wavetable([1.0, 0.25, 0.2, 0.06, 0.05, 0.02]),            # 0 flauta de madera (impares algo marcados: hueca)
         wavetable([1.0, 0.3, 0.1])]                                # 1 colchón
I_WOOD = {'vol': [7, 11, 13, 14, 13, 13], 'sus': 12, 'vib': (16, 0.2, 5.2), 'duty': 0, 'drop': [-0.7, -0.35, -0.12]}
I_PULSE = {'vol': [14, 14, 13, 13, 12, 12], 'sus': 12, 'vib': (14, 0.2, 5.6), 'duty': [0.125, 0.125, 0.25, 0.25, 0.5]}
I_DBL = {'vol': [8, 7, 6, 6, 5, 5], 'sus': 5, 'duty': 0.125}
I_PAD = {'vol': [2, 3, 4, 5, 5, 5], 'sus': 5, 'vib': (24, 0.12, 4.5), 'duty': 1}
I_CM = {'vol': [4, 6, 7, 7, 7, 6], 'sus': 6, 'vib': (18, 0.12, 5.0), 'duty': 1}
I_TRI = {'vol': [15], 'sus': 15}
P_MARIMBA, P_KALIMBA, P_PAN, P_OCARINA, P_BOTTLE, P_TAIKO, P_LOGDRUM = 12, 108, 75, 79, 76, 116, 117
KICK, RIM, CLAP, TOM_L, TOM_M, CHH, OHH, CRASH, COWBELL = 36, 37, 39, 41, 45, 42, 46, 49, 56
BONGO_H, BONGO_L, CONGA_M, CONGA_O, CONGA_L, TIMB_H, TIMB_L = 60, 61, 62, 63, 64, 65, 66
AGOGO_H, AGOGO_L, CABASA, MARACAS, WHISTLE_S, WHISTLE_L, WOOD_H, WOOD_L, SHAKER, SURDO_M, SURDO_O = \
    67, 68, 69, 70, 71, 72, 76, 77, 82, 86, 87
HAT, SNARE_N, CRASH_N = [5, 2, 1], [13, 9, 5, 2], [13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
LEAD_KEYS = ('lead', 'lead2', 'thirds')
DRUM_KEYS = ('kick', 'snare', 'hat', 'crash', 'congas', 'shaker', 'bell', 'taiko', 'timb', 'wood', 'surdo', 'logs', 'rim', 'whistle')


class Rig:
    """Lo que suena: canales de Famicom, grabaciones GM y, para las comprobaciones, las notas de cada voz"""
    def __init__(self, sg):
        self.sg = sg
        NF = F.frames_for(sg.NB * sg.BAR + 3)
        self.NS = int(NF * F.FRAME_S) + SR
        self.Cn = {k: Chan(NF) for k in ('lead', 'dbl', 'pad1', 'pad2', 'cm', 'bass')}
        self.NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash')}
        self.dk, self.sn = np.zeros(self.NS), np.zeros(self.NS)
        self.G, self.D, self.notes = {}, {}, {}

    def gm(self, k, prog, b, st, n, d, vel, gate=0.95):
        sg = self.sg
        self.G.setdefault(k, GM.Rec(prog)).add(sg.t(b, st), sg.t(b, st) + sg.dur(b, d) * gate, n, vel)
        self.notes.setdefault(k, []).append((sg.q(b, st), sg.q(b, st + d), n))

    def dr(self, k, b, st, n, vel, d=1):
        sg = self.sg
        self.D.setdefault(k, GM.Rec(drums=True)).add(sg.t(b, st), sg.t(b, st) + sg.dur(b, d), n, vel)

    def chip(self, k, b, st, n, d, inst, q=F.q_pulse, gate=0.94, release=3):
        sg = self.sg
        play(self.Cn[k], sg.t(b, st), sg.t(b, st) + sg.dur(b, d) * gate, n, inst, q=q, release=release)
        self.notes.setdefault(k, []).append((sg.q(b, st), sg.q(b, st + d), n))

    def hit(self, buf, smp, t, g=1.0):
        i = int(t * SR); m = max(0, min(len(smp), self.NS - i))
        buf[i:i + m] += smp[:m] * g

    def kick(self, b, st, g=1.0, deep=False):
        self.hit(self.dk, TN.KICK_DEEP if deep else TN.KICK, self.sg.t(b, st), g)

    def snare(self, b, st, g=1.0):
        t = self.sg.t(b, st)
        self.NZ['snare'].hit(t, 4, [max(1, int(v * g + 0.5)) for v in SNARE_N]); self.hit(self.sn, TN.SNARE_BODY, t, 0.9 * g)

    def rub(self, b, st, n, d, voice=('lead',)):
        """¿choca (2ª menor, 7ª mayor, tritono) con la melodía que suena?"""
        sg = self.sg
        s0, e0 = sg.q(b, st), sg.q(b, st + d)
        return any(min(e0, q1) - max(s0, q0) > 0.5 and (n - n2) % 12 in (1, 6, 11)
                   for k in voice for (q0, q1, n2) in self.notes.get(k, []) if q0 < e0 and q1 > s0)


def place(r, c, lo):
    """las notas del acorde c desde lo hacia arriba (raíz, 3ª, 5ª, 8ª, 10ª, 12ª, 15ª)"""
    root, q = c
    r0 = lo + (root - lo) % 12
    return [r0 + o + iv for o in (0, 12, 24) for iv in q][:7]


def counter(sg, R, bars, lo=55, hi=67):
    """contracanto (N163, debajo de la melodía): una nota del acorde por medio compás, la más cercana a la anterior,
    sin 2ª menor / 7ª mayor / tritono con lo que canta la melodía mientras suena"""
    prev = None
    for b in bars:
        S = sg.steps[b - 1]
        for half in (0, 1):
            st, d = half * S // 2, S // 2
            r, q = sg.chords[b - 1][half]
            cands = sorted((p for p in range(lo, hi + 1) if (p - r) % 12 in q), key=lambda p: (abs(p - (prev or lo + 6)), p))
            cands = [p for p in cands if not R.rub(b, st, p, d)] or cands
            prev = cands[0]
            R.chip('cm', b, st, prev, d, I_CM, q=q_n163, gate=0.97, release=5)


def thirds(sg, R, bars, prog, vel, key='thirds'):
    """la 2ª flauta: una 3ª (diatónica) por debajo; en las notas largas, la nota del acorde más cercana por debajo"""
    for b, st, n, d in [m for m in sg.mel if m[0] in bars]:
        tones = sg.tones(b, st)
        if sg.q(b, st + d) - sg.q(b, st) >= 3 or n % 12 not in sg.scale:
            h = max(p for p in range(n - 9, n - 2) if p % 12 in tones)
        else:
            h = [p for p in range(n - 4, n - 2) if p % 12 in sg.scale | tones][0]
        R.gm(key, prog, b, st, h, d, vel)


# ══ ARREGLOS ═════════════════════════════════════════════════════════════════════════════════════════════════════
def toucan(sg, R, b, vel=72):
    """el ACENTO de la jungla (jungla_1 y el bonus): el tucán — la 5ª dos veces y la raíz una 4ª arriba (ocarina),
    solo donde la melodía se posa (ningún golpe suyo en la segunda mitad del compás)"""
    if any(bb == b and st >= 9 for bb, st, n, d in sg.mel):
        return
    r, q = sg.chord(b, 12)
    f5 = 79 + (r + 7 - 79) % 12
    for st, n, d, v in ((10, f5, 1, vel - 10), (11, f5, 1, vel - 14), (12, f5 + 5, 3, vel)):
        if not R.rub(b, st, n, d): R.gm('accent', P_OCARINA, b, st, n, d, v, gate=0.85)


def arrange_j1(sg, R, v):
    lead_bars = []
    for b in range(1, sg.NB + 1):
        tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        last = k == L
        # ── LA MELODÍA ──
        for bb, st, n, d in [m for m in sg.mel if m[0] == b]:
            if v == 'A':
                R.chip('lead', b, st, n, d, I_WOOD, q=q_n163, release=4)
                if 'dbl' in var and n + 12 <= 96: R.chip('dbl', b, st, n + 12, d, I_DBL, release=2)
            else:
                R.gm('lead', P_PAN, b, st, n, d, 104 if tag == 'C' else 96, gate=0.97)
                R.chip('lead', b, st, n - 12, d, I_WOOD, q=q_n163, release=4)      # (la flauta de N163, una octava abajo: el color de la casa)
                if 'dbl' in var and n + 12 <= 96: R.chip('dbl', b, st, n + 12, d, I_DBL, release=2)
        if 'thirds' in var: lead_bars.append(b)
    if v == 'B': thirds(sg, R, set(lead_bars), P_OCARINA, 78)
    counter(sg, R, [b for b in range(1, sg.NB + 1) if 'cm' in sg.var[b - 1]])
    for b in range(1, sg.NB + 1):
        tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        last = k == L
        nxt = sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0]
        riff_bar = tag == 'C' and k in (1, 5)
        # ── EL RIFF: marimba + kalimba con la flauta, a su altura de la referencia (como en el jefe) ──
        if riff_bar:
            for bb, st, n, d in [m for m in sg.mel if m[0] == b]:
                R.gm('riff', P_MARIMBA, b, st, n - 12, d, 92); R.gm('riff', P_KALIMBA, b, st, n - 12, d, 70)
        # ── EL BAJO (triángulo): rebota y anticipa la raíz ──
        if tag != 'intro' or k >= 3:
            def bn(st, deg, d, up=0):
                r, q = sg.chord(b, st)
                base = 41 + (r - 41) % 12
                n = base + {0: 0, 5: 7, 8: 12}[deg] + up
                R.chip('bass', b, st, n, d, I_TRI, q=q_tri, gate=0.9, release=1)
            if tag == 'K' and k <= 4 or (tag == 'intro'):
                bn(0, 0, 6); bn(6, 5, 2); bn(8, 0, 6); bn(14, 8, 2)
            else:
                bn(0, 0, 3); bn(3, 8, 2); bn(6, 5, 2); bn(10, 0, 2); bn(12, 8, 1)
                r2 = nxt[0]
                n2 = 41 + (r2 - 41) % 12
                if last or r2 != sg.chord(b, 14)[0]:
                    ap = [p for p in (n2 - 2, n2 - 1, n2 + 2, n2 + 1) if p % 12 in sg.scale and p >= 40 and not R.rub(b, 14, p, 2)]
                    R.chip('bass', b, 14, ap[0] if ap else n2, 2, I_TRI, q=q_tri, gate=0.9, release=1)
                else: bn(14, 5, 2)
        # ── LA MARIMBA: acordes partidos en 3+3+3+3+2+2 ──
        if not riff_bar and (tag in ('A', 'B', 'C', 'K') or (tag == 'intro' and k >= 3)):
            for st, deg in ((0, 0), (3, 2), (6, 3), (9, 1), (12, 2), (14, 1)):
                c = sg.chord(b, st)
                n = place(None, c, 55)[deg]
                vel = (86 if st == 0 else 66) + (8 if tag == 'K' else 0)
                if not R.rub(b, st, n, 3): R.gm('marimba', P_MARIMBA, b, st, n, 3, vel)
        # ── LA KALIMBA: dos notas del acorde a contratiempo (desde A', en B y C) ──
        if (tag == 'A' and sg.sidx[b - 1] >= 2) or tag in ('B', 'C'):
            if not riff_bar:
                for st in (2, 10):
                    c = sg.chord(b, st)
                    for n in place(None, c, 67)[1:3]:
                        if not R.rub(b, st, n, 2): R.gm('kal', P_KALIMBA, b, st, n, 2, 60)
        # ── EL COLCHÓN (N163) en B, C y las vueltas ──
        if tag in ('B', 'C') or (tag == 'A' and var):
            for half in (0, 1):
                r, q = sg.chords[b - 1][half]
                base = 53 + (r - 53) % 12
                for j, iv in enumerate(q[1:]):
                    R.chip(('pad1', 'pad2')[j], b, half * 8, base + iv, 8, I_PAD, q=q_n163, gate=0.97, release=6)
        # ── EL ACENTO ──
        if tag in ('A', 'B', 'C') or (tag == 'intro' and k == 4) or (tag == 'K' and k % 2 == 0):
            toucan(sg, R, b)
        # ── BATERÍA ──
        for st in range(16):
            if tag == 'intro':
                if st == 0 and k in (1, 3): R.gm('taiko', P_TAIKO, b, st, 41, 4, 100)
                if k >= 1: R.dr('shaker', b, st, MARACAS if st % 2 else CABASA, 50 + (14 if st % 4 == 2 else 0))
                if k >= 2 and st in (4, 6, 12, 14, 15): R.dr('congas', b, st, (CONGA_M, CONGA_O, CONGA_O, CONGA_L, CONGA_L)[(4, 6, 12, 14, 15).index(st)], 84)
                if k >= 3 and st in (0, 10): R.kick(b, st, 0.85)
                if k == 4 and st >= 12: R.dr('timb', b, st, TIMB_H if st < 14 else TIMB_L, 86 + 4 * (st - 12))
                continue
            if tag == 'K':                                                   # el corro de tambores
                if st in (0, 6, 10) and k % 2 == 1: R.gm('taiko', P_TAIKO, b, st, 41 if st == 0 else 45, 4, 112 if st == 0 else 92)
                if st in (0, 3, 8, 11) and k % 2 == 0: R.gm('taiko', P_TAIKO, b, st, 45 if st % 8 else 41, 4, 100)
                if st in (2, 5, 9, 13, 14): R.dr('congas', b, st, (CONGA_O, CONGA_M, CONGA_O, CONGA_L, CONGA_L)[(2, 5, 9, 13, 14).index(st)], 96)
                if k >= 3 and st in (0, 3, 6, 8, 11, 14): R.dr('wood', b, st, WOOD_H if st in (0, 8) else WOOD_L, 82)   # los troncos en 3+3+2
                R.dr('shaker', b, st, SHAKER, 62 if st % 4 == 2 else 44)
                if k >= 5 and st in (0, 10): R.kick(b, st, 0.9)
                if k >= 7 and st in (4, 12): R.snare(b, st, 0.7)
                if last and st >= 8: R.snare(b, st, 0.45 + 0.04 * (st - 8))
                continue
            big = tag in ('B', 'C')
            if st in (0, 10) or (big and st == 7): R.kick(b, st, 1.0 if st == 0 else 0.85)
            if st in (4, 12):
                if big: R.snare(b, st, 0.85)
                else: R.dr('rim', b, st, RIM, 88)
            if st in (4, 6, 12, 14, 15): R.dr('congas', b, st, (CONGA_M, CONGA_O, CONGA_O, CONGA_L, CONGA_L)[(4, 6, 12, 14, 15).index(st)], 92 if st in (6, 14) else 78)
            if st in (3, 11) and big: R.dr('congas', b, st, BONGO_H, 58)
            R.dr('shaker', b, st, MARACAS if big else CABASA, 66 if st % 4 == 2 else 46)
            if st % 4 == 2: R.NZ['hat'].hit(sg.t(b, st), 1, HAT if big else [4, 1])
            if st == 0 and k == 1:
                R.NZ['crash'].hit(sg.t(b, st), 3, CRASH_N); R.gm('taiko', P_TAIKO, b, st, 41, 4, 104)
            if st == 0 and k == 5 and big: R.gm('taiko', P_TAIKO, b, st, 41, 4, 92)
            if last and st >= 12: R.dr('timb', b, st, TIMB_H if st < 14 else TIMB_L, 90 + 3 * (st - 12))


def arrange_j2(sg, R, v):
    for b in range(1, sg.NB + 1):
        tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        S = sg.steps[b - 1]
        last = k == L
        # ── LA MELODÍA ──
        for bb, st, n, d in [m for m in sg.mel if m[0] == b]:
            if v == 'A':
                R.chip('lead', b, st, n, d, I_PULSE, release=3)
                if 'dbl' in var and n + 12 <= 96: R.chip('dbl', b, st, n + 12, d, I_DBL, release=2)
            else:                                                            # balafón: rollo en las notas largas
                d16 = sg.q(b, st + d) - sg.q(b, st)
                if d16 >= 4:
                    step = 0.5 if S == 12 else 1.0                           # (rollo a semicorcheas)
                    k_, x = 0, 0.0
                    while x < d - 0.01:
                        R.G.setdefault('lead', GM.Rec(P_MARIMBA)).add(sg.t(b, st) + sg.dur(b, x), sg.t(b, st) + sg.dur(b, x + step), n, max(60, 110 - 6 * k_ - (12 if k_ % 2 else 0)))
                        x += step; k_ += 1
                    R.notes.setdefault('lead', []).append((sg.q(b, st), sg.q(b, st + d), n))
                else:
                    R.gm('lead', P_MARIMBA, b, st, n, d, 112 if st % (3 if S == 12 else 4) else 104)
                R.gm('lead2', P_KALIMBA, b, st, n + 12 if n + 12 <= 96 else n, min(d, 2), 72 if 'dbl' in var else 56)
    for b in range(1, sg.NB + 1):
        tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        S = sg.steps[b - 1]
        last = k == L
        stop = 'stop' in var and k < L
        r0 = sg.chords[b - 1][0][0]
        if tag == 'R':                                                       # ── 4/4: la sombra del escarabajo ──
            riff_bar = k in (1, 3, 5)
            if riff_bar:
                for bb, st, n, d in [m for m in sg.mel if m[0] == b]:
                    R.gm('riff', P_MARIMBA, b, st, n - 12, d, 90); R.gm('riff', P_KALIMBA, b, st, n - 12, d, 66)
            for st, deg, d in ((0, 0, 2), (2, 8, 1), (3, 0, 1), (4, 0, 2), (6, 8, 1), (7, 0, 1), (8, 0, 2), (10, 5, 2), (12, 0, 2), (14, 8, 2)):
                r, q = sg.chord(b, st)
                base = 39 + (r - 39) % 12
                R.chip('bass', b, st, base + {0: 0, 5: 7, 8: 12}[deg], d, I_TRI, q=q_tri, gate=0.85, release=1)
            if not riff_bar:
                for st in (2, 6, 10, 14):
                    c = sg.chord(b, st)
                    for n in place(None, c, 60)[1:3]:
                        if not R.rub(b, st, n, 2): R.gm('kal', P_KALIMBA, b, st, n, 2, 64)
            for half in (0, 1):
                r, q = sg.chords[b - 1][half]
                base = 53 + (r - 53) % 12
                for j, iv in enumerate(q[1:]):
                    R.chip(('pad1', 'pad2')[j], b, half * 8, base + iv, 8, I_PAD, q=q_n163, gate=0.97, release=6)
            for st in range(16):                                             # la batería de la referencia (templo.py)
                if st in (0, 6, 8, 13): R.kick(b, st, 1.0 if st in (0, 8) else 0.8)
                if st in (2, 12): R.dr('congas', b, st, CONGA_O if st == 2 else CONGA_L, 96)
                if st in (6, 9): R.dr('rim', b, st, CLAP, 84)
                if st in (4, 12): R.snare(b, st, 0.8)
                R.dr('shaker', b, st, MARACAS, 64 if st % 4 == 2 else 44)
                if st % 4 == 2: R.NZ['hat'].hit(sg.t(b, st), 1, HAT)
                if k in (1, 5) and st == 0: R.NZ['crash'].hit(sg.t(b, st), 3, CRASH_N); R.gm('taiko', P_TAIKO, b, st, 41, 4, 108)
                if last and st >= 8:                                         # (vuelve al 12/8: redoble de toms que baja)
                    R.gm('taiko', P_TAIKO, b, st, (48, 48, 45, 45, 43, 43, 41, 41)[st - 8], 2, 70 + 5 * (st - 8))
            continue
        # ── 12/8 ──
        nxt = sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0]
        # EL BAJO (triángulo): pulsos de negra con puntillo, la 5ª y la octava entre medias
        if not (tag == 'intro' and k < 3):
            pat = ((0, 0, 3), (3, 5, 2), (5, 0, 1), (6, 8, 3), (9, 5, 2), (11, 0, 1)) if not stop else ((0, 0, 3), (9, 5, 2), (11, 0, 1))
            for st, deg, d in pat:
                r, q = sg.chord(b, st)
                base = 39 + (r - 39) % 12
                n = base + {0: 0, 5: 7, 8: 12}[deg]
                if st == 11 and nxt[0] != r:                                 # (se acerca a la raíz siguiente por grado)
                    n2 = 39 + (nxt[0] - 39) % 12
                    ap = [p for p in (n2 - 2, n2 - 1, n2 + 2, n2 + 1) if p % 12 in sg.scale and not R.rub(b, st, p, d)]
                    n = ap[0] if ap else n
                R.chip('bass', b, st, n, d, I_TRI, q=q_tri, gate=0.85, release=1)
        # LA KALIMBA: corcheas que suben y bajan por el acorde
        if tag in ('A', 'B') and not stop or (tag == 'intro' and k == 4):
            for st in range(12):
                c = sg.chord(b, st)
                n = place(None, c, 60)[(0, 1, 2, 3, 2, 1)[st % 6]]
                if not R.rub(b, st, n, 1): R.gm('kal', P_KALIMBA, b, st, n, 1, 70 if st % 3 == 0 else 54)
        if tag == 'B' or (tag == 'A' and sg.sidx[b - 1] >= 2):
            for half in (0, 1):
                r, q = sg.chords[b - 1][half]
                base = 53 + (r - 53) % 12
                for j, iv in enumerate(q[1:]):
                    R.chip(('pad1', 'pad2')[j], b, half * 6, base + iv, 6, I_PAD, q=q_n163, gate=0.97, release=6)
        # EL ACENTO: la botella soplada (ave nocturna), 5ª → 3ª, donde la melodía se posa
        if tag in ('A', 'B', 'intro') and not (tag == 'intro' and k < 4):
            if not any(bb == b and st >= 7 for bb, st, n, d in sg.mel):
                r, q = sg.chord(b, 9)
                f5 = 72 + (r + 7 - 72) % 12
                t3 = f5 - 7 + q[1]
                t3 += 12 if t3 < f5 - 7 else 0
                for st, n, d, vv in ((8, f5, 2, 80), (10, t3, 2, 70)):
                    if not R.rub(b, st, n, d): R.gm('accent', P_BOTTLE, b, st, n, d, vv, gate=0.9)
        # LA BATERÍA: la campana 2-2-1-2-2-2-1, congas, cabasa en corcheas, bombo en 1 y 3
        for st in range(12):
            if tag == 'intro' or not stop or st in (0, 9):
                if st in (0, 2, 4, 5, 7, 9, 11) and not (stop and st not in (0, 9)):
                    R.dr('bell', b, st, AGOGO_H if st in (0, 7) else AGOGO_L, (86 if st == 0 else 70) - (10 if tag == 'intro' and k == 1 else 0))
            if tag == 'intro' and k == 1: continue
            if stop:
                if st in (0, 9): R.kick(b, st, 1.0); R.gm('taiko', P_TAIKO, b, st, 41, 3, 104)
                if st in (0, 9): R.dr('congas', b, st, CONGA_L, 96)
                R.dr('shaker', b, st, CABASA, 56 if st % 3 else 70)
                continue
            R.dr('shaker', b, st, CABASA, 56 if st % 3 else 72)
            R.dr('shaker', b, st + 0.5, SHAKER, 34) if tag == 'B' else None
            if st in (1, 4, 7): R.dr('congas', b, st, CONGA_M, 74)
            if st in (3, 10): R.dr('congas', b, st, CONGA_O, 92)
            if st in (9, 11): R.dr('congas', b, st, CONGA_L, 88)
            if tag == 'intro' and k == 2: continue
            if st in (0, 6) or (tag == 'B' and st == 9): R.kick(b, st, 1.0 if st == 0 else 0.85)
            if tag == 'B' and st == 6: R.snare(b, st, 0.75)
            if tag == 'A' and st in (3, 9): R.dr('rim', b, st, RIM, 80)
            if tag == 'B' and st in (2, 5, 8, 11): R.NZ['hat'].hit(sg.t(b, st), 1, HAT)
            if k == 1 and st == 0 and tag != 'intro': R.NZ['crash'].hit(sg.t(b, st), 3, CRASH_N); R.gm('taiko', P_TAIKO, b, st, 41, 3, 108)
            if (k == 5 and st == 0 and tag != 'intro'): R.gm('taiko', P_TAIKO, b, st, 41, 3, 92)
            if last and st >= 9: R.dr('timb', b, st, TIMB_H if st < 11 else TIMB_L, 90 + 4 * (st - 9))
        if 'stop' in var and k == L:                                         # (el último de 'stop' vuelve con todo: redoble)
            for st in range(6, 12): R.dr('timb', b, st, TIMB_H if st < 9 else TIMB_L, 78 + 4 * (st - 6))


def solo_selva(sg, R, b, k):
    """SOLO DE PERCUSIÓN de la jungla (8 compases): 1-2 el TAIKO llama (3+3+2) y las CONGAS contestan · 3-4 los TAMBORES
    DE TRONCO afinados (notas de la tónica) en grupos de 3 contra el surdo en negras · 5-6 todo en 3 contra 4: taiko
    cada 3 semicorcheas, congas y shaker cada 4, bloques de madera · 7 EL RITMO DEL RIFF (2+3+3+3+3+2) golpeado al unísono
    · 8 los surdos y el taiko redoblan y crecen, silbato al final"""
    tones = place(None, sg.tonic, 48)
    for st in range(16):
        R.dr('shaker', b, st, SHAKER, 60 if st % 4 == 2 else 40) if k != 7 else None
        if k in (1, 2):
            if st in (0, 3, 6): R.gm('taiko', P_TAIKO, b, st, 41 if st == 0 else 45, 3, 118 if st == 0 else 100)
            if st in (8, 10, 11, 13, 14): R.dr('congas', b, st, (CONGA_O, CONGA_M, CONGA_O, CONGA_L, CONGA_L)[(8, 10, 11, 13, 14).index(st)], 100)
            if k == 2 and st in (12, 15): R.dr('congas', b, st, BONGO_H, 84)
            if st in (0, 8): R.kick(b, st, 0.8)
        elif k in (3, 4):
            if st % 4 == 0: R.dr('surdo', b, st, SURDO_O if st % 8 == 0 else SURDO_M, 104)
            seq = (0, 2, 4, 3, 2, 1) if k == 3 else (4, 3, 2, 3, 1, 0)
            if st % 3 == 0 and st < 16:
                R.gm('logs', P_LOGDRUM, b, st, tones[seq[(st // 3) % 6]], 2, 104)
            if st in (14, 15) and k == 4: R.dr('congas', b, st, CONGA_O, 90)
        elif k in (5, 6):
            if st % 3 == 0: R.gm('taiko', P_TAIKO, b, st, 45 if (st // 3) % 2 else 41, 2, 98 + (8 if st == 0 else 0))
            if st % 4 == 2: R.dr('congas', b, st, CONGA_O, 96)
            if st % 4 == 3: R.dr('congas', b, st, CONGA_L, 86)
            if st % 2 == 1: R.dr('wood', b, st, WOOD_H if st % 4 == 1 else WOOD_L, 74)
            if st in (0, 8): R.kick(b, st, 0.9)
            if k == 6 and st in (4, 12): R.snare(b, st, 0.8)
        elif k == 7:                                                         # el riff del escarabajo, golpeado
            if st in RIFF_RHYTHM:
                R.kick(b, st, 1.0); R.snare(b, st, 0.9); R.gm('taiko', P_TAIKO, b, st, 41, 2, 120)
                R.dr('congas', b, st, CONGA_L, 110); R.dr('surdo', b, st, SURDO_O, 110)
                R.gm('logs', P_LOGDRUM, b, st, tones[(3, 3, 4, 5, 2, 2)[RIFF_RHYTHM.index(st)]], 2, 110)
        else:
            R.dr('surdo', b, st, SURDO_M if st % 2 else SURDO_O, 60 + 3 * st)
            if st % 2 == 0: R.gm('taiko', P_TAIKO, b, st, 41, 2, 70 + 3 * st)
            if st >= 8: R.snare(b, st, 0.3 + 0.05 * (st - 8))
            if st == 14: R.dr('whistle', b, st, WHISTLE_L, 100, 2)
        if st == 0 and k in (1, 5, 7): R.NZ['crash'].hit(sg.t(b, st), 3, CRASH_N)


def arrange_bonus(sg, R, v):
    for b in range(1, sg.NB + 1):
        tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        for bb, st, n, d in [m for m in sg.mel if m[0] == b]:
            R.chip('lead', b, st, n, d, I_PULSE, release=3)
            R.gm('lead2', P_MARIMBA, b, st, n - 12, min(d, 3), 84)                 # (la marimba una octava abajo: el golpe)
            if 'dbl' in var and n + 12 <= 96: R.chip('dbl', b, st, n + 12, d, I_DBL, release=2)
    for b in range(1, sg.NB + 1):
        tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
        last = k == L
        if tag == 'solo':
            solo_selva(sg, R, b, k)
            R.chip('bass', b, 0, 44, 16, I_TRI, q=q_tri, gate=0.5, release=1) if k in (1, 5) else None
            continue
        nxt = sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0]
        # BAJO: corcheas con octavas
        if not (tag == 'intro' and k < 3):
            for st in range(0, 16, 2):
                r, q = sg.chord(b, st)
                base = 44 + (r - 44) % 12 - (12 if (r - 44) % 12 > 6 else 0)
                n = base + (12 if st % 4 == 2 else 0)
                if st == 14 and nxt[0] != r:
                    n2 = 44 + (nxt[0] - 44) % 12 - (12 if (nxt[0] - 44) % 12 > 6 else 0)
                    ap = [p for p in (n2 - 2, n2 - 1, n2 + 2) if p % 12 in sg.scale | sg.tones(b, 14) and not R.rub(b, 14, p, 2)]
                    n = ap[0] if ap else n
                R.chip('bass', b, st, n, 2, I_TRI, q=q_tri, gate=0.8, release=1)
        # MARIMBA: golpes de acorde a contratiempo; KALIMBA en B
        if tag in ('A', 'B') or (tag == 'intro' and k == 4):
            for st in (2, 6, 10, 14):
                c = sg.chord(b, st)
                for n in place(None, c, 60)[1:3]:
                    if not R.rub(b, st, n, 2): R.gm('marimba', P_MARIMBA, b, st, n, 2, 74)
        if tag == 'B':
            for half in (0, 1):
                r, q = sg.chords[b - 1][half]
                base = 53 + (r - 53) % 12
                for j, iv in enumerate(q[1:]):
                    R.chip(('pad1', 'pad2')[j], b, half * 8, base + iv, 8, I_PAD, q=q_n163, gate=0.97, release=6)
            for st in range(0, 16, 2):
                c = sg.chord(b, st)
                n = place(None, c, 72)[(0, 1, 2, 3, 2, 1, 2, 3)[st // 2]]
                if not R.rub(b, st, n, 1): R.gm('kal', P_KALIMBA, b, st, n, 1, 58)
        if tag in ('A', 'B'): toucan(sg, R, b, 70)
        # BATERÍA DE COMPETICIÓN
        for st in range(16):
            if tag == 'intro':
                if st % 4 == 0: R.gm('taiko', P_TAIKO, b, st, 41, 2, 80 + 8 * k)
                if k >= 2: R.dr('shaker', b, st, SHAKER, 56 if st % 2 else 40)
                if k >= 3 and st % 4 == 0: R.kick(b, st, 0.9)
                if k >= 3 and st in (6, 14): R.dr('surdo', b, st, SURDO_M, 84)
                if k == 2 and st == 0: R.dr('whistle', b, st, WHISTLE_S, 90)
                if k == 4 and st in (8, 12): R.dr('whistle', b, st, WHISTLE_S if st == 8 else WHISTLE_L, 100, 2 if st == 8 else 3)
                if k == 4 and st >= 12: R.dr('timb', b, st, TIMB_H if st < 14 else TIMB_L, 96)
                continue
            if st % 4 == 0: R.kick(b, st, 1.0 if st % 8 == 0 else 0.9)
            if st in (4, 12): R.snare(b, st, 0.9)
            if st in (6, 14): R.dr('surdo', b, st, SURDO_O, 92)
            if st in (3, 10, 11): R.dr('congas', b, st, (CONGA_O, CONGA_O, CONGA_L)[(3, 10, 11).index(st)], 90)
            if st in (7, 15): R.dr('congas', b, st, CONGA_M, 70)
            R.dr('shaker', b, st, SHAKER, 64 if st % 4 == 2 else 42)
            if st % 4 == 2: R.NZ['hat'].hit(sg.t(b, st), 1, HAT)
            if st == 0 and k in (1, 5): R.NZ['crash'].hit(sg.t(b, st), 3, CRASH_N); R.gm('taiko', P_TAIKO, b, st, 41, 3, 110)
            if (b + 1 < sg.NB + 1 and sg.tag[b] == 'solo' or last) and st >= 12:
                R.dr('timb', b, st, TIMB_H if st < 14 else TIMB_L, 96 + 3 * (st - 12))


ARRANGE = {'jungla_1': arrange_j1, 'jungla_2': arrange_j2, 'jungla_bonus': arrange_bonus}
# niveles (dB, RMS mientras suena) respecto a la melodía; la casa sube el acompañamiento (BACKING) para el juego
LV = {
    'jungla_1': {'lead': 0, 'dbl': -10, 'cm': -6, 'thirds': -5, 'riff': -3, 'bass': 2, 'marimba': -2, 'kal': -7, 'pad': -9,
                 'accent': -5, 'kick': 3, 'snare': 0, 'rim': -4, 'congas': -1, 'shaker': -8, 'hat': -9, 'crash': -7,
                 'taiko': 1, 'timb': -3, 'wood': -4},
    'jungla_2': {'lead': 0, 'lead2': -9, 'dbl': -10, 'riff': -1, 'bass': 4, 'kal': -3, 'pad': -7, 'accent': -4,
                 'kick': 5, 'snare': 2, 'rim': -2, 'congas': 1, 'shaker': -6, 'bell': -3, 'hat': -7, 'crash': -5,
                 'taiko': 3, 'timb': -1},
    'jungla_bonus': {'lead': 0, 'lead2': -7, 'dbl': -10, 'bass': 2, 'marimba': -4, 'kal': -8, 'pad': -9,
                     'kick': 1, 'snare': 1, 'congas': 0, 'shaker': -7, 'hat': -9, 'crash': -6, 'taiko': 0, 'timb': -2,
                     'surdo': -3, 'logs': 0, 'wood': -3, 'whistle': -6, 'accent': -5},
}


def build(track, v):
    sg = Song(track, v)
    R = Rig(sg)
    ARRANGE[track](sg, R, v)
    n = int(sg.NB * sg.BAR * SR)
    at = int(sg.INTRO * sg.BAR * SR)
    L = n + 3 * SR
    cut = lambda x: x[:L] - np.mean(x[:n])
    base = F.tnd_dac(np.full(R.NS, 64 / 22638.0))
    S = {}
    lead_chip = cut(F.render_wave(R.Cn['lead'], WAVES) * 0.0075) if (track == 'jungla_1') else cut(F.pulse_dac(F.render_pulse(R.Cn['lead'])))
    gm_lead = {k: GM.cached(R.G[k], L) for k in R.G}
    if track == 'jungla_1' and v == 'B':
        S['lead'] = gm_lead.pop('lead') + 0.35 * lead_chip
    elif track == 'jungla_2' and v == 'B':
        S['lead'] = gm_lead.pop('lead')
    else:
        S['lead'] = lead_chip
    S.update(gm_lead)
    S.update({k: GM.cached(R.D[k], L) for k in R.D})
    S.update({'dbl': cut(F.pulse_dac(F.render_pulse(R.Cn['dbl']))),
              'cm': cut(F.render_wave(R.Cn['cm'], WAVES) * 0.0075),
              'pad': cut(F.render_wave(R.Cn['pad1'], WAVES) * 0.0075) + cut(F.render_wave(R.Cn['pad2'], WAVES) * 0.0075),
              'bass': cut(F.tnd_dac(F.render_tri(R.Cn['bass']) / 8227.0)),
              'kick': cut(F.tnd_dac((R.dk + 64) / 22638.0) - base),
              'snare': cut(F.tnd_dac((R.sn + 64) / 22638.0) - base) + cut(F.tnd_dac(R.NZ['snare'].render() / 22638.0 * 12)),
              'hat': cut(F.tnd_dac(R.NZ['hat'].render() / 22638.0 * 12)),
              'crash': cut(F.tnd_dac(R.NZ['crash'].render() / 22638.0 * 12))})
    from scipy.signal import butter, sosfilt
    hp = butter(2, 30, btype='high', fs=SR, output='sos')
    S = {k: sosfilt(hp, GN.fold(x, n, at)) for k, x in S.items() if np.abs(x).max() > 0}
    if track == 'jungla_1':                                              # (un eco corto en la flauta: el aire de la selva)
        S['lead'] = GN.delay(S['lead'], 3 * 60.0 / sg.bpm / 4, 0.22, 2, 3200)[:len(S['lead'])]
    up = 1.0 if (track, v) == ('jungla_1', 'B') else 0.0                   # (dos flautas: el resto, 1 dB más arriba)
    g = GN.level(S, {k: LV[track].get(k, -10) + (0 if k in LEAD_KEYS else up) for k in S}, 'lead')
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('marimba', 0.3) - sd('kal', 0.4) + sd('shaker', 0.4) - sd('congas', 0.2) + sd('hat', 0.3) - sd('pad', 0.2) \
        + sd('accent', 0.35) - sd('bell', 0.3) + sd('thirds', 0.2) - sd('lead2', 0.25) + sd('wood', 0.3) - sd('cm', 0.15)
    y = F.master(np.stack([x + side, x - side], 1), lufs=TRACKS[track]['lufs'])
    return sg, R, S, g, y, n, at


def report(track, v, sg, R, S, g, y, n, at):
    lab = track + (f' variante {v} "{TRACKS[track]["vname"][v]}"' if v else '')
    print(f'── {lab}')
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    print(f'  {sg.bpm} BPM, {sg.NB} compases: intro {sg.INTRO * sg.BAR:.1f} s + bucle {(sg.NB - sg.INTRO) * sg.BAR:.1f} s; '
          f'{F.loudness(y):.1f} LUFS, pico {np.abs(y).max():.2f}')
    print(f'  energía: melodía {grp(LEAD_KEYS):.0f} % (con dobles {grp(LEAD_KEYS + ("lead2", "dbl")):.0f} %), batería {grp(DRUM_KEYS):.0f} %, '
          f'bajo {grp(("bass",)):.0f} %, acompañamiento {grp(("marimba", "kal", "pad", "cm", "riff")):.0f} %, acento {grp(("accent",)):.1f} %')
    print('  ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    lb, lo, out, off = check(sg)
    print(f'  melodía: {len(sg.mel)} notas, ámbito {nm(min(m[2] for m in sg.mel))}-{nm(max(m[2] for m in sg.mel))}, '
          f'a contratiempo {100 * off:.0f} %; largas fuera del acorde: {lb or "ninguna"}; sueltas: {lo or "ninguna"}; '
          f'fuera de la escala: {out or "ninguna"}')
    for k in ('bass', 'marimba', 'kal', 'cm', 'thirds', 'riff', 'accent', 'pad1'):
        if k in R.notes:
            cl = clashes(sg, sg.mel, R.notes[k])
            if cl: print(f'  choques melodía / {k} (≥ corchea): {len(cl)} {cl[:6]}')
    if 'thirds' in R.notes:
        lb2, lo2, out2, _ = check(sg, sorted((int(q0 // 16) + 1, int(q0 % 16), nn, int(round(q1 - q0))) for q0, q1, nn in R.notes['thirds']))
        print(f'  2ª flauta (terceras): largas fuera del acorde {lb2 or "ninguna"}, fuera de escala {out2 or "ninguna"}')
    bad = [(b, st, nm(nn)) for (q0, q1, nn) in R.notes.get('bass', []) for b, st in [(int(q0 // 16) + 1, q0 % 16)]
           if q1 - q0 >= 3 and (nn - sg.chord(b, st * sg.steps[b - 1] / 16)[0]) % 12 not in (0, 7)]
    print(f'  bajo: {len(R.notes.get("bass", []))} notas; largas que no son raíz ni 5ª: {bad or "ninguna"}')
    ov, who, mean = attack_overlap(sg)
    print(f'  frase A: golpes compartidos con otras islas — máx. {100 * ov:.0f} % ({who}), media {100 * mean:.0f} %')
    secs = []
    for i, b0 in enumerate(sg.starts):
        tsec = (b0 - 1) * sg.BAR
        secs.append(f'{sg.tag[b0 - 1]}{"·" + sg.var[b0 - 1] if sg.var[b0 - 1] else ""} {int(tsec // 60)}:{tsec % 60:04.1f}')
    print('  secciones (desde el principio de la intro): ' + ' | '.join(secs))
    def last_note(b):
        ms = [m for m in sg.mel if m[0] <= b]
        return f'{nm(ms[-1][2])}' if ms and ms[-1][0] >= b - 1 else '—'
    def first_note(b):
        ms = [m for m in sg.mel if m[0] >= b]
        return f'{nm(ms[0][2])}@{ms[0][1]}' if ms and ms[0][0] <= b + 1 else '—'
    cn = lambda c: NAMES[c[0]] + ('m' if c[1] == MIN else '')
    seams = [(b0 - 1, b0) for b0 in sg.starts[2:]] + [(sg.NB, sg.INTRO + 1)]
    print('  costuras (compás: acorde, última nota → acorde, primera nota): ' + ' | '.join(
        f'{a}→{c}: {cn(sg.chords[a - 1][1])} {last_note(a)} → {cn(sg.chords[c - 1][0])} {first_note(c)}' for a, c in seams))
    span = lambda b0, L_: (int((b0 - 1) * sg.BAR * SR), int((b0 - 1 + L_) * sg.BAR * SR))
    def db(a, b_):
        z = sum(S[k][a:b_] * g[k] for k in S)
        return 10 * np.log10(np.mean(np.asarray(z) ** 2) + 1e-12)
    ref = db(*span(sg.starts[1], sg.slen[sg.starts[1] - 1]))
    print('  sonoridad por sección vs la 1ª A (dB): ' + ' '.join(f'{sg.tag[b0 - 1]} {db(*span(b0, sg.slen[b0 - 1])) - ref:+.1f}' for b0 in sg.starts))
    return dict(lb=lb, lo=lo, out=out, off=off)


def write_mid(path, sg, R):
    """la melodía (canal 0) y el bajo (canal 1), con la rejilla de cada compás; tempo = el pulso (negra o negra con puntillo)"""
    import mido
    mid = mido.MidiFile(ticks_per_beat=480)
    tr = mido.MidiTrack(); mid.tracks.append(tr)
    tr.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / sg.bpm), time=0))
    ev = []
    for b, st, n, d in sg.mel:
        t0 = int(round(sg.q(b, st) * 120)); t1 = int(round(sg.q(b, st + d) * 120)) - 10
        ev += [(t0, 1, n, 0), (t1, 0, n, 0)]
    for q0, q1, n in R.notes.get('bass', []):
        ev += [(int(round(q0 * 120)), 1, n, 1), (int(round(q1 * 120)) - 10, 0, n, 1)]
    t = 0
    for tt, on, n, c in sorted(ev, key=lambda e: (e[0], e[1])):
        tr.append(mido.Message('note_on' if on else 'note_off', channel=c, note=n, velocity=96, time=tt - t)); t = tt
    mid.save(path)


def enc(x, ogg):
    wav = ogg[:-4] + '.wav'
    F.write_wav(wav, x)
    os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"')
    os.remove(wav)


def export(y, at, base):
    """<base>_intro.ogg (una vez; sus últimos 6 ms se apagan) + <base>_loop.ogg — como GN.export, a cualquier carpeta"""
    a = y[:at].copy()
    k = int(0.006 * SR)
    a[-k:] = a[-k:] * np.linspace(1, 0, k)[:, None]
    enc(a, base + '_intro.ogg')
    enc(y[at:], base + '_loop.ogg')


if __name__ == '__main__':
    which = [a for a in sys.argv[1:] if a in TRACKS] or list(TRACKS)
    os.makedirs(PRUEBAS, exist_ok=True)
    for track in which:
        for v in TRACKS[track]['variants']:
            if os.environ.get('INSTALL') and v and os.environ.get(track.upper(), 'A') != v: continue
            sg, R, S, g, y, n, at = build(track, v)
            report(track, v, sg, R, S, g, y, n, at)
            if os.environ.get('REPORT'): continue
            name = track + (f'_{v}_{TRACKS[track]["vname"][v]}' if v else '')
            base = os.path.join(PRUEBAS, name)
            export(y, at, base)
            enc(np.concatenate([y, y[at:]]), base + '_preview.ogg')
            write_mid(base + '.mid', sg, R)
            if os.environ.get('INSTALL'):
                os.makedirs(INSTALL_DIR, exist_ok=True)
                export(y, at, os.path.join(INSTALL_DIR, track))
                write_mid(F.out(track, 'mid'), sg, R)
                print(f'  instalada: {INSTALL_DIR}/{track}_intro|_loop.ogg')
    if not os.environ.get('REPORT'): print(f'  previas en {PRUEBAS}')
