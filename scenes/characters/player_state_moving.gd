class_name PlayerStateMoving
extends PlayerState

func _process(_delta: float) -> void:
	match player.control_scheme:
		Player.ControlScheme.CPU:
			# 联机模式：CPU 全部静止，方便 debug 联机交互
			if GameManager.is_online():
				player.velocity = Vector2.ZERO
				pass
			else:
				ai_behavior.process_ai()
		Player.ControlScheme.ONLINE_REMOTE:
			_handle_online_remote()
		_:
			# P1, P2, ONLINE_LOCAL 都走本地输入
			handle_human_movement()
	player.set_movement_animation()
	player.set_heading()


func handle_human_movement() -> void:
	var direction := KeyUtils.get_input_vector(player.control_scheme)
	player.velocity = direction * player.speed

	if player.velocity != Vector2.ZERO:
		teammate_detection_area.rotation = player.velocity.angle()

	# 优先检查组合键（跳跃）
	if KeyUtils.check_combo_triggered(player.control_scheme, [KeyUtils.Action.PASS, KeyUtils.Action.SHOOT]):
		print('组合键触发：跳跃')
		transition_state(Player.State.JUMPING)
		return

	# 检查单键：传球
	if KeyUtils.check_single_action_triggered(player.control_scheme, KeyUtils.Action.PASS):
		if player.has_ball():
			transition_state(Player.State.PASSING)
		elif can_teammate_pass_ball():
			ball.carrier.get_pass_request(player)
		else:
			player.swap_requested.emit(player)
		return

	# 检查单键：射门
	if KeyUtils.check_single_action_triggered(player.control_scheme, KeyUtils.Action.SHOOT):
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


## 联机模式：服务端处理远程玩家的网络输入
func _handle_online_remote() -> void:
	if not multiplayer.is_server():
		# 客户端的远程玩家由快照插值驱动，不执行输入逻辑
		return
	# 服务端：从 KeyUtils 网络输入缓冲读取
	var idx := player.network_index
	var direction := KeyUtils.get_network_input_vector(idx)
	player.velocity = direction * player.speed

	if player.velocity != Vector2.ZERO:
		teammate_detection_area.rotation = player.velocity.angle()

	# 跳跃
	if KeyUtils.is_network_jump_pressed(idx):
		transition_state(Player.State.JUMPING)
		return

	# 传球
	if KeyUtils.is_network_action_just_pressed(idx, KeyUtils.Action.PASS):
		if player.has_ball():
			transition_state(Player.State.PASSING)
		elif can_teammate_pass_ball():
			ball.carrier.get_pass_request(player)
		return

	# 射门
	if KeyUtils.is_network_action_just_pressed(idx, KeyUtils.Action.SHOOT):
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

func can_teammate_pass_ball() -> bool:
	if ball.carrier == null or ball.carrier.country != player.country:
		return false
	# 联机模式：ONLINE_REMOTE 队友也可以被请求传球
	var carrier_scheme := ball.carrier.control_scheme
	return carrier_scheme == Player.ControlScheme.CPU or carrier_scheme == Player.ControlScheme.ONLINE_REMOTE

func can_pass() -> bool:
	return true
