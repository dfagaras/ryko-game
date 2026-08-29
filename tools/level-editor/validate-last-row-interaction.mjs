import fs from "node:fs";

const ui = fs.readFileSync(new URL("./mechanics-ui.js", import.meta.url), "utf8");
const css = fs.readFileSync(new URL("./styles.css", import.meta.url), "utf8");

if (!ui.includes("function bindBoardCells()")) {
  throw new Error("Mechanic placement must bind directly to every rendered board cell.");
}
if (!ui.includes("targetCell.addEventListener('pointerdown'")) {
  throw new Error("Every board cell, including the final row, must receive a direct pointerdown mechanic handler.");
}
if (!ui.includes("placeMechanicInCell(targetCell,event)")) {
  throw new Error("Cell-bound pointerdown must place the mechanic using that exact board cell.");
}
if (ui.includes("document.addEventListener('pointerdown',placeArmedMechanic,true)")) {
  throw new Error("Global document-level mechanic placement must not be used for final-row handling.");
}
if (!/\.launch-line\s*\{[^}]*pointer-events:\s*none/s.test(css)) {
  throw new Error("Launch/danger line must not intercept pointer input from the final board row.");
}

console.log("Last-row interaction contract passed: direct pointerdown binding on every board cell and noninteractive launch line.");
