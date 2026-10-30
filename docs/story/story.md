# The story of Flappy Monster: "El Espejo Roto" (The Broken Mirror)

Approved by the user on 2026-10-03. This document is the reference for the story. How it is implemented:
[story-mode](story-mode.md) (worlds, saves, shards), [cinematics](cinematics.md) (the films).

**Hard rule: the monster has NO WINGS.** It flaps by a magic of its own. Never draw or mention wings.

## Premise

The monster could **flap** (the Flappy mode). It has no wings: it flaps by a **magic** of its own. One day it flies to
an old mirror hidden in the volcano and crashes into it: the glass breaks into **shards** — one per boss plus the
centre one (eight since the jungle, 0.5.99; how many there are is data: `assets/story/shards.json`).

- Its **Reflection** steps out of the frame, steals the flap and stays in the volcano with the centre shard. The
  monster is left with what it can do physically and the little magic it has left: the **double jump**. That is why
  the adventure is on foot.
- The other shards fall across the islands, one per island boss. Whoever finds one **grows and becomes furious**: this is **LA FURIA
  DEL ESPEJO** ("The Fury of the Mirror"), and it is why every boss is the giant version of a normal enemy (the Evil
  Ship's pilot found one like the rest).

Each beaten boss drops its shard; with all of them the mirror is restored, the Reflection goes back inside, the fury
fades (the bosses shrink) and the monster **gets its flap back**.

There is no dialogue or text anywhere: animation and music only.

## The shards

**The catalog is `assets/story/shards.json`** — the single list, in STORY order (the order they are won): the game
(`src/story/Shards.lua`: `LIST`, `ORDER`, `LEVEL`, `BOSSES`, `TOTAL`, `FINAL`), the films (how many bells, bosses that
grow and shrink, islands the wave crosses: [cinematics](cinematics.md)) and the film music read it. Each entry: `id`
(saved in the save files and the image name `shard_<id>.png`: **never renumbered**; a new one takes the next free
number), `level` (the boss level that drops it), `tint` (its island's colour in the glass), `normal` (what the boss
looks like BEFORE its shard in the intro: its normal enemy sprite), `final` (the Mirror's, the centre one).

Images: `assets/images/story/mirror/` (from `tools/art/story/make_mirror_shards.py`); they all share one 48x64 canvas:
drawn at the same point, they fit together and the mirror fills up. The outer pieces go clockwise around the centre
in story order.

| Order | Id | Boss | Level | Position in the mirror |
|---|---|---|---|---|
| 1 | 1 | Gummy King | `reino_gummy` | top-left |
| 2 | 2 | Giant Pufferfish (was Mega Crabby, now a secret boss) | `cala_resaca` | top-right |
| 3 | 8 | Giant Rhino Beetle (the jungle, 0.5.99) | `templo_escarabajo` | right, upper |
| 4 | 3 | Evil Ship | `fortaleza_malvada` | right, lower |
| 5 | 4 | Snowball Boss (the Frozen Mountains, world 5) | `lago_helado` | bottom-right |
| 6 | 5 | Icy Mega Crabby (the Frozen Coast, world 6, 0.5.100) | `glaciar_cangrejo` | bottom-left |
| 7 | 6 | Giant Hopper (was Mega Gloomy Crabby, now a secret boss) | `gruta_del_farol` | left |
| 8 | 7 | The Mirror | `ruta_del_espejo` | centre (where it crashed) |

- In the level: when the boss falls, its shard comes out of it and hovers; the player picks it up by touching it
  (after 5 s it goes to the player by itself; touching the finish first collects it). It is only SAVED when the level
  is finished (rule: nothing gained in a level is saved until the level ends). A boss already beaten whose shard is
  owned does not drop it again.
- **Two bosses per arena** (`bossExtra`; Xtra Extreme until 0.5.24, today no difficulty — kept for a future idea, the user): each drops HALF a shard (`3a` the original, `3b` the copy): twice as many halves. Today every difficulty uses the whole shard and the same films.
- The map shows the mirror with the shards owned and the count ("Fragmentos del espejo 4 / 8"; Xtra: n / 16).
- The Mirror boss's shard is the last: on pickup the player freezes, the screen fades to white and the ENDING starts,
  without touching the finish; then the usual results screen.

## The films, scene by scene

Both are drawn BY THE GAME, live, with its sprites, backgrounds, sets and effects (nothing pre-rendered). Times come
from `assets/story/films.json` (the single source for picture and music).

Scenes that go ONE BY ONE through the bosses or the shards (`scatter`, `fury`, `pieces`, `shrink`) last longer with
more of them (`plus` in films.json); the times below are for today's 7 bosses + the Mirror (8 shards).

### Intro (when a save is created) — 53.4 s

| Scene | Time | What is seen | Music and sound |
|---|---|---|---|
| `flappy` An ordinary day | 0.0–7.3 s | The monster FLAPS between the pipes: the real Flappy mode (its background, its pipes, its player, piloted). | Its theme ("Rumbo a las islas", which opens with "la llamada"), light. Every flap sounds. |
| `glint` The glint | 7.3–12.7 s | The pipes end; something glints far away; the Flappy background slides off, the real sky appears, then the world map: the monster flaps across the sea to the volcano. | The theme hangs; two bells (the glint); the bass darkens. |
| `mirror` The old mirror | 12.7–18.4 s | It comes down the crater chimney (set: a real level). A golden mirror; its reflection imitates it. | Music box: la llamada… and the mirror returns it UPSIDE DOWN. |
| `crash` CRACK! | 18.4–21.3 s | It flaps too close and crashes: flash, shake, the glass split in pieces. | Two heartbeats, a tremolo… and the hit (glass). |
| `reflex` The Reflection steps out | 21.3–26.3 s | The shards float around the empty frame; inside, its REFLECTION (inverted colours) appears and jumps out. | Low galloping drone; the mirror motif; when it lands, the head of the Mirror boss theme. |
| `steal` It steals the flap | 26.3–33.8 s | The Reflection rips the flap out (an orb of magic), rises flapping and laughs; it keeps the centre shard. The monster tries: a jump, a second jump… and falls. The Reflection throws everything out of the crater. | La llamada, torn away, deflates; the Reflection sings it in its own voice; the laugh; drum roll. |
| `scatter` A shard for each island | 33.8–39.4 s | On the map (all the islands): the bosses' shards (and the monster) cross the sky from the volcano and fall one by one. | One bell going DOWN per shard (the scale down to G#). |
| `fury` The fury of the mirror | 39.4–47.4 s | One by one, close up: whoever finds a shard grows and becomes furious (before the shard each is its normal small enemy; the jungle's is a small Rhino Beetle). Then all the islands, reddened. | One hit going UP per boss; the dominant with a roll. |
| `onfoot` On foot | 47.4–53.4 s | The monster lands in the Meadow. It gets up, tries to flap (just a little hop)… and starts walking. → MAP. | Silence; la llamada does not come out; and then it does, determined: it leads into the map music. |

### Ending (on picking up the last shard) — 54.8 s

| Scene | Time | What is seen | Music and sound |
|---|---|---|---|
| `seven` All the shards | 0.0–5.7 s | In the crater, before the empty frame: the shards come out and circle it (Xtra Extreme: the halves). | La llamada on the music box; rising arpeggios. |
| `pieces` Piece by piece | 5.7–17.0 s | They fly to the frame and fit one by one, in the order they were won (the centre one last). | One note going UP the major scale per shard, the last on the top tonic (the same ones the clink effect sings). |
| `whole` The mirror, whole | 17.0–19.5 s | Flash: the cracks vanish; rays of light. | The full chord and la llamada, fast, up high. |
| `return` The Reflection returns | 19.5–24.5 s | The mirror pulls the Reflection in, kicking; out of the glass comes what it stole: the orb of the flap. | Its theme falls apart downward; the hit; two notes of la llamada. |
| `light` The light crosses the islands | 24.5–30.5 s | On the map: a wave of light leaves the volcano and reaches each island: the FURY OF THE MIRROR goes out. | The map theme, full; one bell per island. |
| `shrink` Small again | 30.5–38.5 s | One by one, close up: the bosses shrink (the Gummy, now without its crown). | The theme goes on, playful; a "pop" per boss. |
| `flap` The flap | 38.5–45.7 s | The orb returns to the monster. It tries: one flap… two… and rises without stopping out of the chimney; its reflection, now only a reflection, imitates it. | Silence; with each flap, one more note of la llamada; and it rises. |
| `home` Flying home | 45.7–54.8 s | It flies over the volcano; the sky becomes the Flappy mode's again, the pipes return; the logo. | The whole theme; with the logo, the final chord and la llamada on bells. |

### The chase (before "La Huida del Espejo", the first time) — 20.5 s

| Scene | Time | What is seen | Music and sound |
|---|---|---|---|
| `arrive` The slope | 0.0–7.5 s | After the eruption the monster climbs the volcano slope at dusk. It stops, crouches and TAKES OUT its shards (an arc over its head); they glow and tremble — the Mirror's is near. | La llamada, calm, with footsteps; the volcano rumbles; one rising bell per shard (they come out); the mirror motif. |
| `ambush` The ambush | 7.5–15.0 s | A distant laugh; it looks around. A floating mirror opens behind it and the REFLECTION dives down with the centre shard. It laughs, eyes the shards and crouches to pounce; the monster backs away. | Heartbeats and a tremolo; the hit and the head of the Mirror theme; the laugh hammered on the mirror motif; a roll. |
| `run` Run! | 15.0–20.5 s | A startled jump; it RUNS; the Reflection pounces and a double jump saves it by a hair; it jumps the lava ditch and runs out of frame, the Reflection after it. → the level. | At 174, the tempo of "¡Corre!": two-step drums, the chopped hook, the hit of the miss; then a C# pedal at half voice — what the level's intro starts with (it comes in with no gap). |

### The lair (before "Ruta del Espejo", the first time) — 19.6 s

| Scene | Time | What is seen | Music and sound |
|---|---|---|---|
| `escape` End of the run | 0.0–6.9 s | Still running: a jump and a double jump across the lava lake. The Reflection stops at the shore, laughs, jumps into a floating mirror — and the mirror flies away into the distance (its lair). The monster watches it go, out of breath. | The chase drums; two notes up with each jump; everything cuts at the shore; the laugh; rising runs as it flies off; two bells far away. |
| `night` Night falls | 6.9–14.0 s | Night. Alone, it takes out its shards: they tremble and line up POINTING the way it went. Far off, the Mirror's answers with a glint; the laugh echoes. | La llamada alone, sad; one rising bell per shard; the mirror motif; two high bells (the answer) and the motif deep down; a Phrygian cadence toward A. |
| `follow` Into the lair | 14.0–19.6 s | It nods and walks after its shards, toward the glint, into the dark. → the level. | At 172 in A, the tempo and key of "Lluvia de fuego" (the level's music): the galloping bass, la llamada in A minor, determined; then an A pedal with its B♭ at half voice, and the level's intro comes in. |

## The secrets: the splinters, the Groove and the true ending

The user's design and decisions of 2026-10-29 (analysis: `FlappyMonster_pruebas/secretos/lore_analisis.md`). How it is
built: [story-mode](story-mode.md#the-secrets-secret-exits-splinters-the-groove-and-the-mashup),
[world-map](world-map.md#the-secret-nodes).

- **The splinters.** When the mirror broke, tiny SPLINTERS flew off as well as the shards. Crabs that found one became
  the "Mega" crabs, hidden in secret lairs reached through a SECRET EXIT in a level of their island (Arrecife Globo →
  the Mega Crabby's lair; Templo del Eco → the Mega Gloomy's grotto). Each WEARS its splinter: the Mega Crabby a SHELL
  CROWN, the Mega Gloomy an AMULET. Beaten, it drops the piece (crown / amulet with its splinter) and flees, still big,
  like the main bosses. The player keeps the pieces.
- **The rule that holds it together:** losing the piece never shrinks anyone; only the restored mirror's LIGHT does.
  In the ending the wave shrinks every boss grown by mirror power — the secret crabs too, if the player found them (at
  their red nodes, all at once, in the wide shot of `shrink`). The GROOVE does not shrink: its disco ball, made of
  splinters, bounces the wave away (shown only when the player owns every splinter: then the Groove matters).
- **Two endings.** Without every splinter (kind `splinter`) the game ends at the Mirror, exactly as before, nothing
  extra. With all of them (when the Mirror falls, or later when the last one is won), back on the map the Groove's
  scene plays: its ball pulls the splinters out of the crown and the amulet (the player keeps the empty settings: state
  `stolen`, the cards say so), the ball is whole, and on its island and in the Mashup — the ball's dance field — the
  monster's flap is jammed (it sputters; elsewhere the adventure is on foot anyway). The Groove's island opens: the
  Groove, then the CRAB MEGA MASHUP. After beating the Groove, its ball's beams make the three small crabs (Icy Mega
  Crabby, Mega Crabby, Mega Gloomy) grow again (that is why they are big in the Mashup; there they wear no crown or
  amulet: the ball holds the splinters). The TRUE ENDING, after the Mashup: the ball breaks, the splinters go back to
  their settings, everyone small and dancing, the flap free again, and the trophy: the Disco Ball.
- No text anywhere, as always: the map scenes `groove`, `regrow`, `disco` and the ending's additions are animation and
  sound only. Not watched by a person yet.

## Open ideas (optional, from the user)

Evil Monster sprites standing outside its ship; the shard summoning the ship.

FUTURE (the user, 2026-10-29; not to build yet): after the ending, the player might FLY in replayed levels to reach
secret places.
