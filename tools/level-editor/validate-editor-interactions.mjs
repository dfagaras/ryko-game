import fs from "node:fs";

const read = (name) => fs.readFileSync(new URL(`./${name}`, import.meta.url), "utf8");
const index = read("index.html");
const editor = read("editor.js");
const mechanics = read("mechanics-ui.js");
const styles = read("styles.css");

function requireText(source, text, message) {
  if (!source.includes(text)) throw new Error(message);
}

requireText(index, 'id="blackHolePlacementFields"', "Black Hole placement-side controls are missing from the core editor UI.");
if (index.includes("editor-interaction-fixes.js")) throw new Error("Obsolete interaction patch must not be loaded by the editor.");
requireText(editor, '"blackHolePlacementFields"', "Core editor is not wired to Black Hole placement controls.");
requireText(editor, 'entity.absorbingSides = blackHolePlacementSides();', "Black Hole sides are not assigned at entity creation time.");
requireText(mechanics, "M.boardForLevel(l)", "Mechanic placement does not validate against the active custom board dimensions.");
requireText(mechanics, "row>=board.rows", "Mechanic placement is missing the active-board row bound check.");
requireText(mechanics, "document.addEventListener('pointerdown',placeArmedMechanic,true)", "Mechanic placement must capture pointerdown at document level so covered final-row cells remain placeable.");
requireText(mechanics, "getBoundingClientRect()", "Mechanic placement must resolve cells geometrically when the direct event target is not the board cell.");
requireText(styles, ".launch-line", "Launch line styles are missing.");
requireText(styles, "pointer-events: none", "Launch line must not intercept pointer input from the final row.");
requireText(mechanics, "l.mechanics.launchers=l.mechanics.launchers.filter", "Launcher placement should replace an existing launcher in the same cell.");

console.log("Editor interaction regression checks passed: Black Hole sides are core-owned and custom-grid launcher placement uses pointerdown, geometric hit testing, and a non-interactive launch line.");
