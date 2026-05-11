class_name PlayerStateMoving
extends PlayerState

## Moving 比较特殊：有本地输入/网络输入/AI 三条路径，直接重写 _process
func _process(_delta: float) -> void:
	match player.control_scheme:
		Player.ControlScheme.CPU:
			if GameManager.is_online():
				player.velocity = Vector2.ZERO  # debug: 联机模式 CPU 静止
			else:
				ai_behavior.process_ai()
			if player.current_state != self:
				return
			player.set_movement_animation()
			player.set_heading()
		Player.ControlScheme.ONLINE_REMOTE:
			if SyncManager.is_server():
				_handle_network_input()
				if player.current_state != self:
					return
				player.set_movement_animation()
				player.set_heading()
			# 客户端：动画由 SyncManager 驱动
		_:
			# P1, P2, ONLINE_LOCAL
			_handle_local_input()
			if player.current_state != self:
				return
			player.set_movement_animation()
			player.set_heading()


func _handle_local_input() -> void:
	var direction := KeyUtils.get_input_vector(player.control_scheme)
	player.velocity = direction * player.speed
	if player.velocity != Vector2.ZERO:
		teammate_detection_area.rotation = player.velocity.angle()
	# 组合键：跳跃
	if KeyUtils.check_combo_triggered(player.control_scheme, [KeyUtils.Action.PASS, KeyUtils.Action.SHOOT]):
		transition_state(Player.State.JUMPING)
		return
	# 传球
	if KeyUtils.check_single_action_triggered(player.control_scheme, KeyUtils.Action.PASS):
		if player.has_ball():
			transition_state(Player.State.PASSING)
		elif _can_teammate_pass_ball():
			ball.carrier.get_pass_request(player)
		else:
			player.swap_requested.emit(player)
		return
	# 射门
	if KeyUtils.check_single_action_triggered(player.control_scheme, KeyUtils.Action.SHOOT):
		_handle_shoot_action()


func _handle_network_input() -> void:
	var idx := player.network_index
	var direction := KeyUtils.get_network_input_vector(idx)
	player.velocity = direction * player.speed
	if player.velocity != Vector2.ZERO:
		teammate_detection_area.rotation = player.velocity.angle()
	if KeyUtils.is_network_jump_pressed(idx):
		transition_state(Player.State.JUMPING)
		return
	if KeyUtils.is_network_jump_held(idx):
		return
	if KeyUtils.is_network_action_just_pressed(idx, KeyUtils.Action.PASS):
		if player.has_ball():
			transition_state(Player.State.PASSING)
		elif _can_teammate_pass_ball():
			ball.carrier.get_pass_request(player)
		return
	if KeyUtils.is_network_action_just_pressed(idx, KeyUtils.Action.SHOOT):
		_handle_shoot_action()


func _handle_shoot_action() -> void:
	if player.has_ball():
		transition_state(Player.State.PREPPING_SHOT)
	elif ball.can_air_interact():
		if player.velocity == Vector2.ZERO:
			if player.is_facing_target_goal():
				transition_state(Player.State.VOLLEY_KICK)
			else:
				transition_state(Player.State.BICYCLE_KICK)
		else:
			transition_state(Player.State.HEADER)
	elif player.velocity != Vector2.ZERO:
		state_transition_requested.emit(Player.State.TACKLING)


func can_carry_ball() -> bool:
	return player.role != Player.Role.GOALIE

func _can_teammate_pass_ball() -> bool:
	if ball.carrier == null or ball.carrier.country != player.country:
		return false
	var s := ball.carrier.control_scheme
	return s == Player.ControlScheme.CPU or s == Player.ControlScheme.ONLINE_REMOTE

func can_pass() -> bool:
	return true
