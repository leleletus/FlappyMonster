# Level file format (JSON)

A level is one JSON file in `assets/levels/` (the server and Free Play scan that folder; names starting with `_` are
hidden). The editor writes one tile row per line and only the props that differ from their defaults. Loaded by
`Level.fromData` in `src/world/level/Level.lua`; saved and validated by `src/editor/EditorModel.lua`. Every level
that exists: [reference/levels](../reference/levels.md).

| Key | Meaning |
|---|---|
| `name`, `name_en` (`name_<lang>`) | level name in Spanish and its translations |
| `width`, `height` | size in cells |
| `playerStart` | `[col, row]` |
| `tiles` | grid of raw cells: tile id + water + spikes (`src/world/tiles/TileCodec.lua`) |
| `bgTiles` | the BACKGROUND PLANE: same grid and encoding as `tiles`, only the block id counts; absent = no plane. The editor writes it (one row per line) only when the plane has a block — [art/background-plane](../art/background-plane.md) |
| `subtiles` | mini blocks: `{col, row, sub 1..4, kind, solid}` |
| `entities` | placements `{type, col, row, sub, props}` (also floods, point zones, boss walls…) |
| `foliage` | decorations `{type, col, row, sub, flip, layer, plane, …}` (the key is historic: it means decorations); `"plane": "bg"` = on the background plane (types with `plane = 'bg'`, the big trees, always are and do not write it) |
| `vents` | oxygen vents |
| `bossZones` | `{id, col, row, w, h, music, event}` (`event`: driven by a director, it does not start by itself) |
| `links`, `blockLinks` | ON/OFF Activator → activatable entity (`to` = id) / → ON/OFF Blocks |
| `autoScroll` | `{startCol, endCol, speed, width, margin, countdown}` |
| `xtraBosses` | optional explicit placements of the second boss when `bossExtra` is on (no difficulty sets it since 0.5.24; default: mirrored) |
| `background`, `time`, `clouds`, `depth`, `surfaceRow` | sky: surface biome, day / dusk / night, depth biome and the surface line |
| `light`, `dark`, `echo`, `snow`, `spikeSkin` | light mood, dark level, echo, snowfall, spike look |
| `scenes` | parts of the level with their own sky and light: `{col, w, background, time, clouds, light, dark, snow, echo, spikeSkin, depth, surfaceRow}`; `Level:applyScene(i)` (`src/world/level/Scenes.lua`) — the Crab Mega Mashup stitches five arenas |
| `event` | an EVENT level (Free Play shows it first, highlighted: `LevelCatalog.EVENTS`; boss-fight help on every difficulty) |
| `music` | catalog id of the level track |
| `modes`, `matchTime` | whitelist of online modes; seconds for timed modes |
| `parTime` | target time in seconds for the story results (0 / absent = automatic by width) |
| `peaceful` | harmless enemies (test galleries); never listed online |
| `coldWater` | seconds: the level's TILE water freezes whoever stays in it that long ([water-and-floods](../gameplay/water-and-floods.md#freezing-water-flood-prop-cold-level-key-coldwater); floods have their own prop `cold`) |
| `openTop` | nothing solid ABOVE the level (outside the map is solid everywhere else) and its boss zones may start above row 1 (the credits' live stages: no ceiling a few cells over the ground) |

Level ids (file names) are referenced by `src/story/Worlds.lua`, by saves and by online rooms: **do not rename
level files**. Test arenas that are not game levels live in `tools/levelgen/arenas/`.

## Notes

`{name,width,height,playerStart:[c,r],tiles:[[raw...]],entities:[...],
foliage:[...],vents:[...]}` (+ `bossZones:[...]`, see below). Editor writes
one tile row per line and only non-default props.

- **Harmless test levels**: level JSON `"peaceful": true` (editor Nivel → Modos de juego → "Enemigos inofensivos
  (prueba)") → `pa.peaceful` (set in `PlayerAdventure:update` from the level) → `Interactions.check` drops 'hurt' /
  'kill' (stomps, bounces, pickups still work; bosses that hit from their own update are not covered). Never listed
  in an online mode (`LevelCatalog`). `assets/levels/EnemyTest.json` (the user's enemy gallery, Free Play): every Gummy,
  Crabby (+ Gloomy) and Hopper skin, each species in island order. Harness `mechanics inofensivos`.
