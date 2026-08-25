import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const M = require("./model.js");

function approx(actual, expected, epsilon = 0.001) {
  assert.ok(Math.abs(actual - expected) <= epsilon, `${actual} should be approximately ${expected}`);
}

for (const scale of M.SUPPORTED_SCALES) {
  const board = M.boardForScale(scale);
  assert.equal(board.columns, 7 * scale);
  assert.equal(board.rows, 9 * scale);
  approx(board.cell, 88 / scale);
  const width = board.columns * board.cell + (board.columns - 1) * board.gap;
  approx(width, 640, 0.01);
}

assert.equal(M.boardForScale(1).gap, 4);
assert.equal(M.boardForScale(1).gridY, 268);
assert.equal(M.boardForScale(2).columns, 14);
assert.equal(M.boardForScale(2).rows, 18);
assert.equal(M.boardForScale(4).columns, 28);
assert.equal(M.boardForScale(4).rows, 36);
approx(M.gameplayForScale(1).ballRadius, 9);
approx(M.gameplayForScale(2).ballRadius, 4.5);
approx(M.gameplayForScale(4).ballRadius, 2.25);
approx(M.gameplayForScale(2).ballSpeed, 380);
approx(M.gameplayForScale(4).ballSpeed, 190);

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
assert.equal(result.level.board.gap, 4);

const legacyV1 = M.normalizeLevel({
  schemaVersion: 1,
  levelId: "legacy",
  name: "Legacy",
  board: { columns: 7, rows: 9, cell: 88, gap: 4 },
  rules: { mode: "clear_limited", startingBalls: 1, moveLimit: 5 },
  initialBoard: [{ kind: "block", shape: "square", variant: "normal", hp: 2, column: 6, row: 8 }]
});
assert.equal(legacyV1.boardScale, 1);
assert.equal(legacyV1.schemaVersion, 2);
assert.equal(legacyV1.initialBoard.length, 1);

const micro = M.createDefaultLevel();
micro.boardScale = 4;
micro.board = M.boardForScale(4);
micro.initialBoard = [{ kind: "block", shape: "square", variant: "dense", hp: 20, column: 27, row: 34 }];
result = M.validateLevel(micro);
assert.equal(result.valid, true, result.errors.join("; "));
assert.equal(result.level.board.columns, 28);
assert.equal(result.level.board.rows, 36);
assert.match(result.warnings.join("\n"), /micro-grid/i);

const descent = M.createDefaultLevel();
descent.boardScale = 2;
descent.board = M.boardForScale(2);
descent.rules.mode = "descent";
descent.initialBoard = [{ kind: "block", shape: "square", variant: "regenerative", hp: 12, column: 2, row: 15 }];
descent.incomingRows = [
  { afterMove: 1, cells: [{ kind: "block", shape: "triangle", variant: "normal", orientation: "top_right", hp: 8, column: 13, row: 0 }] },
  { afterMove: 2, cells: [] }
];
result = M.validateLevel(descent);
assert.equal(result.valid, true, result.errors.join("; "));
const afterOne = M.simulateDescent(descent, 1);
assert.equal(afterOne.entities.some((e) => e.column === 2 && e.row === 16), true);
assert.equal(afterOne.entities.some((e) => e.column === 13 && e.row === 0), true);
assert.equal(afterOne.danger, false);
const afterTwo = M.simulateDescent(descent, 2);
assert.equal(afterTwo.danger, true);
assert.equal(afterTwo.dangerAtMove, 2);

const invalidBlackHole = M.createDefaultLevel();
invalidBlackHole.initialBoard = [{ kind: "block", shape: "square", variant: "black_hole", hp: 5, absorbingSides: [], column: 1, row: 1 }];
result = M.validateLevel(invalidBlackHole);
assert.equal(result.valid, false);
assert.match(result.errors.join("\n"), /absorbing side/i);

const normalizedTriangle = M.normalizeLevel({
  levelId: "x", name: "x", boardScale: 4, rules: { mode: "clear_limited", startingBalls: 1, moveLimit: 5 },
  initialBoard: [{ kind: "block", shape: "triangle", variant: "regenerative", orientation: "bottom_right", hp: 3, column: 27, row: 35 }]
});
assert.equal(normalizedTriangle.initialBoard[0].variant, "normal");

const exported = JSON.parse(M.toExportJson(micro));
assert.equal(exported.schemaVersion, 2);
assert.equal(exported.boardScale, 4);
assert.deepEqual(exported.board, M.boardForScale(4));
assert.equal(exported.rules.winCondition, "clear_all_content");

console.log("RYKO level editor board-scale validation: PASS");
