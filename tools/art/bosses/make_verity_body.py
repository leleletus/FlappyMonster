#!/usr/bin/env python3
# HUEVO DE PASCUA "Verity" de la Gran Bola de Nieve: el usuario dibujó verity/roll_happy, roll_angry, flee y ball
# (la misma bola, en amarillo); faltaba el CUERPO (quieta, risa, mareada, golpeada, muerte...). Es solo un cambio de
# paleta, así que se saca de sus propias hojas: el mapa color normal → color Verity se MIDE comparando píxel a píxel
# roll_happy / roll_angry / flee / ball de las dos carpetas, y se aplica a body-Sheet.png.
#   python3 tools/art/bosses/make_verity_body.py           → vista previa en FlappyMonster_pruebas/verity/
#   python3 tools/art/bosses/make_verity_body.py --apply   → assets/images/bosses/snowboss/verity/body-Sheet.png
import os, sys
from PIL import Image

D = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'assets', 'images', 'bosses', 'snowboss')
PAIRS = ['roll_happy-Sheet.png', 'roll_angry-Sheet.png', 'flee-Sheet.png', 'ball.png']

votes = {}
for f in PAIRS:
    a = Image.open(os.path.join(D, f)).convert('RGBA')
    b = Image.open(os.path.join(D, 'verity', f)).convert('RGBA')
    assert a.size == b.size, f
    for pa, pb in zip(a.getdata(), b.getdata()):
        if pa[3] and pb[3]:
            votes.setdefault(pa, {}).setdefault(pb, 0)
            votes[pa][pb] += 1
MAP = {k: max(v, key=v.get) for k, v in votes.items()}
for k, v in sorted(MAP.items()): print('  %s → %s  (%d)' % (k, v, votes[k][v]))

src = Image.open(os.path.join(D, 'body-Sheet.png')).convert('RGBA')
out = Image.new('RGBA', src.size)
missing = {}
keys = list(MAP)
px = []
for p in src.getdata():
    if not p[3]: px.append(p); continue
    if p not in MAP:                                  # (un color que las hojas de rodar no usan: el más parecido)
        near = min(keys, key=lambda k: sum((k[i] - p[i]) ** 2 for i in range(3)))
        missing[p] = near
        MAP[p] = MAP[near]
    px.append(MAP[p][:3] + (p[3],))
out.putdata(px)
for k, v in missing.items(): print('  (sin pareja) %s ≈ %s → %s' % (k, v, MAP[k]))
if '--apply' in sys.argv:
    path = os.path.join(D, 'verity', 'body-Sheet.png')
else:
    d = '/home/mtvemo/FlappyMonster_pruebas/verity'
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, 'body-Sheet.png')
    out.resize((src.width * 6, src.height * 6), Image.NEAREST).save(os.path.join(d, 'vista_previa.png'))
out.save(path)
print('  ' + path)
