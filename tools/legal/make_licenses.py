#!/usr/bin/env python3
# tools/legal/make_licenses.py — junta en assets/legal/THIRD_PARTY_LICENSES.txt los TEXTOS COMPLETOS de las licencias
# de todo lo ajeno que va dentro del juego (docs/story/credits.md): varias (MIT, zlib, ISC, OFL, LGPL) piden que el
# texto acompañe a cada copia; los créditos solo dicen los nombres y remiten a este archivo.
#   · LÖVE y lo que trae dentro (resources/win64/love/license.txt: LuaJIT, SDL2, OpenAL Soft, FreeType...)
#   · las librerías de libs/ (cada una con su texto, sacado de la cabecera del propio archivo)
#   · la fuente Press Start 2P (SIL OFL 1.1: tools/legal/OFL-1.1.txt)
# Si se añade una librería o un recurso ajeno: su entrada en LIBS (o un archivo de texto aquí) y volver a ejecutarlo.
#   python3 tools/legal/make_licenses.py
import os, re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'assets', 'legal', 'THIRD_PARTY_LICENSES.txt')
HERE = os.path.dirname(os.path.abspath(__file__))

MIT = '''Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.'''


def header(path, start, end):
    """El bloque de licencia de la cabecera de un archivo de libs/ (entre dos marcas), sin la sangría ni los --"""
    s = open(os.path.join(ROOT, path), encoding='utf-8').read()
    a = s.index(start)
    b = s.index(end, a + len(start))
    lines = s[a:b].splitlines()
    out = [re.sub(r'^\s*(--\s?)?', '', l).rstrip() for l in lines]
    while out and not out[0].strip(): out.pop(0)
    while out and not out[-1].strip(): out.pop()
    return '\n'.join(out)


# (nombre, de dónde sale, licencia, texto)
LIBS = [
    ('baton (libs/baton.lua) — https://github.com/tesselode/baton', 'MIT', header('libs/baton.lua', 'MIT License', ']]')),
    ('bitser (libs/bitser.lua) — https://github.com/gvx/bitser', 'ISC', header('libs/bitser.lua', 'Copyright', ']]')),
    ('classic (libs/class.lua is based on it) — https://github.com/rxi/classic', 'MIT',
     'Copyright (c) 2014, rxi\n\n' + MIT),
    ('json.lua (libs/json.lua) — https://github.com/rxi/json.lua', 'MIT', header('libs/json.lua', 'Copyright', 'local json')),
    ('sock.lua (libs/sock.lua) — https://github.com/camchenry/sock.lua', 'MIT', header('libs/sock.lua', 'MIT License', ']]')),
    ('hump.timer (libs/timer.lua) — https://github.com/vrld/hump', 'MIT', header('libs/timer.lua', 'Copyright', ']]')),
    ('lovesize (libs/lovesize.lua) — https://github.com/RicardoBusta/lovesize', 'MIT',
     'Copyright (c) 2018 Ricardo Bustamante de Queiroz\n\n' + MIT),
]


def main():
    parts = ['''FLAPPY MONSTER — THIRD-PARTY LICENSES / LICENCIAS DE TERCEROS
================================================================

Flappy Monster: original idea by djvemo; remastered by mtvemo (serqwjahk).
This file lists every third-party component distributed with the game and the full text of its license.
Este archivo recoge todo lo ajeno que se distribuye con el juego y el texto completo de su licencia.

Contents / Índice
  1. LÖVE (the game engine) and the libraries bundled with it
  2. Ports: love-nx (Nintendo Switch homebrew) and love-android
  3. Lua libraries included in the game (libs/)
  4. Font: Press Start 2P
  5. Music references and trademarks
''']
    parts.append('\n\n1. LÖVE AND ITS BUNDLED LIBRARIES\n' + '=' * 33 + '\n\n' +
                 open(os.path.join(ROOT, 'resources', 'win64', 'love', 'license.txt'), encoding='utf-8', errors='replace').read().strip())
    parts.append('''

2. PORTS
========

love-nx (LÖVE for Nintendo Switch homebrew) — https://github.com/retronx-team/love-nx — retronx-team.
A port of LÖVE: distributed under LÖVE's zlib license (section 1).

love-android — https://github.com/love2d/love-android — LÖVE Development Team.
Distributed under LÖVE's zlib license (section 1) and the licenses of the libraries it bundles (section 1).''')
    libs = ['\n\n3. LUA LIBRARIES (libs/)\n' + '=' * 24]
    for name, lic, text in LIBS:
        libs.append('\n\n--- %s  [%s]\n\n%s' % (name, lic, text))
    parts.append(''.join(libs))
    parts.append('\n\n4. FONT: PRESS START 2P (assets/fonts/PressStart2P.ttf) — by CodeMan38 (Cody "CodeMan38" Boisclair)\n' +
                 '=' * 40 + '\n\n' + open(os.path.join(HERE, 'OFL-1.1.txt'), encoding='utf-8').read().strip())
    parts.append('''

5. MUSIC REFERENCES AND TRADEMARKS
==================================

The game's music is original and was synthesised by the game's own tools. Some tracks quote short motifs of, or
were inspired by, these works (credited with thanks; the rights belong to their authors):
  · "Tentacle Tantrum" and "Winter Fallympics" — Jukio Kallio & Daniel Hagström
  · "It's Me, It's Verity" — Horror Skunk
  · "Spider Dance" — Toby Fox (inspiration for an effect)
The sound imitates the Ricoh 2A03 (NES / Famicom), Konami VRC6 and Namco 163 sound chips. Nintendo, NES, Famicom,
Nintendo Switch, Konami and Namco are trademarks of their respective owners. Flappy Monster is not affiliated with,
endorsed or sponsored by any of them.
''')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8').write(''.join(parts))
    print('  → %s (%d líneas)' % (os.path.relpath(OUT, ROOT), ''.join(parts).count('\n')))


if __name__ == '__main__':
    main()
