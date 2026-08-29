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


func _laser_segment(laser_data: Dictionary) -> Array[Vector2]:
	var from_normalized: Vector2 = laser_data.get("from", Vector2.ZERO)
	var to_normalized: Vector2 = laser_data.get("to", Vector2.ONE)
	var playfield := _laser_playfield_rect()
	return [
		playfield.position + from_normalized * playfield.size,
		playfield.position + to_normalized * playfield.size,
	]


func _laser_visual_segment(laser_data: Dictionary, inset: float) -> Array[Vector2]:
	var from_normalized: Vector2 = laser_data.get("from", Vector2.ZERO)
	var to_normalized: Vector2 = laser_data.get("to", Vector2.ONE)
	var playfield := _laser_playfield_rect()
	var safe_inset := maxf(0.0, inset)
	var origin := playfield.position + Vector2.ONE * safe_inset
	var size := Vector2(
		maxf(0.0, playfield.size.x - safe_inset * 2.0),
		maxf(0.0, playfield.size.y - safe_inset * 2.0),
	)
	return [origin + from_normalized * size, origin + to_normalized * size]
