#!/usr/bin/env python3
# NIVELA la banda sonora: mide la sonoridad (LUFS) de cada pista del catálogo y escribe su "volume" en
# assets/music/index.json para que todas suenen igual de fuertes EN EL JUEGO (sonoridad del archivo + volumen).
# Los volúmenes de antes estaban puestos para las pistas prestadas: los jefes nuevos salían ~3,5 dB por encima de
# los niveles y al entrar en la pelea había un salto. Objetivos (LUFS efectivos): niveles y mapa −14,5 · pistas
# tranquilas (cuevas, arrecife) −15,3 · jefes −14 (medio punto por encima del nivel; −13 hasta la 0.5.64: tapaba los
# efectos) · jefe final −13,5 · el Groove y el Mega Mashup −12 ·
# resultados −15 · menús −15,5.
#   ~/.venvs/fm-music/bin/python tools/music/levels.py      (repetirlo siempre que se regenere o añada una pista)
import json, re, math, os
import soundfile as sf, pyloudnorm as pyln

ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'music')
CALM = {'costa_2', 'cuevas_1', 'cuevas_2', 'cuevas_oscuras', 'map_cuevas'}


def target(t):
    i = t['id']
    # (0.5.64, el usuario: "la música de los jefes suena más fuerte de lo que debería y los carámbanos, el daño del
    #  jugador y otros efectos casi ni se oyen" → todo lo de jefe, 1 dB más bajo; el Groove y el mashup, que iban a
    #  −9,5 para que la música mandara, a −12: siguen por encima del resto pero dejan oír los efectos)
    if i == 'mirror_boss': return -13.5
    if i in ('groove', 'crab_mashup'): return -12.0
    if t.get('boss'): return -14.0
    if i == 'menus': return -15.5
    if i.startswith('story_'): return -14.0   # (cinemáticas: con sus efectos de sonido encima)
    if i == 'victory': return -14.0          # (la pantalla de resultados la baja aún más mientras cuenta)
    if i in CALM: return -15.3
    return -14.5


p = os.path.join(ROOT, 'index.json')
raw = open(p).read()
idx = json.loads(raw)
out = []
for l in raw.split('\n'):
    m = re.search(r'"id": "([a-z_0-9]+)"', l)
    t = next((t for t in idx['tracks'] if t['id'] == m.group(1)), None) if m and l.strip().startswith('{') else None
    if t:
        f = t.get('loop') if isinstance(t.get('loop'), str) else t.get('file')
        y, sr = sf.read(os.path.join(ROOT, f))
        lu = pyln.Meter(sr).integrated_loudness(y)
        v = min(1.0, round(10 ** ((target(t) - lu) / 20), 2))
        l = re.sub(r',\s*"volume": [0-9.]+', '', l)
        l = re.sub(r'\s*\}(,?)\s*$', lambda mm: ', "volume": %.2f }%s' % (v, mm.group(1)), l)
        print('%-22s %6.1f LUFS  volumen %.2f  → %6.1f en el juego' % (t['id'], lu, v, lu + 20 * math.log10(v)))
    out.append(l)
s = '\n'.join(out)
json.loads(s)
open(p, 'w').write(s)
