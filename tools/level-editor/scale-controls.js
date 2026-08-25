(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M) return;

  const STORAGE_KEY = "ryko-level-editor-v1";
  let draft;
  try {
    draft = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null") || M.createDefaultLevel();
  } catch {
    draft = M.createDefaultLevel();
  }
  draft = M.normalizeLevel(draft);
  const board = M.boardForLevel(draft);

  function applyVisualScale() {
    const editorBaseCell = 58;
    const editorBaseGap = 3;
    const scale = draft.boardScale;
    const cell = editorBaseCell / scale;
    const gap = editorBaseGap / scale;
    const gridWidth = board.columns * cell + Math.max(0, board.columns - 1) * gap;

    document.documentElement.style.setProperty("--cell", `${cell}px`);
    document.documentElement.style.setProperty("--gap", `${gap}px`);

    const template = `repeat(${board.columns}, var(--cell))`;
    document.querySelectorAll(".board-grid, .incoming-strip, .incoming-editor").forEach((grid) => {
      grid.style.gridTemplateColumns = template;
      grid.style.gridAutoRows = "var(--cell)";
    });

    const shell = document.querySelector(".board-shell");
    if (shell) shell.style.width = `${gridWidth + 28}px`;

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
    if (!modeNote) return;

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

    const select = field.querySelector("select");
    select.value = String(draft.boardScale);
    select.addEventListener("change", () => {
      const nextScale = M.normalizeBoardScale(select.value);
      if (nextScale === draft.boardScale) return;
      const hasContent = draft.initialBoard.length > 0 || draft.incomingRows.some((row) => row.cells?.length);
      if (hasContent && !window.confirm("Changing grid scale changes every cell coordinate. Clear authored board content and switch grid scale?")) {
        select.value = String(draft.boardScale);
        return;
      }
      draft.boardScale = nextScale;
      draft.board = M.boardForScale(nextScale);
      draft.initialBoard = [];
      draft.incomingRows = [];
      localStorage.setItem(STORAGE_KEY, JSON.stringify(draft));
      window.location.reload();
    });
  }

  function updateLabels() {
    const eyebrow = document.querySelector(".board-card-header .eyebrow");
    if (eyebrow) eyebrow.textContent = `${board.columns} columns × ${board.rows} playable rows // ${draft.boardScale}× zoom-out grid`;

    const contract = document.querySelectorAll(".contract-list > div");
    for (const row of contract) {
      const label = row.querySelector("dt")?.textContent;
      const value = row.querySelector("dd");
      if (!value) continue;
      if (label === "Columns") value.textContent = String(board.columns);
      if (label === "Playable rows") value.textContent = String(board.rows);
    }
    const cellContract = [...contract].find((row) => row.querySelector("dt")?.textContent === "Cells")?.querySelector("dd");
    if (cellContract) cellContract.textContent = `${board.cell.toFixed(board.cell % 1 ? 1 : 0)} px + ${board.gap.toFixed(board.gap % 1 ? 1 : 0)} px gap`;
  }

  injectScaleControl();
  applyVisualScale();
  updateLabels();
})();
