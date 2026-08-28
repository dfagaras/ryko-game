(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M?.__mechanicsExtended) return;

  const STORAGE_KEY = "ryko-level-editor-v1";
  const toolbox = document.getElementById("toolbox");
  const boardGrid = document.getElementById("boardGrid");
  if (!toolbox || !boardGrid) return;

  const DIRECTION_GLYPHS = {
    up: "↑", up_right: "↗", right: "→", down_right: "↘",
    down: "↓", down_left: "↙", left: "←", up_left: "↖"
  };
  let armedDirection = null;

  const style = document.createElement("style");
  style.textContent = `
    .mechanics-panel{margin-top:10px}.launcher-direction-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px;margin:8px 0}
    .launcher-direction{min-height:54px;border:1px solid rgba(242,227,187,.18);border-radius:7px;background:rgba(2,11,14,.42);color:var(--cream);display:grid;place-items:center;gap:1px;cursor:pointer}
    .launcher-direction strong{font-size:24px;line-height:1;color:var(--aqua)}.launcher-direction span{font-size:8px;text-transform:uppercase;color:rgba(242,227,187,.58)}
    .launcher-direction.active{border-color:var(--aqua);box-shadow:inset 0 0 0 1px rgba(85,184,177,.28),0 0 12px rgba(85,184,177,.10);background:rgba(85,184,177,.12)}
    .mechanics-cancel{width:100%;margin-bottom:8px}.mechanics-list{margin:8px 0 2px}.mechanics-list-item{display:flex;justify-content:space-between;align-items:center;gap:8px}
    .board-grid{position:relative}.board-cell{position:relative}.board-grid.placing-launcher .board-cell{cursor:crosshair}
    .mechanic-launcher-overlay{position:absolute;inset:12%;z-index:8;display:grid;place-items:center;border-radius:50%;border:2px solid var(--aqua);background:rgba(7,20,25,.88);color:var(--cream);font-size:clamp(16px,2vw,28px);font-weight:900;line-height:1;box-shadow:0 0 10px rgba(85,184,177,.28);pointer-events:none}
    .mechanic-laser-layer{position:absolute;inset:0;width:100%;height:100%;z-index:7;pointer-events:none;overflow:visible}.mechanic-laser-line{stroke:#ff4058;stroke-width:7;vector-effect:non-scaling-stroke;filter:drop-shadow(0 0 4px rgba(255,64,88,.9))}`;
  document.head.appendChild(style);

  const wrap = document.createElement("section");
  wrap.className = "mechanics-panel";
  wrap.innerHTML = `
    <div class="section-rule"></div>
    <div class="panel-title">Mechanics</div>
    <p class="muted-copy">Choose one launcher direction, then click a board cell. Each launcher pushes every ball only in that selected direction.</p>
    <div class="launcher-direction-grid" id="launcherDirectionGrid"></div>
    <button class="button ghost small mechanics-cancel" id="cancelLauncherButton" hidden>Cancel launcher placement</button>
    <div id="launcherList" class="validation-list mechanics-list"></div>
    <div class="section-rule"></div>
    <div class="selection-name">TIMED LASER</div>
    <p class="muted-copy">0 = left/top edge, 1 = right/bottom edge. Values in between create a partial laser.</p>
    <div class="field-row"><label class="field">From X<input id="laserFromX" type="number" min="0" max="1" step="0.05" value="0" /></label><label class="field">From Y<input id="laserFromY" type="number" min="0" max="1" step="0.05" value="0.5" /></label></div>
    <div class="field-row"><label class="field">To X<input id="laserToX" type="number" min="0" max="1" step="0.05" value="1" /></label><label class="field">To Y<input id="laserToY" type="number" min="0" max="1" step="0.05" value="0.5" /></label></div>
    <div class="field-row"><label class="field">ON sec<input id="laserOnSeconds" type="number" min="0.05" step="0.05" value="1.5" /></label><label class="field">OFF sec<input id="laserOffSeconds" type="number" min="0.05" step="0.05" value="1" /></label></div>
    <div class="field-row"><label class="field">Start delay<input id="laserStartDelay" type="number" min="0" step="0.05" value="0" /></label><label class="field">Starts<select id="laserStartsOn"><option value="on">ON</option><option value="off">OFF</option></select></label></div>
    <button class="button secondary small" id="addLaserButton">+ Add laser</button>
    <div id="laserList" class="validation-list mechanics-list"></div>`;
  toolbox.insertAdjacentElement("afterend", wrap);

  const $ = (id) => document.getElementById(id);

  function readLevel() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) return M.normalizeLevel(JSON.parse(raw));
    } catch (error) {
      console.warn("Could not read mechanics draft", error);
    }
    return M.createDefaultLevel();
  }

  function saveLevel(level) {
    const normalized = M.normalizeLevel(level);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized));
    window.location.reload();
  }

  function nextId(items, prefix) {
    let index = 1;
    while (items.some((item) => item.id === `${prefix}_${index}`)) index += 1;
    return `${prefix}_${index}`;
  }

  function listItem(text, onDelete) {
    const row = document.createElement("div");
    row.className = "validation-item mechanics-list-item";
    const copy = document.createElement("span");
    copy.textContent = text;
    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "button danger small";
    remove.textContent = "Delete";
    remove.addEventListener("click", onDelete);
    row.append(copy, remove);
    return row;
  }

  function buildDirectionButtons() {
    const host = $("launcherDirectionGrid");
    host.innerHTML = "";
    M.MECHANIC_DIRECTIONS.forEach((direction) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `launcher-direction${armedDirection === direction ? " active" : ""}`;
      button.title = direction.replaceAll("_", " ");
      button.innerHTML = `<strong>${DIRECTION_GLYPHS[direction]}</strong><span>${direction.replaceAll("_", " ")}</span>`;
      button.addEventListener("click", () => {
        armedDirection = armedDirection === direction ? null : direction;
        render();
      });
      host.appendChild(button);
    });
    $("cancelLauncherButton").hidden = !armedDirection;
  }

  function renderLaunchers(level) {
    document.querySelectorAll(".mechanic-launcher-overlay").forEach((node) => node.remove());
    level.mechanics.launchers.forEach((launcher) => {
      const cell = boardGrid.querySelector(`.board-cell[data-column="${launcher.column}"][data-row="${launcher.row}"]`);
      if (!cell) return;
      const marker = document.createElement("div");
      marker.className = "mechanic-launcher-overlay";
      marker.title = `Launcher ${launcher.direction.replaceAll("_", " ")}`;
      marker.textContent = DIRECTION_GLYPHS[launcher.direction] || "↑";
      cell.appendChild(marker);
    });
  }

  function renderLasers(level) {
    boardGrid.querySelectorAll(":scope > .mechanic-laser-layer").forEach((node) => node.remove());
    if (!level.mechanics.lasers.length) return;
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("class", "mechanic-laser-layer");
    svg.setAttribute("viewBox", "0 0 1000 1000");
    svg.setAttribute("preserveAspectRatio", "none");
    level.mechanics.lasers.forEach((laser) => {
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", String(laser.from.x * 1000)); line.setAttribute("y1", String(laser.from.y * 1000));
      line.setAttribute("x2", String(laser.to.x * 1000)); line.setAttribute("y2", String(laser.to.y * 1000));
      line.setAttribute("class", "mechanic-laser-line");
      svg.appendChild(line);
    });
    boardGrid.appendChild(svg);
  }

  function renderLists(level) {
    $("launcherList").innerHTML = "";
    level.mechanics.launchers.forEach((launcher) => $("launcherList").appendChild(listItem(
      `${DIRECTION_GLYPHS[launcher.direction]} C${launcher.column + 1} R${launcher.row + 1} // ${launcher.direction.replaceAll("_", " ")}`,
      () => { const fresh = readLevel(); fresh.mechanics.launchers = fresh.mechanics.launchers.filter((item) => item.id !== launcher.id); saveLevel(fresh); }
    )));
    $("laserList").innerHTML = "";
    level.mechanics.lasers.forEach((laser) => $("laserList").appendChild(listItem(
      `${laser.id} // (${laser.from.x},${laser.from.y}) → (${laser.to.x},${laser.to.y}) // ${laser.onSeconds}s ON / ${laser.offSeconds}s OFF`,
      () => { const fresh = readLevel(); fresh.mechanics.lasers = fresh.mechanics.lasers.filter((item) => item.id !== laser.id); saveLevel(fresh); }
    )));
  }

  function render() {
    const level = readLevel();
    buildDirectionButtons();
    renderLists(level);
    renderLaunchers(level);
    renderLasers(level);
    boardGrid.classList.toggle("placing-launcher", Boolean(armedDirection));
  }

  function readLaserNumber(id, min, max = Infinity) {
    const input = $(id);
    const value = Number(input.value);
    if (!Number.isFinite(value) || value < min || value > max) {
      input.focus();
      return null;
    }
    return value;
  }

  function mutationTouchesBoardCells(mutations) {
    return mutations.some((mutation) => [...mutation.addedNodes, ...mutation.removedNodes].some((node) => {
      if (!(node instanceof Element)) return false;
      return node.matches(".board-cell") || Boolean(node.querySelector?.(".board-cell"));
    }));
  }

  boardGrid.addEventListener("click", (event) => {
    if (!armedDirection) return;
    const cell = event.target.closest(".board-cell");
    if (!cell || !boardGrid.contains(cell)) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    const column = Number(cell.dataset.column);
    const row = Number(cell.dataset.row);
    const level = readLevel();
    level.mechanics.launchers = level.mechanics.launchers.filter((item) => !(item.column === column && item.row === row));
    level.mechanics.launchers.push({ id: nextId(level.mechanics.launchers, "launcher"), column, row, direction: armedDirection });
    saveLevel(level);
  }, true);

  $("cancelLauncherButton").addEventListener("click", () => { armedDirection = null; render(); });
  $("addLaserButton").addEventListener("click", () => {
    const fromX = readLaserNumber("laserFromX", 0, 1);
    const fromY = readLaserNumber("laserFromY", 0, 1);
    const toX = readLaserNumber("laserToX", 0, 1);
    const toY = readLaserNumber("laserToY", 0, 1);
    const onSeconds = readLaserNumber("laserOnSeconds", 0.05);
    const offSeconds = readLaserNumber("laserOffSeconds", 0.05);
    const startDelay = readLaserNumber("laserStartDelay", 0);
    if ([fromX, fromY, toX, toY, onSeconds, offSeconds, startDelay].some((value) => value === null)) {
      window.alert("Laser values are invalid. Position must be 0–1, ON/OFF must be at least 0.05s, and delay cannot be negative.");
      return;
    }
    if (fromX === toX && fromY === toY) {
      $("laserToX").focus();
      window.alert("Laser needs two different endpoints.");
      return;
    }

    const level = readLevel();
    level.mechanics.lasers.push({
      id: nextId(level.mechanics.lasers, "laser"),
      from: { x: fromX, y: fromY },
      to: { x: toX, y: toY },
      onSeconds, offSeconds,
      startDelay, startsOn: $("laserStartsOn").value === "on"
    });
    saveLevel(level);
  });

  const observer = new MutationObserver((mutations) => {
    if (!mutationTouchesBoardCells(mutations)) return;
    queueMicrotask(() => {
      if (!document.body.contains(wrap)) return;
      const level = readLevel();
      renderLaunchers(level);
      renderLasers(level);
    });
  });
  observer.observe(boardGrid, { childList: true, subtree: true });

  render();
})();
