extends Node2D

const LevelDefinition = preload("res://scripts/level_definition.gd")

const LEVELS_DIR := "res://levels"
const USER_LEVELS_DIR := "user://levels"
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
const LEVEL_OPTION_HEIGHT := 50.0
const LEVEL_OPTION_GAP := 8.0
const LEVELS_PER_PAGE := 5
const LEVELS_IMPORT_RECT := Rect2(185.0, 710.0, 350.0, 46.0)
const LEVELS_PREV_RECT := Rect2(125.0, 790.0, 150.0, 44.0)
const LEVELS_PAGE_RECT := Rect2(285.0, 790.0, 150.0, 44.0)
const LEVELS_NEXT_RECT := Rect2(445.0, 790.0, 150.0, 44.0)

var overlay_open := false
# Full paths are kept here. Local user:// files override bundled res:// files
# with the same filename so testers can replace a level without rebuilding APK.
var level_files: Array[String] = []
var level_page := 0
var import_status := ""
var fallback_font: Font
var import_dialog: FileDialog


func _ready() -> void:
	fallback_font = ThemeDB.fallback_font
	_ensure_user_levels_dir()
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
			import_status = ""
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

	if LEVELS_IMPORT_RECT.has_point(pointer):
		_open_import_dialog()
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


func _ensure_user_levels_dir() -> void:
	var absolute_path := ProjectSettings.globalize_path(USER_LEVELS_DIR)
	if not DirAccess.dir_exists_absolute(absolute_path):
		var error := DirAccess.make_dir_recursive_absolute(absolute_path)
		if error != OK:
			push_error("RYKO could not create local levels directory: %s" % absolute_path)


func _refresh_catalog() -> void:
	level_files.clear()
	var merged_by_filename: Dictionary = {}

	if DirAccess.dir_exists_absolute(LEVELS_DIR):
		for filename in DirAccess.get_files_at(LEVELS_DIR):
			if filename.to_lower().ends_with(".json"):
				merged_by_filename[filename] = LEVELS_DIR.path_join(filename)

	_ensure_user_levels_dir()
	if DirAccess.dir_exists_absolute(USER_LEVELS_DIR):
		for filename in DirAccess.get_files_at(USER_LEVELS_DIR):
			if filename.to_lower().ends_with(".json"):
				# Local copy wins over bundled copy with the same level filename.
				merged_by_filename[filename] = USER_LEVELS_DIR.path_join(filename)

	var filenames: Array = merged_by_filename.keys()
	filenames.sort()
	for filename_variant in filenames:
		level_files.append(String(merged_by_filename[filename_variant]))
	level_page = clampi(level_page, 0, maxi(0, _page_count() - 1))


func _page_count() -> int:
	if level_files.is_empty():
		return 1
	return int(ceili(float(level_files.size()) / float(LEVELS_PER_PAGE)))


func _launch_level(path: String) -> void:
	ProjectSettings.set_setting(RUNTIME_LEVEL_KEY, path)
	var error := get_tree().change_scene_to_file(TEST_SCENE)
	if error != OK:
		push_error("RYKO level launcher could not open test scene for %s" % path)


func _level_option_rect(index: int) -> Rect2:
	return Rect2(125.0, 410.0 + float(index) * (LEVEL_OPTION_HEIGHT + LEVEL_OPTION_GAP), 470.0, LEVEL_OPTION_HEIGHT)


func _level_display_name(path: String) -> String:
	return path.get_file().trim_suffix(".json").replace("_", " ").to_upper()


func _draw_levels_overlay() -> void:
	draw_rect(LEVELS_PANEL_RECT, Color(PANEL, 0.995), true)
	draw_rect(LEVELS_PANEL_RECT, Color(CREAM, 0.82), false, 3.0, true)
	draw_rect(LEVELS_PANEL_RECT.grow(-8.0), Color(AQUA, 0.24), false, 1.0, true)
	_draw_centered("LEVELS", Vector2(W * 0.5, 345.0), 27, CREAM)
	_draw_centered("BUILT-IN + LOCAL JSON", Vector2(W * 0.5, 380.0), 12, Color(AQUA, 0.82))

	if level_files.is_empty():
		_draw_centered("NO JSON LEVELS YET", Vector2(W * 0.5, 510.0), 14, Color(CREAM, 0.68))
		_draw_centered("IMPORT A LEVEL JSON FROM YOUR PHONE", Vector2(W * 0.5, 545.0), 10, Color(MUTED, 0.88))
	else:
		var page_start := level_page * LEVELS_PER_PAGE
		var page_count := mini(LEVELS_PER_PAGE, maxi(0, level_files.size() - page_start))
		for slot in range(page_count):
			var rect := _level_option_rect(slot)
			var path := level_files[page_start + slot]
			var local_level := path.begins_with("user://")
			draw_rect(rect, Color(PLAYFIELD_BG, 0.98), true)
			draw_rect(rect, AQUA if local_level else Color(CREAM, 0.34), false, 2.5 if local_level else 1.5, true)
			_draw_centered(_level_display_name(path), rect.get_center(), 14, CREAM)
			if local_level:
				_draw_centered("LOCAL", Vector2(rect.end.x - 42.0, rect.get_center().y), 8, AQUA)

	_draw_action_button(LEVELS_IMPORT_RECT, "IMPORT JSON", CORAL)
	if not import_status.is_empty():
		_draw_centered(import_status, Vector2(W * 0.5, 772.0), 10, AQUA)

	if _page_count() > 1:
		_draw_action_button(LEVELS_PREV_RECT, "PREV", AQUA if level_page > 0 else MUTED)
		_draw_action_button(LEVELS_PAGE_RECT, "%d / %d" % [level_page + 1, _page_count()], CREAM)
		_draw_action_button(LEVELS_NEXT_RECT, "NEXT", AQUA if level_page < _page_count() - 1 else MUTED)

	_draw_action_button(LEVELS_BACK_RECT, "BACK", AQUA)


func _open_import_dialog() -> void:
	if is_instance_valid(import_dialog):
		return
	import_status = "SELECT JSON..."
	queue_redraw()
	# Opening on a deferred frame avoids handing the same Android touch event
	# that pressed IMPORT JSON to the system picker as an immediate cancel.
	call_deferred("_show_import_dialog")


func _show_import_dialog() -> void:
	if is_instance_valid(import_dialog):
		return
	var dialog := FileDialog.new()
	import_dialog = dialog
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	# Android's native picker uses Storage Access Framework and returns a
	# content:// URI. FileAccess can read that URI directly in Godot 4.4.
	dialog.filters = PackedStringArray(["*.json;JSON Level;application/json,text/json"])
	dialog.use_native_dialog = true
	dialog.file_selected.connect(_on_import_file_selected)
	dialog.file_selected.connect(func(_path: String) -> void:
		_close_import_dialog()
	)
	dialog.canceled.connect(func() -> void:
		import_status = "IMPORT CANCELED"
		queue_redraw()
		_close_import_dialog()
	)
	add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(640, 560), 0.9)


func _close_import_dialog() -> void:
	if not is_instance_valid(import_dialog):
		import_dialog = null
		return
	var dialog := import_dialog
	import_dialog = null
	dialog.queue_free()


func _on_import_file_selected(source_path: String) -> void:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		import_status = "CANNOT READ FILE"
		push_error("RYKO import could not read %s" % source_path)
		queue_redraw()
		return
	var raw_text := source.get_as_text()
	source.close()
	var parsed := LevelDefinition.parse_json_text(raw_text)
	if not bool(parsed.get("valid", false)):
		import_status = "INVALID LEVEL JSON"
		push_error("RYKO import rejected %s: %s" % [source_path, str(parsed.get("errors", []))])
		queue_redraw()
		return

	var parsed_level: Dictionary = parsed.get("level", {}) as Dictionary
	var level_id := String(parsed_level.get("levelId", "")).strip_edges()
	if level_id.is_empty():
		level_id = source_path.get_file().get_basename()
	level_id = _sanitize_level_id(level_id)
	if level_id.is_empty():
		import_status = "MISSING LEVEL ID"
		queue_redraw()
		return

	_ensure_user_levels_dir()
	var destination := USER_LEVELS_DIR.path_join("%s.json" % level_id)
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		import_status = "CANNOT SAVE LEVEL"
		push_error("RYKO import could not write %s" % destination)
		queue_redraw()
		return
	output.store_string(raw_text)
	output.close()

	_refresh_catalog()
	for index in range(level_files.size()):
		if level_files[index] == destination:
			level_page = int(index / LEVELS_PER_PAGE)
			break
	import_status = "IMPORTED %s" % level_id.to_upper()
	print("RYKO local level imported: %s -> %s" % [source_path, destination])
	queue_redraw()


func _sanitize_level_id(value: String) -> String:
	var cleaned := value.strip_edges().to_lower()
	var regex := RegEx.new()
	if regex.compile("[^a-z0-9_-]") != OK:
		return cleaned
	cleaned = regex.sub(cleaned, "_", true)
	while cleaned.contains("__"):
		cleaned = cleaned.replace("__", "_")
	return cleaned.trim_prefix("_").trim_suffix("_")


func _draw_action_button(rect: Rect2, label: String, accent: Color) -> void:
	draw_rect(rect, Color(PLAYFIELD_BG, 0.98), true)
	draw_rect(rect, accent, false, 3.0, true)
	_draw_centered(label, rect.get_center(), 17, CREAM)


func _draw_centered(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(fallback_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
