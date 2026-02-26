class_name BallStatePowerShotJump
extends BallState

# 绝招：跳跃射门 作为基础的跳跃射门状态，其他类似的绝招（如鱼跃射门）可以继承这个状态并调整参数
# 球一边向球门移动，一边像兔子一样一跳一跳前进

# 射门力量
const POWER_SHOT_STRENGTH := 80.0
# 跳跃高度速度
const JUMP_HEIGHT_VELOCITY := 100.0
# 跳跃专用重力（控制下落速度）
const JUMP_GRAVITY := 100.0

var target_position := Vector2.ZERO # 球门目标位置

func _enter_tree() -> void:
	# 获取球门目标位置
	target_position = carrier.target_goal.get_random_target_position()

	# 设置射门方向和速度（直接指向球门）
	var shot_direction := ball.position.direction_to(target_position)
	ball.velocity = shot_direction * POWER_SHOT_STRENGTH

	# 设置初始高度为0，准备第一次跳跃
	ball.height = 0.0

	# 立即施加第一次跳跃
	ball.height_velocity = JUMP_HEIGHT_VELOCITY

	# 设置动画和特效
	play_animation()
	shot_particles.emitting = true
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT_STRONG)
	print("绝招激活：跳跃射门！目标位置：%s 第一次跳跃！" % target_position)

func play_animation() -> void:
	set_ball_roll_animation_from_velocity()
func _process(delta: float) -> void:
	# 检查是否击中玩家造成伤害
	var ball_caught := check_player_damage()
	if not ball_caught:
		apply_jump_gravity(delta)
		move_and_bounce(delta)

func apply_jump_gravity(delta: float) -> void:
	# 应用跳跃专用重力（比普通重力更强，让球快速落地）
	if ball.height > 0 or ball.height_velocity > 0:
		ball.height_velocity -= JUMP_GRAVITY * delta
		ball.height += ball.height_velocity * delta
		# 球落地时立即再次跳跃
		if ball.height <= 0:
			ball.height = 0
			ball.height_velocity = JUMP_HEIGHT_VELOCITY

func can_air_interact() -> bool:
	return true

func _exit_tree() -> void:
	shot_particles.emitting = false
	print("跳跃射门结束")
