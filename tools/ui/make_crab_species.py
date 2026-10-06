#!/usr/bin/env python3
# Los dos CRABBIES nuevos, ya como aspectos (skins) del Crabby — elegidos por el usuario tras cuatro rondas
# (tools/ui/make_enemy_designs.py guarda las propuestas):
#   · CRABBY DE RÍO (pradera, agua dulce): caparazón estrecho con musgo, NO más alto que el Crabby de siempre (9 px),
#     patas largas con una fila VERDE pegada (como las naranjas del Crabby helado; sin más pelitos), sin boca, y las
#     pinzas del juego (el dibujo de las del Crabby helado) en su color → assets/images/crabby_river/
#   · CRABBY DE LAVA: roca ancha y baja, "cara 1" (ojos de brasa y grietas sueltas, sin boca) y las mismas pinzas con
#     el filo al rojo ("pinzas C") → assets/images/crabby_lava/
# Cada carpeta: crab1-3 (andar), sink1..N (se HUNDE fila a fila al esconderse, como el helado), hid, lookin, meat,
# dead (aplastado), spike (la púa del Crabby) y claw_left-Sheet (2 cuadros 5x5: abierta / cerrada).
#   python3 tools/ui/make_crab_species.py --apply      (sin --apply: solo la vista previa en FlappyMonster_pruebas)
import os, shutil, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_enemy_designs as D

IMG = D.ROOT
RIVER = D.P('d8cc8c', 'a89c5a', '6e6638', e=D.NAVY, m='5aa040', M='8cd060')
LAVA = D.P('804238', '5c2a26', '3e1a1c', e=D.FIRE3, E=D.FIRE2, f=D.FIRE)

SPECIES = {
    'crabby_river': dict(
        pal=RIVER, claw_pal=RIVER,
        shell=["......ommmoo......",
               "....oohmMbbboo....",
               "....ohbbbbbbso....",
               "....obebbbbeso....",
               "....oossssssoo...."],
        legs=[["..om.om....mo.mo..", ".om..om....mo..mo.", "om...om....mo...mo", "o.....o....o.....o"],
              ["..om.om....mo.mo..", "..om..om....mo.mo.", ".om...om....mo.mo.", ".o...o.......o.o.."],
              ["..om.om....mo.mo..", ".om.om....mo..mo..", ".om.om....mo...mo.", "..o.o......o....o."]],
        look=2,                                            # el "asomado": desde esta fila del caparazón
        dead=["........oommoo........",
              "....oohhbbmmbbbboo....",
              ".omobeebbbbbbbbeebsom.",
              "om.oossssssssssssoo.mo",
              "....oooooooooooooo...."]),
    'crabby_lava': dict(
        pal=LAVA, claw_pal=dict(LAVA, h=D.FIRE3),
        shell=[".....oooooooo.....",
               "....ohbbfbbbso....",
               "...ohbbbfebbbfso..",
               "...obEbbbbbbEbso..",
               "...obefbbbbbebso..",
               "...oossssssssoo..."],
        legs=[["...o.o.o..o.o.o...", "..o..o.o..o.o..o..", ".o...o.o..o.o...o."],
              ["...o.o.o..o.o.o...", "...o.o..o.o..o.o..", "..o..o..o.o..o..o."],
              ["...o.o.o..o.o.o...", "..o.o.o....o.o.o..", ".o..o.o....o.o..o."]],
        look=2,
        dead=["......oooooooooo......",
              "...oohbbbfbbbbfbbsoo..",
              "o.oobEEbbbbbbbEEbsoo.o",
              ".oossssssssssssssssoo.",
              "o..oooooooooooooooo..o"]),
}


CLAW_W = 5
CLAW = [["oooo.", "ohbbo", "oboo.", "osso.", ".oo.."],          # abierta
        ["oooo.", "ohbbo", "ossso", ".ooo.", "....."]]          # cerrada


def img(rows, pal):
    return D.maps(rows, pal)


def build(name, sp):
    out = {}
    shell, n = sp['shell'], len(sp['shell'])
    w = len(shell[0])
    for i, legs in enumerate(sp['legs']):
        out['crab%d.png' % (i + 1)] = img(shell + legs, sp['pal'])
    blank = '.' * w
    for i in range(n):                                     # hundiéndose: el caparazón baja una fila cada vez
        out['sink%d.png' % (i + 1)] = img([blank] * i + shell[:n - i], sp['pal'])
    out['meat.png'] = out['sink1.png']
    out['lookin.png'] = img(shell[sp['look']:], sp['pal'])
    out['hid.png'] = Image.new('RGBA', (w, 1))
    out['dead.png'] = img(sp['dead'], sp['pal'])
    # La pinza: el MISMO dibujo que las de los demás Crabbies (dedo de arriba largo con su gancho, hueco, dedo de abajo
    # corto), a la medida de estos, que son más bajos: 5x5 en vez de 7x7 (la del helado les llegaba de la cabeza al suelo)
    claw = Image.new('RGBA', (CLAW_W * 2, 5))
    for k, g in enumerate(CLAW):
        claw.alpha_composite(D.maps(g, sp['claw_pal']), (k * CLAW_W, 0))
    out['claw_left-Sheet.png'] = claw
    return out


if __name__ == '__main__':
    apply = '--apply' in sys.argv
    for name, sp in SPECIES.items():
        files = build(name, sp)
        d = os.path.join(IMG, name) if apply else os.path.join(D.OUT, name)
        os.makedirs(d, exist_ok=True)
        for f, im in files.items(): im.save(os.path.join(d, f))
        if apply: shutil.copy(os.path.join(IMG, 'crabby', 'spike.png'), os.path.join(d, 'spike.png'))
        print('  %s  (%d archivos, cuerpo %dx%d, caparazón de %d filas)' % (d, len(files) + (1 if apply else 0), files['crab1.png'].width,
                                                                           files['crab1.png'].height, len(sp['shell'])))
