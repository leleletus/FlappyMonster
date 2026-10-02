#!/usr/bin/env python3
# tools/music/tentacle_winter.py
# "Tentacle Tantrum" × "Winter Fallympics": la música del Mega Crabby helado.
# NO es una mezcla de las dos pistas: es un arreglo nuevo (mismo motor de Famicom) con
#   · la BASE de tentacle_nes: su melodía nota a nota (MIDI, mano derecha), su bajo
#     (mano izquierda), su armonía (HARM, medida en el original) y su batería (bombo en
#     tresillo, caja en 2 y 4, break en negras, redobles);
#   · la PALETA de winter_nes: lead de sierra del VRC6 + brillo de pulso a la octava,
#     caja de música (campana N163 con eco), cuerdas huecas, subgrave de triángulo con
#     "slap", acordes en pulsos, centelleo en semicorcheas, su batería (bombo / caja DPCM)
#     y CASCABELES (ruido corto del 2A03: nuevo);
#   · el MOTIVO navideño de winter_nes (la caja de música: 1 1' 7 6 | 5 4 3 4 | 5 6 5 4 |
#     3 2 1 2 | 1, en negras) integrado en la forma, no pegado encima:
#       estribillo (Rem Do Si♭ Si♭ | Solm La Si♭ Do)  la melodía de Tentacle deja HUECOS
#           (compases 27-28, 31-32, 35-36, 39-40): ahí RESPONDE la caja de música con el
#           motivo en su tonalidad original (Fa mayor = la escala de Re menor), y esos
#           huecos caen sobre Si♭ Si♭ / Si♭ Do: los acordes que el motivo tiene en winter;
#       riff (Fa#m, luego Solm)  solo la cabeza del motivo, transpuesta por GRADOS (el mismo
#           dibujo desde la 5ª del menor: Do# Do#' Si La...), en compases alternos (la 2ª
#           vuelta, el motivo entero);
#       escalas  entra cuando la música llega a Fa (compases 49-56; en la 2ª vuelta también
#           en Mi, 41-48);
#       final (Si – Do# – Re#)  el motivo en la escala del final (Re# mixolidio ♭6) y,
#           la 2ª vuelta, armonizado a la quinta como en winter.
#   Toda nota AÑADIDA (campanas, quintas, cuerdas) pasa por `fit`: si es una nota a evitar
#   del acorde (un semitono sobre una nota del acorde) o roza en semitono a la melodía que
#   suena en ese momento, se mueve a la nota del acorde más cercana (o se quita).
#
#   python3 tools/music/tentacle_winter.py        → assets/music/tentacle_winter.ogg (+ .mid)
#   REPORT=1 python3 ...                           → solo los números (sin exportar)
#   SOLO=lead,bell python3 ...                     → solo esos instrumentos
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import tentacle_nes as TN                      # melodía, bajo, armonía, forma
import winter_nes as W                         # paleta: canción, instrumentos, batería
from famicom import (master, SR, Noise, tnd_dac, band_power, OCT, write_wav, loudness, biquad)

BPM, BAR, S16, NB = W.BPM, W.BAR, W.S16, 144
E = BAR / 8                                    # corchea
assert abs(BAR - TN.BAR) < 1e-9, 'las dos canciones van al mismo tempo (185 BPM)'
OUT = W.OUT
NAME = 'tentacle_winter'
SECT = [('A', 1, 16), ('BR', 17, 24), ('B', 25, 40), ('C', 41, 56), ('D', 57, 72)]


def bar_of(t):
    return int(t / BAR + 1e-6) + 1


def loc(b):
    """Compás 1-144 → (compás 1-72 de la forma, vuelta 1 o 2)"""
    return (b - 1) % 72 + 1, 1 if b <= 72 else 2


# ── El motivo navideño (grados de la escala respecto a la tónica de arriba) ───
MAJOR = [0, 2, 4, 5, 7, 9, 11]
MIXO = [0, 2, 4, 5, 7, 9, 10]
MIXO_B6 = [0, 2, 4, 5, 7, 8, 10]               # la escala del final: Re# con Si y Do# (♭VI, ♭VII)
MOTIF = [[-7, 0, -1, -2], [-3, -4, -5, -4], [-3, -2, -3, -4], [-5, -6, -7, -6]]
LAND = -7


def deg(tonic, scale, d):
    """Grado d (0 = tónica `tonic`, negativos hacia abajo) → nota MIDI"""
    return tonic + 12 * (d // 7) + scale[d % 7]


def chord_pcs(b, half):
    r, q = TN.chord_at(b, half)
    return [(r + x) % 12 for x in q]


def fit(m, b, half, lead_now, prev=None):
    """Encaja una nota añadida: ni nota a evitar del acorde (un semitono SOBRE una nota del
    acorde) ni a un semitono de la melodía que suena. Nota a evitar → la nota del acorde más
    cercana que no REPITA la anterior; roce con la melodía → se calla (pregunta y respuesta) (`prev`: repetir deshace el dibujo del motivo).
    Devuelve (nota | None, cambió)"""
    pcs = chord_pcs(b, half)

    def avoid(n):
        pc = n % 12
        return pc not in pcs and any((pc - c) % 12 == 1 for c in pcs)

    def rub(n):
        return any((n - l) % 12 in (1, 11) for l in lead_now)

    def bad(n):
        return avoid(n) or rub(n)
    if not bad(m):
        return m, False
    if not avoid(m):
        return None, True          # (roza a la melodía: mejor un silencio que cambiar el motivo)
    ok = [n for d in range(1, 6) for n in (m - d, m + d) if n % 12 in pcs and not bad(n)]
    for n in ok:
        if n != prev:
            return n, True
    return (ok[0], True) if ok else (None, True)


# ── Arreglo ──────────────────────────────────────────────────────────────────
I_SLEIGH = [7, 5, 4, 3, 2, 1]                  # cascabel: ruido corto (metálico), agudo
I_SLEIGH_OFF = [4, 3, 2, 1]
I_STAB = {'vol': [15, 13, 11, 8, 6, 4], 'sus': 3}
STATS = {'moved': 0, 'dropped': 0, 'bells': 0, 'statements': 0, 'strings': 0}


def build():
    rh, lh = TN.load_midi()
    top, _ = TN.voices(rh)
    S = W.Song(NB)
    S.NZ['sleigh'] = Noise(S.nf)

    # Melodía de Tentacle con el lead de winter (sierra + brillo); en el break, golpes cortos
    lead_at = {}                                # (compás, semicorchea) → notas de la melodía sonando
    for s, e, n in top:
        b = bar_of(s)
        fb, lap = loc(b)
        sec = TN.section(b)
        dur = e - s
        gate = 0.55 if sec == 'BR' else 0.92
        S.note('lead_saw', 'saw', s, dur, n, I_STAB if sec == 'BR' else W.I_SAW, gate=gate, midi='lead')
        S.note('lead_sheen', 'pulse', s, dur, n + 12, W.I_SHEEN, gate=gate, midi='lead')
        if sec == 'D' or (lap == 2 and sec == 'B'):
            # el estribillo de la 2ª vuelta y el final, con cuerpo: la onda de lead a la octava baja
            S.note('lead_low', 'n163', s, dur, n - 12, W.I_LEAD_N, vs=0.8, gate=gate, midi='lead')
        k0, k1 = int(round(s / S16)), max(int(round(s / S16)) + 1, int(round((s + dur * gate) / S16)))
        for k in range(k0, k1):
            lead_at.setdefault(k, []).append(n)

    def lead_during(t0, steps=5):
        k0 = int(round(t0 / S16))
        out = []
        for k in range(k0, k0 + steps):
            out += lead_at.get(k, [])
        return out

    # Bajo de Tentacle con el de winter: triángulo de subgrave + "slap" N163 corto
    def bass(t0, t1, n, sub=True):
        S.note('bass_tri', 'tri', t0, t1 - t0, n - 12 if (n >= 40 and sub) else n, W.I_TRI, gate=1.0, midi='bass')
        S.note('bass_n', 'n163', t0, min(t1 - t0, S16 * 1.6), n, W.I_BASSN, gate=0.9, midi='bass')
    for s, e, n in lh:
        sec = TN.section(bar_of(s))
        if sec == 'D':
            continue
        while n < 33:
            n += 12
        if sec == 'BR':
            bass(s, s + (e - s) * 0.4, n, sub=False)
        else:
            bass(s, s + (e - s) * 0.88, n)
    for b in range(1, NB + 1):                   # el final: tresillo raíz – 5ª – raíz (del original)
        if TN.section(b) != 'D':
            continue
        r, _ = TN.chord_at(b, 0)
        root = 36 + (r - 36) % 12 - (12 if r >= 8 else 0)
        t0 = (b - 1) * BAR
        for st, dm, ln in ((0, 0, 3), (3, 7, 2), (5, 0, 3)):
            bass(t0 + st * E, t0 + (st + ln) * E * 0.9, root + dm)

    # Acordes: el "chop" de Tentacle en 2 y 4, con los pulsos de winter (tercera y quinta);
    # cuerdas huecas (winter) sosteniendo la armonía; centelleo en las escalas
    for b in range(1, NB + 1):
        fb, lap = loc(b)
        sec = TN.section(b)
        t0 = (b - 1) * BAR
        for half in (0, 1):
            r, q = TN.chord_at(b, half)
            base = 60 + (r - 60) % 12
            if sec != 'BR':
                st = 2 + half * 4
                S.note('chord0', 'vrc6', t0 + st * E, E, base + q[1], W.I_CHORD, gate=0.8, midi='keys')
                S.note('chord1', 'vrc6', t0 + st * E, E, base + q[2], W.I_CHORD2, gate=0.8, midi='keys')
            else:
                for k in (0, 2):                                       # break: golpe en cada negra
                    tt = t0 + (half * 4 + k) * E
                    S.note('chord0', 'vrc6', tt, E, base + q[1], W.I_CHORD, vs=0.8, gate=0.6, midi='keys')
                    S.note('chord1', 'vrc6', tt, E, base + q[2] - 12, W.I_CHORD2, vs=0.8, gate=0.6, midi='keys')
            # Cuerdas: estribillo, escalas y final (y el riff de la 2ª vuelta, más flojas)
            if sec in ('B', 'C', 'D') or (sec == 'A' and lap == 2):
                vs = {'A': 0.55, 'B': 0.85, 'C': 0.7, 'D': 1.0}[sec]
                tt = t0 + half * BAR / 2
                ld = lead_during(tt, 8)
                # (nota sostenida: si la melodía pasa a un semitono de ella, la raíz; si tampoco, nada)
                for nm_, ins, m in (('str0', W.I_STR, base + q[2] - (12 if base + q[2] > 70 else 0)),
                                    ('str1', W.I_STR2, base + 12 + q[1] - (12 if base + q[1] > 70 else 0))):
                    if any((m - l) % 12 in (1, 11) for l in ld):
                        m = base + (12 if nm_ == 'str1' else 0)
                        STATS['strings'] += 1
                        if any((m - l) % 12 in (1, 11) for l in ld):
                            continue
                    S.note(nm_, 'n163', tt, BAR / 2, m, ins, vs=vs, gate=0.98, midi='keys')
            if sec == 'C' or (sec == 'D' and lap == 2):
                # Centelleo (las dos canciones lo tienen en este punto): arpegio en semicorcheas
                notes = sorted(72 + ((r + x) % 12) for x in q)
                for k in range(8):
                    S.note('shim', 'pulse', t0 + half * BAR / 2 + k * S16, S16, notes[k % 3] + (12 if k >= 3 and k < 6 else 0),
                           W.I_SHIM, vs=0.9 if sec == 'C' else 0.75, gate=0.7, midi='keys')

    # ── El motivo navideño en la caja de música ──────────────────────────────
    prev = [None]

    def bell(t, m, b, half, vs=1.0, pair=True, fifth=None):
        """Una nota del motivo (negra): campana + su octava baja + eco, encajada con `fit`"""
        n, moved = fit(m, b, half, lead_during(t), prev[0])
        prev[0] = n
        STATS['moved'] += 1 if (moved and n is not None) else 0
        if n is None:
            STATS['dropped'] += 1
            return
        STATS['bells'] += 1
        S.note('bell0', 'n163', t, BAR / 4, n, W.I_BELL, vs=vs, gate=1.2, midi='bell', release=6)
        if pair:
            S.note('bell1', 'n163', t, BAR / 4, n - 12, W.I_BELL, vs=vs * 0.85, gate=1.2, midi='bell', release=6)
        S.note('echo', 'n163', t + 3 * S16, BAR / 4, n, W.I_ECHO, vs=vs, gate=1.2, midi='bell', release=4)
        if fifth is not None:
            f, _ = fit(fifth, b, half, lead_during(t))
            if f is not None and (f - n) % 12 != 0:
                S.note('bell5', 'pulse', t, BAR / 4, f, W.I_SPARK, vs=vs, gate=1.0, midi='bell')

    def motif_bar(b, i, tonic, scale, vs=1.0, pair=True, fifth=False, up=0):
        """El compás i (0-3) del motivo en el compás b, en la tonalidad (tonic, scale);
        `up` = grados de transposición DIATÓNICA (el mismo dibujo desde otro grado)"""
        t0 = (b - 1) * BAR
        for k, d in enumerate(MOTIF[i]):
            bell(t0 + k * BAR / 4, deg(tonic, scale, d + up), b, k // 2, vs=vs, pair=pair,
                 fifth=deg(tonic, scale, d + up + 4) if fifth else None)

    def landing(b, tonic, scale, vs=1.0):
        """La nota de llegada (el 1 de abajo), ajustada al acorde del compás donde cae"""
        bell((b - 1) * BAR, deg(tonic, scale, LAND), b, 0, vs=vs)

    F6, A5, Bb5, E6, Ds6 = 89, 81, 82, 88, 87
    for lap in (1, 2):
        o = (lap - 1) * 72
        hi = lap == 2
        # Riff (Fa#m → La mayor; Solm → Si♭ mayor): la cabeza del motivo en compases alternos;
        # la 2ª vuelta, el motivo entero repartido por los huecos del riff
        if not hi:
            motif_bar(o + 5, 0, A5, MAJOR, vs=0.7, pair=False, up=2); motif_bar(o + 7, 1, A5, MAJOR, vs=0.7, pair=False, up=2)
            motif_bar(o + 13, 0, Bb5, MAJOR, vs=0.7, pair=False, up=2); motif_bar(o + 15, 1, Bb5, MAJOR, vs=0.7, pair=False, up=2)
            STATS['statements'] += 2
        else:
            for i, b in enumerate((1, 3, 5, 7)):
                motif_bar(o + b, i, A5, MAJOR, vs=0.8, up=2)
            for i, b in enumerate((9, 11, 13, 15)):
                motif_bar(o + b, i, Bb5, MAJOR, vs=0.8, up=2)
            STATS['statements'] += 2
        # Estribillo: pregunta (Tentacle) y respuesta (el motivo) en los huecos de la melodía
        for b0, fifth in ((25, False), (33, hi)):
            motif_bar(o + b0 + 2, 0, F6, MAJOR, fifth=fifth); motif_bar(o + b0 + 3, 1, F6, MAJOR, fifth=fifth)
            motif_bar(o + b0 + 6, 2, F6, MAJOR, fifth=fifth); motif_bar(o + b0 + 7, 3, F6, MAJOR, fifth=fifth)
            landing(o + b0 + 8, F6, MAJOR)
            STATS['statements'] += 1
        # Escalas: en Mi (solo la 2ª vuelta) y en Fa (su tonalidad: siempre)
        if hi:
            for i in range(4):
                motif_bar(o + 41 + i, i, E6, MAJOR, vs=0.75)
            landing(o + 45, E6, MAJOR, vs=0.75)
            STATS['statements'] += 1
        for i in range(4):
            motif_bar(o + 49 + i, i, F6, MAJOR, vs=0.85, fifth=hi)
        landing(o + 53, F6, MAJOR, vs=0.85)
        STATS['statements'] += 1
        # Final (Si – Do# – Re# – Re#): el motivo en la escala del final; la 2ª vuelta, en las
        # cuatro frases y a la quinta
        for b0 in ((57, 65) if not hi else (57, 61, 65, 69)):
            for i in range(4):
                # (sobre Si y Do#: con Si natural; sobre Re#: mixolidio, con Do)
                motif_bar(o + b0 + i, i, Ds6, MIXO_B6 if i < 2 else MIXO, fifth=hi)
            if b0 + 4 <= 72:
                landing(o + b0 + 4, Ds6, MIXO_B6)
            STATS['statements'] += 1
        # Break: sin motivo; la caja de música puntea el acorde con los golpes (frío, vacío)
        for b in range(o + 17, o + 23):
            r, q = TN.chord_at(b, 0)
            base = 84 + (r - 84) % 12
            for st, x in ((6, q[2]), (10, q[1]), (14, 0)):
                S.note('bell0', 'n163', (b - 1) * BAR + st * S16, S16 * 2, base + x - 12, W.I_BELL, vs=0.6, gate=1.2,
                       midi='bell', release=5)

    # ── Batería: los patrones de Tentacle con la batería de winter + cascabeles ─
    for b in range(1, NB + 1):
        fb, lap = loc(b)
        sec = TN.section(b)
        t0 = (b - 1) * BAR
        if sec == 'BR':
            kicks, snares = (0, 2, 4, 6), (2, 6)
        elif sec == 'C':
            kicks, snares = (0, 3, 6), (4,)
        else:
            kicks, snares = (0, 3, 5), (2, 6)
        if sec == 'D' and fb % 2 == 0:
            kicks = (0, 3, 5, 7)
        for st in kicks:
            S.drum(t0 + st * E, 36, 1.0)
        for st in snares:
            S.drum(t0 + st * E, 40, 1.0)
        if sec == 'C':
            S.drum(t0 + 2 * E, 40, 0.45)                              # (fantasma del medio tiempo)
        for st in range(8):
            if st in snares:
                continue
            S.drum(t0 + st * E, 42, 1.0 if st % 2 else 0.65)
            if sec in ('B', 'C', 'D') and st + 1 not in snares:
                S.NZ['hat'].hit(t0 + st * E + S16, 0, [4, 2, 1])      # (semicorchea fantasma)
        if fb in (1, 17, 25, 41, 49, 57):
            S.drum(t0, 49, 1.0)
        if fb in (16, 24, 40, 56, 72):                                # redoble antes de cada sección
            for k in range(8):
                S.drum(t0 + 4 * E + k * S16, 40, 0.5 + 0.06 * k)
        if fb in (24, 56):                                            # subida de ruido al estribillo y al final
            S.riser(t0 - BAR, t0 + BAR, top=10)
        # Cascabeles: en corcheas (acento en los tiempos); en el riff solo la 2ª vuelta
        if sec in ('B', 'C', 'D') or (sec == 'A' and lap == 2) or (sec == 'BR' and fb >= 23):
            for st in range(8):
                S.NZ['sleigh'].hit(t0 + st * E, 1, I_SLEIGH if st % 2 == 0 else I_SLEIGH_OFF, short=1)
                if sec == 'BR' or (sec == 'D' and lap == 2):          # (trémolo en semicorcheas)
                    S.NZ['sleigh'].hit(t0 + st * E + S16, 1, I_SLEIGH_OFF, short=1)
    return S


def stems(S):
    st = S.stems()
    n = int(NB * BAR * SR)
    x = tnd_dac(S.NZ['sleigh'].render() / 12241.0)
    x = np.concatenate([x, np.zeros(max(0, n + 3 * SR - len(x)))])[:n + 2 * SR]
    st['sleigh'] = x - np.mean(x[:n])
    return st


# ── Mezcla (la de winter: nivel de cada grupo respecto a la melodía) ─────────
GROUPS = {'lead': ('lead',), 'bass': ('bass',), 'chords': ('chord',), 'bell': ('bell', 'echo'), 'strings': ('str',),
          'arp': ('shim',), 'kick': ('kick',), 'snare': ('snare', 'tom'), 'cymbals': ('hat', 'crash', 'xriser'),
          'sleigh': ('sleigh',)}
LEVEL_DB = {'lead': 0, 'bass': -1, 'kick': 1.5, 'snare': -0.5, 'cymbals': -7, 'chords': -5, 'bell': -4,
            'strings': -9, 'arp': -11, 'sleigh': -11}


def group_of(k):
    return next((g for g, pre in GROUPS.items() if any(k.startswith(p) for p in pre)), None)


def balance(st):
    g = {k: 1.0 for k in st}
    groups = [gr for gr in GROUPS if any(group_of(k) == gr for k in st)]
    lvl = {gr: W.active_rms(sum(st[k] for k in st if group_of(k) == gr)) for gr in groups}
    for gr in groups:
        if lvl[gr] > 0:
            want = lvl['lead'] * 10 ** (LEVEL_DB[gr] / 20)
            for k in st:
                if group_of(k) == gr:
                    g[k] = want / lvl[gr]
    return g


def mixdown(st, g):
    solo = os.environ.get('SOLO')
    keep = set(solo.split(',')) if solo else None
    use = [k for k in st if group_of(k) and (keep is None or any(k.startswith(w) for w in keep))]
    x = sum(st[k] * g[k] for k in use)
    from scipy.signal import butter, sosfilt
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    x = sosfilt(butter(1, 15000, btype='low', fs=SR, output='sos'), x)
    side = np.zeros_like(x)
    for k, p in (('lead_sheen', 0.25), ('chord0', -0.3), ('chord1', 0.3), ('bell1', 0.3), ('echo', -0.4), ('bell5', 0.35),
                 ('shim', 0.25), ('str0', -0.25), ('str1', 0.25), ('hat', 0.2), ('sleigh', -0.3)):
        if k in st and k in use:
            side += st[k] * g[k] * p
    return np.stack([x + side, x - side], 1)


def eq_to(y, ref):
    """La forma del espectro (bandas de octava) hacia la de winter_nes: la misma paleta"""
    mono = y.mean(1)
    n = min(len(mono), len(ref)) / SR
    P, R = band_power(mono, 6, n - 6), band_power(ref, 6, n - 6)
    dev = 10 * np.log10((P / P.sum() + 1e-12) / (R / R.sum() + 1e-12))
    gains = np.clip(-0.6 * dev, -4, 4)
    for (lo, hi), gdb in zip(OCT, gains):
        if abs(gdb) >= 0.5 and hi <= 16000:
            y = biquad(y, 'peak', np.sqrt(lo * hi), gdb, 1.1)
    print('  EQ hacia winter_nes: ' + ' '.join(f'{int(np.sqrt(lo * hi))}Hz {gdb:+.1f}' for (lo, hi), gdb in zip(OCT, gains)))
    return y


def report(y, st, g):
    mono = y.mean(1)
    print('  sonoridad: %.1f LUFS, pico %.3f' % (loudness(y), np.abs(y).max()))
    e = {}
    for k in st:
        gr = group_of(k)
        if gr:
            e[gr] = e.get(gr, 0) + float(np.mean((st[k] * g[k]) ** 2))
    tot = sum(e.values())
    print('  energía: ' + ' '.join(f'{k} {100 * v / tot:.0f}%' for k, v in sorted(e.items(), key=lambda z: -z[1])))
    # ¿Tapa algo a la melodía? (1-5 kHz, por sección: acompañamiento / melodía)
    lead = sum(st[k] * g[k] for k in st if group_of(k) == 'lead')
    rows = []
    for name, a, b in SECT:
        t0, t1 = (a - 1) * BAR, b * BAR
        L = W.band_rms(lead, t0, t1)
        r = {gr: W.band_rms(sum(st[k] * g[k] for k in st if group_of(k) == gr), t0, t1) / max(L, 1e-9)
             for gr in ('bell', 'chords', 'strings', 'arp', 'sleigh')}
        rows.append('%s ' % name + ' '.join('%s %.2f' % (k, v) for k, v in r.items()))
    print('  frente a la melodía (1-5 kHz): ' + ' | '.join(rows))
    lv = [(n, 20 * np.log10(np.sqrt(np.mean(mono[int((a - 1) * BAR * SR):int(b * BAR * SR)] ** 2)))) for n, a, b in SECT]
    lv2 = [(n, 20 * np.log10(np.sqrt(np.mean(mono[int((a + 71) * BAR * SR):int((b + 72) * BAR * SR)] ** 2)))) for n, a, b in SECT]
    m = max(v for _, v in lv + lv2)
    print('  dinámica (dB bajo la sección más fuerte) vuelta 1: ' + ' '.join(f'{n} {v - m:+.1f}' for n, v in lv)
          + ' · vuelta 2: ' + ' '.join(f'{n} {v - m:+.1f}' for n, v in lv2))


if __name__ == '__main__':
    import librosa
    S = build()
    print('  motivo: %d entradas, %d notas de campana; ajustadas al acorde / melodía %d, quitadas %d'
          % (STATS['statements'], STATS['bells'], STATS['moved'], STATS['dropped']))
    print('  cuerdas cambiadas a la raíz por roce con la melodía: %d' % STATS['strings'])
    st = stems(S)
    g = balance(st)
    n = int(NB * BAR * SR)
    y = W.fold_tail(mixdown(st, g), n)
    y = eq_to(y, librosa.load(os.path.join(OUT, 'winter_nes.ogg'), sr=SR, mono=True)[0])
    y = master(y, lufs=-10.0)
    f = int(0.003 * SR)
    y[:f] *= np.linspace(0, 1, f)[:, None]
    y[-f:] *= np.linspace(1, 0, f)[:, None]
    report(y, st, g)
    if not os.environ.get('REPORT') and not os.environ.get('SOLO'):
        wav = os.path.join(OUT, NAME + '.wav')
        write_wav(wav, y)
        W.write_midi(os.path.join(OUT, NAME + '.mid'), S.ev)
        ogg = os.path.join(OUT, NAME + '.ogg')
        os.system(f'ffmpeg -v quiet -y -i "{wav}" -c:a libvorbis -q:a 6 "{ogg}"')
        os.remove(wav)
        print(f'  {ogg}  {len(y) / SR:.2f} s')
    elif os.environ.get('SOLO'):
        write_wav('/tmp/%s_solo.wav' % NAME, y)
