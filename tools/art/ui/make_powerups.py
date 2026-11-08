#!/usr/bin/env python3
# tools/art/ui/make_powerups.py
# Los POWER-UPS (docs/design/powerups.md, src/world/powerups/), mapas de caracteres de 16x16:
#   assets/images/ui/powerups/icons-Sheet.png  un icono por power-up, en el orden del catálogo (Powerups.LIST):
#       escudo · corazón extra · fuerza · imán de puntos · imán de objetos · súper imán · pequeño · fantasma
#   /usr/bin/python3 tools/art/ui/make_powerups.py      (nada de esto está retocado a mano: se puede volver a generar)
import os
from PIL import Image

PAL = {
    '.': (0, 0, 0, 0), 'o': (20, 18, 34, 255), 'w': (245, 250, 255, 255),
    'b': (60, 120, 220, 255), 'c': (120, 200, 255, 255),          # azules
    'r': (220, 50, 60, 255), 'R': (255, 120, 120, 255),           # rojos
    'y': (255, 210, 70, 255), 'Y': (255, 240, 160, 255),          # dorados
    'g': (90, 200, 90, 255), 'G': (170, 240, 150, 255),           # verdes
    'm': (200, 60, 60, 255), 's': (190, 195, 210, 255),           # imán: rojo, plata
    'p': (170, 120, 230, 255), 'P': (215, 185, 255, 255),         # morados (fantasma)
    'k': (60, 60, 80, 255),
}
ICONS = {
    'shield': [
        '................', '....oooooooo....', '...occccccccbo..', '..occwwccccccbo.', '..ocwwcccccccbo.',
        '..occcccccccbbo.', '..occccccccccbo.', '..occccccccccbo.', '...occcccccbbo..', '...occcccccbbo..',
        '....occcccbbo...', '.....occcbbo....', '......occbo.....', '.......oo.......', '................', '................'],
    'heart': [
        '................', '..oooo....oooo..', '.oRRrro..orrrro.', '.oRrrrroorrrrro.', '.orrrrrwwrrrrro.',
        '.orrrrrwwrrrrro.', '.orrrwwwwwwrrro.', '.orrrwwwwwwrrro.', '..orrrrwwrrrro..', '...orrrwwrrro...',
        '....orrrrrro....', '.....orrrro.....', '......orro......', '.......oo.......', '................', '................'],
    'strength': [
        '................', '.......oo.......', '......oyyo......', '..oo..oyyo..oo..', '..oyoooyyoooyo..',
        '...oyyyyyyyyo...', '....oyyrryyo....', '.ooyyyrrrryyyoo.', '.oyyyyrrrryyyyo.', '..ooyyyrryyyoo..',
        '....oyyyyyyo....', '...oyoooyyoooyo.', '..oyo..oyyo..oo.', '..oo...oyyo.....', '.......oo.......', '................'],
    'magnet_points': [
        '................', '..oooo....oooo..', '..osso....osso..', '..oooo....oooo..', '..ommo.oo.ommo..',
        '..ommooyyoommo..', '..ommoyyyyommo..', '..ommooyyoommo..', '..ommmoooommmo..', '..ommmmmmmmmmo..',
        '...ommmmmmmmo...', '....oooooooo....', '................', '................', '................', '................'],
    'magnet_items': [
        '................', '..oooo....oooo..', '..osso....osso..', '..oooo....oooo..', '..ommoo..oommo..',
        '..ommoRooRommo..', '..ommorrrrommo..', '..ommoorroommo..', '..ommmoooommmo..', '..ommmmmmmmmmo..',
        '...ommmmmmmmo...', '....oooooooo....', '................', '................', '................', '................'],
    'magnet_all': [
        '................', '..oooo....oooo..', '..oYYo....oYYo..', '..oooo....oooo..', '..oyyo.oo.oyyo..',
        '..oyyooRroyyo...', '..oyyoyrrooyyo..', '..oyyooyyooyyo..', '..oyyyoooooyyo..', '..oyyyyyyyyyyo..',
        '...oyyyyyyyyo...', '....oooooooo....', '................', '................', '................', '................'],
    'small': [
        '................', '.oo..........oo.', '.ooo........ooo.', '..ooo......ooo..', '...o..o..o..o...',
        '......oooo......', '.....okkkko.....', '.....owkwko.....', '.....okkkko.....', '......okko......',
        '...o..o..o..o...', '..ooo......ooo..', '.ooo........ooo.', '.oo..........oo.', '................', '................'],
    'ghost': [
        '................', '....o......o....', '.....o....o.....', '....oooooooo....', '...oPPPPPPPPo...',
        '...oPwwPPwwPo...', '...oPwkPPwkPo...', '...oPPPPPPPPo...', '....oooooooo....', '.....oPPPPo.....',
        '....oPPPPPPo....', '...oPPoPPoPPo...', '...oPo.PP.oPo...', '....o..oo..o....', '................', '................'],
}
ORDER = ['shield', 'heart', 'strength', 'magnet_points', 'magnet_items', 'magnet_all', 'small', 'ghost']


def save(rows, path):
    h, w = len(rows), len(rows[0])
    assert all(len(r) == w for r in rows), (path, [len(r) for r in rows])
    im = Image.new('RGBA', (w, h))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            im.putpixel((x, y), PAL[ch])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print('escrito', path)


for k in ORDER:
    assert len(ICONS[k]) == 16 and all(len(r) == 16 for r in ICONS[k]), k
save([''.join(ICONS[k][y] for k in ORDER) for y in range(16)], 'assets/images/ui/powerups/icons-Sheet.png')
