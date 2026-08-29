import fs from "node:fs";

const read = (name) => fs.readFileSync(new URL(`./${name}`, import.meta.url), "utf8");
const index = read("index.html");
const editor = read("editor.js");
const extras = read("editor-extras.js");
const mechanicsModel = read("mechanics-model.js");
const mechanicsUi = read("mechanics-ui.js");

function requireText(source, text, message) {
  if (!source.includes(text)) throw new Error(message);
}

requireText(index, 'id="blackHolePlacementFields"', "Black Hole placement-side controls are missing from the core editor UI.");
if (index.includes("editor-interaction-fixes.js")) throw new Error("Obsolete interaction patch must not be loaded by the editor.");
requireText(editor, 'entity.absorbingSides = blackHolePlacementSides();', "Normal board Black Hole placement does not use the side selector.");
requireText(extras, "absorbingSides:blackHolePlacementSides()", "Top-row Black Hole placement does not use the side selector.");
requireText(extras, "for (const side of entity.absorbingSides || [])", "Top-row Black Hole does not render its selected absorbing sides.");
requireText(mechanicsModel, "Number(item?.row) === -1 ? -1", "Mechanics model does not preserve the top-row launcher coordinate.");
requireText(mechanicsUi, "isTop?-1:Number(c.dataset.row)", "Launcher UI does not map the top playable row to row -1.");
requireText(mechanicsUi, "document.addEventListener('click',placeArmedMechanic,true)", "Mechanic placement must own the click before the top-row editor handler.");
requireText(mechanicsUi, "x.row===-1?'TOP'", "Top-row launchers are not labelled distinctly in the launcher list.");

console.log("Editor interaction checks passed: launcher supports TOP row and Black Hole side selection is shared by normal and top rows.");
