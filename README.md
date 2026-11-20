# Temucraft Minimap Buttons

Puts the addon buttons from around the minimap into one grid, for WoW 3.3.5a. One button stays on the minimap; click it to open the grid.

- Finds LibDBIcon buttons (`LibDBIcon10_*`) and other addon buttons on the minimap
- Leaves the Blizzard buttons alone (tracking, mail, zoom, calendar, world map, battleground, LFG, voice chat and the clock)
- Skips map pins (GatherMate, Questie, HandyNotes, TomTom and other numbered pins)
- Looks again a few seconds after login and every time you open the grid, so late buttons are found too
- Options: columns, scale, which buttons stay on the minimap, hide our own button, close the grid when the mouse leaves or after a click
- Drag our minimap button to move it around the minimap

Left-click the minimap button: open or close the grid. Right-click: options (also in Interface, AddOns).

`/tmb` opens or closes the grid. `/tmb options`, `/tmb rescan`, `/tmb list`, `/tmb columns <n>`, `/tmb scale <0.5-2>`, `/tmb exclude <name>`, `/tmb include <name>`, `/tmb button` (hide or show our minimap button), `/tmb reset`.

Written from scratch for Temucraft. MIT licence, see LICENSE.

## Tests

`lua5.1 tests/tmb_test.lua TemucraftMinimapButtons` runs a plain Lua test with stub frames.
