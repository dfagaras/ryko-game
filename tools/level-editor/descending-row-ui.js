(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M?.__descendingRowEntitiesExtended) return;

  const STORAGE_KEY = "ryko-level-editor-v1";
  const ARMED_KEY = "ryko-mechanic-armed";
  const MISSION_TOOL = "mission_core";
  const GL = {up:"↑",up_right:"↗",right:"→",down_right:"↘",down:"↓",down_left:"↙",left:"←",up_left:"↖"};

  const style = document.createElement("style");
  style.textContent = `
    #incomingEditor .incoming-cell{position:relative}
    .descending-launcher-mark{position:absolute;inset:18%;z-index:12;display:grid;place-items:center;border:2px solid var(--aqua);border-radius:50%;background:rgba(7,20,25,.92);color:var(--cream);font-weight:900;pointer-events:none}
  `;
  document.head.appendChild(style);

  function missionAssetUrl() {
    const inRepoToolPath = window.location.protocol === "file:" || window.location.pathname.includes("/tools/level-editor/");
    return inRepoToolPath ? "../../assets/ui/mission_block/rama%20(3).png" : "assets/ui/mission_block/rama%20(3).png";
  }

  function loadLevel() {
    try { return M.normalizeLevel(JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}")); }
    catch { return M.createDefaultLevel(); }
  }

  function saveLevel(level) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(M.normalizeLevel(level)));
    location.reload();
  }

  function activeIncomingIndex() {
    const tabs = [...document.querySelectorAll("#timelineTabs .timeline-tab")];
    const active = tabs.findIndex((tab) => tab.classList.contains("active"));
    return active >= 0 ? active : 0;
  }

  function incomingColumn(cell) {
    return [...cell.parentElement.children].indexOf(cell);
  }

  function ensureIncomingRow(level, rowIndex) {
    while (level.incomingRows.length <= rowIndex) {
      level.incomingRows.push({ afterMove: level.incomingRows.length + 1, cells: [], launchers: [] });
    }
    level.incomingRows[rowIndex].cells ||= [];
    level.incomingRows[rowIndex].launchers ||= [];
    return level.incomingRows[rowIndex];
  }

  function missionActive() {
    return document.querySelector(`#toolbox .tool[data-tool="${MISSION_TOOL}"].active`) != null;
  }

  function eraserActive() {
    return document.querySelector('#toolbox .tool[data-tool="erase"].active') != null;
  }

  function armedLauncher() {
    const armed = sessionStorage.getItem(ARMED_KEY) || "";
    return armed.startsWith("launcher:") ? armed.split(":")[1] : null;
  }

  function placeMission(rowIndex, column) {
    const level = loadLevel();
    const row = ensureIncomingRow(level, rowIndex);
    const hp = Math.max(1, Number.parseInt(document.getElementById("defaultHp")?.value || "1", 10) || 1);
    row.cells = row.cells.filter((item) => Number(item.column) !== column);
    row.cells.push({ kind:"block", shape:"square", variant:MISSION_TOOL, hp, column, row:0 });
    saveLevel(level);
  }

  function placeLauncher(rowIndex, column, direction) {
    const level = loadLevel();
    const row = ensureIncomingRow(level, rowIndex);
    row.launchers = row.launchers.filter((item) => Number(item.column) !== column);
    let suffix = 1;
    const used = new Set([
      ...(level.mechanics?.launchers || []).map((item) => item.id),
      ...level.incomingRows.flatMap((item) => (item.launchers || []).map((launcher) => launcher.id))
    ]);
    let id = `incoming_${rowIndex + 1}_launcher_${suffix}`;
    while (used.has(id)) id = `incoming_${rowIndex + 1}_launcher_${++suffix}`;
    row.launchers.push({ id, column, direction });
    saveLevel(level);
  }

  function eraseIncomingCell(rowIndex, column) {
    const level = loadLevel();
    const row = ensureIncomingRow(level, rowIndex);
    row.cells = row.cells.filter((item) => Number(item.column) !== column);
    row.launchers = row.launchers.filter((item) => Number(item.column) !== column);
    saveLevel(level);
  }

  document.addEventListener("click", (event) => {
    const cell = event.target.closest?.("#incomingEditor .incoming-cell");
    if (!cell) return;
    const column = incomingColumn(cell);
    if (column < 0) return;
    const rowIndex = activeIncomingIndex();

    if (missionActive()) {
      event.preventDefault();
      event.stopImmediatePropagation();
      placeMission(rowIndex, column);
      return;
    }

    const direction = armedLauncher();
    if (direction) {
      event.preventDefault();
      event.stopImmediatePropagation();
      placeLauncher(rowIndex, column, direction);
      return;
    }

    if (eraserActive()) {
      const level = loadLevel();
      const row = level.incomingRows[rowIndex];
      const hasLauncher = (row?.launchers || []).some((item) => Number(item.column) === column);
      if (hasLauncher) {
        event.preventDefault();
        event.stopImmediatePropagation();
        eraseIncomingCell(rowIndex, column);
      }
    }
  }, true);

  function syncLauncherMark(cell, launcher) {
    const existing = cell.querySelector(":scope > .descending-launcher-mark");
    if (!launcher) {
      if (existing) existing.remove();
      return;
    }
    const glyph = GL[launcher.direction] || "↑";
    if (existing) {
      if (existing.textContent !== glyph) existing.textContent = glyph;
      return;
    }
    const mark = document.createElement("div");
    mark.className = "descending-launcher-mark";
    mark.textContent = glyph;
    cell.appendChild(mark);
  }

  function decorateIncoming() {
    const host = document.getElementById("incomingEditor");
    if (!host) return;
    const level = loadLevel();
    const rowIndex = activeIncomingIndex();
    const row = level.incomingRows[rowIndex];
    const cells = [...host.querySelectorAll(".incoming-cell")];

    cells.forEach((cell, column) => {
      const entity = (row?.cells || []).find((item) => Number(item.column) === column);
      if (entity?.variant === MISSION_TOOL) {
        const visual = cell.querySelector(".entity");
        if (visual && !visual.querySelector(".mission-core-art")) {
          visual.classList.add("mission_core");
          const image = document.createElement("img");
          image.className = "mission-core-art";
          image.src = missionAssetUrl();
          image.alt = "";
          visual.insertBefore(image, visual.firstChild);
        }
      }
      const launcher = (row?.launchers || []).find((item) => Number(item.column) === column);
      syncLauncherMark(cell, launcher);
    });

    document.querySelectorAll("#timelineTabs .timeline-tab").forEach((tab, index) => {
      const rowDef = level.incomingRows[index];
      if (!rowDef) return;
      const count = (rowDef.cells || []).length + (rowDef.launchers || []).length;
      const nextText = `+${index + 1}${count ? ` · ${count}` : " · blank"}`;
      if (tab.textContent !== nextText) tab.textContent = nextText;
    });
  }

  function incomingLauncherSignature(level) {
    return (level.incomingRows || []).flatMap((row, rowIndex) =>
      (row.launchers || []).map((launcher) => `${rowIndex}:${launcher.id}:${launcher.column}:${launcher.direction}`)
    ).join("|");
  }

  function appendIncomingLauncherList() {
    const host = document.getElementById("launcherList");
    if (!host) return;
    const level = loadLevel();
    const signature = incomingLauncherSignature(level);
    if (host.dataset.incomingLauncherSignature === signature) return;

    host.querySelectorAll("[data-incoming-launcher='1']").forEach((node) => node.remove());
    level.incomingRows.forEach((row, rowIndex) => {
      (row.launchers || []).forEach((launcher) => {
        const item = document.createElement("div");
        item.className = "validation-item mechanics-list-item";
        item.dataset.incomingLauncher = "1";
        const text = document.createElement("span");
        text.textContent = `${launcher.id} ${GL[launcher.direction] || "↑"} C${launcher.column + 1} INCOMING +${rowIndex + 1}`;
        const button = document.createElement("button");
        button.className = "button danger small";
        button.textContent = "Delete";
        button.onclick = () => {
          const fresh = loadLevel();
          if (fresh.incomingRows[rowIndex]) fresh.incomingRows[rowIndex].launchers = (fresh.incomingRows[rowIndex].launchers || []).filter((item) => item.id !== launcher.id);
          saveLevel(fresh);
        };
        item.append(text, button);
        host.appendChild(item);
      });
    });
    host.dataset.incomingLauncherSignature = signature;
  }

  let scheduled = false;
  function refreshSoon() {
    if (scheduled) return;
    scheduled = true;
    queueMicrotask(() => {
      scheduled = false;
      decorateIncoming();
      appendIncomingLauncherList();
    });
  }

  const incoming = document.getElementById("incomingEditor");
  if (incoming) new MutationObserver(refreshSoon).observe(incoming, { childList:true, subtree:true });
  const tabs = document.getElementById("timelineTabs");
  if (tabs) new MutationObserver(refreshSoon).observe(tabs, { childList:true, subtree:true, attributes:true, attributeFilter:["class"] });
  const launcherList = document.getElementById("launcherList");
  if (launcherList) new MutationObserver(() => {
    if (!launcherList.querySelector("[data-incoming-launcher='1']")) {
      delete launcherList.dataset.incomingLauncherSignature;
      refreshSoon();
    }
  }).observe(launcherList, { childList:true });
  refreshSoon();
})();
