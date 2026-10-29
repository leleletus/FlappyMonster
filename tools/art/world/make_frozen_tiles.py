#!/usr/bin/env python3
# tools/art/world/make_frozen_tiles.py
# TILES HELADOS (2026-10-29, la actualización helada): la nieve y el hielo como UNA masa continua y un paquete nuevo de
# bloques de construcción helados. Arte de 16x16 por casilla (32x32 los que cubren 2x2 casillas: `span = 2`) escalado x4.
#
# 1. Nieve y hielo por CAPAS (TileTypes.drawSkin): antes cada casilla llevaba su franja clara arriba y su sombra abajo y
#    una pared de nieve o de hielo se veía bloque a bloque (rayas). Ahora:
#      snow.png         el CUERPO de la nieve, sin franjas (se repite sin costura; 64x64: otras herramientas lo leen)
#      snow_top.png     la capa de arriba (solo en las caras al aire): almohadilla de nieve con el borde ondulado
#      snow_under.png   la sombra de debajo (solo en las caras de abajo al aire)
#      ice.png          el CUERPO del hielo, 2x2 casillas (los brillos cruzan de un bloque al de al lado)
#      ice_top.png      el filo de escarcha de arriba;  ice_under.png  lo más denso de abajo
#      ice_blend.png    franja tramada de escarcha del hielo hacia la nieve (como sand_blend.png)
#    (la nieve hacia la tierra / piedra usa las franjas de sand_blend.png: el mismo tramado)
# 2. El paquete de construcción helado (tiles 50-58):
#      frost_brick.png  ladrillo helado (2x2)          ice_rock.png     roca helada (2x2)
#      ice_brick.png    sillares de hielo opaco (2x2)  glacier_ice.png  hielo glaciar opaco en estratos (2x2)
#      snow_brick.png   bloques de nieve de iglú (2x2) frost_top.png    nieve fina encima (capa de arriba de la piedra)
#      ice_pillar.png + ice_pillar_top.png + ice_pillar_bottom.png   columna de hielo: fuste, capitel y basa
#      frost_window.png ventana helada (capa sobre el ladrillo helado; para el plano de fondo)
#      frost_platform.png  plataforma helada traspasable    ice_ledge.png  repisa de hielo traspasable (resbala)
#
# Opciones de diseño (vista previa A / B; se aplica la elegida):
#   --snow A|B   A = almohadilla gruesa con el borde ondulado (por defecto) · B = capa fina y recta
#   --ice A|B    A = brillos diagonales largos (por defecto) · B = estratos horizontales
# Sin --apply: solo la hoja de texturas en /home/mtvemo/FlappyMonster_pruebas/tiles_helados/paquete/ (la maqueta en el
# juego: tools/levelgen/arenas/make_hielo_paquete.py + run.sh level_shots).
# --apply escribe los PNG; el snow.png / ice.png de antes se guardan una vez FUERA del repo
# (FlappyMonster_originals/assets/images/world/tiles/<nombre>-antes_capas.png).
# Desde la raíz del repo:  python3 tools/art/world/make_frozen_tiles.py [--apply] [--snow A|B] [--ice A|B]
import os, sys, shutil
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib'))   # (originals.py)
import originals   # noqa: E402


def arg(name, default):
    if name in sys.argv:
        i = sys.argv.index(name)
        if i + 1 < len(sys.argv): return sys.argv[i + 1].upper()
    return default


APPLY = '--apply' in sys.argv
SNOW_OPT = arg('--snow', 'A')
ICE_OPT = arg('--ice', 'A')
T = 'assets/images/world/tiles'
PRUEBAS = '/home/mtvemo/FlappyMonster_pruebas/tiles_helados'
X = 4                                   # escala del arte


def rgb(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def new(w, h, fill=None):
    return Image.new('RGBA', (w, h), fill or (0, 0, 0, 0))


def put(im, x, y, c):
    """Pone un píxel envolviendo (las texturas se repiten sin costura)"""
    im.putpixel((x % im.width, y % im.height), c)


def hline(im, x0, x1, y, c):
    for x in range(x0, x1 + 1): put(im, x, y, c)


def vline(im, x, y0, y1, c):
    for y in range(y0, y1 + 1): put(im, x, y, c)


# ── Paletas ───────────────────────────────────────────────────────────────────────────────────────────────────────────
# Nieve: los colores del usuario (snow-orig.png) y sus tonos
SN_B, SN_L, SN_S, SN_D, SN_W = (203, 219, 252, 255), (226, 236, 255, 255), (178, 196, 238, 255), (150, 170, 222, 255), (255, 255, 255, 255)
# Hielo: los del usuario (ice-orig.png)
IC_B, IC_BUB, IC_D, IC_SH = (167, 196, 255, 255), (213, 227, 255, 255), (132, 166, 240, 255), (240, 247, 255, 255)
# Piedra helada (gris azulado, contorno de su propio color)
FS_O, FS_S, FS_M, FS_L, FS_H = rgb('343c5e'), rgb('4c5878'), rgb('606e92'), rgb('8492b6'), rgb('a8b8d8')
FR_A, FR_B = rgb('dce8fc'), rgb('ffffff')                      # escarcha / nieve fina
# Hielo opaco (sillares, glaciar, columna)
IO_O, IO_D, IO_M, IO_L, IO_H = rgb('4e70be'), rgb('6e92d6'), rgb('96baf0'), rgb('bcd6fc'), rgb('e8f2ff')
# Madera helada (la plataforma)
WD_O, WD_M, WD_L = rgb('4a3c4c'), rgb('7a6470'), rgb('9c8890')


# ── 1. Nieve ──────────────────────────────────────────────────────────────────────────────────────────────────────────
def snow_body():
    """El cuerpo: el color de la nieve, sin franjas; pocas motas lejos de los bordes (no marcan la rejilla)"""
    im = new(16, 16, SN_B)
    for x, y in ((3, 4), (11, 9), (6, 13)): put(im, x, y, SN_W)
    for x, y in ((12, 3), (4, 8), (9, 12)): put(im, x, y, SN_L)
    for x0, y in ((8, 5), (1, 11), (13, 14)):
        put(im, x0, y, SN_S); put(im, x0 + 1, y, SN_S)
    return im


def snow_top(opt):
    """Capa de arriba. A: almohadilla con el borde de abajo ondulado (2 lomitas por casilla); B: capa fina recta"""
    im = new(16, 16)
    if opt == 'B':
        hline(im, 0, 15, 0, SN_W); hline(im, 0, 15, 1, SN_L); hline(im, 0, 15, 2, SN_L)
        for x in range(0, 16, 2): put(im, x, 3, SN_S)
        return im
    prof = [4, 5, 5, 5, 5, 4, 3, 3]              # (fila del borde de abajo, por columna: lomas de 8)
    for x in range(16):
        b = prof[x % 8]
        put(im, x, 0, SN_W)
        for y in range(1, b): put(im, x, y, SN_L)
        put(im, x, b, SN_S)
    for x in (2, 11): put(im, x, 1, SN_W)
    return im


def snow_under():
    """Sombra de debajo: la cara de abajo al aire (nieve que vuela un poco)"""
    im = new(16, 16)
    hline(im, 0, 15, 15, SN_D)
    hline(im, 0, 15, 14, SN_S)
    for x in range(16):
        if x % 4 in (1, 2): put(im, x, 13, SN_S)
    return im


# ── 1. Hielo ──────────────────────────────────────────────────────────────────────────────────────────────────────────
def diag(im, x0, y0, n, c):
    """Raya diagonal hacia arriba a la derecha (envolviendo)"""
    for k in range(n): put(im, x0 + k, y0 - k, c)


def ice_body(opt):
    im = new(32, 32, IC_B)
    if opt == 'B':
        # estratos horizontales ondulados (capas de hielo), sin brillos sueltos
        for y0, c, amp in ((5, IC_BUB, 1), (13, IC_D, 1), (21, IC_BUB, 1), (27, IC_D, 0)):
            for x in range(32):
                y = y0 + (amp if (x // 6) % 2 else 0)
                put(im, x, y, c)
        for x, y in ((6, 9), (22, 17), (14, 25), (27, 2)): put(im, x, y, IC_SH)
        return im
    # A: dos parejas de brillos largos en diagonal, cruzando de una casilla a la otra
    diag(im, 3, 24, 11, IC_SH); diag(im, 4, 26, 6, IC_BUB)
    diag(im, 19, 13, 9, IC_SH); diag(im, 21, 14, 4, IC_BUB)
    for x, y in ((25, 4), (8, 8), (28, 22), (13, 29), (2, 14)): put(im, x, y, IC_BUB)      # burbujas
    for x, y in ((16, 21), (17, 22), (17, 23), (18, 24)): put(im, x, y, IC_D)              # grieta fina
    return im


def ice_top():
    im = new(16, 16)
    hline(im, 0, 15, 0, IC_SH)
    for x in range(16):
        if x % 3 != 2: put(im, x, 1, IC_BUB)
    return im


def ice_under():
    im = new(16, 16)
    hline(im, 0, 15, 15, IC_D)
    for x in range(0, 16, 2): put(im, x, 14, IC_D)
    return im


def blend_band(colors):
    """Un cuadro de transición como los de sand_blend.png: franja tramada a la IZQUIERDA (5 columnas), el resto vacío"""
    im = new(16, 16)
    dens = [16, 12, 8, 4, 2]                     # (píxeles por cada 16 filas, de fuera hacia dentro)
    order = [0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15]
    for x, n in enumerate(dens):
        rows = set(order[:n])
        for y in range(16):
            yy = (y + x * 3) % 16
            if yy in rows: put(im, x, y, colors[(x + y) % len(colors)])
    return im


# ── 2. El paquete helado ──────────────────────────────────────────────────────────────────────────────────────────────
def bricks(w, h, bw, bh, fill, hi, lo, joint, frost=None, seed=0):
    """Aparejo de ladrillos de bw x bh desplazados media pieza por hilada (se repite sin costura)"""
    im = new(w, h, fill)
    k = seed
    for row in range(h // bh):
        y0 = row * bh
        off = (bw // 2) if row % 2 else 0
        for b in range(w // bw):
            x0 = b * bw + off
            hline(im, x0, x0 + bw - 1, y0 + bh - 1, joint)              # junta de abajo
            vline(im, x0 + bw - 1, y0, y0 + bh - 1, joint)              # junta de la derecha
            hline(im, x0, x0 + bw - 2, y0, hi)                          # luz arriba y a la izquierda
            vline(im, x0, y0, y0 + bh - 2, hi)
            hline(im, x0 + 1, x0 + bw - 2, y0 + bh - 2, lo)             # sombra abajo
            k += 1
            if frost and k % 3 == 0:                                     # escarcha en alguna esquina
                hline(im, x0 + 1, x0 + 3, y0 + 1, frost); put(im, x0 + 1, y0 + 2, frost)
    return im


def frost_brick():
    return bricks(32, 32, 16, 8, FS_M, FS_L, FS_S, FS_O, frost=FR_A, seed=1)


def snow_brick():
    return bricks(32, 32, 16, 8, SN_B, SN_W, SN_S, SN_D, seed=0)


def ice_brick():
    im = bricks(32, 32, 16, 16, IO_M, IO_L, IO_D, IO_O)
    for bx, by in ((0, 0), (16, 0), (8, 16), (24, 16)):                 # un brillo en cada sillar
        diag(im, bx + 3, by + 11, 5, IO_H); put(im, bx + 4, by + 12, IO_L)
    return im


def ice_rock():
    """Como la piedra: color plano y pocas marcas; vetas de hielo claro"""
    im = new(32, 32, FS_M)
    for x, y in ((5, 6), (20, 3), (27, 17), (11, 22), (3, 28)):        # marcas cortas
        put(im, x, y, FS_S); put(im, x + 1, y, FS_S); put(im, x + 1, y + 1, FS_O)
    for x, y in ((14, 10), (25, 26), (8, 15)): put(im, x, y, FS_L)
    # escarcha metida en las grietas (manchitas; las vetas en diagonal parecían lluvia)
    for x, y in ((16, 14), (2, 19), (24, 29)):
        put(im, x, y, IO_L); put(im, x + 1, y, IO_H); put(im, x, y + 1, IO_L)
    return im


def glacier_ice():
    """Hielo glaciar OPACO en estratos (el hielo transparente en el fondo se veía fantasmal)"""
    im = new(32, 32, IO_M)
    for y0, c in ((0, IO_L), (9, IO_D), (18, IO_L), (25, IO_D)):
        for x in range(32):
            w = 1 + ((x // 5) % 2)
            for d in range(w): put(im, x, y0 + d + (1 if (x // 8) % 2 else 0), c)
    for x, y in ((6, 5), (21, 14), (12, 22), (28, 29)): put(im, x, y, IO_H)
    vline(im, 17, 3, 6, IO_O); put(im, 18, 7, IO_O)                    # grietas
    vline(im, 4, 13, 15, IO_O)
    return im


def frost_top():
    """Nieve fina sobre la piedra / el hielo opaco (capa de arriba)"""
    im = new(16, 16)
    hline(im, 0, 15, 0, FR_B)
    hline(im, 0, 15, 1, FR_A)
    for x in range(16):
        if x % 6 in (0, 1, 2): put(im, x, 2, FR_A)
        if x % 6 == 1: put(im, x, 3, FR_A)
    return im


def pillar_shaft():
    im = new(16, 16, IO_M)
    vline(im, 0, 0, 15, IO_O); vline(im, 15, 0, 15, IO_O)
    vline(im, 1, 0, 15, IO_H); vline(im, 2, 0, 15, IO_L)
    vline(im, 13, 0, 15, IO_D); vline(im, 14, 0, 15, IO_D)
    for x in (5, 9): vline(im, x, 0, 15, IO_L)                          # estrías
    for x in (6, 10): vline(im, x, 0, 15, IO_D)
    return im


def pillar_cap(bottom=False):
    im = new(16, 16)
    rows = [FR_B, IO_H, IO_L, IO_D, IO_O] if not bottom else [IO_O, IO_L, IO_M, IO_D, IO_O]
    y0 = 0 if not bottom else 11
    for i, c in enumerate(rows): hline(im, 0, 15, y0 + i, c)
    if not bottom: hline(im, 0, 15, 1, FR_A); put(im, 0, 2, IO_O); put(im, 15, 2, IO_O)
    return im


def frost_window():
    """Ventana en arco con cristal de hielo, parteluz y nieve en el alféizar (capa encima del ladrillo helado)"""
    im = new(16, 16)
    glass, shine = rgb('9cc4f4'), rgb('e8f4ff')
    x0, x1, y0, y1 = 3, 12, 2, 13                                        # (marco: 10 x 12 de arte)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            corner = (y == y0 and x in (x0, x0 + 1, x1 - 1, x1)) or (y == y0 + 1 and x in (x0, x1))
            if corner: continue
            edge = x in (x0, x1) or y in (y0, y1) or (y == y0 + 1 and x in (x0 + 1, x1 - 1))
            put(im, x, y, FS_O if edge else glass)
    for x, y in ((5, 4), (6, 4), (5, 5), (5, 6)): put(im, x, y, shine)     # brillo arriba a la izquierda
    vline(im, 8, 3, 12, FS_O)                                              # parteluz
    hline(im, 4, 11, 8, FS_O)                                              # travesaño
    hline(im, 2, 13, 14, FR_B); hline(im, 3, 12, 13, FR_A)                 # nieve en el alféizar
    return im


def frost_platform():
    """Tablones helados con nieve encima y carámbanos debajo (la losa ocupa las filas 0-5: hitbox 0.36)"""
    im = new(16, 16)
    hline(im, 0, 15, 0, FR_B)
    for x in range(16):
        put(im, x, 1, FR_A if x % 5 != 3 else WD_L)
    hline(im, 0, 15, 2, WD_L)
    hline(im, 0, 15, 3, WD_M); hline(im, 0, 15, 4, WD_M)
    hline(im, 0, 15, 5, WD_O)
    vline(im, 11, 2, 5, WD_O)                                            # junta entre tablones
    for x, n in ((3, 3), (8, 2), (14, 1)):                               # carámbanos
        for k in range(n): put(im, x, 6 + k, IO_L if k < n - 1 else FR_B)
    return im


def ice_ledge():
    """Repisa de hielo (traspasable, resbala; semitransparente al dibujarse)"""
    im = new(16, 16)
    hline(im, 0, 15, 0, IC_SH)
    hline(im, 0, 15, 1, IC_BUB)
    for y in (2, 3, 4): hline(im, 0, 15, y, IC_B)
    hline(im, 0, 15, 5, IC_D)
    diag(im, 3, 4, 3, IC_SH); diag(im, 10, 4, 3, IC_SH)
    for x, n in ((2, 2), (7, 3), (12, 2)):
        for k in range(n): put(im, x, 6 + k, IC_D if k < n - 1 else IC_BUB)
    return im


# ── Salida ────────────────────────────────────────────────────────────────────────────────────────────────────────────
def up(im):
    return im.resize((im.width * X, im.height * X), Image.NEAREST)


def build(snow_opt, ice_opt):
    return {
        'snow': snow_body(), 'snow_top': snow_top(snow_opt), 'snow_under': snow_under(),
        'ice': ice_body(ice_opt), 'ice_top': ice_top(), 'ice_under': ice_under(),
        'ice_blend': blend_band([SN_L, SN_W, SN_B]),
        'frost_brick': frost_brick(), 'ice_rock': ice_rock(), 'ice_brick': ice_brick(), 'glacier_ice': glacier_ice(),
        'snow_brick': snow_brick(), 'frost_top': frost_top(),
        'ice_pillar': pillar_shaft(), 'ice_pillar_top': pillar_cap(), 'ice_pillar_bottom': pillar_cap(True),
        'frost_window': frost_window(), 'frost_platform': frost_platform(), 'ice_ledge': ice_ledge(),
    }


BACKUP = ('snow', 'ice')            # (los únicos que ya existían: su versión de antes, fuera del repo)


def apply(tex):
    for n in BACKUP:
        src = os.path.join(T, n + '.png')
        dst = os.path.join(originals.ROOT, T, n + '-antes_capas.png')
        if os.path.exists(src) and not os.path.exists(dst):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy(src, dst)
            print('  copia de antes: ' + dst)
    for n, im in tex.items():
        p = os.path.join(T, n + '.png')
        up(im).save(p)
        print('  %-48s %dx%d' % (p, im.width * X, im.height * X))


def sheet(path, sets):
    """Hoja de las texturas (x6) por opción"""
    k = 6
    rows = []
    for title, tex in sets:
        rows.append((title, tex))
    W = 1500
    H = sum(60 + 32 * k + 40 for _ in rows) + 20
    out = new(W, H, rgb('1c2232'))
    d = ImageDraw.Draw(out)
    y = 10
    for title, tex in rows:
        d.text((10, y), title, fill=(255, 255, 255))
        y += 20
        x = 10
        for n, im in tex.items():
            big = im.resize((im.width * k // (2 if im.width > 16 else 1), im.height * k // (2 if im.width > 16 else 1)), Image.NEAREST)
            if x + big.width > W - 10:
                x = 10; y += 32 * k // 2 + 30
            out.paste(rgb('7aa0d8')[:3], (x - 1, y - 1, x + big.width + 1, y + big.height + 1))
            out.alpha_composite(big, (x, y))
            d.text((x, y + big.height + 2), n, fill=(220, 230, 255))
            x += big.width + 14
        y += 32 * k // 2 + 40
    out.save(path)
    print('  ' + path)


if __name__ == '__main__':
    tex = build(SNOW_OPT, ICE_OPT)
    os.makedirs(os.path.join(PRUEBAS, 'paquete'), exist_ok=True)
    sheet(os.path.join(PRUEBAS, 'paquete', 'hoja_texturas.png'),
          [('A (nieve: almohadilla ondulada · hielo: brillos diagonales)  [aplicada]', build('A', 'A')),
           ('B (nieve: capa fina recta · hielo: estratos)', {k: v for k, v in build('B', 'B').items() if k in ('snow_top', 'ice')})])
    if APPLY:
        print('Tiles helados (nieve %s, hielo %s):' % (SNOW_OPT, ICE_OPT))
        apply(tex)
