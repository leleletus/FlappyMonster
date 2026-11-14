"""Cae por el equipo — melodías v3 (propias, desde cero). Las usa cae_equipo.py:
    python tools/music/cae_equipo.py --melodia cae_equipo_melodias [--informe]

LA IDEA: un solo gesto de dos compases, "el traspié" — un bordado hacia abajo (la nota, la de debajo, la nota) que
toma impulso y SALTA por terceras hasta una nota larga a contratiempo (ritmo 2+2+3+3+6: "ta-ta ta- ta- taaa");
el compás que contesta CAE por grados, como un muñeco que se tropieza y rueda. Cada sección lo usa a su manera:
  · tema A (groove sobre Si♭7): el traspié en miniatura, picado y con huecos, con la 7ª menor (La♭) — travieso.
  · puente (campana FM, contramelodía de los cortes de voz): ritmo largo-corto-largo (6+2+8) que baja por las
    notas guía de los acordes (7ª → 3ª); solo tiene movimiento donde los cortes callan.
  · gancho (estribillo): el traspié completo, entero y cantable; pregunta (c1-4) y respuesta (c5-8) con el Do7
    brillante (Mi natural) en c6 y la bajada cromática La♭ – Sol m – Re7/Fa# llevando de vuelta al Sol.
  · tema C: lo contrario — notas repetidas en 3+3+2 que "corren" (la carrera) en registro medio, y el compás
    siguiente responde con una nota larga; la segunda mitad (Sol m) se abre hacia arriba.
La llamada (Fa–Si♭–Re–Fa) suena una vez, en el último estribillo (c126, sobre Si♭), justo antes del cierre.
"""
from cae_equipo import frases

SUFIJO = 'v3'

# ── TEMA A (c43-50 y c139-146): el traspié en miniatura, sobre Si♭7 ──────────────────────────────
TEMA_A = ['0:F5/2 2:Eb5/1 3:F5/3 6:Ab5/2 8:G5/1 9:F5/3 12:D5/4',        # bordado y salto a la 7ª, cae
          '2:F5/2 4:Bb5/2 6:C6/1 7:Bb5/3 10:Ab5/2 12:F5/4',
          '0:Bb5/2 2:Ab5/1 3:Bb5/3 6:D6/2 8:C6/1 9:Bb5/3 12:F5/4',       # lo mismo, una cuarta arriba
          '2:Ab5/2 4:F5/2 6:D5/2 8:F5/8',
          '0:F5/2 2:Eb5/1 3:F5/3 6:Ab5/2 8:G5/1 9:F5/3 12:D5/4',
          '2:F5/2 4:Bb5/2 6:C6/1 7:D6/3 10:C6/2 12:Bb5/4',
          '0:D6/2 2:Db6/1 3:D6/3 6:F6/2 8:Eb6/1 9:D6/3 12:Bb5/4',        # arriba del todo; Re♭ = la nota azul
          '0:Ab5/2 2:F5/2 4:D5/2 6:Eb5/3 9:C5/3 12:D5/2 14:F5/2']        # la vuelta La♭ – Sol m – Fa sus
TEMA_A_SALIDA = TEMA_A[:7] + ['0:Bb5/2']                                 # c146: el efecto desde la semicorchea 2

# ── PUENTE (c19-32): la campana, notas guía en 6+2+8 ─────────────────────────────────────────────
PUENTE = ['0:Bb5/6 6:C6/2 8:D6/8',                    # Mi♭maj7
          '0:Eb6/6 6:D6/2 8:C6/8',                    # Mi♭maj7 | Re m7
          '0:Bb5/6 6:A5/2 8:G5/4 12:Bb5/4',          # Sol m7
          '0:A5/8 8:Bb5/8',                           # Fa/La | Si♭
          '0:G5/6 6:Bb5/2 8:Eb6/8',                   # Do m7
          '0:C6/6 6:A5/2 8:Bb5/8',                    # Fa7 | Mi♭/Sol
          '0:F5/4 4:Bb5/4 8:D6/8',                    # Si♭/Re
          '0:Eb6/6 6:D6/2 8:C6/8',                    # Do m7 | Re m7
          '0:Bb5/6 6:C6/2 8:D6/4 12:Eb6/2 14:D6/2',   # Mi♭maj7
          '0:C6/6 6:A5/2 8:F5/8',                     # Re m7
          '0:G5/6 6:Bb5/2 8:A5/8',                    # Sol m7 | Fa/La
          '0:A5/4 4:Bb5/4 8:D6/8',                    # Si♭maj7
          '0:Eb6/6 6:D6/2 8:C6/4 12:Bb5/2 14:C6/2',   # Do m7
          '0:C6/8 8:A5/8']                            # Fa7sus4 | Fa7

# ── GANCHO (estribillo): el traspié entero ───────────────────────────────────────────────────────
G1 = '0:G5/2 2:F5/2 4:G5/3 7:Bb5/3 10:D6/6'            # Mi♭maj7: bordado, salto por terceras, Re largo
G2 = '0:C6/2 2:Bb5/2 4:A5/3 7:F5/3 10:G5/2 12:A5/4'    # Fa: cae por grados
G3 = '0:Bb5/2 2:C6/2 4:Bb5/3 7:D6/3 10:F6/6'           # Sol m7: el traspié una tercera arriba, el bordado ahora por arriba
G4 = '0:D6/3 3:C6/1 4:Bb5/1 5:A5/1 6:Bb5/2 8:F5/6'     # Si♭: la voltereta (rueda en semicorcheas)
G6 = '0:C6/2 2:Bb5/2 4:G5/3 7:E5/4 11:F5/1 12:G5/4'    # Do7: el Mi natural, brillante
G7 = '0:D6/3 3:Bb5/3 6:G5/2 8:Bb5/2 10:A5/2 12:G5/4'   # Sol m7
G8 = '0:Bb5/3 3:C6/5 8:D6/2 10:Bb5/2 12:A5/2 14:F#5/2'  # Do m7/Si♭ – La♭ – Sol m7 – Re7/Fa#: la sensible al Sol
GANCHO = [G1, G2, G3, G4, G1, G6, G7, G8]
G8B = '0:Bb5/4 4:C6/4 8:D6/2 10:Bb5/2 12:A5/2 14:F#5/2'  # c114: a tiempo (la 2ª voz automática toma el acorde del ataque)
# variante para c107-114 (lleva la 2ª voz a una tercera): respuestas más altas y cantadas
GANCHO_B = [G1,
            '0:C6/3 3:A5/3 6:C6/2 8:F6/4 12:C6/4',
            G3,
            '0:D6/6 6:C6/2 8:Bb5/4 12:F5/4',
            G1,
            '0:E6/3 3:C6/3 6:Bb5/2 8:G5/4 12:Bb5/4',
            G7, G8B]
FIN1 = [G1, G2, G3, G4,
        '0:G5/2 2:F5/2 4:G5/3 7:Bb5/3 10:Eb6/6',         # Mi♭maj7: el traspié sube hasta la tónica del acorde
        '0:Bb5/4 4:A5/6']                                # Fa sus4 → Fa: el retardo resuelve; respira antes de los golpes
FIN2 = [G1, G2, G3,
        '0:F5/2 2:Bb5/2 4:D6/2 6:F6/10',                 # LA LLAMADA (5-1-3-5) sobre Si♭
        '0:Eb6/3 3:D6/3 6:Bb5/2 8:G5/4 12:Bb5/4',        # Mi♭maj7
        '0:C6/4 4:Bb5/4 8:A5/6']                         # Fa sus4 | Fa

# ── TEMA C (c67-98): la carrera — notas repetidas en 3+3+2 y una larga que contesta ───────────────
TEMA_C = ['0:D5/3 3:D5/3 6:Eb5/2 8:F5/3 11:Bb5/5',              # Si♭
          '0:A5/3 3:A5/3 6:G5/2 8:F5/8',                        # Re m7
          '0:Eb5/3 3:Eb5/3 6:F5/2 8:G5/3 11:Bb5/5',             # Mi♭maj7
          '0:C6/3 3:C6/3 6:Bb5/2 8:A5/8',                       # Fa
          '0:D5/3 3:D5/3 6:Eb5/2 8:F5/3 11:D6/5',               # Si♭ (el salto, más grande)
          '0:C6/3 3:C6/3 6:Bb5/2 8:A5/4 12:F5/4',               # Re m7
          '0:G5/3 3:Bb5/3 6:C6/2 8:D6/6 14:C6/2',               # Mi♭maj7
          '0:C6/3 3:A5/5 8:A5/3 11:F#5/5',                      # Fa | Re7/Fa#
          '0:G5/3 3:G5/3 6:A5/2 8:Bb5/6 14:A5/2',               # Sol m
          '0:A5/3 3:F5/5 8:Eb5/3 11:F5/5',                      # Fa | Fa7/Mi♭
          '0:G5/3 3:G5/3 6:F5/2 8:Eb5/3 11:G5/5',               # Mi♭maj7
          '0:F#5/3 3:A5/3 6:C6/2 8:D6/8',                       # Re7/Fa#
          '0:D6/3 3:D6/3 6:C6/2 8:Bb5/6 14:A5/2',               # Sol m
          '0:A5/3 3:C6/5 8:Eb6/3 11:C6/5',                      # Fa | Fa7/Mi♭
          '0:Bb5/3 3:G5/3 6:F5/2 8:G5/8',                       # Mi♭maj7
          '0:Bb5/4 4:A5/4 8:F5/3 11:C5/5']                      # Fa sus4 | Fa
TEMA_C2_FIN = ['0:Eb6/3 3:C6/3 6:Bb5/2 8:G5/8',                # Do m7
               '0:A5/3 3:F5/3 6:D5/2 8:F5/4']                  # Re m7: respira antes del estribillo


def melodias():
    M = {}
    M['tema_a'] = frases(TEMA_A, 43) + [(p, d, m, 82) for p, d, m, v in frases(TEMA_A_SALIDA, 139)]
    M['puente'] = frases(PUENTE, 19)
    M['gancho'] = (frases(GANCHO + FIN1, 51) + frases(GANCHO, 99) + frases(GANCHO_B, 107) +
                   frases(GANCHO, 115) + frases(FIN2, 123))
    M['tema_c'] = frases(TEMA_C, 67) + frases(TEMA_C[:14] + TEMA_C2_FIN, 83)
    return M
