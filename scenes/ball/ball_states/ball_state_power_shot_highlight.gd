class_name  BallStatePowerShotHighlight
extends BallState

const POWER_SHOT_STRENGTH := 200.0
const POWER_SHOT_HEIGHT := 5.0
var time_since_shot := Time.get_ticks_msec()


var time_since_power_shot := Time.get_ticks_msec()

func _enter_tree() -> void:
	set_ball_roll_animation_from_velocity()
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT_STRONG)
	shot_particles.emitting = true
	ball.height = carrier.height + POWER_SHOT_HEIGHT
	# 绝招射击直接指向目标球门 必中
	var short_direction := carrier.get_direction_to_opponent_goal()
	ball.velocity = short_direction * POWER_SHOT_STRENGTH

func _process(_delta: float) -> void:
	add_highlight_effect()

	# 检查是否击中玩家造成伤害
	var ball_caught := check_player_damage()
	if not ball_caught:
		move_and_bounce(_delta)

func _exit_tree() -> void:
	remove_highlight_effect()
	shot_particles.emitting = false

func can_air_interact() -> bool:
	return true
