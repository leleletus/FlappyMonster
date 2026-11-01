#!/usr/bin/env python3
# tools/music/obsidiana.py — "OBSIDIANA": tema de jefe ORIGINAL para el escorpión gigante de obsidiana y tres colas
# (el jefe secreto de la isla del volcán). Previas para que el usuario elija; no toca assets/ salvo con INSTALL=1 (y
# nunca el index.json). Compuesto desde cero. Se comprueba con números: NO SE HA ESCUCHADO.
#
# LA IDEA: la isla del volcán ya vive en el modo frigio (Mi con Fa natural, el ♭II), y el frigio es el modo del
# FLAMENCO. Así que el escorpión baila una BULERÍA de fuego:
#   · el RITMO que el juego no tenía: un compás de 12 pasos partido 3+3+2+2+2 (dos pasos largos y tres cortos, el 6/8 +
#     3/4 de la bulería). Cada compás es el bicho entero: la cola SE LEVANTA (3+3) y PICA TRES VECES (2+2+2);
#   · la armonía: la cadencia andaluza La m - Sol - Fa - Mi, que baja sola y deja la melodía encima con todo hecho;
#     el Mi mayor con su Sol# trae la 2ª aumentada Fa-Sol#, el color de la pieza. GIRO OSCURO (uno): Si♭ → Mi, un tritono;
#   · el reparto TEMÁTICO sobre el de la casa: guitarra española en rasgueo, palmas, castañuelas, taiko como zapateo,
#     trompeta de corrida (variante A), voz de chip (B; ELEGIDA) o tres voces (C), y el VIDRIO (Crystal GM: la obsidiana es
#     vidrio volcánico) como acento, tres notas del acorde justo donde la melodía se posa. Debajo sigue Flappy Monster:
#     el slap bass de todos los jefes, bombo y caja de DPCM, platos de ruido, colchón y voz hueca de N163, sierra VRC6;
#   · la sección Z, el ZAPATEADO (8 compases en 4/4 al mismo compás de 1,5 s: la subdivisión cambia, el pulso no): un
#     solo de slap y pies, sin melodía.
#
# LAS MELODÍAS se escribieron con lo que sale del estudio de los temas favoritos (jungla, montañas):
#   · el RITMO de la melodía ES el del acompañamiento: casi todos sus golpes caen en los acentos del compás;
#   · una sola figura de 1-2 compases que se repite con el ritmo fijo mientras la armonía la mueve, y cada intento llega
#     más alto; en el compás 7 la figura se rompe y va a la cima;
#   · acordes por todas partes (más del 80 % de las notas), los primeros tiempos y las largas siempre;
#   · entre compás y compás, por grado o cerca: el final de cada compás lleva al principio del siguiente;
#   · respiran: cada dos compases, una larga o un silencio; ahí contesta el acento;
#   · cada sección tiene su propio ritmo de melodía, pero dentro de ella el ritmo es casi el mismo.
#
# TRES VARIANTES con la misma armonía y forma y DISTINTA melodía:
#   A "saeta"       cantada, de frases largas: 5-1-3-2-1 en largo-largo-corto-corto-corto, que se contesta en secuencia.
#   B "picado"      de guitarra: una vuelta rápida, una nota larga y las tres picadas subiendo por el acorde; el
#                   estribillo son carreras (sube la escala, se clava) y caídas.
#   C "tres colas"  el salto de 5ª y la caída de 3ª, pasado entre tres voces (trombón, trompeta, shanai: una por cola,
#                   cada una más arriba); se juntan en acordes al final de la frase; estribillo que entra tras el 1.
#
# Forma: INTRO 8 · A 16 · B 16 · C 16 · Z 8 · A' 16 (LA LLAMADA, Mi-La-Do-Mi) · R 4 (vuelve) = 8 + 76 compases, 160
# "BPM" (compás de 1,5 s justos = 66 150 muestras); 12 s + bucle de 114 s. La R acaba como la intro, en las tres picadas.
#
#   ~/.venvs/fm-music/bin/python tools/music/obsidiana.py [A B C]  → previas en FlappyMonster_pruebas/musica/escorpion_nuevo/
#   REPORT=1 → solo números · INSTALL=1 OBSIDIANA=A|B|C → assets/music/bosses/obsidiana_intro|_loop.ogg + mid/obsidiana.mid
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
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/escorpion_nuevo'
INSTALL_DIR = os.path.join(F.MUSIC_DIR, 'bosses')
TRACK = 'obsidiana'
BPM, LUFS, CEILING = 160, -10.5, 0.72
VNAME = {'A': 'saeta', 'B': 'picado', 'C': 'tres_colas'}
SCALE = {9, 11, 0, 2, 4, 5, 7}                                       # La menor natural (el Sol# solo dentro de su Mi mayor)

# ══ LA ARMONÍA (la misma en las tres) ═══════════════════════════════════════════════════════════════════════════════
H_IN = "E E F E E F G|F E"
H_A = "Am G F E Am G F E " + "Dm G C F Dm E F E"                     # la andaluza, dos veces · el círculo de quintas
H_B = "F C Dm Am F C Bb E " + "F C Dm Am Dm E Am|G F|E"              # el GIRO OSCURO: Si♭ → Mi
H_C = "Am F Dm E Am F G E " + "Am F Dm E F G F|E E"
H_Z = "E F E F E F G|F E"
H_R = "E F G|F E"

# ══ LA LLAMADA del intro: la misma saeta para las tres (Mi mayor; sube, se queda arriba, cae) ═══════════════════════
IN_CALL = ['', "6:E5/2 8:G#5/2 10:B5/2", "0:C6/6 6:A5/6", "0:B5/6 6:G#5/6", "6:E5/2 8:G#5/2 10:B5/2",
           "0:C6/3 3:F6/3 6:E6/2 8:D6/2 10:C6/2", "0:B5/3 3:D6/3 6:C6/2 8:A5/2 10:F5/2", "0:E5/6"]

# ══ LAS MELODÍAS: 'paso:Nota/duración' en 12 pasos por compás (acentos: 0 3 6 8 10) ═════════════════════════════════
MEL = {
    # A "saeta": 3-3-2-2-2 — sube el acorde y baja por grado; contesta con una larga y tres que suben; todo en secuencia
    'A': {'A': ["0:E5/3 3:A5/3 6:C6/2 8:B5/2 10:A5/2",                # Lam: 5-1-3-2-1
                "0:B5/6 6:G5/2 8:A5/2 10:B5/2",                       # Sol: la larga, y sube hacia el Do
                "0:C6/3 3:A5/3 6:F5/2 8:G5/2 10:A5/2",                # Fa
                "0:G#5/4 4:A5/1 5:G#5/1 6:E5/2 8:F5/2 10:G#5/2",     # Mi: Fa-Sol#, la 2ª aumentada; el Sol# cae en el La
                "0:A5/3 3:C6/3 6:E6/2 8:D6/2 10:C6/2",                # la cabeza, una 3ª más arriba
                "0:D6/4 4:E6/1 5:D6/1 6:B5/2 8:C6/2 10:D6/2",
                "0:A5/3 3:C6/3 6:F6/2 8:E6/2 10:D6/2",                # … y otra vez más arriba: la cima de la frase
                "0:E6/4 4:F6/1 5:E6/1 6:D6/2 8:C6/2 10:B5/2",         # la vuelta de cante y la bajada
                "0:A5/5 5:G5/1 6:F5/2 8:G5/2 10:A5/2",                # el círculo de quintas: se abre
                "0:B5/2 2:A5/1 3:G5/3 6:D6/5 11:C6/1",                # (se adelanta al Do del compás siguiente)
                "0:C6/3 3:E6/3 6:G5/2 8:A5/2 10:B5/2",
                "0:C6/5 5:D6/1 6:C6/2 8:A5/4",
                "2:F5/1 3:A5/3 6:D6/2 8:C6/2 10:D6/2",
                "0:E6/6 6:D6/2 8:C6/2 10:B5/2",
                "0:A5/2 2:B5/1 3:C6/3 6:A5/2 8:G5/2 10:F5/2",
                "0:E5/6"],                                            # (se calla: pican los tres golpes)
          # B: la QUEJA, en voz baja; entra tarde, sube tres notas, se posa y cae en dos largas
          'B': ["2:C5/1 3:F5/3 6:G5/2 8:A5/4", "0:G5/6 6:E5/6", "2:F5/1 3:A5/3 6:G5/2 8:A5/4", "0:E5/6 6:C5/6",
                "2:F5/1 3:A5/3 6:A5/2 8:C6/4", "0:E6/6 6:C6/3 9:G5/3",
                "0:Bb5/3 3:D6/3 6:F6/6",                              # el Si♭
                "0:E6/6 6:B5/2 8:G#5/2 10:E5/2",
                "2:C5/1 3:F5/3 6:G5/2 8:A5/4", "0:G5/6 6:E5/6", "2:D5/1 3:F5/3 6:A5/2 8:D6/4", "0:C6/6 6:A5/2 8:B5/2 10:C6/2",
                "0:D6/3 3:F6/3 6:E6/2 8:D6/2 10:C6/2", "0:B5/6 6:G#5/6",
                "0:A5/3 3:C6/3 6:B5/2 8:A5/2 10:G5/2", "0:F5/3 3:A5/3 6:G#5/6"],
          # C: el ESTRIBILLO — la nota repetida en las tres picadas, cada vez más arriba
          'C': ["0:A5/3 3:E6/3 6:E6/2 8:E6/2 10:D6/2", "0:C6/6 6:F5/2 8:A5/2 10:C6/2",
                "0:D6/3 3:A6/3 6:A6/2 8:A6/2 10:F6/2", "0:E6/2 2:F6/1 3:G#6/3 6:E6/2 8:D6/1 9:C6/1 10:B5/2",
                "0:A5/3 3:C6/3 6:E6/2 8:A6/4", "0:A6/2 2:G6/1 3:F6/3 6:C6/2 8:D6/2 10:E6/2",
                "0:D6/3 3:G6/3 6:F6/2 8:E6/2 10:D6/2", "0:E6/6 6:D6/2 8:C6/2 10:B5/2",
                "0:A5/3 3:E6/3 6:E6/2 8:E6/2 10:D6/2", "0:C6/6 6:F5/2 8:A5/2 10:C6/2",
                "0:D6/3 3:A6/3 6:A6/2 8:A6/2 10:F6/2", "0:E6/2 2:F6/1 3:G#6/3 6:E6/2 8:D6/1 9:C6/1 10:B5/2",
                "0:A5/3 3:C6/3 6:F6/2 8:A6/4", "0:G6/3 3:D6/3 6:B5/2 8:C6/2 10:D6/2",
                "0:C6/3 3:A5/3 6:B5/2 8:G#5/2 10:E5/2", "0:E5/6"],
          'LL': (0, "0:E5/3 3:A5/3 6:C6/2 8:E6/4")},                  # LA LLAMADA (Mi-La-Do-Mi), compás 1 de A'
    # B "picado": la vuelta (1+1+1), la larga (3) y las tres picadas por el acorde; la línea de arriba baja Do-Si-La-Sol#
    'B': {'A': ["0:C6/1 1:B5/1 2:C6/1 3:A5/3 6:E5/2 8:A5/2 10:C6/2",
                "0:B5/1 1:A5/1 2:B5/1 3:G5/3 6:D5/2 8:G5/2 10:B5/2",
                "0:A5/1 1:G5/1 2:A5/1 3:F5/3 6:C5/2 8:F5/2 10:A5/2",
                "0:G#5/1 1:F5/1 2:G#5/1 3:E5/3 6:B4/2 8:E5/2 10:G#5/2",
                "0:A5/1 1:B5/1 2:C6/1 3:E6/3 6:C6/2 8:A5/2 10:C6/2",  # la vuelta se abre: ahora la carrera sube
                "0:B5/1 1:C6/1 2:D6/1 3:G6/3 6:D6/2 8:B5/2 10:D6/2",
                "0:C6/1 1:D6/1 2:E6/1 3:F6/3 6:C6/2 8:A5/2 10:C6/2",
                "0:B5/1 1:C6/1 2:D6/1 3:E6/3 6:D6/1 7:C6/1 8:B5/2 10:G#5/2",
                "0:A5/1 1:G5/1 2:A5/1 3:F5/3 6:D5/2 8:F5/2 10:A5/2",
                "0:B5/1 1:A5/1 2:B5/1 3:G5/3 6:D5/2 8:G5/2 10:B5/2",
                "0:C6/1 1:B5/1 2:C6/1 3:G5/3 6:E5/2 8:G5/2 10:C6/2",
                "0:C6/1 1:D6/1 2:E6/1 3:F6/3 6:C6/2 8:A5/2 10:F5/2",
                "0:F5/1 1:G5/1 2:A5/1 3:D6/3 6:A5/2 8:F5/2 10:A5/2",
                "0:G#5/1 1:A5/1 2:B5/1 3:E6/3 6:B5/2 8:G#5/2 10:B5/2",
                "0:C6/1 1:D6/1 2:E6/1 3:F6/3 6:E6/1 7:D6/1 8:C6/2 10:A5/2",
                "0:G#5/1 1:A5/1 2:G#5/1 3:E5/3"],
          # B: dos golpes en la misma nota y el arpegio; luego invertido
          'B': ["0:F5/3 3:F5/3 6:A5/2 8:C6/2 10:A5/2", "0:G5/3 3:G5/3 6:C6/2 8:E6/2 10:C6/2",
                "0:A5/3 3:A5/3 6:D6/2 8:F6/2 10:D6/2", "0:C6/3 3:A5/3 6:E5/6",
                "0:F5/3 3:F5/3 6:A5/2 8:C6/2 10:F6/2", "0:E6/3 3:E6/3 6:C6/2 8:G5/2 10:E5/2",
                "0:F5/3 3:F5/3 6:Bb5/2 8:D6/2 10:F6/2", "0:E6/3 3:D6/1 4:C6/1 5:B5/1 6:G#5/6",
                "0:F5/3 3:F5/3 6:A5/2 8:C6/2 10:A5/2", "0:G5/3 3:G5/3 6:C6/2 8:E6/2 10:C6/2",
                "0:A5/3 3:A5/3 6:D6/2 8:F6/2 10:D6/2", "0:E6/3 3:C6/3 6:A5/2 8:C6/2 10:E6/2",
                "0:F6/3 3:D6/3 6:A5/2 8:D6/2 10:F6/2", "0:E6/3 3:B5/3 6:G#5/2 8:B5/2 10:E6/2",
                "0:E6/3 3:C6/3 6:D6/2 8:B5/2 10:G5/2", "0:A5/3 3:F5/3 6:G#5/6"],
          # C: la CARRERA (seis notas que suben y se clavan en las tres picadas) y la CAÍDA (tres que bajan)
          'C': ["0:A5/1 1:B5/1 2:C6/1 3:D6/1 4:E6/1 5:F6/1 6:E6/6", "0:F6/3 3:E6/1 4:D6/1 5:C6/1 6:A5/6",
                "0:D5/1 1:F5/1 2:G5/1 3:A5/1 4:B5/1 5:C6/1 6:D6/6", "0:E6/3 3:D6/1 4:C6/1 5:B5/1 6:G#5/6",
                "0:C6/1 1:D6/1 2:E6/1 3:F6/1 4:G6/2 6:A6/6", "0:A6/3 3:G6/1 4:F6/1 5:E6/1 6:D6/1 7:C6/5",
                "0:B5/1 1:C6/1 2:D6/1 3:E6/1 4:F6/2 6:G6/6", "0:E6/3 3:D6/1 4:C6/1 5:B5/1 6:G#5/6",
                "0:A5/1 1:B5/1 2:C6/1 3:D6/1 4:E6/1 5:F6/1 6:E6/6", "0:F6/3 3:E6/1 4:D6/1 5:C6/1 6:A5/6",
                "0:D5/1 1:F5/1 2:G5/1 3:A5/1 4:B5/1 5:C6/1 6:D6/6", "0:E6/3 3:D6/1 4:C6/1 5:B5/1 6:G#5/6",
                "0:C6/1 1:D6/1 2:E6/1 3:F6/1 4:G6/2 6:A6/6", "0:G6/3 3:F6/1 4:E6/1 5:D6/1 6:B5/6",
                "0:A5/1 1:B5/1 2:C6/1 3:F6/3 6:E6/1 7:D6/1 8:C6/1 9:B5/1 10:G#5/2", "0:E5/3"],
          'LL': (4, "0:E5/3 3:A5/3 6:C6/2 8:E6/4")},                  # LA LLAMADA, compás 5 de A'
    # C "tres colas": salta una 5ª y cae una 3ª; la respuesta (2+1+3 y baja). Cada dos compases, otra voz más arriba
    'C': {'A': ["0:A4/3 3:E5/3 6:C5/6", "0:B4/2 2:C5/1 3:D5/3 6:B4/2 8:G4/4",            # 1ª cola (trombón)
                "0:F5/3 3:C6/3 6:A5/6", "0:G#5/2 2:A5/1 3:B5/3 6:G#5/2 8:E5/4",          # 2ª cola (trompeta)
                "0:A5/3 3:E6/3 6:C6/6", "0:B5/2 2:C6/1 3:D6/3 6:B5/2 8:G5/4",            # 3ª cola (shanai)
                "0:A5/3 3:C6/3 6:F6/2 8:C6/2 10:A5/2", "0:B5/3 3:G#5/3 6:E6/6",          # las tres juntas
                "0:D5/3 3:A5/3 6:F5/6", "0:G5/3 3:D6/3 6:B5/6", "0:C6/3 3:G6/3 6:E6/6",  # una por compás: cada una más alta
                "0:A5/2 2:C6/1 3:F6/3 6:C6/2 8:A5/4",
                "0:A5/3 3:F6/3 6:D6/6", "0:B5/2 2:C6/1 3:B5/3 6:G#5/2 8:E5/4",
                "0:F5/3 3:C6/3 6:A5/6", "0:G#5/2 2:A5/1 3:B5/3 6:E5/6"],
          # B: una larga que baja por grados (La Sol Fa Mi · Fa Mi Re Si) y el acorde que la contesta
          'B': ["0:A5/6 6:C6/2 8:A5/2 10:F5/2", "0:G5/6 6:C6/2 8:G5/2 10:E5/2",
                "0:F5/6 6:A5/2 8:F5/2 10:D5/2", "0:E5/6 6:A5/2 8:C6/2 10:E6/2",
                "0:F6/6 6:C6/2 8:A5/2 10:C6/2", "0:E6/6 6:C6/2 8:G5/2 10:C6/2",
                "0:D6/6 6:Bb5/2 8:F5/2 10:Bb5/2", "0:B5/6 6:G#5/2 8:E5/2 10:G#5/2",
                "0:A5/6 6:C6/2 8:A5/2 10:F5/2", "0:G5/6 6:C6/2 8:G5/2 10:E5/2",
                "0:F5/6 6:A5/2 8:F5/2 10:D5/2", "0:E5/6 6:A5/2 8:C6/2 10:E6/2",
                "0:F6/6 6:D6/2 8:A5/2 10:D6/2", "0:E6/6 6:B5/2 8:G#5/2 10:B5/2",
                "0:C6/3 3:A5/3 6:B5/2 8:D6/2 10:G6/2", "0:F6/3 3:C6/3 6:B5/2 8:G#5/2 10:E5/2"],
          # C: el ESTRIBILLO — la banda da el 1 y las tres voces entran después, en acordes, en la misma nota
          'C': ["3:E6/3 6:E6/2 8:E6/2 10:C6/2", "3:F6/3 6:F6/2 8:C6/2 10:A5/2",
                "3:D6/3 6:D6/2 8:F6/2 10:A6/2", "0:G#6/6 6:E6/2 8:D6/1 9:C6/1 10:B5/2",
                "3:E6/3 6:A6/2 8:A6/2 10:E6/2", "3:F6/3 6:A6/2 8:G6/2 10:F6/2",
                "3:D6/3 6:G6/2 8:D6/2 10:B5/2", "0:E6/6 6:G#5/6",
                "3:E6/3 6:E6/2 8:E6/2 10:C6/2", "3:F6/3 6:F6/2 8:C6/2 10:A5/2",
                "3:D6/3 6:D6/2 8:F6/2 10:A6/2", "0:G#6/6 6:E6/2 8:D6/1 9:C6/1 10:B5/2",
                "3:A6/3 6:A6/2 8:G6/2 10:F6/2", "3:G6/3 6:G6/2 8:D6/2 10:B5/2",
                "0:C6/3 3:A5/3 6:B5/2 8:G#5/2 10:E5/2", "0:E5/6"],
          'LL': (0, "0:E4/3 3:A4/3 6:C5/2 8:E5/4")},                  # LA LLAMADA, compás 1 de A', en el trombón
}


def sections(v):
    M_ = MEL[v]
    i, ll = M_['LL']
    rep = list(M_['A']); rep[i] = ll
    return [('intro', H_IN, IN_CALL, 12, ''), ('A', H_A, M_['A'], 12, ''), ('B', H_B, M_['B'], 12, ''),
            ('C', H_C, M_['C'], 12, ''), ('Z', H_Z, [''] * 8, 16, ''), ('A', H_A, rep, 12, 'rep'), ('R', H_R, [''] * 4, 12, '')]


J.TRACKS[TRACK] = dict(secs=sections, bpm=BPM, scale=SCALE, tonic=(9, M.MIN), lufs=LUFS, variants=tuple(VNAME), title='Obsidiana', vname=VNAME)

# ══ EL REPARTO ══════════════════════════════════════════════════════════════════════════════════════════════════════
NYLON, OVERDRIVE, TRUMPET, TROMBONE, BRASS, SHANAI, TAIKO, CRYSTAL = 24, 29, 56, 57, 61, 111, 116, M.CRYSTAL
CLAP, CAST, WOOD_H, WOOD_L, TOM_L, TOM_H = 39, 85, 76, 77, 41, 48
ACC = {0: 104, 3: 84, 6: 100, 8: 86, 10: 94}                         # (el peso de cada acento en un rasgueo)
ACCENTS = (0, 3, 6, 8, 10)
BASS_ROOT = {9: 45, 7: 43, 5: 41, 4: 40, 2: 38, 0: 36, 10: 34}       # (la andaluza BAJA: La2 Sol2 Fa2 Mi2)
# la voz hueca del N163 bajo la melodía (el color de la casa) y la sierra del volcán
I_UNDER = {'vol': [6, 9, 10, 10, 9], 'sus': 9, 'vib': (18, 0.15, 5.2), 'duty': 2}
I_SAW = {'vol': [9, 8, 7, 7, 6], 'sus': 6, 'vib': (20, 0.12, 5.4)}
M.TIGHT_KEYS = M.TIGHT_KEYS + ('lead3',)                             # (sin cola sobre la nota siguiente, también la 3ª voz)
LEADS = ('lead', 'lead2', 'lead3', 'thirds')
B_LEAD = os.environ.get('B_LEAD', 'sierra')
I_SAW_LEAD = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.18, 6)}


class Rig(M.Rig):
    """el Rig de las montañas (GM con bancos y a tiempo) + el slap de los jefes y un canal de sierra VRC6"""
    def __init__(self, sg):
        super().__init__(sg)
        self.Cn['saw'] = Chan(len(self.Cn['lead'].f))
        self.slap = SL.Rec()
        for k in ('snare', 'crash'): self.NZ[k].exact = True          # (cada golpe en su muestra, como el siseo)

    def sl(self, b, st, n, d, vel=100):
        sg = self.sg
        self.slap.add(sg.t(b, st), sg.t(b, st) + sg.dur(b, d) * 0.95, n, vel)
        self.notes.setdefault('bass', []).append((sg.q(b, st), sg.q(b, st + d), n))

    def tk(self, b, st, d, vel):
        """el TAIKO, afinado a la raíz del acorde (su nota se oye: otra chocaría)"""
        r = self.sg.chord(b, st)[0]
        self.gm('taiko', TAIKO, b, st, 36 + (r - 36) % 12, d, vel)

    def strum(self, k, prog, b, st, d, vel, lo=52, n=5):
        """un RASGUEO: las cuerdas una tras otra, 6 ms entre ellas y centradas en el golpe (no se oye tarde)"""
        sg = self.sg
        vs = place(None, sg.chord(b, st), lo)[:n]
        t0 = sg.t(b, st) - 0.006 * (len(vs) - 1) / 2
        for i, p in enumerate(vs):
            self.gmt(k, prog, t0 + i * 0.006, sg.t(b, st) + sg.dur(b, d) * 0.92, p, vel - 4 * i)
            self.notes.setdefault(k, []).append((sg.q(b, st), sg.q(b, st + d), p))


def next_root(sg, b):
    return (sg.chords[b][0] if b < sg.NB else sg.chords[sg.INTRO][0])[0]


def under(sg, b, st, n, k):
    """la k-ésima voz por debajo de n en el acorde: nota del acorde; las notas de paso, una 3ª diatónica abajo"""
    tones = sg.tones(b, st)
    low = [p for p in range(n - 12, n) if p % 12 in tones]
    if n % 12 in tones and len(low) >= k: return low[-k]
    p = [x for x in range(n - 4, n - 2) if x % 12 in sg.scale | tones]
    return (p[0] if p else n - 3) - (k - 1) * 3 - (1 if k > 1 else 0)


# ══ LA MELODÍA, según la variante ═══════════════════════════════════════════════════════════════════════════════════
def play_melody(sg, R, v):
    thirds = []
    for b, st, n, d in sg.mel:
        tag, var, k = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1]
        strong = tag == 'C' or var == 'rep'
        if v == 'A':
            R.gm('lead', TRUMPET, b, st, n, d, 108 if strong else 100, gate=0.97)
            R.chip('cm', b, st, n - 12, d, I_UNDER, q=F.q_n163, release=3)
            if strong: R.chip('saw', b, st, n - 12, d, I_SAW, q=F.q_saw, release=2)
            if var == 'rep': thirds.append(b)
        elif v == 'B':
            # (la voz, del chip: el usuario eligió la B "con otro instrumento en lugar de la guitarra saturada, quizá uno clásico de
            #  NES". sierra: la sierra del VRC6, la del volcán, la ELEGIDA · B_LEAD=pulso: el 2A03 con barrido de ciclo)
            if B_LEAD == 'sierra':
                R.chip('saw', b, st, n - 12, d, I_SAW_LEAD, q=F.q_saw, release=3)
            else:
                R.chip('lead', b, st, n, d, J.I_PULSE, release=3)
                R.chip('saw', b, st, n - 12, d, I_SAW, q=F.q_saw, release=2)
            if strong and n + 12 <= 96: R.chip('dbl', b, st, n + 12, d, J.I_DBL, release=2)
        else:
            # las tres colas: cada una con su registro; la melodía del compás la canta la que toca, y juntas al final
            whose = voices_c(tag, k)
            if 'lead2' in whose and len(whose) == 1:
                R.gm('lead2', TROMBONE, b, st, n, d, 108, gate=0.97)
            elif 'lead3' in whose and len(whose) == 1:
                R.gm('lead3', SHANAI, b, st, n, d, 104, gate=0.97)
            elif len(whose) == 1:
                R.gm('lead', TRUMPET, b, st, n, d, 102, gate=0.97)
            else:
                R.gm('lead', TRUMPET, b, st, n, d, 106, gate=0.97)
                R.gm('lead3', SHANAI, b, st, under(sg, b, st, n, 1), d, 92, gate=0.97)
                R.gm('lead2', TROMBONE, b, st, under(sg, b, st, n, 2) - 12, d, 100, gate=0.97)
            if strong: R.chip('cm', b, st, n - 12, d, I_UNDER, q=F.q_n163, release=3)
    if thirds: J.thirds(sg, R, set(thirds), TRUMPET, 82)


def voices_c(tag, k):
    """quién canta cada compás en la variante C"""
    if tag == 'C': return ('lead', 'lead2', 'lead3')
    if tag == 'A':
        return {1: ('lead2',), 2: ('lead2',), 3: ('lead',), 4: ('lead',), 5: ('lead3',), 6: ('lead3',), 9: ('lead2',), 10: ('lead',),
                11: ('lead3',)}.get(k, ('lead', 'lead2', 'lead3'))
    if tag == 'B': return ('lead',) if k <= 8 else ('lead3',)
    return ('lead',)


# ══ EL ARREGLO (el mismo en las tres) ═══════════════════════════════════════════════════════════════════════════════
def bass_bar(sg, R, b, heavy):
    """el slap en 3+3+2+2+2: raíz, octava (pop), 5ª, raíz y la nota que se acerca por grado a la raíz siguiente"""
    def r0(st):
        r, q = sg.chord(b, st)
        return BASS_ROOT.get(r, 36 + (r - 36) % 12)
    nx = BASS_ROOT.get(next_root(sg, b), 40)
    here = sg.chord(b, 10)[0]
    if here == next_root(sg, b):
        ap = r0(10) + 7
    else:
        c = [p for p in (nx + 2, nx - 2, nx + 1, nx - 1) if p % 12 in sg.scale | sg.tones(b, 10) and not R.rub(b, 10, p, 2, voice=LEADS)]
        ap = c[0] if c else r0(10)
    if heavy: R.sl(b, 0, r0(0), 2, 112); R.sl(b, 2, r0(0), 1, 78)
    else: R.sl(b, 0, r0(0), 3, 106)
    R.sl(b, 3, r0(3) + 12, 3, 112)
    R.sl(b, 6, r0(6) + 7, 2, 96)
    R.sl(b, 8, r0(8), 2, 104)
    R.sl(b, 10, ap, 2, 94)


def stab(sg, R, b, vel=102, sts=(6, 8, 10)):
    """las TRES PICADAS: metal y taiko en un acorde (sin 2ª menor, 7ª mayor ni tritono con quien canta)"""
    for st in sts:
        for n in place(None, sg.chord(b, st), 60)[:4]:
            if not R.rub(b, st, n, 2, voice=LEADS): R.gm('stab', BRASS, b, st, n, 2, vel, gate=0.7)
        R.tk(b, st, 2, 96 + (st - 6) * 3)


def glass(sg, R, b):
    """el ACENTO: tres notas del acorde de VIDRIO, donde la melodía no da golpes (de las tres picadas en adelante)"""
    if any(m[0] == b and m[1] >= 6 for m in sg.mel): return
    p = place(None, sg.chord(b, 6), 76)[:3]
    for st, n in zip((6, 8, 10), p):
        if not R.rub(b, st, n, 2, voice=LEADS): R.gm('accent', CRYSTAL, b, st, n, 2, 92)


def ending(sg, R, b):
    """el último compás de la intro y de la R (iguales, para que la costura y la entrada sean la misma): un rasgueo y las
    tres picadas de toda la banda, cada vez más fuerte; suena el silencio que queda antes del 1"""
    R.strum('guit', NYLON, b, 0, 3, 100)
    R.sl(b, 0, 40, 3, 106)
    R.kick(b, 0)
    for i, st in enumerate((6, 8, 10)):
        R.strum('guit', NYLON, b, st, 1, 92 + 6 * i)
        R.sl(b, st, 40 + (0, 7, 12)[i], 1, 100 + 5 * i)
        R.kick(b, st); R.snare(b, st, 0.7 + 0.1 * i)
        R.dr('palmas', b, st, CLAP, 96)
    stab(sg, R, b, 100)


def bar_12(sg, R, b, v):
    tag, var, k, L = sg.tag[b - 1], sg.var[b - 1], sg.pos[b - 1], sg.slen[b - 1]
    rep = var == 'rep'
    if tag in ('intro', 'R') and k == L: return ending(sg, R, b)
    level = {'intro': 0, 'R': 1, 'A': 2, 'B': 2, 'C': 4}[tag] + (1 if rep else 0)
    sparse_B = tag == 'B' and k <= 8                                   # la queja: poca banda
    last = k == L
    # ── LA GUITARRA: rasgueo en los acentos (en B, dos solos y el punteo) ──
    if tag == 'intro':
        for st in ACCENTS: R.strum('guit', NYLON, b, st, 2 if st >= 6 else 3, ACC[st] - (14 if k <= 2 else 4))
    elif sparse_B:
        for st in (0, 6): R.strum('guit', NYLON, b, st, 6, ACC[st] - 12)
    else:
        for st in ACCENTS: R.strum('guit', NYLON, b, st, 2 if st >= 6 else 3, ACC[st])
    # ── EL PUNTEO de la guitarra en corcheas (B): el acorde que sube y baja ──
    if tag == 'B':
        for st in range(12):
            c = place(None, sg.chord(b, st), 60)[:4]
            n = c[(0, 1, 2, 3, 2, 1)[st % 6]]
            if not R.rub(b, st, n, 1, voice=LEADS): R.gm('arp', NYLON, b, st, n, 1, 72 + (10 if st in ACCENTS else 0), gate=1.0)
    # ── EL COLCHÓN ──
    if tag == 'C' or rep or (tag == 'B' and k > 8):
        for half in (0, 1):
            r, q = sg.chords[b - 1][half]
            base = 53 + (r - 53) % 12
            for j, iv in enumerate(q[1:]):
                R.chip(('pad1', 'pad2')[j], b, half * 6, base + iv, 6, M.I_PAD, q=F.q_n163, gate=0.97, release=5)
    # ── EL BAJO ──
    if tag != 'intro' or k >= 3:
        if tag == 'intro' and k < 5:
            R.sl(b, 0, BASS_ROOT[sg.chord(b, 0)[0]], 6, 104); R.sl(b, 6, BASS_ROOT[sg.chord(b, 6)[0]] + 12, 3, 100); R.sl(b, 10, BASS_ROOT[sg.chord(b, 6)[0]] + 7, 2, 90)
        elif sparse_B:
            R.sl(b, 0, BASS_ROOT[sg.chord(b, 0)[0]], 6, 100); R.sl(b, 6, BASS_ROOT[sg.chord(b, 0)[0]] + 7, 2, 92); R.sl(b, 10, BASS_ROOT[sg.chord(b, 0)[0]], 2, 90)
        else:
            bass_bar(sg, R, b, heavy=level >= 3)
    # ── LAS PALMAS y las castañuelas ──
    if tag != 'intro' or k >= 2:
        hits = (6, 10) if sparse_B else (3, 6, 8, 10)
        for st in hits: R.dr('palmas', b, st, CLAP, 92 if st in (6, 10) else 72)
    if (tag == 'intro' and k >= 3) or tag == 'C' or rep or (tag == 'B' and k > 8):
        for st, vv in ((9, 62), (10, 84), (11, 58)): R.dr('cast', b, st, CAST, vv)
        if level >= 4: R.dr('cast', b, 4, CAST, 60); R.dr('cast', b, 5, CAST, 72)
    # ── LA BATERÍA ──
    if tag == 'intro' and k < 5: pass
    elif sparse_B:
        R.kick(b, 0, 0.9)
        if k % 2 == 0: R.kick(b, 8, 0.75)
        R.dr('wood', b, 6, WOOD_L, 74)
    else:
        for st in (0, 3, 8): R.kick(b, st, 1.0 if st == 0 else 0.8)
        for st in (6, 10): R.snare(b, st, 0.9)
        if level >= 4: R.kick(b, 6, 0.8); R.kick(b, 10, 0.7); R.snare(b, 8, 0.55)
    if not (tag == 'intro' and k < 5):
        for st in range(12):
            if sparse_B and st % 3: continue
            R.NZ['hat'].hit(sg.t(b, st), 1, J.HAT if st in ACCENTS else [3, 1])
    if k == 1 and tag != 'intro': R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N); R.tk(b, 0, 3, 108)
    if k == 9 and tag in ('A', 'B', 'C'): R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N); R.tk(b, 0, 3, 96)
    # ── LAS TRES PICADAS con metal: donde cierra una frase del estribillo y al final de cada mitad ──
    if (tag == 'C' and k % 4 == 0 and k != 16) or (tag == 'A' and k in (8, 16)) or (tag == 'B' and k == 8) or (tag == 'C' and k == 16):
        stab(sg, R, b)
    if tag in ('A', 'B', 'C'): glass(sg, R, b)
    # ── REDOBLE antes de una sección nueva ──
    if last and tag in ('A', 'B', 'C') and not rep:
        for st in (7, 9, 11): R.snare(b, st, 0.5)


def bar_z(sg, R, b):
    """EL ZAPATEADO (4/4, 16 semicorcheas, el mismo compás de 1,5 s): el slap solo y los pies"""
    k, L = sg.pos[b - 1], sg.slen[b - 1]
    r = BASS_ROOT.get(sg.chord(b, 0)[0], 40)
    r2 = BASS_ROOT.get(sg.chord(b, 8)[0], 40)
    if k < L:
        for st, deg, d, vv in ((0, 0, 2, 112), (3, 0, 1, 84), (4, 12, 2, 114), (6, 0, 1, 80), (7, 7, 1, 92), (8, 0, 2, 108),
                               (10, 12, 1, 106), (11, 0, 1, 78), (12, 7, 2, 96), (14, 12, 1, 104), (15, 7, 1, 88)):
            R.sl(b, st, (r if st < 8 else r2) + deg, d, vv)
    else:
        for st in (0, 4, 8): R.sl(b, st, r + (0, 7, 12)[st // 4], 3, 112)
    # los pies: planta y tacón en semicorcheas, y el taiko de golpe
    if k < L:
        for st in range(16):
            R.dr('wood', b, st, WOOD_H if st % 4 == 0 else WOOD_L, (86 if st % 4 == 0 else 50 if st % 2 else 64) + 3 * k)
        for st in (0, 6, 8, 14) if k % 2 else (0, 3, 8, 11): R.tk(b, st, 2, 102 + k)
        for st in (4, 12): R.dr('palmas', b, st, CLAP, 92)
        if k >= 5:
            for st in (0, 8): R.kick(b, st, 0.95)
            for st in (4, 12): R.snare(b, st, 0.85)
            for st in range(0, 16, 2): R.NZ['hat'].hit(sg.t(b, st), 1, J.HAT)
        if k >= 3 and k % 2: R.dr('cast', b, 14, CAST, 74); R.dr('cast', b, 15, CAST, 86)
    else:
        for st in (0, 4, 8):                                           # (las tres picadas, ahora a negras)
            R.strum('guit', NYLON, b, st, 2, 106)
            R.kick(b, st); R.snare(b, st, 0.9)
            for n in place(None, sg.chord(b, st), 60)[:4]: R.gm('stab', BRASS, b, st, n, 2, 104, gate=0.7)
            R.tk(b, st, 2, 110)
        for i, st in enumerate(range(12, 16)):                         # redoble de toms que sube hacia la vuelta del tema
            R.dr('wood', b, st, TOM_L + i * 2, 78 + 8 * i)
    if k == 1:
        R.NZ['crash'].hit(sg.t(b, 0), 3, J.CRASH_N)
        R.strum('guit', NYLON, b, 0, 4, 104)


def arrange(sg, R, v):
    play_melody(sg, R, v)
    for b in range(1, sg.NB + 1):
        if sg.steps[b - 1] == 16: bar_z(sg, R, b)
        else: bar_12(sg, R, b, v)


# ══ LA MEZCLA ═══════════════════════════════════════════════════════════════════════════════════════════════════════
LV = {'lead': 0, 'lead2': -3, 'lead3': -5, 'thirds': -6, 'cm': -10, 'saw': -10, 'dbl': -10,
      'guit': -4, 'arp': -6, 'stab': -3, 'pad': -9, 'accent': -2, 'bass': -1,
      'kick': -1, 'snare': 0, 'taiko': -4, 'palmas': -8, 'cast': -6, 'wood': -5, 'hat': -9, 'crash': -7}
LEAD_GROUP = ('lead', 'lead2', 'lead3', 'thirds')
DRUM_GROUP = ('kick', 'snare', 'taiko', 'palmas', 'cast', 'wood', 'hat', 'crash')
ACC_GROUP = ('guit', 'arp', 'stab', 'pad', 'accent', 'cm', 'saw', 'dbl')
BACKING = 2.5                                                         # dB (como las montañas: el juego se come el fondo)


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
    if np.abs(R.Cn['saw'].v).max() > 0: S['saw'] = cut(F.render_saw(R.Cn['saw']) * 0.0035)
    if v == 'B' and B_LEAD == 'sierra': S['lead'] = S.pop('saw')
    from scipy.signal import butter, sosfilt
    hp = butter(2, 30, btype='high', fs=SR, output='sos')
    S = {k: sosfilt(hp, x) for k, x in S.items() if np.abs(x).max() > 0}
    ref = 'lead'
    g = GN.level(S, {k: LV.get(k, -10) + (0 if k in LEAD_GROUP else BACKING) for k in S}, ref)
    x = sum(S[k] * g[k] for k in S)
    sd = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd('guit', 0.25) - sd('arp', 0.3) + sd('palmas', 0.3) - sd('cast', 0.3) + sd('accent', 0.35) - sd('lead2', 0.2) \
        + sd('lead3', 0.2) - sd('thirds', 0.15) + sd('stab', 0.12) - sd('wood', 0.2)
    Lx, Rx = x + side, x - side
    st = np.stack([GN.fold(Lx, n, at), GN.fold(Rx, n, at)], 1)            # (la cola, sobre el principio del bucle)
    st = F.master(st, lufs=LUFS, ceiling=0.72 if v == 'B' else CEILING)   # (la B: el OGG subía el pico a 0,98)
    S = {k: GN.fold(s, n, at) for k, s in S.items()}
    return sg, R, S, g, st, n, at


# ══ INFORME (números: NO se ha escuchado) ═══════════════════════════════════════════════════════════════════════════
def melody_numbers(sg):
    mel = [m for m in sg.mel if sg.tag[m[0] - 1] != 'intro']
    bars = sorted({m[0] for m in mel})
    tones = [m[2] % 12 in sg.tones(m[0], m[1]) for m in mel]
    d16 = lambda m: sg.q(m[0], m[1] + m[3]) - sg.q(m[0], m[1])
    on1 = [m for m in mel if m[1] == 0]
    longs = [m for m in mel if d16(m) >= 4]
    per = {b: [m for m in mel if m[0] == b] for b in bars}
    bl = [abs(per[b + 1][0][2] - per[b][-1][2]) for b in bars if b + 1 in per]
    rhy = {}
    for b in bars:
        key = tuple(m[1] for m in per[b]); rhy[key] = rhy.get(key, 0) + 1
    top3 = sum(sorted(rhy.values())[-3:]) / len(bars)
    iv = np.diff([m[2] for m in mel])
    rev = [np.sign(a) != np.sign(b) for a, b in zip(iv, iv[1:]) if abs(a) >= 5 and b != 0]
    return dict(notes=len(mel), lo=nm(min(m[2] for m in mel)), hi=nm(max(m[2] for m in mel)), ct=np.mean(tones), ct1=np.mean([m[2] % 12 in sg.tones(m[0], 0) for m in on1]),
                ctl=np.mean([m[2] % 12 in sg.tones(m[0], m[1]) for m in longs]), acc=np.mean([m[1] in ACCENTS for m in mel]),
                bl=np.mean(bl), bl2=np.mean(np.array(bl) <= 2), rhythms=len(rhy), top3=top3, meaniv=np.mean(np.abs(iv)), rev=np.mean(rev),
                long=np.mean([d16(m) >= 4 for m in mel]))


def report(v, sg, R, S, g, y, n, at):
    print(f'── {TRACK} variante {v} "{VNAME[v]}"')
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    grp = lambda ks: 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ks if k in S) / tot
    bar = sg.BAR * SR
    lufs = F.loudness(y)
    print(f'  {sg.NB} compases: intro {sg.INTRO} = {at} muestras ({at / SR:.2f} s) + bucle {sg.NB - sg.INTRO} = {n - at} muestras ({(n - at) / SR:.2f} s) · {lufs:.1f} LUFS, pico {np.abs(y).max():.2f}')
    print(f'  energía: melodía {grp(LEAD_GROUP):.0f} %, batería {grp(DRUM_GROUP):.0f} %, bajo {grp(("bass",)):.0f} %, acompañamiento {grp(ACC_GROUP):.0f} %')
    print('  ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    lb, lo, out, off = J.check(sg)
    lo = [x for x in lo if not (x[2][0] == 'F' and sg.chord(x[0], x[1])[0] == 4)]                    # (Fa → Sol# sobre Mi: es el color; no cuenta)
    out = [x for x in out if not (x[2].startswith('G') and x[2][1] != 'b' and sg.chord(x[0], x[1])[0] == 4)]
    mn = melody_numbers(sg)
    print(f'  melodía: {mn["notes"]} notas {mn["lo"]}-{mn["hi"]} · a contratiempo {100 * off:.0f} % · en los acentos del compás {100 * mn["acc"]:.0f} % · del acorde {100 * mn["ct"]:.0f} % (tiempo 1: {100 * mn["ct1"]:.0f} %, largas: {100 * mn["ctl"]:.0f} %)')
    print(f'    entre compases {mn["bl"]:.1f} st ({100 * mn["bl2"]:.0f} % ≤ 2) · intervalo medio {mn["meaniv"]:.2f} · tras un salto cambia de sentido {100 * mn["rev"]:.0f} % · ritmos distintos {mn["rhythms"]}, los 3 más usados {100 * mn["top3"]:.0f} % · largas {100 * mn["long"]:.0f} %')
    print(f'    largas fuera del acorde: {lb or "ninguna"}; sueltas: {lo or "ninguna"}; fuera de escala: {out or "ninguna"}')
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
    if v == 'C':
        cross = []
        ms = {k: R.notes.get(k, []) for k in ('lead', 'lead2', 'lead3')}
        for a, b_ in (('lead', 'lead2'), ('lead', 'lead3'), ('lead2', 'lead3')):
            for q0, q1, n1 in ms[a]:
                for q2, q3, n2 in ms[b_]:
                    if q0 < q3 and q2 < q1 and min(q1, q3) - max(q0, q2) >= 2 and (n1 - n2) % 12 in (1, 6, 11): cross.append((int(q0 // 16) + 1, nm(n1), nm(n2)))
        print(f'    choques entre las tres voces (≥ corchea): {len(cross)} {cross[:8]}')
    ln, bars, jr, dbs, ji, dbi = M.seam_numbers(y, at, bar, [(b0 - 1) * sg.BAR * SR for b0 in sg.starts[2:]])
    print(f'  BUCLE: {ln} muestras = {bars:.4f} compases; costura: salto {jr:.2f}× el de otro tiempo 1 de sección, {dbs:+.1f} dB; intro → bucle {ji:.2f}×, {dbi:+.1f} dB')
    span = lambda b0, L_: (int((b0 - 1) * sg.BAR * SR), int((b0 - 1 + L_) * sg.BAR * SR))
    def db(a, b_):
        z = sum(S[k][a:b_] * g[k] for k in S)
        return 10 * np.log10(np.mean(np.asarray(z) ** 2) + 1e-12)
    r0 = db(*span(sg.starts[1], 16))
    print('  sonoridad por sección vs A (dB): ' + ' '.join(f'{sg.tag[b0 - 1]} {db(*span(b0, sg.slen[b0 - 1])) - r0:+.1f}' for b0 in sg.starts))
    return dict(lufs=lufs, loop=n - at, intro=at, bars=bars, jr=jr, off=off, nlb=len(lb), nlo=len(lo), nout=len(out), ncl=tot_cl, mn=mn)


def mmss(t):
    return f'{int(t // 60)}:{t % 60:04.1f}'


def readme(sg, nums):
    desc = {'intro': 'INTRO: guitarra y palmas; la llamada de la voz', 'A': 'A: el tema (andaluza; 2ª mitad, círculo de quintas)',
            'B': 'B: la queja (voz baja, el giro oscuro Si♭ → Mi; la 2ª mitad crece)', 'C': 'C: el estribillo, lo más alto',
            'Z': 'Z: EL ZAPATEADO, solo de slap y pies en 4/4, sin melodía', 'R': "R: vuelve, y las tres picadas antes del 1"}
    t = ['OBSIDIANA — tema de jefe del escorpión de obsidiana de tres colas (isla del volcán)',
         'tools/music/obsidiana.py. NO SE HA ESCUCHADO: comprobado solo con números. El oído es el tuyo.',
         '',
         'La idea: el volcán vive en frigio, el modo del flamenco: una BULERÍA de fuego. Compás de 12 pasos 3+3+2+2+2, ritmo',
         'nuevo en el juego: la cola se levanta (3+3) y pica tres veces (2+2+2). La menor; cadencia andaluza La m-Sol-Fa-Mi.',
         'Guitarra española, palmas, castañuelas y taiko sobre el slap, el DPCM y el N163 de la casa.',
         '',
         'LAS TRES VARIANTES (misma armonía y forma, otra melodía):',
         '  A saeta       cantada en trompeta, frases largas: sube el acorde y baja por grados, y se contesta en secuencia.',
         '  B picado      guitarra saturada: vuelta rápida, nota larga y tres golpes subiendo; estribillo de carreras y caídas.',
         '  C tres_colas  un salto de 5ª y una caída, pasados entre trombón, trompeta y shanai; juntas en acordes al final.',
         '',
         'ARCHIVOS, en cada variante: obsidiana_<v>_preview.mp3 / .ogg (intro + bucle dos veces), _intro.ogg, _loop.ogg, .mid (melodía y bajo).',
         '',
         'SECCIONES (tiempos de la previa; igual en las tres):']
    for b0 in sg.starts:
        t.append(f'  {mmss((b0 - 1) * sg.BAR)}  {desc[sg.tag[b0 - 1]]}' + ("  (la vuelta del tema, con la llamada, colchón y más metal)" if sg.var[b0 - 1] == 'rep' else ''))
    lp = (sg.NB - sg.INTRO) * sg.BAR
    t.append(f'  {mmss(sg.NB * sg.BAR)}  el bucle empieza otra vez (segunda vuelta: mismas secciones + {mmss(lp)})')
    t += [f'  {mmss((sg.NB + sg.NB - sg.INTRO) * sg.BAR)}  fin de la previa', '', 'NÚMEROS:'] + nums
    t += ['', 'A JUZGAR DE OÍDO: si la melodía canta sobre el compás 3+3+2+2+2 o se siente forzada (y en qué tiempo); la trompeta y el shanai',
          'del soundfont; el salto 12 → 16 → 12 pasos del zapateado (' + mmss((sg.starts[4] - 1) * sg.BAR) + '); si el flamenco le pega al escorpión.']
    return '\n'.join(t) + '\n'


def enc_mp3(y, path):
    wav = path[:-4] + '.wav'
    F.write_wav(wav, y)
    os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libmp3lame -q:a 2 "{path}"')
    os.remove(wav)


if __name__ == '__main__':
    which = [a for a in sys.argv[1:] if a in VNAME] or list(VNAME)
    if os.environ.get('INSTALL'): which = [os.environ.get('OBSIDIANA', 'A')]
    os.makedirs(PRUEBAS, exist_ok=True)
    nums = []
    for v in which:
        sg, R, S, g, y, n, at = build(v)
        r = report(v, sg, R, S, g, y, n, at)
        mn = r['mn']
        nums.append(f'  {v} {VNAME[v]}: intro {r["intro"]} muestras ({r["intro"] / SR:.2f} s) + bucle {r["loop"]} ({r["loop"] / SR:.2f} s = {r["bars"]:.4f} compases), '
                    f'{r["lufs"]:.1f} LUFS; del acorde {100 * mn["ct"]:.0f} %, largas fuera {r["nlb"]}, sueltas {r["nlo"]}, choques {r["ncl"]}; costura {r["jr"]:.2f}×')
        if os.environ.get('REPORT'): continue
        if os.environ.get('INSTALL'):
            J.export(y, at, os.path.join(INSTALL_DIR, TRACK))
            J.write_mid(os.path.join(F.MID_DIR, TRACK + '.mid'), sg, R)
            print(f'  instalada: {INSTALL_DIR}/{TRACK}_intro|_loop.ogg')
            continue
        base = os.path.join(PRUEBAS, f'{TRACK}_{v}_{VNAME[v]}' + (f'_{B_LEAD}' if v == 'B' else ''))
        J.export(y, at, base)
        pv = np.concatenate([y, y[at:]])
        J.enc(pv, base + '_preview.ogg')
        enc_mp3(pv, base + '_preview.mp3')
        J.write_mid(base + '.mid', sg, R)
    if not os.environ.get('REPORT') and not os.environ.get('INSTALL') and len(which) == len(VNAME):
        with open(os.path.join(PRUEBAS, 'LEEME.txt'), 'w') as f:
            f.write(readme(sg, nums))
        print(f'  previas en {PRUEBAS}')
