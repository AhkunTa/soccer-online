class_name BallStatePowerShotCurve
extends BallState

# 绝招：弧线射门
# 球以弧线轨迹飞向球门，可以绕过守门员
# 这是一个示例文件，展示如何创建更多绝招

# 弧线强度
const CURVE_STRENGTH := 50.0
# 射门持续时间
const DURATION_SHOT := 1000
# 默认射门高度
const DEFAULT_SHOT_HEIGHT := 15.0

var time_since_shot := 0
var curve_direction := 1.0  # 1.0 为右弧线，-1.0 为左弧线

func _enter_tree() -> void:
	print("绝招激活：弧线射门！")
	
	# 根据射门方向决定弧线方向
	if ball.velocity.x > 0:
		curve_direction = 1.0
	else:
		curve_direction = -1.0
	
	# 设置初始高度
	if state_data.shot_height >= 0:
		ball.height = state_data.shot_height
	else:
		ball.height = DEFAULT_SHOT_HEIGHT
	
	time_since_shot = Time.get_ticks_msec()
	
	# 设置动画和特效
	set_ball_animation_from_velocity()
	shot_particles.emitting = true
	GameEvents.impact_received.emit(ball.position, true)

func _process(delta: float) -> void:
	var elapsed_time := Time.get_ticks_msec() - time_since_shot
	
	if elapsed_time >= DURATION_SHOT:
		# 射门时间结束，转换为自由状态
		state_transition_requested.emit(Ball.State.FREEFORM)
	else:
		# 应用弧线效果
		var perpendicular := Vector2(-ball.velocity.y, ball.velocity.x).normalized()
		ball.velocity += perpendicular * curve_direction * CURVE_STRENGTH * delta
		
		# 移动球
		move_and_bounce(delta)

func _exit_tree() -> void:
	shot_particles.emitting = false
	print("弧线射门结束")

