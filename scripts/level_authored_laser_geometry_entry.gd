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


func _laser_center_segment(laser_data: Dictionary) -> Array[Vector2]:
	var from_normalized: Vector2 = laser_data.get("from", Vector2.ZERO)
	var to_normalized: Vector2 = laser_data.get("to", Vector2.ONE)
	var playfield := _laser_playfield_rect()
	return [
		playfield.position + from_normalized * playfield.size,
		playfield.position + to_normalized * playfield.size,
	]


func _extend_segment_to_cell_edges(segment: Array[Vector2]) -> Array[Vector2]:
	if not authored_mode or segment.size() < 2:
		return segment
	var from_point := segment[0]
	var to_point := segment[1]
	var delta := to_point - from_point
	if delta.length_squared() <= 0.0001:
		return segment
	var direction := delta.normalized()
	var dominant := maxf(absf(direction.x), absf(direction.y))
	if dominant <= 0.0001:
		return segment
	# The JSON endpoints represent authored cell centers. Extend by exactly half
	# a cell to the outer edge of the first/last selected cell. Using the dominant
	# axis also keeps diagonal lasers aligned with the square cell boundary.
	var edge_distance := (_active_cell() * 0.5) / dominant
	return [
		from_point - direction * edge_distance,
		to_point + direction * edge_distance,
	]


func _laser_segment(laser_data: Dictionary) -> Array[Vector2]:
	return _extend_segment_to_cell_edges(_laser_center_segment(laser_data))


func _laser_visual_segment(laser_data: Dictionary, _inset: float) -> Array[Vector2]:
	# Visuals and collision intentionally share the exact same edge-to-edge
	# segment so the laser never looks shorter than its gameplay hitbox.
	return _laser_segment(laser_data)
