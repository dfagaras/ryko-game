class_name RykoLevelBoardProfile
extends RefCounted

# Authored levels can subdivide the exact same RYKO playfield without changing
# the existing endless/hero gameplay constants in main.gd. 7x9 is the current
# standard board, but authored levels may choose any supported column/row count.
const BASE_COLUMNS := 7
const BASE_ROWS := 9
const BASE_CELL := 88.0
const BASE_GAP := 4.0
const BASE_ROW_STEP := 92.0
const BASE_BALL_RADIUS := 9.0
const BASE_BALL_COLLISION_RADIUS := 10.0
const BASE_BALL_SPEED := 760.0
const BASE_PICKUP_RADIUS := 19.0
const BASE_ION_RADIUS := 20.0
const BASE_GHOST_RADIUS := 20.0
const BASE_SUPERNOVA_CORE_RADIUS := 22.0
const BASE_BOARD_LEFT := 28.0
const BASE_BOARD_RIGHT := 692.0
const BASE_BOARD_TOP := 176.0
const BASE_GRID_X := 40.0
const BASE_GRID_Y := 268.0
const BASE_LAUNCH_LINE_Y := 1092.0
const BASE_GRID_WIDTH := BASE_COLUMNS * BASE_CELL + (BASE_COLUMNS - 1) * BASE_GAP
const BASE_GRID_HEIGHT := BASE_ROWS * BASE_CELL + (BASE_ROWS - 1) * BASE_GAP
const MIN_SCALE := 1
const MAX_SCALE := 4
const MIN_COLUMNS := 6
const MAX_COLUMNS := 28
const MIN_ROWS := 8
const MAX_ROWS := 36


static func is_supported_scale(value: Variant) -> bool:
	var scale := int(value)
	return scale >= MIN_SCALE and scale <= MAX_SCALE


static func normalize_scale(value: Variant) -> int:
	return clampi(int(value), MIN_SCALE, MAX_SCALE)


static func is_supported_dimensions(columns_value: Variant, rows_value: Variant) -> bool:
	var columns := int(columns_value)
	var rows := int(rows_value)
	return columns >= MIN_COLUMNS and columns <= MAX_COLUMNS \
		and rows >= MIN_ROWS and rows <= MAX_ROWS


static func normalize_columns(value: Variant) -> int:
	return clampi(int(value), MIN_COLUMNS, MAX_COLUMNS)


static func normalize_rows(value: Variant) -> int:
	return clampi(int(value), MIN_ROWS, MAX_ROWS)


static func legacy_scale_for_dimensions(columns: int, rows: int) -> int:
	if columns % BASE_COLUMNS != 0 or rows % BASE_ROWS != 0:
		return 0
	var column_scale := int(columns / BASE_COLUMNS)
	var row_scale := int(rows / BASE_ROWS)
	if column_scale == row_scale and is_supported_scale(column_scale):
		return column_scale
	return 0


static func from_dimensions(columns_value: Variant, rows_value: Variant) -> Dictionary:
	var columns := normalize_columns(columns_value)
	var rows := normalize_rows(rows_value)
	# Keep cells square. Whichever axis is denser drives the zoom-out amount;
	# the remaining space is distributed as gaps so the physical playfield stays
	# exactly the same size as the current 7x9 board.
	var visual_scale := minf(float(BASE_COLUMNS) / float(columns), float(BASE_ROWS) / float(rows))
	var cell := BASE_CELL * visual_scale
	var column_gap := (BASE_GRID_WIDTH - float(columns) * cell) / float(columns - 1)
	var row_gap := (BASE_GRID_HEIGHT - float(rows) * cell) / float(rows - 1)
	var column_step := cell + column_gap
	var row_step := cell + row_gap
	var legacy_scale := legacy_scale_for_dimensions(columns, rows)

	return {
		"scale": legacy_scale,
		"legacy_scale": legacy_scale,
		"columns": columns,
		"rows": rows,
		"cell": cell,
		"gap": column_gap,
		"column_gap": column_gap,
		"row_gap": row_gap,
		"column_step": column_step,
		"row_step": row_step,
		"grid_width": BASE_GRID_WIDTH,
		"grid_height": BASE_GRID_HEIGHT,
		"danger_row": rows - 1,
		"visual_scale": visual_scale,
		"board_left": BASE_BOARD_LEFT,
		"board_right": BASE_BOARD_RIGHT,
		"board_top": BASE_BOARD_TOP,
		"grid_x": BASE_GRID_X,
		"grid_y": BASE_GRID_Y,
		"launch_line_y": BASE_LAUNCH_LINE_Y,
		"ball_radius": BASE_BALL_RADIUS * visual_scale,
		"ball_collision_radius": BASE_BALL_COLLISION_RADIUS * visual_scale,
		"ball_speed": BASE_BALL_SPEED * visual_scale,
		"pickup_radius": BASE_PICKUP_RADIUS * visual_scale,
		"ion_radius": BASE_ION_RADIUS * visual_scale,
		"ghost_radius": BASE_GHOST_RADIUS * visual_scale,
		"supernova_core_radius": BASE_SUPERNOVA_CORE_RADIUS * visual_scale,
		"supernova_explosion_radius": cell * 0.75
	}


static func from_scale(value: Variant) -> Dictionary:
	var scale := normalize_scale(value)
	return from_dimensions(BASE_COLUMNS * scale, BASE_ROWS * scale)


static func infer_scale(level_data: Dictionary) -> int:
	var dimensions := resolve_dimensions(level_data)
	var legacy_scale := legacy_scale_for_dimensions(int(dimensions["columns"]), int(dimensions["rows"]))
	return legacy_scale if legacy_scale > 0 else 1


static func resolve_dimensions(level_data: Dictionary) -> Dictionary:
	var board_variant: Variant = level_data.get("board", {})
	if typeof(board_variant) == TYPE_DICTIONARY:
		var board: Dictionary = board_variant
		if board.has("columns") or board.has("rows"):
			return {
				"columns": normalize_columns(board.get("columns", BASE_COLUMNS)),
				"rows": normalize_rows(board.get("rows", BASE_ROWS)),
			}

	if level_data.has("boardColumns") or level_data.has("boardRows"):
		return {
			"columns": normalize_columns(level_data.get("boardColumns", BASE_COLUMNS)),
			"rows": normalize_rows(level_data.get("boardRows", BASE_ROWS)),
		}

	if level_data.has("boardScale"):
		var scale := normalize_scale(level_data.get("boardScale", 1))
		return {"columns": BASE_COLUMNS * scale, "rows": BASE_ROWS * scale}

	if typeof(board_variant) == TYPE_DICTIONARY:
		var board: Dictionary = board_variant
		if board.has("scale"):
			var nested_scale := normalize_scale(board.get("scale", 1))
			return {"columns": BASE_COLUMNS * nested_scale, "rows": BASE_ROWS * nested_scale}

	return {"columns": BASE_COLUMNS, "rows": BASE_ROWS}


static func from_level_data(level_data: Dictionary) -> Dictionary:
	var dimensions := resolve_dimensions(level_data)
	return from_dimensions(dimensions["columns"], dimensions["rows"])


static func matches_level_board(level_data: Dictionary) -> bool:
	var profile := from_level_data(level_data)
	var board_variant: Variant = level_data.get("board", {})
	if typeof(board_variant) != TYPE_DICTIONARY:
		return true
	var board: Dictionary = board_variant
	if board.is_empty():
		return true
	return int(board.get("columns", profile["columns"])) == int(profile["columns"]) \
		and int(board.get("rows", profile["rows"])) == int(profile["rows"])


static func cell_rect(profile: Dictionary, column: int, row: int) -> Rect2:
	return Rect2(
		float(profile["grid_x"]) + float(column) * float(profile["column_step"]),
		float(profile["grid_y"]) + float(row) * float(profile["row_step"]),
		float(profile["cell"]),
		float(profile["cell"])
	)


static func cell_center(profile: Dictionary, column: int, row: int) -> Vector2:
	return cell_rect(profile, column, row).get_center()


static func grid_rect(profile: Dictionary) -> Rect2:
	return Rect2(
		float(profile["grid_x"]),
		float(profile["grid_y"]),
		float(profile["grid_width"]),
		float(profile["grid_height"])
	)
