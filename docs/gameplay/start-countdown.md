# Start countdown (3, 2, 1, GO!)

Every level starts with a countdown so the player has time to react: **3, 2, 1, ¡YA!**. While it runs EVERYTHING is
frozen — player, enemies, traps, water, the level clock, the auto-scroll camera — and the player cannot control the
character. It applies to single player (story, Free Play, bonus matches, editor playtest) and to online rounds. The
menu background demo has none.

## Files

| File | What |
|---|---|
| `src/world/systems/StartCountdown.lua` | shared: `TIME` (3 s), `GO_TIME` (0.8 s the GO! stays), `ticks(tickDt)` (server), `beeps(prev, rem)` (the sound of each number and of GO) |
| `src/ui/BossHud.lua` | `drawStartCountdown(rem)`: the big pixel-font number (enters big and shrinks), then GO! in green fading out |
| `assets/sounds/ui/count_tick.wav`, `count_go.wav` | the sounds (`countTick`, `countGo`), written by `tools/sounds/ui.py` |

## Single player / server / client

- **Single player** (`AdventureState`): `self.startCd` = seconds left. While > 0, `update` only advances the camera
  (snapped to its target on the first frame: `camSnap`) and returns — nothing else updates. Then `startGoT` runs the
  GO! for `GO_TIME`. Pause still works.
- **Server** (`server/main.lua`): `sim.startTicks = StartCountdown.ticks(TICK_DT)`. In `stepRoom`, while
  `sim.tick <= startTicks` the inputs are drained and acknowledged (`drainFrozenInputs`) but nobody steps, the
  entity history is still recorded, and nothing else runs. Floods use `(tick - startTicks) * TICK_DT` as their time.
  `startTicks` travels in `game_init` as `cd`.
- **Client** (`OnlineAdventureState`): the time left is `(startTicks - snapBuf.clock) * TICK_DT`
  (`_startRemaining`); while > 0 the level visuals, level clock and floods don't advance. The prediction numbers and
  sends every input, but `Predictor:tick(bits, frozen)` doesn't move the player for inputs the server will still
  process frozen (`_startFrozenAhead`: clock + ping < startTicks, like the floods estimate); those history entries
  are skipped on replay too. An old server (no `cd`) means no countdown. Protocol v64.

## Auto-scroll

The auto-scroll's own countdown (`autoScroll.countdown`) no longer runs at level start: on its first update after
the start countdown, if every player is inside the window it goes straight to `run` (`cdSkip`; the `scroll_start`
event is `quiet` — no second GO! banner). Its own countdown only happens if someone was still outside the window
(online). The Mirror chase laughs when the run starts instead of during that countdown.

## Tests

`story_flow` (`entrar`: the map's iris transition, the countdown running with the player still and the level clock at
0) and `online_smoke` (the countdown exists and the own player doesn't move during it). Harnesses that measure a
level for fixed seconds skip it (`perf`: `st.startCd = nil`) or count after it (`tool_editors FLOW=runtime`).

## History and decisions

- 0.5.36 (2026-10-26): added at the user's request ("un sistema genérico de cuenta atrás para que el jugador tenga
  tiempo de reacción… todo congelado… también para el modo online"). Before, only auto-scroll levels had a countdown,
  and players could move during it. Not judged by a person yet (feel, timing, sound).
