extends "res://scripts/header_style.gd"

signal main_menu_requested

const MENU_PANEL_TEXTURE: Texture2D = preload("res://assets/ui/menu/menu_board (2).png")
const MENU_RESUME_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_resume.png")
const MENU_RESUME_PRESSED_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_resume_pressed.png")
const MENU_MAIN_MENU_TEXTURE: Texture2D = preload("res://assets/ui/menu/main_menu.png")
const MENU_MAIN_MENU_PRESSED_TEXTURE: Texture2D = preload("res://assets/ui/menu/main_menu_pressed.png")
const MENU_RESTART_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_restart.png")
const MENU_RESTART_PRESSED_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_restart_pressed.png")
const MENU_SETTINGS_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_settings.png")
const MENU_SETTINGS_PRESSED_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_settings_pressed.png")
const MENU_HOW_TO_PLAY_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_how_to_play.png")
const MENU_HOW_TO_PLAY_PRESSED_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_how_to_play_pressed.png")

# The new board keeps the popup entirely between the established 240 px header
# and 152 px footer on the 720x1280 logical canvas. Five 3:1 button assets fit
# inside its usable teal face with equal spacing and comfortable side margins.
const POPUP_PANEL_RECT := Rect2(50.0, 270.0, 620.0, 826.7)
const POPUP_BUTTON_SIZE := Vector2(390.0, 130.0)
const POPUP_BUTTON_X := 165.0
const POPUP_BUTTON_START_Y := 400.0
const POPUP_BUTTON_STEP := 137.0
const POPUP_PRESSED_OFFSET := Vector2(0.0, 2.0)
const POPUP_DIM_ALPHA := 0.68

const PAUSE_BUTTON_RESUME := "resume"
const PAUSE_BUTTON_MAIN_MENU := "main_menu"
const PAUSE_BUTTON_RESTART := "restart"
const PAUSE_BUTTON_SETTINGS := "settings"
const PAUSE_BUTTON_HOW_TO_PLAY := "how_to_play"

const SETTINGS_POPUP_RECT := Rect2(80.0, 355.0, 560.0, 500.0)

var pause_button_press_candidate := ""
var pause_button_pressed_visual := ""


func _popup_button_rect(button_index: int) -> Rect2:
	return Rect2(
		Vector2(POPUP_BUTTON_X, POPUP_BUTTON_START_Y + POPUP_BUTTON_STEP * float(button_index)),
		POPUP_BUTTON_SIZE
	)


func _popup_resume_rect() -> Rect2:
	return _popup_button_rect(0)


func _popup_main_menu_rect() -> Rect2:
	return _popup_button_rect(1)


func _popup_restart_rect() -> Rect2:
	return _popup_button_rect(2)


func _popup_settings_rect() -> Rect2:
	return _popup_button_rect(3)


func _popup_how_to_play_rect() -> Rect2:
	return _popup_button_rect(4)


func _settings_backgrounds_rect() -> Rect2:
	return Rect2(145.0, 505.0, 430.0, 78.0)


func _settings_ball_sounds_rect() -> Rect2:
	return Rect2(145.0, 605.0, 430.0, 78.0)


func _settings_back_rect() -> Rect2:
	return Rect2(235.0, 730.0, 250.0, 64.0)


func _draw() -> void:
	# Keep the established game rendering, but turn the pause UI into a genuine
	# overlay so the current board remains visible underneath the popup.
	_update_responsive_layout()
	_set_draw_offset(Vector2.ZERO)
	var full_area := Rect2(Vector2.ZERO, layout_viewport_size)
	_draw_fullscreen_background(full_area)

	_set_draw_offset(Vector2(layout_content_x, layout_header_y_offset))
	_draw_header()

	_set_draw_offset(Vector2(layout_content_x, layout_board_y_offset))
	_draw_playfield()
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

	_set_draw_offset(Vector2(layout_content_x, layout_footer_y_offset))
	_draw_footer()

	_set_draw_offset(Vector2(layout_content_x, layout_board_y_offset))
	if state == TurnState.GAME_OVER:
		_draw_game_over()

	if menu_open:
		_set_draw_offset(Vector2.ZERO)
		draw_rect(full_area, Color(BG, POPUP_DIM_ALPHA), true)
		_set_draw_offset(Vector2(layout_content_x, layout_menu_y_offset))
		_draw_menu_overlay()

	_set_draw_offset(Vector2.ZERO)


func _draw_menu_overlay() -> void:
	if menu_page == 0:
		_draw_pause_popup()
		return
	if menu_page == 4:
		_draw_settings_popup()
		return

	# Existing detailed pages remain functional while they are progressively
	# migrated to the same physical popup language.
	super._draw_menu_overlay()


func _draw_pause_popup() -> void:
	draw_texture_rect(MENU_PANEL_TEXTURE, POPUP_PANEL_RECT, false)
	_draw_pause_button(
		MENU_RESUME_TEXTURE,
		MENU_RESUME_PRESSED_TEXTURE,
		_popup_resume_rect(),
		PAUSE_BUTTON_RESUME
	)
	_draw_pause_button(
		MENU_MAIN_MENU_TEXTURE,
		MENU_MAIN_MENU_PRESSED_TEXTURE,
		_popup_main_menu_rect(),
		PAUSE_BUTTON_MAIN_MENU
	)
	_draw_pause_button(
		MENU_RESTART_TEXTURE,
		MENU_RESTART_PRESSED_TEXTURE,
		_popup_restart_rect(),
		PAUSE_BUTTON_RESTART
	)
	_draw_pause_button(
		MENU_SETTINGS_TEXTURE,
		MENU_SETTINGS_PRESSED_TEXTURE,
		_popup_settings_rect(),
		PAUSE_BUTTON_SETTINGS
	)
	_draw_pause_button(
		MENU_HOW_TO_PLAY_TEXTURE,
		MENU_HOW_TO_PLAY_PRESSED_TEXTURE,
		_popup_how_to_play_rect(),
		PAUSE_BUTTON_HOW_TO_PLAY
	)


func _draw_pause_button(
	normal_texture: Texture2D,
	pressed_texture: Texture2D,
	button_rect: Rect2,
	button_id: String
) -> void:
	var is_pressed := pause_button_pressed_visual == button_id
	var target_rect := button_rect
	if is_pressed:
		target_rect.position += POPUP_PRESSED_OFFSET
	draw_texture_rect(pressed_texture if is_pressed else normal_texture, target_rect, false)


func _draw_settings_popup() -> void:
	# First pass keeps the existing selectors behind a compact Settings hub.
	_draw_rounded_panel(SETTINGS_POPUP_RECT, Color(PANEL, 0.99), Color(CREAM, 0.82), 3.0, 18.0)
	_draw_rounded_panel(SETTINGS_POPUP_RECT.grow(-8.0), Color(PANEL, 0.99), Color(AMBER, 0.26), 1.0, 14.0)
	_draw_centered_label("SETTINGS", Vector2(W * 0.5, 415.0), 27, CREAM)
	_draw_centered_label("MISSION CONTROL", Vector2(W * 0.5, 450.0), 12, Color(AQUA, 0.82))
	_draw_menu_action_button(_settings_backgrounds_rect(), "BACKGROUNDS", PHASE_BLUE)
	_draw_menu_action_button(_settings_ball_sounds_rect(), "BALL SOUNDS", AMBER)
	_draw_menu_action_button(_settings_back_rect(), "BACK", AQUA)


func _pause_button_at_point(pointer: Vector2) -> String:
	if _popup_resume_rect().has_point(pointer):
		return PAUSE_BUTTON_RESUME
	if _popup_main_menu_rect().has_point(pointer):
		return PAUSE_BUTTON_MAIN_MENU
	if _popup_restart_rect().has_point(pointer):
		return PAUSE_BUTTON_RESTART
	if _popup_settings_rect().has_point(pointer):
		return PAUSE_BUTTON_SETTINGS
	if _popup_how_to_play_rect().has_point(pointer):
		return PAUSE_BUTTON_HOW_TO_PLAY
	return ""


func _pause_button_rect(button_id: String) -> Rect2:
	match button_id:
		PAUSE_BUTTON_RESUME:
			return _popup_resume_rect()
		PAUSE_BUTTON_MAIN_MENU:
			return _popup_main_menu_rect()
		PAUSE_BUTTON_RESTART:
			return _popup_restart_rect()
		PAUSE_BUTTON_SETTINGS:
			return _popup_settings_rect()
		PAUSE_BUTTON_HOW_TO_PLAY:
			return _popup_how_to_play_rect()
	return Rect2()


func _begin_pause_button_press(pointer: Vector2) -> void:
	pause_button_press_candidate = _pause_button_at_point(pointer)
	pause_button_pressed_visual = pause_button_press_candidate
	queue_redraw()


func _update_pause_button_press(pointer: Vector2) -> void:
	if pause_button_press_candidate.is_empty():
		return
	var should_look_pressed := _pause_button_rect(pause_button_press_candidate).has_point(pointer)
	var next_visual := pause_button_press_candidate if should_look_pressed else ""
	if next_visual == pause_button_pressed_visual:
		return
	pause_button_pressed_visual = next_visual
	queue_redraw()


func _finish_pause_button_press(pointer: Vector2) -> void:
	var activated_button := ""
	if not pause_button_press_candidate.is_empty() and _pause_button_rect(pause_button_press_candidate).has_point(pointer):
		activated_button = pause_button_press_candidate
	pause_button_press_candidate = ""
	pause_button_pressed_visual = ""
	queue_redraw()
	if not activated_button.is_empty():
		_activate_pause_button(activated_button)


func _cancel_pause_button_press() -> void:
	if pause_button_press_candidate.is_empty() and pause_button_pressed_visual.is_empty():
		return
	pause_button_press_candidate = ""
	pause_button_pressed_visual = ""
	queue_redraw()


func _activate_pause_button(button_id: String) -> void:
	match button_id:
		PAUSE_BUTTON_RESUME:
			menu_open = false
			queue_redraw()
		PAUSE_BUTTON_MAIN_MENU:
			# The project currently boots directly into the gameplay scene and has no
			# separate main-menu scene yet. Expose a clean navigation hook without
			# inventing a destructive fallback such as restarting the current run.
			main_menu_requested.emit()
		PAUSE_BUTTON_RESTART:
			menu_open = false
			_start_new_run()
		PAUSE_BUTTON_SETTINGS:
			menu_page = 4
			queue_redraw()
		PAUSE_BUTTON_HOW_TO_PLAY:
			menu_page = 1
			queue_redraw()


func _handle_pause_menu_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pointer := _screen_to_menu(event.position)
		if event.pressed:
			_begin_pause_button_press(pointer)
		else:
			_finish_pause_button_press(pointer)
		return

	if event is InputEventScreenDrag:
		_update_pause_button_press(_screen_to_menu(event.position))
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer := _screen_to_menu(event.position)
		if event.pressed:
			_begin_pause_button_press(pointer)
		else:
			_finish_pause_button_press(pointer)
		return

	if event is InputEventMouseMotion and not pause_button_press_candidate.is_empty():
		_update_pause_button_press(_screen_to_menu(event.position))


func _unhandled_input(event: InputEvent) -> void:
	if menu_open and menu_page == 0:
		_handle_pause_menu_input(event)
		return
	_cancel_pause_button_press()
	super._unhandled_input(event)


func _handle_menu_press(pointer: Vector2) -> void:
	if menu_page == 0:
		# Compatibility path for callers other than the normal pointer-release flow.
		var button_id := _pause_button_at_point(pointer)
		if not button_id.is_empty():
			_activate_pause_button(button_id)
		return

	if menu_page == 4:
		if _settings_backgrounds_rect().has_point(pointer):
			menu_page = 2
			queue_redraw()
			return
		if _settings_ball_sounds_rect().has_point(pointer):
			menu_page = 3
			queue_redraw()
			return
		if _settings_back_rect().has_point(pointer):
			menu_page = 0
			queue_redraw()
			return
		return

	super._handle_menu_press(pointer)
