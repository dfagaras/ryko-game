extends Node2D

enum TurnState {
	AIMING,
	FIRING,
	ADVANCING,
	GAME_OVER
}

const W := 720.0
const H := 1280.0
const BOARD_LEFT := 28.0
const BOARD_RIGHT := 692.0
const BOARD_TOP := 176.0
const CELL := 88.0
const TRIANGLE_WIDTH := CELL
const TRIANGLE_HEIGHT := CELL
const GAP := 4.0
const ROW_STEP := CELL + GAP
const ROW_DROP_DURATION := 0.46
# Preserve the original cell centers while expanding each block into the old
# empty space. The remaining gap now matches the four-pixel outline width.
const GRID_X := 40.0
const GRID_Y := 239.0
const COLUMN_COUNT := 7
const LAST_PLAYABLE_BLOCK_ROW := 8
const LAUNCH_LINE_Y := GRID_Y + LAST_PLAYABLE_BLOCK_ROW * ROW_STEP + CELL
const RETURN_Y := LAUNCH_LINE_Y

const MIN_PULL_DISTANCE := 14.0
const MAX_PULL_DISTANCE := 300.0
const RELEASE_PULL_DISTANCE := 48.0
# Limit shots to 15 degrees above horizontal, matching the reference feel.
const MIN_UPWARD_COMPONENT := 0.258819
const MAX_HORIZONTAL_COMPONENT := 0.965926
const BALL_SPEED := 760.0
const BALL_RADIUS := 9.0
const BALL_COLLISION_RADIUS := 10.0
const BALL_LAUNCH_INTERVAL := 0.075
const PICKUP_RADIUS := 19.0
const TRIANGLE_CHANCE := 0.28
const TRIANGLE_ORIENTATIONS := ["top_left", "top_right", "bottom_left", "bottom_right"]
const BLOCK_OUTLINE_WIDTH := 6.0
const DENSE_BLOCK_START_TURN := 10
const DENSE_BLOCK_MULTIPLIER := 2
const REGENERATIVE_BLOCK_START_TURN := 12
const REGENERATIVE_GROWTH := 1.5
const BLACK_HOLE_BLOCK_START_TURN := 5
const PHASE_BLOCK_START_TURN := 8
const ION_BEAM_START_TURN := 4
const ION_BEAM_RADIUS := 20.0
const ION_BEAM_EFFECT_DURATION := 0.30

const BG := Color("#08191c")
const PLAYFIELD_BG := Color("#0b2225")
const PANEL := Color("#0d262a")
const AMBER := Color("#ffb84a")
const AQUA := Color("#56e0d2")
const CORAL := Color("#ff6b5f")
const REGENERATIVE_GREEN := Color("#9ee66f")
const VOID_PURPLE := Color("#b36cff")
const VOID_DARK := Color("#020608")
const PHASE_BLUE := Color("#78a8ff")
const ION_BLUE := Color("#32d8ff")
const MUTED := Color("#55777a")
const CREAM := Color("#f3e7c5")

@export var fixed_generation_seed: int = 0

var state := TurnState.AIMING
var turn := 1
var ball_count := 1
var pending_ball_bonus := 0
var launcher := Vector2(W * 0.5, RETURN_Y)
var next_launcher_x := W * 0.5
var first_return_recorded := false

var aim_direction := Vector2(0, -1)
var is_aiming := false
var drag_origin := Vector2.ZERO
var pull_distance := 0.0
var pull_strength := 0.0

var volley_direction := Vector2(0, -1)
var launched_ball_count := 0
var active_ball_count := 0
var launch_timer := 0.0
var row_advance_elapsed := 0.0

var balls: Array[Dictionary] = []
var blocks: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var ion_powers: Array[Dictionary] = []
var ion_beam_effects: Array[Dictionary] = []
var fallback_font: Font
var rng := RandomNumberGenerator.new()
var run_seed := 0


func _ready() -> void:
	fallback_font = ThemeDB.fallback_font
	_create_boundaries()
	_start_new_run()


func _create_boundaries() -> void:
	_add_wall(Vector2(BOARD_LEFT - 12.0, (BOARD_TOP + RETURN_Y) * 0.5), Vector2(24.0, RETURN_Y - BOARD_TOP + 24.0))
	_add_wall(Vector2(BOARD_RIGHT + 12.0, (BOARD_TOP + RETURN_Y) * 0.5), Vector2(24.0, RETURN_Y - BOARD_TOP + 24.0))
	_add_wall(Vector2(W * 0.5, BOARD_TOP - 12.0), Vector2(BOARD_RIGHT - BOARD_LEFT + 48.0, 24.0))


func _add_wall(position: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = position
	wall.set_meta("kind", "wall")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)


func _start_new_run() -> void:
	_clear_run_objects()
	state = TurnState.AIMING
	turn = 1
	ball_count = 1
	pending_ball_bonus = 0
	launcher = Vector2(W * 0.5, RETURN_Y)
	next_launcher_x = launcher.x
	first_return_recorded = false
	aim_direction = Vector2(0, -1)
	is_aiming = false
	pull_distance = 0.0
	pull_strength = 0.0
	launched_ball_count = 0
	active_ball_count = 0
	launch_timer = 0.0
	row_advance_elapsed = 0.0

	if fixed_generation_seed != 0:
		run_seed = fixed_generation_seed
	else:
		run_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
	rng.seed = run_seed
	print("RYKO endless seed: %s" % run_seed)

	_spawn_row(turn)
	queue_redraw()


func _clear_run_objects() -> void:
	for item in blocks:
		var body: StaticBody2D = item.get("body") as StaticBody2D
		if is_instance_valid(body):
			body.queue_free()
	blocks.clear()

	for entry in balls:
		var body: CharacterBody2D = entry.get("body") as CharacterBody2D
		if is_instance_valid(body):
			body.queue_free()
	balls.clear()
	pickups.clear()
	ion_powers.clear()
	ion_beam_effects.clear()


func _cell_center(column: int, row: int) -> Vector2:
	return Vector2(GRID_X + column * ROW_STEP + CELL * 0.5, GRID_Y + row * ROW_STEP + CELL * 0.5)


func _spawn_row(hp: int, row: int = 0) -> void:
	var columns := _shuffled_columns()
	var block_count := _block_count_for_turn()
	var row_shapes: Array[String] = []
	var row_orientations: Array[String] = []
	var square_indices: Array[int] = []

	for index in range(block_count):
		if turn >= 3 and rng.randf() < TRIANGLE_CHANCE:
			var orientation: String = TRIANGLE_ORIENTATIONS[rng.randi_range(0, TRIANGLE_ORIENTATIONS.size() - 1)]
			row_shapes.append("triangle")
			row_orientations.append(orientation)
		else:
			row_shapes.append("square")
			row_orientations.append("")
			square_indices.append(index)

	# Dense blocks are intentionally limited to one per row and can only be
	# assigned to a square. The roll happens once per row so triangle frequency
	# does not accidentally make dense blocks more common.
	var dense_index := -1
	if not square_indices.is_empty() and rng.randf() < _dense_block_spawn_chance():
		dense_index = square_indices[rng.randi_range(0, square_indices.size() - 1)]

	# Regenerative blocks are square-only and never replace the dense square.
	var regenerative_index := -1
	var regenerative_candidates: Array[int] = []
	for index in square_indices:
		if index != dense_index:
			regenerative_candidates.append(index)
	if not regenerative_candidates.is_empty() and rng.randf() < _regenerative_block_spawn_chance():
		regenerative_index = regenerative_candidates[rng.randi_range(0, regenerative_candidates.size() - 1)]

	# Black holes are square-only, limited to one per row, and cannot overlap
	# another special variant.
	var black_hole_index := -1
	var black_hole_candidates: Array[int] = []
	for index in square_indices:
		if index != dense_index and index != regenerative_index:
			black_hole_candidates.append(index)
	if not black_hole_candidates.is_empty() and rng.randf() < _black_hole_block_spawn_chance():
		black_hole_index = black_hole_candidates[rng.randi_range(0, black_hole_candidates.size() - 1)]

	# Phase blocks may use either base shape, but cannot overlap another special
	# variant. They spawn active and alternate on every later row descent.
	var phase_index := -1
	var phase_candidates: Array[int] = []
	for index in range(block_count):
		if index != dense_index and index != regenerative_index and index != black_hole_index:
			phase_candidates.append(index)
	if not phase_candidates.is_empty() and rng.randf() < _phase_block_spawn_chance():
		phase_index = phase_candidates[rng.randi_range(0, phase_candidates.size() - 1)]

	for index in range(block_count):
		var column := columns[index]
		var variant := "normal"
		if index == regenerative_index:
			variant = "regenerative"
		elif index == phase_index:
			variant = "phase"
		if row_shapes[index] == "triangle":
			_add_triangle_block(column, row, hp, row_orientations[index], variant)
		else:
			var is_dense := index == dense_index
			var square_hp := hp * DENSE_BLOCK_MULTIPLIER if is_dense else hp
			var absorbing_sides: Array[String] = []
			if is_dense:
				variant = "dense"
			elif index == black_hole_index:
				variant = "black_hole"
				square_hp = maxi(1, int(floor(float(hp) * 0.5)))
				absorbing_sides = _choose_black_hole_sides()
			_add_square_block(column, row, square_hp, variant, absorbing_sides)

	var pickup_column := columns[block_count]
	pickups.append({
		"column": pickup_column,
		"row": row,
		"position": _cell_center(pickup_column, row),
		"collected": false
	})

	# Keep the permanent +1 pickup, then use a second empty cell for Ion Beam
	# when the generated row has enough room.
	if block_count + 1 < COLUMN_COUNT and rng.randf() < _ion_beam_spawn_chance():
		var ion_column := columns[block_count + 1]
		ion_powers.append({
			"column": ion_column,
			"row": row,
			"position": _cell_center(ion_column, row),
			"activated": false,
			"triggered_balls": {}
		})


func _block_count_for_turn() -> int:
	if turn <= 4:
		return rng.randi_range(1, 3)
	if turn <= 9:
		return rng.randi_range(2, 4)
	if turn <= 19:
		return rng.randi_range(3, 5)
	return rng.randi_range(4, 6)


func _dense_block_spawn_chance() -> float:
	if turn < DENSE_BLOCK_START_TURN:
		return 0.0
	if turn <= 19:
		return 0.22
	if turn <= 29:
		return 0.30
	return 0.38


func _regenerative_block_spawn_chance() -> float:
	if turn < REGENERATIVE_BLOCK_START_TURN:
		return 0.0
	if turn <= 19:
		return 0.18
	if turn <= 29:
		return 0.24
	return 0.30


func _black_hole_block_spawn_chance() -> float:
	if turn < BLACK_HOLE_BLOCK_START_TURN:
		return 0.0
	if turn <= 9:
		return 0.25
	if turn <= 19:
		return 0.30
	return 0.35


func _phase_block_spawn_chance() -> float:
	if turn < PHASE_BLOCK_START_TURN:
		return 0.0
	if turn <= 19:
		return 0.20
	if turn <= 29:
		return 0.26
	return 0.32


func _ion_beam_spawn_chance() -> float:
	if turn < ION_BEAM_START_TURN:
		return 0.0
	if turn <= 9:
		return 0.28
	if turn <= 19:
		return 0.32
	return 0.36


func _choose_black_hole_sides() -> Array[String]:
	var sides: Array[String] = ["left", "right", "top", "bottom"]
	for index in range(sides.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value := sides[index]
		sides[index] = sides[swap_index]
		sides[swap_index] = value

	var side_count := rng.randi_range(1, 4)
	var selected: Array[String] = []
	for index in range(side_count):
		selected.append(sides[index])
	return selected


func _shuffled_columns() -> Array[int]:
	var result: Array[int] = []
	for column in range(COLUMN_COUNT):
		result.append(column)
	for index in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value := result[index]
		result[index] = result[swap_index]
		result[swap_index] = value
	return result


func _add_square_block(column: int, row: int, hp: int, variant: String = "normal", absorbing_sides: Array[String] = []) -> void:
	var body := StaticBody2D.new()
	body.position = _cell_center(column, row)
	body.set_meta("kind", "block")
	body.set_meta("block_index", blocks.size())
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL, CELL)
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
		"orientation": ""
	})


func _add_triangle_block(column: int, row: int, hp: int, orientation: String, variant: String = "normal") -> void:
	var body := StaticBody2D.new()
	body.position = _cell_center(column, row)
	body.set_meta("kind", "block")
	body.set_meta("block_index", blocks.size())
	var collision := CollisionPolygon2D.new()
	collision.polygon = _triangle_local_points(orientation)
	body.add_child(collision)
	add_child(body)
	blocks.append({
		"body": body,
		"shape": "triangle",
		"variant": variant,
		"phase_active": true,
		"hp_multiplier": 1,
		"hp": hp,
		"position": body.position,
		"column": column,
		"row": row,
		"orientation": orientation
	})


func _triangle_local_points(orientation: String) -> PackedVector2Array:
	# Keep the same top and bottom alignment as squares, while retaining the
	# exact same outer bounds. The visible tip is part of these bounds.
	var half_width := TRIANGLE_WIDTH * 0.5
	var half_height := TRIANGLE_HEIGHT * 0.5
	var base_points := PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(-half_width, half_height)
	])
	return _orient_triangle_points(base_points, orientation)


func _triangle_inner_local_points(orientation: String) -> PackedVector2Array:
	# Build a mathematically inset right triangle. Drawing a smaller dark
	# triangle over the solid outer triangle keeps the six-pixel border fully
	# inside the cell and preserves a sharp outer tip without miter overflow.
	var half_width := TRIANGLE_WIDTH * 0.5
	var half_height := TRIANGLE_HEIGHT * 0.5
	var inset := BLOCK_OUTLINE_WIDTH
	var acute_inset := inset * (1.0 + sqrt(2.0))
	var base_points := PackedVector2Array([
		Vector2(-half_width + inset, -half_height + inset),
		Vector2(half_width - acute_inset, -half_height + inset),
		Vector2(-half_width + inset, half_height - acute_inset)
	])
	return _orient_triangle_points(base_points, orientation)


func _orient_triangle_points(points: PackedVector2Array, orientation: String) -> PackedVector2Array:
	var flip_x := orientation == "top_right" or orientation == "bottom_right"
	var flip_y := orientation == "bottom_left" or orientation == "bottom_right"
	var result := PackedVector2Array()
	for point in points:
		var oriented_point := point
		if flip_x:
			oriented_point.x = -oriented_point.x
		if flip_y:
			oriented_point.y = -oriented_point.y
		result.append(oriented_point)
	return result


func _unhandled_input(event: InputEvent) -> void:
	if state == TurnState.GAME_OVER:
		if event is InputEventScreenTouch and event.pressed:
			_start_new_run()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_new_run()
		return

	if state == TurnState.FIRING:
		if event is InputEventScreenTouch and event.pressed and _recall_button_rect().has_point(event.position):
			_recall_volley()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _recall_button_rect().has_point(event.position):
			_recall_volley()
		return

	if state != TurnState.AIMING:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_aim(event.position)
		else:
			_release_aim()
		queue_redraw()
	elif event is InputEventScreenDrag:
		_update_drag_aim(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_aim(event.position)
		else:
			_release_aim()
		queue_redraw()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_drag_aim(event.position)
		queue_redraw()


func _begin_aim(pointer: Vector2) -> void:
	drag_origin = pointer
	pull_distance = 0.0
	pull_strength = 0.0
	is_aiming = false


func _update_drag_aim(pointer: Vector2) -> void:
	var pull := pointer - drag_origin
	pull_distance = maxf(0.0, pull.y)

	if pull_distance < MIN_PULL_DISTANCE:
		pull_strength = 0.0
		is_aiming = false
		return

	var candidate := Vector2(-pull.x, -pull_distance).normalized()
	if candidate.y > -MIN_UPWARD_COMPONENT:
		candidate = Vector2(signf(candidate.x) * MAX_HORIZONTAL_COMPONENT, -MIN_UPWARD_COMPONENT)

	aim_direction = candidate
	pull_strength = clamp(
		(pull_distance - MIN_PULL_DISTANCE) / (MAX_PULL_DISTANCE - MIN_PULL_DISTANCE),
		0.0,
		1.0
	)
	is_aiming = true


func _release_aim() -> void:
	if is_aiming and pull_distance >= RELEASE_PULL_DISTANCE:
		_launch_volley()
	is_aiming = false
	pull_distance = 0.0
	pull_strength = 0.0


func _launch_volley() -> void:
	state = TurnState.FIRING
	volley_direction = aim_direction
	launched_ball_count = 0
	active_ball_count = 0
	launch_timer = 0.0
	first_return_recorded = false
	next_launcher_x = launcher.x
	balls.clear()
	queue_redraw()


func _recall_button_rect() -> Rect2:
	return Rect2(Vector2(W - 158.0, H - 92.0), Vector2(130.0, 58.0))


func _recall_volley() -> void:
	if state != TurnState.FIRING:
		return

	# If no ball has returned naturally, recalling keeps the existing launcher
	# position. Otherwise, the first natural return remains authoritative.
	if not first_return_recorded:
		next_launcher_x = launcher.x
		first_return_recorded = true

	# Cancel balls that were still waiting in the launch queue and safely remove
	# every active ball before advancing the board.
	launched_ball_count = ball_count
	for entry in balls:
		if bool(entry["returned"]):
			continue
		entry["returned"] = true
		var body: CharacterBody2D = entry["body"] as CharacterBody2D
		if is_instance_valid(body):
			body.collision_layer = 0
			body.queue_free()
		entry["body"] = null
	active_ball_count = 0
	_finish_volley()
	queue_redraw()


func _spawn_volley_ball() -> void:
	var body := CharacterBody2D.new()
	body.position = launcher
	# Balls share the same launch path but must never collide with one another.
	body.collision_layer = 2
	body.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	# The collision radius is intentionally one pixel larger than the rendered
	# ball so it never appears embedded in a block outline at contact.
	shape.radius = BALL_COLLISION_RADIUS
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	balls.append({
		"body": body,
		"velocity": volley_direction * BALL_SPEED,
		"returned": false
	})
	launched_ball_count += 1
	active_ball_count += 1


func _physics_process(delta: float) -> void:
	_update_ion_beam_effects(delta)
	if state == TurnState.ADVANCING:
		_process_board_advance(delta)
		queue_redraw()
		return

	if state != TurnState.FIRING:
		return

	launch_timer -= delta
	while launched_ball_count < ball_count and launch_timer <= 0.0:
		_spawn_volley_ball()
		launch_timer += BALL_LAUNCH_INTERVAL

	for entry in balls:
		if bool(entry["returned"]):
			continue
		var body: CharacterBody2D = entry["body"] as CharacterBody2D
		if not is_instance_valid(body):
			continue
		var velocity: Vector2 = entry["velocity"]
		var collision := body.move_and_collide(velocity * delta)
		if collision:
			velocity = velocity.bounce(collision.get_normal()).normalized() * BALL_SPEED
			entry["velocity"] = velocity
			var collider := collision.get_collider()
			if collider is StaticBody2D and collider.get_meta("kind", "") == "block":
				var should_absorb := _block_absorbs_ball(collider, collision.get_normal())
				_hit_block(collider)
				if should_absorb:
					_consume_ball(entry)
					continue

		_collect_pickups_at(body.position)
		_activate_ion_powers_at(body)
		if body.position.y > RETURN_Y + 32.0:
			_return_ball(entry)

	if launched_ball_count == ball_count and active_ball_count == 0:
		_finish_volley()

	queue_redraw()


func _hit_block(body: StaticBody2D) -> void:
	var index := int(body.get_meta("block_index", -1))
	if index < 0 or index >= blocks.size():
		return
	var item := blocks[index]
	var block_body: StaticBody2D = item["body"] as StaticBody2D
	if not is_instance_valid(block_body):
		return
	item["hp"] = int(item["hp"]) - 1
	if int(item["hp"]) <= 0:
		block_body.collision_layer = 0
		block_body.queue_free()
		item["body"] = null


func _block_absorbs_ball(body: StaticBody2D, collision_normal: Vector2) -> bool:
	var index := int(body.get_meta("block_index", -1))
	if index < 0 or index >= blocks.size():
		return false
	var item := blocks[index]
	if String(item.get("variant", "normal")) != "black_hole":
		return false
	var absorbing_sides: Array = item.get("absorbing_sides", [])
	return absorbing_sides.has(_collision_side_from_normal(collision_normal))


func _collision_side_from_normal(normal: Vector2) -> String:
	if absf(normal.x) > absf(normal.y):
		return "right" if normal.x > 0.0 else "left"
	return "bottom" if normal.y > 0.0 else "top"


func _consume_ball(entry: Dictionary) -> void:
	if bool(entry["returned"]):
		return
	entry["returned"] = true
	active_ball_count = maxi(0, active_ball_count - 1)
	var body: CharacterBody2D = entry["body"] as CharacterBody2D
	if is_instance_valid(body):
		body.collision_layer = 0
		body.queue_free()
	entry["body"] = null


func _collect_pickups_at(ball_position: Vector2) -> void:
	for pickup in pickups:
		if bool(pickup["collected"]):
			continue
		var pickup_position: Vector2 = pickup["position"]
		if ball_position.distance_to(pickup_position) <= PICKUP_RADIUS + BALL_RADIUS:
			pickup["collected"] = true
			pending_ball_bonus += 1


func _activate_ion_powers_at(ball: CharacterBody2D) -> void:
	var ball_id := ball.get_instance_id()
	for power in ion_powers:
		var power_position: Vector2 = power["position"]
		if ball.position.distance_to(power_position) > ION_BEAM_RADIUS + BALL_RADIUS:
			continue
		var triggered_balls: Dictionary = power["triggered_balls"]
		if triggered_balls.has(ball_id):
			continue
		triggered_balls[ball_id] = true
		power["activated"] = true
		_fire_ion_beam(power_position.y)


func _fire_ion_beam(beam_y: float) -> void:
	ion_beam_effects.append({
		"y": beam_y,
		"elapsed": 0.0
	})
	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		if String(item.get("variant", "normal")) == "phase" and not bool(item.get("phase_active", true)):
			continue
		var block_position: Vector2 = item["position"]
		if absf(block_position.y - beam_y) <= CELL * 0.5:
			_hit_block(body)


func _update_ion_beam_effects(delta: float) -> void:
	var active_effects: Array[Dictionary] = []
	for effect in ion_beam_effects:
		effect["elapsed"] = float(effect["elapsed"]) + delta
		if float(effect["elapsed"]) < ION_BEAM_EFFECT_DURATION:
			active_effects.append(effect)
	ion_beam_effects = active_effects


func _return_ball(entry: Dictionary) -> void:
	var body: CharacterBody2D = entry["body"] as CharacterBody2D
	if not first_return_recorded:
		next_launcher_x = clampf(body.position.x, BOARD_LEFT + BALL_COLLISION_RADIUS, BOARD_RIGHT - BALL_COLLISION_RADIUS)
		first_return_recorded = true
	entry["returned"] = true
	active_ball_count -= 1
	body.queue_free()
	entry["body"] = null


func _finish_volley() -> void:
	_regenerate_surviving_blocks()
	balls.clear()
	launcher.x = next_launcher_x
	launcher.y = RETURN_Y
	ball_count += pending_ball_bonus
	pending_ball_bonus = 0
	_begin_board_advance()


func _regenerate_surviving_blocks() -> void:
	for item in blocks:
		if String(item.get("variant", "normal")) != "regenerative":
			continue
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		var current_hp := int(item["hp"])
		item["hp"] = int(floor(float(current_hp) * REGENERATIVE_GROWTH))


func _begin_board_advance() -> void:
	state = TurnState.ADVANCING
	row_advance_elapsed = 0.0
	_toggle_phase_blocks()

	var remaining_pickups: Array[Dictionary] = []
	for pickup in pickups:
		if not bool(pickup["collected"]):
			remaining_pickups.append(pickup)
	pickups = remaining_pickups

	var remaining_ion_powers: Array[Dictionary] = []
	for power in ion_powers:
		if not bool(power["activated"]):
			remaining_ion_powers.append(power)
	ion_powers = remaining_ion_powers

	turn += 1
	_spawn_row(turn, -1)

	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		item["row"] = int(item["row"]) + 1
		item["move_from"] = body.position
		item["move_to"] = body.position + Vector2(0.0, ROW_STEP)

	for pickup in pickups:
		pickup["row"] = int(pickup["row"]) + 1
		var pickup_position: Vector2 = pickup["position"]
		pickup["move_from"] = pickup_position
		pickup["move_to"] = pickup_position + Vector2(0.0, ROW_STEP)

	for power in ion_powers:
		power["row"] = int(power["row"]) + 1
		var power_position: Vector2 = power["position"]
		power["move_from"] = power_position
		power["move_to"] = power_position + Vector2(0.0, ROW_STEP)


func _toggle_phase_blocks() -> void:
	for item in blocks:
		if String(item.get("variant", "normal")) != "phase":
			continue
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		var is_active := not bool(item.get("phase_active", true))
		item["phase_active"] = is_active
		body.collision_layer = 1 if is_active else 0


func _process_board_advance(delta: float) -> void:
	row_advance_elapsed += delta
	var progress := clampf(row_advance_elapsed / ROW_DROP_DURATION, 0.0, 1.0)
	# Smoothstep gives the row an elevator-like acceleration and soft stop.
	var eased := progress * progress * (3.0 - 2.0 * progress)

	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		var move_from: Vector2 = item["move_from"]
		var move_to: Vector2 = item["move_to"]
		body.position = move_from.lerp(move_to, eased)
		item["position"] = body.position

	for pickup in pickups:
		var move_from: Vector2 = pickup["move_from"]
		var move_to: Vector2 = pickup["move_to"]
		pickup["position"] = move_from.lerp(move_to, eased)

	for power in ion_powers:
		var move_from: Vector2 = power["move_from"]
		var move_to: Vector2 = power["move_to"]
		power["position"] = move_from.lerp(move_to, eased)

	if progress < 1.0:
		return

	var reached_danger := false
	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		item.erase("move_from")
		item.erase("move_to")
		if body.position.y + CELL * 0.5 >= LAUNCH_LINE_Y:
			reached_danger = true

	var visible_pickups: Array[Dictionary] = []
	for pickup in pickups:
		pickup.erase("move_from")
		pickup.erase("move_to")
		var pickup_position: Vector2 = pickup["position"]
		if pickup_position.y < LAUNCH_LINE_Y:
			visible_pickups.append(pickup)
	pickups = visible_pickups

	var visible_ion_powers: Array[Dictionary] = []
	for power in ion_powers:
		power.erase("move_from")
		power.erase("move_to")
		var power_position: Vector2 = power["position"]
		if power_position.y < LAUNCH_LINE_Y:
			visible_ion_powers.append(power)
	ion_powers = visible_ion_powers

	if reached_danger:
		state = TurnState.GAME_OVER
		is_aiming = false
		return

	state = TurnState.AIMING


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), BG)
	_draw_playfield()
	draw_rect(Rect2(0, 0, W, 154), PANEL)
	draw_line(Vector2(24, 154), Vector2(W - 24, 154), MUTED, 2.0)

	_draw_signal_details()
	_draw_header()
	_draw_launch_line()
	_draw_blocks()
	_draw_pickups()
	_draw_ion_powers()
	_draw_ion_beam_effects()

	if state == TurnState.AIMING:
		_draw_launcher()
		if is_aiming:
			_draw_aim_guide()

	_draw_active_balls()
	if state == TurnState.FIRING:
		_draw_recall_button()
	if state == TurnState.GAME_OVER:
		_draw_game_over()


func _draw_playfield() -> void:
	var playfield_bottom := LAUNCH_LINE_Y
	var playfield_rect := Rect2(
		Vector2(BOARD_LEFT, BOARD_TOP),
		Vector2(BOARD_RIGHT - BOARD_LEFT, playfield_bottom - BOARD_TOP)
	)
	draw_rect(playfield_rect, PLAYFIELD_BG, true)
	var wall_color := Color(MUTED, 0.82)
	draw_line(Vector2(BOARD_LEFT, BOARD_TOP), Vector2(BOARD_LEFT, playfield_bottom), wall_color, 3.0, true)
	draw_line(Vector2(BOARD_RIGHT, BOARD_TOP), Vector2(BOARD_RIGHT, playfield_bottom), wall_color, 3.0, true)
	draw_line(Vector2(BOARD_LEFT, BOARD_TOP), Vector2(BOARD_RIGHT, BOARD_TOP), wall_color, 3.0, true)
	# A separate lower area keeps the launch origin visually distinct from the
	# descending block field. This can later be replaced by the final art.
	draw_rect(
		Rect2(Vector2(BOARD_LEFT, LAUNCH_LINE_Y), Vector2(BOARD_RIGHT - BOARD_LEFT, H - LAUNCH_LINE_Y)),
		Color(PANEL, 0.55),
		true
	)


func _draw_active_balls() -> void:
	for entry in balls:
		if bool(entry["returned"]):
			continue
		var body: CharacterBody2D = entry["body"] as CharacterBody2D
		if not is_instance_valid(body):
			continue
		draw_circle(body.position, BALL_RADIUS, AQUA)
		draw_circle(body.position, 4.0, CREAM)


func _draw_aim_guide() -> void:
	var start := launcher + aim_direction * 56.0
	# The guide is intentionally visual-only: it passes over blocks exactly like
	# the reference game, while the launched ball still uses real collisions.
	var guide_length := lerpf(38.0, 980.0, pow(pull_strength, 0.78))
	var dot_radius := lerpf(1.4, 5.2, pull_strength)
	var dot_spacing := lerpf(10.0, 22.0, pull_strength)
	var segment_count := maxi(1, int(round(guide_length / dot_spacing)))

	for index in range(segment_count + 1):
		var distance := guide_length * float(index) / float(segment_count)
		var fade := lerpf(0.96, 0.62, distance / maxf(guide_length, 1.0))
		draw_circle(start + aim_direction * distance, dot_radius, Color(AQUA, fade))


func _draw_header() -> void:
	draw_string(fallback_font, Vector2(34, 66), "RYKO", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, CREAM)
	draw_string(fallback_font, Vector2(34, 108), "PROTOCOL // ENDLESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, AQUA)
	draw_string(fallback_font, Vector2(W - 190, 68), "ROUND %02d" % turn, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, AMBER)
	draw_string(fallback_font, Vector2(W - 190, 108), "BALLS %02d" % ball_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CORAL)


func _draw_signal_details() -> void:
	for i in range(18):
		var x := 28.0 + i * 19.0
		var height := 5.0 + float((i * 7) % 18)
		draw_line(Vector2(x, 138), Vector2(x, 138 - height), Color(AQUA, 0.42), 2.0)
	for p in [Vector2(92, 205), Vector2(615, 218), Vector2(650, 522), Vector2(70, 704), Vector2(630, 902)]:
		draw_circle(p, 2.0, Color(MUTED, 0.55))


func _draw_launch_line() -> void:
	draw_line(
		Vector2(BOARD_LEFT, LAUNCH_LINE_Y),
		Vector2(BOARD_RIGHT, LAUNCH_LINE_Y),
		Color(CREAM, 0.72),
		3.0,
		true
	)


func _draw_blocks() -> void:
	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		var center: Vector2 = item["position"]
		var label_center := center
		var hp := str(item["hp"])
		var variant := String(item.get("variant", "normal"))
		var is_regenerative := variant == "regenerative"
		var is_phase := variant == "phase"
		var phase_active := bool(item.get("phase_active", true))
		var phase_alpha := 1.0 if phase_active else 0.28
		var label_color := CREAM if not is_phase or phase_active else Color(CREAM, 0.38)
		if item["shape"] == "square":
			var rect := Rect2(center - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL))
			var is_dense := variant == "dense"
			var is_black_hole := variant == "black_hole"
			var border_color := AMBER
			if is_dense:
				border_color = AQUA
			elif is_regenerative:
				border_color = REGENERATIVE_GREEN
			elif is_black_hole:
				border_color = VOID_PURPLE
			elif is_phase:
				border_color = Color(PHASE_BLUE, phase_alpha)
			# Draw the border as an outer solid shape plus an inset fill. Unlike a
			# centered stroke, this can never overlap a neighbouring cell.
			draw_rect(rect, border_color, true)
			draw_rect(
				rect.grow(-BLOCK_OUTLINE_WIDTH),
				Color(PANEL, 0.22) if is_phase and not phase_active else PANEL,
				true
			)
			if is_dense:
				var inner_border := rect.grow(-(BLOCK_OUTLINE_WIDTH + 7.0))
				draw_rect(inner_border, AQUA, false, 3.0, true)
				_draw_centered_label("x2", center + Vector2(0.0, -28.0), 13, CORAL)
				label_center.y += 7.0
			elif is_regenerative:
				_draw_centered_label("R", center + Vector2(0.0, -28.0), 13, REGENERATIVE_GREEN)
				label_center.y += 7.0
			elif is_black_hole:
				_draw_black_hole_sides(rect, item.get("absorbing_sides", []))
			elif is_phase:
				_draw_centered_label("P", center + Vector2(0.0, -28.0), 13, Color(PHASE_BLUE, phase_alpha))
				label_center.y += 7.0
		else:
			var local_points := _triangle_local_points(String(item["orientation"]))
			var points := PackedVector2Array()
			var centroid := Vector2.ZERO
			for point in local_points:
				points.append(center + point)
				centroid += point
			centroid /= float(local_points.size())
			label_center = center + centroid
			var inner_local_points := _triangle_inner_local_points(String(item["orientation"]))
			var inner_points := PackedVector2Array()
			for point in inner_local_points:
				inner_points.append(center + point)
			draw_colored_polygon(points, Color(PHASE_BLUE, phase_alpha) if is_phase else CORAL)
			draw_colored_polygon(
				inner_points,
				Color(PANEL, 0.22) if is_phase and not phase_active else PANEL
			)
			if is_phase:
				_draw_centered_label("P", label_center + Vector2(0.0, -24.0), 13, Color(PHASE_BLUE, phase_alpha))
				label_center.y += 7.0
		_draw_centered_label(hp, label_center, 24, label_color)


func _draw_black_hole_sides(rect: Rect2, absorbing_sides: Array) -> void:
	var center := rect.get_center()
	var half_segment := 22.0
	for side_value in absorbing_sides:
		var side := String(side_value)
		var start := Vector2.ZERO
		var end := Vector2.ZERO
		match side:
			"left":
				start = Vector2(rect.position.x + 8.0, center.y - half_segment)
				end = Vector2(rect.position.x + 8.0, center.y + half_segment)
			"right":
				start = Vector2(rect.end.x - 8.0, center.y - half_segment)
				end = Vector2(rect.end.x - 8.0, center.y + half_segment)
			"top":
				start = Vector2(center.x - half_segment, rect.position.y + 8.0)
				end = Vector2(center.x + half_segment, rect.position.y + 8.0)
			"bottom":
				start = Vector2(center.x - half_segment, rect.end.y - 8.0)
				end = Vector2(center.x + half_segment, rect.end.y - 8.0)
			_:
				continue
		draw_line(start, end, VOID_PURPLE, 10.0, true)
		draw_line(start, end, VOID_DARK, 5.0, true)


func _draw_recall_button() -> void:
	var rect := _recall_button_rect()
	draw_rect(rect, Color(PANEL, 0.96), true)
	draw_rect(rect, AQUA, false, 3.0, true)
	var icon_center := Vector2(rect.position.x + 25.0, rect.get_center().y)
	draw_arc(icon_center, 11.0, -PI * 0.65, PI * 0.75, 20, AQUA, 3.0, true)
	var arrow_tip := icon_center + Vector2(-10.0, -7.0)
	draw_colored_polygon(PackedVector2Array([
		arrow_tip,
		arrow_tip + Vector2(10.0, -2.0),
		arrow_tip + Vector2(4.0, 8.0)
	]), AQUA)
	_draw_centered_label("RECALL", Vector2(rect.position.x + 85.0, rect.get_center().y), 16, CREAM)


func _draw_centered_label(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(fallback_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_pickups() -> void:
	for pickup in pickups:
		if bool(pickup["collected"]):
			continue
		var center: Vector2 = pickup["position"]
		draw_circle(center, PICKUP_RADIUS, Color(PANEL, 0.9))
		draw_arc(center, PICKUP_RADIUS, 0.0, TAU, 32, AQUA, 4.0)
		draw_line(center + Vector2(-8, 0), center + Vector2(8, 0), CREAM, 4.0, true)
		draw_line(center + Vector2(0, -8), center + Vector2(0, 8), CREAM, 4.0, true)


func _draw_ion_powers() -> void:
	for power in ion_powers:
		var center: Vector2 = power["position"]
		var color := CORAL if bool(power["activated"]) else ION_BLUE
		draw_circle(center, ION_BEAM_RADIUS, Color(PANEL, 0.92))
		draw_arc(center, ION_BEAM_RADIUS, 0.0, TAU, 32, color, 4.0, true)
		draw_line(center + Vector2(-12.0, 0.0), center + Vector2(12.0, 0.0), color, 5.0, true)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-16.0, 0.0),
			center + Vector2(-8.0, -6.0),
			center + Vector2(-8.0, 6.0)
		]), color)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(16.0, 0.0),
			center + Vector2(8.0, -6.0),
			center + Vector2(8.0, 6.0)
		]), color)


func _draw_ion_beam_effects() -> void:
	for effect in ion_beam_effects:
		var progress := clampf(float(effect["elapsed"]) / ION_BEAM_EFFECT_DURATION, 0.0, 1.0)
		var pulse := sin(progress * PI)
		var fade := 1.0 - progress
		var glow_width := 5.0 + pulse * 17.0
		var beam_y := float(effect["y"])
		# Rectangles are clipped by construction to the exact board width.
		draw_rect(
			Rect2(Vector2(BOARD_LEFT, beam_y - glow_width * 0.5), Vector2(BOARD_RIGHT - BOARD_LEFT, glow_width)),
			Color(ION_BLUE, fade * 0.34),
			true
		)
		draw_rect(
			Rect2(Vector2(BOARD_LEFT, beam_y - 2.0), Vector2(BOARD_RIGHT - BOARD_LEFT, 4.0)),
			Color(CREAM, fade),
			true
		)


func _draw_launcher() -> void:
	draw_circle(launcher, 13.0, Color(PANEL, 1.0))
	draw_arc(launcher, 13.0, 0, TAU, 32, AQUA, 3.0)
	var tip := launcher + aim_direction * 48.0
	var side := aim_direction.orthogonal()
	draw_line(launcher + aim_direction * 12.0, tip, AQUA, 5.0, true)
	draw_line(tip, tip - aim_direction * 14.0 + side * 9.0, AQUA, 4.0, true)
	draw_line(tip, tip - aim_direction * 14.0 - side * 9.0, AQUA, 4.0, true)


func _draw_game_over() -> void:
	draw_rect(Rect2(Vector2(0, 360), Vector2(W, 360)), Color(0.02, 0.07, 0.08, 0.94), true)
	draw_string(fallback_font, Vector2(0, 470), "SIGNAL LOST", HORIZONTAL_ALIGNMENT_CENTER, W, 48, CORAL)
	draw_string(fallback_font, Vector2(0, 535), "ROUND %02d" % turn, HORIZONTAL_ALIGNMENT_CENTER, W, 26, CREAM)
	draw_string(fallback_font, Vector2(0, 610), "TAP TO RESTART", HORIZONTAL_ALIGNMENT_CENTER, W, 20, AQUA)
