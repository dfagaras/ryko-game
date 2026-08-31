import fs from "node:fs";

const state = fs.readFileSync(new URL("./placement-state.js", import.meta.url), "utf8");
const index = fs.readFileSync(new URL("./index.html", import.meta.url), "utf8");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(state.includes('const TOOL_KEY = "ryko-placement-tool"'), "Placement tool state key missing");
assert(state.includes('const HP_KEY = "ryko-placement-hp"'), "Placement HP state key missing");
assert(state.includes('sessionStorage.setItem(TOOL_KEY, tool.dataset.tool)'), "Tool selection is not persisted");
assert(state.includes('sessionStorage.setItem(HP_KEY, String(hp))'), "Default HP is not persisted");
assert(state.includes('defaultHp.value = storedHp'), "Default HP is not restored after reload");
assert(state.includes('button.click()'), "Base tool is not restored after reload");
assert(state.includes('sessionStorage.getItem(MISSION_KEY) === "1"'), "Mission Core restore guard missing");

const editorIndex = index.indexOf('<script src="editor.js"></script>');
const stateIndex = index.indexOf('<script src="placement-state.js"></script>');
const missionIndex = index.indexOf('<script src="mission-block-ui.js"></script>');
assert(editorIndex >= 0 && stateIndex > editorIndex, "placement-state.js must load after editor.js");
assert(missionIndex > stateIndex, "placement-state.js must load before mission-block-ui.js");

console.log("Placement state persistence contract OK");
