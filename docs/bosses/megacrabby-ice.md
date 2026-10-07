# Icy Mega Crabby — `megacrabby_ice`

The Summits boss: a subclass of the Mega Crabby (all its states, attacks, intro, rests and death) with its own art,
smaller scale (`MS` 9) and three ice rules: the frost clap (its frozen claws are the weak point), the icicle field
where it pounces, and ice shards when enraged. Minions are Icy Crabbies.
**File:** `src/world/entities/types/bosses/megacrabby_ice.lua`. **Art:** `assets/images/bosses/megacrabby_ice/` (bodies
HAND-EDITED by the user). **Level:** `glaciar_cangrejo`; arena `tools/levelgen/arenas/jefe_cangrejo_helado.json`.
**Music:** `crab_tantrum_icy`. **Harnesses:** `icecrabby_rules` (`mega_*` cases, `LOOK=1`), `boss_sim` / `boss_intro` /
`online_boss` with `LEVEL=` that arena.

## Behaviour

- **Icy Mega Crabby** (`types/bosses/megacrabby_ice.lua`, "Mega Crabby helado", `boss.megacrabby_ice`): subclass of
  the Mega (ALL its states/attacks/intro/rests/death); art per class (`Mega.loadArt(dir, w, h, cw, ch, clawK,
  clawX, clawY, clawIn)` → `self.art`; the icy one 18x13 at MS 10 from `tools/art/bosses/make_icecrab_sprites.py`,
  Paralomis birsteini, claws 1.0 of the body scale, lower). Minions = Icy Crabbies (`summons` maps the types).
  Three ice rules: (1) FROST CLAP after every charge that hit nobody ('clap': claws up, slammed OUTWARD flat on
  the floor at `CLAP_AT`) → two floor waves (`waves`, speed `waveSpeed`, 1.4 s, 34 px tall = jump them) that
  `pa:freeze(waveFreeze)`; then 'clap_stuck' (`clapStuck` s, claws in ice blocks). WEAK POINT = a frozen CLAW
  (`clawBoxes()`, outside the body): ground pound on one = 2 dmg (once per clap, then recover); a normal stomp
  on a claw bounces; the back keeps its head spike → immune bounce (the user: "how is it vulnerable with that
  spike?"). (2) ICICLE FIELD where the wall pounce lands (it used to leave a slippery frost patch: pointless on a
  floor that is already ice): `fields` {x0,x1,y,dir,t,life}, one at each side OUTSIDE the claws (`patchWidth` tiles in
  total, `patchTime` s): floor cracks blink for `FIELD_WARN` 0.45 s (no damage), then icicles sprout from the inside
  out (`FIELD_SPREAD`), one every 32 px where there is floor (`fieldSpikes`, a pure function of field + level: the client
  needs `levelRef`); touching one that is out = 1 HP + recoil (SP/server, `Boss.withPlayer`); they shatter at the end;
  cleared on death; `unsafeAt` keeps respawns out. Art `bosses/megacrabby_ice/ice_field-Sheet.png` (3 frames 8x16: cracks,
  icicle, glint; drawn rising with a quad). (3) RAGE: sharp ice shards on shell AND claws (user's
  pick: body "A: Esquirlas" + claws "B: Corona" of 4 options, `--rabia A --rabia-pinza B`; `rage_body-Sheet.png` 26x21 / `rage_claw-Sheet.png` 18x15, 2 frames
  normal/glint, from `tools/art/bosses/make_icecrab_sprites.py --rabia A`: procedural tapered shards, coverage-rasterised) drawn
  by Mega.drawLocal hooks `drawBodyOverlay` / `drawClawOverlay` (same transform: follow squash/claws), white
  flash when they appear; no red pulse; anger symbols = vein + steam only (`angerKinds`, no scribble);
  icicle fields last `ragePatchTime`. Its head spike sits 2 art px lower (`Mega.loadArt(..., spikeDy)`). netPackExtra = the
  Mega's 9 fields + waves {id,x,y,dir,t} + fields {x0,x1,y,dir,t,life}. Arena `tools/levelgen/arenas/jefe_cangrejo_helado.json` (music `tentacle_nes`);
  real level **glaciar_cangrejo** "Glaciar del Cangrejo" / "Crab Glacier" (`levels_boss.py`, snow theme): thin ice
  over water, ice track with a snow-mound Crabby, ice-spike pit with an icicle Crabby, low ceiling with icicle/snow
  droppers, a wall-walking climber, an icy trampoline Crabby, then that arena grafted (zone from column 89).
  Harnesses: `icecrabby_rules` (mega_* cases, `LOOK=1` → icemega_look.png), `boss_sim`/`boss_intro`/`online_boss`
  with `LEVEL=` that arena. Protocol v40 (v42: icicle field).
