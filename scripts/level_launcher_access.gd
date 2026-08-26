extends Node2D

const LEVELS_DIR := "res://levels"
const TEST_SCENE := "res://scenes/level_test.tscn"
const RUNTIME_LEVEL_KEY := "ryko/runtime_test_level_path"
const W := 720.0

const PANEL := Color("#0c2025")
const PLAYFIELD_BG := Color("#10262b")
const CREAM := Color("#f2e3bb")
const AQUA := Color("#55b8b1")
const CORAL := Color("#e96b5f")
const MUTED := Color("#6e8584")

const LEVELS_BUTTON_RECT := Rect2(145.0, 665.0, 430.0, 52.0)
const LEVELS_PANEL_RECT := Rect2(80.0, 300.0, 560.0, 650.0)
const LEVELS_BACK_RECT := Rect2(235.0, 855.0, 250.0, 64.0)
const LEVEL_OPTION_HEIGHT := 58.0
const LEVEL_OPTION_GAP := 10.0

var overlay_open := false
var level_files: Array[String] = []
var fallback_font: Font


func _ready() -> void:
	fallback_font = ThemeDB.fallback_font
	_refresh_catalog()
	set_process(true)


func _process(_delta: float) -> void:
	var game := get_parent()
	if game == null:
		return
	if not bool(game.get("menu_open")) or int(game.get("menu_page")) != 4:
		overlay_open = false
	queue_redraw()


func _draw() -> void:
	var game := get_parent()
	if game == null or not bool(game.get("menu_open")):
		return
	if int(game.get("menu_page")) != 4:
		return

	var offset := Vector2(float(game.get("layout_content_x")), float(game.get("layout_menu_y_offset")))
	draw_set_transform(offset, 0.0, Vector2.ONE)
	if overlay_open:
		_draw_levels_overlay()
	else:
		_draw_action_button(LEVELS_BUTTON_RECT, "LEVELS", CORAL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _input(event: InputEvent) -> void:
	var game := get_parent()
	if game == null or not bool(game.get("menu_open")) or int(game.get("menu_page")) != 4:
		return

	var pressed := false
	var screen_position := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
		screen_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		screen_position = event.position
	if not pressed:
		return

	var pointer := screen_position - Vector2(float(game.get("layout_content_x")), float(game.get("layout_menu_y_offset")))
	if not overlay_open:
		if LEVELS_BUTTON_RECT.has_point(pointer):
			overlay_open = true
			_refresh_catalog()
			get_viewport().set_input_as_handled()
			queue_redraw()
		return

	for index in range(mini(7, level_files.size())):
		if _level_option_rect(index).has_point(pointer):
			_launch_level(level_files[index])
			get_viewport().set_input_as_handled()
			return
	if LEVELS_BACK_RECT.has_point(pointer):
		overlay_open = false
		get_viewport().set_input_as_handled()
		queue_redraw()
		return

	# While the launcher is open, don't let the Settings page underneath react.
	get_viewport().set_input_as_handled()


func _refresh_catalog() -> void:
	level_files.clear()
	if not DirAccess.dir_exists_absolute(LEVELS_DIR):
		return
	for filename in DirAccess.get_files_at(LEVELS_DIR):
		if filename.to_lower().ends_with(".json"):
			level_files.append(filename)
	level_files.sort()


func _launch_level(filename: String) -> void:
	var path := LEVELS_DIR.path_join(filename)
	ProjectSettings.set_setting(RUNTIME_LEVEL_KEY, path)
	var error := get_tree().change_scene_to_file(TEST_SCENE)
	if error != OK:
		push_error("RYKO level launcher could not open test scene for %s" % path)


func _level_option_rect(index: int) -> Rect2:
	return Rect2(125.0, 420.0 + float(index) * (LEVEL_OPTION_HEIGHT + LEVEL_OPTION_GAP), 470.0, LEVEL_OPTION_HEIGHT)


func _draw_levels_overlay() -> void:
	draw_rect(LEVELS_PANEL_RECT, Color(PANEL, 0.995), true)
	draw_rect(LEVELS_PANEL_RECT, Color(CREAM, 0.82), false, 3.0, true)
	draw_rect(LEVELS_PANEL_RECT.grow(-8.0), Color(AQUA, 0.24), false, 1.0, true)
	_draw_centered("LEVELS", Vector2(W * 0.5, 345.0), 27, CREAM)
	_draw_centered("TEST LAUNCHER // JSON", Vector2(W * 0.5, 380.0), 12, Color(AQUA, 0.82))

	if level_files.is_empty():
		_draw_centered("NO JSON LEVELS IN /levels YET", Vector2(W * 0.5, 510.0), 14, Color(CREAM, 0.68))
		_draw_centered("ADD A LEVEL JSON AND IT WILL APPEAR HERE", Vector2(W * 0.5, 545.0), 10, Color(MUTED, 0.88))
	else:
		for index in range(mini(7, level_files.size())):
			var rect := _level_option_rect(index)
			draw_rect(rect, Color(PLAYFIELD_BG, 0.98), true)
			draw_rect(rect, Color(CREAM, 0.34), false, 1.5, true)
			_draw_centered(level_files[index].trim_suffix(".json").replace("_", " ").to_upper(), rect.get_center(), 14, CREAM)

	_draw_action_button(LEVELS_BACK_RECT, "BACK", AQUA)


func _draw_action_button(rect: Rect2, label: String, accent: Color) -> void:
	draw_rect(rect, Color(PLAYFIELD_BG, 0.98), true)
	draw_rect(rect, accent, false, 3.0, true)
	_draw_centered(label, rect.get_center(), 17, CREAM)


func _draw_centered(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(fallback_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
