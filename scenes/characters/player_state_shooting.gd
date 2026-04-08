class_name  PlayerStateShooting
extends PlayerState

func _enter_tree() -> void:
	animation_player.play("kick")

func on_animation_complete() -> void:
	if player.control_scheme == Player.ControlScheme.CPU:
		transition_state(Player.State.RECOVERING)
	else:
		transition_state(Player.State.MOVING)
	shoot_ball()

func shoot_ball() -> void:
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
	# 联机模式：客户端不执行 ball.shoot()，由服务器通过快照驱动球
	if GameManager.is_online() and not multiplayer.is_server():
		return
	ball.shoot(state_data.shot_direction * state_data.shot_power, -1.0, state_data.shot_power)
