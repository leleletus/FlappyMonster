# Contrast edge

A light or dark edge that separates characters (the player, enemies, bosses, items) from whatever is behind them,
only where they get lost. It replaced the level-flag white silhouette (0.5.211; design and plan archived:
[design](../design/archive/entity-edge-shader.md) · [plan](../design/archive/entity-edge-shader-plan.md)).

## What

Two modes, chosen in Settings → ASSIST → **EDGE / BORDE** (`Settings.edge`):

| Mode | Default on | How |
|---|---|---|
| `shader` | PC (Windows, macOS, Linux) | **Per character, whole sprite** (0.5.213). Characters draw into their own transparent canvas and, once more without side effects, their NUMBER into an ID canvas. A small pass per character measures what share of its OUTLINE is lost (character and background CONTRAST low — luminance AND colour, both × the light map; places too dark to see don't count) and, since 0.5.214, whether its BODY stands out: the sprite's pixels except its dark border (dark pixels touching the outside, `BORDER`), each against what is right behind it. Edge only if at least `NEED` (30 %) of the outline is lost AND less than `VIS` (50 %) of the body stands out; then it rises to 1, otherwise falls to 0, in `FADE` s; that state lives in a tiny GPU texture (nothing is read back). The composite draws a 2 px edge around the WHOLE sprite with that alpha: light on a dark background, dark on a light one (by the character's background). |
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
- Values (in `Edge.lua`, to tune by eye): `NEED` 0.3 (share of the outline that must be lost), `BORDER` 0.12 (a perimeter pixel darker than this is the sprite's border, not its body), `VIS` 0.5 (share of the body that must stand out to skip the edge), `CK` 1.0 (weight of the colour difference — Cb / Cr — against luminance in the contrast), `SLOTS` 255 character
  numbers (when they run out, the one longest undrawn is reused), `W` 2 px, `T_LO` 0.03 / `T_HI` 0.10 (luminance difference: full / no edge; 0.08 / 0.22 until 0.5.212),
  `L_LO` 0.12 / `L_HI` 0.3 (light here: no edge / full — a `dark` level's ambient is 0.055, so nothing is revealed
  outside the flashlight), `LIGHT` white, `DARK` navy, `MAX_A` 0.9, `FADE` 0.3 s.
- **Light sources get no edge** (the user, 2026-11-12: the cave Hopper with its lantern IS the light): `Edge.selfLit(e)`
  = the entity's `lights()` gives a light centred on it this frame (inside its box with a margin). Lights it gives far
  away (the Mortar's fireballs) don't count. Generic, for any type with `lights()`.
- The level JSON field `outline` is still read but does nothing.

## SP / server / client

Same code in single player, the online client and every demo (menu background, intro card, credits): it all goes
through `SceneLayers`. The server never draws. Online hit-stop (`reuse`) redraws the composited canvas of the last
real frame.

## How to extend

- **A new character type**: nothing. Its category decides; set `edge = false` if it is not a character.
- **A render that draws things that are not the body**: `Edge.direct(fn, ...)` for what goes BEHIND the characters
  (shadows, the floor, the back stun stars) and `Edge.over(fn, ...)` for what goes ON TOP (front stars, names, tags, bars,
  spotlights, target marks, weather). In shader mode `over` draws into a third canvas laid over the composited scene.
  Additive drawing into the empty character canvas would be read as a sprite. `BossFx.target/sleepZ/anger` and the front
  `stars` already go `over`, the back `stars` `direct`.
- **A render with side effects** (records deltas, emits particles, uses `math.random`): fine. In simple mode the 8
  copies run with the owner's fields snapshotted and restored, `Particles.emit` muted and a separate RNG. An `Edge.draw`
  inside the copies, or of the same owner inside itself (a subclass calling its base render), draws without copies.
- **A subclass with its own `render`** is wrapped too (`rawget`), so it gets the edge in both modes.
- **A new scene that is not a level** (a film shot, a screen with characters): wrap its drawing in `Edge.scene(fn, o)`;
  characters drawn by `Edge.draw` inside get the edge (only when drawn on that scene's canvas: a reflection or a boss's
  own canvas keeps its draws). `o.simple = 'light'` forces the simple mode's edge (films); a level drawn inside
  (`SceneLayers`, the credits) suspends it.

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
- Final review (2026-11-12) found and fixed before release: films lost the forced simple-mode edge (a `local` declared
  after use), nested `Edge.draw` crashed in simple mode, the light map stayed stale when a level left darkness (scenes),
  subclasses with their own render had no edge in simple mode, overlays (front stars, names, spotlights) went UNDER the
  characters in shader mode (→ `Edge.over`), and draws into another canvas inside an open scene were stolen.
- 0.5.212, the user: "it should need much more darkness to trigger" → `T_LO` / `T_HI` 0.08 / 0.22 → 0.03 / 0.10. The
  near-black monster now only gets the edge against an almost black background (caves, dark levels, the darkest night
  skies); medium contrasts (dusk, night mountains) no longer get a partial edge.
- 0.5.213, the user: "make it the whole sprite, I'm not convinced by only the darker parts: it does it or it doesn't
  (but with the fade)". Shader mode now decides per character (share of the outline lost ≥ `NEED`) and draws the
  whole outline with a fade kept on the GPU per character number. The simple mode already worked like that.
- Not judged by a person yet: the look, the thresholds (partial edges at medium contrast, e.g. the intro card at dusk),
  and the frame rate on real devices.
- 0.5.214, the user: "the shader must not only compare luminance but also the colour contrast — both dark but a
  different enough colour: no edge — and separate the enemies' dark border (almost all have one) from their coloured
  body". The contrast is now max(luminance difference, Cb/Cr colour difference × `CK`); the outline is judged as before
  but with that contrast, and the BODY (the sprite minus its dark perimeter pixels) is compared pixel by pixel with what
  is behind it: if half of it stands out, no edge. A red Gummy with a black border in a dark cave: no edge; the
  monster (black with a small white face): still edged. `edge_look` `cuerpo_color`, `cuerpo_igual`, `color_puro`,
  `cara_clara`. Not judged by a person yet.
