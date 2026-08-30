(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M) return;

  const MISSION_VARIANT = "mission_core";
  const MISSION_WIN = "destroy_all_objectives";
  const CLEAR_WIN = "clear_all_content";
  const DIRECTIONS = new Set(M.MECHANIC_DIRECTIONS || ["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]);
  const baseNormalizeLevel = M.normalizeLevel.bind(M);
  const baseValidateLevel = M.validateLevel.bind(M);
  const baseToExportJson = M.toExportJson.bind(M);

  function sourceMissionAt(source, scope, rowIndex, column, row) {
    if (scope === "initial") {
      return (Array.isArray(source?.initialBoard) ? source.initialBoard : []).find((item) =>
        item?.kind === "block" && item?.variant === MISSION_VARIANT && item?.shape !== "triangle" &&
        Number(item.column) === column && Number(item.row) === row);
    }
    if (scope === "top") {
      return (Array.isArray(source?.topRow) ? source.topRow : []).find((item) =>
        item?.kind === "block" && item?.variant === MISSION_VARIANT && item?.shape !== "triangle" && Number(item.column) === column);
    }
    return (Array.isArray(source?.incomingRows?.[rowIndex]?.cells) ? source.incomingRows[rowIndex].cells : []).find((item) =>
      item?.kind === "block" && item?.variant === MISSION_VARIANT && item?.shape !== "triangle" && Number(item.column) === column);
  }

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

  function restoreMissionVariants(source, target) {
    for (const entity of target.initialBoard || []) {
      if (entity.kind !== "block" || entity.shape === "triangle") continue;
      if (sourceMissionAt(source, "initial", -1, entity.column, entity.row)) entity.variant = MISSION_VARIANT;
    }
    for (let rowIndex = 0; rowIndex < (target.incomingRows || []).length; rowIndex += 1) {
      for (const entity of target.incomingRows[rowIndex].cells || []) {
        if (entity.kind !== "block" || entity.shape === "triangle") continue;
        if (sourceMissionAt(source, "incoming", rowIndex, entity.column, 0)) entity.variant = MISSION_VARIANT;
      }
    }
    for (const entity of target.topRow || []) {
      if (entity.kind !== "block" || entity.shape === "triangle") continue;
      if (sourceMissionAt(source, "top", -1, entity.column, 0)) entity.variant = MISSION_VARIANT;
    }
    restoreIncomingLaunchers(source, target);
    const objectiveCount = missionCount(target);
    target.rules = target.rules || {};
    target.rules.winCondition = objectiveCount > 0 ? MISSION_WIN : CLEAR_WIN;
    return target;
  }

  function missionCount(level) {
    let count = (level.initialBoard || []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT).length;
    count += (level.topRow || []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT).length;
    for (const row of level.incomingRows || []) {
      count += (row?.cells || []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT).length;
    }
    return count;
  }

  function rawTriangleMissionCount(source) {
    let count = (Array.isArray(source?.initialBoard) ? source.initialBoard : []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT && entity?.shape === "triangle").length;
    count += (Array.isArray(source?.topRow) ? source.topRow : []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT && entity?.shape === "triangle").length;
    for (const row of Array.isArray(source?.incomingRows) ? source.incomingRows : []) {
      count += (Array.isArray(row?.cells) ? row.cells : []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT && entity?.shape === "triangle").length;
    }
    return count;
  }

  M.MISSION_BLOCK_VARIANT = MISSION_VARIANT;
  M.MISSION_WIN_CONDITION = MISSION_WIN;
  M.missionBlockCount = missionCount;
  M.normalizeIncomingLauncher = normalizeIncomingLauncher;
  M.restoreIncomingLaunchers = restoreIncomingLaunchers;
  M.__descendingRowEntitiesExtended = true;
  M.normalizeLevel = (input) => restoreMissionVariants(input || {}, baseNormalizeLevel(input));
  M.validateLevel = (input) => {
    const base = baseValidateLevel(input);
    const normalized = M.normalizeLevel(input || {});
    const errors = [...base.errors];
    const warnings = [...base.warnings].filter((message) => !/Mission Core objective\(s\)/i.test(String(message)));
    const triangleMissionCount = rawTriangleMissionCount(input || {});
    if (triangleMissionCount > 0) errors.push("Mission Core is square-only; triangles cannot be mission objectives.");

    const seenIds = new Set((normalized.mechanics?.launchers || []).map((launcher) => launcher.id));
    for (let rowIndex = 0; rowIndex < (normalized.incomingRows || []).length; rowIndex += 1) {
      for (const launcher of normalized.incomingRows[rowIndex].launchers || []) {
        if (!DIRECTIONS.has(launcher.direction)) errors.push(`Incoming +${rowIndex + 1} launcher ${launcher.id}: invalid direction.`);
        if (seenIds.has(launcher.id)) errors.push(`Duplicate mechanic id: ${launcher.id}.`);
        seenIds.add(launcher.id);
      }
    }

    if (normalized.rules?.winCondition === MISSION_WIN && missionCount(normalized) === 0) {
      errors.push("Mission objective levels need at least one Mission Core block.");
    }
    if (missionCount(normalized) > 0) warnings.push(`${missionCount(normalized)} Mission Core objective(s): the level clears when all objectives are destroyed, including authored future rows.`);
    return { level: normalized, errors, warnings, valid: errors.length === 0 };
  };
  M.toExportJson = (input) => {
    const exported = JSON.parse(baseToExportJson(input));
    restoreMissionVariants(input || {}, exported);
    return JSON.stringify(exported, null, 2);
  };
})();
