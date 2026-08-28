extends "res://scripts/mission_level_test_entry.gd"

const MECHANIC_LASER_ACTIVE := Color("#ff4058")
const MECHANIC_LASER_IDLE := Color(0.45, 0.18, 0.20, 0.24)
const MECHANIC_LAUNCHER := Color("#55bfe3")
const MECHANIC_LAUNCHER_CORE := Color("#f2e3bb")
const MECHANIC_LASER_WIDTH := 7.0

var level_launchers: Array[Dictionary] = []
var level_lasers: Array[Dictionary] = []
var mechanics_elapsed := 0.0
var mechanic_previous_ball_positions: Dictionary = {}


func _load_authored_level(path: String) -> void:
	super._load_authored_level(path)
	if not authored_mode:
		return
	_load_level_mechanics()


func _load_level_mechanics() -> void:
	level_launchers.clear()
	level_lasers.clear()
	mechanics_elapsed = 0.0
	mechanic_previous_ball_positions.clear()

	var mechanics_variant: Variant = authored_level.get("mechanics", {})
	if typeof(mechanics_variant) != TYPE_DICTIONARY:
		return
	var mechanics: Dictionary = mechanics_variant

	var launchers_variant: Variant = mechanics.get("launchers", [])
	if typeof(launchers_variant) == TYPE_ARRAY:
		for launcher_variant in launchers_variant as Array:
			if typeof(launcher_variant) != TYPE_DICTIONARY:
				continue
			var source: Dictionary = launcher_variant
			var column := int(source.get("column", -1))
			var row := int(source.get("row", -1))
			if column < 0 or column >= int(authored_profile.get("columns", 7)) or row < 0 or row >= int(authored_profile.get("rows", 9)):
				continue
			level_launchers.append({
				"id": String(source.get("id", "launcher_%d" % (level_launchers.size() + 1))),
				"column": column,
				"row": row,
				"position": _cell_center(column, row),
				"direction": String(source.get("direction", "up")),
				"balls_inside": {},
			})

	var lasers_variant: Variant = mechanics.get("lasers", [])
	if typeof(lasers_variant) == TYPE_ARRAY:
		for laser_variant in lasers_variant as Array:
			if typeof(laser_variant) != TYPE_DICTIONARY:
				continue
			var source: Dictionary = laser_variant
			var from_variant: Variant = source.get("from", {})
			var to_variant: Variant = source.get("to", {})
			if typeof(from_variant) != TYPE_DICTIONARY or typeof(to_variant) != TYPE_DICTIONARY:
				continue
			var from_data: Dictionary = from_variant
			var to_data: Dictionary = to_variant
			level_lasers.append({
				"id": String(source.get("id", "laser_%d" % (level_lasers.size() + 1))),
				"from": Vector2(clampf(float(from_data.get("x", 0.0)), 0.0, 1.0), clampf(float(from_data.get("y", 0.0)), 0.0, 1.0)),
				"to": Vector2(clampf(float(to_data.get("x", 1.0)), 0.0, 1.0), clampf(float(to_data.get("y", 0.0)), 0.0, 1.0)),
				"on_seconds": maxf(0.05, float(source.get("onSeconds", 1.5))),
				"off_seconds": maxf(0.05, float(source.get("offSeconds", 1.0))),
				"start_delay": maxf(0.0, float(source.get("startDelay", 0.0))),
				"starts_on": bool(source.get("startsOn", true)),
			})


func _physics_process(delta: float) -> void:
	_capture_mechanic_ball_positions()
	super._physics_process(delta)
	if not authored_mode or menu_open or state != TurnState.FIRING:
		return
	mechanics_elapsed += delta
	_process_directional_launchers()
	_process_timed_lasers()


func _capture_mechanic_ball_positions() -> void:
	mechanic_previous_ball_positions.clear()
	if not authored_mode:
		return
	for entry in balls:
		if bool(entry.get("returned", false)):
			continue
		var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
		if is_instance_valid(body):
			mechanic_previous_ball_positions[body.get_instance_id()] = body.position


func _process_directional_launchers() -> void:
	if level_launchers.is_empty():
		return
	var trigger_radius := maxf(_active_ball_collision_radius() * 1.35, _active_cell() * 0.28)
	for launcher_data in level_launchers:
		var inside: Dictionary = launcher_data["balls_inside"]
		var center: Vector2 = launcher_data["position"]
		for entry in balls:
			if bool(entry.get("returned", false)):
				continue
			var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
			if not is_instance_valid(body):
				continue
			var ball_id := body.get_instance_id()
			var touching := body.position.distance_to(center) <= trigger_radius
			if not touching:
				inside.erase(ball_id)
				continue
			if inside.has(ball_id):
				continue
			inside[ball_id] = true
			var direction := _mechanic_direction_vector(String(launcher_data.get("direction", "up")))
			entry["velocity"] = direction * BALL_SPEED * ball_speed_multiplier


func _process_timed_lasers() -> void:
	if level_lasers.is_empty():
		return
	for entry in balls:
		if bool(entry.get("returned", false)):
			continue
		var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
		if not is_instance_valid(body):
			continue
		var current := body.position
		var previous: Vector2 = mechanic_previous_ball_positions.get(body.get_instance_id(), current)
		for laser_data in level_lasers:
			if not _laser_is_active(laser_data):
				continue
			var segment := _laser_segment(laser_data)
			if _motion_touches_segment(previous, current, segment[0], segment[1], _active_ball_collision_radius() + MECHANIC_LASER_WIDTH * 0.5):
				_destroy_ball_by_laser(entry)
				break


func _destroy_ball_by_laser(entry: Dictionary) -> void:
	if bool(entry.get("returned", false)):
		return
	var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
	entry["returned"] = true
	active_ball_count = maxi(0, active_ball_count - 1)
	if is_instance_valid(body):
		body.queue_free()
	entry["body"] = null


func _laser_is_active(laser_data: Dictionary) -> bool:
	var delay := float(laser_data.get("start_delay", 0.0))
	if mechanics_elapsed < delay:
		return false
	var on_seconds := maxf(0.05, float(laser_data.get("on_seconds", 1.5)))
	var off_seconds := maxf(0.05, float(laser_data.get("off_seconds", 1.0)))
	var cycle := on_seconds + off_seconds
	var phase := fposmod(mechanics_elapsed - delay, cycle)
	if bool(laser_data.get("starts_on", true)):
		return phase < on_seconds
	return phase >= off_seconds


func _laser_segment(laser_data: Dictionary) -> Array[Vector2]:
	var from_normalized: Vector2 = laser_data.get("from", Vector2.ZERO)
	var to_normalized: Vector2 = laser_data.get("to", Vector2.ONE)
	var size := Vector2(BOARD_RIGHT - BOARD_LEFT, RETURN_Y - BOARD_TOP)
	return [Vector2(BOARD_LEFT, BOARD_TOP) + from_normalized * size, Vector2(BOARD_LEFT, BOARD_TOP) + to_normalized * size]


func _laser_visual_segment(laser_data: Dictionary, inset: float) -> Array[Vector2]:
	var from_normalized: Vector2 = laser_data.get("from", Vector2.ZERO)
	var to_normalized: Vector2 = laser_data.get("to", Vector2.ONE)
	var safe_inset := maxf(0.0, inset)
	var origin := Vector2(BOARD_LEFT + safe_inset, BOARD_TOP + safe_inset)
	var size := Vector2(
		maxf(0.0, (BOARD_RIGHT - BOARD_LEFT) - safe_inset * 2.0),
		maxf(0.0, (RETURN_Y - BOARD_TOP) - safe_inset * 2.0)
	)
	return [origin + from_normalized * size, origin + to_normalized * size]


func _motion_touches_segment(motion_from: Vector2, motion_to: Vector2, laser_from: Vector2, laser_to: Vector2, radius: float) -> bool:
	var distance := motion_from.distance_to(motion_to)
	var step := maxf(2.0, radius * 0.5)
	var samples := maxi(1, int(ceil(distance / step)))
	for index in range(samples + 1):
		var point := motion_from.lerp(motion_to, float(index) / float(samples))
		if _point_segment_distance(point, laser_from, laser_to) <= radius:
			return true
	return false


func _point_segment_distance(point: Vector2, from: Vector2, to: Vector2) -> float:
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(from)
	var t := clampf((point - from).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(from + segment * t)


func _mechanic_direction_vector(direction: String) -> Vector2:
	match direction:
		"up_right": return Vector2(1.0, -1.0).normalized()
		"right": return Vector2.RIGHT
		"down_right": return Vector2(1.0, 1.0).normalized()
		"down": return Vector2.DOWN
		"down_left": return Vector2(-1.0, 1.0).normalized()
		"left": return Vector2.LEFT
		"up_left": return Vector2(-1.0, -1.0).normalized()
		_: return Vector2.UP


func _draw() -> void:
	super._draw()
	if not authored_mode:
		return
	draw_set_transform(Vector2(layout_content_x, layout_board_y_offset), 0.0, Vector2.ONE)
	_draw_level_launchers()
	_draw_level_lasers()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_level_launchers() -> void:
	var radius := maxf(6.0, _active_cell() * 0.27)
	for launcher_data in level_launchers:
		var center: Vector2 = launcher_data["position"]
		var direction := _mechanic_direction_vector(String(launcher_data.get("direction", "up")))
		draw_circle(center, radius, Color(PANEL, 0.96))
		draw_arc(center, radius, 0.0, TAU, 28, MECHANIC_LAUNCHER, maxf(2.0, radius * 0.12), true)
		var tip := center + direction * radius * 0.72
		var base := center - direction * radius * 0.28
		var side := direction.rotated(PI * 0.5) * radius * 0.32
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), MECHANIC_LAUNCHER_CORE)


func _draw_level_lasers() -> void:
	for laser_data in level_lasers:
		var active := _laser_is_active(laser_data)
		var width := maxf(2.0, MECHANIC_LASER_WIDTH * float(authored_profile.get("visual_scale", 1.0)))
		var emitter_radius := maxf(3.0, _active_cell() * 0.08)
		var visual_inset := emitter_radius + width * 0.5 + 1.0
		var segment := _laser_visual_segment(laser_data, visual_inset)
		if active:
			draw_line(segment[0], segment[1], MECHANIC_LASER_ACTIVE, width, true)
			draw_circle(segment[0], emitter_radius, MECHANIC_LASER_ACTIVE)
			draw_circle(segment[1], emitter_radius, MECHANIC_LASER_ACTIVE)
		else:
			draw_circle(segment[0], emitter_radius, MECHANIC_LASER_IDLE)
			draw_circle(segment[1], emitter_radius, MECHANIC_LASER_IDLE)
