"""Originales de las imágenes que rediseñan los generadores (retouch_bomb,
make_snow_sprites, make_decorations...): se guardan FUERA del repositorio, en
../FlappyMonster_originals/<misma ruta>-orig.png (o $FM_ORIGINALS), una sola
vez, y los generadores siempre parten de ellos. Nunca entran en los commits.
"""
import os, shutil

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
ROOT = os.environ.get('FM_ORIGINALS') or os.path.join(os.path.dirname(REPO), 'FlappyMonster_originals')


def path(asset):
    """Ruta del original de `asset` (relativa a la raíz del repo)."""
    rel = os.path.relpath(os.path.abspath(asset), REPO)
    base, ext = os.path.splitext(rel)
    return os.path.join(ROOT, base + '-orig' + ext)


def keep(asset):
    """Guarda el original la primera vez (si el asset existe). Devuelve (ruta, recién guardado)."""
    o = path(asset)
    if os.path.exists(o):
        return o, False
    if not os.path.exists(asset):
        return o, False
    os.makedirs(os.path.dirname(o), exist_ok=True)
    shutil.copy(asset, o)
    return o, True
