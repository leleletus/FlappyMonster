> **Archived design document.** Status: BUILT; the user's verdict at the end changes the proposal.
> Copied unchanged on 2026-10-31 from `FlappyMonster_pruebas/islas_heladas/diseno.md`. It records what was proposed and decided at the time: the system pages win where they differ, and paths or ids below may be out of date.

# The two frozen islands — new mechanics and levels (proposal for approval)

Islands since 0.5.100:
- **Frozen Mountains** (`nieve`, Snowball Boss): `cumbres_escarcha`, `torre_viento` → boss `lago_helado`.
- **Frozen Coast** (`costa_helada`, Icy Mega Crabby): `fabrica_criogenica` → boss `glaciar_cangrejo`, bonus `lago_de_cristal`.

To reach 4 levels per island, the Mountains need **2 levels and a bonus**, and the Coast needs **3 levels**.
Order, as you asked:
1. Resources first: music (in progress), the Coast background pack (in progress), and the mechanics below.
2. Then the levels, built only from what already exists.

---

## A. New mechanics

Each one goes in the base, generic, so any island can use it later. Each gets its own test harness.

### 1. Iceberg (`iceberg`): floating ice you ride (Coast)
- A block of ice that **floats on the water surface**. It follows the water if a flood or tide raises or lowers it.
- It **bobs**, and **sinks a little under weight**. With enough weight (you plus a box or a beetle) it goes under, with a short warning. When the weight leaves, it comes back up.
- Optional `drift`: it moves sideways on its own, bouncing between walls, and carries whoever stands on it.
- Optional `fragile`: it cracks while you stand on it, like thin ice, and breaks into small pieces.
- It's built on the existing moving-body system (`bodyParts` with `moves`), the one the Scale already uses, so the player, boxes and enemies ride it correctly.

### 2. Freezing water (water prop `cold`) (Coast)
- In polar water, after some seconds swimming you **freeze**. That's the existing frozen state, escaped by mashing buttons.
- If you're still in the water after breaking out, it starts again.
- Leaving the water resets it. A frost meter shows next to the air bar.
- It's an option of the level's water or flood, not a new tile.

### 3. Tide (option of the existing flood: `tide`) (Coast)
- The water **rises and falls in cycles** by itself, with no switch.
- Combined with icebergs, this is the core of the coastal puzzles: at high tide an iceberg reaches a high ledge, at low tide you walk the sea floor.

### 4. Avalanche (`avalanche`) (Mountains)
- A **snow chute**: a column of the level where, after a warning, a torrent of snow pours down. The warning is a rumble, falling flakes and the ledge shaking.
- The snow pushes you down and hurts you. You take cover under ledges or run across between pours.
- Props: width, period, delay. One chute or a staggered line of them.
- It reuses the falling-hazard rules of spike rain, but as a flow, not single spikes.

### 5. Cable car (`cablecar`): a generic moving platform on a cable (Mountains, reusable anywhere)
- A platform hangs from a **cable drawn between two or more points**. It travels the path back and forth or in a loop, at a set speed.
- Optional `stops`: it waits at each end.
- Optional `onWeight`: it only moves while someone is on it.
- The game has no free-path moving platform yet. This one is generic and will serve every island: mine carts, rafts, elevators.

### Optional new enemies (pick none, one or both)
- **Penguin** (Coast): slides on its belly across ice. Stomped, it stays on its belly and you can **ride it as a sled** for a few seconds.
- **Mountain goat** (Mountains): leaps between ledges and **butts you sideways** off narrow ledges. A thin, angular silhouette, in the "simple and original" style.

---

## B. New levels (built after the mechanics)

### Frozen Mountains
1. `cumbres_escarcha` (existing)
2. **NEW "El Teleférico" (The Cable Car Pass)**: crossing between peaks on cable cars in the wind.
   - Gusts push the cabins.
   - Some cabins only move while you ride them.
   - One stretch has two cabins crossing in opposite directions, and you jump from one to the other.
3. `torre_viento` (existing): the climb.
4. **NEW "La Ladera del Alud" (Avalanche Slope)**: a DESCENT, the opposite of the tower.
   - You climb down a cliff face while avalanche chutes sweep the columns.
   - Snow cornices collapse under your weight (thin ice dressed as snow).
   - It ends at the frozen lake (the boss).
- Boss: `lago_helado`.
- **NEW bonus "La Cima" (The Summit)**: King of the Hill on a peak. The zone sits in the path of an avalanche chute, so you leave when it rumbles and come back.

### Frozen Coast
1. `fabrica_criogenica` (existing): the factory that freezes the sea.
2. **NEW "Témpanos a la Deriva" (Drifting Floes)**: crossing a polar sea on drifting icebergs.
   - Some sink if you carry a box onto them; fragile floes crack.
   - The water freezes you, and pufferfish rise from below.
3. **NEW "La Bahía de las Mareas" (Tide Bay)**: a frozen harbour with a tide.
   - At high tide icebergs lift you to the docks and a wrecked ship.
   - At low tide you cross the seabed among icy crabs.
4. **NEW "Bajo el Hielo" (Under the Ice)**: swimming under a sheet of ice in freezing water.
   - Air pockets; you break thin ice from below to breathe.
   - Currents carry floating ice.
   - It ends at the glacier (the boss).
- Boss: `glaciar_cangrejo`. Bonus: `lago_de_cristal` (existing).

Each level gets the house treatment: about 150–170 tiles wide (the cable car level may be taller), 2 checkpoints, 3 stars (one hidden), food. Music:
- Mountains: the new set (pending your pick).
- Coast: `nieve_1`, `nieve_2` and `nieve_bonus`.

---

## C. How the work is split (in parallel)
- **Phase 1** (now, already running): music previews for the Mountains and background-pack previews for the Coast. They wait for your A/B choice.
- **Phase 2** (after you approve this page): one agent per mechanic (1–5, plus the enemies you choose).
  - Each covers single player, server and online client, with a harness and its docs.
  - Then one battery run and one release (a new protocol version).
- **Phase 3**: one agent per level, using the finished resources.
  - Each level is checked with the solver and captured for you before it goes into the story.

Needs your answer:
- (1) Approve or change the 5 mechanics.
- (2) Which optional enemies, if any.
- (3) Approve or change the 5 new levels and the bonus.

---

## User's verdict (2026-10-29)
- Mechanics: all five approved. Icebergs do NOT crack, and do NOT drift on their own; they move only when pushed or blown.
- Enemies: only the Penguin. The Gust enemy already does what the goat would (maybe later).
- Levels: approved as proposed.
- Background: A, "costa de témpanos", with the background icebergs and ice walls redesigned like B's "mar congelado". Keep the auroras.
- Extra: improve the snow and ice tiles (walls must read as continuous, not block by block). Add a pack of frozen bricks and rock walls, plus background variants. The user will place them in the existing levels by hand; the new levels will use them.
- Added (user, 2026-10-29): a small SNOWBALL enemy, the Giant Snowball's normal counterpart (like every other boss). It launches itself at players and shoves them off ledges, the role the goat had in this proposal. It is also the boss's "before the shard" form in the intro.
