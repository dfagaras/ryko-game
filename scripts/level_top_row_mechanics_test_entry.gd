extends "res://scripts/level_mechanics_test_entry.gd"


func _load_level_mechanics() -> void:
	super._load_level_mechanics()
	if not authored_mode:
		return

	var mechanics_variant: Variant = authored_level.get("mechanics", {})
	if typeof(mechanics_variant) != TYPE_DICTIONARY:
		return
	var launchers_variant: Variant = (mechanics_variant as Dictionary).get("launchers", [])
	if typeof(launchers_variant) != TYPE_ARRAY:
		return

	var columns := int(authored_profile.get("columns", 7))
	var valid_directions: Array[String] = ["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]
	for launcher_variant in launchers_variant as Array:
		if typeof(launcher_variant) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = launcher_variant
		var column := int(source.get("column", -1))
		var row := int(source.get("row", 0))
		if row != -1 or column < 0 or column >= columns:
			continue
		var direction := String(source.get("direction", "up"))
		if direction not in valid_directions:
			direction = "up"
		level_launchers.append({
			"id": String(source.get("id", "launcher_%d" % (level_launchers.size() + 1))),
			"column": column,
			"row": -1,
			"position": _cell_center(column, -1),
			"direction": direction,
			"balls_inside": {},
		})
	queue_redraw()
