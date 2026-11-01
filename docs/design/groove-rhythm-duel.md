# Groove Crab: the rhythm duel (proposal)

**Status: proposal, nothing built.** The user's idea (2026-11-01): a Friday Night Funkin' style micro-game inside the Groove Crab's fight. The player stands still, the crab keeps dancing, 4 arrows appear and the song's exact notes scroll to them. The user asked for an opinion and a balance plan. Fight today: [groovecrab](../bosses/groovecrab.md).

## What was measured (`tools/music/groove_mejora.py`, variant B, the installed one)

- 150 BPM, so a sixteenth is 100 ms.
- **The attacks are NOT out of sync:** 61 of the 62 note shots in sections B, C and D land on a bass pop (the other: D bar 16, sixteenth 14, on a normal note). Every bar has a bass note on sixteenth 0, where hops land. No global re-sync is needed.
- Slap bass, notes per second by section, average / busiest bar:

| Filter | A | B | K | S | C | D | O |
|---|---|---|---|---|---|---|---|
| All (1:1) | 7.5 / 8.8 | 5.4 / 8.8 | 8.5 / 10 | 7.5 / 8.8 | 6.4 / 8.8 | **9.9 / 10** | 7.7 / 8.1 |
| No ghost notes | 6.5 / 7.5 | 5.0 / 6.9 | 7.5 / 10 | 6.6 / 7.5 | 5.7 / 7.5 | 7.5 / 7.5 | 6.7 / 6.9 |

- Section D's bass is 252 gaps of one sixteenth out of 253: a 25 s run of 10 notes per second. Its hook adds 4.2 per second.

## Proposal

**When:** 8 bars (12.8 s), starting on a phrase. Always on the first half of D, so its second half, the dance floor, follows. In phase 2, also one other phrase. About 1 to 2 duels per 134 s loop. The chart covers the whole song, so the trigger can move freely.

**Entry:** one bar of warning. Hazards vanish, the player is invulnerable and frozen. If in the air, the player lands first. The crab cannot be hit during it.

**Chart by difficulty** (`window` = either side of the note; `scroll` = time on screen):

| Difficulty | Notes | Rate | Window | Scroll | Fail below | KO from |
|---|---|---|---|---|---|---|
| Easy | pops and downbeats, at least 400 ms apart | ~2 /s | ±160 ms | 1.6 s | 50 % | 70 % |
| Normal | at least 200 ms apart | ~3.5 /s | ±130 ms | 1.3 s | 60 % | 80 % |
| Hard | the user asked 1:1; see open question 1 | 5-7.5 /s | ±110 ms | 1.1 s | 65 % | 85 % |
| Extreme | 1:1 | 5.4-10 /s | ±85 ms | 0.85 s | 70 % | 90 % |
| Xtra Extreme | same chart | 5.4-10 /s | ±65 ms | 0.65 s | 75 % | 92 % |

**In D**, the hook plays over the bass; both 1:1 would be 14 notes per second. On Easy and Normal the chart follows the hook. On Hard and up, the bass.

**Lanes:** by pitch within the bar, so a rising line rises across the lanes. Repeated notes alternate between two lanes, because one lane at 100 ms is a trill no thumb sustains.

**Reward and penalty:**
- A meter starts at 50 %. A hit raises it, a miss lowers it, in the ratio that makes the "fail below" accuracy the balance point, whatever the note count.
- Meter empty: the duel ends at once and costs 1 HP, so nobody sits through 12 s of failing.
- **At most 1 HP per duel.** Easy and Normal leave at least 1 HP; Hard and up can kill. The player has 3 or 4 HP.
- **Above "KO from": the crab is knocked out, one free hit.** It is what makes the duel an opportunity, not a tax. In between: nothing lost.
- The existing crowd cheers and boos follow the meter.

## Technical risks

1. **Sync:** judge against the music's real position (`Source:tell`), not `songT`. Audio latency varies by device, so an offset setting is needed (Android above all).
2. **Online:** today everything drawn comes from snapshots. A rhythm game cannot wait for those: each client judges its own notes against its own music, and the server gets the result. That is a new message and a new `Protocol.VERSION`. Results can be faked, an accepted risk here. Each player has their own meter; a KO needs a majority.
3. **Controls:** d-pad and keyboard are fine. Analog stick is poor at this speed. Android needs 4 on-screen buttons.
4. **Golden rule 4:** arrows and judgement text are real asset files; chart data is generated and committed.

## Build

A new chart generator in the music tools reads the same `sections('B')` as the song and writes `assets/story/` chart data per difficulty, so chart and song cannot drift apart. Then a `RhythmDuel` system, the crab's state, and a harness with simulated players (timing error of 40, 70, 100 ms) to measure pass rates for the table above before anyone plays it.

## Open questions

1. Hard: all notes as asked, or no ghosts (7.5 notes per second in D against 9.9)? Claude recommends no ghosts, leaving true 1:1 to Extreme and Xtra.
2. A KO as the reward?
3. Is 8 bars right, or the whole of section D?
