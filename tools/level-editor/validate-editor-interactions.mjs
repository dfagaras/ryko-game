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
requireText(mechanics, "function bindBoardCells()", "Mechanic placement must bind directly to each rendered board cell.");
requireText(mechanics, "targetCell.addEventListener('click'", "Every rendered board cell must receive a direct capture-phase click mechanic handler.");
requireText(mechanics, "placeMechanicInCell(targetCell,event)", "Cell-bound handler must place the mechanic using that exact cell.");
requireText(mechanics, "stopImmediatePropagation", "Mechanic click handling must stop the core editor cell click from overwriting the saved mechanic.");
if (mechanics.includes("targetCell.addEventListener('pointerdown'")) throw new Error("Mechanic placement must not save on pointerdown because the later core click can overwrite the mechanic state.");
requireText(styles, ".launch-line", "Launch line styles are missing.");
requireText(styles, "pointer-events: none", "Launch line must not intercept pointer input from the final row.");
requireText(mechanics, "l.mechanics.launchers=l.mechanics.launchers.filter", "Launcher placement should replace an existing launcher in the same cell.");
requireText(mechanics, 'ARMED_KEY="ryko-mechanic-armed"', "Mechanic armed state must have a persistent session key.");
requireText(mechanics, "sessionStorage.getItem(ARMED_KEY)", "Armed launcher direction must be restored after editor reload.");
requireText(mechanics, "sessionStorage.setItem(ARMED_KEY,armed)", "Armed launcher direction must be saved before editor reload.");

console.log("Editor interaction regression checks passed: mechanics own the capture-phase cell click, core cell clicks cannot overwrite placement, and armed launcher state survives reloads.");
