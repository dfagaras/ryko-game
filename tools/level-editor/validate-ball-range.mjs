import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const M = require("./model.js");
globalThis.window = { RykoLevelModel: M };
vm.runInThisContext(fs.readFileSync(new URL("./ball-range-extension.js", import.meta.url), "utf8"));

const makeLevel = (sizeMultiplier) => ({
  levelId: `ball_${String(sizeMultiplier).replace(".", "_")}`,
  name: `Ball ${sizeMultiplier}x`,
  boardColumns: 10,
  boardRows: 13,
  ball: { sizeMultiplier },
  rules: { mode: "clear_limited", startingBalls: 2, moveLimit: 8 },
  initialBoard: [{ kind: "block", shape: "square", variant: "normal", hp: 5, column: 4, row: 4 }],
  incomingRows: []
});

for (const multiplier of [0.2, 0.35, 0.5, 0.7, 1, 1.3, 1.5, 2, 2.5, 3]) {
  const result = M.validateLevel(makeLevel(multiplier));
  assert.equal(result.valid, true, result.errors.join("; "));
  assert.equal(result.level.ball.sizeMultiplier, multiplier);
  const exported = JSON.parse(M.toExportJson(makeLevel(multiplier)));
  assert.equal(exported.ball.sizeMultiplier, multiplier);
  const metrics = M.ballMetricsForLevel(result.level);
  assert.equal(metrics.selectedRadius, metrics.standardRadius * multiplier);
  assert.equal(metrics.selectedCollisionRadius, metrics.standardCollisionRadius * multiplier);
}

assert.equal(M.validateLevel(makeLevel(0.19)).valid, false);
assert.equal(M.validateLevel(makeLevel(3.01)).valid, false);
assert.match(M.validateLevel(makeLevel(0.2)).warnings.join("\n"), /experimental|tiny/i);
assert.match(M.validateLevel(makeLevel(3)).warnings.join("\n"), /experimental|large/i);

console.log("RYKO experimental ball range validation: PASS");
