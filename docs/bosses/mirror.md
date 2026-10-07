# The Mirror (final boss) — `mirror`

The Reflection: it owns a real `PlayerAdventure` body and replays the delayed inputs of its target, so it literally
copies you; on top of that it has arena attacks (floating mirror portal, platform leaps) and a broken-glass event.
**Files:** `src/world/entities/types/bosses/mirror.lua`, `types/mechanisms/bossglass.lua`. **Art:**
`assets/images/bosses/mirror/` (the player's sprites through an invert shader + laugh pieces). **Sounds:**
`tools/sounds/mirror.py`. **Level:** `ruta_del_espejo`; arena `tools/levelgen/arenas/jefe_espejo.json`.
**Music:** `mirror_boss`. **Harnesses:** `boss_sim LEVEL=assets/levels/ruta_del_espejo.json`,
`online_boss LEVEL=tools/tests/online_boss/espejo.json`. Its shard is the last one: picking it up starts the ending.

## Behaviour

- **MirrorEnemy**: owns a real `PlayerAdventure` body (`self.body`) and feeds it
  the delayed inputs of its target through a stub `Input` (and a `Sound` proxy
  that lowers pitch). Players record their raw inputs every step
  (`pa.inMoveX, inCrouch, inJumpN, inCrouchN` in `PlayerAdventure:update`).
  It records ALL players, so switching target (nearest, with hysteresis) is
  seamless. `speedMult/jumpMult` on the body make it a bit faster/higher.
  Rendered with an invert-colors shader; laugh = Body_Arms* + Head_* + JoyEyes. It laughs at
  EVERY player death (`onPlayerDeath`: now if copying/landed/perched, else `laughPending`
  → as soon as it's on the ground). Its own attacks never daze it: 'recover' is a short
  landing pause without stars; only a PLAYER's ground pound stuns it ('ko').
  ARENA ATTACKS (rework, in progress with the user): every `attackEvery` s of copying
  (phase-scaled) it shatters ('warp_out', fx `mirror_shards`, sound mirrorWarp) and either
  appears in a floating mirror portal above the target ('portal': follows, locks the last
  `PORTAL_LOCK` s, floor marker `markX/markY` in netPack) and ground-pounds down ('dive';
  platforms stop it = shelter), or appears standing on an arena platform ('perch';
  `arenaPlatforms` = runs ≥2 cells with 2 free above, ≥2 above the zone floor) and leaps
  ballistically (height capped under the zone ceiling) to GP at the apex over the target
  ('leap' → 'dive'). Then 'recover' (dazed, stompable; a hit ends the chain). Its GP
  landing on a player = 2 HP (`GP_DAMAGE`, also the copied GP). Phases (`PHASES`: HP ≤
  66 % / 33 %): attacks more often, chains 2 / 3, copy delay ×0.85 / ×0.7. Crouch in
  perch/recover is VISUAL only (a real crouch drops through platform_drop). Sounds
  `tools/sounds/mirror.py` (warp, appear, portal). Harness: `boss_sim LEVEL=ruta_del_espejo`
  (attacks, GP = 2, leap lands on its mark, chains), `online_boss LEVEL=
  tools/tests/online_boss/espejo.json` (start next to the arena).
  **Broken glass event** (`types/mechanisms/bossglass.lua`, entity "Cristal roto de jefe", Mecanismos;
  rect like bosswall over the AIR row above the arena floor, shards stand on its bottom
  edge): idle → warn (cracks + red pulse, glassWarn) → active (shards, glassRise) → retract;
  only while its zone fights; fires every `every` s (first at `first`) and once per boss HP
  threshold `phase1/phase2` (0.66/0.33). Touching active glass = `interact` → `'launch', 0,
  -launchSpeed, 2` (all jumps recharged; `pa:launch(vx, vy, jumps)`, predicted via
  `Predictor:recordLaunch(vx, vy, jumps)`, client sound `er.launchSound`) + `onLaunch` =
  1 HP unless invulnerable. `unsafeAt(x, y)` → `BossZones.safeSpawn` never respawns there
  while dangerous. Mirror: while `glassDanger` it stops copying (`toPlatforms`: perch in
  place or warp to a platform) and chains platform→platform leaps (`platformTargetX`);
  touching the glass → `glassEscape` (1 HP + leap to the nearest reachable platform, GP
  onto it); back to copying when the event ends. Placed in ruta_del_espejo. Harness:
  `boss_sim LEVEL=ruta_del_espejo` (cristal / arriba / escapa / vuelve).
