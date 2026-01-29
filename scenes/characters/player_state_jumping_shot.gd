class_name PlayerStateJumpingShot
extends PlayerState

const BONUS_POWER := 1.5
const BALL_HEIGHT_MIN := 1.0
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
		AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
		contact_ball.shoot(direction * player.power * BONUS_POWER, player.height)

func perform_jump_shot() -> void:
	var destination := target_goal.get_random_target_position()
	var direction := ball.position.direction_to(destination)
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
	ball.shoot(direction * player.power * BONUS_POWER, player.height)

func can_pass() -> bool:
	return true