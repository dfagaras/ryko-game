extends "res://scripts/level_launcher_access.gd"

# Development flow: the web editor copies the exact exported Ryko JSON to the
# clipboard, then the game stores it in user://levels. This avoids Android file
# picker inconsistencies and lets authored levels be tested without rebuilding.


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

	var parsed := LevelDefinition.parse_json_text(raw_text)
	if not bool(parsed.get("valid", false)):
		import_status = "INVALID RYKO JSON"
		push_error("RYKO clipboard import rejected: %s" % str(parsed.get("errors", [])))
		queue_redraw()
		return

	var parsed_level: Dictionary = parsed.get("level", {}) as Dictionary
	var level_id := _sanitize_level_id(String(parsed_level.get("levelId", "")))
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
