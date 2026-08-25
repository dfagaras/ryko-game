import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const M = require("./model.js");

const closeTo = (actual, expected, epsilon = 1e-9) => assert.ok(Math.abs(actual - expected) <= epsilon, `${actual} != ${expected}`);
const assertFixedFootprint = (board) => {
  const width = board.columns * board.cell + (board.columns - 1) * board.columnGap;
  const height = board.rows * board.cell + (board.rows - 1) * board.rowGap;
  closeTo(width, M.BASE_GRID_WIDTH);
  closeTo(height, M.BASE_GRID_HEIGHT);
  closeTo(board.gridX + width, 680);
  closeTo(board.gridY + height, board.launchLineY);
  assert.ok(board.cell > 0 && board.columnGap >= 0 && board.rowGap >= 0);
};

const clearLevel = M.createDefaultLevel();
clearLevel.initialBoard.push({ kind: "block", shape: "square", variant: "normal", hp: 10, column: 3, row: 2 });
let result = M.validateLevel(clearLevel);
assert.equal(result.valid, true, result.errors.join("; "));
assert.equal(result.level.board.columns, 7);
assert.equal(result.level.board.rows, 9);
assertFixedFootprint(result.level.board);

for (const [columns, rows] of [[8, 10], [9, 11], [10, 13], [14, 18], [28, 36]]) {
  const level = M.normalizeLevel({
    levelId: `grid_${columns}_${rows}`,
    name: `${columns}x${rows}`,
    boardColumns: columns,
    boardRows: rows,
    rules: { mode: "clear_limited", startingBalls: 2, moveLimit: 12 },
    initialBoard: [{ kind: "block", shape: "square", variant: "normal", hp: 20, column: columns - 1, row: rows - 1 }]
  });
  assert.equal(level.board.columns, columns);
  assert.equal(level.board.rows, rows);
  assert.equal(M.validateLevel(level).valid, true, M.validateLevel(level).errors.join("; "));
  assertFixedFootprint(level.board);
}

const eightByTen = M.normalizeLevel({
  levelId: "grid_8_10", name: "8x10", boardColumns: 8, boardRows: 10,
  rules: { mode: "clear_limited", startingBalls: 1, moveLimit: 8 },
  initialBoard: [{ kind: "block", shape: "square", variant: "phase", hp: 12, column: 7, row: 9 }]
});
assert.equal(eightByTen.board.scale, 0);
assertFixedFootprint(eightByTen.board);

const legacyScale = M.normalizeLevel({
  levelId: "legacy_scaled", name: "Legacy scaled board", boardScale: 2,
  rules: { mode: "clear_limited", startingBalls: 1, moveLimit: 5 },
  initialBoard: [{ kind: "block", shape: "square", variant: "normal", hp: 3, column: 13, row: 17 }]
});
assert.equal(legacyScale.boardScale, 2);
assert.equal(legacyScale.board.columns, 14);
assert.equal(legacyScale.board.rows, 18);
assertFixedFootprint(legacyScale.board);

result = M.validateLevel({
  levelId: "bad_dimensions", name: "Bad dimensions", boardColumns: 29, boardRows: 10,
  rules: { mode: "clear_limited", startingBalls: 1, moveLimit: 5 },
  initialBoard: [{ kind: "block", shape: "square", variant: "normal", hp: 3, column: 0, row: 0 }]
});
assert.equal(result.valid, false);
assert.match(result.errors.join("\n"), /Board size/i);

const descent = M.normalizeLevel({
  ...M.createDefaultLevel(), boardColumns: 8, boardRows: 10, board: M.boardForDimensions(8, 10),
  rules: { mode: "descent", startingBalls: 1, moveLimit: 10 },
  initialBoard: [{ kind: "block", shape: "square", variant: "regenerative", hp: 12, column: 2, row: 7 }],
  incomingRows: [{ afterMove: 1, cells: [{ kind: "block", shape: "triangle", variant: "normal", orientation: "top_right", hp: 8, column: 4, row: 0 }] }, { afterMove: 2, cells: [] }]
});
result = M.validateLevel(descent);
assert.equal(result.valid, true, result.errors.join("; "));
assert.equal(M.simulateDescent(descent, 1).danger, false);
assert.equal(M.simulateDescent(descent, 2).danger, true);
assert.equal(M.simulateDescent(descent, 2).dangerAtMove, 2);

const arbitraryExport = JSON.parse(M.toExportJson(eightByTen));
assert.equal(arbitraryExport.boardColumns, 8);
assert.equal(arbitraryExport.boardRows, 10);
assert.equal(arbitraryExport.boardScale, undefined);
assert.equal(arbitraryExport.board.scale, undefined);
assertFixedFootprint(arbitraryExport.board);

const legacyExport = JSON.parse(M.toExportJson(legacyScale));
assert.equal(legacyExport.boardScale, 2);
assert.equal(legacyExport.board.scale, 2);
assertFixedFootprint(legacyExport.board);

console.log("RYKO flexible authored board validation: PASS");
