# Architecture overview

Flappy Monster is a LÖVE 11.x game (Lua / LuaJIT) that contains two games: the original **Flappy** mode and
**Adventure**, a platformer with a story mode, a free-play hub, a level editor and an online mode backed by an
**authoritative server**.

## The one rule everything follows

Everything that affects gameplay must behave identically in three places:

| Where | Entry | What runs there |
|---|---|---|
| Single player | `src/states/adventure/AdventureState.lua` | the whole simulation + drawing |
| Server | `server/main.lua` (`love server`) | the whole simulation for every room, no drawing; `Sound` and `Input` are stubs |
| Online client | `src/states/online/OnlineAdventureState.lua` | only PREDICTS the local player; draws everything else from server snapshots |

So the shared simulation code (`src/player/`, `src/world/`) must never touch `love.graphics`, the real `Input` or the
real `Sound` outside render functions, and everything a client draws must be derivable from what travels in
snapshots (`x, y, state, deadTimer` + each entity's `netPack`). See [netcode](netcode.md).

## Boot sequence

1. `main.lua` — the BOOTSTRAP. It is never auto-updated (like `conf.lua`): it mounts or overlays the active update
   slot over the installed game and then does `require 'game'`. See [updates-and-release](updates-and-release.md).
2. `game.lua` — the real client entry: loads `settings.lua` (global constants; it also registers the tile catalog)
   and `input.lua` (the global `Input`, built on `libs/baton.lua`), creates the fonts and the global `Sound`, registers
   every state in the state machine (`gStateMachine`), routes LÖVE callbacks (keyboard, mouse, touch in logical
   coordinates) to the current state, and installs the editor instead when run with `--editor`.
3. The first state is `update` (`UpdateState`), which goes to the title at once when offline or up to date.

## States (`src/states/`)

A state is a table derived from `src/core/BaseState.lua` (`enter(args)`, `update(dt)`, `render()`, `exit()`, input
callbacks); `src/core/StateMachine.lua` keeps a stack (`change`, `push`, `pop`): Pause is pushed over a level.

| Folder | States (registry name) |
|---|---|
| `menu/` | `UpdateState` (update), `TitleState` (title), `MainMenuState` (main_menu), `SettingsState` (settings), `AdventureModeSelectState` (adv_mode_select: Story / Online / Free Play) |
| `flappy/` | `DifficultySelectionState` (difficulty), `PlayState` (play) |
| `adventure/` | `AdventureState` (adventure: every single-player level, story or not), `FreePlayState` (free_play), `PauseState` (pause) |
| `online/` | `OnlineLoginState`, `OnlineHubState`, `OnlineRoomState`, `OnlineAdventureState`, `OnlineResultsState`, `OnlineErrorState` |
| `story/` | `StorySlotState` (story_slots), `StoryMapState` (story_map), `StoryResultsState` (story_results), `StoryFilmState` (story_film) |

`AdventureState` is the single way to play a level offline; who launches it decides what happens around it through
`args`: `level`, `returnTo`, `difficulty`, `lives`, `onFinish(result)`, `onLeave(lives)`, `onGameOver()`, `bonus`,
`shards`. The story, Free Play and the editor's F5 all use it.

## Globals

Set by `settings.lua` / `game.lua` and used everywhere: `Sound`, `Input`, `gStateMachine`, `TILE_PX` (64),
`PLAYER_SCALE` (6), `GUMMY_SCALE` (4), `ADV_GRAVITY`, `ADV_JUMP_VEL`, `ADV_MOVE_SPD`, `ADV_FRICTION`,
`ADV_AIR_FRIC`, `CAM_LERP`, `WINDOW_W` / `WINDOW_H` (logical size; `WINDOW_W` changes with the screen), fonts
`FONT_SMALL / FONT_MED / FONT_BIG`, `DEBUG_HITBOX` (F1; `FM_HITBOX=1`), `SERVER_HOST` / `SERVER_PORT`, `TILE_<NAME>`
(one per tile type), `EDITOR_VIEW` (true while the editor draws the map). The Flappy mode's own constants
(`GRAVITY`, `FLAP_VELOCITY`, `PIPE_*`, `DIFFICULTIES`) also live in `settings.lua`.

## Data-driven catalogs

Tiles, entities, decorations, game modes, music, story worlds, difficulties and languages are all catalogs: a new one
is **a file plus one name in a list** (or one entry in a data table), and the editor, the server and the client pick
it up. The generated tables in [reference/](../reference/) list what is registered today.

| Catalog | Registry | One file per type in |
|---|---|---|
| Tiles + materials | `src/world/tiles/Tiles.lua` | `src/world/tiles/types/`, `materials/` |
| Entities | `src/world/entities/Entities.lua` | `src/world/entities/types/<category>/` |
| Decorations | `src/world/decorations/Decorations.lua` | `src/world/decorations/types/` |
| Online modes | `src/world/modes/Modes.lua` | `src/world/modes/` |
| Music | `assets/music/index.json` (`src/audio/Music.lua`) | `assets/music/…` |
| Story worlds | `src/story/Worlds.lua` | — (data table) |
| Difficulties | `src/core/Difficulty.lua` | — (data table of named modifiers) |
| Languages | `src/core/Lang.lua` `LANGUAGES` | `assets/lang/<id>.lua` |

## Golden rules (verbatim from the project rules)

1. **Everything that affects gameplay must run identically in 3 places**:
   single player (`AdventureState`), the server (`server/main.lua`), and the
   online client (`OnlineAdventureState`, which only *predicts the local
   player* and *renders* everything else from snapshots).
2. Gameplay code must not touch `love.graphics` / real `Input` / real `Sound`
   outside render functions — the server stubs `Sound` (collects events),
   `Input` (per-tick bitmask stub) and, headless, `love.graphics.newImage`
   (returns a fake with real dimensions).
3. Globals used everywhere: `Sound`, `Input`, `TILE_PX`(64), `PLAYER_SCALE`(6),
   `GUMMY_SCALE`(4), `ADV_GRAVITY`, `ADV_JUMP_VEL`, `ADV_MOVE_SPD`,
   `WINDOW_W/H`, fonts `FONT_SMALL/MED/BIG` (Press Start 2P), `DEBUG_HITBOX`.
4. Visual style is 8/16-bit pixel art: integer positions (`math.floor`; the states round
   the CAMERA to whole pixels when drawing — fractional cameras left 1-px seams between
   blocks that only showed with the window scaled up), hard
   rectangles, black drop shadows offset 2-4 px, no rounded/smooth UI in-game.
5. EVERY image and sound the game uses is a real ASSET FILE (assets/images/..., assets/sounds/...),
   never only drawn/synthesized in code, so the user can edit or replace it. Generators are fine
   (tools/sounds/*.py, tools/art/ui/make_sprites.py …) as long as their output files are committed
   and loaded by the game; code only places/animates them. When a generator REDESIGNS an
   existing image, the original goes OUTSIDE the repo (`tools/art/lib/originals.py`:
   `/home/mtvemo/FlappyMonster_originals/<same path>-orig.png`, or `$FM_ORIGINALS`) and the
   generator always starts from it. `*-orig.png` is gitignored: never commit backups. The
   user's `.aseprite` source files live there too (same relative paths; gitignored), and so
   does reference audio (`music/TentacleTantrum.wav`). Design previews for the user go to
   `/home/mtvemo/FlappyMonster_pruebas/<thing>/vista_previa.png` (also outside the repo).
6. Data-driven catalogs: new tiles/entities/decorations/modes are a new file
   + one name in a list. The editor and server pick them up automatically.
7. Don't commit the many ` M` files in git status (they're mode-only changes).

## The original Unity project (reference only)

`/home/mtvemo/Escritorio/Proyecto_Unity_Exportado/ExportedProject/Assets` —
scripts in `Scripts/Assembly-CSharp/`, real inspector values in
`Scenes/Level1.unity`. Port *behaviour and timings*; the physics differ, so
don't copy speeds/forces literally (the user tunes feel by hand).
