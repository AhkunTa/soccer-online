class_name PlayerStateDiving
extends PlayerState

const DURATION_DIVE := 500
var time_start_dive := Time.get_ticks_msec()

func on_enter_visual() -> void:
	var target_dive := Vector2(player.spawn_position.x, ball.position.y)
	var direction := player.position.direction_to(target_dive)
	if direction.y > 0:
		animation_player.play("dive_down")
	else:
		animation_player.play("dive_up")

func on_enter_logic() -> void:
	var target_dive := Vector2(player.spawn_position.x, ball.position.y)
	var direction := player.position.direction_to(target_dive)
	player.velocity = direction * player.speed
	time_start_dive = Time.get_ticks_msec()

func server_process(_delta: float) -> void:
	if Time.get_ticks_msec() - time_start_dive > DURATION_DIVE:
		transition_state(Player.State.RECOVERING)
