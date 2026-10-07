# The level editor

`love . --editor [assets/levels/x.json]`. A development tool, in Spanish. It uses the game's own catalogs and drawing,
so anything registered (tile, entity, decoration, prop) appears by itself — **new level objects are a schema, not
bespoke widgets**.

**Files** (`src/editor/`): `Editor.lua` (state, layers and tools, utilities, model / undo, play-test, the loop and
the LÖVE callbacks), `EditorCanvas.lua` (what each tool does on the map + drawing the map), `EditorPalette.lua` (top
bar and left panel), `EditorInspector.lua` (the right panel: fields generated from a prop schema, inspectors, tabs
Selección / Nivel / Avisos), `EditorDialogs.lua` (dialogs, boss-zone and auto-scroll tools), `EditorModel.lua` (level
data, save, `validate()`), `ui.lua` (widgets).

Keys: 1-7 layers, F1 shortcuts, F5 play-test (through `AdventureState`), Ctrl+O open, Ctrl+S save, K connect.
**Harness:** `editor_open` (`LINKS=1`, `PLAY=<level>`), `level_check` (runs the validator on every level).

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
Ctrl+O "Abrir nivel" = scrollable list (wheel / arrows + Enter) with file + level
name; hides `_*` files and `editor_playtest.json`. Test arenas live in
`tools/levelgen/arenas/` (not listed).
