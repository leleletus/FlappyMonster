# Where every asset lives

```
assets/
  fonts/            PressStart2P.ttf
  lang/             es.lua, en.lua
  levels/           one JSON per level (ids are used by saves and the story: never rename)
  anim/             animation sets, one JSON each, in folders that mirror images/ (editor: love . --anim;
                    generators: tools/anim/)
  enemies/          data-driven enemies: index.json + one JSON each (editor: love . --enemy)
  nav/              bot navigation graphs, one per arena (rebuilt by `run.sh bot_nav BUILD=1`)
  shaders/          water.glsl
  story/            overworld.json (world map), films.json (film timing), sets/ (film sets = real levels)
  music/            index.json (the catalog) + menus/ map/ worlds/<world>/ bosses/ jingles/ story/
  sounds/           player/ enemies/<enemy>/ (shared: enemies/common/) bosses/<boss>/ items/ mechanics/ traps/
                    water/ ambience/ jingles/ ui/ flappy/ fireworks/ story/
  images/
    player/         the monster (monstrito1-5, icon)
    enemies/<enemy>/  gummy*, crabby*, gloomy, hopper, bomb, pufferfish, mortar, wings
    bosses/<boss>/  one folder per boss + common/ (stun stars, anger symbols, target mark)
    traps/          cryo/ (Freezer), spikes/
    mechanisms/     trampoline/
    items/          star, extra life, checkpoint, food per island
    world/          tiles/ sky/ decorations/<theme>/ (+ foliage/, fx/) bubbles/ crack.png
    flappy/         pipe.png, Background.png (the Flappy mode only)
    story/          world-map sprites, features/, mirror/ (frame, glass, shards), fx/
    ui/             touch/ ping/ icons/ menus/ flashlight
    fx/             ice block, ice drop, lava fx, noise mark, snowflakes
```
Rules: lower-case names; animation strips are `<thing>-Sheet.png` (frames side by side, loaded with
`src/fx/SpriteStrip.lua`); a new image needs no registration beyond the code that loads it; a new sound needs one
`load(...)` line in `src/audio/Sound.lua`; a new track needs one entry in `assets/music/index.json`.
`project_check` fails when a path written in code does not exist.

Moving or renaming an asset: update the code, the generator that writes it and the matching file in
`FlappyMonster_originals`; installed players re-download a moved file on their next update.

## Small icons

- `src/ui/PixelIcons.lua` — small pixel icons = PNGs in assets/images/ui/icons/<name>.png (crown, mode icons skull/flag/hill: a new mode icon is just a file); drawn at integer scale with a 1-px drop shadow
