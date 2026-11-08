# The Flappy prequel campaign (design, 2026-11-04)

Status: **design, not built.** Decided with the user in conversation on 2026-11-04. Lines marked *(Claude's call)*
were proposed by Claude and accepted as a group, or are left for the user to revisit; everything else is the user's.

## Intent

Today the Flappy mode ([flappy-mode](../gameplay/flappy-mode.md)) is an endless pipe game with three difficulties and
nothing else: unbalanced, repetitive and disconnected from the rest of the game. The user wants it to become **the
prequel of Adventure**: a short story campaign that tells how the monster reached the archipelago, with stages,
the Evil Monster's machines as hazards and bosses, and an ending that hands straight into Adventure's intro film.
Adventure becomes locked until the prequel is finished.

Success: Flappy is a campaign worth playing on its own, diverse stage to stage, and its story makes Adventure's
premise (the mirror, the Evil Monster's fortress) feel earned.

Anti-goals: breaking the established lore (the monster has NO wings; the fury only exists after the mirror breaks);
a Flappy that plays like a platformer; Flappy-only content leaking into Adventure levels.

## Three projects, in this order

1. **The Flappy campaign** (this document): zones, stages, machines, bosses, special attack, backgrounds, music, the
   Adventure lock, the debug menu, the film changes.
2. **Online unlock rules** (decided, see below; small).
3. **Online Flappy**: a "Flappy / Adventure" choice before the online menu's options. Not designed yet; designed
   after project 1 exists.

## The story

- **The race.** The monster belongs to a race of **flappies** that flap by magic, without wings. Their homeland is
  the **Valley of the Pillars**: tall hollow stone columns like giant basalt organ pipes, with nests in the holes;
  flapping between the columns is the race's everyday game, which is where Flappy's pipes come from. The Valley is
  full of other flappies, each a little different from the monster (colours, horns, tails — never wings).
- **The Evil Monster** is one of the race, born **without the flap**. It looks like the monster. Jealous of the
  monster's innate magic, it wants to capture it and use that magic as a power source for its machines. It has also
  tested its machines on other flappies, whose magic is not strong enough for what it wants; it leaves them caged
  along the route (the collectible, below).
- **The prequel:** the Evil Monster hunts the monster from the Valley across five more lands, with machines that get
  bigger and better at each boss — all without magic yet: cruder, held together with junk.
- **The ending:** over the sea, the archipelago appears; the monster beats the Evil Monster (almost) for good above
  the **quarry** of the fortress island, and it falls into the quarry — where it will later build its fortress. From
  there the monster sees the **glint** of the volcano for the first time.
- **Into Adventure:** with the Evil Monster out of the way for now, the monster follows the glint; the existing intro
  film continues (mirror, crash, the Reflection, the shards). A shard falls near the quarry; the Evil Monster takes
  it and it powers its ship and fortress: the fight in `fortaleza_malvada` becomes a rematch. Having its power source,
  the Evil Monster no longer hunts the monster in Adventure, but will not let it through its fortress either.
- **Lore fix:** [story](../story/story.md) says today "the Evil Ship's pilot found one like the rest". It must say
  the Evil Monster does NOT grow from its shard: it uses it to power its machines and fortress (the one boss that
  breaks the giants-and-fury rule).

## Films

- **Adventure intro** (`assets/story/films.json`): no longer opens with "an ordinary day" on the checkered Flappy
  background. It starts at the **quarry** and goes to the **volcano**, using the new backgrounds (the Ocean zone's).
  Add a short shot of the quarry with a mechanical arm or a glowing eye in the rubble so it is clear the villain
  survived *(Claude's call, approved)*. The rest of the film (mirror → crash → Reflection → shards → fury → on foot)
  stays.
- **The `fortaleza_malvada` rematch is lore and films only for now:** the Evil Ship fight does not change
  *(Claude's call)*.
- **The Evil Monster's look** extends the current pilot sprite of the Evil Ship (`miniboss1`), not a redesign; it is
  seen piloting every machine *(Claude's call)*. Check the hand-edited list in [generators](../art/generators.md)
  before touching its sprites.
- **Adventure ending:** the `home` scene no longer returns to the checkered Flappy background: from the volcano,
  past the quarry and back along the route (the zones' backgrounds in reverse).
- **The Flappy campaign** needs its own films *(scope left to the builder, with the user's review)*: at least an
  opening in the Valley (the Evil Monster's first capture attempt) and the ending over the quarry that leads into the
  Adventure intro. No text anywhere, as in all the films.

## Zones

Six zones, each with 3–4 stages and an Evil Monster machine boss at the end *(Claude's proposal, approved)*:

| # | Zone | Obstacle ideas | Food *(Claude's call)* |
|---|---|---|---|
| 1 | Valley of the Pillars (homeland) | classic pipes = the pillars; first capture attempt (a net) | fruit |
| 2 | Swamp | twisted trunks, rising gas, vines | mushroom |
| 3 | Desert | sandstorms that push, ruined columns, mirages | cactus fig |
| 4 | Taiga | pines, snow falling from branches, logging machines | pine nuts |
| 5 | Tundra | aurora, ice spikes, a blizzard that cuts visibility | frozen fish |
| 6 | The Ocean (arrival) | waves, spray, the archipelago on the horizon; final boss over the quarry | coconut |

- Cold zones are last before the sea because Adventure already has two ice islands; the order may change.
- **Backgrounds:** new ones per zone, replacing today's checkered Flappy background. None may be an Adventure island:
  the monster has not reached the archipelago yet (the Ocean zone only shows it on the horizon, and the quarry at the
  very end).
- **Music:** the Valley keeps the current Flappy theme ("Aleteo", `flappy`). Each other zone gets an ORIGINAL theme
  that keeps recognisable leitmotifs (la llamada; plus an Evil Monster motif *(Claude's call)*). Boss music is left
  to the builder. Music rules: [music-guide](../audio/music-guide.md); verified by numbers only.

## Gameplay

- **Movement:** the monster flaps (vertical) AND moves left and right at will, but always inside the window that the
  level carries along by itself (auto-scroll): like a scrolling shooter, not a fixed-x Flappy and not a platformer
  camera that follows the player.
- **Stages, not endless.** Each stage has a fixed length and a finish. Different pipe arrangements per stage plus the
  Evil Monster's machines and zone obstacles, so stages feel diverse.
- **Health = Adventure's:** 3 HP (4 on Easy), a pipe takes 1, machines and enemies 1 or more depending on the attack.
  After a hit: red flash, invulnerability, and the monster passes through what it touched *(Claude's call, approved)*.
- **Lives, Game Over, results screen, invulnerability times, checkpoints:** as in Adventure's story, adapted to the
  Flappy structure and a Flappy HUD of its own. Checkpoints are flags flown past in long stages.
- **Food:** the zone's food spawns in stages and bosses (like Adventure's per-island food), controlled in bosses.
- **Rule 7 holds:** nothing gained in a stage (points, items, rescued flappies) is saved until the stage is finished.

### Damage to bosses: two ways

1. **Return to sender.** Some machine shots look distinct (e.g. a glowing bomb or ring). Hitting one while rising
   sends it back at the machine instead of hurting the monster; ordinary shots still hurt *(Claude's call,
   approved)*.
2. **The special attack:** a burst of the monster's flap magic.
   - Charged by a **special item** found in stages; the more collected, the more charge, up to a cap. Firing spends
     all of it; low charge = little damage, high charge = a lot.
   - Fired with a second button (on touch, a second zone of the screen) *(Claude's call)*.
   - Also breaks **special obstacles** in some stages (cracked blocks, cages), each needing a minimum charge, so
     saving charge opens routes and shortcuts.
   - In bosses the charge items appear controlled: never too many, reachable but risky; if the player has been low
     on charge for a while, the next one comes sooner, so a fight is never unwinnable *(Claude's call, approved)*.
   - Charge does not carry between stages *(Claude's call, approved)*.

### Collectible: caged flappies

Flappies the Evil Monster captured, in small cages along the stages, often in risky spots or behind special
obstacles. Breaking a cage frees one: it flies home. On the campaign map the Valley fills up with the ones rescued.
**Reward for all of them: PENDING** (the user, 2026-11-04: "not sure yet, leave it pending"). Claude's placeholder
was an extra stage plus a short extra scene in the ending with the Valley full again; build no reward until the user
decides. How many per stage is left to the builder.
Each freed flappy also gives a **power-up** (2026-11-07): see [powerups](powerups.md).

### Difficulties

Only **Easy, Normal, Hard** in the campaign (Extreme and Xtra Extreme stay exclusive to Adventure), chosen when a save
is created, using the same modifier framework ([difficulty](../gameplay/difficulty.md)). Gap size and scroll speed
may become new modifiers in that table *(Claude's call)*.

## Menus and access

- **Main menu (the user, 2026-11-07):** CONTINUE · **FLAPPY** · ADVENTURE · SETTINGS. The button is called FLAPPY
  (was CLÁSICO; id `classic` kept) and comes FIRST. Free Play left the Adventure menu (only in the debug menu).
  **CONTINUE resumes the last mode played**: the most recently written save, Flappy or Adventure, opens its map
  (built when the Flappy campaign gets saves, step 3). Done in 0.5.166: the order, the name, Free Play.
- The "CLÁSICO / CLASSIC" button (`menu.classic`) becomes the Flappy campaign. It opens a menu similar
  to Adventure's (3 save slots, a map of the zones) but with its own look (e.g. the Valley's stone and nests)
  *(look: Claude's suggestion)*. Flappy saves are separate from Adventure's.
- **Adventure (story, Free Play, online) is locked until the Flappy campaign is finished in ANY one Flappy slot**;
  that unlocks the whole of Adventure for the install (global, like the other unlocks in `story.sav`). The Flappy
  ending goes straight into creating an Adventure save (slot + difficulty), then plays the Adventure intro film.
  Existing Adventure saves
  stay on disk and come back when it unlocks. Only beta testers exist today, so no migration is needed.
- **The old endless mode stays in the code** (its 3 difficulties and best scores) but is not reachable by players.
- **The debug menu.** The current Sound Test combination (↑ ↑ ↓ ↓ ← → ← →, or 7 taps on the version) opens a new
  **debug menu** instead, with: *Classic (endless)*, *Adventure (without the lock)*, *Free Play*, *Sound Test*,
  *Film Test*. The Film Test is split from the Sound Test (today it is reached from it with ◀) into its own entry.
  Whether "Adventure without the lock" persists or is per session is left to the builder.

## Online unlock rules (project 2, decided)

- Online needs Adventure unlocked.
- In a room, the host can only pick levels the host has unlocked; guests play whatever the host picks, even if they
  have not reached it.
- The daily challenge stays open to everyone.
- Spoilers (seeing a boss online before the story) are an accepted price.

## Approaches considered (how it is built)

1. **Adventure's engine — CHOSEN.** Each Flappy stage is a level of the normal engine: auto-scroll
   ([autoscroll](../gameplay/autoscroll.md)), the player in a **flight mode** (flap physics as a trait in the player
   base), pipes as tiles, machines and bosses as entities on the Boss base. Gets the editor, checkpoints, food, HP,
   lives, results, difficulties, harnesses and later the online server; the post-game flight idea
   ([story](../story/story.md), "Open ideas") gets the same flight trait. Cost: the tile camera and a flying player
   must be tuned to feel like Flappy, not a platformer.
2. Grow the current Flappy engine (stages as "spawn X at distance D"): keeps the exact feel, but rebuilds lives,
   checkpoints, bosses, editor, difficulties and online — copies the base (breaks golden rule 2). Rejected.
3. Hybrid (Flappy engine reading Adventure levels): worst of both. Rejected.

**The user's condition on 1:** the Flappy-specific additions — enemies, objects, foods, decorations, obstacles, the
charge item, cages, backgrounds — are **exclusive to Flappy levels** and cannot be used in Adventure levels.

## Left to the builder

- How a level is marked as a Flappy level and how the exclusivity is enforced (catalog, editor, level loader,
  `project_check`); flight physics and how close they stay to today's Flappy feel (the user judges the feel).
- The machines and bosses per zone (one new machine per boss, each better than the last), the special obstacles,
  how many stages per zone within 3–4, the cage count, the HUD layout, the campaign map's form.
- Art and sounds follow the usual rules: real asset files, pixel density, simple and original sprites, no wings.
- Docs: a new system page (or a rewrite of [flappy-mode](../gameplay/flappy-mode.md)) when built, and the lore fix in
  [story](../story/story.md).

## What only a person can judge

The flight feel, the balance of charge and food in bosses, the looks of backgrounds and flappies, and the music
(never listened to by Claude).

## Starting the build (for the next session)

Approved by the user on 2026-11-04. Next step: write the implementation plan from this document (superpowers
`writing-plans`), then build in this suggested order *(Claude's call; each step playable and tested before the next)*:

1. **Debug menu + Adventure lock** (the Sound Test combination opens it; Classic / Adventure / Free Play / Sound
   Test / Film Test; the global unlock; the CLÁSICO button opens a placeholder campaign menu).
   **DONE in 0.5.163** ([menus](../architecture/menus.md#debug-menu-secret)). "Adventure without the lock" lasts the
   session. The lock is built but switched off (`Campaign.READY = false`) until the campaign can be finished, so
   testers keep Adventure; CLÁSICO's placeholder offers the endless mode until then.
2. **Flight trait + one test stage** on Adventure's engine (auto-scroll window, free left/right, flap, 3 HP, pass
   through on hit, Flappy-only catalog flag enforced) — the user judges the feel here before anything else.
   **BUILT in 0.5.164, waiting for the user's verdict on the feel** ([player](../gameplay/player.md#flight-flappy-levels)):
   level key `"flappy": true`, `PlayerFlight.lua`, the `pillar` tile (59, Flappy-only, hurts and lets through), the
   test stage `assets/levels/_flappy_vuelo.json` (`tools/levelgen/levels_flappy_test.py`, debug menu → FLAPPY
   FLIGHT (TEST)), harness `flappy_flight`. The track `flappy` became a level track (the Valley keeps it).
3. **Campaign frame:** Flappy saves (3 slots), zone map, lives / Game Over / results, Flappy HUD, Easy/Normal/Hard.
4. **Special attack, charge items, special obstacles, cages, food.**
5. **Zone 1 (Valley of the Pillars)** complete: background, stages, first boss machine, Evil Monster art.
6. Zones 2–6, one at a time (background, music, obstacles, stages, boss); the final over the quarry.
7. **Films:** the campaign's opening and ending; the Adventure intro (quarry → volcano) and ending (`home`) changes;
   the lore fix in [story](../story/story.md).

Projects 2 (online unlock rules) and 3 (online Flappy) come after.

## Plans

**The user, 2026-11-08:** the first boss is the Net-Copter (Redcóptero) as proposed in [flappy-plan-5-netcopter](flappy-plan-5-netcopter.md). `tuffi` is the FINAL battle's theme (it may be reworked later with Evil Monster motifs); until Flappy bosses have music of their own, they all use it.

One implementation plan per build step, each written (superpowers `writing-plans`) when the step before it is done
and judged, so it builds on what really exists. Each must leave the game playable and the battery green.

| Plan | Covers | Status |
|---|---|---|
| 1 | Debug menu, Adventure lock (off), FLAPPY placeholder | done (0.5.163, menu changes 0.5.166) |
| 2 | Flight (`PlayerFlight`), pillar tile, test stage | built (0.5.164–0.5.165), feel being judged by the user |
| 3 | **Campaign frame:** shared save / run core, Flappy saves (3 slots, Easy / Normal / Hard), zone map (placeholder look), stages with lives / Game Over / results, CONTINUE = last mode | **done (0.5.167):** [flappy-plan-3-campaign-frame](flappy-plan-3-campaign-frame.md), system page [flappy-campaign](../gameplay/flappy-campaign.md) |
| 4 | Flappy HUD (HP, lives, charge); special attack + charge items; special obstacles; caged flappies (saved on finish); zone food (return-to-sender and boss charge drops moved to 5: they need the machines) | **done (0.5.169):** [flappy-plan-4-attack-and-cages](flappy-plan-4-attack-and-cages.md) |
| 4b | Power-ups ([powerups](powerups.md)): inventory per slot (6 / 3 per type), the quick wheel (touch, pad, PC), `shield` + `heart` first, then the catalog; cages give power-ups | **done (0.5.172):** [flappy-plan-4b-powerups](flappy-plan-4b-powerups.md), system page [powerups](../gameplay/powerups.md) |
| 5 | **The Net-Copter** (zone 1's boss): Evil Monster + machine art, return to sender (`reflectable`, `glowbomb`), controlled charge / food in Flappy boss fights (`bossdrops`), the boss, the stage `valle_redcoptero`; boss music `tuffi` | **built (0.5.175):** [flappy-plan-5-netcopter](flappy-plan-5-netcopter.md), boss page [netcopter](../bosses/netcopter.md); art provisional, feel / music not judged yet |
| 5b | Zone 1's look: Valley sky (`valley` biome), 3 real stages (+ `valle_pilares_3` with the net-launcher), the drawn zone map, the shop + points wallet | **built (0.5.179):** [flappy-plan-5b-valley](flappy-plan-5b-valley.md) (approved by the user 2026-11-08); art, stage feel and prices not judged yet |
| 6 | Zones 2–6, one sub-plan each (background, music — verified by numbers only —, obstacles, stages, boss); the final over the quarry; **`Campaign.READY = true`** (the Adventure lock goes on) | after 5 |
| 7 | Films: the campaign's opening and ending; Adventure intro (quarry → volcano) and ending changes; lore fix in [story](../story/story.md) | after 6 |
| — | Projects 2 (online unlock rules) and 3 (online Flappy) | after 7 |

The Adventure lock turns on in Plan 6, when the campaign can be finished (unless the user asks for it earlier).

## Later: menu background

The user (2026-11-08): when there are many Flappy levels, the bot in the menu background scene should also play Flappy levels (not only Adventure ones). Not built. History: the old endless-mode background (`MenuScene.flappyBg()`) was first put behind the Flappy screens by a misunderstanding; the user meant the DEBUG menu, and the Flappy screens keep the bot scene.
