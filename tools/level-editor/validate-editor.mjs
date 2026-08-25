import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const M = require("./model.js");

const closeTo = (actual, expected, epsilon = 1e-9) => {
  assert.ok(Math.abs(actual - expected) <= epsilon, `${actual} != ${expected}`);
};

const assertFixedFootprint = (board) => {
  const width = board.columns * board.cell + (board.columns - 1) * board.columnGap;
  const height = board.rows * board.cell + (board.rows - 1) * board.rowGap;
  closeTo(width, M.BASE_GRID_WIDTH);
  closeTo(height, M.BASE_GRID_HEIGHT);
  closeTo(board.gridX + width, 680);
  closeTo(board.gridY + height, board.launchLineY);
};

const clearLevel = M.createDefaultLevel();
clearLevel.initialBoard.push({ kind: "block", shape: "square", variant: "normal", hp: 10, column: 3, row: 2 });
let result = M.validateLevel(clearLevel);
assert.equal(result.valid, true, result.errors.join("; "));
assert.equal(result.level.rules.mode, "clear_limited");
assert.equal(result.level.rules.moveLimit, 10);
assert.equal(result.level.boardScale, 1);
assert.equal(result.level.board.columns, 7);
assert.equal(result.level.board.rows, 9);
assert.equal(result.level.board.cell, 88);
assert.equal(result.level.board.columnGap, 4);
assert.equal(result.level.board.rowGap, 4);
assert.equal(result.level.board.ballRadius, 9);
assert.equal(result.level.board.ballSpeed, 760);
assertFixedFootprint(result.level.board);

const scale2 = M.normalizeLevel({
  levelId: "scale_2",
  name: "14x18",
  boardScale: 2,
  rules: { mode: "clear_limited", startingBalls: 2, moveLimit: 12 },
  initialBoard: [{ kind: "block", shape: "square", variant: "normal", hp: 20, column: 13, row: 17 }]
});
assert.equal(scale2.board.columns, 14);
assert.equal(scale2.board.rows, 18);
assert.equal(scale2.board.cell, 44);
closeTo(scale2.board.columnGap, 24 / 13);
closeTo(scale2.board.rowGap, 32 / 17);
assert.equal(scale2.board.ballRadius, 4.5);
assert.equal(scale2.board.ballCollisionRadius, 5);
assert.equal(scale2.board.ballSpeed, 380);
assert.equal(M.validateLevel(scale2).valid, true);
assertFixedFootprint(scale2.board);

const scale3 = M.normalizeLevel({
  levelId: "scale_3",
  name: "21x27",
  boardScale: 3,
  rules: { mode: "clear_limited", startingBalls: 3, moveLimit: 15 },
  initialBoard: [{ kind: "block", shape: "square", variant: "phase", hp: 12, column: 20, row: 26 }]
});
assert.equal(scale3.board.columns, 21);
assert.equal(scale3.board.rows, 27);
closeTo(scale3.board.cell, 88 / 3);
assertFixedFootprint(scale3.board);

const scale4 = M.normalizeLevel({
  levelId: "scale_4",
  name: "28x36",
  boardScale: 4,
  rules: { mode: "clear_limited", startingBalls: 4, moveLimit: 20 },
  initialBoard: [{ kind: "block", shape: "triangle", variant: "normal", orientation: "bottom_right", hp: 8, column: 27, row: 35 }]
});
assert.equal(scale4.board.columns, 28);
assert.equal(scale4.board.rows, 36);
assert.equal(scale4.board.cell, 22);
closeTo(scale4.board.columnGap, 24 / 27);
closeTo(scale4.board.rowGap, 32 / 35);
assert.equal(scale4.board.ballRadius, 2.25);
assert.equal(scale4.board.ballSpeed, 190);
assert.equal(M.validateLevel(scale4).valid, true);
assert.match(M.validateLevel(scale4).warnings.join("\n"), /high-density/i);
assertFixedFootprint(scale4.board);

const inferredLegacyScale = M.normalizeLevel({
  levelId: "legacy_scaled",
  name: "Legacy scaled board",
  board: { columns: 14, rows: 18 },
  rules: { mode: "clear_limited", startingBalls: 1, moveLimit: 5 },
  initialBoard: [{ kind: "block", shape: "square", variant: "normal", hp: 3, column: 12, row: 12 }]
});
assert.equal(inferredLegacyScale.boardScale, 2);
assert.equal(inferredLegacyScale.board.columns, 14);

const unsupportedScale = {
  levelId: "bad_scale",
  name: "Bad scale",
  boardScale: 5,
  rules: { mode: "clear_limited", startingBalls: 1, moveLimit: 5 },
  initialBoard: [{ kind: "block", shape: "square", variant: "normal", hp: 3, column: 0, row: 0 }]
};
result = M.validateLevel(unsupportedScale);
assert.equal(result.valid, false);
assert.match(result.errors.join("\n"), /scale must be 1, 2, 3 or 4/i);

const descent = M.createDefaultLevel();
descent.rules.mode = "descent";
descent.initialBoard = [{ kind: "block", shape: "square", variant: "regenerative", hp: 12, column: 2, row: 6 }];
descent.incomingRows = [
  { afterMove: 1, cells: [{ kind: "block", shape: "triangle", variant: "normal", orientation: "top_right", hp: 8, column: 4, row: 0 }] },
  { afterMove: 2, cells: [] }
];
result = M.validateLevel(descent);
assert.equal(result.valid, true, result.errors.join("; "));
const afterOne = M.simulateDescent(descent, 1);
assert.equal(afterOne.entities.some((e) => e.column === 2 && e.row === 7), true);
assert.equal(afterOne.entities.some((e) => e.column === 4 && e.row === 0), true);
assert.equal(afterOne.danger, false);
const afterTwo = M.simulateDescent(descent, 2);
assert.equal(afterTwo.danger, true);
assert.equal(afterTwo.dangerAtMove, 2);

const scaledDescent = M.normalizeLevel({
  levelId: "descent_2x",
  name: "Scaled descent",
  boardScale: 2,
  rules: { mode: "descent", startingBalls: 1, moveLimit: 10 },
  initialBoard: [{ kind: "block", shape: "square", variant: "normal", hp: 5, column: 0, row: 15 }],
  incomingRows: []
});
assert.equal(M.simulateDescent(scaledDescent, 1).danger, false);
assert.equal(M.simulateDescent(scaledDescent, 2).danger, true);
assert.equal(M.simulateDescent(scaledDescent, 2).dangerAtMove, 2);

const invalidBlackHole = M.createDefaultLevel();
invalidBlackHole.initialBoard = [{ kind: "block", shape: "square", variant: "black_hole", hp: 5, absorbingSides: [], column: 1, row: 1 }];
result = M.validateLevel(invalidBlackHole);
assert.equal(result.valid, false);
assert.match(result.errors.join("\n"), /absorbing side/i);

const normalizedTriangle = M.normalizeLevel({
  levelId: "x", name: "x", rules: { mode: "clear_limited", startingBalls: 1, moveLimit: 5 },
  initialBoard: [{ kind: "block", shape: "triangle", variant: "regenerative", orientation: "bottom_right", hp: 3, column: 0, row: 0 }]
});
assert.equal(normalizedTriangle.initialBoard[0].variant, "normal");

const exported = JSON.parse(M.toExportJson(scale2));
assert.equal(exported.schemaVersion, 1);
assert.equal(exported.boardScale, 2);
assert.equal(exported.board.scale, 2);
assert.equal(exported.board.columns, 14);
assert.equal(exported.board.rows, 18);
assert.equal(exported.rules.winCondition, "clear_all_content");
assertFixedFootprint(exported.board);

console.log("RYKO level editor exact board-scale validation: PASS");
