# UX round (2026-11-11)

**Status:** approved by the user; being built in this order. Each item: built, tested, committed on its own.

Proposals the user turned down this round: checkpoint feedback ("not needed"); a Flappy tutorial (not enough content
yet). Later: loading spinners on slow devices beyond item 6.

## Order and scope

1. **Restart from pause, with the life warning.** Restarting the level costs a life (so it is not spammed); the pause
   menu's RESTART asks for confirmation and says so ("you lose a life"). Single player only.
2. **Level intro card.** At the start of a story level: its name, its island and the par time, about 2 s, without
   stopping play. Works the same in single player and in the online client (from data both sides have).
3. **Collectibles in the HUD.** Stars and freed cages of the level while playing ("★ 2/3"), not only on the results
   screen. Nothing new is saved (golden rule 7: nothing counts until the level is finished).
4. **Cause of death.** No death screen exists: on respawn, a short line with an icon at the top for ~1.5 s (spikes,
   lava, drowned, an enemy's name, fell, crushed…), without pausing. Online: each client shows its own.
5. **Online lobby clarity.** Ping per room / connection, a preview of the room's level, and plain-words reasons when
   you cannot join (full, another version, already started…).
6. **Loading screen.** Black, a white running monster in the bottom-right corner and "Cargando..." with animated
   dots. Shown only when a load takes longer than ~0.2 s, so fast devices never see it.
7. **Accessibility and touch controls.** Reduce screen shake and flashes, bigger sign text, colour-blind-friendly
   hazards; on phones, the on-screen controls' size, layout and opacity. This one gets its own short design first.

## Built

1. (0.5.200) `AdventureState:retryCostsLife` / `canRetry` / `retryNow`: with lives, retrying counts as a death, saved at
   once; on the last life RETRY is not offered. `PauseState` asks first (`pause.retry_title`, `pause.retry_note`: "you
   will have N left"; cancel or back returns). Free Play and bonus games: no cost, no question. Harness `story_flow`
   `reintentar_vida`.
2. (0.5.200) `src/ui/LevelCard.lua`: name, island (`Worlds.worldOf` → `story.world.<id>`) and target time (`parTime` or
   `Score.par`) for 3.6 s in the lower third, during the countdown; single player and the online client (no target time
   there: the mode has its own clock). Not on Flappy stages, the demo or bonus target time. Harness `story_flow` `tarjeta`.
3. (0.5.200) `src/ui/CollectHud.lua`, top centre (the corners are taken): stars `n/total` and, on Flappy stages, freed
   cages (already freed in a finished run count). `AdventureState:collectedCounts`. Not in bonus games. Harness
   `story_flow` `recogido_hud`.
4. (0.5.200) `src/player/DeathCause.lua` decides at the moment of death (drowned, out of time, fell, lava, spikes, the
   nearest enemy by its `enemy.<family>` name or a boss's name, otherwise "too many hits"; `PlayerAdventure.deathFlags`
   keeps die()'s flags); `src/ui/DeathBanner.lua` shows a skull and the text for 1.8 s after respawning. Single player
   and the online client (its own player). Harness `mechanics` `causa_muerte`.
5. (0.5.201) The room list shows each room's mode and level under its name (`OnlineHubState:_roomWhat`; the server
   adds `level` / `mode` to the list — extra fields, old clients ignore them) and the connection ping bottom-left
   (`PingIcon`). Reasons for not joining were already plain words (`srv.room_full`, `srv.version`…). A minimap preview
   of the level was not added: the name and mode carry what matters. Capture `online_menus` `online_daily_hub`.
6. (0.5.201) `src/ui/LoadingScreen.lua` (art `tools/art/ui/make_loading.py`: the monster's flutter frames, all white):
   `wrap(gStateMachine)` times every change to a level state; once one takes over 0.2 s the device counts as slow and
   from then on a loading frame is drawn and presented before each level load. Fast devices never see it. Harness
   `menu_flow` `carga`, capture `menu_loading`.
