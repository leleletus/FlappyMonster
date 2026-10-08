#!/usr/bin/env python3
# tools/anim/port_names.py — pasos de DATOS de la migración al runtime único (docs/art/animation.md): cuando el
# código de algo deja de elegir cuadros por número y pide sus animaciones POR NOMBRE, aquí se dejan sus animaciones
# como animaciones normales (sin "at" / "sheet"), con el ritmo que llevaba escrito el código, y se crean las que el
# código componía a mano. Cada paso solo actúa si aún no se hizo (se puede volver a ejecutar).
#   python3 tools/anim/port_names.py
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import write, REPO

def load(sid): return json.load(open(os.path.join(REPO, 'assets', 'anim', sid + '.json'), encoding='utf-8'))
def free(doc, names=None, **over):
    for n, a in doc['anims'].items():
        if names is None or n in names:
            for k in ('at', 'sheet', 'frameW', 'codeFps'): a.pop(k, None)
            a.update(over)
def marked(doc, names): return any(('sheet' in doc['anims'][n] or 'at' in doc['anims'][n]) for n in names if n in doc['anims'])
def cut(doc, image, fw, h, n, y=0):
    """Añade al banco n cuadros de fw x h cortados de una hoja; devuelve sus números."""
    first = len(doc['frames'])
    doc['frames'] += [{'image': image, 'x': i * fw, 'y': y, 'w': fw, 'h': h} for i in range(n)]
    return list(range(first + 1, first + n + 1))
def anim(frames, fps=8, loop=True, **kw): return dict({'frames': list(frames), 'fps': fps, 'loop': loop}, **kw)
done = []

# ── Congelador: cuerpo y cañón idle / charge / fire, el chorro (3 cuadros que fluyen) y su punta
d = load('traps/cryo'); A = d['anims']
if marked(d, ['idle', 'stream_head']):
    free(d)
    A['stream_head']['fps'] = 10
    A['stream'] = anim(cut(d, 'assets/images/traps/cryo/stream-Sheet.png', 16, 10, 3), fps=16)
    write(d, True); done.append('traps/cryo')

# ── Mortero: idle / shoot y la bola de fuego `flame` (12 cuadros/s)
d = load('enemies/mortar')
if marked(d, ['flame']):
    free(d, ['flame'], fps=12)
    write(d, True); done.append('enemies/mortar')

# ── Rey Gummy: el cuerpo por estados (andar a 6/s), la ola a 10/s; la diana compartida a 10/s
d = load('bosses/megagummy')
if marked(d, ['idle', 'wave']):
    free(d)
    d['anims']['walk']['fps'] = 6; d['anims']['wave']['fps'] = 10
    write(d, True); done.append('bosses/megagummy')

# ── Efectos compartidos de los jefes: estrellas de mareo (8/s), diana (10/s), marcas de enfado (vena 7/s,
# garabato 12/s; el vapor, una pasada en lo que dura)
d = load('bosses/common')
if marked(d, ['target']):
    A = d['anims']
    free(d)
    A['stars'] = anim(cut(d, 'assets/images/bosses/common/stars-Sheet.png', 5, 5, 2), fps=8)
    A['target']['fps'] = 10; A['anger_vein']['fps'] = 7; A['anger_scribble']['fps'] = 12
    A['anger_steam'].update(loop=False)
    write(d, True); done.append('bosses/common')

# ── Mega Crabby (y el helado): cuerpo walk / idle / wiggle / kick / dig / windup, pinzas, púa; el helado: capas de
# rabia (destello 0,4 s cada 2 s) y campo de carámbanos (aviso, carámbano, destello)
for sid in ('bosses/megacrabby', 'bosses/megacrabby_ice'):
    d = load(sid); A = d['anims']
    if 'idle' in A: continue
    w = A['walk']['frames']
    A['idle'] = anim([w[1]])
    for n, fps in (('wiggle', 12), ('kick', 24), ('dig', 14), ('windup', 18)): A[n] = anim(w, fps=fps)
    free(d)
    if sid.endswith('_ice'):
        f = A.pop('ice_field')['frames']
        A['field_warn'], A['field_spike'], A['field_glint'] = anim([f[0]]), anim([f[1]]), anim([f[2]])
        b = A['rage_body']['frames']; A['rage_body'] = anim([b[1], b[0]], fps=2.5, durations=[0.4, 1.6])
        c = [A.pop('rage_claw_open')['frames'][0], A.pop('rage_claw_closed')['frames'][0]]
        A['rage_claw'] = anim([c[1], c[0]], fps=2.5, durations=[0.4, 1.6])
    write(d, True); done.append(sid)
d = load('bosses/snowboss')
if marked(d, ['shock']):
    free(d, ['shock'], fps=10); write(d, True); done.append('bosses/snowboss shock')

# ── Gloomy: los iconos que flotan sobre él; Mega Gloomy: las pinzas (normales, de rabia y su brillo)
d = load('enemies/gloomy'); A = d['anims']
if 'icons' in A:
    f = A.pop('icons')['frames']
    for n, i in (('icon_alert', 0), ('icon_doubt', 1), ('icon_lost', 2)): A[n] = anim([f[i]])
    write(d, True); done.append('enemies/gloomy iconos')
d = load('bosses/megagloomy')
if marked(d, ['claw_open']):
    free(d); write(d, True); done.append('bosses/megagloomy pinzas')

# ── Gran Bola de Nieve y Verity: una animación por lo que hace (con angry_ desde la fase 2), la vuelta de rodar, y
# las grietas enlazadas por el dato "ck" de cada cuadro del cuerpo
for sid in ('bosses/snowboss', 'bosses/snowboss/verity'):
    d = load(sid); A = d['anims']
    if 'land' in A: continue
    b = [A['idle']['frames'][0]] + A['squash']['frames'] + [A['spit']['frames'][0], A['angry_idle']['frames'][0]] + \
        A['angry_squash']['frames'] + [A['angry_spit']['frames'][0], A['hurt']['frames'][0], A['angry_hurt']['frames'][0]] + A['dizzy']['frames']
    for i, f in enumerate(b): d['frames'][f - 1]['ck'] = i + 1
    for n in ('roll_happy', 'roll_angry'):
        for i, f in enumerate(A[n]['frames']): d['frames'][f - 1]['ck'] = i + 1
    free(d)
    B = lambda i: b[i - 1]
    for pre, o in (('', 0), ('angry_', 4)):
        A[pre + 'rest'] = anim([B(o + 1), B(o + 2)], fps=3)
        A[pre + 'windup'] = anim([B(o + 3)])
        A[pre + 'land'] = anim([B(o + 3), B(o + 2)], fps=8, loop=False, durations=[0.12, 1])
        A[pre + 'leap'] = anim([B(o + 4)]); A[pre + 'slam_hold'] = anim([B(o + 4)])
        A[pre + 'shoot_wind'] = anim([B(o + 2)])
        A[pre + 'shoot'] = anim([B(o + 4), B(o + 1)], fps=8, durations=[0.6, 0.4])
    A['dizzy']['fps'] = 6
    A['dying'] = anim([B(10)]); A['phase_up'] = anim([B(8)])
    A['intro_flinch'] = anim([B(3)]); A['intro_chatter'] = anim([B(4), B(2)], fps=8)
    A['intro_inhale'] = anim([B(2), B(3)], fps=10, loop=False, durations=[0.1, 1]); A['intro_spit'] = anim([B(4)])
    A['flee']['fps'] = 10
    if 'splat' in A: A['splat'].update(loop=False, durations=[0.55, 0.55, 1], fps=2)
    if 'sweat' in A: A['sweat']['fps'] = 4
    write(d, True); done.append(sid)

# ── El monstruo: una animación por pose (la simulación lleva la pose como número), la caída, el aleteo y los ojos en X;
# el Espejo: su risa (cuerpo y cabeza, 6/s; la cabeza que baja lleva "bob") y los ojos de alegría
d = load('player'); A = d['anims']
if 'glide' not in A:
    k = {fr['key'][:-4]: i + 1 for i, fr in enumerate(d['frames']) if fr.get('key')}
    m = [k['monstrito%d' % i] for i in range(1, 6)]
    for n in ('monstrito', 'dedais'): A.pop(n, None)
    for n, i in (('glide', 0), ('jump', 1), ('idle', 2), ('dead', 3), ('crouch', 4)): A[n] = anim([m[i]])
    A['fall'] = anim([m[0], m[2]], fps=6); A['flutter'] = anim([m[0], m[1], m[2]], fps=14)
    A['dead_eyes'] = anim([k['dedais']]); A['icon'] = anim([k['icon']])
    d['fallback'] = 'idle'
    write(d, True); done.append('player')
d = load('bosses/mirror'); A = d['anims']
if 'laugh_body' not in A:
    k = {fr['key'][:-4]: i + 1 for i, fr in enumerate(d['frames']) if fr.get('key')}
    d['anims'] = A = {}
    A['laugh_body'] = anim([k['Body_ArmsDown'], k['Body_ArmsUp']], fps=6)
    A['laugh_head'] = anim([k['Head_Up'], k['Head_Down']], fps=6)
    d['frames'][k['Head_Down'] - 1]['bob'] = True
    A['joy_eyes'] = anim([k['JoyEyes']])
    d['fallback'] = 'laugh_body'
    write(d, True); done.append('bosses/mirror')

# ── ADOPTAR imágenes sueltas: toda imagen (en git) de una carpeta con conjunto que aún no esté en él entra como un
# cuadro con su "key" y una animación con su nombre (la púa y el caparazón de los Crabbies, el casco del Gummy…),
# para que también se vean y se editen en el editor y el juego las pida como pieza (Anim.part)
import subprocess, glob
TRACKED = set(subprocess.check_output(['git', '-C', REPO, 'ls-files', 'assets/images']).decode().split('\n'))
n_adopt = 0
for f in sorted(glob.glob(os.path.join(REPO, 'assets', 'anim', '**', '*.json'), recursive=True)):
    d = json.load(open(f, encoding='utf-8'))
    folder = os.path.join(REPO, 'assets', 'images', d['id'])
    if not os.path.isdir(folder): continue
    used = {fr['image'] for fr in d['frames']}
    ch = False
    for png in sorted(os.listdir(folder)):
        path = 'assets/images/%s/%s' % (d['id'], png)
        if not png.endswith('.png') or path in used or path not in TRACKED: continue
        d['frames'].append({'image': path, 'key': png})
        name = png[:-4]
        while name in d['anims']: name += '_img'
        d['anims'][name] = anim([len(d['frames'])], fps=4)
        ch = True; n_adopt += 1
    if ch: write(d, True)
if n_adopt: done.append('%d imágenes sueltas adoptadas' % n_adopt)

# ── Piezas que el código elige por estado: cada una, su animación (no un ciclo): el monstruo de la Nave Malvada
# (idle_a / idle_b / hurt, y derribado up / down), el punto de control (apagado / encendido); y las PINZAS de los
# Crabbies de río, lava y hielo (claw_open / claw_snap, cortadas de su hoja)
from PIL import Image
d = load('bosses/miniboss1/monster'); A = d['anims']
if 'idle_a' not in A:
    k = {fr['key'][:-4]: i + 1 for i, fr in enumerate(d['frames']) if fr.get('key')}
    d['anims'] = {'idle_a': anim([k['Idle1']]), 'idle_b': anim([k['idle2_forflipping']]), 'hurt': anim([k['hurt']])}
    d['fallback'] = 'idle_a'; write(d, True); done.append('miniboss1/monster')
d = load('bosses/miniboss1/monster_dead'); A = d['anims']
if 'up' not in A:
    k = {fr['key'][:-4]: i + 1 for i, fr in enumerate(d['frames']) if fr.get('key')}
    d['anims'] = {'up': anim([k['up']]), 'down': anim([k['down']])}
    d['fallback'] = 'up'; write(d, True); done.append('miniboss1/monster_dead')
d = load('items'); A = d['anims']
if 'checkpoint' in A:
    f = A.pop('checkpoint')['frames']
    A['checkpoint_off'], A['checkpoint_on'] = anim([f[0]]), anim([f[1]])
    write(d, True); done.append('items checkpoint')
for sid, fw in (('enemies/crabby_river', 5), ('enemies/crabby_lava', 5), ('enemies/crabby_ice', 7)):
    d = load(sid); A = d['anims']
    if 'claw_open' in A: continue
    img = 'assets/images/%s/claw_left-Sheet.png' % sid
    h = Image.open(os.path.join(REPO, img)).size[1]
    f = cut(d, img, fw, h, 2)
    A['claw_open'], A['claw_snap'] = anim([f[0]]), anim([f[1]])
    A.pop('claw_left-Sheet', None)
    write(d, True); done.append(sid + ' pinzas')

# ── Efectos e interfaz: lava (burbuja, burbuja grande, estallido, gota), copos de nieve (las formas de cada capa),
# gota de hielo, alas, linterna del HUD (encendida / apagada / agotada); la cruceta y los botones ya tienen nombre
d = load('fx'); A = d['anims']
if 'lava_fx' in A:
    f = A.pop('lava_fx')['frames']
    for n, i in (('lava_bubble', 0), ('lava_bubble_big', 1), ('lava_pop', 2), ('lava_drop', 3)): A[n] = anim([f[i]])
    s = A.pop('snowflakes')['frames']
    A['flake_far'], A['flake_mid'], A['flake_near'] = anim([s[3], s[0]]), anim([s[0], s[1], s[3]]), anim([s[1], s[2]])
    free(d); write(d, True); done.append('fx')
d = load('ui'); A = d['anims']
if 'flashlight_on' not in A:
    f = cut(d, 'assets/images/ui/flashlight-Sheet.png', 12, 8, 3)
    A.pop('flashlight', None)
    A['flashlight_on'], A['flashlight_off'], A['flashlight_empty'] = anim([f[0]]), anim([f[1]]), anim([f[2]])
    d['fallback'] = 'flashlight_on'; write(d, True); done.append('ui linterna')
for sid in ('ui/touch', 'ui/ping', 'enemies/wings'):
    d = load(sid)
    if any('sheet' in a or 'at' in a for a in d['anims'].values()):
        free(d)
        if sid == 'enemies/wings': d['anims']['wings']['fps'] = 9
        write(d, True); done.append(sid)

print('pasos hechos ahora:', ', '.join(done) or 'ninguno')
