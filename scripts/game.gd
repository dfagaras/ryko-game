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

var score: int = 0


func _update_responsive_layout() -> void:
	# Keep the established safe-area/footer behavior, but reserve the real
	# aspect-ratio height of the full-width illustrated header.
	super._update_responsive_layout()
	var safe_insets := _safe_vertical_insets(layout_viewport_size)
	var header_target_y := safe_insets.x
	var footer_target_y := layout_viewport_size.y - safe_insets.y - 18.0 - 152.0
	footer_target_y = maxf(1110.0, footer_target_y)

	layout_header_y_offset = header_target_y
	layout_footer_y_offset = footer_target_y - 1110.0

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
