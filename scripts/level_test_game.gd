extends "res://scripts/game_menu.gd"

const LevelDefinition = preload("res://scripts/level_definition.gd")
const LEVELS_DIR := "res://levels"
const LEVELS_MENU_PAGE := 5
const LEVELS_PANEL_RECT := Rect2(80.0, 300.0, 560.0, 650.0)
const LEVELS_BUTTON_HEIGHT := 58.0
const LEVELS_BUTTON_GAP := 10.0
const EXTENDED_BALL_MIN := 0.20
const EXTENDED_BALL_MAX := 3.00
const RECOMMENDED_BALL_MIN := 0.65
const RECOMMENDED_BALL_MAX := 1.35

var authored_mode := false
var authored_level_path := ""
var authored_level: Dictionary = {}
var authored_profile: Dictionary = {}
var authored_completed_moves := 0
var authored_result := ""
var authored_level_files: Array[String] = []


func _settings_backgrounds_rect() -> Rect2:
	return Rect2(145.0, 475.0, 430.0, 68.0)


func _settings_ball_sounds_rect() -> Rect2:
	return Rect2(145.0, 558.0, 430.0, 68.0)


func _settings_levels_rect() -> Rect2:
	return Rect2(145.0, 641.0, 430.0, 68.0)


func _settings_back_rect() -> Rect2:
	return Rect2(235.0, 744.0, 250.0, 64.0)


func _levels_back_rect() -> Rect2:
	return Rect2(235.0, 855.0, 250.0, 64.0)


func _draw_settings_popup() -> void:
	_draw_rounded_panel(SETTINGS_POPUP_RECT, Color(PANEL, 0.99), Color(CREAM, 0.82), 3.0, 18.0)
	_draw_rounded_panel(SETTINGS_POPUP_RECT.grow(-8.0), Color(PANEL, 0.99), Color(AMBER, 0.26), 1.0, 14.0)
	_draw_centered_label("SETTINGS", Vector2(W * 0.5, 405.0), 27, CREAM)
	_draw_centered_label("MISSION CONTROL", Vector2(W * 0.5, 440.0), 12, Color(AQUA, 0.82))
	_draw_menu_action_button(_settings_backgrounds_rect(), "BACKGROUNDS", PHASE_BLUE)
	_draw_menu_action_button(_settings_ball_sounds_rect(), "BALL SOUNDS", AMBER)
	_draw_menu_action_button(_settings_levels_rect(), "LEVELS", CORAL)
	_draw_menu_action_button(_settings_back_rect(), "BACK", AQUA)


func _draw_menu_overlay() -> void:
	if menu_page == LEVELS_MENU_PAGE:
		_draw_levels_popup()
		return
	super._draw_menu_overlay()


func _draw_levels_popup() -> void:
	_refresh_level_catalog()
	_draw_rounded_panel(LEVELS_PANEL_RECT, Color(PANEL, 0.99), Color(CREAM, 0.82), 3.0, 18.0)
	_draw_rounded_panel(LEVELS_PANEL_RECT.grow(-8.0), Color(PANEL, 0.99), Color(AQUA, 0.24), 1.0, 14.0)
	_draw_centered_label("LEVELS", Vector2(W * 0.5, 345.0), 27, CREAM)
	_draw_centered_label("TEST LAUNCHER // JSON", Vector2(W * 0.5, 380.0), 12, Color(AQUA, 0.82))

	if authored_level_files.is_empty():
		_draw_centered_label("NO JSON LEVELS IN /levels YET", Vector2(W * 0.5, 510.0), 14, Color(CREAM, 0.68))
		_draw_centered_label("ADD A LEVEL JSON AND IT WILL APPEAR HERE", Vector2(W * 0.5, 545.0), 10, Color(MUTED, 0.88))
	else:
		var max_visible := mini(7, authored_level_files.size())
		for index in range(max_visible):
			var rect := _level_option_rect(index)
			var filename := authored_level_files[index]
			var selected := authored_mode and authored_level_path == LEVELS_DIR.path_join(filename)
			draw_rect(rect, Color(PLAYFIELD_BG, 0.98), true)
			draw_rect(rect, AQUA if selected else Color(CREAM, 0.34), false, 3.0 if selected else 1.5, true)
			_draw_centered_label(_level_display_name(filename), rect.get_center(), 14, CREAM)
			if selected:
				_draw_centered_label("ACTIVE", Vector2(rect.end.x - 42.0, rect.get_center().y), 9, AQUA)

	_draw_menu_action_button(_levels_back_rect(), "BACK", AQUA)


func _level_option_rect(index: int) -> Rect2:
	return Rect2(125.0, 420.0 + float(index) * (LEVELS_BUTTON_HEIGHT + LEVELS_BUTTON_GAP), 470.0, LEVELS_BUTTON_HEIGHT)


func _level_display_name(filename: String) -> String:
	return filename.trim_suffix(".json").replace("_", " ").to_upper()


func _refresh_level_catalog() -> void:
	authored_level_files.clear()
	if not DirAccess.dir_exists_absolute(LEVELS_DIR):
		return
	for filename in DirAccess.get_files_at(LEVELS_DIR):
		if filename.to_lower().ends_with(".json"):
			authored_level_files.append(filename)
	authored_level_files.sort()


func _handle_menu_press(pointer: Vector2) -> void:
	if menu_page == 4 and _settings_levels_rect().has_point(pointer):
		menu_page = LEVELS_MENU_PAGE
		queue_redraw()
		return
	if menu_page == LEVELS_MENU_PAGE:
		_refresh_level_catalog()
		for index in range(mini(7, authored_level_files.size())):
			if _level_option_rect(index).has_point(pointer):
				_load_authored_level(LEVELS_DIR.path_join(authored_level_files[index]))
				return
		if _levels_back_rect().has_point(pointer):
			menu_page = 4
			queue_redraw()
		return
	super._handle_menu_press(pointer)


func _start_new_run() -> void:
	if authored_mode and not authored_level_path.is_empty():
		_load_authored_level(authored_level_path)
		return
	super._start_new_run()


func _load_authored_level(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("RYKO level launcher: cannot open %s" % path)
		return
	var raw_text := file.get_as_text()
	var json := JSON.new()
	if json.parse(raw_text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		print("RYKO level launcher: invalid JSON %s" % path)
		return
	var raw: Dictionary = json.data
	var requested_multiplier := _normalize_extended_ball_multiplier(raw.get("ball", {}).get("sizeMultiplier", 1.0)) if typeof(raw.get("ball", {})) == TYPE_DICTIONARY else 1.0

	# The existing parser remains the source of truth for board/entity validation.
	# It currently validates the normal ball range, so parse a safe copy and then
	# restore the explicitly supported test-level multiplier (0.20x..3.00x).
	var parser_source := raw.duplicate(true)
	parser_source["ball"] = {"sizeMultiplier": clampf(requested_multiplier, RECOMMENDED_BALL_MIN, RECOMMENDED_BALL_MAX)}
	var parsed := LevelDefinition.normalize_level(parser_source)
	if not bool(parsed.get("valid", false)):
		print("RYKO level launcher rejected %s: %s" % [path, str(parsed.get("errors", []))])
		return

	authored_mode = true
	authored_level_path = path
	authored_level = (parsed["level"] as Dictionary).duplicate(true)
	authored_level["ball"] = {"sizeMultiplier": requested_multiplier}
	authored_profile = (parsed["board_profile"] as Dictionary).duplicate(true)
	authored_completed_moves = 0
	authored_result = ""
	menu_open = false
	menu_page = 0
	_clear_run_objects()
	state = TurnState.AIMING
	turn = 1
	ball_count = maxi(1, int(authored_level.get("rules", {}).get("startingBalls", 1)))
	pending_ball_bonus = 0
	launcher = Vector2(W * 0.5, RETURN_Y)
	next_launcher_x = launcher.x
	first_return_recorded = false
	aim_direction = Vector2(0, -1)
	is_aiming = false
	aim_gesture_active = false
	pull_distance = 0.0
	pull_strength = 0.0
	launched_ball_count = 0
	active_ball_count = 0
	launch_timer = 0.0
	row_advance_elapsed = 0.0
	field_clear_triggered = false
	score = 0

	for entity_variant in authored_level.get("initialBoard", []):
		if typeof(entity_variant) == TYPE_DICTIONARY:
			_spawn_authored_entity(entity_variant as Dictionary, int((entity_variant as Dictionary).get("row", 0)))
	print("RYKO authored level loaded: %s (%dx%d, ball %.2fx)" % [
		path,
		int(authored_profile.get("columns", 7)),
		int(authored_profile.get("rows", 9)),
		_authored_ball_multiplier()
	])
	queue_redraw()


func _normalize_extended_ball_multiplier(value: Variant) -> float:
	return clampf(float(value), EXTENDED_BALL_MIN, EXTENDED_BALL_MAX)


func _authored_ball_multiplier() -> float:
	if not authored_mode:
		return 1.0
	var ball_variant: Variant = authored_level.get("ball", {})
	if typeof(ball_variant) != TYPE_DICTIONARY:
		return 1.0
	return _normalize_extended_ball_multiplier((ball_variant as Dictionary).get("sizeMultiplier", 1.0))


func _active_cell() -> float:
	return float(authored_profile.get("cell", CELL)) if authored_mode else CELL


func _active_column_step() -> float:
	return float(authored_profile.get("column_step", ROW_STEP)) if authored_mode else ROW_STEP


func _active_row_step() -> float:
	return float(authored_profile.get("row_step", ROW_STEP)) if authored_mode else ROW_STEP


func _active_ball_radius() -> float:
	if not authored_mode:
		return BALL_RADIUS
	return float(authored_profile.get("ball_radius", BALL_RADIUS)) * _authored_ball_multiplier()


func _active_ball_collision_radius() -> float:
	if not authored_mode:
		return BALL_COLLISION_RADIUS
	return float(authored_profile.get("ball_collision_radius", BALL_COLLISION_RADIUS)) * _authored_ball_multiplier()


func _active_pickup_radius() -> float:
	return float(authored_profile.get("pickup_radius", PICKUP_RADIUS)) if authored_mode else PICKUP_RADIUS


func _active_ion_radius() -> float:
	return float(authored_profile.get("ion_radius", ION_BEAM_RADIUS)) if authored_mode else ION_BEAM_RADIUS


func _active_ghost_radius() -> float:
	return float(authored_profile.get("ghost_radius", GHOST_CORE_RADIUS)) if authored_mode else GHOST_CORE_RADIUS


func _active_supernova_radius() -> float:
	return float(authored_profile.get("supernova_core_radius", SUPERNOVA_CORE_RADIUS)) if authored_mode else SUPERNOVA_CORE_RADIUS


func _active_supernova_explosion_radius() -> float:
	return float(authored_profile.get("supernova_explosion_radius", SUPERNOVA_EXPLOSION_RADIUS)) if authored_mode else SUPERNOVA_EXPLOSION_RADIUS


func _cell_center(column: int, row: int) -> Vector2:
	if not authored_mode:
		return super._cell_center(column, row)
	return Vector2(
		float(authored_profile.get("grid_x", GRID_X)) + float(column) * _active_column_step() + _active_cell() * 0.5,
		float(authored_profile.get("grid_y", GRID_Y)) + float(row) * _active_row_step() + _active_cell() * 0.5
	)


func _spawn_position(column: int, row: int) -> Vector2:
	if not authored_mode:
		return super._spawn_position(column, row)
	if row < 0:
		return Vector2(_cell_center(column, 0).x, BOARD_TOP + _active_cell() * 0.5)
	return _cell_center(column, row)


func _triangle_local_points(orientation: String) -> PackedVector2Array:
	if not authored_mode:
		return super._triangle_local_points(orientation)
	var half := _active_cell() * 0.5
	return _orient_triangle_points(PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half)
	]), orientation)


func _triangle_inner_local_points(orientation: String) -> PackedVector2Array:
	if not authored_mode:
		return super._triangle_inner_local_points(orientation)
	var half := _active_cell() * 0.5
	var inset := maxf(1.0, BLOCK_OUTLINE_WIDTH * float(authored_profile.get("visual_scale", 1.0)))
	var acute := inset * (1.0 + sqrt(2.0))
	return _orient_triangle_points(PackedVector2Array([
		Vector2(-half + inset, -half + inset),
		Vector2(half - acute, -half + inset),
		Vector2(-half + inset, half - acute)
	]), orientation)


func _add_square_block(column: int, row: int, hp: int, variant: String = "normal", absorbing_sides: Array[String] = []) -> void:
	if not authored_mode:
		super._add_square_block(column, row, hp, variant, absorbing_sides)
		return
	var body := StaticBody2D.new()
	body.position = _spawn_position(column, row)
	body.collision_layer = BLOCK_COLLISION_LAYER
	body.set_meta("kind", "block")
	body.set_meta("block_index", blocks.size())
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * _active_cell()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	blocks.append({"body": body, "shape": "square", "variant": variant, "absorbing_sides": absorbing_sides, "phase_active": true, "hp_multiplier": DENSE_BLOCK_MULTIPLIER if variant == "dense" else 1, "hp": hp, "position": body.position, "column": column, "row": row, "orientation": ""})


func _add_triangle_block(column: int, row: int, hp: int, orientation: String, variant: String = "normal") -> void:
	if not authored_mode:
		super._add_triangle_block(column, row, hp, orientation, variant)
		return
	var body := StaticBody2D.new()
	body.position = _spawn_position(column, row)
	body.collision_layer = BLOCK_COLLISION_LAYER
	body.set_meta("kind", "block")
	body.set_meta("block_index", blocks.size())
	var collision := CollisionPolygon2D.new()
	collision.polygon = _triangle_local_points(orientation)
	body.add_child(collision)
	add_child(body)
	blocks.append({"body": body, "shape": "triangle", "variant": "normal", "phase_active": true, "hp_multiplier": 1, "hp": hp, "position": body.position, "column": column, "row": row, "orientation": orientation})


func _spawn_authored_entity(entity: Dictionary, row: int) -> void:
	var column := int(entity.get("column", 0))
	var kind := String(entity.get("kind", ""))
	match kind:
		"block":
			var shape := String(entity.get("shape", "square"))
			var hp := maxi(1, int(entity.get("hp", 1)))
			if shape == "triangle":
				_add_triangle_block(column, row, hp, String(entity.get("orientation", "top_left")), "normal")
			else:
				var sides: Array[String] = []
				for side in entity.get("absorbingSides", []):
					sides.append(String(side))
				_add_square_block(column, row, hp, String(entity.get("variant", "normal")), sides)
		"pickup":
			pickups.append({"column": column, "row": row, "position": _spawn_position(column, row), "collected": false})
		"power":
			var power_type := String(entity.get("type", ""))
			if power_type == "ion":
				ion_powers.append({"column": column, "row": row, "position": _spawn_position(column, row), "orientation": String(entity.get("orientation", "horizontal")), "activated": false, "balls_inside": {}})
			elif power_type == "ghost":
				ghost_cores.append({"column": column, "row": row, "position": _spawn_position(column, row), "activated": false})
			elif power_type == "supernova":
				supernova_cores.append({"column": column, "row": row, "position": _spawn_position(column, row), "activated": false, "pulse_elapsed": SUPERNOVA_EFFECT_DURATION})


func _spawn_volley_ball() -> void:
	if not authored_mode:
		super._spawn_volley_ball()
		return
	var body := CharacterBody2D.new()
	body.position = launcher
	body.collision_layer = BALL_COLLISION_LAYER
	body.collision_mask = WALL_COLLISION_LAYER | BLOCK_COLLISION_LAYER
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = _active_ball_collision_radius()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	balls.append({"body": body, "velocity": volley_direction * BALL_SPEED * ball_speed_multiplier, "returned": false, "ghost": false, "supernova": false, "ghost_blocks_inside": {}})
	launched_ball_count += 1
	active_ball_count += 1


func _collect_pickups_at(ball_position: Vector2) -> void:
	if not authored_mode:
		super._collect_pickups_at(ball_position)
		return
	for pickup in pickups:
		if bool(pickup["collected"]):
			continue
		if ball_position.distance_to(pickup["position"]) <= _active_pickup_radius() + _active_ball_radius():
			pickup["collected"] = true
			pending_ball_bonus += 1


func _activate_ion_powers_at(ball: CharacterBody2D) -> void:
	if not authored_mode:
		super._activate_ion_powers_at(ball)
		return
	var ball_id := ball.get_instance_id()
	for power in ion_powers:
		var inside: Dictionary = power["balls_inside"]
		if ball.position.distance_to(power["position"]) > _active_ion_radius() + _active_ball_radius():
			inside.erase(ball_id)
			continue
		if inside.has(ball_id):
			continue
		inside[ball_id] = true
		power["activated"] = true
		_fire_ion_beam(power["position"], String(power["orientation"]))


func _activate_ghost_cores_at(entry: Dictionary) -> void:
	if not authored_mode:
		super._activate_ghost_cores_at(entry)
		return
	var body: CharacterBody2D = entry["body"] as CharacterBody2D
	if not is_instance_valid(body):
		return
	for core in ghost_cores:
		if body.position.distance_to(core["position"]) <= _active_ghost_radius() + _active_ball_radius():
			core["activated"] = true
			entry["ghost"] = true
			body.collision_mask = WALL_COLLISION_LAYER


func _activate_supernova_cores_at(entry: Dictionary) -> void:
	if not authored_mode:
		super._activate_supernova_cores_at(entry)
		return
	if bool(entry.get("supernova", false)) or _supernova_remaining_charges() <= 0:
		return
	var body: CharacterBody2D = entry["body"] as CharacterBody2D
	if not is_instance_valid(body):
		return
	for core in supernova_cores:
		if body.position.distance_to(core["position"]) <= _active_supernova_radius() + _active_ball_radius():
			entry["supernova"] = true
			supernova_charged_count += 1
			core["activated"] = true
			core["pulse_elapsed"] = 0.0
			return


func _ghost_path_crosses_block(from: Vector2, to: Vector2, item: Dictionary) -> bool:
	if not authored_mode:
		return super._ghost_path_crosses_block(from, to, item)
	var sample_step := maxf(1.0, _active_ball_radius() * 0.6)
	var sample_count := maxi(1, int(ceil(from.distance_to(to) / sample_step)))
	for index in range(sample_count + 1):
		if _ghost_point_overlaps_block(from.lerp(to, float(index) / float(sample_count)), item):
			return true
	return false


func _ghost_point_overlaps_block(point: Vector2, item: Dictionary) -> bool:
	if not authored_mode:
		return super._ghost_point_overlaps_block(point, item)
	var center: Vector2 = item["position"]
	if String(item["shape"]) == "square":
		return Rect2(center - Vector2.ONE * _active_cell() * 0.5, Vector2.ONE * _active_cell()).grow(_active_ball_radius() * 0.55).has_point(point)
	var polygon := PackedVector2Array()
	for local_point in _triangle_local_points(String(item["orientation"])):
		polygon.append(center + local_point)
	var probe := _active_ball_radius() * 0.55
	for offset in [Vector2.ZERO, Vector2(probe, 0), Vector2(-probe, 0), Vector2(0, probe), Vector2(0, -probe)]:
		if Geometry2D.is_point_in_polygon(point + offset, polygon):
			return true
	return false


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
		var delta: Vector2 = item["position"] - beam_position
		if (orientation == "vertical" and absf(delta.x) <= _active_cell() * 0.5) or (orientation != "vertical" and absf(delta.y) <= _active_cell() * 0.5):
			_hit_block(body)


func _trigger_supernova_explosion(center: Vector2) -> void:
	if not authored_mode:
		super._trigger_supernova_explosion(center)
		return
	supernova_effects.append({"position": center, "elapsed": 0.0})
	var targets: Array[StaticBody2D] = []
	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if is_instance_valid(body) and _authored_circle_intersects_block(center, _active_supernova_explosion_radius(), item):
			targets.append(body)
	for target in targets:
		if is_instance_valid(target):
			_hit_block(target)


func _authored_circle_intersects_block(center: Vector2, radius: float, item: Dictionary) -> bool:
	var block_center: Vector2 = item["position"]
	if String(item["shape"]) == "square":
		var rect := Rect2(block_center - Vector2.ONE * _active_cell() * 0.5, Vector2.ONE * _active_cell())
		var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
		return center.distance_squared_to(closest) <= radius * radius
	var polygon := PackedVector2Array()
	for local_point in _triangle_local_points(String(item["orientation"])):
		polygon.append(block_center + local_point)
	if Geometry2D.is_point_in_polygon(center, polygon):
		return true
	for point in polygon:
		if center.distance_squared_to(point) <= radius * radius:
			return true
	return false


func _return_ball(entry: Dictionary) -> void:
	if not authored_mode:
		super._return_ball(entry)
		return
	var body: CharacterBody2D = entry["body"] as CharacterBody2D
	if not first_return_recorded:
		next_launcher_x = clampf(body.position.x, BOARD_LEFT + _active_ball_collision_radius(), BOARD_RIGHT - _active_ball_collision_radius())
		first_return_recorded = true
	entry["returned"] = true
	active_ball_count -= 1
	body.queue_free()
	entry["body"] = null


func _finish_volley() -> void:
	if not authored_mode:
		super._finish_volley()
		return
	_regenerate_surviving_blocks()
	balls.clear()
	supernova_charged_count = 0
	launcher.x = next_launcher_x
	launcher.y = RETURN_Y
	ball_count += pending_ball_bonus
	pending_ball_bonus = 0
	authored_completed_moves += 1
	turn = authored_completed_moves + 1

	if _live_block_count() == 0:
		_finish_authored_level(true)
		return

	var rules: Dictionary = authored_level.get("rules", {})
	if String(rules.get("mode", "clear_limited")) == "clear_limited":
		_toggle_phase_blocks()
		if authored_completed_moves >= maxi(1, int(rules.get("moveLimit", 1))):
			_finish_authored_level(false)
		else:
			state = TurnState.AIMING
		queue_redraw()
		return

	_begin_authored_board_advance()


func _finish_authored_level(won: bool) -> void:
	authored_result = "won" if won else "lost"
	state = TurnState.GAME_OVER
	is_aiming = false
	aim_gesture_active = false
	if won:
		_trigger_field_clear()
	queue_redraw()


func _begin_authored_board_advance() -> void:
	state = TurnState.ADVANCING
	row_advance_elapsed = 0.0
	_toggle_phase_blocks()
	pickups = pickups.filter(func(p): return not bool(p["collected"]))
	ion_powers = ion_powers.filter(func(p): return not bool(p["activated"]))
	ghost_cores = ghost_cores.filter(func(p): return not bool(p["activated"]))
	supernova_cores = supernova_cores.filter(func(p): return not bool(p["activated"]))

	var incoming_rows: Array = authored_level.get("incomingRows", [])
	var incoming_index := authored_completed_moves - 1
	if incoming_index >= 0 and incoming_index < incoming_rows.size():
		var row_def: Dictionary = incoming_rows[incoming_index]
		for entity_variant in row_def.get("cells", []):
			if typeof(entity_variant) == TYPE_DICTIONARY:
				_spawn_authored_entity(entity_variant as Dictionary, -1)

	_mark_authored_move_targets(blocks)
	_mark_authored_move_targets(pickups)
	_mark_authored_move_targets(ion_powers)
	_mark_authored_move_targets(ghost_cores)
	_mark_authored_move_targets(supernova_cores)


func _mark_authored_move_targets(items: Array) -> void:
	for item in items:
		var body_variant: Variant = item.get("body", null)
		var current_position: Vector2 = body_variant.position if body_variant is Node2D and is_instance_valid(body_variant) else item["position"]
		var target_row := int(item.get("row", 0)) + 1
		item["row"] = target_row
		item["move_from"] = current_position
		item["move_to"] = _cell_center(int(item["column"]), target_row)


func _process_board_advance(delta: float) -> void:
	if not authored_mode:
		super._process_board_advance(delta)
		return
	row_advance_elapsed += delta
	var progress := clampf(row_advance_elapsed / ROW_DROP_DURATION, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	_update_authored_moving_items(blocks, eased)
	_update_authored_moving_items(pickups, eased)
	_update_authored_moving_items(ion_powers, eased)
	_update_authored_moving_items(ghost_cores, eased)
	_update_authored_moving_items(supernova_cores, eased)
	if progress < 1.0:
		return

	var reached_danger := false
	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		item.erase("move_from")
		item.erase("move_to")
		if int(item.get("row", 0)) >= int(authored_profile.get("rows", 9)) - 1:
			reached_danger = true

	_cleanup_authored_nonblocks(pickups)
	_cleanup_authored_nonblocks(ion_powers)
	_cleanup_authored_nonblocks(ghost_cores)
	_cleanup_authored_nonblocks(supernova_cores)
	if reached_danger:
		_finish_authored_level(false)
		return
	if _live_block_count() == 0:
		_finish_authored_level(true)
		return
	state = TurnState.AIMING


func _update_authored_moving_items(items: Array, eased: float) -> void:
	for item in items:
		if not item.has("move_from"):
			continue
		var position: Vector2 = (item["move_from"] as Vector2).lerp(item["move_to"], eased)
		item["position"] = position
		var body_variant: Variant = item.get("body", null)
		if body_variant is Node2D and is_instance_valid(body_variant):
			body_variant.position = position


func _cleanup_authored_nonblocks(items: Array) -> void:
	var keep: Array[Dictionary] = []
	for item in items:
		item.erase("move_from")
		item.erase("move_to")
		if int(item.get("row", 0)) < int(authored_profile.get("rows", 9)):
			keep.append(item)
	items.assign(keep)


func _draw_active_balls() -> void:
	if not authored_mode:
		super._draw_active_balls()
		return
	var radius := _active_ball_radius()
	for entry in balls:
		if bool(entry["returned"]):
			continue
		var body: CharacterBody2D = entry["body"] as CharacterBody2D
		if not is_instance_valid(body):
			continue
		var is_ghost := bool(entry.get("ghost", false))
		var is_supernova := bool(entry.get("supernova", false))
		var fill := GHOST_PURPLE if is_ghost else (NOVA_RED if is_supernova else AQUA)
		draw_circle(body.position, radius, Color(fill, 0.72 if is_ghost else 1.0))
		draw_circle(body.position, maxf(1.0, radius * 0.42), CREAM)
		if is_supernova:
			draw_arc(body.position, radius + maxf(1.0, radius * 0.18), 0.0, TAU, 24, NOVA_ORANGE, maxf(1.0, radius * 0.22), true)


func _draw_blocks() -> void:
	if not authored_mode:
		super._draw_blocks()
		return
	var cell := _active_cell()
	var scale := float(authored_profile.get("visual_scale", 1.0))
	var outline := maxf(1.0, BLOCK_OUTLINE_WIDTH * scale)
	var font_size := maxi(7, int(round(24.0 * scale)))
	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		var center: Vector2 = item["position"]
		var hp := str(item["hp"])
		var variant := String(item.get("variant", "normal"))
		var phase_active := bool(item.get("phase_active", true))
		var alpha := 1.0 if phase_active else 0.28
		var label_center := center
		if String(item["shape"]) == "square":
			var rect := Rect2(center - Vector2.ONE * cell * 0.5, Vector2.ONE * cell)
			var border := AMBER
			if variant == "dense": border = DENSE_ORANGE
			elif variant == "regenerative": border = REGENERATIVE_GREEN
			elif variant == "black_hole": border = VOID_PURPLE
			elif variant == "phase": border = Color(PHASE_BLUE, alpha)
			draw_rect(rect, border, true)
			draw_rect(rect.grow(-outline), PANEL.lerp(border, 0.16), true)
			if variant == "dense": _draw_cell_texture(ICON_BLOCK_DENSE, rect)
			elif variant == "regenerative": _draw_cell_texture(ICON_BLOCK_REGENERATIVE, rect)
			elif variant == "black_hole":
				_draw_cell_texture(ICON_BLOCK_BLACK_HOLE, rect)
				_draw_black_hole_sides(rect, item.get("absorbing_sides", []))
			elif variant == "phase": _draw_cell_texture(ICON_BLOCK_PHASE, rect, alpha)
		else:
			var points := PackedVector2Array()
			var centroid := Vector2.ZERO
			for local in _triangle_local_points(String(item["orientation"])):
				points.append(center + local)
				centroid += local
			centroid /= 3.0
			label_center = center + centroid
			var inner := PackedVector2Array()
			for local in _triangle_inner_local_points(String(item["orientation"])):
				inner.append(center + local)
			draw_colored_polygon(points, CORAL)
			draw_colored_polygon(inner, PANEL.lerp(CORAL, 0.16))
		_draw_centered_label(hp, label_center, maxi(6, font_size - (2 if String(item["shape"]) == "triangle" else 0)), CREAM)


func _draw_black_hole_sides(rect: Rect2, absorbing_sides: Array) -> void:
	if not authored_mode:
		super._draw_black_hole_sides(rect, absorbing_sides)
		return
	var center := rect.get_center()
	var edge := maxf(2.0, rect.size.x * 0.18)
	for side_value in absorbing_sides:
		var side := String(side_value)
		var tip := center
		var inward := Vector2.ZERO
		match side:
			"left": tip = Vector2(rect.position.x + edge, center.y); inward = Vector2.RIGHT
			"right": tip = Vector2(rect.end.x - edge, center.y); inward = Vector2.LEFT
			"top": tip = Vector2(center.x, rect.position.y + edge); inward = Vector2.DOWN
			"bottom": tip = Vector2(center.x, rect.end.y - edge); inward = Vector2.UP
		var side_vec := inward.rotated(PI * 0.5)
		var size := maxf(1.5, rect.size.x * 0.07)
		draw_colored_polygon(PackedVector2Array([tip + inward * size, tip - inward * size * 0.5 + side_vec * size, tip - inward * size * 0.5 - side_vec * size]), CORAL)


func _draw_pickups() -> void:
	if not authored_mode:
		super._draw_pickups()
		return
	for pickup in pickups:
		if bool(pickup["collected"]): continue
		var radius := _active_pickup_radius()
		_draw_cell_texture(ICON_POWER_PLUS_ONE, Rect2(pickup["position"] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), 0.94)


func _draw_ion_powers() -> void:
	if not authored_mode:
		super._draw_ion_powers()
		return
	for power in ion_powers:
		var radius := _active_ion_radius()
		var rect := Rect2(Vector2(-radius, -radius), Vector2.ONE * radius * 2.0)
		draw_set_transform(active_draw_offset + power["position"], PI * 0.5 if String(power["orientation"]) == "vertical" else 0.0, Vector2.ONE)
		draw_texture_rect(ICON_POWER_ION, rect, false, Color(1, 1, 1, 0.48 if bool(power["activated"]) else 0.92))
		draw_set_transform(active_draw_offset, 0.0, Vector2.ONE)


func _draw_ghost_cores() -> void:
	if not authored_mode:
		super._draw_ghost_cores()
		return
	for core in ghost_cores:
		var radius := _active_ghost_radius()
		_draw_cell_texture(ICON_POWER_GHOST, Rect2(core["position"] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), 0.48 if bool(core["activated"]) else 0.92)


func _draw_supernova_cores() -> void:
	if not authored_mode:
		super._draw_supernova_cores()
		return
	for core in supernova_cores:
		var radius := _active_supernova_radius()
		_draw_cell_texture(ICON_POWER_SUPERNOVA, Rect2(core["position"] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), 0.48 if bool(core["activated"]) else 0.92)


func _draw_game_over() -> void:
	if not authored_mode:
		super._draw_game_over()
		return
	var won := authored_result == "won"
	var accent := AQUA if won else CORAL
	draw_rect(Rect2(Vector2(0, 360), Vector2(W, 360)), Color(0.02, 0.07, 0.08, 0.94), true)
	draw_string(fallback_font, Vector2(0, 465), "LEVEL CLEARED" if won else "LEVEL FAILED", HORIZONTAL_ALIGNMENT_CENTER, W, 44, accent)
	draw_string(fallback_font, Vector2(0, 525), String(authored_level.get("name", authored_level_path.get_file())), HORIZONTAL_ALIGNMENT_CENTER, W, 22, CREAM)
	draw_string(fallback_font, Vector2(0, 575), "%d SHOTS" % authored_completed_moves, HORIZONTAL_ALIGNMENT_CENTER, W, 18, Color(CREAM, 0.78))
	draw_string(fallback_font, Vector2(0, 630), "TAP TO RESTART", HORIZONTAL_ALIGNMENT_CENTER, W, 18, AQUA)
