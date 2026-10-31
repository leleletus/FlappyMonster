> **Archived design document.** Status: USED for the frozen levels; a reusable template for briefing level agents.
> Copied unchanged on 2026-10-31 from `FlappyMonster_pruebas/islas_heladas/brief_niveles.md`. It records what was proposed and decided at the time: the system pages win where they differ, and paths or ids below may be out of date.

# Shared brief for the frozen level agents

Repo: /home/mtvemo/FlappyMonster (LÖVE 11 pixel-art platformer, story mode).

## Read first
- CLAUDE.md. Obey it strictly:
  - Level tools are dangerous: `tools/levelgen/build.py` ONLY with `--only <your_level>`; `tools/levelgen/retheme.py` ONLY with your level name.
  - Tests only via `tools/tests/run.sh`, always with `timeout 300`, never `run.sh all`.
  - Never leave LÖVE processes running.
  - Spanish comments; player-facing text in both es/en.
  - Untracked root files are the user's.
  - Don't commit and don't bump versions.
- The approved design for all frozen levels: /home/mtvemo/FlappyMonster_pruebas/islas_heladas/diseno.md, including the user's verdict at the end.
- A finished example of a full level job: the jungle levels.
  - Builders: `tools/levelgen/levels_jungle_1.py` … `levels_jungle_4.py`, `levels_jungle_bonus.py`.
  - How to use the builder, solver and retheme: their docstrings and docs/levels/ (generator-and-solver.md, level-format.md, retheme.md, editor.md).
- docs/art/background-plane.md.
- The resources you MUST use (all in the game since 0.5.101; read their docs):
  - **Iceberg** (`iceberg`), **freezing water** (flood prop `cold` / level key `coldWater`), **tide** (flood `control='tide'`): docs/gameplay/water-and-floods.md, carry-and-push.md.
  - **Avalanche chute** (`avalanche`) and **cable car** (`cablecar`): docs/entities/traps-and-mechanisms.md.
  - **Penguin** (`penguin`, Frozen Coast only, rideable sled when stomped) and **Snowball** (`snowball`, Frozen Mountains, launches and shoves): docs/entities/enemies.md.
  - The existing icy enemies (icy Gummy / Crabby, Gust, Blizzard, cryo freezer, spikefall, thin ice).
  - The **frozen tile pack** (ids 50-58) and the continuous snow/ice: docs/gameplay/tiles-and-blocks.md, "Frozen pack".
  - Backgrounds:
    - `snow` (Frozen Mountains) with retheme theme `snow`.
    - `frozen_coast` (Frozen Coast) with retheme theme `frozen_coast`, its decorations `frozen_coast_set`, aurora at night.
  - Music:
    - Mountains: `montana_1`, `montana_2`, `montana_bonus`.
    - Coast: `nieve_1`, `nieve_2` (`nieve_bonus` belongs to the existing coast bonus).

## House rules for a story level
- About 150-170 tiles wide (unless the design says otherwise; auto-scroll ≤ 11 rows).
- 2 checkpoints, 3 stars (one hidden), food like the other islands.
- Difficulty in story order.
- Original structure: "si todo es igual, nada nunca será nuevo".
- Decorate with retheme, plus the background plane where it helps.
- Use the frozen pack tiles for structures and backdrops.

## Checks
- `level_check` must end TODO OK.
- `level_solve` must reach the finish with the real physics. Use solver variants for mechanics it can't model, as the jungle agents did; delete the variants afterwards.
- Capture the whole level and each section to /home/mtvemo/FlappyMonster_pruebas/niveles_helados/<level_id>/.
- Finish with `run.sh docs_reference`.

## Shared files
Other level agents work in the same tree at the same time.
- Add your module to build.py's module list with ONE small Edit; never rewrite the file.
- Add your level to retheme.py's THEMES / time table the same way.
- Never touch other levels or other builders.
- Online tests share port 22122: if `online_smoke` reports a port clash, wait and retry.
- Do NOT add your level to `src/story/Worlds.lua`; the integrator does that.

## Final report
Short English:
- the level as built, section by section;
- changes from the design, and why;
- check result lines;
- captures;
- what needs the user's eye.
