extends Node2D

const W := 720.0
const H := 1280.0
const BOARD_LEFT := 24.0
const BOARD_RIGHT := 696.0
const BOARD_TOP := 176.0
const RETURN_Y := 1165.0
const DANGER_Y := 1080.0
const CELL := 82.0
const GAP := 10.0
const GRID_X := 43.0

const BG := Color("#08191c")
const PANEL := Color("#0d262a")
const AMBER := Color("#ffb84a")
const AQUA := Color("#56e0d2")
const CORAL := Color("#ff6b5f")
const MUTED := Color("#55777a")
const CREAM := Color("#f3e7c5")

var launcher := Vector2(W * 0.5, RETURN_Y)
var aim_direction := Vector2(0, -1)
var is_aiming := false
var ball: CharacterBody2D
var ball_velocity := Vector2.ZERO
var ball_active := false
var blocks: Array[Dictionary] = []
var fallback_font: Font


func _ready() -> void:
	fallback_font = ThemeDB.fallback_font
	_create_boundaries()
	_create_ball()
	_create_demo_blocks()
	queue_redraw()


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


func _create_ball() -> void:
	ball = CharacterBody2D.new()
	ball.position = launcher
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	collision.shape = shape
	ball.add_child(collision)
	add_child(ball)


func _create_demo_blocks() -> void:
	_add_square_block(1, 0, 1)
	_add_square_block(4, 0, 1)
	_add_triangle_block(6, 0, 1, "top_left")
	_add_square_block(2, 2, 2)


func _cell_center(column: int, row: int) -> Vector2:
	return Vector2(GRID_X + column * (CELL + GAP) + CELL * 0.5, 242.0 + row * (CELL + GAP) + CELL * 0.5)


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
		"orientation": ""
	})


func _add_triangle_block(column: int, row: int, hp: int, orientation: String) -> void:
	var body := StaticBody2D.new()
	body.position = _cell_center(column, row)
	body.set_meta("kind", "block")
	body.set_meta("block_index", blocks.size())
	var collision := CollisionPolygon2D.new()
	collision.polygon = PackedVector2Array([
		Vector2(-CELL * 0.5, -CELL * 0.5),
		Vector2(CELL * 0.5, -CELL * 0.5),
		Vector2(-CELL * 0.5, CELL * 0.5)
	])
	body.add_child(collision)
	add_child(body)
	blocks.append({
		"body": body,
		"shape": "triangle",
		"hp": hp,
		"position": body.position,
		"orientation": orientation
	})


func _unhandled_input(event: InputEvent) -> void:
	if ball_active:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_update_aim(event.position)
			is_aiming = true
		else:
			if is_aiming:
				_launch()
			is_aiming = false
		queue_redraw()
	elif event is InputEventScreenDrag:
		_update_aim(event.position)
		is_aiming = true
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_update_aim(event.position)
			is_aiming = true
		else:
			if is_aiming:
				_launch()
			is_aiming = false
		queue_redraw()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_aim(event.position)
		is_aiming = true
		queue_redraw()


func _update_aim(pointer: Vector2) -> void:
	var candidate := pointer - launcher
	if candidate.length() < 20.0:
		return
	candidate = candidate.normalized()
	if candidate.y > -0.12:
		candidate.y = -0.12
		candidate = candidate.normalized()
	aim_direction = candidate


func _launch() -> void:
	ball_active = true
	ball_velocity = aim_direction * 760.0


func _physics_process(delta: float) -> void:
	if not ball_active:
		return

	var collision := ball.move_and_collide(ball_velocity * delta)
	if collision:
		ball_velocity = ball_velocity.bounce(collision.get_normal()).normalized() * 760.0
		var collider := collision.get_collider()
		if collider is StaticBody2D and collider.get_meta("kind", "") == "block":
			_hit_block(collider)

	if ball.position.y > RETURN_Y + 32.0:
		_reset_ball()

	queue_redraw()


func _hit_block(body: StaticBody2D) -> void:
	var index := int(body.get_meta("block_index", -1))
	if index < 0 or index >= blocks.size():
		return
	var item := blocks[index]
	if item["body"] == null:
		return
	item["hp"] = int(item["hp"]) - 1
	if int(item["hp"]) <= 0:
		item["body"].queue_free()
		item["body"] = null


func _reset_ball() -> void:
	ball_active = false
	ball_velocity = Vector2.ZERO
	ball.position = launcher
	queue_redraw()


func _first_aim_hit() -> Vector2:
	var target := launcher + aim_direction * 1600.0
	var query := PhysicsRayQueryParameters2D.create(launcher + aim_direction * 14.0, target)
	query.exclude = [ball.get_rid()]
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

	if not ball_active:
		_draw_launcher()
		if is_aiming:
			var hit := _first_aim_hit()
			draw_line(launcher + aim_direction * 20.0, hit, Color(AQUA, 0.68), 3.0, true)

	draw_circle(ball.position, 9.0, AQUA)
	draw_circle(ball.position, 4.0, CREAM)


func _draw_header() -> void:
	draw_string(fallback_font, Vector2(34, 66), "RYKO", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, CREAM)
	draw_string(fallback_font, Vector2(34, 108), "PROTOCOL // TEST SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, AQUA)
	draw_string(fallback_font, Vector2(W - 190, 68), "ROUND 01", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, AMBER)
	draw_string(fallback_font, Vector2(W - 190, 108), "BALLS 01", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CORAL)


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
		if item["body"] == null:
			continue
		var center: Vector2 = item["position"]
		var hp := str(item["hp"])
		if item["shape"] == "square":
			var rect := Rect2(center - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL))
			draw_rect(rect, Color(PANEL, 0.72), true)
			draw_rect(rect, AMBER, false, 4.0)
		else:
			var points := PackedVector2Array([
				center + Vector2(-CELL * 0.5, -CELL * 0.5),
				center + Vector2(CELL * 0.5, -CELL * 0.5),
				center + Vector2(-CELL * 0.5, CELL * 0.5)
			])
			draw_colored_polygon(points, Color(PANEL, 0.72))
			var outline := PackedVector2Array([points[0], points[1], points[2], points[0]])
			draw_polyline(outline, CORAL, 4.0, true)
		var text_size := fallback_font.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		draw_string(fallback_font, center + Vector2(-text_size.x * 0.5, 8), hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, CREAM)


func _draw_launcher() -> void:
	draw_circle(launcher, 13.0, Color(PANEL, 1.0))
	draw_arc(launcher, 13.0, 0, TAU, 32, AQUA, 3.0)
	var tip := launcher + aim_direction * 48.0
	var side := aim_direction.orthogonal()
	draw_line(launcher + aim_direction * 12.0, tip, AQUA, 5.0, true)
	draw_line(tip, tip - aim_direction * 14.0 + side * 9.0, AQUA, 4.0, true)
	draw_line(tip, tip - aim_direction * 14.0 - side * 9.0, AQUA, 4.0, true)
