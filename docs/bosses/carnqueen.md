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

- **Mouths** (`self.mouths`: `warn` → `out` → `bite` → `shut` or `hold` → `back`): the socket opens under, beside or above you (floor always; a wall or the ceiling only if within about 4 tiles), then the stalk comes out at you and shuts. Aim locks 0.22 s before it comes out, so it can be dodged; from phase 2 it partly follows you while coming out. Up to 1 / 2 / 3 at once. Stalks reach at most 4.6 tiles. **It swallows, it does no other damage:** mash buttons to get out, −1 every 1.75 s (`PlayerGulp`; the mouth is `gulpBy`).
- **Seeds:** spat in an arc; they sprout into normal Carnivorous Plants, reserve minions (`def.summons`), up to 1 / 2 / 2.
- **The window:** a THROWN bomb falling on her is swallowed (`bomb`), explodes inside (`blast`), she is stunned (`stun`) and her mouths let go. The flower opens up high: stomp 1, ground pound 2, **on the flower only**, one hit per knockout. `STUN_T` by difficulty (6 s Easy to 3.5 s Xtra), `GETUP_T` after the hit.
- **Bombs and platforms** are the room's: `bombobject` with `respawn` at both sides, drop-through platforms to reach the flower (about 125 px up).
- **Entry:** closed pod, opens. **Defeat:** `dying_out`, then `dying_flee`: closes without the dew drop and sinks away; her plants burst.

## Single player, server, client

What swallows comes from each mouth's state (`netPackExtra`: phase, mouths, seeds). Stalks are local, each client's `SegmentChain`. Protocol 101.

## Tests

`carnqueen_rules` (its own fixed copy of the arena), `boss_intro`, `boss_sim`, `online_boss`, `sp_boss` with `LEVEL=tools/levelgen/arenas/jefe_reina.json`; `boss_frames` with `NEAR=1`.

## History and decisions

- 2026-11-01: user's look A without the face. My proposals, accepted by the user's silence when choosing: body walk-through, bud always visible. Seeds grow into the NORMAL plant, as the mock-up showed ("tal y como lo muestras"), not the weaker seedling I had suggested.
- **Pending the user:** feel, numbers, stalk lengths, own sounds. Nobody has played her.
