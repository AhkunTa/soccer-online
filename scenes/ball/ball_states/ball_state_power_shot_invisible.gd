class_name BallStatePowerShotInvisible
extends BallState

const POWER_SHOT_STRENGTH := 150.0
const POWER_SHOT_HEIGHT := 5.0
const DISTANCE_TO_GOAL_APPEAR := 150.0
const DISTANCE_TO_GOAL_FADE := 200.0

enum Phase { FADING_OUT, INVISIBLE, APPEARING }

var current_phase: Phase = Phase.FADING_OUT
var time_since_shot := 0
var target_goal: Goal = null

func on_enter_visual() -> void:
	set_ball_roll_animation_from_velocity()
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT_STRONG)

func on_enter_logic() -> void:
	if carrier == null:
		# 客户端：velocity 已由 RPC extra 设置，target_goal 从快照位置推断方向
		if ball.height <= 0:
			ball.height = POWER_SHOT_HEIGHT
		current_phase = Phase.FADING_OUT
		time_since_shot = Time.get_ticks_msec()
		return
	ball.height = carrier.height + POWER_SHOT_HEIGHT
	target_goal = carrier.target_goal
	var shot_direction := carrier.get_direction_to_opponent_goal()
	ball.velocity = shot_direction * POWER_SHOT_STRENGTH
	current_phase = Phase.FADING_OUT
	time_since_shot = Time.get_ticks_msec()

func server_process(delta: float) -> void:
	_update_visibility()
	var ball_caught := check_player_damage()
	if not ball_caught:
		move_and_bounce(delta)

func _update_visibility() -> void:
	if target_goal == null:
		return
	var distance_to_goal := ball.position.distance_to(target_goal.position)
	match current_phase:
		Phase.FADING_OUT:
			var elapsed := Time.get_ticks_msec() - time_since_shot
			var alpha: float = 1.0 - clamp(elapsed / 200.0, 0.0, 1.0)
			sprite.modulate.a = alpha
			if alpha <= 0.0:
				current_phase = Phase.INVISIBLE
		Phase.INVISIBLE:
			sprite.modulate.a = 0.0
			if distance_to_goal <= DISTANCE_TO_GOAL_FADE:
				current_phase = Phase.APPEARING
		Phase.APPEARING:
			if distance_to_goal <= DISTANCE_TO_GOAL_APPEAR:
				sprite.modulate.a = 1.0
			else:
				var progress := (DISTANCE_TO_GOAL_FADE - distance_to_goal) / (DISTANCE_TO_GOAL_FADE - DISTANCE_TO_GOAL_APPEAR)
				sprite.modulate.a = clamp(progress, 0.0, 1.0)

func can_air_interact() -> bool:
	return true

func _exit_tree() -> void:
	sprite.modulate.a = 1.0
