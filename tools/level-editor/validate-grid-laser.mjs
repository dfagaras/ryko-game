import fs from "node:fs";
import vm from "node:vm";

const read = (name) => fs.readFileSync(new URL(`./${name}`, import.meta.url), "utf8");
const sandbox = { window: {}, console };
vm.createContext(sandbox);
vm.runInContext(read("model.js"), sandbox);
sandbox.window.RykoLevelModel = sandbox.RykoLevelModel;
vm.runInContext(read("mechanics-model.js"), sandbox);

const M = sandbox.window.RykoLevelModel;
const ui = read("mechanics-ui.js");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const level10x13 = M.normalizeLevel({ boardColumns: 10, boardRows: 13 });
const board10x13 = M.boardForLevel(level10x13);
const r12 = M.laserPointForCell(level10x13, 9, 11);
const r13 = M.laserPointForCell(level10x13, 9, 12);
assert(r12 && r13, "10x13 cell centers must map to laser points.");
assert(Math.abs(r12.x - r13.x) < 1e-12, "Vertical adjacent cells must keep the same normalized X.");
const verticalLogicalDistance = Math.abs(r13.y - r12.y) * (board10x13.launchLineY - board10x13.boardTop);
assert(Math.abs(verticalLogicalDistance - board10x13.rowStep) < 1e-9, "R12→R13 must equal exactly one logical rowStep.");

const level7x9 = M.normalizeLevel({ boardColumns: 7, boardRows: 9 });
const board7x9 = M.boardForLevel(level7x9);
const c1 = M.laserPointForCell(level7x9, 0, 0);
const c2 = M.laserPointForCell(level7x9, 1, 0);
const horizontalLogicalDistance = Math.abs(c2.x - c1.x) * (board7x9.boardRight - board7x9.boardLeft);
assert(Math.abs(horizontalLogicalDistance - board7x9.columnStep) < 1e-9, "C1→C2 must equal exactly one logical columnStep.");
assert(M.laserPointForCell(level10x13, 10, 0) === null, "Out-of-bounds laser columns must be rejected.");
assert(M.laserPointForCell(level10x13, 0, 13) === null, "Out-of-bounds laser rows must be rejected.");

for (const id of ["laserFromColumn", "laserFromRow", "laserToColumn", "laserToRow"]) {
  assert(ui.includes(id), `Laser UI is missing ${id}.`);
}
assert(!ui.includes('id="laserFromX"'), "Old normalized From X input must not remain in the editor UI.");
assert(!ui.includes('id="laserFromY"'), "Old normalized From Y input must not remain in the editor UI.");
assert(ui.includes("M.laserPointForCell"), "Laser creation must convert grid cells through the shared geometry helper.");

console.log("Grid laser checks passed: adjacent cells map to exact board row/column steps while export remains normalized.");
