class_name BallStatePowerShotHighlight
extends BallState

const POWER_SHOT_STRENGTH := 150.0
const POWER_SHOT_HEIGHT := 5.0
const INITIAL_HEIGHT_VELOCITY := 3.0 # 向上的初始速度，产生抛物线效果
const SPEED_MULTIPLIER := 1.5 # 速度倍数，提高整体飞行速度
var time_since_shot := Time.get_ticks_msec()

var time_since_power_shot := Time.get_ticks_msec()

func _enter_tree() -> void:
	set_ball_roll_animation_from_velocity()
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT_STRONG)
	shot_particles.emitting = true
	ball.height = carrier.height + POWER_SHOT_HEIGHT

	var bounce_target := carrier.target_goal.get_bounce_target_position()

	# 计算从当前位置到目标位置的水平距离和方向
	var horizontal_offset := bounce_target - ball.position
	var horizontal_distance := horizontal_offset.length()
	var direction := horizontal_offset.normalized()

	# 抛物线运动物理计算：
	# 已知：初始高度 h0 = ball.height, 目标高度 h1 = 0, 初始向上速度 vy0 = INITIAL_HEIGHT_VELOCITY
	# 重力加速度 g = GRAVITY
	#
	# 垂直方向运动方程：h(t) = h0 + vy0*t - 0.5*g*t^2
	# 当 h(t) = 0 时求解 t（落地时间）：
	# 0 = h0 + vy0*t - 0.5*g*t^2
	# 0.5*g*t^2 - vy0*t - h0 = 0
	# 使用求根公式：t = (vy0 + sqrt(vy0^2 + 2*g*h0)) / g

	var initial_height := ball.height
	var discriminant := INITIAL_HEIGHT_VELOCITY * INITIAL_HEIGHT_VELOCITY + 2.0 * GRAVITY * initial_height
	var flight_time := (INITIAL_HEIGHT_VELOCITY + sqrt(discriminant)) / GRAVITY

	# 水平方向：distance = velocity * time
	# 所以：velocity = distance / time
	var horizontal_velocity := horizontal_distance / flight_time

	# 应用速度倍数，提高整体飞行速度
	horizontal_velocity *= SPEED_MULTIPLIER
	var adjusted_height_velocity := INITIAL_HEIGHT_VELOCITY * SPEED_MULTIPLIER

	# 设置球的速度（水平方向）和高度速度（垂直方向）
	ball.velocity = direction * horizontal_velocity
	ball.height_velocity = adjusted_height_velocity

	print("抛物线射门计算：")
	print("  起始高度=%s, 目标距离=%s" % [initial_height, horizontal_distance])
	print("  基础飞行时间=%s, 速度倍数=%s" % [flight_time, SPEED_MULTIPLIER])
	print("  水平速度=%s, 向上速度=%s" % [horizontal_velocity, adjusted_height_velocity])
	print("  目标位置=%s, 当前位置=%s" % [bounce_target, ball.position])
func _process(_delta: float) -> void:
	add_highlight_effect()
	process_gravity(_delta, 0.9, 1.0)
	var ball_caught := check_player_damage()
	if not ball_caught:
		move_and_bounce(_delta)

func process_gravity(delta: float, height_velocity_decay: float = 0.0, velocity_decay: float = 0.0) -> void:
	if ball.height > 0 or ball.height_velocity > 0:
		# 重力也需要按速度倍数的平方调整，以保持抛物线形状
		var adjusted_gravity := GRAVITY * SPEED_MULTIPLIER * SPEED_MULTIPLIER
		ball.height_velocity -= adjusted_gravity * delta
		ball.height += ball.height_velocity * delta

		if ball.height <= 0:
			ball.height = 0
			if height_velocity_decay > 0 and ball.height_velocity < -0.1:
				ball.height_velocity = - ball.height_velocity * (height_velocity_decay * 0.3)
				ball.velocity *= velocity_decay

func _exit_tree() -> void:
	remove_highlight_effect()
	shot_particles.emitting = false

func can_air_interact() -> bool:
	return true
