# Project structure

```
main.lua            BOOTSTRAP only: mounts / overlays downloaded updates, then require 'game'. Never auto-updated.
conf.lua            LÖVE window + identity. Never auto-updated.
game.lua            the client entry: globals, state registry, callback routing, --editor
settings.lua        global constants; registers the tile catalog (TILE_* ids)
input.lua           the global Input (keyboard / gamepad / touch → actions), built on libs/baton.lua
version.txt         the released version (bump = release)
Makefile            builds: lovefile, win64, switch, android (resources/ holds the runtimes and icons)

libs/               third-party: baton (input), bitser (serialisation), class, json, lovesize (scaling), sock (ENet), timer
server/             the authoritative server: main.lua (simulation, rooms, messages), updates.lua, conf.lua
assets/             everything shipped that is not code → docs/art/asset-layout.md
docs/               this documentation
tools/              development tools, never shipped → tools/README.md
  art/              image generators (enemies/ bosses/ world/ ui/ story/ lib/)
  sounds/           sound-effect generators
  music/            the Famicom engine and the track generators (+ mid/)
  levelgen/         level builders, retheme, arenas/
  tests/            the harnesses + run.sh + README.md
  video/            OST presentation videos
  deploy_server.sh  update the game server after a push

src/
  core/             BaseState, StateMachine, Lang, Settings (options.cfg), Difficulty, PlayRecorder
  audio/            Sound (effects + music playback), Music (the catalog)
  player/           PlayerAdventure (+ PlayerCollision, PlayerAir, PlayerGroundPound, PlayerRender), OnlinePlayer, DeadEyes
  flappy/           Player, Pipe (the Flappy mode's objects)
  network/          Protocol, NetworkClient, Predictor, SnapshotBuffer, Resolver, NameFilter
  world/
    level/          Level (+ LevelTiles, LevelWater, LevelRender), LevelCatalog, SubTiles, SpikeSkins, Lights
    systems/        level-wide systems: AutoScroll, Floods, BossZones, PhaseBlocks, XtraBosses, PointAreas, Noise, Explosions
    tiles/          Tiles (registry), TileCodec, TileTypes, Materials, types/, materials/
    entities/       Entities (registry)
      base/         Entity, EntityTypes, Props, Interactions, Crawler, FreeFlight, Boss, BombCore, CrabVariant, GloomyNav
      types/        enemies/ bosses/ traps/ mechanisms/ items/ directors/   — one file per type
    decorations/    Decorations (registry), DecorationTypes, DecoFx, types/
    modes/          Modes (registry), ModeTypes, hunt, race, koth
  states/           menu/ flappy/ adventure/ online/ story/   — the screens
  story/            Worlds, Save, Run, Score, Shards, BonusMatch, Film, Stage, films/
  ai/               Bot, BotNav (the King-of-the-Hill bot)
  fx/               render-side effects: Particles, Sky, Darkness, Silhouette, SpriteStrip, …
  ui/               HUD and UI pieces: View, Clip, TouchControls, BossHud, PixelFont, PixelIcons, Celebration, …
  editor/           the level editor: Editor (+ EditorCanvas, EditorPalette, EditorInspector, EditorDialogs), EditorModel, ui
  update/           Updater (downloads new versions)
```

## What must never move or be renamed

- Root files `main.lua`, `conf.lua`, `game.lua`, `input.lua`, `settings.lua`, `version.txt` and the roots `src/`,
  `libs/`, `assets/`: the update system distributes exactly that set and installed bootstraps depend on it.
- Level files in `assets/levels/` and ids of entities, tiles, decorations, modes, music tracks and story worlds:
  they are DATA in level files, saves and network messages. Confusing ids are explained in the glossary of
  [docs/README](../README.md) instead of being renamed.
- Inside `src/` and `assets/` files may move freely: update the `require` strings / paths (`project_check` finds
  what you missed). Players just download the moved files again.

## Module paths

Modules are required by their path from the repo root with slashes: `require 'src/world/level/Level'`. The server
adds the repo root to `package.path`; harnesses reach `src/` and `assets/` through symlinks.

## Split files

Four files that had grown past 1300 lines are split by system. The pattern is always the same and deliberately
simple: the ORIGINAL file is still the entry point and the public table; each part file is
`return function(Class, P) … end`, is loaded at the END of the original file, and adds methods to the same table.
`P` is a private table carrying what used to be file-level locals shared between sections (constants, small helper
functions). Call sites never changed.

| Entry file | Parts |
|---|---|
| `src/world/level/Level.lua` | `LevelTiles` (changing tiles), `LevelWater` (bubbles, vents, water bodies), `LevelRender` (drawing, decorations) |
| `src/player/PlayerAdventure.lua` | `PlayerCollision`, `PlayerAir`, `PlayerGroundPound`, `PlayerRender` |
| `src/states/online/OnlineAdventureState.lua` | `OnlineAdventureNet` (init data, snapshots, events), `OnlineAdventureRender`, `OnlineAdventureHud` |
| `src/editor/Editor.lua` | `EditorCanvas`, `EditorPalette`, `EditorInspector`, `EditorDialogs` |

Rules when editing a split file: a new method goes in the part of its system; a new file-level local that two parts
need goes through `P` (export it where it is defined: `P.name = name`; import it at the top of the part that uses
it); a local that is REASSIGNED must live in one part only (or become a field of `P`). A part must not import from
a part loaded after it.

## Naming

Code identifiers and file names are English (with a few historic Spanish level and type ids); code comments are
Spanish; editor labels are Spanish; player text comes from the language files; documentation is English.
