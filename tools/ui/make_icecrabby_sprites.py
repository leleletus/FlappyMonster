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
#   python3 tools/ui/make_icecrabby_sprites.py --apply    # escribe assets/images/enemies/crabby_ice/
#   (--out: $FM_PREVIEWS/crabby_ice o /home/mtvemo/FlappyMonster_pruebas/crabby_ice, fuera del repo)
#
# Salida (como assets/images/enemies/crabby/ + tapas):
#   crab1/2/3.png   andar (18x13; los de assets/images/bosses/megacrabby_ice)
#   meat.png        el cuerpo sin patas, lookin.png (solo asoma), hid.png
#   hide-Sheet.png  8 cuadros 18x8: se hunde fila a fila en la superficie (esconderse / salir al revés);
#                   también sueltos: sink1..8.png (los usa el juego)
#   spike.png       púa de hielo (38x38, como crabby/spike.png)
#   tramp_normal.png / tramp_extended.png   trampolín de hielo (16x16, como trampoline/*.png)
#   snow.png        montón de nieve (18x8, estilo de la decoración snow_pile), snow_cracked.png
#   icicle.png      carámbano (8x16, el de la Gran Bola de Nieve)
import argparse
import os
import shutil

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
ICE_MEGA = os.path.join(ROOT, 'assets', 'images', 'megacrabby_ice')
DST = os.path.join(ROOT, 'assets', 'images', 'enemies', 'crabby_ice')
S = 4                                   # escala del Crabby en el juego

PAL = {'.': None, 'O': (30, 30, 42)}
# Montón de nieve: MISMO ESTILO que la decoración snow_pile (tools/ui/make_decorations.py):
# contorno azul claro (no el oscuro de los personajes), 3 tonos, base en sombra sin contorno
# abajo, 1 px de margen. Así pasa por una decoración más.
PAL.update({'o': (142, 164, 212), 'W': (244, 248, 255), 'H': (255, 255, 255), 'S': (196, 210, 240),
            'c': (110, 130, 182)})
SNOW = [
    "..................",
    ".......ooo........",
    ".....ooWHWoo.ooo..",
    "....oWWWWWWWoWHWo.",
    "...oWHWWWWWWWWWSo.",
    "..oWWWWWWWWWWWSSSo",
    ".oWHWWWWWWWWWSSSSo",
    ".oSSSSSSSSSSSSSSSo",
]
# A punto de reventar: grietas (más oscuras, para que se vean) y bultos
SNOW_CRACKED = [
    "..................",
    ".......ooo...o....",
    ".....ooWcWoo.ooo..",
    "....oWWWcWWWoWcWo.",
    "...oWHWWcWWcWWWSo.",
    "..oWWWWcWWWWcWSSSo",
    ".oWHWWcWWWWWWcSSSo",
    ".oSSSSSSSSSSSSSSSo",
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
    # Se HUNDE poco a poco (8 cuadros): el caparazón baja fila a fila dentro de la superficie
    # (se dibuja anclado abajo), en vez de pasar de golpe de meat → lookin → nada
    shell = out['meat.png']
    sheet = Image.new('RGBA', (shell.width * 8, shell.height), (0, 0, 0, 0))
    for i in range(8):
        part = shell.crop((0, 0, shell.width, shell.height - i))
        sheet.paste(part, (i * shell.width, i))
    out['hide-Sheet.png'] = sheet
    for i in range(8):                                           # (y suelto: el juego usa imágenes)
        out['sink%d.png' % (i + 1)] = sheet.crop((i * shell.width, 0, (i + 1) * shell.width, shell.height))
    out['tramp_normal.png'] = recolor(os.path.join(ROOT, 'assets/images/mechanisms/trampoline/normal.png'), TRAMP)
    out['tramp_extended.png'] = recolor(os.path.join(ROOT, 'assets/images/mechanisms/trampoline/extended.png'), TRAMP)
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
    W, H = 1280, 1000
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
    normal = Image.open(os.path.join(ROOT, 'assets/images/enemies/crabby/crab1.png')).convert('RGBA')
    paste_bottom(im, up(normal, S), 80, y1)
    d.text((40, 30), 'Crabby', fill=(255, 255, 255), font=font)
    pl = Image.open(os.path.join(ROOT, 'assets/images/player/monstrito1.png')).convert('RGBA')
    paste_bottom(im, up(pl, 6), 170, y1)
    x = 260
    for n in ('crab1.png', 'crab2.png', 'crab3.png'):
        paste_bottom(im, up(sp[n], S), x, y1); x += 100
    d.text((230, 30), 'Crabby helado: andar 1-3', fill=(255, 255, 255), font=font)
    # esconderse: sale la tapa (montón de nieve) y el caparazón se hunde fila a fila
    d.text((560, 30), 'se esconde (montón de nieve): crece la tapa y se hunde poco a poco', fill=(255, 255, 255), font=font)
    sheet = sp['hide-Sheet.png']
    fw = sheet.width // 8
    x = 560
    # (el montón crece DELANTE, desde el suelo, mientras el caparazón se hunde detrás)
    frames = [(sp['crab2.png'], 0.0)] + [(sheet.crop((i * fw, 0, (i + 1) * fw, sheet.height)), 0.25 + i * 0.11)
                                         for i in (0, 1, 3, 5, 7)] + [(None, 1)]
    for b, pr in frames:
        if b is not None: paste_bottom(im, up(b, S), x, y1)
        if pr > 0: paste_bottom(im, cover_img(sp, 'snow', min(1, pr)), x, y1)
        x += 100
    # objeto (aquí el carámbano; igual púa y trampolín): como el Crabby normal, la tapa le
    # SALE DEL LOMO y luego baja encima del caparazón mientras se hunde, hasta quedar en la superficie
    fr2 = [(sp['crab2.png'], 0.0), (sp['crab2.png'], 0.5), (sp['crab2.png'], 1.0)] + \
          [(sheet.crop((i * fw, 0, (i + 1) * fw, sheet.height)), 1.0, i) for i in (0, 2, 4, 6)] + [(None, 1.0)]
    x = 60
    yo = y1 + 135
    d.rectangle((0, yo, W, yo + 30), fill=(226, 238, 252))
    d.text((20, yo - 125), 'se esconde con un objeto (carámbano / púa / trampolín): le sale del lomo y baja con el caparazón', fill=(255, 255, 255), font=font)
    for item in fr2:
        b, pr = item[0], item[1]
        top = yo
        if b is not None:
            bb = up(b, S)
            paste_bottom(im, bb, x, yo)
            # lo alto del caparazón: donde se apoya la tapa (en la hoja de hundirse, lo que asoma)
            top = yo - bb.height + (item[2] * S if len(item) > 2 else 0)
        if pr > 0:
            c = cover_img(sp, 'icicle', pr)
            paste_bottom(im, c, x, top + 4)
        x += 110
    # 2) Las 4 tapas en el suelo, en una pared y en el techo
    kinds = [('spike', 'púa de hielo: mata'), ('tramp', 'trampolín: rebota'),
             ('snow', 'nieve: disfraz, revienta al tocarla'), ('icicle', 'carámbano: -2 vida + empujón')]
    y2 = 330
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
    y3 = 930
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
