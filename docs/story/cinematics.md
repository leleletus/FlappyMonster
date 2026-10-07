# Cinematics (the intro and ending films)

The two films are **rendered by the game, live** (user's rule: never pre-rendered or animated outside it): real
sprites, real backgrounds, a real level as the set, the real world map, the real Flappy objects piloted. Scene by
scene: [story](story.md).

**Files:** `src/story/Film.lua` (the player: scenes, cue events, fades, letterbox bars), `src/story/Stage.lua` (the
pieces: monster, laugh, mirror, shards, orb, sets), `src/story/films/intro.lua`, `ending.lua`, `common.lua`,
`src/states/story/StoryFilmState.lua` (hold any button 1 s to skip), **`assets/story/films.json`** (the timing: the
ONE source for picture and music), `assets/story/sets/crater.json` (the crater set, a real level made by
`tools/levelgen/make_sets.py`), music from `tools/music/story_music.py`, sounds from `tools/sounds/story.py`.

**To change a time:** edit `films.json`, regenerate the music (`story_music.py`, then `levels.py`).
**Harness:** `story_film` (`XTRA=1`, `NOSHOTS=1`).

## Details

- **Cinematics are rendered BY THE GAME** (user's rule: never pre-rendered or animated outside it; real sprites,
  backgrounds, sets, effects): `src/story/Film.lua` (player: scenes, cue events, fades, letterbox bars; with its
  music playing the film clock = the music position), `src/story/Stage.lua` (pieces: `monster`, `laugh` (the Mirror's
  laugh animation), `mirror` / `shard` / `shardSlot`, `orb` + `spark` (the flap as magic: `story/fx/` sprites from
  `tools/art/story/make_story_fx.py`), `flappyBg`, `sky`, `set` + `drawSet` = a REAL LEVEL drawn like the game does (sky,
  tiles, lava, decorations, light mood; every monster drawn in a set gets a halo), `map()` = the world map as a set
  via `StoryMapState:stage()/filmDraw(cx, cy, zoom, o)` with `filmBoss[w]` = boss size override), scenes in
  `src/story/films/intro.lua` / `ending.lua` (+ `common.lua`: the REAL Flappy `Player` and `Pipe` objects piloted,
  crater measurements, map targets), state `story_film` (`StoryFilmState`: `{ film, xtra, onDone }`; SKIP = hold any
  button / finger / mouse for 1 s, hint `story.skip_hint`). Intro plays when a NEW save is created
  (`StorySlotState:_open`); ending after the final shard.

- **TIMING = `assets/story/films.json`** (per scene: bpm, beats, `cues` in beats, `in` = cut|fade|white): the ONE
  source for picture and music. `tools/music/story_music.py [intro ending]` reads it and composes ON it → catalog
  `story_intro` / `story_ending` (`assets/music/story/`, no loop; verified by numbers only: track = film length,
  hits land on the cues). Change a time in films.json → regenerate the music (+ `levels.py`). Material: the map tune
  (= the monster), "la llamada" on the music box, the mirror motif + the Mirror boss theme's head in A minor (= the
  Reflection); the ending is in A major and its seven rising notes are the pitches the `storyClink` sfx sings.

- Set: `assets/story/sets/crater.json` (`tools/levelgen/make_sets.py`; a real level, opens in the editor). Sounds
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
