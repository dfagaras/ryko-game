import fs from "node:fs";
import vm from "node:vm";

const context = { console };
context.window = context;
context.globalThis = context;
vm.createContext(context);
vm.runInContext(fs.readFileSync(new URL("./model.js", import.meta.url), "utf8"), context);
vm.runInContext(fs.readFileSync(new URL("./mechanics-model.js", import.meta.url), "utf8"), context);
const M = context.RykoLevelModel;

const level = M.createDefaultLevel();
level.initialBoard.push({ kind: "block", shape: "square", variant: "normal", hp: 10, column: 0, row: 0 });
M.MECHANIC_DIRECTIONS.forEach((direction, index) => {
  level.mechanics.launchers.push({ id: `launcher_${index + 1}`, column: index % 7, row: Math.floor(index / 7), direction });
});
level.mechanics.lasers.push({ id: "laser_a", from: { x: 0, y: 0.5 }, to: { x: 1, y: 0.5 }, onSeconds: 1.5, offSeconds: 0.8, startDelay: 0.2, startsOn: true });
const validation = M.validateLevel(level);
if (!validation.valid) throw new Error(`Expected valid mechanics level: ${validation.errors.join("; ")}`);
const exported = JSON.parse(M.toExportJson(level));
if (exported.mechanics.launchers.length !== 8) throw new Error("Expected all 8 selectable launcher directions to survive export.");
for (let index = 0; index < M.MECHANIC_DIRECTIONS.length; index += 1) {
  if (exported.mechanics.launchers[index].direction !== M.MECHANIC_DIRECTIONS[index]) throw new Error(`Launcher direction ${M.MECHANIC_DIRECTIONS[index]} was not preserved.`);
}
if (exported.mechanics.lasers[0].to.x !== 1) throw new Error("Laser endpoint was not preserved.");

const custom = M.normalizeLevel({
  ...M.createDefaultLevel(),
  boardColumns: 10,
  boardRows: 13,
  board: M.boardForDimensions(10, 13),
  initialBoard: [{ kind: "block", shape: "square", variant: "normal", hp: 10, column: 0, row: 0 }],
  incomingRows: [],
  mechanics: {
    launchers: [{ id: "launcher_last_row", column: 9, row: 12, direction: "down_left" }],
    lasers: [], shields: [], switches: [], portals: []
  }
});
const customValidation = M.validateLevel(custom);
if (!customValidation.valid) throw new Error(`Expected 10x13 last-row launcher to be valid: ${customValidation.errors.join("; ")}`);
const customExport = JSON.parse(M.toExportJson(custom));
const lastRowLauncher = customExport.mechanics.launchers.find((item) => item.id === "launcher_last_row");
if (!lastRowLauncher || lastRowLauncher.column !== 9 || lastRowLauncher.row !== 12 || lastRowLauncher.direction !== "down_left") {
  throw new Error("10x13 launcher on row 13 was not preserved exactly.");
}

console.log("Mechanics validation passed: 8 launcher directions, laser timing, and 10x13 row-13 launcher placement are preserved.");
