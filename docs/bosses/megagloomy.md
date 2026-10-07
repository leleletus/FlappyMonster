# Mega Gloomy Crabby — `megagloomy`

The Caves boss, fought in the dark. ONE rule, visible on screen: **it only attacks where there is a red "!"** — made
by its echolocation ring or by the player's noise. It is immune except when it is tired AND a flashlight lights it.
**File:** `src/world/entities/types/bosses/megagloomy.lua`. **Art:** `assets/images/bosses/megagloomy/` (body, glow
and claws HAND-EDITED by the user). **Level:** `gruta_lugubre` (dark); arena
`tools/levelgen/arenas/jefe_lugubre.json`. **Music:** `crab_tantrum_gloomy`.
**Harnesses:** `megagloomy_rules` (`LOOK=1`), `boss_sim` / `boss_intro` / `online_boss` with `LEVEL=` that arena.
Background: [dark-levels](../gameplay/dark-levels.md).

## Behaviour

- **Mega Gloomy Crabby** (`types/bosses/megagloomy.lua`, "Mega Crabby lúgubre", `boss.megagloomy`; boss of the dark
  levels). Fourth version: MOSTLY terrestrial + its ceiling attack (v1 = "tedious, boring, confusing"; v2 lived on
  walls/ceiling and stabbed its legs down: odd; v3 was ground-only: the user wanted the ceiling launch back). ONE RULE,
  visible on screen: **it only attacks if there is a red "!", and it attacks THAT "!"**. Two sources of "!":
  (a) ECHOLOCATION 'ping' every `pingEvery` s (stops, raises the claws, snaps): ONE ring from its body that detects
  whoever it TOUCHES, even standing still and silent (user: echolocation doesn't need the target to make sound) →
  "!" there (`Noise.emit` faint + `tEcho`) → it JUMPS there ('pounce'); (b) player NOISES (see Noise: hit < hurt <
  kill < ground pound; jumps and steps are silent) = investigation points → it CHARGES toward them ('charge': dashed
  floor line to the wall `endX`; crouch under it or jump it). Either one within `CLAW_PICK` 4 tiles → CLAW instead.
  With a fresh "!" (`tAge ≤ FRESH` 4 s, cooldown over) → 'aim' (eyes blink, hiss, the attack's mark; `startAim`
  spends the "!"). CLAW ('claw'): the NEAREST claw aims at the player from its joint (`MG:clawAim()` = pivot +
  direction to `markX/markY`, used by sim, red dotted line and drawing alike): during 'aim' the mark FOLLOWS the
  player (`tPa`), any direction incl. up, locked the last `CLAW_LOCK` 0.2 s; the thrust hits along that line up to
  `CLAW_REACH` 240 px (`clawHit`) — the old horizontal box hit jumping players it didn't visibly touch. CEILING every
  `ceilingEvery` s (14; first at half): 'climb' (parametric path floor → nearest wall → ceiling, `MG:pathAt(u)`, body
  rotated by `ang`: ±90° wall, 180° ceiling) → 'ceil_ping' (a BIG ring, `RING_CEIL`) → 'ceil_wait' (mark = where the
  ring found a player, else straight below) → 'aim' (kind dive, target sprite on the floor; light doesn't cancel it)
  → 'dive' (launches itself there, flips to land upright, `slam`). After charge / pounce / dive it is 'tired'
  (`TIRED_T`): immune (bounce) unless a flashlight lights its body → 'dazzled' (covers itself with the claws + the
  usual STUN STARS orbiting over it = "vulnerable now"): stomp 1 / GP 2, one hit. Contact in an attack = 1 HP + push;
  LIT while aiming on the floor → 'flinch' ("…"), cancelled. Phase 2 (`phase2`): faster tables. RAGE (hp ≤ `rageAt`
  0.4): 'roar' (claws up), EVERYTHING × `rageSpeed` 1.45 (`MG:pace()` → table row + multiplier: walk, charge, aim,
  cooldown, climb, dive; like the Mega Crabby's `rageSpeed`), and it SHOWS like the Mega Crabby (`MG:angry()`): slight
  1-px tremble, soft reddish pulse, anger symbols (`BossFx.anger`, drawn in `renderGlow` so
  they show in the dark); 'shriek' every `shriekEvery` s (`level.lightScale` for `dimTime` s + reserve Gloomies);
  CRYSTALS grow ON THE CLAWS — never on the shell: crystals on the head look like spikes and the head is what you
  stomp. 'taunt' after an attack that hit somebody. DEATH is a crab's, not a robot's (`MG:defeat` override, no
  explosions): 'dying_curl' → 'dying_out' (`releasesZone`). x,y = centre of its SHELL (`BODY_ROW` 11, box 11x6 art
  px; legs don't count); art = the SAME pixel grid as the small one at scale 10 (`MEGA_B`, 9 frames 38x21 + glow).
  Intro: falls from the dark AT ITS EDITOR x (`onIntroStart` → `stand(level, self.x)`; it used to land at the zone
  centre wherever it was placed, while the camera looked at the editor spot). Music: zone `tentacle_gloomy`.
  CLAWS (user's picks): option B "Hoz" (long sharp sickle, 2 frames 14x7 `claw_left-Sheet.png`, right = mirror), at
  rest pointing INWARD ("C Ↄ": tips toward the body's centre) and LOW on the body (`CLAW_DY` 2 art px under the shell
  centre; the mockups had them too high); raised (ping, roar) = exact 90° turn, mirrored so the dorsal crystals face
  OUTWARD. `MG:clawPose(side, now)` → out, dy, raised, frame, outward (render-only). Rage crystals = mix of options
  B "Espinas" × C "Corona" (`CLAW_CRYSTALS`): `claw_rage_left-Sheet.png` (14x12: 5 crystal rows above the claw) +
  `claw_rage_glow-Sheet.png` (their tips, drawn in `renderGlow`). All from `tools/art/enemies/make_gloomy_sprites.py --apply
  [--pinzas X]` (montages `pinzas` / `cristales` → `FlappyMonster_pruebas/gloomy/`). The USER then HAND-EDITED
  `body-Sheet.png`, `glow-Sheet.png`, `claw_left-Sheet.png` and `claw_rage_left-Sheet.png` (3.34.0): running `--apply`
  again would overwrite their work — don't, unless they ask (then port their edits into the generator first).
  netPackExtra: phase, frame, face, mark x/y (claw: the aim point), endX, attack kind (1 charge, 2 claw, 3 pounce,
  4 dive), light scale, icon, rage, ang·100, pings {id,x,y,t,max} (protocol v46). Arena
  `tools/levelgen/arenas/jefe_lugubre.json`; real level **gruta_lugubre** "Gruta Lúgubre" / "Gloomy Grotto"
  (`levels_boss.py`, cave theme, dark: no spikes or pits, Gloomies, then the arena, zone from column 88).
  `retheme.py` has NO --help: any unknown flag runs it over EVERY level — pass level names. Harnesses
  `megagloomy_rules` (+ `LOOK=1`: claws, ring, rage, each telegraph in the dark), `boss_sim` / `boss_intro` / `online_boss`
  with `LEVEL=` that arena.
