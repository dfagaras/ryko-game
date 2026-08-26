extends "res://scripts/level_test_game.gd"

const RUNTIME_LEVEL_KEY := "ryko/runtime_test_level_path"


func _ready() -> void:
	super._ready()
	var path := str(ProjectSettings.get_setting(RUNTIME_LEVEL_KEY, ""))
	if path.is_empty():
		return
	call_deferred("_load_authored_level", path)
