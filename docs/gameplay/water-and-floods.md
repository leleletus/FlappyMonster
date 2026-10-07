# Water, air and floods

Water is a per-cell bit (any tile can be waterlogged) plus optional **floods**: rectangles whose water level rises and
falls. In water the player swims (weaker jumps that only recharge on ground), slowly loses air and drowns unless it
surfaces or catches an oxygen bubble from a **vent**.

**Files:** `src/world/level/LevelWater.lua` (water bodies, bubbles, vents, oxygen), `src/player/PlayerAir.lua`
(drowning, the Sonic-style countdown, splashes, air bar), `src/world/systems/Floods.lua` + the placeholder entity
`types/mechanisms/flood.lua`, `src/fx/WaterSurface.lua` and `assets/shaders/water.glsl` (drawing),
`src/world/tiles/materials/water.lua`.

**Configuration:** vents are level objects (`vents` in the level JSON; editor layer "Especial"); a flood is the
entity `flood` with a `corner` handle and timing props; difficulty scales air time (`airTime`) and the delay between
vent bubbles (`ventDelay`). Underwater design numbers for level builders are in
[generator-and-solver](../levels/generator-and-solver.md).

**Harnesses:** `flood_control`, `online_boss LEVEL=tools/tests/online_boss/fortaleza_flood.json`, `mechanics`.

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
