extends "res://scripts/level_test_entry.gd"

const MISSION_VARIANT := "mission_core"
const MISSION_WIN_CONDITION := "destroy_all_objectives"
const MISSION_FRAME: Texture2D = preload("res://assets/ui/mission_block/rama (3).png")
const MISSION_RYKO_FRAMES: Array[Texture2D] = [
	preload("res://assets/ui/mission_block/pose1.png"),
	preload("res://assets/ui/mission_block/pose2.png"),
	preload("res://assets/ui/mission_block/pose3.png"),
	preload("res://assets/ui/mission_block/pose4.png"),
	preload("res://assets/ui/mission_block/pose5.png"),
	preload("res://assets/ui/mission_block/pose6.png"),
	preload("res://assets/ui/mission_block/pose7.png"),
	preload("res://assets/ui/mission_block/pose8.png"),
	preload("res://assets/ui/mission_block/pose9.png"),
	preload("res://assets/ui/mission_block/pose10.png"),
]
const MISSION_FRAME_SECONDS := 0.28
# Ryko stays inside the inner viewport and clears the taller bottom energy panel.
const MISSION_POSE_SCALE := 0.78
const MISSION_POSE_TOP := 0.015
# Normalized safe area measured against the final frame artwork. The bar spans
# the lower panel between the two screw/corner assemblies, while the chamfers
# keep the code-drawn fill inside the cut corners of the image.
const MISSION_BAR_LEFT := 0.175
const MISSION_BAR_RIGHT := 0.825
const MISSION_BAR_TOP := 0.825
const MISSION_BAR_BOTTOM := 0.915
const MISSION_BAR_CHAMFER := 0.035


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


func _spawn_authored_entity(entity: Dictionary, row: int) -> void:
	var before := blocks.size()
	super._spawn_authored_entity(entity, row)
	if blocks.size() <= before:
		return
	var item: Dictionary = blocks[blocks.size() - 1]
	if String(item.get("variant", "normal")) != MISSION_VARIANT:
		return
	var starting_hp := maxi(1, int(item.get("hp", 1)))
	item["max_hp"] = starting_hp


func _hit_block(body: StaticBody2D) -> void:
	var index := int(body.get_meta("block_index", -1))
	var was_mission_core := false
	if index >= 0 and index < blocks.size():
		was_mission_core = String(blocks[index].get("variant", "normal")) == MISSION_VARIANT
		if was_mission_core and not blocks[index].has("max_hp"):
			blocks[index]["max_hp"] = maxi(1, int(blocks[index].get("hp", 1)))
	super._hit_block(body)
	# The normal hit path queues redraw immediately, so the bar reflects every
	# individual ball impact during the volley rather than waiting for turn end.
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


func _mission_pose_rect(cell_rect: Rect2) -> Rect2:
	var pose_size := cell_rect.size.x * MISSION_POSE_SCALE
	return Rect2(
		Vector2(cell_rect.get_center().x - pose_size * 0.5, cell_rect.position.y + cell_rect.size.y * MISSION_POSE_TOP),
		Vector2.ONE * pose_size
	)


func _mission_bar_polygon(cell_rect: Rect2) -> PackedVector2Array:
	var left := cell_rect.position.x + cell_rect.size.x * MISSION_BAR_LEFT
	var right := cell_rect.position.x + cell_rect.size.x * MISSION_BAR_RIGHT
	var top := cell_rect.position.y + cell_rect.size.y * MISSION_BAR_TOP
	var bottom := cell_rect.position.y + cell_rect.size.y * MISSION_BAR_BOTTOM
	var cut := cell_rect.size.x * MISSION_BAR_CHAMFER
	return PackedVector2Array([
		Vector2(left + cut, top),
		Vector2(right - cut, top),
		Vector2(right, top + cut),
		Vector2(right, bottom - cut),
		Vector2(right - cut, bottom),
		Vector2(left + cut, bottom),
		Vector2(left, bottom - cut),
		Vector2(left, top + cut),
	])


func _clip_polygon_right(points: PackedVector2Array, max_x: float) -> PackedVector2Array:
	var output := PackedVector2Array()
	if points.is_empty():
		return output
	var previous := points[points.size() - 1]
	var previous_inside := previous.x <= max_x
	for current in points:
		var current_inside := current.x <= max_x
		if current_inside != previous_inside:
			var dx := current.x - previous.x
			var ratio := 0.0 if is_zero_approx(dx) else (max_x - previous.x) / dx
			output.append(previous.lerp(current, clampf(ratio, 0.0, 1.0)))
		if current_inside:
			output.append(current)
		previous = current
		previous_inside = current_inside
	return output


func _draw_mission_progress(item: Dictionary, cell_rect: Rect2) -> void:
	var max_hp := maxi(1, int(item.get("max_hp", item.get("hp", 1))))
	var hp := clampi(int(item.get("hp", 0)), 0, max_hp)
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var track := _mission_bar_polygon(cell_rect)
	# Dark recessed track belongs inside the artwork's lower window and never
	# creates another border around the Mission Core tile.
	draw_colored_polygon(track, Color(0.02, 0.08, 0.10, 0.88))
	if ratio <= 0.0:
		return
	var left := cell_rect.position.x + cell_rect.size.x * MISSION_BAR_LEFT
	var right := cell_rect.position.x + cell_rect.size.x * MISSION_BAR_RIGHT
	var fill_right := lerpf(left, right, ratio)
	var fill := _clip_polygon_right(track, fill_right)
	if fill.size() >= 3:
		draw_colored_polygon(fill, Color(AQUA, 0.96))
		# A subtle inner highlight makes each live decrement readable on phone
		# without adding an outline outside the frame.
		var highlight_y := cell_rect.position.y + cell_rect.size.y * (MISSION_BAR_TOP + 0.012)
		var highlight_left := left + cell_rect.size.x * MISSION_BAR_CHAMFER
		if fill_right > highlight_left:
			draw_line(Vector2(highlight_left, highlight_y), Vector2(fill_right, highlight_y), Color(CREAM, 0.35), maxf(1.0, cell_rect.size.x * 0.008), true)


func _draw_blocks() -> void:
	# Preserve every established authored block exactly as-is, then replace only
	# Mission Core cells with the dedicated art. Infinity is untouched because
	# this script exists only in the authored level scene.
	super._draw_blocks()
	if not authored_mode:
		return

	var cell := _active_cell()

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

		# Cover the generic authored-square rendering completely first. This is the
		# guard against the old coral/red or any other generic outer outline.
		draw_rect(rect, PANEL, true)
		# The final frame contains the static interior/background, so it is drawn
		# first. Ryko is then composited above it, inside a safe inner footprint.
		draw_texture_rect(MISSION_FRAME, rect, false)
		draw_texture_rect(_mission_animation_frame(item), _mission_pose_rect(rect), false)
		_draw_mission_progress(item, rect)

		var hit_flash_ratio := clampf(float(item.get("hit_flash", 0.0)) / BLOCK_HIT_FLASH_DURATION, 0.0, 1.0)
		if hit_flash_ratio > 0.0:
			draw_rect(rect.grow(-cell * 0.08), Color(CREAM, hit_flash_ratio * 0.12), true)
