#!/usr/bin/env python3
# tools/music/bloques_beep_check.py — COMPRUEBA con números (FFT por ventanas, solo numpy) que un .wav de la música de
# los BLOQUES BEEP cumple el contrato de tiempos del que depende el juego (los bloques cambian cada 4 s):
#   · tempo 120 ± 0,5 (autocorrelación de los ataques + separación de los pitidos);
#   · en CADA frase de 2 compases (4 s), exactamente 3 pitidos en los tiempos 6, 7 y 8 (2,5 · 3,0 · 3,5 s de la
#     frase), ~0,5 s entre sí, ~70 ms, a la frecuencia fijada ± 20 Hz, casi senoidales (armónicos < 10 %);
#   · el GOLPE en el tiempo 1 de cada frase: bombo (35-120 Hz) ≥ 1,3 × la media de la frase y platillo (6-14 kHz)
#     ≥ 2 × la media de la frase;
#   · el puente C 3-4 dB por debajo de A y de B (RMS de la mezcla entera);
#   · la costura del bucle sin clic ni salto de nivel.
# Sin `--fade`: el archivo es el BUCLE (empieza en el tiempo 1 de la frase 1). Con `--fade`: la versión con final
# (bucle + cola que se apaga): además comprueba que los pitidos siguen durante el fundido.
#   python3 tools/music/bloques_beep_check.py <wav> [--fade] [--freq 2290] [--bpm 120] [--sections 20,16,4]
# Sale con código 1 si algo falla. NO escucha: solo mide.
import sys, wave, json
import numpy as np


def load(path):
    with wave.open(path, 'rb') as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        x = np.frombuffer(w.readframes(n), '<i2').astype(float) / 32768.0
    return (x.reshape(-1, ch).mean(1) if ch > 1 else x), sr


def band(x, sr, lo, hi):
    """filtro de banda ideal por FFT (todo el archivo de una vez)"""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))


def envelope(x, sr, smooth_ms=2.0):
    """envolvente de amplitud (señal analítica por FFT) suavizada"""
    n = len(x)
    X = np.fft.fft(x)
    h = np.zeros(n); h[0] = 1
    if n % 2 == 0: h[n // 2] = 1; h[1:n // 2] = 2
    else: h[1:(n + 1) // 2] = 2
    e = np.abs(np.fft.ifft(X * h))
    k = max(1, int(smooth_ms * sr / 1000))
    return np.convolve(e, np.ones(k) / k, mode='same')


def rms_db(x):
    return 10 * np.log10(np.mean(x ** 2) + 1e-20)


def section_levels(x, sr, bar_s, sections):
    """dB RMS de cada sección (A, B, C) — la misma medida que usa el generador para ajustar C"""
    out, b0 = [], 0
    for L in sections:
        a, b = int(b0 * bar_s * sr), int((b0 + L) * bar_s * sr)
        out.append(rms_db(x[a:b])); b0 += L
    return out


def tempo(x, sr):
    """tempo por autocorrelación del flujo espectral (ventana 2048, salto 256), afinado en el retardo de un compás"""
    hop, n = 256, 2048
    win = np.hanning(n)
    fr = np.lib.stride_tricks.sliding_window_view(x, n)[::hop] * win
    S = np.abs(np.fft.rfft(fr, axis=1))
    S = np.log1p(100 * S)
    flux = np.maximum(0, np.diff(S, axis=0)).sum(1)
    flux -= flux.mean()
    ac = np.correlate(flux, flux, 'full')[len(flux) - 1:]
    fps = sr / hop
    def peak(lo_s, hi_s):
        a, b = int(lo_s * fps), int(hi_s * fps)
        i = a + int(np.argmax(ac[a:b]))
        y0, y1, y2 = ac[i - 1], ac[i], ac[i + 1]
        d = 0.5 * (y0 - y2) / (y0 - 2 * y1 + y2 + 1e-20)
        return (i + d) / fps
    beat = peak(0.4, 0.6)
    bar = peak(1.9, 2.1)                                                  # 4 tiempos: más precisión
    long_ = peak(7.9, 8.1)                                                # 16 tiempos
    return 60 / beat, 240 / bar, 960 / long_


def detect_beeps(x, sr, freq, thr_db=-14.0, local=None):
    """los pitidos: envolvente en freq ± 45 Hz; cada subida por encima de thr_db respecto al pico (del archivo, o de
    su frase si `local`) es un pitido; su inicio = el cruce de −6 dB de su pico; su duración = tiempo por encima de −20 dB"""
    e = envelope(band(x, sr, freq - 45, freq + 45), sr, 1.0)
    ref = np.full(len(e), e.max())
    if local:
        P = int(local * sr)
        for a in range(0, len(e), P):
            ref[a:a + P] = e[a:a + P].max()
    on = e > ref * 10 ** (thr_db / 20)
    d = np.diff(on.astype(int))
    starts, ends = np.where(d == 1)[0] + 1, np.where(d == -1)[0] + 1
    if on[0]: starts = np.r_[0, starts]
    if on[-1]: ends = np.r_[ends, len(e)]
    out = []
    for s, t in zip(starts, ends):
        if t - s < int(0.01 * sr): continue                               # (ruido: < 10 ms)
        seg = e[max(0, s - int(0.02 * sr)):t + int(0.05 * sr)]
        pk = seg.max(); i0 = max(0, s - int(0.02 * sr))
        above = np.where(seg > pk * 0.1)[0]
        t0, t1 = (i0 + above[0]) / sr, (i0 + above[-1]) / sr
        ton = (i0 + np.where(seg > pk * 0.5)[0][0]) / sr                  # (inicio = cruce de −6 dB: el filtro emborrona
                                                                          #  igual por los dos lados del ataque)
        # frecuencia y armónicos: FFT (Hann, relleno a 2^17) de los 60 ms del pitido
        a = int(t0 * sr) + int(0.003 * sr); b = a + int(0.06 * sr)
        z = x[a:b] * np.hanning(b - a)
        Z = np.abs(np.fft.rfft(z, 1 << 17)); f = np.fft.rfftfreq(1 << 17, 1 / sr)
        m = (f > freq - 200) & (f < freq + 200)
        i = np.where(m)[0][np.argmax(Z[m])]
        y0, y1, y2 = np.log(Z[i - 1] + 1e-12), np.log(Z[i] + 1e-12), np.log(Z[i + 1] + 1e-12)
        fp = f[i] + 0.5 * (y0 - y2) / (y0 - 2 * y1 + y2) * (f[1] - f[0])
        h = max(Z[(f > k * fp - 25) & (f < k * fp + 25)].max() for k in (2, 3)) / Z[i]
        # cuánto sobresale de la mezcla: su banda frente a la mezcla entera en esos 60 ms
        over = 20 * np.log10(Z[i] / (np.sqrt(np.mean(Z[(f > 300) & (f < 12000)] ** 2)) + 1e-12))
        out.append(dict(t=ton, dur=t1 - t0, f=fp, harm=h, peak=pk, over=over))
    return out


def check(path, freq=2290.0, bpm=120.0, sections=(20, 16, 4), fade=False, verbose=True):
    x, sr = load(path)
    beat = 60.0 / bpm; bar = 4 * beat; phrase = 2 * bar
    loop_bars = sum(sections); loop_n = int(round(loop_bars * bar * sr))
    total = len(x) / sr
    nph = int(round(total / phrase)) if fade else loop_bars // 2
    ok, R = True, {}
    say = print if verbose else (lambda *a: None)

    def verdict(name, good, txt):
        nonlocal ok
        ok &= bool(good)
        say(f'  [{"OK" if good else "FALLA"}] {name}: {txt}')

    say(f'── {path}  ({total:.3f} s, {len(x)} muestras, {nph} frases de {phrase:.0f} s)')
    if not fade:
        verdict('longitud del bucle', len(x) == loop_n, f'{len(x)} muestras (esperadas {loop_n} = {loop_bars} compases)')
    # TEMPO
    t1, t4, t16 = tempo(x[:loop_n], sr)
    beeps = detect_beeps(x, sr, freq, local=phrase if fade else None)
    gaps = [b2['t'] - b1['t'] for b1, b2 in zip(beeps, beeps[1:]) if b2['t'] - b1['t'] < 1.0]
    per = [b2['t'] - b1['t'] for b1, b2 in zip(beeps, beeps[1:]) if b2['t'] - b1['t'] > 2.0]
    bt = 60 / np.mean(gaps) if gaps else 0
    pt = 8 * 60 / np.mean([b2['t'] - b1['t'] for b1, b2 in zip(beeps, beeps[3:])]) if len(beeps) > 3 else 0
    R['tempo'] = (t1, t4, t16, bt, pt)
    verdict('tempo', all(abs(v - bpm) <= 0.5 for v in (t4, t16, bt, pt)),
            f'ataques: {t1:.2f} (1 tiempo) · {t4:.3f} (compás) · {t16:.3f} (4 compases); pitidos: {bt:.3f} (entre sí) · {pt:.3f} (de frase a frase)')
    # PITIDOS por frase
    counts, terr, durs, fs, hs, overs = [], [], [], [], [], []
    for p in range(nph):
        t0 = p * phrase
        mine = [b for b in beeps if t0 <= b['t'] < t0 + phrase]
        counts.append(len(mine))
        for k, b in enumerate(mine[:3]):
            terr.append(abs(b['t'] - (t0 + (5 + k) * beat)))
        durs += [b['dur'] for b in mine]; fs += [b['f'] for b in mine]; hs += [b['harm'] for b in mine]; overs += [b['over'] for b in mine]
    R['beeps'] = dict(n=len(beeps), counts=counts)
    verdict('3 pitidos por frase', all(c == 3 for c in counts), f'{len(beeps)} pitidos; por frase: {"".join(str(c) for c in counts)}')
    verdict('en los tiempos 6-7-8', max(terr) < 0.004, f'error máx. {1000 * max(terr):.2f} ms respecto a 2,5 · 3,0 · 3,5 s de la frase')
    verdict('separación', all(abs(g - beat) < 0.004 for g in gaps), f'{min(gaps):.4f}-{max(gaps):.4f} s')
    verdict('duración ~70 ms', all(55e-3 <= d <= 85e-3 for d in durs), f'{1000 * min(durs):.1f}-{1000 * max(durs):.1f} ms (por encima de −20 dB de su pico)')
    verdict(f'frecuencia {freq:.0f} ± 20 Hz', all(abs(f - freq) <= 20 for f in fs), f'{min(fs):.1f}-{max(fs):.1f} Hz')
    verdict('casi senoidal', max(hs) < 0.10, f'2º/3er armónico como mucho {100 * max(hs):.1f} % de la fundamental (en la mezcla)')
    say(f'        (sobresale de la mezcla: su pico {min(overs):.0f}-{max(overs):.0f} dB por encima del espectro medio 0,3-12 kHz)')
    secs, b0 = [], 0
    for name, L in zip('ABC', sections):
        secs.append((name, b0 // 2, (b0 + L) // 2)); b0 += L
    have = {name: all(counts[p] == 3 for p in range(a, b)) for name, a, b in secs}
    txt = ', '.join(f'{k} {"sí" if v else "NO"}' for k, v in have.items())
    if fade:
        tail = list(range(loop_bars // 2, nph))
        have['fundido'] = all(counts[p] == 3 for p in tail)
        txt += f', fundido {"sí" if have["fundido"] else "NO"} (frases {tail[0] + 1}-{tail[-1] + 1})'
    verdict('pitidos en todas las secciones', all(have.values()), txt)
    # GOLPES (tiempo 1 de cada frase)
    lowb = band(x, sr, 35, 120) ** 2
    hib = band(x, sr, 6000, 14000) ** 2
    kr, hr, kk = [], [], []
    for p in range(nph):
        a = int(p * phrase * sr); b = int(min(len(x), (p + 1) * phrase * sr))
        if fade and p >= loop_bars // 2: break
        w = lambda arr, t, L: arr[a + int(t * sr):a + int((t + L) * sr)].mean()
        kr.append(w(lowb, 0, 0.10) / lowb[a:b].mean())
        hr.append(w(hib, 0, 0.06) / hib[a:b].mean())
        others = [w(lowb, k * beat, 0.10) for k in range(1, 8)]
        kk.append(w(lowb, 0, 0.10) / max(others))
    R['impacts'] = dict(kick=kr, high=hr)
    verdict('bombo del golpe ≥ 1,3 × media de la frase', min(kr) >= 1.3,
            f'{min(kr):.1f}-{max(kr):.1f} × (y {min(kk):.2f}-{max(kk):.2f} × el tiempo más fuerte del resto de la frase)')
    verdict('platillo del golpe (6-14 kHz) ≥ 2 × media', min(hr) >= 2.0, f'{min(hr):.1f}-{max(hr):.1f} ×')
    # SECCIONES
    lv = section_levels(x[:loop_n], sr, bar, sections)
    R['levels'] = lv
    dA, dB = lv[2] - lv[0], lv[2] - lv[1]
    verdict('C 3-4 dB por debajo de A y B', -4.0 <= dA <= -3.0 and -4.0 <= dB <= -3.0,
            f'A {lv[0]:.2f} · B {lv[1]:.2f} ({lv[1] - lv[0]:+.2f}) · C {lv[2]:.2f} dB → C−A {dA:+.2f}, C−B {dB:+.2f}')
    # COSTURA
    if not fade:
        y = x[:loop_n]
        dd = np.abs(np.diff(y))
        jump = abs(y[0] - y[-1])
        lim = np.percentile(dd, 99.9)
        q = int(0.25 * sr)
        pre_seam, pre_ref = rms_db(y[-q:]), rms_db(y[int((loop_bars - 2) * bar * sr) - q:int((loop_bars - 2) * bar * sr)])
        post_seam = rms_db(y[:q])
        posts = [rms_db(y[int(p * phrase * sr):int(p * phrase * sr) + q]) for p in range(1, sections[0] // 2)]
        # la cola de antes de la costura frente a la de antes del golpe de dentro de C; la cabeza después de la costura
        # frente a la de las otras frases de A (el salto propio de pasar de C a A, pero ninguno de más)
        good = jump <= lim and abs(pre_seam - pre_ref) <= 1.5 and abs(post_seam - np.mean(posts)) <= 1.5
        verdict('costura del bucle', good,
                f'salto de muestra {jump:.4f} (p99,9 de las diferencias {lim:.4f}); últimos 250 ms {pre_seam:.1f} dB vs '
                f'antes del golpe de C {pre_ref:.1f}; primeros 250 ms {post_seam:.1f} vs otras frases de A {np.mean(posts):.1f} '
                f'({min(posts):.1f}-{max(posts):.1f})')
    else:
        q = int(phrase * sr)                                              # (por frases: cada una lleva su golpe)
        tail_lv = [rms_db(x[a:a + q]) for a in range(int(loop_bars * bar * sr), len(x) - q + 1, q)]
        mono = all(b2 <= b1 + 1.5 for b1, b2 in zip(tail_lv, tail_lv[1:]))
        verdict('fundido', mono and tail_lv[-1] < tail_lv[0] - 20,
                f'{(len(x) - loop_n) / sr:.1f} s de {tail_lv[0]:.1f} a {tail_lv[-1]:.1f} dB, sin subidas')
    say(f'  → {"TODO OK" if ok else "HAY FALLOS"}')
    R['ok'] = ok
    return R


if __name__ == '__main__':
    a = sys.argv[1:]
    opt = lambda k, d: type(d)(a[a.index(k) + 1]) if k in a else d
    files = [f for i, f in enumerate(a) if f.endswith('.wav') and (i == 0 or not a[i - 1].startswith('--'))]
    secs = tuple(int(s) for s in opt('--sections', '20,16,4').split(','))
    bad = 0
    for f in files:
        r = check(f, opt('--freq', 2290.0), opt('--bpm', 120.0), secs, fade='--fade' in a)
        bad += not r['ok']
    sys.exit(1 if bad else 0)
