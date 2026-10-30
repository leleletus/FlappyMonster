# The level editor

`love . --editor [assets/levels/x.json]`. A development tool, in Spanish. It uses the game's own catalogs and drawing,
so anything registered (tile, entity, decoration, prop) appears by itself — **new level objects are a schema, not
bespoke widgets**.

**Files** (`src/editor/`): `Editor.lua` (state, layers and tools, utilities, model / undo, play-test, the loop and
the LÖVE callbacks), `EditorCanvas.lua` (what each tool does on the map + drawing the map), `EditorPalette.lua` (top
bar and left panel), `EditorInspector.lua` (the right panel: fields generated from a prop schema, inspectors, tabs
Selección / Nivel / Avisos), `EditorDialogs.lua` (dialogs, boss-zone and auto-scroll tools), `EditorModel.lua` (level
data, save, `validate()`), `ui.lua` (widgets).

Keys: 1-7 layers, P plane (Delante / Fondo), F1 shortcuts, F5 play-test (through `AdventureState`), Ctrl+O open,
Ctrl+S save, K connect.
**Harness:** `editor_open` (`LINKS=1`, `PLAY=<level>`, `PLANE=1`), `level_check` (runs the validator on every level).

## Details

Layers (1-7): tiles, water, spikes, entities, deco, special, mini (subtiles) (`LAYERS`/`TOOLS`
at the top of Editor.lua carry their help texts). Left panel: layer, tool
(+ hint card), palette (search + collapsible categories). Right panel has tabs
Selección / Nivel / Avisos. EVERYTHING editable is drawn by
`drawPropFields(schema, obj, …)` from a prop schema: entities, decorations,
boss zones (`zoneSchema`), vents (`VENT_SCHEMA`), auto-scroll
(`AUTOSCROLL_SCHEMA`); each `group` is a collapsible section (`ui.section`),
min/max may be functions(owner), optional `onChange`. New level objects =
a schema + an inspector function in `drawSelectionTab`, not bespoke widgets.
Catalog metadata that drives the editor (no editor code needed):

- entities: `category` (ordered by `EntityTypes.CATEGORIES`: Enemigos, Jefes,
  Trampas, Mecanismos, Objetos, Directores), `description` (palette tooltip +
  inspector), `hide = 'all'` (no common props), `variant = {group, label,
  groupLabel, prop}` (several defs shown as ONE palette card + selector; X
  cycles; inspector enum changes `e.type`) — used by the 4 trampolines.
  Prop groups: the type's own groups first, then `EntityTypes.COMMON_GROUPS`.

- tiles: `TileTypes.CATEGORIES` order. UI text is Spanish WITH accents.
`ui.lua` widgets: button (opts.hint = key), toggle, number, enum (segmented
when it fits), textField (placeholder), section, tabs, hint, caption, label
(fits/ellipsizes). F1 = shortcuts overlay. `E.instances` renders entities as
in-game. `Model:validate()` → warnings (Avisos tab, clickable). F5 playtests
via `AdventureState` with `editor_playtest.json` (SP keeps reserve entities in
`self.enemies`: it only drops non-alive ones without `summonOf`).
NOTHING IS LOST (0.5.109): the editor model keeps every top-level key it does not edit itself (`EditorModel.KNOWN` = the
ones it reads and writes) in `extra` and writes them back unchanged on save AND on play-test — before, it dropped the
Crab Mega Mashup's `scenes` and `event`: play-testing it from the editor, the Gloomy's arena never went dark (the user,
2026-10-29), and saving it would have erased them. Harness `editor_open` case `conserva` loads and re-encodes every
level of `assets/levels` and checks no key is lost.
Ctrl+O "Abrir nivel" — FILTERS (0.5.108, the user: "que solo salgan de una isla u otra, de un modo u otro, y los
de jefe"): three buttons under the search field, combinable with it — **Isla** (the story world the level belongs to;
outside the story, its art island from `Isles.of`, plus `frozen_coast` → `costa_helada`), **Modo** (the online modes the
level supports, from `LevelCatalog.info`), **Solo jefes** (levels with a boss). Click = next value, Shift + click =
previous; the first of the cycle is "all". `E.levelMeta` (cached per file and modification time), `E.filterOptions`,
`E.filterLevels`; harness `editor_open` case `filtros`.
Ctrl+O "Abrir nivel" = scrollable list (wheel / arrows + Enter) with file + level
name; hides `_*` files and `editor_playtest.json`. Test arenas live in
`tools/levelgen/arenas/` (not listed). A SEARCH field on top (0.5.77, the user could not find the boss level) has the
focus as soon as the dialog opens: typing filters by file and level name (Spanish and English), ignoring accents and
capitals (`TextUtil.matches`); arrows + Enter open the highlighted match. Harness `editor_open` (`buscar`).
Saving (0.5.10, review): "Guardar como" with the name of an EXISTING level warns (and says when it is a story level,
`Worlds.LIST`) and only overwrites on the second press — it used to overwrite silently. Every editor writes through
`ToolShell.writeSafe` (temp file + rename, write result checked: a full disk no longer leaves a truncated JSON while
saying "Guardado"). Closing the window with unsaved changes warns in edit AND playtest mode, and the "close again"
only counts for 5 s. Harness `editor_open` (`guardar`).

## Background plane (0.5.87)

The level has a second plane of blocks and decorations behind everything ([art/background-plane](../art/background-plane.md)).
The editor edits ONE plane at a time, `E.plane` = `'front'` / `'bg'`:

- **Switch**: top bar "Delante | Fondo" (a single "Fondo" toggle when the window is narrower than 1180 px) and the key
  **P**. `Editor.setPlane` clears the selection; in Fondo only the layers with `bg = true` in `LAYERS` (Bloques and
  Decoración) can be chosen — the others are greyed and their keys say why. **Entities, water, spikes, mini blocks and
  the Especial layer are not available on the plane** (they always belong to the front); clicking an entity in the
  Avisos tab or in a boss zone goes back to Delante. The Conectar tool is hidden (no ON/OFF blocks there).
- **Blocks**: every tile tool (pencil, rectangle, line, fill, eyedropper, eraser, right click) reads and writes
  `Model.bgTiles` through `Model:getBg` / `setBg` (fill passes the plane's grid to `Model:flood`). Blocks that
  `BackPlane.allows` refuses are greyed in the palette, cannot be picked, and painting one only warns (once per
  stroke). The plane has no water or spike bits.
- **Decorations**: placing one in Fondo sets `plane = 'bg'`; select / erase / "already one here" only see the
  decorations of the current plane (`Model:decoAt(c, r, sub, plane)`). Placing a type that always goes to the plane
  (a big tree) from Delante switches to Fondo and says so. The decoration inspector has **Plano: Delante / Fondo**
  (types with `plane = 'bg'` show "siempre en el fondo" instead).
- **Drawing**: the plane is drawn once, clipped to the level like the sky (`renderBackPlane`, then
  `Level:render(…, true)`). In Delante everything looks as in the game; in Fondo the front (blocks, liquids, vents,
  entities, decorations) is drawn into a canvas of the view and composited at 30 % opacity, with a "PLANO DE FONDO"
  badge in the corner; overlays (grid, zones, links, routes, selection) stay opaque. The status bar and the hovered
  cell show the plane's block.
- **Model**: `bgTiles` always exists in the editor (zeros); `toData` / `encode` write it only when it has a block,
  right after `tiles`, one row per line. It is in undo snapshots and `resize` keeps it the level's size. Play-test
  (F5) saves through `encode`, so the plane is in the game.

