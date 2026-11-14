# Beep blocks (proposal, 2026-11-14)

Status: **proposal, not built**. The music is being composed (generator `bloques_beep.py` in the music tools, previews in
`FlappyMonster_pruebas/musica/bloques_beep/`); this page is the block mechanic that goes with it.

## What

A special level, a sky road above the clouds, made of two colours of blocks that SWAP every 4 seconds on their own:
while one colour is solid the other is a passable outline. The music warns: in every 4 s phrase, 3 beeps on beats 6, 7
and 8 (0.5 s apart), then an IMPACT on beat 1 of the next phrase = the switch. The player learns the rhythm, not a
switch to hit.

## The user's decision (2026-11-14)

- **A new block, not the ON/OFF Block.** The ON/OFF Block changes with an Activator (hit by the player, `links`,
  nearest activator); the beep block changes with a CLOCK, with no action. Mixing both rules in one tile would confuse
  them, and a level may want both side by side.
- **But no copied code** (golden rule 2): it reuses the base of the ON/OFF Blocks.

## Design

### Tiles (data)

A new tile file `beepblock` (tile types folder), 4 tiles in the `Mecanismos` category, on FREE ids (today 5-8 and 20-26 are
free; choose when building and check `TileTypes`):

| name | label | collision |
|---|---|---|
| `beepblock_a` | Bloque Beep A | solid |
| `beepblock_a_x` | Bloque Beep A (inactivo), `editorHide` | none |
| `beepblock_b` | Bloque Beep B | solid |
| `beepblock_b_x` | Bloque Beep B (inactivo), `editorHide` | none |

Same `switchBlock = { kind, active, other }` field as the ON/OFF Blocks; `kind = 'beep_a' | 'beep_b'`. Own
`cbSymbol` for the colour-blind symbols (accessibility tab). Their own art (two colours that are NOT the ON/OFF blue
and red), a real asset file each, from a generator in `tools/art/world/`.

### Base change: who decides a switch block's state

Today `Level:updateSwitchBlocks` asks only "is my activator ON?". Make the source of the wanted state generic:

- `b.src` stays for ON/OFF Blocks (activator);
- a block whose `kind` starts with `beep_` asks the level's **beat clock** instead: `want = (phase is A) == (kind is
  beep_a)`.

Everything after the decision is the existing code: the tile swap keeping water / spikes bits, `brokenQueue` with
`k = 'set'`, and the rule that a block never turns solid with a player or an obstacle inside (`pending`, retried in
`Level:update`). That rule is the important one: a block appearing on the player waits, it never crushes.

### The clock (the only new system)

A new system `BeatClock` (world systems), created by `Level.fromData` when the level has beep blocks:

- `period` = 4 s (phrase), `warn` = 1.5 s (beats 6-8), `t` advanced with the SIMULATION dt (`sdt`: it slows down
  with the death slow-motion exactly as `Sound.setMusicPitch` slows the music), frozen during pause and the start
  countdown / intro card.
- Each time `t` crosses a multiple of `period`, the phase flips and `level:updateSwitchBlocks()` runs. Only where
  tiles are decided (single player, server): clients get the tiles as `tile k='set'` events, as today.
- Level JSON (optional, defaults shown): `"beat": { "period": 4, "start": "a" }`. Extended by the level editor's
  level settings later if needed.

**Online:** the clock is also needed by the client (beeps, warning flash, music sync), so its `t` travels in the
snapshot (one number, like the point-zone clock `zc`). The client never changes tiles: the swap still arrives as tile
events. → `Protocol.VERSION` + 1 (new tiles + snapshot field) and `version.txt`.

### Sound: the clock leads, the music follows

- The track is installed WITHOUT its beep stem (the generator already writes stems). The 3 beeps are a real SFX file
  (`assets/sounds/…/beep.ogg`, cut from the beep stem) played by the clock at beats 6, 7, 8 of each phrase, and the
  switch plays its own short sound. So the warning still works with the music muted or turned down, and it can never
  drift from the blocks.
- The music (120 BPM, phrase = 4 s, loop 80 s = 20 phrases) is kept in step with `Sound.syncMusic(name, t, tol)` with
  a tight tolerance (~0.05 s) for this track, the same way the Mega Mashup follows its director's clock.
- **Hurry** (`src/audio/Hurry.lua`, time running out) must not change the tempo of this track: tempo change = out of
  sync. Keep only its volume / warning effect here.

### Visuals

- Inactive block = outline texture (as the ON/OFF Blocks).
- During the warning (the last 1.5 s) the blocks about to appear blink their outline on each beep and the ones about
  to vanish flash, so deaf players and players with the sound off can read it (accessibility: honour the "flashes"
  option with a softer cue).
- On the switch: the existing tile bump / small dust, no screen shake.

### Editor

Placed like any tile (Mecanismos). No links: the clock is global to the level. The editor shows both colours solid (as
it shows ON/OFF Blocks) with a small A / B mark.

## Open questions for the user

1. One clock per level, or zones with different periods (e.g. a faster stretch at 2 s)? Proposal: one per level
   first.
2. Which colours / look for A and B?
3. Does dying restart the clock from 0 (and the music with it), or does it keep running? Proposal: keeps running
   (the music never stops; respawn lands in the middle of the rhythm like the reference stage).
4. The level itself: where it goes (story, Free Play, a secret), its name and length.

## Tests

- `mechanics` (or `flood_control switchblocks`): extend with a beep case — blocks swap at t = 4, 8…; a block with the
  player inside waits; the slow-motion keeps blocks and clock together.
- Online: a client sees the swaps from tile events and its beeps from the snapshot clock (the online harness).
- `docs_reference` after adding the tiles; `project_check` for the new files.
- Needs a person: whether the warning reads well by ear and by eye, the feel of the timing, the music.
