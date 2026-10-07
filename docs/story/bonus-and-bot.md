# Bonus matches and the bot

Each world has one optional **bonus**: a King-of-the-Hill arena played against an expert BOT. It opens when the
world's boss is beaten and does not count for progress. The same match runs in Free Play for any level with point
zones and no finish.

**Files:** `src/story/BonusMatch.lua` (the match inside `AdventureState`), `src/ai/Bot.lua` (decisions),
`src/ai/BotNav.lua` (navigation graph built with the REAL player physics; `assets/nav/<level>.json`),
`src/world/systems/PointAreas.lua` (zones), `src/story/Score.lua` (`bonus`), `src/story/Run.lua` (`bonusResult`).

**The bot in one paragraph:** a real `PlayerAdventure` driven by input bits at a fixed 1/60 step. Scoring comes
first: it goes to the active zone and holds it; it attacks (jumps on you and ground-pounds, launching you far) only
if you are in its zone or scoring within its chase radius; it presses ON/OFF Activators when that gives it floor or
takes yours; it never ground-pounds breakable floor; it waits out floods. It is immortal. Hostility scales with the
difficulty (`botRest`, `botChase`, `botCount`: two bots on Xtra Extreme).

**Data rule for every level with point zones** (checked by `bot_nav`): enemies respawn and give 40 % of their
points; no extra-life items; the level's music is its island's `_bonus` track.

**After changing an arena:** `tools/tests/run.sh bot_nav BUILD=1` rebuilds the nav files (they also rebuild on the
device when stale). **Harnesses:** `bot_nav`, `story_flow bonus`.

## The match and the bot

- **Stage 8 ✔ — BONUS: King of the Hill vs the BOT.** One optional bonus per world (`Worlds.LIST[w].bonus`,
  `Worlds.bonus(w)`; NOT in `Worlds.nodes`: it doesn't count for progress or unlocks): pradera isla_flotante, costa
  cala_de_los_muelles, fortaleza ciudadela_alterna, nieve lago_de_cristal, cuevas cripta_del_silencio (dark), final
  cantera_real (rethemed volcano). Opens when the world's boss is beaten (`Run.bonusState(w)`); FIRST win = +1 life +1000 points
  (`Run.bonusResult`, save field `bonus[id] = {won, best, played}`). Map: a blue "B" node on a short branch from the
  castle (`overworld.json worlds[i].bonus`; in `StoryMapState` it is stop n+1 of its world: `mapNodes` / `stateOf`).
  MATCH = `src/story/BonusMatch.lua` inside AdventureState (`args.bonus = { onEnd }`): `BonusMatch.TIME` 60 s (story and
  Free Play; ONLINE King of the Hill = 100 s: koth `DEFAULT_TIME` and every arena's `matchTime`), HOSTILITY BY
  DIFFICULTY (`Difficulty` `botRest` × the rest between ground pounds, `botChase` tiles, `botCount`): easy 3.5 / 3,
  normal 2 / 5, hard and no difficulty 1 / 7 (the user's reference), extreme 0.7 / 10, Xtra the same with TWO bots
  (second one from the centre; the score to beat is the BEST bot's; `bonus.bots`), both score
  from the point zones, more points wins (tie = not won), HUD "TÚ n · clock · BOT n"; your adventure lives are NOT
  used (99, never written back); your ground pound near the bot shoves it too.
  THE BOT (`src/ai/Bot.lua`; user's brief: its job is to keep you from sitting in the zone, by ground pounds; IMMORTAL
  for simplicity — `pa.immortal`: hits, knockback and enemies still affect it, but no HP loss, death or drowning; a
  kill = a hop + blink): a real `PlayerAdventure` driven by input bits each frame. If you are in a zone and its cooldown
  is over it hunts you through the nav graph and, within `ATTACK_R`, jumps at you and GROUND-POUNDS on top: `Bot:push`
  launches you far (`PUSH_VX` 1150) with a short stun; then `attackCd` (`ATTACK_CD` 0.45 s × 0.7-1.5 / the difficulty's
  `enemyPace`). VERY HOSTILE (user): it also chases you when you are within `CHASE_R` 7 tiles even outside a zone, and
  attacks whenever you are in range, whatever it was doing.
  Otherwise it goes to the best zone that has FLOOR NOW (`Bot.pickZone`: more points first, all-thin-ice zones
  penalised, ON/OFF floors re-checked every second) and holds it. NAVIGATION (`src/ai/BotNav.lua`): a graph per level
  built with the REAL physics — nodes = standable cells, edges = walk to the next cell or a recorded MACRO (≈30 input
  sequences from each cell: jumps, double jumps at several timings, drops, walk-offs; trampolines included via their
  `interact`) → `assets/nav/<level>.json` (`run.sh bot_nav BUILD=1`, ~1 s per arena; signature of the tiles: stale →
  the game rebuilds it on entering). Levels with ON/OFF blocks are built in BOTH states and merged; at run time edges
  whose target has no floor now are skipped, an edge that fails twice is banned 15 s, and with no path it brute-forces
  toward the goal jumping. The bot runs at a FIXED 1/60 step inside (`Bot:step` accumulates the real dt): the macros
  were recorded per frame at 60 Hz, and with the game's variable dt they landed elsewhere — in the user's first test
  the bot never reached a zone while the harness (exact 1/60) passed; the harness now feeds an irregular dt and
  `story_flow` checks in the real game that the bot scores. The graph is only the MAP of possible moves: what the bot does is decided every frame
  (where you are, the level's state) plus some chance (rest between attacks × 0.8-1.6, it roams to a random cell of
  its zone every few seconds). FREE PLAY: a level with point zones and no finish starts as a match vs the bot too
  (`FreePlayState:_play`; arenas without a nav file build it on entering). Harness `bot_nav` (per arena: reaches a zone and stays; with a dummy player in the zone it
  must push it ≥ 3 times in 40 s) and `story_flow bonus`.

- **BOT 3.69.0 (user: "prioritize points; it melts down in water; it doesn't press the ON/OFF activator")** —
  PRIORITIES (`Bot:_goal`): scoring comes first. In a zone it never leaves to chase you: it attacks only if you are in
  ITS zone; outside a zone it goes to the best zone, or to throw you out of yours if you are scoring within its chase
  radius; an equal-value zone it already holds is not abandoned for the "best" one. It never ground-pounds over
  BREAKABLE floor (`breakableUnder`: it used to break its own zone floor and fall in — cantera_real, whose spike pit
  the user then turned into a pit with drop-through STAIRS; there the bot just holds the zone). ACTIVATORS
  (`_switchPlan`, `activators`, `flippedZones`): the bot evaluates the zones' floors with the switch blocks flipped
  and goes to press the activator (head bump from the node 2-3 rows below, or ground pound from on top; mode
  'press', `SWITCH_CD` 6 s) when that gives a better zone, or takes YOUR zone's floor away while leaving it one at
  least as good and it is not standing in yours (ciudadela_alterna's only mechanic). WATER: the nav graph is recorded
  with every flood at its MINIMUM level; `flooded()` = covered by a flood that is ABOVE its minimum → such nodes are
  not zone nodes nor path targets, and if the bot itself is in it → `_water`: swim to the nearest dry node and, with
  no progress for `WATER_TRY` 2.2 s (a pit you can't leave at high water), WAIT still (`kind = 'wait'`) until the
  surface drops `WATER_DROP` 24 px (or 15 s). Static water tiles are part of the graph as before.
  NAV v3 (`BotNav.VERSION`): the signature now includes every entity placement (moving a mortar/trampoline makes
  the file stale) and cells occupied by a solid object are not nodes (the bot pushed against a mortar for 5 s).
  KOTH DATA RULE, enforced by the harness (`bot_nav` `datos`): in every level with point zones stompable enemies
  respawn and give floor(40 %) of their type's points — Crabbies / Gloomies 15 → 6, Gummies 10 → 4 (several arenas
  had Gummies at 6 and Trampoline Crabbies at 5: fixed, also in `levels_batch2.py` `K` / `KG`).
  Harness `bot_nav`: floods now ADVANCE, plus `cebo` (a dummy standing OUTSIDE the zones: the bot stays in),
  `agua` (jump presses per second while in flood water), activator presses, breakable floor.

- 3.64.3 (bonus match): the lives counter is NOT drawn in a bonus (it showed "x99": internally the bonus gives the
  player 99 lives so dying is only a respawn and never a Game Over, and adventure lives are untouched); when the match
  ends the player is FROZEN — no control, invulnerable — until the screen leaves (`pa.forceFrozen`, honoured by
  `PlayerAdventure:update` like a boss intro; before, you could still move and even die under the result banner).
  Free Play bonus matches share the same code. Harness `story_flow bonus` checks the freeze.

## Results and rewards

- BONUS RESULTS: a bonus (KOTH vs bot) now ends in `story_results` — made generic: `args.rows` ({label, value fn, points, max}), `args.title`, `summary.rewards` (list) — instead of a notice on the map. `Score.bonus(stats)` (`BONUS_WEIGHTS`: duel 50 = your points / (2 × the bot's), items 15, enemies 15 = kills / 5, falls 20; LOSING caps the rating at 49 = D) → `Run.bonusResult` returns the summary: match points × difficulty (only when won), rewards = first win `Score.BONUS_WIN` (+1 life +1000) and the first win with each grade `BONUS_GRADE_REWARD` (S +1 life, A +500); save fields `bonus[id].rating/grade/wonGrade`. `AdventureState.stats.items / itemsTotal` = pickups taken / in the level.

- NO EXTRA LIFE in any level with point zones (the reward gives the lives): cripta_del_silencio's became an apple, the KOTH arenas in `levels_batch2.py` place apples, and `bot_nav` `datos` fails on an `extralife` in an arena.

- (1) BONUS RESULTS: the "enemies" row is gone (they always respawn in arenas) → "time in the zone" (`stats.zoneT`, `Score.BONUS_WEIGHTS.zone` 15 = seconds inside the active zone / half the match).

## History and decisions (dated notes)

Kept because they record WHY things are the way they are and what was tried and rejected. Where a note
conflicts with the sections above, the sections above describe the current behaviour.

- BOT, 3.64.0 (user: in cumbre_cangrejo "the bot had a stroke: the whole match jumping in one place"): (1) that
  arena had NO nav file and its only way up needs a 5-tile gap jump: new macros in `BotNav` v2 (`VERSION` 2 → every nav
  rebuilt): the 2nd jump exactly at the apex, and LONG jumps (2nd jump late) with a +400 cost `PENALTY` — last resort,
  they are tight (in isla_flotante one failed and dropped the bot off the graph). (2) Recorded moves now start from
  the EXACT cell centre (`pa.x = from.x` once within 5 px). (3) NEVER stuck: with no path for `Bot.GIVE_UP` 2.5 s
  (airborne time counts) it WANDERS to a random reachable cell for 4-7 s and tries again; chasing you keeps priority.
  (4) Harness `bot_nav` now runs ALL 11 levels with point zones (6 story bonuses + coliseo_pinchos, cascada_dorada,
  cumbre_cangrejo, marea_alta, rebote_real) and fails if the bot stays within 40 px outside a zone for 6 s.
  cumbre_cangrejo itself: renamed "Peñón del Cangrejo" / "Crab Rock" (it is a beach level: sand, crabs, coast sky),
  music costa_1, its stray snow_pile removed (file id unchanged).

- 3.64.2: (1) RULE: every level with point zones (KOTH) plays its island's BONUS track — cumbre_cangrejo, cascada_dorada,
  marea_alta, rebote_real → `costa_bonus`, coliseo_pinchos → `fortaleza_bonus` (the six story bonuses already did).
  (2) CLIMBER ON AN EDGE: a wall-walking Crabby shoved so its centre ends beyond the platform edge (another enemy, a
  hit) never re-attached — `Crawler.attach` looks for the surface under the CENTRE — and stood there forever as if it
  had nowhere to go. `Crawler.edgeRescue(e, level, dt)`: with no surface under the centre but some under its box, it
  walks toward that side until it can attach (Crabby `crawlWalk`, Gloomy). Harness `mechanics trepador_canto`.
  (3) BOT bouncing on a Crabby trampolín: airborne it gave no input and kept bouncing until the crab left; after 0.9 s
  without touching ground (`airT`) it steers toward its goal (or sideways if right under it) to get off.
