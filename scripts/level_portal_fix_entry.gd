extends "res://scripts/level_mechanics_test_entry.gd"


func _process_portals() -> void:
	if level_portals.is_empty():
		return

	# The trigger must match what the player sees. Use the rendered portal radius
	# plus the authored ball collision radius, and test the whole travelled path
	# for this physics frame so fast balls cannot skip over a portal.
	var portal_radius := maxf(5.0, _active_cell() * 0.24)
	var trigger_radius := portal_radius + _active_ball_collision_radius()

	for entry in balls:
		if bool(entry.get("returned", false)):
			continue
		var body: CharacterBody2D = entry.get("body", null) as CharacterBody2D
		if not is_instance_valid(body):
			continue

		var ball_id := body.get_instance_id()
		if portal_ball_cooldowns.has(ball_id):
			continue

		var current_position := body.position
		var previous_position: Vector2 = mechanic_previous_ball_positions.get(ball_id, current_position)

		for portal in level_portals:
			var center: Vector2 = portal["position"]
			if _point_segment_distance(center, previous_position, current_position) > trigger_radius:
				continue

			var exit_portal := _portal_pair_exit(portal)
			if exit_portal.is_empty():
				break

			var velocity: Vector2 = entry.get("velocity", Vector2.UP)
			var direction := velocity.normalized()
			if direction.length_squared() < 0.01:
				direction = Vector2.UP

			# Emerge just outside the paired portal in the same travel direction.
			# Direction and speed stay untouched.
			var exit_center: Vector2 = exit_portal["position"]
			body.position = exit_center + direction * (trigger_radius + 2.0)

			# Critical: teleportation is discontinuous movement. Downstream mechanics
			# (especially lasers) must not interpret the line between entry and exit as
			# a real ball path, otherwise a laser between portals destroys the ball.
			mechanic_previous_ball_positions[ball_id] = body.position
			portal_ball_cooldowns[ball_id] = 0.12
			break
