# Starway / Vía Estelar — the level (2026-11-14)

Status: **built; second version (0.5.226): 520 columns, the DANCE FLOOR zone, the Starway packs, the redecoration and the background plane. Not fully proven by the solver; the user plays and edits it by hand**. The special level of the
[beep blocks](beep-blocks.md) and the [rhythm objects](starway-rhythm-objects.md). Free Play only (not in the story yet:
the user will decide). File `assets/levels/via_estelar.json`, generator `tools/levelgen/levels_via_estelar.py`
(`python3 tools/levelgen/build.py --only via_estelar`).

The user's brief: "the longest, most labyrinthine and most fun level ever made in this game, exploiting the new and
old mechanics".

## Numbers

- **520 × 48** cells (24 960): about 3.4× the biggest level before it (`laberinto_submarino`, 134 × 55). v1 (0.5.225) was 420 wide; v2 inserted the dance floor (columns 97-196) and moved zones 3-6 right by 100 (`DX`, the `Shift` proxy of the generator).
- Music `via_estelar` (120 BPM: beat 0.5 s, phrase 4 s = one block switch); sky `starway` at night with `light:
  "none"` (the night light mood darkened the crystal and the objects too much); `timeLimit` 900 s (the 10-minute
  default is short for a labyrinth this size; the hurry warning still comes at 60 s left and speeds everything up).
- Online: `modes: ["race"]`.

## The route (columns)

| Zone | Cols | What |
|---|---|---|
| 0 Take-off | 2-19 | start island, two signs (`via.beep`, `via.switch`) |
| 1 Crystal bridge | 20-58 | bridge of 3-tile pink / cyan pieces over the void (jump the 3-gaps or wait for the switch); a two-colour STAIRCASE that switches under your feet (jump on the impact); a safety net below with an on-beat spring that sends you back; **star 1** on an islet under the bridge (back up with the spring) |
| 2 Clap corridor | 59-96 | low-ceiling corridor (no jumping over) with 4 pairs of clap-spike plates, alternating offsets; a 7-tile wall climbed only with an on-beat bounce |
| 2b The dance floor (v2) | 97-196 | parkour made ENTIRELY of beep blocks: (a) a floor of 2-tile pink / cyan pairs (half of it vanishes every switch) with crystal WALLS under a ceiling (each switch opens the other colour's walls); (b) a two-colour zigzag tower (rest ledges in the walls); (c) a 48-column corridor of floor-to-ceiling crystal walls (same colours in a row = two per phase) with clap plates, star at its end; (d) the drop to the metronome island |
| 3 The metronome | 197-265 (v1: 97-165) | the void crossed on PAIRS of metronome platforms that meet on beat 5 (each pair goes in opposite directions); a Gust; then the FORK: two-colour stepping stones up to the HIGH ROAD (crabby, extra life), or the fall to the LOW ROAD of clouds (clap plates, Gummies) |
| 4 Constellation maze | 266-362 (v1: 166-262) | 12 × 6 chambers of 8 × 6 (rows 8-44): a DFS maze + 14 loops. 40 % of the side passages are CRYSTAL DOORS (a 3-high column of pink or cyan: open half the time). Vertical passages: a drop-through hole, climbed with an on-beat spring or a ladder of ledges. Two ON/OFF Activators in the two farthest dead ends (one in the top half, one in the bottom) open the two Doors at the exit (`links`). **Star 2**, an extra life and apples in other dead ends; clap plates, Gummies and Hoppers in the rest; 3 checkpoints. Entrances: top-left (high road) and middle-left (low road); exit bottom-right |
| 5 Star staircase | 363-400 (v1: 263-300) | a 35-row tower: spring → ledge → two-colour stair → metronome LIFT → ledge (Gust) → spring → two-colour stair back → ledge → the top. Falling only drops you inside the tower |
| 6 The grand symphony | 401-518 (v1: 301-418) | a two-colour bridge with clap plates, a metronome pair over the void with a Gust, a DESCENDING two-colour staircase (each switch drops you onto the next step) with springs below for whoever falls, the finish island; **star 3** on a ledge reached with a spring |

## Looks (v2, 2026-11-14)

The user: a complete themed block pack, themed enemy textures, a complete decoration pack, a full redecoration with
the background plane, and more varied use of beep blocks (longer parkour, walls and floors made entirely of them).
- Blocks: the Starway pack ([tiles-and-blocks](../gameplay/tiles-and-blocks.md#the-starway-pack-05226)): star crystal
  road over nebula rock, star brick for the maze (a temple), crystal ledges.
- Enemies: the star island `estelar` ([enemies](../entities/enemies.md#the-star-island-estelar-2026-11-14)): Gummy and
  Crabby estelar placed directly; Hoppers, Gusts and Doors pick the island's art by themselves (sky `starway`).
- Decorations: `starway_set` ([decorations](../art/decorations.md#starway-set-2026-11-14)), placed by `decorate()` on the
  crystal tops (~20 % of the cells: crystals, moon flowers, shards, lanterns, telescopes, signs, banners; cloud puffs on
  clouds) and floating stars in the open sky. Subcell decorations go in the BOTTOM subcells (3, 4): v2 put them in
  1 / 2 and the moon flower and the crystal shard floated half a tile above the ground (the user, 2026-11-14; fixed 0.5.227).
- Background plane (`backplane()`): the whole maze has a brick wall with starry windows behind it (inside a temple);
  behind every long stretch of road, a brick tower with windows or a portico of crystal columns.

## Relief pass (0.5.234)

The user: "the same restructuring as the new levels, so it doesn't look so flat or square — and this time be careful
with the mini blocks" (they had removed them from the three new levels). The level is hand-edited, so it is NOT rebuilt:
`tools/levelgen/relief.py via_estelar` only ADDS to the existing file — 702 cells of nebula rock as domes and
stalactites under the crystal islands (only where the column and 3 columns each side are empty down to the void and no
entity or patrol is near; never the 2 edge columns; grown downward from the island, so no new surface faces up: checked,
0 new footholds) and 4 395 background-plane cells (spires out of a cloud sea, distant islands) where the plane was
empty. No mini blocks; the brick temples, the maze and every route untouched.

## How it was checked

`level_solve` learnt the beat (0.5.225): time is part of the state (each action is 0.1 s; the key holds the moment of
the 8-s cycle in quarter beats), beep blocks switch as in the game, the metronome is a moving body, clap spikes out
kill (stricter than the game) and the on-beat spring launches by the beat. Long levels are solved in STRETCHES:
`START=col,row GOALCOL=c [GOALROW=r] [T0=s]`.

Results of the FIRST version (420 wide; v2 moved zones 3-6 by +100 columns and has not been run through the solver) (the user asked to stop the solver — the PC had other heavy work — and to test, play and
edit the level by hand):
- OK: start → corridor (col 61) · corridor + spring wall (→ 94) · the metronome pairs (→ 129) · the fork, high road
  (→ 150, row 13) and low road (→ 150, row 31) · high road → the top Activator (178, 11).
- NOT PROVEN (search budget of 80 000 states ran out, so not necessarily impossible): high road → the bottom Activator
  (234, 35) — closest (226, 22); the tower (270, 43 → 296, 8) — stuck after the first spring, around (274, 33): the
  first ledge → pink stair step may be too hard or the spring's launch misses the ledge.
- Not run: low road → maze (the test started on a clap plate), Activators → exit, the finale.
- `level_check`: OK (420 × 48, 124 entities, race).

## Needs a person

The fun, the difficulty curve, the timing windows, whether the maze is fair or confusing, and the length (the solver's
route is far faster than a human's).
