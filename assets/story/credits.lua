-- assets/story/credits.lua — EL TEXTO DE LOS CRÉDITOS (docs/story/credits.md), por escenas de la película de los
-- créditos (assets/story/films.json, "credits"; la dibuja src/story/films/credits.lua). Cada escena es un bloque que
-- sube desde abajo cuando empieza su música. Líneas:
--   { head = 'clave' }     rótulo (fuente pixel, amarillo)          { name = 'TEXTO' }   nombre grande (fuente pixel)
--   { text = 'clave' }     texto traducido (puede tener \n)         { raw = 'texto' }    texto tal cual
--   { line = 'texto' }     una línea de una lista, tal cual        { small = 'texto' } / { smallk = 'clave' } pequeño
--   { gap = px }
-- `stage` = el ESCENARIO VIVO que se juega debajo del texto (src/story/LiveStage.lua; tools/levelgen/make_credits_sets.py)
-- Las claves son de assets/lang/*.lua (credits.*); los nombres propios no se traducen.
return {
    pradera = {
        { head = 'credits.idea' }, { gap = 18 }, { name = 'DJVEMO' }, { gap = 14 }, { text = 'credits.idea_roles' },
        stage = 'credits_pradera',          -- (su escenario vivo: assets/story/sets/credits_pradera.json)
    },
    costa = {
        { head = 'credits.remaster' }, { gap = 18 }, { name = 'MTVEMO' }, { gap = 6 }, { raw = '(serqwjahk)' }, { gap = 14 },
        { text = 'credits.remaster_roles' },
        stage = 'credits_costa',          -- (su escenario vivo: assets/story/sets/credits_costa.json)
    },
    fortaleza = {
        { head = 'credits.engine' }, { gap = 26 }, { name = 'LÖVE 11.5' }, { gap = 10 },
        { line = 'love2d.org  ·  zlib  ·  (c) 2006-2024 LÖVE Development Team' }, { gap = 26 },
        { head = 'credits.ports' }, { gap = 12 },
        { line = 'love-nx (Nintendo Switch homebrew)  ·  retronx-team' },
        { line = 'love-android  ·  LÖVE Development Team' },
        stage = 'credits_fortaleza',          -- (su escenario vivo: assets/story/sets/credits_fortaleza.json)
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
        stage = 'credits_nieve',          -- (su escenario vivo: assets/story/sets/credits_nieve.json)
    },
    cuevas = {
        { head = 'credits.bundled' }, { gap = 14 },
        { line = 'LuaJIT  ·  SDL2  ·  OpenAL Soft  ·  FreeType' },
        { line = 'libogg  ·  libvorbis  ·  ENet  ·  lua-enet' },
        { line = 'LuaSocket  ·  LZ4  ·  LodePNG  ·  stb_image' },
        { line = 'dr_flac  ·  libmpg123  ·  TinyEXR  ·  xxHash' },
        { line = 'UTF8-CPP  ·  GLAD  ·  glslang' },
        { gap = 16 }, { smallk = 'credits.licenses' }, { small = 'assets/legal/THIRD_PARTY_LICENSES.txt' },
        stage = 'credits_cuevas',          -- (su escenario vivo: assets/story/sets/credits_cuevas.json)
    },
    volcan = {
        { head = 'credits.font' }, { gap = 14 }, { name = 'PRESS START 2P' }, { gap = 8 },
        { line = 'CodeMan38  ·  SIL Open Font License 1.1' }, { gap = 26 },
        { head = 'credits.sound' }, { gap = 12 }, { text = 'credits.sound_desc' }, { gap = 8 }, { smallk = 'credits.trademarks' },
        stage = 'credits_volcan',          -- (su escenario vivo: assets/story/sets/credits_volcan.json)
    },
    crab = {
        { head = 'credits.motifs' }, { gap = 10 }, { smallk = 'credits.motifs_desc' }, { gap = 18 },
        { name = 'TENTACLE TANTRUM' }, { gap = 10 }, { name = 'WINTER FALLYMPICS' }, { gap = 12 },
        { raw = 'Jukio Kallio  ·  Daniel Hagström' },
        stage = 'credits_crab',          -- (su escenario vivo: assets/story/sets/credits_crab.json)
    },
    bola = {
        { name = "IT'S ME, IT'S VERITY" }, { gap = 12 }, { raw = 'Horror Skunk' }, { gap = 26 },
        { name = 'SPIDER DANCE' }, { gap = 12 }, { raw = 'Toby Fox' }, { gap = 4 }, { smallk = 'credits.inspiration' },
        stage = 'credits_bola',          -- (su escenario vivo: assets/story/sets/credits_bola.json)
    },
}
