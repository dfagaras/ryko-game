extends "res://scripts/level_test_game.gd"

const RUNTIME_LEVEL_KEY := "ryko/runtime_test_level_path"
# Music preference is process-wide and must survive the switch from Infinity to an authored level scene.
const BACKGROUND_MUSIC_KEY := "ryko/background_music_enabled"
const MUSIC_SILENT_DB := -80.0
const MUSIC_DEFAULT_DB := -19.0
const MUSIC_VOLUME_META := "ryko_music_volume_before_mute"
const BLOCK_COLOR_PALETTE := {
	"amber": Color("e7ae43"),
	"aqua": Color("55b8b1"),
	"coral": Color("e96b5f"),
	"toxic": Color("9ac85b"),
	"violet": Color("9477b5"),
	"ion_blue": Color("55bfe3"),
}
const PIXEL_COLOR_NAMES := {
	"M": "amber",
	"A": "aqua",
	"C": "coral",
	"T": "toxic",
	"V": "violet",
	"I": "ion_blue",
}
var _pending_block_color := "amber"


func _ready() -> void:
	super._ready()
	_apply_background_music_state()
	call_deferred("_apply_background_music_state")
	var path := str(ProjectSettings.get_setting(RUNTIME_LEVEL_KEY, ""))
	if path.is_empty():
		return
	call_deferred("_load_authored_level", path)


func _apply_background_music_state() -> void:
	var enabled := bool(ProjectSettings.get_setting(BACKGROUND_MUSIC_KEY, true))
	for player in music_players:
		if not is_instance_valid(player):
			continue
		if enabled:
			player.stream_paused = false
			if player.has_meta(MUSIC_VOLUME_META):
				player.volume_db = float(player.get_meta(MUSIC_VOLUME_META))
				player.remove_meta(MUSIC_VOLUME_META)
			elif player.volume_db <= MUSIC_SILENT_DB + 0.1:
				player.volume_db = MUSIC_DEFAULT_DB
		else:
			if not player.has_meta(MUSIC_VOLUME_META):
				player.set_meta(MUSIC_VOLUME_META, player.volume_db)
			player.volume_db = MUSIC_SILENT_DB
			player.stream_paused = true


func _load_authored_level(path: String) -> void:
	var pixel_rows := _read_pixel_rows(path)
	super._load_authored_level(path)
	if not authored_mode:
		return

	var top_row_variant: Variant = authored_level.get("topRow", [])
	if typeof(top_row_variant) == TYPE_ARRAY:
		for entity_variant in top_row_variant as Array:
			if typeof(entity_variant) != TYPE_DICTIONARY:
				continue
			var entity := (entity_variant as Dictionary).duplicate(true)
			entity["row"] = -1
			_spawn_authored_entity(entity, -1)

	_spawn_pixel_rows(pixel_rows)
	queue_redraw()


func _read_pixel_rows(path: String) -> Array[String]:
	var result: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return result
	var raw: Dictionary = json.data
	var rows_variant: Variant = raw.get("pixelRows", [])
	if typeof(rows_variant) != TYPE_ARRAY:
		return result
	for row_variant in rows_variant as Array:
		result.append(String(row_variant))
	return result


func _spawn_pixel_rows(pixel_rows: Array[String]) -> void:
	if pixel_rows.is_empty():
		return
	var row_limit := mini(pixel_rows.size(), int(authored_profile.get("rows", 9)))
	var column_limit := int(authored_profile.get("columns", 7))
	for row in range(row_limit):
		var row_text := pixel_rows[row]
		for column in range(mini(row_text.length(), column_limit)):
			var symbol := row_text.substr(column, 1)
			if not PIXEL_COLOR_NAMES.has(symbol) or _has_block_at(column, row):
				continue
			_spawn_authored_entity({
				"column": column,
				"row": row,
				"kind": "block",
				"shape": "square",
				"variant": "normal",
				"hp": 50,
				"color": PIXEL_COLOR_NAMES[symbol],
			}, row)


func _has_block_at(column: int, row: int) -> bool:
	for item in blocks:
		if int(item.get("column", -1)) == column and int(item.get("row", -1)) == row:
			return true
	return false


func _spawn_authored_entity(entity: Dictionary, row: int) -> void:
	_pending_block_color = str(entity.get("color", "amber"))
	if not BLOCK_COLOR_PALETTE.has(_pending_block_color):
		_pending_block_color = "amber"
	var before := blocks.size()
	super._spawn_authored_entity(entity, row)
	if blocks.size() > before:
		blocks[blocks.size() - 1]["color"] = _pending_block_color


func _draw_blocks() -> void:
	if not authored_mode:
		super._draw_blocks()
		return

	var cell := _active_cell()
	var scale := float(authored_profile.get("visual_scale", 1.0))
	var outline := maxf(1.0, BLOCK_OUTLINE_WIDTH * scale)
	var font_size := maxi(7, int(round(24.0 * scale)))

	for item in blocks:
		var body: StaticBody2D = item["body"] as StaticBody2D
		if not is_instance_valid(body):
			continue

		var center: Vector2 = item["position"]
		var hp := str(item["hp"])
		var variant := String(item.get("variant", "normal"))
		var phase_active := bool(item.get("phase_active", true))
		var alpha := 1.0 if phase_active else 0.28
		var label_center := center
		var color_name := str(item.get("color", "amber"))
		var authored_accent: Color = BLOCK_COLOR_PALETTE.get(color_name, BLOCK_COLOR_PALETTE["amber"])

		if String(item["shape"]) == "square":
			var rect := Rect2(center - Vector2.ONE * cell * 0.5, Vector2.ONE * cell)
			var border := authored_accent
			if variant == "dense": border = DENSE_ORANGE
			elif variant == "regenerative": border = REGENERATIVE_GREEN
			elif variant == "black_hole": border = VOID_PURPLE
			elif variant == "phase": border = Color(PHASE_BLUE, alpha)
			draw_rect(rect, border, true)
			draw_rect(rect.grow(-outline), PANEL.lerp(border, 0.16), true)
			if variant == "dense": _draw_cell_texture(ICON_BLOCK_DENSE, rect)
			elif variant == "regenerative": _draw_cell_texture(ICON_BLOCK_REGENERATIVE, rect)
			elif variant == "black_hole":
				_draw_cell_texture(ICON_BLOCK_BLACK_HOLE, rect)
				_draw_black_hole_sides(rect, item.get("absorbing_sides", []))
			elif variant == "phase": _draw_cell_texture(ICON_BLOCK_PHASE, rect, alpha)
		else:
			var points := PackedVector2Array()
			var centroid := Vector2.ZERO
			for local in _triangle_local_points(String(item["orientation"])):
				points.append(center + local)
				centroid += local
			centroid /= 3.0
			label_center = center + centroid
			var inner := PackedVector2Array()
			for local in _triangle_inner_local_points(String(item["orientation"])):
				inner.append(center + local)
			draw_colored_polygon(points, authored_accent)
			draw_colored_polygon(inner, PANEL.lerp(authored_accent, 0.16))

		_draw_centered_label(hp, label_center, maxi(6, font_size - (2 if String(item["shape"]) == "triangle" else 0)), CREAM)
