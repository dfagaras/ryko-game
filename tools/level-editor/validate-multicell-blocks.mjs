import fs from "node:fs";
import vm from "node:vm";

const read = (name) => fs.readFileSync(new URL(`./${name}`, import.meta.url), "utf8");
const sandbox = { window: {}, console };
vm.createContext(sandbox);
for (const file of ["model.js", "mechanics-model.js", "ball-range-extension.js", "block-color-model.js", "mission-block-model.js", "multicell-block-model.js"]) {
  vm.runInContext(read(file), sandbox);
  if (sandbox.RykoLevelModel && !sandbox.window.RykoLevelModel) sandbox.window.RykoLevelModel = sandbox.RykoLevelModel;
}
const M = sandbox.window.RykoLevelModel;
const assert = (condition, message) => { if (!condition) throw new Error(message); };

function level(columns, rows, initialBoard) {
  return {
    schemaVersion: 1,
    boardColumns: columns,
    boardRows: rows,
    rules: { mode: "clear_limited", startingBalls: 1, moveLimit: 10 },
    initialBoard
  };
}

for (const [columns, rows] of [[7, 9], [10, 13], [14, 18], [28, 36]]) {
  const candidate = level(columns, rows, [
    { column: 0, row: 0, kind: "block", shape: "square", variant: "normal", hp: 20, widthCells: 4, heightCells: 4 },
    { column: 4, row: 0, kind: "block", shape: "square", variant: "normal", hp: 5 }
  ]);
  const result = M.validateLevel(candidate);
  assert(result.valid, `${columns}x${rows}: 4x4 block plus adjacent 1x1 block must be valid: ${result.errors.join(" | ")}`);
  const large = result.level.initialBoard.find((x) => x.column === 0 && x.row === 0);
  assert(large.widthCells === 4 && large.heightCells === 4, `${columns}x${rows}: 4x4 footprint must survive normalization.`);
  assert(M.entityCoveringCell(result.level.initialBoard, 3, 3) === large, `${columns}x${rows}: bottom-right footprint cell must resolve to the large block.`);
  assert(M.entityCoveringCell(result.level.initialBoard, 4, 0)?.hp === 5, `${columns}x${rows}: adjacent 1x1 block must remain independent.`);
}

const overlap = M.validateLevel(level(10, 13, [
  { column: 2, row: 2, kind: "block", shape: "square", variant: "normal", hp: 10, widthCells: 3, heightCells: 3 },
  { column: 4, row: 4, kind: "block", shape: "square", variant: "normal", hp: 5 }
]));
assert(!overlap.valid && overlap.errors.some((x) => x.includes("overlap")), "Overlapping footprints must be rejected.");

const outside = M.validateLevel(level(7, 9, [
  { column: 5, row: 7, kind: "block", shape: "square", variant: "normal", hp: 10, widthCells: 3, heightCells: 3 }
]));
assert(!outside.valid && outside.errors.some((x) => x.includes("outside")), "Footprints extending outside the board must be rejected.");

const mission = M.validateLevel(level(10, 13, [
  { column: 1, row: 1, kind: "block", shape: "square", variant: "mission_core", hp: 30, widthCells: 2, heightCells: 2 }
]));
assert(mission.valid, `2x2 Mission Core must be valid: ${mission.errors.join(" | ")}`);
const missionBlock = mission.level.initialBoard[0];
assert(missionBlock.variant === "mission_core" && missionBlock.widthCells === 2 && missionBlock.heightCells === 2, "Mission Core size and variant must survive normalization.");

const exported = JSON.parse(M.toExportJson(level(14, 18, [
  { column: 3, row: 4, kind: "block", shape: "square", variant: "normal", hp: 99, widthCells: 3, heightCells: 3 }
])));
assert(exported.initialBoard[0].widthCells === 3 && exported.initialBoard[0].heightCells === 3, "Export must persist multi-cell dimensions.");

const runtime = fs.readFileSync(new URL("../../scripts/level_multicell_blocks_entry.gd", import.meta.url), "utf8");
assert(runtime.includes("_multicell_size"), "Runtime must calculate multi-cell collision dimensions from active board geometry.");
assert(runtime.includes("_active_column_step()") && runtime.includes("_active_row_step()"), "Runtime size must scale from active board column/row steps.");
assert(runtime.includes("bottom_row := int(item.get(\"row\", 0)) + int(item.get(\"height_cells\", 1)) - 1"), "Descent danger must use the bottom of the large block.");
assert(runtime.includes("shape.size = _multicell_size(width_cells, height_cells)"), "One collision body must span the complete multi-cell footprint.");

console.log("Multi-cell block checks passed on 7x9, 10x13, 14x18 and 28x36 boards.");
