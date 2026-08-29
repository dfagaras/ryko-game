(() => {
  "use strict";

  const M = window.RykoLevelModel;
  const STORAGE_KEY = "ryko-level-editor-v1";
  const COLOR_KEY = "ryko-block-color";
  const ACTIVE_TOOL_KEY = "ryko-active-tool";
  if (!M) return;

  const css = document.createElement("style");
  css.textContent = `
    .block-color-panel{margin:10px 0 14px;padding:10px;border:1px solid rgba(242,227,187,.16);border-radius:8px;background:rgba(2,11,14,.28)}
    .block-color-swatches{display:grid;grid-template-columns:repeat(6,1fr);gap:6px;margin-top:7px}
    .block-color-swatch{height:29px;border:2px solid transparent;border-radius:6px;padding:0;background:var(--swatch)}
    .block-color-swatch.active{border-color:#f2e3bb;box-shadow:0 0 0 2px rgba(85,184,177,.24)}
    .top-row-label{text-align:center;font-size:9px;letter-spacing:.16em;color:var(--aqua);margin:-4px 0 5px}
    .top-row-grid{display:grid;grid-template-columns:repeat(var(--board-columns,7),var(--cell));grid-auto-rows:var(--cell);gap:var(--gap);margin-bottom:var(--gap)}
    .entity.block.square.normal{border-color:var(--block-accent,var(--amber))!important}
    .entity.triangle::before{background:var(--block-accent,var(--coral))!important}
  `;
  document.head.appendChild(css);

  function assetUrl(filename) {
    const inRepoToolPath = window.location.protocol === "file:" || window.location.pathname.includes("/tools/level-editor/");
    return `${inRepoToolPath ? "../../assets/icons/" : "assets/icons/"}${filename}`;
  }

  function loadLevel() {
    try { return M.normalizeLevel(JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}")); }
    catch { return M.createDefaultLevel(); }
  }

  function rememberActiveTool() {
    const tool = activeTool();
    if (tool) sessionStorage.setItem(ACTIVE_TOOL_KEY, tool);
  }

  function saveAndReload(level) {
    rememberActiveTool();
    localStorage.setItem(STORAGE_KEY, JSON.stringify(M.normalizeLevel(level)));
    location.reload();
  }

  function restoreActiveTool() {
    const remembered = sessionStorage.getItem(ACTIVE_TOOL_KEY);
    if (!remembered) return;
    sessionStorage.removeItem(ACTIVE_TOOL_KEY);
    const button = document.querySelector(`.tool[data-tool="${CSS.escape(remembered)}"]`);
    if (button && !button.classList.contains("active")) button.click();
  }

  function activeColor() {
    const value = localStorage.getItem(COLOR_KEY) || M.DEFAULT_BLOCK_COLOR || "amber";
    return M.BLOCK_COLORS?.[value] ? value : "amber";
  }

  function activeTool() {
    return document.querySelector(".tool.active")?.dataset?.tool || "select";
  }

  function blackHolePlacementSides() {
    const fields = document.getElementById("blackHolePlacementFields");
    const sides = fields ? [...fields.querySelectorAll('input[type="checkbox"]:checked')].map((input) => input.value) : [];
    return sides.length ? sides : ["top"];
  }

  function makeEntity(toolId, column) {
    const hp = Math.max(1, Number.parseInt(document.getElementById("defaultHp")?.value || "1", 10) || 1);
    const color = activeColor();
    if (toolId === "square") return { kind:"block", shape:"square", variant:"normal", hp, column, color };
    const triangles = { tri_tl:"top_left", tri_tr:"top_right", tri_bl:"bottom_left", tri_br:"bottom_right" };
    if (triangles[toolId]) return { kind:"block", shape:"triangle", variant:"normal", orientation:triangles[toolId], hp, column, color };
    if (toolId === "dense") return { kind:"block", shape:"square", variant:"dense", hp, column, color };
    if (toolId === "regen") return { kind:"block", shape:"square", variant:"regenerative", hp, column, color };
    if (toolId === "phase") return { kind:"block", shape:"square", variant:"phase", phaseActive:true, hp, column, color };
    if (toolId === "black_hole") return { kind:"block", shape:"square", variant:"black_hole", absorbingSides:blackHolePlacementSides(), hp, column, color };
    if (toolId === "plus_ball") return { kind:"pickup", type:"plus_ball", column };
    if (toolId === "ion_h") return { kind:"power", type:"ion", orientation:"horizontal", column };
    if (toolId === "ion_v") return { kind:"power", type:"ion", orientation:"vertical", column };
    if (toolId === "ghost") return { kind:"power", type:"ghost", column };
    if (toolId === "supernova") return { kind:"power", type:"supernova", column };
    return null;
  }

  function buildColorPanel() {
    const toolbox = document.getElementById("toolbox");
    if (!toolbox || document.getElementById("blockColorPanel")) return;
    const panel = document.createElement("div");
    panel.id = "blockColorPanel";
    panel.className = "block-color-panel";
    panel.innerHTML = `<div class="field-label">Block color · squares + triangles</div><div class="muted-copy">RYKO palette presets. New blocks use the selected color; select an existing block then choose a swatch to recolor it.</div><div class="block-color-swatches"></div>`;
    const swatches = panel.querySelector(".block-color-swatches");
    for (const [name, hex] of Object.entries(M.BLOCK_COLORS || {})) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `block-color-swatch${name === activeColor() ? " active" : ""}`;
      button.style.setProperty("--swatch", hex);
      button.dataset.color = name;
      button.title = name.replace("_", " ").toUpperCase();
      button.addEventListener("click", () => {
        localStorage.setItem(COLOR_KEY, name);
        const selectedTop = document.querySelector(".top-row-grid .board-cell.selected");
        if (selectedTop) {
          const level = loadLevel();
          const column = Number(selectedTop.dataset.column);
          const block = (level.topRow || []).find((item) => item.kind === "block" && item.column === column);
          if (block) { block.color = name; saveAndReload(level); return; }
        }
        const selected = document.querySelector("#boardGrid .board-cell.selected");
        if (selected) {
          const level = loadLevel();
          const column = Number(selected.dataset.column);
          const row = Number(selected.dataset.row);
          const block = level.initialBoard.find((item) => item.kind === "block" && item.column === column && item.row === row);
          if (block) { block.color = name; saveAndReload(level); return; }
        }
        refreshSwatches();
      });
      swatches.appendChild(button);
    }
    toolbox.parentElement.insertBefore(panel, toolbox);
  }

  function refreshSwatches() {
    document.querySelectorAll(".block-color-swatch").forEach((button) => button.classList.toggle("active", button.dataset.color === activeColor()));
  }

  function decorateEntity(element, entity) {
    if (!element || entity?.kind !== "block") return;
    const colorName = M.normalizeBlockColor?.(entity.color) || "amber";
    element.style.setProperty("--block-accent", M.BLOCK_COLORS[colorName]);
  }

  function decorateMainBoard() {
    const level = loadLevel();
    document.querySelectorAll("#boardGrid .board-cell").forEach((cell) => {
      const entity = level.initialBoard.find((item) => item.column === Number(cell.dataset.column) && item.row === Number(cell.dataset.row));
      decorateEntity(cell.querySelector(".entity"), entity);
    });
  }

  function topRowVisual(entity) {
    const visual = document.createElement("div");
    visual.className = `entity ${entity.kind}${entity.kind === "block" ? ` block ${entity.shape || "square"} ${entity.variant || "normal"} ${entity.orientation || ""}` : ` ${entity.type || ""}`}`;

    let art = null;
    if (entity.kind === "block") {
      art = { dense:"block_dense.png", regenerative:"block_regenerative.png", phase:"block_phase.png", black_hole:"block_black_hole.png" }[entity.variant];
    } else if (entity.kind === "pickup" && entity.type === "plus_ball") {
      art = "power_plus_one.png";
    } else if (entity.kind === "power") {
      art = { ion:"power_ion.png", ghost:"power_ghost.png", supernova:"power_supernova.png" }[entity.type];
    }

    if (art) {
      const image = document.createElement("img");
      image.className = "entity-art";
      image.src = assetUrl(art);
      image.alt = "";
      if (entity.kind === "power" && entity.type === "ion" && entity.orientation === "vertical") image.style.transform = "rotate(90deg)";
      visual.appendChild(image);
    }

    if (entity.kind === "block" && entity.variant === "black_hole") {
      for (const side of entity.absorbingSides || []) {
        const marker = document.createElement("i");
        marker.className = `black-hole-side ${side}`;
        visual.appendChild(marker);
      }
    }

    if (entity.kind === "block") {
      const hp = document.createElement("span");
      hp.className = "hp";
      hp.textContent = entity.hp;
      visual.appendChild(hp);
      decorateEntity(visual, entity);
    }
    return visual;
  }

  function renderTopRow() {
    const boardGrid = document.getElementById("boardGrid");
    if (!boardGrid || document.getElementById("topRowGrid")) return;
    const level = loadLevel();
    const label = document.createElement("div");
    label.className = "top-row-label";
    label.textContent = "TOP PLAYABLE ROW // ABOVE ROW 1";
    const grid = document.createElement("div");
    grid.id = "topRowGrid";
    grid.className = "top-row-grid";
    grid.style.setProperty("--board-columns", String(M.BOARD.columns));
    for (let column = 0; column < M.BOARD.columns; column += 1) {
      const cell = document.createElement("div");
      cell.className = "board-cell";
      cell.dataset.column = String(column);
      cell.innerHTML = `<span class="cell-index">T.${column + 1}</span>`;
      const entity = (level.topRow || []).find((item) => item.column === column);
      if (entity) cell.appendChild(topRowVisual(entity));
      cell.addEventListener("click", () => {
        const tool = activeTool();
        const fresh = loadLevel();
        fresh.topRow = Array.isArray(fresh.topRow) ? fresh.topRow : [];
        const index = fresh.topRow.findIndex((item) => item.column === column);
        if (tool === "select") {
          document.querySelectorAll(".board-cell.selected").forEach((el) => el.classList.remove("selected"));
          if (index >= 0) cell.classList.add("selected");
          return;
        }
        if (tool === "erase") {
          if (index >= 0) fresh.topRow.splice(index, 1);
          saveAndReload(fresh);
          return;
        }
        const entityToAdd = makeEntity(tool, column);
        if (!entityToAdd) return;
        if (index >= 0) fresh.topRow[index] = entityToAdd; else fresh.topRow.push(entityToAdd);
        saveAndReload(fresh);
      });
      grid.appendChild(cell);
    }
    boardGrid.parentElement.insertBefore(label, boardGrid);
    boardGrid.parentElement.insertBefore(grid, boardGrid);
  }

  document.getElementById("clearBoardButton")?.addEventListener("click", () => {
    const level = loadLevel();
    if ((level.topRow || []).length === 0) return;
    level.topRow = [];
    localStorage.setItem(STORAGE_KEY, JSON.stringify(M.normalizeLevel(level)));
  });

  buildColorPanel();
  renderTopRow();
  decorateMainBoard();
  restoreActiveTool();
  const observer = new MutationObserver(() => decorateMainBoard());
  const boardGrid = document.getElementById("boardGrid");
  if (boardGrid) observer.observe(boardGrid, { childList:true, subtree:true });
})();
