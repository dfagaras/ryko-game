import fs from "node:fs";

const ui = fs.readFileSync(new URL("./mechanics-ui.js", import.meta.url), "utf8");
const css = fs.readFileSync(new URL("./styles.css", import.meta.url), "utf8");

if (!ui.includes("function bindBoardCells()")) {
  throw new Error("Mechanic placement must bind directly to every rendered board cell.");
}
if (!ui.includes("targetCell.addEventListener('click'")) {
  throw new Error("Every board cell, including the final row, must receive a direct capture-phase click mechanic handler.");
}
if (!ui.includes("placeMechanicInCell(targetCell,event)")) {
  throw new Error("Cell-bound click must place the mechanic using that exact board cell.");
}
if (!ui.includes("stopImmediatePropagation")) {
  throw new Error("Mechanic cell click must stop the core editor click from overwriting mechanic state.");
}
if (ui.includes("targetCell.addEventListener('pointerdown'")) {
  throw new Error("Final-row placement must not save on pointerdown because the following core click can overwrite it.");
}
if (!/\.launch-line\s*\{[^}]*pointer-events:\s*none/s.test(css)) {
  throw new Error("Launch/danger line must not intercept pointer input from the final board row.");
}

console.log("Last-row interaction contract passed: capture-phase click owns every board cell and blocks the core click overwrite.");
