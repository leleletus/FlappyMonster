# Flappy Monster — documentation

Start here. Every system has one page with the same shape: what it is · files · data and configuration · how it runs
in single player / server / client · how to extend it · its tests · history and decisions. Pages are written from
the code; the tables in `reference/` are GENERATED from the running game (`tools/tests/run.sh docs_reference`) and
are never edited by hand.

## "I want to…"

| …do this | Read |
|---|---|
| understand how the whole thing fits | [architecture/overview](architecture/overview.md), [architecture/project-structure](architecture/project-structure.md) |
| make an enemy WITHOUT code (visual editor) | [entities/enemy-editor](entities/enemy-editor.md) |
| create or edit animations (sprites, tiles, anything) | [art/animation](art/animation.md) |
| add or change an enemy in code | [entities/how-to-add-an-enemy](entities/how-to-add-an-enemy.md), [entities/overview](entities/overview.md), [entities/enemies](entities/enemies.md) |
| add or change a boss | [bosses/how-to-add-a-boss](bosses/how-to-add-a-boss.md), [bosses/system](bosses/system.md), the boss's own page |
| add a tile, a block, a trap | [gameplay/tiles-and-blocks](gameplay/tiles-and-blocks.md), [entities/traps-and-mechanisms](entities/traps-and-mechanisms.md) |
| change how the player moves or takes damage | [gameplay/player](gameplay/player.md) |
| make something carryable, pushable, blowing, a moving platform, or change by island | [gameplay/carry-and-push](gameplay/carry-and-push.md) |
| change anything that goes over the network | [architecture/netcode](architecture/netcode.md) |
| add a difficulty modifier | [gameplay/difficulty](gameplay/difficulty.md) |
| make or edit a level | [levels/editor](levels/editor.md), [levels/level-format](levels/level-format.md), [levels/generator-and-solver](levels/generator-and-solver.md), [levels/retheme](levels/retheme.md) |
| see the level review and the proposals (Gusts, reworks, new levels) | [levels/level-review-2026-10](levels/level-review-2026-10.md) |
| change the countdown at the start of every level (single player and online) | [gameplay/start-countdown](gameplay/start-countdown.md) |
| change the story order, saves, results, the Collection (collectibles screen, worn boss pieces) | [story/story-mode](story/story-mode.md) |
| change the world map | [story/world-map](story/world-map.md) |
| add a secret (secret exit, secret level, splinter, map scene) | [story/story-mode](story/story-mode.md#the-secrets-secret-exits-splinters-the-groove-and-the-mashup) |
| change a cinematic | [story/cinematics](story/cinematics.md), [story/story](story/story.md) |
| change the credits, add a credit or a license | [story/credits](story/credits.md) |
| touch the bonus matches or the bot | [story/bonus-and-bot](story/bonus-and-bot.md), [gameplay/game-modes](gameplay/game-modes.md) |
| draw or regenerate art | [art/style-rules](art/style-rules.md), [art/generators](art/generators.md) (**hand-edited list**), [art/asset-layout](art/asset-layout.md) |
| put blocks or decorations behind the level (the background plane) | [art/background-plane](art/background-plane.md), [levels/editor](levels/editor.md) § Background plane |
| add a sound, or listen to all of them (secret sound test) | [audio/sound](audio/sound.md) |
| compose or change music | [audio/music-guide](audio/music-guide.md), [audio/music-catalog](audio/music-catalog.md), [audio/music-history](audio/music-history.md) |
| add a text or a language | [architecture/i18n](architecture/i18n.md) |
| test something | [testing/harnesses](testing/harnesses.md), `tools/tests/README.md` |
| measure speed, garbage, memory leaks (client and server) | [testing/performance](testing/performance.md) |
| change the logo intro shown at boot | [architecture/startup-intro](architecture/startup-intro.md) |
| change the title, the menus (online screens included), their background or transitions | [architecture/menus](architecture/menus.md) |
| release and update the server | [architecture/updates-and-release](architecture/updates-and-release.md) |
| port, publish, change screens or controls | [architecture/platforms](architecture/platforms.md), [architecture/known-debt](architecture/known-debt.md) (Google Play readiness) |
| know what is saved | [architecture/save-data](architecture/save-data.md) |
| see what is pending (review of 2026-10-20) | [pendientes](pendientes.md) |
| the plan for the two new bosses (Giant Pufferfish, Giant Hopper) and the secret crab bosses | [bosses/new-bosses-plan](bosses/new-bosses-plan.md) |
| the script of the four-crab event boss rush with adaptive music (Free Play) | [bosses/crab-mashup](bosses/crab-mashup.md) |
| the plan for the new Gust enemy, Scale, pushable Box and Seed (design stage) | [entities/new-props-plan](entities/new-props-plan.md) |

## All pages

- **architecture/** — [overview](architecture/overview.md) · [project-structure](architecture/project-structure.md) ·
  [netcode](architecture/netcode.md) · [updates-and-release](architecture/updates-and-release.md) · [startup-intro](architecture/startup-intro.md) · [menus](architecture/menus.md) ·
  [platforms](architecture/platforms.md) · [i18n](architecture/i18n.md) · [save-data](architecture/save-data.md) ·
  [known-debt](architecture/known-debt.md)
- **gameplay/** — [player](gameplay/player.md) · [tiles-and-blocks](gameplay/tiles-and-blocks.md) ·
  [water-and-floods](gameplay/water-and-floods.md) · [dark-levels](gameplay/dark-levels.md) ·
  [difficulty](gameplay/difficulty.md) · [game-modes](gameplay/game-modes.md) · [autoscroll](gameplay/autoscroll.md) · [start-countdown](gameplay/start-countdown.md) ·
  [pickups](gameplay/pickups.md) · [free-play](gameplay/free-play.md) · [flappy-mode](gameplay/flappy-mode.md)
- **entities/** — [overview](entities/overview.md) · [enemies](entities/enemies.md) ·
  [traps-and-mechanisms](entities/traps-and-mechanisms.md) · [enemy-editor](entities/enemy-editor.md) ·
  [how-to-add-an-enemy](entities/how-to-add-an-enemy.md)
- **bosses/** — [system](bosses/system.md) · [megagummy](bosses/megagummy.md) · [giantpuffer](bosses/giantpuffer.md) · [gianthopper](bosses/gianthopper.md) · [giantbeetle](bosses/giantbeetle.md) · [groovecrab](bosses/groovecrab.md) · [crab-mashup](bosses/crab-mashup.md) · [megacrabby](bosses/megacrabby.md) ·
  [miniboss1](bosses/miniboss1.md) · [snowboss](bosses/snowboss.md) · [megacrabby-ice](bosses/megacrabby-ice.md) ·
  [megagloomy](bosses/megagloomy.md) · [mirror](bosses/mirror.md) · [mirror-chase](bosses/mirror-chase.md) ·
  [how-to-add-a-boss](bosses/how-to-add-a-boss.md)
- **story/** — [story](story/story.md) · [story-mode](story/story-mode.md) · [world-map](story/world-map.md) ·
  [cinematics](story/cinematics.md) · [credits](story/credits.md) · [bonus-and-bot](story/bonus-and-bot.md)
- **levels/** — [level-format](levels/level-format.md) · [editor](levels/editor.md) ·
  [generator-and-solver](levels/generator-and-solver.md) · [retheme](levels/retheme.md)
- **art/** — [animation](art/animation.md) · [style-rules](art/style-rules.md) · [asset-layout](art/asset-layout.md) · [generators](art/generators.md) ·
  [sky-and-biomes](art/sky-and-biomes.md) · [decorations](art/decorations.md) · [fx-and-particles](art/fx-and-particles.md) ·
  [background-plane](art/background-plane.md)
- **audio/** — [sound](audio/sound.md) · [music-catalog](audio/music-catalog.md) · [music-guide](audio/music-guide.md) ·
  [music-history](audio/music-history.md)
- **testing/** — [harnesses](testing/harnesses.md) · [performance](testing/performance.md)
- **tools/** — [ost-videos](tools/ost-videos.md)
- **reference/** (generated) — [entities](reference/entities.md) · [tiles](reference/tiles.md) ·
  [decorations-and-modes](reference/decorations-and-modes.md) · [levels](reference/levels.md) · [music](reference/music.md)

## Glossary (names in code and data vs what they are)

Ids are data (level files, saves, network), so confusing ones are explained here instead of renamed.

| In code / data | What it is |
|---|---|
| `pa`, `PlayerAdventure` | a player body in Adventure (also the bot's and the Mirror's) |
| `monstrito` (sprites) | the monster, the player character |
| Gummy / Crabby / Gloomy / Hopper (Saltarín) | the regular enemy families |
| `miniboss1`, "Nave Malvada" | the Evil Ship boss (with the Evil Monster as pilot) |
| `megagummy`, "Rey Gummy" | the Gummy King |
| `snowboss`, "Gran Bola de Nieve"; music id `snowball_boss` | the Snowball Boss; Verity = its Easter-egg look |
| `megagloomy`, "Mega Crabby lúgubre" | the Mega Gloomy Crabby |
| `gianthopper`, "Saltarín Gigante" | the Giant Hopper (the caves boss) |
| `mole` "Topo" · `piranha` "Piraña" · `carnivoreplant` "Planta carnívora" | the 0.5.96 enemies: the mole of every island, the jungle's piranha and carnivorous plant ([enemies](entities/enemies.md)) |
| `penguin` "Pingüino" | the Frozen Coast's penguin: waddles, belly-slides, stomped it is a SLED you ride (generic `base/Sled.lua`) ([enemies](entities/enemies.md#penguin-penguin-pingüino--frozen-coast)) |
| `giantbeetle`, "Escarabajo Rinoceronte Gigante" | the Giant Rhino Beetle (the jungle boss; the small one: `beetle`) |
| `groovecrab`, "Groove Crab" (Cangrejo Groove; "El Groove" until 0.5.54); music id `groove` | the secret boss after the game (a fiddler trampoline crab that fights to its music) |
| `mirror` / `mirrorchase`, "el Reflejo" | the Mirror boss (the Reflection) / its chase before the fight |
| `cryo`, "Congelador" | the Freezer trap |
| `avalanche` "Alud" · `cablecar` "Teleférico" | the Frozen Mountains' snow chute trap and the generic cable car platform ([traps-and-mechanisms](entities/traps-and-mechanisms.md)) |
| `door` "Puerta" | a solid door that opens when its linked ON/OFF Activator fires (or its boss zone is won), per-island art ([traps-and-mechanisms](entities/traps-and-mechanisms.md#door-puerta-2026-10-29)) |
| tile `solid` | stone ("Piedra"); `border` = very hard rock; `danger` = LAVA; `hidden_block` = invisible block |
| `switch_on/off` | ON/OFF Activator; `switchblock_*` = ON/OFF Blocks |
| level key `foliage` | decorations |
| `pointarea`, "zona de puntos" | King-of-the-Hill point zone |
| GP | ground pound |
| KOTH, `koth` | King of the Hill |
| worlds `pradera`, `costa`, `jungla`, `fortaleza`, `nieve`, `costa_helada`, `cuevas`, `final` | Meadow, Coast, Jungle, Fortress, Frozen Mountains, Frozen Coast, Caves, Volcano |
| "la llamada" | the game's musical leitmotif (the opening of the map tune) |
| "fragmento" / shard | one of the mirror shards (8 today: one per boss + the Mirror's; catalog `assets/story/shards.json`) |
| Xtra Extreme (`xtra`) | the top difficulty: one boss per arena, enraged from the start (two bosses per arena until 0.5.24) |
| arnés | a test harness in `tools/tests/` |
| `FlappyMonster_originals/`, `FlappyMonster_pruebas/` | folders OUTSIDE the repo: the user's original art / audio and archived tools; previews for the user |
