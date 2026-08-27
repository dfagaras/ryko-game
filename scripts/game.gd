extends "res://scripts/main.gd"

# Final header follows the same asset pattern as the footer: one normal PNG
# preloaded by Godot, with only the changing values rendered on top.
const HEADER_TEXTURE: Texture2D = preload("res://assets/ui/finalboard.png")
const HEADER_FONT: Font = preload("res://assets/fonts/Oxanium-VariableFont_wght.ttf")

# finalboard.png is exactly 3:1 (2172x724), so 720x240 fills the logical phone
# width without stretching the artwork in either direction.
const HEADER_HEIGHT := 240.0
const HEADER_RECT := Rect2(0.0, 0.0, W, HEADER_HEIGHT)

# Value windows mapped directly from the blank display areas in finalboard.png.
# Text is centered inside these rectangles at its natural width; it is never
# horizontally stretched. Font size only decreases when the value stops fitting.
const ROUND_VALUE_RECT := Rect2(44.0, 129.0, 86.0, 36.0)
const SCORE_VALUE_RECT := Rect2(204.0, 126.0, 258.0, 49.0)
const BALLS_VALUE_RECT := Rect2(641.0, 135.0, 34.0, 34.0)

const FOOTER_HEIGHT := 152.0
const FOOTER_Y := 1110.0
const FOOTER_CONTROL_SIZE := 108.0
const FOOTER_CONTROL_CENTER_Y := 1175.0
const FOOTER_SIDE_SCOPE_GAP := 116.0

# Gameplay music stays deliberately below the ball/block SFX. Two players are
# used so tracks can overlap for a smooth equal-power crossfade instead of
# stopping and starting abruptly.
const MUSIC_TRACKS := [
	preload("res://assets/music/ryko_track_01.mp3"),
	preload("res://assets/music/ryko_track_02.mp3"),
	preload("res://assets/music/ryko_track_03.mp3"),
	preload("res://assets/music/ryko_track_04.mp3"),
	preload("res://assets/music/ryko_track_05.mp3"),
	preload("res://assets/music/ryko_track_06.mp3")
]
const MUSIC_VOLUME_DB := -19.0
const MUSIC_SILENT_DB := -80.0
const MUSIC_CROSSFADE_SECONDS := 6.0

var score: int = 0
var music_players: Array[AudioStreamPlayer] = []
var music_order: Array[int] = []
var music_order_position := 0
var music_active_player := 0
var music_current_track_index := -1
var music_next_track_index := -1
var music_crossfade_active := false
var music_crossfade_elapsed := 0.0
var music_rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_setup_music_playlist()


func _process(delta: float) -> void:
	_update_music_playlist(delta)


func _setup_music_playlist() -> void:
	music_rng.randomize()
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % (index + 1)
		player.volume_db = MUSIC_SILENT_DB
		add_child(player)
		music_players.append(player)

	_build_music_order(-1)
	music_active_player = 0
	music_current_track_index = _take_next_music_track()
	var first_player := music_players[music_active_player]
	first_player.stream = MUSIC_TRACKS[music_current_track_index]
	first_player.volume_db = MUSIC_VOLUME_DB
	first_player.play()


func _build_music_order(previous_track: int) -> void:
	music_order.clear()
	for index in range(MUSIC_TRACKS.size()):
		music_order.append(index)

	# Fisher-Yates with a dedicated RNG keeps music randomization independent of
	# the seeded gameplay row/block generator.
	for index in range(music_order.size() - 1, 0, -1):
		var swap_index := music_rng.randi_range(0, index)
		var value := music_order[index]
		music_order[index] = music_order[swap_index]
		music_order[swap_index] = value

	# A freshly shuffled cycle must never immediately repeat the track that just
	# finished in the previous cycle.
	if music_order.size() > 1 and previous_track >= 0 and music_order[0] == previous_track:
		var value := music_order[0]
		music_order[0] = music_order[1]
		music_order[1] = value
	music_order_position = 0


func _take_next_music_track() -> int:
	if music_order_position >= music_order.size():
		_build_music_order(music_current_track_index)
	var track_index := music_order[music_order_position]
	music_order_position += 1
	return track_index


func _update_music_playlist(delta: float) -> void:
	if music_players.size() != 2 or music_current_track_index < 0:
		return

	if music_crossfade_active:
		music_crossfade_elapsed += delta
		var ratio := clampf(music_crossfade_elapsed / MUSIC_CROSSFADE_SECONDS, 0.0, 1.0)
		var base_linear := db_to_linear(MUSIC_VOLUME_DB)
		var outgoing_gain := cos(ratio * PI * 0.5) * base_linear
		var incoming_gain := sin(ratio * PI * 0.5) * base_linear
		var outgoing := music_players[music_active_player]
		var incoming_index := 1 - music_active_player
		var incoming := music_players[incoming_index]
		outgoing.volume_db = linear_to_db(maxf(outgoing_gain, 0.0001))
		incoming.volume_db = linear_to_db(maxf(incoming_gain, 0.0001))

		if ratio >= 1.0:
			outgoing.stop()
			outgoing.volume_db = MUSIC_SILENT_DB
			music_active_player = incoming_index
			music_current_track_index = music_next_track_index
			music_next_track_index = -1
			music_crossfade_active = false
			music_crossfade_elapsed = 0.0
			incoming.volume_db = MUSIC_VOLUME_DB
		return

	var active_player := music_players[music_active_player]
	if active_player.stream == null:
		return

	var stream_length := active_player.stream.get_length()
	var remaining := stream_length - active_player.get_playback_position()
	if stream_length > MUSIC_CROSSFADE_SECONDS and remaining <= MUSIC_CROSSFADE_SECONDS:
		_start_music_crossfade()
	elif not active_player.playing:
		# Defensive fallback for a stream that ends before its reported duration.
		_start_music_crossfade()


func _start_music_crossfade() -> void:
	if music_crossfade_active or music_players.size() != 2:
		return
	music_next_track_index = _take_next_music_track()
	var incoming_index := 1 - music_active_player
	var incoming := music_players[incoming_index]
	incoming.stop()
	incoming.stream = MUSIC_TRACKS[music_next_track_index]
	incoming.volume_db = MUSIC_SILENT_DB
	incoming.play()
	music_crossfade_elapsed = 0.0
	music_crossfade_active = true


func _update_responsive_layout() -> void:
	# Keep the established safe-area/footer behavior, but reserve the real
	# aspect-ratio height of the full-width illustrated header.
	super._update_responsive_layout()
	var safe_insets := _safe_vertical_insets(layout_viewport_size)
	var header_target_y := safe_insets.x
	var footer_target_y := layout_viewport_size.y - safe_insets.y - 18.0 - FOOTER_HEIGHT
	footer_target_y = maxf(FOOTER_Y, footer_target_y)

	layout_header_y_offset = header_target_y
	layout_footer_y_offset = footer_target_y - FOOTER_Y

	var available_top := header_target_y + HEADER_HEIGHT
	var available_bottom := footer_target_y - 14.0
	var board_height := LAUNCH_LINE_Y - BOARD_TOP
	var centered_board_y := available_top
	if available_bottom - available_top > board_height:
		centered_board_y += (available_bottom - available_top - board_height) * 0.5
	layout_board_y_offset = centered_board_y - BOARD_TOP


func _start_new_run() -> void:
	score = 0
	super._start_new_run()


func _hit_block(body: StaticBody2D) -> void:
	# Every destruction path, including Ion, Ghost and Supernova, ends here.
	var index := int(body.get_meta("block_index", -1))
	var destroys_block := false
	if index >= 0 and index < blocks.size():
		var item := blocks[index]
		var block_body: StaticBody2D = item["body"] as StaticBody2D
		if is_instance_valid(block_body):
			destroys_block = int(item["hp"]) == 1

	super._hit_block(body)

	if destroys_block:
		# Simple MVP score: blocks destroyed × current round × 10.
		score += turn * 10


func _draw_header() -> void:
	draw_texture_rect(HEADER_TEXTURE, HEADER_RECT, false)

	var round_text := str(turn)
	var score_text := _format_score(score)
	var balls_text := str(ball_count)

	_draw_header_value(round_text, ROUND_VALUE_RECT, 29, 19, CREAM)
	_draw_header_value(score_text, SCORE_VALUE_RECT, 34, 20, AQUA)
	_draw_header_value(balls_text, BALLS_VALUE_RECT, 27, 17, CREAM)


func _draw_header_value(
	text: String,
	value_rect: Rect2,
	preferred_font_size: int,
	minimum_font_size: int,
	color: Color
) -> void:
	var font_size := preferred_font_size
	var text_size := HEADER_FONT.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	)

	# Preserve the natural glyph width. Only reduce font size when the complete
	# value genuinely no longer fits inside its physical display window.
	while font_size > minimum_font_size and (
		text_size.x > value_rect.size.x - 4.0
		or text_size.y > value_rect.size.y - 2.0
	):
		font_size -= 1
		text_size = HEADER_FONT.get_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		)

	var center := value_rect.get_center()
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(
		HEADER_FONT,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)


func _footer_rect() -> Rect2:
	# The footer is intentionally viewport-wide. Because the game content itself
	# is centered inside a logical 720px canvas, extend the local footer in both
	# directions by layout_content_x to reach the physical phone edges.
	return Rect2(
		Vector2(-layout_content_x, FOOTER_Y),
		Vector2(layout_viewport_size.x, FOOTER_HEIGHT)
	)


func _draw_footer() -> void:
	_draw_radio_console(_footer_rect())


func _menu_button_rect() -> Rect2:
	var footer := _footer_rect()
	var center := Vector2(footer.position.x + 61.0, FOOTER_CONTROL_CENTER_Y)
	return Rect2(center - Vector2(58.0, 67.0), Vector2(116.0, 134.0))


func _recall_button_rect() -> Rect2:
	var footer := _footer_rect()
	var center := Vector2(footer.end.x - 61.0, FOOTER_CONTROL_CENTER_Y)
	return Rect2(center - Vector2(58.0, 67.0), Vector2(116.0, 134.0))


func _radio_scope_outer_rect() -> Rect2:
	var footer := _footer_rect()
	# RADIO title/ornaments were removed, so the glass can use almost the full
	# footer height. Side controls keep a small breathing gap from the housing.
	return Rect2(
		Vector2(footer.position.x + FOOTER_SIDE_SCOPE_GAP, FOOTER_Y + 10.0),
		Vector2(footer.size.x - FOOTER_SIDE_SCOPE_GAP * 2.0, 126.0)
	)


func _radio_speed_track_rect() -> Rect2:
	var scope := _radio_scope_outer_rect()
	# The waveform gets a much taller usable window. The scale sits underneath
	# it inside the same glass so the needle, labels and interaction all share
	# the exact same horizontal geometry.
	return Rect2(
		scope.position + Vector2(24.0, 13.0),
		Vector2(scope.size.x - 48.0, 64.0)
	)


func _radio_speed_interaction_rect() -> Rect2:
	return _radio_scope_outer_rect().grow(-4.0)


func _draw_radio_console(rect: Rect2) -> void:
	# Keep the established recycled-space-junk faceplate, but let it touch both
	# phone edges and dedicate the freed RADIO title area to the oscilloscope.
	_draw_rounded_panel(Rect2(rect.position + Vector2(0.0, 5.0), rect.size), Color(PAPER_SHADOW, 0.90), Color(PAPER_SHADOW, 0.90), 0.0, 8.0)
	_draw_rounded_panel(rect, Color(PANEL, 1.0), Color(CREAM, 0.82), 3.0, 8.0)
	_draw_rounded_panel(rect.grow(-7.0), Color(PANEL, 1.0), Color(AMBER, 0.26), 1.0, 5.0)
	for screw in [
		rect.position + Vector2(13.0, 13.0),
		Vector2(rect.end.x - 13.0, rect.position.y + 13.0),
		Vector2(rect.position.x + 13.0, rect.end.y - 13.0),
		rect.end - Vector2(13.0, 13.0)
	]:
		_draw_machine_screw(screw, 6.0)

	var menu_center := Vector2(rect.position.x + 61.0, FOOTER_CONTROL_CENTER_Y)
	var recall_center := Vector2(rect.end.x - 61.0, FOOTER_CONTROL_CENTER_Y)
	_draw_footer_menu_asset(menu_center)

	var scope_outer := _radio_scope_outer_rect()
	draw_texture_rect_region(RADIO_WAVEBOARD_TEXTURE, scope_outer, RADIO_WAVEBOARD_SOURCE_RECT)
	var wave_rect := _radio_speed_track_rect()
	_draw_radio_waveform(wave_rect)

	# Remove raster graduations from the source artwork and redraw only the five
	# real speed stops. The mask is derived from the enlarged glass, not fixed px.
	var scale_mask := Rect2(
		Vector2(scope_outer.position.x + 8.0, wave_rect.end.y + 2.0),
		Vector2(scope_outer.size.x - 16.0, scope_outer.end.y - wave_rect.end.y - 7.0)
	)
	draw_rect(scale_mask, Color("#06191d", 0.94), true)
	_draw_radio_speed_control(scope_outer, wave_rect)
	_draw_footer_recall_asset(recall_center)


func _draw_footer_menu_asset(center: Vector2) -> void:
	var asset_rect := Rect2(
		center - Vector2(FOOTER_CONTROL_SIZE, FOOTER_CONTROL_SIZE) * 0.5,
		Vector2(FOOTER_CONTROL_SIZE, FOOTER_CONTROL_SIZE)
	)
	draw_texture_rect(MENU_SPEAKER_TEXTURE, asset_rect, false)
	_draw_centered_label("MENU", Vector2(center.x, center.y + 58.0), 12, Color(CREAM, 0.92))


func _draw_footer_recall_asset(center: Vector2) -> void:
	var enabled := state == TurnState.FIRING
	var asset_rect := Rect2(
		center - Vector2(FOOTER_CONTROL_SIZE, FOOTER_CONTROL_SIZE) * 0.5,
		Vector2(FOOTER_CONTROL_SIZE, FOOTER_CONTROL_SIZE)
	)
	var tint := Color.WHITE if enabled else Color(0.72, 0.76, 0.74, 0.58)
	draw_texture_rect(RECALL_KNOB_TEXTURE, asset_rect, false, tint)
	_draw_centered_label("RECALL", Vector2(center.x, center.y + 58.0), 12, Color(CREAM, 0.92 if enabled else 0.46))


func _format_score(value: int) -> String:
	var digits := str(maxi(0, value))
	var formatted := ""
	var group_size := 0
	for index in range(digits.length() - 1, -1, -1):
		formatted = digits.substr(index, 1) + formatted
		group_size += 1
		if group_size == 3 and index > 0:
			formatted = "," + formatted
			group_size = 0
	return formatted
