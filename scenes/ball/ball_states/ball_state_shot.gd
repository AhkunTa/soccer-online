class_name BallStateShot

extends BallState

const DURATION_SHOT := 1000
const SHOT_SPRITE_SCALE := 0.9
const DEFAULT_SHOT_HEIGHT := 10.0
var time_since_shot := Time.get_ticks_msec()

func _enter_tree() -> void:
	set_ball_roll_animation_from_velocity()
	sprite.scale.y = SHOT_SPRITE_SCALE

	if state_data.shot_height >= 0:
		ball.height = state_data.shot_height
	else:
		ball.height = DEFAULT_SHOT_HEIGHT

	time_since_shot = Time.get_ticks_msec()
	shot_particles.emitting = true
	# 全局暂停特效
	GameEvents.impact_received.emit(ball.position, true)

func _process(delta: float) -> void:
	if Time.get_ticks_msec() - time_since_shot >= DURATION_SHOT:
		state_transition_requested.emit(Ball.State.FREEFORM)
	else:
		# 检查是否击中玩家造成伤害
		var ball_caught := check_player_damage()
		if not ball_caught:
			move_and_bounce(delta)

func can_air_interact() -> bool:
	return true

func _exit_tree() -> void:
	sprite.scale.y = 1.0
	shot_particles.emitting = false
