#!/usr/bin/env python3
# tools/ui/make_enemy_extras.py
# Sprites sueltos de enemigos, dibujados a mano (mapas de caracteres) con el estilo y las
# paletas de los que ya hay (contorno azul marino, brillo arriba-izquierda, sombra abajo-derecha):
#   crabby/dead.png          Crabby APLASTADO: el caparazón hecho tortita con las patas abiertas
#   crabby_ice/dead.png      Crabby helado aplastado: naranja, con sus cerdas, patas y pinzas tiradas
#                            (antes los dos usaban gummy/dead.png: valía cuando todos eran blancos)
#   gummy/parachute.png      paracaídas de la guardia del Rey Gummy (entra por el techo)
#   megacrabby_ice/ice_field-Sheet.png   campo de carámbanos del Mega Crabby helado, 3 cuadros
#                            8x16: grietas de aviso, carámbano, carámbano con brillo
#   MegaCrabby/claw_left-Sheet.png       PINZAS NUEVAS del Mega Crabby (2 cuadros 11x10: abierta /
#                            cerrada): pinza gorda de cangrejo ermitaño, alzada, con el dedo de fuera
#                            grande y ganchudo y el pulgar corto. Nada que ver con la del Mega
#                            Crabby helado (centolla: larga, baja y horizontal). El original del
#                            usuario sigue fuera del repo (tools/ui/originals.py).
#
#   python3 tools/ui/make_enemy_extras.py            → solo la vista previa
#   python3 tools/ui/make_enemy_extras.py --apply    → escribe los assets
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(HERE, '..', '..', 'assets', 'images')
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/extras/vista_previa.png'

WHITE = {'a': '#1e1e2a', 'h': '#ffffff', 'w': '#f2f2f6', 's': '#c4c8d6'}
ORANGE = {'a': '#1e1e2a', 'h': '#ffd8a8', 'w': '#f89e58', 's': '#e26832', 'd': '#a83e28'}
CHUTE = {'a': '#1e1e2a', 'h': '#ffffff', 'w': '#f2f2f6', 's': '#c4c8d6', 'r': '#e04848', 'q': '#a82c3c'}
ICE = {'o': '#3c6cb4', 'h': '#ffffff', 'w': '#c8e6ff', 's': '#8cc0ee'}


def art(rows, pal):
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c not in '. ':
                h = pal[c].lstrip('#')
                im.putpixel((x, y), (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255))
    return im


def strip(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


# Crabby aplastado: tortita con sus dos ojos y las cuatro patas abiertas en el suelo
CRAB_DEAD = art([
    '......aaaaaaaa......',
    '....aahhwwwwwwaa....',
    'a..awwwaawwaawwsa..a',
    '.aaaswwwwwwwwwssaaa.',
    'a..aaaaaaaaaaaaaa..a',
], WHITE)

# Crabby helado aplastado: naranja, cerdas aplastadas, patas y las dos pincitas tiradas
ICE_DEAD = art([
    '.......a..a..a..a.......',
    '......aaaaaaaaaaaa......',
    '.aa.aahhwwwwwwwwwsaa.aa.',
    'awsaawwaawwwwwwaawsdaswa',
    'aadaasswwwwwwwwwssddadaa',
    '.aa..aaaaaaaaaaaaaa..aa.',
], ORANGE)

PARACHUTE = art([
    '.....aaaaaa.....',
    '...aarrhwrraa...',
    '..arrrhwwwrrqa..',
    '.arrrwwwwwwrrqa.',
    '.arrrwwwwwwrrqa.',
    'arrrrwwwwwwsrrqa',
    'aaaaaaaaaaaaaaaa',
    '.a...a....a...a.',
    '..a...a..a...a..',
    '...a..a..a..a...',
    '....a.a..a.a....',
], CHUTE)

FIELD = strip([
    art(['........'] * 12 + ['...o....', '..oho.o.', '.owhwoho', 'ohwhwhwo'], ICE),
    art(['...oo...', '...oho..', '..ohwo..', '..ohwo..', '..ohwo..', '..ohwso.', '..ohwso.', '.ohwwso.',
         '.ohwwso.', '.ohwwso.', '.ohwwso.', '.ohwwsso', 'ohhwwsso', 'ohwwwsso', 'ohwwwsso', 'oooooooo'], ICE),
    art(['...oo...', '...oho..', '..ohho..', '..ohho..', '..ohwo..', '..ohhso.', '..ohwso.', '.ohhwso.',
         '.ohhwso.', '.ohwwso.', '.ohhwso.', '.ohwwsso', 'ohhhwsso', 'ohhwwsso', 'ohwwwsso', 'oooooooo'], ICE),
])

# Pinza del Mega Crabby (izquierda; se une al cuerpo por abajo a la derecha): abierta / cerrada
CLAW = strip([
    art([
        'aa.........',
        'ahaa....a..',
        'ahwwa..awa.',
        'awwwa.aawa.',
        'awwwwaawsa.',
        'awwwaawwsa.',
        'awwwwwwwssa',
        '.awwwwwwssa',
        '..awwwsssa.',
        '...aaaaaa..',
    ], WHITE),
    art([
        '...........',
        '.aaa...a...',
        'ahwwaaawa..',
        'ahwwwawwsa.',
        'awwwaawwsa.',
        'awwwwawwsa.',
        'awwwwwwwssa',
        '.awwwwwwssa',
        '..awwwsssa.',
        '...aaaaaa..',
    ], WHITE),
])

OUT = {
    'crabby/dead.png': CRAB_DEAD,
    'crabby_ice/dead.png': ICE_DEAD,
    'gummy/parachute.png': PARACHUTE,
    'megacrabby_ice/ice_field-Sheet.png': FIELD,
    'MegaCrabby/claw_left-Sheet.png': CLAW,
}


def preview():
    K = 8
    bg = Image.new('RGBA', (1200, 560), (70, 90, 120, 255))
    x = 16
    for name, im in OUT.items():
        big = im.resize((im.width * K, im.height * K), Image.NEAREST)
        bg.alpha_composite(big, (x, 16))
        x += big.width + 24
    # El Mega Crabby con sus pinzas nuevas (como en el juego: escala 0.85 del cuerpo) y, al lado, las de antes
    body = Image.open(os.path.join(IMG, 'MegaCrabby', 'crab1.png')).convert('RGBA')
    S = 10
    def mega(claw, fw, ox):
        b = body.resize((body.width * S, body.height * S), Image.NEAREST)
        cs = 8.5
        fy = 520
        bg.alpha_composite(b, (ox - b.width // 2, fy - b.height))
        fh = claw.height
        for i, side in enumerate((-1, 1)):
            fr = claw.crop((i * fw, 0, i * fw + fw, fh))
            c = fr.resize((int(fw * cs), int(fh * cs)), Image.NEAREST)
            if side > 0:
                c = c.transpose(Image.FLIP_LEFT_RIGHT)
            cx = ox + side * (4.6 * S + fw * cs / 2 - 1.5 * cs)
            cy = fy - 1.6 * S - fh * cs / 2
            bg.alpha_composite(c, (int(cx - c.width / 2), int(cy - c.height / 2)))
    mega(CLAW, 11, 260)
    import importlib.util
    try:
        old = Image.open(os.path.join(IMG, 'MegaCrabby', 'claw_left-Sheet.png')).convert('RGBA')
        if old.size == (14, 6):
            mega(old, 7, 620)
    except Exception:
        pass
    ice = Image.open(os.path.join(IMG, 'megacrabby_ice', 'claw_left-Sheet.png')).convert('RGBA')
    bg.alpha_composite(ice.resize((ice.width * 8, ice.height * 8), Image.NEAREST), (860, 420))
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    bg.save(PREVIEW)
    print('vista previa:', PREVIEW)


if __name__ == '__main__':
    preview()
    if '--apply' in sys.argv:
        for name, im in OUT.items():
            p = os.path.join(IMG, name)
            im.save(p)
            print('escrito', os.path.relpath(p))
