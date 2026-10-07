# Snowball Boss (Gran Bola de Nieve) and Verity — `snowboss`

The mid-island boss of the Summits: a giant snowball that can never be hurt directly — only while dizzy, soaked or
frozen — and SHRINKS over three phases. Its physics (`Snow.move / physics / jumpTo / strike…`) are reused by the
Gummy King. 2 % of the fights it is **Verity**, a yellow smiley with its own music (an Easter egg).
**File:** `src/world/entities/types/bosses/snowboss.lua`. **Art:** `assets/images/bosses/snowboss/` (+ `verity/`, the
user's). **Sounds:** `tools/sounds/snowboss.py`. **Level:** `lago_helado`; arena
`tools/levelgen/arenas/jefe_nieve.json` (`make_jefe_nieve.py`). **Music:** `snowball_boss` / `snowball_verity`.
**Harnesses:** `snowboss_rules`, `snowboss_look` (`VERITY=1`), `boss_sim LEVEL=…jefe_nieve.json`,
`online_boss LEVEL=tools/tests/online_boss/nieve_fases.json`.

## Behaviour

- **Snowball Boss** (`types/bosses/snowboss.lua`, "Gran Bola de Nieve", `boss.snowboss`; REBUILT from zero in 3.22.0
  — the old gate/bombs/burial/avalanche version was "overcomplicated"; sprites `assets/images/bosses/snowboss/`
  from `tools/art/bosses/make_snowboss_sprites.py` (the user's ball drawing restyled; that original lives ONLY outside the repo, `<originals>/assets/images/snowball/ball-orig.png`);
  sounds `bosses/snowboss/` from `tools/sounds/snowboss.py`; music `winter_nes`). renderFront. NEVER hurt
  directly: only VULNERABLE states take stomp 1 / GP 2 (one hit per opening, then 'recover'):
  'dizzy' (rolling into a wall/step at ≥ `CRASH_SPD` after ≥ `CRASH_RUN` tiles since the last crash, on its
  LAST crash: bounces per phase `BOUNCES` {0,1,2}; or a falling CEILING ICICLE hits it = `bonk`), 'soaked'
  (falls into water through broken thin ice: it is HEAVY — `LAND_CRACK` 4, any landing on thin ice breaks it,
  rolling wears it `ROLL_WEAR`, and when one cell under it breaks its whole footprint goes, so it reliably falls
  in; entering the water opens the hole to its width; `soakTime` s drenched + dripping, then a big heavy jump
  out (`ESCAPE_WIND`, `ESCAPE_UP`) to the nearest DRY spot — dry = no thin ice/water below AND no water above:
  the pool bottom used to count as dry and it "escaped" back into the pool forever; the thin ice does NOT
  regrow while it is in the water / escaping; once IT fell in (`fellIn`), the moment it is OUT of the water every broken
  cell comes back AT ONCE (the user: re-dropping it into the same hole was an exploit), except cells under it while it
  jumps out (they return as soon as it clears them or lands — never closes its exit, never lands on fresh ice); other
  breaks keep the `lakeRegrow` timer; only on ENTERING water: `wasWet`) and 'frozen' (IN THE WATER — soaked, or winding
  up / jumping out while still in it — + a Freezer stream: `FROZEN_T` 4.5 s, GP 3, then thaw; a Freezer on a DRY
  boss = short daze `DAZE_T`; the user found "stunned + water + beam" too hard). After any Freezer it is FROST-PROOF
  `frostProof` s (blue tint; `frostT` in netPack). Water itself never freezes it (user's rule).
  THREE PHASES THAT SHRINK IT (`SC` = {10, 8, 6}; 'phase_up' roars, sheds snow `snow_shed` and shrinks;
  `bossPhase()` → zone phase, see Phase system): cycles `CYCLE` — 1: shoot, roll, hop (low: never reaches the
  platforms), roll · 2: LEAP (ballistic jump to the `spots` surface nearest the target — platforms included;
  during the jump `passY` = the mark: it passes through every platform/block on the way and only lands on a
  top at the mark's height or lower, so it always reaches the marked spot; marker `landX/landY` during 'leap_wind'),
  shoot, leap, roll · 3: SLAM (rises `SLAM_H`, reaches the target's vertical at the apex, falls; cracks thin
  ice 4 = breaks a pocket → soaked; snow waves only on the arena floor), roll (2 bounces), leap, slam, shoot(5),
  leap. PACE per phase (normal / middle / aggressive; user: much more agile, the old phase-3 pace is now the
  middle one): `IDLE_T` {0.5, 0.4, 0.22}, `REST_T`, `STREAK` {2, 2, 3} attacks per streak, `SHOTS` {4, 6, 8}
  balls per volley, `WINDUP_T`, `SHOOT_WIND/GAP`, `LEAP_WIND/LAND`, `LAND_T`, `RECOVER_T`, `SLAM_HOLD/LAND`,
  `ROLL_SPD` all per phase (render uses the phase from netPack). Snowballs PASS THROUGH platforms (one-way
  tiles): only solid tiles (floor, ledges, walls) or leaving the zone stop them. It does NOT laugh at player
  deaths (only in its intro; laughing at deaths is the Mirror's thing). Every landing (`landed`) cracks thin ice, crushes players
  under it and SHAKES the ceiling icicles within `ICE_R` 2.5 tiles: prop `icicles` (points; they hang from the
  TOP of their cell; appear growing in phase 2 and ONLY exist in phase 2: reaching phase 3 shatters them
  (`meltIcicles`; a falling one finishes its fall) and they never regrow; ready → shake 0.6 s → fall → `icicleRegrow` s → grow). Icicles
  over a platform land on it (platforms are shelter). LAKE: thin ice cells of the zone regrow `lakeRegrow` s
  after breaking (`regrowLake`, never into an occupied cell); all at death. Hits on players by the boss itself
  (`hitWithShots`, `strike(pa, hit, dir)` = {HP, vx, vy, ctrlLock, stun}): ball 1 HP + strong push, icicle
  2 HP, snow wave 1 HP + push, `slamWave` 1 HP + VERY strong push + stun within `SLAM_R`; rolling/landing
  contact 1 HP + knockback/squash. Rolling into an ON/OFF Activator toggles it. Roll end is deterministic
  (time budget `ROLL_MAX_T` per phase, then 'slide'; `MAX_CRASHES`). Intro (generic `introLength` 4.4: a small
  ball bounces in, grows, lands, laughs, spits at the camera → screen splat). Death: dying_crack → dying_burst
  → dying_flee (releasesZone). netPackExtra: phase, scale, shock wave, dir, frozenFor, frostT, dizzyFor,
  landX/Y, balls {id,x,y}, icicles {state,y,t} by INDEX (same list on both sides: `icicleList`). Protocol v38.
  ARENA "Pista de hielo" (jefe_nieve.json from `tools/levelgen/arenas/make_jefe_nieve.py`; `--lago` writes it
  into lago_helado from column 72, widening the level to 113): zone 24×10, ice floor, two thin-ice POCKETS over
  water out in the open, steps at both walls, one-way platforms (sides row 10, middle row 8, top row 6), five
  icicles over the platforms, and in PHASE 3 ONLY: two floor Activadores (phase blocks hidden as ice) and two
  Freezers (`phase` 3) that drop from the ceiling above the pockets, each pocket's Activador fires its
  Freezer (ids 11/12). Harnesses: `snowboss_rules` (every rule, real arena cases), `boss_sim LEVEL=
  tools/levelgen/arenas/jefe_nieve.json` (plays it as intended: bait under icicles, slam onto a pocket,
  freeze it soaked), `online_boss LEVEL=tools/tests/online_boss/nieve_fases.json` (3 HP: the client sees
  scales 10/8/6, zone phase 3, icicles, Activadores and Freezers only in phase 3), `snowboss_look`
  (`snow_arena.png` per phase), `boss_intro`.

- **Snowball Boss, 3.70.0 (user's report: water exploit + final phase)**: hp 14 (13 was tried in 3.70.0 and reverted in
  3.71.0: a frozen ground pound = 3, so phase 3 died in one hit; phase 2 at ≤ 9, phase 3 at ≤ 4 → two freeze cycles). (1) WATER IS NOT A SAFE SPOT: when the ball falls into a pool (`checkSoak`) everyone
  swimming in THAT pool (`Snow:poolSpan`) takes `HIT_SPLASH` (1 HP, thrown up and out) before the crush check, and a
  target that is swimming never gets a hop / leap / slam — `nextAttack` turns it into 'shoot' (the exploit: wait in
  the water, the ball jumps in harmlessly, is soaked = hittable, repeat). (2) PHASE 3 = ONLY FROZEN is vulnerable
  (`isVulnerable`): soaked is not, and wall crashes no longer daze it (`crash` → 'recover'); the freezing mechanic is
  the only way. (3) Freezing needs no aim in phase 3: the Freezer's stream reports where it touches water (cryo.lua,
  every 24 px of the stream → `e:onChilledWater(level, x, y, t)` on any entity that has it, a generic hook) and the
  ball freezes if it is in that pool. Phases 1-2 keep the old rule (stream on the body). Map: mid-island bosses
  stand beside their node until beaten (`overworld.json worlds[i].nodeBoss[levelId]` = art, `tools/art/story/make_overworld.py`
  `NODE_BOSS`; `StoryMapState:_drawNodes`). Harness `snowboss_rules` agua_trampa / fase3_hielo.

## Verity

- **VERITY, the Snowball's Easter egg (3.71.0)**: `Snow.VERITY_CHANCE` 2 % of the fights (rolled in `onIntroStart`, SP /
  server; `self.verity` = LAST field of netPackExtra; `FM_VERITY=1 love .` forces it, `0` forbids) the ball is the
  yellow smiley: `Snow:art()` → `bosses/snowboss/verity/` (the USER's roll_happy / roll_angry / flee / ball +
  `body-Sheet.png` = their palette applied to the normal body by `tools/art/bosses/make_verity_body.py --apply`, colour map
  measured from their sheets; re-run it if they edit the palette). Cracks, sweat, icicles, snow particles are shared.
  It brings ITS MUSIC: generic hook `Boss:musicOverride()` read by `BossZones.music` (before the zone's track) →
  catalog `snowball_verity` (`tools/music/verity_boss.py`, intro + loop; verified by numbers only): a NEW composition
  from the ideas of La Gran Bola (three repeated notes + a leap, octave leap, 16th rolling bass, rolling toms, sleigh
  bells) and "It's me, It's Verity" by Horror Skunx (C harmonic minor, 126; refs local only in `tools/music/ref/
  verity.mid|wav`): the lower-neighbour on the leading tone, the 5–♭6–5 trill, the rocking 0·6·8·14 rhythm, descending
  pairs, oom-pah bass + offbeat chords, four-on-the-floor, i–i–♭VI–V with a MAJOR dominant. F minor + E natural, 150
  BPM; intro 4 · A · A' · B (rolling bass) · C (chorus + the Ball's riff as 2nd voice) · K (music box alone, Neapolitan
  G♭) · A'' (+ music-box descant) · C' · coda = 60-bar loop (96 s). `copied()` asserts no bar equals a bar of either
  source (rhythm + intervals). Harness `snowboss_rules verity`, `snowboss_look VERITY=1`.
  3.71.1 (user: "the electric piano line is THE recognizable motif; it has to be heard as a reference"): Verity's e-piano
  HOOK (its bars 1-4, over i–i–♭VI–V) is now quoted literally in F minor (`HOOK`): music box alone in the intro and
  opening both choruses (loop file 0:38 and 1:17), the Ball's riff answering below in its gaps. Reinterpreting it only
  was not recognizable — when the user names a motif as the reference, quote it.
  3.71.2: (a) the sample has TWO halves (user) — the chorus is now the whole thing, 8 bars: the hook + the e-piano's
  answering phrase (`HOOK2`, its bars 10-13: three-8th pickup, long note with its neighbour, fall to the tonic; i–♭VI–V–i).
  (b) INTRO → LOOP: the intro ended with the music box alone and the coda with the band, and the coda's tail was folded
  onto the loop start, so the loop began with BOTH tails and the intro "didn't cut clean". Now ONE turnaround bar
  (`TURN`, full band on the dominant) closes both the intro (3 music-box bars + it) and the coda, and nothing is folded:
  the tail at the loop start is the same wherever you come from (measured: same level, band spectra within 1.4 dB).
  RULE for intro + loop tracks whose intro ends differently from the loop's end: give both the same last bar and skip
  `GN.fold`. The generator prints the turnaround comparison and every section's level against A.
  3.71.3: the user pinned the sample down — the e-piano's FIRST 14 SECONDS = the hook TWICE (bars 1-8: first time with
  the pickup that relaunches it, second time left open on the 2nd degree + a silent bar), over i–i–♭VI–V twice. That is
  the chorus now (`T_C = HOOK + HOOK[:3] + [""]`); the bars 10-13 phrase tried in 3.71.2 was NOT it and is gone.
