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

