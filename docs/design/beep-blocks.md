# Beep blocks (proposal, 2026-11-14)

Status: **blocks, clock, blink and sounds built (0.5.221)**; the system page is
[tiles-and-blocks](../gameplay/tiles-and-blocks.md#beep-blocks-05221). Still to do: the music install (two variants
waiting for the user's choice) and the level Starway / Vía Estelar. The music (generator `bloques_beep.py` in the music tools, previews in
`FlappyMonster_pruebas/musica/bloques_beep/`); this page is the block mechanic that goes with it.

## What

A special level, a road of stars above the clouds, made of two colours of CRYSTAL blocks that SWAP every 4 seconds on
their own: while one colour is solid the other is a passable outline. The music warns: in every 4 s phrase, 3 beeps on
beats 6, 7 and 8 (0.5 s apart), then an IMPACT on beat 1 of the next phrase = the switch. The player learns the
rhythm, not a switch to hit.

## The user's decisions (2026-11-14)

- **A new block, not the ON/OFF Block.** The ON/OFF Block changes with an Activator (hit by the player, `links`,
  nearest activator); the beep block changes with a CLOCK, with no action. A level may want both side by side.
- **But no copied code** (golden rule 2): it reuses the base of the ON/OFF Blocks.
- **One clock for the whole level**, and it speeds up with the music when the "hurry" warning makes the music faster
  (60 s left of the level's time limit).
- **Crystal blocks, one PINK and one CYAN.**
- **The clock follows the music 1:1**: if the music restarts, the clock restarts with it. (In practice the music only
  restarts in a few cases, such as drowning; this level has no water.)
- **Not in the story mode yet** (the user will decide later). Name: **Starway / Vía Estelar** (chosen over the
  working name StarTrail Highway).

## Design

### Tiles (data)

A new tile file `beepblock` (tile types folder), 4 tiles in the `Mecanismos` category, on ids 45-48 (20-26 are the fake walls):

| name | label | collision |
|---|---|---|
| `beepblock_pink` | Bloque de cristal rosa | solid |
| `beepblock_pink_x` | Bloque de cristal rosa (inactivo), `editorHide` | none |
| `beepblock_cyan` | Bloque de cristal cian | solid |
| `beepblock_cyan_x` | Bloque de cristal cian (inactivo), `editorHide` | none |

Same `switchBlock = { kind, active, other }` field as the ON/OFF Blocks; `kind = 'beep_pink' | 'beep_cyan'`. Own
`cbSymbol` for the colour-blind symbols (accessibility tab), since pink vs cyan is the only difference. Art: crystal
(faceted, a light highlight, translucent look in hard pixel art — no real alpha blending needed), solid = filled
crystal, inactive = a dotted crystal outline. A real asset file each, from a generator in `tools/art/world/`; preview
to `FlappyMonster_pruebas/beep_blocks/vista_previa.png` before installing.

### Base change: who decides a switch block's state

Today `Level:updateSwitchBlocks` asks only "is my activator ON?". Make the source of the wanted state generic:

- `b.src` stays for ON/OFF Blocks (activator);
- a block whose `kind` starts with `beep_` asks the level's **beat clock** instead: `want = (phase is pink) == (kind
  is beep_pink)`.

Everything after the decision is the existing code: the tile swap keeping water / spikes bits, `brokenQueue` with
`k = 'set'`, and the rule that a block never turns solid with a player or an obstacle inside (`pending`, retried in
`Level:update`). That rule matters: a block appearing on the player waits, it never crushes.

### The clock = the music's position

A new system `BeatClock` (world systems), created by `Level.fromData` when the level has beep blocks. Its time `t` is
**the position the music is at**, computed the same way in all 3 places (the server has no audio, so it cannot read
the music — it runs the same model):

- `t` advances with `dt × rate`, where `rate` = the slow-motion `timeScale` (the death slow-motion, which already
  slows the music through `Sound.setMusicPitch`; NOT built: the level does not step during game over) × the hurry rate (`Hurry.RATE` = ×1.189 from the moment the hurry
  jingle ends: 60 s left + `Hurry.DUCK` 2.85 s; during the jingle the music is silent but keeps advancing, and so does
  the clock). Frozen during pause, the intro card and the start countdown, exactly when the music is.
- `t` goes back to 0 whenever the music restarts (level restart; drowning, if a level with water ever uses beep
  blocks).
- Each time `t` crosses a multiple of `period` (4 s of music), the phase flips and `level:updateSwitchBlocks()` runs.
  With the hurry rate the switches come every 4 / 1.189 = 3.36 s of real time, still on the music's downbeat.
- Only where tiles are decided (single player, server) do the blocks change; clients get the tiles as `tile k='set'`
  events, as today.
- To keep `Hurry` and the clock from disagreeing, `Hurry` exposes its current rate (`Hurry.rate(owner)` /
  the server's equivalent from the level's time left) and the clock reads it; the moment comes from `Sim.limitOf`
  and the level time, which all 3 places already have.
- Level JSON (optional, defaults shown): `"beat": { "period": 4, "start": "pink" }`.

**Online:** the client needs the clock (beeps, blink, music sync), so the server's `t` travels in the snapshot (one
number, like the point-zone clock `zc`); the client advances it between snapshots with the same rate. The client never
changes tiles: the swap still arrives as tile events. → `Protocol.VERSION` + 1 (new tiles + snapshot field) and
`version.txt`.

### Sound: the clock and the music move together

- The track is installed WITHOUT its beep stem (the generator already writes stems). The 3 beeps are a real SFX file
  (`assets/sounds/…/beep.ogg`, cut from the beep stem) played by the clock on beats 6, 7, 8 of each phrase, and the
  switch plays its own short crystal "clink". So the warning works with the music muted and during the hurry jingle
  (when the music is silent), and it can never drift from the blocks. With the hurry rate the beep SFX plays at the
  same ×1.189 pitch so it matches the music.
- The audio is kept on the clock with `Sound.syncMusic(name, t, tol)` and a tight tolerance (~0.05 s) for this track,
  the way the Mega Mashup follows its director's clock. Normally they agree on their own (same start, same rate); the
  sync only corrects drift (frame hitches, a late audio start).

### Visuals

- Inactive block = dotted crystal outline.
- **On EVERY beep (beats 6, 7, 8) every beep block BLINKS (the user, 2026-11-14): for a moment each block is DRAWN
  in the other state (solid ones show the outline look, outline ones show the solid look) and then back. ONLY VISUAL:
  collision does not change until the switch on beat 1.** Driven by the same clock as the beep SFX (render only, from
  the clock `t`, in SP and on the client; the server does nothing). The accessibility "flashes" option gets a softer
  version (e.g. a brightness pulse instead of the full swap), never none: it is the cue for players with the sound
  off.
- On the switch: the existing tile bump and a few crystal sparkles, no screen shake.

### Editor

Placed like any tile (Mecanismos). No links: the clock is global to the level. The editor shows both colours solid
(as it shows ON/OFF Blocks).

## The level

- **Name (the user, 2026-11-14): Starway · ES Vía Estelar, level file `via_estelar`** (EN/ES rows in
  `translations.csv`).
- Not in the story mode for now: a Free Play level (the user decides its place later). Level file names are permanent
  (golden rule 3), so the name is chosen BEFORE the file exists.
- Proposals that were offered (the user's working name: StarTrail Highway / for Spanish, e.g. "Autopista Estelar"):
  - **Starway** · ES **Vía Estelar** — the shortest; file `via_estelar`.
  - **Star Trail** · ES **Estela Estelar** / **Sendero Estelar**.
  - **Comet Road** · ES **Ruta Cometa**.
- Shown text goes through `assets/lang/translations.csv` (all languages), never hardcoded.

## Tests

- `mechanics` (or `flood_control switchblocks`): extend with a beep case — blocks swap at t = 4, 8…; a block with the
  player inside waits; slow-motion and the hurry rate keep blocks, clock and switch times together; the clock goes back
  to 0 on a level restart.
- Online: a client sees the swaps from tile events and its beeps from the snapshot clock (the online harness).
- `docs_reference` after adding the tiles and the level; `project_check` for the new files.
- Needs a person: whether the warning reads well by ear and by eye, the feel of the timing, the music, the crystal art.
