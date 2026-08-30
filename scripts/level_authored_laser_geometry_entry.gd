extends "res://scripts/level_top_row_mechanics_test_entry.gd"


func _laser_playfield_rect() -> Rect2:
	if authored_mode:
		var left := float(authored_profile.get("board_left", BOARD_LEFT))
		var right := float(authored_profile.get("board_right", BOARD_RIGHT))
		var top := float(authored_profile.get("board_top", BOARD_TOP))
		var bottom := float(authored_profile.get("launch_line_y", RETURN_Y))
		return Rect2(
			Vector2(left, top),
			Vector2(maxf(0.0, right - left), maxf(0.0, bottom - top))
		)
	return Rect2(
		Vector2(BOARD_LEFT, BOARD_TOP),
		Vector2(BOARD_RIGHT - BOARD_LEFT, RETURN_Y - BOARD_TOP)
	)


func _nearest_authored_grid_line(value: float, start: float, step: float, end: float, count: int) -> float:
	var best_value := start
	var best_distance := INF
	for index in range(count + 1):
		var candidate := end if index == count else start + float(index) * step
		var distance := absf(value - candidate)
		if distance < best_distance:
			best_distance = distance
			best_value = candidate
	return best_value


func _snap_authored_laser_point(normalized: Vector2) -> Vector2:
	var playfield := _laser_playfield_rect()
	var logical := playfield.position + normalized * playfield.size
	if not authored_mode:
		return logical

	var columns := int(authored_profile.get("columns", 7))
	var rows := int(authored_profile.get("rows", 9))
	var grid_x := float(authored_profile.get("grid_x", GRID_X))
	var grid_y := float(authored_profile.get("grid_y", GRID_Y))
	var column_step := float(authored_profile.get("column_step", ROW_STEP))
	var row_step := float(authored_profile.get("row_step", ROW_STEP))
	var grid_width := float(authored_profile.get("grid_width", BOARD_RIGHT - BOARD_LEFT))
	var grid_height := float(authored_profile.get("grid_height", RETURN_Y - GRID_Y))

	return Vector2(
		_nearest_authored_grid_line(logical.x, grid_x, column_step, grid_x + grid_width, columns),
		_nearest_authored_grid_line(logical.y, grid_y, row_step, grid_y + grid_height, rows)
	)


func _laser_segment(laser_data: Dictionary) -> Array[Vector2]:
	var from_normalized: Vector2 = laser_data.get("from", Vector2.ZERO)
	var to_normalized: Vector2 = laser_data.get("to", Vector2.ONE)
	return [
		_snap_authored_laser_point(from_normalized),
		_snap_authored_laser_point(to_normalized),
	]


func _laser_visual_segment(laser_data: Dictionary, _inset: float) -> Array[Vector2]:
	# Old authored files may still contain cell-center normalized endpoints.
	# Snap both rendering and collision onto the nearest exact grid intersections.
	return _laser_segment(laser_data)
