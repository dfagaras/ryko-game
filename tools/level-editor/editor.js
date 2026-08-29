(() => {
  "use strict";

  const M = window.RykoLevelModel;
  const STORAGE_KEY = "ryko-level-editor-v1";

  const TOOLS = [
    { id: "select", label: "Select", sub: "Edit existing", glyph: "⌖" },
    { id: "erase", label: "Eraser", sub: "Remove cell", glyph: "×" },
    { id: "square", label: "Normal", sub: "Square", kind: "block", shape: "square", variant: "normal" },
    { id: "tri_tl", label: "Triangle TL", sub: "Normal", kind: "block", shape: "triangle", variant: "normal", orientation: "top_left" },
    { id: "tri_tr", label: "Triangle TR", sub: "Normal", kind: "block", shape: "triangle", variant: "normal", orientation: "top_right" },
    { id: "tri_bl", label: "Triangle BL", sub: "Normal", kind: "block", shape: "triangle", variant: "normal", orientation: "bottom_left" },
    { id: "tri_br", label: "Triangle BR", sub: "Normal", kind: "block", shape: "triangle", variant: "normal", orientation: "bottom_right" },
    { id: "dense", label: "Double Metal", sub: "Dense", kind: "block", shape: "square", variant: "dense", art: "block_dense.png" },
    { id: "regen", label: "Regenerative", sub: "+50% surviving HP", kind: "block", shape: "square", variant: "regenerative", art: "block_regenerative.png" },
    { id: "phase", label: "Phase", sub: "Solid / intangible", kind: "block", shape: "square", variant: "phase", art: "block_phase.png" },
    { id: "black_hole", label: "Black Hole", sub: "Absorbing sides", kind: "block", shape: "square", variant: "black_hole", art: "block_black_hole.png" },
    { id: "plus_ball", label: "+ Ball", sub: "Next volley +1", kind: "pickup", type: "plus_ball", art: "power_plus_one.png" },
    { id: "ion_h", label: "Ion H", sub: "Horizontal beam", kind: "power", type: "ion", orientation: "horizontal", art: "power_ion.png" },
    { id: "ion_v", label: "Ion V", sub: "Vertical beam", kind: "power", type: "ion", orientation: "vertical", art: "power_ion.png" },
    { id: "ghost", label: "Ghost Core", sub: "Pass through blocks", kind: "power", type: "ghost", art: "power_ghost.png" },
    { id: "supernova", label: "Supernova", sub: "20% charged balls", kind: "power", type: "supernova", art: "power_supernova.png" }
  ];

  const els = Object.fromEntries([
    "levelId", "levelName", "modeSelect", "startingBalls", "moveLimit", "moveLimitField", "modeNote", "defaultHp",
    "toolbox", "blackHolePlacementFields", "boardGrid", "boardTitle", "clearBoardButton", "previewButton", "resetPreviewButton", "boardStatus",
    "timelineCard", "timelineTabs", "addIncomingButton", "incomingEditor", "incomingEditorLabel", "removeIncomingButton",
    "incomingStrip", "incomingSlotLabel", "selectionEmpty", "selectionEditor", "selectionName", "hpField", "selectedHp",
    "blackHoleFields", "deleteSelectedButton", "validationSummary", "validationList", "jsonPreview", "loseContract",
    "importButton", "copyButton", "downloadButton", "fileInput", "toast"
  ].map((id) => [id, document.getElementById(id)]));

  let level = loadDraft();
  let activeTool = "select";
  let selected = null;
  let activeIncomingIndex = 0;
  let previewMoves = 0;

  function assetUrl(filename) {
    const inRepoToolPath = window.location.protocol === "file:" || window.location.pathname.includes("/tools/level-editor/");
    return `${inRepoToolPath ? "../../assets/icons/" : "assets/icons/"}${filename}`;
  }

  function loadDraft() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) return M.normalizeLevel(JSON.parse(raw));
    } catch (error) {
      console.warn("Could not load editor draft", error);
    }
    return M.createDefaultLevel();
  }

  function saveDraft() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(level)); } catch (error) { console.warn("Could not save editor draft", error); }
  }

  function showToast(message) {
    els.toast.textContent = message;
    els.toast.classList.add("show");
    clearTimeout(showToast.timer);
    showToast.timer = setTimeout(() => els.toast.classList.remove("show"), 1600);
  }

  function blackHolePlacementSides() {
    if (!els.blackHolePlacementFields) return ["top"];
    const sides = [...els.blackHolePlacementFields.querySelectorAll('input[type="checkbox"]:checked')].map((input) => input.value);
    return sides.length ? sides : ["top"];
  }

  function buildToolbox() {
    els.toolbox.innerHTML = "";
    for (const tool of TOOLS) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `tool${tool.id === activeTool ? " active" : ""}`;
      button.dataset.tool = tool.id;
      const icon = document.createElement("span");
      icon.className = "tool-icon";
      if (tool.art) {
        const image = document.createElement("img");
        image.src = assetUrl(tool.art);
        image.alt = "";
        if (tool.id === "ion_v") image.style.transform = "rotate(90deg)";
        icon.appendChild(image);
      } else if (tool.id.startsWith("tri_")) {
        const sample = makeEntityElement({ kind: "block", shape: "triangle", variant: "normal", orientation: tool.orientation, hp: "" }, true);
        icon.appendChild(sample);
      } else if (tool.id === "square") {
        const sample = makeEntityElement({ kind: "block", shape: "square", variant: "normal", hp: "" }, true);
        icon.appendChild(sample);
      } else {
        icon.textContent = tool.glyph;
        icon.style.fontSize = "22px";
        icon.style.color = tool.id === "erase" ? "var(--coral)" : "var(--aqua)";
      }
      const text = document.createElement("span");
      text.innerHTML = `<div class="tool-label">${tool.label}</div><div class="tool-sub">${tool.sub || ""}</div>`;
      button.append(icon, text);
      button.addEventListener("click", () => {
        activeTool = tool.id;
        buildToolbox();
      });
      els.toolbox.appendChild(button);
    }
    if (els.blackHolePlacementFields) els.blackHolePlacementFields.hidden = activeTool !== "black_hole";
  }

  function makeEntityElement(entity, tiny = false) {
    const wrapper = document.createElement("div");
    const classes = ["entity"];
    if (entity.kind === "block") {
      classes.push("block", entity.shape || "square", entity.variant || "normal");
      if (entity.shape === "triangle") classes.push(entity.orientation || "top_left");
    } else classes.push(entity.kind, entity.type || "");
    wrapper.className = classes.join(" ");

    let art = null;
    if (entity.kind === "block") {
      art = {
        dense: "block_dense.png",
        regenerative: "block_regenerative.png",
        phase: "block_phase.png",
        black_hole: "block_black_hole.png"
      }[entity.variant];
    } else if (entity.kind === "pickup") art = "power_plus_one.png";
    else if (entity.kind === "power") art = { ion: "power_ion.png", ghost: "power_ghost.png", supernova: "power_supernova.png" }[entity.type];

    if (art) {
      const image = document.createElement("img");
      image.className = "entity-art";
      image.src = assetUrl(art);
      image.alt = "";
      if (entity.kind === "power" && entity.type === "ion" && entity.orientation === "vertical") image.style.transform = "rotate(90deg)";
      wrapper.appendChild(image);
    }

    if (entity.kind === "block" && entity.variant === "black_hole") {
      for (const side of entity.absorbingSides || []) {
        const marker = document.createElement("i");
        marker.className = `black-hole-side ${side}`;
        wrapper.appendChild(marker);
      }
    }

    if (entity.kind === "block" && entity.hp !== "") {
      const hp = document.createElement("span");
      hp.className = "hp";
      hp.textContent = entity.hp;
      wrapper.appendChild(hp);
    }
    if (tiny) { wrapper.style.width = "34px"; wrapper.style.height = "34px"; }
    return wrapper;
  }

  function entityAtInitial(column, row, entities = level.initialBoard) {
    return entities.find((item) => item.column === column && item.row === row) || null;
  }

  function incomingEntityAt(rowIndex, column) {
    return level.incomingRows[rowIndex]?.cells.find((item) => item.column === column) || null;
  }

  function renderBoard() {
    const isDescent = level.rules.mode === M.MODES.DESCENT;
    const preview = isDescent && previewMoves > 0 ? M.simulateDescent(level, previewMoves) : null;
    const boardEntities = preview ? preview.entities : level.initialBoard;
    els.boardGrid.innerHTML = "";
    for (let row = 0; row < M.BOARD.rows; row += 1) {
      for (let column = 0; column < M.BOARD.columns; column += 1) {
        const cell = document.createElement("div");
        cell.className = "board-cell";
        cell.dataset.column = column;
        cell.dataset.row = row;
        if (!preview && selected?.scope === "initial" && selected.column === column && selected.row === row) cell.classList.add("selected");
        if (preview && row === M.BOARD.rows - 1 && entityAtInitial(column, row, boardEntities)?.kind === "block") cell.classList.add("preview-danger");
        const index = document.createElement("span");
        index.className = "cell-index";
        index.textContent = `${row + 1}.${column + 1}`;
        cell.appendChild(index);
        const entity = entityAtInitial(column, row, boardEntities);
        if (entity) cell.appendChild(makeEntityElement(entity));
        cell.addEventListener("click", () => {
          if (preview) return;
          handleCellClick("initial", column, row);
        });
        els.boardGrid.appendChild(cell);
      }
    }

    els.boardTitle.textContent = preview ? `Preview after ${previewMoves} move${previewMoves === 1 ? "" : "s"}` : "Initial board";
    els.previewButton.hidden = !isDescent;
    els.resetPreviewButton.hidden = !isDescent || previewMoves === 0;
    els.incomingStrip.hidden = !isDescent || previewMoves === 0;
    els.incomingSlotLabel.hidden = els.incomingStrip.hidden;
    if (preview) {
      els.boardStatus.textContent = preview.danger ? `Danger: a block reached the launch line by move ${preview.dangerAtMove}.` : `Static descent preview: ${previewMoves} completed move(s). Destruction is not simulated.`;
      els.boardStatus.className = `board-status${preview.danger ? " danger" : ""}`;
      renderPreviewIncoming();
    } else {
      els.boardStatus.textContent = isDescent ? "Each completed volley shifts every surviving entity down by exactly one row." : `Player must clear the authored board within ${level.rules.moveLimit} moves. The board does not descend.`;
      els.boardStatus.className = "board-status";
    }
  }

  function renderPreviewIncoming() {
    els.incomingStrip.innerHTML = "";
    const next = level.incomingRows[previewMoves];
    for (let column = 0; column < M.BOARD.columns; column += 1) {
      const cell = document.createElement("div");
      cell.className = "incoming-cell";
      const entity = next?.cells.find((item) => item.column === column);
      if (entity) cell.appendChild(makeEntityElement(entity));
      els.incomingStrip.appendChild(cell);
    }
    els.incomingSlotLabel.textContent = next ? `NEXT AUTHORED ROW // AFTER MOVE ${previewMoves + 1}` : "NO MORE AUTHORED ROWS";
  }

  function renderIncomingEditor() {
    if (level.rules.mode !== M.MODES.DESCENT) return;
    els.timelineTabs.innerHTML = "";
    if (level.incomingRows.length === 0) {
      activeIncomingIndex = 0;
      els.incomingEditorLabel.textContent = "No incoming rows yet";
      els.incomingEditor.innerHTML = "";
      for (let column = 0; column < M.BOARD.columns; column += 1) {
        const cell = document.createElement("div");
        cell.className = "incoming-cell";
        cell.title = "Add the first incoming row";
        cell.addEventListener("click", () => {
          level.incomingRows.push({ afterMove: 1, cells: [] });
          activeIncomingIndex = 0;
          handleCellClick("incoming", column, 0, 0);
        });
        els.incomingEditor.appendChild(cell);
      }
      els.removeIncomingButton.disabled = true;
      return;
    }
    els.removeIncomingButton.disabled = false;
    activeIncomingIndex = Math.min(activeIncomingIndex, level.incomingRows.length - 1);
    level.incomingRows.forEach((rowDef, index) => {
      rowDef.afterMove = index + 1;
      const button = document.createElement("button");
      button.type = "button";
      button.className = `timeline-tab${index === activeIncomingIndex ? " active" : ""}`;
      button.textContent = `+${index + 1}${rowDef.cells.length ? ` · ${rowDef.cells.length}` : " · blank"}`;
      button.addEventListener("click", () => { activeIncomingIndex = index; selected = null; renderAll(); });
      els.timelineTabs.appendChild(button);
    });

    els.incomingEditorLabel.textContent = `Incoming after move ${activeIncomingIndex + 1}`;
    els.incomingEditor.innerHTML = "";
    for (let column = 0; column < M.BOARD.columns; column += 1) {
      const cell = document.createElement("div");
      cell.className = "incoming-cell";
      if (selected?.scope === "incoming" && selected.rowIndex === activeIncomingIndex && selected.column === column) cell.classList.add("selected");
      const entity = incomingEntityAt(activeIncomingIndex, column);
      if (entity) cell.appendChild(makeEntityElement(entity));
      cell.addEventListener("click", () => handleCellClick("incoming", column, 0, activeIncomingIndex));
      els.incomingEditor.appendChild(cell);
    }
  }

  function toolEntity(toolId, column, row) {
    const tool = TOOLS.find((item) => item.id === toolId);
    if (!tool || !tool.kind) return null;
    if (tool.kind === "block") {
      const entity = {
        kind: "block",
        shape: tool.shape,
        variant: tool.variant,
        hp: Math.max(1, Number.parseInt(els.defaultHp.value, 10) || 1),
        column,
        row
      };
      if (tool.shape === "triangle") entity.orientation = tool.orientation;
      if (tool.variant === "black_hole") entity.absorbingSides = blackHolePlacementSides();
      if (tool.variant === "phase") entity.phaseActive = true;
      return entity;
    }
    if (tool.kind === "pickup") return { kind: "pickup", type: "plus_ball", column, row };
    const power = { kind: "power", type: tool.type, column, row };
    if (tool.type === "ion") power.orientation = tool.orientation;
    return power;
  }

  function handleCellClick(scope, column, row, rowIndex = null) {
    const existing = scope === "initial" ? entityAtInitial(column, row) : incomingEntityAt(rowIndex, column);
    if (activeTool === "select") {
      selected = existing ? { scope, column, row, rowIndex } : null;
      renderAll();
      return;
    }

    if (activeTool === "erase") {
      removeEntity(scope, column, row, rowIndex);
      selected = null;
      commitChange();
      return;
    }

    const entity = toolEntity(activeTool, column, row);
    if (!entity) return;
    removeEntity(scope, column, row, rowIndex);
    if (scope === "initial") level.initialBoard.push(entity);
    else level.incomingRows[rowIndex].cells.push({ ...entity, row: 0 });
    selected = { scope, column, row, rowIndex };
    commitChange();
  }

  function removeEntity(scope, column, row, rowIndex = null) {
    if (scope === "initial") level.initialBoard = level.initialBoard.filter((item) => !(item.column === column && item.row === row));
    else if (level.incomingRows[rowIndex]) level.incomingRows[rowIndex].cells = level.incomingRows[rowIndex].cells.filter((item) => item.column !== column);
  }

  function getSelectedEntity() {
    if (!selected) return null;
    return selected.scope === "initial" ? entityAtInitial(selected.column, selected.row) : incomingEntityAt(selected.rowIndex, selected.column);
  }

  function renderSelection() {
    const entity = getSelectedEntity();
    els.selectionEmpty.hidden = Boolean(entity);
    els.selectionEditor.hidden = !entity;
    if (!entity) return;

    const name = entity.kind === "block"
      ? entity.shape === "triangle" ? `Triangle ${entity.orientation.replace("_", " ")}` : entity.variant.replace("_", " ")
      : entity.kind === "pickup" ? "+ Ball" : entity.type === "ion" ? `Ion ${entity.orientation}` : entity.type;
    els.selectionName.textContent = name.toUpperCase();
    els.hpField.hidden = entity.kind !== "block";
    if (entity.kind === "block") els.selectedHp.value = entity.hp;
    els.blackHoleFields.hidden = !(entity.kind === "block" && entity.variant === "black_hole");
    if (!els.blackHoleFields.hidden) {
      const sides = new Set(entity.absorbingSides || []);
      els.blackHoleFields.querySelectorAll("input[type=checkbox]").forEach((checkbox) => { checkbox.checked = sides.has(checkbox.value); });
    }
  }

  function renderMeta() {
    els.levelId.value = level.levelId;
    els.levelName.value = level.name;
    els.modeSelect.value = level.rules.mode;
    els.startingBalls.value = level.rules.startingBalls;
    els.moveLimit.value = level.rules.moveLimit;
    const descent = level.rules.mode === M.MODES.DESCENT;
    els.moveLimitField.hidden = descent;
    els.timelineCard.hidden = !descent;
    els.modeNote.textContent = descent
      ? "Puzzle board + authored future rows. After every volley all surviving content moves down exactly one row; reaching the launch line loses the level."
      : "All authored pieces start on the board. No descent and no row spawning; clear everything before the move limit expires.";
    els.loseContract.querySelector("dd").textContent = descent ? "Block reaches launch line" : `Exceed ${level.rules.moveLimit} moves`;
  }

  function renderValidation() {
    const result = M.validateLevel(level);
    els.validationSummary.className = `validation-summary ${result.valid ? "ok" : "error"}`;
    els.validationSummary.textContent = result.valid ? "✓ Level contract valid" : `✕ ${result.errors.length} blocking issue${result.errors.length === 1 ? "" : "s"}`;
    els.validationList.innerHTML = "";
    for (const message of result.errors) addValidationItem(message, "error");
    for (const message of result.warnings) addValidationItem(message, "warning");
    if (!result.errors.length && !result.warnings.length) addValidationItem("No warnings. JSON is ready for the Ryko level loader.", "ok");
    els.jsonPreview.textContent = M.toExportJson(level);
  }

  function addValidationItem(message, type) {
    const item = document.createElement("div");
    item.className = `validation-item ${type}`;
    item.textContent = `${type === "error" ? "ERROR" : type === "warning" ? "WARN" : "OK"} // ${message}`;
    els.validationList.appendChild(item);
  }

  function renderAll() {
    level = M.normalizeLevel(level);
    renderMeta();
    buildToolbox();
    renderBoard();
    renderIncomingEditor();
    renderSelection();
    renderValidation();
    saveDraft();
  }

  function commitChange() {
    previewMoves = 0;
    renderAll();
  }

  function updateMetaFromInputs() {
    level.levelId = els.levelId.value.trim();
    level.name = els.levelName.value.trim();
    level.rules.mode = els.modeSelect.value === M.MODES.DESCENT ? M.MODES.DESCENT : M.MODES.CLEAR_LIMITED;
    level.rules.startingBalls = Math.max(1, Number.parseInt(els.startingBalls.value, 10) || 1);
    level.rules.moveLimit = Math.max(1, Number.parseInt(els.moveLimit.value, 10) || 1);
    level.rules.loseCondition = level.rules.mode === M.MODES.DESCENT ? "block_reaches_launch_line" : "move_limit";
    selected = null;
    commitChange();
  }

  [els.levelId, els.levelName, els.modeSelect, els.startingBalls, els.moveLimit].forEach((input) => input.addEventListener("change", updateMetaFromInputs));
  [els.levelId, els.levelName].forEach((input) => input.addEventListener("input", () => {
    level.levelId = els.levelId.value;
    level.name = els.levelName.value;
    renderValidation();
    saveDraft();
  }));

  els.clearBoardButton.addEventListener("click", () => {
    if (!window.confirm("Clear the entire initial board?")) return;
    level.initialBoard = [];
    selected = null;
    commitChange();
  });

  els.previewButton.addEventListener("click", () => {
    previewMoves += 1;
    selected = null;
    renderAll();
  });
  els.resetPreviewButton.addEventListener("click", () => { previewMoves = 0; renderAll(); });

  els.addIncomingButton.addEventListener("click", () => {
    level.incomingRows.push({ afterMove: level.incomingRows.length + 1, cells: [] });
    activeIncomingIndex = level.incomingRows.length - 1;
    selected = null;
    commitChange();
  });
  els.removeIncomingButton.addEventListener("click", () => {
    if (level.incomingRows.length === 0) return;
    level.incomingRows.splice(activeIncomingIndex, 1);
    activeIncomingIndex = Math.max(0, activeIncomingIndex - 1);
    selected = null;
    commitChange();
  });

  els.selectedHp.addEventListener("change", () => {
    const entity = getSelectedEntity();
    if (!entity || entity.kind !== "block") return;
    entity.hp = Math.max(1, Number.parseInt(els.selectedHp.value, 10) || 1);
    commitChange();
  });
  els.blackHoleFields.querySelectorAll("input[type=checkbox]").forEach((checkbox) => checkbox.addEventListener("change", () => {
    const entity = getSelectedEntity();
    if (!entity || entity.kind !== "block" || entity.variant !== "black_hole") return;
    entity.absorbingSides = [...els.blackHoleFields.querySelectorAll("input[type=checkbox]:checked")].map((input) => input.value);
    commitChange();
  }));
  els.deleteSelectedButton.addEventListener("click", () => {
    if (!selected) return;
    removeEntity(selected.scope, selected.column, selected.row, selected.rowIndex);
    selected = null;
    commitChange();
  });

  els.copyButton.addEventListener("click", async () => {
    const result = M.validateLevel(level);
    if (!result.valid) return showToast("Fix validation errors first");
    try {
      await navigator.clipboard.writeText(M.toExportJson(level));
      showToast("JSON copied");
    } catch {
      showToast("Clipboard blocked by browser");
    }
  });

  els.downloadButton.addEventListener("click", () => {
    const result = M.validateLevel(level);
    if (!result.valid) return showToast("Fix validation errors first");
    const blob = new Blob([M.toExportJson(level)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${level.levelId.replace(/[^a-z0-9_-]/gi, "_") || "ryko_level"}.json`;
    a.click();
    URL.revokeObjectURL(url);
    showToast("JSON downloaded");
  });

  els.importButton.addEventListener("click", () => els.fileInput.click());
  els.fileInput.addEventListener("change", async () => {
    const file = els.fileInput.files?.[0];
    if (!file) return;
    try {
      const parsed = JSON.parse(await file.text());
      if (Number(parsed.schemaVersion ?? 1) !== M.SCHEMA_VERSION) throw new Error(`Unsupported schemaVersion ${parsed.schemaVersion}`);
      level = M.normalizeLevel(parsed);
      activeIncomingIndex = 0;
      selected = null;
      previewMoves = 0;
      renderAll();
      showToast("Level imported");
    } catch (error) {
      window.alert(`Could not import this level: ${error.message}`);
    } finally {
      els.fileInput.value = "";
    }
  });

  renderAll();
})();
