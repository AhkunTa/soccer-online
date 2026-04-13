class_name PlayerStateChestControl
extends PlayerState

const DURATION_CONTROL := 500
var time_start_control := Time.get_ticks_msec()

func on_enter_visual() -> void:
	animation_player.play("chest_control")

func on_enter_logic() -> void:
	player.velocity = Vector2.ZERO
	time_start_control = Time.get_ticks_msec()

func server_process(_delta: float) -> void:
	if Time.get_ticks_msec() - time_start_control > DURATION_CONTROL:
		transition_state(Player.State.MOVING)

func can_pass() -> bool:
	return true
