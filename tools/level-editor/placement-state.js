(() => {
  "use strict";

  const TOOL_KEY = "ryko-placement-tool";
  const HP_KEY = "ryko-placement-hp";
  const MISSION_KEY = "ryko-mission-tool-active";
  const defaultHp = document.getElementById("defaultHp");
  const toolbox = document.getElementById("toolbox");
  if (!defaultHp || !toolbox) return;

  const storedHp = sessionStorage.getItem(HP_KEY);
  if (storedHp !== null) defaultHp.value = storedHp;

  function rememberHp() {
    const hp = Math.max(1, Number.parseInt(defaultHp.value || "1", 10) || 1);
    sessionStorage.setItem(HP_KEY, String(hp));
  }

  function restoreTool() {
    if (sessionStorage.getItem(MISSION_KEY) === "1") return;
    const toolId = sessionStorage.getItem(TOOL_KEY);
    if (!toolId) return;
    const button = [...toolbox.querySelectorAll(".tool[data-tool]")].find((tool) => tool.dataset.tool === toolId);
    if (button && !button.classList.contains("active")) button.click();
  }

  defaultHp.addEventListener("input", rememberHp);
  defaultHp.addEventListener("change", rememberHp);

  document.addEventListener("click", (event) => {
    const tool = event.target.closest?.("#toolbox .tool[data-tool]");
    if (!tool) return;
    if (tool.dataset.tool === "mission_core") {
      sessionStorage.removeItem(TOOL_KEY);
      return;
    }
    sessionStorage.setItem(TOOL_KEY, tool.dataset.tool);
  }, true);

  queueMicrotask(restoreTool);
})();
