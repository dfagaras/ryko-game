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

function near(a, b, epsilon = 1e-9) {
  return Math.abs(a - b) <= epsilon;
}

const level10x13 = M.normalizeLevel({ boardColumns: 10, boardRows: 13 });
const board10x13 = M.boardForLevel(level10x13);
const r1 = M.laserPointForGridLine(level10x13, 5, 0);
const r2 = M.laserPointForGridLine(level10x13, 5, 1);
assert(r1 && r2, "R1 and R2 grid lines must map to laser points.");
assert(Math.abs(r1.x - r2.x) < 1e-12, "Vertical wall must keep the same normalized X.");
const firstRowSpan = Math.abs(r2.y - r1.y) * (board10x13.launchLineY - board10x13.boardTop);
assert(Math.abs(firstRowSpan - board10x13.rowStep) < 1e-9, "R1→R2 must span exactly one authored row step.");
const r13 = M.laserPointForGridLine(level10x13, 5, 12);
const r14 = M.laserPointForGridLine(level10x13, 5, 13);
const lastRowSpan = Math.abs(r14.y - r13.y) * (board10x13.launchLineY - board10x13.boardTop);
assert(Math.abs(lastRowSpan - board10x13.cell) < 1e-9, "R13→R14 must end exactly on the bottom edge of the last row.");

const level7x9 = M.normalizeLevel({ boardColumns: 7, boardRows: 9 });
const board7x9 = M.boardForLevel(level7x9);
const c1 = M.laserPointForGridLine(level7x9, 0, 4);
const c2 = M.laserPointForGridLine(level7x9, 1, 4);
const firstColumnSpan = Math.abs(c2.x - c1.x) * (board7x9.boardRight - board7x9.boardLeft);
assert(Math.abs(firstColumnSpan - board7x9.columnStep) < 1e-9, "C1→C2 must span exactly one authored column step.");
const c7 = M.laserPointForGridLine(level7x9, 6, 4);
const c8 = M.laserPointForGridLine(level7x9, 7, 4);
const lastColumnSpan = Math.abs(c8.x - c7.x) * (board7x9.boardRight - board7x9.boardLeft);
assert(Math.abs(lastColumnSpan - board7x9.cell) < 1e-9, "C7→C8 must end exactly on the right edge of the last column.");

assert(M.laserPointForGridLine(level10x13, 11, 0) === null, "Grid line beyond C11 must be rejected on a 10-column board.");
assert(M.laserPointForGridLine(level10x13, 0, 14) === null, "Grid line beyond R14 must be rejected on a 13-row board.");

// Regression for the exact bug: lasers saved by the old editor used cell centers.
// Normalization must migrate those stale points to the nearest grid boundaries.
const oldFromLogical = {
  x: board7x9.gridX + 3 * board7x9.columnStep + board7x9.cell * 0.5,
  y: board7x9.gridY + 1 * board7x9.rowStep + board7x9.cell * 0.5
};
const oldToLogical = {
  x: board7x9.gridX + 3 * board7x9.columnStep + board7x9.cell * 0.5,
  y: board7x9.gridY + 2 * board7x9.rowStep + board7x9.cell * 0.5
};
const legacyLaserLevel = M.normalizeLevel({
  boardColumns: 7,
  boardRows: 9,
  mechanics: {
    lasers: [{
      id: "legacy_r2_r3",
      from: {
        x: (oldFromLogical.x - board7x9.boardLeft) / (board7x9.boardRight - board7x9.boardLeft),
        y: (oldFromLogical.y - board7x9.boardTop) / (board7x9.launchLineY - board7x9.boardTop)
      },
      to: {
        x: (oldToLogical.x - board7x9.boardLeft) / (board7x9.boardRight - board7x9.boardLeft),
        y: (oldToLogical.y - board7x9.boardTop) / (board7x9.launchLineY - board7x9.boardTop)
      },
      onSeconds: 1.5,
      offSeconds: 1
    }]
  }
});
const migrated = legacyLaserLevel.mechanics.lasers[0];
const expectedFrom = M.laserPointForGridLine(level7x9, 3, 1);
const expectedTo = M.laserPointForGridLine(level7x9, 3, 2);
assert(near(migrated.from.x, expectedFrom.x) && near(migrated.from.y, expectedFrom.y), "Legacy R2 cell-center start must snap to the R2 grid boundary.");
assert(near(migrated.to.x, expectedTo.x) && near(migrated.to.y, expectedTo.y), "Legacy R3 cell-center end must snap to the R3 grid boundary.");

const exactLaserLevel = M.normalizeLevel({
  boardColumns: 7,
  boardRows: 9,
  mechanics: { lasers: [{ id: "exact", from: expectedFrom, to: expectedTo, onSeconds: 1.5, offSeconds: 1 }] }
});
const exact = exactLaserLevel.mechanics.lasers[0];
assert(near(exact.from.x, expectedFrom.x) && near(exact.from.y, expectedFrom.y), "Already-correct grid endpoints must stay unchanged.");
assert(near(exact.to.x, expectedTo.x) && near(exact.to.y, expectedTo.y), "Already-correct grid endpoints must stay unchanged.");

for (const id of ["laserFromColumn", "laserFromRow", "laserToColumn", "laserToRow"]) {
  assert(ui.includes(id), `Laser UI is missing ${id}.`);
}
assert(ui.includes("board.columns+1"), "Laser UI must allow the final vertical grid line after the last column.");
assert(ui.includes("board.rows+1"), "Laser UI must allow the final horizontal grid line after the last row.");
assert(ui.includes("M.laserPointForGridLine"), "Laser creation must convert C/R values as grid-line intersections.");
assert(ui.includes("R1 → R2 spans exactly the first row"), "Laser UI must explain the grid-line contract.");
assert(ui.includes("function laserPreviewPoint"), "Laser preview must map runtime-normalized coordinates back to the rendered grid.");

console.log("Grid-boundary laser checks passed, including migration of legacy cell-center R2→R3 endpoints.");
