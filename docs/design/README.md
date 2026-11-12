# Design documents

Proposals, plans and the user's design decisions, kept so they are never lost outside the repo. **Any design written
for the user goes here from the first draft** (or next to its system, if it is that system's page); only previews
(images, audio) go to `FlappyMonster_pruebas/`.

When asked "what did we plan / save for later", read the **Open** table first, then [pendientes](../pendientes.md) and
[known-debt](../architecture/known-debt.md). When a proposal is built, move it to the archive with its status on top
and describe the real thing in the system's page.

## Open (not built)

| What | Page |
|---|---|
| **Damage sources (2026-11-13):** every hit carries what did it and which part ("Pufferfish spike" vs "Pufferfish projectile"), single player / server / client; the death message reads it instead of guessing (**built 0.5.205**) | [damage-sources](damage-sources.md) |
| **Level intro card (2026-11-12):** title card before the level over a live scene (the level's background, the real monster and the island's enemy), island-coloured bands, number plate; the server waits for everyone to load (**built 0.5.202-203, approved by the user 2026-11-13**) | [level-intro-card](level-intro-card.md) · [plan](level-intro-card-plan.md) |
| **UX round (2026-11-11):** items 1-6 built (0.5.200-201), HUD layout pass and death message built (0.5.204), damage sources built (0.5.205); next: touch controls editor | [ux-round-2026-11](ux-round-2026-11.md) |
| **The tutorial level (2026-11-10):** every mechanic, signs with prompts, teach the verb not the trick (being built) | [tutorial-level](tutorial-level.md) |
| **Game feel, structure and performance round (2026-11-10):** variable jump, coyote time, rumble, dust, camera lead, boss file split… (hit-stop waiting, off-screen arrow rejected) | [gamefeel-round-2026-11](gamefeel-round-2026-11.md) |
| **Flappy levels need work (the user, 2026-11-10):** the first zone's attack, cages, power-ups, wheel and boss are built, but its levels are too short, weak and easy | [flappy-prequel](flappy-prequel.md) |
| **Menu background:** when there are many Flappy levels, the menu bot should also play Flappy levels (the user, 2026-11-08) | [flappy-prequel](flappy-prequel.md) |
| **Flappy Plan 4b (2026-11-08):** power-ups, inventory per slot, the quick wheel, cages give power-ups | [flappy-plan-4b-powerups](flappy-plan-4b-powerups.md) |
| **Flappy Plan 4 (2026-11-08):** charge, special attack, caged flappies, cracked walls, zone food, Flappy HUD | [flappy-plan-4-attack-and-cages](flappy-plan-4-attack-and-cages.md) |
| **Flappy Plan 3, the campaign frame (2026-11-07):** step-by-step implementation plan (shared save core, Flappy slots, zone map, CONTINUE by mode); roadmap of all plans in the prequel page | [flappy-plan-3-campaign-frame](flappy-plan-3-campaign-frame.md) |
| **The Flappy prequel campaign (2026-11-04):** 6 zones, the Evil Monster's machines, special attack, caged flappies, Adventure locked behind it, debug menu; online rules | [flappy-prequel](flappy-prequel.md) |
| **Power-ups and the quick wheel (2026-11-07):** inventory per mode (6 max, 3 per type), shield, strength, extra heart, three magnets, small (Flappy) / big (Adventure), from cages and map shops; wheel for touch, pad and PC | [powerups](powerups.md) |
| **The working plan of 2026-11-02:** online bugs, carrying, ground pound, editor, options, tests | [backlog-2026-11](backlog-2026-11.md) |
| **Finishing the secret bosses (2026-11-03):** Queen, Scorpion and Tifón done; the Mother Mole is left | [secret-bosses-plan](secret-bosses-plan.md) |
| Tifón's looks and sounds (2026-11-04): look (Remolino shape, Nubarrón colours, ×6), sounds and music B; **built and in the story (0.5.159)** | [tifon](tifon.md) |
| 4 future secret bosses: Mother Mole, Carnivorous Queen, Supreme Gust, Triple Strike Scorpion (at least 3 needed) | [bosses/future-secret-bosses](../bosses/future-secret-bosses.md) |
| The Carnivorous Queen's looks (A chosen, built) | [carnivorous-queen](carnivorous-queen.md) |
| Groove Crab's rhythm duel, Friday Night Funkin' style: charts, balance, risks (built) | [groove-rhythm-duel](groove-rhythm-duel.md) |
| Bosses still waiting for the user's verdict, the Giant Hopper's own theme | [bosses/new-bosses-plan](../bosses/new-bosses-plan.md) |
| Level review: where to put Gusts, reworks, new levels | [levels/level-review-2026-10](../levels/level-review-2026-10.md) |
| Flying in replayed levels after the ending (future idea, not to build yet) | [story/story](../story/story.md) |

## Archive (built or decided; the system pages win where they differ)

| Document | What it holds | Status |
|---|---|---|
| [settings-menu-rework](settings-menu-rework.md) · [settings-menu-plan](settings-menu-plan.md) | the settings screen rebuilt: tabs, rows, switches, checkered background, the gear | built (0.5.197) |
| [secrets-design](archive/secrets-design.md) | cannons, splinters, secret exits, the Collection, the pieces each crab wears | built (0.5.111) |
| [secrets-lore-analysis](archive/secrets-lore-analysis.md) | endings, the flap problem, options weighed and the user's decisions | decided |
| [frozen-islands-design](archive/frozen-islands-design.md) | iceberg, cold water, tide, avalanche, cable car, levels, the user's verdict | built |
| [frozen-levels-brief](archive/frozen-levels-brief.md) | the shared brief given to level agents: reusable template | used |
| [frozen-coast-background](archive/frozen-coast-background.md) | background A against B and the final mix | applied |
| [frozen-tiles](archive/frozen-tiles.md) | continuous snow / ice, tiles 50-58, snow seam, where to place them by hand | applied; placements not tracked |
| [jungle-levels-design](archive/jungle-levels-design.md) | the jungle's four levels and bonus as proposed | built (0.5.99) |
| [snowball-boss-plan](archive/snowball-boss-plan.md) | the Big Snowball's full original plan | built (3.20.0), with changes |

The archive is history: `project_check` does not check its paths, and it is not rewritten when files move.

## Left outside the repo on purpose

Notes that only explain the audio previews sitting next to them; the decisions are in
[music-history](../audio/music-history.md). All in `FlappyMonster_pruebas/` unless noted:

| Note | About |
|---|---|
| `musica_jefes_helados/LEEME.txt`, `crab_v4_capas/LEEME.txt` inside it | icy bosses on the GM cast, versions and numbers, one file per instrument |
| `musica_correcciones/LEEME.txt` | the snowfall on time and the echo, before / after |
| `musica_montanas/LEEME.txt`, `musica/jungla/LEEME.txt` | the Mountains and jungle sets, variants to pick from |
| `musica/crab_mashup/LEEME.txt`, `musica/final_fall/LEEME.txt` | the Mashup's section map, Final Fall's versions (archived track) |
| `musica/revision_3.99.1/`, `musica/revision_3.99.2/` (a `LEEME.txt` per track) | the music review of 2026-10-19 |
| `musica/pradera_1_capas/LEEME.txt` | `pradera_1` split into layers |
| `FlappyMonster_originals/herramientas_retiradas/LEEME.txt` | retired music generators and how to bring them back |
| `FlappyMonster_originals/MUDANZA_2026-10-07.txt` | old to new image folders |
| `FlappyMonster_originals/music/versiones/*/LEEME.txt` | how to recover an archived track version |

The originals of the copied documents stay in `FlappyMonster_pruebas/` next to their images; the copy in the repo is the
one to keep up to date.
