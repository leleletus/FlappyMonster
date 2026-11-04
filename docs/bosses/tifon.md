# Tifón, the Supreme Gust (`tifon`)

The fortress's secret boss: the fortress Gust (`gust`) grown into a giant storm cloud with a tornado tail, floating
over the rooftops. **In the story since 0.5.159 (2026-11-04): its lair `tejados_del_tifon`, behind the secret exit of
`taller_trampas`; it drops the Brass Weather Vane (`astilla_tifon`).** Names: «TIFÓN» in Spanish, «TYPHOON» in English
(`boss.tifon`). Plan: [secret-bosses-plan § 4](../design/secret-bosses-plan.md#4-supreme-gust-tifón--fortress-new);
looks, sounds and music chosen by the user: [design/tifon](../design/tifon.md).

Try it: `love . --editor tools/levelgen/arenas/jefe_tifon.json`, then play from the editor.

## Files

| File | What |
|---|---|
| `src/world/entities/types/bosses/tifon.lua` | the boss |
| `tools/art/bosses/make_tifon.py` | art: `--apply` writes `assets/images/bosses/tifon/`, `assets/anim/bosses/tifon*.json` and the 2 Collection icons |
| `tools/sounds/tifon.py` | the 14 `tifon*` sounds (`--apply`) |
| `tools/music/tifon.py` | its theme «Vendaval» (`INSTALL=1 TIFON=B`), boss track `tifon` |
| `tools/levelgen/arenas/make_jefe_tifon.py` | the test arena `jefe_tifon.json` and, with `--lair`, the lair `tejados_del_tifon.json` (rewrites it: do not run with `--lair` once the user edits the lair) |

Sets: `bosses/tifon` (body ×6, origin at the centre), `bosses/tifon_vane` (the vane, ×6, a separate layer that turns:
`left`, `right`, `edge` and the `_empty` three after the defeat), `bosses/tifon_fx` (×4: streaks, warning streaks,
lightning marks, bolt, arc, hail, scorch). Anchors are in [design/tifon](../design/tifon.md).

## The fight

Hp 6 + 2 per extra player. Phase 2 at half health (`angerAt`). Its body can be walked through and never hurts; what
hurts is what it does. It floats about 4.3 tiles over the roof, keeping 5.5 tiles to the side of the nearest player,
and faces you.

- **Blow** (`warn` 1 s: dashed streaks, puffed cheeks, the vane turns → `blow` 2.6 s): wind across the WHOLE zone at
  400 px/s (450 in phase 2), faster than walking (240): it pushes you, the boxes and the bombs (`systems/Push`,
  `pushAt`). **Shelter:** anything solid within 3 tiles upwind of you at your height (a chimney, a ledge, a box: any
  entity with `pushBy`) cuts it. **Phase 2:** 60 % of blows SWAP sides at 1.3 s; 0.55 s before, the vane goes
  edge-on with `tifonVane` + `tifonSpin` and the streaks show the new side; the wind pauses 0.2 s around the swap.
- **Inhale** (`inhale`, 2 s, the mouth opens for 0.35 s first): it pulls players along the roof towards under its
  mouth (170 px/s, never lifting them) and lifts loose objects within 7 tiles into its mouth (520 px/s, brusque, so a
  bomb rises against gravity). What reaches the mouth (1.1 tiles):
  - **a thrown, lit bomb** (`BombCore.canBeEaten` + state `lit`): swallowed → `bomb` (named so for `BombCore`, which
    explodes it after 1.2 s) → `boom` (`tifonBoom`, shake, a blast at the mouth) → `fall` onto the nearest roof
    (0.55 s; over the gap it slides to the closest roof) → **`stun`**: stomp 1, ground pound 2, on top of the lying
    cloud, ONE HIT PER KNOCKOUT (`OPENINGS`). `STUN_T` by difficulty (6 s Easy … 3.5 s Xtra). Then `rise` back up.
  - anything else it can push (an unlit bomb, a box): **coughed** at the nearest player (620 px/s), `cough`.
  - **you** (only by jumping into it): −1 and spat away, `cough`.
- **Lightning** (`charge` 1 s / 0.85 s: marks on the roof light up in three stages and blink → `strike` 0.3 s):
  3 marks (4 in phase 2), one under each player and the rest ≥ 2.2 tiles apart, never over the gap; −1 in a
  0.9-tile column from the sky to the mark. **Phase 2:** an ARC at roof level (0.7 tiles high) between pairs of
  neighbouring marks on the same roof, at most 6 tiles apart, warned by sparks along the roof: jump it.
- **Hail** (phase 2, `hail` 3 s): a stone every 0.2 s from the top of the zone (45 % near a player), 560 px/s; −1 on
  contact; ledges, boxes and chimneys stop it.
- **Roar** (`roar` 1.6 s): the first idle after reaching phase 2, it spins and roars.
- **Order:** every second attack is an inhale (the window never waits long); the others are picked from blow and
  lightning (plus hail in phase 2). `IDLE_T` 1.8 / 1.3 s between attacks.
- **Entry:** the cloud forms above the zone and comes down spinning (1.5 s), roars at 1.7 s. **Defeat:**
  `dying_out` (1.8 s lying stunned, still wearing the vane) → `dying_flee` (it rises away, the vane without its
  tip: the splinter drops, `shardDrop`).

## The lair `tejados_del_tifon`

60x17, `openTop` (no ceiling), `fortress` at night, music `fortaleza_2`; boss zone columns 15-42, rows 2-13, music
`tifon`. The roof is the floor (row 14). In the middle a 2-column GAP whose cells are floor spikes: falling in costs
1 and you jump out. Chimneys: two 2 tall right beside the gap (columns 25 and 32: hugging one, the wind never throws
you in) and two 1 tall near the walls (19, 38). Drop-through ledges at row 10 (columns 17-19, 36-38) against hail and
to throw from higher. Two big boxes (22, 35) and two respawning bombs (17, 40). Before the zone: a chimney, a ledge, a
bomb to learn to carry it and a Gust. Nothing past the zone (`project_check jefes`).

## The secret exit in `taller_trampas`

A stone CHIMNEY against the left wall, beside the start (column 2): its base (row 11) is a real block, its shaft (rows
5-10) is FAKE stone, and on top (rows 3-4) the secret exit, capped and covered by fake stone (rows 2-4, column 3).
Inside the shaft a Ventisca blows only UP (`power` 1.6, gusts of 3-4 s every 2-3 s): you hear the wind in the chimney
from the start. Jump left into the shaft and the draught lifts you to the exit; walking left into the base does
nothing. Harness `mechanics secreto_tifon`.

## Single player, server, client

Everything drawn and what blows come from `state`, `deadTimer` and the netPack: phase, facing, wind side, swap flag,
the zone bounds, the marks, arcs and hailstones. `pushAt` also runs on the client (it predicts the local player's
push from the snapshot data; the shelter check uses the client's level). Protocol 111.

## Tests

`tifon_rules` (15 cases in a fixed copy of the arena: blow, shelter, swap, inhale, swallow, cough, spit, lightning,
arc, hail, stomp, walk-through, phase, defeat, network), `mechanics secreto_tifon`, `boss_frames
LEVEL=tools/levelgen/arenas/jefe_tifon.json FX=1 ZONE=1 STATES=warn,blow,inhale,strike,…`, `sp_boss
LEVEL=assets/levels/tejados_del_tifon.json`, `online_boss LEVEL=tools/levelgen/arenas/jefe_tifon.json` (the arena's
entrance is flat for its bot; the lair has a chimney there).

## History and decisions

- 2026-11-04: the user asked for Tifón before the Mother Mole. Looks: round 1 (four looks at ×5) → "A with C's tail"
  and "too much pixel density" → round 2 at half resolution; the user chose ×6. Sounds approved as generated. Music: B
  «vendaval» of three variants.
- 2026-11-04, built in one go after "continúa con absolutamente todo lo que falte". Choices made by Claude, not yet
  seen by the user: hp 6 + 2; two phases (the plan had one change at half health); the inhale pulls players only
  along the roof (lifting them into its mouth would make the spit unavoidable); the gap costs 1 instead of a life (the
  level's floor is solid below the map, and a pit you cannot leave would be a soft-lock); the secret exit's "Gust that
  lifts you" is an upward Ventisca (the Gust only blows sideways); roof breaking in phase 2 was left out (it could cut
  the arena with no way back).
- Not judged by anyone yet: the feel, the wind's strength, the fall into the gap, the sounds in place, the music in
  the fight, readability of the dark cloud on the night sky.
