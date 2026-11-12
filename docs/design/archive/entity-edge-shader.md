# Contrast edge for every entity (2026-11-12)

**Status:** built 0.5.211 — the system page is [contrast-edge](../../art/contrast-edge.md) (it wins where they differ). Simple mode: no dark edge on snow (the user).


**Status:** design, approved approach (B, "layer pass"); not built.

## Why

Today the white edge ([`src/fx/Silhouette.lua`](../../../src/fx/Silhouette.lua)) is all-or-nothing and decided by
*theory*: `Silhouette.on(level, y)` says "it is dark here" from the level's flags (`dark`, light mood night / cave,
below the depth surface, or the forced `outline` flag), and then the whole sprite gets 8 offset white copies behind it.
Enemies only get one if their type declares `darkEdge` (crabby_lava, gummy_magma: a warm 1 px edge, also on dusk).
It works, "but not very well": it appears where the sprite already reads fine, and never where a sprite is really lost
(a dark enemy against a dark wall in daylight, a white thing on snow).

The user's idea: one reusable effect that compares, **per pixel**, the sprite with what is really behind it (sky,
background, block, whatever) and, past a threshold, **fades in** an edge **only on the parts of the outline that need
it**. It must work anywhere, any time, smoothly, and look good.

## Goals

- Every character on screen gets the edge automatically: players (local, online, bots, the ghost), enemies, bosses,
  and anything else whose type opts in. No per-type drawing code.
- **Both directions** (the user, 2026-11-12: "ambos"): a **light** edge where a dark sprite meets a dark background,
  a **dark** edge where a light sprite meets a light background.
- Smooth: the edge's strength grows continuously with how little contrast there is (no popping on / off), per pixel,
  so half a sprite can have it and the other half not.
- Uses what the player **sees**: the background *after* the level's light (night / dusk / cave / depth penumbra /
  flashlight) is applied, not the raw scene.
- Same everywhere a level scene is drawn: single player, online client, the menu background, the level intro card,
  the credits' live stages and **the cinematics** (the user: "las cinemáticas también").
- **The level intro card no longer forces the edge** (`outline = true`): it uses the new system like everything else
  (the user).

## Non-goals

- Edges between two entities (an enemy against another enemy): the edge separates entities from the *scene* only.
- Gameplay: nothing in the simulation changes; the server is not touched; no protocol bump.
- A settings option for it (could come later in the ASSIST tab; not asked).

## Anti-goals (would be a failure even if it "works")

- **Revealing things in the dark.** In `dark` levels an enemy outside the flashlight must stay invisible: the edge must
  never be visible where the player could not see the sprite itself.
- Soft / blurry look: the edge is hard pixels of a fixed integer width (style rules: hard rectangles, integer
  positions). Only its *opacity* is smooth.
- A frame-rate hit on modest devices that makes the game worse there (hence the simple mode below).
- Edges on terrain-like things (moving platforms, spikes, water, flood fills, directors' screen effects).

## Constraints

- LÖVE 11 GLSL; no stencils (Switch / Android). A shader cannot read the canvas it draws into.
- Golden rule 1: visuals only, render code only; the same layers in SP and online (`SceneLayers`).
- Golden rule 2: on / off is a **base trait**, never per-type drawing code.
- Golden rule 4: no image assets needed (it is an effect, like the water shader); shader code lives with its module
  through `Shaders.define`.

## Approaches considered

| | How | Trade-off |
|---|---|---|
| A. Per-sprite shader | Snapshot the scene after the tiles; every entity's outline copies go through a shader that samples the snapshot | Per-entity widths, but it must be hooked into every render (bosses, multi-part enemies, hand-drawn things): dozens of files or wrapping `love.graphics.draw` — rule 2 broken in practice |
| **B. Layer pass (chosen)** | Characters draw into their own transparent canvas; one full-screen shader composites it over the scene and adds the edge where contrast is low | Automatic for everything; one width for all; one extra canvas + one full-screen pass |
| C. CPU estimate | Sample average brightness around each entity, keep the 8-copy outline | Still whole-sprite, still a guess: what the user wants to leave |

The user chose **B** "with everything it implies".

## How it works (decided)

### The layers

`SceneLayers.draw` today draws, in the scene canvas: sky → back plane → `renderBack` → tiles → … → **back entities**
→ **players (actors)** → particles → **front entities** → foliage → bubbles → snow. Then the water effect, then
`Darkness.render` multiplies the light, then `renderGlow` and the HUD.

New:

1. Everything up to the back entities draws in the scene canvas as now.
2. **The actor canvas** (transparent, screen size, shared like `SceneCanvas`): back entities that have the edge
   trait, the players / ghost / bots, and front entities with the trait draw here. Entities **without** the trait
   keep drawing straight into the scene canvas, in their usual place.
3. **The light map is built before the composite.** `Darkness.render` is split in two: *build* (fills its 1/4-size
   light canvas: ambient, halos, flashlight cones, decoration / tile / entity lights — exactly as today) and *apply*
   (multiplies it over the screen, after the water effect, as today). The build runs before step 4; when the level
   has no light mood the light is plain white.
4. **The composite.** A shader cannot read the canvas it draws into, so the scene canvas is a **ping-pong pair**:
   the composite reads scene canvas A + the actor canvas + the light map and writes canvas B in one full-screen draw
   (that draw *is* the copy); drawing then continues on B. For each pixel,
   - if the actor canvas has a sprite pixel there → draw it as is;
   - else, look at the neighbours within `W` pixels (8 directions × the width); if one is a sprite pixel, this pixel is
     on the outline. Compare the **neighbour sprite's luminance** with the **background's luminance here**, both
     multiplied by the light map at this point (what the player will see). Low difference → edge.
   - Edge colour: the opposite of the *background* (light edge on a dark background, dark edge on a light one), so it
     always reads. Edge alpha = `smoothstep(T_hi, T_lo, contrast) × smoothstep(L_lo, L_hi, light here)` — 0 where
     contrast is good, growing to full as it vanishes, and **fading out where there is almost no light** (see below).
     This alpha is the "smooth" part; the pixels stay hard.
5. Particles, foliage, bubbles, snow, water effect, light apply, glow, HUD: unchanged order after it.

The edge goes into the scene canvas **before** the light is applied, so the darkness multiplies it too. That alone is
**not** enough for anti-goal 1 (found by the review): outside the flashlight both sprite and background are ×0.055, the
contrast reads ~0 and the edge would go to full — a white edge at ~5 % grey on near-black would faintly outline every
enemy in a `dark` level. Hence the light factor: below `L_lo` there is no edge at all. In night / cave the ambient is
~0.5, so the edge still reads at about half, as today.

### The trait

`edge` on the entity base (EntityTypes / `Entity`): **on by default** for players and for the categories *enemies*,
*bosses* and *items*; **off by default** for *traps*, *mechanisms* and *directors*. Any type can set `edge = true /
false` to override its category (a carryable crate, a glowing projectile). The base decides where the entity draws
(actor canvas or scene canvas); types do nothing.

### Which parts of an entity get the edge (my call, from the review)

An edged entity's `render` draws more than its body: floor shadows, target markers and wind marks (Megacrabby, Snowboss,
Tifón), additive glows (gloomy, megagloomy, mortar, megacrabby_ice, cryo — `setBlendMode('add')`, which also breaks
in an empty transparent canvas), the player's stun stars and attack bursts, online name tags / crown / place / "SPEC",
the point-zone progress bar. The user's words — "solo en las partes del sprite que realmente lo necesitan" — mean the
**body**. So:

- What is part of the character's body or wraps it (the body, the ice block, the shield bubble) → actor canvas.
- Overlays (shadows, markers, glows, text, bars, stars, bursts) → drawn straight into the scene canvas through a
  **base helper** (`Edge.direct(fn)`: switches the target to the scene canvas for `fn` and back). It is one call around
  the existing overlay code, not drawing code per type; the renders that need it are listed in the plan (the review
  found ~15). Any additive-blend drawing must go through it.
- Not an alpha threshold: it would also drop the edge from a blinking (0.25 / 0.6), ghosted (0.5) or replay sprite.

### Two modes and the setting (the user, 2026-11-12)

"On modest devices keep the current silhouette (but improved), with an option in the settings to switch between them."

- Setting **EDGE / BORDE** in the ASSIST tab (`Settings.edge = 'shader' | 'simple'`), my call on the tab. Default by
  platform: `shader` on PC, `simple` on Switch and Android (my call; the user can change it on any device).
  Shaders unavailable (`Shaders.get` nil) → `simple` whatever the setting says.
- **`shader`**: the layer pass described above.
- **`simple`**: today's 8-copy silhouette, improved (my proposal of what "improved" means, to confirm):
  1. **Every edged entity**, through the same base `edge` trait — not only the player and two `darkEdge` types.
  2. ~~**Both colours**: a dark edge on light levels (snow / ice) by day~~ — **built and removed (the user,
     2026-11-12):** "the Gummies and snowy Hoppers don't need an edge on snow by day: their sprites already have dark
     outlines exactly for that; it doesn't help and doesn't look quite right". The simple mode only draws the LIGHT
     edge where it is dark. (Shader mode decides per pixel: those outlines already contrast, so nothing appears.)
  3. **Fades** in and out (~0.3 s, per entity) instead of popping when the entity crosses the depth surface line.
  4. The same **light fade** in `dark` levels (no edge outside the flashlight).
  Same layers code path: in `simple` mode the actor canvas is not used; entities draw into the scene canvas as today
  with the silhouette behind them.

### What goes away

- `Silhouette`'s role as the ONLY edge: it stays as the `simple` mode, generalised. The `darkEdge` trait (crabby_lava,
  gummy_magma) is folded into the base `edge` trait; the per-call `Silhouette.on` checks in `PlayerRender`,
  `OnlinePlayer`, `Story/Actor` and `Stage.monster`'s forced edge move into the one base path that picks the mode.
- `outline = true` in [`src/ui/IntroScene.lua`](../../../src/ui/IntroScene.lua) and in the films (`Stage.monster{ outline =
  true }`). The level JSON field `outline` is still read (ids and fields are never renamed) but no longer does anything.

### Cinematics (the user: they must have it too)

- `Stage.drawSet` draws its decor like a level: its `actors(camX, camY)` callback goes into the same actor canvas and
  the same composite runs (its Darkness build moves before the composite, as in the game).
- **Shots without a decor** — the monster flying over the world map (`films/intro.lua`, today `outline = true`), over
  the Flappy backgrounds: `StoryMapState:filmDraw` and those shots draw their background into a scene canvas and the
  monster into the actor canvas, then the same composite (my call: the user asked for cinematics to use the new system,
  so these do too, instead of keeping a forced edge).
- The Mirror's reflection (drawn into its own canvas, masked by the glass) keeps no edge, as today.

### The credits' live stages

They run `AdventureState` with `noSky` (transparent scene) over a Flappy background drawn in another target. My call:
the credits hand their background to the stage so it is drawn into the scene canvas first (the composite then compares
against what is really behind); pixels that are still transparent count as black.

### Starting values (to tune by eye)

- `W` = 2 screen pixels (today's player edge: 1/3 of an art pixel at scale 6 = 2 px).
- Contrast = absolute difference of Rec. 601 luminance; `T_lo` ≈ 0.08 (full edge), `T_hi` ≈ 0.22 (no edge).
- Light edge colour ≈ (1, 1, 1); dark edge ≈ (0.05, 0.06, 0.10) (the game's outline navy).
- Edge max alpha 0.9.
- Light fade: `L_lo` ≈ 0.12 (no edge), `L_hi` ≈ 0.3 (full) — above the `dark` ambient (0.055), below night / cave
  (~0.46-0.5).

## Left to the builder

- The exact shader code, sample pattern and how the light map is sampled (1/4 size, nearest).
- Whether back and front entities share one actor canvas (one composite; particles then draw above front entities —
  acceptable) or two composites (exact order, double cost). Prefer one if the visual difference is nil.
- Where the results screen (`StoryResultsState`, a monster on a flat dark UI background, no scene) ends up: simplest
  is to keep a forced light edge there through a tiny local helper, since there is no scene behind it.
- Whether the simple mode's per-entity fade timer lives on the entity or in a weak table in the edge module.
- Performance numbers: measure with the perf scenes (`docs/testing/performance.md`); the cost is one screen-size
  canvas (≈3.5 MB at 1280×720) and one full-screen pass with ~16 texture reads.

## What only a person can judge

How it looks and whether the thresholds feel right; the frame rate on a real Switch and Android phone.

## Tests (planned)

- Syntax check + `level_shots` captures: a dark enemy on a dark wall by day (edge only on the touching side), a light
  thing on snow (dark edge), a night level, a `dark` level with an enemy outside the flashlight (no visible edge).
- The intro card capture without `outline` (the monster still reads on its background where needed).
- A film capture with a decor (cinematics harness).
- `project_check` (removed trait / module references), `docs_reference` if the type tables list `darkEdge`.

## Docs to update when built

`docs/gameplay/dark-levels.md` (the Silhouette row), `docs/art/fx-and-particles.md` (new effect page or section),
`docs/entities/overview.md` (the `edge` trait), `docs/story/cinematics.md` (rim lines), `docs/design/level-intro-card.md`
note, this page → archive with its status.
