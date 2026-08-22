extends Node2D

enum TurnState {
	AIMING,
	FIRING,
	ADVANCING,
	GAME_OVER
}

const W := 720.0
const H := 1280.0
const BOARD_LEFT := 24.0
const BOARD_RIGHT := 696.0
const BOARD_TOP := 176.0
const RETURN_Y := 1165.0
const DANGER_Y := 1080.0
const CELL := 82.0
const TRIANGLE_SIZE := 78.0
const GAP := 10.0
const ROW_STEP := CELL + GAP
const ROW_DROP_DURATION := 0.46
const GRID_X := 43.0
const GRID_Y := 242.0
const COLUMN_COUNT := 7

const MIN_PULL_DISTANCE := 14.0
const MAX_PULL_DISTANCE := 300.0
const RELEASE_PULL_DISTANCE := 48.0
const MIN_UPWARD_COMPONENT := 0.045
const BALL_SPEED := 760.0
const BALL_RADIUS := 8.0
const BALL_LAUNCH_INTERVAL := 0.075
const PICKUP_RADIUS := 19.0
const TRIANGLE_CHANCE := 0.28
const TRIANGLE_ORIENTATIONS := ["top_left", "top_right", "bottom_left", "bottom_right"]

const BG := Color("#08191c")
const PANEL := Color("#0d262a")
const AMBER := Color("#ffb84a")
const AQUA := Color("#56e0d2")
const CORAL := Color("#ff6b5f")
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


func _cell_center(column: int, row: int) -> Vector2:
	return Vector2(GRID_X + column * ROW_STEP + CELL * 0.5, GRID_Y + row * ROW_STEP + CELL * 0.5)


func _spawn_row(hp: int, row: int = 0) -> void:
	var columns := _shuffled_columns()
	var block_count := _block_count_for_turn()

	for index in range(block_count):
		var column := columns[index]
		if turn >= 3 and rng.randf() < TRIANGLE_CHANCE:
			var orientation: String = TRIANGLE_ORIENTATIONS[rng.randi_range(0, TRIANGLE_ORIENTATIONS.size() - 1)]
			_add_triangle_block(column, row, hp, orientation)
		else:
			_add_square_block(column, row, hp)

	var pickup_column := columns[block_count]
	pickups.append({
		"column": pickup_column,
		"row": row,
		"position": _cell_center(pickup_column, row),
		"collected": false
	})


func _block_count_for_turn() -> int:
	if turn <= 4:
		return rng.randi_range(1, 3)
	if turn <= 9:
		return rng.randi_range(2, 4)
	if turn <= 19:
		return rng.randi_range(3, 5)
	return rng.randi_range(4, 6)


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


func _add_square_block(column: int, row: int, hp: int) -> void:
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
		"hp": hp,
		"position": body.position,
		"column": column,
		"row": row,
		"orientation": ""
	})


func _add_triangle_block(column: int, row: int, hp: int, orientation: String) -> void:
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
		"hp": hp,
		"position": body.position,
		"column": column,
		"row": row,
		"orientation": orientation
	})


func _triangle_local_points(orientation: String) -> PackedVector2Array:
	var half := TRIANGLE_SIZE * 0.5
	match orientation:
		"top_right":
			return PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half)])
		"bottom_left":
			return PackedVector2Array([Vector2(-half, -half), Vector2(-half, half), Vector2(half, half)])
		"bottom_right":
			return PackedVector2Array([Vector2(half, -half), Vector2(-half, half), Vector2(half, half)])
		_:
			return PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half)])


func _unhandled_input(event: InputEvent) -> void:
	if state == TurnState.GAME_OVER:
		if event is InputEventScreenTouch and event.pressed:
			_start_new_run()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_new_run()
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
		candidate.y = -MIN_UPWARD_COMPONENT
		candidate = candidate.normalized()

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


func _spawn_volley_ball() -> void:
	var body := CharacterBody2D.new()
	body.position = launcher
	# Balls share the same launch path but must never collide with one another.
	body.collision_layer = 2
	body.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = BALL_RADIUS
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
				_hit_block(collider)

		_collect_pickups_at(body.position)
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


func _collect_pickups_at(ball_position: Vector2) -> void:
	for pickup in pickups:
		if bool(pickup["collected"]):
			continue
		var pickup_position: Vector2 = pickup["position"]
		if ball_position.distance_to(pickup_position) <= PICKUP_RADIUS + BALL_RADIUS:
			pickup["collected"] = true
			pending_ball_bonus += 1


func _return_ball(entry: Dictionary) -> void:
	var body: CharacterBody2D = entry["body"] as CharacterBody2D
	if not first_return_recorded:
		next_launcher_x = clampf(body.position.x, BOARD_LEFT + BALL_RADIUS, BOARD_RIGHT - BALL_RADIUS)
		first_return_recorded = true
	entry["returned"] = true
	active_ball_count -= 1
	body.queue_free()
	entry["body"] = null


func _finish_volley() -> void:
	balls.clear()
	launcher.x = next_launcher_x
	launcher.y = RETURN_Y
	ball_count += pending_ball_bonus
	pending_ball_bonus = 0
	_begin_board_advance()


func _begin_board_advance() -> void:
	state = TurnState.ADVANCING
	row_advance_elapsed = 0.0

	var remaining_pickups: Array[Dictionary] = []
	for pickup in pickups:
		if not bool(pickup["collected"]):
			remaining_pickups.append(pickup)
	pickups = remaining_pickups

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

	if progress < 1.0:
		return

	var reached_danger := false
	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		item.erase("move_from")
		item.erase("move_to")
		if body.position.y + CELL * 0.5 >= DANGER_Y:
			reached_danger = true

	var visible_pickups: Array[Dictionary] = []
	for pickup in pickups:
		pickup.erase("move_from")
		pickup.erase("move_to")
		var pickup_position: Vector2 = pickup["position"]
		if pickup_position.y < DANGER_Y:
			visible_pickups.append(pickup)
	pickups = visible_pickups

	if reached_danger:
		state = TurnState.GAME_OVER
		is_aiming = false
		return

	state = TurnState.AIMING


func _first_aim_hit() -> Vector2:
	var target := launcher + aim_direction * 1600.0
	var query := PhysicsRayQueryParameters2D.create(launcher + aim_direction * 14.0, target)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.has("position"):
		return result["position"]
	return target


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), BG)
	draw_rect(Rect2(0, 0, W, 154), PANEL)
	draw_line(Vector2(24, 154), Vector2(W - 24, 154), MUTED, 2.0)

	_draw_signal_details()
	_draw_header()
	_draw_danger_line()
	_draw_blocks()
	_draw_pickups()

	if state == TurnState.AIMING:
		_draw_launcher()
		if is_aiming:
			_draw_aim_guide()

	_draw_active_balls()
	if state == TurnState.GAME_OVER:
		_draw_game_over()


func _draw_active_balls() -> void:
	for entry in balls:
		if bool(entry["returned"]):
			continue
		var body: CharacterBody2D = entry["body"] as CharacterBody2D
		if not is_instance_valid(body):
			continue
		draw_circle(body.position, 9.0, AQUA)
		draw_circle(body.position, 4.0, CREAM)


func _draw_aim_guide() -> void:
	var start := launcher + aim_direction * 56.0
	var hit := _first_aim_hit()
	var available_length := maxf(0.0, start.distance_to(hit) - 5.0)
	var desired_length := lerpf(38.0, 980.0, pow(pull_strength, 0.78))
	var guide_length := minf(available_length, desired_length)
	var dot_radius := lerpf(1.4, 5.2, pull_strength)
	var dot_spacing := lerpf(10.0, 22.0, pull_strength)
	var distance := 0.0

	while distance <= guide_length:
		var fade := lerpf(0.96, 0.62, distance / maxf(guide_length, 1.0))
		draw_circle(start + aim_direction * distance, dot_radius, Color(AQUA, fade))
		distance += dot_spacing


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


func _draw_danger_line() -> void:
	draw_dashed_line(Vector2(BOARD_LEFT + 8, DANGER_Y), Vector2(BOARD_RIGHT - 8, DANGER_Y), Color(CORAL, 0.55), 2.0, 10.0)
	draw_string(fallback_font, Vector2(32, DANGER_Y - 14), "LIMIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(CORAL, 0.7))


func _draw_blocks() -> void:
	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		var center: Vector2 = item["position"]
		var label_center := center
		var hp := str(item["hp"])
		if item["shape"] == "square":
			var rect := Rect2(center - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL))
			draw_rect(rect, Color(PANEL, 0.72), true)
			draw_rect(rect, AMBER, false, 4.0)
		else:
			var local_points := _triangle_local_points(String(item["orientation"]))
			var points := PackedVector2Array()
			var centroid := Vector2.ZERO
			for point in local_points:
				points.append(center + point)
				centroid += point
			centroid /= float(local_points.size())
			label_center = center + centroid
			draw_colored_polygon(points, Color(PANEL, 0.72))
			var outline := PackedVector2Array([points[0], points[1], points[2], points[0]])
			draw_polyline(outline, CORAL, 4.0, true)
		_draw_centered_label(hp, label_center, 24, CREAM)


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
