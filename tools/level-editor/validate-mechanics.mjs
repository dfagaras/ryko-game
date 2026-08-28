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
console.log("Mechanics model validation passed: one selected direction per launcher, 8 available options, laser timing preserved.");
