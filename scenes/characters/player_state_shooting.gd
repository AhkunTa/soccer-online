class_name PlayerStateShooting
extends PlayerState

func on_enter_visual() -> void:
	animation_player.play("kick")

func on_animation_complete() -> void:
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
