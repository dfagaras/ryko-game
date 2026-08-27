(() => {
  "use strict";

  const M = window.RykoLevelModel;
  if (!M) return;

  const MIN = 0.20;
  const MAX = 3.00;
  const RECOMMENDED_MIN = 0.65;
  const RECOMMENDED_MAX = 1.35;
  const originalNormalizeLevel = M.normalizeLevel.bind(M);
  const originalValidateLevel = M.validateLevel.bind(M);
  const originalToExportJson = M.toExportJson.bind(M);

  const normalizeMultiplier = (value) => {
    const parsed = Number(value);
    const multiplier = Number.isFinite(parsed) ? parsed : 1;
    return Math.round(Math.min(MAX, Math.max(MIN, multiplier)) * 100) / 100;
  };

  const rawMultiplier = (input) => normalizeMultiplier(input?.ball?.sizeMultiplier ?? 1);

  M.MIN_BALL_SIZE_MULTIPLIER = MIN;
  M.MAX_BALL_SIZE_MULTIPLIER = MAX;
  M.RECOMMENDED_BALL_SIZE_MIN = RECOMMENDED_MIN;
  M.RECOMMENDED_BALL_SIZE_MAX = RECOMMENDED_MAX;
  M.isSupportedBallSizeMultiplier = (value) => {
    const number = Number(value);
    return Number.isFinite(number) && number >= MIN && number <= MAX;
  };
  M.normalizeBallSizeMultiplier = normalizeMultiplier;

  M.normalizeLevel = (input) => {
    const source = input && typeof input === "object" ? input : {};
    const multiplier = rawMultiplier(source);
    const safeSource = { ...source, ball: { sizeMultiplier: 1 } };
    const level = originalNormalizeLevel(safeSource);
    level.ball = { sizeMultiplier: multiplier };
    return level;
  };

  M.ballMetricsForLevel = (level) => {
    const board = M.boardForLevel(level || {});
    const sizeMultiplier = rawMultiplier(level || {});
    return {
      sizeMultiplier,
      standardRadius: board.ballRadius,
      selectedRadius: board.ballRadius * sizeMultiplier,
      standardCollisionRadius: board.ballCollisionRadius,
      selectedCollisionRadius: board.ballCollisionRadius * sizeMultiplier
    };
  };

  M.validateLevel = (input) => {
    const source = input && typeof input === "object" ? input : {};
    const multiplier = Number(source?.ball?.sizeMultiplier ?? 1);
    const base = originalValidateLevel({ ...source, ball: { sizeMultiplier: 1 } });
    base.level = M.normalizeLevel(source);
    base.errors = base.errors.filter((message) => !/ball size multiplier/i.test(message));
    if (!Number.isFinite(multiplier) || multiplier < MIN || multiplier > MAX) {
      base.errors.push(`Ball size multiplier must be between ${MIN.toFixed(2)} and ${MAX.toFixed(2)}.`);
    }
    const normalized = normalizeMultiplier(multiplier);
    if (normalized < RECOMMENDED_MIN) {
      base.warnings.push(`Ball ${normalized.toFixed(2)}× is experimental/tiny; verify visibility and narrow collision paths on a phone.`);
    } else if (normalized > RECOMMENDED_MAX) {
      base.warnings.push(`Ball ${normalized.toFixed(2)}× is experimental/large; verify corridor fit and collision feel on a phone.`);
    }
    base.valid = base.errors.length === 0;
    return base;
  };

  M.toExportJson = (input) => {
    const source = input && typeof input === "object" ? input : {};
    const multiplier = rawMultiplier(source);
    const safeJson = JSON.parse(originalToExportJson({ ...source, ball: { sizeMultiplier: 1 } }));
    safeJson.ball = { sizeMultiplier: multiplier };
    return JSON.stringify(safeJson, null, 2);
  };
})();
