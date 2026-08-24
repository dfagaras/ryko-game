extends "res://scripts/main.gd"

# Header assets follow the same pattern as the footer: normal imported PNGs,
# preloaded once and drawn directly. Only the values are dynamic.
const HEADER_BOARD_TEXTURE: Texture2D = preload("res://assets/ui/board.png")
const HEADER_ROUND_TEXTURE: Texture2D = preload("res://assets/ui/round.png")
const HEADER_SCORE_TEXTURE: Texture2D = preload("res://assets/ui/score.png")
const HEADER_BALLS_TEXTURE: Texture2D = preload("res://assets/ui/bals.png")

const HEADER_HEIGHT := 207.0
const HEADER_BOARD_RECT := Rect2(50.0, 0.0, 620.0, 206.6667)
const HEADER_ROUND_RECT := Rect2(61.0, 82.0, 138.0, 103.5)
const HEADER_SCORE_RECT := Rect2(199.0, 75.0, 321.0, 107.0)
const HEADER_BALLS_RECT := Rect2(520.0, 82.0, 138.0, 103.5)

var score: int = 0


func _update_responsive_layout() -> void:
	# Start from the proven responsive layout and only reserve the extra height
	# required by the non-stretched illustrated header.
	super._update_responsive_layout()
	var safe_insets := _safe_vertical_insets(layout_viewport_size)
	var header_target_y := safe_insets.x
	var footer_target_y := layout_viewport_size.y - safe_insets.y - 152.0
	footer_target_y = maxf(1110.0, footer_target_y)

	layout_header_y_offset = header_target_y
	layout_footer_y_offset = footer_target_y - 1110.0

	var available_top := header_target_y + HEADER_HEIGHT
	var available_bottom := footer_target_y
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
	# Preserve each source asset's aspect ratio exactly. The board is the base;
	# the three approved illustrated modules are layered on top.
	draw_texture_rect(HEADER_BOARD_TEXTURE, HEADER_BOARD_RECT, false)
	draw_texture_rect(HEADER_ROUND_TEXTURE, HEADER_ROUND_RECT, false)
	draw_texture_rect(HEADER_SCORE_TEXTURE, HEADER_SCORE_RECT, false)
	draw_texture_rect(HEADER_BALLS_TEXTURE, HEADER_BALLS_RECT, false)

	# The artwork already contains all static labels/icons. Only values change.
	var round_text := str(turn)
	var balls_text := str(ball_count)
	_draw_centered_label(round_text, Vector2(130.0, 149.0), 25 if round_text.length() <= 2 else 21, CREAM)
	_draw_centered_label(_format_score(score), Vector2(348.0, 139.0), 25, AQUA)
	_draw_centered_label(balls_text, Vector2(624.0, 149.0), 24 if balls_text.length() <= 2 else 20, CREAM)


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
