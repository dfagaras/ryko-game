(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M) return;

  const STORAGE_KEY = "ryko-level-editor-v1";
  let currentLevel = loadLevel();
  let columnsInput = null;
  let rowsInput = null;

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
    const visualScale = board.visualScale;
    const cell = editorBaseCell * visualScale;
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

    const zoom = 1 / visualScale;
    const hpSize = Math.max(5.5, 15 / zoom);
    const outline = Math.max(1, 4 / zoom);
    const triangleInset = Math.max(1, 5 / zoom);
    const style = document.createElement("style");
    style.id = "ryko-scale-style";
    style.textContent = `
      .entity.block.square.normal { border-width: ${outline}px; }
      .entity.block.dense, .entity.block.regenerative, .entity.block.phase, .entity.block.black_hole { border-width: ${outline}px; }
      .entity .hp { font-size: ${hpSize}px; }
      .entity.triangle::after { inset: ${triangleInset}px; }
      ${visualScale <= 0.5 ? ".cell-index { display:none; }" : ""}
      ${visualScale <= (1 / 3) ? ".black-hole-side { transform: scale(.55); transform-origin:center; }" : ""}
    `;
    document.getElementById(style.id)?.remove();
    document.head.appendChild(style);
  }

  function injectDimensionControls() {
    const modeNote = document.getElementById("modeNote");
    if (!modeNote || document.getElementById("boardColumnsInput")) return;

    const wrapper = document.createElement("div");
    wrapper.className = "grid-dimension-controls";
    wrapper.innerHTML = `
      <label class="field">Grid columns
        <input id="boardColumnsInput" type="number" inputmode="numeric"
          min="${M.MIN_BOARD_COLUMNS}" max="${M.MAX_BOARD_COLUMNS}" step="1"
          aria-label="Board grid columns">
      </label>
      <label class="field">Grid rows
        <input id="boardRowsInput" type="number" inputmode="numeric"
          min="${M.MIN_BOARD_ROWS}" max="${M.MAX_BOARD_ROWS}" step="1"
          aria-label="Board grid rows">
      </label>`;
    modeNote.insertAdjacentElement("afterend", wrapper);

    columnsInput = wrapper.querySelector("#boardColumnsInput");
    rowsInput = wrapper.querySelector("#boardRowsInput");
    const board = boardForCurrentLevel();
    columnsInput.value = String(board.columns);
    rowsInput.value = String(board.rows);

    const applyDimensions = () => {
      const nextColumns = Number(columnsInput.value);
      const nextRows = Number(rowsInput.value);
      if (!M.isSupportedBoardDimensions(nextColumns, nextRows)) {
        window.alert(`Grid must be ${M.MIN_BOARD_COLUMNS}-${M.MAX_BOARD_COLUMNS} columns and ${M.MIN_BOARD_ROWS}-${M.MAX_BOARD_ROWS} rows.`);
        updateLabels();
        return;
      }

      const currentBoard = boardForCurrentLevel();
      if (nextColumns === currentBoard.columns && nextRows === currentBoard.rows) return;

      const hasContent = currentLevel.initialBoard.length > 0 || currentLevel.incomingRows.some((row) => row.cells?.length);
      if (hasContent && !window.confirm("Changing grid dimensions changes every cell coordinate. Clear authored board content and switch grid size?")) {
        updateLabels();
        return;
      }

      const next = M.normalizeLevel({
        ...currentLevel,
        boardColumns: nextColumns,
        boardRows: nextRows,
        board: M.boardForDimensions(nextColumns, nextRows),
        initialBoard: [],
        incomingRows: []
      });
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      window.location.reload();
    };

    columnsInput.addEventListener("change", applyDimensions);
    rowsInput.addEventListener("change", applyDimensions);
  }

  function updateLabels() {
    const board = boardForCurrentLevel();
    if (columnsInput) columnsInput.value = String(board.columns);
    if (rowsInput) rowsInput.value = String(board.rows);

    const eyebrow = document.querySelector(".board-card-header .eyebrow");
    if (eyebrow) eyebrow.textContent = `${board.columns} columns × ${board.rows} playable rows // ${Math.round(board.visualScale * 100)}% element size`;

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
    M.setActiveBoardDimensions(currentLevel.board.columns, currentLevel.board.rows);
    applyVisualScale();
    updateLabels();
  }

  function refreshFromJsonPreview() {
    const preview = document.getElementById("jsonPreview");
    if (!preview?.textContent?.trim()) return;
    try {
      refresh(JSON.parse(preview.textContent));
    } catch {
      // The editor may be between render passes; its next JSON update retries.
    }
  }

  function observeEditorState() {
    const preview = document.getElementById("jsonPreview");
    if (!preview) return;
    new MutationObserver(refreshFromJsonPreview).observe(preview, {
      childList: true,
      characterData: true,
      subtree: true
    });
    refreshFromJsonPreview();
  }

  function format(value) {
    return Number.isInteger(value) ? String(value) : Number(value.toFixed(2)).toString();
  }

  injectDimensionControls();
  refresh(currentLevel);
  observeEditorState();
})();
