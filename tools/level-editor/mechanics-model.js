(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M || M.__mechanicsExtended) return;

  const DIRECTIONS = Object.freeze(["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]);
  const DIRECTION_SET = new Set(DIRECTIONS);

  const baseCreateDefaultLevel = M.createDefaultLevel.bind(M);
  const baseNormalizeLevel = M.normalizeLevel.bind(M);
  const baseValidateLevel = M.validateLevel.bind(M);
  const baseToExportJson = M.toExportJson.bind(M);

  function clamp01(value) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return 0;
    return Math.min(1, Math.max(0, parsed));
  }

  function positiveSeconds(value, fallback) {
    const parsed = Number(value);
    return Number.isFinite(parsed) && parsed > 0 ? Math.round(parsed * 100) / 100 : fallback;
  }

  function normalizeMechanics(raw, level) {
    const source = raw && typeof raw === "object" ? raw : {};
    const board = M.boardForLevel(level || {});
    const launchers = Array.isArray(source.launchers) ? source.launchers : [];
    const lasers = Array.isArray(source.lasers) ? source.lasers : [];

    return {
      launchers: launchers.map((item, index) => ({
        id: String(item?.id || `launcher_${index + 1}`),
        column: Math.min(board.columns - 1, Math.max(0, Math.trunc(Number(item?.column) || 0))),
        row: Math.min(board.rows - 1, Math.max(0, Math.trunc(Number(item?.row) || 0))),
        direction: DIRECTION_SET.has(item?.direction) ? item.direction : "up"
      })),
      lasers: lasers.map((item, index) => ({
        id: String(item?.id || `laser_${index + 1}`),
        from: { x: clamp01(item?.from?.x), y: clamp01(item?.from?.y) },
        to: { x: clamp01(item?.to?.x ?? 1), y: clamp01(item?.to?.y) },
        onSeconds: positiveSeconds(item?.onSeconds, 1.5),
        offSeconds: positiveSeconds(item?.offSeconds, 1.0),
        startDelay: Math.max(0, Number(item?.startDelay) || 0),
        startsOn: item?.startsOn !== false
      }))
    };
  }

  function attach(level, source) {
    level.mechanics = normalizeMechanics(source?.mechanics, level);
    window.RykoMechanicsLevelRef = level;
    return level;
  }

  M.createDefaultLevel = function () {
    return attach(baseCreateDefaultLevel(), { mechanics: { launchers: [], lasers: [] } });
  };

  M.normalizeLevel = function (input) {
    return attach(baseNormalizeLevel(input), input || {});
  };

  M.validateLevel = function (input) {
    const result = baseValidateLevel(input);
    result.level.mechanics = normalizeMechanics(input?.mechanics, result.level);
    const board = M.boardForLevel(result.level);
    const ids = new Set();

    for (const launcher of result.level.mechanics.launchers) {
      if (!DIRECTION_SET.has(launcher.direction)) result.errors.push(`Launcher ${launcher.id}: invalid direction.`);
      if (launcher.column < 0 || launcher.column >= board.columns || launcher.row < 0 || launcher.row >= board.rows) result.errors.push(`Launcher ${launcher.id}: position is outside the board.`);
      if (ids.has(launcher.id)) result.errors.push(`Duplicate mechanic id: ${launcher.id}.`);
      ids.add(launcher.id);
    }

    for (const laser of result.level.mechanics.lasers) {
      if (ids.has(laser.id)) result.errors.push(`Duplicate mechanic id: ${laser.id}.`);
      ids.add(laser.id);
      if (laser.onSeconds <= 0 || laser.offSeconds <= 0) result.errors.push(`Laser ${laser.id}: ON and OFF durations must be greater than 0.`);
      if (laser.from.x === laser.to.x && laser.from.y === laser.to.y) result.errors.push(`Laser ${laser.id}: endpoints must be different.`);
    }

    result.valid = result.errors.length === 0;
    window.RykoMechanicsLevelRef = result.level;
    return result;
  };

  M.toExportJson = function (input) {
    const parsed = JSON.parse(baseToExportJson(input));
    parsed.mechanics = normalizeMechanics(input?.mechanics, parsed);
    return JSON.stringify(parsed, null, 2);
  };

  M.MECHANIC_DIRECTIONS = DIRECTIONS;
  M.normalizeMechanics = normalizeMechanics;
  M.__mechanicsExtended = true;
})();
