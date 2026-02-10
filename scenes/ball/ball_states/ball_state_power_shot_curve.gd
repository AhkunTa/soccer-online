class_name BallStatePowerShotCurve
extends BallState

# 绝招：弧线射门
# 球以弧线轨迹飞向球门，随机产生上弧线或下弧线

# 弧线类型
enum CurveType {
	LEFT, # 左弧线（向左弯曲）
	RIGHT # 右弧线（向右弯曲）
}

# 弧线强度（垂直于速度方向的加速度）
const CURVE_STRENGTH := 150.0
# 默认射门高度
const DEFAULT_SHOT_HEIGHT := 15.0
# 射门力量
const POWER_SHOT_STRENGTH := 180.0

var time_since_shot := 0
var curve_type: CurveType
var target_position := Vector2.ZERO # 球门目标位置
var initial_direction := Vector2.ZERO # 初始射门方向（偏离球门）

func _enter_tree() -> void:
	# 确保球可见
	sprite.modulate.a = 1.0
	sprite.visible = true

	# 获取球门目标位置
	target_position = carrier.target_goal.get_random_target_position()

	# 随机选择左弧线或右弧线
	curve_type = CurveType.LEFT if randf() > 0.5 else CurveType.RIGHT

	# 计算初始射门方向：向球门方向偏移一定角度
	var to_goal := ball.position.direction_to(target_position)
	var offset_angle := deg_to_rad(30.0) # 偏移30度
	if curve_type == CurveType.LEFT:
		# 左弧线：初始方向向右偏，然后向左弯回球门
		initial_direction = to_goal.rotated(offset_angle)
	else:
		# 右弧线：初始方向向左偏，然后向右弯回球门
		initial_direction = to_goal.rotated(-offset_angle)

	# 设置初始速度
	ball.velocity = initial_direction * POWER_SHOT_STRENGTH

	# 设置初始高度
	if state_data.shot_height >= 0:
		ball.height = state_data.shot_height
	else:
		ball.height = DEFAULT_SHOT_HEIGHT

	time_since_shot = Time.get_ticks_msec()

	# 设置动画和特效
	set_ball_roll_animation_from_velocity()
	shot_particles.emitting = true
	var curve_name := "左弧线" if curve_type == CurveType.LEFT else "右弧线"
	print("绝招激活：弧线射门！类型：%s " % [curve_name])

func _process(delta: float) -> void:
	# 弧线射门增加高亮效果
	add_highlight_effect()
	var ball_caught := check_player_damage()
	if not ball_caught:
		apply_curve_effect(delta)
		move_and_bounce(delta)

func apply_curve_effect(delta: float) -> void:
	# 计算当前位置到球门的方向
	var to_goal := ball.position.direction_to(target_position)

	# 计算当前速度方向
	var current_direction := ball.velocity.normalized()

	# 施加转向力，让球弯向球门
	# 使用叉积判断转向方向
	var turn_direction: float = sign(current_direction.cross(to_goal))
	var perpendicular := Vector2(-current_direction.y, current_direction.x).normalized()

	# 施加弧线力
	ball.velocity += perpendicular * turn_direction * CURVE_STRENGTH * delta

func can_air_interact() -> bool:
	return true

func _exit_tree() -> void:
	shot_particles.emitting = false
	remove_highlight_effect()
	print("弧线射门结束")
