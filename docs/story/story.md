# The story of Flappy Monster: "El Espejo Roto" (The Broken Mirror)

Approved by the user on 2026-10-03. This document is the reference for the story. How it is implemented:
[story-mode](story-mode.md) (worlds, saves, shards), [cinematics](cinematics.md) (the two films).

**Hard rule: the monster has NO WINGS.** It flaps by a magic of its own. Never draw or mention wings.

## Premise

The monster could **flap** (the Flappy mode). It has no wings: it flaps by a **magic** of its own. One day it flies to
an old mirror hidden in the volcano and crashes into it: the glass breaks into **seven shards**.

- Its **Reflection** steps out of the frame, steals the flap and stays in the volcano with the centre shard. The
  monster is left with what it can do physically and the little magic it has left: the **double jump**. That is why
  the adventure is on foot.
- The other six shards fall across the islands. Whoever finds one **grows and becomes furious**: this is **LA FURIA
  DEL ESPEJO** ("The Fury of the Mirror"), and it is why every boss is the giant version of a normal enemy (the Evil
  Ship's pilot found one like the rest).

Each beaten boss drops its shard; with all seven the mirror is restored, the Reflection goes back inside, the fury
fades (the bosses shrink) and the monster **gets its flap back**.

There is no dialogue or text anywhere: animation and music only.

## The shards

Images: `assets/images/story/mirror/` (from `tools/art/story/make_mirror_shards.py`); they all share one 48x64 canvas:
drawn at the same point, they fit together and the mirror fills up. Logic: `src/story/Shards.lua`.

| No. | Boss | Level | Position in the mirror |
|---|---|---|---|
| 1 | Gummy King | `reino_gummy` | top-left |
| 2 | Mega Crabby | `guarida_cangrejo_rey` | top-right |
| 3 | Evil Ship | `fortaleza_malvada` | right |
| 4 | Snowball Boss | `lago_helado` | bottom-right |
| 5 | Icy Mega Crabby | `glaciar_cangrejo` | bottom-left |
| 6 | Mega Gloomy Crabby | `gruta_lugubre` | left |
| 7 | The Mirror | `ruta_del_espejo` | centre (where it crashed) |

- In the level: when the boss falls, its shard comes out of it and hovers; the player picks it up by touching it
  (after 5 s it goes to the player by itself; touching the finish first collects it). It is only SAVED when the level
  is finished (rule: nothing gained in a level is saved until the level ends). A boss already beaten whose shard is
  owned does not drop it again.
- **Xtra Extreme** (two bosses per arena): each drops HALF a shard (`3a` the original, `3b` the copy): 14 halves.
- The map shows the mirror with the shards owned and the count ("Fragmentos del espejo 4 / 7"; Xtra: n / 14).
- The Mirror boss's shard is the last: on pickup the player freezes, the screen fades to white and the ENDING starts,
  without touching the finish; then the usual results screen.

## The films, scene by scene

Both are drawn BY THE GAME, live, with its sprites, backgrounds, sets and effects (nothing pre-rendered). Times come
from `assets/story/films.json` (the single source for picture and music).

### Intro (when a save is created) — 51.8 s

| Scene | Time | What is seen | Music and sound |
|---|---|---|---|
| `flappy` An ordinary day | 0.0–7.3 s | The monster FLAPS between the pipes: the real Flappy mode (its background, its pipes, its player, piloted). | Its theme ("Rumbo a las islas", which opens with "la llamada"), light. Every flap sounds. |
| `glint` The glint | 7.3–12.7 s | The pipes end; something glints far away; the Flappy background slides off, the real sky appears, then the world map: the monster flaps across the sea to the volcano. | The theme hangs; two bells (the glint); the bass darkens. |
| `mirror` The old mirror | 12.7–18.4 s | It comes down the crater chimney (set: a real level). A golden mirror; its reflection imitates it. | Music box: la llamada… and the mirror returns it UPSIDE DOWN. |
| `crash` CRACK! | 18.4–21.3 s | It flaps too close and crashes: flash, shake, the glass split in seven. | Two heartbeats, a tremolo… and the hit (glass). |
| `reflex` The Reflection steps out | 21.3–26.3 s | The shards float around the empty frame; inside, its REFLECTION (inverted colours) appears and jumps out. | Low galloping drone; the mirror motif; when it lands, the head of the Mirror boss theme. |
| `steal` It steals the flap | 26.3–33.8 s | The Reflection rips the flap out (an orb of magic), rises flapping and laughs; it keeps the centre shard. The monster tries: a jump, a second jump… and falls. The Reflection throws everything out of the crater. | La llamada, torn away, deflates; the Reflection sings it in its own voice; the laugh; drum roll. |
| `scatter` Six shards | 33.8–38.8 s | On the map: the six shards (and the monster) cross the sky from the volcano and fall one by one. | Six bells going DOWN, one per shard. |
| `fury` The fury of the mirror | 38.8–45.8 s | One by one, close up: whoever finds a shard grows and becomes furious (before the shard each is its normal small enemy). Then all the islands, reddened. | Six hits going UP, one per boss; the dominant with a roll. |
| `onfoot` On foot | 45.8–51.8 s | The monster lands in the Meadow. It gets up, tries to flap (just a little hop)… and starts walking. → MAP. | Silence; la llamada does not come out; and then it does, determined: it leads into the map music. |

### Ending (on picking up the last shard) — 52.5 s

| Scene | Time | What is seen | Music and sound |
|---|---|---|---|
| `seven` The seven | 0.0–5.7 s | In the crater, before the empty frame: the shards come out and circle it (Xtra Extreme: the 14 halves). | La llamada on the music box; rising arpeggios. |
| `pieces` Piece by piece | 5.7–15.7 s | They fly to the frame and fit one by one, in the order they were won (the centre one last). | Seven notes going UP the scale, one per shard (the same ones the clink effect sings). |
| `whole` The mirror, whole | 15.7–18.2 s | Flash: the cracks vanish; rays of light. | The full chord and la llamada, fast, up high. |
| `return` The Reflection returns | 18.2–23.2 s | The mirror pulls the Reflection in, kicking; out of the glass comes what it stole: the orb of the flap. | Its theme falls apart downward; the hit; two notes of la llamada. |
| `light` The light crosses the islands | 23.2–29.2 s | On the map: a wave of light leaves the volcano and reaches each island: the FURY OF THE MIRROR goes out. | The map theme, full; one bell per island. |
| `shrink` Small again | 29.2–36.2 s | One by one, close up: the bosses shrink (the Gummy, now without its crown). | The theme goes on, playful; a "pop" per boss. |
| `flap` The flap | 36.2–43.4 s | The orb returns to the monster. It tries: one flap… two… and rises without stopping out of the chimney; its reflection, now only a reflection, imitates it. | Silence; with each flap, one more note of la llamada; and it rises. |
| `home` Flying home | 43.4–52.5 s | It flies over the volcano; the sky becomes the Flappy mode's again, the pipes return; the logo. | The whole theme; with the logo, the final chord and la llamada on bells. |

## Open ideas (optional, from the user)

Evil Monster sprites standing outside its ship; the shard summoning the ship.
