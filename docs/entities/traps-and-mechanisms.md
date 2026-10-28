# Traps and mechanisms

Things that are not enemies: **traps** (Freezer, falling spikes, the mortar is an "enemy" by category but behaves
like a turret), **mechanisms** (trampolines, floods, point zones, boss walls, boss glass, phase blocks) and
**directors** (the invisible spike-rain orchestrator). Types and props: [reference/entities](../reference/entities.md).

Related docs: ON/OFF Activators and blocks are tiles → [tiles-and-blocks](../gameplay/tiles-and-blocks.md); floods →
[water-and-floods](../gameplay/water-and-floods.md); point zones → [game-modes](../gameplay/game-modes.md); boss
walls, glass and phase blocks → [bosses/system](../bosses/system.md); spike rain →
[autoscroll](../gameplay/autoscroll.md).

**Linking:** any type with `activatable = true` can be wired to ON/OFF Activators in the editor (tool "Conectar");
in game it asks `level:signal(id)`.

## Trampolines

- Trampolines (top/bottom faces need 120 px/s; UNDER WATER 25: the slow fall never reached 120 and only a ground
  pound launched): `solidFull` bodies with `bouncyFace`. The player's
  `moveAndCollide` records `pa.bodyHit = {o, face, speed}` (face of the BODY it
  hit this step). `e:interact` returns `'launch', vx, vy` when the face and
  speed match → `pa:launch(vx, vy)` + `e:onLaunch(pa)`; predicted on the client
  (`Predictor:recordLaunch`). States ready → bounce (0.1 s: everyone touching
  bounces) → extended (`cooldown`, just a wall) → retract → ready.

- FROZEN TRAMPOLINES (3.73.0): trampoline prop `skin` = 'auto' (default) | 'normal' | 'ice' (render only; editor
  "Aspecto"). Auto = the ICE texture (`trampoline/ice_normal.png` / `ice_extended.png`, the same art as the Icy
  Crabby's trampoline) in snowy levels — `level.spikeSkin == 'ice'` or `level.snow` — so no level data had to change
  and none can be left mixed (`Tramp.skinFor(props, level)`, needs `levelRef`: `wantsLevel`). New skin = 2 PNGs + one
  `SKINS` line. Today only lago_helado has a plain trampoline among the icy levels.

## Freezer (Congelador) and being frozen

- **Freezer** (`types/traps/cryo.lua`, entity "Congelador", Trampas; liquid-nitrogen launcher): solid 1-cell
  block (`solidFull`; prop `phase` > 0 = only from that boss phase on, see Phase system), prop `dir` (right/left/up/down; sprite drawn facing right, rotated). States
  idle → windup (`windup` s: shakes, gauge glows, frost puffs, cryoWindup) → fire (stream grows/leaves at
  `STREAM_SPEED` 1800 px/s for `burst` s, cut at the first solid tile = `reach` in netPack; cryoBlast) →
  idle. `mode` 'interval' (`interval`, `firstDelay`) or 'switch' (`activatable`: fires when its linked ON/OFF
  Activator changes, `trigger` any/on/off; linking it in the editor sets switch) — boss arenas: fires with
  the gates. Stream = hazard box `effect='freeze', time` → `pa:freeze(t)` (own-state index 30 `iceT`,
  `PF_ICE` 128, protocol v36): no control (FROZEN_INPUT), keeps its pose, slides/falls; each jump/crouch
  press removes 0.22 s; on break cryoFree + fx `ice_shatter` + 0.7 s invulnerability. Enemies in the
  stream: `Entity:freeze(t)` → common state 'frozen' (`canFreeze`: category Enemigos only; mortar no;
  bosses no unless they override; `freezeFloats` = stays in place, pufferfish), deadTimer = time LEFT,
  falls (flyers too), harmless (`Interactions.frozenCheck`: landing on it / GP → 'stomp' kills a stompable
  one, else 'shatter' = thaw), `thaw()` resumes the previous state with its timer. Look: `src/fx/IceEncase.lua`
  (9-slice `fx/ice_block.png` around the body + ice tint shader, blinks the last 0.6 s), used by the
  EntityTypes render wrapper, PlayerAdventure and OnlinePlayer. Art `assets/images/traps/cryo/` from
  `tools/art/world/make_cryo_sprites.py`; sounds `traps/cryo_*.wav` from `tools/sounds/cryo.py` (cryoFreeze is a
  SHARED sound). Particles cryo_puff/cryo_mist/cryo_blast/ice_freeze/ice_shatter. Harness `mechanics`
  (cryo_*). Drawn from PIECES (`tools/art/world/make_cryo_parts.py`, all 16x16 centred on the cell): body
  `cryo_body-Sheet` (always upright, 4 frames), cannon `cryo_cannon-Sheet` (drawn facing right, rotated to
  `dir`), feet `cryo_feet` (drawn facing down, rotated to the supporting side); `cryo-Sheet` = the classic
  assembly (editor icon). `Cryo:support()` (render only, needs `levelRef`: `wantsLevel`, also set by the
  editor) = the solid side holding it, never the firing side, preference floor → behind the cannon → sides →
  ceiling; nil = it HANGS: no feet, `cryo/chain.png` + `anchor.png` + `clamp.png` to the ceiling
  (`tools/art/world/make_cryo_chain.py`; two side chains when firing up). Harness `snowboss_look` (snow_cryo.png),
  `online_smoke LEVEL=tools/levelgen/arenas/congelador.json WATCH=gummy WANT=frozen WANTICE=1`,
  `editor_open PLAY=tools/levelgen/arenas/congelador.json`.

## Scale, Blizzard and Geyser (0.5.68)

Built on the generic systems of [carry-and-push](../gameplay/carry-and-push.md) (body parts, moving bodies, the air).
Designs and the user's verdicts: [new-props-plan](new-props-plan.md).

- **Scale** (`mechanisms/scale.lua`, "Balanza"): placed on the PULLEY cell; two pans (one-way moving body parts:
  the plank is rows 2-7 of the 48x8 pan art — the hitbox starts there, or things floated 8 px, the user) hang `drop`
  tiles below, `span` tiles apart. The heavier side goes down `travel` tiles, equal weights level out. Weight counts
  everything STACKED on a pan (a box with something on top weighs both: the user): players standing on it or on
  something of the stack (+ what they carry), entities resting on it or on the stack (`weight`: players 1, big box
  2, small box 1, Seed 0.5, enemies 1; flyers weigh nothing). The pan moves what is stacked on it; players ride it
  (`standBody`). A ground pound on a pan slams it down and LAUNCHES everything on the other pan (`power`). Pans STOP when they would hit a block, a
  platform or a box not in their stack (0.5.69, the user: they went through the floor; `Scale:panBlocked`); enemies
  pass through them. Pans are NOT drop-through (the user: boxes must be placed on them carefully with crouch + UP;
  a pan does not rise if that would push a box on it into a player above). Sounds v2 (the user: "more mechanical,
  chain / rope / wood"): rope creak, chain clinks and a wood knock. Net: the offset `d` in its netPack. Harness
  `mechanics` `balanza`, `balanza_tope`.
- **Blizzard** (`mechanisms/blizzard.lua`, "Ventisca"): an AREA (entity cell = top-left corner, `corner` = bottom-right).
  Calm for a random `gapMin..gapMax` s, then a `warn` s warning (three blinking arrows at the screen edge the wind
  comes from + `windWarn`), then `blowMin..blowMax` s of wind (`windGust`, streaks of the island) in one of the allowed
  directions (`dir_right/left/up/down`) that pushes everything with physics (`pushAt`). Its sounds come from the point
  of the area nearest to the player (an area can be a whole tower). Net: direction and gust length in its netPack.
- **Geyser** (`mechanisms/geyser.lua`, "Géiser"): placed on the cell above the floor (the vent fills its lower half).
  Idle `interval` s → `warn` s bubbling (`geyserRumble`) → `erupt` s column up to `height` tiles (cut at the first
  block) that lifts everything with physics (`pushAt`, no damage; since 0.5.69 SHARP — 1050 px/s reached almost at once —
  with a triple crest, spray and steam: the user found it slow; it fades out over the last 0.9 s — the column lowers
  and pushes less — instead of vanishing; spray, splashes and steam with per-particle randomness, `hash`; since 0.5.70 it lifts the FIRST thing in its column
  — `findLoad` — at a speed ÷ its total weight with what is stacked on it, systems/Weight, and the jet is cut at its
  underside: nothing above is pushed by it; the cut height and the factor travel in its netPack. The drawn jet and the push area MATCH (the user: the box
  looked like floating): the water reaches exactly `topY()` — clipped at the vent —, only things whose feet are inside
  it are pushed, and a load carried a bit past the jet's height by its momentum (`HOLD` 48 px) is still held: the jet
  stretches to touch it and pushes less the higher it goes) → idle. Meadow / coast water, fortress steam, cave
  glowing steam (gives light), volcano smoke (only pushes, the user). Snow: the column FREEZES into an ice pillar whose
  top is a one-way platform for `freeze` s (cracks the last second) and then shatters.
