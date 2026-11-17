#!/usr/bin/env python3
# tools/art/enemies/make_puffer_skins.py — el PEZ GLOBO de cada ISLA (2026-11-16, el usuario: "que según la isla salga
# con el aspecto respectivo… con su propio detalle, como los crabbies"; docs/design/archive/giantpuffer-rework.md).
#
# LEE la hoja de la costa, RETOCADA A MANO por el usuario (assets/images/enemies/pufferfish/puffer_fish-Sheet.png:
# 4 cuadros 16x16 — nadar 1, nadar 2, medio hinchado, hinchado —) y la púa del Pez Globo Gigante
# (assets/images/bosses/giantpuffer/spine.png), y saca las otras 7 islas cambiando los PAPELES de sus colores
# (luz, medio, sombra, contorno, vientre, manchas, aletas, púas, ojo) y añadiendo el detalle de cada especie.
# NUNCA escribe la de la costa. La silueta es la misma en todos los cuadros (las animaciones y cajas no cambian);
# solo el señuelo del pez de la cueva añade píxeles fuera de ella (DETAIL_EXTRA, comprobado abajo).
#
#   python tools/art/enemies/make_puffer_skins.py             → /home/mtvemo/FlappyMonster_pruebas/pez_globo/vista_previa.png
#   python tools/art/enemies/make_puffer_skins.py --apply     → escribe <isla>-Sheet.png y <isla>-spine.png que falten
#   python tools/art/enemies/make_puffer_skins.py --apply --force   → también los que ya existen
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
SHEET = os.path.join(ROOT, 'assets', 'images', 'enemies', 'pufferfish', 'puffer_fish-Sheet.png')
SPINE = os.path.join(ROOT, 'assets', 'images', 'bosses', 'giantpuffer', 'spine.png')
PREVIEW = '/home/mtvemo/FlappyMonster_pruebas/pez_globo'
FW = 16


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# Los colores de la hoja del usuario → su papel
ROLE = {
    (248, 224, 142): 'light', (227, 184, 78): 'mid', (181, 132, 44): 'shade', (94, 59, 18): 'outline',
    (255, 244, 212): 'belly', (233, 211, 160): 'bellyS', (143, 91, 32): 'spot', (229, 139, 58): 'fin',
    (169, 86, 28): 'finS', (20, 12, 6): 'eye',
}

# Cada isla: sus tonos por papel + su detalle (`detail`). Pocos colores, zonas planas (docs/art/style-rules.md).
ISLES = {
    # pez de río: verde oliva con manchas oscuras y aletas azuladas
    'pradera': dict(light='#bcd96e', mid='#86b04a', shade='#5a8030', outline='#263d16', belly='#f3f0d2', bellyS='#d4d0a6',
                    spot='#33521d', fin='#5f9c9a', finS='#356467', spike='#f3f0d2', eye='#140c06', detail='spots'),
    # acorazado: placas de acero con remaches, aletas de estandarte
    'fortaleza': dict(light='#cdd2da', mid='#9ba4b2', shade='#6b7483', outline='#262b33', belly='#e4e0d4', bellyS='#bab5a6',
                      spot='#f2f4f7', fin='#b8423a', finS='#7a2620', spike='#e6eaf0', eye='#140c06', detail='plates'),
    # escarcha: blanco y hielo, púas de cristal
    'nieve': dict(light='#ffffff', mid='#d6edf8', shade='#9ec8df', outline='#36607c', belly='#ffffff', bellyS='#e2f1f9',
                  spot='#80bada', fin='#a2daf2', finS='#5f9fc2', spike='#b6f0ff', eye='#1a2a3a', detail='frost'),
    # de la cueva profunda: oscuro, manchas que brillan y un señuelo
    'cueva': dict(light='#5c617c', mid='#41455f', shade='#2c2f46', outline='#11121d', belly='#726c88', bellyS='#524c68',
                  spot='#8ff5d0', fin='#3a7f7a', finS='#24504d', spike='#a6f8de', eye='#d8fff0', detail='lure'),
    # basalto: negro con grietas de magma y púas de brasa
    'volcan': dict(light='#5c4b48', mid='#3b302f', shade='#271f1f', outline='#0e0909', belly='#6d5651', bellyS='#4e3d39',
                   spot='#ff8a24', fin='#e0481c', finS='#9c2a10', spike='#ffb43c', eye='#ffd040', detail='cracks'),
    # rana dardo: amarillo con bandas negras
    'jungla': dict(light='#ffe866', mid='#f5c51c', shade='#c4921a', outline='#1b1a12', belly='#fff3ac', bellyS='#dfcb72',
                   spot='#23221a', fin='#2a2920', finS='#121109', spike='#ffe866', eye='#140c06', detail='bands'),
    # de la noche: azul con motas de estrella y púas de estrella
    'estelar': dict(light='#5f6fd6', mid='#3c48aa', shade='#27307c', outline='#10143e', belly='#8f9be8', bellyS='#6874c9',
                    spot='#fff6b0', fin='#a07ae0', finS='#6a4ab0', spike='#fff6b0', eye='#0a0c22', detail='stars'),
}

# Señuelo del pez de la cueva (fuera de la silueta): por cuadro, (x, y, papel)
DETAIL_EXTRA = {
    'cueva': {0: [(10, 4, 'outline'), (11, 3, 'outline'), (12, 3, 'spot')],
              1: [(10, 4, 'outline'), (11, 3, 'outline'), (12, 3, 'spot')],
              2: [(10, 2, 'outline'), (11, 1, 'outline'), (12, 1, 'spot')],
              3: [(10, 2, 'outline'), (11, 1, 'outline'), (12, 1, 'spot')]},
}

BODY = ('light', 'mid', 'shade', 'spot')


def roles(frame):
    """Papel de cada píxel opaco del cuadro; las púas son 'belly' sueltos (sin cuerpo al lado)."""
    out = {}
    for y in range(frame.height):
        for x in range(frame.width):
            p = frame.getpixel((x, y))
            if p[3] == 0:
                continue
            out[(x, y)] = ROLE.get(p[:3], 'mid')
    inner = set(ROLE.values()) - {'outline'}
    for (x, y), r in list(out.items()):
        if r == 'belly' and not any(out.get((x + dx, y + dy)) in inner for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            out[(x, y)] = 'spike'
    return out


def detail_role(kind, x, y, r):
    """El detalle de la especie: cambia el papel de algunos píxeles del cuerpo (sin tocar la silueta)."""
    if r not in BODY:
        return r
    if kind == 'plates':                      # costura de placas (columna) y remaches donde estaban las manchas
        if x == 8 and r != 'spot':
            return 'outline'
    elif kind == 'bands':                     # bandas negras verticales
        if x in (6, 10):
            return 'spot'
        if r == 'spot':
            return 'mid'
    elif kind == 'cracks':                    # grietas: las manchas y una diagonal de magma
        if r != 'spot' and (x + 2 * y) % 7 == 0:
            return 'spot'
    elif kind == 'frost':                     # escarcha: motas claras en lo medio
        if r == 'mid' and (x * 3 + y) % 5 == 0:
            return 'light'
    elif kind == 'stars':                     # motas de estrella sueltas
        if r == 'shade' and (x + y) % 3 == 0:
            return 'spot'
    return r


def skin_frame(frame, isle, fi):
    cfg = ISLES[isle]
    out = Image.new('RGBA', frame.size, (0, 0, 0, 0))
    for (x, y), r in roles(frame).items():
        r = detail_role(cfg['detail'], x, y, r)
        out.putpixel((x, y), hx(cfg[r]))
    for x, y, r in DETAIL_EXTRA.get(isle, {}).get(fi, []):
        out.putpixel((x, y), hx(cfg[r]))
    return out


def skin_sheet(sheet, isle):
    out = Image.new('RGBA', sheet.size, (0, 0, 0, 0))
    for fi in range(sheet.width // FW):
        fr = sheet.crop((fi * FW, 0, (fi + 1) * FW, sheet.height))
        out.paste(skin_frame(fr, isle, fi), (fi * FW, 0))
    return out


def skin_spine(spine, isle):
    """La púa del jefe: contorno → contorno de la isla, cuerpo → púa, sombra → sombra, punta clara → vientre."""
    cfg = ISLES[isle]
    m = {(94, 59, 18): 'outline', (227, 184, 78): 'spike', (181, 132, 44): 'shade', (255, 244, 212): 'belly'}
    out = Image.new('RGBA', spine.size, (0, 0, 0, 0))
    for y in range(spine.height):
        for x in range(spine.width):
            p = spine.getpixel((x, y))
            if p[3]:
                out.putpixel((x, y), hx(cfg[m.get(p[:3], 'spike')]))
    return out


def check(sheet, skins):
    """Misma silueta que la original en cada cuadro (salvo DETAIL_EXTRA)."""
    bad = []
    for isle, im in skins.items():
        for fi in range(sheet.width // FW):
            extra = {(x + fi * FW, y) for x, y, _ in DETAIL_EXTRA.get(isle, {}).get(fi, [])}
            for y in range(sheet.height):
                for x in range(fi * FW, (fi + 1) * FW):
                    a, b = sheet.getpixel((x, y))[3] > 0, im.getpixel((x, y))[3] > 0
                    if a != b and (x, y) not in extra:
                        bad.append((isle, fi, x, y))
    print('silueta OK' if not bad else 'silueta DISTINTA: %s' % bad[:10])
    return not bad


def preview(sheet, spine, skins, spines):
    S, PAD = 8, 8
    names = ['costa'] + list(ISLES)
    rows = [sheet] + [skins[n] for n in ISLES]
    sp = [spine] + [spines[n] for n in ISLES]
    w = sheet.width * S + PAD * 3 + spine.width * S * 2
    h = len(rows) * (sheet.height * S + PAD) + PAD
    img = Image.new('RGBA', (w, h), (42, 70, 96, 255))
    for i, (n, r) in enumerate(zip(names, rows)):
        y = PAD + i * (sheet.height * S + PAD)
        img.alpha_composite(r.resize((r.width * S, r.height * S), Image.NEAREST), (PAD, y))
        s2 = sp[i].resize((sp[i].width * S * 2 // 2, sp[i].height * S * 2 // 2), Image.NEAREST)
        img.alpha_composite(s2, (PAD * 2 + sheet.width * S, y + 4 * S))
    os.makedirs(PREVIEW, exist_ok=True)
    path = os.path.join(PREVIEW, 'vista_previa.png')
    img.save(path)
    print('vista previa:', path, '(filas: ' + ', '.join(names) + ')')


def main():
    sheet = Image.open(SHEET).convert('RGBA')
    spine = Image.open(SPINE).convert('RGBA')
    skins = {n: skin_sheet(sheet, n) for n in ISLES}
    spines = {n: skin_spine(spine, n) for n in ISLES}
    ok = check(sheet, skins)
    preview(sheet, spine, skins, spines)
    if '--apply' in sys.argv:
        if not ok:
            sys.exit('la silueta cambió: no se escribe nada')
        force = '--force' in sys.argv
        for n in ISLES:
            for im, path in ((skins[n], os.path.join(os.path.dirname(SHEET), n + '-Sheet.png')),
                             (spines[n], os.path.join(os.path.dirname(SPINE), n + '-spine.png'))):
                if os.path.exists(path) and not force:
                    print('ya existe (sin --force no se toca):', os.path.relpath(path, ROOT))
                    continue
                im.save(path)
                print('escrito:', os.path.relpath(path, ROOT))


if __name__ == '__main__':
    main()
