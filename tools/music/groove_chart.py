#!/usr/bin/env python3
# tools/music/groove_chart.py — el CHART del duelo de ritmo del Cangrejo Groove, sacado de la MISMA partitura que el tema instalado
# (groove_mejora.py, variante B): si cambian las notas, se vuelve a generar y no se desincronizan.
#   full    (Difícil, Extremo, Xtra) 1:1 con el bajo slap, nota a nota (el usuario: "debe ser 1:1")
#   normal  faltan las menos: pops, tiempos y lo que quepa con 200 ms entre notas. En "la pista", el gancho (el otro instrumento)
#   easy    pops y tiempos fuertes con 400 ms entre notas. En "la pista", el gancho
# Carriles 0 izquierda, 1 abajo, 2 arriba, 3 derecha: por altura dentro del compás (la línea que sube, sube por los carriles). Una
# nota no repite carril con la anterior a una semicorchea: a 100 ms nadie lo aguanta con un dedo.
# Formato: { s16, bars, charts = { nombre = { compás (desde 0) = { semicorchea, carril, ... } } } }, en assets/charts/groove.json.
#   ~/.venvs/fm-music/bin/python tools/music/groove_chart.py
import json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import groove_mejora as G
import worlds_nes as W

OUT = 'assets/charts/groove.json'
POP, GHOST = 122, 48


def lanes(bar, rot=0):
    """[(st, nota, ...)] de un compás → {st: carril}"""
    ps = sorted({n for _, n in bar})
    out, prev_st, prev_l = {}, None, None
    for st, n in sorted(bar):
        l = ((ps.index(n) * 4 // len(ps)) + (rot if len(ps) <= 2 else 0)) % 4 if len(ps) > 1 else rot % 4    # (pocas alturas: van rotando)
        # (notas iguales seguidas: se alternan; y nunca el mismo carril a una semicorchea)
        if prev_st is not None and l == prev_l and st - prev_st <= 1:
            l = (l + 1) % 4 if l < 3 else 2
        out[st] = l
        prev_st, prev_l = st, l
    return out


def thin(notes, gap, last=-999):
    """Por prioridad, deja las que queden a `gap` semicorcheas o más. notes = [(abs, prioridad)]"""
    keep = []
    for ab, _ in sorted(notes, key=lambda x: (-x[1], x[0])):
        if all(abs(ab - k) >= gap for k in keep): keep.append(ab)
    return set(keep)


def main():
    charts = {'full': {}, 'normal': {}, 'easy': {}}
    bar0, total, ghosts = 0, 0, 0
    for name, bars, _, _ in G.sections('B'):
        for i, t in enumerate(bars):
            b = bar0 + i
            ev = G.BL(t)
            total += len(ev)
            lane = lanes([(st, n) for st, n, d, v in ev])
            charts['full'][b] = [x for st, n, d, v in sorted(ev) for x in (st, lane[st])]
            if name == 'D':                                           # el gancho, el otro instrumento principal
                k = i + 1
                src = [(st, n) for _, st, n, d in W.P(b + 1, G.HOOK[(k - 1) % 8])] if k <= 15 else []
                pri = {st: 3 if st % 4 == 0 else 2 for st, _ in src}
            else:
                src = [(st, n) for st, n, d, v in ev]
                pri = {st: (5 if v == POP else 4 if st % 8 == 0 else 3 if st % 4 == 0 else 1 if v == GHOST else 2) for st, n, d, v in ev}
            for diff, gap in (('normal', 2), ('easy', 4)):
                keep = thin([(st, pri[st]) for st, _ in src], gap)
                if diff == 'easy' and name != 'D':
                    keep = {st for st in keep if pri[st] >= 3}
                l2 = lanes([(st, n) for st, n in src if st in keep], b)
                charts[diff][b] = [x for st, _ in sorted(src) if st in keep for x in (st, l2[st])]
        bar0 += len(bars)
    assert sum(len(v) // 2 for v in charts['full'].values()) == total, 'full debe ser 1:1'
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    data = {'s16': G.S16, 'bars': bar0, 'charts': {k: {str(b): v[b] for b in v if v[b]} for k, v in charts.items()}}
    with open(OUT, 'w') as f:
        json.dump(data, f, separators=(',', ':'), sort_keys=True)
    for k, v in charts.items():
        n = sum(len(x) // 2 for x in v.values())
        c = [0, 0, 0, 0]
        for x in v.values():
            for l in x[1::2]: c[l] += 1
        print('%-7s %5d notas, %.1f por segundo; por carril %s' % (k, n, n / (bar0 * G.BAR), c))


if __name__ == '__main__':
    main()
