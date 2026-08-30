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
await import("./mechanics-model.js");
await import("./block-color-model.js");
await import("./mission-block-model.js");

const level = M.normalizeLevel({
  ...M.createDefaultLevel(),
  levelId: "descending_entities",
  name: "Descending entities",
  rules: { mode: "descent", startingBalls: 3 },
  initialBoard: [
    { kind:"block", shape:"square", variant:"normal", hp:8, column:0, row:2 }
  ],
  incomingRows: [
    {
      afterMove: 1,
      cells: [
        { kind:"block", shape:"square", variant:"mission_core", hp:12, column:2, row:0 },
        { kind:"power", type:"ghost", column:4, row:0 }
      ],
      launchers: [
        { id:"incoming_launcher_1", column:5, direction:"down_left" }
      ]
    }
  ]
});

assert.equal(level.rules.winCondition, "destroy_all_objectives");
assert.equal(M.missionBlockCount(level), 1);
assert.equal(level.incomingRows[0].cells[0].variant, "mission_core");
assert.equal(level.incomingRows[0].launchers.length, 1);
assert.equal(level.incomingRows[0].launchers[0].direction, "down_left");

const result = M.validateLevel(level);
assert.equal(result.valid, true, result.errors.join("; "));
assert.doesNotMatch(result.errors.join("\n"), /incoming mission objectives are not supported/i);
assert.match(result.warnings.join("\n"), /future rows/i);

const exported = JSON.parse(M.toExportJson(level));
assert.equal(exported.incomingRows[0].cells[0].variant, "mission_core");
assert.equal(exported.incomingRows[0].launchers[0].id, "incoming_launcher_1");
assert.equal(exported.rules.winCondition, "destroy_all_objectives");
assert.equal(exported.rules.loseCondition, "block_reaches_launch_line");
assert.equal(Object.hasOwn(exported.rules, "moveLimit"), false);

const topRowOnly = M.validateLevel({
  ...M.createDefaultLevel(),
  levelId: "top_row_only",
  name: "Top row only",
  rules: { mode: "descent", startingBalls: 2 },
  initialBoard: [],
  topRow: [
    { kind:"block", shape:"square", variant:"mission_core", hp:5, column:3 }
  ],
  incomingRows: [
    { afterMove:1, cells:[{ kind:"block", shape:"square", variant:"mission_core", hp:7, column:1 }] }
  ]
});
assert.equal(topRowOnly.valid, true, topRowOnly.errors.join("; "));
assert.equal(M.missionBlockCount(topRowOnly.level), 2);
assert.doesNotMatch(topRowOnly.errors.join("\n"), /initial board needs at least one block/i);

const duplicate = M.validateLevel({
  ...level,
  mechanics: {
    ...level.mechanics,
    launchers: [{ id:"incoming_launcher_1", column:1, row:1, direction:"up" }]
  }
});
assert.equal(duplicate.valid, false);
assert.match(duplicate.errors.join("\n"), /Duplicate mechanic id/i);

console.log("RYKO descending row entities validation: PASS");
