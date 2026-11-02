#!/usr/bin/env python3
# tools/art/player/make_duel_poses.py → assets/images/player/duel/*.png
#   python3 tools/art/player/make_duel_poses.py          (escribe los PNG y una vista previa en
#                                                         FlappyMonster_pruebas/jugador/duelo/vista_previa.png)
#
# EL MONSTRUO EN EL DUELO DE RITMO (0.5.150, el usuario: "un idle de baile, una animación por nota y una por nota
# fallada", como en Friday Night Funkin'): 13x16 (el monstruo de 9x16 centrado, con sitio para estirar los brazos),
# la misma cabeza, antenas y paleta que monstrito1-5.png (sin alas: vuela por arte de magia — nunca se dibujan).
#   idle1, idle2      el baile de espera (a tiempo y a contratiempo: rodillas dobladas, brazos arriba)
#   left down up right  la pose de cada flecha (mira hacia su lado, se agacha, señala arriba)
#   miss_<flecha>     la misma pose fallada: ojos cerrados y los colores apagados en violeta
# Sale en el conjunto `player` (assets/anim/player.json: duel_idle, duel_<flecha>, duel_miss_<flecha>).
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'player', 'duel')
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/jugador/duelo'

PAL = {'k': (12, 12, 20, 255), 'd': (50, 52, 74, 255), 'g': (196, 200, 214, 255), 'l': (242, 242, 246, 255),
       'w': (255, 255, 255, 255)}
# (fallada: todo hacia un violeta apagado — el "tinte de fallo" de FNF, hecho en el PNG)
MISS = {'k': (34, 20, 52, 255), 'd': (70, 52, 104, 255), 'g': (132, 112, 176, 255), 'l': (166, 150, 206, 255),
        'w': (186, 172, 222, 255)}

W, H = 13, 16
# La cabeza (8 filas, 9 de ancho), como monstrito3.png; ojos según hacia dónde mira
HEAD = ["..k...k..", "...k.k...", "...k.k...", "..kkkkk..", ".kwwllgk.", ".klklkgk.", ".kllgggk.", "..kkkkk.."]
EYES = {
    'front': (".kwwllgk.", ".klklkgk.", ".kllgggk."),
    'left':  (".kwwllgk.", ".kklklgk.", ".kllgggk."),
    'right': (".kwwllgk.", ".kllklkk.", ".kllgggk."),
    'up':    (".kwklkgk.", ".kllllgk.", ".kllgggk."),
    'down':  (".kwwllgk.", ".kllllgk.", ".klkgkgk."),
    'shut':  (".kwwllgk.", ".kkklkkk.", ".kllgggk."),
}


def head(eyes):
    h = list(HEAD)
    h[4], h[5], h[6] = EYES[eyes]
    return h


def canvas():
    return [['.'] * W for _ in range(H)]


def put(cv, rows, x0, y0):
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != '.' and 0 <= y0 + y < H and 0 <= x0 + x < W: cv[y0 + y][x0 + x] = c


# Los cuerpos (13 de ancho), de la fila de debajo de la cabeza hasta los pies
BODY = {
    'idle1': ["......k......",
              ".....dkk.....",
              "....kkkkk....",
              "...k.kkk.k...",
              "..k...k...k..",
              ".....k.k.....",
              ".....k.k.....",
              "....kk.kk...."],
    'idle2': ["..k...k...k..",               # (una fila más abajo: rodillas dobladas, brazos arriba)
              "...k.dkk.k...",
              "....kkkkk....",
              ".....kkk.....",
              "....k.k.k....",
              "....k...k....",
              "...kk...kk..."],
    'left':  ["......k......",
              "kkkkkdkk.....",
              "....kkkkk....",
              "....kkkk.k...",
              ".....kk...k..",
              "....k..k.....",
              "...k....k....",
              "..kk....kk..."],
    'up':    ["......k...k..",
              ".....dkkkk...",
              "....kkkkk....",
              "...kkkkk.....",
              "...k..k......",
              ".....k.k.....",
              ".....k.k.....",
              "....kk.kk...."],
    'down':  ["...k.dkk.k...",               # (dos filas más abajo: en cuclillas, brazos hacia el suelo)
              "..k.kkkkk.k..",
              ".k...kkk...k.",
              "....k...k....",
              "...k.....k...",
              "..kk.....kk.."],
}


def mirror(rows): return [r[::-1].replace('d', '§').replace('§', 'd') for r in rows]


def pose(name, miss=False):
    cv = canvas()
    if name == 'idle1':
        put(cv, head('front'), 2, 0); put(cv, BODY['idle1'], 0, 8)
    elif name == 'idle2':
        put(cv, head('front'), 2, 1); put(cv, BODY['idle2'], 0, 9)      # (toda la cabeza una fila más abajo, pegada al cuerpo)
    elif name == 'left':
        put(cv, head('shut' if miss else 'left'), 1, 0); put(cv, BODY['left'], 0, 8)
    elif name == 'right':
        put(cv, head('shut' if miss else 'right'), 3, 0); put(cv, mirror(BODY['left']), 0, 8)
    elif name == 'up':
        put(cv, head('shut' if miss else 'up'), 2, 0)
        for y in range(4, 8): cv[y][11] = 'k'                           # (el brazo, señalando arriba; 0.5.151: más corto)
        put(cv, BODY['up'], 0, 8)
    elif name == 'down':
        put(cv, head('shut' if miss else 'down'), 2, 2); put(cv, BODY['down'], 0, 10)
    pal = MISS if miss else PAL
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for y in range(H):
        for x in range(W):
            if cv[y][x] in pal: im.putpixel((x, y), pal[cv[y][x]])
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    out = {'idle1.png': pose('idle1'), 'idle2.png': pose('idle2')}
    for n in ('left', 'down', 'up', 'right'):
        out[n + '.png'] = pose(n)
        out['miss_' + n + '.png'] = pose(n, True)
    for name, im in out.items():
        im.save(os.path.join(OUT, name))
        print('  escrito', os.path.join(OUT, name))
    os.makedirs(PREVIEW, exist_ok=True)
    order = ['idle1.png', 'idle2.png', 'left.png', 'down.png', 'up.png', 'right.png',
             'miss_left.png', 'miss_down.png', 'miss_up.png', 'miss_right.png']
    pv = Image.new('RGBA', (len(order) * (W + 3) + 3, H + 6), (60, 44, 96, 255))
    for i, n in enumerate(order): pv.paste(out[n], (3 + i * (W + 3), 3), out[n])
    pv = pv.resize((pv.width * 10, pv.height * 10), Image.NEAREST)
    pv.save(os.path.join(PREVIEW, 'vista_previa.png'))
    print('  vista previa', os.path.join(PREVIEW, 'vista_previa.png'))


if __name__ == '__main__':
    main()
