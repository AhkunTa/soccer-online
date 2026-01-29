class_name PlayerStateMoving
extends PlayerState

func _process(_delta: float) -> void:
	if player.control_scheme == Player.ControlScheme.CPU:
		pass
		# FIXME debug 永远只有2p 移动
		# if player.country == GameManager.player_setup[1]:
		# 		ai_behavior.process_ai()
	else:
		handle_human_movement()
	player.set_movement_animation()
	player.set_heading()
	

func handle_human_movement() -> void:
	var direction := KeyUtils.get_input_vector(player.control_scheme)
	player.velocity = direction * player.speed

	if player.velocity != Vector2.ZERO:
		teammate_detection_area.rotation = player.velocity.angle()

	# FIXME 缓冲组合按键处理
	var pass_just_pressed := KeyUtils.is_action_just_pressed(player.control_scheme, KeyUtils.Action.PASS)
	var shoot_just_pressed := KeyUtils.is_action_just_pressed(player.control_scheme, KeyUtils.Action.SHOOT)
	var pass_pressed := KeyUtils.is_action_pressed(player.control_scheme, KeyUtils.Action.PASS)
	var shoot_pressed := KeyUtils.is_action_pressed(player.control_scheme, KeyUtils.Action.SHOOT)

	# 如果刚按下 PASS 且 SHOT 已按下，或刚按下 SHOT 且 PASS 已按下，则触发跳跃
	if (pass_just_pressed and shoot_pressed) or (shoot_just_pressed and pass_pressed):
		transition_state(Player.State.JUMPING)
	elif pass_just_pressed:
		if player.has_ball():
			transition_state(Player.State.PASSING)
		elif can_teammate_pass_ball():
			ball.carrier.get_pass_request(player)
		else:
			player.swap_requested.emit(player)
	elif shoot_just_pressed:
		if player.has_ball():
			transition_state(Player.State.PREPPING_SHOT)
		elif ball.can_air_interact():
			if player.velocity == Vector2.ZERO:
				if player.is_facing_target_goal():
					# 球员面向目标门 VOLLEY_KICK
					transition_state(Player.State.VOLLEY_KICK)
				else:
					# 球员背对目标门 BICYCLE_KICK
					transition_state(Player.State.BICYCLE_KICK)
			else:
				transition_state(Player.State.HEADER)
		elif player.velocity != Vector2.ZERO:
			state_transition_requested.emit(Player.State.TACKLING)

func can_carry_ball() -> bool:
	return player.role != Player.Role.GOALIE

func can_teammate_pass_ball() -> bool:
	return ball.carrier != null and ball.carrier.country == player.country and ball.carrier.control_scheme == Player.ControlScheme.CPU

func can_pass() -> bool:
	return true
