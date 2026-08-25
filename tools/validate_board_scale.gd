extends SceneTree

const BoardProfile = preload("res://scripts/board_profile.gd")
const LevelDefinition = preload("res://scripts/level_definition.gd")


func _init() -> void:
	var standard := BoardProfile.for_scale(1)
	assert(int(standard["columns"]) == 7)
	assert(int(standard["rows"]) == 9)
	assert(is_equal_approx(float(standard["cell"]), 88.0))
	assert(is_equal_approx(float(standard["gap"]), 4.0))
	assert(is_equal_approx(float(standard["gridY"]), 268.0))

	var scale_two := BoardProfile.for_scale(2)
	assert(int(scale_two["columns"]) == 14)
	assert(int(scale_two["rows"]) == 18)
	assert(is_equal_approx(float(scale_two["cell"]), 44.0))
	var width_two := float(scale_two["columns"]) * float(scale_two["cell"]) + float(int(scale_two["columns"]) - 1) * float(scale_two["gap"])
	assert(is_equal_approx(width_two, 640.0))

	var scale_four := BoardProfile.for_scale(4)
	assert(int(scale_four["columns"]) == 28)
	assert(int(scale_four["rows"]) == 36)
	assert(is_equal_approx(float(scale_four["cell"]), 22.0))
	var gameplay_four := BoardProfile.gameplay_for_scale(4)
	assert(is_equal_approx(float(gameplay_four["ballRadius"]), 2.25))
	assert(is_equal_approx(float(gameplay_four["ballSpeed"]), 190.0))

	var legacy := {
		"schemaVersion": 1,
		"levelId": "legacy",
		"name": "Legacy",
		"rules": {"mode": "clear_limited", "startingBalls": 1, "moveLimit": 5},
		"initialBoard": [{"kind": "block", "shape": "square", "variant": "normal", "hp": 3, "column": 6, "row": 8}],
		"incomingRows": [],
	}
	var legacy_result := LevelDefinition.normalize_level(legacy)
	assert(bool(legacy_result["valid"]))
	assert(int(legacy_result["level"]["boardScale"]) == 1)
	assert(int(legacy_result["level"]["schemaVersion"]) == 2)

	var micro := {
		"schemaVersion": 2,
		"levelId": "micro",
		"name": "Micro",
		"boardScale": 4,
		"rules": {"mode": "clear_limited", "startingBalls": 1, "moveLimit": 12},
		"initialBoard": [{"kind": "block", "shape": "square", "variant": "normal", "hp": 12, "column": 27, "row": 35}],
		"incomingRows": [],
	}
	var micro_result := LevelDefinition.normalize_level(micro)
	assert(bool(micro_result["valid"]))
	assert(int(micro_result["boardProfile"]["columns"]) == 28)
	assert(int(micro_result["boardProfile"]["rows"]) == 36)

	var invalid := micro.duplicate(true)
	invalid["boardScale"] = 5
	var invalid_result := LevelDefinition.normalize_level(invalid)
	assert(not bool(invalid_result["valid"]))

	print("RYKO board-scale runtime validation: PASS")
	quit(0)
