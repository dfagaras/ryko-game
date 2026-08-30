extends "res://scripts/level_multicell_blocks_entry.gd"

var authored_spawned_incoming_rows := 0
var authored_future_mission_cores := 0


func _load_authored_level(path: String) -> void:
	super._load_authored_level(path)
	if not authored_mode:
		return
	authored_spawned_incoming_rows = 0
	authored_future_mission_cores = _count_mission_cores_in_incoming_range(0)
	# The editor's Top Row is the authored row immediately above R1. Spawn it as
	# row -1 so it is playable immediately and joins the normal first descent.
	for entity_variant in authored_level.get("topRow", []):
		if typeof(entity_variant) == TYPE_DICTIONARY:
			_spawn_authored_entity(entity_variant as Dictionary, -1)
	queue_redraw()


func _mission_cores_in_row(row_def: Dictionary) -> int:
	var count := 0
	for entity_variant in row_def.get("cells", []):
		if typeof(entity_variant) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_variant
		if String(entity.get("kind", "")) == "block" and String(entity.get("variant", "normal")) == MISSION_VARIANT:
			count += 1
	return count


func _count_mission_cores_in_incoming_range(start_index: int) -> int:
	if not authored_mode:
		return 0
	var incoming_rows: Array = authored_level.get("incomingRows", [])
	var count := 0
	for row_index in range(maxi(0, start_index), incoming_rows.size()):
		var row_variant: Variant = incoming_rows[row_index]
		if typeof(row_variant) == TYPE_DICTIONARY:
			count += _mission_cores_in_row(row_variant as Dictionary)
	return count


func _future_mission_core_count() -> int:
	if not authored_mode:
		return 0
	return maxi(0, authored_future_mission_cores)


func _live_mission_core_count() -> int:
	return super._live_mission_core_count() + _future_mission_core_count()


func _live_block_count() -> int:
	var count := super._live_block_count()
	if authored_mode and _authored_uses_mission_objectives():
		count += _future_mission_core_count()
	return count


func _spawn_incoming_launchers(row_def: Dictionary) -> void:
	var launchers_variant: Variant = row_def.get("launchers", [])
	if typeof(launchers_variant) != TYPE_ARRAY:
		return
	var columns := int(authored_profile.get("columns", 7))
	var valid_directions: Array[String] = ["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]
	for launcher_variant in launchers_variant as Array:
		if typeof(launcher_variant) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = launcher_variant
		var column := int(source.get("column", -1))
		if column < 0 or column >= columns:
			continue
		var direction := String(source.get("direction", "up"))
		if direction not in valid_directions:
			direction = "up"
		level_launchers.append({
			"id": String(source.get("id", "incoming_launcher_%d" % (level_launchers.size() + 1))),
			"column": column,
			"row": -1,
			"position": _cell_center(column, -1),
			"direction": direction,
			"balls_inside": {},
		})


func _mark_launcher_move_targets() -> void:
	for launcher_data in level_launchers:
		var current_position: Vector2 = launcher_data.get("position", _cell_center(int(launcher_data.get("column", 0)), int(launcher_data.get("row", 0))))
		var target_row := int(launcher_data.get("row", 0)) + 1
		launcher_data["row"] = target_row
		launcher_data["move_from"] = current_position
		launcher_data["move_to"] = _cell_center(int(launcher_data.get("column", 0)), target_row)


func _begin_authored_board_advance() -> void:
	if not authored_mode:
		super._begin_authored_board_advance()
		return

	var incoming_rows: Array = authored_level.get("incomingRows", [])
	var incoming_index := authored_completed_moves - 1
	super._begin_authored_board_advance()

	if incoming_index >= 0 and incoming_index < incoming_rows.size():
		var row_variant: Variant = incoming_rows[incoming_index]
		if typeof(row_variant) == TYPE_DICTIONARY:
			var row_def: Dictionary = row_variant
			_spawn_incoming_launchers(row_def)
			authored_future_mission_cores = maxi(0, authored_future_mission_cores - _mission_cores_in_row(row_def))
		authored_spawned_incoming_rows = maxi(authored_spawned_incoming_rows, incoming_index + 1)

	_mark_launcher_move_targets()
	queue_redraw()


func _update_descending_launchers(eased: float) -> void:
	for launcher_data in level_launchers:
		if not launcher_data.has("move_from"):
			continue
		launcher_data["position"] = (launcher_data["move_from"] as Vector2).lerp(launcher_data["move_to"], eased)


func _cleanup_descending_launchers() -> void:
	var rows := int(authored_profile.get("rows", 9))
	var keep: Array[Dictionary] = []
	for launcher_data in level_launchers:
		launcher_data.erase("move_from")
		launcher_data.erase("move_to")
		if int(launcher_data.get("row", 0)) < rows:
			keep.append(launcher_data)
	level_launchers.assign(keep)


func _process_board_advance(delta: float) -> void:
	if not authored_mode:
		super._process_board_advance(delta)
		return

	super._process_board_advance(delta)
	var progress := clampf(row_advance_elapsed / ROW_DROP_DURATION, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	_update_descending_launchers(eased)
	if progress >= 1.0:
		_cleanup_descending_launchers()
	queue_redraw()
