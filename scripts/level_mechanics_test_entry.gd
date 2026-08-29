extends "res://scripts/mission_level_test_entry.gd"

const MECHANIC_LASER_ACTIVE := Color("#ff4058")
const MECHANIC_LASER_IDLE := Color(0.45, 0.18, 0.20, 0.24)
const MECHANIC_LAUNCHER := Color("#55bfe3")
const MECHANIC_LAUNCHER_CORE := Color("#f2e3bb")
const MECHANIC_SHIELD := Color("#f2e3bb")
const MECHANIC_SWITCH := Color("#e7ae43")
const MECHANIC_PORTAL := Color("#9477b5")
const MECHANIC_LASER_WIDTH := 7.0

var level_launchers: Array[Dictionary] = []
var level_lasers: Array[Dictionary] = []
var level_shields: Array[Dictionary] = []
var level_switches: Array[Dictionary] = []
var level_portals: Array[Dictionary] = []
var mechanics_elapsed := 0.0
var mechanic_previous_ball_positions: Dictionary = {}
var shield_collision_sides: Dictionary = {}
var laser_forced_states: Dictionary = {}
var portal_ball_cooldowns: Dictionary = {}


func _load_authored_level(path: String) -> void:
	super._load_authored_level(path)
	if not authored_mode:
		return
	_load_level_mechanics()


func _load_level_mechanics() -> void:
	level_launchers.clear()
	level_lasers.clear()
	level_shields.clear()
	level_switches.clear()
	level_portals.clear()
	laser_forced_states.clear()
	portal_ball_cooldowns.clear()
	shield_collision_sides.clear()
	mechanics_elapsed = 0.0
	mechanic_previous_ball_positions.clear()
	var mechanics_variant: Variant = authored_level.get("mechanics", {})
	if typeof(mechanics_variant) != TYPE_DICTIONARY:
		return
	var mechanics: Dictionary = mechanics_variant
	var columns := int(authored_profile.get("columns", 7))
	var rows := int(authored_profile.get("rows", 9))

	var launchers_variant: Variant = mechanics.get("launchers", [])
	if typeof(launchers_variant) == TYPE_ARRAY:
		for launcher_variant in launchers_variant as Array:
			if typeof(launcher_variant) != TYPE_DICTIONARY: continue
			var source: Dictionary = launcher_variant
			var column := int(source.get("column", -1))
			var row := int(source.get("row", -1))
			if column < 0 or column >= columns or row < 0 or row >= rows: continue
			level_launchers.append({"id": String(source.get("id", "launcher_%d" % (level_launchers.size() + 1))), "column": column, "row": row, "position": _cell_center(column, row), "direction": String(source.get("direction", "up")), "balls_inside": {}})

	var lasers_variant: Variant = mechanics.get("lasers", [])
	if typeof(lasers_variant) == TYPE_ARRAY:
		for laser_variant in lasers_variant as Array:
			if typeof(laser_variant) != TYPE_DICTIONARY: continue
			var source: Dictionary = laser_variant
			var from_variant: Variant = source.get("from", {})
			var to_variant: Variant = source.get("to", {})
			if typeof(from_variant) != TYPE_DICTIONARY or typeof(to_variant) != TYPE_DICTIONARY: continue
			var from_data: Dictionary = from_variant
			var to_data: Dictionary = to_variant
			level_lasers.append({"id": String(source.get("id", "laser_%d" % (level_lasers.size() + 1))), "from": Vector2(clampf(float(from_data.get("x", 0.0)), 0.0, 1.0), clampf(float(from_data.get("y", 0.0)), 0.0, 1.0)), "to": Vector2(clampf(float(to_data.get("x", 1.0)), 0.0, 1.0), clampf(float(to_data.get("y", 0.0)), 0.0, 1.0)), "on_seconds": maxf(0.05, float(source.get("onSeconds", 1.5))), "off_seconds": maxf(0.05, float(source.get("offSeconds", 1.0))), "start_delay": maxf(0.0, float(source.get("startDelay", 0.0))), "starts_on": bool(source.get("startsOn", true))})

	var shields_variant: Variant = mechanics.get("shields", [])
	if typeof(shields_variant) == TYPE_ARRAY:
		for shield_variant in shields_variant as Array:
			if typeof(shield_variant) != TYPE_DICTIONARY: continue
			var source: Dictionary = shield_variant
			var column := int(source.get("column", -1))
			var row := int(source.get("row", -1))
			if column < 0 or column >= columns or row < 0 or row >= rows: continue
			var sides: Array[String] = []
			for side in source.get("sides", []):
				var side_name := String(side)
				if side_name in ["top", "right", "bottom", "left"] and side_name not in sides: sides.append(side_name)
			if sides.is_empty(): continue
			level_shields.append({"id": String(source.get("id", "shield_%d" % (level_shields.size() + 1))), "column": column, "row": row, "sides": sides, "block_id": _block_id_at_cell(column, row)})

	var switches_variant: Variant = mechanics.get("switches", [])
	if typeof(switches_variant) == TYPE_ARRAY:
		for switch_variant in switches_variant as Array:
			if typeof(switch_variant) != TYPE_DICTIONARY: continue
			var source: Dictionary = switch_variant
			var column := int(source.get("column", -1))
			var row := int(source.get("row", -1))
			if column < 0 or column >= columns or row < 0 or row >= rows: continue
			level_switches.append({"id": String(source.get("id", "switch_%d" % (level_switches.size() + 1))), "column": column, "row": row, "position": _cell_center(column, row), "target_id": String(source.get("targetId", "")), "action": String(source.get("action", "disable")), "duration_seconds": maxf(0.0, float(source.get("durationSeconds", 0.0))), "balls_inside": {}})

	var portals_variant: Variant = mechanics.get("portals", [])
	if typeof(portals_variant) == TYPE_ARRAY:
		for portal_variant in portals_variant as Array:
			if typeof(portal_variant) != TYPE_DICTIONARY: continue
			var source: Dictionary = portal_variant
			var column := int(source.get("column", -1))
			var row := int(source.get("row", -1))
			if column < 0 or column >= columns or row < 0 or row >= rows: continue
			level_portals.append({"id": String(source.get("id", "portal_%d" % (level_portals.size() + 1))), "pair_id": String(source.get("pairId", "pair_1")), "column": column, "row": row, "position": _cell_center(column, row)})
	queue_redraw()


func _block_id_at_cell(column: int, row: int) -> int:
	for item in blocks:
		if int(item.get("column", -1)) != column or int(item.get("row", -1)) != row: continue
		var body: StaticBody2D = item.get("body", null) as StaticBody2D
		if is_instance_valid(body): return body.get_instance_id()
	return 0


func _process(delta: float) -> void:
	super._process(delta)
	if not authored_mode:
		return
	if not menu_open:
		mechanics_elapsed += delta
		_expire_laser_forced_states()
	if not level_lasers.is_empty() or not level_shields.is_empty() or not level_switches.is_empty() or not level_portals.is_empty():
		queue_redraw()


func _physics_process(delta: float) -> void:
	_capture_mechanic_ball_positions()
	super._physics_process(delta)
	if not authored_mode or menu_open or state != TurnState.FIRING:
		return
	_update_portal_cooldowns(delta)
	_process_directional_launchers()
	_process_switches()
	_process_portals()
	_process_timed_lasers()


func _capture_mechanic_ball_positions() -> void:
	mechanic_previous_ball_positions.clear()
	if not authored_mode: return
	for entry in balls:
		if bool(entry.get("returned", false)): continue
		var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
		if is_instance_valid(body): mechanic_previous_ball_positions[body.get_instance_id()] = body.position


func _process_directional_launchers() -> void:
	if level_launchers.is_empty(): return
	var trigger_radius := maxf(_active_ball_collision_radius() * 1.35, _active_cell() * 0.28)
	for launcher_data in level_launchers:
		var inside: Dictionary = launcher_data["balls_inside"]
		var center: Vector2 = launcher_data["position"]
		for entry in balls:
			if bool(entry.get("returned", false)): continue
			var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
			if not is_instance_valid(body): continue
			var ball_id := body.get_instance_id()
			var touching := body.position.distance_to(center) <= trigger_radius
			if not touching:
				inside.erase(ball_id)
				continue
			if inside.has(ball_id): continue
			inside[ball_id] = true
			entry["velocity"] = _mechanic_direction_vector(String(launcher_data.get("direction", "up"))) * BALL_SPEED * ball_speed_multiplier


func _process_switches() -> void:
	if level_switches.is_empty(): return
	var trigger_radius := maxf(_active_ball_collision_radius() * 1.25, _active_cell() * 0.24)
	for switch_data in level_switches:
		var inside: Dictionary = switch_data["balls_inside"]
		var center: Vector2 = switch_data["position"]
		for entry in balls:
			if bool(entry.get("returned", false)): continue
			var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
			if not is_instance_valid(body): continue
			var ball_id := body.get_instance_id()
			var touching := body.position.distance_to(center) <= trigger_radius
			if not touching:
				inside.erase(ball_id)
				continue
			if inside.has(ball_id): continue
			inside[ball_id] = true
			_apply_switch(switch_data)


func _apply_switch(switch_data: Dictionary) -> void:
	var target_id := String(switch_data.get("target_id", ""))
	if target_id.is_empty(): return
	var desired := String(switch_data.get("action", "disable")) == "enable"
	var duration := maxf(0.0, float(switch_data.get("duration_seconds", 0.0)))
	laser_forced_states[target_id] = {"active": desired, "expires": mechanics_elapsed + duration if duration > 0.0 else -1.0}
	queue_redraw()


func _expire_laser_forced_states() -> void:
	var expired: Array[String] = []
	for target_id in laser_forced_states.keys():
		var data: Dictionary = laser_forced_states[target_id]
		var expires := float(data.get("expires", -1.0))
		if expires >= 0.0 and mechanics_elapsed >= expires: expired.append(String(target_id))
	for target_id in expired: laser_forced_states.erase(target_id)


func _update_portal_cooldowns(delta: float) -> void:
	var remove_ids: Array[int] = []
	for ball_id in portal_ball_cooldowns.keys():
		var remaining := float(portal_ball_cooldowns[ball_id]) - delta
		if remaining <= 0.0: remove_ids.append(int(ball_id))
		else: portal_ball_cooldowns[ball_id] = remaining
	for ball_id in remove_ids: portal_ball_cooldowns.erase(ball_id)


func _process_portals() -> void:
	if level_portals.is_empty(): return
	var trigger_radius := maxf(_active_ball_collision_radius() * 1.2, _active_cell() * 0.22)
	for entry in balls:
		if bool(entry.get("returned", false)): continue
		var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
		if not is_instance_valid(body): continue
		var ball_id := body.get_instance_id()
		if portal_ball_cooldowns.has(ball_id): continue
		for portal in level_portals:
			var center: Vector2 = portal["position"]
			if body.position.distance_to(center) > trigger_radius: continue
			var exit_portal := _portal_pair_exit(portal)
			if exit_portal.is_empty(): break
			var velocity: Vector2 = entry.get("velocity", Vector2.UP)
			var direction := velocity.normalized()
			if direction.length_squared() < 0.01: direction = Vector2.UP
			body.position = (exit_portal["position"] as Vector2) + direction * (trigger_radius + _active_ball_collision_radius() + 2.0)
			portal_ball_cooldowns[ball_id] = 0.10
			break


func _portal_pair_exit(portal: Dictionary) -> Dictionary:
	var pair_id := String(portal.get("pair_id", ""))
	var own_id := String(portal.get("id", ""))
	for candidate in level_portals:
		if String(candidate.get("pair_id", "")) == pair_id and String(candidate.get("id", "")) != own_id: return candidate
	return {}


func _process_timed_lasers() -> void:
	if level_lasers.is_empty(): return
	for entry in balls:
		if bool(entry.get("returned", false)): continue
		var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
		if not is_instance_valid(body): continue
		var current := body.position
		var previous: Vector2 = mechanic_previous_ball_positions.get(body.get_instance_id(), current)
		for laser_data in level_lasers:
			if not _laser_is_active(laser_data): continue
			var segment := _laser_segment(laser_data)
			if _motion_touches_segment(previous, current, segment[0], segment[1], _active_ball_collision_radius() + MECHANIC_LASER_WIDTH * 0.5):
				_destroy_ball_by_laser(entry)
				break


func _destroy_ball_by_laser(entry: Dictionary) -> void:
	if bool(entry.get("returned", false)): return
	var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
	entry["returned"] = true
	active_ball_count = maxi(0, active_ball_count - 1)
	if is_instance_valid(body): body.queue_free()
	entry["body"] = null


func _laser_is_active(laser_data: Dictionary) -> bool:
	var laser_id := String(laser_data.get("id", ""))
	if laser_forced_states.has(laser_id): return bool((laser_forced_states[laser_id] as Dictionary).get("active", false))
	var delay := float(laser_data.get("start_delay", 0.0))
	if mechanics_elapsed < delay: return false
	var on_seconds := maxf(0.05, float(laser_data.get("on_seconds", 1.5)))
	var off_seconds := maxf(0.05, float(laser_data.get("off_seconds", 1.0)))
	var cycle := on_seconds + off_seconds
	var phase := fposmod(mechanics_elapsed - delay, cycle)
	if bool(laser_data.get("starts_on", true)): return phase < on_seconds
	return phase >= off_seconds


func _block_absorbs_ball(body: StaticBody2D, collision_normal: Vector2) -> bool:
	if authored_mode:
		shield_collision_sides[body.get_instance_id()] = _collision_side_from_normal(collision_normal)
	return super._block_absorbs_ball(body, collision_normal)


func _hit_block(body: StaticBody2D) -> void:
	if authored_mode:
		var body_id := body.get_instance_id()
		if shield_collision_sides.has(body_id):
			var side := String(shield_collision_sides[body_id])
			shield_collision_sides.erase(body_id)
			var shield := _shield_for_block_id(body_id)
			if not shield.is_empty() and (shield.get("sides", []) as Array).has(side):
				queue_redraw()
				return
	super._hit_block(body)


func _shield_for_block_id(body_id: int) -> Dictionary:
	for shield in level_shields:
		if int(shield.get("block_id", 0)) == body_id: return shield
	return {}


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
	var size := Vector2(maxf(0.0, (BOARD_RIGHT - BOARD_LEFT) - safe_inset * 2.0), maxf(0.0, (RETURN_Y - BOARD_TOP) - safe_inset * 2.0))
	return [origin + from_normalized * size, origin + to_normalized * size]


func _motion_touches_segment(motion_from: Vector2, motion_to: Vector2, laser_from: Vector2, laser_to: Vector2, radius: float) -> bool:
	var distance := motion_from.distance_to(motion_to)
	var step := maxf(2.0, radius * 0.5)
	var samples := maxi(1, int(ceil(distance / step)))
	for index in range(samples + 1):
		var point := motion_from.lerp(motion_to, float(index) / float(samples))
		if _point_segment_distance(point, laser_from, laser_to) <= radius: return true
	return false


func _point_segment_distance(point: Vector2, from: Vector2, to: Vector2) -> float:
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001: return point.distance_to(from)
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
	if not authored_mode or menu_open: return
	draw_set_transform(Vector2(layout_content_x, layout_board_y_offset), 0.0, Vector2.ONE)
	_draw_level_launchers()
	_draw_level_lasers()
	_draw_level_shields()
	_draw_level_switches()
	_draw_level_portals()
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


func _draw_level_shields() -> void:
	var half := _active_cell() * 0.5
	var width := maxf(2.0, _active_cell() * 0.075)
	for shield in level_shields:
		var body_id := int(shield.get("block_id", 0))
		var center := Vector2.ZERO
		for item in blocks:
			var body: StaticBody2D = item.get("body", null) as StaticBody2D
			if is_instance_valid(body) and body.get_instance_id() == body_id:
				center = item.get("position", body.position)
				break
		if center == Vector2.ZERO: continue
		var sides: Array = shield.get("sides", [])
		if sides.has("top"): draw_line(center + Vector2(-half, -half), center + Vector2(half, -half), MECHANIC_SHIELD, width, true)
		if sides.has("right"): draw_line(center + Vector2(half, -half), center + Vector2(half, half), MECHANIC_SHIELD, width, true)
		if sides.has("bottom"): draw_line(center + Vector2(-half, half), center + Vector2(half, half), MECHANIC_SHIELD, width, true)
		if sides.has("left"): draw_line(center + Vector2(-half, -half), center + Vector2(-half, half), MECHANIC_SHIELD, width, true)


func _draw_level_switches() -> void:
	var radius := maxf(4.0, _active_cell() * 0.18)
	for switch_data in level_switches:
		var center: Vector2 = switch_data["position"]
		draw_circle(center, radius, Color(PANEL, 0.96))
		draw_arc(center, radius, 0.0, TAU, 24, MECHANIC_SWITCH, maxf(2.0, radius * 0.18), true)
		draw_circle(center, radius * 0.38, MECHANIC_SWITCH)


func _draw_level_portals() -> void:
	var radius := maxf(5.0, _active_cell() * 0.24)
	for portal in level_portals:
		var center: Vector2 = portal["position"]
		draw_circle(center, radius, Color(PANEL, 0.88))
		draw_arc(center, radius, 0.0, TAU, 28, MECHANIC_PORTAL, maxf(2.0, radius * 0.14), true)
		draw_arc(center, radius * 0.58, 0.35, TAU + 0.35, 24, Color(MECHANIC_PORTAL, 0.72), maxf(1.0, radius * 0.10), true)
