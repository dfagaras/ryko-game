(() => {
  "use strict";

  const M = window.RykoLevelModel;
  const boardGrid = document.getElementById("boardGrid");
  const toolbox = document.getElementById("toolbox");
  if (!M || !boardGrid || !toolbox) return;

  const STORAGE_KEY = "ryko-level-editor-v1";
  const GLYPH_TO_DIRECTION = Object.freeze({
    "↑": "up", "↗": "up_right", "→": "right", "↘": "down_right",
    "↓": "down", "↙": "down_left", "←": "left", "↖": "up_left"
  });

  function readLevel() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      return M.normalizeLevel(raw ? JSON.parse(raw) : M.createDefaultLevel());
    } catch {
      return M.createDefaultLevel();
    }
  }

  function writeLevel(level) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(M.normalizeLevel(level)));
    window.location.reload();
  }

  function nextId(items, prefix) {
    let index = 1;
    while (items.some((item) => item.id === `${prefix}_${index}`)) index += 1;
    return `${prefix}_${index}`;
  }

  function activeLauncherDirection() {
    const button = document.querySelector("#dirGrid .mechanic-tool.active");
    return button ? GLYPH_TO_DIRECTION[button.textContent.trim()] || null : null;
  }

  function lastRowCellAtPoint(x, y) {
    const level = readLevel();
    const board = M.boardForLevel(level);
    const lastRow = board.rows - 1;
    const cells = boardGrid.querySelectorAll(`.board-cell[data-row="${lastRow}"]`);
    for (const cell of cells) {
      const rect = cell.getBoundingClientRect();
      if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) return cell;
    }
    return null;
  }

  // The launch/danger decoration must never steal pointer input from the final row.
  const launchLine = document.querySelector(".launch-line");
  if (launchLine) launchLine.style.pointerEvents = "none";

  // Explicit fallback for launchers on the final row. It uses physical cell bounds,
  // so it remains correct for custom grids such as 10x13 and for responsive scaling.
  document.addEventListener("pointerup", (event) => {
    const direction = activeLauncherDirection();
    if (!direction) return;
    const targetCell = lastRowCellAtPoint(event.clientX, event.clientY);
    if (!targetCell) return;

    event.preventDefault();
    event.stopImmediatePropagation();

    const level = readLevel();
    const column = Number(targetCell.dataset.column);
    const row = Number(targetCell.dataset.row);
    level.mechanics ||= {};
    level.mechanics.launchers ||= [];
    level.mechanics.launchers = level.mechanics.launchers.filter((item) => !(item.column === column && item.row === row));
    level.mechanics.launchers.push({
      id: nextId(level.mechanics.launchers, "launcher"),
      column,
      row,
      direction
    });
    writeLevel(level);
  }, true);

  function injectBlackHolePlacementControls() {
    if (document.getElementById("blackHolePlacementSides")) return;
    const blackHoleTool = toolbox.querySelector('[data-tool="black_hole"]');
    if (!blackHoleTool) return;

    const panel = document.createElement("div");
    panel.id = "blackHolePlacementSides";
    panel.className = "black-hole-placement-config";
    panel.innerHTML = `
      <div class="selection-name">BLACK HOLE ABSORBING SIDES</div>
      <div class="check-grid">
        <label><input type="checkbox" value="top" checked>Top</label>
        <label><input type="checkbox" value="right">Right</label>
        <label><input type="checkbox" value="bottom">Bottom</label>
        <label><input type="checkbox" value="left">Left</label>
      </div>
      <div class="muted-copy">Choose the sides that consume balls, then place the Black Hole.</div>`;
    toolbox.insertAdjacentElement("afterend", panel);

    const style = document.createElement("style");
    style.textContent = `.black-hole-placement-config{margin:8px 0 10px;padding:9px;border:1px solid rgba(242,227,187,.14);border-radius:8px;background:rgba(2,11,14,.28)}.black-hole-placement-config .muted-copy{font-size:9px}`;
    document.head.appendChild(style);
  }

  function selectedBlackHoleSides() {
    const panel = document.getElementById("blackHolePlacementSides");
    if (!panel) return ["top"];
    const sides = [...panel.querySelectorAll('input[type="checkbox"]:checked')].map((input) => input.value);
    return sides.length ? sides : ["top"];
  }

  // Core editor currently creates Black Holes with top-only absorption. After its
  // normal placement completes, apply the sides selected in the placement panel.
  boardGrid.addEventListener("click", (event) => {
    const blackHoleActive = toolbox.querySelector('[data-tool="black_hole"].active');
    if (!blackHoleActive) return;
    const cell = event.target.closest(".board-cell");
    if (!cell) return;
    const column = Number(cell.dataset.column);
    const row = Number(cell.dataset.row);
    const sides = selectedBlackHoleSides();

    setTimeout(() => {
      const level = readLevel();
      const entity = level.initialBoard.find((item) => item.column === column && item.row === row);
      if (!entity || entity.kind !== "block" || entity.variant !== "black_hole") return;
      entity.absorbingSides = [...sides];
      writeLevel(level);
    }, 0);
  });

  injectBlackHolePlacementControls();
})();
