#!/usr/bin/env python3
# tools/art/ui/make_powerups.py
# Los POWER-UPS (docs/design/powerups.md, src/world/powerups/), mapas de caracteres de 12x12 (se dibujan ×4):
#   assets/images/ui/powerups/icons-Sheet.png  un icono por power-up, en el orden del catálogo (Powerups.LIST):
#       escudo · corazón extra · fuerza · imán de puntos · imán de objetos · súper imán · pequeño · fantasma
#   /usr/bin/python3 tools/art/ui/make_powerups.py      (nada de esto está retocado a mano: se puede volver a generar)
import os
from PIL import Image

PAL = {
    '.': (0, 0, 0, 0), 'o': (34, 32, 52, 255), 'w': (245, 250, 255, 255),
    'b': (60, 120, 220, 255), 'c': (120, 200, 255, 255),          # azules
    'r': (220, 50, 60, 255), 'R': (255, 120, 120, 255),           # rojos
    'y': (255, 210, 70, 255), 'Y': (255, 240, 160, 255),          # dorados
    'g': (90, 200, 90, 255), 'G': (170, 240, 150, 255),           # verdes
    'm': (200, 60, 60, 255), 's': (190, 195, 210, 255),           # imán: rojo, plata
    'p': (170, 120, 230, 255), 'P': (215, 185, 255, 255),         # morados (fantasma)
    'k': (60, 60, 80, 255),
}
# (DENSIDAD: 12x12 por icono y ×4 en pantalla, unos 8 píxeles de arte de ancho como los objetos — docs/art/style-rules.md;
#  el usuario, 2026-11-08: los primeros de 16x16 tenían demasiada resolución —)
ICONS = {
    'shield': ['............', '..oooooooo..', '..owcccbbo..', '..occcccbo..', '..occcccbo..', '..occcccbo..',
               '...occcbo...', '....ocbo....', '.....oo.....', '............', '............', '............'],
    'heart': ['............', '...oo.oo....', '..oRroRro...', '..orrwrro...', '..orwwwro...', '...orwro....',
              '....oro.....', '.....o......', '............', '............', '............', '............'],
    'strength': ['............', '.......oo...', '......oyo...', '.....oyyo...', '....oyyo....', '...oyyyyoo..',
                 '...ooyyyyo..', '.....oyyo...', '....oyyo....', '....oyo.....', '....oo......', '............'],
    'magnet_points': ['............', '..ooo..ooo..', '..oso..oso..', '..omoyyomo..', '..omo..omo..', '..omoooomo..',
                      '..ommmmmmo..', '...oooooo...', '............', '............', '............', '............'],
    'magnet_items': ['............', '..ooo..ooo..', '..oso..oso..', '..omorromo..', '..omo..omo..', '..omoooomo..',
                     '..ommmmmmo..', '...oooooo...', '............', '............', '............', '............'],
    'magnet_all': ['............', '..ooo..ooo..', '..oYo..oYo..', '..oyorroyo..', '..oyo..oyo..', '..oyooooyo..',
                   '..oyyyyyyo..', '...oooooo...', '............', '............', '............', '............'],
    'small': ['oo........oo', 'o..........o', '....k..k....', '....kkkk....', '....kwkw....', '....kkkk....',
              '.....kk.....', '............', 'o..........o', 'oo........oo', '............', '............'],
    'ghost': ['............', '...P....P...', '....P..P....', '...pppppp...', '...pPwPwp...', '...pPkPkp...',
              '...pPPPPp...', '...pppppp...', '....pPPp....', '...pPppPp...', '...pp..pp...', '............'],
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
    assert len(ICONS[k]) == 12 and all(len(r) == 12 for r in ICONS[k]), k
save([''.join(ICONS[k][y] for k in ORDER) for y in range(12)], 'assets/images/ui/powerups/icons-Sheet.png')

# La BURBUJA del escudo (assets/images/fx/shield.png): un aro de 28x28 que rodea al monstruo (×4 → 112 px, como su
# sprite de 16x16 ×6), con brillo arriba a la izquierda; solo el aro: el monstruo se ve dentro
def bubble():
    rows = []
    for y in range(28):
        r = ''
        for x in range(28):
            dx, dy = x - 13.5, y - 13.5
            d = (dx * dx + dy * dy) ** 0.5
            if 12.6 < d <= 13.6: r += 'b'
            elif 11.6 < d <= 12.6: r += 'w' if (dx < -4 and dy < -4) else 'c'
            else: r += '.'
        rows.append(r)
    return rows
save(bubble(), 'assets/images/fx/shield.png')
