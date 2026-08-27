import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);

globalThis.window = globalThis;
const storage = new Map([["ryko-block-color", "amber"]]);
globalThis.localStorage = {
  getItem: (key) => storage.has(key) ? storage.get(key) : null,
  setItem: (key, value) => storage.set(key, String(value))
};

const M = require("./model.js");
require("./block-color-model.js");
await import("./mission-block-model.js");

const mission = M.normalizeLevel({
  ...M.createDefaultLevel(),
  levelId: "mission_test",
  name: "Mission test",
  rules: { mode: "clear_limited", startingBalls: 5, moveLimit: 10 },
  initialBoard: [
    { kind:"block", shape:"square", variant:"mission_core", hp:5, column:0, row:0 },
    { kind:"block", shape:"square", variant:"normal", hp:20, column:1, row:0 }
  ],
  topRow: [{ kind:"block", shape:"square", variant:"mission_core", hp:8, column:2 }]
});

assert.equal(mission.initialBoard[0].variant, "mission_core");
assert.equal(mission.topRow[0].variant, "mission_core");
assert.equal(mission.rules.winCondition, "destroy_all_objectives");
assert.equal(M.missionBlockCount(mission), 2);

const result = M.validateLevel(mission);
assert.equal(result.valid, true, result.errors.join("; "));
assert.match(result.warnings.join("\n"), /Mission Core objective/i);

const exported = JSON.parse(M.toExportJson(mission));
assert.equal(exported.initialBoard[0].variant, "mission_core");
assert.equal(exported.topRow[0].variant, "mission_core");
assert.equal(exported.rules.winCondition, "destroy_all_objectives");

const normal = M.normalizeLevel({
  ...M.createDefaultLevel(),
  initialBoard: [{ kind:"block", shape:"square", variant:"normal", hp:2, column:0, row:0 }]
});
assert.equal(normal.rules.winCondition, "clear_all_content");

const triangle = M.validateLevel({
  ...M.createDefaultLevel(),
  initialBoard: [{ kind:"block", shape:"triangle", orientation:"top_left", variant:"mission_core", hp:2, column:0, row:0 }]
});
assert.equal(triangle.valid, false);
assert.match(triangle.errors.join("\n"), /square-only/i);

console.log("RYKO Mission Core contract validation: PASS");
