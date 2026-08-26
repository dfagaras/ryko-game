(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M) return;

  const COLORS = Object.freeze({
    amber: "#e7ae43",
    aqua: "#55b8b1",
    coral: "#e96b5f",
    toxic: "#9ac85b",
    violet: "#9477b5",
    ion_blue: "#55bfe3"
  });
  const DEFAULT_COLOR = "amber";
  const COLOR_KEY = "ryko-block-color";
  const baseNormalizeLevel = M.normalizeLevel.bind(M);
  const baseToExportJson = M.toExportJson.bind(M);

  function selectedColor() {
    const value = localStorage.getItem(COLOR_KEY) || DEFAULT_COLOR;
    return COLORS[value] ? value : DEFAULT_COLOR;
  }

  function normalizeColor(value) {
    return COLORS[value] ? value : selectedColor();
  }

  function colorizeEntity(entity) {
    if (!entity || entity.kind !== "block") return entity;
    return { ...entity, color: normalizeColor(entity.color) };
  }

  function copyColors(source, target) {
    const sourceInitial = Array.isArray(source?.initialBoard) ? source.initialBoard : [];
    for (const targetEntity of target.initialBoard || []) {
      if (targetEntity.kind !== "block") continue;
      const original = sourceInitial.find((item) => item?.kind === "block" && Number(item.column) === targetEntity.column && Number(item.row) === targetEntity.row);
      targetEntity.color = normalizeColor(original?.color);
    }
    const sourceRows = Array.isArray(source?.incomingRows) ? source.incomingRows : [];
    (target.incomingRows || []).forEach((row, rowIndex) => {
      for (const targetEntity of row.cells || []) {
        if (targetEntity.kind !== "block") continue;
        const original = sourceRows[rowIndex]?.cells?.find((item) => item?.kind === "block" && Number(item.column) === targetEntity.column);
        targetEntity.color = normalizeColor(original?.color);
      }
    });
    target.topRow = (Array.isArray(source?.topRow) ? source.topRow : []).map((entity) => colorizeEntity(M.normalizeEntity({ ...entity, row: 0 }, 0))).filter(Boolean).map((entity) => {
      delete entity.row;
      return entity;
    });
    return target;
  }

  M.BLOCK_COLORS = COLORS;
  M.DEFAULT_BLOCK_COLOR = DEFAULT_COLOR;
  M.normalizeBlockColor = normalizeColor;
  M.normalizeLevel = (input) => copyColors(input || {}, baseNormalizeLevel(input));
  M.toExportJson = (input) => {
    const exported = JSON.parse(baseToExportJson(input));
    copyColors(input || {}, exported);
    return JSON.stringify(exported, null, 2);
  };
})();
