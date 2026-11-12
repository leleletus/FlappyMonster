# Level start: intro card + countdown (3, 2, 1, GO!)

Since 0.5.202 every level starts with **two phases**, defined once in `StartCountdown` and run the same in single
player, on the server and in the online client: first the **intro card** (`CARD_TIME` 5 s since 0.5.203: a title card with the
level's name, island and number over a live scene — [design](../design/level-intro-card.md)), then the **countdown**
(`TIME`: 0 since 0.5.203, to try the game without it — it was 3 s, **3, 2, 1, ¡YA!** —; only the ¡YA! remains). Neither can be skipped and there is **no pause** during either (the user). Online, before the card,
the server **waits for every player to load** the level. `TIME` can be set to 0 (card only) with nothing else
changing — the user will decide after trying it.

The countdown gives the player time to react. While it runs EVERYTHING is
frozen — player, enemies, traps, water, the level clock, the auto-scroll camera — and the player cannot control the
character. It applies to single player (story, Free Play, bonus matches, editor playtest) and to online rounds. The
menu background demo has none.

## Files

| File | What |
|---|---|
| `src/world/systems/StartCountdown.lua` | shared: `CARD_TIME` (2 s), `TIME` (3 s), `GO_TIME` (0.8 s the GO! stays); `total(card)`, `phase(rem)` → `'card'` / `'count'` / `'go'` / nil (`rem` = seconds until play starts), `ticks(tickDt, card)` (server), `beeps(prev, rem)` (the sound of each number and of GO; silent during the card) |
| `src/ui/IntroCard.lua` | the card: `new(level, id)`, `draw(card, t, { waiting })`, `rects(card)` (layout, for the overlap test). Bands slide in (level name from the left, island from the right) in the island's colours, a small plate drops left of the island band (`1-3`, `1-B` bonus, `1-?` secret — also the secret bosses —, `1-` + the world-map castle for bosses; none when the level has no story number), the island's ground strip with a decoration and an enemy, the monster (white outline) runs in and stops; while waiting it stays alive (hops, turns, band shimmer) and after 1 s extra shows `intro.waiting` with dots bottom-left |
| `src/ui/IntroScene.lua` | the LIVE scene under the card (0.5.203): a strip level written to the save folder (`intro_scene.json`) and run as an `AdventureState` in demo mode, with the starting level's sky / time / clouds / light and its most common surface tiles, the island's enemy (`Worlds.INTRO[...].enemy`, a real entity type) and the real monster with its white edge (level flag `outline`, `src/fx/Silhouette.lua`). The monster walks in from the left (its walking speed scaled to the screen width, `CROSS` 4.4 s) and leaves on the right; at the enemy, at random: jumps over it, stomps it or gets hurt. Real animations and sounds. `hold` (online, while the server waits): it stops at `HOLD_AT` of the width. Nothing counts for the real level (`Entity.onKill` off, hit-stop cleared, globals given back with `restore`); `finish()` clears its particles and the file |
| `src/story/Worlds.lua` | `Worlds.plate(id)` (the number) and `Worlds.INTRO` / `INTRO_DEFAULT` / `introOf(id)` (each island's band colours, tiles, decoration, enemy frames) |
| `tools/art/ui/make_intro_card.py` | the card art in `assets/images/ui/intro/` (outlined monster, band piece + cap, plate) |
| `src/ui/BossHud.lua` | `drawStartCountdown(rem)`: the big pixel-font number (enters big and shrinks), then GO! in green fading out |
| `assets/sounds/ui/count_tick.wav`, `count_go.wav` | the sounds (`countTick`, `countGo`), written by `tools/sounds/ui.py` |

## Single player / server / client

- **Single player** (`AdventureState`): `self.introCard` (not the demo, not an editor playtest, not a Flappy stage;
  RETRY and restarts re-enter the state and show it again; checkpoint respawns don't) and `self.startCd =
  StartCountdown.total(self.introCard)` = seconds left. While > 0, `update` only advances the camera (snapped to its
  target on the first frame: `camSnap`) and returns — nothing else updates. During the `'card'` phase `render` draws
  the card INSTEAD of the level (and no touch controls). Then `startGoT` runs the GO! for `GO_TIME`. `startPhase()`;
  `pauseGame()` and the pause input do nothing in the card and countdown phases (`_startLocked`). The level music
  starts on entering the state, so it starts with the card. The card fades to black in its last `IntroCard.FADE_OUT`
  s and the level comes out of black in `FADE_IN` s UNDER the HUD (`IntroCard.drawFadeIn`, `afterCardT`): the ¡YA!
  is never covered (the user). The online client does the same.
- **Server** (`server/srv/sim.lua`): `sim.startTicks` is nil while it WAITS: every player of the room at the start
  (`sim.waitFor`) must send `level_loaded` (the client does it at the end of `_onGameInit`; `server/srv/lobby.lua`),
  unless they disconnect or leave / are kicked (no `playerSims` entry); or the wait ends 8 s after the first `level_loaded` or 20 s after `game_init`
  (`S.startWaitOver`). Then `startTicks = tick + StartCountdown.ticks(TICK_DT, true)` and `round_start { start }` goes
  to the room. While waiting and until `startTicks` the inputs are drained and acknowledged (`drainFrozenInputs`) but
  nobody steps, the entity history is still recorded, and nothing else runs. Floods use `(tick - startTicks) *
  TICK_DT` as their time. `game_init` carries `start` (nil while waiting) and `card` (its ticks).
- **Client** (`OnlineAdventureState`): `waitingStart` until `round_start` (or `start` in `game_init`); the time left is
  `(startTicks - snapBuf.clock) * TICK_DT` (`_startRemaining`; while waiting, more than the whole start: the `'card'`
  phase); while > 0 the level visuals, level clock and floods don't advance. `_cardShowing()` draws the card instead of
  the level; its animation time is local (`cardT0`), its LENGTH is the server clock. `_introWaiting()` = seconds of
  wait past the card's normal end. Late joiners and players who arrive after the card phase get no card. The
  pause / leave overlay can't be opened during the card and the countdown (a spectator's overlay can). `round_start`
  is kept in `NC.pendingRoundStart` (like `game_init`) and checked every frame while waiting (`_checkRoundStart`), so
  one that arrives before the state listens is not lost; if the server clock passes the longest possible wait without
  it, the client stops waiting anyway. Editor playtests pass `fromEditor` (kept on retry): no card. The prediction numbers and
  sends every input, but `Predictor:tick(bits, frozen)` doesn't move the player for inputs the server will still
  process frozen (`_startFrozenAhead`: clock + ping < startTicks, like the floods estimate); those history entries
  are skipped on replay too. Protocol v64 (countdown), v117 (wait + card).

## Auto-scroll

The auto-scroll's own countdown (`autoScroll.countdown`) no longer runs at level start: on its first update after
the start countdown, if every player is inside the window it goes straight to `run` (`cdSkip`; the `scroll_start`
event is `quiet` — no second GO! banner). Its own countdown only happens if someone was still outside the window
(online). The Mirror chase laughs when the run starts instead of during that countdown.

## Tests

`mechanics` `inicio_fases` (phases, totals, beeps only in the countdown, `TIME` = 0). `story_flow`: `tarjeta` (the card
before the countdown, the level not drawn, the plate, Free Play without plate, the longest level name at 960 / 1280 /
1600 with nothing overlapping; captures `story_intro_<level>_<width>.png`), `placas` (`Worlds.plate`, every island's
look loads), `sin_pausa_inicio` (any button every frame during card + countdown: no pause, no movement; pause works
after GO). `online_smoke` `espera_carga` / `tarjeta_online` (bot loads at once, `DELAYLOAD=4`, `NOLOAD=1`,
`QUITLOAD=1`). Also `story_flow` (`entrar`: the map's iris transition, the countdown running with the player still and the level clock at
0) and `online_smoke` (the countdown exists and the own player doesn't move during it). Harnesses that measure a
level for fixed seconds skip it (`perf`: `st.startCd = nil`) or count after it (`tool_editors FLOW=runtime`).

## History and decisions

- 0.5.36 (2026-10-26): added at the user's request ("un sistema genérico de cuenta atrás para que el jugador tenga
  tiempo de reacción… todo congelado… también para el modo online"). Before, only auto-scroll levels had a countdown,
  and players could move during it. Not judged by a person yet (feel, timing, sound).
- 0.5.37: the monster showed half sunk into the ground during the countdown and popped up when it ended (the user).
  Cause: `Level:getSpawnPx` is the CENTRE of the start cell and the monster's box reaches more than half a cell
  below it; the first physics step pushed it out, and the countdown now held that first frame for 3 s.
  `PlayerAdventure:settle(level)` puts the feet on the ground below (same top face as the landing in
  `moveAndCollide`); called when the player is created in `AdventureState` and in the server's `initRoomSim` (the
  client gets it in `game_init`). `story_flow` `apoyado`: the first step after the countdown moves it 0 px.
- 0.5.202 (2026-11-12): the **intro card** before the countdown (the user: "like the classic platformer title cards",
  a black screen made of real assets, the island, the level name and its number "1 - 3"). Chosen from mockups: the
  sliding bands of one idea + the island strip with the running monster of another; the number on a small plate left
  of the island band; band colours per island (the user). The user's rules: about 2 s, it CANNOT be skipped, no pause
  during the card nor the countdown, shown in story and Free Play and online, no number when it is not known, bonus
  `w-B`, secret `w-?` (also for the secret bosses), bosses `w-` + the castle (my recommendation, accepted). "Fix it for
  real" online (the user rejected letting the card just cover part of the old 3 s freeze): one start sequence, the
  server waits for everyone to load (the user: with a limit; the card IS the waiting screen and must stay alive, with
  "Esperando jugadores..." bottom-left if it takes long). The countdown stays as it was until the user tries it (they
  may remove it). Not judged by a person yet (looks, timing, feel).
- 0.5.203 (2026-11-12): the user: instead of the black background and the hand-animated monster and enemy, "the level's
  own background, and the monster and the enemy walk, animate and sound as in a real level" (with the game's own white
  edge, not my hand-drawn one): `IntroScene`. The monster walks in from the left and leaves on the right, jumping over,
  stomping or being hurt by the enemy; online it waits on screen while the server waits and leaves when the start
  comes. Card 5 s (the user: "neither" 5.3 nor 4.3 s — the walk is scaled to the width to fit), countdown 0 to try it
  ("just to test"), a fade to black and back into the level without covering the ¡YA! (the user). Protocol 118.
  The user tried it (2026-11-13): approved and closed, with the countdown at 0.
