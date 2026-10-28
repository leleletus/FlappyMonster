#!/usr/bin/env python3
# LA BALANZA y LA CAJA (mecanismos nuevos, aprobados por el usuario en 0.5.67 — diseño en curso).
#   BALANZA: dos platillos colgados de una cuerda que pasa por una polea: el peso baja uno y sube el otro; un ground
#   pound en uno lanza lo que haya en el otro. Piezas (1 casilla = 16 px de arte, ×4 en el juego):
#     platillo 48x8 (3 casillas) · cuerda 4x8 (se repite en vertical) · polea 16x16 (2 cuadros: gira) · polea de las
#     esquinas 10x12 (2 cuadros; `--corner` escribe solo esas)
#   CAJA: se empuja andando contra ella, se sube encima y pesa en la balanza. 16x16 + 4 trozos de 8x8 (al romperse).
# Un aspecto por isla: pradera madera · costa madera de deriva y cabos · fortaleza hierro con remaches · nieve hielo ·
# cueva piedra con un cristal que brilla · volcán basalto con grietas de lava.
# Estilo (docs/art/style-rules.md): contorno = el tono más oscuro de su color, brillo arriba-izquierda, sombra abajo-derecha.
#   python3 tools/art/world/make_scale_box.py            → vistas previas en FlappyMonster_pruebas/nuevos/balanza_caja/
#   python3 tools/art/world/make_scale_box.py --apply    → assets/images/mechanisms/scale/<isla>-*.png, …/box/<isla>.png
#                                                           (+ la caja pequeña: …/box/<isla>-small.png y -small-bits-Sheet.png)
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
PRUEBAS = os.path.join(os.environ.get('FM_PRUEBAS', '/home/mtvemo/FlappyMonster_pruebas'), 'nuevos', 'balanza_caja')
OUT_SCALE = os.path.join(ROOT, 'assets', 'images', 'mechanisms', 'scale')
OUT_BOX = os.path.join(ROOT, 'assets', 'images', 'mechanisms', 'box')


def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# papeles: o contorno · s sombra · b cuerpo · h brillo · x/y acentos (veta, remache, cristal, lava…) · r cuerda / cadena
ISLES = {
    'pradera':   dict(o='4a2c1a', s='7c4a28', b='a86c3c', h='d09858', x='6a3c20', y='7cc850', r='c8a060', R='7c5a30', bg='8cc8f0'),
    'costa':     dict(o='4c3a2a', s='8a7058', b='b49a7c', h='dccaa8', x='7c6248', y='3cb4b4', r='e8d8b0', R='a08c64', bg='9cdcf0'),
    'fortaleza': dict(o='242830', s='4c5260', b='747c8c', h='a8b0be', x='343842', y='c8ccd6', r='8a8f9c', R='4c5260', bg='8a8ea8'),
    'nieve':     dict(o='3c6a9c', s='78acde', b='bee4fa', h='ecfaff', x='a8d0f0', y='ffffff', r='e4eef6', R='9cb8d0', bg='b8d4f0'),
    'cueva':     dict(o='2a2438', s='4a4060', b='6c6088', h='9488b0', x='3a3250', y='b4f4ff', r='a89880', R='6a5c48', bg='3a3450'),
    'volcan':    dict(o='140e10', s='2c2224', b='443438', h='60504e', x='ff8a28', y='ffd23c', r='5c5052', R='2c2224', bg='6a2c2c'),
}


class G:
    def __init__(self, w, h): self.w, self.h, self.g = w, h, [['.'] * w for _ in range(h)]
    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h: self.g[y][x] = c
    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w): self.put(xx, yy, c)
    def block(self, x, y, w, h):
        """Un bloque con el estilo de la casa: contorno, brillo arriba-izquierda, sombra abajo-derecha"""
        self.rect(x, y, w, h, 'b')
        self.rect(x + 1, y + 1, w - 2, 1, 'h'); self.rect(x + 1, y + 1, 1, h - 2, 'h')
        self.rect(x + 1, y + h - 2, w - 2, 1, 's'); self.rect(x + w - 2, y + 1, 1, h - 2, 's')
        self.rect(x, y, w, 1, 'o'); self.rect(x, y + h - 1, w, 1, 'o'); self.rect(x, y, 1, h, 'o'); self.rect(x + w - 1, y, 1, h, 'o')
    def img(self, pal):
        im = Image.new('RGBA', (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                c = self.g[y][x]
                if c != '.': im.putpixel((x, y), rgb(pal[c]))
        return im


# ── El PLATILLO (48x8): la tabla, con lo de cada isla, y una argolla en cada punta para la cuerda ──
def pan(isle):
    g = G(48, 8)
    g.block(0, 2, 48, 6)
    if isle in ('pradera', 'costa'):                       # tablones: juntas verticales y vetas
        for x in (12, 24, 36): g.rect(x, 3, 1, 4, 'o')
        for x in (5, 17, 29, 41): g.put(x, 4, 'x'); g.put(x + 1, 4, 'x')
        if isle == 'pradera':
            for x in (3, 4, 44): g.put(x, 1, 'y')                    # (unas briznas de hierba)
            g.put(4, 0, 'y')
        else:
            for x in (11, 12, 13, 35, 36, 37): g.put(x, 4, 'r')      # (cabos atando los tablones)
    elif isle == 'fortaleza':                              # bandeja de hierro con remaches
        for x in (3, 10, 17, 24, 31, 38, 44): g.put(x, 4, 'y'); g.put(x, 5, 'x')
    elif isle == 'nieve':                                  # losa de hielo: brillos en diagonal y escarcha arriba
        for x in (6, 7, 20, 21, 33, 34): g.put(x, 3, 'y'); g.put(x + 1, 4, 'y')
        for x in range(2, 46, 3): g.put(x, 1, 'y')
    elif isle == 'cueva':                                  # losa de piedra con un cristal que brilla
        for x in (8, 26, 39): g.put(x, 5, 'x'); g.put(x + 1, 4, 'x')
        g.rect(30, 0, 2, 2, 'y'); g.put(31, 2, 'y')
    elif isle == 'volcan':                                 # basalto con grietas de lava
        for x, y in ((7, 3), (8, 4), (9, 4), (10, 5), (30, 4), (31, 3), (32, 4), (41, 5)): g.put(x, y, 'x')
        g.put(9, 5, 'y'); g.put(31, 4, 'y')
    # la argolla del CENTRO, de donde cuelga la cuerda
    g.rect(22, 0, 4, 1, 'R'); g.put(22, 1, 'R'); g.put(25, 1, 'R')
    return g.img(ISLES[isle])


# ── La CUERDA (4x8, se repite): trenzada en las islas de madera; cadena en fortaleza y volcán ──
def rope(isle):
    g = G(4, 8)
    if isle in ('fortaleza', 'volcan'):
        for y0 in (0, 4):                                  # eslabones: uno de frente, otro de canto
            g.rect(1, y0, 2, 1, 'r'); g.rect(1, y0 + 2, 2, 1, 'r'); g.put(0, y0 + 1, 'r'); g.put(3, y0 + 1, 'r')
            g.put(1, y0 + 3, 'R'); g.put(2, y0 + 3, 'R')
    else:
        for y in range(8):                                 # trenzado: dos hebras que se cruzan
            g.put(1, y, 'r' if y % 4 < 2 else 'R'); g.put(2, y, 'R' if y % 4 < 2 else 'r')
        if isle == 'nieve': g.put(1, 3, 'y')
    return g.img(ISLES[isle])


# ── La POLEA (16x16, 2 cuadros: gira) ──
def pulley(isle):
    out = Image.new('RGBA', (32, 16))
    pal = ISLES[isle]
    for f in range(2):
        g = G(16, 16)
        cx, cy = 7.5, 7.5
        for y in range(16):
            for x in range(16):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= 7.2:
                    g.put(x, y, 'o' if d > 6.2 else ('h' if (x - cx) + (y - cy) < -4 else ('s' if (x - cx) + (y - cy) > 4 else 'b')))
                if 2.2 < d < 3.2: g.put(x, y, 'x')
        # radios (giran: en el 2º cuadro, a 45º)
        if f == 0:
            g.rect(7, 2, 2, 12, 'x'); g.rect(2, 7, 12, 2, 'x')
        else:
            for k in range(-4, 5): g.put(int(cx + k), int(cy + k), 'x'); g.put(int(cx + k), int(cy - k), 'x')
        g.rect(6, 6, 4, 4, 'R'); g.rect(7, 7, 2, 2, 'y' if isle in ('cueva', 'volcan') else 'h')     # el eje
        g.rect(6, 0, 4, 1, 'R'); g.rect(7, 1, 2, 5, 'R')                                    # la horquilla (cuelga del techo)
        out.paste(g.img(pal), (f * 16, 0))
    return out


# ── La POLEA DE LA ESQUINA (10x12, 2 cuadros: gira con la grande; 0.5.87, el usuario: "en cada esquina donde la cuerda
# se dobla no hay nada que la agarre") — la misma rueda, más pequeña, con su horquilla; `pal` = la paleta de la isla
def corner(pal, mossy=False):
    out = Image.new('RGBA', (20, 12))
    for f in range(2):
        g = G(10, 12)
        cx, cy = 4.5, 7.0
        for y in range(12):
            for x in range(10):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= 4.6:
                    g.put(x, y, 'o' if d > 3.7 else ('h' if (x - cx) + (y - cy) < -2 else ('s' if (x - cx) + (y - cy) > 2 else 'b')))
        if f == 0:
            g.rect(4, 4, 2, 6, 'x'); g.rect(2, 6, 6, 2, 'x')
        else:
            for k in range(-2, 3): g.put(int(cx + k), int(cy + k), 'x'); g.put(int(cx + k), int(cy - k), 'x')
        g.rect(4, 6, 2, 2, 'R')                                                              # el eje
        g.rect(3, 0, 4, 1, 'R'); g.rect(4, 1, 2, 3, 'r' if mossy else 'R')                  # la horquilla
        if mossy: g.put(2, 10, 'y'); g.put(7, 10, 'y')
        out.paste(g.img(pal), (f * 10, 0))
    return out


# ── La CAJA (16x16) y sus 4 trozos ──
def box(isle):
    g = G(16, 16)
    g.block(0, 0, 16, 16)
    if isle == 'pradera':                                  # caja de madera: marco y aspa
        g.rect(1, 1, 14, 2, 's'); g.rect(1, 13, 14, 2, 's')
        for k in range(3, 13): g.put(k, k, 'x'); g.put(k + 1, k, 'x')
        for x in (3, 12): g.put(x, 2, 'h')
    elif isle == 'costa':                                  # caja de deriva con un cabo alrededor
        for y in (4, 8, 12): g.rect(1, y, 14, 1, 'x')
        g.rect(7, 1, 2, 14, 'r'); g.rect(1, 7, 14, 2, 'r'); g.rect(6, 6, 4, 4, 'R')
    elif isle == 'fortaleza':                              # caja de hierro: remaches en las esquinas y una placa
        for x, y in ((3, 3), (12, 3), (3, 12), (12, 12)): g.put(x, y, 'y'); g.put(x + 1, y + 1, 'x')
        g.rect(5, 6, 6, 4, 's'); g.rect(6, 7, 4, 2, 'x')
    elif isle == 'nieve':                                  # bloque de hielo: transparencia con brillos y una burbuja
        for k in range(3, 9): g.put(k, 11 - k, 'y')
        g.put(10, 10, 'y'); g.put(11, 9, 'h'); g.rect(4, 4, 2, 1, 'y')
    elif isle == 'cueva':                                  # bloque de piedra con una runa que brilla
        for x, y in ((7, 4), (8, 4), (6, 5), (9, 5), (7, 6), (8, 6), (7, 7), (8, 8), (7, 9), (8, 10), (6, 11), (9, 11)): g.put(x, y, 'y')
        g.put(3, 12, 'x'); g.put(12, 3, 'x')
    elif isle == 'volcan':                                 # basalto con una grieta de lava
        for x, y in ((3, 4), (4, 5), (5, 5), (6, 6), (7, 7), (7, 8), (8, 9), (9, 9), (10, 10), (11, 11)): g.put(x, y, 'x')
        g.put(6, 6, 'y'); g.put(8, 9, 'y')
    whole = g.img(ISLES[isle])
    # los trozos al romperse: los 4 cuartos, un poco desmigados
    bits = Image.new('RGBA', (32, 8))
    for i, (sx, sy) in enumerate(((0, 0), (8, 0), (0, 8), (8, 8))):
        q = whole.crop((sx, sy, sx + 8, sy + 8))
        px = q.load()
        for (a, b) in ((7, 0), (0, 7), (7, 7), (6, 7))[i:i + 2]: px[a, b] = (0, 0, 0, 0)
        bits.paste(q, (i * 8, 0))
    return whole, bits


def small_box(isle):
    """La CAJA PEQUEÑA (10x10, se carga): la misma caja de cada isla en pequeño, con un solo detalle; y sus 4 trozos
    de 5x5 (20x5)"""
    g = G(10, 10)
    g.block(0, 0, 10, 10)
    if isle == 'pradera':                                  # tablas con una diagonal
        for k in range(2, 8): g.put(k, k, 'x')
    elif isle == 'costa':                                  # el cabo en cruz
        g.rect(4, 1, 2, 8, 'r'); g.rect(1, 4, 8, 2, 'r'); g.rect(4, 4, 2, 2, 'R')
    elif isle == 'fortaleza':                              # cuatro remaches
        for x, y in ((2, 2), (7, 2), (2, 7), (7, 7)): g.put(x, y, 'y')
    elif isle == 'nieve':                                  # un brillo de hielo
        for k in range(2, 6): g.put(k, 7 - k, 'y')
    elif isle == 'cueva':                                  # un punto de runa
        g.rect(4, 3, 2, 1, 'y'); g.rect(4, 5, 2, 1, 'y'); g.put(4, 4, 'y'); g.put(5, 6, 'y')
    elif isle == 'volcan':                                 # una grietita de lava
        for x, y in ((2, 3), (3, 4), (4, 4), (5, 5), (6, 6), (7, 7)): g.put(x, y, 'x')
        g.put(4, 4, 'y')
    whole = g.img(ISLES[isle])
    bits = Image.new('RGBA', (20, 5))
    for i, (sx, sy) in enumerate(((0, 0), (5, 0), (0, 5), (5, 5))):
        q = whole.crop((sx, sy, sx + 5, sy + 5))
        q.load()[(4, 0) if i % 2 else (0, 4)] = (0, 0, 0, 0)
        bits.paste(q, (i * 5, 0))
    return whole, bits


def preview(parts):
    S = 6
    rows = []
    for isle, (p, r, pu, bx, bits) in parts.items():
        bg = Image.new('RGBA', (110, 44), rgb(ISLES[isle]['bg']))
        # una balanza montada: polea arriba, dos cuerdas, un platillo abajo y otro arriba, una caja en el de abajo
        bg.paste(pu.crop((0, 0, 16, 16)), (47, 1), pu.crop((0, 0, 16, 16)))
        for y in range(9, 30, 8): bg.paste(r, (34, y), r)
        for y in range(9, 18, 8): bg.paste(r, (74, y), r)
        bg.paste(p, (12, 34), p)                      # (el de la izquierda, abajo: con la caja)
        bg.paste(p, (52, 20), p)
        bg.paste(bx, (20, 18), bx)
        bg.paste(pu.crop((16, 0, 32, 16)), (92, 26), pu.crop((16, 0, 32, 16)))   # (la polea girada)
        bg.paste(bits, (78, 4), bits)
        sb, sbits = small_box(isle)
        bg.paste(sb, (94, 12), sb); bg.paste(sbits, (86, 36), sbits)
        rows.append(bg.resize((bg.width * S, bg.height * S), Image.NEAREST))
    out = Image.new('RGBA', (rows[0].width, sum(r.height for r in rows)))
    y = 0
    for r in rows: out.paste(r, (0, y)); y += r.height
    return out


def gif(isle, p, r, pu, bx, path):
    """La balanza moviéndose: la caja baja su lado; luego un ground pound la lanza (sube y vuelve a caer)"""
    S = 5
    pal = ISLES[isle]
    frames, dur = [], []
    import math
    seq = [(i / 12) for i in range(13)] + [1 - i / 4 for i in range(5)] + [0.0] * 4
    for n, u in enumerate(seq):
        cv = Image.new('RGBA', (110, 60), rgb(pal['bg']))
        left = 40 - int(14 * u); right = 12 + int(14 * u)          # (y de cada platillo: u=1 → izquierda abajo)
        pf = pu.crop(((n % 2) * 16, 0, (n % 2) * 16 + 16, 16))
        cv.paste(pf, (47, 0), pf)
        for y in range(9, left, 8): cv.paste(r, (34, y), r)
        for y in range(9, right, 8): cv.paste(r, (74, y), r)
        cv.paste(p, (12, left), p)
        cv.paste(p, (52, right), p)
        bxy = left - 16 - (int(10 * math.sin((n - 13) / 4 * math.pi)) if 13 <= n <= 17 else 0)
        cv.paste(bx, (24, bxy), bx)
        frames.append(cv.resize((cv.width * S, cv.height * S), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
        dur.append(110)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=dur, loop=0, disposal=2)


if __name__ == '__main__':
    if '--corner' in sys.argv:                             # (solo las poleas de las esquinas: no rehace lo demás)
        os.makedirs(OUT_SCALE, exist_ok=True)
        for isle, pal in ISLES.items():
            corner(pal).save(os.path.join(OUT_SCALE, f'{isle}-corner-Sheet.png'))
        print('  ' + OUT_SCALE + '/<isla>-corner-Sheet.png')
        sys.exit(0)
    parts = {}
    for isle in ISLES:
        bx, bits = box(isle)
        parts[isle] = (pan(isle), rope(isle), pulley(isle), bx, bits)
    if '--apply' in sys.argv:
        os.makedirs(OUT_SCALE, exist_ok=True); os.makedirs(OUT_BOX, exist_ok=True)
        for isle, (p, r, pu, bx, bits) in parts.items():
            p.save(os.path.join(OUT_SCALE, f'{isle}-pan.png')); r.save(os.path.join(OUT_SCALE, f'{isle}-rope.png'))
            pu.save(os.path.join(OUT_SCALE, f'{isle}-pulley-Sheet.png'))
            corner(ISLES[isle]).save(os.path.join(OUT_SCALE, f'{isle}-corner-Sheet.png'))
            bx.save(os.path.join(OUT_BOX, f'{isle}.png')); bits.save(os.path.join(OUT_BOX, f'{isle}-bits-Sheet.png'))
            sb, sbits = small_box(isle)
            sb.save(os.path.join(OUT_BOX, f'{isle}-small.png')); sbits.save(os.path.join(OUT_BOX, f'{isle}-small-bits-Sheet.png'))
        print('  ' + OUT_SCALE + '  ·  ' + OUT_BOX)
    os.makedirs(PRUEBAS, exist_ok=True)
    preview(parts).save(os.path.join(PRUEBAS, 'vista_previa.png'))
    for isle, (p, r, pu, bx, bits) in parts.items(): gif(isle, p, r, pu, bx, os.path.join(PRUEBAS, f'anim_{isle}.gif'))
    print('  ' + PRUEBAS)
