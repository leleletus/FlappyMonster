-- assets/story/credits.lua — EL TEXTO DE LOS CRÉDITOS (docs/story/credits.md), por escenas de la película de los
-- créditos (assets/story/films.json, "credits"; la dibuja src/story/films/credits.lua). Cada escena es un bloque que
-- sube desde abajo cuando empieza su música. Líneas:
--   { head = 'clave' }     rótulo (fuente pixel, amarillo)          { name = 'TEXTO' }   nombre grande (fuente pixel)
--   { text = 'clave' }     texto traducido (puede tener \n)         { raw = 'texto' }    texto tal cual
--   { line = 'texto' }     una línea de una lista, tal cual        { small = 'texto' } / { smallk = 'clave' } pequeño
--   { gap = px }
-- `parade` = los bichos que cruzan la pantalla bajo el texto: { anim, variant, seq, scale, y (px bajo el texto), dir }
-- Las claves son de assets/lang/*.lua (credits.*); los nombres propios no se traducen.
return {
    pradera = {
        { head = 'credits.idea' }, { gap = 18 }, { name = 'DJVEMO' }, { gap = 14 }, { text = 'credits.idea_roles' },
        parade = { { anim = 'enemies/gummy', seq = 'walk', scale = 5 }, { anim = 'enemies/gummy', seq = 'walk', scale = 4, lag = 1.4 } },
    },
    costa = {
        { head = 'credits.remaster' }, { gap = 18 }, { name = 'MTVEMO' }, { gap = 6 }, { raw = '(serqwjahk)' }, { gap = 14 },
        { text = 'credits.remaster_roles' },
        parade = { { anim = 'enemies/crabby_river', seq = 'walk', scale = 5 }, { anim = 'enemies/pufferfish', seq = 'swim', scale = 4, y = -40, lag = 2 } },
    },
    fortaleza = {
        { head = 'credits.engine' }, { gap = 26 }, { name = 'LÖVE 11.5' }, { gap = 10 },
        { line = 'love2d.org  ·  zlib  ·  (c) 2006-2024 LÖVE Development Team' }, { gap = 26 },
        { head = 'credits.ports' }, { gap = 12 },
        { line = 'love-nx (Nintendo Switch homebrew)  ·  retronx-team' },
        { line = 'love-android  ·  LÖVE Development Team' },
        parade = { { anim = 'enemies/crabby_fortress', seq = 'walk', scale = 5 }, { anim = 'enemies/gummy', variant = 'fortress', seq = 'walk', scale = 4, lag = 1.2 } },
    },
    nieve = {
        { head = 'credits.libs' }, { gap = 14 },
        { line = 'baton  ·  Andrew Minnich  ·  MIT' },
        { line = 'bitser  ·  Jasmijn Wellner  ·  ISC' },
        { line = 'classic, json.lua  ·  rxi  ·  MIT' },
        { line = 'sock.lua  ·  Cameron McHenry  ·  MIT' },
        { line = 'hump.timer  ·  Matthias Richter  ·  MIT' },
        { line = 'lovesize  ·  Ricardo Bustamante de Queiroz  ·  MIT' }, { gap = 24 },
        { head = 'credits.tools' }, { gap = 12 },
        { line = 'Python  ·  Pillow  ·  NumPy  ·  SciPy' }, { line = 'FFmpeg  ·  basic-pitch  ·  Demucs' },
        parade = { { anim = 'enemies/crabby_ice', seq = 'walk', scale = 5 }, { anim = 'enemies/gummy', variant = 'ice', seq = 'walk', scale = 4, lag = 1.6 } },
    },
    cuevas = {
        { head = 'credits.bundled' }, { gap = 14 },
        { line = 'LuaJIT  ·  SDL2  ·  OpenAL Soft  ·  FreeType' },
        { line = 'libogg  ·  libvorbis  ·  ENet  ·  lua-enet' },
        { line = 'LuaSocket  ·  LZ4  ·  LodePNG  ·  stb_image' },
        { line = 'dr_flac  ·  libmpg123  ·  TinyEXR  ·  xxHash' },
        { line = 'UTF8-CPP  ·  GLAD  ·  glslang' },
        { gap = 16 }, { smallk = 'credits.licenses' }, { small = 'assets/legal/THIRD_PARTY_LICENSES.txt' },
        parade = { { anim = 'enemies/gloomy', seq = 'walk', scale = 5 }, { anim = 'enemies/gummy', variant = 'cave', seq = 'walk', scale = 4, lag = 1.3 } },
    },
    volcan = {
        { head = 'credits.font' }, { gap = 14 }, { name = 'PRESS START 2P' }, { gap = 8 },
        { line = 'CodeMan38  ·  SIL Open Font License 1.1' }, { gap = 26 },
        { head = 'credits.sound' }, { gap = 12 }, { text = 'credits.sound_desc' }, { gap = 8 }, { smallk = 'credits.trademarks' },
        parade = { { anim = 'enemies/crabby_lava', seq = 'walk', scale = 5 }, { anim = 'enemies/gummy', variant = 'magma', seq = 'walk', scale = 4, lag = 1.1 } },
    },
    crab = {
        { head = 'credits.motifs' }, { gap = 10 }, { smallk = 'credits.motifs_desc' }, { gap = 18 },
        { name = 'TENTACLE TANTRUM' }, { gap = 10 }, { name = 'WINTER FALLYMPICS' }, { gap = 12 },
        { raw = 'Jukio Kallio  ·  Daniel Hagström' },
        parade = { { anim = 'enemies/crabby', seq = 'walk', scale = 8 } },
    },
    bola = {
        { name = "IT'S ME, IT'S VERITY" }, { gap = 12 }, { raw = 'Horror Skunk' }, { gap = 26 },
        { name = 'SPIDER DANCE' }, { gap = 12 }, { raw = 'Toby Fox' }, { gap = 4 }, { smallk = 'credits.inspiration' },
        parade = { { anim = 'enemies/crabby_ice', seq = 'walk', scale = 8 } },
    },
}
