> **Archived design document.** Status: BUILT (3.20.0) with the changes noted in its section 10, see [snowboss](../../bosses/snowboss.md).
> Copied unchanged on 2026-10-31 from `FlappyMonster_pruebas/boss_bola_de_nieve/plan.md`. It records what was proposed and decided at the time: the system pages win where they differ, and paths or ids below may be out of date.

# Boss plan — "Gran Bola de Nieve" (Big Snowball)

Mockups (same folder): `vista_previa.png` (montage), `panel_1..4.png`, `sprite_*.png`.

Inspirations: **Chill Bully** (Mario 64 — sumo pushing on an icy ring), **Mr. Frosty** (Kirby —
slides and throws ice), **Chill Penguin** (Mega Man X — slides across ice, freezes things,
icicles from the ceiling), **Polar Knight** (Shovel Knight — snow and spikes raining down),
**Mr. Blizzard** (Mario — snowballs from the mouth). The twist that makes it ours: the arena is
a frozen lake, and **the player beats the boss with the environment** (thin ice, ON/OFF gates,
bombs), not just by stomping it.

---

## 1. Personality

A playful snowball who thinks this is a **snowball fight**. Happy at first: it giggles, bounces,
and throws snowballs to "play". When you hurt it, it gets offended (angry sprites), rolls faster
and bigger, and starts cheating (snowballs with bombs inside). At low HP it **cracks** and
panics. When it loses, it breaks apart and a tiny, embarrassed snowball rolls off (a callback to
the Mega Crabby's ending).

- **Happy sprites** = phase 1 (and the intro).
- **Angry sprites** = phases 2 and 3.
- **Squash frames 1/2** = landing / roll wind-up / being hit (squash & stretch).
- **Mouth-open frame** = shooting.

## 2. Arena — "Lago Helado" (frozen lake)

20 × 11 cells, as in the mockup:

```
####################
#..................#     icicles hang from the ceiling (decoration + falling hazard)
#..................#
#..................#
#.sss..........sss.#     two SNOW platforms (safe spots, height 4)
#.A..............A.#     ON/OFF ACTIVATORS under each platform (head bump / GP)
#..................#
#Fb.......tttt....bF#    ON BLOCKS ("ice gates") at both ends of the floor; THIN ICE lake in the middle
#iiiiiiii~~~~iiiiii#     slippery ICE floor; water under the thin ice
F = FREEZERS (Congelador, mode 'switch') in the walls, linked to the same activators as the gates
####################
```

- Boss walls close the entrance and exit (material **snow**, already supported).
- Background: surface `snow` at **dusk**, depth `icecave`, snowfall ON, boss music.
- Respawn spots are the two snow platforms (safeSpawn already avoids unsafe places).

## 3. Ice mechanics (new: slippery ice)

Today ice does **not** slide (the material has no `friction`). Proposal:

- Material `ice` gets `friction = 0.25` (the player physics already reads `ground.friction`), so
  both **ice and thin ice** slide. This also changes the ice islands in `torre_viento`; that's
  fine and it fits, but it should be decided explicitly.
- The **boss slides** on ice too: after a roll it can't stop at once and keeps sliding
  (`ICE_DRIFT`), which is what makes the gates and the lake work.

## 4. How it takes damage (it's never vulnerable while rolling)

| Situation | How it happens | Damage |
|---|---|---|
| **Dizzy** (`dizzy`, spiral eyes) | It slams into a raised ON gate / a wall at full speed, or a kicked bomb blows up next to it | stomp 1 · **GP 2** |
| **Frozen** (`frozen`, in an ice block) | A **freezer** stream hits it: the freezers fire whenever an activator toggles (the same moment the gates move) | **GP 3** (breaks the block) |
| Bomb blast | A lit bomb-snowball kicked back at it explodes within its hurt radius | 1 + dizzy |
| Landing on it while it's happy/idle | — | immune bounce (like the other bosses) |

HP: 14 base + 4 per extra player. Invulnerability after each hit (existing boss rules,
anti-GP-spam `STUN_INV`).

## 5. Phases and attacks

### Phase 1 — "Snowball fight" (happy, 100% → 60%)
1. **Hop** around the arena (squash on each landing; the landing cracks thin ice by 1 stage
   if it lands on it).
2. **Snowball arc**: mouth open, spits 3 snowballs in arcs (1 HP each). They splat into snow
   puffs; on thin ice they don't break it.
3. **Roll**: wind-up (squash frames + shaking, the floor marker shows the direction), then rolls
   across the arena. On ice it **slides past the end** → if an ON gate is up, it crashes
   → **dizzy 2.5 s**. If the gates are down, it bounces off the arena wall and stops (no
   damage window), so the player learns to raise the gates with the activators.
4. **Freezer trap** (any phase): hitting an activator toggles the gates AND fires the wall
   **freezers** (short liquid-nitrogen burst, with windup). If the boss is in the stream →
   **frozen** in an ice block for ~4 s → GP from above = 3. The freezers also freeze the
   player (mash jump to break out) and minions, so timing matters. Thin ice stays as terrain
   (its landings crack it; falling in = just water, no freeze).

### Phase 2 — "Now it's serious" (angry, 60% → 25%)
Transition: a short cinematic (the camera stays fixed, HUD visible). It inflates (scale
×1.0 → ×1.2), roars, and the screen shakes; the **icicles** on the ceiling start to rattle.
1. **Faster roll** that bounces off walls once (two crossings).
2. **Bomb-snowballs**: some of the snowballs carry a lit fuse. They land and become **lit bomb
   objects** (the existing `bombobject` + `throw()`); touching them kicks them, so the player
   can **kick them back** at the boss → blast = 1 + dizzy. They also break thin ice (chaos) and
   ON/OFF activators flip on the explosion (already in `Explosions.blast`).
3. **Body slam**: jumps high and slams → snow shockwave along the floor (jump over it),
   **icicles fall** (the existing `rainspike` orchestrated by the boss, with a shadow warning on
   the floor) and its weight cracks thin ice by 2 stages if it lands on the lake.

### Phase 3 — "Avalanche" (cracked + angry, < 25%)
1. Cracked sprite overlay, sweat drops, a faster idle tremble.
2. **Avalanche roll**: rolls continuously and bounces off everything for ~6 s, growing; the
   only way to stop it is an ON gate (or the lake trap).
3. **Snow burial**: it buries the activators under **packed-snow breakable blocks** (new snow
   tile variant of `breakable`). The player must head-bump or GP them to dig the activators out
   again (uses breakable blocks + GP).
4. Desperation snowball barrages (5-spread, bombs mixed in).

## 6. Intro cinematic (generic `introLength` boss intro)

0. The fight zone starts → players frozen, cinema bars, music silent.
1. A **tiny snowball** rolls down from the top-left of the screen, bouncing on the snow
   platforms, **growing with each bounce** (scale 0.3 → 1.0), leaving a snow trail.
2. It crashes into the middle of the lake area → a big snow puff and screen shake; the
   thin ice cracks but holds.
3. A face appears (the happy idle), it giggles (squash bounce ×2, sound `snowLaugh`) and
   **spits a snowball at the camera** → a "snow splat" fills the screen for 0.5 s and slides
   off (a new screen effect, drawn above the HUD).
4. Name typed in: **GRAN BOLA DE NIEVE** / **BIG SNOWBALL**. The fight starts.

## 7. Death sequence (own states like the Mega Crabby)

1. `dying_crack`: freezes mid-air in the angry hurt frame, cracks spread (overlay frames 1→3),
   with ice-crack sounds.
2. `dying_burst`: bursts into a big snow explosion (chunks + powder, physical particles that
   settle on the floor) plus a soft shake; the thin ice refreezes.
3. `dying_flee`: a **tiny snowball with a face** (`flee` sprite, embarrassed sweat drop) is left
   behind and rolls away through the boss wall, which opens first (`releasesZone`).
4. The snowfall slows down, and the sky turns from dusk to clear (optional: the level `time` changes on clear).

## 8. Assets

### Sprites (`assets/images/bosses/snowboss/`, generator `tools/ui/make_snowboss_sprites.py`)
Originals restyled (originals kept outside the repo):
- happy: idle, squash 1, squash 2, shoot; angry: idle, squash 1, squash 2, shoot; snowball.

New (16×16 unless noted):
- **dizzy** ×2 (spiral eyes, alternating) · **hurt** (eyes shut, squash) for happy and angry.
- **roll** ×4 (the body rotated 0/90/180/270, face moving: true pixel rotation, no blur).
- **cracked** overlay ×3 (more cracks each) · **sweat** drop strip ×2.
- **frozen** ice-block overlay 22×22 (semi-transparent ice, glints) · **breath** frost puff strip.
- **bomb-snowball** 14×16 (snowball with a lit fuse; 2 spark frames).
- **flee** mini snowball with a face 12×12 ×2 (rolling).
- **snow splat** (screen effect) 64×36 ×3 (hit, drip, gone).
- Ice gate / packed snow: new tile variant **packed snow** (breakable, snow texture with cracks).

### Sounds (`assets/sounds/bosses/snowboss/`, generator `tools/sounds/snowboss.py`)
snowLaugh (giggle), snowRoar (angry, low, with frost hiss), spit ("ptoo"), splat (soft snow
hit), rollLoop (crunchy rumble, tracked), slam (deep thud + crunch), crashGate (crash into ice
gate), dizzyTweet, freeze (ice forming), iceBreakFree (block shattering), crack ×3 (death),
burst (big snow explosion), flee (tiny squeaky roll), introRoll (growing roll).

### Particles (`src/fx/Particles.lua` kinds)
snow_puff (landings, splats), snow_trail (while rolling, physical), snow_chunks (crash/burst),
frost_breath (blue mist while shooting), ice_freeze (the block forming: shards inwards),
snow_shock (floor shockwave ring), icicle_warn (shadow on the floor), snow_splat_screen.

### Music
Boss track: reuse a catalog boss track, or generate an icy variant (bells/celesta over
`boss_nes`, chiptune) with the music tools (to be verified with numbers, not listened to).

## 9. Code plan

1. **Material**: `ice.friction = 0.25` (+ the boss reads the friction of its floor for drift).
   Test: `mechanics` case "ice slides" (stopping distance on ice > on stone).
2. **`types/snowboss.lua`** (`Entity.extend(Boss)`), `category='Jefes'`, `boss={title=...}`,
   props via `Boss.props({hp=14, hpPerPlayer=4}, {rollSpeed, phase thresholds, gatesNeeded...})`.
   - States: `intro` (generic intro hooks) → `idle/hop` → `shoot` → `windup` → `roll` →
     `slide` → `crash`/`dizzy` → `slam` → `frozen` → `phase2_trans` → … → `dying_crack` →
     `dying_burst` → `dying_flee` → `dead`.
   - Everything drawn = f(state, deadTimer, x, y, facing, phase) so online matches.
   - `netPackExtra`: phase, scale×100, roll angle, crack stage, frozen timer.
   - Projectiles: own list with stable ids (like the mortar); bomb-snowballs spawn a reserve
     `bombobject` via `summons()` (shared indices server/client) and `throw()`.
   - Interactions: `interact(pa)` side-effect free: immune bounce unless dizzy/frozen;
     rolling = contact damage 1 + knockback (or a squash if it rolls over you).
   - Environment: `level:crackIce(c, r, n)` on landings; gate crash = an ON block solid in its
     path (`level:getDef` + `switchBlock.active`); thin-ice fall = no floor under it → water
     (`level:liquidAt`) → just water; frozen = the boss overrides `canFreeze`/`freeze` (Entity freezer API); burial = `level:setTileRaw` to packed snow (queued as tile
     events, SP/server only).
   - Icicles: the boss triggers the `rainspike` entities of its zone (like `spikerain`).
3. **Explosions.blast**: bosses with `onBlast(x, y, dist)` take the bomb hit (generic hook).
4. **Arena level** `lago_helado.json` (or graft into a snow level) + `tools/levelgen/arenas/
   jefe_nieve.json` for tests.
5. **Lang**: `boss.snowboss` (es/en), intro/name.
6. **Editor**: overlay with the roll lane and the slam radius; the zone music picker
   already exists.
7. **Protocol** bump (new entity type + netPack), `version.txt`.
8. **Tests**: `boss_sim LEVEL=…jefe_nieve.json` (phases, dizzy on gate crash, frozen on thin
   ice, bomb kickback = damage, GP 2/3), `boss_intro`, `online_boss` (states seen by the
   client), `boss_frames`.

## 10. Order of work (suggested)

1. Slippery ice — DONE (3.18.8). Freezer device — DONE (3.19.0).
   Boss — DONE (3.20.0): all phases, intro, death, arena `jefe_nieve` + level `lago_helado`. CHANGE vs this plan:
   the thin-ice lake was REMOVED (falling into the hole did nothing): the arena is all ice; activators drive the
   gates AND two freezers each (wall + ceiling); packed snow only blocks players. Music: `winter_nes` (chiptune).
2. Sprites + sounds (the generators) → previews for approval.
3. Boss phase 1 (hop / shoot / roll / dizzy / thin-ice trap) + arena + tests.
4. Phase 2 (bombs, slam, icicles) → phase 3 (avalanche, burial) → intro → death.
5. Online pass (netPack, client renders) + `online_boss`.
