class_name PlayerStatePreppingShot
extends PlayerState

const DURATION_MAX_BONUS := 1000.0
const DURATION_MAX_CHARGE := 1500.0
const EASE_REWARD_FACTOR := 2.0

var shot_direction := Vector2.ZERO
var time_start_shot := Time.get_ticks_msec()

func on_enter_visual() -> void:
	animation_player.play("prep_kick")

func on_enter_logic() -> void:
	player.velocity = Vector2.ZERO
	time_start_shot = Time.get_ticks_msec()
	shot_direction = player.heading

## PreppingShot 有本地/网络输入分支，直接重写 _process
func _process(delta: float) -> void:
	if _is_remote_on_client():
		return
	if player.control_scheme == Player.ControlScheme.ONLINE_REMOTE:
		_handle_network_input(delta)
	else:
		_handle_local_input(delta)


func _handle_local_input(delta: float) -> void:
	shot_direction += KeyUtils.get_input_vector(player.control_scheme) * delta
	if Time.get_ticks_msec() - time_start_shot >= DURATION_MAX_CHARGE:
		transition_state(Player.State.HURT)
	if KeyUtils.is_action_just_released(player.control_scheme, KeyUtils.Action.SHOOT):
		_do_shoot()


func _handle_network_input(delta: float) -> void:
	var idx := player.network_index
	shot_direction += KeyUtils.get_network_input_vector(idx) * delta
	if Time.get_ticks_msec() - time_start_shot >= DURATION_MAX_CHARGE:
		transition_state(Player.State.HURT)
	if KeyUtils.is_network_shoot_just_released(idx):
		_do_shoot()


func _do_shoot() -> void:
	var prep_time := Time.get_ticks_msec() - time_start_shot
	var duration_pass := clampf(prep_time, 0.0, DURATION_MAX_BONUS)
	var ease_time := duration_pass / DURATION_MAX_BONUS
	var bonus := ease(ease_time, EASE_REWARD_FACTOR)
	var shot_power := player.power * (1 + bonus)
	shot_direction = shot_direction.normalized()
	var shooting_data = PlayerStateData.build().set_shot_direction(shot_direction).set_shot_power(shot_power)
	transition_state(Player.State.SHOOTING, shooting_data)

func can_pass() -> bool:
	return true
