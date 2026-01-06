class_name PlayerStateResting
extends PlayerState

var has_arrived: bool = false

func _enter_tree() -> void:
	pass

func _process(_delta: float) -> void:
	if not has_arrived:
		var direction := player.position.direction_to(state_data.reset_position)
		if player.position.distance_squared_to(state_data.reset_position) < 2:
			has_arrived = true
			player.velocity = Vector2.ZERO
			player.face_towards_goal()
		else:
			player.velocity = direction * player.speed
		player.set_movement_animation()
		player.set_heading()

func is_ready_for_kickoff() -> bool:
	return has_arrived
