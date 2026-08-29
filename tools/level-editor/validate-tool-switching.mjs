import fs from "node:fs";

const ui = fs.readFileSync(new URL("./mechanics-ui.js", import.meta.url), "utf8");

function requireText(text, message) {
  if (!ui.includes(text)) throw new Error(message);
}

requireText("toolbox.addEventListener('click'", "Normal toolbox clicks must be observed by mechanics UI.");
requireText("closest('.tool')", "Mechanics UI must only disarm for actual normal editor tools.");
requireText("armed=null", "Selecting a normal editor tool must disarm the active mechanic.");
requireText("sessionStorage.removeItem(ARMED_KEY)", "Selecting a normal editor tool must clear persisted mechanic state.");

console.log("Tool switching contract passed: selecting Select/Erase/block/power disarms active mechanics.");
