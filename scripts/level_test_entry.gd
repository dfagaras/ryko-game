extends "res://scripts/level_test_game.gd"

const RUNTIME_LEVEL_KEY := "ryko/runtime_test_level_path"
const BLOCK_COLOR_PALETTE := {
	"amber": Color("e7ae43"),
	"aqua": Color("55b8b1"),
	"coral": Color("e96b5f"),
	"toxic": Color("9ac85b"),
	"violet": Color("9477b5"),
	"ion_blue": Color("55bfe3"),
}
var _pending_block_color := "amber"


func _ready() -> void:
	super._ready()
	var path := str(ProjectSettings.get_setting(RUNTIME_LEVEL_KEY, ""))
	if path.is_empty():
		return
	call_deferred("_load_authored_level", path)


func _load_authored_level(path: String) -> void:
	super._load_authored_level(path)
	if not authored_mode:
		return
	var top_row_variant: Variant = authored_level.get("topRow", [])
	if typeof(top_row_variant) != TYPE_ARRAY:
		return
	for entity_variant in top_row_variant as Array:
		if typeof(entity_variant) != TYPE_DICTIONARY:
			continue
		var entity := (entity_variant as Dictionary).duplicate(true)
		entity["row"] = -1
		_spawn_authored_entity(entity, -1)
	queue_redraw()


func _spawn_authored_entity(entity: Dictionary, row: int) -> void:
	_pending_block_color = str(entity.get("color", "amber"))
	if not BLOCK_COLOR_PALETTE.has(_pending_block_color):
		_pending_block_color = "amber"
	var before := blocks.size()
	super._spawn_authored_entity(entity, row)
	if blocks.size() > before:
		blocks[blocks.size() - 1]["color"] = _pending_block_color


func _draw_blocks() -> void:
	super._draw_blocks()
	if not authored_mode:
		return
	var scale := float(authored_profile.get("visual_scale", 1.0))
	var line_width := maxf(1.0, 4.0 * scale)
	for item in blocks:
		var color_name := str(item.get("color", "amber"))
		var accent: Color = BLOCK_COLOR_PALETTE.get(color_name, BLOCK_COLOR_PALETTE["amber"])
		if String(item.get("shape", "square")) == "triangle":
			var points := _triangle_local_points(String(item.get("orientation", "top_left")))
			var translated := PackedVector2Array()
			for point in points:
				translated.append(Vector2(item["position"]) + point)
			translated.append(translated[0])
			draw_polyline(translated, accent, line_width, true)
		else:
			var cell := _active_cell()
			var rect := Rect2(Vector2(item["position"]) - Vector2.ONE * cell * 0.5, Vector2.ONE * cell)
			draw_rect(rect, accent, false, line_width, true)
