class_name RykoBoardProfile
extends RefCounted

const BASE_LOGICAL_WIDTH: float = 720.0
const BASE_LOGICAL_HEIGHT: float = 1280.0
const BASE_BOARD_LEFT: float = 28.0
const BASE_BOARD_RIGHT: float = 692.0
const BASE_BOARD_TOP: float = 176.0
const BASE_GRID_X: float = 40.0
const BASE_GRID_Y: float = 268.0
const BASE_LAUNCH_LINE_Y: float = 1092.0
const BASE_COLUMNS: int = 7
const BASE_ROWS: int = 9
const BASE_CELL: float = 88.0
const BASE_GAP: float = 4.0
const BASE_ROW_STEP: float = 92.0

const BASE_BALL_RADIUS: float = 9.0
const BASE_BALL_COLLISION_RADIUS: float = 10.0
const BASE_BALL_SPEED: float = 760.0
const BASE_PICKUP_RADIUS: float = 19.0
const BASE_BLOCK_OUTLINE_WIDTH: float = 6.0
const BASE_ION_BEAM_RADIUS: float = 20.0
const BASE_GHOST_CORE_RADIUS: float = 20.0
const BASE_SUPERNOVA_CORE_RADIUS: float = 22.0

const SUPPORTED_SCALES: Array[int] = [1, 2, 3, 4]
const BASE_GRID_WIDTH: float = BASE_COLUMNS * BASE_CELL + (BASE_COLUMNS - 1) * BASE_GAP


static func is_supported_scale(value: Variant) -> bool:
	var scale := int(value)
	return scale in SUPPORTED_SCALES


static func normalize_scale(value: Variant) -> int:
	var scale := int(value)
	if scale in SUPPORTED_SCALES:
		return scale
	return 1


static func for_scale(value: Variant) -> Dictionary:
	var scale := normalize_scale(value)
	var columns := BASE_COLUMNS * scale
	var rows := BASE_ROWS * scale
	var cell := BASE_CELL / float(scale)
	# Keep the exact current playable width. Extra separators consume the old
	# gap space instead of making the physical board wider.
	var gap := (BASE_GRID_WIDTH - float(columns) * cell) / float(columns - 1)
	var row_step := cell + gap
	var grid_height := float(rows) * cell + float(rows - 1) * gap
	var grid_y := BASE_LAUNCH_LINE_Y - grid_height

	return {
		"logicalWidth": BASE_LOGICAL_WIDTH,
		"logicalHeight": BASE_LOGICAL_HEIGHT,
		"boardLeft": BASE_BOARD_LEFT,
		"boardRight": BASE_BOARD_RIGHT,
		"boardTop": BASE_BOARD_TOP,
		"gridX": BASE_GRID_X,
		"gridY": grid_y,
		"launchLineY": BASE_LAUNCH_LINE_Y,
		"columns": columns,
		"rows": rows,
		"cell": cell,
		"gap": gap,
		"rowStep": row_step,
	}


static func gameplay_for_scale(value: Variant) -> Dictionary:
	var scale := normalize_scale(value)
	var divisor := float(scale)
	var board := for_scale(scale)
	return {
		"visualScale": 1.0 / divisor,
		"ballRadius": BASE_BALL_RADIUS / divisor,
		"ballCollisionRadius": BASE_BALL_COLLISION_RADIUS / divisor,
		"ballSpeed": BASE_BALL_SPEED / divisor,
		"pickupRadius": BASE_PICKUP_RADIUS / divisor,
		"blockOutlineWidth": BASE_BLOCK_OUTLINE_WIDTH / divisor,
		"ionBeamRadius": BASE_ION_BEAM_RADIUS / divisor,
		"ghostCoreRadius": BASE_GHOST_CORE_RADIUS / divisor,
		"supernovaCoreRadius": BASE_SUPERNOVA_CORE_RADIUS / divisor,
		"supernovaExplosionRadius": float(board["cell"]) * 0.75,
	}
