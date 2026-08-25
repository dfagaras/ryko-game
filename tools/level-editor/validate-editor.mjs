import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const M = require("./model.js");

const clearLevel = M.createDefaultLevel();
clearLevel.initialBoard.push({ kind: "block", shape: "square", variant: "normal", hp: 10, column: 3, row: 2 });
let result = M.validateLevel(clearLevel);
assert.equal(result.valid, true, result.errors.join("; "));
assert.equal(result.level.rules.mode, "clear_limited");
assert.equal(result.level.rules.moveLimit, 10);
assert.equal(result.level.board.columns, 7);
assert.equal(result.level.board.rows, 9);
assert.equal(result.level.board.cell, 88);
assert.equal(result.level.board.gap, 4);

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

const exported = JSON.parse(M.toExportJson(clearLevel));
assert.equal(exported.schemaVersion, 1);
assert.deepEqual(exported.board, M.BOARD);
assert.equal(exported.rules.winCondition, "clear_all_content");

console.log("RYKO level editor model validation: PASS");
