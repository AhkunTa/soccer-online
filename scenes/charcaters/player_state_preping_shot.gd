class_name PlayerStatePrepingShot
extends PlayerState

# 蓄力最大奖励
const DURATION_MAX_BONUS := 1000.0
# 蓄力过长脱力
const DURATION_MIN_MALUS := 1500.0
# 
const EASE_REWARD_FACTOR := 2.0

var shot_direction := Vector2.ZERO

var time_start_shot := Time.get_ticks_msec()

func _enter_tree() -> void:
	animation_player.play("prep_kick")
	player.velocity = Vector2.ZERO
	time_start_shot = Time.get_ticks_msec()
	shot_direction = player.heading
	
func _process(delta: float) -> void:
	shot_direction += KeyUtils.get_input_vector(player.control_scheme) * delta
	if KeyUtils.is_action_just_released(player.control_scheme, KeyUtils.Action.SHOOT):
		var prep_time := Time.get_ticks_msec() - time_start_shot
		var duration_pass := clampf(prep_time, 0.0, DURATION_MAX_BONUS)
		var ease_time := duration_pass / DURATION_MAX_BONUS
		var bonus := ease(ease_time, EASE_REWARD_FACTOR) # 用pow代替ease
		var shot_power := player.power * (1 + bonus)
		shot_direction = shot_direction.normalized()
		var state_data = PlayerStateData.build().set_shot_direction(shot_direction).set_shot_power(shot_power)
		transition_state(Player.State.SHOOTING, state_data)

		#  超时惩罚
		if prep_time >= DURATION_MIN_MALUS:
			# transition_state(Player.State.RECOVERING)
			pass
