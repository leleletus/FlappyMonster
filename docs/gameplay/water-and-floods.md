# Water, air and floods

Water is a per-cell bit (any tile can be waterlogged) plus optional **floods**: rectangles whose water level rises and
falls. In water the player swims (weaker jumps that only recharge on ground), slowly loses air and drowns unless it
surfaces or catches an oxygen bubble from a **vent**.

**Files:** `src/world/level/LevelWater.lua` (water bodies, bubbles, vents, oxygen), `src/player/PlayerAir.lua`
(drowning, the Sonic-style countdown, splashes, air bar), `src/world/systems/Floods.lua` + the placeholder entity
`types/mechanisms/flood.lua`, `src/fx/WaterSurface.lua` and `assets/shaders/water.glsl` (drawing),
`src/world/tiles/materials/water.lua`; the Frozen Coast additions (2026-10-29): the TIDE and FREEZING WATER (below) and
the floating ICEBERG ([carry-and-push](carry-and-push.md#the-iceberg-floating-ice)), `Level:waterSurfaceAt` and
`Level:coldAt` in `src/world/level/LevelWater.lua` / `Level.lua`, the frost meter in `PlayerAir.lua`.

**Configuration:** vents are level objects (`vents` in the level JSON; editor layer "Especial"); a flood is the
entity `flood` with a `corner` handle and timing props; difficulty scales air time (`airTime`) and the delay between
vent bubbles (`ventDelay`). Underwater design numbers for level builders are in
[generator-and-solver](../levels/generator-and-solver.md).

**Harnesses:** `flood_control`, `online_boss LEVEL=tools/tests/online_boss/fortaleza_flood.json`, `mechanics`,
`iceberg_rules` (tide, freezing water, icebergs; its level `tools/tests/iceberg_rules/costa.json` also runs online:
`online_smoke LEVEL=tools/tests/iceberg_rules/costa.json WATCH=iceberg WANT=warn,sunk WANTICE=1`).

## Oxygen bubbles

- Oxygen bubbles: `Level:checkVentOxyCollision` = visible circle of bubble1
  (offset -3.5,-10.5 from b.x,b.y, r 24.5 + 6 px pad) vs the whole outer box.
  F1 draws the circles; breathing point = `getHeadPoint` (top of head).

## Floods

Editor: entity "Inundacion" (Trampas); its cell = top-left, prop `corner`
(`point` handle, moves with the entity) = bottom-right. Props: startLevel/maxLevel
(tiles above the rect bottom), startDelay, riseSpeed/riseStep/risePause,
holdTime, fallSpeed/fallStep/fallPause, lowTime. `Level.fromData` builds
`level.floods` from those placements; the entity itself does nothing in game
(never sent: `netAtRest`). The water level is a PURE function of
`level.floodTime` (`Floods.levelAt`): SP `Floods.advance(level, dt)`, server
`Floods.setTime(level, tick*TICK_DT)`, client = snapshot clock + ping (the tick
at which its predicted inputs get processed; 0 corrections in tests). Physics:
`Level:liquidAt` returns water below `f.surf`, so swimming/drowning/splash/
fireballs work unchanged. Render in `renderWaterEffect` (distortion + tint per
cell, over EVERYTHING it covers incl. solid blocks — only tile water is skipped, no double tint). Surfaces (floods AND tile water
with air above: `Level:isWaterSurfaceCell`) use `src/fx/WaterSurface.lua`: tint
drawn in 4-px columns whose top follows the wave (no flat edge behind it);
distortion starts `WaterSurface.MARGIN` px below the surface. `Floods.updateFx`
(clients only): 'floodRise'/'floodFall' sounds when the water starts moving
(each step too), bubbles via `Level:spawnBubble`, born at the lowest OPEN water point of a random column
(the flood rect may start inside blocks: water rising from under the ground). Level `marea_alta.json`.
**Undertow** (flood prop `undertow`, px/s signed, 0 = none; 0.5.30): while the flood is FALLING, the water drags
anything in it sideways — `Floods.currentAt(level, x, y)`, added to the player's horizontal move
(`PlayerAdventure`); foam particles `undertow_foam` run that way. **Warning** (0.5.34, the user: "apart from the
current lines there is not much telling the player"): when it starts dragging and the listener is in the flood or
within 4 tiles, `Floods.updateFx` (clients only) sets `f.alertAt` and plays `undertowAlert`
(`assets/sounds/water/undertow.wav`, `tools/sounds/mechanics.py`: water rush + two falling beeps); while it drags,
`BossHud.drawUndertow` shows "¡RESACA!" (`hud.undertow`) between two arrows (`ui/icons/current.png`, flipped when
it drags left) at the top centre — big and shaking on entry, then pulsing with the arrows stepping that way. Used by the Giant Pufferfish's cove
([giantpuffer](../bosses/giantpuffer.md)). Pufferfish follow a falling flood and flop / die on dry ground
([enemies](../entities/enemies.md#pufferfish)).
**Connected floods** (flood prop `control`): 'cycle' (default, the pure time cycle),
'boss' (zone prop `zone`, 0 = the overlapping/nearest one: runs its cycle from the fight
start while the zone is in 'fight' and a boss is alive and not dying; then falls to its
minimum and stays — fortaleza_malvada) and 'switch' (ON/OFF blocks linked to it: any
linked block ON → rises to max and stays; all OFF → falls to min; steps/pauses honoured).
**Links are generic**: level JSON `"links": [{col,row,to=id}]` (old key `flood` still
read) from an ON/OFF block to any ACTIVATABLE entity (type def `activatable = true` →
prop `id`, auto-added if the type doesn't declare it; optional `onLink(props)` run by
the editor when a block is linked, e.g. flood → control 'switch'). Game side:
`Level:linkedCells(id)`, `Level:signal(id)` (any linked block ON; authoritative in SP and
server — send the resulting state to clients, like floods do). Editor: a link disappears
with its block (`Model:set` drops it when the cell stops being ON/OFF; `pruneLinks` on
load), "Quitar conexión" in the inspector, ids unique across all activatables. A controlled flood stores
only `{active, t0, L0}`; its level is still a pure function of t
(`Floods.controlledLevelAt`). `Floods.control(level, t)` (SP inside `Floods.advance`,
server before `setTime`) decides the changes; the snapshot carries `fc =
Floods.netPack` → client `Floods.netApply` and computes the water at its predicted time.
Editor: Bloques layer → tool **Conectar** (K): click an ON/OFF block → pick its flood in
the Selección tab (+ "Empieza encendido"); links drawn as yellow dotted lines; flood ids
kept unique (`Model:fixFloodIds`); warnings for dangling links. Harness `flood_control`
(+ `online_boss` with `tools/tests/online_boss/fortaleza_flood.json`). Protocol v25.

## Tide (flood `control = 'tide'`)

- A flood that rises and falls BY ITSELF, smoothly (a sine), between its minimum (`startLevel` = low tide) and its
  maximum (`maxLevel` = high tide): `tidePeriod` s for a whole tide, `tidePhase` = where the cycle starts (fraction of
  the period: 0 = low tide rising, 0.5 = high tide falling). Editor: "Se mueve" → "Marea" (the rise / fall props hide).
- Like the cycle it is a PURE function of `level.floodTime` (`Floods.tideAt`): nothing travels online
  (`Floods.netPack` only carries the boss / switch floods, `Floods.controlled`), every client computes it at its
  predicted time. Its phase is `rise` / `fall` from where it is going (`hold` / `low` in the top / bottom 4 %), so an
  `undertow` also drags on the falling tide.

## Freezing water (flood prop `cold`, level key `coldWater`)

- `Level:coldAt(x, y)` = the seconds that water allows (a flood with `cold > 0` — its own water —, or the tile water of a
  level with `"coldWater": s`), or nil. Editor: the flood's "Agua helada: congela a los (s)"; the level's "Agua helada
  (s; 0 = no)" (Nivel → aspect section). It is drawn paler (`coldTint` of the water material) so it reads as icy.
- The player (`PlayerAdventure:updateFrost`, `PlayerAir.lua`, after the drowning step): while the body centre is in
  freezing water `frostT` counts; at `cold × airTime` (the difficulty's air modifier) it FREEZES — the same ice block as
  the Freezer (`pa:freeze(FROST_ICE)` 3 s, mash any button to break out, `ICE_FREE_INV` after). Out of the water (or in
  normal water) `frostT` is 0 at once; inside the ice it stays 0, so after breaking out in the water it starts again.
  Invulnerable at the limit (just respawned) it waits full until it can freeze.
- HUD: the FROST METER (`renderFrostBar`, drawn by `renderAirBar` — local player only) above the air bar, pale blue,
  pulsing past 75 %, with the snowflake icon `assets/images/ui/icons/frost.png` (`tools/art/world/make_iceberg.py`).
- Network: `frostT` is index 40 of the own state (`Protocol.packOwnState`); the client predicts it like the air
  (needs a `Protocol.VERSION` bump). Others only see the ice (`PF_ICE`).

## History

- 2026-10-29 (the Frozen Coast, the user's approved design `FlappyMonster_pruebas/islas_heladas/diseno.md` §A 2-3):
  tide and freezing water as options of the existing flood / level water, not new tiles. Not yet felt by the user.
- 0.5.11 (review): oxygen bubbles (gameplay: they give air) no longer depend on the bubble images having loaded, and
  every bubble's zigzag uses the level's own clock (`level.waterT`), not the wall clock (rule 1: the pause no longer
  moves them). The headless server already spawned them (it gets placeholder images). Harness `online_smoke
  WANTOXY=1` (in the battery). Drowning does not run while the player is frozen (boss intro, end of a bonus) and
  does not kill while invulnerable (level already won): harness `mechanics` (`ahogo_ganado`).
