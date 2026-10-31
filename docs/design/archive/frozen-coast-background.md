> **Archived design document.** Status: APPLIED (2026-10-29), see [sky-and-biomes](../../art/sky-and-biomes.md) and [decorations](../../art/decorations.md).
> Translated on 2026-10-31 from `FlappyMonster_pruebas/fondo_costa_helada/README.md`, where the images it names still are.

# Frozen Coast: background and decoration pack

Generators: `tools/art/world/make_frozen_coast_sky.py [--apply A|B]` (surface background `frozen_coast`) and
`tools/art/world/make_frozen_coast_decor.py [--apply A|B]` (decorations, `assets/images/world/decorations/frozen_coast/`).

## Final (2026-10-29)

Chosen: **A with B's ice** (icebergs, barrier and glacier front in flat facets with a striped reflection) and the aurora
(green with a touch of magenta, night only). `vista_previa_final.png` is the real game:
`run.sh level_shots SCALE=1 TIME=<hour> TAG=<hour> -- tools/levelgen/arenas/costa_helada.json`, day / dusk / night.

## A against B

- **Background A, "floe coast"** (house style): polar blue sky, a sea horizon with tabular icebergs and an ice barrier;
  mid layer with a glacier front falling into the sea and a small harbour (dock, two huts with lit windows, a red-striped
  lighthouse); near layer of pack ice with raised slabs and posts with a rope.
- **Background B, "frozen sea"** (bolder): turquoise sky, faceted crystal icebergs with a striped reflection; mid layer of
  **frozen breaking waves** (ice curls with frozen foam and icicles); near layer of a cracked ice sheet, splinters and the
  bow of a wreck trapped in the ice with a broken mast.
- Both: 3 gradients of their own (day / dusk / night) and a night **aurora** (A green; B green and magenta).
- **Decorations A** (4 tones, outline in their own colour): iceberg, ice chunks, anchor, buoy with light (2 frames),
  bollard, lobster pot, rock with seaweed, capsized boat, hanging net, starfish in ice, floating floe.
- **Decorations B** (flat faces, thin shapes, coral accent): crystal iceberg, frozen wave, ice needle, beacon with light
  (2 frames), hanging chain, stacked pots, frozen seaweed, wreck mast, ice arch, jellyfish in ice, faceted floe.

Against `snow` (the Mountains): everything is at sea level and horizontal (horizon, floes, waves) instead of peaks; the
blues are ocean blues and the ice is turquoise.

## What the mockup did not show as the game does

The water surface (waves in the game), night and dusk lighting over the blocks, the animations (blinking light, rocking
floe) and the scale on a real device.
