class_name BallStatePowerShotNormal
extends BallState

const POWER_SHOT_STRENGTH := 200.0
const POWER_SHOT_HEIGHT := 5.0

func _enter_tree() -> void:
	play_animation()
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT_STRONG)
	ball.height = carrier.height + POWER_SHOT_HEIGHT
	if ball.height <= 10:
			shot_particles.emitting = true
	# 绝招射击直接指向目标球门 必中
	var short_direction := carrier.get_direction_to_opponent_goal()
	ball.velocity = short_direction * POWER_SHOT_STRENGTH

func play_animation() -> void:
	set_ball_roll_animation_from_velocity()


func is_height_light_effect() -> bool:
	return false

func _process(_delta: float) -> void:
	# 检查是否击中玩家造成伤害
	if is_height_light_effect():
		add_highlight_effect()

	var ball_caught := check_player_damage()
	if not ball_caught:
		move_and_bounce(_delta)

func _exit_tree() -> void:
	shot_particles.emitting = false

func can_air_interact() -> bool:
	return true