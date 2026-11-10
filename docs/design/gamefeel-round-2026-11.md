# Game feel, structure and performance round (2026-11-10)

Proposed to the user on 2026-11-10 after the optimisation round (0.5.182-0.5.187). **The user's verdict:** apply
everything except the hit-stop (only if it is explained well) and the off-screen arrow (rejected).

| # | What | Status |
|---|---|---|
| 1 | Variable jump height (releasing jump early cuts the jump) | built 0.5.188 ([player](../gameplay/player.md)) |
| 2 | Hit-stop (2-4 frozen frames on hits) | built 0.5.188 (ground pound, boss hits, damage, death); **0.5.189: only on dying**, the user did not like it on ground pounds ([player](../gameplay/player.md)) |
| 3 | Controller vibration (pound, hits, explosions, boss stomps) | built 0.5.188 (`src/core/Rumble.lua`, Settings → VIBRATION) |
| 4 | Coyote time + corner correction | corner correction built 0.5.188; coyote time not needed (falling keeps both jumps) |
| 5 | Landing / turning dust, squash on hard landings | built 0.5.188 |
| 6 | Camera leads ahead in the running direction | built 0.5.188 (`CameraLook.lead`) |
| 7 | Off-screen arrow | **rejected by the user** |
| 8 | Editor field for the data enemy `leaves` | built 0.5.188 (enemy editor, General → Al morir) |
| 9 | Split the big boss files, shared attack pieces in the boss base | split 0.5.188 (`SnowbossRender`, `MegacrabbyDeath`, `MegacrabbyRender`); the duplicate scan found no other copies to move |
| 10 | One "is this cell free" rule | built 0.5.188 (`Level:boxTaken` / `cellTaken`) |
| 11 | Pre-drawn static level chunks | measured, NOT built: see [performance](../testing/performance.md) (0.5.188); two safe savings in the tile loop instead |
| 12 | Shader pre-compilation at startup | built 0.5.188 (`src/fx/Shaders.lua`) |

Each built item is described in its system's page; this page keeps the list and the verdicts.
