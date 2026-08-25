extends "res://scripts/header_style.gd"

const MENU_PANEL_TEXTURE: Texture2D = preload("res://assets/ui/menu/menu_panel_frame.png")
const MENU_RESUME_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_resume.png")
const MENU_RESTART_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_restart.png")
const MENU_SETTINGS_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_settings.png")
const MENU_HOW_TO_PLAY_TEXTURE: Texture2D = preload("res://assets/ui/menu/btn_how_to_play.png")

const POPUP_PANEL_RECT := Rect2(50.0, 300.0, 620.0, 542.5)
const POPUP_BUTTON_SIZE := Vector2(430.0, 82.0)
const POPUP_BUTTON_X := 145.0
const POPUP_BUTTON_START_Y := 462.0
const POPUP_BUTTON_STEP := 92.0
const POPUP_DIM_ALPHA := 0.68

const SETTINGS_POPUP_RECT := Rect2(80.0, 355.0, 560.0, 500.0)


func _popup_resume_rect() -> Rect2:
	return Rect2(Vector2(POPUP_BUTTON_X, POPUP_BUTTON_START_Y), POPUP_BUTTON_SIZE)


func _popup_restart_rect() -> Rect2:
	return Rect2(Vector2(POPUP_BUTTON_X, POPUP_BUTTON_START_Y + POPUP_BUTTON_STEP), POPUP_BUTTON_SIZE)


func _popup_settings_rect() -> Rect2:
	return Rect2(Vector2(POPUP_BUTTON_X, POPUP_BUTTON_START_Y + POPUP_BUTTON_STEP * 2.0), POPUP_BUTTON_SIZE)


func _popup_how_to_play_rect() -> Rect2:
	return Rect2(Vector2(POPUP_BUTTON_X, POPUP_BUTTON_START_Y + POPUP_BUTTON_STEP * 3.0), POPUP_BUTTON_SIZE)


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
	draw_texture_rect(MENU_RESUME_TEXTURE, _popup_resume_rect(), false)
	draw_texture_rect(MENU_RESTART_TEXTURE, _popup_restart_rect(), false)
	draw_texture_rect(MENU_SETTINGS_TEXTURE, _popup_settings_rect(), false)
	draw_texture_rect(MENU_HOW_TO_PLAY_TEXTURE, _popup_how_to_play_rect(), false)


func _draw_settings_popup() -> void:
	# First pass keeps the existing selectors behind a compact Settings hub.
	_draw_rounded_panel(SETTINGS_POPUP_RECT, Color(PANEL, 0.99), Color(CREAM, 0.82), 3.0, 18.0)
	_draw_rounded_panel(SETTINGS_POPUP_RECT.grow(-8.0), Color(PANEL, 0.99), Color(AMBER, 0.26), 1.0, 14.0)
	_draw_centered_label("SETTINGS", Vector2(W * 0.5, 415.0), 27, CREAM)
	_draw_centered_label("MISSION CONTROL", Vector2(W * 0.5, 450.0), 12, Color(AQUA, 0.82))
	_draw_menu_action_button(_settings_backgrounds_rect(), "BACKGROUNDS", PHASE_BLUE)
	_draw_menu_action_button(_settings_ball_sounds_rect(), "BALL SOUNDS", AMBER)
	_draw_menu_action_button(_settings_back_rect(), "BACK", AQUA)


func _handle_menu_press(pointer: Vector2) -> void:
	if menu_page == 0:
		if _popup_resume_rect().has_point(pointer):
			menu_open = false
			queue_redraw()
			return
		if _popup_restart_rect().has_point(pointer):
			menu_open = false
			_start_new_run()
			return
		if _popup_settings_rect().has_point(pointer):
			menu_page = 4
			queue_redraw()
			return
		if _popup_how_to_play_rect().has_point(pointer):
			menu_page = 1
			queue_redraw()
			return
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
