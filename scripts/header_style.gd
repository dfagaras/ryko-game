extends "res://scripts/game.gd"

const OXANIUM_BASE: Font = preload("res://assets/fonts/Oxanium-VariableFont_wght.ttf")

# Optical windows tuned to the actual blank displays in finalboard.png.
const ROUND_VALUE_RECT_V2 := Rect2(44.0, 127.0, 86.0, 38.0)
const SCORE_VALUE_RECT_V2 := Rect2(204.0, 124.0, 258.0, 53.0)
const BALLS_VALUE_RECT_V2 := Rect2(641.0, 137.0, 34.0, 34.0)

var round_font := FontVariation.new()
var score_font := FontVariation.new()
var balls_font := FontVariation.new()


func _ready() -> void:
	_configure_header_fonts()
	super._ready()


func _configure_header_fonts() -> void:
	var text_server := TextServerManager.get_primary_interface()
	var weight_tag := text_server.name_to_tag("wght")

	round_font.base_font = OXANIUM_BASE
	round_font.variation_opentype = {weight_tag: 650.0}

	score_font.base_font = OXANIUM_BASE
	score_font.variation_opentype = {weight_tag: 750.0}

	balls_font.base_font = OXANIUM_BASE
	balls_font.variation_opentype = {weight_tag: 650.0}


func _draw_header() -> void:
	draw_texture_rect(HEADER_TEXTURE, HEADER_RECT, false)

	_draw_header_value_v2(str(turn), ROUND_VALUE_RECT_V2, round_font, 30, 20, CREAM, -0.5)
	_draw_header_value_v2(_format_score(score), SCORE_VALUE_RECT_V2, score_font, 40, 24, AQUA, 0.0)
	_draw_header_value_v2(str(ball_count), BALLS_VALUE_RECT_V2, balls_font, 29, 18, CREAM, 0.8)


func _draw_header_value_v2(
	text: String,
	value_rect: Rect2,
	font: Font,
	preferred_font_size: int,
	minimum_font_size: int,
	color: Color,
	optical_y_offset: float
) -> void:
	var font_size := preferred_font_size
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	while font_size > minimum_font_size and (
		text_size.x > value_rect.size.x - 4.0
		or font.get_height(font_size) > value_rect.size.y - 2.0
	):
		font_size -= 1
		text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	# draw_string uses a baseline, so center from the font's actual ascent/descent
	# instead of the previous text-height approximation. This keeps ROUND and
	# BALLS vertically consistent even as their digit count changes.
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline_y := value_rect.get_center().y + (ascent - descent) * 0.5 + optical_y_offset

	draw_string(
		font,
		Vector2(value_rect.position.x, baseline_y),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		value_rect.size.x,
		font_size,
		color
	)
