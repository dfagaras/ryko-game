extends Node2D

const LEVELS_DIR := "res://levels"
const TEST_SCENE := "res://scenes/level_test.tscn"
const RUNTIME_LEVEL_KEY := "ryko/runtime_test_level_path"
const BACKGROUND_MUSIC_KEY := "ryko/background_music_enabled"
const MUSIC_BUS_NAME := "RYKO_MUSIC"
const W := 720.0

const PANEL := Color("#0c2025")
const PLAYFIELD_BG := Color("#10262b")
const CREAM := Color("#f2e3bb")
const AQUA := Color("#55b8b1")
const CORAL := Color("#e96b5f")
const AMBER := Color("#e7ae43")
const MUTED := Color("#6e8584")

# Keep the extra Settings controls in the free space between BALL SOUNDS and BACK.
# They are intentionally compact so the established Settings panel does not need
# to be resized and the existing Infinity menu remains untouched.
const MUSIC_BUTTON_RECT := Rect2(145.0, 688.0, 205.0, 36.0)
const LEVELS_BUTTON_RECT := Rect2(370.0, 688.0, 205.0, 36.0)
const LEVELS_PANEL_RECT := Rect2(80.0, 300.0, 560.0, 650.0)
const LEVELS_BACK_RECT := Rect2(235.0, 855.0, 250.0, 64.0)
const LEVEL_OPTION_HEIGHT := 58.0
const LEVEL_OPTION_GAP := 10.0
const LEVELS_PER_PAGE := 5
const LEVELS_PREV_RECT := Rect2(125.0, 775.0, 150.0, 52.0)
const LEVELS_PAGE_RECT := Rect2(285.0, 775.0, 150.0, 52.0)
const LEVELS_NEXT_RECT := Rect2(445.0, 775.0, 150.0, 52.0)

var overlay_open := false
var level_files: Array[String] = []
var level_page := 0
var fallback_font: Font


func _ready() -> void:
	fallback_font = ThemeDB.fallback_font
	_refresh_catalog()
	set_process(true)
	call_deferred("_apply_background_music_state")


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
		_draw_action_button(MUSIC_BUTTON_RECT, "MUSIC %s" % ("ON" if _background_music_enabled() else "OFF"), AMBER)
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
		if MUSIC_BUTTON_RECT.has_point(pointer):
			_toggle_background_music()
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
		if LEVELS_BUTTON_RECT.has_point(pointer):
			overlay_open = true
			level_page = 0
			_refresh_catalog()
			get_viewport().set_input_as_handled()
			queue_redraw()
		return

	var page_start := level_page * LEVELS_PER_PAGE
	var page_count := mini(LEVELS_PER_PAGE, maxi(0, level_files.size() - page_start))
	for slot in range(page_count):
		if _level_option_rect(slot).has_point(pointer):
			_launch_level(level_files[page_start + slot])
			get_viewport().set_input_as_handled()
			return

	if _page_count() > 1:
		if LEVELS_PREV_RECT.has_point(pointer) and level_page > 0:
			level_page -= 1
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
		if LEVELS_NEXT_RECT.has_point(pointer) and level_page < _page_count() - 1:
			level_page += 1
			get_viewport().set_input_as_handled()
			queue_redraw()
			return

	if LEVELS_BACK_RECT.has_point(pointer):
		overlay_open = false
		get_viewport().set_input_as_handled()
		queue_redraw()
		return

	# While the launcher is open, don't let the Settings page underneath react.
	get_viewport().set_input_as_handled()


func _background_music_enabled() -> bool:
	return bool(ProjectSettings.get_setting(BACKGROUND_MUSIC_KEY, true))


func _toggle_background_music() -> void:
	ProjectSettings.set_setting(BACKGROUND_MUSIC_KEY, not _background_music_enabled())
	_apply_background_music_state()


func _ensure_music_bus() -> int:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus()
	bus_index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, MUSIC_BUS_NAME)
	return bus_index


func _apply_background_music_state() -> void:
	var game := get_parent()
	if game == null:
		return
	var bus_index := _ensure_music_bus()
	var enabled := _background_music_enabled()

	# Route only the two playlist players to a dedicated music bus. Ball/block
	# SFX remain on their existing bus, so muting BGM cannot mute gameplay audio.
	for child in game.get_children():
		if child is AudioStreamPlayer and String(child.name).begins_with("MusicPlayer"):
			(child as AudioStreamPlayer).bus = MUSIC_BUS_NAME

	var players_variant: Variant = game.get("music_players")
	if typeof(players_variant) == TYPE_ARRAY:
		for player_variant in players_variant:
			if player_variant is AudioStreamPlayer:
				(player_variant as AudioStreamPlayer).bus = MUSIC_BUS_NAME

	# Muting at AudioServer level cannot be undone by the playlist crossfade code
	# changing individual player volumes. This is the authoritative BGM mute.
	AudioServer.set_bus_mute(bus_index, not enabled)


func _refresh_catalog() -> void:
	level_files.clear()
	if not DirAccess.dir_exists_absolute(LEVELS_DIR):
		level_page = 0
		return
	for filename in DirAccess.get_files_at(LEVELS_DIR):
		if filename.to_lower().ends_with(".json"):
			level_files.append(filename)
	level_files.sort()
	level_page = clampi(level_page, 0, maxi(0, _page_count() - 1))


func _page_count() -> int:
	if level_files.is_empty():
		return 1
	return int(ceili(float(level_files.size()) / float(LEVELS_PER_PAGE)))


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
		var page_start := level_page * LEVELS_PER_PAGE
		var page_count := mini(LEVELS_PER_PAGE, maxi(0, level_files.size() - page_start))
		for slot in range(page_count):
			var rect := _level_option_rect(slot)
			var filename := level_files[page_start + slot]
			draw_rect(rect, Color(PLAYFIELD_BG, 0.98), true)
			draw_rect(rect, Color(CREAM, 0.34), false, 1.5, true)
			_draw_centered(filename.trim_suffix(".json").replace("_", " ").to_upper(), rect.get_center(), 14, CREAM)

	if _page_count() > 1:
		_draw_action_button(LEVELS_PREV_RECT, "PREV", AQUA if level_page > 0 else MUTED)
		_draw_action_button(LEVELS_PAGE_RECT, "%d / %d" % [level_page + 1, _page_count()], CREAM)
		_draw_action_button(LEVELS_NEXT_RECT, "NEXT", AQUA if level_page < _page_count() - 1 else MUTED)

	_draw_action_button(LEVELS_BACK_RECT, "BACK", AQUA)


func _draw_action_button(rect: Rect2, label: String, accent: Color) -> void:
	draw_rect(rect, Color(PLAYFIELD_BG, 0.98), true)
	draw_rect(rect, accent, false, 3.0, true)
	_draw_centered(label, rect.get_center(), 17, CREAM)


func _draw_centered(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(fallback_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
