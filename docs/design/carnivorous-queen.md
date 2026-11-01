# The Carnivorous Queen: visual designs

Designs to choose from for the jungle's secret boss ([saved idea](../bosses/future-secret-bosses.md)). **Nothing is implemented and nothing is in `assets/`.**

- Generator: `tools/art/bosses/make_carnivorous_queen.py` (previews only; `--still` skips the GIFs, `--look X` makes one GIF).
- Previews: `FlappyMonster_pruebas/reina_carnivora/`: `vista_previa.png` (all looks at real scale on the temple, idle and stunned, plus silhouettes), `piezas_<A-D>.png`, `pelea_<A-D>.gif`.
- Test scene: the `temple` depth plane (gradient, wall, arches, hanging roots), `temple_brick` + moss, the real player ×6, the real Carnivorous Plant ×4, the real bomb, explosion and stun stars.

Every look keeps the small plant's B «Cepo» language: lobes green outside and magenta inside, pale cilia, base leaves, pink bait flower, the same palette. It stays readable on the dark green temple thanks to the light green mid tone and the magenta.

## The looks

Sizes are the occupied area at ×5, in pixels (player 54x96, tile 64).

| Look | Idea | Idle | Stunned | Frame (art) |
|---|---|---|---|---|
| **A «Cepo Real»** | The plant itself, lying flat and huge. Closed, it stands as a pod. The most faithful, and the air stays free | 260x115 (closed 200x165) | lobes flat, flower rises on its stem, 260x135 | 56x38 |
| **B «Dama»** | Leaf gown, thin waist, a V crown of lobes as head; bud as a brooch between two lapels. The slimmest and most queen-like | 190x340 | neck gives way, crown hangs to one side, lapels part, 200x235 | 48x75 |
| **C «Jarra»** | A tall pitcher plant: one lobe as lid, eyes inside the black mouth. The boldest, and it shows where bombs go | 190x360 | topples sideways, flower pokes out of the mouth, 340x305 | 84x83 |
| **D «Abanico»** | Thin stalk and a wheel of 7 narrow lobes around a face. Closes like a tulip to swallow | 260x335 (closed 190x335) | lobes hang like a wilted sunflower, flower on top | 60x69 |

**Recommendation at hand-off: B «Dama».** It is the one that meets the whole brief: the real Cepo V trap as her crown (so the lore reads), the slimmest original silhouette, eyes that read, and an obvious queen. Bombs go into the crown from above. **C** is the bold runner-up with the strongest eyes and the clearest bomb target, but it reads least as the Cepo. **A** is the safe, most faithful one, with the most room to dodge, but the least new.

## Pieces each one needs

All are drawn at ×5 except where stated.

- **Body sheet, 10 frames:** `idle1`, `idle2`, `tell`, `spit1`, `spit2`, `closed`, `gulp`, `blast`, `stun1`, `stun2`. A defeat frame is not drawn yet.
- **Flower, separate layers (same for all looks, 19x17):** open flower, bud, dew drop (the splinter), each frame with an anchor. The bud with its drop is visible at idle in every look except when closed, so she always wears the piece. Remove the drop layer for "stolen" or defeated. A hit flash exists for the flower only.
- **Sprouting mouth:**
  - Head in 16 directions (no pixel rotation) × closed / half / wide / with prey. Length: A 18, B 20, C 17 (a small cup with lid), D 18 art px (three lobes).
  - Stalk as live discs for `SegmentChain.lua`, 5 sizes, each **in 3 layers** (outline, shade, light). The game draws all outlines of the chain, then all shades, then all lights, for a smooth 3-tone tube. This needs a small addition to how the chain is drawn (the scorpion draws discs whole). The scorpion's stacked-disc look was tried first here and looked striped.
  - Socket, 3 stages (crack, opening, leaves), rotated for floor, wall and ceiling.
- **Seed:** 11x11, 4 rotations, ×4. A brown pip, B magenta spindle, C brown teardrop, D magenta star.
- **Sprout:** 2 frames, 17x16, ×4, then it becomes the normal `carnivoreplant` (its sheet is untouched, not redrawn).
- **Collection icon (17x13):** dew flower with leaves, with the drop, and without it (a dark dimple on the petal). Same for all looks. Not written to `assets/`.

## Sizes and the room

- Scale ×5 for all, to keep the same pixel size across looks. The scorpion's lesson: about 200 px wide was right.
- A, B and D are about 190-260 px wide. B, C and D stand about 335-360 px, so the room needs at least 8 clear tiles of height. The test room has 9.
- She is rooted in the middle, so the player has to cross her. Like the scorpion, her body should be walkable and harmless, or the room is cut in two (only A can simply be jumped). To be decided.
- No squash or bounce: idle is 1-2 px of sway between 2 frames, and only `gulp` widens the body, as a discrete frame.

## Open questions

1. Which look. Mixes are possible, for example A's mouths on another body.
2. Does the seed grow into the normal plant at ×4, as drawn, or a weaker seedling at ×3?
3. Is the bud always visible (drawn), or should the flower be hidden until the stun?
4. How long can a stalk be? The GIF's ceiling mouth reaches about 480 px, which looks long. Phase 2 ("the mouths move around") needs a stalk that travels, not drawn.
5. Is the flower reachable at stun height? B and C were placed by eye: B's flower is about 185 px up, C's about 300 px. C's may need a lower pose or a platform. Depends on the real jump, not tested.
6. Do mouths sprout on a tell of the socket alone, or also a root ridge running along the floor from her base (not drawn)?

## Known weak points

- Not seen in the game: these are Python mock-ups with scripted motion, and the springs only imitate `SegmentChain.lua`.
- Green on green: the mid tones separate well, but the dark outlines and base leaves sink into the temple.
- Explosion, stars and player moves are placeholders for timing, not designs. The body has no whole-body red flash (`Kit.tint`) or defeat frame.
- B's stunned pose is the busiest: the big flower crowds the hanging head, and her bud is tight against the lapels. C's lid can look like a pointed hat, its stripes a little like a wasp, and when stunned the flower covers the lid. D is close to a familiar "garden plant with a face". The icon's flower centre is rough at real size.

## History

- 2026-11-01: first round, four looks, waiting for the user's verdict.
