extends SceneTree

const BoardProfile = preload("res://scripts/level_board_profile.gd")
const LevelDefinition = preload("res://scripts/level_definition.gd")


func _init() -> void:
	for scale in [1, 2, 3, 4]:
		_validate_profile(scale)
	_validate_level_parser()
	_validate_invalid_contracts()
	print("RYKO scalable authored-board runtime validation: PASS")
	quit(0)


func _validate_profile(scale: int) -> void:
	var profile := BoardProfile.from_scale(scale)
	_check(int(profile["columns"]) == 7 * scale, "columns mismatch at %dx" % scale)
	_check(int(profile["rows"]) == 9 * scale, "rows mismatch at %dx" % scale)
	_check(is_equal_approx(float(profile["cell"]), 88.0 / float(scale)), "cell mismatch at %dx" % scale)
	_check(is_equal_approx(float(profile["ball_radius"]), 9.0 / float(scale)), "ball radius mismatch at %dx" % scale)
	_check(is_equal_approx(float(profile["ball_speed"]), 760.0 / float(scale)), "ball speed mismatch at %dx" % scale)

	var grid := BoardProfile.grid_rect(profile)
	_check(is_equal_approx(grid.position.x, 40.0), "grid x moved at %dx" % scale)
	_check(is_equal_approx(grid.position.y, 268.0), "grid y moved at %dx" % scale)
	_check(is_equal_approx(grid.size.x, 640.0), "grid width changed at %dx" % scale)
	_check(is_equal_approx(grid.size.y, 824.0), "grid height changed at %dx" % scale)
	_check(is_equal_approx(grid.end.x, 680.0), "grid right edge changed at %dx" % scale)
	_check(is_equal_approx(grid.end.y, 1092.0), "launch line changed at %dx" % scale)

	var last_rect := BoardProfile.cell_rect(profile, int(profile["columns"]) - 1, int(profile["rows"]) - 1)
	_check(is_equal_approx(last_rect.end.x, grid.end.x), "last column does not fit at %dx" % scale)
	_check(is_equal_approx(last_rect.end.y, grid.end.y), "last row does not fit at %dx" % scale)


func _validate_level_parser() -> void:
	var source := {
		"schemaVersion": 1,
		"levelId": "runtime_scale_4",
		"name": "Runtime 28x36",
		"boardScale": 4,
		"rules": {
			"mode": "descent",
			"startingBalls": 12,
			"winCondition": "clear_all_content",
			"loseCondition": "block_reaches_launch_line",
			"moveLimit": 10,
			"descent": {
				"rowsPerMove": 1,
				"incomingSource": "authored",
				"loseWhenBlockReachesLaunchLine": true
			}
		},
		"initialBoard": [
			{"kind": "block", "shape": "square", "variant": "regenerative", "hp": 20, "column": 27, "row": 34},
			{"kind": "pickup", "type": "plus_ball", "column": 0, "row": 0}
		],
		"incomingRows": [
			{"afterMove": 1, "cells": [{"kind": "power", "type": "ion", "orientation": "horizontal", "column": 12, "row": 0}]}
		]
	}
	var parsed := LevelDefinition.parse_json_text(JSON.stringify(source))
	_check(bool(parsed["valid"]), "valid 4x level was rejected: %s" % str(parsed["errors"]))
	var level: Dictionary = parsed["level"]
	var board: Dictionary = level["board"]
	_check(int(level["boardScale"]) == 4, "runtime parser lost boardScale")
	_check(int(board["columns"]) == 28, "runtime parser columns mismatch")
	_check(int(board["rows"]) == 36, "runtime parser rows mismatch")
	_check(int(board["dangerRow"]) == 35, "runtime danger row mismatch")
	_check(is_equal_approx(float(board["gridWidth"]), 640.0), "runtime grid width mismatch")
	_check(is_equal_approx(float(board["gridHeight"]), 824.0), "runtime grid height mismatch")
	_check(is_equal_approx(float(board["ballRadius"]), 2.25), "runtime ball radius mismatch")
	_check(is_equal_approx(float(board["ballSpeed"]), 190.0), "runtime ball speed mismatch")


func _validate_invalid_contracts() -> void:
	var bad_scale := {
		"schemaVersion": 1,
		"levelId": "bad_scale",
		"name": "Bad scale",
		"boardScale": 5,
		"rules": {"mode": "clear_limited", "startingBalls": 1, "moveLimit": 5},
		"initialBoard": [{"kind": "block", "shape": "square", "variant": "normal", "hp": 3, "column": 0, "row": 0}],
		"incomingRows": []
	}
	var scale_result := LevelDefinition.normalize_level(bad_scale)
	_check(not bool(scale_result["valid"]), "unsupported 5x board was accepted")

	var bad_hole := {
		"schemaVersion": 1,
		"levelId": "bad_hole",
		"name": "Bad hole",
		"boardScale": 2,
		"rules": {"mode": "clear_limited", "startingBalls": 1, "moveLimit": 5},
		"initialBoard": [{"kind": "block", "shape": "square", "variant": "black_hole", "hp": 3, "absorbingSides": [], "column": 0, "row": 0}],
		"incomingRows": []
	}
	var hole_result := LevelDefinition.normalize_level(bad_hole)
	_check(not bool(hole_result["valid"]), "Black Hole without absorbing side was accepted")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
