extends "res://scripts/main.gd"

# Header follows the exact same runtime pattern as the footer UI assets:
# Godot imports a normal PNG and the game draws that texture directly.
const HEADER_ART_TEXTURE: Texture2D = preload("res://assets/ui/header_composite_2d.png")

var score: int = 0


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
	# The complete illustrated recycled-space-junk header is a static 2D asset.
	# It already contains ROUND / SCORE / BALLS labels and blank display glass.
	# Only the three changing values are rendered by Godot.
	var header_rect := Rect2(Vector2(28.0, 18.0), Vector2(664.0, 158.0))
	draw_texture_rect(HEADER_ART_TEXTURE, header_rect, false)

	_draw_centered_label(str(turn), Vector2(113.0, 104.0), 29, CREAM)
	_draw_centered_label(_format_score(score), Vector2(356.0, 96.0), 28, AQUA)
	_draw_centered_label(str(ball_count), Vector2(640.0, 104.0), 26, CREAM)


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
