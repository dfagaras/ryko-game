extends "res://scripts/level_authored_laser_geometry_entry.gd"

var _pending_multicell_width := 1
var _pending_multicell_height := 1


func _spawn_authored_entity(entity: Dictionary, row: int) -> void:
	_pending_multicell_width = 1
	_pending_multicell_height = 1
	if String(entity.get("kind", "")) == "block" and String(entity.get("shape", "square")) == "square":
		var variant := String(entity.get("variant", "normal"))
		if variant in ["normal", MISSION_VARIANT]:
			_pending_multicell_width = clampi(int(entity.get("widthCells", 1)), 1, 4)
			_pending_multicell_height = clampi(int(entity.get("heightCells", 1)), 1, 4)
	super._spawn_authored_entity(entity, row)
	_pending_multicell_width = 1
	_pending_multicell_height = 1


func _multicell_size(width_cells: int, height_cells: int) -> Vector2:
	return Vector2(
		_active_cell() + float(maxi(0, width_cells - 1)) * _active_column_step(),
		_active_cell() + float(maxi(0, height_cells - 1)) * _active_row_step()
	)


func _multicell_center(column: int, row: int, width_cells: int, height_cells: int) -> Vector2:
	return _cell_center(column, row) + Vector2(
		float(maxi(0, width_cells - 1)) * _active_column_step() * 0.5,
		float(maxi(0, height_cells - 1)) * _active_row_step() * 0.5
	)


func _multicell_rect(item: Dictionary) -> Rect2:
	var width_cells := clampi(int(item.get("width_cells", 1)), 1, 4)
	var height_cells := clampi(int(item.get("height_cells", 1)), 1, 4)
	var size := _multicell_size(width_cells, height_cells)
	var center: Vector2 = item.get("position", Vector2.ZERO)
	return Rect2(center - size * 0.5, size)


func _is_large_square(item: Dictionary) -> bool:
	return String(item.get("shape", "")) == "square" and (int(item.get("width_cells", 1)) > 1 or int(item.get("height_cells", 1)) > 1)


func _add_square_block(column: int, row: int, hp: int, variant: String = "normal", absorbing_sides: Array[String] = []) -> void:
	var width_cells := _pending_multicell_width
	var height_cells := _pending_multicell_height
	if not authored_mode or (width_cells == 1 and height_cells == 1):
		super._add_square_block(column, row, hp, variant, absorbing_sides)
		return

	var body := StaticBody2D.new()
	body.position = _multicell_center(column, row, width_cells, height_cells)
	body.collision_layer = BLOCK_COLLISION_LAYER
	body.set_meta("kind", "block")
	body.set_meta("block_index", blocks.size())
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _multicell_size(width_cells, height_cells)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	blocks.append({
		"body": body,
		"shape": "square",
		"variant": variant,
		"absorbing_sides": absorbing_sides,
		"phase_active": true,
		"hp_multiplier": DENSE_BLOCK_MULTIPLIER if variant == "dense" else 1,
		"hp": hp,
		"position": body.position,
		"column": column,
		"row": row,
		"orientation": "",
		"width_cells": width_cells,
		"height_cells": height_cells,
	})


func _ghost_point_overlaps_block(point: Vector2, item: Dictionary) -> bool:
	if authored_mode and _is_large_square(item):
		return _multicell_rect(item).grow(_active_ball_radius() * 0.55).has_point(point)
	return super._ghost_point_overlaps_block(point, item)


func _authored_circle_intersects_block(center: Vector2, radius: float, item: Dictionary) -> bool:
	if authored_mode and _is_large_square(item):
		var rect := _multicell_rect(item)
		var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
		return center.distance_squared_to(closest) <= radius * radius
	return super._authored_circle_intersects_block(center, radius, item)


func _fire_ion_beam(beam_position: Vector2, orientation: String) -> void:
	if not authored_mode:
		super._fire_ion_beam(beam_position, orientation)
		return
	ion_beam_effects.append({"position": beam_position, "orientation": orientation, "elapsed": 0.0})
	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		if String(item.get("variant", "normal")) == "phase" and not bool(item.get("phase_active", true)):
			continue
		if _is_large_square(item):
			var rect := _multicell_rect(item)
			if (orientation == "vertical" and beam_position.x >= rect.position.x and beam_position.x <= rect.end.x) or (orientation != "vertical" and beam_position.y >= rect.position.y and beam_position.y <= rect.end.y):
				_hit_block(body)
		else:
			var delta: Vector2 = item["position"] - beam_position
			if (orientation == "vertical" and absf(delta.x) <= _active_cell() * 0.5) or (orientation != "vertical" and absf(delta.y) <= _active_cell() * 0.5):
				_hit_block(body)


func _mark_authored_move_targets(items: Array) -> void:
	super._mark_authored_move_targets(items)
	for item in items:
		if not _is_large_square(item) or not item.has("move_to"):
			continue
		item["move_to"] = _multicell_center(
			int(item.get("column", 0)),
			int(item.get("row", 0)),
			int(item.get("width_cells", 1)),
			int(item.get("height_cells", 1))
		)


func _process_board_advance(delta: float) -> void:
	super._process_board_advance(delta)
	if not authored_mode or state != TurnState.AIMING:
		return
	var rows := int(authored_profile.get("rows", 9))
	for item in blocks:
		if not _is_large_square(item):
			continue
		var body: StaticBody2D = item.get("body", null) as StaticBody2D
		if not is_instance_valid(body):
			continue
		var bottom_row := int(item.get("row", 0)) + int(item.get("height_cells", 1)) - 1
		if bottom_row >= rows - 1:
			_finish_authored_level(false)
			return


func _draw_blocks() -> void:
	super._draw_blocks()
	if not authored_mode:
		return

	var scale := float(authored_profile.get("visual_scale", 1.0))
	var outline := maxf(1.0, BLOCK_OUTLINE_WIDTH * scale)
	for item in blocks:
		if not _is_large_square(item):
			continue
		var body: StaticBody2D = item.get("body", null) as StaticBody2D
		if not is_instance_valid(body):
			continue
		var rect := _multicell_rect(item)
		var variant := String(item.get("variant", "normal"))
		if variant == MISSION_VARIANT:
			draw_rect(rect, PANEL, true)
			_draw_mission_frame(rect)
			draw_texture_rect(_mission_animation_frame(item), _mission_pose_rect(rect), false)
			_draw_mission_progress(item, rect)
			var hit_flash_ratio := clampf(float(item.get("hit_flash", 0.0)) / BLOCK_HIT_FLASH_DURATION, 0.0, 1.0)
			if hit_flash_ratio > 0.0:
				draw_rect(rect.grow(-minf(rect.size.x, rect.size.y) * 0.08), Color(CREAM, hit_flash_ratio * 0.12), true)
			continue

		# Only normal numbered blocks can be authored as multi-cell today.
		draw_rect(rect, AMBER, true)
		draw_rect(rect.grow(-outline), PANEL.lerp(AMBER, 0.16), true)
		var font_size := maxi(10, int(round(24.0 * scale * minf(float(item.get("width_cells", 1)), 2.0))))
		_draw_centered_label(str(item.get("hp", 1)), rect.get_center(), font_size, CREAM)
