class_name PlayerStateJumpingShot
extends PlayerState

# 跳跃奖励
const JUMP_BONUS := 1.3
const DOUBLE_JUMP_BONUS := 2.0
# 弹反奖励
const PARRY_BONUS := 2.0
const BALL_HEIGHT_MIN := 10.0
const BALL_HEIGHT_MAX := 50.0

func _enter_tree() -> void:
	animation_player.play("volley_kick")
	player.velocity = Vector2.ZERO
	if player.has_ball():
		perform_jump_shot()
	else:
		# 如果玩家不持球，等待球进入检测区域
		ball_detection_area.body_entered.connect(on_ball_entered.bind())

func _process(_delta: float) -> void:
	# 落地后转换到 RECOVERING 状态
	if player.height <= 0:
		transition_state(Player.State.RECOVERING)

func on_ball_entered(contact_ball: Ball) -> void:
	# 如果球在合适的高度范围内,执行跳跃射门
	if contact_ball.can_air_connect(BALL_HEIGHT_MIN, BALL_HEIGHT_MAX):
		var destination := target_goal.get_random_target_position()
		var direction := ball.position.direction_to(destination)
		var bonus_power := PARRY_BONUS * player.power
		AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
		contact_ball.shoot(direction * bonus_power, player.height, bonus_power, player.power_shot_type)

func perform_jump_shot() -> void:
	var destination := target_goal.get_random_target_position()
	var direction := ball.position.direction_to(destination)
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
	var bonus_power := JUMP_BONUS * player.power if player.jump_count == 1 else DOUBLE_JUMP_BONUS * player.power
	print("执行跳跃射门 %s 次跳跃 %s 力量 %s bonus_power %s" % [player.jump_count, player.power, bonus_power, bonus_power, player.power_shot_type])

	ball.shoot(direction * bonus_power, player.height, bonus_power, player.power_shot_type)

func can_pass() -> bool:
	return true
