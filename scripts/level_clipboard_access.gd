extends "res://scripts/level_launcher_access.gd"

# Development flow: the web editor copies the exact exported Ryko JSON to the
# clipboard, then the game stores it in user://levels. This avoids Android file
# picker inconsistencies and lets authored levels be tested without rebuilding.
#
# Important: the editor/runtime support two extensions that the core parser keeps
# intentionally conservative for backwards compatibility:
# - ball.sizeMultiplier 0.20x..3.00x (core parser: 0.65x..1.35x)
# - topRow, stored separately above normal row 1
# Clipboard validation therefore adapts a temporary copy exactly like the runtime
# loader does, while saving the original editor JSON unchanged.

const CLIPBOARD_BALL_MIN := 0.20
const CLIPBOARD_BALL_MAX := 3.00
const CORE_BALL_MIN := 0.65
const CORE_BALL_MAX := 1.35
const CLIPBOARD_DIAGNOSTIC_EDGE := 32


func _draw_levels_overlay() -> void:
	super._draw_levels_overlay()
	# Reuse the established import slot so the overlay layout stays unchanged.
	_draw_action_button(LEVELS_IMPORT_RECT, "PASTE LEVEL", CORAL)


func _input(event: InputEvent) -> void:
	var game := get_parent()
	if game != null and bool(game.get("menu_open")) and int(game.get("menu_page")) == 4 and overlay_open:
		var pressed := false
		var screen_position := Vector2.ZERO
		if event is InputEventScreenTouch and event.pressed:
			pressed = true
			screen_position = event.position
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed = true
			screen_position = event.position
		if pressed:
			var pointer := screen_position - Vector2(float(game.get("layout_content_x")), float(game.get("layout_menu_y_offset")))
			if LEVELS_IMPORT_RECT.has_point(pointer):
				_paste_level_from_clipboard()
				get_viewport().set_input_as_handled()
				return
	super._input(event)


func _paste_level_from_clipboard() -> void:
	var raw_text := DisplayServer.clipboard_get().strip_edges()
	if raw_text.is_empty():
		import_status = "CLIPBOARD EMPTY"
		queue_redraw()
		return

	var json := JSON.new()
	var json_error := json.parse(raw_text)
	if json_error != OK:
		import_status = "NOT JSON // LINE %d" % json.get_error_line()
		_log_clipboard_parse_diagnostic(raw_text, json)
		queue_redraw()
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		import_status = "JSON ROOT MUST BE OBJECT"
		queue_redraw()
		return

	var raw: Dictionary = json.data
	var validation := _validate_editor_level(raw)
	if not bool(validation.get("valid", false)):
		var errors: Array = validation.get("errors", [])
		var first_error := String(errors[0]) if not errors.is_empty() else "Unknown validation error"
		import_status = _short_status(first_error)
		push_error("RYKO clipboard import rejected: %s" % str(errors))
		queue_redraw()
		return

	var level_id := _sanitize_level_id(String(raw.get("levelId", "")))
	if level_id.is_empty():
		import_status = "MISSING LEVEL ID"
		queue_redraw()
		return

	_ensure_user_levels_dir()
	var destination := USER_LEVELS_DIR.path_join("%s.json" % level_id)
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		import_status = "CANNOT SAVE LEVEL"
		push_error("RYKO clipboard import could not write %s" % destination)
		queue_redraw()
		return
	output.store_string(raw_text)
	output.close()

	_refresh_catalog()
	for index in range(level_files.size()):
		if level_files[index] == destination:
			level_page = int(index / LEVELS_PER_PAGE)
			break
	import_status = "PASTED %s" % level_id.to_upper()
	print("RYKO clipboard level saved: %s" % destination)
	queue_redraw()


func _log_clipboard_parse_diagnostic(raw_text: String, json: JSON) -> void:
	var text_length := raw_text.length()
	var edge_length := mini(CLIPBOARD_DIAGNOSTIC_EDGE, text_length)
	var head := raw_text.substr(0, edge_length).c_escape()
	var tail := raw_text.substr(maxi(0, text_length - edge_length), edge_length).c_escape()
	var first_code := raw_text.unicode_at(0) if text_length > 0 else -1
	var last_code := raw_text.unicode_at(text_length - 1) if text_length > 0 else -1
	push_error(
		"RYKO clipboard JSON parse failed at line %d: %s | length=%d first_code=%d last_code=%d head='%s' tail='%s'" % [
			json.get_error_line(),
			json.get_error_message(),
			text_length,
			first_code,
			last_code,
			head,
			tail,
		]
	)


func _validate_editor_level(raw: Dictionary) -> Dictionary:
	var parser_source := raw.duplicate(true)

	# Match the existing authored runtime loader: validate a safe multiplier in
	# the core parser, then retain the editor's wider supported range in the file.
	var requested_multiplier := 1.0
	var ball_variant: Variant = raw.get("ball", {})
	if typeof(ball_variant) == TYPE_DICTIONARY:
		requested_multiplier = float((ball_variant as Dictionary).get("sizeMultiplier", 1.0))
	if requested_multiplier < CLIPBOARD_BALL_MIN or requested_multiplier > CLIPBOARD_BALL_MAX:
		return {
			"valid": false,
			"errors": ["BALL SIZE MUST BE %.2f-%.2fX" % [CLIPBOARD_BALL_MIN, CLIPBOARD_BALL_MAX]]
		}
	parser_source["ball"] = {"sizeMultiplier": clampf(requested_multiplier, CORE_BALL_MIN, CORE_BALL_MAX)}

	# The core contract predates topRow and requires at least one block in
	# initialBoard. For validation only, map top-row entities onto row 0. This
	# validates their normal entity fields and lets top-row-only boards pass.
	var parser_initial: Array = []
	var initial_variant: Variant = raw.get("initialBoard", [])
	if typeof(initial_variant) == TYPE_ARRAY:
		parser_initial = (initial_variant as Array).duplicate(true)
	var top_variant: Variant = raw.get("topRow", [])
	if typeof(top_variant) == TYPE_ARRAY:
		for entity_variant in top_variant as Array:
			if typeof(entity_variant) != TYPE_DICTIONARY:
				parser_initial.append(entity_variant)
				continue
			var entity := (entity_variant as Dictionary).duplicate(true)
			entity["row"] = 0
			parser_initial.append(entity)
	parser_source["initialBoard"] = parser_initial

	return LevelDefinition.normalize_level(parser_source)


func _short_status(message: String) -> String:
	var clean := message.strip_edges().to_upper()
	if clean.length() <= 42:
		return clean
	return clean.substr(0, 39) + "..."
