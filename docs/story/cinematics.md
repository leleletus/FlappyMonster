# Cinematics (the intro, the ending and the pre-level films)

The films are **rendered by the game, live** (user's rule: never pre-rendered or animated outside it): real
sprites, real backgrounds, a real level as the set, the real world map, the real Flappy objects piloted. Scene by
scene: [story](story.md).

**Files:** `src/story/Film.lua` (the player: scenes, cue events, fades, letterbox bars), `src/story/Stage.lua` (the
pieces: monster, laugh, mirror, shards, orb, sets), `src/story/films/intro.lua`, `ending.lua`, `chase.lua`, `lair.lua`, `common.lua`, `src/story/Actor.lua` (real bodies for the pre-level films),
`src/states/story/StoryFilmState.lua` (hold any button 1 s to skip), **`assets/story/films.json`** (the timing: the
ONE source for picture and music), `assets/story/sets/crater.json`, `ladera.json`, `ladera_noche.json` (the sets, real levels made
by `tools/levelgen/make_sets.py`), music from `tools/music/story_music.py`, sounds from `tools/sounds/story.py`.

**To change a time:** edit `films.json`, regenerate the music (`story_music.py`, then `levels.py`).
**Harness:** `story_film` (`FILM=intro|ending|chase|lair`, `XTRA=1`, `NOSHOTS=1`).

**Pre-level films:** a world can name a film to play the FIRST time a level is entered (`Worlds.LIST` `films =
{ [level] = film }`, `Worlds.film(id)`). `StoryMapState:_play` plays it through `story_film` and its `onDone` enters
the level (`StoryMapState:_start`); the save notes it as seen (`films`, see [save-data](../architecture/save-data.md))
and a level already cleared never plays it. Today: `chase` before `huida_del_espejo`, `lair` before `ruta_del_espejo`.
- **Into the level's music:** `films.json` `next` = the level's track. The film's LAST scene is written in that
  track's tempo and key and ends on what the track's intro starts with, at its level (`chase` → `mirror_chase`: 174,
  a C# pedal; `lair` → `volcan_2`: 172, an A pedal with its B♭). The score has no tail, and `StoryFilmState:_finish`
  starts the `next` track instead of stopping the music; the level asks for its own track, finds it already playing
  and keeps it (harness `story_film` `enlace`).
- **Real physics:** in these two films the monster and the Reflection are ACTORS (`src/story/Actor.lua`): a real
  `PlayerAdventure` inside the set, driven by scripted inputs (`mx`, `crouch`, `jump()`) through a stub `Input`, the
  way the Mirror boss drives its body. So walking, braking, jumps and the double jump (and their sounds and
  animations) are exactly the game's. The white rim only shows where the game shows it (`Silhouette.on`). Only what
  is magic in the game too is scripted: the floating mirror, the dive and the pounce.
Test saves to watch them: `python3 tools/story/test_saves.py 2=lluvia_pinchos 3=huida_del_espejo` (overwrites those
slots; the films stay unseen, so re-run it to watch them again).

## Details

- **Cinematics are rendered BY THE GAME** (user's rule: never pre-rendered or animated outside it; real sprites,
  backgrounds, sets, effects): `src/story/Film.lua` (player: scenes, cue events, fades, letterbox bars; with its
  music playing the film clock = the music position), `src/story/Stage.lua` (pieces: `monster`, `laugh` (the Mirror's
  laugh animation), `mirror` / `shard` / `shardSlot`, `orb` + `spark` (the flap as magic: `story/fx/` sprites from
  `tools/art/story/make_story_fx.py`), `flappyBg`, `sky`, `set` + `drawSet` = a REAL LEVEL drawn like the game does (sky,
  tiles, lava, decorations, light mood; every monster drawn in a set gets a halo), `map()` = the world map as a set
  via `StoryMapState:stage()/filmDraw(cx, cy, zoom, o)` with `filmBoss[w]` = boss size override), scenes in
  `src/story/films/intro.lua` / `ending.lua` (+ `common.lua`: the REAL Flappy `Player` and `Pipe` objects piloted,
  crater and slope measurements, map targets, the carried shards `carry`, the running Reflection `reflex`, the boss's
  floating mirror `portal` and floor `mark`), state `story_film` (`StoryFilmState`: `{ film, xtra, onDone }`; SKIP = hold any
  button / finger / mouse for 1 s, hint `story.skip_hint`). Intro plays when a NEW save is created
  (`StorySlotState:_open`); ending after the final shard; `chase` / `lair` before their levels (above).

- **TIMING = `assets/story/films.json`** (per scene: bpm, beats, `cues` in beats, `in` = cut|fade|white; per film `next` = the level track it hands over to): the ONE
  source for picture and music. `tools/music/story_music.py [intro ending]` reads it and composes ON it → catalog
  `story_intro` / `story_ending` / `story_chase` / `story_lair` (`assets/music/story/`, no loop; verified by numbers only: track = film length,
  hits land on the cues). Change a time in films.json → regenerate the music (+ `levels.py`). Material: the map tune
  (= the monster), "la llamada" on the music box, the mirror motif + the Mirror boss theme's head in A minor (= the
  Reflection); the ending is in A major and its seven rising notes are the pitches the `storyClink` sfx sings.

- Sets: `assets/story/sets/crater.json`, `ladera.json` (the volcano slope at dusk, like `huida_del_espejo`; a ditch
  and a lava lake), `ladera_noche.json` (the same at night, like `ruta_del_espejo`) (`tools/levelgen/make_sets.py`;
  real levels, they open in the editor). Sounds
  `assets/sounds/story/` (`tools/sounds/story.py`, ids `story*`, `shardDrop`, `shardGet`).

- Harnesses: `story_film` (both films through the real state, durations, music clock, skip; 3 captures per scene;
  `XTRA=1`), `story_flow` (`fragmento`, `final`, `migrar`). Contact sheets: `FlappyMonster_pruebas/historia/`.

## History and decisions (dated notes)

Kept because they record WHY things are the way they are and what was tried and rejected. Where a note
conflicts with the sections above, the sections above describe the current behaviour.

- User's verdict after watching (3.68.2): "incredible"; fixed on request — (1) Flappy → volcano TRANSITION: the Flappy
  background slides away with its edge and the real (meadow) sky appears, a glint far away, then a cut to the WORLD
  MAP: the monster flaps across the sea from the Meadow to the volcano (the old crossfade into the volcano sky "didn't
  feel right"); cue beats unchanged, so the music still fits. (2) The monster is almost black: inside a set it gets a
  thin light-blue RIM (`Stage.monster` silhouette at 4 offsets; `o.outline`). (3) REFLECTION = `K.reflect(x, y, o)`:
  the monster's real mirror image (same pose, flipped, smaller with distance, moving the opposite way), drawn into a
  canvas and cut to the GLASS SHAPE with a mask shader, glass sheen on top. (4) Monster poses as in the levels
  (`K.pose`: idle = frame 3, walk = 3↔2 at 8 fps + puff + 'step' every other frame via `K.steps`, rising 2, falling
  1↔3 at 6 fps, crouch 5 at the SAME centre — it used to be pushed 18 px into the floor; `K.hop` = idle the moment
  it lands). (5) BEFORE its shard each boss is its NORMAL enemy (`K.NORMAL`, drawn by `K.drawExtras`): Gummy, Crabby
  (no claws/spike), the ship small, a snowball, Icy Crabby with its small claws, Gloomy Crabby; after shrinking too.
  Still open (user's optional idea): Evil Monster sprites standing outside its ship, the shard summoning the ship.
- 3.100.0 — the user: going from the level before the chase to the chase, and from it to the Mirror boss, was
  "anticlimactic" — "out of nowhere the Mirror is chasing me, and in the next one the boss is already there"; asked for
  short films between those levels, like the intro and ending. Made `chase` (the monster climbs the slope with its six
  shards; a laugh; the Reflection dives from a floating mirror behind it with the centre shard, laughs, eyes the six
  and crouches to pounce; it flees, jumps the lava ditch, the pounce misses by a hair) and `lair` (the end of the run:
  a double jump over the lava lake; the Reflection stops at the shore, laughs and shatters away; night falls; the
  centre shard glints far off, the laugh echoes, a trail of floating mirrors lights up toward its lair; the monster
  breathes deep and walks into the dark). Rejected on the way: the six shards circling at shoulder height read as
  WINGS (the monster has none) → they are a small ring ABOVE its head. Not yet watched by the user.
- 3.100.1 — the user watched them: (1) the film music did not lead properly into the level's music → each film's
  last scene now plays in the level track's tempo and key and hands over to it with no gap (above); (2) in `chase` the
  shards must NOT be there from the start: the monster takes them out, then they glow — and "fix the glow" (it was a
  square behind each shard) → the glow is now the shard's own shape, added in light around it, plus a few sparkles;
  (3) `lair` was confusing ("why are there mirrors in the sky?") → rewritten: at the lava lake the Reflection stops,
  laughs and jumps into a floating mirror that flies away into the distance (its lair); at night the six shards come
  out and line up pointing that way, the seventh answers with a glint far off, and the monster follows them; the
  trail of floating mirrors is gone; (4) a decoration was floating: `lava_vent` is a sub-cell decoration placed
  without `sub` (it went to sub-cell 1, half a tile up) → `make_sets.py` now gives it one; (5) the movement felt
  simulated → the actors (above). Also rejected on the way: a tight ring of shards over the head still grouped them
  in threes that read as wings → an evenly spaced arc above the head, like a floating crown.
