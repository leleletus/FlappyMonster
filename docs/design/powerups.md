# Power-ups and the quick wheel (design, 2026-11-07)

Status: **design, not built.** Decided with the user in conversation on 2026-11-07, as an addition to the
[Flappy prequel campaign](flappy-prequel.md). Lines marked *(Claude's call)* were proposed by Claude and still wait for
the user's verdict; everything else is the user's.

## Intent

Consumable power-ups the player keeps in an inventory and spends whenever they want, in any level. They come first to
the Flappy campaign, then to Adventure's story. They give the player a way through a hard stage without grinding it,
and give the caged flappies and the map shops a purpose.

Anti-goals: power-ups that make a boss trivial; a level that can only be finished with a power-up; Flappy and
Adventure inventories mixing; anything that breaks the shared simulation online (golden rule 1).

## Rules (the user's)

- **Two inventories, one per mode.** Flappy power-ups and Adventure power-ups never mix. Each lives in its mode's save
  **slot**: every slot has its own inventory, and deleting a slot deletes it (the user, 2026-11-07).
- **Capacity: 6 power-ups in total, at most 3 of one type.** They are meant to be hard to get, so the cap is not
  expected to feel tight.
- **Where they come from:**
  1. **Caged flappies** (Flappy campaign): freeing one gives a power-up.
  2. Later, **shops on the world maps**, where power-ups are bought with points.
- **Use = spent.** A power-up is gone the moment it is used, whatever happens next: if the player dies, quits or
  wastes it, it is still spent. It is the player's decision and responsibility. This is the one exception to golden
  rule 7, and only for spending: power-ups *gained* in a level (from a cage) are still saved only when the level is
  finished.
- **Usable in any level, at any moment,** through the quick wheel (below).
- **No slow time.** It cannot work online (the server runs one clock for everybody). Every power-up must work in both
  single player and the online simulation. Some are shared by both modes, some are exclusive to the mode where they
  make sense.

## The catalog (first set)

Durations and ranges are *(Claude's call)*, to be tuned by playing.

| Id *(proposed)* | Power-up | Modes | Effect |
|---|---|---|---|
| `shield` | Shield | both | Absorbs the next hit of any kind, once, then breaks (with its own sound and a short invulnerability, like a hit). Lasts until hit or the level ends. Also saves from spikes, lava and drowning (each would cost HP or the life: the shield takes it instead, and drowning refills the air). **Not** from pits (the user, 2026-11-07). |
| `strength` | Strength | both | Double damage for 12 s. |
| `heart` | Extra heart | both | +1 max HP for the rest of the level (3→4, or 4→5 on Easy), and the new heart starts full. Stacks: two give +2. |
| `magnet_points` | Points magnet | both | Pulls points pickups from a radius of about 4 tiles, for 20 s. |
| `magnet_items` | Item magnet | both | Pulls lives, food and Flappy charge items, for 20 s. |
| `magnet_all` | Super magnet | both | Both magnets in one, for 20 s. Rarer and pricier. |
| `small` | Small monster | Flappy | Half-size hitbox and sprite for 15 s: tight gaps get easier. |
| `ghost` | Ghost | Flappy | Passes through pipes and zone obstacles for a set time (12 s, like Strength), shown see-through. Machines, their shots and bosses still hurt. It replaces slow time (the user, 2026-11-07). If it runs out inside a pipe, the monster is pushed out to the nearest gap with a short invulnerability instead of being hurt *(Claude's call)*. |
| `big` | Big monster | Adventure | Double size for 20 s (or until it runs out of extra hits). Takes twice as many hits (see below), and breaks blocks that normally need a ground pound or a bomb just by running or jumping into them: shortcuts, secret exits, bonus rooms. Each level decides: a big-only block may hide a bonus room, a shortcut or a secret exit with no other way in (the user, 2026-11-07). |

How "twice as many hits" works for `big` *(Claude's call)*: while big, a hit shrinks the monster back to normal size
instead of taking HP, with the usual flash and invulnerability. A second hit then takes HP as normal. This is easier to
read than half-HP hits.

Ideas for later, not decided:
- Flappy: `full_charge` (fills the special attack charge to the cap at once, designed together with the charge
  system).
- Adventure: something to replace slow time that makes sense on foot, such as longer air under water or an extra
  mid-air jump for a while.

### Strength and the special attack (designed together)

The user wants each one to work on its own and both to work well together *(the rules below are Claude's call)*:

- Strength multiplies the **damage the monster deals**: the special attack (its damage comes from the charge, then
  ×2), shots returned to sender, and in Adventure stomps, ground pounds and thrown objects.
- Strength does **not** change how much charge a **special obstacle** needs. Routes stay tied to the charge the player
  saved, not to a consumable.
- Strength does not fill the charge. Saving up a full charge and firing it under Strength is the intended big combo,
  and it costs two things: the charge saved during the stage and a power-up.
- Boss tuning: a full charge under Strength must not take more than about half of a boss's HP in one hit (cap it if
  needed).

### Several at once

Different types can run together (for example Shield + Strength + a magnet). The same timed type used again restarts
its timer and does not add to it. A second `shield` cannot be used while one is still up, and a second magnet does
nothing while `magnet_all` is active. In those cases the wheel greys the power-up out, so it is never wasted by
mistake *(Claude's call)*.

## The quick wheel

A ring of up to 6 segments, one per type the player holds, each with its icon and a ×N count. Opening it in **single
player freezes the game**. It works like the pause menu, so it does not need to be fast, and it is the only fair way to
choose in Flappy *(Claude's call)*. Online it does not freeze (see Online). Using a power-up closes the wheel and
resumes the game. A greyed-out segment (see above) cannot be picked. Cancelling never spends anything.

| Device | Open | Choose | Use | Cancel |
|---|---|---|---|---|
| **Phone / tablet** | Tap the bag button in the HUD band at the top (the top 30 % of the screen is already outside the control zones, so it never collides with flap or the special attack) | The wheel opens in the centre of the screen, with big segments (at least 12 mm on a phone) | Tap a segment. You can also hold the bag button, slide to a segment and lift the finger | Tap the centre or outside the wheel, or slide back to the centre and lift |
| **Gamepad / Switch** | Hold a shoulder button (L) | Point with the left stick (the right stick also works) | Release L over a segment | Release L with the stick centred |
| **PC** | Hold Q (or Tab) | Point with the mouse or the arrows / WASD | Release Q, or click | Release Q with nothing chosen, or Esc |
| **PC shortcut** | — | — | Keys 1–6 use the type in that wheel position directly, without opening the wheel | — |

- New action names in `input.lua`: `wheel` (Q / Tab / `button:leftshoulder`) and `wheel_1`…`wheel_6`. Existing actions
  are not renamed (golden rule 8 only protects files, but levels and harnesses rely on these names).
- The wheel always keeps the same order (catalog order), so muscle memory works and the 1–6 keys stay stable.
- Labels go through `Input.label` / `Input.hints` as usual. Texts are rows in `translations.csv`.
- Accessibility: a setting to make the wheel toggle (press to open, press again to choose) instead of hold-and-release.

## Getting them

### Caged flappies (Flappy campaign)

- Each cage gives a fixed power-up chosen by the level designer (a field on the cage entity), so a cage in a hard spot
  can give a better one *(Claude's call)*.
- **Saved only when the level is finished** (rule 7). If the player dies before the end of the level, the cage closes
  again.
- A cage gives its power-up **once per slot**. When the level is replayed, an already-freed cage is shown empty or
  open, so it cannot be farmed.
- If the inventory is full (6, or 3 of that type) when the level is finished, the results screen offers to swap the
  new power-up for one already held, or let it go *(Claude's call)*.
- The reward for freeing **all** the flappies is still undecided, as in [flappy-prequel](flappy-prequel.md).

### Shops on the world maps (later)

- A shop node on the map (Flappy's zone map first, then Adventure's world map) sells a fixed list per zone, at prices
  in points. Later zones sell the rarer power-ups.
- **Points as money:** today `Run.complete` keeps the *total points* as a record, and it feeds the rewards. Spending
  needs a separate **wallet** that goes up with the same points and down when buying, so the record never shrinks
  *(Claude's call)*.
- Prices stay high enough that the shop does not replace the cages.

## Online

- The inventory belongs to a story slot, and online has no slots, so **power-ups are off online in the first version**
  *(Claude's call)*. Every power-up is still designed to work in the server simulation (no slow time, no global
  effects), so online can be opened later without redesigning them.
- If they come online later: the wheel does not freeze the game; the active power-ups travel in the player's snapshot
  so others see them (shield bubble, big or small size); `Protocol.VERSION` + 1.

## Built how (left to the builder, with these constraints)

- **Catalog as data** (golden rule 3): one file per power-up in a new `powerups/` folder under `src/world/` (id, modes, duration,
  icon, sound, price, hooks), plus its name in a list. The ids are stored in saves and must never be renamed.
- **Effects in the player base, not in the power-up** (golden rule 2): `PlayerAdventure` gains a generic "active
  effects" table with a timer per effect. The shield absorbs damage in the one existing `hurt` / invulnerability path,
  and `big` / `small` scale the hitbox the same way `puff` (squash) does. The flight mode and the platformer use the
  same mechanism.
- `big` breaking blocks uses the existing breakable-block rule ("what breaks this block"), extended with a cause. No
  per-block copies.
- Mode exclusivity uses the same flag as the rest of the Flappy-only catalog (see [flappy-prequel](flappy-prequel.md),
  approach 1).
- Save: `inventory = { [id] = count }` in each mode's slot, with the wallet next to it. Spending writes the save at once.
- Sprites: icons and the shield bubble / size states as real asset files (golden rule 4), pixel art, no wings.
- Tests: a harness for the rules (cap 6 / 3, spent on use even on death, cage saved only on finish, no farming, two
  magnets that do not stack, strength × charge cap) and a `touch_layout` capture with the bag button and the wheel open.

## Open questions for the user

1. Durations, prices, and how rare each one is.

Answered on 2026-11-07: the inventory is per slot; the shield saves from everything except pits; big-only blocks may hide any of the three
(level by level); `ghost` replaces slow time in Flappy, with a set duration.

**Related, found while answering:** Adventure has no pits today. A player who falls below the level does not die
(enemies and objects already have `fellOut`, the player does not). Logged in [pendientes](../pendientes.md) §3, to be
fixed later, before the shield's "not from pits" rule means anything.

## Order in the Flappy build

This goes in after step 4 of [flappy-prequel](flappy-prequel.md) ("special attack, charge items, special obstacles,
cages, food"), because it needs the cages and the charge. The wheel and inventory frame come first, with `shield` and
`heart`, then the rest of the catalog. The shops come after zone 1, with the map. Adventure gets its inventory, its
shop and `big` once the Flappy campaign is finished.

## What only a person can judge

How the wheel feels on a real phone and on the Switch (size, sliding versus tapping), whether freezing the game breaks
the pace of Flappy, the balance of durations and prices, and the looks of the icons and the size states.
