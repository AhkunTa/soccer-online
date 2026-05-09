class_name PlayerStateShooting
extends PlayerState

const DURATION_SHOOT_FALLBACK := 350

var time_start_shooting := Time.get_ticks_msec()
var did_finish := false

func on_enter_visual() -> void:
	animation_player.play("kick")

func on_enter_logic() -> void:
	time_start_shooting = Time.get_ticks_msec()
	did_finish = false

func server_process(_delta: float) -> void:
	if SyncManager.is_client():
		return
	if Time.get_ticks_msec() - time_start_shooting > DURATION_SHOOT_FALLBACK:
		_finish_shooting()

func on_animation_complete() -> void:
	_finish_shooting()

func _finish_shooting() -> void:
	if did_finish:
		return
	did_finish = true
	if player.control_scheme == Player.ControlScheme.CPU:
		transition_state(Player.State.RECOVERING)
	else:
		transition_state(Player.State.MOVING)
	_shoot_ball()

func _shoot_ball() -> void:
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
	if SyncManager.is_client():
		return
	ball.shoot(state_data.shot_direction * state_data.shot_power, -1.0, state_data.shot_power)
