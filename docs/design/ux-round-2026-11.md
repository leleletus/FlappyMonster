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
2. (0.5.200; replaced in 0.5.202 by the [level intro card](level-intro-card.md)) `LevelCard` (removed): name, island (`Worlds.worldOf` → `story.world.<id>`) and target time (`parTime` or
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

## Next (written down 2026-11-12, at the user's request; not started)

- **Item 7, touch controls:** the user chose FREE placement — on an edit screen each on-screen button is dragged
  wherever the player wants — plus size and opacity sliders. The rest of item 7 as above (reduce shake / flashes,
  bigger sign text, colour-blind-friendly hazards).
- **HUD layout pass (the user found it) — BUILT 0.5.204, [hud](../architecture/hud.md):** the death message sits right against the score counter, and during a boss
  fight the boss health bar covers the score completely. Every HUD element must have its own place, nothing on top of
  anything else, at every resolution (960 / 1280 / 1600, phones with bands): score and time, lives, light, collectibles
  (top centre), the level card, the death message, the boss bar and its player bars, the Flappy HUD and bag, the
  pause button, the countdown, online mode banners. Make a harness that draws them all together and checks their
  rectangles do not overlap.
- **Death message placement — BUILT 0.5.204 (left, under the top HUD):** move it somewhere it does not get in the way (it now sits top centre, under the
  collectibles, against the score).
- **Online instruction banners (to CHECK) — CHECKED 0.5.204: no overlap once placed under the HUD; they were never seen since the intro card (fixed):** the mode's how-to-play banners sit top centre and
  have sizes per resolution; the user suspects they could collide like the score did. Check them in the HUD pass;
  only if they collide: show them for the first seconds of a match and then hide them, and/or make them available
  from the pause menu.
- **Damage SOURCES (the user: "worth it") — BUILT 0.5.205, [damage-sources](damage-sources.md):** every hit records exactly what caused it, so the cause of death is certain
  instead of guessed from the surroundings: a spike tile vs a falling spike vs a Crabby's spike vs a pufferfish's spike
  vs a pufferfish's projectile, lava, a boss's attack by name, explosions, crushing, etc. The source travels with the
  damage (`hurt` / `die` / `hazardHit` get a source descriptor; hazard boxes and entities attach theirs) in single
  player, on the server and in the online client; `src/player/DeathCause.lua` then reads the last source instead of
  guessing, and the death message names it.

