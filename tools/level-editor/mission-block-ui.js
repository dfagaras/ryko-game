(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M) return;
  const STORAGE_KEY = "ryko-level-editor-v1";
  const MISSION_TOOL = "mission_core";
  const SESSION_KEY = "ryko-mission-tool-active";

  const style = document.createElement("style");
  style.textContent = `
    .entity.block.mission_core{border-color:#55b8b1!important;background:#0c2025!important;overflow:hidden;position:relative}
    .entity.block.mission_core .mission-core-art{position:absolute;inset:0;width:100%;height:100%;object-fit:contain;z-index:1;pointer-events:none}
    .entity.block.mission_core .hp{z-index:2;bottom:2px;top:auto;transform:translateX(-50%);font-size:.78em;color:#f2e3bb;text-shadow:0 1px 2px #020b0e}
    .tool[data-tool="mission_core"] .tool-icon img{width:34px;height:34px;object-fit:contain}
  `;
  document.head.appendChild(style);

  function missionAssetUrl() {
    const inRepoToolPath = window.location.protocol === "file:" || window.location.pathname.includes("/tools/level-editor/");
    return inRepoToolPath ? "../../assets/ui/mission_block/rama%20(2).png" : "assets/ui/mission_block/rama%20(2).png";
  }

  function loadLevel() {
    try { return M.normalizeLevel(JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}")); }
    catch { return M.createDefaultLevel(); }
  }

  function saveLevel(level) {
    sessionStorage.setItem(SESSION_KEY, "1");
    localStorage.setItem(STORAGE_KEY, JSON.stringify(M.normalizeLevel(level)));
    location.reload();
  }

  function missionActive() {
    return document.querySelector('.tool[data-tool="mission_core"]')?.classList.contains("active") === true;
  }

  function addMissionButton() {
    const toolbox = document.getElementById("toolbox");
    if (!toolbox || toolbox.querySelector('.tool[data-tool="mission_core"]')) return;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "tool";
    button.dataset.tool = MISSION_TOOL;
    button.innerHTML = `<span class="tool-icon"><img src="${missionAssetUrl()}" alt=""></span><span><div class="tool-label">Mission Core</div><div class="tool-sub">Square objective</div></span>`;
    button.addEventListener("click", () => {
      toolbox.querySelectorAll(".tool").forEach((tool) => tool.classList.remove("active"));
      button.classList.add("active");
      sessionStorage.setItem(SESSION_KEY, "1");
    });
    const blackHole = toolbox.querySelector('.tool[data-tool="black_hole"]');
    if (blackHole?.nextSibling) toolbox.insertBefore(button, blackHole.nextSibling);
    else toolbox.appendChild(button);
    if (sessionStorage.getItem(SESSION_KEY) === "1") {
      toolbox.querySelectorAll(".tool").forEach((tool) => tool.classList.remove("active"));
      button.classList.add("active");
    }
  }

  function addMissionAt(scope, column, row = 0) {
    const level = loadLevel();
    const hp = Math.max(1, Number.parseInt(document.getElementById("defaultHp")?.value || "1", 10) || 1);
    const entity = { kind:"block", shape:"square", variant:MISSION_TOOL, hp, column, row };
    if (scope === "initial") {
      level.initialBoard = (level.initialBoard || []).filter((item) => !(item.column === column && item.row === row));
      level.initialBoard.push(entity);
    } else {
      level.topRow = (level.topRow || []).filter((item) => item.column !== column);
      const top = { ...entity }; delete top.row;
      level.topRow.push(top);
    }
    saveLevel(level);
  }

  document.addEventListener("click", (event) => {
    const baseTool = event.target.closest?.("#toolbox .tool:not([data-tool='mission_core'])");
    if (baseTool) sessionStorage.removeItem(SESSION_KEY);
  }, true);

  document.addEventListener("click", (event) => {
    if (!missionActive()) return;
    const cell = event.target.closest?.("#boardGrid .board-cell, #topRowGrid .board-cell");
    if (!cell) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    const column = Number(cell.dataset.column);
    if (!Number.isInteger(column)) return;
    if (cell.closest("#topRowGrid")) addMissionAt("top", column);
    else addMissionAt("initial", column, Number(cell.dataset.row));
  }, true);

  function decorateMissionCells() {
    const level = loadLevel();
    const decorate = (cell, entity) => {
      if (entity?.variant !== MISSION_TOOL) return;
      const visual = cell.querySelector(".entity");
      if (!visual || visual.querySelector(".mission-core-art")) return;
      visual.classList.add("mission_core");
      const image = document.createElement("img");
      image.className = "mission-core-art";
      image.src = missionAssetUrl();
      image.alt = "";
      visual.insertBefore(image, visual.firstChild);
    };
    document.querySelectorAll("#boardGrid .board-cell").forEach((cell) => {
      const entity = (level.initialBoard || []).find((item) => item.column === Number(cell.dataset.column) && item.row === Number(cell.dataset.row));
      decorate(cell, entity);
    });
    document.querySelectorAll("#topRowGrid .board-cell").forEach((cell) => {
      const entity = (level.topRow || []).find((item) => item.column === Number(cell.dataset.column));
      decorate(cell, entity);
    });
    const win = document.querySelector(".contract-list > div:nth-child(5) dd");
    if (win) win.textContent = M.missionBlockCount(level) > 0 ? "Destroy all Mission Cores" : "Clear all authored content";
  }

  const toolboxObserver = new MutationObserver(() => addMissionButton());
  const toolbox = document.getElementById("toolbox");
  if (toolbox) toolboxObserver.observe(toolbox, { childList:true });
  addMissionButton();
  decorateMissionCells();
  const boardObserver = new MutationObserver(() => decorateMissionCells());
  const boardGrid = document.getElementById("boardGrid");
  if (boardGrid) boardObserver.observe(boardGrid, { childList:true, subtree:true });
})();
