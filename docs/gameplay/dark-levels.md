# Dark levels: flashlight, noise, light moods, echo

A level with `"dark": true` is played in darkness and that CHANGES the gameplay: the only light is each player's
flashlight (a battery that drains and recharges), enemies there hunt by SOUND, and noise can be used as a decoy.
Separately, every level has a render-only **light mood** (day, dusk, night, cave) and caves have **echo**.

**Files**

| File | Role |
|---|---|
| `src/world/level/Lights.lua` | flashlight geometry (cone, range, blocked by walls) — shared by simulation and drawing |
| `src/player/PlayerAdventure.lua` (`updateLight`) | the flashlight's battery, part of the simulation |
| `src/world/systems/Noise.lua` | what makes noise and how far it carries; what listeners hear |
| `src/fx/Darkness.lua` | draws the darkness, the light moods and everything that glows |
| `src/fx/NoiseMarks.lua` | the red "!" where a noise happened |
| `src/fx/CaveAmbience.lua`, `src/audio/Sound.lua` (`setEcho`) | ambience and echo |
| `src/ui/LightHud.lua` | the battery HUD |
| `src/fx/Silhouette.lua` | white edge of the player / outline of dark enemies where it is dark |

**Level JSON:** `dark`, `light` (day | dusk | night | cave | none; automatic by default), `echo`.
**To make something audible to enemies:** declare `noises = { soundName = tiles }` on the entity type (or `noise` on
a pickup); nothing else. **To make something glow:** `renderGlow()` / `lights()` on an entity, `light = {…}` on a
decoration or tile def.

The enemies of the dark: the Gloomy Crabby ([enemies](../entities/enemies.md)) and the Mega Gloomy
([megagloomy](../bosses/megagloomy.md)). **Harnesses:** `gloomy_rules`, `megagloomy_rules`,
`level_shots` (draws the mood; `LIGHT=0` without).

## Darkness and the flashlight

- **Dark level** = JSON `"dark": true` (editor Nivel → Fondo y clima → "A oscuras (linterna)"). It AFFECTS
  GAMEPLAY (not just a look). The only light is each player's FLASHLIGHT: action `light` (keyboard F / LShift,
  gamepad X / Y, touch = small button above the jump: `TouchControls.update(active, level.dark)`, sprite
  `ui/touch/light-Sheet.png`). `PlayerAdventure:updateLight`: toggles; on = drains `LIGHT_TIME` 7 s; off = recharges in
  `LIGHT_RECHARGE` 9 s; if it runs OUT it turns off and can't be lit for `LIGHT_COOL` 3.5 s; `pa:blindLight(t)` (a boss
  hit) forces it off. Part of the SIM: input bit `IN_LIGHT_P` 64, own-state 31-33 (`lightOn`, `lightBat`, `lightCd`),
  others see `PF_LIGHT` 256. Protocol v43. Sounds lightOn/Off/Out/Dead.

- `src/world/level/Lights.lua` (pure geometry, shared by sim and drawing): cone towards `facing`, `RANGE` 5.2 tiles, `HALF`
  27°, cut by solid blocks (`Lights.ray`); `Lights.lit(level, x, y)` → true + the light's origin.

- `src/fx/Darkness.lua` (render): after the scene + water effect and BEFORE the HUD, a quarter-res canvas starts at
  `AMBIENT` and each player adds, in steps, a halo (always: you see yourself) and, lit, the cone traced with rays;
  then it is MULTIPLIED over the screen (no shaders/stencils). It restores the previous canvas (harness captures).
  What must always show is drawn after it: entities with `renderGlow(camX, camY)` (`Darkness.renderGlow`). HUD:
  `src/ui/LightHud.lua` (icon `ui/flashlight-Sheet.png` + 8 segments, under the lives).

## Noise

- **Noise** (`src/world/systems/Noise.lua`) = what enemies can HEAR, and what the player can use as a DISTRACTION (Gloomies go
  look where it sounded). GENERIC: everything that makes noise and how STRONG it is (radius in tiles) lives in two
  tables there — `Noise.R` (things that are not an entity's sound, emitted with `Noise.emit(x, y, Noise.R.x)`: pickup 4,
  life 5, thin-ice crack 4, ON/OFF switch 7, hitting a boss 8, ice break 8, breaking a block 9, a hurt player 10, a
  killed enemy 12, ground pound 15) and `Noise.SOUNDS` (SOUND names that are also noise: trampoline 8, helmetBounce 6,
  helmetBreak 8, mortarShoot 10, spikeHit 8, cryoBlast 9, pufferInflate 7, bombIgnite 4, bombKick 6, bombBlast 26).
  `Noise.bind(level)` wraps the current global `Sound.play` once: any listed sound played while simulating emits its
  noise where its maker is = `Noise.src(x, y)` (set by `Interactions.run` around each entity) or else Sound's emitter
  (`Sound.getEmitter`, set by the states around each entity update); no position → nothing (UI, the player's own
  sounds). A NEW entity needs no change here: its type def declares `noises = { itsSound = tiles }` (registered by
  `EntityTypes.register`) or, for a pickup, `noise = tiles`. WALKING AND JUMPING MAKE NO NOISE. `faint` 3.5 = the
  Mega Gloomy's echolocation mark. Only recorded in
  DARK levels, in `level.noises` of the level bound with `Noise.bind(level)` (AdventureState
  on enter, server every `stepRoom`; the online client binds nil). Listeners: `Noise.heard(level, x, y, sinceSeq, k)`.
  Every noise leaves a NOISE MARK (the user's rule made visible: noise → mark → that's where they go look): fx
  `noise_s` / `noise_m` / `noise_l` → `Particles.emit` forwards them to `src/fx/NoiseMarks.lua` (SP and online, same
  path as any fx) → a red "!" (`fx/noise_mark.png`) for 1.5 s + a ring growing to the hearing radius, drawn by
  `Darkness.renderGlow` over the darkness.

## Light moods (every level)

- **LIGHT MOODS (all levels, render only)**: `level.light` = JSON `"light"` (day | dusk | night | cave | none) or auto
  (`Level.lightMood`: background 'cave' → cave, time dusk/night → that, else day; editor Nivel → Fondo y clima → "Luz").
  `src/fx/Darkness.lua` draws them with the SAME light canvas as the dark levels (`Darkness.MOODS`: ambient colour that
  multiplies the screen, × strength of the lights): dusk warm, night cool and darker with torches/lava glowing, cave =
  PENUMBRA (playable). The PLAYER gives NO light in these (user: night must feel like night) — only in dark levels. With a `depth` biome, everything below the surface
  line is cave penumbra (stepped transition band) even on a day level. Light sources: decorations with `light`, TILES
  with `light` in their def (lava) and the players. Soft lights = `RINGS` stepped circles (flat discs looked wrong).
  Cave mood also turns the ECHO on by default (`level.echo`). What is HOT keeps glowing: tile lights with `emissive`
  (lava: the cell itself is never darkened, bigger glow), entities with `e:lights()` → {x, y, r, color, a} (the mortar's
  fireballs; `Darkness.render(..., entities)`), and the red-hot pixels of sky layers (`Sky` builds a glow image per layer
  from its bright orange/red pixels — craters, lava streams, magma veins — and `Sky.renderGlow()` redraws them after the
  darkness, with the same clip via `Clip`). Mortar fireball REDESIGNED (`tools/art/world/make_biome_art.py mortar_flame`, 6
  frames; the user's original in `FlappyMonster_originals/assets/images/enemies/mortar/flame-orig.png`). `level_shots` draws the mood (`LIGHT=0` = without).

- **Background glow at night, FIXED (3.62.1)**: `Sky.renderGlow` used to REDRAW the red-hot pixels of the sky layers on
  top of the darkness — over blocks, boss walls and characters in front, and outside the gameplay viewport (into the
  letterbox bands). Now nothing is redrawn on top: with `Sky.punch` (set by the level states around `Sky.render` when a
  light mood is active) the glow is painted untinted into the scene canvas and its ALPHA is set to 0 (colour mask +
  'subtract'); whatever is drawn over it afterwards puts alpha back to 1, so only glow that is really visible stays
  marked; `Darkness.render(..., scene)` then restores exactly those pixels from the scene canvas with a shader
  (`restoreGlow`), under the current transform and scissor. Tools that don't pass the scene just get a darkened glow.

- **Glowing decorations**: a decoration type with `light = { r = px, color, a, dy, pulse }` (glow_mushroom,
  cave_crystals, torch, ice_crystal) adds a VERY subtle two-step light to the Darkness canvas (render only: it is not
  a flashlight for `Lights`). New luminous decoration = that one field.

## Ambience and echo

- **Cave ambience** (render-only sound, per client; never Noise): `DecoFx.drip` (stalactites) and `IceDrips` play
  'dripFall' when the drop lets go and 'dripSplash' where it lands (`DecoFx.sound` → `Sound.playAt`, random pitch,
  attenuated, with the cave echo; QUIET on purpose: `DecoFx.AMBIENT_VOL` 0.35, ambience layers 0.04-0.14 — the user
  wanted them as background, not something that stands out); `src/fx/CaveAmbience.lua` (`tick(level)` from both level states, only when
  `level.echo`) plays far drips every 2.5-7 s, a rolling pebble every 14-32 s and a low rock rumble every 24-50 s at
  random pitch/volume. Files `assets/sounds/ambience/` from `tools/sounds/ambience.py`.

- **Echo** (deep caves): level `echo` (default = `dark`; JSON `"echo": true/false` forces it; editor toggle "Eco")
  → `Sound.setEcho(1)` on entering the level (0 on `leaveMatch`). Every `Sound.play` schedules delayed, quieter,
  slightly lower repeats (`ECHO_DELAY` 0.21 s, ×0.5 each, up to 3) and the LOUDER it arrives (volume after distance ×
  `ECHO_W[name]`: a slam booms, a step barely) the more echo it leaves. Done with delayed clones in `Sound.update`
  (OpenAL effects aren't available on every platform). Music has no echo.

## History and decisions (dated notes)

Kept because they record WHY things are the way they are and what was tried and rejected. Where a note
conflicts with the sections above, the sections above describe the current behaviour.

- Lives HUD "x3": ALWAYS white with a black shadow (it was black except in dark levels: unreadable at night, dusk and
  in caves). The Icy Crabbies walking on the world map now have their small claws (`CRITTER.crabby_ice.claw`, same
  sheet and placement as `Crabby.SKINS.ice.claw`).

- 3.63.2 (after the user played it): (1) the background glow no longer showed at night — LÖVE's 'subtract' blend
  does NOT touch destination alpha, so nothing was being marked; `Sky` now builds a "hole" image per glowing layer
  (alpha 0 on glow, 1 elsewhere) and writes it with colour mask alpha-only + blend 'replace' (verified: pixels marked,
  streams bright, clipped by the boss walls). (2) Volcano blocks kept the GREY light edge the game draws on exposed
  faces: basalt/ash edges (and editor colours) now use the rock's and the ash's own light tones. (3) FINAL BOSS form:
  the fury was 8 bars and after the climax the loop jumped STRAIGHT to theme A ("it ends before the fury finishes
  developing; odd loop from the most intense to the calm start") → fury is 16 bars (2nd half: the riff a fourth up, Bm /
  C, then its hammered ending) and after the climax a 4-bar FALL = the intro again (mirror motif slowly over the
  dominant, timpani, the music empties and the roll rises), so A re-enters exactly as the first time. Loop 80 bars
  (121.5 s); vs A: fury +4.1 / +4.7, climax +5.4, fall −2.9 dB. Lesson: a long boss loop needs its own way back —
  never cut from the peak to the opening.
