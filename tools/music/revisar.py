#!/usr/bin/env python3
# tools/music/revisar.py — REVISIÓN de una pista de worlds_nes.py con lo que de verdad suena (no con las listas de notas):
#   · captura cada nota que el generador manda a cada canal (melodía, contracanto, acordes, bajo, acento…)
#   · ARMONÍA: notas de la melodía (y del contracanto / la melodía cambiada) que no son del acorde y duran una corchea o
#     más sin resolver por grado; choques de segunda menor / séptima mayor / tritono entre voces que suenan a la vez
#     más de una corchea (incluido contra el bajo y los acordes)
#   · TRANSICIONES: en cada cambio de sección, el acorde y la nota de antes y de después, el salto de la melodía y el
#     del bajo; y el COSIDO del bucle (último compás → primer compás del bucle)
#   · AUDIO del bucle exportado (el .ogg que carga el juego): duración = compases exactos, salto de muestra en la
#     costura, sonoridad de los últimos/primeros 250 ms frente a la media, silencios, y lo mismo en intro → bucle
#   · --pfm: además escribe la pista en PFM (formato del skill pfm-chiptune-composer) para pasarle su validador
#   ~/.venvs/fm-music/bin/python tools/music/revisar.py <pista> [...] [--pfm DIR] [--viejo DIR_DEL_GENERADOR_VIEJO]
import os, sys, importlib
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
NAMES = ('lead', 'echo', 'c1', 'c2', 'bass', 'trill', 'dbl', 'bell', 'cm', 'swap', 'perc')
HARSH = {1: 'm2', 11: 'M7', 6: 'tritono'}


def capture(W, name):
    """→ (eventos [(canal, compás, semicorchea, dur en semicorcheas, midi)], song, kw, audio, n_intro)"""
    kw = dict(W.TRACKS[name])
    made, ev = [], []
    RealChan, real_play = W.Chan, W.play
    class Ch(RealChan):
        def __init__(s, *a, **k):
            super().__init__(*a, **k); made.append(s)
    def play(chn, t0, t1, m, inst, *a, **k):
        ev.append((chn, t0, t1, m)); return real_play(chn, t0, t1, m, inst, *a, **k)
    W.Chan, W.play = Ch, play
    try:
        y, mel, bpm, n_i = W.build(name, **kw)
    finally:
        W.Chan, W.play = RealChan, real_play
    names = {id(c): NAMES[i] for i, c in enumerate(made[:len(NAMES)])}
    s16 = 60.0 / kw['bpm'] / 4
    out = []
    for chn, t0, t1, m in ev:
        q0 = t0 / s16
        q0 = round(q0, 3)
        out.append((names.get(id(chn), '?'), int(q0 // 16) + 1, round(q0 % 16, 2), max(0.25, round((t1 - t0) / s16, 2)), m))
    # (cada canal toca UNA nota a la vez: la siguiente corta a la anterior)
    by, cut = {}, []
    for e in out: by.setdefault(e[0], []).append(e)
    for v, es in by.items():
        es.sort(key=lambda e: (e[1], e[2]))
        for i, (v_, b, st, d, m) in enumerate(es):
            if i + 1 < len(es):
                gap = (es[i + 1][1] - b) * 16 + es[i + 1][2] - st
                if 0 < gap < d: d = round(gap, 2)
            cut.append((v_, b, st, d, m))
    return cut, kw, y, n_i


def chord_at(ch, b, st):
    return ch[b - 1][0 if st < 8 else 1]


def harmony(ev, ch, tag, W, voices=('lead', 'cm', 'swap')):
    """notas no del acorde, largas y sin resolver; y choques entre voces"""
    probs = []
    by = {}
    for v, b, st, d, m in ev: by.setdefault(v, []).append((b, st, d, m))
    for v in voices:
        seq = sorted(by.get(v, []))
        for i, (b, st, d, m) in enumerate(seq):
            if b > len(ch) or tag[b - 1] in ('intro', 'solo'): continue
            r, q = chord_at(ch, b, int(st))
            if (m - r) % 12 in q or d < 2: continue
            nxt = seq[i + 1][3] if i + 1 < len(seq) else None
            resolves = nxt is not None and abs(nxt - m) <= 2 and (nxt - r) % 12 in q
            if d >= 3 or not resolves:
                probs.append((b, st, v, 'nota fuera del acorde %s sobre %s (%s semicorcheas)%s' % (nm(m), cn(r, q), d, '' if resolves else ', sin resolver por grado')))
    # choques verticales (en una rejilla de semicorcheas)
    grid = {}
    for v, b, st, d, m in ev:
        if v in ('echo', 'trill', 'perc') or b > len(tag) or tag[b - 1] == 'intro': continue
        a = (b - 1) * 16 + st
        for k in range(int(round(d))):
            grid.setdefault(int(a + k), []).append((v, m))
    run = {}
    for t in sorted(grid):
        here = grid[t]
        for i in range(len(here)):
            for j in range(i + 1, len(here)):
                (v1, m1), (v2, m2) = here[i], here[j]
                if v1 == v2: continue
                iv = abs(m1 - m2) % 12
                if iv in HARSH and not ({v1, v2} <= {'c1', 'c2', 'bass'}):
                    key = (min(v1, v2), max(v1, v2), min(m1, m2), max(m1, m2))
                    run.setdefault(key, []).append(t)
    for (v1, v2, a, b_), ts in run.items():
        # tramos seguidos de 2+ semicorcheas
        ts = sorted(set(ts)); seg = [ts[0]]
        for t in ts[1:] + [None]:
            if t is not None and t == seg[-1] + 1: seg.append(t); continue
            if len(seg) >= 2:
                bb, st = seg[0] // 16 + 1, seg[0] % 16
                r, q = chord_at(ch, bb, st)
                ok = (a - r) % 12 in q and (b_ - r) % 12 in q
                if not ok: probs.append((bb, st, v1 + '/' + v2, 'choque %s %s–%s (%d semicorcheas) sobre %s' % (HARSH[abs(a - b_) % 12], nm(a), nm(b_), len(seg), cn(r, q))))
            if t is not None: seg = [t]
    return sorted(probs)


def transitions(ev, ch, tag, starts, NB):
    mel = sorted((b, st, d, m) for v, b, st, d, m in ev if v in ('lead', 'swap'))
    bass = sorted((b, st, d, m) for v, b, st, d, m in ev if v == 'bass')
    out = []
    def last(seq, b): x = [s for s in seq if s[0] == b]; return x[-1] if x else None
    def first(seq, b): x = [s for s in seq if s[0] == b]; return x[0] if x else None
    for s0 in starts + ['bucle']:
        if s0 == 'bucle': pb, nb, lab = NB, 5, 'COSIDO DEL BUCLE'
        else:
            if s0 <= 5: continue
            pb, nb, lab = s0 - 1, s0, '%s→%s' % (tag[s0 - 2], tag[s0 - 1])
        lm, fm, lb, fb = last(mel, pb), first(mel, nb), last(bass, pb), first(bass, nb)
        c1, c2 = ch[pb - 1][1], ch[nb - 1][0]
        out.append('  c.%d→%d %-18s acordes %s→%s  melodía %s→%s (%s)  bajo %s→%s' % (
            pb, nb, lab, cn(*c1), cn(*c2), nm(lm[3]) if lm else '—', nm(fm[3]) if fm else '—',
            ('%+d' % (fm[3] - lm[3])) if lm and fm else '', nm(lb[3]) if lb else '—', nm(fb[3]) if fb else '—'))
    return out


def audio(path_loop, path_intro, bars, bpm, sr_want=None):
    import soundfile as sf
    y, sr = sf.read(path_loop); y = y.mean(1) if y.ndim > 1 else y
    bar = 16 * 60.0 / bpm / 4
    res = ['  bucle %.2f s = %.3f compases (esperados %d)' % (len(y) / sr, len(y) / sr / bar, bars)]
    w = int(0.05 * sr)
    rms = lambda x: np.sqrt(np.mean(x ** 2)) + 1e-9
    med = np.median([rms(y[i:i + w]) for i in range(0, len(y) - w, w)])
    end, beg = rms(y[-5 * w:]), rms(y[:5 * w])
    jump = abs(y[0] - y[-1]); typ = np.percentile(np.abs(np.diff(y)), 99)
    res.append('  costura: salto de muestra %.4f (p99 de saltos %.4f) · últimos 250 ms %+.1f dB · primeros 250 ms %+.1f dB (vs mediana)' % (
        jump, typ, 20 * np.log10(end / med), 20 * np.log10(beg / med)))
    # silencios de más de 150 ms
    env = np.array([rms(y[i:i + w]) for i in range(0, len(y) - w, w)])
    quiet = np.where(env < med * 0.05)[0]
    if len(quiet): res.append('  silencios (<-26 dB) en %s s' % sorted(set(round(i * 0.05, 1) for i in quiet))[:12])
    if path_intro and os.path.exists(path_intro):
        z, _ = sf.read(path_intro); z = z.mean(1) if z.ndim > 1 else z
        res.append('  intro → bucle: salto %.4f · intro %.2f s = %.3f compases' % (abs(z[-1] - y[0]), len(z) / sr, len(z) / sr / bar))
    return res


def nm(m):
    return ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'][m % 12] + str(m // 12 - 1)


def cn(r, q):
    return ['C', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'][r % 12] + ('m' if q[1] == 3 else '')


def to_pfm(ev, kw, ch, path, NB, title):
    """la pista (lo que suena) en PFM, una voz por canal, en semicorcheas, para validate_pfm.py del skill"""
    voices = [('lead', 'pulse', 'lead'), ('cm', 'pulse', 'harmony'), ('swap', 'pulse', 'harmony'), ('c1', 'pulse', 'harmony'),
              ('c2', 'pulse', 'harmony'), ('bass', 'triangle', 'bass')]
    L = ['@title %s' % title, '@tempo %d' % kw['bpm'], '@timesig 4/4', '@key C chromatic', '@loop', '@master headroom=-3 limiter=none', '']
    names = 'CDEFGAB'
    def pn(m):
        pc = m % 12; o = m // 12 - 1
        return {0: 'C', 1: 'C#', 2: 'D', 3: 'D#', 4: 'E', 5: 'F', 6: 'F#', 7: 'G', 8: 'G#', 9: 'A', 10: 'A#', 11: 'B'}[pc] + str(o)
    body = []
    for v, wave, role in voices:
        evs = sorted((b, st, d, m) for vv, b, st, d, m in ev if vv == v and b >= 5 and b <= NB)
        if not evs: continue
        L.append('voice %s wave=%s vol=0.2 role=%s range=C0-C8' % (v, wave, role))
        grid = [None] * ((NB - 4) * 16)
        for b, st, d, m in evs:
            a = (b - 5) * 16 + int(round(st))
            for k in range(max(1, int(round(d)))):
                if 0 <= a + k < len(grid) and grid[a + k] is None: grid[a + k] = (m, k == 0)
        bars = []
        for bi in range(NB - 4):
            toks = []
            for k in range(16):
                g = grid[bi * 16 + k]
                toks.append('R:16' if g is None else ('%s:16' % pn(g[0]) if g[1] else '-:16'))
            # (un "-" al principio de compás sigue la nota anterior)
            bars.append(' '.join(toks))
        body.append('%s: %s |' % (v, ' | '.join(bars)))
    open(path, 'w').write('\n'.join(L + [''] + body) + '\n')


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    pfm = sys.argv[sys.argv.index('--pfm') + 1] if '--pfm' in sys.argv else None
    old = sys.argv[sys.argv.index('--viejo') + 1] if '--viejo' in sys.argv else None
    if pfm: args = [a for a in args if a != pfm]
    if old: args = [a for a in args if a != old]
    sys.path.insert(0, old or HERE)
    W = importlib.import_module('worlds_nes')
    import famicom as F
    for name in args:
        ev, kw, y, n_i = capture(W, name)
        mel, ch, tag, starts = W.song(kw.get('variant', 'A'), False, kw.get('solo', False), kw.get('theme'))
        NB = len(ch)
        print('══ %s (%d BPM, %d compases, bucle %d)' % (name, kw['bpm'], NB, NB - 4))
        print('  forma: ' + ' '.join('%d:%s%s' % (s, tag[s - 1], ('[' + W.song.var[s - 1] + ']') if getattr(W.song, 'var', None) and W.song.var[s - 1] else '') for s in [5] + [x for x in starts if x > 5]))
        pr = harmony(ev, ch, tag, W)
        print('  ARMONÍA: %d problemas' % len(pr))
        for b, st, v, msg in pr[:60]: print('    c.%d·%s %s: %s' % (b, st, v, msg))
        print('  TRANSICIONES:'); print('\n'.join(transitions(ev, ch, tag, [x for x in starts], NB)))
        base = F.out(name, 'ogg')[:-4]
        if not old and os.path.exists(base + '_loop.ogg'):
            print('  AUDIO:'); print('\n'.join(audio(base + '_loop.ogg', base + '_intro.ogg', NB - 4, kw['bpm'])))
        if pfm:
            os.makedirs(pfm, exist_ok=True)
            to_pfm(ev, kw, ch, os.path.join(pfm, name + '.pfm'), NB, name)
