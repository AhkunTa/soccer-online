class_name AIBehavior
extends Node

## AI更新频率（毫秒）
const DURATION_AI_TICK_FREQUENCY := 200
## 助攻站位分散系数，用于计算队友助攻时的站位距离
const SPREAD_ASSIST_FACTOR := 0.8
# AI射击距离
const SHOT_DISTANCE := 150
# 每次 30% 射击
const SHOT_PROBABILITY := 0.3

var ball: Ball = null
var player: Player = null
var time_since_last_ai_tick := Time.get_ticks_msec()

## 初始化AI行为
## 参考: https://www.youtube.com/watch?v=4_J_rYPteXg&t=1301s
func _ready() -> void:
	# 随机化初始AI更新时间，避免所有AI同时更新
	time_since_last_ai_tick = Time.get_ticks_msec() + randi_range(0, DURATION_AI_TICK_FREQUENCY)


## 设置AI上下文
## @param context_player: 要控制的球员
## @param context_ball: 球的引用
func setup(context_player: Player, context_ball: Ball) -> void:
	player = context_player
	ball = context_ball


## 处理AI逻辑（每帧调用）
## 根据设定的频率执行AI移动和决策
func process_ai() -> void:
	if Time.get_ticks_msec() - time_since_last_ai_tick > DURATION_AI_TICK_FREQUENCY:
		time_since_last_ai_tick = Time.get_ticks_msec()
		perform_ai_movement()
		perform_ai_decisions()

## 执行AI移动逻辑
## 根据球员状态计算转向力并更新速度
func perform_ai_movement() -> void:
	var total_steering_force := Vector2.ZERO
	if player.has_ball():
		# 持球时：向目标球门移动
		total_steering_force += get_carrier_steering_force()
	elif player.role != Player.Role.GOALIE:
		# 非守门员且无球时：追球
		total_steering_force += get_onduty_steering_force()
		if is_ball_carried_by_teammate():
			# 队友持球时：进行助攻站位
			total_steering_force += get_assist_formation_steering()
	# 限制转向力的最大值为1.0
	total_steering_force = total_steering_force.limit_length(1.0)
	player.velocity = total_steering_force * player.speed

## 执行AI决策逻辑
func perform_ai_decisions() -> void:
	if ball.carrier == player:
			var target := player.target_goal.get_center_target_position()
			if player.position.distance_to(target) < SHOT_DISTANCE and randf() < SHOT_PROBABILITY:
				face_towards_goal()
				var shot_direction := player.position.direction_to(player.target_goal.get_random_target_position())
				var data := PlayerStateData.build().set_shot_power(player.power).set_shot_direction(shot_direction)
				player.switch_state(Player.State.SHOOTING, data)

func face_towards_goal() -> void:
	if not player.is_facing_target_goal():
		player.heading = player.heading * -1


## 获取值班状态下的转向力（追球）
## @return 指向球的方向的转向力向量
func get_onduty_steering_force() -> Vector2:
	# 越近球 权重越高
	return player.weight_on_duty_steering * player.position.direction_to(ball.position)

## 获取持球者的转向力（带球进攻）
## @return 指向目标球门的转向力向量，根据距离调整权重
func get_carrier_steering_force() -> Vector2:
	var target := player.target_goal.get_center_target_position()
	var direction := player.position.direction_to(target)
	# 使用双圆权重：内圆半径100权重0，外圆半径150权重1
	var weight := get_bicircular_weight(player.position, target, 100, 0, 150, 1);
	return weight * direction

## 获取助攻站位的转向力
## 根据持球队友的位置和出生点差异计算助攻位置
## @return 指向助攻目标位置的转向力向量
func get_assist_formation_steering() -> Vector2:
	# 计算当前球员与持球队友的出生点位置差
	var spawn_difference := ball.carrier.spawn_position - player.spawn_position
	# 根据持球队友位置和分散系数计算助攻目标位置
	var assist_destination := ball.carrier.position - spawn_difference * SPREAD_ASSIST_FACTOR
	var direction := player.position.direction_to(assist_destination)
	# 使用双圆权重：内圆半径30权重0.2，外圆半径50权重1
	var weight := get_bicircular_weight(player.position, assist_destination, 30, 0.2, 50, 1)
	return weight * direction


## 计算双圆权重系统
## 根据位置到目标中心的距离，在内外两个圆之间进行权重插值
## @param position: 当前位置
## @param center_target: 目标中心位置
## @param inner_circle_radius: 内圆半径
## @param inner_circle_weight: 内圆权重
## @param outer_circle_radius: 外圆半径
## @param outer_circle_weight: 外圆权重
## @return 根据距离计算的权重值
func get_bicircular_weight(position: Vector2, center_target: Vector2, inner_circle_radius: float, inner_circle_weight: float, outer_circle_radius: float, outer_circle_weight: float) -> float:
	var distance_to_center := position.distance_to(center_target)
	if distance_to_center > outer_circle_radius:
		return outer_circle_weight
	elif distance_to_center < inner_circle_radius:
		return inner_circle_weight
	else:
		# 在两圆之间：线性插值
		var distance_to_inner_radius := distance_to_center - inner_circle_radius
		var distance_between_circles := outer_circle_radius - inner_circle_radius
		var t := distance_to_inner_radius / distance_between_circles
		return lerp(inner_circle_weight, outer_circle_weight, t)

## 判断球是否被队友持有
func is_ball_carried_by_teammate() -> bool:
	return ball.carrier != null and ball.carrier != player and ball.carrier.country == player.country