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
from famicom import SR, Chan, Noise, play, wavetable, q_n163, q_tri, q_pulse
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


def song(variant, minor=False, solo=False, theme=None):
    """→ melodía [(compás, semicorchea, nota, dur)], acordes [(1ª mitad, 2ª mitad)] por compás, etiqueta de cada
    compás ('intro' | 'A' | 'B' | 'solo') y los compases donde EMPIEZA una frase"""
    global SCALE
    SCALE = {'galope': SCALE_C, 'calipso': SCALE_F, 'arrecife': SCALE_Bb}.get(theme, SCALE_G)
    if theme == 'calipso': pa, e1, e2, pb, ca, cb, tonic = K_A, K_END, K_END2, K_B, KCH_A, KCH_B, (Fr, MAJ)
    elif theme == 'arrecife': pa, e1, e2, pb, ca, cb, tonic = R_A, R_END, R_END2, R_B, RCH_A, RCH_B, (Bbr, MAJ)
    elif theme == 'galope': pa, e1, e2, pb, ca, cb, tonic = P_A, P_END, P_END2, P_B, PCH_A, PCH_B, (C, MAJ)
    elif minor: pa, e1, e2, pb, ca, cb, tonic = M_A, M_END, M_END2, M_B, MCH_A, MCH_B, (E, MIN)
    elif variant == 'B': pa, e1, e2, pb, ca, cb, tonic = A_SONG, A_SONG_END, A_SONG_END2, PH_B, GCH_A, GCH_B, (G, MAJ)
    else: pa, e1, e2, pb, ca, cb, tonic = A_HOP, A_HOP_END, A_HOP_END2, PH_B, GCH_A, GCH_B, (G, MAJ)
    mel, ch, tag, starts = [], [], [], []
    def section(kind, ph, chords):
        base = len(ch)
        starts.append(base + 1)
        for b, st, n, d in ph: mel.append((base + b, st, n, d))
        for c in chords:
            ch.append(c if isinstance(c[0], tuple) else (c, c))
            tag.append(kind)
    section('intro', [], [tonic] * INTRO)
    section('A', pa + e1, ca)
    section('A', pa + e2, ca)
    section('B', pb, cb)
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
ISLE_LV = {
    'costa':    {'lead': 0, 'echo': -10, 'chords': -8, 'bass': -2, 'trill': -5, 'kick': -4, 'snare': -8, 'hat': -11, 'crash': -12, 'toms': 2},
    'arrecife': {'lead': 0, 'echo': -9, 'chords': -7, 'bass': -3, 'trill': -3, 'kick': -7, 'snare': -13, 'hat': -15, 'crash': -14, 'toms': 0},
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


def build(name, variant='A', bpm=136, minor=False, drive=0, lufs=-11.5, solo=False, theme=None, flute=None, isle='pradera'):
    """isle: el arreglo ('pradera' | 'costa' = calipso | 'arrecife' = bossa de agua). drive: 0 = tema (batería ligera) · 1 = segunda cara (más empuje) · 2 = bonus (competición)"""
    S16 = 60.0 / bpm / 4
    BAR = 16 * S16
    mel, ch, tag, starts = song(variant, minor, solo, theme)
    NB = len(ch)
    NF = F.frames_for(NB * BAR + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'echo', 'c1', 'c2', 'bass', 'trill')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash')}
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
        if isle == 'costa': play(Cn['lead'], t0, tv(b, st) + max(d, 3) * S16, n, dict(I_STEEL, duty=2.0), q=q_n163, release=4)
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
            solo_bar(b - starts[3] + 1 if len(starts) > 3 else 1, lambda st: tv(b, st), kick, sn, tom, NZ, hit)
            continue
        for half in (0, 1):
            r, q = ch[b - 1][half]
            root = 36 + (r - 36) % 12
            notes = [60 + (r - 60) % 12 + iv for iv in q]
            s0 = half * 8
            # BAJO saltarín: 1-5-8-5 en corcheas (en la intro entra en el compás 3; en B, negras)
            if not intro or b >= 3:
                pat = ((0, 0, 3.4), (4, 12, 3.4)) if in_b else ((0, 0, 1.7), (2, 7, 1.7), (4, 12, 1.7), (6, 7, 1.7))
                if drive: pat = ((0, 0, 1.6), (2, 12, 1.6), (4, 0, 1.6), (6, 7, 1.6))
                if galop and not in_b: pat = ((0, 0, 2.6), (3, 0, 0.9), (4, 7, 2.6), (7, 7, 0.9))     # (tan-ta tan-ta)
                if isle == 'costa' and drive < 2: pat = ((0, 0, 2.7), (3, 7, 0.9), (4, 12, 3.3))             # calipso: 1, 1y, 3
                if isle == 'arrecife': pat = ((0, 0, 5.4), (6, 7, 1.8))                                    # bossa: largo y la quinta
                for st, iv, ln in pat:
                    play(Cn['bass'], tv(b, s0 + st), tv(b, s0 + st) + ln * S16, root + iv, I_TRI, q=q_tri, release=0)
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
        if (intro and b % 2 == 0) or (long_tail and not in_b):
            r, q = ch[b - 1][1]
            top = 84 + (r - 84) % 12 + q[2] - 12
            up = 2 if (top + 2) % 12 in SCALE else 1          # (la nota de al lado, DE LA ESCALA: +2 sobre Si daba Do#)
            if isle == 'costa':                               # el motivo de la costa: la marimba SUBE por el acorde
                base_ = 72 + (r - 72) % 12
                for i, st in enumerate((10, 11, 12, 13, 14)):
                    play(Cn['trill'], tv(b, st), tv(b, st) + S16 * 1.2, base_ + (q + (12,) + (12 + q[1],))[i], I_MARIMBA, vs=1.2, release=1)
            elif isle == 'arrecife':                          # burbujas: tres notitas del acorde que suben
                base_ = 84 + (r - 84) % 12
                for i, st in enumerate((9, 12, 14)):
                    play(Cn['trill'], tv(b, st), tv(b, st) + 0.07, base_ + q[i], GN.I_DRIP, release=0)
            else:
                for i, st in enumerate(range(10, 16)):
                    play(Cn['trill'], tv(b, st), tv(b, st) + S16 * 0.9, top + (up if i % 2 else 0), I_TRILL, release=0)
        # BATERÍA
        for st in range(16):
            t = tv(b, st)
            if intro and b < 3:
                if st % 4 == 2: NZ['hat'].hit(t, 0, HAT)
                continue
            if drive == 2:                                   # competición: bombo a negras, caja en 2 y 4, platos en semicorcheas
                if st % 4 == 0: hit(kick, TN.KICK, t, 0.95)
                if st in (4, 12): NZ['snare'].hit(t, 4, SNARE_N); hit(sn, TN.SNARE_BODY, t, 0.8)
                NZ['hat'].hit(t, 0, HAT if st % 2 == 0 else [3, 1])
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
            if st == 0 and b in starts and isle != 'arrecife': NZ['crash'].hit(t, 3, CRASH)
            # redoble de entrada: el último medio compás antes de cada frase
            if (b + 1) in starts and st >= 12 and isle != 'arrecife': NZ['snare'].hit(t, 4, [9, 5, 2])

    n = int(NB * BAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    pulse = lambda k: cut(F.pulse_dac(F.render_pulse(Cn[k])))
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    S = {
        'lead': cut(F.render_wave(Cn['lead'], WAVES) * 0.0075) if (flute and isle == 'pradera') or isle == 'costa' else pulse('lead'),
        'echo': pulse('echo'), 'chords': pulse('c1') + pulse('c2'),
        'bass': cut(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)), 'trill': pulse('trill'),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0) - base), 'toms': cut(F.tnd_dac((tom + 64) / 22638.0) - base),
        'snare': cut(F.tnd_dac((sn + 64) / 22638.0) - base) + cut(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
        'hat': cut(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12)), 'crash': cut(F.tnd_dac(NZ['crash'].render() / 22638.0 * 12)),
    }
    S = {k: GN.fold(v, n) for k, v in S.items() if np.abs(v).max() > 0}
    LV = ISLE_LV.get(isle) or {'lead': 0, 'echo': -11, 'chords': -6, 'bass': -2, 'trill': -6, 'kick': -2 + drive, 'snare': -5 + drive, 'hat': -12, 'crash': -11, 'toms': 2}
    LV = dict(LV); LV['kick'] = LV['kick'] + (drive if isle != 'pradera' else 0); LV['snare'] = LV['snare'] + (drive if isle != 'pradera' else 0)
    g = GN.level(S, {k: LV[k] for k in S}, 'lead')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    side = S['chords'] * g['chords'] * 0.35 - S['echo'] * g['echo'] * 0.6 + S['trill'] * g['trill'] * 0.4 + S['hat'] * g['hat'] * 0.3
    y = F.master(np.stack([x + side, x - side], 1), lufs=lufs)
    GN.report(name, y, S, g, n)
    off = np.mean([st % 4 != 0 for b, st, nn, d in mel])
    print(f'  {bpm} BPM, {NB} compases ({NB * BAR:.1f} s); melodía: {len(mel)} notas, {100 * off:.0f} % fuera del tiempo, '
          f'ámbito {min(m[2] for m in mel)}-{max(m[2] for m in mel)}')
    return y, mel, bpm


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
                y, mel, bpm = build('pradera_1 variante ' + v, **kw)
                wav = os.path.join(out, 'pradera_1_%s.wav' % v)
                F.write_wav(wav, y)
                os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{wav[:-4]}.ogg"'); os.remove(wav)
                print('  ' + wav[:-4] + '.ogg')
            continue
        kw = dict(TRACKS[a])
        if var and a == 'pradera_1': kw = dict(VARIANTS[var])
        y, mel, bpm = build(a, **kw)
        if not os.environ.get('REPORT'):
            GN.export(a, y)
            write_mid(F.out(a, 'mid'), mel, bpm)
