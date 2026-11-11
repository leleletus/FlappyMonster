# The tutorial level (2026-11-10)

**The user's request:** "a new tutorial level with ABSOLUTELY ALL the game's mechanics, and a tutorial with prompts
about the objects and a guided tutorial on how to play, what to do and what you can do — without showing absolutely
everything or how to squeeze the obstacles, to avoid spoilers and ruining the experience."

**Status:** first version built (0.5.190): `assets/levels/tutorial.json` (362 × 18, 21 sections, 23 signs), from
`tools/levelgen/make_tutorial.py`; the entry **TUTORIAL** heads the Adventure menu (Story stays the default
selection); `"followScenes": true` makes its dark cave follow the player and keeps the level out of online (`"modes": []` never did: an empty list means no limit, and the editor drops it). The user reviews it in play; this page keeps the plan and decisions.

**Built pieces:** the help sign `hint` (`src/world/entities/types/items/hint.lua`: props `text` = a translation key,
`radius`; the bubble is drawn above the darkness through `Entities.renderOverlays`, by `src/ui/HintBubble.lua` since
0.5.196, shared with the Flappy cages), its art
(`tools/art/items/make_hint_sign.py`), the `tut.*` texts and `keys.touch_*` (the touch button names: `Input.label`
gives them while playing with a finger), `adv.tutorial`.

**Design rule found while building:** the main path never depends on an OBJECT (box, trampoline, seed, geyser): those
lead to an optional reward (a star, an extra life). The ON/OFF wall and the door are terrain gates opened by an
activator under them. Geometry checked against the physics (single jump 1.58 tiles, double ≈ 3.15): every pit can be
climbed out of, the double-jump wall is 2 tiles. Found in play / by the solver and fixed: the ground-pound exit step sat under the pillar with 1 tile of headroom (the user: "literally impossible"), the pool had a sheer wall (swim jumps are weak and recharge only on the ground: now underwater steps), the crouch tunnel is 3 tiles (crouched you cannot walk, only crouch-hop).

**How it is verified:** `level_solve` on a copy with the three gates open (it cannot break the lid, hit activators or crouch-hop) and `mechanics tutorial` on the real level (signs have texts, activator opens the wall, the pound breaks the lid, the door opens).

## Principles

- **Teach the verb, not the trick.** Each section introduces ONE thing with a short prompt ("Hold {run} to run"),
  gives a safe place to try it and a small gap that needs it. Combinations, speed tricks, secrets and what each
  object can do in clever hands are left for the player to discover ("this box can be carried… and more").
- **No bosses, no story spoilers**, no secret exits, no island-specific enemies beyond one example each. The prompts
  say there is more ("there are many more kinds: watch how each one moves").
- **Safe:** a checkpoint before every section, falls lead back into the section (no bottomless pits early on),
  `parTime` generous; no time pressure.
- **Prompts are signs** placed in the level: a post with a "?" that shows its text in a bubble while the player is
  near. The text is a translation key (`assets/lang/translations.csv`, every language) with the button names of the
  device in use inserted ({jump}, {run}, {crouch}, {grab}, {light}: `Input.label`).

## Sections (left to right)

| # | Section | What it teaches | Needs it |
|---|---|---|---|
| 1 | Walk | move, the goal is at the end (right) | — |
| 2 | Run | hold {run}; a long gap | a run-up |
| 3 | Jump | {jump}, holding it jumps higher; a step | jump |
| 4 | Double jump | press again in the air | a tall ledge |
| 5 | Crouch | {crouch}, low tunnel; crouch + jump; looking up / down by holding | crouch |
| 6 | Drop-through platforms | hold {crouch} on a thin platform | drop |
| 7 | Stomp | jump on a Gummy; touching it from the side hurts | stomp |
| 8 | Spikes and health | spikes hurt; food heals; the health on screen | — |
| 9 | Ground pound | {crouch} in the air; breaks blocks below | break a floor |
| 10 | Head bump | breakable blocks from below; ON/OFF switch blocks | switch |
| 11 | Checkpoints and pickups | checkpoint, stars, extra life | — |
| 12 | Carry and throw | {grab} picks up / throws, {crouch}+{grab} puts down; a small box as a step | carry |
| 13 | Push | walk into a big box | push |
| 14 | Trampoline | bounce higher | bounce |
| 15 | Water | swim, the air bar, air bubbles from vents | swim |
| 16 | Ice | slippery ice; thin ice cracks (and grows back) | — |
| 17 | Wind and geysers | air pushes you | ride the wind |
| 18 | Doors and activators | an activator opens a door | open it |
| 19 | The dark | {light}: the flashlight (and its battery) | find the way |
| 20 | The Seed | carry it, ground pound to plant it, climb the plant | plant |
| 21 | Goal | touch the flag | — |

## Decisions taken by default (the user can change them)

- **Where:** a new **TUTORIAL** entry in the Adventure menu (above Story); it is also listed in Free Play. Level file
  `assets/levels/tutorial.json` (the id is permanent once shipped). Online: not listed (`followScenes`, single player only).
- **The sign** is a new generic entity `hint` ("Cartel", category Objetos): props `text` (a translation key) and
  `radius` (tiles). It draws only (no collision, nothing in the simulation); online it would work the same on each
  client. Its art is a real file (`tools/art/items/make_hint_sign.py`).
- **Built by a script** (`tools/levelgen/make_tutorial.py`): each section is an ASCII map + its entities, so the level
  can be rebuilt while it is being designed. It REFUSES to overwrite the level once it exists (the user may have
  edited it in the editor) unless `--force`.
- Texts in Spanish and English (the only languages of the sheet today).

## The offer in Story (0.5.191, the user: "yes, optionally")

The first time a new story is started on a device, `TutorialOfferState` asks before the intro film: PLAY THE TUTORIAL / START NOW (back = start now). Shown once (`Settings.tutorialOffered`, also set by entering the tutorial from the Adventure menu). Any exit from the level (finishing, quitting from pause) continues to the intro, so the new game starts either way. Campaigns opt in with `offerTutorial`.

Players who skip it still learn to run: `valle_soleado`, the first story level, has a `hint` sign at the start (`tut.run_tip`, "Hold {run} to run!"; the user asked for this). Signs don't count towards a bot graph's signature (`BotNav.signature`), so adding one never makes a graph stale.

## Dressing and darkness (0.5.193)

Dressed with `retheme.py tutorial` (theme `meadow`, 17 cosmetic tiles) and `retheme.py --bg tutorial` (a generated background plane); the 9 meadow decorations inside the cave columns were swapped for 19 cave ones. Gameplay data is unchanged. The cave fades in and out over 1.2 s (`Scenes.follow`, `DARK_FADE`); the sky and the rest of the scene swap only while fully dark, so the change is never seen. The user: entering was too quick, and leaving must fade too.

## Order and button icons (0.5.195)

The user: stars and checkpoints appeared long before the sign that explained them. Now `tut.stars` sits before the first star and `tut.checkpoint` before the first checkpoint; the old `tut.pickups` sign (section 11) explains the extra life. The user also asked for button sprites: with a keyboard or a controller each `{button}` in a sign is drawn as its icon (`src/ui/InputGlyphs.lua`, art from `tools/art/ui/make_input_glyphs.py`, picked from `Input.label` so A/B swapping follows); on a phone the text keeps the on-screen button's name and that button glows and bounces while the sign is read (`TouchControls.highlight`). Checked by `menu_flow` `tut_iconos` with captures `tut_sign_{keyboard,gamepad,touch}`. `make_tutorial.py` no longer matches the level (the user edits it by hand now): never rerun it with `--force`.

## Open questions for the user

- Which enemies to show (one Gummy and one Crabby by default)?
