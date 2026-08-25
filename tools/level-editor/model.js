(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.RykoLevelModel = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const BASE_BOARD = Object.freeze({
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

  const BASE_GRID_WIDTH = BASE_BOARD.columns * BASE_BOARD.cell + (BASE_BOARD.columns - 1) * BASE_BOARD.gap;
  const BASE_GRID_HEIGHT = BASE_BOARD.rows * BASE_BOARD.cell + (BASE_BOARD.rows - 1) * BASE_BOARD.gap;
  const MIN_BOARD_SCALE = 1;
  const MAX_BOARD_SCALE = 4;
  let activeBoardScale = 1;

  function isSupportedBoardScale(value) {
    const scale = Math.trunc(Number(value));
    return Number.isFinite(scale) && scale >= MIN_BOARD_SCALE && scale <= MAX_BOARD_SCALE;
  }

  function normalizeBoardScale(value) {
    const scale = Math.trunc(Number(value) || 1);
    return Math.min(MAX_BOARD_SCALE, Math.max(MIN_BOARD_SCALE, scale));
  }

  function inferBoardScale(source) {
    const explicit = source?.boardScale ?? source?.board?.scale;
    if (explicit !== undefined && explicit !== null) return normalizeBoardScale(explicit);
    const columns = Number(source?.board?.columns);
    const rows = Number(source?.board?.rows);
    if (Number.isInteger(columns) && Number.isInteger(rows) && columns % BASE_BOARD.columns === 0 && rows % BASE_BOARD.rows === 0) {
      const columnScale = columns / BASE_BOARD.columns;
      const rowScale = rows / BASE_BOARD.rows;
      if (columnScale === rowScale) return normalizeBoardScale(columnScale);
    }
    return 1;
  }

  function boardForScale(value) {
    const scale = normalizeBoardScale(value);
    const columns = BASE_BOARD.columns * scale;
    const rows = BASE_BOARD.rows * scale;
    const cell = BASE_BOARD.cell / scale;

    // The physical board must remain exactly the same size. Scaling the old
    // 4px gap directly would slightly expand dense grids because they contain
    // more separators. Recalculate the gaps from the fixed 7x9 footprint.
    const columnGap = columns > 1 ? (BASE_GRID_WIDTH - columns * cell) / (columns - 1) : 0;
    const rowGap = rows > 1 ? (BASE_GRID_HEIGHT - rows * cell) / (rows - 1) : 0;
    const columnStep = cell + columnGap;
    const rowStep = cell + rowGap;

    return {
      ...BASE_BOARD,
      scale,
      columns,
      rows,
      cell,
      // gap remains for schema-v1 compatibility. New code should use the
      // explicit horizontal/vertical values below.
      gap: columnGap,
      columnGap,
      rowGap,
      columnStep,
      rowStep,
      gridWidth: BASE_GRID_WIDTH,
      gridHeight: BASE_GRID_HEIGHT,
      dangerRow: rows - 1,
      visualScale: 1 / scale,
      ballRadius: 9 / scale,
      ballCollisionRadius: 10 / scale,
      ballSpeed: 760 / scale,
      pickupRadius: 19 / scale,
      ionRadius: 20 / scale,
      ghostRadius: 20 / scale,
      supernovaCoreRadius: 22 / scale,
      supernovaExplosionRadius: cell * 0.75
    };
  }

  const BOARD = {};
  for (const key of Object.keys(boardForScale(1))) {
    Object.defineProperty(BOARD, key, { enumerable: true, get: () => boardForScale(activeBoardScale)[key] });
  }

  const SCHEMA_VERSION = 1;
  const MODES = Object.freeze({ CLEAR_LIMITED: "clear_limited", DESCENT: "descent" });
  const BLOCK_VARIANTS = new Set(["normal", "dense", "regenerative", "phase", "black_hole"]);
  const TRIANGLE_ORIENTATIONS = new Set(["top_left", "top_right", "bottom_left", "bottom_right"]);
  const POWER_TYPES = new Set(["ion", "ghost", "supernova"]);

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function createDefaultLevel() {
    activeBoardScale = 1;
    return {
      schemaVersion: SCHEMA_VERSION,
      levelId: "level_001",
      name: "New Ryko Level",
      boardScale: 1,
      board: boardForScale(1),
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

  function boardForLevel(level) {
    return boardForScale(level?.boardScale ?? level?.board?.scale ?? 1);
  }

  function inBounds(column, row, board = boardForScale(activeBoardScale)) {
    return Number.isInteger(column) && column >= 0 && column < board.columns && Number.isInteger(row) && row >= 0 && row < board.rows;
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

    if (entity.kind === "pickup" && entity.type === "plus_ball") return { kind: "pickup", type: "plus_ball", column, row };
    if (entity.kind === "power" && POWER_TYPES.has(entity.type)) {
      const power = { kind: "power", type: entity.type, column, row };
      if (entity.type === "ion") power.orientation = entity.orientation === "vertical" ? "vertical" : "horizontal";
      return power;
    }
    return null;
  }

  function normalizeLevel(input) {
    const source = input && typeof input === "object" ? input : {};
    const scale = inferBoardScale(source);
    const board = boardForScale(scale);
    const base = createDefaultLevel();
    const level = createDefaultLevel();

    level.levelId = String(source.levelId || base.levelId).trim() || base.levelId;
    level.name = String(source.name || base.name).trim() || base.name;
    level.boardScale = scale;
    level.board = board;
    level.rules.mode = source.rules?.mode === MODES.DESCENT ? MODES.DESCENT : MODES.CLEAR_LIMITED;
    level.rules.startingBalls = Math.max(1, Math.trunc(Number(source.rules?.startingBalls) || 1));
    level.rules.moveLimit = Math.max(1, Math.trunc(Number(source.rules?.moveLimit) || 10));
    level.rules.loseCondition = level.rules.mode === MODES.DESCENT ? "block_reaches_launch_line" : "move_limit";
    level.rules.winCondition = "clear_all_content";
    level.rules.descent = { rowsPerMove: 1, incomingSource: "authored", loseWhenBlockReachesLaunchLine: true };

    const initial = Array.isArray(source.initialBoard) ? source.initialBoard : [];
    const occupied = new Set();
    level.initialBoard = [];
    for (const raw of initial) {
      const entity = normalizeEntity(raw);
      if (!entity || !inBounds(entity.column, entity.row, board)) continue;
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
        if (!entity || entity.column < 0 || entity.column >= board.columns) continue;
        const key = String(entity.column);
        if (rowOccupied.has(key)) continue;
        rowOccupied.add(key);
        normalizedCells.push(entity);
      }
      return { afterMove: index + 1, cells: normalizedCells };
    });

    activeBoardScale = scale;
    return level;
  }

  function validateLevel(input) {
    const raw = input && typeof input === "object" ? input : {};
    const explicitScale = raw.boardScale ?? raw.board?.scale;
    const level = normalizeLevel(raw);
    const board = boardForLevel(level);
    const errors = [];
    const warnings = [];

    if (explicitScale !== undefined && explicitScale !== null && !isSupportedBoardScale(explicitScale)) {
      errors.push("Board scale must be 1, 2, 3 or 4.");
    }
    if (!String(level.levelId).trim()) errors.push("Level ID is required.");
    if (!String(level.name).trim()) errors.push("Level name is required.");
    if (level.rules.startingBalls < 1) errors.push("Starting balls must be at least 1.");
    if (level.rules.mode === MODES.CLEAR_LIMITED && level.rules.moveLimit < 1) errors.push("Clear mode needs a move limit of at least 1.");

    const allBlocks = [];
    const inspectEntity = (entity, label) => {
      if (entity.kind !== "block") return;
      allBlocks.push(entity);
      if (!Number.isInteger(entity.hp) || entity.hp < 1) errors.push(`${label}: block HP must be a positive integer.`);
      if (entity.shape === "triangle" && entity.variant !== "normal") errors.push(`${label}: triangles cannot use special variants.`);
      if (entity.variant === "black_hole" && (!Array.isArray(entity.absorbingSides) || entity.absorbingSides.length === 0)) errors.push(`${label}: Black Hole needs at least one absorbing side.`);
    };

    level.initialBoard.forEach((entity, index) => inspectEntity(entity, `Initial cell ${index + 1}`));
    level.incomingRows.forEach((row, rowIndex) => row.cells.forEach((entity, index) => inspectEntity(entity, `Incoming +${rowIndex + 1}, cell ${index + 1}`)));

    const initialBlocks = level.initialBoard.filter((entity) => entity.kind === "block").length;
    if (initialBlocks === 0) errors.push("The initial board needs at least one block so the level cannot complete before play begins.");

    if (level.rules.mode === MODES.DESCENT) {
      const dangerBlocks = level.initialBoard.filter((entity) => entity.kind === "block" && entity.row >= board.dangerRow - 1);
      if (dangerBlocks.length) warnings.push(`${dangerBlocks.length} block(s) start on or one row above the danger line; they must be destroyed before the next descent.`);
      if (level.incomingRows.length === 0) warnings.push("No authored incoming rows: the initial board will only move downward each turn.");
    } else if (level.incomingRows.some((row) => row.cells.length)) {
      warnings.push("Incoming rows are saved but ignored while mode is Clear in N moves.");
    }

    const nonEmptyIncoming = level.incomingRows.reduce((sum, row) => sum + row.cells.length, 0);
    if (allBlocks.length > 0 && allBlocks.every((block) => block.hp === 1) && level.rules.startingBalls > 20) warnings.push("All blocks have 1 HP while starting ball count is high; this may be intentionally very easy.");
    if (level.rules.mode === MODES.DESCENT && nonEmptyIncoming === 0 && initialBlocks < 3) warnings.push("This descent level contains very little authored content.");
    if (level.boardScale >= 3) warnings.push(`${board.columns}×${board.rows} is a high-density zoom-out board; verify HP readability on a phone build.`);

    return { level, errors, warnings, valid: errors.length === 0 };
  }

  function simulateDescent(input, completedMoves) {
    const level = normalizeLevel(input);
    const board = boardForLevel(level);
    const moves = Math.max(0, Math.trunc(Number(completedMoves) || 0));
    let entities = level.initialBoard.map((entity) => clone(entity));
    let danger = false;
    let dangerAtMove = null;

    for (let move = 1; move <= moves; move += 1) {
      const shifted = [];
      for (const entity of entities) {
        const next = { ...entity, row: entity.row + 1 };
        if (next.kind === "block" && next.row >= board.dangerRow) {
          danger = true;
          if (dangerAtMove === null) dangerAtMove = move;
        }
        if (next.row < board.rows) shifted.push(next);
      }
      entities = shifted;
      const incoming = level.incomingRows[move - 1];
      if (incoming) for (const entity of incoming.cells) entities.push({ ...clone(entity), row: 0 });
    }

    return { entities, danger, dangerAtMove, completedMoves: moves };
  }

  function toExportJson(input) {
    const validation = validateLevel(input);
    const level = validation.level;
    level.schemaVersion = SCHEMA_VERSION;
    level.board = boardForLevel(level);
    level.rules.loseCondition = level.rules.mode === MODES.CLEAR_LIMITED ? "move_limit" : "block_reaches_launch_line";
    activeBoardScale = level.boardScale;
    return JSON.stringify(level, null, 2);
  }

  function setActiveBoardScale(value) {
    activeBoardScale = normalizeBoardScale(value);
    return boardForScale(activeBoardScale);
  }

  return {
    BASE_BOARD,
    BASE_GRID_WIDTH,
    BASE_GRID_HEIGHT,
    BOARD,
    SCHEMA_VERSION,
    MODES,
    MIN_BOARD_SCALE,
    MAX_BOARD_SCALE,
    isSupportedBoardScale,
    boardForScale,
    boardForLevel,
    normalizeBoardScale,
    setActiveBoardScale,
    createDefaultLevel,
    normalizeLevel,
    normalizeEntity,
    validateLevel,
    simulateDescent,
    toExportJson,
    clone
  };
});
