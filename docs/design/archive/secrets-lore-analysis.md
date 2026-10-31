> **Archived design document.** Status: DECIDED; the user's decisions are at the end. Item 5 (more secret bosses) is open: [future-secret-bosses](../../bosses/future-secret-bosses.md). Post-game flight is a future idea.
> Copied unchanged on 2026-10-31 from `FlappyMonster_pruebas/secretos/lore_analisis.md`. It records what was proposed and decided at the time: the system pages win where they differ, and paths or ids below may be out of date.

# Lore analysis: splinters, the Groove, the Mashup, the flap and the endings

## 1. What the story already establishes (it has to stay consistent)
- The mirror broke into **8 shards**. Whoever finds a shard grows and becomes furious: that is the FURY OF THE MIRROR.
- The Reflection stole the flap. The Mirror boss keeps the centre shard.
- **Beaten main bosses DROP their shard and flee, but stay BIG** until the ending. In the ending, with the 8 shards in place, the mirror is whole and its LIGHT WAVE crosses the islands: every boss shrinks. The monster gets its flap back and flies home.
- So the rule the game already follows is: **losing the piece doesn't shrink you; only the restored mirror's light does.**
- The new piece (user, 2026-10-29): when the mirror broke, tiny SPLINTERS flew off too. The secret crabs wear theirs (the Mega Crabby a shell crown, the Mega Gloomy an amulet). The Groove's disco ball is made of splinters.
- The user's correction: beaten secret crabs drop their splinter piece and **flee, still big**. That matches the main bosses exactly, so there is no contradiction.

## 2. Do the splinters shrink anyone? Two options
**A. The player USES the splinters in the ending, so that they shrink everyone.**
- Problem 1: the normal route ends at the Mirror, and a player may own 0 splinters. The ending must work with 0, so shrinking cannot depend on optional items. Splinters would only add an edge case: who shrinks the secret crabs if you don't have them?
- Problem 2: it breaks the rule from §1. Shrinking comes from the mirror's light, not from handing in pieces.
- The upside (keeping the crown and amulet as empty settings) can be had another way (§4).

**B. The player KEEPS the splinters, and the mirror's light shrinks everyone (recommended).**
- The wave shrinks EVERYONE grown by mirror power: the 7 bosses and the 2 secret crabs, because splinters are mirror too.
- The **exception is the Groove**: its disco ball REFLECTS the wave and bounces it away. It is comic, it can be seen in the ending, and it explains why it is still big.
- It works the same with 0, 1 or every splinter. The splinters stay in the inventory as items: the crown and the amulet with their splinters.

## 3. The flap: the problem is bigger than the Groove and the Mashup
After the Mirror, the monster has its flap back. Yet:
- **every replay of a level after the ending** is also played without flying, not just the Groove and the Mashup;
- the adventure "is" the flapless form, because the flap is the Flappy-mode ability.

Ways to justify it:
- **a. Local: the dance floor.** The disco ball cancels the flap only on the Groove's island and in the Mashup.
  - Simple.
  - Replays of other levels after the ending stay unexplained, accepted as a game convention.
- **b. Global: the post-credits STINGER (recommended).** After the credits, the Groove's disco ball "catches" the monster's returning flap and jams it, the way the Reflection did, but with music. The flap sputters out.
  - Everything played after the ending (replays, secret levels, the Groove, the Mashup) is then justified.
  - The flap only comes back for good in the TRUE ending.
  - It also turns the normal ending into a hook: "you won… almost".
- **c. The user's idea, taken further.** On reaching the Groove with every splinter, it STEALS them (it pulls the splinters out of the crown and the amulet; the player keeps the empty settings).
  - With its disco ball complete, it has enough power to (1) cancel the flap for good inside its party and (2) bring its pals back BIG (the Icy, the Mega Crabby and the Mega Gloomy). That gives the Mashup.
  - It fits the Groove gate: it asks for every splinter because it needs them.
  - **b and c combine well:** b explains post-game play in general; c explains the Groove, the regrowth and the Mashup.

## 4. The collectibles under this plan
- Beating each secret crab gives its piece WITH its splinter: the crown and the amulet.
- The Groove steals the splinters, and the cards change, for example "Corona de conchas — su astilla te la robó el Groove". The empty settings stay in the collection, which is the user's "le saca el splinter y se queda con el objeto".
- Beating the Mashup breaks the disco ball. The splinters go back where they belong: into their settings, or into the mirror, whichever we decide. The player gets the "Bola de discoteca" (broken / empty frame) as a trophy.
- **Extensible:** each secret boss adds one entry with kind = splinter. The ball gets N slots, the Groove asks for all N, and nothing else changes.

## 5. Endings
| Ending | When | What happens |
|---|---|---|
| **Neutral** (normal route) | Beat the Mirror | Today's ending (mirror whole, bosses shrink, flap back), the Groove's ball bouncing the wave, then the stinger: the flap jams. On the map, the Groove's island with its ball MISSING one piece per splinter you lack. |
| **Neutral variant by splinters** | Same, with 0 / some / all splinters | The stinger shows the ball with the gaps you still need. 0 = only a glint; some = the Groove counting the pieces it lacks; all = the Groove calling you. A visual guide to the secret. |
| **True** (good) | Beat the Mashup | The ball breaks, the flap comes back for good, everyone small and dancing, and an epilogue with the monster flying free. Maybe a mark on the save slot (a ⭐ / "100 %"). |
| **Bad?** | — | I don't recommend one. A "bad" ending only fits if there is a real failure (not finishing the Mashup isn't an ending, it's unfinished). It would feel like a punishment for a secret that is optional. An alternative is a separate "Groove victory" variant if you lose the Mashup… but that's a Game Over, not an ending. |

## 6. Only one of the two secret bosses beaten
- The Groove stays closed. On the map its ball is missing exactly one piece; in the stinger it shows its gaps. The player knows "one splinter is missing" without any text, because the story has no text.
- The beaten secret crab's card is in the collection; the other shows "???" with its hint.

## 7. Extending it with more secret bosses
- Every new secret boss: a lair with a secret exit, its splinter in its own setting (an item), one more slot in the ball, and one more entry in `collectibles.json`. Nothing in the Groove's or the endings' code changes.
- In the Mashup only the crabs come back (it's their remix). A non-crab secret boss is only a holder of its splinter, unless it gets a role in the remix.

## 8. Implications for the build (what changes vs what is in progress)
- **Ending film** (`ending.lua`):
  - the wave also shrinks the secret crabs;
  - the Groove's ball bounces the wave;
  - a post-credits stinger (the flap jams; the ball with N gaps, by splinters owned).
- **Groove gate:** Mirror + every splinter (already planned). When it opens: the THEFT scene (the splinters leave the crown and amulet → the complete ball).
- **Before the Mashup:** the ball's beams regrow the Icy, the Mega Crabby and the Mega Gloomy (the scene already proposed).
- **True ending after the Mashup:** the ball breaks, the flap returns, everyone small dancing, the "Bola de discoteca" trophy.
- **Save:** splinters stolen (a state change of the collectibles), true ending seen.
- **Collection cards:** text that changes after the theft.

---
## User's decisions (2026-10-29)
1. The restored mirror's LIGHT shrinks everyone, the secret crabs included. The Groove does not shrink: its ball bounces the wave away. The player keeps the splinters as items.
2. The flap is jammed ONLY on the Groove's island and in the Mashup. Post-game flight to secret places is a future idea, not for today.
3. Without every splinter the game ENDS at the Mirror, with nothing extra. With every splinter, the Groove's island unlocks with its 2 final secret fights: the Groove, then the Mashup.
4. Designs (crown, amulet, disco ball, cannons): approved ("se ven bien").
5. FUTURE (user): at least 5 secret bosses, not necessarily crabs, and all new (none reused). Each holds its splinter in its own piece, so the disco ball fills more convincingly ("con 2 suena insuficiente"). The Mashup stays as it is.
