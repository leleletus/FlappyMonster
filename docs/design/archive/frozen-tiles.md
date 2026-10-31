> **Archived design document.** Status: APPLIED, see [tiles-and-blocks](../../gameplay/tiles-and-blocks.md). The placement suggestions below were left for the user to do by hand; whether each was done is not tracked.
> Translated on 2026-10-31 from `FlappyMonster_pruebas/tiles_helados/README.md` and `tiles_helados/costura_nieve/README.md`, where the images it names still are.

# Frozen tiles: continuous snow and ice + the frozen building pack (2026-10-29)

No existing level was edited: levels look different only because snow and ice are drawn differently (same physics, same
ids).

## The cause

`snow.png` and `ice.png` carried a light strip on top and a shadow below INSIDE each tile (ice also its whole diagonal
shine). Stacked, those strips repeated once per block: horizontal lines on every snow or ice wall. The join
(`joinGroup`) was fine: it only removed the 2 px edge.

## The fix (general, works for any block)

- **Layered skin** (`skin` on the tile type, `TileTypes.drawSkin`): a seamless BODY (it can span 2x2 tiles) + layers only
  on the faces open to the air: top (the snow pad), bottom (the shadow), sides, or always (`over`: the window). A wall
  reads as ONE mass.
- **`joinAlso`**: snow and ice join with no edge between them (and with the new snow / ice blocks).
- **Dithered transitions** (the sand's) now in the base: ice towards snow has a frost strip. Snow towards dirt / stone
  does NOT: tried, the dithered dirt under the snow looked like spiky grass (rejected).

## The frozen pack (tiles 50-58)

| Id | Block | What it does |
|---|---|---|
| 50 | Frozen brick | normal solid; thin snow on top |
| 51 | Frozen rock | normal solid; thin snow on top |
| 52 | Ice ashlar | solid, opaque, SLIPPERY |
| 53 | Glacial ice | solid, opaque in strata, SLIPPERY (the ice wall that does not look ghostly in the background) |
| 54 | Snow block (igloo) | solid, snow (the mole digs it) |
| 55 | Ice column | solid, slippery; capital and base appear by themselves where the column ends |
| 56 | Frozen window | solid; frozen brick with a window (meant for the background plane) |
| 57 | Frozen platform | drop-through, same as the wood one (same hitbox) |
| 58 | Ice ledge | drop-through, SLIPPERY, semi-transparent, drips |

Also mini blocks (snow, ice, frozen brick, frozen rock, snow block, glacial ice, ice ashlar) and boss blocks (frozen
brick, frozen rock, ice ashlar). All can go on the background plane.

To switch to the alternative look: `python3 tools/art/world/make_frozen_tiles.py --apply --snow B --ice B`.

## Snow seam with other blocks

The user: "just as ice / sand has a seam with other blocks, snow must too". **A applied:** snow SPILLS over the block it
touches (dirt, grass, stone, edge, abyssal rock, sand, basalt, ash, mud, jungle grass, temple ashlar, frozen brick, frozen
rock, frozen window, breakable block): a 1-pixel snow lip inside the neighbour and ROUND clumps with the tip in shadow, so
it does not look like grass. On all four sides, in mini blocks, boss blocks and the background plane. Ice and snow keep
their frost strip between them. Drawing only: physics do not change.

B (dithered frost): `python3 tools/art/world/make_frozen_tiles.py --apply --seam B`.

## Where the new pieces could go (to place by hand)

Wood drop-through platforms can become the **Frozen platform** without changing gameplay (same shape and behaviour). The
**Ice ledge** is slippery: only where that challenge is wanted.

- **cumbres_escarcha**: wood platforms (cols 11-16, 101-108, 136-141) → frozen platform. Background plane: a frozen brick
  ruin with windows behind the exit (cols 2-30, rows 15-21); a snow block igloo next to a snowman (cols 118-124, row 21);
  glacial ice inside the right peak (cols 140-157, rows 3-16); ice columns under the big mountain's overhang (cols 55-72,
  rows 13-15), plane only.
- **torre_viento**: a frozen brick wall on the background plane (cols 6-38, rows 9-52) with frozen windows every 4 rows
  and ice columns at the sides; the 22 wood platforms → frozen platform; the finish's stone pillar (col 19, rows 2-8) →
  frozen brick.
- **lago_helado**: wood platforms of rows 6-8 → frozen platform (not ledge: it would change the jump); plane: a frozen
  brick ruin behind the ice bridge (cols 17-30) and glacial ice behind the right frozen lake (cols 77-93).
- **fabrica_criogenica**: the stone mass of the ceiling (cols 117-146, rows 2-17) → frozen brick (it is a factory: brick
  walls, some frozen windows); wood platforms → frozen platform; plane: frozen brick walls with windows behind the lower
  corridor (rows 18-21) and pairs of ice columns as supports behind the freezers (cols 44-66, rows 16-21).
- **glaciar_cangrejo**: the hanging snow block (cols 50-61, rows 2-7) → glacial ice (only seen from below: no gameplay
  change); plane: glacial ice walls behind the first stretch (cols 20-45), far from the boss zone. The `===` beams (row
  10) stay: they are not drop-through.
- **lago_de_cristal**: wood platforms and the long bridge of row 14 (cols 36-56) → frozen platform; plane: frozen brick
  ruins instead of the snow hills; ice columns under the upper snow block (cols 41-53, rows 9-13), plane only (in front
  they would block the way).

## Left for the user's eye at the time

Whether the flat snow body works in large masses, A against B, the pack's colours (frozen brick and rock come out very
dark on the daytime background plane), the frozen platform and the window size, the clump size and that the seam pattern
repeats every tile along long edges. Not played on a real device.
