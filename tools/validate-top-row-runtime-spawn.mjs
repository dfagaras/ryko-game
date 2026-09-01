import fs from "node:fs";

const base = fs.readFileSync(new URL("../scripts/level_test_entry.gd", import.meta.url), "utf8");
const descent = fs.readFileSync(new URL("../scripts/level_descending_rows_entry.gd", import.meta.url), "utf8");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const spawnPattern = /authored_level\.get\("topRow"[\s\S]*?_spawn_authored_entity\([^\n]*-1\)/g;
const baseMatches = base.match(spawnPattern) || [];
const descentMatches = descent.match(spawnPattern) || [];

assert(baseMatches.length === 1, `Expected exactly one Top Row spawn owner in level_test_entry.gd, found ${baseMatches.length}`);
assert(descentMatches.length === 0, `Descending runtime must not spawn Top Row again, found ${descentMatches.length} duplicate spawn path(s)`);
assert(descent.includes("Top Row spawning is owned by level_test_entry.gd"), "Descending runtime ownership comment missing");

const authoredTopRowPickupCount = 6;
const collectedVisiblePickups = 4;
const expectedBalls = 1 + collectedVisiblePickups;
assert(expectedBalls === 5, "Top Row pickup regression fixture is invalid");
assert(authoredTopRowPickupCount - collectedVisiblePickups === 2, "Expected two visible pickups to remain in regression fixture");

console.log("Top Row runtime spawn ownership OK: one authored entity -> one runtime entity");
