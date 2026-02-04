class_name  BallStatePowerShotStrong
extends BallState

const POWER_SHOT_STRENGTH := 200.0
const POWER_SHOT_HEIGHT := 5.0
var time_since_shot := Time.get_ticks_msec()


var time_since_power_shot := Time.get_ticks_msec()

func _enter_tree() -> void:
	animation_player.play("power_shot_strong")
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT_STRONG)
	ball.height = carrier.height + POWER_SHOT_HEIGHT
	# 绝招射击直接指向目标球门 必中
	var short_direction := carrier.get_direction_to_opponent_goal()
	ball.velocity = short_direction * POWER_SHOT_STRENGTH

func _process(_delta: float) -> void:
	move_and_bounce(_delta)
