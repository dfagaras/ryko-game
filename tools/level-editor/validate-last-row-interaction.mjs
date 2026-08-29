import fs from "node:fs";

const ui = fs.readFileSync(new URL("./mechanics-ui.js", import.meta.url), "utf8");
const css = fs.readFileSync(new URL("./styles.css", import.meta.url), "utf8");

if (!ui.includes("document.addEventListener('pointerdown',placeArmedMechanic,true)")) {
  throw new Error("Mechanic placement must use pointerdown capture so bottom-row input is handled before click/decorative handlers.");
}
if (!ui.includes("resolvePlacementCell")) {
  throw new Error("Mechanic placement must resolve a board cell geometrically when the direct event target is not the cell.");
}
if (!/\.launch-line\s*\{[^}]*pointer-events:\s*none/s.test(css)) {
  throw new Error("Launch/danger line must not intercept pointer input from the final board row.");
}

console.log("Last-row interaction contract passed: pointerdown capture, geometric cell resolution, noninteractive launch line.");
