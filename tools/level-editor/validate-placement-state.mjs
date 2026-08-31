import fs from "node:fs";
import vm from "node:vm";

const state = fs.readFileSync(new URL("./placement-state.js", import.meta.url), "utf8");
const index = fs.readFileSync(new URL("./index.html", import.meta.url), "utf8");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const editorIndex = index.indexOf('<script src="editor.js"></script>');
const stateIndex = index.indexOf('<script src="placement-state.js"></script>');
const missionIndex = index.indexOf('<script src="mission-block-ui.js"></script>');
assert(editorIndex >= 0 && stateIndex > editorIndex, "placement-state.js must load after editor.js");
assert(missionIndex > stateIndex, "placement-state.js must load before mission-block-ui.js");

const storage = new Map([
  ["ryko-placement-tool", "square"],
  ["ryko-placement-hp", "37"]
]);
const listeners = {};
let restoredClicks = 0;

const defaultHp = {
  value: "10",
  addEventListener(type, handler) { listeners[`hp:${type}`] = handler; }
};
const squareButton = {
  dataset: { tool: "square" },
  classList: { contains: () => false },
  click() { restoredClicks += 1; }
};
const regenButton = {
  dataset: { tool: "regen" },
  classList: { contains: () => false },
  click() {}
};
const toolbox = {
  querySelectorAll() { return [squareButton, regenButton]; }
};
const documentListeners = {};
const document = {
  getElementById(id) {
    if (id === "defaultHp") return defaultHp;
    if (id === "toolbox") return toolbox;
    return null;
  },
  addEventListener(type, handler) { documentListeners[type] = handler; }
};
const sessionStorage = {
  getItem(key) { return storage.has(key) ? storage.get(key) : null; },
  setItem(key, value) { storage.set(key, String(value)); },
  removeItem(key) { storage.delete(key); }
};

vm.runInNewContext(state, {
  document,
  sessionStorage,
  Number,
  Math,
  String,
  queueMicrotask(callback) { callback(); }
});

assert(defaultHp.value === "37", "Default HP was not restored after reload");
assert(restoredClicks === 1, "Selected placement tool was not restored after reload");

defaultHp.value = "42";
listeners["hp:input"]();
assert(storage.get("ryko-placement-hp") === "42", "Changed Default HP was not persisted");

documentListeners.click({
  target: { closest: () => regenButton }
});
assert(storage.get("ryko-placement-tool") === "regen", "Changed placement tool was not persisted");

documentListeners.click({
  target: { closest: () => ({ dataset: { tool: "mission_core" } }) }
});
assert(!storage.has("ryko-placement-tool"), "Mission Core must clear the base-tool restore state");

console.log("Placement state reload behavior OK: tool + HP persist");
