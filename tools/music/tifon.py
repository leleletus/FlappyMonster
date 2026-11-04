#!/usr/bin/env python3
# tools/music/tifon.py — "TIFÓN": tema de jefe ORIGINAL para la Ráfaga Suprema (jefe secreto de la isla de la FORTALEZA:
# una nube de tormenta gigante, la Ráfaga pequeña crecida al tocar una astilla mágica). La pelea es en los TEJADOS de la
# fortaleza, bajo un cielo abierto de tormenta, entre chimeneas, cajas sueltas y bombas. PREVIAS para que el usuario
# elija; no toca assets/ ni el index.json. Compuesto desde cero. Se comprueba con números: NO SE HA ESCUCHADO.
#
# LA IDEA: la fortaleza es Do menor, marcha, sierra del VRC6 y redobles de caja, y su motivo es una fanfarria de
# tresillos. La tormenta llega a ese tejado y lo hace girar:
#   · EL RITMO que el juego no tenía: LA RÁFAGA, 3+3+4+3+3 en un compás de 4/4 (golpes en 0 3 6 10 13). Es un palíndromo:
#     el viento entra (3+3), se queda arriba (4) y sale (3+3) — inspira y sopla, como el jefe. Lo tocan juntos el slap,
#     el bombo y la melodía (el ritmo de la melodía ES el del acompañamiento).
#   · EL SOPLIDO cambia la subdivisión sin cambiar el pulso: las secciones de viento (intro, S, R) van en TRESILLOS
#     (12 pasos por compás, el compás dura lo mismo) — el remolino; la fanfarria de tresillos de la fortaleza vive ahí.
#   · Re menor (la fortaleza baja un tono hacia el cielo: otro color que Do menor sin dejar de ser la isla), con una
#     dominante mayor de verdad (La mayor, Do#). GIRO OSCURO (uno): Si♭ MENOR → La (el ♭vi menor prestado: Re♭ = Do#,
#     las tres voces bajan medio tono o se quedan; el ojo de la tormenta).
#   · LA LLAMADA (La-Re-Fa-La), en la fanfarria de tresillos de la intro y de la vuelta R.
#   · EL ACENTO propio, melódico: EL RELÁMPAGO — cuatro notas del acorde en zigzag hacia abajo (vibráfono, flojo), donde
#     la melodía se posa; el trueno (timbal y plato) cae en el tiempo 1 siguiente: primero la marca, luego el golpe.
#
# LA FORMA CUENTA LA PELEA:
#   INTRO 8 (tresillos) la tormenta se junta: viento, redoble de timbal, la fanfarria de la llamada.
#   A 16    el tema, en la ráfaga.
#   S 8     EL SOPLIDO (tresillos): un compás de AVISO (redoble que crece, cuerdas que suben; el aviso del jefe dura 1 s)
#           y siete de viento: arpegios de remolino que cruzan de un lado al otro, el viento GM debajo.
#   B 16    la voz baja, poca banda; el giro oscuro (Si♭m → La). Los dos últimos compases: LA INHALACIÓN — la banda se calla,
#           platillo al revés, viento y redoble que crecen… y la BOMBA explota dentro: el golpe del estribillo.
#   C 16    el estribillo, lo más alto: relámpagos al final de cada frase, coro y trémolo.
#   H 8     EL GRANIZO: sin melodía; xilófono y pizzicato que repiquetean, metal de ruido, solo de slap, truenos.
#   C' 8    la FASE 2: el jefe gira — el remolino cambia de sentido a mitad de compás (de izquierda a derecha y de vuelta),
#           la melodía doblada a la octava.
#   R 4     (tresillos) vuelve la fanfarria con la llamada; acaba igual que la intro (la costura es la misma entrada).
#   = 8 + 76 compases a 160 BPM (compás de 1,5 s justos = 66 150 muestras): 12 s de intro + bucle de 114 s.
#
# TRES VARIANTES (misma armonía, forma y banda; OTRA MELODÍA y otra voz):
#   A "remolino"  melodía-riff en la SIERRA del VRC6: cada compás la misma figura de la ráfaga — salta, baja por grado y
#                 vuelve a subir, como una racha que da la vuelta —, movida por la armonía y cada vez más arriba.
#   B "vendaval"  cantada en el PULSO del 2A03 (barrido de ciclo, voz hueca del N163 al unísono): corcheas que van por
#                 grados con anticipaciones, frases de dos compases que preguntan y se contestan en secuencia.
#   C "granizo"   XILÓFONO GM con la sierra una octava abajo: notas repetidas que repiquetean como el granizo y se paran
#                 en una larga redoblada; la frase siguiente la contesta (la idea de instrumento: el xilófono redobla).
#
#   ~/.venvs/fm-music/bin/python tools/music/tifon.py [A B C] → previas en FlappyMonster_pruebas/musica/tifon/
#   INSTALL=1 [TIFON=B] → assets/music/bosses/tifon_intro|_loop.ogg (la elegida: B "vendaval", 2026-11-04)
#   MELODIA=1 → solo los números de las melodías (sin tocar nada) · REPORT=1 → números con la mezcla, sin escribir
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

CH, place, nm = M.CH, M.place, J.nm
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/tifon'
TRACK = 'tifon'
BPM, LUFS, CEILING = 160, -10.5, 0.70
VNAME = {'A': 'remolino', 'B': 'vendaval', 'C': 'granizo'}
SCALE = {2, 4, 5, 7, 9, 10, 0}                                       # Re menor natural (Do# solo en su La mayor; Re♭ solo en Si♭m)
RAFAGA = (0, 3, 6, 10, 13)                                           # LA RÁFAGA: 3+3+4+3+3

# ══ LA ARMONÍA (la misma en las tres) ═══════════════════════════════════════════════════════════════════════════════
H_IN = "Dm Dm Dm Dm Bb C A A"
H_A = "Dm Bb F C Dm Bb Gm A " + "Dm Bb F C Gm Dm Gm|A Dm"            # i VI III VII · i VI iv V
H_S = "Bb C Dm Dm Bb C A A"
H_B = "Gm Dm Bb F Gm Dm Bbm A " + "Gm Dm Bb F Gm C A A"              # el GIRO OSCURO: Si♭m → La · 15-16: la inhalación
H_C = "Bb F C Dm Bb F Gm A " + "Bb F C Dm Gm Bb A Dm"                # el estribillo arranca en el VI (tras la bomba)
H_H = "Dm Dm C C Bb Bb A A"
H_C2 = "Bb F C Dm Gm Bb A A"
H_R = "Dm Dm A A"

# ══ LA FANFARRIA de la intro y de la R (la misma en las tres; tresillos: 12 pasos, pulsos en 0 3 6 9) ════════════════
FAN_CALL = "0:A4/3 3:D5/2 5:F5/1 6:A5/6"                             # LA LLAMADA: La-Re-Fa-La, largo-corto-corto-larguísimo
FAN_ANS = "0:G5/2 2:F5/1 3:E5/2 5:F5/1 6:D5/6"                       # (y se posa)
FAN_DOM = "0:C#5/3 3:E5/3 6:A5/6"
FAN_END = "0:E5/2 2:A5/1 3:C#6/3"                                    # el compás final: sube, y la banda pica tres veces
IN_MEL = ['', '', FAN_CALL, FAN_ANS, "0:D5/3 3:F5/3 6:Bb5/6", "0:E5/3 3:G5/3 6:C6/6", FAN_DOM, FAN_END]
R_MEL = [FAN_CALL, FAN_ANS, FAN_DOM, FAN_END]

# ══ LAS MELODÍAS: 'paso:Nota/duración' (16 semicorcheas; en S, 12 tresillos) ═══════════════════════════════════════
MEL = {
    # A "remolino": la ráfaga — salta, baja por grado, vuelve a subir; el compás par cae; cada dos, se posa y contesta el
    # relámpago. En el 7 la figura va a la cima.
    'A': {'A': ["0:D5/3 3:A5/3 6:A5/2 8:G5/2 10:F5/3 13:A5/3",            # Rem
                "0:Bb5/3 3:A5/2 5:G5/1 6:F5/4 10:D5/3 13:F5/3",                  # Si♭
                "0:F5/3 3:C6/3 6:C6/2 8:Bb5/2 10:A5/2 12:Bb5/1 13:C6/3",         # Fa: la misma figura, más arriba
                "0:E6/3 3:D6/2 5:C6/1 6:G5/6",                                   # Do: se posa (el relámpago)
                "0:D5/3 3:A5/3 6:A5/2 8:G5/2 10:F5/3 13:A5/3",
                "0:D6/3 3:C6/2 5:Bb5/1 6:F5/4 10:G5/2 12:A5/1 13:Bb5/3",
                "0:G5/3 3:D6/3 6:D6/2 8:C6/2 10:Bb5/2 12:C6/1 13:D6/3",          # Solm: la cima de la frase
                "0:E6/3 3:D6/2 5:C#6/1 6:A5/6",                                  # La
                "0:D5/3 3:A5/3 6:A5/2 8:G5/2 10:F5/3 13:A5/3",
                "0:Bb5/3 3:A5/2 5:G5/1 6:F5/4 10:D5/3 13:F5/3",
                "0:C6/3 3:F6/3 6:F6/2 8:E6/2 10:D6/2 12:E6/1 13:F6/3",           # una octava más arriba
                "0:E6/3 3:D6/2 5:C6/1 6:G5/4 10:A5/2 12:Bb5/1 13:C6/3",
                "0:D6/3 3:Bb5/3 6:Bb5/2 8:A5/2 10:G5/3 13:Bb5/3",
                "0:A5/3 3:F5/3 6:F5/2 8:E5/2 10:D5/3 13:F5/3",
                "0:G5/3 3:Bb5/3 6:D6/2 8:C#6/3 11:E6/2 13:A6/3",                 # Solm|La: sube a la dominante
                "0:F6/3 3:E6/2 5:D6/1 6:A5/6"],
          # S: EL SOPLIDO en tresillos — tres que suben y la larga; el aviso, en silencio
          'S': ["9:D5/1 10:E5/1 11:F5/1", "0:G5/6 6:E5/2 8:G5/1 9:C6/3",
                "0:D5/1 1:F5/1 2:A5/1 3:D6/6 9:A5/3", "0:F6/3 3:E6/2 5:D6/1 6:A5/6",
                "0:Bb4/1 1:D5/1 2:F5/1 3:Bb5/6 9:F5/3", "0:C5/1 1:E5/1 2:G5/1 3:C6/6 9:E6/3",
                "0:E6/6 6:C#6/3 9:A5/3", "0:E6/6 6:C#6/2 8:A5/1 9:E5/3"],
          # B: la voz baja; una larga, dos que caminan y dos de la ráfaga
          'B': ["0:D5/6 6:Bb4/2 8:C5/2 10:D5/3 13:G5/3", "0:F5/6 6:E5/2 8:D5/2 10:A4/3 13:D5/3",
                "0:F5/6 6:G5/2 8:A5/2 10:Bb5/3 13:D6/3", "0:C6/6 6:A5/2 8:F5/6",
                "0:D5/6 6:Bb4/2 8:C5/2 10:D5/3 13:G5/3", "0:A5/6 6:G5/2 8:F5/2 10:E5/1 11:F5/2 13:A5/3",
                "0:Db6/6 6:C6/2 8:Bb5/2 10:F5/3 13:Bb5/3",                       # el Re♭ de Si♭m
                "0:C#6/6 6:D6/1 7:C#6/1 8:A5/6",
                "0:D5/6 6:Bb4/2 8:C5/2 10:D5/3 13:G5/3", "0:F5/6 6:E5/2 8:D5/2 10:A4/3 13:D5/3",
                "0:F5/6 6:G5/2 8:A5/2 10:Bb5/3 13:D6/3", "0:F6/6 6:E6/1 7:D6/1 8:C6/2 10:A5/3 13:C6/3",
                "0:D6/6 6:C6/2 8:Bb5/2 10:G5/3 13:Bb5/3", "0:C6/6 6:D6/2 8:E6/2 10:G6/3 13:E6/3",
                "0:E6/8", ""],                                                    # (la inhalación)
          # C: el ESTRIBILLO — la ráfaga con la nota repetida (los golpes del rayo), arriba
          'C': ["0:F6/3 3:F6/3 6:D6/4 10:C6/1 11:D6/2 13:F6/3", "0:A6/3 3:A6/3 6:F6/4 10:E6/1 11:F6/2 13:A6/3",
                "0:G6/3 3:G6/3 6:E6/4 10:D6/1 11:E6/2 13:G6/3", "0:A6/3 3:F6/2 5:E6/1 6:D6/6",
                "0:F6/3 3:F6/3 6:D6/4 10:C6/1 11:D6/2 13:F6/3", "0:C6/3 3:F6/3 6:A6/4 10:G6/1 11:A6/2 13:F6/3",
                "0:G6/3 3:Bb6/3 6:G6/4 10:F6/1 11:G6/2 13:D6/3", "0:C#6/3 3:E6/3 6:A6/6",
                "0:F6/3 3:F6/3 6:D6/4 10:C6/1 11:D6/2 13:F6/3", "0:A6/3 3:A6/3 6:F6/4 10:E6/1 11:F6/2 13:A6/3",
                "0:G6/3 3:G6/3 6:E6/4 10:D6/1 11:E6/2 13:G6/3", "0:A6/3 3:F6/2 5:E6/1 6:D6/6",
                "0:Bb6/3 3:A6/2 5:G6/1 6:D6/4 10:E6/1 11:F6/2 13:G6/3", "0:F6/3 3:D6/3 6:Bb5/4 10:C6/1 11:D6/2 13:F6/3",
                "0:E6/3 3:E6/3 6:C#6/4 10:D6/1 11:C#6/2 13:E6/3", "0:D6/6"]},
    # B "vendaval": corcheas cantadas, por grados, con anticipaciones (la respuesta entra tarde, en el 2); pregunta de dos
    # compases y respuesta en secuencia; el estribillo, en el tresillo 3+3+2 de la casa
    'B': {'A': ["0:A4/2 2:D5/2 4:E5/2 6:F5/4 10:E5/2 12:D5/2 14:F5/4",
                "2:G5/2 4:F5/2 6:D5/4 10:Bb4/4 14:C5/2",
                "0:C5/2 2:F5/2 4:G5/2 6:A5/4 10:G5/2 12:F5/2 14:A5/2",           # la pregunta, una 3ª más arriba
                "2:Bb5/2 4:A5/2 6:G5/4 10:E5/4 14:G5/2",
                "0:A5/2 2:D6/2 4:E6/2 6:F6/4 10:E6/2 12:D6/2 14:A5/2",           # … y una octava
                "2:Bb5/2 4:C6/2 6:D6/4 10:F6/4 14:D6/2",
                "0:D6/2 2:Bb5/2 4:C6/2 6:D6/4 10:G6/2 12:F6/2 14:E6/2",
                "0:E6/6 6:C#6/4 10:A5/6",
                "0:A4/2 2:D5/2 4:E5/2 6:F5/4 10:E5/2 12:D5/2 14:F5/4",
                "2:G5/2 4:F5/2 6:D5/4 10:Bb4/4 14:F5/2",
                "0:C6/2 2:F6/2 4:G6/2 6:A6/4 10:G6/2 12:F6/2 14:C6/4",
                "2:D6/2 4:E6/2 6:G6/4 10:E6/4 14:D6/2",
                "0:D6/6 6:C6/2 8:Bb5/2 10:A5/2 12:G5/4",
                "2:A5/2 4:G5/2 6:F5/4 10:E5/2 12:D5/2 14:F5/2",
                "0:G5/2 2:Bb5/2 4:D6/2 6:Bb5/2 8:A5/2 10:C#6/2 12:E6/4",
                "0:D6/6 6:A5/2 8:F5/2 10:E5/2 12:D5/4"],
          'S': ["9:F5/3", "0:G5/6 6:C6/3 9:E6/3", "0:F6/6 6:D6/3 9:A5/3", "0:D6/3 3:E6/2 5:F6/1 6:A6/6",
                "0:F6/6 6:D6/3 9:Bb5/3", "0:C6/3 3:D6/2 5:E6/1 6:G6/6", "0:E6/6 6:C#6/3 9:A5/3", "0:E6/6 6:C#6/2 8:A5/1 9:E5/3"],
          'B': ["0:G4/4 4:Bb4/2 6:D5/4 10:C5/2 12:Bb4/2 14:A4/2", "0:A4/6 6:F4/2 8:D5/6 14:C5/2",
                "0:Bb4/4 4:D5/2 6:F5/4 10:G5/2 12:F5/2 14:D5/2", "0:C5/6 6:A4/2 8:F4/6",
                "0:G4/4 4:Bb4/2 6:D5/4 10:C5/2 12:Bb4/2 14:D5/2", "0:F5/6 6:E5/2 8:D5/4 12:A4/4",
                "0:F5/4 4:Db5/2 6:F5/4 10:Bb5/2 12:Db6/4",                       # Si♭m
                "0:C#6/6 6:A5/2 8:E5/6",
                "0:G5/4 4:Bb5/2 6:D6/4 10:C6/2 12:Bb5/2 14:A5/2", "0:A5/6 6:F5/2 8:D6/6 14:C6/2",
                "0:Bb5/4 4:D6/2 6:F6/4 10:G6/2 12:F6/2 14:D6/2", "0:C6/6 6:A5/2 8:F5/6",
                "0:D6/4 4:Bb5/2 6:G5/4 10:A5/2 12:Bb5/2 14:C6/2", "0:C6/4 4:E6/2 6:G6/4 10:F6/2 12:E6/2 14:D6/2",
                "0:E6/8", ""],
          'C': ["0:F6/3 3:D6/3 6:Bb6/6 12:A6/2 14:G6/2", "0:A6/3 3:F6/3 6:C6/6 12:D6/2 14:E6/2",
                "0:E6/3 3:G6/3 6:C6/6 12:D6/2 14:E6/2", "0:F6/3 3:A6/3 6:D6/6",
                "0:F6/3 3:D6/3 6:Bb6/6 12:A6/2 14:G6/2", "0:A6/3 3:F6/3 6:A6/6 12:G6/2 14:F6/2",
                "0:G6/3 3:Bb6/3 6:G6/6 12:D6/4", "0:E6/3 3:C#6/3 6:A5/6",
                "0:F6/3 3:D6/3 6:Bb6/6 12:A6/2 14:G6/2", "0:A6/3 3:F6/3 6:C6/6 12:D6/2 14:E6/2",
                "0:E6/3 3:G6/3 6:C6/6 12:D6/2 14:E6/2", "0:F6/3 3:A6/3 6:D6/6",
                "0:Bb6/3 3:G6/3 6:D6/6 12:E6/2 14:F6/2", "0:F6/3 3:D6/3 6:Bb6/6 12:A6/2 14:G6/2",
                "0:A6/3 3:E6/3 6:C#6/6", "0:D6/8"]},
    # C "granizo": dos golpes repetidos que repiquetean y saltan (ta-ta-TAA), y una larga redoblada; la frase siguiente contesta
    'C': {'A': ["0:A5/2 2:A5/1 3:F5/3 6:A5/4 10:G5/2 12:A5/1 13:D6/3",
                "0:D6/2 2:D6/1 3:Bb5/3 6:D6/4 10:C6/2 12:Bb5/1 13:F5/3",
                "0:C6/2 2:C6/1 3:A5/3 6:C6/4 10:Bb5/2 12:A5/1 13:F5/3",
                "0:E6/8 8:G5/2 10:C6/6",
                "0:A5/2 2:A5/1 3:F5/3 6:A5/4 10:G5/2 12:A5/1 13:D6/3",
                "0:F6/2 2:F6/1 3:D6/3 6:F6/4 10:D6/2 12:C6/1 13:Bb5/3",
                "0:G6/2 2:G6/1 3:D6/3 6:G6/4 10:F6/2 12:E6/1 13:D6/3",
                "0:E6/10 10:C#6/2 12:A5/4",
                "0:A5/2 2:A5/1 3:F5/3 6:A5/4 10:G5/2 12:A5/1 13:D6/3",
                "0:D6/2 2:D6/1 3:Bb5/3 6:D6/4 10:C6/2 12:Bb5/1 13:F5/3",
                "0:F6/2 2:F6/1 3:C6/3 6:F6/4 10:E6/2 12:D6/1 13:C6/3",
                "0:G6/8 8:E6/2 10:C6/6",
                "0:D6/2 2:D6/1 3:Bb5/3 6:D6/4 10:C6/2 12:Bb5/1 13:G5/3",
                "0:F5/2 2:F5/1 3:A5/3 6:F5/4 10:E5/2 12:F5/1 13:D5/3",
                "0:Bb5/2 2:Bb5/1 3:G5/3 6:D6/2 8:A5/2 10:C#6/2 12:E6/4",
                "0:D6/10 10:A5/2 12:F5/4"],
          'S': ["9:D5/1 10:D5/1 11:F5/1", "0:G5/6 6:E5/1 7:E5/1 8:G5/1 9:C6/3", "0:D6/6 6:A5/1 7:A5/1 8:F5/1 9:D6/3",
                "0:F6/9 9:E6/1 10:D6/1 11:E6/1", "0:F6/6 6:D6/1 7:D6/1 8:F6/1 9:Bb5/3", "0:G6/6 6:E6/1 7:E6/1 8:G6/1 9:C6/3",
                "0:E6/6 6:C#6/1 7:C#6/1 8:E6/1 9:A5/3", "0:E6/6 6:C#6/2 8:A5/1 9:E5/3"],
          'B': ["0:D5/2 2:D5/1 3:Bb4/3 6:D5/6 12:C5/2 14:D5/2", "0:F5/2 2:F5/1 3:D5/3 6:F5/6 12:E5/2 14:F5/2",
                "0:F5/2 2:F5/1 3:D5/3 6:Bb5/6 12:A5/2 14:G5/2", "0:F5/10 10:A5/2 12:C6/4",
                "0:D6/2 2:D6/1 3:Bb5/3 6:D6/6 12:C6/2 14:Bb5/2", "0:A5/2 2:A5/1 3:F5/3 6:A5/6 12:G5/2 14:F5/2",
                "0:Db6/2 2:Db6/1 3:Bb5/3 6:Db6/6 12:F5/4",                       # Si♭m
                "0:E5/10 10:A5/2 12:C#6/4",
                "0:G5/2 2:G5/1 3:D5/3 6:G5/6 12:A5/2 14:Bb5/2", "0:A5/2 2:A5/1 3:F5/3 6:D6/6 12:E6/2 14:F6/2",
                "0:F6/2 2:F6/1 3:D6/3 6:F6/6 12:G6/2 14:F6/2", "0:A6/10 10:F6/2 12:C6/4",
                "0:Bb5/2 2:Bb5/1 3:G5/3 6:D6/6 12:C6/2 14:Bb5/2", "0:C6/2 2:C6/1 3:G5/3 6:E6/6 12:F6/2 14:G6/2",
                "0:E6/8", ""],
          'C': ["0:Bb5/2 2:Bb5/1 3:D6/3 6:F6/2 8:F6/2 10:F6/4 14:G6/2", "0:A6/2 2:A6/1 3:F6/3 6:A6/2 8:F6/2 10:C6/4 14:D6/2",
                "0:E6/2 2:E6/1 3:C6/3 6:G6/2 8:E6/2 10:C6/4 14:E6/2", "0:F6/10 10:E6/2 12:D6/4",
                "0:Bb5/2 2:Bb5/1 3:D6/3 6:F6/2 8:F6/2 10:F6/4 14:G6/2", "0:A6/2 2:A6/1 3:F6/3 6:A6/2 8:F6/2 10:A6/4 14:G6/2",
                "0:G6/2 2:G6/1 3:D6/3 6:Bb6/2 8:G6/2 10:D6/4 14:E6/2", "0:E6/10 10:C#6/2 12:A5/4",
                "0:Bb5/2 2:Bb5/1 3:D6/3 6:F6/2 8:F6/2 10:F6/4 14:G6/2", "0:A6/2 2:A6/1 3:F6/3 6:A6/2 8:F6/2 10:C6/4 14:D6/2",
                "0:E6/2 2:E6/1 3:C6/3 6:G6/2 8:E6/2 10:C6/4 14:E6/2", "0:F6/10 10:E6/2 12:D6/4",
                "0:D6/2 2:D6/1 3:Bb5/3 6:G6/2 8:Bb6/2 10:A6/2 12:G6/4", "0:F6/2 2:F6/1 3:D6/3 6:F6/2 8:Bb5/2 10:C6/2 12:D6/4",
                "0:E6/2 2:E6/1 3:C#6/3 6:E6/2 8:A5/2 10:C#6/2 12:E6/4", "0:D6/8"]},
}
C2_FROM = (0, 1, 2, 3, 12, 13, 14)                                   # C' = el estribillo: 1-4 y 13-15 (+ el cierre en La)
C2_END = "0:E6/3 3:C#6/3 6:A5/6"


def sections(v):
    M_ = MEL[v]
    c2 = [M_['C'][i] for i in C2_FROM] + [C2_END]
    return [('intro', H_IN, IN_MEL, 12, ''), ('A', H_A, M_['A'], 16, ''), ('S', H_S, M_['S'], 12, ''),
            ('B', H_B, M_['B'], 16, ''), ('C', H_C, M_['C'], 16, ''), ('H', H_H, [''] * 8, 16, ''),
            ('C2', H_C2, c2, 16, 'gira'), ('R', H_R, R_MEL, 12, '')]


J.TRACKS[TRACK] = dict(secs=sections, bpm=BPM, scale=SCALE, tonic=(2, M.MIN), lufs=LUFS, variants=tuple(VNAME), title='Tifón', vname=VNAME)


# ══ LOS NÚMEROS DE LA MELODÍA (la guía: del acorde 79-90 %, por grado 20-44, repetidas 1-23, largas 11-46) ══════════
def melody_numbers(sg):
    mel = [m for m in sg.mel if sg.tag[m[0] - 1] not in ('intro', 'R')]
    d16 = lambda m: sg.q(m[0], m[1] + m[3]) - sg.q(m[0], m[1])
    iv = np.diff([m[2] for m in mel])
    beat = lambda b: 4 if sg.steps[b - 1] == 16 else 3
    return dict(notes=len(mel), lo=nm(min(m[2] for m in mel)), hi=nm(max(m[2] for m in mel)),
                ct=np.mean([m[2] % 12 in sg.tones(m[0], m[1]) for m in mel]),
                step=np.mean([1 <= abs(i) <= 2 for i in iv]), rep=np.mean([i == 0 for i in iv]),
                long=np.mean([d16(m) >= 4 for m in mel]), leap=np.mean([abs(i) >= 5 for i in iv]),
                off=np.mean([m[1] % beat(m[0]) != 0 for m in mel]), meaniv=np.mean(np.abs(iv)),
                raf=np.mean([m[1] in RAFAGA for m in mel if sg.steps[m[0] - 1] == 16]))


def melody_report(v, sg):
    mn = melody_numbers(sg)
    lb, lo, out, off = J.check(sg)
    ov, who, avg = J.attack_overlap(sg)
    print(f'── {TRACK} {v} "{VNAME[v]}": {mn["notes"]} notas {mn["lo"]}-{mn["hi"]} · del acorde {100 * mn["ct"]:.0f} % · por grado {100 * mn["step"]:.0f} % · '
          f'repetidas {100 * mn["rep"]:.0f} % · largas {100 * mn["long"]:.0f} % · saltos ≥ 4ª {100 * mn["leap"]:.0f} % · intervalo medio {mn["meaniv"]:.2f}')
    print(f'    a contratiempo {100 * mn["off"]:.0f} % · en la ráfaga {100 * mn["raf"]:.0f} % · frase A frente a otras islas: {100 * ov:.0f} % ({who}; media {100 * avg:.0f} %)')
    print(f'    largas fuera del acorde: {lb or "ninguna"}; sueltas: {lo or "ninguna"}; fuera de escala: {out or "ninguna"}')
    return mn, lb, lo, out


if __name__ == '__main__' and os.environ.get('MELODIA'):
    for v in [a for a in sys.argv[1:] if a in VNAME] or list(VNAME):
        melody_report(v, J.Song(TRACK, v))
    sys.exit(0)


# ══ EL REPARTO ══════════════════════════════════════════════════════════════════════════════════════════════════════
XYLO, VIBES, TREM, STRINGS, PIZZ, CHOIR, TIMPANI, REV_CYM = 13, 11, 44, 48, 45, 52, 47, 119
WIND = M.WIND                                                        # (banco 3: el viento de efecto del GeneralUser GS)
TOM_L, TOM_M, TOM_H, RIM = 41, 45, 48, 37
LEADS = ('lead', 'sawlead', 'saw', 'fan', 'dbl', 'cm')
BASS_ROOT = {2: 38, 0: 36, 10: 34, 9: 45, 7: 43, 5: 41, 4: 40}       # (Re2 Do2 Si♭1 La2 Sol2 Fa2: Si♭-Do-Re suben)
I_SAW_LEAD = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.18, 6)}   # (la sierra elegida en Obsidiana)
I_SAW = {'vol': [9, 8, 7, 7, 6], 'sus': 6, 'vib': (20, 0.12, 5.4)}
I_UNDER = {'vol': [6, 9, 10, 10, 9], 'sus': 9, 'vib': (18, 0.15, 5.2), 'duty': 2}  # (voz hueca del N163)
I_SWIRL = {'vol': [10, 8, 6, 5, 4], 'sus': 4, 'duty': 0.25}         # el remolino: pulso corto
M.TIGHT_KEYS = M.TIGHT_KEYS + ('stab', 'pizz')                       # (sin cola sobre la nota siguiente)


class Rig(M.Rig):
    """el Rig de las montañas (GM con bancos y a tiempo) + el slap de los jefes, sierras VRC6 y el remolino"""
    def __init__(self, sg):
        super().__init__(sg)
        NF = len(self.Cn['lead'].f)
        for k in ('saw', 'sawlead', 'fan', 'swirl'): self.Cn[k] = Chan(NF)
        self.slap = SL.Rec()
        self.pan = []                                                  # (t0, t1, p0, p1): por dónde cruza el remolino
        for k in ('snare', 'crash'): self.NZ[k].exact = True

    def sl(self, b, st, n, d, vel=100):
        sg = self.sg
        self.slap.add(sg.t(b, st), sg.t(b, st) + sg.dur(b, d) * 0.95, n, vel)
        self.notes.setdefault('bass', []).append((sg.q(b, st), sg.q(b, st + d), n))

    def timp(self, b, st, n, d, vel):
        self.gm('timp', TIMPANI, b, st, 40 + (n - 40) % 12, d, vel, gate=0.95)

    def chord_gm(self, k, prog, b, st, d, vel, lo, nn=4, gate=0.95):
        """un acorde GM (sin 2ª menor, 7ª mayor ni tritono con la melodía que suena)"""
        for n in place(None, self.sg.chord(b, st), lo)[:nn]:
            if not self.rub(b, st, n, d, voice=LEADS): self.gm(k, prog, b, st, n, d, vel, gate=gate)


def wind(sg, R, b, st, d, vel):
    """el VIENTO GM (efecto sin altura: no cuenta en las comprobaciones de choques)"""
    R.gmt('wind', WIND, sg.t(b, st), sg.t(b, st) + sg.dur(b, d), 60, vel)


def next_root(sg, b):
    return (sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0])[0]


def r0(sg, b, st):
    return BASS_ROOT.get(sg.chord(b, st)[0], 38)


def approach(sg, R, b, st):
    """la nota del slap que lleva por grado a la raíz siguiente (o la 5ª si el acorde sigue)"""
    nx = BASS_ROOT.get(next_root(sg, b), 38)
    if sg.chord(b, st)[0] == next_root(sg, b): return r0(sg, b, st) + 7
    c = [p for p in (nx + 2, nx - 2, nx + 1, nx - 1) if p % 12 in sg.scale | sg.tones(b, st) and not R.rub(b, st, p, 2, voice=LEADS)]
    return c[0] if c else r0(sg, b, st)


# ══ LA MELODÍA, según la variante ═══════════════════════════════════════════════════════════════════════════════════
def play_melody(sg, R, v):
    for b, st, n, d in sg.mel:
        tag, k = sg.tag[b - 1], sg.pos[b - 1]
        if tag in ('intro', 'R'):                                      # la fanfarria: sierra y pulso a la octava (todas)
            R.chip('fan', b, st, n, d, I_SAW_LEAD, q=F.q_saw, release=3)
            if tag == 'R' or k >= 3: R.chip('dbl', b, st, n + 12, d, J.I_DBL, release=2)
            continue
        strong = tag in ('C', 'C2') or (tag == 'A' and k > 8)
        d16 = sg.q(b, st + d) - sg.q(b, st)
        if v == 'A':
            R.chip('sawlead', b, st, n - 12, d, I_SAW_LEAD, q=F.q_saw, release=3)
            if strong: R.chip('dbl', b, st, n, d, J.I_DBL, release=2)
        elif v == 'B':
            R.chip('lead', b, st, n - 12, d, J.I_PULSE, release=3)
            R.chip('cm', b, st, n - 12, d, I_UNDER, q=F.q_n163, release=3)
            if strong: R.chip('saw', b, st, n - 24, d, I_SAW, q=F.q_saw, release=2)
            if tag == 'C2': R.chip('dbl', b, st, n, d, J.I_DBL, release=2)
        else:
            # el xilófono: las largas, REDOBLADAS (semicorcheas que se apagan y vuelven a crecer); la sierra, debajo
            if d16 >= 6:
                for i in range(int(d)):
                    vel = (112 if i == 0 else 70 + int(30 * abs(i - d / 2) / (d / 2)))
                    R.gm('lead', XYLO, b, st + i, n, 1, vel, gate=0.9)
            else:
                R.gm('lead', XYLO, b, st, n, d, 110 if strong else 102, gate=0.9)
            R.chip('saw', b, st, n - 12, d, I_SAW, q=F.q_saw, release=2)
            if tag == 'C2': R.chip('dbl', b, st, n + 12 if n + 12 <= 96 else n, d, J.I_DBL, release=2)


# ══ EL RELÁMPAGO (el acento) y el trueno ════════════════════════════════════════════════════════════════════════════
def lightning(sg, R, b, thunder=False):
    """cuatro notas del acorde en zigzag hacia abajo (tres en tresillos), donde la melodía se calla; el trueno, en el 1
    siguiente. → True si sonó"""
    S = sg.steps[b - 1]
    z = 12 if S == 16 else 9
    for bb, st, n, d in sg.mel:
        if bb == b and (st >= z - 2 or sg.q(b, st + d) > sg.q(b, z) + 0.01): return False
    tones = place(None, sg.chord(b, z), 74)[:6]
    idx = (5, 3, 4, 2) if S == 16 else (5, 3, 4)
    for i, j in enumerate(idx):
        if not R.rub(b, z + i, tones[j], 1, voice=LEADS): R.gm('accent', VIBES, b, z + i, tones[j], 1, 88 - 6 * i, gate=0.9)
    if thunder and b < sg.NB:
        R.timp(b + 1, 0, next_root(sg, b), 4, 104)
        R.NZ['crash'].hit(sg.t(b + 1, 0), 3, J.CRASH_N)
    return True


# ══ LOS COMPASES DE 16 (A, B, C, C', H) ═════════════════════════════════════════════════════════════════════════════
def bass_raf(sg, R, b, heavy):
    """el slap en la ráfaga 3+3+4+3+3: raíz, octava (pop), 5ª, octava, y la que lleva al acorde siguiente"""
    if heavy: R.sl(b, 0, r0(sg, b, 0), 2, 114); R.sl(b, 2, r0(sg, b, 0), 1, 76)
    else: R.sl(b, 0, r0(sg, b, 0), 3, 108)
    R.sl(b, 3, r0(sg, b, 3) + 12, 3, 110)
    if sg.chords[b - 1][0] != sg.chords[b - 1][1]:                   # (dos acordes: la raíz del segundo en su sitio)
        R.sl(b, 6, r0(sg, b, 6) + 7, 2, 98); R.sl(b, 8, r0(sg, b, 8), 2, 104)
    else:
        R.sl(b, 6, r0(sg, b, 6) + 7, 4, 98)
    R.sl(b, 10, r0(sg, b, 10) + 12, 3, 106)
    R.sl(b, 13, approach(sg, R, b, 13), 3, 96)


def drums_raf(sg, R, b, level, k):
    """bombo en la ráfaga, caja de marcha en 2 y 4 con su ta-ta, metal de la fortaleza a contratiempo"""
    for st in (0, 6, 10) + ((3, 13) if level >= 3 else ()): R.kick(b, st, 1.0 if st == 0 else 0.8)
    for st in (4, 12): R.snare(b, st, 0.9)
    if k % 2 == 0: R.snare(b, 14, 0.35); R.snare(b, 15, 0.45)       # (ta-ta: la marcha)
    for st in range(16):
        if st % 4 == 2: R.NZ['hat'].hit(sg.t(b, st), 3, [6, 3, 1], short=1)
        elif level >= 3 or st % 2 == 0: R.NZ['hat'].hit(sg.t(b, st), 0, J.HAT if st % 2 == 0 else [3, 1])


def pad_chip(sg, R, b):
    for half in (0, 1):
        r, q = sg.chords[b - 1][half]
        base = 53 + (r - 53) % 12
        for j, iv in enumerate(q[1:]):
            R.chip(('pad1', 'pad2')[j], b, half * 8, base + iv, 8, M.I_PAD, q=F.q_n163, gate=0.97, release=5)


def held(sg, R, b, key, prog, vel, lo, S=16):
    """un acorde tenido por medio compás (trémolo de cuerdas, coro)"""
    for half in (0, 1):
        R.chord_gm(key, prog, b, half * S // 2, S // 2, vel, lo, nn=4, gate=0.98)


def swirl16(sg, R, b, flip):
    """el REMOLINO en semicorcheas; en la fase 2 cambia de sentido a mitad de compás (y cruza el estéreo de vuelta)"""
    for st in range(16):
        tones = place(None, sg.chord(b, st), 62)[:6]
        up = st < 8 or not flip
        j = (st % 8) if up else 7 - (st % 8)
        n = tones[min(j, 5)] if j < 6 else tones[(10 - j) % 6]
        if not R.rub(b, st, n, 1, voice=LEADS): R.chip('swirl', b, st, n, 1, I_SWIRL, gate=0.6, release=1)
    t0, tm, t1 = sg.t(b, 0), sg.t(b, 8), sg.t(b, 16)
    if flip: R.pan += [(t0, tm, -0.7, 0.7), (tm, t1, 0.7, -0.7)]
    else: R.pan += [(t0, t1, -0.7, 0.7)]


def bar_16(sg, R, b, v):
    tag, k, L = sg.tag[b - 1], sg.pos[b - 1], sg.slen[b - 1]
    if tag == 'H': return bar_hail(sg, R, b, k, L)
    if tag == 'A':
        level = 2 if k <= 8 else 3
        bass_raf(sg, R, b, heavy=k > 8)
        drums_raf(sg, R, b, level, k)
        for st in (3, 10): R.chord_gm('stab', STRINGS, b, st, 2, 92, 60, nn=3, gate=0.4)
        if k > 8: pad_chip(sg, R, b); held(sg, R, b, 'trem', TREM, 70, 50)
        if k in (1, 9):
            R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N); R.timp(b, 0, sg.chord(b, 0)[0], 4, 108)
        lightning(sg, R, b)
        if k == L:                                                     # redoble que crece hacia el soplido
            for st in range(8, 16): R.snare(b, st, 0.3 + 0.08 * (st - 8))
    elif tag == 'B':
        if k == L: return bar_inhale(sg, R, b)
        quiet = k <= 8
        if quiet:
            R.sl(b, 0, r0(sg, b, 0), 6, 100); R.sl(b, 10, r0(sg, b, 10) + 12, 3, 92); R.sl(b, 13, approach(sg, R, b, 13), 3, 88)
            R.kick(b, 0, 0.85)
            if k % 2 == 0: R.kick(b, 10, 0.6)
            for st in (4, 12): R.dr('rim', b, st, RIM, 80)
            for st in (2, 6, 10, 14): R.NZ['hat'].hit(sg.t(b, st), 3, [4, 2, 1], short=1)
            pad_chip(sg, R, b)
            if k == 1: R.timp(b, 0, sg.chord(b, 0)[0], 8, 92)
            if k == 8:                                                 # (el giro oscuro ya pasó: redoble de timbal suave)
                for st in range(8, 16): R.timp(b, st, next_root(sg, b), 1, 58 + 4 * (st - 8))
        else:
            if k == L - 1:                                             # el compás 15: la banda toca medio y se calla
                R.sl(b, 0, r0(sg, b, 0), 3, 106); R.sl(b, 3, r0(sg, b, 0) + 12, 3, 104); R.sl(b, 6, r0(sg, b, 0) + 7, 2, 96)
                R.kick(b, 0); R.kick(b, 6, 0.8); R.snare(b, 4, 0.9)
                R.chord_gm('stab', STRINGS, b, 6, 2, 96, 60, nn=3, gate=0.5)
                R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)
                R.gmt('revcym', REV_CYM, sg.t(b + 2, 0) - 1.35, sg.t(b + 2, 0) + 0.1, 60, 96)    # (llega a su punta en el 1 de C)
                wind(sg, R, b, 8, 24, 88)
                return
            bass_raf(sg, R, b, heavy=False)
            drums_raf(sg, R, b, 2, k)
            pad_chip(sg, R, b); held(sg, R, b, 'trem', TREM, 64, 50)
            if k == 9: R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)
        lightning(sg, R, b)
    else:                                                              # C y C' (fase 2)
        bass_raf(sg, R, b, heavy=True)
        drums_raf(sg, R, b, 4, k)
        for st in (3, 10): R.chord_gm('stab', STRINGS, b, st, 2, 100, 60, nn=3, gate=0.4)
        pad_chip(sg, R, b)
        held(sg, R, b, 'trem', TREM, 76, 50)
        held(sg, R, b, 'choir', CHOIR, 72, 57)
        if tag == 'C2': swirl16(sg, R, b, flip=True)
        if k == 1 and tag == 'C':                                      # LA BOMBA explota dentro
            R.timp(b, 0, sg.chord(b, 0)[0], 6, 124); R.kick(b, 0, 1.2); R.snare(b, 0, 1.0)
            R.chord_gm('stab', STRINGS, b, 0, 3, 116, 48, nn=5, gate=0.6)
        if k in (1, 9) or (tag == 'C2' and k == 5): R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)
        lightning(sg, R, b, thunder=True)
        if k == L and tag == 'C':                                      # (al granizo: redoble de toms)
            for i, st in enumerate(range(12, 16)): R.dr('toms', b, st, TOM_L + 2 * i, 84 + 8 * i)


def bar_inhale(sg, R, b):
    """LA INHALACIÓN (el último compás de B): el viento entra a la boca — redoble de timbal y caja que crecen sobre el La,
    el slap calla; el plato al revés llega en el 1 del estribillo"""
    for st in range(16):
        R.timp(b, st, sg.chord(b, 0)[0], 1, 60 + 4 * st)
        if st >= 8: R.snare(b, st, 0.25 + 0.07 * (st - 8))
    held(sg, R, b, 'trem', TREM, 84, 50)


def bar_hail(sg, R, b, k, L):
    """EL GRANIZO: sin melodía. Xilófono y pizzicato que repiquetean, metal de ruido en semicorcheas, solo de slap"""
    r, r2 = r0(sg, b, 0), r0(sg, b, 8)
    if k < L:
        pat = ((0, 0, 2, 112), (3, 0, 1, 84), (4, 12, 2, 114), (6, 0, 1, 80), (7, 7, 1, 92), (8, 0, 2, 108),
               (10, 12, 1, 106), (11, 0, 1, 78), (12, 7, 2, 96), (14, 12, 1, 104), (15, 7 if k % 2 else 12, 1, 88))
        for st, deg, d, vv in pat:
            n = (r if st < 8 else r2) + deg
            R.sl(b, st, n, d, vv)
        tones = place(None, sg.chord(b, 0), 79)[:6]
        for st in range(16):
            if (b * 3 + st * 7) % 5 == 0: continue                    # (huecos: el granizo no cae a compás)
            n = tones[(b * 7 + st * 5) % 6]
            R.gm('xylo', XYLO, b, st, n, 1, (92 if st % 4 == 0 else 70) + 3 * k, gate=0.5)
            R.NZ['hat'].hit(sg.t(b, st), 2 if st % 2 else 1, [5, 2] if st % 4 == 0 else [3, 1], short=1)
        low = place(None, sg.chord(b, 0), 55)[:3]
        for i, st in enumerate((2, 6, 10, 14)): R.gm('pizz', PIZZ, b, st, low[i % 3], 1, 84, gate=0.5)
        if k in (1, 5): R.timp(b, 0, sg.chord(b, 0)[0], 6, 116); R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)
        if k in (4, 7):
            for st in range(10, 16): R.timp(b, st, next_root(sg, b), 1, 70 + 6 * (st - 10))
        if k >= 3:
            for st in (0, 8): R.kick(b, st, 0.95)
        if k >= 5:
            for st in (4, 12): R.snare(b, st, 0.8)
            R.kick(b, 10, 0.7)
    else:                                                              # el último: tres golpes y redoble de toms
        for st in (0, 4, 8):
            R.sl(b, st, r + (0, 7, 12)[st // 4], 3, 112)
            R.kick(b, st); R.snare(b, st, 0.9)
            R.chord_gm('stab', STRINGS, b, st, 2, 106, 55, nn=4, gate=0.5)
            R.timp(b, st, sg.chord(b, 0)[0], 2, 112)
        for i, st in enumerate(range(12, 16)): R.dr('toms', b, st, TOM_L + 2 * i, 80 + 8 * i)


# ══ LOS COMPASES DE 12 (intro, S, R: los tresillos del viento) ═══════════════════════════════════════════════════════
def bass_trip(sg, R, b, light=False):
    rt = r0(sg, b, 0)
    if light:
        R.sl(b, 0, rt, 6, 100); R.sl(b, 6, rt + 7, 3, 92); R.sl(b, 9, rt + 12, 3, 96)
        return
    for st, deg, d, vv in ((0, 0, 3, 112), (3, 12, 2, 106), (5, 0, 1, 80), (6, 7, 3, 100), (9, 12, 2, 106)):
        R.sl(b, st, r0(sg, b, st) + deg, d, vv)
    R.sl(b, 11, approach(sg, R, b, 11), 1, 92)


def drums_trip(sg, R, b, heavy=False):
    for st in (0, 6) + ((4, 10) if heavy else ()): R.kick(b, st, 1.0 if st == 0 else 0.8)
    for st in (3, 9): R.snare(b, st, 0.9)
    for st in range(12):
        if st % 3 == 2: R.NZ['hat'].hit(sg.t(b, st), 3, [6, 3, 1], short=1)
        else: R.NZ['hat'].hit(sg.t(b, st), 0, J.HAT if st % 3 == 0 else [3, 1])


def swirl12(sg, R, b, vel_scale=1.0):
    """el REMOLINO en tresillos: sube y baja por el acorde; cruza el estéreo de izquierda a derecha cada compás"""
    tones = place(None, sg.chord(b, 0), 62)[:6]
    for st in range(12):
        j = (0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 2, 3)[st]
        n = place(None, sg.chord(b, st), 62)[:6][j]
        if not R.rub(b, st, n, 1, voice=LEADS): R.chip('swirl', b, st, n, 1, I_SWIRL, gate=0.6, release=1)
    R.pan.append((sg.t(b, 0), sg.t(b, 12), -0.7, 0.7))


def ending(sg, R, b):
    """el último compás de la intro y de la R (iguales: la costura del bucle es la misma entrada que tras la intro):
    la banda pica tres veces en el tiempo 3 y el tiempo 4 se queda en el aire, con el plato al revés hacia el 1"""
    R.sl(b, 0, 45, 6, 108); R.kick(b, 0); R.snare(b, 0, 0.6)
    held(sg, R, b, 'trem', TREM, 80, 50, S=12)
    for i, st in enumerate((6, 7, 8)):
        R.sl(b, st, 45 + (0, 7, 12)[i], 1, 104 + 4 * i)
        R.kick(b, st); R.snare(b, st, 0.7 + 0.1 * i)
        R.chord_gm('stab', STRINGS, b, st, 1, 100 + 4 * i, 57, nn=4, gate=0.6)
        R.timp(b, st, 9, 1, 100 + 6 * i)
    R.gmt('revcym', REV_CYM, sg.t(b, 12) - 1.35, sg.t(b, 12) + 0.1, 60, 84)


def bar_12(sg, R, b, v):
    tag, k, L = sg.tag[b - 1], sg.pos[b - 1], sg.slen[b - 1]
    if k == L and tag in ('intro', 'R'): return ending(sg, R, b)
    if tag == 'intro':
        if k == 1:
            wind(sg, R, b, 0, 36, 96)
            held(sg, R, b, 'trem', TREM, 56, 50, S=12)
        elif k == 2:
            for st in range(12): R.timp(b, st, 2, 1, 50 + 5 * st)
            for st in range(6, 12): R.snare(b, st, 0.2 + 0.08 * (st - 6))
            held(sg, R, b, 'trem', TREM, 66, 50, S=12)
            R.sl(b, 0, 38, 6, 96); R.sl(b, 9, 38, 3, 90)
        else:
            bass_trip(sg, R, b)
            drums_trip(sg, R, b, heavy=k >= 5)
            held(sg, R, b, 'trem', TREM, 72, 50, S=12)
            if k == 3: R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N); R.timp(b, 0, 2, 4, 112)
            if k >= 5: swirl12(sg, R, b, 0.8)
    elif tag == 'S':
        if k == 1:                                                     # EL AVISO: el redoble crece, las cuerdas suben
            R.sl(b, 0, r0(sg, b, 0), 12, 100)
            for st in range(12): R.snare(b, st, 0.2 + 0.06 * st)
            for i, st in enumerate((0, 3, 6, 9)):
                R.chord_gm('trem', TREM, b, st, 3, 60 + 8 * i, 50 + 2 * i, nn=4, gate=0.98)
            wind(sg, R, b + 1, 0, 12 * 7, 104)    # (siete compases de viento)
            R.kick(b, 0)
            return
        bass_trip(sg, R, b)
        drums_trip(sg, R, b, heavy=True)
        swirl12(sg, R, b)
        held(sg, R, b, 'trem', TREM, 80, 50, S=12)
        if k in (2, 5): R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N); R.timp(b, 0, sg.chord(b, 0)[0], 3, 110)
        lightning(sg, R, b)
    else:                                                              # R: vuelve la fanfarria
        bass_trip(sg, R, b)
        drums_trip(sg, R, b, heavy=True)
        held(sg, R, b, 'trem', TREM, 76, 50, S=12)
        swirl12(sg, R, b, 0.8)
        if k == 1: R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N); R.timp(b, 0, 2, 4, 112)


def arrange(sg, R, v):
    play_melody(sg, R, v)
    for b in range(1, sg.NB + 1):
        if sg.steps[b - 1] == 16: bar_16(sg, R, b, v)
        else: bar_12(sg, R, b, v)


# ══ LA MEZCLA ═══════════════════════════════════════════════════════════════════════════════════════════════════════
LV = {'lead': 0, 'fan': 0, 'saw': -8, 'dbl': -11, 'cm': -8,
      'stab': -6, 'trem': -9, 'choir': -9, 'pad': -10, 'swirl': -9, 'accent': -6, 'xylo': -4, 'pizz': -7,
      'bass': -1, 'kick': -1, 'snare': 0, 'rim': -6, 'hat': -9, 'crash': -7, 'timp': -4, 'toms': -5, 'wind': -13, 'revcym': -9}
LEAD_GROUP = ('lead', 'fan')
DRUM_GROUP = ('kick', 'snare', 'rim', 'hat', 'crash', 'timp', 'toms')
ACC_GROUP = ('stab', 'trem', 'choir', 'pad', 'swirl', 'accent', 'xylo', 'pizz', 'saw', 'dbl', 'cm', 'wind', 'revcym')
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
    for k in ('saw', 'sawlead', 'fan'):
        if np.abs(R.Cn[k].v).max() > 0: S[k] = cut(F.render_saw(R.Cn[k]) * 0.0035)
    if np.abs(R.Cn['swirl'].v).max() > 0: S['swirl'] = cut(F.pulse_dac(F.render_pulse(R.Cn['swirl'])))
    if 'sawlead' in S: S['lead'] = S.pop('sawlead')
    from scipy.signal import butter, sosfilt
    hp = butter(2, 30, btype='high', fs=SR, output='sos')
    S = {k: sosfilt(hp, x) for k, x in S.items() if np.abs(x).max() > 0}
    g = GN.level(S, {k: LV.get(k, -10) + (0 if k in LEAD_GROUP else BACKING) for k in S}, 'lead')
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('stab', 0.2) - sd('pizz', 0.3) + sd('xylo', 0.3) - sd('accent', 0.35) + sd('choir', 0.15) - sd('trem', 0.15) \
        + sd('hat', 0.25) - sd('saw', 0.15) + sd('dbl', 0.15) - sd('toms', 0.25)
    pan = np.zeros(L)                                                  # el remolino cruza de un lado al otro
    for t0, t1, p0, p1 in R.pan:
        a, b_ = int(t0 * SR), min(L, int(t1 * SR))
        if b_ > a: pan[a:b_] = np.linspace(p0, p1, b_ - a)
    if 'swirl' in S: side = side + S['swirl'] * g['swirl'] * pan
    Lx, Rx = x + side, x - side
    st = np.stack([GN.fold(Lx, n, at), GN.fold(Rx, n, at)], 1)            # (la cola, sobre el principio del bucle)
    st = F.master(st, lufs=LUFS, ceiling=CEILING)
    S = {k: GN.fold(s, n, at) for k, s in S.items()}
    return sg, R, S, g, st, n, at


# ══ INFORME (números: NO se ha escuchado) ═══════════════════════════════════════════════════════════════════════════
def report(v, sg, R, S, g, y, n, at):
    mn, lb, lo, out = melody_report(v, sg)
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    bar = sg.BAR * SR
    lufs = F.loudness(y)
    print(f'  {sg.NB} compases: intro {sg.INTRO} = {at} muestras ({at / SR:.2f} s) + bucle {sg.NB - sg.INTRO} = {n - at} muestras ({(n - at) / SR:.2f} s) · {lufs:.1f} LUFS, pico {np.abs(y).max():.2f}')
    print(f'  energía: melodía {grp(LEAD_GROUP):.0f} %, batería {grp(DRUM_GROUP):.0f} %, bajo {grp(("bass",)):.0f} %, acompañamiento {grp(ACC_GROUP):.0f} %')
    print('  ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    from scipy.signal import butter, sosfilt
    bp = butter(2, [1000, 5000], btype='band', fs=SR, output='sos')
    rms = lambda z: np.sqrt(np.mean(sosfilt(bp, z[at:n]) ** 2))
    lead = sum(S[k] * g[k] for k in LEAD_GROUP if k in S)
    print('    en 1-5 kHz, frente a la melodía: ' + ' '.join(f'{k} {100 * rms(S[k] * g[k]) / rms(lead):.0f} %' for k in S if k not in LEAD_GROUP and rms(S[k] * g[k]) / rms(lead) > 0.2))
    tot_cl = 0
    for k, notes in R.notes.items():
        if k in LEADS or not notes: continue
        cl = J.clashes(sg, sg.mel, notes)
        tot_cl += len(cl)
        if cl: print(f'    choques melodía / {k} (≥ corchea): {len(cl)} {cl[:5]}')
    print(f'    choques totales melodía / resto: {tot_cl}')
    ln, bars, jr, dbs, ji, dbi = M.seam_numbers(y, at, bar, [(b0 - 1) * sg.BAR * SR for b0 in sg.starts[2:]])
    print(f'  BUCLE: {ln} muestras = {bars:.4f} compases; costura: salto {jr:.2f}× el de otro tiempo 1 de sección, {dbs:+.1f} dB; intro → bucle {ji:.2f}×, {dbi:+.1f} dB')
    span = lambda b0, L_: (int((b0 - 1) * sg.BAR * SR), int((b0 - 1 + L_) * sg.BAR * SR))
    def db(a, b_):
        z = sum(S[k][a:b_] * g[k] for k in S)
        return 10 * np.log10(np.mean(np.asarray(z) ** 2) + 1e-12)
    r_ = db(*span(sg.starts[1], 16))
    secs = ' '.join(f'{sg.tag[b0 - 1]} {db(*span(b0, sg.slen[b0 - 1])) - r_:+.1f}' for b0 in sg.starts)
    print('  sonoridad por sección vs A (dB): ' + secs)
    # (la costura: lo que suena en el último y el primer compás del bucle, frente a la entrada desde la intro)
    w = int(0.025 * SR)
    env = lambda z: np.sqrt(np.convolve(z.mean(1) ** 2, np.ones(w) / w, mode='valid')[::w])
    a_, b_ = env(y[at - int(bar):at]), env(y[n - int(bar):n])
    same = np.corrcoef(a_, b_)[0, 1]
    print(f'  el último compás de la intro y el del bucle (envolvente de 25 ms): correlación {same:.3f}, {20 * np.log10(b_.mean() / a_.mean()):+.2f} dB')
    return dict(lufs=lufs, loop=n - at, intro=at, bars=bars, jr=jr, ji=ji, dbs=dbs, nlb=len(lb), nlo=len(lo), nout=len(out), ncl=tot_cl,
                mn=mn, lead=grp(LEAD_GROUP), peak=np.abs(y).max(), secs=secs, same=same)


def mmss(t):
    return f'{int(t // 60)}:{t % 60:04.1f}'


def readme(sg, nums):
    desc = {'intro': 'INTRO (tresillos): viento, redoble de timbal, la fanfarria con LA LLAMADA (La-Re-Fa-La)',
            'A': 'A: el tema, en la ráfaga 3+3+4+3+3 (2ª mitad: trémolo, colchón, más batería)',
            'S': 'S: EL SOPLIDO (tresillos): 1 compás de aviso (redoble que crece) y 7 de viento, el remolino cruzando',
            'B': 'B: la voz baja, el giro oscuro (Si♭m → La); los 2 últimos compases, LA INHALACIÓN',
            'C': 'C: el estribillo, tras la bomba; relámpagos (vibráfono en zigzag) y truenos',
            'H': 'H: EL GRANIZO, sin melodía: xilófono y pizzicato, metal, solo de slap',
            'C2': "C': FASE 2, el jefe gira: el remolino cambia de sentido a mitad de compás",
            'R': 'R (tresillos): vuelve la fanfarria con la llamada y acaba como la intro'}
    t = ['TIFÓN — tema de jefe de la Ráfaga Suprema (jefe secreto de la FORTALEZA, en los tejados bajo la tormenta)',
         'tools/music/tifon.py. NO SE HA ESCUCHADO: comprobado solo con números. El oído es el tuyo.',
         '',
         'Re menor, 160 BPM, 4/4. La idea: la tormenta llega al tejado de la fortaleza (marcha, sierra del VRC6, redobles,',
         'la fanfarria de tresillos) y lo hace girar. Ritmo nuevo, LA RÁFAGA: 3+3+4+3+3 (golpes en 0 3 6 10 13), un palíndromo:',
         'el viento entra, se queda arriba y sale. Las secciones de viento (intro, S, R) cambian a TRESILLOS sin cambiar el',
         'pulso. Giro oscuro: Si♭ menor → La. Acento: EL RELÁMPAGO (vibráfono, cuatro notas en zigzag) y el trueno (timbal +',
         'plato) en el 1 siguiente. Debajo: el slap de todos los jefes, bombo y caja de DPCM, metal de ruido, colchón N163,',
         'trémolo de cuerdas, coro, timbales, viento GM, platillo al revés; xilófono y pizzicato en el granizo.',
         '',
         'LAS TRES VARIANTES (misma armonía, forma y banda; otra melodía y otra voz):',
         '  A remolino  melodía-RIFF en la sierra del VRC6: la figura de la ráfaga (salta, baja por grado, vuelve a subir)',
         '              movida por los acordes, cada vez más arriba. La más cerca de lo que te gustó en Obsidiana B y Resaca A.',
         '  B vendaval  CANTADA en el pulso del 2A03 (con la voz hueca del N163 al unísono): corcheas por grados con',
         '              anticipaciones, pregunta y respuesta en secuencia; estribillo en el tresillo 3+3+2.',
         '  C granizo   XILÓFONO con la sierra una octava abajo: notas repetidas que repiquetean y se paran en una larga',
         '              REDOBLADA; la más original (el instrumento hace el granizo también en la melodía).',
         '',
         'ARCHIVOS, en cada variante: tifon_<v>_preview.ogg / .mp3 (intro + el bucle dos veces), _intro.ogg, _loop.ogg (los dos',
         'del juego), _costura.ogg (los últimos 8 s del bucle + los primeros 8 s: así suena la vuelta), .mid (melodía y bajo).',
         '',
         'SECCIONES (tiempos de la previa; igual en las tres):']
    for b0 in sg.starts:
        t.append(f'  {mmss((b0 - 1) * sg.BAR)}  {desc[sg.tag[b0 - 1]]}')
    lp = (sg.NB - sg.INTRO) * sg.BAR
    t.append(f'  {mmss(sg.NB * sg.BAR)}  el bucle empieza otra vez (segunda vuelta: mismas secciones + {mmss(lp)})')
    t += [f'  {mmss((sg.NB + sg.NB - sg.INTRO) * sg.BAR)}  fin de la previa', '', 'NÚMEROS:'] + nums
    t += ['', 'A JUZGAR DE OÍDO: si la melodía canta sobre la ráfaga o se siente forzada (y en qué tiempo); el paso de semicorcheas a',
          'tresillos y vuelta (' + mmss((sg.starts[2] - 1) * sg.BAR) + ', ' + mmss((sg.starts[3] - 1) * sg.BAR) + '); la inhalación y la bomba (' +
          mmss((sg.starts[4] - 1) * sg.BAR - 2 * sg.BAR) + '); si el remolino que cruza el estéreo marea; el volumen del viento GM; el',
          'xilófono de la C; si suena a la fortaleza y a tormenta.']
    return '\n'.join(t) + '\n'


def enc_mp3(y, path):
    wav = path[:-4] + '.wav'
    F.write_wav(wav, y)
    os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libmp3lame -q:a 2 "{path}"')
    os.remove(wav)


if __name__ == '__main__':
    which = [a for a in sys.argv[1:] if a in VNAME] or list(VNAME)
    if os.environ.get('INSTALL'): which = [os.environ.get('TIFON', 'B')]     # (el usuario eligió la B "vendaval", 2026-11-04)
    os.makedirs(PRUEBAS, exist_ok=True)
    nums = []
    for v in which:
        sg, R, S, g, y, n, at = build(v)
        r = report(v, sg, R, S, g, y, n, at)
        mn = r['mn']
        nums.append(f'  {v} {VNAME[v]}: intro {r["intro"]} muestras ({r["intro"] / SR:.2f} s) + bucle {r["loop"]} ({r["loop"] / SR:.2f} s = {r["bars"]:.4f} compases), '
                    f'{r["lufs"]:.1f} LUFS, pico {r["peak"]:.2f}; melodía {r["lead"]:.0f} % de la energía')
        nums.append(f'      melodía: del acorde {100 * mn["ct"]:.0f} %, por grado {100 * mn["step"]:.0f} %, repetidas {100 * mn["rep"]:.0f} %, largas {100 * mn["long"]:.0f} %, '
                    f'a contratiempo {100 * mn["off"]:.0f} %; largas fuera del acorde {r["nlb"]}, sueltas {r["nlo"]}, fuera de escala {r["nout"]}, choques {r["ncl"]}')
        nums.append(f'      costura {r["jr"]:.2f}× un tiempo 1 de sección ({r["dbs"]:+.1f} dB); intro → bucle {r["ji"]:.2f}×; secciones (dB frente a A): {r["secs"]}')
        if os.environ.get('REPORT'): continue
        if os.environ.get('INSTALL'):
            J.export(y, at, os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'music', 'bosses', TRACK))
            print(f'  instalada {v} {VNAME[v]} en assets/music/bosses/{TRACK}_intro|_loop.ogg')
            continue
        base = os.path.join(PRUEBAS, f'{TRACK}_{v}_{VNAME[v]}')
        J.export(y, at, base)
        pv = np.concatenate([y, y[at:]])
        J.enc(pv, base + '_preview.ogg')
        enc_mp3(pv, base + '_preview.mp3')
        w = 8 * SR
        J.enc(np.concatenate([y[n - w:n], y[at:at + w]]), base + '_costura.ogg')
        J.write_mid(base + '.mid', sg, R)
    if not os.environ.get('REPORT') and len(which) == len(VNAME):
        with open(os.path.join(PRUEBAS, 'LEEME.txt'), 'w') as f:
            f.write(readme(sg, nums))
        print(f'  previas en {PRUEBAS}')
