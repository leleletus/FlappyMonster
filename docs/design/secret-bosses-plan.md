# Secret bosses: the plan to finish them (proposal of 2026-11-03)

The user (2026-11-03): "ahora es momento de trabajar en los bosses secretos restantes. ¿Qué diseños propones y sus
mecánicas?". Background: [future-secret-bosses](../bosses/future-secret-bosses.md) (the four ideas of 2026-10-29) and
how a secret is wired: [story-mode](../story/story-mode.md#the-secrets-secret-exits-splinters-the-groove-and-the-mashup).

## Where we are

| Boss | Island | Fight | Lair level | Secret exit | Splinter + piece | Music |
|---|---|---|---|---|---|---|
| Mega Crabby / Mega Gloomy / Groove | coast / caves / volcano | done | done | done | done | done |
| Carnivorous Queen (`carnqueen`) | jungle | done | `jardin_de_la_reina` (0.5.157) | `templo_de_los_pesos` | `astilla_reina` | `reina` (boss), `jungla_1` |
| Triple Strike Scorpion (`giantscorpion`) | volcano | done | `nido_del_escorpion` (0.5.157) | `caldera_roja` | `astilla_escorpion` | `obsidiana` (boss), `volcan_1` |
| Mother Mole | meadow | — | — | — | — | — |
| Supreme Gust «Tifón» (`tifon`) | fortress | — | — | — | art `astilla_tifon` (no entry yet) | `tifon` (boss) |

The Groove's disco ball has six splinters: Mega Crabby's crown, Mega Gloomy's amulet and four more. **A splinter entry
must never be added to `assets/story/collectibles.json` before its boss is playable in the story** (the Groove's gate
would become impossible).

Proposed order: 1) finish the Queen and the Scorpion (only levels, exits and entries are missing), 2) Mother Mole,
3) Tifón. **The user (2026-11-04): Tifón goes before the Mother Mole**, visuals and sounds first: [tifon](tifon.md). Each new fight reuses existing systems; nothing here needs a new engine feature.

## 1. Carnivorous Queen — DONE (0.5.157; see story-mode § secret exits)

- **Secret exit:** `templo_de_los_pesos`: a fake wall high behind the big scale. Load the other pan with two boxes and
  ground-pound: the catapult throws you through it (HardLaunch already stuns into ceilings: the hole must be a clean gap).
- **Lair `jardin_de_la_reina`:** the test arena dressed as an overgrown temple room, a short run-up with two Carnivorous
  Plants and a bomb crate before the zone (bombs are her weak spot: the player must learn to carry them in).
- **Piece:** dewdrop flower (art done). Splinter entry + map node + its scene on the map.

## 2. Triple Strike Scorpion — DONE (0.5.157; the lavafall became a curtain of FAKE lava: there is no switchable lava)

- **Secret exit:** `caldera_roja`: behind a lavafall that a timed ground pound on a hidden ON/OFF block stops for 3 s.
- **Lair `nido_del_escorpion`:** an obsidian cave over lava; a small Scorpion on the way (the lore rule: the boss is its
  grown-up version).
- **Piece:** the clasp (art done). Entry + node + scene.

## 3. Mother Mole — meadow (new)

A giant version of the Mole (`mole`) that already digs through soft ground and stops at stone (`EXTRA_DIG` per island).

- **Unlock:** `pradera_explosiva`: a cracked wall that only a bomb thrown at the right height opens; behind it, a burrow
  going down (the secret exit).
- **Lair `madriguera_madre`:** a wide burrow of soft dirt with patches of hard rock; half-dark, lit by the splinter in her
  miner's helmet when she surfaces (the dark-levels light system: you SEE where she comes up).
- **Moves (telegraphed, never lying):**
  - **Hunt:** she swims under the ground; a trail of trembling dirt shows where she is going.
  - **Burst:** she stops under your last position, the ground bulges for 0.8 s, then she bursts up: −1 and a launch.
  - **Mounds:** she leaves dirt mounds behind that block the way like walls for a few seconds (and then crumble).
  - **Rockfall:** when she rams a wall of the arena, stones fall from the ceiling where shadows appear.
  - **Pups:** normal Moles as reserve minions (the boss summons system).
- **Weak spots (two ways):** 1) a ground pound right over her trail pops her out dizzy (window: stomp 1 / ground pound 2);
  2) lure her into a hard-rock patch: she cannot dig it, bumps her head and stays out dizzy (the stone rule of the Mole).
- **Phase 2 (half health):** sinkholes: parts of the dirt floor collapse into pits, the arena gets smaller and the rock
  patches matter more; she digs faster and bursts twice in a row.
- **Piece:** miner's helmet, the splinter as its lamp.

## 4. Supreme Gust «Tifón» — fortress (new)

A giant storm cloud: the Gust (`gust`) grown huge, built on Push (wind), boxes, bombs and the lightning of the dark levels.

- **Unlock:** `taller_trampas`: a hidden chimney; a Gust's wind lifts you onto the roof, where the secret exit hides
  among the chimneys.
- **Lair `tejados_del_tifon`:** the fortress roofs under an open stormy sky, chimneys as cover, loose boxes and bomb crates,
  and gaps between roofs (falling = a life).
- **Moves:**
  - **Blow:** streaks show the direction for 1 s, then 2-3 s of strong wind across the whole arena: it pushes you, the
    boxes, the bombs and the enemies (Push). Stand behind a chimney or a box to hold your ground.
  - **Inhale:** it sucks everything towards its mouth for 2 s.
  - **Lightning:** marks on the roof tiles, then strikes (−1); in phase 2 they chain along the metal chimneys.
  - **Hail:** small damage from above; ledges and boxes shelter you.
- **Weak spot:** while it INHALES, a LIT bomb thrown into the stream is swallowed and explodes inside: Tifón collapses onto
  the roof dizzy (stomp 1 / ground pound 2). An unlit bomb or a box is coughed back at you (a projectile). So the
  player must light the bomb (throwing lights it) at the right moment.
- **Phase 2:** it spins: the wind changes direction mid-blow (the streaks warn of the swap) and some roof tiles break.
- **Piece:** weather vane, the splinter as the arrow's tip.

## Decisions (the user, 2026-11-03: "Me parece bien, primero termina de implementar por completo a los bosses secretos que ya están completos")

The order and the two new designs were accepted. Still to decide:

1. The order (Queen → Scorpion → Mole → Tifón)?
2. The two new designs: as they are, or changes?
3. The secret exits proposed for the Queen (scale catapult) and the Scorpion (lavafall)?
4. Music: each new lair needs its theme (per the user's rule, composed by a clean-context agent).
