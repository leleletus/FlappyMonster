# Groove Crab (Cangrejo Groove; "El Groove" until 0.5.54) — `groovecrab`

The SECRET boss, after the game: a giant Trampoline Crabby — a FIDDLER CRAB (one big claw, one small) with visor
sunglasses and the game's trampoline on its back — that FIGHTS TO THE BEAT OF ITS OWN THEME (`groove`, the track
where the slap bass is the lead: `tools/music/slap_boss.py`). It appears on the world map once the Mirror (the last
world's boss) is beaten: [world-map](../story/world-map.md#the-secret-node).
**File:** `src/world/entities/types/bosses/groovecrab.lua`. **Art (its own design):** `assets/images/bosses/groovecrab/`
(`tools/art/bosses/make_groove_crab.py`; `--gif` writes an animated mockup to `FlappyMonster_pruebas/jefes/groove/`).
**Sounds:** reused (`megaSlam`, `megaClack`, `megaWindup`, `megaHurt`, `megaRoar`, `trampoline`, `crabPop`, `gpImpact`,
`bossExplode`) + the crowd's own `crowdCheer` / `crowdBoo` (`assets/sounds/bosses/groove/`, `tools/sounds/groove.py`:
many detuned saw "voices" through a vowel formant — no samples).
**Level:** `isla_del_groove` "Isla del Groove" / "Groove Island" (`tools/levelgen/levels_boss.py`; beach at night; level music `costa_groove`, the slap remix of Calipso: `tools/music/groove_island.py`);
arena `tools/levelgen/arenas/jefe_groove.json` (`make_jefe_groove.py`). **Music:** `groove`. **Shard:** none.
**Harnesses:** `groovecrab_rules`, `boss_sim` / `boss_intro` / `online_boss` / `boss_frames` with `LEVEL=` that arena
(`boss_frames HIT_AT=` = when the hook stomps it knocked out; in phase 2 the hook spins both decks), `sp_boss LEVEL=assets/levels/isla_del_groove.json`,
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
`B_NOTES`, `C_NOTES` and `GOLD_AT` / `goldAt` too** (`slap_boss.py` says so in its header). Online: `songT` travels in the
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
- **Phase 1 — GOLDEN NOTE** (the only opening while HP > `rageAt`): on the band hit closing every 8 bars of A, B, the
  build and the climax (sixteenth 12, `GOLD_AT`) and on bar 5 of the solo (sixteenth 0) it fires a golden note aimed
  ABOVE you (jump into it). Touching it sends it back; it bursts his trampoline → KNOCKED OUT (below). One at a time;
  it never hurts.
- **Phase 2 — DJ DECKS** (HP ≤ `rageAt`, 0.5): no more golden notes (live ones vanish). A DJ deck rises on each side
  platform (`GC:findDecks`: the left-most and right-most standable runs of the zone, ≥ 2 tiles above the floor and
  wide enough for a deck; same on SP and server; positions travel in the snapshot). The platforms are 5 tiles up and a
  double jump reaches ~3.1, so the ONLY way up is HIS trampoline. Stomp / ground-pound a deck → it spins for `DECK_T`
  = 10 bars (16 s; stomping again restarts it; the player bounces). He does NOT go anywhere special meanwhile: the
  player lures him (his hops follow the nearest player) to the other side. A 5-LED countdown turns red and blinks at
  the end, then the deck stops (`switchOff`). While the DANCE FLOOR is on (`GC:decksAway` = `floorOn`), the decks AND
  their platforms are gone (`GC:updatePlatforms` → `setPlatforms`: the phase-block cells go back to `hiddenAs`, 'set'
  tile changes like PhaseBlocks; an occupied cell waits) so the attack is all there is; deck countdowns pause; when
  it ends they come back and the decks rise again (`drawDecks`, render-cached return time). An arrow bobs over every stopped deck. BOTH spinning at once → the BASS DROP: the
  two speakers fire rings and a beam at him (`dropT`, drawn `DROP_FX` 0.8 s) → knocked out. Decks can't be started
  while he is knocked out or regrowing. If an arena has no such platforms (`decks = false`), phase 2 keeps the golden
  note so he can still be hurt.
- **Knocked out** ('stunned', `STUN_T` 2 bars; also the look of 'dying_daze'): stomp 1 / ground pound 2,
  up to 2 hits, then 'regrow' (a new trampoline grows from his head). Look (`ko-Sheet.png`, `glasses.png`): his
  SUNGLASSES fly off in an arc and bounce on the floor behind him (back on his face in the first 0.35 s of 'regrow';
  left on the floor when he bursts), X eyes that spin (X / + frames), tongue out, legs splayed, claws on the floor; the
  hit SQUASHES him and he springs back, then he sways side to side (offset, never rotated) under a bigger star ring.
  The generic `stunned` wobble of the render wrapper is off (`GC.ownStunLook`): it rotated his whole render — dance
  floor included — around him.
- **Trampoline**: unless knocked out, landing on it LAUNCHES you (`'launch'`, vy = jump × 1.85, also with a ground
  pound; ~8.4 tiles up): the way onto the side platforms. Touching its BODY (shell and legs) = 1 HP and a push (not
  knocked out); the CLAWS do no damage — the hitbox is only the body (`outerW` 0.78: 14 of 18 px).
- **Rage** (phase 2; on Xtra Extreme from the start, still in phase 1): hops on every possible bar, more notes.
  HP 11 (+4 per extra player; × the difficulty's `bossHp`).

**Intro** (3.6 s): falls from the sky, lands (shake), snaps its claws twice, boings on its trampoline.
**Defeat:** 'dying_daze' (`DAZE_T` 1.8 s: knocked-out look, he SWELLS and shakes harder, small `boss_blast`s on his body
closer and closer) → 'dying_burst' (`GC:burst`: `boss_big_blast`, six `enemy_burst`s around him, his trampoline in
pieces, big confetti, big shake, `bossExplode` + `enemyExplode` + `megaSlam` + the crowd's boo; releases the zone; the
body is no longer drawn, only his glasses on the floor) → after `STAGE_OUT` 2.4 s, 'dead'. Meanwhile the STAGE
RETRACTS the way it came in, backwards (`stageT` runs the entrance timeline in reverse: lasers off, the crowd ducks
under the sand one by one, the ball goes up, the speakers sink). No shard (`shardDrop` = false).

**Crowd mood** (`GC:mood`, `crowdMood`; `MOOD_T` 2 s; travels in the snapshot): it CHEERS him (`crowdCheer`; everyone
jumps on every beat, higher, waving the sticks) when a player loses HP or dies (`watchPlayers`: any HP drop of any
player in the level, whatever hit them), and BOOS (`crowdBoo`; nobody jumps, they sink a little, sticks lowered) when
he is hurt — and all through his death.

**Look** (all from state + deadTimer + songT): bobs on every beat, claws click and SWING in every state (walking
out of step, tucked in and shaking when crouched, flailing in the air, swaying knocked out, jolted when hit; offsets
in whole art pixels, never rotated: pixel art); two stage SPOTLIGHTS from the top
corners of the zone onto it, changing colour on every beat (additive cones).

**Network:** netPackExtra `{songT·100, rage, markX, stunHits, phase, dropT·100 (-1), p2T·100 (-1), waves
mood (0/1/2), mood songT·100 (-1), (BossWaves.pack), nNotes, {id, x, y, vx, vy, colour}…, nDecks, {x, y, on·10}…}`.
Protocol 71.

## History and decisions

- 2026-10-26: born from the music. The user loved the slap-bass mockup ("the best track in the game by far") and
  asked for a boss worthy of it, "probably secret". Proposed: (1) a rhythm boss on the beat (picked), (2) a band of 3
  Gummies whose defeat removes instruments, (3) the Mirror's echo. Unlocked after beating the game (the user: "not
  sure in which world"; decided: a sand islet NE of the volcano, a branch from the Final's bonus node).
- The first art attempt was the Mega Crabby with sunglasses: the user asked for its own design inspired by all the
  game's crabs, and notes in several colours → the fiddler crab; approved from an animated GIF mockup ("me gusta").
  Not played by the user yet.
- 0.5.46, the user's first round (6 points): (1) the music louder — here it matters → `groove` mastered at −9.5 LUFS
  and its own target in `levels.py` (3.5 dB over the other bosses); (2) the claws must not hurt ("unfair, no Mega
  works like that") — body contact stays, the hitbox is now only shell + legs; (4) the claws were stiff → they swing
  in every state like the other Megas (a first try rotated them: rejected by the pixel-art rule, offsets only).
  Pending, with GIF drafts to choose from (`FlappyMonster_pruebas/jefes/groove/borradores/`): (3) more attacks on
  the beat, (5) a clearer, longer way to damage it (the pose was "unpredictable, short and hard to understand"),
  (6) more epicness: a crowd of crabs dancing to the music, more energy and visuals.
- 0.5.47, the user's picks from the drafts: (5) GOLDEN NOTE — on the band hit closing each phrase (and the solo's bars
  1 and 5) it fires a golden note aimed above you; touching it sends it back, it bursts the trampoline (`groove_tramp`
  particles, confetti) → 'stunned' 2 bars (stomp 1 / GP 2, up to 2 hits) → 'regrow' (a new trampoline grows from its
  head). The old pose is gone. (3) DANCE FLOOR (build + climax 9-16: panels warn on a beat, light column on the next,
  1 HP; side platforms safe) and CONGA (solo; enraged also climax 9-16: 4 crowd crabs hop one tile per beat, touch 1 HP,
  stomp removes them). (6) Stage = night rave + beach concert (level `time` night): crowd of crabs and Gummies in
  silhouette with glow sticks (no outline: background), speakers, equalizer, disco ball + lasers, phrase flash —
  drawn by the new generic hook `Entities.renderBack` (behind the tiles); it APPEARS during the intro. Floor panels
  only light for the attack. Conga crabs get their species' `darkEdge` at night; the monster its white outline.
  Drawing moved to the part `groovecrab_stage.lua`. Protocol 69. `sp_boss` gained `FIGHT_SHOTS=` and `GOD=1`.
- 0.5.48, the user's second round (6 points): (1) the CONGA is gone (code, net, test); (2) fewer golden notes — every
  8 bars instead of 4, and only bar 5 of the solo (half as many per loop); (3) HP 10 → 13; (4) the knockout did not
  read as "very dazed" → own KO sprite (glasses fly off, X eyes, tongue, splayed legs), squash on the hit, sway, bigger
  stars; (5) "the coloured floor lights shake with him when he is stunned": the user's theory was right — the
  `EntityTypes` render wrapper rotates the whole render of a 'stunned' entity, and his render draws the dance floor →
  new trait `ownStunLook`; (6) a new way to hurt him in phase 2 using the two platforms and his trampoline: proposed
  DJ decks (picked) / a falling lighting truss (two levers) / overloaded speakers stomped on the beat. Not played by
  the user yet: the 8 s deck window and the deck size are guesses to tune by feel.
- 0.5.51, the user: (1) the screen shakes on every hit he takes (`onDamaged` → `shake_big`); (2) note PATTERNS and
  visibility: the B / climax notes change pattern every 2 bars (`GC.noteKind`: `aim` straight at you, `fan` three in a
  fan — not when enraged, it would rain —, `wave` straight but weaving ±46 px, `lob` an arc that falls where you stand
  after 1.05 s and bursts on the floor); drawn at ×5 with a glow of their colour and a trail, and a ring closes on the
  claw tip in the 0.22 s before each shot (`drawCue`, from the song clock and the plan: same online); (3) the DANCE
  FLOOR was hard to read and dodge: one pattern per BAR (was two), a 3-beat warning (`FLOOR_WARN` 12 sixteenths =
  1.2 s, was 0.4 s) showing the GHOST of each column (outline, fill growing stronger, a rising "!" arrow), all warned
  tiles in danger pink, then a brighter 3-sixteenth column; (4) more MOBILE and varied: between attacks he dance-walks
  across the stage a half tile per beat (`danceWalk`: the side changes every 2 bars, facing you — a moonwalk when
  moving away —, never towards a player closer than 2.6 tiles), and his idle dance changes every 2 bars (bob · claws
  up in turns · half-turn on every beat, flipping, never rotated · deep squat with a shimmy); all drawing from the song
  clock (same online). Harness cases `dibujos`, `baile`, `temblor`; `boss_frames FROM=s`. Not played by the user yet.
- 0.5.52, the user: (1) the WEAVING notes confused ("they sway up and down") — removed; the patterns are now aim, fan,
  lob (every 2 bars; enraged, aim instead of fan); (2) the dance floor had become all pink (the danger tint) and lost
  its colours: each tile keeps ITS colour in the blink, the ghost outline and the column (the rising arrow stays);
  (3) the golden note looked like a yellow normal note: no normal note is yellow any more (the third colour of
  `note-Sheet.png` is purple) and the golden one is drawn at ×7 with turning rays, a pulsing white ring and a bigger
  halo; (4) the two side platforms only exist in PHASE 2: phase blocks (`phaseblock`, phase 2, like the Snowball's
  switches) in the arena (`make_jefe_groove.py`) and in `isla_del_groove.json` (added by hand: `build.py --only
  isla_del_groove` regenerated the level WITHOUT its later retheme and decorations — not used). `findDecks` counts
  the hidden cells, so the decks are known from the start and rise with their platforms.
- 0.5.53, the user: (1) the decks were too far apart and, if he stood still in an attack away from the second one,
  activating both was impossible: a deck now spins `DECK_T` 8 bars (12.8 s, was 8 s) and, with exactly ONE deck
  spinning, he goes to stand under the OTHER (`GC:deckGoal`: walking at 1.8 × `WALK_SPD`, also while snapping notes,
  and his hops aim there), so his trampoline is where you need it; (2) the decks were black on the night stage and
  only the arrows told what to do: `deck-Sheet.png` is now a LIGHT box with a dark outline, a silver-rimmed black
  record and a dark LED strip, and a stopped deck pulses a warm glow (`drawDecks`; the halos are no longer clipped to
  the deck's box).
- 0.5.54, the user: the name is now **Groove Crab** / **Cangrejo Groove** (keys `boss.groovecrab` in es/en and the
  title in the type; the id stays `groovecrab`), and the level got its own track: `costa_groove`, a funk remix of
  `costa_1` with the slap bass leading (`tools/music/groove_island.py`; docs/audio/music-catalog.md). Not listened to.
- 0.5.55, the user: (1) the crowd's crabs that HAVE claws in the game (river — the meadow one —, icy, lava: the `claw`
  of their skin in `types/enemies/crabby.lua`) had none: they now wear them in silhouette, a shade lighter than the
  body, and hold their glow stick in one RAISED claw that bobs on the beat (the others keep it against the body);
  (2) a fuller crowd: two rows (`GC:drawCrowd`) — a back row of 34, smaller (×3), darker and higher, and a front row
  of 30 (was 22); (3) "the hardest boss in the game, but it goes a bit too far": HP 13 → 11, notes 330 / 390 →
  300 / 345 px/s, sand waves 470 → 420 px/s, enraged he adds ONE hop every 4 bars of A (was every bar) and the
  third note every 4 bars of B (was every other bar). Not played by the user yet.
- 0.5.56, the user: (1) during the dance-floor attack the decks AND their platforms go away (focus on the attack) and
  come back after it; (2) "going to stand under the other deck was forced and weird": `deckGoal` removed — he behaves
  as always and the player lures him; decks spin a bit longer (`DECK_T` 8 → 10 bars); (3) the defeat was a bounce up
  into the sky → now he EXPLODES wildly, like the crabs on spikes or lava (`dying_burst`); (4) the stage and crowd
  vanished at once on his death → they retract the way they came in, with the crowd booing; (5) the crowd cheers him
  when a player is hurt or dies and boos when he is hurt or dies (new sounds, NOT listened to). Same release: a
  ceiling Crabby (any skin) dropping onto spikes stayed there stuck → `Entity:droppedOnSpikes` (it bursts). Not
  played by the user yet: deck length, crowd sounds and burst feel are to judge.
- 0.5.64, the user: the DJ decks could be spammed — no cooldown after knocking him out → after a bass drop the decks
  cannot be started for `DECK_COOL` = 12 bars (19.2 s, longer than the knockout): they go grey and their LEDs refill as
  the cooldown runs out (`GC:deckCool`, from `dropT` and the song clock: the same online). His level and the Mega
  Mashup. Harness `groovecrab_rules` (`enfriar`). Not played by the user yet.
- 0.5.65, the user (his level and the Mega Mashup): (1) a deck switched on, then hidden by the dance-floor attack, came
  back still spinning → while the decks are away they switch OFF (they return off); (2) "too easy" → a deck spins
  `DECK_T` 6 bars (9.6 s; was 10 bars, 16 s). Harness `groovecrab_rules` (`ocultos`, `platos`). Not played yet.
