#!/usr/bin/env python3
# tools/music/credits_music.py — LA MÚSICA DE LOS CRÉDITOS (docs/story/credits.md): un popurrí de la propia banda
# sonora del juego, montado SOBRE los tiempos de la película de los créditos (assets/story/films.json, "credits"):
# cada escena dice de qué pista sale su trozo (`src`: pista del catálogo, parte intro / loop / file, compás de
# partida y cuántos compases) y dura justo esos compases a su tempo, así que cada cambio de canción cae en su imagen
# (la película se dibuja con la misma tabla: src/story/films/credits.lua). Nada ajeno: solo las pistas del juego.
#   · Cada trozo se corta en compás exacto (las pistas se generaron a tempo fijo: sus bucles son compases enteros;
#     el script lo comprueba) y se iguala de volumen (RMS) con los demás.
#   · En cada empalme: un fundido de 12 ms (sin chasquido) y un PLATILLO de ruido (como el canal de ruido del NES)
#     que tapa el cambio de tono; en el primer tiempo de cada canción.
#   · La última escena: su trozo y luego el primer tiempo de esa canción sostenido y apagándose (el acorde final),
#     y silencio hasta el final de la escena.
#   python3 tools/music/credits_music.py        → assets/music/story/story_credits.ogg
#   REPORT=1 → solo números (duración por escena, volumen, picos), sin exportar
# Se comprueba con números (NO se ha escuchado).
import json, os, sys
import numpy as np
import soundfile as sf

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
MUSIC = os.path.join(ROOT, 'assets', 'music')
FILMS = json.load(open(os.path.join(ROOT, 'assets', 'story', 'films.json')))
INDEX = {t['id']: t for t in json.load(open(os.path.join(MUSIC, 'index.json')))['tracks']}
SR = 44100
BEATS_PER_BAR = 4
TARGET_RMS = 10 ** (-15.0 / 20)        # todos los trozos a -15 dBFS RMS
XF = int(0.012 * SR)                   # fundido de cada empalme
OUT = os.path.join(MUSIC, 'story', 'story_credits.ogg')


def load(track, part):
    t = INDEX[track]
    path = os.path.join(MUSIC, t[part])
    y, sr = sf.read(path, always_2d=True)
    assert sr == SR, (path, sr)
    return y


def crash(n, k=1.0):
    """Platillo: ruido blanco con su caída, filtrado a agudos (el canal de ruido del NES, largo)"""
    rng = np.random.default_rng(7)
    x = rng.uniform(-1, 1, n)
    x = np.diff(np.concatenate([[0], x]))                       # (paso alto sencillo: quita los graves)
    env = np.exp(-np.arange(n) / (0.35 * SR)) * 0.18 * k
    return np.stack([x * env, x * env], axis=1)


def main():
    film = FILMS['credits']
    pieces, report, t, gains = [], [], 0.0, {}
    scenes = film['scenes']
    for i, s in enumerate(scenes):
        src = s['src']
        beat = 60.0 / s['bpm']
        bar = BEATS_PER_BAR * beat
        y = load(src['track'], src['part'])
        # (el bucle tiene que ser de compases enteros a ese tempo: si no, el tempo de la tabla está mal)
        bars_in_file = len(y) / SR / bar
        assert abs(bars_in_file - round(bars_in_file)) < 0.01, (s['id'], bars_in_file)
        a = int(round(src['bar'] * bar * SR))
        n = int(round(src['bars'] * bar * SR))
        assert a + n <= len(y), (s['id'], 'el trozo se sale de la pista')
        seg = y[a:a + n].copy()
        rms = np.sqrt(np.mean(seg ** 2))
        # (varias escenas seguidas de la MISMA pista — el Espejo: tema, subida, clímax — llevan la ganancia de la
        # primera: la subida se queda más suave y el clímax más fuerte, como en la canción)
        key = src['track']
        if key not in gains: gains[key] = TARGET_RMS / max(rms, 1e-6)
        g = gains[key]
        seg *= g
        dur = s['beats'] * beat
        total = int(round(dur * SR))
        if len(seg) < total:
            # (la última: el primer tiempo de la canción sostenido y apagándose, y silencio)
            tail = y[a:a + int(beat * SR)].copy() * g
            hold = np.concatenate([tail, np.zeros((total - len(seg) - len(tail), 2))]) if total - len(seg) > len(tail) else tail[:total - len(seg)]
            fade = np.exp(-np.arange(len(hold)) / (0.8 * SR))[:, None]
            seg = np.concatenate([seg, hold * fade])
        seg = seg[:total]
        # empalme: fundidos y platillo en el primer tiempo (no en el logo, que empieza solo)
        seg[:XF] *= np.linspace(0, 1, XF)[:, None]
        seg[-XF:] *= np.linspace(1, 0, XF)[:, None]
        if i > 0:
            c = crash(min(len(seg), int(1.2 * SR)), 1.3 if s['id'] in ('mirror', 'climax', 'bye') else 1.0)
            seg[:len(c)] += c
        pieces.append(seg)
        report.append((s['id'], src['track'], t, dur, 20 * np.log10(max(rms, 1e-9))))
        t += dur
    y = np.concatenate(pieces)
    peak = np.max(np.abs(y))
    if peak > 0.97: y *= 0.97 / peak
    # fundido de entrada del logo y de salida al final
    fi = int(1.0 * SR); y[:fi] *= np.linspace(0, 1, fi)[:, None]
    fo = int(0.6 * SR); y[-fo:] *= np.linspace(1, 0, fo)[:, None]
    for r in report:
        print('  %-10s %-20s %6.2f s  dura %5.2f s  (original %5.1f dBFS RMS)' % r)
    print('  total %.3f s  pico %.2f  (película: %.3f s)' % (len(y) / SR, np.max(np.abs(y)), t))
    if os.environ.get('REPORT'): return
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    # (libsndfile se cae escribiendo Vorbis largos: WAV temporal + ffmpeg)
    import subprocess, tempfile
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, 'credits.wav')
        sf.write(wav, y.astype(np.float32), SR, subtype='FLOAT')
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6', OUT], check=True)
    print('  → ' + os.path.relpath(OUT, ROOT))


if __name__ == '__main__':
    main()
