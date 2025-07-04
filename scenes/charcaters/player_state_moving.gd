class_name PlayerStateMoving
extends PlayerState

func _process(_delta: float) -> void:
	if player.control_scheme == Player.ControlScheme.CPU:
		pass
	else:
		handle_human_movement()
		player.set_movement_animation()
		player.set_heading()
	

func handle_human_movement() -> void:
	var direction := KeyUtils.get_input_vector(player.control_scheme)
	player.velocity = direction * player.SPEED
	
	if player.velocity !=Vector2.ZERO:
		teammate_detection_area.rotation = player.velocity.angle()
	
	if player.has_ball() and KeyUtils.is_action_just_pressed(player.control_scheme, KeyUtils.Action.PASS):
		transition_state(Player.State.PASSING)
	
	if player.has_ball() and KeyUtils.is_action_just_pressed(player.control_scheme, KeyUtils.Action.SHOOT):
		transition_state(Player.State.PREPINGSHOT)
	#if player.has_ball() and KeyUtils.is_action_just_pressed(player.control_scheme, KeyUtils.Action.SHOOT):
		#transition_state.emit(Player.State.PREPINGSHOT)
	
	#if player.velocity != Vector2.ZERO  and KeyUtils.is_action_just_pressed(player.control_scheme,KeyUtils.Action.SHOOT):
		#transition_state.emit(Player.State.TACKLING)
		
		
