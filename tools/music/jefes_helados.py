#!/usr/bin/env python3
# tools/music/jefes_helados.py — los dos jefes helados con el REPARTO GM nuevo (el de las Montañas Heladas,
# montana_nes.py): `snowball_boss` "La Gran Bola" (worlds_nes.py, la Gran Bola de Nieve) y `crab_tantrum_icy` (crab_icy.py,
# el Mega Crabby helado). El usuario (2026-10-29): "rework a la música de la Gran Bola de Nieve y del Icy Mega Crabby de
# forma que solo mejore (si aplica) su estructura musical/ritmo y utilice las nuevas sound fonts para las melodías,
# percusiones y efectos".
#
# CÓMO: la composición NO se toca. Cada generador, con su `EVENTS` puesto, apunta cada nota que manda a cada canal de
# chip, cada golpe de batería y su mezcla (famicom.play / Noise.hit / su hit()); aquí cada CAPA se vuelve a tocar con
# instrumentos GM (montana_nes.Rec: bancos y kits del GeneralUser GS) con las MISMAS notas, tiempos y duraciones, el chip
# de la casa queda debajo donde da carácter (la voz, el bombo DPCM, el bajo slap de los jefes, que ya era GM), y se
# mezcla con los MISMOS niveles por capa que la pista de siempre. Mismas melodías, armonía, tono, tempo, forma y largos.
# (crab_mashup.py lee de crab_icy.py solo las melodías y acordes: no cambia nada.)
#
# Lo que cambia, además del timbre (ver LEEME): fuera el ECO de notas (la misma nota 3 semicorcheas después, y el eco de
# la caja de música del cangrejo) — el usuario acaba de rechazar ese efecto en montana_2 —; reverb "escarcha" (la eligió
# en las dos pistas de las montañas); EFECTOS: platillo al revés que llega a cada sección, viento (bola) / mar y viento
# (cangrejo, la costa helada); RITMO: el redoble de caja de cada entrada lo dobla un redoble de timbal afinado que crece
# (la bola que rueda y se hace grande), los toms de chip pasan a timbales afinados al acorde, y en las partes tranquilas
# del cangrejo un shaker en semicorcheas (la costa).
#
#   ~/.venvs/fm-music/bin/python tools/music/jefes_helados.py [snowball_boss crab_tantrum_icy]
#   → FlappyMonster_pruebas/musica_jefes_helados/ (antes / nuevo / comparación, .ogg y .mp3) · REPORT=1 → números.
#   No instala nada. Se comprueba con números (NO se ha escuchado).
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import famicom as F
from famicom import SR
import tentacle_nes as TN
import gloomy_nes as GN
import worlds_nes as W
import crab_icy as CI
import montana_nes as MN
import gm as GM

PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/musica_jefes_helados'
P = MN   # (los instrumentos: MN.CRYSTAL, MN.CELESTA…)
STEEL, MARIMBA, SEASHORE, SHAKER = 114, 12, (0, 122), 82


class Lay:
    """las grabaciones GM de una capa nueva"""
    def __init__(self):
        self.R = {}

    def add(self, key, prog, t0, t1, n, vel, drums=False, kit=0):
        k = (key, prog, drums, kit)
        if k not in self.R: self.R[k] = MN.Rec(drums=True, kit=kit) if drums else MN.Rec(prog)
        self.R[k].add(max(0.0, t0), max(t0 + 0.01, t1), int(n), int(max(1, min(127, vel))))

    def stems(self, L, n, n_i):
        out = {}
        for (key, prog, drums, kit), r in self.R.items():
            y = GM.cached(r, L)
            y = np.concatenate([y[MN.GM_LAT:], np.zeros(MN.GM_LAT)])
            out[key] = out.get(key, 0) + y
        return {k: GN.fold(v, n, n_i) for k, v in out.items()}


def chord_at(mx, t):
    b = int(t / mx['BAR']) + 1
    b = min(max(b, 1), len(mx['ch']))
    st = (t - (b - 1) * mx['BAR']) / mx['S16']
    return mx['ch'][b - 1][0 if st < 8 else 1]


def low(r, lo=40):
    return lo + (r - lo) % 12


def tom_index(smp):
    return next((i for i, x in enumerate(W.TOMS) if x is smp), 2)


def rescale(x, ref):
    """x al RMS de ref (para dejar el chip DEBAJO del GM con una proporción fija)"""
    a, b = GN.rms_on(x), GN.rms_on(ref)
    return x * (b / a) if a > 0 else x


def common_drums(E, mx, Lz, snare_kit=MN.K_ORCH):
    """la batería de siempre, golpe a golpe, con instrumentos GM: caja de orquesta, cascabeles, platillos, timbales
    afinados al acorde (eran toms de chip), bombo de concierto en los tiempos 1"""
    BAR, S16 = mx['BAR'], mx['S16']
    for t, per, vols, short in E.get('nz_snare', []):
        v = vols[0] if vols else 6
        Lz.add('snare', 0, t, t + 0.12, MN.SN, 30 + 5.5 * v, drums=True, kit=snare_kit)
    for t, per, vols, short in E.get('nz_hat', []):
        v = vols[0] if vols else 3
        Lz.add('hat', 0, t, t + 0.12, MN.JINGLE, 26 + 11 * v, drums=True)
    for t, per, vols, short in E.get('nz_crash', []):
        full = len(vols) >= 10
        Lz.add('crash', 0, t, t + 1.5, MN.CRASH_GM, 96 if full else 74, drums=True, kit=MN.K_ORCH)
    for t, g, smp in E.get('buf_toms', []):
        r, q = chord_at(mx, t)
        i = tom_index(smp)
        Lz.add('toms', MN.TIMPANI, t, t + 0.25, low(r) + (12, 7, 0)[i], 62 + 44 * min(1.0, g))
    for t, g, smp in E.get('buf_kick', []):
        st = (t % BAR) / S16
        if abs(st) < 0.01 or abs(st - 8) < 0.01:
            Lz.add('kick', MN.CONCERT_BD, t, t + 0.3, 36, 58 + 34 * min(1.0, g) * (1.0 if st < 1 else 0.7))


def entry_rolls(mx, Lz, last_bars, vel0=58):
    """el redoble de entrada, doblado por un timbal afinado a la raíz de lo que viene, que crece (semicorcheas 12-15)"""
    BAR, S16, ch = mx['BAR'], mx['S16'], mx['ch']
    for b in last_bars:
        nxt = ch[b % len(ch)][0] if b < len(ch) else ch[len(ch) - len(ch) + mx['n_i_bars']][0]
        for st in range(8, 16):
            t = (b - 1) * BAR + st * S16
            Lz.add('toms', MN.TIMPANI, t, t + S16 * 0.9, low(nxt[0]), vel0 + 7 * (st - 8))


def rev_cyms(mx, Lz, bars, vel=80):
    for b in bars:
        t = (b - 1) * mx['BAR']
        Lz.add('revcym', MN.REV_CYM, t - 1.35, t + 0.1, 60, vel)


def mixdown(S, g, mx, side_w, send_w, env=None, wet=0.4, rt=1.4, ceiling=0.7):
    from scipy.signal import butter, sosfilt
    x = sum(S[k] * g[k] for k in S)
    x = sosfilt(butter(1, 30, btype='high', fs=SR, output='sos'), x)
    side = sum(S[k] * g[k] * w for k, w in side_w.items() if k in S)
    send = sum(S[k] * g[k] * w for k, w in send_w.items() if k in S)
    if env is not None: x, side, send = x * env, side * env, send * env
    n, n_i = mx['n'], mx['n_i']
    pad = np.zeros(3 * SR)
    rl, rr = MN.frost(np.concatenate([send, pad]), rt=rt)
    Lx = np.concatenate([x + side, pad]) + wet * rl
    Rx = np.concatenate([x - side, pad]) + wet * rr
    y = np.stack([GN.fold(Lx, n, n_i), GN.fold(Rx, n, n_i)], 1)            # (la cola de la reverb, al principio del bucle)
    return F.master(y, lufs=mx['lufs'], ceiling=ceiling)                    # (con 0,8 el OGG pasaba de 1,0 en el cangrejo)


# ══ LA GRAN BOLA (snowball_boss) — helado ════════════════════════════════════════════════════════════════════════
# OPCIONES DE LA MELODÍA (2026-10-29, el usuario: "en ambos se debe optar por un instrumento diferente para la melodía
# principal: el de la Giant Ball le quita potencia, y al Crabby lo pone algo tropical, que contrasta con el lugar").
# Cada opción: [(capa, programa, transporte, velocidad)] — la 1ª capa es 'lead', la 2ª 'lead2' (a LEAD2_DB de ella);
# chip = cuánto pulso / voz de chip queda debajo (proporción de su RMS).
LEAD2_DB = -5
LEADS = {
    'snowball_boss': {
        1: ('metales', [('lead', 61, 0, 108), ('lead2', 60, -12, 100)], 0.45),            # metales + trompas una 8ª abajo
        2: ('sierra_cuerdas', [('lead', 81, 0, 100), ('lead2', 48, 0, 104)], 0.4),        # sierra + cuerdas rápidas
        3: ('metal_sinte', [('lead', 62, 0, 108), ('lead2', 80, 12, 78)], 0.45),          # metal sintético + cuadrada una 8ª arriba
    },
    'crab_tantrum_icy': {
        1: ('cristal_cuerdas', [('lead', 98, 0, 104), ('lead2', 48, 0, 98)], 0.35),       # Crystal + cuerdas rápidas
        2: ('cuerdas_vidrio', [('lead', 48, 0, 108), ('lead2', 92, 12, 84)], 0.45),       # cuerdas + vidrio frotado una 8ª arriba
        3: ('cuadrada_fria', [('lead', 80, 0, 92), ('lead2', 50, 0, 100)], 0.35),         # onda cuadrada + cuerdas sintéticas
    },
}


def recast_snowball(lead=None):
    E = {}
    W.EVENTS = E
    kw = dict(W.TRACKS['snowball_boss'])
    y_old, mel, bpm, n_i = W.build('snowball_boss', **kw)
    W.EVENTS = None
    mx = E['_mix']
    S0, LV, n = mx['S'], mx['LV'], mx['n']
    nb_i = n_i / (mx['BAR'] * SR)
    mx['n_i_bars'] = int(round(nb_i))
    L = n + 5 * SR
    Lz = Lay()
    # LA MELODÍA: "Crystal" (campana con cuerpo) + el pulso de chip debajo; la caja de música una 8ª arriba → celesta
    for t0, t1, m, inst, vs in E['lead']:
        if lead == 'chip': break                                     # (LEAD_CHIP: la voz de chip de siempre, tal cual)
        if lead:
            for key, prog, tr, vel in lead[1]: Lz.add(key, prog, t0, t1, m + tr, vel)
        else: Lz.add('lead', MN.CRYSTAL, t0, t1, m, 104)
    for t0, t1, m, inst, vs in E['bell']:
        Lz.add('bell', MN.CELESTA, t0, t1, m, 86)
    for t0, t1, m, inst, vs in E['dbl']:
        Lz.add('dbl', MN.GLOCK, t0, min(t1, t0 + 0.2), m, 64)
    for t0, t1, m, inst, vs in E['cm']:                                       # el contracanto (N163) → coro
        Lz.add('cm', MN.CHOIR, t0, t1, m, 80)
    for t0, t1, m, inst, vs in E['c1'] + E['c2']:                            # acordes a contratiempo / golpes → pizzicato
        Lz.add('chords', MN.PIZZ, t0, t0 + 0.14, m, 84 if inst is W.I_STAB else 72)
    for t0, t1, m, inst, vs in E['trill']:                                    # el acento (tres notas del acorde) → glockenspiel
        Lz.add('trill', MN.GLOCK, t0, t1, m, 66)
    common_drums(E, mx, Lz)
    # EFECTOS y el redoble de timbal en cada entrada de sección (y hacia el bucle)
    starts = mx['starts']
    last_bars = [s - 1 for s in starts[1:]] + [len(mx['ch'])]
    entry_rolls(mx, Lz, last_bars)
    rev_cyms(mx, Lz, [s for s in starts[1:]] + [len(mx['ch']) + 1], 82)
    BAR = mx['BAR']
    Lz.add('wind', MN.WIND, 0.0, 4 * BAR, 60, 92)                            # la ventisca en la intro
    b_b = starts[3] if len(starts) > 3 else None                             # (B: el puente)
    if b_b: Lz.add('wind', MN.WIND, (b_b - 1) * BAR, (b_b + 3) * BAR, 60, 84)
    G = Lz.stems(L, n, n_i)
    S = {'lead': S0['lead'] if lead == 'chip' else G['lead'] + (lead[2] if lead else 0.35) * rescale(S0['lead'], G['lead']),
         'bell': G['bell'], 'chords': G['chords'] + 0.3 * rescale(S0['chords'], G['chords']),
         'trill': G['trill'], 'bass': S0['bass'], 'kick': S0['kick'] + 0.6 * rescale(G['kick'], S0['kick']),
         'snare': G['snare'] + 0.45 * rescale(S0['snare'], G['snare']), 'hat': G['hat'], 'crash': G['crash'], 'toms': G['toms'],
         'revcym': G['revcym'], 'wind': G['wind']}
    if 'cm' in G: S['cm'] = G['cm']
    if 'dbl' in G: S['dbl'] = G['dbl']
    if 'lead2' in G: S['lead2'] = G['lead2']
    S = {k: v for k, v in S.items() if np.abs(v).max() > 0}
    lv = dict(LV); lv.update({'revcym': -9, 'wind': -12, 'toms': LV.get('toms', 0) - 1, 'lead2': LV['lead'] + LEAD2_DB})
    g = GN.level(S, {k: lv.get(k, -10) for k in S}, 'lead')
    y = mixdown(S, g, mx, {'chords': 0.35, 'trill': 0.4, 'hat': 0.3, 'bell': 0.25, 'cm': -0.2, 'revcym': 0.3},
                {'lead': 0.0 if lead == 'chip' else 0.18, 'lead2': 0.25, 'bell': 0.35, 'cm': 0.4, 'chords': 0.2, 'trill': 0.3,
                 'dbl': 0.3, 'toms': 0.12})                          # (la voz de chip, SECA: la reverb, en lo GM de alrededor)
    return dict(id='snowball_boss', y=y, y_old=y_old, S=S, g=g, mx=mx, n=n, n_i=n_i, mel=mel, E=E)


# ══ EL MEGA CRABBY HELADO (crab_tantrum_icy) — helado y de costa ═════════════════════════════════════════════════
def recast_crab(lead=None):
    E = {}
    CI.EVENTS = E
    y_old, mel, n_i = CI.build()
    CI.EVENTS = None
    mx = E['_mix']
    S0, LV, n = mx['S'], mx['LV'], mx['n']
    mx['n_i_bars'] = CI.INTRO
    L = n + 5 * SR
    BAR, S16, tag, starts = mx['BAR'], mx['S16'], mx['tag'], mx['starts']
    Lz = Lay()
    # LA VOZ: vibráfono (hielo) + steel drum (la costa) y la voz suave del N163 debajo; en el respiro (voz suave una
    # 8ª abajo) → voces "ooh"
    for t0, t1, m, inst, vs in E['lead']:
        if inst is CI.I_SOFTV:
            Lz.add('lead', MN.OOHS, t0, t1, m, 76)
        elif lead == 'chip':                                           # (la voz de chip de siempre: va en S0['lead'])
            continue
        elif lead:                                                     # (opciones: sin steel drum ni vibráfono)
            for key, prog, tr, vel in lead[1]: Lz.add(key, prog, t0, t1, m + tr, vel)
        else:
            Lz.add('lead', MN.VIBES, t0, t1, m, 102)
            Lz.add('steel', STEEL, t0, t1, m, 72)
    for t0, t1, m, inst, vs in E['bell']:                                     # la caja de música (y el contrapunto) → la GM
        Lz.add('bell', MN.MUSICBOX, t0, t1, m, 92)
    for t0, t1, m, inst, vs in ([] if lead == 'chip' else E['dbl']):   # (con la voz de chip, su octava de pulso también)
        Lz.add('dbl', MN.GLOCK, t0, min(t1, t0 + 0.2), m, 66)
    for t0, t1, m, inst, vs in E['p1'] + E['p2']:
        Lz.add('choir', MN.CHOIR, t0, t1, m, int(64 + 16 * vs))
    for t0, t1, m, inst, vs in E['c1'] + E['c2']:                            # golpes de quinta → pizzicato (+ el chip)
        Lz.add('stabs', MN.PIZZ, t0, t0 + 0.16, m, 92)
    for t0, t1, m, inst, vs in E['ice']:                                      # campanillas del tresillo → campanas
        Lz.add('ice', (12, 10), t0, t1, m, 78)
    for t0, t1, m, inst, vs in E['shim']:                                     # arpegio en semicorcheas → marimba (la costa)
        Lz.add('shim', MARIMBA, t0, t1, m, 70)
    common_drums(E, mx, Lz)
    # RITMO: shaker en semicorcheas en las partes tranquilas (B) y en el respiro desde su 5º compás
    NB = len(mx['ch'])
    for b in range(1, NB + 1):
        kind = tag[b - 1]
        k = b - starts[CI.ORDER.index(kind)] + 1
        if kind in CI.CALM or (kind == 'K' and k >= 5):
            for st in range(16):
                t = (b - 1) * BAR + st * S16
                Lz.add('shaker', 0, t, t + S16, SHAKER, 66 if st % 4 == 2 else 44, drums=True)
    last_bars = [s - 1 for s in starts[1:]] + [NB]
    entry_rolls(mx, Lz, [b for b in last_bars if tag[b - 1] not in ('IN', 'K')])
    # EFECTOS: la subida de ruido hacia el tema (intro y respiro) → platillo al revés + el MAR que crece; platillo al
    # revés en cada sección; el viento bajo el respiro
    fx = E.get('nz_fx', [])
    runs, cur = [], []
    for ev in fx:
        if cur and ev[0] - cur[-1][0] > 0.05: runs.append(cur); cur = []
        cur.append(ev)
    if cur: runs.append(cur)
    for r_ in runs:
        t_end = r_[-1][0] + 1 / 60.0
        Lz.add('revcym', MN.REV_CYM, t_end - 1.35, t_end + 0.1, 60, 88)
        Lz.add('sea', SEASHORE, r_[0][0], t_end + 0.5, 60, 96)
    rev_cyms(mx, Lz, [s for s in starts[1:] if tag[s - 1] not in ('A', 'A3')], 78)
    Lz.add('sea', SEASHORE, 0.0, 4 * BAR, 60, 70)
    kb = starts[CI.ORDER.index('K')]
    Lz.add('wind', MN.WIND, (kb - 1) * BAR, (kb + 7) * BAR, 60, 80)
    G = Lz.stems(L, n, n_i)
    if lead == 'chip':
        # la voz de chip del tema tal cual; en el RESPIRO (K) su voz suave una 8ª abajo calla: allí cantan las voces "ooh"
        mask = np.ones(n)
        kb0 = int((kb - 1) * BAR * SR); kb1 = int((kb + 7) * BAR * SR); f_ = int(0.01 * SR)
        mask[kb0:kb1] = 0.0
        mask[kb0 - f_:kb0] = np.linspace(1, 0, f_); mask[kb1:kb1 + f_] = np.linspace(0, 1, f_)
        chip_lead = S0['lead'] * mask
        G['lead'] = G['lead'] if 'lead' in G else 0 * chip_lead
    S = {'lead': (chip_lead + G['lead']) if lead == 'chip' else G['lead'] + (lead[2] if lead else 0.35) * rescale(S0['lead'], G['lead']), 'steel': G.get('steel', 0 * G['lead']), 'bell': G['bell'], 'choir': G['choir'],
         'stabs': G['stabs'] + 0.35 * rescale(S0['stabs'], G['stabs']), 'ice': G['ice'], 'shim': G['shim'], 'bass': S0['bass'],
         'kick': S0['kick'] + 0.6 * rescale(G['kick'], S0['kick']), 'snare': G['snare'] + 0.45 * rescale(S0['snare'], G['snare']),
         'hat': G['hat'], 'crash': G['crash'], 'toms': G['toms'], 'shaker': G['shaker'], 'revcym': G['revcym'],
         'sea': G['sea'], 'wind': G['wind']}
    if 'dbl' in G: S['dbl'] = G['dbl']
    if lead == 'chip': S['dbl'] = S0['dbl']
    if 'lead2' in G: S['lead2'] = G['lead2']
    S = {k: v for k, v in S.items() if np.abs(v).max() > 0}
    lv = dict(LV); lv.update({'lead2': LV['lead'] + LEAD2_DB, 'steel': -6, 'shaker': -9, 'revcym': -9, 'sea': -13, 'wind': -14, 'toms': LV.get('toms', 0) - 1})
    g = GN.level(S, {k: lv.get(k, -10) for k in S}, 'lead')
    y = mixdown(S, g, mx, {'ice': 0.5, 'shim': 0.5, 'choir': 0.4, 'hat': 0.3, 'steel': -0.3, 'shaker': 0.35, 'sea': 0.4},
                {'lead': 0.0 if lead == 'chip' else 0.18, 'lead2': 0.25, 'bell': 0.35, 'choir': 0.4, 'stabs': 0.15, 'ice': 0.3, 'shim': 0.25, 'dbl': 0.3, 'toms': 0.12,
                 'steel': 0.2}, env=mx['env'][:n], ceiling=0.64 if lead == 'chip' else 0.7)    # (la voz de chip: el ogg subía a 0,92)
    return dict(id='crab_tantrum_icy', y=y, y_old=y_old, S=S, g=g, mx=mx, n=n, n_i=n_i, mel=mel, E=E)


# ══ NÚMEROS ══════════════════════════════════════════════════════════════════════════════════════════════════════
def installed(tid):
    import soundfile as sf
    a, _ = sf.read(os.path.join(F.MUSIC_DIR, 'bosses', tid + '_intro.ogg'))
    b, _ = sf.read(os.path.join(F.MUSIC_DIR, 'bosses', tid + '_loop.ogg'))
    return a, b


def report(r):
    mx, y, S, g, n, n_i = r['mx'], r['y'], r['S'], r['g'], r['n'], r['n_i']
    bar = mx['BAR'] * SR
    print(f'── {r["id"]} (reparto GM)')
    a, b = installed(r['id'])
    m = min(len(b), len(r['y_old']) - n_i)
    c = np.corrcoef(b[:m].ravel(), r['y_old'][n_i:n_i + m].ravel())[0, 1]
    print(f'  la de siempre: intro {len(a)} + bucle {len(b)} muestras; el generador la reproduce (correlación con el '
          f'.ogg instalado {c:.4f})')
    print(f'  nueva: {mx["bpm"]} BPM, intro {n_i} muestras ({n_i / bar:.4f} compases, {n_i / SR:.2f} s) + bucle {n - n_i} muestras '
          f'({(n - n_i) / bar:.4f} compases, {(n - n_i) / SR:.2f} s) — iguales que la de siempre: '
          f'{"sí" if (n_i, n - n_i) == (len(a), len(b)) else "NO"}; {F.loudness(y):.1f} LUFS (antes {F.loudness(np.concatenate([a, b])):.1f}), pico {np.abs(y).max():.2f}')
    tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
    print('  energía: ' + ' '.join(f'{k} {100 * np.mean((S[k][:n] * g[k]) ** 2) / tot:.1f}' for k in sorted(S, key=lambda k: -np.mean((S[k][:n] * g[k]) ** 2))))
    st = [(s - 1) * bar for s in mx['starts'][2:]]
    ln, bars, jr, dbs, ji, dbi = MN.seam_numbers(y, n_i, bar, st)
    print(f'  BUCLE: {ln} muestras = {bars:.4f} compases; costura (fin → principio): salto {jr:.2f}× el mayor de los otros '
          f'tiempos 1 de sección, {dbs:+.1f} dB; intro → bucle {ji:.2f}×, {dbi:+.1f} dB')
    # sonoridad por sección, antes y ahora (la forma y la dinámica no cambian)
    old = np.concatenate([a, b])
    dbf = lambda z, i0, i1: 10 * np.log10(np.mean(z[i0:i1] ** 2) + 1e-12)
    s_ = mx['starts'] + [len(mx['ch']) + 1]
    rows = []
    for i, s0 in enumerate(s_[:-1]):
        i0, i1 = int((s0 - 1) * bar), int((s_[i + 1] - 1) * bar)
        rows.append(f'{mx["tag"][s0 - 1]} {dbf(old, i0, i1) - dbf(old, 0, len(old)):+.1f}/{dbf(y, i0, i1) - dbf(y, 0, len(y)):+.1f}')
    print('  sonoridad por sección vs la media (dB, antes/ahora): ' + ' '.join(rows))
    return dict(jr=jr, dbs=dbs, lufs=F.loudness(y), corr=c, same=(n_i, n - n_i) == (len(a), len(b)), ln=ln, bars=bars)


def enc_both(x, base):
    MN.enc(x, base + '.ogg')
    os.system(f'ffmpeg -v quiet -y -i "{base}.ogg" -codec:a libmp3lame -q:a 3 "{base}.mp3"')


README = """LOS JEFES HELADOS CON LOS INSTRUMENTOS NUEVOS — previas antes / ahora (2026-10-29)
=================================================================================

NO SE HA ESCUCHADO: todo se ha comprobado solo con números (abajo). Tu oído manda. Nada está instalado.
Generador: tools/music/jefes_helados.py (vuelve a tocar las mismas notas de worlds_nes.py y crab_icy.py).
Cada archivo va en .ogg y en .mp3 (para escucharlo desde el Mac).

  <pista>_ANTES_preview     la de siempre (la instalada): intro + bucle dos veces
  <pista>_NUEVO_preview     la nueva: intro + bucle dos veces
  <pista>_NUEVO_intro/_loop como se instalaría
  <pista>_comparacion       los 16 primeros compases de la de siempre y, seguidos, los mismos 16 de la nueva

LO QUE NO CAMBIA: las melodías, la armonía, el tono, el tempo, la forma (secciones y compases) y los largos de la intro
y del bucle (al compás y a la muestra). El Mega Mashup de los Cangrejos no se entera: lee de crab_icy.py las melodías
y acordes, que siguen igual. No hacía falta tocar la estructura: las dos se aprobaron así (la del cangrejo es la v3
"definitiva"); lo que mejora el ritmo va en la batería (abajo).

LO QUE CAMBIA EN LAS DOS
- Los instrumentos: cada capa toca las MISMAS notas con un instrumento del soundfont (los de las Montañas Heladas), el
  chip de la casa queda debajo donde da carácter (la voz, el bombo DPCM; el bajo slap de los jefes ya era así).
- Batería GM golpe a golpe: caja de orquesta, cascabeles, platillos de verdad; los toms de chip → TIMBALES afinados al
  acorde; bombo de concierto bajo el bombo de chip en los tiempos 1 y 3.
- RITMO: cada redoble de entrada lo dobla un redoble de timbal afinado a lo que viene, que crece (más empuje en las
  costuras y en la vuelta del bucle).
- EFECTOS: platillo al revés que llega a cada sección; reverb "escarcha" (la que elegiste en las montañas).
- FUERA el ECO DE NOTAS (la misma nota 3 semicorcheas después; y en el cangrejo el eco de la caja de música): es el
  "efecto de notas con retraso" que quitaste de montana_2. Si en estos dos te gustaba, se vuelve a poner.

snowball_boss "La Gran Bola" (Fa menor, 168) — HELADO
  melodía: "Crystal" + el pulso de chip debajo · caja de música → celesta una 8ª arriba · contracanto → coro ·
  acordes a contratiempo y golpes → pizzicato · el acento (tres notas que bajan) → glockenspiel · viento en la intro
  y bajo el puente B.
crab_tantrum_icy (Re menor, 186) — HELADO Y DE COSTA (la Costa Helada)
  voz: vibráfono + steel drum (la costa) + la voz de chip debajo; en el respiro, voces "ooh" · caja de música → la GM
  (también el contrapunto) · coro → coro GM · golpes de quinta → pizzicato (+ chip) · campanillas → campanas de Navidad
  · arpegio en semicorcheas → marimba · el MAR (olas) en la intro y donde subía el ruido hacia el tema, viento en el
  respiro · RITMO: shaker en semicorcheas en B y en la 2ª mitad del respiro.

LOS NÚMEROS
-----------
"""


def options(which):
    """OPCIONES=1: las tres melodías de cada jefe → PRUEBAS/opciones_melodia/ (comparación 16 compases + previa entera)"""
    out = os.path.join(PRUEBAS, 'opciones_melodia')
    os.makedirs(out, exist_ok=True)
    nums = []
    for tid in which:
        a, b = installed(tid)
        old = np.concatenate([a, b])
        for i, (name, layers, chip) in LEADS[tid].items():
            r = (recast_snowball if tid == 'snowball_boss' else recast_crab)((name, layers, chip))
            print(f'  opción {i} "{name}"')
            x = report(r)
            S, g, n = r['S'], r['g'], r['n']
            tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
            share = 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ('lead', 'lead2') if k in S) / tot
            nums.append(f'{tid}_lead_{i}_{name}: intro {r["n_i"] / SR:.2f} s + bucle {(r["n"] - r["n_i"]) / SR:.2f} s ({x["bars"]:.4f} '
                        f'compases; iguales que antes: {"sí" if x["same"] else "NO"}), {x["lufs"]:.1f} LUFS, pico {np.abs(r["y"]).max():.2f}, '
                        f'melodía (sus dos capas) {share:.0f} % de la energía')
            if os.environ.get('REPORT'): continue
            y, n_i = r['y'], r['n_i']
            base = os.path.join(out, f'{tid}_lead_{i}_{name}')
            k16 = int(16 * r['mx']['BAR'] * SR)
            enc_both(np.concatenate([old[:k16], np.zeros((int(0.6 * SR), 2)), y[:k16]]), base + '_comparacion')
            enc_both(np.concatenate([y, y[n_i:]]), base + '_preview')
    return nums


OPT_README = """

OPCIONES DE LA MELODÍA PRINCIPAL (carpeta opciones_melodia/) — tras tu veredicto: "en ambos se debe optar por un
instrumento diferente para la melodía principal: el de la Giant Ball le quita potencia, y al Crabby lo pone algo
tropical". Solo cambia el instrumento de la MELODÍA; todo lo demás (batería, timbales, platillos al revés, reverb, el
resto del reparto, sin el eco) sigue como en NUEVO. NO SE HA ESCUCHADO.
  <pista>_lead_<n>_<nombre>_comparacion   16 compases de la de siempre y los mismos 16 con esa melodía
  <pista>_lead_<n>_<nombre>_preview       la pista entera: intro + bucle dos veces
snowball_boss (con potencia y helado; el pulso de chip debajo, más fuerte que antes):
  1 metales         Brass Section + trompas (French Horns) una 8ª abajo
  2 sierra_cuerdas  Saw Lead + cuerdas rápidas (Fast Strings) al unísono
  3 metal_sinte     Synth Brass 1 + Square Lead una 8ª arriba (brillo frío)
crab_tantrum_icy (helado y amenazante; sin steel drum ni vibráfono; lo de costa queda en el fondo: las olas, la
marimba del arpegio; la voz de chip debajo):
  1 cristal_cuerdas Crystal + cuerdas rápidas (Fast Strings)
  2 cuerdas_vidrio  cuerdas rápidas + vidrio frotado (Bowed Glass) una 8ª arriba
  3 cuadrada_fria   Square Lead + cuerdas sintéticas (Synth Strings 1)
(el respiro K del cangrejo sigue con las voces "ooh": es la voz suave una 8ª abajo, no la melodía principal)
"""


CHIP_README = """

LA MELODÍA CON EL CHIP DE SIEMPRE (carpeta lead_chip/) — tu decisión: "volver a usar los instrumentos chiptune para
las melodías principales de ambas canciones; de esa manera se conserva la esencia original del juego". NO SE HA
ESCUCHADO. La voz principal es la de la pista instalada, nota a nota y con su mismo sonido, octava, envolventes y nivel
respecto al resto (el de siempre): la Gran Bola, el PULSO del 2A03; el cangrejo, la VOZ SUAVE del N163 y, en el último
estribillo, su octava de pulso. Todo lo demás, como en NUEVO (batería GM y timbales, platillos al revés, reverb, el
reparto GM de acompañamiento, sin el eco; el cangrejo sin steel drum ni vibráfono, y en el respiro las voces "ooh").
La voz de chip va SECA (sin reverb: así conserva el golpe; la reverb queda en lo GM de alrededor).
  <pista>_lead_chip_comparacion   16 compases de la de siempre y los mismos 16 nuevos
  <pista>_lead_chip_preview       intro + bucle dos veces
  <pista>_lead_chip_intro/_loop   como se instalaría
"""


V2_README = """

lead_chip_v2/ (2026-10-29) — lo mismo que lead_chip/ con tu corrección: "retirar efecto eco en instrumentos de fondo y
hacer que los 'shakers' que hacen de 'nevada' suenen bien, es decir, a tiempo". ECO: estas dos ya no llevaban ninguno
(el eco de notas se quitó en el rework; la reverb no es eco). NEVADA: los cascabeles GM ya caían en su sitio, pero la
CAJA y el resto del chip que quedan debajo salían de la pista de siempre con los golpes de ruido redondeados al frame
(hasta ±8 ms); ahora los cascabeles de ruido de la pista de siempre van a su muestra (famicom.Noise.exact) y los GM,
a la rejilla exacta. Nombres: <pista>_lead_chip_* como en lead_chip/. NO SE HA ESCUCHADO.
"""


if __name__ == '__main__' and os.environ.get('LEAD_CHIP'):
    SUB = os.environ.get('SUB', 'lead_chip')                # (lead_chip_v2: los cascabeles a tiempo, 2026-10-29)
    out = os.path.join(PRUEBAS, SUB)
    os.makedirs(out, exist_ok=True)
    nums = []
    for tid in ('snowball_boss', 'crab_tantrum_icy'):
        r = (recast_snowball if tid == 'snowball_boss' else recast_crab)('chip')
        x = report(r)
        S, g, n, y, n_i = r['S'], r['g'], r['n'], r['y'], r['n_i']
        tot = sum(np.mean((S[k][:n] * g[k]) ** 2) for k in S)
        share = 100 * sum(np.mean((S[k][:n] * g[k]) ** 2) for k in ('lead', 'dbl') if k in S) / tot
        nums.append(f'{tid}_lead_chip: intro {n_i / SR:.2f} s + bucle {(n - n_i) / SR:.2f} s ({x["bars"]:.4f} compases; iguales que '
                    f'antes: {"sí" if x["same"] else "NO"}), {x["lufs"]:.1f} LUFS, pico {np.abs(y).max():.2f}, voz de chip {share:.0f} % de la energía')
        if os.environ.get('REPORT'): continue
        a, b = installed(tid)
        base = os.path.join(out, f'{tid}_lead_chip')
        MN.J.export(y, n_i, base)
        for suf in ('_intro', '_loop'):
            os.system(f'ffmpeg -v quiet -y -i "{base}{suf}.ogg" -codec:a libmp3lame -q:a 3 "{base}{suf}.mp3"')
        k16 = int(16 * r['mx']['BAR'] * SR)
        enc_both(np.concatenate([np.concatenate([a, b])[:k16], np.zeros((int(0.6 * SR), 2)), y[:k16]]), base + '_comparacion')
        enc_both(np.concatenate([y, y[n_i:]]), base + '_preview')
    if not os.environ.get('REPORT') and SUB == 'lead_chip':
        p_ = os.path.join(PRUEBAS, 'LEEME.txt')
        txt = open(p_).read().split('\n\nLA MELODÍA CON EL CHIP DE SIEMPRE')[0]
        with open(p_, 'w') as f:
            f.write(txt + CHIP_README + '\nLOS NÚMEROS (lead_chip)\n' + '\n'.join(nums) + '\n')
    elif not os.environ.get('REPORT'):
        with open(os.path.join(PRUEBAS, 'LEEME.txt'), 'a') as f:
            f.write(V2_README + '\nLOS NÚMEROS (' + SUB + ')\n' + '\n'.join(nums) + '\n')
    sys.exit(0)

if __name__ == '__main__' and os.environ.get('OPCIONES'):
    nums = options([a for a in sys.argv[1:] if a in LEADS] or list(LEADS))
    if not os.environ.get('REPORT'):
        p_ = os.path.join(PRUEBAS, 'LEEME.txt')
        txt = open(p_).read().split('\n\nOPCIONES DE LA MELODÍA')[0]
        with open(p_, 'w') as f:
            f.write(txt + OPT_README + '\nLOS NÚMEROS DE LAS OPCIONES\n' + '\n'.join(nums) + '\n')
    sys.exit(0)

if __name__ == '__main__':
    which = [a for a in sys.argv[1:] if a in ('snowball_boss', 'crab_tantrum_icy')] or ['snowball_boss', 'crab_tantrum_icy']
    os.makedirs(PRUEBAS, exist_ok=True)
    nums = []
    for tid in which:
        r = recast_snowball() if tid == 'snowball_boss' else recast_crab()
        x = report(r)
        nums.append(f'{tid}: intro {r["n_i"] / SR:.2f} s + bucle {(r["n"] - r["n_i"]) / SR:.2f} s ({x["bars"]:.4f} compases; iguales que antes: '
                    f'{"sí" if x["same"] else "NO"}), {x["lufs"]:.1f} LUFS; costura del bucle: salto {x["jr"]:.2f}× el de un tiempo 1 '
                    f'de sección, {x["dbs"]:+.1f} dB')
        if os.environ.get('REPORT'): continue
        y, n_i = r['y'], r['n_i']
        a, b = installed(tid)
        base = os.path.join(PRUEBAS, tid)
        J = MN.J
        J.export(y, n_i, base + '_NUEVO')
        for suf in ('_NUEVO_intro', '_NUEVO_loop'):
            os.system(f'ffmpeg -v quiet -y -i "{base}{suf}.ogg" -codec:a libmp3lame -q:a 3 "{base}{suf}.mp3"')
        enc_both(np.concatenate([y, y[n_i:]]), base + '_NUEVO_preview')
        enc_both(np.concatenate([a, b, b]), base + '_ANTES_preview')
        k16 = int(16 * r['mx']['BAR'] * SR)
        old = np.concatenate([a, b])
        gap = np.zeros((int(0.6 * SR), 2))
        enc_both(np.concatenate([old[:k16], gap, y[:k16]]), base + '_comparacion')
    if not os.environ.get('REPORT') and len(which) == 2:
        with open(os.path.join(PRUEBAS, 'LEEME.txt'), 'w') as f:
            f.write(README + '\n'.join(nums) + '\n')
        print(f'  previas en {PRUEBAS}')
