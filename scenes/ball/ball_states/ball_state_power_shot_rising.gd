class_name BallStatePowerShotRising
extends BallState

# 绝招：上升射门
# 球缓慢上升一定距离，然后直接射击球门，没有速度衰减

# 上升阶段持续时间（毫秒）
const DURATION_RISING := 500
# 上升的目标高度
const RISING_TARGET_HEIGHT := 30.0
# 上升速度
const RISING_SPEED := 0.08
# 射门阶段没有摩擦力（速度不衰减）
const NO_FRICTION := 0.0

# 绝招状态阶段
enum Phase {
	RISING,    # 上升阶段
	SHOOTING   # 射门阶段
}

var current_phase: Phase = Phase.RISING
var time_since_start := 0
var initial_velocity := Vector2.ZERO

func _enter_tree() -> void:
	print("绝招激活：上升射门！")
	
	# 保存初始速度
	initial_velocity = ball.velocity
	
	# 设置初始状态
	current_phase = Phase.RISING
	time_since_start = Time.get_ticks_msec()
	
	# 设置球的动画
	set_ball_animation_from_velocity()
	
	# 播放特效
	shot_particles.emitting = true
	GameEvents.impact_received.emit(ball.position, true)

func _process(delta: float) -> void:
	match current_phase:
		Phase.RISING:
			process_rising_phase(delta)
		Phase.SHOOTING:
			process_shooting_phase(delta)

func process_rising_phase(delta: float) -> void:
	var elapsed_time := Time.get_ticks_msec() - time_since_start
	
	# 球缓慢上升
	if ball.height < RISING_TARGET_HEIGHT:
		ball.height += RISING_SPEED * delta * 60.0  # 乘以60是为了适配帧率
	
	# 在上升阶段，球的水平速度逐渐减慢
	ball.velocity = ball.velocity.move_toward(Vector2.ZERO, ball.friction_ground * delta * 0.5)
	
	# 移动球（可能会碰撞墙壁）
	move_and_bounce(delta)
	
	# 上升阶段结束，进入射门阶段
	if elapsed_time >= DURATION_RISING:
		enter_shooting_phase()

func enter_shooting_phase() -> void:
	print("进入射门阶段！")
	current_phase = Phase.SHOOTING
	
	# 恢复并增强初始速度（直射球门，无衰减）
	ball.velocity = initial_velocity.normalized() * initial_velocity.length()
	
	# 设置高度速度为0，保持在当前高度
	ball.height_velocity = 0.0

func process_shooting_phase(delta: float) -> void:
	# 射门阶段：球保持高度，速度不衰减
	# 不应用摩擦力，速度保持不变
	
	# 保持高度不变
	ball.height_velocity = 0.0
	
	# 移动球（可能会碰撞）
	var collision := ball.move_and_collide(ball.velocity * delta)
	if collision != null:
		# 如果碰到墙壁或球门，转换为自由状态
		ball.velocity = ball.velocity.bounce(collision.get_normal()) * BOUNCINESS
		AudioPlayer.play(AudioPlayer.Sound.BOUNCE)
		state_transition_requested.emit(Ball.State.FREEFORM)

func _exit_tree() -> void:
	shot_particles.emitting = false
	print("绝招结束")

