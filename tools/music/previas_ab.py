#!/usr/bin/env python3
# tools/music/previas_ab.py — PREVIAS A/B de una pista de worlds_nes.py, con el motor del juego (no toca assets/):
#   <pista>_<versión>_completa.ogg        intro + bucle ×3, tal cual lo encadena el juego (intro una vez, bucle sin volver)
#   <pista>_<versión>_costura.ogg         últimos 4 compases del bucle → primeros 4 (la costura, dos veces seguidas)
#   <pista>_<versión>_intro_a_bucle.ogg   la intro entera → 4 compases del bucle
#   <pista>_<versión>_c<N>.ogg            4 compases antes y 4 después de la sección que empieza en el compás N
# Versiones: la PROPUESTA (el generador del árbol de trabajo, renderizado aquí) y las publicadas que se le pasen como
# commits (`--contra 5f2ceea af3b8b5`: sus .ogg salen del propio git, como las oía el juego).
#   ~/.venvs/fm-music/bin/python tools/music/previas_ab.py <pista> --compases 29,37 [--contra COMMIT ...] [--salida DIR]
import io, os, sys, subprocess
import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
import worlds_nes as W
import famicom as F
import gloomy_nes as GN

SR = F.SR


def enc(x, path):
    wav = path[:-4] + '.wav'
    sf.write(wav, x, SR); subprocess.run(['ffmpeg', '-nostdin', '-v', 'quiet', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6', path]); os.remove(wav)
    print('  ' + path)


def propuesta(name):
    """→ intro, bucle (como los escribiría GN.export: los últimos 6 ms de la intro se apagan)"""
    y, mel, bpm, n_i = W.build(name, **W.TRACKS[name])
    a = y[:n_i].copy(); k = int(0.006 * SR); a[-k:] *= np.linspace(1, 0, k)[:, None]
    return a, y[n_i:]


def publicada(name, commit):
    rel = os.path.relpath(os.path.abspath(F.out(name, 'ogg')), ROOT)[:-4]
    out = []
    for suf in ('_intro.ogg', '_loop.ogg'):
        data = subprocess.run(['git', '-C', ROOT, 'show', '%s:%s' % (commit, rel + suf)], capture_output=True).stdout
        x, sr = sf.read(io.BytesIO(data))
        out.append(x if x.ndim == 2 else np.stack([x, x], 1))
    return out


VER = {'af3b8b5': 'ORIGINAL_3.97.0', '5f2ceea': 'ANTES_3.99.0'}


if __name__ == '__main__':
    name = sys.argv[1]
    # --compases 29:B_a_A,37:A_a_E  (compás de la pieza donde empieza la sección: la intro son los compases 1-4)
    bars = [(int(x.split(':')[0]), x.split(':')[1] if ':' in x else '') for x in sys.argv[sys.argv.index('--compases') + 1].split(',')] if '--compases' in sys.argv else []
    contra = []
    if '--contra' in sys.argv:
        for c in sys.argv[sys.argv.index('--contra') + 1:]:
            if c.startswith('--'): break
            contra.append(c)
    base = sys.argv[sys.argv.index('--salida') + 1] if '--salida' in sys.argv else os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'musica', 'revision')
    out = os.path.join(base, name)
    os.makedirs(out, exist_ok=True)
    bar = 16 * 60.0 / W.TRACKS[name]['bpm'] / 4
    k4 = int(round(4 * bar * SR))
    vers = [('NUEVA', propuesta(name))] + [(VER.get(c, c), publicada(name, c)) for c in contra]
    guia = ['%s — previas para comparar (motor del juego). Cada archivo existe en varias versiones: el final del nombre dice cuál.' % name,
            '  NUEVA = la propuesta · ANTES_3.99.0 = la que está ahora en el juego · ORIGINAL_3.97.0 = antes de alargarla', '']
    for lab, (intro, loop) in vers:
        guia.append('%s: intro %.1f s, bucle %.1f s (%d compases)' % (lab, len(intro) / SR, len(loop) / SR, round(len(loop) / SR / bar)))
        enc(np.concatenate([intro, loop, loop, loop]), os.path.join(out, '1_completa_intro_y_3_vueltas__%s.ogg' % lab))
        enc(np.concatenate([loop[-k4:], loop[:k4], loop[-k4:], loop[:k4]]), os.path.join(out, '2_final_del_bucle_y_vuelta_al_principio__%s.ogg' % lab))
        enc(np.concatenate([intro, loop[:k4]]), os.path.join(out, '3_intro_y_entrada_al_bucle__%s.ogg' % lab))
        if lab == 'NUEVA':
            lin = np.concatenate([intro, loop, loop])
            for i, (b, desc) in enumerate(bars):
                t = (b - 1) * bar
                a, z = int(max(0, t - 4 * bar) * SR), int((t + 4 * bar) * SR)
                enc(lin[a:z], os.path.join(out, '%d_cambio_compas_%d_%s__%s.ogg' % (4 + i, b, desc, lab)))
    guia += ['', 'Qué escuchar:',
             '  1_completa…           la canción como la oye el jugador: la intro una vez y el bucle 3 veces seguidas.',
             '  2_final_del_bucle…    los 4 últimos compases del bucle y los 4 primeros, dos veces: la vuelta al principio',
             '                        cae a los %.1f s y a los %.1f s.' % (4 * bar, 12 * bar),
             '  3_intro_y_entrada…    la intro y los 4 primeros compases del bucle (el bucle empieza a los %.1f s).' % (len(vers[0][1][0]) / SR)]
    for i, (b, desc) in enumerate(bars):
        guia.append('  %d_cambio_compas_%d…  4 compases antes y 4 después de ese cambio de sección (%s); el cambio cae a los %.1f s.' % (4 + i, b, desc.replace('_', ' '), 4 * bar if b > 4 else 0))
    open(os.path.join(out, 'LEEME.txt'), 'w').write('\n'.join(guia) + '\n')
    print('\n'.join(guia))
