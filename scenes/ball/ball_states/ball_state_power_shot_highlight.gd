class_name BallStatePowerShotHighlight
extends BallState

const POWER_SHOT_STRENGTH := 150.0
const POWER_SHOT_HEIGHT := 5.0
const INITIAL_HEIGHT_VELOCITY := 3.0
const SPEED_MULTIPLIER := 1.5

func on_enter_visual() -> void:
	set_ball_roll_animation_from_velocity()
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT_STRONG)
	shot_particles.emitting = true

func on_enter_logic() -> void:
	ball.height = carrier.height + POWER_SHOT_HEIGHT
	var bounce_target := carrier.target_goal.get_bounce_target_position()
	var horizontal_offset := bounce_target - ball.position
	var horizontal_distance := horizontal_offset.length()
	var direction := horizontal_offset.normalized()
	var initial_height := ball.height
	var discriminant := INITIAL_HEIGHT_VELOCITY * INITIAL_HEIGHT_VELOCITY + 2.0 * GRAVITY * initial_height
	var flight_time := (INITIAL_HEIGHT_VELOCITY + sqrt(discriminant)) / GRAVITY
	var horizontal_velocity := horizontal_distance / flight_time
	horizontal_velocity *= SPEED_MULTIPLIER
	var adjusted_height_velocity := INITIAL_HEIGHT_VELOCITY * SPEED_MULTIPLIER
	ball.velocity = direction * horizontal_velocity
	ball.height_velocity = adjusted_height_velocity

func visual_process(_delta: float) -> void:
	add_highlight_effect()

func physics_process(delta: float) -> void:
	_process_gravity_highlight(delta, 0.9, 1.0)
	var ball_caught := check_player_damage()
	if not ball_caught:
		move_and_bounce(delta)

func _process_gravity_highlight(delta: float, height_velocity_decay: float, velocity_decay: float) -> void:
	if ball.height > 0 or ball.height_velocity > 0:
		var adjusted_gravity := GRAVITY * SPEED_MULTIPLIER * SPEED_MULTIPLIER
		ball.height_velocity -= adjusted_gravity * delta
		ball.height += ball.height_velocity * delta
		if ball.height <= 0:
			ball.height = 0
			if height_velocity_decay > 0 and ball.height_velocity < -0.1:
				ball.height_velocity = -ball.height_velocity * (height_velocity_decay * 0.3)
				ball.velocity *= velocity_decay

func _exit_tree() -> void:
	remove_highlight_effect()
	shot_particles.emitting = false

func can_air_interact() -> bool:
	return true
