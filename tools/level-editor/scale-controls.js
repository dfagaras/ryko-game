(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M) return;

  const STORAGE_KEY = "ryko-level-editor-v1";
  let currentLevel = loadLevel();
  let select = null;

  function loadLevel() {
    try {
      return M.normalizeLevel(JSON.parse(localStorage.getItem(STORAGE_KEY) || "null") || M.createDefaultLevel());
    } catch {
      return M.createDefaultLevel();
    }
  }

  function boardForCurrentLevel() {
    return M.boardForLevel(currentLevel);
  }

  function applyVisualScale() {
    const board = boardForCurrentLevel();
    const editorBaseCell = 58;
    const editorBaseGap = 3;
    const editorBaseColumns = 7;
    const editorBaseRows = 9;
    const baseGridWidth = editorBaseColumns * editorBaseCell + (editorBaseColumns - 1) * editorBaseGap;
    const baseGridHeight = editorBaseRows * editorBaseCell + (editorBaseRows - 1) * editorBaseGap;
    const scale = currentLevel.boardScale;
    const cell = editorBaseCell / scale;
    const columnGap = (baseGridWidth - board.columns * cell) / (board.columns - 1);
    const rowGap = (baseGridHeight - board.rows * cell) / (board.rows - 1);

    document.documentElement.style.setProperty("--cell", `${cell}px`);
    document.documentElement.style.setProperty("--gap", `${columnGap}px`);

    const template = `repeat(${board.columns}, var(--cell))`;
    document.querySelectorAll(".board-grid, .incoming-strip, .incoming-editor").forEach((grid) => {
      grid.style.gridTemplateColumns = template;
      grid.style.gridAutoRows = "var(--cell)";
      grid.style.columnGap = `${columnGap}px`;
      grid.style.rowGap = `${rowGap}px`;
      grid.style.width = `${baseGridWidth}px`;
    });

    const shell = document.querySelector(".board-shell");
    if (shell) shell.style.width = `${baseGridWidth + 28}px`;

    const hpSize = Math.max(5.5, 15 / scale);
    const outline = Math.max(1, 4 / scale);
    const triangleInset = Math.max(1, 5 / scale);
    const style = document.createElement("style");
    style.id = "ryko-scale-style";
    style.textContent = `
      .entity.block.square.normal { border-width: ${outline}px; }
      .entity.block.dense, .entity.block.regenerative, .entity.block.phase, .entity.block.black_hole { border-width: ${outline}px; }
      .entity .hp { font-size: ${hpSize}px; }
      .entity.triangle::after { inset: ${triangleInset}px; }
      ${scale >= 2 ? ".cell-index { display:none; }" : ""}
      ${scale >= 3 ? ".black-hole-side { transform: scale(.55); transform-origin:center; }" : ""}
    `;
    document.getElementById(style.id)?.remove();
    document.head.appendChild(style);
  }

  function injectScaleControl() {
    const modeNote = document.getElementById("modeNote");
    if (!modeNote || document.getElementById("boardScaleSelect")) return;

    const field = document.createElement("label");
    field.className = "field";
    field.innerHTML = `Grid scale
      <select id="boardScaleSelect" aria-label="Board grid scale">
        <option value="1">1× — 7 × 9</option>
        <option value="2">2× — 14 × 18</option>
        <option value="3">3× — 21 × 27</option>
        <option value="4">4× — 28 × 36</option>
      </select>`;
    modeNote.insertAdjacentElement("afterend", field);

    select = field.querySelector("select");
    select.value = String(currentLevel.boardScale);
    select.addEventListener("change", () => {
      const nextScale = M.normalizeBoardScale(select.value);
      if (nextScale === currentLevel.boardScale) return;
      window.dispatchEvent(new CustomEvent("ryko-board-scale-requested", {
        detail: { scale: nextScale }
      }));
    });
  }

  function updateLabels() {
    const board = boardForCurrentLevel();
    if (select) select.value = String(currentLevel.boardScale);

    const eyebrow = document.querySelector(".board-card-header .eyebrow");
    if (eyebrow) eyebrow.textContent = `${board.columns} columns × ${board.rows} playable rows // ${currentLevel.boardScale}× zoom-out grid`;

    const contract = document.querySelectorAll(".contract-list > div");
    for (const row of contract) {
      const label = row.querySelector("dt")?.textContent;
      const value = row.querySelector("dd");
      if (!value) continue;
      if (label === "Columns") value.textContent = String(board.columns);
      if (label === "Playable rows") value.textContent = String(board.rows);
    }
    const cellContract = [...contract].find((row) => row.querySelector("dt")?.textContent === "Cells")?.querySelector("dd");
    if (cellContract) {
      const xGap = Number(board.columnGap ?? board.gap);
      const yGap = Number(board.rowGap ?? board.gap);
      cellContract.textContent = `${format(board.cell)} px cell · ${format(xGap)} / ${format(yGap)} px gaps`;
    }
  }

  function refresh(level) {
    currentLevel = M.normalizeLevel(level || loadLevel());
    applyVisualScale();
    updateLabels();
  }

  function format(value) {
    return Number.isInteger(value) ? String(value) : Number(value.toFixed(2)).toString();
  }

  window.addEventListener("ryko-level-changed", (event) => {
    refresh(event.detail?.level);
  });

  injectScaleControl();
  refresh(currentLevel);
})();
