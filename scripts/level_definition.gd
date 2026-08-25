class_name RykoLevelDefinition
extends RefCounted

const BoardProfile = preload("res://scripts/board_profile.gd")
const CURRENT_SCHEMA_VERSION: int = 2
const SUPPORTED_SCHEMA_VERSIONS: Array[int] = [1, 2]
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
	var parse_error := json.parse(text)
	if parse_error != OK:
		return _failure("Invalid level JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _failure("Level JSON root must be an object.")
	return normalize_level(json.data)


static func normalize_level(raw: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var schema_version := int(raw.get("schemaVersion", 1))
	if schema_version not in SUPPORTED_SCHEMA_VERSIONS:
		errors.append("Unsupported schemaVersion %d." % schema_version)

	var scale_result := _infer_board_scale(raw)
	if not bool(scale_result["valid"]):
		errors.append(str(scale_result["error"]))
	var board_scale := int(scale_result["scale"])
	var board := BoardProfile.for_scale(board_scale)
	var normalized: Dictionary = raw.duplicate(true)
	normalized["schemaVersion"] = CURRENT_SCHEMA_VERSION
	normalized["boardScale"] = board_scale
	normalized["board"] = board

	var rules_variant: Variant = normalized.get("rules", {})
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

	var initial_variant: Variant = normalized.get("initialBoard", [])
	if typeof(initial_variant) != TYPE_ARRAY:
		errors.append("initialBoard must be an array.")
		initial_variant = []
	var initial_board: Array = initial_variant
	for index in range(initial_board.size()):
		_validate_entity(initial_board[index], board, "Initial cell %d" % (index + 1), errors, false)

	var incoming_variant: Variant = normalized.get("incomingRows", [])
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
			_validate_entity(cells[cell_index], board, "Incoming +%d cell %d" % [row_index + 1, cell_index + 1], errors, true)

	if board_scale >= 3:
		warnings.append("%dx micro-grid: gameplay elements intentionally render at %.0f%% of standard size." % [board_scale, 100.0 / float(board_scale)])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"level": normalized,
		"boardProfile": board,
		"gameplayProfile": BoardProfile.gameplay_for_scale(board_scale),
	}


static func _infer_board_scale(raw: Dictionary) -> Dictionary:
	if raw.has("boardScale"):
		var explicit_scale := int(raw["boardScale"])
		if BoardProfile.is_supported_scale(explicit_scale):
			return {"valid": true, "scale": explicit_scale, "error": ""}
		return {"valid": false, "scale": 1, "error": "boardScale must be one of 1, 2, 3 or 4."}

	var board_variant: Variant = raw.get("board", {})
	if typeof(board_variant) == TYPE_DICTIONARY:
		var board: Dictionary = board_variant
		if board.has("scale"):
			var nested_scale := int(board["scale"])
			if BoardProfile.is_supported_scale(nested_scale):
				return {"valid": true, "scale": nested_scale, "error": ""}
			return {"valid": false, "scale": 1, "error": "board.scale must be one of 1, 2, 3 or 4."}
		var columns := int(board.get("columns", 7))
		var rows := int(board.get("rows", 9))
		if columns % 7 == 0 and rows % 9 == 0:
			var column_scale := columns / 7
			var row_scale := rows / 9
			if column_scale == row_scale and BoardProfile.is_supported_scale(column_scale):
				return {"valid": true, "scale": column_scale, "error": ""}

	# Schema v1 had no scale; it is the existing 7x9 board.
	return {"valid": true, "scale": 1, "error": ""}


static func _validate_entity(raw_entity: Variant, board: Dictionary, label: String, errors: Array[String], incoming: bool) -> void:
	if typeof(raw_entity) != TYPE_DICTIONARY:
		errors.append("%s must be an object." % label)
		return
	var entity: Dictionary = raw_entity
	var column := int(entity.get("column", -1))
	var row := 0 if incoming else int(entity.get("row", -1))
	if column < 0 or column >= int(board["columns"]):
		errors.append("%s column %d is outside 0..%d." % [label, column, int(board["columns"]) - 1])
	if row < 0 or row >= int(board["rows"]):
		errors.append("%s row %d is outside 0..%d." % [label, row, int(board["rows"]) - 1])

	if str(entity.get("kind", "")) == "block":
		if int(entity.get("hp", 0)) < 1:
			errors.append("%s block HP must be at least 1." % label)
		if str(entity.get("shape", "square")) == "triangle" and str(entity.get("variant", "normal")) != "normal":
			errors.append("%s triangle cannot use a special block variant." % label)
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
		"boardProfile": {},
		"gameplayProfile": {},
	}
