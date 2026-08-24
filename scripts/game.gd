extends "res://scripts/main.gd"

const HEADER_ART_PATH := "res://assets/ui/header_full_approved.webp.b64"

var score: int = 0
var header_art_texture: Texture2D


func _ready() -> void:
	_load_header_art()
	super._ready()


func _load_header_art() -> void:
	var encoded := FileAccess.get_file_as_string(HEADER_ART_PATH).strip_edges()
	if encoded.is_empty():
		push_error("RYKO header artwork is missing or empty")
		return
	var raw := Marshalls.base64_to_raw(encoded)
	var image := Image.new()
	var load_error := image.load_webp_from_buffer(raw)
	if load_error != OK:
		push_error("RYKO header artwork could not be decoded: %s" % load_error)
		return
	header_art_texture = ImageTexture.create_from_image(image)


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
	# Use the exact approved illustrated recycled-space-junk header as one
	# production asset. Only the three changing values are painted dynamically.
	var header_rect := Rect2(Vector2(28.0, 18.0), Vector2(664.0, 136.0))
	if is_instance_valid(header_art_texture):
		draw_texture_rect(header_art_texture, header_rect, false)
	else:
		# Safe fallback so a corrupt asset never hides gameplay information.
		_draw_panel_frame(header_rect, Color(PANEL, 0.985), Color(CREAM, 0.78), 3.0)

	# Cover only the baked demo values from the concept image. These masks sit
	# inside the illustrated CRT/display glass and preserve all surrounding art.
	var screen_fill := Color("#06191d", 0.97)
	_draw_rounded_panel(Rect2(Vector2(73.0, 76.0), Vector2(82.0, 43.0)), screen_fill, Color(AQUA, 0.20), 1.0, 4.0)
	_draw_rounded_panel(Rect2(Vector2(250.0, 67.0), Vector2(220.0, 55.0)), screen_fill, Color(AQUA, 0.18), 1.0, 5.0)
	_draw_rounded_panel(Rect2(Vector2(618.0, 76.0), Vector2(55.0, 43.0)), screen_fill, Color(AQUA, 0.18), 1.0, 4.0)

	_draw_centered_label(str(turn), Vector2(114.0, 97.0), 29, CREAM)
	_draw_centered_label(_format_score(score), Vector2(360.0, 95.0), 29, AQUA)
	_draw_centered_label(str(ball_count), Vector2(645.0, 97.0), 27, CREAM)


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
