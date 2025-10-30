class_name AIBehaviorField
extends AIBehavior

## 助攻站位分散系数，用于计算队友助攻时的站位距离
const SPREAD_ASSIST_FACTOR := 0.8
# AI射击距离
const SHOT_DISTANCE := 150
# 每次 30% 射击
const SHOT_PROBABILITY := 0.3
# 抢断距离
const TACKLE_DISTANCE := 15
const TACKLE_PROBABILITY := 0.3

## 执行AI移动逻辑
## 根据球员状态计算转向力并更新速度
func perform_ai_movement() -> void:
	var total_steering_force := Vector2.ZERO
	if player.has_ball():
		# 持球时：向目标球门移动
		total_steering_force += get_carrier_steering_force()
	else:
		# 非守门员且无球时：追球
		total_steering_force += get_onduty_steering_force()
		if is_ball_carried_by_teammate():
			# 队友持球时：进行助攻站位
			total_steering_force += get_assist_formation_steering_force()
	# 限制转向力的最大值为1.0
	total_steering_force = total_steering_force.limit_length(1.0)
	player.velocity = total_steering_force * player.speed

## 执行AI决策逻辑
func perform_ai_decisions() -> void:
	if is_ball_possessed_by_opponent():
		# 对手持球时，有一定概率尝试抢断
		if player.position.distance_to(ball.carrier.position) < TACKLE_DISTANCE and randf() < TACKLE_PROBABILITY:
			face_towards_goal()
			var tackle_direction := player.position.direction_to(ball.carrier.position)
			var data := PlayerStateData.build().set_shot_direction(tackle_direction)
			player.switch_state(Player.State.TACKLING, data)
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
func get_assist_formation_steering_force() -> Vector2:
	# 计算当前球员与持球队友的出生点位置差
	var spawn_difference := ball.carrier.spawn_position - player.spawn_position
	# 根据持球队友位置和分散系数计算助攻目标位置
	var assist_destination := ball.carrier.position - spawn_difference * SPREAD_ASSIST_FACTOR
	var direction := player.position.direction_to(assist_destination)
	# 使用双圆权重：内圆半径30权重0.2，外圆半径50权重1
	var weight := get_bicircular_weight(player.position, assist_destination, 30, 0.2, 50, 1)
	return weight * direction
