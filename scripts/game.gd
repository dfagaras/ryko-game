extends "res://scripts/main.gd"

# Static 2D header artwork. Only the changing game values are rendered at runtime.
const HEADER_ROUND_TEXTURE: Texture2D = preload("res://assets/ui/header_round.svg")
const HEADER_SCORE_TEXTURE: Texture2D = preload("res://assets/ui/header_score_tv.svg")
const HEADER_BALLS_TEXTURE: Texture2D = preload("res://assets/ui/header_balls.svg")

var score: int = 0


func _start_new_run() -> void:
	score = 0
	super._start_new_run()


func _hit_block(body: StaticBody2D) -> void:
	# Determine the kill before the parent clears the block reference. Every
	# destruction path ultimately reaches _hit_block(), including powers.
	var index := int(body.get_meta("block_index", -1))
	var destroys_block := false
	if index >= 0 and index < blocks.size():
		var item := blocks[index]
		var block_body: StaticBody2D = item["body"] as StaticBody2D
		if is_instance_valid(block_body):
			destroys_block = int(item["hp"]) == 1

	super._hit_block(body)

	if destroys_block:
		# Intentionally simple MVP scoring rule agreed for RYKO:
		# score += blocks destroyed * current round * 10
		score += turn * 10


func _draw_header() -> void:
	# Match the approved footer language: one flat, illustrated junk-space HUD,
	# with the center CRT carrying the visual weight and compact side modules.
	var round_rect := Rect2(Vector2(28.0, 24.0), Vector2(148.0, 118.0))
	var score_rect := Rect2(Vector2(188.0, 18.0), Vector2(344.0, 130.0))
	var balls_rect := Rect2(Vector2(544.0, 24.0), Vector2(148.0, 118.0))

	draw_texture_rect(HEADER_ROUND_TEXTURE, round_rect, false)
	draw_texture_rect(HEADER_SCORE_TEXTURE, score_rect, false)
	draw_texture_rect(HEADER_BALLS_TEXTURE, balls_rect, false)

	# Labels and values stay dynamic so artwork never needs regeneration.
	_draw_centered_label("ROUND", Vector2(round_rect.get_center().x, 52.0), 11, Color("#f2e3bb"))
	_draw_centered_label(str(turn), Vector2(round_rect.get_center().x, 91.0), 31, Color("#e7ae43"))

	_draw_centered_label("SCORE", Vector2(score_rect.get_center().x, 49.0), 11, Color("#f2e3bb"))
	_draw_centered_label(_format_score(score), Vector2(score_rect.get_center().x, 91.0), 27, Color("#55b8b1"))

	_draw_centered_label("BALLS", Vector2(balls_rect.get_center().x, 52.0), 11, Color("#f2e3bb"))
	_draw_centered_label("× %d" % ball_count, Vector2(balls_rect.get_center().x + 8.0, 91.0), 27, Color("#f2e3bb"))


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
