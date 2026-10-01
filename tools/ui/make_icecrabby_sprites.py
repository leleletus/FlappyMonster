#!/usr/bin/env python3
# tools/ui/make_icecrabby_sprites.py — sprites del CRABBY HELADO (los Crabbies normales en su
# versión helada: el mismo cangrejo que el Mega Crabby helado, igual que el Crabby normal es el
# mismo dibujo que el Mega) y de sus 4 TAPAS (lo que saca al esconderse, en suelo, pared o techo):
#   púa de hielo  = la púa normal en hielo (mata, como la púa)
#   trampolín     = el del Crabby trampolín en hielo (rebota, como siempre)
#   nieve         = un montón de nieve: disfraz inofensivo; al tocarlo revienta y ataca
#   carámbano     = el carámbano de la Gran Bola de Nieve (2 de vida + empujón), en cualquier
#                   superficie (siempre carámbano, apuntando hacia fuera de la superficie)
#
#   python3 tools/ui/make_icecrabby_sprites.py            # vista previa en --out
#   python3 tools/ui/make_icecrabby_sprites.py --apply    # escribe assets/images/crabby_ice/
#   (--out: $FM_PREVIEWS/crabby_ice o /home/mtvemo/FlappyMonster_pruebas/crabby_ice, fuera del repo)
#
# Salida (como assets/images/crabby/ + tapas):
#   crab1/2/3.png   andar (18x13; los de assets/images/megacrabby_ice)
#   meat.png        el cuerpo sin patas (se mete en el suelo), lookin.png (solo asoma), hid.png
#   spike.png       púa de hielo (38x38, como crabby/spike.png)
#   tramp_normal.png / tramp_extended.png   trampolín de hielo (16x16, como trampoline/*.png)
#   snow.png        montón de nieve (18x8), snow_cracked.png (a punto de reventar)
#   icicle.png      carámbano (8x16, el de la Gran Bola de Nieve)
import argparse
import os
import shutil

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
ICE_MEGA = os.path.join(ROOT, 'assets', 'images', 'megacrabby_ice')
DST = os.path.join(ROOT, 'assets', 'images', 'crabby_ice')
S = 4                                   # escala del Crabby en el juego

PAL = {'.': None, 'O': (30, 30, 42), 'W': (255, 255, 255), 'w': (226, 238, 252), 'b': (176, 204, 236),
       'B': (128, 166, 214)}

SNOW = [
    "......OOOO........",
    "....OOWWWWOO.OOO..",
    "...OWWWWWwwOOWWwO.",
    "..OWWWWwwwwwwwwbO.",
    ".OWWwwwwwwwwwbbbbO",
    "OWwwwwwwwwwbbbbbBO",
    "OwbbbbbbbbbbbBBBBO",
    "OOOOOOOOOOOOOOOOOO",
]
SNOW_CRACKED = [
    "......OOOO........",
    "....OOWWWOOO.OOO..",
    "...OWWWWOwwOOWWwO.",
    "..OWWWWwwOwwOwwbO.",
    ".OWWwwOwwOwwOwbbbO",
    "OWwwwwwOwwwOwbbbBO",
    "OwbbbbbbObbbOBBBBO",
    "OOOOOOOOOOOOOOOOOO",
]
# Trampolín: amarillo → hielo, grises → nieve
TRAMP = {(232, 160, 32): (110, 170, 226), (255, 225, 74): (196, 232, 255),
         (90, 97, 120): (96, 120, 160), (110, 118, 136): (150, 176, 210), (180, 188, 204): (226, 238, 252)}


def grid(rows):
    im = Image.new('RGBA', (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        assert len(r) == len(rows[0]), r
        for x, ch in enumerate(r):
            if PAL[ch]: im.putpixel((x, y), PAL[ch] + (255,))
    return im


def recolor(path, table):
    im = Image.open(path).convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if p[3] and p[:3] in table: px[x, y] = table[p[:3]] + (p[3],)
    return im


def build():
    out = {}
    for n in ('crab1.png', 'crab2.png', 'crab3.png', 'spike.png'):
        out[n] = Image.open(os.path.join(ICE_MEGA, n)).convert('RGBA')
    body = out['crab1.png']
    out['meat.png'] = body.crop((0, 0, body.width, 8))           # el caparazón sin patas
    out['lookin.png'] = body.crop((0, 4, body.width, 8))         # asoman los ojos
    out['hid.png'] = Image.new('RGBA', (body.width, 1), (0, 0, 0, 0))
    out['tramp_normal.png'] = recolor(os.path.join(ROOT, 'assets/images/trampoline/normal.png'), TRAMP)
    out['tramp_extended.png'] = recolor(os.path.join(ROOT, 'assets/images/trampoline/extended.png'), TRAMP)
    out['snow.png'] = grid(SNOW)
    out['snow_cracked.png'] = grid(SNOW_CRACKED)
    out['icicle.png'] = Image.open(os.path.join(ROOT, 'assets/images/bosses/snowboss/icicle.png')).convert('RGBA')
    return out


# ── Maqueta ──────────────────────────────────────────────────────────────────
def up(im, s): return im.resize((round(im.width * s), round(im.height * s)), Image.NEAREST)


def cover_img(sp, kind, prog=1.0):
    """La tapa de pie sobre su base (abajo = la superficie), al tamaño del juego."""
    if kind == 'spike':
        im = sp['spike.png']
    elif kind == 'tramp':
        im = up(sp['tramp_normal.png'], S)
    elif kind == 'snow':
        im = up(sp['snow.png'], S)
    elif kind == 'snow_cracked':
        im = up(sp['snow_cracked.png'], S)
    else:                                                        # carámbano: la punta hacia fuera
        im = up(sp['icicle.png'].transpose(Image.FLIP_TOP_BOTTOM), S)
        im = im.crop((0, 2 * S, im.width, im.height))            # (sin las filas vacías de la base)
    if prog < 1:
        h = max(1, round(im.height * prog))
        im = im.resize((im.width, h), Image.NEAREST)
    return im


def scene_bg(w, h, floor):
    bg = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    d = ImageDraw.Draw(bg)
    for y in range(0, h, 8):
        k = y / h
        d.rectangle((0, y, w, y + 8), fill=(int(70 + 50 * k), int(82 + 50 * k), int(140 - 10 * k)))
    d.rectangle((0, floor, w, h), fill=(226, 238, 252))
    d.rectangle((0, floor, w, floor + 4), fill=(255, 255, 255))
    return bg


def paste_bottom(canvas, im, cx, base):
    canvas.alpha_composite(im, (int(cx - im.width / 2), int(base - im.height)))


def mockup(sp, out):
    W, H = 1280, 900
    im = scene_bg(W, H, H)
    d = ImageDraw.Draw(im)
    font = ImageFont.load_default()
    ground = (226, 238, 252)

    def floor_line(y):
        d.rectangle((0, y, W, y + 64), fill=ground)
        d.rectangle((0, y, W, y + 4), fill=(255, 255, 255))

    # 1) Crabby normal vs helado, andando (escala 4) + jugador
    y1 = 150
    floor_line(y1)
    d.text((20, 10), 'CRABBY HELADO (escala 4, como el Crabby) - andar, esconderse con cada tapa, en pared y techo, y el montón de nieve que revienta', fill=(255, 255, 255), font=font)
    normal = Image.open(os.path.join(ROOT, 'assets/images/crabby/crab1.png')).convert('RGBA')
    paste_bottom(im, up(normal, S), 80, y1)
    d.text((40, 30), 'Crabby', fill=(255, 255, 255), font=font)
    pl = Image.open(os.path.join(ROOT, 'assets/images/player/monstrito1.png')).convert('RGBA')
    paste_bottom(im, up(pl, 6), 170, y1)
    x = 260
    for n in ('crab1.png', 'crab2.png', 'crab3.png'):
        paste_bottom(im, up(sp[n], S), x, y1); x += 100
    d.text((230, 30), 'Crabby helado: andar 1-3', fill=(255, 255, 255), font=font)
    # esconderse: cuerpo → meat → lookin → escondido con su tapa (crece)
    x = 620
    d.text((600, 30), 'se esconde (púa de hielo): sale la tapa, se mete', fill=(255, 255, 255), font=font)
    seq = [(sp['crab2.png'], 0.0), (sp['crab2.png'], 0.6), (sp['meat.png'], 1.0), (sp['lookin.png'], 1.0), (None, 1.0)]
    for b, pr in seq:
        c = cover_img(sp, 'spike', pr) if pr > 0 else None
        bh = 0
        if b is not None:
            bb = up(b, S); paste_bottom(im, bb, x, y1); bh = bb.height
        if c is not None: paste_bottom(im, c, x, y1 - bh + (4 if bh else 0))
        x += 130

    # 2) Las 4 tapas en el suelo, en una pared y en el techo
    kinds = [('spike', 'púa de hielo: mata'), ('tramp', 'trampolín: rebota'),
             ('snow', 'nieve: disfraz, revienta al tocarla'), ('icicle', 'carámbano: -2 vida + empujón')]
    y2 = 230
    for i, (k, label) in enumerate(kinds):
        cx = 160 + i * 310
        d.text((cx - 120, y2), label, fill=(255, 255, 255), font=font)
        # suelo
        fy = y2 + 150
        d.rectangle((cx - 130, fy, cx + 130, fy + 40), fill=ground)
        paste_bottom(im, cover_img(sp, k), cx - 60, fy)
        d.text((cx - 90, fy + 46), 'suelo', fill=(255, 255, 255), font=font)
        # pared (izquierda; la tapa apunta a la derecha)
        wx = cx + 30
        d.rectangle((wx, y2 + 20, wx + 30, y2 + 150), fill=ground)
        c = cover_img(sp, k).rotate(-90, expand=True)
        im.alpha_composite(c, (wx + 30, int(y2 + 85 - c.height / 2)))
        d.text((wx - 10, fy + 46), 'pared', fill=(255, 255, 255), font=font)
        # techo
        ty = fy + 80
        d.rectangle((cx - 130, ty, cx + 130, ty + 30), fill=ground)
        c = cover_img(sp, k).rotate(180)
        im.alpha_composite(c, (int(cx - c.width / 2), ty + 30))
        d.text((cx - 20, ty + 160), 'techo', fill=(255, 255, 255), font=font)

    # 3) El montón de nieve: escondido → se agrieta (0.25 s, sin daño) → sale
    y3 = 820
    floor_line(y3)
    d.text((20, y3 - 150), 'nieve: tocarla → se agrieta 0.25 s (aún sin daño: da tiempo a saltar) → revienta y sale (luego -1 vida + empujón; encima te lanza hacia arriba; ground pound encima = lo aplasta)', fill=(255, 255, 255), font=font)
    x = 160
    paste_bottom(im, cover_img(sp, 'snow'), x, y3); x += 220
    paste_bottom(im, cover_img(sp, 'snow_cracked'), x, y3); x += 220
    # reventando: trozos de nieve + el cangrejo saliendo
    paste_bottom(im, up(sp['meat.png'], S), x, y3)
    for dx, dy in ((-50, -70), (40, -90), (-20, -110), (60, -50), (-70, -40)):
        d.rectangle((x + dx, y3 + dy, x + dx + 12, y3 + dy + 12), fill=(255, 255, 255), outline=(30, 30, 42))
    x += 220
    paste_bottom(im, up(sp['crab2.png'], S), x, y3)
    os.makedirs(out, exist_ok=True)
    im.convert('RGB').save(os.path.join(out, 'vista_previa.png'))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--out', default=os.path.join(os.environ.get('FM_PREVIEWS', '/home/mtvemo/FlappyMonster_pruebas'),
                                                  'crabby_ice'))
    a = ap.parse_args()
    sp = build()
    os.makedirs(a.out, exist_ok=True)
    for n, im in sp.items(): im.save(os.path.join(a.out, n))
    mockup(sp, a.out)
    print('vista previa:', a.out)
    if a.apply:
        os.makedirs(DST, exist_ok=True)
        for n, im in sp.items(): im.save(os.path.join(DST, n))
        print('escrito', DST)


if __name__ == '__main__':
    main()
