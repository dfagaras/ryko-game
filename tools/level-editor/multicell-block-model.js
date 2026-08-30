(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M || M.__multicellBlocksExtended) return;

  const MAX_SPAN = 4;
  const baseNormalizeLevel = M.normalizeLevel.bind(M);
  const baseValidateLevel = M.validateLevel.bind(M);
  const baseToExportJson = M.toExportJson.bind(M);
  const baseSimulateDescent = typeof M.simulateDescent === "function" ? M.simulateDescent.bind(M) : null;

  const span = (value) => Math.min(MAX_SPAN, Math.max(1, Math.trunc(Number(value) || 1)));
  const supportsMultiCell = (entity) => entity?.kind === "block" && entity?.shape !== "triangle" && ["normal", "mission_core"].includes(String(entity?.variant || "normal"));

  function footprint(entity) {
    return {
      width: supportsMultiCell(entity) ? span(entity?.widthCells) : 1,
      height: supportsMultiCell(entity) ? span(entity?.heightCells) : 1
    };
  }

  function covers(entity, column, row) {
    const size = footprint(entity);
    return column >= entity.column && column < entity.column + size.width && row >= entity.row && row < entity.row + size.height;
  }

  function footprintCells(entity) {
    const size = footprint(entity);
    const cells = [];
    for (let row = entity.row; row < entity.row + size.height; row += 1) {
      for (let column = entity.column; column < entity.column + size.width; column += 1) cells.push({ column, row });
    }
    return cells;
  }

  function entityCoveringCell(entities, column, row) {
    return (entities || []).find((entity) => covers(entity, column, row)) || null;
  }

  function footprintConflict(entities, candidate, ignore = null) {
    for (const cell of footprintCells(candidate)) {
      const hit = (entities || []).find((entity) => entity !== ignore && covers(entity, cell.column, cell.row));
      if (hit) return hit;
    }
    return null;
  }

  function sourceEntityAt(source, column, row) {
    return (Array.isArray(source?.initialBoard) ? source.initialBoard : []).find((item) => Number(item?.column) === column && Number(item?.row) === row) || null;
  }

  function restoreSpans(source, target) {
    const board = M.boardForLevel(target || {});
    for (const entity of target.initialBoard || []) {
      const raw = sourceEntityAt(source, entity.column, entity.row);
      if (!supportsMultiCell(entity) || !raw) {
        entity.widthCells = 1;
        entity.heightCells = 1;
        continue;
      }
      entity.widthCells = span(raw.widthCells);
      entity.heightCells = span(raw.heightCells);
      // Keep the normalized object deterministic even when an imported block is invalid.
      // Validation below reports the error instead of silently moving the block.
      if (entity.column + entity.widthCells > board.columns || entity.row + entity.heightCells > board.rows) {
        entity.widthCells = span(raw.widthCells);
        entity.heightCells = span(raw.heightCells);
      }
    }
    return target;
  }

  M.normalizeLevel = (input) => restoreSpans(input || {}, baseNormalizeLevel(input));

  M.validateLevel = (input) => {
    const base = baseValidateLevel(input);
    const level = M.normalizeLevel(input || {});
    const board = M.boardForLevel(level);
    const errors = [...base.errors];
    const warnings = [...base.warnings];
    const occupied = new Map();

    for (const entity of level.initialBoard || []) {
      const raw = sourceEntityAt(input || {}, entity.column, entity.row);
      const rawWidth = Math.trunc(Number(raw?.widthCells ?? 1));
      const rawHeight = Math.trunc(Number(raw?.heightCells ?? 1));
      if ((rawWidth !== 1 || rawHeight !== 1) && !supportsMultiCell(entity)) {
        errors.push(`C${entity.column + 1} R${entity.row + 1}: only Normal square and Mission Core blocks can be larger than 1×1.`);
      }
      const size = footprint(entity);
      if (size.width < 1 || size.width > MAX_SPAN || size.height < 1 || size.height > MAX_SPAN) {
        errors.push(`C${entity.column + 1} R${entity.row + 1}: block size must be between 1×1 and 4×4.`);
      }
      if (entity.column + size.width > board.columns || entity.row + size.height > board.rows) {
        errors.push(`C${entity.column + 1} R${entity.row + 1}: ${size.width}×${size.height} block extends outside the ${board.columns}×${board.rows} board.`);
      }
      for (const cell of footprintCells(entity)) {
        if (cell.column < 0 || cell.row < 0 || cell.column >= board.columns || cell.row >= board.rows) continue;
        const key = `${cell.column}:${cell.row}`;
        if (occupied.has(key)) {
          errors.push(`C${cell.column + 1} R${cell.row + 1}: block footprints overlap.`);
          break;
        }
        occupied.set(key, entity);
      }
    }

    return { level, errors: [...new Set(errors)], warnings, valid: errors.length === 0 };
  };

  M.toExportJson = (input) => {
    const normalized = M.normalizeLevel(input || {});
    const exported = JSON.parse(baseToExportJson(normalized));
    for (const entity of exported.initialBoard || []) {
      const source = (normalized.initialBoard || []).find((item) => item.column === entity.column && item.row === entity.row);
      if (!source || !supportsMultiCell(source)) continue;
      const size = footprint(source);
      if (size.width > 1) entity.widthCells = size.width; else delete entity.widthCells;
      if (size.height > 1) entity.heightCells = size.height; else delete entity.heightCells;
    }
    return JSON.stringify(exported, null, 2);
  };

  if (baseSimulateDescent) {
    M.simulateDescent = (input, moves) => {
      const level = M.normalizeLevel(input || {});
      const result = baseSimulateDescent(level, moves);
      const board = M.boardForLevel(level);
      let earliest = Number.isInteger(result.dangerAtMove) ? result.dangerAtMove : null;
      for (const entity of level.initialBoard || []) {
        if (entity.kind !== "block") continue;
        const size = footprint(entity);
        const movesUntilDanger = (board.rows - 1) - (entity.row + size.height - 1);
        if (movesUntilDanger >= 0 && movesUntilDanger <= moves) earliest = earliest === null ? movesUntilDanger : Math.min(earliest, movesUntilDanger);
      }
      if (earliest !== null) {
        result.danger = true;
        result.dangerAtMove = earliest;
      }
      return result;
    };
  }

  M.MULTICELL_MAX_SPAN = MAX_SPAN;
  M.blockFootprint = footprint;
  M.blockFootprintCells = footprintCells;
  M.blockCoversCell = covers;
  M.entityCoveringCell = entityCoveringCell;
  M.blockFootprintConflict = footprintConflict;
  M.supportsMultiCellBlock = supportsMultiCell;
  M.__multicellBlocksExtended = true;
})();
