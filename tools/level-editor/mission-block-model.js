(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M) return;

  const MISSION_VARIANT = "mission_core";
  const MISSION_WIN = "destroy_all_objectives";
  const CLEAR_WIN = "clear_all_content";
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
    const objectiveCount = missionCount(target);
    target.rules = target.rules || {};
    target.rules.winCondition = objectiveCount > 0 ? MISSION_WIN : CLEAR_WIN;
    return target;
  }

  function missionCount(level) {
    let count = (level.initialBoard || []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT).length;
    count += (level.topRow || []).filter((entity) => entity?.kind === "block" && entity?.variant === MISSION_VARIANT).length;
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
  M.normalizeLevel = (input) => restoreMissionVariants(input || {}, baseNormalizeLevel(input));
  M.validateLevel = (input) => {
    const base = baseValidateLevel(input);
    const normalized = M.normalizeLevel(input || {});
    const errors = [...base.errors];
    const warnings = [...base.warnings];
    const triangleMissionCount = rawTriangleMissionCount(input || {});
    if (triangleMissionCount > 0) errors.push("Mission Core is square-only; triangles cannot be mission objectives.");
    if ((normalized.incomingRows || []).some((row) => (row.cells || []).some((entity) => entity.variant === MISSION_VARIANT))) {
      errors.push("Mission Core must start on the authored board or top row; incoming mission objectives are not supported yet.");
    }
    if (normalized.rules?.winCondition === MISSION_WIN && missionCount(normalized) === 0) {
      errors.push("Mission objective levels need at least one Mission Core block.");
    }
    if (missionCount(normalized) > 0) warnings.push(`${missionCount(normalized)} Mission Core objective(s): the level clears when all objectives are destroyed.`);
    return { level: normalized, errors, warnings, valid: errors.length === 0 };
  };
  M.toExportJson = (input) => {
    const exported = JSON.parse(baseToExportJson(input));
    restoreMissionVariants(input || {}, exported);
    return JSON.stringify(exported, null, 2);
  };
})();
