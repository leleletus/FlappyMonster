# Starway / Vía Estelar — the level (2026-11-14)

Status: **built (0.5.225), first version, NOT fully proven by the solver; the user plays and edits it by hand**. The special level of the
[beep blocks](beep-blocks.md) and the [rhythm objects](starway-rhythm-objects.md). Free Play only (not in the story yet:
the user will decide). File `assets/levels/via_estelar.json`, generator `tools/levelgen/levels_via_estelar.py`
(`python3 tools/levelgen/build.py --only via_estelar`).

The user's brief: "the longest, most labyrinthine and most fun level ever made in this game, exploiting the new and
old mechanics".

## Numbers

- **420 × 48** cells (20 160): about 2.7× the biggest level before it (`laberinto_submarino`, 134 × 55).
- Music `via_estelar` (120 BPM: beat 0.5 s, phrase 4 s = one block switch); sky `starway` at night with `light:
  "none"` (the night light mood darkened the crystal and the objects too much); `timeLimit` 900 s (the 10-minute
  default is short for a labyrinth this size; the hurry warning still comes at 60 s left and speeds everything up).
- Online: `modes: ["race"]`.

## The route (columns)

| Zone | Cols | What |
|---|---|---|
| 0 Take-off | 2-19 | start island, two signs (`via.beep`, `via.switch`) |
| 1 Crystal bridge | 20-58 | bridge of 3-tile pink / cyan pieces over the void (jump the 3-gaps or wait for the switch); a two-colour STAIRCASE that switches under your feet (jump on the impact); a safety net below with an on-beat spring that sends you back; **star 1** on an islet under the bridge (back up with the spring) |
| 2 Clap corridor | 59-96 | low-ceiling corridor (no jumping over) with 4 pairs of clap-spike plates, alternating offsets; a 7-tile wall climbed only with an on-beat bounce |
| 3 The metronome | 97-165 | the void crossed on PAIRS of metronome platforms that meet on beat 5 (each pair goes in opposite directions); a Gust; then the FORK: two-colour stepping stones up to the HIGH ROAD (crabby, extra life), or the fall to the LOW ROAD of clouds (clap plates, Gummies) |
| 4 Constellation maze | 166-262 | 12 × 6 chambers of 8 × 6 (rows 8-44): a DFS maze + 14 loops. 40 % of the side passages are CRYSTAL DOORS (a 3-high column of pink or cyan: open half the time). Vertical passages: a drop-through hole, climbed with an on-beat spring or a ladder of ledges. Two ON/OFF Activators in the two farthest dead ends (one in the top half, one in the bottom) open the two Doors at the exit (`links`). **Star 2**, an extra life and apples in other dead ends; clap plates, Gummies and Hoppers in the rest; 3 checkpoints. Entrances: top-left (high road) and middle-left (low road); exit bottom-right |
| 5 Star staircase | 263-300 | a 35-row tower: spring → ledge → two-colour stair → metronome LIFT → ledge (Gust) → spring → two-colour stair back → ledge → the top. Falling only drops you inside the tower |
| 6 The grand symphony | 301-418 | a two-colour bridge with clap plates, a metronome pair over the void with a Gust, a DESCENDING two-colour staircase (each switch drops you onto the next step) with springs below for whoever falls, the finish island; **star 3** on a ledge reached with a spring |

## How it was checked

`level_solve` learnt the beat (0.5.225): time is part of the state (each action is 0.1 s; the key holds the moment of
the 8-s cycle in quarter beats), beep blocks switch as in the game, the metronome is a moving body, clap spikes out
kill (stricter than the game) and the on-beat spring launches by the beat. Long levels are solved in STRETCHES:
`START=col,row GOALCOL=c [GOALROW=r] [T0=s]`.

Results of the first version (the user asked to stop the solver — the PC had other heavy work — and to test, play and
edit the level by hand):
- OK: start → corridor (col 61) · corridor + spring wall (→ 94) · the metronome pairs (→ 129) · the fork, high road
  (→ 150, row 13) and low road (→ 150, row 31) · high road → the top Activator (178, 11).
- NOT PROVEN (search budget of 80 000 states ran out, so not necessarily impossible): high road → the bottom Activator
  (234, 35) — closest (226, 22); the tower (270, 43 → 296, 8) — stuck after the first spring, around (274, 33): the
  first ledge → pink stair step may be too hard or the spring's launch misses the ledge.
- Not run: low road → maze (the test started on a clap plate), Activators → exit, the finale.
- `level_check`: OK (420 × 48, 124 entities, race).

## Needs a person

The fun, the difficulty curve, the timing windows, whether the maze is fair or confusing, and the length (the solver's
route is far faster than a human's).
