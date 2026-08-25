class_name RykoLevelDefinition
extends RefCounted

const BoardProfile = preload("res://scripts/level_board_profile.gd")
const SUPPORTED_SCHEMA_VERSION := 1
const SUPPORTED_MODES: Array[String] = ["clear_limited", "descent"]


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

	var scale_result := _resolve_scale(raw)
	if not bool(scale_result["valid"]):
		errors.append(str(scale_result["error"]))
	var scale := int(scale_result["scale"])
	var profile := BoardProfile.from_scale(scale)
	var level: Dictionary = raw.duplicate(true)
	level["schemaVersion"] = SUPPORTED_SCHEMA_VERSION
	level["boardScale"] = scale

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
	for index in range(initial_board.size()):
		_validate_entity(initial_board[index], profile, "Initial cell %d" % (index + 1), errors, false)

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

	if scale >= 3:
		warnings.append("%dx micro-grid: gameplay elements render at %.0f%% of standard size." % [scale, 100.0 / float(scale)])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"level": level,
		"board_profile": profile,
	}


static func _resolve_scale(raw: Dictionary) -> Dictionary:
	if raw.has("boardScale"):
		var explicit := int(raw.get("boardScale", 1))
		if not BoardProfile.is_supported_scale(explicit):
			return {"valid": false, "scale": 1, "error": "boardScale must be 1, 2, 3 or 4."}
		return {"valid": true, "scale": explicit, "error": ""}

	var board_variant: Variant = raw.get("board", {})
	if typeof(board_variant) != TYPE_DICTIONARY:
		return {"valid": true, "scale": 1, "error": ""}
	var board: Dictionary = board_variant
	if board.has("scale"):
		var nested := int(board.get("scale", 1))
		if not BoardProfile.is_supported_scale(nested):
			return {"valid": false, "scale": 1, "error": "board.scale must be 1, 2, 3 or 4."}
		return {"valid": true, "scale": nested, "error": ""}

	var columns := int(board.get("columns", BoardProfile.BASE_COLUMNS))
	var rows := int(board.get("rows", BoardProfile.BASE_ROWS))
	if columns % BoardProfile.BASE_COLUMNS == 0 and rows % BoardProfile.BASE_ROWS == 0:
		var column_scale := int(columns / BoardProfile.BASE_COLUMNS)
		var row_scale := int(rows / BoardProfile.BASE_ROWS)
		if column_scale == row_scale and BoardProfile.is_supported_scale(column_scale):
			return {"valid": true, "scale": column_scale, "error": ""}
	return {"valid": true, "scale": 1, "error": ""}


static func _validate_entity(raw_entity: Variant, profile: Dictionary, label: String, errors: Array[String], incoming: bool) -> void:
	if typeof(raw_entity) != TYPE_DICTIONARY:
		errors.append("%s must be an object." % label)
		return
	var entity: Dictionary = raw_entity
	var column := int(entity.get("column", -1))
	var row := 0 if incoming else int(entity.get("row", -1))
	if column < 0 or column >= int(profile["columns"]):
		errors.append("%s column %d is outside 0..%d." % [label, column, int(profile["columns"]) - 1])
	if row < 0 or row >= int(profile["rows"]):
		errors.append("%s row %d is outside 0..%d." % [label, row, int(profile["rows"]) - 1])

	if str(entity.get("kind", "")) != "block":
		return
	if int(entity.get("hp", 0)) < 1:
		errors.append("%s block HP must be at least 1." % label)
	if str(entity.get("shape", "square")) == "triangle" and str(entity.get("variant", "normal")) != "normal":
		errors.append("%s triangle cannot use a special variant." % label)
	if str(entity.get("variant", "normal")) == "black_hole":
		var sides_variant: Variant = entity.get("absorbingSides", [])
		if typeof(sides_variant) != TYPE_ARRAY or (sides_variant as Array).is_empty():
			errors.append("%s Black Hole needs at least one absorbing side." % label)


static func _failure(message: String) -> Dictionary:
	return {
		"valid": false,
		"errors": [message],
		"warnings": [],
		"level": {},
		"board_profile": {},
	}
