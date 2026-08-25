# RYKO Level Editor

Static browser editor for authored RYKO puzzle levels. It mirrors the current Godot gameplay board contract from `scripts/main.gd`:

- logical canvas: 720 × 1280;
- board: 7 columns × 9 playable rows;
- cells: 88 px with a 4 px gap (92 px row step);
- launch / danger line: logical Y 1092;
- blocks and powers use the same names and icon assets as the game.

## Supported level modes

### `clear_limited`

All content is present on the initial board. Nothing descends and no new row is spawned. The player wins by clearing all authored content before `moveLimit` is exceeded.

### `descent`

The initial board starts with authored content. After every completed volley, all surviving board content moves down exactly one row, matching the current endless-mode cadence. The editor can also author a finite sequence of incoming top rows: incoming row `+1` appears after move 1, `+2` after move 2, and so on. A block reaching the launch line loses the level.

The level is complete when all authored content has been consumed and the live board is clear. This allows finite descending puzzle levels without replacing the separate endless generator.

## JSON contract

The editor exports schema version `1`. Positions are stored as `column` and `row`; no pixel positions are authored.

Block entity example:

```json
{
  "kind": "block",
  "shape": "square",
  "variant": "regenerative",
  "hp": 12,
  "column": 2,
  "row": 4
}
```

Triangle example:

```json
{
  "kind": "block",
  "shape": "triangle",
  "variant": "normal",
  "orientation": "top_right",
  "hp": 8,
  "column": 5,
  "row": 1
}
```

Black Hole adds `absorbingSides`, with values from `left`, `right`, `top`, `bottom`.

Power entities use `kind: "power"` with `type: "ion" | "ghost" | "supernova"`; Ion also has `orientation: "horizontal" | "vertical"`. The `+ Ball` pickup uses `kind: "pickup", type: "plus_ball"`.

## Validation

Run from this directory:

```bash
node --check model.js
node --check editor.js
node validate-editor.mjs
```

The GitHub Pages workflow runs the same checks before publishing.
