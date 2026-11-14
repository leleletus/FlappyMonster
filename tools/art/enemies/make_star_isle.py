#!/usr/bin/env python3
# tools/art/enemies/make_star_isle.py
# LA ISLA ESTELAR (`estelar`, la Vía Estelar: docs/design/via-estelar-level.md): el arte de los enemigos y de todo lo
# que cambia por isla (Isles.IDS, `isleArt`, familias) para el cielo `starway`. Sale del arte de la pradera (o del
# Gummy / Crabby de río) PASADO A LA PALETA ESTELAR: cada color con saturación pasa a la franja violeta-lavanda
# (conserva su luz y el orden de los tonos: lo claro sigue claro), los grises se enfrían un poco y el negro y el blanco
# no cambian; el Gummy y el Crabby llevan además unas motas de estrella en el lomo. La comida es una CARAMBOLA (fruta
# estrella): la manzana pasada a dorado.
# Nada de esto pisa un archivo existente (crea los `estelar-*` y las carpetas `*_star`); --force los rehace.
#   python3 tools/art/enemies/make_star_isle.py            → vista previa en FlappyMonster_pruebas/via_estelar/enemigos/
#   python3 tools/art/enemies/make_star_isle.py --apply
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib'))
import animjson  # noqa: E402
import os, sys, glob, json, colorsys, shutil
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
os.chdir(REPO)
PREV = '/home/mtvemo/FlappyMonster_pruebas/via_estelar/enemigos'
APPLY, FORCE = '--apply' in sys.argv, '--force' in sys.argv
ISLE = 'estelar'


def recolor(im, hue0=262, span=34, satk=0.85, gold=False):
    im = im.convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s > 0.16 and v > 0.08:
                if gold:
                    nh = (44 + (h * 360 % 60) / 60 * 10) / 360
                else:
                    nh = (hue0 + (h * 360) / 360 * span) / 360          # (el orden de los tonos de antes, en la franja)
                ns = min(0.75, s * satk)
                nr, ng, nb = colorsys.hsv_to_rgb(nh % 1, ns, v)
            else:
                nr, ng, nb = r / 255 * 0.96, g / 255 * 0.96, min(1, b / 255 * 1.06 + 0.02)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return im


def lavender(im):
    """el Gummy es BLANCO (sin color: la paleta no lo toca): su cuerpo claro pasa a lavanda pálido y lleva una estrella
    dorada en la frente (la pupila / boca oscura y el contorno no cambian)"""
    im = im.convert('RGBA')
    px = im.load()
    top = None
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s < 0.2 and v > 0.55:
                nr, ng, nb = colorsys.hsv_to_rgb(265 / 360, 0.16 + (1 - v) * 0.9, min(1, v * 1.0))
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
                if top is None: top = (x, y)
    return im


def sparkle(im, n=2):
    """unas motas de estrella sobre los píxeles de cuerpo más grandes (no en los bordes)"""
    im = im.copy()
    px = im.load()
    W, H = im.size
    pts = []
    for y in range(2, H - 2):
        for x in range(2, W - 2):
            if all(px[x + dx, y + dy][3] > 0 for dx in (-2, 0, 2) for dy in (-2, 0, 2)):
                r, g, b, a = px[x, y]
                if 60 < (r + g + b) / 3 < 200: pts.append((x, y))
    for i in range(min(n, len(pts))):
        x, y = pts[(i * 7919 + 3) % len(pts)]
        px[x, y] = (255, 246, 210, 255)
    return im


def out(path, im, written):
    written.append((path, im))
    if APPLY:
        if os.path.exists(path) and not FORCE: print('  ya existe (no se toca):', path); return
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im.save(path); print('  escrito', os.path.relpath(path, REPO))


def main():
    written = []
    # 1. Todo lo `pradera-*` (por isla): enemigos, mecanismos, semilla
    for p in sorted(glob.glob('assets/images/**/pradera-*', recursive=True) + glob.glob('assets/images/**/pradera.png', recursive=True)):
        dst = p.replace('pradera-', ISLE + '-').replace('pradera.png', ISLE + '.png')
        if p.endswith('.json'):
            if APPLY and (FORCE or not os.path.exists(dst)): shutil.copyfile(p, dst); print('  copiado', dst)
            continue
        out(dst, recolor(Image.open(p)), written)
    # 2. La hoja del viento del Soplón: una fila por isla (orden de Isles.IDS) → una fila más
    wp = 'assets/images/enemies/gust/wind-Sheet.png'
    w = Image.open(wp).convert('RGBA')
    rows = w.height // 8
    if rows == 7 or FORCE:
        nw = Image.new('RGBA', (w.width, 8 * 8)); nw.paste(w.crop((0, 0, w.width, 7 * 8)), (0, 0))
        nw.paste(recolor(w.crop((0, 0, w.width, 8))), (0, 7 * 8))
        written.append((wp, nw))
        if APPLY: nw.save(wp); print('  ' + wp + ': fila 8 (estelar)')
    # 3. Las familias: Gummy estelar (del Gummy) y Crabby estelar (del de río)
    for src, dst, spark in (('assets/images/enemies/gummy', 'assets/images/enemies/gummy_star', True),
                            ('assets/images/enemies/crabby_river', 'assets/images/enemies/crabby_star', True)):
        for p in sorted(glob.glob(src + '/*.png')):
            im = recolor(Image.open(p))
            if 'gummy' in src: im = lavender(im)
            name = os.path.basename(p)
            if spark and not name.startswith(('dead', 'casco', 'parachute', 'claw', 'spike', 'meat')): im = sparkle(im)
            out(os.path.join(dst, name), im, written)
    # 4. La comida: carambola (fruta estrella)
    out('assets/images/items/food_estelar.png', recolor(Image.open('assets/images/items/apple.png'), gold=True), written)
    # 5. Las variantes de los conjuntos de animación (Saltarín, Topo)
    for aid in ('enemies/hopper', 'enemies/mole'):
        p = 'assets/anim/%s.json' % aid
        d = json.load(open(p))
        src = d['variants'][next(iter(d['variants']))]['from']
        if ISLE not in d['variants']:
            d['variants'][ISLE] = {'from': src, 'to': src.replace('pradera-', ISLE + '-')}
            if APPLY:
                animjson.write(p, d)
                print('  ' + p + ': variante estelar')
    preview(written)


def preview(written):
    os.makedirs(PREV, exist_ok=True)
    picks = [im for p, im in written if any(k in p for k in ('gummy_star/gummy1', 'crabby_star/crab1', 'hopper/estelar',
                                                              'gust/estelar', 'mole/estelar', 'box/estelar.png',
                                                              'food_estelar', 'door/estelar'))]
    x, h = 10, 10
    big = [im.resize((im.width * 4, im.height * 4), Image.NEAREST) for im in picks]
    W = sum(b.width + 20 for b in big) + 20
    H = max(b.height for b in big) + 40
    cv = Image.new('RGBA', (W, H), (24, 22, 48, 255))
    for b in big:
        cv.alpha_composite(b, (x, 20)); x += b.width + 20
    cv.save(os.path.join(PREV, 'vista_previa.png'))
    print('vista previa:', os.path.join(PREV, 'vista_previa.png'), '·', len(written), 'imágenes')


if __name__ == '__main__':
    main()
