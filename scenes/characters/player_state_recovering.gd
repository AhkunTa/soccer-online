class_name PlayerStateRecovering
extends PlayerState

const DURATION_RECOVER := 500
var time_start_recovery := Time.get_ticks_msec()

func on_enter_visual() -> void:
	animation_player.play("recover")

func on_enter_logic() -> void:
	time_start_recovery = Time.get_ticks_msec()
	player.velocity = Vector2.ZERO
	player.is_invincible_to_ball_damage = false

func server_process(_delta: float) -> void:
	if Time.get_ticks_msec() - time_start_recovery > DURATION_RECOVER:
		transition_state(Player.State.MOVING)
