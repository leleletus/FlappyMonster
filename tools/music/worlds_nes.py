#!/usr/bin/env python3
# tools/music/worlds_nes.py
# La música de NIVEL de cada isla (música de Famicom; motor: famicom.py), según docs/musica/GUIA_MUSICAL.md:
# una idea por pieza, frases de 8 compases (intro 4 · A · A' · B · A''), más de la mitad de la melodía a
# contratiempo, un compás con el tresillo 3+3+2, y la cita de "la llamada" (el motivo del juego: 5ª-1ª-3ª-5ª, el
# arranque de la música del mapa) al cerrar la frase B, sobre SU acorde. Bucle sin costura.
#
#   PRADERA (Sol mayor, pulso cantarín, bajo saltarín 1-5-8-5, acordes a contratiempo, batería ligera, trino):
#     pradera_1      el TEMA de la pradera (136 BPM). Tres variantes para elegir (--variante A|B|C):
#                      A  melodía a saltitos sobre el tresillo, con la subida pentatónica Sol-La-Si-Re
#                      B  melodía "de canción", en corcheas y por grados
#                      C  la A con flauta (tabla de onda) en vez de pulso, algo más rápida (140)
#     pradera_2      su segunda cara: "Galope", Do mayor, 144 BPM, ritmo de galope y flauta (otra tonalidad, otro
#                    ritmo y otro timbre; las versiones en Mi menor no le encajaron al usuario)
#     pradera_bonus  el tema a 152 BPM con batería de "competición" y un SOLO DE PERCUSIÓN de 8 compases antes de la
#                    última vuelta (la arena de Rey de la Colina de la isla)
#
#   python3 tools/music/worlds_nes.py pradera_1 [--variante B] | pradera_2 | pradera_bonus | previas
#   `previas` = las tres variantes de pradera_1 en FlappyMonster_pruebas/musica/ (fuera del repo), sin tocar el juego.
#   REPORT=1 → solo números. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_n163, q_tri, q_pulse, q_saw
import tentacle_nes as TN
import gloomy_nes as GN

MAJ, MIN = (0, 4, 7), (0, 3, 7)
C, D, E, G, A, B = 0, 2, 4, 7, 9, 11
D4, E4, G4, A4, B4, C5, D5, E5, Fs5, G5, A5, B5, D6 = 62, 64, 67, 69, 71, 72, 74, 76, 78, 79, 81, 83, 86

# ── PRADERA: la melodía (compás de la frase, semicorchea, nota, duración en semicorcheas) ──
# Frase A, variante A: a saltitos; golpes en 0-3-6 (3+3+2) y la subida pentatónica Sol-La-Si-Re
A_HOP = [
    (1, 0, G4, 3), (1, 3, A4, 3), (1, 6, B4, 2), (1, 8, D5, 4), (1, 12, B4, 2), (1, 14, D5, 2),
    (2, 0, E5, 3), (2, 3, D5, 3), (2, 6, B4, 2), (2, 8, D5, 6),
    (3, 0, G5, 3), (3, 3, E5, 3), (3, 6, D5, 2), (3, 8, E5, 4), (3, 12, D5, 2), (3, 14, B4, 2),
    (4, 0, C5, 3), (4, 3, E5, 3), (4, 6, G5, 2), (4, 8, E5, 6),
    (5, 0, G4, 3), (5, 3, A4, 3), (5, 6, B4, 2), (5, 8, D5, 4), (5, 12, B4, 2), (5, 14, D5, 2),
    (6, 0, Fs5, 3), (6, 3, E5, 3), (6, 6, D5, 2), (6, 8, A4, 4), (6, 12, D5, 2), (6, 14, Fs5, 2),
    (7, 0, G5, 2), (7, 2, E5, 2), (7, 4, C5, 2), (7, 6, E5, 2), (7, 8, Fs5, 2), (7, 10, D5, 2), (7, 12, A4, 2), (7, 14, D5, 2),
]
A_HOP_END = [(8, 0, B4, 2), (8, 2, D5, 2), (8, 4, G5, 8)]                       # cierra abajo (pregunta)
A_HOP_END2 = [(8, 0, G5, 3), (8, 3, A5, 3), (8, 6, B5, 2), (8, 8, G5, 8)]        # cierra arriba (respuesta)
# Frase A, variante B: "de canción", en corcheas y por grados
A_SONG = [
    (1, 0, D5, 2), (1, 2, E5, 2), (1, 4, D5, 2), (1, 6, B4, 2), (1, 8, G4, 2), (1, 10, B4, 2), (1, 12, D5, 4),
    (2, 0, E5, 2), (2, 2, G5, 2), (2, 4, E5, 2), (2, 6, D5, 2), (2, 8, B4, 6), (2, 14, D5, 2),
    (3, 0, E5, 2), (3, 2, Fs5, 2), (3, 4, G5, 4), (3, 8, E5, 2), (3, 10, D5, 2), (3, 12, B4, 4),
    (4, 0, C5, 2), (4, 2, D5, 2), (4, 4, E5, 4), (4, 8, G5, 8),
    (5, 0, D5, 2), (5, 2, E5, 2), (5, 4, D5, 2), (5, 6, B4, 2), (5, 8, G4, 2), (5, 10, B4, 2), (5, 12, D5, 4),
    (6, 0, Fs5, 2), (6, 2, E5, 2), (6, 4, D5, 2), (6, 6, A4, 2), (6, 8, D5, 2), (6, 10, E5, 2), (6, 12, Fs5, 4),
    (7, 0, G5, 2), (7, 2, E5, 2), (7, 4, C5, 4), (7, 8, A4, 2), (7, 10, D5, 2), (7, 12, Fs5, 4),
]
A_SONG_END = [(8, 0, G5, 10)]
A_SONG_END2 = [(8, 0, G5, 4), (8, 4, B5, 4), (8, 8, G5, 8)]
# Frase B (contraste: más alta y en notas largas) y, al cerrar, LA LLAMADA: Re-Sol-Si-Re sobre Sol
PH_B = [
    (1, 0, C5, 4), (1, 4, E5, 4), (1, 8, G5, 6), (1, 14, E5, 2),
    (2, 0, D5, 6), (2, 6, B4, 2), (2, 8, G4, 4), (2, 12, B4, 4),
    (3, 0, C5, 4), (3, 4, E5, 4), (3, 8, A5, 6), (3, 14, G5, 2),
    (4, 0, Fs5, 6), (4, 6, E5, 2), (4, 8, D5, 8),
    (5, 0, E5, 3), (5, 3, G5, 3), (5, 6, E5, 2), (5, 8, C5, 3), (5, 11, E5, 3), (5, 14, G5, 2),
    (6, 0, D5, 3), (6, 3, G5, 3), (6, 6, D5, 2), (6, 8, B4, 3), (6, 11, D5, 3), (6, 14, G5, 2),
    (7, 0, A5, 2), (7, 2, G5, 2), (7, 4, E5, 2), (7, 6, C5, 2), (7, 8, D5, 2), (7, 10, Fs5, 2), (7, 12, A5, 4),
    (8, 0, D5, 4), (8, 4, G5, 2), (8, 6, B5, 2), (8, 8, D6, 6),
]
CH_A = [(G, MAJ), (G, MAJ), (E, MIN), (C, MAJ), (G, MAJ), (D, MAJ), (C, MAJ), (G, MAJ)]
CH_A7 = (D, MAJ)                                  # (el compás 7 de A: Do | Re, medio compás cada uno)
CH_B = [(C, MAJ), (G, MAJ), (A, MIN), (D, MAJ), (C, MAJ), (G, MAJ), (A, MIN), (G, MAJ)]
INTRO = 4

G_MAJOR = [0, 2, 4, 5, 7, 9, 11]                  # (grados desde Do: la escala de Sol mayor = Do# no, Fa#)


def shift_diatonic(n, steps, scale=(7, 9, 11, 0, 2, 4, 6)):
    """Mueve una nota `steps` grados dentro de Sol mayor (para pasar el tema a Mi menor: 2 grados abajo)"""
    pcs = list(scale)
    pc, octv = n % 12, n // 12
    i = pcs.index(pc) if pc in pcs else min(range(7), key=lambda k: abs(pcs[k] - pc))
    j = i + steps
    # (la escala empieza en Sol: al pasar de Fa# a Sol hacia arriba sube la "octava de la escala")
    order = sorted(range(7), key=lambda k: pcs[k])
    abs_ = [octv * 12 + pcs[k] for k in range(7)]
    idx = order.index(i) + steps
    o2, k2 = divmod(idx, 7)
    return (octv + o2) * 12 + pcs[order[k2]]


# ── PRADERA 2: tema PROPIO en Mi menor (no el de pradera_1 transportado: al usuario le sonó parecido y con roces
# armónicos). Mismo aire — golpes 3+3+2, subida pentatónica (aquí Mi-Sol-La-Si) —, otra melodía y armonía de menor
# con su dominante (Si mayor: Re#).
E4m, Ds5 = 64, 75
M_A = [
    (1, 0, E5, 3), (1, 3, B4, 3), (1, 6, E5, 2), (1, 8, G5, 4), (1, 12, Fs5, 2), (1, 14, E5, 2),
    (2, 0, B4, 3), (2, 3, G4, 3), (2, 6, B4, 2), (2, 8, E5, 6),
    (3, 0, E5, 3), (3, 3, C5, 3), (3, 6, E5, 2), (3, 8, G5, 4), (3, 12, E5, 2), (3, 14, C5, 2),
    (4, 0, D5, 3), (4, 3, Fs5, 3), (4, 6, A5, 2), (4, 8, Fs5, 6),
    (5, 0, E5, 3), (5, 3, B4, 3), (5, 6, E5, 2), (5, 8, G5, 4), (5, 12, Fs5, 2), (5, 14, E5, 2),
    (6, 0, G5, 3), (6, 3, E5, 3), (6, 6, C5, 2), (6, 8, E5, 4), (6, 12, G5, 2), (6, 14, E5, 2),
    (7, 0, A5, 2), (7, 2, E5, 2), (7, 4, C5, 2), (7, 6, E5, 2), (7, 8, Fs5, 2), (7, 10, Ds5, 2), (7, 12, B4, 2), (7, 14, Ds5, 2),
]
M_END = [(8, 0, E5, 2), (8, 2, G5, 2), (8, 4, B5, 8)]
M_END2 = [(8, 0, E5, 3), (8, 3, G5, 3), (8, 6, B5, 2), (8, 8, E5, 8)]
M_B = [
    (1, 0, G5, 6), (1, 6, E5, 2), (1, 8, C5, 4), (1, 12, E5, 4),
    (2, 0, D5, 6), (2, 6, B4, 2), (2, 8, G4, 4), (2, 12, B4, 4),
    (3, 0, C5, 4), (3, 4, E5, 4), (3, 8, A5, 6), (3, 14, G5, 2),
    (4, 0, Fs5, 6), (4, 6, Ds5, 2), (4, 8, B4, 8),
    (5, 0, E5, 3), (5, 3, G5, 3), (5, 6, E5, 2), (5, 8, C5, 3), (5, 11, E5, 3), (5, 14, G5, 2),
    (6, 0, Fs5, 3), (6, 3, A5, 3), (6, 6, Fs5, 2), (6, 8, D5, 3), (6, 11, Fs5, 3), (6, 14, A5, 2),
    (7, 0, A5, 2), (7, 2, G5, 2), (7, 4, E5, 2), (7, 6, C5, 2), (7, 8, B4, 2), (7, 10, Ds5, 2), (7, 12, Fs5, 4),
    (8, 0, B4, 4), (8, 4, E5, 2), (8, 6, G5, 2), (8, 8, B5, 6),              # la llamada, en Mi menor: Si-Mi-Sol-Si
]
MCH_A = [(E, MIN), (E, MIN), (C, MAJ), (D, MAJ), (E, MIN), (C, MAJ), ((A, MIN), (B, MAJ)), (E, MIN)]
MCH_B = [(C, MAJ), (G, MAJ), (A, MIN), (B, MAJ), (C, MAJ), (D, MAJ), ((A, MIN), (B, MAJ)), (E, MIN)]
GCH_A = [(G, MAJ), (G, MAJ), (E, MIN), (C, MAJ), (G, MAJ), (D, MAJ), ((C, MAJ), (D, MAJ)), (G, MAJ)]
GCH_B = [(C, MAJ), (G, MAJ), (A, MIN), (D, MAJ), (C, MAJ), (G, MAJ), ((A, MIN), (D, MAJ)), (G, MAJ)]
SCALE_G = {7, 9, 11, 0, 2, 4, 6}                 # Sol mayor = Mi menor natural


# ── PRADERA 2 (3ª versión): "Galope" — Do MAYOR, ritmo de galope (corchea con puntillo + semicorchea), flauta.
# Las dos primeras eran en Mi menor (el tema de pradera_1 transportado; luego uno propio): al usuario no le
# encajaban melodía y arreglo — un tema menor sobre el acompañamiento saltarín y alegre de la pradera. La pradera
# es mayor: la segunda cara cambia de TONO, de RITMO y de TIMBRE, no de modo.
F5, C6 = 77, 84
P_A = [
    (1, 0, E5, 3), (1, 3, G5, 1), (1, 4, E5, 3), (1, 7, C5, 1), (1, 8, D5, 2), (1, 10, E5, 2), (1, 12, G5, 4),
    (2, 0, A5, 3), (2, 3, G5, 1), (2, 4, E5, 3), (2, 7, D5, 1), (2, 8, C5, 6), (2, 14, D5, 2),
    (3, 0, F5, 3), (3, 3, A5, 1), (3, 4, F5, 3), (3, 7, C5, 1), (3, 8, D5, 2), (3, 10, F5, 2), (3, 12, A5, 4),
    (4, 0, G5, 3), (4, 3, B5, 1), (4, 4, G5, 3), (4, 7, D5, 1), (4, 8, G5, 6),
    (5, 0, E5, 3), (5, 3, G5, 1), (5, 4, E5, 3), (5, 7, C5, 1), (5, 8, D5, 2), (5, 10, E5, 2), (5, 12, G5, 4),
    (6, 0, A5, 3), (6, 3, C6, 1), (6, 4, A5, 3), (6, 7, E5, 1), (6, 8, C5, 2), (6, 10, E5, 2), (6, 12, A5, 4),
    (7, 0, A5, 2), (7, 2, F5, 2), (7, 4, C5, 2), (7, 6, F5, 2), (7, 8, B5, 2), (7, 10, G5, 2), (7, 12, D5, 2), (7, 14, G5, 2),
]
P_END = [(8, 0, E5, 2), (8, 2, G5, 2), (8, 4, C6, 8)]
P_END2 = [(8, 0, C6, 3), (8, 3, G5, 3), (8, 6, E5, 2), (8, 8, C5, 8)]
P_B = [
    (1, 0, A5, 6), (1, 6, F5, 2), (1, 8, C5, 4), (1, 12, F5, 4),
    (2, 0, G5, 6), (2, 6, E5, 2), (2, 8, C5, 4), (2, 12, E5, 4),
    (3, 0, F5, 4), (3, 4, A5, 4), (3, 8, D5, 6), (3, 14, F5, 2),
    (4, 0, G5, 6), (4, 6, B5, 2), (4, 8, D5, 8),
    (5, 0, F5, 3), (5, 3, A5, 3), (5, 6, F5, 2), (5, 8, C5, 3), (5, 11, F5, 3), (5, 14, A5, 2),
    (6, 0, E5, 3), (6, 3, G5, 3), (6, 6, E5, 2), (6, 8, C5, 3), (6, 11, E5, 3), (6, 14, G5, 2),
    (7, 0, A5, 2), (7, 2, F5, 2), (7, 4, D5, 2), (7, 6, F5, 2), (7, 8, G5, 2), (7, 10, B5, 2), (7, 12, D5, 4),
    (8, 0, G4, 4), (8, 4, C5, 2), (8, 6, E5, 2), (8, 8, G5, 6),              # la llamada, tal cual en el mapa: Sol-Do-Mi-Sol
]
Fr = 5
PCH_A = [(C, MAJ), (C, MAJ), (Fr, MAJ), (G, MAJ), (C, MAJ), (A, MIN), ((Fr, MAJ), (G, MAJ)), (C, MAJ)]
PCH_B = [(Fr, MAJ), (C, MAJ), (D, MIN), (G, MAJ), (Fr, MAJ), (C, MAJ), ((D, MIN), (G, MAJ)), (C, MAJ)]
SCALE_C = {0, 2, 4, 5, 7, 9, 11}
SCALE = SCALE_G                                   # (la de la pieza que se está montando: la pone song())


# ══ COSTA ═════════════════════════════════════════════════════════════════════
# Con lo aprendido en la pradera: el modo va con el arreglo (isla alegre = mayor); la SEGUNDA CARA cambia de
# tonalidad, de ritmo y de timbre, no de modo, y lleva su propia melodía; las notas largas, siempre del acorde;
# los adornos, dentro de la escala; el bonus, con solo de percusión.
#   costa_1  "Calipso": Fa mayor, 122 BPM, steel drum, bajo de calipso (1, 1y, 3), maraca en semicorcheas,
#            marimba que sube donde la melodía se posa
#   costa_2  "Arrecife": Si♭ mayor, 108 BPM, ocarina (pulso suave) sobre un colchón y arpegios lentos, aire de
#            bossa (clave en el aro), burbujas — para los niveles de agua: melodía en ondas, notas largas
Bb4, Eb5, Bb5, F4, A4_ = 70, 75, 82, 65, 69
K_A = [
    (1, 0, A4, 2), (1, 2, C5, 1), (1, 3, F5, 3), (1, 6, F5, 2), (1, 8, E5, 2), (1, 10, C5, 2), (1, 12, A4, 2), (1, 14, C5, 2),
    (2, 0, D5, 3), (2, 3, C5, 3), (2, 6, A4, 2), (2, 8, C5, 6),
    (3, 0, Bb4, 2), (3, 2, D5, 1), (3, 3, F5, 3), (3, 6, F5, 2), (3, 8, G5, 2), (3, 10, F5, 2), (3, 12, D5, 2), (3, 14, Bb4, 2),
    (4, 0, C5, 3), (4, 3, E5, 3), (4, 6, G5, 2), (4, 8, E5, 6),
    (5, 0, A4, 2), (5, 2, C5, 1), (5, 3, F5, 3), (5, 6, F5, 2), (5, 8, E5, 2), (5, 10, C5, 2), (5, 12, A4, 2), (5, 14, C5, 2),
    (6, 0, D5, 2), (6, 2, F5, 1), (6, 3, A5, 3), (6, 6, A5, 2), (6, 8, G5, 2), (6, 10, F5, 2), (6, 12, D5, 2), (6, 14, F5, 2),
    (7, 0, G5, 2), (7, 2, F5, 2), (7, 4, D5, 2), (7, 6, Bb4, 2), (7, 8, C5, 2), (7, 10, E5, 2), (7, 12, G5, 2), (7, 14, E5, 2),
]
K_END = [(8, 0, F5, 2), (8, 2, A5, 2), (8, 4, C6, 8)]
K_END2 = [(8, 0, A5, 3), (8, 3, G5, 3), (8, 6, F5, 2), (8, 8, F5, 8)]
K_B = [
    (1, 0, D5, 4), (1, 4, F5, 4), (1, 8, Bb5, 6), (1, 14, A5, 2),
    (2, 0, A5, 6), (2, 6, F5, 2), (2, 8, C5, 4), (2, 12, F5, 4),
    (3, 0, Bb4, 4), (3, 4, D5, 4), (3, 8, G5, 6), (3, 14, F5, 2),
    (4, 0, E5, 6), (4, 6, D5, 2), (4, 8, C5, 8),
    (5, 0, D5, 3), (5, 3, F5, 3), (5, 6, D5, 2), (5, 8, Bb4, 3), (5, 11, D5, 3), (5, 14, F5, 2),
    (6, 0, C5, 3), (6, 3, F5, 3), (6, 6, C5, 2), (6, 8, A4, 3), (6, 11, C5, 3), (6, 14, F5, 2),
    (7, 0, G5, 2), (7, 2, F5, 2), (7, 4, D5, 2), (7, 6, Bb4, 2), (7, 8, C5, 2), (7, 10, E5, 2), (7, 12, G5, 4),
    (8, 0, C5, 4), (8, 4, F5, 2), (8, 6, A5, 2), (8, 8, C6, 6),              # la llamada en Fa: Do-Fa-La-Do
]
Bbr = 10
KCH_A = [(Fr, MAJ), (Fr, MAJ), (Bbr, MAJ), (C, MAJ), (Fr, MAJ), (D, MIN), ((Bbr, MAJ), (C, MAJ)), (Fr, MAJ)]
KCH_B = [(Bbr, MAJ), (Fr, MAJ), (G, MIN), (C, MAJ), (Bbr, MAJ), (Fr, MAJ), ((G, MIN), (C, MAJ)), (Fr, MAJ)]
SCALE_F = {5, 7, 9, 10, 0, 2, 4}
R_A = [
    (1, 0, D5, 4), (1, 4, F5, 2), (1, 6, D5, 2), (1, 8, Bb4, 4), (1, 12, D5, 2), (1, 14, F5, 2),
    (2, 0, G5, 6), (2, 6, F5, 2), (2, 8, D5, 8),
    (3, 0, Eb5, 4), (3, 4, G5, 2), (3, 6, Eb5, 2), (3, 8, Bb4, 4), (3, 12, Eb5, 2), (3, 14, G5, 2),
    (4, 0, A5, 6), (4, 6, G5, 2), (4, 8, F5, 8),
    (5, 0, D5, 4), (5, 4, F5, 2), (5, 6, D5, 2), (5, 8, Bb4, 4), (5, 12, D5, 2), (5, 14, F5, 2),
    (6, 0, Bb5, 6), (6, 6, A5, 2), (6, 8, G5, 4), (6, 12, D5, 4),
    (7, 0, G5, 2), (7, 2, Eb5, 2), (7, 4, Bb4, 4), (7, 8, A4_, 2), (7, 10, C5, 2), (7, 12, F5, 4),
]
R_END = [(8, 0, D5, 4), (8, 4, F5, 10)]
R_END2 = [(8, 0, F5, 4), (8, 4, D5, 4), (8, 8, Bb4, 8)]
R_B = [
    (1, 0, G5, 8), (1, 8, Eb5, 4), (1, 12, G5, 4),
    (2, 0, F5, 8), (2, 8, D5, 4), (2, 12, F5, 4),
    (3, 0, Eb5, 8), (3, 8, C5, 4), (3, 12, Eb5, 4),
    (4, 0, C5, 4), (4, 4, F5, 4), (4, 8, A5, 8),
    (5, 0, Bb5, 6), (5, 6, G5, 2), (5, 8, Eb5, 6), (5, 14, G5, 2),
    (6, 0, F5, 6), (6, 6, D5, 2), (6, 8, Bb4, 6), (6, 14, D5, 2),
    (7, 0, Eb5, 4), (7, 4, C5, 4), (7, 8, F5, 4), (7, 12, A5, 4),
    (8, 0, F4, 4), (8, 4, Bb4, 2), (8, 6, D5, 2), (8, 8, F5, 6),              # la llamada en Si♭: Fa-Si♭-Re-Fa
]
Ebr = 3
RCH_A = [(Bbr, MAJ), (G, MIN), (Ebr, MAJ), (Fr, MAJ), (Bbr, MAJ), (G, MIN), ((Ebr, MAJ), (Fr, MAJ)), (Bbr, MAJ)]
RCH_B = [(Ebr, MAJ), (Bbr, MAJ), (C, MIN), (Fr, MAJ), (Ebr, MAJ), (Bbr, MAJ), ((C, MIN), (Fr, MAJ)), (Bbr, MAJ)]
SCALE_Bb = {10, 0, 2, 3, 5, 7, 9}


# ══ FORTALEZA ═════════════════════════════════════════════════════════════════
# (La pista anterior de la fortaleza era un arreglo de una canción ajena: retirada. Todo esto es nuevo.)
#   fortaleza_1  "Marcha de hierro": Do menor, 140 BPM, sierra del VRC6 + pulso, ritmo de marcha (tan · ta-ta) en la
#                melodía y la caja, bajo en octavas, golpes de quinta, "metal" a contratiempo; motivo: fanfarria de
#                tresillos donde la melodía se posa
#   fortaleza_2  "Engranajes": Sol menor, 126 BPM, pulso fino en picado (de reloj), tic-tac de quinta y tónica, bajo
#                de locomotora (1 · 1-8), máquina en semicorcheas de ruido metálico; motivo: tres golpes de yunque.
#                Otra tonalidad, otro ritmo y otro timbre, y su propia melodía (fábricas, canteras, el tren)
G4_, Ab4, Bb4_, B4_, Eb5_, F5_, Ab5, Bb5_, C6_ = 67, 68, 70, 71, 75, 77, 80, 82, 84
H_A = [
    (1, 0, C5, 4), (1, 4, G4_, 2), (1, 6, C5, 1), (1, 7, D5, 1), (1, 8, Eb5_, 4), (1, 12, D5, 2), (1, 14, C5, 2),
    (2, 0, G5, 6), (2, 6, Eb5_, 2), (2, 8, C5, 8),
    (3, 0, Ab4, 4), (3, 4, C5, 2), (3, 6, Eb5_, 1), (3, 7, F5_, 1), (3, 8, Eb5_, 4), (3, 12, F5_, 2), (3, 14, Eb5_, 2),
    (4, 0, D5, 6), (4, 6, B4_, 2), (4, 8, G4_, 8),
    (5, 0, C5, 4), (5, 4, G4_, 2), (5, 6, C5, 1), (5, 7, D5, 1), (5, 8, Eb5_, 4), (5, 12, D5, 2), (5, 14, C5, 2),
    (6, 0, Ab5, 6), (6, 6, G5, 2), (6, 8, Eb5_, 4), (6, 12, C5, 4),
    (7, 0, F5_, 2), (7, 2, Ab5, 2), (7, 4, F5_, 2), (7, 6, C5, 2), (7, 8, D5, 2), (7, 10, G5, 2), (7, 12, B4_, 2), (7, 14, D5, 2),
]
H_END = [(8, 0, C5, 2), (8, 2, Eb5_, 2), (8, 4, G5, 8)]
H_END2 = [(8, 0, Eb5_, 3), (8, 3, D5, 3), (8, 6, C5, 2), (8, 8, C5, 8)]
H_B = [
    (1, 0, C5, 4), (1, 4, Eb5_, 4), (1, 8, Ab5, 6), (1, 14, G5, 2),
    (2, 0, G5, 6), (2, 6, Eb5_, 2), (2, 8, Bb4_, 4), (2, 12, Eb5_, 4),
    (3, 0, Ab4, 4), (3, 4, C5, 4), (3, 8, F5_, 6), (3, 14, Eb5_, 2),
    (4, 0, D5, 6), (4, 6, C5, 2), (4, 8, B4_, 8),
    (5, 0, C5, 3), (5, 3, Eb5_, 3), (5, 6, C5, 2), (5, 8, Ab4, 3), (5, 11, C5, 3), (5, 14, Eb5_, 2),
    (6, 0, Bb4_, 3), (6, 3, Eb5_, 3), (6, 6, Bb4_, 2), (6, 8, G4_, 3), (6, 11, Bb4_, 3), (6, 14, Eb5_, 2),
    (7, 0, F5_, 2), (7, 2, Eb5_, 2), (7, 4, C5, 2), (7, 6, Ab4, 2), (7, 8, B4_, 2), (7, 10, D5, 2), (7, 12, G5, 4),
    (8, 0, G4_, 4), (8, 4, C5, 2), (8, 6, Eb5_, 2), (8, 8, G5, 6),            # la llamada en Do menor: Sol-Do-Mi♭-Sol
]
Abr, Ebr_, Fr_ = 8, 3, 5
HCH_A = [(C, MIN), (C, MIN), (Abr, MAJ), (G, MAJ), (C, MIN), (Abr, MAJ), ((Fr_, MIN), (G, MAJ)), (C, MIN)]
HCH_B = [(Abr, MAJ), (Ebr_, MAJ), (Fr_, MIN), (G, MAJ), (Abr, MAJ), (Ebr_, MAJ), ((Fr_, MIN), (G, MAJ)), (C, MIN)]
SCALE_Cm = {0, 2, 3, 5, 7, 8, 10, 11}                 # (menor con sus dos séptimas: Si♭ en la melodía, Si en la dominante)
A4n, Fs5_, A5n, D6_ = 69, 78, 81, 86
N_A = [
    (1, 0, G4_, 2), (1, 2, Bb4_, 2), (1, 4, D5, 2), (1, 6, Bb4_, 2), (1, 8, G5, 4), (1, 12, D5, 2), (1, 14, Bb4_, 2),
    (2, 0, A4n, 2), (2, 2, Bb4_, 2), (2, 4, C5, 2), (2, 6, D5, 2), (2, 8, D5, 6),
    (3, 0, G4_, 2), (3, 2, Bb4_, 2), (3, 4, Eb5_, 2), (3, 6, Bb4_, 2), (3, 8, G5, 4), (3, 12, Eb5_, 2), (3, 14, Bb4_, 2),
    (4, 0, Fs5_, 2), (4, 2, G5, 2), (4, 4, A5n, 2), (4, 6, G5, 2), (4, 8, Fs5_, 6),
    (5, 0, G4_, 2), (5, 2, Bb4_, 2), (5, 4, D5, 2), (5, 6, Bb4_, 2), (5, 8, G5, 4), (5, 12, D5, 2), (5, 14, Bb4_, 2),
    (6, 0, C5, 2), (6, 2, Eb5_, 2), (6, 4, G5, 2), (6, 6, Eb5_, 2), (6, 8, G5, 4), (6, 12, Eb5_, 2), (6, 14, C5, 2),
    (7, 0, Bb5_, 2), (7, 2, G5, 2), (7, 4, Eb5_, 2), (7, 6, G5, 2), (7, 8, A5n, 2), (7, 10, Fs5_, 2), (7, 12, D5, 2), (7, 14, Fs5_, 2),
]
N_END = [(8, 0, G4_, 2), (8, 2, Bb4_, 2), (8, 4, D5, 8)]
N_END2 = [(8, 0, Bb5_, 3), (8, 3, A5n, 3), (8, 6, G5, 2), (8, 8, G5, 8)]
N_B = [
    (1, 0, Eb5_, 8), (1, 8, G5, 6), (1, 14, Eb5_, 2),
    (2, 0, D5, 8), (2, 8, Bb4_, 4), (2, 12, D5, 4),
    (3, 0, Eb5_, 8), (3, 8, Bb5_, 6), (3, 14, G5, 2),
    (4, 0, A5n, 6), (4, 6, G5, 2), (4, 8, Fs5_, 8),
    (5, 0, C5, 3), (5, 3, Eb5_, 3), (5, 6, C5, 2), (5, 8, G4_, 3), (5, 11, C5, 3), (5, 14, Eb5_, 2),
    (6, 0, Bb4_, 3), (6, 3, D5, 3), (6, 6, Bb4_, 2), (6, 8, G4_, 3), (6, 11, Bb4_, 3), (6, 14, D5, 2),
    (7, 0, Eb5_, 2), (7, 2, G5, 2), (7, 4, Bb5_, 4), (7, 8, A5n, 2), (7, 10, Fs5_, 2), (7, 12, D5, 4),
    (8, 0, D5, 4), (8, 4, G5, 2), (8, 6, Bb5_, 2), (8, 8, D6_, 6),            # la llamada en Sol menor: Re-Sol-Si♭-Re
]
NCH_A = [(G, MIN), (G, MIN), (Ebr_, MAJ), (D, MAJ), (G, MIN), (C, MIN), ((Ebr_, MAJ), (D, MAJ)), (G, MIN)]
NCH_B = [(C, MIN), (G, MIN), (Ebr_, MAJ), (D, MAJ), (C, MIN), (G, MIN), ((Ebr_, MAJ), (D, MAJ)), (G, MIN)]
SCALE_Gm = {7, 9, 10, 0, 2, 3, 5, 6}


# ══ JEFES DE ISLA (sustituyen a la genérica, que era un arreglo de una canción ajena) ══════════════════════════
#   gummy_king_boss  "Su Majestad Gummy": Sol mayor (la tonalidad de la pradera), 152 BPM; fanfarria pomposa de
#                    ritmo con puntillo (tan-ta), bajo de gelatina que salta en octavas, timbales; B en Mi menor
#   evil_ship_boss   "Persecución": Do menor (la de la fortaleza), 160 BPM; la marcha convertida en persecución:
#                    corcheas que empujan, sierra, bajo que no para, máquina metálica; motivo: la ALARMA (dos notas)
Y_A = [
    (1, 0, G4, 3), (1, 3, G4, 1), (1, 4, B4, 2), (1, 6, D5, 2), (1, 8, G5, 4), (1, 12, D5, 2), (1, 14, B4, 2),
    (2, 0, A4, 3), (2, 3, A4, 1), (2, 4, D5, 2), (2, 6, Fs5, 2), (2, 8, A5, 6),
    (3, 0, G5, 3), (3, 3, Fs5, 1), (3, 4, E5, 2), (3, 6, B4, 2), (3, 8, E5, 4), (3, 12, G5, 2), (3, 14, E5, 2),
    (4, 0, E5, 3), (4, 3, D5, 1), (4, 4, C5, 2), (4, 6, E5, 2), (4, 8, G5, 6),
    (5, 0, G4, 3), (5, 3, G4, 1), (5, 4, B4, 2), (5, 6, D5, 2), (5, 8, G5, 4), (5, 12, D5, 2), (5, 14, B4, 2),
    (6, 0, Fs5, 3), (6, 3, Fs5, 1), (6, 4, A5, 2), (6, 6, Fs5, 2), (6, 8, D5, 4), (6, 12, Fs5, 2), (6, 14, A5, 2),
    (7, 0, E5, 2), (7, 2, G5, 2), (7, 4, E5, 2), (7, 6, C5, 2), (7, 8, D5, 2), (7, 10, Fs5, 2), (7, 12, A5, 2), (7, 14, Fs5, 2),
]
Y_END = [(8, 0, G5, 3), (8, 3, Fs5, 1), (8, 4, G5, 2), (8, 6, B5, 2), (8, 8, D5, 8)]
Y_END2 = [(8, 0, G5, 3), (8, 3, G5, 1), (8, 4, B5, 4), (8, 8, G5, 8)]
Y_B = [
    (1, 0, E5, 4), (1, 4, G5, 4), (1, 8, B5, 6), (1, 14, G5, 2),
    (2, 0, Fs5, 6), (2, 6, D5, 2), (2, 8, B4, 4), (2, 12, D5, 4),
    (3, 0, E5, 4), (3, 4, G5, 4), (3, 8, G5, 6), (3, 14, E5, 2),
    (4, 0, Fs5, 6), (4, 6, E5, 2), (4, 8, D5, 8),
    (5, 0, E5, 3), (5, 3, G5, 3), (5, 6, E5, 2), (5, 8, B4, 3), (5, 11, E5, 3), (5, 14, G5, 2),
    (6, 0, D5, 3), (6, 3, Fs5, 3), (6, 6, D5, 2), (6, 8, B4, 3), (6, 11, D5, 3), (6, 14, Fs5, 2),
    (7, 0, E5, 2), (7, 2, G5, 2), (7, 4, E5, 2), (7, 6, C5, 2), (7, 8, D5, 2), (7, 10, Fs5, 2), (7, 12, A5, 4),
    (8, 0, D5, 4), (8, 4, G5, 2), (8, 6, B5, 2), (8, 8, D6, 6),              # la llamada: Re-Sol-Si-Re
]
YCH_A = [(G, MAJ), (D, MAJ), (E, MIN), (C, MAJ), (G, MAJ), (D, MAJ), ((C, MAJ), (D, MAJ)), (G, MAJ)]
YCH_B = [(E, MIN), (B, MIN), (C, MAJ), (D, MAJ), (E, MIN), (B, MIN), ((C, MAJ), (D, MAJ)), (G, MAJ)]
Bbr_ = 10
X_A = [
    (1, 0, C5, 2), (1, 2, C5, 2), (1, 4, Eb5_, 2), (1, 6, C5, 2), (1, 8, G5, 4), (1, 12, Eb5_, 2), (1, 14, C5, 2),
    (2, 0, Ab5, 2), (2, 2, G5, 2), (2, 4, Ab5, 2), (2, 6, G5, 2), (2, 8, Eb5_, 6),
    (3, 0, D5, 2), (3, 2, D5, 2), (3, 4, F5_, 2), (3, 6, D5, 2), (3, 8, Bb5_, 4), (3, 12, F5_, 2), (3, 14, D5, 2),
    (4, 0, G5, 2), (4, 2, B4_, 2), (4, 4, D5, 2), (4, 6, G5, 2), (4, 8, D5, 6),
    (5, 0, C5, 2), (5, 2, C5, 2), (5, 4, Eb5_, 2), (5, 6, C5, 2), (5, 8, G5, 4), (5, 12, Eb5_, 2), (5, 14, C5, 2),
    (6, 0, Ab5, 4), (6, 4, Eb5_, 2), (6, 6, C5, 2), (6, 8, Eb5_, 4), (6, 12, Ab5, 2), (6, 14, C6_, 2),
    (7, 0, C6_, 2), (7, 2, Ab5, 2), (7, 4, F5_, 2), (7, 6, Ab5, 2), (7, 8, G5, 2), (7, 10, D5, 2), (7, 12, B4_, 2), (7, 14, D5, 2),
]
X_END = [(8, 0, Eb5_, 2), (8, 2, C5, 2), (8, 4, G4_, 8)]
X_END2 = [(8, 0, C5, 2), (8, 2, Eb5_, 2), (8, 4, G5, 2), (8, 6, Eb5_, 2), (8, 8, C5, 8)]
X_B = [
    (1, 0, Ab5, 8), (1, 8, F5_, 6), (1, 14, Ab5, 2),
    (2, 0, G5, 8), (2, 8, Eb5_, 4), (2, 12, G5, 4),
    (3, 0, Ab5, 6), (3, 6, G5, 2), (3, 8, Eb5_, 6), (3, 14, C5, 2),
    (4, 0, D5, 6), (4, 6, B4_, 2), (4, 8, D5, 8),
    (5, 0, F5_, 3), (5, 3, Ab5, 3), (5, 6, F5_, 2), (5, 8, C5, 3), (5, 11, F5_, 3), (5, 14, Ab5, 2),
    (6, 0, Eb5_, 3), (6, 3, G5, 3), (6, 6, Eb5_, 2), (6, 8, C5, 3), (6, 11, Eb5_, 3), (6, 14, G5, 2),
    (7, 0, Ab5, 2), (7, 2, Eb5_, 2), (7, 4, C5, 2), (7, 6, Eb5_, 2), (7, 8, D5, 2), (7, 10, B4_, 2), (7, 12, G5, 4),
    (8, 0, G4_, 4), (8, 4, C5, 2), (8, 6, Eb5_, 2), (8, 8, G5, 6),            # la llamada en Do menor
]
XCH_A = [(C, MIN), (Abr, MAJ), (Bbr_, MAJ), (G, MAJ), (C, MIN), (Abr, MAJ), ((Fr_, MIN), (G, MAJ)), (C, MIN)]
XCH_B = [(Fr_, MIN), (C, MIN), (Abr, MAJ), (G, MAJ), (Fr_, MIN), (C, MIN), ((Abr, MAJ), (G, MAJ)), (C, MIN)]


# ══ CUMBRES (nieve) ═══════════════════════════════════════════════════════════
#   nieve_1        "Cumbres de cristal": Fa mayor, 148 BPM; la melodía en la CAJA DE MÚSICA una octava arriba (con un
#                  pulso suave debajo), bajo en blancas, copos en corcheas, cascabeles; motivo: campanitas que caen
#   nieve_2        "Ventisca": Re menor natural, 156; voz de pulso con destellos de campana, arpegio de viento en
#                  semicorcheas, bajo en corcheas, caja en 2 y 4 — la cara tensa (fábrica, torre)
#   snowball_boss  "La Gran Bola": Fa menor, 168; a saltitos y burlona, bajo que RUEDA en semicorcheas, timbales que
#                  ruedan, cascabeles
# El MOTIVO NAVIDEÑO de la caja de música de "Winter Fallympics" (muestra; el usuario: sin abusar): UNA vez por vuelta
# en nieve_1 (y su bonus) y en el jefe — los cuatro primeros compases de la frase B, sobre su propia armonía
# (IV IV V V; en el jefe, subido una tercera menor: cae sobre ♭VI ♭VI ♭VII ♭VII de Fa menor) —; nieve_2 no lo lleva.
WMOTIF = [[77, 89, 88, 86], [84, 82, 81, 82], [84, 86, 84, 82], [81, 79, 77, 79]]
def wmotif(up=0):                     # (escrito una octava abajo: la caja de música lo sube a su sitio)
    return [(i + 1, k * 4, m - 12 + up, 4) for i, bar in enumerate(WMOTIF) for k, m in enumerate(bar)]
# SEGUNDA VERSIÓN de las melodías (3.56.0). La primera usaba el molde rítmico de la pradera (golpes 3+3+2 con
# puntillo, la misma frase B) y al usuario le sonaron "muchísimo" a pradera_1/2. Ahora el vocabulario sale de las
# dos muestras de Winter Fallympics, para que las melodías propias y las muestras sean de la misma familia:
#   · la FRASE DE 1:48-2:08 (compases 85-92 del original: `W148`), que hace de parte "tranquila sin perder energía"
#     y de PUENTE hacia el estribillo: tres corcheas que suben y una negra a contratiempo (2-2-2-4 · 2-2-4→), y su
#     cierre de tres notas repetidas y un salto (compases 91-92);
#   · el MOTIVO navideño de la caja de música (negras, salto de octava), que es el estribillo.
# Forma de nieve_1 y del jefe: intro · A · A' · B (el puente: la muestra de 1:48) · C (estribillo: el motivo + una
# respuesta + la llamada) · A''. nieve_2: sin estribillo; su puente solo cita los dos primeros compases de 1:48,
# rearmonizados en el relativo menor. Sin abusar: cada muestra, una vez por vuelta.
_PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
def P(bar, txt, up=0):
    """'0:Bb4/2 2:C5/2' → [(compás, semicorchea, nota MIDI, duración)]"""
    out = []
    for tok in txt.split():
        st, rest = tok.split(':'); nm, d = rest.split('/')
        pc = _PC[nm[0]] + (-1 if 'b' in nm[1:-1] else 1 if '#' in nm[1:-1] else 0)
        out.append((bar, int(st), 12 * (int(nm[-1]) + 1) + pc + up, int(d)))
    return out
def PH(*bars, up=0):
    return [x for i, t in enumerate(bars) for x in P(i + 1, t, up)]
# la frase de 1:48 (Smooth Synth, compases 85-88 y 91-92), una octava arriba de como está escrita
W148 = ["0:F4/2 2:A4/2 4:C5/2 6:F5/4 10:C5/2 12:F5/2 14:G5/4", "2:C5/2 4:G5/2 6:A5/4 12:C6/2",
        "0:C6/2 2:Bb5/2 4:A5/2 6:G5/4 10:F5/2 12:G5/2 14:A5/4", "2:G5/2 4:F5/2 6:E5/4 10:D5/2 12:E5/4"]
W148_END = ["0:D5/3 4:D5/3 8:D5/3 12:Bb5/4", "0:E5/3 4:E5/3 8:E5/3 12:G5/4"]
Abr_ = 8
# ── nieve_1 "Cumbres de cristal" (Fa mayor) ──
S_A = PH("0:A4/2 2:C5/2 4:F5/2 6:A5/4 10:G5/2 12:F5/2 14:C5/4", "2:E5/2 4:G5/2 6:C6/4 10:G5/2 12:E5/4",
         "0:D5/2 2:F5/2 4:A5/2 6:D6/4 10:C6/2 12:A5/2 14:F5/4", "2:D5/2 4:F5/2 6:Bb5/4 10:A5/2 12:F5/4",
         "0:C6/2 2:A5/2 4:F5/2 6:A5/4 10:G5/2 12:F5/2 14:E5/4", "2:E5/2 4:G5/2 6:E5/4 10:D5/2 12:C5/4",
         "0:D5/4 4:Bb5/4 8:C6/4 12:G5/4")
S_END = P(8, "0:A5/4 4:F5/4 8:C5/8")
S_END2 = P(8, "0:F5/4 4:A5/4 8:C6/8")
S_B = PH(*W148, "0:F5/2 2:A5/2 4:D6/2 6:A5/4 10:F5/2 12:D5/2 14:F5/4", "2:D5/2 4:F5/2 6:Bb5/4 10:F5/2 12:D5/4", *W148_END)
S_C = wmotif() + P(5, "0:A5/6 6:F5/2 8:D5/4 12:F5/4") + P(6, "0:F5/6 6:D5/2 8:Bb4/4 12:D5/4") \
    + P(7, "0:G5/2 2:Bb5/2 4:G5/2 6:D5/2 8:E5/2 10:G5/2 12:C6/4") + P(8, "0:C5/4 4:F5/2 6:A5/2 8:C6/6")     # la llamada
SCH_A = [(Fr_, MAJ), (C, MAJ), (D, MIN), (Bbr_, MAJ), (Fr_, MAJ), (C, MAJ), ((Bbr_, MAJ), (C, MAJ)), (Fr_, MAJ)]
SCH_B = [(Fr_, MAJ), ((G, MIN), (Fr_, MAJ)), (Bbr_, MAJ), (C, MAJ), (D, MIN), (Bbr_, MAJ), (G, MIN), (C, MAJ)]
SCH_C = [(Bbr_, MAJ), (Bbr_, MAJ), (C, MAJ), (C, MAJ), (D, MIN), (Bbr_, MAJ), ((G, MIN), (C, MAJ)), (Fr_, MAJ)]
# ── nieve_2 "Ventisca" (Re menor natural) ──
V_A = PH("0:A5/2 2:G5/2 4:F5/2 6:D5/4 10:F5/2 12:A5/2 14:Bb5/4", "2:A5/2 4:F5/2 6:D5/4 10:F5/2 12:Bb5/4",
         "0:C6/2 2:Bb5/2 4:G5/2 6:E5/4 10:G5/2 12:C6/2 14:A5/4", "2:F5/2 4:D5/2 6:A5/4 12:D5/4",
         "0:A5/2 2:G5/2 4:F5/2 6:D5/4 10:F5/2 12:A5/2 14:Bb5/4", "2:G5/2 4:D5/2 6:Bb5/4 10:A5/2 12:G5/4",
         "0:D5/4 4:Bb5/4 8:E5/4 12:C6/4")
V_END = P(8, "0:A5/4 4:F5/4 8:D5/8")
V_END2 = P(8, "0:D5/4 4:F5/4 8:A5/8")
V_B = PH(W148[0], W148[1], "0:D6/2 2:C6/2 4:Bb5/2 6:F5/4 10:D5/2 12:F5/2 14:G5/4", "2:E5/2 4:G5/2 6:C6/4 12:G5/4",
         "0:A5/8 8:F5/4 12:A5/4", "0:Bb5/8 8:F5/4 12:D5/4", "0:E5/3 4:E5/3 8:E5/3 12:G5/4", "0:A4/4 4:D5/2 6:F5/2 8:A5/6")
VCH_A = [(D, MIN), (Bbr_, MAJ), (C, MAJ), (D, MIN), (D, MIN), (G, MIN), ((Bbr_, MAJ), (C, MAJ)), (D, MIN)]
VCH_B = [(D, MIN), ((G, MIN), (Fr_, MAJ)), (Bbr_, MAJ), (C, MAJ), (D, MIN), (Bbr_, MAJ), (C, MAJ), (D, MIN)]
SCALE_Dm = {2, 4, 5, 7, 9, 10, 0}
# ── snowball_boss "La Gran Bola" (Fa menor; las muestras, una tercera menor arriba: caen en su relativo, La♭) ──
# (A, 2ª versión: la primera llevaba el mismo ritmo que nieve_1 compás a compás, solo que en menor, y al usuario no
# le convenció: "más distinta de nieve_1 y construida con las muestras". Ahora el tema del jefe SALE de las muestras:
# el golpe de tres notas repetidas y salto con que cierra la frase de 1:48 (`W148_END`) es su riff, le contesta una
# bajada por grados como la del 2º compás del motivo, y el salto de octava del motivo remata la frase.)
O_A = PH("0:F5/3 4:F5/3 8:F5/3 12:C6/4", "0:Ab5/2 2:G5/2 4:F5/2 6:Eb5/2 8:F5/4 12:C5/4",
         "0:Ab5/3 4:Ab5/3 8:Ab5/3 12:Db6/4", "0:Bb5/2 2:Ab5/2 4:G5/2 6:F5/2 8:G5/4 12:Eb5/4",
         "0:C5/3 4:C5/3 8:C5/3 12:Ab5/4", "0:Ab5/2 2:C6/2 4:Ab5/2 6:F5/2 8:C5/4 12:F5/4",
         "0:F5/4 4:F6/4 8:Eb6/4 12:Bb5/4")
O_END = P(8, "0:Ab5/4 4:F5/4 8:C5/8")
O_END2 = P(8, "0:C6/4 4:Ab5/4 8:F5/8")
O_B = PH(*W148, up=3) + P(5, "0:C6/8 8:Ab5/4 12:F5/4") + P(6, "0:Ab5/8 8:F5/4 12:Db5/4") + [(b + 6, st, n + 3, d) for b, st, n, d in PH(*W148_END)]
O_C = wmotif(3) + P(5, "0:C6/6 6:Ab5/2 8:F5/4 12:Ab5/4") + P(6, "0:Ab5/6 6:F5/2 8:Db5/4 12:F5/4") \
    + P(7, "0:Bb5/2 2:F5/2 4:Db5/2 6:F5/2 8:G5/2 10:Eb5/2 12:Bb5/4") + P(8, "0:C5/4 4:F5/2 6:Ab5/2 8:C6/6")   # la llamada
Dbr = 1
OCH_A = [(Fr_, MIN), (Fr_, MIN), (Dbr, MAJ), (Ebr_, MAJ), (Fr_, MIN), (Fr_, MIN), ((Dbr, MAJ), (Ebr_, MAJ)), (Fr_, MIN)]
OCH_B = [(Fr_, MIN), ((Bbr_, MIN), (Abr_, MAJ)), (Dbr, MAJ), (Ebr_, MAJ), (Fr_, MIN), (Dbr, MAJ), (Bbr_, MIN), (Ebr_, MAJ)]
OCH_C = [(Dbr, MAJ), (Dbr, MAJ), (Ebr_, MAJ), (Ebr_, MAJ), (Fr_, MIN), (Dbr, MAJ), ((Bbr_, MIN), (Ebr_, MAJ)), (Fr_, MIN)]
SCALE_Fm = {5, 7, 8, 10, 0, 1, 3}
# compases (de la frase) que son muestra prestada: sus notas de paso no cuentan en la comprobación
SAMPLE_BARS = {'cumbres': {'B': (1, 2, 3, 4, 7, 8), 'C': (1, 2, 3, 4)}, 'ventisca': {'B': (1, 2)},
               'bola': {'B': (1, 2, 3, 4, 7, 8), 'C': (1, 2, 3, 4)}}


# ══ CUEVAS ═══════════════════════════════════════════════════════════════════
#   cuevas_1   "Ecos de cristal": Re dórico (Si natural: el acorde de Sol mayor), 104 BPM a medio tiempo; la melodía
#              en la caja de música CON ECO de cueva, notas largas y huecos para que el eco conteste; colchón, bajo en
#              redondas, bombo hondo y un chasquido, sin platos; acento: GOTAS
#   cuevas_2   "Laberinto sumergido": La menor, 92; voz de flauta hueca con eco que va y viene por grados, arpa en
#              corcheas, casi sin batería; acento: un SONAR (una nota que se repite más lejos) — el laberinto de agua
#   (cuevas_oscuras, la de los niveles a oscuras, ya era propia: gloomy_nes.py cueva)
C_A = PH("0:D5/6 6:F5/2 8:A5/8", "0:B5/6 6:A5/2 8:G5/4 12:D5/4", "0:F5/6 6:A5/2 8:D6/8", "0:E6/6 6:D6/2 8:C6/4 12:G5/4",
         "0:A5/4 4:F5/4 8:D5/6 14:E5/2", "0:G5/4 4:B5/4 8:D6/6 14:B5/2", "0:C6/6 6:B5/2 8:A5/4 12:E5/4")
C_END = P(8, "0:F5/4 4:A5/4 8:D5/8")
C_END2 = P(8, "0:A5/4 4:F5/4 8:D6/8")
C_B = PH("0:C6/4 4:A5/2 6:F5/2 8:A5/8", "0:G5/4 4:E5/2 6:C5/2 8:E5/8", "0:B5/4 4:G5/2 6:D5/2 8:G5/8", "0:A5/4 4:F5/2 6:D5/2 8:F5/8",
         "0:F5/2 2:A5/2 4:C6/4 8:C6/8", "0:E5/2 2:G5/2 4:C6/4 8:E6/8", "0:E6/4 4:C6/4 8:A5/4 12:E5/4", "0:A4/4 4:D5/2 6:F5/2 8:A5/6")
CCH_A = [(D, MIN), (G, MAJ), (D, MIN), (C, MAJ), (D, MIN), (G, MAJ), (A, MIN), (D, MIN)]
CCH_B = [(Fr_, MAJ), (C, MAJ), (G, MAJ), (D, MIN), (Fr_, MAJ), (C, MAJ), (A, MIN), (D, MIN)]
SCALE_Ddor = {2, 4, 5, 7, 9, 11, 0}
U_A = PH("0:E5/4 4:A5/2 6:B5/2 8:C6/6 14:B5/2", "0:A5/8 8:F5/4 12:A5/4", "0:D5/4 4:G5/2 6:A5/2 8:B5/6 14:A5/2", "0:E5/8 8:C5/4 12:E5/4",
         "0:E5/4 4:A5/2 6:B5/2 8:C6/6 14:B5/2", "0:C6/4 4:A5/4 8:F5/6 14:A5/2", "0:B5/4 4:G5/4 8:E5/4 12:G5/4")
U_END = P(8, "0:A5/4 4:E5/4 8:C5/8")
U_END2 = P(8, "0:C6/4 4:E6/4 8:A5/8")
U_B = PH("0:F5/2 2:A5/2 4:C6/4 8:A5/8", "0:G5/2 2:B5/2 4:D6/4 8:B5/8", "0:A5/2 2:C6/2 4:E6/4 8:C6/8", "0:E6/6 6:D6/2 8:C6/4 12:A5/4",
         "0:F5/4 4:A5/4 8:D6/8", "0:C6/4 4:A5/4 8:F5/8", "0:G5/2 2:B5/2 4:D6/2 6:B5/2 8:G5/4 12:D5/4", "0:E5/4 4:A5/2 6:C6/2 8:E6/6")
UCH_A = [(A, MIN), (Fr_, MAJ), (G, MAJ), (A, MIN), (A, MIN), (Fr_, MAJ), ((G, MAJ), (E, MIN)), (A, MIN)]
UCH_B = [(Fr_, MAJ), (G, MAJ), (A, MIN), (A, MIN), (D, MIN), (Fr_, MAJ), (G, MAJ), (A, MIN)]
SCALE_Am = {9, 11, 0, 2, 4, 5, 7}


# ══ VOLCÁN ═══════════════════════════════════════════════════════════════════
#   volcan_1   "Sendero de ceniza": Mi frigio (el Fa natural, ♭II: el acorde de Fa mayor), 164 BPM; tema cantable y heroico (ver L_A), metal cálido del N163 con
#              trompas abajo; quintas en trémolo de semicorcheas, bajo en corcheas, doble bombo; acento: un floreo punteado
#   volcan_2   "Lluvia de fuego": La frigio (Si♭), 172; latigazos — escalas frigias en semicorcheas que rematan en una
#              nota larga —, bajo y bombo al GALOPE (ta-ta-tan), quintas tenidas; acento: el acorde que sube punteado
#              (cámara automática, lluvia de pinchos)
# volcan_1, SEGUNDA VERSIÓN (el usuario pidió rehacerla entera; la primera iba "a chispazos" — semicorchea + corchea
# con puntillo — sobre una onda áspera y con una erupción de ruido como acento, y no quedaba bien). Ahora es un tema
# CANTABLE y heroico, el de la última isla: negra, dos semicorcheas y la nota larga ADELANTADA una corchea (taa ta-ta-TAAA: empuja), frases
# de 2 compases que suben y se contestan; Mi menor con el Fa natural (♭II) en mitad y al cierre de la frase; la parte
# B se abre al relativo mayor. Voz de metal cálido (N163) con trompas abajo.
L_A = PH("0:E5/4 4:G5/1 5:A5/1 6:B5/8 14:G5/2", "0:E6/4 4:D6/1 5:C6/1 6:G5/10",
         "0:D6/4 4:B5/1 5:G5/1 6:B5/8 14:D6/2", "0:C6/4 4:A5/1 5:F5/1 6:A5/10",
         "0:E5/4 4:G5/1 5:A5/1 6:B5/8 14:G5/2", "0:C6/4 4:E6/1 5:D6/1 6:C6/8 14:G5/2",
         "0:A5/2 2:C6/2 4:E6/4 8:F6/2 10:C6/2 12:A5/2 14:F5/2")
L_END = P(8, "0:E5/4 4:G5/4 8:B5/8")
L_END2 = P(8, "0:G5/4 4:F5/2 6:E5/2 8:E5/8")
L_B = PH("0:G5/6 6:E5/2 8:C6/8", "0:B5/6 6:G5/2 8:D6/8", "0:C6/4 4:E6/4 8:A5/6 14:C6/2", "0:B5/6 6:G5/2 8:E5/8",
         "0:A5/6 6:F5/2 8:C6/8", "0:G5/6 6:E5/2 8:E6/8", "0:F6/4 4:C6/4 8:A5/4 12:F5/4", "0:B4/4 4:E5/2 6:G5/2 8:B5/6")
LCH_A = [(E, MIN), (C, MAJ), (G, MAJ), (Fr_, MAJ), (E, MIN), (C, MAJ), ((A, MIN), (Fr_, MAJ)), (E, MIN)]
LCH_B = [(C, MAJ), (G, MAJ), (A, MIN), (E, MIN), (Fr_, MAJ), (C, MAJ), (Fr_, MAJ), (E, MIN)]
SCALE_Ephr = {4, 5, 7, 9, 11, 0, 2}
F_A = PH("0:A5/1 1:Bb5/1 2:C6/1 3:D6/1 4:E6/6 10:D6/2 12:C6/4", "0:E6/1 1:D6/1 2:C6/1 3:Bb5/1 4:A5/6 10:C6/2 12:E5/4",
         "0:Bb5/1 1:C6/1 2:D6/1 3:E6/1 4:F6/6 10:D6/2 12:Bb5/4", "0:E6/1 1:D6/1 2:C6/1 3:Bb5/1 4:A5/8 12:E5/4",
         "0:D6/1 1:E6/1 2:F6/1 3:E6/1 4:D6/6 10:A5/2 12:F5/4", "0:C6/1 1:D6/1 2:E6/1 3:D6/1 4:C6/6 10:G5/2 12:E5/4",
         "0:Bb5/2 2:D6/2 4:F6/4 8:D6/2 10:Bb5/2 12:F5/4")
F_END = P(8, "0:C6/4 4:A5/4 8:E5/8")
F_END2 = P(8, "0:A5/4 4:C6/4 8:E6/8")
F_B = PH("0:C6/8 8:A5/4 12:F5/4", "0:D6/8 8:Bb5/4 12:G5/4", "0:E6/6 6:D6/2 8:C6/4 12:G5/4", "0:F6/6 6:D6/2 8:Bb5/8",
         "0:E6/8 8:C6/4 12:A5/4", "0:C6/8 8:A5/4 12:C6/4", "0:D6/4 4:Bb5/4 8:F6/4 12:D6/4", "0:E5/4 4:A5/2 6:C6/2 8:E6/6")
FCH_A = [(A, MIN), (A, MIN), (Bbr_, MAJ), (A, MIN), (D, MIN), (C, MAJ), (Bbr_, MAJ), (A, MIN)]
FCH_B = [(Fr_, MAJ), (G, MIN), (C, MAJ), (Bbr_, MAJ), (A, MIN), (Fr_, MAJ), ((G, MIN), (Bbr_, MAJ)), (A, MIN)]
SCALE_Aphr = {9, 10, 0, 2, 4, 5, 7}


# ══ VICTORIA (la pantalla de resultados; id `victory`) ═════════════════════════
# Una FANFARRIA (la intro, suena una vez: "la llamada" entera — Sol-Do-Mi-Sol — con timbales y platillo, y su cierre
# en la tónica) y después un bucle de celebración, ligero, para lo que dure la pantalla (la pista prestada de antes
# duraba 85 s y se acababa). Do mayor, 132 BPM; la melodía, a saltitos con un adelanto (2-1-3); bajo que camina por el
# acorde, palmas en 2 y 4, pandereta; cierra la frase B con la llamada.
W_IN = PH("0:G4/4 4:C5/4 8:E5/4 12:G5/4", "0:C6/12 12:G5/4", "0:A5/4 4:F5/4 8:B5/4 12:D6/4", "0:C6/16")
WCH_IN = [(C, MAJ), (C, MAJ), ((Fr_, MAJ), (G, MAJ)), (C, MAJ)]
W_A = PH("0:E5/2 2:G5/1 3:C6/3 6:G5/2 8:E5/4 12:G5/4", "0:A5/2 2:C6/1 3:E6/3 6:C6/2 8:A5/8",
         "0:F5/2 2:A5/1 3:C6/3 6:A5/2 8:F5/4 12:A5/4", "0:G5/2 2:B5/1 3:D6/3 6:B5/2 8:G5/8",
         "0:E5/2 2:G5/1 3:C6/3 6:G5/2 8:E5/4 12:G5/4", "0:E6/4 4:C6/4 8:A5/4 12:C6/4",
         "0:A5/2 2:C6/2 4:F6/4 8:B5/2 10:D6/2 12:G5/4")
W_END = P(8, "0:C6/4 4:G5/4 8:E5/8")
W_END2 = P(8, "0:E6/4 4:G5/4 8:C6/8")
W_B = PH("0:A5/8 8:F5/4 12:A5/4", "0:G5/8 8:E5/4 12:G5/4", "0:B5/8 8:D6/4 12:B5/4", "0:C6/6 6:G5/2 8:E5/8",
         "0:C6/8 8:A5/4 12:F5/4", "0:E6/8 8:C6/4 12:G5/4", "0:D6/4 4:A5/4 8:B5/4 12:D6/4", "0:G4/4 4:C5/2 6:E5/2 8:G5/6")
WCH_A = [(C, MAJ), (A, MIN), (Fr_, MAJ), (G, MAJ), (C, MAJ), (A, MIN), ((Fr_, MAJ), (G, MAJ)), (C, MAJ)]
WCH_B = [(Fr_, MAJ), (C, MAJ), (G, MAJ), (C, MAJ), (Fr_, MAJ), (C, MAJ), ((D, MIN), (G, MAJ)), (C, MAJ)]


# ── gummy_king_boss, 2ª versión: "Su Majestad Gummy" de CORTE (el usuario: más regio y menos parecido a la pradera).
# La 1ª iba en Sol mayor con el bajo saltarín, los acordes a contratiempo y el trino de la pradera. Ahora: Si♭ mayor
# (tonalidad de metales), fanfarria de trompeta A TIEMPO (nada de síncopas juguetonas) con su llamada "ta-ta taa",
# trompas una octava abajo, acordes tenidos, bajo de marcha (tónica y quinta en negras), caja militar con sus
# redobles, timbales en tónica y dominante; la parte B es una danza de corte en menor: secuencia barroca por grados
# sobre un clavecín en semicorcheas.
R2_A = PH("0:F5/4 4:Bb5/6 10:Bb5/1 11:Bb5/1 12:D6/4", "0:C6/3 3:Bb5/1 4:A5/2 6:Bb5/2 8:F5/8",
          "0:G5/4 4:Bb5/6 10:Bb5/1 11:Bb5/1 12:Eb6/4", "0:D6/3 3:C6/1 4:Bb5/2 6:A5/2 8:C6/8",
          "0:F5/4 4:Bb5/6 10:Bb5/1 11:Bb5/1 12:D6/4", "0:D6/3 3:C6/1 4:Bb5/2 6:G5/2 8:D5/4 12:G5/4",
          "0:Eb5/2 2:G5/2 4:Bb5/2 6:Eb6/2 8:C6/2 10:A5/2 12:F5/2 14:A5/2")
R2_END = P(8, "0:Bb5/3 3:Bb5/1 4:Bb5/4 8:F5/8")
R2_END2 = P(8, "0:Bb5/3 3:Bb5/1 4:D6/4 8:Bb5/8")
R2_B = PH("0:D6/2 2:C6/2 4:Bb5/2 6:A5/2 8:Bb5/4 12:G5/4", "0:A5/2 2:G5/2 4:F5/2 6:Eb5/2 8:F5/4 12:D5/4",
          "0:Bb5/2 2:A5/2 4:G5/2 6:F5/2 8:G5/4 12:Eb5/4", "0:C6/2 2:Bb5/2 4:A5/2 6:G5/2 8:A5/4 12:F5/4",
          "0:G5/4 4:Bb5/4 8:D6/6 14:Bb5/2", "0:F5/4 4:A5/4 8:D6/6 14:A5/2",
          "0:G5/2 2:Bb5/2 4:Eb6/4 8:F5/2 10:A5/2 12:C6/4", "0:F4/4 4:Bb4/2 6:D5/2 8:F5/6")       # la llamada en Si♭
R2CH_A = [(Bbr_, MAJ), (Bbr_, MAJ), (Ebr_, MAJ), (Fr_, MAJ), (Bbr_, MAJ), (G, MIN), ((Ebr_, MAJ), (Fr_, MAJ)), (Bbr_, MAJ)]
R2CH_B = [(G, MIN), (D, MIN), (Ebr_, MAJ), (Fr_, MAJ), (G, MIN), (D, MIN), ((Ebr_, MAJ), (Fr_, MAJ)), (Bbr_, MAJ)]


def song(variant, minor=False, solo=False, theme=None):
    """→ melodía [(compás, semicorchea, nota, dur)], acordes [(1ª mitad, 2ª mitad)] por compás, etiqueta de cada
    compás ('intro' | 'A' | 'B' | 'solo') y los compases donde EMPIEZA una frase"""
    global SCALE
    SCALE = {'galope': SCALE_C, 'calipso': SCALE_F, 'arrecife': SCALE_Bb, 'marcha': SCALE_Cm, 'engranajes': SCALE_Gm, 'persecucion': SCALE_Cm,
             'cumbres': SCALE_F, 'ventisca': SCALE_Dm, 'bola': SCALE_Fm, 'majestad': SCALE_Bb, 'ecos': SCALE_Ddor, 'laberinto': SCALE_Am, 'ceniza': SCALE_Ephr, 'fuego': SCALE_Aphr, 'victoria': SCALE_C}.get(theme, SCALE_G)
    pi, ci = [], None                                  # (la intro puede llevar melodía y acordes propios: la fanfarria)
    if theme == 'victoria': pa, e1, e2, pb, ca, cb, tonic, pi, ci = W_A, W_END, W_END2, W_B, WCH_A, WCH_B, (C, MAJ), W_IN, WCH_IN
    elif theme == 'ceniza': pa, e1, e2, pb, ca, cb, tonic = L_A, L_END, L_END2, L_B, LCH_A, LCH_B, (E, MIN)
    elif theme == 'fuego': pa, e1, e2, pb, ca, cb, tonic = F_A, F_END, F_END2, F_B, FCH_A, FCH_B, (A, MIN)
    elif theme == 'ecos': pa, e1, e2, pb, ca, cb, tonic = C_A, C_END, C_END2, C_B, CCH_A, CCH_B, (D, MIN)
    elif theme == 'laberinto': pa, e1, e2, pb, ca, cb, tonic = U_A, U_END, U_END2, U_B, UCH_A, UCH_B, (A, MIN)
    elif theme == 'cumbres': pa, e1, e2, pb, ca, cb, tonic = S_A, S_END, S_END2, S_B, SCH_A, SCH_B, (Fr_, MAJ)
    elif theme == 'ventisca': pa, e1, e2, pb, ca, cb, tonic = V_A, V_END, V_END2, V_B, VCH_A, VCH_B, (D, MIN)
    elif theme == 'bola': pa, e1, e2, pb, ca, cb, tonic = O_A, O_END, O_END2, O_B, OCH_A, OCH_B, (Fr_, MIN)
    elif theme == 'majestad': pa, e1, e2, pb, ca, cb, tonic = R2_A, R2_END, R2_END2, R2_B, R2CH_A, R2CH_B, (Bbr_, MAJ)
    elif theme == 'persecucion': pa, e1, e2, pb, ca, cb, tonic = X_A, X_END, X_END2, X_B, XCH_A, XCH_B, (C, MIN)
    elif theme == 'marcha': pa, e1, e2, pb, ca, cb, tonic = H_A, H_END, H_END2, H_B, HCH_A, HCH_B, (C, MIN)
    elif theme == 'engranajes': pa, e1, e2, pb, ca, cb, tonic = N_A, N_END, N_END2, N_B, NCH_A, NCH_B, (G, MIN)
    elif theme == 'calipso': pa, e1, e2, pb, ca, cb, tonic = K_A, K_END, K_END2, K_B, KCH_A, KCH_B, (Fr, MAJ)
    elif theme == 'arrecife': pa, e1, e2, pb, ca, cb, tonic = R_A, R_END, R_END2, R_B, RCH_A, RCH_B, (Bbr, MAJ)
    elif theme == 'galope': pa, e1, e2, pb, ca, cb, tonic = P_A, P_END, P_END2, P_B, PCH_A, PCH_B, (C, MAJ)
    elif minor: pa, e1, e2, pb, ca, cb, tonic = M_A, M_END, M_END2, M_B, MCH_A, MCH_B, (E, MIN)
    elif variant == 'B': pa, e1, e2, pb, ca, cb, tonic = A_SONG, A_SONG_END, A_SONG_END2, PH_B, GCH_A, GCH_B, (G, MAJ)
    else: pa, e1, e2, pb, ca, cb, tonic = A_HOP, A_HOP_END, A_HOP_END2, PH_B, GCH_A, GCH_B, (G, MAJ)
    pc, cc = {'cumbres': (S_C, SCH_C), 'bola': (O_C, OCH_C)}.get(theme, (None, None))     # el estribillo (tras el puente B)
    mel, ch, tag, starts = [], [], [], []
    def section(kind, ph, chords):
        base = len(ch)
        starts.append(base + 1)
        for b, st, n, d in ph: mel.append((base + b, st, n, d))
        for c in chords:
            ch.append(c if isinstance(c[0], tuple) else (c, c))
            tag.append(kind)
    section('intro', pi, ci or [tonic] * INTRO)
    section('A', pa + e1, ca)
    section('A', pa + e2, ca)
    section('B', pb, cb)
    if pc: section('C', pc, cc)
    if solo: section('solo', [], [tonic] * 8)          # (solo de percusión: sin melodía ni acordes)
    section('A', pa + e2, ca)
    return mel, ch, tag, starts[1:]


I_LEAD = {'vol': [15, 14, 13, 13, 12, 12], 'sus': 12, 'vib': (12, 0.22, 5.6), 'duty': [0.25, 0.5]}
I_FLUTE = {'vol': [9, 12, 14, 14, 13, 13], 'sus': 12, 'vib': (10, 0.25, 5.4)}
I_PLUCK = {'vol': [12, 9, 6, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_TRI = {'vol': [15], 'sus': 15}
I_TRILL = {'vol': [9, 8, 7, 6, 5, 4], 'sus': 3, 'duty': 0.125}
I_ECHO = {'vol': [5, 5, 4, 3], 'sus': 2, 'duty': 0.5}
WAVES = [wavetable([1.0, 0.45, 0.12, 0.2, 0.03]),            # 0 flauta
         wavetable([1.0, 0.3, 0.1])]                         # 1 colchón
I_STEEL = {'vol': [15, 14, 12, 11, 10, 9, 8, 7, 6, 6, 5, 5, 4, 4, 3, 3], 'sus': 3, 'vib': (10, 0.12, 6)}
I_MARIMBA = {'vol': [10, 7, 5, 3, 2, 1], 'sus': 0, 'duty': 0.5}
I_OCA = {'vol': [6, 10, 12, 12, 11, 11], 'sus': 11, 'vib': (14, 0.22, 5.0), 'duty': 0.5}
I_PADP = {'vol': [1, 2, 2, 3, 3, 4], 'sus': 4, 'duty': 0.25}
WAVES.append(wavetable([1.0, 0.7, 0.35, 0.45, 0.1, 0.2]))    # 2 steel drum (metálico, brillante)
I_SOFTACC = {'vol': [7, 6, 5, 4, 3, 2], 'sus': 2, 'duty': 0.5}              # acento discreto (jefes)
I_DING = {'vol': [13, 11, 10, 9, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1], 'sus': 1, 'duty': 0.25}       # una campana que se apaga
I_LAUGH = {'vol': [12, 10, 7, 4, 2], 'sus': 1, 'duty': 0.5, 'drop': [2, 1, 0]}
I_SIREN = {'vol': [8, 10, 11, 11, 10, 10], 'sus': 10, 'vib': (0, 2.0, 2.6), 'duty': 0.25}             # aúlla ±2 semitonos
I_HORNLOW = {'vol': [9, 12, 13, 12, 11, 11], 'sus': 11, 'duty': 0.5}
I_BUBBLE = {'vol': [12, 9, 6, 3, 1], 'sus': 0, 'duty': 0.5, 'drop': [-7, -4, -2, 0]}                  # sube al nacer
I_CLOP = {'vol': [13, 6, 2], 'sus': 0, 'duty': 0.5, 'drop': [5, 0]}                                   # madera
I_BRASS = {'vol': [10, 14, 15, 14, 13, 13], 'sus': 13, 'vib': (16, 0.15, 5.5), 'duty': 0.25}      # trompeta
I_HORN = {'vol': [6, 9, 10, 10, 9, 9], 'sus': 9, 'duty': 0.5}                                    # trompas
I_ORG = {'vol': [5, 6, 7, 7, 6, 6], 'sus': 6, 'duty': 0.5}                                       # acordes tenidos
I_SAWL = {'vol': [15, 14, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.18, 6)}
I_DBL = {'vol': [9, 8, 7, 7, 6, 6], 'sus': 6, 'duty': 0.25}
I_STAB = {'vol': [13, 10, 7, 4, 2, 1], 'sus': 0, 'duty': 0.25}
I_FANF = {'vol': [13, 12, 10, 8, 6, 5], 'sus': 4, 'duty': 0.25}
I_CLOCK = {'vol': [15, 13, 11, 10, 9, 9], 'sus': 8, 'vib': (16, 0.15, 6), 'duty': 0.125}
I_TICK = {'vol': [9, 5, 2, 1], 'sus': 0, 'duty': 0.125}
I_ANVIL = {'vol': [14, 9, 6, 4, 3, 2, 1], 'sus': 0, 'duty': 0.125}
WAVES.append(GN.CWAVES[0])                                    # 3 caja de música
I_BOX = dict(GN.I_BELL, duty=3.0)
I_SOFT = {'vol': [5, 7, 8, 8, 7, 7], 'sus': 7, 'vib': (14, 0.15, 5.0), 'duty': 0.5}
I_FLAKE = {'vol': [7, 4, 2, 1], 'sus': 0, 'duty': 0.125}
I_FALL = {'vol': [10, 7, 5, 3, 2, 1], 'sus': 0, 'duty': 0.125}
SNOW = ('nieve', 'ventisca', 'bola')
WAVES.append(wavetable([1.0, 0.6, 0.4, 0.25, 0.15]))             # 4 metal cálido (volcán; antes una onda áspera)
I_HOT = {'vol': [11, 14, 15, 14, 13, 13], 'sus': 13, 'vib': (14, 0.18, 5.5), 'duty': 4.0}
I_GTR = {'vol': [13, 10, 8, 6, 5, 4, 3, 2], 'sus': 2, 'duty': 0.125}                 # punteo (el acento del volcán)
I_TREM = {'vol': [7, 4, 2], 'sus': 0, 'duty': 0.25}
VOLC = ('volcan', 'lava')
I_HARP = {'vol': [8, 6, 5, 4, 3, 2, 1], 'sus': 0, 'duty': 0.5}
CAVE = ('cueva', 'sumergida')
ISLE_LV = {
    'fiesta': {'lead': 0, 'dbl': -9, 'echo': -12, 'chords': -10, 'bass': -2, 'trill': -8, 'kick': -2, 'snare': -5, 'hat': -12, 'crash': -9, 'toms': -1},
    'volcan': {'lead': 0, 'dbl': -8, 'echo': -13, 'chords': -10, 'bass': -1, 'trill': -6, 'kick': 0, 'snare': -3, 'hat': -12, 'crash': -10, 'toms': 0},
    'lava':   {'lead': 0, 'dbl': -9, 'echo': -13, 'chords': -9, 'bass': -1, 'trill': -7, 'kick': 0, 'snare': -3, 'hat': -12, 'crash': -10, 'toms': 0},
    'cueva':     {'lead': -9, 'bell': 0, 'echo': -10, 'chords': -9, 'bass': -2, 'trill': -2, 'kick': -3, 'snare': -10, 'hat': -14, 'crash': -14, 'toms': 0},
    'sumergida': {'lead': 0, 'echo': -8, 'chords': -10, 'bass': -3, 'trill': -9, 'kick': -6, 'snare': -15, 'hat': -15, 'crash': -14, 'toms': 0},
    'nieve':    {'lead': -5, 'bell': 0, 'echo': -12, 'chords': -11, 'bass': -3, 'trill': -5, 'kick': -5, 'snare': -10, 'hat': -11, 'crash': -13, 'toms': 0},
    'ventisca': {'lead': 0, 'bell': -6, 'echo': -11, 'chords': -11, 'bass': -1, 'trill': -7, 'kick': -2, 'snare': -5, 'hat': -12, 'crash': -11, 'toms': 0},
    'bola':     {'lead': 0, 'bell': -4, 'echo': -12, 'chords': -7, 'bass': -1, 'trill': -14, 'kick': 0, 'snare': -3, 'hat': -10, 'crash': -9, 'toms': -1},
    'rey':  {'lead': 0, 'dbl': -7, 'echo': -13, 'chords': -9, 'bass': -1.5, 'trill': -6, 'kick': 0, 'snare': -3, 'hat': -14, 'crash': -9, 'toms': -1},
    'nave': {'lead': 0, 'dbl': -9, 'echo': -12, 'chords': -8, 'bass': -1, 'trill': -15, 'kick': 0, 'snare': -3, 'hat': -9, 'crash': -9, 'toms': 0},
    'fortaleza': {'lead': 0, 'dbl': -9, 'echo': -12, 'chords': -8, 'bass': -1, 'trill': -6, 'kick': -2, 'snare': -4, 'hat': -11, 'crash': -11, 'toms': 2},
    'maquina':   {'lead': 0, 'dbl': -9, 'echo': -11, 'chords': -10, 'bass': -1, 'trill': -6, 'kick': -3, 'snare': -7, 'hat': -10, 'crash': -12, 'toms': 2},
    'costa':    {'lead': 0, 'echo': -10, 'chords': -8, 'bass': -2, 'trill': -10, 'kick': -4, 'snare': -8, 'hat': -11, 'crash': -12, 'toms': 2},
    'arrecife': {'lead': 0, 'echo': -9, 'chords': -7, 'bass': -3, 'trill': -16, 'kick': -7, 'snare': -13, 'hat': -15, 'crash': -14, 'toms': 0},
}
HAT, SNARE_N, CRASH = [5, 2, 1], [13, 9, 5, 2], [13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]


# Timbales (DPCM): seno que cae, tres alturas
def _tom(f0):
    t = F.t_(int(0.22 * SR))
    return F.dpcm(np.sin(2 * np.pi * np.cumsum(f0 * (0.55 + 0.45 * np.exp(-t / 0.05))) / SR) * np.exp(-t / 0.09))
TOMS = [_tom(260), _tom(190), _tom(130)]


def solo_bar(k, at, kick, sn, tom, NZ, hit):
    """SOLO DE PERCUSIÓN (8 compases, k = 1..8), intenso y cada vez más lleno: llamada y respuesta entre caja y
    timbales (2 compases cada idea), bombo que pasa de negras a corcheas, redoble final en semicorcheas que sube
    de volumen y platillo."""
    for st in range(16):
        t = at(st)
        # bombo: negras; desde el 5º compás, corcheas
        if st % (4 if k <= 4 else 2) == 0: hit(kick, TN.KICK, t, 0.95)
        # platos en semicorcheas (abiertos en las "y")
        NZ['hat'].hit(t, 0, [6, 3, 1] if st % 4 == 2 else [4, 1])
        if k in (1, 3):                                   # la caja pregunta: 3+3+2 y un redoblito
            if st in (0, 3, 6, 8, 11, 14): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.9)
            if st in (12, 13): NZ['snare'].hit(t, 4, [8, 4, 2])
        elif k in (2, 4):                                 # los timbales contestan bajando (agudo, medio, grave)
            pat = {0: 0, 2: 0, 3: 1, 6: 1, 8: 2, 10: 0, 11: 1, 12: 2, 14: 2} if k == 2 else {0: 0, 1: 0, 3: 1, 4: 1, 6: 2, 8: 0, 9: 1, 10: 2, 12: 2, 13: 2, 14: 1, 15: 0}
            if st in pat: hit(tom, TOMS[pat[st]], t, 1.0)
            if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.8)
        elif k in (5, 6):                                 # todo a la vez: caja en 2 y 4 + síncopas, timbales entre medias
            if st in (4, 12) or (k == 6 and st in (7, 10, 15)): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.95)
            if st in (2, 3, 6, 9, 11, 14): hit(tom, TOMS[(st // 3) % 3], t, 0.9)
        elif k == 7:                                      # timbales corridos de agudo a grave, dos veces
            hit(tom, TOMS[min(2, (st % 8) // 3)], t, 0.85 + 0.15 * (st % 2 == 0))
            if st % 4 == 0: NZ['snare'].hit(t, 4, SNARE_N)
        else:                                             # redoble de caja que crece + platillo al entrar la frase
            v = 5 + int(st * 0.6)
            NZ['snare'].hit(t, 4, [v, max(1, v - 4), 1]); hit(sn, TN.SNARE_BODY, t, 0.4 + st * 0.04)
            if st >= 12: hit(tom, TOMS[2], t, 0.9)
        if st == 0 and k in (1, 5): NZ['crash'].hit(t, 3, CRASH)


BACKING = 4.0                # dB que sube el acompañamiento respecto a la melodía (ver build)
BACKING_KEYS = ('chords', 'bass', 'kick', 'snare', 'hat', 'crash', 'toms')
STEMS_TO = None
STEM_NAMES = [('lead', 'melodia'), ('echo', 'eco_de_la_melodia'), ('dbl', 'melodia_doblada'), ('bell', 'caja_de_musica'),
              ('chords', 'acordes_a_contratiempo'), ('trill', 'acento_del_sitio'), ('bass', 'bajo'), ('kick', 'bombo'),
              ('snare', 'caja'), ('hat', 'platos'), ('crash', 'platillo'), ('toms', 'timbales')]


def build(name, variant='A', bpm=136, minor=False, drive=0, lufs=-11.5, solo=False, theme=None, flute=None, isle='pradera', boss=False):
    """isle: el arreglo ('pradera' | 'costa' = calipso | 'arrecife' = bossa de agua). drive: 0 = tema (batería ligera) · 1 = segunda cara (más empuje) · 2 = bonus (competición)"""
    S16 = 60.0 / bpm / 4
    BAR = 16 * S16
    mel, ch, tag, starts = song(variant, minor, solo, theme)
    NB = len(ch)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'echo', 'c1', 'c2', 'bass', 'trill', 'dbl', 'bell')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash', 'fx')}
    NS = int(NF * F.FRAME_S) + SR
    kick, sn, tom = np.zeros(NS), np.zeros(NS), np.zeros(NS)
    tv = lambda b, st: (b - 1) * BAR + st * S16
    flute = variant == 'C' if flute is None else flute
    galop = theme == 'galope'

    def hit(buf, smp, t, g=1.0):
        i = int(t * SR)
        m = max(0, min(len(smp), NS - i))
        buf[i:i + m] += smp[:m] * g

    busy = set()
    for b, st, n, d in mel:
        t0, t1 = tv(b, st), tv(b, st) + d * S16 * 0.94
        if isle == 'fiesta':                                 # trompeta + su octava
            play(Cn['lead'], t0, t1, n, I_BRASS, release=3)
            play(Cn['dbl'], t0, t1, n + 12, I_DBL, release=2)
        elif isle == 'volcan':                               # voz áspera (N163) + trompas una octava abajo
            play(Cn['lead'], t0, t1, n, I_HOT, q=q_n163, release=3)
            play(Cn['dbl'], t0, t1, n - 12, I_HORN, release=2)
        elif isle == 'lava':                                 # pulso una octava abajo (el latigazo es agudo) + su octava
            play(Cn['lead'], t0, t1, n - 12, I_LEAD, release=2)
            play(Cn['dbl'], t0, t1, n, I_DBL, release=1)
        elif isle == 'cueva':                                # la caja de música (el eco de cueva va en la mezcla) + un pulso muy suave abajo
            play(Cn['bell'], t0, t0 + max(d, 4) * S16, n, I_BOX, q=q_n163, release=6)
            play(Cn['lead'], t0, t1, n - 12, I_SOFT, release=3)
        elif isle == 'sumergida':                            # flauta hueca
            play(Cn['lead'], t0, t1, n, dict(I_FLUTE, duty=0.0), q=q_n163, release=4)
        elif isle == 'nieve':                                # la CAJA DE MÚSICA una octava arriba + un pulso suave a su altura
            play(Cn['bell'], t0, t0 + max(d, 4) * S16, n + 12, I_BOX, q=q_n163, release=6)
            play(Cn['lead'], t0, t1, n, I_SOFT, release=3)
        elif isle in ('ventisca', 'bola'):                   # pulso; la campana dobla (ventisca: solo las notas largas)
            play(Cn['lead'], t0, t1, n, I_LEAD, release=3)
            if isle == 'bola' or d >= 6: play(Cn['bell'], t0, t0 + max(d, 4) * S16, n + 12, I_BOX, q=q_n163, release=6)
        elif isle == 'rey':                                  # pulso + su octava (pomposo)
            play(Cn['lead'], t0, t1, n, I_BRASS, release=3)          # trompeta, y las trompas una octava abajo
            play(Cn['dbl'], t0, t1, n - 12, I_HORN, release=3)
        elif isle in ('fortaleza', 'nave'):                  # sierra (una octava abajo: cuerpo) + pulso a su altura
            play(Cn['lead'], t0, t1, n - 12, I_SAWL, q=q_saw, release=3)
            play(Cn['dbl'], t0, t1, n, I_DBL, release=2)
        elif isle == 'maquina': play(Cn['lead'], t0, tv(b, st) + (d * 0.94 if d >= 4 else d * 0.6) * S16, n, I_CLOCK, release=2)
        elif isle == 'costa': play(Cn['lead'], t0, tv(b, st) + max(d, 3) * S16, n, dict(I_STEEL, duty=2.0), q=q_n163, release=4)
        elif isle == 'arrecife': play(Cn['lead'], t0, t1, n, I_OCA, release=4)
        elif flute: play(Cn['lead'], t0, t1, n, dict(I_FLUTE, duty=0.0), q=q_n163, release=3)
        else: play(Cn['lead'], t0, t1, n, I_LEAD, release=3)
        # eco: la misma nota 3 semicorcheas después, floja (más melodía de la que se toca)
        if d >= 3: play(Cn['echo'], t0 + 3 * S16, t0 + 3 * S16 + min(d, 3) * S16 * 0.8, n, I_ECHO, release=1)
        for k in range(d): busy.add((b, st + k))
    last_in_bar = {}
    for b, st, n, d in mel: last_in_bar[b] = max(last_in_bar.get(b, 0), st + d)

    for b in range(1, NB + 1):
        intro = tag[b - 1] == 'intro'
        in_b = tag[b - 1] == 'B'
        if tag[b - 1] == 'solo':
            solo_bar(b - tag.index('solo'), lambda st: tv(b, st), kick, sn, tom, NZ, hit)
            continue
        for half in (0, 1):
            r, q = ch[b - 1][half]
            root = 36 + (r - 36) % 12
            notes = [60 + (r - 60) % 12 + iv for iv in q]
            s0 = half * 8
            # BAJO saltarín: 1-5-8-5 en corcheas (en la intro entra en el compás 3; en B, negras)
            if not intro or b >= 3 or isle == 'fiesta':
                pat = ((0, 0, 3.4), (4, 12, 3.4)) if in_b else ((0, 0, 1.7), (2, 7, 1.7), (4, 12, 1.7), (6, 7, 1.7))
                if drive: pat = ((0, 0, 1.6), (2, 12, 1.6), (4, 0, 1.6), (6, 7, 1.6))
                if galop and not in_b: pat = ((0, 0, 2.6), (3, 0, 0.9), (4, 7, 2.6), (7, 7, 0.9))     # (tan-ta tan-ta)
                if isle == 'costa' and drive < 2: pat = ((0, 0, 2.7), (3, 7, 0.9), (4, 12, 3.3))             # calipso: 1, 1y, 3
                if isle == 'fortaleza' and drive < 2: pat = ((0, 0, 3.2), (4, 12, 3.2)) if in_b else ((0, 0, 1.5), (2, 12, 1.5), (4, 0, 1.5), (6, 12, 1.5))   # octavas
                if isle == 'fiesta': pat = ((0, 0, 1.6), (2, q[1], 1.6), (4, 7, 1.6), (6, q[1], 1.6))                    # camina por el acorde
                if isle == 'fiesta' and intro: pat = ((0, 0, 7.6),)
                if isle == 'volcan': pat = ((0, 0, 1.6), (2, 0, 1.6), (4, 0, 1.6), (6, 12, 1.6))                       # corcheas
                if isle == 'lava': pat = ((0, 0, 0.9), (1, 0, 0.9), (2, 0, 1.7), (4, 0, 0.9), (5, 0, 0.9), (6, 12, 1.7))     # galope
                if isle in CAVE and drive < 2: pat = ((0, 0, 7.7),)                                          # redondas
                if isle == 'nieve' and drive < 2: pat = ((0, 0, 7.5),)                                       # blancas
                if isle == 'ventisca': pat = ((0, 0, 1.6), (2, 0, 1.6), (4, 12, 1.6), (6, 0, 1.6))
                if isle == 'bola' and in_b: pat = ((0, 0, 1.6), (2, 0, 1.6), (4, 12, 1.6), (6, 0, 1.6))       # (el puente: corcheas)
                elif isle == 'bola': pat = tuple((k_, (0, 0, 12, 0, 0, 0, 12, 7)[k_], 0.9) for k_ in range(8))   # RUEDA
                if isle == 'rey': pat = ((0, 0, 3.0), (4, 7, 3.0))                                           # marcha: tónica y quinta, en negras
                if isle == 'nave': pat = ((0, 0, 1.5), (2, 0, 1.5), (4, 12, 1.5), (6, 0, 1.5))              # no para
                if isle == 'maquina': pat = ((0, 0, 1.6), (2, 0, 0.8), (3, 12, 0.8), (4, 0, 1.6), (6, 0, 0.8), (7, 12, 0.8))   # locomotora
                if isle == 'arrecife': pat = ((0, 0, 5.4), (6, 7, 1.8))                                    # bossa: largo y la quinta
                for st, iv, ln in pat:
                    play(Cn['bass'], tv(b, s0 + st), tv(b, s0 + st) + ln * S16, root + iv, I_TRI, q=q_tri, release=0)
            if isle == 'fiesta':                             # acordes tenidos, flojos
                play(Cn['c1'], tv(b, s0), tv(b, s0) + 7.4 * S16, notes[1], I_ORG, release=3)
                play(Cn['c2'], tv(b, s0), tv(b, s0) + 7.4 * S16, notes[2], I_ORG, release=3)
                continue
            if isle == 'volcan' and not in_b:                # quintas en TRÉMOLO de semicorcheas
                for st in range(8):
                    play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 0.6, notes[0] - 12, I_TREM, release=0)
                    play(Cn['c2'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 0.6, notes[2] - 12, I_TREM, release=0)
                continue
            if isle in VOLC:                                 # quintas tenidas
                play(Cn['c1'], tv(b, s0), tv(b, s0) + 7.4 * S16, notes[0] - 12, I_ORG, release=3)
                play(Cn['c2'], tv(b, s0), tv(b, s0) + 7.4 * S16, notes[2] - 12, I_ORG, release=3)
                continue
            if isle == 'cueva':                              # colchón
                play(Cn['c1'], tv(b, s0), tv(b, s0) + 7.6 * S16, notes[1], I_PADP, release=6)
                play(Cn['c2'], tv(b, s0), tv(b, s0) + 7.6 * S16, notes[2], I_PADP, release=6)
                continue
            if isle == 'sumergida':                          # arpa: el acorde en corcheas, sube y baja
                for k_, st in enumerate((0, 2, 4, 6)):
                    play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 1.8, notes[(0, 1, 2, 1)[k_]] + (12 if half else 0), I_HARP, release=2)
                continue
            if isle == 'rey':
                if in_b:                                     # clavecín: el acorde en semicorcheas (bajo de Alberti)
                    for st in range(8):
                        play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 0.8, notes[(0, 2, 1, 2)[st % 4]] + 12, I_FLAKE, vs=1.3, release=0)
                else:                                        # acordes tenidos (tercera y quinta)
                    play(Cn['c1'], tv(b, s0), tv(b, s0) + 7.4 * S16, notes[1], I_ORG, release=3)
                    play(Cn['c2'], tv(b, s0), tv(b, s0) + 7.4 * S16, notes[2], I_ORG, release=3)
                continue
            if isle == 'nieve':
                # COPOS: el acorde en corcheas, muy cortas y agudas
                for k_, st in enumerate((0, 2, 4, 6)):
                    play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 0.8, notes[(k_ + half) % 3] + 12, I_FLAKE, release=0)
                continue
            if isle == 'ventisca':
                # VIENTO: arpegio en semicorcheas que sube y baja
                for st in range(8):
                    play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 0.7, notes[(0, 1, 2, 1)[st % 4]] + (12 if st >= 4 else 0), I_FLAKE, release=0)
                continue
            if isle == 'nave':
                # golpes de quinta 3+3+2 (empujan)
                for st in (0, 3, 6):
                    play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + 1.5 * S16, notes[0], I_STAB, release=1)
                    play(Cn['c2'], tv(b, s0 + st), tv(b, s0 + st) + 1.5 * S16, notes[2], I_STAB, release=1)
                continue
            if isle == 'fortaleza':
                # golpes de QUINTA (sin tercera: duro) con el ritmo de la marcha: tan · ta-ta
                for st, ln in ((0, 1.6), (6, 0.8), (7, 0.8)) if not in_b else ((0, 3.0), (4, 3.0)):
                    play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + ln * S16, notes[0], I_STAB, release=1)
                    play(Cn['c2'], tv(b, s0 + st), tv(b, s0 + st) + ln * S16, notes[2], I_STAB, release=1)
                continue
            if isle == 'maquina':
                # TIC-TAC: quinta y tónica en corcheas, muy cortas
                for k_, st in enumerate((0, 2, 4, 6)):
                    play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 0.7, notes[2] if k_ % 2 == 0 else notes[0] + 12, I_TICK, release=0)
                continue
            if isle == 'costa':
                # MARIMBA: el acorde arpegiado en corcheas (suave)
                for k_, st in enumerate((0, 2, 4, 6)):
                    nn = notes[(k_ + half) % 3] + (12 if k_ == 3 else 0)
                    play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + S16 * 1.4, nn, I_MARIMBA, release=1)
                continue
            if isle == 'arrecife':
                # colchón (dos notas largas) y un arpegio lento en negras
                play(Cn['c1'], tv(b, s0), tv(b, s0) + 7.6 * S16, notes[1], I_PADP, release=6)
                play(Cn['c2'], tv(b, s0), tv(b, s0) + 7.6 * S16, notes[2], I_PADP, release=6)
                continue
            # ACORDES a contratiempo (en las "y")
            for st in (2, 6):
                play(Cn['c1'], tv(b, s0 + st), tv(b, s0 + st) + S16, notes[0] + 12 if notes[0] < 64 else notes[0], I_PLUCK, release=1)
                play(Cn['c2'], tv(b, s0 + st), tv(b, s0 + st) + S16, notes[1] + (12 if notes[1] < 66 else 0), I_PLUCK, release=1)
        # TRINO de pájaro (el motivo de la isla): donde la melodía se queda quieta, y en la intro
        free_from = last_in_bar.get(b, 0)
        long_tail = any(bb == b and st + d >= 14 and d >= 6 for bb, st, n, d in mel)
        snow_tail = isle in SNOW and b % 2 == 0 and not intro and any(bb == b and st == 12 and d == 4 for bb, st, n, d in mel)   # (sus frases cierran en negra)
        if isle in CAVE and b % 2 == 1 and not intro: long_tail = False        # (cuevas: un acento cada dos compases, no más)
        if isle == 'fiesta' and intro: long_tail = False
        if (intro and b % 2 == 0 and isle != 'fiesta') or (long_tail and not in_b) or snow_tail or (isle in CAVE and long_tail):
            r, q = ch[b - 1][1]
            top = 84 + (r - 84) % 12 + q[2] - 12
            up = 2 if (top + 2) % 12 in SCALE else 1          # (la nota de al lado, DE LA ESCALA: +2 sobre Si daba Do#)
            # EL ACENTO DE CADA SITIO. Antes casi todos eran "unas notitas agudas de pulso en semicorcheas en el mismo
            # hueco" — el trino de la pradera adaptado —, y como la pradera es lo primero que se oye, todo sonaba a
            # remezcla de la pradera (el usuario lo localizó con las capas: `trino_adorno`). Ahora cada uno es de
            # su sitio: otro timbre, otro ritmo y muchas veces sin altura (ruido, tambores). El trino queda SOLO
            # para pradera_1 y su bonus.
            t8 = lambda st: tv(b, st)
            lowr = 60 + (r - 60) % 12
            def swell(st0, st1, per, peak, shape='wave', short=0):
                """ruido que crece y se va ('wave': ola) o que crece y corta ('gust': racha / redoble de plato)"""
                n_ = max(2, int((st1 - st0) * S16 * 60))
                for i_ in range(n_):
                    x_ = i_ / (n_ - 1)
                    v_ = np.sin(np.pi * x_) if shape == 'wave' else x_ ** 1.5
                    pp = per if not isinstance(per, tuple) else int(round(per[0] + (per[1] - per[0]) * x_))
                    NZ['fx'].hit(t8(st0) + i_ / 60.0, pp, [max(1, int(round(peak * v_)))], short=short)
            # (volcán: el acento era ruido — una erupción, una bola de fuego — y el usuario lo pidió MELÓDICO: un punteo)
            if isle == 'fiesta':                              # "¡ta-chán!": la quinta y la tónica de arriba
                for st, iv, ln in ((12, q[2], 1.6), (14, 12, 3)):
                    play(Cn['trill'], t8(st), t8(st) + ln * S16, 84 + (r - 84) % 12 + iv - 12, I_DING, release=4)
            elif isle == 'volcan':                            # floreo: la quinta, su vecina de arriba (de la escala), la quinta… y cae a la tónica
                fth = 72 + (r - 72) % 12 + q[2] - (12 if q[2] + (r - 72) % 12 > 9 else 0)
                nb = 1 if (fth + 1) % 12 in SCALE else 2
                for st, ln, nn in ((10, 0.9, fth), (11, 0.9, fth + nb), (12, 0.9, fth), (13, 2.8, 72 + (r - 72) % 12)):
                    play(Cn['trill'], t8(st), t8(st) + ln * S16, nn, I_GTR, release=2)
            elif isle == 'lava':                              # el acorde que SUBE punteado, en corcheas
                base_ = 72 + (r - 72) % 12
                for st, iv in ((8, 0), (10, q[1]), (12, q[2]), (14, 12)):
                    play(Cn['trill'], t8(st), t8(st) + S16 * 1.8, base_ + iv, I_GTR, release=2)
            elif isle == 'cueva':                             # GOTAS: dos, que caen (la quinta y, más abajo, la tónica)
                for st, iv in ((11, 12 + q[2]), (14, 12)):
                    play(Cn['trill'], t8(st), t8(st) + 0.07, 72 + (r - 72) % 12 + iv, GN.I_DRIP, release=0)
            elif isle == 'sumergida':                         # SONAR: una nota y su repetición, más lejos
                play(Cn['trill'], t8(9), t8(9) + S16 * 3, 84 + (r - 84) % 12 + q[2], I_DING, release=6)
                play(Cn['trill'], t8(13), t8(13) + S16 * 3, 84 + (r - 84) % 12 + q[2], I_DING, vs=0.45, release=6)
            elif isle == 'nieve':                             # un cascabeleo y UNA campana que se queda sonando
                for st in (10, 11, 12): NZ['fx'].hit(t8(st), 0, [7, 3, 1])
                play(Cn['trill'], t8(12), t8(12) + S16 * 6, 84 + (r - 84) % 12 + q[2], I_DING, release=8)
            elif isle == 'ventisca':                          # tres campanillas que bajan, espaciadas (cada tres semicorcheas)
                for st, iv in ((8, 12), (11, q[2]), (14, q[1])):
                    play(Cn['trill'], t8(st), t8(st) + S16 * 2.6, 84 + (r - 84) % 12 + iv - 12, I_DING, vs=0.9, release=4)
            elif isle == 'bola':                              # la bola rueda (timbales, flojos) y tres notas DEL ACORDE que bajan
                # (antes una "risa" grave con caída de tono, y muy fuerte: el usuario la oía como si fuera la melodía y
                # no casaba con la armonía. Ahora es un acompañamiento: notas del acorde, sin desafinar, apenas se nota)
                if not in_b:
                    for st in (12, 13, 14, 15): hit(tom, TOMS[min(2, (st - 12) // 2 + 1)], t8(st), 0.5)
                base_ = 72 + (r - 72) % 12
                for st, iv in ((10, 12), (12, q[2]), (14, q[1])):
                    play(Cn['trill'], t8(st), t8(st) + S16 * 1.5, base_ + iv, I_SOFTACC, release=2)
            elif isle == 'nave':                              # dos notas del acorde que se alternan en corcheas (quinta y tónica)
                # (antes una "sirena" que aullaba ±2 semitonos: se salía de la armonía y sonaba más que la melodía)
                base_ = 72 + (r - 72) % 12
                for i, st in enumerate((8, 10, 12, 14)):
                    play(Cn['trill'], t8(st), t8(st) + S16 * 1.5, base_ + (q[2] if i % 2 == 0 else 12), I_SOFTACC, release=2)
            elif isle == 'rey':                               # respuesta de las trompetas: el acorde sube con puntillo (taa-ta-taaa) y un timbal
                base_ = 72 + (r - 72) % 12
                for st, ln, iv in ((8, 2.8, 0), (11, 0.9, q[1]), (12, 3.6, q[2])):
                    play(Cn['trill'], t8(st), t8(st) + ln * S16, base_ + iv, I_FANF, release=2)
                hit(tom, TOMS[2], t8(12), 0.9)
            elif isle == 'fortaleza':                         # la respuesta de las trompas, GRAVE: quinta y tónica, con redoble de caja
                play(Cn['trill'], t8(10), t8(10) + S16 * 1.7, lowr - 12 + q[2], I_HORNLOW, release=1)
                play(Cn['trill'], t8(12), t8(12) + S16 * 3.6, lowr, I_HORNLOW, release=2)
                for st in (12, 13, 14, 15): NZ['fx'].hit(t8(st), 5, [6 + (st - 12), 3, 1])
            elif isle == 'maquina':                           # el carillón del reloj: quinta-tercera, dos veces (din-don, din-don)
                base_ = 72 + (r - 72) % 12
                for st, iv in ((10, q[2]), (11, q[1]), (13, q[2]), (14, q[1])):
                    play(Cn['trill'], t8(st), t8(st) + S16 * 0.9, base_ + iv, I_ANVIL, release=1)
            elif isle == 'costa':                             # la marimba contesta sincopada (ta · ta-ta · ta), no en carrerilla
                base_ = 72 + (r - 72) % 12
                for st, iv in ((9, q[2]), (11, q[1]), (12, q[2]), (14, 12)):
                    play(Cn['trill'], t8(st), t8(st) + S16 * 1.3, base_ + iv, I_MARIMBA, vs=1.2, release=1)
            elif isle == 'arrecife':                          # burbujas: notitas que suben "con chirrido"
                base_ = 84 + (r - 84) % 12
                for i, st in enumerate((9, 12, 14)):
                    play(Cn['trill'], t8(st), t8(st) + 0.09, base_ + q[i], I_BUBBLE, release=0)
            elif galop:                                       # (pradera_2) cascos de caballo: clip-clop, clip-clop
                for st, hi in ((10, 1), (11, 0), (14, 1), (15, 0)):
                    play(Cn['trill'], t8(st), t8(st) + S16 * 0.6, 76 if hi else 71, I_CLOP, release=0)
            else:                                             # (pradera_1) el trino de pájaro
                for i, st in enumerate(range(10, 16)):
                    play(Cn['trill'], tv(b, st), tv(b, st) + S16 * 0.9, top + (up if i % 2 else 0), I_TRILL, release=0)
        # BATERÍA
        for st in range(16):
            t = tv(b, st)
            if isle == 'fiesta' and intro:                   # la FANFARRIA: timbales con cada nota, platillo y redoble
                if any(bb == b and s_ == st for bb, s_, _, _ in mel): hit(tom, TOMS[2 if st % 8 == 0 else 1], t, 1.0); hit(kick, TN.KICK_DEEP, t, 0.8)
                if st == 0 and b in (2, 4): NZ['crash'].hit(t, 3, CRASH)
                if b == 4 and st >= 4: NZ['snare'].hit(t, 4, [6 + st // 2, 4, 2]); hit(sn, TN.SNARE_BODY, t, 0.3 + st * 0.04)
                continue
            if intro and b < 3:
                if st % 4 == 2 and isle not in CAVE: NZ['hat'].hit(t, 0, HAT)
                continue
            if drive == 2:                                   # competición: bombo a negras, caja en 2 y 4, platos en semicorcheas
                if st % 4 == 0: hit(kick, TN.KICK, t, 0.95)
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.8)
                NZ['hat'].hit(t, 0, HAT if st % 2 == 0 else [3, 1])
            elif isle == 'fiesta':                           # bombo 1 · 3 · 3y, palmas en 2 y 4, pandereta en semicorcheas
                if st in (0, 8, 10): hit(kick, TN.KICK, t, 0.85 if st != 10 else 0.6)
                if st in (4, 12): NZ['snare'].hit(t, 3, [12, 7, 3, 1]); hit(sn, TN.SNARE_BODY, t, 0.5)
                else: NZ['hat'].hit(t, 0, [4, 2, 1] if st % 4 == 2 else [2, 1])
            elif isle == 'volcan':                           # doble bombo (1, 2y-y, 3, 4y-y), caja en 2 y 4
                if st in (0, 6, 7, 8, 14, 15): hit(kick, TN.KICK, t, 0.95 if st in (0, 8) else 0.8)
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.9)
                elif st % 2 == 0: NZ['hat'].hit(t, 0, HAT)
            elif isle == 'lava':                             # galope: ta-ta-tan en el bombo, caja en 2 y 4
                if st in (0, 1, 2, 8, 9, 10): hit(kick, TN.KICK, t, 0.95 if st % 8 == 2 or st % 8 == 0 else 0.75)
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.9)
                elif st % 2 == 0: NZ['hat'].hit(t, 0, HAT)
                elif st in (6, 7, 14, 15): NZ['hat'].hit(t, 0, [3, 1])
            elif isle == 'cueva':                            # medio tiempo: bombo hondo en 1 y 3y, un chasquido en el 3; sin platos
                if st in (0, 10): hit(kick, TN.KICK_DEEP, t, 0.9 if st == 0 else 0.6)
                if st == 8: NZ['snare'].hit(t, 3, [8, 4, 1], short=1)
            elif isle == 'sumergida':                        # casi nada: un bombo hondo y una escobilla
                if st == 0: hit(kick, TN.KICK_DEEP, t, 0.8)
                if st == 8: NZ['snare'].hit(t, 6, [4, 2, 1])
            elif isle == 'nieve':                            # suave: bombo en 1 · 2y · 3, escobilla en 2 y 4, cascabeles
                if st in (0, 6, 8): hit(kick, TN.KICK, t, 0.7)
                if st in (4, 12): NZ['snare'].hit(t, 6, [7, 3, 1])
                else: NZ['hat'].hit(t, 0, [5, 3, 1] if st % 2 == 0 else [2, 1])
            elif isle == 'ventisca':                         # tensa: bombo 1 · 2y · 3 · 4y, caja en 2 y 4, viento en semicorcheas
                if st in (0, 6, 8, 14): hit(kick, TN.KICK, t, 0.9)
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.7)
                else: NZ['hat'].hit(t, 0, [4, 2, 1] if st % 2 == 0 else [3, 1])
            elif isle == 'bola':                             # jefe: bombo a negras + 4y, caja fuerte en 2 y 4, cascabeles
                if st % 4 == 0 or st == 14: hit(kick, TN.KICK, t, 0.95)
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.9)
                else: NZ['hat'].hit(t, 0, [5, 3, 1] if st % 2 == 0 else [3, 1])
            elif isle == 'rey':                              # marcha real: bombo en 1 y 3, caja militar (2 y 4 con su redoble), timbal en el 1
                if st in (0, 8): hit(kick, TN.KICK, t, 0.95)
                if st == 0: hit(tom, TOMS[2], t, 0.7)
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.9)
                elif st in (2, 3, 10, 11) or (st in (6, 7, 14, 15) and b % 2 == 0): NZ['snare'].hit(t, 4, [7, 3, 1]); hit(sn, TN.SNARE_BODY, t, 0.3)
                elif st % 4 == 2 or st % 4 == 0: NZ['hat'].hit(t, 0, [3, 1])
            elif isle == 'nave':                             # persecución: bombo a negras + 4y, caja en 2 y 4, máquina metálica
                if st % 4 == 0 or st == 14: hit(kick, TN.KICK, t, 0.95)
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.9)
                else: NZ['hat'].hit(t, 2, [5, 2] if st % 2 == 0 else [4, 1], short=1)
            elif isle == 'fortaleza':                        # marcha: bombo en 1 y 3, caja en 2 y 4 con su ta-ta, metal a contratiempo
                if st in (0, 8): hit(kick, TN.KICK, t, 0.9)
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.75)
                elif st in (6, 7, 14, 15) or (in_b and st in (2, 10)): NZ['snare'].hit(t, 4, [7, 3, 1]); hit(sn, TN.SNARE_BODY, t, 0.3)
                elif st in (2, 10): NZ['hat'].hit(t, 3, [6, 3, 1], short=1)
                elif st % 2 == 0: NZ['hat'].hit(t, 0, HAT)
            elif isle == 'maquina':                          # la máquina: semicorcheas metálicas con acento, bombo 1 · 3 · 3y, caja en 2 y 4
                if st in (0, 8, 10): hit(kick, TN.KICK, t, 0.85 if st != 10 else 0.6)
                if st in (4, 12): NZ['snare'].hit(t, 5, [11, 6, 2]); hit(sn, TN.SNARE_BODY, t, 0.5)
                else: NZ['hat'].hit(t, 2, [5, 2] if st % 4 == 0 else ([4, 1] if st % 2 else [2, 1]), short=1)
            elif isle == 'costa':                            # calipso: bombo 1 · 2y · 3 · 4y, aro en 2 y 4, maraca en semicorcheas
                if st in (0, 6, 8, 14): hit(kick, TN.KICK, t, 0.8 if st % 8 == 0 else 0.6)
                if st in (4, 12): NZ['snare'].hit(t, 5, [10, 5, 2]); hit(sn, TN.SNARE_BODY, t, 0.4)
                NZ['hat'].hit(t, 1, [4, 2, 1] if st % 2 == 0 else [3, 1], short=0)
            elif isle == 'arrecife':                         # bossa: bombo suave en 1 y 3, clave en el aro, maraca en corcheas
                if st in (0, 8): hit(kick, TN.KICK, t, 0.6)
                if st in (0, 3, 6, 10, 13) and not in_b or (in_b and st in (4, 12)): NZ['snare'].hit(t, 7, [6, 3, 1])
                if st % 2 == 0: NZ['hat'].hit(t, 1, [3, 1])
            else:
                if galop:
                    if st in (0, 8) or st in (3, 11): hit(kick, TN.KICK, t, 0.85 if st % 8 == 0 else 0.55)   # galope: tan-ta
                elif st in (0, 6, 8) or (drive and st == 14): hit(kick, TN.KICK, t, 0.8 if st else 0.9)      # 3+3+2
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.55 + 0.2 * drive)
                if st % 2 == 0: NZ['hat'].hit(t, 0, HAT)
                elif drive: NZ['hat'].hit(t, 0, [3, 1])
            if st == 0 and b in starts and isle != 'arrecife' and (isle not in CAVE or drive == 2): NZ['crash'].hit(t, 3, CRASH)
            if boss and not intro:                           # jefe: platillo cada 2 compases y redoble de caja cada 4
                if st == 0 and b % 2 == 1 and b not in starts: NZ['crash'].hit(t, 3, CRASH[2:])
                if b % 4 == 0 and st >= 8 and (b + 1) not in starts: NZ['snare'].hit(t, 4, [8 + (st - 8) // 2, 4, 2]); hit(sn, TN.SNARE_BODY, t, 0.5 + (st - 8) * 0.05)
            # redoble de entrada: el último medio compás antes de cada frase
            if (b + 1) in starts and st >= 12 and isle != 'arrecife' and (isle not in CAVE or drive == 2): NZ['snare'].hit(t, 4, [9, 5, 2])

    n = int(NB * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k: cut(F.pulse_dac(F.render_pulse(Cn[k])))
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    S = {
        'lead': cut(F.render_wave(Cn['lead'], WAVES) * 0.0075) if (flute and isle == 'pradera') or isle in ('costa', 'sumergida', 'volcan')
                else cut(F.pulse_dac(F.render_saw(Cn['lead']))) if isle in ('fortaleza', 'nave') else pulse('lead'),
        'dbl': pulse('dbl'), 'bell': cut(F.render_wave(Cn['bell'], WAVES) * 0.0075),
        'echo': pulse('echo'), 'chords': pulse('c1') + pulse('c2'),
        'bass': cut(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)), 'trill': pulse('trill') + cut(F.tnd_dac(NZ['fx'].render() / 22638.0 * 12)),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + cut(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
        'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12)), 'crash': cut(F.tnd_dac(NZ['crash'].render() / 22638.0 * 12)),
    }
    n_i = int(INTRO * BAR * SR)                 # la INTRO suena una vez (su propio archivo); el bucle empieza aquí
    S = {k: GN.fold(v, n, n_i) for k, v in S.items() if np.abs(v).max() > 0}
    if isle == 'cueva': S['bell'] = GN.delay(S['bell'], 3 * S16, 0.45, 3, 2600)[:len(S['bell'])]        # el eco de la cueva
    if isle == 'sumergida': S['lead'] = GN.delay(S['lead'], 3 * S16, 0.35, 3, 2200)[:len(S['lead'])]
    LV = ISLE_LV.get(isle) or {'lead': 0, 'echo': -11, 'chords': -6, 'bass': -2, 'trill': -11, 'kick': -2 + drive, 'snare': -5 + drive, 'hat': -12, 'crash': -11, 'toms': 2}
    LV = dict(LV); LV['kick'] = LV['kick'] + (drive if isle != 'pradera' else 0); LV['snare'] = LV['snare'] + (drive if isle != 'pradera' else 0)
    # EL ACOMPAÑAMIENTO, MÁS ARRIBA (el usuario, tras jugar: "en el juego las melodías suenan mucho más fuertes que
    # el resto, sobre todo el bajo; canciones equilibradas al oírlas sueltas quedan vacías"). En el juego la música
    # va más baja y entre efectos de sonido: lo primero que se pierde es lo grave y lo que acompaña, y queda la
    # melodía sola. Las mezclas tenían la melodía en el 25-35 % de la energía; la regla de la casa era 10-15 %.
    # Todo lo que no es melodía sube BACKING dB respecto a ella (el acento del sitio, la mitad).
    for k_ in LV:
        if k_ in BACKING_KEYS: LV[k_] = LV[k_] + BACKING
        elif k_ == 'trill': LV[k_] = LV[k_] + BACKING / 2
    g = GN.level(S, {k: LV[k] for k in S}, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    sd_ = lambda k, w: S[k] * g[k] * w if k in S else 0.0
    side = sd_('chords', 0.35) - sd_('echo', 0.6) + sd_('trill', 0.4) + sd_('hat', 0.3) + sd_('bell', 0.25)
    y = F.master(np.stack([x + side, x - side], 1), lufs=lufs)
    if STEMS_TO:
        # CAPAS por separado (para que el usuario señale cuál es cuál): cada una con la MISMA ganancia, muestra a
        # muestra, que el masterizado le dio a la mezcla → sumadas dan exactamente la pista
        hp = lambda v: sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), v)
        SIDE = {'chords': 0.35, 'echo': -0.6, 'trill': 0.4, 'hat': 0.3, 'bell': 0.25}
        st2 = {k: np.stack([hp(S[k] * g[k]) + S[k] * g[k] * SIDE.get(k, 0), hp(S[k] * g[k]) - S[k] * g[k] * SIDE.get(k, 0)], 1) for k in S}
        pre = sum(st2.values())
        ok = np.abs(pre) > 1e-4
        ratio = np.where(ok, y / np.where(ok, pre, 1), np.median((y / np.where(ok, pre, 1))[ok]))
        os.makedirs(STEMS_TO, exist_ok=True)
        tot = np.zeros_like(y)
        for i_, (k, lab) in enumerate(STEM_NAMES):
            if k not in st2: continue
            F.write_wav(os.path.join(STEMS_TO, '%02d_%s.wav' % (i_ + 1, lab)), st2[k] * ratio); tot += st2[k] * ratio
        drums = sum(st2[k] for k in ('kick', 'snare', 'hat', 'crash', 'toms') if k in st2) * ratio
        F.write_wav(os.path.join(STEMS_TO, '20_bateria_completa.wav'), drums)
        F.write_wav(os.path.join(STEMS_TO, '00_todo_junto.wav'), y)
        print('  capas en %s · suma de capas vs pista: diferencia máxima %.5f' % (STEMS_TO, np.abs(tot - y).max()))
    GN.report(name, y, S, g, n)
    off = np.mean([st % 4 != 0 for b, st, nn, d in mel])
    print(f'  {bpm} BPM, {NB} compases ({NB * BAR:.1f} s); melodía: {len(mel)} notas, {100 * off:.0f} % fuera del tiempo, '
          f'ámbito {min(m[2] for m in mel)}-{max(m[2] for m in mel)}')
    return y, mel, bpm, n_i


def write_mid(path, mel, bpm):
    import mido
    mid = mido.MidiFile(ticks_per_beat=480)
    tr = mido.MidiTrack(); mid.tracks.append(tr)
    tr.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / bpm), time=0))
    ev = []
    for b, st, n, d in mel:
        t0 = ((b - 1) * 16 + st) * 120
        ev += [(t0, 'note_on', n), (t0 + d * 120 - 10, 'note_off', n)]
    t = 0
    for tt, kind, n in sorted(ev):
        tr.append(mido.Message(kind, note=n, velocity=96, time=tt - t)); t = tt
    mid.save(path)


TRACKS = {
    'pradera_1':     dict(variant='A', bpm=136),
    'pradera_2':     dict(theme='galope', bpm=144, flute=True),
    'pradera_bonus': dict(variant='A', bpm=152, drive=2, lufs=-11.0, solo=True),
    'costa_1':       dict(theme='calipso', isle='costa', bpm=122),
    'costa_2':       dict(theme='arrecife', isle='arrecife', bpm=108, lufs=-12.5),
    'fortaleza_1':     dict(theme='marcha', isle='fortaleza', bpm=140),
    'fortaleza_2':     dict(theme='engranajes', isle='maquina', bpm=126),
    'fortaleza_bonus': dict(theme='marcha', isle='fortaleza', bpm=156, drive=2, lufs=-11.0, solo=True),
    'victory':       dict(theme='victoria', isle='fiesta', bpm=132, lufs=-12.0),
    'volcan_1':      dict(theme='ceniza', isle='volcan', bpm=164, lufs=-11.0),
    'volcan_2':      dict(theme='fuego', isle='lava', bpm=172, lufs=-11.0),
    'volcan_bonus':  dict(theme='ceniza', isle='volcan', bpm=178, drive=2, lufs=-10.5, solo=True),
    'cuevas_1':      dict(theme='ecos', isle='cueva', bpm=104, lufs=-12.0),
    'cuevas_2':      dict(theme='laberinto', isle='sumergida', bpm=92, lufs=-12.5),
    'cuevas_bonus':  dict(theme='ecos', isle='cueva', bpm=132, drive=2, lufs=-11.0, solo=True),
    'nieve_1':       dict(theme='cumbres', isle='nieve', bpm=148),
    'nieve_2':       dict(theme='ventisca', isle='ventisca', bpm=156),
    'nieve_bonus':   dict(theme='cumbres', isle='nieve', bpm=166, drive=2, lufs=-11.0, solo=True),
    'snowball_boss': dict(theme='bola', isle='bola', bpm=168, boss=True, lufs=-10.5),
    'gummy_king_boss': dict(theme='majestad', isle='rey', bpm=148, boss=True, lufs=-10.5),
    'evil_ship_boss':  dict(theme='persecucion', isle='nave', bpm=160, boss=True, lufs=-10.5),
    'costa_bonus':   dict(theme='calipso', isle='costa', bpm=138, drive=2, lufs=-11.0, solo=True),
}
VARIANTS = {'A': dict(variant='A', bpm=136), 'B': dict(variant='B', bpm=132), 'C': dict(variant='C', bpm=140)}

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    var = sys.argv[sys.argv.index('--variante') + 1] if '--variante' in sys.argv else None
    for a in args:
        if a == 'previas':
            out = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'musica')
            os.makedirs(out, exist_ok=True)
            for v, kw in VARIANTS.items():
                y, mel, bpm, _ = build('pradera_1 variante ' + v, **kw)
                wav = os.path.join(out, 'pradera_1_%s.wav' % v)
                F.write_wav(wav, y)
                os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{wav[:-4]}.ogg"'); os.remove(wav)
                print('  ' + wav[:-4] + '.ogg')
            continue
        kw = dict(TRACKS[a])
        if var and a == 'pradera_1': kw = dict(VARIANTS[var])
        if '--capas' in sys.argv:                  # capas por separado (no exporta la pista): FlappyMonster_pruebas/musica/<pista>_capas/
            STEMS_TO = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'musica', a + '_capas')
            build(a, **kw)
            continue
        y, mel, bpm, n_i = build(a, **kw)
        if not os.environ.get('REPORT'):
            GN.export(a, y, n_i)
            write_mid(F.out(a, 'mid'), mel, bpm)
