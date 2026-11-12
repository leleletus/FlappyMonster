# Contrast edge — Implementation Plan

**Status:** executed (0.5.211); rulings in the commit history. System page: [contrast-edge](../../art/contrast-edge.md).


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the level-flag white silhouette with a per-pixel contrast edge for every character (shader mode), keep an improved silhouette as the simple mode, switchable in settings.

**Architecture:** A new module `src/fx/Edge.lua` owns both modes. Shader mode: edged entities and players draw into a transparent actor canvas; one full-screen composite (ping-pong scene canvases) adds a light/dark edge where the sprite's luminance is close to the lit background's. Simple mode: the old 8-offset silhouette (`src/fx/Silhouette.lua`), generalised to every edged entity, light or dark, with a fade. `Darkness.render` is split into build / apply so the light map exists before the composite.

**Tech Stack:** LÖVE 11.x, LuaJIT, GLSL (LÖVE shader dialect), the repo's `Shaders` registry and `tools/tests/run.sh` harnesses.

**Spec:** [entity-edge-shader.md](entity-edge-shader.md)

## Global Constraints

- Golden rule 1: render-only. Nothing in `server/`, no simulation change, no `Protocol.VERSION` bump. `version.txt` + 1 at release.
- Golden rule 2: on / off is the base trait `edge`; types never draw edges themselves.
- No stencils; canvases follow `WINDOW_W/H` at draw time (never at file load) — the same rule as `SceneCanvas.get()`.
- Code comments and commit messages in Spanish; player-facing text only through `assets/lang/translations.csv` (every language column).
- Edge pixels are hard (integer offsets, `nearest`); only their opacity is smooth.
- Starting values (from the spec): `W = 2` screen px, `T_LO = 0.08`, `T_HI = 0.22` (Rec. 601 luminance difference), `L_LO = 0.12`, `L_HI = 0.3` (light-map luminance), light edge `{1, 1, 1}`, dark edge `{0.05, 0.06, 0.10}`, max alpha `0.9`, simple-mode fade `0.3` s.
- Default mode: `'shader'` when `love.system.getOS()` is `Windows`, `OS X` or `Linux`; `'simple'` otherwise (Android, Switch). `Shaders.get` nil → `'simple'` whatever the setting.
- Tests only through `tools/tests/run.sh`; a new harness gets its README row.

## Review Focus

1. **Window resize / phone rotation mid-level** → the actor canvas and the second scene canvas are rebuilt at the new `WINDOW_W/H`, no stretched or cut frame. (Task 4: `edge_look` case `tamano`.)
2. **Online hit-stop (`reuse`)** → the frozen frame shows the composited scene (with edges), not the pre-composite canvas. (Task 4: case `reuse`.)
3. **A render that sets its own shader or blend mode** (iced tint, the Mirror's invert, additive glows) **inside an edge** → simple mode's flat copies stay flat; shader mode's additive parts go through `Edge.direct`. (Task 2: case `sombreador`; Task 4: case `aditivo`.)
4. **See-through sprites** (invulnerability blink 0.25 / 0.6, ghost power-up 0.5, replay ghost) → the edge is scaled by the sprite's alpha, never dropped. (Task 4: case `translucido`.)
5. **Sprite half off-screen** → no edge drawn from samples outside the canvas (clamp, no wrap-around stripe on the opposite border). (Task 4: case `borde_pantalla`.)

---

### Task 1: The `Edge` module, the setting and the simple-mode rules

**Files:**
- Create: `src/fx/Edge.lua`
- Modify: `src/fx/Silhouette.lua` (keeps `draw`, `around`, `on`, `dim`; becomes the simple mode's drawing; header says so)
- Modify: `src/core/Settings.lua` (`edge` key: default, load, save)
- Modify: `src/ui/menu/SettingsRows.lua` (choice row `edge` in the `access` tab, after `cbSymbols`)
- Modify: `assets/lang/translations.csv` (`settings.row_edge`, `settings.desc_edge`, `settings.val_edge_shader`, `settings.val_edge_simple`)
- Modify: `src/fx/Sky.lua` (`bright = true` on the `snow` and `frozen_coast` backgrounds)
- Create: harness `tools/tests/edge_look/` (skeleton like `hud_layout`: `conf.lua`, `main.lua`, symlinks `assets game.lua game_main.lua input.lua libs settings.lua src`)
- Modify: `tools/tests/README.md` (row `edge_look`)

**Interfaces:**
- Produces:
  - `Edge.mode() -> 'shader' | 'simple'` (effective mode: setting + shader availability)
  - `Edge.defaultMode(os: string) -> 'shader' | 'simple'`
  - `Edge.level` (the level being drawn; set by whoever draws a scene, nil outside one) — replaces `Silhouette.level` and `PlayerAdventure.lightLevel`
  - `Edge.simpleKind(level, x, y) -> 'light' | 'dark' | nil` — `'light'` where `Silhouette.on(level, y)` (and, for dark levels, only where lit: `Lights.lit(level, x, y)` or within 118 px of a player in `level.players`); `'dark'` where the level's background has `bright` and the light mood is day / none and `y` is above the depth surface; else nil
  - `Edge.draw(owner, y, fn)` — `fn(dx, dy)` draws the owner shifted by screen pixels. Shader mode: `fn(0, 0)`. Simple mode: per-owner fade (weak table, 0.3 s towards 1 when `simpleKind` is non-nil, towards 0 otherwise); if alpha > 0, 8 flat copies (1 px for owners with `owner.edgeThin`, else `max(1, round(PLAYER_SCALE/3))` px) in the kind's colour × alpha × max alpha, then `fn(0, 0)`. During the copies `love.graphics.setShader` is replaced by a no-op so nested shaders can't undo the flat colour; restored after.
  - `Edge.direct(fn)` — draws `fn()` without an edge: during simple-mode copies it skips `fn`; in shader mode while the actor canvas is the target it switches to the scene canvas for `fn` and back.
  - `Edge.inPass() -> boolean` (true during simple-mode copies)
  - Constants `Edge.W, T_LO, T_HI, L_LO, L_HI, LIGHT, DARK, MAX_A, FADE` with the values in Global Constraints.
- `Settings.edge` = `'shader' | 'simple'`, saved like `signText`.

- [ ] **Step 1: Write the failing cases in `tools/tests/edge_look/main.lua`** (`check(name, ok, msg)` like `hud_layout`; `ONLY=a,b` filter)
  - `modo`: `Edge.defaultMode('Linux') == 'shader'`, `('Windows')` and `('OS X')` shader, `('Android') == 'simple'`, `('Horizon') == 'simple'`; with `Settings.edge = 'shader'` and `Shaders.get` stubbed to nil, `Edge.mode() == 'simple'`.
  - `simple_tipo`: `simpleKind({ light = 'night' }, 0, 0) == 'light'`; `({ light = 'day', background = 'snow' }, 0, 0) == 'dark'`; `({ light = 'day', background = 'meadow' }, 0, 0) == nil`; depth level `{ depth = 'cave', surfaceRow = 6 }` above y 320 nil / below `'light'`; `{ dark = true, players = {} }` far from any player nil, a player at the same point `'light'`.
  - `simple_fundido`: an owner at a dark place: after 0.15 s of `Edge.draw` calls alpha ≈ 0.5 (±0.1), after 0.4 s = 1; moved to light, back to 0 within 0.35 s (no jump to 0 on the first frame).
  - `directo`: inside a simple-mode `Edge.draw`, a counter in `Edge.direct(fn)` is bumped once (the final `fn(0,0)`), not 9 times.
  - `sombreador`: inside the copies, a `love.graphics.setShader(other)` call leaves the flat shader active (read back with `getShader`).
  - `ajuste`: `Settings.edge` saves and loads; the `access` tab has row `edge`; its four language keys exist in every column.
- [ ] **Step 2:** `tools/tests/run.sh edge_look` → FAIL (`src/fx/Edge.lua` missing).
- [ ] **Step 3: Implement** `src/fx/Edge.lua`, the setting, the row, the texts (Spanish with accents: «BORDE», «Contorno que separa a los personajes del fondo»; «SHADER» / «SIMPLE»), `bright` in `Sky.lua`.
- [ ] **Step 4:** `tools/tests/run.sh edge_look` → all OK; `tools/tests/run.sh menu_flow ONLY=cfg_datos,cfg_pestanas` (or the harness's equivalent filter) → OK.
- [ ] **Step 5: Commit** — `git -c core.fileMode=false commit` «Borde: módulo Edge (modo shader / simple), ajuste en AYUDAS y reglas del modo simple».

### Task 2: The `edge` trait and every character through `Edge.draw`

**Files:**
- Modify: `src/world/entities/base/EntityTypes.lua` (default by category; the render wrapper calls `Edge.draw` when `self.edge`, replacing the `darkEdge` block)
- Modify: `src/world/entities/base/DataEnemy.lua` (`spec.edge`; a present `darkEdge` still reads as `edge = true` — data files keep working)
- Modify: `src/editor/EnemyEditor.lua` (the toggle writes `edge = true / false`; label «Borde»)
- Modify: `src/world/entities/types/enemies/crabby_lava.lua`, `gummy_magma.lua` (drop `darkEdge`: their category gives the edge)
- Modify: `src/player/PlayerRender.lua`, `src/player/OnlinePlayer.lua` (the body through `Edge.draw(self, y, fn)`; stun stars, bursts, name tag, crown, place, «SPEC» through `Edge.direct`)
- Modify: `src/story/Actor.lua`, `src/story/Stage.lua` (`Stage.monster`: `Edge.draw`; `o.outline` ignored; reflection keeps none)
- Modify: overlay parts through `Edge.direct`: `MegacrabbyRender.lua` (`drawTarget`, floor shadows), Snowboss shadows, Tifón's wind marks, additive glows in gloomy, megagloomy, mortar, megacrabby_ice, cryo (grep `setBlendMode('add')` inside `render` of edged types), `PointAreas.drawProgress`
- Modify: `src/world/level/SceneLayers.lua`, `tools/tests/level_shots/main.lua` (`Edge.level = level` instead of `Silhouette.level` / `PlayerAdventure.lightLevel`)
- Test: `tools/tests/mechanics/main.lua` (`filo_propio`, `tapa_base` rewritten), `tools/tests/edge_look/main.lua` (`rasgo`)

**Interfaces:**
- Consumes: `Edge.draw`, `Edge.direct`, `Edge.level` (Task 1).
- Produces: `EntityTypes.EDGE_DEFAULT = { Enemigos = true, Jefes = true, Objetos = true }` (the real category ids; `Trampas`, `Mecanismos`, `Directores` and `Flappy` default to off — a Flappy-category type that is a creature sets `edge = true` itself); every entity instance has `self.edge` boolean; `owner.edgeThin = true` for non-player entities (1 px in simple mode, as `darkEdge` was).

- [ ] **Step 1: Write the failing cases**
  - `edge_look` `rasgo`: a gummy, a crabby_lava, a boss type → `edge == true`; a trap, a mechanism, a director → false; a data enemy JSON with `"darkEdge": [..]` → true; with `"edge": false` → false.
  - `mechanics` `filo_propio` (same scene as today, counting `Edge.draw` simple-mode copies instead of `Silhouette.draw`): above the surface 0, below > 0, for the local player and an `OnlinePlayer`; `Edge.level = nil` → 0.
  - `mechanics` `tapa_base`: the lid check unchanged; the edge part becomes "crabby, crabby_lava and gummy_magma all have `edge`".
- [ ] **Step 2:** `tools/tests/run.sh edge_look ONLY=rasgo` and `tools/tests/run.sh mechanics ONLY=filo_propio,tapa_base` → FAIL.
- [ ] **Step 3: Implement** the trait, the wrappers, the `Edge.direct` wraps listed above. `grep -rn "Silhouette\.\(on\|dim\|level\|around\)\|lightLevel\|darkEdge" src tools/tests` → only `Edge.lua`, `Silhouette.lua`, `DataEnemy.lua` (compat read) and `StoryResultsState` (`Silhouette.draw`, kept: no scene behind it).
- [ ] **Step 4:** the two commands → OK; `tools/tests/run.sh enemy_data` and `tools/tests/run.sh tool_editors` → OK; `tools/tests/run.sh level_shots SCALE=0.25 TIME=night -- assets/levels/<a night level>.json` with the setting on `simple` → capture shows edges on the player and enemies (look at it).
- [ ] **Step 5: Commit** «Borde: rasgo `edge` en la base (por categoría), jugadores, actores y cinemáticas por Edge.draw; lo que no es cuerpo por Edge.direct».

### Task 3: Light map before the composite

**Files:**
- Modify: `src/fx/Darkness.lua` (split), `src/states/adventure/AdventureState.lua` (`_renderScene`), `src/states/online/OnlineAdventureRender.lua` (`_renderScene`), `src/story/Stage.lua` (`drawSet`)

**Interfaces:**
- Produces:
  - `Darkness.build(level, camX, camY, sources, entities) -> boolean` (fills the 1/4 light canvas exactly as the first half of today's `render`; false when `Darkness.active` is false)
  - `Darkness.apply(level, scene)` (the multiply + `restoreGlow`, the second half)
  - `Darkness.lightCanvas() -> Canvas | nil` (the canvas filled by the last `build` this frame; nil if the last build returned false)
  - `Darkness.render(...)` = `build` + `apply` (unchanged signature, still used where no composite runs)
- The states fill their light-source lists and call `build` BEFORE `SceneLayers.draw`, and `apply` where `render` was.

- [ ] **Step 1:** Capture the baseline: `tools/tests/run.sh level_shots FIXED=1 TAG=antes SCALE=0.25 -- <a night level> <a dark level> <a depth level>`; `tools/tests/run.sh gloomy_rules LOOK=1`.
- [ ] **Step 2: Implement** the split and the reorder.
- [ ] **Step 3:** same `level_shots` with `TAG=despues` → pixel-identical to `antes` (compare with the harness's `FIXED=1` comparison); `gloomy_rules` → OK.
- [ ] **Step 4: Commit** «Oscuridad: build / apply separados (la luz se calcula antes de juntar las capas)».

### Task 4: Shader mode — actor canvas and composite

**Files:**
- Modify: `src/fx/Edge.lua` (canvases, composite shader via `Shaders.define('edge_composite', …)`)
- Modify: `src/fx/SceneCanvas.lua` (`SceneCanvas.pair() -> Canvas, Canvas`: the existing one + a second of the same size, same rebuild rule)
- Modify: `src/world/level/SceneLayers.lua` (routing + composite; returns the final canvas)
- Modify: `src/states/adventure/AdventureState.lua`, `src/states/online/OnlineAdventureRender.lua` (use the returned canvas for `Darkness.apply`; hit-stop `reuse` redraws the returned canvas of the last real frame)
- Test: `tools/tests/edge_look/main.lua`

**Interfaces:**
- Consumes: `Darkness.lightCanvas()` (Task 3), `Edge.level`, `Edge.direct` (Task 1).
- Produces:
  - `Edge.begin(scene: Canvas)` — shader mode only: clears the actor canvas (transparent) and makes it the target; remembers `scene` for `Edge.direct`.
  - `Edge.finish(light: Canvas|nil) -> Canvas` — composites `scene` + actor canvas + light (nil → white; sampled at `screen / 4`, nearest) into the other canvas of `SceneCanvas.pair()` in one full-screen draw, makes it the target, returns it.
  - `Edge.wants(entity) -> boolean` (= `entity.edge`; in simple mode always false: nothing is routed).
  - `SceneLayers.draw(...) -> Canvas` (the canvas holding the final scene).
- Order inside `SceneLayers.draw` (shader mode): … foliage back → back entities **without** edge → `Edge.begin` → back entities with edge → actors → front entities with edge → `Edge.finish` → particles → front entities without edge → foliage → bubbles → snow. Simple mode: today's order (particles between actors and front entities).
- Composite shader, per pixel: actor alpha `a` here; if `a > 0` output `mix(scene, actor, a)` (premultiplied as LÖVE stores canvases). Else scan 8 directions × 1..`W`; take the sampled actor pixel with the highest alpha `n`; if `n == 0` output scene. Else `ls = lum(actor.rgb/n) * light`, `lb = lum(scene.rgb) * light` (light = luminance of the light map here); `k = smoothstep(T_HI, T_LO, abs(ls - lb)) * smoothstep(L_LO, L_HI, lum(light)) * MAX_A * n`; colour = `LIGHT` if `lb < 0.5` else `DARK`; output `mix(scene, colour, k)`. Samples outside `[0, 1]` UV count as empty.

- [ ] **Step 1: Write the failing cases** (offscreen: a 64×64 scene canvas filled with a flat colour, a 16×16 sprite drawn through `Edge.begin/finish`, read back with `newImageData`)
  - `pixel_oscuro`: bg (0.05, 0.05, 0.08), sprite (0.08, 0.08, 0.1), light nil → the pixel 1 px outside the sprite's edge is ≥ 0.75 white-ish (r > 0.7); 3 px outside = bg.
  - `pixel_claro`: bg (0.92, 0.95, 1), sprite (0.85, 0.9, 0.95) → that pixel r < 0.2.
  - `pixel_contraste`: bg black, sprite white → that pixel = bg (no edge).
  - `pixel_mitad`: bg left half dark, right half white; sprite dark across the boundary → edge on the left side only.
  - `oscuridad`: bg and sprite dark, light canvas filled with 0.055 → no edge pixel (all = bg).
  - `translucido`: same as `pixel_oscuro` with the sprite at alpha 0.5 → edge alpha about half (r between 0.3 and 0.6), > 0.
  - `directo_sombra`: inside `begin/finish`, a dark rectangle drawn through `Edge.direct` gets no edge.
  - `aditivo`: an additive glow drawn through `Edge.direct` looks the same as drawn straight into the scene (pixel-equal).
  - `borde_pantalla`: sprite touching the canvas's left edge → the right-most column of the result = bg.
  - `tamano`: change `WINDOW_W/H`, call again → canvases rebuilt at the new size, no error.
  - `reuse`: a `SceneLayers.draw` then one with `reuse = true` → the drawn frame equals the first frame's final canvas.
- [ ] **Step 2:** `tools/tests/run.sh edge_look` → the new cases FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** `tools/tests/run.sh edge_look` → all OK. Captures (`SHOT=1` in `edge_look`, saved to `<save>/edge_*.png`): a dark crabby against a dark wall by day, an enemy on the Costa Helada snow, a night level, a `dark` level with an enemy outside the flashlight, a boss with shadows / markers (Megacrabby). Look at each.
- [ ] **Step 5:** `tools/tests/run.sh perf SCENES=menu,level:assets/levels/<a busy level>.json,boss` with `edge` = `shader` and = `simple` → note draw ms of each in `docs/testing/performance.md`; no new resources per frame.
- [ ] **Step 6: Commit** «Borde (modo shader): lienzo de personajes y una pasada que compara cada borde con lo que tiene detrás».

### Task 5: Cinematics without a decor, the intro card, the credits

**Files:**
- Modify: `src/fx/Edge.lua` (`Edge.scene(drawBg, drawActors) -> nil`: draws `drawBg()` into a scene canvas, `drawActors()` between `begin` / `finish` (shader) or plainly (simple: `Stage.monster` / `Actor` already go through `Edge.draw`), then draws the result where it was drawing)
- Modify: `src/story/Stage.lua` (`drawSet`: `Edge.level = set.level`, `Darkness.build` before, actors between `Edge.begin/finish`, `apply` after)
- Modify: `src/story/films/intro.lua` (lines ~105 and ~380: drop `outline = true`; the map shots go through `Edge.scene(function() map:filmDraw(...) end, function() Stage.monster(...) end)`), other film shots that draw the monster over a Flappy background (grep `Stage.monster` outside `drawSet` actors)
- Modify: `src/ui/IntroScene.lua` (drop `outline = true`)
- Modify: `src/story/LiveStage.lua` / credits (`opts.background(drawFn)`: the credits hand their background so it is drawn into the scene canvas before the stage; transparent pixels count as black)
- Keep: `src/world/level/Level.lua` still reads `outline` (field never renamed) but nothing uses it; comment says so.
- Test: `tools/tests/story_film` captures, `tools/tests/startup_intro` (intro card capture), `edge_look` `escena`

**Interfaces:**
- Consumes: `Edge.begin/finish/draw/level`, `Darkness.build/apply/lightCanvas`.
- Produces: `Edge.scene(drawBg, drawActors)`; `LiveStage.new(name, seed, { background = fn })`.

- [ ] **Step 1: Failing case** `edge_look` `escena`: `Edge.scene` with a dark bg and a dark monster at scale 5 → edge pixels next to the monster (shader mode), none with a light bg.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** `edge_look` OK; `tools/tests/run.sh story_film` (captures of the intro film's map shots and a decor scene: look), `tools/tests/run.sh startup_intro` (the card's capture: the monster reads where its background is dark), the credits capture from `story_flow` or its harness. `grep -rn "outline = true" src` → nothing.
- [ ] **Step 5: Commit** «Borde: cinemáticas (decorados, mapa, fondos Flappy), tarjeta del nivel y créditos con el sistema nuevo».

### Task 6: Docs, battery, release

**Files:**
- Modify: `docs/gameplay/dark-levels.md` (Silhouette row → Edge), `docs/art/fx-and-particles.md` (section "Contrast edge": both modes, values, `Edge.direct` rule), `docs/entities/overview.md` + `docs/entities/how-to-add-an-enemy.md` (trait `edge` replaces `darkEdge`), `docs/entities/enemy-editor.md`, `docs/entities/enemies.md` (line ~696), `docs/story/cinematics.md` (rim lines), `docs/design/level-intro-card.md` (note), `docs/architecture/menus.md` if it lists the ASSIST rows, `docs/design/accessibility.md` (the new option), `docs/testing/performance.md` (numbers from Task 4)
- Move: `docs/design/entity-edge-shader.md` + this plan → `docs/design/archive/` with status on top; update `docs/design/README.md`
- Modify: `version.txt` (+1)

- [ ] **Step 1:** `tools/tests/run.sh docs_reference`, `tools/tests/run.sh project_check` → OK.
- [ ] **Step 2:** `tools/tests/run.sh all` (gameplay render paths changed in SP and online) under Monitor → ends «TODO OK».
- [ ] **Step 3: Commit** «Borde de contraste: documentación; versión 0.5.X».
- [ ] **Step 4: Release:** `git fetch`, `git log HEAD..origin/master` empty, push master, `tools/deploy_server.sh`, report version + commit.
- [ ] **Step 5: Hand-off note:** not judged by a person: the look and thresholds, the simple mode's colours, the frame rate on a real Switch and Android.
