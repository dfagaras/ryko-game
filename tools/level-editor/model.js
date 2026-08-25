(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.RykoLevelModel = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const BOARD = Object.freeze({
    logicalWidth: 720,
    logicalHeight: 1280,
    boardLeft: 28,
    boardRight: 692,
    boardTop: 176,
    gridX: 40,
    gridY: 268,
    launchLineY: 1092,
    columns: 7,
    rows: 9,
    cell: 88,
    gap: 4,
    rowStep: 92
  });

  const SCHEMA_VERSION = 1;
  const MODES = Object.freeze({ CLEAR_LIMITED: "clear_limited", DESCENT: "descent" });

  const BLOCK_VARIANTS = new Set(["normal", "dense", "regenerative", "phase", "black_hole"]);
  const TRIANGLE_ORIENTATIONS = new Set(["top_left", "top_right", "bottom_left", "bottom_right"]);
  const POWER_TYPES = new Set(["ion", "ghost", "supernova"]);

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function createDefaultLevel() {
    return {
      schemaVersion: SCHEMA_VERSION,
      levelId: "level_001",
      name: "New Ryko Level",
      board: clone(BOARD),
      rules: {
        mode: MODES.CLEAR_LIMITED,
        startingBalls: 1,
        winCondition: "clear_all_content",
        loseCondition: "move_limit",
        moveLimit: 10,
        descent: {
          rowsPerMove: 1,
          incomingSource: "authored",
          loseWhenBlockReachesLaunchLine: true
        }
      },
      initialBoard: [],
      incomingRows: []
    };
  }

  function inBounds(column, row) {
    return Number.isInteger(column) && column >= 0 && column < BOARD.columns && Number.isInteger(row) && row >= 0 && row < BOARD.rows;
  }

  function cellKey(column, row) {
    return `${column}:${row}`;
  }

  function normalizeEntity(entity, fallbackRow) {
    if (!entity || typeof entity !== "object") return null;
    const column = Number(entity.column);
    const row = Number(entity.row ?? fallbackRow ?? 0);
    const normalized = { column, row };

    if (entity.kind === "block") {
      normalized.kind = "block";
      normalized.shape = entity.shape === "triangle" ? "triangle" : "square";
      normalized.variant = BLOCK_VARIANTS.has(entity.variant) ? entity.variant : "normal";
      normalized.hp = Math.max(1, Math.trunc(Number(entity.hp) || 1));
      if (normalized.shape === "triangle") {
        normalized.variant = "normal";
        normalized.orientation = TRIANGLE_ORIENTATIONS.has(entity.orientation) ? entity.orientation : "top_left";
      }
      if (normalized.variant === "black_hole") {
        const allowed = new Set(["left", "right", "top", "bottom"]);
        const sides = Array.isArray(entity.absorbingSides) ? entity.absorbingSides.filter((side) => allowed.has(side)) : ["top"];
        normalized.absorbingSides = [...new Set(sides)];
      }
      if (normalized.variant === "phase") normalized.phaseActive = entity.phaseActive !== false;
      return normalized;
    }

    if (entity.kind === "pickup" && entity.type === "plus_ball") {
      return { kind: "pickup", type: "plus_ball", column, row };
    }

    if (entity.kind === "power" && POWER_TYPES.has(entity.type)) {
      const power = { kind: "power", type: entity.type, column, row };
      if (entity.type === "ion") power.orientation = entity.orientation === "vertical" ? "vertical" : "horizontal";
      return power;
    }

    return null;
  }

  function normalizeLevel(input) {
    const base = createDefaultLevel();
    const source = input && typeof input === "object" ? input : {};
    const level = createDefaultLevel();
    level.levelId = String(source.levelId || base.levelId).trim() || base.levelId;
    level.name = String(source.name || base.name).trim() || base.name;
    level.rules.mode = source.rules?.mode === MODES.DESCENT ? MODES.DESCENT : MODES.CLEAR_LIMITED;
    level.rules.startingBalls = Math.max(1, Math.trunc(Number(source.rules?.startingBalls) || 1));
    level.rules.moveLimit = Math.max(1, Math.trunc(Number(source.rules?.moveLimit) || 10));
    level.rules.loseCondition = level.rules.mode === MODES.DESCENT ? "block_reaches_launch_line" : "move_limit";
    level.rules.winCondition = "clear_all_content";
    level.rules.descent = {
      rowsPerMove: 1,
      incomingSource: "authored",
      loseWhenBlockReachesLaunchLine: true
    };

    const initial = Array.isArray(source.initialBoard) ? source.initialBoard : [];
    const occupied = new Set();
    level.initialBoard = [];
    for (const raw of initial) {
      const entity = normalizeEntity(raw);
      if (!entity || !inBounds(entity.column, entity.row)) continue;
      const key = cellKey(entity.column, entity.row);
      if (occupied.has(key)) continue;
      occupied.add(key);
      level.initialBoard.push(entity);
    }

    const incomingRows = Array.isArray(source.incomingRows) ? source.incomingRows : [];
    level.incomingRows = incomingRows.map((rowDef, index) => {
      const cells = Array.isArray(rowDef?.cells) ? rowDef.cells : [];
      const rowOccupied = new Set();
      const normalizedCells = [];
      for (const raw of cells) {
        const entity = normalizeEntity({ ...raw, row: 0 }, 0);
        if (!entity || entity.column < 0 || entity.column >= BOARD.columns) continue;
        const key = String(entity.column);
        if (rowOccupied.has(key)) continue;
        rowOccupied.add(key);
        normalizedCells.push(entity);
      }
      return { afterMove: index + 1, cells: normalizedCells };
    });

    return level;
  }

  function validateLevel(input) {
    const level = normalizeLevel(input);
    const errors = [];
    const warnings = [];

    if (!String(level.levelId).trim()) errors.push("Level ID is required.");
    if (!String(level.name).trim()) errors.push("Level name is required.");
    if (level.rules.startingBalls < 1) errors.push("Starting balls must be at least 1.");
    if (level.rules.mode === MODES.CLEAR_LIMITED && level.rules.moveLimit < 1) errors.push("Clear mode needs a move limit of at least 1.");

    const allBlocks = [];
    const inspectEntity = (entity, label) => {
      if (entity.kind === "block") {
        allBlocks.push(entity);
        if (!Number.isInteger(entity.hp) || entity.hp < 1) errors.push(`${label}: block HP must be a positive integer.`);
        if (entity.shape === "triangle" && entity.variant !== "normal") errors.push(`${label}: triangles cannot use special variants.`);
        if (entity.variant === "black_hole" && (!Array.isArray(entity.absorbingSides) || entity.absorbingSides.length === 0)) {
          errors.push(`${label}: Black Hole needs at least one absorbing side.`);
        }
      }
    };

    level.initialBoard.forEach((entity, index) => inspectEntity(entity, `Initial cell ${index + 1}`));
    level.incomingRows.forEach((row, rowIndex) => row.cells.forEach((entity, index) => inspectEntity(entity, `Incoming +${rowIndex + 1}, cell ${index + 1}`)));

    const initialBlocks = level.initialBoard.filter((entity) => entity.kind === "block").length;
    if (initialBlocks === 0) errors.push("The initial board needs at least one block so the level cannot complete before play begins.");

    if (level.rules.mode === MODES.DESCENT) {
      const dangerBlocks = level.initialBoard.filter((entity) => entity.kind === "block" && entity.row >= BOARD.rows - 2);
      if (dangerBlocks.length) warnings.push(`${dangerBlocks.length} block(s) start on or one row above the danger line; they must be destroyed before the next descent.`);
      if (level.incomingRows.length === 0) warnings.push("No authored incoming rows: the initial board will only move downward each turn.");
    } else if (level.incomingRows.some((row) => row.cells.length)) {
      warnings.push("Incoming rows are saved but ignored while mode is Clear in N moves.");
    }

    const nonEmptyIncoming = level.incomingRows.reduce((sum, row) => sum + row.cells.length, 0);
    if (allBlocks.length > 0 && allBlocks.every((block) => block.hp === 1) && level.rules.startingBalls > 20) {
      warnings.push("All blocks have 1 HP while starting ball count is high; this may be intentionally very easy.");
    }
    if (level.rules.mode === MODES.DESCENT && nonEmptyIncoming === 0 && initialBlocks < 3) {
      warnings.push("This descent level contains very little authored content.");
    }

    return { level, errors, warnings, valid: errors.length === 0 };
  }

  function simulateDescent(input, completedMoves) {
    const level = normalizeLevel(input);
    const moves = Math.max(0, Math.trunc(Number(completedMoves) || 0));
    let entities = level.initialBoard.map((entity) => clone(entity));
    let danger = false;
    let dangerAtMove = null;

    for (let move = 1; move <= moves; move += 1) {
      const shifted = [];
      for (const entity of entities) {
        const next = { ...entity, row: entity.row + 1 };
        // Matches main.gd: row 8 has its bottom edge exactly on LAUNCH_LINE_Y,
        // so reaching the last playable row after an advance is already a loss.
        if (next.kind === "block" && next.row >= BOARD.rows - 1) {
          danger = true;
          if (dangerAtMove === null) dangerAtMove = move;
        }
        if (next.row < BOARD.rows) shifted.push(next);
      }
      entities = shifted;

      const incoming = level.incomingRows[move - 1];
      if (incoming) {
        for (const entity of incoming.cells) entities.push({ ...clone(entity), row: 0 });
      }
    }

    return { entities, danger, dangerAtMove, completedMoves: moves };
  }

  function toExportJson(input) {
    const validation = validateLevel(input);
    const level = validation.level;
    level.schemaVersion = SCHEMA_VERSION;
    level.board = clone(BOARD);
    if (level.rules.mode === MODES.CLEAR_LIMITED) {
      level.rules.loseCondition = "move_limit";
    } else {
      level.rules.loseCondition = "block_reaches_launch_line";
    }
    return JSON.stringify(level, null, 2);
  }

  return {
    BOARD,
    SCHEMA_VERSION,
    MODES,
    createDefaultLevel,
    normalizeLevel,
    normalizeEntity,
    validateLevel,
    simulateDescent,
    toExportJson,
    clone
  };
});
