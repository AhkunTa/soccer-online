class_name BallStatePowerShotInvisible
extends BallState

# 绝招：隐身球
# 球在射门过程中变得隐形，在球门附近才显现
const POWER_SHOT_STRENGTH := 150.0
const POWER_SHOT_HEIGHT := 5.0

# 隐身和显现的距离阈值（距离球门的距离）
const DISTANCE_TO_GOAL_APPEAR := 150.0 # 距离球门150像素时开始显现
const DISTANCE_TO_GOAL_FADE := 200.0 # 距离球门200像素时完全隐身

# 隐身阶段
enum Phase {
	FADING_OUT, # 淡出阶段（刚射门）
	INVISIBLE, # 完全隐身阶段
	APPEARING # 显现阶段（接近球门）
}

var current_phase: Phase = Phase.FADING_OUT
var time_since_shot := 0
var target_goal: Goal = null

func _enter_tree() -> void:
	set_ball_roll_animation_from_velocity()
	# TODO 修改音频
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT_STRONG)

	ball.height = carrier.height + POWER_SHOT_HEIGHT

	# 获取目标球门
	target_goal = carrier.target_goal

	# 绝招射击直接指向目标球门
	var shot_direction := carrier.get_direction_to_opponent_goal()
	ball.velocity = shot_direction * POWER_SHOT_STRENGTH

	# 开始淡出
	current_phase = Phase.FADING_OUT
	time_since_shot = Time.get_ticks_msec()

	# 播放特效
	shot_particles.emitting = true
	GameEvents.impact_received.emit(ball.position, true)
	print("绝招激活：隐身射门！")

func _process(_delta: float) -> void:
	# 更新透明度
	update_visibility()

	# 检查是否击中玩家造成伤害
	var ball_caught := check_player_damage()
	if not ball_caught:
		move_and_bounce(_delta)

func update_visibility() -> void:
	# 计算球到目标球门的距离
	var distance_to_goal := ball.position.distance_to(target_goal.position)

	match current_phase:
		Phase.FADING_OUT:
			# 淡出阶段：快速变透明
			var elapsed := Time.get_ticks_msec() - time_since_shot
			var fade_duration := 200.0 # 200毫秒内完全隐身
			var alpha: float = 1.0 - clamp(elapsed / fade_duration, 0.0, 1.0)
			sprite.modulate.a = alpha

			if alpha <= 0.0:
				current_phase = Phase.INVISIBLE

		Phase.INVISIBLE:
			# 完全隐身
			sprite.modulate.a = 0.0

			# 检查是否接近球门，开始显现
			if distance_to_goal <= DISTANCE_TO_GOAL_FADE:
				current_phase = Phase.APPEARING

		Phase.APPEARING:
			# 显现阶段：根据距离逐渐显现
			if distance_to_goal <= DISTANCE_TO_GOAL_APPEAR:
				# 完全显现
				sprite.modulate.a = 1.0
			else:
				# 线性插值显现
				var progress := (DISTANCE_TO_GOAL_FADE - distance_to_goal) / (DISTANCE_TO_GOAL_FADE - DISTANCE_TO_GOAL_APPEAR)
				sprite.modulate.a = clamp(progress, 0.0, 1.0)

func can_air_interact() -> bool:
	return true

func _exit_tree() -> void:
	# 恢复球的透明度
	sprite.modulate.a = 1.0
	shot_particles.emitting = false
	print("隐身射门结束")
