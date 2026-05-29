class_name PlayerStateMoving
extends PlayerState

const WALK_SPEED_SCALE := 0.6
const DOUBLE_TAP_WINDOW_MS := 280

var last_tap_action := KeyUtils.Action.LEFT
var last_tap_time := 0
var previous_network_x_sign := 0.0

## Moving 比较特殊：有本地输入/网络输入/AI 三条路径，直接重写 _process
func _process(delta: float) -> void:
	match player.control_scheme:
		Player.ControlScheme.CPU:
			ai_behavior.process_ai()
			if player.current_state != self:
				return
			player.apply_ground_movement(ai_behavior.desired_movement_direction, delta)
			player.set_movement_animation()
			player.set_heading()
		Player.ControlScheme.ONLINE_REMOTE:
			if SyncManager.is_server():
				_handle_network_input(delta)
				if player.current_state != self:
					return
				player.set_movement_animation()
				player.set_heading()
			# 客户端：动画由 SyncManager 驱动
		_:
			# P1, P2, ONLINE_LOCAL
			_handle_local_input(delta)
			if player.current_state != self:
				return
			player.set_movement_animation()
			player.set_heading()


func _handle_local_input(delta: float) -> void:
	var direction := KeyUtils.get_input_vector(player.control_scheme)
	_try_start_local_run()
	if player.current_state != self:
		return
	player.apply_ground_movement(direction, delta, WALK_SPEED_SCALE)
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


func _handle_network_input(delta: float) -> void:
	var idx := player.network_index
	var direction := KeyUtils.get_network_input_vector(idx)
	_try_start_network_run(direction)
	if player.current_state != self:
		return
	player.apply_ground_movement(direction, delta, WALK_SPEED_SCALE)
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


func _try_start_local_run() -> void:
	_try_start_run_from_action(_get_forward_action())
	if player.current_state == self:
		_try_start_run_from_action(_get_backward_action())


func _try_start_network_run(direction: Vector2) -> void:
	var current_sign := _get_float_sign(direction.x)
	if current_sign != 0.0 and current_sign != previous_network_x_sign:
		var action := KeyUtils.Action.RIGHT if current_sign > 0.0 else KeyUtils.Action.LEFT
		if action == _get_forward_action() or action == _get_backward_action():
			_handle_run_tap(action, current_sign)
	previous_network_x_sign = current_sign


func _handle_run_tap(action: int, direction_sign: float) -> void:
	var now := Time.get_ticks_msec()
	if last_tap_action == action and now - last_tap_time <= DOUBLE_TAP_WINDOW_MS:
		transition_state(Player.State.RUNNING, PlayerStateData.build().set_run_direction(Vector2(direction_sign, 0.0)))
		last_tap_time = 0
		return
	last_tap_action = action
	last_tap_time = now


func _try_start_run_from_action(action: int) -> void:
	if KeyUtils.is_action_just_pressed(player.control_scheme, action):
		_handle_run_tap(action, _get_action_sign(action))


func _get_forward_action() -> int:
	return KeyUtils.Action.RIGHT if target_goal.position.x > player.position.x else KeyUtils.Action.LEFT


func _get_backward_action() -> int:
	return KeyUtils.Action.LEFT if _get_forward_action() == KeyUtils.Action.RIGHT else KeyUtils.Action.RIGHT


func _get_action_sign(action: int) -> float:
	return -1.0 if action == KeyUtils.Action.LEFT else 1.0


func _get_float_sign(value: float) -> float:
	if value > 0.0:
		return 1.0
	if value < 0.0:
		return -1.0
	return 0.0


func can_carry_ball() -> bool:
	return player.role != Player.Role.GOALIE

func _can_teammate_pass_ball() -> bool:
	if ball.carrier == null or ball.carrier.country != player.country:
		return false
	var s := ball.carrier.control_scheme
	return s == Player.ControlScheme.CPU or s == Player.ControlScheme.ONLINE_REMOTE

func can_pass() -> bool:
	return true
