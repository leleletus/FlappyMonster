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
| **The working plan of 2026-11-02:** online bugs, carrying, ground pound, editor, options, tests | [backlog-2026-11](backlog-2026-11.md) |
| **Finishing the secret bosses (2026-11-03):** what is missing for the Queen and the Scorpion, new designs for the Mother Mole and Tifón | [secret-bosses-plan](secret-bosses-plan.md) |
| **Tifón's looks and sounds (round 1, 2026-11-04):** four looks, 14 sounds, waiting for the user | [tifon](tifon.md) |
| 4 future secret bosses: Mother Mole, Carnivorous Queen, Supreme Gust, Triple Strike Scorpion (at least 3 needed) | [bosses/future-secret-bosses](../bosses/future-secret-bosses.md) |
| The Carnivorous Queen's looks (A chosen, built) | [carnivorous-queen](carnivorous-queen.md) |
| Groove Crab's rhythm duel, Friday Night Funkin' style: charts, balance, risks (built) | [groove-rhythm-duel](groove-rhythm-duel.md) |
| Bosses still waiting for the user's verdict, the Giant Hopper's own theme | [bosses/new-bosses-plan](../bosses/new-bosses-plan.md) |
| Level review: where to put Gusts, reworks, new levels | [levels/level-review-2026-10](../levels/level-review-2026-10.md) |
| Flying in replayed levels after the ending (future idea, not to build yet) | [story/story](../story/story.md) |

## Archive (built or decided; the system pages win where they differ)

| Document | What it holds | Status |
|---|---|---|
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
