# The Groove (El Groove) — `groovecrab`

The SECRET boss, after the game: a giant Trampoline Crabby — a FIDDLER CRAB (one big claw, one small) with visor
sunglasses and the game's trampoline on its back — that FIGHTS TO THE BEAT OF ITS OWN THEME (`groove`, the track
where the slap bass is the lead: `tools/music/slap_boss.py`). It appears on the world map once the Mirror (the last
world's boss) is beaten: [world-map](../story/world-map.md#the-secret-node).
**File:** `src/world/entities/types/bosses/groovecrab.lua`. **Art (its own design):** `assets/images/bosses/groovecrab/`
(`tools/art/bosses/make_groove_crab.py`; `--gif` writes an animated mockup to `FlappyMonster_pruebas/jefes/groove/`).
**Sounds:** reused (`megaSlam`, `megaClack`, `megaWindup`, `megaHurt`, `megaRoar`, `trampoline`, `crabPop`, `gpImpact`).
**Level:** `isla_del_groove` "Isla del Groove" / "Groove Island" (`tools/levelgen/levels_boss.py`; beach at dusk);
arena `tools/levelgen/arenas/jefe_groove.json` (`make_jefe_groove.py`). **Music:** `groove`. **Shard:** none.
**Harnesses:** `groovecrab_rules`, `boss_sim` / `boss_intro` / `online_boss` / `boss_frames` with `LEVEL=` that arena
(`boss_frames HIT_AT=` = when the hook stomps it in a pose), `sp_boss LEVEL=assets/levels/isla_del_groove.json`,
`story_flow` (case `secreto`).

## The design (art)

The user asked for an original crab, "not just a reskin of the Mega Crabby", in the style of the game's crabs. It
keeps the family's rules — dark outline, a two-three tone body, the coast Crabby's own thin legs and 3-frame walk,
separate claws in 2 frames (open / closed) — and its own detail is being a fiddler crab (fiddler crabs wave the big
claw to a rhythm): turquoise shell (the coast), visor sunglasses drawn into the sprite, a grin, magenta claws, notes
in 4 colours (pink, cyan, yellow, green). Grid 18x10 at scale 10. Drawn by itself (not with the Mega Crabby's
drawLocal): trampoline (height = `tk`), body, big claw in front, small claw behind.

## The clock is the song

`songT` = time since the fight started; the zone music starts on that same frame and keeps playing through
respawns, so the boss knows the section, bar and sixteenth (`GC.where`; table `SONG`: intro 8 bars + loop A 16 ·
B 16 · SOLO 8 · BUILD 8 · CLIMAX 16 · RETURN 4 = 68 bars, 150 BPM). The difficulty's pace does not touch it
(`def.pace = false`) and the Xtra Extreme generic anger, which speeds bosses up, is off (`angryPhase()` = true; on Xtra
it starts enraged instead). **If the score changes (form, tempo, where the pops or band hits fall), change `SONG`,
`B_NOTES`, `C_NOTES` and `POSE_AT` too** (`slap_boss.py` says so in its header). Online: `songT` travels in the
snapshot; the client's music starts when it sees the fight, with the same delay as the snapshots it draws.

## Behaviour (per bar: `GC.plan`)

- **Hop** (A, the build, odd bars of the climax, the return; intro bars 5 and 7): crouches with a floor mark that
  follows the nearest player (locked at sixteenth 6), jumps on sixteenth 8 and LANDS on the next bar's downbeat (the
  kick) on the mark — a pure function of time, no physics (the arena floor is flat). Landing: two SAND WAVES, one
  each way (shared `src/world/entities/base/BossWaves.lua`; jump them, 1 HP). It needs `MIN_WARN` 0.3 s crouched to
  jump (coming out of a hit it skips that hop). Calm in A it hops on odd bars; enraged, on every bar it can.
- **Notes** (B and the even bars of the climax): raises the big claw and, on the bass POPS (`B_NOTES`: sixteenths 4
  and 8 mostly), snaps and fires a NOTE at the nearest player (straight, 330 / 390 px/s enraged; 1 HP). Between notes
  it walks towards you.
- **Pose** (the ONLY opening): on the band hits that close every phrase (bar 4 of every 4, from sixteenth 12 to
  sixteenth 4 of the next bar) and in the SOLO (odd bars, the whole bar: a band hit and silence). The trampoline
  hides, the big claw goes up: stomp 1 / ground pound 2, one hit per pose → 'hurt' (the trampoline springs out,
  nearby players shoved without damage). In the solo, the even bars are a small hop that lands on the next hit.
- **Trampoline**: outside a pose, landing on it LAUNCHES you (`'launch'`, vy = jump × 1.85, also with a ground pound;
  ~8.4 tiles up): the way to be above it when it poses. Touching its side = 1 HP and a push (not while posing).
- **Rage** under `rageAt` (0.5): hops on every possible bar, more notes. HP 10 (+4 per extra player).

**Intro** (3.6 s): falls from the sky, lands (shake), snaps its claws twice, boings on its trampoline.
**Defeat:** 'dying_daze' (stars, 2.2 s) → 'dying_flee': one huge bounce on its trampoline up into the sky (pure
function of time), out of view. No shard (`shardDrop` = false).

**Look** (all from state + deadTimer + songT): bobs on every beat, claws click; two stage SPOTLIGHTS from the top
corners of the zone onto it, changing colour on every beat (additive cones).

**Network:** netPackExtra `{songT·100, rage, markX, waves (BossWaves.pack), nNotes, {id, x, y, vx, vy, colour}…}`.
Protocol 68.

## History and decisions

- 2026-10-26: born from the music. The user loved the slap-bass mockup ("the best track in the game by far") and
  asked for a boss worthy of it, "probably secret". Proposed: (1) a rhythm boss on the beat (picked), (2) a band of 3
  Gummies whose defeat removes instruments, (3) the Mirror's echo. Unlocked after beating the game (the user: "not
  sure in which world"; decided: a sand islet NE of the volcano, a branch from the Final's bonus node).
- The first art attempt was the Mega Crabby with sunglasses: the user asked for its own design inspired by all the
  game's crabs, and notes in several colours → the fiddler crab; approved from an animated GIF mockup ("me gusta").
  Not played by the user yet.
