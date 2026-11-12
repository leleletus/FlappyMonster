# Touch-control editor (2026-11-13)

**Status:** built (0.5.207); how it works: [platforms](../architecture/platforms.md) § the player's own layout. Approved in conversation (the user: "size per button"). Item 7 of the
[UX round](ux-round-2026-11.md), first half (the second half — accessibility — comes after).

## What the user asked

On phones, the on-screen controls' size, layout and opacity. The user chose FREE placement: on an edit screen each
on-screen button is dragged wherever the player wants; a size per button; one opacity for all.

## What gets built

- **Entry:** Settings → CONTROLS → `EDIT TOUCH CONTROLS` (an action row). Back returns to that row.
- **Screen** (`src/states/menu/TouchEditorState.lua`): the menu's living background dimmed; the real on-screen buttons
  (d-pad, jump, run, and the extra button shown as the flashlight) drawn by `TouchControls`; a finger (or the mouse)
  **drags** a button; tapping one **selects** it (gold outline). A bottom panel: `SIZE` of the selected button
  (60 %–160 %), `OPACITY` of all (20 %–100 %), `RESET` (back to the default layout, size and opacity) and `DONE`.
  Buttons stay inside the screen and below the top HUD strip (`TOP_FRAC`), and never overlap each other (the dragged
  one keeps its spot; a neighbour it would cover moves to the nearest free spot). The panel sits IN the top strip,
  where no button can go (my call: no clash between the panel and the buttons). Keyboard / pad (for testing on PC):
  left / right selects a button, the arrows with the shoulder buttons… kept minimal: tab cycles the selection, arrows
  move it, confirm / back = done.
- **Saved** in `options.cfg` (`src/core/Settings.lua`): `touchLayout` = nil (default) or
  `{ pad = {fx, fy, size}, jump = {…}, run = {…}, extra = {…} }` with positions as fractions of the screen (so it adapts
  to another resolution or orientation); `touchAlpha` (1 = as today). Per device by nature (each has its own options).
- **In game** (`TouchControls`): with the default layout nothing changes (left half = d-pad, right half = jump, as
  today). With a custom layout every button answers in a circle a bit larger than drawn (×1.35 its radius; the d-pad
  ×1.5 and you can still slide between directions); where two zones overlap, the nearest button wins. The opacity
  multiplies the controls' alpha everywhere.

## Tests

`touch_layout`: a custom layout moves and resizes the buttons; a finger on each button gives its action there and not
where it used to be; the d-pad slides; save → load keeps it; reset restores the default; clamping keeps every button
inside, below the HUD strip and without overlaps. `menu_flow`: the settings row opens the editor; a simulated drag
moves the d-pad and it is saved; size and opacity sliders change their values; DONE / back return to the row.

## Left to the builder

The panel's look (the settings screen's style), the exact limits, the drag feel.
