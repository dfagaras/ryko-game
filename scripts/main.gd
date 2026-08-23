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
# Reserve one complete incoming-row slot below the top frame. New blocks start
# in that slot and descend into row zero without crossing the frame or
# overlapping the previous top row.
const GRID_Y := BOARD_TOP + ROW_STEP
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
const WALL_COLLISION_LAYER := 1
const BALL_COLLISION_LAYER := 2
const BLOCK_COLLISION_LAYER := 4
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
const GHOST_CORE_START_TURN := 8
const GHOST_CORE_RADIUS := 20.0
const SUPERNOVA_CORE_START_TURN := 10
const SUPERNOVA_CORE_RADIUS := 22.0
const SUPERNOVA_BALL_RATIO := 0.20
const SUPERNOVA_EXPLOSION_RADIUS := CELL * 0.75
const SUPERNOVA_EFFECT_DURATION := 0.36
const BLOCK_HIT_FLASH_DURATION := 0.12
const RADIO_CLEAR_DURATION := 0.92
const RADIO_SAMPLE_RATE := 22050
const SETTINGS_PATH := "user://ryko_settings.cfg"
const BACKGROUND_NAMES := [
	"STAR CHART",
	"MISSION LOG",
	"COSMIC BLUEPRINT",
	"ALIEN DOODLES",
	"PAPER NEBULA",
	"SIGNAL NAVIGATION",
	"NEUTRAL PAPER"
]
const BACKGROUND_DISPLAY_ORDER := [6, 0, 1, 2, 3, 4, 5]

const BG := Color("#071419")
const PLAYFIELD_BG := Color("#10262b")
const PANEL := Color("#0c2025")
const AMBER := Color("#e7ae43")
const AQUA := Color("#55b8b1")
const CORAL := Color("#e96b5f")
const DENSE_ORANGE := Color("#d96732")
const REGENERATIVE_GREEN := Color("#55b8b1")
const VOID_PURPLE := Color("#745f98")
const VOID_DARK := Color("#020608")
const PHASE_BLUE := Color("#9477b5")
const ION_BLUE := Color("#55bfe3")
const GHOST_PURPLE := Color("#a184c4")
const NOVA_RED := Color("#ff4058")
const NOVA_ORANGE := Color("#ff8a38")
const MUTED := Color("#6e8584")
const CREAM := Color("#f2e3bb")
const PAPER_FIBER := Color("#b9a984")
const PAPER_SHADOW := Color("#020b0e")

# Full-cell paper illustrations. Geometry, collision borders and HP text remain
# code-driven so the artwork can never alter gameplay alignment or readability.
# Power pickups deliberately render smaller than blocks and keep open board space.
const ICON_BLOCK_DENSE: Texture2D = preload("res://assets/icons/block_dense.png")
const ICON_BLOCK_REGENERATIVE: Texture2D = preload("res://assets/icons/block_regenerative.png")
const ICON_BLOCK_PHASE: Texture2D = preload("res://assets/icons/block_phase.png")
const ICON_BLOCK_BLACK_HOLE: Texture2D = preload("res://assets/icons/block_black_hole.png")
const ICON_POWER_PLUS_ONE: Texture2D = preload("res://assets/icons/power_plus_one.png")
const ICON_POWER_ION: Texture2D = preload("res://assets/icons/power_ion.png")
const ICON_POWER_GHOST: Texture2D = preload("res://assets/icons/power_ghost.png")
const ICON_POWER_SUPERNOVA: Texture2D = preload("res://assets/icons/power_supernova.png")
const LAUNCHER_TEXTURE: Texture2D = preload("res://assets/launcher/retro_cannon.png")
const BACKGROUND_TEXTURES: Array[Texture2D] = [
	preload("res://assets/backgrounds/star_chart.jpg"),
	preload("res://assets/backgrounds/mission_log.jpg"),
	preload("res://assets/backgrounds/cosmic_blueprint.jpg"),
	preload("res://assets/backgrounds/alien_doodles.jpg"),
	preload("res://assets/backgrounds/paper_nebula.jpg"),
	preload("res://assets/backgrounds/signal_navigation.jpg")
]

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
var ghost_cores: Array[Dictionary] = []
var supernova_cores: Array[Dictionary] = []
var supernova_effects: Array[Dictionary] = []
var supernova_charged_count := 0
var menu_open := false
var menu_page := 0
var selected_background := 0
var radio_hit_energy := 0.0
var radio_phase := 0.0
var radio_clear_elapsed := RADIO_CLEAR_DURATION
var field_clear_triggered := false
var radio_audio_player: AudioStreamPlayer
var fallback_font: Font
var rng := RandomNumberGenerator.new()
var run_seed := 0


func _ready() -> void:
	fallback_font = ThemeDB.fallback_font
	_create_radio_audio()
	_load_settings()
	_create_boundaries()
	_start_new_run()


func _create_radio_audio() -> void:
	radio_audio_player = AudioStreamPlayer.new()
	radio_audio_player.name = "RykoRadio"
	radio_audio_player.volume_db = -8.0
	radio_audio_player.stream = _build_happy_radio_chirp()
	add_child(radio_audio_player)


func _build_happy_radio_chirp() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RADIO_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var sample_count := int(RADIO_CLEAR_DURATION * RADIO_SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(RADIO_SAMPLE_RATE)
		var sample := clampf(_happy_radio_sample(time), -0.92, 0.92)
		data.encode_s16(sample_index * 2, int(sample * 32767.0))
	stream.data = data
	return stream


func _happy_radio_sample(time: float) -> float:
	if time < 0.0 or time >= RADIO_CLEAR_DURATION:
		return 0.0
	var step_length := 0.115
	var step := mini(6, int(time / step_length))
	var local_time := fposmod(time, step_length)
	var frequencies := [430.0, 610.0, 790.0, 560.0, 880.0, 1040.0, 720.0]
	var envelope := sin(clampf(local_time / step_length, 0.0, 1.0) * PI)
	var fade_out := clampf((RADIO_CLEAR_DURATION - time) / 0.18, 0.0, 1.0)
	var phase := TAU * float(frequencies[step]) * time
	# A soft square-wave overtone gives Ryko a strange radio voice without
	# imitating an existing film character sound.
	var carrier := sin(phase) * 0.72 + signf(sin(phase * 0.5)) * 0.16
	return carrier * envelope * fade_out


func _update_radio(delta: float) -> void:
	radio_phase = fposmod(radio_phase + delta, TAU)
	radio_hit_energy = move_toward(radio_hit_energy, 0.0, delta * 1.65)
	radio_clear_elapsed = minf(RADIO_CLEAR_DURATION, radio_clear_elapsed + delta)


func _pulse_radio(amount: float = 0.3) -> void:
	radio_hit_energy = minf(1.6, radio_hit_energy + amount)


func _live_block_count() -> int:
	var count := 0
	for item in blocks:
		var body: StaticBody2D = item.get("body") as StaticBody2D
		if is_instance_valid(body) and int(item.get("hp", 0)) > 0:
			count += 1
	return count


func _trigger_field_clear() -> void:
	if field_clear_triggered:
		return
	field_clear_triggered = true
	radio_clear_elapsed = 0.0
	radio_hit_energy = 1.6
	if is_instance_valid(radio_audio_player):
		radio_audio_player.stop()
		radio_audio_player.play()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	selected_background = clampi(int(config.get_value("visual", "background", 0)), 0, BACKGROUND_NAMES.size() - 1)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("visual", "background", selected_background)
	config.save(SETTINGS_PATH)


func _create_boundaries() -> void:
	_add_wall(Vector2(BOARD_LEFT - 12.0, (BOARD_TOP + RETURN_Y) * 0.5), Vector2(24.0, RETURN_Y - BOARD_TOP + 24.0))
	_add_wall(Vector2(BOARD_RIGHT + 12.0, (BOARD_TOP + RETURN_Y) * 0.5), Vector2(24.0, RETURN_Y - BOARD_TOP + 24.0))
	_add_wall(Vector2(W * 0.5, BOARD_TOP - 12.0), Vector2(BOARD_RIGHT - BOARD_LEFT + 48.0, 24.0))


func _add_wall(position: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = position
	wall.collision_layer = WALL_COLLISION_LAYER
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
	radio_hit_energy = 0.0
	radio_clear_elapsed = RADIO_CLEAR_DURATION
	field_clear_triggered = false

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
	ghost_cores.clear()
	supernova_cores.clear()
	supernova_effects.clear()
	supernova_charged_count = 0


func _cell_center(column: int, row: int) -> Vector2:
	return Vector2(GRID_X + column * ROW_STEP + CELL * 0.5, GRID_Y + row * ROW_STEP + CELL * 0.5)


func _spawn_position(column: int, row: int) -> Vector2:
	if row < 0:
		# Incoming content starts fully inside the board, touching the top edge
		# without ever drawing over the header or top frame.
		return Vector2(_cell_center(column, 0).x, BOARD_TOP + CELL * 0.5)
	return _cell_center(column, row)


func _spawn_row(hp: int, row: int = 0) -> void:
	var columns := _shuffled_columns()
	var block_count := _block_count_for_turn()
	var should_spawn_power := turn >= ION_BEAM_START_TURN and rng.randf() < _power_spawn_chance()
	# During this temporary equal-frequency test, reserve one cell for +1 and
	# one for the selected power instead of silently dropping powers on dense rows.
	if should_spawn_power:
		block_count = mini(block_count, COLUMN_COUNT - 2)
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

	# Every powered block is square-only. Triangles deliberately remain normal
	# blocks, which keeps their silhouette and HP placement completely clean.
	var phase_index := -1
	var phase_candidates: Array[int] = []
	for index in square_indices:
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
		"position": _spawn_position(pickup_column, row),
		"collected": false
	})

	# Keep the permanent +1 pickup and add at most one power. Every currently
	# unlocked power has the same selection weight; balancing comes later.
	var next_power_index := block_count + 1
	if should_spawn_power and next_power_index < COLUMN_COUNT:
		var eligible_powers: Array[String] = ["ion"]
		if turn >= GHOST_CORE_START_TURN:
			eligible_powers.append("ghost")
		if turn >= SUPERNOVA_CORE_START_TURN:
			eligible_powers.append("supernova")
		var selected_power := eligible_powers[rng.randi_range(0, eligible_powers.size() - 1)]
		var power_column := columns[next_power_index]
		match selected_power:
			"ion":
				ion_powers.append({
					"column": power_column,
					"row": row,
					"position": _spawn_position(power_column, row),
					"orientation": "horizontal" if rng.randf() < 0.5 else "vertical",
					"activated": false,
					"balls_inside": {}
				})
			"ghost":
				ghost_cores.append({
					"column": power_column,
					"row": row,
					"position": _spawn_position(power_column, row),
					"activated": false
				})
			"supernova":
				supernova_cores.append({
					"column": power_column,
					"row": row,
					"position": _spawn_position(power_column, row),
					"activated": false,
					"pulse_elapsed": SUPERNOVA_EFFECT_DURATION
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


func _power_spawn_chance() -> float:
	if turn < ION_BEAM_START_TURN:
		return 0.0
	if turn < GHOST_CORE_START_TURN:
		return 0.30
	if turn < SUPERNOVA_CORE_START_TURN:
		return 0.38
	return 0.45


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
	body.position = _spawn_position(column, row)
	body.collision_layer = BLOCK_COLLISION_LAYER
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
	body.position = _spawn_position(column, row)
	body.collision_layer = BLOCK_COLLISION_LAYER
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


func _menu_button_rect() -> Rect2:
	return Rect2(Vector2(34.0, 1120.0), Vector2(112.0, 132.0))


func _menu_theme_rect(display_slot: int) -> Rect2:
	var column := display_slot % 2
	var row := display_slot / 2
	return Rect2(Vector2(48.0 + column * 330.0, 140.0 + row * 142.0), Vector2(294.0, 124.0))


func _menu_backgrounds_rect() -> Rect2:
	return Rect2(Vector2(120.0, 230.0), Vector2(480.0, 82.0))


func _menu_restart_rect() -> Rect2:
	return Rect2(Vector2(120.0, 450.0), Vector2(480.0, 82.0))


func _menu_legend_rect() -> Rect2:
	return Rect2(Vector2(120.0, 340.0), Vector2(480.0, 82.0))


func _menu_resume_rect() -> Rect2:
	return Rect2(Vector2(120.0, 560.0), Vector2(480.0, 82.0))


func _legend_back_rect() -> Rect2:
	return Rect2(Vector2(260.0, 1190.0), Vector2(200.0, 58.0))


func _backgrounds_back_rect() -> Rect2:
	return Rect2(Vector2(260.0, 740.0), Vector2(200.0, 58.0))


func _open_menu() -> void:
	menu_open = true
	menu_page = 0
	is_aiming = false
	pull_distance = 0.0
	pull_strength = 0.0
	queue_redraw()


func _handle_menu_press(pointer: Vector2) -> void:
	if menu_page == 1:
		if _legend_back_rect().has_point(pointer):
			menu_page = 0
			queue_redraw()
		return

	if menu_page == 2:
		if _backgrounds_back_rect().has_point(pointer):
			menu_page = 0
			queue_redraw()
			return
		for display_slot in range(BACKGROUND_DISPLAY_ORDER.size()):
			if _menu_theme_rect(display_slot).has_point(pointer):
				selected_background = BACKGROUND_DISPLAY_ORDER[display_slot]
				_save_settings()
				queue_redraw()
				return
		return

	if _menu_backgrounds_rect().has_point(pointer):
		menu_page = 2
		queue_redraw()
	elif _menu_restart_rect().has_point(pointer):
		menu_open = false
		_start_new_run()
	elif _menu_legend_rect().has_point(pointer):
		menu_page = 1
		queue_redraw()
	elif _menu_resume_rect().has_point(pointer):
		menu_open = false
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var pressed_position := Vector2(-1.0, -1.0)
	if event is InputEventScreenTouch and event.pressed:
		pressed_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed_position = event.position

	if menu_open:
		if pressed_position.x >= 0.0:
			_handle_menu_press(pressed_position)
		return

	if pressed_position.x >= 0.0 and _menu_button_rect().has_point(pressed_position):
		_open_menu()
		return

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

	# The radio console is deliberately outside the aiming surface. Its right
	# control is reserved for a future feature and must not accidentally shoot.
	if pressed_position.y >= 1110.0:
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
	supernova_charged_count = 0
	field_clear_triggered = false
	next_launcher_x = launcher.x
	balls.clear()
	queue_redraw()


func _recall_button_rect() -> Rect2:
	return Rect2(Vector2(574.0, 1120.0), Vector2(112.0, 132.0))


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
	body.collision_layer = BALL_COLLISION_LAYER
	body.collision_mask = WALL_COLLISION_LAYER | BLOCK_COLLISION_LAYER
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
		"returned": false,
		"ghost": false,
		"supernova": false,
		"ghost_blocks_inside": {}
	})
	launched_ball_count += 1
	active_ball_count += 1


func _physics_process(delta: float) -> void:
	_update_radio(delta)
	queue_redraw()
	if menu_open:
		return
	_update_ion_beam_effects(delta)
	_update_supernova_effects(delta)
	_update_block_hit_flashes(delta)
	_update_supernova_core_pulses(delta)
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
		var previous_position := body.position
		var collision := body.move_and_collide(velocity * delta)
		if collision:
			velocity = velocity.bounce(collision.get_normal()).normalized() * BALL_SPEED
			entry["velocity"] = velocity
			var collider := collision.get_collider()
			if collider is StaticBody2D and collider.get_meta("kind", "") == "block":
				var should_absorb := _block_absorbs_ball(collider, collision.get_normal())
				if bool(entry.get("supernova", false)):
					_trigger_supernova_explosion(_block_position_from_body(collider))
				else:
					_hit_block(collider)
				if should_absorb:
					_consume_ball(entry)
					continue

		_collect_pickups_at(body.position)
		_activate_ion_powers_at(body)
		_activate_supernova_cores_at(entry)
		_activate_ghost_cores_at(entry)
		_damage_blocks_crossed_by_ghost(entry, previous_position)
		if body.position.y >= RETURN_Y:
			var travel_y := body.position.y - previous_position.y
			if absf(travel_y) > 0.0001:
				var return_fraction := clampf((RETURN_Y - previous_position.y) / travel_y, 0.0, 1.0)
				body.position.x = lerpf(previous_position.x, body.position.x, return_fraction)
			body.position.y = RETURN_Y
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
	_pulse_radio(0.28)
	item["hit_flash"] = BLOCK_HIT_FLASH_DURATION
	item["hp"] = int(item["hp"]) - 1
	if int(item["hp"]) <= 0:
		block_body.collision_layer = 0
		block_body.queue_free()
		item["body"] = null
		if _live_block_count() == 0:
			_trigger_field_clear()


func _block_position_from_body(body: StaticBody2D) -> Vector2:
	var index := int(body.get_meta("block_index", -1))
	if index < 0 or index >= blocks.size():
		return body.position
	return blocks[index]["position"]


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
		var balls_inside: Dictionary = power["balls_inside"]
		if ball.position.distance_to(power_position) > ION_BEAM_RADIUS + BALL_RADIUS:
			balls_inside.erase(ball_id)
			continue
		if balls_inside.has(ball_id):
			continue
		balls_inside[ball_id] = true
		power["activated"] = true
		_fire_ion_beam(power_position, String(power["orientation"]))


func _supernova_charge_limit() -> int:
	return maxi(1, int(floor(float(ball_count) * SUPERNOVA_BALL_RATIO)))


func _supernova_remaining_charges() -> int:
	return maxi(0, _supernova_charge_limit() - supernova_charged_count)


func _activate_supernova_cores_at(entry: Dictionary) -> void:
	if bool(entry.get("supernova", false)) or _supernova_remaining_charges() <= 0:
		return
	var body: CharacterBody2D = entry["body"] as CharacterBody2D
	if not is_instance_valid(body):
		return
	for core in supernova_cores:
		var core_position: Vector2 = core["position"]
		if body.position.distance_to(core_position) > SUPERNOVA_CORE_RADIUS + BALL_RADIUS:
			continue
		entry["supernova"] = true
		supernova_charged_count += 1
		core["activated"] = true
		core["pulse_elapsed"] = 0.0
		return


func _activate_ghost_cores_at(entry: Dictionary) -> void:
	var body: CharacterBody2D = entry["body"] as CharacterBody2D
	if not is_instance_valid(body):
		return
	for core in ghost_cores:
		var core_position: Vector2 = core["position"]
		if body.position.distance_to(core_position) > GHOST_CORE_RADIUS + BALL_RADIUS:
			continue
		core["activated"] = true
		entry["ghost"] = true
		# Ghost balls still collide with the three board walls, but every block
		# and every black-hole side becomes physically transparent.
		body.collision_mask = WALL_COLLISION_LAYER


func _damage_blocks_crossed_by_ghost(entry: Dictionary, previous_position: Vector2) -> void:
	if not bool(entry.get("ghost", false)):
		return
	var body: CharacterBody2D = entry["body"] as CharacterBody2D
	if not is_instance_valid(body):
		return
	var blocks_inside: Dictionary = entry["ghost_blocks_inside"]
	for item in blocks:
		var block_body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(block_body):
			continue
		var block_id := block_body.get_instance_id()
		if String(item.get("variant", "normal")) == "phase" and not bool(item.get("phase_active", true)):
			blocks_inside.erase(block_id)
			continue
		var currently_inside := _ghost_point_overlaps_block(body.position, item)
		var crossed := _ghost_path_crosses_block(previous_position, body.position, item)
		if crossed and not blocks_inside.has(block_id):
			blocks_inside[block_id] = true
			if bool(entry.get("supernova", false)):
				_trigger_supernova_explosion(item["position"])
			else:
				_hit_block(block_body)
		if not currently_inside:
			blocks_inside.erase(block_id)


func _ghost_path_crosses_block(from: Vector2, to: Vector2, item: Dictionary) -> bool:
	var distance := from.distance_to(to)
	var sample_step := maxf(4.0, BALL_RADIUS * 0.6)
	var sample_count := maxi(1, int(ceil(distance / sample_step)))
	for sample_index in range(sample_count + 1):
		var sample_position := from.lerp(to, float(sample_index) / float(sample_count))
		if _ghost_point_overlaps_block(sample_position, item):
			return true
	return false


func _ghost_point_overlaps_block(point: Vector2, item: Dictionary) -> bool:
	var center: Vector2 = item["position"]
	if String(item["shape"]) == "square":
		return Rect2(center - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)).grow(BALL_RADIUS * 0.55).has_point(point)

	var polygon := PackedVector2Array()
	for local_point in _triangle_local_points(String(item["orientation"])):
		polygon.append(center + local_point)
	var probe_distance := BALL_RADIUS * 0.55
	for offset in [
		Vector2.ZERO,
		Vector2(probe_distance, 0.0),
		Vector2(-probe_distance, 0.0),
		Vector2(0.0, probe_distance),
		Vector2(0.0, -probe_distance)
	]:
		if Geometry2D.is_point_in_polygon(point + offset, polygon):
			return true
	return false


func _trigger_supernova_explosion(center: Vector2) -> void:
	supernova_effects.append({
		"position": center,
		"elapsed": 0.0
	})
	# Keep the visual queue bounded during dense late-game volleys.
	if supernova_effects.size() > 48:
		supernova_effects.pop_front()

	var targets: Array[StaticBody2D] = []
	for item in blocks:
		var block_body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(block_body):
			continue
		if String(item.get("variant", "normal")) == "phase" and not bool(item.get("phase_active", true)):
			continue
		if _circle_intersects_block(center, SUPERNOVA_EXPLOSION_RADIUS, item):
			targets.append(block_body)

	for target in targets:
		if is_instance_valid(target):
			_hit_block(target)


func _circle_intersects_block(center: Vector2, radius: float, item: Dictionary) -> bool:
	var block_center: Vector2 = item["position"]
	if String(item["shape"]) == "square":
		var rect := Rect2(block_center - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL))
		var closest := Vector2(
			clampf(center.x, rect.position.x, rect.end.x),
			clampf(center.y, rect.position.y, rect.end.y)
		)
		return center.distance_squared_to(closest) <= radius * radius

	var polygon := PackedVector2Array()
	for local_point in _triangle_local_points(String(item["orientation"])):
		polygon.append(block_center + local_point)
	if Geometry2D.is_point_in_polygon(center, polygon):
		return true
	for point in polygon:
		if center.distance_squared_to(point) <= radius * radius:
			return true
	for index in range(polygon.size()):
		var start := polygon[index]
		var end := polygon[(index + 1) % polygon.size()]
		if _distance_to_segment(center, start, end) <= radius:
			return true
	return false


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func _fire_ion_beam(beam_position: Vector2, orientation: String) -> void:
	ion_beam_effects.append({
		"position": beam_position,
		"orientation": orientation,
		"elapsed": 0.0
	})
	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		if String(item.get("variant", "normal")) == "phase" and not bool(item.get("phase_active", true)):
			continue
		var block_position: Vector2 = item["position"]
		var is_in_beam := false
		if orientation == "vertical":
			is_in_beam = absf(block_position.x - beam_position.x) <= CELL * 0.5
		else:
			is_in_beam = absf(block_position.y - beam_position.y) <= CELL * 0.5
		if is_in_beam:
			_hit_block(body)


func _update_ion_beam_effects(delta: float) -> void:
	var active_effects: Array[Dictionary] = []
	for effect in ion_beam_effects:
		effect["elapsed"] = float(effect["elapsed"]) + delta
		if float(effect["elapsed"]) < ION_BEAM_EFFECT_DURATION:
			active_effects.append(effect)
	ion_beam_effects = active_effects


func _update_supernova_effects(delta: float) -> void:
	var active_effects: Array[Dictionary] = []
	for effect in supernova_effects:
		effect["elapsed"] = float(effect["elapsed"]) + delta
		if float(effect["elapsed"]) < SUPERNOVA_EFFECT_DURATION:
			active_effects.append(effect)
	supernova_effects = active_effects


func _update_block_hit_flashes(delta: float) -> void:
	for item in blocks:
		if float(item.get("hit_flash", 0.0)) > 0.0:
			item["hit_flash"] = maxf(0.0, float(item["hit_flash"]) - delta)


func _update_supernova_core_pulses(delta: float) -> void:
	for core in supernova_cores:
		core["pulse_elapsed"] = minf(
			SUPERNOVA_EFFECT_DURATION,
			float(core.get("pulse_elapsed", SUPERNOVA_EFFECT_DURATION)) + delta
		)


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
	supernova_charged_count = 0
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

	var remaining_ghost_cores: Array[Dictionary] = []
	for core in ghost_cores:
		if not bool(core["activated"]):
			remaining_ghost_cores.append(core)
	ghost_cores = remaining_ghost_cores

	var remaining_supernova_cores: Array[Dictionary] = []
	for core in supernova_cores:
		if not bool(core["activated"]):
			remaining_supernova_cores.append(core)
	supernova_cores = remaining_supernova_cores

	turn += 1
	_spawn_row(turn, -1)

	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		var target_row := int(item["row"]) + 1
		item["row"] = target_row
		item["move_from"] = body.position
		item["move_to"] = _cell_center(int(item["column"]), target_row)

	for pickup in pickups:
		var target_row := int(pickup["row"]) + 1
		pickup["row"] = target_row
		var pickup_position: Vector2 = pickup["position"]
		pickup["move_from"] = pickup_position
		pickup["move_to"] = _cell_center(int(pickup["column"]), target_row)

	for power in ion_powers:
		var target_row := int(power["row"]) + 1
		power["row"] = target_row
		var power_position: Vector2 = power["position"]
		power["move_from"] = power_position
		power["move_to"] = _cell_center(int(power["column"]), target_row)

	for core in ghost_cores:
		var target_row := int(core["row"]) + 1
		core["row"] = target_row
		var core_position: Vector2 = core["position"]
		core["move_from"] = core_position
		core["move_to"] = _cell_center(int(core["column"]), target_row)

	for core in supernova_cores:
		var target_row := int(core["row"]) + 1
		core["row"] = target_row
		var core_position: Vector2 = core["position"]
		core["move_from"] = core_position
		core["move_to"] = _cell_center(int(core["column"]), target_row)


func _toggle_phase_blocks() -> void:
	for item in blocks:
		if String(item.get("variant", "normal")) != "phase":
			continue
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue
		var is_active := not bool(item.get("phase_active", true))
		item["phase_active"] = is_active
		body.collision_layer = BLOCK_COLLISION_LAYER if is_active else 0


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

	for core in ghost_cores:
		var move_from: Vector2 = core["move_from"]
		var move_to: Vector2 = core["move_to"]
		core["position"] = move_from.lerp(move_to, eased)

	for core in supernova_cores:
		var move_from: Vector2 = core["move_from"]
		var move_to: Vector2 = core["move_to"]
		core["position"] = move_from.lerp(move_to, eased)

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

	var visible_ghost_cores: Array[Dictionary] = []
	for core in ghost_cores:
		core.erase("move_from")
		core.erase("move_to")
		var core_position: Vector2 = core["position"]
		if core_position.y < LAUNCH_LINE_Y:
			visible_ghost_cores.append(core)
	ghost_cores = visible_ghost_cores

	var visible_supernova_cores: Array[Dictionary] = []
	for core in supernova_cores:
		core.erase("move_from")
		core.erase("move_to")
		var core_position: Vector2 = core["position"]
		if core_position.y < LAUNCH_LINE_Y:
			visible_supernova_cores.append(core)
	supernova_cores = visible_supernova_cores

	if reached_danger:
		state = TurnState.GAME_OVER
		is_aiming = false
		return

	state = TurnState.AIMING


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), BG)
	_draw_paper_texture(Rect2(Vector2.ZERO, Vector2(W, H)), Color(PAPER_FIBER, 0.055), 96)
	_draw_playfield()
	_draw_header()
	_draw_launch_line()
	_draw_blocks()
	_draw_pickups()
	_draw_ion_powers()
	_draw_ghost_cores()
	_draw_supernova_cores()
	_draw_ion_beam_effects()
	_draw_supernova_effects()

	if state == TurnState.AIMING:
		_draw_launcher()
		if is_aiming:
			_draw_aim_guide()

	_draw_active_balls()
	_draw_footer()
	if state == TurnState.GAME_OVER:
		_draw_game_over()
	if menu_open:
		_draw_menu_overlay()


func _draw_playfield() -> void:
	var playfield_bottom := LAUNCH_LINE_Y
	var playfield_rect := Rect2(
		Vector2(BOARD_LEFT, BOARD_TOP),
		Vector2(BOARD_RIGHT - BOARD_LEFT, playfield_bottom - BOARD_TOP)
	)
	draw_rect(playfield_rect, PLAYFIELD_BG, true)
	_draw_paper_texture(playfield_rect, Color(PAPER_FIBER, 0.07), 72)
	_draw_selected_background(playfield_rect)
	var wall_color := Color(CREAM, 0.78)
	draw_line(Vector2(BOARD_LEFT, BOARD_TOP), Vector2(BOARD_LEFT, playfield_bottom), Color(PAPER_SHADOW, 0.72), 8.0, true)
	draw_line(Vector2(BOARD_RIGHT, BOARD_TOP), Vector2(BOARD_RIGHT, playfield_bottom), Color(PAPER_SHADOW, 0.72), 8.0, true)
	draw_line(Vector2(BOARD_LEFT, BOARD_TOP), Vector2(BOARD_RIGHT, BOARD_TOP), Color(PAPER_SHADOW, 0.72), 8.0, true)
	draw_line(Vector2(BOARD_LEFT, BOARD_TOP), Vector2(BOARD_LEFT, playfield_bottom), wall_color, 3.0, true)
	draw_line(Vector2(BOARD_RIGHT, BOARD_TOP), Vector2(BOARD_RIGHT, playfield_bottom), wall_color, 3.0, true)
	draw_line(Vector2(BOARD_LEFT, BOARD_TOP), Vector2(BOARD_RIGHT, BOARD_TOP), wall_color, 3.0, true)
	# Close the game page visually at the launch line. The footer is a separate
	# physical radio console and does not change any gameplay coordinates.
	draw_line(Vector2(BOARD_LEFT, playfield_bottom), Vector2(BOARD_RIGHT, playfield_bottom), Color(PAPER_SHADOW, 0.72), 8.0, true)


func _draw_paper_texture(area: Rect2, color: Color, sample_count: int) -> void:
	# Deterministic marks keep the paper stable between frames and avoid visual
	# noise that could be mistaken for moving gameplay objects.
	for index in range(sample_count):
		var seed_value := float(index + 1)
		var unit_x := fposmod(sin(seed_value * 12.9898) * 43758.5453, 1.0)
		var unit_y := fposmod(sin(seed_value * 78.233) * 24634.6345, 1.0)
		var start := area.position + Vector2(unit_x * area.size.x, unit_y * area.size.y)
		var fiber_length := 2.0 + float(index % 5) * 1.7
		var direction := Vector2(1.0, 0.18 if index % 2 == 0 else -0.12)
		draw_line(start, start + direction * fiber_length, color, 1.0, true)


func _draw_selected_background(area: Rect2) -> void:
	if selected_background < 0 or selected_background >= BACKGROUND_TEXTURES.size():
		return
	var texture_alpha := 0.82
	if selected_background == 4:
		# The paper nebula is deliberately vivid, so soften it slightly to keep
		# cream HP labels and the dotted trajectory readable over every cloud.
		texture_alpha = 0.70
	draw_texture_rect(
		BACKGROUND_TEXTURES[selected_background],
		area,
		false,
		Color(1.0, 1.0, 1.0, texture_alpha)
	)
	draw_rect(area, Color(BG, 0.10 if selected_background != 4 else 0.16), true)


func _draw_constellation(points: PackedVector2Array, color: Color) -> void:
	for index in range(points.size() - 1):
		draw_line(points[index], points[index + 1], color, 1.2, true)
	for point in points:
		draw_circle(point, 2.2, color)


func _draw_star_chart_background(_area: Rect2) -> void:
	var ink := Color(AMBER, 0.13)
	_draw_constellation(PackedVector2Array([
		Vector2(55, 236), Vector2(83, 214), Vector2(107, 252), Vector2(139, 228), Vector2(157, 270)
	]), ink)
	_draw_constellation(PackedVector2Array([
		Vector2(50, 932), Vector2(79, 954), Vector2(105, 925), Vector2(138, 968)
	]), ink)
	_draw_constellation(PackedVector2Array([
		Vector2(574, 284), Vector2(603, 259), Vector2(632, 302), Vector2(662, 278)
	]), ink)
	draw_arc(Vector2(608, 974), 54.0, PI * 0.82, TAU * 1.10, 28, Color(AQUA, 0.10), 1.5, true)
	draw_arc(Vector2(608, 974), 37.0, PI * 0.74, TAU * 1.14, 28, Color(CREAM, 0.09), 1.2, true)
	draw_arc(Vector2(100, 350), 48.0, PI * 0.80, TAU * 1.08, 24, Color(CREAM, 0.08), 1.2, true)


func _draw_mission_log_background(_area: Rect2) -> void:
	var note := Color(CREAM, 0.105)
	var aqua_note := Color(AQUA, 0.095)
	draw_string(fallback_font, Vector2(48, 230), "LOG 3173", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, note)
	draw_string(fallback_font, Vector2(48, 250), "R.Y.K.O.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, note)
	draw_string(fallback_font, Vector2(48, 270), "ENDLESS TEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, note)
	draw_string(fallback_font, Vector2(48, 772), "COURSE 214°", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, aqua_note)
	draw_string(fallback_font, Vector2(48, 792), "ΔV 2.73", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, aqua_note)
	draw_string(fallback_font, Vector2(575, 228), "REV. 2.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, note)
	draw_arc(Vector2(607, 292), 34.0, 0.0, TAU, 30, note, 1.4, true)
	draw_arc(Vector2(607, 292), 25.0, 0.0, TAU, 26, note, 1.0, true)
	draw_line(Vector2(579, 292), Vector2(635, 292), note, 1.0, true)
	draw_line(Vector2(607, 264), Vector2(607, 320), note, 1.0, true)
	draw_rect(Rect2(48, 824, 76, 36), note, false, 1.2, true)
	draw_string(fallback_font, Vector2(59, 848), "FUEL OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, note)


func _draw_blueprint_background(area: Rect2) -> void:
	var ink := Color(AQUA, 0.105)
	draw_rect(area.grow(-18.0), ink, false, 1.0, true)
	for corner in [Vector2(92, 300), Vector2(625, 292), Vector2(94, 972), Vector2(623, 974)]:
		draw_arc(corner, 58.0, 0.0, TAU, 36, ink, 1.0, true)
		draw_arc(corner, 37.0, 0.0, TAU, 32, ink, 1.0, true)
		draw_line(corner - Vector2(67, 0), corner + Vector2(67, 0), ink, 1.0, true)
		draw_line(corner - Vector2(0, 67), corner + Vector2(0, 67), ink, 1.0, true)
	for y in range(220, 1030, 80):
		draw_line(Vector2(35, y), Vector2(45, y), ink, 1.0, true)
		draw_line(Vector2(675, y), Vector2(685, y), ink, 1.0, true)
	draw_string(fallback_font, Vector2(585, 360), "X:+27.4", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	draw_string(fallback_font, Vector2(585, 378), "Y:-18.6", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)


func _draw_alien_doodle_background(_area: Rect2) -> void:
	var ink := Color(AMBER, 0.13)
	var aqua_ink := Color(AQUA, 0.10)
	# Small UFO and alien glyphs stay on the margins so they cannot be read as pickups.
	_draw_ellipse(Vector2(85, 260), Vector2(31, 10), ink, 1.4, 28)
	draw_arc(Vector2(85, 255), 14.0, PI, TAU, 18, ink, 1.4, true)
	draw_line(Vector2(57, 274), Vector2(48, 284), ink, 1.0, true)
	draw_line(Vector2(113, 274), Vector2(122, 284), ink, 1.0, true)
	for index in range(5):
		var center := Vector2(58, 410 + index * 82)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -11), center + Vector2(10, 0), center + Vector2(0, 11), center + Vector2(-10, 0)
		]), Color(AQUA, 0.055))
		draw_arc(center, 11.0, 0.0, TAU, 20, aqua_ink, 1.0, true)
	for index in range(4):
		var x := 568.0 + index * 26.0
		draw_line(Vector2(x, 232), Vector2(x + 10, 250), ink, 1.3, true)
		draw_line(Vector2(x + 10, 250), Vector2(x, 268), ink, 1.3, true)
	_draw_doodle_planet(Vector2(610, 925), 32.0, Color(AMBER, 0.12))
	_draw_doodle_star(Vector2(636, 800), 10.0, Color(AQUA, 0.10))


func _draw_deep_space_background(_area: Rect2) -> void:
	# Overlapping translucent ink washes create a printed nebula without glow or photography.
	for index in range(14):
		var center := Vector2(92.0 + float((index * 47) % 530), 230.0 + float((index * 83) % 760))
		var radius := 42.0 + float(index % 4) * 19.0
		var color := Color(AQUA, 0.018 + float(index % 3) * 0.008)
		if index % 3 == 1:
			color = Color(PHASE_BLUE, 0.020 + float(index % 2) * 0.009)
		elif index % 3 == 2:
			color = Color(CORAL, 0.014)
		draw_circle(center, radius, color)
	for point in [Vector2(63, 250), Vector2(146, 315), Vector2(622, 238), Vector2(657, 522), Vector2(92, 872), Vector2(581, 963)]:
		_draw_doodle_star(point, 4.0, Color(CREAM, 0.12))


func _draw_signal_navigation_background(_area: Rect2) -> void:
	var ink := Color(AQUA, 0.115)
	var amber_ink := Color(AMBER, 0.105)
	draw_string(fallback_font, Vector2(48, 228), "SIGNAL LOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	var waveform := PackedVector2Array([
		Vector2(48, 258), Vector2(65, 258), Vector2(72, 246), Vector2(79, 276),
		Vector2(88, 238), Vector2(98, 270), Vector2(108, 252), Vector2(123, 258), Vector2(154, 258)
	])
	draw_polyline(waveform, ink, 1.4, true)
	draw_string(fallback_font, Vector2(575, 228), "FREQ:7.38", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	draw_string(fallback_font, Vector2(575, 248), "GAIN:2.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	draw_arc(Vector2(103, 956), 66.0, PI, TAU * 1.22, 32, ink, 1.2, true)
	draw_arc(Vector2(103, 956), 44.0, PI, TAU * 1.22, 28, ink, 1.0, true)
	draw_line(Vector2(103, 956), Vector2(152, 912), ink, 1.0, true)
	draw_string(fallback_font, Vector2(574, 880), "COORD.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, amber_ink)
	draw_string(fallback_font, Vector2(574, 900), "X:+27.4", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, amber_ink)
	draw_string(fallback_font, Vector2(574, 920), "Y:-18.6", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, amber_ink)


func _draw_cosmic_doodles() -> void:
	var doodle_color := Color(CREAM, 0.32)
	_draw_doodle_star(Vector2(48.0, 111.0), 7.0, doodle_color)
	_draw_doodle_star(Vector2(W - 48.0, 110.0), 6.0, doodle_color)
	_draw_doodle_planet(Vector2(82.0, H - 72.0), 24.0, Color(CREAM, 0.26))
	draw_arc(Vector2(W - 72.0, H - 76.0), 20.0, 0.0, TAU * 0.84, 24, Color(AQUA, 0.24), 2.0, true)
	draw_arc(Vector2(W - 72.0, H - 76.0), 10.0, PI * 0.35, TAU, 20, Color(CREAM, 0.22), 1.5, true)


func _draw_doodle_star(center: Vector2, radius: float, color: Color) -> void:
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), color, 1.5, true)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), color, 1.5, true)
	draw_line(center + Vector2(-radius * 0.55, -radius * 0.55), center + Vector2(radius * 0.55, radius * 0.55), color, 1.0, true)
	draw_line(center + Vector2(radius * 0.55, -radius * 0.55), center + Vector2(-radius * 0.55, radius * 0.55), color, 1.0, true)


func _draw_doodle_planet(center: Vector2, radius: float, color: Color) -> void:
	draw_arc(center, radius * 0.62, 0.0, TAU, 28, color, 1.5, true)
	draw_arc(center, radius, PI * 0.86, PI * 1.86, 24, color, 1.5, true)
	draw_arc(center, radius, -PI * 0.14, PI * 0.86, 24, color, 1.5, true)


func _draw_active_balls() -> void:
	for entry in balls:
		if bool(entry["returned"]):
			continue
		var body: CharacterBody2D = entry["body"] as CharacterBody2D
		if not is_instance_valid(body):
			continue
		var is_ghost := bool(entry.get("ghost", false))
		var is_supernova := bool(entry.get("supernova", false))
		var velocity: Vector2 = entry["velocity"]
		var trail_end := body.position - velocity.normalized() * 24.0
		if is_ghost and is_supernova:
			draw_line(trail_end, body.position, Color(GHOST_PURPLE, 0.30), 9.0, true)
			draw_line(trail_end, body.position, Color(NOVA_ORANGE, 0.58), 4.0, true)
			draw_circle(body.position, BALL_RADIUS + 2.0, Color(GHOST_PURPLE, 0.30))
			draw_arc(body.position, BALL_RADIUS + 1.0, 0.0, TAU, 24, Color(NOVA_RED, 0.90), 3.0, true)
			draw_circle(body.position, 4.0, Color(CREAM, 0.88))
		elif is_ghost:
			draw_line(trail_end, body.position, Color(GHOST_PURPLE, 0.28), 6.0, true)
			draw_circle(body.position, BALL_RADIUS, Color(GHOST_PURPLE, 0.42))
			draw_arc(body.position, BALL_RADIUS, 0.0, TAU, 24, Color(CREAM, 0.78), 2.0, true)
			draw_circle(body.position, 3.0, Color(CREAM, 0.62))
		elif is_supernova:
			draw_line(trail_end, body.position, Color(NOVA_ORANGE, 0.46), 7.0, true)
			draw_circle(body.position, BALL_RADIUS + 3.0, Color(NOVA_RED, 0.18))
			draw_circle(body.position, BALL_RADIUS, NOVA_RED)
			draw_circle(body.position, 4.0, CREAM)
		else:
			draw_circle(body.position, BALL_RADIUS, AQUA)
			draw_circle(body.position, 4.0, CREAM)


func _draw_aim_guide() -> void:
	# The guide is intentionally visual-only: it passes over blocks exactly like
	# the reference game, while stopping at the first board wall. No reflected
	# trajectory is shown after that contact.
	var dot_radius := lerpf(1.4, 5.2, pull_strength)
	var start_offset := 56.0
	var edge_distance := _distance_to_board_edge(launcher, aim_direction)
	if edge_distance <= start_offset + dot_radius:
		return
	var start := launcher + aim_direction * start_offset
	var requested_length := lerpf(38.0, 980.0, pow(pull_strength, 0.78))
	var guide_length := minf(requested_length, edge_distance - start_offset - dot_radius)
	var dot_spacing := lerpf(10.0, 22.0, pull_strength)
	var segment_count := maxi(1, int(round(guide_length / dot_spacing)))

	for index in range(segment_count + 1):
		var distance := guide_length * float(index) / float(segment_count)
		var fade := lerpf(0.96, 0.62, distance / maxf(guide_length, 1.0))
		draw_circle(start + aim_direction * distance, dot_radius, Color(AQUA, fade))


func _distance_to_board_edge(origin: Vector2, direction: Vector2) -> float:
	var distance := 1000000.0
	if direction.x < -0.0001:
		distance = minf(distance, (BOARD_LEFT - origin.x) / direction.x)
	elif direction.x > 0.0001:
		distance = minf(distance, (BOARD_RIGHT - origin.x) / direction.x)
	if direction.y < -0.0001:
		distance = minf(distance, (BOARD_TOP - origin.y) / direction.y)
	elif direction.y > 0.0001:
		distance = minf(distance, (LAUNCH_LINE_Y - origin.y) / direction.y)
	return maxf(0.0, distance)


func _draw_header() -> void:
	var rect := Rect2(BOARD_LEFT, 18.0, BOARD_RIGHT - BOARD_LEFT, 136.0)
	_draw_panel_frame(rect, Color(PANEL, 0.985), Color(CREAM, 0.78), 3.0)
	draw_line(Vector2(rect.position.x + 16.0, 126.0), Vector2(rect.end.x - 16.0, 126.0), Color(MUTED, 0.52), 1.0, true)
	draw_string(fallback_font, Vector2(48.0, 50.0), "ROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CREAM, 0.62))
	_draw_alien_number(str(turn), Vector2(89.0, 88.0), 38.0, AMBER, 3.4)
	_draw_centered_label("RYKO", Vector2(W * 0.5, 51.0), 25, CREAM)
	_draw_centered_label("ENDLESS // SECTOR %02d" % maxi(1, int(ceil(float(turn) / 10.0))), Vector2(W * 0.5, 87.0), 12, Color(AQUA, 0.88))
	draw_string(fallback_font, Vector2(W - 132.0, 50.0), "BALLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CREAM, 0.62))
	_draw_alien_number(str(ball_count), Vector2(W - 86.0, 88.0), 38.0, CORAL, 3.4)
	_draw_centered_label("COSMIC NOTE // %04d" % (run_seed % 10000), Vector2(W * 0.5, 139.0), 10, Color(CREAM, 0.42))


func _draw_signal_details() -> void:
	for index in range(9):
		var angle := TAU * float(index) / 9.0
		var point := Vector2(W * 0.5, 50.0) + Vector2(cos(angle), sin(angle)) * 94.0
		draw_circle(point, 1.5, Color(CREAM, 0.26))
	for point in [Vector2(48, 214), Vector2(666, 238), Vector2(54, 552), Vector2(662, 784), Vector2(48, 944)]:
		draw_circle(point, 1.8, Color(PAPER_FIBER, 0.30))


func _draw_launch_line() -> void:
	draw_line(
		Vector2(BOARD_LEFT, LAUNCH_LINE_Y + 3.0),
		Vector2(BOARD_RIGHT, LAUNCH_LINE_Y + 3.0),
		Color(PAPER_SHADOW, 0.76),
		6.0,
		true
	)
	draw_line(
		Vector2(BOARD_LEFT, LAUNCH_LINE_Y),
		Vector2(BOARD_RIGHT, LAUNCH_LINE_Y),
		Color(CREAM, 0.82),
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
		var hit_flash_ratio := clampf(float(item.get("hit_flash", 0.0)) / BLOCK_HIT_FLASH_DURATION, 0.0, 1.0)
		var label_color := CREAM if not is_phase or phase_active else Color(CREAM, 0.38)
		if item["shape"] == "square":
			var rect := Rect2(center - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL))
			var is_dense := variant == "dense"
			var is_black_hole := variant == "black_hole"
			var border_color := AMBER
			if is_dense:
				border_color = DENSE_ORANGE
			elif is_regenerative:
				border_color = REGENERATIVE_GREEN
			elif is_black_hole:
				border_color = VOID_PURPLE
			elif is_phase:
				border_color = Color(PHASE_BLUE, phase_alpha)
			border_color = border_color.lerp(CREAM, hit_flash_ratio)
			# Draw the border as an outer solid shape plus an inset fill. Unlike a
			# centered stroke, this can never overlap a neighbouring cell.
			draw_rect(rect, border_color, true)
			var square_fill := PANEL.lerp(border_color, 0.18)
			if is_black_hole:
				square_fill = VOID_DARK.lerp(VOID_PURPLE, 0.10)
			elif is_phase and not phase_active:
				square_fill = PLAYFIELD_BG.lerp(PHASE_BLUE, 0.08)
			draw_rect(
				rect.grow(-BLOCK_OUTLINE_WIDTH),
				square_fill.lerp(CREAM, hit_flash_ratio * 0.32),
				true
			)
			if is_dense:
				_draw_cell_texture(ICON_BLOCK_DENSE, rect)
			elif is_regenerative:
				_draw_cell_texture(ICON_BLOCK_REGENERATIVE, rect)
			elif is_black_hole:
				_draw_cell_texture(ICON_BLOCK_BLACK_HOLE, rect)
				_draw_black_hole_sides(rect, item.get("absorbing_sides", []))
			elif is_phase:
				_draw_cell_texture(ICON_BLOCK_PHASE, rect, phase_alpha)
			# Special artwork fills the complete cell. Apply the collision flash
			# afterwards so it stays visible without hiding the HP label.
			if variant != "normal" and hit_flash_ratio > 0.0:
				draw_rect(rect, Color(CREAM, hit_flash_ratio * 0.25), true)
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
			var triangle_border := CORAL
			triangle_border = triangle_border.lerp(CREAM, hit_flash_ratio)
			var triangle_fill := PANEL.lerp(triangle_border, 0.18)
			draw_colored_polygon(points, triangle_border)
			draw_colored_polygon(
				inner_points,
				triangle_fill.lerp(CREAM, hit_flash_ratio * 0.32)
			)
		_draw_alien_number(hp, label_center, 30.0, label_color, 3.0)


func _draw_cell_texture(texture: Texture2D, rect: Rect2, alpha: float = 1.0) -> void:
	draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, alpha))


func _draw_black_hole_sides(rect: Rect2, absorbing_sides: Array) -> void:
	var center := rect.get_center()
	for side_value in absorbing_sides:
		var side := String(side_value)
		var arrow_tip := Vector2.ZERO
		var inward := Vector2.ZERO
		match side:
			"left":
				arrow_tip = Vector2(rect.position.x + 16.0, center.y)
				inward = Vector2.RIGHT
			"right":
				arrow_tip = Vector2(rect.end.x - 16.0, center.y)
				inward = Vector2.LEFT
			"top":
				arrow_tip = Vector2(center.x, rect.position.y + 16.0)
				inward = Vector2.DOWN
			"bottom":
				arrow_tip = Vector2(center.x, rect.end.y - 16.0)
				inward = Vector2.UP
			_:
				continue
		var side_vector := inward.rotated(PI * 0.5)
		draw_colored_polygon(PackedVector2Array([
			arrow_tip + inward * 8.0,
			arrow_tip - inward * 4.0 + side_vector * 6.0,
			arrow_tip - inward * 4.0 - side_vector * 6.0
		]), CORAL)
		draw_circle(arrow_tip - inward * 10.0, 2.5, Color(CREAM, 0.62))


func _draw_panel_frame(rect: Rect2, fill: Color, border: Color, width: float) -> void:
	draw_rect(Rect2(rect.position + Vector2(0.0, 4.0), rect.size), Color(PAPER_SHADOW, 0.76), true)
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, width, true)
	draw_rect(rect.grow(-7.0), Color(border, 0.16), false, 1.0, true)


func _draw_footer() -> void:
	var footer := Rect2(BOARD_LEFT, 1110.0, BOARD_RIGHT - BOARD_LEFT, 152.0)
	_draw_panel_frame(footer, Color(PANEL, 0.99), Color(CREAM, 0.72), 3.0)
	_draw_footer_menu_control()
	_draw_radio_console(Rect2(154.0, 1122.0, 412.0, 120.0))
	_draw_footer_recall_control()


func _draw_footer_menu_control() -> void:
	var rect := _menu_button_rect()
	var center := Vector2(rect.get_center().x, 1179.0)
	draw_circle(center + Vector2(0.0, 3.0), 29.0, Color(PAPER_SHADOW, 0.72))
	draw_circle(center, 27.0, Color(PLAYFIELD_BG, 0.98))
	draw_arc(center, 27.0, 0.0, TAU, 36, Color(CREAM, 0.55), 2.4, true)
	for offset in [-8.0, 0.0, 8.0]:
		draw_line(center + Vector2(-10.0, offset), center + Vector2(10.0, offset), AQUA, 2.8, true)
	_draw_centered_label("MENU", Vector2(center.x, 1227.0), 11, Color(CREAM, 0.76))


func _draw_footer_recall_control() -> void:
	var rect := _recall_button_rect()
	var center := Vector2(rect.get_center().x, 1179.0)
	var enabled := state == TurnState.FIRING
	var accent := AQUA if enabled else Color(MUTED, 0.38)
	draw_circle(center + Vector2(0.0, 3.0), 29.0, Color(PAPER_SHADOW, 0.72))
	draw_circle(center, 27.0, Color(PLAYFIELD_BG, 0.98))
	draw_arc(center, 27.0, 0.0, TAU, 36, Color(CREAM, 0.48), 2.4, true)
	draw_arc(center, 13.0, -PI * 0.72, PI * 0.72, 24, accent, 3.0, true)
	var tip := center + Vector2(-11.0, -9.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(10.0, 0.0), tip + Vector2(4.0, 9.0)]), accent)
	_draw_centered_label("RECALL", Vector2(center.x, 1227.0), 11, Color(CREAM, 0.76 if enabled else 0.34))


func _draw_radio_console(rect: Rect2) -> void:
	draw_rect(rect, Color(BG, 0.64), true)
	draw_rect(rect, Color(CREAM, 0.38), false, 1.5, true)
	_draw_centered_label("RADIO", Vector2(rect.get_center().x, rect.position.y + 16.0), 11, Color(CREAM, 0.74))
	# Speaker grille, kept visually weighted to the left as in the approved board.
	var speaker_center := Vector2(rect.position.x + 48.0, rect.position.y + 66.0)
	draw_circle(speaker_center, 30.0, Color(PLAYFIELD_BG, 0.96))
	draw_arc(speaker_center, 30.0, 0.0, TAU, 36, Color(CREAM, 0.42), 2.0, true)
	for y_offset in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		var half_width := sqrt(maxf(0.0, 25.0 * 25.0 - y_offset * y_offset))
		draw_line(speaker_center + Vector2(-half_width, y_offset), speaker_center + Vector2(half_width, y_offset), Color(AQUA, 0.48), 1.5, true)
	var wave_rect := Rect2(rect.position + Vector2(91.0, 40.0), Vector2(231.0, 48.0))
	_draw_radio_waveform(wave_rect)
	var status := "READY"
	if radio_clear_elapsed < RADIO_CLEAR_DURATION:
		status = "FIELD CLEAR"
	elif state == TurnState.FIRING:
		status = "%02d / %02d SIGNALS" % [launched_ball_count, ball_count]
	elif state == TurnState.ADVANCING:
		status = "ROW SHIFT"
	_draw_centered_label(status, Vector2(wave_rect.get_center().x, rect.position.y + 103.0), 9, Color(AQUA, 0.72))
	# Reserved physical control: visible and tactile, intentionally non-functional.
	var knob_center := Vector2(rect.end.x - 39.0, rect.position.y + 66.0)
	draw_circle(knob_center + Vector2(0.0, 3.0), 25.0, Color(PAPER_SHADOW, 0.72))
	draw_circle(knob_center, 24.0, Color(PLAYFIELD_BG, 1.0))
	draw_arc(knob_center, 24.0, 0.0, TAU, 32, Color(AMBER, 0.68), 2.4, true)
	draw_arc(knob_center, 13.0, 0.0, TAU, 28, Color(CREAM, 0.52), 2.0, true)
	draw_line(knob_center, knob_center + Vector2(0.0, -11.0), AMBER, 2.5, true)
	draw_circle(knob_center + Vector2(20.0, -24.0), 2.8, Color(CORAL, 0.88))


func _draw_radio_waveform(rect: Rect2) -> void:
	draw_line(Vector2(rect.position.x, rect.get_center().y), Vector2(rect.end.x, rect.get_center().y), Color(CREAM, 0.12), 1.0, true)
	var points := PackedVector2Array()
	var point_count := 58
	var clear_active := radio_clear_elapsed < RADIO_CLEAR_DURATION
	for index in range(point_count):
		var ratio := float(index) / float(point_count - 1)
		var history := (1.0 - ratio) * 0.20
		var idle := sin(radio_phase * 1.7 + ratio * TAU * 2.0) * 1.6
		var hit := sin(radio_phase * 5.2 + ratio * TAU * 7.0) * radio_hit_energy * 8.5
		var clear_signal := 0.0
		if clear_active:
			clear_signal = _happy_radio_sample(radio_clear_elapsed - history) * 17.0
		var y := rect.get_center().y - idle - hit - clear_signal
		points.append(Vector2(lerpf(rect.position.x, rect.end.x, ratio), y))
	var color := AQUA
	if clear_active:
		color = AMBER.lerp(CORAL, 0.35 + sin(radio_phase * 2.0) * 0.15)
	elif radio_hit_energy > 0.18:
		color = AQUA.lerp(AMBER, minf(0.68, radio_hit_energy * 0.42))
	draw_polyline(points, color, 2.4, true)


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


func _draw_menu_button() -> void:
	var rect := _menu_button_rect()
	draw_rect(rect, Color(PANEL, 0.96), true)
	draw_rect(rect, Color(CREAM, 0.52), false, 2.0, true)
	var icon_center := Vector2(rect.position.x + 27.0, rect.get_center().y)
	for offset in [-9.0, 0.0, 9.0]:
		draw_line(icon_center + Vector2(-9.0, offset), icon_center + Vector2(9.0, offset), AQUA, 2.5, true)
	_draw_centered_label("MENU", Vector2(rect.position.x + 86.0, rect.get_center().y), 16, CREAM)


func _draw_menu_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(BG, 0.965), true)
	var panel := Rect2(24.0, 24.0, W - 48.0, H - 48.0)
	draw_rect(panel, Color(PANEL, 0.985), true)
	draw_rect(panel, Color(CREAM, 0.76), false, 3.0, true)
	_draw_paper_texture(panel.grow(-4.0), Color(PAPER_FIBER, 0.065), 84)

	if menu_page == 1:
		_draw_legend_page()
		return
	if menu_page == 2:
		_draw_backgrounds_page()
		return

	_draw_centered_label("RYKO MENU", Vector2(W * 0.5, 68.0), 28, CREAM)
	_draw_centered_label("MISSION CONTROL", Vector2(W * 0.5, 111.0), 14, Color(AQUA, 0.90))
	_draw_menu_action_button(_menu_backgrounds_rect(), "BACKGROUNDS", PHASE_BLUE)
	_draw_centered_label(BACKGROUND_NAMES[selected_background], Vector2(W * 0.5, 324.0), 11, Color(CREAM, 0.52))
	_draw_menu_action_button(_menu_restart_rect(), "RESTART", CORAL)
	_draw_menu_action_button(_menu_legend_rect(), "LEGEND", AMBER)
	_draw_menu_action_button(_menu_resume_rect(), "RESUME", AQUA)
	_draw_centered_label("SETTINGS ARE SAVED ON THIS DEVICE", Vector2(W * 0.5, 690.0), 11, Color(CREAM, 0.54))
	_draw_menu_mission_notes()


func _draw_backgrounds_page() -> void:
	_draw_centered_label("BACKGROUNDS", Vector2(W * 0.5, 67.0), 28, CREAM)
	_draw_centered_label("SELECT NIGHT SKY PAPER", Vector2(W * 0.5, 108.0), 14, Color(AQUA, 0.90))
	for display_slot in range(BACKGROUND_DISPLAY_ORDER.size()):
		_draw_theme_card(display_slot, BACKGROUND_DISPLAY_ORDER[display_slot])
	_draw_menu_action_button(_backgrounds_back_rect(), "BACK", AQUA)
	_draw_centered_label("SELECTION IS SAVED ON THIS DEVICE", Vector2(W * 0.5, 825.0), 11, Color(CREAM, 0.54))


func _draw_theme_card(display_slot: int, index: int) -> void:
	var rect := _menu_theme_rect(display_slot)
	var selected := index == selected_background
	draw_rect(rect, Color(PLAYFIELD_BG, 0.96), true)
	draw_rect(rect, AQUA if selected else Color(CREAM, 0.48), false, 4.0 if selected else 2.0, true)
	var preview_rect := Rect2(rect.position + Vector2(10.0, 9.0), Vector2(76.0, 106.0))
	if index < BACKGROUND_TEXTURES.size():
		draw_texture_rect(BACKGROUND_TEXTURES[index], preview_rect, false, Color(1.0, 1.0, 1.0, 0.96))
	else:
		draw_rect(preview_rect, PLAYFIELD_BG, true)
	draw_rect(preview_rect, Color(CREAM, 0.36), false, 1.5, true)
	var label_center_x := rect.position.x + 190.0
	_draw_centered_label("%02d" % [display_slot + 1], Vector2(label_center_x, rect.position.y + 32.0), 16, AMBER)
	_draw_centered_label(BACKGROUND_NAMES[index], Vector2(label_center_x, rect.position.y + 62.0), 11, CREAM)
	_draw_centered_label("SELECTED" if selected else "TAP TO SELECT", Vector2(label_center_x, rect.position.y + 94.0), 9, AQUA if selected else Color(CREAM, 0.48))


func _draw_menu_action_button(rect: Rect2, label: String, accent: Color) -> void:
	draw_rect(rect, Color(PLAYFIELD_BG, 0.98), true)
	draw_rect(rect, accent, false, 3.0, true)
	_draw_centered_label(label, rect.get_center(), 17, CREAM)


func _draw_menu_mission_notes() -> void:
	var ink := Color(CREAM, 0.11)
	draw_string(fallback_font, Vector2(58, 855), "MISSION CONTROL NOTES", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(AMBER, 0.54))
	for line_index in range(5):
		var y := 891.0 + line_index * 56.0
		draw_line(Vector2(58, y), Vector2(W - 58, y), ink, 1.0, true)
	draw_string(fallback_font, Vector2(70, 925), "KEEP THE TRAJECTORY SIMPLE.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(CREAM, 0.26))
	draw_string(fallback_font, Vector2(70, 981), "SPECIAL BLOCKS ARE SOLID SIGNALS.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(CREAM, 0.22))
	draw_string(fallback_font, Vector2(70, 1037), "NORMAL SHAPES KEEP THE PAPER VISIBLE.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(CREAM, 0.18))
	_draw_doodle_planet(Vector2(580, 1120), 42.0, Color(AQUA, 0.14))
	_draw_doodle_star(Vector2(112, 1150), 16.0, Color(AMBER, 0.16))


func _draw_legend_page() -> void:
	_draw_centered_label("FIELD LEGEND", Vector2(W * 0.5, 67.0), 28, CREAM)
	_draw_centered_label("BLOCKS", Vector2(195.0, 112.0), 15, AMBER)
	_draw_centered_label("POWERS", Vector2(525.0, 112.0), 15, AQUA)

	_draw_legend_item(Rect2(44, 138, 306, 175), "NORMAL SHAPES", ["Each hit removes 1 HP.", "Triangles never have special effects."], "normal")
	_draw_legend_item(Rect2(44, 325, 306, 155), "DOUBLE METAL", ["Starts with twice the round HP."], "dense")
	_draw_legend_item(Rect2(44, 492, 306, 155), "REGENERATIVE", ["Gains 50% HP after every", "turn it survives."], "regenerative")
	_draw_legend_item(Rect2(44, 659, 306, 155), "PHASE BLOCK", ["Alternates between solid and", "intangible every turn."], "phase")
	_draw_legend_item(Rect2(44, 826, 306, 210), "BLACK HOLE", ["Coral intake marks show which", "sides absorb a ball on contact.", "Unmarked sides bounce normally."], "black_hole")

	_draw_legend_item(Rect2(370, 138, 306, 155), "+ BALL", ["Adds one ball to the next volley."], "plus")
	_draw_legend_item(Rect2(370, 305, 306, 175), "ION BEAM", ["Each ball crossing it damages", "the full marked row or column."], "ion")
	_draw_legend_item(Rect2(370, 492, 306, 175), "GHOST CORE", ["Balls pass through blocks for", "the rest of the current volley."], "ghost")
	_draw_legend_item(Rect2(370, 679, 306, 205), "SUPERNOVA", ["Charges 20% of the volley.", "Charged impacts also damage", "nearby blocks."], "supernova")

	_draw_menu_action_button(_legend_back_rect(), "BACK", AQUA)


func _draw_legend_item(rect: Rect2, title: String, description: Array, icon_kind: String) -> void:
	draw_rect(rect, Color(PLAYFIELD_BG, 0.76), true)
	draw_rect(rect, Color(CREAM, 0.20), false, 1.5, true)
	var icon_rect := Rect2(rect.position + Vector2(14, 18), Vector2(58, 58))
	match icon_kind:
		"normal":
			draw_rect(icon_rect.grow(-6.0), AMBER, false, 4.0, true)
			var triangle_center := icon_rect.get_center() + Vector2(0, 67)
			draw_polyline(PackedVector2Array([
				triangle_center + Vector2(-18, 16), triangle_center + Vector2(18, 16),
				triangle_center + Vector2(-18, -20), triangle_center + Vector2(-18, 16)
			]), CORAL, 4.0, true)
		"dense":
			_draw_cell_texture(ICON_BLOCK_DENSE, icon_rect)
		"regenerative":
			_draw_cell_texture(ICON_BLOCK_REGENERATIVE, icon_rect)
		"phase":
			_draw_cell_texture(ICON_BLOCK_PHASE, icon_rect)
		"black_hole":
			_draw_cell_texture(ICON_BLOCK_BLACK_HOLE, icon_rect)
			draw_line(icon_rect.position + Vector2(0, 29), icon_rect.position + Vector2(9, 29), CORAL, 5.0, true)
			draw_line(icon_rect.end - Vector2(9, 29), icon_rect.end - Vector2(0, 29), CORAL, 5.0, true)
		"plus":
			_draw_cell_texture(ICON_POWER_PLUS_ONE, icon_rect)
		"ion":
			_draw_cell_texture(ICON_POWER_ION, icon_rect)
		"ghost":
			_draw_cell_texture(ICON_POWER_GHOST, icon_rect)
		"supernova":
			_draw_cell_texture(ICON_POWER_SUPERNOVA, icon_rect)
	draw_string(fallback_font, rect.position + Vector2(84, 39), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CREAM)
	for line_index in range(description.size()):
		draw_string(
			fallback_font,
			rect.position + Vector2(84, 67 + line_index * 20),
			String(description[line_index]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(CREAM, 0.72)
		)


func _draw_centered_label(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(fallback_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_alien_number(text: String, center: Vector2, height: float, color: Color, stroke_width: float) -> void:
	# Bespoke chamfered signal glyphs keep HP readable at phone scale while
	# giving every number the selected geometric/alien display language.
	var digit_width := height * 0.58
	var spacing := height * 0.18
	var total_width := digit_width * text.length() + spacing * maxi(0, text.length() - 1)
	var origin := center - Vector2(total_width * 0.5, height * 0.5)
	for digit_index in range(text.length()):
		var digit := text.substr(digit_index, 1)
		var digit_origin := origin + Vector2(float(digit_index) * (digit_width + spacing), 0.0)
		for segment_name in _alien_digit_segments(digit):
			var segment := _alien_segment_points(String(segment_name))
			var first := digit_origin + Vector2(segment[0].x * digit_width, segment[0].y * height)
			var second := digit_origin + Vector2(segment[1].x * digit_width, segment[1].y * height)
			draw_line(first, second, Color(PAPER_SHADOW, color.a * 0.58), stroke_width + 2.2, true)
			draw_line(first, second, color, stroke_width, true)


func _alien_digit_segments(digit: String) -> Array[String]:
	match digit:
		"0": return ["a", "b", "c", "d", "e", "f"]
		"1": return ["b", "c"]
		"2": return ["a", "b", "g", "e", "d"]
		"3": return ["a", "b", "g", "c", "d"]
		"4": return ["f", "g", "b", "c"]
		"5": return ["a", "f", "g", "c", "d"]
		"6": return ["a", "f", "g", "e", "c", "d"]
		"7": return ["a", "b", "c"]
		"8": return ["a", "b", "c", "d", "e", "f", "g"]
		"9": return ["a", "b", "c", "d", "f", "g"]
	return []


func _alien_segment_points(segment_name: String) -> PackedVector2Array:
	match segment_name:
		"a": return PackedVector2Array([Vector2(0.16, 0.04), Vector2(0.82, 0.04)])
		"b": return PackedVector2Array([Vector2(0.86, 0.10), Vector2(0.96, 0.44)])
		"c": return PackedVector2Array([Vector2(0.96, 0.56), Vector2(0.86, 0.90)])
		"d": return PackedVector2Array([Vector2(0.82, 0.96), Vector2(0.16, 0.96)])
		"e": return PackedVector2Array([Vector2(0.14, 0.90), Vector2(0.04, 0.56)])
		"f": return PackedVector2Array([Vector2(0.04, 0.44), Vector2(0.14, 0.10)])
		"g": return PackedVector2Array([Vector2(0.18, 0.50), Vector2(0.82, 0.50)])
	return PackedVector2Array([Vector2.ZERO, Vector2.ZERO])


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, width: float, segments: int = 32) -> void:
	for index in range(segments):
		var first_angle := TAU * float(index) / float(segments)
		var second_angle := TAU * float(index + 1) / float(segments)
		var first := center + Vector2(cos(first_angle) * radii.x, sin(first_angle) * radii.y)
		var second := center + Vector2(cos(second_angle) * radii.x, sin(second_angle) * radii.y)
		draw_line(first, second, color, width, true)


func _draw_regeneration_orbit(center: Vector2, color: Color) -> void:
	for segment_index in range(3):
		var start_angle := -PI * 0.5 + TAU * float(segment_index) / 3.0
		var end_angle := start_angle + PI * 0.48
		draw_arc(center, 29.0, start_angle, end_angle, 14, color, 2.5, true)
		var endpoint := center + Vector2(cos(end_angle), sin(end_angle)) * 29.0
		var tangent := Vector2(-sin(end_angle), cos(end_angle))
		var side := tangent.rotated(PI * 0.5)
		draw_colored_polygon(PackedVector2Array([
			endpoint + tangent * 4.5,
			endpoint - tangent * 3.5 + side * 3.5,
			endpoint - tangent * 3.5 - side * 3.5
		]), color)
	draw_circle(center, 5.0, Color(AMBER, 0.72))


func _draw_phase_emblem(center: Vector2, alpha: float, scale: float = 1.0) -> void:
	var radius := 10.0 * scale
	var left_color := Color(PHASE_BLUE, 0.78 * alpha)
	var right_color := Color(AQUA, 0.68 * alpha)
	draw_circle(center, radius, left_color)
	var right_half := PackedVector2Array([center])
	for index in range(9):
		var angle := -PI * 0.5 + PI * float(index) / 8.0
		right_half.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(right_half, right_color)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), Color(CREAM, 0.72 * alpha), 1.5, true)
	draw_arc(center, radius + 5.0, -PI * 0.44, PI * 0.22, 10, Color(CREAM, 0.68 * alpha), 2.0, true)
	draw_arc(center, radius + 5.0, PI * 0.56, PI * 1.22, 10, Color(CREAM, 0.68 * alpha), 2.0, true)


func _draw_pickups() -> void:
	for pickup in pickups:
		if bool(pickup["collected"]):
			continue
		var center: Vector2 = pickup["position"]
		var icon_rect := Rect2(center - Vector2(26.0, 26.0), Vector2(52.0, 52.0))
		_draw_cell_texture(ICON_POWER_PLUS_ONE, icon_rect, 0.94)


func _draw_ion_powers() -> void:
	for power in ion_powers:
		var center: Vector2 = power["position"]
		var orientation := String(power["orientation"])
		var alpha := 0.48 if bool(power["activated"]) else 0.90
		draw_set_transform(center, PI * 0.5 if orientation == "vertical" else 0.0, Vector2.ONE)
		_draw_cell_texture(ICON_POWER_ION, Rect2(Vector2(-26.0, -26.0), Vector2(52.0, 52.0)), alpha)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ghost_cores() -> void:
	for core in ghost_cores:
		var center: Vector2 = core["position"]
		var alpha := 0.48 if bool(core["activated"]) else 0.90
		_draw_cell_texture(
			ICON_POWER_GHOST,
			Rect2(center - Vector2(26.0, 26.0), Vector2(52.0, 52.0)),
			alpha
		)


func _draw_supernova_cores() -> void:
	var remaining := _supernova_remaining_charges()
	for core in supernova_cores:
		var center: Vector2 = core["position"]
		var is_exhausted := remaining <= 0
		_draw_cell_texture(
			ICON_POWER_SUPERNOVA,
			Rect2(center - Vector2(26.0, 26.0), Vector2(52.0, 52.0)),
			0.44 if is_exhausted else 0.92
		)

		var pulse_progress := clampf(
			float(core.get("pulse_elapsed", SUPERNOVA_EFFECT_DURATION)) / SUPERNOVA_EFFECT_DURATION,
			0.0,
			1.0
		)
		if pulse_progress < 1.0:
			var pulse_radius := lerpf(20.0, 38.0, pulse_progress)
			draw_arc(center, pulse_radius, 0.0, TAU, 32, Color(NOVA_ORANGE, 1.0 - pulse_progress), 3.0, true)


func _draw_supernova_effects() -> void:
	for effect in supernova_effects:
		var center: Vector2 = effect["position"]
		var progress := clampf(float(effect["elapsed"]) / SUPERNOVA_EFFECT_DURATION, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - progress, 2.0)
		var fade := 1.0 - progress
		var wave_radius := lerpf(10.0, SUPERNOVA_EXPLOSION_RADIUS, eased)

		if progress < 0.24:
			var flash_fade := 1.0 - progress / 0.24
			draw_circle(center, lerpf(15.0, 5.0, progress / 0.24), Color(CREAM, flash_fade * 0.90))

		_draw_board_clipped_ring(center, wave_radius, Color(NOVA_RED, fade * 0.94), 5.0, 64)
		_draw_board_clipped_ring(center, wave_radius * 0.72, Color(NOVA_ORANGE, fade * 0.72), 3.0, 52)

		for index in range(10):
			var angle := TAU * float(index) / 10.0 + 0.19
			var direction := Vector2(cos(angle), sin(angle))
			var ray_start := center + direction * wave_radius * 0.28
			var ray_end := center + direction * wave_radius * (1.0 if index % 2 == 0 else 0.78)
			_draw_board_clipped_line(ray_start, ray_end, Color(NOVA_ORANGE, fade * 0.82), 3.0)

		for index in range(8):
			var angle := TAU * float(index) / 8.0 + 0.43
			var particle_position := center + Vector2(cos(angle), sin(angle)) * wave_radius * 0.88
			if _is_inside_board(particle_position, 3.0):
				draw_circle(particle_position, 2.5 + float(index % 2), Color(CREAM, fade * 0.76))


func _draw_board_clipped_ring(center: Vector2, radius: float, color: Color, width: float, segments: int) -> void:
	for index in range(segments):
		var first_angle := TAU * float(index) / float(segments)
		var second_angle := TAU * float(index + 1) / float(segments)
		var first := center + Vector2(cos(first_angle), sin(first_angle)) * radius
		var second := center + Vector2(cos(second_angle), sin(second_angle)) * radius
		_draw_board_clipped_line(first, second, color, width)


func _draw_board_clipped_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var clipped := _clip_segment_to_board(from, to)
	if clipped.size() == 2:
		draw_line(clipped[0], clipped[1], color, width, true)


func _clip_segment_to_board(from: Vector2, to: Vector2) -> PackedVector2Array:
	var delta := to - from
	var minimum := 0.0
	var maximum := 1.0
	var tests := [
		Vector2(-delta.x, from.x - BOARD_LEFT),
		Vector2(delta.x, BOARD_RIGHT - from.x),
		Vector2(-delta.y, from.y - BOARD_TOP),
		Vector2(delta.y, LAUNCH_LINE_Y - from.y)
	]
	for test: Vector2 in tests:
		var direction: float = test.x
		var distance: float = test.y
		if absf(direction) < 0.0001:
			if distance < 0.0:
				return PackedVector2Array()
			continue
		var amount: float = distance / direction
		if direction < 0.0:
			minimum = maxf(minimum, amount)
		else:
			maximum = minf(maximum, amount)
		if minimum > maximum:
			return PackedVector2Array()
	return PackedVector2Array([from + delta * minimum, from + delta * maximum])


func _is_inside_board(point: Vector2, margin: float = 0.0) -> bool:
	return (
		point.x >= BOARD_LEFT + margin
		and point.x <= BOARD_RIGHT - margin
		and point.y >= BOARD_TOP + margin
		and point.y <= LAUNCH_LINE_Y - margin
	)


func _draw_ion_beam_effects() -> void:
	for effect in ion_beam_effects:
		var progress := clampf(float(effect["elapsed"]) / ION_BEAM_EFFECT_DURATION, 0.0, 1.0)
		var pulse := sin(progress * PI)
		var fade := 1.0 - progress
		var glow_width := 5.0 + pulse * 17.0
		var beam_position: Vector2 = effect["position"]
		var orientation := String(effect["orientation"])
		# Both variants are bounded by construction to the playable board.
		if orientation == "vertical":
			draw_rect(
				Rect2(
					Vector2(beam_position.x - glow_width * 0.5, BOARD_TOP),
					Vector2(glow_width, LAUNCH_LINE_Y - BOARD_TOP)
				),
				Color(ION_BLUE, fade * 0.34),
				true
			)
			draw_rect(
				Rect2(
					Vector2(beam_position.x - 2.0, BOARD_TOP),
					Vector2(4.0, LAUNCH_LINE_Y - BOARD_TOP)
				),
				Color(CREAM, fade),
				true
			)
		else:
			draw_rect(
				Rect2(
					Vector2(BOARD_LEFT, beam_position.y - glow_width * 0.5),
					Vector2(BOARD_RIGHT - BOARD_LEFT, glow_width)
				),
				Color(ION_BLUE, fade * 0.34),
				true
			)
			draw_rect(
				Rect2(
					Vector2(BOARD_LEFT, beam_position.y - 2.0),
					Vector2(BOARD_RIGHT - BOARD_LEFT, 4.0)
				),
				Color(CREAM, fade),
				true
			)


func _draw_launcher() -> void:
	var rotation := Vector2.UP.angle_to(aim_direction.normalized())
	draw_set_transform(launcher, rotation, Vector2.ONE)
	draw_texture_rect(LAUNCHER_TEXTURE, Rect2(-30.0, -70.0, 60.0, 70.0), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_game_over() -> void:
	draw_rect(Rect2(Vector2(0, 360), Vector2(W, 360)), Color(0.02, 0.07, 0.08, 0.94), true)
	draw_string(fallback_font, Vector2(0, 470), "SIGNAL LOST", HORIZONTAL_ALIGNMENT_CENTER, W, 48, CORAL)
	draw_string(fallback_font, Vector2(0, 535), "ROUND %02d" % turn, HORIZONTAL_ALIGNMENT_CENTER, W, 26, CREAM)
	draw_string(fallback_font, Vector2(0, 610), "TAP TO RESTART", HORIZONTAL_ALIGNMENT_CENTER, W, 20, AQUA)
