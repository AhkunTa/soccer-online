class_name BallStatePowerShotCurve
extends BallState

enum CurveType { LEFT, RIGHT }

const CURVE_STRENGTH := 150.0
const DEFAULT_SHOT_HEIGHT := 15.0
const POWER_SHOT_STRENGTH := 180.0

var curve_type: CurveType
var target_position := Vector2.ZERO
var initial_direction := Vector2.ZERO

func on_enter_visual() -> void:
	sprite.modulate.a = 1.0
	sprite.visible = true
	set_ball_roll_animation_from_velocity()
	shot_particles.emitting = true

func on_enter_logic() -> void:
	if carrier == null:
		# 客户端：velocity 已由 RPC extra 设置，从速度方向推算 target_position
		if ball.height <= 0:
			ball.height = DEFAULT_SHOT_HEIGHT
		# 用速度方向推算一个远处的目标点，保证弧线方向正确
		target_position = ball.position + ball.velocity.normalized() * 1000.0
		initial_direction = ball.velocity.normalized()
		curve_type = CurveType.LEFT if randf() > 0.5 else CurveType.RIGHT
		return
	target_position = carrier.target_goal.get_random_target_position()
	curve_type = CurveType.LEFT if randf() > 0.5 else CurveType.RIGHT
	var to_goal := ball.position.direction_to(target_position)
	var offset_angle := deg_to_rad(30.0)
	if curve_type == CurveType.LEFT:
		initial_direction = to_goal.rotated(offset_angle)
	else:
		initial_direction = to_goal.rotated(-offset_angle)
	ball.velocity = initial_direction * POWER_SHOT_STRENGTH
	if state_data.shot_height >= 0:
		ball.height = state_data.shot_height
	else:
		ball.height = DEFAULT_SHOT_HEIGHT

func visual_process(_delta: float) -> void:
	add_highlight_effect()

func server_process(delta: float) -> void:
	var ball_caught := check_player_damage()
	if not ball_caught:
		_apply_curve_effect(delta)
		move_and_bounce(delta)

func _apply_curve_effect(delta: float) -> void:
	var to_goal := ball.position.direction_to(target_position)
	var current_direction := ball.velocity.normalized()
	var turn_direction: float = sign(current_direction.cross(to_goal))
	var perpendicular := Vector2(-current_direction.y, current_direction.x).normalized()
	ball.velocity += perpendicular * turn_direction * CURVE_STRENGTH * delta

func can_air_interact() -> bool:
	return true

func _exit_tree() -> void:
	shot_particles.emitting = false
	remove_highlight_effect()
