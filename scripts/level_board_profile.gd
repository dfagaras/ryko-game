class_name RykoLevelBoardProfile
extends RefCounted

# Authored levels can subdivide the exact same RYKO playfield without changing
# the existing endless-mode constants in main.gd. Scale 1 is the current game.
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
const MIN_SCALE := 1
const MAX_SCALE := 4


static func normalize_scale(value: Variant) -> int:
	return clampi(int(value), MIN_SCALE, MAX_SCALE)


static func from_scale(value: Variant) -> Dictionary:
	var scale := normalize_scale(value)
	var visual_scale := 1.0 / float(scale)
	var cell := BASE_CELL * visual_scale
	var gap := BASE_GAP * visual_scale
	return {
		"scale": scale,
		"columns": BASE_COLUMNS * scale,
		"rows": BASE_ROWS * scale,
		"cell": cell,
		"gap": gap,
		"row_step": BASE_ROW_STEP * visual_scale,
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


static func infer_scale(level_data: Dictionary) -> int:
	if level_data.has("boardScale"):
		return normalize_scale(level_data.get("boardScale", 1))
	var board: Dictionary = level_data.get("board", {})
	if board.has("scale"):
		return normalize_scale(board.get("scale", 1))
	var columns := int(board.get("columns", BASE_COLUMNS))
	var rows := int(board.get("rows", BASE_ROWS))
	if columns % BASE_COLUMNS == 0 and rows % BASE_ROWS == 0:
		var column_scale := columns / BASE_COLUMNS
		var row_scale := rows / BASE_ROWS
		if column_scale == row_scale:
			return normalize_scale(column_scale)
	return 1


static func from_level_data(level_data: Dictionary) -> Dictionary:
	return from_scale(infer_scale(level_data))


static func matches_level_board(level_data: Dictionary) -> bool:
	var profile := from_level_data(level_data)
	var board: Dictionary = level_data.get("board", {})
	if board.is_empty():
		return true
	return int(board.get("columns", profile.columns)) == int(profile.columns) \
		and int(board.get("rows", profile.rows)) == int(profile.rows)
