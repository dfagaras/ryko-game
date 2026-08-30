(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M || M.__descendingRowEntitiesExtended) return;

  const MISSION_VARIANT = M.MISSION_BLOCK_VARIANT || "mission_core";
  const MISSION_WIN = M.MISSION_WIN_CONDITION || "destroy_all_objectives";
  const CLEAR_WIN = "clear_all_content";
  const DIRECTIONS = new Set(M.MECHANIC_DIRECTIONS || ["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]);

  const baseNormalizeLevel = M.normalizeLevel.bind(M);
  const baseValidateLevel = M.validateLevel.bind(M);
  const baseToExportJson = M.toExportJson.bind(M);

  function normalizeIncomingLauncher(item, rowIndex, launcherIndex, board) {
    if (!item || typeof item !== "object") return null;
    const column = Math.trunc(Number(item.column));
    if (!Number.isInteger(column) || column < 0 || column >= board.columns) return null;
    return {
      id: String(item.id || `incoming_${rowIndex + 1}_launcher_${launcherIndex + 1}`),
      column,
      direction: DIRECTIONS.has(item.direction) ? item.direction : "up"
    };
  }

  function restoreIncomingLaunchers(source, target) {
    const sourceRows = Array.isArray(source?.incomingRows) ? source.incomingRows : [];
    const board = M.boardForLevel(target || source || {});
    for (let rowIndex = 0; rowIndex < (target.incomingRows || []).length; rowIndex += 1) {
      const rawLaunchers = Array.isArray(sourceRows[rowIndex]?.launchers) ? sourceRows[rowIndex].launchers : [];
      const occupied = new Set();
      target.incomingRows[rowIndex].launchers = [];
      rawLaunchers.forEach((item, launcherIndex) => {
        const launcher = normalizeIncomingLauncher(item, rowIndex, launcherIndex, board);
        if (!launcher || occupied.has(launcher.column)) return;
        occupied.add(launcher.column);
        target.incomingRows[rowIndex].launchers.push(launcher);
      });
    }
    return target;
  }

  function missionCountAll(level) {
    let count = (level?.initialBoard || []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT).length;
    count += (level?.topRow || []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT).length;
    for (const row of level?.incomingRows || []) {
      count += (row?.cells || []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT).length;
    }
    return count;
  }

  function applyDescendingExtensions(source, target) {
    restoreIncomingLaunchers(source || {}, target);
    const missionCount = missionCountAll(target);
    target.rules = target.rules || {};
    target.rules.winCondition = missionCount > 0 ? MISSION_WIN : CLEAR_WIN;
    return target;
  }

  M.normalizeLevel = function (input) {
    return applyDescendingExtensions(input || {}, baseNormalizeLevel(input));
  };

  M.validateLevel = function (input) {
    const result = baseValidateLevel(input);
    result.level = applyDescendingExtensions(input || {}, result.level);
    result.errors = result.errors.filter((message) => !String(message).includes("incoming mission objectives are not supported yet"));
    result.warnings = result.warnings.filter((message) => !/Mission Core objective\(s\)/i.test(String(message)));

    const seenIds = new Set((result.level.mechanics?.launchers || []).map((launcher) => launcher.id));
    for (let rowIndex = 0; rowIndex < (result.level.incomingRows || []).length; rowIndex += 1) {
      for (const launcher of result.level.incomingRows[rowIndex].launchers || []) {
        if (!DIRECTIONS.has(launcher.direction)) result.errors.push(`Incoming +${rowIndex + 1} launcher ${launcher.id}: invalid direction.`);
        if (seenIds.has(launcher.id)) result.errors.push(`Duplicate mechanic id: ${launcher.id}.`);
        seenIds.add(launcher.id);
      }
    }

    const missionCount = missionCountAll(result.level);
    if (missionCount > 0) result.warnings.push(`${missionCount} Mission Core objective(s): the level clears when all objectives are destroyed, including authored future rows.`);
    result.valid = result.errors.length === 0;
    return result;
  };

  M.toExportJson = function (input) {
    const parsed = JSON.parse(baseToExportJson(input));
    applyDescendingExtensions(input || {}, parsed);
    return JSON.stringify(parsed, null, 2);
  };

  M.missionBlockCount = missionCountAll;
  M.normalizeIncomingLauncher = normalizeIncomingLauncher;
  M.restoreIncomingLaunchers = restoreIncomingLaunchers;
  M.__descendingRowEntitiesExtended = true;
})();
