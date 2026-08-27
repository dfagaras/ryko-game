extends "res://scripts/level_test_entry.gd"

const MISSION_VARIANT := "mission_core"
const MISSION_WIN_CONDITION := "destroy_all_objectives"
const MISSION_FRAME: Texture2D = preload("res://assets/ui/mission_block/rama.png")
const MISSION_RYKO_FRAMES: Array[Texture2D] = [
	preload("res://assets/ui/mission_block/ricostatic.png"),
	preload("res://assets/ui/mission_block/ricoimpingelateral.png"),
	preload("res://assets/ui/mission_block/ricoimpingelateral1.png"),
	preload("res://assets/ui/mission_block/ricoimpingesus.png"),
]
const MISSION_FRAME_SECONDS := 0.28


func _authored_uses_mission_objectives() -> bool:
	if not authored_mode:
		return false
	var rules_variant: Variant = authored_level.get("rules", {})
	if typeof(rules_variant) != TYPE_DICTIONARY:
		return false
	return String((rules_variant as Dictionary).get("winCondition", "clear_all_content")) == MISSION_WIN_CONDITION


func _live_mission_core_count() -> int:
	var count := 0
	for item in blocks:
		if String(item.get("variant", "normal")) != MISSION_VARIANT:
			continue
		var body_variant: Variant = item.get("body", null)
		if body_variant is StaticBody2D and is_instance_valid(body_variant):
			count += 1
	return count


func _hit_block(body: StaticBody2D) -> void:
	var index := int(body.get_meta("block_index", -1))
	var was_mission_core := false
	if index >= 0 and index < blocks.size():
		was_mission_core = String(blocks[index].get("variant", "normal")) == MISSION_VARIANT
	super._hit_block(body)
	if authored_mode and was_mission_core and _authored_uses_mission_objectives() and _live_mission_core_count() == 0 and authored_result.is_empty():
		_finish_authored_level(true)


func _finish_volley() -> void:
	if authored_mode and _authored_uses_mission_objectives() and _live_mission_core_count() == 0:
		_finish_authored_level(true)
		return
	super._finish_volley()


func _mission_animation_frame(item: Dictionary) -> Texture2D:
	var elapsed := float(Time.get_ticks_msec()) / 1000.0
	var phase_offset := float((int(item.get("column", 0)) * 5 + int(item.get("row", 0)) * 3) % MISSION_RYKO_FRAMES.size())
	var frame_index := int(floor(elapsed / MISSION_FRAME_SECONDS + phase_offset)) % MISSION_RYKO_FRAMES.size()
	return MISSION_RYKO_FRAMES[frame_index]


func _draw_blocks() -> void:
	# Preserve every established authored block exactly as-is, then cover only
	# Mission Core cells with the dedicated art. Infinity is untouched because
	# this script exists only in the authored level scene.
	super._draw_blocks()
	if not authored_mode:
		return

	var cell := _active_cell()
	var scale := float(authored_profile.get("visual_scale", 1.0))
	var inset := maxf(1.0, cell * 0.055)
	var hp_font_size := maxi(6, int(round(18.0 * scale)))

	for item in blocks:
		if String(item.get("variant", "normal")) != MISSION_VARIANT:
			continue
		if String(item.get("shape", "square")) != "square":
			continue
		var body: StaticBody2D = item.get("body", null) as StaticBody2D
		if not is_instance_valid(body):
			continue

		var center: Vector2 = item["position"]
		var rect := Rect2(center - Vector2.ONE * cell * 0.5, Vector2.ONE * cell)
		# Mask the generic authored-square rendering (including its centered HP)
		# before composing the static frame, animated Ryko layer and dynamic HP.
		draw_rect(rect.grow(-inset), PANEL, true)
		draw_texture_rect(_mission_animation_frame(item), rect, false)
		draw_texture_rect(MISSION_FRAME, rect, false)

		var hit_flash_ratio := clampf(float(item.get("hit_flash", 0.0)) / BLOCK_HIT_FLASH_DURATION, 0.0, 1.0)
		if hit_flash_ratio > 0.0:
			draw_rect(rect, Color(CREAM, hit_flash_ratio * 0.18), true)

		var hp_center := Vector2(center.x, rect.position.y + rect.size.y * 0.875)
		_draw_centered_label(str(item.get("hp", 1)), hp_center, hp_font_size, CREAM)
