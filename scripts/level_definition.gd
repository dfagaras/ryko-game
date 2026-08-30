class_name RykoLevelDefinition
extends RefCounted

const BoardProfile = preload("res://scripts/level_board_profile.gd")
const SUPPORTED_SCHEMA_VERSION := 1
const SUPPORTED_MODES: Array[String] = ["clear_limited", "descent"]
const VALID_BLACK_HOLE_SIDES: Array[String] = ["left", "right", "top", "bottom"]
const DEFAULT_BALL_SIZE_MULTIPLIER := 1.0
const MIN_BALL_SIZE_MULTIPLIER := 0.65
const MAX_BALL_SIZE_MULTIPLIER := 1.35


static func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("Level file does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Could not open level file: %s" % path)
	return parse_json_text(file.get_as_text())


static func parse_json_text(text: String) -> Dictionary:
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		return _failure("Invalid level JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _failure("Level JSON root must be an object.")
	return normalize_level(json.data)


static func normalize_level(raw: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var schema_version := int(raw.get("schemaVersion", 1))
	if schema_version != SUPPORTED_SCHEMA_VERSION:
		errors.append("Unsupported schemaVersion %d." % schema_version)

	var dimensions_result := _resolve_dimensions(raw)
	if not bool(dimensions_result["valid"]):
		errors.append(str(dimensions_result["error"]))
	var columns := int(dimensions_result["columns"])
	var rows := int(dimensions_result["rows"])
	var profile := BoardProfile.from_dimensions(columns, rows)

	var ball_result := _resolve_ball(raw)
	if not bool(ball_result["valid"]):
		errors.append(str(ball_result["error"]))
	var ball_multiplier := float(ball_result["size_multiplier"])
	profile["standard_ball_radius"] = float(profile["ball_radius"])
	profile["standard_ball_collision_radius"] = float(profile["ball_collision_radius"])
	profile["ball_size_multiplier"] = ball_multiplier
	profile["ball_radius"] = float(profile["ball_radius"]) * ball_multiplier
	profile["ball_collision_radius"] = float(profile["ball_collision_radius"]) * ball_multiplier

	var level: Dictionary = raw.duplicate(true)
	level["schemaVersion"] = SUPPORTED_SCHEMA_VERSION
	level["boardColumns"] = columns
	level["boardRows"] = rows
	level["ball"] = {"sizeMultiplier": ball_multiplier}
	var legacy_scale := int(profile["legacy_scale"])
	if legacy_scale > 0:
		level["boardScale"] = legacy_scale
	else:
		level.erase("boardScale")
	# Authored levels always resolve onto the exact existing RYKO playfield.
	# main.gd / the existing hero gameplay remains untouched.
	level["board"] = _board_json(profile)

	var rules_variant: Variant = level.get("rules", {})
	if typeof(rules_variant) != TYPE_DICTIONARY:
		errors.append("rules must be an object.")
		rules_variant = {}
	var rules: Dictionary = rules_variant
	var mode := str(rules.get("mode", "clear_limited"))
	if mode not in SUPPORTED_MODES:
		errors.append("Unsupported level mode: %s." % mode)
	if int(rules.get("startingBalls", 1)) < 1:
		errors.append("startingBalls must be at least 1.")
	if mode == "clear_limited" and int(rules.get("moveLimit", 0)) < 1:
		errors.append("clear_limited levels need moveLimit >= 1.")

	var initial_variant: Variant = level.get("initialBoard", [])
	if typeof(initial_variant) != TYPE_ARRAY:
		errors.append("initialBoard must be an array.")
		initial_variant = []
	var initial_board: Array = initial_variant
	var initial_block_count := 0
	for index in range(initial_board.size()):
		if _validate_entity(initial_board[index], profile, "Initial cell %d" % (index + 1), errors, false):
			if str((initial_board[index] as Dictionary).get("kind", "")) == "block":
				initial_block_count += 1

	var top_variant: Variant = level.get("topRow", [])
	if typeof(top_variant) != TYPE_ARRAY:
		errors.append("topRow must be an array.")
		top_variant = []
	var top_row: Array = top_variant
	var top_block_count := 0
	for index in range(top_row.size()):
		if _validate_entity(top_row[index], profile, "Top row cell %d" % (index + 1), errors, true):
			if str((top_row[index] as Dictionary).get("kind", "")) == "block":
				top_block_count += 1

	if initial_block_count + top_block_count == 0:
		errors.append("The authored start needs at least one block on the initial board or top row.")

	var incoming_variant: Variant = level.get("incomingRows", [])
	if typeof(incoming_variant) != TYPE_ARRAY:
		errors.append("incomingRows must be an array.")
		incoming_variant = []
	var incoming_rows: Array = incoming_variant
	for row_index in range(incoming_rows.size()):
		var row_variant: Variant = incoming_rows[row_index]
		if typeof(row_variant) != TYPE_DICTIONARY:
			errors.append("Incoming row %d must be an object." % (row_index + 1))
			continue
		var row_def: Dictionary = row_variant
		var cells_variant: Variant = row_def.get("cells", [])
		if typeof(cells_variant) != TYPE_ARRAY:
			errors.append("Incoming row %d cells must be an array." % (row_index + 1))
			continue
		var cells: Array = cells_variant
		for cell_index in range(cells.size()):
			_validate_entity(cells[cell_index], profile, "Incoming +%d cell %d" % [row_index + 1, cell_index + 1], errors, true)

	if mode == "descent" and incoming_rows.is_empty():
		warnings.append("No authored incoming rows: only the authored start will descend.")
	if float(profile["visual_scale"]) <= (1.0 / 3.0):
		warnings.append("%dx%d micro-grid: gameplay elements render at %.0f%% of standard size." % [columns, rows, 100.0 * float(profile["visual_scale"])])
	var standard_ratio := float(BoardProfile.BASE_COLUMNS) / float(BoardProfile.BASE_ROWS)
	var board_ratio := float(columns) / float(rows)
	if absf((board_ratio / standard_ratio) - 1.0) > 0.2:
		warnings.append("%dx%d is far from the standard 7x9 aspect ratio; horizontal and vertical gaps will differ noticeably." % [columns, rows])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"level": level,
		"board_profile": profile,
	}


static func _resolve_ball(raw: Dictionary) -> Dictionary:
	if not raw.has("ball"):
		return {"valid": true, "size_multiplier": DEFAULT_BALL_SIZE_MULTIPLIER, "error": ""}
	var ball_variant: Variant = raw.get("ball", {})
	if typeof(ball_variant) != TYPE_DICTIONARY:
		return {"valid": false, "size_multiplier": DEFAULT_BALL_SIZE_MULTIPLIER, "error": "ball must be an object."}
	var ball: Dictionary = ball_variant
	var multiplier := float(ball.get("sizeMultiplier", DEFAULT_BALL_SIZE_MULTIPLIER))
	if multiplier < MIN_BALL_SIZE_MULTIPLIER or multiplier > MAX_BALL_SIZE_MULTIPLIER:
		return {
			"valid": false,
			"size_multiplier": DEFAULT_BALL_SIZE_MULTIPLIER,
			"error": "ball.sizeMultiplier must be between %.2fx and %.2fx." % [MIN_BALL_SIZE_MULTIPLIER, MAX_BALL_SIZE_MULTIPLIER]
		}
	return {"valid": true, "size_multiplier": snappedf(multiplier, 0.01), "error": ""}


static func _resolve_dimensions(raw: Dictionary) -> Dictionary:
	var board_variant: Variant = raw.get("board", {})
	if typeof(board_variant) == TYPE_DICTIONARY:
		var board: Dictionary = board_variant
		if board.has("columns") or board.has("rows"):
			if not board.has("columns") or not board.has("rows"):
				return _invalid_dimensions("board.columns and board.rows must be provided together.")
			return _validated_dimensions(int(board.get("columns", BoardProfile.BASE_COLUMNS)), int(board.get("rows", BoardProfile.BASE_ROWS)))

	if raw.has("boardColumns") or raw.has("boardRows"):
		if not raw.has("boardColumns") or not raw.has("boardRows"):
			return _invalid_dimensions("boardColumns and boardRows must be provided together.")
		return _validated_dimensions(int(raw.get("boardColumns", BoardProfile.BASE_COLUMNS)), int(raw.get("boardRows", BoardProfile.BASE_ROWS)))

	if raw.has("boardScale"):
		var explicit := int(raw.get("boardScale", 1))
		if not BoardProfile.is_supported_scale(explicit):
			return _invalid_dimensions("boardScale must be 1, 2, 3 or 4 for legacy level files.")
		return {"valid": true, "columns": BoardProfile.BASE_COLUMNS * explicit, "rows": BoardProfile.BASE_ROWS * explicit, "error": ""}

	if typeof(board_variant) == TYPE_DICTIONARY:
		var board: Dictionary = board_variant
		if board.has("scale"):
			var nested := int(board.get("scale", 1))
			if not BoardProfile.is_supported_scale(nested):
				return _invalid_dimensions("board.scale must be 1, 2, 3 or 4 for legacy level files.")
			return {"valid": true, "columns": BoardProfile.BASE_COLUMNS * nested, "rows": BoardProfile.BASE_ROWS * nested, "error": ""}

	return {"valid": true, "columns": BoardProfile.BASE_COLUMNS, "rows": BoardProfile.BASE_ROWS, "error": ""}


static func _validated_dimensions(columns: int, rows: int) -> Dictionary:
	if not BoardProfile.is_supported_dimensions(columns, rows):
		return _invalid_dimensions("Board size must be %d-%d columns and %d-%d rows." % [BoardProfile.MIN_COLUMNS, BoardProfile.MAX_COLUMNS, BoardProfile.MIN_ROWS, BoardProfile.MAX_ROWS])
	return {"valid": true, "columns": columns, "rows": rows, "error": ""}


static func _invalid_dimensions(message: String) -> Dictionary:
	return {"valid": false, "columns": BoardProfile.BASE_COLUMNS, "rows": BoardProfile.BASE_ROWS, "error": message}


static func _validate_entity(raw_entity: Variant, profile: Dictionary, label: String, errors: Array[String], incoming: bool) -> bool:
	if typeof(raw_entity) != TYPE_DICTIONARY:
		errors.append("%s must be an object." % label)
		return false
	var entity: Dictionary = raw_entity
	var column := int(entity.get("column", -1))
	var row := 0 if incoming else int(entity.get("row", -1))
	if column < 0 or column >= int(profile["columns"]):
		errors.append("%s column %d is outside 0..%d." % [label, column, int(profile["columns"]) - 1])
	if row < 0 or row >= int(profile["rows"]):
		errors.append("%s row %d is outside 0..%d." % [label, row, int(profile["rows"]) - 1])

	var kind := str(entity.get("kind", ""))
	if kind == "block":
		if int(entity.get("hp", 0)) < 1:
			errors.append("%s block HP must be at least 1." % label)
		if str(entity.get("shape", "square")) == "triangle" and str(entity.get("variant", "normal")) != "normal":
			errors.append("%s triangle cannot use a special variant." % label)
		if str(entity.get("variant", "normal")) == "black_hole":
			var sides_variant: Variant = entity.get("absorbingSides", [])
			if typeof(sides_variant) != TYPE_ARRAY or (sides_variant as Array).is_empty():
				errors.append("%s Black Hole needs at least one absorbing side." % label)
			else:
				for side in sides_variant as Array:
					if str(side) not in VALID_BLACK_HOLE_SIDES:
						errors.append("%s Black Hole has invalid absorbing side: %s." % [label, str(side)])
	elif kind == "pickup":
		if str(entity.get("type", "")) != "plus_ball":
			errors.append("%s has unsupported pickup type." % label)
	elif kind == "power":
		if str(entity.get("type", "")) not in ["ion", "ghost", "supernova"]:
			errors.append("%s has unsupported power type." % label)
	else:
		errors.append("%s has unsupported kind: %s." % [label, kind])

	return true


static func _board_json(profile: Dictionary) -> Dictionary:
	var board := {
		"logicalWidth": 720,
		"logicalHeight": 1280,
		"boardLeft": float(profile["board_left"]),
		"boardRight": float(profile["board_right"]),
		"boardTop": float(profile["board_top"]),
		"gridX": float(profile["grid_x"]),
		"gridY": float(profile["grid_y"]),
		"launchLineY": float(profile["launch_line_y"]),
		"columns": int(profile["columns"]),
		"rows": int(profile["rows"]),
		"cell": float(profile["cell"]),
		"gap": float(profile["gap"]),
		"columnGap": float(profile["column_gap"]),
		"rowGap": float(profile["row_gap"]),
		"columnStep": float(profile["column_step"]),
		"rowStep": float(profile["row_step"]),
		"gridWidth": float(profile["grid_width"]),
		"gridHeight": float(profile["grid_height"]),
		"dangerRow": int(profile["danger_row"]),
		"visualScale": float(profile["visual_scale"]),
		"standardBallRadius": float(profile["standard_ball_radius"]),
		"standardBallCollisionRadius": float(profile["standard_ball_collision_radius"]),
		"ballSizeMultiplier": float(profile["ball_size_multiplier"]),
		"ballRadius": float(profile["ball_radius"]),
		"ballCollisionRadius": float(profile["ball_collision_radius"]),
		"ballSpeed": float(profile["ball_speed"]),
		"pickupRadius": float(profile["pickup_radius"]),
		"ionRadius": float(profile["ion_radius"]),
		"ghostRadius": float(profile["ghost_radius"]),
		"supernovaCoreRadius": float(profile["supernova_core_radius"]),
		"supernovaExplosionRadius": float(profile["supernova_explosion_radius"]),
	}
	if int(profile["legacy_scale"]) > 0:
		board["scale"] = int(profile["legacy_scale"])
	return board


static func _failure(message: String) -> Dictionary:
	return {
		"valid": false,
		"errors": [message],
		"warnings": [],
		"level": {},
		"board_profile": {},
	}
