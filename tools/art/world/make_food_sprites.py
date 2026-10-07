#!/usr/bin/env python3
# tools/art/world/make_food_sprites.py — la COMIDA que cura, una por isla (assets/images/items/food_<isla>.png, 16x16 como
# la manzana del usuario, que es la de la pradera y NO se genera aquí): mapas de píxeles a mano, con el contorno
# azul oscuro de la manzana y la luz arriba a la izquierda.
#   costa      piña              fortaleza  muslo asado        nieve   polo de hielo
#   cueva      bayas luminosas   volcan     guindilla
#   python3 tools/art/world/make_food_sprites.py [--apply]     (sin --apply: solo la vista previa en FlappyMonster_pruebas/comida/)
import os, sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..', '..', '..')
OUT = os.path.join(ROOT, 'assets', 'images', 'items')
O = '222034'          # el contorno de la manzana

FOODS = {
    'costa': (dict(o=O, G='99e550', g='37946e', Y='fbe35a', y='e8a82a', d='b8741c'), [
        "................", "................", ".......o.o......", "......oGoGo.....", ".....oGgGgGo....", "......ogGgo.....",
        ".....oooooo.....", "....oYyYyYdo....", "....oyYyYydo....", "....oYyYyYdo....", "....oyYyYddo....", ".....oyYddo.....",
        "......oooo......", "................", "................", "................"]),
    'fortaleza': (dict(o=O, B='eaa860', b='c47a34', d='8a4a20', w='f4ecdc'), [
        "................", "................", "................", "........oooo....", ".......oBbbbo...", "......oBbbbbdo..",
        "......obbbbbdo..", "......obbbbddo..", ".....oowbbddo...", "....owwooooo....", "...owwo.........", "...owo..........",
        "....o...........", "................", "................", "................"]),
    'nieve': (dict(o=O, C='f0fcff', c='8fe0ff', d='4aa6e0', s='dcb878'), [
        "................", "................", "......oooo......", ".....oCccdo.....", ".....oCccdo.....", ".....occcdo.....",
        ".....occcdo.....", ".....occcdo.....", ".....ocdddo.....", "......oooo......", "......osso......", "......osso......",
        ".......oo.......", "................", "................", "................"]),
    'cueva': (dict(o=O, P='d8fff8', p='5fe8dc', d='2a9aa8', G='99e550', g='37946e'), [
        "................", "................", ".......oo.......", "......oGgo......", "...ooo.oo.ooo...", "..oPppoooPppo...",
        "..opppo.opppo...", "..oppdoooppdo...", "...ooooooooo....", ".....oPppo......", ".....opppo......", ".....oppdo......",
        "......ooo.......", "................", "................", "................"]),
    'volcan': (dict(o=O, R='ff8a4a', r='e8382a', d='a01c1c', G='99e550', g='37946e'), [
        "................", "................", "..........oo....", ".........oGo....", "........oogo....", ".......oRro.....",
        "......oRrro.....", ".....oRrrdo.....", "....oRrrdo......", "....orrdo.......", "....ordo........", ".....oo.........",
        "................", "................", "................", "................"]),
}


def img(pal, rows):
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), [len(r) for r in rows]
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.':
                h = pal[ch]
                im.putpixel((x, y), (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255))
    return im


if __name__ == '__main__':
    made = {k: img(*v) for k, v in FOODS.items()}
    prev = os.path.join('/home/mtvemo/FlappyMonster_pruebas', 'comida')
    os.makedirs(prev, exist_ok=True)
    sheet = Image.new('RGBA', (6 * 18 + 2, 20), (70, 100, 140, 255))
    sheet.alpha_composite(Image.open(os.path.join(OUT, 'apple.png')).convert('RGBA'), (2, 2))
    for i, k in enumerate(FOODS):
        sheet.alpha_composite(made[k], (2 + (i + 1) * 18, 2))
    sheet.resize((sheet.width * 10, sheet.height * 10), Image.NEAREST).save(os.path.join(prev, 'vista_previa.png'))
    print('  vista previa:', os.path.join(prev, 'vista_previa.png'))
    if '--apply' in sys.argv:
        for k, im in made.items():
            im.save(os.path.join(OUT, 'food_%s.png' % k))
            print('  assets/images/items/food_%s.png' % k)
