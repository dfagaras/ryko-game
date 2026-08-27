import assert from "node:assert/strict";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const M = require("./model.js");

globalThis.window = globalThis;
const storage = new Map([["ryko-block-color", "amber"]]);
globalThis.localStorage = {
  getItem: (key) => storage.has(key) ? storage.get(key) : null,
  setItem: (key, value) => storage.set(key, String(value))
};
require("./block-color-model.js");

function levelWith(columns, rows, topRow) {
  return M.normalizeLevel({
    schemaVersion: 1,
    levelId: `bounds_${columns}_${rows}`,
    name: "Bounds",
    boardColumns: columns,
    boardRows: rows,
    board: M.boardForDimensions(columns, rows),
    rules: { mode: "clear_limited", startingBalls: 1, moveLimit: 5 },
    initialBoard: [
      { kind: "block", shape: "square", variant: "normal", hp: 10, column: 0, row: 0 }
    ],
    incomingRows: [],
    topRow
  });
}

for (const [columns, rows] of [[6, 8], [7, 9], [8, 10], [14, 18], [28, 36]]) {
  const level = levelWith(columns, rows, [
    { kind: "block", shape: "square", variant: "normal", hp: 5, column: 0, color: "aqua" },
    { kind: "block", shape: "square", variant: "normal", hp: 6, column: columns - 1, color: "coral" },
    { kind: "block", shape: "square", variant: "normal", hp: 7, column: columns, color: "violet" },
    { kind: "block", shape: "square", variant: "normal", hp: 8, column: columns + 6, color: "toxic" },
    { kind: "block", shape: "square", variant: "normal", hp: 9, column: -1, color: "ion_blue" },
    { kind: "block", shape: "square", variant: "normal", hp: 10, column: 0, color: "amber" }
  ]);

  assert.equal(level.topRow.length, 2, `${columns}x${rows} should keep only unique in-bounds top-row cells`);
  assert.deepEqual(level.topRow.map((item) => item.column), [0, columns - 1]);

  const exported = JSON.parse(M.toExportJson(level));
  assert.equal(exported.topRow.length, 2);
  assert.ok(exported.topRow.every((item) => item.column >= 0 && item.column < columns));
}

// Regression for the exact stale state that produced level_005's failure:
// a 7-column board carrying top-row cells from a previous wider board.
const skullRegression = levelWith(7, 9, [
  { kind: "block", shape: "square", variant: "normal", hp: 50, column: 13, color: "ion_blue" },
  { kind: "block", shape: "square", variant: "normal", hp: 10, column: 14, color: "ion_blue" },
  { kind: "block", shape: "square", variant: "normal", hp: 10, column: 3, color: "coral" }
]);
assert.deepEqual(skullRegression.topRow.map((item) => item.column), [3]);

console.log("RYKO top-row bounds pruning validation: PASS");
