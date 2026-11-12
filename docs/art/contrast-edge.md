# Contrast edge

A light or dark edge that separates characters (the player, enemies, bosses, items) from whatever is behind them,
only where they get lost. It replaced the level-flag white silhouette (0.5.211; design and plan archived:
[design](../design/archive/entity-edge-shader.md) · [plan](../design/archive/entity-edge-shader-plan.md)).

## What

Two modes, chosen in Settings → ASSIST → **EDGE / BORDE** (`Settings.edge`):

| Mode | Default on | How |
|---|---|---|
| `shader` | PC (Windows, macOS, Linux) | Characters draw into their own transparent canvas. One full-screen pass composites it over the scene and, **per pixel**, compares the character's luminance with the background's (both × the light map). Where they are too close it fades in a 2 px edge: light on a dark background, dark on a light one. |
| `simple` | Android, Switch; any device without shaders | The old silhouette: 8 offset copies of the body in one flat colour (`src/fx/Silhouette.lua`). LIGHT edge only, where the level is dark (`Silhouette.on`: dark, night, cave, under the depth surface; in `dark` levels only where a flashlight or a player's halo reaches). 0.3 s fade per character. |

Nothing is gameplay: no server change, no protocol change.

## Files

| File | Role |
|---|---|
| `src/fx/Edge.lua` | the module: `mode`, `draw`, `direct`, `simpleKind`, `open / begin / finish`, `scene`, the composite shader (`edge_composite`) |
| `src/fx/Silhouette.lua` | the simple mode's copies (`draw`, `around`) and `on` / `dim`; the forced edge of the results screen |
| `src/world/level/SceneLayers.lua` | routes edged entities and the actors into the character canvas, runs the composite, returns the final canvas |
| `src/fx/Darkness.lua` | `build` / `apply` / `lightCanvas(level)`: the light is computed BEFORE the composite |
| `src/world/entities/base/EntityTypes.lua` | the `edge` trait (default by category) and the render wrapper that calls `Edge.draw` |
| `src/player/PlayerRender.lua`, `src/player/OnlinePlayer.lua` | the player's body through `Edge.draw`; stars, bursts, name, crown, tags through `Edge.direct` |
| `src/story/Film.lua`, `src/story/Stage.lua`, `src/story/Actor.lua` | every film shot is an `Edge.scene`; a set (`Stage.drawSet`) opens its own scene inside |
| `src/story/LiveStage.lua`, `src/story/films/credits.lua` | the credits hand their background to the stage (`opts.background`) |

## Data

- Entity trait `edge`: on by default for the categories in `EntityTypes.EDGE_DEFAULT` (`Enemigos`, `Jefes`,
  `Objetos`); off for `Trampas`, `Mecanismos`, `Directores`, `Flappy`. A type overrides it with `edge = true / false`
  (definition or class). Data enemies: `"edge"` in the JSON (enemy editor: «Borde de contraste»); an old `"darkEdge"`
  reads as `edge = true`.
- Values (in `Edge.lua`, to tune by eye): `W` 2 px, `T_LO` 0.08 / `T_HI` 0.22 (luminance difference: full / no edge),
  `L_LO` 0.12 / `L_HI` 0.3 (light here: no edge / full — a `dark` level's ambient is 0.055, so nothing is revealed
  outside the flashlight), `LIGHT` white, `DARK` navy, `MAX_A` 0.9, `FADE` 0.3 s.
- The level JSON field `outline` is still read but does nothing.

## SP / server / client

Same code in single player, the online client and every demo (menu background, intro card, credits): it all goes
through `SceneLayers`. The server never draws. Online hit-stop (`reuse`) redraws the composited canvas of the last
real frame.

## How to extend

- **A new character type**: nothing. Its category decides; set `edge = false` if it is not a character.
- **A render that draws things that are not the body** (shadows, target marks, glows, text, bars, weather, additive
  light): wrap them in `Edge.direct(fn, ...)`. Additive drawing into the empty character canvas would be read as a
  sprite. `BossFx.stars/target/sleepZ/anger` already go through it.
- **A render with side effects** (records deltas, emits particles, uses `math.random`): fine. In simple mode the 8
  copies run with the owner's fields snapshotted and restored, `Particles.emit` muted and a separate RNG.
- **A new scene that is not a level** (a film shot, a screen with characters): wrap its drawing in `Edge.scene(fn, o)`;
  characters drawn by `Edge.draw` inside get the edge.

## Tests

`run.sh edge_look` (all cases: modes, simple rules, side effects, the trait, the setting, the composite pixel by pixel,
scenes, nested sets, the credits background; `SHOT=1` captures five levels in both modes). `mechanics` `filo_propio`,
`tapa_base`. `level_shots EDGE=simple`, `perf EDGE=shader|simple`.

## Decisions and history

- 3.68.x: the white edge of the monster was 8 offset white copies, on or off for the whole sprite by level flags;
  `darkEdge` added a warm edge to two volcanic enemies. It "worked, but not very well" (the user, 2026-11-12).
- 2026-11-12, the user's idea: a reusable per-pixel shader comparing each character with what is behind it. Chosen
  approach: the layer pass (one composite) over per-sprite shaders (would need hooks in every render). The user
  asked for both edge colours, the cinematics and the intro card on the same system (no forced `outline`), and a simple
  mode for modest devices switchable in settings.
- **Rejected (the user, 2026-11-12):** a dark edge on snow by day in simple mode. "The Gummies and snowy Hoppers
  already have dark outlines in the sprite exactly for that; it doesn't help and doesn't look quite right." Simple mode
  only draws the light edge; shader mode doesn't edge them because their outline already contrasts.
- Measured on PC at 1280×720: draw time shader / simple: menu 4.2 / 2.7 ms, a level 4.0 / 2.7 ms, a boss 4.8 / 3.0 ms;
  textures +7 MB (the character canvas and the scene's partner). Not yet measured on Switch / Android.
- Not judged by a person yet: the look, the thresholds (partial edges at medium contrast, e.g. the intro card at dusk),
  and the frame rate on real devices.
