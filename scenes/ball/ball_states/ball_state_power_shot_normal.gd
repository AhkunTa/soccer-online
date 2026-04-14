class_name BallStatePowerShotNormal
extends BallState

const POWER_SHOT_STRENGTH := 200.0
const POWER_SHOT_HEIGHT := 5.0

func on_enter_visual() -> void:
	play_animation()
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT_STRONG)
	shot_particles.emitting = true

func on_enter_logic() -> void:
	if carrier == null:
		if ball.height <= 0:
			ball.height = POWER_SHOT_HEIGHT
		return
	ball.height = carrier.height + POWER_SHOT_HEIGHT
	var short_direction := carrier.get_direction_to_opponent_goal()
	ball.velocity = short_direction * POWER_SHOT_STRENGTH

func play_animation() -> void:
	set_ball_roll_animation_from_velocity()

func is_height_light_effect() -> bool:
	return false

func visual_process(_delta: float) -> void:
	if is_height_light_effect():
		add_highlight_effect()

func physics_process(delta: float) -> void:
	var ball_caught := check_player_damage()
	if not ball_caught:
		move_and_bounce(delta)

func _exit_tree() -> void:
	shot_particles.emitting = false
	if is_height_light_effect():
		remove_highlight_effect()

func can_air_interact() -> bool:
	return true
