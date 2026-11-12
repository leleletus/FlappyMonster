# Groove Crab (Cangrejo Groove; "El Groove" until 0.5.54) — `groovecrab`

The SECRET boss, after the game: a giant Trampoline Crabby — a FIDDLER CRAB (one big claw, one small) with visor
sunglasses and the game's trampoline on its back — that FIGHTS TO THE BEAT OF ITS OWN THEME (`groove`, the track
where the slap bass is the lead: `tools/music/groove_mejora.py`, built on `tools/music/slap_boss.py`). Its island opens on the world map after the Mirror is beaten AND
every splinter is owned, through the theft scene (its disco ball takes the splinters out of the crown and the amulet):
[world-map](../story/world-map.md#the-secret-nodes), [story](../story/story.md#the-secrets-the-splinters-the-groove-and-the-true-ending).
It is the only one the mirror's light does not shrink: its ball bounces the wave. Beating it drops nothing; it opens the
Mega Mashup.
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
  and 8 mostly), snaps and fires a NOTE at the nearest player (straight, 255 / 295 px/s enraged; box ±12 px; fan gap
  0.42 rad; lob 1.2 s; claw cue 0.32 s before — all eased in 0.5.149; 1 HP). Between notes
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
  while he is knocked out or regrowing. During the COOLDOWN after a drop (`DECK_COOL`), once the drop's flash is over,
  the decks and their platforms EXPLODE and are gone (`GC:decksBlown` → `decksAway`; `chunk_break` debris of their
  tile, a `boss_blast` per deck, `bossExplode` + `blockBreak`) and rise again when it ends (0.5.149). If an arena has no such platforms (`decks = false`), phase 2 keeps the golden
  note so he can still be hurt.
- **Knocking him out STOPS what he was doing** (0.5.149): notes in flight burst, sand waves go, a buck ends, and the
  dance floor stays off while 'stunned' / 'regrow' and in the bar he wakes up in (`backT`, in the netPack: a column
  could otherwise fire with less than its 3-beat warning).
- **Knocked out** ('stunned', `STUN_T` 2 bars; also the look of 'dying_daze'): stomp 1 / ground pound 2,
  ONE hit (2 until 2026-10-31), then 'regrow' (a new trampoline grows from his head). Look (`ko-Sheet.png`, `glasses.png`): his
  SUNGLASSES fly off in an arc and bounce on the floor behind him (back on his face in the first 0.35 s of 'regrow';
  left on the floor when he bursts), X eyes that spin (X / + frames), tongue out, legs splayed, claws on the floor; the
  hit SQUASHES him and he springs back, then he sways side to side (offset, never rotated) under a bigger star ring.
  The generic `stunned` wobble of the render wrapper is off (`GC.ownStunLook`): it rotated his whole render — dance
  floor included — around him.
- **Trampoline**: unless knocked out, landing on it LAUNCHES you (`'launch'`, also with a ground pound) to a FIXED
  height — the player's centre `LAUNCH_APEX` 571 px above the floor, the same as the old jump × 1.85 from him on the
  floor, but also when he is mid-hop — and with NO air jump left (`GC:launchVy`; since 0.5.149): the way onto the side
  platforms.
- **Ceiling spikes and the BUCK** (0.5.149): row 3 of the zone — its invisible lid — is lined with down spikes (empty
  cells with the two top sub-spikes: raw 1440) in his arena, `isla_del_groove` and both Groove zones of the Mashup. A
  launch alone tops out ~37 px under them. A player who bounces on him `CAMP_N` 2 times in a row without touching the
  ground (`onLaunch` counts, `watchCampers` resets on ground) makes him BUCK: state `buck`, `BUCK_WIND` 0.45 s crouched
  with the trampoline blinking red, then a `BUCK_H` 1.6-tile hop of `BUCK_DUR` 0.9 s; while bucking his trampoline
  launches at jump × `BUCK_LAUNCH` 2.75 → into the spikes. Not mid-hop, crouched, in a duel or frozen by the event. Touching its BODY (shell and legs) = 1 HP and a push (not
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
mood (0/1/2), mood songT·100 (-1), duel bar (-1), duel bars, backT·100 (-1), (BossWaves.pack), nNotes, {id, x, y, vx, vy, colour}…, nDecks, {x, y, on·10}…}`.
Protocol 107.

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
  particles, confetti) → 'stunned' 2 bars (stomp 1 / GP 2, one hit) → 'regrow' (a new trampoline grows from its
  head). The old pose is gone. (3) DANCE FLOOR (build + climax 9-16: panels warn on a beat, light column on the next,
  1 HP; side platforms safe) and CONGA (solo; enraged also climax 9-16: 4 crowd crabs hop one tile per beat, touch 1 HP,
  stomp removes them). (6) Stage = night rave + beach concert (level `time` night): crowd of crabs and Gummies in
  silhouette with glow sticks (no outline: background), speakers, equalizer, disco ball + lasers, phrase flash —
  drawn by the new generic hook `Entities.renderBack` (behind the tiles); it APPEARS during the intro. Floor panels
  only light for the attack. Conga crabs and the monster get the [contrast edge](../art/contrast-edge.md); the stage, decks, spotlights and flashes go through `Edge.direct` (no edge).
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

- 0.5.149, the user (his level and the Mega Mashup): (1) a new dance for the duel → he SINGS the chart's arrows,
  FNF style, own sprite `sing-Sheet.png`; (2) a livelier background → two dim FNF lanes on the stage (`drawChartBack`:
  the real `easy` and `normal` charts of the song rising to their strums, which light up; not during the duel) and
  notes floating out of the speakers on every beat; (3) the decks on cooldown looked like a mistake → their platforms
  explode and hide until it ends; (4) "many players just keep bouncing on his trampoline" → spikes along the zone's
  ceiling and the BUCK; to keep the spikes fair, the launch now goes to a fixed height and spends the air jump (a
  launch + double jump already hit the zone's invisible lid; lowering the launch instead broke the climb to the
  platforms — case `trepar`); (5) balance: a won duel hurts him directly, once per player; knocking him out stops the
  current attack (the dance floor above all); notes slower and easier to dodge. In the Mashup all of it applies to
  his arena turn and the final, except the duel parts: the event has no duel. Not played by the user yet: the buck's
  timing, the 37 px margin under the spikes, the no-air-jump launch and the background lanes are to judge.

- 0.5.150, the user ("bastante chad"), three more points: (1) the two background lanes → something else showing exactly
  the same; picked from four proposals (fireworks, neon tubes, rig spotlights, a giant dance pad): FIREWORKS — every
  chart note (easy chart on the left half, normal on the right) climbs as a rocket from behind the crowd in its
  arrow's colour and column and bursts exactly on its time (`drawFireworks`, `firework-Sheet.png`); (2) the monster's
  own duel sprites: dance idle, one pose per arrow and one miss pose per arrow (picked over a single miss pose);
  (3) the duel laid out as their sketch: dimmed world, the two dancers at the sides at mid height; online every
  player is shown (picked over "only you"), and the arena copies are hidden (picked over "dimmed in the arena").
  Not played by the user yet: the poses' look, the fireworks' density, the layout on phones and the Switch.

- 0.5.151, the user: (1) less squash & stretch on the crab's singing poses (halved); (2) squash & stretch on the
  monster too (`drawCast`: up stretches, down squashes, the sides widen, a miss shrinks a little, ~0.22 s; a small
  bounce on every beat while idle); (3) the idle's 2nd frame had its head apart from the body (the head moved down
  without its antenna tips: a gap row) → the whole head moves down; the arm of the up pose (and its miss) is shorter.

## The rhythm duel (the user's idea, 2026-11-01)

Friday Night Funkin' style. The player stands still, invulnerable; the crab keeps dancing, can't be hit and does no harm; the song's exact notes rise to 4 grey strums and must be pressed on time.

**On screen** (0.5.150, the user's sketch): the world DIMS (`RhythmDuel.drawDim`, under the HUD; it stays alive behind, and nothing can hurt anyone), and on top: the arrows a little left of centre, the meter to their right, and at mid height, each under its own spotlight on a small floor, the MONSTER on the left and the CRAB on the right (`GC:drawDuelCast`: his body only, scaled ×0.8, facing the centre), both dancing. Their copies in the arena are not drawn while it lasts (`RhythmDuel.hides`: in the duel's zone, frozen by it). The monster (`assets/anim/player.json` `duel_*`, `tools/art/player/make_duel_poses.py`): the pose of each arrow he hits for 0.34 s, the violet MISS pose of each one that gets past for 0.45 s, and between notes a two-frame dance on the beat. Online EVERY player in the duel dances there, in a row, smaller (scale 9 / 7 / 5 / 4 by count), in their room colour, yours marked with a yellow arrow: each hit / miss is sent as `rhythm_pose` and the server relays it to the rest of the room (`R.remotePose`); drawing only. Also in the test level.

**His duel dance** (0.5.149, the user asked for a new dance for this section): like FNF's opponent he SINGS every arrow of the chart of that difficulty with its pose, for `SING_HOLD` 0.32 s — left / right: he faces that side and leans out with the big claw thrust; down: a squat; up: stretched with both claws up and the spring long — with his own sprite, `sing-Sheet.png` (mouth wide open with the tongue, then half open with the glasses' glint moved). `GC:singNow` / `chartAround` (stage part), from the song clock: same online.

**Files:** `src/ui/RhythmDuel.lua` (the game, drawing, input) · `GC.DUEL`, `GC:planDuel`, `GC:finishDuel` in the boss · `assets/charts/groove.json` from `tools/music/groove_chart.py`, generated from the installed score, so **if the score changes, regenerate it** · sprites in `assets/images/ui/rhythm/` from `tools/art/ui/make_rhythm.py`.

**When:** at the start of section D always; enraged, also one random phrase (A, B or C) per song loop. **Randomly 8 or 16 bars** (the user). One bar of warning before it, already frozen. Not while knocked out, not in the Mashup.

| Difficulty | Chart | Notes/s | Window | On screen | Meter empties below | Hit from | Can kill |
|---|---|---|---|---|---|---|---|
| Easy | `easy`: pops and strong beats, 400 ms apart; hook in D | 1.9 | ±160 ms | 1.6 s | 50 % | 70 % | no |
| Normal | `normal`: 200 ms apart; hook in D | 4.5 | ±130 ms | 1.3 s | 60 % | 80 % | no |
| Hard | `full`: the slap bass without ghost notes, and the hook in D | 5.7 | ±110 ms | 1.1 s | 65 % | 85 % | yes |
| Extreme | `full` | 5.7 | ±85 ms | 0.85 s | 70 % | 90 % | yes |
| Xtra Extreme | `full` | 5.7 | ±65 ms | 0.65 s | 75 % | 92 % | yes |

**The chart** (`tools/music/groove_chart.py`) was hand-authored per distinct bar by an agent with no earlier context, from the score: repeated phrases keep their arrows and pops mostly land on outer lanes. Its first Hard chart forced alternating hands, and only 76 % of arrows moved with the pitch (Normal 97 %); the user: on Hard "it has nothing to do with what the bass plays", and uncomfortable. Hard now follows the pitch with the same method as Normal (`contour`). On Normal and Easy, bar 16 of D is empty, as the hook rests. Review MIDIs: `FlappyMonster_pruebas/groove_duelo/chart_*.mid`. Checked note by note against `tools/music/mid/groove.mid` when generated. History: the first version of this chart played the bass in D on Hard and up, 10 notes per second; the user: "it doesn't follow the slap or the other instrument, it seems to chart every instrument". Now the hook there. The user also reported notes out of sync depending on speed; arrival time does not depend on scroll, so a constant audio delay looks worse at higher speed: pending their next test.

**Ghost notes are out of the chart.** The user first asked for 1:1, then played it: "2 or 3 notes where only one should go". They are in the MIDI at velocity 48, but barely sound. **Hit feedback:** the strum jumps, a splash plays (`splash-Sheet.png`) and a click sounds on each hit (`scorpionClick`). The click began as an autoplay test the user asked for, to hear the chart against the song; after hearing it, the user's verdict on the chart without ghosts was "very good", and they kept the click as a mechanic and removed the autoplay.

**Result:** a meter starts at 50 %; hits and misses are scaled so "empties below" is the break-even accuracy, whatever the note count. Empty: the duel ends, −1 HP (at most 1 per duel). From "Hit from": he loses 1 HP right away, ONE PER PLAYER who did it (two players → −2; `GC:duelHit`, kind `duel`: no knockout, not counted as a stunned hit). Until 0.5.148 it knocked him out for one free hit, lost if you were far from him. In between: nothing. Pressing with no note costs nothing.

**Sync:** judged against the music's real position (`Sound.musicPosition`), falling back to `songT`. Settings has a rhythm delay (±300 ms) for audio latency.

**Single player, server, client:** the freeze comes from the song clock through `freezesPlayers` (`BossZones.frozenAt`): same in all three. **The judging is the exception to the rule that the server decides:** each client plays against its own music and sends `rhythm_result` (a modified client could fake it, accepted). Each player's good result is one hit. No result: nothing happens.

**Measured with simulated players** (`rhythm_duel`, % fail / % KO over 40 duels of 8 bars; each player has a timing error and misses some notes):

| | 30 ms | 50 ms | 70 ms | 100 ms | 140 ms |
|---|---|---|---|---|---|
| Easy | 0 / 100 | 0 / 100 | 0 / 100 | 0 / 75 | 2 / 2 |
| Normal | 0 / 100 | 0 / 100 | 0 / 90 | 0 / 5 | 10 / 0 |
| Hard | 0 / 100 | 0 / 100 | 0 / 37 | 0 / 0 | 27 / 0 |
| Extreme | 0 / 100 | 0 / 42 | 0 / 0 | 0 / 0 | 82 / 0 |
| Xtra | 0 / 77 | 0 / 0 | 15 / 0 | 95 / 0 | 100 / 0 |

**The song as MIDI:** `tools/music/mid/groove.mid` (slap bass and hook tracks, 92 bars with the intro), from `MIDI=1 tools/music/groove_mejora.py`; the installed song wrote none before 2026-11-01 because its scripts had no such step.

**Test level:** `assets/levels/prueba_duelo_ritmo.json`, in Free Play (search "duelo"; choose the difficulty there), prop `duelOnly`: one duel of the whole song from the first bar, the meter cannot empty, and the crab dies at the end. For the user to test the system; not in the story. Being in `assets/levels/` it also shows in the online lobby. **Remove it from the catalog when done** (`LevelCatalog.RETIRED`: updates cannot delete installed files).

**If anything goes wrong:** each duel writes `rhythm_duel.log` in the save folder (start, end, notes, clock, music). A player dead or respawning when it starts joins as soon as alive. A duel with no notes ends at once, with no penalty. History: the first version, 0.5.136, left the user frozen with strums and no notes; not reproduced in single player (test arena and real level), a natural fight or online; the hole found was deciding "is playing" only on the first frame. Tests need `sp_boss GROOVE_BAR=n` or `FM_TEST_GROOVE_BAR=n` with `online_boss DUELDBG=1`.

Simulated players do not get tired or lost at 10 notes per second, so real results will be worse. **Pending the user:** feel, whether the chart is readable, the lanes, real devices. The existing attacks were measured against the new song: 61 of 62 shots on a pop; bar 16 of D fixed.

## The song's section D (2026-11-01)

The improved theme adds D, 16 disco bars after the climax (loop 84 bars): he hops on odd bars, throws notes on even bars with the pops (steps 6, 14; enraged also 2), golden note on bars 8 and 16, dance floor from bar 9. Timings not played yet.
