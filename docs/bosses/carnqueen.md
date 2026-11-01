# The Carnivorous Queen (`carnqueen`)

The jungle's secret boss: the Carnivorous Plant grown huge, lying flat, rooted in the middle of a temple room. **In the game as an entity, with an arena for
testing; no story level, secret exit, Collection entry or music of her own yet** (plan: [future-secret-bosses](future-secret-bosses.md), looks:
[carnivorous-queen](../design/carnivorous-queen.md)). The user chose look A «Cepo Real», without the face.

Try her: `love . --editor tools/levelgen/arenas/jefe_reina.json`, then play from the editor.

## Files

| File | What |
|---|---|
| `src/world/entities/types/bosses/carnqueen.lua` | the boss |
| `src/world/entities/base/SegmentChain.lua` | her mouths' live stalks (drawing only) |
| `src/player/PlayerGulp.lua` | being swallowed, as by the Plant (`gulpKind` 0) |
| `tools/art/bosses/make_carnivorous_queen.py` | art: `--apply` writes `assets/images/bosses/carnqueen/`, `assets/anim/bosses/carnqueen*.json` and the 2 Collection icons |
| `tools/levelgen/arenas/make_jefe_reina.py` | the test arena |

Sets: `bosses/carnqueen` (body ×5), `bosses/carnqueen_parts` (heads in 16 directions × closed, half, wide, prey; 3-layer stalk discs; sockets; flower; dew), `bosses/carnqueen_seed` (×4).
Sounds: reused from the Plant (`plantRustle`, `plantSnap`, `plantCrunch`) and `megaHurt`, `stunned`, `bombIgnite`.

## The fight

Hp 8 + 3 per extra player. Phases at 2/3 and 1/3 of her health. Her body can be walked through and never hurts.

- **Mouths** (`self.mouths`: `warn` → `out` → `seek` → `bite` → `shut` or `hold` → `back`): the socket opens 2.4-3.8 tiles away from you, never under you (floor always; a wall or the ceiling only if within about 4 tiles), so the stalk has to stretch. Stretched, the head looks at you and follows you for about 0.6 s, fixed for the last 0.16 s, so it can be dodged. Up to 2 / 3 / 4 at once, 1 / 2 / 3 sprouting together. Stalks reach at most 4.6 tiles. **It swallows, it does no other damage:** mash buttons to get out, −1 every 1.75 s (`PlayerGulp`; the mouth is `gulpBy`).
- **She bites too:** within about 2 tiles she opens her lobes (`bite_wind`, a warning), then shuts (`hold` if she caught you, `chomp_miss` if not). Cooldown 2.5 s.
- **Floor vines** (`vine_wind` → `vines` → `vine_back`, every 13 / 11 / 9 s): they sprout harmlessly for 1.6 / 1.4 / 1.2 s, then thorns fill the room's floor for 3.2-4.4 s: −1 and a launch upwards while touching the floor, so the player must go up to the platforms.
- **Seeds:** spat in an arc; they sprout into normal Carnivorous Plants, reserve minions (`def.summons`), up to 1 / 2 / 2.
- **The window:** a THROWN bomb falling on her is swallowed (`bomb`), explodes inside (`blast`), she is stunned (`stun`) and her mouths let go. The flower opens up high: stomp 1, ground pound 2, **on the flower only**, one hit per knockout. `STUN_T` by difficulty (6 s Easy to 3.5 s Xtra), `GETUP_T` after the hit.
- **Bombs and platforms** are the room's: `bombobject` with `respawn` at both sides, drop-through platforms to reach the flower (about 125 px up).
- **Entry:** closed pod, opens. **Defeat:** `dying_out`, then `dying_flee`: closes without the dew drop and sinks away; her plants burst.

## Single player, server, client

What swallows comes from each mouth's state (`netPackExtra`: phase, mouths, seeds). Stalks are local, each client's `SegmentChain`. Protocol 102.

## Tests

`carnqueen_rules` (its own fixed copy of the arena), `boss_intro`, `boss_sim`, `online_boss`, `sp_boss` with `LEVEL=tools/levelgen/arenas/jefe_reina.json`; `boss_frames` with `NEAR=1`.

## History and decisions

- 2026-11-01: user's look A without the face. My proposals, accepted by the user's silence when choosing: body walk-through, bud always visible. Seeds grow into the NORMAL plant, as the mock-up showed ("tal y como lo muestras"), not the weaker seedling I had suggested.
- 2026-11-01, the user's first notes: she herself eats you when close; stalks sprout at random spots near you and stretch, not under you; heads aim freely (they always pointed up); several at once; a new floor-thorn attack that forces you up. All added. Art: `vine-Sheet.png`.
- **Pending the user:** feel, numbers, stalk lengths, own sounds. Nobody has played her.
