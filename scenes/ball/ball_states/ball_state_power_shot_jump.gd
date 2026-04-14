class_name BallStatePowerShotJump
extends BallState

const POWER_SHOT_STRENGTH := 80.0
const JUMP_HEIGHT_VELOCITY := 100.0
const JUMP_GRAVITY := 100.0

var target_position := Vector2.ZERO

func on_enter_visual() -> void:
	play_animation()
	shot_particles.emitting = true
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT_STRONG)

func on_enter_logic() -> void:
	if carrier == null:
		# 客户端：velocity/height_velocity 已由 RPC extra 设置
		if ball.height_velocity == 0.0:
			ball.height_velocity = JUMP_HEIGHT_VELOCITY
		return
	target_position = carrier.target_goal.get_random_target_position()
	var shot_direction := ball.position.direction_to(target_position)
	ball.velocity = shot_direction * POWER_SHOT_STRENGTH
	ball.height = 0.0
	ball.height_velocity = JUMP_HEIGHT_VELOCITY

func play_animation() -> void:
	set_ball_roll_animation_from_velocity()

func physics_process(delta: float) -> void:
	var ball_caught := check_player_damage()
	if not ball_caught:
		_apply_jump_gravity(delta)
		move_and_bounce(delta)

func _apply_jump_gravity(delta: float) -> void:
	if ball.height > 0 or ball.height_velocity > 0:
		ball.height_velocity -= JUMP_GRAVITY * delta
		ball.height += ball.height_velocity * delta
		if ball.height <= 0:
			ball.height = 0
			ball.height_velocity = JUMP_HEIGHT_VELOCITY

func can_air_interact() -> bool:
	return true

func _exit_tree() -> void:
	shot_particles.emitting = false
