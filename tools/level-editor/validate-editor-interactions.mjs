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
requireText(mechanicsUi, 'ARMED_KEY="ryko-mechanic-armed"', "Selected mechanic must persist across editor reloads.");
requireText(mechanicsUi, 'SCROLL_KEY="ryko-editor-scroll-y"', "Editor scroll position must persist across mechanic reloads.");
requireText(mechanicsUi, "sessionStorage.setItem(SCROLL_KEY,String(window.scrollY))", "Mechanic placement does not save the current scroll position.");
requireText(mechanicsUi, "window.scrollTo(0,savedScroll)", "Mechanic placement does not restore the editor scroll position after reload.");
requireText(mechanicsUi, "l.topRow=[]", "Clear Board does not clear the separate top row.");
requireText(mechanicsUi, "l.mechanics={launchers:[],lasers:[],shields:[],switches:[],portals:[]}", "Clear Board does not clear authored mechanics.");

console.log("Editor interaction checks passed: TOP row launcher, Black Hole sides, complete Clear Board, and continuous mechanic placement are preserved.");
