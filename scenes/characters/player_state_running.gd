class_name PlayerStateRunning
extends PlayerState

const START_ANIMATION := "short_dash"
const STOP_ANIMATION := "recover"
const START_SPEED_SCALE := 0.55
const STOP_FALLBACK_MS := 420

enum Phase {STARTING, RUNNING, STOPPING}

var phase := Phase.STARTING
var run_direction := Vector2.RIGHT
var start_started_at := 0
var stop_started_at := 0

func on_enter_visual() -> void:
	run_direction = state_data.run_direction.normalized()
	if run_direction == Vector2.ZERO:
		run_direction = player.heading
	player.heading = Vector2.RIGHT if run_direction.x >= 0.0 else Vector2.LEFT
	start_started_at = Time.get_ticks_msec()
	animation_player.play(START_ANIMATION)

func server_process(delta: float) -> void:
	var input_direction := _get_input_direction()
	var movement_direction := _get_running_movement_direction(input_direction)
	_update_animation_gate()
	if player.current_state != self:
		return

	if phase != Phase.STOPPING and _is_opposite_direction_pressed(input_direction):
		_start_stop()

	match phase:
		Phase.STARTING:
			player.apply_ground_movement(movement_direction, delta, START_SPEED_SCALE)
		Phase.RUNNING:
			player.apply_ground_movement(movement_direction, delta)
			player.set_movement_animation()
		Phase.STOPPING:
			player.apply_ground_movement(Vector2.ZERO, delta)
			if Time.get_ticks_msec() - stop_started_at > STOP_FALLBACK_MS:
				transition_state(Player.State.MOVING)

	if player.velocity != Vector2.ZERO:
		teammate_detection_area.rotation = player.velocity.angle()
	player.set_heading()
	_handle_actions(input_direction)

func _get_input_direction() -> Vector2:
	if player.control_scheme == Player.ControlScheme.ONLINE_REMOTE:
		return KeyUtils.get_network_input_vector(player.network_index)
	return KeyUtils.get_input_vector(player.control_scheme)

func _get_running_movement_direction(input_direction: Vector2) -> Vector2:
	return Vector2(run_direction.x, input_direction.y).limit_length(1.0)

func _handle_actions(direction: Vector2) -> void:
	if player.control_scheme == Player.ControlScheme.ONLINE_REMOTE:
		_handle_network_actions()
		return
	_handle_local_actions(direction)

func _handle_local_actions(_direction: Vector2) -> void:
	if KeyUtils.check_combo_triggered(player.control_scheme, [KeyUtils.Action.PASS, KeyUtils.Action.SHOOT]):
		transition_state(Player.State.JUMPING)
		return
	if KeyUtils.check_single_action_triggered(player.control_scheme, KeyUtils.Action.PASS):
		if player.has_ball():
			transition_state(Player.State.PASSING)
		elif _can_teammate_pass_ball():
			ball.carrier.get_pass_request(player)
		else:
			player.swap_requested.emit(player)
		return
	if KeyUtils.check_single_action_triggered(player.control_scheme, KeyUtils.Action.SHOOT):
		_handle_shoot_action()

func _handle_network_actions() -> void:
	var idx := player.network_index
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
		transition_state(Player.State.HEADER)
	elif player.velocity != Vector2.ZERO:
		transition_state(Player.State.TACKLING)

func _start_stop() -> void:
	phase = Phase.STOPPING
	stop_started_at = Time.get_ticks_msec()
	animation_player.play(STOP_ANIMATION)

func _update_animation_gate() -> void:
	match phase:
		Phase.STARTING:
			if _has_animation_finished(START_ANIMATION, start_started_at):
				phase = Phase.RUNNING
		Phase.STOPPING:
			if _has_animation_finished(STOP_ANIMATION, stop_started_at):
				transition_state(Player.State.MOVING)

func _has_animation_finished(animation_name: String, started_at: int) -> bool:
	var elapsed := float(Time.get_ticks_msec() - started_at) / 1000.0
	var animation := animation_player.get_animation(animation_name)
	var animation_length := animation.length if animation != null else 0.0
	return elapsed >= animation_length

func _is_opposite_direction_pressed(direction: Vector2) -> bool:
	return run_direction.x != 0.0 and direction.x != 0.0 and _get_float_sign(direction.x) == -_get_float_sign(run_direction.x)

func _get_float_sign(value: float) -> float:
	if value > 0.0:
		return 1.0
	if value < 0.0:
		return -1.0
	return 0.0

func _can_teammate_pass_ball() -> bool:
	if ball.carrier == null or ball.carrier.country != player.country:
		return false
	var s := ball.carrier.control_scheme
	return s == Player.ControlScheme.CPU or s == Player.ControlScheme.ONLINE_REMOTE

func on_animation_complete() -> void:
	match phase:
		Phase.STARTING:
			phase = Phase.RUNNING
		Phase.STOPPING:
			transition_state(Player.State.MOVING)

func can_carry_ball() -> bool:
	return player.role != Player.Role.GOALIE

func can_pass() -> bool:
	return true
