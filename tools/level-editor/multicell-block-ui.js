(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M?.__multicellBlocksExtended) return;

  const STORAGE_KEY = "ryko-level-editor-v1";
  const SIZE_KEY = "ryko-block-size";
  const defaultHp = document.getElementById("defaultHp");
  const toolbox = document.getElementById("toolbox");
  const boardGrid = document.getElementById("boardGrid");
  if (!defaultHp || !toolbox || !boardGrid) return;

  const sizeField = document.createElement("label");
  sizeField.className = "field compact";
  sizeField.innerHTML = `Block size<select id="multicellBlockSize"><option value="1">1×1</option><option value="2">2×2</option><option value="3">3×3</option><option value="4">4×4</option></select>`;
  defaultHp.closest("label")?.insertAdjacentElement("afterend", sizeField);
  const sizeSelect = document.getElementById("multicellBlockSize");
  sizeSelect.value = sessionStorage.getItem(SIZE_KEY) || "1";
  sizeSelect.addEventListener("change", () => sessionStorage.setItem(SIZE_KEY, sizeSelect.value));

  const style = document.createElement("style");
  style.textContent = `
    .entity.multicell-block{position:absolute;left:0;top:0;z-index:6}
    .board-cell.multicell-covered{background:rgba(231,174,67,.025)}
  `;
  document.head.appendChild(style);

  function loadLevel() {
    try { return M.normalizeLevel(JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}")); }
    catch { return M.createDefaultLevel(); }
  }

  function saveLevel(level) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(M.normalizeLevel(level)));
    location.reload();
  }

  function currentSize() {
    const value = Math.trunc(Number(sizeSelect.value) || 1);
    return Math.min(M.MULTICELL_MAX_SPAN, Math.max(1, value));
  }

  function activeTool() {
    return toolbox.querySelector(".tool.active")?.dataset.tool || "";
  }

  function entityForCell(level, column, row) {
    return M.entityCoveringCell(level.initialBoard || [], column, row);
  }

  function decorate() {
    const level = loadLevel();
    boardGrid.querySelectorAll(".board-cell").forEach((cell) => {
      cell.classList.remove("multicell-covered");
      const column = Number(cell.dataset.column);
      const row = Number(cell.dataset.row);
      const entity = entityForCell(level, column, row);
      if (!entity) return;
      const size = M.blockFootprint(entity);
      if (size.width === 1 && size.height === 1) return;
      if (column !== entity.column || row !== entity.row) {
        cell.classList.add("multicell-covered");
        return;
      }
      const visual = cell.querySelector(".entity");
      if (!visual) return;
      visual.classList.add("multicell-block");
      visual.style.width = `calc(var(--cell) * ${size.width} + var(--gap) * ${size.width - 1})`;
      visual.style.height = `calc(var(--cell) * ${size.height} + var(--gap) * ${size.height - 1})`;
    });
  }

  function placeNormalSquare(event, cell) {
    const size = currentSize();
    const level = loadLevel();
    const board = M.boardForLevel(level);
    const column = Number(cell.dataset.column);
    const row = Number(cell.dataset.row);
    const hp = Math.max(1, Number.parseInt(defaultHp.value || "1", 10) || 1);
    const candidate = { kind:"block", shape:"square", variant:"normal", hp, column, row, widthCells:size, heightCells:size };

    if (column + size > board.columns || row + size > board.rows) {
      window.alert(`${size}×${size} block does not fit from C${column + 1} R${row + 1}.`);
      return;
    }
    const conflict = M.blockFootprintConflict(level.initialBoard || [], candidate);
    if (conflict) {
      window.alert("Those cells are already occupied. Erase the existing piece first.");
      return;
    }
    event.preventDefault();
    event.stopImmediatePropagation();
    level.initialBoard.push(candidate);
    saveLevel(level);
  }

  document.addEventListener("click", (event) => {
    const cell = event.target.closest?.("#boardGrid .board-cell");
    if (!cell) return;
    const tool = activeTool();
    if (tool === "square") {
      placeNormalSquare(event, cell);
      return;
    }

    if (["select", "erase", "mission_core", ""].includes(tool)) return;
    const level = loadLevel();
    const column = Number(cell.dataset.column);
    const row = Number(cell.dataset.row);
    const existing = entityForCell(level, column, row);
    if (existing && M.blockFootprint(existing).width > 1) {
      event.preventDefault();
      event.stopImmediatePropagation();
      window.alert("This cell belongs to a multi-cell block. Erase the whole block first.");
    }
  }, true);

  const observer = new MutationObserver(() => decorate());
  observer.observe(boardGrid, { childList:true, subtree:true });
  decorate();
})();
