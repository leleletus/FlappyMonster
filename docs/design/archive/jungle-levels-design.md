> **Archived design document.** Status: BUILT (0.5.99); levels may differ from this proposal.
> Copied unchanged on 2026-10-31 from `FlappyMonster_pruebas/niveles_jungla/diseno.md`. It records what was proposed and decided at the time: the system pages win where they differ, and paths or ids below may be out of date.

# Jungle island — level designs (proposal for approval)

Four story levels + one bonus. Every level is built around ONE central idea with its own structure, mixes the new
jungle mechanics (Rhino Beetle, carnivorous plant, piranha, mole, background plane) with old ones, and is decorated
with the jungle set (big trees on the background plane, temple ruins, lianas, idols, braziers).

Common numbers (the game's): one jump ≈ 1.6 tiles, double ≈ 3; gaps ≤ 4 are easy; levels ≈ 150-180 × 28 tiles;
2 checkpoints per level; 3 stars (one hidden) and food as in the other islands; background `jungle` (day/dusk), music
`jungla_1` (levels 1 and 3), `jungla_2` (levels 2 and 4), `jungla_bonus` (bonus). Story order = difficulty order.

Legend for the sketches: `=` drop-through platform (liana planks) · `#` ground · `T` temple brick · `~` water ·
`P` carnivorous plant (`Pv` ceiling, `P<`/`P>` wall) · `B` Rhino Beetle · `M` mole · `F` piranha · `S` seed ·
`G` geyser · `K` scale · `x` box · `o` bomb · `!` ON/OFF switch · `C` checkpoint · `*` star · `▒` background plane.

---

## 1. "Senda del Dosel" (The Canopy Trail) — intro, TWO ROUTES AT ONCE

**Idea.** From the start the path splits into two parallel floors that cross every ~30 tiles: the FLOOR (mud, moles,
beetles, plants) and the CANOPY (platforms you grow with seeds, lianas, plants hanging under it). Each floor solves
the other's problems: from the canopy you drop/throw beetles onto the plants below (they eat them and sleep); from
the floor you ground-pound to pull the moles out of the canopy route's landing spots and you grow the seeds that
build the canopy.
**Size** 170 × 28 · day · `jungla_1`.

```
 canopy  ==S==   Pv   ==  ==B==  Pv  ====      ==*==         Pv   ===== C ====
         |    \       /  \       /   \        /     \        /           \
 floor   ##M###P###B####x##P####M######P##~~F~~##P###B##M###P######### C ####### F
```

**Sections**
1. *Teaching the beetle* (cols 1-30): one beetle on flat floor, a lone plant; a sign-like safe spot shows the
   stomp → flip → carry → throw cycle; throwing the beetle at the plant puts it to sleep and opens the way.
2. *First crossing* (30-55): a seed planted on a mud mound grows into the first canopy; from up there two plants
   wait below — drop the canopy beetle onto them (the canopy route is fast, the floor route slow but safe).
3. *Moles* (55-90): the floor becomes mud with two moles chasing you; the canopy above has a gap too wide to jump,
   crossable only with a seed planted on the floor below — but that mud patch is a mole's territory: ground-pound
   it out first (it surfaces dizzy, stomp it), then plant. The floors cross again here. Checkpoint 1.
4. *The plant corridor* (90-130): ceiling plants under the canopy, floor plants below; the only safe way is to feed
   them in order with the beetles that wander on each floor (a puzzle of carrying).
5. *River glimpse* (130-155): a small pool with ONE piranha (intro to level 2) under a canopy bridge.
6. *Finish* (155-170): both floors merge into a ruined arch with the finish.

**Hidden star:** behind the background-plane ceiba at col ~120: a canopy dead end that looks closed (fake block).

---

## 2. "Río Revuelto" (The Churning River) — the valley you cross TWICE

**Idea.** One long valley. GOING: the river is LOW — you walk the riverbed among puddles (piranhas jump out of them)
and moles in the mud banks. At the far end a big ON/OFF switch FLOODS the valley (an `activatable` flood) and the
level continues BACKWARDS above the same valley: now everything is water, piranhas everywhere, geysers lift you,
and the HANGING PLANTS that were harmless above your head while going are now at water level: you lure the piranhas
under them so the plants eat them in mid-leap (the plants become your allies).
**Size** 160 × 28 (the return runs on a higher layer of the same columns) · dusk · `jungla_2`.

```
 return →  ←  ←  ←  Pv   ←  G  ←  Pv  ←  K(ferry)  ←  Pv  ← C ← ← F(finish over the start)
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  (after the flood)
 going  →  ~F~  M  →  ~F~  →  x  →  M  →  ~F~  → C →  ~F~ → ! (flood switch)
 ####### #### ####### ####### ### ##### ##### ###########
```

**Sections**
1. *Riverbed* (going, 1-80): dry mud with deep puddles (piranhas leap when you pass over); moles on the banks;
   boxes to push into puddles as stepping stones. Checkpoint 1 at the bottom of the valley.
2. *The dam* (80-90): the flood switch inside a small temple; a short warning (rumble, the water starts rising
   from behind) and the music swells.
3. *The return* (going back, upper layer): you swim or hop on floating stuff; geysers (jungle variant) give lifts;
   a SCALE works as a FERRY between two banks (stand on one pan, a box on the other); hanging plants at the surface
   eat leaping piranhas — pass under a plant to make the piranha that follows you jump into it.
4. *Exit*: the finish sits ABOVE the starting point (you end where you began, but on the flooded level).

**Hidden star:** inside a puddle on the way out, only reachable once the valley is flooded (an air pocket).

---

## 3. "El Templo de los Pesos" (The Temple of Weights) — NON-LINEAR temple

**Idea.** Inside the temple (background `jungle` + depth `temple`, torches/braziers, ruins on the background plane).
A central HALL with a big door made of 3 ON/OFF blocks; three WINGS in any order, each ending at a switch that
removes one block of the door.
**Size** 150 × 40 (hall in the middle, wings left / up / right) · day (temple interior) · `jungla_1`.

```
                 [ Wing of the Mouths ]  Pv P< P> o  !
                          |
 [Wing of the Scale] — [  HALL  ][DOOR ▮▮▮] — finish
   K x x B  !             |
                 [ Wing of the Tunnels ]  M M T T  !
```

**Wings**
- *Wing of the Scale* (left): balance puzzles — boxes and flipped beetles as weights to catapult yourself to a
  ledge; a beetle on a pan you launch into the ceiling to break a breakable block; the switch on top.
- *Wing of the Mouths* (up): a vertical shaft lined with plants on the ceiling, floor and both walls; you climb by
  pushing enemies into them (Gummies from the side, moles knocked out) or feeding them bombs (thrown bombs make
  them burst); the switch at the top.
- *Wing of the Tunnels* (right): moles in mud between temple bricks; ground-pounding pulls them out, and breakable
  blocks open shortcuts; a beetle charging down a corridor breaks the boxes that block it.
- *Hall*: a safe hub with a checkpoint and food; the door's three blocks blink as you open them.

**Hidden star:** above the hall's chandelier-like hanging moss: needs a scale launch from the Scale wing's last pan.

---

## 4. "La Estampida" (The Stampede) — AUTO-SCROLL chase to the boss

**Idea.** The camera moves on its own while a STAMPEDE of Rhino Beetles charges from behind (they see you in front
and charge). Charging beetles bowl over other enemies and boxes — sometimes clearing your way, sometimes blocking it
(a fallen tree = a row of boxes they smash). Moles pop up ahead; plants in the path eat the beetles that overtake you
(a breather). Ends at the gate of the Giant Rhino Beetle's temple (next: the boss level, `templo_escarabajo`).
**Size** 200 × 15 (horizontal auto-scroll like `tren_fugaz`) · dusk → night at the end · `jungla_2`.

```
 → → camera →
 B B B (stampede)   x x x (fallen tree)   M   P   ~~F~~   P   B   T T T (temple gate) F
 ######################## #### ############ ####### ####################
```

**Sections**
1. *Stampede start* (1-50): three beetles charge as the camera starts; plain ground to learn the rhythm.
2. *Fallen trees* (50-100): rows of boxes — jump over them or let the beetles smash them.
3. *Moles and plants* (100-150): moles pop under you; plants eat the beetles that get ahead.
4. *The river ford* (150-175): stepping stones over a piranha river (with the camera pushing).
5. *The gate* (175-200): the temple gate closes behind you — next level is the boss.

**Hidden star:** on a canopy liana above section 3, only reachable by bouncing on a flipped beetle.

---

## Bonus: "El Claro de la Balanza" (The Scale Clearing) — King of the Hill vs the bot

**Idea.** The POINT ZONE sits on a pan of a giant scale: whoever stands on it sinks it and lifts the other pan, so
the zone moves up and down with who's on it. Plants line the arena's edges — push your rival into one and it eats
them (they have to mash out while you score). Geysers in the corners throw you back onto the scale; bombs appear now
and then to blow the plants (or your rival) away. ~1 minute, `jungla_bonus`.
**Size** 48 × 18 arena.

```
  Pv      Pv            Pv      Pv
      K==========o==========K
     [pan + POINT ZONE]   [pan]
  P  G                      G  P
  ##########################################
```

**New mechanic needed:** a point zone that FOLLOWS a scale pan (today point zones are static) — small, generic
(`pointarea` attached to a moving body).

---

## Order, story and what's left
- Story order: 1 Senda del Dosel → 2 Río Revuelto → 3 Templo de los Pesos → 4 La Estampida → boss
  `templo_escarabajo`; bonus El Claro de la Balanza (opens after the boss).
- The island then enters `Worlds.LIST` after the coast (save migration: decide what happens to saves that already
  beat the coast boss — see docs/story/world-map.md).
- Each level is built with a generator (`tools/levelgen/levels_jungle.py`), checked with `level_solve`
  (completable with the real physics) and `level_check`, decorated by `retheme.py` (jungle theme + background
  plane), and shown to you as captures before going into the story.
