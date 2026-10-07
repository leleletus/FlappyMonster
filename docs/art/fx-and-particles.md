# Effects and particles

Render-side effects in `src/fx/`: `Particles.lua` (every particle kind; `Particles.emit(kind, x, y, opts)`),
`SpriteStrip.lua` (animation strips), `BossFx.lua`, `IceEncase.lua`, `IceDrips.lua`, `LavaFx.lua`, `Snowfall.lua`,
`WaterSurface.lua`, `NoiseMarks.lua`, `Darkness.lua`, `Silhouette.lua`, `Sky.lua`, `CaveAmbience.lua`; shared UI
celebration (confetti, fireworks) in `src/ui/Celebration.lua`.

**From the simulation** use `Entity.emitFx(kind, x, y)`: it reaches every client as an `fx` event (no options — a
variant needs its own kind name). **From drawing** call `Particles.emit` directly. Screen shake is a particle kind
(`shake_small`, `shake_big`, `shake_roar`); the level states add `Particles.shakeOffset()` to the camera.

## Particles

- `src/fx/Particles.lua` — Particles.emit(kind,x,y) — kinds: gp_land, gp_start, block_break, oneup, spawn, spike_land, spike_pop, collect, checkpoint, boss_hit, boss_blast, boss_big_blast, mortar_blast, fire_puff, ember, exhaust, smoke, sparks, mega_* (Mega Crabby), shake_small/shake_big (screen shake: states add Particles.shakeOffset() to the camera when drawing)

- **Physical particles** (`phys = true` in `Particles`): collide with the level set by
  `Particles.setLevel(level)` (Adventure/Online states): bounce off walls/ceilings,
  bounce and then REST on floors/platforms (`landingCross`), fall again without
  support, sink slowly in water; born inside a block → no collisions. Debris from a
  surface with a known normal (`opts.nx, ny`: the Mega on walls/ceilings) is born
  outside the block and looks for the material INTO the surface; on an invisible zone
  edge it uses the floor below. Impact kinds
  (block_break, spike_land, gp_land, spike_pop, mega_step/debris/dirt/slam/land) take
  the colours of the block they hit: `TileTypes.debris(def)` = tile `debris` →
  material `debris` → shades of its colour; the surface is probed around the point.
  A broken block's colours come from `Level:previousDef(c, r)` (setTileRaw/breakTile
  remember the old raw). Harness `subtiles`.

## Sprite strips

- src/fx/SpriteStrip.lua animation strips (frames side by side in one PNG): SpriteStrip.load(path[, frameW]) → :frameAt(t, fps), :draw(i, x, y, r, sx, sy)

## Ice drips and snowfall

- **Ice drips** (`src/fx/IceDrips.lua`, render-only, per client): tiles with `iceDrip` and air
  below grow drops (`fx/ice_drop.png`) that fall and splash. **Snowfall** (`src/fx/Snowfall.lua`):
  level JSON `"snow": true` (editor Nivel → Clima → "Nieve cayendo"), 3 depth layers of
  `fx/snowflakes.png`, visual only. Decoration `icicle` (Carámbano, `decorations/ice/icicle.png`,
  hangs from the top of its cell). Test arena `tools/levelgen/arenas/hielo.json`.
