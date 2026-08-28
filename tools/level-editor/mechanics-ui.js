(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M?.__mechanicsExtended) return;

  const host = document.querySelector(".inspector-panel");
  if (!host) return;

  const wrap = document.createElement("section");
  wrap.innerHTML = `
    <div class="section-rule"></div>
    <div class="panel-title">Level mechanics</div>
    <p class="muted-copy">Launchers redirect any ball in one of 8 directions. Lasers destroy balls while ON; coordinates are normalized from 0 to 1 across the playable board.</p>
    <div class="selection-editor" id="mechanicsEditor">
      <div class="selection-name">LAUNCHER</div>
      <div class="field-row">
        <label class="field">Column<input id="mechanicLauncherColumn" type="number" min="0" value="0" /></label>
        <label class="field">Row<input id="mechanicLauncherRow" type="number" min="0" value="0" /></label>
      </div>
      <label class="field">Direction<select id="mechanicLauncherDirection"></select></label>
      <button class="button secondary small" id="addLauncherButton">+ Add launcher</button>
      <div id="launcherList" class="validation-list"></div>

      <div class="section-rule"></div>
      <div class="selection-name">TIMED LASER</div>
      <div class="field-row">
        <label class="field">From X<input id="laserFromX" type="number" min="0" max="1" step="0.05" value="0" /></label>
        <label class="field">From Y<input id="laserFromY" type="number" min="0" max="1" step="0.05" value="0.5" /></label>
      </div>
      <div class="field-row">
        <label class="field">To X<input id="laserToX" type="number" min="0" max="1" step="0.05" value="1" /></label>
        <label class="field">To Y<input id="laserToY" type="number" min="0" max="1" step="0.05" value="0.5" /></label>
      </div>
      <div class="field-row">
        <label class="field">ON sec<input id="laserOnSeconds" type="number" min="0.05" step="0.05" value="1.5" /></label>
        <label class="field">OFF sec<input id="laserOffSeconds" type="number" min="0.05" step="0.05" value="1" /></label>
      </div>
      <div class="field-row">
        <label class="field">Start delay<input id="laserStartDelay" type="number" min="0" step="0.05" value="0" /></label>
        <label class="field">Starts<select id="laserStartsOn"><option value="on">ON</option><option value="off">OFF</option></select></label>
      </div>
      <button class="button secondary small" id="addLaserButton">+ Add laser</button>
      <div id="laserList" class="validation-list"></div>
    </div>`;
  host.appendChild(wrap);

  const $ = (id) => document.getElementById(id);
  M.MECHANIC_DIRECTIONS.forEach((direction) => {
    const option = document.createElement("option");
    option.value = direction;
    option.textContent = direction.replaceAll("_", " ").toUpperCase();
    $("mechanicLauncherDirection").appendChild(option);
  });

  function levelRef() {
    const level = window.RykoMechanicsLevelRef;
    if (!level.mechanics) level.mechanics = { launchers: [], lasers: [] };
    return level;
  }

  function commit() {
    const name = document.getElementById("levelName");
    if (name) name.dispatchEvent(new Event("input", { bubbles: true }));
    render();
  }

  function removeById(type, id) {
    const level = levelRef();
    level.mechanics[type] = level.mechanics[type].filter((item) => item.id !== id);
    commit();
  }

  function listItem(text, onDelete) {
    const row = document.createElement("div");
    row.className = "validation-item";
    row.style.display = "flex";
    row.style.justifyContent = "space-between";
    row.style.gap = "8px";
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

  function render() {
    const level = levelRef();
    const board = M.boardForLevel(level);
    $("mechanicLauncherColumn").max = String(board.columns - 1);
    $("mechanicLauncherRow").max = String(board.rows - 1);

    $("launcherList").innerHTML = "";
    level.mechanics.launchers.forEach((launcher) => {
      $("launcherList").appendChild(listItem(
        `${launcher.id} // C${launcher.column} R${launcher.row} → ${launcher.direction.replaceAll("_", " ")}`,
        () => removeById("launchers", launcher.id)
      ));
    });

    $("laserList").innerHTML = "";
    level.mechanics.lasers.forEach((laser) => {
      $("laserList").appendChild(listItem(
        `${laser.id} // (${laser.from.x},${laser.from.y}) → (${laser.to.x},${laser.to.y}) // ${laser.onSeconds}s ON / ${laser.offSeconds}s OFF`,
        () => removeById("lasers", laser.id)
      ));
    });
  }

  $("addLauncherButton").addEventListener("click", () => {
    const level = levelRef();
    const index = level.mechanics.launchers.length + 1;
    level.mechanics.launchers.push({
      id: `launcher_${index}`,
      column: Number.parseInt($("mechanicLauncherColumn").value, 10) || 0,
      row: Number.parseInt($("mechanicLauncherRow").value, 10) || 0,
      direction: $("mechanicLauncherDirection").value
    });
    commit();
  });

  $("addLaserButton").addEventListener("click", () => {
    const level = levelRef();
    const index = level.mechanics.lasers.length + 1;
    level.mechanics.lasers.push({
      id: `laser_${index}`,
      from: { x: Number($("laserFromX").value), y: Number($("laserFromY").value) },
      to: { x: Number($("laserToX").value), y: Number($("laserToY").value) },
      onSeconds: Number($("laserOnSeconds").value),
      offSeconds: Number($("laserOffSeconds").value),
      startDelay: Number($("laserStartDelay").value),
      startsOn: $("laserStartsOn").value === "on"
    });
    commit();
  });

  render();
})();
