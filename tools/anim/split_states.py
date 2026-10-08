#!/usr/bin/env python3
# tools/anim/split_states.py — UNA ANIMACIÓN POR ESTADO. Las hojas en las que el código usa cada cuadro para un
# estado distinto (la del Gloomy: andar 1-4, quieto 5, agachado 6, salto 7, susto 8, muerto 9) se reparten en una
# animación por estado dentro del conjunto de su carpeta; cada una lleva "at" = los números de cuadro de la hoja
# que son suyos (los que pide el código: SpriteStrip los busca ahí). Y las imágenes sueltas de cada conjunto dejan
# de ir todas en una animación «all»: una por objeto o estado (trampolín: idle / bounce…).
# Qué cuadro es de qué estado sale del código de cada cosa (constantes F_* y comentarios de cabecera).
# Solo actúa sobre lo que sigue sin repartir (se puede volver a ejecutar): python3 tools/anim/split_states.py
import glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import write, REPO

CRAB = [('walk', [1, 2, 3, 4]), ('idle', [5]), ('crouch', [6]), ('leap', [7]), ('scared', [8]), ('dead', [9])]
CLAW = [('claw_open', [1]), ('claw_closed', [2])]
BOMB = [('idle', [1]), ('walk', [2, 3]), ('lit', [4])]
SNOW = [('idle', [1]), ('squash', [2, 3]), ('spit', [4]), ('angry_idle', [5]), ('angry_squash', [6, 7]), ('angry_spit', [8]),
        ('hurt', [9]), ('angry_hurt', [10]), ('dizzy', [11, 12])]
def pre(p, parts): return [(p + n, i) for n, i in parts]
def levels(p, per): return [('%s%d' % (p, l + 1), list(range(l * per + 1, (l + 1) * per + 1))) for l in range(3)]

# conjunto → animación de hoja → [(estado, [números de cuadro de la hoja]), …]
SHEETS = {
    'enemies/gloomy': {'gloomy': CRAB, 'glow': pre('glow_', CRAB)},
    'bosses/megagloomy': {'body': CRAB, 'glow': pre('glow_', CRAB), 'claw_left': CLAW,
                          'claw_rage_left': pre('rage_', CLAW), 'claw_rage_glow': pre('rage_glow_', CLAW)},
    'bosses/megagummy': {'body': [('idle', [1]), ('walk', [2, 3]), ('jump', [4]), ('dazed', [5]), ('hurt', [6]), ('laugh', [7]), ('shout', [8])]},
    'bosses/megacrabby': {'claw_left': CLAW},
    'bosses/megacrabby_ice': {'claw_left': CLAW, 'rage_claw': pre('rage_', CLAW)},
    'bosses/snowboss': {'body': SNOW, 'cracks_body': levels('cracks_body_', 12), 'cracks_roll': levels('cracks_roll_', 8)},
    'bosses/snowboss/verity': {'body': SNOW},
    'enemies/bomb': {'bomb': BOMB, 'bombObject': pre('object_', BOMB),
                     'bomb-fuse': [('fuse_idle', [1, 5]), ('fuse_walk', [2, 3, 6, 7]), ('fuse_lit', [4, 8])],
                     'bombObject-fuse': [('object_fuse_idle', [1, 5]), ('object_fuse_walk', [2, 3, 6, 7]), ('object_fuse_lit', [4, 8])]},
    'enemies/pufferfish': {'puffer_fish': [('swim', [1, 2]), ('half', [3]), ('puffed', [4])]},
    'traps/cryo': {'cryo_body': [('idle', [1]), ('charge', [2, 3]), ('fire', [4])],
                   'cryo_cannon': [('cannon_idle', [1]), ('cannon_charge', [2, 3]), ('cannon_fire', [4])]},
    'ui/touch': {'dpad': [('dpad_neutral', [1]), ('dpad_left', [2]), ('dpad_right', [3]), ('dpad_down', [4]), ('dpad_down_left', [5]),
                          ('dpad_down_right', [6]), ('dpad_up', [7])],
                 'jump': [('jump_up', [1]), ('jump_pressed', [2])], 'light': [('light_up', [1]), ('light_pressed', [2])]},
    'ui/ping': {'ping': [('no_connection', [1]), ('bars', [2, 3, 4, 5])]},
    'fx': {'ice_drop': [('ice_drop', [1]), ('ice_splash', [2])]},
}
# conjunto → estado → imágenes sueltas (sin .png); las demás, una animación por imagen (las numeradas, juntas)
LOOSE = {
    'mechanisms/trampoline': {'idle': ['normal'], 'bounce': ['extended'], 'idle_ice': ['ice_normal'], 'bounce_ice': ['ice_extended']},
    'enemies/mortar': {'idle': ['normal'], 'shoot': ['shooting']},
    'bosses/miniboss1/monster': {'idle': ['Idle1', 'idle2_forflipping'], 'hurt': ['hurt']},
    'bosses/miniboss1/monster_dead': {'dead': ['down', 'up']},
    'bosses/megacrabby': {'walk': ['crab1', 'crab2', 'crab3']},
    'bosses/megacrabby_ice': {'walk': ['crab1', 'crab2', 'crab3']},
    'items': {'checkpoint': ['checkpoint_off', 'checkpoint_on']},
}
WALKS = ('walk', 'swim')
n_sheet = n_loose = 0
for f in sorted(glob.glob(os.path.join(REPO, 'assets', 'anim', '**', '*.json'), recursive=True)):
    doc = json.load(open(f, encoding='utf-8'))
    sid, anims, changed = doc['id'], doc['anims'], False
    for old, parts in SHEETS.get(sid, {}).items():
        a = anims.get(old)
        if not a or 'at' in a or not a.get('sheet'): continue
        assert sorted(i for _, idx in parts for i in idx) == list(range(1, len(a['frames']) + 1)), (sid, old)
        del anims[old]
        for name, idx in parts:
            assert name not in anims, (sid, name)
            anims[name] = {'frames': [a['frames'][i - 1] for i in idx], 'at': idx, 'fps': 7 if name.split('_')[-1] in WALKS else 8,
                           'loop': True, 'sheet': a['sheet'], 'frameW': a['frameW']}
        n_sheet += 1; changed = True
    keys = {fr['key'][:-4]: i + 1 for i, fr in enumerate(doc['frames']) if fr.get('key')}
    if keys and 'all' in anims and not anims['all'].get('sheet'):
        del anims['all']
        if sid in ('bosses/megacrabby', 'bosses/megacrabby_ice'): anims.pop('crab', None)
        for name, ks in LOOSE.get(sid, {}).items():
            anims[name] = {'frames': [keys[k] for k in ks], 'fps': 4, 'loop': True}
        used = {i for a in anims.values() if not a.get('sheet') for i in a['frames']}
        for k, i in sorted(keys.items()):
            if i in used: continue
            name = re.sub(r'-Sheet$', '', k)
            while name in anims: name += '_img'
            anims[name] = {'frames': [i], 'fps': 4, 'loop': True}
        n_loose += 1; changed = True
    if changed:
        if doc.get('fallback') not in anims:
            doc['fallback'] = 'idle' if 'idle' in anims else sorted(anims)[0]
        write(doc, True)
print('hojas repartidas por estados: %d · conjuntos con las imágenes sueltas repartidas: %d' % (n_sheet, n_loose))
