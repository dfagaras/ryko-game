(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M || M.__mechanicsExtended) return;

  const DIRECTIONS = Object.freeze(["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]);
  const SIDES = Object.freeze(["top", "right", "bottom", "left"]);
  const DIRECTION_SET = new Set(DIRECTIONS);
  const SIDE_SET = new Set(SIDES);

  const baseCreateDefaultLevel = M.createDefaultLevel.bind(M);
  const baseNormalizeLevel = M.normalizeLevel.bind(M);
  const baseValidateLevel = M.validateLevel.bind(M);
  const baseToExportJson = M.toExportJson.bind(M);

  const clamp01 = (value) => Math.min(1, Math.max(0, Number.isFinite(Number(value)) ? Number(value) : 0));
  const positiveSeconds = (value, fallback) => Number.isFinite(Number(value)) && Number(value) > 0 ? Math.round(Number(value) * 100) / 100 : fallback;
  const boardPosition = (item, board) => ({
    column: Math.min(board.columns - 1, Math.max(0, Math.trunc(Number(item?.column) || 0))),
    row: Math.min(board.rows - 1, Math.max(0, Math.trunc(Number(item?.row) || 0)))
  });
  const launcherPosition = (item, board) => ({
    column: Math.min(board.columns - 1, Math.max(0, Math.trunc(Number(item?.column) || 0))),
    row: Number(item?.row) === -1 ? -1 : Math.min(board.rows - 1, Math.max(0, Math.trunc(Number(item?.row) || 0)))
  });

  function laserPointForGridLine(level, rawColumnLine, rawRowLine) {
    const board = M.boardForLevel(level || {});
    const columnLine = Math.trunc(Number(rawColumnLine));
    const rowLine = Math.trunc(Number(rawRowLine));
    if (!Number.isInteger(columnLine) || !Number.isInteger(rowLine) || columnLine < 0 || columnLine > board.columns || rowLine < 0 || rowLine > board.rows) return null;

    const logicalX = columnLine === board.columns
      ? board.gridX + board.gridWidth
      : board.gridX + columnLine * board.columnStep;
    const logicalY = rowLine === board.rows
      ? board.gridY + board.gridHeight
      : board.gridY + rowLine * board.rowStep;
    const laserWidth = board.boardRight - board.boardLeft;
    const laserHeight = board.launchLineY - board.boardTop;
    if (!(laserWidth > 0) || !(laserHeight > 0)) return null;

    return {
      x: clamp01((logicalX - board.boardLeft) / laserWidth),
      y: clamp01((logicalY - board.boardTop) / laserHeight)
    };
  }

  function normalizeMechanics(raw, level) {
    const source = raw && typeof raw === "object" ? raw : {};
    const board = M.boardForLevel(level || {});
    const launchers = Array.isArray(source.launchers) ? source.launchers : [];
    const lasers = Array.isArray(source.lasers) ? source.lasers : [];
    const shields = Array.isArray(source.shields) ? source.shields : [];
    const switches = Array.isArray(source.switches) ? source.switches : [];
    const portals = Array.isArray(source.portals) ? source.portals : [];

    return {
      launchers: launchers.map((item, index) => ({ id: String(item?.id || `launcher_${index + 1}`), ...launcherPosition(item, board), direction: DIRECTION_SET.has(item?.direction) ? item.direction : "up" })),
      lasers: lasers.map((item, index) => ({
        id: String(item?.id || `laser_${index + 1}`),
        from: { x: clamp01(item?.from?.x), y: clamp01(item?.from?.y) }, to: { x: clamp01(item?.to?.x ?? 1), y: clamp01(item?.to?.y) },
        onSeconds: positiveSeconds(item?.onSeconds, 1.5), offSeconds: positiveSeconds(item?.offSeconds, 1.0),
        startDelay: Math.max(0, Number(item?.startDelay) || 0), startsOn: item?.startsOn !== false
      })),
      shields: shields.map((item, index) => ({
        id: String(item?.id || `shield_${index + 1}`), ...boardPosition(item, board),
        sides: [...new Set((Array.isArray(item?.sides) ? item.sides : ["top"]).filter((side) => SIDE_SET.has(side)))]
      })),
      switches: switches.map((item, index) => ({
        id: String(item?.id || `switch_${index + 1}`), ...boardPosition(item, board),
        targetId: String(item?.targetId || ""), action: item?.action === "enable" ? "enable" : "disable",
        durationSeconds: Math.max(0, Number(item?.durationSeconds) || 0)
      })),
      portals: portals.map((item, index) => ({
        id: String(item?.id || `portal_${index + 1}`), pairId: String(item?.pairId || `pair_${Math.floor(index / 2) + 1}`), ...boardPosition(item, board)
      }))
    };
  }

  function attach(level, source) {
    level.mechanics = normalizeMechanics(source?.mechanics, level);
    window.RykoMechanicsLevelRef = level;
    return level;
  }

  M.createDefaultLevel = function () { return attach(baseCreateDefaultLevel(), { mechanics: {} }); };
  M.normalizeLevel = function (input) { return attach(baseNormalizeLevel(input), input || {}); };
  M.validateLevel = function (input) {
    const result = baseValidateLevel(input);
    result.level.mechanics = normalizeMechanics(input?.mechanics, result.level);
    const board = M.boardForLevel(result.level);
    const ids = new Set();
    const all = [...result.level.mechanics.launchers, ...result.level.mechanics.lasers, ...result.level.mechanics.shields, ...result.level.mechanics.switches, ...result.level.mechanics.portals];
    for (const item of all) { if (ids.has(item.id)) result.errors.push(`Duplicate mechanic id: ${item.id}.`); ids.add(item.id); }
    for (const launcher of result.level.mechanics.launchers) {
      if (!DIRECTION_SET.has(launcher.direction)) result.errors.push(`Launcher ${launcher.id}: invalid direction.`);
      if (launcher.column < 0 || launcher.column >= board.columns || launcher.row < -1 || launcher.row >= board.rows) result.errors.push(`${launcher.id}: position is outside the board.`);
    }
    for (const laser of result.level.mechanics.lasers) {
      if (laser.onSeconds <= 0 || laser.offSeconds <= 0) result.errors.push(`Laser ${laser.id}: ON and OFF durations must be greater than 0.`);
      if (laser.from.x === laser.to.x && laser.from.y === laser.to.y) result.errors.push(`Laser ${laser.id}: endpoints must be different.`);
    }
    for (const shield of result.level.mechanics.shields) if (!shield.sides.length) result.errors.push(`Shield ${shield.id}: select at least one protected side.`);
    const laserIds = new Set(result.level.mechanics.lasers.map((item) => item.id));
    for (const sw of result.level.mechanics.switches) if (!laserIds.has(sw.targetId)) result.errors.push(`Switch ${sw.id}: target laser '${sw.targetId}' does not exist.`);
    const pairCounts = new Map();
    for (const portal of result.level.mechanics.portals) pairCounts.set(portal.pairId, (pairCounts.get(portal.pairId) || 0) + 1);
    for (const [pairId, count] of pairCounts) if (count !== 2) result.errors.push(`Portal pair ${pairId}: exactly 2 portals are required.`);
    for (const item of [...result.level.mechanics.shields, ...result.level.mechanics.switches, ...result.level.mechanics.portals]) {
      if (item.column < 0 || item.column >= board.columns || item.row < 0 || item.row >= board.rows) result.errors.push(`${item.id}: position is outside the board.`);
    }
    result.valid = result.errors.length === 0;
    window.RykoMechanicsLevelRef = result.level;
    return result;
  };
  M.toExportJson = function (input) { const parsed = JSON.parse(baseToExportJson(input)); parsed.mechanics = normalizeMechanics(input?.mechanics, parsed); return JSON.stringify(parsed, null, 2); };
  M.MECHANIC_DIRECTIONS = DIRECTIONS;
  M.MECHANIC_SIDES = SIDES;
  M.normalizeMechanics = normalizeMechanics;
  M.laserPointForGridLine = laserPointForGridLine;
  M.__mechanicsExtended = true;
})();
