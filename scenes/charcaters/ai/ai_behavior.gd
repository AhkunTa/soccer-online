class_name AIBehavior
extends Node

## AI更新频率（毫秒）
const DURATION_AI_TICK_FREQUENCY := 200

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

func perform_ai_movement() -> void:
	pass
func perform_ai_decisions() -> void:
	pass

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
