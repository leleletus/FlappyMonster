#!/usr/bin/env python3
# tools/music/groove_chart.py — el CHART del duelo de ritmo del Cangrejo Groove, sacado de la MISMA partitura que el tema instalado
# (groove_mejora.py, variante B): si cambian las notas, el generador se para (falta el patrón de un compás nuevo) y no se desincronizan.
#   full    (Difícil, Extremo, Xtra) 1:1 con el bajo slap, nota a nota (el usuario: "debe ser 1:1")
#   normal  faltan las menos: lo máximo que cabe a 200 ms, sin perder los pops. En "la pista", el gancho entero
#   easy    pops y tiempos fuertes, a 400 ms o más, hacia 2 por segundo. En "la pista", lo fuerte del gancho
# Las NOTAS salen de la partitura. Las FLECHAS de full y del gancho están escritas a mano, un patrón por compás distinto (PAT, GANCHO). Las de
# Normal y Fácil las elige contour(): a 200 ms o más la mano ya no manda, así que esas flechas dibujan la altura de la línea. Todas van por el
# texto del compás: la misma frase lleva siempre las mismas flechas.
# El idioma de las flechas (0 izquierda, 1 abajo, 2 arriba, 3 derecha; mano izquierda 0-1, mano derecha 2-3):
#   · a 100 ms las manos SIEMPRE se alternan, también al cruzar el compás (se comprueba): con dos pulgares es lo único que aguanta
#   · dentro de la mano elige la altura: lo grave a la izquierda, lo agudo a la derecha, y la misma nota del compás, la misma flecha
#   · los pops caen en flecha de fuera (derecha casi siempre): el riff abre "grave-POP-fantasma" (0 3 0), su acorde de Do gira a 1 2 1
#   · la escalera cruzada es el motivo del tema: 0 2 1 3 subiendo, 3 1 2 0 bajando
#   · identidad: el riff salta; la B dibuja la melodía; el solo tiene trinos de octava y los pops a la izquierda en sus paradas;
#     la pista es un flujo de dos manos, pops en 3 (La, Sol) o en 2 (Re, Do), y escalera continua en Si
# Formato: { s16, bars, charts = { nombre = { compás (desde 0) = { semicorchea, carril, ... } } } }, en assets/charts/groove.json.
#   ~/.venvs/fm-music/bin/python tools/music/groove_chart.py
# Previas para revisar (flechas como Do4, Do#4, Re4, Re#4): FlappyMonster_pruebas/groove_duelo/chart_<nombre>.mid
import collections, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import groove_mejora as G
import worlds_nes as W

OUT = 'assets/charts/groove.json'
PREVIAS = '/home/mtvemo/FlappyMonster_pruebas/groove_duelo'
POP, GHOST = 122, 48
LOOP_FROM = 8                                                         # (la O vuelve al compás 8, la A)

# ══ LAS FLECHAS DEL BAJO: una cifra por nota, en orden (se comprueba que coincida con la partitura) ══════════════════
PAT = {
    # el riff
    G.R1: '030231313121', G.R2: '2302303120', G.R3: '121231302030', G.R4: '231232130213',   # (la frase base)
    G.R1b: '03021313203121', G.R2b: '2302130130212', G.R3b: '121231302030',
    G.R1V: '0302021321321', G.R7: '13132321321', G.R7b: '1312133120321', G.R8: '23021312013',
    G.R8b: '230213130203', G.FILL: '231232021313',
    # la B: el bajo canta, la flecha dibuja la línea
    G.B1: '02312012', G.B2: '02121312', G.B3: '02312012', G.B4: '02012323', G.B5: '12302013', G.B6: '030121321',
    G.B7: '02312012', G.B8: '030201213', G.B9: '02312012', G.B11: '02312012', G.B16: '23020303120312',
    # el solo
    G.K2: '203020313120213', G.K3: '0302021321312', G.K4: '103103102102', G.K6: '20313021331202',
    G.K7: '0302133120312', G.K8: '0303030312021303',
}
# la pista: pares a la derecha, impares a la izquierda, 16 semicorcheas sin parar. Un patrón por acorde (cada 4 compases, el giro)
DISCO = {'Am': '2030213020312131',
         'D': '3121302131203020',
         'G': '2131203121302030',
         'C': '3020312030213121',
         'B': '2031203120312031'}
PAT.update({G.disco(c): DISCO[c] for c in DISCO})
# el gancho (una cifra por nota): sube la escalera cruzada y baja por las mismas notas
GANCHO = ['0213120', '0213201', '0213202', '123210', '0213120', '0213201', '0213201', '321012']


def lanes_of(text, pats=PAT):
    ev = sorted(G.BL(text))
    pat = pats.get(text)
    assert pat is not None, 'compás sin patrón de flechas: ' + text
    assert len(pat) == len(ev), 'patrón de %d flechas para %d notas: %s' % (len(pat), len(ev), text)
    return {st: int(pat[i]) for i, (st, n, d, v) in enumerate(ev)}


def best(notes, gap, last=15):
    """La mejor elección de notas con `gap` semicorcheas o más entre ellas (la de más peso: programación dinámica sobre el compás).
    notes = {st: peso}. `last`: la última que puede quedar (para no pegarse a la primera del compás siguiente)."""
    sts = sorted(st for st in notes if st <= last)
    memo = {}
    def go(i):
        if i >= len(sts): return (0, ())
        if i in memo: return memo[i]
        j = i + 1
        while j < len(sts) and sts[j] - sts[i] < gap: j += 1
        w, rest = go(j)
        memo[i] = max(go(i + 1), (w + notes[sts[i]], (sts[i],) + rest), key=lambda x: x[0])
        return memo[i]
    return sorted(go(0)[1])


def weight_normal(st, v):
    # (cuenta sobre todo el número de notas; un pop vale más que las dos normales que le estorban; el fantasma, lo último)
    return 25 if v == POP else 4 if v == GHOST else 13 if st % 4 == 0 else 10


def weight_easy(st, v):
    # (pops y tiempos fuertes; los fantasmas no entran)
    if v == GHOST: return -9
    w = {0: 14, 8: 6, 4: 4, 12: 2}.get(st, 0)                          # (el 1 siempre; el cuarto tiempo solo si es pop: hacia 2 por segundo)
    return w + (10 if v == POP else 0) - 2


# (K8, el trino de octava: sus pops van todos a contratiempo; Fácil se queda con los tiempos, que suben Mi Mi Sol Si)
EASY_STEPS = {G.K8: (0, 4, 8, 12)}


def weight_hook_easy(st, d):
    return (5 if d >= 3 else 3) + (2 if st % 4 == 0 else 0)            # (las largas son las que se oyen como cumbre)


def contour(notes, jack, bias=(0, 0, 0, 0), first=None):
    """Las flechas de un compás ya aclarado (a 200 ms o más): la de menos coste (Viterbi). notes = [(st, altura, fuerza)]. Quieren: lo grave a
    la izquierda y lo agudo a la derecha, que la flecha suba cuando sube la nota, que el pop caiga en flecha de fuera, no repetir (`jack`) y gastar las flechas menos usadas hasta ahora (`bias`)."""
    ps = sorted({n for _, n, _ in notes})
    target = lambda n: 1.5 if len(ps) == 1 else 3 * ps.index(n) / (len(ps) - 1)
    def own(n, v, l):
        return abs(l - target(n)) + (0 if v != POP or l in (0, 3) else 1) + bias[l]
    cost = {l: (own(notes[0][1], notes[0][2], l), (l,)) for l in range(4) if first is None or l == first}
    for (_, n0, _), (_, n, v) in zip(notes, notes[1:]):
        nxt = {}
        for l in range(4):
            opts = []
            for l0, (c, path) in cost.items():
                move = jack if l == l0 else 0
                if n > n0 and l <= l0: move += 3
                if n < n0 and l >= l0: move += 3
                opts.append((c + move + own(n, v, l), path + (l,)))
            nxt[l] = min(opts)
        cost = nxt
    return list(min(cost.values())[1])


CHOSEN, USED = {}, {}
# Fácil: la primera nota del compás cae según su nota (Mi 0, Sol y La 1, Si y Re 2, Do 3): el riff abre 0 1 3 2, la B 1 0 3 2 y el cambio de
# acorde se ve en la flecha. Si no, con tan pocas notas, todos los compases serían el mismo "0 1 3".
ROOT_LANE = {4: 0, 7: 1, 9: 1, 11: 2, 2: 2, 0: 3}


def thin_lanes(text, ev, keep, jack, root=False):
    """contour() una sola vez por compás distinto y por dificultad: la misma frase, las mismas flechas"""
    key = (text, tuple(keep))
    used = USED.setdefault(jack, [0, 0, 0, 0])
    if key not in CHOSEN:
        tot = max(1, sum(used))
        first = ROOT_LANE.get(ev[keep[0]][0] % 12) if root else None
        CHOSEN[key] = contour([(st, ev[st][0], ev[st][2]) for st in keep], jack, [(10 if root else 1.5) * (u / tot - 0.25) for u in used], first)
    for l in CHOSEN[key]: used[l] += 1
    return list(zip(keep, CHOSEN[key]))


def score():
    """[(sección, compás, texto del bajo, índice del gancho o None)]"""
    out, b0 = [], 0
    for name, bars, _, _ in G.sections('B'):
        for i, t in enumerate(bars):
            out.append((name, b0 + i, t, i % 8 if name == 'D' and i < 15 else None))
        b0 += len(bars)
    return out


def build():
    charts = {'full': {}, 'normal': {}, 'easy': {}}
    for name, b, t, hk in score():
        ev = {st: (n, d, v) for st, n, d, v in G.BL(t)}
        lane = lanes_of(t)
        charts['full'][b] = [(st, lane[st]) for st in sorted(ev)]
        if name == 'D':                                               # el gancho, el otro instrumento principal
            if hk is None:                                            # (el compás 16 de la pista no lleva gancho: descanso)
                charts['normal'][b] = charts['easy'][b] = []
                continue
            src = sorted(W.P(b + 1, G.HOOK[hk]), key=lambda x: x[1])
            assert len(GANCHO[hk]) == len(src), 'gancho %d' % hk
            hl = {x[1]: int(GANCHO[hk][i]) for i, x in enumerate(src)}
            # (Normal lo toca entero: su único par a 100 ms, 6-7, es a dos manos y es la firma del gancho)
            charts['normal'][b] = [(x[1], hl[x[1]]) for x in src]
            keep = best({x[1]: weight_hook_easy(x[1], x[3]) for x in src}, 4, 12)
            charts['easy'][b] = [(st, hl[st]) for st in keep]
        else:
            keep = best({st: weight_normal(st, ev[st][2]) for st in ev}, 2, 14)
            charts['normal'][b] = thin_lanes(t, ev, keep, 4)
            keep = EASY_STEPS.get(t) or best({st: weight_easy(st, ev[st][2]) for st in ev if ev[st][2] != GHOST}, 4, 12)
            charts['easy'][b] = thin_lanes(t, ev, list(keep), 2, True)
    return charts


def flat(chart):
    """→ [(tiempo absoluto en semicorcheas, carril)] en orden"""
    return [(b * 16 + st, l) for b in sorted(chart) for st, l in chart[b]]


# ══ COMPROBACIONES E INFORME ══════════════════════════════════════════════════════════════════════════════════════════
def pairs(chart, nbars):
    """Parejas de notas seguidas, incluida la vuelta del bucle (la última nota de la O con la primera de la A)"""
    f = flat(chart)
    ps = list(zip(f, f[1:]))
    tail = f[-1]
    head = next(x for x in f if x[0] >= LOOP_FROM * 16)
    ps.append((tail, (nbars * 16 + head[0] - LOOP_FROM * 16, head[1])))
    return ps


def stats(chart, nbars):
    ps = pairs(chart, nbars)
    same100 = sum(b[0] - a[0] == 1 and a[1] == b[1] for a, b in ps)
    hand100 = sum(b[0] - a[0] == 1 and a[1] // 2 == b[1] // 2 for a, b in ps)
    n100 = sum(b[0] - a[0] == 1 for a, b in ps)
    jack200 = sum(b[0] - a[0] == 2 and a[1] == b[1] for a, b in ps)
    n200 = sum(b[0] - a[0] == 2 for a, b in ps)
    return same100, hand100, n100, jack200, n200


def phrase_consistency(charts_name, chart, rows, size):
    """De los grupos de `size` compases que vuelven con las mismas notas (empezando en múltiplo de `size` dentro de la sección), cuántas
    veces llevan las mismas flechas que la primera vez"""
    seen, same, total = {}, 0, 0
    pos = collections.Counter()
    for i in range(len(rows)):
        name, b, t, hk = rows[i]
        k = pos[name]; pos[name] += 1
        if k % size or i + size > len(rows): continue
        grp = rows[i:i + size]
        if len({r[0] for r in grp}) > 1: continue
        def key(r):
            return (r[2] if not (r[0] == 'D' and charts_name != 'full') else 'g%s' % r[3])
        mus = tuple(key(r) for r in grp)
        arrows = tuple(tuple(chart[r[1]]) for r in grp)
        if mus in seen:
            total += 1
            same += seen[mus] == arrows
        else:
            seen[mus] = arrows
    return same, total


def report(charts, nbars):
    rows = score()
    secs = []
    for r in rows:
        if r[0] not in secs: secs.append(r[0])
    barlen = G.BAR
    for k, chart in charts.items():
        c = [0, 0, 0, 0]
        for x in chart.values():
            for _, l in x: c[l] += 1
        n = sum(c)
        print('%-7s %4d notas, %.1f/s; carriles %s = %s %%' % (k, n, n / (nbars * barlen), c, [round(100 * v / n) for v in c]))
        line = []
        for s in secs:
            bs = [r[1] for r in rows if r[0] == s]
            cnt = [len(chart[b]) for b in bs]
            line.append('%s %.1f/%.1f' % (s, sum(cnt) / (len(bs) * barlen), max(cnt) / barlen))
        print('        por seccion (media/compas max): ' + '  '.join(line))
        same100, hand100, n100, jack200, n200 = stats(chart, nbars)
        print('        mismo carril a 100 ms: %d; misma mano a 100 ms: %d de %d; mismo carril a 200 ms: %d de %d' % (same100, hand100, n100, jack200, n200))
        print('        frases que vuelven con las mismas flechas: compas %d/%d, 2 compases %d/%d, 4 compases %d/%d' % (
            *phrase_consistency(k, chart, rows, 1), *phrase_consistency(k, chart, rows, 2), *phrase_consistency(k, chart, rows, 4)))


def check(charts):
    rows = score()
    total = 0
    for name, b, t, hk in rows:
        ev = sorted(G.BL(t))
        total += len(ev)
        assert [st for st, _ in charts['full'][b]] == [st for st, n, d, v in ev], 'full debe ser 1:1 (compás %d)' % b
    assert sum(len(v) for v in charts['full'].values()) == total, 'full debe ser 1:1'
    nbars = len(rows)
    for name, chart in charts.items():
        same100, hand100, *_ = stats(chart, nbars)
        assert same100 == 0, '%s: mismo carril a 100 ms' % name
        assert hand100 == 0, '%s: misma mano a 100 ms' % name
    # Normal y Fácil, sacados de notas reales
    for name, b, t, hk in rows:
        real = {st for st, *_ in G.BL(t)} if name != 'D' else {x[1] for x in W.P(1, G.HOOK[hk])} if hk is not None else set()
        for k in ('normal', 'easy'):
            assert {st for st, _ in charts[k][b]} <= real, 'nota inventada en %s, compás %d' % (k, b)


def write_midis(charts):
    import mido
    os.makedirs(PREVIAS, exist_ok=True)
    for k, chart in charts.items():
        mid = mido.MidiFile(type=1, ticks_per_beat=480)
        tr = mido.MidiTrack()
        tr.append(mido.MetaMessage('set_tempo', tempo=int(60e6 / G.BPM), time=0))
        tr.append(mido.MetaMessage('time_signature', numerator=4, denominator=4, time=0))
        tr.append(mido.MetaMessage('track_name', name='Flechas ' + k, time=0))
        ev = []
        for t, l in flat(chart):
            ev += [(t * 120, 1, 60 + l), (t * 120 + 100, 0, 60 + l)]
        now = 0
        for tt, on, n in sorted(ev, key=lambda e: (e[0], e[1])):
            tr.append(mido.Message('note_on' if on else 'note_off', note=n, velocity=100 if on else 0, time=tt - now))
            now = tt
        mid.tracks.append(tr)
        mid.save(os.path.join(PREVIAS, 'chart_%s.mid' % k))


def main():
    charts = build()
    check(charts)
    nbars = len(score())
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    data = {'s16': G.S16, 'bars': nbars,
            'charts': {k: {str(b): [x for p in v[b] for x in p] for b in v if v[b]} for k, v in charts.items()}}
    with open(OUT, 'w') as f:
        json.dump(data, f, separators=(',', ':'), sort_keys=True)
    report(charts, nbars)
    write_midis(charts)


if __name__ == '__main__':
    main()
