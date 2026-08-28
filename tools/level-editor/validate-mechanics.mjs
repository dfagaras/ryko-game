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
level.mechanics.launchers.push({ id: "launcher_a", column: 3, row: 4, direction: "up_right" });
level.mechanics.lasers.push({ id: "laser_a", from: { x: 0, y: 0.5 }, to: { x: 1, y: 0.5 }, onSeconds: 1.5, offSeconds: 0.8, startDelay: 0.2, startsOn: true });
const validation = M.validateLevel(level);
if (!validation.valid) throw new Error(`Expected valid mechanics level: ${validation.errors.join("; ")}`);
const exported = JSON.parse(M.toExportJson(level));
if (exported.mechanics.launchers[0].direction !== "up_right") throw new Error("Launcher direction was not preserved.");
if (exported.mechanics.lasers[0].to.x !== 1) throw new Error("Laser endpoint was not preserved.");
console.log("Mechanics model validation passed.");
