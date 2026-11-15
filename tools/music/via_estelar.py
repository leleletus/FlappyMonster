#!/usr/bin/env python3
# tools/music/via_estelar.py — la música del nivel especial VÍA ESTELAR / Starway (`via_estelar`): un camino de bloques
# de cristal por encima de las nubes; los bloques rosa y cian se cambian cada 4 s, a tiempo con la música (bloques Beep,
# docs/design/beep-blocks.md). PREVIAS para que el usuario elija: no toca assets/ ni el index.json.
#
# Lo que pidió el usuario: una melodía ORDENADA, PREVISIBLE y CONSONANTE. Por eso, a propósito, este tema NO sigue
# algunas costumbres de la casa (música-guía § 1 y § 4): nada de 3+3+2, ni mayoría de notas a contratiempo, ni giro
# oscuro, ni acentos que contestan. Re mayor, solo acordes de la tonalidad, ciclos de 4 acordes que se repiten, frases
# de 2 compases (pregunta / respuesta) que se repiten en bloques de 4 y de 8 compases; pocas voces con papeles claros:
# melodía, bajo de triángulo, un arpegio (o colchón en C) y batería recta.
#
# CONTRATO DE TIEMPOS (el juego depende de él): 4/4, 120 BPM exactos (tiempo 0,5 s, compás 2 s = 88 200 muestras).
# Frase = 2 compases = 8 tiempos = 4 s. Bucle = 40 compases = 80 s exactos, sin intro: A 1-20 · B 21-36 · C 37-40
# (puente tranquilo, pedal, 3-4 dB más bajo) → vuelta a A.
#   · En cada frase el JUEGO toca 3 pitidos (assets/sounds/mechanics/beep_warn.wav, ~2290 Hz, 70 ms) en los tiempos
#     6, 7 y 8, y los bloques cambian en el tiempo 1 de la frase siguiente. La música: no lleva los pitidos (la versión
#     del juego), les deja sitio (la melodía no ataca en los tiempos 6-8: allí sostiene) y marca un GOLPE en el tiempo 1
#     de cada frase (bombo fuerte + platillo corto), también al volver al principio después de C.
#
# Dos variantes, que se diferencian en la MELODÍA:
#   A "chip"   pulso del 2A03 con barrido de ciclo; motivo "ta-ta TAA, ta-ta TAA | TAAAA" que sube por el acorde
#   B "flauta" flauta GM (GeneralUser GS) sobre el reparto de chip, con una voz de N163 debajo (el color de la casa);
#              motivo "TAAA ta-ta-ta-ta | TAAAA" (nota larga y una ola por grados); en B el glockenspiel GM la dobla
# La armonía, el bajo, el arpegio y la batería son los mismos en las dos.
# Y la variante R "remaster" (2026-11-15, la INSTALADA): el usuario, "buena pero repetitiva y aburrida para un nivel
# largo" → el tema B como sección A y luego subida, estribillo nuevo, corte, subida y clímax un tono arriba; 76
# compases = 152 s. Vive en tools/music/estelar.py (la familia estelar: también Púlsar, el bonus y el jefe); aquí
# `R` solo la llama. La B instalada hasta entonces y la A se pueden volver a generar como siempre (sin instalarse).
#
#   ~/.venvs/fm-music/bin/python tools/music/via_estelar.py [A|B|R ...]   → FlappyMonster_pruebas/musica/via_estelar/
#   REPORT=1 → solo números (no escribe nada)
# Se comprueba con números (tools/music/bloques_beep_check.py); NO se ha escuchado.
import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import famicom as F
from famicom import SR, Chan, Noise, play, q_n163, q_tri, q_vrc6
import tentacle_nes as TN
import gloomy_nes as GN
import worldmap_nes as W
import montana_nes as MN
import gm as GM

# ══ PARÁMETROS ════════════════════════════════════════════════════════════════════════════════════════════════════
BPM = 120
S16 = 60.0 / BPM / 4                     # 0,125 s
BAR = 16 * S16                           # 2 s
BAR_N = int(round(BAR * SR))             # 88 200 muestras
SECCIONES = [('A', 20), ('B', 16), ('C', 4)]
NB = sum(n for _, n in SECCIONES)        # 40 compases = 80 s
LOOP_N = NB * BAR_N
COPIAS = 3                               # se toca el bucle 3 veces seguidas y se queda la del medio: costura exacta
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica/via_estelar'
ROOT_REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
BEEP_WAV = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'sounds', 'mechanics', 'beep_warn.wav')
BEEP_TIEMPOS = (5, 6, 7)                 # tiempos 6, 7 y 8 de la frase (contando desde 0)
BEEP_GAN = 0.55                          # (solo la previa con pitidos: el juego los toca con su volumen de efectos)
LUFS = -11.5
C_DB = -3.45                             # C respecto a A y B, con los pitidos (el comprobador pide 3-4 dB por debajo)
GM_FLAUTA, GM_GLOCK = 73, 9
# El driver va a 64 Hz: una semicorchea = 8 frames justos (5512,5 muestras), así todas las voces del chip empiezan
# a tiempo con el bombo y el ruido.
F.FRAME_S = S16 * SR / 8
F.FPS = SR / F.FRAME_S

MAJ, MIN, DOM = (0, 4, 7), (0, 3, 7), (0, 4, 7, 10)
PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
ESCALA = {2, 4, 6, 7, 9, 11, 1}          # Re mayor
NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
nm = lambda m: NAMES[m % 12] + str(m // 12 - 1)


def N(s):
    """'F#5' → nota MIDI"""
    alt = {'b': -1, '#': 1}.get(s[1], 0) if len(s) == 3 else 0
    return 12 * (int(s[-1]) + 1) + PC[s[0]] + alt


def acorde(c):
    """'D' / 'Bm' / 'A7' → (clase de la raíz, intervalos)"""
    r = c.rstrip('m7')
    return N(r + '0') % 12, {'m': MIN, '7': DOM, '': MAJ}[c[len(r):]]


# ══ ARMONÍA: un acorde por compás, ciclos de 4 que se repiten ═════════════════════════════════════════════════════
#   A: I IV V I (dos veces) · vi IV ii V (el puente de A) · I IV V I (dos veces)
#   B: vi IV I V (tres veces) y vi IV V V (para ir a C)
#   C: I sobre pedal de Re (estático)
ACORDES = ('D G A7 D  D G A7 D  Bm G Em A7  D G A7 D  D G A7 D '
           'Bm G D A7  Bm G D A7  Bm G D A7  Bm G A7 A7 '
           'D D D D').split()
assert len(ACORDES) == NB


def seccion(b):
    """compás 1..40 → letra de la sección"""
    a = 0
    for s, n in SECCIONES:
        if b <= a + n: return s
        a += n


def chord_at(b): return acorde(ACORDES[(b - 1) % NB])


# ══ MELODÍAS: frases de 2 compases, "semicorchea:nota:duración" por compás ═══════════════════════════════════════
# En el 2.º compás de cada frase (tiempos 5-8) la melodía solo ataca en el tiempo 5 y SOSTIENE: los pitidos del juego
# suenan en los tiempos 6-8 sobre una nota quieta.
def frase(c1, c2): return [c1, c2]


MEL = {}
# ── A "chip": motivo X = corchea, corchea, negra, corchea, corchea, negra | redonda — sube por el acorde ─────────
X = lambda a, b, c, d, e, f: f'0:{a}:2 2:{b}:2 4:{c}:4 8:{d}:2 10:{e}:2 12:{f}:4'
H = lambda n: f'0:{n}:16'                                            # la nota sostenida (tiempos 5-8)
W4 = lambda a, b, c, d, e, f: f'0:{a}:2 2:{b}:2 4:{c}:2 6:{d}:2 8:{e}:4 12:{f}:4'   # (B: escala que sube y se posa)
Q_A = frase(X('A4', 'D5', 'F#5', 'E5', 'F#5', 'A5'), H('B5'))       # pregunta: La Re Fa# (Mi) Fa# La | Si
R1_A = frase(X('A4', 'C#5', 'E5', 'D5', 'E5', 'G5'), H('F#5'))      # respuesta abierta (en secuencia, acaba en Fa#)
R2_A = frase(X('E5', 'F#5', 'G5', 'F#5', 'E5', 'C#5'), H('D5'))     # respuesta cerrada: acaba en Re (la tónica)
P1_A = frase(X('F#5', 'B5', 'D6', 'C#6', 'B5', 'F#5'), H('G5'))     # puente de A: el motivo sobre Si menor…
P2_A = frase(X('E5', 'G5', 'B5', 'A5', 'G5', 'E5'), H('C#5'))       # …y en secuencia una 3.ª abajo, sobre Mi menor
BQ_A = frase(W4('D5', 'C#5', 'B4', 'D5', 'F#5', 'B5'), H('D6'))     # B: una vuelta (Re Do# Si) y sube por el acorde
BR1_A = frase(W4('A5', 'G5', 'F#5', 'D5', 'F#5', 'A5'), H('E5'))    # baja (espejo de la pregunta) y rebota, abierta
BR2_A = frase(W4('A5', 'G5', 'F#5', 'E5', 'F#5', 'A5'), H('C#6'))   # vuelve a subir, abierta y alta
BR3_A = frase(W4('E5', 'F#5', 'G5', 'F#5', 'E5', 'C#5'), H('A4'))   # se posa en La: hacia el puente
# ── B "flauta": motivo P = negra con puntillo y una ola de corcheas | redonda ────────────────────────────────────
P = lambda a, b, c, d, e, f: f'0:{a}:6 6:{b}:2 8:{c}:2 10:{d}:2 12:{e}:2 14:{f}:2'
Z = lambda a, b, c, d, e: f'0:{a}:4 4:{b}:4 8:{c}:2 10:{d}:2 12:{e}:4'
Q_B = frase(P('F#5', 'E5', 'D5', 'F#5', 'A5', 'D6'), H('B5'))       # Faaa mi re, fa la re' | Si
R1_B = frase(P('E5', 'D5', 'C#5', 'E5', 'A5', 'C#6'), H('A5'))      # la misma, un grado abajo: abierta (en La)
R2_B = frase(P('E5', 'D5', 'C#5', 'D5', 'E5', 'C#5'), H('D5'))      # cerrada en Re
P1_B = frase(P('D6', 'C#6', 'B5', 'F#5', 'B5', 'D6'), H('B5'))      # puente de A, sobre Si menor…
P2_B = frase(P('B5', 'A5', 'G5', 'E5', 'G5', 'B5'), H('A5'))        # …y una 3.ª abajo, sobre Mi menor
BQ_B = frase(Z('F#5', 'B5', 'A5', 'B5', 'D6'), H('B5'))             # B: negras que saltan por el acorde
BR1_B = frase(Z('A5', 'F#5', 'E5', 'F#5', 'A5'), H('E5'))
BR2_B = frase(Z('D6', 'A5', 'F#5', 'G5', 'A5'), H('C#6'))
BR3_B = frase(Z('E5', 'A5', 'G5', 'F#5', 'E5'), H('C#5'))
# ── C (las dos): LA LLAMADA en Re (La-Re-Fa#-La, 5.ª-1.ª-3.ª-5.ª) sobre su acorde, una vez, y se posa en Re ─────────
C1 = frase('0:A4:4 4:D5:4 8:F#5:4 12:A5:4', H('A5'))
C2 = frase('0:F#5:6 6:E5:2 8:D5:2 10:E5:2 12:F#5:4', H('D5'))

# Forma: en A, a a' b a a' (pregunta + respuesta abierta · pregunta + respuesta cerrada · el puente · otra vez);
# en B, c c' c c'' (la misma pregunta y tres respuestas); C = la llamada.
FORMA = {
    'A': [('Q', 'R1'), ('Q', 'R2'), ('P1', 'P2'), ('Q', 'R1'), ('Q', 'R2'),
          ('BQ', 'BR1'), ('BQ', 'BR2'), ('BQ', 'BR1'), ('BQ', 'BR3'), ('C1', 'C2')],
}
FORMA['B'] = FORMA['A']
FRASES = {'A': dict(Q=Q_A, R1=R1_A, R2=R2_A, P1=P1_A, P2=P2_A, BQ=BQ_A, BR1=BR1_A, BR2=BR2_A, BR3=BR3_A, C1=C1, C2=C2),
          'B': dict(Q=Q_B, R1=R1_B, R2=R2_B, P1=P1_B, P2=P2_B, BQ=BQ_B, BR1=BR1_B, BR2=BR2_B, BR3=BR3_B, C1=C1, C2=C2)}


def mapa_frases(v):
    """lista de 20 nombres de frase (una por cada 2 compases)"""
    return [n for par in FORMA[v] for n in par]


def melodia(v):
    """(compás 1..40, semicorchea, nota, duración, nombre de frase)"""
    out = []
    for i, nombre in enumerate(mapa_frases(v)):
        for k, txt in enumerate(FRASES[v][nombre]):
            b = 2 * i + k + 1
            for x in txt.split():
                a, n, d = x.split(':')
                out.append((b, int(a), N(n), int(d), nombre))
    return out


# ══ BAJO Y ARPEGIO ═══════════════════════════════════════════════════════════════════════════════════════════════
def raiz_bajo(r): return 38 + (r - 38) % 12                         # Re2..Do#3


def linea_bajo():
    """triángulo en corcheas: A = raíz-octava; B = raíz-octava-5.ª-octava; C = pedal de Re en redondas"""
    out = []
    for b in range(1, NB + 1):
        s = seccion(b)
        r, q = chord_at(b)
        ra = raiz_bajo(r)
        if s == 'C':
            out.append((b, 0, 38, 16))
            continue
        pat = [0, 12] * 4 if s == 'A' else [0, 12, 7, 12] * 2
        out += [(b, 2 * k, ra + iv, 2) for k, iv in enumerate(pat)]
    return out


def arpegio():
    """sube y baja por el acorde (1-3-5-8-10-8-5-3): corcheas en A, semicorcheas en B; en C no hay (colchón)"""
    out = []
    for b in range(1, NB + 1):
        s = seccion(b)
        if s == 'C': continue
        r, q = chord_at(b)
        base = 57 + (r - 57) % 12                                     # La3..Sol#4
        cont = [0, q[1], q[2], 12, 12 + q[1], 12, q[2], q[1]]
        paso = 2 if s == 'A' else 1
        for k in range(16 // paso):
            out.append((b, k * paso, base + cont[k % 8], paso))
    return out


# ══ BATERÍA: recta y pareja ═════════════════════════════════════════════════════════════════════════════════════
#   bombo en 1 y 3 (más fuerte el del tiempo 1 de cada frase: el GOLPE, con platillo corto), caja en 2 y 4,
#   charles en los contratiempos de corchea. En C: solo el golpe de cada frase y charles flojo.
CRASH = [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 3, 2, 2, 1, 1]
HAT, SNARE_N = [5, 2, 1], [11, 8, 5, 3, 1]


def bateria():
    """(segundo, tipo, ganancia) dentro de un bucle"""
    ev = []
    for b in range(1, NB + 1):
        s, t0 = seccion(b), (b - 1) * BAR
        golpe = b % 2 == 1
        if golpe:
            ev += [(t0, 'golpe', 1.0), (t0, 'crash', 1.0)]
        if s == 'C':
            ev += [(t0 + st * S16, 'hat', 0.6) for st in (2, 6, 10, 14)]
            continue
        if not golpe: ev.append((t0, 'kick', 0.55))
        ev += [(t0 + 8 * S16, 'kick', 0.5), (t0 + 4 * S16, 'snare', 1.0), (t0 + 12 * S16, 'snare', 1.0)]
        ev += [(t0 + st * S16, 'hat', 1.0 if s == 'A' else 1.15) for st in (2, 6, 10, 14)]
    return ev


# ══ INSTRUMENTOS ═════════════════════════════════════════════════════════════════════════════════════════════════
I_LEAD = {'vol': [14, 15, 14, 13, 13, 12], 'sus': 12, 'vib': (14, 0.2, 5.6),
          'duty': [0.125, 0.125, 0.25, 0.25, 0.25, 0.5]}               # pulso con barrido de ciclo 12,5 → 50 %
I_SAW = {'vol': [10, 10, 9, 9, 8], 'sus': 8, 'vib': (14, 0.18, 5.6)}  # (A: dobla la melodía una octava abajo en B)
I_N163 = {'vol': [6, 9, 10, 10, 9], 'sus': 9, 'vib': (16, 0.15, 5.2), 'duty': 3.0}   # (B: debajo de la flauta)
I_ARP = {'vol': [10, 7, 5, 4, 3, 2], 'sus': 1, 'duty': 0.25}
I_PAD = dict(W.I_PAD, duty=2.0)
I_TRI = {'vol': [15], 'sus': 15}
WAVES = W.WAVES + [F.wavetable([1.0, 0.45, 0.12, 0.2, 0.03])]          # 3 flauta (como la de worlds_nes)


def tval(b, st, copia=0):
    return copia * NB * BAR + (b - 1) * BAR + st * S16


def construir(v, mel):
    """los stems (mono) de COPIAS bucles seguidos"""
    T = COPIAS * NB * BAR
    NF = F.frames_for(T + 3)
    Cn = {k: Chan(NF) for k in ('lead', 'saw', 'n163', 'arp', 'bass', 'p1', 'p2', 'p3')}
    NZ = {k: Noise(NF) for k in ('hat', 'snare', 'crash')}
    for z in NZ.values(): z.exact = True
    NS = int(NF * F.FRAME_S) + SR
    kick, body = np.zeros(NS), np.zeros(NS)
    flauta, glock = MN.Rec(GM_FLAUTA), MN.Rec(GM_GLOCK)

    def mete(buf, smp, t, g):
        i = int(round(t * SR))
        buf[i:i + len(smp)] += smp[:max(0, min(len(smp), NS - i))] * g

    for c in range(COPIAS):
        for b, st, n, d, nombre in mel:
            s = seccion(b)
            t0, t1 = tval(b, st, c), tval(b, st + d, c) - 0.15 * S16
            vs = 0.8 if s == 'C' else 1.0
            if v == 'A':
                play(Cn['lead'], t0, t1, n, I_LEAD, release=3, vs=vs)
                if s == 'B': play(Cn['saw'], t0, t1, n - 12, I_SAW, q=q_vrc6, release=2)
            else:
                flauta.add(t0, t1, n, 92 if s != 'C' else 76)
                play(Cn['n163'], t0, t1, n, I_N163, q=q_n163, release=3, vs=vs)
                if s == 'B': glock.add(t0, min(t1, t0 + 0.5), n, 70)
        for b, st, n, d in linea_bajo():
            play(Cn['bass'], tval(b, st, c), tval(b, st + d, c) - 0.25 * S16, n, I_TRI, q=q_tri, release=0)
        for b, st, n, d in arpegio():
            play(Cn['arp'], tval(b, st, c), tval(b, st + d, c) - 0.1 * S16, n, I_ARP, release=1,
                 vs=0.9 if seccion(b) == 'A' else 0.8)
        for b in range(1, NB + 1):
            if seccion(b) != 'C': continue
            r, q = chord_at(b)
            for ch, nn in zip(('p1', 'p2', 'p3'), sorted(55 + (r + iv - 55) % 12 for iv in q[:3])):
                play(Cn[ch], tval(b, 0, c), tval(b, 16, c) - 0.1 * S16, nn, I_PAD, q=q_n163, release=4)
        for t, k, g in bateria():
            t += c * NB * BAR
            if k == 'golpe':
                mete(kick, TN.KICK_DEEP, t, 0.75); mete(kick, TN.KICK, t, 0.45)
            elif k == 'kick':
                mete(kick, TN.KICK, t, 0.4 * g)
            elif k == 'snare':
                NZ['snare'].hit(t, 4, SNARE_N); mete(body, TN.SNARE_BODY, t, 0.3)
            elif k == 'hat':
                NZ['hat'].hit(t, 0, [round(x * g) for x in HAT])
            elif k == 'crash':
                NZ['crash'].hit(t, 1, CRASH)
    L = int(round(T * SR)) + 2 * SR
    fit = lambda x: np.pad(x, (0, max(0, L - len(x))))[:L]
    wave = lambda ch: fit(F.render_wave(Cn[ch], WAVES) * 0.0075)
    pulse = lambda ch: fit(F.pulse_dac(F.render_pulse(Cn[ch])))
    base = F.tnd_dac(np.full(NS, 64 / 22638.0))
    from scipy.signal import butter, sosfilt
    blando = butter(1, 2200, btype='low', fs=SR, output='sos')     # (el arpegio, redondo: no tapa la melodía ni los pitidos)
    S = {'lead': pulse('lead'), 'saw': fit(F.render_saw(Cn['saw']) * 0.004), 'n163': wave('n163'),
         'arp': sosfilt(blando, pulse('arp')),
         'bass': fit(F.tnd_dac(F.render_tri(Cn['bass']) / 8227.0)),
         'pad': wave('p1') + wave('p2') + wave('p3'),
         'kick': fit(F.tnd_dac((kick + 64) / 22638.0) - base),
         'snare': fit(F.tnd_dac((body + 64) / 22638.0) - base) + fit(F.tnd_dac(NZ['snare'].render() / 22638.0 * 12)),
         'hat': fit(F.tnd_dac(NZ['hat'].render() / 22638.0 * 12)),
         'crash': fit(F.tnd_dac(NZ['crash'].render() / 22638.0 * 12))}
    for k, r in (('flauta', flauta), ('glock', glock)):            # las capas GM, adelantadas lo que tarda su ataque
        if not r.ev: continue
        adv = MN.attack_smp(r, 0.5)
        y = GM.cached(r, L)
        S[k] = np.concatenate([y[adv:], np.zeros(adv)])
    S = {k: x - np.mean(x) for k, x in S.items() if np.abs(x).max() > 0}
    return S


LV = {'lead': 0, 'flauta': 0, 'saw': -9, 'n163': -10, 'glock': -9, 'arp': -3.5, 'pad': -4.5, 'bass': 0.5,
      'kick': 3.5, 'snare': -5.5, 'hat': -12, 'crash': -8}
REF = {'A': 'lead', 'B': 'flauta'}


def mezcla(v, S):
    """del medio de los 3 bucles: la mezcla (estéreo), con C bajado hasta C_DB respecto a A y B tras masterizar"""
    g = GN.level(S, {k: LV.get(k, -12) for k in S}, REF[v])
    a = NB * BAR_N                                                   # (empieza la copia del medio)
    mid = {k: x[a:a + LOOP_N] * g[k] for k, x in S.items()}
    from scipy.signal import butter, sosfilt
    hp = butter(1, 30, btype='high', fs=SR, output='sos')
    full = {k: sosfilt(hp, S[k] * g[k])[a:a + LOOP_N] for k in S}    # (el filtro, sobre las 3 copias: sin costura)
    x = sum(full.values())
    side = 0.25 * full['arp'] + 0.2 * full['hat'] + 0.15 * full.get('glock', 0) + 0.15 * full.get('saw', 0)
    st = np.stack([x + side, x - side], 1)
    b0, c0 = SECCIONES[0][1] * BAR_N, (SECCIONES[0][1] + SECCIONES[1][1]) * BAR_N
    r = int(0.01 * SR)
    gb, gc = 1.0, 10 ** (C_DB / 20)
    # (se mide en la versión CON pitidos, que es la que mide el comprobador: los pitidos suben más a C, que es más
    #  flojo; sin ellos C queda ~0,3 dB más abajo, también dentro de 3-4 dB. B se iguala a A, para que C quede a la
    #  misma distancia de los dos)
    for _ in range(8):
        env = np.ones(LOOP_N)
        env[b0:c0] = gb
        env[c0:] = gc
        env[b0 - r:b0] = np.linspace(1, gb, r)
        env[c0 - r:c0] = np.linspace(gb, gc, r)                     # (baja justo antes del golpe de C…)
        env[LOOP_N - r:] = np.linspace(gc, 1, r)                    # (…y sube justo antes de la costura)
        y = F.master(st * env[:, None], lufs=LUFS)
        lv = niveles(con_pitidos(y))
        eb = lv[1] - lv[0]
        ec = (lv[2] - (lv[0] + lv[1]) / 2) - C_DB
        if abs(eb) < 0.05 and abs(ec) < 0.05: break
        gb *= 10 ** (-eb / 20); gc *= 10 ** (-ec / 20)
    return y, g, {k: x for k, x in mid.items()}


def niveles(y):
    m = y.mean(1) if y.ndim == 2 else y
    out, b0 = [], 0
    for _, n in SECCIONES:
        seg = m[b0 * BAR_N:(b0 + n) * BAR_N]
        out.append(10 * np.log10(np.mean(seg ** 2) + 1e-20)); b0 += n
    return out


def con_pitidos(y):
    with wave.open(BEEP_WAV, 'rb') as w:
        bp = np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(float) / 32768.0
    z = y.copy()
    for p in range(NB // 2):
        for bt in BEEP_TIEMPOS:
            i = p * 2 * BAR_N + int(round(bt * BAR_N / 4))
            z[i:i + len(bp)] += (bp * BEEP_GAN)[:, None]
    pk = np.abs(z).max()
    return z * (0.98 / pk) if pk > 0.98 else z


# ══ COMPROBACIONES (números: no oyen) ════════════════════════════════════════════════════════════════════════════
CLASH = {1, 6, 11}


def comprueba(v, mel):
    tono, paso, igual, largas, fuera, malas = 0, 0, 0, 0, 0, []
    for i, (b, st, n, d, nombre) in enumerate(mel):
        r, q = chord_at(b)
        en = (n - r) % 12 in [iv % 12 for iv in q]
        assert n % 12 in ESCALA, f'nota fuera de Re mayor: compás {b}'
        tono += en; fuera += st % 4 != 0; largas += d >= 4
        ant = mel[i - 1][2] if i else mel[-1][2]
        sig = mel[i + 1][2] if i + 1 < len(mel) else mel[0][2]
        paso += 1 <= abs(n - ant) <= 2; igual += n == ant
        if not en and not (d < 3 and 1 <= abs(n - ant) <= 2 and 1 <= abs(n - sig) <= 2):
            malas.append((b, st, nm(n), d))
        if b % 2 == 0: assert st == 0, f'la melodía ataca en los tiempos 6-8 (compás {b}, semicorchea {st})'
    t = len(mel)
    stats = dict(notas=t, acorde=100 * tono / t, grado=100 * paso / t, repetidas=100 * igual / t, largas=100 * largas / t,
                 contratiempo=100 * fuera / t)
    print(f'  melodía {v}: {t} notas · del acorde {stats["acorde"]:.0f}% (aprobadas 79-90) · por grado {stats["grado"]:.0f}% (20-44) · '
          f'repetidas {stats["repetidas"]:.0f}% (1-23) · largas {stats["largas"]:.0f}% (11-46) · a contratiempo de negra '
          f'{stats["contratiempo"]:.0f}% (la regla de la casa > 50: aquí, a propósito, no)')
    print('  notas fuera del acorde que entran o salen por salto, o largas:', malas or 'ninguna')
    assert not malas
    bajo = {(b, st): n for b, st, n, d in linea_bajo()}
    choques = []
    for b, st, n, d, _ in mel:
        for k in range(st, st + d, 2):
            bb = bajo.get((b + k // 16, k % 16))
            if bb is not None and (n - bb) % 12 in CLASH: choques.append((b, k, nm(n), nm(bb)))
    print('  bajo contra melodía (m2 / M7 / tritono):', choques or 'ninguno')
    # la melodía nunca ataca en 1,5-3 kHz en los tiempos 6-8 (no ataca nada: ver el assert de arriba); registro
    print(f'  ámbito: {nm(min(m[2] for m in mel))}-{nm(max(m[2] for m in mel))}')
    return stats


def imprime_forma(v, mel):
    mapa = mapa_frases(v)
    print(f'  forma de la melodía {v} (una frase = 2 compases = 4 s):')
    for s, (a, z) in (('A', (0, 10)), ('B', (10, 18)), ('C', (18, 20))):
        print(f'    {s}: ' + ' '.join(f'{mapa[i]}' for i in range(a, z)))
    print('    acordes por sección:')
    b0 = 0
    for s, n in SECCIONES:
        print(f'      {s}: ' + ' | '.join(ACORDES[b0:b0 + n])); b0 += n
    seen = {}
    for b, st, n, d, nombre in mel:
        seen.setdefault(nombre, []).append(nm(n))
    for k, notas in seen.items():
        print(f'      {k:4s} {" ".join(notas)}')


def escribe_mid(v, mel, path):
    import mido
    mid = mido.MidiFile(ticks_per_beat=480)
    tk = lambda b, st: ((b - 1) * 16 + st) * 120
    pistas = [('melodia', 0, 80 if v == 'A' else GM_FLAUTA, [(tk(b, st), d * 120, n) for b, st, n, d, _ in mel]),
              ('bajo', 1, 38, [(tk(b, st), d * 120, n) for b, st, n, d in linea_bajo()]),
              ('arpegio', 2, 81, [(tk(b, st), d * 120, n) for b, st, n, d in arpegio()])]
    gm_dr = {'golpe': 36, 'kick': 36, 'snare': 38, 'hat': 42, 'crash': 49}
    pistas.append(('bateria', 9, None, [(int(round(t / S16 * 120)), 60, gm_dr[k]) for t, k, g in bateria()]))
    for nombre, ch, prog, ev in pistas:
        tr = mido.MidiTrack(); mid.tracks.append(tr)
        tr.append(mido.MetaMessage('track_name', name=nombre, time=0))
        if nombre == 'melodia': tr.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / BPM), time=0))
        if prog is not None: tr.append(mido.Message('program_change', channel=ch, program=prog, time=0))
        e = []
        for t0, d, n in ev: e += [(t0, 1, n), (t0 + d, 0, n)]
        t = 0
        for tt, on, n in sorted(e, key=lambda x: (x[0], x[1])):
            tr.append(mido.Message('note_on' if on else 'note_off', channel=ch, note=n, velocity=96, time=tt - t)); t = tt
    mid.save(path)


def ogg(wavp, oggp):
    os.system(f'ffmpeg -v quiet -y -i "{wavp}" -c:a libvorbis -q:a 6 "{oggp}"')


def variante(v):
    mel = melodia(v)
    print(f'── Variante {v} ({"pulso de chip" if v == "A" else "flauta GM sobre el chip"}): Re mayor, {BPM} BPM, '
          f'{NB} compases = {NB * BAR:.0f} s ({LOOP_N} muestras)')
    stats = comprueba(v, mel)
    imprime_forma(v, mel)
    S = construir(v, mel)
    y, g, mid = mezcla(v, S)
    assert len(y) == LOOP_N
    GN.report(f'via_estelar_{v}', y, mid, {k: 1.0 for k in mid}, LOOP_N)
    lv = niveles(y)
    print(f'  secciones: A {lv[0]:.2f} · B {lv[1]:.2f} · C {lv[2]:.2f} dB (C−A {lv[2] - lv[0]:+.2f}, C−B {lv[2] - lv[1]:+.2f})')
    z = con_pitidos(y)
    if os.environ.get('REPORT'):
        return stats
    os.makedirs(PRUEBAS, exist_ok=True)
    for nombre, x in ((f'{v}_juego', y), (f'{v}_con_beeps', z)):
        wp = os.path.join(PRUEBAS, nombre + '.wav')
        F.write_wav(wp, x)
        ogg(wp, os.path.join(PRUEBAS, nombre + '.ogg'))
        if nombre.endswith('juego'): os.remove(wp)                 # (el .wav con pitidos se queda: lo mide el comprobador)
    escribe_mid(v, mel, os.path.join(PRUEBAS, f'{v}.mid'))
    print(f'  → {PRUEBAS}/{v}_juego.ogg · {v}_con_beeps.ogg/.wav · {v}.mid')
    # INSTALL=1 VIA_ESTELAR=A|B: instala esa SIN pitidos → el juego. Desde 2026-11-15 la instalada es la R (estelar.py):
    # sin VIA_ESTELAR, A y B ya no se instalan.
    if os.environ.get('INSTALL') and v == os.environ.get('VIA_ESTELAR', 'R'):
        dst = os.path.join(ROOT_REPO, 'assets', 'music', 'worlds', 'via_estelar')
        os.makedirs(dst, exist_ok=True)
        wp = os.path.join(dst, 'via_estelar.wav')
        F.write_wav(wp, y)
        ogg(wp, os.path.join(dst, 'via_estelar.ogg'))
        os.remove(wp)
        escribe_mid(v, mel, os.path.join(ROOT_REPO, 'tools', 'music', 'mid', 'via_estelar.mid'))
        print(f'  → instalada: assets/music/worlds/via_estelar/via_estelar.ogg (variante {v})')
    return stats


if __name__ == '__main__':
    vs = [a for a in sys.argv[1:] if a in ('A', 'B', 'R')] or ['A', 'B']
    for v in vs:
        if v == 'R':                                                  # el remaster: tools/music/estelar.py
            import estelar
            estelar.pista('via_estelar')
        else:
            variante(v)
