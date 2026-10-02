#!/usr/bin/env python3
# tools/music/gloomy_nes.py
# La música de los niveles A OSCURAS (Crabbies lúgubres), como música de Famicom (motor: famicom.py):
#
#   python3 tools/music/gloomy_nes.py            → las dos
#   python3 tools/music/gloomy_nes.py jefe|cueva → solo una          REPORT=1 → números, sin exportar
#
# 1) tentacle_gloomy.ogg (catálogo `tentacle_gloomy`, la pelea del Mega Crabby lúgubre): Tentacle
#    Tantrum (la melodía y el bajo de tentacle_nes, nota a nota) pero MÁS LENTA (150 BPM, no 185),
#    de cueva y MENOS CARGADA (sin sierra, sin 2ª voz, sin colchón ni "chop"), con el efecto ARAÑA
#    de "Spider Dance" (Toby Fox): miles de patitas.
#      · PATAS: pulso del 2A03 al 12,5 %, envolvente cortísima (un toque seco), en SEMICORCHEAS
#        seguidas agrupadas de a 8 (las 8 patas), sobre la pentatónica menor del acorde + la blue
#        note (la 5ª bemol, de paso hacia la 5ª). No paran en toda la canción: en primer plano
#        cuando la melodía calla (y en la intro y el break), en segundo cuando canta.
#      · PAUSAS: al cerrar cada frase de 8 compases, media vuelta en cromático hacia abajo y
#        medio compás de SILENCIO (solo sigue la melodía); la vuelta entra con platillo. Es el
#        "drop".
#      · 2º patrón DESFASADO: otro pulso (VRC6) con un ciclo de 6 notas contra el de 8: patas que
#        no van a la par (desde el estribillo).
#      · Saltos de registro (dos notas una octava arriba cada 4 compases), eco del lead a 3
#        semicorcheas (más patas de las que tocan), notas largas que entran retorciéndose (bend
#        corto + vibrato rápido), "chasquidos" de pinza (ruido en modo corto) en 2 y 4.
#    Forma: 4 compases de intro (solo patas; luego entra el bajo) + los 72 de Tentacle, una vuelta.
#
# 2) dark_cave.ogg (catálogo `dark_cave`, música de nivel de las cavernas a oscuras): lenta
#    (72 BPM) y tensa, en Re menor sin resolver (acaba en La mayor y un silencio). El CONTRASTE:
#    abajo, lo oscuro (bordón de triángulo, latido de bombo grave, colchón que se hincha); arriba,
#    lo delicado: una CAJA DE MÚSICA con eco de cueva y gotas de agua. La caja de música canta una
#    nana en secuencia (sube por el acorde y se posa; baja por grados y se posa), forma A A' B A''.
#    En la 3ª frase se oyen, lejos, las PATAS de la música del jefe (un grupo de 8 de vez en cuando).
#
# Se comprueba con números (no se ha escuchado): duración, sonoridad, reparto de energía, que las
# patas no fallen ni una semicorchea fuera de las pausas, y que no tapen la melodía (1-5 kHz).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR, Chan, Noise, play, wavetable, q_n163, q_tri, q_vrc6, q_pulse
import tentacle_nes as TN

OUT = TN.OUT
MAJ, MIN = TN.MAJ, TN.MIN


def rms_on(x):
    """RMS mientras suena (por encima de -50 dB de su pico)"""
    a = np.abs(x)
    m = a > a.max() * 0.003 if a.max() > 0 else a > 1
    return np.sqrt(np.mean(x[m] ** 2)) if m.any() else 0.0


def delay(x, secs, fb, n=4, dark=3500):
    """Eco de cueva: repeticiones cada `secs`, cada una más floja (× fb) y más oscura"""
    from scipy.signal import butter, sosfilt
    sos = butter(1, dark, btype='low', fs=SR, output='sos')
    out, tap = x.copy(), x
    d = int(secs * SR)
    for k in range(1, n + 1):
        tap = sosfilt(sos, tap) * fb
        if d * k >= len(x):
            break
        out[d * k:] += tap[:len(x) - d * k]
    return out


def level(S, db, ref):
    """Ganancias: cada grupo a `db` dB del de referencia (RMS mientras suena)"""
    r = rms_on(S[ref])
    return {k: (r * 10 ** (db[k] / 20) / rms_on(S[k]) if rms_on(S[k]) > 0 else 0.0) for k in S}


def fold(y, n):
    """Bucle sin costura: la cola (lo que suena después del final) se suma al principio"""
    out = y[:n].copy()
    tail = y[n:]
    out[:len(tail)] += tail
    return out


def export(name, y):
    wav = os.path.join(OUT, name + '.wav')
    F.write_wav(wav, y)
    ogg = os.path.join(OUT, name + '.ogg')
    os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"')
    os.remove(wav)
    print(f'  {ogg}')


def report(name, y, S, g, n):
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    print(f'  {name}: {len(y) / SR:.1f} s, {F.loudness(y):.1f} LUFS, pico {np.abs(y).max():.2f}')
    print('  energía: ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.0f}%' for k in S))


# ═════════════════════════════════════════════════════════════════════════════
# 1) El jefe: Tentacle Tantrum de cueva, con patas
# ═════════════════════════════════════════════════════════════════════════════
BPM = 150
S16 = 60.0 / BPM / 4
BAR = 16 * S16
INTRO = 4
NB = INTRO + 72
K = 185.0 / BPM                               # (los tiempos del MIDI, a este tempo)

LEG8 = {MIN: [0, 12, 7, 10, 12, 6, 7, 3], MAJ: [0, 12, 7, 9, 12, 6, 7, 4]}      # (6 = la blue note, de paso a la 5ª)
LEG6 = {MIN: [12, 19, 24, 22, 19, 15], MAJ: [12, 19, 24, 21, 19, 16]}
I_LEG = {'vol': [13, 8, 4, 1], 'sus': 0, 'duty': 0.125}
I_LEG2 = {'vol': [8, 5, 2, 1], 'sus': 0, 'duty': 0.25}
I_SING = {'vol': [14, 14, 13, 13, 12, 12], 'sus': 11, 'vib': (9, 0.32, 6.6), 'drop': [-0.8, -0.45, -0.15]}
I_SHORT = {'vol': [14, 13, 12, 11], 'sus': 10}
I_STAB = {'vol': [15, 12, 9, 6, 4, 2], 'sus': 1}
I_ECHO = {'vol': [5, 5, 4, 3], 'sus': 2, 'duty': 0.25}
I_TRI = {'vol': [15], 'sus': 15}
WAVES = [wavetable([1.0, 0.05, 0.5, 0.03, 0.25, 0.02, 0.12, 0.0, 0.06])]         # hueca (armónicos impares): voz de cueva
CLACK = [13, 7, 3, 1]
HAT = [5, 2, 1]
CRASH = [13, 12, 11, 10, 10, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1]


def song_bar(b):                              # compás de Tentacle (1-72) de un compás de esta pista; None = intro
    return b - INTRO if b > INTRO else None


def chord(b, half):
    sb = song_bar(b)
    return TN.ch('F#m') if sb is None else TN.chord_at(sb, half)


def sect(b):
    sb = song_bar(b)
    return 'IN' if sb is None else TN.section(sb)


def phrase_end(b):                            # el último compás de cada frase de 8 (y el de la intro)
    sb = song_bar(b)
    return b == INTRO or (sb is not None and sb % 8 == 0)


def boss():
    rh, lh = TN.load_midi()
    top, _ = TN.voices(rh)
    conv = lambda t: t * K + INTRO * BAR
    bar_of = lambda t: int(t / BAR + 1 / 64) + 1
    NF = F.frames_for(NB * BAR)
    C = {k: Chan(NF) for k in ('lead', 'echo', 'legs', 'legs2', 'tri')}
    NZ = {k: Noise(NF) for k in ('clack', 'hat', 'crash')}
    NS = int(NF * F.FRAME_S) + SR
    kick = np.zeros(NS)

    # Melodía (N163 hueco) + su eco a 3 semicorcheas (pulso flojo)
    singing = set()                           # semicorcheas en las que canta la melodía
    for s, e, n in top:
        s, e = conv(s), conv(e)
        b = bar_of(s)
        dur = e - s
        steps = dur / S16
        if sect(b) == 'BR':
            inst, gate = I_STAB, dur * 0.5
        elif steps >= 3:
            inst, gate = I_SING, dur * 0.85   # (las largas entran retorciéndose)
        else:
            inst, gate = I_SHORT, dur * 0.75
        play(C['lead'], s, s + gate, n, dict(inst, duty=0.0), q=q_n163)
        for k in range(int(round(s / S16)), int(round((s + gate) / S16)) + 1):
            singing.add(k)
        if sect(b) != 'BR':
            play(C['echo'], s + 3 * S16, s + 3 * S16 + gate * 0.7, n, I_ECHO)

    # PATAS: semicorcheas sin parar, de 8 en 8
    slots = played = 0
    i6 = 0
    for b in range(1, NB + 1):
        sec = sect(b)
        if (b - INTRO - 1) % 8 == 0:
            i6 = 0                            # (el patrón de 6 vuelve a empezar con cada frase)
        for k in range(16):
            t = (b - 1) * BAR + k * S16
            r, q = chord(b, k // 8)
            base = 54 + (r - 54) % 12
            if phrase_end(b):
                if k >= 8:
                    continue                  # el silencio
                note = base + 12 - k          # media vuelta en cromático hacia abajo
            else:
                note = base + LEG8[q][k % 8]
                if b % 4 == 3 and k in (12, 13):
                    note += 12                # (salto de registro: la araña gira de golpe)
            slots += 1
            front = sec in ('IN', 'BR') or ((b - 1) * 16 + k) not in singing
            if sec in ('IN', 'BR'):
                note += 12
            play(C['legs'], t, t + S16 * 0.5, note, I_LEG, vs=1.0 if front else 0.4, release=0)     # (en 2º plano bajo la melodía)
            played += 1
            if sec in ('B', 'C', 'D') and not phrase_end(b):
                play(C['legs2'], t, t + S16 * 0.5, base + LEG6[q][i6 % 6], I_LEG2, q=q_vrc6, vs=1.0 if sec == 'D' else 0.75, release=0)
            i6 += 1

    # Bajo (solo triángulo): el del MIDI; el final, del original; en la intro entra a mitad
    def bass(t0, t1, n):
        b = bar_of(t0)
        if phrase_end(b) and t0 - (b - 1) * BAR >= 8 * S16 - 1e-6:
            return                            # (la pausa)
        if phrase_end(b):
            t1 = min(t1, (b - 1) * BAR + 8 * S16)
        play(C['tri'], t0, t1, n, I_TRI, q=q_tri, release=0)
    for s, e, n in lh:
        s, e = conv(s), conv(e)
        if sect(bar_of(s)) == 'D':
            continue
        while n < 33:
            n += 12
        bass(s, s + (e - s) * (0.45 if sect(bar_of(s)) == 'BR' else 0.8), n)
    for b in range(1, NB + 1):
        t0 = (b - 1) * BAR
        if sect(b) == 'D':
            r, _ = chord(b, 0)
            root = 36 + (r - 36) % 12 - (12 if r >= 8 else 0)
            for st, dm, ln in ((0, 0, 6), (6, 7, 4), (10, 0, 6)):
                bass(t0 + st * S16, t0 + (st + ln) * S16 * 0.85, root + dm)
        elif b in (3, 4):
            for st, ln in ((0, 6), (6, 4), (10, 6)):
                bass(t0 + st * S16, t0 + (st + ln) * S16 * 0.8, 42)          # Fa#2

    # Percusión seca: bombo, chasquidos de pinza (ruido corto) en 2 y 4, hi-hat a contratiempo
    def hit(buf, t, smp, g=1.0):
        i = int(t * SR)
        j = min(len(buf), i + len(smp))
        buf[i:j] = smp[:j - i] * g
    for b in range(1, NB + 1):
        sec = sect(b)
        t0 = (b - 1) * BAR
        end = phrase_end(b)
        kicks = {'IN': (0, 10) if b >= 3 else (), 'A': (0, 10), 'BR': (0, 4, 8, 12), 'B': (0, 6, 10), 'C': (0, 12), 'D': (0, 6, 10)}[sec]
        clacks = {'IN': (), 'A': (4, 12), 'BR': (4, 12), 'B': (4, 12), 'C': (8,), 'D': (4, 12)}[sec]
        for st in kicks:
            if not (end and st >= 8):
                hit(kick, t0 + st * S16, TN.KICK_DEEP if sec == 'BR' else TN.KICK)
        for st in clacks:
            if not (end and st >= 8):
                NZ['clack'].hit(t0 + st * S16, 6, CLACK, short=1)
        if sec in ('B', 'D'):
            for st in (2, 6, 10, 14):
                if not (end and st >= 8):
                    NZ['hat'].hit(t0 + st * S16, 0, HAT)
        sb = song_bar(b)
        if sb is not None and sb % 8 == 1:    # la vuelta tras cada pausa
            NZ['crash'].hit(t0, 3, CRASH)

    n = int(NB * BAR * SR)
    cut = lambda x: fold(x[:n + SR] - np.mean(x[:n]), n)
    S = {
        'lead':  cut(F.render_wave(C['lead'], WAVES) * 0.0075),
        'echo':  cut(F.pulse_dac(F.render_pulse(C['echo']))),
        'legs':  cut(F.pulse_dac(F.render_pulse(C['legs']))),
        'legs2': cut(F.render_pulse(C['legs2']) * 0.0075),
        'tri':   cut(F.tnd_dac(F.render_tri(C['tri']) / 8227.0)),
        'kick':  cut(F.tnd_dac((kick + 64) / 22638.0)),
        'clack': cut(F.tnd_dac(NZ['clack'].render() / 12241.0)),
        'hat':   cut(F.tnd_dac(NZ['hat'].render() / 12241.0)),
        'crash': cut(F.tnd_dac(NZ['crash'].render() / 12241.0)),
    }
    S['lead'] = delay(S['lead'], 3 * S16, 0.22, 2)                    # (un poco de cueva en la voz)
    g = level(S, {'lead': 0, 'echo': -11, 'legs': -6, 'legs2': -13, 'tri': -1, 'kick': -0.5, 'clack': -5, 'hat': -15, 'crash': -9}, 'lead')
    # La melodía manda: las patas no pasan del 50 % de ella en 1-5 kHz mientras canta (en primer plano, cuando
    # calla, suenan 8 dB más: su envolvente va a 1.0 en vez de 0.4)
    from scipy.signal import butter, sosfilt
    sos = butter(4, [1000, 5000], btype='band', fs=SR, output='sos')
    mask = np.abs(S['lead']) > np.abs(S['lead']).max() * 0.02
    mel = np.sqrt(np.mean((sosfilt(sos, S['lead'])[mask] * g['lead']) ** 2))
    ratio, cut_db = {}, {}
    for k in ('legs', 'legs2', 'echo'):
        x = np.sqrt(np.mean((sosfilt(sos, S[k])[mask] * g[k]) ** 2))
        top_ = 0.5 if k == 'legs' else 0.45     # (las patas son el efecto: un poco más de margen)
        if x / mel > top_:
            cut_db[k] = 20 * np.log10(top_ * mel / x)
            g[k] *= top_ * mel / x
            x = top_ * mel
        ratio[k] = x / mel
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    side = S['echo'] * g['echo'] * 0.4 + S['legs2'] * g['legs2'] * 0.5 - S['legs'] * g['legs'] * 0.25
    y = F.master(np.stack([x + side, x - side], 1), lufs=-11.0)
    report('tentacle_gloomy', y, S, g, n)
    print(f'  {BPM} BPM, {NB} compases; patas: {played}/{slots} semicorcheas fuera de las pausas '
          f'({NB * 16 - slots} en silencio, {sum(1 for b in range(1, NB + 1) if phrase_end(b))} pausas); '
          'bajo la melodía (1-5 kHz): ' + ' '.join(f'{k} {v:.2f}' for k, v in ratio.items())
          + ' (recortes: ' + ' '.join(f'{k} {v:.1f} dB' for k, v in cut_db.items()) + ')')
    return y


# ═════════════════════════════════════════════════════════════════════════════
# 2) La caverna a oscuras (música de nivel)
# ═════════════════════════════════════════════════════════════════════════════
CB = 72
CS = 60.0 / CB / 4
CBAR = 16 * CS
CN = 32
D, Eb, F_, G, A, Bb = 2, 3, 5, 7, 9, 10
CH = ([(D, MIN), (D, MIN), (Bb, MAJ), (Bb, MAJ), (G, MIN), (G, MIN), (A, MAJ), (A, MAJ)] +
      [(D, MIN), (D, MIN), (Bb, MAJ), (Bb, MAJ), (Eb, MAJ), (Eb, MAJ), (A, MAJ), (A, MAJ)] +        # (Mi♭: la napolitana)
      [(G, MIN), (G, MIN), (D, MIN), (D, MIN), (Eb, MAJ), (Eb, MAJ), (A, MAJ), (A, MAJ)] +
      [(D, MIN), (D, MIN), (Bb, MAJ), (Bb, MAJ), (G, MIN), (Eb, MAJ), (A, MAJ), (A, MAJ)])           # acaba en La: sin resolver
# La caja de música: (compás, semicorchea, nota). Una melodía de VERDAD, de nana (la 1ª versión
# troceaba la célula del riff de Tentacle a cámara lenta: el usuario no le encontró sentido musical,
# aunque el ambiente sí encajaba). Una idea de 2 compases — SUBE por el acorde en negras y se posa
# en una blanca; luego BAJA por grados y se posa — que se repite en secuencia sobre cada acorde
# (pregunta / respuesta), frases de 8 compases en forma A A' B A'', todas las notas largas son del
# acorde y el final se queda en la sensible (Do#): sin resolver.
def Q(b, n1, n2, n3):                         # negra, negra, blanca
    return [(b, 0, n1), (b, 4, n2), (b, 8, n3)]


def H(b, n1, n2):                             # dos blancas
    return [(b, 0, n1), (b, 8, n2)]


A4, Bb4, C5, Cs5, D5, Eb5, E5, F5, G5, A5, Bb5, G4 = 69, 70, 72, 73, 74, 75, 76, 77, 79, 81, 82, 67
PHRASE_A = (Q(1, A4, D5, F5) + Q(2, E5, D5, A4) +             # Rem: sube La-Re-Fa; baja Mi-Re-La
            Q(3, Bb4, D5, F5) + Q(4, G5, F5, D5) +            # Si♭: lo mismo un grado arriba, la respuesta llega más alto
            Q(5, G4, Bb4, D5) + Q(6, D5, C5, Bb4) +           # Solm
            Q(7, A4, Cs5, E5))                                # La: sube a la 5ª…
BELL = (PHRASE_A + H(8, E5, Cs5) +                            # … y cae a la sensible (pregunta abierta)
        [(b + 8, k, n) for b, k, n in PHRASE_A if b <= 4] + [(10, 12, D5)] +      # A': igual, con una nota de paso
        Q(13, G4, Bb4, Eb5) + Q(14, Eb5, D5, Bb4) +           # Mi♭ (la napolitana): el giro oscuro
        Q(15, A4, Cs5, E5) + [(16, 0, A5)] +
        H(17, D5, G5) + H(18, Bb5, G5) +                      # B: arriba y en blancas (respira)
        H(19, A5, F5) + [(20, 0, D5)] +
        H(21, Eb5, G5) + H(22, Bb5, G5) +
        H(23, A5, E5) + [(24, 0, Cs5)] +
        [(b + 24, k, n) for b, k, n in PHRASE_A if b <= 5] +  # A'': vuelve la primera frase
        Q(30, Eb5, D5, Bb4) + Q(31, A4, Cs5, E5) + [(32, 0, Cs5)])   # … y se queda en la sensible, y silencio
I_BELL = {'vol': [15, 13, 12, 11, 10, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 1, 1, 1], 'sus': 0}
I_PADC = {'vol': [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6], 'sus': 6, 'vib': (30, 0.14, 4.5)}
I_DRIP = {'vol': [9, 6, 3, 1], 'sus': 0, 'duty': 0.125, 'drop': [-5, -2, 0]}
CWAVES = [wavetable([1.0, 0.0, 0.55, 0.0, 0.0, 0.32, 0.0, 0.18]),    # 0 caja de música (parciales de campana)
          wavetable([1.0, 0.3, 0.1])]                                 # 1 colchón (casi seno)


def cave():
    rng = np.random.default_rng(7)
    NF = F.frames_for(CN * CBAR + 3)
    C = {k: Chan(NF) for k in ('bell', 'pad1', 'pad2', 'tri', 'drip', 'legs')}
    NS = int(NF * F.FRAME_S) + SR
    kick = np.zeros(NS)
    busy = {(b, k) for b, k, _ in BELL}
    for b, k, n in BELL:
        t = (b - 1) * CBAR + k * CS
        play(C['bell'], t, t + CS * 6, n, dict(I_BELL, duty=0.0), q=q_n163, release=6)
    for b in range(1, CN + 1):
        t0 = (b - 1) * CBAR
        r, q = CH[b - 1]
        last = b == CN
        dur = CBAR * (0.5 if last else 0.97)                         # (el último: medio compás y silencio)
        play(C['tri'], t0, t0 + dur, 38 + (r - 38) % 12, I_TRI, q=q_tri, release=0)
        base = 57 + (r - 57) % 12
        play(C['pad1'], t0, t0 + dur, base + q[1], dict(I_PADC, duty=1.0), q=q_n163, release=10)
        play(C['pad2'], t0, t0 + dur, base + q[2], dict(I_PADC, duty=1.0), q=q_n163, release=10)
        # el latido: dos golpes graves; al principio, compás sí compás no
        if (b > 8 or b % 2 == 1) and not last:
            for st, gk in ((0, 1.0), (3, 0.7)):
                i = int((t0 + st * CS) * SR)
                kick[i:i + len(TN.KICK_DEEP)] = TN.KICK_DEEP * gk
        # gotas: 0-2 por compás, agudas, en notas del acorde, donde no toca la caja de música
        for _ in range(int(rng.integers(0, 3))):
            k = int(rng.integers(0, 16))
            if (b, k) in busy or (last and k >= 8):
                continue
            note = 84 + (r - 84) % 12 + [0, q[1], q[2], 12][int(rng.integers(0, 4))]
            play(C['drip'], t0 + k * CS, t0 + k * CS + 0.07, note, I_DRIP, release=0)
        # las PATAS del jefe, lejos: un grupo de 8 en la 3ª frase
        if b in (18, 20, 22, 24):
            lb = 62 + (r - 62) % 12
            for k in range(8):
                kk = k if b == 24 else 8 + k
                play(C['legs'], t0 + kk * CS, t0 + kk * CS + 0.05, lb + LEG8[q][k], I_LEG, vs=0.6, release=0)

    n = int(CN * CBAR * SR)
    tail = 3 * SR
    cut = lambda x: x[:n + tail] - np.mean(x[:n])
    S = {
        'bell': delay(cut(F.render_wave(C['bell'], CWAVES) * 0.0075), 3 * CS, 0.5, 4, 2600),
        'pad':  cut((F.render_wave(C['pad1'], CWAVES) + F.render_wave(C['pad2'], CWAVES)) * 0.0075),
        'tri':  cut(F.tnd_dac(F.render_tri(C['tri']) / 8227.0)),
        'kick': cut(F.tnd_dac((kick + 64) / 22638.0)),
        'drip': delay(cut(F.pulse_dac(F.render_pulse(C['drip']))), 0.31, 0.4, 3, 3000),
        'legs': delay(cut(F.pulse_dac(F.render_pulse(C['legs']))), 2 * CS, 0.35, 2, 2500),
    }
    S = {k: fold(v, n) for k, v in S.items()}
    g = level(S, {'bell': 0, 'pad': -9, 'tri': -2, 'kick': -3, 'drip': -12, 'legs': -15}, 'bell')
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    p1 = fold(cut(F.render_wave(C['pad1'], CWAVES) * 0.0075), n) * g['pad']
    side = p1 * 0.45 - (S['pad'] * g['pad'] - p1) * 0.45 + S['drip'] * g['drip'] * 0.5 - S['legs'] * g['legs'] * 0.4
    y = F.master(np.stack([x + side, x - side], 1), lufs=-13.0)
    report('dark_cave', y, S, g, n)
    print(f'  {CB} BPM, {CN} compases, Re menor; caja de música: {len(BELL)} notas')
    return y


if __name__ == '__main__':
    which = [a for a in sys.argv[1:]] or ['jefe', 'cueva']
    for w in which:
        y = boss() if w == 'jefe' else cave()
        if not os.environ.get('REPORT'):
            export('tentacle_gloomy' if w == 'jefe' else 'dark_cave', y)
