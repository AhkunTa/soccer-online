class_name BallStateShot
extends BallState

const DURATION_SHOT := 1000
const SHOT_SPRITE_SCALE := 0.9
const DEFAULT_SHOT_HEIGHT := 10.0
var time_since_shot := Time.get_ticks_msec()
var previous_sprite_scale := Vector2.ONE

func on_enter_visual() -> void:
	set_ball_roll_animation_from_velocity()
	previous_sprite_scale = sprite.scale
	sprite.scale.y = previous_sprite_scale.y * SHOT_SPRITE_SCALE
	shot_particles.emitting = true
	GameEvents.impact_received.emit(ball.position, true)

func on_enter_logic() -> void:
	if state_data.shot_height >= 0:
		ball.height = state_data.shot_height
	else:
		ball.height = DEFAULT_SHOT_HEIGHT
	time_since_shot = Time.get_ticks_msec()

func server_process(delta: float) -> void:
	if Time.get_ticks_msec() - time_since_shot >= DURATION_SHOT:
		if SyncManager.is_client(): return
		state_transition_requested.emit(Ball.State.FREEFORM)
	else:
		var ball_caught := check_player_damage()
		if not ball_caught:
			move_and_bounce(delta)

func can_air_interact() -> bool:
	return true

func _exit_tree() -> void:
	sprite.scale = previous_sprite_scale
	shot_particles.emitting = false
