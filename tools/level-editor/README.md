# RYKO Level Editor

Static browser editor for authored RYKO puzzle levels. It mirrors the current Godot board footprint while allowing higher-resolution grids that behave like a camera zoom-out.

## Board scale

The physical board stays the same size. `boardScale` only increases the number of logical cells and scales gameplay elements proportionally:

- `1×` → 7 × 9, standard 88 px cell, 9 px ball radius, 760 px/s base ball speed;
- `2×` → 14 × 18, 44 px cell, 4.5 px ball radius, 380 px/s base ball speed;
- `3×` → 21 × 27;
- `4×` → 28 × 36, 22 px cell, 2.25 px ball radius, 190 px/s base ball speed.

The outer 720 × 1280 logical canvas, board frame and launch / danger line remain fixed. The extra cell separators consume the existing gap budget so the playable grid does not grow wider.

Changing grid scale in the editor clears authored board content after confirmation because the coordinate system changes.

## Supported level modes

### `clear_limited`

All content is present on the initial board. Nothing descends and no new row is spawned. The player wins by clearing all authored content before `moveLimit` is exceeded.

### `descent`

The initial board starts with authored content. After every completed volley, all surviving board content moves down exactly one grid row. The editor can also author a finite sequence of incoming top rows: incoming row `+1` appears after move 1, `+2` after move 2, and so on. A block reaching the launch line loses the level.

The level is complete when all authored content has been consumed and the live board is clear. This allows finite descending puzzle levels without replacing the separate endless generator.

## JSON contract

The editor exports schema version `2`. Schema version `1` files remain import-compatible and are treated as the standard `1×` board.

The important board field is:

```json
{
  "schemaVersion": 2,
  "boardScale": 2,
  "board": {
    "columns": 14,
    "rows": 18
  }
}
```

`board` also contains derived geometry for inspection, but runtime code must recompute that geometry from `boardScale` rather than trusting authored pixel values.

Positions are stored as `column` and `row`; no pixel positions are authored.

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

## Runtime preparation

Godot-side scale math lives in `scripts/board_profile.gd`. `scripts/level_definition.gd` accepts schema v1/v2 JSON, validates bounds against the selected scale and returns derived board/gameplay profiles without changing the current endless mode.

This intentionally keeps the existing `1×` endless gameplay untouched until authored-level loading is wired into the game session flow.

## Validation

Run from this directory:

```bash
node --check model.js
node --check editor.js
node validate-editor.mjs
```

The Android CI also runs `tools/validate_board_scale.gd` with Godot 4.4.1 so the runtime scale contract is checked before APK export.
