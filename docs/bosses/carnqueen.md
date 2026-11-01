# The Carnivorous Queen (`carnqueen`)

The jungle's secret boss: the Carnivorous Plant grown huge, lying flat, rooted in the middle of a temple room. **In the game as an entity, with an arena for
testing; no story level, secret exit or Collection entry yet** (plan: [future-secret-bosses](future-secret-bosses.md), looks:
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

- **Lanzas** (the user's name for the stalks that sprout from walls; `self.mouths` in code: `warn` → `out` → `seek` → `lunge` → `hold`, `shut` or `camp` → `back`): the socket opens 2.4-5.5 tiles from you, up to 9.5 if nothing nearer fits; on the floor never within 2.2 tiles horizontally, never within 2.5 tiles of another. Standing on an opening hole closes it. It peeks, then winds up for 0.8 / 0.68 / 0.56 s: it aims, shrinks back and trembles more and more, and blinks red for the last 0.24 s, when its aim is fixed and you should move. Then it lunges straight at 1300-1700 px/s, past where you were (up to 10 tiles, stopping at solid tiles). **Any contact swallows instantly**, from when it peeks until the lunge ends; it does no other damage: mash to get out, −1 every 1.75 s (`PlayerGulp`, `gulpBy`). A Lanza that missed is finished: it no longer aims or swallows; 40 % stay still and closed (`camp`) for 2.5-4 s. They turn gradually while aiming (3 / 3.5 / 4 rad/s). Up to 2 / 3 / 4 at once, 1-3 sprouting together, every 2.4 / 1.9 / 1.5 s; **when you are above the floor or vines are out, up to 3 / 4 / 5, every 1.1 / 0.9 / 0.75 s**, from the ceiling and walls only. **When no player is free, the others retract, none sprout, and 1.5 s pass after you get out.**
- **She bites too:** within about 2 tiles she opens her lobes (`bite_wind`, a warning), then shuts (`hold` if she caught you, `chomp_miss` if not). Cooldown 2.5 s.
- **Floor vines** (`vine_wind` → `vines` → `vine_back`, every 13 / 11 / 9 s): they sprout harmlessly for 1.6 / 1.4 / 1.2 s, then thorns fill the room's floor for 3.2-4.4 s: −1 and a launch upwards while touching the floor, so the player must go up to the platforms. She hops onto the platform above her and back (`platformAbove`, none = stays), so no bomb can be fed to her during the attack. Her plants on the floor die when the thorns come out; seeds in flight are lost.
- **Seeds:** spat in an arc; they sprout into normal Carnivorous Plants, reserve minions (`def.summons`), up to 1 / 2 / 2.
- **The window:** a THROWN bomb falling on her is swallowed (`bomb`), explodes inside (`blast`), she is stunned (`stun`) and her mouths let go. The flower opens up high: stomp 1, ground pound 2, **on the flower only**, one hit per knockout. `STUN_T` by difficulty (6 s Easy to 3.5 s Xtra), `GETUP_T` after the hit.
- **Bombs and platforms** are the room's: `bombobject` with `respawn`, reappearing at a random spot of the room, floor or platform (`respawnLeft` / `respawnRight`, generic props), drop-through platforms to reach the flower (about 125 px up).
- **Entry:** closed pod, opens. **Defeat:** `dying_out`, then `dying_flee`: closes without the dew drop and sinks away; her plants burst.

## Single player, server, client

What swallows comes from each mouth's state (`netPackExtra`: phase, mouths, seeds). Stalks are local, each client's `SegmentChain`. Protocol 103.

## Tests

`carnqueen_rules` (its own fixed copy of the arena), `boss_intro`, `boss_sim`, `online_boss`, `sp_boss` with `LEVEL=tools/levelgen/arenas/jefe_reina.json`; `boss_frames` with `NEAR=1`.

## History and decisions

- 2026-11-01: user's look A without the face. My proposals, accepted by the user's silence when choosing: body walk-through, bud always visible. Seeds grow into the NORMAL plant, as the mock-up showed ("tal y como lo muestras"), not the weaker seedling I had suggested.
- 2026-11-01, the user's first notes: she herself eats you when close; stalks sprout at random spots near you and stretch, not under you; heads aim freely (they always pointed up); several at once; a new floor-thorn attack that forces you up. All added. Art: `vine-Sheet.png`.
- 2026-11-01, second notes: the user named nothing, so Claude named them **Lanzas**. "Mouth very fat, did you change the sprite?": the sprite had NOT changed; the wide-open frame was now held while seeking. They now stay closed and thin, half open when aiming. They still sprouted under the player, because a static distance rule ignored the player walking onto the hole. Too slow to catch: rewritten as spears that swallow on contact. None came while the player was up, because mouths only spawned in `idle`. First vine art rejected ("no parecen enredaderas").
- 2026-11-01, third notes: 6-8 Lanzas up high were too many (now 3-5); once caught the others must not attack; at full speed the head came apart from its stalk, because the spring lagged (now the stalk is placed rigidly while moving fast); more visible, avoidable windup.
- 2026-11-01, fourth notes: after a miss it must give up (closed, no aiming, no eating); smooth turning, because the stalk looked broken (the stalk's chain length was measured in a straight line while it followed a curve; no more spring, the stalk is always the exact curve); open mouths thinner, closed unchanged (`head_half`, `head_wide`).
- 2026-11-01, fifth notes: jaws wide open while winding up and lunging, closed only when biting (catch or miss); screen shake on a catch.
- **Pending the user:** feel, numbers, stalk lengths, own sounds. Nobody has played her.
